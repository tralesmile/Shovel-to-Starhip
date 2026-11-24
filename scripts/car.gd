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
	_dust.position = Vector3(0, 0.2, -1.8)
	_dust.amount = 24
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
	Models.put(self, Models.CITY + "car_sedan.gltf", Vector3.ZERO, 4.4, 0.0)
	seat = CarSeat.new()
	seat.car = self
	seat.interact_radius = 3.2
	add_child(seat)
	_add_headlights()
	_add_dust()
	add_to_group("car")


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
			mat.albedo_color = Color(0.1, 0.1, 0.1)
			for x in [-1.05, 1.05]:
				for z in [-1.3, 1.3]:
					var w := MeshInstance3D.new()
					var cm := CylinderMesh.new(); cm.top_radius = 0.55; cm.bottom_radius = 0.55; cm.height = 0.4
					w.mesh = cm; w.material_override = mat
					w.rotation.z = PI / 2.0
					w.position = Vector3(x, 0.55, z)
					root.add_child(w)
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
	add_child(_flame)


func drive(delta: float, throttle: float, steer_input: float, handbrake: bool, want_boost: bool = false) -> void:
	var st := stats_for(parts)
	var bs := boost_step(boost, want_boost and throttle > 0.0, has_part("rocket_booster"), delta)
	boost = bs["fuel"]
	boosting = bs["active"]
	if _flame:
		_flame.emitting = boosting
	var top: float = st["max_speed"] * (st["boost"] if boosting else 1.0)
	var acc: float = st["accel"] * (2.0 if boosting else 1.0)
	speed = step_speed(speed, throttle, handbrake, delta, top, acc)
	if _dust:
		_dust.emitting = dust_amount(speed, handbrake, steer_input) > 0.0
	heading += turn_delta(speed, steer_input, delta) * st["steer"]
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
		speed *= st["bump"]
		bumped.emit()


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
		return "[E] Hop in and drive (WASD, Space = handbrake%s)" % [", Shift = boost" if car.has_part("rocket_booster") else ""]

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
		var p = get_tree().get_first_node_in_group("player")
		if p:
			p.enter_car(car)
