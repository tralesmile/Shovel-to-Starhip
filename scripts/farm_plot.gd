class_name FarmPlot
extends Interactable
## One 2x2 m patch of land: grass -> tilled -> planted -> ripe -> pulled.
## A planted crop grows one stage each night it went to bed watered. Harvesting is physical: the
## plant is yanked out and the produce pops onto the ground as pick-ups. Compost doubles a harvest
## and fattens the odds of a giant crop (see FarmField).

enum State { GRASS, TILLED, PLANTED }

const SIZE := 1.8
const PULL_TIME := 0.24
const RUSTLE_RADIUS := 0.85

var state: int = State.GRASS
var watered: bool = false
var growth: int = 0
var crop: String = "turnip"
var composted := false
var picks := 0               ## harvests already taken from a regrowing plant
var giant := false           ## this plot is part of a giant crop (FarmField owns it)
var slept_wet := false       ## was watered when the last night fell

var _grass: MeshInstance3D
var _soil: MeshInstance3D
var _soil_mat: ShaderMaterial
var _crop: Node3D
var _sparkle: CPUParticles3D
var _wet_tween: Tween
var _tilt := Vector2.ZERO
var _tilt_vel := Vector2.ZERO


func _ready() -> void:
	add_to_group("daily")
	add_to_group("saveable")
	add_to_group("farmplot")
	interact_radius = 1.5
	_grass = Art.box(Vector3(SIZE, 0.06, SIZE), Art.GRASS.darkened(0.08))
	_grass.position.y = 0.03
	add_child(_grass)
	_soil = MeshInstance3D.new()
	_soil.mesh = CropModel.soil_mesh(SIZE)
	_soil_mat = CropModel.soil_material()
	_soil.material_override = _soil_mat
	add_child(_soil)
	_crop = Node3D.new()
	_crop.position.y = 0.04
	add_child(_crop)
	_refresh()


func grow_days() -> int:
	return int(GameState.CROPS[crop]["days"])


func is_ripe() -> bool:
	return state == State.PLANTED and growth >= grow_days()


## Can compost still do something here?
func wants_compost() -> bool:
	return state == State.PLANTED and not composted and not giant


func get_prompt(game: GameState) -> String:
	if giant:
		return ""
	if is_ripe():
		return "[E] Pull up %s" % crop if not GameState.CROPS[crop].has("regrow") else "[E] Pick %s" % crop
	match game.current_tool:
		GameState.Tool.HOE:
			return "[E] Till soil" if state == State.GRASS else ""
		GameState.Tool.SEEDS:
			if state == State.TILLED:
				return "[E] Plant %s seed (%d left)" % [game.selected_crop, game.count(game.crop_seed_id())]
			if wants_compost() and game.count("compost") > 0:
				return "[E] Feed it compost (%d left)" % game.count("compost")
		GameState.Tool.WATER:
			if state != State.GRASS and not watered:
				return "[E] Water"
	return _status_text()


func _status_text() -> String:
	match state:
		State.GRASS:
			return "Grass. Use the Hoe [1] to till it."
		State.TILLED:
			return "Tilled soil. Plant seeds [2]." if not watered else "Wet soil. Plant seeds [2]."
		State.PLANTED:
			var left := grow_days() - growth
			var w := "watered" if watered else "thirsty! Use the Watering Can [3]"
			return "%s: %d night(s) to go, %s%s" % [crop.capitalize(), left, w, ", composted" if composted else ""]
	return ""


func interact(game: GameState) -> void:
	if giant:
		return
	if is_ripe():
		_harvest(game)
		return
	match game.current_tool:
		GameState.Tool.HOE:
			if state == State.GRASS:
				state = State.TILLED
				game.say("Tilled! Your back says hello.")
				FX.burst(self, global_position + Vector3(0, 0.1, 0), Art.DIRT, 18, 0.12, 3.0)
				_refresh()
		GameState.Tool.SEEDS:
			if state == State.TILLED:
				if game.remove_item(game.crop_seed_id()):
					state = State.PLANTED
					crop = game.selected_crop
					growth = 0
					picks = 0
					composted = false
					FX.burst(self, global_position + Vector3(0, 0.1, 0), Color(0.85, 0.75, 0.45), 6, 0.06, 1.5)
					game.say("Planted a %s. Grow, little buddy." % crop)
					_refresh()
					_pop_crop()
				else:
					game.say("Out of %s seeds. The General Store sells them. [2] switches seeds." % game.selected_crop)
			elif wants_compost() and game.remove_item("compost"):
				composted = true
				game.say("Composted. It smells like ambition.")
				FX.burst(self, global_position + Vector3(0, 0.25, 0), Color(0.28, 0.2, 0.1), 16, 0.08, 2.2)
				FX.burst(self, global_position + Vector3(0, 0.4, 0), Color(0.55, 0.9, 0.35), 8, 0.06, 1.6, -2.0, "sphere", 70.0, true)
				_apply_soil(false)
				kick(Vector2(0.35, 0.2))
		GameState.Tool.WATER:
			if state != State.GRASS:
				if watered:
					game.say("It's already wet. Any wetter and it's a pond.")
				else:
					pour_water()
		GameState.Tool.AXE:
			game.say("You threaten the soil with an axe. It is unimpressed.")


