# DVSense 多模态视觉工作站

正式开发工程。根目录只保留唯一入口、版本/说明文件和一级功能目录。

## 启动

在 MATLAB 中进入项目根目录后运行：

```matlab
main
```

`main.m` 直接加载 `config/default.json` 和 `config/camera-profile.json`；如果存在 `config/local.json`，再用其中的本机路径和相机序列号覆盖默认值。本机私有配置不会提交到仓库。

GUI-first 启动：DVS 和 RGB 都可以在程序启动后独立连接；任何相机缺失都不会伪造设备或关闭 GUI。

## 当前真实能力

- DVSense / DVSLume：真实枚举、连接、实时预览、ROI、原始事件录制、现有分析链路。
- Hikrobot RGB：真实 MVS 枚举、连接、实时取流、1280×720 低延迟预览、实时曝光控制、掉线识别与异常恢复。
- DVS 与 RGB：两条独立真实链路，可只连接任意一台，也可同时连接。
- RGB/DVS Fusion：已接入基础叠加。Fusion 不重新枚举、打开或读取相机，只复用 `latestDvsFrame` 和 `latestRgbFrame`；RGB 为底图，DVS ON 事件绿色、OFF 事件洋红色，输出 1280×720。
- Fusion 几何标定、去畸变、手动对齐仍属于后续增强；未实现控件继续禁用。
- RGB 视频录制 / Fusion 视频录制 / 分析 CSV：尚未接入，继续禁用。

原则：**相机资源只归相机模块管理；Fusion 只处理已经取得的帧，不拥有任何硬件句柄。**

## RGB 实机基线

Hikrobot `MV-CU050-90UC` 已完成真实 MVS 冒烟测试：曝光读取/写回、连续采集、停止、关闭和 SDK 释放均通过。详细测试记录位于 `docs/diagnostics/`。

MATLAB R2024b 已验证可通过 Visual Studio 2022 Build Tools 编译 `hikrobot_mex.mexw64`，并由 `camera.HikrobotCameraSource` 完成真实枚举、打开、曝光读写、1280×720 RGB 帧读取和关闭。

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

## Fusion 数据流

```text
DVS SDK -> DVS CameraSource -> latestDvsFrame --\
                                               > FusionRenderer -> Fusion FrameSurface
RGB MVS -> HikrobotCameraSource -> latestRgbFrame /
```

Fusion 不调用 `discover`、`open`、`readDisplayFrame`、`hikrobot_mex` 或任何 `MV_CC_*` 接口。DVS/RGB 预览各自只读取一次，同一张最新显示帧同时供独立预览和 Fusion 使用。

## 公开仓库说明

- 当前采用单人、单分支开发方式，只使用 `main`。
- `config/local.json`、MEX、构建产物和本机输出保持未跟踪状态。
- 密码、Token、私钥等凭据不要提交到仓库。

## 目录

- `main.m`：唯一程序入口。
- `config/`：配置文件。
- `src/`：MATLAB / C++ 源码。
- `runtime/`：运行时布局说明和本机生成文件位置。
- `tests/`：自动与手动测试。
- `tools/`：构建、诊断、启动工具。
- `docs/`：架构、SDK 与整合记录。

RGB 接入说明见 `docs/integration/V5_RGB_HIKROBOT.md`。
