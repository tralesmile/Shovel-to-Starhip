class_name Models
extends RefCounted
## Loads CC0 model packs (KayKit, Kenney) and places them with optional collision.

const MED := "res://assets/kaykit_medieval/"
const CITY := "res://assets/kaykit_city/"
const CHAR := "res://assets/kaykit_characters/"
const FOOD := "res://assets/kaykit_restaurant/"
const SPACE := "res://assets/kaykit_space/"
const KENNEY := "res://assets/kenney/"

static var _scenes: Dictionary = {}


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## Instance a model. pos = where its base sits, rot_y in radians.
static func put(parent: Node, path: String, pos: Vector3, scale: float = 1.0, rot_y: float = 0.0) -> Node3D:
	var inst: Node3D = scene(path).instantiate()
	var f := path.get_file()
	var wind := 0.0
	if f.begins_with("tree") or f.begins_with("bush"):
		wind = 0.05
	var windows := f.begins_with("building_")
	Toon.apply(inst, wind, windows, not f.begins_with("cloud"))
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = Vector3.ONE * scale
	parent.add_child(inst)
	return inst


## Instance a model inside a StaticBody3D with a box collider fitted to its bounds.
static func solid(parent: Node, path: String, pos: Vector3, scale: float = 1.0, rot_y: float = 0.0, shrink: float = 0.9) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	parent.add_child(body)
	var inst := put(body, path, Vector3.ZERO, scale)
	var box := local_aabb(inst, body)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(box.size.x * shrink, box.size.y, box.size.z * shrink)
	shape.shape = bs
	shape.position = box.get_center()
	body.add_child(shape)
	return body


## Bounds of all meshes under node, in the space of relative_to.
static func local_aabb(node: Node3D, relative_to: Node3D) -> AABB:
	var inv := relative_to.global_transform.affine_inverse() if relative_to.is_inside_tree() else Transform3D.IDENTITY
	var result := AABB()
	var first := true
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if not mi.visible:
			continue
		var xf: Transform3D
		if relative_to.is_inside_tree():
			xf = inv * mi.global_transform
		else:
			xf = _relative_xf(mi, relative_to)
		var b := xf * mi.get_aabb()
		if first:
			result = b
			first = false
		else:
			result = result.merge(b)
	return result


static func _relative_xf(n: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## First mesh found inside a model file (for MultiMesh scattering).
static func first_mesh(path: String) -> Mesh:
	var inst: Node = scene(path).instantiate()
	var mesh: Mesh = null
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		mesh = (c as MeshInstance3D).mesh
		break
	inst.free()
	return mesh


## Loop the named animations (KayKit imports them as play-once).
static func set_loops(player: AnimationPlayer, names: Array) -> void:
	for n in names:
		if player.has_animation(n):
			player.get_animation(n).loop_mode = Animation.LOOP_LINEAR
