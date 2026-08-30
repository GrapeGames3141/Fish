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

var lake_texture: Texture2D = load("res://art/ui_v1/runtime_source/pine-lake-clean-v01.png")
var rod_texture: Texture2D = load("res://art/ui_v1/runtime_source/rod-bend-strip-v01.png")
var bobber_texture: Texture2D = load("res://art/ui_v1/runtime_source/bobber-v01.png")
var reaction_texture: Texture2D = load("res://art/ui_v1/runtime_source/water-reaction-strip-v01.png")
var catch_frame_texture: Texture2D = load("res://art/ui_v1/runtime_source/catch-frame-clean-v01.png")
var bluegill_texture: Texture2D = load("res://art/ui_v1/runtime_source/bluegill-v01.png")
var splash_texture: Texture2D = load("res://art/ui_v1/runtime_source/loading-splash-v01.png")
var records_texture: Texture2D = load("res://art/ui_v1/runtime_source/records-screen-v01.png")

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
		if loading_elapsed >= 1.0: loading_active = false
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
	var motion_event := motion.update(delta, session.state in [FishingSession.State.READY, FishingSession.State.CAST_ARMED], session.state == FishingSession.State.HOOK_WINDOW, session.state == FishingSession.State.REELING)
	if session.state == FishingSession.State.READY and bool(motion_event.get("cast_arm", false)): _arm_cast()
	if session.state == FishingSession.State.CAST_ARMED and float(motion_event.get("cast_quality", 0.0)) > 0.0: _cast(float(motion_event.cast_quality))
	if session.state == FishingSession.State.HOOK_WINDOW and bool(motion_event.get("hook", false)): _hook()
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
	if session.arm_cast(): haptics.cue("cock")
func _cast(quality: float = 0.78) -> void:
	if session.release_cast(quality): print("MOTION_CAST quality=%.2f distance_m=%.1f" % [session.cast_quality, session.cast_distance_m])
func _hook() -> void:
	if session.set_hook():
		motion.begin_fight(); haptics.cue("hook"); haptics.start_fight(session.fish); print("MOTION_HOOK state=REELING")
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
func _can_open_journal() -> bool: return session.state in [FishingSession.State.READY, FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]
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
		"bite": session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.HOOK_WINDOW; session.bite_elapsed = 0.35
		"reeling": session.state = FishingSession.State.REELING; session.fight_progress = 0.48; session.tension = 0.63; session.rod_load = 0.55; session.cast_quality = 0.86; session.cast_distance_m = 35.5
		"caught": session.state = FishingSession.State.CAUGHT; session.last_reason = "Bluegill landed!"; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"cedar_catch": session.set_location("cedar_river", 0.97); session.state = FishingSession.State.CAUGHT; session.catch_length_cm = 89.0; session.last_reason = "%s landed!" % session.fish.display_name; session.cast_quality = 0.88; session.cast_distance_m = 36.2; caught_recorded = true
		"records": _seed_capture_records(); view.overlay = "records"
		"settings": view.overlay = "settings"
		"diagnostics": view.overlay = "diagnostics"
		"locations": view.overlay = "locations"
		"synthetic_reserve": view.synthetic_reserve = 88.0
		_: pass
func _seed_capture_records() -> void:
	var count := 1
	for fish in FishDefinition.all_planned(): save.data.catches[fish.id] = count; save.data.best_cm[fish.id] = fish.min_length_cm + 3.5; count += 1
func _capture_after_draw() -> void:
	await get_tree().process_frame; await get_tree().process_frame
	var image := get_viewport().get_texture().get_image(); var error := image.save_png(capture_path)
	print("SCREENSHOT_CAPTURED path=%s error=%s" % [capture_path, error]); get_tree().quit(0 if error == OK else 1)

