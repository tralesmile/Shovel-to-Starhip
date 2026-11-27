class_name BuildPiece
extends StaticBody3D
## One placed building piece. Structural pieces assemble themselves board by board and fall apart
## into physics debris; furniture pops in with a squash bounce.

var piece_id := "fence_panel"
var rot := 0
var level := 0
## Roofs only: which tile of a shared gable this is, and which ends are open.
var roof_shape := [0, 1, true, true]
var falling := false
var _mesh: Node3D
var _cols: Array[CollisionShape3D] = []

const ASSEMBLE_SPREAD := 0.34
const FLOOR_LIP := 0.22
const DOOR_HEIGHT := 1.98   ## head room for someone stepping up onto the floor


func _ready() -> void:
	var def: Dictionary = BuildWorld.PIECES[piece_id]
	var sz: Vector3 = def["size"]
	var style: String = def["style"]
	if style == "doorway":
		# Two jambs + a lintel: you walk straight through the gap.
		_add_box(Vector3(0.55, sz.y, sz.z), Transform3D(Basis(), Vector3(-0.705, sz.y * 0.5, 0)))
		_add_box(Vector3(0.55, sz.y, sz.z), Transform3D(Basis(), Vector3(0.705, sz.y * 0.5, 0)))
		_add_box(Vector3(0.86, sz.y - DOOR_HEIGHT, sz.z), Transform3D(Basis(), Vector3(0, (sz.y + DOOR_HEIGHT) * 0.5, 0)))
	elif style == "stairs":
		# A smooth ramp under the treads, so you can simply walk up.
		var top := BuildGrid.STOREY + BuildKit.FLOOR_TOP
		var slope := atan2(top, 2.0)
		var basis := Basis(Vector3.RIGHT, -slope)
		_add_box(Vector3(1.5, 0.12, Vector2(2.0, top).length()), Transform3D(basis, Vector3(0, top * 0.5, 0) - basis.y * 0.06))
	elif style == "floor":
		# Only ground floors need the bevel; upstairs it would snag people climbing the stairs.
		if level == 0:
			_floor_collision(sz)
		else:
			_add_box(sz, Transform3D(Basis(), Vector3(0, sz.y * 0.5, 0)))
	elif style == "roof":
		_roof_collision()
	else:
		_add_box(sz, Transform3D(Basis(), Vector3(0, sz.y * 0.5, 0)))
	_mesh = Node3D.new()
	add_child(_mesh)
	var c: Color = def["color"]
	if style == "roof":
		BuildKit.roof(_mesh, c, roof_shape[0], roof_shape[1], roof_shape[2], roof_shape[3])
	elif style in BuildKit.STYLES:
		BuildKit.build(_mesh, style, sz, c)
		if style == "doorway":
			_mesh.add_child(DoorLeaf.new())
	elif def["style"] == "bale":
		# A fat straw block: banded, with loose stalks poking out so it reads as soft and springy.
		var core := Art.box(Vector3(sz.x, sz.y - 0.04, sz.z), c)
		core.position.y = sz.y * 0.5
		_mesh.add_child(core)
		for k in 4:
			var layer := Art.box(Vector3(sz.x + 0.02, 0.035, sz.z + 0.02), c.darkened(0.14))
			layer.position.y = 0.12 + k * 0.17
			_mesh.add_child(layer)
		for sx3 in [-0.42, 0.42]:
			var band := Art.box(Vector3(0.1, sz.y + 0.01, sz.z + 0.06), Color(0.76, 0.28, 0.2))
			band.position = Vector3(sx3, sz.y * 0.5, 0)
			_mesh.add_child(band)
		for k in 18:
			var stalk := Art.box(Vector3(0.025, 0.22, 0.025), c.lightened(0.22))
			stalk.position = Vector3(-0.68 + fmod(k * 0.397, 1.36), sz.y + 0.02, -0.45 + fmod(k * 0.271, 0.9))
			stalk.rotation = Vector3(sin(k * 2.3) * 0.9, 0, cos(k * 1.7) * 0.9)
			_mesh.add_child(stalk)
	elif def["style"] == "sprinkler":
		# Copper standpipe on a stone foot with a spinning four-nozzle head.
		var foot := Art.cylinder(0.15, 0.2, 0.1, Color(0.62, 0.63, 0.68), 10)
		foot.position.y = 0.05
		_mesh.add_child(foot)
		var pipe := Art.cylinder(0.045, 0.055, 0.46, c, 8)
		pipe.position.y = 0.31
		_mesh.add_child(pipe)
		var head := Node3D.new()
		head.position.y = 0.55
		_mesh.add_child(head)
		for k in 2:
			var arm := Art.box(Vector3(0.44, 0.06, 0.06), c.darkened(0.12))
			arm.rotation.y = k * PI * 0.5
			head.add_child(arm)
		var cap := Art.sphere(0.085, c.lightened(0.2), 5, 8)
		cap.position.y = 0.03
		head.add_child(cap)
		var spot := SprinklerSpot.new()
		spot.interact_radius = 0.75
		add_child(spot)
	elif def["style"] == "table":
		var top := Art.box(Vector3(sz.x, 0.1, sz.z), c.lightened(0.08))
		top.position.y = sz.y - 0.05
		_mesh.add_child(top)
		for lx in [-0.55, 0.55]:
			for lz in [-0.35, 0.35]:
				var leg := Art.box(Vector3(0.1, sz.y - 0.1, 0.1), c.darkened(0.2))
				leg.position = Vector3(lx, (sz.y - 0.1) * 0.5, lz)
				_mesh.add_child(leg)
		# A small pie, because a table with nothing on it is just a sad plank.
		var pie := Art.box(Vector3(0.24, 0.07, 0.24), Color(0.9, 0.7, 0.35))
		pie.position = Vector3(0.25, sz.y + 0.035, 0.05)
		_mesh.add_child(pie)
	elif def["style"] == "chair":
		var seat := Art.box(Vector3(0.55, 0.08, 0.55), c)
		seat.position.y = 0.45
		_mesh.add_child(seat)
		var back := Art.box(Vector3(0.55, 0.5, 0.07), c.darkened(0.12))
		back.position = Vector3(0, 0.74, -0.24)
		_mesh.add_child(back)
		for lx2 in [-0.23, 0.23]:
			for lz2 in [-0.23, 0.23]:
				var leg2 := Art.box(Vector3(0.07, 0.42, 0.07), c.darkened(0.2))
				leg2.position = Vector3(lx2, 0.21, lz2)
				_mesh.add_child(leg2)
	elif def["style"] == "bed":
		var frame := Art.box(Vector3(sz.x, 0.28, sz.z), c)
		frame.position.y = 0.26
		_mesh.add_child(frame)
		var mattress := Art.box(Vector3(sz.x - 0.1, 0.16, sz.z - 0.5), Color(0.92, 0.88, 0.8))
		mattress.position = Vector3(0, 0.48, 0.12)
		_mesh.add_child(mattress)
		var blanket := Art.box(Vector3(sz.x - 0.08, 0.1, 0.9), Color(0.85, 0.35, 0.4))
		blanket.position = Vector3(0, 0.56, 0.38)
		_mesh.add_child(blanket)
		var pillow := Art.box(Vector3(0.7, 0.14, 0.34), Color(1.0, 0.97, 0.92))
		pillow.position = Vector3(0, 0.6, -0.62)
		_mesh.add_child(pillow)
		var head := Art.box(Vector3(sz.x, 0.7, 0.1), c.darkened(0.18))
		head.position = Vector3(0, 0.5, -sz.z * 0.5 + 0.05)
		_mesh.add_child(head)
		for lx3 in [-0.5, 0.5]:
			var foot := Art.box(Vector3(0.12, 0.2, 0.12), c.darkened(0.25))
			foot.position = Vector3(lx3, 0.1, sz.z * 0.5 - 0.08)
			_mesh.add_child(foot)
		var spot := BedSpot.new()
		spot.interact_radius = 2.2
		add_child(spot)
	elif def["style"] == "firejar":
		var stake := Art.box(Vector3(0.1, 0.85, 0.1), c)
		stake.position.y = 0.42
		_mesh.add_child(stake)
		var shelf := Art.box(Vector3(0.42, 0.07, 0.42), c.lightened(0.12))
		shelf.position.y = 0.86
		_mesh.add_child(shelf)
		var jar := FireflyJar.new()
		jar.position.y = 1.13
		_mesh.add_child(jar)
	elif def["style"] == "crystallamp":
		var lamp := CrystalLampSpot.new()
		lamp.interact_radius = 1.5
		add_child(lamp)
	elif def["style"] == "lantern":
		var post := Art.box(Vector3(0.1, 1.2, 0.1), c)
		post.position.y = 0.6
		_mesh.add_child(post)
		var cage := Art.box(Vector3(0.3, 0.3, 0.3), Color(1.0, 0.8, 0.4))
		cage.material_override = Art.mat(Color(1.0, 0.8, 0.4), true)
		cage.position.y = 1.35
		_mesh.add_child(cage)
		var cap := Art.box(Vector3(0.38, 0.07, 0.38), c)
		cap.position.y = 1.54
		_mesh.add_child(cap)
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.78, 0.45)
		lt.omni_range = 7.0
		lt.light_energy = 0.0
		lt.visible = false
		lt.position.y = 1.35
		lt.add_to_group("lantern")
		_mesh.add_child(lt)
	elif def["style"] == "chest":
		# Plank box with iron bands, a domed lid hinged at the back, and a gold latch.
		var body := Art.box(Vector3(sz.x, 0.5, sz.z), c)
		body.position.y = 0.25
		_mesh.add_child(body)
		for bx in [-0.35, 0.35]:
			var band := Art.box(Vector3(0.1, 0.52, sz.z + 0.04), Color(0.3, 0.3, 0.34))
			band.position = Vector3(bx, 0.25, 0)
			_mesh.add_child(band)
		var lid_pivot := Node3D.new()
		lid_pivot.name = "LidPivot"
		lid_pivot.position = Vector3(0, 0.5, -sz.z * 0.5)
		_mesh.add_child(lid_pivot)
		var lid := Art.box(Vector3(sz.x + 0.04, 0.2, sz.z + 0.04), c.lightened(0.1))
		lid.position = Vector3(0, 0.1, sz.z * 0.5)
		lid_pivot.add_child(lid)
		var latch := Art.box(Vector3(0.14, 0.16, 0.06), Color(0.95, 0.8, 0.3))
		latch.position = Vector3(0, -0.02, sz.z + 0.04)
		lid_pivot.add_child(latch)
		var cs := ChestSpot.new()
		cs.interact_radius = 2.0
		cs.lid = lid_pivot
		add_child(cs)
	elif def["style"] == "campfire":
		# Ring of stones, crossed logs, flickering flames + smoke, and a spot to roast things.
		for k in 8:
			var a := float(k) / 8.0 * TAU
			var rock := Art.box(Vector3(0.22, 0.16, 0.2), c.lightened(0.06 * float(k % 3)))
			rock.position = Vector3(cos(a) * 0.42, 0.08, sin(a) * 0.42)
			rock.rotation.y = a
			_mesh.add_child(rock)
		for k2 in 2:
			var lg := Art.box(Vector3(0.7, 0.1, 0.1), Color(0.42, 0.28, 0.17))
			lg.position.y = 0.14
			lg.rotation.y = 0.8 + float(k2) * 1.6
			_mesh.add_child(lg)
		var spot := CampfireSpot.new()
		spot.interact_radius = 2.0
		add_child(spot)
	elif def["style"] == "anvil":
		# Stump base, waisted body, flat face, pointed horn; E hammers ingots into hull plates.
		var stump := Art.box(Vector3(0.5, 0.35, 0.4), Art.WOOD)
		stump.position.y = 0.175
		_mesh.add_child(stump)
		var waist := Art.box(Vector3(0.32, 0.25, 0.28), c.darkened(0.2))
		waist.position.y = 0.47
		_mesh.add_child(waist)
		var face := Art.box(Vector3(0.9, 0.2, 0.36), c)
		face.position.y = 0.69
		_mesh.add_child(face)
		var horn := Art.box(Vector3(0.3, 0.12, 0.2), c.lightened(0.05))
		horn.position = Vector3(0.58, 0.67, 0)
		_mesh.add_child(horn)
		var sp := AnvilSpot.new()
		sp.interact_radius = 2.0
		sp.face = face
		add_child(sp)
	elif def["style"] == "invention":
		# Tinkerer's bench: slab top, tesla coil with a glowing bulb, a cog on a pole; E tinkers gadgets together.
		var top := Art.box(Vector3(1.4, 0.12, 0.8), Art.WOOD)
		top.position.y = 0.9
		_mesh.add_child(top)
		for lx in [-0.6, 0.6]:
			var leg := Art.box(Vector3(0.12, 0.9, 0.6), Art.WOOD.darkened(0.2))
			leg.position = Vector3(lx, 0.45, 0)
			_mesh.add_child(leg)
		var coil := Art.box(Vector3(0.14, 0.5, 0.14), Color(0.7, 0.45, 0.25))
		coil.position = Vector3(-0.4, 1.21, 0)
		_mesh.add_child(coil)
		var bulb := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.15
		sph.height = 0.3
		bulb.mesh = sph
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.5, 0.9, 1.0)
		bm.emission_enabled = true
		bm.emission = Color(0.4, 0.85, 1.0)
		bm.emission_energy_multiplier = 1.2
		bulb.material_override = bm
		bulb.position = Vector3(-0.4, 1.55, 0)
		_mesh.add_child(bulb)
		var cog := Art.box(Vector3(0.36, 0.36, 0.06), Color(0.85, 0.7, 0.2))
		cog.position = Vector3(0.35, 1.25, -0.2)
		_mesh.add_child(cog)
		var cog2 := Art.box(Vector3(0.36, 0.36, 0.06), Color(0.85, 0.7, 0.2))
		cog2.position = cog.position
		cog2.rotation.z = PI / 4.0
		_mesh.add_child(cog2)
		var isp := InventionSpot.new()
		isp.interact_radius = 2.0
		isp.bulb = bulb
		isp.cog = cog
		isp.cog2 = cog2
		add_child(isp)
	elif def["style"] == "furnace":
		# Chunky stone kiln: brick courses, glowing mouth, chimney with smoke; E smelts ore with wood fuel.
		var body := Art.box(Vector3(1.0, 1.0, 0.9), c)
		body.position.y = 0.5
		_mesh.add_child(body)
		for row in 3:
			var brick := Art.box(Vector3(1.04, 0.05, 0.94), c.darkened(0.25))
			brick.position.y = 0.25 + row * 0.3
			_mesh.add_child(brick)
		var chim := Art.box(Vector3(0.3, 0.5, 0.3), c.darkened(0.15))
		chim.position = Vector3(0.25, 1.25, -0.2)
		_mesh.add_child(chim)
		var mouth := Art.box(Vector3(0.44, 0.32, 0.08), Color(1.0, 0.55, 0.12))
		mouth.position = Vector3(0, 0.35, 0.46)
		_mesh.add_child(mouth)
		var fs := FurnaceSpot.new()
		fs.interact_radius = 2.0
		fs.mouth = mouth
		add_child(fs)
	_mesh.position.y = 0.0
	rotation.y = BuildWorld.yaw_of(rot)


