class_name BuildKit
extends RefCounted
## Code-built models for the structural build pieces: timber frames, boards with nail heads,
## stonework, picket fences, windows, stairs and auto-shaped shingle roofs. Every part is a
## separate mesh, so a piece can assemble itself and fall apart again.

const SHADER := preload("res://scripts/shaders/timber.gdshader")
const WOOD_SURFACE := 0
const STONE_SURFACE := 1
const SHINGLE_SURFACE := 2
const IRON := Color(0.2, 0.2, 0.23)
const GLASS := Color(0.62, 0.82, 0.92)
const FLOOR_TOP := 0.14
const STYLES := ["fence", "block", "floor", "plank_wall", "window", "doorway", "stairs", "roof"]

static var _mats := {}
static var _glass: StandardMaterial3D


static func material(c: Color, surface: int, axis: int) -> ShaderMaterial:
	var key := "%s_%d_%d" % [c.to_html(), surface, axis]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("base", c)
	m.set_shader_parameter("surface", surface)
	m.set_shader_parameter("grain_axis", axis)
	if Toon.outlines:
		m.next_pass = Toon.outline_material(0.0)
	_mats[key] = m
	return m


## Window panes share one material, so every window lights up together at dusk.
static func glass() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = GLASS
		_glass.roughness = 0.15
		_glass.emission_enabled = true
		_glass.emission = Color(1.0, 0.74, 0.34)
		_glass.emission_energy_multiplier = 0.0
	return _glass


static func set_night(dark: float) -> void:
	var g := glass()
	var k := clampf((dark - 0.2) / 0.6, 0.0, 1.0)
	g.emission_energy_multiplier = 1.5 * k
	g.albedo_color = GLASS.lerp(Color(0.95, 0.75, 0.4), k)


