class_name Car
extends CharacterBody3D
## Player's drivable car. Handling maths are static/pure so they are unit testable.
## W/S throttle and reverse, A/D steer, Space handbrake, E to hop out.

signal bumped
signal bumped_prop
signal smoke_started(stage: int)

const REPAIR_AMOUNT := 0.6

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
## Arcade physics state (see CarPhysics).
var lat: float = 0.0             ## sideways (leftward) slip speed
var grip: float = CarPhysics.GRIP
var damage: float = 0.0          ## 0 mint .. 1 wreck
var drift_charge: float = 0.0
var turbo_time: float = 0.0
var _turbo_kick: float = 0.0
var sliding: bool = false
var last_impact: float = 0.0
var yaw_rate: float = 0.0
var _hit_cooldown: float = 0.0
var _screech_cd: float = 0.0
## Visual rig: _lift sets ride height, _chassis leans on its springs, wheels spin and steer.
var _lift: Node3D
var _chassis: Node3D
var _wheels: Array = []           ## [{pivot, spin, front, base_y}]
var _roll := Vector2.ZERO         ## spring (value, velocity)
var _pitch := Vector2.ZERO
var _heave := Vector2.ZERO
var _accel := 0.0
var _steer_vis := 0.0
var _last_road := -1.0
var skids: SkidMarks
var _wheel_last: Array = [null, null]
var _smoke: CPUParticles3D
var _sparks: Array[CPUParticles3D] = []
var _brake_mat: StandardMaterial3D
var _turbo_flames: Array[CPUParticles3D] = []
var braking: bool = false
const LIFT_BASE := 0.37          ## the imported model's wheels hang this far below the floor
const WHEEL_RADIUS := 0.32
var _lamps: Array[SpotLight3D] = []
var _dust: CPUParticles3D
var parts: Array = []            ## installed upgrade ids (see PARTS)
var boost: float = 1.0           ## rocket booster fuel 0..1
var boosting: bool = false
var _flame: CPUParticles3D
var _part_nodes: Dictionary = {}

## Vehicle builder v1: bolt-on parts crafted at the workbench (Trailmakers-style modular upgrades).
const PARTS := {
	"turbo_engine": {"name": "Turbo Engine", "max_speed": 1.3, "accel": 1.4},
	"offroad_wheels": {"name": "Big Wheels", "steer": 1.25, "bump_add": 0.25},
	"rocket_booster": {"name": "Rocket Booster", "boost": 1.5},
	"bull_bar": {"name": "Bull Bar"},       ## crashes dent far less, props fly further
	"drift_tyres": {"name": "Drift Tyres"},  ## longer slides, faster turbo charge
}
const BOOST_DRAIN := 0.4
const BOOST_RECHARGE := 0.18


## Combined handling multipliers for a set of installed parts. Pure.
static func stats_for(installed: Array) -> Dictionary:
	var st := {"max_speed": MAX_SPEED, "accel": ACCEL, "steer": 1.0, "bump": 0.2, "boost": 1.0}
	for id in installed:
		var d: Dictionary = PARTS.get(id, {})
		st["max_speed"] *= float(d.get("max_speed", 1.0))
		st["accel"] *= float(d.get("accel", 1.0))
		st["steer"] *= float(d.get("steer", 1.0))
		st["bump"] += float(d.get("bump_add", 0.0))
		st["boost"] *= float(d.get("boost", 1.0))
	return st


## Boost fuel step: drains while boosting, refills otherwise. Returns {fuel, active}.
static func boost_step(fuel: float, want: bool, has_booster: bool, delta: float) -> Dictionary:
	if not has_booster:
		return {"fuel": fuel, "active": false}
	if want and fuel > 0.02:
		return {"fuel": maxf(0.0, fuel - BOOST_DRAIN * delta), "active": true}
	return {"fuel": minf(1.0, fuel + BOOST_RECHARGE * delta), "active": false}


