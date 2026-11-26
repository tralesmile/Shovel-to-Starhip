class_name MineCave
extends Node3D
## Gran's Old Mine: a walk-in cave (parked far from town like the other interiors) with glowing
## crystals, ore rocks that regrow, hard crystal geodes that need a copper pickaxe, and a cracked
## wall hiding Gran's secret pocket that only a Boom Turnip can open.

const ORIGIN := Vector3(400, 0, 220)
const SIZE := Vector3(24.0, 6.0, 22.0)
const ENTRANCE := Vector3(-22.0, 0.0, -23.0)
const CRYSTAL_SHADER := preload("res://scripts/shaders/crystal.gdshader")
const ROCK_A := Color(0.27, 0.25, 0.3)
const ROCK_B := Color(0.34, 0.3, 0.32)
const FLOOR_COL := Color(0.3, 0.27, 0.27)
const CRYSTAL_COLORS := [Color(0.3, 0.85, 1.0), Color(0.75, 0.45, 1.0), Color(0.35, 1.0, 0.65)]

## Local positions of the ore: [kind, position]. kind: "rich", "plain" or "geode".
const ORE_SPOTS := [
	["rich", Vector3(-6.0, 0, -7.5)], ["plain", Vector3(-1.5, 0, -8.2)], ["rich", Vector3(4.0, 0, -7.0)],
	["geode", Vector3(8.8, 0, -7.6)], ["rich", Vector3(9.2, 0, -1.0)], ["plain", Vector3(-8.6, 0, 5.5)],
	["geode", Vector3(8.6, 0, 5.0)], ["geode", Vector3(-16.2, 0, -1.4)], ["geode", Vector3(-15.0, 0, 1.7)],
]

static var _crystal_mats: Dictionary = {}
var entry_point := Vector3.ZERO
var _drip_t := 2.0


## Pure (tested): is a world position down in the mine?
static func inside(p: Vector3) -> bool:
	return p.x > ORIGIN.x - 30.0 and p.x < ORIGIN.x + 30.0 and absf(p.z - ORIGIN.z) < 20.0


## Pure (tested): seconds between water drips; r in 0..1.
static func drip_gap(r: float) -> float:
	return lerpf(1.6, 5.0, clampf(r, 0.0, 1.0))


## Dark, cool underground lighting that overrides the outdoor sun and weather.
static func apply_light(env: Environment, sun: DirectionalLight3D) -> void:
	sun.light_energy = 0.0
	env.ambient_light_color = Color(0.42, 0.44, 0.68)
	env.ambient_light_energy = 0.38
	env.fog_light_color = Color(0.06, 0.05, 0.11)
	env.fog_density = 0.016
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.08
	env.adjustment_brightness = 1.0


static func crystal_mat(c: Color) -> ShaderMaterial:
	var key := c.to_html()
	if not _crystal_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = CRYSTAL_SHADER
		m.set_shader_parameter("tint", c)
		_crystal_mats[key] = m
	return _crystal_mats[key]


## A spiky crystal cluster (six-sided prisms with pointed tips).
static func crystal_cluster(c: Color, count: int, scale_by: float, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	for i in count:
		var h := rng.randf_range(0.45, 1.1) * scale_by * (1.4 if i == 0 else 1.0)
		var r := h * rng.randf_range(0.12, 0.18)
		var spike := Node3D.new()
		root.add_child(spike)
		var a := TAU * float(i) / float(count) + rng.randf() * 0.6
		var off := 0.0 if i == 0 else 0.28 * scale_by
		spike.position = Vector3(cos(a) * off, 0, sin(a) * off)
		spike.rotation = Vector3(sin(a) * (0.0 if i == 0 else 0.55), rng.randf() * TAU, -cos(a) * (0.0 if i == 0 else 0.55))
		for part in 2:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.radial_segments = 6
			cm.rings = 1
			cm.top_radius = r if part == 0 else 0.0
			cm.bottom_radius = r * 0.85 if part == 0 else r
			cm.height = h if part == 0 else h * 0.35
			mi.mesh = cm
			mi.material_override = crystal_mat(c)
			mi.position.y = h * 0.5 if part == 0 else h * 1.175
			spike.add_child(mi)
	return root


## A faceted boulder (very low-poly sphere), used for cave walls and rubble.
static func boulder(r: float, c: Color, rng: RandomNumberGenerator) -> MeshInstance3D:
	var mi := Art.sphere(r, c, 3, 6)
	mi.scale = Vector3(rng.randf_range(0.85, 1.25), rng.randf_range(0.75, 1.2), rng.randf_range(0.85, 1.25))
	mi.rotation = Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)
	return mi


## Invisible collision slab (centre position).
static func wall_body(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)
	return body


