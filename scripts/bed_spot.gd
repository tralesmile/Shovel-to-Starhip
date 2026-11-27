class_name BedSpot
extends Interactable
## A placed Wood Bed is a real bed: press E near it to sleep until morning.


func get_prompt(_game: GameState) -> String:
	return "[E] Sleep in your homemade bed"


func interact(game: GameState) -> void:
	FX.burst(self, global_position + Vector3(0, 0.6, 0), Color(0.85, 0.9, 1.0), 6, 0.1, 1.2, -0.5, "sphere", 60.0)
	game.say("You flop onto the lumpy bed. Zzz...")
	var bw := get_tree().get_first_node_in_group("buildworld") as BuildWorld if is_inside_tree() else null
	var cosy := bw.comfort_at(get_parent() as BuildPiece) if bw != null else 0
	game.sleep()
	game.rested = cosy
	if cosy > 0:
		game.say(BuildGrid.comfort_line(cosy))
