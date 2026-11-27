class_name BuildWorld
extends Node3D
## Build mode (Valheim style): with the Builder tool [6] a see-through copy of the next piece shows
## where it will go. Walls snap to tile edges and turn with you, pieces stack into storeys (T), and
## the ghost's colour shows how well it will be held up. Take away a support and whatever depended
## on it comes crashing down. Click/E places or demolishes (full refund), Q rotates, F switches.
## Pieces are saved in GameState.built as {id, x, z, r, l}.

const GRID := 2.0
const REACH := 2.6
const PIECES := {
	"fence_panel": {"name": "Fence Panel", "size": Vector3(1.9, 0.9, 0.16), "color": Color(0.72, 0.5, 0.3), "style": "fence"},
	"stone_wall": {"name": "Stone Wall", "size": Vector3(1.95, 1.3, 0.4), "color": Color(0.6, 0.61, 0.66), "style": "block"},
	"wood_floor": {"name": "Wood Floor", "size": Vector3(1.96, 0.14, 1.96), "color": Color(0.8, 0.6, 0.38), "style": "floor"},
	"wood_wall": {"name": "Wood Wall", "size": Vector3(1.96, 2.2, 0.2), "color": Color(0.74, 0.52, 0.32), "style": "plank_wall"},
	"wood_door": {"name": "Wood Doorway", "size": Vector3(1.96, 2.2, 0.2), "color": Color(0.66, 0.44, 0.27), "style": "doorway"},
	"wood_table": {"name": "Wood Table", "size": Vector3(1.3, 0.8, 0.9), "color": Color(0.7, 0.48, 0.28), "style": "table"},
	"wood_chair": {"name": "Wood Chair", "size": Vector3(0.6, 0.95, 0.6), "color": Color(0.76, 0.54, 0.34), "style": "chair"},
	"wood_bed": {"name": "Wood Bed", "size": Vector3(1.1, 0.6, 1.9), "color": Color(0.7, 0.46, 0.28), "style": "bed"},
	"hay_bale": {"name": "Bouncy Hay Bale", "size": Vector3(1.5, 0.7, 1.1), "color": Color(0.92, 0.76, 0.3), "style": "bale"},
	"firefly_jar": {"name": "Firefly Jar", "size": Vector3(0.45, 1.4, 0.45), "color": Color(0.55, 0.38, 0.22), "style": "firejar"},
	"lantern": {"name": "Lantern Post", "size": Vector3(0.3, 1.5, 0.3), "color": Color(0.3, 0.3, 0.34), "style": "lantern"},
	"storage_chest": {"name": "Storage Chest", "size": Vector3(1.1, 0.8, 0.7), "color": Color(0.62, 0.4, 0.22), "style": "chest"},
	"campfire": {"name": "Campfire", "size": Vector3(1.0, 0.4, 1.0), "color": Color(0.5, 0.48, 0.5), "style": "campfire"},
	"furnace": {"name": "Stone Furnace", "size": Vector3(1.1, 1.3, 1.1), "color": Color(0.5, 0.5, 0.55), "style": "furnace"},
	"invention_bench": {"name": "Invention Bench", "size": Vector3(1.4, 1.0, 0.8), "color": Color(0.35, 0.45, 0.55), "style": "invention"},
	"anvil": {"name": "Anvil", "size": Vector3(1.0, 0.9, 0.6), "color": Color(0.32, 0.33, 0.38), "style": "anvil"},
	"sprinkler": {"name": "Copper Sprinkler", "size": Vector3(0.34, 0.6, 0.34), "color": Color(0.9, 0.55, 0.3), "style": "sprinkler"},
	"wood_roof": {"name": "Wood Roof", "size": Vector3(2.3, 0.7, 2.3), "color": Color(0.7, 0.3, 0.22), "style": "roof", "y": 2.2},
	"wood_window": {"name": "Window Wall", "size": Vector3(1.96, 2.2, 0.2), "color": Color(0.74, 0.52, 0.32), "style": "window"},
	"wood_stairs": {"name": "Wood Stairs", "size": Vector3(1.6, 2.34, 2.0), "color": Color(0.72, 0.5, 0.3), "style": "stairs"},
}
const PIECE_ORDER := ["fence_panel", "stone_wall", "wood_floor", "wood_wall", "wood_door", "wood_roof", "wood_table", "wood_chair", "wood_bed", "lantern", "storage_chest", "campfire", "furnace", "anvil", "invention_bench", "hay_bale", "firefly_jar", "sprinkler", "wood_window", "wood_stairs"]