## Next forward speed given throttle (-1 reverse .. 1 forward) and handbrake.
static func step_speed(current: float, throttle: float, handbrake: bool, delta: float, top: float = MAX_SPEED, accel: float = ACCEL) -> float:
	var s := current
	if handbrake:
		s = move_toward(s, 0.0, BRAKE * delta)
	elif throttle > 0.01:
		# Pressing forward while rolling backwards brakes first.
		s += (BRAKE if s < 0.0 else accel * (1.0 - clampf(s / top, 0.0, 1.0))) * throttle * delta
	elif throttle < -0.01:
		s += (-BRAKE if s > 0.0 else -ACCEL) * -throttle * delta
	else:
		s = move_toward(s, 0.0, DRAG * delta)
	return clampf(s, -MAX_REVERSE, maxf(top, MAX_SPEED))


## Tyre dust puffs when the handbrake is dragged at real speed, or when the car
## is flung into a tight corner at pace.
static func dust_amount(spd: float, handbrake: bool, steer_input: float) -> float:
	var a := absf(spd)
	if a < 4.0:
		return 0.0
	if handbrake:
		return clampf(a / MAX_SPEED, 0.3, 1.0)
	if absf(steer_input) > 0.8 and a > MAX_SPEED * 0.7:
		return 0.4
	return 0.0


func _add_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.position = Vector3(0, 0.2, -1.5)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.85, 0.05, 0.25)
	_dust.local_coords = false
	_dust.amount = 40
	_dust.lifetime = 0.8
	_dust.emitting = false
	_dust.direction = Vector3(0, 1, 0)
	_dust.spread = 40.0
	_dust.initial_velocity_min = 0.8
	_dust.initial_velocity_max = 2.0
	_dust.gravity = Vector3(0, 0.5, 0)
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.25
	m.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.8, 0.7, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	_dust.mesh = m
	add_child(_dust)


## Headlights come on once it is properly dusky (0 = bright day .. 1 = dark night).
static func headlights_on(dark: float) -> bool:
	return dark > 0.35


func set_dark(dark: float) -> void:
	var on := headlights_on(dark)
	for l in _lamps:
		l.visible = on


func _add_headlights() -> void:
	for x in [-0.7, 0.7]:
		var l := SpotLight3D.new()
		l.position = Vector3(x, 0.8, 2.0)
		l.rotation.x = deg_to_rad(-6.0)   # -Z is forward for lights; car forward is +Z
		l.rotation.y = PI
		l.spot_range = 22.0
		l.spot_angle = 32.0
		l.light_energy = 2.5
		l.light_color = Color(1.0, 0.95, 0.75)
		l.visible = false
		add_child(l)
		_lamps.append(l)


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
	_build_rig()
	skids = SkidMarks.new()
	add_child(skids)
	seat = CarSeat.new()
	seat.car = self
	seat.interact_radius = 3.2
	add_child(seat)
	_add_headlights()
	_add_dust()
	_add_smoke()
	_add_drift_sparks()
	_add_brake_lights()
	add_to_group("car")


## Splits the imported sedan into a sprung body and four wheels that can spin and steer.
func _build_rig() -> void:
	_lift = Node3D.new()
	_lift.position.y = LIFT_BASE
	add_child(_lift)
	_chassis = Node3D.new()
	_lift.add_child(_chassis)
	var model := Models.put(_chassis, Models.CITY + "car_sedan.gltf", Vector3.ZERO, 4.4, 0.0)
	for w in model.find_children("*wheel*", "MeshInstance3D", true, false):
		var mi := w as MeshInstance3D
		var at: Vector3 = Models._relative_xf(mi, _chassis).origin
		var pivot := Node3D.new()
		pivot.position = at
		_lift.add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		mi.get_parent().remove_child(mi)
		mi.owner = null
		spin.add_child(mi)
		mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * 4.4), Vector3.ZERO)
		_wheels.append({"pivot": pivot, "spin": spin, "front": at.z > 0.0, "base_y": at.y})


