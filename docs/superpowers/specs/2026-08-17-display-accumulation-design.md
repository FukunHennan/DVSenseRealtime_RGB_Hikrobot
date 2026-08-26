# Display Accumulation Design

## Goal

Make event-display trail length directly controllable by one explicit
accumulation-time setting while keeping camera acquisition, display refresh,
and recognition timing independent.

## Current Problem

The settings surface currently labels camera SDK batch duration as
`累积时间`. The application sends that value through `setBatchTime`, so it
changes the size of camera callback batches rather than a stable display
window.

The native display buffer clears at every SDK callback and keeps only the
latest callback batch. MATLAB calls `readDisplayFrame` on a display refresh
timer, so refresh cadence and SDK callback timing together determine what the
user sees. Recognition also uses independent fixed windows, making the visible
control misleading.

## Design

### Timing Responsibilities

| Concern | Owner | User-facing |
| --- | --- | --- |
| Camera read batch | Camera SDK/source | No, fixed at 1 ms |
| Display accumulation window | Native helper | Yes, `事件累计时间` |
| MATLAB display refresh | Application loop | No, fixed at 25 Hz |
| Recognition window | MATLAB analysis | No, kept short and independent |

### Native Display Accumulator

The helper will keep a bounded timestamped event history for display. Each
display read will construct a gray/white/black indexed frame from events whose
timestamps fall within the configured display accumulation window ending at the
newest received event.

The accumulator will:

- accept a runtime accumulation-window update;
- retain only bounded recent events;
- drop events older than the active window;
- return the latest display frame without making refresh rate define the
  accumulation duration;
- reset when the camera closes, ROI changes, or the window changes.

The existing camera event packet path remains unchanged.

### MATLAB Control Flow

The settings control will send a new `setDisplayAccumulationUs` command.
`app.run` will update the native source display window and reset the display
accumulator. `setBatchTimeUs` will no longer be exposed as the accumulation
control.

The application will keep the camera source batch duration fixed at 1 ms and
the display loop at 25 Hz. The display refresh loop will only decide when to
paint the latest frame.

Recognition state will not be reset or retuned by ordinary display
accumulation changes. ROI changes and start/stop still reset recognition and
display state together.

### UI

The `显示与刷新` group will contain:

- `事件累计时间` in milliseconds, with a visible numeric field and slider;
- no user-editable refresh-rate row.

The value will be initialized from the application display configuration and
updated from MATLAB state after each accepted command.

## Error Handling

- Clamp display accumulation to a supported range, initially 1-100 ms.
- Reject malformed or non-positive values before sending them to the helper.
- If the helper rejects an update, keep the previous value and publish a
  command error without stopping acquisition.
- Reset the native history when the value changes so old trail pixels cannot
  survive a setting change.

## Testing

Add tests for:

- native accumulation-window trimming and reset behavior;
- display-window command encoding and source forwarding;
- UI command mapping and removal of the refresh-rate control;
- changing accumulation time without changing camera batch time;
- end-to-end state reset after an accumulation-window update.

Run the MATLAB suite, compile and run the native frame-buffer regression, and
perform a real-camera discovery/open/close smoke test when the camera is free.
