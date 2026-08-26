# C++ Fusion Preview Design

## Goal

Extend the existing single-event-camera project with the smallest useful
vertical slice for the installed hardware:

- DVSLume event camera with the 6 mm IR lens;
- Hikrobot MV-CU050-90UC RGB camera with the HN-1228-CM-C2/3B 12 mm lens;
- hardware trigger and synchronization box;
- the official DVS-RGB Fusion SDK as the native camera implementation;
- one calibrated fused image shown by the existing MATLAB application.

The first slice does not include ROI, riser recognition changes, GPU
recognition, or a new UI system.

## Architectural Decision

MATLAB remains the application manager. C++ remains the owner of the
high-frequency data plane and the vendor SDKs.

```text
MATLAB manager
  -> project C ABI bridge
  -> isolated fusion helper
  -> official DvsRgbFusionCamera<HikCamera>
      -> DVSLume SDK
      -> Hikvision MVS SDK
```

MATLAB must not load MVS or DVSense vendor DLLs directly and must not own
SDK callback threads. The helper owns discovery, opening, trigger setup,
streaming, bounded buffers, calibration warp, and fused-frame production.

The official Fusion SDK is treated as the source of camera and synchronization
semantics. Project code wraps it with a stable helper protocol, bounded state,
validation, and cleanup rather than copying the demo's UI loop into MATLAB.

## First Vertical Slice

The native helper will:

1. discover DVS and Hikvision devices;
2. open the selected serial numbers;
3. configure the Fusion SDK for the requested stream mode;
4. start `FUSION_STREAM`;
5. receive DVS events and RGB frames through native callbacks;
6. use the trigger relationship to associate an RGB frame with the event
   timing;
7. warp the RGB frame into the DVS 1280 x 720 coordinate system using the
   configured calibration file;
8. overlay the current event image;
9. retain the newest fused frame in a bounded native buffer;
10. expose the frame and synchronization status through the project bridge.

MATLAB will:

1. load and validate the project configuration;
2. send normalized camera and fusion settings to the helper;
3. manage start, stop, close, and recovery;
4. read the newest fused frame at the display cadence;
5. render that frame through the existing viewer;
6. show basic device and synchronization status.

The existing MATLAB event recognition path remains unchanged during this
slice. Event batches may continue to be exposed for later recognition
integration, but they are not required for the first visible fused frame.

## Data Contract

The first bridge contract needs these logical operations:

```text
discoverFusionDevices
openFusion(dvsSerial, rgbSerial, fusionConfig)
startFusion
readLatestFusionFrame
readFusionStatus
stopFusion
closeFusion
```

The latest frame response contains:

```text
frame: uint8 BGR/RGB image
width: uint32
height: uint32
timestampUs: uint64
sequence: uint64
```

The status response contains:

```text
dvsConnected
rgbConnected
running
syncValid
timestampDeltaUs
rgbFrameRate
droppedRgbFrames
eventRate
fusionLatencyUs
calibrationValid
lastError
```

The first implementation may continue using the existing synchronous bridge
request model. A shared-memory frame transport is deferred until profiling
shows that copying a 1280 x 720 frame at the display cadence is a real
bottleneck.

## Configuration

The project will move machine-dependent values out of `main.m`.

```text
config/default.json
config/local.example.json
config/local.json
config/camera-profile.json
```

`local.json` contains computer-specific SDK paths, runtime paths, serial
preferences, and output paths. `camera-profile.json` contains the installed
camera and lens identity, trigger assumptions, calibration file, and fusion
output geometry. The MATLAB manager merges and validates these files, expands
`${PROJECT_ROOT}`, and sends a normalized configuration to C++.

The helper validates the native subset again. MATLAB remains the source of
application configuration, but the helper must reject missing paths, invalid
serial selections, unsupported stream modes, and invalid calibration files.

## Lifecycle and Error Handling

The normal lifecycle is:

```text
created
  -> discovered
  -> opened
  -> configured
  -> running
  -> stopped
  -> closed
```

The helper must report failures without taking down MATLAB. MATLAB must be
able to close the helper after:

- partial device discovery;
- RGB opened but DVS failed;
- DVS opened but RGB failed;
- trigger setup failure;
- calibration load failure;
- helper process exit;
- user stop before the first fused frame.

The helper must keep event and RGB buffers bounded. The first slice always
prefers the newest complete fused frame over preserving an unbounded queue.

## Testing Strategy

Before hardware integration, tests cover:

- configuration merge and path expansion;
- configuration validation;
- fusion status and frame response shape;
- helper protocol error responses;
- cleanup after partial open;
- bounded latest-frame replacement.

Native hardware validation is a separate manual test:

1. connect the synchronization box and both cameras;
2. run the official Fusion SDK Hikvision example;
3. confirm both devices open;
4. confirm `FUSION_STREAM` produces RGB and event callbacks;
5. confirm the calibration file produces a correctly aligned image;
6. run the project helper and confirm MATLAB displays the fused frame;
7. stop and restart repeatedly;
8. verify no helper process or camera lock remains.

## Out of Scope

The first slice does not change:

- ROI behavior;
- riser segmentation and centerline extraction;
- MATLAB GPU recognition;
- the final production UI layout;
- RGB-assisted recognition;
- long-term recording format;
- automatic calibration generation.

Those features follow only after the fused-frame path is visible and stable.
