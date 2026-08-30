# Testing Strategy

Run deterministic domain tests for state transitions/timeouts, clockwise reel behavior, tension escape, save round trip, desktop AdMob contract, and project settings. Use capture scenarios `ready`, `armed`, `bite`, `reeling`, `caught`, `escaped`, and `synthetic_reserve` to render 720×1280 evidence.

Physical Android validation is a later gate: verify real sensor thresholds, vibration timing, lifecycle, UMP, native adaptive banner geometry, touch comfort, and performance on a named device. Desktop success does not validate those properties.

Final Gate 1 evidence: deterministic domain tests and parser import passed. ADB found no attached device, so motion, haptics, UMP, real banner geometry, lifecycle, and performance remain unvalidated. Android export was attempted but yielded no APK because the first Gradle run found conflicting SDK environment variables and the corrected attempt produced no artifact before its owner exited.
