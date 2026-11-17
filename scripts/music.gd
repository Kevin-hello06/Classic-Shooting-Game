extends Node
## Background music, composed as text below and synthesised in code: square-
## wave bass riffs, a pulse-wave lead with echo, and synth drums. Each song is
## an 8-bar loop. Level 1 plays song 0, level 2 song 1, and so on.
##
## The first launch renders the songs on a background thread (the game starts
## straight away and the music fades in when ready). They're then cached in
## user:// so later launches start instantly. Bump CACHE_VERSION after editing
## a song so the cache is rebuilt.
##
## Writing music: each bar is 16 steps (16th notes).
##   bass / lead:  a note like E2 or A#4 starts a note, "-" holds it, "." is a rest
##   drums:        k kick, s snare, h hi-hat, K kick+hat, S snare+hat,
##                 x kick+snare, . nothing

const RATE := 22050
const CACHE_VERSION := 1
const FADE_IN := 1.5

const SONGS := [
	{
		"name": "Brick Halls",
		"bpm": 132,
		"bass": [
			"E2 E2 . E2 E2 . G2 . E2 E2 . E2 A#2 - A2 -",
			"E2 E2 . E2 E2 . G2 . E2 E2 . E2 D3 - B2 -",
			"E2 E2 . E2 E2 . G2 . E2 E2 . E2 A#2 - A2 -",
			"E2 E2 . E2 E2 . G2 . A2 - G2 - F#2 - D2 -",
			"C3 C3 . C3 C3 . C3 . D3 D3 . D3 D3 . D3 .",
			"E2 E2 . E2 E2 . E2 . E2 E2 . E2 B2 - G2 -",
			"C3 C3 . C3 C3 . C3 . D3 D3 . D3 D3 . D3 .",
			"E2 E2 . E2 F#2 . F#2 . G2 . G2 . A#2 - B2 -",
		],
		"lead": [
			". . . . . . . . . . . . . . . .",
			". . . . . . . . . . . . . . . .",
			". . . . . . . . . . . . . . . .",
			". . . . . . . . E5 - D5 - B4 - - -",
			"E4 - - - G4 - - - A4 - B4 - - - A4 -",
			"G4 - E4 - - - - - D4 - E4 - - - - -",
			"E4 - - - G4 - - - A4 - B4 - D5 - B4 -",
			"A4 - - - G4 - A4 - B4 - - - - - - -",
		],
		"drums": [
			"K.h.S.hkK.hkS.h.",
			"K.h.S.hkK.hkS.h.",
			"K.h.S.hkK.hkS.h.",
			"K.h.S.hkK.s.ssss",
			"KhkhShkhKhkhShkh",
			"KhkhShkhKhkhShkh",
			"KhkhShkhKhkhShkh",
			"K.h.S.hkx.s.ssxs",
		],
	},
	{
		"name": "Steel Depths",
		"bpm": 144,
		"bass": [
			"D2 D2 . D2 D2 . D#2 . D2 D2 . D2 F2 - D#2 -",
			"D2 D2 . D2 D2 . D#2 . D2 D2 . D2 A2 - G#2 -",
			"D2 D2 . D2 D2 . D#2 . D2 D2 . D2 F2 - D#2 -",
			"D2 D2 . D2 D2 . F2 . G2 - F2 - D#2 - C2 -",
			"A#2 A#2 . A#2 A#2 . A#2 . C3 C3 . C3 C3 . C3 .",
			"D2 D2 . D2 D2 . D2 . D2 D2 . D2 D#2 - F2 -",
			"A#2 A#2 . A#2 A#2 . A#2 . C3 C3 . C3 C3 . C3 .",
			"D2 . D2 . D#2 . D#2 . F2 . F2 . G2 - A2 -",
		],
		"lead": [
			". . . . . . . . . . . . . . . .",
			". . . . . . . . A4 - - - G#4 - - -",
			". . . . . . . . . . . . . . . .",
			". . . . . . . . D5 - C5 - A#4 - A4 -",
			"D5 - - - D#5 - - - F5 - - - D#5 - D5 -",
			"C5 - A#4 - - - - - A4 - - - - - - -",
			"D5 - - - D#5 - - - F5 - G5 - A5 - G5 -",
			"F5 - D#5 - D5 - - - - - - - . . . .",
		],
		"drums": [
			"K.hkS.hkK.hkS.hk",
			"K.hkS.hkK.hkS.hk",
			"K.hkS.hkK.hkS.hk",
			"K.hkS.hkx.s.ssxs",
			"KkhkSkhkKkhkSkhk",
			"KkhkSkhkKkhkSkhk",
			"KkhkSkhkKkhkSkhk",
			"KkhkSkhkx.s.sxss",
		],
	},
]

const NOTE_INDEX := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

var _player: AudioStreamPlayer
var _tracks: Array = []
var _thread: Thread
var _wanted := -1
var _current := -1


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)
	_thread = Thread.new()
	_thread.start(_load_or_render_all)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func is_ready() -> bool:
	return not _tracks.is_empty()


func track(i: int) -> AudioStreamWAV:
	return _tracks[i] if i < _tracks.size() else null


func current_track() -> int:
	return _current


## Play the song for a level. Safe to call before the songs are ready.
func play_for_level(level_index: int) -> void:
	_wanted = level_index % SONGS.size()
	if is_ready() and _wanted != _current:
		_start(_wanted)


func stop() -> void:
	_player.stop()
	_current = -1


