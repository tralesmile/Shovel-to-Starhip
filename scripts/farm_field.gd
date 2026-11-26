class_name FarmField
extends Node3D
## Watches the 4x4 field for giant crops. When a 2x2 block holds the same crop, all ripe and all
## watered overnight, it may fuse into one enormous vegetable (compost raises the odds a lot).

const COLS := 4   ## plots are numbered column by column: index = col * 4 + row
const ROWS := 4
const BASE_CHANCE := 0.2
const COMPOST_CHANCE := 0.2   ## per composted plot in the block: four composted = certain

var plots: Array = []   ## FarmPlot, in index order


func _ready() -> void:
	name = "FarmField"
	add_to_group("daily")      # added after the plots, so their night is resolved first
	add_to_group("saveable")


## Pure (tested): the four plot indices of every 2x2 block.
static func blocks() -> Array:
	var out: Array = []
	for c in COLS - 1:
		for r in ROWS - 1:
			var i := c * ROWS + r
			out.append([i, i + 1, i + ROWS, i + ROWS + 1])
	return out


## Pure (tested): chance per night for an eligible block.
static func giant_chance(composted: int) -> float:
	return clampf(BASE_CHANCE + COMPOST_CHANCE * composted, 0.0, 1.0)


## Pure (tested): deterministic 0..1 roll for a block on a day.
static func roll(day: int, block: int) -> float:
	return float(posmod(hash("giant:%d:%d" % [day, block]), 1000)) / 1000.0


## Pure (tested): may these four plots fuse? Each entry: {crop, ripe, wet, giant}.
static func eligible(cells: Array) -> bool:
	if cells.size() != 4:
		return false
	for c in cells:
		if not c["ripe"] or not c["wet"] or c["giant"] or c["crop"] != cells[0]["crop"]:
			return false
	return true


func _cells(block: Array) -> Array:
	var out: Array = []
	for i in block:
		var p: FarmPlot = plots[i]
		out.append({"crop": p.crop, "ripe": p.is_ripe(), "wet": p.slept_wet, "giant": p.giant})
	return out


func on_new_day(game: GameState) -> void:
	if plots.size() < COLS * ROWS:
		return
	var all := blocks()
	for b in all.size():
		var block: Array = all[b]
		if not eligible(_cells(block)):
			continue
		var fed := 0
		for i in block:
			if (plots[i] as FarmPlot).composted:
				fed += 1
		if roll(game.day, b) < giant_chance(fed):
			var g := form(block)
			game.say.call_deferred("Overnight, something on your farm got VERY big. A giant %s!" % g.crop)


## Fuse four plots into one giant (also used when loading a save).
func form(block: Array) -> GiantCrop:
	var centre := Vector3.ZERO
	var crop_id: String = (plots[block[0]] as FarmPlot).crop
	for i in block:
		var p: FarmPlot = plots[i]
		p.make_giant()
		centre += p.position
	var g := GiantCrop.new()
	g.crop = crop_id
	g.block = block.duplicate()
	g.field = self
	g.position = centre / 4.0
	add_child(g)
	g.arrive()
	return g


func giants() -> Array:
	return get_children().filter(func(n): return n is GiantCrop and not n.is_queued_for_deletion())


func loose_giants() -> Array:
	return get_children().filter(func(n): return n is GiantBall and not n.is_queued_for_deletion())


## A rooted giant has been tugged free: it becomes a rolling physics object.
func uproot(g: GiantCrop, game: GameState) -> GiantBall:
	for i in g.block:
		(plots[i] as FarmPlot).clear_giant()
	g.drop_collider()
	var ball := spawn_ball(g.crop, g.position + Vector3(0, GiantBall.RADIUS + 0.15, 0), game)
	g.queue_free()
	return ball


func spawn_ball(crop_id: String, at: Vector3, game: GameState) -> GiantBall:
	var ball := GiantBall.new()
	ball.crop = crop_id
	ball.game = game
	ball.position = at
	add_child(ball)
	return ball


func to_dict() -> Dictionary:
	var rooted: Array = []
	for g in giants():
		rooted.append({"block": g.block, "tugs": g.tugs})
	var loose: Array = []
	for b in loose_giants():
		var p: Vector3 = b.position
		loose.append({"crop": b.crop, "x": p.x, "y": p.y, "z": p.z, "chops": b.chops})
	return {"giants": rooted, "loose": loose}


func from_dict(d: Dictionary) -> void:
	for n in get_children():
		if n is GiantCrop or n is GiantBall:
			remove_child(n)
			n.queue_free()
	var claimed := {}
	for e in d.get("giants", []):
		var block: Array = []
		for v in e.get("block", []):
			var i := int(v)
			if i >= 0 and i < plots.size():
				block.append(i)
		if block.size() != 4 or not (plots[block[0]] as FarmPlot).giant:
			continue
		var g := form(block)
		g.tugs = clampi(int(e.get("tugs", 0)), 0, GiantCrop.TUGS - 1)
		g.sit()
		for i in block:
			claimed[i] = true
	# A plot that thinks it is giant but has no giant would be stuck forever: free it.
	for i in plots.size():
		var p: FarmPlot = plots[i]
		if p.giant and not claimed.has(i):
			p.clear_giant()
	var game := get_node_or_null("/root/Game") as GameState
	for e in d.get("loose", []):
		var crop_id := str(e.get("crop", "turnip"))
		if not CropModel.is_crop(crop_id):
			continue
		var ball := spawn_ball(crop_id, Vector3(float(e.get("x", 0)), float(e.get("y", 1.5)), float(e.get("z", 0))), game)
		ball.chops = int(e.get("chops", 0))
