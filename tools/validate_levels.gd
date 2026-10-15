extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var repository: LevelRepository = LevelRepository.new()
	if not repository.load_manifest():
		printerr(repository.last_error)
		quit(1)
		return
	var failed: bool = false
	for entry: Dictionary in repository.manifest:
		var result: LevelLoadResult = repository.load_level(entry.id)
		if not result.is_ok():
			failed = true
			for error: String in result.errors:
				printerr(error)
	print("Проверено уровней: ", repository.manifest.size())
	quit(1 if failed else 0)
