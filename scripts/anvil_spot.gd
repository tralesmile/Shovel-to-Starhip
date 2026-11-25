class_name AnvilSpot
extends Interactable
## A placed Anvil: each E strike hammers; after 3 strikes 2 copper ingots become a Rocket Hull Plate.

var face: MeshInstance3D
var _strikes := 0
var _squash := 0.0


## Pure (tested): first anvil recipe the inventory can pay for, or {}.
static func ready_recipe(inv: Dictionary) -> Dictionary:
	for r in GameState.ANVIL_RECIPES:
		var ok := true
		for id in r["in"]:
			if int(inv.get(id, 0)) < int(r["in"][id]):
				ok = false
		if ok:
			return r
	return {}


## Pure (tested): anvil face squash after a hammer blow (1 = rest, dips then recovers).
static func strike_squash(t: float) -> float:
	return 1.0 - 0.25 * clampf(1.0 - t * 6.0, 0.0, 1.0)


func get_prompt(game: GameState) -> String:
	var r := ready_recipe(game.inventory)
	if r.is_empty():
		return "Anvil. Bring 2 Copper Ingots to hammer a Hull Plate."
	return "[E] Hammer %s (strike %d/%d)" % [GameState.ITEMS[r["out"]]["name"], _strikes + 1, int(r["strikes"])]


func interact(game: GameState) -> void:
	var r := ready_recipe(game.inventory)
	if r.is_empty():
		game.say("You tap the anvil. It rings out of pity.")
		return
	_strikes += 1
	_squash = 0.15
	Sfx.play_on(self, "clang", 1.0 + 0.08 * _strikes)
	FX.burst(self, global_position + Vector3(0, 0.85, 0), Color(1.0, 0.8, 0.3), 8 + _strikes * 4, 0.06, 4.0, -9.0, "sphere", 80.0)
	FX.hit_stop(get_tree(), 0.3)
	if _strikes >= int(r["strikes"]):
		_strikes = 0
		for id in r["in"]:
			game.remove_item(id, int(r["in"][id]))
		game.add_item(r["out"], 1)
		game.shake.emit(0.3)
		FX.burst(self, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.95, 0.6), 24, 0.1, 5.0, -6.0, "sphere", 120.0)
		Sfx.play_on(self, "happy")
		game.say("CLANG! A Hull Plate. The Moon is getting nervous.")


func _process(delta: float) -> void:
	if _squash > 0.0:
		_squash = maxf(0.0, _squash - delta)
	if face != null:
		face.scale.y = strike_squash(0.15 - _squash) if _squash > 0.0 else 1.0
