class_name Meadow
extends Node3D
## The living meadow: thousands of grass tufts in chunked MultiMeshes with a custom shader.
## Grass bends away from the player, car and animals and leaves a short wake. Tall grass can be
## cut with the Hoe (or, far better, the Scythe): blades fly, Hay Bundles pop out to be picked up,
## and now and then a Sunmint herb. Crouch in tall grass to hide. Cut grass regrows after 2 days.

const CHUNK := 16.0
const CELL := 2.0
const TALL_PATCHES := 70
const PER_PATCH := 34
const SHORT_TUFTS := 2600
const REGROW_DAYS := 2
const TUFTS_PER_HAY := 5     ## tall tufts cut per Hay Bundle that pops out
const HOE_RADIUS := 1.7
const HOE_ARC := 110.0
const SCYTHE_RADIUS := 3.0
const SCYTHE_ARC := 360.0    ## the scythe is a full spin
const COVER_TUFTS := 4       ## this many standing tall tufts around you = hidden while crouched
const COVER_RADIUS := 1.2
const MAX_BENDERS := 12
const TRAIL_SLOTS := 5
const TRAIL_LIFE := 1.4
const MAX_LOOSE_PICKUPS := 90  ## beyond this, hay goes straight to your pockets (frame rate)

var game: GameState
var tufts: Array[Dictionary] = []   ## {pos: Vector3, tall: bool, chunk, slot, tint, state}
var _cells := {}                    ## Vector2i -> Array[int]
var _chunks: Array[MultiMesh] = []
var _mat: ShaderMaterial
var _covered := {}                  ## tuft index -> true (under a built floor)
var _hay_progress := 0
var _trail: Array = []              ## {pos, age}
var _trail_last := Vector3(1e9, 0, 0)
var _rustle_dist := 0.0
var _shock_t := -1.0
var _shock_at := Vector2.ZERO


# ---------------------------------------------------------------- pure helpers (tested)

## Pure: may grass grow here? Keeps the farm, store, road, spaceport, pond and mine mouth clear.
static func spot_ok(x: float, z: float) -> bool:
	if absf(x) < 6.5 and absf(z) < 13.5:
		return false   # farm + path
	if x > 7.5 and x < 21.5 and z > -2.5 and z < 11.0:
		return false   # store
	if x > 21.0 and z < -13.0:
		return false   # spaceport
	if z > 12.5:
		return false   # road + town
	if x < -9.0 and x > -17.0 and z > -3.0 and z < 5.0:
		return false   # the player's house
	if Terrain.height_at(x, z) < -0.6:
		return false   # pond and river
	if Vector2(x - MineCave.ENTRANCE.x, z - MineCave.ENTRANCE.z + 1.0).length() < 4.0:
		return false
	return true


## Pure: swing reach for the tool in hand.
static func swing_for(has_scythe: bool) -> Dictionary:
	if has_scythe:
		return {"radius": SCYTHE_RADIUS, "arc": SCYTHE_ARC}
	return {"radius": HOE_RADIUS, "arc": HOE_ARC}


## Pure: is `p` inside a swing from `origin` facing `yaw` (0 = +z, like the player model)?
static func in_swing(p: Vector2, origin: Vector2, yaw: float, radius: float, arc_deg: float) -> bool:
	var d := p - origin
	var dist := d.length()
	if dist > radius:
		return false
	if arc_deg >= 360.0 or dist < 0.35:
		return true
	var fwd := Vector2(sin(yaw), cos(yaw))
	return absf(fwd.angle_to(d)) <= deg_to_rad(arc_deg * 0.5)


## Pure: carries cut tufts over between swings. Returns [leftover, bundles].
static func hay_from(progress: int, cut: int) -> Array:
	var total := progress + maxi(cut, 0)
	return [total % TUFTS_PER_HAY, total / TUFTS_PER_HAY]


