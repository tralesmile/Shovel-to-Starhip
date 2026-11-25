class_name MineRock
extends Interactable
## An ore rock. Pickaxe hits crack it in stages (it darkens and shrinks, shakes, hit-stops);
## the last hit shatters it into rigid-body chunks (stone, sometimes copper ore or a gem)
## that you pick up from the ground. Regrows after REGROW_DAYS.

const HITS_TO_BREAK := 4
const REGROW_DAYS := 3
const STONE_COLOR := Color(0.55, 0.56, 0.6)
const ORE_COLOR := Color(0.85, 0.5, 0.28)
const GEM_COLOR := Color(0.4, 0.9, 1.0)

var hits: int = 0
var broken: bool = false
var days_broken: int = 0
var ore_rich := false   ## copper streaks visible; better drops

var _mesh: Node3D
var _cracks: Node3D
var _mats: Array = []
var _wobble := 0.0


## Pure (tested): hits needed to break; the copper pickaxe cracks rocks a hit sooner.
static func hits_needed(upgraded: bool, gem: bool = false) -> int:
	var n := HITS_TO_BREAK - 1 if upgraded else HITS_TO_BREAK
	if gem:
		n -= 1   # Gem Pickaxe tier (research: Core Keeper/Terraria pickaxe tiers)
	return maxi(n, 1)


## Pure (tested): the rock's tint darkens as it cracks (stage 0..1).
static func crack_tint(c: float) -> Color:
	return STONE_COLOR.lerp(Color(0.22, 0.2, 0.22), clampf(c, 0.0, 1.0) * 0.7)


## Pure (tested): how many dark crack lines are visible after h hits.
static func crack_line_count(h: int) -> int:
	return clampi(h, 0, HITS_TO_BREAK) * 2


## Pure (tested): the pickaxe tier from what the player owns.
static func tier_args(game: GameState) -> Array:
	return [game.count("copper_pickaxe") > 0, game.count("gem_pickaxe") > 0]


## Pure (tested): which drops does a break give? roll1/roll2 are 0..1 randoms.
static func drops_for(rich: bool, roll1: float, roll2: float) -> Array:
	var out := [{"item": "stone", "amount": 1}, {"item": "stone", "amount": 1}]
	if rich or roll1 < 0.35:
		out.append({"item": "copper_ore", "amount": 1})
	if roll2 < (0.25 if rich else 0.08):
		out.append({"item": "gem", "amount": 1})
	return out


## Pure (tested): visual crack stage 0..1 for a given hit count.
static func crack_amount(h: int) -> float:
	return clampf(float(h) / float(HITS_TO_BREAK), 0.0, 1.0)


func _ready() -> void:
	add_to_group("daily")
	add_to_group("saveable")
	interact_radius = 1.9
	ore_rich = absi(hash(str(name))) % 3 == 0
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.8
	shape.shape = sph
	shape.position.y = 0.6
	body.add_child(shape)
	add_child(body)
	_mesh = Node3D.new()
	add_child(_mesh)
	_cracks = Node3D.new()
	_mesh.add_child(_cracks)
	var big := Art.box(Vector3(1.5, 1.1, 1.3), STONE_COLOR)
	big.position.y = 0.55
	big.rotation.y = randf() * TAU
	_mesh.add_child(big)
	var top := Art.box(Vector3(1.0, 0.7, 0.9), STONE_COLOR.lightened(0.1))
	top.position = Vector3(0.1, 1.2, 0.0)
	top.rotation = Vector3(0.15, randf() * TAU, 0.1)
	_mesh.add_child(top)
	for mi in [big, top]:
		mi.material_override = mi.material_override.duplicate()   # Toon materials are cached/shared; tint per rock
		_mats.append(mi.material_override)
	if ore_rich:
		for i in 3:
			var vein := Art.box(Vector3(0.28, 0.28, 0.28), ORE_COLOR)
			vein.position = Vector3(randf_range(-0.6, 0.6), randf_range(0.4, 1.2), 0.62 if i % 2 == 0 else -0.62)
			vein.rotation = Vector3(randf(), randf(), randf())
			_mesh.add_child(vein)
	_refresh()


func _process(delta: float) -> void:
	if _wobble > 0.0 and _mesh != null:
		_wobble = max(0.0, _wobble - delta * 5.0)
		_mesh.position.x = sin(_wobble * 40.0) * 0.05 * _wobble


func get_prompt(game: GameState) -> String:
	if broken:
		return "Gravel dust. It'll regrow in %d day(s)." % (REGROW_DAYS - days_broken)
	if game.current_tool == GameState.Tool.PICKAXE:
		return "[E] Mine %s(%d/%d)" % ["copper-streaked rock " if ore_rich else "rock ", hits, hits_needed(game.count("copper_pickaxe") > 0, game.count("gem_pickaxe") > 0)]
	return "A big rock. Use the Pickaxe [5]."


