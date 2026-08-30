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
const FIGHT_MIN_TRANSITION_SECONDS := 0.20
const FIGHT_GYRO_MINIMUM := 0.20
# Portrait/right-handed contract: physical left is the forward/ease direction,
# physical right is the cock/pull/hook direction. A future mirror mode can swap
# these constants without changing the state machines below.
const RIGHT_HANDED_FORWARD_AXIS := Vector3(-1, 0, 0)
const RIGHT_HANDED_BACK_AXIS := Vector3(1, 0, 0)
# A saved/calibration profile must still be recognizably right-handed, but live
# motion uses the learned 3D axis for direction. These low X gates merely retain
# polarity so a natural diagonal cock is not forced into a second narrow cone.
const PROFILE_HANDEDNESS_ALIGNMENT := 0.48
const CALIBRATION_HANDEDNESS_ALIGNMENT := 0.34
const RUNTIME_X_POLARITY_ALIGNMENT := 0.18
const SNAP_MIN_AXIS_TOLERANCE := 0.38
const SNAP_AXIS_PROFILE_SCALE := 0.68
const SNAP_MIN_POLARITY_TOLERANCE := 0.06
const SNAP_POLARITY_SCALE := 0.45
const LOAD_RESPONSE_SECONDS := 0.10
const LOAD_DEADBAND := 0.035

