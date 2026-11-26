class_name PondLife
extends Node3D
## What lives in the pond: fish shadows you can actually see and aim at, the AI that makes
## them notice, nibble and bite your bobber, expanding ripple rings (fed to the water
## shader), and the odd show-off leaping out of the water.

const RADIUS := 6.8             ## fish stay this close to the pond centre
const COUNT := 7
const MAX_RIPPLES := 16
const RIPPLE_LIFE := 2.2
const SPOOK_DIST := 0.55        ## bobber landing on a fish's head scares it off
const NOTICE_DIST := 3.2
const SHADOW_Y := 0.1           ## above the wave crests so the silhouette stays visible

## water ripples: {x, z, age, strength}
var ripples: Array = []
var water_mat: ShaderMaterial
var fish: Array = []
var rng := RandomNumberGenerator.new()
var bobber_on := false
var bobber := Vector2.ZERO
var baited := false
var game: GameState

var tick_event := ""          ## latest "nibble"/"bite", consumed by the fishing spot
var _wait := 0.0
var _chosen := -1
var _meshes: Array[MeshInstance3D] = []
var _jump_in := 6.0
var _jumper: Node3D
var _jump_t := 0.0
var _jump_from := Vector3.ZERO
var _jump_dir := Vector3.ZERO
var _rain_in := 0.0


static func new_fish(species: String, pos: Vector2, heading: float, cm: int) -> Dictionary:
	return {"species": species, "pos": pos, "heading": heading, "cm": cm, "mode": "wander", "t": 0.0, "nibbles": 0, "turn": 0.0}


## Shadow length in metres: bigger catch, bigger shadow, so you can pick your target.
static func shadow_length(species: String, cm: int) -> float:
	if species in Fishing.JUNK:
		return 0.75
	return clampf(0.62 + cm * 0.018, 0.65, 2.0)


## Seconds before the nearest fish takes an interest. Bait and rain both help.
static func interest_delay(roll: float, bait: bool, rain: bool) -> float:
	var d := lerpf(1.2, 3.2, roll)
	if bait:
		d *= 0.45
	if rain:
		d *= 0.7
	return d


## Fake-out tugs before the real bite.
static func nibble_count(roll: float, bait: bool) -> int:
	var n := int(roll * 3.999)           # 0..3
	return mini(n, 1) if bait else n


