class_name BoardState
extends RefCounted

var width: int = 0
var height: int = 0
var cells: Array[String] = []
var reserved_job_by_cell: Dictionary = {}

func _init(level: LevelDefinition) -> void:
	width = level.width
	height = level.height
	cells = level.cells.duplicate()
