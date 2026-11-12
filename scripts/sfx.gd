class_name Sfx
extends Node
## Polyphonic combat cues and one low-volume environmental bed.

const VOICES := 6
const STREAMS := {
	"swing_light": preload("res://assets/audio/swing_light.wav"),
	"swing_heavy": preload("res://assets/audio/swing_heavy.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"),
	"dodge": preload("res://assets/audio/dodge.wav"),
	"enemy_strike": preload("res://assets/audio/enemy_strike.wav"),
	"block": preload("res://assets/audio/block.wav"),
	"parry": preload("res://assets/audio/parry.wav"),
	"guard_break": preload("res://assets/audio/guard_break.wav"),
	"captain": preload("res://assets/audio/captain.wav"),
	"win": preload("res://assets/audio/win.wav"),
	"lose": preload("res://assets/audio/lose.wav"),
}
const BEDS := {
	"title": preload("res://assets/audio/title.ogg"),
	"outer_walls": preload("res://assets/audio/outer_walls.ogg"),
	"forge": preload("res://assets/audio/forge.ogg"),
	"crown_pit": preload("res://assets/audio/crown_pit.ogg"),
}
const BED_VOLUME := -14.0

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bed: AudioStreamPlayer
var _bed_fade: Tween
var _requested_bed := ""


func _ready() -> void:
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -5.0
		add_child(voice)
		_players.append(voice)
	_bed = AudioStreamPlayer.new()
	add_child(_bed)


func play(sound: String) -> void:
	if DisplayServer.get_name() == "headless" or not STREAMS.has(sound) or _players.is_empty():
		return
	var voice := _players[_next]
	_next = (_next + 1) % _players.size()
	voice.stream = STREAMS[sound]
	voice.play()


func set_bed(name: String) -> void:
	var stream: AudioStreamOggVorbis = BEDS.get(name)
	if DisplayServer.get_name() == "headless" or _requested_bed == name:
		return
	_requested_bed = name
	if _bed_fade != null and _bed_fade.is_valid():
		_bed_fade.kill()
	_bed_fade = create_tween()
	if _bed.playing:
		_bed_fade.tween_property(_bed, "volume_db", -48.0, 0.22)
	_bed_fade.tween_callback(_start_bed.bind(stream))
	if stream != null:
		_bed_fade.tween_property(_bed, "volume_db", BED_VOLUME, 0.55)


func _start_bed(stream: AudioStreamOggVorbis) -> void:
	_bed.stop()
	_bed.stream = stream
	if stream != null:
		stream.loop = true
		_bed.volume_db = -48.0
		_bed.play()



func _exit_tree() -> void:
	if _bed_fade != null and _bed_fade.is_valid():
		_bed_fade.kill()
	for voice in _players:
		voice.stop()
		voice.stream = null
	_bed.stop()
	_bed.stream = null
