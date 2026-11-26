class_name RoomDressing
extends RefCounted
## The art pass for the box-room interiors: wallpaper, floorboards, windows whose
## glass and light shafts follow the time of day, a rug, shelves, pictures and
## clutter. Decoration only (no collision), kept clear of beds, drawers and doors.

static var _glass: StandardMaterial3D
static var _shaft: StandardMaterial3D


static func glass_material() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glass.albedo_color = Color(0.6, 0.82, 1.0)
	return _glass


static func shaft_material() -> StandardMaterial3D:
	if _shaft == null:
		_shaft = StandardMaterial3D.new()
		_shaft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shaft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shaft.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_shaft.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shaft.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_shaft.vertex_color_use_as_albedo = true
		_shaft.albedo_color = Color(1, 1, 1, 0.2)
	return _shaft


## Pure (tested): window glass colour and light-shaft strength for the sky blend weights.
static func window_light(day: float, sunset: float, night: float) -> Dictionary:
	var c := Color(0.62, 0.84, 1.0) * day + Color(1.0, 0.62, 0.36) * sunset + Color(0.12, 0.17, 0.38) * night
	c.a = 1.0
	return {"glass": c, "shaft": clampf(0.2 * day + 0.28 * sunset + 0.07 * night, 0.0, 0.3)}


static func update_light(day: float, sunset: float, night: float) -> void:
	var w := window_light(day, sunset, night)
	var glass: Color = w["glass"]
	glass_material().albedo_color = glass
	var s := glass.lightened(0.25)
	s.a = float(w["shaft"])
	shaft_material().albedo_color = s


static func dress(room: Node3D, index: int, wall_color: Color) -> void:
	var size := Buildings.ROOM
	var wall := ShaderMaterial.new()
	wall.shader = preload("res://scripts/shaders/interior_wall.gdshader")
	wall.set_shader_parameter("paper", wall_color)
	wall.set_shader_parameter("floor_y", room.global_position.y)
	var boards := ShaderMaterial.new()
	boards.shader = preload("res://scripts/shaders/floorboards.gdshader")
	boards.set_shader_parameter("centre", Vector2(room.global_position.x, room.global_position.z))
	boards.set_shader_parameter("half_size", Vector2(size.x / 2.0 - 0.15, size.z / 2.0 - 0.15))
	var i := 0
	for body in room.get_children():
		if body is StaticBody3D and i < 6:
			var mi := body.get_child(0) as MeshInstance3D
			if i == 0:
				mi.material_override = boards
			elif i >= 2:
				mi.material_override = wall
			i += 1
	var deco := Node3D.new()
	deco.name = "Deco"
	room.add_child(deco)
	var back := -size.z / 2.0 + 0.17
	for wx in [-1.9, 1.9]:
		_window(deco, Vector3(wx, 2.0, back))
	var accent: Color = [Color(0.8, 0.25, 0.2), Color(0.9, 0.62, 0.2), Color(0.28, 0.45, 0.75), Color(0.7, 0.28, 0.45), Color(0.28, 0.6, 0.38)][index % 5]
	_rug(deco, Vector3(0.2, 0, 0.35), accent)
	_shelf(deco, Vector3(0.0, 1.45, back + 0.1), index)
	_picture(deco, Vector3(-size.x / 2.0 + 0.18, 1.9, 0.4), PI / 2.0, accent)
	_picture(deco, Vector3(size.x / 2.0 - 0.18, 1.8, -0.2), -PI / 2.0, accent.lightened(0.3))
	_plant(deco, Vector3(-3.45, 0, 1.9))
	if index != 1:
		_table(deco, Vector3(2.9, 0, 1.4), accent)
	# A lamp shade on a cord (no ceiling beams: they sit right in front of the camera).
	var cord := Art.cylinder(0.012, 0.012, 0.35, Color(0.1, 0.08, 0.06), 5)
	cord.position = Vector3(0, size.y - 0.28, 0)
	deco.add_child(cord)
	var shade := Art.cylinder(0.09, 0.3, 0.2, accent, 12)
	shade.position = Vector3(0, size.y - 0.48, 0)
	deco.add_child(shade)


static func _add(parent: Node3D, mi: Node3D, pos: Vector3) -> Node3D:
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _window(parent: Node3D, pos: Vector3) -> void:
	var frame := Art.WOOD.lightened(0.15)
	var pane := Art.box(Vector3(1.1, 0.95, 0.03), Color.WHITE)
	pane.material_override = glass_material()
	_add(parent, pane, pos)
	for s in [-1.0, 1.0]:
		_add(parent, Art.box(Vector3(1.24, 0.08, 0.08), frame), pos + Vector3(0, s * 0.5, 0.03))
		_add(parent, Art.box(Vector3(0.08, 1.05, 0.08), frame), pos + Vector3(s * 0.58, 0, 0.03))
		var curtain := Art.box(Vector3(0.24, 1.12, 0.07), Color(0.86, 0.36, 0.34))
		_add(parent, curtain, pos + Vector3(s * 0.75, -0.04, 0.06))
	_add(parent, Art.box(Vector3(0.04, 0.95, 0.04), frame), pos + Vector3(0, 0, 0.03))
	_add(parent, Art.box(Vector3(1.1, 0.04, 0.04), frame), pos + Vector3(0, 0, 0.03))
	_add(parent, Art.cylinder(0.025, 0.025, 1.8, LootModel.GOLD, 6), pos + Vector3(0, 0.58, 0.09)).rotation.z = PI / 2.0
	# A slanting shaft of light falling from the pane to the floor.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_a := Vector3(-0.52, 0.45, 0.06)
	var top_b := Vector3(0.52, 0.45, 0.06)
	var low_a := Vector3(-0.85, -pos.y + 0.03, 1.9)
	var low_b := Vector3(0.85, -pos.y + 0.03, 1.9)
	for v in [[top_a, 1.0], [top_b, 1.0], [low_a, 0.0], [low_a, 0.0], [top_b, 1.0], [low_b, 0.0]]:
		st.set_color(Color(1, 1, 1, v[1]))
		st.add_vertex(v[0])
	var shaft := MeshInstance3D.new()
	shaft.mesh = st.commit()
	shaft.material_override = shaft_material()
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, shaft, pos)