var pieces := {}   ## cell key -> BuildPiece
var piece_id := "fence_panel"
var rot := 0
var level_offset := 0   ## storeys above where you stand (T cycles)
var _ghost_r := 0
var _ghost_level := 0
var _ghost_support := 1.0
var _ghost_look := ""
var _hidden: Array = []
var _hearth: OmniLight3D

const HEARTH_ENERGY := 1.5
var _ghost: Node3D
var _ghost_mat: StandardMaterial3D
var _ghost_pos := Vector3.ZERO
var _ghost_ok := false
var _time := 0.0


# ---------------------------------------------------------------- pure helpers (tested)

## Snap a world position to the build grid (x/z only; y is kept).
static func snap(p: Vector3) -> Vector3:
	return Vector3(roundf(p.x / GRID) * GRID, p.y, roundf(p.z / GRID) * GRID)


## Where the ghost goes: REACH metres ahead of the player along `yaw`, snapped.
static func target_pos(player: Vector3, yaw: float) -> Vector3:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	return snap(player + fwd * REACH)


## Unique key for a wall slot: position in metres, storey and which way it runs.
static func cell_key(p: Vector3, r: int, level: int = 0) -> String:
	return "e,%d,%d,%d,%d" % [int(roundf(p.x / (GRID * 0.5))), int(roundf(p.z / (GRID * 0.5))), level, r % 2]


## Pure (tested): the slot a piece fills. Walls are keyed by the edge (in metres), everything
## else by tile; each storey has its own slots.
static func key_for(id: String, p: Vector3, r: int, level: int = -1) -> String:
	var l := default_level(id) if level < 0 else level
	var tile := "%d,%d,%d" % [int(roundf(p.x / GRID)), int(roundf(p.z / GRID)), l]
	if PIECES.has(id):
		match BuildGrid.kind_of(PIECES[id]["style"]):
			"floor":
				return "f," + tile
			"roof":
				return "r," + tile
			"cell":
				return "m," + tile
	return cell_key(p, r, l)


## Roofs rest on top of ground-floor walls unless told otherwise.
static func default_level(id: String) -> int:
	return roundi(base_y(id) / BuildGrid.STOREY)


## Pure (tested): furniture lives in its own key space (one per cell, stands on floors).
static func is_furniture(id: String) -> bool:
	return PIECES.has(id) and PIECES[id]["style"] in ["table", "chair", "lantern", "bed", "campfire", "chest", "furnace", "anvil", "invention", "bale", "firejar", "sprinkler"]


## Pure (tested): height above the ground a piece sits at (roofs rest on top of 2.2m walls).
static func base_y(id: String) -> float:
	return float(PIECES[id].get("y", 0.0)) if PIECES.has(id) else 0.0


static func yaw_of(r: int) -> float:
	return float(r % 4) * PI * 0.5


## Pure (tested): may a piece go here?
static func can_place(key: String, existing: Dictionary, in_water: bool, owned: int) -> bool:
	return owned > 0 and not in_water and not existing.has(key)


## Pure (tested): cycle to the next piece id, preferring ones you own when `inv` is given.
static func next_piece(current: String, dir: int, inv: Dictionary) -> String:
	var n := PIECE_ORDER.size()
	var i := PIECE_ORDER.find(current)
	for step in range(1, n + 1):
		var cand: String = PIECE_ORDER[posmod(i + dir * step, n)]
		if int(inv.get(cand, 0)) > 0:
			return cand
	return PIECE_ORDER[posmod(i + dir, n)]


## Pure (tested): HUD hint for the Builder tool.
static func prompt_for(id: String, owned: int, aiming_at_piece: bool, level: int = 0, support: float = 1.0) -> String:
	var nm: String = PIECES[id]["name"]
	var floor_name: String = ["ground", "upstairs", "attic", "top"][clampi(level, 0, 3)]
	if aiming_at_piece:
		return "[E] Demolish piece (refunds 1)   {build_level} storey: %s" % floor_name
	if owned <= 0:
		return "No %s - craft some at the workbench   {build_cycle} switch piece" % nm
	var hold := "" if level <= 0 else " - " + BuildGrid.support_word(support)
	return "[E] Place %s (%d left) %s%s   {craft_next} rotate   {build_level} storey   {build_cycle} switch" % [nm, owned, floor_name, hold]


