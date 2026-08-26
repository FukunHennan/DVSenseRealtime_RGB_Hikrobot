# Flexible Riser MATLAB Architecture

> **Superseded on August 15, 2026.** The deployed runtime uses the isolated
> helper as a production dependency, and the production UI direction is the
> hybrid native-frame/`uihtml` design. See
> `docs/superpowers/specs/2026-08-15-hybrid-production-ui.md`.

## Goal

Deliver a MATLAB-first DVSense application for detecting a flexible riser's
motion state, outline, centerline, curvature, displacement, and vibration,
while keeping camera acquisition and SDK lifetime management in precompiled
native binaries.

## Boundary

MATLAB owns the application lifecycle, GUI, event-window processing,
recognition algorithms, GPU execution, data analysis, and result storage.

The native bridge owns only the DVSense SDK boundary: camera open/close,
bounded event buffering, display-frame generation, parameter metadata,
parameter writes with readback, and raw recording. Native code does not own
the flexible-riser recognition algorithm.

The user must not need Visual Studio, a C++ compiler, or a MEX toolchain to
run the delivered application.

## Runtime Architecture

```text
DVSLume
  |
  v
Precompiled DVSense bridge DLL + vendor runtime DLLs
  |
  v
MATLAB loadlibrary/calllib wrapper
  |
  +--> MATLAB realtime GUI
  +--> MATLAB/GPU flexible-riser recognition
  +--> MATLAB recording and analysis
```

The current MEX/helper path is a development and validation artifact. The
final MATLAB entry point must not require compiling `dvsense_mex`.

## Native Bridge Contract

The bridge exports a narrow C ABI:

- `dvsense_open`
- `dvsense_close`
- `dvsense_start`
- `dvsense_stop`
- `dvsense_read_events`
- `dvsense_read_frame`
- `dvsense_get_camera_info`
- `dvsense_get_tool_parameters`
- `dvsense_set_parameter`
- `dvsense_start_recording`
- `dvsense_stop_recording`
- `dvsense_last_error`

All buffers are caller-owned or fixed-capacity bridge-owned buffers with
explicit element counts. No C++ STL type crosses the MATLAB boundary.
Parameter names, types, ranges, units, and enum choices come from the SDK at
runtime.

## MATLAB GUI

The final GUI uses the stable MATLAB `figure` graphics system for the
high-rate image view. It keeps a fixed image axes and updates only image
`CData`; window resizing changes layout only through a debounced resize
callback. Parameter controls use grouped panels, scrollable rows, sliders
with SDK-derived limits, exact numeric fields, enum menus, and per-row
readback status.

The GUI must not rebuild its layout in the frame-refresh loop. Full-screen
mode must preserve the image coordinate limits and must not trigger repeated
axes recreation.

## Recognition Pipeline

The first production pipeline is:

1. Read a bounded event window from the bridge.
2. Apply ROI and activity filtering.
3. Build a stable event image/time surface.
4. Segment the riser candidate.
5. Clean the mask with morphology and connected-component rules.
6. Extract the outer contour.
7. Extract a centerline using skeletonization and path selection.
8. Smooth and fit the centerline.
9. Compute curvature, displacement, velocity, acceleration, and vibration
   features.
10. Publish a fixed result structure to the GUI and recorder.

The result contract is independent of CPU/GPU implementation:

- `valid`
- `timestampUs`
- `mask`
- `outline`
- `centerline`
- `curvature`
- `position`
- `velocity`
- `acceleration`
- `confidence`
- `state`

## GPU Policy

The default backend is `matlab-gpu`. At startup MATLAB verifies the Parallel
Computing Toolbox and a usable GPU. If unavailable, the application records a
visible warning and falls back to CPU only when `allowFallback` is true.
GPU use is limited to recognition and feature extraction; camera I/O and GUI
display remain CPU-side.

GPU and CPU backends must produce the same result fields and be checked against
the same deterministic fixtures.

## Deployment

Runtime binaries live under `runtime/`:

- bridge DLL
- DVSense vendor DLLs
- transitive non-system dependencies

MATLAB adds only this private directory for DLL resolution and restores the
original path on shutdown. Insight Qt/OpenCV GUI DLLs are not copied into the
MATLAB process.

## Acceptance Criteria

- Running `main.m` does not require `mex -setup`.
- The default configuration requests GPU recognition.
- The GUI can start, stop, and restart acquisition without closing.
- Full-screen resizing does not recreate the image object or parameter layout.
- All SDK parameter controls enforce SDK metadata limits and enum choices.
- A deterministic flexible-riser fixture produces outline and centerline
  results on both CPU and GPU backends.
- Native and MATLAB tests pass, and a real DVSLume open/read/close smoke test
  leaves no camera-owning process behind.
