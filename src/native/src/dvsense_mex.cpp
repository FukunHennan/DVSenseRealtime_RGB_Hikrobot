#include "mex.h"
#include <windows.h>
#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace {
constexpr uint32_t CMD_OPEN = 1;
constexpr uint32_t CMD_BATCH_TIME = 2;
constexpr uint32_t CMD_SET_ROI = 3;
constexpr uint32_t CMD_START_RECORDING = 4;
constexpr uint32_t CMD_STOP_RECORDING = 5;
constexpr uint32_t CMD_START = 6;
constexpr uint32_t CMD_READ = 7;
constexpr uint32_t CMD_STOP = 8;
constexpr uint32_t CMD_CLOSE = 9;
constexpr uint32_t CMD_READ_FRAME = 10;
constexpr uint32_t CMD_GET_TOOLS = 11;
constexpr uint32_t CMD_GET_TOOL_PARAMETERS = 12;
constexpr uint32_t CMD_SET_PARAMETER = 13;

HANDLE childInput = nullptr;
HANDLE childOutput = nullptr;
HANDLE childProcess = nullptr;
bool connected = false;
bool started = false;

[[noreturn]] void fail(const char* id, const std::string& message) {
    mexErrMsgIdAndTxt(id, "%s", message.c_str());
}

std::string toText(const mxArray* input) {
    const mxArray* source = input;
    mxArray* converted = nullptr;
    if (!mxIsChar(input)) {
        mxArray* mutableInput = const_cast<mxArray*>(input);
        if (mexCallMATLAB(1, &converted, 1, &mutableInput, "char") != 0) {
            fail("DVSense:input", "Text conversion failed.");
        }
        source = converted;
    }
    char* value = mxArrayToString(source);
    if (converted) mxDestroyArray(converted);
    if (!value) fail("DVSense:input", "Unable to read text input.");
    std::string result(value);
    mxFree(value);
    return result;
}

void requireConnected() {
    if (!connected || !childInput || !childOutput) {
        fail("DVSense:helper", "DVSense helper is not connected.");
    }
}

void writeAll(const void* data, size_t bytes) {
    const auto* cursor = static_cast<const uint8_t*>(data);
    while (bytes > 0) {
        DWORD written = 0;
        if (!WriteFile(childInput, cursor, static_cast<DWORD>(bytes), &written, nullptr) || written == 0) {
            fail("DVSense:helper", "Failed to write to DVSense helper.");
        }
        cursor += written;
        bytes -= written;
    }
}

void readAll(void* data, size_t bytes) {
    auto* cursor = static_cast<uint8_t*>(data);
    while (bytes > 0) {
        DWORD read = 0;
        if (!ReadFile(childOutput, cursor, static_cast<DWORD>(bytes), &read, nullptr) || read == 0) {
            fail("DVSense:helper", "DVSense helper disconnected.");
        }
        cursor += read;
        bytes -= read;
    }
}

std::vector<uint8_t> request(uint32_t command, const std::vector<uint8_t>& payload = {}) {
    requireConnected();
    const uint32_t header[2] = {command, static_cast<uint32_t>(payload.size())};
    writeAll(header, sizeof(header));
    if (!payload.empty()) writeAll(payload.data(), payload.size());

    uint32_t response[2] = {};
    readAll(response, sizeof(response));
    const uint32_t status = response[0];
    const uint32_t size = response[1];
    std::vector<uint8_t> body(size);
    if (size > 0) readAll(body.data(), body.size());
    if (status != 0) fail("DVSense:helper", std::string(body.begin(), body.end()));
    return body;
}

void appendU32(std::vector<uint8_t>& out, uint32_t value) {
    for (int i = 0; i < 4; ++i) out.push_back(static_cast<uint8_t>(value >> (8 * i)));
}

void appendU64(std::vector<uint8_t>& out, uint64_t value) {
    for (int i = 0; i < 8; ++i) out.push_back(static_cast<uint8_t>(value >> (8 * i)));
}

void appendI32(std::vector<uint8_t>& out, int32_t value) {
    appendU32(out, static_cast<uint32_t>(value));
}

void appendString(std::vector<uint8_t>& out, const std::string& value) {
    appendU32(out, static_cast<uint32_t>(value.size()));
    out.insert(out.end(), value.begin(), value.end());
}

uint32_t readU32(const std::vector<uint8_t>& data, size_t& offset) {
    if (offset + 4 > data.size()) fail("DVSense:helper", "Malformed helper response.");
    uint32_t value = 0;
    for (int i = 0; i < 4; ++i) value |= static_cast<uint32_t>(data[offset++]) << (8 * i);
    return value;
}

