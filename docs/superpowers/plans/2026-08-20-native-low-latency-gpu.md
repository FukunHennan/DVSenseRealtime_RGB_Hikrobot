# Native Low-Latency GPU Processing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move latency-critical DVSLume flexible-riser processing into the isolated native helper, add measured CUDA acceleration with native CPU fallback, and make MATLAB consume latest-only result snapshots asynchronously.

**Architecture:** The SDK callback publishes bounded Event Batches to a latest-only native mailbox. A dedicated helper processing thread owns Recognition Window assembly, native CPU/CUDA processing, tracking, and a latest-only Processing Result mailbox; the bridge and MATLAB read immutable snapshots without blocking acquisition.

**Tech Stack:** MATLAB R2024b, C++17, Windows named pipes, DVSense SDK, CUDA Runtime API, NVIDIA CUDA compiler, MATLAB `loadlibrary` C ABI.

**Spec:** `docs/superpowers/specs/2026-08-20-native-low-latency-gpu-design.md`

## Global Constraints

- Keep one Camera Session and one helper process as the only owner of the vendor SDK.
- Do not perform allocation, CUDA synchronization, recording I/O, or UI work in the SDK callback.
- All long-lived queues and buffers must have fixed capacity.
- Latest data replaces stale unpublished data and increments a drop counter.
- Preserve the existing MATLAB CPU path as a selectable fallback and validation oracle.
- Report requested, available, and executed backends separately, including fallback reason.
- Measure helper processing latency from Event Batch publication to Processing Result publication.
- Target mean processing latency at or below 1.5 ms and P99 at or below 3 ms where local hardware and event density permit it.
- Do not claim hard real-time behavior on Windows.
- Do not add Hikvision SDK loading or production RGB fusion in phase one.

## File Map

New native files:

- `src/native/src/latest_mailbox.hpp`: fixed-capacity latest-only publication primitive.
- `src/native/src/processing_types.hpp`: versioned Event Batch, configuration, result, backend-status, and statistics types.
- `src/native/src/processing_metrics.hpp`: fixed-capacity rolling latency statistics.
- `src/native/src/native_processing_backend.hpp`: backend interface and native CPU implementation.
- `src/native/src/native_processing_coordinator.hpp`: processing thread, window assembly, resets, fallback, and result publication.
- `src/native/cuda/cuda_processing_backend.hpp`: CUDA backend interface implementation declaration.
- `src/native/cuda/cuda_processing_backend.cu`: persistent CUDA buffers and accelerated parallel stages.
- `tests/native/latest_mailbox_test.cpp`: mailbox ordering and overflow tests.
- `tests/native/processing_metrics_test.cpp`: percentile and deadline tests.
- `tests/native/native_processing_test.cpp`: deterministic native CPU result tests.
- `tests/native/processing_coordinator_test.cpp`: thread, reset-generation, and fallback tests.
- `tests/native/cuda_processing_test.cu`: CPU/CUDA contract and failure-path tests.
- `tools/build/buildNativeTests.m`: reproducible native validation test builder and runner.
- `src/matlab/+camera/NativeProcessingResult.m`: fixed C result decoding into MATLAB structs.
- `tests/matlab/testNativeProcessingSession.m`: session adapter contract tests.
- `tests/matlab/testNativeProcessingAppPath.m`: application-path selection tests.
- `tools/diagnostics/benchmarkNativeProcessing.m`: benchmark runner and JSON/CSV report writer.

Modified files:

