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
}

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _last_money := -1


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
		phase += TAU * lerpf(float(p[0]), float(p[1]), t) / RATE
		var env := minf(1.0, t * 40.0) * pow(1.0 - t, 2.0)
		var s := (sin(phase) * (1.0 - float(p[3])) + rng.randf_range(-1, 1) * float(p[3])) * env * 0.6
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


func _ready() -> void:
	for i in 4:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(pl)
		_players.append(pl)
	var g: Node = get_node("/root/Game")
	g.money_changed.connect(_on_money)
	g.toast.connect(func(_t): play("blip"))
	g.shake.connect(func(a: float): if a >= 0.25: play("thud"))


func _on_money(v: int) -> void:
	if _last_money >= 0:
		play("coin" if v > _last_money else "spend")
	_last_money = v


## +-5% pitch variation so repeated sounds do not feel robotic. r in 0..1.
static func pitch_jitter(r: float) -> float:
	return 0.95 + clampf(r, 0.0, 1.0) * 0.10


func play(kind: String) -> void:
	if not _cache.has(kind):
		_cache[kind] = make(kind)
	for pl in _players:
		if not pl.playing:
			pl.stream = _cache[kind]
			pl.pitch_scale = pitch_jitter(randf())
			pl.play()
			return