## A box whose grain runs along its longest side.
static func board(parent: Node3D, size: Vector3, pos: Vector3, c: Color, surface: int = WOOD_SURFACE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var axis := 0
	if size.y >= size.x and size.y >= size.z:
		axis = 1
	elif size.z >= size.x and size.z >= size.y:
		axis = 2
	mi.material_override = material(c, surface, axis)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func nail(parent: Node3D, pos: Vector3, along_y: bool = false) -> void:
	var s := Vector3(0.045, 0.02, 0.045) if along_y else Vector3(0.045, 0.045, 0.02)
	var mi := Art.box(s, IRON)
	mi.material_override = Toon.color(IRON, false, false)
	mi.visibility_range_end = 18.0   # too small to see further off: saves draw calls
	mi.position = pos
	parent.add_child(mi)


## Build the structural model for `style` into `root`.
static func build(root: Node3D, style: String, size: Vector3, c: Color) -> void:
	match style:
		"fence":
			_fence(root, size, c)
		"block":
			_stone_wall(root, size, c)
		"floor":
			_floor(root, size, c)
		"plank_wall":
			_frame(root, size, c)
			_boards(root, -0.88, 0.88, 0.14, size.y - 0.14, 6, c)
			board(root, Vector3(1.76, 0.12, 0.2), Vector3(0, 1.1, 0), c.darkened(0.22))
			_nails(root, [-0.72, -0.43, -0.14, 0.15, 0.44, 0.73], 1.1, 0.11)
		"window":
			_window(root, size, c)
		"doorway":
			_frame(root, size, c)
			var head := BuildPiece.DOOR_HEIGHT
			for sx in [-0.67, 0.67]:
				_boards(root, sx - 0.21, sx + 0.21, 0.0, size.y - 0.14, 2, c)
			_boards(root, -0.46, 0.46, head + 0.05, size.y - 0.14, 3, c)
			for sx2 in [-0.5, 0.5]:
				board(root, Vector3(0.1, head, 0.24), Vector3(sx2, head * 0.5, 0), c.darkened(0.25))
			board(root, Vector3(1.1, 0.1, 0.24), Vector3(0, head + 0.03, 0), c.darkened(0.25))
		"stairs":
			_stairs(root, c)
		"roof":
			roof(root, c, 0, 1, true, true)


## Sill, top plate and two corner posts: neighbouring walls share their posts, so corners close.
static func _frame(root: Node3D, size: Vector3, c: Color) -> void:
	var dark := c.darkened(0.28)
	for sx in [-0.98, 0.98]:
		board(root, Vector3(0.22, size.y, 0.26), Vector3(sx, size.y * 0.5, 0), dark)
	board(root, Vector3(1.76, 0.14, 0.24), Vector3(0, size.y - 0.07, 0), dark.lightened(0.06))
	if size.y > 1.0:
		for sx2 in [-0.98, 0.98]:
			for y in [0.18, size.y - 0.18]:
				_nails(root, [sx2], y, 0.14)


static func _nails(root: Node3D, xs: Array, y: float, z: float) -> void:
	for x in xs:
		for side in [-1.0, 1.0]:
			nail(root, Vector3(x, y, side * z))


static func _boards(root: Node3D, x0: float, x1: float, y0: float, y1: float, n: int, c: Color) -> void:
	var w := (x1 - x0) / n
	for k in n:
		var shade := c.lightened(0.07) if k % 2 == 0 else c.darkened(0.04)
		board(root, Vector3(w - 0.018, y1 - y0, 0.15 + 0.015 * (k % 3)), Vector3(x0 + w * (k + 0.5), (y0 + y1) * 0.5, 0), shade)


static func _window(root: Node3D, size: Vector3, c: Color) -> void:
	_frame(root, size, c)
	var trim := Color(0.96, 0.92, 0.8)
	_boards(root, -0.88, 0.88, 0.0, 0.82, 6, c)
	_boards(root, -0.88, 0.88, 1.72, size.y - 0.14, 6, c)
	for sx in [-0.7, 0.7]:
		_boards(root, sx - 0.18, sx + 0.18, 0.82, 1.72, 2, c)
	var pane := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.04, 0.9, 0.06)
	pane.mesh = pm
	pane.material_override = glass()
	pane.position = Vector3(0, 1.27, 0)
	pane.add_to_group("window_pane")
	root.add_child(pane)
	for y in [0.82, 1.72]:
		board(root, Vector3(1.16, 0.09, 0.24), Vector3(0, y, 0), trim)
	for sx2 in [-0.54, 0.54]:
		board(root, Vector3(0.09, 0.9, 0.22), Vector3(sx2, 1.27, 0), trim)
	board(root, Vector3(0.05, 0.9, 0.1), Vector3(0, 1.27, 0), trim)
	board(root, Vector3(1.04, 0.05, 0.1), Vector3(0, 1.3, 0), trim)
	# A flower box on the front sill.
	board(root, Vector3(1.1, 0.17, 0.2), Vector3(0, 0.68, 0.2), c.darkened(0.3))
	var petals := [Color(1.0, 0.45, 0.55), Color(1.0, 0.85, 0.25), Color(0.7, 0.55, 1.0)]
	for k in 6:
		var x := -0.44 + k * 0.176
		var leaf := Art.sphere(0.085, Color(0.3, 0.6, 0.28), 3, 6)
		leaf.position = Vector3(x, 0.79, 0.2)
		root.add_child(leaf)
		var bloom := Art.sphere(0.05, petals[k % 3], 3, 6)
		bloom.position = Vector3(x + 0.03, 0.87 + 0.02 * (k % 2), 0.23)
		root.add_child(bloom)


static func _floor(root: Node3D, size: Vector3, c: Color) -> void:
	for k in 5:
		var shade := c.lightened(0.06) if k % 2 == 0 else c.darkened(0.05)
		var x := -0.8 + k * 0.4
		board(root, Vector3(0.38, 0.08, 1.98), Vector3(x, size.y - 0.04, 0), shade)
		for z in [-0.86, 0.86]:
			nail(root, Vector3(x, size.y + 0.002, z), true)
	for z2 in [-0.86, 0.0, 0.86]:
		board(root, Vector3(1.98, 0.07, 0.2), Vector3(0, 0.035, z2), c.darkened(0.35))


