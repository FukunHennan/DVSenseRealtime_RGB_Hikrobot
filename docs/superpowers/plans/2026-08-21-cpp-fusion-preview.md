# C++ Fusion Preview Implementation Plan / C++ 融合预览实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.  
> **面向智能代理的要求：**必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，逐项执行本计划。步骤使用复选框（`- [ ]`）跟踪。

**Goal / 目标:**  
Show the first calibrated DVSLume + Hikrobot MV-CU050-90UC fused frame through the existing MATLAB-managed project while keeping device ownership and high-frequency fusion processing in native C++.  
在现有 MATLAB 管理的项目中显示第一幅经过标定的 DVSLume + 海康 MV-CU050-90UC 融合画面，同时保持设备所有权和高频融合处理在原生 C++ 中。

**Architecture / 架构:**  
MATLAB remains the lifecycle, configuration, control, and UI manager. A native C++ helper owns DVSense, MVS, trigger synchronization, RGB warping, event overlay, and a bounded latest-frame buffer. The existing single-DVS path remains available as a fallback until dual-camera hardware validation passes.  
MATLAB 继续负责生命周期、配置、控制和界面；原生 C++ helper 负责 DVSense、MVS、触发同步、RGB 变换、事件叠加以及有界的最新帧缓存。在双相机硬件验证通过前，保留现有单事件相机路径作为回退。

**Tech Stack / 技术栈:**  
MATLAB R2024b, MATLAB `loadlibrary/calllib`, C++17/MSVC, official `DvsRgbFusionCamera<HikCamera>`, `DvsRgbCalib`, Hikvision MVS, OpenCV calibration/warp, and the existing named-pipe helper protocol.  
MATLAB R2024b、MATLAB `loadlibrary/calllib`、C++17/MSVC、官方 `DvsRgbFusionCamera<HikCamera>`、`DvsRgbCalib`、海康 MVS、OpenCV 标定/变换，以及现有命名管道 helper 协议。

**Spec / 设计文档:**  
`docs/superpowers/specs/2026-08-21-cpp-fusion-preview-design.md`

> **Status update / 状态更新:** The native dual-camera acquisition baseline
> described in M0 has since passed. The current evidence is consolidated in
> `docs/CONNECTION_BASELINE.md`; this plan now continues from the native fused
> display milestone rather than the old empty-serial blocker.
>
> **状态更新：** M0 所需的原生双相机采集基线已经通过。当前证据统一收敛到
> `docs/CONNECTION_BASELINE.md`；本计划应从原生融合画面里程碑继续，而不是从
> 旧的空序列号阻塞继续。

## Milestones / 里程碑

### M0: Hardware and SDK baseline / 硬件与 SDK 基线

**Status / 状态: Complete / 已完成**

**Exit criteria / 完成标准:**

- A native C++ probe can enumerate DVSLume and return a non-empty serial number.  
  原生 C++ 探针能够枚举 DVSLume，并返回非空序列号。
- A native C++ probe can enumerate and open the Hikrobot camera.  
  原生 C++ 探针能够枚举并打开海康相机。
- One native C++ process can open and stream both cameras concurrently.  
  同一个原生 C++ 进程能够同时打开两台相机并持续取流。
- The tested runtime DLL set, MVS path, camera identities, and build date are recorded.  
  已记录验证过的运行库集合、MVS 路径、相机身份和验证日期。

**Historical evidence / 历史证据:**

- Windows recognizes `DVSLume` (`USB\VID_04B5&PID_0001`) and `MvisionUSB USB3 Vision Camera` (`USB\VID_2BDF&PID_0001`).  
  Windows 能识别 DVSLume 和海康 USB3 Vision 相机。
- The current standalone C++ discovery reproduces `size mismatch`, `Get serial number failed`, and `updateCameras count=0`.  
  当前独立 C++ 发现测试稳定复现 `size mismatch`、`Get serial number failed` 和 `updateCameras count=0`。
