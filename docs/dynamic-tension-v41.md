# Dynamic tension v41

## Scope

The tension target is now a deterministic live profile during a fight. The cast
snapshots one immutable `challenge_profile`; `live_challenge_profile` is derived
from it every fight tick and is shared by the domain, tension meter, glance hint,
landing reward, red exposure dwell, and haptic warning tier. Settings cannot
alter an active cast.

For weak, ordinary fish the dynamic intensity is zero and the profile remains
the base profile. For stronger and upper-tail fish, deterministic behavior/time
waves can move the center, narrow the green zone, and grow or shrink both red
ends. There is no per-frame random selection or scripted loss.

## Bounds and pacing

- The initial challenge baseline remains unchanged through startup grace.
- A 2.4-second smooth blend begins after grace; reset and re-hook return to the
  baseline. `tick(0)` does not advance the profile.
- All live profiles maintain `0 < low critical < low warning < center < high
  warning < high critical < 1`, warning buffers of at least `0.085`, and a
  green width of at least `0.24`.
- Large Expert Tarpon observed from the deterministic fixture: center span
  `6.89` points; green width `24.32–29.24` points; low critical span `5.31`
  points; high critical span `9.50` points.
- The all-phase strongest-fish sweep measured maximum live-edge speed
  `0.06625` tension/sec (6.63 percentage points/sec), below the `0.085`
  response budget. This leaves the established 300ms decision + 100ms load
  ramp meaningful.
- Red failure remains dwell based; a moving edge begins normal high/slack
  exposure, never an instant failure. Center reward peaks at the live center
  and uses live green width.

## UI and capture fixtures

The meter draws the live red/orange/green bounds and a live-center tick. The
steady hint is **HOLD THE GREEN**. Reduced Motion freezes only decorative water
and rod motion; fight boundaries still use the changing live profile.

Named deterministic visual fixtures use production
`refresh_live_challenge_profile()` after the blend window:

- `tarpon_large_standard_wide`, `tarpon_large_standard_narrow`,
  `tarpon_large_standard_drift_left`, `tarpon_large_standard_drift_right`
- `tarpon_large_expert_wide`, `tarpon_large_expert_narrow`,
  `tarpon_large_expert_safe180`, `tarpon_large_expert_reduced`
- `bluegill_baseline`

They seed no player save or unlock. They are still phases, not a claim that a
capture-frame run animates fight time.

## Validation

- Focused deterministic final: `v41-dynamic-focused-final`, root PID `123044`,
  exit `0`, no helper stderr marker/window/remaining process. It checked 5,184
  fish/profile/size/behavior/time combinations, pause/FPS stability, profile
  immutability, both dynamic red exposures, moving-center reward, and haptic
  tier/cancellation parity.
- Full regression: `v41-domain-full-final`, root PID `125876`, exit `0` in
  59.21 seconds. The standard responsive maximum prints
  `20.0000000000001` from frame accumulation; the test uses a `1e-6` numeric
  comparison tolerance, not a duration-cap increase. Established teardown
  notices remain: 12 ObjectDB instances and 5 resources.
- Tarpon live-cue regression: `v41-tarpon-livecue-final`, root PID `68428`,
  exit `0` in 16.39 seconds. All 243 simulated lifecycle cases caught in
  `10.51–14.63s`; this is deterministic simulation, not physical play.

Receipts and stdout/stderr are under
`reports/dynamic-tension-v41/validation/`.

- Final import/parser: `v41-import-final`, root PID `126548`, exit `0`, no
  helper stderr marker, cleanup PID, remaining task process, or window.

## Delivery and physical-feel gate

Primary focused/domain/export checks passed: roots `123844`, `120872`, and
`96096`, respectively. The nine named desktop stills were visually reviewed:
the dynamic meter is readable, its center/green width/both red ends visibly
change, and the Safe-180 and Reduced Motion variants remain usable.

The signed local APK is
`build/android/Hooked-0.8.1-tension1-arm64-debug.apk` (76,232,563 bytes,
SHA-256 `6A400B3298C3C83C7300B37AAC7531280D9ADD63B37EE136C08696A65C75F951`).
Audit confirms package `com.tak.castandcrank`, label `Hooked`, code `41`,
version `0.8.1-tension1`, SDK `24/36`, arm64-only, `VIBRATE`, and valid APK v2
signature with certificate SHA-256
`c26373b2320fa530be93f5b6d255a4c8e10e6aa4476e430dedb6106a4de865dc`.
All eight water scenes/atlases/masks and Cinzel OFL remain present; excluded
development content is absent from the 868-entry APK. Android generated files
were hash-unchanged from the pre-export baseline.

The initial desktop delivery did not install, copy to Drive, or push remotely.
A subsequent user-requested [Pixel install](../reports/dynamic-tension-v41/pixel-install-v41.md)
succeeded and preserved the save. Android later reported task removal, with a
native error during engine shutdown; sustained runtime stability and physical
feel remain unverified. No Drive copy or remote push occurred.

### Read-only header follow-up

The `bluegill_baseline` still uses the same `_top_location_title_rect()` as
Mangrove (`y + 30`, height `31` in active fishing). Its short title receives a
larger auto-fit metal font than `MANGROVE FLATS`, making it appear closer to the
top grain; this is pre-existing shared header/font-size behavior, not a dynamic
tension regression. It is recorded for later header polish and was not changed
in this scope.

Automated evidence cannot validate whether the moving sweet spot, growing red
zones, haptic phrasing, or motion response feel fair in-hand. Pixel installation
is complete; human physical-feel acceptance and the observed shutdown error
remain open.
