class_name Fishing
extends RefCounted
## Pure fishing logic: cast, wait for a random bite, then react inside a short
## window to hook the fish. Too early or too late = it got away.

const FISH_TABLE := [
	["boot", 0.12], ["minnow", 0.35], ["carp", 0.28], ["trout", 0.15], ["golden_carp", 0.07], ["old_wizard_hat", 0.03],
]
const BITE_WINDOW := 1.0

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


func tick(delta: float) -> void:
	timer += delta
	if state == "waiting" and timer >= bite_time:
		state = "bite"
		timer = 0.0
	elif state == "bite" and timer >= BITE_WINDOW:
		state = "done"   # too slow


## Player presses reel. Returns "early", "caught", "late" or "" if not fishing.
func reel() -> String:
	match state:
		"waiting":
			state = "idle"
			return "early"
		"bite":
			state = "idle"
			return "caught"
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
