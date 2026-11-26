class_name Bug
extends Interactable
## A small catchable meadow critter: butterflies by day, fireflies by night, and grasshoppers
## and frogs that leap out of the grass you cut. Grab with E: bare hands often miss (sneaking
## helps), the Bug Net never does. Charge in and it flees.

const KINDS := ["butterfly", "firefly", "grasshopper", "frog"]
const NET_REACH := 2.3
const HAND_REACH := 1.25
const FLUSH_LIFE := 18.0        ## seconds a flushed hopper hangs around
const WING_COLORS := [Color(1.0, 0.55, 0.12), Color(0.35, 0.68, 1.0), Color(1.0, 0.9, 0.25), Color(0.95, 0.42, 0.75)]

var kind := "butterfly"
var home := Vector3.ZERO
var game: GameState
var life := -1.0                ## >0 = flushed: leaves when it runs out
var caught := false
var _t := 0.0
var _seed := 0.0
var _vel := Vector3.ZERO
var _hop_t := -1.0              ## >=0 while mid-hop
var _hop_wait := 0.6
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _flee := 0.0
var _wings: Array[Node3D] = []
var _legs: Node3D
var _halo: MeshInstance3D
var _halo_mat: ShaderMaterial
var _body: Node3D


# ---------------------------------------------------------------- pure helpers (tested)

## Pure: chance of grabbing a critter. The net always works.
static func catch_chance(k: String, has_net: bool, sneaking: bool) -> float:
	if has_net:
		return 1.0
	match k:
		"frog": return 0.75 if sneaking else 0.35
		"grasshopper": return 0.6 if sneaking else 0.2
		"firefly": return 0.65 if sneaking else 0.3
	return 0.4 if sneaking else 0.1   # butterfly


static func reach(has_net: bool) -> float:
	return NET_REACH if has_net else HAND_REACH


## Pure: E-target ranking, lower wins. A passing bug never steals E from a tree, plot or station in reach.
static func target_rank(dist: float, is_bug: bool) -> float:
	return dist + (100.0 if is_bug else 0.0)


## Pure: how close you can get before it bolts. Sneaking gets you right up to it.
static func scare_radius(speed: float, sneaking: bool) -> float:
	if sneaking:
		return 0.5
	if speed > 6.0:
		return 3.4
	return 1.9 if speed > 0.5 else 0.8


## Pure: position along a hop, t = 0..1.
static func hop_point(a: Vector3, b: Vector3, t: float, height: float) -> Vector3:
	var u := clampf(t, 0.0, 1.0)
	return a.lerp(b, u) + Vector3(0, 4.0 * height * u * (1.0 - u), 0)


## Pure: a firefly's blink, 0.35..1.
static func blink(t: float, phase: float) -> float:
	return 0.35 + 0.65 * pow(0.5 + 0.5 * sin(t * 2.3 + phase), 3.0)


## Pure: where a fleeing critter heads (flat, away from the threat).
static func away_dir(at: Vector3, threat: Vector3) -> Vector3:
	var d := Vector3(at.x - threat.x, 0, at.z - threat.z)
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


# ---------------------------------------------------------------- build

static var _plain_mats := {}


## Swap the toon material (whose outline turns tiny parts into black blobs) for a plain one.
static func _plain(mi: MeshInstance3D, c: Color) -> MeshInstance3D:
	if not _plain_mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.18
		_plain_mats[c] = m
	mi.material_override = _plain_mats[c]
	return mi


static func _box(sz: Vector3, c: Color) -> MeshInstance3D:
	return _plain(Art.box(sz, c), c)


static func _ball(r: float, c: Color, rings: int, segs: int) -> MeshInstance3D:
	return _plain(Art.sphere(r, c, rings, segs), c)

func _ready() -> void:
	add_to_group("bug")
	interact_radius = reach(game != null and game.count("bug_net") > 0)
	_seed = randf() * TAU
	home = position
	_body = Node3D.new()
	add_child(_body)
	match kind:
		"butterfly": _build_butterfly()
		"firefly": _build_firefly()
		"grasshopper": _build_grasshopper()
		_: _build_frog()
	if kind == "frog" or kind == "grasshopper":
		add_to_group("grass_bender")


