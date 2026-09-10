# Tarpon diagnostic v40

## Result

No Tarpon selection or simulated fight-path bug was found. This is deterministic
domain evidence only, not a physical-phone playtest or haptic-feel verdict.
No runtime odds, fight rules, UI, package, device state, or player save was
changed.

Mangrove Flats has three live, distance-weighted candidates. Exact Tarpon odds
are 3.73557% near (`<18m`), 8.74126% mid (`18m..<30m`), and 18.98734% far
(`>=30m`). Consequently, the chance of seeing no Tarpon across 20 independent
casts is 46.70%, 16.05%, and 1.48% respectively. A near-water run can therefore
quite reasonably see no Tarpon for a long time; far casts are the intended
Tarpon-friendly habitat.

The diagnostic samples the real `FishDefinition.select_weighted` logic on a
10,000-point uniform grid per band. Results were Near: Snook 4637, Snapper
4989, Tarpon 374 (3.74%); Mid: 4476, 4650, 874 (8.74%); Far: 3437, 4664, 1899
(18.99%). It separately proves the `<18`, `18..<30`, and `>=30` boundaries via
actual `FishingSession.release_cast`, with the selection roll injected only as
an encounter input and never by overriding `game.fish`.

The complete live state path `LINE_OUT → BITE → HOOK_WINDOW → set_hook →
REELING → CAUGHT` passed for 243 cases: near/mid/far × Relaxed/Standard/Expert
× 30/60/120fps × behavior rolls 0/.37/.83 × small/ordinary/upper-tail size
rolls. The existing 300ms-delayed tension decision and 100ms rod-load ramp
landed every case. Fight times were 10.03–14.57 seconds overall: Relaxed
11.23–12.12s, Standard 10.03–14.57s, Expert 10.37–11.73s. A sustained-pull
control escaped under every challenge, distinguishing ordinary tension failure
from a selection failure. The real `SaveService.record_catch` persisted one
earned Tarpon count/best/history through an isolated run-unique cache save and
reload; repeating against the same cache passed.

Fresh runtime encounter rolls are still made per arm in `main.gd`, and
`release_cast` selects only after it has calculated cast distance. Fish size is
chosen before the fight and currently has only a small upper-tail progress
modifier; it does not move the tension zone. A moving sweet spot for hard/large
fish is a product-design option, not implemented here. If pursued, retain fixed
red failure limits, move the safe target slowly, synchronize cues to the target,
and provide reaction time.

## Evidence

- Final diagnostic: [tarpon-diagnostic-v40-domain-final2.json](../reports/tarpon-diagnostic-v40/validation/tarpon-diagnostic-v40-domain-final2.json), root `87468`, exit `0`.
- Same-cache repeat: [tarpon-diagnostic-v40-domain-repeat.json](../reports/tarpon-diagnostic-v40/validation/tarpon-diagnostic-v40-domain-repeat.json), root `50544`, exit `0`.
- Primary full regression: [primary-tarpon-v40-domain.json](../reports/tarpon-diagnostic-v40/validation/primary-tarpon-v40-domain.json), root `123492`, 44.54s, exit `0`; only established 12 ObjectDB / 5-resource teardown notices.
- Primary same-cache targeted rerun: [primary-tarpon-v40-targeted.json](../reports/tarpon-diagnostic-v40/validation/primary-tarpon-v40-targeted.json), root `114108`, 16.12s, exit `0`, no stderr marker/error/window/remaining task PID; it reproduced the same 243 cases, odds, and timing results.
- Both diagnostic runs used `E:\CodexCache\haptic-fish-tarpon-diagnostic-v40`; no Pixel was discovered, so no device save/history or physical-input claim exists.
