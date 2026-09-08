extends SceneTree

const FishingSession = preload("res://src/domain/fishing_session.gd")
const SaveService = preload("res://src/services/save_service.gd")
const AdMobService = preload("res://src/services/admob_service.gd")
const MotionService = preload("res://src/services/motion_service.gd")
const FishDefinition = preload("res://src/domain/fish_definition.gd")
const HapticService = preload("res://src/services/haptic_service.gd")
const CastCaptureService = preload("res://src/services/cast_capture_service.gd")
const GameMain = preload("res://src/ui/main.gd")

var failures: Array[String] = []

func _init() -> void:
	_test_state_transitions_and_timing()
	_test_pump_and_recover_fight()
	_test_save_round_trip()
	_test_catch_record_progression()
	_test_ui_presentation_contract()
	_test_ui_controller_interactions()
	_test_cast_capture_service()
	_test_injectable_motion()
	_test_physical_cast_profile_motion()
	_test_haptic_signatures()
	_test_admob_contract()
	_test_project_source_settings()
	if failures.is_empty():
		print("PASS: Cast & Crank Gate 1 domain tests")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: %d test assertions" % failures.size())
		quit(1)

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _max_emitted_amplitude(pulses: Array[Dictionary]) -> float:
	var maximum := 0.0
	for pulse in pulses:
		maximum = maxf(maximum, float(pulse.amplitude))
	return maximum

func _motion_sample(linear: Vector3, gyro := Vector3(0, 0, 0.72)) -> Dictionary:
	var gravity := Vector3(0, -9.8, 0)
	return {"gravity": gravity, "accelerometer": gravity + linear, "gyro": gyro}

func _test_cast_capture_service() -> void:
	var path := "user://cast_tuning_capture_test_%d.json" % Time.get_ticks_msec()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var capture := CastCaptureService.new(path)
	expect(capture.phase == "idle" and not FileAccess.file_exists(path), "capture recorder is idle and stores nothing by default")
	expect(capture.start({"left_handed": false, "sensitivity": 1.2, "motion_profile": {"forward_axis": [-0.85, 0.27, -0.45]}}), "explicit Settings-style start begins a fresh capture")
	expect(capture.phase == "countdown" and not FileAccess.file_exists(path), "countdown does not overwrite a prior capture")
	var event: Dictionary = {}
	for frame in range(30): event = capture.update(0.10)
	expect(capture.phase == "active" and str(event.get("cue", "")) == "capture_window" and capture.casts.is_empty(), "countdown transitions into the first haptic-cued active window without sampling early")
	var last_event: Dictionary = {}
	for cast_number in range(CastCaptureService.CAST_COUNT):
		for frame in range(20):
			capture.queue_sample(_motion_sample(Vector3(-1.5 - cast_number * 0.1, 0.2, -0.3), Vector3(0.1, 0.2, 0.7)))
			last_event = capture.update(0.10)
		if cast_number < CastCaptureService.CAST_COUNT - 1:
			capture.queue_sample(_motion_sample(Vector3(99, 0, 0)))
			var rest_queued := capture.queued_samples.size()
			for frame in range(11): last_event = capture.update(0.10)
			expect(capture.phase == "active" and str(last_event.get("cue", "")) == "capture_window" and capture.queued_samples.size() == rest_queued, "rest windows do not sample and advance automatically to the next capture cue")
			capture.queued_samples.pop_front()
	expect(capture.phase == "saved" and bool(last_event.get("saved", false)) and capture.write_count == 1, "exactly ten active windows complete and write once")
	expect(capture.casts.size() == CastCaptureService.CAST_COUNT, "capture contains exactly ten cast groups")
	for group in capture.casts:
		expect(group.samples.size() > 0 and group.samples.size() <= CastCaptureService.MAX_SAMPLES_PER_CAST, "active capture group is nonempty and bounded")
		var sample: Dictionary = group.samples[0]
		expect(sample.has("t_ms") and sample.has("gravity") and sample.has("accelerometer") and sample.has("linear") and sample.has("gyro"), "captured samples retain timestamped sensor and derived-linear fields")
	last_event = capture.update(0.10)
	expect(capture.write_count == 1 and not bool(last_event.get("saved", false)), "completed capture is one-shot and does not rewrite while idle")
	var file := FileAccess.open(path, FileAccess.READ); var json := JSON.new(); var parse_error := json.parse(file.get_as_text()); file.close()
	expect(parse_error == OK and typeof(json.data) == TYPE_DICTIONARY and int(json.data.get("version", 0)) == CastCaptureService.VERSION and bool(json.data.get("completed", false)) and json.data.get("metadata", {}).get("handedness", "") == "right" and json.data.get("casts", []).size() == CastCaptureService.CAST_COUNT, "completed explicit capture writes valid metadata and ten groups")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _runtime_sweep(motion: MotionService, linear: Vector3, gyro := Vector3(0, 0, 0.72), frames := 3, delta := 0.04) -> Dictionary:
	var event := {"cast_arm": false, "cast_quality": 0.0}
	for frame in range(frames):
		motion.queue_sample(_motion_sample(linear, gyro))
		event = motion.update(delta, true, false)
	return event

func _physical_back_sweep(motion: MotionService, strength_multiplier := 1.20, frames := 3, delta := 0.04) -> Dictionary:
	return _runtime_sweep(motion, motion._back_axis_direction() * motion._physical_cock_threshold() * strength_multiplier, Vector3(0, 0, 0.72), frames, delta)

func _learned_snap_sweep(motion: MotionService, strength := -1.0, frames := 3, delta := 0.04) -> Dictionary:
	var axis := Vector3(motion.profile.forward_axis[0], motion.profile.forward_axis[1], motion.profile.forward_axis[2]).normalized()
	if strength < 0.0:
		strength = motion._runtime_snap_threshold() * 2.0
	return _runtime_sweep(motion, axis * strength, Vector3(0, 0, 0.72), frames, delta)

func _hook_sweep(motion: MotionService, multiplier := 1.4, frames := 3, delta := 0.05) -> Dictionary:
	var event := {"hook": false}
	var linear := motion._back_axis_direction() * motion._hook_threshold() * multiplier
	for frame in range(frames):
		motion.queue_sample(_motion_sample(linear, Vector3(0, 0, 0.5)))
		event = motion.update(delta, false, true)
	return event

func _calibrated_motion() -> MotionService:
	var motion := MotionService.new()
	motion.begin_calibration()
	for frame in range(3):
		motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO))
		motion.update(0.25, false, false)
	for pair in [[Vector3(3.0, 0, 0), Vector3(-5.0, 0, 0)], [Vector3(3.2, 0, 0), Vector3(-5.4, 0, 0)]]:
		motion.queue_sample(_motion_sample(pair[0]))
		motion.update(0.01, false, false)
		motion.queue_sample(_motion_sample(pair[1]))
		motion.update(0.18, false, false)
	return motion

func _diagonal_motion() -> MotionService:
	var motion := MotionService.new()
	motion.begin_calibration()
	for frame in range(3):
		motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO))
		motion.update(0.25, false, false)
	var cock := Vector3(4.5, 4.5, 1.5)
	for pair in [[cock, -cock * 1.70], [cock * 1.04, -cock * 1.76]]:
		motion.queue_sample(_motion_sample(pair[0]))
		motion.update(0.01, false, false)
		motion.queue_sample(_motion_sample(pair[1]))
		motion.update(0.18, false, false)
	return motion

func _left_calibrated_motion() -> MotionService:
	var motion := MotionService.new(); motion.left_handed = true; motion.begin_calibration()
	for frame in range(3): motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); motion.update(0.25, false, false)
	for pair in [[Vector3(-3.0, 0, 0), Vector3(5.0, 0, 0)], [Vector3(-3.2, 0, 0), Vector3(5.4, 0, 0)]]:
		motion.queue_sample(_motion_sample(pair[0])); motion.update(0.01, false, false); motion.queue_sample(_motion_sample(pair[1])); motion.update(0.18, false, false)
	return motion

func _test_state_transitions_and_timing() -> void:
	var game = FishingSession.new()
	expect(game.arm_cast(), "READY arms")
	expect(game.release_cast(0.85), "armed cast releases")
	expect(game.cast_distance_m > FishingSession.MIN_CAST_DISTANCE_M and game.cast_distance_m <= FishingSession.MAX_CAST_DISTANCE_M, "cast quality maps to a bounded distance")
	game.tick(game.fish.bite_delay_seconds)
	expect(game.state == FishingSession.State.BITE, "line reaches bite")
	game.tick(FishingSession.BITE_CUE_HOLD_SECONDS - 0.01)
	expect(game.state == FishingSession.State.BITE, "bite holds hook detection until the two-pulse cue has completed")
	game.tick(0.01)
	expect(game.state == FishingSession.State.HOOK_WINDOW and is_zero_approx(game.bite_elapsed), "bite advances only after the .42 second cue hold and resets the full hook timer")
	expect(game.set_hook(), "hook succeeds in 1.8s window")
	expect(game.state == FishingSession.State.REELING, "hook enters reeling")
	game.reset(); game.arm_cast(); game.release_cast(0.4); game.tick(game.fish.bite_delay_seconds + 0.01); game.tick(FishingSession.BITE_CUE_HOLD_SECONDS); game.tick(FishingSession.HOOK_WINDOW_SECONDS + 0.1)
	expect(game.state == FishingSession.State.ESCAPED, "hook timeout escapes")
	var boundary = FishingSession.new(); boundary.arm_cast(); boundary.release_cast(0.5); boundary.tick(boundary.fish.bite_delay_seconds + 0.01); boundary.tick(FishingSession.BITE_CUE_HOLD_SECONDS); boundary.tick(1.79); expect(boundary.state == FishingSession.State.HOOK_WINDOW, "hook remains available for the full 1.8 seconds after the bite cue hold"); boundary.tick(0.02); expect(boundary.state == FishingSession.State.ESCAPED, "hook closes at 1.8 seconds after the cue hold")
	var guarded_bite = FishingSession.new(); guarded_bite.arm_cast(); guarded_bite.release_cast(0.8); guarded_bite.tick(guarded_bite.fish.bite_delay_seconds)
	var bite_guard_motion := _calibrated_motion(); bite_guard_motion.queue_sample(_motion_sample(Vector3(1.35, 0, 0), Vector3(0, 0, 0.5)))
	expect(not bite_guard_motion.update(0.05, false, guarded_bite.state == FishingSession.State.HOOK_WINDOW).hook and guarded_bite.state == FishingSession.State.BITE, "BITE does not activate hook detection while the bite haptic chain is still protected")
	guarded_bite.tick(FishingSession.BITE_CUE_HOLD_SECONDS)
	expect(guarded_bite.state == FishingSession.State.HOOK_WINDOW and _hook_sweep(bite_guard_motion).hook, "hook detection starts only after the bite cue hold completes and a deliberate sweep arrives")
	var cancellation_motion := _calibrated_motion(); var cancellation_arm := _physical_back_sweep(cancellation_motion)
	var cancellation_session := FishingSession.new(); cancellation_session.arm_cast()
	cancellation_motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); var cancellation_event := cancellation_motion.update(MotionService.RUNTIME_MAX_REVERSAL_SECONDS + 0.01, true, false)
	expect(cancellation_arm.cast_arm and bool(cancellation_event.get("cast_cancel", false)) and cancellation_session.cancel_cast() and cancellation_session.state == FishingSession.State.READY, "timed-out reversal emits cast_cancel and returns CAST_ARMED to READY without progress")
	var stale_snap := _runtime_sweep(cancellation_motion, Vector3(-80.0, 0, 0), Vector3(0, 0, 0.72))
	expect(float(stale_snap.cast_quality) == 0.0 and not stale_snap.cast_arm, "a snap after cancellation cannot cast without a fresh cock")
	var pine_rolls := [0.0, 0.60, 0.90]
	var cedar_rolls := [0.0, 0.65, 0.93]
	var selected_ids: Array[String] = []
	for roll in pine_rolls:
		selected_ids.append(FishDefinition.select_weighted("pine_lake", roll).id)
	for roll in cedar_rolls:
		selected_ids.append(FishDefinition.select_weighted("cedar_river", roll).id)
	expect(selected_ids == ["bluegill", "largemouth_bass", "channel_catfish", "rainbow_trout", "smallmouth_bass", "northern_pike"], "deterministic weighted boundaries make every planned species reachable across Pine Lake and Cedar River")
	var pine := FishDefinition.select_weighted("pine_lake", 0.0); var cedar := FishDefinition.select_weighted("cedar_river", 0.99)
	expect(pine.location_id == "pine_lake" and cedar.id == "northern_pike" and cedar.max_length_cm > pine.max_length_cm, "deterministic weighted location selection exposes distinct species and size ranges")
	var near_pine := FishDefinition.select_weighted("pine_lake", 0.70, 12.0)
	var far_pine := FishDefinition.select_weighted("pine_lake", 0.70, 36.0)
	expect(near_pine.id != far_pine.id, "near and far Pine Lake habitat weights can change encounter selection")
	var tiny_far := FishingSession.new(); tiny_far.set_location("cedar_river"); tiny_far.set_encounter_rolls(0.1, 0.05, 0.0); tiny_far.arm_cast(); tiny_far.release_cast(0.95)
	var giant_near := FishingSession.new(); giant_near.set_location("cedar_river"); giant_near.set_encounter_rolls(0.1, 0.98, 0.0); giant_near.arm_cast(); giant_near.release_cast(0.15)
	expect(tiny_far.catch_length_cm < giant_near.catch_length_cm, "independent size roll prevents long casts from guaranteeing larger catches")
	var terminal_recast := FishingSession.new(); terminal_recast.state = FishingSession.State.CAUGHT; terminal_recast.tick(FishingSession.TERMINAL_RECAST_DWELL_SECONDS)
	for frame in range(6): terminal_recast.credit_terminal_still(0.08, true)
	expect(terminal_recast.can_recast_from_motion(), "terminal recast requires dwell plus valid still sensor credit")
	terminal_recast.credit_terminal_still(0.01, false)
	expect(not terminal_recast.can_recast_from_motion(), "terminal movement resets recast readiness until a fresh quiet settle")

func _fight_session(fish: FishDefinition, behavior_roll := 0.0) -> FishingSession:
	var game := FishingSession.new()
	game.set_location(fish.location_id, 0.0); game.fish = fish; game.behavior_roll = behavior_roll; game.fight_phase_offset = behavior_roll * (fish.run_seconds + fish.lull_seconds); game.state = FishingSession.State.REELING; game.tension = 0.30
	return game
