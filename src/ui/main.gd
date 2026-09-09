extends Node

const FishingSession = preload("res://src/domain/fishing_session.gd")
const MotionService = preload("res://src/services/motion_service.gd")
const SaveService = preload("res://src/services/save_service.gd")
const AdMobService = preload("res://src/services/admob_service.gd")
const HapticService = preload("res://src/services/haptic_service.gd")
const CastCaptureService = preload("res://src/services/cast_capture_service.gd")
const FishDefinition = preload("res://src/domain/fish_definition.gd")
const LeaderboardService = preload("res://src/services/leaderboard_service.gd")
const PlayGamesConfig = preload("res://addons/play_games/play_games_config.gd")

var session: FishingSession
var motion: MotionService
var save: SaveService
var ads: AdMobService
var haptics: HapticService
var preview_haptics: HapticService
var cast_capture: CastCaptureService
var leaderboards: LeaderboardService
var prior_state := -1
var view: FishingView
var capture_path := ""
var capture_scenario := "ready"
var loading_elapsed := 0.0
var loading_active := true
var ui_time := 0.0
var caught_recorded := false
var capture_mode := false
var capture_freeze := false
var cast_visual_elapsed := 0.0
var menu_motion_settle_remaining := 0.0
var catch_prior_count := 0
var catch_prior_best_cm := 0.0
var ui_notice := ""
var ui_notice_remaining := 0.0
var terminal_motion_ready := false
var leaderboard_motion_cast := false
var leaderboard_motion_hook := false
var leaderboard_motion_fight := false
var leaderboard_reel_sensor_seconds := 0.0
var leaderboard_catch_token := 0

var pine_lake_texture: Texture2D = load("res://art/ui_v1/runtime_source/pine-lake-clean-v01.png")
var cedar_river_texture: Texture2D = load("res://art/ui_v1/runtime_source/cedar-river-photo-v03.png")
var pine_fish_atlas: Texture2D = load("res://art/ui_v1/runtime_source/pine-fish-atlas-v02.png")
var cedar_fish_atlas: Texture2D = load("res://art/ui_v1/runtime_source/cedar-fish-atlas-v02.png")
var rod_texture: Texture2D = load("res://art/ui_v1/runtime_source/rod-bend-repacked-v02.png")
var photoreal_rod_texture: Texture2D = load("res://art/ui_v1/runtime_source/rod-photoreal-alpha-v01.png")
var bobber_texture: Texture2D = load("res://art/ui_v1/runtime_source/bobber-photoreal-alpha-v01.png")
var reaction_texture: Texture2D = load("res://art/ui_v1/runtime_source/water-reaction-strip-v01.png")
var splash_texture: Texture2D = load("res://art/ui_v1/runtime_source/loading-splash-v01.png")
var records_texture: Texture2D = preload("res://art/ui_v1/runtime_source/records-screen-rustic-v01.png")
var journal_detail_texture: Texture2D = preload("res://art/ui_v1/runtime_source/journal-detail-v01.png")
var control_kit_texture: Texture2D = load("res://art/ui_v1/runtime/control-kit-alpha-v01.png")
var top_nav_texture: Texture2D = load("res://art/ui_v1/runtime_source/top-nav-rustic-v01.png")
var rustic_settings_texture: Texture2D = load("res://art/ui_v1/runtime_source/settings-rustic-v01.png")
var rustic_waters_texture: Texture2D = load("res://art/ui_v1/runtime_source/waters-rustic-v01.png")
var rustic_catch_texture: Texture2D = load("res://art/ui_v1/runtime_source/catch-rustic-v01.png")

func _ready() -> void:
	session = FishingSession.new(); motion = MotionService.new(); save = SaveService.new(); ads = AdMobService.new(); haptics = HapticService.new(); preview_haptics = HapticService.new(); cast_capture = CastCaptureService.new(CastCaptureService.PATH, Callable(motion, "sample"))
	save.load_data(); motion.sensitivity = float(save.data.settings.get("sensitivity", 1.0)); motion.left_handed = bool(save.data.settings.get("left_handed", false)); session.set_location(str(save.data.get("selected_location_id", "pine_lake")), 0.0)
	if not motion.set_profile(save.data.get("motion_profile", {})): motion.begin_calibration()
	ads.initialize(); haptics.set_enabled(bool(save.data.settings.get("haptics", true)))
	view = FishingView.new(); view.controller = self; add_child(view)
	_parse_capture_args()
	# Capture fixtures must never even initialize the optional native service.
	leaderboards = LeaderboardService.new(null, PlayGamesConfig.as_dictionary(), capture_path != "")
	if capture_path != "":
		capture_mode = true
		# Capture fixtures must never inherit or mutate the player's actual progress.
		save.data = SaveService.default_data()
		session.set_location("pine_lake", 0.0)
		_apply_capture_scenario(); loading_active = capture_scenario == "loading"; capture_freeze = capture_scenario != "loading"; call_deferred("_capture_after_draw")
	elif not motion.is_calibrated(): view.overlay = "calibration"

func _process(delta: float) -> void:
	# Freeze the presentation clock before any state advances so multi-frame capture
	# evidence remains deterministic rather than schedule-dependent.
	if not capture_freeze: ui_time += delta
	if loading_active:
		loading_elapsed += delta
		if loading_elapsed >= 1.0:
			loading_active = false
		view.queue_redraw(); return
	if capture_freeze:
		view.queue_redraw(); return
	var was_settling := menu_motion_settle_remaining > 0.0
	menu_motion_settle_remaining = maxf(0.0, menu_motion_settle_remaining - delta)
	ui_notice_remaining = maxf(0.0, ui_notice_remaining - delta)
	if ui_notice_remaining <= 0.0: ui_notice = ""
	if cast_capture.is_active():
		var capture_event := cast_capture.update(delta)
		var capture_cue := str(capture_event.get("cue", ""))
		if capture_cue != "": haptics.cue(capture_cue)
		haptics.tick(delta)
		if bool(capture_event.get("saved", false)): view.overlay = "capture_saved"
		else: view.overlay = "capture"
		view.queue_redraw(); return
	if view.overlay == "calibration":
		var calibration_event := motion.update(delta, false, false)
		if bool(calibration_event.get("calibration_tick", false)): haptics.cue("calibration_tick")
		if bool(calibration_event.get("calibration_complete", false)):
			save.data.motion_profile = motion.get_profile(); save.data.calibrated = true; save.save_data()
			var profile := motion.get_profile()
			print("MOTION_PROFILE_SAVED forward_peak=%.2f back_peak=%.2f transition=%.2f" % [float(profile.forward_peak), float(profile.back_peak), float(profile.transition_seconds)])
			view.overlay = ""
		view.queue_redraw(); return
	if view.overlay == "capture_saved": haptics.tick(delta); view.queue_redraw(); return
	if view.overlay in ["settings", "motion_setup", "records", "journal_detail", "world_records", "locations", "diagnostics", "capture"]:
		if view.overlay in ["settings", "motion_setup"]: preview_haptics.tick(delta)
		view.queue_redraw(); return
	if was_settling:
		# Drain one sensor frame without recognizing it, while all session timers pause.
		motion.update(delta, false, false, false); haptics.tick(delta); view.queue_redraw(); return
	cast_visual_elapsed += delta
	var terminal_state := session.state in [FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]
	var allow_cast := menu_motion_settle_remaining <= 0.0 and (session.state == FishingSession.State.CAST_ARMED or (session.state == FishingSession.State.READY and not haptics.is_motion_guarded()) or (terminal_state and terminal_motion_ready and not haptics.is_motion_guarded()))
	var allow_hook := menu_motion_settle_remaining <= 0.0 and session.state == FishingSession.State.HOOK_WINDOW and not haptics.is_motion_guarded()
	var motion_event := motion.update(delta, allow_cast, allow_hook, session.state == FishingSession.State.REELING)
	if session.state == FishingSession.State.READY and bool(motion_event.get("cast_arm", false)): _arm_cast()
	elif terminal_state:
		session.credit_terminal_still(delta, bool(motion_event.get("sensor_quiet", false)))
		if not terminal_motion_ready and session.can_recast_from_motion() and not haptics.is_motion_guarded():
			# The next intentional cock is read on a fresh frame after a quiet dwell.
			motion.reset_gesture(); terminal_motion_ready = true
		elif terminal_motion_ready and bool(motion_event.get("cast_arm", false)):
			_reset_terminal_for_motion_cast(); _arm_cast()
	if session.state == FishingSession.State.CAST_ARMED and bool(motion_event.get("cast_cancel", false)):
		if session.cancel_cast(): print("MOTION_CAST_CANCEL reason=timeout")
	if session.state == FishingSession.State.CAST_ARMED and float(motion_event.get("cast_quality", 0.0)) > 0.0: _cast(float(motion_event.cast_quality), motion_event)
	if session.state == FishingSession.State.HOOK_WINDOW and bool(motion_event.get("hook", false)): _hook(motion_event)
	if session.state == FishingSession.State.REELING:
		session.set_rod_load(0.0 if menu_motion_settle_remaining > 0.0 else float(motion_event.get("fight_load", 0.0)))
		if OS.has_feature("android") and bool(motion_event.get("sensor_gravity_valid", false)):
			leaderboard_reel_sensor_seconds += minf(delta, 0.08)
			leaderboard_motion_fight = leaderboard_reel_sensor_seconds >= 0.35
		if bool(motion_event.get("fight_lower", false)): print("MOTION_FIGHT lower tension=%.2f elapsed=%.2f" % [session.tension, session.fight_elapsed])
		if bool(motion_event.get("fight_pull", false)): print("MOTION_FIGHT pull progress=%.2f tension=%.2f elapsed=%.2f" % [session.fight_progress, session.tension, session.fight_elapsed])
	session.tick(delta); haptics.set_enabled(bool(save.data.settings.get("haptics", true)))
	if prior_state != session.state:
		if session.state == FishingSession.State.BITE: haptics.cue("bite")
		elif session.state == FishingSession.State.CAUGHT:
			_snapshot_catch_record(); _record_catch_once(); haptics.cue("caught")
			print("MOTION_FIGHT caught elapsed=%.2f progress=%.2f tension=%.2f" % [session.fight_elapsed, session.fight_progress, session.tension])
		elif session.state == FishingSession.State.ESCAPED:
			haptics.cue("hook_miss" if prior_state == FishingSession.State.HOOK_WINDOW else "escaped")
			print("MOTION_FIGHT escaped elapsed=%.2f progress=%.2f tension=%.2f" % [session.fight_elapsed, session.fight_progress, session.tension])
		if session.state in [FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]: motion.reset_fight()
		prior_state = session.state
	if session.state == FishingSession.State.REELING:
		if not haptics.fighting: haptics.start_fight(session.fish)
		var fight_size_factor := 1.0 + (inverse_lerp(session.fish.min_length_cm, session.fish.max_length_cm, session.catch_length_cm) * 0.10 if session.catch_length_cm > 0.0 else 0.0)
		var felt_effort := session.fight_effort + (0.16 if session.fight_stage == FishingSession.FightStage.LAST_SURGE else (0.08 if session.fight_stage == FishingSession.FightStage.OPENING_RUN else 0.0))
		haptics.update_fight(delta, session.fish, session.tension, felt_effort, fight_size_factor)
	else: haptics.tick(delta)
	view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _desktop_fallbacks_enabled(): return
	if event.is_action_pressed("cast_fallback"):
		if session.state == FishingSession.State.READY: _arm_cast()
		elif session.state == FishingSession.State.CAST_ARMED: _cast(0.8)
	if event.is_action_pressed("hook_fallback"): _hook()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: view.overlay = "" if view.overlay in ["settings", "records"] else "settings"

