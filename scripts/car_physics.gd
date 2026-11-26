class_name CarPhysics
extends RefCounted
## Pure arcade-driving maths (no nodes, all unit tested): drifting, drift-charge mini turbos,
## crash bounces, damage, the body-on-springs suspension and where the road surface is.

# --- Road ---------------------------------------------------------------------------------
## The town road model has no collision, so cars lift their *visuals* onto it.
const ROAD_Z := 16.0
const ROAD_ASPHALT_HALF := 3.84   ## asphalt is the middle 80% of the 9.6m tile
const ROAD_HALF := 4.8
const ROAD_HALF_LENGTH := 62.4    ## 13 tiles
const ASPHALT_Y := 0.35
const CURB_Y := 0.48


## Height of the road mesh above the flat ground at a world position (0 off the road).
static func road_height(x: float, z: float) -> float:
	var dz := absf(z - ROAD_Z)
	if absf(x) > ROAD_HALF_LENGTH or dz > ROAD_HALF:
		return 0.0
	return ASPHALT_Y if dz <= ROAD_ASPHALT_HALF else CURB_Y


# --- Drifting -----------------------------------------------------------------------------
const GRIP := 11.0            ## how fast sideways speed dies on normal tyres
const DRIFT_GRIP := 1.6       ## handbrake slide
const SLICK_GRIP_MULT := 0.65 ## Drift Tyres slide longer
const GRIP_RECOVER := 22.0    ## grip comes back over a moment, not in one frame
const DRIFT_YAW := 1.5        ## the nose swings in harder while sliding
const DRIFT_MIN_SPEED := 6.0
const DRIFT_SLIP := 2.5       ## sideways m/s that counts as a drift (skid marks, smoke)
const DRIFT_DRAG := 3.5       ## a drift only scrubs a little speed
const MAX_SLIP_RATIO := 0.85


## Handbrake + steering at speed = drift. Handbrake alone is still a brake.
static func wants_drift(speed: float, steer: float, handbrake: bool) -> bool:
	return handbrake and absf(steer) > 0.3 and speed > DRIFT_MIN_SPEED


static func grip_step(grip: float, drifting_wanted: bool, slick: bool, delta: float) -> float:
	var want := DRIFT_GRIP if drifting_wanted else GRIP
	if slick:
		want *= SLICK_GRIP_MULT
	if want < grip:
		return want   # the tail steps out at once
	return move_toward(grip, want, GRIP_RECOVER * delta)


## Sideways (leftward) speed after the car yaws by `dh` radians: momentum keeps going the old
## way, then the tyres bleed it off at `grip`.
static func slip_step(lat: float, speed: float, dh: float, grip: float, delta: float) -> float:
	var l := lat * cos(dh) - speed * sin(dh)
	l *= exp(-grip * delta)
	var cap := absf(speed) * MAX_SLIP_RATIO
	return clampf(l, -cap, cap)


static func is_sliding(lat: float, speed: float) -> bool:
	return absf(lat) > DRIFT_SLIP and absf(speed) > 4.0


# --- Drift charge / mini turbo ------------------------------------------------------------
const TIER1_CHARGE := 0.7
const TIER2_CHARGE := 1.6
const TURBO_KICK := [0.0, 3.5, 6.5]
const TURBO_TIME := [0.0, 0.7, 1.3]
const SLICK_CHARGE := 1.6


static func charge_step(charge: float, sliding: bool, lat: float, slick: bool, delta: float) -> float:
	if not sliding:
		return charge
	var rate := clampf(absf(lat) / 6.0, 0.4, 1.4) * (SLICK_CHARGE if slick else 1.0)
	return minf(charge + rate * delta, TIER2_CHARGE + 0.4)


static func tier_for(charge: float) -> int:
	if charge >= TIER2_CHARGE:
		return 2
	return 1 if charge >= TIER1_CHARGE else 0


# --- Crashes ------------------------------------------------------------------------------
const SCRAPE_IMPACT := 2.5   ## slower than this into a wall is just a scrape
const DAMAGE_IMPACT := 6.0   ## slower than this never dents
const DAMAGE_PER_MS := 0.03
const BULL_BAR_MULT := 0.4
const MAX_DAMAGE := 1.0


