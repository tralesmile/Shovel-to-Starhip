class_name DresserModel
extends Node3D
## A chest of drawers you can read at a glance: it rattles while being picked,
## the top drawer slides open with a bounce, and the loot leaps out, spins and
## flies into your pockets. Purely visual; LootContainer owns the rules.

const W := 1.0
const H := 0.9
const D := 0.5
const SLIDE := 0.34

var drawers: Array[Node3D] = []
var _jiggle := 0.0
var _t := 0.0
var _body: Node3D


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var wood := Art.WOOD.darkened(0.22)
	var carcass := Art.box(Vector3(W, H - 0.1, D - 0.04), wood)
	carcass.position = Vector3(0, H / 2.0 + 0.04, -0.02)
	_body.add_child(carcass)
	var top := Art.box(Vector3(W + 0.12, 0.07, D + 0.08), Art.WOOD.darkened(0.05))
	top.position.y = H + 0.02
	_body.add_child(top)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var foot := Art.cylinder(0.05, 0.035, 0.1, wood.darkened(0.2), 6)
			foot.position = Vector3(sx * (W / 2.0 - 0.08), 0.05, sz * (D / 2.0 - 0.08))
			_body.add_child(foot)
	for i in 3:
		var d := Node3D.new()
		d.position = Vector3(0, 0.72 - i * 0.25, D / 2.0 - 0.02)
		_body.add_child(d)
		var front := Art.box(Vector3(W - 0.1, 0.21, 0.05), Art.WOOD.lightened(0.06))
		d.add_child(front)
		for sx in [-1.0, 1.0]:
			var knob := Art.sphere(0.032, LootModel.GOLD)
			knob.position = Vector3(sx * 0.27, 0, 0.045)
			d.add_child(knob)
		if i == 0:
			var plate := Art.cylinder(0.055, 0.055, 0.02, LootModel.GOLD, 12)
			plate.rotation.x = PI / 2.0
			plate.position.z = 0.032
			d.add_child(plate)
			var hole := Art.box(Vector3(0.018, 0.055, 0.012), Color(0.08, 0.05, 0.03))
			hole.position.z = 0.046
			d.add_child(hole)
			# Tray behind the front so the open drawer is not a floating plank.
			var tray := Art.box(Vector3(W - 0.18, 0.03, SLIDE), wood.darkened(0.3))
			tray.position = Vector3(0, -0.08, -SLIDE / 2.0)
			d.add_child(tray)
			for sx in [-1.0, 1.0]:
				var side := Art.box(Vector3(0.03, 0.14, SLIDE), wood)
				side.position = Vector3(sx * (W / 2.0 - 0.09), -0.02, -SLIDE / 2.0)
				d.add_child(side)
		drawers.append(d)
	# A doily and a candlestick: valuables deserve a throne.
	var doily := Art.cylinder(0.2, 0.2, 0.012, Color(0.98, 0.95, 0.9), 14)
	doily.position = Vector3(-0.22, H + 0.062, 0)
	_body.add_child(doily)
	var stick := Art.cylinder(0.025, 0.06, 0.18, LootModel.GOLD, 8)
	stick.position = Vector3(-0.22, H + 0.15, 0)
	_body.add_child(stick)
	var flame := Art.sphere(0.035, Color(1.0, 0.7, 0.2))
	flame.material_override = Art.mat(Color(1.0, 0.7, 0.2), true)
	flame.scale = Vector3(0.7, 1.4, 0.7)
	flame.position = Vector3(-0.22, H + 0.29, 0)
	_body.add_child(flame)


func jiggle(strength: float) -> void:
	_jiggle = maxf(_jiggle, strength)


func _process(delta: float) -> void:
	_t += delta
	_jiggle = maxf(0.0, _jiggle - delta * 2.6)
	_body.rotation.z = sin(_t * 46.0) * 0.045 * _jiggle
	_body.position.x = sin(_t * 61.0) * 0.015 * _jiggle


func open_with(loot_id: String) -> void:
	var tw := create_tween()
	tw.tween_property(drawers[0], "position:z", D / 2.0 - 0.02 + SLIDE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_pop_loot.bind(loot_id))


func close() -> void:
	if not drawers.is_empty():
		drawers[0].position.z = D / 2.0 - 0.02


func _pop_loot(loot_id: String) -> void:
	var item := LootModel.make(loot_id)
	add_child(item)
	item.position = Vector3(0, 0.75, D / 2.0 + SLIDE * 0.6)
	item.scale = Vector3.ONE * 0.3
	FX.burst(self, item.global_position, Color(1.0, 0.85, 0.3), 18, 0.06, 2.6, -4.0, "sphere", 80.0)
	var tw := item.create_tween()
	tw.set_parallel(true)
	tw.tween_property(item, "position:y", 1.65, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "scale", Vector3.ONE * 1.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "rotation:y", TAU * 2.0, 1.15)
	tw.chain().tween_interval(0.55)
	tw.chain().tween_method(_fly_to_player.bind(item, Vector3(0, 1.65, D / 2.0 + SLIDE * 0.6)), 0.0, 1.0, 0.28).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(item.queue_free)


func _fly_to_player(k: float, item: Node3D, from_local: Vector3) -> void:
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	var from := global_transform * from_local
	item.global_position = from.lerp(pl.global_position + Vector3(0, 1.0, 0), k)
	item.scale = Vector3.ONE * lerpf(1.5, 0.25, k)
