class_name ChoppableTree
extends Interactable
## A tree. Three axe hits drop 3 wood; the stump regrows after REGROW_DAYS.

const HITS_TO_FELL := 3
const WOOD_DROP := 3
const REGROW_DAYS := 2

var hits: int = 0
var felled: bool = false
var days_felled: int = 0

var _trunk: Node3D
var _stump: Node3D
var _wobble: float = 0.0
var _falling: bool = false
var _leaves: CPUParticles3D


func _ready() -> void:
	add_to_group("daily")
	add_to_group("saveable")
	interact_radius = 1.9
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = 1.0
	body.add_child(shape)
	add_child(body)

	var variant := "A" if absi(hash(str(name))) % 2 == 0 else "B"
	var size: float = 3.8 + (absi(hash(str(name))) % 5) * 0.25
	_trunk = Node3D.new()
	add_child(_trunk)
	Models.put(_trunk, Models.MED + "tree_single_%s.gltf" % variant, Vector3.ZERO, size, randf() * TAU)
	_stump = Models.put(self, Models.MED + "tree_single_%s_cut.gltf" % variant, Vector3.ZERO, size)
	_leaves = FX.emitter(self, Color(0.45, 0.62, 0.25), 3, 7.0, 0.12, Vector3(1.2, 0.6, 1.2), Vector3(0.3, -0.35, 0.1))
	_leaves.position.y = size * 0.75
	_refresh()


func _process(delta: float) -> void:
	if _wobble > 0.0:
		_wobble = max(0.0, _wobble - delta * 4.0)
		_trunk.rotation.z = sin(_wobble * 20.0) * 0.06 * _wobble


func get_prompt(game: GameState) -> String:
	if felled:
		return "A stump. It'll regrow in %d day(s)." % (REGROW_DAYS - days_felled)
	if game.current_tool == GameState.Tool.AXE:
		return "[E] Chop tree (%d/%d)" % [hits, HITS_TO_FELL]
	return "A tree. Use the Axe [4] for wood."


func interact(game: GameState) -> void:
	if felled:
		game.say("You pat the stump. Emotional support for stumps.")
		return
	if game.current_tool != GameState.Tool.AXE:
		game.say("You hug the tree. It doesn't hug back.")
		return
	hits += 1
	_wobble = 1.0
	Sfx.play_on(self, "chop")
	FX.burst(self, global_position + Vector3(0, 0.8, 0), Art.WOOD.lightened(0.25), 10, 0.1, 3.5)
	if hits >= HITS_TO_FELL:
		felled = true
		hits = 0
		days_felled = 0
		game.say("TIMBER! Grab the logs!")
		_fall(game)
	_refresh()


func _fall(game: GameState) -> void:
	if not is_inside_tree():
		return
	_falling = true
	var side := 1.0 if randf() < 0.5 else -1.0
	var tw := create_tween()
	tw.tween_property(_trunk, "rotation:z", side * PI * 0.5, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_spawn_logs(game, side)
		game.shake.emit(0.45)
		FX.burst(self, global_position + Vector3(side * 2.5, 0.3, 0), Color(0.45, 0.62, 0.25), 24, 0.16, 4.0, -6.0)
		FX.burst(self, global_position + Vector3(side * 2.5, 0.2, 0), Color(0.75, 0.68, 0.55), 16, 0.2, 2.0, -2.0, "sphere"))
	tw.tween_property(_trunk, "scale", Vector3.ONE * 0.01, 0.35).set_delay(0.25)
	tw.tween_callback(func():
		_falling = false
		_trunk.rotation.z = 0.0
		_trunk.scale = Vector3.ONE
		_refresh())


## Logs are real rigid bodies that tumble out where the trunk lands.
func _spawn_logs(game: GameState, side: float) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	for i in WOOD_DROP:
		var lg := WoodLog.new()
		lg.game = game
		host.add_child(lg)
		lg.global_position = global_position + Vector3(side * (1.2 + i * 0.9), 0.6 + i * 0.2, randf_range(-0.3, 0.3))
		lg.pop(Vector3(side * 1.5, 0, 0))


func on_new_day(_game: GameState) -> void:
	if felled:
		days_felled += 1
		if days_felled >= REGROW_DAYS:
			felled = false
			days_felled = 0
	_refresh()


func to_dict() -> Dictionary:
	return {"hits": hits, "felled": felled, "days_felled": days_felled}


func from_dict(d: Dictionary) -> void:
	hits = int(d.get("hits", 0))
	felled = bool(d.get("felled", false))
	days_felled = int(d.get("days_felled", 0))
	_refresh()


func _refresh() -> void:
	if _trunk == null:
		return
	_trunk.visible = not felled or _falling
	_stump.visible = felled
	_leaves.emitting = not felled
	# Collision only while standing.
	for c in get_children():
		if c is StaticBody3D:
			c.process_mode = Node.PROCESS_MODE_DISABLED if felled else Node.PROCESS_MODE_INHERIT
