# Display Accumulation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the visible event trail respond directly to an explicit accumulation-time setting while keeping camera batching and screen refresh independent.

**Architecture:** Keep camera acquisition batches fixed at 1 ms. Add a bounded timestamped native display accumulator that renders the latest events inside a configurable time window. Keep MATLAB display refresh fixed at 25 Hz and expose only the display accumulation window to the user.

**Tech Stack:** MATLAB R2024b, C++17 helper/bridge, MATLAB `uihtml`, existing fixed-resolution indexed display frames.

**Spec:** `docs/superpowers/specs/2026-08-17-display-accumulation-design.md`

## Global Constraints

- Camera read batch remains fixed at 1 ms.
- Display accumulation is initially clamped to 1-100 ms.
- Display refresh is fixed internally at 25 Hz and is not user-editable.
- Recognition timing remains independent of display accumulation.
- Native display history is bounded and resets on close, ROI change, or window change.
- Existing event-packet and camera ownership interfaces remain compatible.

---

### Task 1: Add A Timestamped Native Display Accumulator

**Files:**
- Create: `src/native/src/display_event_accumulator.hpp`
- Modify: `tests/native/frame_batch_test.cpp`

**Interfaces:**
- Produces `DisplayEventAccumulator(width, height, maxEvents)`.
- Produces `setWindowUs(uint64_t)`, `reset(width, height)`, `clear()`,
  `append(const DisplayEvent*, size_t)`, and `snapshot()`. `DisplayEvent` is a
  local record containing `x`, `y`, `polarity`, and `timestamp`; the helper
  converts SDK events into this record before appending.
- `snapshot()` returns a gray/white/black indexed frame and returns a gray
  frame when no new events have arrived since the previous snapshot.

- [ ] **Step 1: Write the failing native tests**

Add cases covering:

```cpp
DisplayEventAccumulator accumulator(4, 1, 16);
accumulator.setWindowUs(1000);
accumulator.append(events_at_1000_and_1500);
auto frame = accumulator.snapshot();
```

Assert that both events appear inside the first 1000-us window, an event older
than the active window is dropped after a newer event arrives, changing the
window clears old pixels, and a second snapshot without new events is gray.

- [ ] **Step 2: Run the native test and verify it fails**

Run the existing native test command once a compiler is available. Expected:
the new accumulator type is missing and compilation fails for the intended
reason.

- [ ] **Step 3: Implement the bounded accumulator**

Store timestamped events in a bounded vector/deque. On `append`, retain the
newest events up to `maxEvents`, update the newest timestamp, and prune entries
older than `newestTimestamp - windowUs`. On `snapshot`, render retained events
into an indexed frame, clear the `newEvents` flag, and return gray when no new
events exist.

- [ ] **Step 4: Run the native regression**

Compile and run `frame_batch_test`. Expected: all accumulator and existing frame
regression assertions pass.

### Task 2: Wire The Native Display-Window Protocol

**Files:**
- Modify: `src/native/bridge/dvsense_bridge.h`
- Modify: `src/native/bridge/dvsense_bridge.cpp`
- Modify: `src/native/src/dvsense_helper.cpp`
- Modify: `src/matlab/+camera/DVSenseSession.m`
- Modify: `src/matlab/+camera/DVSenseCameraSource.m`
- Test: `tests/matlab/testNativeProtocol.m`

**Interfaces:**
- Adds `dvsense_set_display_window(uint64_t window_us)` to the bridge.
- Adds helper command `CMD_DISPLAY_WINDOW`.
- Adds `DVSenseSession.setDisplayWindow(windowUs)`.
- Adds `DVSenseCameraSource.setDisplayAccumulation(windowUs)` and
  `DVSenseCameraSource.resetDisplayAccumulation()`.

- [ ] **Step 1: Write the failing MATLAB protocol/source tests**

Extend `testNativeProtocol` to verify the new bridge declaration and add a
source-control test that accepts a display accumulation update while closed.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run:

