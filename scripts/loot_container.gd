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
var dresser: DresserModel = null   ## set by main; null in headless logic tests
var _was_in_zone := false


func _process(delta: float) -> void:
	if state == "picking" and lock:
		lock.tick(delta)
		var inside := lock.in_zone()
		if inside and not _was_in_zone:
			Sfx.play_on(self, "drip", 0.7 + 0.15 * lock.pins_set)   # an audible "now!"
		_was_in_zone = inside
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl != null and pl.global_position.distance_to(global_position) > Stealth.ABANDON_DIST:
			abandon()


## Walking off drops the lock (otherwise the "crime" would carry on without you).
func abandon() -> void:
	if state == "picking":
		state = "locked"
		lock = null


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
			return "[E] Push the pin when the pick is in the gold"
	return "Empty. Only dust and regret."


func interact(game: GameState) -> void:
	match state:
		"locked":
			if not game.can_carry():
				game.say("Your pockets are full. Loot is heavy. So is guilt.")
				return
			lock = Lockpick.new(difficulty, seed_value + game.day, game.count("velvet_picks") > 0)
			_was_in_zone = false
			state = "picking"
			game.say("Steady hands... press E in the zone.")
			game.hint_event.emit("pick")
		"picking":
			var r := lock.press()
			match r:
				"pin":
					game.say("Click!")
					Sfx.play_on(self, "clang", 0.8 + 0.22 * lock.pins_set)
					game.shake.emit(0.08)
					if dresser:
						dresser.jiggle(0.5)
				"snap":
					game.say("SNAP. Pins reset. Picks left: %d" % lock.picks_left)
					_snap_feedback(game)
				"broken":
					game.say("Out of picks. The drawer wins today.")
					state = "locked"
					_snap_feedback(game)
				"open":
					_open(game)


func _snap_feedback(game: GameState) -> void:
	Sfx.play_on(self, "crunch", 1.9)
	game.shake.emit(0.22)
	if dresser:
		dresser.jiggle(1.0)
		FX.burst(self, global_position + Vector3(0, 0.8, 0.32), Color(0.85, 0.87, 0.95), 6, 0.05, 2.0, -9.0, "box")


func _open(game: GameState) -> void:
	state = "open"
	if game.add_loot(loot_id):
		game.say("Got: %s!" % game.item_name(loot_id))
		Sfx.play_on(self, "fanfare", 1.5)
		game.shake.emit(0.18)
		if dresser:
			dresser.open_with(loot_id)
	else:
		game.say("Too heavy to carry. You leave it. Crime is hard.")
		state = "locked"


func on_new_day(game: GameState) -> void:
	if state == "open":
		state = "locked"
		if dresser:
			dresser.close()
		loot_id = roll_loot(game.day * 0.6180339 - floorf(game.day * 0.6180339))


func _enter_tree() -> void:
	super._enter_tree()
	add_to_group("daily")
	add_to_group("lootbox")
