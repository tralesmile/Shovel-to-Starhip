class_name CropModel
extends RefCounted
## Code-built crops: leafy plants that visibly grow stage by stage, and the produce you pull out of
## the ground (also used, scaled way up, for giant crops). Leaves are merged into one mesh per plant.

const LEAF_SHADER := preload("res://scripts/shaders/crop.gdshader")
const SOIL_SHADER := preload("res://scripts/shaders/soil.gdshader")

const COLORS := {
	"turnip": {"leaf": Color(0.33, 0.66, 0.24), "body": Color(0.97, 0.92, 0.84), "cap": Color(0.68, 0.24, 0.58)},
	"carrot": {"leaf": Color(0.25, 0.60, 0.22), "body": Color(1.0, 0.50, 0.08), "cap": Color(0.86, 0.36, 0.05)},
	"tomato": {"leaf": Color(0.22, 0.52, 0.20), "body": Color(0.93, 0.16, 0.10), "cap": Color(0.24, 0.55, 0.18)},
}

static var _leaf_mat: ShaderMaterial
static var _soil_mesh: ArrayMesh


static func is_crop(id: String) -> bool:
	return COLORS.has(id)


## Pure (tested): 0 sprout .. 1 full size.
static func growth_fraction(growth: int, days: int) -> float:
	return clampf(float(growth) / maxf(float(days), 1.0), 0.0, 1.0)


static func leaf_material() -> ShaderMaterial:
	if _leaf_mat == null:
		_leaf_mat = ShaderMaterial.new()
		_leaf_mat.shader = LEAF_SHADER
	return _leaf_mat


