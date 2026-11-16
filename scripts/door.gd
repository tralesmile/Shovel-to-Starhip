class_name Door
extends Interactable
## Walk-up door: press E to be moved to `destination` (global position).

@export var destination: Vector3 = Vector3.ZERO
@export var label: String = "Enter"


func get_prompt(_game: GameState) -> String:
	return "[E] %s" % label


func interact(_game: GameState) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		go(p)


## Moves a body through the door.
func go(body: Node3D) -> void:
	body.global_position = destination
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
