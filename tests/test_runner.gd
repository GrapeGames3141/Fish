extends SceneTree

const FishingSession = preload("res://src/domain/fishing_session.gd")
const SaveService = preload("res://src/services/save_service.gd")
const AdMobService = preload("res://src/services/admob_service.gd")
const MotionService = preload("res://src/services/motion_service.gd")
const FishDefinition = preload("res://src/domain/fish_definition.gd")
const HapticService = preload("res://src/services/haptic_service.gd")

var failures: Array[String] = []

func _init() -> void:
	_test_state_transitions_and_timing()
	_test_pump_and_recover_fight()
	_test_save_round_trip()
	_test_injectable_motion()
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
	var cock := Vector3(3.4, 5.2, 1.8)
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
	game.tick(0.01)
	expect(game.state == FishingSession.State.HOOK_WINDOW, "bite advances to hook window")
	expect(game.set_hook(), "hook succeeds in 1.8s window")
	expect(game.state == FishingSession.State.REELING, "hook enters reeling")
	game.reset(); game.arm_cast(); game.release_cast(0.4); game.tick(game.fish.bite_delay_seconds + 0.01); game.tick(0.01); game.tick(FishingSession.HOOK_WINDOW_SECONDS + 0.1)
	expect(game.state == FishingSession.State.ESCAPED, "hook timeout escapes")
	var boundary = FishingSession.new(); boundary.arm_cast(); boundary.release_cast(0.5); boundary.tick(boundary.fish.bite_delay_seconds + 0.01); boundary.tick(0.01); boundary.tick(1.79); expect(boundary.state == FishingSession.State.HOOK_WINDOW, "hook remains available just inside 1.8 second window"); boundary.tick(0.02); expect(boundary.state == FishingSession.State.ESCAPED, "hook closes at 1.8 seconds")
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

