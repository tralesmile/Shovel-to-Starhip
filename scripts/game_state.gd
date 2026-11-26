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
signal story_advanced(act: int)
signal hint_event(name: String)  ## context events for one-time tutorial hints

const DAY_LENGTH := 120.0          ## real seconds per in-game day
const START_TIME := 0.25           ## 0..1 of a day; 0.25 = 6:00
const SAVE_PATH := "user://save.json"

enum Tool { HOE, SEEDS, WATER, AXE, PICKAXE, BUILD, SLINGSHOT }
const TOOL_NAMES := ["Hoe", "Turnip Seeds", "Watering Can", "Axe", "Pickaxe", "Builder", "Slingshot"]

## Crop table: seed item, harvest item, watered nights to ripen, ripe model.
const CROPS := {
	"turnip": {"days": 2, "model": "food_ingredient_onion.gltf", "y": -0.12, "scale": 0.5},
	"carrot": {"days": 3, "model": "food_ingredient_carrot.gltf", "y": 0.0, "scale": 0.55},
	"tomato": {"days": 4, "model": "food_ingredient_tomato.gltf", "y": 0.0, "scale": 0.6, "regrow": 2, "picks": 3},
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
	"compost": {"name": "Compost", "buy": 0, "sell": 2},
	"squeaky_chicken": {"name": "Squeaky Chicken", "buy": 0, "sell": 0},
	"velvet_picks": {"name": "Velvet Picks", "buy": 0, "sell": 0},
	"sprinkler": {"name": "Copper Sprinkler", "buy": 0, "sell": 0},
	"hay": {"name": "Hay Bundle", "buy": 0, "sell": 3},
	"sunmint": {"name": "Sunmint", "buy": 0, "sell": 14},
	"scythe": {"name": "Scythe", "buy": 0, "sell": 0},
	# Meadow critters (caught by hand or with the Bug Net).
	"butterfly": {"name": "Butterfly", "buy": 0, "sell": 12},
	"grasshopper": {"name": "Grasshopper", "buy": 0, "sell": 8},
	"frog": {"name": "Frog", "buy": 0, "sell": 22},
	"firefly": {"name": "Firefly", "buy": 0, "sell": 10},
	"bug_net": {"name": "Bug Net", "buy": 0, "sell": 0},
	"firefly_jar": {"name": "Firefly Jar", "buy": 0, "sell": 0},
	"sunmint_bait": {"name": "Sunmint Bait", "buy": 0, "sell": 4},
	"springy_rod": {"name": "Springy Rod", "buy": 0, "sell": 0},
	"hay_bale": {"name": "Bouncy Hay Bale", "buy": 0, "sell": 0},
	# Mining drops.
	"stone": {"name": "Stone", "buy": 0, "sell": 4},
	"copper_ore": {"name": "Copper Ore", "buy": 0, "sell": 18},
	"gem": {"name": "Shiny Gem", "buy": 0, "sell": 90},
	"glow_crystal": {"name": "Glow Crystal", "buy": 0, "sell": 45},
	"boom_turnip": {"name": "Boom Turnip", "buy": 0, "sell": 15},
	"miner_helmet": {"name": "Miner's Helmet", "buy": 0, "sell": 0},
	# Hunting and cooking.
	"rabbit_meat": {"name": "Rabbit Meat", "buy": 0, "sell": 12},
	"rabbit_pelt": {"name": "Rabbit Pelt", "buy": 0, "sell": 20},
	"rabbit_stew": {"name": "Rabbit Stew", "buy": 0, "sell": 55},
	"cooked_meat": {"name": "Roast Rabbit", "buy": 0, "sell": 32},
	"egg": {"name": "Happy Egg", "buy": 0, "sell": 15},
	"campfire": {"name": "Campfire", "buy": 0, "sell": 0},
	"furnace": {"name": "Stone Furnace", "buy": 0, "sell": 0},
	"anvil": {"name": "Iron-ish Anvil", "buy": 0, "sell": 0},
	"invention_bench": {"name": "Invention Bench", "buy": 0, "sell": 0},
	"magnet_gloves": {"name": "Magnet Gloves", "buy": 0, "sell": 0},
	"spring_boots": {"name": "Spring Boots", "buy": 0, "sell": 0},
	"glider": {"name": "Pelt Glider", "buy": 0, "sell": 0},
	"loot_vacuum": {"name": "Loot Vacuum", "buy": 0, "sell": 0},
	"saddle": {"name": "Goat Saddle", "buy": 0, "sell": 0},
	"saddle_bags": {"name": "Saddle Bags", "buy": 0, "sell": 0},
	"goat_whistle": {"name": "Goat Whistle", "buy": 0, "sell": 0},
	"turbo_engine": {"name": "Turbo Engine", "buy": 0, "sell": 0},
	"offroad_wheels": {"name": "Big Wheels", "buy": 0, "sell": 0},
	"rocket_booster": {"name": "Rocket Booster", "buy": 0, "sell": 0},
	"bull_bar": {"name": "Bull Bar", "buy": 0, "sell": 0},
	"drift_tyres": {"name": "Drift Tyres", "buy": 0, "sell": 0},
	"repair_kit": {"name": "Repair Kit", "buy": 0, "sell": 20},
	# Crafted at the workbench.
	"plank": {"name": "Plank", "buy": 0, "sell": 4},
	"copper_ingot": {"name": "Copper Ingot", "buy": 0, "sell": 50},
	"polished_gem": {"name": "Polished Gem", "buy": 0, "sell": 220},
	"fence_panel": {"name": "Fence Panel", "buy": 0, "sell": 28},
	"stone_wall": {"name": "Stone Wall", "buy": 0, "sell": 20},
	"wood_floor": {"name": "Wood Floor", "buy": 0, "sell": 12},
	"wood_wall": {"name": "Wood Wall", "buy": 0, "sell": 16},
	"wood_door": {"name": "Wood Doorway", "buy": 0, "sell": 20},
	"wood_roof": {"name": "Wood Roof", "buy": 0, "sell": 18},
	"rocket_plate": {"name": "Rocket Hull Plate", "buy": 0, "sell": 0},
	"copper_pickaxe": {"name": "Copper Pickaxe", "buy": 0, "sell": 0},
	"gem_pickaxe": {"name": "Gem Pickaxe", "buy": 0, "sell": 0},
	"slingshot": {"name": "Slingshot", "buy": 0, "sell": 0},
	"copper_axe": {"name": "Copper Axe", "buy": 0, "sell": 0},
	"wheelbarrow": {"name": "Wheelbarrow", "buy": 0, "sell": 0},
	"wood_table": {"name": "Wood Table", "buy": 0, "sell": 0},
	"wood_chair": {"name": "Wood Chair", "buy": 0, "sell": 0},
	"wood_bed": {"name": "Wood Bed", "buy": 0, "sell": 0},
	"lantern": {"name": "Lantern Post", "buy": 0, "sell": 0},
	"storage_chest": {"name": "Storage Chest", "buy": 0, "sell": 0},
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
	{"id": "wood_door", "name": "Wood Doorway", "in": {"plank": 4, "copper_ingot": 1}, "out": {"wood_door": 1}},
	{"id": "wood_roof", "name": "Wood Roof", "in": {"plank": 5}, "out": {"wood_roof": 1}},
	{"id": "wood_table", "name": "Wood Table", "in": {"plank": 4}, "out": {"wood_table": 1}},
	{"id": "wood_chair", "name": "Wood Chair", "in": {"plank": 2}, "out": {"wood_chair": 1}},
	{"id": "wood_bed", "name": "Wood Bed", "in": {"plank": 5, "rabbit_pelt": 1}, "out": {"wood_bed": 1}},
	{"id": "lantern", "name": "Lantern Post", "in": {"plank": 1, "copper_ingot": 1, "gem": 1}, "out": {"lantern": 1}},
	{"id": "campfire", "name": "Campfire", "in": {"stone": 3, "wood": 2}, "out": {"campfire": 1}},
	{"id": "furnace", "name": "Stone Furnace", "in": {"stone": 8, "wood": 2}, "out": {"furnace": 1}},
	{"id": "anvil", "name": "Anvil", "in": {"copper_ingot": 4, "stone": 4}, "out": {"anvil": 1}},
	{"id": "rabbit_stew", "name": "Rabbit Stew", "in": {"rabbit_meat": 2, "carrot": 1}, "out": {"rabbit_stew": 1}},
	{"id": "storage_chest", "name": "Storage Chest", "in": {"plank": 6, "copper_ingot": 1}, "out": {"storage_chest": 1}},
	{"id": "saddle", "name": "Goat Saddle", "in": {"plank": 2, "rabbit_pelt": 2}, "out": {"saddle": 1}, "once": true},
	{"id": "turbo_engine", "name": "Turbo Engine", "in": {"copper_ingot": 3, "plank": 2}, "out": {"turbo_engine": 1}, "once": true},
	{"id": "offroad_wheels", "name": "Big Wheels", "in": {"plank": 4, "rabbit_pelt": 1, "copper_ingot": 1}, "out": {"offroad_wheels": 1}, "once": true},
	{"id": "rocket_booster", "name": "Rocket Booster", "in": {"rocket_plate": 1, "copper_ingot": 2, "gem": 1}, "out": {"rocket_booster": 1}, "once": true},
	{"id": "gem_pickaxe", "name": "Gem Pickaxe", "in": {"gem": 2, "copper_ingot": 2, "plank": 1}, "out": {"gem_pickaxe": 1}, "once": true},
	{"id": "slingshot", "name": "Slingshot", "in": {"plank": 2, "rabbit_pelt": 1}, "out": {"slingshot": 1}, "once": true},
	{"id": "invention_bench", "name": "Invention Bench", "in": {"plank": 6, "copper_ingot": 3, "gem": 1}, "out": {"invention_bench": 1}},
	{"id": "boom_turnip", "name": "Boom Turnips", "in": {"turnip": 1, "stone": 2, "copper_ore": 1}, "out": {"boom_turnip": 2}},
	{"id": "miner_helmet", "name": "Miner's Helmet", "in": {"copper_ingot": 2, "glow_crystal": 2}, "out": {"miner_helmet": 1}, "once": true},
	{"id": "scythe", "name": "Scythe", "in": {"plank": 2, "stone": 2}, "out": {"scythe": 1}, "once": true},
	{"id": "hay_bale", "name": "Bouncy Hay Bale", "in": {"hay": 6, "plank": 1}, "out": {"hay_bale": 1}},
	{"id": "bug_net", "name": "Bug Net", "in": {"plank": 2, "hay": 4}, "out": {"bug_net": 1}, "once": true},
	{"id": "firefly_jar", "name": "Firefly Jar", "in": {"firefly": 4, "plank": 1, "copper_ingot": 1}, "out": {"firefly_jar": 1}},
	{"id": "sunmint_bait", "name": "Sunmint Bait", "in": {"sunmint": 1, "hay": 1}, "out": {"sunmint_bait": 3}},
	{"id": "springy_rod", "name": "Springy Rod", "in": {"plank": 3, "copper_ingot": 1, "hay": 2}, "out": {"springy_rod": 1}, "once": true},
	{"id": "repair_kit", "name": "Repair Kit", "in": {"copper_ingot": 1, "plank": 2}, "out": {"repair_kit": 1}},
	{"id": "bull_bar", "name": "Bull Bar", "in": {"copper_ingot": 2, "stone": 4}, "out": {"bull_bar": 1}, "once": true},
	{"id": "drift_tyres", "name": "Drift Tyres", "in": {"hay": 4, "copper_ingot": 2, "plank": 1}, "out": {"drift_tyres": 1}, "once": true},
	{"id": "squeaky_chicken", "name": "Squeaky Chicken", "in": {"hay": 3, "plank": 1}, "out": {"squeaky_chicken": 1}},
	{"id": "velvet_picks", "name": "Velvet Picks", "in": {"copper_ingot": 1, "rabbit_pelt": 1}, "out": {"velvet_picks": 1}, "once": true},
	{"id": "compost", "name": "Compost", "in": {"hay": 3}, "out": {"compost": 2}},
	{"id": "sprinkler", "name": "Copper Sprinkler", "in": {"copper_ingot": 1, "plank": 1, "stone": 2}, "out": {"sprinkler": 1}},
	{"id": "saddle_bags", "name": "Saddle Bags", "in": {"hay": 4, "rabbit_pelt": 2, "plank": 1}, "out": {"saddle_bags": 1}, "once": true},
	{"id": "goat_whistle", "name": "Goat Whistle", "in": {"wood": 3, "sunmint": 1}, "out": {"goat_whistle": 1}, "once": true},
]