var sensitivity := 1.0
var left_handed := false
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
var _settle_noise_peak := 0.0
var _settle_gyro_peak := 0.0
var _simulated_cast_pending := false
var _simulated_hook_pending := false
var fight_phase := ""
var fight_load := 0.0
var _fight_active := false
var _fight_pull_reference := Vector3.ZERO
var _fight_lower_reference := Vector3.ZERO
var _fight_transition_elapsed := 0.0
var _last_gravity := Vector3.ZERO
var diagnostics := {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
var _diagnostic_elapsed := 0.0
var _candidate_latched := {"cock": false, "snap": false, "hook": false}

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
	_diagnostic_elapsed += maxf(delta, 0.0)
	if calibration_phase != "idle" and calibration_phase != "complete":
		return _update_calibration(delta, reading)
	_cooldown_elapsed = maxf(0.0, _cooldown_elapsed - delta)
	var event := {"cast_arm": false, "cast_quality": 0.0, "hook": false, "fight_lower": false, "fight_pull": false, "fight_load": fight_load, "fight_phase": fight_phase}
	if allow_cast:
		_update_cast(delta, reading, event)
	if allow_hook:
		event.hook = _detect_hook(reading)
	else:
		# Hook candidates exist only inside the bounded bite window. Do not let a
		# rejected/high sample from a completed window suppress the first real
		# candidate in the next session.
		_candidate_latched.hook = false
	if allow_fight:
		_update_fight(delta, reading, event)
	return event

func begin_calibration() -> void:
	profile = {}
	_calibration_examples.clear()
	calibration_phase = "settling"
	calibration_progress = 0
	_settle_elapsed = 0.0
	_settle_noise_peak = 0.0
	_settle_gyro_peak = 0.0
	reset_gesture()

func set_left_handed(value: bool) -> bool:
	if left_handed == value: return false
	left_handed = value
	profile = {}
	begin_calibration()
	return true

func get_diagnostics() -> Dictionary: return diagnostics.duplicate(true)

func _forward_axis() -> Vector3: return -RIGHT_HANDED_FORWARD_AXIS if left_handed else RIGHT_HANDED_FORWARD_AXIS
func _back_axis_direction() -> Vector3: return -_forward_axis()

func is_calibrated() -> bool: return validate_profile(profile, left_handed)

func set_profile(value: Dictionary) -> bool:
	if not validate_profile(value, left_handed):
		profile = {}
		return false
	profile = value.duplicate(true)
	calibration_phase = "complete"
	reset_gesture()
	return true

func get_profile() -> Dictionary:
	return profile.duplicate(true)

static func validate_profile(value: Dictionary, use_left_handed: bool = false) -> bool:
	if value.is_empty() or not value.has("forward_axis") or not value.has("back_peak") or not value.has("forward_peak"):
		return false
	var axis_value = value.forward_axis
	if not axis_value is Array or axis_value.size() != 3:
		return false
	var axis := Vector3(float(axis_value[0]), float(axis_value[1]), float(axis_value[2]))
	var forward := -RIGHT_HANDED_FORWARD_AXIS if use_left_handed else RIGHT_HANDED_FORWARD_AXIS
	return axis.length() >= 0.90 and axis.normalized().dot(forward) >= PROFILE_HANDEDNESS_ALIGNMENT and float(value.back_peak) >= 1.2 and float(value.forward_peak) >= 1.4 and float(value.get("gyro_peak", 0.0)) >= 0.08 and float(value.get("transition_seconds", 0.0)) >= MIN_TRANSITION_SECONDS and float(value.get("transition_seconds", 9.0)) <= MAX_TRANSITION_SECONDS and float(value.get("noise_floor", -1.0)) >= 0.0 and float(value.get("direction_tolerance", 0.0)) >= 0.45

func reset_gesture() -> void:
	_gesture_elapsed = 0.0
	_back_axis = Vector3.ZERO
	_back_peak = 0.0
	_back_gyro_peak = 0.0
	_noise_peak = 0.0
	_candidate_latched.cock = false
	_candidate_latched.snap = false
	_candidate_latched.hook = false

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
	var left_travel := _ease_pose_travel_degrees(pose, _fight_pull_reference)
	if _fight_lower_reference.length() < 0.90:
		# Before the first left/ease pose is learned, the hook/right pose is a full
		# pull. Pitch/YZ motion or rightward travel must never ease the line.
		_smooth_fight_load(clampf(1.0 - maxf(left_travel, 0.0) / FIGHT_LOWER_TRAVEL_DEGREES, 0.0, 1.0), delta)
		if left_travel >= FIGHT_LOWER_TRAVEL_DEGREES and gyro.length() >= FIGHT_GYRO_MINIMUM and _fight_transition_elapsed >= FIGHT_MIN_TRANSITION_SECONDS:
			_fight_lower_reference = pose
			fight_phase = "PULL BACK"
			fight_load = 0.0
			_fight_transition_elapsed = 0.0
			event.fight_lower = true
	else:
		var reference_span := _ease_pose_travel_degrees(_fight_lower_reference, _fight_pull_reference)
		var rightward_return := _pull_pose_travel_degrees(pose, _fight_lower_reference)
		# Pose load is signed: left/lower is 0, and only return toward physical
		# right/pull increases it. Y/Z-only shakes stay at zero regardless of angle.
		var raw_fight_load := clampf(rightward_return / maxf(reference_span, 0.01), 0.0, 1.0)
		# Natural returns commonly stop short of the hook pose. Square-root response
		# preserves exact lower/pull anchors while making useful partial cock-backs
		# contribute enough continuous load to meet the physical timing target.
		_smooth_fight_load(0.0 if raw_fight_load <= LOAD_DEADBAND else sqrt(raw_fight_load), delta)
		var clearly_toward_pull := rightward_return >= FIGHT_PULL_RETURN_TRAVEL_DEGREES + FIGHT_RETURN_HYSTERESIS_DEGREES
		if fight_phase == "PULL BACK" and clearly_toward_pull and gyro.length() >= FIGHT_GYRO_MINIMUM and _fight_transition_elapsed >= FIGHT_MIN_TRANSITION_SECONDS:
			fight_phase = "LOWER ROD"
			_fight_transition_elapsed = 0.0
			event.fight_pull = true
		elif fight_phase == "LOWER ROD" and left_travel >= FIGHT_LOWER_TRAVEL_DEGREES and gyro.length() >= FIGHT_GYRO_MINIMUM and _fight_transition_elapsed >= FIGHT_MIN_TRANSITION_SECONDS:
			_fight_lower_reference = pose
			fight_phase = "PULL BACK"
			fight_load = 0.0
			_fight_transition_elapsed = 0.0
			event.fight_lower = true
	event.fight_load = fight_load
	event.fight_phase = fight_phase

func _update_calibration(delta: float, reading: Dictionary) -> Dictionary:
	var linear: Vector3 = reading.linear
	var gyro: Vector3 = reading.gyro
	var event := {"cast_arm": false, "cast_quality": 0.0, "hook": false, "calibration_complete": false, "calibration_tick": false}
	if calibration_phase == "settling":
		if linear.length() <= 0.75 and gyro.length() <= 0.35:
			_settle_elapsed += delta
			_settle_noise_peak = maxf(_settle_noise_peak, linear.length())
			_settle_gyro_peak = maxf(_settle_gyro_peak, gyro.length())
		else:
			_settle_elapsed = 0.0
		if _settle_elapsed >= SETTLE_DWELL_SECONDS:
			calibration_phase = "practice_%d_back" % (calibration_progress + 1)
		return event
	if _back_axis == Vector3.ZERO:
		if linear.length() >= 2.0 / maxf(sensitivity, 0.5) and linear.normalized().dot(_back_axis_direction()) >= CALIBRATION_HANDEDNESS_ALIGNMENT and gyro.length() >= 0.16:
			diagnostics.cock_attempts += 1
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
	var handed_match := linear.normalized().dot(_forward_axis()) if linear.length() > 0.0 else -1.0
	if forward_projection >= maxf(2.4 / maxf(sensitivity, 0.5), _back_peak * 0.72) and forward_match >= 0.62 and handed_match >= CALIBRATION_HANDEDNESS_ALIGNMENT and gyro.length() >= 0.16:
		_accept_calibration_example(forward_projection, gyro.length())
		event.calibration_tick = true
		if calibration_progress >= PROFILE_EXAMPLES:
			event.calibration_complete = _finish_calibration()
		return event
	if linear.length() > 0.0 and absf(linear.normalized().dot(_back_axis)) < 0.45: _fail("calibration", "axis")
	return event

func _retry_calibration_example() -> void:
	reset_gesture()
	calibration_phase = "practice_%d_back" % (calibration_progress + 1)

func _accept_calibration_example(forward_peak: float, gyro_peak: float) -> void:
	_calibration_examples.append({"forward_axis": _vector_to_array(-_back_axis), "back_peak": _back_peak, "forward_peak": forward_peak, "gyro_peak": maxf(_back_gyro_peak, gyro_peak), "transition_seconds": _gesture_elapsed, "noise_floor": _settle_noise_peak, "direction_tolerance": 0.62})
	calibration_progress = _calibration_examples.size()
	diagnostics.completed_casts += 1
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
	if axis.dot(_forward_axis()) < PROFILE_HANDEDNESS_ALIGNMENT:
		begin_calibration()
		return false
	for example in _calibration_examples:
		if _array_to_vector(example.forward_axis).normalized().dot(axis) < 0.70:
			begin_calibration()
			return false
	profile = {"forward_axis": _vector_to_array(axis), "back_peak": _average("back_peak"), "forward_peak": _average("forward_peak"), "gyro_peak": _robust_gyro_peak(), "transition_seconds": _average("transition_seconds"), "noise_floor": _average("noise_floor"), "direction_tolerance": 0.62}
	if not validate_profile(profile, left_handed):
		begin_calibration()
		return false
	calibration_phase = "complete"
	return true

func _average(key: String) -> float:
	var total := 0.0
	for example in _calibration_examples:
		total += float(example[key])
	return total / float(_calibration_examples.size())

func _robust_gyro_peak() -> float:
	var lowest := INF
	for example in _calibration_examples: lowest = minf(lowest, float(example.gyro_peak))
	return lowest

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
		var handed_match := linear.normalized().dot(_back_axis_direction()) if linear.length() > 0.0 else -1.0
		if _new_candidate("cock", back_projection, _back_threshold()):
			diagnostics.cock_attempts += 1
			if back_projection >= _back_threshold() and back_match >= float(profile.direction_tolerance) and handed_match >= RUNTIME_X_POLARITY_ALIGNMENT and gyro.length() >= _gyro_threshold():
				_back_axis = -axis; _back_peak = back_projection; _back_gyro_peak = gyro.length(); _gesture_elapsed = 0.0; event.cast_arm = true
			else:
				# Keep one derived failure per continuous candidate burst. A new
				# opposite/quiet projection clears this latch in _new_candidate.
				_candidate_latched.cock = true
				_classify_failure(linear, gyro, back_match, handed_match, _back_threshold(), "cock")
		return
	_gesture_elapsed += delta
	if _gesture_elapsed > MAX_TRANSITION_SECONDS:
		_fail("snap", "timeout"); reset_gesture()
		return
	var forward_projection := linear.dot(axis)
	var forward_match := linear.normalized().dot(axis) if linear.length() > 0.0 else -1.0
	var handed_match := linear.normalized().dot(_forward_axis()) if linear.length() > 0.0 else -1.0
	if _new_candidate("snap", forward_projection, _forward_threshold()):
		if forward_projection >= _forward_threshold() and forward_match >= _snap_axis_tolerance() and handed_match >= _snap_polarity_tolerance() and gyro.length() >= _gyro_threshold():
			event.cast_quality = _cast_quality(forward_projection); diagnostics.completed_casts += 1; reset_gesture(); _cooldown_elapsed = GESTURE_COOLDOWN_SECONDS
		else:
			_candidate_latched.snap = true
			_classify_failure(linear, gyro, forward_match, handed_match, _forward_threshold(), "snap")

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
	var handed_match := linear.normalized().dot(_back_axis_direction()) if linear.length() > 0.0 else -1.0
	if not _new_candidate("hook", back_projection, _hook_threshold()): return false
	diagnostics.hook_attempts += 1
	if back_projection >= _hook_threshold() and back_match >= float(profile.direction_tolerance) * 0.82 and handed_match >= RUNTIME_X_POLARITY_ALIGNMENT and gyro.length() >= _gyro_threshold() * 0.65:
		_cooldown_elapsed = GESTURE_COOLDOWN_SECONDS
		return true
	_candidate_latched.hook = true
	_classify_failure(linear, gyro, back_match, handed_match, _hook_threshold(), "hook")
	return false

func _back_threshold() -> float:
	return maxf(float(profile.noise_floor) * 1.6, float(profile.back_peak) * 0.42) / maxf(sensitivity, 0.5)

func _forward_threshold() -> float:
	return maxf(float(profile.noise_floor) * 1.4, float(profile.forward_peak) * 0.32) / maxf(sensitivity, 0.5)

func _hook_threshold() -> float:
	return maxf(float(profile.noise_floor) * 1.6, float(profile.back_peak) * 0.30) / maxf(sensitivity, 0.5)

func _gyro_threshold() -> float:
	return clampf(float(profile.gyro_peak) * 0.16 / maxf(sensitivity, 0.5), 0.10, 0.60)

func _snap_axis_tolerance() -> float:
	return maxf(SNAP_MIN_AXIS_TOLERANCE, float(profile.get("direction_tolerance", 0.62)) * SNAP_AXIS_PROFILE_SCALE)

func _snap_polarity_tolerance() -> float:
	return maxf(SNAP_MIN_POLARITY_TOLERANCE, RUNTIME_X_POLARITY_ALIGNMENT * SNAP_POLARITY_SCALE)

func _cast_quality(forward_projection: float) -> float:
	var threshold := _forward_threshold()
	var peak := maxf(float(profile.forward_peak), threshold + 0.01)
	return clampf(0.35 + (forward_projection - threshold) / maxf(peak * 0.80, 0.1) * 0.65, 0.35, 1.0)

func _ease_pose_travel_degrees(pose: Vector3, reference: Vector3) -> float:
	var signed_component := (pose - reference).dot(_forward_axis())
	return rad_to_deg(asin(clampf(signed_component, -1.0, 1.0)))

func _pull_pose_travel_degrees(pose: Vector3, reference: Vector3) -> float:
	var signed_component := (pose - reference).dot(_back_axis_direction())
	return rad_to_deg(asin(clampf(signed_component, -1.0, 1.0)))

func _smooth_fight_load(target: float, delta: float) -> void:
	fight_load = move_toward(fight_load, clampf(target, 0.0, 1.0), maxf(delta, 0.0) / LOAD_RESPONSE_SECONDS)

func _fail(stage: String, reason: String) -> void:
	if not diagnostics.reasons.has(reason): return
	diagnostics.reasons[reason] = int(diagnostics.reasons[reason]) + 1
	if _diagnostic_elapsed >= 0.75:
		print("MOTION_FAIL stage=%s reason=%s count=%d" % [stage, reason, int(diagnostics.reasons[reason])])
		_diagnostic_elapsed = 0.0

func _classify_failure(linear: Vector3, gyro: Vector3, axis_match: float, polarity_match: float, threshold: float, stage: String) -> void:
	var polarity_tolerance := _snap_polarity_tolerance() if stage == "snap" else RUNTIME_X_POLARITY_ALIGNMENT
	var axis_tolerance := _snap_axis_tolerance() if stage == "snap" else float(profile.get("direction_tolerance", 0.62))
	if linear.length() < threshold: _fail(stage, "linear")
	elif polarity_match < polarity_tolerance: _fail(stage, "polarity")
	elif axis_match < axis_tolerance: _fail(stage, "axis")
	elif gyro.length() < _gyro_threshold(): _fail(stage, "gyro")

func _new_candidate(stage: String, directed_projection: float, threshold: float) -> bool:
	# Enter a stage only when energy is already travelling in that stage's learned
	# direction. A cock's taper is negative forward projection, so it clears the
	# snap latch instead of consuming the forthcoming left/forward snap candidate.
	var directional_start := maxf(0.35, threshold * 0.30)
	if directed_projection < directional_start:
		_candidate_latched[stage] = false
		return false
	if bool(_candidate_latched.get(stage, false)): return false
	_candidate_latched[stage] = true
	return true

static func _vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _array_to_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