uint64_t readU64(const std::vector<uint8_t>& data, size_t& offset) {
    if (offset + 8 > data.size()) fail("DVSense:helper", "Malformed helper response.");
    uint64_t value = 0;
    for (int i = 0; i < 8; ++i) value |= static_cast<uint64_t>(data[offset++]) << (8 * i);
    return value;
}

std::string readString(const std::vector<uint8_t>& data, size_t& offset) {
    const uint32_t size = readU32(data, offset);
    if (offset + size > data.size()) fail("DVSense:helper", "Malformed helper response.");
    std::string value(data.begin() + static_cast<ptrdiff_t>(offset),
                      data.begin() + static_cast<ptrdiff_t>(offset + size));
    offset += size;
    return value;
}

std::wstring helperPath() {
    HMODULE module = nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                                GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            reinterpret_cast<LPCWSTR>(&helperPath), &module)) {
        fail("DVSense:helper", "Unable to locate the MEX module.");
    }
    wchar_t path[MAX_PATH] = {};
    const DWORD length = GetModuleFileNameW(module, path, MAX_PATH);
    if (length == 0 || length >= MAX_PATH) fail("DVSense:helper", "Unable to locate the helper executable.");
    std::filesystem::path result(path);
    result.replace_filename(L"dvsense_helper.exe");
    return result.wstring();
}

