#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <algorithm>
#include <cctype>
#include <iostream>
#include <mutex>
#include <string>
#include <vector>
#include <windows.h>
#include "DvsenseDriver/camera/DvsCameraManager.hpp"
#include "display_event_accumulator.hpp"

namespace {
constexpr uint32_t CMD_OPEN = 1;
constexpr uint32_t CMD_BATCH_TIME = 2;
constexpr uint32_t CMD_SET_ROI = 3;
constexpr uint32_t CMD_START_RECORDING = 4;
constexpr uint32_t CMD_STOP_RECORDING = 5;
constexpr uint32_t CMD_START = 6;
constexpr uint32_t CMD_READ = 7;
constexpr uint32_t CMD_STOP = 8;
constexpr uint32_t CMD_CLOSE = 9;
constexpr uint32_t CMD_READ_FRAME = 10;
constexpr uint32_t CMD_GET_TOOLS = 11;
constexpr uint32_t CMD_GET_TOOL_PARAMETERS = 12;
constexpr uint32_t CMD_SET_PARAMETER = 13;
constexpr uint32_t CMD_DISCOVER_CAMERAS = 14;
constexpr uint32_t CMD_DISPLAY_WINDOW = 15;

dvsense::DvsCameraManager manager;
dvsense::CameraDevice camera;
bool started = false;
uint32_t callbackId = 0;
std::mutex eventMutex;
std::condition_variable eventReady;
constexpr size_t MAX_PENDING_EVENTS = 200000;
std::vector<dvsense::Event2D> pendingEvents(MAX_PENDING_EVENTS);
std::vector<dvsense::Event2D> readEvents(MAX_PENDING_EVENTS);
size_t pendingCount = 0;
std::mutex frameMutex;
uint32_t frameWidth = 0;
uint32_t frameHeight = 0;
DisplayEventAccumulator frameStorage;
HANDLE protocolOutput = nullptr;

void receiveEvents(const dvsense::Event2D* begin, const dvsense::Event2D* end) {
    const size_t count = static_cast<size_t>(end - begin);
    {
        std::lock_guard<std::mutex> lock(eventMutex);
        const size_t copied =
            count < MAX_PENDING_EVENTS ? count : MAX_PENDING_EVENTS;
        std::copy(end - copied, end, pendingEvents.begin());
        pendingCount = copied;
    }
    std::vector<DisplayEvent> displayEvents;
    displayEvents.reserve(count);
    for (auto event = begin; event != end; ++event) {
        displayEvents.push_back(DisplayEvent{
            static_cast<uint32_t>(event->x),
            static_cast<uint32_t>(event->y),
            event->polarity != 0,
            static_cast<uint64_t>(event->timestamp)});
    }
    {
        std::lock_guard<std::mutex> lock(frameMutex);
        frameStorage.append(displayEvents.data(), displayEvents.size());
    }
    eventReady.notify_one();
}

uint32_t readU32(const std::vector<uint8_t>& data, size_t& offset) {
    if (offset + 4 > data.size()) throw std::runtime_error("Malformed request.");
    uint32_t value = 0;
    for (int i = 0; i < 4; ++i) value |= static_cast<uint32_t>(data[offset++]) << (8 * i);
    return value;
}

uint64_t readU64(const std::vector<uint8_t>& data, size_t& offset) {
    if (offset + 8 > data.size()) throw std::runtime_error("Malformed request.");
    uint64_t value = 0;
    for (int i = 0; i < 8; ++i) value |= static_cast<uint64_t>(data[offset++]) << (8 * i);
    return value;
}

std::string readString(const std::vector<uint8_t>& data, size_t& offset) {
    const uint32_t size = readU32(data, offset);
    if (offset + size > data.size()) throw std::runtime_error("Malformed request.");
    std::string value(data.begin() + static_cast<ptrdiff_t>(offset),
                      data.begin() + static_cast<ptrdiff_t>(offset + size));
    offset += size;
    return value;
}

void appendU32(std::vector<uint8_t>& out, uint32_t value) {
    for (int i = 0; i < 4; ++i) out.push_back(static_cast<uint8_t>(value >> (8 * i)));
}

void appendString(std::vector<uint8_t>& out, const std::string& value) {
    appendU32(out, static_cast<uint32_t>(value.size()));
    out.insert(out.end(), value.begin(), value.end());
}

std::vector<uint8_t> info() {
    const auto description = camera->getDescription();
    std::vector<uint8_t> body;
    appendU32(body, camera->getWidth());
    appendU32(body, camera->getHeight());
    appendString(body, description.product);
    appendString(body, description.serial);
    return body;
}

std::string interfaceName(dvsense::INTERFACE_TYPE type) {
    return type == dvsense::INTERFACE_TYPE::USB ? "USB" : "ETH";
}

std::vector<uint8_t> camerasInfo() {
    manager.updateCameras();
    const auto descriptions = manager.getCameraDescs();
    std::vector<uint8_t> body;
    appendU32(body, static_cast<uint32_t>(descriptions.size()));
    for (const auto& description : descriptions) {
        appendString(body, description.product);
        appendString(body, description.serial);
        appendString(body, description.manufacturer);
        appendString(body, interfaceName(description.interfaceType));
        appendString(body, description.camera_ip);
        appendString(body, description.local_ip);
        appendString(body, description.firmware_version);
    }
    return body;
}

std::vector<uint8_t> toolsInfo() {
    const auto tools = camera->getAllToolsInfo();
    std::vector<uint8_t> body;
    appendU32(body, static_cast<uint32_t>(tools.size()));
    for (const auto& tool : tools) {
        appendString(body, tool.tool_name);
        appendString(body, tool.description);
        appendU32(body, static_cast<uint32_t>(tool.parameter_names.size()));
        for (const auto& parameter : tool.parameter_names) {
            appendString(body, parameter);
        }
    }
    return body;
}

std::vector<uint8_t> toolParametersInfo() {
    struct ParameterRecord {
        std::string tool;
        std::string name;
        std::string type;
        std::string details;
        std::string current;
        std::string min;
        std::string max;
        std::string defaultValue;
        std::string unit;
        std::vector<std::string> options;
    };
    std::vector<ParameterRecord> records;
    for (const auto& toolInfo : camera->getAllToolsInfo()) {
        const auto tool = camera->getTool(toolInfo.tool_type);
        if (!tool) continue;
        for (const auto& [name, basic] : tool->getAllParamInfo()) {
            ParameterRecord record{toolInfo.tool_name, name,
                                   dvsense::ToolParameterTypeToString(basic.type),
                                   "", ""};
            switch (basic.type) {
                case dvsense::ToolParameterType::INT: {
                    dvsense::IntParameterInfo info;
                    int current = 0;
                    if (tool->getParamInfo(name, info)) {
                        record.details = info.toString();
                        record.min = std::to_string(info.min);
                        record.max = std::to_string(info.max);
                        record.defaultValue = std::to_string(info.default_value);
                        record.unit = info.unit;
                    }
                    if (tool->getParam(name, current)) record.current = std::to_string(current);
                    break;
                }
                case dvsense::ToolParameterType::FLOAT: {
                    dvsense::FloatParameterInfo info;
                    float current = 0;
                    if (tool->getParamInfo(name, info)) {
                        record.details = info.toString();
                        record.min = std::to_string(info.min);
                        record.max = std::to_string(info.max);
                        record.defaultValue = std::to_string(info.default_value);
                        record.unit = info.unit;
                    }
                    if (tool->getParam(name, current)) record.current = std::to_string(current);
                    break;
                }
                case dvsense::ToolParameterType::BOOL: {
                    dvsense::BoolParameterInfo info;
                    bool current = false;
                    if (tool->getParamInfo(name, info)) {
                        record.details = info.toString();
                        record.defaultValue = info.default_value ? "true" : "false";
                    }
                    if (tool->getParam(name, current)) record.current = current ? "true" : "false";
                    break;
                }
                case dvsense::ToolParameterType::ENUM: {
                    dvsense::EnumParameterInfo info;
                    std::string current;
                    if (tool->getParamInfo(name, info)) {
                        record.details = "Options: ";
                        record.options = info.options;
                        for (size_t index = 0; index < info.options.size(); ++index) {
                            if (index > 0) record.details += ", ";
                            record.details += info.options[index];
                        }
                        record.details += " Default: " + info.default_value;
                        record.defaultValue = info.default_value;
                    }
                    if (tool->getParam(name, current)) record.current = current;
                    break;
                }
                case dvsense::ToolParameterType::STRING: {
                    dvsense::StringParameterInfo info;
                    std::string current;
                    if (tool->getParamInfo(name, info)) {
                        record.details = info.toString();
                        record.defaultValue = info.default_value;
                    }
                    if (tool->getParam(name, current)) record.current = current;
                    break;
                }
            }
            records.push_back(std::move(record));
        }
    }
    std::vector<uint8_t> body;
    appendU32(body, static_cast<uint32_t>(records.size()));
    for (const auto& record : records) {
        appendString(body, record.tool);
        appendString(body, record.name);
        appendString(body, record.type);
        appendString(body, record.details);
        appendString(body, record.current);
        appendString(body, record.min);
        appendString(body, record.max);
        appendString(body, record.defaultValue);
        appendString(body, record.unit);
        appendU32(body, static_cast<uint32_t>(record.options.size()));
        for (const auto& option : record.options) appendString(body, option);
    }
    return body;
}

std::string readParameterValue(const std::vector<uint8_t>& payload,
                               size_t& offset) {
    return readString(payload, offset);
}

bool isTrueText(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(),
                   [](unsigned char character) { return static_cast<char>(std::tolower(character)); });
    return value == "true";
}