- `src/native/src/dvsense_helper.cpp`: create coordinator, publish callback batches, and implement processing commands.
- `src/native/bridge/dvsense_bridge.h`: public versioned processing C ABI.
- `src/native/bridge/dvsense_bridge.cpp`: processing command transport and bounded result decoding.
- `tools/build/buildMex.m`: compile helper processing sources and optional CUDA object.
- `tools/build/buildBridge.m`: copy validated helper and regenerate bridge assets.
- `src/matlab/+camera/+internal/dvsenseBridgePrototype.m`: processing function prototypes.
- `src/matlab/+camera/DVSenseSession.m`: native processing lifecycle and latest-result reads.
- `src/matlab/+camera/DVSenseCameraSource.m`: source-level processing facade.
- `src/matlab/+app/run.m`: select asynchronous native or existing MATLAB analysis path.
- `src/matlab/+ui/WorkbenchViewer.m`: publish backend/latency/drop status.
- `src/matlab/+ui/assets/status.html`: render processing diagnostics.
- `main.m`: native-processing configuration defaults.
- `runtime/manifest.json`: refreshed hashes after validated native build.
- `docs/architecture/current.md`: record the implemented processing path and measured limits.

---

### Task 1: Latest-Only Native Mailbox and Rolling Metrics

**Files:**
- Create: `src/native/src/latest_mailbox.hpp`
- Create: `src/native/src/processing_metrics.hpp`
- Create: `tests/native/latest_mailbox_test.cpp`
- Create: `tests/native/processing_metrics_test.cpp`
- Create: `tools/build/buildNativeTests.m`

**Interfaces:**
- Produces: `template<class T> class LatestMailbox` with `publish(const T&)`, `bool readLatest(uint64_t&, T&) const`, and `uint64_t droppedCount() const`.
- Produces: `class ProcessingMetrics` with `add(double)`, `reset()`, and `ProcessingMetricSnapshot snapshot(double deadlineUs) const`.
- Consumes: only C++17 standard library types.

- [ ] **Step 1: Write the mailbox test**

Create a test that publishes sequences 1, 2, and 3, verifies the consumer reads sequence 3 exactly once, verifies a second read reports no newer value, and verifies overwrite increments the drop counter. Add a concurrent loop with 100,000 publications where the reader asserts `payload.checksum == payload.sequence ^ 0x5a5a5a5aU`; any torn snapshot returns exit code 4.

- [ ] **Step 2: Write the metrics test**

Add samples `{100,200,300,400,500}` microseconds and verify count `5`, mean `300`, P50 `300`, P95 `500`, P99 `500`, maximum `500`, and two deadline misses at a `350` microsecond deadline. Reset and verify every field returns zero.

- [ ] **Step 3: Run tests to verify they fail to compile**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); buildNativeTests('mailbox-metrics')"
```

Expected: compiler errors naming missing `latest_mailbox.hpp` and `processing_metrics.hpp`.

- [ ] **Step 4: Implement the mailbox**

Use three preallocated slots, one mutex protecting publication and snapshot copy, a monotonically increasing publication sequence, and a consumed sequence. `publish` copies into the next slot and increments `droppedCount` when the previous publication has not been consumed. This first correct implementation deliberately uses a short critical section; lock-free replacement is permitted only after benchmarks prove the mutex is a bottleneck.

- [ ] **Step 5: Implement fixed-capacity metrics**

Store the newest 2048 microsecond samples in a preallocated `std::array<double,2048>`. `snapshot` copies only the active samples to a local fixed array, sorts the active range, and uses nearest-rank percentiles with indices `ceil(p * count) - 1`. Metrics snapshotting occurs on the bridge command thread, never the processing thread.

- [ ] **Step 6: Implement the native test builder**

`buildNativeTests(selection)` must use MATLAB's selected C++ compiler shell, compile into `artifacts/build/native-tests`, run the requested executables, and assert each exit status is zero. Support selections `mailbox-metrics`, `cpu-processing`, `coordinator`, `cuda`, and `all` with explicit source lists.

- [ ] **Step 7: Run the focused tests**

Run the command from Step 3. Expected: both executables exit `0`.

- [ ] **Step 8: Commit**

```powershell
git add src/native/src/latest_mailbox.hpp src/native/src/processing_metrics.hpp tests/native/latest_mailbox_test.cpp tests/native/processing_metrics_test.cpp tools/build/buildNativeTests.m
git commit -m "feat: add bounded native processing mailboxes"
```

### Task 2: Native Processing Contract and CPU Reference

**Files:**
- Create: `src/native/src/processing_types.hpp`
- Create: `src/native/src/native_processing_backend.hpp`
- Create: `tests/native/native_processing_test.cpp`
- Modify: `tools/build/buildNativeTests.m`

**Interfaces:**
- Consumes: `ProcessingMetrics` from Task 1.
- Produces: `ProcessingConfig`, `NativeEventBatch`, `ProcessingResult`, `BackendStatus`, and `INativeProcessingBackend`.
- Produces: `NativeCpuProcessingBackend::process(const NativeEventBatch&, const ProcessingConfig&) -> ProcessingResult` and `reset()`.

- [ ] **Step 1: Define deterministic contract tests**

Construct a 32×24 synthetic event packet containing a six-pixel-thick curved vertical target, positive and negative polarities, isolated noise, and timestamps spanning 5000 microseconds. Assert that the result is valid, its bounding box encloses the target, centerline points are ordered by increasing row, every output coordinate is in range, confidence is within `[0,1]`, and repeated processing after reset returns byte-equivalent scalar fields and point arrays.

- [ ] **Step 2: Add invalid-input tests**

Verify empty events return status `waiting-events`; out-of-range coordinates are ignored and counted; fewer than `recognitionMinEvents` return status `insufficient-events`; output outline and centerline arrays never exceed their compile-time capacities.

- [ ] **Step 3: Run the CPU processing test and verify compile failure**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); buildNativeTests('cpu-processing')"
```

