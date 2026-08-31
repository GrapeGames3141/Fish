extends Node

const FishingSession = preload("res://src/domain/fishing_session.gd")
const MotionService = preload("res://src/services/motion_service.gd")
const SaveService = preload("res://src/services/save_service.gd")
const AdMobService = preload("res://src/services/admob_service.gd")
const HapticService = preload("res://src/services/haptic_service.gd")
const CastCaptureService = preload("res://src/services/cast_capture_service.gd")
const FishDefinition = preload("res://src/domain/fish_definition.gd")

var session: FishingSession
var motion: MotionService
var save: SaveService
var ads: AdMobService
var haptics: HapticService
var cast_capture: CastCaptureService
var prior_state := -1
var view: FishingView
var capture_path := ""
var capture_scenario := "ready"
var loading_elapsed := 0.0
var loading_active := true
var ui_time := 0.0
var caught_recorded := false
var capture_mode := false

var pine_lake_texture: Texture2D = load("res://art/ui_v1/runtime_source/pine-lake-clean-v01.png")
var cedar_river_texture: Texture2D = load("res://art/ui_v1/runtime_source/cedar-river-clean-v02.png")
var pine_fish_atlas: Texture2D = load("res://art/ui_v1/runtime_source/pine-fish-atlas-v02.png")
var cedar_fish_atlas: Texture2D = load("res://art/ui_v1/runtime_source/cedar-fish-atlas-v02.png")
var rod_texture: Texture2D = load("res://art/ui_v1/runtime_source/rod-bend-repacked-v02.png")
var bobber_texture: Texture2D = load("res://art/ui_v1/runtime_source/bobber-v01.png")
var reaction_texture: Texture2D = load("res://art/ui_v1/runtime_source/water-reaction-strip-v01.png")
var splash_texture: Texture2D = load("res://art/ui_v1/runtime_source/loading-splash-v01.png")
var records_texture: Texture2D = preload("res://art/ui_v1/runtime_source/records-screen-v02.png")
var control_kit_texture: Texture2D = load("res://art/ui_v1/runtime/control-kit-alpha-v01.png")
var top_nav_texture: Texture2D = load("res://art/ui_v1/runtime_source/top-nav-strip-v01.png")

func _ready() -> void:
	session = FishingSession.new(); motion = MotionService.new(); save = SaveService.new(); ads = AdMobService.new(); haptics = HapticService.new(); cast_capture = CastCaptureService.new(CastCaptureService.PATH, Callable(motion, "sample"))
	save.load_data(); motion.sensitivity = float(save.data.settings.get("sensitivity", 1.0)); motion.left_handed = bool(save.data.settings.get("left_handed", false)); session.set_location(str(save.data.get("selected_location_id", "pine_lake")), 0.0)
	if not motion.set_profile(save.data.get("motion_profile", {})): motion.begin_calibration()
	ads.initialize(); haptics.set_enabled(bool(save.data.settings.get("haptics", true)))
	view = FishingView.new(); view.controller = self; add_child(view)
	_parse_capture_args()
	if capture_path != "":
		capture_mode = true; _apply_capture_scenario(); loading_active = capture_scenario == "loading"; call_deferred("_capture_after_draw")
	elif not motion.is_calibrated(): view.overlay = "calibration"

