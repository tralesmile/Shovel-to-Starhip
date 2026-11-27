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
const CRYSTAL_COLOR := Color(0.55, 0.95, 0.9)
const CHEESE_COLOR := Color(0.9, 0.68, 0.22)
const ROCK_SHADER := preload("res://scripts/shaders/rock.gdshader")
const WEDGES := 13
const RADII := Vector3(0.9, 0.78, 0.82)
const CENTER := Vector3(0.0, 0.6, 0.0)
const SWEET_ARC := 0.8   ## radians either side of the gold mark that count as a sweet hit
const SPOT_RANGE := 4.5
const MAX_SHARD_RISE := 6.5

var kind := ""   ## "" = random surface rock, "plain", "rich" (copper veins), "geode" (needs copper pickaxe) or "cheese" (Moon)

var hits: int = 0
var broken: bool = false
var days_broken: int = 0
var ore_rich := false   ## copper streaks visible; better drops

var spot_yaw := 0.0     ## world-facing angle of the gold sweet spot
var gone: Array = []    ## indices of the wedges already knocked off

var _mesh: Node3D
var _mats: Array = []
var _mat: ShaderMaterial
var _wedges: Array = []        ## MeshInstance3D per wedge
var _wedge_data: Array = []    ## RockMesh.fracture() output
var _whole: MeshInstance3D     ## one merged mesh, shown until the first wedge comes off
var _core: MeshInstance3D
var _growths: Array = []       ## [node, wedge index]: crystals that go when their wedge goes
var _crack_from := Vector3(0, 0.8, 0.8)
var _wobble := 0.0
var _jolt := Vector3.ZERO


## Pure (tested): hits needed to break; the copper pickaxe cracks rocks a hit sooner.
static func hits_needed(upgraded: bool, gem: bool = false) -> int:
	var n := HITS_TO_BREAK - 1 if upgraded else HITS_TO_BREAK
	if gem:
		n -= 1   # Gem Pickaxe tier (research: Core Keeper/Terraria pickaxe tiers)
	return maxi(n, 1)


## Pure (tested): where the gold mark starts on a fresh rock.
static func first_spot_yaw(seed_value: int) -> float:
	return wrapf(float(seed_value % 628) * 0.01, -PI, PI)


## Pure (tested): after a hit from `hit_yaw` the mark jumps round the rock, far enough that
## you have to step sideways to line it up again. roll is 0..1.
static func next_spot_yaw(hit_yaw: float, roll: float) -> float:
	var side := 1.0 if roll >= 0.5 else -1.0
	return wrapf(hit_yaw + side * lerpf(1.35, 2.1, fposmod(roll * 2.0, 1.0)), -PI, PI)


## Pure (tested): the compass angle of a flat direction.
static func yaw_to(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


## Pure (tested): was the swing lined up with the gold mark? No direction means no.
static func is_sweet(toward: Vector3, yaw: float) -> bool:
	if Vector2(toward.x, toward.z).length() < 0.05:
		return false
	return absf(angle_difference(yaw_to(toward), yaw)) <= SWEET_ARC


## Pure (tested): a sweet hit does the work of two.
static func hit_damage(sweet: bool) -> int:
	return 2 if sweet else 1


## Pure (tested): finishing on the gold mark is a "clean break" with one bonus piece.
static func clean_break_bonus(rock_kind: String, rich: bool) -> Dictionary:
	if rock_kind == "geode":
		return {"item": "glow_crystal", "amount": 1}
	if rock_kind == "cheese":
		return {"item": "moon_cheese", "amount": 1}
	return {"item": "copper_ore" if rich else "stone", "amount": 1}


## Pure (tested): geodes are too hard for the starter pickaxe (Terraria/Core Keeper tool gates).
static func can_mine(rock_kind: String, copper: bool, gem: bool) -> bool:
	return rock_kind != "geode" or copper or gem


## Pure (tested): what a geode bursts into.
static func geode_drops(roll: float) -> Array:
	var out := [{"item": "stone", "amount": 1}, {"item": "glow_crystal", "amount": 1}, {"item": "glow_crystal", "amount": 1}]
	if roll < 0.35:
		out.append({"item": "gem", "amount": 1})
	return out


## Pure (tested): what a Moon cheese boulder bursts into.
static func cheese_drops(roll: float) -> Array:
	var out := [{"item": "moon_cheese", "amount": 1}, {"item": "moon_cheese", "amount": 1}, {"item": "moon_rock", "amount": 1}]
	if roll < 0.3:
		out.append({"item": "moon_cheese", "amount": 1})
	return out


func _base_tint(c: float) -> Color:
	if kind == "cheese":
		return CHEESE_COLOR.lerp(Color(0.55, 0.34, 0.06), clampf(c, 0.0, 1.0) * 0.6)
	return crack_tint(c).darkened(0.35 if kind == "geode" else 0.0)


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
	add_to_group("blastable")
	interact_radius = 1.9
	ore_rich = kind == "rich" if kind != "" else absi(hash(str(name))) % 3 == 0
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
	var seed_value := absi(hash(str(name))) + 11
	spot_yaw = first_spot_yaw(seed_value)
	_build_rock(seed_value)
	if kind == "cheese":
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.8, 0.3)
		glow.light_energy = 0.22
		glow.omni_range = 3.0
		glow.position.y = 1.4
		_mesh.add_child(glow)
	if kind == "geode":
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(name))
		for k in 3:
			var cl := MineCave.crystal_cluster(CRYSTAL_COLOR, 3, 0.55, rng)
			cl.position = [Vector3(0.1, 1.25, 0.05), Vector3(-0.72, 0.55, 0.3), Vector3(0.66, 0.75, 0.45)][k]
			cl.rotation = [Vector3.ZERO, Vector3(0.2, 0, 1.1), Vector3(0.7, 0, -0.9)][k]
			# Each cluster grows on a wedge, so it breaks away with it.
			_mesh.add_child(cl)
			_growths.append([cl, _nearest_wedge(cl.position)])
	_refresh()


