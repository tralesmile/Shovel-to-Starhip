class_name KnockProp
extends RigidBody3D
## Street furniture that sits still until the car clips it, then goes flying: traffic cones,
## picket fence panels, mailboxes and a hay-bale pyramid to bowl over. It tidies itself back
## up once you have driven away.

const KINDS := {
	"cone": {"mass": 1.5, "size": Vector3(0.55, 0.85, 0.55)},
	"fence": {"mass": 6.0, "size": Vector3(1.9, 0.95, 0.18)},
	"mailbox": {"mass": 5.0, "size": Vector3(0.5, 1.25, 0.6)},
	"bale": {"mass": 4.0, "size": Vector3(1.1, 0.75, 0.8)},
}
const RESPAWN_TIME := 35.0
const RESPAWN_DIST := 20.0
const MIN_KNOCK_SPEED := 1.2

const BARKS := {
	"cone": "You flattened a cone. It had one job.",
	"fence": "CRUNCH. That fence was merely resting.",
	"mailbox": "Mail delivery: airborne.",
	"bale": "STRIKE! The hay never saw it coming.",
}

static var _last_bark := {}

var kind := "cone"
var cluster := ""      ## props sharing a cluster id all wake together (stacks)
var game: GameState
var knocked := false
var _home := Transform3D.IDENTITY
var _down_for := 0.0
var _gave_loot := false
var _hit_car: PhysicsBody3D


## Pure (tested): may a knocked prop reset itself?
static func may_respawn(down_for: float, player_dist: float) -> bool:
	return down_for >= RESPAWN_TIME and player_dist >= RESPAWN_DIST


func _ready() -> void:
	add_to_group("knockable")
	var d: Dictionary = KINDS[kind]
	mass = d["mass"]
	var size: Vector3 = d["size"]
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	var phys := PhysicsMaterial.new()
	phys.friction = 0.8
	phys.bounce = 0.3
	physics_material_override = phys
	# The body's origin is its centre so it tumbles naturally.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	_build_mesh(size)
	_home = transform


func _part(mesh_node: MeshInstance3D, pos: Vector3) -> MeshInstance3D:
	mesh_node.position = pos
	add_child(mesh_node)
	return mesh_node


func _build_mesh(size: Vector3) -> void:
	var h := size.y * 0.5
	match kind:
		"cone":
			var orange := Color(1.0, 0.45, 0.08)
			_part(Art.box(Vector3(0.55, 0.08, 0.55), orange.darkened(0.3)), Vector3(0, -h + 0.04, 0))
			_part(Art.cylinder(0.05, 0.22, 0.76, orange, 10), Vector3(0, -h + 0.46, 0))
			_part(Art.cylinder(0.11, 0.145, 0.15, Color(0.97, 0.97, 0.95), 10), Vector3(0, -h + 0.5, 0))
		"fence":
			var wood := Color(0.93, 0.9, 0.8)
			for y in [-0.12, 0.22]:
				_part(Art.box(Vector3(1.9, 0.1, 0.07), wood.darkened(0.12)), Vector3(0, y, 0))
			for i in 6:
				var x := -0.8 + i * 0.32
				_part(Art.box(Vector3(0.17, 0.78, 0.07), wood), Vector3(x, -h + 0.39, 0.06))
				_part(Art.prism(Vector3(0.17, 0.16, 0.07), wood), Vector3(x, -h + 0.86, 0.06))
		"mailbox":
			_part(Art.box(Vector3(0.12, 0.85, 0.12), Art.WOOD), Vector3(0, -h + 0.42, 0))
			_part(Art.box(Vector3(0.45, 0.28, 0.58), Color(0.2, 0.42, 0.85)), Vector3(0, -h + 0.98, 0))
			var top := _part(Art.cylinder(0.225, 0.225, 0.58, Color(0.2, 0.42, 0.85), 10), Vector3(0, -h + 1.1, 0))
			top.rotation.x = PI / 2.0
			_part(Art.box(Vector3(0.04, 0.3, 0.05), Color(0.9, 0.15, 0.1)), Vector3(0.26, -h + 1.15, -0.1))
			_part(Art.box(Vector3(0.04, 0.1, 0.18), Color(0.9, 0.15, 0.1)), Vector3(0.26, -h + 1.28, -0.02))
		"bale":
			var straw := Color(0.93, 0.76, 0.3)
			_part(Art.box(size, straw), Vector3.ZERO)
			for x in [-0.3, 0.3]:
				_part(Art.box(Vector3(0.09, size.y + 0.03, size.z + 0.03), straw.darkened(0.35)), Vector3(x, 0, 0))


