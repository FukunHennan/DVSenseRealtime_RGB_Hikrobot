# Flexible Riser MATLAB Architecture Implementation Plan

> **Historical plan.** Runtime bridge, helper isolation, bounded display
> buffers, SDK parameters, and riser recognition were implemented through
> later work. The remaining production UI migration is planned in
> `docs/superpowers/plans/2026-08-15-hybrid-production-ui.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the prototype MEX/uifigure path with a MATLAB-first application backed by a precompiled DVSense C ABI bridge and a GPU-default flexible-riser recognition pipeline.

**Architecture:** MATLAB owns GUI, recognition, GPU execution, recording, and analysis. A narrow precompiled bridge DLL owns only SDK access, bounded buffers, display frames, and parameter operations. The bridge ships with private vendor runtime DLLs and does not expose C++ types.

**Tech Stack:** MATLAB R2024b, `loadlibrary/calllib`, MATLAB `figure` graphics, Image Processing Toolbox, Computer Vision Toolbox, Parallel Computing Toolbox, MSVC-built bridge DLL, DVSense SDK.

**Spec:** `docs/superpowers/specs/2026-08-14-flexible-riser-matlab-architecture.md`

## Global Constraints

- No user-side C++ compiler, MEX setup, or Visual Studio configuration.
- SDK parameter names and constraints must come from runtime metadata.
- GPU recognition is the default; CPU fallback is explicit and visible.
- The display frame uses the official gray/white/black palette.
- Native buffers are bounded and must not grow with runtime duration.
- Insight Qt/OpenCV GUI DLLs must not be loaded into the MATLAB process.

---

### Task 1: Establish the final runtime layout

**Files:**
- Create: `runtime/README.md`
- Create: `+dvsense/RuntimeLayout.m`
- Modify: `main.m`
- Modify: `docs/README.md`
- Test: `tests/testRuntimeLayout.m`

- [ ] Write a failing test asserting `RuntimeLayout` returns the bridge path,
  vendor DLL path, and restores the original MATLAB path after cleanup.
- [ ] Run `matlab -batch "addpath(pwd); results=runtests('tests/testRuntimeLayout.m'); assert(any([results.Failed]))"`.
- [ ] Implement private runtime path resolution without modifying the global
  user environment permanently.
- [ ] Run the focused test and confirm it passes.
- [ ] Update `main.m` to use `RuntimeLayout` and set
  `cfg.compute.backend = "matlab-gpu"` with `cfg.compute.allowFallback = true`.

### Task 2: Implement the precompiled C ABI bridge

**Files:**
- Create: `native/bridge/dvsense_bridge.h`
- Create: `native/bridge/dvsense_bridge.cpp`
- Create: `tools/buildBridge.m`
- Create: `tests/testBridgeAbi.m`
- Modify: `+app/dvsenseRuntimeFiles.m`

- [ ] Write ABI tests for open/close state, bounded event reads, frame reads,
  metadata retrieval, parameter write/readback, and last-error behavior.
- [ ] Run the ABI test against a fake bridge and confirm it fails because the
  exported bridge API is absent.
- [ ] Implement opaque handles and fixed-capacity C buffers; expose only
  primitive C types, byte buffers, and explicit lengths.
- [ ] Build the bridge into `runtime/dvsense_bridge.dll` and keep import
  libraries/intermediate objects under `build/`.
- [ ] Use `dumpbin /DEPENDENTS` to verify the bridge dependency closure and
  copy only required vendor DLLs into `runtime/`.
- [ ] Run the ABI test and confirm it passes without loading a MEX file.

### Task 3: Add the MATLAB bridge wrapper

**Files:**
- Create: `+dvsense/DVSenseSession.m`
- Create: `+dvsense/BridgeTypes.m`
- Create: `+dvsense/BridgeErrors.m`
- Create: `tests/testDVSenseSession.m`

- [ ] Write tests for MATLAB-side open/close, event packet shape,
  display-frame shape, metadata conversion, parameter validation, and
  idempotent cleanup.
- [ ] Run the focused tests and verify they fail at the missing wrapper seam.
- [ ] Implement `loadlibrary/calllib` declarations and preallocated pointer
  handling. Convert native buffers to MATLAB arrays only once per batch.
- [ ] Implement `onCleanup` and explicit `stop/close` ordering.
- [ ] Run the focused tests with the fake bridge and confirm they pass.

### Task 4: Replace the high-rate GUI

**Files:**
- Create: `+ui/RealtimeViewer.m`
- Create: `+ui/ParameterPanel.m`
- Create: `+ui/ViewerLayout.m`
- Create: `tests/testRealtimeViewerLayout.m`
- Modify: `+app/run.m`

- [ ] Write tests asserting a fixed image handle, stable axes limits,
  grouped scrollable parameter rows, SDK-derived slider limits, and no layout
  rebuild during frame updates.
- [ ] Run the focused tests and verify the current uifigure implementation
  fails the fixed-handle and layout assertions.
- [ ] Implement a classic MATLAB `figure` with fixed image axes, debounced
  resize, separate parameter panels, and slider/value-field synchronization.
- [ ] Make stop/start state changes keep the figure alive and make display
  updates change only `CData` and overlays.
- [ ] Run focused GUI tests and a manual full-screen smoke test.

### Task 5: Implement the flexible-riser recognition pipeline

**Files:**
- Create: `+recognition/RiserPipeline.m`
- Create: `+recognition/buildEventImage.m`
- Create: `+recognition/segmentRiser.m`
- Create: `+recognition/extractOutline.m`
- Create: `+recognition/extractCenterline.m`
- Create: `+recognition/estimateMotionState.m`
- Create: `tests/testRiserPipeline.m`
- Create: `tests/fixtures/riserEvents.mat`

- [ ] Create a deterministic synthetic riser event fixture containing a
  curved stripe and noise.
- [ ] Write tests for mask, outline, centerline, curvature, motion fields,
  confidence, and invalid sparse input.
- [ ] Run the focused tests and confirm they fail before the pipeline exists.
- [ ] Implement CPU processing using bounded arrays, morphology,
  connected-component filtering, contour extraction, skeletonization, and
  centerline smoothing.
- [ ] Run focused CPU tests and confirm deterministic results.

### Task 6: Make GPU the default recognition backend

**Files:**
- Create: `+recognition/CpuRiserBackend.m`
- Create: `+recognition/GpuRiserBackend.m`
- Modify: `+compute/BackendFactory.m`
- Modify: `main.m`
- Modify: `docs/GPU_ACCELERATION_ROADMAP.md`
- Create: `tests/testRiserBackends.m`

- [ ] Write cross-backend tests that compare valid state, centerline shape,
  bounding geometry, and motion features within tolerances.
- [ ] Run the tests and confirm the GPU backend selection test fails while the
  current configuration defaults to CPU.
- [ ] Implement GPU batching with `gpuArray`, gather only compact results, and
  preserve CPU fallback with a visible status reason.
- [ ] Change the default configuration to `matlab-gpu`.
- [ ] Run tests on machines with and without a usable GPU; confirm both paths
  are deterministic and explicit.

### Task 7: Remove the old runtime path and update deployment docs

**Files:**
- Modify: `main.m`
- Modify: `docs/README.md`
- Modify: `docs/DVSENSE_DLL_ANALYSIS.md`
- Modify: `docs/OFFICIAL_PIPELINE_NOTES.md`
- Modify: `tools/buildMex.m`
- Create: `tools/packageRuntime.m`

- [ ] Write a packaging test asserting the final package contains the bridge
  DLL, required vendor dependencies, MATLAB code, and no Qt GUI DLLs.
- [ ] Run the packaging test and confirm it fails against the old `build/mex`
  layout.
- [ ] Implement package generation and mark MEX/helper as development-only
  artifacts.
- [ ] Update run instructions so a clean machine runs `main.m` without
  compiler setup.
- [ ] Run all MATLAB tests, bridge ABI tests, packaging tests, and the real
  DVSLume open/read/close smoke test.
- [ ] Verify no MATLAB/helper/bridge process remains and no camera lock is
  left behind.
