class_name GameState
extends Node
## Global game state: money, inventory, clock, tools, save/load.
## Registered as the autoload "Game". Tests create their own instance.

signal money_changed(value: int)
signal inventory_changed
signal toast(text: String)
signal day_changed(day: int)
signal tool_changed(index: int)
signal shake(amount: float)
signal built_loaded
signal hint_event(name: String)  ## context events for one-time tutorial hints

const DAY_LENGTH := 120.0          ## real seconds per in-game day
const START_TIME := 0.25           ## 0..1 of a day; 0.25 = 6:00
const SAVE_PATH := "user://save.json"

enum Tool { HOE, SEEDS, WATER, AXE, PICKAXE, BUILD }
const TOOL_NAMES := ["Hoe", "Turnip Seeds", "Watering Can", "Axe", "Pickaxe", "Builder"]

## Crop table: seed item, harvest item, watered nights to ripen, ripe model.
const CROPS := {
	"turnip": {"days": 2, "model": "food_ingredient_onion.gltf", "y": -0.12, "scale": 0.5},
	"carrot": {"days": 3, "model": "food_ingredient_carrot.gltf", "y": 0.0, "scale": 0.55},
	"tomato": {"days": 4, "model": "food_ingredient_tomato.gltf", "y": 0.0, "scale": 0.6},
}
const CROP_ORDER := ["turnip", "carrot", "tomato"]

const ITEMS := {
	"turnip_seed": {"name": "Turnip Seeds", "buy": 10, "sell": 0},
	"turnip": {"name": "Turnip", "buy": 0, "sell": 35},
	"carrot_seed": {"name": "Carrot Seeds", "buy": 18, "sell": 0},
	"carrot": {"name": "Carrot", "buy": 0, "sell": 70},
	"tomato_seed": {"name": "Tomato Seeds", "buy": 30, "sell": 0},
	"tomato": {"name": "Tomato", "buy": 0, "sell": 125},
	"wood": {"name": "Wood", "buy": 0, "sell": 5},
	# Mining drops.
	"stone": {"name": "Stone", "buy": 0, "sell": 4},
	"copper_ore": {"name": "Copper Ore", "buy": 0, "sell": 18},
	"gem": {"name": "Shiny Gem", "buy": 0, "sell": 90},
	# Crafted at the workbench.
	"plank": {"name": "Plank", "buy": 0, "sell": 4},
	"copper_ingot": {"name": "Copper Ingot", "buy": 0, "sell": 50},
	"polished_gem": {"name": "Polished Gem", "buy": 0, "sell": 220},
	"fence_panel": {"name": "Fence Panel", "buy": 0, "sell": 28},
	"stone_wall": {"name": "Stone Wall", "buy": 0, "sell": 20},
	"wood_floor": {"name": "Wood Floor", "buy": 0, "sell": 12},
	"wood_wall": {"name": "Wood Wall", "buy": 0, "sell": 16},
	"rocket_plate": {"name": "Rocket Hull Plate", "buy": 0, "sell": 0},
	"copper_pickaxe": {"name": "Copper Pickaxe", "buy": 0, "sell": 0},
	"copper_axe": {"name": "Copper Axe", "buy": 0, "sell": 0},
	"wheelbarrow": {"name": "Wheelbarrow", "buy": 0, "sell": 0},
	# Fish: sell at the bin.
	"boot": {"name": "Old Boot", "buy": 0, "sell": 2},
	"minnow": {"name": "Minnow", "buy": 0, "sell": 8},
	"carp": {"name": "Carp", "buy": 0, "sell": 20},
	"trout": {"name": "Trout", "buy": 0, "sell": 40},
	"golden_carp": {"name": "Golden Carp", "buy": 0, "sell": 150},
	"old_wizard_hat": {"name": "Soggy Wizard Hat", "buy": 0, "sell": 60},
	# Stolen goods: sell 0 at the bin; the fence buys them.
	"gold_spoon": {"name": "Gold Spoon", "buy": 0, "sell": 0, "loot": true, "value": 60},
	"suspicious_vase": {"name": "Suspicious Vase", "buy": 0, "sell": 0, "loot": true, "value": 90},
	"garden_gnome": {"name": "Garden Gnome", "buy": 0, "sell": 0, "loot": true, "value": 120},
	"rubber_duck_gold": {"name": "Golden Rubber Duck", "buy": 0, "sell": 0, "loot": true, "value": 200},
}

