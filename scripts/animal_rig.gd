class_name AnimalRig
extends Node3D
## Code-built, jointed farm animals with secondary motion: necks bob, tails wag, ears
## flop on landing, eyes blink, goats bend their knees and chickens thrust their heads.
## The owner moves the whole thing about; `animate()` only poses it. Faces +Z, feet at y=0.

const FUR := preload("res://scripts/shaders/fur.gdshader")

const CHICKEN_COATS := [
	[Color(0.98, 0.96, 0.9), Color(0.9, 0.82, 0.68), 0.0],      # white
	[Color(0.8, 0.45, 0.18), Color(0.55, 0.27, 0.1), 0.38],     # ginger
	[Color(0.94, 0.9, 0.82), Color(0.3, 0.24, 0.22), 0.34],     # speckled
	[Color(0.25, 0.22, 0.27), Color(0.45, 0.4, 0.5), 0.3],      # midnight
]

var species := "chicken"
var legs: Array[Node3D] = []     ## hip pivots (front pair first for the goat)
var knees: Array[Node3D] = []
var wings: Array[Node3D] = []    ## shoulder pivots with a "side" meta
var ears: Array[Node3D] = []
var body: Node3D                 ## breathes and bobs
var neck: Node3D
var head: Node3D
var tail: Node3D
var jaw: Node3D
var eyes: Array[Node3D] = []
var bags: Node3D                 ## goat saddle bags (hidden until crafted)

var _t := 0.0
var _stride := 0.0
var _blink := 2.0
var _tail_s := Vector2.ZERO      ## spring: x = angle, y = velocity
var _ear_s := Vector2.ZERO
var _last_y := 0.0
var _vy := 0.0
var _neck_home := Vector3.ZERO

static var _mats := {}
static var _meshes := {}


# ---------------------------------------------------------------- pure helpers (tested)

## Damped spring step: returns Vector2(value, velocity).
static func spring(state: Vector2, target: float, stiffness: float, damping: float, delta: float) -> Vector2:
	var dt := minf(delta, 1.0 / 30.0)
	var v := state.y + (target - state.x) * stiffness * dt
	v *= maxf(0.0, 1.0 - damping * dt)
	return Vector2(state.x + v * dt, v)


## The chicken strut: the head holds still while the body walks under it, then darts forward.
## `phase` is in strides; returns a forward offset in -0.5..0.5.
static func head_thrust(phase: float) -> float:
	var f := fposmod(phase, 1.0)
	if f < 0.75:
		return 0.5 - f / 0.75          # drifting back relative to the body
	return -0.5 + (f - 0.75) / 0.25    # quick dart forward


## Knee bend for a hip swing angle: a leg only folds while it is coming forward.
static func knee_bend(hip_angle: float, hip_speed: float) -> float:
	return clampf(-hip_speed, 0.0, 1.0) * 1.1 + maxf(0.0, hip_angle) * 0.25


## Leg phase offsets (turns): goat walk is diagonal pairs, gallop is front pair then back pair.
static func leg_phase(index: int, count: int, gallop: bool) -> float:
	if count == 2:
		return 0.0 if index == 0 else 0.5
	if gallop:
		return [0.0, 0.1, 0.5, 0.6][index]
	return [0.0, 0.5, 0.5, 0.0][index]


# ---------------------------------------------------------------- building blocks

static func coat(base: Color, patch: Color = Color.WHITE, amount: float = 0.0, scale_: float = 4.0,
		seed_: float = 0.0, outline: bool = true) -> ShaderMaterial:
	var key := "%s_%s_%s_%s_%s_%s" % [base.to_html(), patch.to_html(), amount, scale_, seed_, outline]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = FUR
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("patch_color", patch)
	m.set_shader_parameter("patch_amount", amount)
	m.set_shader_parameter("patch_scale", scale_)
	m.set_shader_parameter("patch_seed", seed_)
	if outline and Toon.outlines:
		m.next_pass = Toon.outline_material(0.0)
	_mats[key] = m
	return m


