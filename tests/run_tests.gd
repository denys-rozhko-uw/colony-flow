extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var requested_suite: String = ""
	var self_test_failure: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			requested_suite = argument.trim_prefix("--suite=")
		elif argument == "--self-test-failure":
			self_test_failure = true
	if self_test_failure:
		_check(false, "intentional runner self-test")
		print("Checks: ", checks, "; failures: ", failures.size())
		quit(1)
		return
	var suites: Array[String] = ["content", "domain", "integration", "save"]
	if not requested_suite.is_empty() and not suites.has(requested_suite):
		_fail("Unknown suite: " + requested_suite)
	else:
		if requested_suite.is_empty() or requested_suite == "content":
			_content_suite()
		if requested_suite.is_empty() or requested_suite == "domain":
			_domain_suite()
		if requested_suite.is_empty() or requested_suite == "integration":
			await _integration_suite()
		if requested_suite.is_empty() or requested_suite == "save":
			_save_suite()
	print("Checks: ", checks, "; failures: ", failures.size())
	for failure: String in failures:
		printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() and checks > 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		_fail(label)

func _fail(label: String) -> void:
	failures.append(label)

func _content_suite() -> void:
	var repository: LevelRepository = LevelRepository.new()
	_check(repository.load_manifest(), "manifest: " + repository.last_error)
	if repository.manifest.is_empty():
		return
	var result: LevelLoadResult = repository.load_level("level_001")
	_check(result.is_ok(), "level_001: " + ", ".join(result.errors))
	if not result.is_ok():
		return
	_check(result.level.cells.size() == 4, "2x2 cells")
	for level_id: String in ["level_004", "level_005"]:
		var trap_result: LevelLoadResult = repository.load_level(level_id)
		_check(trap_result.is_ok(), level_id + " loads for trap check")
		if not trap_result.is_ok():
			continue
		var trap_game: Simulation = Simulation.new(trap_result.level)
		var wrong_order: Array = ["b_coral", "b_cyan", "b_mint", "b_rose", "b_gold"] if level_id == "level_004" else ["b_cyan", "b_mint", "b_rose", "b_gold", "b_leaf"]
		for box_id: String in wrong_order:
			trap_game.enqueue_activate(box_id)
			trap_game.step()
		_check(trap_game.status == "LOST", level_id + " five premature boxes lose")
	var raw: Dictionary = _fixture()
	raw["width"] = 2.5
	_check(not LevelValidator.validate(raw).is_empty(), "fractional width rejected")
	raw = _fixture()
	raw["cells"] = [["blue", "blue"], ["red", "green"]]
	_check(not LevelValidator.validate(raw).is_empty(), "unknown color rejected")
	raw = _fixture()
	raw["boxes"][0]["blocked_by"] = ["b_blue"]
	_check(not LevelValidator.validate(raw).is_empty(), "cycle rejected")
	for fixture_name: String in ["valid_2x2", "valid_holes", "valid_split_color", "valid_branches"]:
		var source: String = FileAccess.get_file_as_string("res://tests/fixtures/" + fixture_name + ".json")
		var fixture: Variant = JSON.parse_string(source)
		_check(LevelValidator.validate(fixture).is_empty(), fixture_name + " validates")
	for fixture_name: String in ["fractional_width", "fractional_quota", "unknown_color", "wrong_width", "empty_board", "extra_field", "duplicate_box", "missing_reference", "cycle", "quota_mismatch", "future_schema", "wrong_ruleset", "duplicate_position"]:
		var source: String = FileAccess.get_file_as_string("res://tests/fixtures/invalid_" + fixture_name + ".json")
		var fixture: Variant = JSON.parse_string(source)
		_check(not LevelValidator.validate(fixture).is_empty(), "invalid_" + fixture_name + " rejected")
	var invalid_json: JSON = JSON.new()
	_check(invalid_json.parse(FileAccess.get_file_as_string("res://tests/fixtures/invalid_json.txt")) != OK, "broken JSON rejected")