## Wet the soil with a visible pour: the dark patch soaks outwards and the leaves flinch.
func pour_water() -> void:
	watered = true
	if is_inside_tree():
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl != null and pl.global_position.distance_to(global_position) < 3.5:
			FX.pour(self, pl.global_position + Vector3(0, 1.15, 0), global_position + Vector3(0, 0.2, 0))
			Sfx.play_on(self, "splash", 1.5)
		else:
			FX.burst(self, global_position + Vector3(0, 0.3, 0), Color(0.45, 0.75, 1.0), 14, 0.07, 1.8, -9.0, "sphere", 60.0)
	_apply_soil(true)
	kick(Vector2(randf_range(-0.2, 0.2), 0.25))


## Pure (tested): crops produced by one harvest. `lucky` is the old 1-in-5 bonus; compost always doubles.
static func harvest_amount(has_compost: bool, lucky: bool) -> int:
	return 2 if has_compost or lucky else 1


## Pure (tested): does this plant stay in the ground after being picked, and at what growth?
## Returns -1 when the plant is spent.
static func regrow_growth(crop_id: String, picks_done: int) -> int:
	var cd: Dictionary = GameState.CROPS[crop_id]
	if not cd.has("regrow") or picks_done >= int(cd["picks"]):
		return -1
	return int(cd["days"]) - int(cd["regrow"])