## The material that draws a rock of this kind (also used by the loose nuggets).
static func rock_material(rock_kind: String, rich: bool, mossy: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROCK_SHADER
	m.set_shader_parameter("albedo_color", CHEESE_COLOR if rock_kind == "cheese" else STONE_COLOR)
	if rock_kind == "geode":
		m.set_shader_parameter("veins", 0.45)
		m.set_shader_parameter("vein_color", CRYSTAL_COLOR)
		m.set_shader_parameter("glint", 0.8)
	elif rich:
		m.set_shader_parameter("veins", 1.0)
		m.set_shader_parameter("vein_color", ORE_COLOR)
		m.set_shader_parameter("glint", 0.45)
	m.set_shader_parameter("cheese", 1.0 if rock_kind == "cheese" else 0.0)
	m.set_shader_parameter("moss", 1.0 if mossy else 0.0)
	return m


func _build_rock(seed_value: int) -> void:
	_mat = rock_material(kind, ore_rich, kind == "")
	_mats = [_mat]
	_wedge_data = RockMesh.fracture(WEDGES, RADII, CENTER, seed_value)
	for piece in _wedge_data:
		var mi := MeshInstance3D.new()
		mi.mesh = RockMesh.wedge_mesh(piece)
		mi.material_override = _mat
		_mesh.add_child(mi)
		_add_outline(mi, piece["skin"])
		_wedges.append(mi)
	_whole = MeshInstance3D.new()
	_whole.mesh = RockMesh.whole_mesh(_wedge_data)
	_whole.material_override = _mat
	_mesh.add_child(_whole)
	var all_skin := PackedVector3Array()
	for piece in _wedge_data:
		all_skin.append_array(piece["skin"])
	_add_outline(_whole, all_skin)
	_core = MeshInstance3D.new()
	_core.mesh = RockMesh.lump_mesh(RADII, CENTER, seed_value, 1, RockMesh.UV_CORE, RockMesh.CORE)
	_core.material_override = _mat
	_mesh.add_child(_core)
	# A few loose stones round the foot so it sits in the ground rather than on it.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pebbles := SurfaceTool.new()
	for k in 5:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.09, 0.2)
		var at := Vector3(cos(a) * rng.randf_range(0.82, 1.15), r * 0.4, sin(a) * rng.randf_range(0.76, 1.05))
		pebbles.append_from(RockMesh.lump_mesh(Vector3(r, r * 0.7, r), at, seed_value + k, 0, RockMesh.UV_SKIN), 0, Transform3D.IDENTITY)
	var foot := MeshInstance3D.new()
	foot.mesh = pebbles.commit()
	foot.material_override = _mat
	_mesh.add_child(foot)


## The cartoon outline for a rock part (its own smooth-normal shell).
func _add_outline(on: MeshInstance3D, skin: PackedVector3Array) -> void:
	if not (Toon.enabled and Toon.outlines):
		return
	var shell := MeshInstance3D.new()
	shell.mesh = RockMesh.shell_mesh(skin, CENTER)
	shell.material_override = Toon.outline_material(0.0)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	on.add_child(shell)