```matlab
run(fullfile(pwd,"tools","dev","setupPath.m"))
runtests({"tests/matlab/testNativeProtocol.m", ...
    "tests/matlab/testDVSenseCameraSourceControls.m"})
```

Expected: the new bridge declaration or source method is missing.

- [ ] **Step 3: Implement the protocol**

Use the existing little-endian `appendU64`/`readU64` request path. The helper
forwards the window value to the accumulator, clamps it to 1-100000 us, and
resets the display history. Camera close and ROI changes also reset the
accumulator.

- [ ] **Step 4: Run focused tests and compile the bridge/helper**

Run the focused MATLAB tests and the existing bridge/helper build scripts.
Expected: the new command is accepted and the runtime binaries are rebuilt
under `runtime/bin`.

### Task 3: Replace The Misleading UI And Application Control

**Files:**
- Modify: `main.m`
- Modify: `src/matlab/+app/run.m`
- Modify: `src/matlab/+app/readViewerCommandState.m`
- Modify: `src/matlab/+ui/WorkbenchViewer.m`
- Modify: `src/matlab/+ui/assets/settings.html`
- Modify: `src/matlab/+ui/+internal/mapControlEvent.m`
- Modify: `src/matlab/+ui/LiveViewer.m`
- Test: `tests/matlab/testViewerCommandState.m`
- Test: `tests/matlab/testUiControlProtocol.m`
- Test: `tests/matlab/testWorkbenchViewerContract.m`

**Interfaces:**
- Adds `cfg.display.accumulationUs`, defaulting to `5000`.
- Adds command type `setDisplayAccumulationUs`.
- Removes user-facing refresh-rate controls while keeping an internal
  `cfg.display.refreshHz = 25`.
- `app.run` keeps `cfg.source.windowUs = 1000` and forwards accumulation changes
  to the camera source display accumulator only.

- [ ] **Step 1: Write failing command and UI tests**

Assert that `setDisplayAccumulationUs` is clamped and preserved by
`readViewerCommandState`, that the UI source contains `事件累计时间` but no
user-editable `画面刷新率` row, and that `setBatchTimeUs` is not generated by
the accumulation control.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run the three focused MATLAB test files. Expected: the new command and display
state do not exist, and the old refresh row is still present.

- [ ] **Step 3: Implement the MATLAB/UI wiring**

Keep `displayRefreshHz` internal in `app.run`. Add a separate
`displayAccumulationUs` state and command. On acceptance, call
`src.setDisplayAccumulation(windowUs)` and reset only display accumulation;
ROI/start/stop continue to reset recognition and tracking.

Update the settings HTML to show one emphasized `事件累计时间` control with
1-100 ms bounds and send `setDisplayAccumulationUs`.

- [ ] **Step 4: Run focused tests and the full MATLAB suite**

Expected: all command, UI, ROI, recognition, and viewer tests pass with the
refresh control removed.

### Task 4: Final Integration And Verification

**Files:**
- Modify: `docs/index.md`
- Modify: `docs/architecture/current.md`
- Modify: `runtime/README.md`
- Modify: `tests/manual/captureOfficialWorkbenchFinal.m`

**Interfaces:**
- Documentation describes camera batching, display accumulation, and refresh as
  separate responsibilities.
- Manual preview/output paths remain under `artifacts/previews`.

- [ ] **Step 1: Update current documentation**

Replace wording that describes refresh cadence or camera batch duration as the
display accumulation setting.

- [ ] **Step 2: Run the full MATLAB suite**

Run:

```matlab
run(fullfile(pwd,"tools","dev","setupPath.m"))
results = runtests("tests/matlab");
assertSuccess(results)
```

- [ ] **Step 3: Run native regression and real-camera smoke test**

Compile/run `tests/native/frame_batch_test.cpp`. With the camera free, run
discovery, open/close, and one display-window update. Confirm no MATLAB or
helper process remains.

- [ ] **Step 4: Verify the development package**

Run `createDevelopmentPackage` and confirm the archive contains `src`,
`runtime/bin`, and `启动开发版.bat`, but excludes `artifacts`.
