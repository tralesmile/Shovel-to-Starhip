class_name Buildings
extends RefCounted
## Enterable buildings: each one gets a small interior room parked far from the
## town (interiors are separate spaces; doors teleport the player between them).
## Pure helpers (Schedule) are kept free of scene state so they can be unit tested.

const INTERIOR_ORIGIN := Vector3(400, 0, 0)
const INTERIOR_SPACING := 30.0
const ROOM := Vector3(8.0, 3.2, 6.0)    ## width (x), height (y), depth (z)


## Interior origin for the nth building.
static func interior_origin(index: int) -> Vector3:
	return INTERIOR_ORIGIN + Vector3(0, 0, index * INTERIOR_SPACING)


## XZ floor area inside the walls of the nth interior (world coordinates).
static func room_rect(index: int, margin: float = 0.18) -> Rect2:
	var o := interior_origin(index)
	return Rect2(o.x - ROOM.x / 2.0 + margin, o.z - ROOM.z / 2.0 + margin, ROOM.x - margin * 2.0, ROOM.z - margin * 2.0)


static func solid_box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var mi := Art.box(size, color)
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	return body


## Builds an interior room and an exit door. `outside` is the global spot the exit
## door drops the player at. Returns {root, entry (global inside spot), exit_door}.
static func build_interior(parent: Node, index: int, outside: Vector3, wall_color: Color, title: String) -> Dictionary:
	var origin := interior_origin(index)
	var room := Node3D.new()
	room.name = "Interior_%d" % index
	room.position = origin
	parent.add_child(room)
	var t := 0.3
	solid_box(room, Vector3(ROOM.x, t, ROOM.z), Vector3(0, -t / 2.0, 0), Art.WOOD.darkened(0.1))      # floor
	var ceiling := solid_box(room, Vector3(ROOM.x, t, ROOM.z), Vector3(0, ROOM.y + t / 2.0, 0), Art.WOOD.darkened(0.3)) # ceiling
	_dollhouse_ceiling(ceiling, t)
	solid_box(room, Vector3(ROOM.x, ROOM.y, t), Vector3(0, ROOM.y / 2.0, -ROOM.z / 2.0), wall_color)    # back
	solid_box(room, Vector3(ROOM.x, ROOM.y, t), Vector3(0, ROOM.y / 2.0, ROOM.z / 2.0), wall_color)     # front (door wall)
	solid_box(room, Vector3(t, ROOM.y, ROOM.z), Vector3(-ROOM.x / 2.0, ROOM.y / 2.0, 0), wall_color)
	solid_box(room, Vector3(t, ROOM.y, ROOM.z), Vector3(ROOM.x / 2.0, ROOM.y / 2.0, 0), wall_color)
	# Indoor lighting: a warm lamp that stays on whatever the sun is doing.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, ROOM.y - 0.5, 0)
	lamp.omni_range = 11.0
	lamp.light_energy = 1.35
	lamp.light_color = Color(1.0, 0.86, 0.62)
	room.add_child(lamp)
	var bulb := Art.sphere(0.09, Color(1.0, 0.92, 0.6))
	bulb.material_override = Art.mat(Color(1.0, 0.92, 0.6), true)
	bulb.position = Vector3(0, ROOM.y - 0.6, 0)
	room.add_child(bulb)
	var sign := Art.label(title, 44, Color(1, 0.95, 0.8))
	sign.position = Vector3(0, ROOM.y - 0.8, -ROOM.z / 2.0 + 0.3)
	room.add_child(sign)
	# Exit door on the front wall, standing just inside.
	var exit_door := Door.new()
	exit_door.name = "ExitDoor"
	exit_door.position = Vector3(0, 0, ROOM.z / 2.0 - 0.28)   # flush with the wall, out of the camera's way
	exit_door.destination = outside
	exit_door.label = "Leave"
	exit_door.interact_radius = 1.8
	room.add_child(exit_door)
	exit_door.attach_leaf()
	exit_door.open_angle = -Door.OPEN_ANGLE   # swings into the room, not into the wall
	RoomDressing.dress(room, index, wall_color)
	return {"root": room, "entry": origin + Vector3(0, 0.1, ROOM.z / 2.0 - 1.8), "exit_door": exit_door}


const CEILING_LAYER := 2

## The ceiling still stops people, but not the camera: its mesh only faces down,
## so a camera above the room looks straight through it (no more near-clip slab
## across the top of the screen).
static func _dollhouse_ceiling(body: StaticBody3D, thickness: float) -> void:
	body.collision_layer = CEILING_LAYER
	var mi := body.get_child(0) as MeshInstance3D
	var plane := PlaneMesh.new()
	plane.size = Vector2(ROOM.x, ROOM.z)
	plane.flip_faces = true
	mi.mesh = plane
	mi.position.y = -thickness / 2.0
	# A plain one-sided material: the toon outline pass would draw the back face.
	var m := StandardMaterial3D.new()
	m.albedo_color = Art.WOOD.darkened(0.3)
	m.cull_mode = BaseMaterial3D.CULL_BACK
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Adds a front door to a facade. Teleports to `entry` inside.
static func add_front_door(parent: Node, local_pos: Vector3, entry: Vector3, label: String, with_mesh: bool = true) -> Door:
	var d := Door.new()
	d.position = local_pos
	d.destination = entry
	d.label = label
	d.interact_radius = 1.6
	parent.add_child(d)
	if with_mesh:
		d.attach_leaf()
	return d


## NPC daily routine, driven by Game.time_of_day (0..1).
class Schedule:
	enum Activity { SLEEP, WAKE, WORK, HOME }
	const WAKE_AT := 6.0
	const WORK_AT := 8.0
	const HOME_AT := 17.0
	const SLEEP_AT := 22.0

	static func activity_at(time_of_day: float, wake_shift: float = 0.0) -> int:
		var h := fposmod(time_of_day * 24.0 - wake_shift, 24.0)
		if h >= SLEEP_AT or h < WAKE_AT:
			return Activity.SLEEP
		if h < WORK_AT:
			return Activity.WAKE
		if h < HOME_AT:
			return Activity.WORK
		return Activity.HOME

	static func is_indoors(activity: int) -> bool:
		return activity != Activity.WORK