func _nearest_wedge(at: Vector3) -> int:
	var best := 0
	for i in range(1, _wedge_data.size()):
		if at.distance_squared_to(_wedge_data[i]["centroid"]) < at.distance_squared_to(_wedge_data[best]["centroid"]):
			best = i
	return best


## A world direction expressed in rock space.
func _local_dir(world_dir: Vector3) -> Vector3:
	var b := global_basis.orthonormalized() if is_inside_tree() else Basis.IDENTITY
	return b.inverse() * world_dir


## Where on the skin (rock space) a flat world direction lands, a little above the middle.
func _skin_point(yaw: float) -> Vector3:
	var d := _local_dir(Vector3(sin(yaw), 0.0, cos(yaw)))
	d = Vector3(d.x, 0.3, d.z).normalized()
	return RockMesh.shape_point(d, 1.0, RADII, CENTER, absi(hash(str(name))) + 11)


## Knocks wedges off until `target` are gone, flinging each as a physics shard.
func _shed(target: int, toward: Vector3, punch: float) -> int:
	var dirs := _wedge_data.map(func(p): return p["dir"])
	var picks := RockMesh.pick_shed(dirs, gone, _local_dir(toward), target - gone.size())
	var host: Node = get_parent()
	var seen := is_inside_tree() and _mesh.is_visible_in_tree()
	for i in picks:
		gone.append(i)
		var mi: MeshInstance3D = _wedges[i]
		if host != null and seen:
			var loose := _mat.duplicate() as ShaderMaterial
			loose.set_shader_parameter("spot_on", 0.0)
			var c: Vector3 = _wedge_data[i]["centroid"]
			var out := global_basis * (c - CENTER)
			out.y = maxf(out.y, 0.0)
			var vel := (out.normalized() * randf_range(1.2, 2.6) + toward * randf_range(0.2, 1.0)) * punch + Vector3.UP * randf_range(1.4, 3.2) * punch
			vel.y = minf(vel.y, MAX_SHARD_RISE)   # even a bomb only tosses them head-high or so
			RockShard.fling(host, mi, global_transform, c, _wedge_data[i]["skin"], loose, vel)
	_show_wedges()
	return picks.size()


func _show_wedges() -> void:
	var whole := gone.is_empty()
	_whole.visible = whole
	_core.visible = not whole
	for i in _wedges.size():
		_wedges[i].visible = not whole and not i in gone
	for g in _growths:
		g[0].visible = not g[1] in gone


func wedge_count() -> int:
	return _wedges.size()


## The gold mark shows while you stand near with the pickaxe out.
func spot_visible(game: GameState, player_pos: Vector3) -> bool:
	return not broken and game.current_tool == GameState.Tool.PICKAXE \
		and player_pos.distance_to(global_position) <= SPOT_RANGE \
		and can_mine(kind, game.count("copper_pickaxe") > 0, game.count("gem_pickaxe") > 0)


func _process(delta: float) -> void:
	if _mesh == null:
		return
	if _wobble > 0.0:
		_wobble = max(0.0, _wobble - delta * 5.0)
		_mesh.position = Vector3(sin(_wobble * 40.0) * 0.05 * _wobble, 0, 0) - _jolt * 0.09 * _wobble
		_mesh.scale = Vector3(1.0 + 0.05 * _wobble, 1.0 - 0.07 * _wobble, 1.0 + 0.05 * _wobble) if _wobble > 0.0 else Vector3.ONE
	if broken or _mat == null or not is_inside_tree():
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var game := get_node_or_null("/root/Game") as GameState
	var on := pl != null and game != null and spot_visible(game, pl.global_position)
	_mat.set_shader_parameter("spot_on", 1.0 if on else 0.0)


func get_prompt(game: GameState) -> String:
	if broken:
		if kind == "cheese":
			return "Cheese crumbs. The Moon makes more in %d day(s)." % (REGROW_DAYS - days_broken)
		return "Gravel dust. It'll regrow in %d day(s)." % (REGROW_DAYS - days_broken)
	if game.current_tool == GameState.Tool.PICKAXE:
		if not can_mine(kind, game.count("copper_pickaxe") > 0, game.count("gem_pickaxe") > 0):
			return "Crystal geode. Too hard: craft a Copper Pickaxe (or throw a Boom Turnip [B])."
		var label := "copper-streaked rock " if ore_rich else "rock "
		if kind == "geode":
			label = "crystal geode "
		return "[E] Mine %s(%d/%d)  -  strike the gold spot for double" % [label, hits, hits_needed(game.count("copper_pickaxe") > 0, game.count("gem_pickaxe") > 0)]
	return "A big rock. Use the Pickaxe [5]."


