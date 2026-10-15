class_name ProgressData
extends RefCounted

var completed_level_ids: Array[String] = []
var last_selected_level_id: String = ""
var master_volume: float = 0.8
var music_volume: float = 0.5
var sfx_volume: float = 0.8
var reduced_motion: bool = false
var color_symbols: bool = true

func to_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"completed_level_ids": completed_level_ids.duplicate(),
		"last_selected_level_id": last_selected_level_id,
		"settings": {
			"master_volume": master_volume,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
			"reduced_motion": reduced_motion,
			"color_symbols": color_symbols
		}
	}

static func parse(value: Variant) -> ProgressData:
	if not value is Dictionary or value.get("schema_version") != 1:
		return null
	if not value.get("completed_level_ids") is Array or not value.get("last_selected_level_id") is String or not value.get("settings") is Dictionary:
		return null
	var settings: Dictionary = value.settings
	var data: ProgressData = ProgressData.new()
	for item: Variant in value.completed_level_ids:
		if not item is String or item.is_empty():
			return null
		if not data.completed_level_ids.has(item):
			data.completed_level_ids.append(item)
	data.last_selected_level_id = value.last_selected_level_id
	for key: String in ["master_volume", "music_volume", "sfx_volume"]:
		var amount: Variant = settings.get(key)
		if not amount is float and not amount is int:
			return null
		if amount < 0.0 or amount > 1.0:
			return null
	if not settings.get("reduced_motion") is bool or not settings.get("color_symbols") is bool:
		return null
	data.master_volume = float(settings.master_volume)
	data.music_volume = float(settings.music_volume)
	data.sfx_volume = float(settings.sfx_volume)
	data.reduced_motion = settings.reduced_motion
	data.color_symbols = settings.color_symbols
	return data