## Pure: rare finds in tall grass. `roll` is 0..1 per tall tuft cut.
static func find_for(roll: float) -> String:
	if roll < 0.025:
		return "sunmint"
	if roll > 0.992:
		return "turnip_seed"
	return ""


static func regrown(cut_day: int, today: int) -> bool:
	return today - cut_day >= REGROW_DAYS


## Pure: crouching among enough standing tall grass hides you.
static func is_cover(crouched: bool, tall_near: int) -> bool:
	return crouched and tall_near >= COVER_TUFTS


## Pure: bend strength of a wake point `age` seconds old.
static func trail_power(age: float) -> float:
	return clampf(1.0 - age / TRAIL_LIFE, 0.0, 1.0) * 0.8


# ---------------------------------------------------------------- build

func _ready() -> void:
	name = "Meadow"
	add_to_group("meadow")
	add_to_group("blast_grass")
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scripts/shaders/meadow.gdshader")
	_scatter()
	_build_meshes()
	if game != null:
		game.day_changed.connect(func(_d): refresh())
		game.built_loaded.connect(refresh)
	refresh()


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	tufts.clear()
	# Hand-placed patches first, so there is tall grass right outside the farm fence.
	var centers: Array[Vector2] = [Vector2(-9.5, -4.0), Vector2(9.5, -8.0), Vector2(-9.0, -14.0), Vector2(4.0, -17.5), Vector2(14.0, -9.0)]
	var guard := 0
	while centers.size() < TALL_PATCHES and guard < 4000:
		guard += 1
		var c := Vector2(rng.randf_range(-52, 52), rng.randf_range(-54, 9))
		if spot_ok(c.x, c.y):
			centers.append(c)
	for c in centers:
		var radius := rng.randf_range(1.8, 3.6)
		var shade := rng.randf()   # whole patches lean greener or golden
		for k in PER_PATCH:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * radius
			var q := c + Vector2(cos(a), sin(a)) * r
			if spot_ok(q.x, q.y):
				_add_tuft(q, true, clampf(shade + rng.randf_range(-0.15, 0.15), 0.0, 1.0), rng)
	var short := 0
	guard = 0
	while short < SHORT_TUFTS and guard < SHORT_TUFTS * 4:
		guard += 1
		var q := Vector2(rng.randf_range(-58, 58), rng.randf_range(-58, 12))
		if spot_ok(q.x, q.y):
			_add_tuft(q, false, rng.randf() * 0.75, rng)
			short += 1


func _add_tuft(q: Vector2, tall: bool, tint: float, rng: RandomNumberGenerator) -> void:
	var idx := tufts.size()
	tufts.append({"pos": Vector3(q.x, Terrain.height_at(q.x, q.y) - 0.02, q.y), "tall": tall, "tint": tint,
		"yaw": rng.randf() * TAU, "scale": rng.randf_range(0.8, 1.2), "state": 0, "chunk": -1, "slot": -1})
	var cell := _cell(q.x, q.y)
	if not _cells.has(cell):
		_cells[cell] = []
	_cells[cell].append(idx)


static func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))


## A tuft of tapered, slightly curved blades. UV.y runs 0 (root) to 1 (tip) for the shader.
static func tuft_mesh(blades: int, height: float, width: float, spread: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5 + blades
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in blades:
		var a := float(b) / blades * TAU + rng.randf_range(-0.4, 0.4)
		var root := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.02, spread)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.28) * height
		var h := height * rng.randf_range(0.65, 1.15)
		var side := Vector3(cos(a + PI * 0.5 + rng.randf_range(-0.6, 0.6)), 0, sin(a + PI * 0.5)).normalized() * width * 0.5
		var mid := root + lean * 0.35 + Vector3(0, h * 0.55, 0)
		var top := root + lean + Vector3(0, h, 0)
		var pts := [[root - side, 0.0], [root + side, 0.0], [mid + side * 0.7, 0.55],
			[root - side, 0.0], [mid + side * 0.7, 0.55], [mid - side * 0.7, 0.55],
			[mid - side * 0.7, 0.55], [mid + side * 0.7, 0.55], [top, 1.0]]
		for v in pts:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5, v[1]))
			st.add_vertex(v[0])
	return st.commit()


