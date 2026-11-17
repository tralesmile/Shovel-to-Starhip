class_name PoliceCar
extends Node3D
## Squad car that joins the hunt at max heat while the player is driving. Pure
## pursuit steering: turn toward the target at a limited rate, cruise a bit slower
## than the player's top speed so skilled drivers can escape. Touching = busted.

const CRUISE := 15.0
const ACCEL := 8.0
const TURN_RATE := 1.9       ## rad/s
const CATCH_DIST := 3.4
const GIVE_UP_DIST := 70.0
const SPAWN_DIST := 38.0

var active := false
var speed := 0.0
var heading := 0.0


## Pure: is a squad car needed? Heat maxed, player driving and not hidden indoors.
static func should_chase(heat: float, player_driving: bool, hidden: bool) -> bool:
	return heat >= GameState.MAX_HEAT - 0.001 and player_driving and not hidden


## Pure: rotate `heading` toward `desired` by at most `max_turn`.
static func steer(current: float, desired: float, max_turn: float) -> float:
	return current + clampf(wrapf(desired - current, -PI, PI), -max_turn, max_turn)


## Pure: slow down for sharp turns, otherwise ease up to cruise.
static func next_speed(current: float, angle_off: float, delta: float) -> float:
	var want := CRUISE * (0.55 if absf(angle_off) > 1.0 else 1.0)
	return move_toward(current, want, ACCEL * delta)


static func caught(dist: float) -> bool:
	return dist <= CATCH_DIST


func setup() -> void:
	Models.put(self, Models.CITY + "car_police.gltf", Vector3.ZERO, 4.4, 0.0)
	visible = false


func deactivate() -> void:
	active = false
	visible = false
	speed = 0.0


## Returns true on the tick the player is caught.
func update_chase(delta: float, player_pos: Vector3, heat: float, driving: bool) -> bool:
	if not should_chase(heat, driving, Police.is_hidden(player_pos)):
		if active:
			deactivate()
		return false
	var to := player_pos - global_position
	to.y = 0.0
	if not active:
		active = true
		visible = true
		var side := 1.0 if player_pos.x < 0.0 else -1.0
		global_position = Vector3(clampf(player_pos.x + side * SPAWN_DIST, -50.0, 50.0), 0.1, 16.0)
		heading = atan2(to.x, to.z)
		to = player_pos - global_position
		to.y = 0.0
	var d := to.length()
	if d > GIVE_UP_DIST:
		deactivate()
		return false
	var desired := atan2(to.x, to.z)
	var off := wrapf(desired - heading, -PI, PI)
	heading = steer(heading, desired, TURN_RATE * delta)
	speed = next_speed(speed, off, delta)
	rotation.y = heading
	global_position += Vector3(sin(heading), 0.0, cos(heading)) * speed * delta
	if caught(d):
		deactivate()
		return true
	return false
