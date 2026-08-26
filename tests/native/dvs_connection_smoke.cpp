#include "DvsenseDriver/camera/DvsCameraManager.hpp"

#include <atomic>
#include <chrono>
#include <iomanip>
#include <iostream>
#include <memory>
#include <string>
#include <thread>
#include <vector>

namespace {

struct Options {
    int durationSeconds = 5;
};

int parseDuration(int argc, char** argv) {
    if (argc < 2) {
        return 5;
    }
    try {
        const int value = std::stoi(argv[1]);
        return value > 0 ? value : 5;
    } catch (...) {
        return 5;
    }
}

void printDescription(const dvsense::CameraDescription& description) {
    std::cout << "dvs_description"
              << " product=" << description.product
              << " serial=" << (description.serial.empty() ? "<empty>" : description.serial)
              << " manufacturer=" << description.manufacturer
              << " vid=0x" << std::hex << std::setw(4) << std::setfill('0')
              << description.vid
              << " pid=0x" << std::setw(4) << description.pid
              << std::dec << std::setfill(' ')
              << " interface=" << static_cast<int>(description.interfaceType)
              << "\n";
}

}  // namespace

int main(int argc, char** argv) {
    const Options options{parseDuration(argc, argv)};
    std::cout << "dvs_connection_smoke"
              << " duration_s=" << options.durationSeconds << "\n";

    try {
        dvsense::DvsCameraManager manager;
        const int updatedCount = manager.updateCameras();
        const auto descriptions = manager.getCameraDescs();

        std::cout << "updateCameras_return=" << updatedCount
                  << " descriptions_count=" << descriptions.size() << "\n";
        for (const auto& description : descriptions) {
            printDescription(description);
        }

        std::vector<dvsense::CameraDescription> candidates = descriptions;
        if (candidates.empty()) {
            dvsense::CameraDescription emptySerialCandidate{};
            emptySerialCandidate.product = "unknown";
            candidates.push_back(emptySerialCandidate);
            std::cout << "dvs_fallback_candidate serial=<empty>\n";
        }

        bool hasHistoricalSerial = false;
        for (const auto& candidate : candidates) {
            if (candidate.serial == "ffffffffffffffab") {
                hasHistoricalSerial = true;
                break;
            }
        }
        if (!hasHistoricalSerial) {
            dvsense::CameraDescription historicalSerialCandidate{};
            historicalSerialCandidate.product = "historical_success_serial";
            historicalSerialCandidate.serial = "ffffffffffffffab";
            candidates.push_back(historicalSerialCandidate);
            std::cout << "dvs_fallback_candidate serial=ffffffffffffffab\n";
        }

        for (size_t index = 0; index < candidates.size(); ++index) {
            const auto& candidate = candidates[index];
            std::cout << "open_attempt index=" << index
                      << " product=" << (candidate.product.empty() ? "<empty>" : candidate.product)
                      << " serial=" << (candidate.serial.empty() ? "<empty>" : candidate.serial)
                      << "\n";

            dvsense::CameraDevice camera;
            try {
                camera = manager.openCamera(candidate.serial);
            } catch (const std::exception& error) {
                std::cout << "open_result=exception message=" << error.what() << "\n";
                continue;
            }

            if (!camera) {
                std::cout << "open_result=null\n";
                continue;
            }

            std::cout << "open_result=handle"
                      << " connected=" << (camera->isConnected() ? "true" : "false")
                      << " product=" << camera->getDescription().product
                      << " serial="
                      << (camera->getDescription().serial.empty()
                              ? "<empty>"
                              : camera->getDescription().serial)
                      << " size=" << camera->getWidth()
                      << "x" << camera->getHeight()
                      << "\n";

            if (!camera->isConnected()) {
                std::cout << "connection_result=not_connected\n";
                continue;
            }

            std::atomic<uint64_t> eventCount{0};
            const uint32_t callbackId =
                camera->addEventsStreamHandleCallback(
                    [&eventCount](const dvsense::Event2D* begin,
                                  const dvsense::Event2D* end) {
                        eventCount.fetch_add(
                            static_cast<uint64_t>(end - begin),
                            std::memory_order_relaxed);
                    });

            const int startResult = camera->start();
            std::cout << "start_result=" << startResult << "\n";
            if (startResult != 0) {
                camera->removeEventsStreamHandleCallback(callbackId);
                continue;
            }

            std::this_thread::sleep_for(
                std::chrono::seconds(options.durationSeconds));

            const int stopResult = camera->stop();
            camera->removeEventsStreamHandleCallback(callbackId);
            std::cout << "stream_result"
                      << " events=" << eventCount.load()
                      << " stop_result=" << stopResult
                      << " connected_before_close="
                      << (camera->isConnected() ? "true" : "false")
                      << "\n";

            if (eventCount.load() > 0) {
                std::cout << "result=PASS\n";
                return 0;
            }
            std::cout << "result=CONNECTED_BUT_NO_EVENTS\n";
            return 20;
        }

        std::cerr << "result=OPEN_FAILED\n";
        return 10;
    } catch (const std::exception& error) {
        std::cerr << "result=SDK_EXCEPTION message=" << error.what() << "\n";
        return 11;
    } catch (...) {
        std::cerr << "result=UNKNOWN_EXCEPTION\n";
        return 12;
    }
}
