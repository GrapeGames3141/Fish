class_name SaveService
extends RefCounted

const LocationDefinition = preload("res://src/domain/location_definition.gd")
const FightChallenge = preload("res://src/domain/fight_challenge.gd")

const VERSION := 6
const MAX_CATCH_HISTORY := 256
const PATH := "user://cast_and_crank_save.json"
const PLANNED_FISH_IDS := ["pumpkinseed", "black_crappie", "brown_bullhead", "bluegill", "largemouth_bass", "channel_catfish", "rainbow_trout", "smallmouth_bass", "northern_pike", "red_drum", "spotted_seatrout", "bluefish"]
const LOCATION_IDS := ["willow_pond", "pine_lake", "cedar_river", "hatteras_inlet"]
const LEGACY_UNLOCKED_IDS := ["willow_pond", "pine_lake", "cedar_river"]
var data: Dictionary = default_data()
var path: String
var timestamp_provider: Callable
func _init(custom_path: String = PATH, custom_timestamp_provider: Callable = Callable()) -> void: path = custom_path; timestamp_provider = custom_timestamp_provider
static func default_data() -> Dictionary:
	var catches := {}; var best_cm := {}
	for fish_id in PLANNED_FISH_IDS: catches[fish_id] = 0; best_cm[fish_id] = 0.0
	return {"version": VERSION, "calibrated": false, "motion_profile": {}, "selected_location_id": "willow_pond", "unlocked_location_ids": ["willow_pond"], "settings": {"sensitivity": 1.0, "haptics": true, "audio": true, "reduced_motion": false, "left_handed": false, "fight_challenge": FightChallenge.DEFAULT_ID}, "catches": catches, "best_cm": best_cm, "catch_history": []}
func load_data() -> Dictionary:
	if not FileAccess.file_exists(path): data = default_data(); return data
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: data = default_data(); return data
	var json := JSON.new(); var parse_error := json.parse(file.get_as_text()); file.close()
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY: data = default_data(); return data
	data = _migrate(json.data); return data
func _migrate(parsed: Dictionary) -> Dictionary:
	var migrated := default_data()
	var parsed_settings: Variant = parsed.get("settings", null)
	if parsed_settings is Dictionary:
		if _finite_number(parsed_settings.get("sensitivity", null)): migrated.settings.sensitivity = clampf(float(parsed_settings.sensitivity), 0.5, 2.0)
		for nested_key in ["haptics", "audio", "reduced_motion", "left_handed"]:
			if typeof(parsed_settings.get(nested_key, null)) == TYPE_BOOL: migrated.settings[nested_key] = bool(parsed_settings[nested_key])
		migrated.settings.fight_challenge = FightChallenge.sanitize(parsed_settings.get("fight_challenge", FightChallenge.DEFAULT_ID))
	for key in ["catches", "best_cm"]:
		if parsed.get(key, null) is Dictionary:
			for fish_id in PLANNED_FISH_IDS:
				if parsed[key].has(fish_id) and _finite_number(parsed[key][fish_id]): migrated[key][fish_id] = maxi(0, int(parsed[key][fish_id])) if key == "catches" else maxf(0.0, float(parsed[key][fish_id]))
	var parsed_version := _safe_nonnegative_int(parsed.get("version", 0))
	var is_legacy := parsed_version >= 1 and parsed_version < VERSION
	var unlocked: Array[String] = []
	if is_legacy:
		for location_id in LEGACY_UNLOCKED_IDS: unlocked.append(location_id)
	elif parsed.get("unlocked_location_ids", null) is Array:
		for location_id in parsed.unlocked_location_ids:
			var location := str(location_id)
			if location in LOCATION_IDS and location not in unlocked: unlocked.append(location)
	if not "willow_pond" in unlocked: unlocked.push_front("willow_pond")
	migrated.unlocked_location_ids = unlocked
	var location := str(parsed.get("selected_location_id", "willow_pond"))
	if location in unlocked: migrated.selected_location_id = location
	if parsed.has("motion_profile") and is_motion_profile_valid(parsed.motion_profile): migrated.motion_profile = parsed.motion_profile.duplicate(true); migrated.calibrated = true
	else: migrated.motion_profile = {}; migrated.calibrated = false
	# Old aggregate saves retain their truthful totals but receive no invented dates.
	if parsed.get("catch_history", null) is Array:
		for entry in parsed.catch_history:
			if entry is Dictionary and _history_entry_valid(entry): migrated.catch_history.append(_sanitize_history_entry(entry))
		while migrated.catch_history.size() > MAX_CATCH_HISTORY: migrated.catch_history.pop_front()
	_refresh_unlocks(migrated)
	migrated.version = VERSION; return migrated
