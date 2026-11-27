class_name RockShard
extends RigidBody3D
## A wedge knocked off a boulder: real physics, clacks when it lands, then crumbles away.
## It never blocks or pushes the player.

const LIFE := 7.0
const MAX_LIVE := 48

var _age := 0.0
var _vis: Node3D
var _clacked := false
var _prev_vy := 0.0


## Launches `src` (a wedge node whose meshes are in rock space) as a shard under `host`.
## `xf` is the rock's global transform and `centroid` the wedge's middle in rock space.
static func fling(host: Node, src: MeshInstance3D, xf: Transform3D, centroid: Vector3, points: PackedVector3Array, mat: Material, vel: Vector3) -> RockShard:
	if host == null or not host.is_inside_tree() or host.get_tree().get_nodes_in_group("rock_shard").size() >= MAX_LIVE:
		return null
	var s := RockShard.new()
	var hull := PackedVector3Array()
	var step := maxi(1, points.size() / 36)
	for i in range(0, points.size(), step):
		hull.append((points[i] - centroid) * 0.92)
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var cs := CollisionShape3D.new()
	cs.shape = shape
	s.add_child(cs)
	s._vis = Node3D.new()
	s.add_child(s._vis)
	var copy := src.duplicate() as MeshInstance3D
	copy.visible = true
	copy.material_override = mat
	copy.position = -centroid
	s._vis.add_child(copy)
	s.collision_layer = 0
	s.collision_mask = 1
	s.mass = 1.4
	var phys := PhysicsMaterial.new()
	phys.bounce = 0.2
	phys.friction = 0.9
	s.physics_material_override = phys
	s.angular_damp = 1.4
	host.add_child(s)
	s.global_transform = Transform3D(xf.basis.orthonormalized(), xf * centroid)
	# Speed is set directly: an impulse before physics knows the mass launches things sky high.
	s.linear_velocity = vel
	s.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
	s.add_to_group("rock_shard")
	return s


func _physics_process(delta: float) -> void:
	_age += delta
	if not _clacked and _prev_vy < -2.0 and linear_velocity.y > _prev_vy + 1.5:
		_clacked = true
		Sfx.play_on(self, "clack", randf_range(0.75, 1.35))
		FX.burst(get_parent(), global_position, Color(0.76, 0.72, 0.66, 0.8), 5, 0.12, 1.2, -0.6, "sphere", 85.0)
	_prev_vy = linear_velocity.y
	if _age > LIFE - 0.8:
		_vis.scale = Vector3.ONE * maxf(0.05, (LIFE - _age) / 0.8)
	if _age >= LIFE:
		queue_free()
