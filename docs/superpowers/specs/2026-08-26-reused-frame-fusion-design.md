# Reused-Frame Fusion and RGB Live Controls Design

## Goal / 目标

Add a real third Fusion preview to the existing workbench without discovering,
opening, closing, or reconnecting either camera when Fusion is enabled. Fusion
reuses the latest DVS display frame and Hikrobot RGB preview frame already
owned by the existing acquisition paths.

在现有工作台中增加真实的第三路 Fusion 预览。启用 Fusion 时不得重新枚举、
打开、关闭或重连任何相机；Fusion 直接复用现有 DVS 显示帧和 Hikrobot RGB
预览帧。

The same change adds RGB exposure and brightness-threshold controls to the
Live Control panel so the operator can tune the RGB and Fusion views while
watching them.

同一改动在“实时控制”中增加 RGB 曝光和亮度阈值控件，使操作者可以边看 RGB
与 Fusion 画面边调整参数。

## Scope / 范围

The first slice includes:

- reuse of independently acquired DVS and RGB preview frames;
- calibrated RGB warp into the DVS 1280 x 720 coordinate system;
- visible DVS-event overlay on the warped RGB image;
- one bounded latest Fusion frame;
- RGB exposure slider in Live Control;
- RGB brightness-threshold slider in Live Control;
- truthful calibration and input-availability status;
- regression coverage for independent DVS and RGB operation.

第一阶段包括：

- 复用独立采集的 DVS 和 RGB 预览帧；
- 将 RGB 标定变换到 DVS 1280 x 720 坐标系；
- 在变换后的 RGB 图像上叠加可见 DVS 事件；
- 只保留一张有界的最新 Fusion 帧；
- 在“实时控制”中增加 RGB 曝光滑块；
- 在“实时控制”中增加 RGB 亮度阈值滑块；
- 如实显示标定与输入可用状态；
- 保证 DVS、RGB 独立运行模式不回归。

The first slice does not claim hardware timestamp synchronization, use the
official `FUSION_STREAM`, generate calibration, record Fusion video, or feed
RGB data into riser recognition.

第一阶段不宣称实现硬件时间同步，不使用官方 `FUSION_STREAM`，不生成标定，
不录制 Fusion 视频，也不把 RGB 数据送入立管识别。

## Architectural Decision / 架构决策

Camera ownership remains unchanged:

```text
app.run
  -> DVSenseCameraSource -> existing DVS helper -> DVSLume
  -> HikrobotCameraSource -> hikrobot_mex -> Hikrobot
```

Fusion is a display-processing module with no camera interface and no camera
ownership:

```text
latest DVS Display Frame -----+
                              +-> FusionRenderer -> latest Fusion Frame
latest RGB Preview Frame -----+
```

`FusionRenderer` is the seam. Its interface accepts existing images and
configuration, then returns a result containing the newest fused image and
truthful status. It never discovers devices, changes acquisition state, or
retains an unbounded frame queue.

`FusionRenderer` 是 Fusion seam。它的接口接收现有图像和配置，返回最新融合
图像及真实状态；它不得发现设备、改变采集状态或维护无界帧队列。

This replaces the earlier first-slice proposal in
`2026-08-21-cpp-fusion-preview-design.md` that assigned both cameras to a new
Fusion helper. The earlier design remains historical documentation for a
future hardware-synchronized adapter.

本设计取代旧设计中“由新 Fusion helper 独占双相机”的第一阶段方案。旧设计
保留为未来硬件同步 adapter 的历史资料。

## FusionRenderer Interface / FusionRenderer 接口

The MATLAB module exposes a small interface:

```matlab
renderer = fusion.FusionRenderer(cfg)
result = renderer.render(dvsFrame, rgbFrame, inputState)
renderer.setRgbThreshold(value)
renderer.reset()
```

`render` returns:

