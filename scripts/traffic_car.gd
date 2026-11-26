class_name TrafficCar
extends AnimatableBody3D
## Ambient traffic: drives a straight lane along the town road, wraps at the ends,
## and brakes politely for anything (player, NPC, car) parked in front of it.

const CRUISE := 7.0
const ACCEL := 6.0
const BRAKE := 16.0
const LOOK_AHEAD := 9.0
const LANE_HALF_WIDTH := 1.6
const MIN_X := -52.0
const MAX_X := 52.0

var dir: float = 1.0        ## +1 drives toward +x, -1 toward -x
var lane_z: float = 14.4
var speed: float = 0.0
var cruise: float = CRUISE
var model: String = "car_taxi.gltf"


## Pure: is a point in the lane box ahead of us (so we should brake)?
static func blocked(pos: Vector3, direction: float, target: Vector3) -> bool:
	var ahead := (target.x - pos.x) * direction
	return ahead > 0.0 and ahead < LOOK_AHEAD and absf(target.z - pos.z) < LANE_HALF_WIDTH


## Pure: next speed, easing toward cruise or braking to a stop.
static func next_speed(current: float, want: float, is_blocked: bool, delta: float) -> float:
	if is_blocked:
		return move_toward(current, 0.0, BRAKE * delta)
	return move_toward(current, want, ACCEL * delta)


## Pure: advance along the lane; leaving one end re-enters at the other.
static func wrap_x(x: float) -> float:
	if x > MAX_X:
		return MIN_X
	if x < MIN_X:
		return MAX_X
	return x


func setup() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.2, 4.0)
	shape.shape = box
	shape.position.y = 0.7
	add_child(shape)
	# The model's wheels hang below its origin: lift it so they roll on the asphalt, not under it.
	Models.put(self, Models.CITY + model, Vector3(0, CarPhysics.ASPHALT_Y + 0.27 - 0.1, 0), 4.4, 0.0)
	rotation.y = PI / 2.0 if dir > 0.0 else -PI / 2.0
	sync_to_physics = false
	add_to_group("traffic")


func _physics_process(delta: float) -> void:
	var stop := false
	for n in get_tree().get_nodes_in_group("car") + get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("traffic"):
		if n != self and n is Node3D and blocked(position, dir, (n as Node3D).position):
			stop = true
			break
	speed = next_speed(speed, cruise, stop, delta)
	position.x = wrap_x(position.x + dir * speed * delta)
