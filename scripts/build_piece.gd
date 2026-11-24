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
	var by := BuildWorld.base_y(piece_id)
	if def["style"] == "doorway":
		# Two jambs + a lintel: you walk straight through the gap.
		for box in [[Vector3(0.55, sz.y, sz.z), Vector3(-0.705, sz.y * 0.5, 0)], [Vector3(0.55, sz.y, sz.z), Vector3(0.705, sz.y * 0.5, 0)], [Vector3(0.86, 0.4, sz.z), Vector3(0, sz.y - 0.2, 0)]]:
			var dc := CollisionShape3D.new()
			var db := BoxShape3D.new()
			db.size = box[0]
			dc.shape = db
			dc.position = box[1]
			add_child(dc)
	else:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(sz.x, 0.25, sz.z) if def["style"] == "roof" else sz
		col.shape = bs
		col.position.y = (0.3 if def["style"] == "roof" else sz.y * 0.5)
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
	elif def["style"] == "floor":
		# Planks laid side by side with a darker gap + a pale edge: reads as boards, not a slab.
		for k in 5:
			var shade := c.lightened(0.05) if k % 2 == 0 else c.darkened(0.06)
			var b := Art.box(Vector3(sz.x / 5.0 - 0.02, sz.y, sz.z - 0.02), shade)
			b.position = Vector3(-sz.x * 0.4 + k * sz.x * 0.2, sz.y * 0.5, 0)
			_mesh.add_child(b)
	elif def["style"] == "plank_wall":
		for k in 6:
			var shade2 := c.lightened(0.05) if k % 2 == 0 else c.darkened(0.07)
			var b2 := Art.box(Vector3(sz.x / 6.0 - 0.02, sz.y, sz.z), shade2)
			b2.position = Vector3(-sz.x * 0.417 + k * sz.x / 6.0, sz.y * 0.5, 0)
			_mesh.add_child(b2)
		for ry2 in [0.3, sz.y - 0.3]:
			var brace := Art.box(Vector3(sz.x, 0.14, sz.z + 0.06), c.darkened(0.25))
			brace.position = Vector3(0, ry2, 0)
			_mesh.add_child(brace)
	elif def["style"] == "doorway":
		for sx2 in [-0.705, 0.705]:
			var jamb := Art.box(Vector3(0.55, sz.y, sz.z), c.lightened(0.04))
			jamb.position = Vector3(sx2, sz.y * 0.5, 0)
			_mesh.add_child(jamb)
		var lintel := Art.box(Vector3(sz.x, 0.4, sz.z + 0.06), c.darkened(0.2))
		lintel.position = Vector3(0, sz.y - 0.2, 0)
		_mesh.add_child(lintel)
		# Door leaf hanging ajar on the left hinge (visual only; the gap stays walkable).
		var hinge := Node3D.new()
		hinge.position = Vector3(-0.43, 0, 0.0)
		hinge.rotation.y = 1.25
		_mesh.add_child(hinge)
		var leaf := Art.box(Vector3(0.86, sz.y - 0.42, 0.07), c.lightened(0.18))
		leaf.position = Vector3(0.43, (sz.y - 0.42) * 0.5, 0)
		hinge.add_child(leaf)
		var knob := Art.box(Vector3(0.08, 0.08, 0.14), Color(0.95, 0.8, 0.3))
		knob.position = Vector3(0.78, 1.0, 0)
		hinge.add_child(knob)
	elif def["style"] == "table":
		var top := Art.box(Vector3(sz.x, 0.1, sz.z), c.lightened(0.08))
		top.position.y = sz.y - 0.05
		_mesh.add_child(top)
		for lx in [-0.55, 0.55]:
			for lz in [-0.35, 0.35]:
				var leg := Art.box(Vector3(0.1, sz.y - 0.1, 0.1), c.darkened(0.2))
				leg.position = Vector3(lx, (sz.y - 0.1) * 0.5, lz)
				_mesh.add_child(leg)
		# A small pie, because a table with nothing on it is just a sad plank.
		var pie := Art.box(Vector3(0.24, 0.07, 0.24), Color(0.9, 0.7, 0.35))
		pie.position = Vector3(0.25, sz.y + 0.035, 0.05)
		_mesh.add_child(pie)
	elif def["style"] == "chair":
		var seat := Art.box(Vector3(0.55, 0.08, 0.55), c)
		seat.position.y = 0.45
		_mesh.add_child(seat)
		var back := Art.box(Vector3(0.55, 0.5, 0.07), c.darkened(0.12))
		back.position = Vector3(0, 0.74, -0.24)
		_mesh.add_child(back)
		for lx2 in [-0.23, 0.23]:
			for lz2 in [-0.23, 0.23]:
				var leg2 := Art.box(Vector3(0.07, 0.42, 0.07), c.darkened(0.2))
				leg2.position = Vector3(lx2, 0.21, lz2)
				_mesh.add_child(leg2)
	elif def["style"] == "bed":
		var frame := Art.box(Vector3(sz.x, 0.28, sz.z), c)
		frame.position.y = 0.26
		_mesh.add_child(frame)
		var mattress := Art.box(Vector3(sz.x - 0.1, 0.16, sz.z - 0.5), Color(0.92, 0.88, 0.8))
		mattress.position = Vector3(0, 0.48, 0.12)
		_mesh.add_child(mattress)
		var blanket := Art.box(Vector3(sz.x - 0.08, 0.1, 0.9), Color(0.85, 0.35, 0.4))
		blanket.position = Vector3(0, 0.56, 0.38)
		_mesh.add_child(blanket)
		var pillow := Art.box(Vector3(0.7, 0.14, 0.34), Color(1.0, 0.97, 0.92))
		pillow.position = Vector3(0, 0.6, -0.62)
		_mesh.add_child(pillow)
		var head := Art.box(Vector3(sz.x, 0.7, 0.1), c.darkened(0.18))
		head.position = Vector3(0, 0.5, -sz.z * 0.5 + 0.05)
		_mesh.add_child(head)
		for lx3 in [-0.5, 0.5]:
			var foot := Art.box(Vector3(0.12, 0.2, 0.12), c.darkened(0.25))
			foot.position = Vector3(lx3, 0.1, sz.z * 0.5 - 0.08)
			_mesh.add_child(foot)
		var spot := BedSpot.new()
		spot.interact_radius = 2.2
		add_child(spot)
	elif def["style"] == "lantern":
		var post := Art.box(Vector3(0.1, 1.2, 0.1), c)
		post.position.y = 0.6
		_mesh.add_child(post)
		var cage := Art.box(Vector3(0.3, 0.3, 0.3), Color(1.0, 0.8, 0.4))
		cage.material_override = Art.mat(Color(1.0, 0.8, 0.4), true)
		cage.position.y = 1.35
		_mesh.add_child(cage)
		var cap := Art.box(Vector3(0.38, 0.07, 0.38), c)
		cap.position.y = 1.54
		_mesh.add_child(cap)
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.78, 0.45)
		lt.omni_range = 7.0
		lt.light_energy = 0.0
		lt.visible = false
		lt.position.y = 1.35
		lt.add_to_group("lantern")
		_mesh.add_child(lt)
	elif def["style"] == "chest":
		# Plank box with iron bands, a domed lid hinged at the back, and a gold latch.
		var body := Art.box(Vector3(sz.x, 0.5, sz.z), c)
		body.position.y = 0.25
		_mesh.add_child(body)
		for bx in [-0.35, 0.35]:
			var band := Art.box(Vector3(0.1, 0.52, sz.z + 0.04), Color(0.3, 0.3, 0.34))
			band.position = Vector3(bx, 0.25, 0)
			_mesh.add_child(band)
		var lid_pivot := Node3D.new()
		lid_pivot.name = "LidPivot"
		lid_pivot.position = Vector3(0, 0.5, -sz.z * 0.5)
		_mesh.add_child(lid_pivot)
		var lid := Art.box(Vector3(sz.x + 0.04, 0.2, sz.z + 0.04), c.lightened(0.1))
		lid.position = Vector3(0, 0.1, sz.z * 0.5)
		lid_pivot.add_child(lid)
		var latch := Art.box(Vector3(0.14, 0.16, 0.06), Color(0.95, 0.8, 0.3))
		latch.position = Vector3(0, -0.02, sz.z + 0.04)
		lid_pivot.add_child(latch)
		var cs := ChestSpot.new()
		cs.interact_radius = 2.0
		cs.lid = lid_pivot
		add_child(cs)
	elif def["style"] == "campfire":
		# Ring of stones, crossed logs, flickering flames + smoke, and a spot to roast things.
		for k in 8:
			var a := float(k) / 8.0 * TAU
			var rock := Art.box(Vector3(0.22, 0.16, 0.2), c.lightened(0.06 * float(k % 3)))
			rock.position = Vector3(cos(a) * 0.42, 0.08, sin(a) * 0.42)
			rock.rotation.y = a
			_mesh.add_child(rock)
		for k2 in 2:
			var lg := Art.box(Vector3(0.7, 0.1, 0.1), Color(0.42, 0.28, 0.17))
			lg.position.y = 0.14
			lg.rotation.y = 0.8 + float(k2) * 1.6
			_mesh.add_child(lg)
		var spot := CampfireSpot.new()
		spot.interact_radius = 2.0
		add_child(spot)
	elif def["style"] == "roof":
		# Gable: two tilted slabs meeting at a ridge, shingle rows, gable cap hides the seam.
		for side in [-1, 1]:
			var slab := Node3D.new()
			slab.position = Vector3(side * 0.55, 0.0, 0)
			slab.rotation.z = -side * 0.5
			_mesh.add_child(slab)
			for row in 4:
				var shade3 := c.lightened(0.05) if row % 2 == 0 else c.darkened(0.08)
				var shingle := Art.box(Vector3(1.4, 0.07, sz.z / 4.0 - 0.02), shade3)
				shingle.position = Vector3(side * 0.0, 0.0, -sz.z * 0.375 + row * sz.z / 4.0)
				slab.add_child(shingle)
		var ridge := Art.box(Vector3(0.22, 0.12, sz.z), c.darkened(0.3))
		ridge.position = Vector3(0, 0.5, 0)
		_mesh.add_child(ridge)
	else:
		for row in 3:
			var off := 0.0 if row % 2 == 0 else 0.25
			for k in 2:
				var b := Art.box(Vector3(0.95, sz.y / 3.0 - 0.03, sz.z), c.lightened(0.06 * ((row + k) % 2)))
				b.position = Vector3(-0.5 + k * 1.0 + off - 0.12, sz.y / 6.0 + row * sz.y / 3.0, 0)
				_mesh.add_child(b)
	_mesh.position.y = 0.0
	rotation.y = BuildWorld.yaw_of(rot)
	position.y += by


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
