class_name FarmPlot
extends Interactable
## One 2x2 m patch of land: grass -> tilled -> planted -> ripe -> harvest.
## A planted crop grows one stage each night it went to bed watered.

enum State { GRASS, TILLED, PLANTED }

const SIZE := 1.8

var state: int = State.GRASS
var watered: bool = false
var growth: int = 0
var crop: String = "turnip"

var _soil: MeshInstance3D
var _crop: Node3D


func _ready() -> void:
	add_to_group("daily")
	add_to_group("saveable")
	interact_radius = 1.5
	_soil = Art.box(Vector3(SIZE, 0.06, SIZE), Art.GRASS)
	_soil.position.y = 0.03
	add_child(_soil)
	_crop = Node3D.new()
	add_child(_crop)
	_refresh()


func grow_days() -> int:
	return int(GameState.CROPS[crop]["days"])


func is_ripe() -> bool:
	return state == State.PLANTED and growth >= grow_days()


func get_prompt(game: GameState) -> String:
	if is_ripe():
		return "[E] Harvest %s" % crop
	match game.current_tool:
		GameState.Tool.HOE:
			return "[E] Till soil" if state == State.GRASS else ""
		GameState.Tool.SEEDS:
			if state == State.TILLED:
				return "[E] Plant %s seed (%d left)" % [game.selected_crop, game.count(game.crop_seed_id())]
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
			return "%s: %d night(s) to go, %s" % [crop.capitalize(), left, w]
	return ""


func interact(game: GameState) -> void:
	if is_ripe():
		_harvest(game)
		return
	match game.current_tool:
		GameState.Tool.HOE:
			if state == State.GRASS:
				state = State.TILLED
				game.say("Tilled! Your back says hello.")
				FX.burst(self, global_position + Vector3(0, 0.1, 0), Art.DIRT, 12, 0.12, 2.5)
		GameState.Tool.SEEDS:
			if state == State.TILLED:
				if game.remove_item(game.crop_seed_id()):
					state = State.PLANTED
					crop = game.selected_crop
					growth = 0
					FX.burst(self, global_position + Vector3(0, 0.1, 0), Color(0.85, 0.75, 0.45), 6, 0.06, 1.5)
					game.say("Planted a %s. Grow, little buddy." % crop)
				else:
					game.say("Out of %s seeds. The General Store sells them. [2] switches seeds." % game.selected_crop)
		GameState.Tool.WATER:
			if state != State.GRASS:
				if watered:
					game.say("It's already wet. Any wetter and it's a pond.")
				else:
					watered = true
					FX.burst(self, global_position + Vector3(0, 0.3, 0), Color(0.45, 0.75, 1.0), 18, 0.08, 2.0, -9.0, "sphere", 40.0)
		GameState.Tool.AXE:
			game.say("You threaten the soil with an axe. It is unimpressed.")
	_refresh()


func _harvest(game: GameState) -> void:
	var amount := 1
	# Small bonus chance keeps harvests exciting. Deterministic per plot+day for tests.
	if hash(str(name) + str(game.day)) % 5 == 0:
		amount = 2
	game.add_item(crop, amount)
	FX.burst(self, global_position + Vector3(0, 0.4, 0), Color(0.45, 0.75, 0.3), 14, 0.12, 3.0)
	FX.burst(self, global_position + Vector3(0, 0.1, 0), Art.DIRT, 8, 0.1, 2.0)
	game.say("Harvested %d %s%s!" % [amount, crop, "s" if amount > 1 else ""])
	state = State.TILLED
	growth = 0
	watered = false
	_refresh()


func on_new_day(_game: GameState) -> void:
	if state == State.PLANTED and watered and growth < grow_days():
		growth += 1
	watered = false
	_refresh()


func to_dict() -> Dictionary:
	return {"state": state, "watered": watered, "growth": growth, "crop": crop}


func from_dict(d: Dictionary) -> void:
	state = int(d.get("state", State.GRASS))
	watered = bool(d.get("watered", false))
	growth = int(d.get("growth", 0))
	crop = str(d.get("crop", "turnip"))
	if not GameState.CROPS.has(crop):
		crop = "turnip"
	_refresh()


func _refresh() -> void:
	if _soil == null:
		return
	if state == State.GRASS:
		_soil.material_override = Art.mat(Art.GRASS.darkened(0.08))
	else:
		_soil.material_override = Art.mat(Art.DIRT_WET if watered else Art.DIRT)
	for c in _crop.get_children():
		c.queue_free()
	if state != State.PLANTED:
		return
	if is_ripe():
		var cd: Dictionary = GameState.CROPS[crop]
		Models.put(_crop, Models.FOOD + cd["model"], Vector3(0, cd["y"], 0), cd["scale"], hash(name) % 6)
	else:
		var sc := 0.18 + 0.12 * growth
		Models.put(_crop, Models.FOOD + "food_ingredient_lettuce.gltf", Vector3(0, 0.02, 0), sc, hash(name) % 6)