## Recolour a piece that has colours (the Crystal Lamp).
func set_tint(i: int) -> void:
	for c in get_children():
		if c is CrystalLampSpot:
			c.set_tint(i)


func _add_box(size: Vector3, xf: Transform3D) -> void:
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.transform = xf
	add_child(col)
	_cols.append(col)


## A slab with bevelled sides: a square 14 cm edge is just too steep for a round-bottomed
## walker, so without this you had to jump to get onto your own floor.
func _floor_collision(sz: Vector3) -> void:
	var pts := PackedVector3Array()
	for sx in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			pts.append(Vector3(sx * sz.x, sz.y, z * sz.z))
			pts.append(Vector3(sx * (sz.x + FLOOR_LIP * 2.0), 0.0, z * (sz.z + FLOOR_LIP * 2.0)))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	_cols.append(col)


func _roof_collision() -> void:
	for c in _cols:
		c.free()
	_cols.clear()
	for shape in BuildKit.roof_shapes(roof_shape[0], roof_shape[1]):
		_add_box(shape[0], shape[1])


## A roof tile re-shapes itself when its neighbours change. Returns true if it did.
func set_roof_shape(shape: Array) -> bool:
	if shape == roof_shape:
		return false
	roof_shape = shape
	if _mesh == null:
		return true
	for c in _mesh.get_children():
		c.free()
	BuildKit.roof(_mesh, BuildWorld.PIECES[piece_id]["color"], shape[0], shape[1], shape[2], shape[3])
	_roof_collision()
	return true


