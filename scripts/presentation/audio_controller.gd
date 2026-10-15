class_name AudioController
extends Node

const SFX_PATHS: Dictionary = {
	"command_accepted": "res://assets/audio/select.wav",
	"command_rejected": "res://assets/audio/reject.wav",
	"block_picked": "res://assets/audio/pickup.wav",
	"block_delivered": "res://assets/audio/deliver.wav",
	"level_won": "res://assets/audio/win.wav",
	"level_lost": "res://assets/audio/lose.wav"
}

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	if DisplayServer.get_name() == "headless":
		return
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.stream = load("res://assets/audio/music.wav")
	music_player.finished.connect(_restart_music)
	add_child(music_player)
	for index: int in 4:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	for kind: String in SFX_PATHS.keys():
		sfx_streams[kind] = load(SFX_PATHS[kind])
	music_player.play()

func _exit_tree() -> void:
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	for player: AudioStreamPlayer in sfx_players:
		player.stop()
		player.stream = null
	sfx_streams.clear()

func apply_settings(data: ProgressData) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(data.master_volume, 0.001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(data.music_volume, 0.001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(data.sfx_volume, 0.001)))
	AudioServer.set_bus_mute(0, data.master_volume == 0.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), data.music_volume == 0.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), data.sfx_volume == 0.0)

func play_events(events: Array[Dictionary]) -> void:
	var selected: String = ""
	for event: Dictionary in events:
		if event.kind == "level_won" or event.kind == "level_lost":
			selected = event.kind
			break
		if event.kind == "command_rejected":
			selected = event.kind
		elif event.kind == "command_accepted" and selected.is_empty():
			selected = event.kind
		elif event.kind == "block_delivered" and selected.is_empty():
			selected = event.kind
		elif event.kind == "block_picked" and selected.is_empty():
			selected = event.kind
	if selected.is_empty():
		return
	for player: AudioStreamPlayer in sfx_players:
		if not player.playing:
			player.stream = sfx_streams[selected]
			player.play()
			return

func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, name)
	AudioServer.set_bus_send(index, "Master")

func _restart_music() -> void:
	if is_inside_tree():
		music_player.play()
