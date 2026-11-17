extends SceneTree
## Boot smoke test: godot --headless --path . --script res://tests/smoke_boot.gd
## Loads the main scene, lets it run ~120 frames, exits 0 if it survived.

var frames := 0
var scene: Node


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("SMOKE FAIL: main scene did not load")
		quit(1)
		return
	scene = packed.instantiate()
	root.add_child(scene)


func _process(_delta: float) -> bool:
	frames += 1
	if frames >= 120:
		var ok := is_instance_valid(scene) and scene.get_child_count() > 0
		print("SMOKE %s: main scene ran %d frames, %d children" % ["OK" if ok else "FAIL", frames, scene.get_child_count() if is_instance_valid(scene) else 0])
		quit(0 if ok else 1)
	return false