Expected: compiler errors naming missing processing types and backend.

- [ ] **Step 4: Implement versioned processing types**

Use explicit fixed-width fields and `constexpr uint32_t PROCESSING_RESULT_VERSION = 1`. Set maximum result geometry to 8192 outline points and 2048 centerline points. Keep variable-length input events in preallocated vectors whose capacities are established during coordinator initialization; do not expose STL containers through the C ABI.

- [ ] **Step 5: Implement the minimal native CPU stages**

Port the observable behavior of MATLAB `ActivityFilter`, `buildEventImage`, `segmentRiser`, `extractOutline`, `extractCenterline`, `estimateMotionState`, and `MotionTracker`. Preserve one-based MATLAB coordinate conversion only at the bridge/MATLAB seam; native processing uses zero-based coordinates internally. Preallocate event-image, time-surface, mask, visited, and component-work buffers in the backend constructor.

- [ ] **Step 6: Add fixture export for parity**

Extend the test builder to export `tests/fixtures/riserEvents.mat` to a deterministic native binary fixture under `artifacts/build/native-tests` before compiling. The native test reads the exported packet and writes its result as JSON; a MATLAB assertion compares validity, bounding box within one pixel, centerline median distance within two pixels, and position within two pixels.

- [ ] **Step 7: Run CPU and MATLAB parity tests**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); buildNativeTests('cpu-processing'); results=runtests('tests/matlab/testRiserAnalysisPipeline.m'); assertSuccess(results)"
```

Expected: native executable exits `0`; MATLAB test file passes.

- [ ] **Step 8: Commit**

```powershell
git add src/native/src/processing_types.hpp src/native/src/native_processing_backend.hpp tests/native/native_processing_test.cpp tools/build/buildNativeTests.m
git commit -m "feat: add native CPU riser processing reference"
```

### Task 3: Processing Coordinator and Ordered Resets

**Files:**
- Create: `src/native/src/native_processing_coordinator.hpp`
- Create: `tests/native/processing_coordinator_test.cpp`
- Modify: `tools/build/buildNativeTests.m`

**Interfaces:**
- Consumes: `LatestMailbox<NativeEventBatch>`, `LatestMailbox<ProcessingResult>`, `INativeProcessingBackend`, and `ProcessingMetrics`.
- Produces: `NativeProcessingCoordinator::start()`, `stop(std::chrono::milliseconds)`, `publishBatch(const NativeEventBatch&)`, `configure(const ProcessingConfig&)`, `reset()`, `readLatest(uint64_t&, ProcessingResult&)`, `stats()`, and `status()`.

- [ ] **Step 1: Write coordinator lifecycle tests**

Use a fake backend that records the calling thread. Verify `publishBatch` returns without invoking the backend, processing occurs on a different thread, `stop(2000ms)` joins successfully, and destruction after stop is idempotent.

- [ ] **Step 2: Write latest-only and reset-generation tests**

Block the fake backend while publishing batches 1, 2, and 3. Release it and verify result 3 becomes the newest result and the dropped count is nonzero. Block processing batch 4, call `reset`, release processing, and verify no result from the pre-reset generation is published.

- [ ] **Step 3: Write fallback tests**

Configure a fake preferred backend to throw `std::runtime_error("injected GPU failure")`. Verify the coordinator resets state, processes the next window using native CPU, and reports requested `cuda`, executed `native-cpu`, fallback `true`, with the exact failure message.

- [ ] **Step 4: Run and verify test failure**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); buildNativeTests('coordinator')"
```

