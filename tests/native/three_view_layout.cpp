#include "three_view_layout.hpp"

#include "opencv2/imgproc.hpp"

#include <array>
#include <string>

namespace {

cv::Mat normalizeToBgr(const cv::Mat& source) {
    if (source.empty()) {
        return cv::Mat();
    }
    if (source.channels() == 3) {
        return source;
    }
    cv::Mat bgr;
    if (source.channels() == 1) {
        cv::cvtColor(source, bgr, cv::COLOR_GRAY2BGR);
    } else {
        cv::cvtColor(source, bgr, cv::COLOR_BGRA2BGR);
    }
    return bgr;
}

cv::Mat makePanel(const cv::Mat& source, cv::Size panelSize, const char* label) {
    cv::Mat panel(panelSize, CV_8UC3, cv::Scalar(18, 18, 18));
    const cv::Mat bgr = normalizeToBgr(source);
    if (!bgr.empty()) {
        const double scale = std::min(
            static_cast<double>(panelSize.width) / bgr.cols,
            static_cast<double>(panelSize.height) / bgr.rows);
        const int width = std::max(1, static_cast<int>(bgr.cols * scale));
        const int height = std::max(1, static_cast<int>(bgr.rows * scale));
        cv::Mat resized;
        cv::resize(bgr, resized, cv::Size(width, height), 0, 0, cv::INTER_AREA);
        const int x = (panelSize.width - width) / 2;
        const int y = (panelSize.height - height) / 2;
        resized.copyTo(panel(cv::Rect(x, y, width, height)));
    }

    cv::Mat labeled(panelSize.height + dvsense_preview::kLabelHeight,
                    panelSize.width, CV_8UC3, cv::Scalar(18, 18, 18));
    panel.copyTo(labeled(cv::Rect(0, 0, panelSize.width, panelSize.height)));
    cv::rectangle(
        labeled,
        cv::Rect(0, 0, labeled.cols - 1, labeled.rows - 1),
        cv::Scalar(100, 100, 100),
        2);
    cv::putText(
        labeled,
        label,
        cv::Point(12, panelSize.height + 23),
        cv::FONT_HERSHEY_SIMPLEX,
        0.65,
        cv::Scalar(235, 235, 235),
        1,
        cv::LINE_AA);
    return labeled;
}

}  // namespace

namespace dvsense_preview {

cv::Mat composeThreeView(
    const cv::Mat& hikFrame,
    const cv::Mat& dvsFrame,
    const cv::Mat& fusedFrame,
    cv::Size panelSize) {
    const std::array<cv::Mat, 3> panels = {
        makePanel(hikFrame, panelSize, "Hikrobot RGB"),
        makePanel(dvsFrame, panelSize, "DVS Events"),
        makePanel(fusedFrame, panelSize, "Fused View")};

    cv::Mat canvas;
    cv::hconcat(std::vector<cv::Mat>(panels.begin(), panels.end()), canvas);
    return canvas;
}

}  // namespace dvsense_preview
