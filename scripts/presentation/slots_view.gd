class_name SlotsView
extends HBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 5)
	for index: int in Simulation.SLOT_COUNT:
		var label: Label = Label.new()
		label.text = "—"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(48, 48)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#edf2fa"))
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("#283349")
		style.set_corner_radius_all(8)
		label.add_theme_stylebox_override("normal", style)
		add_child(label)

func display(snapshot: GameSnapshot, level: LevelDefinition, show_symbols: bool) -> void:
	for index: int in Simulation.SLOT_COUNT:
		var label: Label = get_child(index)
		var box_id: String = snapshot.slots[index]
		if box_id.is_empty():
			label.text = "—"
			label.add_theme_color_override("font_color", Color("#edf2fa"))
			continue
		var box: Dictionary = snapshot.boxes[box_id]
		var prefix: String = str(level.palette[box.color_id].symbol) + " " if show_symbols else ""
		label.text = prefix + str(int(box.quota) - int(box.delivered))
		label.add_theme_color_override("font_color", Color.html(level.palette[box.color_id].hex))