func _process(delta: float) -> void:
	ui_time += delta
	if loading_active:
		loading_elapsed += delta
		if loading_elapsed >= 1.0:
			loading_active = false
		view.queue_redraw(); return
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
	if view.overlay in ["settings", "records", "locations", "diagnostics", "capture"]: view.queue_redraw(); return
	var allow_cast := session.state == FishingSession.State.CAST_ARMED or (session.state == FishingSession.State.READY and not haptics.is_motion_guarded())
	var allow_hook := session.state == FishingSession.State.HOOK_WINDOW and not haptics.is_motion_guarded()
	var motion_event := motion.update(delta, allow_cast, allow_hook, session.state == FishingSession.State.REELING)
	if session.state == FishingSession.State.READY and bool(motion_event.get("cast_arm", false)): _arm_cast()
	if session.state == FishingSession.State.CAST_ARMED and bool(motion_event.get("cast_cancel", false)):
		if session.cancel_cast(): print("MOTION_CAST_CANCEL reason=timeout")
	if session.state == FishingSession.State.CAST_ARMED and float(motion_event.get("cast_quality", 0.0)) > 0.0: _cast(float(motion_event.cast_quality), motion_event)
	if session.state == FishingSession.State.HOOK_WINDOW and bool(motion_event.get("hook", false)): _hook(motion_event)
	if session.state == FishingSession.State.REELING:
		session.set_rod_load(float(motion_event.get("fight_load", 0.0)))
		if bool(motion_event.get("fight_lower", false)): print("MOTION_FIGHT lower tension=%.2f elapsed=%.2f" % [session.tension, session.fight_elapsed])
		if bool(motion_event.get("fight_pull", false)): print("MOTION_FIGHT pull progress=%.2f tension=%.2f elapsed=%.2f" % [session.fight_progress, session.tension, session.fight_elapsed])
	session.tick(delta); haptics.set_enabled(bool(save.data.settings.get("haptics", true)))
	if prior_state != session.state:
		if session.state == FishingSession.State.BITE: haptics.cue("bite")
		elif session.state == FishingSession.State.CAUGHT:
			_record_catch_once(); haptics.cue("caught")
			print("MOTION_FIGHT caught elapsed=%.2f progress=%.2f tension=%.2f" % [session.fight_elapsed, session.fight_progress, session.tension])
		elif session.state == FishingSession.State.ESCAPED:
			haptics.cue("hook_miss" if prior_state == FishingSession.State.HOOK_WINDOW else "escaped")
			print("MOTION_FIGHT escaped elapsed=%.2f progress=%.2f tension=%.2f" % [session.fight_elapsed, session.fight_progress, session.tension])
		if session.state in [FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]: motion.reset_fight()
		prior_state = session.state
	if session.state == FishingSession.State.REELING:
		if not haptics.fighting: haptics.start_fight(session.fish)
		haptics.update_fight(delta, session.fish, session.tension)
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
	# Keep weighting deterministic in FishDefinition; physical casts provide a fresh
	# runtime roll so every species at the selected water can be encountered.
	session.set_location(str(save.data.get("selected_location_id", "pine_lake")), randf())
	session.arm_cast()
func _cast(quality: float = 0.78, motion_event: Dictionary = {}) -> void:
	if session.release_cast(quality): print("MOTION_CAST quality=%.2f distance_m=%.1f snap_projection=%.2f axis_match=%.2f polarity=%.2f gyro=%.2f reversal_s=%.3f cock_projection=%.2f" % [session.cast_quality, session.cast_distance_m, float(motion_event.get("snap_projection", 0.0)), float(motion_event.get("snap_axis_match", 0.0)), float(motion_event.get("snap_polarity_match", 0.0)), float(motion_event.get("snap_gyro", 0.0)), float(motion_event.get("reversal_seconds", 0.0)), float(motion_event.get("cock_projection", 0.0))])
func _hook(motion_event: Dictionary = {}) -> void:
	if session.set_hook():
		motion.begin_fight(); haptics.cue("hook"); haptics.start_fight(session.fish); print("MOTION_HOOK state=REELING projection=%.2f alignment=%.2f gyro=%.2f sweep_samples=%d" % [float(motion_event.get("hook_projection", 0.0)), float(motion_event.get("hook_alignment", 0.0)), float(motion_event.get("hook_gyro", 0.0)), int(motion_event.get("hook_sweep_samples", 0))])
func _record_catch_once() -> void:
	if caught_recorded or capture_mode: return
	save.record_catch(session.fish.id, session.catch_length_cm); caught_recorded = true
func _reset_session() -> void:
	session.reset(); caught_recorded = false; haptics.stop(); prior_state = session.state; motion.reset_gesture(); motion.reset_fight()
func _start_motion_recalibration() -> void:
	motion.begin_calibration(); save.data.calibrated = false; save.data.motion_profile = {}; save.save_data(); view.overlay = "calibration"
func _start_cast_capture() -> void:
	var settings: Dictionary = save.data.settings
	var metadata := {"left_handed": bool(settings.get("left_handed", false)), "sensitivity": float(settings.get("sensitivity", 1.0)), "motion_profile": motion.get_profile()}
	if cast_capture.start(metadata):
		haptics.cue("capture_countdown")
		view.overlay = "capture"
