class_name SaveService
extends RefCounted

const VERSION := 5
const MAX_CATCH_HISTORY := 256
const PATH := "user://cast_and_crank_save.json"
const PLANNED_FISH_IDS := ["bluegill", "largemouth_bass", "channel_catfish", "rainbow_trout", "smallmouth_bass", "northern_pike"]
var data: Dictionary = default_data()
var path: String
var timestamp_provider: Callable
func _init(custom_path: String = PATH, custom_timestamp_provider: Callable = Callable()) -> void: path = custom_path; timestamp_provider = custom_timestamp_provider
static func default_data() -> Dictionary:
	var catches := {}; var best_cm := {}
	for fish_id in PLANNED_FISH_IDS: catches[fish_id] = 0; best_cm[fish_id] = 0.0
	return {"version": VERSION, "calibrated": false, "motion_profile": {}, "selected_location_id": "pine_lake", "settings": {"sensitivity": 1.0, "haptics": true, "audio": true, "reduced_motion": false, "left_handed": false}, "catches": catches, "best_cm": best_cm, "catch_history": []}
func load_data() -> Dictionary:
	if not FileAccess.file_exists(path): data = default_data(); return data
	var file := FileAccess.open(path, FileAccess.READ); var json := JSON.new(); var parse_error := json.parse(file.get_as_text()); file.close()
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY: data = default_data(); return data
	data = _migrate(json.data); return data
func _migrate(parsed: Dictionary) -> Dictionary:
	var migrated := default_data()
	for key in ["settings", "catches", "best_cm"]:
		if parsed.get(key, null) is Dictionary:
			for nested_key in parsed[key]: migrated[key][nested_key] = parsed[key][nested_key]
	var location := str(parsed.get("selected_location_id", "pine_lake"))
	if location in ["pine_lake", "cedar_river"]: migrated["selected_location_id"] = location
	if parsed.has("motion_profile") and is_motion_profile_valid(parsed.motion_profile): migrated.motion_profile = parsed.motion_profile; migrated.calibrated = true
	else: migrated.motion_profile = {}; migrated.calibrated = false
	# Old aggregate saves retain their truthful totals but receive no invented dates.
	if parsed.get("catch_history", null) is Array:
		for entry in parsed.catch_history:
			if entry is Dictionary and _history_entry_valid(entry): migrated.catch_history.append(_sanitize_history_entry(entry))
		while migrated.catch_history.size() > MAX_CATCH_HISTORY: migrated.catch_history.pop_front()
	migrated.version = VERSION; return migrated
static func is_motion_profile_valid(value: Variant) -> bool:
	if not value is Dictionary or not value.has("forward_axis") or not value.has("back_peak") or not value.has("forward_peak"): return false
	var axis = value.forward_axis
	if not axis is Array or axis.size() != 3: return false
	return Vector3(float(axis[0]), float(axis[1]), float(axis[2])).length() >= 0.90 and float(value.back_peak) >= 1.2 and float(value.forward_peak) >= 1.4 and float(value.get("gyro_peak", 0.0)) >= 0.08 and float(value.get("transition_seconds", 0.0)) >= 0.08 and float(value.get("transition_seconds", 9.0)) <= 1.10 and float(value.get("noise_floor", -1.0)) >= 0.0 and float(value.get("direction_tolerance", 0.0)) >= 0.45
func save_data() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data)); file.close(); return true
func _history_entry_valid(entry: Dictionary) -> bool:
	return str(entry.get("fish_id", "")) in PLANNED_FISH_IDS and float(entry.get("length_cm", 0.0)) > 0.0 and str(entry.get("location_id", "")) in ["pine_lake", "cedar_river"] and int(entry.get("timestamp_utc", 0)) > 0
func _sanitize_history_entry(entry: Dictionary) -> Dictionary:
	return {"fish_id": str(entry.fish_id), "length_cm": snappedf(maxf(0.0, float(entry.length_cm)), 0.1), "location_id": str(entry.location_id), "timestamp_utc": int(entry.timestamp_utc), "fight_seconds": snappedf(clampf(float(entry.get("fight_seconds", 0.0)), 0.0, 180.0), 0.1), "cast_distance_m": snappedf(clampf(float(entry.get("cast_distance_m", 0.0)), 0.0, 100.0), 0.1)}
func _timestamp_utc() -> int: return int(timestamp_provider.call()) if timestamp_provider.is_valid() else int(Time.get_unix_time_from_system())
func record_catch(fish_id: String, length_cm: float, metadata: Dictionary = {}) -> void:
	data.catches[fish_id] = int(data.catches.get(fish_id, 0)) + 1; data.best_cm[fish_id] = maxf(float(data.best_cm.get(fish_id, 0.0)), length_cm)
	var entry := {"fish_id": fish_id, "length_cm": length_cm, "location_id": str(metadata.get("location_id", "")), "timestamp_utc": int(metadata.get("timestamp_utc", _timestamp_utc())), "fight_seconds": float(metadata.get("fight_seconds", 0.0)), "cast_distance_m": float(metadata.get("cast_distance_m", 0.0))}
	if _history_entry_valid(entry):
		data.catch_history.append(_sanitize_history_entry(entry))
		while data.catch_history.size() > MAX_CATCH_HISTORY: data.catch_history.pop_front()
	save_data()
func history_for_fish(fish_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in data.get("catch_history", []):
		if entry is Dictionary and str(entry.get("fish_id", "")) == fish_id: result.append(entry.duplicate(true))
	return result
func record_bluegill(length_cm: float) -> void: record_catch("bluegill", length_cm)
