class_name BuildGrid
extends RefCounted
## Pure building rules (all tested): edge snapping, storeys, structural support, auto-shaped
## roofs and how cosy a bedroom is. Positions are metres; cells are 2 m wide and centred on
## even coordinates, so their edges sit on odd ones.

const GRID := 2.0
const STOREY := 2.2
const MAX_LEVEL := 2          ## ground, upstairs, attic (roofs may rest one higher)
const MIN_SUPPORT := 0.25
const FROM_BELOW := 0.85      ## load carried straight down onto a wall
const WALL_ON_FLOOR := 0.7
const FLOOR_CANTILEVER := 0.55
const ROOF_SPAN := 0.6
const FURNITURE_ON_FLOOR := 0.9
const COZY_MAX := 4
const COMFORT_STYLES := ["table", "chair", "lantern", "firejar", "crystallamp", "chest", "campfire"]


## "edge" (walls and fences), "floor", "roof" or "cell" (stairs and furniture).
static func kind_of(style: String) -> String:
	if style in ["fence", "block", "plank_wall", "doorway", "window"]:
		return "edge"
	if style == "floor" or style == "roof":
		return style
	return "cell"


## Which way a wall should run for a player looking along `yaw`: 0 = along X, 1 = along Z.
static func facing_axis(yaw: float) -> int:
	return 0 if absf(cos(yaw)) >= absf(sin(yaw)) else 1


## The quarter turn (0..3) closest to `yaw`.
static func facing_quarter(yaw: float) -> int:
	return posmod(roundi(yaw / (PI * 0.5)), 4)


## Snap a point to the nearest cell edge for a wall running along `axis`.
static func snap_edge(p: Vector3, axis: int) -> Vector3:
	var along_x := axis % 2 == 0
	var x := roundf(p.x / GRID) * GRID if along_x else floorf(p.x / GRID) * GRID + GRID * 0.5
	var z := floorf(p.z / GRID) * GRID + GRID * 0.5 if along_x else roundf(p.z / GRID) * GRID
	return Vector3(x, p.y, z)


static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(roundi(x / GRID), roundi(z / GRID))


## The cells a wall borders. Walls saved before edge snapping sit mid-cell and count for that cell.
static func edge_cells(x: float, z: float, axis: int) -> Array:
	var perp := z if axis % 2 == 0 else x
	if posmod(roundi(perp), 2) == 0:
		return [cell_of(x, z)]
	if axis % 2 == 0:
		return [Vector2i(roundi(x / GRID), roundi((z - 1.0) / GRID)), Vector2i(roundi(x / GRID), roundi((z + 1.0) / GRID))]
	return [Vector2i(roundi((x - 1.0) / GRID), roundi(z / GRID)), Vector2i(roundi((x + 1.0) / GRID), roundi(z / GRID))]


