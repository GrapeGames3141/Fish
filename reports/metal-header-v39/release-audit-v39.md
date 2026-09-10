# Hooked 0.7.5-sign1 release audit

- [APK](../../build/android/Hooked-0.7.5-sign1-arm64-debug.apk): `65,518,255`
  bytes; SHA-256
  `C0FDCE844EC93541CEFE5A0C062ECF105E8C2B56B0AFDF695F5F0EFE877650F9`.
- Export retry [`primary-v39-export-retry`](validation/primary-v39-export-retry.json)
  ran `20:40:26–20:43:20` on 2026-09-09, exited 0, and has no stderr marker
  or remaining task processes/windows. The idle, project-owned Gradle daemon
  `80032` was explicitly stopped after the export; final Godot/Java/aapt2/
  WerFault inventory was empty.
- `aapt` confirms `com.tak.castandcrank`, code `39`, name `0.7.5-sign1`,
  min SDK `24`, target SDK `36`, arm64 only, and `VIBRATE` present.
- `apksigner` verifies v2 signing with the established debug certificate
  SHA-256 `c26373b2320fa530be93f5b6d255a4c8e10e6aa4476e430dedb6106a4de865dc`.
- Package audit confirms the Cinzel font and exact unmodified OFL license are
  present; no reports, tests, docs, tools, concepts, screenshots, builds,
  GIF/MP4 evidence, or private configuration leaked into the APK. Details are
  machine-readable in [package-audit-v39.json](package-audit-v39.json).

## Pixel 9 Pro install

The paired wireless Pixel 9 Pro was updated in place from v37 with `adb install
-r`. Only Hooked was force-stopped before the update; no uninstall, data clear,
or Drive delivery occurred. The existing save file
`files/cast_and_crank_save.json` had identical pre/post SHA-256
`3ddc5c9efcb9ff05e5e56215a09c305f40dd3d96c2a056f9952bf0e694103e38` before
launch. `VIBRATE` remains granted. The standard launcher cold-start completed
with `Status: ok`, `TotalTime: 2035ms`, and app PID `9381`.

The app PID was still present about 30 seconds later, and the installed
`base.apk` SHA-256 matches the release APK. The app-only log has no Godot script
error, AndroidRuntime fatal, or native crash marker. It does contain one
nonfatal GodotAppLauncher `BufferQueueProducer` message saying its buffer queue
was abandoned, so this is not presented as an error-free log. The complete
install facts are in [pixel-install-v39.json](pixel-install-v39.json); this
receipt does not claim human device visual/performance review, physical motion,
haptic feel, or broader gameplay acceptance.