func _domain_suite() -> void:
	var level: LevelDefinition = LevelDefinition.new(_fixture())
	var simulation: Simulation = Simulation.new(level)
	_check(simulation.available_box_ids() == ["b_red"], "initially available box")
	simulation.enqueue_activate("b_blue")
	var events: Array[Dictionary] = simulation.step()
	_check(_contains_kind(events, "command_rejected"), "blocked box rejected")
	_check(simulation.validate_invariants().is_empty(), "invariants after rejection")
	simulation.enqueue_activate("b_red")
	simulation.enqueue_activate("b_red")
	events = simulation.step()
	_check(_count_kind(events, "command_accepted") == 1, "double activation")
	_check(_count_kind(events, "command_rejected") == 1, "repeat rejected")
	_check(simulation.available_box_ids().has("b_blue"), "dependent box unlocked")
	for index: int in 100:
		if simulation.is_quiescent():
			break
		simulation.step()
		_check(simulation.validate_invariants().is_empty(), "invariants red tick " + str(index))
	_check(simulation.boxes["b_red"].delivered == 2, "red delivered")
	simulation.enqueue_activate("b_blue")
	simulation.step()
	for index: int in 100:
		if simulation.status != "PLAYING":
			break
		simulation.step()
		_check(simulation.validate_invariants().is_empty(), "invariants blue tick " + str(index))
	_check(simulation.status == "WON", "first level won")
	var turnover: Simulation = Simulation.new(level)
	turnover.enqueue_activate("b_red")
	turnover.step()
	for index: int in 3:
		turnover.step()
	turnover.enqueue_activate("b_blue")
	var turnover_events: Array[Dictionary] = turnover.step()
	_check(_contains_kind(turnover_events, "box_completed") and _contains_kind(turnover_events, "command_accepted"), "completed slot accepts next box in same tick")
	_check(turnover.slots[0] == "b_blue", "first free slot reused")
	var returning: Simulation = Simulation.new(level)
	returning.enqueue_activate("b_red")
	for index: int in 5:
		returning.step()
	returning.enqueue_activate("b_blue")
	for index: int in 3:
		returning.step()
	_check(returning.cells.all(func(cell: String) -> bool: return cell.is_empty()) and not returning.jobs.is_empty() and returning.status == "PLAYING", "empty board with returning cargo has not won")
	var trap: LevelDefinition = LevelDefinition.new(_trap_fixture())
	var six: Simulation = Simulation.new(trap)
	for box_id: String in ["a", "b", "c", "d", "e", "f"]:
		six.enqueue_activate(box_id)
	var six_events: Array[Dictionary] = six.step()
	_check(_count_kind(six_events, "command_accepted") == 5 and _count_kind(six_events, "command_rejected") == 1, "sixth simultaneous command rejected")
	var bad: Simulation = Simulation.new(trap)
	for box_id: String in ["a", "b", "c", "d", "e"]:
		bad.enqueue_activate(box_id)
		bad.step()
	_check(bad.status == "LOST", "five blocked slots lose")
	_check(bad.step().is_empty(), "loss event emitted only once")
	var good: Simulation = Simulation.new(trap)
	for box_id: String in ["f", "a", "b", "c", "d", "e"]:
		good.enqueue_activate(box_id)
		good.step()
		for index: int in 100:
			if good.status != "PLAYING" or good.is_quiescent():
				break
			good.step()
	_check(good.status == "WON", "correct box order wins")
	_check(good.step().is_empty(), "win event emitted only once")
	var bad_witness: Dictionary = _trap_fixture()
	bad_witness["solution_order"] = ["a", "b", "c", "d", "e", "f"]
	_check(not SolutionVerifier.verify(LevelDefinition.new(bad_witness)).ok, "verifier rejects blocked witness")
	var moving_fixture: Dictionary = _trap_fixture()
	moving_fixture["cells"] = [["f", "f", "f", "f", "f"], ["a", "b", "c", "d", "e"]]
	var moving: Simulation = Simulation.new(LevelDefinition.new(moving_fixture))
	for box_id: String in ["a", "b", "c", "d", "e"]:
		moving.enqueue_activate(box_id)
	var moving_events: Array[Dictionary] = moving.step()
	_check(moving.status == "PLAYING" and moving.jobs.size() == 5, "full slots with moving ants continue")
	_check(_count_kind(moving_events, "job_started") == 5, "each box gets one job")
	for index: int in 4:
		moving_events = moving.step()
	_check(_count_kind(moving_events, "block_delivered") == 5, "simultaneous jobs deliver in one tick")
	var prior_id: int = 0
	for event: Dictionary in moving_events:
		if event.kind == "block_delivered":
			_check(event.job_id > prior_id, "simultaneous deliveries ordered by job ID")
			prior_id = event.job_id
	var board: Array[String] = ["blue", "blue", "red", "red"]
	var targets: Array[Dictionary] = ReachabilityPolicy.find_targets(board, 2, 2, {})
	_check(targets.size() == 2 and targets[0].color_id == "red", "only bottom targets reachable")
	board[2] = ""
	targets = ReachabilityPolicy.find_targets(board, 2, 2, {})
	_check(targets.any(func(target: Dictionary) -> bool: return target.cell_id == 0), "removed bottom block opens top")
	var sealed: Array[String] = ["red", "red", "red", "red", "blue", "red", "", "red", "red"]
	targets = ReachabilityPolicy.find_targets(sealed, 3, 3, {})
	_check(not targets.any(func(target: Dictionary) -> bool: return target.cell_id == 4), "diagonal gap does not expose target")
	var reserved_board: Array[String] = ["blue", "red"]
	targets = ReachabilityPolicy.find_targets(reserved_board, 1, 2, {1: 1})
	_check(targets.is_empty(), "reserved bottom block remains obstacle")
	var tied: Array[String] = ["red", "red"]
	targets = ReachabilityPolicy.find_targets(tied, 2, 1, {})
	_check(targets.size() == 2 and targets[0].cell_id == 0 and targets[1].cell_id == 1, "equal-distance targets use cell ID")
	var split_source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/valid_split_color.json"))
	var split: Simulation = Simulation.new(LevelDefinition.new(split_source))
	split.enqueue_activate("b_red")
	split.enqueue_activate("b_red_2")
	var split_events: Array[Dictionary] = split.step()
	_check(_count_kind(split_events, "job_started") == 2 and split.reserved.size() == 2, "same-color boxes reserve distinct targets")
	for index: int in 10:
		if split.is_quiescent():
			break
		split.step()
	split.enqueue_activate("b_blue")
	split.step()
	for index: int in 10:
		if split.status != "PLAYING":
			break
		split.step()
	_check(split.status == "WON", "split-color level wins")
	var replay_a: Simulation = Simulation.new(level)
	var replay_b: Simulation = Simulation.new(level)
	replay_a.enqueue_activate("b_red")
	replay_b.enqueue_activate("b_red")
	for index: int in 20:
		var a_events: Array[Dictionary] = replay_a.step()
		var b_events: Array[Dictionary] = replay_b.step()
		_check(a_events == b_events, "deterministic events tick " + str(index))
	var snap: GameSnapshot = replay_a.get_snapshot()
	snap.cells[0] = "corrupt"
	_check(replay_a.cells[0] != "corrupt", "snapshot cannot mutate model")

