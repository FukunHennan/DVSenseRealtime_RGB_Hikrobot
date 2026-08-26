# Hybrid Production UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the monolithic production viewer with an official-style
hybrid MATLAB workbench while preserving native frame performance, one camera
owner, bounded memory, SDK-driven parameters, and reliable cleanup.

**Architecture:** `ui.LiveViewer` remains the seam used by `app.run` and
delegates to the official `OfficialLiveViewer` composed of one native
`FrameSurface` and bounded command interfaces. Camera operations remain in
`app.run`.

**Tech Stack:** MATLAB R2024b, `uifigure`, `uigridlayout`, `uiaxes`,
`image.CData`, `uihtml`, local HTML/CSS/JavaScript, MATLAB function-based
tests, existing bridge/helper runtime.

**Spec:** `docs/superpowers/specs/2026-08-15-hybrid-production-ui.md`

## Global Constraints

- One `DVSenseSession` and one helper process own the single DVSLume.
- No Display Frame bytes, Base64 data, PNG data, or event arrays cross into
  `uihtml`.
- The official display palette remains gray background, white ON, black OFF.
- Tool Parameter names and constraints come from SDK metadata at runtime.
- UI callbacks enqueue commands and never call the source or bridge.
- The image object is created once and only its `CData` changes per frame.
- Stop/start resets event accumulation, recognition history, and tracker time.
- GPU status must describe actual execution; the current CPU-delegating GPU
  adapter must not be presented as completed GPU acceleration.
- The current workspace is not a Git repository. Each task ends with a
  verification checkpoint; initialize Git before production delivery so
  these checkpoints can become commits.

---

### Task 1: Add the versioned UI event mapper and bounded command mailbox

**Files:**
- Create: `+ui/+internal/mapControlEvent.m`
- Create: `+ui/+internal/CommandMailbox.m`
- Create: `tests/testUiControlProtocol.m`
- Create: `tests/testCommandMailbox.m`

**Interfaces:**
- Produces:
  - `command = ui.internal.mapControlEvent(event,parameters)`
  - `mailbox = ui.internal.CommandMailbox(64)`
  - `mailbox.push(command)`
  - `commands = mailbox.consume()`
- Consumes: existing `camera.validateToolParameter`.

- [ ] **Step 1: Write failing protocol tests**

```matlab
function tests=testUiControlProtocol
tests=functiontests(localfunctions);
end

function testMapsValidatedToolParameterEvent(testCase)
parameter=struct("tool","Biases","name","bias_diff","type","INT", ...
    "min","-25","max","23","unit","%","options",strings(0), ...
    "current","-15","defaultValue","-15","details","");
event=struct("version",1,"sequence",7, ...
    "type","setToolParameter", ...
    "payload",struct("index",1,"tool","Biases", ...
        "name","bias_diff","value",5));

command=ui.internal.mapControlEvent(event,parameter);

verifyEqual(testCase,string(command.type),"setToolParameter");
verifyEqual(testCase,command.value,5);
end

function testRejectsUnknownProtocolVersion(testCase)
event=struct("version",2,"sequence",1,"type","stop","payload",struct);
verifyError(testCase,@()ui.internal.mapControlEvent(event,struct([])), ...
    "DVSense:UIProtocolVersion");
end
```

- [ ] **Step 2: Run the protocol tests and verify RED**

Run:

```matlab
results=runtests("tests/testUiControlProtocol.m");
assert(any([results.Failed]))
```

Expected failure: `ui.internal.mapControlEvent` does not exist.

- [ ] **Step 3: Implement minimal event mapping**

Implement version checking, supported event types, required payload fields,
and Tool Parameter validation. Return the existing command shapes consumed by
`app.run`.

- [ ] **Step 4: Write failing mailbox tests**