func _puff_emitter(amount: int, life: float, radius: float, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 1.1, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(0.5, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	p.mesh = m
	return p


## Steam / smoke from under the bonnet when the car is badly dented.
func _add_smoke() -> void:
	_smoke = _puff_emitter(26, 1.6, 0.24, Color(1, 1, 1, 0.5))
	_smoke.position = Vector3(0, 1.15, 1.5)
	_chassis.add_child(_smoke)


## Mini-turbo charge sparks at the back wheels (blue, then orange) and the release flames.
func _add_drift_sparks() -> void:
	for x in [-0.85, 0.85]:
		var s := FX.emitter(self, Color.WHITE, 18, 0.28, 0.09, Vector3(0.1, 0.04, 0.1), Vector3(0, -9, 0), true)
		s.position = Vector3(x, 0.25, -1.45)
		s.direction = Vector3(0, 0.6, -1)
		s.spread = 40.0
		s.initial_velocity_min = 2.0
		s.initial_velocity_max = 4.5
		s.local_coords = false
		s.emitting = false
		_sparks.append(s)
		var f := _puff_emitter(16, 0.25, 0.13, Color(1, 1, 1, 0.9))
		f.position = Vector3(x * 0.55, 0.45, -2.15)
		f.local_coords = true
		f.direction = Vector3(0, 0, -1)
		f.spread = 12.0
		f.initial_velocity_min = 3.0
		f.initial_velocity_max = 5.0
		f.gravity = Vector3.ZERO
		_chassis.add_child(f)
		_turbo_flames.append(f)


func _add_brake_lights() -> void:
	_brake_mat = StandardMaterial3D.new()
	_brake_mat.albedo_color = Color(0.45, 0.04, 0.03)
	_brake_mat.emission_enabled = true
	_brake_mat.emission = Color(1.0, 0.08, 0.05)
	_brake_mat.emission_energy_multiplier = 0.15
	for x in [-0.62, 0.62]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.14, 0.06)
		b.mesh = bm
		b.material_override = _brake_mat
		b.position = Vector3(x, 0.52, -2.09)
		_chassis.add_child(b)


## Visual-only update: springs, wheels, ride height, smoke and lights. Runs parked or driven.
func animate(delta: float) -> void:
	if _chassis == null:
		return
	var here := global_position if is_inside_tree() else position
	var road := CarPhysics.road_height(here.x, here.z)
	# Rolling over a kerb (or onto the road) kicks the springs.
	if _last_road >= 0.0 and absf(road - _last_road) > 0.01 and absf(speed) > 1.0:
		_heave.y += clampf((road - _last_road) * absf(speed) * 0.45, -2.2, 2.2)
		_pitch.y -= clampf((road - _last_road) * absf(speed) * 0.2, -0.6, 0.6)
	_last_road = road
	var floor_gap := clampf(Terrain.height_at(here.x, here.z) - here.y, -0.15, 0.15)
	var big := has_part("offroad_wheels")
	_lift.position.y = move_toward(_lift.position.y, 0.27 + floor_gap + road + (0.13 if big else 0.0), 3.0 * delta)
	_roll = CarPhysics.spring_step(_roll.x, _roll.y, CarPhysics.roll_target(yaw_rate, speed), delta)
	_pitch = CarPhysics.spring_step(_pitch.x, _pitch.y, CarPhysics.pitch_target(_accel), delta)
	_heave = CarPhysics.spring_step(_heave.x, _heave.y, 0.0, delta, 150.0, 8.0)
	var rumble := 0.0
	if driven and road <= 0.0 and absf(speed) > 3.0:
		rumble = randf_range(-0.012, 0.012) * clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
	_chassis.rotation = Vector3(clampf(_pitch.x, -0.16, 0.16), 0.0, clampf(_roll.x, -0.2, 0.2) + damage * 0.035)
	_chassis.position.y = clampf(_heave.x, -0.14, 0.2) + rumble
	for w in _wheels:
		(w["spin"] as Node3D).rotate_x(speed / WHEEL_RADIUS * delta)
		var pivot := w["pivot"] as Node3D
		pivot.rotation.y = _steer_vis if w["front"] else 0.0
	if _smoke:
		var stage := CarPhysics.smoke_stage(damage)
		_smoke.emitting = stage > 0
		_smoke.color = Color(0.12, 0.11, 0.11, 1.0) if stage == 2 else Color(0.85, 0.86, 0.9, 0.75)
	if _brake_mat:
		_brake_mat.emission_energy_multiplier = 3.5 if braking else 0.15


func _process(delta: float) -> void:
	if not driven:
		yaw_rate = 0.0
		_accel = 0.0
		braking = false
	animate(delta)


## Parks it: stop every driving effect (called when the driver hops out).
func halt() -> void:
	speed = 0.0
	lat = 0.0
	grip = CarPhysics.GRIP
	drift_charge = 0.0
	turbo_time = 0.0
	boosting = false
	sliding = false
	braking = false
	_wheel_last = [null, null]
	for e in _sparks + _turbo_flames:
		e.emitting = false
	if _dust:
		_dust.emitting = false
	if _flame:
		_flame.emitting = false


## Repair Kit: knocks out most of the dents.
func repair(amount: float = REPAIR_AMOUNT) -> void:
	damage = maxf(0.0, damage - amount)


func has_part(id: String) -> bool:
	return id in parts


func install_part(id: String) -> bool:
	if not PARTS.has(id) or id in parts:
		return false
	parts.append(id)
	_show_part(id)
	return true


func set_parts(list: Array) -> void:
	for id in list:
		install_part(str(id))


func _show_part(id: String) -> void:
	if _part_nodes.has(id):
		return
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	match id:
		"turbo_engine":
			mat.albedo_color = Color(0.75, 0.2, 0.15)
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(0.9, 0.3, 0.8)
			b.mesh = bm; b.material_override = mat; b.position = Vector3(0, 1.25, 1.3)
			root.add_child(b)
			for x in [-0.25, 0.25]:
				var pipe := MeshInstance3D.new()
				var cm := CylinderMesh.new(); cm.top_radius = 0.1; cm.bottom_radius = 0.1; cm.height = 0.5
				pipe.mesh = cm; pipe.material_override = mat
				pipe.position = Vector3(x, 1.5, 1.3)
				root.add_child(pipe)
		"offroad_wheels":
			for w in _wheels:
				(w["pivot"] as Node3D).scale = Vector3(1.25, 1.4, 1.4)
		"bull_bar":
			mat.albedo_color = Color(0.8, 0.82, 0.86)
			mat.metallic = 0.7
			mat.roughness = 0.35
			for bar in [[Vector3(2.0, 0.13, 0.13), Vector3(0, 0.62, 2.28)], [Vector3(2.0, 0.13, 0.13), Vector3(0, 0.25, 2.3)],
					[Vector3(0.13, 0.62, 0.13), Vector3(-0.55, 0.42, 2.3)], [Vector3(0.13, 0.62, 0.13), Vector3(0.55, 0.42, 2.3)],
					[Vector3(0.1, 0.1, 0.4), Vector3(-0.55, 0.3, 2.1)], [Vector3(0.1, 0.1, 0.4), Vector3(0.55, 0.3, 2.1)]]:
				var m := MeshInstance3D.new()
				var bm := BoxMesh.new(); bm.size = bar[0]
				m.mesh = bm; m.material_override = mat; m.position = bar[1]
				root.add_child(m)
		"drift_tyres":
			# Hot-pink hubcaps, obviously the secret to sliding.
			mat.albedo_color = Color(1.0, 0.25, 0.65)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.15, 0.55)
			mat.emission_energy_multiplier = 0.5
			for w in _wheels:
				var spin := w["spin"] as Node3D
				var side := signf((w["pivot"] as Node3D).position.x)
				for ang in [0.0, PI / 2.0]:
					var m := MeshInstance3D.new()
					var bm := BoxMesh.new(); bm.size = Vector3(0.04, 0.34, 0.08)
					m.mesh = bm; m.material_override = mat
					m.position = Vector3(side * 0.15, 0, 0)
					m.rotation.x = ang
					spin.add_child(m)
		"rocket_booster":
			mat.albedo_color = Color(0.7, 0.72, 0.8)
			mat.metallic = 0.6
			var n := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.3; cm.bottom_radius = 0.45; cm.height = 0.9
			n.mesh = cm; n.material_override = mat
			n.rotation.x = -PI / 2.0
			n.position = Vector3(0, 0.9, -2.3)
			root.add_child(n)
			_add_flame()
	if _chassis != null:
		_chassis.add_child(root)
	else:
		add_child(root)
	_part_nodes[id] = root


