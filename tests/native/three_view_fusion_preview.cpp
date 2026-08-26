#include "DvsRgbCalib/CalibrateThroughFile.hpp"
#include "DvsRgbFusionCamera/CameraManager/DvsRgbFusionCamera.hpp"
#include "DvsRgbFusionCamera/rgb/hik/HikCamera.hpp"
#include "three_view_event_window.hpp"
#include "three_view_layout.hpp"

#include "opencv2/highgui.hpp"
#include "opencv2/imgproc.hpp"

#include <algorithm>
#include <cstdint>
#include <iostream>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

namespace {

constexpr int kPanelWidth = 640;
constexpr int kPanelHeight = 480;
constexpr double kCalibrationDistance = 110000.0;
constexpr double kScaleStep = 0.01;
constexpr int kMoveStepPixels = 5;

struct PreviewState {
    std::mutex mutex;
    cv::Mat hikFrame;
    cv::Mat fusedFrame;
};

struct ManualAlignment {
    double scale = 0.86;
    int offsetX = 150;
    int offsetY = 20;
};

cv::Mat cloneBgrFrame(const dvsense::ApsFrame& frame) {
    if (frame.getDataSize() == 0 || frame.width() <= 0 || frame.height() <= 0) {
        return cv::Mat();
    }
    const cv::Mat view(
        frame.height(),
        frame.width(),
        CV_8UC3,
        const_cast<void*>(static_cast<const void*>(frame.data())));
    return view.clone();
}

cv::Mat applyManualAlignment(
    const cv::Mat& source,
    const ManualAlignment& alignment) {
    if (source.empty()) {
        return cv::Mat();
    }

    const double centerX = (source.cols - 1) * 0.5;
    const double centerY = (source.rows - 1) * 0.5;
    const cv::Mat transform = (cv::Mat_<double>(2, 3) <<
        alignment.scale,
        0.0,
        (1.0 - alignment.scale) * centerX + alignment.offsetX,
        0.0,
        alignment.scale,
        (1.0 - alignment.scale) * centerY + alignment.offsetY);

    cv::Mat aligned;
    cv::warpAffine(
        source,
        aligned,
        transform,
        source.size(),
        cv::INTER_LINEAR,
        cv::BORDER_CONSTANT,
        cv::Scalar(0, 0, 0));
    return aligned;
}

void printAlignment(const ManualAlignment& alignment) {
    std::cout << "manual_alignment scale=" << alignment.scale
              << " offset_x=" << alignment.offsetX
              << " offset_y=" << alignment.offsetY << std::endl;
}

void handleAlignmentKey(int key, ManualAlignment& alignment) {
    if (key == 'a' || key == 'A') {
        alignment.offsetX -= kMoveStepPixels;
    } else if (key == 'd' || key == 'D') {
        alignment.offsetX += kMoveStepPixels;
    } else if (key == 'w' || key == 'W') {
        alignment.offsetY -= kMoveStepPixels;
    } else if (key == 's' || key == 'S') {
        alignment.offsetY += kMoveStepPixels;
    } else if (key == '+' || key == '=') {
        alignment.scale += kScaleStep;
    } else if (key == '-' || key == '_') {
        alignment.scale = std::max(0.1, alignment.scale - kScaleStep);
    } else if (key == 'r' || key == 'R') {
        alignment = ManualAlignment{};
    } else {
        return;
    }
    printAlignment(alignment);
}

}  // namespace

