# Architecture Documents

These documents describe the current system and the approved direction for
the production hybrid MATLAB user interface.

## Current system

- `current.md`: code-verified runtime structure, data flow,
  process ownership, memory model, and known risks.

## Target system

- `structure.md`: ownership of production code, UI
  resources, tests, runtime binaries, generated artifacts, and documentation.
- `../history/specs/2026-08-15-hybrid-production-ui.md`: historical design
  for the hybrid MATLAB UI.
- `../history/plans/2026-08-15-hybrid-production-ui.md`: historical migration
  plan.

## Decisions

- `../adr/0001-isolate-vendor-sdk-behind-helper.md`
- `../adr/0002-use-hybrid-matlab-ui.md`

Documents under `docs/history/` or marked superseded are historical evidence,
not the current architecture contract.
