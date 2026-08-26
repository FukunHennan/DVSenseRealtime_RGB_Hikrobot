#include "three_view_event_window.hpp"

#include "opencv2/core.hpp"

#include <cassert>
#include <iostream>

int main() {
    dvsense_preview::ThreeViewEventWindow window(cv::Size(8, 6));
    window.add(2, 3, true);
    window.add(5, 1, false);

    const cv::Mat first = window.takeAndClear();
    assert(first.size() == cv::Size(8, 6));
    assert(first.at<cv::Vec3b>(3, 2) == dvsense_preview::kDvsOn);
    assert(first.at<cv::Vec3b>(1, 5) == dvsense_preview::kDvsOff);

    const cv::Mat second = window.takeAndClear();
    assert(cv::countNonZero(second.reshape(1)) == 0);

    std::cout << "event_window_test=PASS\n";
    return 0;
}
