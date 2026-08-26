#include "MvCameraControl.h"

#include <chrono>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>

namespace {

struct Options {
    int durationSeconds = 5;
    std::string requestedSerial;
};

Options parseOptions(int argc, char** argv) {
    Options options;
    if (argc > 1) {
        try {
            const int value = std::stoi(argv[1]);
            if (value > 0) {
                options.durationSeconds = value;
            }
        } catch (...) {
        }
    }
    if (argc > 2 && argv[2] != nullptr) {
        options.requestedSerial = argv[2];
    }
    return options;
}

std::string text(const unsigned char* value, size_t capacity) {
    size_t length = 0;
    while (length < capacity && value[length] != 0) {
        ++length;
    }
    return std::string(reinterpret_cast<const char*>(value), length);
}

std::string errorCode(int code) {
    std::ostringstream output;
    output << "0x" << std::hex << std::uppercase
           << static_cast<unsigned int>(code);
    return output.str();
}

void printDevice(unsigned int index, MV_CC_DEVICE_INFO* device) {
    if (device == nullptr) {
        std::cout << "device[" << index << "] <null>\n";
        return;
    }
    const auto& usb = device->SpecialInfo.stUsb3VInfo;
    std::cout << "device[" << index << "]"
              << " transport=0x" << std::hex << device->nTLayerType
              << std::dec
              << " vendor=" << text(usb.chVendorName, sizeof(usb.chVendorName))
              << " model=" << text(usb.chModelName, sizeof(usb.chModelName))
              << " manufacturer="
              << text(usb.chManufacturerName, sizeof(usb.chManufacturerName))
              << " serial=" << text(usb.chSerialNumber, sizeof(usb.chSerialNumber))
              << " device_version="
              << text(usb.chDeviceVersion, sizeof(usb.chDeviceVersion))
              << "\n";
}

}  // namespace

