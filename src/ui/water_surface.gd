class_name WaterSurface
extends Node2D

# Presentation-only water plate. It owns the location photo behind FishingView;
# native rod, mono, float and interface are intentionally drawn above it.
const WATER_SHADER := preload("res://src/ui/water_surface.gdshader")
const MASKS := {
	"willow_pond": preload("res://art/ui_v1/runtime_source/water-motion-v01/willow-mask.svg"),
	"pine_lake": preload("res://art/ui_v1/runtime_source/water-motion-v01/pine-mask.svg"),
	"cedar_river": preload("res://art/ui_v1/runtime_source/water-motion-v01/cedar-mask.svg"),
	"hatteras_inlet": preload("res://art/ui_v1/runtime_source/water-motion-v01/hatteras-mask.svg"),
	"mangrove_flats": preload("res://art/ui_v1/runtime_source/water-motion-v01/mangrove-mask.svg"),
	"cypress_bayou": preload("res://art/ui_v1/runtime_source/water-motion-v01/bayou-mask.svg"),
	"moonlit_reservoir": preload("res://art/ui_v1/runtime_source/water-motion-v01/moonlit-mask.svg"),
	"bluewater_offshore": preload("res://art/ui_v1/runtime_source/water-motion-v01/offshore-mask.svg"),
}

var controller: Node
var surface_material := ShaderMaterial.new()

func _ready() -> void:
	surface_material.shader = WATER_SHADER
	material = surface_material
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

static func profile_id(location_id: String) -> int:
	match location_id:
		"pine_lake": return 1
		"cedar_river": return 2
		"hatteras_inlet": return 3
		"mangrove_flats": return 4
		"cypress_bayou": return 5
		"moonlit_reservoir": return 6
		"bluewater_offshore": return 7
	return 0

static func profile_name(location_id: String) -> String:
	return ["pond", "lake", "river", "ocean", "mangrove_tide", "bayou", "moonlit_lake", "bluewater"][profile_id(location_id)]

# Canonical Hatteras shoreline controls. These follow the dry foreground edge
# in the approved plate; surf remains a shader-only presentation layer and does
# not alter open-water bobber physics.
static func ocean_shore_y(x: float) -> float:
	var anchors := [Vector2(0, 930), Vector2(100, 995), Vector2(200, 1060), Vector2(300, 1110), Vector2(400, 1150), Vector2(500, 1200), Vector2(600, 1230), Vector2(720, 1280)]
	var clamped_x := clampf(x, 0.0, 720.0)
	for index in range(anchors.size() - 1):
		var left: Vector2 = anchors[index]
		var right: Vector2 = anchors[index + 1]
		if clamped_x <= right.x: return lerpf(left.y, right.y, inverse_lerp(left.x, right.x, clamped_x))
	return 1280.0

static func ocean_surf_cycle(time: float, reduced: bool) -> float:
	return 0.0 if reduced else fposmod(time, 6.0) / 6.0

static func ocean_surf_weight(position: Vector2) -> float:
	var shore_depth := ocean_shore_y(position.x) - position.y
	# A broad 70px shoreward fade and 210px offshore fade bound gradients before
	# mask gating limits the visible foam swash to the safe foreground band.
	return smoothstep(-70.0, 0.0, shore_depth) * (1.0 - smoothstep(150.0, 360.0, shore_depth))

static func ocean_surf_offset(position: Vector2, time: float, reduced: bool) -> Vector2:
	if reduced: return Vector2.ZERO
	var shore_depth := ocean_shore_y(position.x) - position.y
	var shoreline_lag := sin(position.x * .005) * .018
	var run_cycle := 0.5 - 0.5 * cos((ocean_surf_cycle(time, false) + shoreline_lag) * TAU)
	# Broad, non-folding shorewash: zero at both cycle boundaries, a 70px
	# shoreward fade, and a 210px offshore fade prevent taffy-like warping.
	var shore_envelope := ocean_surf_weight(position)
	var offshore_envelope := smoothstep(95.0, 165.0, shore_depth) * (1.0 - smoothstep(420.0, 610.0, shore_depth))
	var push := 28.0 * run_cycle * shore_envelope + 7.0 * sin((ocean_surf_cycle(time, false) + shore_depth * .004 + position.x * .002) * TAU) * offshore_envelope
	var shore_normal := Vector2(-.46, 1.0).normalized()
	return shore_normal * push