```matlab
function testCoalescesRefreshAndParameterWrites(testCase)
box=ui.internal.CommandMailbox(64);
box.push(struct("type","setRefreshHz","value",20));
box.push(struct("type","setRefreshHz","value",30));
box.push(struct("type","setToolParameter","tool","Biases", ...
    "name","bias_diff","value",1));
box.push(struct("type","setToolParameter","tool","Biases", ...
    "name","bias_diff","value",2));

commands=box.consume();

verifyEqual(testCase,numel(commands),2);
verifyEqual(testCase,commands{1}.value,30);
verifyEqual(testCase,commands{2}.value,2);
end
```

- [ ] **Step 5: Run mailbox tests and verify RED**

Expected failure: `ui.internal.CommandMailbox` does not exist.

- [ ] **Step 6: Implement the bounded mailbox**

Use a private cell array, a capacity constructor argument, coalescing keys for
refresh and Tool Parameter writes, and explicit overflow errors for protected
commands.

- [ ] **Step 7: Run both focused tests and verify GREEN**

Run:

```matlab
results=runtests(["tests/testUiControlProtocol.m", ...
    "tests/testCommandMailbox.m"]);
assertSuccess(results)
```

- [ ] **Step 8: Record checkpoint**

Record the four files and the passing test output in the implementation log.

---

### Task 2: Add explicit processing-state reset for stop/start

**Files:**
- Modify: `+pipeline/EventAccumulator.m`
- Modify: `+recognition/RiserPipeline.m`
- Modify: `+recognition/CpuRiserBackend.m`
- Modify: `+recognition/GpuRiserBackend.m`
- Modify: `+tracking/KalmanTracker.m`
- Create: `+app/resetProcessingState.m`
- Create: `tests/testProcessingReset.m`

**Interfaces:**
- Produces:
  - `EventAccumulator.reset()`
  - `RiserPipeline.reset()`
  - `CpuRiserBackend.reset()`
  - `GpuRiserBackend.reset()`
  - `KalmanTracker.reset()`
  - `app.resetProcessingState(accumulator,riserBackend,tracker)`

- [ ] **Step 1: Write the failing reset test**

Create a Recognition Window, advance the tracker, call
`app.resetProcessingState`, then verify:

```matlab
verifyFalse(testCase,accumulator.ready());
verifyFalse(testCase,tracker.Initialized);
verifyEqual(testCase,tracker.LastTimestampUs,uint64(0));
```

Process a new packet whose timestamp restarts at a smaller value and verify no
unsigned timestamp underflow or inherited velocity.

- [ ] **Step 2: Run the focused test and verify RED**

Expected failure: reset methods do not exist and tracker state remains
initialized.

- [ ] **Step 3: Implement reset methods**

Each module clears only runtime state and preserves configuration and
preallocated buffers.

- [ ] **Step 4: Run reset and existing pipeline tests**

Run:

```matlab
results=runtests(["tests/testProcessingReset.m", ...
    "tests/testRiserPipeline.m","tests/testRiserBackends.m"]);
assertSuccess(results)
```

- [ ] **Step 5: Record checkpoint**

Record the reset contract and test output.

---

### Task 3: Extract the native frame surface

**Files:**
- Create: `+ui/+internal/FrameSurface.m`
- Create: `tests/testFrameSurface.m`

**Interfaces:**
- Produces:
  - `ui.internal.FrameSurface(parent,cfg)`
  - `update(frame,track)`
  - `reset()`
  - `setOverlayVisible(value)`
  - `getImageHandle()`

- [ ] **Step 1: Write a failing fixed-handle test**

```matlab
figureHandle=uifigure("Visible","off");
cleanup=onCleanup(@()delete(figureHandle)); %#ok<NASGU>
surface=ui.internal.FrameSurface(figureHandle,localConfig);
first=surface.getImageHandle();
surface.update(ones(720,1280,"uint8"),localTrack);
surface.update(2*ones(720,1280,"uint8"),localTrack);

verifyTrue(testCase,isvalid(first));
verifyEqual(testCase,surface.getImageHandle(),first);
verifyEqual(testCase,first.CData(1,1),uint8(2));
```

