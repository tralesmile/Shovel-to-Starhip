class_name MeshBake
extends RefCounted
## Once a built piece has finished assembling, its dozens of boards are welded into one mesh per
## material so the graphics card is asked to draw far less. The loose boards stay (hidden) so the
## piece can still burst apart. Each welded vertex remembers where it sat on its own board
## (CUSTOM0) and that board's shade, so grain and knots look exactly as before.

const GROUP_META := "baked_mesh"

static var _baked_mats := {}


## Pure (tested): the same per-board shade the timber shader works out for a loose board.
static func board_tint(origin: Vector3) -> float:
	var p := (origin * 3.0 + Vector3.ONE * 0.37).floor()
	var s := sin(p.dot(Vector3(127.1, 311.7, 74.7))) * 43758.5453
	return s - floorf(s)


static func _timber(m: Material) -> bool:
	return m is ShaderMaterial and (m as ShaderMaterial).shader == BuildKit.SHADER


## The welded twin of a timber material (reads grain position and shade from the vertices).
static func baked_material(m: ShaderMaterial) -> ShaderMaterial:
	if not _baked_mats.has(m):
		var b := m.duplicate() as ShaderMaterial
		b.set_shader_parameter("baked", true)
		_baked_mats[m] = b
	return _baked_mats[m]


## Which of `root`'s direct children can be welded, grouped by material. Window panes light up on
## their own and doors swing, so they stay loose.
static func groups(root: Node3D) -> Dictionary:
	var out := {}
	for c in root.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null or mi.material_override == null or mi.has_meta(GROUP_META) or mi.is_in_group("window_pane"):
			continue
		var key := [mi.material_override, mi.visibility_range_end]
		if not out.has(key):
			out[key] = []
		out[key].append(mi)
	return out


## Weld. Returns how many loose parts were replaced.
static func bake(root: Node3D) -> int:
	var replaced := 0
	var by := groups(root)
	for key in by:
		var list: Array = by[key]
		if list.size() < 2:
			continue
		var mat: Material = key[0]
		var merged := _weld(list, root, _timber(mat))
		var mi := MeshInstance3D.new()
		mi.mesh = merged
		mi.material_override = baked_material(mat) if _timber(mat) else mat
		mi.visibility_range_end = key[1]
		mi.cast_shadow = (list[0] as MeshInstance3D).cast_shadow
		mi.set_meta(GROUP_META, true)
		root.add_child(mi)
		for part in list:
			(part as MeshInstance3D).visible = false
		replaced += list.size()
	return replaced


## Throw the welded meshes away and show the loose boards again.
static func unbake(root: Node3D) -> void:
	for c in root.get_children():
		if c.has_meta(GROUP_META):
			root.remove_child(c)
			c.free()
		elif c is MeshInstance3D:
			(c as MeshInstance3D).visible = true


static func _weld(list: Array, root: Node3D, timber: bool) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var custom := PackedFloat32Array()
	var index := PackedInt32Array()
	var world := root.global_transform if root.is_inside_tree() else Transform3D.IDENTITY
	for part in list:
		var mi := part as MeshInstance3D
		var xf := mi.transform
		var turn := xf.basis.inverse().transposed()
		var tint := board_tint(world * xf.origin) if timber else 0.0
		var arrays := mi.mesh.surface_get_arrays(0) if not mi.mesh is PrimitiveMesh else (mi.mesh as PrimitiveMesh).get_mesh_arrays()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv = arrays[Mesh.ARRAY_TEX_UV]
		var base := verts.size()
		for i in v.size():
			verts.append(xf * v[i])
			normals.append((turn * n[i]).normalized())
			uvs.append(uv[i] if uv != null and uv.size() > i else Vector2.ZERO)
			if timber:
				custom.append_array(PackedFloat32Array([v[i].x, v[i].y, v[i].z, tint]))
		var ind = arrays[Mesh.ARRAY_INDEX]
		if ind == null or ind.is_empty():
			for i2 in v.size():
				index.append(base + i2)
		else:
			for i3 in ind:
				index.append(base + i3)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_INDEX] = index
	var flags := 0
	if timber:
		out[Mesh.ARRAY_CUSTOM0] = custom
		flags = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, flags)
	return mesh
