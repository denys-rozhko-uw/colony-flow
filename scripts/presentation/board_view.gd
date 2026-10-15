class_name BoardView
extends Control

var level: LevelDefinition
var snapshot: GameSnapshot
var show_symbols: bool = true
var reduced_motion: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(180, 170)

func display(new_level: LevelDefinition, new_snapshot: GameSnapshot) -> void:
	level = new_level
	snapshot = new_snapshot
	queue_redraw()

func _draw() -> void:
	if level == null or snapshot == null:
		return
	var cell_size: float = minf((size.x - 20.0) / float(level.width), (size.y - 24.0) / float(level.height))
	cell_size = maxf(8.0, cell_size)
	var board_size: Vector2 = Vector2(level.width, level.height) * cell_size
	var origin: Vector2 = Vector2((size.x - board_size.x) * 0.5, (size.y - board_size.y) * 0.5 - 4.0)
	draw_rect(Rect2(origin - Vector2(8, 8), board_size + Vector2(16, 16)), Color("#242d42"), true)
	for cell_id: int in snapshot.cells.size():
		var color_id: String = snapshot.cells[cell_id]
		var x: int = cell_id % level.width
		var y: int = cell_id / level.width
		var rect: Rect2 = Rect2(origin + Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
		if color_id.is_empty():
			draw_rect(rect.grow(-1.0), Color("#202839"), true)
		else:
			var color: Color = Color.html(level.palette[color_id].hex)
			draw_rect(rect.grow(-2.0), color.darkened(0.38), true)
			draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 8)), color, true)
			if show_symbols and cell_size >= 22.0:
				var font: Font = get_theme_default_font()
				if font != null:
					var symbol: String = str(level.palette[color_id].symbol)
					draw_string(font, rect.position + Vector2(0, cell_size * 0.65), symbol, HORIZONTAL_ALIGNMENT_CENTER, cell_size, mini(24, int(cell_size * 0.48)), Color(1, 1, 1, 0.75))
	for job: Dictionary in snapshot.jobs:
		var box_color_id: String = snapshot.boxes[job.box_id].color_id
		var ant_color: Color = Color.html(level.palette[box_color_id].hex)
		var path: Array = job.path
		var points: Array[Vector2] = []
		if path.is_empty():
			var target_x: int = int(job.cell_id) % level.width
			points.append(origin + Vector2(float(target_x) + 0.5, float(level.height) + 0.5) * cell_size)
		else:
			var first_x: int = int(path[0]) % level.width
			points.append(origin + Vector2(float(first_x) + 0.5, float(level.height) + 0.5) * cell_size)
			for path_id: Variant in path:
				points.append(_cell_center(int(path_id), origin, cell_size))
		points.append(_cell_center(int(job.cell_id), origin, cell_size))
		var fraction: float
		if int(job.phase) == JobState.Phase.OUTBOUND:
			fraction = 1.0 - float(job.phase_ticks_left) / float(job.outbound_ticks)
		else:
			fraction = float(job.phase_ticks_left) / float(job.return_ticks)
		var progress: float = clampf(fraction, 0.0, 1.0) * float(points.size() - 1)
		var segment: int = mini(int(floor(progress)), points.size() - 2)
		var ant_position: Vector2 = points[segment].lerp(points[segment + 1], progress - float(segment))
		if reduced_motion:
			ant_position = points[points.size() - 1] if int(job.phase) == JobState.Phase.OUTBOUND else points[0]
		draw_circle(ant_position, maxf(3.0, cell_size * 0.11), Color("#172033"))
		draw_circle(ant_position + Vector2(0, -2), maxf(2.0, cell_size * 0.07), ant_color)
		if int(job.phase) == JobState.Phase.RETURNING:
			draw_rect(Rect2(ant_position + Vector2(3, -8), Vector2(6, 6)), ant_color, true)

func _cell_center(cell_id: int, origin: Vector2, cell_size: float) -> Vector2:
	return origin + Vector2(float(cell_id % level.width) + 0.5, float(cell_id / level.width) + 0.5) * cell_size
