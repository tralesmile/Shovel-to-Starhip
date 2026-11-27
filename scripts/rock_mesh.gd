class_name RockMesh
extends RefCounted
## Code-built boulders that really come apart. A lumpy sphere is cut into Voronoi wedges: together
## they look like one rock, and each one can be knocked off on its own, leaving fresh broken faces
## around a smaller core. Vertices stay in rock space, so a flying shard keeps its own markings.
## UV.x marks the surface kind for the shader: 0 weathered skin, 0.5 fresh break, 1 the core.

const INNER := 0.5        ## how far in (0..1) a wedge reaches
const CORE := 0.57        ## the core is a touch bigger so no gap shows between wedges and core
const UV_SKIN := 0.0
const UV_BREAK := 0.5
const UV_CORE := 1.0


## Pure (tested): evenly spread directions for the wedge centres (golden-angle spiral).
static func seed_dirs(count: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := []
	var spin := rng.randf() * TAU
	for i in count:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(count)
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var a := spin + float(i) * 2.39996
		var d := Vector3(cos(a) * r, y, sin(a) * r)
		d += Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
		out.append(d.normalized())
	return out


## Unit icosphere as [vertices, triangle indices]. Triangles wind counter-clockwise seen from outside.
static func icosphere(subdiv: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts := []
	for v in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
			Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append((v as Vector3).normalized())
	var tris := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for s in subdiv:
		var mids := {}
		var next := []
		for tri in tris:
			var m := []
			for e in 3:
				var a: int = tri[e]
				var b: int = tri[(e + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not mids.has(key):
					mids[key] = verts.size()
					verts.append(((verts[a] as Vector3) + (verts[b] as Vector3)).normalized())
				m.append(mids[key])
			next.append([tri[0], m[0], m[2]])
			next.append([tri[1], m[1], m[0]])
			next.append([tri[2], m[2], m[1]])
			next.append([m[0], m[1], m[2]])
		tris = next
	return [verts, tris]


## Pure (tested): the lumpy radius multiplier in a direction.
static func lump(dir: Vector3, seed_value: int, amount: float = 0.16) -> float:
	var s := float(seed_value % 97)
	var n := sin(dir.x * 3.1 + s) * sin(dir.y * 2.7 + s * 1.7) + sin(dir.z * 4.3 + s * 0.6) * 0.6 \
		+ sin((dir.x + dir.z) * 6.1 + dir.y * 5.0 + s * 2.3) * 0.35
	return 1.0 + n * amount * 0.6


## A point on (or inside) the boulder: radii squash it, `center` lifts it, the ground flattens it.
static func shape_point(dir: Vector3, depth: float, radii: Vector3, center: Vector3, seed_value: int) -> Vector3:
	var p := center + dir * radii * lump(dir, seed_value) * depth
	p.y = maxf(p.y, 0.02 * depth)
	return p


## Cuts the boulder into wedges: [{dir, centroid, skin: PackedVector3Array, cut: PackedVector3Array}].
## Both arrays are triangle lists wound counter-clockwise seen from outside the wedge.
static func fracture(count: int, radii: Vector3, center: Vector3, seed_value: int, subdiv: int = 2) -> Array:
	var ico := icosphere(subdiv)
	var dirs: Array = ico[0]
	var tris: Array = ico[1]
	var seeds := seed_dirs(count, seed_value)
	var owned := []
	for i in count:
		owned.append([])
	for tri in tris:
		var c: Vector3 = ((dirs[tri[0]] as Vector3) + (dirs[tri[1]] as Vector3) + (dirs[tri[2]] as Vector3)).normalized()
		var best := 0
		for i in range(1, count):
			if c.dot(seeds[i]) > c.dot(seeds[best]):
				best = i
		owned[best].append(tri)
	var out := []
	for i in count:
		if owned[i].is_empty():
			continue
		var skin := PackedVector3Array()
		var cut := PackedVector3Array()
		var edges := {}
		for tri in owned[i]:
			var o := []
			var inn := []
			for k in 3:
				o.append(shape_point(dirs[tri[k]], 1.0, radii, center, seed_value))
				inn.append(shape_point(dirs[tri[k]], INNER, radii, center, seed_value))
				edges[Vector2i(tri[k], tri[(k + 1) % 3])] = true
			skin.append_array(PackedVector3Array([o[0], o[1], o[2]]))
			cut.append_array(PackedVector3Array([inn[0], inn[2], inn[1]]))   # inner cap faces the core
		for e in edges:
			if edges.has(Vector2i(e.y, e.x)):
				continue   # shared inside this wedge
			var a := shape_point(dirs[e.x], 1.0, radii, center, seed_value)
			var b := shape_point(dirs[e.y], 1.0, radii, center, seed_value)
			var ai := shape_point(dirs[e.x], INNER, radii, center, seed_value)
			var bi := shape_point(dirs[e.y], INNER, radii, center, seed_value)
			cut.append_array(PackedVector3Array([b, a, ai, b, ai, bi]))
		var mid := Vector3.ZERO
		for v in skin:
			mid += v
		mid /= float(skin.size())
		out.append({"dir": seeds[i], "centroid": mid.lerp(center, (1.0 - INNER) * 0.4), "skin": skin, "cut": cut})
	return out


static func _add(st: SurfaceTool, verts: PackedVector3Array, kind: float) -> void:
	for i in range(0, verts.size(), 3):
		var a := verts[i]
		var b := verts[i + 1]
		var c := verts[i + 2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 0.000000001:
			continue
		n = n.normalized()
		# Godot's front faces wind clockwise, so emit a, c, b.
		for v in [a, c, b]:
			st.set_normal(n)
			st.set_uv(Vector2(kind, 0))
			st.add_vertex(v)


## The flat-shaded mesh of one wedge.
static func wedge_mesh(piece: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add(st, piece["skin"], UV_SKIN)
	_add(st, piece["cut"], UV_BREAK)
	return st.commit()


## The whole unbroken boulder as one mesh: an untouched rock costs one draw call, not thirteen.
static func whole_mesh(pieces: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces:
		_add(st, piece["skin"], UV_SKIN)
	return st.commit()


## Skin only, with normals pointing out from the middle: the cartoon outline pushes along these,
## so flat-shaded facets do not split the line apart.
static func shell_mesh(skin: PackedVector3Array, center: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, skin.size(), 3):
		for k in [0, 2, 1]:
			var v := skin[i + k]
			st.set_normal((v - center).normalized())
			st.add_vertex(v)
	return st.commit()


## A whole closed lump (the inner core, or a loose nugget).
static func lump_mesh(radii: Vector3, center: Vector3, seed_value: int, subdiv: int, kind: float, depth: float = 1.0) -> ArrayMesh:
	var ico := icosphere(subdiv)
	var tris := PackedVector3Array()
	for tri in ico[1]:
		for k in 3:
			var d: Vector3 = ico[0][tri[k]]
			tris.append(center + d * radii * lump(d, seed_value) * depth)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add(st, tris, kind)
	return st.commit()


## Pure (tested): how many wedges should be off after `hits` of `need`. The last hit takes them all.
static func shed_target(hits: int, need: int, total: int) -> int:
	if hits >= need:
		return total
	if hits <= 0:
		return 0
	return clampi(roundi(float(total) * 0.5 * float(hits) / float(maxi(need - 1, 1))), 1, total - 1)


## Pure (tested): which wedges break off next: the ones facing the pickaxe (slightly from the top),
## skipping the ones already gone and the underside.
static func pick_shed(dirs: Array, gone: Array, toward: Vector3, count: int) -> Array:
	var want := (toward.normalized() + Vector3.UP * 0.45).normalized()
	var left := []
	for i in dirs.size():
		if not i in gone:
			left.append(i)
	left.sort_custom(func(a, b):
		var sa: float = (dirs[a] as Vector3).dot(want) - (2.0 if (dirs[a] as Vector3).y < -0.55 else 0.0)
		var sb: float = (dirs[b] as Vector3).dot(want) - (2.0 if (dirs[b] as Vector3).y < -0.55 else 0.0)
		return sa > sb)
	return left.slice(0, maxi(count, 0))