int main(int argc, char** argv) {
#ifdef _WIN32
    SetProcessDPIAware();
#endif

    const std::string calibrationPath =
        argc > 1 ? argv[1] : "calibration_result.json";
    std::cout << "three_view_fusion_preview calibration=" << calibrationPath << "\n";

    auto calibrator = std::make_unique<CalibrateThroughFile>(calibrationPath);
    auto fusionCamera = std::make_unique<DvsRgbFusionCamera<HikCamera>>(30.0F);

    std::vector<dvsense::CameraDescription> dvsCameras;
    std::vector<std::string> hikSerials;
    if (!fusionCamera->findCamera(dvsCameras, hikSerials) ||
        dvsCameras.empty() || hikSerials.empty()) {
        std::cerr << "preview_error=camera_discovery_failed\n";
        return 10;
    }

    DvsRgbCameraSerial serials;
    serials.dvs_serial_number = dvsCameras.front();
    serials.rgb_serial_number = hikSerials.front();
    std::cout << "selected_dvs=" << serials.dvs_serial_number.serial
              << " selected_hik=" << serials.rgb_serial_number << "\n";

    if (!fusionCamera->openCamera(serials) || !fusionCamera->isConnected()) {
        std::cerr << "preview_error=camera_open_failed\n";
        fusionCamera->destroy();
        return 11;
    }

    const uint16_t dvsWidth = fusionCamera->getWidth(dvsense::DVS_STREAM);
    const uint16_t dvsHeight = fusionCamera->getHeight(dvsense::DVS_STREAM);
    PreviewState state;
    std::mutex alignmentMutex;
    ManualAlignment alignment;
    dvsense_preview::ThreeViewEventWindow eventWindow(
        cv::Size(dvsWidth, dvsHeight));

    const auto bias = fusionCamera->getTool(dvsense::ToolType::TOOL_BIAS);
    const bool biasOnSet = bias && bias->setParam("bias_diff_on", 24);
    const bool biasOffSet = bias && bias->setParam("bias_diff_off", 30);
    std::cout << "dvs_bias_diff_on_set=" << (biasOnSet ? "true" : "false")
              << " value=24\n"
              << "dvs_bias_diff_off_set=" << (biasOffSet ? "true" : "false")
              << " value=30" << std::endl;
    std::cout << "calibration_distance_mm=" << kCalibrationDistance << std::endl;

    const cv::Mat homography =
        calibrator->getApsToDvsHomographyMatrix(kCalibrationDistance);
    const uint32_t eventCallbackId =
        fusionCamera->addEventsStreamHandleCallback(
            [&eventWindow](dvsense::EventIterator_t begin,
                           dvsense::EventIterator_t end) {
                for (auto it = begin; it != end; ++it) {
                    eventWindow.add(it->x, it->y, it->polarity);
                }
            });

    const int frameCallbackId = fusionCamera->addApsFrameCallback(
        [&state, &homography, dvsWidth, dvsHeight, &calibrator, &alignmentMutex, &alignment](
            const dvsense::ApsFrame& frame) {
            const cv::Mat hikFrame = cloneBgrFrame(frame);
            if (hikFrame.empty()) {
                return;
            }

            ManualAlignment alignmentCopy;
            {
                std::lock_guard<std::mutex> lock(alignmentMutex);
                alignmentCopy = alignment;
            }
            const cv::Mat alignedRgb = applyManualAlignment(hikFrame, alignmentCopy);
            cv::Mat fusedFrame = calibrator->warpImage(
                alignedRgb,
                homography,
                cv::Size(dvsWidth, dvsHeight));
            {
                std::lock_guard<std::mutex> lock(state.mutex);
                state.hikFrame = hikFrame;
                state.fusedFrame = fusedFrame;
            }
        });

    if (fusionCamera->start(dvsense::FUSION_STREAM) != 0) {
        std::cerr << "preview_error=stream_start_failed\n";
        fusionCamera->removeEventsStreamHandleCallback(eventCallbackId);
        fusionCamera->removeApsFrameCallback(frameCallbackId);
        fusionCamera->destroy();
        return 12;
    }

    const std::string windowName = "DVSense Three-View Fusion";
    cv::namedWindow(windowName, cv::WINDOW_NORMAL);
    cv::resizeWindow(
        windowName,
        kPanelWidth * 3,
        kPanelHeight + dvsense_preview::kLabelHeight);

    bool running = true;
    printAlignment(alignment);
    while (running) {
        cv::Mat hikFrame;
        cv::Mat dvsFrame = eventWindow.takeAndClear();
        cv::Mat fusedFrame;
        {
            std::lock_guard<std::mutex> lock(state.mutex);
            hikFrame = state.hikFrame.clone();
            fusedFrame = state.fusedFrame.clone();
        }

        if (!fusedFrame.empty() && !dvsFrame.empty()) {
            cv::Mat eventMask;
            cv::inRange(
                dvsFrame,
                cv::Scalar(1, 1, 1),
                cv::Scalar(255, 255, 255),
                eventMask);
            fusedFrame.setTo(cv::Scalar(0, 255, 0), eventMask);
            cv::Mat magentaMask;
            cv::inRange(
                dvsFrame,
                cv::Scalar(200, 0, 200),
                cv::Scalar(255, 80, 255),
                magentaMask);
            fusedFrame.setTo(cv::Scalar(255, 0, 255), magentaMask);
        }

        cv::imshow(
            windowName,
            dvsense_preview::composeThreeView(
                hikFrame, dvsFrame, fusedFrame, cv::Size(kPanelWidth, kPanelHeight)));
        const int key = cv::waitKey(30);
        {
            std::lock_guard<std::mutex> lock(alignmentMutex);
            handleAlignmentKey(key, alignment);
        }
        running = key != 'q' && key != 'Q' && key != 27;
    }

    fusionCamera->stop(dvsense::FUSION_STREAM);
    fusionCamera->removeEventsStreamHandleCallback(eventCallbackId);
    fusionCamera->removeApsFrameCallback(frameCallbackId);
    fusionCamera->destroy();
    cv::destroyAllWindows();
    return 0;
}
