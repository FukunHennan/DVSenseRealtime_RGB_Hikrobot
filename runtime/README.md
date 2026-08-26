# DVSense Runtime

`runtime/bin/` is the private runtime loaded by `main.m`.

Keep `manifest.json` and this README one level above the binaries so the
runtime folder remains easy to inspect and copy.

- `runtime/bin/dvsense_bridge.dll` is the C ABI proxy loaded by MATLAB. It is
  loaded through a pre-generated MATLAB prototype under
  `src/matlab/+camera/+internal/`, so runtime operation does not parse the C
  header or invoke a compiler.
- `runtime/bin/dvsense_helper.exe` is the isolated worker that loads the
  DVSense SDK.
- The remaining DLLs in `runtime/bin` are the vendor runtime closure used only
  by the worker.
- `manifest.json` records runtime ownership, origin, license category, and
  SHA-256 fingerprints for the shipped files.

MATLAB must not load `DvsenseDriver.dll`, `DvsenseHal.dll`, or `DvsenseBase.dll`
directly. The worker process owns those libraries so a vendor SDK failure
cannot crash the MATLAB process.

The native binaries use the Microsoft Visual C++ runtime. A MATLAB
installation normally provides these runtime DLLs; on a machine where they
are absent, install the Microsoft Visual C++ 2015-2022 x64 Redistributable.

The development package copies this runtime folder as-is so another computer
has the same project-owned camera runtime closure. Compiler installations are
developer workstation tools and are not stored in `runtime/bin`.

Timing responsibilities are deliberately separate: the worker receives fixed
1 ms camera batches, the native display history is controlled by the
`事件累计时间` setting from 1 to 100 ms, and MATLAB paints at a fixed 25 Hz.
