#include "dvsense_bridge.h"

#include <algorithm>
#include <filesystem>
#include <stdexcept>
#include <string>
#include <vector>
#include <windows.h>
#include <tlhelp32.h>

namespace {
constexpr uint32_t CMD_OPEN=1, CMD_BATCH_TIME=2, CMD_SET_ROI=3;
constexpr uint32_t CMD_START_RECORDING=4, CMD_STOP_RECORDING=5, CMD_START=6;
constexpr uint32_t CMD_READ=7, CMD_STOP=8, CMD_CLOSE=9, CMD_READ_FRAME=10;
constexpr uint32_t CMD_GET_TOOL_PARAMETERS=12, CMD_SET_PARAMETER=13;
constexpr uint32_t CMD_DISCOVER_CAMERAS=14;
constexpr uint32_t CMD_DISPLAY_WINDOW=15;
constexpr DWORD DVSENSE_RESPONSE_TIMEOUT_MS=2000;
constexpr DWORD DVSENSE_DISCOVERY_TIMEOUT_MS=15000;
constexpr DWORD DVSENSE_CONNECTION_TIMEOUT_MS=30000;
constexpr uint32_t MAX_RESPONSE_BYTES=256u*1024u*1024u;

HANDLE childInput=nullptr, childOutput=nullptr, childProcess=nullptr;
bool connected=false, started=false;
std::string lastError, lastValue;
std::wstring moduleDirectory();

[[noreturn]] void fail(const std::string& text) { throw std::runtime_error(text); }

void writeAll(const void* data,size_t size) {
    const auto* cursor=static_cast<const uint8_t*>(data);
    while(size) {
        DWORD written=0;
        if(!WriteFile(childInput,cursor,(DWORD)size,&written,nullptr)||!written)
            fail("Failed to write to DVSense helper.");
        cursor+=written; size-=written;
    }
}
void waitForResponseBytes(DWORD required,DWORD timeoutMs) {
    const ULONGLONG deadline=GetTickCount64()+timeoutMs;
    while(true) {
        if(!childProcess || WaitForSingleObject(childProcess,0)==WAIT_OBJECT_0)
            fail("DVSense helper exited while waiting for a response.");
        DWORD available=0;
        if(!PeekNamedPipe(childOutput,nullptr,0,nullptr,&available,nullptr))
            fail("Unable to inspect DVSense helper response pipe.");
        if(available>=required || (required>0 && available>0)) return;
        if(GetTickCount64()>=deadline)
            fail("DVSense helper response timed out.");
        Sleep(1);
    }
}
void readAll(void* data,size_t size,DWORD timeoutMs) {
    auto* cursor=static_cast<uint8_t*>(data);
    while(size) {
        waitForResponseBytes(1,timeoutMs);
        DWORD available=0;
        if(!PeekNamedPipe(childOutput,nullptr,0,nullptr,&available,nullptr) ||
           available==0) fail("DVSense helper response pipe is unavailable.");
        DWORD requestSize=(DWORD)std::min<size_t>(size,available);
        DWORD read=0;
        if(!ReadFile(childOutput,cursor,requestSize,&read,nullptr)||!read)
            fail("DVSense helper disconnected.");
        cursor+=read; size-=read;
    }
}
std::vector<uint8_t> request(uint32_t command,
    const std::vector<uint8_t>& payload={},DWORD timeoutMs=DVSENSE_RESPONSE_TIMEOUT_MS) {
    if(!connected) fail("DVSense helper is not connected.");
    const uint32_t header[2]={command,(uint32_t)payload.size()};
    writeAll(header,sizeof(header));
    if(!payload.empty()) writeAll(payload.data(),payload.size());
    uint32_t response[2]={}; readAll(response,sizeof(response),timeoutMs);
    if(response[1]>MAX_RESPONSE_BYTES)
        fail("Helper response exceeds the configured safety limit.");
    std::vector<uint8_t> body(response[1]);
    if(!body.empty()) readAll(body.data(),body.size(),timeoutMs);
    if(response[0]) fail(std::string(body.begin(),body.end()));
    return body;
}
void appendU32(std::vector<uint8_t>& out,uint32_t value) {
    for(int i=0;i<4;++i) out.push_back((uint8_t)(value>>(8*i)));
}
void appendU64(std::vector<uint8_t>& out,uint64_t value) {
    for(int i=0;i<8;++i) out.push_back((uint8_t)(value>>(8*i)));
}
void appendI32(std::vector<uint8_t>& out,int32_t value) { appendU32(out,(uint32_t)value); }
void appendString(std::vector<uint8_t>& out,const std::string& value) {
    appendU32(out,(uint32_t)value.size()); out.insert(out.end(),value.begin(),value.end());
}
uint32_t readU32(const std::vector<uint8_t>& data,size_t& offset) {
    if(offset+4>data.size()) fail("Malformed helper response.");
    uint32_t value=0; for(int i=0;i<4;++i) value|=(uint32_t)data[offset++]<<(8*i);
    return value;
}
uint64_t readU64(const std::vector<uint8_t>& data,size_t& offset) {
    if(offset+8>data.size()) fail("Malformed helper response.");
    uint64_t value=0; for(int i=0;i<8;++i) value|=(uint64_t)data[offset++]<<(8*i);
    return value;
}
std::string readString(const std::vector<uint8_t>& data,size_t& offset) {
    uint32_t size=readU32(data,offset);
    if(offset+size>data.size()) fail("Malformed helper response.");
    std::string value(data.begin()+offset,data.begin()+offset+size);
    offset+=size; return value;
}
std::string jsonEscape(const std::string& value) {
    std::string output;
    for(char character:value) {
        switch(character) {
            case '\\': output+="\\\\"; break;
            case '"': output+="\\\""; break;
            case '\n': output+="\\n"; break;
            case '\r': output+="\\r"; break;
            case '\t': output+="\\t"; break;
            default: output+=character; break;
        }
    }
    return output;
}
std::string utf8FromWide(const std::wstring& value) {
    if(value.empty()) return {};
    const int bytes=WideCharToMultiByte(CP_UTF8,0,value.data(),
        static_cast<int>(value.size()),nullptr,0,nullptr,nullptr);
    std::string output(bytes,'\0');
    WideCharToMultiByte(CP_UTF8,0,value.data(),static_cast<int>(value.size()),
        output.data(),bytes,nullptr,nullptr);
    return output;
}
bool queryProcessImagePath(DWORD pid,std::wstring& path) {
    HANDLE process=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,FALSE,pid);
    if(!process) return false;
    wchar_t buffer[32768]={};
    DWORD length=static_cast<DWORD>(sizeof(buffer)/sizeof(buffer[0]));
    const BOOL ok=QueryFullProcessImageNameW(process,0,buffer,&length);
    CloseHandle(process);
    if(!ok) return false;
    path.assign(buffer,length);
    return true;
}
std::vector<DWORD> staleHelperPids() {
    const std::wstring helperPath=
        (std::filesystem::path(moduleDirectory())/"dvsense_helper.exe").wstring();
    const DWORD currentHelperPid=childProcess ?
        GetProcessId(childProcess) : 0;
    std::vector<DWORD> pids;
    HANDLE snapshot=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);
    if(snapshot==INVALID_HANDLE_VALUE) return pids;
    PROCESSENTRY32W entry{};
    entry.dwSize=sizeof(entry);
    if(Process32FirstW(snapshot,&entry)) {
        do {
            if(entry.th32ProcessID==currentHelperPid) continue;
            std::wstring imagePath;
            if(queryProcessImagePath(entry.th32ProcessID,imagePath) &&
               _wcsicmp(imagePath.c_str(),helperPath.c_str())==0)
                pids.push_back(entry.th32ProcessID);
        } while(Process32NextW(snapshot,&entry));
    }
    CloseHandle(snapshot);
    return pids;
}
std::wstring moduleDirectory() {
    HMODULE module=nullptr;
    if(!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
        GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
        reinterpret_cast<LPCWSTR>(&moduleDirectory),&module))
        fail("Unable to locate bridge DLL.");
    wchar_t path[MAX_PATH]={};
    DWORD length=GetModuleFileNameW(module,path,MAX_PATH);
    if(!length||length>=MAX_PATH) fail("Unable to locate bridge DLL.");
    return std::filesystem::path(path).parent_path().wstring();
}
void cleanup() {
    if(connected) try { request(CMD_CLOSE); } catch(...) {}
    if(childInput) CloseHandle(childInput);
    if(childOutput) CloseHandle(childOutput);
    if(childProcess) {
        WaitForSingleObject(childProcess,2000);
        if(WaitForSingleObject(childProcess,0)!=WAIT_OBJECT_0) TerminateProcess(childProcess,1);
        CloseHandle(childProcess);
    }
    childInput=childOutput=childProcess=nullptr; connected=false; started=false;
}
void launchHelper(const std::string& serial,bool openCamera) {
    if(connected) {
        if(openCamera) {
            std::vector<uint8_t> payload;
            appendString(payload,serial);
            request(CMD_OPEN,payload,DVSENSE_CONNECTION_TIMEOUT_MS);
        }
        return;
    }
    SECURITY_ATTRIBUTES attributes{sizeof(SECURITY_ATTRIBUTES),nullptr,TRUE};
    HANDLE stdoutRead=nullptr,stdoutWrite=nullptr,stdinRead=nullptr,stdinWrite=nullptr;
    HANDLE sink=CreateFileW(L"NUL",GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,
        &attributes,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
    if(!CreatePipe(&stdoutRead,&stdoutWrite,&attributes,0) ||
       !CreatePipe(&stdinRead,&stdinWrite,&attributes,0) ||
       sink==INVALID_HANDLE_VALUE) fail("Unable to create helper pipes.");
    SetHandleInformation(stdoutRead,HANDLE_FLAG_INHERIT,0);
    SetHandleInformation(stdinWrite,HANDLE_FLAG_INHERIT,0);
    std::wstring helper=(std::filesystem::path(moduleDirectory())/"dvsense_helper.exe").wstring();
    std::wstring command=L"\""+helper+L"\" "+std::to_wstring((uintptr_t)stdoutWrite);
    STARTUPINFOW startup{}; startup.cb=sizeof(startup); startup.dwFlags=STARTF_USESTDHANDLES;
    startup.hStdInput=stdinRead; startup.hStdOutput=sink; startup.hStdError=sink;
    PROCESS_INFORMATION process{};
    if(!CreateProcessW(nullptr,command.data(),nullptr,nullptr,TRUE,CREATE_NO_WINDOW,
        nullptr,nullptr,&startup,&process)) fail("Unable to start dvsense_helper.exe.");
    CloseHandle(process.hThread); CloseHandle(stdoutWrite); CloseHandle(stdinRead); CloseHandle(sink);
    childInput=stdinWrite; childOutput=stdoutRead; childProcess=process.hProcess; connected=true;
    if(openCamera) {
        std::vector<uint8_t> payload; appendString(payload,serial);
        request(CMD_OPEN,payload,DVSENSE_CONNECTION_TIMEOUT_MS);
    }
}
template<typename Callback> int guarded(Callback&& callback) {
    try { lastError.clear(); callback(); return 0; }
    catch(const std::exception& error) { lastError=error.what(); return -1; }
    catch(...) { lastError="Unknown DVSense bridge error."; return -1; }
}
}