func _arm_cast() -> void:
	if session.state != FishingSession.State.READY: return
	# All three rolls are injected by tests. Gameplay chooses them only after the
	# player begins a real cast; distance-aware fish selection happens at release.
	session.set_encounter_rolls(randf(), randf(), randf())
	session.arm_cast()
func _cast(quality: float = 0.78, motion_event: Dictionary = {}) -> void:
	if session.release_cast(quality):
		leaderboard_motion_cast = OS.has_feature("android") and not motion_event.is_empty()
		leaderboard_motion_hook = false
		leaderboard_catch_token += 1
		cast_visual_elapsed = 0.0
		print("MOTION_CAST quality=%.2f distance_m=%.1f snap_projection=%.2f axis_match=%.2f polarity=%.2f gyro=%.2f reversal_s=%.3f cock_projection=%.2f" % [session.cast_quality, session.cast_distance_m, float(motion_event.get("snap_projection", 0.0)), float(motion_event.get("snap_axis_match", 0.0)), float(motion_event.get("snap_polarity_match", 0.0)), float(motion_event.get("snap_gyro", 0.0)), float(motion_event.get("reversal_seconds", 0.0)), float(motion_event.get("cock_projection", 0.0))])
func _hook(motion_event: Dictionary = {}) -> void:
	if session.set_hook():
		leaderboard_motion_hook = OS.has_feature("android") and not motion_event.is_empty()
		motion.begin_fight(); haptics.cue("hook"); haptics.start_fight(session.fish); print("MOTION_HOOK state=REELING projection=%.2f alignment=%.2f gyro=%.2f sweep_samples=%d" % [float(motion_event.get("hook_projection", 0.0)), float(motion_event.get("hook_alignment", 0.0)), float(motion_event.get("hook_gyro", 0.0)), int(motion_event.get("hook_sweep_samples", 0))])
func _record_catch_once() -> void:
	if caught_recorded or capture_mode: return
	save.record_catch(session.fish.id, session.catch_length_cm, {"location_id": session.location_id, "fight_seconds": session.fight_elapsed, "cast_distance_m": session.cast_distance_m}); caught_recorded = true
	if leaderboards != null:
		leaderboards.submit_landed(session.fish.id, session.catch_length_cm, {
			"landed": session.state == FishingSession.State.CAUGHT,
			"motion_cast": leaderboard_motion_cast, "motion_hook": leaderboard_motion_hook, "motion_fight": leaderboard_motion_fight,
			"fight_seconds": session.fight_elapsed, "android": OS.has_feature("android"),
			"debug": OS.is_debug_build(), "capture": capture_mode, "fixture": false,
			"legacy": false, "simulated": false, "catch_token": leaderboard_catch_token
		})
func _snapshot_catch_record() -> void:
	catch_prior_count = int(save.data.catches.get(session.fish.id, 0))
	catch_prior_best_cm = float(save.data.best_cm.get(session.fish.id, 0.0))
func _catch_status(length: float) -> String:
	return catch_status_for(catch_prior_count, catch_prior_best_cm, length)
static func catch_status_for(prior_count: int, prior_best: float, length: float) -> String:
	var shown_length := snappedf(length, 0.1)
	var shown_best := snappedf(prior_best, 0.1)
	if prior_count <= 0: return "FIRST CATCH  •  1 CAUGHT"
	if shown_length > shown_best: return "NEW BEST  •  %d CAUGHT" % (prior_count + 1)
	if is_equal_approx(shown_length, shown_best): return "MATCHED BEST  •  %d CAUGHT" % (prior_count + 1)
	return "%d CAUGHT  •  BEST %.1f cm" % [prior_count + 1, shown_best]
static func presentation_bobber_y(distance_m: float, fight_progress: float, is_reeling: bool, landing_blend: float) -> float:
	var distance_fraction := inverse_lerp(FishingSession.MIN_CAST_DISTANCE_M, FishingSession.MAX_CAST_DISTANCE_M, distance_m)
	var landed_y := lerpf(780.0, 410.0, distance_fraction)
	if is_reeling: return lerpf(landed_y, 860.0, clampf(fight_progress, 0.0, 1.0))
	return lerpf(786.0, landed_y, clampf(landing_blend, 0.0, 1.0))
static func presentation_bobber_position(distance_m: float, fight_progress: float, is_reeling: bool, landing_blend: float) -> Vector2:
	var distance_fraction := inverse_lerp(FishingSession.MIN_CAST_DISTANCE_M, FishingSession.MAX_CAST_DISTANCE_M, distance_m)
	# Cast speed selects a reachable water band, not a touch-aim cursor. The small
	# lateral drift makes reeds / seam / deep-run landings visibly distinct.
	return Vector2(lerpf(446.0, 528.0, distance_fraction), presentation_bobber_y(distance_m, fight_progress, is_reeling, landing_blend))
static func accepts_primary_press(is_touch: bool, is_pressed: bool, is_primary: bool, device_id: int) -> bool:
	if not is_pressed or not is_primary: return false
	return is_touch or device_id != InputEvent.DEVICE_ID_EMULATION
func _reset_session() -> void:
	session.reset(); caught_recorded = false; terminal_motion_ready = false; leaderboard_motion_cast = false; leaderboard_motion_hook = false; leaderboard_motion_fight = false; leaderboard_reel_sensor_seconds = 0.0; haptics.stop(); prior_state = session.state; motion.reset_gesture(); motion.reset_fight()
func _reset_terminal_for_motion_cast() -> void:
	# Preserve the newly read cock candidate; only reset world/fight state.
	session.reset(); caught_recorded = false; terminal_motion_ready = false; leaderboard_motion_cast = false; leaderboard_motion_hook = false; leaderboard_motion_fight = false; leaderboard_reel_sensor_seconds = 0.0; haptics.stop(); prior_state = session.state; motion.reset_fight()
func _start_motion_recalibration() -> void:
	preview_haptics.stop(); _reset_session(); motion.begin_calibration(); save.data.calibrated = false; save.data.motion_profile = {}; save.save_data(); view.overlay = "calibration"
func _start_cast_capture() -> void:
	preview_haptics.stop(); _reset_session()
	var settings: Dictionary = save.data.settings
	var metadata := {"left_handed": bool(settings.get("left_handed", false)), "sensitivity": float(settings.get("sensitivity", 1.0)), "motion_profile": motion.get_profile()}
	if cast_capture.start(metadata):
		haptics.cue("capture_countdown")
		view.overlay = "capture"
func _desktop_fallbacks_enabled() -> bool: return not OS.has_feature("android")
func _toggle_setting(key: String) -> void:
	if key == "left_handed":
		_reset_session(); save.data.settings.left_handed = not bool(save.data.settings.get("left_handed", false)); motion.set_left_handed(bool(save.data.settings.left_handed)); save.data.calibrated = false; save.data.motion_profile = {}; save.save_data(); view.overlay = "calibration"; return
	if key == "sensitivity":
		var next := float(save.data.settings.sensitivity) + 0.2
		save.data.settings.sensitivity = 0.6 if next > 1.6 else next; motion.sensitivity = float(save.data.settings.sensitivity)
	else:
		save.data.settings[key] = not bool(save.data.settings[key])
		if key == "haptics": haptics.set_enabled(bool(save.data.settings[key])); preview_haptics.set_enabled(bool(save.data.settings[key]))
	save.save_data()
func _can_open_records() -> bool: return session.state in [FishingSession.State.READY, FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]
func _discovered_species_count(location: String) -> int:
	var discovered := 0
	for fish in FishDefinition.for_location(location):
		if int(save.data.catches.get(fish.id, 0)) > 0: discovered += 1
	return discovered
func _select_location(location: String) -> void:
	if not _can_open_records(): return
	if session.state in [FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]: _reset_session()
	if session.set_location(location, 0.0): save.data.selected_location_id = location; save.save_data(); view.overlay = ""
func _open_settings() -> void:
	# A menu visit pauses the loop and discards a partially cocked gesture.
	if session.state == FishingSession.State.CAST_ARMED: session.cancel_cast(); prior_state = session.state
	terminal_motion_ready = false; session.terminal_still_elapsed = 0.0
	haptics.stop(); preview_haptics.stop(); motion.reset_gesture(); view.overlay = "settings"
func _close_overlay() -> void:
	# stop() clears scheduler state, so retain the active motor tail plus settle time
	# before clearing either channel. This prevents a preview pulse becoming a cast/hook.
	var preserved_guard := maxf(HapticService.MOTION_SETTLE_SECONDS, maxf(haptics.motion_guard_seconds(), preview_haptics.motion_guard_seconds()))
	terminal_motion_ready = false; session.terminal_still_elapsed = 0.0
	haptics.stop(); preview_haptics.stop(); motion.reset_gesture(); menu_motion_settle_remaining = preserved_guard; view.overlay = ""
func _test_haptics() -> void:
	preview_haptics.stop(); preview_haptics.set_enabled(bool(save.data.settings.get("haptics", true))); preview_haptics.cue("bite")
