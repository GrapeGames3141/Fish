# Cast & Crank — Gate 1 GDD

Cast & Crank is a tactile freshwater fishing game for a phone held flat on the palm. Pick a location, cock back and snap forward to cast, feel a bite, tilt back to set the hook, then circle a finger clockwise on the reel while managing tension.

Gate 1 includes Pine Lake and Bluegill only. The finished loop uses `READY → CAST_ARMED → LINE_OUT → BITE → HOOK_WINDOW → REELING → CAUGHT|ESCAPED`. Bluegill fights lightly, bites after 2.4 seconds, and measures 14–31 cm. Pine Lake’s later family is Bluegill, Largemouth Bass, and Channel Catfish; Cedar River (later) contains Rainbow Trout, Smallmouth Bass, and Northern Pike.

The slice favors accessible, forgiving timing: 1.5 seconds to hook and 1.25 continuous seconds in red tension before loss. Touch/keyboard fallback keeps the game reviewable without sensors. Future location selection and collection screens are intentionally deferred until the Gate 1 direction is approved.

Eyes-up haptics communicate the fight without requiring the player to stare at a meter. The bite is a two-pulse cue and a successful hook gives one short confirmation before the first fish phrase begins. Each planned fish definition has its own pulse phrase and phrase cadence with deliberate quiet space; in this Gate 1 runtime, Bluegill is the active specimen. Tension at 65% overrides species rhythm with a universal high-warning cadence, and 90% uses a faster universal urgent red-warning cadence; lowering tension restores the fish rhythm. A caught fish gives a three-part lift cue, while an escape is a single low cue. Disabling haptics stops and clears all queued feedback. These six signatures are data and test coverage only until future locations and species pass content approval.
