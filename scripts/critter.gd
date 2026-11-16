class_name Critter
extends Interactable
## Wandering animals and flying things built from simple cartoon shapes.
## Chickens and the goat can be petted. Butterflies and birds only come out by day.

enum Kind { CHICKEN, GOAT, BUTTERFLY, BIRD }

@export var kind: int = Kind.CHICKEN
var home: Vector3
var roam: float = 3.0

var _body: Node3D
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _target: Vector3
var _wait: float = 0.0
var _t: float = 0.0
var _speed: float = 1.0
var _phase: float = 0.0

const PET_LINES := {
	Kind.CHICKEN: ["The chicken accepts your offering of pats.", "Bawk. (That means thanks.)", "The chicken judges your farming. Gently."],
	Kind.GOAT: ["The goat is the 13th citizen. It knows.", "The goat eats your sleeve. Bonding!", "Mehhh. (The goat approves.)"],
}


func _ready() -> void:
	home = position
	_target = position
	_phase = randf() * TAU
	_body = Node3D.new()
	add_child(_body)
	match kind:
		Kind.CHICKEN:
			_build_chicken()
			_speed = 1.2
			interact_radius = 1.2
		Kind.GOAT:
			_build_goat()
			_speed = 1.0
			interact_radius = 1.7
		Kind.BUTTERFLY:
			_build_butterfly()
			_speed = 1.5
			remove_from_group("interactable")
		Kind.BIRD:
			_build_bird()
			_speed = 9.0
			remove_from_group("interactable")


func get_prompt(_game: GameState) -> String:
	if kind == Kind.CHICKEN:
		return "[E] Pet the chicken"
	if kind == Kind.GOAT:
		return "[E] Pet the goat"
	return ""


func interact(game: GameState) -> void:
	var lines: Array = PET_LINES.get(kind, [])
	if lines.size() > 0:
		game.say(lines[randi() % lines.size()])
		FX.burst(self, global_position + Vector3(0, 1.0, 0), Color(1, 0.45, 0.6), 6, 0.14, 1.5, -1.0, "sphere")
		_wait = 1.5


# ---------------------------------------------------------------- shapes

