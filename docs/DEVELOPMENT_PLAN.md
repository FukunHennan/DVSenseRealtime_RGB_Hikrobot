# Development Plan / 开发路线

This is the short milestone route. Detailed SDK and build instructions are
kept in the purpose-specific documents linked from `docs/README.md`.

这是项目的简版里程碑路线。详细 SDK 和构建说明集中在
`docs/README.md` 所链接的用途文档中。

## M0: Native camera baseline / 原生相机基线

**Status / 状态: Complete / 已完成**

- DVSense `DVSLume` opens and produces events.
- Hikrobot `MV-CU050-90UC` opens and produces RGB frames.
- Both independent cameras stream in one native C++ process.
- Real failure records are preserved, including DVS empty serial recovery and
  the complete MVS runtime requirement.

- DVSense `DVSLume` 已打开并持续产生事件。
- 海康 `MV-CU050-90UC` 已打开并持续产生 RGB 图像帧。
- 两台独立相机已在同一个原生 C++ 进程中并行取流。
- 已保留 DVS 空序列号恢复和 MVS 完整运行库等真实故障记录。

Acceptance evidence / 验收证据：`docs/CONNECTION_BASELINE.md`.

## M1: Native fused display / 原生融合画面

**Status / 状态: Next / 下一阶段**

- Use the official Fusion SDK path for the dual-camera session.
- Keep device ownership, callbacks, synchronization, calibration, and latest
  frame buffering in C++.
- Produce the first visible fused frame in DVS `1280x720` coordinates.
- Keep the frame buffer bounded and prefer the newest complete frame.

- 使用官方 Fusion SDK 完成双相机会话。
- 由 C++ 管理设备所有权、回调、同步、标定和最新画面缓存。
- 输出第一幅 DVS `1280x720` 坐标系下的可见融合画面。
- 画面缓存必须有界，并优先保留最新完整画面。

ROI, recognition, GPU processing, and final UI redesign are out of scope for
this milestone.

本里程碑暂不包含 ROI、识别、GPU 处理和最终 UI 重构。

## M2: Manager integration / 管理层接入

- MATLAB remains the configuration, lifecycle, and UI manager.
- MATLAB calls only the project C++ bridge.
- MATLAB displays the latest native fused frame and basic status.
- Existing single-DVS mode remains available during the transition.

- MATLAB 继续负责配置、生命周期和 UI 管理。
- MATLAB 只调用项目 C++ bridge。
- MATLAB 显示原生最新融合画面和基本状态。
- 迁移期间保留现有单 DVS 模式。

## M3: Stability and synchronization / 稳定性与同步

- Verify calibration validity, timestamp delta, RGB FPS, event rate, and
  dropped-frame counters.
- Exercise stop, restart, partial-open failure, and helper cleanup.
- Run a longer stability session and record latency and memory behavior.

- 验证标定有效性、时间差、RGB FPS、事件率和丢帧计数。
- 验证停止、重启、部分打开失败和 helper 清理。
- 进行更长时间稳定性测试，记录延迟和内存表现。

## M4: GPU and later analysis / GPU 与后续分析

- Keep a CPU reference implementation.
- Benchmark CUDA event rasterization, RGB warp, overlay, and transfers.
- Enable GPU processing only when measurements justify it.
- Add ROI, recognition, recording, and offline replay after the fused display
  is stable.

- 保留 CPU 参考实现。
- 测量 CUDA 事件栅格化、RGB 变换、叠加和数据传输。
- 只有测试数据证明有收益时才启用 GPU 处理。
- 融合画面稳定后再加入 ROI、识别、录制和离线回放。

## Development Rules / 开发规则

- Native C++ is the final camera and fusion program.
- MATLAB is the manager/UI layer, not the vendor SDK owner.
- Machine-specific paths belong in `config/local.json`.
- Project-owned movable dependencies belong under the project tree when
  licensing and runtime behavior allow it.
- Every new plan document must be bilingual.

- 原生 C++ 是最终相机和融合程序。
- MATLAB 是管理层和 UI 层，不直接拥有厂商 SDK。
- 机器相关路径写入 `config/local.json`。
- 在许可和运行行为允许时，可移动的项目依赖统一放在项目目录内。
- 后续所有计划文件必须双语。
