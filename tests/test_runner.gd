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
	_test_reel_geometry_and_tension()
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
	expect(int(export_config.get_value("preset.0.options", "version/code")) == 4 and export_config.get_value("preset.0.options", "version/name") == "0.1.3-gate1", "debug package version is bumped")
	expect(export_config.get_value("preset.0.options", "package/signed"), "debug package requests signing")
	expect(export_config.get_value("preset.0.options", "gradle_build/compress_native_libraries"), "native libraries are compressed")
	expect(export_config.get_value("preset.0.options", "architectures/arm64-v8a") and not export_config.get_value("preset.0.options", "architectures/armeabi-v7a") and not export_config.get_value("preset.0.options", "architectures/x86") and not export_config.get_value("preset.0.options", "architectures/x86_64"), "debug package exports arm64 only")
	var excluded := str(export_config.get_value("preset.0", "exclude_filter"))
	expect("build/**" in excluded and "reports/**" in excluded and "addons/admob/internal/editor/**" in excluded and "addons/admob/internal/mock/**" in excluded and not "addons/admob/gdscript/src/mediation/**" in excluded, "non-runtime material is recursively excluded while runtime mediation dependencies remain")
	var source := FileAccess.get_file_as_string("res://src/services/admob_service.gd")
	expect("ConsentInformation" in source and "MAX_AD_CONTENT_RATING_PG" in source and "failed_closed" in source and "game_content_reserve_height" in source and "OnInitializationCompleteListener" in source and "sdk_initializing" in source and "banner_requested" in source, "consent-first SDK-sequenced AdMob contract retained")
	var haptic_source := FileAccess.get_file_as_string("res://src/services/haptic_service.gd")
	expect("AndroidRuntime" in haptic_source and "getSystemService(\"vibrator\")" in haptic_source and "VibrationEffect" in haptic_source and "createOneShot" in haptic_source and "Build$VERSION" in haptic_source and "SDK_INT" in haptic_source and "_android_vibrator.vibrate(maxi(1, duration_ms))" in haptic_source and "Input.vibrate_handheld" in haptic_source, "Android API26 amplitude and API24 legacy vibrator contract retained")