## Carry weight per item (kg-ish, Valheim-style encumbrance). Missing = 0.2 (light stuff, seeds, fish).
const ITEM_WEIGHT := {"wood": 2.0, "stone": 3.0, "copper_ore": 2.5, "gem": 0.5, "plank": 1.0, "copper_ingot": 1.5,
	"stone_wall": 6.0, "fence_panel": 3.0, "wood_floor": 4.0, "wood_wall": 5.0, "wood_door": 5.0, "wood_roof": 5.0, "wood_table": 4.0, "wood_chair": 2.0, "wood_bed": 6.0, "lantern": 2.0, "storage_chest": 6.0, "campfire": 4.0, "furnace": 8.0, "anvil": 10.0, "invention_bench": 9.0, "saddle": 1.0, "turbo_engine": 4.0, "offroad_wheels": 4.0, "rocket_booster": 5.0, "rocket_plate": 5.0, "turnip": 0.5, "carrot": 0.4, "tomato": 0.3,
	"copper_pickaxe": 0.0, "gem_pickaxe": 0.0, "copper_axe": 0.0, "wheelbarrow": 0.0, "magnet_gloves": 0.0, "spring_boots": 0.0, "glider": 0.0, "slingshot": 0.0, "loot_vacuum": 0.0,
	"glow_crystal": 0.5, "boom_turnip": 0.5, "miner_helmet": 0.0,
	"hay": 0.4, "sunmint": 0.1, "scythe": 0.0, "hay_bale": 4.0,
	"butterfly": 0.05, "grasshopper": 0.05, "frog": 0.3, "firefly": 0.02, "bug_net": 0.0, "firefly_jar": 2.0,
	"sunmint_bait": 0.05, "springy_rod": 0.0,
	"bull_bar": 4.0, "drift_tyres": 4.0, "repair_kit": 1.0, "compost": 0.3, "sprinkler": 2.0, "squeaky_chicken": 0.3, "velvet_picks": 0.0, "saddle_bags": 0.0, "goat_whistle": 0.0}
