class_name InventionSpot
extends Interactable
## A placed Invention Bench: each E tinkers; after a few taps the next affordable gadget pops out.
## Gadgets are one-off wearables (Magnet Gloves, Spring Boots).

var bulb: MeshInstance3D
var cog: MeshInstance3D
var cog2: MeshInstance3D
var _taps := 0
var _spin := 0.0
var _flash := 0.0
var _light: OmniLight3D


## Pure (tested): cog spin speed (rad/s): lazy idle drift, frantic while tinkering.
static func cog_speed(flash: float) -> float:
	return 0.6 + 14.0 * clampf(flash, 0.0, 1.0)


## Pure (tested): bulb emission energy, bright flash fading to a soft idle glow.
static func bulb_energy(flash: float) -> float:
	return 1.0 + 4.0 * clampf(flash, 0.0, 1.0)


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.85, 1.0)
	_light.omni_range = 4.0
	_light.light_energy = 0.4
	_light.position = Vector3(-0.4, 1.7, 0)
	add_child(_light)


func get_prompt(game: GameState) -> String:
	var r := GameState.invention_ready(game.inventory)
	if r.is_empty():
		return "Invention Bench. Magnet Gloves: 2 Ingots + Gem + Plank. Spring Boots: 2 Pelts + Ingot + 2 Planks."
	return "[E] Tinker %s (%d/%d)" % [GameState.ITEMS[r["id"]]["name"], _taps + 1, int(r["taps"])]


func interact(game: GameState) -> void:
	var r := GameState.invention_ready(game.inventory)
	if r.is_empty():
		game.say("You fiddle with a spanner. Nothing invents itself yet.")
		return
	_taps += 1
	_flash = 1.0
	Sfx.play_on(self, "zap", 0.9 + 0.1 * _taps)
	FX.burst(self, global_position + Vector3(-0.4, 1.55, 0), Color(0.5, 0.9, 1.0), 8 + _taps * 4, 0.05, 4.0, -4.0, "sphere", 180.0)
	FX.hit_stop(get_tree(), 0.2)
	if _taps >= int(r["taps"]):
		_taps = 0
		for id in r["in"]:
			game.remove_item(id, int(r["in"][id]))
		game.add_item(r["id"], 1)
		game.shake.emit(0.3)
		FX.burst(self, global_position + Vector3(0, 1.3, 0), Color(1.0, 0.95, 0.5), 26, 0.1, 5.5, -6.0, "sphere", 100.0)
		Sfx.play_on(self, "happy")
		game.say(String(r["line"]))


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 1.6)
	_spin += cog_speed(_flash) * delta
	if cog != null:
		cog.rotation.z = _spin
	if cog2 != null:
		cog2.rotation.z = _spin + PI / 4.0
	if bulb != null and bulb.material_override is StandardMaterial3D:
		(bulb.material_override as StandardMaterial3D).emission_energy_multiplier = bulb_energy(_flash)
	if _light != null:
		_light.light_energy = 0.4 + 1.6 * _flash
