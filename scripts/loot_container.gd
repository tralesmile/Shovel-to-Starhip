class_name LootContainer
extends Interactable
## A locked drawer/chest in a home. E starts picking, E again sets a pin when the
## cursor is in the sweet zone. Loot goes in your pockets, up to the carry limit.

const LOOT_TABLE := [
	["gold_spoon", 0.4], ["suspicious_vase", 0.25], ["garden_gnome", 0.2], ["rubber_duck_gold", 0.15],
]

var difficulty: float = 0.0
var loot_id: String = "gold_spoon"
var state: String = "locked"     ## locked, picking, open
var lock: Lockpick = null
var seed_value: int = 1


func _process(delta: float) -> void:
	if state == "picking" and lock:
		lock.tick(delta)


## Picks an item from LOOT_TABLE using a 0..1 roll.
static func roll_loot(roll: float) -> String:
	var acc := 0.0
	for e in LOOT_TABLE:
		acc += float(e[1])
		if roll <= acc:
			return e[0]
	return LOOT_TABLE[0][0]


func get_prompt(game: GameState) -> String:
	match state:
		"locked":
			return "[E] Pick the lock (the drawer looks smug)"
		"picking":
			var bar := ""
			for i in 20:
				var p := float(i) / 19.0
				if lock.in_zone() and absf(p - lock.cursor()) < 0.03:
					bar += "#"
				elif absf(p - lock.cursor()) < 0.03:
					bar += "|"
				elif absf(p - lock.zone_center) <= lock.zone_width / 2.0:
					bar += "="
				else:
					bar += "-"
			return "[E] on the = zone!  [%s]  pins %d/%d  picks %d" % [bar, lock.pins_set, Lockpick.PINS, lock.picks_left]
	return "Empty. Only dust and regret."


func interact(game: GameState) -> void:
	match state:
		"locked":
			if not game.can_carry():
				game.say("Your pockets are full. Loot is heavy. So is guilt.")
				return
			lock = Lockpick.new(difficulty, seed_value + game.day)
			state = "picking"
			game.say("Steady hands... press E in the zone.")
			game.hint_event.emit("pick")
		"picking":
			var r := lock.press()
			match r:
				"pin":
					game.say("Click!")
				"snap":
					game.say("SNAP. Pins reset. Picks left: %d" % lock.picks_left)
				"broken":
					game.say("Out of picks. The drawer wins today.")
					state = "locked"
				"open":
					_open(game)


func _open(game: GameState) -> void:
	state = "open"
	if game.add_loot(loot_id):
		game.say("Got: %s!" % game.item_name(loot_id))
	else:
		game.say("Too heavy to carry. You leave it. Crime is hard.")
		state = "locked"


func on_new_day(game: GameState) -> void:
	if state == "open":
		state = "locked"
		loot_id = roll_loot(game.day * 0.6180339 - floorf(game.day * 0.6180339))


func _enter_tree() -> void:
	super._enter_tree()
	add_to_group("daily")
	add_to_group("lootbox")