bool isFalseText(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(),
                   [](unsigned char character) { return static_cast<char>(std::tolower(character)); });
    return value == "false";
}

std::vector<uint8_t> setParameter(const std::vector<uint8_t>& payload) {
    size_t offset = 0;
    const std::string toolName = readString(payload, offset);
    const std::string parameterName = readString(payload, offset);
    const std::string type = readString(payload, offset);
    const std::string valueText = readParameterValue(payload, offset);
    if (offset != payload.size()) throw std::runtime_error("Malformed parameter request.");

    const auto tool = camera->getTool(toolName);
    if (!tool) throw std::runtime_error("Camera tool unavailable: " + toolName);
    std::string currentText;

    if (type == "INT") {
        int value = 0;
        try { value = std::stoi(valueText); }
        catch (...) { throw std::runtime_error("Invalid integer parameter value."); }
        dvsense::IntParameterInfo info;
        if (!tool->getParamInfo(parameterName, info))
            throw std::runtime_error("Integer parameter metadata unavailable.");
        if (value < info.min || value > info.max)
            throw std::runtime_error("Integer parameter value is outside SDK range.");
        if (!tool->setParam(parameterName, value))
            throw std::runtime_error("SDK rejected integer parameter value.");
        if (!tool->getParam(parameterName, value))
            throw std::runtime_error("Unable to read back integer parameter.");
        currentText = std::to_string(value);
    } else if (type == "FLOAT") {
        float value = 0;
        try { value = std::stof(valueText); }
        catch (...) { throw std::runtime_error("Invalid float parameter value."); }
        dvsense::FloatParameterInfo info;
        if (!tool->getParamInfo(parameterName, info))
            throw std::runtime_error("Float parameter metadata unavailable.");
        if (value < info.min || value > info.max)
            throw std::runtime_error("Float parameter value is outside SDK range.");
        if (!tool->setParam(parameterName, value))
            throw std::runtime_error("SDK rejected float parameter value.");
        if (!tool->getParam(parameterName, value))
            throw std::runtime_error("Unable to read back float parameter.");
        currentText = std::to_string(value);
    } else if (type == "BOOL") {
        bool value = false;
        if (isTrueText(valueText)) value = true;
        else if (!isFalseText(valueText))
            throw std::runtime_error("Boolean parameter must be true or false.");
        if (!tool->setParam(parameterName, value))
            throw std::runtime_error("SDK rejected boolean parameter value.");
        if (!tool->getParam(parameterName, value))
            throw std::runtime_error("Unable to read back boolean parameter.");
        currentText = value ? "true" : "false";
    } else if (type == "ENUM" || type == "STRING") {
        if (type == "ENUM") {
            dvsense::EnumParameterInfo info;
            if (!tool->getParamInfo(parameterName, info))
                throw std::runtime_error("Enum parameter metadata unavailable.");
            if (std::find(info.options.begin(), info.options.end(), valueText) == info.options.end())
                throw std::runtime_error("Enum parameter value is not an SDK option.");
        }
        if (!tool->setParam(parameterName, valueText))
            throw std::runtime_error("SDK rejected text parameter value.");
        if (!tool->getParam(parameterName, currentText))
            throw std::runtime_error("Unable to read back text parameter.");
    } else {
        throw std::runtime_error("Unsupported SDK parameter type: " + type);
    }

    std::vector<uint8_t> body;
    appendString(body, currentText);
    return body;
}

