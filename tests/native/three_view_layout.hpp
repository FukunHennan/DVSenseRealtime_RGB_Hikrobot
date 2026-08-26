#pragma once

#include "opencv2/core.hpp"

namespace dvsense_preview {

constexpr int kLabelHeight = 34;

cv::Mat composeThreeView(
    const cv::Mat& hikFrame,
    const cv::Mat& dvsFrame,
    const cv::Mat& fusedFrame,
    cv::Size panelSize);

}  // namespace dvsense_preview