const CARRY_FREE := 30.0       ## below this you move at full speed
const CARRY_WHEELBARROW := 40.0  ## extra free capacity with a wheelbarrow
const CARRY_SADDLE_BAGS := 20.0  ## your friend the goat hauls this much in the bags

## Raw -> cooked at a campfire (pure data, tested).
const COOKABLE := {"rabbit_meat": "cooked_meat"}
const COOK_TIME := 3.0
## Furnace smelting (Terraria-style station tier): 1 ore + 1 wood fuel -> 1 ingot in 4s (workbench hand-smelting needs 2 ore).
## Anvil (Terraria-style tier): hammer ingots into hull plates, 3 strikes. Cheaper than the workbench plate (no planks, 2 ingots).
const ANVIL_RECIPES := [{"id": "rocket_plate", "in": {"copper_ingot": 2}, "out": "rocket_plate", "strikes": 3}]
## Invention Bench gadgets (Terraria Tinkerer-style combos): one-off wearables that change how you move and gather.
const INVENTIONS := [
	{"id": "magnet_gloves", "in": {"copper_ingot": 2, "gem": 1, "plank": 1}, "taps": 2, "line": "Magnet Gloves! Loot now flies to you from twice as far."},
	{"id": "spring_boots", "in": {"rabbit_pelt": 2, "copper_ingot": 1, "plank": 2}, "taps": 3, "line": "Spring Boots! Boing. Gravity filed a complaint."},
	{"id": "glider", "in": {"rabbit_pelt": 3, "plank": 2, "copper_ingot": 1}, "taps": 3, "line": "Pelt Glider! Hold jump in the air to float. Rabbits are not consulted."},
	## Gadget combine (Terraria Tinkerer-style): Magnet Gloves + junk -> a funnier, stronger gadget that replaces them.
	{"id": "loot_vacuum", "in": {"magnet_gloves": 1, "copper_ingot": 2, "gem": 1, "plank": 1}, "taps": 4, "line": "LOOT VACUUM! Everything not nailed down comes to you. Check your pockets for neighbours."},
]
const MAGNET_BASE := 2.6
const MAGNET_GLOVES := 5.4
const MAGNET_VACUUM := 11.0
const JUMP_BASE := 5.0
const JUMP_BOOTS := 6.6
const SMELTABLE := {"copper_ore": {"out": "copper_ingot", "ore": 1, "fuel": 1}}
const SMELT_TIME := 4.0

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
var fish_log: Dictionary = {}   ## species -> {n, best (cm)}
var crime_suspicion: float = 0.0   ## highest witness meter right now (HUD only)
var fence_sold_today: int = 0   ## items fenced today (resets each morning)
var heat: float = 0.0           ## 0..MAX_HEAT, rises when witnesses sound the alarm