func _simulate_fight_policy(fish: FishDefinition, fps: int, policy: String, behavior_roll := 0.0) -> FishingSession:
	var game := _fight_session(fish, behavior_roll)
	var delta := 1.0 / float(fps)
	var target := 0.80 if policy == "reactive" else (1.0 if policy == "hard" else 0.70)
	var delayed_tension := game.tension
	var next_decision := 0.10
	var tension_history: Array[Dictionary] = []
	for frame in range(50 * fps):
		if game.state != FishingSession.State.REELING: break
		tension_history.append({"at": game.fight_elapsed, "tension": game.tension})
		if policy == "reactive" and game.fight_elapsed >= next_decision:
			# A 300ms-old warning sample plus a 100ms load ramp models a human response.
			for sample in tension_history:
				if float(sample.at) <= game.fight_elapsed - 0.30: delayed_tension = float(sample.tension)
			target = 0.14 if delayed_tension >= 0.65 else (0.80 if delayed_tension <= 0.35 else target)
			next_decision += 0.10
		var current := game.rod_load
		game.set_rod_load(move_toward(current, target, delta / 0.10))
		game.tick(delta)
	return game
func _test_pump_and_recover_fight() -> void:
	for fish in FishDefinition.all_planned():
		for fps in [30, 60, 120]:
			for behavior_roll in [0.0, 0.37, 0.83]:
				var reactive := _simulate_fight_policy(fish, fps, "reactive", behavior_roll)
				var hard := _simulate_fight_policy(fish, fps, "hard", behavior_roll)
				var moderate := _simulate_fight_policy(fish, fps, "moderate", behavior_roll)
				expect(reactive.state == FishingSession.State.CAUGHT and reactive.fight_elapsed >= 10.0 and reactive.fight_elapsed <= 20.0, "300ms-delayed pull/ease lands %s in 10–20 seconds at %dHz / roll %.2f" % [fish.id, fps, behavior_roll])
				expect(hard.state == FishingSession.State.ESCAPED or hard.fight_elapsed > reactive.fight_elapsed + 2.0, "constant hard pull underperforms responsive %s at %dHz" % [fish.id, fps])
				expect(moderate.state == FishingSession.State.ESCAPED or moderate.fight_elapsed > reactive.fight_elapsed + 1.0, "constant moderate pull underperforms responsive %s at %dHz" % [fish.id, fps])
	var pike := _fight_session(FishDefinition.all_planned().back(), 0.0)
	pike.tension = 0.82; pike.strain = 0.78; pike.set_rod_load(0.04)
	for frame in range(60): pike.tick(1.0 / 60.0)
	expect(pike.tension <= 0.66 and pike.strain < 0.60, "even a pike run visibly recovers within one second of lowering")
	var no_load := _fight_session(FishDefinition.bluegill()); no_load.set_rod_load(0.0); no_load.tick(5.0)
	expect(is_zero_approx(no_load.fight_progress), "no-load fight time never gains landing progress")
	var paused := _fight_session(FishDefinition.bluegill()); var before := paused.tension; paused.tick(0.0)
	expect(is_equal_approx(before, paused.tension) and is_zero_approx(paused.fight_elapsed), "zero-delta menu pause leaves fight state untouched")

func _test_save_round_trip() -> void:
	var path := "user://gate1-test-%d.json" % Time.get_ticks_usec()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var save = SaveService.new(path)
	expect(save.load_data().version == SaveService.VERSION, "missing save returns defaults")
	for fish in FishDefinition.all_planned():
		expect(int(save.data.catches.get(fish.id, -1)) == 0 and float(save.data.best_cm.get(fish.id, -1.0)) == 0.0, "new save has a zero record for " + fish.id)
	save.data.settings.sensitivity = 1.4
	save.data.settings.left_handed = true; save.data.selected_location_id = "cedar_river"
	save.data.motion_profile = _calibrated_motion().get_profile()
	save.data.calibrated = true
	save.record_bluegill(24.2)
	save.record_catch("northern_pike", 74.5)
	var restored = SaveService.new(path)
	restored.load_data()
	expect(float(restored.data.settings.sensitivity) == 1.4 and restored.data.settings.left_handed and restored.data.selected_location_id == "cedar_river", "save restores expanded settings and selected location")
	expect(int(restored.data.catches.bluegill) >= 1, "save restores catch count")
	expect(float(restored.data.best_cm.bluegill) >= 24.2, "save restores best fish")
	expect(int(restored.data.catches.northern_pike) == 1 and float(restored.data.best_cm.northern_pike) == 74.5, "generic record_catch persists every planned species")
	expect(restored.data.calibrated and SaveService.is_motion_profile_valid(restored.data.motion_profile), "save restores a validated motion profile")
	var legacy := FileAccess.open(path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 1, "calibrated": true, "settings": {"sensitivity": 1.2, "haptics": false}, "catches": {"bluegill": 4}, "best_cm": {"bluegill": 29.5}}))
	legacy.close()
	var migrated := SaveService.new(path); migrated.load_data()
	expect(migrated.data.version == SaveService.VERSION and not migrated.data.calibrated and migrated.data.motion_profile.is_empty(), "v1 save migrates to uncalibrated without losing unsafe profile state")
	expect(float(migrated.data.settings.sensitivity) == 1.2 and not migrated.data.settings.haptics and int(migrated.data.catches.bluegill) == 4 and float(migrated.data.best_cm.bluegill) == 29.5 and int(migrated.data.catches.northern_pike) == 0, "v1 migration preserves settings/catch progress and adds zero planned records")
	var legacy_v4 := FileAccess.open(path, FileAccess.WRITE)
	legacy_v4.store_string(JSON.stringify({"version": 4, "calibrated": true, "settings": {"sensitivity": 1.3, "haptics": false, "reduced_motion": true, "left_handed": true}, "selected_location_id": "cedar_river", "motion_profile": _calibrated_motion().get_profile(), "catches": {"bluegill": 7}, "best_cm": {"bluegill": 30.5}}))
	legacy_v4.close()
	var migrated_v4 := SaveService.new(path); migrated_v4.load_data()
	expect(migrated_v4.data.version == SaveService.VERSION and int(migrated_v4.data.catches.bluegill) == 7 and is_equal_approx(float(migrated_v4.data.best_cm.bluegill), 30.5) and bool(migrated_v4.data.settings.left_handed) and bool(migrated_v4.data.settings.reduced_motion) and migrated_v4.data.selected_location_id == "cedar_river" and migrated_v4.data.calibrated and migrated_v4.data.catch_history.is_empty(), "v4 to v5 preserves aggregate/profile/settings without inventing catch dates")
	var malformed_history := FileAccess.open(path, FileAccess.WRITE)
	malformed_history.store_string(JSON.stringify({"version": SaveService.VERSION, "catches": {"bluegill": 2}, "best_cm": {"bluegill": 25.0}, "catch_history": [{"fish_id": "bluegill", "length_cm": 25.04, "location_id": "pine_lake", "timestamp_utc": 1700000000, "fight_seconds": 11.26, "cast_distance_m": 21.24}, {"fish_id": "unknown", "length_cm": 99.0, "location_id": "pine_lake", "timestamp_utc": 1700000001}, {"fish_id": "bluegill", "length_cm": 0.0, "location_id": "pine_lake", "timestamp_utc": 1700000002}, {"fish_id": "bluegill", "length_cm": 18.0, "location_id": "ocean", "timestamp_utc": 1700000003}, {"fish_id": "bluegill", "length_cm": 18.0, "location_id": "pine_lake", "timestamp_utc": 0}]}))
	malformed_history.close()
	var sanitized_history := SaveService.new(path); sanitized_history.load_data()
	expect(sanitized_history.data.catch_history.size() == 1 and is_equal_approx(float(sanitized_history.data.catch_history[0].length_cm), 25.0) and is_equal_approx(float(sanitized_history.data.catch_history[0].fight_seconds), 11.3) and is_equal_approx(float(sanitized_history.data.catch_history[0].cast_distance_m), 21.2), "v5 reload discards malformed history and sanitizes valid bounded fields")
	var invalid := FileAccess.open(path, FileAccess.WRITE)
	invalid.store_string(JSON.stringify({"version": SaveService.VERSION, "settings": {"sensitivity": 1.1}, "catches": {"bluegill": 6}, "best_cm": {"bluegill": 30.0}, "motion_profile": {"forward_axis": [1.0, 0.0, 0.0], "back_peak": 0.1, "forward_peak": 5.0}}))
	invalid.close()
	var invalid_restored := SaveService.new(path); invalid_restored.load_data()
	expect(not invalid_restored.data.calibrated and invalid_restored.data.motion_profile.is_empty() and int(invalid_restored.data.catches.bluegill) == 6, "invalid motion profiles recalibrate without losing progress")
	var corrupt := FileAccess.open(path, FileAccess.WRITE); corrupt.store_string("not json"); corrupt.close()
	expect(SaveService.new(path).load_data().version == SaveService.VERSION, "corrupt save falls back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_catch_record_progression() -> void:
	var path := "user://catch-progress-%d.json" % Time.get_ticks_usec()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var catch_save := SaveService.new(path); catch_save.load_data()
	catch_save.record_catch("largemouth_bass", 31.5)
	expect(int(catch_save.data.catches.largemouth_bass) == 1 and is_equal_approx(float(catch_save.data.best_cm.largemouth_bass), 31.5), "first catch stores one catch and its initial best")
	catch_save.record_catch("largemouth_bass", 31.5)
	expect(int(catch_save.data.catches.largemouth_bass) == 2 and is_equal_approx(float(catch_save.data.best_cm.largemouth_bass), 31.5), "exact tied length increments once without changing the saved best")
	catch_save.record_catch("largemouth_bass", 31.46)
	expect(int(catch_save.data.catches.largemouth_bass) == 3 and is_equal_approx(float(catch_save.data.best_cm.largemouth_bass), 31.5), "lower catch increments count without replacing the saved best")
	catch_save.record_catch("largemouth_bass", 31.54)
	expect(int(catch_save.data.catches.largemouth_bass) == 4 and is_equal_approx(float(catch_save.data.best_cm.largemouth_bass), 31.54) and is_equal_approx(snappedf(31.54, 0.1), snappedf(31.5, 0.1)), "near-tie keeps precise saved best while presentation can compare the same one-decimal value")
	catch_save.record_catch("largemouth_bass", 32.1)
	expect(int(catch_save.data.catches.largemouth_bass) == 5 and is_equal_approx(float(catch_save.data.best_cm.largemouth_bass), 32.1), "higher catch replaces best after preserving all prior catches")
	var history_save := SaveService.new(path, func() -> int: return 1700000000); history_save.load_data()
	history_save.record_catch("bluegill", 22.4, {"location_id": "pine_lake", "fight_seconds": 13.2, "cast_distance_m": 18.0})
	var blue_history := history_save.history_for_fish("bluegill")
	expect(blue_history.size() == 1 and int(blue_history[0].timestamp_utc) == 1700000000 and is_equal_approx(float(blue_history[0].fight_seconds), 13.2), "recent catch history records injected UTC, water, fight time, and cast distance")
	var reloaded_history := SaveService.new(path); reloaded_history.load_data()
	expect(reloaded_history.history_for_fish("bluegill").size() == 1 and int(reloaded_history.history_for_fish("bluegill")[0].timestamp_utc) == 1700000000, "persisted recent history reloads without changing its aggregate catch record")
	for index in range(SaveService.MAX_CATCH_HISTORY + 3): history_save.record_catch("bluegill", 18.0 + index * 0.01, {"location_id": "pine_lake", "fight_seconds": 10.0, "cast_distance_m": 12.0})
	expect(history_save.history_for_fish("bluegill").size() == SaveService.MAX_CATCH_HISTORY, "recent history is bounded while aggregate totals remain unbounded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_ui_presentation_contract() -> void:
	expect(GameMain.catch_status_for(0, 0.0, 24.0).begins_with("FIRST CATCH"), "first catch presentation is distinct")
	expect(GameMain.catch_status_for(2, 31.5, 31.5).begins_with("MATCHED BEST"), "exact displayed tie does not claim a new best")
	expect(GameMain.catch_status_for(2, 31.5, 31.54).begins_with("MATCHED BEST"), "one-decimal near-tie does not claim a hidden-precision new best")
	expect(GameMain.catch_status_for(2, 31.5, 31.6).begins_with("NEW BEST"), "larger displayed catch claims a new best")
	expect(GameMain.catch_status_for(2, 31.5, 30.0).begins_with("3 CAUGHT"), "lower catch preserves the existing displayed best")
	var min_landed := GameMain.presentation_bobber_y(FishingSession.MIN_CAST_DISTANCE_M, 0.0, false, 1.0)
	var mid_landed := GameMain.presentation_bobber_y(24.0, 0.0, false, 1.0)
	var max_landed := GameMain.presentation_bobber_y(FishingSession.MAX_CAST_DISTANCE_M, 0.0, false, 1.0)
	expect(max_landed < mid_landed and mid_landed < min_landed, "farther casts place the landed bobber farther up the water")
	expect(GameMain.presentation_bobber_y(FishingSession.MIN_CAST_DISTANCE_M, 1.0, true, 1.0) > min_landed and GameMain.presentation_bobber_y(FishingSession.MAX_CAST_DISTANCE_M, 1.0, true, 1.0) > max_landed, "fight progress brings every landed bobber nearer the rod")
	expect(is_equal_approx(mid_landed, 595.0), "reduced motion uses the settled logical landing endpoint without travel animation")
	expect(GameMain.accepts_primary_press(true, true, true, 0) and not GameMain.accepts_primary_press(false, true, true, InputEvent.DEVICE_ID_EMULATION), "raw touch dispatches once while the matching emulated mouse press is ignored")
	expect(GameMain.accepts_primary_press(false, true, true, 0) and not GameMain.accepts_primary_press(false, true, false, 0) and not GameMain.accepts_primary_press(false, false, true, 0), "desktop primary click dispatches once while right-click and release are inert")
	var terminal := FishingSession.new(); terminal.state = FishingSession.State.CAUGHT
	expect(terminal.set_location("cedar_river", 0.0), "terminal state can select a new water before the controller resets its presentation")
	terminal.reset(); expect(terminal.state == FishingSession.State.READY and terminal.set_location("cedar_river", 0.0) and terminal.location_id == "cedar_river", "water selection resets terminal catch state without touching saved records")
	var armed := FishingSession.new(); armed.arm_cast(); armed.cancel_cast()
	expect(armed.state == FishingSession.State.READY, "opening a pause menu can cancel an armed cast before it leaves a stale snap prompt")

func _test_ui_controller_interactions() -> void:
	var controller := GameMain.new()
	controller.session = FishingSession.new(); controller.motion = MotionService.new(); controller.haptics = HapticService.new(); controller.preview_haptics = HapticService.new(); controller.cast_capture = CastCaptureService.new("user://ui-controller-capture-%d.json" % Time.get_ticks_usec(), Callable(controller.motion, "sample"))
	controller.save = SaveService.new("user://ui-controller-%d.json" % Time.get_ticks_usec()); controller.save.data = SaveService.default_data()
	var view = GameMain.FishingView.new(); view.controller = controller; view.size = Vector2(720, 1280); controller.view = view
	for safe_top in [0.0, 91.0, 180.0]:
		view.safe_top_override = safe_top; view.overlay = ""; view._refresh_top_nav_geometry(); view._handle_press(view.settings_rect.get_center())
		expect(view.overlay == "settings", "Settings press routes through its current shared safe-top target at %.0f" % safe_top)
		controller._close_overlay()
		view.overlay = ""; view._handle_press(view.settings_rect.position - Vector2(1, 1)); expect(view.overlay == "", "nav boundary outside is inert at safe-top %.0f" % safe_top)
	view.safe_top_override = 0.0; view.overlay = "settings"
	var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.index = 0; touch.device = 0; touch.position = view.settings_haptics_rect.get_center()
	var emulated_mouse := InputEventMouseButton.new(); emulated_mouse.pressed = true; emulated_mouse.button_index = MOUSE_BUTTON_LEFT; emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION; emulated_mouse.position = touch.position
	var original_haptics := bool(controller.save.data.settings.haptics); view._gui_input(touch); view._gui_input(emulated_mouse)
	expect(bool(controller.save.data.settings.haptics) != original_haptics, "raw touch plus matching emulated mouse toggles a Settings control exactly once")
	var right_click := InputEventMouseButton.new(); right_click.pressed = true; right_click.button_index = MOUSE_BUTTON_RIGHT; right_click.device = 0; right_click.position = touch.position; var after_touch := bool(controller.save.data.settings.haptics); view._gui_input(right_click)
	expect(bool(controller.save.data.settings.haptics) == after_touch, "right click is inert on Settings targets")
	view._handle_press(Vector2(90, 780)); expect(view.overlay == "settings", "blank Settings gap is inert")
	controller.session.state = FishingSession.State.CAST_ARMED; controller._open_settings()
	expect(controller.session.state == FishingSession.State.READY and view.overlay == "settings", "opening Settings cancels CAST_ARMED before stale snap input can survive pause")
	controller.motion = _calibrated_motion(); var pull_pose := Vector3(0, -9.8, 0); controller.motion.begin_fight(pull_pose); controller.session.state = FishingSession.State.REELING; controller._open_settings(); controller._close_overlay()
	expect(controller.session.state == FishingSession.State.REELING and controller.menu_motion_settle_remaining >= HapticService.MOTION_SETTLE_SECONDS, "settings pause preserves an active fight while return owns a motion-settle guard")
	controller.motion.queue_sample({"gravity": pull_pose, "accelerometer": pull_pose, "gyro": Vector3(0, 0, 0.5)})
	var resumed_pull := controller.motion.update(0.1, false, false, true)
	expect(float(resumed_pull.fight_load) >= 0.95, "a real fight pose still maps to pull load after settings return preserves fight anchors")
	controller.loading_active = false; controller.capture_freeze = false; controller.session.state = FishingSession.State.HOOK_WINDOW; controller.session.bite_elapsed = FishingSession.HOOK_WINDOW_SECONDS - 0.05; controller.menu_motion_settle_remaining = 0.30; view.overlay = ""; controller._process(0.20)
	expect(controller.session.state == FishingSession.State.HOOK_WINDOW and controller.session.bite_elapsed <= FishingSession.HOOK_WINDOW_SECONDS - 0.05, "menu settle pauses a near-expiry hook window rather than consuming it")
	controller._process(0.11); controller._process(0.01)
	expect(controller.session.state == FishingSession.State.HOOK_WINDOW, "hook window resumes only after its menu settle guard finishes")
	controller.preview_haptics.set_enabled(true); controller.preview_haptics.cue("bite"); controller.preview_haptics.tick(0.01); var preview_guard := controller.preview_haptics.motion_guard_seconds(); controller._close_overlay()
	expect(controller.menu_motion_settle_remaining >= preview_guard and controller.preview_haptics.pending.is_empty(), "closing immediately after preview preserves its motor guard and clears delayed preview work")
	controller.save.data.settings.haptics = true; controller.haptics.set_enabled(true); controller.preview_haptics.set_enabled(true); controller.preview_haptics.cue("bite"); controller.preview_haptics.tick(0.01); controller._toggle_setting("haptics")
	expect(not controller.preview_haptics.enabled and controller.preview_haptics.pending.is_empty(), "turning haptics off stops the preview channel before later pulses leak")
	controller.session.state = FishingSession.State.LINE_OUT; controller.session.location_id = "pine_lake"; view.overlay = "locations"; view._refresh_location_card_rects(0.0); view._handle_press(view.location_cedar_rect.get_center())
	expect(controller.session.location_id == "pine_lake" and view.overlay == "locations", "active fishing blocks water selection through the Locations overlay")
	controller.session.state = FishingSession.State.CAUGHT; controller.save.data.catches.bluegill = 3; controller._select_location("cedar_river")
	expect(controller.session.state == FishingSession.State.READY and controller.session.location_id == "cedar_river" and int(controller.save.data.catches.bluegill) == 3, "terminal catch selection resets the result without losing saved records")
	controller.session.state = FishingSession.State.CAUGHT; controller.session.fish = FishDefinition.bluegill(); controller.session.catch_length_cm = 25.0; controller.caught_recorded = false; controller._snapshot_catch_record(); controller._record_catch_once(); controller._record_catch_once()
	expect(int(controller.save.data.catches.bluegill) == 4 and controller.save.history_for_fish("bluegill").size() == 1, "catch record handler persists aggregate and history exactly once")
	controller.motion = _calibrated_motion(); controller.session.state = FishingSession.State.CAUGHT; controller.session.terminal_elapsed = 0.0; controller.session.terminal_still_elapsed = 0.0; controller.caught_recorded = true; controller.terminal_motion_ready = false; controller.prior_state = FishingSession.State.CAUGHT; view.overlay = ""
	for frame in range(60): controller.motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); controller._process(0.05)
	expect(controller.terminal_motion_ready, "terminal controller waits through dwell and valid quiet samples before accepting a new gesture")
	for frame in range(3): controller.motion.queue_sample(_motion_sample(controller.motion._back_axis_direction() * controller.motion._physical_cock_threshold() * 1.2)); controller._process(0.04)
	expect(controller.session.state == FishingSession.State.CAST_ARMED, "settled terminal controller accepts a fresh physical cock")
	var forward := Vector3(controller.motion.profile.forward_axis[0], controller.motion.profile.forward_axis[1], controller.motion.profile.forward_axis[2]).normalized()
	for frame in range(3): controller.motion.queue_sample(_motion_sample(forward * controller.motion._runtime_snap_threshold() * 2.0)); controller._process(0.04)
	expect(controller.session.state == FishingSession.State.LINE_OUT, "terminal cock followed by snap launches a motion-only next cast")
	controller.session.state = FishingSession.State.CAUGHT; controller.session.terminal_elapsed = FishingSession.TERMINAL_RECAST_DWELL_SECONDS; controller.terminal_motion_ready = false
	for frame in range(12): controller.motion.queue_sample({"gravity": Vector3.ZERO, "accelerometer": Vector3.ZERO, "gyro": Vector3.ZERO}); controller._process(0.05)
	expect(not controller.terminal_motion_ready, "gravity-zero desktop samples never credit terminal stillness")
	controller.haptics.stop(); controller.motion = _calibrated_motion(); controller.session.state = FishingSession.State.CAUGHT; controller.session.terminal_elapsed = FishingSession.TERMINAL_RECAST_DWELL_SECONDS; controller.session.terminal_still_elapsed = 0.0; controller.terminal_motion_ready = false; controller.prior_state = FishingSession.State.CAUGHT
	for frame in range(12): controller.motion.queue_sample(_motion_sample(Vector3(0.9, 0, 0), Vector3.ZERO)); controller._process(0.05)
	expect(not controller.terminal_motion_ready and controller.session.terminal_still_elapsed == 0.0, "noisy valid-gravity terminal samples cannot arm recast readiness")
	controller.session.terminal_still_elapsed = FishingSession.TERMINAL_STILL_SECONDS; controller.save.data.settings.haptics = true; controller.haptics.set_enabled(true); controller.haptics.cue("bite"); controller.haptics.tick(0.0); controller.motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); controller._process(0.04)
	expect(not controller.terminal_motion_ready and controller.haptics.is_motion_guarded(), "terminal motor guard rejects a ready-looking quiet frame until the haptic tail clears")
	controller.haptics.stop(); controller.motion = _left_calibrated_motion(); controller.session.state = FishingSession.State.CAUGHT; controller.session.terminal_elapsed = 0.0; controller.session.terminal_still_elapsed = 0.0; controller.terminal_motion_ready = false; controller.prior_state = FishingSession.State.CAUGHT
	for frame in range(60): controller.motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); controller._process(0.05)
	for frame in range(3): controller.motion.queue_sample(_motion_sample(controller.motion._back_axis_direction() * controller.motion._physical_cock_threshold() * 1.2)); controller._process(0.04)
	var left_forward := Vector3(controller.motion.profile.forward_axis[0], controller.motion.profile.forward_axis[1], controller.motion.profile.forward_axis[2]).normalized()
	for frame in range(3): controller.motion.queue_sample(_motion_sample(left_forward * controller.motion._runtime_snap_threshold() * 2.0)); controller._process(0.04)
	expect(controller.session.state == FishingSession.State.LINE_OUT, "left-handed terminal recast also requires and accepts its mirrored fresh cock then snap")
	controller.session.terminal_still_elapsed = FishingSession.TERMINAL_STILL_SECONDS; controller._open_settings(); controller._close_overlay()
	expect(not controller.terminal_motion_ready and is_zero_approx(controller.session.terminal_still_elapsed), "menu return clears terminal readiness for a fresh still settle")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(controller.save.path)); view.free(); controller.free()

