# Documentation / 文档入口

This directory is organized by purpose rather than by every individual test
run. The four documents below are the normal handoff entry points.

本目录按用途整理，不再为每一次测试单独建立入口。下面四份文档是新成员接手项目时的主要入口。

## Core Documents / 核心文档

| Document / 文档 | Purpose / 用途 |
|---|---|
| [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) | Bilingual milestones and development route / 双语里程碑与开发路线 |
| [CONNECTION_BASELINE.md](CONNECTION_BASELINE.md) | Verified camera connection, streaming results, and real failure records / 已验证的相机连接、取流结果和真实故障记录 |
| [BUILD_AND_DEPENDENCIES.md](BUILD_AND_DEPENDENCIES.md) | Compiler, SDK, runtime, configuration, and reproducible build notes / 编译器、SDK、运行库、配置和可复现构建说明 |
| [architecture/current.md](architecture/current.md) | Source-code architecture as implemented / 当前源码架构 |

## Reference Categories / 参考分类

- `sdk/`: vendor SDK usage manuals / 厂商 SDK 使用手册
- `setup/`: detailed environment installation notes / 详细环境安装说明
- `diagnostics/`: original dated evidence and raw diagnostic records /
  原始日期证据和详细诊断记录
- `architecture/`: code ownership and module boundaries / 代码归属和模块边界
- `adr/`: architecture decisions / 架构决策
- `history/`: superseded plans and specifications / 已被替代的历史计划和规格
- `archive/`: retained legacy code and docs that are no longer active /
  保留的旧代码与已不再作为主线的文档
- `superpowers/`: implementation plans and design specifications /
  实施计划和设计规格

The dated diagnostic files remain available as evidence. The consolidated
connection status is maintained in `CONNECTION_BASELINE.md`.

日期诊断文件继续保留作为证据；当前统一连接状态只在
`CONNECTION_BASELINE.md` 中维护。

## Current Status / 当前状态

As of August 21, 2026, one native C++ process has opened and streamed both
independent cameras.

截至 2026 年 8 月 21 日，同一个原生 C++ 进程已经完成两台独立相机的打开和取流：

- DVSense `DVSLume`: event stream received continuously /
  持续收到事件流
- Hikrobot `MV-CU050-90UC`: RGB frames received continuously /
  持续收到 RGB 图像帧
- Simultaneous native acquisition: `result=PASS` /
  同进程并行取流：`result=PASS`

The next product slice is the native C++ fused display. ROI, recognition, GPU
processing, and final UI work remain later milestones.

下一阶段是原生 C++ 融合画面。ROI、识别、GPU 处理和最终 UI 放在后续里程碑。

The old event-only MATLAB workbench has been archived under
`archive/versions/2026-08-22_fusion-preview/legacy-event-workbench/`.

旧的仅事件相机 MATLAB 工作台已归档到
`archive/versions/2026-08-22_fusion-preview/legacy-event-workbench/`。

The archive index is available at [`archive/README.md`](../archive/README.md).
Archived code is retained for traceability and recovery; new production work
must stay in the active C++/MATLAB source and test paths.

归档区索引见 [`archive/README.md`](../archive/README.md)。归档代码用于追溯和恢复；
新的生产功能必须继续放在当前 C++/MATLAB 源码与测试路径中。
