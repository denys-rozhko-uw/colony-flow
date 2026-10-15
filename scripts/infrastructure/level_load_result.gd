class_name LevelLoadResult
extends RefCounted

var level: LevelDefinition = null
var errors: Array[String] = []

func is_ok() -> bool:
	return level != null and errors.is_empty()