Expected: compiler error naming missing `NativeProcessingCoordinator`.

- [ ] **Step 5: Implement the coordinator**

Own one `std::jthread` or C++17 `std::thread` plus atomic stop flag, a condition variable, one Recognition Window buffer, current configuration generation, backend instances, result mailbox, and timing metrics. `publishBatch` only validates bounded size, publishes, and signals. The worker takes the newest batch, assembles until either configured duration or minimum-event threshold is met, runs the backend, verifies generation, and publishes.

- [ ] **Step 6: Implement bounded shutdown and fallback**

Use an explicit worker-exited condition variable. `stop(timeout)` signals cancellation and waits for worker exit; timeout returns false and leaves an error status for helper teardown. Catch backend exceptions only around processing, switch to CPU, clear the partial window and tracker state, increment generation, and resume with the next batch.

- [ ] **Step 7: Run coordinator and existing native tests**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); buildNativeTests('all')"
```

Expected: mailbox, metrics, CPU processing, coordinator, and existing frame tests exit `0`; CUDA selection may report skipped until Task 6.

- [ ] **Step 8: Commit**

```powershell
git add src/native/src/native_processing_coordinator.hpp tests/native/processing_coordinator_test.cpp tools/build/buildNativeTests.m
git commit -m "feat: add asynchronous native processing coordinator"
```

### Task 4: Versioned Helper and Bridge Processing Protocol

**Files:**
- Modify: `src/native/src/dvsense_helper.cpp`
- Modify: `src/native/bridge/dvsense_bridge.h`
- Modify: `src/native/bridge/dvsense_bridge.cpp`
- Modify: `tests/matlab/testBridgeSourceSafety.m`
- Modify: `tests/matlab/testNativeProtocol.m`
- Modify: `tools/build/buildBridgePrototype.m`

**Interfaces:**
- Consumes: coordinator from Task 3.
- Produces C ABI: `dvsense_processing_get_capabilities_json`, `dvsense_processing_configure`, `dvsense_processing_start`, `dvsense_processing_stop`, `dvsense_processing_reset`, `dvsense_processing_read_latest`, and `dvsense_processing_get_stats_json`.

- [ ] **Step 1: Add bridge source contract tests**

Assert the header contains all seven functions, the helper and bridge share command IDs 16 through 22, every processing response validates payload size before copying, and the result-read function accepts explicit outline and centerline capacities.

- [ ] **Step 2: Add fake-helper protocol tests**

Extend `tests/native/dvsense_fake_helper.cpp` to return a version-1 result with sequence 7, one outline point, one centerline point, backend `native-cpu`, and processing duration 750 microseconds. Verify MATLAB validation reads every field and rejects a response with a declared point count larger than the supplied payload.

- [ ] **Step 3: Run focused MATLAB tests and verify failure**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); results=runtests({'tests/matlab/testBridgeSourceSafety.m','tests/matlab/testNativeProtocol.m'}); assertSuccess(results)"
```