## Workbench recipes (ordered). "in" is consumed, "out" is produced.
const RECIPES := [
	{"id": "plank", "name": "Planks", "in": {"wood": 2}, "out": {"plank": 3}},
	{"id": "fence_panel", "name": "Fence Panel", "in": {"plank": 4}, "out": {"fence_panel": 1}},
	{"id": "copper_ingot", "name": "Copper Ingot", "in": {"copper_ore": 2, "wood": 1}, "out": {"copper_ingot": 1}},
	{"id": "polished_gem", "name": "Polished Gem", "in": {"gem": 1, "stone": 2}, "out": {"polished_gem": 1}},
	{"id": "copper_pickaxe", "name": "Copper Pickaxe", "in": {"copper_ingot": 2, "plank": 2}, "out": {"copper_pickaxe": 1}, "once": true},
	{"id": "copper_axe", "name": "Copper Axe", "in": {"copper_ingot": 2, "plank": 2}, "out": {"copper_axe": 1}, "once": true},
	{"id": "rocket_plate", "name": "Rocket Hull Plate", "in": {"copper_ingot": 3, "plank": 2}, "out": {"rocket_plate": 1}},
	{"id": "stone_wall", "name": "Stone Wall", "in": {"stone": 4}, "out": {"stone_wall": 1}},
	{"id": "wheelbarrow", "name": "Wheelbarrow", "in": {"plank": 4, "copper_ingot": 1}, "out": {"wheelbarrow": 1}, "once": true},
	{"id": "wood_floor", "name": "Wood Floor", "in": {"plank": 3}, "out": {"wood_floor": 1}},
	{"id": "wood_wall", "name": "Wood Wall", "in": {"plank": 4}, "out": {"wood_wall": 1}},
]

## Carry weight per item (kg-ish, Valheim-style encumbrance). Missing = 0.2 (light stuff, seeds, fish).
const ITEM_WEIGHT := {"wood": 2.0, "stone": 3.0, "copper_ore": 2.5, "gem": 0.5, "plank": 1.0, "copper_ingot": 1.5,
	"stone_wall": 6.0, "fence_panel": 3.0, "wood_floor": 4.0, "wood_wall": 5.0, "rocket_plate": 5.0, "turnip": 0.5, "carrot": 0.4, "tomato": 0.3,
	"copper_pickaxe": 0.0, "copper_axe": 0.0, "wheelbarrow": 0.0}
const CARRY_FREE := 30.0       ## below this you move at full speed
const CARRY_WHEELBARROW := 40.0  ## extra free capacity with a wheelbarrow

const CARRY_LIMIT := 4   ## max stolen items in your pockets

const NEW_DAY_JOKES := [
	"The rooster has opinions about this.",
	"The goat ate your alarm clock. Again.",
	"Somewhere, a rocket waits. Patiently. Very patiently.",
	"You feel 3% more like a farmer today.",
	"The turnips whisper. Probably fine.",
]

var money: int = 50
var inventory: Dictionary = {"turnip_seed": 5}
var built: Array = []   ## placed building pieces: {id, x, z, r}
var day: int = 1
var time_of_day: float = START_TIME
var current_tool: int = Tool.HOE
var selected_recipe: int = 0         ## workbench picker choice (not saved)
var selected_crop: String = "turnip"   ## which seed the Seeds tool plants
var clock_running: bool = true
var total_earned: int = 0
var crime_suspicion: float = 0.0   ## highest witness meter right now (HUD only)
var fence_sold_today: int = 0   ## items fenced today (resets each morning)
var heat: float = 0.0           ## 0..MAX_HEAT, rises when witnesses sound the alarm

var car_owned: bool = false
var car_pos: Array = [8.0, 0.0, 14.0, 1.5708]   ## x, y, z, heading of the parked car

var reputation: float = 0.0     ## -MAX_REP (Outlaw) .. +MAX_REP (Lawful)

