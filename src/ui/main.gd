extends Node

const FishingSession = preload("res://src/domain/fishing_session.gd")
const MotionService = preload("res://src/services/motion_service.gd")
const SaveService = preload("res://src/services/save_service.gd")
const AdMobService = preload("res://src/services/admob_service.gd")

var session: FishingSession
var motion: MotionService
var save: SaveService
var ads: AdMobService
var view: FishingView
var calibration_step := 0
var cast_hold := false
var last_reel_angle := 0.0
var has_reel_angle := false
var capture_path := ""
var capture_scenario := "ready"

func _ready() -> void:
	session = FishingSession.new()
	motion = MotionService.new()
	save = SaveService.new()
	ads = AdMobService.new()
	save.load_data()
	motion.sensitivity = float(save.data.settings.get("sensitivity", 1.0))
	ads.initialize()
	view = FishingView.new()
	view.controller = self
	add_child(view)
	_parse_capture_args()
	if not bool(save.data.get("calibrated", false)):
		view.overlay = "calibration"
	if capture_path != "":
		_apply_capture_scenario()
		call_deferred("_capture_after_draw")

func _process(delta: float) -> void:
	if view.overlay == "settings" or view.overlay == "calibration":
		view.queue_redraw()
		return
	if session.state == FishingSession.State.CAST_ARMED:
		var quality := motion.detect_cast()
		if quality > 0.0:
			_cast(quality)
	elif session.state == FishingSession.State.HOOK_WINDOW and motion.detect_hook():
		_hook()
	session.tick(delta)
	if session.state == FishingSession.State.BITE:
		_bite_feedback()
	view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cast_fallback"):
		if session.state == FishingSession.State.READY:
			_arm_cast()
		elif session.state == FishingSession.State.CAST_ARMED:
			_cast(0.8)
	if event.is_action_pressed("hook_fallback"):
		_hook()
	if event.is_action_pressed("reel_fallback") and session.state == FishingSession.State.REELING:
		session.add_reel_turns(0.24, 0.1)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		view.overlay = "" if view.overlay == "settings" else "settings"

func _arm_cast() -> void:
	if session.arm_cast():
		cast_hold = true

func _cast(quality: float = 0.78) -> void:
	if session.release_cast(quality):
		cast_hold = false

func _hook() -> void:
	if session.set_hook():
		has_reel_angle = false
		if bool(save.data.settings.get("haptics", true)):
			Input.vibrate_handheld(55, 0.6)

func _bite_feedback() -> void:
	if bool(save.data.settings.get("haptics", true)):
		Input.vibrate_handheld(70, 0.85)
		get_tree().create_timer(0.17).timeout.connect(func(): Input.vibrate_handheld(105, 0.95))

func _finish_catch() -> void:
	if session.state == FishingSession.State.CAUGHT:
		var length := 19.0 + session.cast_quality * 7.5
		save.record_bluegill(length)

func _reset_session() -> void:
	session.reset()
	has_reel_angle = false

func _calibrate_or_bypass() -> void:
	calibration_step += 1
	motion.calibrate()
	if calibration_step >= 2:
		save.data.calibrated = true
		save.save_data()
		view.overlay = ""

func _toggle_setting(key: String) -> void:
	if key == "sensitivity":
		var next := float(save.data.settings.sensitivity) + 0.2
		save.data.settings.sensitivity = 0.6 if next > 1.6 else next
		motion.sensitivity = float(save.data.settings.sensitivity)
	else:
		save.data.settings[key] = not bool(save.data.settings[key])
	save.save_data()

func _parse_capture_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-scenario="):
			capture_scenario = arg.trim_prefix("--capture-scenario=")