void encodeEvents(const dvsense::Event2D* input, size_t count,
                  std::vector<uint8_t>& body) {
    body.resize(4 + count * 13);
    body[0] = static_cast<uint8_t>(count);
    body[1] = static_cast<uint8_t>(count >> 8);
    body[2] = static_cast<uint8_t>(count >> 16);
    body[3] = static_cast<uint8_t>(count >> 24);
    size_t offset = 4;
    for (size_t i = 0; i < count; ++i) {
        const auto& event = input[i];
        const uint16_t x = static_cast<uint16_t>(event.x + 1);
        const uint16_t y = static_cast<uint16_t>(event.y + 1);
        body[offset++] = static_cast<uint8_t>(x);
        body[offset++] = static_cast<uint8_t>(x >> 8);
        body[offset++] = static_cast<uint8_t>(y);
        body[offset++] = static_cast<uint8_t>(y >> 8);
        body[offset++] = event.polarity ? 1 : 0;
        for (int byte = 0; byte < 8; ++byte) {
            body[offset++] = static_cast<uint8_t>(event.timestamp >> (8 * byte));
        }
    }
}

void encodeFrame(std::vector<uint8_t>& body) {
    std::vector<uint8_t> frameRead;
    {
        std::lock_guard<std::mutex> lock(frameMutex);
        frameRead = frameStorage.snapshot();
    }
    body.resize(8 + frameRead.size());
    body[0] = static_cast<uint8_t>(frameWidth);
    body[1] = static_cast<uint8_t>(frameWidth >> 8);
    body[2] = static_cast<uint8_t>(frameWidth >> 16);
    body[3] = static_cast<uint8_t>(frameWidth >> 24);
    body[4] = static_cast<uint8_t>(frameHeight);
    body[5] = static_cast<uint8_t>(frameHeight >> 8);
    body[6] = static_cast<uint8_t>(frameHeight >> 16);
    body[7] = static_cast<uint8_t>(frameHeight >> 24);
    std::copy(frameRead.begin(), frameRead.end(), body.begin() + 8);
}