func _parse_capture_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-scenario="): capture_scenario = arg.trim_prefix("--capture-scenario=")
func _apply_capture_scenario() -> void:
	view.overlay = ""
	match capture_scenario:
		"loading": pass
		"pine_ready": session.set_location("pine_lake", 0.0)
		"cedar_ready": session.set_location("cedar_river", 0.0)
		"cedar_ready_safe_top_180": session.set_location("cedar_river", 0.0); view.safe_top_override = 180.0
		"cast_armed": session.arm_cast()
		"line_out": session.arm_cast(); session.release_cast(0.8)
		"cedar_line_out": session.set_location("cedar_river", 0.0); session.arm_cast(); session.release_cast(0.8)
		"cedar_line_out_safe_top_180": session.set_location("cedar_river", 0.0); session.arm_cast(); session.release_cast(0.8); view.safe_top_override = 180.0
		"cedar_line_out_far": session.set_location("cedar_river", 0.0); session.arm_cast(); session.release_cast(1.0)
		"bite": session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.BITE; session.bite_elapsed = 0.20
		"hook_window": session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.HOOK_WINDOW; session.bite_elapsed = 0.20
		"reeling", "reeling_low": session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.32; session.rod_load = 0.38; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"reeling_high": session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.88; session.rod_load = 0.88; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"caught", "catch_first": session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 24.0; session.last_reason = "Bluegill landed!"; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true; _set_capture_catch_record(0, 0.0)
		"catch_new_best": session.set_location("pine_lake", 0.60); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 44.4; session.cast_distance_m = 32.0; caught_recorded = true; _set_capture_catch_record(2, 41.2)
		"catch_tie": session.set_location("cedar_river", 0.0); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 42.0; session.cast_distance_m = 32.0; caught_recorded = true; _set_capture_catch_record(4, 42.0)
		"catch_long_species": session.set_location("pine_lake", 0.90); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 61.4; session.cast_distance_m = 37.0; caught_recorded = true; _set_capture_catch_record(3, 59.8)
		"pine_bass_catch": session.set_location("pine_lake", 0.60); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 48.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"pine_catfish_catch": session.set_location("pine_lake", 0.90); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 61.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"cedar_trout_catch": session.set_location("cedar_river", 0.0); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 42.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"cedar_smallmouth_catch": session.set_location("cedar_river", 0.65); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 45.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"cedar_catch": session.set_location("cedar_river", 0.97); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 89.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"records": _seed_capture_records(); view.overlay = "records"
		"records_mixed": _seed_capture_records_mixed(); view.overlay = "records"
		"records_empty": _clear_capture_records(); view.overlay = "records"
		"records_safe_top": _seed_capture_records(); view.safe_top_override = 91.0; view.overlay = "records"
		"records_safe_top_180": _seed_capture_records(); view.safe_top_override = 180.0; view.overlay = "records"
		"records_detail": _seed_capture_records(); save.data.best_cm.northern_pike = 88.6; view.journal_fish_id = "northern_pike"; save.data.catch_history = [{"fish_id": "northern_pike", "length_cm": 72.1, "location_id": "cedar_river", "timestamp_utc": 1699900000, "fight_seconds": 18.2, "cast_distance_m": 31.0}, {"fish_id": "northern_pike", "length_cm": 88.6, "location_id": "cedar_river", "timestamp_utc": 1700000000, "fight_seconds": 16.4, "cast_distance_m": 34.0}]; view.overlay = "journal_detail"
		"records_detail_safe_top_180": _seed_capture_records(); save.data.best_cm.northern_pike = 88.6; view.journal_fish_id = "northern_pike"; save.data.catch_history = [{"fish_id": "northern_pike", "length_cm": 72.1, "location_id": "cedar_river", "timestamp_utc": 1699900000, "fight_seconds": 18.2, "cast_distance_m": 31.0}, {"fish_id": "northern_pike", "length_cm": 88.6, "location_id": "cedar_river", "timestamp_utc": 1700000000, "fight_seconds": 16.4, "cast_distance_m": 34.0}]; view.safe_top_override = 180.0; view.overlay = "journal_detail"
		"catch_safe_top_180": view.safe_top_override = 180.0; session.set_location("cedar_river", 0.97); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 89.0; session.cast_distance_m = 36.2; caught_recorded = true
		"catch_recast_ready": session.set_location("cedar_river", 0.97); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 89.0; session.cast_distance_m = 36.2; session.terminal_elapsed = FishingSession.TERMINAL_RECAST_DWELL_SECONDS; session.terminal_still_elapsed = FishingSession.TERMINAL_STILL_SECONDS; caught_recorded = true
		"catch_tail_mid": session.set_location("cedar_river", 0.97); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 89.0; session.cast_distance_m = 36.2; session.terminal_elapsed = 0.32; ui_time = 0.16; caught_recorded = true
		"settings": view.overlay = "settings"
		"settings_safe_top_91": view.safe_top_override = 91.0; view.overlay = "settings"
		"settings_safe_top_180": view.safe_top_override = 180.0; view.overlay = "settings"
		"motion_setup": view.overlay = "motion_setup"
		"motion_setup_safe_top_180": view.safe_top_override = 180.0; view.overlay = "motion_setup"
		"diagnostics": view.overlay = "diagnostics"
		"top_nav_ready": _capture_top_nav_press("settings", 0.0); view.overlay = ""
		"top_nav_safe_top": _capture_top_nav_press("settings", 91.0); view.overlay = ""
		"top_nav_safe_top_180": _capture_top_nav_press("settings", 180.0); view.overlay = ""
		"settings_button_line_out_safe_top": session.arm_cast(); session.release_cast(0.8); _capture_top_nav_press("settings", 91.0)
		"waters_button_ready_safe_top": _capture_top_nav_press("locations", 91.0)
		"records_button_ready_safe_top": _capture_top_nav_press("records", 91.0)
		"top_nav_active_locked": session.arm_cast(); session.release_cast(0.8); _capture_top_nav_press("records", 91.0); _capture_top_nav_press("locations", 91.0)
		"locations", "locations_pine": session.set_location("pine_lake", 0.0); view.overlay = "locations"
		"locations_safe_top_91": view.safe_top_override = 91.0; session.set_location("pine_lake", 0.0); view.overlay = "locations"
		"locations_safe_top_180": view.safe_top_override = 180.0; session.set_location("pine_lake", 0.0); view.overlay = "locations"
		"locations_cedar": session.set_location("cedar_river", 0.0); view.overlay = "locations"
		"escaped": session.state = FishingSession.State.ESCAPED; session.last_reason = "The line went slack."
		"reduced_motion": save.data.settings.reduced_motion = true
		"reduced_bite": save.data.settings.reduced_motion = true; session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.BITE; session.bite_elapsed = 0.20
		"reduced_reeling_high": save.data.settings.reduced_motion = true; session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.88; session.rod_load = 0.88
		"reduced_catch": save.data.settings.reduced_motion = true; session.state = FishingSession.State.CAUGHT; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"synthetic_reserve": view.synthetic_reserve = 88.0
		_: pass
	if session.state in [FishingSession.State.LINE_OUT, FishingSession.State.BITE, FishingSession.State.HOOK_WINDOW, FishingSession.State.REELING]: cast_visual_elapsed = 0.32
func _seed_capture_records() -> void:
	var count := 1
	for fish in FishDefinition.all_planned(): save.data.catches[fish.id] = count; save.data.best_cm[fish.id] = fish.min_length_cm + 3.5; count += 1
func _clear_capture_records() -> void:
	for fish in FishDefinition.all_planned(): save.data.catches[fish.id] = 0; save.data.best_cm[fish.id] = 0.0
func _seed_capture_records_mixed() -> void:
	_clear_capture_records()
	var selected := ["bluegill", "channel_catfish", "northern_pike"]
	for fish in FishDefinition.all_planned():
		if fish.id in selected:
			save.data.catches[fish.id] = 2 if fish.id == "bluegill" else 1
			save.data.best_cm[fish.id] = fish.min_length_cm + 4.0
func _set_capture_catch_record(count: int, best: float) -> void:
	catch_prior_count = count; catch_prior_best_cm = best
	save.data.catches[session.fish.id] = count
	save.data.best_cm[session.fish.id] = best
func _capture_top_nav_press(target: String, safe_top: float) -> void:
	view.safe_top_override = safe_top; view._refresh_top_nav_geometry()
	match target:
		"records": view._handle_press(view.records_rect.get_center())
		"locations": view._handle_press(view.locations_rect.get_center())
		"settings": view._handle_press(view.settings_rect.get_center())
func _capture_after_draw() -> void:
	# Windowed OpenGL can need multiple resize/present frames to resolve imported
	# full-screen art. Use a fixed settle, then wait for the rendered backbuffer.
	for frame in range(32): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image(); var error := image.save_png(capture_path)
	print("SCREENSHOT_CAPTURED path=%s error=%s" % [capture_path, error]); get_tree().quit(0 if error == OK else 1)