func _build_meshes() -> void:
	var tall_mesh := tuft_mesh(7, 0.72, 0.085, 0.2)
	var short_mesh := tuft_mesh(5, 0.27, 0.07, 0.14)
	var groups := {}
	for i in tufts.size():
		var p: Vector3 = tufts[i]["pos"]
		var key := Vector3i(floori(p.x / CHUNK), floori(p.z / CHUNK), 1 if tufts[i]["tall"] else 0)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(i)
	for key in groups.keys():
		var ids: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = tall_mesh if key.z == 1 else short_mesh
		mm.instance_count = ids.size()
		var origin := Vector3((key.x + 0.5) * CHUNK, 0, (key.y + 0.5) * CHUNK)
		for s in ids.size():
			var t: Dictionary = tufts[ids[s]]
			var basis := Basis(Vector3.UP, t["yaw"]).scaled(Vector3.ONE * float(t["scale"]))
			mm.set_instance_transform(s, Transform3D(basis, (t["pos"] as Vector3) - origin))
			t["chunk"] = _chunks.size()
			t["slot"] = s
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat
		mmi.position = origin
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Short grass fades out sooner than tall patches (cheap level of detail).
		mmi.visibility_range_end = 85.0 if key.z == 1 else 55.0
		add_child(mmi)
		_chunks.append(mm)
		for s in ids.size():
			_apply(ids[s])


func _apply(i: int) -> void:
	var t: Dictionary = tufts[i]
	if int(t["chunk"]) < 0:
		return
	var state := 2 if _covered.has(i) else int(t["state"])
	_chunks[t["chunk"]].set_instance_custom_data(t["slot"], Color(float(state), t["tint"], 1.0 if t["tall"] else 0.0, 0.0))


## Re-reads the saved cuts (regrowing old ones) and hides grass under built floors.
func refresh() -> void:
	if game != null:
		for k in game.meadow_cut.keys():
			if regrown(int(game.meadow_cut[k]), game.day):
				game.meadow_cut.erase(k)
	for i in tufts.size():
		var want := 1 if game != null and game.meadow_cut.has(str(i)) else 0
		if int(tufts[i]["state"]) != want:
			tufts[i]["state"] = want
			_apply(i)
	refresh_built()


## Grass never pokes up through floors, furniture or walls you built.
func refresh_built() -> void:
	var old := _covered
	_covered = {}
	if game != null:
		for d in game.built:
			var at := Vector2(float(d.get("x", 0)), float(d.get("z", 0)))
			var floorish: bool = str(d.get("id", "")) == "wood_floor"
			for i in indices_near(at, 1.45):
				var p: Vector3 = tufts[i]["pos"]
				if floorish and absf(p.x - at.x) <= 1.1 and absf(p.z - at.y) <= 1.1:
					_covered[i] = true
				elif Vector2(p.x, p.z).distance_to(at) <= 0.75:
					_covered[i] = true
	for i in old.keys():
		if not _covered.has(i):
			_apply(i)
	for i in _covered.keys():
		_apply(i)


func indices_near(at: Vector2, radius: float) -> Array:
	var out: Array = []
	var lo := _cell(at.x - radius, at.y - radius)
	var hi := _cell(at.x + radius, at.y + radius)
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			for i in _cells.get(Vector2i(cx, cz), []):
				var p: Vector3 = tufts[i]["pos"]
				if Vector2(p.x, p.z).distance_to(at) <= radius:
					out.append(i)
	return out


func _standing(i: int) -> bool:
	return int(tufts[i]["state"]) == 0 and not _covered.has(i)


