# Configuration / 配置

## Files / 文件

- `default.json`: tracked application defaults.  
  纳入版本管理的应用默认配置。
- `camera-profile.json`: tracked camera, lens, trigger, and calibration metadata.  
  纳入版本管理的相机、镜头、触发和标定元数据。
- `local.example.json`: copy this file to `local.json` for machine-specific paths and serials.  
  将此文件复制为 `local.json`，填写本机路径和序列号。
- `local.json`: ignored local override file.  
  被 Git 忽略的本机覆盖配置。

`main.m` uses these files as the only configuration source. Merge order is
`default.json` -> `camera-profile.json` -> optional `local.json`.

`main.m` 只使用这些 JSON 文件提供配置，合并顺序为 `default.json` →
`camera-profile.json` → 可选的 `local.json`。

## Ownership / 归属

Project-owned bridge, helper, and approved runtime DLLs belong under `runtime/bin/`.  
项目自有 bridge、helper 和允许复制的运行时 DLL 放在 `runtime/bin/`。

Redistributable SDK headers, import libraries, and CMake package files may be placed under `vendor/` only after license review.  
只有完成许可核对后，才可以把可再分发的 SDK 头文件、导入库和 CMake 包文件放入 `vendor/`。

MVS and DVSense USB driver installation state stays system-installed. Their paths are configuration values, not files to move blindly.  
MVS 和 DVSense 的 USB 驱动安装状态保留在系统中；它们的路径属于配置值，不应盲目移动。

## Path Tokens / 路径变量

Use `${PROJECT_ROOT}` for paths that should move with the project.  
项目内随目录移动的路径使用 `${PROJECT_ROOT}`。

## Fusion Profile / 融合配置

The first fusion output is DVS-coordinate `1280 x 720`. Calibration is loaded from `fusion.calibrationFile`.  
第一阶段融合输出为 DVS 坐标系 `1280 x 720`，标定文件由 `fusion.calibrationFile` 指定。

The current profile records:

当前配置记录：

- DVSLume with `3MP-HD CCTV LENS 6MM IR`
- Hikrobot `MV-CU050-90UC` with `HN-1228-CM-C2/3B 12MM 1:2.8 2/3`
- Hardware synchronization box and trigger wiring
