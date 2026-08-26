#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <vector>

struct DisplayEvent {
    uint32_t x = 0;
    uint32_t y = 0;
    bool polarity = false;
    uint64_t timestamp = 0;
};

class DisplayEventAccumulator {
public:
    DisplayEventAccumulator() = default;

    DisplayEventAccumulator(uint32_t width, uint32_t height,
                            size_t maxEvents = 200000) {
        reset(width, height, maxEvents);
    }

    void reset(uint32_t width, uint32_t height,
               size_t maxEvents = 200000) {
        width_ = width;
        height_ = height;
        maxEvents_ = maxEvents > 0 ? maxEvents : 1;
        frame_.assign(static_cast<size_t>(width_) * height_, uint8_t{1});
        history_.clear();
        latestTimestamp_ = 0;
        hasNewEvents_ = false;
    }

    void clear() {
        history_.clear();
        latestTimestamp_ = 0;
        hasNewEvents_ = false;
        std::fill(frame_.begin(), frame_.end(), uint8_t{1});
    }

    void setWindowUs(uint64_t windowUs) {
        windowUs_ = windowUs < 1 ? 1 : (windowUs > 100000 ? 100000 : windowUs);
        clear();
    }

    void append(const DisplayEvent* events, size_t count) {
        if (events == nullptr || count == 0) return;

        for (size_t index = 0; index < count; ++index) {
            const DisplayEvent& event = events[index];
            if (event.x >= width_ || event.y >= height_) continue;
            history_.push_back(event);
            latestTimestamp_ = latestTimestamp_ > event.timestamp
                ? latestTimestamp_ : event.timestamp;
            hasNewEvents_ = true;
        }

        while (history_.size() > maxEvents_) {
            history_.pop_front();
        }
        pruneExpired();
    }

    std::vector<uint8_t> snapshot() {
        std::fill(frame_.begin(), frame_.end(), uint8_t{1});
        if (!hasNewEvents_) return frame_;

        pruneExpired();
        for (const DisplayEvent& event : history_) {
            if (latestTimestamp_ < event.timestamp ||
                latestTimestamp_ - event.timestamp > windowUs_) {
                continue;
            }
            const size_t pixel =
                static_cast<size_t>(event.y) * width_ + event.x;
            frame_[pixel] = event.polarity ? uint8_t{2} : uint8_t{3};
        }
        hasNewEvents_ = false;
        return frame_;
    }

private:
    void pruneExpired() {
        while (!history_.empty()) {
            const DisplayEvent& oldest = history_.front();
            if (latestTimestamp_ < oldest.timestamp ||
                latestTimestamp_ - oldest.timestamp <= windowUs_) {
                break;
            }
            history_.pop_front();
        }
    }

    uint32_t width_ = 0;
    uint32_t height_ = 0;
    size_t maxEvents_ = 200000;
    uint64_t windowUs_ = 5000;
    uint64_t latestTimestamp_ = 0;
    bool hasNewEvents_ = false;
    std::deque<DisplayEvent> history_;
    std::vector<uint8_t> frame_;
};
