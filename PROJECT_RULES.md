# Project Rules

- Target Godot 4.7.1, GDScript, Android portrait 720×1280, package `com.tak.castandcrank`.
- Maintain a deterministic domain layer with replaceable motion, save, and ad adapters.
- Gate 1 uses code-native geometry/UI only. `concepts/gate1` is review-only and pending approval.
- Poing AdMob v5.0.0 is MIT-licensed local source. Use Google test IDs until production IDs, privacy policy, UMP review, and store disclosures are supplied.
- For a native `AdPosition.BOTTOM` banner outside the Godot surface: native owns banner and Android safe inset; `game_content_reserve_height()` is always zero. Synthetic overlay reserve is a test-only fixture.
- General audience is 13+, max ad content rating PG, not child-directed. UMP consent must run before requesting production ads.
- After consent, enter `sdk_initializing` and wait for Poing's one-shot initialization callback before constructing/loading the native banner. Callback errors, duplicates, or stale callbacks must not request an ad.
- Debug package changes must retain only arm64-v8a, enable compressed native libraries, exclude non-runtime Gate 1 and AdMob editor/demo material, retain runtime AdMob API/core/mediation dependencies plus android package/AAR files and internal/version, and preserve signing/package evidence for size regression review.
- Android exports must set `permissions/vibrate=true`. Default Android haptic dispatch uses `AndroidRuntime` application context and vibrator service: API 33+ passes `VibrationAttributes.createForUsage(USAGE_MEDIA)`; API 26–32 passes AudioAttributes `USAGE_GAME` / `CONTENT_TYPE_SONIFICATION`; supported min-SDK API 24–25 uses the legacy duration-plus-AudioAttributes overload. Retain injected test emission and `Input.vibrate_handheld` fallback when unavailable. Test export settings before a replacement device install.
- Android gameplay has no touch cast, hook, or reel affordance. Motion reads accelerometer, gravity, and gyro together once per update; it learns a two-cast profile before play, uses a back-then-opposite-snap sequence for casting, permits a smaller profile-relative back hook only in `HOOK_WINDOW`, and drives REELING through alternating gravity/gyro-confirmed lower and pull poses. Desktop keyboard/test simulation must be explicitly guarded from Android. Keep raw sensor traces out of retained logs; emit only compact derived motion markers.
