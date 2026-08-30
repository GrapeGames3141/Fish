class_name CastCaptureService
extends RefCounted

## Opt-in trace recorder for a user-requested ten-cast tuning session. Normal
## motion diagnostics remain derived-only; this service never samples or writes
## raw sensors until Settings explicitly starts a capture.
const VERSION := 1
const PATH := "user://cast_tuning_capture.json"
const CAST_COUNT := 10
const COUNTDOWN_SECONDS := 3.0
const ACTIVE_WINDOW_SECONDS := 2.0
const REST_WINDOW_SECONDS := 1.0
const MAX_DELTA_SECONDS := 0.10
const MAX_SAMPLES_PER_CAST := 180
const MAX_VECTOR_COMPONENT := 100.0

var path: String
var sample_provider: Callable
var queued_samples: Array[Dictionary] = []
var phase := "idle"
var cast_index := 0
var phase_elapsed := 0.0
var session_elapsed := 0.0
var metadata: Dictionary = {}
var casts: Array[Dictionary] = []
var saved := false
var write_count := 0

func _init(custom_path: String = PATH, custom_provider: Callable = Callable()) -> void:
	path = custom_path
	sample_provider = custom_provider

func start(value: Dictionary) -> bool:
	if is_active():
		return false
	phase = "countdown"
	cast_index = 0
	phase_elapsed = 0.0
	session_elapsed = 0.0
	metadata = _safe_metadata(value)
	casts.clear()
	saved = false
	write_count = 0
	queued_samples.clear()
	return true

func is_active() -> bool:
	return phase in ["countdown", "active", "rest"]

func queue_sample(value: Dictionary) -> void:
	queued_samples.append(value)

func update(delta: float) -> Dictionary:
	var event := {"phase": phase, "cast_index": cast_index, "cue": "", "saved": false}
	if not is_active():
		return event
	var bounded_delta := clampf(delta, 0.0, MAX_DELTA_SECONDS)
	session_elapsed += bounded_delta
	phase_elapsed += bounded_delta
	if phase == "countdown":
		if phase_elapsed >= COUNTDOWN_SECONDS:
			phase = "active"
			phase_elapsed = 0.0
			event.phase = phase
			event.cue = "capture_window"
		return event
	if phase == "active":
		_record_sample_once()
		if phase_elapsed >= ACTIVE_WINDOW_SECONDS:
			cast_index += 1
			phase_elapsed = 0.0
			if cast_index >= CAST_COUNT:
				phase = "saved"
				saved = _write_completed_capture()
				event.phase = phase
				event.cue = "capture_complete"
				event.saved = saved
			else:
				phase = "rest"
				event.phase = phase
		return event
	if phase == "rest" and phase_elapsed >= REST_WINDOW_SECONDS:
		phase = "active"
		phase_elapsed = 0.0
		event.phase = phase
		event.cue = "capture_window"
	return event

func status() -> Dictionary:
	return {"phase": phase, "cast_index": cast_index, "cast_count": CAST_COUNT, "phase_elapsed": phase_elapsed, "saved": saved}

func _record_sample_once() -> void:
	if cast_index < 0 or cast_index >= CAST_COUNT:
		return
	while casts.size() <= cast_index:
		casts.append({"index": casts.size() + 1, "samples": []})
	var group: Dictionary = casts[cast_index]
	var samples: Array = group.samples
	if samples.size() >= MAX_SAMPLES_PER_CAST:
		return
	var raw := _sample_once()
	var gravity := _vector(raw.get("gravity", Vector3.ZERO))
	var accelerometer := _vector(raw.get("accelerometer", Vector3.ZERO))
	var gyro := _vector(raw.get("gyro", Vector3.ZERO))
	var linear := accelerometer - gravity if gravity.length() >= 1.0 and accelerometer.length() >= 1.0 else accelerometer
	samples.append({"t_ms": roundi(session_elapsed * 1000.0), "gravity": _array(gravity), "accelerometer": _array(accelerometer), "linear": _array(linear), "gyro": _array(gyro)})
	group.samples = samples
	casts[cast_index] = group

func _sample_once() -> Dictionary:
	if not queued_samples.is_empty():
		return queued_samples.pop_front()
	if sample_provider.is_valid():
		var value = sample_provider.call()
		return value if value is Dictionary else {}
	return {"gravity": Input.get_gravity(), "accelerometer": Input.get_accelerometer(), "gyro": Input.get_gyroscope()}

func _write_completed_capture() -> bool:
	if casts.size() != CAST_COUNT:
		return false
	for group in casts:
		if not group is Dictionary or not group.has("samples") or group.samples.is_empty():
			return false
	var payload := {"version": VERSION, "completed": true, "metadata": metadata, "casts": casts}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	write_count += 1
	return true

func _safe_metadata(value: Dictionary) -> Dictionary:
	return {"handedness": "left" if bool(value.get("left_handed", false)) else "right", "sensitivity": clampf(float(value.get("sensitivity", 1.0)), 0.5, 2.0), "motion_profile": value.get("motion_profile", {}).duplicate(true) if value.get("motion_profile", {}) is Dictionary else {}}

func _vector(value: Variant) -> Vector3:
	return value if value is Vector3 else Vector3.ZERO

func _array(value: Vector3) -> Array:
	return [clampf(value.x, -MAX_VECTOR_COMPONENT, MAX_VECTOR_COMPONENT), clampf(value.y, -MAX_VECTOR_COMPONENT, MAX_VECTOR_COMPONENT), clampf(value.z, -MAX_VECTOR_COMPONENT, MAX_VECTOR_COMPONENT)]