- [ ] **Step 2: Run and verify RED**

Expected failure: `FrameSurface` does not exist.

- [ ] **Step 3: Implement the native surface**

Create one `uiaxes`, one indexed image, one rectangle, and one point marker.
Use the official colormap and nearest-neighbor interpolation. `update` changes
only data and overlay properties.

- [ ] **Step 4: Add resize and reset assertions**

Change the parent figure size, call `drawnow`, and verify the image handle is
unchanged. Call `reset` and verify gray `CData` and hidden overlays.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run:

```matlab
results=runtests("tests/testFrameSurface.m");
assertSuccess(results)
```

- [ ] **Step 6: Record checkpoint**

Record handle identity and resize evidence.

---

### Task 4: Build production HTML surfaces and compact state snapshots

**Files:**
- Create: `+ui/+internal/HtmlSurface.m`
- Create: `+ui/+internal/buildControlState.m`
- Create: `+ui/assets/shared.css`
- Create: `+ui/assets/ui-bridge.js`
- Create: `+ui/assets/settings.html`
- Create: `+ui/assets/header.html`
- Create: `+ui/assets/transport.html`
- Create: `tests/testHtmlControlState.m`
- Create: `tests/testProductionUiAssets.m`

**Interfaces:**
- Produces:
  - `ui.internal.HtmlSurface(parent,htmlFile,eventHandler)`
  - `publish(payload)`
  - `state = ui.internal.buildControlState(viewerState)`

- [ ] **Step 1: Write failing state-snapshot tests**

Verify the output includes protocol version, monotonic revision, connection,
run state, camera metadata, compact stats, Tool Parameters, and per-parameter
status.

Verify it does not contain fields named `frame`, `image`, `pixels`, `events`,
`x`, `y`, `polarity`, or `timestampArray`.

- [ ] **Step 2: Run state tests and verify RED**

Expected failure: `buildControlState` does not exist.

- [ ] **Step 3: Implement compact state construction**

Use MATLAB structs containing only JSON-compatible scalar, string, logical,
and compact Tool Parameter metadata fields.

- [ ] **Step 4: Write failing asset tests**

The test reads each HTML file and verifies:

- local `shared.css` and `ui-bridge.js` references;
- no `http://` or `https://` dependency;
- no APS label;
- expected DVS controls;
- one `setup(htmlComponent)` bridge entry point;
- no frame transport key.

- [ ] **Step 5: Run asset tests and verify RED**

Expected failure: production assets do not exist.

- [ ] **Step 6: Implement assets from the approved design**

Rebuild the validated prototype under `+ui/assets/`. Do not copy the manual
prototype unchanged: remove simulation timers, hard-coded parameter data, and
test-only labels. Render values only from `htmlComponent.Data`.

- [ ] **Step 7: Implement `HtmlSurface`**

Validate the asset path, create one `uihtml`, publish complete snapshots
through `Data`, and route `DataChangedFcn` events to the supplied MATLAB
handler.

- [ ] **Step 8: Run focused tests and verify GREEN**

Run:

```matlab
results=runtests(["tests/testHtmlControlState.m", ...
    "tests/testProductionUiAssets.m"]);
assertSuccess(results)
```

- [ ] **Step 9: Record checkpoint**

Record asset ownership and protocol version.

---

### Task 5: Build the independent analysis window

**Files:**
- Create: `+ui/AnalysisWindow.m`
- Create: `+ui/assets/analysis.html`
- Create: `tests/testAnalysisWindow.m`

**Interfaces:**
- Produces:
  - `ui.AnalysisWindow()`
  - `show()`
  - `hide()`
  - `update(riserResult,track,backendState)`
  - `isOpen()`
  - `delete()`

- [ ] **Step 1: Write a failing lifecycle test**

Create the window hidden, show and hide it, and verify the owning main figure
and a supplied fake camera-owner flag remain unchanged.

