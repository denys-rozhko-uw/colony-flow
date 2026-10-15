extends SceneTree

const WALKTHROUGH_ORDERS: Dictionary = {
	"level_001": ["b_red", "b_blue"],
	"level_002": ["b_leaf", "b_sky", "b_violet"],
	"level_003": ["b_sky", "b_violet", "b_coral", "b_cyan"],
	"level_004": ["b_violet", "b_coral", "b_cyan", "b_mint", "b_rose", "b_gold"],
	"level_005": ["b_coral", "b_cyan", "b_mint", "b_gold", "b_leaf", "b_rose"]
}

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_path: String = "res://tests/.tmp/walkthrough_progress.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	var app: Control = load("res://scenes/app/app_root.tscn").instantiate()
	app.set("save_service", SaveService.new(save_path))
	root.add_child(app)
	var session: GameSession = app.get("session")
	for level_index: int in 20:
		app.call("_start_level", level_index)
		await process_frame
		if session.level == null or session.level.id != "level_%03d" % (level_index + 1):
			failures.append("Уровень " + str(level_index + 1) + " не открылся")
			break
		var chosen_order: Array = WALKTHROUGH_ORDERS.get(session.level.id, session.level.solution_order)
		for box_id: String in chosen_order:
			if session.state != "PLAYING":
				failures.append("Уровень завершился раньше времени: " + session.level.id)
				break
			var supply: SupplyView = app.get("supply_row")
			if not supply.buttons.has(box_id) or supply.buttons[box_id].disabled:
				failures.append("Коробка недоступна: " + box_id)
				break
			var button: BoxView = supply.buttons[box_id]
			var point: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
			var down: InputEventScreenTouch = InputEventScreenTouch.new()
			down.index = 0
			down.position = point
			down.pressed = true
			Input.parse_input_event(down)
			await process_frame
			var up: InputEventScreenTouch = InputEventScreenTouch.new()
			up.index = 0
			up.position = point
			up.pressed = false
			Input.parse_input_event(up)
			await process_frame
			for tick_index: int in 1000:
				if session.state != "PLAYING" or session.simulation.is_quiescent():
					break
				session._process(0.1)
			await process_frame
		if session.state != "WON":
			failures.append("Нет победы: " + session.level.id + " / " + session.state)
			break
		var saved: SaveLoadResult = SaveService.new(save_path).load_progress()
		if not saved.data.completed_level_ids.has(session.level.id):
			failures.append("Не сохранена победа: " + session.level.id)
		print(session.level.id, ": UI touch walkthrough WON")
	app.free()
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure: String in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)
