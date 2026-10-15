extends Control

const BG_COLOR: Color = Color("#161d2b")
const PANEL_COLOR: Color = Color("#283349")

var repository: LevelRepository = LevelRepository.new()
var save_service: SaveService = SaveService.new()
var progress: ProgressData = ProgressData.new()
var save_warning: String = ""
var session: GameSession
var audio_controller: AudioController
var current_level: LevelDefinition
var current_index: int = 0
var root_layout: VBoxContainer
var board_view: BoardView
var slots_row: SlotsView
var supply_row: SupplyView
var status_label: Label
var hint_label: Label
var pause_button: Button
var next_button: Button
var result_overlay: ColorRect

func _ready() -> void:
	_render_background()
	resized.connect(_fit_layout)
	session = GameSession.new()
	add_child(session)
	audio_controller = AudioController.new()
	add_child(audio_controller)
	session.snapshot_changed.connect(_on_snapshot)
	session.events_ready.connect(_on_events)
	session.session_state_changed.connect(_on_state)
	if not repository.load_manifest():
		push_error(repository.last_error)
		_show_error("Не удалось загрузить список уровней. Проверьте файлы игры.")
		return
	var saved: SaveLoadResult = save_service.load_progress()
	progress = saved.data
	save_warning = saved.warning
	audio_controller.apply_settings(progress)
	_show_menu()

func _render_background() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = BG_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func _start_level(index: int) -> void:
	if index < 0 or index >= repository.manifest.size() or not _is_unlocked(index):
		return
	var level_id: String = repository.manifest[index].id
	var result: LevelLoadResult = repository.load_level(level_id)
	if not result.is_ok():
		push_error(", ".join(result.errors))
		_show_error("Уровень повреждён и не может быть открыт. Выберите другой уровень.")
		return
	current_index = index
	current_level = result.level
	_build_screen()
	session.start_level(current_level)
	progress.last_selected_level_id = current_level.id
	_save_progress()

func _new_layout() -> VBoxContainer:
	if root_layout != null:
		root_layout.queue_free()
	root_layout = VBoxContainer.new()
	root_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_layout.add_theme_constant_override("separation", 8)
	root_layout.offset_top = 8
	root_layout.offset_bottom = -8
	add_child(root_layout)
	_fit_layout()
	return root_layout

func _fit_layout() -> void:
	if root_layout == null:
		return
	var content_width: float = minf(480.0, maxf(280.0, size.x - 20.0))
	root_layout.anchor_left = 0.5
	root_layout.anchor_right = 0.5
	root_layout.offset_left = -content_width * 0.5
	root_layout.offset_right = content_width * 0.5

