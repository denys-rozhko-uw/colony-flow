extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var index: int = 0
	var activate_id: String = ""
	var ticks: int = 0
	var solve: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			index = int(argument.trim_prefix("--level=")) - 1
		elif argument.begins_with("--activate="):
			activate_id = argument.trim_prefix("--activate=")
		elif argument.begins_with("--ticks="):
			ticks = int(argument.trim_prefix("--ticks="))
		elif argument == "--solve":
			solve = true
	if index < 0 or index >= 20:
		printerr("Нужен --level=1..20")
		quit(1)
		return
	var scene: PackedScene = load("res://scenes/app/app_root.tscn")
	var app: Control = scene.instantiate()
	app.set("save_service", SaveService.new("res://tests/.tmp/preview_progress.json"))
	root.add_child(app)
	var progress: ProgressData = app.get("progress")
	for number: int in index:
		progress.completed_level_ids.append("level_%03d" % (number + 1))
	app.call("_start_level", index)
	if solve:
		var game: GameSession = app.get("session")
		for box_id: String in game.level.solution_order:
			if game.state != "PLAYING":
				break
			game.activate_box(box_id)
			game._process(0.1)
			for step_index: int in 10000:
				if game.state != "PLAYING" or game.simulation.is_quiescent():
					break
				game._process(0.1)
	if not activate_id.is_empty():
		var session: GameSession = app.get("session")
		session.activate_box(activate_id)
		for number: int in clampi(ticks, 1, 100):
			session._process(0.1)
	await process_frame
	await process_frame
	var suffix: String = "_won" if solve else ("_active" if not activate_id.is_empty() else "")
	var path: String = "res://builds/preview/level_%03d%s.png" % [index + 1, suffix]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		printerr("Не удалось сохранить кадр: ", error_string(error))
	app.free()
	await process_frame
	await process_frame
	quit(0 if error == OK else 1)
