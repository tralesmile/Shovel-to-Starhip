class_name GranRocket
extends Node3D
## Gran's busted rocket: a landmark that visibly gets fixed as story acts complete.
## Stage 0 = leaning, smoking wreck; each act adds a part and straightens it; stage 5 = gleaming starship.

const STAGES := 5
var stage := 0
var _body: Node3D
var _parts: Array[Node3D] = []   ## _parts[i] becomes visible at stage i+1
var _smoke: CPUParticles3D
var _glow: OmniLight3D
var _t := 0.0


## Pure (tested): lean angle in radians for a stage (wreck leans ~0.35, finished stands straight).
static func lean_for(s: int) -> float:
	return 0.35 * (1.0 - clampf(float(s) / float(STAGES - 1), 0.0, 1.0))


## Pure (tested): smoke amount ratio for a stage (thick on the wreck, none when finished).
static func smoke_for(s: int) -> float:
	return clampf(1.0 - float(s) / float(STAGES), 0.0, 1.0)


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var hull := Art.cylinder(0.9, 1.1, 4.2, Color(0.85, 0.87, 0.92), 10)
	hull.position.y = 2.1
	_body.add_child(hull)
	var stripe := Art.cylinder(1.02, 1.05, 0.5, Color(0.9, 0.3, 0.25), 10)
	stripe.position.y = 1.2
	_body.add_child(stripe)
	_add_part(Art.cylinder(0.02, 0.9, 1.6, Color(0.9, 0.3, 0.25), 10), Vector3(0, 5.0, 0))   # nose cone
	_add_part(_fins(), Vector3.ZERO)
	var win := Art.sphere(0.4, Color(0.5, 0.85, 1.0), 6, 8)
	win.position = Vector3(0, 3.0, 0.8)
	win.scale = Vector3(1, 1, 0.5)
	_add_part(win, win.position)
	_add_part(Art.cylinder(0.5, 0.7, 0.6, Color(0.35, 0.35, 0.4), 8), Vector3(0, -0.1, 0))   # engine bell
	var star := Art.sphere(0.5, Color(1.0, 0.85, 0.3), 4, 6)
	_add_part(star, Vector3(0, 6.4, 0))
	_smoke = FX.emitter(_body, Color(0.4, 0.4, 0.42, 0.6), 14, 2.6, 0.3, Vector3(0.3, 0.05, 0.3), Vector3(0.1, 1.2, 0), false, "sphere")
	_smoke.position.y = 3.6
	_smoke.spread = 20
	_smoke.emitting = true
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.8, 0.4)
	_glow.omni_range = 9.0
	_glow.position.y = 1.0
	add_child(_glow)
	var l := Art.label("GRAN'S ROCKET\n(mostly a shed)", 80, Color(1.0, 0.9, 0.7))
	l.position = Vector3(0, 7.6, 0)
	l.visibility_range_end = 0.0
	add_child(l)
	var base := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shp := CylinderShape3D.new()
	shp.radius = 1.2
	shp.height = 5.0
	cs.shape = shp
	cs.position.y = 2.5
	base.add_child(cs)
	add_child(base)
	var g: Node = get_tree().root.get_node_or_null("Game")
	if g != null:
		set_stage(int(g.get("story_act")), false)
		g.story_advanced.connect(func(a: int): set_stage(a, true))
	else:
		set_stage(0, false)


func _add_part(n: Node3D, pos: Vector3) -> void:
	n.position = pos
	_body.add_child(n)
	_parts.append(n)


func _fins() -> Node3D:
	var f := Node3D.new()
	for i in 3:
		var fin := Art.prism(Vector3(0.2, 1.6, 1.2), Color(0.9, 0.3, 0.25))
		var a := i * TAU / 3.0
		fin.position = Vector3(cos(a) * 1.15, 0.9, sin(a) * 1.15)
		fin.rotation.y = -a
		f.add_child(fin)
	return f


func set_stage(s: int, juice: bool) -> void:
	stage = clampi(s, 0, STAGES)
	for i in _parts.size():
		_parts[i].visible = stage > i
	_glow.visible = stage >= STAGES
	_glow.light_energy = 0.0 if stage < STAGES else 2.5
	_smoke.amount = maxi(1, int(14.0 * smoke_for(stage)))
	_smoke.emitting = stage < STAGES
	var target := lean_for(stage)
	if juice and is_inside_tree():
		FX.burst(self, global_position + Vector3(0, 3.0, 0), Color(1.0, 0.85, 0.3), 30, 0.18, 5.0, -4.0, "sphere", 180.0)
		var tw := create_tween()
		tw.tween_property(_body, "rotation:z", target, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_body.scale = Vector3(1.15, 0.85, 1.15)
		tw.parallel().tween_property(_body, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		_body.rotation.z = target


func _process(delta: float) -> void:
	_t += delta
	if stage >= STAGES:
		_glow.light_energy = 2.2 + 0.4 * sin(_t * 3.0)
