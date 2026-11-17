class_name Music
extends Node
## Procedurally generated background music (no audio files, nothing to license).
## A seamless 8-bar loop: soft pad chords + a pentatonic pluck melody from a fixed seed.
## "day" is bright major; "night" is a slower, lower, sparser version. Plays on the Music bus.

const RATE := 11025
## Chord roots (semitones above C) for the 4-chord loop: C, Am, F, G (day) / Am, F, C, G (night)
const DAY_ROOTS := [0, 9, 5, 7]
const NIGHT_ROOTS := [9, 5, 0, 7]
const PENTATONIC := [0, 2, 4, 7, 9]

var _player: AudioStreamPlayer
var _mode := ""
var _cache := {}


static func note_hz(semitones_from_c4: float) -> float:
	return 261.63 * pow(2.0, semitones_from_c4 / 12.0)


## "night" between 20:00 and 06:00, otherwise "day".
static func mode_for_hour(hour: float) -> String:
	return "night" if hour >= 20.0 or hour < 6.0 else "day"


## Seconds per beat for a mode (night is slower).
static func beat_seconds(mode: String) -> float:
	return 0.75 if mode == "night" else 0.5


## Loop length in seconds: 4 chords x 4 beats x 2 passes.
static func loop_seconds(mode: String) -> float:
	return beat_seconds(mode) * 32.0


static func _add_tone(buf: PackedFloat32Array, start: float, dur: float, hz: float, amp: float, pad: bool) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	for k in n:
		var idx := i0 + k
		if idx >= buf.size():
			idx -= buf.size()  # wrap so the loop is seamless
		var t := float(k) / RATE
		var env: float
		if pad:
			env = minf(1.0, t * 3.0) * minf(1.0, (dur - t) * 3.0)
		else:
			env = minf(1.0, t * 200.0) * exp(-t * 4.0)
		var ph := TAU * hz * t
		var s := sin(ph) + (0.0 if pad else 0.3 * sin(ph * 2.0))
		buf[idx] += s * env * amp


## Builds the loop for a mode. Deterministic.
static func make(mode: String) -> AudioStreamWAV:
	var roots: Array = NIGHT_ROOTS if mode == "night" else DAY_ROOTS
	var beat := beat_seconds(mode)
	var total := int(loop_seconds(mode) * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if mode == "day" else 11
	var base := -12.0 if mode == "night" else 0.0
	for pass_i in 2:
		for c in 4:
			var bar_start := (pass_i * 4 + c) * 4.0 * beat
			var root: int = roots[c]
			for iv in [0, 4, 7]:
				_add_tone(buf, bar_start, 4.0 * beat, note_hz(base + root + iv - 12.0), 0.09, true)
			var step := 1.0 if mode == "day" else 2.0
			var b := 0.0
			while b < 4.0:
				if rng.randf() < (0.75 if mode == "day" else 0.6):
					var deg: int = PENTATONIC[rng.randi() % PENTATONIC.size()]
					_add_tone(buf, bar_start + b * beat, beat * 1.6, note_hz(base + root + deg + 12.0), 0.12, false)
				b += step
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 24000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = total
	return w


const FADE_SECONDS := 3.0

var _fade_in: AudioStreamPlayer
var _fade_out: AudioStreamPlayer
var _fade_t := 1.0


## Crossfade progress 0..1 after delta seconds (pure helper for tests).
static func fade_progress(t: float, delta: float, seconds: float = FADE_SECONDS) -> float:
	return clampf(t + delta / maxf(seconds, 0.001), 0.0, 1.0)


## Equal-power gains (in, out) for crossfade progress t.
static func fade_gains(t: float) -> Vector2:
	var c := clampf(t, 0.0, 1.0)
	return Vector2(sin(c * PI * 0.5), cos(c * PI * 0.5))


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	add_child(p)
	return p


func _ready() -> void:
	add_to_group("music")
	_player = _make_player()
	_fade_out = _make_player()
	_fade_in = _player


func set_mode(mode: String) -> void:
	if mode == _mode:
		return
	var first := _mode == ""
	_mode = mode
	if not _cache.has(mode):
		_cache[mode] = make(mode)
	# the old track keeps playing and fades out while the new one fades in
	var old := _fade_in
	_fade_in = _fade_out
	_fade_out = old
	_fade_in.stream = _cache[mode]
	_fade_in.play()
	_fade_t = 1.0 if first else 0.0
	_apply_fade()


func _apply_fade() -> void:
	var g := fade_gains(_fade_t)
	_fade_in.volume_db = linear_to_db(maxf(g.x, 0.0001))
	_fade_out.volume_db = linear_to_db(maxf(g.y, 0.0001))
	if _fade_t >= 1.0 and _fade_out.playing:
		_fade_out.stop()


func _process(delta: float) -> void:
	var g := get_node_or_null("/root/Game")
	if g != null:
		set_mode(mode_for_hour(g.time_of_day))
	if _fade_t < 1.0:
		_fade_t = fade_progress(_fade_t, delta)
		_apply_fade()
