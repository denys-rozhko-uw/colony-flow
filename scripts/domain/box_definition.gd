class_name BoxDefinition
extends RefCounted

var id: String = ""
var color_id: String = ""
var quota: int = 0
var blocked_by: Array[String] = []
var ui_column: int = 0
var ui_row: int = 0

func _init(source: Dictionary = {}) -> void:
	id = str(source.get("id", ""))
	color_id = str(source.get("color_id", ""))
	quota = int(source.get("quota", 0))
	for item: Variant in source.get("blocked_by", []):
		blocked_by.append(str(item))
	ui_column = int(source.get("ui_column", 0))
	ui_row = int(source.get("ui_row", 0))
