class_name MotionService
extends RefCounted

const SETTLE_DWELL_SECONDS := 0.65
const MAX_TRANSITION_SECONDS := 1.10
const MIN_TRANSITION_SECONDS := 0.08
const GESTURE_COOLDOWN_SECONDS := 0.32
const PROFILE_EXAMPLES := 2
const FIGHT_LOWER_TRAVEL_DEGREES := 14.0
const FIGHT_PULL_RETURN_TRAVEL_DEGREES := 10.0
const FIGHT_RETURN_HYSTERESIS_DEGREES := 3.0
const FIGHT_RETURN_DIRECTION_DOT := 0.70
const FIGHT_MIN_TRANSITION_SECONDS := 0.20
const FIGHT_GYRO_MINIMUM := 0.20

var sensitivity := 1.0
var sample_provider: Callable
var queued_samples: Array[Dictionary] = []
var profile: Dictionary = {}
var calibration_phase := "idle"
var calibration_progress := 0

var _calibration_examples: Array[Dictionary] = []
var _settle_elapsed := 0.0
var _gesture_elapsed := 0.0
var _cooldown_elapsed := 0.0
var _back_axis := Vector3.ZERO
var _back_peak := 0.0
var _back_gyro_peak := 0.0
var _noise_peak := 0.0
var _simulated_cast_pending := false
var _simulated_hook_pending := false
var fight_phase := ""
var fight_load := 0.0
var _fight_active := false
var _fight_pull_reference := Vector3.ZERO
var _fight_lower_reference := Vector3.ZERO
var _fight_transition_elapsed := 0.0
var _last_gravity := Vector3.ZERO

func _init(custom_provider: Callable = Callable()) -> void:
	sample_provider = custom_provider

func sample() -> Dictionary:
	if not queued_samples.is_empty():
		return queued_samples.pop_front()
	if sample_provider.is_valid():
		return sample_provider.call()
	return {"gravity": Input.get_gravity(), "accelerometer": Input.get_accelerometer(), "gyro": Input.get_gyroscope()}

func update(delta: float, allow_cast: bool, allow_hook: bool, allow_fight: bool = false) -> Dictionary:
	var reading := _read_once()
	if calibration_phase != "idle" and calibration_phase != "complete":
		return _update_calibration(delta, reading)
	_cooldown_elapsed = maxf(0.0, _cooldown_elapsed - delta)
	var event := {"cast_arm": false, "cast_quality": 0.0, "hook": false, "fight_lower": false, "fight_pull": false, "fight_load": fight_load, "fight_phase": fight_phase}
	if allow_cast:
		_update_cast(delta, reading, event)
	if allow_hook:
		event.hook = _detect_hook(reading)
	if allow_fight:
		_update_fight(delta, reading, event)
	return event

func begin_calibration() -> void:
	profile = {}
	_calibration_examples.clear()
	calibration_phase = "settling"
	calibration_progress = 0
	_settle_elapsed = 0.0
	reset_gesture()

func is_calibrated() -> bool:
	return validate_profile(profile)

func set_profile(value: Dictionary) -> bool:
	if not validate_profile(value):
		profile = {}
		return false
	profile = value.duplicate(true)
	calibration_phase = "complete"
	reset_gesture()
	return true

func get_profile() -> Dictionary:
	return profile.duplicate(true)

static func validate_profile(value: Dictionary) -> bool:
	if value.is_empty() or not value.has("forward_axis") or not value.has("back_peak") or not value.has("forward_peak"):
		return false
	var axis_value = value.forward_axis
	if not axis_value is Array or axis_value.size() != 3:
		return false
	var axis := Vector3(float(axis_value[0]), float(axis_value[1]), float(axis_value[2]))
	return axis.length() >= 0.90 and float(value.back_peak) >= 1.2 and float(value.forward_peak) >= 1.4 and float(value.get("gyro_peak", 0.0)) >= 0.08 and float(value.get("transition_seconds", 0.0)) >= MIN_TRANSITION_SECONDS and float(value.get("transition_seconds", 9.0)) <= MAX_TRANSITION_SECONDS and float(value.get("noise_floor", -1.0)) >= 0.0 and float(value.get("direction_tolerance", 0.0)) >= 0.45