func _test_injectable_motion() -> void:
	var motion := _calibrated_motion()
	expect(motion.is_calibrated() and motion.calibration_progress == 2, "two physical calibration traces build a validated profile")
	expect(float(motion.profile.forward_axis[0]) < -0.70, "calibration stores an explicit left/negative-X forward axis")
	expect(MotionService.validate_profile({"forward_axis": [-0.85, 0.27, -0.445], "back_peak": 3.0, "forward_peak": 5.0, "gyro_peak": 0.7, "transition_seconds": 0.2, "noise_floor": 0.1, "direction_tolerance": 0.62}), "existing negative-X saved profile remains valid")
	expect(MotionService.validate_profile({"forward_axis": [-0.52, -0.80, -0.28], "back_peak": 3.0, "forward_peak": 5.0, "gyro_peak": 0.7, "transition_seconds": 0.2, "noise_floor": 0.1, "direction_tolerance": 0.62}), "clearly left-handed diagonal saved profile remains valid")
	expect(not MotionService.validate_profile({"forward_axis": [1.0, 0.0, 0.0], "back_peak": 3.0, "forward_peak": 5.0, "gyro_peak": 0.7, "transition_seconds": 0.2, "noise_floor": 0.1, "direction_tolerance": 0.62}), "wrong-handed saved profile is rejected and recalibrates")
	var left_motion := _left_calibrated_motion()
	expect(left_motion.is_calibrated() and float(left_motion.profile.get("forward_axis", [0.0])[0]) > 0.70, "left-handed calibration mirrors the saved profile axis profile=%s phase=%s" % [str(left_motion.profile), left_motion.calibration_phase])
	var left_arm := _physical_back_sweep(left_motion)
	var left_cast := _learned_snap_sweep(left_motion)
	expect(left_arm.cast_arm and float(left_cast.cast_quality) > 0.0, "left-handed cock-left snap-right cast mirrors right-handed behavior")
	var thresholds := _calibrated_motion(); thresholds.profile.noise_floor = 1.0; thresholds.profile.back_peak = 4.0; thresholds.profile.forward_peak = 6.0; thresholds.profile.gyro_peak = 4.0; thresholds.sensitivity = 2.0
	expect(is_equal_approx(thresholds._back_threshold(), 1.16) and is_equal_approx(thresholds._forward_threshold(), 1.26) and is_equal_approx(thresholds._hook_threshold(), 0.8) and is_equal_approx(thresholds._gyro_threshold(), 0.32) and is_equal_approx(thresholds._snap_gyro_threshold(), 0.32), "gate-restoration thresholds apply sensitivity to each complete strict max formula")
	thresholds.sensitivity = 0.5; expect(is_equal_approx(thresholds._gyro_threshold(), 0.60) and is_equal_approx(thresholds._snap_gyro_threshold(), 0.60), "restored snap gyro exactly matches the normal cast gyro gate")
	var pixel_profile := {"forward_axis": [-0.8526, 0.2737, -0.4452], "back_peak": 2.1457, "forward_peak": 3.6814, "gyro_peak": 4.2315, "transition_seconds": 0.375, "noise_floor": 0.6437, "direction_tolerance": 0.62}
	var pixel_thresholds := MotionService.new(); expect(pixel_thresholds.set_profile(pixel_profile), "inherited Pixel v3 profile remains valid without recalibration")
	expect(absf(pixel_thresholds._back_threshold() - 1.244506) <= 0.001 and absf(pixel_thresholds._forward_threshold() - 1.546188) <= 0.001 and absf(pixel_thresholds._runtime_snap_threshold() - 37.108512) <= 0.002 and is_equal_approx(pixel_thresholds._snap_axis_tolerance(), 0.78) and is_equal_approx(pixel_thresholds._snap_polarity_tolerance(), 0.62) and is_equal_approx(pixel_thresholds._gyro_threshold(), 0.60) and is_equal_approx(pixel_thresholds._snap_gyro_threshold(), 0.60) and is_equal_approx(pixel_thresholds._gyro_threshold() * 0.65, 0.39), "Pixel v25 keeps the strict runtime threshold and raises only snap axis/polarity floors to .78/.62")
	expect(is_equal_approx(MotionService.RUNTIME_COCK_MIN_IMPULSE_FACTOR, 0.045) and is_equal_approx(MotionService.RUNTIME_SNAP_MIN_IMPULSE_FACTOR, 0.055), "capture build restores the physically known v18 sweep energy: cock 4.5% and snap 5.5%")
	var pixel_axis := Vector3(-0.8526, 0.2737, -0.4452).normalized()
	var ramped_pixel_gesture := MotionService.new(); ramped_pixel_gesture.set_profile(pixel_profile)
	ramped_pixel_gesture.queue_sample(_motion_sample(-pixel_axis * 1.10, Vector3(0, 0, 0.61)))
	var weak_cock := ramped_pixel_gesture.update(0.04, true, false)
	var ramped_cock := _physical_back_sweep(ramped_pixel_gesture, 1.20, 3)
	ramped_pixel_gesture.queue_sample(_motion_sample(pixel_axis * 1.00, Vector3(0, 0, 0.40)))
	var weak_snap := ramped_pixel_gesture.update(0.05, true, false)
	var ramped_snap := _runtime_sweep(ramped_pixel_gesture, pixel_axis * 80.0, Vector3(0, 0, 0.61), 3)
	expect(not weak_cock.cast_arm and ramped_cock.cast_arm and float(weak_snap.cast_quality) == 0.0 and float(ramped_snap.cast_quality) > 0.0, "a sub-v24 snap stays inert, then a shaped runtime-threshold sweep casts without a quiet gap")
	var spike_motion := MotionService.new(); spike_motion.set_profile(pixel_profile)
	var one_cock_spike := _physical_back_sweep(spike_motion, 1.20, 1)
	var two_cock_spikes := _physical_back_sweep(spike_motion, 1.20, 1)
	var deliberate_cock := _physical_back_sweep(spike_motion, 1.20, 1)
	var one_snap_spike := _runtime_sweep(spike_motion, pixel_axis * 80.0, Vector3(0, 0, 0.61), 1)
	var two_snap_spikes := _runtime_sweep(spike_motion, pixel_axis * 80.0, Vector3(0, 0, 0.61), 1)
	var deliberate_snap := _runtime_sweep(spike_motion, pixel_axis * 80.0, Vector3(0, 0, 0.61), 1)
	expect(not one_cock_spike.cast_arm and not two_cock_spikes.cast_arm and deliberate_cock.cast_arm and float(one_snap_spike.cast_quality) == 0.0 and float(two_snap_spikes.cast_quality) == 0.0 and float(deliberate_snap.cast_quality) > 0.0, "runtime cock and snap require three deliberate directional samples rather than one/two-frame spikes")
	var cock_gap_reset := MotionService.new(); cock_gap_reset.set_profile(pixel_profile)
	var cock_before_gap := _physical_back_sweep(cock_gap_reset, 1.20, 2)
	cock_gap_reset.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); cock_gap_reset.update(0.01, true, false)
	var cock_after_gap_two := _physical_back_sweep(cock_gap_reset, 1.20, 2)
	var cock_after_gap_three := _physical_back_sweep(cock_gap_reset, 1.20, 1)
	expect(not cock_before_gap.cast_arm and not cock_after_gap_two.cast_arm and cock_after_gap_three.cast_arm, "an exact-zero cock frame clears partial sweep credit before the next three-sample burst")
	var snap_gap_reset := MotionService.new(); snap_gap_reset.set_profile(pixel_profile)
	_physical_back_sweep(snap_gap_reset)
	var snap_before_gap := _runtime_sweep(snap_gap_reset, pixel_axis * 80.0, Vector3(0, 0, 0.61), 2, 0.03)
	snap_gap_reset.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); snap_gap_reset.update(0.01, true, false)
	var snap_after_gap_two := _runtime_sweep(snap_gap_reset, pixel_axis * 80.0, Vector3(0, 0, 0.61), 2, 0.03)
	var snap_after_gap_three := _runtime_sweep(snap_gap_reset, pixel_axis * 80.0, Vector3(0, 0, 0.61), 1, 0.03)
	expect(float(snap_before_gap.cast_quality) == 0.0 and float(snap_after_gap_two.cast_quality) == 0.0 and float(snap_after_gap_three.cast_quality) > 0.0, "an exact-zero snap frame clears partial credit without disarming the cast, so a new three-sample burst casts within the runtime window")
	var low_impulse := MotionService.new(); low_impulse.set_profile(pixel_profile)
	_physical_back_sweep(low_impulse)
	var low_impulse_snap := _runtime_sweep(low_impulse, pixel_axis * 1.55, Vector3(0, 0, 0.61), 6, 0.01)
	expect(float(low_impulse_snap.cast_quality) == 0.0, "near-threshold multi-frame snap without enough capped impulse remains inert")
	var cock_gyro_recovery := MotionService.new(); cock_gyro_recovery.set_profile(pixel_profile)
	cock_gyro_recovery.diagnostics = {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
	var recovery_cock_vector := cock_gyro_recovery._back_axis_direction() * cock_gyro_recovery._physical_cock_threshold() * 1.20
	_runtime_sweep(cock_gyro_recovery, recovery_cock_vector, Vector3(0, 0, 0.10), 3)
	# The first sweep had a low gyro and its final frame can recover once gyro clears.
	var recovered_cock_same_burst := _runtime_sweep(cock_gyro_recovery, recovery_cock_vector, Vector3(0, 0, 0.72), 1)
	var cock_recovery_counts: Dictionary = cock_gyro_recovery.get_diagnostics()
	expect(recovered_cock_same_burst.cast_arm and int(cock_recovery_counts.cock_attempts) == 1 and int(cock_recovery_counts.reasons.gyro) == 1, "an above-threshold cock gyro miss can recover on a later valid frame in the same rightward burst with one attempt/failure")
	var varied_pixel_snap := MotionService.new(); varied_pixel_snap.set_profile(pixel_profile)
	var varied_left_direction := Vector3(-0.20, 0.98, 0.0).normalized()
	var varied_match := varied_left_direction.dot(pixel_axis)
	var varied_polarity := varied_left_direction.dot(MotionService.RIGHT_HANDED_FORWARD_AXIS)
	_physical_back_sweep(varied_pixel_snap)
	var varied_pixel_rejected := _runtime_sweep(varied_pixel_snap, varied_left_direction * 3.0, Vector3(0, 0, 0.61))
	var varied_pixel_recovered := _runtime_sweep(varied_pixel_snap, pixel_axis * 80.0, Vector3(0, 0, 0.61), 3)
	expect(varied_match >= 0.4216 and varied_match < 0.62 and varied_polarity >= 0.081 and float(varied_pixel_rejected.cast_quality) == 0.0 and float(varied_pixel_recovered.cast_quality) > 0.0, "a below-.62 varied snap remains rejected while a later strict-axis frame recovers in the same burst")
	var below_axis_direction := (pixel_axis * 0.30 + Vector3(-0.305, -0.952, 0.0) * 0.954).normalized()
	var gyro_recovery := MotionService.new(); gyro_recovery.set_profile(pixel_profile)
	_physical_back_sweep(gyro_recovery)
	_runtime_sweep(gyro_recovery, pixel_axis * 80.0, Vector3(0, 0, 0.10), 3)
	expect(float(_runtime_sweep(gyro_recovery, pixel_axis * 80.0, Vector3(0, 0, 0.61), 1).cast_quality) > 0.0, "an above-threshold snap gyro miss can recover on a later valid frame after shape buildup")
	var below_axis_snap := MotionService.new(); below_axis_snap.set_profile(pixel_profile)
	_physical_back_sweep(below_axis_snap)
	expect(float(_runtime_sweep(below_axis_snap, below_axis_direction * 3.0, Vector3(0, 0, 0.61)).cast_quality) == 0.0, "a snap below the restored .62 learned-axis gate remains rejected")
	var polarity_profile := pixel_profile.duplicate(true); polarity_profile.forward_axis = [-0.50, 0.866, 0.0]
	var wrong_polarity_snap := MotionService.new(); wrong_polarity_snap.set_profile(polarity_profile)
	_physical_back_sweep(wrong_polarity_snap)
	expect(float(_runtime_sweep(wrong_polarity_snap, Vector3(0.05, 0.9987, 0.0) * 3.0, Vector3(0, 0, 0.61)).cast_quality) == 0.0, "a learned-axis-compatible snap with the wrong physical left polarity remains rejected")
	var fast_timing := MotionService.new(); fast_timing.set_profile(pixel_profile)
	_physical_back_sweep(fast_timing)
	var fast_timing_cast := _runtime_sweep(fast_timing, pixel_axis * 80.0, Vector3(0, 0, 0.61), 3, 0.06)
	var late_timing := MotionService.new(); late_timing.set_profile(pixel_profile)
	_physical_back_sweep(late_timing)
	var late_timing_cast := _runtime_sweep(late_timing, pixel_axis * 80.0, Vector3(0, 0, 0.61), 3, 0.18)
	var expired_timing := MotionService.new(); expired_timing.set_profile(pixel_profile)
	_physical_back_sweep(expired_timing)
	var expired_timing_cast := _runtime_sweep(expired_timing, pixel_axis * 80.0, Vector3(0, 0, 0.61), 3, 0.22)
	var fast_distance_session := FishingSession.new(); fast_distance_session.arm_cast(); fast_distance_session.release_cast(float(fast_timing_cast.cast_quality))
	var late_distance_session := FishingSession.new(); late_distance_session.arm_cast(); late_distance_session.release_cast(float(late_timing_cast.cast_quality))
	expect(float(fast_timing_cast.cast_quality) >= 0.99 and float(late_timing_cast.cast_quality) > 0.0 and float(late_timing_cast.cast_quality) < float(fast_timing_cast.cast_quality) and float(expired_timing_cast.cast_quality) == 0.0 and fast_distance_session.cast_distance_m > late_distance_session.cast_distance_m, "runtime reversal timing gives full fast casts, short late casts, and rejects over-.65-second reversals")
	var switched := _calibrated_motion(); switched.set_left_handed(true)
	expect(switched.left_handed and not switched.is_calibrated() and switched.calibration_phase == "settling", "switching handedness deliberately clears a v3-compatible profile and starts calibration")
	var robust_gyro := MotionService.new(); robust_gyro._calibration_examples = [{"gyro_peak": 0.42}, {"gyro_peak": 8.0}]
	expect(is_equal_approx(robust_gyro._robust_gyro_peak(), 0.42), "two practice casts use the lower gyro peak to reject a one-off outlier")
	var diagnostic_motion := _calibrated_motion(); diagnostic_motion.queue_sample(_motion_sample(Vector3(12.0, 100.0, 0), Vector3(0, 0, 0.72))); diagnostic_motion.update(0.05, true, false)
	var diagnostic_counts: Dictionary = diagnostic_motion.get_diagnostics()
	expect(diagnostic_counts.has("cock_attempts") and diagnostic_counts.has("reasons") and not str(diagnostic_counts).contains("Vector3"), "motion diagnostics keep derived counters/reasons without raw sensor vectors")
	var still_motion := _calibrated_motion(); still_motion.reset_gesture(); still_motion.diagnostics = {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
	expect(not still_motion._new_candidate("cock", 0.0, still_motion._back_threshold()), "zero directional projection cannot enter a cock candidate")
	for frame in range(1200): still_motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); still_motion.update(0.05, true, true)
	var still_counts: Dictionary = still_motion.get_diagnostics()
	expect(int(still_counts.cock_attempts) == 0 and int(still_counts.hook_attempts) == 0 and int(still_counts.completed_casts) == 0 and int(still_counts.reasons.linear) + int(still_counts.reasons.axis) + int(still_counts.reasons.polarity) + int(still_counts.reasons.gyro) + int(still_counts.reasons.timeout) == 0, "60 seconds of still samples creates no gesture attempts or failure counts: %s" % str(still_counts))
	var burst_motion := _calibrated_motion(); burst_motion.diagnostics = {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
	for frame in range(4): burst_motion.queue_sample(_motion_sample(Vector3(12.0, 100.0, 0), Vector3(0, 0, 0.72))); burst_motion.update(0.05, true, false)
	var burst_counts: Dictionary = burst_motion.get_diagnostics()
	expect(int(burst_counts.cock_attempts) == 1 and int(burst_counts.reasons.linear) + int(burst_counts.reasons.axis) + int(burst_counts.reasons.polarity) == 1, "one off-axis/under-threshold candidate burst records one attempt/reason across high frames")
	var quiet_cock_recovery := _calibrated_motion()
	quiet_cock_recovery.queue_sample(_motion_sample(Vector3(12.0, 100.0, 0), Vector3(0, 0, 0.72)))
	quiet_cock_recovery.update(0.05, true, false)
	quiet_cock_recovery.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO))
	quiet_cock_recovery.update(0.05, true, false)
	var recovered_cock := _physical_back_sweep(quiet_cock_recovery)
	var recovered_cast := _learned_snap_sweep(quiet_cock_recovery)
	expect(recovered_cock.cast_arm and float(recovered_cast.cast_quality) > 0.0, "a zero quiet frame clears a rejected cock burst so the next valid cock and snap cast")
	var hook_burst := _calibrated_motion(); hook_burst.diagnostics = {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
	for frame in range(4): hook_burst.queue_sample(_motion_sample(Vector3(1.35, 0, 0), Vector3(0, 0, 0.4))); hook_burst.update(0.05, false, true)
	expect(int(hook_burst.get_diagnostics().hook_attempts) == 1, "one hook candidate burst counts one hook attempt")
	var two_window_hook := _calibrated_motion()
	# The first bite window receives a deliberately wrong-polarity high burst;
	# ending that window must clear its candidate latch without needing a quiet
	# sample, so the next window sees its first real hook.
	two_window_hook.queue_sample(_motion_sample(Vector3(-1.35, 0, 0), Vector3(0, 0, 0.4)))
	expect(not two_window_hook.update(0.05, false, true).hook, "first hook window rejects a wrong-polarity candidate")
	two_window_hook.queue_sample(_motion_sample(Vector3(-1.35, 0, 0), Vector3(0, 0, 0.4)))
	two_window_hook.update(0.05, false, false)
	expect(_hook_sweep(two_window_hook).hook and int(two_window_hook.get_diagnostics().hook_attempts) == 1, "a prior opposite hook-window burst cannot suppress the first deliberate hook candidate in the next window")
	var calibration_reject := MotionService.new()
	calibration_reject.begin_calibration()
	for frame in range(3):
		calibration_reject.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO))
		calibration_reject.update(0.25, false, false)
	calibration_reject.queue_sample(_motion_sample(Vector3(-3.4, -5.2, -1.8)))
	calibration_reject.update(0.01, false, false)
	expect(calibration_reject.calibration_phase.ends_with("_back") and calibration_reject.calibration_progress == 0, "reversed diagonal left snap is rejected during right-cock calibration")
	var diagonal_motion := _diagonal_motion()
	expect(diagonal_motion.is_calibrated() and float(diagonal_motion.profile.forward_axis[0]) < -0.48, "diagonal signed right-cock/left-snap examples calibrate a compatible profile")
	var diagonal_cock := Vector3(4.5, 4.5, 1.5)
	var diagonal_arm := _physical_back_sweep(diagonal_motion)
	var diagonal_cast := _learned_snap_sweep(diagonal_motion)
	expect(diagonal_arm.cast_arm and float(diagonal_cast.cast_quality) > 0.0, "natural diagonal right cock then left snap passes learned-axis recognition without the old narrow X cone")
	var residual_cock_motion := _calibrated_motion()
	var residual_arm := _physical_back_sweep(residual_cock_motion)
	for residual in [Vector3(2.5, 0, 0), Vector3(2.1, 0, 0), Vector3(1.6, 0, 0), Vector3(1.2, 0, 0)]:
		residual_cock_motion.queue_sample(_motion_sample(residual, Vector3(0, 0, 0.45)))
		residual_cock_motion.update(0.04, true, false)
	var residual_snap := _learned_snap_sweep(residual_cock_motion)
	expect(residual_arm.cast_arm and float(residual_snap.cast_quality) > 0.0, "residual cock/tail frames with no quiet gap cannot consume the natural forward snap candidate")
	var opposite_recovery := _calibrated_motion()
	opposite_recovery.queue_sample(_motion_sample(Vector3(-3.2, 0, 0), Vector3(0, 0, 0.5)))
	var rejected_opposite := opposite_recovery.update(0.05, true, false)
	var recovered_arm := _physical_back_sweep(opposite_recovery)
	var recovered_snap := _learned_snap_sweep(opposite_recovery)
	expect(not rejected_opposite.cast_arm and recovered_arm.cast_arm and float(recovered_snap.cast_quality) > 0.0, "an opposite-direction burst cannot suppress the next correct cock/snap candidate")
	var off_axis_multi := _calibrated_motion()
	for frame in range(4):
		off_axis_multi.queue_sample(_motion_sample(Vector3(0, 3.5, 0), Vector3(0, 0, 0.5)))
		off_axis_multi.update(0.05, true, false)
	expect(int(off_axis_multi.get_diagnostics().completed_casts) == 2 and not bool(off_axis_multi.update(0.01, true, false).cast_arm), "off-axis multi-frame energy cannot arm or cast")
	var diagonal_right_snap := _diagonal_motion()
	_physical_back_sweep(diagonal_right_snap)
	var right_snap_event := _runtime_sweep(diagonal_right_snap, diagonal_cock * 1.70)
	expect(float(right_snap_event.cast_quality) == 0.0, "rightward diagonal snap remains rejected after cock")
	var diagonal_off_axis := _diagonal_motion()
	_physical_back_sweep(diagonal_off_axis)
	var diagonal_off_axis_event := _runtime_sweep(diagonal_off_axis, Vector3(-0.10, 0.0, -1.0).normalized() * 12.0)
	expect(float(diagonal_off_axis_event.cast_quality) == 0.0, "left-polarity diagonal noise below the snap axis floor remains rejected")
	var diagonal_hook_motion := _diagonal_motion()
	var diagonal_hook := _hook_sweep(diagonal_hook_motion)
	expect(diagonal_hook.hook, "deliberate diagonal right hook uses the signed physical direction without the old narrow X cone")
	var diagonal_wrong_hook := _diagonal_motion()
	diagonal_wrong_hook.queue_sample(_motion_sample(Vector3(-1.6, -2.45, -0.85), Vector3(0, 0, 0.5)))
	expect(not diagonal_wrong_hook.update(0.05, false, true).hook, "left diagonal snap remains rejected as a hook")
	var diagonal_off_axis_hook := _diagonal_motion()
	diagonal_off_axis_hook.queue_sample(_motion_sample(Vector3(0.10, -0.74, 0.84), Vector3(0, 0, 0.5)))
	expect(not diagonal_off_axis_hook.update(0.05, false, true).hook, "right-polarity off-axis hook still fails the learned-axis match")
	motion.queue_sample(_motion_sample(Vector3(0.35, 0, 0), Vector3(0, 0, 0.05)))
	var noise := motion.update(0.05, true, false)
	expect(not noise.cast_arm and float(noise.cast_quality) == 0.0, "noise does not arm a cast")
	var wrong_order_motion := _calibrated_motion()
	var wrong_order := _runtime_sweep(wrong_order_motion, Vector3(-4.2, 0, 0))
	expect(not wrong_order.cast_arm and float(wrong_order.cast_quality) == 0.0, "left snap without a right cock is rejected")
	var wrong_direction_motion := _calibrated_motion()
	var wrong_direction := _runtime_sweep(wrong_direction_motion, Vector3(0, 3.5, 0))
	expect(not wrong_direction.cast_arm and float(wrong_direction.cast_quality) == 0.0, "off-axis motion is rejected")
	var reversed_motion := _calibrated_motion()
	var slow_back := _physical_back_sweep(reversed_motion)
	var reversed_snap := _runtime_sweep(reversed_motion, Vector3(4.2, 0, 0))
	expect(slow_back.cast_arm and float(reversed_snap.cast_quality) == 0.0, "rightward snap after a right cock is rejected")
	var slow_motion := _calibrated_motion()
	_physical_back_sweep(slow_motion)
	var slow_snap := _learned_snap_sweep(slow_motion, 80.0, 3, 0.08)
	expect(float(slow_snap.cast_quality) > 0.0, "right cock then left snap arms and casts")
	var fast_motion := _calibrated_motion()
	_physical_back_sweep(fast_motion)
	var fast_snap := _learned_snap_sweep(fast_motion, 80.0, 3, 0.06)
	expect(float(slow_snap.cast_quality) < float(fast_snap.cast_quality), "faster accepted snap has higher quality")
	var slow_session := FishingSession.new(); slow_session.arm_cast(); slow_session.release_cast(float(slow_snap.cast_quality))
	var fast_session := FishingSession.new(); fast_session.arm_cast(); fast_session.release_cast(float(fast_snap.cast_quality))
	expect(slow_session.cast_distance_m < fast_session.cast_distance_m, "faster snap maps to farther cast distance")
	var too_slow_motion := _calibrated_motion()
	_physical_back_sweep(too_slow_motion)
	var too_slow := _learned_snap_sweep(too_slow_motion, 80.0, 3, 0.22)
	expect(float(too_slow.cast_quality) == 0.0, "slow back-to-snap transition is rejected")
	var hook_motion := _calibrated_motion()
	var hook_event := _hook_sweep(hook_motion)
	var hook_session := FishingSession.new(); hook_session.state = FishingSession.State.HOOK_WINDOW
	expect(hook_event.hook and hook_session.set_hook() and int(hook_event.hook_sweep_samples) >= 3 and not str(hook_event).contains("Vector3"), "smaller calibrated right gesture hooks only after a derived three-sample sweep")
	var wrong_hook_motion := _calibrated_motion()
	wrong_hook_motion.queue_sample(_motion_sample(Vector3(-1.35, 0, 0), Vector3(0, 0, 0.4)))
	var wrong_hook := wrong_hook_motion.update(0.05, false, true)
	expect(not wrong_hook.hook, "left snap is rejected as a hook gesture")
	var off_axis_hook_motion := _calibrated_motion()
	off_axis_hook_motion.queue_sample(_motion_sample(Vector3(0, 1.6, 0), Vector3(0, 0, 0.4)))
	var off_axis_hook := off_axis_hook_motion.update(0.05, false, true)
	expect(not off_axis_hook.hook, "off-axis movement is rejected as a hook gesture")
	motion.queue_sample(_motion_sample(Vector3(1.35, 0, 0), Vector3(0, 0, 0.4)))
	var inactive_hook := motion.update(0.05, false, false)
	expect(not inactive_hook.hook, "hook gesture is inactive outside the hook window contract")
	var sensitivity_motion := _calibrated_motion()
	sensitivity_motion.sensitivity = 1.5
	var easier_back := _physical_back_sweep(sensitivity_motion)
	expect(easier_back.cast_arm, "larger sensitivity lowers learned motion thresholds")

	var fight_motion := _calibrated_motion()
	var pull_pose := Vector3(0, -9.8, 0)
	var left_lower_pose := Vector3(-3.4, -9.19, 0)
	fight_motion.begin_fight(pull_pose)
	fight_motion.queue_sample({"gravity": pull_pose, "accelerometer": pull_pose, "gyro": Vector3(0, 0, 0.5)})
	var shake := fight_motion.update(0.25, false, false, true)
	expect(not shake.fight_lower and not shake.fight_pull and float(shake.fight_load) >= 0.95, "right hook pose begins a continuous pull without a false marker")
	fight_motion.queue_sample({"gravity": Vector3(0, -7.0, 6.8), "accelerometer": Vector3(0, -7.0, 6.8), "gyro": Vector3(0, 0, 0.5)})
	var pitch_only := fight_motion.update(0.25, false, false, true)
	expect(not pitch_only.fight_lower and float(pitch_only.fight_load) >= 0.95, "pitch/YZ-only pose cannot ease tension")
	fight_motion.queue_sample({"gravity": Vector3(3.4, -9.19, 0), "accelerometer": Vector3(3.4, -9.19, 0), "gyro": Vector3(0, 0, 0.5)})
	var rightward := fight_motion.update(0.25, false, false, true)
	expect(not rightward.fight_lower and float(rightward.fight_load) >= 0.95, "rightward pose cannot become an ease reference")
	fight_motion.queue_sample({"gravity": left_lower_pose, "accelerometer": left_lower_pose, "gyro": Vector3(0, 0, 0.05)})
	var no_gyro := fight_motion.update(0.25, false, false, true)
	expect(not no_gyro.fight_lower, "left ease pose without gyro corroboration is rejected")
	fight_motion.queue_sample({"gravity": left_lower_pose, "accelerometer": left_lower_pose, "gyro": Vector3(0, 0, 0.5)})
	var lowered := fight_motion.update(0.25, false, false, true)
	expect(lowered.fight_lower and lowered.fight_phase == "PULL BACK" and is_zero_approx(float(lowered.fight_load)), "left lower captures an exact zero-load ease reference")
	var pitch_after_lower_pose := Vector3(-3.4, -7.84, 4.81)
	fight_motion.queue_sample({"gravity": pitch_after_lower_pose, "accelerometer": pitch_after_lower_pose, "gyro": Vector3(0, 0, 0.5)})
	var pitch_after_lower := fight_motion.update(0.25, false, false, true)
	expect(not pitch_after_lower.fight_pull and float(pitch_after_lower.fight_load) <= 0.05, "pitch/YZ after lower cannot add signed load or emit pull")
	var quarter_pose := Vector3(-2.55, -9.46, 0)
	fight_motion.queue_sample({"gravity": quarter_pose, "accelerometer": quarter_pose, "gyro": Vector3(0, 0, 0.5)})
	var quarter_return := fight_motion.update(0.25, false, false, true)
	expect(not quarter_return.fight_pull and absf(float(quarter_return.fight_load) - 0.5) <= 0.06, "quarter rightward return maps through sqrt response to useful half load")
	var halfway_pose := Vector3(-1.7, -9.65, 0)
	fight_motion.queue_sample({"gravity": halfway_pose, "accelerometer": halfway_pose, "gyro": Vector3(0, 0, 0.5)})
	var halfway := fight_motion.update(0.25, false, false, true)
	expect(not halfway.fight_pull and float(halfway.fight_load) > 0.55 and float(halfway.fight_load) < 0.75, "monotonic signed mapping amplifies a halfway rightward return")
	var partial_right_return := Vector3(-0.8, -9.77, 0)
	fight_motion.queue_sample({"gravity": partial_right_return, "accelerometer": partial_right_return, "gyro": Vector3(0, 0, 0.5)})
	var pulled := fight_motion.update(0.25, false, false, true)
	expect(pulled.fight_pull and pulled.fight_phase == "LOWER ROD" and float(pulled.fight_load) > 0.60, "only directional rightward return marks a pull")
	fight_motion.queue_sample({"gravity": partial_right_return, "accelerometer": partial_right_return, "gyro": Vector3(0, 0, 0.5)})
	var fixed_pose_after_marker := fight_motion.update(0.25, false, false, true)
	expect(not fixed_pose_after_marker.fight_pull and is_equal_approx(float(fixed_pose_after_marker.fight_load), float(pulled.fight_load)), "guidance phase change cannot jump continuous load at a fixed pose")

