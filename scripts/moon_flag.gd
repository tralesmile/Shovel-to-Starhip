class_name MoonFlag
extends Interactable
## The spot by the lander where you plant your flag, in your starship's paint colour.
## No air up here, so the cloth only waves when you give the pole a good twang.

var cloth: MeshInstance3D
var planted := false
var _pole: Node3D
var _marker: Node3D
var _twang := 0.0
var _t := 0.0


func _ready() -> void:
	interact_radius = 1.7
	_marker = Node3D.new()
	add_child(_marker)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.52
	ring.mesh = tm
	ring.material_override = Art.mat(Color(1.0, 0.82, 0.25), true)
	ring.position.y = 0.06
	_marker.add_child(ring)
	_pole = Node3D.new()
	add_child(_pole)
	var rod := Art.cylinder(0.045, 0.045, 2.5, Color(0.85, 0.87, 0.92), 8)
	rod.position.y = 1.25
	_pole.add_child(rod)
	var arm := Art.cylinder(0.025, 0.025, 1.25, Color(0.85, 0.87, 0.92), 6)
	arm.rotation.z = PI / 2
	arm.position = Vector3(0.6, 2.46, 0)
	_pole.add_child(arm)
	var bm := BoxMesh.new()
	bm.size = Vector3(1.15, 0.72, 0.04)
	cloth = MeshInstance3D.new()
	cloth.mesh = bm
	cloth.position = Vector3(0.62, 2.06, 0)
	_pole.add_child(cloth)
	var emblem := Art.sphere(0.17, Color(0.95, 0.9, 1.0), 6, 10)
	emblem.scale = Vector3(1.0, 1.0, 0.25)
	emblem.position = Vector3(0.62, 2.03, 0.04)
	_pole.add_child(emblem)
	var leaf := Art.sphere(0.07, Color(0.35, 0.8, 0.3), 4, 8)
	leaf.scale = Vector3(0.6, 1.5, 0.3)
	leaf.position = Vector3(0.62, 2.24, 0.045)
	_pole.add_child(leaf)
	set_planted(false)


func set_planted(on: bool) -> void:
	planted = on
	if _pole != null:
		_pole.visible = on
		_marker.visible = not on


func set_paint(c: Color) -> void:
	if cloth != null:
		cloth.material_override = Art.mat(c)


func get_prompt(_game: GameState) -> String:
	return "[E] Twang your flag" if planted else "[E] Plant your flag"


func interact(game: GameState) -> void:
	_twang = 1.0
	if planted:
		Sfx.play_on(self, "boing", 1.5)
		return
	set_planted(true)
	game.moon_flag = true
	set_paint(StarshipDesign.paint_color(game.ship_design))
	_pole.position.y = 1.4
	var tw := create_tween()
	tw.tween_property(_pole, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		FX.burst(self, global_position + Vector3(0, 0.1, 0), Color(0.72, 0.72, 0.76), 18, 0.14, 2.6, -2.2, "sphere", 80.0)
		Sfx.play_on(self, "thud", 1.2)
		Sfx.play_on(self, "fanfare")
		game.shake.emit(0.3))
	game.say("One small step for a farmer. One giant leap for turnips.")


func _process(delta: float) -> void:
	_t += delta
	if _marker != null and _marker.visible:
		_marker.rotation.y += delta
	_twang = maxf(0.0, _twang - delta * 0.45)
	if cloth != null:
		cloth.rotation.y = sin(_t * 9.0) * 0.45 * _twang
		_pole.rotation.z = sin(_t * 13.0) * 0.07 * _twang