func _test_pump_and_recover_fight() -> void:
	var game = FishingSession.new()
	game.state = FishingSession.State.REELING
	game.tension = 0.40
	game.set_rod_load(1.0)
	game.tick(0.8)
	var raised_tension: float = game.tension
	var raised_progress: float = game.fight_progress
	game.set_rod_load(0.05)
	game.tick(0.8)
	expect(game.fight_progress > 0.0 and raised_progress > 0.0, "raised continuous rod load advances fish progress")
	expect(game.tension < raised_tension, "tilting forward/down actively relieves tension")
	expect(game.fight_progress - raised_progress < raised_progress, "low rod load makes little progress while easing tension")
	var red_game = FishingSession.new(); red_game.state = FishingSession.State.REELING; red_game.tension = 0.96; red_game.set_rod_load(1.0)
	red_game.tick(FishingSession.RED_ESCAPE_SECONDS + 0.1)
	expect(red_game.state == FishingSession.State.ESCAPED, "raised holding pressure can still escape at red tension")
	var nominal = FishingSession.new(); nominal.state = FishingSession.State.REELING
	for cycle in range(8):
		if nominal.state != FishingSession.State.REELING:
			break
		nominal.set_rod_load(0.05); nominal.tick(0.60)
		nominal.set_rod_load(0.90); nominal.tick(1.20)
	expect(nominal.state == FishingSession.State.CAUGHT and nominal.fight_elapsed >= 12.0 and nominal.fight_elapsed <= 14.0, "controlled continuous pull/ease rhythm lands Bluegill in the 12–14 second target")
	var natural_partial = FishingSession.new(); natural_partial.state = FishingSession.State.REELING; natural_partial.set_rod_load(0.50)
	var natural_partial_peak: float = natural_partial.tension
	for frame in range(40):
		if natural_partial.state != FishingSession.State.REELING:
			break
		natural_partial.tick(0.5)
		natural_partial_peak = maxf(natural_partial_peak, natural_partial.tension)
	expect(natural_partial.state == FishingSession.State.CAUGHT and natural_partial.fight_elapsed >= FishingSession.MIN_LANDING_SECONDS and natural_partial.fight_elapsed <= 20.0 and natural_partial_peak > 0.30, "quarter-geometric mapped load lands Bluegill in 10–20 seconds while tension rises measurably above calm baseline")
	var hard_hold = FishingSession.new(); hard_hold.state = FishingSession.State.REELING; hard_hold.set_rod_load(1.0)
	var hard_hold_peak_tension: float = hard_hold.tension
	for frame in range(24):
		if hard_hold.state != FishingSession.State.REELING:
			break
		hard_hold.tick(0.5)
		hard_hold_peak_tension = maxf(hard_hold_peak_tension, hard_hold.tension)
	expect(hard_hold.state in [FishingSession.State.CAUGHT, FishingSession.State.ESCAPED] and hard_hold.fight_elapsed <= 12.0, "sustained hard pull resolves quickly instead of advancing indefinitely")
	expect(hard_hold_peak_tension >= 0.65, "sustained hard pull crosses the high haptic warning tier before resolving")

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
	var invalid := FileAccess.open(path, FileAccess.WRITE)
	invalid.store_string(JSON.stringify({"version": SaveService.VERSION, "settings": {"sensitivity": 1.1}, "catches": {"bluegill": 6}, "best_cm": {"bluegill": 30.0}, "motion_profile": {"forward_axis": [1.0, 0.0, 0.0], "back_peak": 0.1, "forward_peak": 5.0}}))
	invalid.close()
	var invalid_restored := SaveService.new(path); invalid_restored.load_data()
	expect(not invalid_restored.data.calibrated and invalid_restored.data.motion_profile.is_empty() and int(invalid_restored.data.catches.bluegill) == 6, "invalid motion profiles recalibrate without losing progress")
	var corrupt := FileAccess.open(path, FileAccess.WRITE); corrupt.store_string("not json"); corrupt.close()
	expect(SaveService.new(path).load_data().version == SaveService.VERSION, "corrupt save falls back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_injectable_motion() -> void:
	var motion := _calibrated_motion()
	expect(motion.is_calibrated() and motion.calibration_progress == 2, "two physical calibration traces build a validated profile")
	expect(float(motion.profile.forward_axis[0]) < -0.70, "calibration stores an explicit left/negative-X forward axis")
	expect(MotionService.validate_profile({"forward_axis": [-0.85, 0.27, -0.445], "back_peak": 3.0, "forward_peak": 5.0, "gyro_peak": 0.7, "transition_seconds": 0.2, "noise_floor": 0.1, "direction_tolerance": 0.62}), "existing negative-X saved profile remains valid")
	expect(MotionService.validate_profile({"forward_axis": [-0.52, -0.80, -0.28], "back_peak": 3.0, "forward_peak": 5.0, "gyro_peak": 0.7, "transition_seconds": 0.2, "noise_floor": 0.1, "direction_tolerance": 0.62}), "clearly left-handed diagonal saved profile remains valid")
	expect(not MotionService.validate_profile({"forward_axis": [1.0, 0.0, 0.0], "back_peak": 3.0, "forward_peak": 5.0, "gyro_peak": 0.7, "transition_seconds": 0.2, "noise_floor": 0.1, "direction_tolerance": 0.62}), "wrong-handed saved profile is rejected and recalibrates")
	var left_motion := _left_calibrated_motion()
	expect(left_motion.is_calibrated() and float(left_motion.profile.get("forward_axis", [0.0])[0]) > 0.70, "left-handed calibration mirrors the saved profile axis profile=%s phase=%s" % [str(left_motion.profile), left_motion.calibration_phase])
	left_motion.queue_sample(_motion_sample(Vector3(-2.4, 0, 0))); var left_arm := left_motion.update(0.01, true, false); left_motion.queue_sample(_motion_sample(Vector3(5.0, 0, 0))); var left_cast := left_motion.update(0.18, true, false)
	expect(left_arm.cast_arm and float(left_cast.cast_quality) > 0.0, "left-handed cock-left snap-right cast mirrors right-handed behavior")
	var thresholds := _calibrated_motion(); thresholds.profile.noise_floor = 1.0; thresholds.profile.back_peak = 4.0; thresholds.profile.forward_peak = 6.0; thresholds.profile.gyro_peak = 4.0; thresholds.sensitivity = 2.0
	expect(is_equal_approx(thresholds._back_threshold(), 0.84) and is_equal_approx(thresholds._forward_threshold(), 1.26) and is_equal_approx(thresholds._hook_threshold(), 0.8) and is_equal_approx(thresholds._gyro_threshold(), 0.32), "cast-fix thresholds apply sensitivity to each complete exact max formula")
	thresholds.sensitivity = 0.5; expect(is_equal_approx(thresholds._gyro_threshold(), 0.60), "cast gyro threshold is capped at .60 rad/s")
	var pixel_profile := {"forward_axis": [-0.8526, 0.2737, -0.4452], "back_peak": 2.1457, "forward_peak": 3.6814, "gyro_peak": 4.2315, "transition_seconds": 0.375, "noise_floor": 0.6437, "direction_tolerance": 0.62}
	var pixel_thresholds := MotionService.new(); expect(pixel_thresholds.set_profile(pixel_profile), "inherited Pixel v3 profile remains valid without recalibration")
	expect(absf(pixel_thresholds._back_threshold() - 1.02992) <= 0.001 and absf(pixel_thresholds._forward_threshold() - 1.546188) <= 0.001 and is_equal_approx(pixel_thresholds._gyro_threshold(), 0.60) and is_equal_approx(pixel_thresholds._gyro_threshold() * 0.65, 0.39), "Pixel cast-fix gates retune to cock 1.030, snap 1.546, gyro .60, hook gyro .39")
	var switched := _calibrated_motion(); switched.set_left_handed(true)
	expect(switched.left_handed and not switched.is_calibrated() and switched.calibration_phase == "settling", "switching handedness deliberately clears a v3-compatible profile and starts calibration")
	var robust_gyro := MotionService.new(); robust_gyro._calibration_examples = [{"gyro_peak": 0.42}, {"gyro_peak": 8.0}]
	expect(is_equal_approx(robust_gyro._robust_gyro_peak(), 0.42), "two practice casts use the lower gyro peak to reject a one-off outlier")
	var diagnostic_motion := _calibrated_motion(); diagnostic_motion.queue_sample(_motion_sample(Vector3(1.3, 4.0, 0))); diagnostic_motion.update(0.05, true, false)
	var diagnostic_counts: Dictionary = diagnostic_motion.get_diagnostics()
	expect(int(diagnostic_counts.cock_attempts) >= 2 and int(diagnostic_counts.reasons.linear) + int(diagnostic_counts.reasons.axis) + int(diagnostic_counts.reasons.polarity) + int(diagnostic_counts.reasons.gyro) + int(diagnostic_counts.reasons.timeout) >= 1 and not str(diagnostic_counts).contains("Vector3"), "motion diagnostics keep derived counters/reasons without raw sensor vectors")
	var still_motion := _calibrated_motion(); still_motion.diagnostics = {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
	for frame in range(1200): still_motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); still_motion.update(0.05, true, true)
	var still_counts: Dictionary = still_motion.get_diagnostics()
	expect(int(still_counts.cock_attempts) == 0 and int(still_counts.hook_attempts) == 0 and int(still_counts.completed_casts) == 0 and int(still_counts.reasons.linear) + int(still_counts.reasons.axis) + int(still_counts.reasons.polarity) + int(still_counts.reasons.gyro) + int(still_counts.reasons.timeout) == 0, "60 seconds of still samples creates no gesture attempts or failure counts")
	var burst_motion := _calibrated_motion(); burst_motion.diagnostics = {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
	for frame in range(4): burst_motion.queue_sample(_motion_sample(Vector3(1.3, 4.0, 0))); burst_motion.update(0.05, true, false)
	var burst_counts: Dictionary = burst_motion.get_diagnostics()
	expect(int(burst_counts.cock_attempts) == 1 and int(burst_counts.reasons.axis) + int(burst_counts.reasons.polarity) == 1, "one off-axis candidate burst records one attempt/reason across high frames")
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
	two_window_hook.queue_sample(_motion_sample(Vector3(1.35, 0, 0), Vector3(0, 0, 0.4)))
	expect(two_window_hook.update(0.05, false, true).hook and int(two_window_hook.get_diagnostics().hook_attempts) == 1, "a prior opposite hook-window burst cannot suppress the first real hook candidate in the next window")
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
	var diagonal_cock := Vector3(3.4, 5.2, 1.8)
	diagonal_motion.queue_sample(_motion_sample(diagonal_cock))
	var diagonal_arm := diagonal_motion.update(0.01, true, false)
	diagonal_motion.queue_sample(_motion_sample(-diagonal_cock * 1.70))
	var diagonal_cast := diagonal_motion.update(0.18, true, false)
	expect(diagonal_arm.cast_arm and float(diagonal_cast.cast_quality) > 0.0, "natural diagonal right cock then left snap passes learned-axis recognition without the old narrow X cone")
	var residual_cock_motion := _calibrated_motion()
	residual_cock_motion.queue_sample(_motion_sample(Vector3(2.8, 0, 0), Vector3(0, 0, 0.55)))
	var residual_arm := residual_cock_motion.update(0.04, true, false)
	for residual in [Vector3(2.5, 0, 0), Vector3(2.1, 0, 0), Vector3(1.6, 0, 0), Vector3(1.2, 0, 0)]:
		residual_cock_motion.queue_sample(_motion_sample(residual, Vector3(0, 0, 0.45)))
		residual_cock_motion.update(0.04, true, false)
	residual_cock_motion.queue_sample(_motion_sample(Vector3(-4.4, 0, 0), Vector3(0, 0, 0.55)))
	var residual_snap := residual_cock_motion.update(0.16, true, false)
	expect(residual_arm.cast_arm and float(residual_snap.cast_quality) > 0.0, "residual cock/tail frames with no quiet gap cannot consume the natural forward snap candidate")
	var opposite_recovery := _calibrated_motion()
	opposite_recovery.queue_sample(_motion_sample(Vector3(-3.2, 0, 0), Vector3(0, 0, 0.5)))
	var rejected_opposite := opposite_recovery.update(0.05, true, false)
	opposite_recovery.queue_sample(_motion_sample(Vector3(2.8, 0, 0), Vector3(0, 0, 0.5)))
	var recovered_arm := opposite_recovery.update(0.05, true, false)
	opposite_recovery.queue_sample(_motion_sample(Vector3(-4.4, 0, 0), Vector3(0, 0, 0.5)))
	var recovered_snap := opposite_recovery.update(0.16, true, false)
	expect(not rejected_opposite.cast_arm and recovered_arm.cast_arm and float(recovered_snap.cast_quality) > 0.0, "an opposite-direction burst cannot suppress the next correct cock/snap candidate")
	var off_axis_multi := _calibrated_motion()
	for frame in range(4):
		off_axis_multi.queue_sample(_motion_sample(Vector3(0, 3.5, 0), Vector3(0, 0, 0.5)))
		off_axis_multi.update(0.05, true, false)
	expect(int(off_axis_multi.get_diagnostics().completed_casts) == 2 and not bool(off_axis_multi.update(0.01, true, false).cast_arm), "off-axis multi-frame energy cannot arm or cast")
	var diagonal_right_snap := _diagonal_motion()
	diagonal_right_snap.queue_sample(_motion_sample(diagonal_cock))
	diagonal_right_snap.update(0.01, true, false)
	diagonal_right_snap.queue_sample(_motion_sample(diagonal_cock * 1.70))
	var right_snap_event := diagonal_right_snap.update(0.18, true, false)
	expect(float(right_snap_event.cast_quality) == 0.0, "rightward diagonal snap remains rejected after cock")
	var diagonal_off_axis := _diagonal_motion()
	diagonal_off_axis.queue_sample(_motion_sample(diagonal_cock))
	diagonal_off_axis.update(0.01, true, false)
	diagonal_off_axis.queue_sample(_motion_sample(Vector3(-11.73, -0.38, -1.95)))
	var diagonal_off_axis_event := diagonal_off_axis.update(0.18, true, false)
	expect(float(diagonal_off_axis_event.cast_quality) == 0.0, "left-polarity diagonal noise still fails the learned-axis match")
	var diagonal_hook_motion := _diagonal_motion()
	diagonal_hook_motion.queue_sample(_motion_sample(Vector3(1.6, 2.45, 0.85), Vector3(0, 0, 0.5)))
	var diagonal_hook := diagonal_hook_motion.update(0.05, false, true)
	expect(diagonal_hook.hook, "quick diagonal right hook passes learned-axis recognition without the old narrow X cone")
	var diagonal_wrong_hook := _diagonal_motion()
	diagonal_wrong_hook.queue_sample(_motion_sample(Vector3(-1.6, -2.45, -0.85), Vector3(0, 0, 0.5)))
	expect(not diagonal_wrong_hook.update(0.05, false, true).hook, "left diagonal snap remains rejected as a hook")
	var diagonal_off_axis_hook := _diagonal_motion()
	diagonal_off_axis_hook.queue_sample(_motion_sample(Vector3(6.41, -0.74, 0.84), Vector3(0, 0, 0.5)))
	expect(not diagonal_off_axis_hook.update(0.05, false, true).hook, "right-polarity off-axis hook still fails the learned-axis match")
	motion.queue_sample(_motion_sample(Vector3(0.35, 0, 0), Vector3(0, 0, 0.05)))
	var noise := motion.update(0.05, true, false)
	expect(not noise.cast_arm and float(noise.cast_quality) == 0.0, "noise does not arm a cast")
	motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); motion.update(0.05, true, false)
	motion.queue_sample(_motion_sample(Vector3(-4.2, 0, 0)))
	var wrong_order := motion.update(0.05, true, false)
	expect(not wrong_order.cast_arm and float(wrong_order.cast_quality) == 0.0, "left snap without a right cock is rejected")
	motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); motion.update(0.05, true, false)
	motion.queue_sample(_motion_sample(Vector3(0, 3.5, 0)))
	var wrong_direction := motion.update(0.05, true, false)
	expect(not wrong_direction.cast_arm and float(wrong_direction.cast_quality) == 0.0, "off-axis motion is rejected")
	motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); motion.update(0.05, true, false)
	motion.queue_sample(_motion_sample(Vector3(2.2, 0, 0)))
	var slow_back := motion.update(0.01, true, false)
	motion.queue_sample(_motion_sample(Vector3(4.2, 0, 0)))
	var reversed_snap := motion.update(0.12, true, false)
	expect(slow_back.cast_arm and float(reversed_snap.cast_quality) == 0.0, "rightward snap after a right cock is rejected")
	motion.reset_gesture()
	motion.queue_sample(_motion_sample(Vector3(2.2, 0, 0)))
	motion.update(0.01, true, false)
	motion.queue_sample(_motion_sample(Vector3(-3.3, 0, 0)))
	var slow_snap := motion.update(0.24, true, false)
	expect(slow_back.cast_arm and float(slow_snap.cast_quality) > 0.0, "right cock then left snap arms and casts")
	motion.reset_gesture()
	motion.queue_sample(_motion_sample(Vector3(2.3, 0, 0)))
	motion.update(0.40, true, false)
	motion.queue_sample(_motion_sample(Vector3(-4.8, 0, 0)))
	var fast_snap := motion.update(0.18, true, false)
	expect(float(slow_snap.cast_quality) < float(fast_snap.cast_quality), "faster accepted snap has higher quality")
	var slow_session := FishingSession.new(); slow_session.arm_cast(); slow_session.release_cast(float(slow_snap.cast_quality))
	var fast_session := FishingSession.new(); fast_session.arm_cast(); fast_session.release_cast(float(fast_snap.cast_quality))
	expect(slow_session.cast_distance_m < fast_session.cast_distance_m, "faster snap maps to farther cast distance")
	motion.reset_gesture()
	motion.queue_sample(_motion_sample(Vector3(2.4, 0, 0)))
	motion.update(0.01, true, false)
	motion.queue_sample(_motion_sample(Vector3(-5.0, 0, 0)))
	var too_slow := motion.update(1.20, true, false)
	expect(float(too_slow.cast_quality) == 0.0, "slow back-to-snap transition is rejected")
	motion.reset_gesture()
	motion.queue_sample(_motion_sample(Vector3(1.35, 0, 0), Vector3(0, 0, 0.4)))
	var hook_event := motion.update(0.05, false, true)
	var hook_session := FishingSession.new(); hook_session.state = FishingSession.State.HOOK_WINDOW
	expect(hook_event.hook and hook_session.set_hook(), "smaller calibrated right gesture hooks only in hook window")
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
	motion.sensitivity = 1.5
	motion.reset_gesture()
	motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO))
	motion.update(0.40, false, false)
	motion.queue_sample(_motion_sample(Vector3(1.3, 0, 0)))
	var easier_back := motion.update(0.01, true, false)
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

	var before_disable := reset_fired.size()
	reset_haptics.set_enabled(false)
	for frame in range(120):
		reset_haptics.update_fight(0.01, bluegill, 0.95)
	expect(reset_haptics.pending.is_empty() and reset_fired.size() == before_disable, "disabled haptics clear and suppress pending cues")

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
	expect(int(export_config.get_value("preset.0.options", "version/code")) == 14 and export_config.get_value("preset.0.options", "version/name") == "0.3.1-castfix1", "cast-recognition hotfix package version is bumped")
	expect(export_config.get_value("preset.0.options", "package/signed"), "debug package requests signing")
	expect(export_config.get_value("preset.0.options", "gradle_build/compress_native_libraries"), "native libraries are compressed")
	expect(export_config.get_value("preset.0.options", "architectures/arm64-v8a") and not export_config.get_value("preset.0.options", "architectures/armeabi-v7a") and not export_config.get_value("preset.0.options", "architectures/x86") and not export_config.get_value("preset.0.options", "architectures/x86_64"), "debug package exports arm64 only")
	var excluded := str(export_config.get_value("preset.0", "exclude_filter"))
	expect("build/**" in excluded and "reports/**" in excluded and "art/ui_v1/mockups/**" in excluded and "addons/admob/internal/editor/**" in excluded and "addons/admob/internal/mock/**" in excluded and not "addons/admob/gdscript/src/mediation/**" in excluded, "mockups and non-runtime material are recursively excluded while runtime mediation dependencies remain")
	expect(config.get_value("application", "config/icon") == "res://art/ui_v1/runtime_source/app-icon-runtime-512.png" and config.get_value("application", "boot_splash/image") == "res://art/ui_v1/runtime_source/loading-splash-v01.png", "optimized runtime icon and approved splash are configured")
	var runtime_assets := {
		"res://art/ui_v1/runtime_source/pine-lake-clean-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/rod-bend-strip-v01.png": Vector2i(1536, 1024),
		"res://art/ui_v1/runtime_source/bobber-v01.png": Vector2i(1230, 1278),
		"res://art/ui_v1/runtime_source/water-reaction-strip-v01.png": Vector2i(2172, 724),
		"res://art/ui_v1/runtime_source/catch-frame-clean-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/bluegill-v01.png": Vector2i(1536, 1024),
		"res://art/ui_v1/runtime_source/app-icon-v01.png": Vector2i(1254, 1254),
		"res://art/ui_v1/runtime_source/app-icon-runtime-512.png": Vector2i(512, 512),
		"res://art/ui_v1/runtime_source/loading-splash-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/records-screen-v01.png": Vector2i(941, 1672)
	}
	for asset_path in runtime_assets:
		var texture := load(asset_path) as Texture2D
		var image := texture.get_image() if texture else Image.new()
		expect(not image.is_empty() and image.get_size() == runtime_assets[asset_path], "runtime UI asset has the expected dimensions: " + asset_path)
	for transparent_asset in ["res://art/ui_v1/runtime_source/rod-bend-strip-v01.png", "res://art/ui_v1/runtime_source/bobber-v01.png", "res://art/ui_v1/runtime_source/water-reaction-strip-v01.png", "res://art/ui_v1/runtime_source/bluegill-v01.png"]:
		var transparent_texture := load(transparent_asset) as Texture2D
		var transparent_image := transparent_texture.get_image() if transparent_texture else Image.new()
		expect(transparent_image.detect_alpha() != Image.ALPHA_NONE, "runtime animated asset retains alpha: " + transparent_asset)
	var source := FileAccess.get_file_as_string("res://src/services/admob_service.gd")
	expect("ConsentInformation" in source and "MAX_AD_CONTENT_RATING_PG" in source and "failed_closed" in source and "game_content_reserve_height" in source and "OnInitializationCompleteListener" in source and "sdk_initializing" in source and "banner_requested" in source, "consent-first SDK-sequenced AdMob contract retained")
	var haptic_source := FileAccess.get_file_as_string("res://src/services/haptic_service.gd")
	expect("AndroidRuntime" in haptic_source and "getSystemService(\"vibrator\")" in haptic_source and "VibrationEffect" in haptic_source and "createOneShot" in haptic_source and "Build$VERSION" in haptic_source and "SDK_INT" in haptic_source and "VibrationAttributes" in haptic_source and "createForUsage" in haptic_source and "USAGE_MEDIA" in haptic_source and "AudioAttributes$Builder" in haptic_source and "USAGE_GAME" in haptic_source and "CONTENT_TYPE_SONIFICATION" in haptic_source and "vibrate(effect, _android_vibration_attributes)" in haptic_source and "vibrate(effect, _android_audio_attributes)" in haptic_source and "_android_vibrator.vibrate(maxi(1, duration_ms), _android_audio_attributes)" in haptic_source and "Input.vibrate_handheld" in haptic_source, "Android explicit non-touch attributes with API24 fallback contract retained")
	var main_source := FileAccess.get_file_as_string("res://src/ui/main.gd")
	var motion_source := FileAccess.get_file_as_string("res://src/services/motion_service.gd")
	expect("randf()" in main_source and "haptics.cue(\"cock\")" in main_source and "haptics.set_enabled(bool(save.data.settings[key]))" in main_source, "physical arm selects a fresh weighted fish, cues cock, and applies haptics immediately")
	expect("PROFILE_HANDEDNESS_ALIGNMENT" in motion_source and "CALIBRATION_HANDEDNESS_ALIGNMENT" in motion_source and "RUNTIME_X_POLARITY_ALIGNMENT" in motion_source and "LOAD_RESPONSE_SECONDS" in motion_source and "MOTION_FAIL reason=" in motion_source and "sqrt(raw_fight_load)" in motion_source, "mirrored learned-axis motion retains smoothing, bounded diagnostics, and polarity gates")
	expect(not "HOLD TO CAST" in main_source and not "SET HOOK" in main_source and not "SAFE BYPASS" in main_source and not "cast_rect" in main_source and not "reel_center" in main_source and not "InputEventScreenDrag" in main_source and not "_handle_drag" in main_source and not "reel_fallback" in main_source and "COCK RIGHT, THEN SNAP LEFT" in main_source and "BITE — PULL RIGHT" in main_source and "TILT LEFT TO EASE" in main_source and "TILT RIGHT TO PULL" in main_source and "not OS.has_feature(\"android\")" in main_source and "MOTION_FIGHT caught elapsed=" in main_source and "MOTION_FIGHT escaped elapsed=" in main_source and "_record_catch_once" in main_source and "records-screen-v01.png" in main_source and "ROD_TIP_ANCHORS" in main_source and "_rod_tip_for_frame" in main_source and not "draw_line(Vector2(87, 1070)" in main_source, "Android UI retains no touch gameplay paths, explicit right-handed guidance, and tip-anchored rod lines")