static func is_motion_profile_valid(value: Variant) -> bool:
	if not value is Dictionary or not value.has("forward_axis") or not value.has("back_peak") or not value.has("forward_peak"): return false
	var axis: Variant = value.forward_axis
	if not axis is Array or axis.size() != 3: return false
	for component in axis:
		if not _finite_number(component): return false
	for key in ["back_peak", "forward_peak", "gyro_peak", "transition_seconds", "noise_floor", "direction_tolerance"]:
		if not _finite_number(value.get(key, null)): return false
	return Vector3(float(axis[0]), float(axis[1]), float(axis[2])).length() >= 0.90 and float(value.back_peak) >= 1.2 and float(value.forward_peak) >= 1.4 and float(value.get("gyro_peak", 0.0)) >= 0.08 and float(value.get("transition_seconds", 0.0)) >= 0.08 and float(value.get("transition_seconds", 9.0)) <= 1.10 and float(value.get("noise_floor", -1.0)) >= 0.0 and float(value.get("direction_tolerance", 0.0)) >= 0.45
static func _finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))

static func _safe_nonnegative_int(value: Variant, fallback := 0) -> int:
	return maxi(0, int(value)) if _finite_number(value) else fallback

static func _safe_clamped_float(value: Variant, minimum: float, maximum: float, fallback := 0.0) -> float:
	return clampf(float(value), minimum, maximum) if _finite_number(value) else fallback
func save_data() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data)); file.close(); return true
func _history_entry_valid(entry: Dictionary) -> bool:
	var fish_id := str(entry.get("fish_id", ""))
	var location_id := str(entry.get("location_id", ""))
	var location := LocationDefinition.by_id(location_id)
	return fish_id in PLANNED_FISH_IDS and location_id in LOCATION_IDS and not location.is_empty() and fish_id in location.get("species_ids", []) and _finite_number(entry.get("length_cm", 0.0)) and float(entry.length_cm) > 0.0 and _finite_number(entry.get("timestamp_utc", 0)) and int(entry.timestamp_utc) > 0
func _sanitize_history_entry(entry: Dictionary) -> Dictionary:
	return {"fish_id": str(entry.get("fish_id", "")), "length_cm": snappedf(maxf(0.0, _safe_clamped_float(entry.get("length_cm", 0.0), 0.0, 999.0)), 0.1), "location_id": str(entry.get("location_id", "")), "timestamp_utc": _safe_nonnegative_int(entry.get("timestamp_utc", 0)), "fight_seconds": snappedf(_safe_clamped_float(entry.get("fight_seconds", 0.0), 0.0, 180.0), 0.1), "cast_distance_m": snappedf(_safe_clamped_float(entry.get("cast_distance_m", 0.0), 0.0, 100.0), 0.1)}
func _timestamp_utc() -> int:
	var timestamp: Variant = timestamp_provider.call() if timestamp_provider.is_valid() else Time.get_unix_time_from_system()
	return _safe_nonnegative_int(timestamp)
func record_catch(fish_id: String, length_cm: float, metadata: Dictionary = {}) -> void:
	if fish_id not in PLANNED_FISH_IDS or not is_finite(length_cm) or length_cm <= 0.0: return
	data.catches[fish_id] = int(data.catches.get(fish_id, 0)) + 1; data.best_cm[fish_id] = maxf(float(data.best_cm.get(fish_id, 0.0)), length_cm)
	var entry := {"fish_id": fish_id, "length_cm": length_cm, "location_id": str(metadata.get("location_id", "")), "timestamp_utc": _safe_nonnegative_int(metadata.get("timestamp_utc", _timestamp_utc())), "fight_seconds": _safe_clamped_float(metadata.get("fight_seconds", 0.0), 0.0, 180.0), "cast_distance_m": _safe_clamped_float(metadata.get("cast_distance_m", 0.0), 0.0, 100.0)}
	if _history_entry_valid(entry):
		data.catch_history.append(_sanitize_history_entry(entry))
		while data.catch_history.size() > MAX_CATCH_HISTORY: data.catch_history.pop_front()
	_refresh_unlocks(data)
	save_data()

static func missing_species_for_location(candidate: Dictionary, location_id: String) -> Array[String]:
	var missing: Array[String] = []
	if location_id not in LOCATION_IDS: return PLANNED_FISH_IDS.duplicate()
	var catches: Variant = candidate.get("catches", {})
	if not catches is Dictionary: return LocationDefinition.earlier_species(location_id)
	for fish_id in LocationDefinition.earlier_species(location_id):
		var raw_count = catches.get(fish_id, 0)
		if not _finite_number(raw_count) or int(raw_count) < 1: missing.append(fish_id)
	return missing

static func _refresh_unlocks(candidate: Dictionary) -> void:
	var existing: Array[String] = []
	var raw_unlocked: Variant = candidate.get("unlocked_location_ids", [])
	if raw_unlocked is Array:
		for location_id in raw_unlocked:
			if str(location_id) in LOCATION_IDS and str(location_id) not in existing: existing.append(str(location_id))
	if not "willow_pond" in existing: existing.push_front("willow_pond")
	for location_id in LOCATION_IDS:
		if missing_species_for_location(candidate, location_id).is_empty() and location_id not in existing: existing.append(location_id)
	candidate.unlocked_location_ids = existing
func history_for_fish(fish_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in data.get("catch_history", []):
		if entry is Dictionary and str(entry.get("fish_id", "")) == fish_id: result.append(entry.duplicate(true))
	return result
func record_bluegill(length_cm: float) -> void: record_catch("bluegill", length_cm)
