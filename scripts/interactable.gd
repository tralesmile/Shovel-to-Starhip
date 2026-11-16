class_name Interactable
extends Node3D
## Base for anything the player can use with E / left click.

@export var interact_radius: float = 1.6


func _enter_tree() -> void:
	add_to_group("interactable")


## Text shown at the bottom of the screen when the player is close.
func get_prompt(_game: GameState) -> String:
	return ""


## Called when the player presses E near this object.
func interact(_game: GameState) -> void:
	pass
