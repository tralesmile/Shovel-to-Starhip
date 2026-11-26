class_name Sfx
extends Node
## Procedurally synthesised sound effects (no audio files, so nothing to license).
## Hooks into GameState signals: coin chime on money gain, blip on toasts, thud on shakes.

const RATE := 22050
## kind -> [start_hz, end_hz, seconds, noise_mix]
const KINDS := {
	"coin": [880.0, 1320.0, 0.18, 0.0],
	"blip": [520.0, 640.0, 0.07, 0.0],
	"thud": [120.0, 45.0, 0.22, 0.25],
	"spend": [660.0, 330.0, 0.14, 0.0],
	"chop": [210.0, 90.0, 0.12, 0.45],
	"step": [95.0, 60.0, 0.06, 0.5],
	"step_wood": [150.0, 110.0, 0.05, 0.25],
	"step_road": [70.0, 50.0, 0.05, 0.8],
	"splash": [400.0, 150.0, 0.3, 0.7],
	"clang": [1400.0, 900.0, 0.16, 0.2],
	"sizzle": [2200.0, 1400.0, 0.4, 0.92],
	"boing": [260.0, 720.0, 0.22, 0.0],
	"zap": [1800.0, 400.0, 0.12, 0.6],
	"thunder": [95.0, 32.0, 0.95, 0.75],
	"boom": [140.0, 30.0, 0.75, 0.6],
	"drip": [750.0, 1700.0, 0.08, 0.0],
	"rustle": [2600.0, 1700.0, 0.11, 0.97],
	"swish": [1100.0, 260.0, 0.24, 0.9],
	"skid": [900.0, 320.0, 0.2, 0.7],
	"vacuum": [300.0, 900.0, 0.3, 0.35],
	"crunch": [180.0, 40.0, 0.35, 0.7],
	"turbo": [180.0, 980.0, 0.45, 0.45],
	"happy": [620.0, 980.0, 0.14, 0.0],
	"ribbit": [230.0, 150.0, 0.17, 0.18],
	"fanfare": [523.0, 1046.0, 0.5, 0.0],
	"squeak": [1150.0, 1900.0, 0.2, 0.08],
	"cluck": [760.0, 430.0, 0.09, 0.22],
	"bleat": [430.0, 360.0, 0.42, 0.16],
	"flap": [520.0, 260.0, 0.09, 0.96],
	"whistle": [1250.0, 2100.0, 0.34, 0.03],
	"creak": [310.0, 190.0, 0.3, 0.35],
}

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _last_money := -1
var _step_dist := 0.0
var _engine: AudioStreamPlayer = null
const ENGINE_BASE_HZ := 55.0
const STEP_LENGTH := 2.1


## Accumulates walked distance; returns [new_accumulator, step_sound_due].
static func step_progress(acc: float, moved: float) -> Array:
	acc += moved
	if acc >= STEP_LENGTH:
		return [fmod(acc, STEP_LENGTH), true]
	return [acc, false]


## Surface under a world position: interiors are wood floors, the town road is
## a strip along z=16, everything else is grass.
static func surface_at(pos: Vector3) -> String:
	if pos.x > 300.0:
		return "road" if MineCave.inside(pos) else "wood"   # the mine has a stone floor
	if absf(pos.z - 16.0) < 2.4 and absf(pos.x) < 62.0:
		return "road"
	return "grass"


## Footstep loudness (linear): crouched sneaking is a quarter as loud.
const CROUCH_STEP_VOL := 0.25
static func step_volume(crouched: bool) -> float:
	return CROUCH_STEP_VOL if crouched else 1.0


static func step_kind(surface: String) -> String:
	match surface:
		"wood":
			return "step_wood"
		"road":
			return "step_road"
	return "step"


## Engine pitch scale from car speed (m/s): idle 0.8, about 2.4 at top speed.
static func engine_pitch(speed: float) -> float:
	return 0.8 + clampf(absf(speed) / 18.0, 0.0, 1.2) * 1.33


