class_name LanderSpot
extends Interactable
## The parked starship on the Moon: climb back in to fly home.

var program: Node


func get_prompt(_game: GameState) -> String:
	return "[E] Climb aboard and fly home"


func interact(_game: GameState) -> void:
	if program != null:
		program.fly_home()