- The old project runtime contains DVSense DLLs from July 5, 2026, while the installed DVSense driver was modified July 20, 2026; these must not be mixed.  
  项目旧运行时含有 2026 年 7 月 5 日的 DVSense DLL，而系统驱动为 2026 年 7 月 20 日，不能混用。

**Final evidence / 最终证据:**

- Standalone DVS and Hikrobot native probes passed.
- One native C++ process streamed both cameras for five seconds with
  `result=PASS`.
- See `docs/CONNECTION_BASELINE.md` for the exact device identities and
  measured counts.

- DVS 和海康原生独立探针均已通过。
- 同一个原生 C++ 进程同时取流五秒，结果为 `result=PASS`。
- 具体设备身份和统计数据见 `docs/CONNECTION_BASELINE.md`。

### M1: Project-owned configuration and dependency manifest / 项目配置与依赖清单

**Exit criteria / 完成标准:**

- `main.m` contains no machine-specific SDK path literals.  
  `main.m` 不再包含机器相关 SDK 路径。
- A resolved configuration records SDK roots, runtime roots, camera serial preferences, lens metadata, trigger mode, calibration path, and output size.  
  解析后的配置记录 SDK 根目录、运行时根目录、相机序列号偏好、镜头信息、触发模式、标定路径和输出尺寸。
- The project clearly separates project-owned files from system-installed drivers.  
  项目明确区分项目自有文件和系统安装驱动。

**Dependency policy / 依赖策略:**

- Keep project-owned binaries under `runtime/bin/` and project-owned SDK headers/import libraries under `vendor/` only when redistribution and license terms allow it.  
  项目自有二进制放在 `runtime/bin/`；只有在允许再分发且符合许可时，才把 SDK 头文件和导入库放入 `vendor/`。
- Do not move or duplicate USB driver registration, MVS device services, or DVSense installer state blindly. Record their system paths in `config/local.json`.  
  不盲目移动或复制 USB 驱动注册、MVS 设备服务或 DVSense 安装状态；在 `config/local.json` 中记录系统路径。
- The tracked example config uses forward slashes and machine-local overrides remain ignored.  
  纳入版本管理的示例配置使用正斜杠，机器本地覆盖配置保持忽略。

### M2: Native C++ fusion session / 原生 C++ 融合会话

**Exit criteria / 完成标准:**

- C++ discovers, opens, starts, stops, and closes both cameras through the official Fusion SDK.  
  C++ 通过官方 Fusion SDK 完成双相机发现、打开、启动、停止和关闭。
- `FUSION_STREAM` produces a calibrated `1280 x 720` frame in DVS coordinates.  
  `FUSION_STREAM` 输出 DVS 坐标系下的 `1280 x 720` 标定融合画面。
- The helper keeps only the newest complete frame and bounded event data.  
  helper 只保留最新完整画面，并对事件数据设置有界容量。
- Vendor SDK failures remain inside the helper process and are returned as named errors.  
  vendor SDK 失败不会拖垮 MATLAB 进程，而是以明确错误返回。

### M3: MATLAB bridge and preview / MATLAB 桥接与预览

**Exit criteria / 完成标准:**

- MATLAB calls only the project bridge DLL and never loads MVS or DVSense vendor DLLs directly.  
  MATLAB 只加载项目桥接 DLL，不直接加载 MVS 或 DVSense vendor DLL。
- `FusionSession` exposes discovery, open, start, latest-frame read, status, stop, and close.  
  `FusionSession` 提供发现、打开、启动、读取最新帧、读取状态、停止和关闭接口。
- The existing viewer displays the fused frame and basic synchronization status.  
  现有 viewer 显示融合画面和基本同步状态。
- Legacy single-DVS mode still starts and closes cleanly.  
  原有单 DVS 模式仍能正常启动和关闭。

### M4: Hardware validation and documentation handoff / 硬件验证与文档交接

**Exit criteria / 完成标准:**

