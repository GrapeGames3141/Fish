extends SceneTree

const FishingSession = preload("res://src/domain/fishing_session.gd")
const SaveService = preload("res://src/services/save_service.gd")
const AdMobService = preload("res://src/services/admob_service.gd")
const MotionService = preload("res://src/services/motion_service.gd")

var failures: Array[String] = []

func _init() -> void:
	_test_state_transitions_and_timing()
	_test_reel_geometry_and_tension()
	_test_save_round_trip()
	_test_injectable_motion()
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

func _test_state_transitions_and_timing() -> void:
	var game = FishingSession.new()
	expect(game.arm_cast(), "READY arms")
	expect(game.release_cast(0.85), "armed cast releases")
	game.tick(game.fish.bite_delay_seconds)
	expect(game.state == FishingSession.State.BITE, "line reaches bite")
	game.tick(0.01)
	expect(game.state == FishingSession.State.HOOK_WINDOW, "bite advances to hook window")
	expect(game.set_hook(), "hook succeeds in 1.5s window")
	expect(game.state == FishingSession.State.REELING, "hook enters reeling")
	game.reset(); game.arm_cast(); game.release_cast(0.4); game.tick(game.fish.bite_delay_seconds + 0.01); game.tick(0.01); game.tick(FishingSession.HOOK_WINDOW_SECONDS + 0.1)
	expect(game.state == FishingSession.State.ESCAPED, "hook timeout escapes")

func _test_reel_geometry_and_tension() -> void:
	var game = FishingSession.new()
	game.state = FishingSession.State.REELING
	expect(not game.add_reel_turns(-0.3, 0.1), "counterclockwise turns are ignored")
	game.add_reel_turns(0.5, 0.1)
	expect(game.reel_progress > 0.0, "clockwise turns advance catch")
	game.tension = 0.96
	game.tick(FishingSession.RED_ESCAPE_SECONDS + 0.05)
	expect(game.state == FishingSession.State.ESCAPED, "red tension has 1.25s escape")

func _test_save_round_trip() -> void:
	var path := "user://gate1-test-%d.json" % Time.get_ticks_usec()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var save = SaveService.new(path)
	expect(save.load_data().version == SaveService.VERSION, "missing save returns defaults")
	save.data.settings.sensitivity = 1.4
	save.record_bluegill(24.2)
	var restored = SaveService.new(path)
	restored.load_data()
	expect(float(restored.data.settings.sensitivity) == 1.4, "save restores settings")
	expect(int(restored.data.catches.bluegill) >= 1, "save restores catch count")
	expect(float(restored.data.best_cm.bluegill) >= 24.2, "save restores best fish")
	var corrupt := FileAccess.open(path, FileAccess.WRITE); corrupt.store_string("not json"); corrupt.close()
	expect(SaveService.new(path).load_data().version == SaveService.VERSION, "corrupt save falls back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_injectable_motion() -> void:
	var motion = MotionService.new()
	motion.neutral_gravity = Vector3(0, -9.8, 0)
	motion.queue_sample({"accelerometer": Vector3(0, -3.0, 0), "gravity": Vector3(0, -9.8, 0), "gyro": Vector3.ZERO})
	expect(motion.detect_cast() == 0.0, "back sample arms cast sequence")
	motion.queue_sample({"accelerometer": Vector3(0, 6.0, 0), "gravity": Vector3(0, -9.8, 0), "gyro": Vector3.ZERO})
	expect(motion.detect_cast() > 0.0, "forward sample completes cast")
	motion.queue_sample({"accelerometer": Vector3(0, 1.0, 0), "gravity": Vector3(0, -8.0, 0), "gyro": Vector3.ZERO})
	expect(motion.detect_cast() == 0.0, "noise/wrong direction does not cast")
	motion.queue_sample({"accelerometer": Vector3.ZERO, "gravity": Vector3(0, -5.0, 0), "gyro": Vector3.ZERO})
	expect(motion.detect_hook(), "valid gravity hook")
	motion.queue_sample({"accelerometer": Vector3.ZERO, "gravity": Vector3(0, -10.0, 0), "gyro": Vector3.ZERO})
	expect(not motion.detect_hook(), "wrong gravity gesture fails")
	motion.sensitivity = 1.5
	motion.queue_sample({"accelerometer": Vector3(0, -1.8, 0), "gravity": Vector3.ZERO, "gyro": Vector3.ZERO}); motion.detect_cast()
	motion.queue_sample({"accelerometer": Vector3(0, 3.0, 0), "gravity": Vector3.ZERO, "gyro": Vector3.ZERO})
	expect(motion.detect_cast() > 0.0, "larger sensitivity eases thresholds")

func _test_admob_contract() -> void:
	var ads = AdMobService.new()
	ads.initialize()
	expect(ads.game_content_reserve_height() == 0.0, "native bottom banner owns safe inset")
	expect(ads.TEST_BANNER_AD_UNIT == "ca-app-pub-3940256099942544/6300978111", "Google test banner ID is pinned")
	expect("desktop fallback" in ads.describe_desktop_fallback(), "desktop fallback is documented")
	expect(not ads.available and not ads.initialized, "desktop ads remain inert")

func _test_project_source_settings() -> void:
	var config := ConfigFile.new()
	expect(config.load("res://project.godot") == OK, "project settings load")
	expect(config.get_value("android", "package/unique_name") == "com.tak.castandcrank", "Android package is correct")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	expect("window/handheld/orientation=1" in project_source, "portrait orientation is enabled")
	expect(config.get_value("input_devices", "sensors/enable_accelerometer"), "accelerometer enabled")
	expect(config.get_value("input_devices", "sensors/enable_gravity"), "gravity enabled")
	expect(config.get_value("input_devices", "sensors/enable_gyroscope"), "gyroscope enabled")
	var export_config := ConfigFile.new(); expect(export_config.load("res://export_presets.cfg") == OK, "export settings load")
	expect(export_config.get_value("preset.0.options", "permissions/internet"), "Internet permission enabled")
	expect(export_config.get_value("preset.0.options", "permissions/access_network_state"), "network-state permission enabled")
	var source := FileAccess.get_file_as_string("res://src/services/admob_service.gd")
	expect("ConsentInformation" in source and "MAX_AD_CONTENT_RATING_PG" in source and "failed_closed" in source and "game_content_reserve_height" in source, "consent-first AdMob contract retained")
