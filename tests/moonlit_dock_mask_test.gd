extends SceneTree

const DEFAULT_BEFORE_ROOT := "E:/CodexCache/haptic-fish-moonlit-dock-fix-v42/raw-before"
const DEFAULT_AFTER_ROOT := "E:/CodexCache/haptic-fish-moonlit-dock-fix-v42/raw-after-postcap-final"
const DEFAULT_REDUCED_ROOT := "E:/CodexCache/haptic-fish-moonlit-dock-fix-v42/raw-reduced-postcap-final"
const FRAME_COUNT := 24
const WOOD_DELTA_MAX := 0.05
const WATER_DELTA_MIN := 0.50

# Measured, canonical 720x1280 samples just inside the photographed post and
# dock-board silhouette.  They follow the complete lower-left stepped edge
# rather than averaging a broad interior region, so a thin moving edge cannot
# be hidden by static wood.
const POST_SAMPLES := [Vector2i(54, 865), Vector2i(76, 900), Vector2i(88, 936), Vector2i(72, 970)]
const DOCK_EDGE_SAMPLES := [
	Vector2i(121, 995), Vector2i(133, 1008), Vector2i(143, 1020), Vector2i(154, 1034),
	Vector2i(163, 1048), Vector2i(187, 1064), Vector2i(200, 1080), Vector2i(218, 1100),
	Vector2i(233, 1120), Vector2i(260, 1140), Vector2i(279, 1160), Vector2i(294, 1180),
	Vector2i(301, 1200), Vector2i(321, 1220), Vector2i(328, 1240), Vector2i(361, 1260),
	Vector2i(355, 1274),
]
const WATER_SAMPLES := [
	Vector2i(440, 990), Vector2i(500, 1020), Vector2i(560, 1060), Vector2i(620, 1100),
	Vector2i(455, 1140), Vector2i(520, 1180), Vector2i(590, 1220), Vector2i(650, 1260),
]
const SOURCE_PHOTO := "res://art/ui_v1/runtime_source/waters-v40/moonlit_reservoir-photo-v01.png"

var failures: Array[String] = []

func _init() -> void:
	var roots := _roots_from_args()
	var before := _measure(str(roots.before), false)
	var after := _measure(str(roots.after), false)
	var reduced := _measure(str(roots.reduced), true)
	print("MOONLIT_DOCK_MASK " + JSON.stringify({"before": before, "after": after, "reduced": reduced, "frames": FRAME_COUNT}))
	if failures.is_empty():
		expect(float(after.post.max_delta) <= WOOD_DELTA_MAX and int(after.post.changed) == 0, "Moonlit post stays pixel-static across all 24 motion frames")
		expect(float(after.edge.max_delta) <= WOOD_DELTA_MAX and int(after.edge.changed) == 0, "Moonlit dock edge stays pixel-static across all measured board steps")
		expect(float(after.wood.max_delta) <= WOOD_DELTA_MAX and int(after.wood.changed) == 0, "all classified photographed dock wood stays pixel-static across all 24 frames")
		expect(float(after.water.max_delta) >= WATER_DELTA_MIN and int(after.water.changed) > 0, "nearby open Moonlit water still animates")
		expect(float(before.edge.max_delta) > WOOD_DELTA_MAX and int(before.edge.changed) > 0, "pre-fix baseline exposes motion on the measured dock edge")
		expect(float(before.wood.max_delta) > WOOD_DELTA_MAX and int(before.wood.changed) > 0, "pre-fix baseline exposes motion within classified photographed dock wood")
		expect(float(reduced.post.max_delta) <= WOOD_DELTA_MAX and int(reduced.post.changed) == 0, "Reduced Motion keeps the Moonlit post static")
		expect(float(reduced.edge.max_delta) <= WOOD_DELTA_MAX and int(reduced.edge.changed) == 0, "Reduced Motion keeps the full Moonlit dock edge static")
		expect(float(reduced.wood.max_delta) <= WOOD_DELTA_MAX and int(reduced.wood.changed) == 0, "Reduced Motion keeps all classified dock wood static")
		expect(float(reduced.water.max_delta) <= WOOD_DELTA_MAX and int(reduced.water.changed) == 0, "Reduced Motion freezes nearby Moonlit water")
	if failures.is_empty():
		print("PASS: Moonlit dock mask v42")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: %d Moonlit dock-mask assertions" % failures.size())
		quit(1)

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _roots_from_args() -> Dictionary:
	var roots := {"before": DEFAULT_BEFORE_ROOT, "after": DEFAULT_AFTER_ROOT, "reduced": DEFAULT_REDUCED_ROOT}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--before-root="): roots.before = arg.trim_prefix("--before-root=")
		elif arg.begins_with("--after-root="): roots.after = arg.trim_prefix("--after-root=")
		elif arg.begins_with("--reduced-root="): roots.reduced = arg.trim_prefix("--reduced-root=")
	return roots