func _test_admob_contract() -> void:
	var ads = AdMobService.new()
	ads.initialize()
	expect(ads.game_content_reserve_height() == 0.0, "native bottom banner owns safe inset")
	expect(ads.TEST_BANNER_AD_UNIT == "ca-app-pub-3940256099942544/6300978111", "Google test banner ID is pinned")
	expect("desktop fallback" in ads.describe_desktop_fallback(), "desktop fallback is documented")
	expect(not ads.available and not ads.initialized, "desktop ads remain inert")

	var initialization_callbacks: Array[Callable] = []
	var banner_requests: Array[bool] = []
	var sequenced_ads := AdMobService.new(
		func(on_complete: Callable): initialization_callbacks.append(on_complete),
		func(): banner_requests.append(true)
	)
	sequenced_ads.begin_sdk_initialization_for_test()
	expect(sequenced_ads.consent_state == "sdk_initializing" and initialization_callbacks.size() == 1 and banner_requests.is_empty(), "banner waits for SDK initialization completion")
	var stale_callback := initialization_callbacks[0]
	sequenced_ads.begin_sdk_initialization_for_test()
	stale_callback.call(null)
	expect(banner_requests.is_empty() and not sequenced_ads.initialized, "reinitialize destroys and invalidates a pending SDK callback")
	expect(initialization_callbacks.size() == 2 and banner_requests.is_empty(), "reinitialize creates one current SDK callback")
	stale_callback.call(null)
	expect(banner_requests.is_empty(), "stale SDK callback remains inert after restart")
	initialization_callbacks[0].call(null)
	initialization_callbacks[1].call(null)
	expect(sequenced_ads.consent_state == "banner_requested" and sequenced_ads.initialized and banner_requests.size() == 1, "SDK completion requests exactly one native banner")
	initialization_callbacks[1].call(null)
	expect(banner_requests.size() == 1, "duplicate SDK completion callback is ignored")