## Pure (tested): saved pieces as the grid rules see them, keyed by slot.
static func grid_items(built: Array) -> Dictionary:
	var out := {}
	for d in built:
		var id := str(d.get("id", "fence_panel"))
		if not PIECES.has(id):
			continue
		var x := float(d.get("x", 0))
		var z := float(d.get("z", 0))
		var r := int(d.get("r", 0))
		var l := int(d.get("l", default_level(id)))
		out[key_for(id, Vector3(x, 0, z), r, l)] = {"id": id, "style": PIECES[id]["style"], "kind": BuildGrid.kind_of(PIECES[id]["style"]), "x": x, "z": z, "r": r, "l": l}
	return out


## Pure (tested): a stairwell must stay open, so no floor sits right over stairs.
static func blocks_stairwell(items: Dictionary, id: String, x: float, z: float, l: int) -> bool:
	var style: String = PIECES[id]["style"]
	var other := "stairs" if style == "floor" else ("floor" if style == "stairs" else "")
	if other == "":
		return false
	var want := l - 1 if style == "floor" else l + 1
	for it in items.values():
		if it["style"] == other and int(it["l"]) == want and BuildGrid.cell_of(it["x"], it["z"]) == BuildGrid.cell_of(x, z):
			return true
	return false


# ---------------------------------------------------------------- node

func _ready() -> void:
	add_to_group("buildworld")
	name = "BuildWorld"
	_ghost = Node3D.new()
	_ghost.visible = false
	add_child(_ghost)
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = Color(0.4, 1.0, 0.5, 0.45)
	_ghost_mat.emission_enabled = true
	_ghost_mat.emission = Color(0.4, 1.0, 0.5)
	_ghost_mat.emission_energy_multiplier = 0.6
	_rebuild_ghost()
	var g := _game()
	if g != null:
		g.built_loaded.connect(rebuild_from_game)
		rebuild_from_game()


func _game() -> GameState:
	return get_node_or_null("/root/Game") as GameState


## The ghost is the real model, painted see-through, so you see exactly what you will get.
func _rebuild_ghost(shape: Array = [0, 1, true, true]) -> void:
	for c in _ghost.get_children():
		c.free()
	var def: Dictionary = PIECES[piece_id]
	var sz: Vector3 = def["size"]
	var model := Node3D.new()
	_ghost.add_child(model)
	if def["style"] == "roof":
		BuildKit.roof(model, def["color"], shape[0], shape[1], shape[2], shape[3])
	elif def["style"] in BuildKit.STYLES:
		BuildKit.build(model, def["style"], sz, def["color"])
	else:
		var box := Art.box(sz, def["color"])
		box.position.y = sz.y * 0.5
		model.add_child(box)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = _ghost_mat
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_look = "%s%s" % [piece_id, str(shape)]


## Respawn every saved piece (after load).
func rebuild_from_game(source: GameState = null) -> void:
	for k in pieces.keys():
		if is_instance_valid(pieces[k]):
			pieces[k].queue_free()
	pieces.clear()
	_hidden.clear()
	var g := source if source != null else _game()
	if g == null:
		return
	for d in g.built:
		var id := str(d.get("id", "fence_panel"))
		_spawn(id, float(d.get("x", 0)), float(d.get("z", 0)), int(d.get("r", 0)), false, int(d.get("l", default_level(id))), g)
	refresh_roofs(g)


static func world_y(x: float, z: float, level: int) -> float:
	return Terrain.height_at(x, z) + level * BuildGrid.STOREY


func _spawn(id: String, x: float, z: float, r: int, animate: bool, level: int, g: GameState = null) -> BuildPiece:
	if not PIECES.has(id):
		return null
	var p := BuildPiece.new()
	p.piece_id = id
	p.rot = r
	p.level = level
	p.position = Vector3(x, world_y(x, z, level), z)
	if PIECES[id]["style"] == "roof":
		if g != null:
			p.roof_shape = roof_shape_at(grid_items(g.built), x, z, level, r)
	add_child(p)
	pieces[key_for(id, p.position, r, level)] = p
	if animate:
		p.assemble() if PIECES[id]["style"] in BuildKit.STYLES else p.pop_in()
	return p


