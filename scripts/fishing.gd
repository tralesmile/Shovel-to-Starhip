class_name Fishing
extends RefCounted
## Pure fishing logic: the cast (hold to throw further), the wait for a bite, the short
## window to set the hook, plus catch tables and fish sizes. The fight lives in FishFight.

const FISH_TABLE := [
	["boot", 0.12], ["minnow", 0.35], ["carp", 0.28], ["trout", 0.15], ["golden_carp", 0.07], ["old_wizard_hat", 0.03],
]
const BITE_WINDOW := 1.0
const CHARGE_TIME := 1.1        ## seconds of holding for a full-power cast
const CAST_MIN := 3.0
const CAST_MAX := 10.0
const CAST_ROD_BONUS := 3.0
## species -> [shortest cm, longest cm]
const SIZES := {
	"boot": [26, 34], "minnow": [5, 12], "carp": [28, 62], "trout": [24, 55],
	"golden_carp": [35, 80], "old_wizard_hat": [30, 48],
}
const JUNK := ["boot", "old_wizard_hat"]

var state: String = "idle"     ## idle, waiting, bite, done
var timer: float = 0.0
var bite_time: float = 3.0
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


func cast() -> void:
	state = "waiting"
	timer = 0.0
	bite_time = rng.randf_range(2.0, 6.0)


## A fish in the pond has decided to take the bait.
func bite() -> void:
	if state == "waiting":
		state = "bite"
		timer = 0.0


func tick(delta: float) -> void:
	timer += delta
	if state == "waiting" and timer >= bite_time:
		bite()
	elif state == "bite" and timer >= BITE_WINDOW:
		state = "done"   # too slow


## Player presses reel. Returns "early", "hooked", "late" or "" if not fishing.
func reel() -> String:
	match state:
		"waiting":
			state = "idle"
			return "early"
		"bite":
			state = "idle"
			return "hooked"
		"done":
			state = "idle"
			return "late"
	return ""


static func roll_fish(roll: float) -> String:
	var acc := 0.0
	for e in FISH_TABLE:
		acc += float(e[1])
		if roll <= acc:
			return e[0]
	return FISH_TABLE[1][0]


## Cast power 0..1 after holding for `held` seconds.
static func cast_power(held: float) -> float:
	return clampf(held / CHARGE_TIME, 0.0, 1.0)


static func cast_distance(power: float, has_rod: bool) -> float:
	return lerpf(CAST_MIN, CAST_MAX + (CAST_ROD_BONUS if has_rod else 0.0), clampf(power, 0.0, 1.0))


## Size in cm for a species given a roll 0..1 (big ones are rarer).
static func size_for(species: String, roll: float) -> int:
	var r: Array = SIZES.get(species, [10, 20])
	var k := pow(clampf(roll, 0.0, 1.0), 1.8)
	return int(round(lerpf(float(r[0]), float(r[1]), k)))


## Records a catch in `log` ({species: {n, best}}). Returns "new" (first ever), "best" or "".
static func log_catch(book: Dictionary, species: String, cm: int) -> String:
	if not book.has(species):
		book[species] = {"n": 1, "best": cm}
		return "new"
	var e: Dictionary = book[species]
	e["n"] = int(e["n"]) + 1
	if cm > int(e["best"]):
		e["best"] = cm
		return "best"
	return ""


static func total_catches(book: Dictionary) -> int:
	var n := 0
	for k in book:
		n += int(book[k].get("n", 0))
	return n