- Both cameras open with the synchronization box and trigger wiring connected.  
  连接同步盒和触发线后，两台相机都能打开。
- RGB frames and DVS events arrive; calibration loads; a visible fused frame is produced.  
  RGB 帧和 DVS 事件均到达，标定加载成功，并显示融合画面。
- Stop/restart releases the helper and both cameras.  
  停止/重启能够释放 helper 和两台相机。
- A new developer can follow the bilingual setup, configuration, build, run, and troubleshooting documents.  
  新成员可以按照双语的安装、配置、构建、运行和故障排查文档开始开发。

## Global Constraints / 全局约束

- MATLAB remains the application manager; C++ owns vendor SDKs and high-frequency callbacks.  
  MATLAB 作为应用管理层；C++ 负责 vendor SDK 和高频回调。
- MATLAB must not load MVS or DVSense vendor DLLs directly.  
  MATLAB 不得直接加载 MVS 或 DVSense vendor DLL。
- The first visible output is a calibrated fused frame in DVS `1280 x 720` coordinates.  
  第一阶段可见输出必须是 DVS `1280 x 720` 坐标系下的标定融合画面。
- ROI, recognition, GPU recognition, and final UI redesign are out of scope for the first preview slice.  
  第一阶段不做 ROI、识别、GPU 识别和最终 UI 重构。
- Event and RGB buffers are bounded and prefer the newest complete fused frame.  
  事件和 RGB 缓存必须有界，并优先保留最新完整融合帧。
- Installed hardware profile: DVSLume with `3MP-HD CCTV LENS 6MM IR`; Hikrobot `MV-CU050-90UC` with `HN-1228-CM-C2/3B 12MM 1:2.8 2/3`.  
  当前硬件配置：DVSLume 配 `3MP-HD CCTV LENS 6MM IR`；海康 `MV-CU050-90UC` 配 `HN-1228-CM-C2/3B 12MM 1:2.8 2/3`。
- Hardware validation requires the synchronization box, trigger wiring, and suitable power supply.  
  硬件验证需要同步盒、触发线和匹配的供电。
- Every future plan file must be bilingual in Chinese and English.  
  后续所有计划文件必须中英双语。

## Project Layout / 项目目录布局

```text
config/
  default.json                 # tracked defaults / 版本管理的默认配置
  local.example.json            # copyable machine template / 可复制的本机模板
  local.json                    # ignored machine overrides / 忽略的本机覆盖
  camera-profile.json           # cameras, lenses, trigger, calibration / 相机镜头触发标定
  README.md

vendor/                         # only redistributable SDK artifacts / 仅保存可再分发 SDK
  dvsense-fusion-sdk/
    include/
    lib/
    cmake/
  mvs-headers-libs/             # optional, license permitting / 可选，许可允许时使用

runtime/
  bin/                          # project-owned bridge/helper/runtime closure / 项目运行时
  manifest.json
  README.md

calibration/
  cameraParameters.mat
  fusion_result.json

artifacts/
  build/
  diagnostics/
  output/
```

System-installed SDK paths remain configurable because USB driver registration and vendor services may be required.  
由于 USB 驱动注册和 vendor 服务可能是必须的，系统安装 SDK 路径仍然保留为可配置项。

## File Map / 文件地图

### New files / 新建文件

- `config/default.json`: shared defaults / 公共默认配置
- `config/local.example.json`: machine template / 本机配置模板
- `config/camera-profile.json`: camera, lens, trigger, calibration metadata / 相机、镜头、触发、标定元数据
- `config/README.md`: config ownership and setup / 配置归属和设置说明
- `src/matlab/+app/loadConfiguration.m`: load, merge, expand, validate config / 配置加载、合并、路径展开和校验
- `src/matlab/+camera/FusionSession.m`: MATLAB wrapper / MATLAB 融合会话封装
- `src/matlab/+camera/FusionCameraSource.m`: source facade / 融合数据源门面
- `src/matlab/+camera/+internal/fusionBridgePrototype.m`: C ABI prototype / C ABI 原型
- `tests/matlab/testConfigurationLoading.m`
- `tests/matlab/testFusionSessionContract.m`
- `tests/matlab/testFusionFrameShape.m`
- `tools/diagnostics/runOfficialFusionHik.m`
- `docs/configuration.md`
- `docs/dual-camera-testing.md`