## Speed of travel straight into a surface with horizontal normal n (0 when moving away).
static func impact_speed(vel: Vector2, n: Vector2) -> float:
	return maxf(0.0, -vel.dot(n))


## Velocity after hitting a wall: bounce off the normal, keep most of the sideways part.
static func bounce_velocity(vel: Vector2, n: Vector2, bounce: float, keep: float) -> Vector2:
	var into := impact_speed(vel, n)
	if into <= 0.0:
		return vel
	var tangent := vel + n * into
	return tangent * keep + n * into * bounce


static func damage_for(impact: float, bull_bar: bool) -> float:
	var d := maxf(0.0, impact - DAMAGE_IMPACT) * DAMAGE_PER_MS
	return d * (BULL_BAR_MULT if bull_bar else 1.0)


## A wreck still limps home at 60% of top speed.
static func speed_mult(damage: float) -> float:
	return 1.0 - 0.4 * clampf(damage, 0.0, 1.0)


## 0 = fine, 1 = grey steam, 2 = black smoke.
static func smoke_stage(damage: float) -> int:
	if damage >= 0.7:
		return 2
	return 1 if damage >= 0.35 else 0


static func condition_text(damage: float) -> String:
	if damage >= 0.7:
		return "Wrecked-ish"
	if damage >= 0.35:
		return "Steaming"
	if damage > 0.04:
		return "Dented"
	return "Mint"


# --- Suspension ---------------------------------------------------------------------------
const SPRING_K := 120.0
const SPRING_DAMP := 11.0
const MAX_ROLL := 0.13    ## radians
const MAX_PITCH := 0.08


## Damped spring toward `target`. Returns (value, velocity). Sub-stepped so long frames are safe.
static func spring_step(x: float, v: float, target: float, delta: float, k: float = SPRING_K, c: float = SPRING_DAMP) -> Vector2:
	var left := minf(delta, 0.25)
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		v += ((target - x) * k - v * c) * h
		x += v * h
		left -= h
	return Vector2(x, v)


## Body lean in a corner: yaw rate (rad/s, + = turning left) throws the body to the outside.
## Positive result = positive rotation.z (car faces +Z, so that drops the right side).
static func roll_target(yaw_rate: float, speed: float) -> float:
	return clampf(yaw_rate * speed * 0.005, -MAX_ROLL, MAX_ROLL)


## Squat under power (nose up = negative rotation.x for a +Z car), dive under braking.
static func pitch_target(accel: float) -> float:
	return clampf(-accel * 0.0045, -MAX_PITCH, MAX_PITCH)


# --- Knocking street props ----------------------------------------------------------------
## Is `p` inside the car's footprint grown by `reach` in the direction it is moving?
static func in_bumper_zone(car_pos: Vector3, heading: float, speed: float, p: Vector3, reach: float) -> bool:
	var d := Vector2(p.x - car_pos.x, p.z - car_pos.z)
	var fwd := d.dot(Vector2(sin(heading), cos(heading)))
	var side := d.dot(Vector2(cos(heading), -sin(heading)))
	if absf(side) > 1.0 + reach or absf(p.y - car_pos.y) > 2.0:
		return false
	var front := 2.0 + reach + (absf(speed) * 0.05 if speed > 0.0 else 0.0)
	var back := 2.0 + reach + (absf(speed) * 0.05 if speed < 0.0 else 0.0)
	return fwd <= front and fwd >= -back


## Launch velocity for a clipped prop: carried along with the car, shoved sideways and upward.
static func launch_velocity(car_vel: Vector3, away: Vector3, bull_bar: bool) -> Vector3:
	var flat := Vector3(away.x, 0.0, away.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3(1, 0, 0)
	var sp := Vector2(car_vel.x, car_vel.z).length()
	var v := car_vel * 0.85 + flat * (1.5 + sp * 0.22)
	v.y = 2.0 + sp * 0.28
	return v * (1.3 if bull_bar else 1.0)


## The speedometer reads in km/h, never negative.
static func speed_text(speed: float) -> String:
	return "%d km/h%s" % [int(round(absf(speed) * 3.6)), "  R" if speed < -0.3 else ""]
