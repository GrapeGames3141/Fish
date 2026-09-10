# v39 desktop header review

These are actual 720×1280 Godot captures of the current source, not phone
screenshots or regenerated art. The existing rustic beam and its three icon
plaques are unchanged; the review isolates native text ownership and safe-area
layout.

- [Quiet Hatteras line-out](dark-line-out.png) — centered dark-gunmetal
  `HATTERAS INLET` sign only; no habitat/channel or cast-distance copy.
- [Ready at safe top 91](dark-ready-safe91.png) — separate title and one-line,
  high-contrast motion instruction on the same wood plaque.
- [Fight at safe top 180](dark-fight-safe180.png) — title/hint remain readable,
  fixed nav targets remain in their authored positions, and the live tension
  meter clears the rail.
- [Hatteras catch](dark-catch-final.png) — offscreen fixture confirmation that
  the approved dark header coexists with the catch reveal's 61.6 cm fish-size
  result and no cast-distance caption.

Each capture has its exact command, root PID, clean stderr marker, and cleanup
inventory in the adjacent [`../validation`](../validation) receipt set:
`primary-v39-dark-line-out` (PID 70844),
`primary-v39-dark-ready-safe91` (PID 100004), and
`primary-v39-dark-fight-safe180` (PID 107616), plus the offscreen
`primary-v39-dark-catch-offscreen` capture (PID 58408).

The unprefixed `line-out.png`, `ready-safe91.png`, and `fight-safe180.png`
were earlier light-pewter captures and are retained only as superseded process
evidence. `dark-catch.png` is excluded: it cleanly exited but unexpectedly
captured Settings; suspected desktop-input interference was not traced, so it
is not a catch validation image.