func _test_physical_cast_profile_motion() -> void:
	var pixel_profile := {"forward_axis": [-0.8526, 0.2737, -0.4452], "back_peak": 2.1457, "forward_peak": 3.6814, "gyro_peak": 4.2315, "transition_seconds": 0.375, "noise_floor": 0.6437, "direction_tolerance": 0.62}
	var pixel := MotionService.new()
	expect(pixel.set_profile(pixel_profile), "inherited right-handed Pixel v3 profile remains valid without recalibration")
	expect(is_equal_approx(MotionService.RUNTIME_PHYSICAL_COCK_THRESHOLD_FACTOR, 6.0) and is_equal_approx(MotionService.RUNTIME_SNAP_THRESHOLD_FACTOR, 24.0) and absf(pixel._back_threshold() - 1.244506) <= 0.001 and absf(pixel._physical_cock_threshold() - 7.467036) <= 0.002 and absf(pixel._forward_threshold() - 1.546188) <= 0.001 and absf(pixel._runtime_snap_threshold() - 37.108512) <= 0.002 and is_equal_approx(pixel._gyro_threshold(), 0.60), "physical cock remains 6x while v24 requires a 24x learned-axis runtime snap threshold and unchanged gyro")
	expect(is_equal_approx(MotionService.RUNTIME_COCK_MIN_IMPULSE_FACTOR, 0.045) and is_equal_approx(MotionService.RUNTIME_SNAP_MIN_IMPULSE_FACTOR, 0.055) and MotionService.RUNTIME_SWEEP_MIN_SAMPLES == 3, "physical cock preserves the v18 three-sample .045 sweep while snap preserves .055")

	var under_six := MotionService.new(); under_six.set_profile(pixel_profile)
	var under_event := _runtime_sweep(under_six, Vector3(7.40, 2.0, 0.0), Vector3(0, 0, 0.72), 4)
	expect(not under_event.cast_arm, "rightward cock below the 6x physical threshold remains inert")
	var wrong_physical_side := MotionService.new(); wrong_physical_side.set_profile(pixel_profile)
	var wrong_side_event := _runtime_sweep(wrong_physical_side, Vector3(-11.0, 4.0, 0.0), Vector3(0, 0, 0.72), 4)
	expect(not wrong_side_event.cast_arm, "leftward energy cannot arm a right-handed physical cock")

	# This is intentionally off the learned 3D back axis but remains a natural
	# signed-right cock: the physical-X alignment clears .18 and the X projection
	# clears the 6x threshold. The opposite snap still uses the learned profile.
	var natural := MotionService.new(); natural.set_profile(pixel_profile)
	var natural_cock := Vector3(10.0, 30.0, 0.0)
	var learned_back_axis := -Vector3(pixel_profile.forward_axis[0], pixel_profile.forward_axis[1], pixel_profile.forward_axis[2]).normalized()
	expect(natural_cock.normalized().dot(learned_back_axis) < float(pixel_profile.direction_tolerance), "natural physical cock fixture is intentionally outside the learned back-axis cone")
	var natural_arm := _runtime_sweep(natural, natural_cock, Vector3(0, 0, 0.72), 3)
	var natural_snap := _learned_snap_sweep(natural, 80.0, 3, 0.04)
	expect(natural_arm.cast_arm and float(natural_snap.cast_quality) > 0.0 and float(natural_snap.snap_projection) >= natural._runtime_snap_threshold() and float(natural_snap.snap_axis_match) >= 0.62 and float(natural_snap.snap_polarity_match) >= 0.18 and float(natural_snap.snap_gyro) >= 0.60 and float(natural_snap.reversal_seconds) > 0.0 and float(natural_snap.cock_projection) >= natural._physical_cock_threshold() and not str(natural_snap).contains("Vector3"), "6x signed physical cock arms and an accepted v24 cast exposes only derived final-snap and reversal telemetry")
	var below_runtime := MotionService.new(); below_runtime.set_profile(pixel_profile); _physical_back_sweep(below_runtime, 1.25, 3, 0.04)
	var below_runtime_snap := _learned_snap_sweep(below_runtime, below_runtime._runtime_snap_threshold() * 0.98, 3, 0.04)
	expect(float(below_runtime_snap.cast_quality) == 0.0, "a shaped learned-axis snap below the v24 runtime threshold remains rejected")
	var captured_axis := [0.9171, 0.8203, 0.8413, 0.8589, 0.9712, 0.9623, 0.9949, 0.9804, 0.9939, 0.9468]
	var captured_polarity := [0.8989, 0.6668, 0.712, 0.6943, 0.8435, 0.8699, 0.8113, 0.858, 0.8989, 0.8445]
	for index in range(captured_axis.size()):
		expect(float(captured_axis[index]) >= MotionService.RUNTIME_SNAP_AXIS_MIN and float(captured_polarity[index]) >= MotionService.RUNTIME_SNAP_POLARITY_MIN, "each of the ten replay-derived intended snap fixtures clears the v25 axis/polarity floors")
	expect(is_equal_approx(captured_axis.min(), 0.8203) and is_equal_approx(captured_polarity.min(), 0.6668), "replay-derived intended snap minima are retained as scalar evidence for the new floors")
	var false_signature := MotionService.new(); false_signature.set_profile(pixel_profile); _physical_back_sweep(false_signature, 1.25, 3, 0.04)
	var false_direction := Vector3(-0.51, 0.858, -0.043).normalized()
	var false_event := _runtime_sweep(false_signature, false_direction * 80.0, Vector3(0, 0, 0.72), 3, 0.04)
	var intentional_signature := MotionService.new(); intentional_signature.set_profile(pixel_profile); _physical_back_sweep(intentional_signature, 1.25, 3, 0.04)
	var intentional_event := _learned_snap_sweep(intentional_signature, 80.0, 3, 0.04)
	expect(is_equal_approx(MotionService.RUNTIME_SNAP_AXIS_MIN, 0.78) and is_equal_approx(MotionService.RUNTIME_SNAP_POLARITY_MIN, 0.62) and false_direction.dot(Vector3(pixel_profile.forward_axis[0], pixel_profile.forward_axis[1], pixel_profile.forward_axis[2]).normalized()) < MotionService.RUNTIME_SNAP_AXIS_MIN and false_direction.dot(MotionService.RIGHT_HANDED_FORWARD_AXIS) < MotionService.RUNTIME_SNAP_POLARITY_MIN and float(false_event.cast_quality) == 0.0 and float(intentional_event.cast_quality) > 0.0, "the observed v24-like .69/.51 false signature is rejected while intended replay-like snaps clear both v25 floors")

	var spike := MotionService.new(); spike.set_profile(pixel_profile)
	var one_spike := _physical_back_sweep(spike, 1.25, 1)
	var two_spike := _physical_back_sweep(spike, 1.25, 1)
	var three_spike := _physical_back_sweep(spike, 1.25, 1)
	expect(not one_spike.cast_arm and not two_spike.cast_arm and three_spike.cast_arm, "physical cock still rejects one/two-frame spikes before its third sweep sample")
	var gapped := MotionService.new(); gapped.set_profile(pixel_profile)
	_physical_back_sweep(gapped, 1.25, 2)
	gapped.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); gapped.update(0.01, true, false)
	var gapped_two := _physical_back_sweep(gapped, 1.25, 2)
	var gapped_three := _physical_back_sweep(gapped, 1.25, 1)
	expect(not gapped_two.cast_arm and gapped_three.cast_arm, "a quiet frame resets physical cock partial sweep credit")

	var mirrored := _left_calibrated_motion()
	var mirrored_arm := _physical_back_sweep(mirrored, 1.25, 3)
	var mirrored_snap := _learned_snap_sweep(mirrored, 80.0, 3, 0.04)
	expect(mirrored.left_handed and mirrored_arm.cast_arm and float(mirrored_snap.cast_quality) > 0.0, "left-handed mode mirrors physical cock left while retaining its learned-axis snap right")

	var right_hook := MotionService.new(); right_hook.set_profile(pixel_profile)
	expect(_hook_sweep(right_hook).hook, "right-handed hook uses the signed physical-right back direction after a deliberate sweep")
	var wrong_hook := MotionService.new(); wrong_hook.set_profile(pixel_profile)
	wrong_hook.queue_sample(_motion_sample(Vector3(-1.50, 4.0, 0.0), Vector3(0, 0, 0.50)))
	expect(not wrong_hook.update(0.05, false, true).hook, "physical-left movement remains rejected during a right-handed hook window")
	var left_hook := _left_calibrated_motion()
	expect(_hook_sweep(left_hook).hook, "left-handed hook mirrors to physical-left after a deliberate sweep")
	var hook_shape := MotionService.new(); hook_shape.set_profile(pixel_profile)
	var one_hook_frame := _hook_sweep(hook_shape, 1.4, 1)
	var two_hook_frames := _hook_sweep(hook_shape, 1.4, 1)
	var third_hook_frame := _hook_sweep(hook_shape, 1.4, 1)
	expect(not one_hook_frame.hook and not two_hook_frames.hook and third_hook_frame.hook and int(third_hook_frame.hook_sweep_samples) >= 3, "hook recognition rejects one/two-frame impulses and accepts the third deliberate physical sweep sample")

	var fast := MotionService.new(); fast.set_profile(pixel_profile); _physical_back_sweep(fast, 1.25, 3, 0.04)
	var fast_cast := _learned_snap_sweep(fast, 80.0, 3, 0.04)
	var late := MotionService.new(); late.set_profile(pixel_profile); _physical_back_sweep(late, 1.25, 3, 0.04)
	var late_cast := _learned_snap_sweep(late, 80.0, 3, 0.18)
	var expired := MotionService.new(); expired.set_profile(pixel_profile); _physical_back_sweep(expired, 1.25, 3, 0.04)
	var expired_cast := _learned_snap_sweep(expired, 80.0, 3, 0.22)
	expect(float(fast_cast.cast_quality) >= 0.99 and float(late_cast.cast_quality) > 0.0 and float(late_cast.cast_quality) < float(fast_cast.cast_quality) and float(expired_cast.cast_quality) == 0.0, "physical cock retains .22s full quality, late short-cast, and over-.65s rejection timing")

	var still := MotionService.new(); still.set_profile(pixel_profile)
	for frame in range(1200): still.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); still.update(0.05, true, true)
	var counts: Dictionary = still.get_diagnostics()
	expect(int(counts.cock_attempts) == 0 and int(counts.hook_attempts) == 0 and int(counts.completed_casts) == 0 and int(counts.reasons.linear) + int(counts.reasons.axis) + int(counts.reasons.polarity) + int(counts.reasons.gyro) + int(counts.reasons.timeout) == 0, "60 seconds of still samples creates no physical cock/hook attempts or derived failures")

	var fight_motion := _calibrated_motion()
	var pull_pose := Vector3(0, -9.8, 0)
	fight_motion.begin_fight(pull_pose)
	fight_motion.queue_sample({"gravity": pull_pose, "accelerometer": pull_pose, "gyro": Vector3(0, 0, 0.5)})
	var raised := fight_motion.update(0.25, false, false, true)
	fight_motion.queue_sample({"gravity": Vector3(-3.4, -9.19, 0), "accelerometer": Vector3(-3.4, -9.19, 0), "gyro": Vector3(0, 0, 0.5)})
	var lowered := fight_motion.update(0.25, false, false, true)
	expect(float(raised.fight_load) >= 0.95 and lowered.fight_lower and is_zero_approx(float(lowered.fight_load)), "unchanged fight path still starts raised and recognizes signed leftward easing")