func _add_flame() -> void:
	_flame = CPUParticles3D.new()
	_flame.position = Vector3(0, 0.9, -2.9)
	_flame.amount = 30
	_flame.lifetime = 0.45
	_flame.emitting = false
	_flame.direction = Vector3(0, 0, -1)
	_flame.spread = 12.0
	_flame.initial_velocity_min = 5.0
	_flame.initial_velocity_max = 8.0
	_flame.gravity = Vector3.ZERO
	var m := SphereMesh.new()
	m.radius = 0.2
	m.height = 0.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	_flame.mesh = m
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_flame.scale_amount_curve = curve
	(_chassis if _chassis != null else self as Node3D).add_child(_flame)


## One physics frame of driving. steer_input +1 turns right on screen, -1 left.
func drive(delta: float, throttle: float, steer_input: float, handbrake: bool, want_boost: bool = false) -> void:
	var st := stats_for(parts)
	var slick := has_part("drift_tyres")
	var bs := boost_step(boost, want_boost and throttle > 0.0, has_part("rocket_booster"), delta)
	boost = bs["fuel"]
	boosting = bs["active"]
	if _flame:
		_flame.emitting = boosting
	var wear := CarPhysics.speed_mult(damage)
	var top: float = st["max_speed"] * (st["boost"] if boosting else 1.0) * wear
	var acc: float = st["accel"] * (2.0 if boosting else 1.0) * lerpf(1.0, wear, 0.5)
	if turbo_time > 0.0:
		turbo_time = maxf(0.0, turbo_time - delta)
		top += _turbo_kick
	var drift_wanted := CarPhysics.wants_drift(speed, steer_input, handbrake) or (handbrake and sliding)
	var before := speed
	if drift_wanted:
		# Sliding only scrubs a little speed, and the throttle can hold it.
		speed = move_toward(speed, 0.0, CarPhysics.DRIFT_DRAG * delta)
		if throttle > 0.0 and speed < top:
			speed = minf(top, speed + acc * 0.45 * throttle * delta)
	else:
		speed = step_speed(speed, throttle, handbrake, delta, maxf(top, absf(speed)), acc)
	if speed > top:
		speed = move_toward(speed, top, 7.0 * delta)   # ease out of boosts instead of snapping
	braking = (handbrake and absf(speed) > 0.3) or (throttle < -0.01 and speed > 0.5)
	_accel = lerpf(_accel, (speed - before) / maxf(delta, 0.001), minf(1.0, 14.0 * delta))

	var dh: float = turn_delta(speed, steer_input, delta) * st["steer"] * (CarPhysics.DRIFT_YAW if drift_wanted else 1.0)
	grip = CarPhysics.grip_step(grip, drift_wanted, slick, delta)
	lat = CarPhysics.slip_step(lat, speed, dh, grip, delta)
	heading += dh
	yaw_rate = dh / maxf(delta, 0.001)
	_steer_vis = move_toward(_steer_vis, -clampf(steer_input, -1.0, 1.0) * 0.45, 3.5 * delta)
	rotation.y = heading

	sliding = CarPhysics.is_sliding(lat, speed)
	_update_drift_turbo(delta, drift_wanted, slick)

	var fwd := Vector3(sin(heading), 0, cos(heading))
	var left := Vector3(cos(heading), 0, -sin(heading))
	var flat := fwd * speed + left * lat
	var vy := velocity.y
	velocity = flat
	velocity.y = vy - 20.0 * delta if not is_on_floor() else -1.0
	_knock_props()
	var pre := Vector2(velocity.x, velocity.z)
	move_and_slide()
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	_handle_hits(pre, delta, st["bump"])
	_update_trails(delta, handbrake, steer_input)


