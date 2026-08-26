# Project Structure

The project keeps editable source, runtime dependencies, tests, tools, and
generated output in separate top-level areas so the whole folder can be moved
without rebuilding the source layout.

```text
DVSenseRealtimeV1/
|- README.md
|- CONTEXT.md
|- VERSION
|- main.m
|- 启动开发版.bat
|- 启动运行版.bat
|- config/
|- src/
|  |- matlab/
|  |  |- +app/
|  |  |- +camera/
|  |  |- +analysis/
|  |  `- +ui/
|  `- native/
|     |- bridge/
|     |- src/
|     `- cuda/
|- runtime/
|  |- bin/
|  |- manifest.json
|  `- README.md
|- tests/
|  |- matlab/
|  |- native/
|  |- manual/
|  `- fixtures/
|- tools/
|  |- build/
|  |- dev/
|  |- diagnostics/
|  `- package/
|- docs/
`- artifacts/
   |- build/
   |- output/
   `- previews/
```

## Package Ownership

`src/matlab/+app` owns lifecycle and orchestration. It is the only package
that wires camera acquisition, analysis, recording, and the viewer together.

`src/matlab/+camera` owns discovery, exclusive Camera Session ownership,
DVSense SDK bridge access, Tool Parameter validation, and raw recording control.

`src/matlab/+analysis` owns event-window construction, filtering, measurement
backends, riser geometry extraction, motion tracking, and tracking-result
recording. Low-level riser functions live under `+analysis/+riser`.

`src/matlab/+ui` owns MATLAB windows, HTML control surfaces, command
translation, and display overlays. It does not own a camera session.

`src/native` contains editable C++ bridge, helper, and CUDA source. Compiled
DLL/EXE files belong only in `runtime/bin`.

## Root Directory Contract

The project root is intentionally strict. It may contain only:

- launch and project metadata files: `main.m`, `启动开发版.bat`,
  `启动运行版.bat`, `README.md`, `CONTEXT.md`, and `VERSION`;
- the first-level directories listed above.

Generated objects, import libraries, thunk build intermediates, MATLAB logs,
recordings, and previews must never be written to the root. Build staging uses
the system temporary directory, compiled validation output uses
`artifacts/build`, and development packages use `artifacts/packages`.

The MATLAB bridge interface is a special runtime source asset:
`src/matlab/+camera/+internal/` may contain only
`dvsenseBridgePrototype.m` and `dvsense_bridge_thunk_pcwin64.dll`. Its
development `.obj`, `.lib`, and `.exp` files are disposable and are not part
of the source layout.

## Development Package

`tools/package/createDevelopmentPackage.m` creates
`artifacts/packages/DVSenseRealtimeV1-dev.zip` for moving active development to
another computer. The package root is `DVSenseRealtimeV1-dev/` and contains the
same disciplined source layout as the working tree:

- MATLAB source under `src/matlab/`;
- native source under `src/native/`;
- runtime dependencies under `runtime/bin/`;
- tests under `tests/`;
- build, diagnostic, and packaging tools under `tools/`;
- documentation under `docs/`.

The development package keeps project-owned and redistributable runtime
dependencies together. It does not include a C++ compiler installation,
MATLAB preferences, build logs, recordings, generated previews, or native
build intermediates.

## Generated Files

Build objects, MEX intermediates, recordings, logs, and UI previews belong
under `artifacts/`. The development package creator deliberately excludes
build intermediates from this directory.

## Test Layout

MATLAB tests live under `tests/matlab`, native tests under `tests/native`,
manual previews under `tests/manual`, and deterministic input files under
`tests/fixtures`.