static func _fence(root: Node3D, size: Vector3, c: Color) -> void:
	for sx in [-0.95, 0.95]:
		board(root, Vector3(0.17, size.y + 0.15, 0.17), Vector3(sx, (size.y + 0.15) * 0.5, 0), c.darkened(0.2))
		board(root, Vector3(0.22, 0.07, 0.22), Vector3(sx, size.y + 0.18, 0), c.darkened(0.32))
	for y in [0.3, 0.66]:
		board(root, Vector3(1.9, 0.11, 0.07), Vector3(0, y, 0), c.darkened(0.08))
	for k in 6:
		var x := -0.68 + k * 0.272
		var h := size.y - 0.08 + 0.05 * sin(k * 2.3)
		board(root, Vector3(0.15, h, 0.05), Vector3(x, h * 0.5 + 0.04, 0.065), c.lightened(0.05 if k % 2 == 0 else 0.12))
		var tip := board(root, Vector3(0.106, 0.106, 0.049), Vector3(x, h + 0.04, 0.065), c.lightened(0.05 if k % 2 == 0 else 0.12))
		tip.rotation.z = PI * 0.25


static func _stone_wall(root: Node3D, size: Vector3, c: Color) -> void:
	var rows := [[0.62, 0.74, 0.62], [0.44, 0.7, 0.5, 0.34], [0.7, 0.54, 0.74]]
	var rh := (size.y - 0.12) / 3.0
	for row in 3:
		var total := 0.0
		for w in rows[row]:
			total += w
		var x := -size.x * 0.5
		for k in rows[row].size():
			var w2: float = rows[row][k] / total * size.x
			var shade := c.lightened(0.1 * ((row * 2 + k) % 3) - 0.08)
			var s := board(root, Vector3(w2 - 0.035, rh - 0.03, size.z - 0.05 * ((row + k) % 3)), Vector3(x + w2 * 0.5, rh * (row + 0.5), 0), shade, STONE_SURFACE)
			s.rotation.z = 0.012 * sin(row * 7.0 + k * 3.0)
			x += w2
	for k2 in 3:
		board(root, Vector3(size.x / 3.0 - 0.025, 0.13, size.z + 0.08), Vector3(-size.x / 3.0 + k2 * size.x / 3.0, size.y - 0.06, 0), c.darkened(0.14), STONE_SURFACE)


## Nine treads climbing from -Z to +Z, up to the top of an upstairs floor.
static func _stairs(root: Node3D, c: Color) -> void:
	var top := BuildGrid.STOREY + FLOOR_TOP
	var n := 9
	for k in n:
		var y := top * float(k + 1) / n
		var z := -1.0 + 2.0 * (k + 0.5) / n
		board(root, Vector3(1.5, 0.08, 0.27), Vector3(0, y - 0.05, z), c.lightened(0.06 if k % 2 == 0 else 0.0))
		for sx in [-0.62, 0.62]:
			nail(root, Vector3(sx, y - 0.005, z), true)
	var slope := atan2(top, 2.0)
	var run := Vector2(2.0, top).length()
	for sx2 in [-0.8, 0.8]:
		var stringer := board(root, Vector3(0.1, 0.2, run), Vector3(sx2, top * 0.5 - 0.14, 0), c.darkened(0.28))
		stringer.rotation.x = -slope
		var rail := board(root, Vector3(0.08, 0.08, run), Vector3(sx2, top * 0.5 + 0.8, 0), c.darkened(0.2))
		rail.rotation.x = -slope
		for k2 in 3:
			var t := 0.12 + 0.38 * k2
			board(root, Vector3(0.08, 0.86, 0.08), Vector3(sx2, top * t + 0.39, -1.0 + 2.0 * t), c.darkened(0.2))


