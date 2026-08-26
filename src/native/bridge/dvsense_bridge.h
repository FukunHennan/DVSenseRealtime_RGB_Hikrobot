#pragma once

#include <stdint.h>

#ifdef _WIN32
#define DVSENSE_BRIDGE_API __declspec(dllexport)
#else
#define DVSENSE_BRIDGE_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

DVSENSE_BRIDGE_API int dvsense_open(const char* serial);
DVSENSE_BRIDGE_API const char* dvsense_discover_cameras_json(void);
DVSENSE_BRIDGE_API const char* dvsense_list_stale_helpers_json(void);
DVSENSE_BRIDGE_API int dvsense_terminate_stale_helpers(void);
DVSENSE_BRIDGE_API int dvsense_close(void);
DVSENSE_BRIDGE_API int dvsense_start(void);
DVSENSE_BRIDGE_API int dvsense_stop(void);
DVSENSE_BRIDGE_API int dvsense_set_batch_time(uint64_t window_us);
DVSENSE_BRIDGE_API int dvsense_set_display_window(uint64_t window_us);
DVSENSE_BRIDGE_API int dvsense_set_roi(int32_t x, int32_t y,
                                       int32_t width, int32_t height);
DVSENSE_BRIDGE_API int dvsense_read_events(
    uint16_t* x, uint16_t* y, uint8_t* polarity, uint64_t* timestamp,
    uint32_t capacity, uint32_t* count);
DVSENSE_BRIDGE_API int dvsense_read_frame(
    uint8_t* frame, uint32_t capacity, uint32_t* width, uint32_t* height);
DVSENSE_BRIDGE_API const char* dvsense_get_camera_info_json(void);
DVSENSE_BRIDGE_API const char* dvsense_get_tool_parameters_json(void);
DVSENSE_BRIDGE_API int dvsense_set_parameter(
    const char* tool, const char* name, const char* type, const char* value);
DVSENSE_BRIDGE_API int dvsense_start_recording(const char* path);
DVSENSE_BRIDGE_API int dvsense_stop_recording(void);
DVSENSE_BRIDGE_API const char* dvsense_last_value(void);
DVSENSE_BRIDGE_API const char* dvsense_last_error(void);

#ifdef __cplusplus
}
#endif