Expected: failures naming missing processing bridge declarations.

- [ ] **Step 4: Add protocol constants and serialization**

Assign commands 16 `PROCESSING_CAPABILITIES`, 17 `PROCESSING_CONFIGURE`, 18 `PROCESSING_START`, 19 `PROCESSING_STOP`, 20 `PROCESSING_RESET`, 21 `PROCESSING_READ_LATEST`, and 22 `PROCESSING_STATS`. Serialize little-endian fixed-width scalars and bounded point arrays. Limit every pipe response to the existing maximum response payload.

- [ ] **Step 5: Connect the SDK callback to the coordinator**

Create the coordinator after camera metadata supplies sensor dimensions. In the SDK event callback, copy the newest bounded events into `NativeEventBatch`, assign source sequence and timestamp range, publish it, then continue existing display accumulation. Start, stop, ROI change, camera stop, and camera close must call the corresponding ordered coordinator operation.

- [ ] **Step 6: Implement bridge decoding and C ABI copying**

Validate version, payload length, coordinate counts, and caller capacities before writing any caller memory. Return a distinct `has_new_result` output. Convert native zero-based points to one-based coordinates in the MATLAB adapter rather than inside the helper.

- [ ] **Step 7: Regenerate the MATLAB prototype and run protocol tests**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); buildBridgePrototype; results=runtests({'tests/matlab/testBridgeSourceSafety.m','tests/matlab/testNativeProtocol.m'}); assertSuccess(results)"
```

Expected: all source-contract tests pass; binary layout validation passes after `buildNativeTests('all')` creates its validation binaries.

- [ ] **Step 8: Commit**

```powershell
git add src/native/src/dvsense_helper.cpp src/native/bridge/dvsense_bridge.h src/native/bridge/dvsense_bridge.cpp tests/native/dvsense_fake_helper.cpp tests/matlab/testBridgeSourceSafety.m tests/matlab/testNativeProtocol.m src/matlab/+camera/+internal/dvsenseBridgePrototype.m
git commit -m "feat: expose native processing bridge protocol"
```

### Task 5: MATLAB Session Adapter and Asynchronous Application Path

**Files:**
- Create: `src/matlab/+camera/NativeProcessingResult.m`
- Create: `tests/matlab/testNativeProcessingSession.m`
- Create: `tests/matlab/testNativeProcessingAppPath.m`
- Modify: `src/matlab/+camera/DVSenseSession.m`
- Modify: `src/matlab/+camera/DVSenseCameraSource.m`
- Modify: `src/matlab/+app/run.m`
- Modify: `main.m`
- Modify: `tests/matlab/+testsupport/FakeDVSenseSession.m`

**Interfaces:**
- Consumes: processing C ABI from Task 4.
- Produces session/source methods: `configureNativeProcessing`, `startNativeProcessing`, `stopNativeProcessing`, `resetNativeProcessing`, `readLatestProcessingResult`, `getNativeProcessingStatus`, and `supportsNativeProcessing`.
- Produces configuration: `cfg.processing.execution = "native" | "matlab" | "auto"`.

- [ ] **Step 1: Write session adapter tests**

Use the fake session to verify configuration is passed once after open, start and stop follow source lifecycle, result sequences are not emitted twice, native zero-based geometry becomes MATLAB one-based geometry, and malformed versions raise `DVSense:ProcessingProtocol`.

- [ ] **Step 2: Write application path tests**

Source-inspect and fake-run the loop to verify native mode does not call `recognitionAccumulator.add` or `riserBackend.process`, MATLAB mode preserves both calls, and auto mode selects native only when capabilities report an available backend.

- [ ] **Step 3: Run tests and verify failure**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); results=runtests({'tests/matlab/testNativeProcessingSession.m','tests/matlab/testNativeProcessingAppPath.m'}); assertSuccess(results)"
```