```text
frame                 uint8 [720 x 1280 x 3] or empty
valid                 logical scalar
status                ready | waiting-dvs | waiting-rgb | calibration-error
reason                user-facing diagnostic text
calibrationValid      logical scalar
rgbThreshold          scalar integer in [0, 255]
```

The module keeps normalized calibration state and reusable image-processing
objects internally. Callers do not need to know the transform representation,
threshold algorithm, overlay colors, or image-warp implementation.

模块内部保存归一化标定状态和可复用的图像处理对象。调用者不需要了解变换
表示、阈值算法、叠加颜色或图像变换实现。

## Frame Data Flow / 帧数据流

`app.run` retains the newest frame from each existing display path:

1. DVS acquisition updates `latestDvsFrame` at its current display cadence.
2. RGB acquisition updates `latestRgbFrame` at its current display cadence.
3. When either input changes and both are available, `FusionRenderer.render`
   produces a new Fusion frame.
4. `WorkbenchViewer.updateFusion` updates the existing Fusion surface.
5. Disconnecting either camera clears the Fusion frame and publishes a
   waiting status; it does not affect the other camera.

`app.run` 保留两条现有显示链路的最新画面：任一输入更新且两者都可用时才生成
新的 Fusion 帧。任一相机断开时清空 Fusion 画面并显示等待状态，不影响另一台
相机。

Fusion never calls `readDisplayFrame` on a source. Only `app.run` reads each
source, once per existing scheduling decision, and passes the returned frame
to its consumers.

Fusion 不得自行调用数据源的 `readDisplayFrame`。只有 `app.run` 按现有调度读取
每个数据源一次，再把结果交给各个消费者，从而避免重复采集。

## Calibration and Rendering / 标定与渲染

Configuration uses `fusion.calibrationFile`. When
`fusion.calibrationEnabled` is true, startup validation requires this file.
The first implementation accepts the existing official
`calibration_result.json` and extracts the RGB-to-DVS mapping required for the
configured calibration distance.

配置使用 `fusion.calibrationFile`。当 `fusion.calibrationEnabled=true` 时，启动
校验要求文件存在。第一版读取现有官方 `calibration_result.json`，提取当前标定
距离对应的 RGB 到 DVS 变换。

Rendering order is:

1. normalize the RGB frame to `uint8` RGB;
2. apply the configured brightness threshold;
3. warp RGB into the DVS 1280 x 720 coordinate system;
4. convert the indexed DVS display frame into event masks;
5. overlay ON events in green and OFF events in magenta;
6. return one `uint8 [720 x 1280 x 3]` frame.

If calibration is disabled or invalid, the Fusion surface stays empty and
reports the exact reason. The implementation must not silently resize RGB and
claim that it is calibrated Fusion.

如果标定关闭或无效，Fusion 画面保持空白并显示准确原因；不得仅缩放 RGB 后
冒充已标定 Fusion。

## RGB Live Controls / RGB 实时控制

Two controls appear in the Live Control panel.

### RGB Exposure / RGB 曝光

- range: 100 to 30000 microseconds;
- step: 100 microseconds;
- enabled only while RGB is connected;
- initial value comes from the camera readback, not a UI constant;
- writes are coalesced through the existing command mailbox;
- successful writes update the displayed value with camera readback;
- write failure keeps the GUI open and displays the device error.

范围为 100–30000 µs，步长 100 µs。只有 RGB 已连接时启用，初值来自相机
读回；写入通过现有命令邮箱合并，成功后显示相机读回值，失败时保留 GUI 并
显示设备错误。

### RGB Brightness Threshold / RGB 亮度阈值

- range: integer 0 to 255;
- default: 0;
- enabled while an RGB frame source is available;
- luminance is `Y = 0.299R + 0.587G + 0.114B`;
- pixels with `Y < threshold` become black;
- pixels with `Y >= threshold` retain their RGB values;
- the threshold affects RGB preview and Fusion rendering only;
- it does not write a Hikrobot camera parameter or alter recorded raw data.

