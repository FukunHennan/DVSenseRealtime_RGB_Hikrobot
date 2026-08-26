# C++ Build Environment Setup / C++ 编译环境安装手册

**Project / 项目:** `DVSenseRealtimeV1-dev`  
**Platform / 平台:** Windows x64  
**Purpose / 目的:** Build and run the native C++ camera connection tests and the
future C++ fusion program.  
用于编译、运行原生 C++ 相机连接测试，以及后续正式 C++ 融合程序。

## 1. Verified Local Environment / 已验证的本机环境

The following components were found on the development machine on
**August 21, 2026**:

截至 **2026 年 8 月 21 日**，开发机已确认存在：

| Component / 组件 | Verified location / 已确认位置 |
|---|---|
| MSVC / Visual Studio | `C:/Program Files/Microsoft Visual Studio/18/Community` |
| CMake | `C:/cmake-4.3.3-windows-x86_64` |
| DVSense headers and CMake package | `C:/Program Files (x86)/DvsenseDriver` |
| Hikrobot MVS development package | `C:/Program Files (x86)/MVS` |
| Hikrobot MVS runtime | `C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64` |
| OpenCV and FFmpeg | `C:/vcpkg-master/vcpkg-master/installed/x64-windows` |

The project does not store a compiler inside `runtime/bin`. The compiler is a
developer-machine dependency; the vendor runtime is a separate runtime
dependency.

项目不会把编译器放进 `runtime/bin`。编译器属于开发机依赖，厂商运行库属于
程序运行依赖，二者必须分开管理。

## 2. Install the Compiler / 安装编译器

Install Visual Studio Community or Visual Studio Build Tools for the same
machine architecture as the program:

安装 Visual Studio Community 或 Visual Studio Build Tools，并选择与程序一致的
x64 开发环境：

- Workload / 工作负载: **Desktop development with C++ / 使用 C++ 的桌面开发**
- MSVC C++ build tools / MSVC C++ 生成工具
- Windows 10 or Windows 11 SDK / Windows SDK
- CMake tools for Windows / CMake 工具

After installation, verify that a developer command shell contains `cl.exe`,
`cmake.exe`, and the Windows SDK:

安装后，在 Developer PowerShell 或 Developer Command Prompt 中确认存在
`cl.exe`、`cmake.exe` 和 Windows SDK：

```powershell
Get-Command cl
Get-Command cmake
cmake --version
```

The project was configured locally with the Visual Studio generator
`Visual Studio 18 2026`, x64, and Release configuration. On another machine,
use the generator reported by `cmake --help`; do not hard-code a generator
version that is not installed.

本机使用 `Visual Studio 18 2026`、x64 和 Release 配置完成过构建。换机器时，
应以 `cmake --help` 显示的已安装生成器为准，不要硬编码不存在的生成器版本。

## 3. Install Vendor SDKs / 安装厂商 SDK

### DVSense / DVSense

Install the DVSense driver and development package. The C++ build needs:

编译 C++ 需要 DVSense 驱动和开发包中的：

- `include/`
- `lib/DvsenseDriver.lib`
- `share/cmake/DvsenseDriver/`
- matching runtime DLLs such as `DvsenseDriver.dll`, `DvsenseHal.dll`,
  and `DvsenseBase.dll`

The USB driver installation itself remains system-installed. Do not copy
arbitrary DLLs between SDK versions.

USB 驱动本身保留为系统安装状态。不要在不同 SDK 版本之间随意复制 DLL。

### Hikrobot MVS / 海康 MVS

Install the MVS development package and runtime. The C++ build needs:

安装 MVS 开发包和运行库。C++ 编译需要：

- headers: `MVS/Development/Includes`
- import library:
  `MVS/Development/Libraries/win64/MvCameraControl.lib`
- runtime:
  `Common Files/MVS/Runtime/Win64_x64/MvCameraControl.dll`

The `MV-CU050-90UC` USB3 Vision camera should be visible in Device Manager
before running the native test.

运行原生测试前，应先在设备管理器中看到 `MV-CU050-90UC` 对应的 USB3 Vision
设备。

## 4. Configure and Build the Native Smoke Test / 配置和编译原生测试

The test CMake entry point is `tests/native/CMakeLists.txt`.

测试 CMake 入口为 `tests/native/CMakeLists.txt`。

Configure from the project root:

在项目根目录执行配置：

```powershell
cmake -S tests/native `
  -B artifacts/build/native-fusion-smoke `
  -G "Visual Studio 18 2026" `
  -A x64 `
  -DDVSENSE_FUSION_SDK_ROOT="C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk" `
  -DDVSENSE_FUSION_BUILD_ROOT="${PWD}/artifacts/build/official-fusion-local"
```

Build Release:

编译 Release：

```powershell
cmake --build artifacts/build/native-fusion-smoke `
  --config Release `
  --target fusion_connection_smoke `
  -- /m
```

The generated executable is:

生成的可执行文件为：

`artifacts/build/native-fusion-smoke/bin/Release/fusion_connection_smoke.exe`

