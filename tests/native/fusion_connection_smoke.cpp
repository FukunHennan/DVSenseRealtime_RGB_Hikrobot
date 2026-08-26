#include "DvsRgbFusionCamera/CameraManager/DvsRgbFusionCamera.hpp"
#include "DvsRgbFusionCamera/rgb/hik/HikCamera.hpp"

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace {

struct Options {
    int durationSeconds = 10;
    int maxFrameGapMs = 1000;
    uint64_t minimumEvents = 1;
    uint64_t minimumFrames = 5;
};

struct StreamStats {
    std::atomic<uint64_t> eventPackets{0};
    std::atomic<uint64_t> eventCount{0};
    std::atomic<uint64_t> rgbFrames{0};
    std::atomic<uint64_t> nonEmptyRgbFrames{0};
    std::atomic<uint64_t> maxFrameGapMs{0};
    std::atomic<uint64_t> firstRgbBytes{0};
    std::atomic<int> firstRgbWidth{0};
    std::atomic<int> firstRgbHeight{0};
    std::mutex timestampMutex;
    std::chrono::steady_clock::time_point lastFrameTime{};
    bool hasLastFrame = false;
};

int parseInt(const char* value, int fallback) {
    try {
        const int parsed = std::stoi(value);
        return parsed > 0 ? parsed : fallback;
    } catch (...) {
        return fallback;
    }
}

uint64_t parseUint64(const char* value, uint64_t fallback) {
    try {
        const auto parsed = std::stoull(value);
        return parsed > 0 ? parsed : fallback;
    } catch (...) {
        return fallback;
    }
}

Options parseOptions(int argc, char** argv) {
    Options options;
    if (argc > 1) options.durationSeconds = parseInt(argv[1], options.durationSeconds);
    if (argc > 2) options.maxFrameGapMs = parseInt(argv[2], options.maxFrameGapMs);
    if (argc > 3) options.minimumEvents = parseUint64(argv[3], options.minimumEvents);
    if (argc > 4) options.minimumFrames = parseUint64(argv[4], options.minimumFrames);
    return options;
}

void printCameraDescriptions(
    const std::vector<dvsense::CameraDescription>& dvsCameras,
    const std::vector<std::string>& rgbSerials) {
    std::cout << "DVS cameras found: " << dvsCameras.size() << "\n";
    for (size_t index = 0; index < dvsCameras.size(); ++index) {
        const auto& camera = dvsCameras[index];
        std::cout << "  DVS[" << index << "]"
                  << " product=" << camera.product
                  << " serial=" << camera.serial
                  << " manufacturer=" << camera.manufacturer
                  << " vid=0x" << std::hex << std::setw(4) << std::setfill('0')
                  << camera.vid
                  << " pid=0x" << std::setw(4) << camera.pid
                  << std::dec << std::setfill(' ')
                  << " interfaceType=" << static_cast<int>(camera.interfaceType)
                  << "\n";
    }

    std::cout << "RGB cameras found: " << rgbSerials.size() << "\n";
    for (size_t index = 0; index < rgbSerials.size(); ++index) {
        std::cout << "  RGB[" << index << "] serial=" << rgbSerials[index] << "\n";
    }
}

}  // namespace

