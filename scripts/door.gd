class_name Door
extends Interactable
## Walk-up door: press E to be moved to `destination` (global position). The leaf
## creaks open on its hinge and the screen blinks before you step through.

const SWING_TIME := 0.34
const OPEN_ANGLE := -1.75

@export var destination: Vector3 = Vector3.ZERO
@export var label: String = "Enter"

var hinge: Node3D = null
var opening := false
var open_angle := OPEN_ANGLE   ## flips for doors that must swing the other way


## Builds the visible leaf, hung on a hinge along its left edge, plus a frame.
func attach_leaf() -> void:
	var frame := Art.WOOD.darkened(0.42)
	for sx in [-0.62, 0.62]:
		var post := Art.box(Vector3(0.14, 2.22, 0.18), frame)
		post.position = Vector3(sx, 1.11, 0)
		add_child(post)
	var lintel := Art.box(Vector3(1.38, 0.14, 0.18), frame)
	lintel.position.y = 2.2
	add_child(lintel)
	hinge = Node3D.new()
	hinge.position = Vector3(-0.55, 0, 0)
	add_child(hinge)
	var leaf := Art.box(Vector3(1.1, 2.1, 0.12), Art.WOOD.darkened(0.2))
	leaf.position = Vector3(0.55, 1.05, 0)
	hinge.add_child(leaf)
	for y in [0.55, 1.55]:
		var panel := Art.box(Vector3(0.72, 0.62, 0.16), Art.WOOD.darkened(0.3))
		panel.position = Vector3(0.55, y, 0)
		hinge.add_child(panel)
	for sz in [-0.1, 0.1]:
		var knob := Art.sphere(0.06, LootModel.GOLD)
		knob.position = Vector3(0.94, 1.02, sz)
		hinge.add_child(knob)


func get_prompt(_game: GameState) -> String:
	return "[E] %s" % label


func interact(_game: GameState) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or opening:
		return
	opening = true
	Sfx.play_on(self, "creak", 1.0 + randf() * 0.2)
	if hinge != null:
		var tw := hinge.create_tween()
		tw.tween_property(hinge, "rotation:y", open_angle, SWING_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.5)
		tw.tween_property(hinge, "rotation:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(Sfx.play_on.bind(self, "thud", 1.3))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.wipe()
	get_tree().create_timer(SWING_TIME).timeout.connect(_step_through.bind(p))


func _step_through(p: Node3D) -> void:
	opening = false
	if is_instance_valid(p):
		go(p)


## Moves a body through the door.
func go(body: Node3D) -> void:
	body.global_position = destination
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
