# Architecture

`src/domain/fishing_session.gd` owns deterministic game rules and the explicit state machine. `fish_definition.gd` owns data, including each planned fish’s tension strength, pulse phrase, and fight cadence. `motion_service.gd`, `save_service.gd`, `haptic_service.gd`, and `admob_service.gd` are replaceable platform adapters. `src/ui/main.gd` composes the code-native greybox, input fallbacks, calibration, haptic dispatch, and capture mode. `tests/test_runner.gd` calls domain/adapters headlessly.

`HapticService` is an injected-emitter scheduler rather than a timer-only side effect. `start_fight` reserves a short hook-confirmation delay, then `update_fight` can schedule at most one bounded phrase at a time, leaving the fish’s configured quiet gap. Normal species phrases yield to a universal 0.8-second high (65%) warning cadence and a faster universal 0.5-second urgent red (90%) cadence, then reset to normal when tension falls. Terminal cues stop the fight before emitting their distinct result. Turning haptics off clears pending work, so no vibration can leak after a setting change.

AdMob integration is intentionally isolated: the adapter’s native-bottom contract returns a zero Godot reserve, exposes measured native height only for diagnostics, and safely handles absence of the singleton in desktop/headless tests.
