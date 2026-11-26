class_name GiantCrop
extends Interactable
## An enormous vegetable still rooted across four plots. Heave on it a few times to tear it free.

const TUGS := 3
const SCALE := 4.2

var crop := "turnip"
var block: Array = []
var tugs := 0
var field: FarmField
var _body: Node3D
var _solid: StaticBody3D


func _ready() -> void:
	interact_radius = 2.3
	_body = Node3D.new()
	add_child(_body)
	var veg := CropModel.produce(crop)
	veg.scale = Vector3.ONE * SCALE
	_body.add_child(veg)
	_solid = StaticBody3D.new()
	var solid := _solid
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.8
	sh.height = 1.1
	cs.shape = sh
	cs.position.y = 0.55
	solid.add_child(cs)
	add_child(solid)
	var tag := Art.label("GIANT %s!" % crop.to_upper(), 52, Color(1.0, 0.95, 0.55))
	tag.position.y = 2.35
	add_child(tag)
	var sp := FX.emitter(self, Color(1.0, 0.94, 0.55), 10, 1.6, 0.06, Vector3(1.1, 0.5, 1.1), Vector3(0, 0.35, 0), true, "sphere")
	sp.position.y = 0.9
	sit()


## Pure (tested): how far out of the ground the centre sits after `n` tugs (starts half buried).
static func rise(n: int) -> float:
	return 0.34 + 0.2 * n


func sit() -> void:
	if _body != null:
		_body.position.y = rise(tugs)


## Switch the rooted collider off right away, so the loose ball is not spawned inside it
## (the physics engine would fire it into the sky).
func drop_collider() -> void:
	if _solid != null:
		_solid.collision_layer = 0
		_solid.collision_mask = 0
		for c in _solid.get_children():
			(c as CollisionShape3D).disabled = true


## Morning surprise: it heaves up out of the soil.
func arrive() -> void:
	if _body == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	_body.scale = Vector3.ONE * 0.25
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3.ONE, 1.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func get_prompt(_game: GameState) -> String:
	return "[E] Heave! (%d/%d)  Giant %s" % [tugs, TUGS, crop]


func interact(game: GameState) -> void:
	if tugs >= TUGS:
		return
	tugs += 1
	game.shake.emit(0.15 + 0.1 * tugs)
	if is_inside_tree():
		Sfx.play_on(self, "thud", 1.25 - 0.18 * tugs)
		Sfx.play_on(self, "rustle", 0.55)
		FX.burst(self, global_position + Vector3(0, 0.15, 0), Art.DIRT, 14 + 8 * tugs, 0.14, 2.6 + tugs)
	if tugs < TUGS:
		sit()
		if is_inside_tree() and DisplayServer.get_name() != "headless":
			_body.scale = Vector3(0.88, 1.2, 0.88)
			_body.rotation.z = 0.14 * (1 if tugs % 2 == 0 else -1)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(_body, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_body, "rotation:z", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		game.say("Hnnngh! It budged." if tugs == 1 else "HNNNNGH! One more!")
		return
	game.say("POP! It's loose! Roll it to the SELL BIN for a weigh-in, or chop it with the Axe.")
	FX.hit_stop(get_tree() if is_inside_tree() else null, 0.7)
	var ball := field.uproot(self, game)
	ball.launch(Vector3(0, 4.5, 1.0))
