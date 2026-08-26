# Dual-Camera C++ Connection Verification / 双相机 C++ 同时连接验证

Date / 日期: 2026-08-21  
Scope / 范围: One native C++ process, DVSense DVSLume plus Hikrobot RGB

> **Canonical summary / 统一摘要:** The current consolidated status is
> maintained in [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md).
> This file keeps the full raw verification output.
>
> **统一摘要：** 当前汇总状态维护在
> [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md)。本文件保留完整原始验证输出。

## Probe / 探针

Source / 源码:

`tests/native/dual_camera_connection_smoke.cpp`

The probe opens both cameras in the same process:

1. Enumerate and open DVSense `DVSLume`.
2. Register the DVS event callback and start the DVS stream.
3. Initialize MVS, enumerate and open Hikrobot `MV-CU050-90UC`.
4. Disable Hikrobot trigger mode and start RGB grabbing.
5. For five seconds, receive DVS events and synchronously fetch RGB frames.
6. Stop and release both cameras.

该探针在同一个 C++ 进程中完成：

1. 枚举并打开 DVSense `DVSLume`。
2. 注册 DVS 事件回调并启动事件流。
3. 初始化 MVS，枚举并打开海康 `MV-CU050-90UC`。
4. 关闭海康触发模式并启动 RGB 取流。
5. 持续 5 秒同时接收 DVS 事件和 RGB 帧。
6. 分别停止并释放两台相机。

## Verified Hardware / 已验证硬件

- DVS product / DVS 产品: `DVSLume`
- DVS serial / DVS 序列号: `ffffffffffffffab`
- DVS size / DVS 分辨率: `1280x720`
- Hikrobot model / 海康型号: `MV-CU050-90UC`
- Hikrobot serial / 海康序列号: `DA7653943`
- Hik first-frame size / 海康首帧分辨率: `2600x2160`

## Verified Result / 已验证结果

```text
dvs_opened product=DVSLume serial=ffffffffffffffab connected=true size=1280x720
dvs_start_result=0
hik_initialize_result=0x0
hik_enum_result=0x0 count=1
hik_candidate model=MV-CU050-90UC serial=DA7653943
hik_create_handle_result=0x0
hik_open_result=0x0 connected=true
hik_start_result=0x0
hik_opened serial=DA7653943 connected=true
hik_first_frame number=0 size=2600x2160 bytes=5616000
dual_stream_summary dvs_events=49862604 dvs_stop_result=0 dvs_connected_before_close=true hik_frames=298 hik_nonempty_frames=298 hik_frame_gaps=0 hik_first_frame_number=0 hik_first_size=2600x2160 hik_first_bytes=5616000 hik_stop_result=0x0 hik_connected_before_close=true hik_close_result=0x0 hik_destroy_result=0x0 hik_finalize_result=0x0
result=PASS
exit_code=0
```

## Conclusion / 结论

The two independent cameras can be opened and streamed concurrently by one
native C++ process. The DVS event callback continues while the MVS RGB frame
loop is active. Both devices remained connected until their normal shutdown.

两台独立相机可以由同一个原生 C++ 进程同时打开并取流。海康 RGB 取帧循环运行
期间，DVS 事件回调仍持续接收数据；两台相机在正常停止前均保持连接。

This confirms the hardware and SDK acquisition baseline required before adding
the fusion display. Fusion rendering, ROI, GPU processing, and MATLAB were not
included in this verification.

这确认了进入融合显示开发前所需的硬件和 SDK 采集基线。本次验证尚未加入融合
显示、ROI、GPU 处理或 MATLAB。

## Runtime Reproducibility / 运行库复现

The successful executable was run from the project-local staged MVS runtime:

`artifacts/runtime/mvs-win64`

The process also used the installed DVSense runtime:

`C:/Program Files (x86)/DvsenseDriver/bin`

The complete MVS runtime set is required. Copying only
`MvCameraControl.dll` previously caused `MV_E_LOAD_LIBRARY` during MVS
enumeration.

必须使用完整 MVS runtime。之前只复制 `MvCameraControl.dll` 时，MVS 枚举阶段
曾返回 `MV_E_LOAD_LIBRARY`。
