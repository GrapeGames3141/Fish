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
	return 0

static func profile_name(location_id: String) -> String:
	return ["pond", "lake", "river", "ocean"][profile_id(location_id)]

# Matches the shader's periodic presentation phase closely enough for the
# bobber to share the water's heave/drift without a CPU texture readback.
static func _field(px: Vector2, phase: float, speed: float) -> float:
	return sin(px.dot(Vector2(.058, .123)) - phase * (4.0 + speed)) + sin(px.dot(Vector2(-.044, .091)) + phase * (5.0 + speed * .6) + 1.4) * .76 + sin(px.dot(Vector2(.084, -.166)) - phase * 7.0 + 2.1) * .54 + sin(px.dot(Vector2(.027, .047)) + phase * 2.0 + 2.9) * .48

static func sample(location_id: String, position: Vector2, time: float, reduced: bool) -> Dictionary:
	if reduced: return {"offset": Vector2.ZERO, "tilt": 0.0, "submerge": 0.0}
	var profile := profile_id(location_id)
	var phase := time * TAU / 6.0
	var p := position
	var perspective := lerpf(.12, 1.0, smoothstep(.40, .90, p.y / 1280.0))
	var a := _field(p, phase, float(profile))
	var b := _field(p + Vector2(29.0, -17.0), phase, float(profile))
	var strength: float = [1.0, 1.18, 1.08, 1.0][profile]
	var drift: Vector2 = Vector2(a * 2.15 + b * 1.55, a * 1.15 - b * 1.75) * strength * perspective * .78
	if profile == 2: drift += Vector2(-1.8 + sin(phase * 3.0 + p.y * .04), 0.35) * perspective
	if profile == 3:
		var swell := sin(p.x * .021 + p.y * .038 - phase * 1.4) + sin(p.x * -.014 + p.y * .026 + phase * 2.0 + .8) * .55
		drift += Vector2(swell * 3.3, swell * 6.6) * perspective
	drift = drift.limit_length(5.0 if profile < 3 else 10.0)
	return {"offset": drift, "tilt": clampf((a - b) * 0.085 * strength, -0.17, 0.17), "submerge": clampf(0.50 + drift.y * 0.025, 0.30, 0.70)}

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