func reset_gesture() -> void:
	_gesture_elapsed = 0.0
	_back_axis = Vector3.ZERO
	_back_peak = 0.0
	_back_gyro_peak = 0.0
	_noise_peak = 0.0

func begin_fight(pull_gravity: Vector3 = Vector3.ZERO) -> void:
	var reference := pull_gravity if pull_gravity.length() >= 1.0 else _last_gravity
	if reference.length() < 1.0:
		reset_fight()
		return
	_fight_active = true
	_fight_pull_reference = reference.normalized()
	_fight_lower_reference = Vector3.ZERO
	_fight_transition_elapsed = 0.0
	fight_phase = "LOWER ROD"
	fight_load = 1.0

func reset_fight() -> void:
	_fight_active = false
	_fight_pull_reference = Vector3.ZERO
	_fight_lower_reference = Vector3.ZERO
	_fight_transition_elapsed = 0.0
	fight_phase = ""
	fight_load = 0.0

func queue_sample(value: Dictionary) -> void:
	queued_samples.append(value)

func queue_simulated_cast() -> void:
	_simulated_cast_pending = true

func queue_simulated_hook() -> void:
	_simulated_hook_pending = true

func _read_once() -> Dictionary:
	var raw := sample()
	var gravity: Vector3 = raw.get("gravity", Vector3.ZERO)
	var accelerometer: Vector3 = raw.get("accelerometer", Vector3.ZERO)
	var gyro: Vector3 = raw.get("gyro", Vector3.ZERO)
	var linear := accelerometer
	if gravity.length() >= 1.0 and accelerometer.length() >= 1.0:
		linear = accelerometer - gravity
	_last_gravity = gravity
	return {"gravity": gravity, "linear": linear, "gyro": gyro}

func _update_fight(delta: float, reading: Dictionary, event: Dictionary) -> void:
	if not _fight_active:
		return
	var gravity: Vector3 = reading.gravity
	var gyro: Vector3 = reading.gyro
	if gravity.length() < 1.0 or _fight_pull_reference.length() < 0.90:
		return
	var pose := gravity.normalized()
	_fight_transition_elapsed += maxf(delta, 0.0)
	var pull_angle := rad_to_deg(pose.angle_to(_fight_pull_reference))
	if fight_phase == "LOWER ROD":
		# Before the first lower pose is learned, the hook/raised pose is already
		# a full pull. This lets the fight react continuously from the hook onward.
		fight_load = clampf(1.0 - pull_angle / FIGHT_LOWER_TRAVEL_DEGREES, 0.0, 1.0)
		if pull_angle >= FIGHT_LOWER_TRAVEL_DEGREES and gyro.length() >= FIGHT_GYRO_MINIMUM and _fight_transition_elapsed >= FIGHT_MIN_TRANSITION_SECONDS:
			_fight_lower_reference = pose
			fight_phase = "PULL BACK"
			fight_load = 0.0
			_fight_transition_elapsed = 0.0
			event.fight_lower = true
	elif fight_phase == "PULL BACK" and _fight_lower_reference.length() >= 0.90:
		var lower_angle := rad_to_deg(pose.angle_to(_fight_lower_reference))
		var reference_span := rad_to_deg(_fight_lower_reference.angle_to(_fight_pull_reference))
		# Pose load is continuous between the learned lower and pull references.
		# Equal angular distance is a neutral load; moving toward the raised pull
		# reference drives progress and tension without requiring a perfect return.
		fight_load = clampf((lower_angle - pull_angle + reference_span) / maxf(2.0 * reference_span, 0.01), 0.0, 1.0)
		var return_axis := (_fight_pull_reference - _fight_lower_reference).normalized()
		var pose_axis := (pose - _fight_lower_reference).normalized()
		var return_alignment := return_axis.dot(pose_axis)
		var clearly_toward_pull := pull_angle + FIGHT_RETURN_HYSTERESIS_DEGREES < lower_angle
		if lower_angle >= FIGHT_PULL_RETURN_TRAVEL_DEGREES and clearly_toward_pull and return_alignment >= FIGHT_RETURN_DIRECTION_DOT and gyro.length() >= FIGHT_GYRO_MINIMUM and _fight_transition_elapsed >= FIGHT_MIN_TRANSITION_SECONDS:
			fight_phase = "LOWER ROD"
			_fight_transition_elapsed = 0.0
			event.fight_pull = true
	event.fight_load = fight_load
	event.fight_phase = fight_phase

