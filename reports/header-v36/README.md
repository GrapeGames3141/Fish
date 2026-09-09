# Continuous wood-header v36

## Screen contract

- Target: portrait 720×1280 with safe-top variants 0, 91, and 180.
- Normal fishing states (`READY`, arm, line out, bite, hook, fight, catch, escape) use the existing opaque `top-nav-rustic-v01.png` beam at one shared `Rect2(0, safe_top, 720, 108)`.
- The engraved Records, Waters, and Settings targets do not move. Records and Waters show small native locks during active fishing and retain their existing notice-only gate; Settings remains available.
- Guidance and water names are native dark-brown copy centered in the left plaque. Bites deliberately use two lines; fish identity remains hidden until the catch view.
- The tension label and bar begin below the 108px rail. Waters uses one full-width wood rail with a fixed Back action and native title; its scroll viewport begins beneath the rail and retains its prior bottom reach.

## Evidence

Validation receipts and selected 720×1280 desktop captures are retained under `validation/` and `gallery/`:

- `v36-parser-final.json` — import/parser exit 0 (root PID 76356).
- `v36-domain-final3.json` — full deterministic suite exit 0 (root PID 94952); its only stderr is the established teardown notices.
- `v36-capture-*.json` — six successful target-resolution captures: Ready, Willow line-out, two-line Bite, high-tension safe-top-180 fight, catch, and safe-top-180 Waters.
- `primary-v36-domain.json` — independent deterministic suite exit 0 (root PID 110284) with only the established teardown notices.
- `primary-v36-export.json` — signed Android export exit 0 (root PID 93064), empty stderr and no remaining task processes/windows. [Hooked-0.7.2-header1-arm64-debug.apk](../../build/android/Hooked-0.7.2-header1-arm64-debug.apk) is 65,409,743 bytes, SHA-256 `AF60708C8B836AC6E1AA3674E76FB903D013558CF12228AFA300709833D3EDA0`.

The captures prove desktop composition and geometry only. Pixel discovery was unavailable, so this checkpoint performed no device install; physical device, haptic, and human aesthetic acceptance remain pending.
