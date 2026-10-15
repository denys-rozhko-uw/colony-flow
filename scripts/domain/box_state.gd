class_name BoxState
extends RefCounted

enum Location { SUPPLY, ACTIVE, COMPLETED }

var definition: BoxDefinition
var delivered: int = 0
var in_flight: int = 0
var location: Location = Location.SUPPLY
var slot_index: int = -1

func _init(source: BoxDefinition) -> void:
	definition = source

func remaining() -> int:
	return definition.quota - delivered
