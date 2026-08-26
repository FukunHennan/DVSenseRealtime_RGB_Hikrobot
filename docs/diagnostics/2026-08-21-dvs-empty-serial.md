# DVS Empty-Serial Connection Incident / DVS 空序列号连接故障记录

Date / 日期: 2026-08-21  
Scope / 范围: Native C++ DVS-only connection

> **Historical incident / 历史故障:** The recovery described below was
> verified after a physical reconnect. The current summary is maintained in
> [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md).
>
> **历史故障：** 下文所述恢复已在物理重新插拔后验证。当前统一摘要维护在
> [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md)。

## Confirmed Reproduction / 已确认复现

The minimal probe is:

`tests/native/dvs_connection_smoke.cpp`

It performs only:

1. `DvsCameraManager::updateCameras()`
2. `getCameraDescs()`
3. `openCamera("")` when discovery returns no description
4. `openCamera("ffffffffffffffab")` as the historical DVS serial
5. `isConnected()`, `start()`, event counting, and `stop()`

Observed SDK output:

```text
size mismatch; expected {}, got {}
Get serial number failed.
Skip USB camera with empty serial number
```

Observed probe output:

```text
dvs_connection_smoke duration_s=3
updateCameras_return=0 descriptions_count=0
dvs_fallback_candidate serial=<empty>
dvs_fallback_candidate serial=ffffffffffffffab
open_attempt index=0 product=unknown serial=<empty>
open_result=null
open_attempt index=1 product=historical_success_serial serial=ffffffffffffffab
open_result=null
result=OPEN_FAILED
exit_code=10
```

## Confirmed Boundary / 已确认边界

- The failure occurs inside the DVSense USB discovery path.
- The SDK fails while reading the USB serial number.
- The SDK then skips the USB camera before returning a `CameraDescription`.
- `getCameraDescs()` therefore returns an empty vector.
- The outer C++ code does attempt both an empty serial and the historical serial, but the SDK returns a null camera handle.
- No DVS camera object is created, so event callbacks and `start()` are not reached.

This is not currently a fusion-pairing issue, RGB issue, callback issue, or GPU issue.

## Not Proven / 尚未证明

The following causes are not yet proven and must not be presented as facts:

- camera firmware corruption;
- USB descriptor corruption;
- Windows driver state;
- administrator permission state;
- a specific DLL version mismatch.

The exact SDK error text only proves that serial-number retrieval failed.

## Recovery Verification After Physical Reconnect / 物理重新插拔后的恢复验证

After the DVS camera was physically unplugged and reconnected, the same
unchanged probe was run again.

在物理拔出并重新连接 DVS 相机后，使用完全相同的探针重新运行。

Observed result / 实际结果:

```text
updateCameras_return=1 descriptions_count=1
dvs_description product=DVSLume serial=ffffffffffffffab manufacturer=DVSense vid=0x04b5 pid=0x0001 interface=0
open_result=handle connected=true product=DVSLume serial=ffffffffffffffab size=1280x720
start_result=0
stream_result events=46114425 stop_result=0 connected_before_close=true
result=PASS
exit_code=0
```

This proves that the application-side C++ connection path is valid. The
previous failure was a transient DVS USB enumeration state: the SDK could not
read the serial number and discarded the device. Physical reconnect restored
enumeration and event streaming.

这证明应用侧 C++ 连接路径是有效的。之前的失败是 DVS USB 枚举状态异常：
SDK 无法读取序列号并丢弃设备；物理重新插拔后枚举和事件流恢复。

## Current Code Rule / 当前代码规则

Do not treat an empty serial as an invalid DVS identity. Record it and attempt the SDK open path. However, if the vendor SDK discards the device before producing a description, application code cannot force `openCamera()` to create a handle.

## Historical Recovery Action / 历史恢复动作

The required physical reconnect was completed and the unchanged probe then
reported a valid handle and positive event count. Further connection probes are
not the current milestone; the next target is the native fused display.

已完成物理重新插拔，未修改的探针随后返回有效句柄和正事件数。连接探针不再是
当前里程碑，下一目标是原生融合画面。
