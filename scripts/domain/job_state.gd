class_name JobState
extends RefCounted

enum Phase { OUTBOUND, RETURNING }

var id: int = 0
var box_id: String = ""
var cell_id: int = -1
var path: Array[int] = []
var phase: Phase = Phase.OUTBOUND
var phase_ticks_left: int = 0
var outbound_ticks: int = 0
var return_ticks: int = 0

func _init(job_id: int, source_box_id: String, target_cell_id: int, source_path: Array[int], duration: int) -> void:
	id = job_id
	box_id = source_box_id
	cell_id = target_cell_id
	path = source_path.duplicate()
	outbound_ticks = duration
	return_ticks = duration
	phase_ticks_left = duration
