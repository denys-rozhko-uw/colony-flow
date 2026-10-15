class_name ReachabilityPolicy
extends RefCounted

const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]

static func find_targets(cells: Array[String], width: int, height: int, reserved: Dictionary) -> Array[Dictionary]:
	var count: int = width * height
	var distance: Array[int] = []
	var previous: Array[int] = []
	for index: int in count:
		distance.append(-1)
		previous.append(-1)
	var queue: Array[int] = []
	for x: int in width:
		var index: int = (height - 1) * width + x
		if cells[index].is_empty():
			distance[index] = 1
			queue.append(index)
	var cursor: int = 0
	while cursor < queue.size():
		var current: int = queue[cursor]
		cursor += 1
		var position: Vector2i = Vector2i(current % width, current / width)
		for direction: Vector2i in DIRS:
			var next: Vector2i = position + direction
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			var next_id: int = next.y * width + next.x
			if cells[next_id].is_empty() and distance[next_id] < 0:
				distance[next_id] = distance[current] + 1
				previous[next_id] = current
				queue.append(next_id)
	var targets: Array[Dictionary] = []
	for cell_id: int in count:
		if cells[cell_id].is_empty() or reserved.has(cell_id):
			continue
		var x: int = cell_id % width
		var y: int = cell_id / width
		var best_neighbor: int = -1
		var best_distance: int = 2147483647
		if y == height - 1:
			best_distance = 0
		for direction: Vector2i in DIRS:
			var neighbor: Vector2i = Vector2i(x, y) + direction
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= width or neighbor.y >= height:
				continue
			var neighbor_id: int = neighbor.y * width + neighbor.x
			if distance[neighbor_id] >= 0 and (distance[neighbor_id] < best_distance or (distance[neighbor_id] == best_distance and neighbor_id < best_neighbor)):
				best_neighbor = neighbor_id
				best_distance = distance[neighbor_id]
		if best_distance == 2147483647:
			continue
		var path: Array[int] = []
		var step_id: int = best_neighbor
		while step_id >= 0:
			path.push_front(step_id)
			step_id = previous[step_id]
		targets.append({"cell_id": cell_id, "color_id": cells[cell_id], "path": path, "distance": best_distance})
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.distance != b.distance:
			return a.distance < b.distance
		return a.cell_id < b.cell_id
	)
	return targets
