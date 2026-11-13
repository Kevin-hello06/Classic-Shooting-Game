extends Node
## Tiny retro sound effects, synthesised in code when the game starts, so the
## project carries no audio files. Use Sfx.play("shot") from anywhere.
##
## To use real sounds later, put .ogg files in res://sounds/ and load them
## into _streams in _ready() under the same names.

const RATE := 22050
const SOUNDS := {
	"shot": 0.18, "click": 0.05, "fireball": 0.3, "hurt": 0.22, "die": 0.7,
	"enemy_hurt": 0.15, "enemy_die": 0.45, "pickup": 0.14, "exit": 0.6,
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	for id in SOUNDS:
		_streams[id] = _synth(id, SOUNDS[id])


func play(id: String) -> void:
	if not _streams.has(id):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.play()


func _synth(id: String, dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var s := 0.0
		match id:
			"shot":
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.5
				s = lp * exp(-t * 22.0) + sin(TAU * 70.0 * t) * exp(-t * 18.0) * 0.6
			"click":
				s = (1.0 if fmod(t * 900.0, 1.0) < 0.5 else -1.0) * (1.0 - k) * 0.25
			"fireball":
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
				s = lp * 2.5 * sin(PI * k)
			"hurt":
				phase += TAU * (180.0 - 90.0 * k) / RATE
				s = (1.0 if sin(phase) > 0.0 else -1.0) * 0.3 * (1.0 - k)
			"die":
				phase += TAU * (160.0 * (1.0 - 0.75 * k)) / RATE
				s = (fmod(phase / TAU, 1.0) * 2.0 - 1.0) * 0.35 * (1.0 - k)
			"enemy_hurt":
				phase += TAU * (320.0 - 160.0 * k) / RATE
				s = sin(phase) * 0.45 * (1.0 - k)
			"enemy_die":
				phase += TAU * (240.0 * (1.0 - 0.7 * k)) / RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.2
				s = ((fmod(phase / TAU, 1.0) * 2.0 - 1.0) * 0.3 + lp * 0.4) * (1.0 - k)
			"pickup":
				phase += TAU * (520.0 + 900.0 * k) / RATE
				s = (1.0 if sin(phase) > 0.0 else -1.0) * 0.16
			"exit":
				phase += TAU * (300.0 + 700.0 * k) / RATE
				s = sin(phase) * 0.4 * (1.0 - k) + sin(phase * 1.5) * 0.15 * (1.0 - k)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