static func _ball_mesh() -> SphereMesh:
	if not _meshes.has("ball"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 20
		s.rings = 11
		_meshes["ball"] = s
	return _meshes["ball"]


static func _cone_mesh(top: float, bottom: float, h: float) -> CylinderMesh:
	var key := "cone_%.3f_%.3f_%.3f" % [top, bottom, h]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = h
		c.radial_segments = 10
		c.rings = 1
		_meshes[key] = c
	return _meshes[key]


## An ellipsoid with semi-axes `r`.
func _ball(parent: Node3D, pos: Vector3, r: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _ball_mesh()
	mi.material_override = mat
	mi.transform = Transform3D(Basis.from_euler(rot) * Basis.from_scale(r), pos)
	parent.add_child(mi)
	return mi


## A tapered rod from `a` to `b`.
func _rod(parent: Node3D, a: Vector3, b: Vector3, ra: float, rb: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var d := b - a
	var length := maxf(d.length(), 0.001)
	mi.mesh = _cone_mesh(rb, ra, length)
	mi.material_override = mat
	var y := d / length
	var side := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK
	var z := side.cross(y).normalized()
	var x := y.cross(z).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _eye(parent: Node3D, pos: Vector3, size: float, iris: Color, bar_pupil: bool) -> void:
	var e := _pivot(parent, pos)
	var out := signf(pos.x)
	e.rotation.y = out * 0.65
	_ball(e, Vector3.ZERO, Vector3(size, size * 1.1, size * 0.7), coat(iris, Color.WHITE, 0.0, 1.0, 0.0, false))
	var dark := coat(Color(0.07, 0.05, 0.05), Color.WHITE, 0.0, 1.0, 0.0, false)
	var pr := Vector3(size * 0.72, size * 0.26, size * 0.3) if bar_pupil else Vector3(size * 0.62, size * 0.68, size * 0.3)
	_ball(e, Vector3(0, 0, size * 0.55), pr, dark)
	var glint := Toon.color(Color(1, 1, 1), true, false)
	_ball(e, Vector3(size * 0.28, size * 0.34, size * 0.8), Vector3.ONE * size * 0.2, glint)
	eyes.append(e)


static func make(kind_name: String, variant: int = 0) -> AnimalRig:
	var r := AnimalRig.new()
	r.species = kind_name
	r.body = r._pivot(r, Vector3.ZERO)
	match kind_name:
		"goat":
			r._build_goat()
		"rabbit":
			r._build_rabbit(variant)
		_:
			r._build_chicken(variant)
	if r.neck != null:
		r._neck_home = r.neck.position
	return r


func _build_chicken(variant: int) -> void:
	var c: Array = CHICKEN_COATS[posmod(variant, CHICKEN_COATS.size())]
	var feathers := coat(c[0], c[1], c[2], 14.0, float(variant) * 3.7)
	var soft := coat(c[0], c[1], c[2], 14.0, float(variant) * 3.7, false)
	var dark := coat((c[0] as Color).darkened(0.18), c[1], c[2], 14.0, 9.0, false)
	var red := coat(Color(0.9, 0.13, 0.1), Color.WHITE, 0.0, 1.0, 0.0, false)
	var orange := coat(Color(1.0, 0.64, 0.1), Color.WHITE, 0.0, 1.0, 0.0, false)
	# Plump teardrop body: belly, a proud chest and a rising rump.
	_ball(body, Vector3(0, 0.33, -0.02), Vector3(0.19, 0.17, 0.23), feathers)
	_ball(body, Vector3(0, 0.36, 0.08), Vector3(0.155, 0.16, 0.16), soft)
	_ball(body, Vector3(0, 0.39, -0.14), Vector3(0.13, 0.12, 0.15), soft, Vector3(0.5, 0, 0))
	tail = _pivot(body, Vector3(0, 0.43, -0.2))
	for i in 5:
		var a := (i - 2) * 0.34
		var tip := Vector3(sin(a) * 0.14, 0.2 - absf(i - 2) * 0.03, -0.14)
		_ball(tail, tip * 0.5, Vector3(0.04, 0.13 - absf(i - 2) * 0.012, 0.022), dark if i % 2 == 0 else soft,
			Vector3(-0.65, 0, -a * 0.8))
	neck = _pivot(body, Vector3(0, 0.43, 0.13))
	_rod(neck, Vector3(0, -0.05, -0.03), Vector3(0, 0.16, 0.05), 0.1, 0.07, soft)
	head = _pivot(neck, Vector3(0, 0.19, 0.06))
	_ball(head, Vector3.ZERO, Vector3(0.095, 0.095, 0.1), feathers)
	for i in 3:
		_ball(head, Vector3(0, 0.095 + (0.018 if i == 1 else 0.0), 0.045 - i * 0.045), Vector3(0.022, 0.042 - i * 0.004, 0.028), red)
	_rod(head, Vector3(0, -0.005, 0.08), Vector3(0, -0.02, 0.17), 0.038, 0.002, orange)
	jaw = _pivot(head, Vector3(0, -0.03, 0.075))
	_rod(jaw, Vector3.ZERO, Vector3(0, -0.012, 0.062), 0.022, 0.002, orange)
	_ball(head, Vector3(0, -0.085, 0.07), Vector3(0.022, 0.042, 0.018), red)   # wattle
	for sx in [-1.0, 1.0]:
		_eye(head, Vector3(sx * 0.068, 0.022, 0.058), 0.026, Color(1.0, 0.85, 0.35), false)
		var w := _pivot(body, Vector3(sx * 0.165, 0.4, 0.04))
		w.set_meta("side", sx)
		_ball(w, Vector3(sx * 0.018, -0.05, -0.07), Vector3(0.035, 0.095, 0.15), feathers, Vector3(-0.2, 0, 0))
		for k in 3:
			_ball(w, Vector3(sx * 0.022, -0.05 - k * 0.03, -0.19 + k * 0.025), Vector3(0.018, 0.028, 0.085), dark, Vector3(-0.25 - k * 0.12, 0, 0))
		wings.append(w)
		var hip := _pivot(body, Vector3(sx * 0.075, 0.21, 0.0))
		_ball(hip, Vector3(0, -0.01, 0), Vector3(0.048, 0.055, 0.052), soft)
		_rod(hip, Vector3(0, -0.03, 0), Vector3(0, -0.195, 0.0), 0.018, 0.015, orange)
		for toe in [-0.55, 0.0, 0.55]:
			_rod(hip, Vector3(0, -0.195, 0), Vector3(sin(toe) * 0.075, -0.205, cos(toe) * 0.075), 0.015, 0.006, orange)
		_rod(hip, Vector3(0, -0.195, 0), Vector3(0, -0.205, -0.045), 0.013, 0.005, orange)
		legs.append(hip)


func _build_goat() -> void:
	var white := Color(0.95, 0.91, 0.83)
	var brown := Color(0.5, 0.31, 0.18)
	var hide := coat(white, brown, 0.4, 3.3, 11.0)
	var soft := coat(white, brown, 0.4, 3.3, 11.0, false)
	var plain := coat(white)
	var horn := coat(Color(0.66, 0.55, 0.4), Color(0.45, 0.36, 0.26), 0.45, 38.0, 2.0)
	var hoof := coat(Color(0.2, 0.15, 0.12), Color.WHITE, 0.0, 1.0, 0.0, false)
	var pink := coat(Color(0.93, 0.62, 0.6), Color.WHITE, 0.0, 1.0, 0.0, false)
	# Barrel, shoulders and haunches.
	_ball(body, Vector3(0, 0.72, -0.02), Vector3(0.27, 0.25, 0.43), hide)
	_ball(body, Vector3(0, 0.75, 0.22), Vector3(0.24, 0.25, 0.23), soft)
	_ball(body, Vector3(0, 0.76, -0.27), Vector3(0.25, 0.24, 0.23), soft)
	neck = _pivot(body, Vector3(0, 0.84, 0.34))
	_rod(neck, Vector3(0, -0.1, -0.06), Vector3(0, 0.24, 0.14), 0.16, 0.095, plain)
	head = _pivot(neck, Vector3(0, 0.29, 0.17))
	_ball(head, Vector3(0, 0.02, 0.02), Vector3(0.135, 0.14, 0.16), plain)
	_ball(head, Vector3(0, -0.04, 0.17), Vector3(0.092, 0.082, 0.135), plain, Vector3(0.2, 0, 0))
	_ball(head, Vector3(0, -0.045, 0.287), Vector3(0.062, 0.045, 0.03), pink)
	for sx in [-1.0, 1.0]:
		_ball(head, Vector3(sx * 0.028, -0.035, 0.315), Vector3(0.012, 0.016, 0.008), hoof)   # nostrils
		_eye(head, Vector3(sx * 0.102, 0.05, 0.12), 0.037, Color(0.98, 0.76, 0.2), true)
		# Curved horns in four tapering segments, sweeping up and back.
		var at := Vector3(sx * 0.06, 0.12, 0.02)
		var angle := 0.15
		for k in 4:
			var step := Vector3(sx * 0.025, cos(angle) * 0.1, -sin(angle) * 0.1)
			_rod(head, at, at + step, 0.042 - k * 0.009, 0.034 - k * 0.0095, horn)
			at += step
			angle += 0.5
		var ear := _pivot(head, Vector3(sx * 0.125, 0.055, -0.02))
		ear.set_meta("side", sx)
		_ball(ear, Vector3(sx * 0.11, -0.025, 0), Vector3(0.12, 0.028, 0.058), soft, Vector3(0, 0, -sx * 0.25))
		_ball(ear, Vector3(sx * 0.115, -0.018, 0.012), Vector3(0.08, 0.02, 0.038), pink, Vector3(0, 0, -sx * 0.25))
		ears.append(ear)
	jaw = _pivot(head, Vector3(0, -0.09, 0.11))
	_ball(jaw, Vector3(0, -0.012, 0.07), Vector3(0.062, 0.03, 0.1), plain)
	_rod(jaw, Vector3(0, -0.02, 0.06), Vector3(0, -0.2, 0.03), 0.048, 0.003, coat(white.darkened(0.12)))   # beard
	tail = _pivot(body, Vector3(0, 0.88, -0.46))
	_ball(tail, Vector3(0, 0.07, -0.045), Vector3(0.055, 0.12, 0.05), soft, Vector3(-0.6, 0, 0))
	for p in [Vector2(-0.15, 0.27), Vector2(0.15, 0.27), Vector2(-0.16, -0.3), Vector2(0.16, -0.3)]:
		var hip := _pivot(body, Vector3(p.x, 0.62, p.y))
		_rod(hip, Vector3(0, 0.07, 0), Vector3(0, -0.29, 0.0), 0.095 if p.y < 0.0 else 0.08, 0.048, soft)
		var knee := _pivot(hip, Vector3(0, -0.29, 0))
		_ball(knee, Vector3.ZERO, Vector3.ONE * 0.05, plain)
		_rod(knee, Vector3.ZERO, Vector3(0, -0.27, 0), 0.046, 0.036, plain)
		_rod(knee, Vector3(0, -0.245, 0.008), Vector3(0, -0.33, 0.018), 0.045, 0.062, hoof)
		legs.append(hip)
		knees.append(knee)
	# Saddle bags: two stitched hay-leather satchels with brass buckles.
	bags = _pivot(body, Vector3(0, 0.74, -0.24))
	var leather := coat(Color(0.52, 0.3, 0.13), Color(0.38, 0.2, 0.08), 0.35, 18.0, 5.0)
	var brass := Toon.color(Color(1.0, 0.78, 0.25), false, false)
	for sx in [-1.0, 1.0]:
		_ball(bags, Vector3(sx * 0.33, -0.04, -0.03), Vector3(0.11, 0.18, 0.2), leather)
		_ball(bags, Vector3(sx * 0.355, 0.07, -0.03), Vector3(0.105, 0.075, 0.21), leather)
		_ball(bags, Vector3(sx * 0.462, 0.02, -0.03), Vector3(0.018, 0.03, 0.03), brass)
		_rod(bags, Vector3(sx * 0.25, 0.1, 0), Vector3(0, 0.27, 0), 0.03, 0.03, leather)
	bags.visible = false


func _build_rabbit(variant: int) -> void:
	var shades := [Color(0.76, 0.64, 0.5), Color(0.62, 0.55, 0.5), Color(0.86, 0.78, 0.66)]
	var base: Color = shades[posmod(variant, shades.size())]
	var fur := coat(base, base.lightened(0.35), 0.3, 12.0, float(variant))
	var soft := coat(base, base.lightened(0.35), 0.3, 12.0, float(variant), false)
	var white := coat(Color(1, 0.98, 0.95))
	var pink := coat(Color(0.98, 0.62, 0.66), Color.WHITE, 0.0, 1.0, 0.0, false)
	_ball(body, Vector3(0, 0.2, -0.03), Vector3(0.15, 0.15, 0.21), fur)
	_ball(body, Vector3(0, 0.23, 0.09), Vector3(0.11, 0.12, 0.11), soft)
	tail = _pivot(body, Vector3(0, 0.24, -0.23))
	_ball(tail, Vector3(0, 0.02, -0.02), Vector3.ONE * 0.075, white)
	neck = _pivot(body, Vector3(0, 0.29, 0.13))
	head = _pivot(neck, Vector3(0, 0.08, 0.06))
	_ball(head, Vector3.ZERO, Vector3(0.105, 0.1, 0.108), fur)
	_ball(head, Vector3(0, -0.035, 0.085), Vector3(0.062, 0.045, 0.045), white)
	_ball(head, Vector3(0, -0.012, 0.133), Vector3(0.022, 0.017, 0.014), pink)
	for sx in [-1.0, 1.0]:
		_eye(head, Vector3(sx * 0.073, 0.022, 0.07), 0.027, Color(0.16, 0.09, 0.07), false)
		var ear := _pivot(head, Vector3(sx * 0.045, 0.075, -0.015))
		ear.set_meta("side", sx)
		_ball(ear, Vector3(sx * 0.012, 0.13, 0), Vector3(0.036, 0.14, 0.022), fur, Vector3(0, 0, -sx * 0.1))
		_ball(ear, Vector3(sx * 0.012, 0.13, 0.016), Vector3(0.019, 0.105, 0.012), pink, Vector3(0, 0, -sx * 0.1))
		ears.append(ear)
		_ball(body, Vector3(sx * 0.1, 0.14, -0.12), Vector3(0.065, 0.12, 0.13), soft)   # haunch
		var hip := _pivot(body, Vector3(sx * 0.07, 0.14, 0.12))
		_rod(hip, Vector3.ZERO, Vector3(0, -0.11, 0.01), 0.035, 0.028, soft)
		_ball(hip, Vector3(0, -0.115, 0.03), Vector3(0.035, 0.025, 0.052), white)
		legs.append(hip)
		_ball(body, Vector3(sx * 0.11, 0.035, -0.08), Vector3(0.045, 0.033, 0.12), white)   # long hind foot


# ---------------------------------------------------------------- posing

## Pose for this frame. `speed` is ground speed in m/s. State keys (all optional):
## graze (head to the ground), alert (head high), flap (0..1 wing beat), air (legs tucked),
## ram (head lowered, horns first), chew, gallop, happy (fast tail).
func animate(delta: float, speed: float, state: Dictionary = {}) -> void:
	_t += delta
	var moving := speed > 0.15
	var gallop: bool = state.get("gallop", false)
	var air: bool = state.get("air", false)
	var rate := (1.9 if species == "chicken" else 1.25) * clampf(speed, 0.0, 14.0) / (1.0 + speed * 0.09)
	_stride = fposmod(_stride + delta * rate, 1.0) if moving else _stride
	var amp := clampf(0.25 + speed * 0.12, 0.0, 0.85) if moving else 0.0
	var blend := minf(1.0, 14.0 * delta)
	for i in legs.size():
		var ph := (_stride + leg_phase(i, legs.size(), gallop)) * TAU
		var hip := sin(ph) * amp
		if air:
			hip = (-0.7 if i < 2 else 0.8) if legs.size() == 4 else 0.65
		legs[i].rotation.x = lerpf(legs[i].rotation.x, hip, blend)
		if i < knees.size():
			var bend := knee_bend(hip, cos(ph) * (1.0 if moving else 0.0))
			if air:
				bend = 1.3
			knees[i].rotation.x = lerpf(knees[i].rotation.x, bend, blend)

	# Body: breathing at rest, a bob in stride.
	var breath := 1.0 + sin(_t * 2.6) * 0.014
	body.scale = Vector3(breath, 1.0 + (breath - 1.0) * 1.4, 1.0)
	var bob := absf(sin(_stride * TAU * (1.0 if gallop else 2.0))) * (0.06 if gallop else 0.025) if moving and not air else 0.0
	body.position.y = lerpf(body.position.y, bob, blend)

	# Neck and head.
	if neck != null:
		var pitch := 0.0
		var push := 0.0
		if species == "chicken":
			if moving:
				push = head_thrust(_stride * 2.0) * 0.07
			if state.get("graze", false):
				pitch = 0.65 + maxf(0.0, sin(_t * 13.0)) * 0.75     # peck, peck
		else:
			if state.get("graze", false):
				pitch = 1.35 if species == "goat" else 0.45
			elif moving:
				pitch = sin(_stride * TAU * (1.0 if gallop else 2.0)) * 0.12 + (0.2 if gallop else 0.0)
			else:
				pitch = sin(_t * 0.7) * 0.07
		if state.get("alert", false):
			pitch = -0.28
		if state.get("ram", false):
			pitch = 0.95
		neck.rotation.x = lerpf(neck.rotation.x, pitch, minf(1.0, 11.0 * delta))
		neck.position = _neck_home + Vector3(0, 0, push)
		# The head counter-tilts and now and then glances sideways.
		var glance := 0.0 if moving or state.get("graze", false) else sin(_t * 0.53) * sin(_t * 1.31) * 0.7
		head.rotation.y = lerp_angle(head.rotation.y, glance, minf(1.0, 5.0 * delta))
		head.rotation.x = lerpf(head.rotation.x, -neck.rotation.x * (0.35 if not state.get("ram", false) else -0.25), blend)
	if jaw != null:
		var open := 0.0
		if state.get("chew", false):
			open = maxf(0.0, sin(_t * 11.0)) * 0.3
		elif state.get("call", false):
			open = 0.55
		jaw.rotation.x = lerpf(jaw.rotation.x, open, blend)

	# Springs: ears and tail lag behind vertical motion and settle with a wobble.
	var y := global_position.y if is_inside_tree() else position.y
	_vy = lerpf(_vy, (y + body.position.y - _last_y) / maxf(delta, 0.001), 0.5)
	_last_y = y + body.position.y
	_ear_s = spring(_ear_s, clampf(-_vy * 0.22, -0.9, 0.9), 150.0, 9.0, delta)
	_tail_s = spring(_tail_s, clampf(-_vy * 0.18, -0.8, 0.8), 120.0, 7.0, delta)
	for e in ears:
		var side := float(e.get_meta("side", 1.0))
		if species == "goat":
			var twitch := maxf(0.0, sin(_t * 1.7 + side * 2.0) - 0.93) * 5.0
			e.rotation.z = side * (_ear_s.x + twitch + (-0.35 if gallop else 0.0))
			e.rotation.y = side * (0.5 if gallop else 0.0)
		else:
			var lay := -1.15 if moving else (-0.55 if not state.get("alert", false) else 0.05)
			e.rotation.x = lerpf(e.rotation.x, lay + _ear_s.x * 0.6, blend)
	if tail != null:
		var wag_rate := 17.0 if state.get("happy", false) else 3.1
		var wag := sin(_t * wag_rate) * (0.55 if state.get("happy", false) else 0.14)
		tail.rotation = Vector3(_tail_s.x, wag, wag * 0.4 if species == "goat" else 0.0)

	# Wings.
	var flap: float = state.get("flap", 0.0)
	for w in wings:
		var side := float(w.get_meta("side", 1.0))
		var open_a := flap * (1.35 + sin(_t * 34.0) * 0.85)
		w.rotation.z = lerpf(w.rotation.z, side * open_a, minf(1.0, 26.0 * delta))

	# Blink.
	_blink -= delta
	var shut := _blink < 0.12
	if _blink < 0.0:
		_blink = 1.6 + fposmod(_t * 7.31, 2.9)
	for e in eyes:
		e.scale.y = 0.12 if shut else 1.0