## One tile of a shared gable roof: tile `index` of `count` across. Gable boards close open ends.
static func roof(root: Node3D, c: Color, index: int, count: int, gable_back: bool, gable_front: bool) -> void:
	var u_base := index * BuildGrid.GRID + 1.0   # u at the tile's centre
	var wood := Color(0.6, 0.41, 0.25)
	var z_lo := -1.0 - (0.18 if gable_back else 0.0)
	var z_hi := 1.0 + (0.18 if gable_front else 0.0)
	for seg in BuildGrid.roof_segments(index, count):
		var a := Vector2(seg[0] - u_base, BuildGrid.roof_height(seg[0], count) + 0.04)
		var b := Vector2(seg[1] - u_base, BuildGrid.roof_height(seg[1], count) + 0.04)
		var dir := (b - a).normalized()
		# Eaves hang a little past the walls.
		if is_zero_approx(seg[0]):
			a -= dir * 0.22
		if is_equal_approx(seg[1], count * BuildGrid.GRID):
			b += dir * 0.22
		var length := a.distance_to(b)
		var mid := (a + b) * 0.5
		var angle := atan2(dir.y, dir.x)
		var xf := Transform3D(Basis(Vector3.BACK, angle), Vector3(mid.x, mid.y, 0))
		var under := board(root, Vector3(length, 0.05, z_hi - z_lo), Vector3.ZERO, wood.darkened(0.2))
		under.transform = xf * Transform3D(Basis(), Vector3(0, 0, (z_lo + z_hi) * 0.5))
		var rows := maxi(2, roundi(length / 0.34))
		var rw := length / rows
		var uphill := 1.0 if dir.y >= 0.0 else -1.0
		for row in rows:
			var off := 0.5 if row % 2 == 0 else 0.0
			var cols := 4
			var cw := (z_hi - z_lo) / cols
			for k in range(-1 if off > 0.0 else 0, cols):
				var s0 := maxf(z_lo, z_lo + (k + off) * cw)
				var s1 := minf(z_hi, z_lo + (k + off + 1.0) * cw)
				if s1 - s0 < 0.08:
					continue
				var shade := c.lightened(0.09 * ((row * 5 + k * 3 + index) % 3) - 0.07)
				var sh := board(root, Vector3(rw + 0.05, 0.045, s1 - s0 - 0.022), Vector3.ZERO, shade, SHINGLE_SURFACE)
				# Each course lifts at its lower edge so it overlaps the one below.
				sh.transform = xf * Transform3D(Basis(Vector3.BACK, -0.09 * uphill), Vector3(-length * 0.5 + rw * (row + 0.5), 0.065, (s0 + s1) * 0.5))
	var ridge_u := count * BuildGrid.GRID * 0.5
	if ridge_u > index * BuildGrid.GRID + 0.01 and ridge_u <= (index + 1) * BuildGrid.GRID + 0.01:
		board(root, Vector3(0.24, 0.13, z_hi - z_lo + 0.04), Vector3(ridge_u - u_base, BuildGrid.roof_height(ridge_u, count) + 0.15, (z_lo + z_hi) * 0.5), c.darkened(0.35))
	for end in [[gable_back, -0.97], [gable_front, 0.97]]:
		if not end[0]:
			continue
		for k2 in 8:
			var x := -0.875 + k2 * 0.25
			var u := u_base + x
			var h := minf(BuildGrid.roof_height(u - 0.12, count), BuildGrid.roof_height(u + 0.12, count)) + 0.04
			if h < 0.07:
				continue
			board(root, Vector3(0.235, h, 0.12), Vector3(x, h * 0.5, end[1]), wood.lightened(0.07 if k2 % 2 == 0 else -0.03))


## Collision slabs for a roof tile: [size, transform] pairs matching the shingled surface.
static func roof_shapes(index: int, count: int) -> Array:
	var out: Array = []
	var u_base := index * BuildGrid.GRID + 1.0
	for seg in BuildGrid.roof_segments(index, count):
		var a := Vector2(seg[0] - u_base, BuildGrid.roof_height(seg[0], count) + 0.04)
		var b := Vector2(seg[1] - u_base, BuildGrid.roof_height(seg[1], count) + 0.04)
		var angle := atan2(b.y - a.y, b.x - a.x)
		var mid := (a + b) * 0.5
		out.append([Vector3(a.distance_to(b), 0.16, 2.0), Transform3D(Basis(Vector3.BACK, angle), Vector3(mid.x, mid.y, 0))])
	return out
