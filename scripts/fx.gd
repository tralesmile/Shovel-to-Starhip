class_name FX
extends RefCounted
## Small particle effects built in code (CPU particles work on every renderer).

static var _mats: Dictionary = {}


static func particle_mat(unshaded: bool = false) -> StandardMaterial3D:
	var key := "u" if unshaded else "s"
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func _mesh(kind: String, size: float, unshaded: bool) -> Mesh:
	var mesh: PrimitiveMesh
	if kind == "box":
		mesh = BoxMesh.new()
		(mesh as BoxMesh).size = Vector3.ONE * size
	else:
		mesh = SphereMesh.new()
		(mesh as SphereMesh).radius = size * 0.5
		(mesh as SphereMesh).height = size
		(mesh as SphereMesh).radial_segments = 6
		(mesh as SphereMesh).rings = 3
	mesh.material = particle_mat(unshaded)
	return mesh


## One-shot burst at a world position; frees itself afterwards.
static func burst(parent: Node, pos: Vector3, color: Color, amount: int = 14, size: float = 0.12,
		speed: float = 3.0, gravity: float = -9.0, kind: String = "box", spread: float = 60.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 1.0
	p.mesh = _mesh(kind, size, false)
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color = color
	var host: Node = parent.get_tree().current_scene
	if host == null:
		host = parent
	host.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)


## Continuous emitter (dust, leaves, fireflies). Caller toggles .emitting.
static func emitter(parent: Node, color: Color, amount: int, lifetime: float, size: float,
		box: Vector3, gravity: Vector3, unshaded: bool = false, kind: String = "box") -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.mesh = _mesh(kind, size, unshaded)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.gravity = gravity
	p.direction = Vector3.UP
	p.spread = 180
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.5
	p.angular_velocity_min = -90
	p.angular_velocity_max = 90
	p.color = color
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.15, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	parent.add_child(p)
	return p


## Hit-stop (pure helper, tested): time scale to use `t` seconds after an impact of `strength` 0..1.
static func hit_stop_scale(t: float, strength: float) -> float:
	var dur := 0.04 + 0.06 * clampf(strength, 0.0, 1.0)
	return 0.05 if t < dur else 1.0


## Freeze the game for a few frames on impact (real-time timer so it always recovers).
static func hit_stop(tree: SceneTree, strength: float = 0.5) -> void:
	if tree == null or DisplayServer.get_name() == "headless":
		return
	var dur := 0.04 + 0.06 * clampf(strength, 0.0, 1.0)
	Engine.time_scale = 0.05
	tree.create_timer(dur, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## Colour grading per time of day (pure, tested): warm punchy sunset, cool muted night.
static func grade_for(day: float, sunset: float, night: float) -> Dictionary:
	var total: float = maxf(day + sunset + night, 0.001)
	var d := day / total
	var s := sunset / total
	var n := night / total
	return {
		"saturation": 1.08 * d + 1.2 * s + 0.82 * n,
		"contrast": 1.04 * d + 1.1 * s + 1.0 * n,
		"brightness": 1.0 * d + 1.0 * s + 1.04 * n,
	}


const COMBO_WINDOW := 1.2   ## seconds between pickups that keep a combo going


## Pickup combo (pure, tested): grabbing items in quick succession raises the blip a semitone each time (cap 8).
static func pickup_combo(combo: int, since_last: float) -> int:
	return mini(combo + 1, 8) if since_last <= COMBO_WINDOW and combo > 0 else 1


static func combo_pitch(combo: int) -> float:
	return pow(2.0, float(maxi(combo - 1, 0)) / 12.0)


const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12


## Coyote time + jump buffering (pure, tested). Returns new timers and whether to jump now.
static func jump_step(on_floor: bool, pressed: bool, coyote: float, buf: float, delta: float) -> Dictionary:
	coyote = COYOTE_TIME if on_floor else maxf(0.0, coyote - delta)
	buf = JUMP_BUFFER if pressed else maxf(0.0, buf - delta)
	if buf > 0.0 and coyote > 0.0:
		return {"jump": true, "coyote": 0.0, "buffer": 0.0}
	return {"jump": false, "coyote": coyote, "buffer": buf}


const STAMINA_MAX := 100.0
const SPRINT_DRAIN := 22.0      ## per second while sprinting
const STAMINA_REGEN := 30.0     ## per second otherwise
const STAMINA_RESUME := 25.0    ## after running dry you must recover this much to sprint again


## Sprint stamina (pure, tested). Running dry forces a breather until STAMINA_RESUME is regained.
static func stamina_step(stamina: float, want_sprint: bool, moving: bool, winded: bool, delta: float) -> Dictionary:
	var sprinting := want_sprint and moving and not winded and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - SPRINT_DRAIN * delta)
		if stamina <= 0.0:
			winded = true
			sprinting = false
	else:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
		if winded and stamina >= STAMINA_RESUME:
			winded = false
	return {"stamina": stamina, "sprinting": sprinting, "winded": winded}


## Encumbrance (pure, tested): speed multiplier for a carried weight over the free capacity. Never below 0.55.
static func carry_speed_mult(weight: float, free: float) -> float:
	if weight <= free:
		return 1.0
	return clampf(1.0 - (weight - free) * 0.006, 0.55, 1.0)


## Pure (tested): should a landing at `fall_speed` kick up dust / thud (a hard ground hit)?
static func is_hard_landing(prev_vy: float, vy: float) -> bool:
	return prev_vy < -3.0 and vy > prev_vy + 2.0


## Landing squash (pure, tested): vertical scale dips with the fall speed, clamped.
static func landing_squash(fall_speed: float) -> float:
	return clampf(1.0 - maxf(0.0, fall_speed - 3.0) * 0.06, 0.7, 1.0)


## Horizontal unit direction a tree should topple: away from the chopper (Valheim-style).
## Falls back to +X when the player stands on the trunk.
static func fall_dir(tree_pos: Vector3, player_pos: Vector3) -> Vector3:
	var d := Vector3(tree_pos.x - player_pos.x, 0.0, tree_pos.z - player_pos.z)
	if d.length() < 0.05:
		return Vector3.RIGHT
	return d.normalized()


## Rotation axis that tips an upright trunk over towards horizontal direction `dir`.
static func fall_axis(dir: Vector3) -> Vector3:
	return Vector3.UP.cross(dir).normalized()


## Screen-shake strength for a landing tree: stronger the closer you stand.
static func fall_shake(dist: float) -> float:
	return clampf(0.7 - dist * 0.06, 0.15, 0.7)
