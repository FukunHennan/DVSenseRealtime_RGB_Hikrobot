# V5 Hikrobot RGB 真机接入

## 已实现链路

```text
设备页「连接 RGB」
  -> uihtml event: connectRgb
  -> ui.internal.mapControlEvent
  -> app.run
  -> camera.HikrobotCameraSource
  -> hikrobot_mex
  -> Hikrobot MVS SDK
  -> MV_CC_EnumDevices / OpenDevice / StartGrabbing
  -> GetImageBuffer / RGB8 convert / 1280x720 letterbox preview
  -> WorkbenchViewer RGB FrameSurface
```

RGB 与 DVS 是两条独立链路，可以单独连接或同时连接。Fusion 仍保持禁用，
直到真实融合后端接入。

## 首次构建

在安装了 Hikrobot MVS 和 MATLAB C++ 编译器的 Windows 电脑上运行：

```matlab
run tools/dev/setupPath.m
buildHikrobotMex
```

默认 MVS 根目录：

```text
C:\Program Files (x86)\MVS
```

生成文件：

```text
runtime/bin/hikrobot_mex.mexw64
```

MATLAB R2024b 不识别 Visual Studio 2026，但可以并行安装 Visual Studio 2022
Build Tools。当前机器已经使用 VS 2022 Build Tools 成功执行 `mex -setup C++`
并生成 `hikrobot_mex.mexw64`，无需卸载 VS 2026。

MVS 原生运行时继续使用官方安装目录，不复制到项目 runtime：

```text
C:\Program Files (x86)\Common Files\MVS\Runtime\Win64_x64
```

## RGB 能力

- 真机枚举 USB3 / GigE Hikrobot 相机
- 按序列号连接；多设备时弹出真实设备选择框
- 连续采集模式（TriggerMode Off）
- 读取最新帧，主动丢弃旧预览帧以控制延迟
- 使用 MVS PixelConvert 转 RGB8
- 保持原始宽高比缩放到 1280x720 黑边预览
- MATLAB 第二个 FrameSurface 显示 RGB
- ExposureAuto Off + ExposureTime 实时写入
- RGB 断开/取流异常不关闭 GUI，也不影响 DVS

## 尚未实现

以下功能继续保持禁用，不伪造：

- RGB 视频录制
- RGB 去畸变文件执行
- DVS 去畸变文件执行
- RGB/DVS Fusion
- 手动对齐与标定保存
- 硬件触发同步

硬件触发同步将在 Fusion 阶段接入，当前 RGB 使用连续取流以便独立验证。

## 实机冒烟结果（2026-08-25）

测试对象：Hikrobot `MV-CU050-90UC`，序列号 `DA7653943`。

- MVS 初始化、USB3 枚举、创建句柄和打开设备成功；
- `ExposureTime` 读取为 5000 µs，同值写回及读回成功；
- 连续模式采集 5 秒，得到 299 个非空帧；
- 原始帧为 2600×2160，每帧 5,616,000 字节；
- 未检测到帧号间隙；
- 停止采集、关闭设备、销毁句柄和 SDK 释放全部返回成功。

随后使用 MATLAB R2024b、VS 2022 Build Tools 和新构建的 MEX，通过
`camera.HikrobotCameraSource` 完成真实设备枚举、打开、曝光控制、
720×1280×3 `uint8` 预览帧读取和关闭验证。相机刚开始采集时单次 5 ms 读取
可能返回空数组，应用循环会在下一显示周期继续读取。
