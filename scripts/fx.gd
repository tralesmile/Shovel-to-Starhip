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