# Matches the shader's periodic presentation phase closely enough for the
# bobber to share the water's heave/drift without a CPU texture readback.
static func _field(px: Vector2, phase: float, speed: float) -> float:
	return sin(px.dot(Vector2(.058, .123)) - phase * (4.0 + speed)) + sin(px.dot(Vector2(-.044, .091)) + phase * (5.0 + speed * .6) + 1.4) * .76 + sin(px.dot(Vector2(.084, -.166)) - phase * 7.0 + 2.1) * .54 + sin(px.dot(Vector2(.027, .047)) + phase * 2.0 + 2.9) * .48

static func sample(location_id: String, position: Vector2, time: float, reduced: bool) -> Dictionary:
	if reduced: return {"offset": Vector2.ZERO, "common_offset": Vector2.ZERO, "shore_offset": Vector2.ZERO, "tilt": 0.0, "submerge": 0.0}
	var profile := profile_id(location_id)
	var phase := time * TAU / 6.0
	var p := position
	var perspective := lerpf(.12, 1.0, smoothstep(.40, .90, p.y / 1280.0))
	var a := _field(p, phase, float(profile))
	var b := _field(p + Vector2(29.0, -17.0), phase, float(profile))
	var strength: float = [1.0, 1.18, 1.08, 1.0, 0.82, 0.58, 0.76, 1.42][profile]
	var drift: Vector2 = Vector2(a * 2.15 + b * 1.55, a * 1.15 - b * 1.75) * strength * perspective * .78
	if profile == 2: drift += Vector2(-1.8 + sin(phase * 3.0 + p.y * .04), 0.35) * perspective
	if profile == 3:
		var swell := sin(p.x * .021 + p.y * .038 - phase * 1.4) + sin(p.x * -.014 + p.y * .026 + phase * 2.0 + .8) * .55
		drift += Vector2(swell * 3.3, swell * 6.6) * perspective
	if profile == 4: drift += Vector2(sin(phase * 1.4 + p.y * .018) * .75, .25) * perspective
	if profile == 5: drift += Vector2(-.45 + sin(phase * .72 + p.y * .012) * .35, .16) * perspective
	if profile == 6: drift += Vector2(sin(phase * 1.2 + p.x * .014) * 1.2, sin(phase * .9 + p.y * .017) * 1.55) * perspective
	if profile == 7:
		var bluewater_swell := sin(p.x * .016 + p.y * .030 - phase * 1.15) + sin(p.x * -.010 + p.y * .021 + phase * 1.65 + .6) * .68
		drift += Vector2(bluewater_swell * 4.2, bluewater_swell * 8.5) * perspective
	drift = drift.limit_length(5.0 if profile < 3 else (10.0 if profile == 3 else (4.5 if profile < 7 else 12.5)))
	var common_drift := drift
	var shore_offset := Vector2.ZERO if profile != 3 else ocean_surf_offset(p, time, false)
	if profile == 3: drift += shore_offset
	return {"offset": drift, "common_offset": common_drift, "shore_offset": shore_offset, "tilt": clampf((a - b) * 0.085 * strength, -0.17, 0.17), "submerge": clampf(0.50 + drift.y * 0.025, 0.30, 0.70)}

func _draw() -> void:
	if controller == null or not is_instance_valid(controller): return
	var texture: Texture2D = controller.location_texture(controller.session.location_id)
	if texture == null: return
	var reduced := bool(controller.save.data.settings.get("reduced_motion", false))
	surface_material.set_shader_parameter("water_mask", MASKS.get(controller.session.location_id, MASKS.willow_pond))
	surface_material.set_shader_parameter("profile", profile_id(controller.session.location_id))
	surface_material.set_shader_parameter("phase", controller.ui_time * TAU / 6.0)
	surface_material.set_shader_parameter("reduced_motion", reduced)
	var size := get_viewport_rect().size
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / 720.0, size.y / 1280.0))
	draw_texture_rect(texture, Rect2(0, 0, 720, 1280), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