static func _wing_mesh(side: float) -> ArrayMesh:
	var outline := [Vector2(0.0, 0.03), Vector2(0.09, 0.14), Vector2(0.19, 0.13), Vector2(0.18, 0.03),
		Vector2(0.09, -0.01), Vector2(0.14, -0.07), Vector2(0.09, -0.12), Vector2(0.0, -0.04)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, outline.size() - 1):
		for v in [outline[0], outline[i], outline[i + 1]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x * side, 0, v.y))
	return st.commit()


func _flat_mat(c: Color, emit: float = 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = emit
	return m


func _build_butterfly() -> void:
	var c: Color = WING_COLORS[int(_seed * 10.0) % WING_COLORS.size()]
	var body := _box(Vector3(0.018, 0.018, 0.15), Color(0.36, 0.22, 0.14))
	_body.add_child(body)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		_body.add_child(pivot)
		var w := MeshInstance3D.new()
		w.mesh = _wing_mesh(side)
		w.material_override = _flat_mat(c)
		pivot.add_child(w)
		for spot in [Vector3(0.12, 0.004, 0.085), Vector3(0.085, 0.004, -0.07)]:
			var dot := _ball(0.022, Color(1, 0.98, 0.9), 3, 6)
			dot.scale = Vector3(1, 0.15, 1)
			dot.position = Vector3(spot.x * side, spot.y, spot.z)
			pivot.add_child(dot)
		_wings.append(pivot)
	_body.scale = Vector3.ONE * 1.9
	for mi in _body.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_firefly() -> void:
	var body := _ball(0.018, Color(0.2, 0.14, 0.08), 3, 6)
	_body.add_child(body)
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.038
	sm.height = 0.076
	sm.radial_segments = 6
	sm.rings = 3
	lamp.mesh = sm
	var lm := _flat_mat(Color(0.9, 1.0, 0.4), 2.5)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.material_override = lm
	lamp.position.z = -0.025
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(lamp)
	_halo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.85, 0.85)
	_halo.mesh = q
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = load("res://scripts/shaders/glow_halo.gdshader")
	_halo.material_override = _halo_mat
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_halo)


func _build_grasshopper() -> void:
	var green := Color(0.62, 0.78, 0.16)
	var torso := _box(Vector3(0.09, 0.09, 0.26), green)
	torso.position.y = 0.1
	_body.add_child(torso)
	var head := _ball(0.065, green.lightened(0.12), 4, 7)
	head.position = Vector3(0, 0.13, 0.16)
	_body.add_child(head)
	_legs = Node3D.new()
	_body.add_child(_legs)
	for side in [-1.0, 1.0]:
		var eye := _ball(0.024, Color(0.12, 0.08, 0.05), 3, 5)
		eye.position = Vector3(side * 0.045, 0.165, 0.19)
		_body.add_child(eye)
		var thigh := _box(Vector3(0.025, 0.035, 0.2), green.darkened(0.2))
		thigh.position = Vector3(side * 0.08, 0.13, -0.08)
		thigh.rotation.x = 0.7
		_legs.add_child(thigh)
		var shin := _box(Vector3(0.018, 0.18, 0.02), green.darkened(0.35))
		shin.position = Vector3(side * 0.085, 0.09, -0.19)
		shin.rotation.x = -0.25
		_legs.add_child(shin)
		var feeler := _box(Vector3(0.008, 0.008, 0.16), Color(0.25, 0.3, 0.1))
		feeler.position = Vector3(side * 0.035, 0.2, 0.25)
		feeler.rotation = Vector3(-0.45, side * 0.3, 0)
		_body.add_child(feeler)
	_body.scale = Vector3.ONE * 1.05