func _update_drift_turbo(delta: float, drift_wanted: bool, slick: bool) -> void:
	if drift_wanted:
		drift_charge = CarPhysics.charge_step(drift_charge, sliding, lat, slick, delta)
	elif drift_charge > 0.0:
		release_drift()
	var tier := CarPhysics.tier_for(drift_charge)
	for e in _sparks:
		e.emitting = tier > 0
		e.color = Color(1.0, 0.55, 0.1) if tier == 2 else Color(0.35, 0.75, 1.0)
	for e in _turbo_flames:
		e.emitting = turbo_time > 0.0
		e.color = Color(1.0, 0.55, 0.1) if _turbo_kick >= CarPhysics.TURBO_KICK[2] else Color(0.35, 0.75, 1.0)


## Letting go of a charged drift fires a mini turbo. Returns the tier that fired (0 = none).
func release_drift() -> int:
	var tier := CarPhysics.tier_for(drift_charge)
	drift_charge = 0.0
	if tier > 0 and speed > 3.0:
		_turbo_kick = CarPhysics.TURBO_KICK[tier]
		turbo_time = CarPhysics.TURBO_TIME[tier]
		speed += _turbo_kick
		_heave.y -= 0.5
		_pitch.y -= 0.7
		Sfx.play_on(self, "turbo", 1.0 if tier == 1 else 1.3)
		return tier
	return 0


