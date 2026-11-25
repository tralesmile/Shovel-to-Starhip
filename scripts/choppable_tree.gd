class_name ChoppableTree
extends Interactable
## A tree. Three axe hits (two with the copper axe) drop 3 wood; the stump regrows after REGROW_DAYS.

const HITS_TO_FELL := 3
const WOOD_DROP := 3


## Pure (tested): hits to fell; the copper axe saves a swing.
static func hits_needed(upgraded: bool) -> int:
	return HITS_TO_FELL - 1 if upgraded else HITS_TO_FELL

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
	if _wobble <= 0.0 and not felled and not _falling:
		# Gentle wind sway, phase offset per tree.
		var t := Time.get_ticks_msec() * 0.001
		_trunk.rotation.z = sin(t * 0.9 + float(absi(hash(str(name))) % 100)) * 0.012
		_trunk.rotation.x = sin(t * 0.7 + float(absi(hash(str(name))) % 37)) * 0.008
	if _wobble > 0.0:
		_wobble = max(0.0, _wobble - delta * 4.0)
		_trunk.rotation.z = sin(_wobble * 20.0) * 0.06 * _wobble


func get_prompt(game: GameState) -> String:
	if felled:
		return "A stump. It'll regrow in %d day(s)." % (REGROW_DAYS - days_felled)
	if game.current_tool == GameState.Tool.AXE:
		return "[E] Chop tree (%d/%d)" % [hits, hits_needed(game.count("copper_axe") > 0)]
	return "A tree. Use the Axe [4] for wood."


func pl_dir_to_player() -> Vector3:
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return Vector3.BACK
	var d := pl.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.BACK


func interact(game: GameState) -> void:
	if felled:
		game.say("You pat the stump. Emotional support for stumps.")
		return
	if game.current_tool != GameState.Tool.AXE:
		game.say("You hug the tree. It doesn't hug back.")
		return
	hits += 1
	var need := hits_needed(game.count("copper_axe") > 0)
	_wobble = 1.0
	Sfx.play_on(self, "chop")
	FX.burst(self, global_position + Vector3(0, 0.8, 0), Art.WOOD.lightened(0.25), 10, 0.1, 3.5)
	FX.chips(self, global_position + Vector3(0, 0.9, 0), pl_dir_to_player(), hits, need)
	FX.hit_stop(get_tree(), 0.3 if hits < need else 0.8)
	if hits >= need:
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
	_wobble = 0.0
	# Valheim-style: topples away from whoever swung the axe.
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var dir := FX.fall_dir(global_position, pl.global_position if pl != null else global_position - Vector3.RIGHT)
	var axis := FX.fall_axis(dir)
	var dist := pl.global_position.distance_to(global_position) if pl != null else 3.0
	# Warning: a red strip on the ground along the fall line, and a shout if you are standing in it.
	_show_fall_warning(dir)
	if pl != null and FX.in_fall_zone(global_position, dir, pl.global_position):
		game.say("TIMBER!! Move your feet!")
		Sfx.play_on(self, "thud", 0.7)
	var tw := create_tween()
	tw.tween_method(func(a: float): _trunk.basis = Basis(axis, a), 0.0, PI * 0.5, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_spawn_logs(game, dir)
		game.shake.emit(FX.fall_shake(dist))
		_crush(game, dir)
		FX.burst(self, global_position + dir * 2.5 + Vector3(0, 0.3, 0), Color(0.45, 0.62, 0.25), 24, 0.16, 4.0, -6.0)
		FX.burst(self, global_position + dir * 2.5 + Vector3(0, 0.2, 0), Color(0.75, 0.68, 0.55), 16, 0.2, 2.0, -2.0, "sphere")
		# Leaves flutter down slowly (low gravity, wide spread) for a long moment.
		FX.burst(self, global_position + Vector3(0, 3.2, 0) + dir * 1.2, Color(0.5, 0.72, 0.28), 30, 0.12, 2.2, -0.9, "box", 180.0))
	# Thud rebound: bounces back a few degrees and settles.
	tw.tween_method(func(a: float): _trunk.basis = Basis(axis, a), PI * 0.5, PI * 0.46, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float): _trunk.basis = Basis(axis, a), PI * 0.46, PI * 0.5, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_trunk, "scale", Vector3.ONE * 0.01, 0.35).set_delay(0.25)
	tw.tween_callback(func():
		_falling = false
		_trunk.basis = Basis.IDENTITY
		_refresh())


## Logs are real rigid bodies that tumble out along the line the trunk fell.
func _spawn_logs(game: GameState, dir: Vector3) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var side := dir.cross(Vector3.UP)
	for i in WOOD_DROP:
		var lg := WoodLog.new()
		lg.game = game
		host.add_child(lg)
		lg.global_position = global_position + dir * (1.2 + i * 0.9) + side * randf_range(-0.3, 0.3) + Vector3(0, 0.6 + i * 0.2, 0)
		lg.pop(dir * 1.5)


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


## Pulsing red strip on the ground showing where the trunk will land (fades after the thud).
func _show_fall_warning(dir: Vector3) -> void:
	var strip := MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(2.2, 0.03, 5.0)
	strip.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.25, 0.2, 0.0)
	strip.material_override = m
	add_child(strip)
	strip.top_level = true
	strip.global_position = global_position + dir * 2.35 + Vector3(0, 0.08, 0)
	strip.global_rotation.y = atan2(dir.x, dir.z)
	var tw := strip.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.5, 0.25)
	tw.tween_property(m, "albedo_color:a", 0.15, 0.2)
	tw.tween_property(m, "albedo_color:a", 0.5, 0.2)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(strip.queue_free)


## The trunk lands: anything in the strip gets flattened. Player is winded + shoved aside, rabbits
## are bonked, crates splinter. Lighthearted: nobody is actually hurt.
func _crush(game: GameState, dir: Vector3) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var pl := tree.get_first_node_in_group("player") as Node3D
	if pl != null and pl.has_method("timber_bonk") and pl.vehicle == null and pl.mount == null and FX.in_fall_zone(global_position, dir, pl.global_position, 4.6, 0.9):
		pl.timber_bonk(dir.cross(Vector3.UP))
		game.say("BONK! The tree won that round.")
	for n in tree.get_nodes_in_group("huntable"):
		if n is Critter and n.visible and FX.in_fall_zone(global_position, dir, n.global_position, 4.6, 0.9):
			n.bonk(game)
	for n in tree.get_nodes_in_group("smashable"):
		if n is PropCrate and FX.in_fall_zone(global_position, dir, n.global_position, 4.6, 0.9):
			n.smash_hit()
			n.smash_hit()
