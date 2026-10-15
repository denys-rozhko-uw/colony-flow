class_name SupplyView
extends ScrollContainer

signal box_selected(box_id: String)

var row: HFlowContainer
var buttons: Dictionary = {}

func _ready() -> void:
	custom_minimum_size.y = 110
	size_flags_vertical = Control.SIZE_SHRINK_END
	row = HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	add_child(row)

func display(snapshot: GameSnapshot, level: LevelDefinition, show_symbols: bool, can_input: bool) -> void:
	var visible_ids: Array[String] = []
	var occupied: int = 0
	for box_id: String in snapshot.slots:
		if not box_id.is_empty():
			occupied += 1
	for definition: BoxDefinition in level.boxes:
		if int(snapshot.boxes[definition.id].location) != BoxState.Location.SUPPLY:
			continue
		visible_ids.append(definition.id)
		if not buttons.has(definition.id):
			var button: BoxView = BoxView.new()
			button.configure(definition, level.palette, show_symbols)
			button.pressed.connect(func() -> void: box_selected.emit(button.box_id))
			buttons[definition.id] = button
			row.add_child(button)
		var existing: BoxView = buttons[definition.id]
		existing.disabled = not can_input or occupied >= Simulation.SLOT_COUNT or not snapshot.available_box_ids.has(definition.id)
	for box_id: String in buttons.keys():
		if not visible_ids.has(box_id):
			var removed: BoxView = buttons[box_id]
			row.remove_child(removed)
			removed.queue_free()
			buttons.erase(box_id)