func _update_calibration(delta: float, reading: Dictionary) -> Dictionary:
	var linear: Vector3 = reading.linear
	var gyro: Vector3 = reading.gyro
	var event := {"cast_arm": false, "cast_quality": 0.0, "hook": false, "calibration_complete": false}
	if calibration_phase == "settling":
		if linear.length() <= 0.75 and gyro.length() <= 0.35:
			_settle_elapsed += delta
		else:
			_settle_elapsed = 0.0
		if _settle_elapsed >= SETTLE_DWELL_SECONDS:
			calibration_phase = "practice_%d_back" % (calibration_progress + 1)
		return event
	if _back_axis == Vector3.ZERO:
		if linear.length() >= 2.0 / maxf(sensitivity, 0.5) and gyro.length() >= 0.16:
			_back_axis = linear.normalized()
			_back_peak = linear.length()
			_back_gyro_peak = gyro.length()
			_noise_peak = 0.0
			_gesture_elapsed = 0.0
			calibration_phase = "practice_%d_snap" % (calibration_progress + 1)
		return event
	_gesture_elapsed += delta
	if _gesture_elapsed > MAX_TRANSITION_SECONDS:
		_retry_calibration_example()
		return event
	var forward_projection := linear.dot(-_back_axis)
	var forward_match := linear.normalized().dot(-_back_axis) if linear.length() > 0.0 else -1.0
	if forward_projection >= maxf(2.4 / maxf(sensitivity, 0.5), _back_peak * 0.72) and forward_match >= 0.62 and gyro.length() >= 0.16:
		_accept_calibration_example(forward_projection, gyro.length())
		if calibration_progress >= PROFILE_EXAMPLES:
			event.calibration_complete = _finish_calibration()
		return event
	if linear.length() > 0.0 and absf(linear.normalized().dot(_back_axis)) < 0.45:
		_noise_peak = maxf(_noise_peak, linear.length())
	return event

func _retry_calibration_example() -> void:
	reset_gesture()
	calibration_phase = "practice_%d_back" % (calibration_progress + 1)

func _accept_calibration_example(forward_peak: float, gyro_peak: float) -> void:
	_calibration_examples.append({"forward_axis": _vector_to_array(-_back_axis), "back_peak": _back_peak, "forward_peak": forward_peak, "gyro_peak": maxf(_back_gyro_peak, gyro_peak), "transition_seconds": _gesture_elapsed, "noise_floor": minf(_noise_peak, minf(_back_peak, forward_peak) * 0.30), "direction_tolerance": 0.62})
	calibration_progress = _calibration_examples.size()
	reset_gesture()
	calibration_phase = "practice_%d_back" % min(calibration_progress + 1, PROFILE_EXAMPLES)

func _finish_calibration() -> bool:
	if _calibration_examples.size() != PROFILE_EXAMPLES:
		return false
	var axis := Vector3.ZERO
	for example in _calibration_examples:
		axis += _array_to_vector(example.forward_axis).normalized()
	if axis.length() < 0.90:
		begin_calibration()
		return false
	axis = axis.normalized()
	for example in _calibration_examples:
		if _array_to_vector(example.forward_axis).normalized().dot(axis) < 0.70:
			begin_calibration()
			return false
	profile = {"forward_axis": _vector_to_array(axis), "back_peak": _average("back_peak"), "forward_peak": _average("forward_peak"), "gyro_peak": _average("gyro_peak"), "transition_seconds": _average("transition_seconds"), "noise_floor": _average("noise_floor"), "direction_tolerance": 0.62}
	if not validate_profile(profile):
		begin_calibration()
		return false
	calibration_phase = "complete"
	return true