static func _next_to(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


## How much `item` can lean on `other` (both {kind, x, z, r, l}); 0 = not at all.
static func passes_load(other: Dictionary, item: Dictionary) -> float:
	var l: int = item["l"]
	var ol: int = other["l"]
	var cell := cell_of(item["x"], item["z"])
	var ocell := cell_of(other["x"], other["z"])
	match str(item["kind"]):
		"edge":
			if other["kind"] == "edge" and ol == l - 1 and is_equal_approx(other["x"], item["x"]) \
					and is_equal_approx(other["z"], item["z"]) and int(other["r"]) % 2 == int(item["r"]) % 2:
				return FROM_BELOW
			if other["kind"] == "floor" and ol == l and edge_cells(item["x"], item["z"], item["r"]).has(ocell):
				return WALL_ON_FLOOR
		"floor", "roof":
			if other["kind"] == "edge" and ol == l - 1 and edge_cells(other["x"], other["z"], other["r"]).has(cell):
				return FROM_BELOW
			if other["kind"] == item["kind"] and ol == l and _next_to(cell, ocell):
				return FLOOR_CANTILEVER if item["kind"] == "floor" else ROOF_SPAN
		"cell":
			if other["kind"] == "floor" and ol == l and ocell == cell:
				return FURNITURE_ON_FLOOR
	return 0.0


## Valheim-style support for every piece: 1.0 on the ground, weaker the further the load travels.
## `items` is key -> {kind, x, z, r, l}; returns key -> 0..1.
static func supports(items: Dictionary) -> Dictionary:
	var out := {}
	var by_cell := {}
	var raised: Array = []
	for k in items:
		var it: Dictionary = items[k]
		out[k] = 1.0 if int(it["l"]) <= 0 else 0.0
		if int(it["l"]) > 0:
			raised.append(k)
		var c := cell_of(it["x"], it["z"])
		if not by_cell.has(c):
			by_cell[c] = []
		by_cell[c].append(k)
	var changed := true
	var passes := 0
	while changed and passes < 64:
		changed = false
		passes += 1
		for k in raised:
			var it2: Dictionary = items[k]
			var c2 := cell_of(it2["x"], it2["z"])
			var best: float = out[k]
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					for ok in by_cell.get(c2 + Vector2i(dx, dz), []):
						if ok != k:
							best = maxf(best, float(out[ok]) * passes_load(items[ok], it2))
			if best > float(out[k]) + 0.0001:
				out[k] = best
				changed = true
	return out


## Which pieces fall when `removed` goes: only ones that were holding up fine before (so an old
## save never collapses by surprise). Lowest first.
static func collapsed(items: Dictionary, removed: String) -> Array:
	var before := supports(items)
	var left := items.duplicate()
	left.erase(removed)
	var out: Array = []
	var again := true
	while again:
		again = false
		var now := supports(left)
		for k in left.keys():
			if float(before[k]) >= MIN_SUPPORT and float(now[k]) < MIN_SUPPORT:
				out.append(k)
				left.erase(k)
				again = true
	out.sort_custom(func(a, b): return int(items[a]["l"]) < int(items[b]["l"]) or (int(items[a]["l"]) == int(items[b]["l"]) and str(a) < str(b)))
	return out


static func support_color(s: float) -> Color:
	if s >= 0.7:
		return Color(0.4, 1.0, 0.5)
	if s >= 0.45:
		return Color(0.95, 0.95, 0.35)
	if s >= MIN_SUPPORT:
		return Color(1.0, 0.62, 0.2)
	return Color(1.0, 0.32, 0.28)


static func support_word(s: float) -> String:
	if s >= 0.7:
		return "solid"
	if s >= 0.45:
		return "sturdy enough"
	if s >= MIN_SUPPORT:
		return "wobbly"
	return "nothing to hold it up"


# ---------------------------------------------------------------- roofs

## World step along a roof's slope direction (its local +X) for axis 0 or 1.
static func slope_step(axis: int) -> Vector2:
	return Vector2(GRID, 0) if axis % 2 == 0 else Vector2(0, -GRID)


static func roof_id(x: float, z: float, l: int) -> String:
	return "%d,%d,%d" % [roundi(x), roundi(z), l]


## Where a roof tile sits in its row of touching tiles: (index, count). `roofs` maps roof_id -> axis.
static func roof_span(roofs: Dictionary, x: float, z: float, l: int, axis: int) -> Vector2i:
	var step := slope_step(axis)
	var before := 0
	var after := 0
	while before < 8:
		var k := roof_id(x - step.x * (before + 1), z - step.y * (before + 1), l)
		if not roofs.has(k) or int(roofs[k]) % 2 != axis % 2:
			break
		before += 1
	while after < 8:
		var k2 := roof_id(x + step.x * (after + 1), z + step.y * (after + 1), l)
		if not roofs.has(k2) or int(roofs[k2]) % 2 != axis % 2:
			break
		after += 1
	return Vector2i(before, before + 1 + after)


## Rise per metre: narrow roofs are steep, wide ones flatten so they stay a sensible height.
static func roof_pitch(count: int) -> float:
	return minf(0.55, 1.5 / float(maxi(count, 1)))


## Height above the eaves `u` metres across a roof `count` tiles wide (one shared gable).
static func roof_height(u: float, count: int) -> float:
	return roof_pitch(count) * maxf(0.0, minf(u, count * GRID - u))


## The flat slabs tile `index` is made of, as [u0, u1] pairs (split where the ridge crosses it).
static func roof_segments(index: int, count: int) -> Array:
	var u0 := index * GRID
	var u1 := u0 + GRID
	var mid := count * GRID * 0.5
	if mid > u0 + 0.01 and mid < u1 - 0.01:
		return [[u0, mid], [mid, u1]]
	return [[u0, u1]]


# ---------------------------------------------------------------- comfort

## How cosy a bed at (x, z, l) is, 0..COZY_MAX. It needs a roof or floor overhead and walls on
## at least three sides; then each different kind of furniture nearby adds a point.
static func comfort(items: Array, x: float, z: float, l: int) -> int:
	var home := cell_of(x, z)
	var covered := false
	var floors := {}
	var walls: Array = []
	for it in items:
		var c := cell_of(it["x"], it["z"])
		if int(it["l"]) > l and (it["kind"] == "roof" or it["kind"] == "floor") and c == home:
			covered = true
		if int(it["l"]) == l and it["kind"] == "floor":
			floors[c] = true
		if int(it["l"]) == l and it["kind"] == "edge" and str(it.get("style", "")) != "fence":
			walls.append(edge_cells(it["x"], it["z"], it["r"]) + [int(it["r"]) % 2])
	if not covered:
		return 0
	var sides := 0
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c2: Vector2i = home
		for step in 4:
			var nxt: Vector2i = c2 + dir
			var axis := 1 if dir.x != 0 else 0
			var hit := false
			for w in walls:
				if int(w[w.size() - 1]) == axis and w.size() == 3 and w.has(c2) and w.has(nxt):
					hit = true
					break
			if hit:
				sides += 1
				break
			if not floors.has(nxt):
				break
			c2 = nxt
	if sides < 3:
		return 0
	var kinds := {}
	for it in items:
		var st := str(it.get("style", ""))
		if st in COMFORT_STYLES and int(it["l"]) == l and Vector2(it["x"] - x, it["z"] - z).length() <= 5.0:
			kinds[st] = true
	return mini(COZY_MAX, 1 + kinds.size())


## Sprint stamina drain after waking in a bed of comfort `c`.
static func rested_drain_mult(c: int) -> float:
	return 1.0 - 0.12 * clampi(c, 0, COZY_MAX)


static func comfort_line(c: int) -> String:
	if c <= 0:
		return ""
	var words: String = ["", "Snug", "Cosy", "Very cosy", "Gloriously cosy"][clampi(c, 1, COZY_MAX)]
	return "%s night under your own roof! Well rested: sprinting tires you %d%% less." % [words, roundi((1.0 - rested_drain_mult(c)) * 100.0)]
