#include "DvsenseDriver/camera/DvsCameraManager.hpp"
#include "MvCameraControl.h"

#include <atomic>
#include <chrono>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>

namespace {

struct Options {
    int durationSeconds = 5;
    std::string hikSerial;
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
        options.hikSerial = argv[2];
    }
    return options;
}

std::string errorCode(int code) {
    std::ostringstream output;
    output << "0x" << std::hex << std::uppercase
           << static_cast<unsigned int>(code);
    return output.str();
}

std::string text(const unsigned char* value, size_t capacity) {
    size_t length = 0;
    while (length < capacity && value[length] != 0) {
        ++length;
    }
    return std::string(reinterpret_cast<const char*>(value), length);
}

int openDvs(
    dvsense::DvsCameraManager& manager,
    dvsense::CameraDevice& camera,
    dvsense::CameraDescription& description) {
    const int updatedCount = manager.updateCameras();
    const auto descriptions = manager.getCameraDescs();
    std::cout << "dvs_discovery"
              << " update_return=" << updatedCount
              << " count=" << descriptions.size() << "\n";

    for (const auto& candidate : descriptions) {
        std::cout << "dvs_candidate"
                  << " product=" << candidate.product
                  << " serial="
                  << (candidate.serial.empty() ? "<empty>" : candidate.serial)
                  << "\n";
        if (candidate.product == "DVSync") {
            continue;
        }
        description = candidate;
        camera = manager.openCamera(candidate.serial);
        if (camera && camera->isConnected()) {
            return 0;
        }
    }

    description = {};
    description.product = "DVSLume";
    description.serial = "ffffffffffffffab";
    std::cout << "dvs_fallback serial=" << description.serial << "\n";
    camera = manager.openCamera(description.serial);
    if (!camera) {
        return 1;
    }
    return camera->isConnected() ? 0 : 2;
}

int openHik(
    const std::string& requestedSerial,
    void*& handle,
    std::string& selectedSerial) {
    int result = MV_CC_Initialize();
    std::cout << "hik_initialize_result=" << errorCode(result) << "\n";
    if (result != MV_OK) {
        return 10;
    }

    MV_CC_DEVICE_INFO_LIST deviceList{};
    result = MV_CC_EnumDevices(MV_USB_DEVICE, &deviceList);
    std::cout << "hik_enum_result=" << errorCode(result)
              << " count=" << deviceList.nDeviceNum << "\n";
    if (result != MV_OK || deviceList.nDeviceNum == 0) {
        return 11;
    }

    int selectedIndex = -1;
    for (unsigned int index = 0; index < deviceList.nDeviceNum; ++index) {
        auto* device = deviceList.pDeviceInfo[index];
        if (device == nullptr) {
            continue;
        }
        const auto& usb = device->SpecialInfo.stUsb3VInfo;
        const std::string serial =
            text(usb.chSerialNumber, sizeof(usb.chSerialNumber));
        std::cout << "hik_candidate"
                  << " model=" << text(usb.chModelName, sizeof(usb.chModelName))
                  << " serial=" << serial << "\n";
        if (selectedIndex >= 0) {
            continue;
        }
        if (requestedSerial.empty() || requestedSerial == serial) {
            selectedIndex = static_cast<int>(index);
            selectedSerial = serial;
        }
    }

    if (selectedIndex < 0) {
        return 12;
    }

    result = MV_CC_CreateHandle(
        &handle, deviceList.pDeviceInfo[static_cast<unsigned int>(selectedIndex)]);
    std::cout << "hik_create_handle_result=" << errorCode(result) << "\n";
    if (result != MV_OK || handle == nullptr) {
        return 13;
    }

    result = MV_CC_OpenDevice(handle);
    std::cout << "hik_open_result=" << errorCode(result)
              << " connected="
              << (result == MV_OK && MV_CC_IsDeviceConnected(handle) ? "true" : "false")
              << "\n";
    if (result != MV_OK) {
        return 14;
    }

    result = MV_CC_SetImageNodeNum(handle, 10);
    std::cout << "hik_set_image_node_result=" << errorCode(result) << "\n";
    if (result != MV_OK) {
        return 15;
    }

    result = MV_CC_SetEnumValue(handle, "TriggerMode", MV_TRIGGER_MODE_OFF);
    std::cout << "hik_set_trigger_off_result=" << errorCode(result) << "\n";
    if (result != MV_OK) {
        return 16;
    }

    result = MV_CC_StartGrabbing(handle);
    std::cout << "hik_start_result=" << errorCode(result) << "\n";
    return result == MV_OK ? 0 : 17;
}

}  // namespace