func _test_haptic_signatures() -> void:
	expect(HapticService.android_amplitude(-0.2) == 1 and HapticService.android_amplitude(0.0) == 1, "Android haptic amplitude has a nonzero lower bound")
	expect(HapticService.android_amplitude(0.5) == 128 and HapticService.android_amplitude(1.0) == 255 and HapticService.android_amplitude(2.0) == 255, "Android haptic amplitude maps and clamps to 1..255")
	var keys: Dictionary = {}
	for fish in FishDefinition.all_planned():
		var signature := str(fish.fight_pulse) + "|" + str(fish.fight_cycle_seconds)
		expect(not keys.has(signature), "planned fish signature and cadence are unique: " + fish.id)
		expect(fish.fight_cycle_seconds > 0.0, "planned fish has an intentional cadence: " + fish.id)
		keys[signature] = true
	var fired: Array[Dictionary] = []
	var haptics := HapticService.new(func(duration, amplitude): fired.append({"duration": duration, "amplitude": amplitude}))
	var bluegill := FishDefinition.bluegill()
	haptics.start_fight(bluegill)
	var max_pending := 0
	for frame in range(300):
		haptics.update_fight(0.01, bluegill, 0.2)
		max_pending = maxi(max_pending, haptics.pending.size())
	expect(max_pending <= HapticService.MAX_PENDING_PULSES, "fight queue remains bounded")
	expect(fired.size() >= 4 and fired.size() <= 6, "fight cadence avoids per-frame vibration spam")

	var high_fired: Array[Dictionary] = []
	var high_haptics := HapticService.new(func(duration, amplitude): high_fired.append({"duration": duration, "amplitude": amplitude}))
	high_haptics.start_fight(FishDefinition.all_planned()[1])
	for frame in range(60):
		high_haptics.update_fight(0.05, FishDefinition.all_planned()[1], 0.70)
	expect(high_haptics.warning_tier == "high" and high_fired.size() >= 6 and int(high_fired[0].duration) == 58, "high warning repeats on its universal cadence")

	var red_fired: Array[Dictionary] = []
	var red_haptics := HapticService.new(func(duration, amplitude): red_fired.append({"duration": duration, "amplitude": amplitude}))
	red_haptics.start_fight(FishDefinition.all_planned()[2])
	for frame in range(60):
		red_haptics.update_fight(0.05, FishDefinition.all_planned()[2], 0.95)
	expect(red_haptics.warning_tier == "red" and red_fired.size() >= 10 and int(red_fired[0].duration) == 90, "red warning repeats on its universal cadence")
	expect(red_fired.size() > high_fired.size(), "red warning cadence is faster than high across fish")
	var normal_max := _max_emitted_amplitude(fired)
	var high_max := _max_emitted_amplitude(high_fired)
	var red_max := _max_emitted_amplitude(red_fired)
	expect(normal_max < high_max and high_max < red_max and bluegill.fight_cycle_seconds > HapticService.HIGH_WARNING_CYCLE_SECONDS and HapticService.HIGH_WARNING_CYCLE_SECONDS > HapticService.RED_WARNING_CYCLE_SECONDS, "emitted haptic amplitude rises and warning interval shortens from normal to high to red")

	var reset_fired: Array[Dictionary] = []
	var reset_haptics := HapticService.new(func(duration, amplitude): reset_fired.append({"duration": duration, "amplitude": amplitude}))
	reset_haptics.start_fight(bluegill)
	reset_haptics.update_fight(0.23, bluegill, 0.70)
	reset_haptics.update_fight(0.30, bluegill, 0.70)
	expect(reset_haptics.warning_tier == "high" and reset_fired.size() == 2 and int(reset_fired[0].duration) == 58, "high tension overrides species rhythm")
	reset_fired.clear()
	reset_haptics.update_fight(0.01, bluegill, 0.95)
	reset_haptics.update_fight(0.30, bluegill, 0.95)
	expect(reset_haptics.warning_tier == "red" and reset_fired.size() == 2 and int(reset_fired[0].duration) == 90, "red tension emits urgent override")
	reset_fired.clear()
	reset_haptics.update_fight(0.01, bluegill, 0.2)
	expect(reset_haptics.warning_tier == "normal" and not reset_fired.is_empty() and int(reset_fired[0].duration) == 38, "falling tension restores species rhythm")

	var hook_fired: Array[Dictionary] = []
	var hook_haptics := HapticService.new(func(duration, amplitude): hook_fired.append({"duration": duration, "amplitude": amplitude}))
	hook_haptics.cue("hook")
	hook_haptics.start_fight(bluegill)
	hook_haptics.update_fight(0.01, bluegill, 0.2)
	expect(hook_fired.size() == 1 and int(hook_fired[0].duration) == 55, "hook cue does not overlap first fish phrase")
	hook_haptics.update_fight(0.22, bluegill, 0.2)
	expect(hook_fired.size() == 2 and int(hook_fired[1].duration) == 38, "species phrase begins after hook delay")
	var lull_fired: Array[Dictionary] = []
	var lull_haptics := HapticService.new(func(duration, amplitude): lull_fired.append({"duration": duration, "amplitude": amplitude}))
	var pike := FishDefinition.all_planned()[5]
	lull_haptics.start_fight(pike)
	lull_haptics.update_fight(0.22, pike, 0.20, 1.0) # Starts a two-pulse normal phrase.
	lull_haptics.update_fight(0.05, pike, 0.20, 0.20) # Enters a lull before its second pulse is due.
	expect(lull_fired.size() == 1 and lull_haptics.pending.is_empty(), "entering a normal-effort lull drops every unfinished fish pulse immediately")
	lull_haptics.update_fight(0.68, pike, 0.20, 1.0)
	expect(lull_fired.size() == 2 and int(lull_fired[1].duration) == 150 and lull_haptics.pending.size() == 1, "the resumed normal phrase starts fresh instead of replaying its stale second pulse")

	var before_disable := reset_fired.size()
	reset_haptics.set_enabled(false)
	for frame in range(120):
		reset_haptics.update_fight(0.01, bluegill, 0.95)
	expect(reset_haptics.pending.is_empty() and reset_fired.size() == before_disable, "disabled haptics clear and suppress pending cues")

	var bite_guard_fired: Array[Dictionary] = []
	var bite_guard := HapticService.new(func(duration, amplitude): bite_guard_fired.append({"duration": duration, "amplitude": amplitude}))
	bite_guard.cue("bite")
	bite_guard.tick(0.0)
	expect(bite_guard_fired.size() == 1 and bite_guard.is_motion_guarded(), "the first bite pulse starts a deterministic motion settle guard")
	bite_guard.tick(0.239)
	expect(bite_guard.is_motion_guarded(), "the first bite guard survives through its pulse duration plus settle margin")
	bite_guard.tick(0.002)
	expect(bite_guard_fired.size() == 2 and bite_guard.is_motion_guarded(), "the second bite pulse extends the motion guard through its own duration and settle margin")
	bite_guard.tick(0.404)
	expect(bite_guard.is_motion_guarded(), "the second bite guard remains active until its exact deterministic boundary")
	bite_guard.tick(0.002)
	expect(not bite_guard.is_motion_guarded(), "the motion guard expires deterministically after the final bite pulse settle interval")
	bite_guard.start_fight(bluegill)
	bite_guard.update_fight(0.23, bluegill, 0.20)
	expect(bite_guard.fighting and bite_guard.is_motion_guarded(), "fight phrase scheduling remains active while the sensor guard is only used for ready/hook motion")
	bite_guard.stop()
	bite_guard.cue("bite"); bite_guard.tick(0.0); bite_guard.set_enabled(false)
	expect(not bite_guard.is_motion_guarded() and bite_guard.pending.is_empty(), "disabling haptics clears any active motion guard immediately")
	bite_guard.set_enabled(true); bite_guard.cue("bite"); bite_guard.tick(0.0); bite_guard.stop()
	expect(not bite_guard.is_motion_guarded() and bite_guard.pending.is_empty(), "stopping haptics clears its sensor guard immediately")
	var guarded_hook_motion := _calibrated_motion()
	guarded_hook_motion.queue_sample(_motion_sample(Vector3(1.35, 0, 0), Vector3(0, 0, 0.5)))
	var hook_while_guarded := guarded_hook_motion.update(0.05, false, false)
	var hook_after_guard := _hook_sweep(guarded_hook_motion)
	expect(not hook_while_guarded.hook and hook_after_guard.hook, "the haptic guard can suppress hook recognition while the fight motion path remains independently enabled")

	var terminal: Array[Dictionary] = []
	var terminal_haptics := HapticService.new(func(duration, amplitude): terminal.append({"duration": duration, "amplitude": amplitude}))
	terminal_haptics.start_fight(bluegill)
	terminal_haptics.update_fight(0.01, bluegill, 0.2)
	terminal.clear()
	terminal_haptics.cue("caught")
	terminal_haptics.tick(1.0)
	var caught_signature := str(terminal)
	expect(not terminal_haptics.fighting and terminal.size() == 3, "caught stops the fight and emits a lift cue")
	terminal.clear()
	terminal_haptics.cue("escaped")
	terminal_haptics.tick(1.0)
	expect(terminal.size() == 1 and caught_signature != str(terminal), "escaped terminal cue is distinct")
	terminal.clear(); terminal_haptics.cue("hook_miss"); terminal_haptics.tick(1.0)
	expect(terminal.size() == 2 and str(terminal) != caught_signature, "hook miss has a distinct two-pulse cue")
	terminal.clear(); terminal_haptics.cue("cock"); terminal_haptics.tick(0.1)
	expect(terminal.size() == 1 and int(terminal[0].duration) == 22, "accepted cast cock has one subtle haptic cue")
	terminal.clear(); terminal_haptics.cue("capture_window"); terminal_haptics.tick(1.0)
	expect(terminal.size() == 2 and int(terminal[0].duration) == 32, "each explicit capture window has a distinct two-pulse haptic cue")
	terminal.clear(); terminal_haptics.cue("capture_complete"); terminal_haptics.tick(1.0)
	expect(terminal.size() == 3 and int(terminal[2].duration) == 78, "explicit capture completion has a distinct saved cue")
	var preview_guard := HapticService.new(); preview_guard.cue("bite"); preview_guard.tick(0.01)
	expect(preview_guard.motion_guard_seconds() >= HapticService.MOTION_SETTLE_SECONDS and preview_guard.is_motion_guarded(), "preview haptics expose their remaining motor-settle period for menu return protection")
	preview_guard.stop()
	expect(is_zero_approx(preview_guard.motion_guard_seconds()), "stopping a haptic channel clears only that channel after its guard has been captured")