Expected: failures naming missing session and source methods.

- [ ] **Step 4: Implement result decoding**

`camera.NativeProcessingResult.fromBridge(raw)` validates version 1, required scalar fields, finite bounded geometry, monotonic timestamps, and backend status. It returns the existing riser-result and track field names so the viewer interface remains unchanged, plus a `processingStats` struct.

- [ ] **Step 5: Implement session and source lifecycle**

Allocate fixed outline and centerline bridge buffers in `DVSenseSession` construction. Configure native processing after camera metadata and default Tool Parameters but before acquisition start. Stop native processing before vendor acquisition stop. Reset on ROI, processing configuration, stop/start, and reconnect.

- [ ] **Step 6: Split the application loop by processing mode**

Create private local functions `processMatlabBatch(packet)` and `readNativeResult()` inside `app.run`. The first contains current Recognition Window and MATLAB backend behavior. The second reads only newer native snapshots and maps them to viewer, recorder, and statistics contracts. The acquisition read remains available for event-rate statistics and MATLAB fallback; native processing does not wait for the UI cadence.

- [ ] **Step 7: Add configuration defaults**

Set `cfg.processing.execution = "auto"`, `cfg.processing.nativeBackend = "cuda"`, `cfg.processing.nativeFallback = "native-cpu"`, and `cfg.processing.deadlineUs = 1000` in `main.m`. Preserve current MATLAB backend fields for fallback.

- [ ] **Step 8: Run focused and full MATLAB tests**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); results=runtests(fullfile(pwd,'tests','matlab')); assertSuccess(results)"
```

Expected: all executable MATLAB tests pass; hardware-only tests may remain assumption-skipped for their documented missing binaries or camera.

- [ ] **Step 9: Commit**

```powershell
git add src/matlab/+camera/NativeProcessingResult.m src/matlab/+camera/DVSenseSession.m src/matlab/+camera/DVSenseCameraSource.m src/matlab/+app/run.m main.m tests/matlab/testNativeProcessingSession.m tests/matlab/testNativeProcessingAppPath.m tests/matlab/+testsupport/FakeDVSenseSession.m
git commit -m "feat: consume native processing results asynchronously"
```

### Task 6: Persistent-Buffer CUDA Backend

**Files:**
- Create: `src/native/cuda/cuda_processing_backend.hpp`
- Create: `src/native/cuda/cuda_processing_backend.cu`
- Create: `tests/native/cuda_processing_test.cu`
- Modify: `src/native/src/native_processing_coordinator.hpp`
- Modify: `tools/build/buildMex.m`
- Modify: `tools/build/buildNativeTests.m`

**Interfaces:**
- Consumes: `INativeProcessingBackend`, `NativeEventBatch`, `ProcessingConfig`, and `ProcessingResult` from Task 2.
- Produces: `CudaProcessingBackend::available()`, `process`, `reset`, and `status`.

- [ ] **Step 1: Write CUDA availability and parity tests**

On a CUDA-capable machine, process the same deterministic low, typical, and burst fixtures through native CPU and CUDA. Verify identical validity/status, bounding boxes within one pixel, mask counts within 1%, centerline median distance within two pixels, and position within two pixels. On a machine without CUDA, verify `available()` returns false with a nonempty reason and the test exits successfully after validating fallback status.

- [ ] **Step 2: Write allocation and failure tests**

Expose test-only counters under `DVSENSE_TESTING`. After backend construction and warm-up, process 100 windows and verify device-allocation count does not change. Inject a kernel failure and verify `process` throws a typed error containing the CUDA operation and error string.

- [ ] **Step 3: Run CUDA tests and verify failure**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); buildNativeTests('cuda')"
```

Expected: NVCC compile failure naming missing CUDA backend files.

- [ ] **Step 4: Implement persistent GPU storage**