var goat_friend := false   ## the goat is tamed (restored from the goat's own save entry)
var car_owned: bool = false
var stash: Dictionary = {}  ## shared contents of every Storage Chest (Gran's magic stash)
var story_act: int = 0   ## index into Story.ACTS (saved)
var meadow_cut: Dictionary = {}  ## cut grass tuft index (as text) -> day it was cut (saved)
var _story_timer := 0.0
var car_parts: Array = []   ## installed Car.PARTS ids
var car_damage: float = 0.0   ## 0 mint .. 1 wreck
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
	_story_timer += delta
	if _story_timer >= 0.5:
		_story_timer = 0.0
		check_story()
	if not clock_running:
		return
	time_of_day += delta / DAY_LENGTH
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		advance_day()


## Advance the story when the current act's checklist is complete. Returns true if it advanced.
func check_story() -> bool:
	if not Story.act_complete(story_act, self):
		return false
	var done: Dictionary = Story.ACTS[story_act]
	story_act += 1
	earn(int(done["reward"]))
	say("Act complete: %s! +$%d" % [done["title"], int(done["reward"])])
	if not Story.is_finished(story_act):
		say(str(Story.ACTS[story_act]["intro"]))
	shake.emit(0.6)
	story_advanced.emit(story_act)
	return true


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
				if count(id) > 0 or id in car_parts:
					out.append(i)
	return out