func _average(key: String) -> float:
	var total := 0.0
	for example in _calibration_examples:
		total += float(example[key])
	return total / float(_calibration_examples.size())

func _update_cast(delta: float, reading: Dictionary, event: Dictionary) -> void:
	if not is_calibrated() or _cooldown_elapsed > 0.0:
		return
	if _simulated_cast_pending:
		_simulated_cast_pending = false
		reset_gesture()
		event.cast_arm = true
		event.cast_quality = 0.80
		return
	var linear: Vector3 = reading.linear
	var gyro: Vector3 = reading.gyro
	var axis := _array_to_vector(profile.forward_axis).normalized()
	if _back_axis == Vector3.ZERO:
		var back_projection := -linear.dot(axis)
		var back_match := -linear.normalized().dot(axis) if linear.length() > 0.0 else -1.0
		if back_projection >= _back_threshold() and back_match >= float(profile.direction_tolerance) and gyro.length() >= _gyro_threshold():
			_back_axis = -axis
			_back_peak = back_projection
			_back_gyro_peak = gyro.length()
			_gesture_elapsed = 0.0
			event.cast_arm = true
		return
	_gesture_elapsed += delta
	if _gesture_elapsed > MAX_TRANSITION_SECONDS:
		reset_gesture()
		return
	var forward_projection := linear.dot(axis)
	var forward_match := linear.normalized().dot(axis) if linear.length() > 0.0 else -1.0
	if forward_projection >= _forward_threshold() and forward_match >= float(profile.direction_tolerance) and gyro.length() >= _gyro_threshold():
		event.cast_quality = _cast_quality(forward_projection)
		reset_gesture()
		_cooldown_elapsed = GESTURE_COOLDOWN_SECONDS

func _detect_hook(reading: Dictionary) -> bool:
	if not is_calibrated() or _cooldown_elapsed > 0.0:
		return false
	if _simulated_hook_pending:
		_simulated_hook_pending = false
		_cooldown_elapsed = GESTURE_COOLDOWN_SECONDS
		return true
	var axis := _array_to_vector(profile.forward_axis).normalized()
	var linear: Vector3 = reading.linear
	var gyro: Vector3 = reading.gyro
	var back_projection: float = -linear.dot(axis)
	var back_match := -linear.normalized().dot(axis) if linear.length() > 0.0 else -1.0
	if back_projection >= _hook_threshold() and back_match >= float(profile.direction_tolerance) * 0.82 and gyro.length() >= _gyro_threshold() * 0.72:
		_cooldown_elapsed = GESTURE_COOLDOWN_SECONDS
		return true
	return false

func _back_threshold() -> float:
	return maxf(float(profile.noise_floor) * 2.6, float(profile.back_peak) * 0.56 / maxf(sensitivity, 0.5))

func _forward_threshold() -> float:
	return maxf(float(profile.noise_floor) * 2.8, float(profile.forward_peak) * 0.55 / maxf(sensitivity, 0.5))

func _hook_threshold() -> float:
	return maxf(float(profile.noise_floor) * 2.2, float(profile.back_peak) * 0.38 / maxf(sensitivity, 0.5))

func _gyro_threshold() -> float:
	return maxf(0.12, float(profile.gyro_peak) * 0.42 / maxf(sensitivity, 0.5))

func _cast_quality(forward_projection: float) -> float:
	var threshold := _forward_threshold()
	var peak := maxf(float(profile.forward_peak), threshold + 0.01)
	return clampf(0.35 + (forward_projection - threshold) / maxf(peak * 0.80, 0.1) * 0.65, 0.35, 1.0)

static func _vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _array_to_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
