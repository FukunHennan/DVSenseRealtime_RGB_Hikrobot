#include "mex.h"
#include "MvCameraControl.h"

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

namespace {
void* gHandle = nullptr;
bool gInitialized = false;
bool gStarted = false;
std::string gSerial;
std::string gModel;

[[noreturn]] void fail(const char* id, const std::string& message) {
    mexErrMsgIdAndTxt(id, "%s", message.c_str());
}

std::string toText(const mxArray* value) {
    mxArray* converted = nullptr;
    const mxArray* source = value;
    if (!mxIsChar(value)) {
        mxArray* mutableValue = const_cast<mxArray*>(value);
        if (mexCallMATLAB(1, &converted, 1, &mutableValue, "char") != 0) {
            fail("Hikrobot:Input", "Unable to convert input to text.");
        }
        source = converted;
    }
    char* text = mxArrayToString(source);
    if (converted) mxDestroyArray(converted);
    if (!text) fail("Hikrobot:Input", "Unable to read text input.");
    std::string result(text);
    mxFree(text);
    return result;
}

std::string boundedText(const unsigned char* value, size_t capacity) {
    size_t n = 0;
    while (n < capacity && value[n] != 0) ++n;
    return std::string(reinterpret_cast<const char*>(value), n);
}

std::string serialOf(const MV_CC_DEVICE_INFO* device) {
    if (!device) return {};
    if (device->nTLayerType == MV_USB_DEVICE) {
        const auto& info = device->SpecialInfo.stUsb3VInfo;
        return boundedText(info.chSerialNumber, sizeof(info.chSerialNumber));
    }
    if (device->nTLayerType == MV_GIGE_DEVICE) {
        const auto& info = device->SpecialInfo.stGigEInfo;
        return boundedText(info.chSerialNumber, sizeof(info.chSerialNumber));
    }
    return {};
}

std::string modelOf(const MV_CC_DEVICE_INFO* device) {
    if (!device) return {};
    if (device->nTLayerType == MV_USB_DEVICE) {
        const auto& info = device->SpecialInfo.stUsb3VInfo;
        return boundedText(info.chModelName, sizeof(info.chModelName));
    }
    if (device->nTLayerType == MV_GIGE_DEVICE) {
        const auto& info = device->SpecialInfo.stGigEInfo;
        return boundedText(info.chModelName, sizeof(info.chModelName));
    }
    return {};
}

std::string vendorOf(const MV_CC_DEVICE_INFO* device) {
    if (!device) return {};
    if (device->nTLayerType == MV_USB_DEVICE) {
        const auto& info = device->SpecialInfo.stUsb3VInfo;
        return boundedText(info.chVendorName, sizeof(info.chVendorName));
    }
    if (device->nTLayerType == MV_GIGE_DEVICE) {
        const auto& info = device->SpecialInfo.stGigEInfo;
        return boundedText(info.chManufacturerName, sizeof(info.chManufacturerName));
    }
    return {};
}

void ensureInitialized() {
    if (gInitialized) return;
    const int code = MV_CC_Initialize();
    if (code != MV_OK) fail("Hikrobot:Initialize", "MV_CC_Initialize failed.");
    gInitialized = true;
}

void closeCamera() {
    if (gHandle) {
        if (gStarted) {
            MV_CC_StopGrabbing(gHandle);
            gStarted = false;
        }
        MV_CC_CloseDevice(gHandle);
        MV_CC_DestroyHandle(gHandle);
        gHandle = nullptr;
    }
    gSerial.clear();
    gModel.clear();
    if (gInitialized) {
        MV_CC_Finalize();
        gInitialized = false;
    }
    while (mexIsLocked()) mexUnlock();
}

void requireOpen() {
    if (!gHandle) fail("Hikrobot:NotOpen", "Hikrobot camera is not open.");
}

MV_CC_DEVICE_INFO_LIST enumerate() {
    ensureInitialized();
    MV_CC_DEVICE_INFO_LIST list{};
    const int code = MV_CC_EnumDevices(MV_GIGE_DEVICE | MV_USB_DEVICE, &list);
    if (code != MV_OK) fail("Hikrobot:Enumerate", "MV_CC_EnumDevices failed.");
    return list;
}

mxArray* discover() {
    const MV_CC_DEVICE_INFO_LIST list = enumerate();
    const char* fields[] = {"serial", "model", "vendor", "transport"};
    mxArray* result = mxCreateStructMatrix(1, list.nDeviceNum, 4, fields);
    for (unsigned int i = 0; i < list.nDeviceNum; ++i) {
        const MV_CC_DEVICE_INFO* device = list.pDeviceInfo[i];
        const std::string serial = serialOf(device);
        const std::string model = modelOf(device);
        const std::string vendor = vendorOf(device);
        const char* transport = device && device->nTLayerType == MV_USB_DEVICE ? "USB3" : "GigE";
        mxSetField(result, i, "serial", mxCreateString(serial.c_str()));
        mxSetField(result, i, "model", mxCreateString(model.c_str()));
        mxSetField(result, i, "vendor", mxCreateString(vendor.c_str()));
        mxSetField(result, i, "transport", mxCreateString(transport));
    }
    if (!gHandle && gInitialized) {
        MV_CC_Finalize();
        gInitialized = false;
    }
    return result;
}

void openCamera(const std::string& requestedSerial) {
    closeCamera();
    const MV_CC_DEVICE_INFO_LIST list = enumerate();
    MV_CC_DEVICE_INFO* selected = nullptr;
    for (unsigned int i = 0; i < list.nDeviceNum; ++i) {
        MV_CC_DEVICE_INFO* device = list.pDeviceInfo[i];
        if (!device) continue;
        const std::string serial = serialOf(device);
        if (requestedSerial.empty() || serial == requestedSerial) {
            selected = device;
            break;
        }
    }
    if (!selected) {
        if (gInitialized) { MV_CC_Finalize(); gInitialized = false; }
        fail("Hikrobot:NotFound", "Requested Hikrobot camera was not found.");
    }
    int code = MV_CC_CreateHandle(&gHandle, selected);
    if (code != MV_OK || !gHandle) fail("Hikrobot:CreateHandle", "MV_CC_CreateHandle failed.");
    code = MV_CC_OpenDevice(gHandle);
    if (code != MV_OK) { closeCamera(); fail("Hikrobot:Open", "MV_CC_OpenDevice failed."); }
    MV_CC_SetImageNodeNum(gHandle, 4);
    MV_CC_SetEnumValue(gHandle, "TriggerMode", MV_TRIGGER_MODE_OFF);
    code = MV_CC_StartGrabbing(gHandle);
    if (code != MV_OK) { closeCamera(); fail("Hikrobot:Start", "MV_CC_StartGrabbing failed."); }
    gStarted = true;
    gSerial = serialOf(selected);
    gModel = modelOf(selected);
    mexLock();
}

mxArray* cameraInfo() {
    const char* fields[] = {"serial", "model", "connected"};
    mxArray* result = mxCreateStructMatrix(1, 1, 3, fields);
    mxSetField(result, 0, "serial", mxCreateString(gSerial.c_str()));
    mxSetField(result, 0, "model", mxCreateString(gModel.c_str()));
    mxSetField(result, 0, "connected", mxCreateLogicalScalar(gHandle && MV_CC_IsDeviceConnected(gHandle)));
    return result;
}

bool copyToRgb(const MV_FRAME_OUT& frame, std::vector<uint8_t>& rgb) {
    const unsigned int width = frame.stFrameInfo.nExtendWidth > 0 ? frame.stFrameInfo.nExtendWidth : frame.stFrameInfo.nWidth;
    const unsigned int height = frame.stFrameInfo.nExtendHeight > 0 ? frame.stFrameInfo.nExtendHeight : frame.stFrameInfo.nHeight;
    if (!frame.pBufAddr || width == 0 || height == 0) return false;
    const auto pixelType = frame.stFrameInfo.enPixelType;
    rgb.resize(static_cast<size_t>(width) * height * 3);
    if (pixelType == PixelType_Gvsp_RGB8_Packed) {
        std::memcpy(rgb.data(), frame.pBufAddr, rgb.size());
        return true;
    }
    if (pixelType == PixelType_Gvsp_BGR8_Packed) {
        for (size_t i = 0; i < static_cast<size_t>(width) * height; ++i) {
            rgb[i*3+0] = frame.pBufAddr[i*3+2];
            rgb[i*3+1] = frame.pBufAddr[i*3+1];
            rgb[i*3+2] = frame.pBufAddr[i*3+0];
        }
        return true;
    }
    if (pixelType == PixelType_Gvsp_Mono8) {
        for (size_t i = 0; i < static_cast<size_t>(width) * height; ++i) {
            const uint8_t v = frame.pBufAddr[i];
            rgb[i*3+0] = v; rgb[i*3+1] = v; rgb[i*3+2] = v;
        }
        return true;
    }
    MV_CC_PIXEL_CONVERT_PARAM convert{};
    convert.nWidth = width;
    convert.nHeight = height;
    convert.pSrcData = frame.pBufAddr;
    convert.nSrcDataLen = frame.stFrameInfo.nFrameLen;
    convert.enSrcPixelType = pixelType;
    convert.enDstPixelType = PixelType_Gvsp_RGB8_Packed;
    convert.pDstBuffer = rgb.data();
    convert.nDstBufferSize = static_cast<unsigned int>(rgb.size());
    return MV_CC_ConvertPixelType(gHandle, &convert) == MV_OK;
}

mxArray* makePreview(unsigned int timeoutMs, unsigned int outWidth, unsigned int outHeight) {
    requireOpen();
    MV_FRAME_OUT newest{};
    const int code = MV_CC_GetImageBuffer(gHandle, &newest, timeoutMs);
    if (code != MV_OK) {
        if (!MV_CC_IsDeviceConnected(gHandle)) {
            fail("Hikrobot:Disconnected", "Hikrobot camera disconnected during acquisition.");
        }
        return mxCreateNumericMatrix(0, 0, mxUINT8_CLASS, mxREAL);
    }

    for (int i = 0; i < 8; ++i) {
        MV_FRAME_OUT next{};
        if (MV_CC_GetImageBuffer(gHandle, &next, 0) != MV_OK) break;
        MV_CC_FreeImageBuffer(gHandle, &newest);
        newest = next;
    }

    const unsigned int srcWidth = newest.stFrameInfo.nExtendWidth > 0 ? newest.stFrameInfo.nExtendWidth : newest.stFrameInfo.nWidth;
    const unsigned int srcHeight = newest.stFrameInfo.nExtendHeight > 0 ? newest.stFrameInfo.nExtendHeight : newest.stFrameInfo.nHeight;
    std::vector<uint8_t> rgb;
    const bool converted = copyToRgb(newest, rgb);
    MV_CC_FreeImageBuffer(gHandle, &newest);
    if (!converted || srcWidth == 0 || srcHeight == 0) {
        fail("Hikrobot:PixelFormat", "Unable to convert Hikrobot frame to RGB8.");
    }

    outWidth = std::max(1u, outWidth);
    outHeight = std::max(1u, outHeight);
    mwSize dims[3] = {static_cast<mwSize>(outHeight), static_cast<mwSize>(outWidth), 3};
    mxArray* output = mxCreateNumericArray(3, dims, mxUINT8_CLASS, mxREAL);
    auto* dst = static_cast<uint8_t*>(mxGetData(output));
    std::fill(dst, dst + static_cast<size_t>(outWidth) * outHeight * 3, 0);

    const double sx = static_cast<double>(outWidth) / srcWidth;
    const double sy = static_cast<double>(outHeight) / srcHeight;
    const double scale = std::min(sx, sy);
    const unsigned int drawWidth = std::max(1u, static_cast<unsigned int>(srcWidth * scale));
    const unsigned int drawHeight = std::max(1u, static_cast<unsigned int>(srcHeight * scale));
    const unsigned int offsetX = (outWidth - drawWidth) / 2;
    const unsigned int offsetY = (outHeight - drawHeight) / 2;
    const size_t plane = static_cast<size_t>(outWidth) * outHeight;

    for (unsigned int y = 0; y < drawHeight; ++y) {
        const unsigned int srcY = std::min(srcHeight - 1, static_cast<unsigned int>(y / scale));
        for (unsigned int x = 0; x < drawWidth; ++x) {
            const unsigned int srcX = std::min(srcWidth - 1, static_cast<unsigned int>(x / scale));
            const size_t srcIndex = (static_cast<size_t>(srcY) * srcWidth + srcX) * 3;
            const unsigned int outX = x + offsetX;
            const unsigned int outY = y + offsetY;
            const size_t matlabIndex = static_cast<size_t>(outY) + static_cast<size_t>(outX) * outHeight;
            dst[matlabIndex] = rgb[srcIndex];
            dst[plane + matlabIndex] = rgb[srcIndex + 1];
            dst[2 * plane + matlabIndex] = rgb[srcIndex + 2];
        }
    }
    return output;
}

void setExposure(double microseconds) {
    requireOpen();
    if (!(microseconds > 0.0)) fail("Hikrobot:Exposure", "Exposure must be positive.");
    MVCC_FLOATVALUE range{};
    const int rangeCode = MV_CC_GetFloatValue(gHandle, "ExposureTime", &range);
    if (rangeCode != MV_OK) fail("Hikrobot:Exposure", "Unable to query ExposureTime range.");
    const double clamped = std::max(static_cast<double>(range.fMin),
                                    std::min(static_cast<double>(range.fMax), microseconds));
    const int autoCode = MV_CC_SetEnumValue(gHandle, "ExposureAuto", MV_EXPOSURE_AUTO_MODE_OFF);
    if (autoCode != MV_OK) fail("Hikrobot:Exposure", "Unable to disable automatic exposure.");
    const int code = MV_CC_SetFloatValue(gHandle, "ExposureTime", static_cast<float>(clamped));
    if (code != MV_OK) fail("Hikrobot:Exposure", "Unable to set ExposureTime.");
}

mxArray* getExposure() {
    requireOpen();
    MVCC_FLOATVALUE value{};
    const int code = MV_CC_GetFloatValue(gHandle, "ExposureTime", &value);
    if (code != MV_OK) fail("Hikrobot:Exposure", "Unable to read ExposureTime.");
    return mxCreateDoubleScalar(value.fCurValue);
}

unsigned int scalarUInt(const mxArray* value, unsigned int fallback) {
    if (!value || mxIsEmpty(value)) return fallback;
    const double v = mxGetScalar(value);
    if (!(v >= 0.0)) return fallback;
    return static_cast<unsigned int>(v);
}
} // namespace

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
    static bool registered = false;
    if (!registered) { mexAtExit(closeCamera); registered = true; }
    if (nrhs < 1) fail("Hikrobot:Input", "Command is required.");
    const std::string command = toText(prhs[0]);

    if (command == "discover") {
        if (nlhs > 0) plhs[0] = discover();
        return;
    }
    if (command == "open") {
        const std::string serial = nrhs >= 2 ? toText(prhs[1]) : std::string();
        openCamera(serial);
        if (nlhs > 0) plhs[0] = cameraInfo();
        return;
    }
    if (command == "info") {
        requireOpen();
        if (nlhs > 0) plhs[0] = cameraInfo();
        return;
    }
    if (command == "read") {
        const unsigned int timeoutMs = nrhs >= 2 ? scalarUInt(prhs[1], 20) : 20;
        const unsigned int outWidth = nrhs >= 3 ? scalarUInt(prhs[2], 1280) : 1280;
        const unsigned int outHeight = nrhs >= 4 ? scalarUInt(prhs[3], 720) : 720;
        if (nlhs > 0) plhs[0] = makePreview(timeoutMs, outWidth, outHeight);
        return;
    }
    if (command == "setExposure") {
        if (nrhs < 2) fail("Hikrobot:Input", "Exposure value is required.");
        setExposure(mxGetScalar(prhs[1]));
        if (nlhs > 0) plhs[0] = getExposure();
        return;
    }
    if (command == "getExposure") {
        if (nlhs > 0) plhs[0] = getExposure();
        return;
    }
    if (command == "close") {
        closeCamera();
        return;
    }
    fail("Hikrobot:Command", "Unknown hikrobot_mex command: " + command);
}