func _desktop_fallbacks_enabled() -> bool: return not OS.has_feature("android")
func _toggle_setting(key: String) -> void:
	if key == "left_handed":
		save.data.settings.left_handed = not bool(save.data.settings.get("left_handed", false)); motion.set_left_handed(bool(save.data.settings.left_handed)); save.data.calibrated = false; save.data.motion_profile = {}; save.save_data(); view.overlay = "calibration"; return
	if key == "sensitivity":
		var next := float(save.data.settings.sensitivity) + 0.2
		save.data.settings.sensitivity = 0.6 if next > 1.6 else next; motion.sensitivity = float(save.data.settings.sensitivity)
	else:
		save.data.settings[key] = not bool(save.data.settings[key])
		if key == "haptics": haptics.set_enabled(bool(save.data.settings[key]))
	save.save_data()
func _can_open_records() -> bool: return session.state in [FishingSession.State.READY, FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]
func _select_location(location: String) -> void:
	if session.set_location(location, 0.0): save.data.selected_location_id = location; save.save_data(); view.overlay = ""
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
		"cast_armed": session.arm_cast()
		"line_out": session.arm_cast(); session.release_cast(0.8)
		"bite": session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.BITE; session.bite_elapsed = 0.20
		"hook_window": session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.HOOK_WINDOW; session.bite_elapsed = 0.20
		"reeling", "reeling_low": session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.32; session.rod_load = 0.38; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"reeling_high": session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.88; session.rod_load = 0.88; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"caught": session.state = FishingSession.State.CAUGHT; session.last_reason = "Bluegill landed!"; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"pine_bass_catch": session.set_location("pine_lake", 0.60); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 48.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"pine_catfish_catch": session.set_location("pine_lake", 0.90); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 61.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"cedar_trout_catch": session.set_location("cedar_river", 0.0); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 42.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"cedar_smallmouth_catch": session.set_location("cedar_river", 0.65); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 45.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"cedar_catch": session.set_location("cedar_river", 0.97); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 89.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"records": _seed_capture_records(); view.overlay = "records"
		"records_empty": _clear_capture_records(); view.overlay = "records"
		"records_safe_top": _seed_capture_records(); view.safe_top_override = 91.0; view.overlay = "records"
		"settings": view.overlay = "settings"
		"diagnostics": view.overlay = "diagnostics"
		"top_nav_ready": _capture_top_nav_press("settings", 0.0); view.overlay = ""
		"top_nav_safe_top": _capture_top_nav_press("settings", 91.0); view.overlay = ""
		"settings_button_line_out_safe_top": session.arm_cast(); session.release_cast(0.8); _capture_top_nav_press("settings", 91.0)
		"waters_button_ready_safe_top": _capture_top_nav_press("locations", 91.0)
		"records_button_ready_safe_top": _capture_top_nav_press("records", 91.0)
		"top_nav_active_locked": session.arm_cast(); session.release_cast(0.8); _capture_top_nav_press("records", 91.0); _capture_top_nav_press("locations", 91.0)
		"locations", "locations_pine": session.set_location("pine_lake", 0.0); view.overlay = "locations"
		"locations_cedar": session.set_location("cedar_river", 0.0); view.overlay = "locations"
		"escaped": session.state = FishingSession.State.ESCAPED; session.last_reason = "The line went slack."
		"reduced_motion": save.data.settings.reduced_motion = true
		"reduced_bite": save.data.settings.reduced_motion = true; session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.BITE; session.bite_elapsed = 0.20
		"reduced_reeling_high": save.data.settings.reduced_motion = true; session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.88; session.rod_load = 0.88
		"reduced_catch": save.data.settings.reduced_motion = true; session.state = FishingSession.State.CAUGHT; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"synthetic_reserve": view.synthetic_reserve = 88.0
		_: pass
func _seed_capture_records() -> void:
	var count := 1
	for fish in FishDefinition.all_planned(): save.data.catches[fish.id] = count; save.data.best_cm[fish.id] = fish.min_length_cm + 3.5; count += 1
