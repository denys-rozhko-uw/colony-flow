class_name LevelRepository
extends RefCounted

const LEVEL_ROOT: String = "res://data/levels/"

var manifest: Array[Dictionary] = []
var last_error: String = ""

func load_manifest() -> bool:
	manifest.clear()
	last_error = ""
	var raw_result: Dictionary = _read_json(LEVEL_ROOT + "manifest.json")
	if not raw_result.ok:
		last_error = raw_result.error
		return false
	var raw: Variant = raw_result.value
	if not raw is Dictionary or raw.get("schema_version") != 1 or not raw.get("levels") is Array:
		last_error = "manifest.json: неверная схема"
		return false
	var seen: Dictionary = {}
	for item: Variant in raw.levels:
		if not item is Dictionary or not item.get("id") is String or not item.get("path") is String:
			last_error = "manifest.json: неверная запись уровня"
			return false
		var level_id: String = item.id
		var level_path: String = item.path
		if seen.has(level_id) or level_id.is_empty() or not level_path.begins_with(LEVEL_ROOT) or ".." in level_path or not level_path.ends_with(".json"):
			last_error = "manifest.json: повтор ID или недопустимый путь: " + level_id
			return false
		seen[level_id] = true
		manifest.append({"id": level_id, "path": level_path})
	if manifest.is_empty():
		last_error = "manifest.json: список уровней пуст"
		return false
	return true

func load_level(level_id: String) -> LevelLoadResult:
	var result: LevelLoadResult = LevelLoadResult.new()
	var entry: Dictionary = {}
	for candidate: Dictionary in manifest:
		if candidate.id == level_id:
			entry = candidate
			break
	if entry.is_empty():
		result.errors.append("Неизвестный уровень: " + level_id)
		return result
	var raw_result: Dictionary = _read_json(entry.path)
	if not raw_result.ok:
		result.errors.append(raw_result.error)
		return result
	var errors: Array[String] = LevelValidator.validate(raw_result.value)
	if raw_result.value is Dictionary and raw_result.value.get("id") != level_id:
		errors.append("id: не совпадает с manifest")
	if not errors.is_empty():
		for error: String in errors:
			result.errors.append(level_id + ": " + error)
		return result
	result.level = LevelDefinition.new(raw_result.value)
	return result

func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": path + ": невозможно открыть: " + error_string(FileAccess.get_open_error())}
	var text_data: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(text_data)
	if parse_error != OK:
		return {"ok": false, "error": path + ": JSON строка " + str(parser.get_error_line()) + ": " + parser.get_error_message()}
	return {"ok": true, "value": parser.data}
