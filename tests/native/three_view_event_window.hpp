#pragma once

#include "opencv2/core.hpp"

#include <mutex>

namespace dvsense_preview {

const cv::Vec3b kDvsOn(255, 0, 255);
const cv::Vec3b kDvsOff(0, 255, 0);

class ThreeViewEventWindow {
public:
    explicit ThreeViewEventWindow(cv::Size size);

    void add(uint16_t x, uint16_t y, bool polarity);
    cv::Mat takeAndClear();

private:
    std::mutex mutex_;
    cv::Mat frame_;
};

}  // namespace dvsense_preview