## [index, count, open back end, open front end] for a roof tile among its neighbours.
static func roof_shape_at(items: Dictionary, x: float, z: float, l: int, r: int) -> Array:
	var roofs := {}
	for it in items.values():
		if it["kind"] == "roof":
			roofs[BuildGrid.roof_id(it["x"], it["z"], it["l"])] = int(it["r"]) % 2
	var axis := r % 2
	var span := BuildGrid.roof_span(roofs, x, z, l, axis)
	# The ridge runs across the slope: along Z for axis 0, along X for axis 1.
	var along := Vector2(0, GRID) if axis == 0 else Vector2(GRID, 0)
	var open: Array = []
	for side in [-1.0, 1.0]:
		var k := BuildGrid.roof_id(x + along.x * side, z + along.y * side, l)
		var joined: bool = roofs.has(k) and int(roofs[k]) == axis and BuildGrid.roof_span(roofs, x + along.x * side, z + along.y * side, l, axis) == span
		open.append(not joined)
	return [span.x, span.y, open[0], open[1]]


## Reshape every roof tile after something changed; touched tiles give a little hop.
func refresh_roofs(g: GameState, skip: BuildPiece = null) -> void:
	if g == null:
		return
	var items := grid_items(g.built)
	for k in items:
		var it: Dictionary = items[k]
		if it["kind"] != "roof" or not pieces.has(k):
			continue
		var p: BuildPiece = pieces[k]
		if is_instance_valid(p) and p.set_roof_shape(roof_shape_at(items, it["x"], it["z"], it["l"], it["r"])) and p != skip and p.is_inside_tree():
			var tw := p.create_tween()
			var home := world_y(it["x"], it["z"], it["l"])
			tw.tween_property(p, "position:y", home + 0.18, 0.09).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "position:y", home, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Support (0..1) a new piece would have in this slot.
func support_for(id: String, x: float, z: float, r: int, l: int, g: GameState) -> float:
	var items := grid_items(g.built)
	var key := key_for(id, Vector3(x, 0, z), r, l)
	items[key] = {"id": id, "style": PIECES[id]["style"], "kind": BuildGrid.kind_of(PIECES[id]["style"]), "x": x, "z": z, "r": r, "l": l}
	return float(BuildGrid.supports(items)[key])


## Place a piece directly (no reach/collision checks). Used by use() and tests.
func place(id: String, pos: Vector3, r: int, g: GameState, level: int = -1) -> bool:
	var l := default_level(id) if level < 0 else level
	var key := key_for(id, pos, r, l)
	if not can_place(key, pieces, false, g.count(id)):
		return false
	g.remove_item(id, 1)
	var entry := {"id": id, "x": pos.x, "z": pos.z, "r": r % 4}
	if l != default_level(id):
		entry["l"] = l
	g.built.append(entry)
	var made := _spawn(id, pos.x, pos.z, r % 4, true, l, g)
	refresh_roofs(g, made)
	_update_grass()
	if id == "sprinkler":
		for c in made.get_children():
			if c is SprinklerSpot:
				c.water_around()
				c.spray(SprinklerSpot.SPRAY_TIME)
	return true


func _forget(key: String, g: GameState) -> void:
	for i in g.built.size():
		var d: Dictionary = g.built[i]
		var id := str(d["id"])
		if key_for(id, Vector3(d["x"], 0, d["z"]), int(d["r"]), int(d.get("l", default_level(id)))) == key:
			g.built.remove_at(i)
			return


