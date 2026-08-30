class_name FishDefinition
extends RefCounted

var id: String = "bluegill"
var display_name: String = "Bluegill"
var location_id: String = "pine_lake"
var rarity: float = 1.0
var min_length_cm: float = 14.0
var max_length_cm: float = 31.0
var fight_strength: float = 0.32
var bite_delay_seconds: float = 2.4
var fight_pulse: Array[Dictionary] = [{"duration": 42, "amplitude": 0.35}, {"duration": 72, "amplitude": 0.6}]
var fight_cycle_seconds: float = 1.4

static func bluegill() -> FishDefinition:
	return make("bluegill", "Bluegill", "pine_lake", 0.32, [{"duration": 38, "amplitude": 0.3}, {"duration": 62, "amplitude": 0.58}], 1.4)

static func all_planned() -> Array[FishDefinition]:
	return [bluegill(), make("largemouth_bass", "Largemouth Bass", "pine_lake", 0.58, [{"duration": 92, "amplitude": 0.78}, {"duration": 36, "amplitude": 0.45}], 1.15), make("channel_catfish", "Channel Catfish", "pine_lake", 0.7, [{"duration": 140, "amplitude": 0.68}], 1.8), make("rainbow_trout", "Rainbow Trout", "cedar_river", 0.46, [{"duration": 30, "amplitude": 0.48}, {"duration": 30, "amplitude": 0.48}, {"duration": 30, "amplitude": 0.48}], 0.9), make("smallmouth_bass", "Smallmouth Bass", "cedar_river", 0.63, [{"duration": 58, "amplitude": 0.82}, {"duration": 86, "amplitude": 0.5}], 1.05), make("northern_pike", "Northern Pike", "cedar_river", 0.88, [{"duration": 150, "amplitude": 1.0}, {"duration": 55, "amplitude": 0.72}], 0.72)]

static func make(fish_id: String, name: String, location: String, strength: float, pulse: Array[Dictionary], cycle: float) -> FishDefinition:
	var fish := FishDefinition.new()
	fish.id = fish_id; fish.display_name = name; fish.location_id = location; fish.fight_strength = strength; fish.fight_pulse = pulse; fish.fight_cycle_seconds = cycle
	return fish