### Modified files / 修改文件

- `main.m`
- `src/native/src/dvsense_helper.cpp`
- `src/native/bridge/dvsense_bridge.h`
- `src/native/bridge/dvsense_bridge.cpp`
- `src/matlab/+camera/DVSenseSession.m`
- `src/matlab/+camera/CameraSourceFactory.m`
- `src/matlab/+app/run.m`
- `src/matlab/+ui/WorkbenchViewer.m`
- `tools/build/buildMex.m` or `tools/build/buildFusionHelper.m`
- `runtime/README.md`
- `runtime/manifest.json`
- `tests/matlab/testProjectStructure.m`
- `README.md`
- `docs/architecture/current.md`

### External reference files / 外部参考文件

- `C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk/samples/FusionShowHik/FusionShowHik.cpp`
- `C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk/samples/ExternalTriggerShow/ExternalTriggerShow.cpp`
- `C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk/build/Release/DvsRgbFusionCamera.lib`
- `C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk/build/Release/DvsRgbCalib.lib`
- `C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk/build/bin/Release/DvsRgbFusionCamera.dll`
- `C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk/build/bin/Release/DvsRgbCalib.dll`

## Task 0: Diagnose and rebuild the official baseline / 任务 0：诊断并重建官方基线

**Files / 文件:**

- Create: `tools/diagnostics/runOfficialFusionHik.m`
- Create: `artifacts/build/diagnostics/discovery_smoke.exe` as an ignored diagnostic artifact
- Modify: `README.md` only after the result is recorded

**Steps / 步骤:**

- [x] Reproduce standalone DVS discovery with the installed SDK.  
  [x] 使用系统安装 SDK 复现独立 DVS 发现。
- [x] Record the exact failure: `size mismatch`, `Get serial number failed`, empty serial, count zero.  
  [x] 记录完整失败信息。
- [x] Configure a fresh official build directory under `artifacts/build/official-fusion-local`.  
  [x] 在 `artifacts/build/official-fusion-local` 下配置全新的官方构建目录。
- [x] Rebuild `DvsRgbFusionCamera`, `DvsRgbCalib`, and `FusionShowHik` against the current installed DVSense, MVS, OpenCV, and FFmpeg paths.  
  [x] 使用当前系统 DVSense、MVS、OpenCV 和 FFmpeg 路径重新构建三个官方目标。
- [x] Record the separate MVS native runtime blocker: the rebuilt binary requires `MVCameraControl.dll`, which was not found in the installed MVS tree.  
  [x] 记录独立的 MVS 原生运行库阻塞：重建二进制需要 `MVCameraControl.dll`，但在当前 MVS 安装树中未找到。
- [ ] Add the official sample checker and deterministic missing-file checks.  
  [ ] 增加官方示例检查器和确定性的缺文件检查。
- [ ] Run the rebuilt sample with the camera pair and record whether discovery changes.  
  [ ] 运行重建示例，记录发现结果是否变化。
- [ ] If the rebuilt sample still fails, stop feature integration and document the blocker as driver/device-level.  
  [ ] 如果重建后仍失败，暂停功能接入，把阻塞点明确记录为驱动或设备层问题。

**Verification / 验证:**

```text
artifacts/build/diagnostics/discovery_smoke.exe
artifacts/build/official-fusion-local/bin/Release/FusionShowHik.exe
```

Expected success evidence is a non-empty DVS serial and a non-empty Hikvision serial.  
成功证据是非空 DVS 序列号和非空海康序列号。

## Task 1: Add configuration and dependency ownership / 任务 1：增加配置与依赖归属