func _debris_color() -> Color:
	match kind:
		"cone":
			return Color(1.0, 0.5, 0.1)
		"mailbox":
			return Color(0.98, 0.97, 0.9)   # letters everywhere
		"bale":
			return Color(0.96, 0.82, 0.36)
	return Color(0.9, 0.84, 0.7)


## Send it flying. `car` is ignored by its collisions until it tidies itself up.
func knock(velocity: Vector3, car: PhysicsBody3D = null, wake_cluster: bool = true) -> bool:
	if knocked:
		return false
	knocked = true
	_down_for = 0.0
	if car != null:
		_hit_car = car
		car.add_collision_exception_with(self)
	freeze = false
	sleeping = false
	linear_velocity = velocity
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6))
	var host := get_parent()
	FX.burst(host, global_position + Vector3(0, 0.3, 0), _debris_color(), 18 if kind == "bale" or kind == "mailbox" else 8,
		0.1, 4.5, -7.0, "box", 75.0)
	Sfx.play_on(self, "rustle" if kind == "bale" else ("boing" if kind == "cone" else "chop"), 0.8 + randf() * 0.4)
	if game != null:
		var now := Time.get_ticks_msec()
		if now - int(_last_bark.get(kind, -100000)) > 9000:
			_last_bark[kind] = now
			game.say(BARKS[kind])
		if kind == "fence" and not _gave_loot:
			_gave_loot = true
			_drop_plank(host)
	if wake_cluster and cluster != "" and is_inside_tree():
		for n in get_tree().get_nodes_in_group("knockable"):
			var other := n as KnockProp
			if other != self and other.cluster == cluster:
				# The rest of the stack tumbles after it with a bit less oomph.
				var out := (other.global_position - global_position) * 1.6
				other.knock(velocity * randf_range(0.45, 0.75) + out + Vector3(0, randf_range(0.5, 2.5), 0), car, false)
	return true


func _drop_plank(host: Node) -> void:
	var p := WoodLog.new()
	p.game = game
	p.item_id = "plank"
	p.amount = 1
	host.add_child(p)
	p.global_position = global_position + Vector3(0, 0.6, 0)
	p.pop()


func reset_prop() -> void:
	if _hit_car != null and is_instance_valid(_hit_car):
		_hit_car.remove_collision_exception_with(self)
	_hit_car = null
	knocked = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	transform = _home


func _physics_process(delta: float) -> void:
	if not knocked:
		return
	_down_for += delta
	if _down_for < RESPAWN_TIME:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var dist := INF
	if pl != null:
		var parent := get_parent() as Node3D
		var home_world: Vector3 = parent.global_transform * _home.origin if parent != null else _home.origin
		dist = minf(pl.global_position.distance_to(home_world), pl.global_position.distance_to(global_position))
	if may_respawn(_down_for, dist):
		reset_prop()
		FX.burst(get_parent(), global_position, Color(1, 1, 1), 6, 0.1, 1.5, -1.0, "sphere", 120.0)


## The street layout: returns [kind, x, z, yaw, extra_height, cluster] rows. Pure (tested).
static func street_layout() -> Array:
	var out: Array = []
	# A cone slalom on the grass verge east of Honest Hank's, ending in a bale pyramid to bowl over.
	for i in 6:
		out.append(["cone", 20.0 + i * 3.6, 8.6 + (1.3 if i % 2 == 0 else -1.3), 0.0, 0.0, ""])
	var bx := 44.0
	for row in 3:
		for k in 3 - row:
			var z := 8.6 + (k - (2 - row) * 0.5) * 0.86
			out.append(["bale", bx, z, PI / 2.0, row * 0.76, "pyramid"])
	# Picket panels along the west verge.
	for i in 6:
		out.append(["fence", -32.0 + i * 2.05, 9.9, 0.0, 0.0, ""])
	for x in [-22.6, -12.0, 12.0, 29.0]:
		out.append(["mailbox", x, 21.9, PI / 2.0, 0.0, ""])
	return out
