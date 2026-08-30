class_name MotionService
extends RefCounted

var neutral_gravity := Vector3(0, -9.8, 0)
var sensitivity := 1.0
var simulated := false
var simulated_cast_pending := false
var simulated_hook_pending := false
var _back_seen := false

func calibrate() -> void:
	neutral_gravity = Input.get_gravity()
	if neutral_gravity.length() < 1.0:
		neutral_gravity = Vector3(0, -9.8, 0)

func sample() -> Dictionary:
	var gravity := Input.get_gravity()
	var accelerometer := Input.get_accelerometer()
	var gyro := Input.get_gyroscope()
	return {"gravity": gravity, "accelerometer": accelerometer, "gyro": gyro}

func detect_cast() -> float:
	if simulated_cast_pending:
		simulated_cast_pending = false
		_back_seen = false
		return 0.85
	var acceleration: Vector3 = Input.get_accelerometer()
	var back_threshold := 2.5 * sensitivity
	var forward_threshold := 4.0 * sensitivity
	if acceleration.y < -back_threshold:
		_back_seen = true
	if _back_seen and acceleration.y > forward_threshold:
		_back_seen = false
		return clampf(acceleration.y / 12.0, 0.35, 1.0)
	return 0.0

func detect_hook() -> bool:
	if simulated_hook_pending:
		simulated_hook_pending = false
		return true
	var gravity := Input.get_gravity()
	return gravity.y - neutral_gravity.y > 3.2 * sensitivity

func queue_simulated_cast() -> void:
	simulated_cast_pending = true

func queue_simulated_hook() -> void:
	simulated_hook_pending = true
