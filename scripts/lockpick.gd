class_name Lockpick
extends RefCounted
## Pure timing lockpick logic (no scene state, unit testable).
## A cursor sweeps 0..1 back and forth; press while it is inside the sweet zone
## to set a pin. Set all pins to open the lock. Misses snap a pick (3 picks).

const PINS := 3
const PICKS := 3

var speed: float = 1.1          ## sweeps per second
var zone_center: float = 0.5
var zone_width: float = 0.2
var phase: float = 0.0          ## raw time accumulator
var pins_set: int = 0
var picks_left: int = PICKS
var rng := RandomNumberGenerator.new()


func _init(difficulty: float = 0.0, seed_value: int = 1) -> void:
	rng.seed = seed_value
	speed = 1.1 + 0.4 * difficulty
	zone_width = clampf(0.22 - 0.06 * difficulty, 0.08, 0.3)
	_new_zone()


func _new_zone() -> void:
	zone_center = rng.randf_range(zone_width, 1.0 - zone_width)


func tick(delta: float) -> void:
	phase += delta * speed


## Cursor 0..1 as a triangle wave.
func cursor() -> float:
	return 1.0 - absf(fposmod(phase, 2.0) - 1.0)


func in_zone() -> bool:
	return absf(cursor() - zone_center) <= zone_width / 2.0


func is_open() -> bool:
	return pins_set >= PINS


func is_broken() -> bool:
	return picks_left <= 0


## Player presses the button. Returns "pin", "open", "snap" or "broken".
func press() -> String:
	if is_open():
		return "open"
	if is_broken():
		return "broken"
	if in_zone():
		pins_set += 1
		if is_open():
			return "open"
		_new_zone()
		return "pin"
	picks_left -= 1
	pins_set = 0
	_new_zone()
	return "broken" if is_broken() else "snap"