## One pointed, slightly arched leaf from `root` heading `yaw`, rising at `rise` radians and drooping
## toward the tip. `jag` pinches alternate rows for feathery (carrot) fronds.
static func _leaf(st: SurfaceTool, root: Vector3, yaw: float, rise: float, length: float, width: float,
		droop: float, color: Color, jag: bool = false) -> void:
	var rows := 8 if jag else 5
	var out := Vector3(sin(yaw), 0, cos(yaw))
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	var pts: Array = []
	var pos := root
	for r in rows + 1:
		var t := float(r) / rows
		var ang := rise - droop * t * t
		if r > 0:
			pos += (out * cos(ang) + Vector3.UP * sin(ang)) * (length / rows)
		var w := width * sin(PI * clampf(t * 0.86 + 0.07, 0.0, 1.0))
		if jag:
			w *= 1.0 if r % 2 == 1 else 0.28
		if r == rows:
			w = 0.0
		pts.append([pos - side * w * 0.5, pos + Vector3(0, width * 0.14, 0), pos + side * w * 0.5, t])
	for r in rows:
		var a: Array = pts[r]
		var b: Array = pts[r + 1]
		for half in 2:
			var u0 := 0.0 if half == 0 else 0.5
			var u1 := u0 + 0.5
			var quad := [[a[half], u0, a[3]], [b[half], u0, b[3]], [b[half + 1], u1, b[3]], [a[half + 1], u1, a[3]]]
			for idx in [0, 1, 2, 0, 2, 3]:
				var v: Array = quad[idx]
				st.set_color(color)
				st.set_uv(Vector2(v[1], v[2]))
				st.set_normal((Vector3.UP * 0.9 + out * 0.35).normalized())
				st.add_vertex(v[0])


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _finish(st: SurfaceTool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = leaf_material()
	return mi


static func _ball(radius: float, color: Color, scale: Vector3, pos: Vector3, glow: bool = false) -> MeshInstance3D:
	var m := Art.sphere(radius, color, 8, 12)
	if glow:
		m.material_override = Art.mat(color, true)
	m.scale = scale
	m.position = pos
	return m


## The plant standing in a plot. `growth` of `days` watered nights; ripe when equal.
static func plant(crop: String, growth: int, days: int, seed_value: int = 0) -> Node3D:
	var root := Node3D.new()
	var f := growth_fraction(growth, days)
	var ripe := growth >= days
	var cd: Dictionary = COLORS.get(crop, COLORS["turnip"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + crop.length() * 31
	var st := _begin()
	var leaf: Color = cd["leaf"]
	match crop:
		"carrot":
			var n := 5 + int(f * 8.0)
			for i in n:
				var yaw := i * 2.399 + rng.randf() * 0.5
				var inner := float(i) / n
				_leaf(st, Vector3(sin(yaw), 0.05, cos(yaw)) * Vector3(0.07, 1, 0.07), yaw,
					lerpf(0.85, 1.45, inner), (0.24 + 0.56 * f) * rng.randf_range(0.82, 1.12),
					0.09 + 0.13 * f, lerpf(1.25, 0.35, inner), leaf.lightened(rng.randf() * 0.18), true)
			if f >= 0.6:
				var r := 0.19 if ripe else 0.10
				var top := Art.cylinder(r * 0.82, r, 0.17 if ripe else 0.08, cd["body"], 10)
				top.position.y = 0.12
				root.add_child(top)
		"tomato":
			var tall := 0.28 + 0.82 * f
			var stake := Art.cylinder(0.028, 0.035, tall + 0.18, Art.WOOD.lightened(0.18), 6)
			stake.position = Vector3(0.06, (tall + 0.18) * 0.5, 0.0)
			root.add_child(stake)
			var tiers := 2 + int(f * 3.0)
			for tier in tiers:
				var y := 0.08 + tall * float(tier) / tiers
				for i in 5:
					var yaw := i * TAU / 5.0 + tier * 0.7 + rng.randf() * 0.4
					_leaf(st, Vector3(0, y, 0), yaw, rng.randf_range(0.25, 0.65),
						(0.2 + 0.26 * f) * (1.0 - 0.35 * float(tier) / tiers), 0.12 + 0.12 * f, 0.9, leaf.lightened(rng.randf() * 0.2))
			for i in 4:
				var yaw2 := i * TAU / 4.0 + 0.5
				_leaf(st, Vector3(0, tall, 0), yaw2, 0.95, 0.16 + 0.14 * f, 0.1 + 0.07 * f, 0.5, leaf.lightened(0.22))
			if ripe or f >= 0.5:
				var spots := [Vector3(0.27, 0.34, 0.18), Vector3(-0.26, 0.5, 0.12), Vector3(0.05, 0.68, 0.26),
					Vector3(-0.12, 0.28, -0.27), Vector3(0.25, 0.62, -0.15)]
				for i in spots.size():
					var at: Vector3 = spots[i] * Vector3(1.0, 0.45 + 0.55 * f, 1.0)
					if ripe:
						root.add_child(_ball(0.115, cd["body"].lightened(0.06 * (i % 2)), Vector3(1, 0.9, 1), at, true))
					elif f >= 0.75:
						root.add_child(_ball(0.075, Color(0.6, 0.78, 0.25), Vector3.ONE, at))
					else:
						root.add_child(_ball(0.038, Color(1.0, 0.88, 0.2), Vector3(1, 0.5, 1), at, true))
		_:
			var n := 4 + int(f * 5.0)
			for i in n:
				var yaw := i * 2.399 + rng.randf() * 0.4
				var inner := float(i) / n
				var lift := 0.22 if ripe else 0.05
				_leaf(st, Vector3(0, lift, 0), yaw, lerpf(0.5, 1.35, inner), (0.22 + 0.4 * f) * rng.randf_range(0.85, 1.12),
					0.14 + 0.24 * f, lerpf(1.1, 0.4, inner), leaf.lightened(rng.randf() * 0.2))
			if f >= 0.6:
				var r := 0.27 if ripe else 0.13
				var y := 0.14 if ripe else 0.05
				root.add_child(_ball(r, cd["body"], Vector3(1, 0.8, 1), Vector3(0, y, 0)))
				root.add_child(_ball(r * 0.94, cd["cap"], Vector3(1.0, 0.48, 1.0), Vector3(0, y + r * 0.46, 0)))
	root.add_child(_finish(st))
	return root


## The pulled-up vegetable, centred on the origin, roughly 0.45 across at scale 1.
static func produce(crop: String) -> Node3D:
	var root := Node3D.new()
	var cd: Dictionary = COLORS.get(crop, COLORS["turnip"])
	var st := _begin()
	var leaf: Color = cd["leaf"]
	match crop:
		"carrot":
			var body := Art.cylinder(0.13, 0.018, 0.46, cd["body"], 10)
			root.add_child(body)
			root.add_child(_ball(0.128, cd["body"], Vector3(1, 0.45, 1), Vector3(0, 0.23, 0)))
			for k in 3:
				var ring := Art.cylinder(0.112 - k * 0.03, 0.106 - k * 0.03, 0.018, cd["cap"], 10)
				ring.position.y = 0.1 - k * 0.11
				root.add_child(ring)
			for i in 6:
				_leaf(st, Vector3(0, 0.25, 0), i * TAU / 6.0, 1.15, 0.3, 0.09, 0.7, leaf.lightened(0.08 * (i % 3)), true)
		"tomato":
			root.add_child(_ball(0.2, cd["body"], Vector3(1.05, 0.88, 1.05), Vector3.ZERO))
			root.add_child(_ball(0.05, Color(1.0, 0.62, 0.55), Vector3(1, 0.5, 1), Vector3(0.1, 0.08, 0.14), true))
			for i in 6:
				_leaf(st, Vector3(0, 0.17, 0), i * TAU / 6.0, 0.3, 0.16, 0.075, 0.9, leaf)
			var stem := Art.cylinder(0.018, 0.022, 0.1, leaf.darkened(0.2), 6)
			stem.position.y = 0.22
			root.add_child(stem)
		_:
			root.add_child(_ball(0.22, cd["body"], Vector3(1, 0.88, 1), Vector3.ZERO))
			root.add_child(_ball(0.207, cd["cap"], Vector3(1.04, 0.58, 1.04), Vector3(0, 0.082, 0)))
			var tail := Art.cylinder(0.045, 0.004, 0.2, cd["body"].darkened(0.08), 6)
			tail.position.y = -0.26
			root.add_child(tail)
			for i in 5:
				_leaf(st, Vector3(0, 0.18, 0), i * TAU / 5.0 + 0.3, 1.1, 0.3, 0.14, 0.9, leaf.lightened(0.07 * (i % 3)))
	root.add_child(_finish(st))
	return root


## Pure (tested): height of the furrowed bed at local x (three ridges across the plot).
static func furrow_height(x: float, half: float) -> float:
	var u := clampf((x + half) / (half * 2.0), 0.0, 1.0)
	return 0.025 + 0.095 * pow(absf(sin(u * PI * 3.0)), 0.7)


## Furrowed soil bed shared by every plot.
static func soil_mesh(size: float) -> ArrayMesh:
	if _soil_mesh != null:
		return _soil_mesh
	var st := _begin()
	var half := size * 0.5
	var nx := 36
	var nz := 10
	var at := func(i: int, j: int) -> Vector3:
		var x := -half + size * i / nx
		var z := -half + size * j / nz
		var edge := clampf((half - absf(z)) / 0.14, 0.0, 1.0)
		var h := furrow_height(x, half) * (0.35 + 0.65 * edge)
		h += 0.012 * sin(i * 12.9 + j * 4.1) * sin(j * 7.7 + i)
		return Vector3(x, h, z)
	for i in nx:
		for j in nz:
			var q := [at.call(i, j), at.call(i + 1, j), at.call(i + 1, j + 1), at.call(i, j + 1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[idx])
	st.generate_normals()
	_soil_mesh = st.commit()
	return _soil_mesh


static func soil_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOIL_SHADER
	return m