func cycle_recipe(dir: int = 1) -> int:
	selected_recipe = next_recipe(selected_recipe, dir, owned_once_recipes())
	return selected_recipe


## "need 2 more Wood, 1 more Stone" for the recipe (empty when craftable).
func recipe_missing(idx: int) -> String:
	var parts: PackedStringArray = []
	for id in RECIPES[idx]["in"]:
		var lack: int = int(RECIPES[idx]["in"][id]) - count_with_stash(id)
		if lack > 0:
			parts.append("%d more %s" % [lack, ITEMS[id]["name"]])
	return "need " + ", ".join(parts) if parts.size() > 0 else ""


func can_craft(idx: int) -> bool:
	if idx < 0 or idx >= RECIPES.size():
		return false
	if RECIPES[idx].get("once", false):
		for id in RECIPES[idx]["out"]:
			if count(id) > 0 or id in car_parts:
				return false   # one-off upgrade already owned (or bolted to the car)
	for id in RECIPES[idx]["in"]:
		if count_with_stash(id) < int(RECIPES[idx]["in"][id]):
			return false
	return true


func craft(idx: int) -> bool:
	if not can_craft(idx):
		return false
	for id in RECIPES[idx]["in"]:
		var need := int(RECIPES[idx]["in"][id])
		var from_pockets := mini(need, count(id))
		if from_pockets > 0:
			remove_item(id, from_pockets)
		if need > from_pockets:
			stash[id] = int(stash.get(id, 0)) - (need - from_pockets)
			if int(stash[id]) <= 0:
				stash.erase(id)
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
	return CARRY_FREE + (CARRY_WHEELBARROW if count("wheelbarrow") > 0 else 0.0) \
		+ (CARRY_SADDLE_BAGS if goat_friend and count("saddle_bags") > 0 else 0.0)


