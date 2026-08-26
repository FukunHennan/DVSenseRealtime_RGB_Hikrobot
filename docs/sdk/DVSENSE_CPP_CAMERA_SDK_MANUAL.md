# DVSense C++ Camera SDK Manual
# DVSense C++ 相机 SDK 使用手册

> **Status note / 状态说明:** This manual contains detailed SDK analysis and
> historical diagnostic reasoning. The current native hardware result is
> maintained in [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md).
> Use that document for the latest connection status.
>
> 本手册包含详细 SDK 分析和历史诊断推理。当前原生硬件结果统一维护在
> [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md)。查看最新连接状态时，
> 以该文档为准。

**Research type / 研究类型:** read-only source study / 只读源码研究  
**Snapshot date / 源码快照日期:** 2026-08-21  
**Target / 目标:** independent DVSLume event camera + Hikrobot MV-CU050-90UC RGB camera  
**最终目标:** 独立 DVSLume 事件相机 + 海康 MV-CU050-90UC RGB 相机的 C++ 连接与融合

This manual is based only on the local first-party source trees and the current
project files listed in [Source Evidence](#source-evidence--源码证据). It does
not invent SDK APIs. When a recommendation goes beyond an observed API call, it
is labeled as an engineering recommendation.

本手册只基于“源码证据”一节列出的本机官方源码和当前项目文件，不杜撰 SDK API。
超出源码直接调用的内容会明确标注为工程建议。

## 1. Executive Conclusions / 结论摘要

### 1.1 The required camera topology / 当前相机拓扑

The hardware profile is two independent cameras:

- DVSense `DVSLume`
- Hikrobot `MV-CU050-90UC`, accessed through the Hikrobot MVS SDK

当前硬件是两台独立相机：

- DVSense `DVSLume`
- 海康 `MV-CU050-90UC`，通过海康 MVS SDK 访问

The previously recorded successful identifiers are:

- DVS serial: `ffffffffffffffab`
- Hikrobot serial: `DA7653943`
- DVS resolution: `1280 x 720`
- historical RGB first frame: `2600 x 2160`

此前记录过的成功标识为：

- DVS 序列号：`ffffffffffffffab`
- 海康序列号：`DA7653943`
- DVS 分辨率：`1280 x 720`
- 历史海康首帧：`2600 x 2160`

The serial values must be treated as opaque strings. In particular, the DVS
serial is not a decimal number and must not be parsed or normalized.

序列号必须作为不透明字符串处理。尤其是 DVS 序列号不是普通十进制数字，不能做
数值解析或格式化。

### 1.2 The final camera implementation should remain native C++ / 最终相机实现应保持原生 C++

The official Fusion SDK already provides the native C++ abstraction:

```cpp
DvsRgbFusionCamera<HikCamera>
```

The recommended ownership model is:

```text
C++ application
  -> DvsRgbFusionCamera<HikCamera>
      -> DvsEventCamera
          -> DVSense DvsCameraManager
      -> HikCamera
          -> Hikrobot MVS SDK
```

官方 Fusion SDK 已经提供原生 C++ 抽象：

```cpp
DvsRgbFusionCamera<HikCamera>
```

推荐的设备所有权结构为：

```text
C++ 应用程序
  -> DvsRgbFusionCamera<HikCamera>
      -> DvsEventCamera
          -> DVSense DvsCameraManager
      -> HikCamera
          -> 海康 MVS SDK
```

MATLAB may remain an optional management or diagnostic layer, but it should not
own vendor SDK callbacks or load vendor camera DLLs directly. The current
project already follows this isolation rule for the single-DVS path.

MATLAB 可以保留为可选管理层或诊断层，但不应持有 vendor SDK 回调，也不应直接
加载 vendor 相机 DLL。当前项目的单 DVS 路径已经遵循这一隔离原则。

### 1.3 The current failure is below MATLAB / 当前失败发生在 MATLAB 之下

The current diagnostic record reproduces:

```text
size mismatch; expected {}, got {}
Get serial number failed.
Skip USB camera with empty serial number
updateCameras count=0 elapsed_ms=22374
```

当前诊断记录复现了：

```text
size mismatch; expected {}, got {}
Get serial number failed.
Skip USB camera with empty serial number
updateCameras count=0 elapsed_ms=22374
```

This means the DVSense discovery layer sees a USB device but does not obtain a
usable serial number. The device is discarded before the Fusion SDK can pair it
with the Hikrobot camera. This is not evidence that the DVS serial
`ffffffffffffffab` is invalid.

这说明 DVSense 发现层看到了 USB 设备，但没有拿到可用序列号。设备在进入
Fusion SDK 配对之前就被丢弃了。这不能证明 DVS 序列号
`ffffffffffffffab` 无效。

The old program being able to connect DVS and the current Fusion attempt
failing are not contradictory:

1. The old project path is a single-DVS helper path.
2. The Fusion path adds a second SDK, a second discovery path, and a different
   native process/runtime combination.
3. The historical successful Python run and current empty-serial diagnostic are
   observations from different runtime states.
4. The exact root cause of the empty serial is not established by the local
   source alone. It must be diagnosed at the DVSense runtime/driver/device
   discovery boundary before application integration continues.

原程序能连接 DVS，而当前 Fusion 尝试失败，并不矛盾：

1. 原项目是单 DVS helper 路径。
2. Fusion 路径增加了第二套 SDK、第二套发现流程以及不同的原生进程和运行库组合。
3. 历史 Python 成功记录和当前空序列号记录来自不同的运行时状态。
4. 仅凭当前本地源码无法确定空序列号的最终根因。必须先在 DVSense 运行库、驱动和
   设备发现边界排查，再继续应用集成。

## 2. Source Evidence / 源码证据

### 2.1 Official C++ Fusion SDK / 官方 C++ Fusion SDK

Root:

```text
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk
```

Key files and symbols:

| File / 文件 | Key symbols / 关键符号 |
|---|---|
| `CMakeLists.txt` | `MVS_INCLUDE_DIR`, `MVS_LIB_SEARCH_PATHS`, `find_package(OpenCV)`, `find_package(DvsenseDriver)`, `DvsRgbFusionCamera`, `DvsRgbCalib`, `BUILD_SAMPLES` |
| `include/DvsRgbFusionCamera/CameraManager/DvsRgbFusionCamera.hpp` | `DvsRgbFusionCamera`, `findCamera`, `openCamera`, `start`, `stop`, `addEventsStreamHandleCallback`, `addApsFrameCallback` |
| `include/DvsRgbFusionCamera/dvs/DvsEventCamera.hpp` | `DvsEventCamera`, `findCamera`, `openCamera`, `startCamera`, `registerEventCallback` |
| `include/DvsRgbFusionCamera/rgb/RgbCamera.hpp` | `RgbCamera` abstract interface and `create<RGBCameraType>` |
| `include/DvsRgbFusionCamera/rgb/hik/HikCamera.hpp` | `HikCamera`, MVS-backed RGB interface |
| `src/dvs/DvsEventCamera.cpp` | DVS enumeration, open, trigger-input enable, event callbacks |
| `src/rgb/hik/HikCamera.cpp` | MVS initialization, USB discovery, open, acquisition, pixel conversion, cleanup |
| `src/CameraManager/DvsRgbFusionCamera.cpp` | camera pairing, trigger callback, `FUSION_STREAM`, frame callback dispatch |
| `samples/FusionShowHik/FusionShowHik.cpp` | end-to-end official C++ sample |
| `README.md` | vendor installation, CMake variables, C++ quick start |

The symbol locations can be rechecked with:

```powershell
rg -n "findCamera|openCamera|start|FUSION_STREAM|addApsFrameCallback" `
  C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk
```

### 2.2 Official Python fusion application / 官方 Python 融合应用

Root:

```text
C:\Users\chen1\Desktop\DVS\dvsense_python_apps\apps\dvs_rgb_fusion
```

Key files and symbols:

| File / 文件 | Key symbols / 关键符号 |
|---|---|
| `camera_utils.py` | `_load_mvs_sdk`, `_configure_mvs_low_latency`, `MvsRgbCamera.open_first`, `find_dvs_camera`, `find_rgb_camera`, `find_cameras` |
| `tests/test_dvs_device_selection.py` | opaque DVS serial preservation and delayed enumeration tests |
| `tests/test_low_latency_rgb.py` | MVS exposure, frame-rate, buffer and latest-frame configuration test |
| `README.md` | installation, execution, MVS settings, low-latency policy and GPU options |

### 2.3 Current project / 当前项目

| File / 文件 | Observed responsibility / 已观察到的职责 |
|---|---|
| `src/native/src/dvsense_helper.cpp` | isolated DVSense helper process, DVS discovery/open/start/read/close |
| `src/native/bridge/dvsense_bridge.cpp` | C ABI bridge and helper process lifecycle |
| `src/native/bridge/dvsense_bridge.h` | exported C ABI declarations |
| `runtime/bin/*` | project-owned DVS helper/runtime closure |
| `runtime/README.md` | vendor DLL isolation and runtime ownership |
| `runtime/manifest.json` | current DVS runtime file list and hashes |
| `config/local.example.json` | machine-specific SDK/runtime paths and serial placeholders |
| `tests/native/fusion_connection_smoke.cpp` | native Fusion smoke test for events, first RGB frame and frame-gap stability |
| `docs/CONNECTION_BASELINE.md` | current hardware/runtime evidence and verified result |
| `docs/diagnostics/2026-08-21-fusion-baseline.md` | historical pre-reconnect diagnostic record |
| `docs/GPU_ACCELERATION_ROADMAP.md` | current GPU status and later CUDA layering plan |
| `src/native/cuda/gpu_smoke.cu` | existing CUDA smoke-test source |

## 3. Independent DVS Camera Connection / 独立 DVS 相机连接

### 3.1 Official C++ sequence / 官方 C++ 顺序

For an ordinary DVS camera, the official C++ wrapper uses this sequence:

```text
construct DvsEventCamera
  -> DvsCameraManager::getCameraDescs()
  -> select CameraDescription
  -> DvsCameraManager::openCamera(cameraDesc.serial)
  -> get TOOL_TRIGGER_IN
  -> setParam("enable", true)
  -> register event callback
  -> startCamera()
```

普通 DVS 相机的官方 C++ 包装顺序为：

```text
构造 DvsEventCamera
  -> DvsCameraManager::getCameraDescs()
  -> 选择 CameraDescription
  -> DvsCameraManager::openCamera(cameraDesc.serial)
  -> 获取 TOOL_TRIGGER_IN
  -> setParam("enable", true)
  -> 注册事件回调
  -> startCamera()
```

The direct implementation is in:

```text
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\src\dvs\DvsEventCamera.cpp
```

Key observed calls are:

```cpp
cameraDescs = camera_manager_.getCameraDescs();
dvs_camera_ = camera_manager_.openCamera(cameraDesc.serial);
trigger_in->setParam("enable", true);
dvs_camera_->start();
dvs_camera_->addEventsStreamHandleCallback(callback);
```

关键调用在上述文件中直接出现，接口名以源码为准。

### 3.2 Current project single-DVS sequence / 当前项目单 DVS 顺序

The existing helper performs the same basic operation behind a process boundary:

```text
bridge launches dvsense_helper.exe
  -> helper receives CMD_OPEN
  -> manager.updateCameras()
  -> manager.getCameraDescs()
  -> select requested serial
  -> manager.openCamera(serial)
  -> helper receives CMD_START
  -> camera->start()
  -> event callback writes a bounded latest batch
```

现有 helper 在独立进程边界之后完成同样的基础流程：

```text
bridge 启动 dvsense_helper.exe
  -> helper 收到 CMD_OPEN
  -> manager.updateCameras()
  -> manager.getCameraDescs()
  -> 选择请求序列号
  -> manager.openCamera(serial)
  -> helper 收到 CMD_START
  -> camera->start()
  -> 事件回调写入有界最新批次
```

The current helper does not open the Hikrobot camera and does not create a
`DvsRgbFusionCamera<HikCamera>` object. Therefore, its ability to connect a DVS
camera is not proof that the dual-camera Fusion path is healthy.

当前 helper 不打开海康相机，也不创建 `DvsRgbFusionCamera<HikCamera>`。所以它能
连接 DVS，并不能证明双相机 Fusion 路径已经正常。

### 3.3 DVS serial handling / DVS 序列号处理

The Python test explicitly checks that `ffffffffffffffab` is passed to
`open_camera` unchanged. The production helper must apply the same rule:

- keep the serial as `std::string`;
- do not convert it to an integer;
- do not remove leading or trailing characters;
- do not substitute an empty serial when enumeration fails.

Python 测试明确检查 `ffffffffffffffab` 被原样传入 `open_camera`。C++ 正式路径
也必须遵循同一规则：

- 使用 `std::string` 保存序列号；
- 不转换为整数；
- 不删除首尾字符；
- 枚举失败时不使用空序列号替代。

## 4. DVSync vs Independent DVSLume / DVSync 与独立 DVSLume

### 4.1 Product distinction / 产品区别

The official Python application distinguishes products by the discovered
`CameraDescription.product`:

```python
if str(matching.product).lower() == "dvsync":
    camera = manager.open_fusion_camera(matching.serial)
else:
    camera = manager.open_camera(matching.serial)
```

官方 Python 应用根据发现到的 `CameraDescription.product` 区分产品：

```python
if str(matching.product).lower() == "dvsync":
    camera = manager.open_fusion_camera(matching.serial)
else:
    camera = manager.open_camera(matching.serial)
```

The documented product rule is:

| Product / 产品 | DVSense open path / DVSense 打开路径 |
|---|---|
| `DVSync` | `open_fusion_camera(serial)` |
| `DVSLume`, `DVSLume-G1`, `DM3`, other ordinary event products | `open_camera(serial)` |

For the user's two independent cameras, the DVS side is the ordinary
`DVSLume` path. The software class `DvsRgbFusionCamera<HikCamera>` is a
coordinator for two independent devices; it is not evidence that the physical
DVS device is a `DVSync`.

对于用户的两台独立相机，DVS 侧应使用普通 `DVSLume` 路径。软件类
`DvsRgbFusionCamera<HikCamera>` 是两台独立设备的编排器，并不表示物理 DVS
设备就是 `DVSync`。

### 4.2 Engineering implication / 工程含义

Do not solve the current empty-serial problem by forcibly calling a Fusion-device
API. The correct diagnostic question is first:

```text
What product and serial does the DVSense discovery layer actually return?
```

不要通过强行调用融合设备 API 来绕过当前空序列号问题。第一诊断问题应当是：

```text
DVSense 发现层实际返回了什么 product 和 serial？
```

If discovery returns no valid `CameraDescription`, neither `open_camera` nor
`open_fusion_camera` has a valid serial to consume.

如果发现层没有返回有效的 `CameraDescription`，那么
`open_camera` 和 `open_fusion_camera` 都没有可用序列号可以打开。

## 5. Hikrobot MVS Discovery and Frame Acquisition / 海康 MVS 发现与取帧

### 5.1 Official C++ sequence / 官方 C++ 顺序

The observed `HikCamera` lifecycle is:

```text
MV_CC_Initialize()
  -> MV_CC_EnumDevices(MV_USB_DEVICE, ...)
  -> read chSerialNumber
  -> MV_CC_CreateHandle(...)
  -> MV_CC_OpenDevice(...)
  -> configure acquisition
  -> MV_CC_StartGrabbing()
  -> MV_CC_GetImageBuffer(..., 1000)
  -> convert pixel format to BGR8
  -> MV_CC_FreeImageBuffer(...)
  -> stop grabbing
  -> close device
  -> destroy handle
```

观察到的 `HikCamera` 生命周期为：

```text
MV_CC_Initialize()
  -> MV_CC_EnumDevices(MV_USB_DEVICE, ...)
  -> 读取 chSerialNumber
  -> MV_CC_CreateHandle(...)
  -> MV_CC_OpenDevice(...)
  -> 配置采集参数
  -> MV_CC_StartGrabbing()
  -> MV_CC_GetImageBuffer(..., 1000)
  -> 转换到 BGR8
  -> MV_CC_FreeImageBuffer(...)
  -> 停止取流
  -> 关闭设备
  -> 销毁句柄
```

The direct implementation is:

```text
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\src\rgb\hik\HikCamera.cpp
```

The C++ implementation enumerates USB devices only with `MV_USB_DEVICE` and
matches the requested serial against
`SpecialInfo.stUsb3VInfo.chSerialNumber`.

官方 C++ 实现使用 `MV_USB_DEVICE` 枚举，并将请求序列号与
`SpecialInfo.stUsb3VInfo.chSerialNumber` 比较。

### 5.2 Configuration observed in official C++ / 官方 C++ 中观察到的配置

`HikCamera::openCamera` sets or attempts to set:

- `TriggerMode` to off;
- `ImageCompressionMode` to `0`;
- `AcquisitionFrameRate` to the constructor FPS;
- `AcquisitionFrameRateEnable` to true;
- continuous auto exposure and continuous auto gain;
- line/strobe settings used by the Fusion trigger path;
- width rounded down to a multiple of four.

`HikCamera::openCamera` 中设置或尝试设置：

- `TriggerMode` 关闭；
- `ImageCompressionMode` 为 `0`；
- `AcquisitionFrameRate` 为构造函数帧率；
- `AcquisitionFrameRateEnable` 为 true；
- 连续自动曝光和连续自动增益；
- Fusion 触发路径使用的 line/strobe 参数；
- 将宽度向下取整到 4 的倍数。

The official implementation also contains a warm-up branch in
`HikCamera::startCamera` when trigger mode is off: it starts grabbing, obtains a
frame, stops, waits, and then starts the long-running grab thread. This is an
observed implementation detail, not a new API contract.

官方实现中，`HikCamera::startCamera` 在触发关闭时还包含一段预热逻辑：启动取流、
获取一帧、停止、等待，然后再启动长期取流线程。这是观察到的实现细节，不是新的
API 契约。

### 5.3 Python low-latency reference / Python 低延迟参考

The Python implementation uses the same MVS lifecycle and adds an explicit
low-latency policy:

```text
TriggerMode = off
ExposureAuto = off
ExposureTime = configured value
AcquisitionFrameRateEnable = true
AcquisitionFrameRate = configured value
ImageNodeNum = 1
GrabStrategy = MV_GrabStrategy_LatestImagesOnly
```

Python 实现使用相同的 MVS 生命周期，并额外明确了低延迟策略：

```text
TriggerMode = off
ExposureAuto = off
ExposureTime = 配置值
AcquisitionFrameRateEnable = true
AcquisitionFrameRate = 配置值
ImageNodeNum = 1
GrabStrategy = MV_GrabStrategy_LatestImagesOnly
```

The Python test verifies the frame-rate, exposure, node-count and
`LatestImagesOnly` settings with mocked MVS calls. This test validates the
configuration logic, not physical hardware stability.

Python 测试使用 mock MVS 调用验证了帧率、曝光、缓存节点数量和
`LatestImagesOnly` 设置。该测试验证的是配置逻辑，不是实体硬件稳定性。

### 5.4 Frame ownership / 帧内存所有权

The official C++ path:

1. receives an `MV_FRAME_OUT`;
2. converts the source pixel type into the `dvsense::ApsFrame` buffer;
3. calls `MV_CC_FreeImageBuffer`;
4. places the converted frame in the internal queue;
5. returns frames through `getNewRgbFrame`.

官方 C++ 路径：

1. 接收 `MV_FRAME_OUT`；
2. 将源像素格式转换到 `dvsense::ApsFrame` 缓冲区；
3. 调用 `MV_CC_FreeImageBuffer`；
4. 把转换后的帧放入内部队列；
5. 通过 `getNewRgbFrame` 返回帧。

The application must not retain pointers into the MVS frame buffer after
`MV_CC_FreeImageBuffer`. It should retain only copied/owned frame data.

在 `MV_CC_FreeImageBuffer` 之后，应用程序不能继续持有 MVS 帧缓冲区指针，只能
保留已经复制或由应用拥有的帧数据。

## 6. Official Fusion SDK Callback Flow / 官方 Fusion SDK 回调流程

### 6.1 Pairing and opening / 配对与打开

The official C++ sample follows this logical sequence:

```cpp
std::unique_ptr<DvsRgbFusionCamera<HikCamera>> fusionCamera =
    std::make_unique<DvsRgbFusionCamera<HikCamera>>(30);

std::vector<dvsense::CameraDescription> dvsSerials;
std::vector<std::string> rgbSerials;

fusionCamera->findCamera(dvsSerials, rgbSerials);

DvsRgbCameraSerial selected;
selected.dvs_serial_number = dvsSerials[0];
selected.rgb_serial_number = rgbSerials[0];

fusionCamera->openCamera(selected);
fusionCamera->start(dvsense::FUSION_STREAM);
```

官方 C++ 示例遵循以下逻辑顺序：

```text
构造 DvsRgbFusionCamera<HikCamera>
  -> findCamera(dvsSerials, rgbSerials)
  -> 选择 DVS CameraDescription 和 RGB 字符串序列号
  -> openCamera(selected)
  -> start(FUSION_STREAM)
```

`DvsRgbFusionCamera::findCamera` first calls the DVS finder and then the RGB
finder. `openCamera` opens RGB first and DVS second. This order is an observed
implementation detail and should be retained when diagnosing partial-open
failures.

`DvsRgbFusionCamera::findCamera` 先调用 DVS 发现，再调用 RGB 发现。
`openCamera` 先打开 RGB，再打开 DVS。这是源码中观察到的顺序，排查部分打开失败
时应保留该事实。

### 6.2 Event callback / 事件回调

The public event callback is:

```cpp
addEventsStreamHandleCallback(
    const dvsense::EventsStreamHandleCallback& callback)
```

The callback receives an event iterator range:

```cpp
const dvsense::EventIterator_t begin,
const dvsense::EventIterator_t end
```

The official sample iterates the range and uses event fields including `x`,
`y`, and `polarity` to accumulate a display image.

公开事件回调为：

```cpp
addEventsStreamHandleCallback(
    const dvsense::EventsStreamHandleCallback& callback)
```

回调接收事件迭代器范围。官方示例遍历范围，并使用 `x`、`y`、`polarity` 等字段
累计显示图像。

### 6.3 RGB frame callback / RGB 帧回调

The public RGB callback is:

```cpp
addApsFrameCallback(const FrameCallback& frameCallback)
```

The callback receives `dvsense::ApsFrame`. The official sample checks
`getDataSize()`, reads `data()`, `width()` and `height()`, and wraps the data
as an OpenCV image for display.

公开 RGB 回调为：

```cpp
addApsFrameCallback(const FrameCallback& frameCallback)
```

回调接收 `dvsense::ApsFrame`。官方示例检查 `getDataSize()`，读取 `data()`、
`width()` 和 `height()`，再将数据包装为 OpenCV 图像。

### 6.4 `FUSION_STREAM` start behavior / `FUSION_STREAM` 启动行为

The observed `DvsRgbFusionCamera::start(FUSION_STREAM)` behavior is:

1. start the DVS camera;
2. wait approximately one second;
3. inspect the DVS sync tool's `"mode"` parameter;
4. if the mode is `"SLAVE"`, wait until an event arrives;
5. start the RGB camera.

源码中观察到的 `DvsRgbFusionCamera::start(FUSION_STREAM)` 行为是：

1. 启动 DVS；
2. 等待约一秒；
3. 读取 DVS sync tool 的 `"mode"` 参数；
4. 如果模式为 `"SLAVE"`，等待事件到达；
5. 启动 RGB。

The official `openCamera` also installs an internal trigger-input callback.
On a trigger sequence, it records the rising timestamp, obtains a new RGB
frame through `getNewRgbFrame`, sets the exposure timestamps, and dispatches
the frame to registered APS callbacks when the data is non-empty.

官方 `openCamera` 还会安装内部 trigger-input 回调。在触发序列中，它记录上升沿
时间戳，通过 `getNewRgbFrame` 获取新 RGB 帧，设置曝光时间戳，并在数据非空时
把帧分发给已注册的 APS 回调。

This is why the first RGB frame and continuous RGB frames must be validated
after `start(FUSION_STREAM)`, not only after `openCamera`.

因此必须在 `start(FUSION_STREAM)` 之后验证 RGB 首帧和持续 RGB 帧，不能只验证
`openCamera` 返回成功。

### 6.5 Stop and destroy / 停止与销毁

The official Fusion stop path is:

```text
stop(FUSION_STREAM)
  -> rgb_camera_->stopCamera()
  -> dvs_camera_->stopCamera()
  -> remove callbacks as needed
  -> destroy()
      -> reset DVS object
      -> destroy RGB camera
```

官方 Fusion 停止路径为：

```text
stop(FUSION_STREAM)
  -> rgb_camera_->stopCamera()
  -> dvs_camera_->stopCamera()
  -> 按需移除回调
  -> destroy()
      -> 释放 DVS 对象
      -> 销毁 RGB 相机
```

Every native test must exercise stop and destroy even when a frame or event
threshold is not reached. Partial-open cleanup is part of the connection test.

即使没有达到事件或帧数量阈值，每个原生测试也必须执行 stop 和 destroy。部分打开
后的清理同样属于连接测试的一部分。

## 7. Runtime DLLs and Dependency Paths / 运行时 DLL 与依赖路径

### 7.1 System-installed development paths / 系统开发路径

The local official CMake cache records:

```text
DVSense CMake package:
C:/Program Files (x86)/DvsenseDriver/share/cmake/DvsenseDriver

DVSense headers/libs/bin:
C:/Program Files (x86)/DvsenseDriver

MVS headers:
C:/Program Files (x86)/MVS/Development/Includes

MVS import library:
C:/Program Files (x86)/MVS/Development/Libraries/win64/MvCameraControl.lib

MVS native runtime:
C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64

OpenCV/FFmpeg:
C:/vcpkg-master/vcpkg-master/installed/x64-windows
```

本机官方 CMake 缓存记录了上述路径。

The OpenCV header used by the local build is:

```text
C:/vcpkg-master/vcpkg-master/installed/x64-windows/include/opencv4/opencv2/core.hpp
```

Do not assume the header is directly under `include/opencv2`. The official
build adds the `include/opencv4` directory.

不要假定头文件直接位于 `include/opencv2`。官方构建实际加入的是
`include/opencv4` 目录。

### 7.2 Runtime ownership / 运行时归属

The current project runtime policy is:

- `runtime/bin/dvsense_bridge.dll` is project-owned;
- `runtime/bin/dvsense_helper.exe` is project-owned;
- the DVSense DLL closure listed in `runtime/manifest.json` is used by the
  single-DVS helper;
- MVS device runtime remains system-installed;
- the official Fusion DLLs are currently under
  `artifacts/build/official-fusion-local/bin/Release`, not yet part of the
  project's final runtime package.

当前项目运行时策略为：

- `runtime/bin/dvsense_bridge.dll` 属于项目；
- `runtime/bin/dvsense_helper.exe` 属于项目；
- `runtime/manifest.json` 中列出的 DVSense DLL 闭包供单 DVS helper 使用；
- MVS 设备运行库保留系统安装；
- 官方 Fusion DLL 当前位于
  `artifacts/build/official-fusion-local/bin/Release`，还不是项目最终运行时包的一部分。

MATLAB must not load `DvsenseDriver.dll`, `DvsenseHal.dll`, or
`DvsenseBase.dll` directly. The current runtime manual explicitly assigns
those libraries to the helper process.

MATLAB 不得直接加载 `DvsenseDriver.dll`、`DvsenseHal.dll` 或
`DvsenseBase.dll`。当前运行时手册明确将这些库归属给 helper 进程。

Do not copy the entire MVS or DVSense installation into the project. First
verify license/redistribution permission and the complete dependency closure.
For now, record system paths in `config/local.json` and use them for the native
Fusion build.

不要把整套 MVS 或 DVSense 安装目录复制到项目中。应先核对许可和完整依赖闭包。
当前阶段把系统路径记录在 `config/local.json`，并用于原生 Fusion 构建。

## 8. MSVC and CMake Installation and Build / MSVC 与 CMake 安装构建

### 8.1 Required components / 必需组件

The official Fusion README requires:

- DVSense driver;
- RGB camera vendor driver, here Hikrobot MVS;
- OpenCV with FFmpeg support;
- Visual Studio 2022 Community or a later C++ toolchain;
- CMake.

官方 Fusion README 要求：

- DVSense driver；
- RGB 相机厂商驱动，本项目为海康 MVS；
- 带 FFmpeg 支持的 OpenCV；
- Visual Studio 2022 Community 或更新的 C++ 工具链；
- CMake。

Engineering installation checklist:

1. In Visual Studio Installer, install the Desktop development with C++
   workload.
2. Ensure an x64 MSVC toolset and Windows SDK are selected.
3. Install CMake or use the existing CMake installation.
4. Install vcpkg OpenCV with FFmpeg support for the `x64-windows` triplet.
5. Install DVSense driver and Hikrobot MVS before running hardware tests.

工程安装清单：

1. 在 Visual Studio Installer 中安装“使用 C++ 的桌面开发”工作负载。
2. 确保选择 x64 MSVC 工具集和 Windows SDK。
3. 安装 CMake，或使用本机已有的 CMake。
4. 使用 `x64-windows` triplet 安装带 FFmpeg 的 vcpkg OpenCV。
5. 在硬件测试前安装 DVSense driver 和海康 MVS。

On this machine, CMake is available at:

```text
C:\cmake-4.3.3-windows-x86_64\bin\cmake.exe
```

The local official cache records a Visual Studio generator under:

```text
C:\Program Files\Microsoft Visual Studio\18\Community
```

and MSVC version `19.51.36248.0` in the project diagnostic record. A normal
PowerShell session does not expose `cl.exe`; this does not by itself prove that
MSVC is missing. Use the Visual Studio Developer PowerShell or Developer
Command Prompt before invoking CMake builds that require compiler tools.

本机普通 PowerShell 中当前找不到 `cl.exe`，但这不等于 MSVC 未安装。执行需要编译器
的 CMake 构建时，应使用 Visual Studio Developer PowerShell 或 Developer Command
Prompt。

### 8.2 Configure the official SDK / 配置官方 SDK

The following command matches the local official CMake structure. Adjust the
generator to the installed Visual Studio version if necessary:

```powershell
cmake -S C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk `
  -B C:/Users/chen1/Desktop/DVSenseRealtimeV1-dev/DVSenseRealtimeV1-dev/artifacts/build/official-fusion-local `
  -G "Visual Studio 18 2026" -A x64 `
  -DBUILD_SAMPLES=ON `
  -DDvsenseDriver_DIR="C:/Program Files (x86)/DvsenseDriver/share/cmake/DvsenseDriver" `
  -DMVS_INCLUDE_DIR="C:/Program Files (x86)/MVS/Development/Includes" `
  -DMVS_LIB_SEARCH_PATHS="C:/Program Files (x86)/MVS/Development/Libraries/win64"
```

上述命令符合本机官方 CMake 结构。若开发机安装的是其他 Visual Studio 版本，应
替换 generator。

The official `CMakeLists.txt` also uses the local vcpkg toolchain and searches
for OpenCV, FFmpeg and Boost. The local cache records:

```text
C:/vcpkg-master/vcpkg-master/scripts/buildsystems/vcpkg.cmake
C:/vcpkg-master/vcpkg-master/installed/x64-windows
```

官方 `CMakeLists.txt` 还使用本机 vcpkg toolchain，并查找 OpenCV、FFmpeg 和 Boost。
本机缓存记录了上述路径。

### 8.3 Build the official sample / 构建官方示例

```powershell
cmake --build C:/Users/chen1/Desktop/DVSenseRealtimeV1-dev/DVSenseRealtimeV1-dev/artifacts/build/official-fusion-local `
  --config Release --target FusionShowHik
```

Expected local outputs:

```text
artifacts/build/official-fusion-local/bin/Release/FusionShowHik.exe
artifacts/build/official-fusion-local/bin/Release/DvsRgbFusionCamera.dll
artifacts/build/official-fusion-local/bin/Release/DvsRgbCalib.dll
```

### 8.4 Runtime launch environment / 运行时启动环境

For the official Fusion sample, make the MVS native runtime and installed
DVSense runtime visible to the process:

```powershell
$env:PATH = `
  "C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64;" + `
  "C:/Program Files (x86)/DvsenseDriver/bin;" + `
  $env:PATH
```

Then launch the sample from its release directory. The current diagnostic
record specifically confirms that `MvCameraControl.dll` is in the MVS runtime
directory, not in the development library directory.

然后从 Release 目录启动示例。当前诊断已确认 `MvCameraControl.dll` 位于 MVS
runtime 目录，而不是开发库目录。

## 9. Native Connection Smoke Test / 原生连接 Smoke Test

The current project contains:

```text
tests/native/fusion_connection_smoke.cpp
```

Its intended hardware acceptance criteria are:

- DVS event count reaches the configured minimum;
- at least the configured number of non-empty RGB frames arrive;
- the first RGB frame reports width, height and data size;
- the maximum observed RGB inter-frame gap stays below the configured limit;
- the camera remains connected until the pre-close check;
- the program prints `result=PASS`.

其设计的硬件验收条件为：

- DVS 事件数量达到最低值；
- 收到至少指定数量的非空 RGB 帧；
- 首个 RGB 帧报告宽度、高度和数据大小；
- 观测到的最大 RGB 帧间隔不超过配置上限；
- 关闭前相机仍保持连接；
- 程序输出 `result=PASS`。

The default invocation shape is:

```powershell
fusion_connection_smoke.exe 10 1000 1 5
```

The four arguments are:

```text
duration_seconds max_rgb_gap_ms minimum_events minimum_nonempty_rgb_frames
```

The test is intentionally placed before MATLAB integration. It validates the
native camera path and makes the current failure boundary visible.

该测试故意放在 MATLAB 集成之前，用于验证原生相机路径，并让当前失败边界可见。

## 10. Current Empty-Serial Failure and Boundary / 当前空序列号失败与边界

### 10.1 What is proven / 已被证明的事实

The local diagnostic proves:

- Windows still sees the physical DVS and MVS USB devices;
- the official project was rebuilt successfully against the current installed
  headers/import libraries;
- the MVS native runtime exists at the expected runtime path;
- the DVSense enumeration output can still fail with an empty serial;
- the failure occurs before a valid DVS `CameraDescription` is available.

本机诊断已证明：

- Windows 仍能看到实体 DVS 和 MVS USB 设备；
- 官方项目已使用当前安装的头文件和导入库成功重建；
- MVS 原生 runtime 位于预期路径；
- DVSense 枚举仍可能返回空序列号；
- 失败发生在有效 DVS `CameraDescription` 产生之前。

### 10.2 What is not proven / 尚未被证明的事实

The source evidence does not yet prove:

- that the DVS hardware is defective;
- that `ffffffffffffffab` has changed;
- that `DVSLume` should be opened as `DVSync`;
- that the MVS camera is the cause of the DVS empty serial;
- that copying more DLLs into `runtime/bin` will fix discovery;
- that the current Fusion callback path has produced a real hardware frame.

源码证据尚不能证明：

- DVS 硬件损坏；
- `ffffffffffffffab` 已经改变；
- `DVSLume` 应按 `DVSync` 打开；
- 海康相机是 DVS 空序列号的原因；
- 向 `runtime/bin` 复制更多 DLL 就能修复发现；
- 当前 Fusion 回调路径已经产生真实硬件帧。

### 10.3 Historical diagnostic order / 历史诊断顺序

The sequence below is retained as the order used before the physical
reconnect. It is historical evidence, not the current connection status.

下面的顺序保留为物理重新插拔前使用过的诊断证据，不代表当前连接状态。

1. Run the native DVS-only discovery with the current installed DVSense
   runtime.
2. Run the official Fusion sample with the MVS runtime directory on `PATH`.
3. Record product, serial and both enumeration lists before any open call.
4. Do not mix the old project DVSense DLLs with the current installed
   DVSense package.
5. Only after a non-empty DVS serial and non-empty RGB serial are observed,
   evaluate `openCamera`, `FUSION_STREAM`, callbacks and frame stability.
6. If the serial remains empty in both the standalone native test and the
   official path, keep the blocker at the DVSense discovery/runtime boundary.

1. 使用当前安装的 DVSense runtime 执行原生 DVS 单机发现。
2. 将 MVS runtime 目录加入 `PATH` 后执行官方 Fusion 示例。
3. 在任何 open 调用之前记录 product、serial 和两套枚举列表。
4. 不要把项目旧版 DVSense DLL 与当前安装版 DVSense 混用。
5. 只有在 DVS 和 RGB 序列号都非空之后，才评估 `openCamera`、
   `FUSION_STREAM`、回调和帧稳定性。
6. 如果独立原生测试和官方路径都仍返回空序列号，应继续把阻塞点放在 DVSense
   发现和运行库边界，不进入 MATLAB Fusion 集成。

## 11. GPU Acceleration Roadmap / GPU 加速分层路线

### 11.1 Current status / 当前状态

The current project has GPU-related preparation, but GPU recognition is not
complete:

- `src/native/cuda/gpu_smoke.cu` is a CUDA smoke-test source;
- `docs/GPU_ACCELERATION_ROADMAP.md` describes a later CUDA backend;
- the current GPU-capable recognition backend still delegates to CPU;
- the current camera and display baseline is not evidence of GPU acceleration.

当前项目已经有 GPU 准备，但 GPU 识别尚未完成：

- `src/native/cuda/gpu_smoke.cu` 是 CUDA smoke-test 源码；
- `docs/GPU_ACCELERATION_ROADMAP.md` 描述了后续 CUDA backend；
- 当前标记为 GPU-capable 的识别后端仍委托 CPU；
- 当前相机和显示基线不能证明已经使用 GPU 加速。

### 11.2 Recommended native C++ layers / 推荐的原生 C++ 分层

The final C++ program should use the following order:

```text
Layer 0: vendor acquisition
  DVSense callback + MVS acquisition thread

Layer 1: bounded native transport
  latest event batch + owned latest RGB frame

Layer 2: CUDA preprocessing
  event accumulation, event image, color/overlay preparation

Layer 3: CUDA geometry
  RGB resize, warp/homography and fusion composition

Layer 4: CUDA recognition
  activity filtering, features, tracking and optional inference

Layer 5: display/output
  newest complete fused frame and status
```

最终 C++ 程序建议使用以下顺序：

```text
第 0 层：vendor 采集
  DVSense 回调 + MVS 取帧线程

第 1 层：原生有界传输
  最新事件批次 + 应用拥有的最新 RGB 帧

第 2 层：CUDA 预处理
  事件累计、事件图像、颜色和叠加准备

第 3 层：CUDA 几何处理
  RGB 缩放、warp/homography 和融合合成

第 4 层：CUDA 识别
  活动滤波、特征、跟踪和可选推理

第 5 层：显示与输出
  最新完整融合帧和状态
```

Engineering rules:

- do not put CUDA work inside the vendor callback if it can block acquisition;
- use fixed-capacity buffers;
- prefer newest complete frame/window over unbounded queues;
- use pinned host memory and preallocated device buffers after profiling confirms
  the transfer is material;
- use asynchronous CUDA streams and synchronize only for small status/results;
- keep a CPU fallback until numerical equivalence and long-run stability are
  verified;
- measure end-to-end latency and frame drops before enabling GPU by default.

工程规则：

- 不要让 CUDA 阻塞 vendor 回调和采集线程；
- 使用固定容量缓冲区；
- 优先保留最新完整帧或窗口，不创建无界队列；
- 只有性能分析证明传输成本明显后，再使用页锁定主机内存和预分配设备缓冲；
- 使用异步 CUDA stream，只在读取小型状态或结果时同步；
- 在数值一致性和长时间稳定性验证前保留 CPU fallback；
- 在默认启用 GPU 前测量端到端延迟和丢帧。

GPU should be added after native camera acceptance, not used to mask discovery,
driver or serial failures. Camera enumeration and vendor device ownership are
CPU/vendor SDK responsibilities.

GPU 应在原生相机验收通过后再加入，不能用来掩盖发现、驱动或序列号问题。相机
枚举和 vendor 设备所有权仍然属于 CPU/vendor SDK 层。

## 12. Native Developer Checklist / 原生开发检查清单

Before declaring the C++ camera baseline complete:

在宣布 C++ 相机基线完成之前：

- [ ] DVSense driver is installed and the runtime version is recorded.
- [ ] MVS development headers and `MvCameraControl.lib` are present.
- [ ] `MvCameraControl.dll` is available from the MVS runtime directory.
- [ ] OpenCV headers are found through `include/opencv4`.
- [ ] MSVC and CMake are invoked from a developer environment.
- [ ] DVS discovery returns a non-empty `CameraDescription.serial`.
- [ ] RGB discovery returns a non-empty MVS serial.
- [ ] `openCamera` returns true for both devices.
- [ ] `start(FUSION_STREAM)` returns zero.
- [ ] DVS event callback receives non-empty batches.
- [ ] RGB callback receives a non-empty first frame.
- [ ] RGB frames continue arriving within the selected gap threshold.
- [ ] `stop` and `destroy` release both cameras.
- [ ] repeated start/stop does not leave a stale helper or camera lock.
- [ ] the exact build/runtime paths are recorded in a diagnostic Markdown file.

- [ ] 已安装 DVSense driver，并记录运行库版本。
- [ ] 已存在 MVS 头文件和 `MvCameraControl.lib`。
- [ ] MVS runtime 目录中存在 `MvCameraControl.dll`。
- [ ] OpenCV 通过 `include/opencv4` 找到头文件。
- [ ] MSVC 和 CMake 从 developer 环境启动。
- [ ] DVS 发现返回非空 `CameraDescription.serial`。
- [ ] RGB 发现返回非空 MVS 序列号。
- [ ] 两台相机的 `openCamera` 都返回 true。
- [ ] `start(FUSION_STREAM)` 返回零。
- [ ] DVS 事件回调收到非空批次。
- [ ] RGB 回调收到非空首帧。
- [ ] RGB 帧在选定间隔阈值内持续到达。
- [ ] `stop` 和 `destroy` 释放两台相机。
- [ ] 重复启停不会留下残余 helper 或相机锁。
- [ ] 在诊断 Markdown 中记录精确构建和运行时路径。

## 13. Source References / 源码参考

All references below are local files used for this manual:

以下全部是本手册实际使用的本地文件：

```text
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\README.md
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\CMakeLists.txt
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\include\DvsRgbFusionCamera\CameraManager\DvsRgbFusionCamera.hpp
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\include\DvsRgbFusionCamera\dvs\DvsEventCamera.hpp
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\include\DvsRgbFusionCamera\rgb\RgbCamera.hpp
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\include\DvsRgbFusionCamera\rgb\hik\HikCamera.hpp
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\src\dvs\DvsEventCamera.cpp
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\src\rgb\hik\HikCamera.cpp
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\src\CameraManager\DvsRgbFusionCamera.cpp
C:\Users\chen1\Desktop\DVS\dvsense_fusion_combo_sdk\samples\FusionShowHik\FusionShowHik.cpp
C:\Users\chen1\Desktop\DVS\dvsense_python_apps\apps\dvs_rgb_fusion\camera_utils.py
C:\Users\chen1\Desktop\DVS\dvsense_python_apps\apps\dvs_rgb_fusion\README.md
C:\Users\chen1\Desktop\DVS\dvsense_python_apps\apps\dvs_rgb_fusion\tests\test_dvs_device_selection.py
C:\Users\chen1\Desktop\DVS\dvsense_python_apps\apps\dvs_rgb_fusion\tests\test_low_latency_rgb.py
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\src\native\src\dvsense_helper.cpp
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\src\native\bridge\dvsense_bridge.cpp
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\src\native\bridge\dvsense_bridge.h
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\runtime\README.md
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\runtime\manifest.json
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\config\local.example.json
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\tests\native\fusion_connection_smoke.cpp
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\docs\diagnostics\2026-08-21-fusion-baseline.md
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\docs\DVSENSE_DLL_ANALYSIS.md
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\docs\GPU_ACCELERATION_ROADMAP.md
C:\Users\chen1\Desktop\DVSenseRealtimeV1-dev\DVSenseRealtimeV1-dev\src\native\cuda\gpu_smoke.cu
```

This manual is a source-grounded reference, not a claim that the current
hardware Fusion smoke test has already passed. Hardware acceptance remains
pending until the native test prints real event and RGB statistics and
`result=PASS`.

本手册是基于源码的参考，不代表当前硬件 Fusion smoke test 已经通过。只有当原生
测试输出真实事件和 RGB 统计并打印 `result=PASS` 后，硬件验收才算完成。
