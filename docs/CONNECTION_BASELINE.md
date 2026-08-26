# Camera Connection Baseline / 相机连接基线

**Verified date / 验证日期:** August 21, 2026 / 2026 年 8 月 21 日  
**Scope / 范围:** Native C++ acquisition only / 仅验证原生 C++ 采集

This is the current hardware truth for the project. Older diagnostic
summaries that describe the cameras as undiscovered are historical records.

这是当前项目的硬件事实基线。旧诊断摘要中称相机未发现的内容属于历史记录。

## Hardware / 硬件

| Device / 设备 | Verified identity / 已验证身份 | Lens / 镜头 |
|---|---|---|
| Event camera / 事件相机 | DVSense `DVSLume`, serial `ffffffffffffffab`, `1280x720` | `3MP-HD CCTV LENS 6MM IR` |
| RGB camera / RGB 相机 | Hikrobot `MV-CU050-90UC`, serial `DA7653943`, first frame `2600x2160` | `HN-1228-CM-C2/3B 12MM 1:2.8 2/3` |

## Verified Tests / 已验证测试

### DVSense / DVSense

The standalone C++ probe enumerated the camera, opened it, started the event
stream, and received positive event counts.

独立 C++ 探针完成枚举、打开、启动事件流，并持续收到有效事件。

```text
product=DVSLume
serial=ffffffffffffffab
connected=true
size=1280x720
events=46114425
result=PASS
```

### Hikrobot MVS / 海康 MVS

The standalone C++ probe enumerated one USB3 Vision device, opened it, and
received continuous non-empty frames.

独立 C++ 探针枚举到一台 USB3 Vision 设备，完成打开并持续收到非空图像帧。

```text
model=MV-CU050-90UC
serial=DA7653943
connected=true
frames=299
nonempty_frames=299
frame_gap_count=0
first_size=2600x2160
result=PASS
```

### Same-process dual acquisition / 同进程双相机取流

The combined C++ probe opened both cameras in one process, registered the DVS
event callback, started MVS RGB grabbing, and ran both paths for five seconds.

组合 C++ 探针在同一个进程中打开两台相机，注册 DVS 事件回调，启动 MVS RGB
取流，并同时运行五秒。

```text
dvs_events=49862604
hik_frames=298
hik_nonempty_frames=298
hik_frame_gaps=0
result=PASS
exit_code=0
```

This proves the hardware and vendor SDK acquisition baseline required before
building the fused display. It does not yet prove geometric calibration,
timestamp alignment, or the final visible overlay.

这证明了进入融合画面开发前所需的硬件和厂商 SDK 采集基线，但还没有证明几何
标定、时间对齐或最终可见叠加效果。

## Real Failure Records / 真实故障记录

### DVS empty serial / DVS 空序列号

Before the physical reconnect, the SDK printed:

物理重新插拔前，SDK 输出：

```text
size mismatch; expected {}, got {}
Get serial number failed.
Skip USB camera with empty serial number
updateCameras count=0
```

The C++ probe still attempted an empty serial and the historical serial, but
the SDK had already discarded the device and returned no camera handle.
After unplugging and reconnecting the DVS camera, the unchanged probe passed.

C++ 探针仍然尝试了空序列号和历史序列号，但 SDK 已在发现阶段丢弃设备，没有
返回相机句柄。拔插 DVS 后，未修改的探针恢复通过。

**Engineering rule / 工程规则:** Record an empty serial and try the open path,
but do not claim application code can create a handle after the vendor SDK has
discarded the device.

**工程规则：** 即使序列号为空也要记录并尝试打开，但如果厂商 SDK 已丢弃设备，
应用代码不能声称可以强制创建句柄。

### MVS runtime closure / MVS 完整运行库

Copying only `MvCameraControl.dll` caused:

只复制 `MvCameraControl.dll` 曾导致：

```text
enum_result=0x8000000C
```

This is `MV_E_LOAD_LIBRARY`. The successful run used the complete runtime
directory:

这是 `MV_E_LOAD_LIBRARY`。成功运行使用了完整运行库目录：

```text
C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64
```

The tested project-local copy is:

项目内已验证的运行库副本是：

```text
artifacts/runtime/mvs-win64
```

The complete runtime set is required; do not stage a single DLL as a
replacement.

必须使用完整运行库集合，不能用单个 DLL 替代。

## Evidence Files / 证据文件

The original probes and detailed records remain available:

原始探针和详细记录仍保留：

- `tests/native/dvs_connection_smoke.cpp`
- `tests/native/hik_connection_smoke.cpp`
- `tests/native/dual_camera_connection_smoke.cpp`
- `diagnostics/2026-08-21-dvs-empty-serial.md`
- `diagnostics/2026-08-21-hik-connection.md`
- `diagnostics/2026-08-21-dual-camera-connection.md`

The next verification target is a native fused frame, not another connection
probe.

下一项验证目标是原生融合画面，不再重复制作相机连接探针。
