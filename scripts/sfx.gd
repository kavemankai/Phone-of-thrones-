class_name Sfx
extends Node
## Placeholder sounds synthesised at startup. No audio files are shipped.

const RATE := 22050
const VOICES := 6

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_streams = {
		"swing_light": _synth(900.0, 300.0, 0.12, 0.8, 0.35),
		"swing_heavy": _synth(600.0, 140.0, 0.22, 0.7, 0.5),
		"hit": _synth(240.0, 70.0, 0.14, 0.45, 0.8),
		"hurt": _synth(190.0, 55.0, 0.28, 0.3, 0.9),
		"dodge": _synth(1000.0, 2200.0, 0.14, 0.9, 0.25),
		"enemy_strike": _synth(420.0, 110.0, 0.12, 0.6, 0.45),
		"captain": _synth(150.0, 105.0, 0.6, 0.12, 0.7),
		"win": _synth(440.0, 880.0, 0.4, 0.0, 0.5),
		"lose": _synth(320.0, 70.0, 0.55, 0.1, 0.6),
	}
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String) -> void:
	if not _streams.has(sound) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.play()


static func _synth(f0: float, f1: float, dur: float, noise: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(f0, f1, t) / RATE
		var env := pow(1.0 - t, 2.0) * minf(1.0, float(i) / 60.0)
		var s := sin(phase) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