extern "C" {
int dvsense_open(const char* serial) {
    return guarded([&]{ launchHelper(serial?serial:"",true); });
}
const char* dvsense_discover_cameras_json(void) {
    static std::string value;
    try {
        lastError.clear();
        if(!connected) launchHelper("",false);
        auto body=request(CMD_DISCOVER_CAMERAS,{},DVSENSE_DISCOVERY_TIMEOUT_MS);
        size_t offset=0;
        uint32_t count=readU32(body,offset);
        value="[";
        for(uint32_t index=0;index<count;++index) {
            if(index) value+=",";
            std::string fields[7];
            for(auto& field:fields) field=readString(body,offset);
            value+="{\"product\":\""+jsonEscape(fields[0])+
                "\",\"serial\":\""+jsonEscape(fields[1])+
                "\",\"manufacturer\":\""+jsonEscape(fields[2])+
                "\",\"interface\":\""+jsonEscape(fields[3])+
                "\",\"cameraIp\":\""+jsonEscape(fields[4])+
                "\",\"localIp\":\""+jsonEscape(fields[5])+
                "\",\"firmware\":\""+jsonEscape(fields[6])+"\"}";
        }
        if(offset!=body.size()) fail("Malformed camera discovery response.");
        value+="]";
    } catch(const std::exception& error) {
        lastError=error.what();
        value="[]";
    }
    return value.c_str();
}
const char* dvsense_list_stale_helpers_json(void) {
    static std::string value;
    try {
        value="[";
        const auto pids=staleHelperPids();
        for(size_t index=0;index<pids.size();++index) {
            if(index) value+=",";
            std::wstring path;
            queryProcessImagePath(pids[index],path);
            value+="{\"pid\":"+std::to_string(pids[index])+
                ",\"path\":\""+jsonEscape(utf8FromWide(path))+"\"}";
        }
        value+="]";
        lastError.clear();
    } catch(const std::exception& error) {
        lastError=error.what();
        value="[]";
    }
    return value.c_str();
}
int dvsense_terminate_stale_helpers(void) {
    return guarded([&] {
        for(DWORD pid:staleHelperPids()) {
            HANDLE process=OpenProcess(PROCESS_TERMINATE,FALSE,pid);
            if(!process) continue;
            TerminateProcess(process,1);
            CloseHandle(process);
        }
    });
}
int dvsense_close(void) { return guarded([]{ cleanup(); }); }
int dvsense_start(void) { return guarded([]{ request(CMD_START); started=true; }); }
int dvsense_stop(void) {
    return guarded([]{ if(connected) request(CMD_STOP); started=false; });
}
int dvsense_set_batch_time(uint64_t windowUs) {
    return guarded([&]{ std::vector<uint8_t> p; appendU64(p,windowUs); request(CMD_BATCH_TIME,p); });
}
int dvsense_set_display_window(uint64_t windowUs) {
    return guarded([&]{ std::vector<uint8_t> p; appendU64(p,windowUs); request(CMD_DISPLAY_WINDOW,p); });
}
int dvsense_set_roi(int32_t x,int32_t y,int32_t width,int32_t height) {
    return guarded([&]{ std::vector<uint8_t> p; appendI32(p,x); appendI32(p,y);
        appendI32(p,width); appendI32(p,height); request(CMD_SET_ROI,p); });
}
int dvsense_read_events(uint16_t* x,uint16_t* y,uint8_t* polarity,uint64_t* timestamp,
    uint32_t capacity,uint32_t* count) {
    return guarded([&] {
        auto body=request(CMD_READ); size_t offset=0; uint32_t available=readU32(body,offset);
        if(body.size()!=4+(size_t)available*13) fail("Malformed event batch.");
        uint32_t copied=available<capacity?available:capacity, start=available-copied;
        for(uint32_t index=0;index<available;++index) {
            uint16_t eventX=(uint16_t)(body[offset]|(body[offset+1]<<8)); offset+=2;
            uint16_t eventY=(uint16_t)(body[offset]|(body[offset+1]<<8)); offset+=2;
            uint8_t eventPolarity=body[offset++]; uint64_t eventTimestamp=readU64(body,offset);
            if(index>=start) { uint32_t target=index-start; x[target]=eventX; y[target]=eventY;
                polarity[target]=eventPolarity; timestamp[target]=eventTimestamp; }
        }
        *count=copied;
    });
}
int dvsense_read_frame(uint8_t* frame,uint32_t capacity,uint32_t* width,uint32_t* height) {
    return guarded([&] {
        auto body=request(CMD_READ_FRAME); size_t offset=0; *width=readU32(body,offset);
        *height=readU32(body,offset); size_t pixels=(size_t)*width**height;
        if(capacity<pixels||body.size()!=8+pixels) fail("Frame buffer too small or malformed.");
        std::copy(body.begin()+8,body.end(),frame);
    });
}
const char* dvsense_get_camera_info_json(void) {
    static std::string value;
    try {
        auto body=request(CMD_OPEN,{},DVSENSE_CONNECTION_TIMEOUT_MS);
        size_t offset=0; uint32_t width=readU32(body,offset);
        uint32_t height=readU32(body,offset); std::string product=readString(body,offset);
        std::string serial=readString(body,offset);
        value="{\"width\":"+std::to_string(width)+",\"height\":"+std::to_string(height)+
            ",\"product\":\""+product+"\",\"serial\":\""+serial+"\"}";
    } catch(const std::exception& error) { lastError=error.what(); value="{}"; }
    return value.c_str();
}
const char* dvsense_get_tool_parameters_json(void) {
    static std::string value;
    try {
        auto body=request(CMD_GET_TOOL_PARAMETERS,{},DVSENSE_CONNECTION_TIMEOUT_MS);
        size_t offset=0; uint32_t count=readU32(body,offset);
        value="[";
        for(uint32_t index=0;index<count;++index) {
            if(index) value+=",";
            std::string fields[9]; for(auto& field:fields) field=readString(body,offset);
            uint32_t options=readU32(body,offset);
            value+="{\"tool\":\""+fields[0]+"\",\"name\":\""+fields[1]+"\",\"type\":\""+fields[2]+
                "\",\"details\":\""+fields[3]+"\",\"current\":\""+fields[4]+"\",\"min\":\""+fields[5]+
                "\",\"max\":\""+fields[6]+"\",\"defaultValue\":\""+fields[7]+"\",\"unit\":\""+fields[8]+"\",\"options\":[";
            for(uint32_t option=0;option<options;++option) { if(option)value+=","; value+="\""+readString(body,offset)+"\""; }
            value+="]}";
        }
        value+="]";
    } catch(const std::exception& error) { lastError=error.what(); value="[]"; }
    return value.c_str();
}
int dvsense_set_parameter(const char* tool,const char* name,const char* type,const char* value) {
    return guarded([&] {
        std::vector<uint8_t> p; appendString(p,tool?tool:""); appendString(p,name?name:"");
        appendString(p,type?type:""); appendString(p,value?value:"");
        auto body=request(CMD_SET_PARAMETER,p); size_t offset=0; lastValue=readString(body,offset);
    });
}
const char* dvsense_last_value(void) { return lastValue.c_str(); }
const char* dvsense_last_error(void) { return lastError.c_str(); }
int dvsense_start_recording(const char* path) {
    return guarded([&]{ std::vector<uint8_t> p; appendString(p,path?path:""); request(CMD_START_RECORDING,p); });
}
int dvsense_stop_recording(void) { return guarded([]{ request(CMD_STOP_RECORDING); }); }
}
