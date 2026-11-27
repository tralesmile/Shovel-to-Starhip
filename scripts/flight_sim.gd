class_name FlightSim
extends RefCounted
## Hands-on starship flying, as pure logic (tested). ASCENT: hold the throttle, keep her
## upright against the wind, do not cook the engine, drop the booster at the right moment.
## LANDING: a gentle lunar lander. You can never lose: a bad ascent parachutes home for a
## free retry and a hard landing just bounces.

enum Mode { ASCENT, LANDING }

const ORBIT_ALT := 1000.0
const SEP_OPEN := 430.0       ## booster can be dropped from here...
const SEP_PERFECT_LO := 500.0
const SEP_PERFECT_HI := 580.0
const SEP_AUTO := 700.0       ## ...and falls off by itself here (no bonus)
const THRUST := 34.0
const GRAVITY := 11.0
const MAX_CLIMB := 46.0
const BURN := 0.029          ## fuel per second of throttle
const HEAT_UP := 0.17
const HEAT_DOWN := 0.34
const HEAT_RESTART := 0.45
const TUMBLE_ANGLE := 0.95
const WOBBLE_ANGLE := 0.45

const LAND_START_ALT := 160.0
const MOON_GRAVITY := 3.2
const RETRO := 9.5
const LAND_BURN := 0.075
const SIDE_ACCEL := 6.0
const PAD_HALF := 6.0
const SOFT_SPEED := 5.0
const OK_SPEED := 10.0

var mode: int = Mode.ASCENT
var stats := {"lift": 1.0, "balance": 1.0, "range": 1.0, "cool": 1.0}
var gentle := false          ## the first ever launch goes easy on you
var hiccups := false         ## turnip reactor
var alt := 0.0
var vel := 0.0
var tilt := 0.0              ## radians, + leans right
var tilt_vel := 0.0
var side := 0.0              ## landing: metres from the pad centre
var side_vel := 0.0
var fuel := 1.0
var heat := 0.0
var overheated := false
var thrusting := false       ## engine actually lit this step
var separated := false
var tumbles := 0
var bounces := 0
var time := 0.0
var outcome := ""            ## "" flying, "orbit", "abort", "landed"
var grade := ""              ## landing: "perfect", "good", "bumpy"
var events: Array[String] = []   ## drained by the presentation each step
var _rng := RandomNumberGenerator.new()
var _gust := 0.0
var _gust_t := 0.0
var _hiccup_t := 4.0
var _cough := 0.0


func _init(flight_mode: int = Mode.ASCENT, ship_stats: Dictionary = {}, seed_value: int = 1) -> void:
	mode = flight_mode
	stats.merge(ship_stats, true)
	_rng.seed = seed_value
	if mode == Mode.LANDING:
		alt = LAND_START_ALT
		vel = -14.0
		side = _rng.randf_range(10.0, 16.0) * (1.0 if _rng.randf() < 0.5 else -1.0)


func can_separate() -> bool:
	return mode == Mode.ASCENT and not separated and alt >= SEP_OPEN and outcome == ""


## Drop the spent booster. Returns "perfect", "ok" or "" (not now).
func separate() -> String:
	if not can_separate():
		return ""
	separated = true
	var perfect := alt >= SEP_PERFECT_LO and alt <= SEP_PERFECT_HI
	heat = 0.0
	overheated = false
	if perfect:
		vel = minf(vel + 16.0, MAX_CLIMB + 14.0)
		fuel = minf(1.0, fuel + 0.15)
	else:
		vel = minf(vel + 7.0, MAX_CLIMB + 6.0)
		fuel = minf(1.0, fuel + 0.05)
	events.append("sep_perfect" if perfect else "sep_ok")
	return "perfect" if perfect else "ok"


## throttle: engine button held. steer: -1 (left) .. 1 (right).
func step(dt: float, throttle: bool, steer: float) -> void:
	if outcome != "":
		thrusting = false
		return
	time += dt
	if mode == Mode.ASCENT:
		_step_ascent(dt, throttle, clampf(steer, -1.0, 1.0))
	else:
		_step_landing(dt, throttle, clampf(steer, -1.0, 1.0))