## Clip any cone, fence, mailbox, bale or crate in front of the bumper before we collide with it.
func _knock_props() -> void:
	if absf(speed) < KnockProp.MIN_KNOCK_SPEED or not is_inside_tree():
		return
	var bull := has_part("bull_bar")
	for n in get_tree().get_nodes_in_group("knockable"):
		var kp := n as KnockProp
		if kp.knocked or not CarPhysics.in_bumper_zone(global_position, heading, speed, kp.global_position, 0.45):
			continue
		kp.knock(CarPhysics.launch_velocity(velocity, kp.global_position - global_position, bull), self)
		_heave.y += 0.35
		speed *= 1.0 - minf(0.12, kp.mass * 0.012) * (0.4 if bull else 1.0)
		bumped_prop.emit()
	for n in get_tree().get_nodes_in_group("smashable"):
		var cr := n as PropCrate
		if cr == null or absf(speed) < 4.0 or not CarPhysics.in_bumper_zone(global_position, heading, speed, cr.global_position, 0.3):
			continue
		cr.linear_velocity = CarPhysics.launch_velocity(velocity, cr.global_position - global_position, bull) * 0.8
		if absf(speed) > 9.0:
			cr.smash_hit()
			cr.smash_hit()


## Walls bounce you and dent the car; glancing blows scrape along. The ground never counts.
func _handle_hits(pre: Vector2, delta: float, bounce: float) -> void:
	var worst := 0.0
	var normal := Vector2.ZERO
	var at := Vector3.ZERO
	var other: Object = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.6:
			continue
		var n2 := Vector2(n.x, n.z).normalized()
		var hit := CarPhysics.impact_speed(pre, n2)
		if hit >= worst:
			worst = hit
			normal = n2
			at = c.get_position()
			other = c.get_collider()
	if normal == Vector2.ZERO:
		return
	if worst < CarPhysics.SCRAPE_IMPACT:
		if absf(speed) > 5.0:
			speed = move_toward(speed, 0.0, 5.0 * delta)
			if _hit_cooldown <= 0.0:
				_hit_cooldown = 0.12
				FX.burst(self, at + Vector3(0, 0.1, 0), Color(1.0, 0.8, 0.25), 5, 0.05, 3.5, -12.0, "box", 70.0, true)
		return
	if other is RigidBody3D and not (other as RigidBody3D).freeze:
		(other as RigidBody3D).apply_central_impulse(Vector3(-normal.x, 0.25, -normal.y) * worst * minf((other as RigidBody3D).mass, 20.0) * 0.5)
	var out := CarPhysics.bounce_velocity(pre, normal, 0.15 + bounce * 0.5, 0.8)
	var fwd := Vector2(sin(heading), cos(heading))
	var left := Vector2(cos(heading), -sin(heading))
	speed = out.dot(fwd)
	lat = out.dot(left)
	drift_charge = 0.0
	turbo_time = 0.0
	if _hit_cooldown > 0.0:
		return
	_hit_cooldown = 0.35
	crash(worst, at)


## The comedy part of a collision: jolt, sparks, noise and (when hard) a dent.
func crash(impact: float, at: Vector3) -> void:
	last_impact = impact
	var dent := CarPhysics.damage_for(impact, has_part("bull_bar"))
	var was := CarPhysics.smoke_stage(damage)
	damage = minf(CarPhysics.MAX_DAMAGE, damage + dent)
	_heave.y += clampf(impact * 0.12, 0.2, 1.6)
	_pitch.y += clampf(impact * 0.1, 0.2, 1.3) * (1.0 if speed <= 0.0 else -1.0)
	_roll.y += randf_range(-0.8, 0.8)
	FX.burst(self, at + Vector3(0, 0.3, 0), Color(1.0, 0.8, 0.25), int(clampf(impact * 2.0, 6, 26)), 0.07, 5.0, -12.0, "box", 80.0, true)
	if dent > 0.0:
		FX.burst(self, at + Vector3(0, 0.5, 0), Color(0.42, 0.6, 0.85), 7, 0.16, 4.0, -9.0, "box", 70.0)
		Sfx.play_on(self, "crunch", 0.9 + randf() * 0.2)
		FX.hit_stop(get_tree(), clampf(impact / 20.0, 0.2, 0.8))
	bumped.emit()
	if CarPhysics.smoke_stage(damage) > was:
		smoke_started.emit(CarPhysics.smoke_stage(damage))