class FishingView extends Control:
	# Source-local terminal guide contacts for the three 512×1024 rod atlas frames.
	const ROD_DESTINATION := Rect2(-85, 545, 435, 870)
	const ROD_FRAME_SIZE := Vector2(512, 1024)
	const ROD_TIP_ANCHORS := [Vector2(467, 15), Vector2(461, 36), Vector2(412.5, 94)]
	var controller: Node
	var overlay := ""
	var synthetic_reserve := 0.0
	var settings_rect := Rect2(618, 30, 48, 48)
	var journal_rect := Rect2(556, 30, 48, 48)
	var font: Font
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_STOP; font = ThemeDB.fallback_font; queue_redraw()
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
		if controller.lake_texture: draw_texture_rect(controller.lake_texture, Rect2(0, 0, 720, 1280), false)
		else: draw_rect(Rect2(0, 0, 720, 1280), Color("1c617d"))
		_draw_lake_motion(s); _draw_top_chrome(s); _draw_glance_hint(s); _draw_fight_status(s)
		if s.state == FishingSession.State.CAUGHT: _draw_catch_reveal(s)
		elif s.state == FishingSession.State.ESCAPED: _draw_escape_card(s)
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
		if controller.rod_texture: draw_texture_rect_region(controller.rod_texture, ROD_DESTINATION, Rect2(rod_region * 512, 0, 512, 1024))
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
	func _draw_top_chrome(s: FishingSession) -> void:
		draw_style_box(_panel_style(Color(0.03, 0.13, 0.18, 0.72), Color("74b7a8")), Rect2(24, 22, 672, 100)); _text("CAST & CRANK", Vector2(46, 66), 30, Color("fff4d1")); _text("%s  •  %s" % [s.location_id.replace("_", " ").to_upper(), s.fish.display_name.to_upper()], Vector2(48, 98), 16, Color("b9e2d3"))
		draw_circle(Vector2(580, 54), 20, Color("d9bf72")); _text("≡", Vector2(571, 63), 21, Color("173a48")); draw_circle(Vector2(644, 54), 20, Color("d9bf72")); _text("⚙", Vector2(633, 64), 20, Color("173a48"))
	func _draw_glance_hint(s: FishingSession) -> void:
		var copy := "COCK LEFT, THEN SNAP RIGHT" if controller.motion.left_handed else "COCK RIGHT, THEN SNAP LEFT"
		match s.state:
			FishingSession.State.CAST_ARMED: copy = "SNAP RIGHT" if controller.motion.left_handed else "SNAP LEFT"
			FishingSession.State.LINE_OUT: copy = "LINE OUT  %.0f m" % s.cast_distance_m
			FishingSession.State.HOOK_WINDOW: copy = "BITE — PULL LEFT" if controller.motion.left_handed else "BITE — PULL RIGHT"
			FishingSession.State.REELING: copy = ("TILT RIGHT TO EASE" if controller.motion.left_handed else "TILT LEFT TO EASE") if s.rod_load >= 0.55 or s.tension >= 0.65 else ("TILT LEFT TO PULL" if controller.motion.left_handed else "TILT RIGHT TO PULL")
			FishingSession.State.CAUGHT: copy = "%s LANDED" % s.fish.display_name.to_upper()
			FishingSession.State.ESCAPED: copy = "LINE WENT SLACK"
		draw_style_box(_panel_style(Color(0.02, 0.13, 0.18, 0.78), Color("e1ca77")), Rect2(78, 147, 564, 58)); _text(copy, Vector2(118, 185), 20, Color("fff7dc"))
	func _draw_fight_status(s: FishingSession) -> void:
		if s.state != FishingSession.State.REELING: return
		draw_style_box(_panel_style(Color(0.03, 0.14, 0.20, 0.84), Color("79b9ad")), Rect2(74, 1032, 572, 128)); _text("FIGHT", Vector2(102, 1065), 17, Color("d9efe3")); draw_rect(Rect2(102, 1078, 516, 10), Color("153947")); draw_rect(Rect2(102, 1078, 516 * s.fight_progress, 10), Color("70d5ad")); _text("TENSION", Vector2(102, 1122), 17, Color("d9efe3")); draw_rect(Rect2(102, 1134, 516, 10), Color("321b28")); draw_rect(Rect2(102, 1134, 516 * s.tension, 10), Color("ed695e") if s.tension >= 0.65 else Color("e1c46e"))
	func _draw_catch_reveal(s: FishingSession) -> void:
		if controller.catch_frame_texture: draw_texture_rect(controller.catch_frame_texture, Rect2(0, 0, 720, 1280), false)
		var reduced := bool(controller.save.data.settings.get("reduced_motion", false)); var entry := 0.0 if reduced else sin(controller.ui_time * 2.1) * 9.0
		if s.fish.id == "bluegill" and controller.bluegill_texture: draw_texture_rect(controller.bluegill_texture, Rect2(182, 342 + entry, 350, 233), false)
		elif s.fish.id != "bluegill":
			var tint := Color("789db1") if s.location_id == "cedar_river" else Color("6f8f68")
			draw_colored_polygon(PackedVector2Array([Vector2(185, 455 + entry), Vector2(246, 408 + entry), Vector2(408, 402 + entry), Vector2(488, 455 + entry), Vector2(408, 508 + entry), Vector2(246, 502 + entry)]), tint); draw_colored_polygon(PackedVector2Array([Vector2(470, 455 + entry), Vector2(565, 392 + entry), Vector2(565, 518 + entry)]), tint.darkened(0.10)); draw_circle(Vector2(258, 442 + entry), 7, Color("fff4c9"))
		for i in range(4): draw_circle(Vector2(210 + i * 94, 328 + (0 if reduced else sin(controller.ui_time * 4.0 + i) * 7)), 5, Color("d6f7ef", 0.75))
		draw_style_box(_panel_style(Color(0.03, 0.15, 0.19, 0.88), Color("e4c86d")), Rect2(74, 712, 572, 262)); _text(s.fish.display_name.to_upper(), Vector2(150, 770), 34, Color("fff1c4")); var length := s.catch_length_cm if s.catch_length_cm > 0.0 else lerpf(s.fish.min_length_cm, s.fish.max_length_cm, s.cast_quality); _text("%.1f cm  •  %.0f m cast" % [length, s.cast_distance_m], Vector2(218, 816), 22, Color("d7eee4")); _text("PB  %.1f cm" % maxf(length, float(controller.save.data.best_cm.get(s.fish.id, 0.0))), Vector2(264, 864), 24, Color("b9e2d3")); _text("TAP TO CONTINUE", Vector2(232, 932), 20, Color("fff1c4"))
	func _draw_escape_card(s: FishingSession) -> void:
		draw_style_box(_panel_style(Color(0.19, 0.07, 0.10, 0.92), Color("e58970")), Rect2(84, 662, 552, 210)); _text("THE LINE WENT SLACK", Vector2(139, 742), 29, Color("fff2d5")); _text(s.last_reason, Vector2(152, 790), 18, Color("ffd5c2")); _text("TAP TO TRY AGAIN", Vector2(207, 838), 20, Color("fff2d5"))
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
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.88)); draw_style_box(_panel_style(Color("eaf2dc"), Color("fff6c5")), Rect2(55, 150, 610, 960)); _text("SETTINGS", Vector2(243, 240), 34, Color("173a48")); var settings: Dictionary = controller.save.data.settings
		_text("Sensitivity: %.1f  (tap row)" % float(settings.sensitivity), Vector2(120, 330), 23, Color("173a48")); _text("Haptics: %s" % ("ON" if settings.haptics else "OFF"), Vector2(120, 400), 23, Color("173a48")); _text("Audio: %s" % ("ON" if settings.audio else "OFF"), Vector2(120, 470), 23, Color("173a48")); _text("Reduced motion: %s" % ("ON" if settings.reduced_motion else "OFF"), Vector2(120, 540), 23, Color("173a48")); _text("Handedness: %s" % ("LEFT" if settings.left_handed else "RIGHT"), Vector2(120, 610), 23, Color("173a48"))
		draw_style_box(_panel_style(Color("dce7d0"), Color("8ab5a9")), Rect2(110, 650, 500, 58)); _text("RECALIBRATE MOTION", Vector2(193, 689), 20, Color("173a48")); _text("RECORD 10 CASTS", Vector2(223, 758), 20, Color("173a48")); _text("MOTION DIAGNOSTICS", Vector2(202, 827), 20, Color("173a48")); _text("PICK LOCATION", Vector2(232, 896), 20, Color("173a48")); _text("Tap title to close", Vector2(247, 1010), 18, Color("416b72"))
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
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.88)); draw_style_box(_panel_style(Color("eaf2dc"), Color("fff6c5")), Rect2(55, 310, 610, 480)); _text("CHOOSE WATER", Vector2(190, 395), 32, Color("173a48")); _text("PINE LAKE", Vector2(240, 495), 27, Color("173a48")); _text("Bluegill • Bass • Catfish", Vector2(185, 530), 17, Color("416b72")); _text("CEDAR RIVER", Vector2(220, 630), 27, Color("173a48")); _text("Trout • Smallmouth • Pike", Vector2(180, 665), 17, Color("416b72")); _text("Tap title to return", Vector2(245, 744), 18, Color("416b72"))
	func _draw_diagnostics() -> void:
		var data: Dictionary = controller.motion.get_diagnostics(); var reasons: Dictionary = data.reasons
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.08, 0.11, 0.88)); draw_style_box(_panel_style(Color("eaf2dc"), Color("fff6c5")), Rect2(55, 300, 610, 590)); _text("MOTION DIAGNOSTICS", Vector2(150, 390), 30, Color("173a48")); _text("Cock attempts: %d" % int(data.cock_attempts), Vector2(125, 465), 21, Color("173a48")); _text("Completed casts: %d" % int(data.completed_casts), Vector2(125, 510), 21, Color("173a48")); _text("Hook attempts: %d" % int(data.hook_attempts), Vector2(125, 555), 21, Color("173a48")); _text("Fails L/A/P/G/T: %d / %d / %d / %d / %d" % [int(reasons.linear), int(reasons.axis), int(reasons.polarity), int(reasons.gyro), int(reasons.timeout)], Vector2(82, 620), 18, Color("416b72")); _text("Derived counts only. Raw traces exist only after", Vector2(92, 694), 17, Color("416b72")); _text("an explicit RECORD 10 CASTS session.", Vector2(132, 722), 17, Color("416b72")); _text("Tap title to return", Vector2(245, 810), 18, Color("416b72"))
	func _draw_records() -> void:
		if controller.records_texture: draw_texture_rect(controller.records_texture, Rect2(0, 0, 720, 1280), false)
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.09, 0.12, 0.12))
		_text("PINE LAKE JOURNAL", Vector2(160, 230), 30, Color("fff2c8"))
		_text("TAP TOP LEFT TO RETURN", Vector2(206, 262), 15, Color("163c46"))
		var fish_list := FishDefinition.all_planned()
		var card_x := [56.0, 372.0]
		# Each plaque belongs beneath its card's fish, not at a uniform row cadence.
		var card_y := [335.0, 665.0, 995.0]
		for index in range(fish_list.size()):
			var fish = fish_list[index]
			var column := index % 2
			var row: int = index >> 1
			var plaque := Rect2(card_x[column], card_y[row], 292, 58)
			var count := int(controller.save.data.catches.get(fish.id, 0))
			var best := float(controller.save.data.best_cm.get(fish.id, 0.0))
			draw_style_box(_panel_style(Color(0.015, 0.11, 0.14, 0.84), Color("a98a48")), plaque)
			_text(fish.display_name.to_upper(), plaque.position + Vector2(13, 24), 16, Color("fff1c8"))
			_text("%d caught  •  %.1f cm" % [count, best], plaque.position + Vector2(13, 47), 16, Color("caeadb"))
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			if bool(event.pressed): _handle_press(event.position * Vector2(720.0 / size.x, 1280.0 / size.y))
	func _handle_press(pos: Vector2) -> void:
		if overlay == "calibration" or overlay == "capture": return
		if overlay == "capture_saved":
			if pos.y < 270: overlay = "settings"
			return
		if overlay == "records":
			if pos.y < 130: overlay = ""
			return
		if overlay in ["locations", "diagnostics"]:
			if overlay == "locations" and pos.y >= 430 and pos.y < 570: controller._select_location("pine_lake")
			elif overlay == "locations" and pos.y >= 570 and pos.y < 710: controller._select_location("cedar_river")
			elif pos.y < 430: overlay = "settings"
			return
		if overlay == "settings":
			if pos.y < 270: overlay = ""
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
		if settings_rect.has_point(pos) and controller._can_open_journal(): overlay = "settings"; return
		if journal_rect.has_point(pos) and controller._can_open_journal(): overlay = "records"; return
		if controller.session.state in [FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]: controller._reset_session()
	func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new(); box.bg_color = background; box.border_color = border; box.set_border_width_all(3); box.set_corner_radius_all(20); return box
	func _text(value: String, pos: Vector2, font_size: int, color: Color) -> void: draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
