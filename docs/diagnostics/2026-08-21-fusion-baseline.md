# Fusion Baseline Diagnostic / Fusion 基线诊断

**Date / 日期:** 2026-08-21  
**Machine / 机器:** Windows x64  
**Project / 项目:** `DVSenseRealtimeV1-dev`

> **Historical record / 历史记录:** This file captures the pre-reconnect
> diagnostic state. The current verified status is maintained in
> [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md), where the native
> dual-camera stream is `PASS`.
>
> 本文件记录拔插设备前的诊断状态。当前已验证状态统一维护在
> [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md)，原生双相机取流结果为
> `PASS`。

## Hardware / 硬件

- Event camera / 事件相机: DVSLume
- Event lens / 事件相机镜头: `3MP-HD CCTV LENS 6MM IR`
- RGB camera / RGB 相机: Hikrobot `MV-CU050-90UC`
- RGB lens / RGB 相机镜头: `HN-1228-CM-C2/3B 12MM 1:2.8 2/3`
- Synchronization hardware / 同步硬件: synchronization box, trigger cable, and suitable power supply are required

## Installed Paths / 已安装路径

- DVSense driver: `C:/Program Files (x86)/DvsenseDriver`
- MVS development package: `C:/Program Files (x86)/MVS`
- MVS native runtime: `C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64`
- Official reference source: `C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk`
- Project-local rebuild: `artifacts/build/official-fusion-local`

## Discovery Result / 发现结果

The standalone C++ discovery test was compiled against the installed DVSense headers and import libraries and run with the installed DVSense runtime DLLs.

独立 C++ 发现测试使用当前系统 DVSense 头文件、导入库和运行时 DLL 编译并运行。

Observed output / 观察到的输出:

```text
size mismatch; expected {}, got {}
Get serial number failed.
Skip USB camera with empty serial number
updateCameras count=0 elapsed_ms=22374
```

Windows Device Manager still reports both physical USB devices:

Windows 设备管理器仍能看到两台实体 USB 设备：

```text
DVSLume
USB\VID_04B5&PID_0001\00000000

MvisionUSB USB3 Vision Camera
USB\VID_2BDF&PID_0001&MI_00\...
```

**Interpretation / 解释:**  
The failure is below MATLAB and below the project bridge. The DVSense discovery layer sees the USB device but cannot read a valid serial number, so it drops the device before Fusion SDK pairing.  
失败发生在 MATLAB 和项目桥接层之下。DVSense 发现层能看到 USB 设备，但无法读取有效序列号，因此在 Fusion SDK 配对之前就丢弃了设备。

## Rebuild Result / 重建结果

A fresh CMake build was configured under the project directory and built against:

已在项目目录下创建全新的 CMake 构建目录，并使用以下当前依赖构建：

- DVSense CMake package: `C:/Program Files (x86)/DvsenseDriver/share/cmake/DvsenseDriver`
- MVS headers: `C:/Program Files (x86)/MVS/Development/Includes`
- MVS import library: `C:/Program Files (x86)/MVS/Development/Libraries/win64/MvCameraControl.lib`
- OpenCV/FFmpeg: current vcpkg installation
- Compiler: MSVC 19.51.36248.0

Generated files / 已生成文件:

```text
artifacts/build/official-fusion-local/bin/Release/FusionShowHik.exe
artifacts/build/official-fusion-local/bin/Release/DvsRgbFusionCamera.dll
artifacts/build/official-fusion-local/bin/Release/DvsRgbCalib.dll
```

The build exited with code 0. The compiler emitted upstream warnings about DLL-interface exports, macro redefinition, source character sets, and narrowing conversions; no compilation error was observed.  
构建退出码为 0。编译器输出了官方代码已有的 DLL 接口导出、宏重复定义、字符集和窄化转换警告；未观察到编译错误。

## Runtime Check / 运行库检查

The MVS native runtime is installed at
`C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64`, including
`MvCameraControl.dll`. The earlier missing-runtime conclusion was caused by
checking only the development-package directory.

MVS 原生运行库实际位于上述目录，其中包含 `MvCameraControl.dll`。
之前“缺少运行库”的结论是因为只检查了开发包目录。

The rebuilt official sample must be launched with this runtime directory
available on `PATH`. This pre-reconnect record left the DVSense discovery path
as an open question; later native C++ DVS-only and dual-camera probes confirmed
that physical reconnect restored ordinary `DVSLume` discovery and streaming.

重建后的官方示例需要在 `PATH` 中包含该 runtime 目录后启动。本历史记录当时将
DVSense 发现路径列为待确认问题；后续原生 C++ DVS 单机和双相机探针已经确认，
物理重新插拔后普通 `DVSLume` 发现和取流恢复。

## Historical Next Action / 历史下一步

The actions below describe the historical diagnostic sequence. They are not
the current milestone; use `../CONNECTION_BASELINE.md` for current evidence.

下面记录的是当时的诊断顺序，不是当前里程碑；当前证据请查看
`../CONNECTION_BASELINE.md`。

1. Add the complete MVS runtime directory to `PATH`.
2. Re-run the rebuilt official sample.
3. Compare ordinary and sync-path discovery output.
4. Do not mix old project DVSense DLLs with the installed SDK.

## Engineering Decision / 工程决策

At the time of this record, the project paused MATLAB Fusion bridge work until
the native baseline could load both vendor runtimes and reach discovery. That
condition was later satisfied by the standalone and same-process dual-camera
tests. The next implementation target is now the native fused display.

本记录建立时，项目在原生基线加载两套 vendor 运行库并进入发现之前暂停
MATLAB Fusion 桥接工作。该条件后来已由独立测试和同进程双相机测试满足。
当前下一目标是原生融合画面。
