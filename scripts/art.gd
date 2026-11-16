class_name Art
extends RefCounted
## Tiny helpers for placeholder low-poly art built from primitive meshes.
## These get swapped for real asset-pack models in Phase 1.

const GRASS := Color(0.30, 0.52, 0.24)
const DIRT := Color(0.55, 0.38, 0.22)
const DIRT_WET := Color(0.33, 0.22, 0.13)
const WOOD := Color(0.58, 0.40, 0.24)
const LEAF := Color(0.24, 0.55, 0.26)
const ROOF := Color(0.78, 0.28, 0.22)
const WALL := Color(0.95, 0.88, 0.72)
const ROAD := Color(0.25, 0.25, 0.28)

static func mat(color: Color, emissive: bool = false) -> Material:
	return Toon.color(color, emissive)


static func box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat(color)
	return mi


static func sphere(radius: float, color: Color, rings: int = 6, segments: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.rings = rings
	mesh.radial_segments = segments
	mi.mesh = mesh
	mi.material_override = mat(color)
	return mi


static func cylinder(top: float, bottom: float, height: float, color: Color, segments: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat(color)
	return mi


static func prism(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat(color)
	return mi


static func label(text: String, size: int = 64, color: Color = Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = int(size * 0.6)
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.01
	l.font = preload("res://assets/fonts/lilita_one_regular.ttf")
	l.visibility_range_end = 30.0
	return l


## A static solid box with collision, placed at pos (pos = bottom centre).
static func solid_box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, size.y / 2.0, 0)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.add_child(box(size, color))
	parent.add_child(body)
	return body