func _clear_capture_records() -> void:
	for fish in FishDefinition.all_planned(): save.data.catches[fish.id] = 0; save.data.best_cm[fish.id] = 0.0
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
	var top_nav_strip_rect := Rect2(310, 18, 386, 193)
	var records_rect := Rect2(310, 18, 128, 193)
	var locations_rect := Rect2(438, 18, 128, 193)
	var settings_rect := Rect2(566, 18, 130, 193)
	var back_to_fishing_rect := Rect2(420, 18, 264, 64)
	var location_pine_rect := Rect2(42, 240, 636, 356)
	var location_cedar_rect := Rect2(42, 686, 636, 356)
	var settings_footer_close_rect := Rect2(110, 1010, 500, 90)
	var font: Font
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		font = ThemeDB.fallback_font
		_cache_rod_frames()
		_refresh_top_nav_geometry()
		queue_redraw()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_refresh_top_nav_geometry()
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
		top_nav_strip_rect = Rect2(310, chrome_y + 18, 386, 193)
		var button_width := top_nav_strip_rect.size.x / 3.0
		records_rect = Rect2(top_nav_strip_rect.position, Vector2(button_width, top_nav_strip_rect.size.y))
		locations_rect = Rect2(top_nav_strip_rect.position + Vector2(button_width, 0), Vector2(button_width, top_nav_strip_rect.size.y))
		settings_rect = Rect2(top_nav_strip_rect.position + Vector2(button_width * 2.0, 0), Vector2(button_width, top_nav_strip_rect.size.y))
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
			_draw_catch_reveal(s)
		else:
			_draw_lake_motion(s); _draw_top_chrome(s); _draw_glance_hint(s); _draw_fight_status(s)
			if s.state == FishingSession.State.ESCAPED: _draw_escape_card(s)
		if synthetic_reserve > 0.0: draw_rect(Rect2(0, 1280 - synthetic_reserve, 720, synthetic_reserve), Color("ff2f5f", 0.68)); _text("SYNTHETIC OVERLAY STRESS — NOT NATIVE AD", Vector2(66, 1248), 16, Color.WHITE)
		if overlay == "calibration": _draw_calibration()
		elif overlay == "settings": _draw_settings()
		elif overlay == "records": _draw_records()
		elif overlay == "locations": _draw_locations()
		elif overlay == "diagnostics": _draw_diagnostics()
		elif overlay == "capture" or overlay == "capture_saved": _draw_cast_capture()
	func _draw_lake_motion(s: FishingSession) -> void:
		var reduced := bool(controller.save.data.settings.get("reduced_motion", false))
		var wave := 0.0 if reduced else sin(controller.ui_time * 2.2) * 5.0
		var bobber_pos := Vector2(475, 635 + wave)
		var submerged := s.state in [FishingSession.State.BITE, FishingSession.State.HOOK_WINDOW, FishingSession.State.REELING]
		if submerged:
			bobber_pos.y += 44.0 + (0.0 if reduced else sin(controller.ui_time * 9.0) * 3.0)
		var rod_region := 0 if s.state != FishingSession.State.REELING else clampi(int(round(maxf(s.tension, s.rod_load) * 2.0)), 0, 2)
		var rod_tip := _rod_tip_for_frame(rod_region)
		# Draw the external line behind the rod; the rod atlas owns handle-to-terminal-guide pixels.
		draw_line(rod_tip, bobber_pos, Color("f4e6bf", 0.9), 2.4)
		if rod_region < rod_frames.size(): draw_texture_rect(rod_frames[rod_region], ROD_DESTINATION, false)
		if not submerged and controller.bobber_texture:
			draw_texture_rect(controller.bobber_texture, Rect2(bobber_pos - Vector2(21, 25), Vector2(42, 50)), false)
		elif submerged:
			# The body is below the waterline: leave only a dark tip and the line contact visible.
			draw_circle(bobber_pos + Vector2(0, 5), 8, Color(0.015, 0.09, 0.12, 0.88))
			draw_circle(bobber_pos + Vector2(0, 1), 3, Color("9b3a32"))
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
	func _rod_tip_for_frame(frame: int) -> Vector2:
		var source_tip: Vector2 = ROD_TIP_ANCHORS[clampi(frame, 0, ROD_TIP_ANCHORS.size() - 1)]
		return ROD_DESTINATION.position + Vector2(
			source_tip.x / ROD_FRAME_SIZE.x * ROD_DESTINATION.size.x,
			source_tip.y / ROD_FRAME_SIZE.y * ROD_DESTINATION.size.y
		)
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
		_refresh_top_nav_geometry()
		draw_style_box(_panel_style(Color(0.03, 0.13, 0.18, 0.76), Color("74b7a8")), Rect2(24, chrome_y + 12, 672, 204))
		_text("CAST & CRANK", Vector2(46, chrome_y + 64), 29, Color("fff4d1"))
		_text("%s  •  MOTION FISHING" % s.location_id.replace("_", " ").to_upper(), Vector2(48, chrome_y + 96), 15, Color("b9e2d3"))
		if controller.top_nav_texture: draw_texture_rect(controller.top_nav_texture, top_nav_strip_rect, false)
		var records_available: bool = controller._can_open_records()
		_draw_top_nav_label(records_rect, "RECORDS", records_available)
		_draw_top_nav_label(locations_rect, "WATERS", records_available)
		_draw_top_nav_label(settings_rect, "SETTINGS", true)
	func _draw_top_nav_label(rect: Rect2, label: String, available: bool) -> void:
		if not available:
			draw_rect(rect, Color(0.01, 0.05, 0.08, 0.62))
			_centered_text("LOCKED", rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 42), 12, Color("a4bbb5"))
		_centered_text(label, rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 18), 15, Color("fff3ce") if available else Color("b4c4bd"))
	func _draw_glance_hint(s: FishingSession) -> void:
		var copy := "COCK LEFT, THEN SNAP RIGHT" if controller.motion.left_handed else "COCK RIGHT, THEN SNAP LEFT"
		match s.state:
			FishingSession.State.CAST_ARMED: copy = "SNAP RIGHT" if controller.motion.left_handed else "SNAP LEFT"
			FishingSession.State.LINE_OUT: copy = "LINE OUT  %.0f m" % s.cast_distance_m
			FishingSession.State.BITE: copy = "FISH ON — WAIT FOR THE PULSES"
			FishingSession.State.HOOK_WINDOW: copy = "BITE — PULL LEFT" if controller.motion.left_handed else "BITE — PULL RIGHT"
			FishingSession.State.REELING: copy = ("TILT RIGHT TO EASE" if controller.motion.left_handed else "TILT LEFT TO EASE") if s.rod_load >= 0.55 or s.tension >= 0.65 else ("TILT LEFT TO PULL" if controller.motion.left_handed else "TILT RIGHT TO PULL")
			FishingSession.State.CAUGHT: copy = "%s LANDED" % s.fish.display_name.to_upper()
			FishingSession.State.ESCAPED: copy = "LINE WENT SLACK"
		var hint_y := _virtual_safe_top() + 230.0
		draw_style_box(_panel_style(Color(0.02, 0.13, 0.18, 0.78), Color("e1ca77")), Rect2(78, hint_y, 564, 58)); _text(copy, Vector2(118, hint_y + 38), 20, Color("fff7dc"))
	func _draw_fight_status(s: FishingSession) -> void:
		if s.state != FishingSession.State.REELING: return
		draw_style_box(_panel_style(Color(0.03, 0.14, 0.20, 0.74), Color("79b9ad", 0.7)), Rect2(170, 1084, 380, 78)); _text("LANDING", Vector2(190, 1111), 14, Color("d9efe3")); draw_rect(Rect2(275, 1102, 252, 7), Color("153947")); draw_rect(Rect2(275, 1102, 252 * s.fight_progress, 7), Color("70d5ad")); _text("TENSION", Vector2(190, 1144), 14, Color("d9efe3")); draw_rect(Rect2(275, 1135, 252, 7), Color("321b28")); draw_rect(Rect2(275, 1135, 252 * s.tension, 7), Color("ed695e") if s.tension >= 0.65 else Color("e1c46e"))
	func _draw_catch_reveal(s: FishingSession) -> void:
		var reduced := bool(controller.save.data.settings.get("reduced_motion", false))
		var entry := 0.0 if reduced else sin(controller.ui_time * 2.1) * 9.0
		var fish_rect := Rect2(86, 266 + entry, 548, 355)
		_draw_fish_atlas_contained(s.fish.id, fish_rect)
		for i in range(6):
			var bob := 0.0 if reduced else sin(controller.ui_time * 3.3 + i) * 8.0
			draw_circle(Vector2(134 + i * 88, 618 + bob), 4 + (i % 3), Color("d6f7ef", 0.62))
		var length := s.catch_length_cm if s.catch_length_cm > 0.0 else lerpf(s.fish.min_length_cm, s.fish.max_length_cm, s.cast_quality)
		var best := float(controller.save.data.best_cm.get(s.fish.id, 0.0))
		var new_pb := length >= best
		draw_style_box(_panel_style(Color(0.02, 0.16, 0.19, 0.88), Color("e4c86d")), Rect2(70, 724, 580, 270))
		_text(s.fish.display_name.to_upper(), Vector2(112, 782), 34, Color("fff1c4"))
		_text("%.1f cm  •  %.0f m cast" % [length, s.cast_distance_m], Vector2(150, 828), 22, Color("d7eee4"))
		_text("NEW PB  •  %.1f cm" % maxf(length, best) if new_pb else "PB  •  %.1f cm" % best, Vector2(185, 879), 23, Color("f3d979") if new_pb else Color("b9e2d3"))
		_text("TAP TO CONTINUE", Vector2(232, 954), 20, Color("fff1c4"))
	func _draw_escape_card(s: FishingSession) -> void:
		draw_style_box(_control_style("plaque_pressed"), Rect2(84, 650, 552, 238)); _text("FISH GOT AWAY", Vector2(203, 722), 31, Color("fff2d5")); _text(s.last_reason, Vector2(132, 770), 18, Color("ffd5c2")); _text("Ease forward when warning pulses speed up.", Vector2(115, 815), 17, Color("ffe4bc")); _text("TAP TO TRY AGAIN", Vector2(207, 855), 20, Color("fff2d5"))
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
			copy = "Cock %s, then snap %s when ready." % ["left" if controller.motion.left_handed else "right", "right" if controller.motion.left_handed else "left"]
		_text(copy, Vector2(90, 510), 21, Color("173a48"))
		_text("Calibration starts automatically — no buttons.", Vector2(112, 580), 18, Color("416b72"))
	func _draw_settings() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.88)); draw_style_box(_control_style("modal"), Rect2(55, 150, 610, 960)); draw_style_box(_control_style("plaque_normal"), Rect2(168, 168, 384, 78)); _text("SETTINGS", Vector2(243, 222), 34, Color("fff4d1")); var settings: Dictionary = controller.save.data.settings
		var rows := ["Sensitivity: %.1f" % float(settings.sensitivity), "Haptics: %s" % ("ON" if settings.haptics else "OFF"), "Audio: %s" % ("ON" if settings.audio else "OFF"), "Reduced motion: %s" % ("ON" if settings.reduced_motion else "OFF"), "Handedness: %s" % ("LEFT" if settings.left_handed else "RIGHT")]
		for index in range(rows.size()): draw_style_box(_control_style("row_selected" if index == 4 else "row_normal"), Rect2(98, 270 + index * 70, 524, 60)); _text(rows[index], Vector2(126, 310 + index * 70), 22, Color("fff5d8"))
		for index in range(4): draw_style_box(_control_style("plaque_normal"), Rect2(110, 638 + index * 70, 500, 58))
		draw_style_box(_control_style("plaque_normal"), settings_footer_close_rect); _text("RECALIBRATE MOTION", Vector2(193, 678), 20, Color("fff4d1")); _text("RECORD 10 CASTS", Vector2(223, 748), 20, Color("fff4d1")); _text("MOTION DIAGNOSTICS", Vector2(202, 818), 20, Color("fff4d1")); _text("PICK LOCATION", Vector2(232, 888), 20, Color("fff4d1")); _text("TAP SETTINGS TO CLOSE", Vector2(228, 1065), 18, Color("fff4d1"))
	func _draw_cast_capture() -> void:
		var data: Dictionary = controller.cast_capture.status()
		var done := int(data.get("cast_index", 0))
		var phase := str(data.get("phase", "idle"))
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.90)); draw_style_box(_panel_style(Color("eff3dc"), Color("fff6c5")), Rect2(54, 330, 612, 490)); _text("CAST TUNING CAPTURE", Vector2(142, 412), 30, Color("173a48"))
		if phase == "saved":
			_text("10 CASTS SAVED", Vector2(210, 505), 29, Color("1e665d")); _text("Raw trace is stored only for this", Vector2(155, 558), 20, Color("416b72")); _text("explicit capture. Tap title to return.", Vector2(135, 592), 20, Color("416b72")); return
		var copy := "GET READY — WINDOWS BEGIN SOON"
		if phase == "active": copy = "CAST NOW — COCK, THEN SNAP"
		elif phase == "rest": copy = "REST — NEXT WINDOW WILL VIBRATE"
		_text("CAST %d OF %d" % [min(done + 1, CastCaptureService.CAST_COUNT), CastCaptureService.CAST_COUNT], Vector2(248, 488), 24, Color("2c6876")); _text(copy, Vector2(118, 554), 22, Color("173a48")); _text("No taps needed. Gameplay is paused.", Vector2(170, 624), 19, Color("416b72")); _text("Each active window is haptic-cued.", Vector2(168, 658), 19, Color("416b72"))
	func _draw_locations() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.01, 0.06, 0.09, 0.92))
		var safe_top := _virtual_safe_top()
		_draw_back_to_fishing(safe_top)
		_text("CHOOSE WATER", Vector2(46, safe_top + 124), 34, Color("fff4d1"))
		_refresh_location_card_rects(safe_top)
		_draw_location_card("PINE LAKE", "BLUEGILL  •  BASS  •  CATFISH", controller.pine_lake_texture, location_pine_rect, controller.session.location_id == "pine_lake")
		_draw_location_card("CEDAR RIVER", "TROUT  •  SMALLMOUTH  •  PIKE", controller.cedar_river_texture, location_cedar_rect, controller.session.location_id == "cedar_river")
		_text("Tap a water to fish it", Vector2(241, minf(1210.0, location_pine_rect.position.y + 924.0)), 18, Color("d9e9d9"))
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
		location_pine_rect = Rect2(42, card_top, 636, 356)
		location_cedar_rect = Rect2(42, card_top + 426.0, 636, 356)
	func _draw_location_card(title: String, species: String, texture: Texture2D, rect: Rect2, selected: bool) -> void:
		if texture: draw_texture_rect_region(texture, rect, Rect2(0, 335, 941, 940))
		else: draw_rect(rect, Color("1b566a"))
		draw_rect(rect, Color(0.01, 0.10, 0.13, 0.28))
		if selected: draw_style_box(_panel_style(Color(0.0, 0.0, 0.0, 0.0), Color("f0d579")), rect.grow(-4.0))
		draw_style_box(_control_style("row_selected" if selected else "row_normal"), Rect2(rect.position + Vector2(18, rect.size.y - 112), Vector2(rect.size.x - 36, 94)))
		_text(title, rect.position + Vector2(38, rect.size.y - 67), 29, Color("fff2c9")); _text(species, rect.position + Vector2(40, rect.size.y - 32), 15, Color("d1eadf"))
		if selected:
			draw_style_box(_panel_style(Color("123942", 0.92), Color("f0d579")), Rect2(rect.position + Vector2(rect.size.x - 146, 18), Vector2(120, 42)))
			_text("SELECTED", rect.position + Vector2(rect.size.x - 129, 47), 15, Color("fff2c9"))
	func _draw_diagnostics() -> void:
		var data: Dictionary = controller.motion.get_diagnostics(); var reasons: Dictionary = data.reasons
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.88)); draw_style_box(_panel_style(Color("eaf2dc"), Color("fff6c5")), Rect2(55, 300, 610, 590)); _text("MOTION DIAGNOSTICS", Vector2(150, 390), 30, Color("173a48")); _text("Cock attempts: %d" % int(data.cock_attempts), Vector2(125, 465), 21, Color("173a48")); _text("Completed casts: %d" % int(data.completed_casts), Vector2(125, 510), 21, Color("173a48")); _text("Hook attempts: %d" % int(data.hook_attempts), Vector2(125, 555), 21, Color("173a48")); _text("Fails L/A/P/G/T: %d / %d / %d / %d / %d" % [int(reasons.linear), int(reasons.axis), int(reasons.polarity), int(reasons.gyro), int(reasons.timeout)], Vector2(82, 620), 18, Color("416b72")); _text("Derived counts only. Raw traces exist only after", Vector2(92, 694), 17, Color("416b72")); _text("an explicit RECORD 10 CASTS session.", Vector2(132, 722), 17, Color("416b72")); _text("Tap title to return", Vector2(245, 810), 18, Color("416b72"))
	func _draw_records() -> void:
		if controller.records_texture: draw_texture_rect(controller.records_texture, Rect2(0, 0, 720, 1280), false)
		var safe_top := _virtual_safe_top()
		# The cohesive journal master owns all static framing and CATCH RECORDS title.
		# Only this dynamic safe-area back control and the record values draw at runtime.
		_draw_records_back_to_fishing(safe_top)
		# The journal master owns all six fish and card art. Only dynamic native text is
		# overlaid on its baked wood plaques, in the visual's row-major reading order.
		var fish_ids := ["bluegill", "largemouth_bass", "channel_catfish", "rainbow_trout", "smallmouth_bass", "northern_pike"]
		var name_centers := [Vector2(210, 413), Vector2(510, 413), Vector2(210, 728), Vector2(510, 728), Vector2(210, 1043), Vector2(510, 1043)]
		var stat_centers := [Vector2(210, 476), Vector2(510, 476), Vector2(210, 790), Vector2(510, 790), Vector2(210, 1105), Vector2(510, 1105)]
		for index in range(fish_ids.size()):
			var fish := _fish_definition(fish_ids[index])
			var count := int(controller.save.data.catches.get(fish.id, 0))
			var best := float(controller.save.data.best_cm.get(fish.id, 0.0))
			_centered_text(fish.display_name.to_upper(), name_centers[index], 17, Color("fff2c8"))
			_centered_text("%d caught  •  %s" % [count, ("%.1f cm" % best) if best > 0.0 else "—"], stat_centers[index], 16, Color("fff2c8"))
	func _fish_definition(fish_id: String) -> FishDefinition:
		for fish in FishDefinition.all_planned():
			if fish.id == fish_id: return fish
		return FishDefinition.bluegill()
	func _draw_fish_atlas_contained(fish_id: String, destination: Rect2) -> void:
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
		draw_texture_rect_region(atlas, contained, source)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			if bool(event.pressed): _handle_press(event.position * Vector2(720.0 / size.x, 1280.0 / size.y))
	func _handle_press(pos: Vector2) -> void:
		_refresh_top_nav_geometry()
		if overlay == "calibration" or overlay == "capture": return
		if overlay == "capture_saved":
			if pos.y < 270: overlay = "settings"
			return
		if overlay == "records":
			_refresh_records_back_to_fishing_rect(_virtual_safe_top())
			if back_to_fishing_rect.has_point(pos): overlay = ""
			return
		if overlay in ["locations", "diagnostics"]:
			if overlay == "locations":
				var location_safe_top := _virtual_safe_top()
				_refresh_back_to_fishing_rect(location_safe_top); _refresh_location_card_rects(location_safe_top)
				if back_to_fishing_rect.has_point(pos): overlay = ""
				elif location_pine_rect.has_point(pos): controller._select_location("pine_lake")
				elif location_cedar_rect.has_point(pos): controller._select_location("cedar_river")
			elif pos.y < 220: overlay = "settings"
			return
		if overlay == "settings":
			if settings_footer_close_rect.has_point(pos) or pos.y < 270: overlay = ""
			elif pos.y < 360: controller._toggle_setting("sensitivity")
			elif pos.y < 430: controller._toggle_setting("haptics")
			elif pos.y < 500: controller._toggle_setting("audio")
			elif pos.y < 570: controller._toggle_setting("reduced_motion")
			elif pos.y < 640: controller._toggle_setting("left_handed")
			elif pos.y < 720: controller._start_motion_recalibration()
			elif pos.y < 790: controller._start_cast_capture()
			elif pos.y < 860: overlay = "diagnostics"
			elif pos.y < 930: overlay = "locations"
			return
		if settings_rect.has_point(pos): overlay = "settings"; return
		if records_rect.has_point(pos) and controller._can_open_records(): overlay = "records"; return
		if locations_rect.has_point(pos) and controller._can_open_records(): overlay = "locations"; return
		if controller.session.state in [FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]: controller._reset_session()
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