## Standing tall tufts around a point (cover and rustling).
func tall_count(at: Vector3, radius: float = COVER_RADIUS) -> int:
	if at.x > 200.0:
		return 0   # indoors / down the mine
	var n := 0
	for i in indices_near(Vector2(at.x, at.z), radius):
		if tufts[i]["tall"] and _standing(i):
			n += 1
	return n


## Standing tufts a swing from `origin` would cut. Tall grass only: short grass is scenery.
func targets(origin: Vector3, yaw: float, radius: float, arc: float) -> Array:
	var out: Array = []
	if origin.x > 200.0:
		return out
	var o := Vector2(origin.x, origin.z)
	for i in indices_near(o, radius):
		var p: Vector3 = tufts[i]["pos"]
		if tufts[i]["tall"] and _standing(i) and in_swing(Vector2(p.x, p.z), o, yaw, radius, arc):
			out.append(i)
	return out


## Cuts the listed tufts: stubble, flying blades, hay bundles and rare finds. Returns tufts cut.
func cut(ids: Array, from: Vector3, rolls: Array = []) -> int:
	var n := 0
	var sum := Vector3.ZERO
	var finds: Array = []
	var spots: Array = []
	for i in ids:
		if not tufts[i]["tall"] or not _standing(i):
			continue
		tufts[i]["state"] = 1
		if game != null:
			game.meadow_cut[str(i)] = game.day
		_apply(i)
		var p: Vector3 = tufts[i]["pos"]
		sum += p
		spots.append(p)
		if n % 3 == 0:
			_blade_burst(p + Vector3(0, 0.35, 0), from, float(tufts[i]["tint"]))
		var roll: float = rolls[n] if n < rolls.size() else randf()
		var f := find_for(roll)
		if f != "":
			finds.append([f, p])
		n += 1
	if n == 0:
		return 0
	var r := hay_from(_hay_progress, n)
	_hay_progress = r[0]
	var centre := sum / n
	if is_inside_tree():
		var life := get_tree().get_first_node_in_group("bug_life") as BugLife
		if life != null:
			life.flush(spots, from)
	for b in int(r[1]):
		var src: Vector3 = tufts[ids[(b * TUFTS_PER_HAY) % ids.size()]]["pos"]
		_drop("hay", src.lerp(centre, 0.3), from)
	for f in finds:
		_drop(f[0], f[1], from)
		if game != null:
			game.say("Something in the grass: %s!" % GameState.ITEMS[f[0]]["name"])
	return n


## A bundle pops out of the grass as a physics pickup you collect from the ground.
func _drop(item: String, at: Vector3, from: Vector3) -> void:
	if not is_inside_tree() or game == null:
		return
	if get_tree().get_nodes_in_group("pickup").size() >= MAX_LOOSE_PICKUPS:
		game.add_item(item, 1)
		return
	var l := WoodLog.new()
	l.item_id = item
	l.chunk_color = WoodLog.drop_color(item)
	l.game = game
	get_parent().add_child(l)
	l.global_position = at + Vector3(0, 0.45, 0)
	var away := at - from
	away.y = 0.0
	l.pop(away.normalized() * 1.1)


## Thin green blades spinning away from the cut.
func _blade_burst(at: Vector3, from: Vector3, tint: float) -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 12
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	var out := at - from
	out.y = 0.0
	p.direction = (out.normalized() + Vector3(0, 1.5, 0)).normalized()
	p.spread = 55.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 4.2
	p.gravity = Vector3(0, -7.0, 0)
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.particle_flag_rotate_y = true
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -520.0
	p.angular_velocity_max = 520.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.045, 0.24, 0.008)
	var m := FX.particle_mat(false)
	bm.material = m
	p.mesh = bm
	p.color = Color(0.50, 0.74, 0.28).lerp(Color(0.86, 0.76, 0.36), clampf((tint - 0.7) * 3.0, 0.0, 1.0))
	var fade := Curve.new()
	fade.add_point(Vector2(0, 1))
	fade.add_point(Vector2(0.7, 1))
	fade.add_point(Vector2(1, 0))
	p.scale_amount_curve = fade
	add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


