extends SceneTree

const FishDefinition = preload("res://src/domain/fish_definition.gd")
const FishingSession = preload("res://src/domain/fishing_session.gd")
const FightChallenge = preload("res://src/domain/fight_challenge.gd")
const SaveService = preload("res://src/services/save_service.gd")

const LOCATION_ID := "mangrove_flats"
const TARPON_ID := "atlantic_tarpon"
const GRID_SAMPLES := 10000
const SIZE_ROLLS := [0.12, 0.50, 0.96]
const BEHAVIOR_ROLLS := [0.0, 0.37, 0.83]
const FRAME_RATES := [30, 60, 120]
const CHALLENGES := ["relaxed", "standard", "expert"]

var failures: Array[String] = []
var timings: Array[float] = []
var probability_summary: Dictionary = {}
var challenge_timings: Dictionary = {}

func _init() -> void:
	_test_weighted_selection()
	_test_real_tarpon_lifecycle_and_fight()
	_test_save_round_trip()
	if failures.is_empty():
		print("TARPON_DIAGNOSTIC " + JSON.stringify({"probability": probability_summary, "fight_cases": timings.size(), "min_fight_seconds": timings.min() if not timings.is_empty() else 0.0, "max_fight_seconds": timings.max() if not timings.is_empty() else 0.0, "challenge_timings": challenge_timings}))
		print("PASS: Tarpon diagnostic v40")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: %d Tarpon diagnostic assertions" % failures.size())
		quit(1)

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _fish_by_id(fish_id: String) -> FishDefinition:
	for fish in FishDefinition.all_planned():
		if fish.id == fish_id: return fish
	return FishDefinition.bluegill()

