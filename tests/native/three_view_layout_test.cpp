#include "three_view_layout.hpp"

#include <cassert>
#include <iostream>

int main() {
    const cv::Mat hik(10, 20, CV_8UC3, cv::Scalar(10, 20, 30));
    const cv::Mat dvs(20, 10, CV_8UC3, cv::Scalar(40, 50, 60));
    const cv::Mat fused(15, 15, CV_8UC3, cv::Scalar(70, 80, 90));

    const cv::Size panelSize(320, 240);
    const cv::Mat canvas = dvsense_preview::composeThreeView(
        hik, dvs, fused, panelSize);

    assert(canvas.cols == panelSize.width * 3);
    assert(canvas.rows == panelSize.height + dvsense_preview::kLabelHeight);
    assert(canvas.type() == CV_8UC3);
    assert(cv::countNonZero(canvas.reshape(1)) > 0);

    std::cout << "three_view_layout_test=PASS\n";
    return 0;
}