- [ ] **Step 2: Run and verify RED**

Expected failure: `ui.AnalysisWindow` does not exist.

- [ ] **Step 3: Implement the window**

Use a native axes for outline and centerline coordinates and an HTML surface
for low-rate metrics. Store only the latest result.

- [ ] **Step 4: Add update assertions**

Verify line handles are reused across updates and metrics report actual
backend state, including CPU fallback.

- [ ] **Step 5: Run focused tests and verify GREEN**

- [ ] **Step 6: Record checkpoint**

Record that child-window close has no camera-side effect.

---

### Task 6: Assemble `OfficialLiveViewer`

**Files:**
- Create: `+ui/OfficialLiveViewer.m`
- Create: `tests/testOfficialLiveViewer.m`

**Interfaces:**
- Implements the complete `LiveViewer` interface defined in the spec.
- Consumes:
  - `FrameSurface`
  - three `HtmlSurface` instances
  - `CommandMailbox`
  - `AnalysisWindow`
  - `mapControlEvent`
  - `buildControlState`

- [ ] **Step 1: Write failing construction tests**

Construct with `Visible="off"` test configuration and verify:

- one main figure;
- one image object;
- three HTML control surfaces;
- no source/session/helper object;
- official window title;
- `isRunning()` is true.

- [ ] **Step 2: Run and verify RED**

Expected failure: `OfficialLiveViewer` does not exist.

- [ ] **Step 3: Implement composition**

Use a stable grid with:

- settings surface on the left;
- header surface above the frame;
- native frame surface in the center;
- transport surface below the frame.

The viewer state is mutated only by public methods and then published at the
specified low-rate cadence.

- [ ] **Step 4: Write failing interaction tests**

Inject synthetic HTML events through a test seam and verify:

- stop/start commands;
- recording commands;
- Tool Parameter command validation;
- analysis show/hide;
- overlay visibility;
- bounded command consumption.

- [ ] **Step 5: Implement event handling and command consumption**

Map events, push commands, update local visual pending state, and defer
camera-side success until public readback methods are called.

- [ ] **Step 6: Add frame and state update tests**

Call `update` repeatedly and call `setAnalysisResult` independently. Verify:

- the image handle is unchanged;
- HTML payload contains compact stats only;
- outline, centerline, curvature, and backend state never enter frame
  transport;
- analysis data is updated only when the window is open;
- `drawnow limitrate` is used.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run:

```matlab
results=runtests("tests/testOfficialLiveViewer.m");
assertSuccess(results)
```

- [ ] **Step 8: Record checkpoint**

Record GUI object counts and command behavior.

---

### Task 7: Make the official viewer the sole production adapter

**Files:**
- Create: `+ui/LiveViewer.m`
- Modify: `main.m`
- Create: `tests/testLiveViewerFacade.m`

**Interfaces:**
- `ui.LiveViewer(cfg)` delegates the complete official viewer interface.
- No legacy adapter value is accepted.
- `AdapterName` is a read-only diagnostic property used by tests and support
  logs; it is not a graphics-control escape hatch.

- [ ] **Step 1: Write failing facade-selection tests**

```matlab
cfg=localConfig;
cfg.display.viewer="official";
viewer=ui.LiveViewer(cfg);
verifyEqual(testCase,string(viewer.AdapterName),"official");
delete(viewer);
```

- [ ] **Step 2: Implement the facade**

Delegate every public method without exposing concrete graphics handles to
`app.run`.

- [ ] **Step 3: Run facade tests**

Run:

```matlab
results=runtests("tests/testLiveViewerFacade.m");
assertSuccess(results)
```

- [ ] **Step 7: Record checkpoint**

Record both adapter paths and the default.

---

### Task 8: Integrate lifecycle, error reporting, and processing reset

