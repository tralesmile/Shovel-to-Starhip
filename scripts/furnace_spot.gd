class_name FurnaceSpot
extends Interactable
## A placed Stone Furnace: E feeds ore + wood fuel, 4s later an ingot pops out. Glows and smokes while smelting.

var mouth: MeshInstance3D
var _smoke: CPUParticles3D
var _light: OmniLight3D
var _t := 0.0
var _queue: Array = []   ## seconds left per batch
var _out: Array = []


## Pure (tested): first smeltable ore the player can afford (ore + fuel), or "".
static func smelt_ready(inv: Dictionary) -> String:
	for ore in GameState.SMELTABLE.keys():
		var d: Dictionary = GameState.SMELTABLE[ore]
		if int(inv.get(ore, 0)) >= int(d["ore"]) and int(inv.get("wood", 0)) >= int(d["fuel"]):
			return ore
	return ""


## Pure (tested): mouth glow strength; hot while smelting, dim ember when idle.
static func glow(busy: bool, t: float) -> float:
	return (1.6 + 0.4 * sin(t * 11.0)) if busy else 0.5


func _ready() -> void:
	_smoke = FX.emitter(self, Color(0.5, 0.5, 0.54, 0.5), 10, 2.2, 0.24, Vector3(0.08, 0.02, 0.08), Vector3(0.1, 1.0, 0), false, "sphere")
	_smoke.position = Vector3(0.25, 1.55, -0.2)
	_smoke.emitting = false
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = 5.0
	_light.position = Vector3(0, 0.5, 0.9)
	_light.light_energy = 0.0
	add_child(_light)


func get_prompt(game: GameState) -> String:
	var ore := smelt_ready(game.inventory)
	if ore != "":
		return "[E] Smelt %s (+1 Wood fuel) -> %s" % [GameState.ITEMS[ore]["name"], GameState.ITEMS[GameState.SMELTABLE[ore]["out"]]["name"]]
	if _queue.size() > 0:
		return "Roaring... (%d smelting)" % _queue.size()
	return "Stone Furnace. Bring Copper Ore and Wood for fuel."


func interact(game: GameState) -> void:
	var ore := smelt_ready(game.inventory)
	if ore == "":
		game.say("The furnace burps. It wants ore AND wood.")
		return
	var d: Dictionary = GameState.SMELTABLE[ore]
	game.remove_item(ore, int(d["ore"]))
	game.remove_item("wood", int(d["fuel"]))
	_queue.append(GameState.SMELT_TIME)
	_out.append(d["out"])
	Sfx.play_on(self, "sizzle", 0.8)
	FX.burst(self, global_position + Vector3(0, 0.5, 0.6), Color(1.0, 0.7, 0.2), 10, 0.07, 3.0, -4.0, "sphere", 60.0)
	game.say("Whoosh! The furnace takes it. Smelting...")


func _process(delta: float) -> void:
	_t += delta
	var busy := _queue.size() > 0
	if _smoke != null:
		_smoke.emitting = busy
	if _light != null:
		_light.light_energy = glow(busy, _t) * 1.4 if busy else 0.0
	if mouth != null and mouth.material_override is StandardMaterial3D:
		var m := mouth.material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission = Color(1.0, 0.45, 0.1)
		m.emission_energy_multiplier = glow(busy, _t)
	for i in range(_queue.size() - 1, -1, -1):
		_queue[i] -= delta
		if _queue[i] <= 0.0:
			var id: String = _out[i]
			_queue.remove_at(i)
			_out.remove_at(i)
			_done(id)


func _done(id: String) -> void:
	var host := get_parent()
	if host == null:
		return
	var p := WoodLog.new()
	p.game = get_node("/root/Game")
	p.item_id = id
	p.amount = 1
	p.chunk_color = WoodLog.drop_color(id)
	host.add_child(p)
	p.global_position = global_position + Vector3(0, 1.0, 0.8)
	p.pop()
	FX.burst(self, global_position + Vector3(0, 0.5, 0.7), Color(1.0, 0.9, 0.5), 12, 0.1, 3.0, -2.0, "sphere", 70.0)
	Sfx.play_on(self, "happy")
	p.game.say("Clang! A fresh ingot, still too hot to lick.")
