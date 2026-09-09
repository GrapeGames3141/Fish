class_name FishDefinition
extends RefCounted

var id := "bluegill"
var display_name := "Bluegill"
var location_id := "pine_lake"
var rarity := 1.0
var min_length_cm := 14.0
var max_length_cm := 31.0
var fight_strength := 0.32
var bite_delay_seconds := 2.4
var fight_pulse: Array[Dictionary] = [{"duration": 42, "amplitude": 0.35}, {"duration": 72, "amplitude": 0.6, "gap": 0.12}]
var fight_cycle_seconds := 1.4
## Per-species fight cadence. Values are deliberately data-only so deterministic
## replays can inject a behavior roll without reaching into UI code.
var run_seconds := 0.82
var lull_seconds := 0.72
var run_pressure := 0.16
var strain_rate := 0.22
var recovery_rate := 0.46
var pull_efficiency := 0.17
var habitat_near := 1.0
var habitat_mid := 1.0
var habitat_far := 1.0

static func bluegill() -> FishDefinition:
	return make("bluegill", "Bluegill", "pine_lake", 4.2, 14.0, 31.0, 0.32, 2.4, [{"duration": 38, "amplitude": 0.30}, {"duration": 62, "amplitude": 0.58, "gap": 0.12}], 1.40, [0.48, 0.92, 0.10, 0.18, 0.58, 0.30, 1.65, 1.05, 0.55])

static func all_planned() -> Array[FishDefinition]:
	return [bluegill(), make("largemouth_bass", "Largemouth Bass", "pine_lake", 2.1, 28.0, 61.0, 0.58, 2.9, [{"duration": 92, "amplitude": 0.78}, {"duration": 36, "amplitude": 0.45, "gap": 0.18}], 1.15, [1.20, 0.70, 0.18, 0.28, 0.40, 0.31, 1.35, 1.20, 0.80]), make("channel_catfish", "Channel Catfish", "pine_lake", 1.2, 32.0, 76.0, 0.70, 3.4, [{"duration": 140, "amplitude": 0.68}], 1.80, [1.55, 0.45, 0.16, 0.31, 0.30, 0.52, 0.65, 0.95, 1.55]), make("rainbow_trout", "Rainbow Trout", "cedar_river", 3.6, 23.0, 53.0, 0.46, 2.1, [{"duration": 30, "amplitude": 0.48}, {"duration": 30, "amplitude": 0.48, "gap": 0.09}, {"duration": 30, "amplitude": 0.48, "gap": 0.09}], 0.90, [0.42, 0.62, 0.20, 0.23, 0.60, 0.30, 1.45, 1.15, 0.65]), make("smallmouth_bass", "Smallmouth Bass", "cedar_river", 2.2, 24.0, 52.0, 0.63, 2.6, [{"duration": 58, "amplitude": 0.82}, {"duration": 86, "amplitude": 0.50, "gap": 0.15}], 1.05, [0.86, 0.62, 0.20, 0.29, 0.44, 0.31, 0.80, 1.30, 1.10]), make("northern_pike", "Northern Pike", "cedar_river", 0.9, 46.0, 103.0, 0.88, 3.7, [{"duration": 150, "amplitude": 1.0}, {"duration": 55, "amplitude": 0.72, "gap": 0.16}], 0.72, [1.05, 0.48, 0.30, 0.39, 0.34, 0.72, 0.35, 0.85, 1.80])]

static func for_location(location: String) -> Array[FishDefinition]:
	var result: Array[FishDefinition] = []
	for fish in all_planned():
		if fish.location_id == location: result.append(fish)
	return result

static func select_weighted(location: String, roll: float, distance_m := -1.0) -> FishDefinition:
	var candidates := for_location(location)
	if candidates.is_empty(): return bluegill()
	var total := 0.0
	for fish in candidates: total += fish.rarity * fish.habitat_weight(distance_m)
	var target := clampf(roll, 0.0, 0.999999) * total
	for fish in candidates:
		target -= fish.rarity * fish.habitat_weight(distance_m)
		if target <= 0.0: return fish
	return candidates.back()

func habitat_weight(distance_m: float) -> float:
	if distance_m < 0.0: return 1.0
	if distance_m < 18.0: return habitat_near
	if distance_m < 30.0: return habitat_mid
	return habitat_far

func habitat_name(distance_m: float) -> String:
	if location_id == "cedar_river":
		if distance_m < 18.0: return "NEAR EDDY"
		if distance_m < 30.0: return "CURRENT SEAM"
		return "DEEP RUN"
	if distance_m < 18.0: return "REED EDGE"
	if distance_m < 30.0: return "OPEN POCKET"
	return "OUTER COVER"

static func make(fish_id: String, name: String, location: String, weight: float, min_size: float, max_size: float, strength: float, delay: float, pulse: Array[Dictionary], cycle: float, behavior: Array[float] = []) -> FishDefinition:
	var fish := FishDefinition.new()
	fish.id = fish_id; fish.display_name = name; fish.location_id = location; fish.rarity = weight
	fish.min_length_cm = min_size; fish.max_length_cm = max_size; fish.fight_strength = strength; fish.bite_delay_seconds = delay
	fish.fight_pulse = pulse; fish.fight_cycle_seconds = cycle
	if behavior.size() == 9:
		fish.run_seconds = behavior[0]; fish.lull_seconds = behavior[1]; fish.run_pressure = behavior[2]; fish.strain_rate = behavior[3]; fish.recovery_rate = behavior[4]; fish.pull_efficiency = behavior[5]; fish.habitat_near = behavior[6]; fish.habitat_mid = behavior[7]; fish.habitat_far = behavior[8]
	return fish