**Files:**
- Modify: `+app/run.m`
- Modify: `+app/readViewerCommandState.m`
- Modify: `+datasource/DVSenseLiveSource.m`
- Modify: `+dvsense/DVSenseSession.m`
- Modify: `native/bridge/dvsense_bridge.cpp`
- Create: `native/tests/dvsense_fake_helper.cpp`
- Create: `tests/testRunLifecycle.m`
- Modify: `tests/testSourceCleanup.m`
- Modify: `tests/testViewerCommandState.m`
- Create: `tests/testNativeProtocol.m`

**Interfaces:**
- Consumes `app.resetProcessingState`.
- Calls `viewer.setCommandError(command,message)` for nonfatal command errors.
- Calls `viewer.resetProcessingView()` on successful stop.
- Calls `viewer.setAnalysisResult(riserResult,track,backendState)` after
  recognition without coupling analysis data to Display Frame transport.

- [ ] **Step 1: Write a failing stop/start state-reset test**

Use fake source, viewer, accumulator, backend, and tracker adapters to drive:

```text
running -> stop -> stopped -> start -> running
```

Verify source close/open counts, processing reset, UI labels, and one active
source at all times.

- [ ] **Step 2: Run and verify RED**

Expected failure: current stop/start does not reset processing state.

- [ ] **Step 3: Write a failing nonfatal parameter-error test**

Make fake `setToolParameter` throw and verify the loop continues and the
viewer receives one command error.

- [ ] **Step 4: Extract command application inside `app.run`**

Catch errors per nonfatal command. Do not catch fatal source-read or helper
protocol failures as successful operation.

- [ ] **Step 5: Harden partial-open cleanup**

Track bridge/helper startup separately from camera-start state so
`DVSenseSession.close()` can issue bridge cleanup after a partial open
failure. Add idempotent cleanup assertions.

- [ ] **Step 6: Write a failing stalled-helper protocol test**

Use `dvsense_fake_helper` to accept a request without returning a response,
then verify the bridge returns a timeout error within the configured bound.
Add a second case where the helper exits while a request is pending.

- [ ] **Step 7: Implement bounded bridge response waiting**

Replace unbounded pipe-response waiting with a deadline-aware wait that also
checks the helper process handle. Timeout and unexpected helper exit are fatal
protocol errors and must enter the normal cleanup path.

- [ ] **Step 8: Integrate reset on stop and restart**

Reset before accepting events from a newly opened source.

- [ ] **Step 9: Refresh parameter metadata after write/readback**

After a successful parameter write and SDK readback, update
`DVSenseLiveSource.Info.toolParameters` so reconnects and UI snapshots cannot
publish stale cached values.

- [ ] **Step 10: Publish recognition results separately**

After each completed recognition window, call:

```matlab
viewer.setAnalysisResult(riserResult,track,backendState);
```

Keep `viewer.update(frame,track,stats)` dedicated to the Display Frame and
compact live statistics.

- [ ] **Step 11: Run lifecycle, cleanup, command, and protocol tests**

Run:

```matlab
results=runtests(["tests/testRunLifecycle.m", ...
    "tests/testSourceCleanup.m","tests/testViewerCommandState.m", ...
    "tests/testNativeProtocol.m"]);
assertSuccess(results)
```

- [ ] **Step 12: Record checkpoint**

Record source ownership and cleanup counts.

---

### Task 9: Correct backend reporting

**Files:**
- Modify: `+recognition/GpuRiserBackend.m`
- Modify: `+recognition/BackendFactory.m`
- Modify: `+app/run.m`
- Modify: `tests/testRiserBackends.m`
- Create: `tests/testBackendStatus.m`

**Interfaces:**
- Produces a status structure:

```matlab
struct("requested","matlab-gpu", ...
    "executed","cpu", ...
    "fallback",true, ...
    "reason","GPU riser kernels not implemented")
```

- [ ] **Step 1: Write a failing status-accuracy test**

Verify the current CPU-delegating GPU adapter reports `executed="cpu"` and
does not display `GPU active`.

- [ ] **Step 2: Run and verify RED**

Expected failure: current names can imply GPU execution.