func _apply_capture_scenario() -> void:
	view.overlay = ""
	match capture_scenario:
		"armed": session.arm_cast()
		"bite":
			session.arm_cast(); session.release_cast(0.8); session.state = FishingSession.State.HOOK_WINDOW
		"reeling":
			session.state = FishingSession.State.REELING; session.reel_progress = 0.48; session.tension = 0.63
		"caught":
			session.state = FishingSession.State.CAUGHT; session.last_reason = "Bluegill landed!"
		"escaped":
			session.state = FishingSession.State.ESCAPED; session.last_reason = "Line snapped under too much tension."
		"synthetic_reserve": view.synthetic_reserve = 88.0
		_: pass

func _capture_after_draw() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	print("SCREENSHOT_CAPTURED path=%s error=%s" % [capture_path, error])
	get_tree().quit(0 if error == OK else 1)

class FishingView extends Control:
	var controller: Node
	var overlay := ""
	var synthetic_reserve := 0.0
	var reel_center := Vector2(360, 980)
	var cast_rect := Rect2(92, 1060, 536, 105)
	var settings_rect := Rect2(625, 36, 58, 58)
	var font: Font

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		font = ThemeDB.fallback_font
		queue_redraw()

	func _draw() -> void:
		var size := get_size()
		var scale_x := size.x / 720.0
		var scale_y := size.y / 1280.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_x, scale_y))
		_draw_world()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_world() -> void:
		# Temporary code-native Gate 1 illustration; no production art is promoted.
		draw_rect(Rect2(0, 0, 720, 1280), Color("112d43"))
		draw_rect(Rect2(0, 0, 720, 370), Color("8fc9de"))
		draw_circle(Vector2(594, 138), 55, Color("f7d989"))
		for cloud_x in [105.0, 390.0]:
			draw_circle(Vector2(cloud_x, 120), 28, Color("d6edf3")); draw_circle(Vector2(cloud_x + 35, 113), 38, Color("d6edf3")); draw_circle(Vector2(cloud_x + 72, 124), 24, Color("d6edf3"))
		draw_rect(Rect2(0, 350, 720, 650), Color("236f8c"))
		for y in range(410, 930, 68):
			draw_line(Vector2(36, y), Vector2(680, y), Color("5fb2c6", 0.45), 3)
		for x in range(22, 720, 73):
			draw_line(Vector2(x, 348), Vector2(x - 13, 225), Color("1d5d54"), 8)
			draw_line(Vector2(x + 10, 348), Vector2(x + 24, 250), Color("347c62"), 6)
		draw_rect(Rect2(0, 1000, 720, 280), Color("153948"))
		_draw_header()
		_draw_state_panel()
		_draw_reel_or_cast()
		if synthetic_reserve > 0.0:
			draw_rect(Rect2(0, 1280 - synthetic_reserve, 720, synthetic_reserve), Color("ff2f5f", 0.68))
			_text("SYNTHETIC OVERLAY STRESS — NOT NATIVE AD", Vector2(72, 1248), 16, Color.WHITE)
		if overlay == "calibration": _draw_calibration()
		if overlay == "settings": _draw_settings()

	func _draw_header() -> void:
		_text("CAST & CRANK", Vector2(38, 68), 32, Color("fcf7df"))
		_text("PINE LAKE  •  BLUEGILL", Vector2(40, 96), 16, Color("d0e9d2"))
		draw_circle(Vector2(654, 65), 29, Color("e2bc62"))
		_text("⚙", Vector2(642, 77), 26, Color("1c3a46"))

	func _draw_state_panel() -> void:
		var s: FishingSession = controller.session
		var copy := "Hold CAST, cock back, then snap forward."
		match s.state:
			FishingSession.State.CAST_ARMED: copy = "Armed — snap forward now!"
			FishingSession.State.LINE_OUT: copy = "Line is out. Watch the bobber."
			FishingSession.State.HOOK_WINDOW: copy = "BITE! Tilt back or tap SET HOOK!"
			FishingSession.State.REELING: copy = "Reel clockwise. Ease off when tension glows red."
			FishingSession.State.CAUGHT: copy = "BLUEGILL LANDED! Tap the catch card."
			FishingSession.State.ESCAPED: copy = s.last_reason + " Tap to cast again."
		draw_style_box(_panel_style(Color("143c4d", 0.92), Color("a9d4ca")), Rect2(55, 165, 610, 104))
		_text(copy, Vector2(82, 208), 22, Color("f8f4d7"))
		if s.state == FishingSession.State.HOOK_WINDOW:
			draw_rect(Rect2(80, 232, 540, 9), Color("e8d276"))
			draw_rect(Rect2(80, 232, 540 * maxf(0.0, 1.0 - s.bite_elapsed / FishingSession.HOOK_WINDOW_SECONDS), 9), Color("fc5c55"))
		if s.state == FishingSession.State.CAUGHT:
			draw_style_box(_panel_style(Color("e6c869"), Color("fff3bf")), Rect2(102, 318, 516, 220))
			draw_circle(Vector2(360, 410), 69, Color("4e9eb5")); draw_circle(Vector2(395, 398), 8, Color("172e3b"))
			_text("19–27 cm • Pine Lake", Vector2(206, 512), 22, Color("153948"))
		if s.state == FishingSession.State.ESCAPED:
			draw_style_box(_panel_style(Color("713d47"), Color("e8aa90")), Rect2(102, 318, 516, 138))
			_text("TRY THE RIPPLE AGAIN", Vector2(166, 397), 24, Color("fff1d1"))

	func _draw_reel_or_cast() -> void:
		var s: FishingSession = controller.session
		if s.state == FishingSession.State.REELING:
			_draw_reel(s)
		elif s.state != FishingSession.State.CAUGHT and s.state != FishingSession.State.ESCAPED:
			draw_style_box(_panel_style(Color("e9bc57"), Color("fff1ba")), cast_rect)
			_text("HOLD TO CAST", Vector2(228, 1125), 28, Color("163b48"))
			_text("Touch fallback: hold then release", Vector2(190, 1152), 16, Color("254d58"))
		if s.state == FishingSession.State.HOOK_WINDOW:
			draw_style_box(_panel_style(Color("ee765c"), Color("ffe5bf")), Rect2(174, 875, 372, 78))
			_text("SET HOOK  [H]", Vector2(245, 925), 25, Color("432637"))

	func _draw_reel(s: FishingSession) -> void:
		draw_circle(reel_center, 146, Color("d3ac5e"))
		draw_circle(reel_center, 116, Color("253d4a"))
		draw_arc(reel_center, 90, -PI / 2.0, -PI / 2.0 + TAU * s.reel_progress, 64, Color("78d8ba"), 18, true)
		draw_circle(reel_center, 34, Color("e2bd68"))
		for i in 4:
			var angle := float(i) * TAU / 4.0 + 0.35
			draw_line(reel_center, reel_center + Vector2(cos(angle), sin(angle)) * 95, Color("e3ca83"), 9)
		_text("REEL CLOCKWISE", Vector2(222, 1165), 23, Color("fff1c9"))
		draw_style_box(_panel_style(Color("391f32"), Color("ff8e73")), Rect2(90, 815, 540, 32))
		draw_rect(Rect2(95, 820, 530 * s.tension, 22), Color("ed665b") if s.tension >= 0.65 else Color("8cd6aa"))
		_text("TENSION", Vector2(92, 800), 16, Color("f4e7c3"))

	func _draw_calibration() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.04, 0.11, 0.16, 0.88))
		draw_style_box(_panel_style(Color("eff3dc"), Color("fff6c5")), Rect2(54, 300, 612, 530))
		_text("MOTION CHECK", Vector2(180, 375), 34, Color("173a48"))
		var step: int = controller.calibration_step + 1
		_text("Practice cast %d of 2" % min(step, 2), Vector2(242, 430), 22, Color("2c6876"))
		_text("Hold your phone flat in your palm.", Vector2(118, 500), 22, Color("173a48"))
		_text("Cock it back, then snap it forward.", Vector2(104, 538), 22, Color("173a48"))
		draw_style_box(_panel_style(Color("e5b954"), Color("fff1bd")), Rect2(135, 630, 450, 90))
		_text("PRACTICE / SAFE BYPASS", Vector2(169, 687), 22, Color("173a48"))
		_text("You can recalibrate later in Settings.", Vector2(147, 770), 17, Color("416b72"))

	func _draw_settings() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.04, 0.11, 0.16, 0.88))
		draw_style_box(_panel_style(Color("eaf2dc"), Color("fff6c5")), Rect2(55, 260, 610, 660))
		_text("SETTINGS", Vector2(243, 338), 34, Color("173a48"))
		var settings: Dictionary = controller.save.data.settings
		_text("Sensitivity: %.1f  (tap row)" % float(settings.sensitivity), Vector2(120, 438), 24, Color("173a48"))
		_text("Haptics: %s" % ("ON" if settings.haptics else "OFF"), Vector2(120, 518), 24, Color("173a48"))
		_text("Audio: %s" % ("ON" if settings.audio else "OFF"), Vector2(120, 598), 24, Color("173a48"))
		_text("Reduced motion: %s" % ("ON" if settings.reduced_motion else "OFF"), Vector2(120, 678), 24, Color("173a48"))
		_text("Tap title to close", Vector2(247, 845), 18, Color("416b72"))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			var pressed: bool = bool(event.pressed)
			var pos: Vector2 = event.position * Vector2(720.0 / size.x, 1280.0 / size.y)
			if pressed:
				_handle_press(pos)
			else:
				_handle_release(pos)
		elif event is InputEventScreenDrag or event is InputEventMouseMotion:
			_handle_drag(event.position * Vector2(720.0 / size.x, 1280.0 / size.y), event.relative.length())

	func _handle_press(pos: Vector2) -> void:
		if overlay == "calibration":
			if Rect2(120, 610, 480, 130).has_point(pos): controller._calibrate_or_bypass()
			return
		if overlay == "settings":
			if pos.y < 370: overlay = ""
			elif pos.y < 470: controller._toggle_setting("sensitivity")
			elif pos.y < 550: controller._toggle_setting("haptics")
			elif pos.y < 630: controller._toggle_setting("audio")
			elif pos.y < 720: controller._toggle_setting("reduced_motion")
			return
		if settings_rect.has_point(pos): overlay = "settings"; return
		if controller.session.state == FishingSession.State.HOOK_WINDOW and Rect2(150, 850, 420, 120).has_point(pos): controller._hook(); return
		if controller.session.state == FishingSession.State.REELING:
			controller.has_reel_angle = true
			controller.last_reel_angle = (pos - reel_center).angle()
			return
		if controller.session.state in [FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]:
			controller._finish_catch(); controller._reset_session(); return
		if cast_rect.has_point(pos): controller._arm_cast()

	func _handle_release(pos: Vector2) -> void:
		if controller.session.state == FishingSession.State.CAST_ARMED and cast_rect.has_point(pos): controller.motion.queue_simulated_cast(); controller._cast(0.78)
		controller.has_reel_angle = false

	func _handle_drag(pos: Vector2, distance: float) -> void:
		if controller.session.state != FishingSession.State.REELING or not controller.has_reel_angle: return
		var angle := (pos - reel_center).angle()
		var delta := wrapf(angle - controller.last_reel_angle, -PI, PI)
		if delta > 0.0: controller.session.add_reel_turns(delta / TAU, maxf(0.016, distance / 700.0))
		controller.last_reel_angle = angle

	func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new(); box.bg_color = background; box.border_color = border
		box.set_border_width_all(3); box.set_corner_radius_all(20); return box

	func _text(value: String, pos: Vector2, font_size: int, color: Color) -> void:
		draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
