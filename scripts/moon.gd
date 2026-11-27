class_name Moon
extends Node3D
## The Moon: a small cratered playground far from the valley. Low gravity, a black sky with
## home hanging in it, cheese boulders to mine, footprints that stay, and a flag to plant.

const ORIGIN := Vector3(-700.0, 0.0, -700.0)
const RADIUS := 44.0          ## walkable radius
const MESH_HALF := 90.0
const STEP := 1.5
const GRAVITY_SCALE := 0.26
const PAD := Vector2(0.0, 0.0)          ## the landing spot (local)
const FLAG_AT := Vector3(4.4, 0.0, 3.2)
const MAX_PRINTS := 400

## [x, z, radius, depth]
const CRATERS := [[-17.0, -9.0, 7.5, 1.9], [14.0, -19.0, 9.0, 2.3], [22.0, 8.0, 5.5, 1.4], [-9.0, 18.0, 4.5, 1.1],
	[-30.0, 12.0, 8.0, 1.8], [9.0, 25.0, 6.0, 1.3], [-8.0, -31.0, 6.5, 1.6], [34.0, -8.0, 6.0, 1.5], [-23.0, -25.0, 4.0, 1.0]]
const CHEESE_SPOTS := [Vector2(-17.0, -9.0), Vector2(13.0, -18.0), Vector2(16.0, -21.5), Vector2(22.0, 8.0), Vector2(-9.0, 18.0), Vector2(-14.0, -4.5)]
const ROCK_SPOTS := [Vector2(-11.0, 3.0), Vector2(10.0, -4.0), Vector2(-2.0, -15.0)]

var flag: MoonFlag
var _prints: MultiMeshInstance3D
var _print_n := 0
var _step_acc := 0.0
var _last_pos := Vector3.ZERO
var _foot := 1.0
var _was_floor := true
var earth: MeshInstance3D


static func inside(p: Vector3) -> bool:
	return Vector2(p.x - ORIGIN.x, p.z - ORIGIN.z).length() < MESH_HALF


## Pure (tested): ground height at a local x/z: gentle rolls, bowls with raised rims, a flat
## landing spot, and a ring of hills at the edge of the walkable area.
static func height_local(x: float, z: float) -> float:
	var h := 0.32 * sin(x * 0.19 + 1.3) * cos(z * 0.16) + 0.14 * sin(x * 0.47) * sin(z * 0.53 + 2.0)
	for c in CRATERS:
		var d := Vector2(x - c[0], z - c[1]).length() / float(c[2])
		if d < 1.6:
			var bowl := -float(c[3]) * clampf(1.0 - d * d, 0.0, 1.0)
			var rim := float(c[3]) * 0.42 * exp(-pow((d - 1.05) * 4.2, 2.0))
			h += bowl + rim
	var r := Vector2(x, z).length()
	h *= smoothstep(5.0, 11.0, r)
	h += smoothstep(RADIUS - 2.0, RADIUS + 22.0, r) * (7.0 + 3.0 * sin(atan2(z, x) * 7.0) + 2.0 * sin(atan2(z, x) * 17.0))
	return h


static func ground(x: float, z: float) -> Vector3:
	return ORIGIN + Vector3(x, height_local(x, z), z)


## Dust colour for a point: darker bowl floors, pale rims.
static func tone(h: float) -> Color:
	var base := Color(0.46, 0.46, 0.5)
	if h < 0.0:
		return base.lerp(Color(0.27, 0.27, 0.33), clampf(-h / 1.8, 0.0, 1.0))
	return base.lerp(Color(0.66, 0.65, 0.66), clampf(h / 1.2, 0.0, 1.0))