func _integration_suite() -> void:
	var session: GameSession = GameSession.new()
	session.start_level(LevelDefinition.new(_fixture()))
	session.activate_box("b_red")
	session.activate_box("b_red")
	_check(session.simulation.commands.size() == 1, "duplicate UI input in one tick queues one command")
	session._process(0.05)
	_check(session.simulation.tick == 0, "partial delta does not tick")
	session._process(0.05)
	_check(session.simulation.tick == 1, "accumulated delta ticks once")
	session.set_paused(true)
	session._process(10.0)
	_check(session.simulation.tick == 1, "pause stops model")
	session.set_paused(false)
	session._process(0.1)
	_check(session.simulation.tick == 2, "resume has no catch-up")
	var old_id: int = session.session_id
	session.restart()
	_check(session.session_id > old_id and session.simulation.tick == 0 and session.simulation.jobs.is_empty(), "restart discards old jobs")
	session.activate_box("b_red")
	for index: int in 3:
		session._process(0.1)
	_check(session.simulation.jobs.any(func(job: JobState) -> bool: return job.phase == JobState.Phase.RETURNING), "job reached return phase")
	session.restart()
	_check(session.simulation.jobs.is_empty() and session.simulation.cells == session.level.cells, "restart during return restores board")
	session._process(3.0)
	_check(session.simulation.tick == GameSession.MAX_TICKS_PER_FRAME, "large delta respects frame budget")
	session._process(0.0)
	_check(session.simulation.tick == GameSession.MAX_TICKS_PER_FRAME * 2, "unplayed ticks remain queued")
	session.free()
	var fps_results: Array[Dictionary] = []
	for frames_per_second: int in [30, 60, 144]:
		var timed: GameSession = GameSession.new()
		var event_kinds: Array[String] = []
		timed.events_ready.connect(func(events: Array[Dictionary], _id: int) -> void:
			for event: Dictionary in events:
				event_kinds.append(event.kind)
		)
		timed.start_level(LevelDefinition.new(_fixture()))
		timed.activate_box("b_red")
		for index: int in frames_per_second:
			timed._process(1.0 / float(frames_per_second))
		timed.activate_box("b_blue")
		for index: int in frames_per_second:
			timed._process(1.0 / float(frames_per_second))
		fps_results.append({"status": timed.state, "tick": timed.simulation.tick, "events": event_kinds.duplicate()})
		timed.free()
	_check(fps_results[0] == fps_results[1] and fps_results[1] == fps_results[2], "same commands yield same result at 30/60/144 FPS")
	var ui_path: String = "res://tests/.tmp/ui_progress.json"
	var ui_dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ui_path).get_base_dir())
	_check(ui_dir_error == OK, "UI test directory")
	var app_scene: PackedScene = load("res://scenes/app/app_root.tscn")
	var app: Control = app_scene.instantiate()
	app.set("save_service", SaveService.new(ui_path))
	root.add_child(app)
	var game: GameSession = app.get("session")
	if game == null:
		_fail("AppRoot did not create GameSession")
		app.free()
		return
	_check(game.state == "LOADING", "menu starts without ticking a level")
	app.call("_continue_level")
	_check(game.state == "PLAYING" and game.level.id == "level_001", "menu starts first level")
	var initial_children: int = app.get_child_count()
	for restart_index: int in 30:
		game.restart()
	_check(app.get_child_count() == initial_children and game.simulation.jobs.is_empty(), "30 restarts do not grow AppRoot nodes")
	game.set_paused(true)
	_check(app.get("result_overlay") != null, "pause shows modal overlay")
	game.set_paused(false)
	_check(app.get("result_overlay") == null, "resume removes modal overlay")
	app.call("_skip_tutorial")
	_check(not app.get("hint_label").visible, "tutorial hint can be skipped")
	app.call("_show_tutorial")
	var tutorial_dialog: AcceptDialog = null
	for child: Node in app.get_children():
		if child is AcceptDialog:
			tutorial_dialog = child
	_check(tutorial_dialog != null, "tutorial can be replayed")
	if tutorial_dialog != null:
		tutorial_dialog.confirmed.emit()
	app.call("_show_error", "Тестовая ошибка содержимого")
	_check(game.state == "LOADING" and app.get("root_layout") != null, "content error leaves navigable screen")
	app.call("_show_menu")
	app.call("_continue_level")
	await process_frame
	var supply_view: SupplyView = app.get("supply_row")
	var red_button: BoxView = supply_view.buttons["b_red"]
	var touch_position: Vector2 = root.get_final_transform() * red_button.get_global_rect().get_center()
	var touch_down: InputEventScreenTouch = InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.position = touch_position
	touch_down.pressed = true
	Input.parse_input_event(touch_down)
	await process_frame
	var touch_up: InputEventScreenTouch = InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.position = touch_position
	touch_up.pressed = false
	Input.parse_input_event(touch_up)
	await process_frame
	_check(game.simulation.commands.size() == 1 or game.simulation.boxes["b_red"].location == BoxState.Location.ACTIVE, "touch on box activates once")
	game.activate_box("b_red")
	for index: int in 15:
		game._process(0.1)
	var board_view: BoardView = app.get("board_view")
	_check(board_view.snapshot.tick == game.simulation.tick, "view shows latest model snapshot after batched ticks")
	game.activate_box("b_blue")
	for index: int in 20:
		if game.state == "WON":
			break
		game._process(0.1)
	_check(game.state == "WON", "UI session can win")
	var saved_ui: SaveLoadResult = SaveService.new(ui_path).load_progress()
	_check(saved_ui.data.completed_level_ids.has("level_001"), "UI win persists progress")
	_check(bool(app.call("_is_unlocked", 1)), "win unlocks next level")
	_check(not bool(app.call("_is_unlocked", 2)), "later levels remain locked")
	app.call("_show_settings")
	app.call("_set_volume", 0.0, "master_volume")
	_check(AudioServer.is_bus_mute(0), "master mute applies immediately")
	app.call("_set_volume", 0.8, "master_volume")
	app.call("_set_volume", 0.0, "music_volume")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music mute applies immediately")
	app.call("_set_volume", 0.5, "music_volume")
	app.call("_set_boolean", true, "reduced_motion")
	_check(SaveService.new(ui_path).load_progress().data.reduced_motion, "settings persist across load")
	var resumed_app: Control = app_scene.instantiate()
	resumed_app.set("save_service", SaveService.new(ui_path))
	root.add_child(resumed_app)
	resumed_app.call("_continue_level")
	var resumed_game: GameSession = resumed_app.get("session")
	_check(resumed_game.level.id == "level_002", "relaunch continues at newly unlocked level")
	resumed_app.call("_show_menu")
	resumed_app.get("progress").last_selected_level_id = "missing_level"
	resumed_app.call("_continue_level")
	_check(resumed_game.level.id == "level_002", "missing last-selected ID falls back to available level")
	resumed_app.free()
	await process_frame
	var ui_progress: ProgressData = app.get("progress")
	for level_index: int in 19:
		var completed_id: String = "level_%03d" % (level_index + 1)
		if not ui_progress.completed_level_ids.has(completed_id):
			ui_progress.completed_level_ids.append(completed_id)
	app.call("_start_level", 19)
	var ui_blocker_path: String = "res://tests/.tmp/ui_blocker"
	var ui_blocker: FileAccess = FileAccess.open(ui_blocker_path, FileAccess.WRITE)
	ui_blocker.store_string("x")
	ui_blocker.close()
	app.set("save_service", SaveService.new(ui_blocker_path + "/progress.json"))
	for box_id: String in game.level.solution_order:
		if game.state != "PLAYING":
			break
		game.activate_box(box_id)
		game._process(0.1)
		for index: int in 1000:
			if game.state != "PLAYING" or game.simulation.is_quiescent():
				break
			game._process(0.1)
	_check(game.state == "WON" and not app.get("next_button").visible, "last level wins without missing next level")
	_check(not str(app.get("save_warning")).is_empty() and game.state == "WON", "save failure is shown without canceling win")
	app.set("save_service", SaveService.new(ui_path))
	app.call("_retry_save")
	_check(str(app.get("save_warning")).is_empty() and SaveService.new(ui_path).load_progress().data.completed_level_ids.has("level_020"), "retry after save failure persists win")
	app.call("_show_menu")
	_check(game.state == "LOADING" and game.simulation == null, "menu stops unfinished simulation")
	app.call("_continue_level")
	app.call("_request_menu")
	var confirmation: ConfirmationDialog = null
	for child: Node in app.get_children():
		if child is ConfirmationDialog:
			confirmation = child
	_check(confirmation != null and game.state == "PLAYING", "leaving unfinished game asks confirmation")
	if confirmation != null:
		confirmation.confirmed.emit()
		_check(game.state == "LOADING" and game.simulation == null, "confirmed exit stops game")
	app.free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ui_blocker_path))
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(ui_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ui_path + suffix))