int main(int argc, char** argv) {
    const Options options = parseOptions(argc, argv);
    std::cout << "dual_camera_connection_smoke"
              << " duration_s=" << options.durationSeconds
              << " hik_serial="
              << (options.hikSerial.empty() ? "<any>" : options.hikSerial)
              << "\n";

    dvsense::DvsCameraManager dvsManager;
    dvsense::CameraDevice dvsCamera;
    dvsense::CameraDescription dvsDescription;
    const int dvsOpenResult =
        openDvs(dvsManager, dvsCamera, dvsDescription);
    if (dvsOpenResult != 0) {
        std::cerr << "result=DVS_OPEN_FAILED stage=" << dvsOpenResult << "\n";
        return 10 + dvsOpenResult;
    }

    std::cout << "dvs_opened"
              << " product=" << dvsDescription.product
              << " serial=" << dvsDescription.serial
              << " connected=" << (dvsCamera->isConnected() ? "true" : "false")
              << " size=" << dvsCamera->getWidth()
              << "x" << dvsCamera->getHeight()
              << "\n";

    std::atomic<uint64_t> dvsEvents{0};
    const uint32_t dvsCallbackId =
        dvsCamera->addEventsStreamHandleCallback(
            [&dvsEvents](const dvsense::Event2D* begin,
                         const dvsense::Event2D* end) {
                dvsEvents.fetch_add(
                    static_cast<uint64_t>(end - begin),
                    std::memory_order_relaxed);
            });
    const int dvsStartResult = dvsCamera->start();
    std::cout << "dvs_start_result=" << dvsStartResult << "\n";
    if (dvsStartResult != 0) {
        dvsCamera->removeEventsStreamHandleCallback(dvsCallbackId);
        std::cerr << "result=DVS_START_FAILED\n";
        return 20;
    }

    void* hikHandle = nullptr;
    std::string hikSerial;
    const int hikOpenResult =
        openHik(options.hikSerial, hikHandle, hikSerial);
    if (hikOpenResult != 0) {
        dvsCamera->stop();
        dvsCamera->removeEventsStreamHandleCallback(dvsCallbackId);
        if (hikHandle != nullptr) {
            MV_CC_CloseDevice(hikHandle);
            MV_CC_DestroyHandle(hikHandle);
        }
        MV_CC_Finalize();
        std::cerr << "result=HIK_OPEN_FAILED stage=" << hikOpenResult << "\n";
        return 30 + hikOpenResult;
    }

    std::cout << "hik_opened"
              << " serial=" << hikSerial
              << " connected="
              << (MV_CC_IsDeviceConnected(hikHandle) ? "true" : "false")
              << "\n";

    uint64_t hikFrames = 0;
    uint64_t hikNonEmptyFrames = 0;
    unsigned int firstWidth = 0;
    unsigned int firstHeight = 0;
    unsigned int firstBytes = 0;
    uint32_t firstFrameNumber = 0;
    uint32_t lastFrameNumber = 0;
    uint64_t hikFrameGaps = 0;
    bool hasFirstFrame = false;

    const auto startedAt = std::chrono::steady_clock::now();
    while (std::chrono::steady_clock::now() - startedAt <
           std::chrono::seconds(options.durationSeconds)) {
        MV_FRAME_OUT frame{};
        const int frameResult = MV_CC_GetImageBuffer(hikHandle, &frame, 1000);
        if (frameResult != MV_OK) {
            continue;
        }

        ++hikFrames;
        if (frame.pBufAddr != nullptr && frame.stFrameInfo.nFrameLen > 0) {
            ++hikNonEmptyFrames;
            if (!hasFirstFrame) {
                hasFirstFrame = true;
                firstFrameNumber = frame.stFrameInfo.nFrameNum;
                firstWidth = frame.stFrameInfo.nExtendWidth > 0
                                 ? frame.stFrameInfo.nExtendWidth
                                 : frame.stFrameInfo.nWidth;
                firstHeight = frame.stFrameInfo.nExtendHeight > 0
                                  ? frame.stFrameInfo.nExtendHeight
                                  : frame.stFrameInfo.nHeight;
                firstBytes = frame.stFrameInfo.nFrameLen;
                std::cout << "hik_first_frame"
                          << " number=" << firstFrameNumber
                          << " size=" << firstWidth << "x" << firstHeight
                          << " bytes=" << firstBytes
                          << "\n";
            } else if (frame.stFrameInfo.nFrameNum > lastFrameNumber + 1) {
                hikFrameGaps +=
                    frame.stFrameInfo.nFrameNum - lastFrameNumber - 1;
            }
            lastFrameNumber = frame.stFrameInfo.nFrameNum;
        }
        MV_CC_FreeImageBuffer(hikHandle, &frame);
    }

    const int hikStopResult = MV_CC_StopGrabbing(hikHandle);
    const bool hikConnectedBeforeClose = MV_CC_IsDeviceConnected(hikHandle);
    const int hikCloseResult = MV_CC_CloseDevice(hikHandle);
    const int hikDestroyResult = MV_CC_DestroyHandle(hikHandle);
    const int hikFinalizeResult = MV_CC_Finalize();
    const int dvsStopResult = dvsCamera->stop();
    dvsCamera->removeEventsStreamHandleCallback(dvsCallbackId);
    const bool dvsConnectedBeforeClose = dvsCamera->isConnected();

    std::cout << "dual_stream_summary"
              << " dvs_events=" << dvsEvents.load()
              << " dvs_stop_result=" << dvsStopResult
              << " dvs_connected_before_close="
              << (dvsConnectedBeforeClose ? "true" : "false")
              << " hik_frames=" << hikFrames
              << " hik_nonempty_frames=" << hikNonEmptyFrames
              << " hik_frame_gaps=" << hikFrameGaps
              << " hik_first_frame_number=" << firstFrameNumber
              << " hik_first_size=" << firstWidth << "x" << firstHeight
              << " hik_first_bytes=" << firstBytes
              << " hik_stop_result=" << errorCode(hikStopResult)
              << " hik_connected_before_close="
              << (hikConnectedBeforeClose ? "true" : "false")
              << " hik_close_result=" << errorCode(hikCloseResult)
              << " hik_destroy_result=" << errorCode(hikDestroyResult)
              << " hik_finalize_result=" << errorCode(hikFinalizeResult)
              << "\n";

    if (dvsEvents.load() == 0) {
        std::cerr << "result=NO_DVS_EVENTS\n";
        return 40;
    }
    if (hikNonEmptyFrames == 0) {
        std::cerr << "result=NO_HIK_FRAMES\n";
        return 41;
    }
    if (hikFrameGaps != 0) {
        std::cerr << "result=HIK_FRAME_GAPS_DETECTED\n";
        return 42;
    }
    if (!dvsConnectedBeforeClose || !hikConnectedBeforeClose) {
        std::cerr << "result=DISCONNECTED_BEFORE_CLOSE\n";
        return 43;
    }

    std::cout << "result=PASS\n";
    return 0;
}
