class_name SupplyState
extends RefCounted

var ordered_box_ids: Array[String] = []
var predecessors_by_id: Dictionary = {}
var activated_ids: Dictionary = {}

func _init(level: LevelDefinition) -> void:
	for box: BoxDefinition in level.boxes:
		ordered_box_ids.append(box.id)
		predecessors_by_id[box.id] = box.blocked_by.duplicate()

func is_unlocked(box_id: String) -> bool:
	if activated_ids.has(box_id):
		return false
	for predecessor: String in predecessors_by_id.get(box_id, []):
		if not activated_ids.has(predecessor):
			return false
	return true
