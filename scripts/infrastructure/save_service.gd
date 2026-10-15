class_name SaveService
extends RefCounted

var base_path: String = "user://progress.json"
var read_only: bool = false
var primary_valid: bool = true

func _init(path: String = "user://progress.json") -> void:
	base_path = path

func load_progress() -> SaveLoadResult:
	var result: SaveLoadResult = SaveLoadResult.new()
	var primary: Dictionary = _read_file(base_path)
	if primary.get("future_version", false):
		read_only = true
		result.read_only = true
		result.warning = "Сохранение создано более новой версией игры. Запись отключена."
		return result
	if primary.has("data"):
		result.data = primary.data
		result.source = "primary"
		primary_valid = true
		return result
	primary_valid = false
	var backup: Dictionary = _read_file(base_path + ".bak")
	if backup.get("future_version", false):
		read_only = true
		result.read_only = true
		result.warning = "Резервная копия создана более новой версией игры. Запись отключена."
		return result
	if backup.has("data"):
		result.data = backup.data
		result.source = "backup"
		result.warning = "Прогресс восстановлен из резервной копии."
		return result
	if primary.get("exists", false) or backup.get("exists", false):
		result.warning = "Сохранение повреждено. Использован новый прогресс; исходные файлы сохранены."
	return result

func save_progress(data: ProgressData) -> String:
	if read_only:
		return "Сохранение более новой версии: запись отключена."
	var directory: String = base_path.get_base_dir()
	var absolute_directory: String = ProjectSettings.globalize_path(directory)
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if mkdir_error != OK:
		return "Не удалось создать каталог: " + error_string(mkdir_error)
	var temp_path: String = base_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return "Не удалось открыть временный файл: " + error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(data.to_dictionary(), "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return "Ошибка записи: " + error_string(write_error)
	if not _read_file(temp_path).has("data"):
		return "Временный файл не прошёл проверку."
	var absolute_primary: String = ProjectSettings.globalize_path(base_path)
	var absolute_backup: String = ProjectSettings.globalize_path(base_path + ".bak")
	var absolute_temp: String = ProjectSettings.globalize_path(temp_path)
	var absolute_backup_temp: String = ProjectSettings.globalize_path(base_path + ".bak.tmp")
	if FileAccess.file_exists(base_path) and primary_valid and _read_file(base_path).has("data"):
		var copy_error: Error = DirAccess.copy_absolute(absolute_primary, absolute_backup_temp)
		if copy_error != OK:
			return "Не удалось подготовить резервную копию: " + error_string(copy_error)
		if FileAccess.file_exists(base_path + ".bak"):
			var remove_old_backup: Error = DirAccess.remove_absolute(absolute_backup)
			if remove_old_backup != OK:
				return "Не удалось заменить резервную копию: " + error_string(remove_old_backup)
		var rotate_error: Error = DirAccess.rename_absolute(absolute_backup_temp, absolute_backup)
		if rotate_error != OK:
			return "Не удалось сохранить резервную копию: " + error_string(rotate_error)
	if FileAccess.file_exists(base_path):
		var remove_error: Error = DirAccess.remove_absolute(absolute_primary)
		if remove_error != OK:
			return "Не удалось заменить сохранение: " + error_string(remove_error)
	var install_error: Error = DirAccess.rename_absolute(absolute_temp, absolute_primary)
	if install_error != OK:
		return "Не удалось установить сохранение: " + error_string(install_error)
	primary_valid = true
	return ""

func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": true}
	var contents: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(contents) != OK or not parser.data is Dictionary:
		return {"exists": true}
	var raw: Dictionary = parser.data
	if raw.get("schema_version") is float and raw.schema_version > 1:
		return {"exists": true, "future_version": true}
	var data: ProgressData = ProgressData.parse(raw)
	if data == null:
		return {"exists": true}
	return {"exists": true, "data": data}
