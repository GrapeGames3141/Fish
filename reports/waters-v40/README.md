# Waters v40 evidence index

- `source-atlases/`: original generated RGBA sheets retained for provenance and
  excluded from Android export.
- `atlas-qa/`: light/dark alpha-repack review composites.
- `mask-qa/`: conservative water-mask overlays against the selected plates.
- `validation/`: deterministic helper receipts. The initial domain failure is
  retained as superseded diagnostic evidence; consult `docs/waters-v40.md` for
  current acceptance and approval state.
- [Primary helper receipt index](primary-helper-receipts.md) lists every
  completed primary v40 capture/check receipt and its adjacent PID snapshot.
- [Release audit](release-audit-v40.md) records the completed export, Pixel
  dwell/log review, and verified local DriveFS copy while keeping cloud-sync
  and human/physical acceptance limits explicit.

No cloud-sync completion, human visual approval, or physical-play-feel approval
is implied by these source-side artifacts.

Primary independent domain validation passed (`primary-v40-domain-final`, root
`125304`, 43.7 seconds). Six 32-frame 8fps motion clips confirmed exact-still
header/dry ROIs, bounded live-water differences, and whole-frame exact-still
Moonlit/Offshore Reduced Motion; raw frames remain in the isolated E: cache.
