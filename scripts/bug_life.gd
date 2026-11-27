class_name BugLife
extends Node3D
## Keeps the meadow alive: tops up butterflies (dry days) and fireflies (dry nights) around the
## player, and flushes hoppers out of freshly cut grass. A few shared lights follow the nearest
## fireflies so they really glow on the ground without one light each.

const BUTTERFLIES := 9
const FIREFLIES := 18
const MAX_FLUSHED := 12
const SPAWN_MIN := 4.0
const SPAWN_MAX := 24.0
const DESPAWN := 36.0
const LIGHTS := 4
const GUARANTEE_TUFTS := 6   ## a big enough swing always flushes at least one hopper

var game: GameState
var _timer := 0.0
var _lights: Array[OmniLight3D] = []


## Pure (tested): which ambient flyer belongs to this time of day / weather ("" = none).
static func ambient_kind(time_of_day: float, wet: bool) -> String:
	if wet:
		return ""
	if time_of_day > 0.28 and time_of_day < 0.70:
		return "butterfly"
	if time_of_day > 0.76 or time_of_day < 0.21:
		return "firefly"
	return ""


## Pure (tested): what leaps out of one cut tuft. Frogs love the rain.
static func flush_for(roll: float, wet: bool) -> String:
	var frog := 0.05 if wet else 0.012
	if roll < frog:
		return "frog"
	if roll < frog + 0.045:
		return "grasshopper"
	return ""


## Pure (tested): the critters flushed by a swing, given one roll per cut tuft.
static func flush_list(rolls: Array, wet: bool) -> Array:
	var out: Array = []
	for r in rolls:
		var k := flush_for(float(r), wet)
		if k != "":
			out.append(k)
	if out.is_empty() and rolls.size() >= GUARANTEE_TUFTS:
		out.append("frog" if wet else "grasshopper")
	return out


func _ready() -> void:
	add_to_group("bug_life")
	for i in LIGHTS:
		var l := OmniLight3D.new()
		l.light_color = Color(0.82, 1.0, 0.4)
		l.omni_range = 3.2
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		_lights.append(l)


func bugs(kind: String = "") -> Array:
	var out: Array = []
	for c in get_children():
		if c is Bug and not c.is_queued_for_deletion() and (kind == "" or c.kind == kind):
			out.append(c)
	return out


func spawn(kind: String, at: Vector3, flushed: bool = false) -> Bug:
	var b := Bug.new()
	b.kind = kind
	b.game = game
	b.position = at
	if flushed:
		b.life = Bug.FLUSH_LIFE
	add_child(b)
	return b


## Called by the meadow with the positions of the tufts just cut.
func flush(spots: Array, from: Vector3, rolls: Array = []) -> int:
	if spots.is_empty() or not is_inside_tree():
		return 0
	var r := rolls
	if r.is_empty():
		for i in spots.size():
			r.append(randf())
	var wet := game != null and Weather.is_wet(game.weather())
	var room := MAX_FLUSHED - bugs("frog").size() - bugs("grasshopper").size()
	var n := 0
	for k in flush_list(r, wet):
		if n >= room:
			break
		var at: Vector3 = spots[(n * 7) % spots.size()]
		var b := spawn(k, Vector3(at.x, Terrain.height_at(at.x, at.z), at.z), true)
		b.startle(from)
		n += 1
	return n


func _meadow_spot(centre: Vector3) -> Variant:
	var md := get_tree().get_first_node_in_group("meadow") as Meadow
	if md == null:
		return null
	for attempt in 6:
		var a := randf() * TAU
		var d := randf_range(SPAWN_MIN, SPAWN_MAX)
		var q := Vector2(centre.x + cos(a) * d, centre.z + sin(a) * d)
		if Meadow.spot_ok(q.x, q.y):
			return Vector3(q.x, Terrain.height_at(q.x, q.y) + 1.0, q.y)
	return null


## Tops up (or clears) the ambient flyers around `centre`.
func populate(centre: Vector3, time_of_day: float, wet: bool, per_call: int = 3) -> void:
	var want := "" if Moon.inside(centre) else ambient_kind(time_of_day, wet)   # no butterflies in a vacuum
	for b in bugs():
		if b.life > 0.0:
			continue
		var gone: bool = b.kind != want
		if gone or Vector2(b.position.x - centre.x, b.position.z - centre.z).length() > DESPAWN:
			remove_child(b)
			b.queue_free()
	if want == "" or centre.x > 200.0:
		return
	var target := BUTTERFLIES if want == "butterfly" else FIREFLIES
	var missing := mini(per_call, target - bugs(want).size())
	for i in missing:
		var at: Variant = _meadow_spot(centre)
		if at != null:
			spawn(want, at)


func _process(delta: float) -> void:
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null or game == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.8
		populate(pl.global_position, game.time_of_day, Weather.is_wet(game.weather()))
	# Hand the shared lights to the fireflies nearest the player.
	var ff := bugs("firefly")
	ff.sort_custom(func(a, b): return a.position.distance_squared_to(pl.global_position) < b.position.distance_squared_to(pl.global_position))
	for i in LIGHTS:
		var on := i < ff.size()
		_lights[i].visible = on
		if on:
			_lights[i].position = ff[i].position
			_lights[i].light_energy = 0.9 * Bug.blink(ff[i]._t, ff[i]._seed)