func _harvest(game: GameState) -> void:
	# Small bonus chance keeps harvests exciting. Deterministic per plot+day for tests.
	var amount := harvest_amount(composted, hash(str(name) + str(game.day)) % 5 == 0)
	var picked := crop
	picks += 1
	var again := regrow_growth(crop, picks)
	var old_plant: Node3D = _crop.get_child(0) if _crop.get_child_count() > 0 else null
	if again >= 0:
		growth = again
		old_plant = null
		game.say("Picked %d %s%s! The vine will fruit again." % [amount, picked, "es" if amount > 1 else ""])
	else:
		state = State.TILLED
		growth = 0
		picks = 0
		watered = false
		game.say("Pulled up %d %s%s!" % [amount, picked, ("es" if picked == "tomato" else "s") if amount > 1 else ""])
	composted = false
	if old_plant != null:
		_crop.remove_child(old_plant)
	_refresh()
	if old_plant == null:
		kick(Vector2(0.5, -0.4))
	if not is_inside_tree():
		return
	if DisplayServer.get_name() == "headless":
		if old_plant != null:
			old_plant.queue_free()
		_pop_produce(game, picked, amount)
		return
	# The pull: it stretches, strains... and comes free all at once.
	Sfx.play_on(self, "rustle", 0.7)
	var tw := create_tween()
	if old_plant != null:
		add_child(old_plant)
		old_plant.position.y = 0.04
		tw.tween_property(old_plant, "scale", Vector3(0.72, 1.5, 0.72), PULL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tw.tween_interval(PULL_TIME * 0.5)
	tw.tween_callback(func():
		_pop_produce(game, picked, amount)
		if old_plant != null:
			_fling(old_plant))


## Produce jumps out of the ground as physics pick-ups.
func _pop_produce(game: GameState, what: String, amount: int) -> void:
	for i in amount:
		var item := WoodLog.new()
		item.item_id = what
		item.game = game
		get_parent().add_child(item)
		item.global_position = global_position + Vector3(randf_range(-0.12, 0.12), 0.45 + i * 0.2, randf_range(-0.12, 0.12))
		item.pop(Vector3(randf_range(-0.4, 0.4), 0.6, randf_range(0.2, 0.8)))
	Sfx.play_on(self, "boing", 1.35 + randf() * 0.2)
	FX.burst(self, global_position + Vector3(0, 0.15, 0), Art.DIRT, 22, 0.11, 3.6)
	FX.burst(self, global_position + Vector3(0, 0.35, 0), CropModel.COLORS[what]["leaf"], 10, 0.09, 3.0)
	game.shake.emit(0.14)


## The empty greens tumble up and away.
func _fling(plant: Node3D) -> void:
	var tw := create_tween().set_parallel(true)
	var to := Vector3(randf_range(-0.9, 0.9), 0.9, randf_range(-0.9, 0.2))
	tw.tween_property(plant, "position", to, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(plant, "rotation", Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3)), 0.4)
	tw.tween_property(plant, "scale", Vector3.ONE * 0.05, 0.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(plant.queue_free)


## Pure (tested): one step of the damped spring that makes leaves bounce back after a bump.
static func spring_step(tilt: Vector2, vel: Vector2, delta: float) -> Array:
	var dt := minf(delta, 0.033)
	vel += (-tilt * 130.0 - vel * 7.0) * dt
	tilt += vel * dt
	return [tilt, vel]


## Shove the leaves (x = lean about the x axis, y = about z, in radians-ish).
func kick(push: Vector2) -> void:
	_tilt_vel += push * 7.0


func _process(delta: float) -> void:
	if state != State.PLANTED or giant or _crop == null:
		return
	var pl := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if pl != null:
		var off := Vector2(global_position.x - pl.global_position.x, global_position.z - pl.global_position.z)
		var spd := Vector2(pl.velocity.x, pl.velocity.z).length()
		if spd > 1.0 and off.length() < RUSTLE_RADIUS and _tilt_vel.length() < 0.8:
			var away := off.normalized()
			kick(Vector2(away.y, -away.x) * clampf(spd * 0.07, 0.1, 0.45))
			if growth > 0:
				Sfx.play_on(self, "rustle", 1.0 + randf() * 0.4)
	if _tilt.length_squared() < 0.00001 and _tilt_vel.length_squared() < 0.00001:
		return
	var r := spring_step(_tilt, _tilt_vel, delta)
	_tilt = r[0]
	_tilt_vel = r[1]
	_crop.rotation = Vector3(_tilt.x, 0, _tilt.y)


func _pop_crop() -> void:
	if not is_inside_tree():
		return
	_crop.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(_crop, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func on_new_day(_game: GameState) -> void:
	slept_wet = watered
	var grew := false
	if state == State.PLANTED and watered and growth < grow_days() and not giant:
		growth += 1
		grew = true
	watered = false
	_refresh()
	if grew:
		_pop_crop()


## Rain overnight: planted/tilled soil is already wet in the morning.
func rain_water() -> void:
	if state != State.GRASS:
		watered = true
		_apply_soil(false)


## FarmField: these four plots just became one enormous vegetable.
func make_giant() -> void:
	giant = true
	_refresh()


## The giant has been uprooted: back to bare tilled soil.
func clear_giant() -> void:
	giant = false
	state = State.TILLED
	growth = 0
	picks = 0
	composted = false
	_refresh()


func to_dict() -> Dictionary:
	return {"state": state, "watered": watered, "growth": growth, "crop": crop,
		"composted": composted, "picks": picks, "giant": giant}


func from_dict(d: Dictionary) -> void:
	state = int(d.get("state", State.GRASS))
	watered = bool(d.get("watered", false))
	growth = int(d.get("growth", 0))
	crop = str(d.get("crop", "turnip"))
	composted = bool(d.get("composted", false))
	picks = int(d.get("picks", 0))
	giant = bool(d.get("giant", false))
	slept_wet = false
	if not GameState.CROPS.has(crop):
		crop = "turnip"
	_refresh()


func _apply_soil(animate: bool) -> void:
	if _soil_mat == null:
		return
	_soil_mat.set_shader_parameter("compost", 1.0 if composted else 0.0)
	var target := 1.0 if watered else 0.0
	if _wet_tween != null:
		_wet_tween.kill()
		_wet_tween = null
	if animate and is_inside_tree():
		_wet_tween = create_tween()
		_wet_tween.tween_method(func(v: float): _soil_mat.set_shader_parameter("wet", v), 0.0, target, 0.9) \
			.set_delay(0.2).set_ease(Tween.EASE_OUT)
	else:
		_soil_mat.set_shader_parameter("wet", target)


func _refresh() -> void:
	if _soil == null:
		return
	_grass.visible = state == State.GRASS
	_soil.visible = state != State.GRASS
	_apply_soil(false)
	for c in _crop.get_children():
		_crop.remove_child(c)
		c.queue_free()
	_tilt = Vector2.ZERO
	_tilt_vel = Vector2.ZERO
	_crop.rotation = Vector3.ZERO
	_crop.scale = Vector3.ONE
	var show_sparkle := is_ripe() and not giant
	if show_sparkle and _sparkle == null:
		_sparkle = FX.emitter(self, Color(1.0, 0.94, 0.55), 3, 1.4, 0.05, Vector3(0.45, 0.2, 0.45), Vector3(0, 0.25, 0), true, "sphere")
		_sparkle.position.y = 0.55
	if _sparkle != null:
		_sparkle.visible = show_sparkle
		_sparkle.emitting = show_sparkle
	if state != State.PLANTED or giant:
		return
	var plant := CropModel.plant(crop, growth, grow_days(), hash(str(name)))
	plant.rotation.y = float(posmod(hash(str(name)), 628)) * 0.01
	_crop.add_child(plant)
