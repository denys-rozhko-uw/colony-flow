class_name LevelDefinition
extends RefCounted

var id: String = ""
var revision: int = 1
var title: String = ""
var width: int = 0
var height: int = 0
var cells: Array[String] = []
var palette: Dictionary = {}
var boxes: Array[BoxDefinition] = []
var solution_order: Array[String] = []
var tutorial_id: String = ""

func _init(source: Dictionary = {}) -> void:
	id = str(source.get("id", ""))
	revision = int(source.get("revision", 1))
	title = str(source.get("title", ""))
	width = int(source.get("width", 0))
	height = int(source.get("height", 0))
	palette = source.get("palette", {}).duplicate(true)
	for row: Array in source.get("cells", []):
		for cell: Variant in row:
			cells.append("" if cell == null else str(cell))
	for box: Dictionary in source.get("boxes", []):
		boxes.append(BoxDefinition.new(box))
	for box_id: Variant in source.get("solution_order", []):
		solution_order.append(str(box_id))
	if source.get("tutorial_id") != null:
		tutorial_id = str(source.get("tutorial_id"))

func cell_id(x: int, y: int) -> int:
	return y * width + x

func box_by_id(box_id: String) -> BoxDefinition:
	for box: BoxDefinition in boxes:
		if box.id == box_id:
			return box
	return null