## Remove a piece and refund it. Whatever was resting on it falls down, lowest first, and drops
## as bundles you pick back up off the ground.
func demolish(key: String, g: GameState) -> bool:
	if not pieces.has(key):
		return false
	var falling := BuildGrid.collapsed(grid_items(g.built), key)
	var p: BuildPiece = pieces[key]
	var origin := p.position
	pieces.erase(key)
	_forget(key, g)
	g.add_item(p.piece_id, 1)
	_unhide(p)
	p.crumble()
	var i := 0
	for k in falling:
		if not pieces.has(k):
			continue
		var f: BuildPiece = pieces[k]
		pieces.erase(k)
		_forget(k, g)
		f.falling = true
		_unhide(f)
		if f.is_inside_tree() and is_inside_tree():
			var tw := f.create_tween()
			var wait := 0.18 + 0.13 * i
			# A warning shudder before it gives way.
			var home := f.position
			for s in int(wait / 0.06):
				tw.tween_property(f, "position", home + Vector3(0.05 if s % 2 == 0 else -0.05, -0.015 * s, 0), 0.06)
			tw.tween_callback(_drop.bind(f, origin, g))
		else:
			_drop(f, origin, g)
		i += 1
	if i > 0:
		g.say("TIMBERRR! %d piece%s lost their support." % [i, "" if i == 1 else "s"])
		g.shake.emit(minf(0.2 + 0.06 * i, 0.55))
	refresh_roofs(g)
	_update_grass()
	return true


func _drop(f: BuildPiece, origin: Vector3, g: GameState) -> void:
	var bundle := WoodLog.new()
	bundle.item_id = f.piece_id
	bundle.chunk_color = PIECES[f.piece_id]["color"]
	bundle.game = g
	bundle.position = f.position + Vector3(0, 0.6, 0)
	f.collapse(origin)
	add_child(bundle)
	# Set the speed directly: an impulse before physics knows the mass launches things sky high.
	bundle.linear_velocity = Vector3(randf_range(-1.4, 1.4), 2.6, randf_range(-1.4, 1.4))
	bundle.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-2, 2), randf_range(-3, 3))


# ---------------------------------------------------------------- indoors and comfort

## Pure (tested): should this piece be cut away so the camera can see a player at `p`?
static func cuts_away(piece_level: int, style: String, offset: Vector3, indoors: bool) -> bool:
	if not indoors or Vector2(offset.x, offset.z).length() > 7.0:
		return false
	var kind := BuildGrid.kind_of(style)
	if kind == "roof":
		return offset.y > 1.0
	return offset.y > 1.4


## Is there a floor or roof of ours directly over this spot?
func is_covered(at: Vector3) -> bool:
	for p in pieces.values():
		if not is_instance_valid(p):
			continue
		var bp: BuildPiece = p
		var kind := BuildGrid.kind_of(PIECES[bp.piece_id]["style"])
		if (kind == "floor" or kind == "roof") and bp.position.y > at.y + 1.4 \
				and absf(bp.position.x - at.x) <= 1.05 and absf(bp.position.z - at.z) <= 1.05:
			return true
	return false


## Under your own roof, everything overhead turns invisible (it still casts shadows).
func _update_cutaway(pl: Node3D) -> void:
	var indoors := is_covered(pl.global_position)
	if _hearth == null:
		_hearth = OmniLight3D.new()
		_hearth.light_color = Color(1.0, 0.84, 0.62)
		_hearth.omni_range = 5.5
		_hearth.omni_attenuation = 0.6
		_hearth.light_energy = 0.0
		add_child(_hearth)
	# A soft warm glow fills your own rooms, so the roof's shadow never makes them gloomy.
	_hearth.light_energy = move_toward(_hearth.light_energy, HEARTH_ENERGY if indoors else 0.0, 0.12)
	_hearth.visible = _hearth.light_energy > 0.01
	_hearth.global_position = pl.global_position + Vector3(0, 1.9, 0)
	var arm = pl.get("_arm")
	for p in pieces.values():
		if not is_instance_valid(p):
			continue
		var bp: BuildPiece = p
		var want := cuts_away(bp.level, PIECES[bp.piece_id]["style"], bp.global_position - pl.global_position, indoors)
		if want == _hidden.has(bp):
			continue
		var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if want else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for m in bp.parts():
			(m as MeshInstance3D).cast_shadow = mode
		if want:
			_hidden.append(bp)
			if arm != null:
				(arm as SpringArm3D).add_excluded_object(bp.get_rid())
		else:
			_unhide(bp)


func _unhide(bp: BuildPiece) -> void:
	if not _hidden.has(bp):
		return
	_hidden.erase(bp)
	for m in bp.parts():
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var pl := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if pl != null and pl.get("_arm") != null:
		(pl.get("_arm") as SpringArm3D).remove_excluded_object(bp.get_rid())