## Pure (tested): pickup magnet radius, doubled by Magnet Gloves.
static func magnet_range(gloves: bool, vacuum: bool = false) -> float:
	if vacuum:
		return MAGNET_VACUUM
	return MAGNET_GLOVES if gloves else MAGNET_BASE


## Pure (tested): jump speed; Spring Boots boost on foot, a mount keeps its own jump.
static func jump_speed(boots: bool, mounted: bool, mount_jump: float) -> float:
	if mounted:
		return mount_jump
	return JUMP_BOOTS if boots else JUMP_BASE


## Pure (tested): first not-yet-owned gadget the pockets can pay for, or {}.
static func invention_ready(inv: Dictionary) -> Dictionary:
	for r in INVENTIONS:
		if int(inv.get(r["id"], 0)) > 0:
			continue
		var ok := true
		for id in r["in"]:
			if int(inv.get(id, 0)) < int(r["in"][id]):
				ok = false
		if ok:
			return r
	return {}


## Items that exist as physical things you can drop on the ground (seeds, tools and pieces cannot).
const DROPPABLE := ["wood", "plank", "stone", "copper_ore", "copper_ingot", "gem", "carrot", "rabbit_meat", "rabbit_pelt", "turnip", "tomato", "rabbit_stew", "cooked_meat", "egg", "glow_crystal", "hay", "sunmint"]


## Pure (tested): which item G drops: the one adding the most weight to your pockets (ties: alphabetical).
func drop_candidate() -> String:
	var best := ""
	var best_w := -1.0
	var ids := inventory.keys()
	ids.sort()
	for id in ids:
		if not (id in DROPPABLE) or count(id) <= 0:
			continue
		var w := float(count(id)) * float(ITEM_WEIGHT.get(id, 0.2))
		if w > best_w:
			best_w = w
			best = id
	return best


## Items that stay in your pockets: tools, mounts, car parts and stolen loot (the law can find a chest).
const NO_STASH := ["copper_pickaxe", "gem_pickaxe", "copper_axe", "wheelbarrow", "saddle", "turbo_engine", "offroad_wheels", "rocket_booster", "magnet_gloves", "spring_boots", "glider", "slingshot", "loot_vacuum", "miner_helmet", "scythe", "bug_net", "bull_bar", "drift_tyres", "velvet_picks", "saddle_bags", "goat_whistle"]


## Pure (tested): can this item go in a chest?
static func stashable(id: String) -> bool:
	return ITEMS.has(id) and not (id in NO_STASH) and not bool(ITEMS[id].get("loot", false))


## Pocket count plus what the chest holds (crafting draws on both, Terraria-style).
func count_with_stash(id: String) -> int:
	return count(id) + int(stash.get(id, 0))


## Pure (tested): Terraria "Quick Stack": move every stashable item from `inv` into `stash`
## (all of it). Returns the number of items moved.
static func quick_stack(inv: Dictionary, st: Dictionary) -> int:
	var moved := 0
	for id in inv.keys().duplicate():
		if stashable(id):
			var n := int(inv[id])
			st[id] = int(st.get(id, 0)) + n
			inv.erase(id)
			moved += n
	return moved


## Pure (tested): take everything back out of the chest. Returns the number of items moved.
static func take_all(inv: Dictionary, st: Dictionary) -> int:
	var moved := 0
	for id in st.keys().duplicate():
		var n := int(st[id])
		inv[id] = int(inv.get(id, 0)) + n
		st.erase(id)
		moved += n
	return moved