func parts() -> Array:
	return _mesh.find_children("*", "MeshInstance3D", true, false) if _mesh != null else []


## The construction animation: boards fly in one after another, lowest first, each landing with
## a hammer tap that climbs in pitch, then the whole piece gives a settling bounce.
func assemble() -> void:
	var items: Array = _mesh.get_children().filter(func(n): return n is Node3D)
	if items.size() < 3:
		pop_in()
		return
	items.sort_custom(func(a, b): return (a as Node3D).position.y < (b as Node3D).position.y)
	for i in items.size():
		var part: Node3D = items[i]
		var home := part.position
		var turn := part.rotation
		part.position = home + Vector3(randf_range(-0.5, 0.5), randf_range(0.7, 1.4), randf_range(-0.9, 0.9))
		part.rotation = turn + Vector3(randf_range(-1.2, 1.2), randf_range(-0.8, 0.8), randf_range(-1.2, 1.2))
		part.visible = false
		var delay := ASSEMBLE_SPREAD * float(i) / items.size()
		var tw := part.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(part.show)
		tw.tween_property(part, "position", home, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(part, "rotation", turn, 0.17).set_ease(Tween.EASE_OUT)
	for k in 5:
		var tap := create_tween()
		tap.tween_interval(0.12 + ASSEMBLE_SPREAD * k / 5.0)
		tap.tween_callback(func(): Sfx.play_on(self, "step_wood", 0.85 + 0.17 * k))
	var settle := create_tween()
	settle.tween_interval(ASSEMBLE_SPREAD + 0.2)
	settle.tween_callback(_settle_puff)
	settle.tween_property(_mesh, "scale", Vector3(1.04, 0.94, 1.04), 0.07)
	settle.tween_property(_mesh, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _settle_puff() -> void:
	if not is_inside_tree():
		return
	Sfx.play_on(self, "thud", 1.35)
	var along := global_basis.x
	for k in 3:
		FX.burst(self, global_position + along * (k - 1) * 0.8 + Vector3(0, 0.1, 0), Color(0.8, 0.72, 0.56), 7, 0.11, 1.8, -1.0, "sphere", 85.0)


## Knocked down because nothing holds it up: bursts into tumbling parts.
func collapse(from: Vector3) -> void:
	collision_layer = 0   # gone this instant: debris and bundles must not be flung out of it
	for col in _cols:
		col.set_deferred("disabled", true)
	var host := get_parent()
	if host != null and is_inside_tree():
		var meshes := parts()
		var step := maxi(1, ceili(meshes.size() / 16.0))
		for i in range(0, meshes.size(), step):
			var m := meshes[i] as MeshInstance3D
			var away := m.global_position - from
			away.y = 0.0
			BuildDebris.fling(host, m, away.normalized() * randf_range(0.6, 2.2) + Vector3(randf_range(-0.8, 0.8), randf_range(0.3, 2.6), randf_range(-0.8, 0.8)))
		FX.burst(host, global_position + Vector3(0, 0.5, 0), Color(0.8, 0.72, 0.56), 16, 0.18, 2.2, -1.0, "sphere", 90.0)
		Sfx.play_on(host, "crunch", randf_range(0.85, 1.2))
	queue_free()


## Squash-and-bounce arrival (juice): drops in tall, lands wide, settles.
func pop_in() -> void:
	_mesh.scale = Vector3(0.7, 1.6, 0.7)
	_mesh.position.y = 0.6
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_mesh, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_mesh, "scale", Vector3(1.1, 0.85, 1.1), 0.22).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(_mesh, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var c: Color = BuildWorld.PIECES[piece_id]["color"]
	get_tree().create_timer(0.2).timeout.connect(func():
		if is_inside_tree():
			FX.burst(self, global_position + Vector3(0, 0.1, 0), Color(0.78, 0.7, 0.55), 12, 0.12, 2.0, -1.0, "sphere", 80.0)
			FX.burst(self, global_position + Vector3(0, 0.4, 0), c, 6, 0.08, 2.5))


## Demolish: the piece comes apart into its boards.
func crumble() -> void:
	collapse(global_position - global_basis.z)


## A hay bale squishes flat and springs back when something lands on it.
func squish(strength: float) -> void:
	if _mesh == null:
		return
	var k := clampf(strength / FX.BOUNCE_MAX, 0.15, 1.0)
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1.0 + 0.25 * k, 1.0 - 0.45 * k, 1.0 + 0.25 * k), 0.07)
	tw.tween_property(_mesh, "scale", Vector3(1.0 - 0.08 * k, 1.0 + 0.2 * k, 1.0 - 0.08 * k), 0.12)
	tw.tween_property(_mesh, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
