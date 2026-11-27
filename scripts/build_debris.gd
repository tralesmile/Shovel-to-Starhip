class_name BuildDebris
extends RigidBody3D
## One board, stone or shingle knocked off a collapsing build piece: tumbles with real physics,
## then shrinks away. Never pushes the player.

const LIFE := 3.2
const MAX_LIVE := 70

var _age := 0.0
var _mesh: MeshInstance3D


## Spawn a flying copy of `src` under `host`, launched with `vel`.
static func fling(host: Node, src: MeshInstance3D, vel: Vector3) -> BuildDebris:
	if host.get_tree().get_nodes_in_group("build_debris").size() >= MAX_LIVE:
		return null
	var d := BuildDebris.new()
	var box := src.mesh.get_aabb()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size.max(Vector3.ONE * 0.06)
	cs.shape = sh
	d.add_child(cs)
	d._mesh = MeshInstance3D.new()
	d._mesh.mesh = src.mesh
	d._mesh.material_override = src.material_override
	d.add_child(d._mesh)
	d.collision_layer = 0
	d.collision_mask = 1
	d.mass = 0.6
	host.add_child(d)
	d.global_transform = src.global_transform.orthonormalized()
	d.linear_velocity = vel
	d.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-3, 3), randf_range(-5, 5))
	d.add_to_group("build_debris")
	return d


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFE - 0.5 and _mesh != null:
		_mesh.scale = Vector3.ONE * maxf(0.05, (LIFE - _age) / 0.5)
	if _age >= LIFE:
		queue_free()