func _save_suite() -> void:
	var path: String = "res://tests/.tmp/progress.json"
	var absolute: String = ProjectSettings.globalize_path(path)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	_check(directory_error == OK, "test save directory")
	if directory_error != OK:
		return
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(absolute + suffix)
	var service: SaveService = SaveService.new(path)
	var empty: SaveLoadResult = service.load_progress()
	_check(empty.source == "defaults", "fresh save uses defaults")
	var progress: ProgressData = ProgressData.new()
	progress.music_volume = 0.25
	progress.color_symbols = false
	_check(service.save_progress(progress).is_empty(), "first write succeeds")
	progress.completed_level_ids.append("level_001")
	progress.last_selected_level_id = "level_001"
	_check(service.save_progress(progress).is_empty(), "second write succeeds")
	var loaded: SaveLoadResult = service.load_progress()
	_check(loaded.source == "primary" and loaded.data.completed_level_ids == ["level_001"] and loaded.data.music_volume == 0.25 and not loaded.data.color_symbols, "primary round-trip with settings")
	var corrupt: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	var recovered: SaveLoadResult = service.load_progress()
	_check(recovered.source == "backup" and recovered.data.completed_level_ids.is_empty(), "backup restores prior version")
	_check(service.save_progress(progress).is_empty(), "write after backup recovery")
	var pending: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	pending.store_string(JSON.stringify(progress.to_dictionary()))
	pending.close()
	DirAccess.remove_absolute(absolute)
	var interrupted: SaveLoadResult = SaveService.new(path).load_progress()
	_check(interrupted.source == "backup", "backup survives interruption between primary removal and temp install")
	var resumed: SaveService = SaveService.new(path)
	resumed.load_progress()
	_check(resumed.save_progress(progress).is_empty(), "save resumes after interrupted replacement")
	var broken_primary: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	broken_primary.store_string("broken primary")
	broken_primary.close()
	var broken_backup: FileAccess = FileAccess.open(path + ".bak", FileAccess.WRITE)
	broken_backup.store_string("broken backup")
	broken_backup.close()
	var both_broken: SaveLoadResult = SaveService.new(path).load_progress()
	_check(both_broken.source == "defaults" and not both_broken.warning.is_empty(), "two corrupted files use defaults with warning")
	_check(FileAccess.file_exists(path) and FileAccess.file_exists(path + ".bak"), "corrupt files kept for diagnosis")
	var repair: SaveService = SaveService.new(path)
	repair.load_progress()
	progress.completed_level_ids.append("removed_level_id")
	_check(repair.save_progress(progress).is_empty(), "new valid save after corrupt files")
	_check(SaveService.new(path).load_progress().data.completed_level_ids.has("removed_level_id"), "unknown completed ID preserved")
	var future: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	future.store_string('{"schema_version":99}')
	future.close()
	var future_service: SaveService = SaveService.new(path)
	var readonly: SaveLoadResult = future_service.load_progress()
	_check(readonly.read_only, "future save is read-only")
	_check(not future_service.save_progress(progress).is_empty(), "future save refuses overwrite")
	var blocker_path: String = "res://tests/.tmp/not_a_directory"
	var blocker: FileAccess = FileAccess.open(blocker_path, FileAccess.WRITE)
	blocker.store_string("x")
	blocker.close()
	var denied: SaveService = SaveService.new(blocker_path + "/progress.json")
	_check(not denied.save_progress(progress).is_empty(), "save write failure is reported")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(absolute + suffix)

