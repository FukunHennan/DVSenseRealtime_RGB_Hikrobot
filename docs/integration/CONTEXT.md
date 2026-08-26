# DVSense Flexible Riser Monitoring

This context covers acquisition of DVS events and the interpretation of a
flexible riser's geometry and motion.

## Language

**Camera Session**:
The exclusive ownership period in which one DVSLume is opened, configured,
started, stopped, and released.
_Avoid_: Camera connection, camera instance

**Event Batch**:
The newest bounded group of DVS events returned by one acquisition read.
_Avoid_: Frame, packet queue

**Display Frame**:
A full-resolution indexed image containing the latest visible DVS events,
using gray background, white ON events, and black OFF events.
_Avoid_: Video frame, accumulated image

**Recognition Window**:
A bounded time span of events combined for flexible-riser recognition.
_Avoid_: Display frame, camera batch

**Riser Observation**:
The geometry and confidence extracted from one recognition window, including
mask, outline, centerline, curvature, and position.
_Avoid_: Track, detection frame

**Motion Track**:
The time-continuous estimate of riser position, velocity, and motion state
derived from consecutive riser observations.
_Avoid_: Riser observation, centerline

**Tool Parameter**:
A camera setting whose name, type, range, unit, options, and current value are
reported by the DVSense SDK.
_Avoid_: GUI setting, hard-coded parameter

**Raw Recording**:
The camera-native event recording produced through the DVSense SDK.
_Avoid_: Tracking CSV, screen recording

**Run State**:
The application state indicating whether the camera session is actively
acquiring events while the workbench remains open.
_Avoid_: Window state, connection state

**Workbench**:
The collection of live-view, parameter, analysis, recording, and status
windows that observe one shared camera session.
_Avoid_: Camera session, viewer window
