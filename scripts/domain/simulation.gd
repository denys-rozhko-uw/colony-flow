class_name Simulation
extends RefCounted

const SLOT_COUNT: int = 5
const MAX_JOBS_PER_BOX: int = 4
const MAX_JOBS: int = 20

var definition: LevelDefinition
var board: BoardState
var supply: SupplyState
var tick: int = 0
var status: String = "PLAYING"
var cells: Array[String] = []
var boxes: Dictionary = {}
var slots: Array[String] = []
var reserved: Dictionary = {}
var jobs: Array[JobState] = []
var commands: Array[Dictionary] = []
var next_command_id: int = 1
var next_job_id: int = 1
var next_event_id: int = 1

func _init(level: LevelDefinition) -> void:
	definition = level
	board = BoardState.new(level)
	supply = SupplyState.new(level)
	cells = board.cells
	reserved = board.reserved_job_by_cell
	for box: BoxDefinition in level.boxes:
		boxes[box.id] = BoxState.new(box)
	for index: int in SLOT_COUNT:
		slots.append("")

func enqueue_activate(box_id: String) -> int:
	var command_id: int = next_command_id
	next_command_id += 1
	commands.append({"id": command_id, "box_id": box_id})
	return command_id

func step() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if status != "PLAYING":
		return events
	tick += 1
	var job_index: int = 0
	while job_index < jobs.size():
		var job: JobState = jobs[job_index]
		job.phase_ticks_left -= 1
		if job.phase_ticks_left > 0:
			job_index += 1
			continue
		var box: BoxState = boxes[job.box_id]
		if job.phase == JobState.Phase.OUTBOUND:
			cells[job.cell_id] = ""
			reserved.erase(job.cell_id)
			job.phase = JobState.Phase.RETURNING
			job.phase_ticks_left = job.return_ticks
			_emit(events, "block_picked", {"job_id": job.id, "cell_id": job.cell_id})
			job_index += 1
		else:
			box.in_flight -= 1
			box.delivered += 1
			jobs.remove_at(job_index)
			_emit(events, "block_delivered", {"job_id": job.id, "box_id": job.box_id, "delivered": box.delivered, "remaining": box.remaining()})
	for index: int in SLOT_COUNT:
		if slots[index].is_empty():
			continue
		var box: BoxState = boxes[slots[index]]
		if box.remaining() == 0 and box.in_flight == 0:
			box.location = BoxState.Location.COMPLETED
			box.slot_index = -1
			var box_id: String = slots[index]
			slots[index] = ""
			_emit(events, "box_completed", {"box_id": box_id, "slot_index": index})
	for command: Dictionary in commands:
		var box_id: String = command.box_id
		var reason: String = _command_error(box_id)
		if not reason.is_empty():
			_emit(events, "command_rejected", {"command_id": command.id, "box_id": box_id, "reason": reason})
			continue
		var slot_index: int = slots.find("")
		var box: BoxState = boxes[box_id]
		box.location = BoxState.Location.ACTIVE
		box.slot_index = slot_index
		supply.activated_ids[box_id] = true
		slots[slot_index] = box_id
		_emit(events, "command_accepted", {"command_id": command.id, "box_id": box_id, "slot_index": slot_index})
		_emit(events, "box_activated", {"box_id": box_id, "slot_index": slot_index})
	commands.clear()
	var made_progress: bool = true
	while made_progress and jobs.size() < MAX_JOBS:
		made_progress = false
		for slot_index: int in SLOT_COUNT:
			if slots[slot_index].is_empty() or jobs.size() >= MAX_JOBS:
				continue
			var box: BoxState = boxes[slots[slot_index]]
			if box.in_flight >= MAX_JOBS_PER_BOX or box.in_flight >= box.remaining():
				continue
			var target: Dictionary = _first_target(box.definition.color_id)
			if target.is_empty():
				continue
			var duration: int = maxi(2, int(target.distance) + 1)
			var job: JobState = JobState.new(next_job_id, box.definition.id, target.cell_id, target.path, duration)
			next_job_id += 1
			box.in_flight += 1
			reserved[target.cell_id] = job.id
			jobs.append(job)
			_emit(events, "job_started", {"job_id": job.id, "box_id": job.box_id, "cell_id": job.cell_id, "path": job.path.duplicate(), "outbound_ticks": duration, "return_ticks": duration})
			made_progress = true
	if _all_cells_empty() and jobs.is_empty() and _all_boxes_completed():
		status = "WON"
		_emit(events, "level_won", {"reason": "all_delivered"})
	elif jobs.is_empty() and not _can_assign() and not _has_legal_command():
		status = "LOST"
		_emit(events, "level_lost", {"reason": "no_available_move"})
	return events

func is_quiescent() -> bool:
	return commands.is_empty() and jobs.is_empty() and not _can_assign()

func available_box_ids() -> Array[String]:
	var result: Array[String] = []
	for definition_box: BoxDefinition in definition.boxes:
		var box: BoxState = boxes[definition_box.id]
		if box.location != BoxState.Location.SUPPLY:
			continue
		if supply.is_unlocked(definition_box.id):
			result.append(definition_box.id)
	return result