int main(int argc, char** argv) {
    const Options options = parseOptions(argc, argv);
    std::cout << "hik_connection_smoke"
              << " duration_s=" << options.durationSeconds
              << " requested_serial="
              << (options.requestedSerial.empty() ? "<any>" : options.requestedSerial)
              << "\n";

    int result = MV_CC_Initialize();
    std::cout << "initialize_result=" << errorCode(result) << "\n";
    if (result != MV_OK) {
        std::cerr << "result=INITIALIZE_FAILED\n";
        return 10;
    }

    void* handle = nullptr;
    MV_CC_DEVICE_INFO_LIST deviceList{};
    result = MV_CC_EnumDevices(MV_USB_DEVICE, &deviceList);
    std::cout << "enum_result=" << errorCode(result)
              << " device_count=" << deviceList.nDeviceNum << "\n";
    if (result != MV_OK || deviceList.nDeviceNum == 0) {
        MV_CC_Finalize();
        std::cerr << "result=ENUM_FAILED\n";
        return 11;
    }

    int selectedIndex = -1;
    for (unsigned int index = 0; index < deviceList.nDeviceNum; ++index) {
        printDevice(index, deviceList.pDeviceInfo[index]);
        if (selectedIndex >= 0 || deviceList.pDeviceInfo[index] == nullptr) {
            continue;
        }
        const std::string serial = text(
            deviceList.pDeviceInfo[index]->SpecialInfo.stUsb3VInfo.chSerialNumber,
            sizeof(deviceList.pDeviceInfo[index]->SpecialInfo.stUsb3VInfo.chSerialNumber));
        if (options.requestedSerial.empty() || serial == options.requestedSerial) {
            selectedIndex = static_cast<int>(index);
        }
    }

    if (selectedIndex < 0) {
        MV_CC_Finalize();
        std::cerr << "result=REQUESTED_SERIAL_NOT_FOUND\n";
        return 12;
    }

    result = MV_CC_CreateHandle(
        &handle, deviceList.pDeviceInfo[static_cast<unsigned int>(selectedIndex)]);
    std::cout << "create_handle_result=" << errorCode(result) << "\n";
    if (result != MV_OK || handle == nullptr) {
        MV_CC_Finalize();
        std::cerr << "result=CREATE_HANDLE_FAILED\n";
        return 13;
    }

    result = MV_CC_OpenDevice(handle);
    std::cout << "open_device_result=" << errorCode(result)
              << " connected="
              << (result == MV_OK && MV_CC_IsDeviceConnected(handle) ? "true" : "false")
              << "\n";
    if (result != MV_OK) {
        MV_CC_DestroyHandle(handle);
        MV_CC_Finalize();
        std::cerr << "result=OPEN_FAILED\n";
        return 14;
    }

    MVCC_FLOATVALUE exposureBefore{};
    result = MV_CC_GetFloatValue(handle, "ExposureTime", &exposureBefore);
    std::cout << "get_exposure_result=" << errorCode(result)
              << " exposure_us=" << exposureBefore.fCurValue << "\n";
    if (result != MV_OK) {
        MV_CC_CloseDevice(handle);
        MV_CC_DestroyHandle(handle);
        MV_CC_Finalize();
        std::cerr << "result=EXPOSURE_READ_FAILED\n";
        return 22;
    }
    result = MV_CC_SetFloatValue(handle, "ExposureTime", exposureBefore.fCurValue);
    std::cout << "set_exposure_result=" << errorCode(result) << "\n";
    if (result != MV_OK) {
        MV_CC_CloseDevice(handle);
        MV_CC_DestroyHandle(handle);
        MV_CC_Finalize();
        std::cerr << "result=EXPOSURE_WRITE_FAILED\n";
        return 23;
    }
    MVCC_FLOATVALUE exposureAfter{};
    result = MV_CC_GetFloatValue(handle, "ExposureTime", &exposureAfter);
    std::cout << "exposure_readback_result=" << errorCode(result)
              << " exposure_us=" << exposureAfter.fCurValue << "\n";
    if (result != MV_OK) {
        MV_CC_CloseDevice(handle);
        MV_CC_DestroyHandle(handle);
        MV_CC_Finalize();
        std::cerr << "result=EXPOSURE_READBACK_FAILED\n";
        return 24;
    }

    result = MV_CC_SetImageNodeNum(handle, 10);
    std::cout << "set_image_node_result=" << errorCode(result) << "\n";
    if (result != MV_OK) {
        MV_CC_CloseDevice(handle);
        MV_CC_DestroyHandle(handle);
        MV_CC_Finalize();
        std::cerr << "result=IMAGE_NODE_SETUP_FAILED\n";
        return 15;
    }

    result = MV_CC_SetEnumValue(handle, "TriggerMode", MV_TRIGGER_MODE_OFF);
    std::cout << "set_trigger_off_result=" << errorCode(result) << "\n";
    if (result != MV_OK) {
        MV_CC_CloseDevice(handle);
        MV_CC_DestroyHandle(handle);
        MV_CC_Finalize();
        std::cerr << "result=TRIGGER_SETUP_FAILED\n";
        return 16;
    }

    result = MV_CC_StartGrabbing(handle);
    std::cout << "start_grabbing_result=" << errorCode(result) << "\n";
    if (result != MV_OK) {
        MV_CC_CloseDevice(handle);
        MV_CC_DestroyHandle(handle);
        MV_CC_Finalize();
        std::cerr << "result=START_GRABBING_FAILED\n";
        return 17;
    }

    uint64_t frameCount = 0;
    uint64_t nonEmptyFrameCount = 0;
    uint32_t firstFrameNumber = 0;
    unsigned int firstWidth = 0;
    unsigned int firstHeight = 0;
    unsigned int firstFrameLength = 0;
    uint32_t lastFrameNumber = 0;
    bool hasFirstFrame = false;
    uint64_t frameGapCount = 0;
    const auto startedAt = std::chrono::steady_clock::now();
    while (std::chrono::steady_clock::now() - startedAt <
           std::chrono::seconds(options.durationSeconds)) {
        MV_FRAME_OUT frame{};
        result = MV_CC_GetImageBuffer(handle, &frame, 1000);
        if (result != MV_OK) {
            continue;
        }

        ++frameCount;
        if (frame.pBufAddr != nullptr && frame.stFrameInfo.nFrameLen > 0) {
            ++nonEmptyFrameCount;
            if (!hasFirstFrame) {
                hasFirstFrame = true;
                firstFrameNumber = frame.stFrameInfo.nFrameNum;
                firstWidth = frame.stFrameInfo.nExtendWidth > 0
                                 ? frame.stFrameInfo.nExtendWidth
                                 : frame.stFrameInfo.nWidth;
                firstHeight = frame.stFrameInfo.nExtendHeight > 0
                                  ? frame.stFrameInfo.nExtendHeight
                                  : frame.stFrameInfo.nHeight;
                firstFrameLength = frame.stFrameInfo.nFrameLen;
                std::cout << "first_frame"
                          << " number=" << firstFrameNumber
                          << " size=" << firstWidth << "x" << firstHeight
                          << " bytes=" << firstFrameLength
                          << " pixel_type=" << static_cast<unsigned int>(
                                 frame.stFrameInfo.enPixelType)
                          << "\n";
            } else if (frame.stFrameInfo.nFrameNum > lastFrameNumber + 1) {
                frameGapCount +=
                    frame.stFrameInfo.nFrameNum - lastFrameNumber - 1;
            }
            lastFrameNumber = frame.stFrameInfo.nFrameNum;
        }

        const int freeResult = MV_CC_FreeImageBuffer(handle, &frame);
        if (freeResult != MV_OK) {
            std::cout << "free_image_buffer_error=" << errorCode(freeResult) << "\n";
        }
    }

    const int stopResult = MV_CC_StopGrabbing(handle);
    const bool connectedBeforeClose = MV_CC_IsDeviceConnected(handle);
    const int closeResult = MV_CC_CloseDevice(handle);
    const int destroyResult = MV_CC_DestroyHandle(handle);
    const int finalizeResult = MV_CC_Finalize();

    std::cout << "stream_summary"
              << " frames=" << frameCount
              << " nonempty_frames=" << nonEmptyFrameCount
              << " frame_gap_count=" << frameGapCount
              << " first_frame_number=" << firstFrameNumber
              << " first_size=" << firstWidth << "x" << firstHeight
              << " first_bytes=" << firstFrameLength
              << " stop_result=" << errorCode(stopResult)
              << " connected_before_close=" << (connectedBeforeClose ? "true" : "false")
              << " close_result=" << errorCode(closeResult)
              << " destroy_result=" << errorCode(destroyResult)
              << " finalize_result=" << errorCode(finalizeResult)
              << "\n";

    if (nonEmptyFrameCount == 0) {
        std::cerr << "result=NO_FRAMES\n";
        return 20;
    }
    if (frameGapCount != 0) {
        std::cerr << "result=FRAME_GAPS_DETECTED\n";
        return 21;
    }

    std::cout << "result=PASS\n";
    return 0;
}
