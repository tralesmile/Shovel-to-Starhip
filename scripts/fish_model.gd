class_name FishModel
extends RefCounted
## Procedural low-poly catches (no downloaded assets): four fish, one boot, one hat.
## Models face +X, about `LENGTH` long at scale 1.

const LENGTH := 0.6
const COLORS := {
	"minnow": [Color(0.62, 0.78, 0.86), Color(0.92, 0.96, 1.0)],
	"carp": [Color(0.72, 0.46, 0.24), Color(0.95, 0.76, 0.46)],
	"trout": [Color(0.36, 0.56, 0.42), Color(0.95, 0.6, 0.62)],
	"golden_carp": [Color(1.0, 0.74, 0.1), Color(1.0, 0.92, 0.45)],
}


static func has_model(id: String) -> bool:
	return Fishing.SIZES.has(id)


## Visual scale for a catch of `cm` centimetres (readable even for a minnow).
static func scale_for(cm: int) -> float:
	return clampf(0.55 + cm / 80.0, 0.6, 1.5)


static func build(id: String) -> Node3D:
	if id == "boot":
		return _boot()
	if id == "old_wizard_hat":
		return _hat()
	var cols: Array = COLORS.get(id, COLORS["minnow"])
	var root := Node3D.new()
	var shiny := id == "golden_carp"
	var body := _part(root, Art.sphere(0.2, cols[0], 5, 9), Vector3.ZERO, Vector3(1.45, 0.82 if id != "minnow" else 0.62, 0.52))
	var belly := _part(root, Art.sphere(0.17, cols[1], 4, 8), Vector3(0.02, -0.05, 0), Vector3(1.45, 0.62, 0.56))
	if shiny:
		body.material_override = Art.mat(cols[0], true)
		belly.material_override = Art.mat(cols[1], true)
	# Two tail lobes and a back fin.
	for s in [-1.0, 1.0]:
		var lobe := _part(root, Art.box(Vector3(0.18, 0.07, 0.035), cols[0].darkened(0.12)), Vector3(-0.34, 0.055 * s, 0), Vector3.ONE)
		lobe.rotation.z = -0.65 * s
	var fin := _part(root, Art.box(Vector3(0.17, 0.08, 0.03), cols[0].darkened(0.2)), Vector3(-0.03, 0.17, 0), Vector3.ONE)
	fin.rotation.z = 0.25
	for s in [-1.0, 1.0]:
		_part(root, Art.sphere(0.045, Color.WHITE, 4, 7), Vector3(0.18, 0.04, 0.083 * s), Vector3.ONE)
		_part(root, Art.sphere(0.022, Color(0.05, 0.05, 0.08), 3, 6), Vector3(0.2, 0.04, 0.12 * s), Vector3.ONE)
	if id == "trout":
		for i in 4:
			for s in [-1.0, 1.0]:
				var dot := Art.box(Vector3(0.03, 0.03, 0.008), Color(0.93, 0.8, 0.35))
				_part(root, dot, Vector3(-0.14 + 0.08 * i, 0.055 - 0.035 * (i % 2), 0.098 * s), Vector3.ONE)
	return root


static func _part(root: Node3D, mi: MeshInstance3D, pos: Vector3, sc: Vector3) -> MeshInstance3D:
	mi.position = pos
	mi.scale = sc
	root.add_child(mi)
	return mi


static func _boot() -> Node3D:
	var root := Node3D.new()
	var leather := Color(0.34, 0.24, 0.16)
	_part(root, Art.box(Vector3(0.2, 0.34, 0.2), leather), Vector3(-0.1, 0.08, 0), Vector3.ONE)
	_part(root, Art.box(Vector3(0.38, 0.17, 0.21), leather), Vector3(-0.01, -0.12, 0), Vector3.ONE)
	_part(root, Art.box(Vector3(0.42, 0.05, 0.23), Color(0.12, 0.1, 0.09)), Vector3(-0.01, -0.22, 0), Vector3.ONE)
	_part(root, Art.box(Vector3(0.23, 0.05, 0.23), Color(0.6, 0.45, 0.28)), Vector3(-0.1, 0.23, 0), Vector3.ONE)
	return root


static func _hat() -> Node3D:
	var root := Node3D.new()
	var cloth := Color(0.32, 0.24, 0.66)
	_part(root, Art.cylinder(0.27, 0.29, 0.04, cloth.darkened(0.15), 12), Vector3(0, -0.14, 0), Vector3.ONE)
	_part(root, Art.cylinder(0.08, 0.17, 0.25, cloth, 10), Vector3(0, 0.0, 0), Vector3.ONE)
	var tip := _part(root, Art.cylinder(0.005, 0.085, 0.22, cloth, 8), Vector3(0.05, 0.2, 0), Vector3.ONE)
	tip.rotation.z = -0.5
	var star := _part(root, Art.sphere(0.04, Color(1.0, 0.9, 0.3), 3, 5), Vector3(0.0, -0.02, 0.15), Vector3(1, 1, 0.4))
	star.material_override = Art.mat(Color(1.0, 0.9, 0.3), true)
	return root