static func _rug(parent: Node3D, pos: Vector3, accent: Color) -> void:
	var cols := [accent.darkened(0.15), Color(0.96, 0.9, 0.74), accent, Color(0.96, 0.9, 0.74), accent.darkened(0.25)]
	for k in cols.size():
		var ring := Art.cylinder(1.45 - k * 0.27, 1.45 - k * 0.27, 0.012, cols[k], 24)
		ring.scale = Vector3(1.25, 1.0, 0.85)
		_add(parent, ring, pos + Vector3(0, 0.008 + k * 0.004, 0))


static func _shelf(parent: Node3D, pos: Vector3, seed_value: int) -> void:
	for row in 2:
		var y := row * 0.5
		_add(parent, Art.box(Vector3(1.5, 0.05, 0.22), Art.WOOD.darkened(0.15)), pos + Vector3(0, y, 0))
		var x := -0.68
		var k := 0
		while x < 0.5:
			var w := 0.07 + 0.03 * ((k * 7 + seed_value + row) % 3)
			var h := 0.2 + 0.05 * ((k * 5 + seed_value) % 4)
			var col := Color.from_hsv(fposmod(0.13 * (k + row * 3 + seed_value * 2), 1.0), 0.6, 0.8)
			_add(parent, Art.box(Vector3(w, h, 0.16), col), pos + Vector3(x + w / 2.0, y + h / 2.0 + 0.025, 0))
			x += w + 0.012
			k += 1
		_add(parent, Art.sphere(0.09, Color(0.85, 0.55, 0.35)), pos + Vector3(0.62, y + 0.11, 0))


static func _picture(parent: Node3D, pos: Vector3, yaw: float, sky: Color) -> void:
	var p := Node3D.new()
	_add(parent, p, pos)
	p.rotation.y = yaw
	_add(p, Art.box(Vector3(0.85, 0.65, 0.05), LootModel.GOLD.darkened(0.2)), Vector3.ZERO)
	_add(p, Art.box(Vector3(0.72, 0.52, 0.02), sky.lightened(0.45)), Vector3(0, 0, 0.03))
	_add(p, Art.box(Vector3(0.72, 0.2, 0.02), Art.GRASS), Vector3(0, -0.16, 0.036))
	# Portrait of a very important turnip.
	_add(p, Art.sphere(0.13, Color(0.97, 0.93, 0.9)), Vector3(0, -0.02, 0.04)).scale = Vector3(1, 1, 0.2)
	_add(p, Art.cylinder(0.0, 0.06, 0.12, Art.LEAF, 6), Vector3(0, 0.15, 0.05))


static func _plant(parent: Node3D, pos: Vector3) -> void:
	_add(parent, Art.cylinder(0.22, 0.16, 0.34, Color(0.76, 0.42, 0.24), 10), pos + Vector3(0, 0.17, 0))
	for k in 5:
		var a := TAU * k / 5.0
		var leaf := Art.sphere(0.15, Art.LEAF.lightened(0.05 * (k % 3)))
		leaf.scale = Vector3(0.6, 1.5, 0.6)
		var n := _add(parent, leaf, pos + Vector3(cos(a) * 0.12, 0.52 + 0.06 * (k % 2), sin(a) * 0.12))
		n.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)


static func _table(parent: Node3D, pos: Vector3, accent: Color) -> void:
	_add(parent, Art.cylinder(0.55, 0.55, 0.07, Art.WOOD, 16), pos + Vector3(0, 0.72, 0))
	_add(parent, Art.cylinder(0.07, 0.1, 0.7, Art.WOOD.darkened(0.2), 8), pos + Vector3(0, 0.36, 0))
	_add(parent, Art.cylinder(0.3, 0.34, 0.05, Art.WOOD.darkened(0.25), 12), pos + Vector3(0, 0.03, 0))
	_add(parent, Art.cylinder(0.08, 0.07, 0.14, accent, 10), pos + Vector3(-0.18, 0.83, 0.1))
	_add(parent, Art.cylinder(0.2, 0.2, 0.025, Color(0.95, 0.95, 0.92), 14), pos + Vector3(0.15, 0.77, -0.08))
	_add(parent, Art.sphere(0.12, Color(0.86, 0.56, 0.24)), pos + Vector3(0.15, 0.82, -0.08)).scale = Vector3(1.2, 0.55, 1.2)
