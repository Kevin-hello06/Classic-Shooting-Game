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
	"alert": 0.45, "unlock": 0.5,
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for id in SOUNDS:
		_streams[id] = _synth(id, SOUNDS[id])


func play(id: String, volume_db := -6.0) -> void:
	if not _streams.has(id):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.volume_db = volume_db
	p.play()


## For sounds made by enemies: quieter the further away they are.
func play_from(id: String, distance: float) -> void:
	var db := -6.0 - 20.0 * log(maxf(distance / 4.0, 1.0)) / log(10.0)
	if db > -40.0:
		play(id, db)


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
			"alert":
				phase += TAU * (95.0 - 40.0 * k + 12.0 * sin(TAU * 9.0 * t)) / RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3
				s = ((fmod(phase / TAU, 1.0) * 2.0 - 1.0) * 0.45 + lp * 0.35) * sin(PI * k)
			"unlock":
				var note := 0 if k < 0.33 else (1 if k < 0.66 else 2)
				phase += TAU * [440.0, 554.4, 659.3][note] / RATE
				s = (1.0 if sin(phase) > 0.0 else -1.0) * 0.18 * (1.0 - fmod(k * 3.0, 1.0) * 0.6)
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