func _measure(root: String, reduced: bool) -> Dictionary:
	var base_path := root.path_join("frame-000.png")
	if not FileAccess.file_exists(base_path):
		failures.append("missing frame root or frame-000.png: %s" % root)
		return _empty_result()
	var base := Image.load_from_file(base_path)
	if base.is_empty():
		failures.append("could not load frame-000.png: %s" % root)
		return _empty_result()
	if base.get_size() != Vector2i(720, 1280):
		failures.append("Moonlit motion frames must be 720x1280: %s" % base_path)
		return _empty_result()
	var classified_wood := _classified_wood_samples(base)
	if classified_wood.is_empty():
		failures.append("could not classify Moonlit dock wood from source photo")
		return _empty_result()
	var result := {"post": _empty_probe(), "edge": _empty_probe(), "wood": _empty_probe(), "water": _empty_probe()}
	for frame_index in range(FRAME_COUNT):
		var frame_path := root.path_join("frame-%03d.png" % frame_index)
		if not FileAccess.file_exists(frame_path):
			failures.append("missing motion frame: %s" % frame_path)
			return result
		var frame := Image.load_from_file(frame_path)
		if frame.is_empty() or frame.get_size() != base.get_size():
			failures.append("invalid motion frame dimensions: %s" % frame_path)
			return result
		_accumulate_probe(result.post, base, frame, POST_SAMPLES, 1)
		_accumulate_probe(result.edge, base, frame, DOCK_EDGE_SAMPLES, 1)
		_accumulate_probe(result.wood, base, frame, classified_wood, 0)
		_accumulate_probe(result.water, base, frame, WATER_SAMPLES, 1)
	result.reduced = reduced
	return result

func _empty_result() -> Dictionary:
	return {"post": _empty_probe(), "edge": _empty_probe(), "wood": _empty_probe(), "water": _empty_probe()}

func _empty_probe() -> Dictionary:
	return {"max_delta": 0.0, "changed": 0, "samples": 0}

func _accumulate_probe(probe: Dictionary, base: Image, frame: Image, centers: Array, radius: int) -> void:
	for center in centers:
		for y in range(maxi(0, center.y - radius), mini(base.get_height(), center.y + radius + 1)):
			for x in range(maxi(0, center.x - radius), mini(base.get_width(), center.x + radius + 1)):
				var a := base.get_pixel(x, y)
				var b := frame.get_pixel(x, y)
				var delta := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) * 255.0
				probe.max_delta = maxf(float(probe.max_delta), delta)
				if delta > WOOD_DELTA_MAX: probe.changed = int(probe.changed) + 1
				probe.samples = int(probe.samples) + 1

func _classified_wood_samples(base: Image) -> Array:
	var photo := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PHOTO))
	if photo.is_empty(): return []
	var samples: Array = []
	for y in range(850, min(1280, base.get_height())):
		for x in range(0, min(390, base.get_width())):
			var source_x := clampi(roundi(float(x) * float(photo.get_width()) / float(base.get_width())), 0, photo.get_width() - 1)
			var source_y := clampi(roundi(float(y) * float(photo.get_height()) / float(base.get_height())), 0, photo.get_height() - 1)
			var colour := photo.get_pixel(source_x, source_y)
			var r := colour.r * 255.0
			var g := colour.g * 255.0
			var b := colour.b * 255.0
			if r >= g + 3.0 and g >= b + 2.0 and r >= 10.0: samples.append(Vector2i(x, y))
	return samples