func interact(game: GameState) -> void:
	if broken:
		game.say("You salute the gravel. It does not salute back.")
		return
	if game.current_tool != GameState.Tool.PICKAXE:
		game.say("You punch the rock. Your hand files a complaint.")
		return
	hits += 1
	_wobble = 1.0
	Sfx.play_on(self, "thud")
	FX.burst(self, global_position + Vector3(0, 0.9, 0), STONE_COLOR.lightened(0.3), 8, 0.08, 3.5)
	FX.burst(self, global_position + Vector3(0, 0.9, 0), Color(1, 0.9, 0.5), 4, 0.05, 5.0, -2.0, "sphere")   # sparks
	var need := hits_needed(game.count("copper_pickaxe") > 0, game.count("gem_pickaxe") > 0)
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var toward := Vector3.UP
	if pl != null:
		toward = pl.global_position - global_position
		toward.y = 0.0
		toward = toward.normalized() if toward.length() > 0.01 else Vector3.UP
	FX.stone_chips(self, global_position + Vector3(0, 0.9, 0), toward, hits, need, _mats[0].albedo_color if _mats.size() > 0 and "albedo_color" in _mats[0] else STONE_COLOR)
	if hits >= need:
		FX.hit_stop(get_tree(), 0.9)
		game.shake.emit(0.5)
		broken = true
		hits = 0
		days_broken = 0
		game.say("CRACK! The rock gives up its secrets.")
		_spawn_chunks(game)
	else:
		FX.hit_stop(get_tree(), 0.35)
		game.shake.emit(0.15)
	_refresh()


func _spawn_chunks(game: GameState) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	FX.burst(self, global_position + Vector3(0, 0.8, 0), STONE_COLOR, 22, 0.14, 5.0, -9.0)
	FX.burst(self, global_position + Vector3(0, 0.4, 0), Color(0.7, 0.68, 0.62), 14, 0.2, 2.0, -2.0, "sphere")   # dust cloud
	_spawn_shards(host)
	var drops := drops_for(ore_rich, randf(), randf())
	for i in drops.size():
		var d: Dictionary = drops[i]
		var c := WoodLog.new()
		c.game = game
		c.item_id = d["item"]
		c.amount = int(d["amount"])
		c.chunk_color = {"stone": STONE_COLOR, "copper_ore": ORE_COLOR, "gem": GEM_COLOR}[d["item"]]
		host.add_child(c)
		var a := TAU * float(i) / float(drops.size())
		c.global_position = global_position + Vector3(cos(a) * 0.6, 0.9 + i * 0.1, sin(a) * 0.6)
		c.pop(Vector3(cos(a), 0, sin(a)) * 1.2)


## The rock visibly splits: three big shards slide apart, tip over and sink away.
func _spawn_shards(host: Node) -> void:
	for i in 3:
		var a := TAU * float(i) / 3.0 + randf() * 0.5
		var sh := Art.box(Vector3(0.7, 0.6, 0.6), STONE_COLOR.darkened(0.15 * i))
		host.add_child(sh)
		sh.global_position = global_position + Vector3(0, 0.55, 0)
		sh.rotation.y = randf() * TAU
		var tw := sh.create_tween().set_parallel(true)
		var tgt := sh.global_position + Vector3(cos(a), -0.15, sin(a)) * 0.9
		tw.tween_property(sh, "global_position", tgt, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sh, "rotation", sh.rotation + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 0.35)
		tw.chain().tween_property(sh, "scale", Vector3.ONE * 0.05, 0.45).set_delay(0.5)
		tw.chain().tween_callback(sh.queue_free)


func on_new_day(_game: GameState) -> void:
	if broken:
		days_broken += 1
		if days_broken >= REGROW_DAYS:
			broken = false
			days_broken = 0
	_refresh()


func to_dict() -> Dictionary:
	return {"hits": hits, "broken": broken, "days_broken": days_broken}


func from_dict(d: Dictionary) -> void:
	hits = int(d.get("hits", 0))
	broken = bool(d.get("broken", false))
	days_broken = int(d.get("days_broken", 0))
	_refresh()


func _refresh() -> void:
	if _mesh == null:
		return
	_mesh.visible = not broken
	# Cracks: the rock shrinks a little with every hit.
	var c := crack_amount(hits)
	_mesh.scale = Vector3.ONE * (1.0 - 0.12 * c)
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("albedo_color", crack_tint(c))
	if _cracks != null:
		for k in _cracks.get_children():
			k.queue_free()
		var n := crack_line_count(hits)
		for i in n:
			var side := 1.0 if i % 2 == 0 else -1.0
			var ln := Art.box(Vector3(0.05, 0.5 + 0.1 * i, 0.04), Color(0.08, 0.07, 0.09))
			ln.position = Vector3(-0.5 + 0.17 * i, 0.7, 0.66 * side)
			ln.rotation.z = 0.5 * sin(float(i) * 2.3)
			_cracks.add_child(ln)
	for b in get_children():
		if b is StaticBody3D:
			b.process_mode = Node.PROCESS_MODE_DISABLED if broken else Node.PROCESS_MODE_INHERIT
