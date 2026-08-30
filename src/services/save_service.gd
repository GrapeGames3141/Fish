class_name SaveService
extends RefCounted

const VERSION := 1
const PATH := "user://cast_and_crank_save.json"

var data: Dictionary = default_data()

static func default_data() -> Dictionary:
	return {"version": VERSION, "calibrated": false, "settings": {"sensitivity": 1.0, "haptics": true, "audio": true, "reduced_motion": false}, "catches": {"bluegill": 0}, "best_cm": {"bluegill": 0.0}}

func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		data = default_data()
		return data
	var file := FileAccess.open(PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		data = default_data()
		return data
	data = default_data()
	for key in parsed:
		data[key] = parsed[key]
	return data

func save_data() -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true

func record_bluegill(length_cm: float) -> void:
	data.catches.bluegill = int(data.catches.get("bluegill", 0)) + 1
	data.best_cm.bluegill = maxf(float(data.best_cm.get("bluegill", 0.0)), length_cm)
	save_data()