func _contains_kind(events: Array[Dictionary], kind: String) -> bool:
	return _count_kind(events, kind) > 0

func _count_kind(events: Array[Dictionary], kind: String) -> int:
	var count: int = 0
	for event: Dictionary in events:
		if event.kind == kind:
			count += 1
	return count

func _fixture() -> Dictionary:
	return {"schema_version": 1, "ruleset_id": "frontier_v1", "id": "fixture", "revision": 1, "title": "Fixture", "width": 2, "height": 2, "slot_count": 5, "palette": {"red": {"hex": "#E85A5A", "symbol": "●"}, "blue": {"hex": "#4F8FE8", "symbol": "▲"}}, "cells": [["blue", "blue"], ["red", "red"]], "boxes": [{"id": "b_red", "color_id": "red", "quota": 2, "blocked_by": [], "ui_column": 0, "ui_row": 0}, {"id": "b_blue", "color_id": "blue", "quota": 2, "blocked_by": ["b_red"], "ui_column": 0, "ui_row": 1}], "solution_order": ["b_red", "b_blue"], "tutorial_id": "first_steps"}

func _trap_fixture() -> Dictionary:
	var palette: Dictionary = {}
	var top: Array[String] = []
	var boxes: Array[Dictionary] = []
	var solution: Array[String] = ["f"]
	for letter: String in ["a", "b", "c", "d", "e"]:
		palette[letter] = {"hex": "#FF0000", "symbol": letter}
		top.append(letter)
		boxes.append({"id": letter, "color_id": letter, "quota": 1, "blocked_by": [], "ui_column": boxes.size(), "ui_row": 0})
		solution.append(letter)
	palette["f"] = {"hex": "#0000FF", "symbol": "f"}
	boxes.append({"id": "f", "color_id": "f", "quota": 5, "blocked_by": [], "ui_column": 5, "ui_row": 0})
	return {"schema_version": 1, "ruleset_id": "frontier_v1", "id": "trap", "revision": 1, "title": "Trap", "width": 5, "height": 2, "slot_count": 5, "palette": palette, "cells": [top, ["f", "f", "f", "f", "f"]], "boxes": boxes, "solution_order": solution, "tutorial_id": null}
