class_name StarshipDesign
extends RefCounted
## The Starship workshop: four slots of bolt-on parts plus the numbers they give the flight.
## Pure data and logic (tested). A part is paid for once, then it can be swapped freely.

const SLOTS := ["nose", "fins", "engine", "paint"]
const SLOT_NAMES := {"nose": "Nose", "fins": "Fins", "engine": "Engine", "paint": "Paint"}

## lift = climb power, balance = how little she wobbles, range = fuel economy, cool = heat control.
const OPTIONS := {
	"nose": [
		{"id": "cone", "name": "Gran's Cone", "cost": {}, "stats": {}, "line": "Pointy. Traditional."},
		{"id": "cheese", "name": "Cheese Wedge", "cost": {"plank": 2, "turnip": 3}, "stats": {"cool": 0.3, "balance": -0.05}, "line": "Aged for aerodynamics. Runs cool."},
		{"id": "dome", "name": "Lookout Dome", "cost": {"polished_gem": 1, "copper_ingot": 2}, "stats": {"balance": 0.25, "lift": -0.05}, "line": "See the stars. Sail steady."},
	],
	"fins": [
		{"id": "tail", "name": "Tail Fins", "cost": {}, "stats": {}, "line": "Three fins, one dream."},
		{"id": "wings", "name": "Barn-Door Wings", "cost": {"plank": 6, "copper_ingot": 1}, "stats": {"balance": 0.35, "lift": -0.08}, "line": "Very steady. Very draggy."},
		{"id": "stubby", "name": "Stubby Nubs", "cost": {"copper_ingot": 2}, "stats": {"balance": -0.2, "lift": 0.12}, "line": "Light and twitchy."},
	],
	"engine": [
		{"id": "faithful", "name": "Old Faithful", "cost": {}, "stats": {}, "line": "A boiler with ambitions."},
		{"id": "triple", "name": "Triple Boosters", "cost": {"copper_ingot": 3, "rocket_plate": 1}, "stats": {"lift": 0.3, "range": -0.12, "cool": -0.15}, "line": "Three times the shove. Runs hot."},
		{"id": "turnip", "name": "Turnip Reactor", "cost": {"turnip": 8, "gem": 1}, "stats": {"range": 0.35, "lift": -0.05, "balance": -0.1}, "line": "Sips fuel. Hiccups."},
	],
	"paint": [
		{"id": "red", "name": "Gran's Red", "cost": {}, "stats": {}, "color": Color(0.92, 0.27, 0.22)},
		{"id": "turnip", "name": "Turnip Purple", "cost": {}, "stats": {}, "color": Color(0.62, 0.34, 0.82)},
		{"id": "pond", "name": "Pond Blue", "cost": {}, "stats": {}, "color": Color(0.2, 0.55, 0.92)},
		{"id": "hay", "name": "Hay Gold", "cost": {}, "stats": {}, "color": Color(0.97, 0.72, 0.16)},
		{"id": "meadow", "name": "Meadow Green", "cost": {}, "stats": {}, "color": Color(0.26, 0.72, 0.34)},
		{"id": "outlaw", "name": "Midnight Outlaw", "cost": {}, "stats": {}, "color": Color(0.16, 0.14, 0.24)},
	],
}
const STAT_NAMES := {"lift": "Lift", "balance": "Balance", "range": "Range", "cool": "Cooling"}


static func default_design() -> Dictionary:
	return {"nose": "cone", "fins": "tail", "engine": "faithful", "paint": "red"}


static func option(slot: String, id: String) -> Dictionary:
	for o in OPTIONS.get(slot, []):
		if o["id"] == id:
			return o
	return OPTIONS[slot][0] if OPTIONS.has(slot) else {}


static func index_of(slot: String, id: String) -> int:
	var list: Array = OPTIONS.get(slot, [])
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return 0


## The next (or previous) option id in a slot, wrapping round.
static func cycle(slot: String, id: String, dir: int) -> String:
	var list: Array = OPTIONS[slot]
	return list[posmod(index_of(slot, id) + dir, list.size())]["id"]


## A saved design with anything unknown replaced by the default part.
static func sanitize(d: Dictionary) -> Dictionary:
	var out := default_design()
	for slot in SLOTS:
		var id := str(d.get(slot, out[slot]))
		if option(slot, id)["id"] == id:
			out[slot] = id
	return out


static func paint_color(d: Dictionary) -> Color:
	return option("paint", str(d.get("paint", "red")))["color"]


## Flight multipliers around 1.0, clamped so no build is hopeless.
static func stats(d: Dictionary) -> Dictionary:
	var s := {"lift": 1.0, "balance": 1.0, "range": 1.0, "cool": 1.0}
	for slot in SLOTS:
		var o := option(slot, str(d.get(slot, "")))
		for k in o.get("stats", {}):
			s[k] += float(o["stats"][k])
	for k in s:
		s[k] = clampf(s[k], 0.6, 1.6)
	return s


## "##### " style bar for the workshop panel.
static func bar(v: float) -> String:
	var n := clampi(int(round((v - 0.6) / 1.0 * 10.0)), 0, 10)
	return "|".repeat(n) + ".".repeat(10 - n)


static func key(slot: String, id: String) -> String:
	return slot + ":" + id


static func is_unlocked(slot: String, id: String, unlocked: Array) -> bool:
	return option(slot, id).get("cost", {}).is_empty() or unlocked.has(key(slot, id))


## What is still missing to pay for a part, counting pockets and chest ("" = affordable).
static func missing(slot: String, id: String, g) -> String:
	var parts: PackedStringArray = []
	var cost: Dictionary = option(slot, id).get("cost", {})
	for item in cost:
		var short: int = int(cost[item]) - g.count_with_stash(item)
		if short > 0:
			parts.append("%d %s" % [short, g.item_name(item)])
	return ", ".join(parts)


static func cost_text(slot: String, id: String, g) -> String:
	var parts: PackedStringArray = []
	var cost: Dictionary = option(slot, id).get("cost", {})
	for item in cost:
		parts.append("%d %s (have %d)" % [int(cost[item]), g.item_name(item), g.count_with_stash(item)])
	return ", ".join(parts)


## Pay for a part once. Takes from pockets first, then the storage chest.
static func unlock(slot: String, id: String, g) -> bool:
	if is_unlocked(slot, id, g.ship_unlocked) or missing(slot, id, g) != "":
		return false
	var cost: Dictionary = option(slot, id)["cost"]
	for item in cost:
		var need := int(cost[item])
		var from_pockets: int = mini(need, g.count(item))
		if from_pockets > 0:
			g.remove_item(item, from_pockets)
		need -= from_pockets
		if need > 0:
			g.stash[item] = int(g.stash.get(item, 0)) - need
			if g.stash[item] <= 0:
				g.stash.erase(item)
	g.ship_unlocked.append(key(slot, id))
	return true


## The two endings, decided by how the town feels about you when you reach the Moon.
static func ending(reputation: float) -> Dictionary:
	if reputation < 0.0:
		return {"id": "outlaw", "title": "NOTORIOUS LEGEND", "text": "Wanted in one town. Unreachable on one Moon.\nConstable Bumble is looking up and shaking his tiny fist."}
	return {"id": "hero", "title": "LAWFUL HERO", "text": "The whole town is waving from the turnip fields.\nGran would be proud. Gran would also want cheese."}
