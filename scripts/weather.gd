class_name Weather
extends RefCounted
## Deterministic daily weather (pure, tested). Rain waters the crops overnight (Stardew-style) and
## draws a falling-streak particle curtain around the camera with greyer light and thicker fog.

const CLEAR := "clear"
const RAIN := "rain"
const STORM := "storm"
const FIRST_RAIN_DAY := 3   ## the first days are always sunny so new players learn the watering can


## Pure: weather for a given day number. Same day -> same weather, so saves stay consistent.
static func for_day(day: int) -> String:
	if day < FIRST_RAIN_DAY:
		return CLEAR
	var h: int = int(abs(hash("shovel-weather-%d" % day))) % 100
	if h < 8:
		return STORM
	if h < 28:
		return RAIN
	return CLEAR


static func is_wet(w: String) -> bool:
	return w == RAIN or w == STORM


## Pure: how strongly the sky greys (0 clear .. 1 storm); light and saturation scale by this.
static func gloom(w: String) -> float:
	match w:
		RAIN: return 0.55
		STORM: return 0.9
	return 0.0


## Pure: fog density for the weather (clear = baseline).
static func fog_density(w: String, base: float) -> float:
	return base * (1.0 + 2.2 * gloom(w))


## Pure: rain particle count per weather.
static func drops(w: String) -> int:
	match w:
		RAIN: return 700
		STORM: return 1500
	return 0


## Pure: the funny morning line.
static func morning_line(w: String) -> String:
	match w:
		RAIN: return "It's raining. Your crops got a free drink."
		STORM: return "Storm! The goat refuses to leave the shed. Crops watered, hair ruined."
	return ""


## Builds a rain curtain that follows `anchor` (the camera).
static func make_rain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 700
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(12, 0.2, 12)
	p.direction = Vector3(0.12, -1, 0)
	p.spread = 3.0
	p.initial_velocity_min = 22.0
	p.initial_velocity_max = 28.0
	p.gravity = Vector3(0, -6, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.05, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.8, 0.9, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = m
	p.mesh = qm
	p.emitting = false
	return p
