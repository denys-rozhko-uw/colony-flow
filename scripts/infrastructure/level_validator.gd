class_name LevelValidator
extends RefCounted

const ROOT_KEYS: Array[String] = ["schema_version", "ruleset_id", "id", "revision", "title", "width", "height", "slot_count", "palette", "cells", "boxes", "solution_order", "tutorial_id"]
const BOX_KEYS: Array[String] = ["id", "color_id", "quota", "blocked_by", "ui_column", "ui_row"]

static func validate(source: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not source is Dictionary:
		errors.append("корень должен быть объектом")
		return errors
	var raw: Dictionary = source
	_check_keys(raw, ROOT_KEYS, "", errors)
	if raw.get("schema_version") != 1:
		errors.append("schema_version: нужна версия 1")
	if raw.get("ruleset_id") != "frontier_v1":
		errors.append("ruleset_id: нужен frontier_v1")
	if not raw.get("id") is String or str(raw.get("id", "")).is_empty():
		errors.append("id: нужна строка")
	if not raw.get("title") is String or str(raw.get("title", "")).is_empty():
		errors.append("title: нужна строка")
	_int_range(raw.get("revision"), 1, 2147483647, "revision", errors)
	_int_range(raw.get("width"), 1, 32, "width", errors)
	_int_range(raw.get("height"), 1, 32, "height", errors)
	_int_range(raw.get("slot_count"), 5, 5, "slot_count", errors)
	if raw.get("tutorial_id") != null and not raw.get("tutorial_id") is String:
		errors.append("tutorial_id: нужна строка или null")
	if not _is_whole(raw.get("width")) or not _is_whole(raw.get("height")):
		return errors
	var width: int = int(raw.width)
	var height: int = int(raw.height)
	if width < 1 or width > 32 or height < 1 or height > 32:
		return errors
	var palette: Variant = raw.get("palette")
	if not palette is Dictionary or palette.is_empty() or palette.size() > 8:
		errors.append("palette: нужно 1–8 цветов")
		return errors
	for color_id: Variant in palette.keys():
		var info: Variant = palette[color_id]
		if not color_id is String or not info is Dictionary or not info.get("hex") is String or not Color.html_is_valid(info.get("hex", "")) or not info.get("symbol") is String:
			errors.append("palette." + str(color_id) + ": нужен hex и symbol")
	var counts: Dictionary = {}
	var cells: Variant = raw.get("cells")
	if not cells is Array or cells.size() != height:
		errors.append("cells: неверное число строк")
		return errors
	for y: int in height:
		if not cells[y] is Array or cells[y].size() != width:
			errors.append("cells[" + str(y) + "]: неверная ширина")
			continue
		for x: int in width:
			var color_id: Variant = cells[y][x]
			if color_id == null:
				continue
			if not color_id is String or not palette.has(color_id):
				errors.append("cells[" + str(y) + "][" + str(x) + "]: неизвестный цвет")
				continue
			counts[color_id] = int(counts.get(color_id, 0)) + 1
	if counts.is_empty():
		errors.append("cells: нет блоков")
	var boxes: Variant = raw.get("boxes")
	if not boxes is Array or boxes.is_empty() or boxes.size() > 100:
		errors.append("boxes: нужно 1–100 коробок")
		return errors
	var ids: Dictionary = {}
	var positions: Dictionary = {}
	var quotas: Dictionary = {}
	for index: int in boxes.size():
		var box: Variant = boxes[index]
		var prefix: String = "boxes[" + str(index) + "]"
		if not box is Dictionary:
			errors.append(prefix + ": нужен объект")
			continue
		_check_keys(box, BOX_KEYS, prefix + ".", errors)
		var box_id: Variant = box.get("id")
		var color_id: Variant = box.get("color_id")
		if not box_id is String or box_id.is_empty() or ids.has(box_id):
			errors.append(prefix + ".id: пустой или повторный ID")
		else:
			ids[box_id] = box
		if not color_id is String or not palette.has(color_id):
			errors.append(prefix + ".color_id: неизвестный цвет")
		_int_range(box.get("quota"), 1, 1024, prefix + ".quota", errors)
		_int_range(box.get("ui_column"), 0, 100, prefix + ".ui_column", errors)
		_int_range(box.get("ui_row"), 0, 100, prefix + ".ui_row", errors)
		if _is_whole(box.get("ui_column")) and _is_whole(box.get("ui_row")):
			var position: Vector2i = Vector2i(int(box.ui_column), int(box.ui_row))
			if positions.has(position):
				errors.append(prefix + ": повтор UI-позиции")
			positions[position] = true
		if _is_whole(box.get("quota")) and color_id is String:
			quotas[color_id] = int(quotas.get(color_id, 0)) + int(box.quota)
		if not box.get("blocked_by") is Array:
			errors.append(prefix + ".blocked_by: нужен массив")
	for color_id: Variant in palette.keys():
		if int(quotas.get(color_id, 0)) != int(counts.get(color_id, 0)):
			errors.append("quota " + str(color_id) + ": сумма коробок не равна числу клеток")
	for index: int in boxes.size():
		var box: Variant = boxes[index]
		if not box is Dictionary or not box.get("blocked_by") is Array:
			continue
		var seen: Dictionary = {}
		for predecessor: Variant in box.blocked_by:
			if not predecessor is String or not ids.has(predecessor) or predecessor == box.get("id") or seen.has(predecessor):
				errors.append("boxes[" + str(index) + "].blocked_by: неверная ссылка")
			seen[predecessor] = true
	var visiting: Dictionary = {}
	for box_id: Variant in ids.keys():
		if _has_cycle(box_id, ids, visiting):
			errors.append("boxes.blocked_by: цикл")
			break
	var solution: Variant = raw.get("solution_order")
	if not solution is Array or solution.size() != boxes.size():
		errors.append("solution_order: требуется каждый box_id ровно один раз")
	else:
		var used: Dictionary = {}
		for box_id: Variant in solution:
			if not box_id is String or not ids.has(box_id) or used.has(box_id):
				errors.append("solution_order: неверный или повторный ID")
			used[box_id] = true
	return errors

static func _int_range(value: Variant, min_value: int, max_value: int, path: String, errors: Array[String]) -> void:
	if not _is_whole(value) or value < min_value or value > max_value:
		errors.append(path + ": нужно целое число от " + str(min_value) + " до " + str(max_value))

static func _is_whole(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and floor(value) == value)

static func _check_keys(source: Dictionary, keys: Array[String], prefix: String, errors: Array[String]) -> void:
	for key: String in keys:
		if not source.has(key):
			errors.append(prefix + key + ": обязательное поле")
	for key: Variant in source.keys():
		if not keys.has(key):
			errors.append(prefix + str(key) + ": неизвестное поле")

static func _has_cycle(box_id: String, boxes: Dictionary, state: Dictionary) -> bool:
	if state.get(box_id, 0) == 1:
		return true
	if state.get(box_id, 0) == 2:
		return false
	state[box_id] = 1
	var box: Dictionary = boxes[box_id]
	for predecessor: Variant in box.get("blocked_by", []):
		if predecessor is String and boxes.has(predecessor) and _has_cycle(predecessor, boxes, state):
			return true
	state[box_id] = 2
	return false