## Which fish gets curious: the nearest one to the bobber. -1 if none is free.
static func pick_fish(list: Array, at: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in list.size():
		if list[i]["mode"] == "flee":
			continue
		var d: float = (list[i]["pos"] as Vector2).distance_to(at)
		if d < best_d:
			best = i
			best_d = d
	return best


static func clamp_to_pond(p: Vector2, radius: float = RADIUS) -> Vector2:
	var off := p - Terrain.POND_CENTER
	return Terrain.POND_CENTER + off.limit_length(radius)


## Moves one fish. Returns "", "nibble" or "bite". Pure apart from the rng.
static func step_fish(f: Dictionary, delta: float, target: Vector2, r: RandomNumberGenerator) -> String:
	var pos: Vector2 = f["pos"]
	var head: float = f["heading"]
	var speed := 0.45
	var event := ""
	f["t"] = float(f["t"]) - delta
	match str(f["mode"]):
		"wander":
			if float(f["t"]) <= 0.0:
				f["t"] = r.randf_range(1.0, 3.0)
				f["turn"] = r.randf_range(-0.8, 0.8)
			head += float(f["turn"]) * delta
			if pos.distance_to(Terrain.POND_CENTER) > RADIUS - 1.0:
				head = rotate_toward(head, (Terrain.POND_CENTER - pos).angle(), 2.2 * delta)
			if str(f["species"]) in Fishing.JUNK:
				speed = 0.07
		"approach":
			var to := target - pos
			head = rotate_toward(head, to.angle(), 5.0 * delta)
			speed = 1.15 if not str(f["species"]) in Fishing.JUNK else 0.9
			# The nose stops just short of the hook.
			if to.length() <= 0.32:
				if int(f["nibbles"]) > 0:
					f["nibbles"] = int(f["nibbles"]) - 1
					f["mode"] = "backoff"
					f["t"] = r.randf_range(0.5, 1.1)
					event = "nibble"
				else:
					f["mode"] = "bite"
					event = "bite"
				speed = 0.0
		"backoff":
			head = rotate_toward(head, (target - pos).angle(), 5.0 * delta)
			speed = -0.55
			if float(f["t"]) <= 0.0:
				f["mode"] = "approach"
		"bite":
			speed = 0.0
		"flee":
			head = rotate_toward(head, (pos - target).angle(), 6.0 * delta)
			speed = 2.6
			if float(f["t"]) <= 0.0:
				f["mode"] = "wander"
	f["heading"] = wrapf(head, -PI, PI)
	f["pos"] = clamp_to_pond(pos + Vector2.from_angle(head) * speed * delta)
	return event


func _ready() -> void:
	add_to_group("pond")
	rng.seed = 77
	for i in COUNT:
		_add_fish(_species_for(i))


## The pond always holds a readable mix: little, middling, one boot, and now and then gold.
func _species_for(i: int) -> String:
	var fixed := ["minnow", "carp", "boot", "minnow", "trout"]
	if i < fixed.size():
		return fixed[i]
	return Fishing.roll_fish(rng.randf())


func _random_spot() -> Vector2:
	return Terrain.POND_CENTER + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * (RADIUS - 0.8)


func _add_fish(species: String) -> void:
	var f := new_fish(species, _random_spot(), rng.randf() * TAU, Fishing.size_for(species, rng.randf()))
	fish.append(f)
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(1.0, 0.5)
	q.subdivide_width = 10
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/fish_shadow.gdshader")
	m.render_priority = 1
	m.set_shader_parameter("junk", 1.0 if species in Fishing.JUNK else 0.0)
	m.set_shader_parameter("gold", 1.0 if species == "golden_carp" else 0.0)
	m.set_shader_parameter("phase", rng.randf() * TAU)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_meshes.append(mi)
	_place_mesh(fish.size() - 1)


func _place_mesh(i: int) -> void:
	var f: Dictionary = fish[i]
	var p: Vector2 = f["pos"]
	var mi := _meshes[i]
	mi.position = Vector3(p.x, Terrain.WATER_LEVEL + SHADOW_Y, p.y)
	mi.rotation.y = -float(f["heading"])
	var len := shadow_length(str(f["species"]), int(f["cm"]))
	mi.scale = Vector3(len, 1.0, len)
	var rate := 14.0 if f["mode"] == "flee" else (9.0 if f["mode"] == "approach" else 4.5)
	(mi.material_override as ShaderMaterial).set_shader_parameter("wiggle_rate", rate)


## A bobber has landed. Returns true if it landed on a fish and spooked it.
func set_bobber(at: Vector2, bait: bool) -> bool:
	tick_event = ""
	bobber_on = true
	bobber = at
	baited = bait
	_chosen = -1
	var spooked := false
	for f in fish:
		if (f["pos"] as Vector2).distance_to(at) < SPOOK_DIST and not str(f["species"]) in Fishing.JUNK:
			_flee(f)
			spooked = true
	var rain := game != null and Weather.is_wet(game.weather())
	_wait = interest_delay(rng.randf(), bait, rain)
	return spooked


func _flee(f: Dictionary) -> void:
	f["mode"] = "flee"
	f["t"] = 1.3


## Line came in: anything still interested loses interest in a hurry.
func clear_bobber() -> void:
	if _chosen >= 0 and _chosen < fish.size() and fish[_chosen]["mode"] != "wander":
		_flee(fish[_chosen])
	bobber_on = false
	_chosen = -1


## The fish on the hook ("" if none).
func hooked_species() -> String:
	return str(fish[_chosen]["species"]) if _chosen >= 0 else ""


func hooked_cm() -> int:
	return int(fish[_chosen]["cm"]) if _chosen >= 0 else 0


## The hooked fish leaves the shadow list while it is fought; returns its data.
func take_hooked() -> Dictionary:
	if _chosen < 0:
		return {}
	var f: Dictionary = fish[_chosen]
	fish.remove_at(_chosen)
	_meshes[_chosen].queue_free()
	_meshes.remove_at(_chosen)
	_chosen = -1
	bobber_on = false
	return f


## Replace a fish that left the pond with a fresh one.
func restock() -> void:
	if fish.size() >= COUNT:
		return
	var species := Fishing.roll_fish(rng.randf())
	if not fish.any(func(f): return f["species"] == "minnow"):
		species = "minnow"
	_add_fish(species)


func add_ripple(at: Vector2, strength: float = 1.0) -> void:
	ripples.append({"x": at.x, "z": at.y, "age": 0.0, "strength": strength})
	if ripples.size() > MAX_RIPPLES:
		ripples.pop_front()


func splash(at: Vector2, size: float = 1.0) -> void:
	var p := Vector3(at.x, Terrain.WATER_LEVEL + 0.12, at.y)
	FX.burst(self, p, Color(0.82, 0.95, 1.0), int(8 + 10 * size), 0.05 + 0.03 * size, 2.2 + 1.4 * size, -9.0, "sphere", 45.0)
	add_ripple(at, minf(1.0, 0.6 + 0.4 * size))


## Advances the AI one step. Returns "nibble", "bite" or "" for the fish on your line.
func tick(delta: float) -> String:
	var result := ""
	if bobber_on and _chosen < 0:
		_wait -= delta
		var i := pick_fish(fish, bobber)
		# A fish right by the bobber notices sooner than one across the pond.
		if i >= 0 and (_wait <= 0.0 or (_wait <= 0.8 and (fish[i]["pos"] as Vector2).distance_to(bobber) < NOTICE_DIST)):
			_chosen = i
			fish[i]["mode"] = "approach"
			fish[i]["nibbles"] = nibble_count(rng.randf(), baited)
	for i in fish.size():
		var ev := step_fish(fish[i], delta, bobber, rng)
		if i == _chosen and ev != "":
			result = ev
		_place_mesh(i)
	return result


func _process(delta: float) -> void:
	var ev := tick(delta)
	if ev != "":
		tick_event = ev
	for r in ripples:
		r["age"] = float(r["age"]) + delta
	ripples = ripples.filter(func(r): return float(r["age"]) < RIPPLE_LIFE)
	_push_ripples()
	_ambient(delta)


func _push_ripples() -> void:
	if water_mat == null:
		return
	var arr := PackedVector4Array()
	for i in MAX_RIPPLES:
		if i < ripples.size():
			var r: Dictionary = ripples[i]
			arr.append(Vector4(r["x"], r["z"], r["age"], r["strength"]))
		else:
			arr.append(Vector4.ZERO)
	water_mat.set_shader_parameter("ripples", arr)


## Now and then a fish shows off with a leap; rain peppers the surface with rings.
func _ambient(delta: float) -> void:
	if game != null and Weather.is_wet(game.weather()):
		_rain_in -= delta
		if _rain_in <= 0.0:
			_rain_in = 0.16
			add_ripple(_random_spot(), 0.35)
	if _jumper != null:
		_jump_t += delta / 0.8
		var p := _jump_from + _jump_dir * _jump_t * 1.5
		p.y += sin(minf(_jump_t, 1.0) * PI) * 1.0
		_jumper.position = p
		_jumper.rotation.z = lerpf(1.0, -1.0, _jump_t)
		if _jump_t >= 1.0:
			splash(Vector2(p.x, p.z), 0.6)
			_jumper.queue_free()
			_jumper = null
		return
	_jump_in -= delta
	if _jump_in <= 0.0:
		_jump_in = rng.randf_range(5.0, 13.0)
		var at := _random_spot()
		leap(at, rng.randf() * TAU, ["minnow", "carp", "trout"][rng.randi() % 3])


func leap(at: Vector2, heading: float, species: String) -> void:
	if _jumper != null:
		return
	_jumper = FishModel.build(species)
	_jumper.scale = Vector3.ONE * 0.8
	add_child(_jumper)
	_jump_from = Vector3(at.x, Terrain.WATER_LEVEL, at.y)
	_jump_dir = Vector3(cos(heading), 0, sin(heading))
	_jumper.position = _jump_from
	_jumper.rotation.y = -heading
	_jump_t = 0.0
	splash(at, 0.4)