class FishingView extends Control:
	# Terminal guide contacts from deterministic repack metadata; each strict cell owns one rod.
	const ROD_DESTINATION := Rect2(-85, 545, 435, 870)
	const ROD_FRAME_SIZE := Vector2(512, 1024)
	const ROD_TIP_ANCHORS := [Vector2(454.77, 22.98), Vector2(496.65, 34.98), Vector2(435.68, 122.85)]
	# The photographic base remains one alpha master. Its hand/reel are stationary;
	# the later fight mesh owns only its upper shaft and shares this terminal ring.
	# Reviewed against the actual Cedar capture: this keeps the terminal guide in
	# open water below the active safe chrome rather than up in the riverbank.
	const PHOTOREAL_ROD_DESTINATION := Rect2(-80, 434, 480, 852)
	const PHOTOREAL_ROD_SOURCE_SIZE := Vector2(941, 1672)
	const PHOTOREAL_ROD_TIP_SOURCE := Vector2(785, 42)
	const CONTROL_REGIONS := {
		"plaque_normal": Rect2(20, 72, 332, 112), "plaque_pressed": Rect2(364, 72, 332, 112), "plaque_disabled": Rect2(692, 72, 312, 112),
		"row_normal": Rect2(42, 252, 446, 134), "row_selected": Rect2(532, 252, 446, 134), "card_normal": Rect2(82, 445, 196, 182),
		"modal": Rect2(24, 754, 512, 682), "teal_long": Rect2(556, 812, 438, 126)
	}
	var rod_frames: Array[AtlasTexture] = []
	var controller: Node
	var overlay := ""
	var synthetic_reserve := 0.0
	var safe_top_override := -1.0
	var top_nav_strip_rect := Rect2(358, 12, 338, 156)
	var records_rect := Rect2(358, 12, 112, 156)
	var locations_rect := Rect2(470, 12, 112, 156)
	var settings_rect := Rect2(582, 12, 114, 156)
	var back_to_fishing_rect := Rect2(420, 18, 264, 64)
	var location_pine_rect := Rect2(42, 240, 636, 380)
	var location_cedar_rect := Rect2(42, 680, 636, 380)
	var modal_panel_rect := Rect2(55, 150, 610, 960)
	var modal_header_rect := Rect2(226, 178, 272, 102)
	var modal_footer_rect := Rect2(222, 992, 278, 104)
	var settings_haptics_rect := Rect2(98, 304, 524, 72)
	var settings_reduced_motion_rect := Rect2(98, 394, 524, 72)
	var settings_handedness_rect := Rect2(98, 484, 524, 72)
	var settings_test_haptics_rect := Rect2(98, 640, 524, 72)
	var settings_motion_setup_rect := Rect2(98, 740, 524, 72)
	var settings_footer_close_rect := Rect2(222, 992, 278, 104)
	var motion_sensitivity_rect := Rect2(98, 304, 524, 72)
	var motion_recalibrate_rect := Rect2(98, 394, 524, 72)
	var motion_capture_rect := Rect2(98, 484, 524, 72)
	var motion_diagnostics_rect := Rect2(98, 574, 524, 72)
	var motion_back_rect := Rect2(222, 992, 278, 104)
	var catch_continue_rect := Rect2(92, 914, 250, 70)
	var catch_records_rect := Rect2(378, 914, 250, 70)
	var journal_slot_rects := [Rect2(68, 236, 280, 284), Rect2(372, 236, 280, 284), Rect2(68, 548, 280, 284), Rect2(372, 548, 280, 284), Rect2(68, 860, 280, 284), Rect2(372, 860, 280, 284)]
	var journal_detail_back_rect := Rect2(58, 1124, 270, 72)
	var journal_detail_next_rect := Rect2(392, 1124, 270, 72)
	var journal_fish_id := "bluegill"
	var journal_history_offset := 0
	var records_world_rect := Rect2(28, 24, 190, 58)
	var world_back_rect := Rect2(92, 992, 250, 70)
	var world_period_rect := Rect2(374, 860, 260, 70)
	var world_retry_rect := Rect2(86, 860, 260, 70)
	var font: Font
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		font = ThemeDB.fallback_font
		_cache_rod_frames()
		_refresh_top_nav_geometry()
		_refresh_modal_layout()
		queue_redraw()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_refresh_top_nav_geometry()
			_refresh_modal_layout()
	func _virtual_safe_top() -> float:
		if safe_top_override >= 0.0: return clampf(safe_top_override, 0.0, 180.0)
		var screen_size := DisplayServer.screen_get_size()
		var safe_area := DisplayServer.get_display_safe_area()
		var scale_y := 1280.0 / maxf(float(screen_size.y), 1.0)
		# Keep a conservative virtual cap so malformed desktop safe-area data cannot
		# push portrait chrome offscreen. Pixel 9 Pro's 153px inset maps to ~91px.
		return clampf(float(safe_area.position.y) * scale_y, 0.0, 180.0)
	func _refresh_top_nav_geometry() -> void:
		var chrome_y := _virtual_safe_top()
		if controller != null and controller.session != null and controller.session.state in [FishingSession.State.CAST_ARMED, FishingSession.State.LINE_OUT, FishingSession.State.BITE, FishingSession.State.HOOK_WINDOW, FishingSession.State.REELING]:
			top_nav_strip_rect = Rect2(18, chrome_y + 10, 568, 62); records_rect = Rect2(); locations_rect = Rect2(); settings_rect = Rect2(624, chrome_y + 10, 70, 70)
			return
		top_nav_strip_rect = Rect2(0, chrome_y, 720, 108)
		# These are the physical engraved plaques after the 2172px wood beam maps to
		# the 720px presentation. Draw and hit routing deliberately share these bounds.
		records_rect = Rect2(398, chrome_y + 17, 85, 86)
		locations_rect = Rect2(496, chrome_y + 17, 87, 86)
		settings_rect = Rect2(594, chrome_y + 17, 86, 86)
	func _refresh_modal_layout() -> void:
		var panel_y := maxf(150.0, _virtual_safe_top() + 20.0)
		modal_panel_rect = Rect2(55, panel_y, 610, 960)
		# The opaque source modal owns its header/footer plaques. Map their source
		# bounds through this same transform for native labels and hit targets.
		var source: Rect2 = CONTROL_REGIONS.modal
		var scale := modal_panel_rect.size / source.size
		modal_header_rect = Rect2(modal_panel_rect.position + (Rect2(168, 774, 228, 72).position - source.position) * scale, Rect2(168, 774, 228, 72).size * scale)
		modal_footer_rect = Rect2(modal_panel_rect.position + (Rect2(164, 1352, 234, 74).position - source.position) * scale, Rect2(164, 1352, 234, 74).size * scale)
		settings_haptics_rect = Rect2(98, panel_y + 154, 524, 72)
		settings_reduced_motion_rect = Rect2(98, panel_y + 244, 524, 72)
		settings_handedness_rect = Rect2(98, panel_y + 334, 524, 72)
		settings_test_haptics_rect = Rect2(98, panel_y + 490, 524, 72)
		settings_motion_setup_rect = Rect2(98, panel_y + 590, 524, 72)
		settings_footer_close_rect = modal_footer_rect
		motion_sensitivity_rect = Rect2(98, panel_y + 154, 524, 72)
		motion_recalibrate_rect = Rect2(98, panel_y + 244, 524, 72)
		motion_capture_rect = Rect2(98, panel_y + 334, 524, 72)
		motion_diagnostics_rect = Rect2(98, panel_y + 424, 524, 72)
		motion_back_rect = modal_footer_rect
	func _draw_modal_panel() -> void:
		if controller.control_kit_texture: draw_texture_rect_region(controller.control_kit_texture, modal_panel_rect, CONTROL_REGIONS.modal)
		else: draw_style_box(_control_style("modal"), modal_panel_rect)
	func _modal_footer_font_size(label: String) -> int:
		# Keep labels between the baked footer's two brass bolts rather than relying
		# on a shorter neighboring label to imply that long copy will fit.
		var usable_width := modal_footer_rect.size.x - 96.0
		for point_size in range(18, 11, -1):
			if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x <= usable_width: return point_size
		return 12
	func _draw() -> void:
		var size := get_size(); draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / 720.0, size.y / 1280.0))
		if controller.loading_active: _draw_loading()
		else: _draw_world()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	func _draw_loading() -> void:
		if controller.splash_texture: draw_texture_rect(controller.splash_texture, Rect2(0, 0, 720, 1280), false)
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.03, 0.10, 0.14, clampf(0.28 - controller.loading_elapsed * 0.22, 0.0, 0.28)))
		_text("CAST & CRANK", Vector2(128, 1040), 46, Color("fff4cf")); _text("PINE LAKE", Vector2(281, 1080), 18, Color("d9f0e2"))
	func _draw_world() -> void:
		var s: FishingSession = controller.session
		var background: Texture2D = controller.cedar_river_texture if s.location_id == "cedar_river" else controller.pine_lake_texture
		if background: draw_texture_rect(background, Rect2(0, 0, 720, 1280), false)
		else: draw_rect(Rect2(0, 0, 720, 1280), Color("1c617d"))
		if s.state == FishingSession.State.CAUGHT:
			_draw_top_chrome(s); _draw_catch_reveal(s)
		else:
			_draw_lake_motion(s); _draw_top_chrome(s); _draw_glance_hint(s); _draw_fight_status(s)
			if s.state == FishingSession.State.ESCAPED: _draw_escape_card(s)
		if synthetic_reserve > 0.0: draw_rect(Rect2(0, 1280 - synthetic_reserve, 720, synthetic_reserve), Color("ff2f5f", 0.68)); _text("SYNTHETIC OVERLAY STRESS — NOT NATIVE AD", Vector2(66, 1248), 16, Color.WHITE)
		if overlay == "calibration": _draw_calibration()
		elif overlay == "settings": _draw_settings()
		elif overlay == "records": _draw_records()
		elif overlay == "journal_detail": _draw_journal_detail()
		elif overlay == "world_records": _draw_world_records()
		elif overlay == "locations": _draw_locations()
		elif overlay == "motion_setup": _draw_motion_setup()
		elif overlay == "diagnostics": _draw_diagnostics()
		elif overlay == "capture" or overlay == "capture_saved": _draw_cast_capture()
	func _draw_lake_motion(s: FishingSession) -> void:
		var reduced := bool(controller.save.data.settings.get("reduced_motion", false))
		if s.state in [FishingSession.State.READY, FishingSession.State.CAST_ARMED]:
			# River ambience belongs to the water plate even before the line is out.
			_draw_river_life(s, Vector2(492, 650), reduced)
			# The rod art contains its own line until the terminal guide. Water stays clear
			# until a real cast has landed.
			_draw_ready_photoreal_rod()
			return
		var wave := 0.0 if reduced else sin(controller.ui_time * 2.2) * 5.0
		var landing_blend := 1.0 if reduced else clampf(controller.cast_visual_elapsed / 0.32, 0.0, 1.0)
		var bobber_pos: Vector2 = controller.presentation_bobber_position(s.cast_distance_m, s.fight_progress, s.state == FishingSession.State.REELING, landing_blend) + Vector2(0, wave)
		_draw_river_life(s, bobber_pos, reduced)
		var submerged := s.state in [FishingSession.State.BITE, FishingSession.State.HOOK_WINDOW, FishingSession.State.REELING]
		# Keep the external line attached to the stable water-surface contact. The
		# float itself vanishes beneath that contact during bite/fight; it does not
		# drag the visible line endpoint downward.
		var rod_region := 0 if s.state != FishingSession.State.REELING else clampi(int(round(maxf(s.tension, s.rod_load) * 2.0)), 0, 2)
		var rod_tip := _photoreal_rod_tip() if rod_region == 0 and controller.photoreal_rod_texture else _rod_tip_for_frame(rod_region)
		# Draw the external line behind the rod; the rod atlas owns handle-to-terminal-guide pixels.
		var mono := Color("e5eee8", 0.60)
		if submerged: draw_line(rod_tip, bobber_pos, mono, 1.1, true)
		else:
			var sag_depth := minf(14.0, 5.0 + s.cast_distance_m * 0.22)
			var curve := PackedVector2Array()
			for sample in range(9):
				var t := float(sample) / 8.0
				curve.append(rod_tip.lerp(bobber_pos, t) + Vector2(0, sag_depth * 4.0 * t * (1.0 - t)))
			draw_polyline(curve, mono, 1.0, true)
		if rod_region == 0: _draw_ready_photoreal_rod()
		elif rod_region < rod_frames.size(): draw_texture_rect(rod_frames[rod_region], ROD_DESTINATION, false)
		if not submerged and controller.bobber_texture:
			# The source canvas has generous transparent padding; map the known visible
			# body region so distance scaling measures the float rather than its canvas.
			var float_size := lerpf(30.0, 18.0, clampf(s.cast_distance_m / 42.0, 0.0, 1.0))
			draw_texture_rect_region(controller.bobber_texture, Rect2(bobber_pos - Vector2(float_size * 0.5, float_size * 0.62), Vector2(float_size, float_size * 1.24)), Rect2(496, 369, 383, 488))
		if controller.reaction_texture and (submerged or not reduced):
			var frame := 0 if reduced else int(floor(controller.ui_time * 8.0)) % 6
			var alpha := 1.0 if submerged else 0.36
			var reaction_size := Vector2(218, 132) if submerged else Vector2(172, 108)
			draw_texture_rect_region(controller.reaction_texture, Rect2(bobber_pos - reaction_size * Vector2(0.5, 0.42), reaction_size), Rect2(frame * 362, 0, 362, 724), Color(1, 1, 1, alpha))
		if submerged:
			var pulse := 0.0 if reduced else fmod(controller.ui_time * (5.0 if s.state == FishingSession.State.REELING else 3.0), 1.0)
			for ring in range(3):
				var radius := 14.0 + ring * 15.0 + pulse * 9.0
				draw_arc(bobber_pos + Vector2(0, 5), radius, 0.15, TAU - 0.15, 28, Color("d9f6ea", 0.72 - ring * 0.17), 1.6)
		if s.state == FishingSession.State.REELING and not reduced:
			draw_circle(bobber_pos + Vector2(18, 18), 7 + sin(controller.ui_time * 12.0) * 2, Color("e8fbf4", 0.78))
	func _draw_river_life(s: FishingSession, bobber_pos: Vector2, reduced: bool) -> void:
		if s.location_id != "cedar_river": return
		# Code-native life sits only on water; the photographic plate remains the sole
		# owner of banks and rocks, avoiding a second static layer or alpha seams.
		if not reduced:
			for band in range(3):
				var flow_y := 510.0 + band * 126.0
				var flow_x := fmod(controller.ui_time * (18.0 + band * 6.0) + band * 188.0, 720.0)
				# Low-cost reflection flow is confined to the known open-water bands; it
				# never moves photographic banks, rocks, or adds duplicate foliage.
				draw_line(Vector2(flow_x - 24, flow_y), Vector2(flow_x + 24, flow_y + 3), Color(0.82, 0.94, 0.92, 0.11), 1.2)
		if s.state != FishingSession.State.LINE_OUT: return
		var bite_delay := maxf(0.01, s.fish.bite_delay_seconds)
		var approach := clampf(inverse_lerp(maxf(0.0, bite_delay - 1.05), bite_delay, s.elapsed), 0.0, 1.0)
		if approach <= 0.0: return
		# Shadow reaches the real contact at the actual bite without revealing species.
		var start := bobber_pos + Vector2(-128.0, 72.0)
		var shadow := start.lerp(bobber_pos + Vector2(-6, 14), approach)
		var body_w := lerpf(30.0, 52.0, approach)
		var body_h := body_w * 0.32
		# Tapered body and tail are drawn in canonical screen coordinates, preserving
		# the parent viewport scale at non-720 captures without a transform reset.
		var silhouette := PackedVector2Array([shadow + Vector2(-body_w * 0.5, 0), shadow + Vector2(-body_w * 0.18, -body_h), shadow + Vector2(body_w * 0.34, -body_h * 0.62), shadow + Vector2(body_w * 0.50, 0), shadow + Vector2(body_w * 0.34, body_h * 0.62), shadow + Vector2(-body_w * 0.18, body_h), shadow + Vector2(-body_w * 0.58, body_h * 0.52), shadow + Vector2(-body_w * 0.76, 0), shadow + Vector2(-body_w * 0.58, -body_h * 0.52)])
		draw_colored_polygon(silhouette, Color(0.015, 0.10, 0.11, 0.22 + approach * 0.18))
	func _rod_tip_for_frame(frame: int) -> Vector2:
		var source_tip: Vector2 = ROD_TIP_ANCHORS[clampi(frame, 0, ROD_TIP_ANCHORS.size() - 1)]
		return ROD_DESTINATION.position + Vector2(
			source_tip.x / ROD_FRAME_SIZE.x * ROD_DESTINATION.size.x,
			source_tip.y / ROD_FRAME_SIZE.y * ROD_DESTINATION.size.y
		)
	func _photoreal_rod_tip() -> Vector2:
		return PHOTOREAL_ROD_DESTINATION.position + Vector2(
			PHOTOREAL_ROD_TIP_SOURCE.x / PHOTOREAL_ROD_SOURCE_SIZE.x * PHOTOREAL_ROD_DESTINATION.size.x,
			PHOTOREAL_ROD_TIP_SOURCE.y / PHOTOREAL_ROD_SOURCE_SIZE.y * PHOTOREAL_ROD_DESTINATION.size.y
		)
	func _draw_ready_photoreal_rod() -> void:
		if controller.photoreal_rod_texture:
			draw_texture_rect(controller.photoreal_rod_texture, PHOTOREAL_ROD_DESTINATION, false)
		elif not rod_frames.is_empty(): draw_texture_rect(rod_frames[0], ROD_DESTINATION, false)
	func _cache_rod_frames() -> void:
		rod_frames.clear()
		if controller.rod_texture == null: return
		for frame in range(3):
			var atlas := AtlasTexture.new()
			atlas.atlas = controller.rod_texture
			atlas.region = Rect2(frame * 512, 0, 512, 1024)
			atlas.filter_clip = true
			rod_frames.append(atlas)
	func _draw_top_chrome(s: FishingSession) -> void:
		var chrome_y := _virtual_safe_top()
		var active := s.state in [FishingSession.State.CAST_ARMED, FishingSession.State.LINE_OUT, FishingSession.State.BITE, FishingSession.State.HOOK_WINDOW, FishingSession.State.REELING]
		if active:
			# No tinted/opaque backing band: compact solid wood controls sit directly
			# over the scenery while fishing remains eyes-off.
			_refresh_top_nav_geometry()
			if controller.top_nav_texture:
				draw_texture_rect_region(controller.top_nav_texture, top_nav_strip_rect, Rect2(124, 172, 1012, 323))
				draw_texture_rect_region(controller.top_nav_texture, settings_rect, Rect2(1793, 223, 249, 257))
			return
		_refresh_top_nav_geometry()
		if controller.top_nav_texture: draw_texture_rect_region(controller.top_nav_texture, top_nav_strip_rect, Rect2(0, 172, 2172, 323))
		_text(s.location_id.replace("_", " ").to_upper(), Vector2(42, chrome_y + 34), 18, Color("332016"))
	func _draw_glance_hint(s: FishingSession) -> void:
		if controller.ui_notice_remaining > 0.0:
			var notice_y := _virtual_safe_top() + 126.0
			draw_style_box(_control_style("plaque_pressed"), Rect2(30, notice_y, 314, 52)); _centered_text(controller.ui_notice, Vector2(187, notice_y + 34), 13, Color("fff7dc")); return
		var copy := "TILT LEFT, THEN SNAP RIGHT" if controller.motion.left_handed else "TILT RIGHT, THEN SNAP LEFT"
		match s.state:
			FishingSession.State.CAST_ARMED: copy = "SNAP RIGHT" if controller.motion.left_handed else "SNAP LEFT"
			FishingSession.State.LINE_OUT: copy = "%s  •  %.0f m" % [s.fish.habitat_name(s.cast_distance_m), s.cast_distance_m]
			FishingSession.State.BITE: copy = "FISH ON — WAIT FOR THE PULSES"
			FishingSession.State.HOOK_WINDOW: copy = "BITE — PULL LEFT" if controller.motion.left_handed else "BITE — PULL RIGHT"
			FishingSession.State.REELING: copy = ("TILT RIGHT TO EASE" if controller.motion.left_handed else "TILT LEFT TO EASE") if s.tension >= 0.65 else ("TILT LEFT TO PULL" if controller.motion.left_handed else "TILT RIGHT TO PULL")
			FishingSession.State.CAUGHT: copy = "%s LANDED" % s.fish.display_name.to_upper()
			FishingSession.State.ESCAPED: copy = s.last_reason.to_upper()
		var compact := s.state in [FishingSession.State.CAST_ARMED, FishingSession.State.LINE_OUT, FishingSession.State.BITE, FishingSession.State.HOOK_WINDOW, FishingSession.State.REELING]
		var hint_y := _virtual_safe_top() + (12.0 if compact else 36.0)
		if compact:
			_centered_text(copy, Vector2(301, hint_y + 36), 16, Color("332016"))
			return
		if s.state == FishingSession.State.READY:
			_centered_text("TILT %s" % ("LEFT" if controller.motion.left_handed else "RIGHT"), Vector2(214, hint_y + 30), 18, Color("332016")); _centered_text("THEN SNAP %s" % ("RIGHT" if controller.motion.left_handed else "LEFT"), Vector2(214, hint_y + 56), 18, Color("332016"))
		elif s.state == FishingSession.State.HOOK_WINDOW:
			_centered_text("BITE", Vector2(214, hint_y + 29), 21, Color("f2e4c2")); _centered_text("PULL %s" % ("LEFT" if controller.motion.left_handed else "RIGHT"), Vector2(214, hint_y + 57), 20, Color("f2e4c2"))
		elif s.state == FishingSession.State.BITE:
			_centered_text("BITE", Vector2(214, hint_y + 36), 21, Color("f2e4c2")); _centered_text("WAIT FOR PULSES", Vector2(214, hint_y + 68), 18, Color("f2e4c2"))
		elif s.state == FishingSession.State.ESCAPED: _centered_text("FISH GOT AWAY", Vector2(214, hint_y + 52), 20, Color("f2e4c2"))
		else: _centered_text(copy, Vector2(214, hint_y + 43), 17, Color("f2e4c2"))
	func _draw_fight_status(s: FishingSession) -> void:
		if s.state != FishingSession.State.REELING: return
		draw_style_box(_panel_style(Color(0.03, 0.14, 0.20, 0.74), Color("79b9ad", 0.7)), Rect2(170, 1084, 380, 78)); _text("LANDING", Vector2(190, 1111), 14, Color("d9efe3")); draw_rect(Rect2(275, 1102, 252, 7), Color("153947")); draw_rect(Rect2(275, 1102, 252 * s.fight_progress, 7), Color("70d5ad")); _text("TENSION", Vector2(190, 1144), 14, Color("d9efe3")); draw_rect(Rect2(275, 1135, 252, 7), Color("321b28")); draw_rect(Rect2(275, 1135, 252 * s.tension, 7), Color("ed695e") if s.tension >= 0.65 else Color("e1c46e"))
	func _draw_catch_reveal(s: FishingSession) -> void:
		var reduced := bool(controller.save.data.settings.get("reduced_motion", false))
		# A short lift, tail flick, and droplets reward the one moment the player
		# looks up. Reduced motion keeps the same composition static.
		var body_shift := maxf(0.0, _virtual_safe_top() + 210.0 - 300.0)
		var lift := 0.0 if reduced else clampf(s.terminal_elapsed / 0.55, 0.0, 1.0) * 42.0
		var tail_flick := 0.0 if reduced else sin(controller.ui_time * 10.0) * 12.0 * (1.0 - clampf(s.terminal_elapsed / 1.0, 0.0, 1.0))
		var fish_rect := Rect2(86, 300 + body_shift - lift, 548, 330)
		# The head/body stays pinned; only the tail slice bends briefly after landing.
		_draw_fish_catch_flick(s.fish.id, fish_rect, tail_flick)
		var droplet_phase := clampf(s.terminal_elapsed / 1.15, 0.0, 1.0)
		if not reduced and droplet_phase < 1.0:
			for i in range(7): draw_circle(Vector2(104 + i * 86, 618 + body_shift - lift * 0.22 + droplet_phase * (22 + i * 7)), 3 + (i % 3), Color("d6f7ef", 0.62 * (1.0 - droplet_phase)))
		var length := s.catch_length_cm if s.catch_length_cm > 0.0 else lerpf(s.fish.min_length_cm, s.fish.max_length_cm, s.cast_quality)
		var status: String = controller._catch_status(length)
		# Measurement is the focal data treatment; this is not a trophy frame.
		draw_style_box(_control_style("row_selected"), Rect2(74, 672 + body_shift, 572, 108))
		for mark in range(11):
			var x := 106.0 + mark * 50.5
			draw_line(Vector2(x, 746 + body_shift), Vector2(x, 746 + body_shift - (22 if mark % 2 == 0 else 12)), Color("fff2c4"), 2.0)
		_centered_text("%.1f cm" % length, Vector2(360, 720 + body_shift), 34, Color("fff4d1"))
		_text(s.fish.display_name.to_upper(), Vector2(102, 822 + body_shift), 29, Color(0.01, 0.07, 0.08, 0.72)); _text(s.fish.display_name.to_upper(), Vector2(100, 820 + body_shift), 29, Color("fff1c4"))
		_centered_text(status, Vector2(360, 858 + body_shift), 19, Color("f3d979"))
		_centered_text("%s  •  %.0f m CAST" % [s.location_id.replace("_", " ").to_upper(), s.cast_distance_m], Vector2(360, 892 + body_shift), 16, Color("d7eee4"))
		catch_continue_rect = Rect2(92, 914 + body_shift, 250, 70); catch_records_rect = Rect2(378, 914 + body_shift, 250, 70)
		draw_style_box(_control_style("plaque_normal"), catch_continue_rect); draw_style_box(_control_style("plaque_normal"), catch_records_rect)
		_centered_text("CONTINUE", catch_continue_rect.get_center() + Vector2(0, 6), 18, Color("fff1c4")); _centered_text("RECORDS", catch_records_rect.get_center() + Vector2(0, 6), 18, Color("fff1c4"))
		if s.can_recast_from_motion(): _centered_text("READY — TILT, THEN SNAP TO CAST AGAIN", Vector2(360, 1018 + body_shift), 15, Color("fff4d1"))
	func _draw_escape_card(s: FishingSession) -> void:
		draw_style_box(_control_style("plaque_pressed"), Rect2(84, 650, 552, 238)); _text("FISH GOT AWAY", Vector2(203, 722), 31, Color("fff2d5")); _text(s.last_reason, Vector2(132, 770), 18, Color("ffd5c2")); _text("Ease forward when warning pulses speed up.", Vector2(115, 815), 17, Color("ffe4bc")); _text("READY — TILT, THEN SNAP TO CAST AGAIN" if s.can_recast_from_motion() else "SETTLE THE PHONE TO CAST AGAIN", Vector2(126 if s.can_recast_from_motion() else 162, 855), 16 if s.can_recast_from_motion() else 18, Color("fff2d5"))
	func _draw_calibration() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.86))
		draw_style_box(_panel_style(Color("eff3dc"), Color("fff6c5")), Rect2(54, 300, 612, 530))
		_text("MOTION CHECK", Vector2(180, 375), 34, Color("173a48"))
		var step: int = controller.motion.calibration_progress + 1
		_text("Practice cast %d of 2" % min(step, 2), Vector2(242, 430), 22, Color("2c6876"))
		var phase: String = controller.motion.calibration_phase
		var copy := "Rest the phone flat and still for a moment."
		if phase.contains("snap"):
			copy = "Now snap %s to finish this practice cast." % ("right" if controller.motion.left_handed else "left")
		elif phase.contains("back"):
			copy = "Tilt %s, then snap %s when ready." % ["left" if controller.motion.left_handed else "right", "right" if controller.motion.left_handed else "left"]
		_text(copy, Vector2(90, 510), 21, Color("173a48"))
		_text("Calibration starts automatically — no buttons.", Vector2(112, 580), 18, Color("416b72"))
	func _draw_settings() -> void:
		_refresh_modal_layout()
		if controller.rustic_settings_texture: draw_texture_rect(controller.rustic_settings_texture, Rect2(0, 0, 720, 1280), false)
		else: draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.88)); _draw_modal_panel()
		_centered_text("SETTINGS", modal_header_rect.get_center() + Vector2(0, 10), 30, Color("fff4d1")); var settings: Dictionary = controller.save.data.settings
		_draw_setting_row(settings_haptics_rect, "HAPTICS", "ON" if settings.haptics else "OFF")
		_draw_setting_row(settings_reduced_motion_rect, "REDUCED MOTION", "ON" if settings.reduced_motion else "OFF")
		_draw_setting_row(settings_handedness_rect, "HANDEDNESS", "LEFT" if settings.left_handed else "RIGHT")
		_centered_text("Changing handedness resets the active session", Vector2(360, modal_panel_rect.position.y + 442), 16, Color("123942")); _centered_text("and starts motion setup again.", Vector2(360, modal_panel_rect.position.y + 464), 16, Color("123942"))
		if controller.rustic_settings_texture == null: draw_style_box(_control_style("plaque_normal"), settings_test_haptics_rect)
		_centered_text("TEST VIBRATION", settings_test_haptics_rect.get_center() + Vector2(0, 6), 20, Color("fff4d1"))
		if controller.rustic_settings_texture == null: draw_style_box(_control_style("plaque_normal"), settings_motion_setup_rect)
		_centered_text("MOTION SETUP", settings_motion_setup_rect.get_center() + Vector2(0, 6), 20, Color("fff4d1"))
		_centered_text("BACK TO FISHING", settings_footer_close_rect.get_center() + Vector2(0, 6), 17, Color("fff4d1"))
	func _draw_setting_row(rect: Rect2, title: String, value: String) -> void:
		if controller.rustic_settings_texture == null: draw_style_box(_control_style("row_selected"), rect)
		_text(title, rect.position + Vector2(28, 44), 20, Color("3b2818") if controller.rustic_settings_texture else Color("fff5d8")); _text(value, rect.position + Vector2(414, 44), 20, Color("6e411d") if controller.rustic_settings_texture else Color("f3d979"))
	func _draw_motion_setup() -> void:
		_refresh_modal_layout()
		if controller.rustic_settings_texture: draw_texture_rect(controller.rustic_settings_texture, Rect2(0, 0, 720, 1280), false)
		else: draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.90)); _draw_modal_panel()
		_centered_text("MOTION SETUP", modal_header_rect.get_center() + Vector2(0, 8), 22, Color("fff4d1"))
		_draw_setting_row(motion_sensitivity_rect, "SENSITIVITY", "%.1f" % float(controller.save.data.settings.sensitivity))
		if controller.rustic_settings_texture == null:
			for rect in [motion_recalibrate_rect, motion_capture_rect, motion_diagnostics_rect]: draw_style_box(_control_style("plaque_normal"), rect)
		_centered_text("RECALIBRATE MOTION", motion_recalibrate_rect.get_center() + Vector2(0, 6), 20, Color("fff4d1")); _centered_text("RECORD 10 CASTS", motion_capture_rect.get_center() + Vector2(0, 6), 20, Color("fff4d1")); _centered_text("MOTION DIAGNOSTICS", motion_diagnostics_rect.get_center() + Vector2(0, 6), 20, Color("fff4d1"))
		_centered_text("Recalibration clears the active cast and starts", Vector2(360, modal_panel_rect.position.y + 534), 16, Color("123942")); _centered_text("two practice casts.", Vector2(360, modal_panel_rect.position.y + 556), 16, Color("123942"))
		_centered_text("BACK TO SETTINGS", motion_back_rect.get_center() + Vector2(0, 6), 17, Color("fff4d1"))
	func _draw_cast_capture() -> void:
		_refresh_modal_layout()
		var data: Dictionary = controller.cast_capture.status()
		var done := int(data.get("cast_index", 0))
		var phase := str(data.get("phase", "idle"))
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.90)); draw_style_box(_panel_style(Color("eff3dc"), Color("fff6c5")), Rect2(54, 330, 612, 490)); _text("CAST TUNING CAPTURE", Vector2(142, 412), 30, Color("173a48"))
		if phase == "saved":
			_text("10 CASTS SAVED", Vector2(210, 505), 29, Color("1e665d")); _text("Raw trace is stored only for this", Vector2(155, 558), 20, Color("416b72")); _text("explicit capture. Return to Motion Setup.", Vector2(132, 592), 20, Color("416b72")); draw_style_box(_control_style("plaque_normal"), motion_back_rect); _centered_text("BACK TO MOTION SETUP", motion_back_rect.get_center() + Vector2(0, 6), _modal_footer_font_size("BACK TO MOTION SETUP"), Color("fff4d1")); return
		var copy := "GET READY — WINDOWS BEGIN SOON"
		if phase == "active": copy = "CAST NOW — TILT, THEN SNAP"
		elif phase == "rest": copy = "REST — NEXT WINDOW WILL VIBRATE"
		_text("CAST %d OF %d" % [min(done + 1, CastCaptureService.CAST_COUNT), CastCaptureService.CAST_COUNT], Vector2(248, 488), 24, Color("2c6876")); _text(copy, Vector2(118, 554), 22, Color("173a48")); _text("No taps needed. Gameplay is paused.", Vector2(170, 624), 19, Color("416b72")); _text("Each active window is haptic-cued.", Vector2(168, 658), 19, Color("416b72"))
	func _draw_locations() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.01, 0.06, 0.09, 0.92))
		var safe_top := _virtual_safe_top()
		_draw_back_to_fishing(safe_top)
		_text("CHOOSE WATER", Vector2(46, safe_top + 124), 34, Color("fff4d1"))
		_refresh_location_card_rects(safe_top)
		_draw_location_card("PINE LAKE", "Near reeds • mid coves • far channel", controller.pine_lake_texture, location_pine_rect, controller.session.location_id == "pine_lake")
		_draw_location_card("CEDAR RIVER", "Near eddies • mid current • far run", controller.cedar_river_texture, location_cedar_rect, controller.session.location_id == "cedar_river")
		_text("Finish this cast before changing water." if not controller._can_open_records() else "Tap a water to fish it", Vector2(150, minf(1210.0, location_pine_rect.position.y + 924.0)), 18, Color("d9e9d9"))
	func _draw_back_to_fishing(safe_top: float) -> void:
		_refresh_back_to_fishing_rect(safe_top)
		draw_style_box(_control_style("plaque_normal"), back_to_fishing_rect)
		_centered_text("BACK TO FISHING", back_to_fishing_rect.get_center() + Vector2(0, 6), 17, Color("fff4d1"))
	func _refresh_back_to_fishing_rect(safe_top: float) -> void:
		back_to_fishing_rect = Rect2(420, safe_top + 18, 264, 64)
	func _draw_records_back_to_fishing(safe_top: float) -> void:
		_refresh_records_back_to_fishing_rect(safe_top)
		var visual_rect := Rect2(back_to_fishing_rect.position + Vector2(14, 8), back_to_fishing_rect.size - Vector2(28, 18))
		draw_style_box(_control_style("plaque_normal"), visual_rect)
		_centered_text("BACK TO FISHING", visual_rect.get_center() + Vector2(0, 5), 16, Color("fff4d1"))
	func _refresh_records_back_to_fishing_rect(safe_top: float) -> void:
		# The bottom journal footer is clear of the authored crest and all six fish; the hit target stays safe-aware.
		var visual_y := maxf(1168.0, safe_top + 18.0)
		back_to_fishing_rect = Rect2(416, visual_y - 8.0, 280, 64)
	func _refresh_location_card_rects(safe_top: float) -> void:
		var card_top := maxf(240.0, safe_top + 170.0)
		location_pine_rect = Rect2(42, card_top, 636, 380)
		location_cedar_rect = Rect2(42, card_top + 440.0, 636, 380)
	func _draw_location_card(title: String, species: String, texture: Texture2D, rect: Rect2, selected: bool) -> void:
		if texture: draw_texture_rect_region(texture, rect, Rect2(0, 335, 941, 940))
		else: draw_rect(rect, Color("1b566a"))
		draw_rect(rect, Color(0.01, 0.10, 0.13, 0.28))
		if selected: draw_style_box(_panel_style(Color(0.0, 0.0, 0.0, 0.0), Color("f0d579")), rect.grow(-4.0))
		var info_rect := Rect2(rect.position + Vector2(18, rect.size.y - 148), Vector2(rect.size.x - 36, 124))
		draw_style_box(_control_style("row_selected" if selected else "row_normal"), info_rect)
		_text(title, info_rect.position + Vector2(22, 44), 27, Color("fff2c9")); _text(species, info_rect.position + Vector2(22, 73), 15, Color("d1eadf")); _text("%d / 3 DISCOVERED" % controller._discovered_species_count("pine_lake" if title == "PINE LAKE" else "cedar_river"), info_rect.position + Vector2(22, 98), 16, Color("f3d979"))
		if selected:
			draw_style_box(_panel_style(Color("123942", 0.92), Color("f0d579")), Rect2(rect.position + Vector2(rect.size.x - 146, 18), Vector2(120, 42)))
			_text("SELECTED", rect.position + Vector2(rect.size.x - 129, 47), 15, Color("fff2c9"))
	func _draw_diagnostics() -> void:
		_refresh_modal_layout()
		var data: Dictionary = controller.motion.get_diagnostics(); var reasons: Dictionary = data.reasons
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.88)); draw_style_box(_panel_style(Color("eaf2dc"), Color("fff6c5")), Rect2(55, 300, 610, 590)); _text("MOTION DIAGNOSTICS", Vector2(150, 390), 30, Color("173a48")); _text("Tilt attempts: %d" % int(data.cock_attempts), Vector2(125, 465), 21, Color("173a48")); _text("Completed casts: %d" % int(data.completed_casts), Vector2(125, 510), 21, Color("173a48")); _text("Fails L/A/P/G/T: %d / %d / %d / %d / %d" % [int(reasons.linear), int(reasons.axis), int(reasons.polarity), int(reasons.gyro), int(reasons.timeout)], Vector2(82, 620), 18, Color("416b72")); _text("Derived counts only. Raw traces exist only after", Vector2(92, 694), 17, Color("416b72")); _text("an explicit RECORD 10 CASTS session.", Vector2(132, 722), 17, Color("416b72")); draw_style_box(_control_style("plaque_normal"), motion_back_rect); _centered_text("BACK TO MOTION SETUP", motion_back_rect.get_center() + Vector2(0, 6), _modal_footer_font_size("BACK TO MOTION SETUP"), Color("fff4d1"))
	func _draw_records() -> void:
		var safe_top := _virtual_safe_top()
		var page := _journal_page_rect(safe_top)
		draw_rect(Rect2(0, 0, 720, 1280), Color("06232c"))
		if controller.records_texture: draw_texture_rect(controller.records_texture, page, false)
		# One opaque authored page owns the journal/title/slots. Fish, silhouettes,
		# localized names, and stats are runtime-only because they change with saves.
		var fish_ids := ["bluegill", "largemouth_bass", "channel_catfish", "rainbow_trout", "smallmouth_bass", "northern_pike"]
		var canonical_slots := [Rect2(64, 225, 284, 254), Rect2(372, 225, 284, 254), Rect2(64, 503, 284, 256), Rect2(372, 503, 284, 256), Rect2(64, 786, 284, 250), Rect2(372, 786, 284, 250)]
		var discovered_total := 0
		for index in range(fish_ids.size()):
			var fish := _fish_definition(fish_ids[index])
			var count := int(controller.save.data.catches.get(fish.id, 0))
			var best := float(controller.save.data.best_cm.get(fish.id, 0.0))
			if count > 0: discovered_total += 1
			journal_slot_rects[index] = _journal_map_rect(canonical_slots[index], page)
			var slot: Rect2 = journal_slot_rects[index]
			_draw_fish_atlas_contained(fish.id, Rect2(slot.position + Vector2(14, 18), Vector2(slot.size.x - 28, slot.size.y - 92)), Color.WHITE if count > 0 else Color("172e2b"))
			_centered_text(fish.display_name.to_upper() if count > 0 else "UNDISCOVERED", slot.position + Vector2(slot.size.x * 0.5, slot.size.y - 52), maxi(11, int(16 * page.size.x / 720.0)), Color("5f4120"))
			_centered_text("%d caught  •  %s" % [count, ("%.1f cm" % best) if best > 0.0 else "—"], slot.position + Vector2(slot.size.x * 0.5, slot.size.y - 19), maxi(10, int(14 * page.size.x / 720.0)), Color("fff2c8"))
		_centered_text("%d / %d DISCOVERED" % [discovered_total, fish_ids.size()], Vector2(page.get_center().x, page.position.y + page.size.y - 40), maxi(11, int(15 * page.size.x / 720.0)), Color("fff2c8"))
		back_to_fishing_rect = _journal_map_rect(Rect2(420, 1164, 246, 58), page)
		draw_style_box(_control_style("plaque_normal"), back_to_fishing_rect)
		_centered_text("BACK TO FISHING", back_to_fishing_rect.get_center() + Vector2(0, 5), maxi(10, int(14 * page.size.x / 720.0)), Color("fff4d1"))
		records_world_rect = Rect2(26, safe_top + 18, 196, 58)
		draw_style_box(_control_style("plaque_normal"), records_world_rect)
		_centered_text("WORLD RECORDS", records_world_rect.get_center() + Vector2(0, 5), 15, Color("fff4d1"))
	func _draw_world_records() -> void:
		_refresh_modal_layout()
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.90)); _draw_modal_panel()
		_centered_text("WORLD RECORDS", modal_header_rect.get_center() + Vector2(0, 10), 22, Color("fff4d1"))
		var status: String = controller.leaderboards.status if controller.leaderboards != null else "UNAVAILABLE"
		var period: String = controller.leaderboards.period if controller.leaderboards != null else "ALL TIME"
		_centered_text(period, Vector2(360, modal_panel_rect.position.y + 150), 17, Color("f3d979"))
		if status == "UNAVAILABLE":
			_centered_text("ONLINE RECORDS AREN'T CONNECTED YET", Vector2(360, modal_panel_rect.position.y + 218), 17, Color("173a48"))
			_centered_text("Your local Catch Records always stay on this phone.", Vector2(360, modal_panel_rect.position.y + 250), 14, Color("416b72"))
			_centered_text("Play Games will appear here when this water opens online.", Vector2(360, modal_panel_rect.position.y + 276), 14, Color("416b72"))
		elif status == "NO_AUTH":
			_centered_text("CONNECT PLAY GAMES TO VIEW ONLINE RECORDS", Vector2(360, modal_panel_rect.position.y + 218), 16, Color("173a48"))
			_centered_text("Your local Catch Records always stay on this phone.", Vector2(360, modal_panel_rect.position.y + 248), 14, Color("416b72"))
		elif status == "ERROR":
			_centered_text("ONLINE RECORDS COULDN'T LOAD", Vector2(360, modal_panel_rect.position.y + 218), 17, Color("173a48"))
			_centered_text("Try again when Play Games is available.", Vector2(360, modal_panel_rect.position.y + 248), 14, Color("416b72"))
		else:
			_centered_text("%s — %s" % ["CONNECTING" if status in ["LOADING", "CONNECTING"] else "ONLINE", period], Vector2(360, modal_panel_rect.position.y + 218), 18, Color("173a48"))
		for index in range(FishDefinition.all_planned().size()):
			var fish: FishDefinition = FishDefinition.all_planned()[index]
			var best := float(controller.save.data.best_cm.get(fish.id, 0.0))
			var board: Dictionary = controller.leaderboards.board_for(fish.id) if controller.leaderboards != null else {}
			var top_mm := int(board.get("top_score_mm", 0)); var mine_mm := int(board.get("player_score_mm", 0)); var rank := int(board.get("player_rank", 0))
			var world_copy := "—" if top_mm <= 0 else "%s %.1f cm" % [str(board.get("top_name", "TOP")), top_mm / 10.0]
			var player_copy := "—" if mine_mm <= 0 else ("%.1f cm" % (mine_mm / 10.0) if rank <= 0 else "%.1f cm #%d" % [mine_mm / 10.0, rank])
			if bool(board.get("cached", false)) and player_copy != "—": player_copy += " (CACHED)"
			_centered_text("%s  •  LOCAL %s  •  YOU %s  •  WORLD %s" % [fish.display_name.to_upper(), "%.1f cm" % best if best > 0.0 else "—", player_copy, world_copy], Vector2(360, modal_panel_rect.position.y + 338 + index * 48), 12, Color("173a48"))
		world_retry_rect = Rect2(86, modal_panel_rect.position.y + 710, 260, 70)
		world_period_rect = Rect2(374, modal_panel_rect.position.y + 710, 260, 70)
		world_back_rect = modal_footer_rect
		draw_style_box(_control_style("plaque_normal"), world_retry_rect); draw_style_box(_control_style("plaque_normal"), world_period_rect)
		_centered_text("CONNECT" if status == "NO_AUTH" else "RETRY", world_retry_rect.get_center() + Vector2(0, 6), 17, Color("fff4d1")); _centered_text("WEEKLY" if period == "ALL TIME" else "ALL TIME", world_period_rect.get_center() + Vector2(0, 6), 16, Color("fff4d1")); _centered_text("BACK TO RECORDS", world_back_rect.get_center() + Vector2(0, 6), _modal_footer_font_size("BACK TO RECORDS"), Color("fff4d1"))
	func _journal_page_rect(safe_top: float) -> Rect2:
		var scale := clampf((1280.0 - safe_top) / 1280.0, 0.75, 1.0)
		return Rect2((720.0 - 720.0 * scale) * 0.5, safe_top, 720.0 * scale, 1280.0 * scale)
	func _journal_map_rect(canonical: Rect2, page: Rect2) -> Rect2:
		var scale := page.size.x / 720.0
		return Rect2(page.position + canonical.position * scale, canonical.size * scale)
	func _draw_journal_detail() -> void:
		var page := _journal_page_rect(_virtual_safe_top())
		draw_rect(Rect2(0, 0, 720, 1280), Color("06232c"))
		if controller.journal_detail_texture: draw_texture_rect(controller.journal_detail_texture, page, false)
		var fish := _fish_definition(journal_fish_id)
		var count := int(controller.save.data.catches.get(fish.id, 0))
		var best := float(controller.save.data.best_cm.get(fish.id, 0.0))
		var scale := page.size.x / 720.0
		var fish_rect := _journal_map_rect(Rect2(120, 228, 480, 350), page)
		_draw_fish_atlas_contained(fish.id, fish_rect, Color.WHITE if count > 0 else Color(0.08, 0.15, 0.14, 0.58))
		var title_y := page.position.y + 631.0 * scale
		_centered_text(fish.display_name.to_upper() if count > 0 else "UNDISCOVERED", Vector2(page.get_center().x, title_y), maxi(16, int(28 * scale)), Color("fff2c8"))
		_centered_text("%d CAUGHT  •  BEST %s" % [count, ("%.1f cm" % best) if best > 0.0 else "—"], Vector2(page.get_center().x, title_y + 32 * scale), maxi(12, int(18 * scale)), Color("fff2c8"))
		var history: Array[Dictionary] = controller.save.history_for_fish(fish.id)
		var history_y := page.position.y + 705.0 * scale
		_centered_text("RECENT CATCHES" if not history.is_empty() else "NO RECENT CATCHES YET", Vector2(page.get_center().x, history_y), maxi(12, int(17 * scale)), Color("5f4120"))
		for row in range(mini(4, maxi(0, history.size() - journal_history_offset))):
			var entry: Dictionary = history[history.size() - 1 - journal_history_offset - row]
			var date := Time.get_datetime_dict_from_unix_time(int(entry.timestamp_utc))
			var line := "%.1f cm  •  %s  •  %04d-%02d-%02d  •  %.1fs" % [float(entry.length_cm), str(entry.location_id).replace("_", " ").to_upper(), int(date.year), int(date.month), int(date.day), float(entry.fight_seconds)]
			_centered_text(line, Vector2(page.get_center().x, history_y + (38 + row * 32) * scale), maxi(11, int(15 * scale)), Color("5f4120"))
		var habitat_note := "Near reeds favor lighter strikes; far water can hold heavier runs."
		if fish.id == "northern_pike": habitat_note = "Pike runs hard. Ease at the urgent pulse, then pull in the lull."
		elif fish.id == "channel_catfish": habitat_note = "Catfish hold steady pressure. Let the line breathe between pulls."
		_centered_text(habitat_note, Vector2(page.get_center().x, history_y + 198 * scale), maxi(10, int(13 * scale)), Color("5f4120"))
		journal_detail_back_rect = _journal_map_rect(Rect2(54, 1120, 280, 72), page)
		journal_detail_next_rect = _journal_map_rect(Rect2(386, 1120, 280, 72), page)
		draw_style_box(_control_style("plaque_normal"), journal_detail_back_rect); draw_style_box(_control_style("plaque_normal" if history.size() > journal_history_offset + 4 else "plaque_disabled"), journal_detail_next_rect)
		_centered_text("BACK TO RECORDS", journal_detail_back_rect.get_center() + Vector2(0, 5), maxi(11, int(16 * scale)), Color("fff4d1"))
		_centered_text("OLDER" if history.size() > journal_history_offset + 4 else "NO OLDER CATCHES", journal_detail_next_rect.get_center() + Vector2(0, 5), maxi(10, int(14 * scale)), Color("fff4d1"))
	func _fish_definition(fish_id: String) -> FishDefinition:
		for fish in FishDefinition.all_planned():
			if fish.id == fish_id: return fish
		return FishDefinition.bluegill()
	func _draw_fish_atlas_contained(fish_id: String, destination: Rect2, modulate := Color.WHITE) -> void:
		var row := 0
		var atlas: Texture2D = controller.pine_fish_atlas
		match fish_id:
			"bluegill": row = 0
			"largemouth_bass": row = 1
			"channel_catfish": row = 2
			"rainbow_trout": atlas = controller.cedar_fish_atlas; row = 0
			"smallmouth_bass": atlas = controller.cedar_fish_atlas; row = 1
			"northern_pike": atlas = controller.cedar_fish_atlas; row = 2
		if atlas == null: return
		var source := Rect2(0, row * 512, 1024, 512)
		var scale := minf(destination.size.x / source.size.x, destination.size.y / source.size.y)
		var size := source.size * scale
		var contained := Rect2(destination.position + (destination.size - size) * 0.5, size)
		draw_texture_rect_region(atlas, contained, source, modulate)
	func _draw_fish_catch_flick(fish_id: String, destination: Rect2, tail_offset: float) -> void:
		var row := 0
		var atlas: Texture2D = controller.pine_fish_atlas
		match fish_id:
			"largemouth_bass": row = 1
			"channel_catfish": row = 2
			"rainbow_trout": atlas = controller.cedar_fish_atlas; row = 0
			"smallmouth_bass": atlas = controller.cedar_fish_atlas; row = 1
			"northern_pike": atlas = controller.cedar_fish_atlas; row = 2
		if atlas == null: return
		var source := Rect2(0, row * 512, 1024, 512)
		var scale := minf(destination.size.x / source.size.x, destination.size.y / source.size.y)
		var size := source.size * scale
		var contained := Rect2(destination.position + (destination.size - size) * 0.5, size)
		# Continuous textured quad mesh: shared edge vertices prevent duplicated alpha
		# while displacement rises smoothly only after u=.72 (head/body stay pinned).
		var columns := [0.0, 0.25, 0.50, 0.72, 1.0]
		var atlas_size := atlas.get_size()
		for index in range(columns.size() - 1):
			var u0: float = columns[index]
			var u1: float = columns[index + 1]
			var bend0 := tail_offset * clampf((u0 - 0.72) / 0.28, 0.0, 1.0)
			var bend1 := tail_offset * clampf((u1 - 0.72) / 0.28, 0.0, 1.0)
			var points := PackedVector2Array([contained.position + Vector2(contained.size.x * u0, bend0), contained.position + Vector2(contained.size.x * u1, bend1), contained.position + Vector2(contained.size.x * u1, contained.size.y + bend1), contained.position + Vector2(contained.size.x * u0, contained.size.y + bend0)])
			var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
			var uvs := PackedVector2Array([Vector2((source.position.x + source.size.x * u0) / atlas_size.x, source.position.y / atlas_size.y), Vector2((source.position.x + source.size.x * u1) / atlas_size.x, source.position.y / atlas_size.y), Vector2((source.position.x + source.size.x * u1) / atlas_size.x, (source.position.y + source.size.y) / atlas_size.y), Vector2((source.position.x + source.size.x * u0) / atlas_size.x, (source.position.y + source.size.y) / atlas_size.y)])
			draw_polygon(points, colors, uvs, atlas)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if controller.accepts_primary_press(true, bool(event.pressed), event.index == 0, event.device): _handle_press(event.position * Vector2(720.0 / size.x, 1280.0 / size.y))
		elif event is InputEventMouseButton:
			if controller.accepts_primary_press(false, bool(event.pressed), event.button_index == MOUSE_BUTTON_LEFT, event.device): _handle_press(event.position * Vector2(720.0 / size.x, 1280.0 / size.y))
	func _handle_press(pos: Vector2) -> void:
		_refresh_top_nav_geometry()
		_refresh_modal_layout()
		if overlay == "calibration" or overlay == "capture": return
		if overlay == "capture_saved":
			if motion_back_rect.has_point(pos): overlay = "motion_setup"
			return
		if overlay == "records":
			var page := _journal_page_rect(_virtual_safe_top())
			# Draw refresh owns the same transformed slot geometry, but refresh here too
			# so an immediate tap after resize never drifts from artwork.
			var canonical_slots := [Rect2(64, 225, 284, 254), Rect2(372, 225, 284, 254), Rect2(64, 503, 284, 256), Rect2(372, 503, 284, 256), Rect2(64, 786, 284, 250), Rect2(372, 786, 284, 250)]
			back_to_fishing_rect = _journal_map_rect(Rect2(420, 1164, 246, 58), page)
			records_world_rect = Rect2(26, _virtual_safe_top() + 18, 196, 58)
			if back_to_fishing_rect.has_point(pos): controller._close_overlay(); return
			if records_world_rect.has_point(pos):
				overlay = "world_records"
				if controller.leaderboards != null and not controller.capture_mode: controller.leaderboards.open_records()
				return
			for index in range(canonical_slots.size()):
				journal_slot_rects[index] = _journal_map_rect(canonical_slots[index], page)
				if journal_slot_rects[index].has_point(pos): journal_fish_id = ["bluegill", "largemouth_bass", "channel_catfish", "rainbow_trout", "smallmouth_bass", "northern_pike"][index]; journal_history_offset = 0; overlay = "journal_detail"; return
			return
		if overlay == "journal_detail":
			var detail_page := _journal_page_rect(_virtual_safe_top())
			journal_detail_back_rect = _journal_map_rect(Rect2(54, 1120, 280, 72), detail_page); journal_detail_next_rect = _journal_map_rect(Rect2(386, 1120, 280, 72), detail_page)
			if journal_detail_back_rect.has_point(pos): overlay = "records"
			elif journal_detail_next_rect.has_point(pos):
				var history: Array[Dictionary] = controller.save.history_for_fish(journal_fish_id)
				if history.size() > journal_history_offset + 4: journal_history_offset += 4
			return
		if overlay == "world_records":
			_refresh_modal_layout()
			world_retry_rect = Rect2(86, modal_panel_rect.position.y + 710, 260, 70)
			world_back_rect = modal_footer_rect
			world_period_rect = Rect2(374, modal_panel_rect.position.y + 710, 260, 70)
			if world_back_rect.has_point(pos): overlay = "records"
			elif world_period_rect.has_point(pos):
				if controller.leaderboards != null: controller.leaderboards.set_period("WEEKLY" if controller.leaderboards.period == "ALL TIME" else "ALL TIME")
			elif world_retry_rect.has_point(pos):
				if controller.leaderboards != null:
					if controller.leaderboards.status == "NO_AUTH": controller.leaderboards.begin_sign_in()
				else: controller.leaderboards.open_records()
			return
		if overlay in ["locations", "diagnostics"]:
			if overlay == "locations":
				var location_safe_top := _virtual_safe_top()
				_refresh_back_to_fishing_rect(location_safe_top); _refresh_location_card_rects(location_safe_top)
				if back_to_fishing_rect.has_point(pos): controller._close_overlay()
				elif controller._can_open_records() and location_pine_rect.has_point(pos): controller._select_location("pine_lake")
				elif controller._can_open_records() and location_cedar_rect.has_point(pos): controller._select_location("cedar_river")
			elif overlay == "diagnostics" and motion_back_rect.has_point(pos): overlay = "motion_setup"
			return
		if overlay == "settings":
			if settings_footer_close_rect.has_point(pos): controller._close_overlay()
			elif settings_haptics_rect.has_point(pos): controller._toggle_setting("haptics")
			elif settings_reduced_motion_rect.has_point(pos): controller._toggle_setting("reduced_motion")
			elif settings_handedness_rect.has_point(pos): controller._toggle_setting("left_handed")
			elif settings_test_haptics_rect.has_point(pos): controller._test_haptics()
			elif settings_motion_setup_rect.has_point(pos): controller.preview_haptics.stop(); overlay = "motion_setup"
			return
		if overlay == "motion_setup":
			if motion_back_rect.has_point(pos): overlay = "settings"
			elif motion_sensitivity_rect.has_point(pos): controller._toggle_setting("sensitivity")
			elif motion_recalibrate_rect.has_point(pos): controller._start_motion_recalibration()
			elif motion_capture_rect.has_point(pos): controller._start_cast_capture()
			elif motion_diagnostics_rect.has_point(pos): controller.preview_haptics.stop(); overlay = "diagnostics"
			return
		if settings_rect.has_point(pos): controller._open_settings(); return
		if controller.session.state == FishingSession.State.CAUGHT:
			if catch_continue_rect.has_point(pos): controller._reset_session(); return
			if catch_records_rect.has_point(pos): overlay = "records"; return
			return
		if records_rect.has_point(pos) and controller._can_open_records(): overlay = "records"; return
		if records_rect.has_point(pos) or locations_rect.has_point(pos):
			if not controller._can_open_records(): controller.ui_notice = "FINISH THIS CAST"; controller.ui_notice_remaining = 1.8
			elif records_rect.has_point(pos): overlay = "records"
			else: overlay = "locations"
			return
		if controller.session.state == FishingSession.State.ESCAPED: controller._reset_session()
	func _control_style(name: String) -> StyleBoxTexture:
		var skin := StyleBoxTexture.new()
		var region: Rect2 = CONTROL_REGIONS.get(name, CONTROL_REGIONS["plaque_disabled"])
		if controller.control_kit_texture:
			var atlas := AtlasTexture.new(); atlas.atlas = controller.control_kit_texture; atlas.region = region; atlas.filter_clip = true
			skin.texture = atlas
			skin.texture_margin_left = 22.0; skin.texture_margin_top = 22.0; skin.texture_margin_right = 22.0; skin.texture_margin_bottom = 22.0
			skin.draw_center = true
		return skin
	func _draw_control_region(name: String, destination: Rect2) -> void:
		if controller.control_kit_texture == null: return
		var region: Rect2 = CONTROL_REGIONS.get(name, CONTROL_REGIONS["plaque_disabled"])
		draw_texture_rect_region(controller.control_kit_texture, destination, region)
	func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new(); box.bg_color = background; box.border_color = border; box.set_border_width_all(3); box.set_corner_radius_all(20); return box
	func _text(value: String, pos: Vector2, font_size: int, color: Color) -> void: draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	func _centered_text(value: String, center: Vector2, font_size: int, color: Color) -> void:
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_text(value, Vector2(center.x - width * 0.5, center.y), font_size, color)
