# Testing Strategy

Run deterministic domain tests for state transitions/timeouts, clockwise reel behavior, tension escape, save round trip, desktop AdMob contract, and project settings. Haptic tests inject an emitter and assert all six fish signature/cadence pairs are unique, phrases do not accumulate per frame, the hook confirmation precedes the first species phrase, high/red warnings repeat at universal escalating cadences, normal/high/red tier transitions reset correctly, disabling clears pending work, and caught/escaped terminal rhythms differ. Use capture scenarios `ready`, `armed`, `bite`, `reeling`, `caught`, `escaped`, and `synthetic_reserve` to render 720×1280 evidence.

Physical Android validation is a later gate: verify real sensor thresholds, vibration timing, lifecycle, UMP, native adaptive banner geometry, touch comfort, and performance on a named device. Desktop success does not validate those properties.

Final Gate 1 evidence: deterministic domain tests and parser import passed. ADB found no attached device, so motion, haptics, UMP, real banner geometry, lifecycle, and performance remain unvalidated. Android export emitted an APK, but `apksigner` rejected it as unsigned; the project now requests the configured default debug signing flow and needs a signed retry.