const MAX_REP := 10.0
const FENCE_DAILY_ITEMS := 3    ## Shady Sal only has room for this many items per day
const FENCE_CUT := 0.5          ## fence pays this share of an item's value
const FENCE_HEAT_PENALTY := 0.2  ## price cut per heat level above 1
const MAX_HEAT := 3.0
const HEAT_DECAY_PER_DAY := 1.0
const OUT_COOL_PER_SEC := 0.008  ## slower cooling in the open while no cop has line of sight (125s per level)
const CROUCH_COOL_PER_SEC := 0.014  ## out-of-sight cooling while crouched in the open (~70s per level)
const HIDE_COOL_PER_SEC := 0.025  ## heat shed per second while out of sight (40s per level)
const HEAT_NAMES := ["Clean as a turnip", "Raised eyebrows", "Angry whispers", "Pitchforks (pending)"]


func _ready() -> void:
	setup_input()


func _process(delta: float) -> void:
	if not clock_running:
		return
	time_of_day += delta / DAY_LENGTH
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		advance_day()


# ---------------------------------------------------------------- money & items

func earn(amount: int) -> void:
	money += amount
	total_earned += amount
	money_changed.emit(money)


func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	money_changed.emit(money)
	return true


## Index of the first recipe whose ingredients you hold, or -1 (pure, tested).
func first_craftable() -> int:
	for i in RECIPES.size():
		if can_craft(i):
			return i
	return -1


## Recipe picker (workbench): index of the next recipe not yet owned (one-off upgrades), wrapping. Pure.
static func next_recipe(current: int, dir: int, owned_once: Array) -> int:
	var n := RECIPES.size()
	for step in range(1, n + 1):
		var i := posmod(current + dir * step, n)
		if not (i in owned_once):
			return i
	return current


func owned_once_recipes() -> Array:
	var out: Array = []
	for i in RECIPES.size():
		if RECIPES[i].get("once", false):
			for id in RECIPES[i]["out"]:
				if count(id) > 0:
					out.append(i)
	return out


func cycle_recipe(dir: int = 1) -> int:
	selected_recipe = next_recipe(selected_recipe, dir, owned_once_recipes())
	return selected_recipe


## "need 2 more Wood, 1 more Stone" for the recipe (empty when craftable).
func recipe_missing(idx: int) -> String:
	var parts: PackedStringArray = []
	for id in RECIPES[idx]["in"]:
		var lack: int = int(RECIPES[idx]["in"][id]) - count(id)
		if lack > 0:
			parts.append("%d more %s" % [lack, ITEMS[id]["name"]])
	return "need " + ", ".join(parts) if parts.size() > 0 else ""


func can_craft(idx: int) -> bool:
	if idx < 0 or idx >= RECIPES.size():
		return false
	if RECIPES[idx].get("once", false):
		for id in RECIPES[idx]["out"]:
			if count(id) > 0:
				return false   # one-off tool upgrade already owned
	for id in RECIPES[idx]["in"]:
		if count(id) < int(RECIPES[idx]["in"][id]):
			return false
	return true


func craft(idx: int) -> bool:
	if not can_craft(idx):
		return false
	for id in RECIPES[idx]["in"]:
		remove_item(id, int(RECIPES[idx]["in"][id]))
	for id in RECIPES[idx]["out"]:
		add_item(id, int(RECIPES[idx]["out"][id]))
	return true


static func recipe_text(idx: int) -> String:
	var r: Dictionary = RECIPES[idx]
	var ins: PackedStringArray = []
	for id in r["in"]:
		ins.append("%d %s" % [r["in"][id], ITEMS[id]["name"]])
	var outs: PackedStringArray = []
	for id in r["out"]:
		outs.append("%d %s" % [r["out"][id], ITEMS[id]["name"]])
	return "%s -> %s" % [", ".join(ins), ", ".join(outs)]


func count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


## Total weight of everything in the pockets (tested).
func carry_weight() -> float:
	var w := 0.0
	for id in inventory.keys():
		w += float(inventory[id]) * float(ITEM_WEIGHT.get(id, 0.2))
	return w


func carry_free() -> float:
	return CARRY_FREE + (CARRY_WHEELBARROW if count("wheelbarrow") > 0 else 0.0)


func add_item(item_id: String, amount: int = 1) -> void:
	inventory[item_id] = count(item_id) + amount
	inventory_changed.emit()


func remove_item(item_id: String, amount: int = 1) -> bool:
	if count(item_id) < amount:
		return false
	inventory[item_id] = count(item_id) - amount
	if inventory[item_id] == 0:
		inventory.erase(item_id)
	inventory_changed.emit()
	return true


