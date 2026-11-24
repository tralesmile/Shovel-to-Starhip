class_name BuildWorld
extends Node3D
## Build mode v1 (Valheim/Core Keeper style): with the Builder tool [6] a translucent ghost shows
## where the next piece will land, snapped to a 2m grid in front of you. Green = ok, red = blocked.
## Click/E places (pop-in bounce + dust), aiming at an existing piece and clicking demolishes it
## for a full refund. Q rotates, F switches piece. Pieces are saved in GameState.built.

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
	"lantern": {"name": "Lantern Post", "size": Vector3(0.3, 1.5, 0.3), "color": Color(0.3, 0.3, 0.34), "style": "lantern"},
	"wood_roof": {"name": "Wood Roof", "size": Vector3(2.3, 0.7, 2.3), "color": Color(0.62, 0.28, 0.22), "style": "roof", "y": 2.2},
}
const PIECE_ORDER := ["fence_panel", "stone_wall", "wood_floor", "wood_wall", "wood_door", "wood_roof", "wood_table", "wood_chair", "lantern"]

var pieces := {}   ## cell key -> BuildPiece
var piece_id := "fence_panel"
var rot := 0
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


## Unique key for a piece slot: grid cell plus rotation step (0..3, only 0 and 1 matter for a wall).
static func cell_key(p: Vector3, r: int) -> String:
	return "%d,%d,%d" % [int(roundf(p.x / GRID)), int(roundf(p.z / GRID)), r % 2]


## Pure: floors ignore rotation (one per cell, own key space) so a wall can stand on a floor cell.
static func key_for(id: String, p: Vector3, r: int) -> String:
	if PIECES.has(id) and PIECES[id]["style"] == "floor":
		return "f,%d,%d" % [int(roundf(p.x / GRID)), int(roundf(p.z / GRID))]
	if PIECES.has(id) and PIECES[id]["style"] == "roof":
		return "r,%d,%d" % [int(roundf(p.x / GRID)), int(roundf(p.z / GRID))]
	if is_furniture(id):
		return "m,%d,%d" % [int(roundf(p.x / GRID)), int(roundf(p.z / GRID))]
	return cell_key(p, r)


## Pure (tested): furniture lives in its own key space (one per cell, stands on floors).
static func is_furniture(id: String) -> bool:
	return PIECES.has(id) and PIECES[id]["style"] in ["table", "chair", "lantern"]


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
static func prompt_for(id: String, owned: int, aiming_at_piece: bool) -> String:
	var nm: String = PIECES[id]["name"]
	if aiming_at_piece:
		return "[E] Demolish piece (refunds 1)   {craft_next} rotate"
	if owned <= 0:
		return "No %s - craft some at the workbench   {build_cycle} switch piece" % nm
	return "[E] Place %s (%d left)   {craft_next} rotate   {build_cycle} switch" % [nm, owned]


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


func _rebuild_ghost() -> void:
	for c in _ghost.get_children():
		c.queue_free()
	var sz: Vector3 = PIECES[piece_id]["size"]
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	bm.material = _ghost_mat
	mi.mesh = bm
	mi.position.y = sz.y * 0.5 + base_y(piece_id)
	_ghost.add_child(mi)


## Respawn every saved piece (after load).
func rebuild_from_game() -> void:
	for k in pieces.keys():
		if is_instance_valid(pieces[k]):
			pieces[k].queue_free()
	pieces.clear()
	var g := _game()
	if g == null:
		return
	for d in g.built:
		_spawn(str(d.get("id", "fence_panel")), float(d.get("x", 0)), float(d.get("z", 0)), int(d.get("r", 0)), false)


func _spawn(id: String, x: float, z: float, r: int, animate: bool) -> BuildPiece:
	if not PIECES.has(id):
		return null
	var p := BuildPiece.new()
	p.piece_id = id
	p.rot = r
	p.position = Vector3(x, Terrain.height_at(x, z), z)
	add_child(p)
	pieces[key_for(id, p.position, r)] = p
	if animate:
		p.pop_in()
	return p


## Place a piece directly (no reach/collision checks). Used by use() and tests.
func place(id: String, pos: Vector3, r: int, g: GameState) -> bool:
	var key := key_for(id, pos, r)
	if not can_place(key, pieces, false, g.count(id)):
		return false
	g.remove_item(id, 1)
	g.built.append({"id": id, "x": pos.x, "z": pos.z, "r": r % 4})
	_spawn(id, pos.x, pos.z, r % 4, true)
	return true


## Remove a piece and refund it.
func demolish(key: String, g: GameState) -> bool:
	if not pieces.has(key):
		return false
	var p: BuildPiece = pieces[key]
	pieces.erase(key)
	for i in g.built.size():
		var d: Dictionary = g.built[i]
		if key_for(str(d["id"]), Vector3(d["x"], 0, d["z"]), int(d["r"])) == key:
			g.built.remove_at(i)
			break
	g.add_item(p.piece_id, 1)
	p.crumble()
	return true


func _process(delta: float) -> void:
	_time += delta
	var g := _game()
	var pl := get_tree().get_first_node_in_group("player")
	if g == null or pl == null or g.current_tool != GameState.Tool.BUILD or pl.get("vehicle") != null:
		_ghost.visible = false
		return
	_update_ghost(g, pl)


func _update_ghost(g: GameState, pl: Node3D) -> void:
	var yaw: float = pl.get("_model").rotation.y if pl.get("_model") != null else 0.0
	var p := target_pos(pl.global_position, yaw)
	p.y = Terrain.height_at(p.x, p.z)
	_ghost_pos = p
	var key := key_for(piece_id, p, rot)
	var ok := can_place(key, pieces, Terrain.is_water(p.x, p.z), g.count(piece_id)) and _space_free(p)
	_ghost_ok = ok
	_ghost.visible = true
	_ghost.global_position = p
	_ghost.rotation.y = yaw_of(rot)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var c := Color(0.4, 1.0, 0.5) if ok else Color(1.0, 0.35, 0.3)
	if pieces.has(key):
		c = Color(1.0, 0.8, 0.3)   # amber: aiming at an existing piece (click to demolish)
	_ghost_mat.albedo_color = Color(c.r, c.g, c.b, 0.30 + 0.2 * pulse)
	_ghost_mat.emission = c
	_ghost_mat.emission_energy_multiplier = 0.4 + 0.6 * pulse
	_ghost.scale = Vector3.ONE * (1.0 + 0.02 * pulse)


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
	q.transform = Transform3D(Basis(Vector3.UP, yaw_of(rot)), p + Vector3(0, sz.y * 0.8, 0))
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
	var key := key_for(piece_id, _ghost_pos, rot)
	return key if pieces.has(key) else ""


func prompt() -> String:
	var g := _game()
	if g == null:
		return ""
	return prompt_for(piece_id, g.count(piece_id), aiming_key() != "")


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
			return "1H_Melee_Attack_Chop"
		return ""
	if not _ghost_ok:
		g.say("Can't build there." if g.count(piece_id) > 0 else "Craft %s at the workbench first." % PIECES[piece_id]["name"])
		return ""
	if place(piece_id, _ghost_pos, rot, g):
		g.shake.emit(0.1)
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
		rot = (rot + 1) % 2
		Sfx.play_on(self, "blip", 1.2)
	elif event.is_action_pressed("build_cycle"):
		piece_id = next_piece(piece_id, 1, g.inventory)
		_rebuild_ghost()
		Sfx.play_on(self, "blip", 0.9)