Allocate device SoA arrays for maximum configured events, full-resolution recent-timestamp and polarity surfaces, mask, component statistics, and compact candidate output during construction. Allocate pinned host staging for events and outputs when `cudaHostAlloc` succeeds; otherwise use preallocated pageable memory and record the fallback in backend status. Create one nonblocking CUDA stream and reusable CUDA events.

- [ ] **Step 5: Implement accelerated stages**

Add kernels for coordinate validation and activity support, recent-event time-surface scatter with timestamp conflict resolution, temporal decay and threshold mask generation, and block-reduced mask/component statistics. Copy only compact statistics and the mask region needed by CPU continuation. Use ROI dimensions to avoid full-sensor work when software ROI is active.

- [ ] **Step 6: Integrate coordinator fallback**

Construct CUDA once when requested. Warm up with one empty/synthetic window before publishing availability. On initialization or processing exception, store the exact reason, reset processing generation, and switch to the already-constructed native CPU backend without closing the camera.

- [ ] **Step 7: Update native builds**

Compile `.cu` with the CUDA compiler discovered from MATLAB/CUDA environment, target compute capability 8.6 for the local RTX 3050 plus forward-compatible PTX, link `cudart`, and build a CPU-only helper when CUDA tooling is absent. The runtime capability JSON must distinguish build-time CUDA absence from runtime device absence.

- [ ] **Step 8: Run all native parity tests**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); buildNativeTests('all')"
```

Expected: every native test exits `0`; CUDA parity executes on the local RTX 3050.

- [ ] **Step 9: Commit**

```powershell
git add src/native/cuda/cuda_processing_backend.hpp src/native/cuda/cuda_processing_backend.cu tests/native/cuda_processing_test.cu src/native/src/native_processing_coordinator.hpp tools/build/buildMex.m tools/build/buildNativeTests.m
git commit -m "feat: accelerate native riser preprocessing with CUDA"
```

### Task 7: Workbench Diagnostics and Benchmark Reporting

**Files:**
- Create: `tools/diagnostics/benchmarkNativeProcessing.m`
- Modify: `src/matlab/+ui/WorkbenchViewer.m`
- Modify: `src/matlab/+ui/assets/status.html`
- Modify: `tests/matlab/testWorkbenchViewerContract.m`
- Modify: `tests/matlab/testProductionUiAssets.m`

**Interfaces:**
- Consumes: `processingStats` and backend status from Task 5.
- Produces: benchmark JSON and CSV files under `artifacts/output/benchmarks/<timestamp>/`.

- [ ] **Step 1: Write viewer diagnostics tests**

Publish a result with requested `cuda`, executed `native-cpu`, fallback reason, mean 900 microseconds, P95 1200, P99 1700, three deadline misses, and two dropped batches. Verify the status surface receives every value and visually distinguishes fallback and missed-deadline states without throwing or closing the viewer.

- [ ] **Step 2: Write benchmark report tests**

Feed deterministic samples into a report helper and verify JSON/CSV contain GPU name, driver, backend, warm-up count, event density, window size, sample count, mean, P50, P95, P99, maximum, deadline misses, and dropped batches.

- [ ] **Step 3: Run tests and verify failure**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); results=runtests({'tests/matlab/testWorkbenchViewerContract.m','tests/matlab/testProductionUiAssets.m'}); assertSuccess(results)"
```

Expected: new diagnostic contract assertions fail.

- [ ] **Step 4: Add low-rate diagnostic publication**

Publish diagnostic HTML data at the existing UI status cadence, not per Event Batch. Display requested/executed backend, fallback reason, current/mean/P95/P99 latency, deadline misses, dropped batches, processing generation, and last result sequence. Keep event frames in native MATLAB graphics.

- [ ] **Step 5: Implement benchmark runner**

Support fixture and live modes. Fixture mode runs low, typical, and burst deterministic inputs for 200 warm-up and 5000 measured windows per density. Live mode records 60 seconds after 5 seconds warm-up. Write one metadata JSON, one summary CSV, and one samples CSV without writing from the native processing thread.