func _build_frog() -> void:
	var green := Color(0.2, 0.62, 0.3)
	var torso := _ball(0.15, green, 5, 9)
	torso.scale = Vector3(1.05, 0.72, 1.2)
	torso.position.y = 0.12
	_body.add_child(torso)
	var belly := _ball(0.115, Color(0.93, 0.92, 0.6), 4, 8)
	belly.scale = Vector3(1.0, 0.6, 1.1)
	belly.position = Vector3(0, 0.085, 0.06)
	_body.add_child(belly)
	_legs = Node3D.new()
	_body.add_child(_legs)
	for side in [-1.0, 1.0]:
		var eye := _ball(0.06, green.lightened(0.15), 4, 7)
		eye.position = Vector3(side * 0.08, 0.23, 0.1)
		_body.add_child(eye)
		var pupil := _ball(0.028, Color(0.06, 0.06, 0.05), 3, 6)
		pupil.position = Vector3(side * 0.09, 0.245, 0.15)
		_body.add_child(pupil)
		var leg := _ball(0.075, green.darkened(0.2), 4, 7)
		leg.scale = Vector3(0.7, 0.65, 1.5)
		leg.position = Vector3(side * 0.16, 0.07, -0.07)
		_legs.add_child(leg)
		var foot := _box(Vector3(0.09, 0.025, 0.09), green.darkened(0.3))
		foot.position = Vector3(side * 0.12, 0.015, 0.13)
		_body.add_child(foot)


# ---------------------------------------------------------------- behaviour

func get_prompt(g: GameState) -> String:
	var name_: String = g.item_name(kind)
	if g.count("bug_net") > 0:
		return "[E] Net the %s" % name_
	return "[E] Grab the %s  (sneak [C] up on it, or craft a Bug Net)" % name_


## `roll` is 0..1; below the catch chance means you got it.
func try_catch(g: GameState, sneaking: bool, roll: float) -> bool:
	if caught:
		return false
	var net := g.count("bug_net") > 0
	if roll >= catch_chance(kind, net, sneaking):
		var pl := _player()
		startle(pl.global_position if pl != null else global_position + Vector3.BACK)
		g.say("Whiff! The %s escapes, looking smug." % g.item_name(kind))
		return false
	caught = true
	g.add_item(kind, 1)
	g.say("Caught a %s!  (x%d)" % [g.item_name(kind), g.count(kind)])
	if is_inside_tree():
		var col := Color(1.0, 0.95, 0.4) if kind == "firefly" else Color(0.8, 1.0, 0.7)
		FX.burst(self, global_position + Vector3(0, 0.15, 0), col, 12, 0.06, 2.4, -3.0, "sphere", 150.0, true)
		Sfx.play_on(self, "ribbit" if kind == "frog" else "blip", 1.0 if kind == "frog" else 1.35)
	remove_from_group("interactable")
	remove_from_group("bug")
	queue_free()
	return true


func interact(g: GameState) -> void:
	var pl := _player()
	var sneaking: bool = pl != null and bool(pl.get("crouching"))
	if pl != null and g.count("bug_net") > 0 and pl.has_method("swing_net"):
		pl.swing_net()
	try_catch(g, sneaking, randf())


func startle(threat: Vector3) -> void:
	_flee = 1.4
	var d := away_dir(position, threat).rotated(Vector3.UP, randf_range(-0.5, 0.5))
	if kind == "butterfly" or kind == "firefly":
		_vel = d * 3.2 + Vector3(0, 1.2, 0)
		home += d * 2.5
	else:
		_hop_wait = 0.0
		if _hop_t < 0.0:
			_start_hop(d)


func _player() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player") as Node3D


func _start_hop(dir: Vector3) -> void:
	_hop_from = position
	var length := (1.9 if kind == "grasshopper" else 1.2) * randf_range(0.7, 1.15)
	var to := position + dir * length
	to.y = Terrain.height_at(to.x, to.z)
	if to.y < -0.6:   # don't hop into the pond (frogs would, but you couldn't follow)
		to = position
	_hop_to = to
	_hop_t = 0.0
	rotation.y = atan2(dir.x, dir.z)
	if kind == "frog" and randf() < 0.3 and is_inside_tree():
		Sfx.play_on(self, "ribbit", randf_range(0.85, 1.2))