func _step_ascent(dt: float, throttle: bool, steer: float) -> void:
	if overheated and heat <= HEAT_RESTART:
		overheated = false
		events.append("relight")
	thrusting = throttle and not overheated and fuel > 0.0
	if hiccups and thrusting:
		_hiccup_t -= dt
		if _hiccup_t <= 0.0:
			_hiccup_t = _rng.randf_range(4.0, 7.0)
			_cough = 0.35
			tilt_vel += _rng.randf_range(-0.35, 0.35)
			events.append("hiccup")
	_cough = maxf(0.0, _cough - dt)
	if thrusting:
		var push: float = THRUST * float(stats["lift"]) * maxf(cos(tilt), 0.2) * (0.35 if _cough > 0.0 else 1.0)
		# Thrust climbs up to top speed; a booster-drop kick above it bleeds off gently.
		var top := MAX_CLIMB * float(stats["lift"])
		if vel < top:
			vel = minf(vel + (push - GRAVITY) * dt, top)
		else:
			vel = maxf(top, vel - 8.0 * dt)
		fuel = maxf(0.0, fuel - BURN / float(stats["range"]) * dt)
		heat += HEAT_UP / float(stats["cool"]) * (0.6 if gentle else 1.0) * dt
		if heat >= 1.0:
			heat = 1.0
			overheated = true
			events.append("overheat")
	else:
		vel -= GRAVITY * 1.4 * dt
		heat = maxf(0.0, heat - HEAT_DOWN * float(stats["cool"]) * dt)
	vel = maxf(vel, -28.0)
	alt += vel * dt
	if alt <= 0.0:
		alt = 0.0
		vel = maxf(vel, 0.0)
	# Tilt: a wobbly broom balanced on a flame, shoved about by gusts that fade as the air thins.
	_gust_t -= dt
	if _gust_t <= 0.0:
		_gust_t = _rng.randf_range(1.2, 2.6)
		_gust = _rng.randf_range(0.35, 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	if alt > 2.0:
		var air := clampf(1.0 - alt / ORBIT_ALT, 0.15, 1.0)
		var wind: float = _gust * air * 0.85 / float(stats["balance"]) * (0.5 if gentle else 1.0)
		tilt_vel += (tilt * 0.55 / float(stats["balance"]) + wind + steer * 2.1 - tilt_vel * 1.7) * dt
		tilt += tilt_vel * dt
	else:
		tilt = move_toward(tilt, 0.0, dt)
		tilt_vel = 0.0
	if absf(tilt) >= TUMBLE_ANGLE:
		# Cartoon tumble: the autopilot (a trained turnip) rights her at a price.
		tumbles += 1
		tilt = signf(tilt) * 0.2
		tilt_vel = 0.0
		vel *= 0.4
		fuel = maxf(0.0, fuel - (0.04 if gentle else 0.08))
		events.append("tumble")
	if not separated and alt >= SEP_AUTO:
		separated = true
		events.append("sep_auto")
	if alt >= ORBIT_ALT:
		alt = ORBIT_ALT
		outcome = "orbit"
		events.append("orbit")
	elif fuel <= 0.0 and vel < -6.0:
		outcome = "abort"
		events.append("abort")


func _step_landing(dt: float, throttle: bool, steer: float) -> void:
	thrusting = throttle and fuel > 0.0
	vel -= MOON_GRAVITY * dt
	if thrusting:
		vel += RETRO * float(stats["lift"]) * dt
		fuel = maxf(0.0, fuel - LAND_BURN / float(stats["range"]) * dt)
	vel = clampf(vel, -30.0, 8.0)
	alt += vel * dt
	side_vel += steer * SIDE_ACCEL * dt
	side_vel -= side_vel * (0.9 * float(stats["balance"])) * dt
	side += side_vel * dt
	side = clampf(side, -30.0, 30.0)
	tilt = lerpf(tilt, steer * 0.22, minf(1.0, 6.0 * dt))
	if alt <= 0.0:
		alt = 0.0
		var speed := -vel
		if speed > OK_SPEED and bounces < 2:
			bounces += 1
			vel = speed * 0.42
			side_vel *= 0.6
			events.append("bounce")
			return
		outcome = "landed"
		grade = landing_grade(speed, side, bounces)
		vel = 0.0
		side_vel = 0.0
		tilt = 0.0
		events.append("touchdown")


static func landing_grade(speed: float, off: float, bounced: int) -> String:
	if bounced == 0 and speed <= SOFT_SPEED and absf(off) <= PAD_HALF:
		return "perfect"
	if bounced == 0 and speed <= OK_SPEED:
		return "good"
	return "bumpy"


## A very plain pilot, used by the tests and by screenshots: [throttle, steer].
func autopilot() -> Array:
	if mode == Mode.ASCENT:
		var hold := heat < 0.82
		return [hold, clampf(-tilt * 4.0 - tilt_vel * 1.5, -1.0, 1.0)]
	var want := -clampf(alt * 0.16, 3.5, 18.0)
	return [vel < want, clampf(-side * 0.25 - side_vel * 0.6, -1.0, 1.0)]
