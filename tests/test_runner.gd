extends SceneTree

const FishingSession = preload("res://src/domain/fishing_session.gd")
const SaveService = preload("res://src/services/save_service.gd")
const AdMobService = preload("res://src/services/admob_service.gd")

var failures: Array[String] = []

func _init() -> void:
	_test_state_transitions_and_timing()
	_test_reel_geometry_and_tension()
	_test_save_round_trip()
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
	var save = SaveService.new()
	save.data = SaveService.default_data()
	save.data.settings.sensitivity = 1.4
	save.record_bluegill(24.2)
	var restored = SaveService.new()
	restored.load_data()
	expect(float(restored.data.settings.sensitivity) == 1.4, "save restores settings")
	expect(int(restored.data.catches.bluegill) >= 1, "save restores catch count")
	expect(float(restored.data.best_cm.bluegill) >= 24.2, "save restores best fish")

func _test_admob_contract() -> void:
	var ads = AdMobService.new()
	ads.initialize()
	expect(ads.game_content_reserve_height() == 0.0, "native bottom banner owns safe inset")
	expect(ads.TEST_BANNER_AD_UNIT == "ca-app-pub-3940256099942544/6300978111", "Google test banner ID is pinned")
	expect("desktop fallback" in ads.describe_desktop_fallback(), "desktop fallback is documented")

func _test_project_source_settings() -> void:
	var config := ConfigFile.new()
	expect(config.load("res://project.godot") == OK, "project settings load")
	expect(config.get_value("android", "package/unique_name") == "com.tak.castandcrank", "Android package is correct")
	expect(config.get_value("display", "window/handheld/orientation") == 1, "portrait orientation is enabled")
