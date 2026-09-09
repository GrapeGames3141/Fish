# Hooked 0.7.0-waters1

Android version code 34; signed arm64 debug build, 2026-09-09.

- New Willow Pond (Hudson Valley, NY) and Hatteras Inlet (Outer Banks, NC), each with three new fish and distinct fight/vibration profiles.
- Four region-matched waters, a scrollable location picker, and species-completion unlocks: Willow → Pine → Cedar → Hatteras.
- Catch each type in all previous waters to unlock the next. Existing v1–5 saves keep their prior lake/river access and valid progress.
- Two-page local/World Records and new-species Field Notes. Online leaderboards remain unconfigured.
- Motion-only gameplay and the visible tension meter retained. New art remains pending your aesthetic/physical-device review.

APK: `Hooked-0.7.0-waters1-arm64-debug.apk`

Size: 65,404,104 bytes (62.37 MiB), +6.93 MiB versus v33.

SHA-256: `21A788E90EB3699DB429C6380ECA6963445A2F09DBB2C0A851338E582BAF7271`

[Local APK](../../build/android/Hooked-0.7.0-waters1-arm64-debug.apk) · [Gallery](gallery/README.md) · [Full audit](delivery-audit.json) · [Feature details](../../docs/waters-v34.md)

Package `com.tak.castandcrank`; launcher label Hooked; min/target SDK 24/36; arm64-only; VIBRATE present; existing debug signer verified. ZIP audit excludes reports, tests, tools, documentation, mockups, old Cedar v03, owner config, and optional Play Games native AAR. The raw Michigan PNG is deliberately retained as the boot splash alongside its imported runtime texture.

Independent domain and import checks and signed export passed. Existing domain-only shutdown warnings remain documented. All task Godot processes/windows were cleaned up; verified task Gradle daemon 118392 was stopped.

DriveFS copy: `H:\\My Drive\\AI Projects\\Haptic Fish\\Hooked-0.7.0-waters1-arm64-debug.apk`, size/SHA-256 verified. This verifies the local DriveFS copy, not completed cloud synchronization.

Pixel install is pending: no device or mDNS endpoint was available. Send the current Wireless debugging IP/port to install without wiping the save. No phone screenshots were taken.