func chest_deposit() -> int:
	var n := GameState.quick_stack(inventory, stash)
	if n > 0:
		inventory_changed.emit()
	return n


func chest_withdraw() -> int:
	var n := GameState.take_all(inventory, stash)
	if n > 0:
		inventory_changed.emit()
	return n


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
	index = clampi(index, 0, TOOL_NAMES.size() - 1)
	if index == Tool.SLINGSHOT and count("slingshot") <= 0:
		say("Craft a Slingshot at the workbench first (2 planks + 1 rabbit pelt).")
		return
	current_tool = index
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
	if i == Tool.HOE and count("scythe") > 0:
		return "Hoe Scythe"
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
	var w := weather()
	if Weather.is_wet(w):
		for node in get_tree().get_nodes_in_group("daily"):
			if node.has_method("rain_water"):
				node.rain_water()
	# Sprinklers run last, once every plot has had its night.
	for node in get_tree().get_nodes_in_group("sprinkler"):
		node.morning_spray()
	day_changed.emit(day)
	if Weather.is_wet(w):
		say(Weather.morning_line(w))
	else:
		say("Day %d. %s" % [day, NEW_DAY_JOKES[day % NEW_DAY_JOKES.size()]])
	save_game()


## Today's weather (deterministic from the day number).
func weather() -> String:
	return Weather.for_day(day)


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
	car_parts = []
	car_damage = 0.0
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
		"fish_log": fish_log.duplicate(true),
		"heat": heat,
		"fence_sold_today": fence_sold_today,
		"reputation": reputation,
		"car_owned": car_owned,
		"car_parts": car_parts,
		"car_damage": car_damage,
		"story_act": story_act,
		"stash": stash,
		"meadow_cut": meadow_cut.duplicate(),
		"car_pos": car_pos,
		"world": world,
	}


func from_dict(data: Dictionary) -> void:
	goat_friend = false
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
	fish_log = {}
	var fl: Dictionary = data.get("fish_log", {})
	for k in fl.keys():
		fish_log[str(k)] = {"n": int(fl[k].get("n", 1)), "best": int(fl[k].get("best", 0))}
	heat = float(data.get("heat", 0.0))
	reputation = float(data.get("reputation", 0.0))
	fence_sold_today = int(data.get("fence_sold_today", 0))
	car_owned = bool(data.get("car_owned", false))
	car_parts = data.get("car_parts", [])
	car_damage = clampf(float(data.get("car_damage", 0.0)), 0.0, 1.0)
	story_act = clampi(int(data.get("story_act", 0)), 0, Story.act_count())
	stash = {}
	var st: Dictionary = data.get("stash", {})
	for k in st.keys():
		stash[k] = int(st[k])
	meadow_cut = {}
	var mc: Dictionary = data.get("meadow_cut", {})
	for k in mc.keys():
		meadow_cut[str(k)] = int(mc[k])
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
	_key_action("tool_7", [KEY_7])
	_key_action("build_cycle", [KEY_F])
	_key_action("craft_next", [KEY_Q])
	_key_action("help", [KEY_H, KEY_F1])
	_key_action("drop_item", [KEY_G])
	_key_action("throw_bomb", [KEY_B])
	_key_action("throw_decoy", [KEY_V])
	_key_action("whistle", [KEY_R])
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
	"craft_next": [JOY_BUTTON_BACK], "tool_3": [JOY_BUTTON_DPAD_DOWN], "tool_4": [JOY_BUTTON_DPAD_LEFT], "tool_5": [JOY_BUTTON_LEFT_SHOULDER], "tool_6": [JOY_BUTTON_RIGHT_STICK], "tool_7": [JOY_BUTTON_LEFT_STICK], "build_cycle": [JOY_BUTTON_LEFT_STICK], "drop_item": [JOY_BUTTON_PADDLE1], "whistle": [JOY_BUTTON_PADDLE2],
}
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"throw_bomb": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"throw_decoy": [JOY_AXIS_TRIGGER_LEFT, 1.0],
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
