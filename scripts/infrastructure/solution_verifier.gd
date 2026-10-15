class_name SolutionVerifier
extends RefCounted

const MAX_TICKS: int = 100000

static func verify(level: LevelDefinition) -> Dictionary:
	var simulation: Simulation = Simulation.new(level)
	var spent: int = 0
	for box_id: String in level.solution_order:
		if simulation.status != "PLAYING":
			break
		var command_id: int = simulation.enqueue_activate(box_id)
		var events: Array[Dictionary] = simulation.step()
		spent += 1
		var accepted: bool = false
		for event: Dictionary in events:
			if event.kind == "command_accepted" and event.command_id == command_id:
				accepted = true
		if not accepted:
			return {"ok": false, "tick": simulation.tick, "reason": "команда отклонена: " + box_id}
		while simulation.status == "PLAYING" and not simulation.is_quiescent() and spent < MAX_TICKS:
			simulation.step()
			spent += 1
			var errors: Array[String] = simulation.validate_invariants()
			if not errors.is_empty():
				return {"ok": false, "tick": simulation.tick, "reason": ", ".join(errors)}
		if spent >= MAX_TICKS:
			return {"ok": false, "tick": simulation.tick, "reason": "превышен лимит тиков"}
	if simulation.status != "WON":
		return {"ok": false, "tick": simulation.tick, "reason": "конечное состояние " + simulation.status}
	return {"ok": true, "tick": simulation.tick, "reason": ""}