## Skid marks, tyre smoke / dirt spray and the screech.
func _update_trails(delta: float, handbrake: bool, steer_input: float) -> void:
	_screech_cd = maxf(0.0, _screech_cd - delta)
	var here := global_position
	var road := CarPhysics.road_height(here.x, here.z)
	var hard_stop := handbrake and absf(speed) > 7.0
	var marking := is_on_floor() and (sliding or hard_stop)
	if skids != null:
		var left := Vector3(cos(heading), 0, -sin(heading))
		var fwd := Vector3(sin(heading), 0, cos(heading))
		for i in 2:
			var w := here - fwd * 1.13 + left * (0.78 if i == 0 else -0.78)
			w.y = Terrain.height_at(w.x, w.z) + CarPhysics.road_height(w.x, w.z) + 0.025 + i * 0.002
			if marking and _wheel_last[i] != null:
				if (w - (_wheel_last[i] as Vector3)).length() < 0.22:
					continue   # wait until the strip is long enough to be worth a quad
				skids.add_segment(_wheel_last[i], w, SkidMarks.RUBBER if road > 0.0 else SkidMarks.DIRT)
			_wheel_last[i] = w if marking else null
	var amount := 1.0 if sliding else dust_amount(speed, handbrake, steer_input)
	if _dust:
		_dust.position.y = 0.2 + road
		_dust.emitting = amount > 0.0
		var mat := (_dust.mesh as SphereMesh).material as StandardMaterial3D
		mat.albedo_color = Color(0.93, 0.93, 0.96, 0.5) if road > 0.0 else Color(0.78, 0.66, 0.48, 0.6)
	if marking and _screech_cd <= 0.0:
		_screech_cd = 0.17
		Sfx.play_on(self, "skid" if road > 0.0 else "rustle", 0.85 + randf() * 0.3)


func exit_position() -> Vector3:
	var side := Vector3(cos(heading), 0, -sin(heading))
	return global_position + side * 2.4 + Vector3(0, 0.3, 0)


## Door handle: lets the shared E-key interaction find the car.
class CarSeat extends Interactable:
	var car: Car

	func get_prompt(_game: GameState) -> String:
		var np := next_part(_game)
		if np != "":
			return "[E] Bolt on %s" % Car.PARTS[np]["name"]
		if can_repair(_game):
			return "[E] Hammer out the dents (Repair Kit) - car is %s" % CarPhysics.condition_text(car.damage)
		return "[E] Hop in and drive (WASD, Space + steer = drift%s)%s" % [", Shift = boost" if car.has_part("rocket_booster") else "",
			"  [%s: craft a Repair Kit]" % CarPhysics.condition_text(car.damage) if car.damage > 0.04 else ""]

	func can_repair(g: GameState) -> bool:
		return car.damage > 0.04 and g.count("repair_kit") > 0

	func next_part(g: GameState) -> String:
		for id in Car.PARTS:
			if g.count(id) > 0 and not car.has_part(id):
				return id
		return ""

	func interact(_game: GameState) -> void:
		var np := next_part(_game)
		if np != "":
			_game.remove_item(np, 1)
			car.install_part(np)
			_game.car_parts = car.parts.duplicate()
			_game.say("Bolted on the %s. Warranty void." % Car.PARTS[np]["name"])
			Sfx.play_on(car, "thud", 1.3)
			return
		if can_repair(_game):
			_game.remove_item("repair_kit", 1)
			car.repair()
			_game.car_damage = car.damage
			_game.say("Bonk, bonk, tape. Good as %s." % ("new" if car.damage <= 0.04 else "almost-new"))
			Sfx.play_on(car, "clang", 1.0)
			FX.burst(car, car.global_position + Vector3(0, 1.4, 0), Color(1.0, 0.9, 0.4), 18, 0.08, 3.5, -6.0, "box", 90.0, true)
			return
		var p = get_tree().get_first_node_in_group("player")
		if p:
			p.enter_car(car)
