# DVSense 多模态视觉工作站

正式开发工程。根目录只保留唯一入口、版本/说明文件和一级功能目录。

## 启动

在 MATLAB 中进入项目根目录后运行：

```matlab
main
```

`main.m` 直接加载 `config/default.json` 和 `config/camera-profile.json`，
如果存在 `config/local.json`，再用其中的本机路径和相机序列号覆盖默认值。
不再在入口文件中维护第二套硬编码配置。

GUI-first 启动：DVS 和 RGB 都可以在程序启动后独立连接；任何相机缺失都不会伪造设备或关闭 GUI。

## 当前真实能力

- DVSense / DVSLume：真实枚举、连接、实时预览、ROI、原始事件录制、现有分析链路。
- Hikrobot RGB：真实 MVS 枚举、连接、实时取流、1280×720 低延迟预览、实时曝光控制、断开与异常恢复。
- DVS 与 RGB：两条独立真实链路，可只连接任意一台，也可同时连接。
- RGB/DVS Fusion：真实后端尚未接入，去畸变、融合、手动对齐和融合标定保存继续禁用。
- RGB 视频录制 / Fusion 视频录制 / 分析 CSV：尚未接入，继续禁用。

原则：**有真实后端才启用；没有实现的能力保持不可点击。**

## 2026-08-25 RGB 实机基线

独立原生 MVS 冒烟测试已在 `MV-CU050-90UC`（序列号
`DA7653943`）上通过：曝光 5000 µs 读取/同值写回/读回成功，连续 5 秒取得
299 个非空 2600×2160 帧，未检测到帧号间隙，停止、关闭和 SDK 释放均成功。

本机已并行安装 Visual Studio 2022 Build Tools，并由 MATLAB R2024b 成功选择
为 C++ MEX 编译器。`hikrobot_mex.mexw64` 已生成；项目的 MATLAB
`HikrobotCameraSource` 已完成真实枚举、打开、曝光读写、1280×720 RGB 帧读取
和关闭验证。详见
`docs/diagnostics/2026-08-25-hikrobot-rgb-smoke.md`。

## Hikrobot 首次构建

项目包含 `hikrobot_mex.cpp` 源码，但 `.mexw64` 必须在安装 MVS SDK 的 Windows 电脑上本机编译一次：

```matlab
run tools/dev/setupPath.m
buildHikrobotMex
```

默认使用：

```text
MVS SDK: C:\Program Files (x86)\MVS
MVS Runtime: C:\Program Files (x86)\Common Files\MVS\Runtime\Win64_x64
```

成功后生成：

```text
runtime/bin/hikrobot_mex.mexw64
```

随后运行 `main`，在「设备」页点击「连接 RGB」。

## 目录

- `main.m`：唯一程序入口。
- `config/`：配置文件。
- `src/`：MATLAB / C++ 源码。
- `runtime/`：项目本地运行时和本机生成的 MEX。
- `tests/`：自动与手动测试。
- `tools/`：构建、诊断、启动工具。
- `docs/`：架构、SDK 与整合记录。

RGB 接入说明见 `docs/integration/V5_RGB_HIKROBOT.md`。


## V5 RGB / Hikrobot

- 已实现真实 Hikrobot MVS 枚举、连接、连续取流、1280×720 预览和曝光控制。
- RGB 与 DVS 可独立连接。
- 首次使用前在 Windows MATLAB 中运行 `buildHikrobotMex`。
- 详细说明：`docs/integration/V5_RGB_HIKROBOT.md`。
- Fusion、RGB 录制、标定执行仍未接入，对应控件保持禁用。
