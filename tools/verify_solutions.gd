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
			printerr(entry.id, ": невалидный уровень")
			failed = true
			continue
		var verification: Dictionary = SolutionVerifier.verify(result.level)
		if not verification.ok:
			printerr(entry.id, ": решение не прошло; ", verification.reason, ", тик ", verification.tick)
			failed = true
		else:
			print(entry.id, ": WON за ", verification.tick, " тиков")
	quit(1 if failed else 0)