- [ ] **Step 3: Implement truthful backend status**

Do not implement GPU kernels in this task. Report requested and executed
backends separately and publish the fallback reason to the viewer.

- [ ] **Step 4: Run backend tests and verify GREEN**

- [ ] **Step 5: Record checkpoint**

Record the exact status shown on machines with and without GPU support.

---

### Task 10: Update documentation, archive prototypes, and run acceptance

**Files:**
- Modify: `README.md` or create it if still absent
- Modify: `main.m`
- Modify: `docs/README.md`
- Modify: `docs/OFFICIAL_PIPELINE_NOTES.md`
- Modify: `docs/GPU_ACCELERATION_ROADMAP.md`
- Modify: `docs/ui-design/final/README.md`
- Move after acceptance: `tests/manual/runDVSenseOfficialStylePreview.m`
- Move after acceptance: `tests/manual/assets/dvsense_official_matlab_preview.html`
- Create: `docs/protocols/ui-protocol.md`
- Create: `docs/operations/camera-recovery.md`
- Create: `docs/testing.md`

**Interfaces:**
- Documents the implemented protocol and operational recovery steps.

- [ ] **Step 1: Mark old architecture statements**

Mark the August 14 architecture spec as superseded where it conflicts with
the accepted helper-based runtime and hybrid UI.

- [ ] **Step 2: Document the implemented UI protocol**

Copy the final versioned event and state schemas from production tests, not
from the prototype.

After bridge-only runtime validation, remove the production `build/mex` path
from `main.m`. Keep legacy build artifacts outside the active runtime path.

- [ ] **Step 3: Run the complete automated suite**

Run:

```matlab
results=runtests("tests","IncludeSubfolders",true);
assertSuccess(results)
```

Expected: zero failed and zero incomplete automated tests. Hardware tests must
be tagged or located so they do not run by default.

- [ ] **Step 4: Run native validation**

Run the existing native frame-batch test and bridge fake-helper protocol
tests. Confirm bounded latest-data behavior.

- [ ] **Step 5: Run manual display acceptance**

Verify:

- 100%, 125%, 150%, and 175% Windows scaling;
- normal, maximized, and full-screen layouts;
- no flashing during resize;
- no image-handle recreation;
- parameter controls remain visible;
- analysis window can remain beside live view;
- stop/start works repeatedly.

- [ ] **Step 6: Run 30-minute real-camera acceptance**

Record:

- MATLAB working set at start and end;
- helper working set at start and end;
- display latency and recognition latency percentiles;
- camera stop/start count;
- parameter write/readback result;
- final helper and camera-owner process check.

- [ ] **Step 7: Archive the manual prototype**

Only after production visual and interaction acceptance, move the prototype
under `docs/archive/ui-prototypes/2026-08-15/` or delete it after Git history
exists. Production must not reference `tests/manual/assets`.

- [ ] **Step 8: Final documentation self-check**

Search for obsolete claims:

```powershell
rg -n "MEX把|helper.*开发|经典 MATLAB figure|GPU backend active" docs main.m +app +ui
```

Resolve every result against the implemented architecture.

- [ ] **Step 9: Record delivery checkpoint**

Record automated, native, manual, and hardware evidence together with the
runtime manifest.

---

## Execution order

Tasks 1 through 4 establish pure, camera-free seams. Task 5 can proceed after
Task 4. Task 6 composes them. Task 7 changes the production viewer selection.
Task 8 changes camera lifecycle behavior and must occur only after facade
tests pass. Task 9 corrects backend truthfulness independently before final
acceptance. Task 10 is the delivery gate.

## Self-review

- Every specification requirement maps to at least one task.
- No task sends Display Frame data to HTML.
- Stop/start reset is explicitly tested before production integration.
- Parameter legality and SDK readback remain in the existing source path.
- Legacy rollback remains available until hardware acceptance.
- GPU acceleration is not falsely claimed.
- The plan contains no user-side compiler requirement.