范围为整数 0–255，默认值为 0。亮度使用
`Y = 0.299R + 0.587G + 0.114B`；低于阈值的像素置黑，其余像素保留原 RGB
值。阈值只影响 RGB 预览和 Fusion，不写入海康参数，也不改变原始数据。

Threshold processing lives in one shared function used by both RGB preview
and Fusion, so the two views cannot drift to different threshold semantics.

RGB 预览与 Fusion 使用同一个阈值函数，避免两处产生不同语义。

## UI Changes / 界面改动

The existing Fusion panel becomes a real third `FrameSurface`. Live Control
contains the exposure and threshold sliders with current numeric values and a
threshold reset action. Controls publish versioned UI commands:

```text
setRgbExposureUs(value)
setRgbThreshold(value)
resetRgbThreshold
```

The viewer remains an observer. It does not modify frames, call camera
sources, or perform calibration.

现有 Fusion 区域变成真实的第三个 `FrameSurface`。“实时控制”显示曝光、阈值
滑块、当前数值和阈值重置操作。Viewer 仍然只是观察者，不修改画面、不调用
相机数据源，也不执行标定。

## Lifecycle and Errors / 生命周期与错误

- Connecting DVS or RGB follows the existing path.
- Fusion becomes ready automatically when both latest frames and valid
  calibration exist.
- No Fusion connect/disconnect command is introduced.
- Disconnecting DVS clears only DVS and Fusion state.
- Disconnecting RGB clears only RGB and Fusion state.
- Calibration parse or warp failures disable Fusion without stopping either
  camera.
- Closing the workbench releases both existing sources through the current
  cleanup path; Fusion owns no external resources.

连接 DVS/RGB 继续使用现有路径。两张最新画面和有效标定同时存在时 Fusion 自动
就绪，不增加 Fusion 连接/断开命令。标定解析或变换失败只禁用 Fusion，不停止
任何相机。

## Testing / 测试

Automated MATLAB tests cover:

- configuration requires calibration only when enabled;
- official calibration JSON parsing and normalized transform shape;
- threshold boundaries 0 and 255 and a hand-derived luminance fixture;
- identical threshold semantics for RGB preview and Fusion input;
- calibrated output shape and class;
- missing DVS, missing RGB, and invalid calibration statuses;
- latest-frame replacement without queue growth;
- UI command mapping, validation, coalescing, and reset;
- exposure control enablement and camera-readback publication;
- Fusion surface update and clear behavior;
- independent DVS and RGB connection regressions.

自动测试覆盖配置、官方标定 JSON、阈值边界与手算亮度样例、输出契约、缺少
输入状态、最新帧替换、UI 命令、曝光读回、Fusion surface 和独立连接回归。

Hardware validation covers:

1. connect DVS once;
2. connect RGB once;
3. confirm both independent previews remain live;
4. confirm Fusion appears without another discovery or open operation;
5. adjust exposure and observe both RGB and Fusion;
6. adjust threshold and observe identical threshold behavior;
7. disconnect and reconnect each camera independently;
8. close the workbench and verify both cameras are released.

实机验证要求两台相机各连接一次，Fusion 出现时不得再次发现或打开设备；曝光与
阈值调整需同时反映到 RGB/Fusion，并验证独立断开、重连和最终释放。

## Future Adapter / 后续 Adapter

Hardware-trigger synchronization and the official `FUSION_STREAM` remain a
future adapter behind a compatible Fusion interface. That adapter may own both
cameras because synchronized SDK semantics require it, but it must be exposed
as a distinct acquisition mode rather than silently reconnecting devices in
the reused-frame mode.

硬件触发同步和官方 `FUSION_STREAM` 留作未来 adapter。该 adapter 可以因同步
语义而独占双相机，但必须作为明确的另一种采集模式，不能在复用画面模式中静默
重连设备。
