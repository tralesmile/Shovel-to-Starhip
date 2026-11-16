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

const DAY_LENGTH := 120.0          ## real seconds per in-game day
const START_TIME := 0.25           ## 0..1 of a day; 0.25 = 6:00
const SAVE_PATH := "user://save.json"

enum Tool { HOE, SEEDS, WATER, AXE }
const TOOL_NAMES := ["Hoe", "Turnip Seeds", "Watering Can", "Axe"]

const ITEMS := {
	"turnip_seed": {"name": "Turnip Seeds", "buy": 10, "sell": 0},
	"turnip": {"name": "Turnip", "buy": 0, "sell": 35},
	"wood": {"name": "Wood", "buy": 0, "sell": 5},
	# Stolen goods: sell 0 at the bin; the fence buys them.
	"gold_spoon": {"name": "Gold Spoon", "buy": 0, "sell": 0, "loot": true, "value": 60},
	"suspicious_vase": {"name": "Suspicious Vase", "buy": 0, "sell": 0, "loot": true, "value": 90},
	"garden_gnome": {"name": "Garden Gnome", "buy": 0, "sell": 0, "loot": true, "value": 120},
	"rubber_duck_gold": {"name": "Golden Rubber Duck", "buy": 0, "sell": 0, "loot": true, "value": 200},
}

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
var day: int = 1
var time_of_day: float = START_TIME
var current_tool: int = Tool.HOE
var clock_running: bool = true
var total_earned: int = 0
var crime_suspicion: float = 0.0   ## highest witness meter right now (HUD only)
var heat: float = 0.0           ## 0..MAX_HEAT, rises when witnesses sound the alarm

var car_owned: bool = false
var car_pos: Array = [8.0, 0.0, 14.0, 1.5708]   ## x, y, z, heading of the parked car

var reputation: float = 0.0     ## -MAX_REP (Outlaw) .. +MAX_REP (Lawful)

const MAX_REP := 10.0
const FENCE_CUT := 0.5          ## fence pays this share of an item's value
const MAX_HEAT := 3.0
const HEAT_DECAY_PER_DAY := 1.0
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


func count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


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


func buy(item_id: String, amount: int = 1) -> bool:
	var price: int = ITEMS[item_id]["buy"] * amount
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
	var total := 0
	for id in inventory.keys():
		if ITEMS.get(id, {}).get("loot", false):
			total += fence_price(id) * count(id)
	return total


## Per-item fence price: half value, +4% per Outlaw point (they like a pro).
func fence_price(item_id: String) -> int:
	var v: int = ITEMS.get(item_id, {}).get("value", 0)
	var bonus := 1.0 + 0.04 * maxf(0.0, -reputation)
	return int(round(v * FENCE_CUT * bonus))


## Sells all stolen goods to the fence. Returns money earned; turns you more Outlaw.
func fence_sell_all() -> int:
	var total := 0
	var items := 0
	for id in inventory.keys():
		if ITEMS.get(id, {}).get("loot", false):
			total += fence_price(id) * count(id)
			items += count(id)
			inventory.erase(id)
	if items > 0:
		inventory_changed.emit()
		earn(total)
		add_reputation(-1.0 * items)
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
	current_tool = clampi(index, 0, TOOL_NAMES.size() - 1)
	tool_changed.emit(current_tool)


# ---------------------------------------------------------------- heat

func heat_level() -> int:
	return int(ceil(heat - 0.001))


func heat_name() -> String:
	return HEAT_NAMES[clampi(heat_level(), 0, HEAT_NAMES.size() - 1)]


func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, MAX_HEAT)
	if amount > 0.0:
		add_reputation(-amount)   # getting caught costs your good name


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
	return {"fine": fine, "loot": lost}


# ---------------------------------------------------------------- time

func advance_day() -> void:
	day += 1
	heat = maxf(0.0, heat - HEAT_DECAY_PER_DAY)
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
		"day": day,
		"time_of_day": time_of_day,
		"current_tool": current_tool,
		"total_earned": total_earned,
		"heat": heat,
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
	day = int(data.get("day", 1))
	time_of_day = float(data.get("time_of_day", START_TIME))
	current_tool = int(data.get("current_tool", 0))
	total_earned = int(data.get("total_earned", 0))
	heat = float(data.get("heat", 0.0))
	reputation = float(data.get("reputation", 0.0))
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
	_key_action("interact", [KEY_E])
	_key_action("tool_1", [KEY_1])
	_key_action("tool_2", [KEY_2])
	_key_action("tool_3", [KEY_3])
	_key_action("tool_4", [KEY_4])
	_key_action("help", [KEY_H, KEY_F1])
	_key_action("save", [KEY_F5])
	_key_action("pause", [KEY_ESCAPE])
	if not InputMap.has_action("interact_click"):
		InputMap.add_action("interact_click")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("interact_click", mb)


func _key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
