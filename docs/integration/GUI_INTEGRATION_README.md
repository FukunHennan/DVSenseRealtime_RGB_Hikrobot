# DVSense 方案 A GUI 整合说明

本版本把六页中文 GUI 原型接入现有 MATLAB 工程，并保留现有 DVSense C++/helper/MEX 与 FrameSurface 视频链路。

## 已完成

- 单窗口六页 GUI：实时 / 设备 / 融合 / 分析 / 录制 / 设置。
- `src/matlab/+ui/assets/workbench.html` 作为新的统一 HTML 界面。
- `WorkbenchViewer` 改为单窗口 `uihtml + FrameSurface` 结构。
- 实时页 DVS 区域由 MATLAB `FrameSurface` 覆盖显示真实事件画面，不把视频转 Base64/Canvas。
- 页面切换时自动隐藏/显示 FrameSurface；三画面和双画面时自动调整 DVS 显示区域。
- HTML -> MATLAB 继续使用 `uihtml.Data` 协议，保留 version=1。
- 程序改为 GUI-first：`main.m` 启动后先显示 GUI，不再强制立即连接相机。
- 点击 DVS 连接/实时预览后才执行真实 DVSLume 连接。
- 相机未接入或连接失败时 GUI 保持运行。
- ROI、开始/停止、DVS 原始事件录制命令已接现有 MATLAB 命令链。

## 当前阶段限制

- 当前原工程只有 DVSLume/DVS 真机后端，因此 RGB/Hikrobot 与 Fusion 视频仍是 GUI 占位，不伪造后端。
- 设备页“扫描 DVS”目前主要用于界面流程；真实枚举发生在点击连接时，沿用原 `connectWithDecision()`。
- 融合页的 RGB 曝光、DVS 阈值、三类标定文件、拖动对齐和保存目前为前端交互原型；下一阶段应增加对应 MATLAB manager/command。
- 分析页保留现有 FrameSurface 的中心线/轮廓算法链路，但新分析页图表数据尚未全部绑定到实时 MATLAB 状态。

## 运行

在 MATLAB 中进入项目根目录，执行：

```matlab
main
```

GUI 会先出现。没有相机也不会因为启动阶段连接失败而直接退出；需要真机时进入“设备”页扫描，然后连接 DVS。

## 下一阶段推荐

1. 增加 `DeviceManager`，把设备扫描结果直接回传到设备页。
2. 接入 Hikrobot `RGBCameraSource`。
3. 增加 `CalibrationManager`，管理 RGB 内参、DVS 内参、Fusion 相对标定。
4. 增加 `FusionManager`，让拖动对齐的 `dx/dy/scale/rotation` 实时作用于融合。
5. 将录制中心升级为 DVS/RGB/Fusion/CSV 多路 Recorder。
