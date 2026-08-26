# DVSense Final UI Reference

This directory contains the visual source of truth for the next MATLAB GUI implementation.

## Files

- `dvsense_final_visual.html`: editable visual reference source.
- `README.md`: file ownership and implementation notes.

## Rendered previews

PNG exports belong in `artifacts/previews/ui-previews/final/`:

- `dvsense-final-overview.png`: full reference board.
- `dvsense-final-live.png`: live DVS workbench.
- `dvsense-final-settings.png`: official-style settings window.
- `dvsense-final-analysis.png`: contour and centerline analysis window.
- `dvsense-matlab-implementable.png`: clean MATLAB `uihtml` prototype render.
- `dvsense-matlab-analysis-open.png`: prototype with the analysis drawer open.
- `dvsense-matlab-runtime.png`: captured MATLAB runtime window.

## Implementation boundary

- `docs/design/ui/final/` is the design source and acceptance reference.
- `artifacts/previews/ui-previews/final/` contains generated previews only.
- `tests/manual/` remains for behavior-only simulation.
- `tests/manual/runDVSenseOfficialStylePreview.m` launches the MATLAB-hosted
  implementation prototype.
- Production MATLAB UI code belongs in `src/matlab/+ui/`; it must not import preview HTML.
- The final GUI remains DVS-only and keeps official event colors: gray background, white ON events, black OFF events.
- Parameter ranges and enum options must continue to come from SDK metadata.