## How cosy the bed placed at `bed` is (0 = it is just a bed in a field).
func comfort_at(bed: BuildPiece) -> int:
	var g := _game()
	if g == null or bed == null:
		return 0
	return BuildGrid.comfort(grid_items(g.built).values(), bed.position.x, bed.position.z, bed.level)


func _process(delta: float) -> void:
	_time += delta
	var g := _game()
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null:
		_update_cutaway(pl)
	if g == null or pl == null or g.current_tool != GameState.Tool.BUILD or pl.get("vehicle") != null or Moon.inside(pl.global_position):
		_ghost.visible = false
		return
	_update_ghost(g, pl)


## Pure (tested): the storey you are standing on.
static func storey_of(height_above_ground: float) -> int:
	return clampi(floori((height_above_ground + 0.5) / BuildGrid.STOREY), 0, BuildGrid.MAX_LEVEL)


## Pure (tested): where the next piece goes for a player at `player` facing `yaw`:
## {pos, r, level}. Walls take the nearest edge and turn with you; roofs sit on the highest wall
## and copy their neighbour's direction. `turn` is the Q rotation, `lift` the T storey offset.
static func aim(id: String, player: Vector3, yaw: float, turn: int, lift: int, items: Dictionary) -> Dictionary:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var raw := player + fwd * REACH
	var style: String = PIECES[id]["style"]
	var standing := storey_of(player.y - Terrain.height_at(player.x, player.z))
	var level := clampi(standing + lift, 0, BuildGrid.MAX_LEVEL)
	var pos := snap(raw)
	var r := turn % 2
	match BuildGrid.kind_of(style):
		"edge":
			r = (BuildGrid.facing_axis(yaw) + turn) % 2
			pos = BuildGrid.snap_edge(raw, r)
		"roof":
			var cell := BuildGrid.cell_of(pos.x, pos.z)
			var top := -1
			for it in items.values():
				if it["kind"] == "edge" and BuildGrid.edge_cells(it["x"], it["z"], it["r"]).has(cell):
					top = maxi(top, int(it["l"]))
			var near_axis := -1
			for it2 in items.values():
				var c2 := BuildGrid.cell_of(it2["x"], it2["z"])
				if it2["kind"] == "roof" and absi(c2.x - cell.x) + absi(c2.y - cell.y) == 1:
					near_axis = int(it2["r"]) % 2
					if top < 0:
						top = int(it2["l"]) - 1
			level = clampi((top + 1 if top >= 0 else standing + 1) + lift, 1, BuildGrid.MAX_LEVEL + 1)
			r = ((near_axis if near_axis >= 0 else BuildGrid.facing_axis(yaw)) + turn) % 2
		"cell":
			r = (BuildGrid.facing_quarter(yaw) + turn) % 4 if style == "stairs" else turn % 4
	return {"pos": pos, "r": r, "level": level}


func _update_ghost(g: GameState, pl: Node3D) -> void:
	var yaw: float = pl.get("_model").rotation.y if pl.get("_model") != null else 0.0
	var items := grid_items(g.built)
	var a := aim(piece_id, pl.global_position, yaw, rot, level_offset, items)
	var p: Vector3 = a["pos"]
	_ghost_r = a["r"]
	_ghost_level = a["level"]
	var key := key_for(piece_id, p, _ghost_r, _ghost_level)
	var shape := [0, 1, true, true]
	if PIECES[piece_id]["style"] == "roof" and not items.has(key):
		var with_it := items.duplicate()
		with_it[key] = {"id": piece_id, "style": "roof", "kind": "roof", "x": p.x, "z": p.z, "r": _ghost_r, "l": _ghost_level}
		shape = roof_shape_at(with_it, p.x, p.z, _ghost_level, _ghost_r)
	if _ghost_look != "%s%s" % [piece_id, str(shape)]:
		_rebuild_ghost(shape)
	p.y = world_y(p.x, p.z, _ghost_level)
	_ghost_pos = p
	_ghost_support = support_for(piece_id, p.x, p.z, _ghost_r, _ghost_level, g)
	var ok := can_place(key, pieces, Terrain.is_water(p.x, p.z), g.count(piece_id)) and _ghost_support >= BuildGrid.MIN_SUPPORT \
		and not blocks_stairwell(items, piece_id, p.x, p.z, _ghost_level) and _space_free(p)
	_ghost_ok = ok
	_ghost.visible = true
	_ghost.global_position = p
	_ghost.rotation.y = yaw_of(_ghost_r)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var c := BuildGrid.support_color(_ghost_support) if ok else Color(1.0, 0.35, 0.3)
	if pieces.has(key):
		c = Color(0.45, 0.75, 1.0)   # blue: aiming at an existing piece (click to demolish)
	_ghost_mat.albedo_color = Color(c.r, c.g, c.b, 0.30 + 0.2 * pulse)
	_ghost_mat.emission = c
	_ghost_mat.emission_energy_multiplier = 0.4 + 0.6 * pulse
	_ghost.scale = Vector3.ONE * (1.0 + 0.02 * pulse)


