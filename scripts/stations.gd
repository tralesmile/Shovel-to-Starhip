class_name Station
extends Interactable
## Simple fixed-function stations: shop counter, sell bin, bed, rocket tease.

enum Kind { SHOP, SELL_BIN, BED, ROCKET, FENCE }

@export var kind: int = Kind.SHOP

const SEED_PACK := 5     ## seeds bought per press
const ROCKET_PRICE := 1000000


func get_prompt(game: GameState) -> String:
	match kind:
		Kind.SHOP:
			var price: int = GameState.ITEMS["turnip_seed"]["buy"] * SEED_PACK
			return "[E] Buy %d turnip seeds ($%d)" % [SEED_PACK, price]
		Kind.SELL_BIN:
			var value := 0
			for id in game.inventory.keys():
				value += int(GameState.ITEMS.get(id, {}).get("sell", 0)) * game.count(id)
			return "[E] Sell everything ($%d)" % value if value > 0 else "Sell bin. Bring turnips or wood."
		Kind.BED:
			return "[E] Sleep until morning"
		Kind.FENCE:
			var offer := game.fence_offer()
			return "[E] Sell stolen goods ($%d)  [%s]" % [offer, game.reputation_title()] if offer > 0 else "Shady Sal: \"Got anything... acquired?\""
		Kind.ROCKET:
			return "Rocket: $%s to finish. You have $%d. Keep farming." % [_pretty(ROCKET_PRICE), game.money]
	return ""


func interact(game: GameState) -> void:
	match kind:
		Kind.SHOP:
			if game.buy("turnip_seed", SEED_PACK):
				FX.burst(self, global_position + Vector3(0, 1.0, 0), Color(0.9, 0.8, 0.45), 8, 0.1, 2.5)
				game.say("Bought %d seeds. The shopkeeper winks. Weird." % SEED_PACK)
			else:
				game.say("Not enough money. Try selling turnips first.")
		Kind.SELL_BIN:
			var earned := game.sell_all()
			if earned > 0:
				game.say("Ka-ching! +$%d" % earned)
				FX.burst(self, global_position + Vector3(0, 1.2, 0), Color(1.0, 0.82, 0.2), 20, 0.16, 5.0, -9.0, "sphere", 35.0)
			else:
				game.say("The sell bin echoes. It's empty, like your pockets.")
		Kind.BED:
			game.sleep()
		Kind.FENCE:
			var paid := game.fence_sell_all()
			if paid > 0:
				game.say("Shady Sal: \"Never seen it before in my life.\" +$%d  (%s)" % [paid, game.reputation_title()])
				FX.burst(self, global_position + Vector3(0, 1.2, 0), Color(0.6, 0.9, 0.5), 14, 0.14, 4.0)
			else:
				game.say("Shady Sal: \"Come back when your pockets are interesting.\"")
		Kind.ROCKET:
			game.say("One day, little rocket. One day.")


static func _pretty(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
