# Build and Dependencies / 构建与依赖

**Platform / 平台:** Windows x64  
**Purpose / 用途:** New-developer setup and reproducible native C++ work /
新成员环境准备和原生 C++ 可复现开发

## Ownership Rule / 归属规则

Project-owned files should stay under the project directory whenever they can
be moved safely. System-installed drivers and vendor registration remain
system dependencies and are recorded by path in configuration.

可安全移动的项目文件统一放在项目目录内。系统安装的驱动和厂商注册状态继续
作为系统依赖，并在配置文件中记录路径。

| Dependency / 依赖 | Role / 作用 | Location / 位置 |
|---|---|---|
| DVSense driver and SDK / DVSense 驱动与 SDK | Event camera access / 事件相机访问 | `C:/Program Files (x86)/DvsenseDriver` |
| Hikrobot MVS development package / 海康 MVS 开发包 | Headers and import library / 头文件与导入库 | `C:/Program Files (x86)/MVS` |
| Hikrobot MVS runtime / 海康 MVS 运行库 | USB3 Vision runtime / USB3 Vision 运行环境 | `C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64` |
| Project-local MVS runtime / 项目内 MVS 副本 | Reproducible native test run / 可复现原生测试 | `artifacts/runtime/mvs-win64` |
| Official Fusion SDK / 官方 Fusion SDK | Future native fusion layer / 后续原生融合层 | `C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk` |

Do not mix DVSense DLLs from different SDK installations without recording
their source and ABI compatibility. Do not copy USB driver registration into
the repository.

不要在没有记录来源和 ABI 兼容性的情况下混用不同 SDK 安装中的 DVSense DLL。
不要把 USB 驱动注册状态复制进项目仓库。

## Configuration / 配置

Machine-dependent values belong in `config/local.json`, based on
`config/local.example.json`. The tracked defaults remain in
`config/default.json`; camera and lens metadata remain in
`config/camera-profile.json`.

机器相关值写入 `config/local.json`，模板来自 `config/local.example.json`。
版本管理的默认值在 `config/default.json`，相机和镜头元数据在
`config/camera-profile.json`。

Important path fields / 重要路径字段:

```text
paths.sdkRoot
paths.mvsRoot
paths.mvsRuntimeRoot
paths.fusionSdkRoot
paths.runtimeRoot
fusion.calibrationFile
camera.event.serial
camera.rgb.serial
```

Use `${PROJECT_ROOT}` for paths that should move with the project.

项目内可移动路径使用 `${PROJECT_ROOT}`。

## Compiler / 编译器

The verified native compiler is MSVC from Visual Studio Community:

本机已验证的编译器为 Visual Studio Community 提供的 MSVC：

```text
C:/Program Files/Microsoft Visual Studio/18/Community
```

The verified MATLAB MEX compiler is Visual Studio 2022 Build Tools:

```text
C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools
```

Visual Studio 2026 builds the standalone native smoke test. MATLAB R2024b
uses Visual Studio 2022 Build Tools for `hikrobot_mex.mexw64`; both versions
are installed side by side.

Visual Studio 2026 用于构建独立原生冒烟测试；MATLAB R2024b 使用并行安装的
Visual Studio 2022 Build Tools 构建 `hikrobot_mex.mexw64`。

Install the **Desktop development with C++** workload, MSVC build tools,
Windows SDK, and CMake tools for Windows. The compiler is a developer-machine
dependency and is not copied into `runtime/`.

安装“使用 C++ 的桌面开发”工作负载、MSVC 生成工具、Windows SDK 和 Windows
CMake 工具。编译器属于开发机依赖，不复制到 `runtime/`。

## Native Build / 原生构建

Use a Visual Studio Developer PowerShell and build the native smoke targets
from the project directory:

使用 Visual Studio Developer PowerShell，在项目目录中构建原生测试目标：

```powershell
cmake -S tests/native `
  -B artifacts/build/native-dual-camera `
  -G "Visual Studio 18 2026" `
  -A x64 `
  -DDVSENSE_FUSION_SDK_ROOT="C:/Users/chen1/Desktop/DVS/dvsense_fusion_combo_sdk"

cmake --build artifacts/build/native-dual-camera `
  --config Release `
  --target dual_camera_connection_smoke `
  -- /m
```

Run with the project-local MVS runtime and installed DVSense runtime visible
to the same process:

运行时让同一进程看到项目内 MVS 运行库和系统 DVSense 运行库：

```powershell
$env:Path = `
  "${PWD}/artifacts/runtime/mvs-win64;" +
  "C:/Program Files (x86)/DvsenseDriver/bin;" +
  $env:Path

.\artifacts/build/native-dual-camera/bin/Release/dual_camera_connection_smoke.exe
```

The exact executable layout may differ between CMake generators; the
connection baseline records the already verified executable and result.

不同 CMake 生成器产生的可执行文件路径可能不同；已验证的可执行文件和结果
统一记录在连接基线中。

## Runtime and GPU Boundary / 运行库与 GPU 边界

Vendor SDK acquisition remains native C++ and CPU-owned. GPU work begins only
after the fused frame is visible and stable. The first GPU tasks are event
rasterization, timestamp surfaces, RGB warp, and overlay benchmarking, with a
CPU reference path and explicit fallback.

厂商 SDK 采集仍由原生 C++ 和 CPU 路径负责。融合画面稳定显示后才进入 GPU
工作；首批 GPU 任务包括事件栅格化、时间表面、RGB 变换和叠加测速，同时保留
CPU 参考路径和明确回退。

MATLAB remains the manager and UI layer. It must not load MVS or DVSense vendor
DLLs directly.

MATLAB 继续作为管理层和 UI 层，不得直接加载 MVS 或 DVSense vendor DLL。