func _test_project_source_settings() -> void:
	var config := ConfigFile.new()
	expect(config.load("res://project.godot") == OK, "project settings load")
	expect(config.get_value("android", "package/unique_name") == "com.tak.castandcrank", "Android package is correct")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	expect("orientation=1" in project_source, "portrait orientation is enabled")
	expect(config.get_value("input_devices", "sensors/enable_accelerometer"), "accelerometer enabled")
	expect(config.get_value("input_devices", "sensors/enable_gravity"), "gravity enabled")
	expect(config.get_value("input_devices", "sensors/enable_gyroscope"), "gyroscope enabled")
	var export_config := ConfigFile.new(); expect(export_config.load("res://export_presets.cfg") == OK, "export settings load")
	expect(export_config.get_value("preset.0.options", "permissions/internet"), "Internet permission enabled")
	expect(export_config.get_value("preset.0.options", "permissions/access_network_state"), "network-state permission enabled")
	expect(export_config.get_value("preset.0.options", "permissions/vibrate"), "Android VIBRATE permission enabled")
	expect(int(export_config.get_value("preset.0.options", "version/code")) == 29 and export_config.get_value("preset.0.options", "version/name") == "0.5.0-livingfish1", "living fish package version is bumped")
	expect(export_config.get_value("preset.0.options", "package/signed"), "debug package requests signing")
	expect(export_config.get_value("preset.0.options", "gradle_build/compress_native_libraries"), "native libraries are compressed")
	expect(export_config.get_value("preset.0.options", "architectures/arm64-v8a") and not export_config.get_value("preset.0.options", "architectures/armeabi-v7a") and not export_config.get_value("preset.0.options", "architectures/x86") and not export_config.get_value("preset.0.options", "architectures/x86_64"), "debug package exports arm64 only")
	var excluded := str(export_config.get_value("preset.0", "exclude_filter"))
	expect("build/**" in excluded and "reports/**" in excluded and "tools/**" in excluded and "art/ui_v1/mockups/**" in excluded and "art/ui_v1/runtime_source/catch-frame-clean-v01.png" in excluded and "art/ui_v1/runtime_source/bluegill-v01.png" in excluded and "art/ui_v1/runtime_source/app-icon-v01.png" in excluded and "art/ui_v1/runtime_source/records-screen-v01.png" in excluded and "art/ui_v1/runtime_source/rod-bend-strip-v01.png" in excluded and "addons/admob/internal/editor/**" in excluded and "addons/admob/internal/mock/**" in excluded and not "addons/admob/gdscript/src/mediation/**" in excluded, "tools, mockups, and superseded unreferenced masters are excluded while runtime mediation dependencies remain")
	expect(config.get_value("application", "config/icon") == "res://art/ui_v1/runtime_source/app-icon-runtime-512.png" and config.get_value("application", "boot_splash/image") == "res://art/ui_v1/runtime_source/loading-splash-v01.png", "optimized runtime icon and approved splash are configured")
	var runtime_assets := {
		"res://art/ui_v1/runtime_source/pine-lake-clean-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/cedar-river-clean-v02.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/pine-fish-atlas-v02.png": Vector2i(1024, 1536),
		"res://art/ui_v1/runtime_source/cedar-fish-atlas-v02.png": Vector2i(1024, 1536),
		"res://art/ui_v1/runtime/control-kit-alpha-v01.png": Vector2i(1024, 1536),
		"res://art/ui_v1/runtime_source/rod-bend-strip-v01.png": Vector2i(1536, 1024),
		"res://art/ui_v1/runtime_source/rod-bend-repacked-v02.png": Vector2i(1536, 1024),
		"res://art/ui_v1/runtime_source/bobber-v01.png": Vector2i(1230, 1278),
		"res://art/ui_v1/runtime_source/water-reaction-strip-v01.png": Vector2i(2172, 724),
		"res://art/ui_v1/runtime_source/catch-frame-clean-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/bluegill-v01.png": Vector2i(1536, 1024),
		"res://art/ui_v1/runtime_source/app-icon-v01.png": Vector2i(1254, 1254),
		"res://art/ui_v1/runtime_source/app-icon-runtime-512.png": Vector2i(512, 512),
		"res://art/ui_v1/runtime_source/loading-splash-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/records-screen-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/records-screen-v02.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/records-screen-v03-empty-slots.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/journal-detail-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/top-nav-strip-v01.png": Vector2i(1774, 887)
	}
	for asset_path in runtime_assets:
		var texture := load(asset_path) as Texture2D
		var image := texture.get_image() if texture else Image.new()
		expect(not image.is_empty() and image.get_size() == runtime_assets[asset_path], "runtime UI asset has the expected dimensions: " + asset_path)
	for transparent_asset in ["res://art/ui_v1/runtime_source/rod-bend-strip-v01.png", "res://art/ui_v1/runtime_source/bobber-v01.png", "res://art/ui_v1/runtime_source/water-reaction-strip-v01.png", "res://art/ui_v1/runtime_source/bluegill-v01.png"]:
		var transparent_texture := load(transparent_asset) as Texture2D
		var transparent_image := transparent_texture.get_image() if transparent_texture else Image.new()
		expect(transparent_image.detect_alpha() != Image.ALPHA_NONE, "runtime animated asset retains alpha: " + transparent_asset)
	for atlas_asset in ["res://art/ui_v1/runtime_source/pine-fish-atlas-v02.png", "res://art/ui_v1/runtime_source/cedar-fish-atlas-v02.png"]:
		var atlas_texture := load(atlas_asset) as Texture2D
		var atlas_image := atlas_texture.get_image() if atlas_texture else Image.new()
		var clear_boundaries := true
		for y in [511, 512, 1023, 1024]:
			for x in range(0, 1024, 16):
				if atlas_image.get_pixel(x, y).a != 0.0: clear_boundaries = false
		expect(not atlas_image.is_empty() and atlas_image.get_size() == Vector2i(1024, 1536) and atlas_image.get_pixel(0, 0).a == 0.0 and atlas_image.get_pixel(512, 768).a > 0.0 and clear_boundaries, "repacked fish atlas has transparent exact-cell boundaries and opaque per-row content: " + atlas_asset)
	var control_texture := load("res://art/ui_v1/runtime/control-kit-alpha-v01.png") as Texture2D
	var control_image := control_texture.get_image() if control_texture else Image.new()
	expect(not control_image.is_empty() and control_image.get_size() == Vector2i(1024, 1536) and control_image.get_pixel(0, 0).a == 0.0, "derived control-kit atlas retains transparent matte corners")
	var nav_texture := load("res://art/ui_v1/runtime_source/top-nav-strip-v01.png") as Texture2D
	var nav_image := nav_texture.get_image() if nav_texture else Image.new()
	expect(not nav_image.is_empty() and nav_image.get_size() == Vector2i(1774, 887) and nav_image.detect_alpha() == Image.ALPHA_NONE, "top navigation strip is one opaque authored runtime plate")
	var source := FileAccess.get_file_as_string("res://src/services/admob_service.gd")
	expect("ConsentInformation" in source and "MAX_AD_CONTENT_RATING_PG" in source and "failed_closed" in source and "game_content_reserve_height" in source and "OnInitializationCompleteListener" in source and "sdk_initializing" in source and "banner_requested" in source, "consent-first SDK-sequenced AdMob contract retained")
	var haptic_source := FileAccess.get_file_as_string("res://src/services/haptic_service.gd")
	expect("AndroidRuntime" in haptic_source and "getSystemService(\"vibrator\")" in haptic_source and "VibrationEffect" in haptic_source and "createOneShot" in haptic_source and "Build$VERSION" in haptic_source and "SDK_INT" in haptic_source and "VibrationAttributes" in haptic_source and "createForUsage" in haptic_source and "USAGE_MEDIA" in haptic_source and "AudioAttributes$Builder" in haptic_source and "USAGE_GAME" in haptic_source and "CONTENT_TYPE_SONIFICATION" in haptic_source and "vibrate(effect, _android_vibration_attributes)" in haptic_source and "vibrate(effect, _android_audio_attributes)" in haptic_source and "_android_vibrator.vibrate(maxi(1, duration_ms), _android_audio_attributes)" in haptic_source and "Input.vibrate_handheld" in haptic_source and "capture_window" in haptic_source and "capture_complete" in haptic_source, "Android explicit non-touch attributes and capture haptic cues are retained")
	expect("MOTION_SETTLE_SECONDS := 0.30" in haptic_source and "is_motion_guarded" in haptic_source and "motion_guard_seconds" in haptic_source and "_motion_guard_remaining" in haptic_source, "haptic pulses expose the deterministic sensor-settle guard for safe menu return")
	var main_source := FileAccess.get_file_as_string("res://src/ui/main.gd")
	var motion_source := FileAccess.get_file_as_string("res://src/services/motion_service.gd")
	var capture_source := FileAccess.get_file_as_string("res://src/services/cast_capture_service.gd")
	expect("randf()" in main_source and not "haptics.cue(\"cock\")" in main_source and "haptics.cue(\"bite\")" in main_source and "haptics.cue(\"hook\")" in main_source and "menu_motion_settle_remaining" in main_source and "MOTION_CAST_CANCEL reason=timeout" in main_source and "snap_projection=%.2f" in main_source and "cock_projection=%.2f" in main_source and "MOTION_HOOK state=REELING projection=%.2f alignment=%.2f gyro=%.2f sweep_samples=%d" in main_source, "physical arm selects a fresh weighted fish without motor feedback and menu return owns a deterministic motion settle guard")
	expect("PROFILE_HANDEDNESS_ALIGNMENT" in motion_source and "CALIBRATION_HANDEDNESS_ALIGNMENT" in motion_source and "RUNTIME_X_POLARITY_ALIGNMENT" in motion_source and "RUNTIME_PHYSICAL_COCK_THRESHOLD_FACTOR := 6.0" in motion_source and "RUNTIME_SNAP_THRESHOLD_FACTOR := 24.0" in motion_source and "RUNTIME_SNAP_AXIS_MIN := 0.78" in motion_source and "RUNTIME_SNAP_POLARITY_MIN := 0.62" in motion_source and "RUNTIME_HOOK_MIN_IMPULSE_FACTOR := 0.055" in motion_source and "_physical_cock_threshold" in motion_source and "_runtime_snap_threshold" in motion_source and "linear.dot(_back_axis_direction())" in motion_source and "_back_axis = _back_axis_direction()" in motion_source and "RUNTIME_SWEEP_MIN_SAMPLES" in motion_source and "RUNTIME_COCK_MIN_IMPULSE_FACTOR" in motion_source and "RUNTIME_SNAP_MIN_IMPULSE_FACTOR" in motion_source and is_equal_approx(MotionService.RUNTIME_COCK_MIN_IMPULSE_FACTOR, 0.045) and is_equal_approx(MotionService.RUNTIME_SNAP_MIN_IMPULSE_FACTOR, 0.055) and "_sweep_ready(\"hook\"" in motion_source and "hook_projection" in motion_source and "hook_sweep_samples" in motion_source and "_sweep_ready" in motion_source and "_snap_axis_tolerance" in motion_source and "_snap_polarity_tolerance" in motion_source and "_snap_gyro_threshold" in motion_source and "RUNTIME_FULL_REVERSAL_SECONDS" in motion_source and "RUNTIME_MAX_REVERSAL_SECONDS" in motion_source and "cast_cancel" in motion_source and "snap_projection" in motion_source and "_burst_failure_latched" in motion_source and "MOTION_FAIL stage=%s reason=%s count=%d" in motion_source and not "SNAP_MIN_AXIS_TOLERANCE" in motion_source and not "MOTION_FAIL linear=" in motion_source and not "MOTION_FAIL gyro=" in motion_source and "sqrt(raw_fight_load)" in motion_source, "v25 retains signed physical cock with replay-backed snap floors and derived-only three-sample hook telemetry")
	expect("CAST_COUNT := 10" in capture_source and "ACTIVE_WINDOW_SECONDS := 2.0" in capture_source and "REST_WINDOW_SECONDS := 1.0" in capture_source and "MAX_SAMPLES_PER_CAST" in capture_source and "completed" in capture_source and "accelerometer" in capture_source and "linear" in capture_source and not "print(" in capture_source, "raw samples are bounded and retained only by the explicit capture service without logging")
	expect(not "HOLD TO CAST" in main_source and not "SET HOOK" in main_source and not "SAFE BYPASS" in main_source and not "cast_rect" in main_source and not "reel_center" in main_source and not "InputEventScreenDrag" in main_source and not "_handle_drag" in main_source and not "reel_fallback" in main_source and "COCK RIGHT, THEN SNAP LEFT" in main_source and "FISH ON — WAIT FOR THE PULSES" in main_source and "BITE — PULL RIGHT" in main_source and "session.state == FishingSession.State.HOOK_WINDOW" in main_source and "TILT LEFT TO EASE" in main_source and "TILT RIGHT TO PULL" in main_source and "MOTION_FIGHT caught elapsed=" in main_source and "MOTION_FIGHT escaped elapsed=" in main_source and "_record_catch_once" in main_source and "records-screen-v03-empty-slots.png" in main_source and "journal-detail-v01.png" in main_source and "ROD_TIP_ANCHORS" in main_source and "_rod_tip_for_frame" in main_source and "RECORD 10 CASTS" in main_source and "cast_capture.is_active()" in main_source and "_start_cast_capture" in main_source and not "DIAGNOSTIC_AUTO_CAPTURE_ON_ANDROID" in main_source and "DisplayServer.get_display_safe_area" in main_source and "_virtual_safe_top" in main_source and "set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)" in main_source and "mouse_filter = Control.MOUSE_FILTER_STOP" in main_source and "font = ThemeDB.fallback_font" in main_source and "queue_redraw()" in main_source and "can_recast_from_motion" in main_source, "bite guard, safe top, terminal recast, and motion-only gameplay contracts remain explicit")
	expect("pine_lake_texture" in main_source and "cedar_river_texture" in main_source and "pine-fish-atlas-v02.png" in main_source and "cedar-fish-atlas-v02.png" in main_source and "_draw_fish_atlas_contained" in main_source and "largemouth_bass" in main_source and "channel_catfish" in main_source and "rainbow_trout" in main_source and "smallmouth_bass" in main_source and "northern_pike" in main_source and "row * 512" in main_source, "UI v2 maps all six fish IDs to the two runtime atlas row regions and both location plates")
	expect("MOTION FISHING" in main_source and not "s.fish.display_name.to_upper()], Vector2(48" in main_source, "gameplay chrome remains neutral and does not reveal the selected fish before catch")
	expect(not "catch-frame-clean-v01.png" in main_source and not "catch_frame_texture" in main_source and "FIRST CATCH" in main_source and "NEW BEST" in main_source and "MATCHED BEST" in main_source and "catch_prior_best_cm" in main_source, "catch reveal uses a scenic native plaque with prior-record status rather than a trophy frame")
	var records_source := main_source.get_slice("func _draw_records() -> void:", 1).get_slice("func _fish_definition", 0)
	expect("records-screen-v03-empty-slots.png" in main_source and "journal-detail-v01.png" in main_source and "UNDISCOVERED" in records_source and "_draw_fish_atlas_contained" in records_source and "_journal_page_rect" in records_source and "_journal_map_rect" in records_source and not "_text(\"CATCH RECORDS\"" in records_source and "journal_slot_rects" in records_source, "Records uses one opaque blank-slot master with only dynamic fish, discovery, and values")
	expect("_draw_location_card" in main_source and "pine_lake_texture" in main_source and "cedar_river_texture" in main_source and "locations_pine" in main_source and "locations_cedar" in main_source and "records_empty" in main_source and "_clear_capture_records" in main_source and "pine_bass_catch" in main_source and "pine_catfish_catch" in main_source and "cedar_trout_catch" in main_source and "cedar_smallmouth_catch" in main_source and "cast_armed" in main_source and "line_out" in main_source and "hook_window" in main_source and "reduced_bite" in main_source and "reduced_reeling_high" in main_source and "reduced_catch" in main_source, "capture scenarios cover all species, explicit empty records, motion states, and reduced-motion variants without a save write")
	expect("FISH GOT AWAY" in main_source and "Ease forward when warning pulses speed up." in main_source and not "THE LINE WENT SLACK" in main_source, "escape card presents one neutral reason with motion-first recovery guidance")
	expect("SELECTED" in main_source and "rect.grow(-4.0)" in main_source, "location cards retain large selected border and high-contrast selected badge treatment")
	var rod_repacked := load("res://art/ui_v1/runtime_source/rod-bend-repacked-v02.png") as Texture2D
	var rod_repacked_image := rod_repacked.get_image() if rod_repacked else Image.new()
	var rod_boundaries_clear := true
	for x in [511, 512, 1023, 1024]:
		for y in range(0, 1024, 16):
			if rod_repacked_image.get_pixel(x, y).a != 0.0: rod_boundaries_clear = false
	expect(not rod_repacked_image.is_empty() and rod_repacked_image.get_size() == Vector2i(1536, 1024) and rod_boundaries_clear, "repacked rod atlas has strict transparent frame boundaries")
	expect("rod-bend-repacked-v02.png" in main_source and "AtlasTexture.new()" in main_source and "atlas.filter_clip = true" in main_source and "atlas.region = Rect2(frame * 512, 0, 512, 1024)" in main_source and "rod_frames.append(atlas)" in main_source and "draw_texture_rect(rod_frames[rod_region]" in main_source and "source_tip.x / ROD_FRAME_SIZE.x" in main_source and not "ROD_SOURCE_INSET_X" in main_source and not "ROD_SOURCE_FRAME_WIDTH" in main_source, "each repacked rod frame is a clipped AtlasTexture and maps its terminal guide through strict-cell coordinates")
	expect("control-kit-alpha-v01.png" in main_source and "StyleBoxTexture.new()" in main_source and "_control_style" in main_source and "plaque_normal" in main_source and "row_selected" in main_source and "texture_margin_left = 22.0" in main_source and "draw_center = true" in main_source and "TEST VIBRATION" in main_source and "MOTION SETUP" in main_source and "BACK TO FISHING" in main_source and "SETTINGS" in main_source and "SELECTED" in main_source and not "_text(\"⚙\"" in main_source, "control-kit provides Godot 4.7 texture-margin skins for named Settings and exit controls")
	expect("top-nav-strip-v01.png" in main_source and "_refresh_top_nav_geometry()" in main_source and "_handle_press(pos: Vector2)" in main_source and "records_rect" in main_source and "locations_rect" in main_source and "settings_rect" in main_source and "RECORDS" in main_source and "WATERS" in main_source and "SETTINGS" in main_source and "FINISH THIS CAST" in main_source and "controller._open_settings()" in main_source and "controller._can_open_records()" in main_source and not "_can_open_journal" in main_source and not "menu_medallion" in main_source, "top navigation shares current safe-area geometry for drawing and hits; Settings remains available while Records and Waters explain active-fishing gates")
	var locations_source := main_source.get_slice("func _draw_locations() -> void:", 1).get_slice("func _draw_location_card", 0)
	expect("records_safe_top" in main_source and "safe_top_override = 91.0" in main_source and "_journal_page_rect" in main_source and "_draw_back_to_fishing(safe_top)" in locations_source and "BACK TO FISHING" in main_source and not "back_medallion" in records_source and not "back_medallion" in locations_source and not "_text(\"BACK\"" in locations_source, "Records page and locations retain safe-aware Back to Fishing controls without page-turn arrows")
	expect("top_nav_ready" in main_source and "top_nav_safe_top" in main_source and "settings_button_line_out_safe_top" in main_source and "waters_button_ready_safe_top" in main_source and "records_button_ready_safe_top" in main_source and "top_nav_active_locked" in main_source and "_capture_top_nav_press" in main_source and "view._handle_press(view.settings_rect.get_center())" in main_source and "view._handle_press(view.locations_rect.get_center())" in main_source and "view._handle_press(view.records_rect.get_center())" in main_source, "deterministic navigation capture fixtures use the same current-geometry press handler")
	expect("settings_footer_close_rect" in main_source and "draw_style_box(_control_style(\"plaque_normal\"), settings_footer_close_rect)" in main_source and "settings_footer_close_rect.has_point(pos)" in main_source and "settings_haptics_rect.has_point(pos)" in main_source and "motion_sensitivity_rect.has_point(pos)" in main_source, "Settings and Motion Setup route only through their visible named targets")
