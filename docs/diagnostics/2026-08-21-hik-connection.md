# Hikrobot C++ Connection Verification / 海康 C++ 连接验证

Date / 日期: 2026-08-21  
Scope / 范围: Standalone native C++ Hikrobot MVS connection

> **Canonical summary / 统一摘要:** The current consolidated status is
> maintained in [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md).
> This file keeps the full raw verification output and runtime trap.
>
> **统一摘要：** 当前汇总状态维护在
> [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md)。本文件保留完整原始验证输出
> 和运行库踩坑记录。

## Hardware / 硬件

- Model / 型号: `MV-CU050-90UC`
- Serial / 序列号: `DA7653943`
- Transport / 传输层: USB3 Vision
- Resolution reported by first frame / 首帧分辨率: `2600x2160`

## Probe / 探针

Source / 源码:

`tests/native/hik_connection_smoke.cpp`

The probe executes only the native MVS path:

1. `MV_CC_Initialize`
2. `MV_CC_EnumDevices(MV_USB_DEVICE)`
3. `MV_CC_CreateHandle`
4. `MV_CC_OpenDevice`
5. Disable trigger mode
6. `MV_CC_StartGrabbing`
7. Repeated `MV_CC_GetImageBuffer` and `MV_CC_FreeImageBuffer`
8. Stop, close, destroy, and finalize

## Verified Result / 已验证结果

```text
hik_connection_smoke duration_s=5 requested_serial=<any>
initialize_result=0x0
enum_result=0x0 device_count=1
device[0] transport=0x4 vendor=Hikrobot model=MV-CU050-90UC manufacturer=Hikrobot serial=DA7653943 device_version=V4.0.1 220914 887585
create_handle_result=0x0
open_device_result=0x0 connected=true
set_image_node_result=0x0
set_trigger_off_result=0x0
start_grabbing_result=0x0
first_frame number=0 size=2600x2160 bytes=5616000 pixel_type=17301515
stream_summary frames=299 nonempty_frames=299 frame_gap_count=0 first_frame_number=0 first_size=2600x2160 first_bytes=5616000 stop_result=0x0 connected_before_close=true close_result=0x0 destroy_result=0x0 finalize_result=0x0
result=PASS
exit_code=0
```

## Runtime Trap / 运行库踩坑

The first run initialized MVS but enumeration returned:

```text
initialize_result=0x0
enum_result=0x8000000C device_count=0
```

`0x8000000C` is `MV_E_LOAD_LIBRARY`. The first run placed only
`MvCameraControl.dll` beside the executable. That was insufficient because the
MVS USB3 Vision transport layer and its dependent runtime files were not
available as one complete runtime set.

第一次运行时 MVS 初始化成功，但枚举返回 `0x8000000C`，即
`MV_E_LOAD_LIBRARY`。原因是只把 `MvCameraControl.dll` 放到了可执行文件旁边，
没有让 MVS USB3 Vision 传输层及其依赖以完整运行库集合加载。

The successful run used the complete runtime directory:

`C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64`

For project-local reproducibility, the tested runtime set was staged under:

`artifacts/runtime/mvs-win64`

## Conclusion / 结论

The Hikrobot camera connection and continuous frame acquisition path are
confirmed valid in native C++. No fusion code, MATLAB bridge, ROI, or GPU code
was involved in this verification.

海康相机的原生 C++ 连接和连续取帧路径已经确认有效。本次验证没有涉及融合、
MATLAB 桥接、ROI 或 GPU 代码。