func get_snapshot() -> GameSnapshot:
	var snapshot: GameSnapshot = GameSnapshot.new()
	snapshot.tick = tick
	snapshot.status = status
	snapshot.cells = cells.duplicate()
	snapshot.slots = slots.duplicate()
	snapshot.available_box_ids = available_box_ids()
	for box_id: String in boxes.keys():
		var box: BoxState = boxes[box_id]
		snapshot.boxes[box_id] = {"color_id": box.definition.color_id, "quota": box.definition.quota, "delivered": box.delivered, "in_flight": box.in_flight, "location": box.location, "slot_index": box.slot_index}
	for job: JobState in jobs:
		snapshot.jobs.append({"id": job.id, "box_id": job.box_id, "cell_id": job.cell_id, "path": job.path.duplicate(), "phase": job.phase, "phase_ticks_left": job.phase_ticks_left, "outbound_ticks": job.outbound_ticks, "return_ticks": job.return_ticks})
	return snapshot

func validate_invariants() -> Array[String]:
	var errors: Array[String] = []
	var color_totals: Dictionary = {}
	var delivered: Dictionary = {}
	var carrying: Dictionary = {}
	var pending: Dictionary = {}
	var undelivered_quotas: Dictionary = {}
	for color_id: String in definition.cells:
		if not color_id.is_empty():
			color_totals[color_id] = int(color_totals.get(color_id, 0)) + 1
	for color_id: String in cells:
		if not color_id.is_empty():
			pending[color_id] = int(pending.get(color_id, 0)) + 1
	if slots.size() != SLOT_COUNT:
		errors.append("slot count")
	var seen_slots: Dictionary = {}
	for slot_id: String in slots:
		if slot_id.is_empty():
			continue
		if seen_slots.has(slot_id):
			errors.append("duplicate slot box")
		seen_slots[slot_id] = true
		if not boxes.has(slot_id) or boxes[slot_id].location != BoxState.Location.ACTIVE:
			errors.append("invalid active box")
	var job_counts: Dictionary = {}
	var outbound_count: int = 0
	for job: JobState in jobs:
		if not boxes.has(job.box_id) or boxes[job.box_id].location != BoxState.Location.ACTIVE:
			errors.append("orphan job")
			continue
		job_counts[job.box_id] = int(job_counts.get(job.box_id, 0)) + 1
		var color_id: String = boxes[job.box_id].definition.color_id
		if job.phase == JobState.Phase.OUTBOUND:
			outbound_count += 1
			if not reserved.has(job.cell_id) or reserved[job.cell_id] != job.id or cells[job.cell_id] != color_id:
				errors.append("bad reservation")
		else:
			carrying[color_id] = int(carrying.get(color_id, 0)) + 1
	if reserved.size() != outbound_count:
		errors.append("orphan reservation")
	for box_id: String in boxes.keys():
		var box: BoxState = boxes[box_id]
		if box.delivered < 0 or box.delivered > box.definition.quota or box.in_flight < 0 or box.in_flight > box.remaining() or box.in_flight != int(job_counts.get(box_id, 0)):
			errors.append("quota or in-flight: " + box_id)
		var color_id: String = box.definition.color_id
		delivered[color_id] = int(delivered.get(color_id, 0)) + box.delivered
		undelivered_quotas[color_id] = int(undelivered_quotas.get(color_id, 0)) + box.remaining()
		if box.location == BoxState.Location.ACTIVE and not seen_slots.has(box_id):
			errors.append("active box outside slots: " + box_id)
	for color_id: String in color_totals.keys():
		if int(pending.get(color_id, 0)) + int(carrying.get(color_id, 0)) + int(delivered.get(color_id, 0)) != int(color_totals[color_id]):
			errors.append("color conservation: " + color_id)
		if int(undelivered_quotas.get(color_id, 0)) != int(pending.get(color_id, 0)) + int(carrying.get(color_id, 0)):
			errors.append("quota conservation: " + color_id)
	return errors

func _first_target(color_id: String) -> Dictionary:
	for target: Dictionary in ReachabilityPolicy.find_targets(cells, definition.width, definition.height, reserved):
		if target.color_id == color_id:
			return target
	return {}

func _command_error(box_id: String) -> String:
	if not boxes.has(box_id):
		return "UNKNOWN_BOX"
	if boxes[box_id].location != BoxState.Location.SUPPLY:
		return "ALREADY_ACTIVATED"
	if not available_box_ids().has(box_id):
		return "BLOCKED"
	if slots.find("") < 0:
		return "NO_FREE_SLOT"
	return ""

func _can_assign() -> bool:
	for box_id: String in slots:
		if box_id.is_empty():
			continue
		var box: BoxState = boxes[box_id]
		if box.in_flight < box.remaining() and not _first_target(box.definition.color_id).is_empty():
			return true
	return false

func _has_legal_command() -> bool:
	return slots.has("") and not available_box_ids().is_empty()

func _all_cells_empty() -> bool:
	for cell: String in cells:
		if not cell.is_empty():
			return false
	return true

func _all_boxes_completed() -> bool:
	for box: BoxState in boxes.values():
		if box.location != BoxState.Location.COMPLETED:
			return false
	return true

func _emit(events: Array[Dictionary], kind: String, fields: Dictionary) -> void:
	var event: Dictionary = {"event_id": next_event_id, "tick": tick, "kind": kind}
	next_event_id += 1
	for key: Variant in fields.keys():
		event[key] = fields[key]
	events.append(event)
