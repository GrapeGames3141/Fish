class_name SaveService
extends RefCounted

const VERSION := 2
const PATH := "user://cast_and_crank_save.json"

var data: Dictionary = default_data()
var path: String

func _init(custom_path: String = PATH) -> void:
	path = custom_path

static func default_data() -> Dictionary:
	return {"version": VERSION, "calibrated": false, "motion_profile": {}, "settings": {"sensitivity": 1.0, "haptics": true, "audio": true, "reduced_motion": false}, "catches": {"bluegill": 0}, "best_cm": {"bluegill": 0.0}}

func load_data() -> Dictionary:
	if not FileAccess.file_exists(path):
		data = default_data()
		return data
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		data = default_data()
		return data
	var parsed: Dictionary = json.data
	data = _migrate(parsed)
	return data

func _migrate(parsed: Dictionary) -> Dictionary:
	var migrated := default_data()
	for key in ["settings", "catches", "best_cm"]:
		if parsed.get(key, null) is Dictionary:
			for nested_key in parsed[key]:
				migrated[key][nested_key] = parsed[key][nested_key]
	if parsed.has("motion_profile") and is_motion_profile_valid(parsed.motion_profile):
		migrated.motion_profile = parsed.motion_profile
		migrated.calibrated = true
	else:
		# v1 saves never carried a physical motion profile; retain progress but require two real casts.
		migrated.motion_profile = {}
		migrated.calibrated = false
	migrated.version = VERSION
	return migrated

static func is_motion_profile_valid(value: Variant) -> bool:
	if not value is Dictionary or not value.has("forward_axis") or not value.has("back_peak") or not value.has("forward_peak"):
		return false
	var axis = value.forward_axis
	if not axis is Array or axis.size() != 3:
		return false
	var magnitude := Vector3(float(axis[0]), float(axis[1]), float(axis[2])).length()
	return magnitude >= 0.90 and float(value.back_peak) >= 1.2 and float(value.forward_peak) >= 1.4 and float(value.get("gyro_peak", 0.0)) >= 0.08 and float(value.get("transition_seconds", 0.0)) >= 0.08 and float(value.get("transition_seconds", 9.0)) <= 1.10 and float(value.get("noise_floor", -1.0)) >= 0.0 and float(value.get("direction_tolerance", 0.0)) >= 0.45

func save_data() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func record_bluegill(length_cm: float) -> void:
	data.catches.bluegill = int(data.catches.get("bluegill", 0)) + 1
	data.best_cm.bluegill = maxf(float(data.best_cm.get("bluegill", 0.0)), length_cm)
	save_data()
