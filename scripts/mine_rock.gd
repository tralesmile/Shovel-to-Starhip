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
var _wobble := 0.0


## Pure (tested): hits needed to break; the copper pickaxe cracks rocks a hit sooner.
static func hits_needed(upgraded: bool) -> int:
	return HITS_TO_BREAK - 1 if upgraded else HITS_TO_BREAK


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
	var big := Art.box(Vector3(1.5, 1.1, 1.3), STONE_COLOR)
	big.position.y = 0.55
	big.rotation.y = randf() * TAU
	_mesh.add_child(big)
	var top := Art.box(Vector3(1.0, 0.7, 0.9), STONE_COLOR.lightened(0.1))
	top.position = Vector3(0.1, 1.2, 0.0)
	top.rotation = Vector3(0.15, randf() * TAU, 0.1)
	_mesh.add_child(top)
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
		return "[E] Mine %s(%d/%d)" % ["copper-streaked rock " if ore_rich else "rock ", hits, hits_needed(game.count("copper_pickaxe") > 0)]
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
	if hits >= hits_needed(game.count("copper_pickaxe") > 0):
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
	for b in get_children():
		if b is StaticBody3D:
			b.process_mode = Node.PROCESS_MODE_DISABLED if broken else Node.PROCESS_MODE_INHERIT