func _ready() -> void:
	add_to_group("moon")
	name = "Moon"
	position = ORIGIN
	_build_ground()
	_build_bounds()
	_build_rubble()
	_build_earth()
	_build_prints()
	_build_rocks()
	flag = MoonFlag.new()
	flag.name = "MoonFlag"
	flag.position = Vector3(FLAG_AT.x, height_local(FLAG_AT.x, FLAG_AT.z), FLAG_AT.z)
	add_child(flag)
	var sign := Art.label("THE MOON\n(smells faintly of cheese)", 70, Color(0.95, 0.93, 0.8))
	sign.position = Vector3(-6.0, 3.4, -6.5)
	add_child(sign)


func _build_ground() -> void:
	var n := int(MESH_HALF * 2.0 / STEP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for j in n:
		for i in n:
			var x0 := -MESH_HALF + i * STEP
			var z0 := -MESH_HALF + j * STEP
			var a := Vector3(x0, height_local(x0, z0), z0)
			var b := Vector3(x0 + STEP, height_local(x0 + STEP, z0), z0)
			var c := Vector3(x0, height_local(x0, z0 + STEP), z0 + STEP)
			var d := Vector3(x0 + STEP, height_local(x0 + STEP, z0 + STEP), z0 + STEP)
			var tris: Array = [a, c, b, b, c, d] if (i + j) % 2 == 0 else [a, d, b, a, c, d]
			for t in 2:
				var p0: Vector3 = tris[t * 3]
				var p1: Vector3 = tris[t * 3 + 1]
				var p2: Vector3 = tris[t * 3 + 2]
				var nr := (p1 - p0).cross(p2 - p0).normalized()
				if nr.y < 0.0:
					nr = -nr
				# Clockwise from above is the front face.
				var order := [p0, p1, p2] if (p1 - p0).cross(p2 - p0).y < 0.0 else [p0, p2, p1]
				for v in order:
					st.set_normal(nr)
					st.set_color(tone(v.y if Vector2(v.x, v.z).length() < RADIUS else v.y * 0.15))
					st.add_vertex(v)
					faces.append(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/shaders/moon_ground.gdshader")
	mi.material_override = sm
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cp := ConcavePolygonShape3D.new()
	cp.set_faces(faces)
	cp.backface_collision = true
	cs.shape = cp
	body.add_child(cs)
	add_child(body)


## Invisible fence round the playground, tall enough for moon jumps.
func _build_bounds() -> void:
	var seg := 24
	for k in seg:
		var a := TAU * float(k) / float(seg)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(TAU * RADIUS / seg + 1.0, 60.0, 1.0)
		cs.shape = bx
		body.add_child(cs)
		body.position = Vector3(sin(a) * RADIUS, 15.0, cos(a) * RADIUS)
		body.rotation.y = a
		add_child(body)


func _build_rubble() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for k in 130:
		var a := rng.randf() * TAU
		var r := rng.randf_range(8.0, RADIUS + 16.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var big := rng.randf() < 0.1
		var s := rng.randf_range(0.7, 1.5) if big else rng.randf_range(0.1, 0.34)
		var rock := MineCave.boulder(s, Color(0.4, 0.4, 0.45).lerp(Color(0.6, 0.59, 0.6), rng.randf()), rng)
		rock.position = Vector3(x, height_local(x, z) + s * 0.25, z)
		rock.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
		add_child(rock)
		if big and r < RADIUS:
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var sp := SphereShape3D.new()
			sp.radius = s * 0.9
			cs.shape = sp
			body.add_child(cs)
			body.position = rock.position
			add_child(body)


func _build_earth() -> void:
	earth = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 26.0
	sm.height = 52.0
	sm.radial_segments = 48
	sm.rings = 24
	earth.mesh = sm
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/planet.gdshader")
	earth.material_override = m
	earth.position = Vector3(-70.0, 62.0, -230.0)
	earth.rotation = Vector3(0.35, 0.0, 0.2)
	earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(earth)


func _build_prints() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.17, 0.34)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.14, 0.62)
	mat.albedo_texture = _print_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = MAX_PRINTS
	mm.visible_instance_count = 0
	_prints = MultiMeshInstance3D.new()
	_prints.multimesh = mm
	_prints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prints.custom_aabb = AABB(Vector3(-RADIUS, -5, -RADIUS), Vector3(RADIUS * 2, 30, RADIUS * 2))
	add_child(_prints)


## A boot sole: rounded oval with tread bars.
static func _print_texture() -> ImageTexture:
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 32:
			var u := (x - 15.5) / 15.0
			var v := (y - 31.5) / 31.0
			var inside_sole := u * u + pow(v, 4.0) < 0.95
			var tread := 1.0 if (y % 10) < 6 else 0.35
			img.set_pixel(x, y, Color(1, 1, 1, tread if inside_sole else 0.0))
	return ImageTexture.create_from_image(img)


## Stamp one boot print (local position, facing yaw). Oldest prints are reused.
func stamp(at: Vector3, yaw: float) -> void:
	var mm := _prints.multimesh
	var y := height_local(at.x, at.z)
	var nx := height_local(at.x - 0.3, at.z) - height_local(at.x + 0.3, at.z)
	var nz := height_local(at.x, at.z - 0.3) - height_local(at.x, at.z + 0.3)
	var up := Vector3(nx, 0.6, nz).normalized()
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var right := up.cross(fwd).normalized()
	var basis := Basis(right, up, right.cross(up).normalized())
	mm.set_instance_transform(_print_n % MAX_PRINTS, Transform3D(basis, Vector3(at.x, y + 0.035, at.z)))
	_print_n += 1
	mm.visible_instance_count = mini(_print_n, MAX_PRINTS)


func print_count() -> int:
	return mini(_print_n, MAX_PRINTS)


func _build_rocks() -> void:
	var i := 0
	for spec in [["cheese", CHEESE_SPOTS], ["plain", ROCK_SPOTS]]:
		for at in spec[1]:
			var rock := MineRock.new()
			rock.name = "MoonRock_%d" % i
			rock.kind = spec[0]
			rock.position = Vector3(at.x, height_local(at.x, at.y) - 0.12, at.y)
			add_child(rock)
			i += 1


## Footprints, and slow puffs of dust on every landing.
func track(player: CharacterBody3D) -> void:   # untyped Player: it needs the Game autoload
	var p := player.global_position - ORIGIN
	if not inside(player.global_position):
		return
	var on_floor := player.is_on_floor()
	var moved := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	if on_floor and moved < 2.0:
		_step_acc += moved
		if _step_acc > 0.62:
			_step_acc = 0.0
			_foot = -_foot
			var yaw: float = _facing(player)
			stamp(p + Vector3(cos(yaw), 0, -sin(yaw)) * 0.16 * _foot, yaw)
			if Vector2(player.velocity.x, player.velocity.z).length() > 6.0:
				_puff(player.global_position, 4)
	if on_floor and not _was_floor:
		_puff(player.global_position, 18)
		var yaw2: float = _facing(player)
		for s in [-1.0, 1.0]:
			stamp(p + Vector3(cos(yaw2), 0, -sin(yaw2)) * 0.19 * s, yaw2)
	elif _was_floor and not on_floor and player.velocity.y > 2.0:
		_puff(player.global_position, 10)
	_was_floor = on_floor


static func _facing(body: CharacterBody3D) -> float:
	var m = body.get("_model")
	return (m as Node3D).rotation.y if m != null else atan2(body.velocity.x, body.velocity.z)


func _puff(at: Vector3, n: int) -> void:
	FX.burst(self, at + Vector3(0, 0.08, 0), Color(0.66, 0.66, 0.7), n, 0.13, 2.0, -1.7, "sphere", 85.0)


## Hard sunlight, deep shadows, no air to scatter it.
static func apply_light(env: Environment, sun: DirectionalLight3D) -> void:
	sun.global_transform = Transform3D(Basis.looking_at(-Vector3(0.62, 0.55, 0.56).normalized(), Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.15
	env.ambient_light_color = Color(0.4, 0.48, 0.78)
	env.ambient_light_energy = 0.34
	env.fog_density = 0.0
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.1
	env.adjustment_brightness = 1.0