func _start(i: int) -> void:
	_current = i
	_player.stream = _tracks[i]
	_player.volume_db = -40.0
	_player.play()
	var t := create_tween()
	t.tween_property(_player, "volume_db", 0.0, FADE_IN)


# --- background rendering ------------------------------------------------

func _load_or_render_all() -> void:
	var out: Array = []
	for i in SONGS.size():
		var path := "user://music_v%d_%d.res" % [CACHE_VERSION, i]
		var wav: AudioStreamWAV = null
		if ResourceLoader.exists(path):
			wav = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
		if wav == null:
			wav = render_song(SONGS[i])
			ResourceSaver.save(wav, path)
		out.append(wav)
	_on_rendered.call_deferred(out)


func _on_rendered(out: Array) -> void:
	_thread.wait_to_finish()
	_tracks = out
	if _wanted >= 0:
		_start(_wanted)


# --- synthesiser ----------------------------------------------------------

static func render_song(song: Dictionary) -> AudioStreamWAV:
	var step: float = 60.0 / float(song["bpm"]) / 4.0
	var steps: int = (song["bass"] as Array).size() * 16
	var n := int(round(steps * step * RATE))
	var mix := PackedFloat32Array()
	mix.resize(n)

	_render_part(mix, song["bass"], step, "bass")

	var lead := PackedFloat32Array()
	lead.resize(n)
	_render_part(lead, song["lead"], step, "lead")
	var d := int(step * 3.0 * RATE)    # dotted-eighth echo
	for i in n:
		mix[i] += lead[i] + lead[(i - d + n) % n] * 0.35 + lead[(i - 2 * d + 2 * n) % n] * 0.12

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bars: Array = song["drums"]
	for b in bars.size():
		var pattern: String = bars[b]
		for s in 16:
			var start := int((b * 16 + s) * step * RATE)
			match pattern[s]:
				"k":
					_kick(mix, start)
				"s":
					_snare(mix, start, rng)
				"h":
					_hat(mix, start, rng)
				"K":
					_kick(mix, start)
					_hat(mix, start, rng)
				"S":
					_snare(mix, start, rng)
					_hat(mix, start, rng)
				"x":
					_kick(mix, start)
					_snare(mix, start, rng)

	var peak := 0.001
	for v in mix:
		peak = maxf(peak, absf(v))
	var gain := 0.85 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(mix[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


static func note_freq(note: String) -> float:
	var semitone: int = NOTE_INDEX[note[0]]
	var rest := note.substr(1)
	if rest.begins_with("#"):
		semitone += 1
		rest = rest.substr(1)
	var midi := 12 * (int(rest) + 1) + semitone
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


static func _render_part(buf: PackedFloat32Array, bars: Array, step: float, kind: String) -> void:
	var tokens: Array[String] = []
	for bar in bars:
		for t in String(bar).split(" ", false):
			tokens.append(t)
	var i := 0
	while i < tokens.size():
		var tok := tokens[i]
		var length := 1
		while i + length < tokens.size() and tokens[i + length] == "-":
			length += 1
		if tok != "." and tok != "-":
			var start := int(i * step * RATE)
			var gate := length * step * (0.8 if kind == "bass" else 0.95)
			_note(buf, start, gate, note_freq(tok), kind)
		i += length


static func _note(buf: PackedFloat32Array, start: int, dur: float, freq: float, kind: String) -> void:
	var n := buf.size()
	var release := 0.03
	var count := int((dur + release) * RATE)
	var phase := 0.0
	var phase2 := 0.0
	for j in count:
		var t := float(j) / RATE
		var env := minf(1.0, t / 0.003)
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / release)
		var s := 0.0
		if kind == "bass":
			env *= 0.6 + 0.4 * exp(-t * 16.0)
			phase = fmod(phase + freq / RATE, 1.0)
			phase2 = fmod(phase2 + freq * 1.006 / RATE, 1.0)
			var sq := (1.0 if phase < 0.5 else -1.0) + (1.0 if phase2 < 0.5 else -1.0)
			s = sq * 0.22 + sin(TAU * phase) * 0.3
		else:
			var f := freq
			if t > 0.12:
				f *= 1.0 + 0.005 * sin(TAU * 5.5 * t)
			phase = fmod(phase + f / RATE, 1.0)
			var pulse := 1.0 if phase < 0.25 else -0.33
			var tri := 1.0 - 4.0 * absf(phase - 0.5)
			s = (pulse * 0.6 + tri * 0.4) * 0.2
		buf[(start + j) % n] += s * env


static func _kick(buf: PackedFloat32Array, start: int) -> void:
	var n := buf.size()
	var phase := 0.0
	for j in int(0.22 * RATE):
		var t := float(j) / RATE
		phase += (42.0 + 120.0 * exp(-t * 28.0)) / RATE
		buf[(start + j) % n] += sin(TAU * phase) * exp(-t * 13.0) * 0.55


static func _snare(buf: PackedFloat32Array, start: int, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	for j in int(0.18 * RATE):
		var t := float(j) / RATE
		var noise := rng.randf_range(-1.0, 1.0) * exp(-t * 20.0) * 0.3
		var body := sin(TAU * 185.0 * t) * exp(-t * 30.0) * 0.22
		buf[(start + j) % n] += noise + body


static func _hat(buf: PackedFloat32Array, start: int, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	var prev := 0.0
	for j in int(0.045 * RATE):
		var t := float(j) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		buf[(start + j) % n] += (white - prev) * 0.5 * exp(-t * 80.0) * 0.12
		prev = white