- [ ] **Step 6: Run UI tests and a fixture benchmark**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); results=runtests({'tests/matlab/testWorkbenchViewerContract.m','tests/matlab/testProductionUiAssets.m'}); assertSuccess(results); benchmarkNativeProcessing('fixture')"
```

Expected: tests pass and a benchmark directory contains the three report files.

- [ ] **Step 7: Commit**

```powershell
git add tools/diagnostics/benchmarkNativeProcessing.m src/matlab/+ui/WorkbenchViewer.m src/matlab/+ui/assets/status.html tests/matlab/testWorkbenchViewerContract.m tests/matlab/testProductionUiAssets.m
git commit -m "feat: report native processing latency and fallback"
```

### Task 8: Production Build, Full Verification, and Acceptance Report

**Files:**
- Modify: `tools/build/buildBridge.m`
- Modify: `runtime/manifest.json`
- Modify: `docs/architecture/current.md`
- Create: `docs/releases/2026-08-20-native-processing-phase-1.md`

**Interfaces:**
- Consumes: all previous tasks.
- Produces: validated runtime bridge/helper binaries and phase-one acceptance evidence.

- [ ] **Step 1: Build production native binaries**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); buildBridge"
```

Expected: bridge and helper compile successfully, disposable `.obj/.lib/.exp` files remain outside `runtime/bin`, and the MATLAB bridge prototype is regenerated.

- [ ] **Step 2: Refresh and verify runtime hashes**

Update only the project-built `dvsense_bridge.dll` and `dvsense_helper.exe` SHA-256 entries plus `generatedAt`; vendor DLL entries remain unchanged. Run `testRuntimeLayout` and verify every manifest hash matches its file.

- [ ] **Step 3: Run all native and MATLAB tests**

Run:

```matlab
matlab -batch "run(fullfile(pwd,'tools','dev','setupPath.m')); buildNativeTests('all'); results=runtests(fullfile(pwd,'tests','matlab')); assertSuccess(results)"
```

Expected: every executable test passes; any hardware absence is an explicit assumption skip rather than a failure.

- [ ] **Step 4: Run static repository checks**

Run:

```powershell
rg -n "GPU riser kernels are not implemented|CPU fallback is active" src docs/architecture/current.md
git status --short
```

Expected: obsolete production claims are absent; only intended release documentation and refreshed binaries/hashes are modified.

- [ ] **Step 5: Run the local RTX 3050 acceptance benchmark**

Run fixture mode and, when the DVSLume is connected, the 60-second live mode. Record whether mean is at most 1.5 ms and P99 at most 3 ms for each event density. If a target is missed, the release document must identify the slowest measured stage and preserve the measured values without claiming success.

- [ ] **Step 6: Perform hardware lifecycle validation**

With the official Insight application closed, perform ten open/start/stop/restart/close cycles and a 30-minute run. Verify helper count returns to zero after close, memory remains bounded, raw recording still works, UI stalls do not increase native processing latency, and fallback status remains visible if CUDA is disabled during a separate run.

- [ ] **Step 7: Update architecture and release documentation**

Document the implemented native thread model, exact executed backend, buffer capacities, overflow behavior, reset generation, bridge version, local GPU/driver, benchmark parameters, measured mean/P95/P99/maximum, dropped batches, deadline misses, test results, and remaining fusion work.

- [ ] **Step 8: Commit the verified phase**

```powershell
git add tools/build/buildBridge.m runtime/manifest.json runtime/bin/dvsense_bridge.dll runtime/bin/dvsense_helper.exe src/matlab/+camera/+internal/dvsense_bridge_thunk_pcwin64.dll docs/architecture/current.md docs/releases/2026-08-20-native-processing-phase-1.md
git commit -m "release: complete native low-latency processing phase one"
```

- [ ] **Step 9: Confirm clean handoff**

Run:

```powershell
git status --short
git log --oneline --decorate -9
```

Expected: clean working tree and one independently reviewable commit for each completed task.