**Files / 文件:** `config/*`, `src/matlab/+app/loadConfiguration.m`, `main.m`, `tests/matlab/testConfigurationLoading.m`

- [ ] Write tests for config merge, `${PROJECT_ROOT}` expansion, path validation, output size validation, and missing calibration errors.  
  [ ] 编写配置合并、项目根路径展开、路径校验、输出尺寸校验和缺失标定错误测试。
- [ ] Add tracked defaults and local example files.  
  [ ] 增加纳入版本管理的默认配置和本机模板。
- [ ] Add camera and lens metadata for DVSLume, MV-CU050-90UC, the 6 mm IR lens, and the 12 mm HN-1228 lens.  
  [ ] 写入两台相机及两支镜头元数据。
- [ ] Add `sdkRoot`, `mvsRoot`, `fusionSdkRoot`, `runtimeRoot`, and `calibrationFile` to the resolved configuration.  
  [ ] 在解析配置中加入这些路径字段。
- [ ] Keep `config/local.json` ignored and never commit private machine paths unless intentionally documented.  
  [ ] 保持 `config/local.json` 被忽略，除非明确需要，否则不提交私人机器路径。
- [ ] Replace hard-coded paths in `main.m` with `app.loadConfiguration(projectRoot)`.  
  [ ] 用配置加载替换 `main.m` 中的硬编码路径。
- [ ] Run configuration and project-structure tests.  
  [ ] 执行配置和项目结构测试。

## Task 2: Add the native C++ fusion session / 任务 2：增加原生 C++ 融合会话

**Files / 文件:** `src/native/src/dvsense_helper.cpp`, build scripts, `runtime/README.md`, `tests/native/fusion_protocol_test.cpp`

- [ ] Add a `FusionFrameState` with fixed-size ownership, width, height, timestamp, sequence, and validity.  
  [ ] 增加固定容量的融合帧状态。
- [ ] Add one mutex-protected latest-frame replacement path; do not create an unbounded queue.  
  [ ] 增加单互斥锁保护的最新帧替换路径，不创建无界队列。
- [ ] Wrap `DvsRgbFusionCamera<HikCamera>` and `DvsRgbCalib` inside the helper.  
  [ ] 在 helper 内封装官方融合相机和标定器。
- [ ] Keep callback ownership and trigger synchronization in C++.  
  [ ] 保持回调和触发同步由 C++ 管理。
- [ ] Add `fusion_discover`, `fusion_open`, `fusion_start`, `fusion_read_frame`, `fusion_read_status`, `fusion_stop`, and `fusion_close`.  
  [ ] 增加上述融合协议命令。
- [ ] Return named errors for no serial, calibration failure, invalid size, disconnected camera, and stale stream.  
  [ ] 对序列号为空、标定失败、尺寸非法、相机断开和流失效返回明确错误。
- [ ] Link only against the selected local/under-vendor artifacts and copy runtime DLLs only when ownership permits.  
  [ ] 只链接选定的本机或 vendor 依赖，并仅在归属允许时复制运行时 DLL。
- [ ] Run fake protocol tests without hardware.  
  [ ] 在无硬件情况下执行协议假实现测试。

## Task 3: Extend the bridge and MATLAB session / 任务 3：扩展桥接与 MATLAB 会话

**Files / 文件:** `src/native/bridge/*`, `src/matlab/+camera/FusionSession.m`, prototype, tests

- [ ] Add C ABI declarations while preserving all existing DVS exports.  
  [ ] 增加 C ABI 声明，同时保持旧 DVS 导出不变。
- [ ] Implement MATLAB lifecycle methods: `discover`, `open`, `start`, `readLatestFrame`, `readStatus`, `stop`, and `close`.  
  [ ] 实现 MATLAB 生命周期方法。
- [ ] Copy native bytes into MATLAB exactly once and return `[720 1280 3]` or the agreed grayscale shape.  
  [ ] 只做一次 native 字节到 MATLAB 数组的复制，并返回约定尺寸。
