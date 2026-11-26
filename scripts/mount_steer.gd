class_name MountSteer
extends RefCounted
## Weighty mount steering: above a trot the goat turns at a limited rate (slower the faster
## it runs), bleeds speed in hard turns and leans into the corner. Pure maths (tested).

const CARVE_SPEED := 4.0
const TURN_SLOW := 6.5     ## rad/s at CARVE_SPEED
const TURN_FAST := 2.6     ## rad/s at a full gallop
const ACCEL := 14.0
const BRAKE := 22.0


static func turn_limit(speed: float, on_floor: bool) -> float:
	var t := clampf((speed - CARVE_SPEED) / (Critter.MOUNT_GALLOP - CARVE_SPEED), 0.0, 1.0)
	return lerpf(TURN_SLOW, TURN_FAST, t) * (1.0 if on_floor else 0.35)


## `vel` and `wish` are ground velocities (x, z). Returns {"velocity", "turn_rate"}; the
## turn rate is signed, positive = turning left (increasing model yaw).
static func step(vel: Vector2, wish: Vector2, delta: float, on_floor: bool) -> Dictionary:
	var speed := vel.length()
	var dir := vel / maxf(speed, 0.001)
	if wish.length() < 0.1:
		var slowed := move_toward(speed, 0.0, BRAKE * 0.6 * delta if on_floor else 0.0)
		return {"velocity": dir * slowed, "turn_rate": 0.0}
	var want := wish.normalized()
	var angle := dir.angle_to(want)
	if absf(angle) > 2.5 and on_floor:
		# Pulling hard back: dig the hooves in first, turn once slow.
		return {"velocity": dir * move_toward(speed, 0.0, BRAKE * delta), "turn_rate": 0.0}
	var limit := turn_limit(speed, on_floor) * delta
	var turned := clampf(angle, -limit, limit)
	var target := wish.length() * (1.0 - 0.18 * clampf(absf(angle) / 2.0, 0.0, 1.0))
	var next := move_toward(speed, target, (ACCEL if target > speed else BRAKE * 0.5) * delta)
	# Vector2 angles run clockwise in (x, z); model yaw = atan2(x, z) runs the other way.
	return {"velocity": dir.rotated(turned) * next, "turn_rate": -turned / maxf(delta, 0.001)}


## Roll into the corner (radians). Positive roll tips a +Z-facing model to its right, so lean = -turn.
static func lean(turn_rate: float, speed: float) -> float:
	return clampf(-turn_rate * speed * 0.012, -0.3, 0.3)
