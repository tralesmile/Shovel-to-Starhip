class_name Car
extends CharacterBody3D
## Player's drivable car. Handling maths are static/pure so they are unit testable.
## W/S throttle and reverse, A/D steer, Space handbrake, E to hop out.

signal bumped

const MAX_SPEED := 18.0
const MAX_REVERSE := 6.0
const ACCEL := 9.0
const BRAKE := 20.0
const DRAG := 3.0          ## coasting deceleration
const MAX_STEER := 0.6     ## radians at low speed
const WHEEL_BASE := 2.6
const PRICE := 400

var speed: float = 0.0
var heading: float = 0.0
var driven: bool = false
var seat: CarSeat


## Next forward speed given throttle (-1 reverse .. 1 forward) and handbrake.
static func step_speed(current: float, throttle: float, handbrake: bool, delta: float) -> float:
	var s := current
	if handbrake:
		s = move_toward(s, 0.0, BRAKE * delta)
	elif throttle > 0.01:
		# Pressing forward while rolling backwards brakes first.
		s += (BRAKE if s < 0.0 else ACCEL * (1.0 - clampf(s / MAX_SPEED, 0.0, 1.0))) * throttle * delta
	elif throttle < -0.01:
		s += (-BRAKE if s > 0.0 else -ACCEL) * -throttle * delta
	else:
		s = move_toward(s, 0.0, DRAG * delta)
	return clampf(s, -MAX_REVERSE, MAX_SPEED)


## Steering gets tighter-limited at speed so the car does not spin like a top.
static func steer_limit(spd: float) -> float:
	return MAX_STEER * lerpf(1.0, 0.3, clampf(absf(spd) / MAX_SPEED, 0.0, 1.0))


## Heading change (bicycle model), reversed when backing up.
static func turn_delta(spd: float, steer_input: float, delta: float) -> float:
	var angle := clampf(steer_input, -1.0, 1.0) * steer_limit(spd)
	return -spd / WHEEL_BASE * tan(angle) * delta


func setup() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.2, 4.0)
	shape.shape = box
	shape.position.y = 0.7
	add_child(shape)
	Models.put(self, Models.CITY + "car_sedan.gltf", Vector3.ZERO, 4.4, 0.0)
	seat = CarSeat.new()
	seat.car = self
	seat.interact_radius = 3.2
	add_child(seat)
	add_to_group("car")


func drive(delta: float, throttle: float, steer_input: float, handbrake: bool) -> void:
	speed = step_speed(speed, throttle, handbrake, delta)
	heading += turn_delta(speed, steer_input, delta)
	rotation.y = heading
	var fwd := Vector3(sin(heading), 0, cos(heading))
	velocity = fwd * speed
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -1.0
	move_and_slide()
	# Bumping something stops us dead (comedy thud).
	if get_slide_collision_count() > 0 and absf(speed) > 3.0:
		speed *= 0.2
		bumped.emit()


func exit_position() -> Vector3:
	var side := Vector3(cos(heading), 0, -sin(heading))
	return global_position + side * 2.4 + Vector3(0, 0.3, 0)


## Door handle: lets the shared E-key interaction find the car.
class CarSeat extends Interactable:
	var car: Car

	func get_prompt(_game: GameState) -> String:
		return "[E] Hop in and drive (WASD, Space = handbrake)"

	func interact(_game: GameState) -> void:
		var p = get_tree().get_first_node_in_group("player")
		if p:
			p.enter_car(car)
