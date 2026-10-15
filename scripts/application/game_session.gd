class_name GameSession
extends Node

signal events_ready(events: Array[Dictionary], session_id: int)
signal snapshot_changed(snapshot: GameSnapshot, session_id: int)
signal session_state_changed(state: String)

const TICK_SECONDS: float = 0.1
const MAX_TICKS_PER_FRAME: int = 10

var level: LevelDefinition
var simulation: Simulation
var session_id: int = 0
var state: String = "LOADING"
var accumulator: float = 0.0

func _process(delta: float) -> void:
	if state != "PLAYING" or simulation == null:
		return
	accumulator += delta
	var steps: int = 0
	while accumulator + 0.000001 >= TICK_SECONDS and steps < MAX_TICKS_PER_FRAME and state == "PLAYING":
		accumulator -= TICK_SECONDS
		steps += 1
		var events: Array[Dictionary] = simulation.step()
		events_ready.emit(events, session_id)
		snapshot_changed.emit(simulation.get_snapshot(), session_id)
		if simulation.status != "PLAYING":
			state = simulation.status
			session_state_changed.emit(state)
	if accumulator < 0.0:
		accumulator = 0.0

func start_level(new_level: LevelDefinition) -> void:
	level = new_level
	restart()

func activate_box(box_id: String) -> void:
	if state == "PLAYING":
		for command: Dictionary in simulation.commands:
			if command.box_id == box_id:
				return
		simulation.enqueue_activate(box_id)

func set_paused(value: bool) -> void:
	if value and state == "PLAYING":
		state = "PAUSED"
		accumulator = 0.0
		session_state_changed.emit(state)
	elif not value and state == "PAUSED":
		state = "PLAYING"
		session_state_changed.emit(state)

func restart() -> void:
	if level == null:
		return
	session_id += 1
	accumulator = 0.0
	simulation = Simulation.new(level)
	state = "PLAYING"
	session_state_changed.emit(state)
	snapshot_changed.emit(simulation.get_snapshot(), session_id)

func stop() -> void:
	session_id += 1
	accumulator = 0.0
	simulation = null
	state = "LOADING"
	session_state_changed.emit(state)
