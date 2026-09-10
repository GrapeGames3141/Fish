extends Node

const FishingSession = preload("res://src/domain/fishing_session.gd")
const FightChallenge = preload("res://src/domain/fight_challenge.gd")
const MotionService = preload("res://src/services/motion_service.gd")
const SaveService = preload("res://src/services/save_service.gd")
const AdMobService = preload("res://src/services/admob_service.gd")
const HapticService = preload("res://src/services/haptic_service.gd")
const CastCaptureService = preload("res://src/services/cast_capture_service.gd")
const FishDefinition = preload("res://src/domain/fish_definition.gd")
const LocationDefinition = preload("res://src/domain/location_definition.gd")
const LeaderboardService = preload("res://src/services/leaderboard_service.gd")
const PlayGamesConfig = preload("res://addons/play_games/play_games_config.gd")
const WaterSurface = preload("res://src/ui/water_surface.gd")

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
var water_surface: WaterSurface
var capture_path := ""
var capture_scenario := "ready"
var capture_time_override := -1.0
var capture_frames := 0
var capture_fps := 16.0
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

var pine_lake_texture: Texture2D = load("res://art/ui_v1/runtime_source/pine-lake-photoreal-v03.png")
var cedar_river_texture: Texture2D = load("res://art/ui_v1/runtime_source/cedar-river-michigan-v01.png")
var willow_pond_texture: Texture2D = load("res://art/ui_v1/runtime_source/willow-pond-photo-v01.png")
var hatteras_inlet_texture: Texture2D = load("res://art/ui_v1/runtime_source/hatteras-inlet-photo-v01.png")
var pine_fish_atlas: Texture2D = load("res://art/ui_v1/runtime_source/pine-fish-atlas-v02.png")
var cedar_fish_atlas: Texture2D = load("res://art/ui_v1/runtime_source/cedar-fish-atlas-v02.png")
var willow_fish_atlas: Texture2D = load("res://art/ui_v1/runtime_source/willow-fish-atlas-v01.png")
var ocean_fish_atlas: Texture2D = load("res://art/ui_v1/runtime_source/ocean-fish-atlas-v01.png")
var photoreal_rod_texture: Texture2D = load("res://art/ui_v1/runtime_source/rod-photoreal-alpha-v01.png")
var bobber_texture: Texture2D = load("res://art/ui_v1/runtime_source/bobber-photoreal-alpha-v01.png")
var splash_texture: Texture2D = load("res://art/ui_v1/runtime_source/cedar-river-michigan-v01.png")
var records_texture: Texture2D = preload("res://art/ui_v1/runtime_source/records-screen-rustic-v01.png")
var top_nav_texture: Texture2D = load("res://art/ui_v1/runtime_source/top-nav-rustic-v01.png")
var rustic_settings_texture: Texture2D = load("res://art/ui_v1/runtime_source/rustic-clipboard-blank-v01.png")
var rustic_waters_texture: Texture2D = load("res://art/ui_v1/runtime_source/waters-rustic-v01.png")

func _ready() -> void:
	session = FishingSession.new(); motion = MotionService.new(); save = SaveService.new(); ads = AdMobService.new(); haptics = HapticService.new(); preview_haptics = HapticService.new(); cast_capture = CastCaptureService.new(CastCaptureService.PATH, Callable(motion, "sample"))
	save.load_data(); motion.sensitivity = float(save.data.settings.get("sensitivity", 1.0)); motion.left_handed = bool(save.data.settings.get("left_handed", false)); session.set_next_cast_challenge(save.data.settings.get("fight_challenge", FightChallenge.DEFAULT_ID)); session.set_location(str(save.data.get("selected_location_id", "willow_pond")), 0.0)
	if not motion.set_profile(save.data.get("motion_profile", {})): motion.begin_calibration()
	ads.initialize(); haptics.set_enabled(bool(save.data.settings.get("haptics", true)))
	water_surface = WaterSurface.new(); water_surface.controller = self; add_child(water_surface)
	view = FishingView.new(); view.controller = self; add_child(view)
	_parse_capture_args()
	# Capture fixtures must never even initialize the optional native service.
	leaderboards = LeaderboardService.new(null, PlayGamesConfig.as_dictionary(), capture_path != "")
	if capture_path != "":
		capture_mode = true
		# Capture fixtures must never inherit or mutate the player's actual progress.
		save.data = SaveService.default_data()
		session.set_location("pine_lake", 0.0)
		_apply_capture_scenario()
		if capture_time_override >= 0.0: ui_time = capture_time_override
		loading_active = capture_scenario == "loading"; capture_freeze = capture_scenario != "loading"; call_deferred("_capture_after_draw")
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
		if not haptics.fighting: haptics.start_fight(session.fish, session.challenge_profile)
		var fight_size_factor := 1.0 + (inverse_lerp(session.fish.min_length_cm, session.fish.max_length_cm, session.catch_length_cm) * 0.10 if session.catch_length_cm > 0.0 else 0.0)
		var felt_effort := session.fight_effort + (0.16 if session.fight_stage == FishingSession.FightStage.LAST_SURGE else (0.08 if session.fight_stage == FishingSession.FightStage.OPENING_RUN else 0.0))
		haptics.update_fight(delta, session.fish, session.tension, felt_effort, fight_size_factor, session.challenge_profile)
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
	session.set_next_cast_challenge(save.data.settings.get("fight_challenge", FightChallenge.DEFAULT_ID))
	session.set_encounter_rolls(randf(), randf(), randf(), randf(), randf())
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
		motion.begin_fight(); haptics.cue("hook"); haptics.start_fight(session.fish, session.challenge_profile); print("MOTION_HOOK state=REELING projection=%.2f alignment=%.2f gyro=%.2f sweep_samples=%d" % [float(motion_event.get("hook_projection", 0.0)), float(motion_event.get("hook_alignment", 0.0)), float(motion_event.get("hook_gyro", 0.0)), int(motion_event.get("hook_sweep_samples", 0))])
func _record_catch_once() -> void:
	if caught_recorded or capture_mode or session.state != FishingSession.State.CAUGHT: return
	var formerly_unlocked: Array = save.data.get("unlocked_location_ids", []).duplicate()
	save.record_catch(session.fish.id, session.catch_length_cm, {"location_id": session.location_id, "fight_seconds": session.fight_elapsed, "cast_distance_m": session.cast_distance_m}); caught_recorded = true
	for location in LocationDefinition.all():
		if str(location.get("id", "")) != "willow_pond" and location.get("id", "") not in formerly_unlocked and is_location_unlocked(str(location.get("id", ""))):
			ui_notice = "%s UNLOCKED" % str(location.get("title", "")).to_upper(); ui_notice_remaining = 3.0
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
static func presentation_bobber_y(distance_m: float, fight_progress: float, is_reeling: bool, landing_blend: float, location_id := "pine_lake") -> float:
	var distance_fraction := inverse_lerp(FishingSession.MIN_CAST_DISTANCE_M, FishingSession.MAX_CAST_DISTANCE_M, distance_m)
	var near_y := 780.0
	var far_y := 410.0
	if location_id == "willow_pond": near_y = 820.0; far_y = 570.0
	var landed_y := lerpf(near_y, far_y, distance_fraction)
	if is_reeling: return lerpf(landed_y, 860.0, clampf(fight_progress, 0.0, 1.0))
	return lerpf(near_y + 6.0, landed_y, clampf(landing_blend, 0.0, 1.0))
static func presentation_bobber_position(distance_m: float, fight_progress: float, is_reeling: bool, landing_blend: float, location_id := "pine_lake") -> Vector2:
	var distance_fraction := inverse_lerp(FishingSession.MIN_CAST_DISTANCE_M, FishingSession.MAX_CAST_DISTANCE_M, distance_m)
	# Cast speed selects a reachable water band, not a touch-aim cursor. The small
	# lateral drift makes reeds / seam / deep-run landings visibly distinct.
	return Vector2(lerpf(446.0, 528.0, distance_fraction), presentation_bobber_y(distance_m, fight_progress, is_reeling, landing_blend, location_id))
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
	elif key == "fight_challenge":
		var current := FightChallenge.sanitize(save.data.settings.get("fight_challenge", FightChallenge.DEFAULT_ID))
		var next_index := (FightChallenge.IDS.find(current) + 1) % FightChallenge.IDS.size()
		save.data.settings.fight_challenge = FightChallenge.IDS[next_index]
		ui_notice = "FIGHT %s — NEXT CAST" % FightChallenge.display_name(save.data.settings.fight_challenge); ui_notice_remaining = 2.5
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
func location_texture(location_id: String) -> Texture2D:
	match location_id:
		"willow_pond": return willow_pond_texture
		"cedar_river": return cedar_river_texture
		"hatteras_inlet": return hatteras_inlet_texture
	return pine_lake_texture
func is_location_unlocked(location_id: String) -> bool:
	return not LocationDefinition.by_id(location_id).is_empty() and location_id in save.data.get("unlocked_location_ids", [])
func missing_location_fish(location_id: String) -> Array[String]:
	return SaveService.missing_species_for_location(save.data, location_id)
func _select_location(location: String) -> void:
	if not _can_open_records(): return
	if LocationDefinition.by_id(location).is_empty(): return
	if not is_location_unlocked(location):
		var missing_names: Array[String] = []
		for fish_id in missing_location_fish(location): missing_names.append(_fish_name(fish_id))
		ui_notice = "LAND %s" % ", ".join(missing_names)
		ui_notice_remaining = 2.6
		return
	if session.state in [FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]: _reset_session()
	if session.set_location(location, 0.0): save.data.selected_location_id = location; save.save_data(); view.overlay = ""
func _fish_name(fish_id: String) -> String:
	for fish in FishDefinition.all_planned():
		if fish.id == fish_id: return fish.display_name
	return fish_id.replace("_", " ").capitalize()
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
	if view != null: view.reset_waters_pointer()
	haptics.stop(); preview_haptics.stop(); motion.reset_gesture(); menu_motion_settle_remaining = preserved_guard; view.overlay = ""
func _test_haptics() -> void:
	preview_haptics.stop(); preview_haptics.set_enabled(bool(save.data.settings.get("haptics", true))); preview_haptics.cue("bite")
func _parse_capture_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-scenario="): capture_scenario = arg.trim_prefix("--capture-scenario=")
		elif arg.begins_with("--capture-time="): capture_time_override = maxf(0.0, arg.trim_prefix("--capture-time=").to_float())
		elif arg.begins_with("--capture-frames="): capture_frames = clampi(arg.trim_prefix("--capture-frames=").to_int(), 0, 120)
		elif arg.begins_with("--capture-fps="): capture_fps = clampf(arg.trim_prefix("--capture-fps=").to_float(), 1.0, 30.0)
