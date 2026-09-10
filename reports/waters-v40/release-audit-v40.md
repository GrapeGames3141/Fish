# Waters v40 release audit

## APK

- Artifact: `build/android/Hooked-0.8.0-waters2-arm64-debug.apk`
- Size: `76,228,871` bytes
- SHA-256: `5E74F71AA442930D31ADBE391D74D71178F70D237011AB572B326370BF7587B1`
- Godot export receipt: [primary-v40-export-final.json](validation/primary-v40-export-final.json) — root `69044`, completed in 149.9 seconds.

## Package audit

- Package: `com.tak.castandcrank`; app label: `Hooked`.
- Version code `40`; version name `0.8.0-waters2`.
- minSdk `24`; targetSdk `36`; arm64-only; Android `VIBRATE` present.
- v2 signing certificate SHA-256: `c26373b2320fa530be93f5b6d255a4c8e10e6aa4476e430dedb6106a4de865dc`.
- APK ZIP audit found eight waters-v40 runtime asset imports, four water masks, and Cinzel/OFL. Forbidden report/test/doc/tool/concept/platform/original, GIF/video, local-Play-Games, and preview-import entries were absent.
- Native libraries remain compressed: `libgodot` 76,177,376 → 27,833,653 bytes; `libc++` 1,374,336 → 501,772 bytes.

## Pixel 9 Pro in-place update

- Wireless serial: `adb-45291FDAP0080L-NMUskl._adb-tls-connect._tcp` at `192.168.1.234:42939`.
- `adb install -r` succeeded and preserved the player save SHA-256 `3ddc5c9efcb9ff05e5e56215a09c305f40dd3d96c2a056f9952bf0e694103e38` before launch.
- Installed package reports code `40` with `VIBRATE` granted. Cold launch returned `Status: ok`, launched `com.tak.castandcrank/com.godot.game.GodotApp` in 628ms, and reported app PID `12206`.
- The installed `/base.apk` SHA-256 exactly matches the exported APK. PID `12206` survived repeated startup dwell checks beyond 30 seconds.
- PID-scoped log review found no fatal, Godot script, or native crash marker. It did retain three nonfatal `SurfaceSyncGroup` startup transaction timeouts and one nonfatal abandoned `BufferQueue` startup-surface warning.

## DriveFS delivery

- Local DriveFS copy: `H:\My Drive\AI Projects\Haptic Fish\Hooked-0.8.0-waters2-arm64-debug.apk`.
- The delivery helper verified `76,228,871` bytes and SHA-256 `5E74F71AA442930D31ADBE391D74D71178F70D237011AB572B326370BF7587B1` (`VerifiedTrue`). This is a verified local DriveFS copy; cloud sync completion is not claimed.

No phone screenshots, physical motion/haptic acceptance, or human aesthetic approval is claimed here.