## Builds the surface entrance under `surface` and the cave itself under this node.
func build(surface: Node3D) -> void:
	position = ORIGIN
	entry_point = ORIGIN + Vector3(0, 0.1, SIZE.z / 2.0 - 3.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_build_shell(rng)
	_build_props(rng)
	_build_ore()
	_build_secret(rng)
	_build_entrance(surface, rng)


## A wall run: solid collision plus a lumpy skin of boulders from a to b.
func _wall_run(a: Vector3, b: Vector3, rng: RandomNumberGenerator, height: float = SIZE.y, doorway: bool = false) -> void:
	var mid := (a + b) * 0.5
	var along := b - a
	var along_x := absf(along.x) > absf(along.z)
	var size := Vector3(along.length(), height, 0.6) if along_x else Vector3(0.6, height, along.length())
	var body := wall_body(self, size, mid + Vector3(0, height / 2.0, 0))
	var backing := Art.box(size, ROCK_A.darkened(0.25))
	body.add_child(backing)
	# The collision is thicker than the slab so the camera stays out of the lumpy boulder skin.
	var skin: BoxShape3D = (body.get_child(0) as CollisionShape3D).shape
	skin.size = Vector3(size.x, size.y, 1.5) if along_x else Vector3(1.5, size.y, size.z)
	var n := int(along.length() / 1.5) + 1
	for i in n:
		var p := a.lerp(b, (float(i) + 0.5) / float(n))
		if doorway and absf(p.x) < 2.0:
			continue   # keep the way out clear
		for layer in 3:
			var rock := boulder(rng.randf_range(0.65, 1.05), ROCK_A.lerp(ROCK_B, rng.randf()), rng)
			rock.position = p + Vector3(rng.randf_range(-0.2, 0.2), 0.35 + layer * (height / 3.1) + rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
			add_child(rock)


func _build_shell(rng: RandomNumberGenerator) -> void:
	var hx := SIZE.x / 2.0
	var hz := SIZE.z / 2.0
	# Floor in tiles (keeps each mesh within the renderer's per-object light limit).
	for ix in 8:
		for iz in 6:
			var tile := Buildings.solid_box(self, Vector3(4.5, 0.4, 4.0), Vector3(-19.75 + ix * 4.5, -0.2, -10.0 + iz * 4.0), FLOOR_COL.darkened(rng.randf() * 0.14))
			tile.name = "Floor_%d_%d" % [ix, iz]
	_wall_run(Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), rng)
	_wall_run(Vector3(-hx, 0, hz), Vector3(hx, 0, hz), rng, SIZE.y, true)
	_wall_run(Vector3(hx, 0, -hz), Vector3(hx, 0, hz), rng)
	_wall_run(Vector3(-hx, 0, -hz), Vector3(-hx, 0, -3.0), rng)   # left wall, with a gap...
	_wall_run(Vector3(-hx, 0, 3.0), Vector3(-hx, 0, hz), rng)     # ...for the cracked wall
	_wall_run(Vector3(-18.5, 0, -3.3), Vector3(-hx, 0, -3.3), rng)   # secret pocket
	_wall_run(Vector3(-18.5, 0, 3.3), Vector3(-hx, 0, 3.3), rng)
	_wall_run(Vector3(-18.5, 0, -3.3), Vector3(-18.5, 0, 3.3), rng)
	# Ceiling (collision keeps the camera underground) plus stalactites.
	var roof := wall_body(self, Vector3(33.0, 0.5, SIZE.z + 1.0), Vector3(-3.5, SIZE.y + 0.25, 0))
	roof.add_child(Art.box(Vector3(33.0, 0.5, SIZE.z + 1.0), ROCK_A.darkened(0.35)))
	for k in 34:
		var h := rng.randf_range(0.4, 1.3)
		var st := Art.cylinder(0.22 * h, 0.0, h, ROCK_B.darkened(0.15), 5)
		var p := Vector3(rng.randf_range(-hx + 1.0, hx - 1.0), SIZE.y - h / 2.0, rng.randf_range(-hz + 1.0, hz - 1.0))
		if absf(p.x) < 3.0 and p.z > 3.0:
			continue   # keep the entrance view clear
		st.position = p
		add_child(st)
	# Loose pebbles on the floor.
	for k in 60:
		var peb := boulder(rng.randf_range(0.07, 0.16), ROCK_B.lightened(rng.randf() * 0.12), rng)
		peb.position = Vector3(rng.randf_range(-hx + 1.0, hx - 1.0), 0.05, rng.randf_range(-hz + 1.0, hz - 1.0))
		add_child(peb)


func _light(pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	add_child(l)
	return l


func _build_props(rng: RandomNumberGenerator) -> void:
	# Crystal clusters along the walls; the three big ones carry real lights.
	var spots := [Vector3(-10.4, 0, -9.4), Vector3(10.4, 0, -9.2), Vector3(10.6, 0, 8.8), Vector3(1.6, 0, -9.9),
		Vector3(-10.8, 0, 8.6), Vector3(10.9, 0, 2.0), Vector3(-10.9, 0, -4.4)]
	for i in spots.size():
		var col: Color = CRYSTAL_COLORS[i % CRYSTAL_COLORS.size()]
		var cl := crystal_cluster(col, 5, 1.25 if i < 3 else 0.7, rng)
		cl.position = spots[i]
		add_child(cl)
		if i < 3:
			_light(spots[i] + Vector3(-signf(spots[i].x) * 0.9, 1.4, -signf(spots[i].z) * 0.9), col, 2.2, 9.0)
	# Ceiling-hung crystals for depth.
	for k in 7:
		var cl := crystal_cluster(CRYSTAL_COLORS[k % 3], 3, 0.55, rng)
		cl.position = Vector3(rng.randf_range(-9, 9), SIZE.y, rng.randf_range(-9, 2))
		cl.rotation.x = PI
		add_child(cl)
	# Timber supports with warm lanterns.
	for x in [-5.0, 5.0]:
		for sx in [-2.2, 2.2]:
			var post := Buildings.solid_box(self, Vector3(0.35, 4.2, 0.35), Vector3(x + sx, 2.1, -1.0), Art.WOOD.darkened(0.25))
			post.name = "Post_%d_%d" % [int(x), int(sx * 10)]
		var beam := Art.box(Vector3(5.2, 0.35, 0.45), Art.WOOD.darkened(0.15))
		beam.position = Vector3(x, 4.3, -1.0)
		add_child(beam)
		var lamp := Art.box(Vector3(0.3, 0.4, 0.3), Color(1.0, 0.8, 0.35))
		lamp.material_override = Art.mat(Color(1.0, 0.78, 0.35), true)
		lamp.position = Vector3(x, 3.8, -1.0)
		add_child(lamp)
		_light(Vector3(x, 3.4, -0.6), Color(1.0, 0.7, 0.38), 2.4, 10.0)
	_light(Vector3(0, 3.6, 8.2), Color(1.0, 0.82, 0.55), 1.8, 9.0)
	# Rails and Gran's abandoned mine cart.
	for z in range(-7, 9):
		var tie := Art.box(Vector3(1.5, 0.07, 0.25), Art.WOOD.darkened(0.35))
		tie.position = Vector3(0, 0.04, float(z))
		add_child(tie)
	for rx in [-0.55, 0.55]:
		var rail := Art.box(Vector3(0.09, 0.09, 16.0), Color(0.5, 0.45, 0.42))
		rail.position = Vector3(rx, 0.12, 0.5)
		add_child(rail)
	var cart := _make_cart(rng)
	cart.position = Vector3(0, 0.0, -5.2)
	add_child(cart)
	wall_body(self, Vector3(1.3, 1.1, 1.7), Vector3(0, 0.55, -5.2))
	var sign := Art.label("GRAN'S OLD MINE\nshe was digging for rocket fuel", 48, Color(1.0, 0.9, 0.65))
	sign.position = Vector3(0, 3.4, -9.6)
	add_child(sign)
	# Floating dust motes.
	var motes := FX.emitter(self, Color(0.75, 0.8, 1.0, 0.7), 90, 6.0, 0.03, Vector3(11, 2.5, 10), Vector3(0, -0.02, 0), true, "sphere")
	motes.position = Vector3(0, 2.6, 0)


func _make_cart(rng: RandomNumberGenerator) -> Node3D:
	var cart := Node3D.new()
	var tub := Art.box(Vector3(1.2, 0.65, 1.6), Color(0.45, 0.3, 0.22))
	tub.position.y = 0.65
	cart.add_child(tub)
	var rim := Art.box(Vector3(1.32, 0.1, 1.72), Color(0.42, 0.43, 0.48))
	rim.position.y = 1.0
	cart.add_child(rim)
	for sx in [-0.62, 0.62]:
		for sz in [-0.55, 0.55]:
			var wheel := Art.cylinder(0.24, 0.24, 0.12, Color(0.25, 0.25, 0.28), 10)
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(sx, 0.3, sz)
			cart.add_child(wheel)
	for k in 7:
		var ore := boulder(0.22, MineRock.STONE_COLOR if k % 3 else MineRock.ORE_COLOR, rng)
		ore.position = Vector3(rng.randf_range(-0.35, 0.35), 1.08 + rng.randf() * 0.12, rng.randf_range(-0.5, 0.5))
		cart.add_child(ore)
	return cart


func _build_ore() -> void:
	for i in ORE_SPOTS.size():
		var r := MineRock.new()
		r.name = "MineOre_%02d" % i
		r.kind = ORE_SPOTS[i][0]
		r.position = ORE_SPOTS[i][1]
		add_child(r)


func _build_secret(rng: RandomNumberGenerator) -> void:
	var wall := CrackedWall.new()
	wall.name = "CrackedWall"
	wall.position = Vector3(-SIZE.x / 2.0, 0, 0)
	add_child(wall)
	var tin := GranTin.new()
	tin.name = "GranTin"
	tin.position = Vector3(-17.2, 0, 0.1)
	tin.interact_radius = 1.6
	add_child(tin)
	for p in [Vector3(-17.7, 0, -2.4), Vector3(-17.6, 0, 2.4), Vector3(-13.6, 0, -2.6)]:
		var cl := crystal_cluster(Color(1.0, 0.75, 0.3), 5, 0.9, rng)
		cl.position = p
		add_child(cl)
	_light(Vector3(-15.8, 2.8, 0), Color(1.0, 0.72, 0.3), 2.4, 8.0)
	# Exit door (back to daylight).
	var out := ENTRANCE + Vector3(0, 0.2, 3.6)
	var exit_door := Door.new()
	exit_door.name = "ExitDoor"
	exit_door.position = Vector3(0, 0, SIZE.z / 2.0 - 1.3)
	exit_door.destination = out
	exit_door.label = "Climb out of the mine"
	exit_door.interact_radius = 1.6
	add_child(exit_door)
	for sx in [-1.0, 1.0]:
		var post := Art.box(Vector3(0.25, 2.6, 0.25), Art.WOOD)
		post.position = Vector3(sx, 1.3, SIZE.z / 2.0 - 0.45)
		add_child(post)
	var day := Art.box(Vector3(1.8, 2.4, 0.1), Color(0.75, 0.9, 1.0))
	day.material_override = Art.mat(Color(0.75, 0.9, 1.0), true)
	day.position = Vector3(0, 1.2, SIZE.z / 2.0 - 0.34)
	add_child(day)


## Rocky mound with a timber-framed mouth, west of the northern rocks.
func _build_entrance(surface: Node3D, rng: RandomNumberGenerator) -> void:
	var e := Node3D.new()
	e.name = "MineEntrance"
	e.position = Vector3(ENTRANCE.x, Terrain.height_at(ENTRANCE.x, ENTRANCE.z), ENTRANCE.z)
	surface.add_child(e)
	var stone := Color(0.48, 0.47, 0.52)
	for p in [[Vector3(-2.4, 0.8, -0.8), 1.7], [Vector3(2.4, 0.8, -0.8), 1.7], [Vector3(0, 1.8, -2.4), 2.6],
			[Vector3(-1.6, 2.7, -1.2), 1.4], [Vector3(1.7, 2.6, -1.3), 1.5], [Vector3(0.1, 3.5, -1.5), 1.2],
			[Vector3(-3.4, 0.4, 0.4), 0.8], [Vector3(3.5, 0.4, 0.3), 0.9]]:
		var rock := boulder(p[1], stone.darkened(rng.randf() * 0.18), rng)
		rock.position = p[0]
		e.add_child(rock)
	var hole := Art.box(Vector3(2.0, 2.5, 0.2), Color(0.04, 0.03, 0.06))
	hole.position = Vector3(0, 1.25, 0.0)
	e.add_child(hole)
	for sx in [-1.15, 1.15]:
		var post := Art.box(Vector3(0.3, 2.8, 0.35), Art.WOOD.darkened(0.15))
		post.position = Vector3(sx, 1.4, 0.35)
		e.add_child(post)
	var lintel := Art.box(Vector3(3.0, 0.35, 0.45), Art.WOOD)
	lintel.position = Vector3(0, 2.85, 0.35)
	e.add_child(lintel)
	var cl := crystal_cluster(CRYSTAL_COLORS[0], 4, 0.65, rng)
	cl.position = Vector3(1.9, 0, 1.0)
	e.add_child(cl)
	wall_body(e, Vector3(7.0, 4.0, 3.4), Vector3(0, 2.0, -1.8))
	var sign := Art.label("GRAN'S OLD MINE\nmind the geodes", 52, Color(1.0, 0.9, 0.65))
	sign.position = Vector3(0, 4.9, 0.6)
	e.add_child(sign)
	Buildings.add_front_door(e, Vector3(0, 0, 0.8), entry_point, "Enter Gran's Old Mine", false)


func _process(delta: float) -> void:
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null or not inside(pl.global_position):
		return
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = drip_gap(randf())
		var at := pl.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 3))
		at.y = 0.1
		Sfx.play_on(self, "drip", randf_range(0.8, 1.25))
		FX.burst(self, at, Color(0.6, 0.8, 1.0, 0.8), 6, 0.05, 1.4, -8.0, "sphere", 60.0)