## 5. Runtime DLL Order / 运行时 DLL 顺序

Run the executable with the official Fusion DLL, DVSense runtime, MVS runtime,
and vcpkg runtime visible to the same process:

运行时必须让同一进程能够找到官方 Fusion DLL、DVSense 运行库、MVS 运行库和
vcpkg 运行库：

```powershell
$env:Path = `
  "${PWD}/artifacts/build/native-fusion-smoke/bin/Release;" +
  "${PWD}/artifacts/build/official-fusion-local/bin/Release;" +
  "C:/Program Files (x86)/DvsenseDriver/bin;" +
  "C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64;" +
  "C:/vcpkg-master/vcpkg-master/installed/x64-windows/bin;" +
  $env:Path

.\artifacts/build/native-fusion-smoke/bin/Release/fusion_connection_smoke.exe `
  10 1000 1 5
```

The project-owned `runtime/bin` is intentionally isolated for the existing
MATLAB helper. It is not automatically interchangeable with the newly
installed DVSense package. Record the exact DLL source used for every hardware
test.

项目自己的 `runtime/bin` 专供现有 MATLAB helper 隔离使用，不能自动认为它与
新安装的 DVSense 开发包兼容。每次硬件测试都要记录实际加载的 DLL 来源。

## 6. GPU Preparation / GPU 准备

GPU acceleration is a later C++ processing layer, not a substitute for camera
connection. The SDK acquisition path remains vendor-owned CPU code:

GPU 加速属于后续 C++ 处理层，不能替代相机连接。SDK 采集路径仍由厂商 CPU
代码负责：

1. Validate DVS event callbacks and RGB frame callbacks on CPU.
2. Use pinned host buffers and bounded queues between SDK callbacks and CUDA.
3. Move event rasterization, time-surface construction, RGB resize/warp, and
   overlay blending to CUDA.
4. Keep a CPU reference backend and an explicit GPU fallback.
5. Measure transfer time, kernel time, queue delay, dropped frames, and end-to-end
   latency before changing defaults.

先在 CPU 上验证 DVS 事件回调和 RGB 帧回调；再使用页锁定内存和有界队列连接
SDK 与 CUDA；之后迁移事件栅格化、时间表面、RGB 缩放/变换和叠加混合。必须
保留 CPU 参考后端，并对数据传输、kernel、队列等待、丢帧和端到端延迟分别测量。

CUDA Toolkit, NVIDIA driver, and Visual Studio integration must be selected
as a compatible set on the target machine. The repository should record the
tested CUDA toolkit, driver, GPU model, and compiler versions in a benchmark
report rather than assuming that any installed CUDA version is interchangeable.

## 7. Troubleshooting / 故障排查

### `cl` or CMake is missing / 找不到 `cl` 或 CMake

Open the Visual Studio Developer PowerShell, or install the C++ workload and
Windows SDK again. Do not add random MSVC directories to the normal user PATH.

打开 Visual Studio Developer PowerShell，或重新安装 C++ 工作负载和 Windows
SDK。不要把随机的 MSVC 目录永久加入普通用户 PATH。

### DLL load failure / DLL 加载失败

Check the process-local PATH and confirm that `MvCameraControl.dll` comes from
the MVS runtime directory, while DVSense DLLs come from one consistent SDK
version. Do not mix the project July runtime with the system-installed runtime
without an explicit ABI test.

检查进程级 PATH，并确认 `MvCameraControl.dll` 来自 MVS runtime 目录，同时
DVSense DLL 来自同一套 SDK 版本。未经 ABI 验证，不要混用项目旧运行库和系统
新运行库。

### DVS `size mismatch` or empty serial / DVS 出现 `size mismatch` 或空序列号

This was a real transient discovery incident on August 21, 2026. The
unchanged native probe passed after the DVS camera was physically unplugged
and reconnected. The consolidated current result is maintained in
`../CONNECTION_BASELINE.md`.

这是 2026 年 8 月 21 日发生过的真实临时发现故障。DVS 相机物理拔出并重新
连接后，未修改的原生探针恢复通过。当前汇总结果维护在
`../CONNECTION_BASELINE.md`。

This is a discovery-layer failure before `openCamera`, event callbacks, or RGB
frame acquisition. Record:

这是进入 `openCamera`、事件回调和 RGB 取帧之前的发现层失败。应记录：

- exact DVSense DLL hashes and paths;
- Device Manager instance ID;
- product and serial returned by the SDK;
- whether the official Python program can reproduce discovery at that moment;
- whether any other DVSense process owns the device.

After the physical reconnect, discovery returned the non-empty description
`DVSLume / ffffffffffffffab` and event streaming passed. If the same symptom
reappears, follow the evidence-first recovery sequence in
`../CONNECTION_BASELINE.md` and retain the failed output.

物理重新插拔后，发现阶段已返回非空描述
`DVSLume / ffffffffffffffab`，事件取流验证通过。如果再次出现相同症状，应按
`../CONNECTION_BASELINE.md` 中的证据优先顺序恢复，并保留失败输出。
