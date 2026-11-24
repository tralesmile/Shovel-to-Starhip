class_name CampfireSpot
extends Interactable
## A placed Campfire: flickering flame + smoke, a warm light, and E roasts raw meat (3s sizzle).
## Roasted food pops out as a physics pickup.

var _flame: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D
var _t := 0.0
var _cooking: Array = []   ## seconds left per item being roasted (output ids in _out)
var _out: Array = []


## Pure (tested): flame light energy for time t. Layered sines read as flicker; never goes dark.
static func flicker(t: float, base: float = 2.6) -> float:
	return base * (0.82 + 0.1 * sin(t * 13.0) + 0.06 * sin(t * 29.0 + 1.3) + 0.04 * sin(t * 7.1))


## Pure (tested): what a raw item turns into, or "" when it cannot be cooked.
static func cooked_id(raw: String) -> String:
	return GameState.COOKABLE.get(raw, "")


## Pure (tested): first cookable item the player holds, or "".
static func raw_in(inv: Dictionary) -> String:
	for raw in GameState.COOKABLE.keys():
		if int(inv.get(raw, 0)) > 0:
			return raw
	return ""


func _ready() -> void:
	_flame = FX.emitter(self, Color(1.0, 0.62, 0.15), 28, 0.7, 0.14, Vector3(0.12, 0.02, 0.12), Vector3(0, 2.2, 0), true, "sphere")
	_flame.position.y = 0.2
	_flame.spread = 14
	_flame.initial_velocity_min = 0.2
	_flame.initial_velocity_max = 0.7
	_flame.emitting = true
	_smoke = FX.emitter(self, Color(0.55, 0.55, 0.58, 0.55), 10, 2.4, 0.22, Vector3(0.08, 0.02, 0.08), Vector3(0.1, 0.9, 0), false, "sphere")
	_smoke.position.y = 0.7
	_smoke.spread = 25
	_smoke.emitting = true
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.65, 0.3)
	_light.omni_range = 6.5
	_light.position.y = 0.6
	add_child(_light)


func get_prompt(game: GameState) -> String:
	var raw := raw_in(game.inventory)
	if raw != "":
		return "[E] Roast %s over the fire" % GameState.ITEMS[raw]["name"]
	if _cooking.size() > 0:
		return "Sizzling... (%d roasting)" % _cooking.size()
	return "Warm fire. Bring raw meat to roast."


func interact(game: GameState) -> void:
	var raw := raw_in(game.inventory)
	if raw == "":
		game.say("You warm your hands. Toasty.")
		return
	game.remove_item(raw, 1)
	_cooking.append(GameState.COOK_TIME)
	_out.append(cooked_id(raw))
	Sfx.play_on(self, "sizzle")
	FX.burst(self, global_position + Vector3(0, 0.7, 0), Color(1.0, 0.8, 0.3), 6, 0.07, 2.0, -1.0, "sphere", 40.0)
	game.say("Sizzle sizzle...")


func _process(delta: float) -> void:
	_t += delta
	if _light != null:
		_light.light_energy = flicker(_t)
	for i in range(_cooking.size() - 1, -1, -1):
		_cooking[i] -= delta
		if _cooking[i] <= 0.0:
			var id: String = _out[i]
			_cooking.remove_at(i)
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
	p.global_position = global_position + Vector3(0.3, 0.9, 0.3)
	p.pop()
	FX.burst(self, global_position + Vector3(0, 0.8, 0), Color(1, 1, 1), 8, 0.1, 2.0, -1.0, "sphere", 50.0)
	Sfx.play_on(self, "happy")
	p.game.say("Ding! Perfectly roasted (only slightly on fire).")