func loot_count() -> int:
	var n := 0
	for id in inventory.keys():
		if ITEMS.get(id, {}).get("loot", false):
			n += count(id)
	return n


func can_carry(amount: int = 1) -> bool:
	return loot_count() + amount <= CARRY_LIMIT


## Adds a stolen item if the carry limit allows. Returns false when too heavy.
func add_loot(item_id: String) -> bool:
	if not can_carry():
		return false
	add_item(item_id, 1)
	return true


func item_name(item_id: String) -> String:
	return ITEMS.get(item_id, {}).get("name", item_id)


## Shop price multiplier: Lawful folks get 2% off per point (max 20%), shopkeepers
## add 10% per heat level above 1 ("hot goods surcharge").
func shop_multiplier() -> float:
	return 1.0 - 0.02 * maxf(0.0, reputation) + 0.1 * maxf(0.0, heat - 1.0)


func shop_price(item_id: String, amount: int = 1) -> int:
	return int(round(float(ITEMS[item_id]["buy"] * amount) * shop_multiplier()))


func buy(item_id: String, amount: int = 1) -> bool:
	var price: int = shop_price(item_id, amount)
	if not spend(price):
		return false
	add_item(item_id, amount)
	return true


## Sells every sellable item. Returns the money earned.
func sell_all() -> int:
	var total := 0
	for item_id in inventory.keys():
		var price: int = ITEMS.get(item_id, {}).get("sell", 0)
		if price > 0:
			total += price * count(item_id)
			inventory.erase(item_id)
	if total > 0:
		inventory_changed.emit()
		earn(total)
		add_reputation(0.5)   # honest work looks good on you
	return total


## What the fence would pay right now for everything stolen in your pockets.
func fence_offer() -> int:
	var prices: Array = []
	for id in inventory.keys():
		if ITEMS.get(id, {}).get("loot", false):
			for n in count(id):
				prices.append(fence_price(id))
	prices.sort()
	prices.reverse()
	var total := 0
	for k in mini(prices.size(), fence_room()):
		total += prices[k]
	return total


## Per-item fence price: half value, +4% per Outlaw point (they like a pro).
func fence_price(item_id: String) -> int:
	var v: int = ITEMS.get(item_id, {}).get("value", 0)
	var bonus := 1.0 + 0.04 * maxf(0.0, -reputation)
	return int(round(v * FENCE_CUT * bonus * fence_nerves()))


## The fence gets jumpy when the law is sniffing about: -20% per heat level above 1.
func fence_nerves() -> float:
	return 1.0 - FENCE_HEAT_PENALTY * maxf(0.0, float(heat_level() - 1))


## How many more items the fence will take today.
func fence_room() -> int:
	return maxi(0, FENCE_DAILY_ITEMS - fence_sold_today)


## Sells stolen goods to the fence (up to the daily cap, priciest first). Returns money earned;
## turns you more Outlaw.
func fence_sell_all() -> int:
	var total := 0
	var items := 0
	var ids: Array = []
	for id in inventory.keys():
		if ITEMS.get(id, {}).get("loot", false):
			ids.append(id)
	ids.sort_custom(func(a, b): return fence_price(a) > fence_price(b))
	for id in ids:
		while count(id) > 0 and items < fence_room():
			total += fence_price(id)
			items += 1
			inventory[id] -= 1
			if inventory[id] <= 0:
				inventory.erase(id)
	if items > 0:
		fence_sold_today += items
		inventory_changed.emit()
		earn(total)
		add_reputation(-1.0 * items)
		hint_event.emit("fence")
	return total


func add_reputation(amount: float) -> void:
	reputation = clampf(reputation + amount, -MAX_REP, MAX_REP)


func reputation_title() -> String:
	if reputation >= 3.0:
		return "Lawful"
	if reputation <= -3.0:
		return "Outlaw"
	return "Honest-ish"


func say(text: String) -> void:
	toast.emit(text)


func set_tool(index: int) -> void:
	if index == Tool.SEEDS and current_tool == Tool.SEEDS:
		cycle_crop()
		return
	current_tool = clampi(index, 0, TOOL_NAMES.size() - 1)
	tool_changed.emit(current_tool)