## Engine volume (linear) from speed: quiet idle, louder with revs.
static func engine_volume(speed: float) -> float:
	return 0.25 + clampf(absf(speed) / 18.0, 0.0, 1.0) * 0.45


## Seamless looping engine hum (whole number of cycles so the loop has no click).
static func make_engine() -> AudioStreamWAV:
	var cycles := 11
	var n := int(RATE * cycles / ENGINE_BASE_HZ)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var ph := TAU * float(i) * cycles / float(n)
		var s := sin(ph) * 0.5 + sin(ph * 2.0) * 0.3 + sin(ph * 3.0) * 0.15 + sin(ph * 5.0) * 0.05
		s *= 0.55 + 0.25 * sin(ph * 0.5 * 4.0)  # rough putter
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _update_engine(pl: Node) -> void:
	var car = pl.get("vehicle") if pl != null else null
	if car == null:
		if _engine != null and _engine.playing:
			_engine.stop()
		return
	if _engine == null:
		_engine = AudioStreamPlayer.new()
		_engine.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		_engine.stream = make_engine()
		add_child(_engine)
	if not _engine.playing:
		_engine.play()
	var spd: float = car.get("speed")
	_engine.pitch_scale = engine_pitch(spd)
	_engine.volume_db = linear_to_db(engine_volume(spd))


## Play a named effect from anywhere (finds the Sfx node via its group).
static func play_on(node: Node, kind: String, pitch_mult: float = 1.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	var s := node.get_tree().get_first_node_in_group("sfx")
	if s != null:
		s.play(kind, 1.0, pitch_mult)


func _process(delta: float) -> void:
	var pl := get_tree().get_first_node_in_group("player")
	_update_engine(pl)
	if pl == null or not (pl is CharacterBody3D) or pl.get("vehicle") != null:
		return
	var flat := Vector2(pl.velocity.x, pl.velocity.z).length()
	if pl.is_on_floor() and flat > 1.0:
		var r := step_progress(_step_dist, flat * delta)
		_step_dist = r[0]
		if r[1]:
			play(step_kind(surface_at(pl.global_position)), step_volume(bool(pl.get("crouching"))))


## Builds a 16-bit mono WAV for a named effect. Pure function, deterministic.
static func make(kind: String) -> AudioStreamWAV:
	var p: Array = KINDS.get(kind, KINDS["blip"])
	var n := int(RATE * float(p[2]))
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in n:
		var t := float(i) / float(n)
		var wobble := 1.0 + 0.09 * sin(t * 62.0) if kind == "bleat" else 1.0   # meh-eh-eh
		phase += TAU * lerpf(float(p[0]), float(p[1]), t) * wobble / RATE
		var env := minf(1.0, t * 40.0) * pow(1.0 - t, 2.0)
		var s := (sin(phase) * (1.0 - float(p[3])) + rng.randf_range(-1, 1) * float(p[3])) * env * 0.6
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


func _ready() -> void:
	add_to_group("sfx")
	for i in 4:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(pl)
		_players.append(pl)
	var g: Node = get_node("/root/Game")
	g.money_changed.connect(_on_money)
	g.toast.connect(func(_t): play("blip"))
	g.story_advanced.connect(func(_a): play("fanfare"); get_tree().create_timer(0.18).timeout.connect(func(): play("fanfare", 0.8, 1.5)))
	g.shake.connect(func(a: float): if a >= 0.25: play("thud"))


func _on_money(v: int) -> void:
	if _last_money >= 0:
		play("coin" if v > _last_money else "spend")
	_last_money = v


## +-5% pitch variation so repeated sounds do not feel robotic. r in 0..1.
static func pitch_jitter(r: float) -> float:
	return 0.95 + clampf(r, 0.0, 1.0) * 0.10


func play(kind: String, volume: float = 1.0, pitch_mult: float = 1.0) -> void:
	if not _cache.has(kind):
		_cache[kind] = make(kind)
	for pl in _players:
		if not pl.playing:
			pl.stream = _cache[kind]
			pl.pitch_scale = pitch_jitter(randf()) * pitch_mult
			pl.volume_db = linear_to_db(maxf(volume, 0.0001))
			pl.play()
			return
