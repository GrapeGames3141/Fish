# Architecture

`src/domain/fishing_session.gd` owns deterministic game rules and the explicit state machine. `fish_definition.gd` owns data. `motion_service.gd`, `save_service.gd`, and `admob_service.gd` are replaceable platform adapters. `src/ui/main.gd` composes the code-native greybox, input fallbacks, calibration, haptic dispatch, and capture mode. `tests/test_runner.gd` calls domain/adapters headlessly.

AdMob integration is intentionally isolated: the adapter’s native-bottom contract returns a zero Godot reserve, exposes measured native height only for diagnostics, and safely handles absence of the singleton in desktop/headless tests.