std::vector<uint8_t> launchHelper(const std::string& serial) {
    if (connected) return request(CMD_OPEN);
    SECURITY_ATTRIBUTES attributes{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
    HANDLE helperStdoutRead = nullptr;
    HANDLE helperStdoutWrite = nullptr;
    HANDLE helperStdinRead = nullptr;
    HANDLE helperStdinWrite = nullptr;
    HANDLE helperLogSink = CreateFileW(L"NUL", GENERIC_WRITE,
                                       FILE_SHARE_READ | FILE_SHARE_WRITE,
                                       &attributes, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (!CreatePipe(&helperStdoutRead, &helperStdoutWrite, &attributes, 0) ||
        !CreatePipe(&helperStdinRead, &helperStdinWrite, &attributes, 0) ||
        helperLogSink == INVALID_HANDLE_VALUE) {
        fail("DVSense:helper", "Unable to create helper pipes.");
    }
    SetHandleInformation(helperStdoutRead, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(helperStdinWrite, HANDLE_FLAG_INHERIT, 0);

    std::wstring commandLine =
        L"\"" + helperPath() + L"\" " +
        std::to_wstring(reinterpret_cast<uintptr_t>(helperStdoutWrite));
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdInput = helperStdinRead;
    startup.hStdOutput = helperLogSink;
    startup.hStdError = helperLogSink;
    PROCESS_INFORMATION process{};
    if (!CreateProcessW(nullptr, commandLine.data(), nullptr, nullptr, TRUE, CREATE_NO_WINDOW,
                        nullptr, nullptr, &startup, &process)) {
        CloseHandle(helperStdoutRead);
        CloseHandle(helperStdoutWrite);
        CloseHandle(helperStdinRead);
        CloseHandle(helperStdinWrite);
        CloseHandle(helperLogSink);
        fail("DVSense:helper", "Unable to start dvsense_helper.exe.");
    }
    CloseHandle(process.hThread);
    CloseHandle(helperStdoutWrite);
    CloseHandle(helperStdinRead);
    CloseHandle(helperLogSink);
    childInput = helperStdinWrite;
    childOutput = helperStdoutRead;
    childProcess = process.hProcess;
    connected = true;

    std::vector<uint8_t> payload;
    appendString(payload, serial);
    return request(CMD_OPEN, payload);
}

void cleanup() {
    if (connected) {
        try {
            request(CMD_CLOSE);
        } catch (...) {
        }
    }
    if (childInput) CloseHandle(childInput);
    if (childOutput) CloseHandle(childOutput);
    if (childProcess) {
        WaitForSingleObject(childProcess, 2000);
        if (WaitForSingleObject(childProcess, 0) != WAIT_OBJECT_0) TerminateProcess(childProcess, 1);
        CloseHandle(childProcess);
    }
    childInput = nullptr;
    childOutput = nullptr;
    childProcess = nullptr;
    connected = false;
    started = false;
}

mxArray* makeInfo(const std::vector<uint8_t>& body) {
    size_t offset = 0;
    const uint32_t width = readU32(body, offset);
    const uint32_t height = readU32(body, offset);
    const std::string product = readString(body, offset);
    const std::string serial = readString(body, offset);
    const char* fields[] = {"width", "height", "product", "serial"};
    mxArray* result = mxCreateStructMatrix(1, 1, 4, fields);
    mxSetField(result, 0, "width", mxCreateDoubleScalar(width));
    mxSetField(result, 0, "height", mxCreateDoubleScalar(height));
    mxSetField(result, 0, "product", mxCreateString(product.c_str()));
    mxSetField(result, 0, "serial", mxCreateString(serial.c_str()));
    return result;
}

mxArray* makeEvents(const std::vector<uint8_t>& body) {
    size_t offset = 0;
    const uint32_t count = readU32(body, offset);
    const size_t expected = 4 + static_cast<size_t>(count) * 13;
    if (body.size() != expected) fail("DVSense:helper", "Malformed event batch from helper.");
    const char* fields[] = {"x", "y", "polarity", "timestamp"};
    mxArray* result = mxCreateStructMatrix(1, 1, 4, fields);
    mxArray* x = mxCreateNumericMatrix(count, 1, mxUINT16_CLASS, mxREAL);
    mxArray* y = mxCreateNumericMatrix(count, 1, mxUINT16_CLASS, mxREAL);
    mxArray* polarity = mxCreateLogicalMatrix(count, 1);
    mxArray* timestamp = mxCreateNumericMatrix(count, 1, mxUINT64_CLASS, mxREAL);
    auto* xp = static_cast<uint16_t*>(mxGetData(x));
    auto* yp = static_cast<uint16_t*>(mxGetData(y));
    auto* pp = mxGetLogicals(polarity);
    auto* tp = static_cast<uint64_t*>(mxGetData(timestamp));
    for (uint32_t i = 0; i < count; ++i) {
        xp[i] = static_cast<uint16_t>(body[offset] | (body[offset + 1] << 8)); offset += 2;
        yp[i] = static_cast<uint16_t>(body[offset] | (body[offset + 1] << 8)); offset += 2;
        pp[i] = body[offset++] != 0;
        tp[i] = readU64(body, offset);
    }
    mxSetField(result, 0, "x", x);
    mxSetField(result, 0, "y", y);
    mxSetField(result, 0, "polarity", polarity);
    mxSetField(result, 0, "timestamp", timestamp);
    return result;
}

mxArray* makeFrame(const std::vector<uint8_t>& body) {
    size_t offset = 0;
    const uint32_t width = readU32(body, offset);
    const uint32_t height = readU32(body, offset);
    const size_t pixels = static_cast<size_t>(width) * height;
    if (body.size() != 8 + pixels) {
        fail("DVSense:helper", "Malformed display frame from helper.");
    }
    mxArray* result =
        mxCreateNumericMatrix(height, width, mxUINT8_CLASS, mxREAL);
    auto* output = static_cast<uint8_t*>(mxGetData(result));
    for (uint32_t y = 0; y < height; ++y) {
        for (uint32_t x = 0; x < width; ++x) {
            output[static_cast<size_t>(y) +
                   static_cast<size_t>(x) * height] =
                body[offset + static_cast<size_t>(y) * width + x];
        }
    }
    return result;
}

mxArray* makeTools(const std::vector<uint8_t>& body) {
    size_t offset = 0;
    const uint32_t count = readU32(body, offset);
    const char* fields[] = {"name", "description", "parameters"};
    mxArray* result = mxCreateStructMatrix(1, count, 3, fields);
    for (uint32_t toolIndex = 0; toolIndex < count; ++toolIndex) {
        const std::string name = readString(body, offset);
        const std::string description = readString(body, offset);
        const uint32_t parameterCount = readU32(body, offset);
        mxArray* parameters = mxCreateCellMatrix(1, parameterCount);
        for (uint32_t parameterIndex = 0;
             parameterIndex < parameterCount; ++parameterIndex) {
            const std::string parameter = readString(body, offset);
            mxSetCell(parameters, parameterIndex,
                      mxCreateString(parameter.c_str()));
        }
        mxSetField(result, toolIndex, "name", mxCreateString(name.c_str()));
        mxSetField(result, toolIndex, "description",
                   mxCreateString(description.c_str()));
        mxSetField(result, toolIndex, "parameters", parameters);
    }
    if (offset != body.size()) {
        mxDestroyArray(result);
        fail("DVSense:helper", "Malformed tools response from helper.");
    }
    return result;
}

mxArray* makeToolParameters(const std::vector<uint8_t>& body) {
    size_t offset = 0;
    const uint32_t count = readU32(body, offset);
    const char* fields[] = {"tool", "name", "type", "details", "current",
                            "min", "max", "defaultValue", "unit", "options"};
    mxArray* result = mxCreateStructMatrix(1, count, 10, fields);
    for (uint32_t index = 0; index < count; ++index) {
        const std::string tool = readString(body, offset);
        const std::string name = readString(body, offset);
        const std::string type = readString(body, offset);
        const std::string details = readString(body, offset);
        const std::string current = readString(body, offset);
        const std::string min = readString(body, offset);
        const std::string max = readString(body, offset);
        const std::string defaultValue = readString(body, offset);
        const std::string unit = readString(body, offset);
        const uint32_t optionCount = readU32(body, offset);
        mxArray* options = mxCreateCellMatrix(1, optionCount);
        for (uint32_t optionIndex = 0; optionIndex < optionCount; ++optionIndex) {
            mxSetCell(options, optionIndex, mxCreateString(readString(body, offset).c_str()));
        }
        mxSetField(result, index, "tool", mxCreateString(tool.c_str()));
        mxSetField(result, index, "name", mxCreateString(name.c_str()));
        mxSetField(result, index, "type", mxCreateString(type.c_str()));
        mxSetField(result, index, "details", mxCreateString(details.c_str()));
        mxSetField(result, index, "current", mxCreateString(current.c_str()));
        mxSetField(result, index, "min", mxCreateString(min.c_str()));
        mxSetField(result, index, "max", mxCreateString(max.c_str()));
        mxSetField(result, index, "defaultValue", mxCreateString(defaultValue.c_str()));
        mxSetField(result, index, "unit", mxCreateString(unit.c_str()));
        mxSetField(result, index, "options", options);
    }
    if (offset != body.size()) {
        mxDestroyArray(result);
        fail("DVSense:helper", "Malformed tool parameters response.");
    }
    return result;
}
}

void mexAtExitHandler() {
    cleanup();
}

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
    if (nrhs < 1) fail("DVSense:input", "Command required.");
    const std::string command = toText(prhs[0]);

    if (command == "open") {
        const std::string serial = nrhs > 1 ? toText(prhs[1]) : "";
        const bool wasConnected=connected;
        const std::vector<uint8_t> infoBody=launchHelper(serial);
        if (!wasConnected) {
            mexLock();
            mexAtExit(mexAtExitHandler);
        }
        if (nlhs > 0) plhs[0] = makeInfo(infoBody);
        return;
    }
    if (command == "close") {
        cleanup();
        if (mexIsLocked()) mexUnlock();
        return;
    }
    requireConnected();
    if (command == "batchtime") {
        if (nrhs < 2) fail("DVSense:input", "batchtime requires a value.");
        std::vector<uint8_t> payload;
        appendU64(payload, static_cast<uint64_t>(mxGetScalar(prhs[1])));
        request(CMD_BATCH_TIME, payload);
        return;
    }
    if (command == "setroi") {
        if (nrhs < 2 || !mxIsDouble(prhs[1]) || mxGetNumberOfElements(prhs[1]) < 4) {
            fail("DVSense:input", "setroi requires [x y width height].");
        }
        const double* rectangle = mxGetDoubles(prhs[1]);
        std::vector<uint8_t> payload;
        for (int i = 0; i < 4; ++i) appendI32(payload, static_cast<int32_t>(rectangle[i]));
        request(CMD_SET_ROI, payload);
        return;
    }
    if (command == "startrecording") {
        if (nrhs < 2) fail("DVSense:input", "startrecording requires a file path.");
        const std::string path = toText(prhs[1]);
        std::vector<uint8_t> payload;
        appendString(payload, path);
        request(CMD_START_RECORDING, payload);
        return;
    }
    if (command == "stoprecording") {
        request(CMD_STOP_RECORDING);
        return;
    }
    if (command == "start") {
        request(CMD_START);
        started = true;
        return;
    }
    if (command == "read") {
        if (nlhs > 0) plhs[0] = makeEvents(request(CMD_READ));
        return;
    }
    if (command == "readframe") {
        if (nlhs > 0) plhs[0] = makeFrame(request(CMD_READ_FRAME));
        return;
    }
    if (command == "tools") {
        if (nlhs > 0) plhs[0] = makeTools(request(CMD_GET_TOOLS));
        return;
    }
    if (command == "toolparameters") {
        if (nlhs > 0) {
            plhs[0] = makeToolParameters(request(CMD_GET_TOOL_PARAMETERS));
        }
        return;
    }
    if (command == "setparam") {
        if (nrhs < 5) fail("DVSense:input", "setparam requires tool, name, type, value.");
        std::vector<uint8_t> payload;
        for (int index = 1; index <= 4; ++index) {
            appendString(payload, toText(prhs[index]));
        }
        const std::vector<uint8_t> body = request(CMD_SET_PARAMETER, payload);
        size_t offset = 0;
        const std::string current = readString(body, offset);
        if (offset != body.size()) fail("DVSense:helper", "Malformed setparam response.");
        if (nlhs > 0) plhs[0] = mxCreateString(current.c_str());
        return;
    }
    if (command == "stop") {
        request(CMD_STOP);
        started = false;
        return;
    }
    fail("DVSense:cmd", "Unknown command.");
}
