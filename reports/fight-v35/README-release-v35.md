# Hooked 0.7.1-balance1

Signed arm64 Android debug build, version code 35, 2026-09-09.

- Keep tension in the middle: sustained slack lets the fish shake free; excessive tension snaps the line.
- Relaxed / Standard / Expert change the danger bands. Settings changes apply to the next cast.
- Slow long-plus-tap feedback means pull; rapid paired warnings mean ease. Species feedback remains distinct in the safe zone.
- The rod visibly pulls back under load and relaxes when eased. Both red ends and the green target remain visible.
- Independent 5–14 second bite waits and passing fish shadows replace the near-instant, guaranteed approach-to-bite sequence.

[APK](../../build/android/Hooked-0.7.1-balance1-arm64-debug.apk) · [Rendered gallery](gallery/README.md) · [Fight timings](README.md) · [Delivery audit](delivery-audit.json)

Size: 65,409,731 bytes (62.38 MiB), just 5,627 bytes larger than v34.

SHA-256: `932F7D92399D6FDEE66EBB847C80F3C52C740AEB6BD588CC3EF9FBED65955079`

Package `com.tak.castandcrank`, existing debug signer retained, min/target SDK 24/36, arm64-only, VIBRATE present. The APK contains the compiled challenge profile and excludes tests, reports, tools, documentation, mockups, and private Play Games configuration. Production-source hashes match the verified export.

Independent import, full domain regression suite, and signed export passed. The suite covers twelve fish, three challenge levels, three frame rates, three behavior rolls, and two delayed responsive policies. Standard ordinary reactive fights measured 10.66–19.50 seconds. The established domain-only teardown notices remain; import/export stderr is empty. All task Godot processes and the verified export Gradle daemon were cleaned up.

DriveFS: `H:\My Drive\AI Projects\Haptic Fish\Hooked-0.7.1-balance1-arm64-debug.apk`; byte count and SHA-256 verified. This verifies the local DriveFS copy, not completed cloud synchronization.

Pixel installation is pending because ADB and mDNS found no device. No phone screenshots were taken. Physical motion and vibration feel remain a user/device playtest gate.
