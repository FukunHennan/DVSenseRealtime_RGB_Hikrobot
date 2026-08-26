#include <cstdint>
#include <iostream>
#include <vector>

#include "../../src/native/src/display_event_accumulator.hpp"
#include "../../src/native/src/latest_batch_frame.hpp"

int main() {
    LatestBatchFrame frame(4, 1);
    frame.beginBatch();
    frame.setPixel(0, 0, uint8_t{2});
    frame.setPixel(3, 0, uint8_t{3});

    frame.beginBatch();
    frame.setPixel(1, 0, uint8_t{2});
    const std::vector<uint8_t> output = frame.snapshot();

    if (output != std::vector<uint8_t>({1, 2, 1, 1})) {
        std::cerr << "display frame retained events from an older callback\n";
        return 1;
    }
    const std::vector<uint8_t> idleOutput = frame.snapshot();
    const std::vector<uint8_t> repeatedIdleOutput = frame.snapshot();
    const std::vector<uint8_t> blank({1, 1, 1, 1});
    if (idleOutput != blank || repeatedIdleOutput != blank) {
        std::cerr << "idle reads resurrected a previously displayed frame\n";
        return 2;
    }

    DisplayEventAccumulator accumulator(4, 1, 16);
    accumulator.setWindowUs(1000);
    const DisplayEvent firstEvents[] = {
        {0, 0, true, 1000},
        {1, 0, false, 1500},
        {2, 0, true, 1800},
    };
    accumulator.append(firstEvents, 3);
    const std::vector<uint8_t> accumulated = accumulator.snapshot();
    if (accumulated != std::vector<uint8_t>({2, 3, 2, 1})) {
        std::cerr << "display accumulation did not render the active time window\n";
        return 3;
    }

    const DisplayEvent newestEvent[] = {{3, 0, false, 3000}};
    accumulator.append(newestEvent, 1);
    const std::vector<uint8_t> trimmed = accumulator.snapshot();
    if (trimmed != std::vector<uint8_t>({1, 1, 1, 3})) {
        std::cerr << "display accumulation retained events outside the active window\n";
        return 4;
    }

    if (accumulator.snapshot() != blank) {
        std::cerr << "display accumulation resurrected an idle frame\n";
        return 5;
    }

    accumulator.setWindowUs(5000);
    if (accumulator.snapshot() != blank) {
        std::cerr << "changing the display window did not clear old pixels\n";
        return 6;
    }
    return 0;
}
