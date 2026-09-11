# Hooked 0.8.2-dock1 delivery note

APK: `Hooked-0.8.2-dock1-arm64-debug.apk`  
Bytes: `76,232,403`  
SHA-256: `A42B7F57E9D2ACB4A760613EA5589A2582FF47BE99D48DBD8B88C9A0B969CB75`

This signed arm64 debug build contains the Moonlit Reservoir dock/post water
mask repair. The embedded imported Moonlit mask SHA-256 is
`954ECE73BBE5DAAD82DBD497B029B9C072B5065169C217B95906FECA2DFE86BC`, matching
the current local `.ctex` exactly.

Package audit: `com.tak.castandcrank`, visible name **Hooked**, code `42`,
version `0.8.2-dock1`, min/target SDK `24/36`, arm64 only, `VIBRATE` present,
and APK Signature Scheme v2 valid with the existing debug certificate
`c26373b2320fa530be93f5b6d255a4c8e10e6aa4476e430dedb6106a4de865dc`.
The 868-entry APK contains the required Moonlit imported mask and no
reports/tests/docs/tools/concepts/platform/mockup/preview/video or local Play
Games owner payload.

Primary delivery evidence: Pixel 9 Pro in-place update succeeded while
preserving the player save hash; cold launch entered the Godot main loop and
remained alive for about 40 seconds. The APK was copied to
`H:\My Drive\AI Projects\Haptic Fish\Hooked-0.8.2-dock1-arm64-debug.apk` with
matching byte count and SHA-256 (`VerifiedTrue`); this verifies the local
DriveFS copy, not cloud synchronization. No phone screenshot was taken.

The launch log had no fatal/native/script/parse markers. It retained nonfatal
Chromium seed-signature and ads dynamic-lookup warnings. Motion telemetry in
that window is not a physical-feel or untouched-device acceptance claim;
human visual and motion/haptic play evaluation remain separate.
