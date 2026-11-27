class_name ShipModel
extends RefCounted
## Builds the starship from a workshop design: a turned (lathed) riveted hull plus the chosen
## nose, fins, engines and paint. parts[] is in story order: nose, fins, porthole, engine, star.

const HULL_SHADER := preload("res://scripts/shaders/ship_hull.gdshader")
const FLAME_SHADER := preload("res://scripts/shaders/rocket_flame.gdshader")
const HULL_PROFILE := [Vector2(0.72, 0.62), Vector2(0.98, 1.05), Vector2(1.12, 1.9), Vector2(1.15, 2.8), Vector2(1.1, 3.7), Vector2(0.98, 4.4), Vector2(0.84, 4.95)]
const HULL_TOP := 4.95
const NOZZLE_Y := 0.1


## A surface of revolution from [radius, height] points, smooth shaded.
static func lathe(profile: Array, segments: int = 20, cap_bottom: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	for j in n:
		var p: Vector2 = profile[j]
		var tangent: Vector2 = (profile[mini(j + 1, n - 1)] - profile[maxi(j - 1, 0)])
		var nr := Vector2(tangent.y, -tangent.x).normalized()
		for i in segments + 1:
			var a := TAU * float(i) / float(segments)
			st.set_normal(Vector3(sin(a) * nr.x, nr.y, cos(a) * nr.x))
			st.add_vertex(Vector3(sin(a) * p.x, p.y, cos(a) * p.x))
	var w := segments + 1
	for j in n - 1:
		for i in segments:
			var a := j * w + i
			for idx in [a, a + w, a + 1, a + 1, a + w, a + w + 1]:
				st.add_index(idx)
	if cap_bottom:
		var base := n * w
		var p0: Vector2 = profile[0]
		st.set_normal(Vector3.DOWN)
		st.add_vertex(Vector3(0, p0.y, 0))
		for i in segments + 1:
			var a := TAU * float(i) / float(segments)
			st.set_normal(Vector3.DOWN)
			st.add_vertex(Vector3(sin(a) * p0.x, p0.y, cos(a) * p0.x))
		for i in segments:
			for idx in [base, base + 1 + i, base + 2 + i]:
				st.add_index(idx)
	return st.commit()


static func _mesh_node(mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi


static func hull_material(paint: Color, patched: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HULL_SHADER
	m.set_shader_parameter("paint", paint)
	m.set_shader_parameter("patched", patched)
	return m


## A flat swept fin plate as a thick polygon. points are (out, up) pairs, anticlockwise.
static func plate(points: PackedVector2Array, thick: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(points)
	for side in [-1.0, 1.0]:
		for t in range(0, tris.size(), 3):
			var order := [0, 1, 2] if side > 0.0 else [0, 2, 1]
			for k in order:
				var v: Vector2 = points[tris[t + k]]
				st.set_normal(Vector3(0, 0, side))
				st.add_vertex(Vector3(v.x, v.y, side * thick * 0.5))
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var e := (b - a).normalized()
		var nr := Vector3(e.y, -e.x, 0)
		var a0 := Vector3(a.x, a.y, -thick * 0.5)
		var a1 := Vector3(a.x, a.y, thick * 0.5)
		var b0 := Vector3(b.x, b.y, -thick * 0.5)
		var b1 := Vector3(b.x, b.y, thick * 0.5)
		for v in [a0, b0, a1, a1, b0, b1]:
			st.set_normal(nr)
			st.add_vertex(v)
	var mat := Toon.color(color, false, false).duplicate() as ShaderMaterial
	var mi := _mesh_node(st.commit(), mat)
	var two_sided := StandardMaterial3D.new()
	two_sided.albedo_color = color
	two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	two_sided.roughness = 0.7
	mi.material_override = two_sided
	return mi


static func _nose(id: String, paint: Color) -> Node3D:
	var n := Node3D.new()
	match id:
		"cheese":
			var cheese := Color(1.0, 0.8, 0.18)
			var wedge := _mesh_node(lathe([Vector2(0.86, 0), Vector2(0.0, 1.9)], 6, true), Art.mat(cheese), Vector3.ZERO)
			n.add_child(wedge)
			for k in 11:
				var a := k * 2.39
				var h := 0.18 + 1.25 * fposmod(k * 0.37, 1.0)
				var r := 0.86 * (1.0 - h / 1.9) * 0.9
				var hole := Art.sphere(0.09 + 0.05 * (k % 3), cheese.darkened(0.28), 4, 8)
				hole.position = Vector3(sin(a) * r, h, cos(a) * r)
				hole.scale = Vector3(1, 1, 1) * 0.9
				n.add_child(hole)
		"dome":
			var collar := _mesh_node(lathe([Vector2(0.86, 0), Vector2(0.9, 0.18), Vector2(0.74, 0.3)], 20, true), Art.mat(paint))
			n.add_child(collar)
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.55, 0.85, 1.0, 0.42)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.1
			glass.emission_enabled = true
			glass.emission = Color(0.25, 0.55, 0.8)
			glass.emission_energy_multiplier = 0.35
			var dome := _mesh_node(lathe([Vector2(0.74, 0.28), Vector2(0.72, 0.62), Vector2(0.58, 0.92), Vector2(0.34, 1.12), Vector2(0.0, 1.2)], 18, false), glass)
			n.add_child(dome)
			# A lookout turnip, obviously.
			var turnip := Art.sphere(0.24, Color(0.92, 0.86, 0.96), 8, 10)
			turnip.position.y = 0.52
			n.add_child(turnip)
			var leaf := Art.cylinder(0.02, 0.12, 0.3, Color(0.3, 0.7, 0.3), 6)
			leaf.position.y = 0.84
			n.add_child(leaf)
		_:
			var cone := _mesh_node(lathe([Vector2(0.86, 0), Vector2(0.72, 0.5), Vector2(0.48, 1.05), Vector2(0.2, 1.55), Vector2(0.0, 1.8)], 20, true), Art.mat(paint))
			n.add_child(cone)
			var ring := Art.cylinder(0.89, 0.89, 0.12, Color(0.8, 0.82, 0.86), 20)
			ring.position.y = 0.04
			n.add_child(ring)
	return n


static func _fins(id: String, paint: Color) -> Node3D:
	var f := Node3D.new()
	var pts := PackedVector2Array([Vector2(0, 0.55), Vector2(1.15, -0.55), Vector2(1.2, 0.25), Vector2(0, 2.25)])
	var count := 3
	match id:
		"wings":
			pts = PackedVector2Array([Vector2(0, 0.5), Vector2(2.05, 0.1), Vector2(2.15, 1.15), Vector2(0, 2.7)])
			count = 4
		"stubby":
			pts = PackedVector2Array([Vector2(0, 0.7), Vector2(0.62, 0.2), Vector2(0.66, 0.75), Vector2(0, 1.5)])
	for i in count:
		var a := i * TAU / count + PI / 6.0
		var pivot := Node3D.new()
		pivot.rotation.y = a
		var fin := plate(pts, 0.16, paint)
		fin.position = Vector3(0.9, 0.05, 0)
		pivot.add_child(fin)
		var tip := Art.cylinder(0.09, 0.09, 0.7, Color(0.85, 0.87, 0.92), 8)
		tip.position = Vector3(0.9 + pts[1].x + 0.04, pts[1].y + 0.4, 0)
		pivot.add_child(tip)
		f.add_child(pivot)
	return f


## Nozzle positions (and bell size) for an engine choice.
static func nozzles(engine: String) -> Array:
	if engine == "triple":
		return [[Vector3(0, NOZZLE_Y, 0.46), 0.36], [Vector3(-0.42, NOZZLE_Y, -0.26), 0.36], [Vector3(0.42, NOZZLE_Y, -0.26), 0.36]]
	return [[Vector3(0, NOZZLE_Y, 0), 0.68]]


static func _engine(id: String) -> Node3D:
	var e := Node3D.new()
	for nz in nozzles(id):
		var r: float = nz[1]
		var bell := _mesh_node(lathe([Vector2(r, 0.0), Vector2(r * 0.72, 0.22), Vector2(r * 0.5, 0.55)], 14, false), Art.mat(Color(0.3, 0.31, 0.36)), nz[0])
		e.add_child(bell)
		var lip := Art.cylinder(r * 1.04, r * 1.04, 0.07, Color(0.72, 0.5, 0.3), 14)
		lip.position = (nz[0] as Vector3) + Vector3(0, 0.03, 0)
		e.add_child(lip)
	if id == "turnip":
		var bulb := Art.sphere(0.5, Color(0.7, 0.45, 0.85), 8, 12)
		bulb.material_override = Art.mat(Color(0.7, 0.45, 0.85), true)
		bulb.position = Vector3(0, 0.95, 1.02)
		e.add_child(bulb)
		for k in 3:
			var leaf := Art.sphere(0.18, Color(0.35, 0.78, 0.3), 4, 8)
			leaf.scale = Vector3(0.45, 1.5, 0.25)
			leaf.position = Vector3(-0.18 + 0.18 * k, 1.55, 1.03)
			leaf.rotation.z = 0.45 - 0.45 * k
			e.add_child(leaf)
	return e


static func _porthole() -> Node3D:
	var w := Node3D.new()
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.34
	tm.outer_radius = 0.5
	tm.rings = 24
	tm.ring_segments = 10
	rim.mesh = tm
	rim.material_override = Art.mat(Color(0.85, 0.65, 0.3))
	rim.rotation.x = PI / 2
	w.add_child(rim)
	var glass := Art.sphere(0.37, Color(0.45, 0.85, 1.0), 8, 16)
	glass.material_override = Art.mat(Color(0.45, 0.85, 1.0), true)
	glass.scale = Vector3(1, 1, 0.3)
	w.add_child(glass)
	for k in 8:
		var a := k * TAU / 8.0
		var bolt := Art.sphere(0.04, Color(0.5, 0.4, 0.2), 4, 6)
		bolt.position = Vector3(cos(a) * 0.42, sin(a) * 0.42, 0.09)
		w.add_child(bolt)
	return w


static func _star(paint: Color) -> Node3D:
	var s := Node3D.new()
	var rod := Art.cylinder(0.03, 0.03, 0.55, Color(0.8, 0.82, 0.86), 6)
	rod.position.y = -0.2
	s.add_child(rod)
	var ball := Art.sphere(0.2, Color(1.0, 0.86, 0.25), 6, 10)
	ball.material_override = Art.mat(Color(1.0, 0.86, 0.25), true)
	ball.position.y = 0.15
	s.add_child(ball)
	return s


## Returns {root, parts, hull_mat, flames}.
static func build(design: Dictionary, patched: float = 0.0) -> Dictionary:
	var d := StarshipDesign.sanitize(design)
	var paint := StarshipDesign.paint_color(d)
	var root := Node3D.new()
	var mat := hull_material(paint, patched)
	root.add_child(_mesh_node(lathe(HULL_PROFILE), mat))
	var skirt := Art.cylinder(0.76, 0.74, 0.16, Color(0.45, 0.46, 0.52), 20)
	skirt.position.y = 0.66
	root.add_child(skirt)
	var top_ring := Art.cylinder(0.86, 0.86, 0.1, Color(0.55, 0.57, 0.62), 20)
	top_ring.position.y = HULL_TOP
	root.add_child(top_ring)
	var parts: Array[Node3D] = []
	var nose := _nose(d["nose"], paint)
	nose.position.y = HULL_TOP + 0.03
	parts.append(nose)
	parts.append(_fins(d["fins"], paint))
	var win := _porthole()
	win.position = Vector3(0, 3.1, 1.12)
	parts.append(win)
	parts.append(_engine(d["engine"]))
	var star := _star(paint)
	star.position.y = HULL_TOP + (1.55 if d["nose"] == "dome" else 2.15)
	parts.append(star)
	for p in parts:
		root.add_child(p)
	return {"root": root, "parts": parts, "hull_mat": mat, "flames": []}


## An exhaust cone hanging from a nozzle; scale.y is the flame length.
static func flame(radius: float, tint: Color = Color(1.0, 0.38, 0.06)) -> Node3D:
	var holder := Node3D.new()
	for k in 2:
		var cm := CylinderMesh.new()
		cm.top_radius = radius * (0.9 if k == 0 else 0.5)
		cm.bottom_radius = 0.02
		cm.height = 1.0
		cm.radial_segments = 16
		cm.rings = 10
		cm.cap_top = false
		cm.cap_bottom = false
		var m := ShaderMaterial.new()
		m.shader = FLAME_SHADER
		m.set_shader_parameter("edge", tint if k == 0 else Color(1.0, 0.75, 0.3))
		var mi := _mesh_node(cm, m, Vector3(0, -0.5 if k == 0 else -0.35, 0))
		mi.scale = Vector3.ONE if k == 0 else Vector3(1.0, 0.7, 1.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	return holder