void send(uint32_t status, const std::vector<uint8_t>& body) {
    const uint32_t header[2] = {status, static_cast<uint32_t>(body.size())};
    auto writeAll = [](const void* data, size_t bytes) {
        const auto* cursor = static_cast<const uint8_t*>(data);
        while (bytes > 0) {
            DWORD written = 0;
            if (!WriteFile(protocolOutput, cursor, static_cast<DWORD>(bytes),
                           &written, nullptr) ||
                written == 0) {
                throw std::runtime_error("Protocol pipe write failed.");
            }
            cursor += written;
            bytes -= written;
        }
    };
    writeAll(header, sizeof(header));
    if (!body.empty()) {
        writeAll(body.data(), body.size());
    }
}

void handle(uint32_t command, const std::vector<uint8_t>& payload) {
    static std::vector<uint8_t> responseBody;
    size_t offset = 0;
    switch (command) {
        case CMD_DISCOVER_CAMERAS:
            send(0, camerasInfo());
            return;
        case CMD_OPEN: {
            if (camera) {
                send(0, info());
                return;
            }
            const std::string target = readString(payload, offset);
            manager.updateCameras();
            const auto descriptions = manager.getCameraDescs();
            for (const auto& description : descriptions) {
                if (!target.empty() && target != description.serial) continue;
                if (description.product == "DVSync") continue;
                camera = manager.openCamera(description.serial);
                if (camera) break;
            }
            if (!camera) throw std::runtime_error("No matching event camera found.");
            frameWidth = camera->getWidth();
            frameHeight = camera->getHeight();
            {
                std::lock_guard<std::mutex> lock(frameMutex);
                frameStorage.reset(frameWidth, frameHeight);
            }
            camera->setBatchEventsNum(2500);
            callbackId = camera->addEventsStreamHandleCallback(receiveEvents);
            send(0, info());
            return;
        }
        case CMD_BATCH_TIME:
            if (!camera) throw std::runtime_error("Camera is not open.");
            camera->setBatchEventsTime(static_cast<dvsense::TimeStamp>(readU64(payload, offset)));
            send(0, {});
            return;
        case CMD_DISPLAY_WINDOW:
            if (!camera) throw std::runtime_error("Camera is not open.");
            if (payload.size() != 8) throw std::runtime_error("Malformed display window request.");
            {
                std::lock_guard<std::mutex> lock(frameMutex);
                frameStorage.setWindowUs(readU64(payload, offset));
            }
            send(0, {});
            return;
        case CMD_SET_ROI: {
            if (!camera) throw std::runtime_error("Camera is not open.");
            auto tool = camera->getTool(dvsense::ToolType::TOOL_ROI);
            if (!tool) throw std::runtime_error("ROI tool unavailable.");
            const int x = static_cast<int>(readU32(payload, offset));
            const int y = static_cast<int>(readU32(payload, offset));
            const int width = static_cast<int>(readU32(payload, offset));
            const int height = static_cast<int>(readU32(payload, offset));
            auto requireSet = [&tool](const char* name, const auto& value) {
                if (!tool->setParam(name, value)) {
                    throw std::runtime_error(
                        std::string("Failed to apply ROI parameter: ") + name);
                }
            };
            requireSet("x", x - 1);
            requireSet("y", y - 1);
            requireSet("width", width);
            requireSet("height", height);
            requireSet("enable", true);
            {
                std::lock_guard<std::mutex> lock(frameMutex);
                frameStorage.clear();
            }
            send(0, {});
            return;
        }
        case CMD_START_RECORDING: {
            if (!camera) throw std::runtime_error("Camera is not open.");
            const std::string path = readString(payload, offset);
            if (camera->startRecording(path) != 0) {
                throw std::runtime_error("Failed to start RAW recording.");
            }
            send(0, {});
            return;
        }
        case CMD_STOP_RECORDING:
            if (camera) camera->stopRecording();
            send(0, {});
            return;
        case CMD_START:
            if (!camera) throw std::runtime_error("Camera is not open.");
            if (!started) {
                if (camera->start() != 0) throw std::runtime_error("Camera start failed.");
                started = true;
            }
            send(0, {});
            return;
        case CMD_READ: {
            if (!camera) throw std::runtime_error("Camera is not open.");
            {
                std::unique_lock<std::mutex> lock(eventMutex);
                eventReady.wait_for(lock, std::chrono::milliseconds(20),
                                    [] { return pendingCount > 0 || !started; });
                const size_t count = pendingCount;
                std::copy_n(pendingEvents.begin(), count, readEvents.begin());
                pendingCount = 0;
                encodeEvents(readEvents.data(), count, responseBody);
            }
            send(0, responseBody);
            return;
        }
        case CMD_READ_FRAME:
            if (!camera) throw std::runtime_error("Camera is not open.");
            encodeFrame(responseBody);
            send(0, responseBody);
            return;
        case CMD_GET_TOOLS:
            if (!camera) throw std::runtime_error("Camera is not open.");
            send(0, toolsInfo());
            return;
        case CMD_GET_TOOL_PARAMETERS:
            if (!camera) throw std::runtime_error("Camera is not open.");
            send(0, toolParametersInfo());
            return;
        case CMD_SET_PARAMETER:
            if (!camera) throw std::runtime_error("Camera is not open.");
            send(0, setParameter(payload));
            return;
        case CMD_STOP:
            if (camera && started) camera->stop();
            started = false;
            eventReady.notify_all();
            send(0, {});
            return;
        case CMD_CLOSE:
            if (camera && started) camera->stop();
            started = false;
            if (camera && callbackId != 0) {
                camera->removeEventsStreamHandleCallback(callbackId);
                callbackId = 0;
            }
            {
                std::lock_guard<std::mutex> lock(eventMutex);
                pendingCount = 0;
            }
            {
                std::lock_guard<std::mutex> lock(frameMutex);
                frameStorage.clear();
                frameWidth = 0;
                frameHeight = 0;
            }
            eventReady.notify_all();
            camera.reset();
            send(0, {});
            return;
        default:
            throw std::runtime_error("Unknown helper command.");
    }
}
}

int main(int argc, char* argv[]) {
    if (argc != 2) return 3;
    protocolOutput =
        reinterpret_cast<HANDLE>(static_cast<uintptr_t>(std::stoull(argv[1])));
    std::ios::sync_with_stdio(false);
    std::cin.tie(nullptr);
    while (true) {
        uint32_t header[2] = {};
        if (!std::cin.read(reinterpret_cast<char*>(header), sizeof(header))) return 0;
        const uint32_t command = header[0];
        const uint32_t size = header[1];
        if (size > 16 * 1024 * 1024) return 2;
        std::vector<uint8_t> payload(size);
        if (size > 0 &&
            !std::cin.read(reinterpret_cast<char*>(payload.data()),
                           static_cast<std::streamsize>(size))) {
            return 0;
        }
        try {
            handle(command, payload);
        } catch (const std::exception& error) {
            const std::string message = error.what();
            send(1, std::vector<uint8_t>(message.begin(), message.end()));
        } catch (...) {
            const std::string message = "Unknown SDK error.";
            send(1, std::vector<uint8_t>(message.begin(), message.end()));
        }
        if (command == CMD_CLOSE) return 0;
    }
}
