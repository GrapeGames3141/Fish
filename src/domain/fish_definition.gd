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

static func bluegill() -> FishDefinition:
	return FishDefinition.new()
