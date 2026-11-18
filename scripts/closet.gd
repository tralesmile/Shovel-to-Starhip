class_name Closet
extends Interactable
## A wardrobe in a home. E to squeeze in and hide: heat cools 3x as fast while
## you stay inside. E again (or walking away) climbs out.

const EXIT_DIST := 2.2


func _enter_tree() -> void:
	super._enter_tree()
	add_to_group("closet")


func get_prompt(game: GameState) -> String:
	return "[E] Climb out (smells of mothballs)" if game.in_closet else "[E] Hide in the wardrobe (Narnia not guaranteed)"


func interact(game: GameState) -> void:
	game.in_closet = not game.in_closet
	if game.in_closet:
		game.say("You squeeze between the coats. It is snug, dark and judgemental.")
	else:
		game.say("You climb out of the wardrobe, wearing a scarf that is not yours.")


## True when the player has wandered too far from the closet to still be inside.
static func out_of_reach(player_pos: Vector3, closet_pos: Vector3) -> bool:
	return player_pos.distance_to(closet_pos) > EXIT_DIST


## The player model is only drawn when walking about in the open (not driving, not in a wardrobe).
static func model_visible(in_closet: bool, driving: bool) -> bool:
	return not in_closet and not driving


## Camera arm length: peeks out from the coats (tight) while hiding, normal zoom otherwise.
const PEEK_ZOOM := 2.2

static func camera_zoom(in_closet: bool, normal_zoom: float) -> float:
	return minf(PEEK_ZOOM, normal_zoom) if in_closet else normal_zoom