func _process(delta: float) -> void:
	if caught:
		return
	_t += delta
	_flee = maxf(0.0, _flee - delta)
	if game != null:
		interact_radius = reach(game.count("bug_net") > 0)
	if life > 0.0:
		life -= delta
		if life <= 0.0:
			FX.burst(self, global_position, Color(0.55, 0.75, 0.3), 5, 0.05, 1.4, -3.0)
			queue_free()
			return
	var pl := _player()
	if pl != null and _flee <= 0.0 and pl.get("vehicle") == null:
		var v: Vector3 = (pl as CharacterBody3D).velocity if pl is CharacterBody3D else Vector3.ZERO
		var dist := Vector2(pl.global_position.x - position.x, pl.global_position.z - position.z).length()
		if dist < scare_radius(Vector2(v.x, v.z).length(), bool(pl.get("crouching"))):
			startle(pl.global_position)
	if kind == "butterfly" or kind == "firefly":
		_fly(delta)
	else:
		_hop(delta)


func _fly(delta: float) -> void:
	var fly := kind == "butterfly"
	var spd := 1.15 if fly else 0.5
	var wander := Vector3(sin(_t * 0.9 + _seed) + 0.6 * sin(_t * 2.3 + _seed * 2.0), 0.0,
		cos(_t * 0.7 + _seed * 1.3) + 0.6 * cos(_t * 1.9 + _seed)) * spd
	var pull := Vector3(home.x - position.x, 0, home.z - position.z) * 0.55
	var want := wander + pull
	var height := Terrain.height_at(position.x, position.z) + (1.0 if fly else 1.1) + sin(_t * 1.7 + _seed) * (0.28 if fly else 0.35)
	want.y = (height - position.y) * 2.0
	_vel = _vel.lerp(want, minf(1.0, delta * (1.2 if _flee > 0.0 else 3.0)))
	position += _vel * delta
	if Vector2(_vel.x, _vel.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(_vel.x, _vel.z), minf(1.0, delta * 6.0))
	if fly:
		var flap := sin(_t * (26.0 if _flee > 0.0 else 15.0) + _seed)
		for i in _wings.size():
			_wings[i].rotation.z = (1.0 if i == 1 else -1.0) * (0.18 + flap * 0.8)
		_body.position.y = -flap * 0.025
	else:
		var b := blink(_t, _seed)
		_halo_mat.set_shader_parameter("strength", b)
		_halo.scale = Vector3.ONE * (0.7 + 0.5 * b)


func _hop(delta: float) -> void:
	var dur := 0.38 if kind == "grasshopper" else 0.42
	if _hop_t >= 0.0:
		_hop_t += delta / dur
		position = hop_point(_hop_from, _hop_to, _hop_t, 0.75 if kind == "grasshopper" else 0.5)
		_body.rotation.x = lerpf(-0.45, 0.4, clampf(_hop_t, 0.0, 1.0))
		_legs.rotation.x = 0.55 * sin(clampf(_hop_t, 0.0, 1.0) * PI)
		if _hop_t >= 1.0:
			_hop_t = -1.0
			position = _hop_to
			_body.rotation.x = 0.0
			_legs.rotation.x = 0.0
			_body.scale = Vector3(1.25, 0.65, 1.15)   # splat on landing
			_hop_wait = 0.12 if _flee > 0.0 else randf_range(0.7, 2.2)
		return
	var rest := 1.05 if kind == "grasshopper" else 1.0
	_body.scale = _body.scale.lerp(Vector3.ONE * rest, minf(1.0, delta * 12.0))
	if kind == "frog":   # throat puffs
		_body.scale.y = rest * (1.0 + 0.06 * maxf(0.0, sin(_t * 5.0 + _seed)))
	_hop_wait -= delta
	if _hop_wait <= 0.0:
		var pl := _player()
		var dir := Vector3(cos(_t + _seed), 0, sin(_t * 1.7 + _seed)).normalized()
		if _flee > 0.0 and pl != null:
			dir = away_dir(position, pl.global_position).rotated(Vector3.UP, randf_range(-0.6, 0.6))
		_start_hop(dir)
