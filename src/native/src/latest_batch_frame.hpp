#pragma once

#include <algorithm>
#include <cstdint>
#include <utility>
#include <vector>

class LatestBatchFrame {
public:
    LatestBatchFrame() = default;

    LatestBatchFrame(uint32_t width, uint32_t height) {
        reset(width, height);
    }

    void reset(uint32_t width, uint32_t height) {
        width_ = width;
        height_ = height;
        const size_t pixels = static_cast<size_t>(width) * height;
        build_.assign(pixels, uint8_t{1});
        read_.assign(pixels, uint8_t{1});
    }

    void clear() {
        width_ = 0;
        height_ = 0;
        build_.clear();
        read_.clear();
    }

    void beginBatch() {
        std::fill(build_.begin(), build_.end(), uint8_t{1});
    }

    void setPixel(uint32_t x, uint32_t y, uint8_t value) {
        if (x >= width_ || y >= height_) return;
        build_[static_cast<size_t>(y) * width_ + x] = value;
    }

    void swapForRead() {
        std::swap(build_, read_);
        std::fill(build_.begin(), build_.end(), uint8_t{1});
    }

    const std::vector<uint8_t>& readBuffer() const {
        return read_;
    }

    std::vector<uint8_t> snapshot() {
        swapForRead();
        return read_;
    }

private:
    uint32_t width_ = 0;
    uint32_t height_ = 0;
    std::vector<uint8_t> build_;
    std::vector<uint8_t> read_;
};