func interact(game: GameState) -> void:
	if broken:
		game.say("You salute the gravel. It does not salute back.")
		return
	if game.current_tool != GameState.Tool.PICKAXE:
		game.say("You punch the rock. Your hand files a complaint.")
		return
	if not can_mine(kind, game.count("copper_pickaxe") > 0, game.count("gem_pickaxe") > 0):
		_wobble = 0.6
		Sfx.play_on(self, "clang", 1.3)
		FX.burst(self, global_position + Vector3(0, 0.9, 0), Color(1, 0.9, 0.5), 10, 0.05, 5.0, -6.0, "sphere")
		game.shake.emit(0.12)
		game.say("PING! The geode laughs at your starter pickaxe. Copper or better.")
		return
	var pl: Node3D = get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	var toward := Vector3.ZERO
	if pl != null:
		toward = pl.global_position - global_position
		toward.y = 0.0
		toward = toward.normalized() if toward.length() > 0.05 else Vector3.ZERO
	strike(game, toward, randf())


## One swing arriving from `toward` (a flat direction from the rock to the miner, or zero).
## Returns true if it landed on the gold spot.
func strike(game: GameState, toward: Vector3, roll: float) -> bool:
	if broken:
		return false
	var sweet := is_sweet(toward, spot_yaw)
	var from_dir := toward if toward != Vector3.ZERO else Vector3.BACK
	var need := hits_needed(game.count("copper_pickaxe") > 0, game.count("gem_pickaxe") > 0)
	hits += hit_damage(sweet)
	_wobble = 1.0
	_jolt = from_dir
	_crack_from = _skin_point(spot_yaw if sweet else yaw_to(from_dir))
	var face := global_position + from_dir * 0.8 + Vector3(0, 0.85, 0)
	Sfx.play_on(self, "crack", 0.85 + 0.12 * mini(hits, need))
	Sfx.play_on(self, "thud")
	FX.burst(self, face, Color(0.72, 0.7, 0.68, 0.7), 6, 0.14, 1.4, -0.8, "sphere", 80.0)   # dust
	FX.burst(self, face, Color(1, 0.9, 0.5), 5, 0.045, 5.0, -2.0, "sphere")   # sparks
	FX.stone_chips(self, face, from_dir, mini(hits, need), need, _mats[0].get_shader_parameter("albedo_color") if not _mats.is_empty() else STONE_COLOR)
	if sweet:
		Sfx.play_on(self, "chime", 1.0 + 0.08 * mini(hits, 4))
		FX.burst(self, face, Color(1.0, 0.8, 0.2), 16, 0.08, 4.5, -5.0, "box", 75.0, true)
		_shout("SWEET SPOT!" if hits < need else "CLEAN BREAK!")
	# After every swing the mark jumps to a new place beside you. So it is never stuck somewhere
	# you cannot stand (a mine wall, say): swing again and it picks another side.
	if toward != Vector3.ZERO:
		spot_yaw = next_spot_yaw(yaw_to(toward), roll)
	if hits >= need:
		FX.hit_stop(get_tree() if is_inside_tree() else null, 0.9)
		game.shake.emit(0.5)
		broken = true
		hits = 0
		days_broken = 0
		var line := "CRACK! It is cheese. Of course it is cheese." if kind == "cheese" else "CRACK! The rock gives up its secrets."
		if sweet:
			line = "CLEAN BREAK! Struck right on the gold spot: one extra piece."
		game.say(line)
		_burst_apart(from_dir, 1.0)
		_spawn_chunks(game, [clean_break_bonus(kind, ore_rich)] if sweet else [])
	else:
		FX.hit_stop(get_tree() if is_inside_tree() else null, 0.7 if sweet else 0.35)
		game.shake.emit(0.28 if sweet else 0.15)
		_shed(RockMesh.shed_target(hits, need, _wedges.size()), from_dir, 1.15 if sweet else 0.8)
	_refresh()
	return sweet


## The finishing blow: every wedge still standing flies apart.
func _burst_apart(toward: Vector3, punch: float) -> void:
	_shed(_wedges.size(), toward, punch)
	Sfx.play_on(get_parent(), "crunch", randf_range(0.9, 1.15))


