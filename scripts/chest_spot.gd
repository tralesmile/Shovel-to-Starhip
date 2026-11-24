class_name ChestSpot
extends Interactable
## A placed Storage Chest. E stashes everything stashable (Terraria Quick Stack); with nothing to
## stash, E hauls it all back out. All chests share one stash (Gran's magic chest network).

var lid: Node3D
var _open_t: float = 0.0


## Pure (tested): lid angle (radians, negative = opens upward) for an open timer 0..1.
static func lid_angle(t: float) -> float:
	return -1.9 * clampf(t, 0.0, 1.0)


func get_prompt(game: GameState) -> String:
	var held := 0
	for id in game.inventory:
		if GameState.stashable(id):
			held += int(game.inventory[id])
	var inside := 0
	for id in game.stash:
		inside += int(game.stash[id])
	if held > 0:
		return "[E] Quick stack %d item(s) into the chest (%d inside)" % [held, inside]
	if inside > 0:
		return "[E] Take everything out (%d item(s))" % inside
	return "An empty chest. Nothing to stash."


func interact(game: GameState) -> void:
	_open_t = 1.4
	Sfx.play_on(self, "thud", 1.3)
	var n := game.chest_deposit()
	if n > 0:
		FX.burst(self, global_position + Vector3(0, 0.7, 0), Color(1.0, 0.9, 0.5), 8, 0.08, 2.0, -1.0, "sphere", 120.0)
		game.say("Stashed %d item(s). Your back thanks you." % n)
		return
	n = game.chest_withdraw()
	if n > 0:
		FX.burst(self, global_position + Vector3(0, 0.7, 0), Color(1.0, 0.9, 0.5), 8, 0.08, 3.0, 1.0, "sphere", 120.0)
		game.say("Took %d item(s) out. Hope you can carry it all." % n)
	else:
		game.say("Empty. Even the spiders moved out.")


func _process(delta: float) -> void:
	_open_t = maxf(0.0, _open_t - delta)
	if lid != null:
		lid.rotation.x = lerpf(lid.rotation.x, lid_angle(minf(1.0, _open_t * 2.0)), 12.0 * delta)
