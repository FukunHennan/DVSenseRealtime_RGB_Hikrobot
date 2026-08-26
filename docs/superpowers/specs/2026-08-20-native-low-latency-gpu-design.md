# Native Low-Latency GPU Processing Design

Date: 2026-08-20

## Objective

Move the latency-critical flexible-riser processing path from the synchronous
MATLAB application loop into the isolated native helper, using CUDA where it
improves measured latency. Preserve the MATLAB workbench as an asynchronous
observer and controller.

The first phase uses the current DVSLume and the local RTX 3050 Laptop GPU as a
conservative validation platform. It does not require the future Hikvision RGB
camera, but its native protocol and result model must leave a clean extension
seam for synchronized RGB and fusion products.

## Success Criteria

The latency clock starts when a completed DVS Event Batch becomes visible to
the helper processing thread and stops when the corresponding tracking result
is published to the latest-result buffer. Camera transport time and MATLAB UI
refresh are reported separately and are not part of this processing latency.

Required first-phase results:

- no unbounded queue or buffer growth;
- no acquisition callback waiting for CUDA, recognition, MATLAB, or display;
- deterministic overflow policy: newest data replaces stale unpublished data;
- numerical and geometric agreement with the existing MATLAB CPU reference on
  deterministic fixtures;
- mean processing latency at or below 1.5 ms where the local hardware and event
  density permit it;
- P99 processing latency at or below 3 ms where the local hardware and event
  density permit it;
- per-stage timing and an explicit bottleneck report whenever either latency
  target is missed;
- existing MATLAB CPU processing remains available as a runtime fallback.

The aspirational target is processing as close to 1 ms as practical. The
design does not claim hard real-time scheduling on Windows.

## Architecture

The production ownership chain remains singular:

```text
MATLAB workbench
  -> project C ABI bridge
  -> isolated helper process
  -> DVSense SDK
  -> one DVSLume
```

The helper gains an internal real-time pipeline:

```text
DVS SDK callback
  -> fixed-capacity latest Event Batch buffer
  -> native processing thread
  -> CPU/CUDA processing backend
  -> fixed-capacity latest Processing Result buffer
  -> bridge snapshot read
  -> MATLAB workbench
```

MATLAB never schedules individual native processing stages. It reads the newest
complete snapshot and may skip stale snapshots. UI refresh, recording, and
command handling must not block acquisition or native processing.

## Native Modules

### Acquisition Adapter

The existing DVSense SDK callback remains the only module that consumes vendor
event iterators. It copies validated events into a preallocated structure-of-
arrays buffer and publishes the batch with one sequence number and its source
timestamp interval.

The callback performs no filtering, image construction, allocation, CUDA
synchronization, recording I/O, or UI work.

### Latest Event Batch Mailbox

The mailbox owns two or three fixed-capacity slots. A producer publishes only a
fully written slot. The consumer takes the newest complete slot. If processing
falls behind, an older unprocessed slot is overwritten and a dropped-batch
counter is incremented.

This is deliberately latest-only, not a lossless queue. Raw Recording continues
through the vendor SDK and is independent of recognition delivery.

### Native Processing Coordinator

One dedicated native thread consumes Event Batches, constructs Recognition
Windows, selects a backend, publishes results, and records stage timing. It owns
all mutable recognition and tracking state so reset, ROI change, stop, and
restart remain ordered operations.

Control changes are passed through a bounded command mailbox. Commands that
change geometry or time semantics cause an ordered processing reset before the
next result is published.

### Processing Backends

Both backends implement the same internal interface:

```text
process(RecognitionWindow, ProcessingConfig) -> ProcessingResult
reset()
status() -> BackendStatus
```

The native CPU backend is the correctness reference and fallback. The CUDA
backend initially accelerates the stages with the clearest data-parallel value:

1. activity filtering;
2. temporal event-image/time-surface construction;
3. thresholding and mask generation;
4. mask statistics needed to select candidate regions.

Contour ordering, centerline extraction, motion estimation, and Kalman tracking
remain on CPU in the first implementation unless profiling demonstrates that
they prevent the latency targets. This limits the first CUDA scope and avoids
GPU transfers for small serial workloads.

GPU memory is allocated during backend initialization. Per-window CUDA memory
allocation is forbidden. Event input uses pinned host buffers where supported,
one persistent stream, and asynchronous copies. The coordinator synchronizes
only at the point where CPU continuation requires GPU output.

### Latest Processing Result Mailbox

Each published snapshot contains:

- monotonically increasing source and result sequence numbers;
- Event Batch and Recognition Window timestamp ranges;
- validity, status, reason, and backend state;
- position, velocity, acceleration, confidence, and bounding box;
- bounded outline and centerline point arrays;
- event and mask diagnostic counts;
- acquisition-to-processing queue age when measurable;
- processing total, stage durations, rolling P50/P95/P99, deadline misses, and
  dropped Event Batch count.

Readers receive one internally consistent snapshot. If MATLAB reads slowly, it
receives the newest snapshot without delaying the producer.

## Bridge Interface

The existing camera and display functions remain compatible. New C ABI
functions expose versioned native-processing capabilities rather than leaking
CUDA implementation details:

```text
dvsense_processing_get_capabilities_json
dvsense_processing_configure
dvsense_processing_start
dvsense_processing_stop
dvsense_processing_reset
dvsense_processing_read_latest
dvsense_processing_get_stats_json
```

`dvsense_processing_read_latest` uses caller-owned bounded arrays and a
versioned fixed-layout header. It reports whether a newer result exists; absence
of a new result is not an error. All array capacities are supplied by the caller
and validated before copying.

The capability response distinguishes requested, available, and executed
backends. A CUDA initialization or execution failure changes the executed
backend to native CPU, records the reason, resets processing state, and keeps
the Camera Session alive.

## MATLAB Integration

`app.run` stops building Recognition Windows or invoking MATLAB riser analysis
when native processing is active. It continues to own lifecycle, user commands,
recording commands, and the workbench.

At UI cadence, MATLAB reads:

- the latest native display frame;
- the latest Processing Result snapshot;
- native latency and drop statistics.

The existing MATLAB analysis path remains selectable through configuration and
serves as a fallback and validation oracle. Runtime status must show all three
states separately: requested backend, executed backend, and fallback reason.

## Future DVS/RGB Fusion Seam

The first phase does not load the Hikvision SDK. It reserves these concepts in
the native result model without adding unused bridge calls:

- a common hardware-trigger timestamp domain;
- source identifiers for DVS and RGB products;
- independently versioned latest DVS frame, latest RGB frame, and latest fused
  frame snapshots;
- calibration identity and spatial transform version;
- temporal match error for each fused product.

When the Hikvision camera and synchronization box are available, the native
helper will add an RGB acquisition adapter and a fusion coordinator. RGB uses a
latest-only buffer. A fusion product selects the RGB frame and DVS window with
the closest valid hardware-trigger timestamps, then applies the calibrated
homography. MATLAB will display DVS and RGB side by side plus a fused view at
30–60 FPS. None of those display products enters the 1 ms DVS processing
budget.

## Error Handling and Lifecycle

- Partial helper initialization closes all initialized resources in reverse
  ownership order.
- CUDA failure falls back to native CPU without closing the camera.
- Vendor SDK or pipe failure remains a Camera Session error and follows the
  existing reconnect workflow.
- Processing reset invalidates unpublished Recognition Windows and tracking
  state, increments a reset generation, and prevents pre-reset results from
  being published afterward.
- Stop joins the processing thread with a bounded timeout before camera and
  helper teardown.
- Every native wait remains bounded; timeout errors identify the stage and
  retain the last complete diagnostic snapshot.

## Performance Measurement

Native timing uses a monotonic high-resolution CPU clock. CUDA stages use CUDA
events so asynchronous kernel time is not confused with CPU submission time.
Metrics are collected in fixed-capacity rolling storage with no logging or disk
I/O on the processing thread.

Benchmarks cover at least low, typical, and burst event densities. Reports must
include warm-up policy, batch/window sizes, GPU name, driver, backend, event
density, mean, P50, P95, P99, maximum, deadline misses, and dropped batches.

MATLAB-to-screen latency is measured separately because a 30–60 FPS display has
a natural 16.7–33.3 ms presentation interval. Display quality is optimized by
using the latest complete DVS, RGB, and fusion snapshots, not by coupling UI
refresh to the processing deadline.

## Verification

### Native tests

- mailbox publication never exposes partially written data;
- overflow retains the newest batch and increments the counter;
- reset generation prevents stale result publication;
- fixed-layout bridge copies honor all caller capacities;
- CPU and CUDA backends produce contract-equivalent results;
- CUDA failure activates CPU fallback with a visible reason;
- synthetic performance benchmark emits all required percentiles.

### MATLAB tests

- native result parsing and geometry use full-resolution coordinates;
- `app.run` does not execute MATLAB recognition when native processing is
  active;
- fallback restores the existing MATLAB path without changing viewer
  interfaces;
- stop/start, ROI, display accumulation, and Tool Parameter behavior remain
  compatible;
- UI shows requested/executed backend and latency/drop diagnostics.

### Hardware validation

- repeated open/start/stop/close cycles;
- a minimum 30-minute acquisition run with bounded memory;
- low, normal, and burst event-density latency runs;
- comparison of recorded native results with the MATLAB CPU reference;
- confirmation that UI stalls do not increase native processing latency or
  block event acquisition.

## Delivery Sequence

1. Add native timing, benchmark fixtures, and a CPU processing contract.
2. Add latest Event Batch and Processing Result mailboxes.
3. Implement native CPU reference stages and compare with MATLAB fixtures.
4. Extend the C ABI and MATLAB session adapter for latest results and stats.
5. Switch `app.run` to the optional native asynchronous path.
6. Add persistent-buffer CUDA stages and CPU fallback.
7. Profile, tune, and publish the acceptance report.
8. After Hikvision hardware arrives, design and implement the separate RGB and
   fusion extension against the reserved seam.

## Out of Scope for Phase One

- loading or controlling the Hikvision SDK;
- RGB spatial calibration UI;
- production DVS/RGB fused rendering;
- hard real-time guarantees on Windows;
- removal of the existing MATLAB CPU reference path;
- GPU acceleration of stages that profiling does not identify as useful.