func _part(mesh: MeshInstance3D, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	mesh.position = pos
	(parent if parent else _body).add_child(mesh)
	return mesh


func _build_chicken() -> void:
	_part(Art.sphere(0.22, Color(0.98, 0.97, 0.92)), Vector3(0, 0.32, 0)).scale = Vector3(1, 0.9, 1.25)
	_part(Art.sphere(0.13, Color(0.98, 0.97, 0.92)), Vector3(0, 0.55, 0.18))
	_part(Art.box(Vector3(0.05, 0.09, 0.12), Color(0.9, 0.15, 0.15)), Vector3(0, 0.7, 0.18))
	_part(Art.box(Vector3(0.07, 0.05, 0.1), Color(1.0, 0.65, 0.15)), Vector3(0, 0.54, 0.32))
	_part(Art.box(Vector3(0.12, 0.14, 0.06), Color(0.95, 0.94, 0.88)), Vector3(0, 0.42, -0.26)).rotation.x = -0.5
	for x in [-0.07, 0.07]:
		var leg := Node3D.new()
		leg.position = Vector3(x, 0.2, 0)
		_body.add_child(leg)
		_part(Art.box(Vector3(0.03, 0.2, 0.03), Color(1.0, 0.65, 0.15)), Vector3(0, -0.1, 0), leg)
		_legs.append(leg)


func _build_goat() -> void:
	var white := Color(0.93, 0.9, 0.84)
	_part(Art.box(Vector3(0.45, 0.42, 0.85), white), Vector3(0, 0.72, 0))
	var head := Node3D.new()
	head.position = Vector3(0, 1.0, 0.48)
	_body.add_child(head)
	_part(Art.box(Vector3(0.26, 0.3, 0.36), white), Vector3(0, 0, 0.08), head)
	_part(Art.box(Vector3(0.05, 0.16, 0.05), Color(0.45, 0.4, 0.35)), Vector3(-0.08, 0.2, -0.02), head).rotation.x = -0.5
	_part(Art.box(Vector3(0.05, 0.16, 0.05), Color(0.45, 0.4, 0.35)), Vector3(0.08, 0.2, -0.02), head).rotation.x = -0.5
	_part(Art.box(Vector3(0.08, 0.14, 0.06), white.darkened(0.1)), Vector3(0, -0.2, 0.2), head)  # beard
	_part(Art.sphere(0.03, Color(0.1, 0.1, 0.1)), Vector3(-0.1, 0.06, 0.26), head)
	_part(Art.sphere(0.03, Color(0.1, 0.1, 0.1)), Vector3(0.1, 0.06, 0.26), head)
	for p in [Vector2(-0.15, 0.3), Vector2(0.15, 0.3), Vector2(-0.15, -0.3), Vector2(0.15, -0.3)]:
		var leg := Node3D.new()
		leg.position = Vector3(p.x, 0.52, p.y)
		_body.add_child(leg)
		_part(Art.box(Vector3(0.09, 0.52, 0.09), white.darkened(0.15)), Vector3(0, -0.26, 0), leg)
		_legs.append(leg)


func _build_butterfly() -> void:
	var c: Color = [Color(1.0, 0.55, 0.15), Color(0.95, 0.9, 0.25), Color(0.55, 0.75, 1.0), Color(1.0, 0.5, 0.8)][randi() % 4]
	_part(Art.box(Vector3(0.03, 0.03, 0.14), Color(0.15, 0.12, 0.1)), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		_body.add_child(hinge)
		var w := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.01, 0.14)
		w.mesh = bm
		w.material_override = Toon.color(c, false, false)
		w.position = Vector3(0.08 * side, 0, 0)
		hinge.add_child(w)
		hinge.set_meta("side", side)
		_wings.append(hinge)
	_body.scale = Vector3.ONE * 1.3


func _build_bird() -> void:
	_part(Art.box(Vector3(0.12, 0.1, 0.4), Color(0.25, 0.25, 0.3)), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		_body.add_child(hinge)
		var w := Art.box(Vector3(0.5, 0.03, 0.18), Color(0.3, 0.3, 0.36))
		w.position = Vector3(0.25 * side, 0, 0)
		hinge.add_child(w)
		hinge.set_meta("side", side)
		_wings.append(hinge)
	_body.scale = Vector3.ONE * 1.6


# ---------------------------------------------------------------- behaviour

func _process(delta: float) -> void:
	_t += delta
	match kind:
		Kind.CHICKEN, Kind.GOAT:
			_walk(delta)
		Kind.BUTTERFLY:
			_flutter(delta)
		Kind.BIRD:
			_circle(delta)


func _walk(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		for leg in _legs:
			leg.rotation.x = lerp(leg.rotation.x, 0.0, 8.0 * delta)
		# Chickens peck while they wait.
		if kind == Kind.CHICKEN:
			_body.rotation.x = max(0.0, sin(_t * 9.0)) * 0.5 if int(_t) % 3 == 0 else 0.0
		return
	_body.rotation.x = 0.0
	var to := _target - position
	to.y = 0
	if to.length() < 0.2:
		_wait = randf_range(1.0, 4.0)
		var a := randf() * TAU
		var r := randf() * roam
		_target = home + Vector3(cos(a) * r, 0, sin(a) * r)
		return
	var step := to.normalized() * _speed * delta
	position += step
	position.y = Terrain.height_at(position.x, position.z)
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 6.0 * delta)
	var swing := sin(_t * _speed * 9.0) * 0.6
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 2 == 0 else -1.0) * (1.0 if i < 2 else -1.0)
	_body.position.y = abs(sin(_t * _speed * 9.0)) * 0.04


func _flutter(delta: float) -> void:
	var a := _t * 0.6 + _phase
	var target := home + Vector3(sin(a) * roam, 0.8 + sin(_t * 1.7 + _phase) * 0.35, cos(a * 1.3) * roam)
	var prev := position
	position = position.lerp(target, 1.5 * delta)
	var v := position - prev
	if v.length() > 0.0005:
		rotation.y = atan2(v.x, v.z)
	for w in _wings:
		w.rotation.z = sin(_t * 22.0) * 1.1 * float(w.get_meta("side"))


func _circle(delta: float) -> void:
	var a := _t * _speed / roam + _phase
	var prev := position
	position = home + Vector3(cos(a) * roam, sin(_t * 0.5 + _phase) * 1.5, sin(a) * roam)
	var v := position - prev
	if v.length() > 0.0001:
		rotation.y = atan2(v.x, v.z)
	rotation.z = 0.25
	var flap := 0.0
	if fmod(_t + _phase, 3.0) < 1.2:
		flap = sin(_t * 14.0) * 0.6
	for w in _wings:
		w.rotation.z = flap * float(w.get_meta("side"))