## A blast flattens grass in a ripple and mows whatever is close to ground zero.
func blast(at: Vector3, radius: float) -> int:
	if at.x > 200.0:
		return 0
	_shock_at = Vector2(at.x, at.z)
	_shock_t = 0.0
	var ids: Array = []
	for i in indices_near(_shock_at, radius * 0.8):
		if tufts[i]["tall"] and _standing(i):
			ids.append(i)
	return cut(ids, at)


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if _shock_t >= 0.0:
		_shock_t += delta
		var power := clampf(1.0 - _shock_t / 0.9, 0.0, 1.0)
		_mat.set_shader_parameter("shock", Vector4(_shock_at.x, _shock_at.y, _shock_t * 14.0, power))
		if power <= 0.0:
			_shock_t = -1.0
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	_update_benders(delta, pl)
	_mat.set_shader_parameter("wind_strength", 1.0 + 1.3 * Weather.gloom(game.weather() if game != null else Weather.CLEAR))
	_update_rustle(delta, pl)


func _update_benders(delta: float, pl: Node3D) -> void:
	var b := PackedVector4Array()
	var w := PackedFloat32Array()
	var driving: bool = pl.get("vehicle") != null
	var at := pl.global_position
	if not driving:
		var r := 1.5 if pl.get("mount") != null else 1.05
		b.append(Vector4(at.x, at.y, at.z, r))
		w.append(1.0)
		if at.distance_to(_trail_last) > 0.55:
			_trail_last = at
			_trail.push_front({"pos": at, "age": 0.0})
			if _trail.size() > TRAIL_SLOTS:
				_trail.pop_back()
	for t in _trail:
		t["age"] += delta
		var power := trail_power(t["age"])
		if power > 0.0:
			var p: Vector3 = t["pos"]
			b.append(Vector4(p.x, p.y, p.z, 0.9))
			w.append(power)
	for car in get_tree().get_nodes_in_group("car"):
		var c := car as Node3D
		if c != null and b.size() < MAX_BENDERS and c.global_position.distance_to(at) < 45.0:
			b.append(Vector4(c.global_position.x, c.global_position.y, c.global_position.z, 2.4))
			w.append(1.0)
	for n in get_tree().get_nodes_in_group("grass_bender"):
		if b.size() >= MAX_BENDERS:
			break
		var c := n as Node3D
		if c != null and c.visible and c.global_position.distance_to(at) < 30.0:
			b.append(Vector4(c.global_position.x, c.global_position.y, c.global_position.z, 0.75))
			w.append(0.9)
	while b.size() < MAX_BENDERS:
		b.append(Vector4.ZERO)
		w.append(0.0)
	_mat.set_shader_parameter("benders", b)
	_mat.set_shader_parameter("bend_power", w)


## Swishing and drifting seeds while you wade through tall grass.
func _update_rustle(delta: float, pl: Node3D) -> void:
	if pl.get("vehicle") != null or not (pl is CharacterBody3D):
		return
	var v: Vector3 = (pl as CharacterBody3D).velocity
	var spd := Vector2(v.x, v.z).length()
	if spd < 0.8:
		return
	_rustle_dist += spd * delta
	if _rustle_dist < 1.1:
		return
	_rustle_dist = 0.0
	if tall_count(pl.global_position, 0.8) < 2:
		return
	Sfx.play_on(pl, "rustle", randf_range(0.85, 1.2) * (0.8 if bool(pl.get("crouching")) else 1.0))
	FX.burst(self, pl.global_position + Vector3(0, 0.55, 0), Color(0.95, 0.92, 0.6), 4, 0.045, 1.2, -1.2, "sphere", 90.0)