## A word that pops up over the rock and floats off.
func _shout(text: String) -> void:
	if not is_inside_tree():
		return
	var l := Art.label(text, 70, Color(1.0, 0.85, 0.3))
	l.no_depth_test = true
	get_parent().add_child(l)
	l.global_position = global_position + Vector3(0, 1.9, 0)
	l.scale = Vector3.ONE * 0.3
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 0.8, 0), 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


func _spawn_chunks(game: GameState, bonus: Array = []) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	FX.burst(self, global_position + Vector3(0, 0.8, 0), STONE_COLOR, 22, 0.14, 5.0, -9.0)
	FX.burst(self, global_position + Vector3(0, 0.4, 0), Color(0.7, 0.68, 0.62), 14, 0.2, 2.0, -2.0, "sphere")   # dust cloud
	var drops := geode_drops(randf()) if kind == "geode" else (cheese_drops(randf()) if kind == "cheese" else drops_for(ore_rich, randf(), randf()))
	drops.append_array(bonus)
	for i in drops.size():
		var d: Dictionary = drops[i]
		var c := WoodLog.new()
		c.game = game
		c.item_id = d["item"]
		c.amount = int(d["amount"])
		c.chunk_color = {"stone": STONE_COLOR, "copper_ore": ORE_COLOR, "gem": GEM_COLOR, "glow_crystal": CRYSTAL_COLOR, "moon_cheese": CHEESE_COLOR, "moon_rock": Color(0.55, 0.55, 0.62)}[d["item"]]
		host.add_child(c)
		var a := TAU * float(i) / float(drops.size())
		c.global_position = global_position + Vector3(cos(a) * 0.6, 0.9 + i * 0.1, sin(a) * 0.6)
		c.pop(Vector3(cos(a), 0, sin(a)) * 1.2)


## A goat headbutt counts as two swings, pickaxe not required. Geodes just ring.
func ram(game: GameState) -> bool:
	if broken:
		return false
	_wobble = 1.0
	Sfx.play_on(self, "clang", 0.7)
	FX.burst(self, global_position + Vector3(0, 0.8, 0), Color(1, 0.9, 0.5), 10, 0.05, 5.0, -6.0, "sphere")
	if kind == "geode":
		return true
	hits += 2
	var need := hits_needed(false, false)
	if hits >= need:
		hits = 0
		broken = true
		days_broken = 0
		_burst_apart(Vector3.BACK, 1.4)
		_spawn_chunks(game)
		game.say("The goat has opinions about this rock. The rock is now several rocks.")
	else:
		_shed(RockMesh.shed_target(hits, need, _wedges.size()), Vector3.BACK, 1.2)
	_refresh()
	return true


## A Boom Turnip skips the hit count (and the pickaxe gate). Returns false if already rubble.
func blast(game: GameState) -> bool:
	if broken:
		return false
	broken = true
	hits = 0
	days_broken = 0
	_burst_apart(Vector3.UP, 1.9)
	_spawn_chunks(game)
	_refresh()
	return true


func on_new_day(_game: GameState) -> void:
	if broken:
		days_broken += 1
		if days_broken >= REGROW_DAYS:
			broken = false
			days_broken = 0
			gone = []
	_refresh()


func to_dict() -> Dictionary:
	return {"hits": hits, "broken": broken, "days_broken": days_broken, "gone": gone.duplicate(), "spot": spot_yaw}


func from_dict(d: Dictionary) -> void:
	hits = int(d.get("hits", 0))
	broken = bool(d.get("broken", false))
	days_broken = int(d.get("days_broken", 0))
	spot_yaw = float(d.get("spot", spot_yaw))
	gone = []
	for i in d.get("gone", []):   # JSON gives floats back
		gone.append(int(i))
	# Saves from before rocks broke apart only stored the hit count.
	if gone.is_empty() and hits > 0 and not broken and not _wedges.is_empty():
		var dirs := _wedge_data.map(func(p): return p["dir"])
		gone = RockMesh.pick_shed(dirs, [], Vector3.BACK, RockMesh.shed_target(hits, HITS_TO_BREAK, _wedges.size()))
	_refresh()


func _refresh() -> void:
	if _mesh == null:
		return
	_mesh.visible = not broken
	_show_wedges()
	var c := crack_amount(hits)
	_mat.set_shader_parameter("albedo_color", _base_tint(c * 0.5))
	_mat.set_shader_parameter("crack", c)
	_mat.set_shader_parameter("crack_origin", _crack_from)
	_mat.set_shader_parameter("spot_pos", _skin_point(spot_yaw))
	for b in get_children():
		if b is StaticBody3D:
			b.process_mode = Node.PROCESS_MODE_DISABLED if broken else Node.PROCESS_MODE_INHERIT
