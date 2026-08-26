---
status: accepted
---

# Isolate the vendor SDK behind a helper process

MATLAB communicates with a narrow project-owned C ABI bridge, and the bridge
owns one isolated helper process that loads the DVSense SDK. This avoids
loading vendor C++ runtime, USB, and SDK thread state directly into MATLAB,
contains crashes and camera ownership, and allows the bridge to force cleanup
when normal shutdown fails. The cost is a synchronous inter-process protocol
that must remain bounded and gain explicit timeouts.
