#include "three_view_event_window.hpp"

#include "opencv2/imgproc.hpp"

namespace dvsense_preview {

ThreeViewEventWindow::ThreeViewEventWindow(cv::Size size)
    : frame_(size, CV_8UC3, cv::Scalar(0, 0, 0)) {
}

void ThreeViewEventWindow::add(uint16_t x, uint16_t y, bool polarity) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (x >= frame_.cols || y >= frame_.rows) {
        return;
    }
    frame_.at<cv::Vec3b>(y, x) = polarity ? kDvsOn : kDvsOff;
}

cv::Mat ThreeViewEventWindow::takeAndClear() {
    std::lock_guard<std::mutex> lock(mutex_);
    cv::Mat snapshot = frame_.clone();
    frame_.setTo(cv::Scalar(0, 0, 0));
    return snapshot;
}

}  // namespace dvsense_preview