int main(int argc, char** argv) {
    const Options options = parseOptions(argc, argv);
    std::cout << "fusion_connection_smoke"
              << " duration_s=" << options.durationSeconds
              << " max_frame_gap_ms=" << options.maxFrameGapMs
              << " minimum_events=" << options.minimumEvents
              << " minimum_frames=" << options.minimumFrames << "\n";

    auto fusionCamera =
        std::make_unique<DvsRgbFusionCamera<HikCamera>>(30.0F);
    std::vector<dvsense::CameraDescription> dvsCameras;
    std::vector<std::string> rgbSerials;

    if (!fusionCamera->findCamera(dvsCameras, rgbSerials)) {
        std::cerr << "connection_error=findCamera_failed\n";
        return 10;
    }
    printCameraDescriptions(dvsCameras, rgbSerials);
    if (dvsCameras.empty() || rgbSerials.empty()) {
        std::cerr << "connection_error=one_or_both_camera_lists_empty\n";
        return 11;
    }

    DvsRgbCameraSerial serials;
    serials.dvs_serial_number = dvsCameras.front();
    serials.rgb_serial_number = rgbSerials.front();
    std::cout << "selected_dvs_product=" << serials.dvs_serial_number.product
              << " selected_dvs_serial=" << serials.dvs_serial_number.serial
              << " selected_rgb_serial=" << serials.rgb_serial_number << "\n";

    if (!fusionCamera->openCamera(serials)) {
        std::cerr << "connection_error=openCamera_failed\n";
        fusionCamera->destroy();
        return 12;
    }
    if (!fusionCamera->isConnected()) {
        std::cerr << "connection_error=isConnected_false_after_open\n";
        fusionCamera->destroy();
        return 13;
    }

    const uint16_t dvsWidth = fusionCamera->getWidth(dvsense::DVS_STREAM);
    const uint16_t dvsHeight = fusionCamera->getHeight(dvsense::DVS_STREAM);
    const uint16_t rgbWidth = fusionCamera->getWidth(dvsense::APS_STREAM);
    const uint16_t rgbHeight = fusionCamera->getHeight(dvsense::APS_STREAM);
    std::cout << "opened=true"
              << " dvs_size=" << dvsWidth << "x" << dvsHeight
              << " rgb_size=" << rgbWidth << "x" << rgbHeight << "\n";

    StreamStats stats;
    const uint32_t eventCallbackId =
        fusionCamera->addEventsStreamHandleCallback(
            [&stats](dvsense::EventIterator_t begin,
                     dvsense::EventIterator_t end) {
                uint64_t batchSize = 0;
                for (auto it = begin; it != end; ++it) {
                    ++batchSize;
                }
                if (batchSize > 0) {
                    stats.eventPackets.fetch_add(1, std::memory_order_relaxed);
                    stats.eventCount.fetch_add(batchSize, std::memory_order_relaxed);
                }
            });
    const int frameCallbackId = fusionCamera->addApsFrameCallback(
        [&stats](const dvsense::ApsFrame& frame) {
            stats.rgbFrames.fetch_add(1, std::memory_order_relaxed);
            if (frame.getDataSize() == 0) {
                return;
            }

            stats.nonEmptyRgbFrames.fetch_add(1, std::memory_order_relaxed);
            uint64_t expected = 0;
            stats.firstRgbBytes.compare_exchange_strong(
                expected, static_cast<uint64_t>(frame.getDataSize()));
            int expectedWidth = 0;
            stats.firstRgbWidth.compare_exchange_strong(expectedWidth, frame.width());
            int expectedHeight = 0;
            stats.firstRgbHeight.compare_exchange_strong(expectedHeight, frame.height());

            const auto now = std::chrono::steady_clock::now();
            std::lock_guard<std::mutex> lock(stats.timestampMutex);
            if (stats.hasLastFrame) {
                const auto gap = std::chrono::duration_cast<std::chrono::milliseconds>(
                    now - stats.lastFrameTime).count();
                auto previous = stats.maxFrameGapMs.load(std::memory_order_relaxed);
                while (static_cast<uint64_t>(gap) > previous &&
                       !stats.maxFrameGapMs.compare_exchange_weak(
                           previous, static_cast<uint64_t>(gap),
                           std::memory_order_relaxed)) {
                }
            }
            stats.lastFrameTime = now;
            stats.hasLastFrame = true;
        });

    const int startResult = fusionCamera->start(dvsense::FUSION_STREAM);
    if (startResult != 0) {
        std::cerr << "stream_error=start_failed code=" << startResult << "\n";
        fusionCamera->removeEventsStreamHandleCallback(eventCallbackId);
        fusionCamera->removeApsFrameCallback(frameCallbackId);
        fusionCamera->destroy();
        return 14;
    }

    const auto startedAt = std::chrono::steady_clock::now();
    auto nextReport = startedAt + std::chrono::seconds(1);
    while (std::chrono::steady_clock::now() - startedAt <
           std::chrono::seconds(options.durationSeconds)) {
        const auto now = std::chrono::steady_clock::now();
        if (now >= nextReport) {
            std::cout << "progress"
                      << " events=" << stats.eventCount.load()
                      << " event_packets=" << stats.eventPackets.load()
                      << " rgb_frames=" << stats.rgbFrames.load()
                      << " nonempty_rgb_frames=" << stats.nonEmptyRgbFrames.load()
                      << " max_frame_gap_ms=" << stats.maxFrameGapMs.load()
                      << "\n";
            nextReport += std::chrono::seconds(1);
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }

    fusionCamera->stop(dvsense::FUSION_STREAM);
    fusionCamera->removeEventsStreamHandleCallback(eventCallbackId);
    fusionCamera->removeApsFrameCallback(frameCallbackId);
    const bool stillConnected = fusionCamera->isConnected();
    fusionCamera->destroy();

    const auto events = stats.eventCount.load();
    const auto frames = stats.nonEmptyRgbFrames.load();
    const auto maxGap = stats.maxFrameGapMs.load();
    std::cout << "summary"
              << " events=" << events
              << " event_packets=" << stats.eventPackets.load()
              << " rgb_frames=" << stats.rgbFrames.load()
              << " nonempty_rgb_frames=" << frames
              << " first_rgb_size=" << stats.firstRgbWidth.load()
              << "x" << stats.firstRgbHeight.load()
              << " first_rgb_bytes=" << stats.firstRgbBytes.load()
              << " max_frame_gap_ms=" << maxGap
              << " connected_before_close=" << (stillConnected ? "true" : "false")
              << "\n";

    if (events < options.minimumEvents) {
        std::cerr << "stability_error=insufficient_dvs_events\n";
        return 20;
    }
    if (frames < options.minimumFrames) {
        std::cerr << "stability_error=insufficient_nonempty_rgb_frames\n";
        return 21;
    }
    if (maxGap > static_cast<uint64_t>(options.maxFrameGapMs)) {
        std::cerr << "stability_error=rgb_frame_gap_exceeded_limit\n";
        return 22;
    }
    if (!stillConnected) {
        std::cerr << "stability_error=camera_disconnected_before_close\n";
        return 23;
    }

    std::cout << "result=PASS\n";
    return 0;
}