- [ ] Add contract tests with a fake bridge adapter, including partial-open cleanup.  
  [ ] 增加 fake bridge 契约测试，包括部分打开失败后的清理。

## Task 4: Connect the manager and viewer / 任务 4：接入管理器与 viewer

**Files / 文件:** `src/matlab/+camera/FusionCameraSource.m`, `CameraSourceFactory.m`, `app/run.m`, `WorkbenchViewer.m`, tests

- [ ] Select Fusion mode from configuration while preserving legacy live DVS mode.  
  [ ] 根据配置选择融合模式，同时保留旧单 DVS 模式。
- [ ] Read the newest fused frame and status on each UI cycle.  
  [ ] 每个 UI 周期读取最新融合帧和状态。
- [ ] Display the calibrated fused frame without moving ROI or recognition into this slice.  
  [ ] 显示标定融合画面，本阶段不接入 ROI 和识别。
- [ ] Show only connection state, `syncValid`, timestamp delta, and RGB FPS.  
  [ ] 只显示连接状态、`syncValid`、时间差和 RGB FPS。
- [ ] Run source, viewer, cleanup, and structure tests.  
  [ ] 执行数据源、viewer、清理和结构测试。

## Task 5: Validate hardware and finish documentation / 任务 5：硬件验证与文档收尾

**Files / 文件:** `README.md`, `runtime/README.md`, `docs/architecture/current.md`, `docs/configuration.md`, `docs/dual-camera-testing.md`, structure tests

- [ ] Document MVS, DVSense, sync box, trigger wiring, calibration, build, run, stop, and restart.  
  [ ] 文档化 MVS、DVSense、同步盒、触发线、标定、构建、运行、停止和重启。
- [ ] Document which files may be copied into `vendor/` and which dependencies must remain installed system-wide.  
  [ ] 说明哪些文件可以复制到 `vendor/`，哪些依赖必须系统安装。
- [ ] Run all non-hardware tests and record exact results.  
  [ ] 执行全部非硬件测试并记录准确结果。
- [ ] Run the project with both cameras and verify fused frame visibility.  
  [ ] 使用双相机运行项目并确认融合画面可见。
- [ ] Stop the application, verify no stale helper remains, and reopen both cameras from the official sample.  
  [ ] 停止程序，确认没有残留 helper，并用官方示例重新打开两台相机。
- [ ] Update the bilingual project handoff checklist.  
  [ ] 更新双语项目交接清单。

## Verification Commands / 验证命令

```powershell
# Configure and build the official reference locally
cmake -S C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk `
  -B C:/Users/chen1/Desktop/DVSenseRealtimeV1-dev/DVSenseRealtimeV1-dev/artifacts/build/official-fusion-local `
  -G "Visual Studio 18 2026" -A x64 -DBUILD_SAMPLES=ON `
  -DDvsenseDriver_DIR="C:/Program Files (x86)/DvsenseDriver/share/cmake/DvsenseDriver" `
  -DMVS_INCLUDE_DIR="C:/Program Files (x86)/MVS/Development/Includes" `
  -DMVS_LIB_SEARCH_PATHS="C:/Program Files (x86)/MVS/Development/Libraries/win64"

cmake --build C:/Users/chen1/Desktop/DVSenseRealtimeV1-dev/DVSenseRealtimeV1-dev/artifacts/build/official-fusion-local `
  --config Release --target FusionShowHik
```

```matlab
results = runtests("tests/matlab/testConfigurationLoading.m");
results = runtests("tests/matlab/testFusionSessionContract.m");
results = runtests("tests/matlab/testFusionFrameShape.m");
results = runtests("tests/matlab/testProjectStructure.m");
```

No milestone is marked complete from source inspection alone; each completion requires fresh command output or a documented hardware result.  
不能仅凭代码检查标记里程碑完成；每个完成项都必须有新鲜的命令输出或明确的硬件验证结果。
