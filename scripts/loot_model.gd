class_name LootModel
extends RefCounted
## Code-built models for the stolen goods, so loot is something you can see
## pop out of a drawer (no external assets).

const GOLD := Color(1.0, 0.78, 0.18)


static func make(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"gold_spoon":
			var handle := Art.box(Vector3(0.05, 0.3, 0.03), GOLD)
			n.add_child(handle)
			var bowl := Art.sphere(0.09, GOLD)
			bowl.scale = Vector3(0.85, 1.15, 0.4)
			bowl.position.y = 0.22
			n.add_child(bowl)
		"suspicious_vase":
			var belly := Art.sphere(0.15, Color(0.25, 0.5, 0.85))
			n.add_child(belly)
			var neck := Art.cylinder(0.08, 0.05, 0.14, Color(0.25, 0.5, 0.85), 10)
			neck.position.y = 0.18
			n.add_child(neck)
			var band := Art.cylinder(0.152, 0.152, 0.04, Color(0.95, 0.95, 0.9), 10)
			n.add_child(band)
			for sx in [-1.0, 1.0]:   # it is watching you
				var eye := Art.sphere(0.022, Color(0.05, 0.05, 0.08))
				eye.position = Vector3(sx * 0.05, 0.07, 0.135)
				n.add_child(eye)
		"garden_gnome":
			var coat := Art.cylinder(0.07, 0.13, 0.22, Color(0.2, 0.55, 0.85), 8)
			n.add_child(coat)
			var face := Art.sphere(0.08, Color(1.0, 0.8, 0.65))
			face.position.y = 0.17
			n.add_child(face)
			var beard := Art.sphere(0.075, Color(0.96, 0.96, 0.96))
			beard.scale = Vector3(1.0, 1.1, 0.6)
			beard.position = Vector3(0, 0.12, 0.055)
			n.add_child(beard)
			var hat := Art.cylinder(0.0, 0.095, 0.22, Color(0.88, 0.18, 0.15), 8)
			hat.position.y = 0.32
			n.add_child(hat)
		_:
			var body := Art.sphere(0.14, GOLD)
			body.scale = Vector3(1.0, 0.75, 1.2)
			n.add_child(body)
			var head := Art.sphere(0.085, GOLD)
			head.position = Vector3(0, 0.14, 0.09)
			n.add_child(head)
			var beak := Art.box(Vector3(0.07, 0.025, 0.07), Color(1.0, 0.45, 0.1))
			beak.position = Vector3(0, 0.13, 0.19)
			n.add_child(beak)
	return n