func _apply_capture_scenario() -> void:
	view.overlay = ""
	match capture_scenario:
		"loading": pass
		"willow_ready": session.set_location("willow_pond", 0.0)
		"willow_line_out": session.set_location("willow_pond", 0.0); session.arm_cast(); session.release_cast(0.8); session.elapsed = maxf(0.0, session.bite_wait_seconds - 0.35)
		"shadow_pass": session.set_location("willow_pond", 0.0); session.set_encounter_rolls(0.2, 0.4, 0.4, 0.80, 0.30); session.arm_cast(); session.release_cast(0.8); session.elapsed = session.shadow_visit_start + session.shadow_visit_duration * 0.50
		"wait_after_shadow": session.set_location("willow_pond", 0.0); session.set_encounter_rolls(0.2, 0.4, 0.4, 0.80, 0.30); session.arm_cast(); session.release_cast(0.8); session.elapsed = minf(session.bite_wait_seconds - 0.40, session.shadow_visit_start + session.shadow_visit_duration + 0.35)
		"willow_reeling_danger": session.set_location("willow_pond", 0.0); session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.95; session.rod_load = 0.95; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"hatteras_ready": session.set_location("hatteras_inlet", 0.0)
		"hatteras_bite": session.set_location("hatteras_inlet", 0.0); session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.BITE; session.bite_elapsed = 0.20
		"hatteras_reeling_high": session.set_location("hatteras_inlet", 0.0); session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.88; session.rod_load = 0.88; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"pine_ready": session.set_location("pine_lake", 0.0)
		"cedar_ready": session.set_location("cedar_river", 0.0)
		"cedar_ready_safe_top_180": session.set_location("cedar_river", 0.0); view.safe_top_override = 180.0
		"cast_armed": session.arm_cast()
		"line_out": session.arm_cast(); session.release_cast(0.8)
		"hatteras_line_out": session.set_location("hatteras_inlet", 0.0); session.arm_cast(); session.release_cast(0.8)
		"hatteras_short_line_out": session.set_location("hatteras_inlet", 0.0); session.arm_cast(); session.release_cast(0.35)
		"hatteras_reduced_line_out": save.data.settings.reduced_motion = true; session.set_location("hatteras_inlet", 0.0); session.arm_cast(); session.release_cast(0.8)
		"willow_line_out_t2": session.set_location("willow_pond", 0.0); session.arm_cast(); session.release_cast(0.8); ui_time = 2.0
		"hatteras_line_out_t2": session.set_location("hatteras_inlet", 0.0); session.arm_cast(); session.release_cast(0.8); ui_time = 2.0
		"cedar_line_out": session.set_location("cedar_river", 0.0); session.arm_cast(); session.release_cast(0.8)
		"cedar_line_out_safe_top_180": session.set_location("cedar_river", 0.0); session.arm_cast(); session.release_cast(0.8); view.safe_top_override = 180.0
		"cedar_line_out_far": session.set_location("cedar_river", 0.0); session.arm_cast(); session.release_cast(1.0)
		"bite": session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.BITE; session.bite_elapsed = 0.20
		"hook_window": session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.HOOK_WINDOW; session.bite_elapsed = 0.20
		"reeling", "reeling_low": session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.32; session.rod_load = 0.38; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"fight_slack": session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.06; session.rod_load = 0.04; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"fight_center": session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.50; session.rod_load = 0.52; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"fight_center_relaxed": session.set_next_cast_challenge("relaxed"); session.challenge_id = "relaxed"; session.challenge_profile = FightChallenge.profile("relaxed"); session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.50; session.rod_load = 0.52; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"fight_center_expert": session.set_next_cast_challenge("expert"); session.challenge_id = "expert"; session.challenge_profile = FightChallenge.profile("expert"); session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.50; session.rod_load = 0.52; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"reeling_high": session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.88; session.rod_load = 0.88; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"reeling_danger": session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.95; session.rod_load = 0.95; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"cedar_reeling_high_safe180": session.set_location("cedar_river", 0.0); session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.88; session.rod_load = 0.88; session.cast_quality = 0.86; session.cast_distance_m = 35.5; view.safe_top_override = 180.0
		"caught", "catch_first": session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 24.0; session.last_reason = "Bluegill landed!"; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true; _set_capture_catch_record(0, 0.0)
		"catch_new_best": session.set_location("pine_lake", 0.60); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 44.4; session.cast_distance_m = 32.0; caught_recorded = true; _set_capture_catch_record(2, 41.2)
		"catch_tie": session.set_location("cedar_river", 0.0); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 42.0; session.cast_distance_m = 32.0; caught_recorded = true; _set_capture_catch_record(4, 42.0)
		"catch_long_species": session.set_location("pine_lake", 0.90); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 61.4; session.cast_distance_m = 37.0; caught_recorded = true; _set_capture_catch_record(3, 59.8)
		"pine_bass_catch": session.set_location("pine_lake", 0.60); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 48.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"pine_catfish_catch": session.set_location("pine_lake", 0.90); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 61.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"cedar_trout_catch": session.set_location("cedar_river", 0.0); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 42.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"cedar_smallmouth_catch": session.set_location("cedar_river", 0.65); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 45.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"cedar_catch": session.set_location("cedar_river", 0.97); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 89.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"willow_pumpkinseed_catch": _capture_named_catch("willow_pond", "pumpkinseed", 20.8)
		"willow_crappie_catch": _capture_named_catch("willow_pond", "black_crappie", 29.4)
		"willow_bullhead_catch": _capture_named_catch("willow_pond", "brown_bullhead", 34.2)
		"hatteras_reddrum_catch": _capture_named_catch("hatteras_inlet", "red_drum", 61.6)
		"hatteras_seatrout_catch": _capture_named_catch("hatteras_inlet", "spotted_seatrout", 47.2)
		"hatteras_bluefish_catch": _capture_named_catch("hatteras_inlet", "bluefish", 55.8)
		"records": _seed_capture_records(); view.overlay = "records"
		"records_page2": _seed_capture_records_mixed(); view.journal_page_index = 1; view.overlay = "records"
		"records_page2_full_safe180": _seed_capture_records(); view.journal_page_index = 1; view.safe_top_override = 180.0; view.overlay = "records"
		"records_mixed": _seed_capture_records_mixed(); view.overlay = "records"
		"records_empty": _clear_capture_records(); view.overlay = "records"
		"records_page2_empty": _clear_capture_records(); view.journal_page_index = 1; view.overlay = "records"
		"records_safe_top": _seed_capture_records(); view.safe_top_override = 91.0; view.overlay = "records"
		"records_safe_top_180": _seed_capture_records(); view.safe_top_override = 180.0; view.overlay = "records"
		"records_detail": _seed_capture_records(); save.data.best_cm.northern_pike = 88.6; view.journal_fish_id = "northern_pike"; save.data.catch_history = [{"fish_id": "northern_pike", "length_cm": 72.1, "location_id": "cedar_river", "timestamp_utc": 1699900000, "fight_seconds": 18.2, "cast_distance_m": 31.0}, {"fish_id": "northern_pike", "length_cm": 88.6, "location_id": "cedar_river", "timestamp_utc": 1700000000, "fight_seconds": 16.4, "cast_distance_m": 34.0}]; view.overlay = "journal_detail"
		"records_detail_safe_top_180": _seed_capture_records(); save.data.best_cm.northern_pike = 88.6; view.journal_fish_id = "northern_pike"; save.data.catch_history = [{"fish_id": "northern_pike", "length_cm": 72.1, "location_id": "cedar_river", "timestamp_utc": 1699900000, "fight_seconds": 18.2, "cast_distance_m": 31.0}, {"fish_id": "northern_pike", "length_cm": 88.6, "location_id": "cedar_river", "timestamp_utc": 1700000000, "fight_seconds": 16.4, "cast_distance_m": 34.0}]; view.safe_top_override = 180.0; view.overlay = "journal_detail"
		"field_notes": _seed_capture_records(); save.data.best_cm.northern_pike = 88.6; view.journal_fish_id = "northern_pike"; save.data.catch_history = [{"fish_id": "northern_pike", "length_cm": 72.1, "location_id": "cedar_river", "timestamp_utc": 1699900000, "fight_seconds": 18.2, "cast_distance_m": 31.0}, {"fish_id": "northern_pike", "length_cm": 88.6, "location_id": "cedar_river", "timestamp_utc": 1700000000, "fight_seconds": 16.4, "cast_distance_m": 34.0}]; view.overlay = "journal_detail"
		"field_notes_reddrum_safe180": _seed_capture_records(); save.data.best_cm.red_drum = 61.6; view.journal_fish_id = "red_drum"; save.data.catch_history = [{"fish_id": "red_drum", "length_cm": 61.6, "location_id": "hatteras_inlet", "timestamp_utc": 1700000000, "fight_seconds": 18.4, "cast_distance_m": 36.0}]; view.safe_top_override = 180.0; view.overlay = "journal_detail"
		"world_offline": _seed_capture_records(); view.overlay = "world_records"
		"world_page2": _seed_capture_records(); view.world_page_index = 1; view.overlay = "world_records"
		"catch_safe_top_180": view.safe_top_override = 180.0; session.set_location("cedar_river", 0.97); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 89.0; session.cast_distance_m = 36.2; caught_recorded = true
		"catch_recast_ready": session.set_location("cedar_river", 0.97); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 89.0; session.cast_distance_m = 36.2; session.terminal_elapsed = FishingSession.TERMINAL_RECAST_DWELL_SECONDS; session.terminal_still_elapsed = FishingSession.TERMINAL_STILL_SECONDS; caught_recorded = true
		"catch_tail_mid": session.set_location("cedar_river", 0.97); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 89.0; session.cast_distance_m = 36.2; session.terminal_elapsed = 0.32; ui_time = 0.16; caught_recorded = true
		"settings": view.overlay = "settings"
		"settings_expert": save.data.settings.fight_challenge = "expert"; view.overlay = "settings"
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
		"waters_locked_top": session.set_location("willow_pond", 0.0); save.data.selected_location_id = "willow_pond"; view.overlay = "locations"
		"waters_locked_bottom": session.set_location("willow_pond", 0.0); save.data.selected_location_id = "willow_pond"; view.overlay = "locations"; view.waters_scroll = 9999.0
		"waters_unlocked_bottom": _seed_capture_records(); save.data.unlocked_location_ids = ["willow_pond", "pine_lake", "cedar_river", "hatteras_inlet"]; session.set_location("hatteras_inlet", 0.0); save.data.selected_location_id = "hatteras_inlet"; view.overlay = "locations"; view.waters_scroll = 9999.0
		"waters_locked_safe180": view.safe_top_override = 180.0; session.set_location("willow_pond", 0.0); save.data.selected_location_id = "willow_pond"; view.overlay = "locations"
		"waters_locked_bottom_safe180": view.safe_top_override = 180.0; session.set_location("willow_pond", 0.0); save.data.selected_location_id = "willow_pond"; view.overlay = "locations"; view.waters_scroll = 9999.0
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
func _capture_named_catch(location_id: String, fish_id: String, length_cm: float) -> void:
	session.set_location(location_id, 0.0)
	for fish in FishDefinition.all_planned():
		if fish.id == fish_id: session.fish = fish; break
	session.state = FishingSession.State.CAUGHT; session.catch_length_cm = length_cm; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
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
	if capture_frames > 0:
		DirAccess.make_dir_recursive_absolute(capture_path)
		var start_time := ui_time
		var clip_error := OK
		for frame in range(capture_frames):
			ui_time = start_time + float(frame) / capture_fps
			view.queue_redraw(); water_surface.queue_redraw()
			await get_tree().process_frame; await RenderingServer.frame_post_draw
			var frame_path := capture_path.path_join("frame-%03d.png" % frame)
			var frame_error := get_viewport().get_texture().get_image().save_png(frame_path)
			if frame_error != OK: clip_error = frame_error; break
		print("WATER_MOTION_CAPTURED directory=%s frames=%d fps=%.1f error=%s" % [capture_path, capture_frames, capture_fps, clip_error])
		get_tree().quit(0 if clip_error == OK else 1); return
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
	# The clean generated clipboard is cropped to the coherent board rather than
	# stretching its scenic full-frame master behind legacy modal geometry.
	const CLIPBOARD_BOARD_SOURCE := Rect2(50, 230, 840, 1208)
	const CLIPBOARD_HEADER_SOURCE := Rect2(203, 307, 524, 124)
	const CLIPBOARD_FOOTER_SOURCE := Rect2(174, 1314, 592, 106)
	const CLIPBOARD_INTERIOR_SOURCE := Rect2(104, 450, 727, 847)
	const CONTROL_REGIONS := {
		"plaque_normal": Rect2(20, 72, 332, 112), "plaque_pressed": Rect2(364, 72, 332, 112), "plaque_disabled": Rect2(692, 72, 312, 112),
		"row_normal": Rect2(42, 252, 446, 134), "row_selected": Rect2(532, 252, 446, 134), "card_normal": Rect2(82, 445, 196, 182),
		"modal": Rect2(24, 754, 512, 682), "teal_long": Rect2(556, 812, 438, 126)
	}
	var controller: Node
	var overlay := ""
	var synthetic_reserve := 0.0
	var safe_top_override := -1.0
	var top_nav_strip_rect := Rect2(358, 12, 338, 156)
	var records_rect := Rect2(358, 12, 112, 156)
	var locations_rect := Rect2(470, 12, 112, 156)
	var settings_rect := Rect2(582, 12, 114, 156)
	var back_to_fishing_rect := Rect2(420, 18, 264, 64)
	var location_pine_rect := Rect2()
	var location_cedar_rect := Rect2()
	var location_card_rects: Array[Rect2] = [Rect2(), Rect2(), Rect2(), Rect2()]
	var waters_viewport_rect := Rect2()
	var waters_scroll := 0.0
	var waters_drag_start := Vector2.ZERO
	var waters_drag_origin := 0.0
	var waters_dragging := false
	var waters_pointer_active := false
	var waters_press_location_id := ""
	var waters_secondary_touch_seen := false
	var modal_panel_rect := Rect2(55, 150, 610, 960)
	var modal_header_rect := Rect2(226, 178, 272, 102)
	var modal_footer_rect := Rect2(222, 992, 278, 104)
	var settings_haptics_rect := Rect2(98, 304, 524, 72)
	var settings_reduced_motion_rect := Rect2(98, 394, 524, 72)
	var settings_handedness_rect := Rect2(98, 484, 524, 72)
	var settings_challenge_rect := Rect2(98, 608, 524, 54)
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
	var journal_safe_top := 0.0
	var journal_fish_rects := [Rect2(), Rect2(), Rect2(), Rect2(), Rect2(), Rect2()]
	var journal_name_rects := [Rect2(), Rect2(), Rect2(), Rect2(), Rect2(), Rect2()]
	var journal_stats_rects := [Rect2(), Rect2(), Rect2(), Rect2(), Rect2(), Rect2()]
	var journal_detail_back_rect := Rect2(58, 1124, 270, 72)
	var journal_detail_next_rect := Rect2(392, 1124, 270, 72)
	var journal_detail_fish_rect := Rect2(120, 330, 480, 250)
	var journal_detail_title_rect := Rect2(90, 570, 540, 36)
	var journal_detail_stats_rect := Rect2(90, 606, 540, 30)
	var journal_detail_history_rect := Rect2(86, 654, 548, 158)
	var journal_detail_note_rect := Rect2(94, 826, 532, 48)
	var journal_fish_id := "bluegill"
	var journal_history_offset := 0
	var journal_page_index := 0
	var records_previous_rect := Rect2()
	var records_next_rect := Rect2()
	var records_world_rect := Rect2(28, 24, 190, 58)
	var world_back_rect := Rect2(92, 992, 250, 70)
	var world_period_rect := Rect2(374, 860, 260, 70)
	var world_retry_rect := Rect2(86, 860, 260, 70)
	var world_status_rect := Rect2(86, 360, 548, 80)
	var world_row_rects := [Rect2(), Rect2(), Rect2(), Rect2(), Rect2(), Rect2()]
	var world_page_index := 0
	var world_previous_rect := Rect2()
	var world_next_rect := Rect2()
	var tension_meter_rect := Rect2(30, 112, 540, 18)
	var font: Font
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		font = ThemeDB.fallback_font
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
		# The authored beam is a fixed safe-area rail in every normal fishing state.
		# Keeping the source and hit targets stable avoids the former short-plank /
		# floating-gear jump after a cast begins.
		top_nav_strip_rect = Rect2(0, chrome_y, 720, 108)
		# These are the physical engraved plaques after the 2172px wood beam maps to
		# the 720px presentation. Draw and hit routing deliberately share these bounds.
		records_rect = Rect2(398, chrome_y + 17, 85, 86)
		locations_rect = Rect2(496, chrome_y + 17, 87, 86)
		settings_rect = Rect2(594, chrome_y + 17, 86, 86)
	func _refresh_modal_layout() -> void:
		# Decorative source maps exactly once at its native portrait transform. Its
		# usable header/actions already begin below the maximum 180px safe inset;
		# moving or shrinking it introduced mismatched-photo seams and footer overlap.
		var scale := 720.0 / 941.0
		modal_panel_rect = Rect2(Vector2.ZERO, Vector2(720, 1280))
		modal_header_rect = _clipboard_map_rect(CLIPBOARD_HEADER_SOURCE)
		modal_footer_rect = _clipboard_map_rect(CLIPBOARD_FOOTER_SOURCE)
		var interior := _clipboard_map_rect(CLIPBOARD_INTERIOR_SOURCE)
		settings_haptics_rect = Rect2(interior.position.x + 20 * scale, interior.position.y + 44 * scale, interior.size.x - 40 * scale, 68 * scale)
		settings_reduced_motion_rect = Rect2(interior.position.x + 20 * scale, interior.position.y + 166 * scale, interior.size.x - 40 * scale, 68 * scale)
		settings_handedness_rect = Rect2(interior.position.x + 20 * scale, interior.position.y + 288 * scale, interior.size.x - 40 * scale, 68 * scale)
		settings_challenge_rect = Rect2(interior.position.x + 20 * scale, interior.position.y + 454 * scale, interior.size.x - 40 * scale, 68 * scale)
		settings_test_haptics_rect = Rect2(interior.position.x + 20 * scale, interior.position.y + 536 * scale, interior.size.x - 40 * scale, 68 * scale)
		settings_motion_setup_rect = Rect2(interior.position.x + 20 * scale, interior.position.y + 620 * scale, interior.size.x - 40 * scale, 68 * scale)
		settings_footer_close_rect = modal_footer_rect
		motion_sensitivity_rect = Rect2(interior.position.x + 20 * scale, interior.position.y + 44 * scale, interior.size.x - 40 * scale, 68 * scale)
		motion_recalibrate_rect = Rect2(interior.position.x + 20 * scale, interior.position.y + 166 * scale, interior.size.x - 40 * scale, 68 * scale)
		motion_capture_rect = Rect2(interior.position.x + 20 * scale, interior.position.y + 420 * scale, interior.size.x - 40 * scale, 68 * scale)
		motion_diagnostics_rect = Rect2(interior.position.x + 20 * scale, interior.position.y + 560 * scale, interior.size.x - 40 * scale, 68 * scale)
		motion_back_rect = modal_footer_rect
	func _clipboard_map_rect(source: Rect2) -> Rect2:
		var scale := modal_panel_rect.size.x / 941.0
		return Rect2(modal_panel_rect.position + source.position * scale, source.size * scale)
	func _draw_rustic_clipboard() -> void:
		if controller.rustic_settings_texture:
			# One full opaque source owns the ordinary screen; no scaled board is laid
			# over a second photo/clipboard (which created duplicate lower planks).
			draw_texture_rect(controller.rustic_settings_texture, modal_panel_rect, false)
		else: draw_style_box(_control_style("modal"), modal_panel_rect)
	func _draw_modal_panel() -> void:
		draw_style_box(_panel_style(Color("eee0bd"), Color("4c321b")), modal_panel_rect)
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
		_draw_wood_control(Rect2(130, 932, 460, 96)); _centered_text_in_rect("HOOKED", Rect2(130, 944, 460, 42), 32, Color("fff4cf")); _centered_text_in_rect("MOTION FISHING", Rect2(130, 985, 460, 28), 15, Color("fff4cf"))
	func _draw_world() -> void:
		var s: FishingSession = controller.session
		# Ordinary opaque screens retain only their natural scenery background. They
		# never reveal the prior rod, old top beam, or world HUD behind their panel.
		if overlay != "":
			var background: Texture2D = controller.location_texture(s.location_id)
			if background: draw_texture_rect(background, Rect2(0, 0, 720, 1280), false)
			else: draw_rect(Rect2(0, 0, 720, 1280), Color("1c617d"))
			if overlay == "calibration": _draw_calibration()
			elif overlay == "settings": _draw_settings()
			elif overlay == "records": _draw_records()
			elif overlay == "journal_detail": _draw_journal_detail()
			elif overlay == "world_records": _draw_world_records()
			elif overlay == "locations": _draw_locations()
			elif overlay == "motion_setup": _draw_motion_setup()
			elif overlay == "diagnostics": _draw_diagnostics()
			elif overlay == "capture" or overlay == "capture_saved": _draw_cast_capture()
			return
		if s.state == FishingSession.State.CAUGHT:
			_draw_top_chrome(s); _draw_catch_reveal(s)
		else:
			_draw_lake_motion(s); _draw_top_chrome(s); _draw_glance_hint(s); _draw_fight_status(s)
			if s.state == FishingSession.State.ESCAPED: _draw_escape_card(s)
		if synthetic_reserve > 0.0: draw_rect(Rect2(0, 1280 - synthetic_reserve, 720, synthetic_reserve), Color("ff2f5f", 0.68)); _text("SYNTHETIC OVERLAY STRESS — NOT NATIVE AD", Vector2(66, 1248), 16, Color.WHITE)
	func _draw_lake_motion(s: FishingSession) -> void:
		var reduced := bool(controller.save.data.settings.get("reduced_motion", false))
		if s.state in [FishingSession.State.READY, FishingSession.State.CAST_ARMED]:
			# River ambience belongs to the water plate even before the line is out.
			_draw_river_life(s, Vector2(492, 650), reduced)
			# The rod art contains its own line until the terminal guide. Water stays clear
			# until a real cast has landed.
			_draw_ready_photoreal_rod()
			return
		var landing_blend := 1.0 if reduced else clampf(controller.cast_visual_elapsed / 0.32, 0.0, 1.0)
		var base_bobber_pos: Vector2 = controller.presentation_bobber_position(s.cast_distance_m, s.fight_progress, s.state == FishingSession.State.REELING, landing_blend, s.location_id)
		var surface_sample: Dictionary = WaterSurface.sample(s.location_id, base_bobber_pos, controller.ui_time, reduced)
		var bobber_pos: Vector2 = base_bobber_pos + surface_sample.offset
		_draw_river_life(s, bobber_pos, reduced)
		var submerged := s.state in [FishingSession.State.BITE, FishingSession.State.HOOK_WINDOW, FishingSession.State.REELING]
		# Keep the external line attached to the stable water-surface contact. The
		# float itself vanishes beneath that contact during bite/fight; it does not
		# drag the visible line endpoint downward.
		var rod_bend := 0.0 if s.state != FishingSession.State.REELING else clampf(maxf(s.tension, s.rod_load), 0.0, 1.0)
		var rod_pose := 0.0 if s.state != FishingSession.State.REELING else clampf(s.rod_load * 0.75 + s.tension * 0.25, 0.0, 1.0)
		var rod_tip := _photoreal_rod_tip(rod_bend, rod_pose)
		var float_size := lerpf(30.0, 18.0, clampf(s.cast_distance_m / 42.0, 0.0, 1.0))
		var bobber_tilt: float = float(surface_sample.get("tilt", 0.0))
		# The visible source eyelet is near y=399 in the 369..857 body crop.
		var line_target := bobber_pos + Vector2(0, -float_size * 0.544).rotated(bobber_tilt)
		# Draw the external line behind the rod; the rod atlas owns handle-to-terminal-guide pixels.
		var mono := Color("e5eee8", 0.60)
		if submerged: draw_line(rod_tip, bobber_pos, mono, 1.1, true)
		else:
			var sag_depth := minf(14.0, 5.0 + s.cast_distance_m * 0.22)
			var curve := PackedVector2Array()
			for sample in range(9):
				var t := float(sample) / 8.0
				curve.append(rod_tip.lerp(line_target, t) + Vector2(0, sag_depth * 4.0 * t * (1.0 - t)))
			draw_polyline(curve, mono, 1.0, true)
		_draw_photoreal_rod(rod_bend, rod_pose)
		if not submerged and controller.bobber_texture:
			# The source canvas has generous transparent padding; map the known visible
			# body region so distance scaling measures the float rather than its canvas.
			# Split at the real source divider (y=660): upper cap stays dry; lower
			# hemisphere retains its own alpha while appearing refracted and dimmer.
			var upper_h := float_size * 1.24 * (291.0 / 488.0)
			var local_top := -float_size * .62
			var canvas_scale := Vector2(get_size().x / 720.0, get_size().y / 1280.0)
			draw_set_transform(bobber_pos * canvas_scale, bobber_tilt, canvas_scale)
			draw_texture_rect_region(controller.bobber_texture, Rect2(-float_size * .5, local_top, float_size, upper_h), Rect2(496, 369, 383, 291))
			draw_texture_rect_region(controller.bobber_texture, Rect2(-float_size * .5, local_top + upper_h, float_size, float_size * .36), Rect2(496, 660, 383, 197), Color(0.42, 0.68, 0.70, 0.62))
			draw_set_transform(Vector2.ZERO, 0.0, canvas_scale)
			var water_contact := bobber_pos + Vector2(0, local_top + upper_h).rotated(bobber_tilt)
			_draw_water_ripple(water_contact, float_size * 0.82, 0.28)
		if submerged:
			var pulse := 0.0 if reduced else fmod(controller.ui_time * (5.0 if s.state == FishingSession.State.REELING else 3.0), 1.0)
			for ring in range(3):
				_draw_water_ripple(bobber_pos + Vector2(0, 5), 14.0 + ring * 15.0 + pulse * 9.0, 0.48 - ring * 0.12)
		if s.state == FishingSession.State.REELING and not reduced:
			for droplet in range(3):
				var drift := fmod(controller.ui_time * 18.0 + droplet * 7.0, 18.0)
				draw_circle(bobber_pos + Vector2(-9 + droplet * 10, -4 - drift), 2.0, Color("e8fbf4", 0.54))
	func _draw_river_life(s: FishingSession, bobber_pos: Vector2, reduced: bool) -> void:
		# Code-native life sits only on water; the photographic plate remains the sole
		# owner of banks and rocks, avoiding a second static layer or alpha seams.
		if s.state != FishingSession.State.LINE_OUT: return
		if s.shadow_visit_start < 0.0: return
		var visit := clampf(inverse_lerp(s.shadow_visit_start, s.shadow_visit_start + s.shadow_visit_duration, s.elapsed), 0.0, 1.0)
		if visit <= 0.0 or visit >= 1.0: return
		# Wildlife approaches then leaves. Its timing is independent of the real bite,
		# so a fish shadow is atmosphere rather than a guaranteed strike warning.
		var travel := sin(visit * PI)
		var start := bobber_pos + Vector2(-138.0, 74.0)
		var end := bobber_pos + Vector2(116.0, 46.0)
		var shadow := start.lerp(end, visit) + Vector2(0, -travel * 18.0)
		var body_w := lerpf(30.0, 52.0, travel)
		var body_h := body_w * 0.32
		# Tapered body and tail are drawn in canonical screen coordinates, preserving
		# the parent viewport scale at non-720 captures without a transform reset.
		var silhouette := PackedVector2Array([shadow + Vector2(-body_w * 0.5, 0), shadow + Vector2(-body_w * 0.18, -body_h), shadow + Vector2(body_w * 0.34, -body_h * 0.62), shadow + Vector2(body_w * 0.50, 0), shadow + Vector2(body_w * 0.34, body_h * 0.62), shadow + Vector2(-body_w * 0.18, body_h), shadow + Vector2(-body_w * 0.58, body_h * 0.52), shadow + Vector2(-body_w * 0.76, 0), shadow + Vector2(-body_w * 0.58, -body_h * 0.52)])
		draw_colored_polygon(silhouette, Color(0.015, 0.10, 0.11, travel * 0.48))
	func _draw_water_ripple(center: Vector2, radius: float, alpha: float) -> void:
		var points := PackedVector2Array()
		for point in range(25):
			var angle := TAU * float(point) / 24.0
			points.append(center + Vector2(cos(angle) * radius * 1.45, sin(angle) * radius * 0.34))
		draw_polyline(points, Color("7da4a5", alpha), 1.25, true)
	func _rod_tip_for_frame(frame: int) -> Vector2:
		var source_tip: Vector2 = ROD_TIP_ANCHORS[clampi(frame, 0, ROD_TIP_ANCHORS.size() - 1)]
		return ROD_DESTINATION.position + Vector2(
			source_tip.x / ROD_FRAME_SIZE.x * ROD_DESTINATION.size.x,
			source_tip.y / ROD_FRAME_SIZE.y * ROD_DESTINATION.size.y
		)
	func _photoreal_rod_point(source_point: Vector2, bend := 0.0, pose := 0.0) -> Vector2:
		var normalized := Vector2(source_point.x / PHOTOREAL_ROD_SOURCE_SIZE.x, source_point.y / PHOTOREAL_ROD_SOURCE_SIZE.y)
		var point := PHOTOREAL_ROD_DESTINATION.position + normalized * PHOTOREAL_ROD_DESTINATION.size
		# The grip at the bottom stays planted. Pulling back lifts/sets the entire
		# upper shaft before its terminal guide visibly bends under load.
		var upper := pow(1.0 - normalized.y, 1.45)
		var bend_strength := pow(1.0 - normalized.y, 2.2) * bend
		return point + Vector2(-68.0 * upper * pose - 42.0 * bend_strength, -54.0 * upper * pose + 25.0 * bend_strength)
	func _photoreal_rod_tip(bend := 0.0, pose := 0.0) -> Vector2:
		return _photoreal_rod_point(PHOTOREAL_ROD_TIP_SOURCE, bend, pose)
	func _draw_ready_photoreal_rod() -> void:
		_draw_photoreal_rod(0.0)
	func _draw_photoreal_rod(bend: float, pose := 0.0) -> void:
		if controller.photoreal_rod_texture == null: return
		# A single textured mesh preserves the hand/reel and gradually bends only the
		# upper shaft. The same deformation supplies the runtime mono's terminal tip.
		var bands := PackedFloat32Array([0.0, 0.12, 0.30, 0.58, 1.0])
		for index in range(bands.size() - 1):
			var v0: float = bands[index]
			var v1: float = bands[index + 1]
			var source_y0 := PHOTOREAL_ROD_SOURCE_SIZE.y * v0
			var source_y1 := PHOTOREAL_ROD_SOURCE_SIZE.y * v1
			var points := PackedVector2Array([_photoreal_rod_point(Vector2(0, source_y0), bend, pose), _photoreal_rod_point(Vector2(PHOTOREAL_ROD_SOURCE_SIZE.x, source_y0), bend, pose), _photoreal_rod_point(Vector2(PHOTOREAL_ROD_SOURCE_SIZE.x, source_y1), bend, pose), _photoreal_rod_point(Vector2(0, source_y1), bend, pose)])
			var uvs := PackedVector2Array([Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)])
			draw_polygon(points, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, controller.photoreal_rod_texture)
	func _draw_top_chrome(s: FishingSession) -> void:
		var chrome_y := _virtual_safe_top()
		var active := s.state in [FishingSession.State.CAST_ARMED, FishingSession.State.LINE_OUT, FishingSession.State.BITE, FishingSession.State.HOOK_WINDOW, FishingSession.State.REELING]
		_refresh_top_nav_geometry()
		if controller.top_nav_texture: draw_texture_rect_region(controller.top_nav_texture, top_nav_strip_rect, Rect2(0, 172, 2172, 323))
		# The location uses the actual clear left beam, not the old bolt-overlapping x=42 baseline.
		_centered_text(s.location_id.replace("_", " ").to_upper(), Vector2(214, chrome_y + 29), 15, Color("332016"))
		if active:
			# Records and Waters stay in their engraved positions while a cast/fight is
			# active. Small native padlocks communicate the existing notice-only gate
			# without adding a translucent card or a redundant icon label.
			_draw_nav_lock(records_rect); _draw_nav_lock(locations_rect)
	func _draw_nav_lock(rect: Rect2) -> void:
		var body := Rect2(rect.end - Vector2(21, 20), Vector2(13, 10))
		var shackle_center := Vector2(body.get_center().x, body.position.y + 1)
		var lock_color := Color("3b2415")
		draw_rect(body, lock_color, true); draw_rect(body, Color("e3bb62"), false, 1.0)
		draw_arc(shackle_center, 4.5, PI, TAU, 10, lock_color, 2.0, true)
	func _draw_glance_hint(s: FishingSession) -> void:
		if controller.ui_notice_remaining > 0.0:
			_draw_top_hint_lines([_fit_text(controller.ui_notice, 280.0, 15)], 15, Color("332016")); return
		var copy := "TILT LEFT, THEN SNAP RIGHT" if controller.motion.left_handed else "TILT RIGHT, THEN SNAP LEFT"
		match s.state:
			FishingSession.State.CAST_ARMED: copy = "SNAP RIGHT" if controller.motion.left_handed else "SNAP LEFT"
			FishingSession.State.LINE_OUT: copy = "%s  •  %.0f m" % [s.fish.habitat_name(s.cast_distance_m), s.cast_distance_m]
			FishingSession.State.BITE: copy = "FISH ON — WAIT FOR THE PULSES"
			FishingSession.State.HOOK_WINDOW: copy = "BITE — PULL LEFT" if controller.motion.left_handed else "BITE — PULL RIGHT"
			FishingSession.State.REELING:
				var fight_tier := FightChallenge.tier(s.tension, s.challenge_profile)
				if fight_tier in ["ease", "snap"]: copy = "TILT RIGHT TO EASE" if controller.motion.left_handed else "TILT LEFT TO EASE"
				elif fight_tier in ["slack", "pull"]: copy = "TILT LEFT TO PULL" if controller.motion.left_handed else "TILT RIGHT TO PULL"
				else: copy = "HOLD THE MIDDLE"
			FishingSession.State.CAUGHT: copy = "%s LANDED" % s.fish.display_name.to_upper()
			FishingSession.State.ESCAPED: copy = s.last_reason.to_upper()
		# The left plaque owns all native fishing guidance. The fixed two-line layout
		# stays readable during a bite and never shifts across the cast/fight loop.
		if s.state == FishingSession.State.READY:
			_draw_top_hint_lines(["TILT %s" % ("LEFT" if controller.motion.left_handed else "RIGHT"), "THEN SNAP %s" % ("RIGHT" if controller.motion.left_handed else "LEFT")], 17, Color("332016"))
		elif s.state == FishingSession.State.HOOK_WINDOW:
			_draw_top_hint_lines(["BITE", "PULL %s" % ("LEFT" if controller.motion.left_handed else "RIGHT")], 18, Color("332016"))
		elif s.state == FishingSession.State.BITE:
			_draw_top_hint_lines(["FISH ON", "WAIT FOR PULSES"], 18, Color("332016"))
		elif s.state == FishingSession.State.ESCAPED: _draw_top_hint_lines(["FISH GOT AWAY"], 18, Color("332016"))
		else: _draw_top_hint_lines([_fit_text(copy, 280.0, 17)], 17, Color("332016"))
	func _draw_top_hint_lines(lines: Array, point_size: int, color: Color) -> void:
		var base_y := _virtual_safe_top() + (62.0 if lines.size() > 1 else 73.0)
		for index in range(lines.size()): _centered_text(str(lines[index]), Vector2(214, base_y + index * 22.0), point_size, color)
	func _draw_fight_status(s: FishingSession) -> void:
		if not should_draw_tension_meter(s): return
		_refresh_tension_meter_geometry()
		var tension := tension_meter_value(s.tension)
		var profile: Dictionary = s.challenge_profile
		var tier := tension_status(tension, profile)
		var label := "TENSION  %d%%  %s" % [roundi(tension * 100.0), tier]
		var label_pos := tension_meter_rect.position + Vector2(0, -11)
		draw_string_outline(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 2, Color("2b180e")); _text(label, label_pos, 18, Color("fff1d1"))
		draw_rect(tension_meter_rect.grow(2), Color("fff0c9"), true); draw_rect(tension_meter_rect.grow(2), Color("2a180f"), false, 2.0)
		draw_rect(tension_meter_rect, Color("24160d"), true)
		var low_critical := float(profile.low_critical); var low_warning := float(profile.low_warning); var high_warning := float(profile.high_warning); var high_critical := float(profile.high_critical)
		# Both ends are painted before the fill so the safe middle is legible even
		# when the marker is near a red edge.
		var segments := [[0.0, low_critical, Color("8f302b")], [low_critical, low_warning, Color("cf8639")], [low_warning, high_warning, Color("307d69")], [high_warning, high_critical, Color("cf8639")], [high_critical, 1.0, Color("8f302b")]]
		for segment in segments:
			var x := tension_meter_rect.position.x + tension_meter_rect.size.x * float(segment[0])
			draw_rect(Rect2(x, tension_meter_rect.position.y, tension_meter_rect.size.x * (float(segment[1]) - float(segment[0])), tension_meter_rect.size.y), segment[2], true)
		for boundary in [low_critical, low_warning, high_warning, high_critical]:
			var boundary_x: float = tension_meter_rect.position.x + tension_meter_rect.size.x * float(boundary)
			draw_line(Vector2(boundary_x, tension_meter_rect.position.y), Vector2(boundary_x, tension_meter_rect.end.y), Color("fff0c9", 0.70), 1.0)
		var marker_x := tension_meter_rect.position.x + tension_meter_rect.size.x * tension
		draw_circle(Vector2(marker_x, tension_meter_rect.get_center().y), 7.0, Color("fff0c9")); draw_circle(Vector2(marker_x, tension_meter_rect.get_center().y), 7.0, Color("2a180f"), false, 2.0)
		_text("LANDING", Vector2(190, 1111), 14, Color("fff1d1")); draw_line(Vector2(275, 1106), Vector2(527, 1106), Color("2a180f"), 6.0); draw_line(Vector2(275, 1106), Vector2(275 + 252 * s.fight_progress, 1106), Color("d7ad6d"), 4.0)
	func _refresh_tension_meter_geometry() -> void:
		# A full-height shared beam needs clear breathing room before the fight HUD.
		tension_meter_rect = Rect2(30, _virtual_safe_top() + 146, 540, 18)
	func tension_status(tension: float, profile: Dictionary = {}) -> String:
		var active_profile := profile if not profile.is_empty() else FightChallenge.profile(FightChallenge.DEFAULT_ID)
		match FightChallenge.tier(tension_meter_value(tension), active_profile):
			"slack": return "SLACK"
			"pull": return "PULL"
			"ease": return "EASE"
			"snap": return "TOO TIGHT"
		return "STEADY"
	func tension_meter_value(tension: float) -> float: return clampf(tension, 0.0, 1.0)
	func should_draw_tension_meter(s: FishingSession) -> bool: return overlay.is_empty() and s.state == FishingSession.State.REELING
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
		_draw_wood_control(Rect2(74, 672 + body_shift, 572, 108))
		for mark in range(11):
			var x := 106.0 + mark * 50.5
			draw_line(Vector2(x, 746 + body_shift), Vector2(x, 746 + body_shift - (22 if mark % 2 == 0 else 12)), Color("fff2c4"), 2.0)
		_centered_text("%.1f cm" % length, Vector2(360, 720 + body_shift), 34, Color("fff4d1"))
		var species := _fit_text(s.fish.display_name.to_upper(), 520.0, 29)
		_centered_text(species, Vector2(361, 822 + body_shift), 29, Color(0.01, 0.07, 0.08, 0.72)); _centered_text(species, Vector2(360, 820 + body_shift), 29, Color("fff1c4"))
		_centered_text(status, Vector2(360, 858 + body_shift), 19, Color("f3d979"))
		_centered_text("%s  •  %.0f m CAST" % [s.location_id.replace("_", " ").to_upper(), s.cast_distance_m], Vector2(360, 892 + body_shift), 16, Color("d7eee4"))
		catch_continue_rect = Rect2(92, 914 + body_shift, 250, 70); catch_records_rect = Rect2(378, 914 + body_shift, 250, 70)
		_draw_wood_control(catch_continue_rect); _draw_wood_control(catch_records_rect)
		_centered_text_in_rect("CONTINUE", catch_continue_rect, 18, Color("fff1c4")); _centered_text_in_rect("RECORDS", catch_records_rect, 18, Color("fff1c4"))
		if s.can_recast_from_motion(): _centered_text("READY — TILT, THEN SNAP TO CAST AGAIN", Vector2(360, 1018 + body_shift), 15, Color("fff4d1"))
	func _draw_escape_card(s: FishingSession) -> void:
		var notice := Rect2(84, _virtual_safe_top() + 118, 552, 118)
		_draw_wood_control(notice); _centered_text_in_rect("FISH GOT AWAY", Rect2(notice.position, Vector2(notice.size.x, 30)), 22, Color("fff2d5")); _centered_text_in_rect("Ease forward when warning pulses speed up.", Rect2(notice.position + Vector2(0, 30), Vector2(notice.size.x, 27)), 13, Color("fff1c4")); _centered_text_in_rect("READY — TILT, THEN SNAP" if s.can_recast_from_motion() else "SETTLE THE PHONE", Rect2(notice.position + Vector2(0, 59), Vector2(notice.size.x, 30)), 14, Color("fff2d5"))
	func _draw_calibration() -> void:
		_refresh_modal_layout(); _draw_rustic_clipboard()
		_centered_text_in_rect("MOTION CHECK", modal_header_rect, 25, Color("fff4d1"))
		var step: int = controller.motion.calibration_progress + 1
		_centered_text("Practice cast %d of 2" % min(step, 2), Vector2(360, 460), 22, Color("3b2818"))
		var phase: String = controller.motion.calibration_phase
		var copy := "Rest the phone flat and still for a moment."
		if phase.contains("snap"):
			copy = "Now snap %s to finish this practice cast." % ("right" if controller.motion.left_handed else "left")
		elif phase.contains("back"):
			copy = "Tilt %s, then snap %s when ready." % ["left" if controller.motion.left_handed else "right", "right" if controller.motion.left_handed else "left"]
		_centered_text(_fit_text(copy, 520, 20), Vector2(360, 530), 20, Color("3b2818"))
		_centered_text("Calibration starts automatically — no buttons.", Vector2(360, 590), 16, Color("3b2818"))
	func _draw_settings() -> void:
		_refresh_modal_layout()
		_draw_rustic_clipboard()
		_centered_text("SETTINGS", modal_header_rect.get_center() + Vector2(0, 10), 30, Color("fff4d1")); var settings: Dictionary = controller.save.data.settings
		_draw_setting_row(settings_haptics_rect, "HAPTICS", "ON" if settings.haptics else "OFF")
		_draw_setting_row(settings_reduced_motion_rect, "REDUCED MOTION", "ON" if settings.reduced_motion else "OFF")
		_draw_setting_row(settings_handedness_rect, "HANDEDNESS", "LEFT" if settings.left_handed else "RIGHT")
		_centered_text("Changing handedness resets the active session", Vector2(360, settings_handedness_rect.end.y + 30), 15, Color("123942")); _centered_text("and starts motion setup again.", Vector2(360, settings_handedness_rect.end.y + 51), 15, Color("123942"))
		_draw_setting_row(settings_challenge_rect, "FIGHT CHALLENGE", "%s • NEXT CAST" % FightChallenge.display_name(settings.get("fight_challenge", FightChallenge.DEFAULT_ID)))
		_draw_wood_control(settings_test_haptics_rect); _centered_text_in_rect("TEST VIBRATION", settings_test_haptics_rect, 18, Color("fff4d1"))
		_draw_wood_control(settings_motion_setup_rect); _centered_text_in_rect("MOTION SETUP", settings_motion_setup_rect, 18, Color("fff4d1"))
		_centered_text("BACK TO FISHING", settings_footer_close_rect.get_center() + Vector2(0, 6), 17, Color("fff4d1"))
	func _draw_setting_row(rect: Rect2, title: String, value: String) -> void:
		var half_height := rect.size.y * 0.5
		_draw_wood_control(rect)
		_centered_text_in_rect(title, Rect2(rect.position, Vector2(rect.size.x, half_height)), maxi(12, int(rect.size.y * 0.34)), Color("fff4d1"))
		_centered_text_in_rect(value, Rect2(rect.position + Vector2(0, half_height), Vector2(rect.size.x, half_height)), maxi(13, int(rect.size.y * 0.38)), Color("fff4d1"))
	func _draw_wood_control(rect: Rect2) -> void:
		if controller.top_nav_texture: draw_texture_rect_region(controller.top_nav_texture, rect, Rect2(124, 172, 1012, 323))
		else: draw_style_box(_panel_style(Color("62451f"), Color("24170d")), rect)
	func _draw_motion_setup() -> void:
		_refresh_modal_layout()
		_draw_rustic_clipboard()
		_centered_text("MOTION SETUP", modal_header_rect.get_center() + Vector2(0, 8), 22, Color("fff4d1"))
		_draw_setting_row(motion_sensitivity_rect, "SENSITIVITY", "%.1f" % float(controller.save.data.settings.sensitivity))
		for button in [motion_recalibrate_rect, motion_capture_rect, motion_diagnostics_rect]: _draw_wood_control(button)
		_centered_text_in_rect("RECALIBRATE MOTION", motion_recalibrate_rect, 17, Color("fff4d1")); _centered_text_in_rect("RECORD 10 CASTS", motion_capture_rect, 18, Color("fff4d1")); _centered_text_in_rect("MOTION DIAGNOSTICS", motion_diagnostics_rect, 17, Color("fff4d1"))
		_centered_text("Recalibration clears the active cast and starts", Vector2(360, 550), 16, Color("123942")); _centered_text("two practice casts.", Vector2(360, 576), 16, Color("123942"))
		_centered_text("BACK TO SETTINGS", motion_back_rect.get_center() + Vector2(0, 6), 17, Color("fff4d1"))
	func _draw_cast_capture() -> void:
		_refresh_modal_layout()
		var data: Dictionary = controller.cast_capture.status()
		var done := int(data.get("cast_index", 0))
		var phase := str(data.get("phase", "idle"))
		_draw_rustic_clipboard(); _centered_text_in_rect("CAST TUNING CAPTURE", modal_header_rect, 23, Color("fff4d1"))
		if phase == "saved":
			_centered_text("10 CASTS SAVED", Vector2(360, 505), 29, Color("3b2818")); _centered_text("Raw trace is stored only for this explicit capture.", Vector2(360, 558), 16, Color("3b2818")); _centered_text_in_rect("BACK TO MOTION SETUP", motion_back_rect, _modal_footer_font_size("BACK TO MOTION SETUP"), Color("fff4d1")); return
		var copy := "GET READY — WINDOWS BEGIN SOON"
		if phase == "active": copy = "CAST NOW — TILT, THEN SNAP"
		elif phase == "rest": copy = "REST — NEXT WINDOW WILL VIBRATE"
		_centered_text("CAST %d OF %d" % [min(done + 1, CastCaptureService.CAST_COUNT), CastCaptureService.CAST_COUNT], Vector2(360, 488), 22, Color("3b2818")); _centered_text(copy, Vector2(360, 554), 19, Color("3b2818")); _centered_text("No taps needed. Gameplay is paused.", Vector2(360, 624), 16, Color("3b2818")); _centered_text("Each active window is haptic-cued.", Vector2(360, 658), 16, Color("3b2818"))
	func _draw_locations() -> void:
		var safe_top := _virtual_safe_top()
		_refresh_location_card_rects(safe_top)
		var background: Texture2D = controller.location_texture(controller.session.location_id)
		if background: draw_texture_rect(background, Rect2(0, 0, 720, 1280), false)
		# The viewport owns scrolling water cards; fixed wood controls do not move.
		for index in range(LocationDefinition.all().size()):
			var location: Dictionary = LocationDefinition.all()[index]
			_draw_location_card(location, location_card_rects[index])
		var content_height := 0.0
		for index in range(LocationDefinition.all().size()): content_height += _waters_card_height(index) + (18.0 if index > 0 else 0.0)
		if content_height > waters_viewport_rect.size.y:
			var rail := Rect2(682, waters_viewport_rect.position.y + 10, 6, waters_viewport_rect.size.y - 20)
			var thumb_height := maxf(56.0, rail.size.y * waters_viewport_rect.size.y / content_height)
			var scroll_range := content_height - waters_viewport_rect.size.y
			var thumb_y := rail.position.y + (rail.size.y - thumb_height) * waters_scroll / maxf(scroll_range, 1.0)
			draw_rect(rail, Color("3b2818", 0.68)); draw_rect(Rect2(rail.position.x, thumb_y, rail.size.x, thumb_height), Color("efdaa2"))
		# Waters is an overlay with its own continuous wood rail. Draw the single
		# source first, then keep its Back target and title native on that same rail;
		# do not assemble it from two separated planks over the scenery.
		_draw_wood_control(Rect2(0, safe_top, 720, 108))
		_centered_text_in_rect("BACK TO FISHING", back_to_fishing_rect, 15, Color("fff4d1"))
		_centered_text_in_rect("WATERS", Rect2(286, safe_top + 18, 402, 64), 22, Color("fff4d1"))
	func _draw_back_to_fishing(safe_top: float) -> void:
		_refresh_back_to_fishing_rect(safe_top)
		_draw_wood_control(back_to_fishing_rect)
		_centered_text("BACK TO FISHING", back_to_fishing_rect.get_center() + Vector2(0, 6), 17, Color("fff4d1"))
	func _refresh_back_to_fishing_rect(safe_top: float) -> void:
		back_to_fishing_rect = Rect2(420, safe_top + 18, 264, 64)
	func _draw_records_back_to_fishing(safe_top: float) -> void:
		_refresh_records_back_to_fishing_rect(safe_top)
		var visual_rect := Rect2(back_to_fishing_rect.position + Vector2(14, 8), back_to_fishing_rect.size - Vector2(28, 18))
		_draw_wood_control(visual_rect)
		_centered_text("BACK TO FISHING", visual_rect.get_center() + Vector2(0, 5), 16, Color("fff4d1"))
	func _refresh_records_back_to_fishing_rect(safe_top: float) -> void:
		# The bottom journal footer is clear of the authored crest and all six fish; the hit target stays safe-aware.
		var visual_y := maxf(1168.0, safe_top + 18.0)
		back_to_fishing_rect = Rect2(416, visual_y - 8.0, 280, 64)
	func _refresh_location_card_rects(safe_top: float) -> void:
		# Cards start below the full header, leaving the fixed Back control reachable
		# even at the tall device safe inset.
		waters_viewport_rect = Rect2(30, safe_top + 124, 660, 1050 - safe_top)
		var gap := 18.0
		var content_height := 0.0
		for index in range(LocationDefinition.all().size()): content_height += _waters_card_height(index) + (gap if index > 0 else 0.0)
		var max_scroll := maxf(0.0, content_height - waters_viewport_rect.size.y)
		waters_scroll = clampf(waters_scroll, 0.0, max_scroll)
		var y := waters_viewport_rect.position.y - waters_scroll
		for index in range(location_card_rects.size()):
			var height := _waters_card_height(index)
			location_card_rects[index] = Rect2(50, y, 620, height); y += height + gap
		location_pine_rect = location_card_rects[1]
		location_cedar_rect = location_card_rects[2]
		back_to_fishing_rect = Rect2(32, safe_top + 18, 242, 64)
	func _waters_card_height(index: int) -> float:
		if controller == null or controller.save == null: return 416.0
		var location: Dictionary = LocationDefinition.all()[index]
		var missing_count: int = controller.missing_location_fish(str(location.get("id", ""))).size()
		return 416.0 + (ceil(float(missing_count) / 3.0) * 18.0 if missing_count > 0 else 0.0)
	func _draw_waters_clipped_texture(texture: Texture2D, destination: Rect2, source: Rect2) -> void:
		if texture == null: return
		var visible := destination.intersection(waters_viewport_rect)
		if visible.size.x <= 0.0 or visible.size.y <= 0.0: return
		var fraction := (visible.position - destination.position) / destination.size
		var clipped_source := Rect2(source.position + source.size * fraction, source.size * (visible.size / destination.size))
		draw_texture_rect_region(texture, visible, clipped_source)
	func _draw_waters_text(value: String, rect: Rect2, size: int, color: Color) -> void:
		if waters_viewport_rect.encloses(rect): _centered_text_in_rect(value, rect, size, color)
	func _draw_location_card(location: Dictionary, rect: Rect2) -> void:
		if not rect.intersects(waters_viewport_rect): return
		# Only reusable border strips are taken from the Waters master; no baked card
		# photo or copy survives underneath the new real preview and parchment panel.
		var frame: Texture2D = controller.rustic_waters_texture
		_draw_waters_clipped_texture(frame, Rect2(rect.position, Vector2(rect.size.x, 20)), Rect2(32, 224, 877, 34))
		_draw_waters_clipped_texture(frame, Rect2(rect.position + Vector2(0, rect.size.y - 20), Vector2(rect.size.x, 20)), Rect2(32, 807, 877, 24))
		_draw_waters_clipped_texture(frame, Rect2(rect.position, Vector2(20, rect.size.y)), Rect2(32, 258, 28, 549))
		_draw_waters_clipped_texture(frame, Rect2(rect.position + Vector2(rect.size.x - 20, 0), Vector2(20, rect.size.y)), Rect2(881, 258, 28, 549))
		var image_rect := Rect2(rect.position + Vector2(20, 24), Vector2(580, 190))
		var texture: Texture2D = controller.location_texture(str(location.get("id", "")))
		if texture:
			var image_size := texture.get_size()
			var crop_height := image_size.x / maxf(image_rect.size.x / image_rect.size.y, 0.01)
			var center := 0.35 if str(location.get("id", "")) == "hatteras_inlet" else (0.40 if str(location.get("id", "")) == "cedar_river" else 0.46)
			var crop_y := clampf(image_size.y * center - crop_height * 0.5, 0.0, image_size.y - crop_height)
			_draw_waters_clipped_texture(texture, image_rect, Rect2(0, crop_y, image_size.x, crop_height))
		var id := str(location.get("id", ""))
		if controller.session.location_id == id: draw_rect(rect.intersection(waters_viewport_rect).grow(-4), Color("f0d579"), false, 4.0)
		var info_rect := Rect2(rect.position + Vector2(20, 220), Vector2(580, rect.size.y - 240))
		_draw_waters_clipped_texture(controller.rustic_settings_texture, info_rect, Rect2(120, 650, 700, 310))
		var selected: bool = controller.session.location_id == id
		var unlocked: bool = controller.is_location_unlocked(id)
		_draw_waters_text(("SELECTED • " if selected else "") + str(location.get("title", "")).to_upper() + " • " + str(location.get("water_type", "")), Rect2(info_rect.position + Vector2(12, 8), Vector2(info_rect.size.x - 24, 24)), 18, Color("3b2818"))
		_draw_waters_text(str(location.get("region", "")).to_upper(), Rect2(info_rect.position + Vector2(12, 33), Vector2(info_rect.size.x - 24, 21)), 16, Color("3b2818"))
		for row in range(3):
			var fish_id := str(location.get("species_ids", [])[row])
			var caught := int(controller.save.data.catches.get(fish_id, 0)) > 0
			_draw_waters_text(("✓ " if caught else "○ ") + controller._fish_name(fish_id), Rect2(info_rect.position + Vector2(12, 58 + row * 19), Vector2(info_rect.size.x - 24, 18)), 16, Color("3b2818"))
		if unlocked:
			_draw_waters_text("UNLOCKED • %d / 3 DISCOVERED" % controller._discovered_species_count(id), Rect2(info_rect.position + Vector2(12, 118), Vector2(info_rect.size.x - 24, 20)), 16, Color("3b2818"))
		else:
			var missing: Array[String] = []
			for fish_id in controller.missing_location_fish(id): missing.append(controller._fish_name(fish_id))
			var prerequisite_total := LocationDefinition.earlier_species(id).size()
			_draw_waters_text("LOCKED • %d / %d PRIOR SPECIES" % [prerequisite_total - missing.size(), prerequisite_total], Rect2(info_rect.position + Vector2(12, 118), Vector2(info_rect.size.x - 24, 20)), 16, Color("3b2818"))
			for group in range(ceili(float(missing.size()) / 3.0)):
				var from := group * 3; var to := mini(from + 3, missing.size())
				_draw_waters_text(", ".join(missing.slice(from, to)), Rect2(info_rect.position + Vector2(12, 139 + group * 18), Vector2(info_rect.size.x - 24, 17)), 16, Color("3b2818"))
	func _draw_diagnostics() -> void:
		_refresh_modal_layout()
		var data: Dictionary = controller.motion.get_diagnostics(); var reasons: Dictionary = data.reasons
		_draw_rustic_clipboard(); _centered_text_in_rect("MOTION DIAGNOSTICS", modal_header_rect, 22, Color("fff4d1")); _centered_text("Tilt attempts: %d" % int(data.cock_attempts), Vector2(360, 465), 20, Color("3b2818")); _centered_text("Completed casts: %d" % int(data.completed_casts), Vector2(360, 510), 20, Color("3b2818")); _centered_text("Fails L/A/P/G/T: %d / %d / %d / %d / %d" % [int(reasons.linear), int(reasons.axis), int(reasons.polarity), int(reasons.gyro), int(reasons.timeout)], Vector2(360, 620), 17, Color("3b2818")); _centered_text("Derived counts only. Raw traces exist only after", Vector2(360, 694), 15, Color("3b2818")); _centered_text("an explicit RECORD 10 CASTS session.", Vector2(360, 722), 15, Color("3b2818")); _centered_text_in_rect("BACK TO MOTION SETUP", motion_back_rect, _modal_footer_font_size("BACK TO MOTION SETUP"), Color("fff4d1"))
	func _draw_records() -> void:
		var safe_top := _virtual_safe_top()
		_refresh_records_geometry(safe_top)
		var page := _journal_page_rect(safe_top)
		if controller.records_texture:
			var band_height := _journal_map_y(150.0)
			draw_texture_rect_region(controller.records_texture, Rect2(0, 0, 720, band_height), Rect2(0, 0, 941, 150))
			draw_texture_rect_region(controller.records_texture, Rect2(0, band_height, 720, 1280 - band_height), Rect2(0, 150, 941, 1522))
		# One opaque authored page owns the journal/title/slots. Fish, silhouettes,
		# localized names, and stats are runtime-only because they change with saves.
		var all_fish := FishDefinition.all_planned()
		var fish_ids: Array[FishDefinition] = []
		for index in range(6):
			var fish_index := journal_page_index * 6 + index
			if fish_index < all_fish.size(): fish_ids.append(all_fish[fish_index])
		var discovered_total := 0
		for index in range(fish_ids.size()):
			var fish: FishDefinition = fish_ids[index]
			var count := int(controller.save.data.catches.get(fish.id, 0))
			var best := float(controller.save.data.best_cm.get(fish.id, 0.0))
			if count > 0: discovered_total += 1
			var slot: Rect2 = journal_fish_rects[index]
			_draw_fish_atlas_contained(fish.id, slot.grow(-8.0), Color.WHITE if count > 0 else Color("172e2b"))
			var name_rect: Rect2 = journal_name_rects[index]
			var stats_rect: Rect2 = journal_stats_rects[index]
			# Runtime canvas font sizes scale against the 720px virtual viewport, not
			# the narrower safe-inset record page. This keeps full-record labels legible.
			var name_size := maxi(12, int(16 * page.size.x / 720.0))
			_centered_text_in_rect(_fit_text(fish.display_name.to_upper() if count > 0 else "UNDISCOVERED", name_rect.size.x - 28.0, name_size), name_rect, name_size, Color("fff2c8"))
			_centered_text_in_rect("%d CAUGHT  •  %s" % [count, ("%.1f cm" % best) if best > 0.0 else "—"], stats_rect, maxi(11, int(14 * page.size.x / 720.0)), Color("5f4120"))
		_centered_text_in_rect("WORLD RECORDS", records_world_rect, maxi(12, int(16 * page.size.x / 720.0)), Color("fff4d1"))
		_centered_text_in_rect("BACK TO FISHING", back_to_fishing_rect, maxi(12, int(16 * page.size.x / 720.0)), Color("fff4d1"))
		_draw_wood_control(records_previous_rect); _draw_wood_control(records_next_rect)
		_centered_text_in_rect("PREV PAGE" if journal_page_index > 0 else "PAGE 1 / 2", records_previous_rect, 15, Color("fff4d1") if journal_page_index > 0 else Color("b5a789"))
		_centered_text_in_rect("NEXT PAGE" if journal_page_index < 1 else "PAGE 2 / 2", records_next_rect, 15, Color("fff4d1") if journal_page_index < 1 else Color("b5a789"))
	func _refresh_records_geometry(safe_top: float) -> void:
		# All record art / text / hit windows are derived from one journal transform.
		# The tap window intentionally unites its fish, wood name, and paper stats.
		journal_safe_top = safe_top
		var page := _journal_page_rect(safe_top)
		var fish_sources := [Rect2(104, 289, 338, 188), Rect2(501, 289, 338, 188), Rect2(104, 669, 338, 188), Rect2(501, 669, 338, 188), Rect2(104, 1049, 338, 188), Rect2(501, 1049, 338, 188)]
		var name_sources := [Rect2(94, 493, 358, 55), Rect2(491, 493, 358, 55), Rect2(94, 873, 358, 55), Rect2(491, 873, 358, 55), Rect2(94, 1253, 358, 55), Rect2(491, 1253, 358, 55)]
		var stats_sources := [Rect2(94, 565, 358, 45), Rect2(491, 565, 358, 45), Rect2(94, 945, 358, 45), Rect2(491, 945, 358, 45), Rect2(94, 1325, 358, 45), Rect2(491, 1325, 358, 45)]
		for index in range(fish_sources.size()):
			journal_fish_rects[index] = _journal_map_rect(fish_sources[index], page)
			journal_name_rects[index] = _journal_map_rect(name_sources[index], page)
			journal_stats_rects[index] = _journal_map_rect(stats_sources[index], page)
			journal_slot_rects[index] = journal_fish_rects[index].merge(journal_name_rects[index]).merge(journal_stats_rects[index])
		records_world_rect = _journal_map_rect(Rect2(77, 1477, 370, 78), page)
		back_to_fishing_rect = _journal_map_rect(Rect2(493, 1477, 370, 78), page)
		records_previous_rect = _journal_map_rect(Rect2(77, 1394, 370, 60), page)
		records_next_rect = _journal_map_rect(Rect2(493, 1394, 370, 60), page)
	func _draw_world_records() -> void:
		_refresh_world_records_geometry()
		_draw_rustic_clipboard()
		_centered_text_in_rect("WORLD RECORDS", modal_header_rect, 22, Color("fff4d1"))
		var status: String = controller.leaderboards.status if controller.leaderboards != null else "UNAVAILABLE"
		var period: String = controller.leaderboards.period if controller.leaderboards != null else "ALL TIME"
		var paper_dark := Color("3b2818")
		if status == "UNAVAILABLE":
			_centered_text_in_rect("ONLINE RECORDS AREN'T CONNECTED YET", Rect2(world_status_rect.position, Vector2(world_status_rect.size.x, 32)), 16, paper_dark)
			_centered_text_in_rect("Your local Catch Records always stay on this phone.", Rect2(world_status_rect.position + Vector2(0, 34), Vector2(world_status_rect.size.x, 26)), 13, paper_dark)
		elif status == "NO_AUTH":
			_centered_text_in_rect("CONNECT PLAY GAMES TO VIEW ONLINE RECORDS", Rect2(world_status_rect.position, Vector2(world_status_rect.size.x, 32)), 15, paper_dark)
			_centered_text_in_rect("Your local Catch Records always stay on this phone.", Rect2(world_status_rect.position + Vector2(0, 34), Vector2(world_status_rect.size.x, 26)), 13, paper_dark)
		elif status == "ERROR":
			_centered_text_in_rect("ONLINE RECORDS COULDN'T LOAD", Rect2(world_status_rect.position, Vector2(world_status_rect.size.x, 32)), 16, paper_dark)
			_centered_text_in_rect("Try again when Play Games is available.", Rect2(world_status_rect.position + Vector2(0, 34), Vector2(world_status_rect.size.x, 26)), 13, paper_dark)
		else:
			_centered_text_in_rect("%s — %s" % ["CONNECTING" if status in ["LOADING", "CONNECTING"] else "ONLINE", period], world_status_rect, 17, paper_dark)
		var all_fish := FishDefinition.all_planned()
		for index in range(6):
			var fish_index := world_page_index * 6 + index
			if fish_index >= all_fish.size(): continue
			var fish: FishDefinition = all_fish[fish_index]
			var best := float(controller.save.data.best_cm.get(fish.id, 0.0))
			var board: Dictionary = controller.leaderboards.board_for(fish.id) if controller.leaderboards != null else {}
			var top_mm := int(board.get("top_score_mm", 0)); var mine_mm := int(board.get("player_score_mm", 0)); var rank := int(board.get("player_rank", 0))
			var world_name := _fit_text(str(board.get("top_name", "TOP")), 142.0, 11)
			var world_copy := "—" if top_mm <= 0 else "%s %.1f cm" % [world_name, top_mm / 10.0]
			var player_copy := "—" if mine_mm <= 0 else ("%.1f cm" % (mine_mm / 10.0) if rank <= 0 else "%.1f cm #%d" % [mine_mm / 10.0, rank])
			if bool(board.get("cached", false)) and player_copy != "—": player_copy += " (CACHED)"
			var row: Rect2 = world_row_rects[index]
			_centered_text_in_rect(_fit_text(fish.display_name.to_upper(), row.size.x - 20.0, 13), Rect2(row.position, Vector2(row.size.x, 24)), 13, paper_dark)
			_centered_text_in_rect(_fit_text("LOCAL %s  •  YOU %s  •  WORLD %s" % ["%.1f cm" % best if best > 0.0 else "—", player_copy, world_copy], row.size.x - 20.0, 11), Rect2(row.position + Vector2(0, 25), Vector2(row.size.x, 28)), 11, paper_dark)
		_draw_wood_control(world_retry_rect); _draw_wood_control(world_period_rect)
		_centered_text_in_rect("CONNECT" if status == "NO_AUTH" else "RETRY", world_retry_rect, 17, Color("fff4d1")); _centered_text_in_rect("WEEKLY" if period == "ALL TIME" else "ALL TIME", world_period_rect, 16, Color("fff4d1")); _centered_text_in_rect("BACK TO RECORDS", world_back_rect, _modal_footer_font_size("BACK TO RECORDS"), Color("fff4d1"))
		_draw_wood_control(world_previous_rect); _draw_wood_control(world_next_rect)
		_centered_text_in_rect("PREV PAGE" if world_page_index > 0 else "PAGE 1 / 2", world_previous_rect, 15, Color("fff4d1") if world_page_index > 0 else Color("b5a789"))
		_centered_text_in_rect("NEXT PAGE" if world_page_index < 1 else "PAGE 2 / 2", world_next_rect, 15, Color("fff4d1") if world_page_index < 1 else Color("b5a789"))
	func _refresh_world_records_geometry() -> void:
		_refresh_modal_layout()
		# Paper content starts below the clipboard's wood header. These fixed virtual
		# rows share the full source transform and leave its authored footer untouched.
		world_status_rect = Rect2(86, 360, 548, 80)
		for index in range(world_row_rects.size()): world_row_rects[index] = Rect2(86, 470 + index * 60, 548, 56)
		world_retry_rect = Rect2(86, 900, 260, 68)
		world_period_rect = Rect2(374, 900, 260, 68)
		world_previous_rect = Rect2(86, 980, 260, 50)
		world_next_rect = Rect2(374, 980, 260, 50)
		world_back_rect = modal_footer_rect
	func _journal_page_rect(safe_top: float) -> Rect2:
		# Records owns the full screen once. Under a tall safe inset its decorative
		# top band expands just enough to clear the inset; the remaining source maps
		# continuously into the remaining height, preventing a photo/page rectangle.
		return Rect2(0, 0, 720, 1280)
	func _journal_map_rect(canonical: Rect2, page: Rect2) -> Rect2:
		var scale_x := page.size.x / 941.0
		var y0 := _journal_map_y(canonical.position.y)
		var y1 := _journal_map_y(canonical.end.y)
		return Rect2(page.position.x + canonical.position.x * scale_x, y0, canonical.size.x * scale_x, y1 - y0)
	func _journal_map_y(source_y: float) -> float:
		const BAND_END := 150.0
		var natural_band := BAND_END * 720.0 / 941.0
		var band_height := maxf(natural_band, journal_safe_top + 8.0)
		if source_y <= BAND_END: return source_y / BAND_END * band_height
		return band_height + (source_y - BAND_END) / (1672.0 - BAND_END) * (1280.0 - band_height)
	func _draw_journal_detail() -> void:
		_refresh_field_notes_geometry(); _draw_rustic_clipboard()
		var fish := _fish_definition(journal_fish_id)
		var count := int(controller.save.data.catches.get(fish.id, 0))
		var best := float(controller.save.data.best_cm.get(fish.id, 0.0))
		var paper_dark := Color("3b2818")
		_centered_text_in_rect("FIELD NOTES", modal_header_rect, 22, Color("fff4d1"))
		_draw_fish_atlas_contained(fish.id, journal_detail_fish_rect, Color.WHITE if count > 0 else Color(0.08, 0.15, 0.14, 0.58))
		_centered_text_in_rect(_fit_text(fish.display_name.to_upper() if count > 0 else "UNDISCOVERED", journal_detail_title_rect.size.x - 20.0, 24), journal_detail_title_rect, 24, paper_dark)
		_centered_text_in_rect("%d CAUGHT  •  BEST %s" % [count, ("%.1f cm" % best) if best > 0.0 else "—"], journal_detail_stats_rect, 16, paper_dark)
		var history: Array[Dictionary] = controller.save.history_for_fish(fish.id)
		_centered_text_in_rect("RECENT CATCHES" if not history.is_empty() else "NO RECENT CATCHES YET", Rect2(journal_detail_history_rect.position, Vector2(journal_detail_history_rect.size.x, 26)), 15, paper_dark)
		for row in range(mini(4, maxi(0, history.size() - journal_history_offset))):
			var entry: Dictionary = history[history.size() - 1 - journal_history_offset - row]
			var date := Time.get_datetime_dict_from_unix_time(int(entry.timestamp_utc))
			var line := "%.1f cm  •  %s  •  %04d-%02d-%02d  •  %.1fs" % [float(entry.length_cm), str(entry.location_id).replace("_", " ").to_upper(), int(date.year), int(date.month), int(date.day), float(entry.fight_seconds)]
			_centered_text_in_rect(_fit_text(line, journal_detail_history_rect.size.x - 16.0, 12), Rect2(journal_detail_history_rect.position + Vector2(0, 28 + row * 30), Vector2(journal_detail_history_rect.size.x, 28)), 12, paper_dark)
		var location := LocationDefinition.by_id(fish.location_id)
		var habitat_note := str(location.get("habitat", "Work the water band, then ease between runs."))
		habitat_note = "%s. %s" % [habitat_note, "Near water favors quick contact; far water can hold longer runs."]
		if fish.id == "northern_pike": habitat_note = "Pike runs hard. Ease at the urgent pulse, then pull in the lull."
		elif fish.id == "channel_catfish": habitat_note = "Catfish hold steady pressure. Let the line breathe between pulls."
		elif fish.id == "red_drum": habitat_note = "Red drum pull with weight. Ease before the red line, then pull through the gap."
		elif fish.id == "bluefish": habitat_note = "Bluefish surge in fast bursts. Keep the rod responsive, not pinned."
		_centered_text_in_rect(_fit_text(habitat_note, journal_detail_note_rect.size.x - 16.0, 12), journal_detail_note_rect, 12, paper_dark)
		_draw_wood_control(journal_detail_back_rect); _draw_wood_control(journal_detail_next_rect)
		_centered_text_in_rect("BACK TO RECORDS", journal_detail_back_rect, 15, Color("fff4d1"))
		_centered_text_in_rect("OLDER" if history.size() > journal_history_offset + 4 else "NO OLDER CATCHES", journal_detail_next_rect, 13, Color("fff4d1"))
	func _refresh_field_notes_geometry() -> void:
		_refresh_modal_layout()
		journal_detail_fish_rect = Rect2(120, 330, 480, 220)
		journal_detail_title_rect = Rect2(90, 560, 540, 36)
		journal_detail_stats_rect = Rect2(90, 598, 540, 30)
		journal_detail_history_rect = Rect2(86, 650, 548, 158)
		journal_detail_note_rect = Rect2(94, 818, 532, 54)
		journal_detail_back_rect = Rect2(92, 900, 250, 68)
		journal_detail_next_rect = Rect2(378, 900, 250, 68)
	func _fish_definition(fish_id: String) -> FishDefinition:
		for fish in FishDefinition.all_planned():
			if fish.id == fish_id: return fish
		return FishDefinition.bluegill()
	func _draw_fish_atlas_contained(fish_id: String, destination: Rect2, modulate := Color.WHITE) -> void:
		var atlas := _fish_atlas_for(fish_id)
		if atlas == null: return
		var source := _fish_atlas_region(fish_id)
		var scale := minf(destination.size.x / source.size.x, destination.size.y / source.size.y)
		var size := source.size * scale
		var contained := Rect2(destination.position + (destination.size - size) * 0.5, size)
		draw_texture_rect_region(atlas, contained, source, modulate)
	func _draw_fish_catch_flick(fish_id: String, destination: Rect2, tail_offset: float) -> void:
		var atlas := _fish_atlas_for(fish_id)
		if atlas == null: return
		var source := _fish_atlas_region(fish_id)
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
	func _fish_atlas_for(fish_id: String) -> Texture2D:
		if fish_id in ["pumpkinseed", "black_crappie", "brown_bullhead"]: return controller.willow_fish_atlas
		if fish_id in ["rainbow_trout", "smallmouth_bass", "northern_pike"]: return controller.cedar_fish_atlas
		if fish_id in ["red_drum", "spotted_seatrout", "bluefish"]: return controller.ocean_fish_atlas
		return controller.pine_fish_atlas
	func _fish_atlas_region(fish_id: String) -> Rect2:
		# The pond master intentionally has unequal safe rows; this shared metadata
		# keeps contained records and tail mesh from clipping a fin or sampling a neighbor.
		match fish_id:
			"pumpkinseed": return Rect2(0, 0, 1024, 543)
			"black_crappie": return Rect2(0, 543, 1024, 535)
			"brown_bullhead": return Rect2(0, 1078, 1024, 458)
			"largemouth_bass", "smallmouth_bass", "spotted_seatrout": return Rect2(0, 512, 1024, 512)
			"channel_catfish", "northern_pike", "bluefish": return Rect2(0, 1024, 1024, 512)
		return Rect2(0, 0, 1024, 512)
	func _gui_input(event: InputEvent) -> void:
		var scale := Vector2(720.0 / size.x, 1280.0 / size.y)
		if overlay == "locations":
			if event is InputEventScreenTouch and event.index == 0:
				_handle_waters_touch(event.position * scale, bool(event.pressed)); return
			if event is InputEventScreenTouch and event.index != 0:
				# A second finger invalidates the pending primary tap.  Ignore its own
				# coordinates so it cannot begin a competing scroll or card selection.
				if bool(event.pressed) and waters_pointer_active:
					waters_secondary_touch_seen = true; waters_dragging = true; waters_press_location_id = ""
				return
			if event is InputEventScreenDrag and event.index == 0:
				_handle_waters_drag(event.position * scale); return
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
				_handle_waters_touch(event.position * scale, bool(event.pressed)); return
			if event is InputEventMouseMotion and waters_pointer_active and event.device != InputEvent.DEVICE_ID_EMULATION:
				_handle_waters_drag(event.position * scale); return
			if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and bool(event.pressed) and waters_viewport_rect.has_point(event.position * scale) and event.button_index == MOUSE_BUTTON_WHEEL_UP: _scroll_waters(-90.0); return
			if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and bool(event.pressed) and waters_viewport_rect.has_point(event.position * scale) and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _scroll_waters(90.0); return
		if event is InputEventScreenTouch:
			if controller.accepts_primary_press(true, bool(event.pressed), event.index == 0, event.device): _handle_press(event.position * scale)
		elif event is InputEventMouseButton:
			if controller.accepts_primary_press(false, bool(event.pressed), event.button_index == MOUSE_BUTTON_LEFT, event.device): _handle_press(event.position * scale)
	func _scroll_waters(delta_y: float) -> void:
		_refresh_location_card_rects(_virtual_safe_top())
		waters_scroll += delta_y; _refresh_location_card_rects(_virtual_safe_top()); queue_redraw()
	func reset_waters_pointer() -> void:
		waters_pointer_active = false
		waters_dragging = false
		waters_press_location_id = ""
		waters_secondary_touch_seen = false
	func _handle_waters_touch(position: Vector2, pressed: bool) -> void:
		if pressed:
			if not waters_viewport_rect.has_point(position): _handle_press(position); return
			waters_pointer_active = true; waters_dragging = false; waters_secondary_touch_seen = false; waters_drag_start = position; waters_drag_origin = waters_scroll; waters_press_location_id = _waters_location_at(position)
			return
		if not waters_pointer_active: return
		if (position - waters_drag_start).length() > 12.0: waters_dragging = true
		waters_pointer_active = false
		if not waters_dragging and not waters_secondary_touch_seen and waters_press_location_id == _waters_location_at(position): _handle_press(position)
		waters_press_location_id = ""; waters_secondary_touch_seen = false
	func _handle_waters_drag(position: Vector2) -> void:
		if not waters_pointer_active: return
		var delta := position - waters_drag_start
		if delta.length() > 12.0: waters_dragging = true
		if waters_dragging:
			waters_scroll = waters_drag_origin - delta.y; _refresh_location_card_rects(_virtual_safe_top()); queue_redraw()
	func _waters_location_at(position: Vector2) -> String:
		for index in range(location_card_rects.size()):
			if location_card_rects[index].intersection(waters_viewport_rect).has_point(position): return str(LocationDefinition.all()[index].get("id", ""))
		return ""
	func _handle_press(pos: Vector2) -> void:
		_refresh_top_nav_geometry()
		_refresh_modal_layout()
		if overlay == "calibration" or overlay == "capture": return
		if overlay == "capture_saved":
			if motion_back_rect.has_point(pos): overlay = "motion_setup"
			return
		if overlay == "records":
			_refresh_records_geometry(_virtual_safe_top())
			if back_to_fishing_rect.has_point(pos): controller._close_overlay(); return
			if records_world_rect.has_point(pos):
				overlay = "world_records"
				if controller.leaderboards != null and not controller.capture_mode: controller.leaderboards.open_records()
				return
			if records_previous_rect.has_point(pos): journal_page_index = maxi(0, journal_page_index - 1); return
			if records_next_rect.has_point(pos): journal_page_index = mini(1, journal_page_index + 1); return
			for index in range(journal_slot_rects.size()):
				var fish_index := journal_page_index * 6 + index
				if fish_index < FishDefinition.all_planned().size() and journal_slot_rects[index].has_point(pos): journal_fish_id = FishDefinition.all_planned()[fish_index].id; journal_history_offset = 0; overlay = "journal_detail"; return
			return
		if overlay == "journal_detail":
			_refresh_field_notes_geometry()
			if journal_detail_back_rect.has_point(pos): overlay = "records"
			elif journal_detail_next_rect.has_point(pos):
				var history: Array[Dictionary] = controller.save.history_for_fish(journal_fish_id)
				if history.size() > journal_history_offset + 4: journal_history_offset += 4
			return
		if overlay == "world_records":
			_refresh_world_records_geometry()
			if world_back_rect.has_point(pos): overlay = "records"
			elif world_previous_rect.has_point(pos): world_page_index = maxi(0, world_page_index - 1)
			elif world_next_rect.has_point(pos): world_page_index = mini(1, world_page_index + 1)
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
				_refresh_location_card_rects(location_safe_top)
				if back_to_fishing_rect.has_point(pos): controller._close_overlay()
				elif controller._can_open_records():
					for index in range(location_card_rects.size()):
						if location_card_rects[index].intersection(waters_viewport_rect).has_point(pos): controller._select_location(str(LocationDefinition.all()[index].get("id", ""))); return
			elif overlay == "diagnostics" and motion_back_rect.has_point(pos): overlay = "motion_setup"
			return
		if overlay == "settings":
			if settings_footer_close_rect.has_point(pos): controller._close_overlay()
			elif settings_haptics_rect.has_point(pos): controller._toggle_setting("haptics")
			elif settings_reduced_motion_rect.has_point(pos): controller._toggle_setting("reduced_motion")
			elif settings_handedness_rect.has_point(pos): controller._toggle_setting("left_handed")
			elif settings_challenge_rect.has_point(pos): controller._toggle_setting("fight_challenge")
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
		if records_rect.has_point(pos) and controller._can_open_records(): overlay = "records"; return
		if records_rect.has_point(pos) or locations_rect.has_point(pos):
			if not controller._can_open_records(): controller.ui_notice = "FINISH THIS CAST"; controller.ui_notice_remaining = 1.8
			elif records_rect.has_point(pos): overlay = "records"
			else: reset_waters_pointer(); overlay = "locations"
			return
		if controller.session.state == FishingSession.State.ESCAPED: controller._reset_session()
	func _control_style(name: String) -> StyleBoxTexture:
		var skin := StyleBoxTexture.new()
		return skin
	func _draw_control_region(name: String, destination: Rect2) -> void:
		_draw_wood_control(destination)
	func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new(); box.bg_color = background; box.border_color = border; box.set_border_width_all(3); box.set_corner_radius_all(20); return box
	func _text(value: String, pos: Vector2, font_size: int, color: Color) -> void: draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	func _centered_text(value: String, center: Vector2, font_size: int, color: Color) -> void:
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_text(value, Vector2(center.x - width * 0.5, center.y), font_size, color)
	func _centered_text_in_rect(value: String, rect: Rect2, font_size: int, color: Color) -> void:
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var ascent := font.get_ascent(font_size)
		var descent := font.get_descent(font_size)
		_text(value, Vector2(rect.get_center().x - width * 0.5, rect.get_center().y + (ascent - descent) * 0.5), font_size, color)
	func _fit_text(value: String, width: float, preferred_size: int) -> String:
		if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, preferred_size).x <= width: return value
		var words := value.split(" ")
		var line := ""
		for word in words:
			var candidate := word if line.is_empty() else line + " " + word
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, preferred_size).x > width and not line.is_empty(): return line + "…"
			line = candidate
		# A leaderboard name can be one unbroken online handle. Do not return that
		# overlong token unchanged: trim by characters until the ellipsis itself fits.
		var compact := line
		while not compact.is_empty() and font.get_string_size(compact + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, preferred_size).x > width:
			compact = compact.substr(0, compact.length() - 1)
		return compact + "…" if not compact.is_empty() else "…"