## Pressing [2] again with seeds in hand switches to the next seed type.
func cycle_crop() -> void:
	var i := CROP_ORDER.find(selected_crop)
	selected_crop = CROP_ORDER[(i + 1) % CROP_ORDER.size()]
	tool_changed.emit(current_tool)


func crop_seed_id(crop: String = "") -> String:
	return (selected_crop if crop == "" else crop) + "_seed"


func tool_label(i: int) -> String:
	if i == Tool.SEEDS:
		return "%s Seeds" % selected_crop.capitalize()
	return TOOL_NAMES[i]


# ---------------------------------------------------------------- heat

func heat_level() -> int:
	return int(ceil(heat - 0.001))


func heat_name() -> String:
	return HEAT_NAMES[clampi(heat_level(), 0, HEAT_NAMES.size() - 1)]


func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, MAX_HEAT)
	if amount > 0.0:
		hint_event.emit("heat")
		add_reputation(-amount)   # getting caught costs your good name


## Lie low: heat cools while you are hidden indoors and nobody is chasing you.
## `unseen` = in the open but out of every cop's line of sight: cools, slowly.
## `lying_low` is true while heat is actually cooling (HUD shows a hint).
var lying_low := false
var in_closet := false   ## hiding in a wardrobe (not saved)
const CLOSET_COOL_MULT := 3.0

func cool_heat(delta: float, hidden: bool, chased: bool, unseen: bool = false, crouched: bool = false, closet: bool = false) -> void:
	lying_low = false
	if chased or heat <= 0.0:
		return
	lying_low = hidden or unseen
	if hidden:
		heat = maxf(0.0, heat - HIDE_COOL_PER_SEC * (CLOSET_COOL_MULT if closet else 1.0) * delta)
	elif unseen:
		heat = maxf(0.0, heat - (CROUCH_COOL_PER_SEC if crouched else OUT_COOL_PER_SEC) * delta)
	if heat <= 0.0:
		lying_low = false


## Constable Bumble caught you. Loot is confiscated, a quarter of your cash
## (min $10, never more than you have) is fined, and the heat drops to level 1.
## Returns {"fine": int, "loot": int}.
func arrest() -> Dictionary:
	var lost := 0
	for id in inventory.keys():
		if ITEMS.get(id, {}).get("loot", false):
			lost += count(id)
			inventory.erase(id)
	var fine := mini(money, maxi(10, int(money * 0.25)))
	money -= fine
	heat = minf(heat, 1.0)
	inventory_changed.emit()
	hint_event.emit("arrest")
	return {"fine": fine, "loot": lost}


# ---------------------------------------------------------------- time

func advance_day() -> void:
	day += 1
	heat = maxf(0.0, heat - HEAT_DECAY_PER_DAY)
	fence_sold_today = 0
	for node in get_tree().get_nodes_in_group("daily"):
		node.on_new_day(self)
	day_changed.emit(day)
	say("Day %d. %s" % [day, NEW_DAY_JOKES[day % NEW_DAY_JOKES.size()]])
	save_game()


## Skip to the next morning (used by the bed).
func sleep() -> void:
	time_of_day = START_TIME
	advance_day()


func clock_text() -> String:
	var minutes := int(time_of_day * 24.0 * 60.0)
	var h := (minutes / 60) % 24
	var m := (minutes % 60) / 10 * 10
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


func buy_car() -> bool:
	if car_owned or not spend(Car.PRICE):
		return false
	car_owned = true
	car_pos = [8.0, 0.0, 14.0, 1.5708]
	return true


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	var world := {}
	for node in get_tree().get_nodes_in_group("saveable"):
		world[str(node.name)] = node.to_dict()
	return {
		"version": 1,
		"money": money,
		"inventory": inventory,
		"built": built.duplicate(true),
		"day": day,
		"time_of_day": time_of_day,
		"current_tool": current_tool,
		"selected_crop": selected_crop,
		"total_earned": total_earned,
		"heat": heat,
		"fence_sold_today": fence_sold_today,
		"reputation": reputation,
		"car_owned": car_owned,
		"car_pos": car_pos,
		"world": world,
	}


