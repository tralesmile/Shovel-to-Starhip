class_name FishingSpot
extends Interactable
## A jetty spot at the pond. E casts, E again when the bobber dunks.

var fishing: Fishing = null
var next_seed: int = 1


func _process(delta: float) -> void:
	if fishing and fishing.state in ["waiting", "bite"]:
		fishing.tick(delta)


func get_prompt(_game: GameState) -> String:
	if fishing == null or fishing.state == "idle":
		return "[E] Cast a line"
	match fishing.state:
		"waiting":
			return "Waiting... (E to give up)"
		"bite":
			return "[E] NOW!! Something is nibbling!"
		"done":
			return "[E] Reel in (it seems to have left)"
	return ""


func interact(game: GameState) -> void:
	if fishing == null or fishing.state == "idle":
		next_seed += 7
		fishing = Fishing.new(next_seed + game.day * 13 + int(Time.get_ticks_msec()))
		fishing.cast()
		game.say("Plop. Now we wait. Fish are famously punctual.")
		return
	match fishing.reel():
		"early":
			game.say("Too eager. The fish saw you coming.")
		"late":
			game.say("Too slow. The fish took the bait AND your dignity.")
		"caught":
			var id := Fishing.roll_fish(fishing.rng.randf())
			game.add_item(id)
			game.say("Caught: %s!" % game.item_name(id))
			if id == "golden_carp":
				game.say("Caught: Golden Carp! It looks smug and valuable.")