func _show_menu() -> void:
	_clear_overlay()
	session.stop()
	board_view = null
	pause_button = null
	next_button = null
	var layout: VBoxContainer = _new_layout()
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)
	var title: Label = _label("МУРАВЬИНАЯ\nКАРТИНКА", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	var subtitle: Label = _label("Пять слотов. Цветные блоки. Найдите верный порядок.", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(subtitle)
	var center: CenterContainer = CenterContainer.new()
	layout.add_child(center)
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.custom_minimum_size.x = 280
	buttons.add_theme_constant_override("separation", 8)
	center.add_child(buttons)
	buttons.add_child(_button("Продолжить", _continue_level))
	buttons.add_child(_button("Выбор уровня", _show_level_select))
	buttons.add_child(_button("Настройки", _show_settings))
	buttons.add_child(_button("Выход", func() -> void: get_tree().quit()))
	if not save_warning.is_empty():
		var warning: Label = _label(save_warning, 13)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		layout.add_child(warning)
	layout.add_child(_label("Графика и уровни — временные заготовки", 13))
	var bottom: Control = Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(bottom)

func _continue_level() -> void:
	var target: int = 0
	for index: int in repository.manifest.size():
		if _is_unlocked(index) and not progress.completed_level_ids.has(repository.manifest[index].id):
			target = index
			break
	if not progress.last_selected_level_id.is_empty():
		for index: int in repository.manifest.size():
			if repository.manifest[index].id == progress.last_selected_level_id and _is_unlocked(index) and not progress.completed_level_ids.has(progress.last_selected_level_id):
				target = index
	_start_level(target)

func _show_level_select() -> void:
	session.stop()
	var layout: VBoxContainer = _new_layout()
	layout.add_child(_label("ВЫБОР УРОВНЯ", 22))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for index: int in repository.manifest.size():
		var level_id: String = repository.manifest[index].id
		var caption: String = "✓ %02d" % (index + 1) if progress.completed_level_ids.has(level_id) else "%02d" % (index + 1)
		var button: Button = _button(caption, _start_level.bind(index))
		button.custom_minimum_size = Vector2(72, 60)
		button.disabled = not _is_unlocked(index)
		grid.add_child(button)
	layout.add_child(_button("Назад", _show_menu))

func _show_settings() -> void:
	session.stop()
	var layout: VBoxContainer = _new_layout()
	layout.add_child(_label("НАСТРОЙКИ", 22))
	for setting: String in ["master_volume", "music_volume", "sfx_volume"]:
		var title: String = {"master_volume": "Общая громкость", "music_volume": "Музыка", "sfx_volume": "Эффекты"}[setting]
		layout.add_child(_label(title, 15))
		var slider: HSlider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = progress.get(setting)
		slider.custom_minimum_size = Vector2(280, 44)
		slider.value_changed.connect(_set_volume.bind(setting))
		layout.add_child(slider)
	for setting: String in ["reduced_motion", "color_symbols"]:
		var check: CheckBox = CheckBox.new()
		check.text = "Меньше анимации" if setting == "reduced_motion" else "Символы цветов"
		check.button_pressed = progress.get(setting)
		check.toggled.connect(_set_boolean.bind(setting))
		layout.add_child(check)
	layout.add_child(_button("Назад", _show_menu))

func _set_volume(value: float, setting: String) -> void:
	progress.set(setting, value)
	audio_controller.apply_settings(progress)
	_save_progress()

func _set_boolean(value: bool, setting: String) -> void:
	progress.set(setting, value)
	_save_progress()

func _is_unlocked(index: int) -> bool:
	if index == 0:
		return true
	if index < 0 or index >= repository.manifest.size():
		return false
	var level_id: String = repository.manifest[index].id
	var prior_id: String = repository.manifest[index - 1].id
	return progress.completed_level_ids.has(level_id) or progress.completed_level_ids.has(prior_id)

func _save_progress() -> void:
	var problem: String = save_service.save_progress(progress)
	save_warning = problem

func _build_screen() -> void:
	_clear_overlay()
	_new_layout()
	var heading: Label = _label("МУРАВЬИНАЯ КАРТИНКА", 18)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_layout.add_child(heading)
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	root_layout.add_child(top_row)
	top_row.add_child(_label("Уровень %d · %s" % [current_index + 1, current_level.title], 14))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	pause_button = _button("Пауза", _toggle_pause)
	top_row.add_child(pause_button)
	board_view = BoardView.new()
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_layout.add_child(board_view)
	status_label = _label("", 14)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_layout.add_child(status_label)
	root_layout.add_child(_label("ПЯТЬ РАБОЧИХ СЛОТОВ", 14))
	slots_row = SlotsView.new()
	root_layout.add_child(slots_row)
	root_layout.add_child(_label("КОРОБКИ — ВЫБЕРИТЕ ЦВЕТ", 14))
	supply_row = SupplyView.new()
	supply_row.box_selected.connect(session.activate_box)
	root_layout.add_child(supply_row)
	hint_label = _label(_tutorial_message(), 13)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_layout.add_child(hint_label)
	var actions: HBoxContainer = HBoxContainer.new()
	root_layout.add_child(actions)
	actions.add_child(_button("Заново", session.restart))
	actions.add_child(_button("Меню", _request_menu))
	if not current_level.tutorial_id.is_empty():
		actions.add_child(_button("Скрыть", _skip_tutorial))
		actions.add_child(_button("?", _show_tutorial))
	next_button = _button("Следующий", _next_level)
	next_button.visible = false
	actions.add_child(next_button)

func _on_snapshot(snapshot: GameSnapshot, source_id: int) -> void:
	if source_id != session.session_id or current_level == null:
		return
	board_view.show_symbols = progress.color_symbols
	board_view.reduced_motion = progress.reduced_motion
	board_view.display(current_level, snapshot)
	var remaining: int = 0
	for color_id: String in snapshot.cells:
		if not color_id.is_empty():
			remaining += 1
	var busy: int = 0
	for box_id: String in snapshot.slots:
		if not box_id.is_empty():
			busy += 1
	slots_row.display(snapshot, current_level, progress.color_symbols)
	status_label.text = "На поле: %d    В пути: %d    Слоты: %d/5" % [remaining, snapshot.jobs.size(), busy]
	supply_row.display(snapshot, current_level, progress.color_symbols, session.state == "PLAYING")

func _on_events(events: Array[Dictionary], source_id: int) -> void:
	if source_id != session.session_id:
		return
	audio_controller.play_events(events)
	for event: Dictionary in events:
		if event.kind == "command_rejected":
			hint_label.text = "Сейчас эту коробку выбрать нельзя."
		elif event.kind == "level_won":
			hint_label.text = "Картинка собрана! Все блоки доставлены."
		elif event.kind == "level_lost":
			hint_label.text = "Муравьи застряли. Попробуйте другой порядок коробок."

func _on_state(new_state: String) -> void:
	if new_state == "LOADING" or pause_button == null:
		return
	pause_button.text = "Продолжить" if new_state == "PAUSED" else "Пауза"
	pause_button.disabled = new_state == "WON" or new_state == "LOST"
	if new_state == "WON":
		if not progress.completed_level_ids.has(current_level.id):
			progress.completed_level_ids.append(current_level.id)
			_save_progress()
		next_button.visible = current_index + 1 < repository.manifest.size()
	elif new_state == "PLAYING":
		next_button.visible = false
	if new_state == "PAUSED":
		hint_label.text = "Пауза."
	elif new_state == "PLAYING":
		hint_label.text = _tutorial_message()
	if session.simulation != null and board_view != null:
		_on_snapshot(session.simulation.get_snapshot(), session.session_id)
	if new_state == "PLAYING":
		_clear_overlay()
	elif new_state == "PAUSED":
		_show_overlay("Пауза", "Муравьи ждут вашего решения.", false)
	elif new_state == "WON":
		var win_message: String = "Все блоки доставлены. Открыт следующий уровень."
		if not save_warning.is_empty():
			win_message += "\nПрогресс пока не сохранён: " + save_warning
		_show_overlay("Уровень пройден", win_message, true)
	elif new_state == "LOST":
		_show_overlay("Тупик", "Доступных целей и коробок не осталось. Попробуйте другой порядок.", false)

func _clear_overlay() -> void:
	if result_overlay != null:
		result_overlay.queue_free()
		result_overlay = null

func _show_overlay(title: String, description: String, show_picture: bool) -> void:
	_clear_overlay()
	result_overlay = ColorRect.new()
	result_overlay.color = Color(0.05, 0.08, 0.13, 0.86)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.z_index = 10
	add_child(result_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 290
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading: Label = _label(title, 22)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var detail: Label = _label(description, 14)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	if show_picture:
		var picture: BoardView = BoardView.new()
		picture.custom_minimum_size = Vector2(180, 160)
		picture.show_symbols = progress.color_symbols
		var completed_picture: GameSnapshot = GameSnapshot.new()
		completed_picture.cells = current_level.cells.duplicate()
		column.add_child(picture)
		picture.display(current_level, completed_picture)
	if session.state == "PAUSED":
		column.add_child(_button("Продолжить", func() -> void: session.set_paused(false)))
		column.add_child(_button("Заново", session.restart))
	else:
		column.add_child(_button("Заново", session.restart))
		if title == "Уровень пройден" and current_index + 1 < repository.manifest.size():
			column.add_child(_button("Следующий", _next_level))
		if title == "Уровень пройден" and not save_warning.is_empty():
			column.add_child(_button("Повторить сохранение", _retry_save))
	column.add_child(_button("Меню", _request_menu))

func _retry_save() -> void:
	_save_progress()
	var message: String = "Теперь прогресс сохранён."
	if not save_warning.is_empty():
		message = "Прогресс пока не сохранён: " + save_warning
	_show_overlay("Уровень пройден", message, true)

func _toggle_pause() -> void:
	session.set_paused(session.state == "PLAYING")

func _tutorial_message() -> String:
	match current_index:
		0:
			return "Сначала красная коробка: два муравья освободят путь к синему цвету."
		1:
			return "Начните с нижнего ряда. Число на коробке — сколько блоков она доставит."
		2:
			return "Занятая коробка ждёт своей цели. Не заполняйте все пять слотов зря."
		_:
			return "Выберите доступную коробку. Цвет и число показывают её задачу."

func _show_tutorial() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Как играть"
	dialog.dialog_text = _tutorial_message() + "\n\nМуравьи забирают блоки своего цвета, если до них открыт путь снизу. Коробка освободит слот после доставки всех своих блоков. Таймера нет."
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _skip_tutorial() -> void:
	hint_label.visible = false

func _request_menu() -> void:
	if session.state != "PLAYING" and session.state != "PAUSED":
		_show_menu()
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Выйти из уровня?"
	dialog.dialog_text = "Текущая партия начнётся заново при следующем входе."
	dialog.ok_button_text = "Выйти"
	dialog.confirmed.connect(func() -> void:
		_show_menu()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _next_level() -> void:
	_start_level(current_index + 1)

func _show_error(message: String) -> void:
	_clear_overlay()
	session.stop()
	var layout: VBoxContainer = _new_layout()
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)
	var label: Label = _label(message, 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(label)
	if repository.manifest.is_empty():
		layout.add_child(_button("Повторить загрузку", _retry_manifest))
	else:
		layout.add_child(_button("К меню", _show_menu))
	layout.add_child(_button("Выход", func() -> void: get_tree().quit()))
	var bottom: Control = Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(bottom)

func _retry_manifest() -> void:
	if repository.load_manifest():
		_show_menu()
	else:
		push_error(repository.last_error)
		_show_error("Не удалось загрузить список уровней. Проверьте файлы игры.")

func _label(value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#edf2fa"))
	return label

func _button(value: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _button_style(Color("#394b68")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#4d6388")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#2f4059")))
	button.add_theme_stylebox_override("disabled", _panel_style())
	button.add_theme_color_override("font_disabled_color", Color("#a8b3c8"))
	button.pressed.connect(action)
	return button

func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _button_style(fill: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = _panel_style()
	style.bg_color = fill
	return style