func from_dict(data: Dictionary) -> void:
	money = int(data.get("money", 50))
	inventory = {}
	var inv: Dictionary = data.get("inventory", {})
	for k in inv.keys():
		inventory[k] = int(inv[k])
	built = []
	for d in data.get("built", []):
		if typeof(d) == TYPE_DICTIONARY:
			built.append(d)
	day = int(data.get("day", 1))
	time_of_day = float(data.get("time_of_day", START_TIME))
	current_tool = int(data.get("current_tool", 0))
	selected_crop = str(data.get("selected_crop", "turnip"))
	if not CROPS.has(selected_crop):
		selected_crop = "turnip"
	total_earned = int(data.get("total_earned", 0))
	heat = float(data.get("heat", 0.0))
	reputation = float(data.get("reputation", 0.0))
	fence_sold_today = int(data.get("fence_sold_today", 0))
	car_owned = bool(data.get("car_owned", false))
	car_pos = data.get("car_pos", [8.0, 0.0, 14.0, 1.5708])
	var world: Dictionary = data.get("world", {})
	for node in get_tree().get_nodes_in_group("saveable"):
		if world.has(str(node.name)):
			node.from_dict(world[str(node.name)])
	money_changed.emit(money)
	inventory_changed.emit()
	tool_changed.emit(current_tool)
	day_changed.emit(day)
	built_loaded.emit()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	from_dict(data)
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		save_game()


# ---------------------------------------------------------------- input map

func setup_input() -> void:
	_key_action("move_forward", [KEY_W, KEY_UP])
	_key_action("move_back", [KEY_S, KEY_DOWN])
	_key_action("move_left", [KEY_A, KEY_LEFT])
	_key_action("move_right", [KEY_D, KEY_RIGHT])
	_key_action("jump", [KEY_SPACE])
	_key_action("sprint", [KEY_SHIFT])
	_key_action("crouch", [KEY_C, KEY_CTRL])
	_key_action("interact", [KEY_E])
	_key_action("tool_1", [KEY_1])
	_key_action("tool_2", [KEY_2])
	_key_action("tool_3", [KEY_3])
	_key_action("tool_4", [KEY_4])
	_key_action("tool_5", [KEY_5])
	_key_action("tool_6", [KEY_6])
	_key_action("build_cycle", [KEY_F])
	_key_action("craft_next", [KEY_Q])
	_key_action("help", [KEY_H, KEY_F1])
	_key_action("save", [KEY_F5])
	_key_action("pause", [KEY_ESCAPE])
	setup_gamepad()
	if not InputMap.has_action("interact_click"):
		InputMap.add_action("interact_click")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("interact_click", mb)


## Gamepad bindings (Xbox layout; Godot maps other pads to it). Adds to existing actions.
const PAD_BUTTONS := {
	"jump": [JOY_BUTTON_A], "interact": [JOY_BUTTON_X], "interact_click": [JOY_BUTTON_RIGHT_SHOULDER],
	"sprint": [JOY_BUTTON_LEFT_STICK], "crouch": [JOY_BUTTON_B], "help": [JOY_BUTTON_Y], "pause": [JOY_BUTTON_START],
	"tool_1": [JOY_BUTTON_DPAD_UP], "tool_2": [JOY_BUTTON_DPAD_RIGHT],
	"craft_next": [JOY_BUTTON_BACK], "tool_3": [JOY_BUTTON_DPAD_DOWN], "tool_4": [JOY_BUTTON_DPAD_LEFT], "tool_5": [JOY_BUTTON_LEFT_SHOULDER], "tool_6": [JOY_BUTTON_RIGHT_STICK], "build_cycle": [JOY_BUTTON_LEFT_STICK],
}
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
}


func setup_gamepad() -> void:
	for action in PAD_BUTTONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for b in PAD_BUTTONS[action]:
			if not _has_pad_event(action, InputEventJoypadButton, b):
				var ev := InputEventJoypadButton.new()
				ev.button_index = b
				InputMap.action_add_event(action, ev)
	for action in PAD_AXES:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		var a: Array = PAD_AXES[action]
		if not _has_pad_event(action, InputEventJoypadMotion, a[0]):
			var ev := InputEventJoypadMotion.new()
			ev.axis = a[0]
			ev.axis_value = a[1]
			InputMap.action_add_event(action, ev)


func _has_pad_event(action: String, type, code: int) -> bool:
	for e in InputMap.action_get_events(action):
		if is_instance_of(e, type):
			if type == InputEventJoypadButton and e.button_index == code:
				return true
			if type == InputEventJoypadMotion and e.axis == code:
				return true
	return false


func _key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