## Tufts hide under whatever you build (and come back when it is demolished).
func _update_grass() -> void:
	if is_inside_tree():
		get_tree().call_group("meadow", "refresh_built")


## Physics check: nothing solid (trees, rocks, buildings) where the piece would stand.
func _space_free(p: Vector3) -> bool:
	if not is_inside_tree() or PIECES[piece_id]["style"] == "roof":
		return true
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	var sz: Vector3 = PIECES[piece_id]["size"]
	box.size = Vector3(sz.x * 0.9, 0.3, sz.z)
	q.shape = box
	q.transform = Transform3D(Basis(Vector3.UP, yaw_of(_ghost_r)), p + Vector3(0, sz.y * 0.8, 0))
	q.collision_mask = 1
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null:
		q.exclude = [pl.get_rid()]
	for hit in space.intersect_shape(q, 8):
		var col = hit.get("collider")
		if col is BuildPiece or (col is Node and (col as Node).get_parent() is BuildPiece):
			continue
		if col is Terrain:
			continue
		return false
	return true


func aiming_key() -> String:
	var key := key_for(piece_id, _ghost_pos, _ghost_r, _ghost_level)
	return key if pieces.has(key) else ""


func prompt() -> String:
	var g := _game()
	if g == null:
		return ""
	return prompt_for(piece_id, g.count(piece_id), aiming_key() != "", _ghost_level, _ghost_support)


## Called by the player on E / click with the Builder tool. Returns a short anim name.
func use(pl: Node3D) -> String:
	var g := _game()
	if g == null:
		return ""
	var key := aiming_key()
	if key != "":
		if demolish(key, g):
			g.shake.emit(0.12)
			Sfx.play_on(self, "chop", 0.8)
			FX.hit_stop(get_tree(), 0.25)
			return "1H_Melee_Attack_Chop"
		return ""
	if not _ghost_ok:
		var why := "Can't build there."
		if _ghost_support < BuildGrid.MIN_SUPPORT:
			why = "Nothing to hold that up. Put walls under it first."
		elif blocks_stairwell(grid_items(g.built), piece_id, _ghost_pos.x, _ghost_pos.z, _ghost_level):
			why = "Leave a stairwell open above the stairs."
		g.say(why if g.count(piece_id) > 0 else "Craft %s at the workbench first." % PIECES[piece_id]["name"])
		return ""
	if place(piece_id, _ghost_pos, _ghost_r, g, _ghost_level):
		g.shake.emit(0.1)
		if not PIECES[piece_id]["style"] in BuildKit.STYLES:
			Sfx.play_on(self, "thud", 1.3)
		g.hint_event.emit("build")
		if g.count(piece_id) == 0:
			piece_id = next_piece(piece_id, 1, g.inventory)
			_rebuild_ghost()
		return "Interact"
	return ""


func _unhandled_input(event: InputEvent) -> void:
	var g := _game()
	if g == null or g.current_tool != GameState.Tool.BUILD:
		return
	if event.is_action_pressed("craft_next"):
		rot = (rot + 1) % 4
		Sfx.play_on(self, "blip", 1.2)
	elif event.is_action_pressed("build_level"):
		level_offset = (level_offset + 1) % 3
		Sfx.play_on(self, "blip", 1.0 + 0.25 * level_offset)
	elif event.is_action_pressed("build_cycle"):
		piece_id = next_piece(piece_id, 1, g.inventory)
		_rebuild_ghost()
		Sfx.play_on(self, "blip", 0.9)
