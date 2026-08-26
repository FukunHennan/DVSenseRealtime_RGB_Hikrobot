# Fusion Baseline Diagnostic / Fusion 基线诊断

**Date / 日期:** 2026-08-21  
**Machine / 机器:** Windows x64  
**Project / 项目:** `DVSenseRealtimeV1-dev`

> **Historical record / 历史记录:** This file captures the pre-reconnect diagnostic state. The current verified status is maintained in [`../CONNECTION_BASELINE.md`](../CONNECTION_BASELINE.md), where the native dual-camera stream is `PASS`.

## Hardware / 硬件

- Event camera / 事件相机: DVSLume
- Event lens / 事件相机镜头: `3MP-HD CCTV LENS 6MM IR`
- RGB camera / RGB 相机: Hikrobot `MV-CU050-90UC`
- RGB lens / RGB 相机镜头: `HN-1228-CM-C2/3B 12MM 1:2.8 2/3`
- Synchronization hardware / 同步硬件: synchronization box, trigger cable, and suitable power supply are required

## Installed Paths / 已安装路径

Public documentation uses generic locations rather than user-specific absolute paths:

- DVSense driver: `<DVSENSE_SDK_ROOT>`
- MVS development package: `<MVS_SDK_ROOT>`
- MVS native runtime: `<MVS_RUNTIME_ROOT>`
- Official reference source: `<LOCAL_REFERENCE_SOURCE>`
- Project-local rebuild: `artifacts/build/official-fusion-local`

## Discovery Result / 发现结果

The standalone C++ discovery test was compiled against the installed DVSense headers and import libraries and run with the installed DVSense runtime DLLs.

Observed output / 观察到的输出:

```text
size mismatch; expected {}, got {}
Get serial number failed.
Skip USB camera with empty serial number
updateCameras count=0 elapsed_ms=22374
```

Windows Device Manager still reported both physical USB devices, but unique device identifiers are intentionally omitted from the public repository.

**Interpretation / 解释:** The failure is below MATLAB and below the project bridge. The DVSense discovery layer sees the USB device but cannot read a valid serial number, so it drops the device before Fusion SDK pairing.

## Rebuild Result / 重建结果

A fresh CMake build was configured under the project directory using the installed DVSense package, MVS headers/import library, current OpenCV/FFmpeg dependencies and MSVC x64.

Generated files / 已生成文件:

```text
artifacts/build/official-fusion-local/bin/Release/FusionShowHik.exe
artifacts/build/official-fusion-local/bin/Release/DvsRgbFusionCamera.dll
artifacts/build/official-fusion-local/bin/Release/DvsRgbCalib.dll
```

The build exited with code 0. The compiler emitted upstream warnings about DLL-interface exports, macro redefinition, source character sets, and narrowing conversions; no compilation error was observed.

## Runtime Check / 运行库检查

The MVS native runtime was confirmed to contain `MvCameraControl.dll`. The earlier missing-runtime conclusion was caused by checking only the development-package directory.

The rebuilt official sample must be launched with the complete MVS runtime available to the process. Later native C++ DVS-only and dual-camera probes confirmed that physical reconnect restored ordinary `DVSLume` discovery and streaming.

## Historical Next Action / 历史下一步

1. Make the complete MVS runtime available to the process.
2. Re-run the rebuilt official sample.
3. Compare ordinary and sync-path discovery output.
4. Do not mix old project DVSense DLLs with the installed SDK.

## Engineering Decision / 工程决策

At the time of this record, the project paused MATLAB Fusion bridge work until the native baseline could load both vendor runtimes and reach discovery. That condition was later satisfied by the standalone and same-process dual-camera tests. The next implementation target is now the native fused display.