func _weighted_intervals(distance_m: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var total := 0.0
	for fish in FishDefinition.for_location(LOCATION_ID): total += fish.rarity * fish.habitat_weight(distance_m)
	var cursor := 0.0
	for fish in FishDefinition.for_location(LOCATION_ID):
		var weight := fish.rarity * fish.habitat_weight(distance_m)
		result.append({"fish_id": fish.id, "start": cursor / total, "end": (cursor + weight) / total, "weight": weight, "total": total})
		cursor += weight
	return result

func _tarpon_roll(distance_m: float) -> float:
	for interval in _weighted_intervals(distance_m):
		if interval.fish_id == TARPON_ID: return (float(interval.start) + float(interval.end)) * 0.5
	return 0.999999

func _quality_for_distance(distance_m: float) -> float:
	return inverse_lerp(FishingSession.MIN_CAST_DISTANCE_M, FishingSession.MAX_CAST_DISTANCE_M, distance_m)

func _test_weighted_selection() -> void:
	var bands := {"near": 12.0, "mid": 24.0, "far": 36.0}
	for band_name in bands:
		var distance_m: float = bands[band_name]
		var intervals := _weighted_intervals(distance_m)
		var expected_ids := ["common_snook", "mangrove_snapper", TARPON_ID]
		expect(intervals.size() == 3 and intervals.map(func(entry): return entry.fish_id) == expected_ids, "%s Mangrove selection has exactly Snook, Snapper, and Tarpon" % band_name)
		var counts := {"common_snook": 0, "mangrove_snapper": 0, TARPON_ID: 0}
		for index in range(GRID_SAMPLES):
			var roll := (float(index) + 0.5) / float(GRID_SAMPLES)
			var selected := FishDefinition.select_weighted(LOCATION_ID, roll, distance_m)
			counts[selected.id] = int(counts.get(selected.id, 0)) + 1
		var tarpon_interval: Dictionary = intervals[2]
		var expected_probability := float(tarpon_interval.weight) / float(tarpon_interval.total)
		var observed_probability := float(counts[TARPON_ID]) / float(GRID_SAMPLES)
		probability_summary[band_name] = {"distance_m": distance_m, "counts": counts, "tarpon_probability": observed_probability, "exact_tarpon_probability": expected_probability, "tarpon_roll_start": float(tarpon_interval.start), "tarpon_roll_end": float(tarpon_interval.end)}
		expect(int(counts.common_snook) > 0 and int(counts.mangrove_snapper) > 0 and int(counts[TARPON_ID]) > 0, "%s uniform grid reaches all three live Mangrove fish" % band_name)
		expect(absf(observed_probability - expected_probability) <= 1.0 / float(GRID_SAMPLES), "%s Tarpon grid rate matches the live weighted interval" % band_name)
		var epsilon := 0.0001
		expect(FishDefinition.select_weighted(LOCATION_ID, maxf(0.0, float(tarpon_interval.start) - epsilon), distance_m).id == "mangrove_snapper" and FishDefinition.select_weighted(LOCATION_ID, float(tarpon_interval.start) + epsilon, distance_m).id == TARPON_ID and FishDefinition.select_weighted(LOCATION_ID, minf(0.999999, float(tarpon_interval.end) - epsilon), distance_m).id == TARPON_ID, "%s Tarpon interval interior and neighboring boundary select the intended fish" % band_name)
	for boundary in [{"distance": 17.999, "band": "near", "expected": "mangrove_snapper"}, {"distance": 18.0, "band": "mid", "expected": "mangrove_snapper"}, {"distance": 29.999, "band": "mid", "expected": "mangrove_snapper"}, {"distance": 30.0, "band": "far", "expected": TARPON_ID}]:
		var distance_m: float = float(boundary.distance)
		var expected_band := str(boundary.band)
		var expected_species := str(boundary.expected)
		for fish in FishDefinition.for_location(LOCATION_ID):
			var expected_weight := fish.habitat_near if expected_band == "near" else (fish.habitat_mid if expected_band == "mid" else fish.habitat_far)
			expect(is_equal_approx(fish.habitat_weight(distance_m), expected_weight), "distance boundary %.3f uses %s habitat weight for %s" % [distance_m, expected_band, fish.id])
		var boundary_session := FishingSession.new()
		boundary_session.set_location(LOCATION_ID, 0.0); boundary_session.set_encounter_rolls(0.90, 0.50, 0.37, 0.50, 0.50); boundary_session.arm_cast(); boundary_session.release_cast(_quality_for_distance(distance_m))
		expect(is_equal_approx(boundary_session.cast_distance_m, distance_m) and boundary_session.fish.id == expected_species, "release_cast at %.3fm selects %s from the correct habitat band" % [distance_m, expected_species])
	var session := FishingSession.new()
	session.set_location(LOCATION_ID, 0.0); session.set_encounter_rolls(_tarpon_roll(36.0), 0.50, 0.37, 0.50, 0.50); session.arm_cast(); session.release_cast(_quality_for_distance(36.0))
	expect(session.fish.id == TARPON_ID and is_equal_approx(session.cast_distance_m, 36.0), "release_cast selects Tarpon after its distance-aware habitat band is known")
	var main_source := FileAccess.get_file_as_string("res://src/ui/main.gd")
	var session_source := FileAccess.get_file_as_string("res://src/domain/fishing_session.gd")
	expect("session.set_encounter_rolls(randf(), randf(), randf(), randf(), randf())" in main_source and "fish = FishDefinition.select_weighted(location_id, selection_roll, cast_distance_m)" in session_source, "runtime injects fresh random encounter rolls before distance-aware release selection")

func _make_live_tarpon(distance_m: float, size_roll: float, behavior_roll: float, challenge: String) -> FishingSession:
	var game := FishingSession.new()
	game.set_location(LOCATION_ID, 0.0)
	game.set_next_cast_challenge(challenge)
	game.set_encounter_rolls(_tarpon_roll(distance_m), size_roll, behavior_roll, 0.50, 0.50)
	expect(game.arm_cast() and game.release_cast(_quality_for_distance(distance_m)), "real Tarpon cast arms and releases")
	expect(game.state == FishingSession.State.LINE_OUT and game.fish.id == TARPON_ID, "injected selection roll produces Tarpon through release_cast, not fish override")
	game.tick(game.bite_wait_seconds)
	expect(game.state == FishingSession.State.BITE, "Tarpon cast progresses from LINE_OUT to BITE")
	game.tick(FishingSession.BITE_CUE_HOLD_SECONDS)
	expect(game.state == FishingSession.State.HOOK_WINDOW, "Tarpon bite progresses from BITE to HOOK_WINDOW")
	expect(game.set_hook() and game.state == FishingSession.State.REELING, "Tarpon hook progresses from HOOK_WINDOW to REELING")
	return game

func _fight_with_delayed_policy(distance_m: float, size_roll: float, behavior_roll: float, challenge: String, fps: int, sustained := false) -> FishingSession:
	var game := _make_live_tarpon(distance_m, size_roll, behavior_roll, challenge)
	var delta := 1.0 / float(fps)
	var target := 1.0 if sustained else 0.68
	var delayed_tension := game.tension
	var next_decision := 0.10
	var tension_history: Array[Dictionary] = []
	for frame in range(60 * fps):
		if game.state != FishingSession.State.REELING: break
		tension_history.append({"at": game.fight_elapsed, "tension": game.tension})
		if not sustained and game.fight_elapsed >= next_decision:
			for sample in tension_history:
				if float(sample.at) <= game.fight_elapsed - 0.30: delayed_tension = float(sample.tension)
			target = 0.10 if delayed_tension >= float(game.challenge_profile.high_warning) else (0.68 if delayed_tension <= float(game.challenge_profile.low_warning) else target)
			next_decision += 0.10
		game.set_rod_load(move_toward(game.rod_load, target, delta / 0.10))
		game.tick(delta)
	return game

func _test_real_tarpon_lifecycle_and_fight() -> void:
	for distance_m in [12.0, 24.0, 36.0]:
		for challenge in CHALLENGES:
			for fps in FRAME_RATES:
				for behavior_roll in BEHAVIOR_ROLLS:
					for size_roll in SIZE_ROLLS:
						var game := _fight_with_delayed_policy(distance_m, size_roll, behavior_roll, challenge, fps)
						expect(game.state == FishingSession.State.CAUGHT and game.fight_elapsed >= FishingSession.MIN_LANDING_SECONDS and game.fight_elapsed <= 24.0, "300ms-delayed pull/ease lands real Tarpon at %.0fm, %s, %dHz, behavior %.2f, size roll %.2f (state=%d elapsed=%.2f)" % [distance_m, challenge, fps, behavior_roll, size_roll, game.state, game.fight_elapsed])
						if game.state == FishingSession.State.CAUGHT:
							timings.append(game.fight_elapsed)
							if not challenge_timings.has(challenge): challenge_timings[challenge] = {"min": game.fight_elapsed, "max": game.fight_elapsed}
							else:
								challenge_timings[challenge].min = minf(float(challenge_timings[challenge].min), game.fight_elapsed)
								challenge_timings[challenge].max = maxf(float(challenge_timings[challenge].max), game.fight_elapsed)
	for challenge in CHALLENGES:
		var sustained := _fight_with_delayed_policy(36.0, 0.50, 0.37, challenge, 60, true)
		expect(sustained.state == FishingSession.State.ESCAPED, "sustained Tarpon pull legitimately escapes in %s rather than proving a selection fault" % challenge)

func _test_save_round_trip() -> void:
	var game := _fight_with_delayed_policy(36.0, 0.96, 0.83, "standard", 60)
	expect(game.state == FishingSession.State.CAUGHT, "record diagnostic earns Tarpon through the live fight state machine")
	if game.state != FishingSession.State.CAUGHT: return
	var save_path := "user://tarpon-diagnostic-save-%d.json" % OS.get_process_id()
	var save := SaveService.new(save_path, func(): return 1700000000)
	save.load_data()
	save.record_catch(game.fish.id, game.catch_length_cm, {"location_id": game.location_id, "fight_seconds": game.fight_elapsed, "cast_distance_m": game.cast_distance_m})
	var restored := SaveService.new(save_path, func(): return 1700000000)
	restored.load_data()
	expect(int(restored.data.catches[TARPON_ID]) == 1 and is_equal_approx(float(restored.data.best_cm[TARPON_ID]), game.catch_length_cm) and restored.history_for_fish(TARPON_ID).size() == 1, "real Tarpon record_catch persists count, best, and history through isolated save reload")
