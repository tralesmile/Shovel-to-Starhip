class_name BuildPiece
extends StaticBody3D
## One placed building piece (fence panel or stone wall). Pops in with a squash bounce and dust;
## crumbles into debris when demolished.

var piece_id := "fence_panel"
var rot := 0
var _mesh: Node3D


func _ready() -> void:
	var def: Dictionary = BuildWorld.PIECES[piece_id]
	var sz: Vector3 = def["size"]
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = sz
	col.shape = bs
	col.position.y = sz.y * 0.5
	add_child(col)
	_mesh = Node3D.new()
	add_child(_mesh)
	var c: Color = def["color"]
	if def["style"] == "fence":
		for sx in [-0.85, 0.85]:
			var post := Art.box(Vector3(0.16, sz.y + 0.15, 0.16), c.darkened(0.15))
			post.position = Vector3(sx, (sz.y + 0.15) * 0.5, 0)
			_mesh.add_child(post)
		for ry in [0.3, 0.68]:
			var rail := Art.box(Vector3(sz.x, 0.12, 0.08), c)
			rail.position = Vector3(0, ry, 0)
			_mesh.add_child(rail)
	else:
		for row in 3:
			var off := 0.0 if row % 2 == 0 else 0.25
			for k in 2:
				var b := Art.box(Vector3(0.95, sz.y / 3.0 - 0.03, sz.z), c.lightened(0.06 * ((row + k) % 2)))
				b.position = Vector3(-0.5 + k * 1.0 + off - 0.12, sz.y / 6.0 + row * sz.y / 3.0, 0)
				_mesh.add_child(b)
	rotation.y = BuildWorld.yaw_of(rot)


## Squash-and-bounce arrival (juice): drops in tall, lands wide, settles.
func pop_in() -> void:
	_mesh.scale = Vector3(0.7, 1.6, 0.7)
	_mesh.position.y = 0.6
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_mesh, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_mesh, "scale", Vector3(1.1, 0.85, 1.1), 0.22).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(_mesh, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var c: Color = BuildWorld.PIECES[piece_id]["color"]
	get_tree().create_timer(0.2).timeout.connect(func():
		if is_inside_tree():
			FX.burst(self, global_position + Vector3(0, 0.1, 0), Color(0.78, 0.7, 0.55), 12, 0.12, 2.0, -1.0, "sphere", 80.0)
			FX.burst(self, global_position + Vector3(0, 0.4, 0), c, 6, 0.08, 2.5))


## Demolish: debris burst, then free.
func crumble() -> void:
	var c: Color = BuildWorld.PIECES[piece_id]["color"]
	var parent := get_parent()
	if parent != null:
		FX.burst(parent, global_position + Vector3(0, 0.5, 0), c, 14, 0.1, 3.5)
	queue_free()
