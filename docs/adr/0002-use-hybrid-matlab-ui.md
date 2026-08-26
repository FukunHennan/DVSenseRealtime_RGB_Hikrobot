---
status: proposed
---

# Use native MATLAB rendering with HTML control surfaces

The production workbench will render the high-rate Display Frame through one
native MATLAB image object and use `uihtml` only for low-rate controls,
parameters, navigation, and status. Sending each frame through HTML would add
encoding, copying, browser memory, and latency; using only native MATLAB
controls cannot reproduce the approved official-style interface reliably.
The hybrid approach keeps the frame path efficient while accepting a small,
versioned MATLAB-to-HTML message protocol.
