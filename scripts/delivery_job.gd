class_name DeliveryJob
extends RefCounted
## Pure logic for the parcel delivery job: pick a drop-off, race a timer, get paid
## (faster = bigger tip). Needs no scene, so it is easy to test.

## [name, x, z] drop-off points around the world.
const DESTINATIONS := [
	["the Scarecrow Appreciation Society", -10.0, 16.0],
	["Dame Gertrude's front step", 30.0, -8.0],
	["a very suspicious lamp post", -30.0, 22.0],
	["the pond (parcel is waterproof, allegedly)", -14.0, -6.0],
]
const BASE_PAY := 40
const PAY_PER_METRE := 1.2
const TIME_PER_METRE := 0.45     ## seconds allowed per metre (generous but not lazy)
const MIN_TIME := 25.0
const DROP_RADIUS := 3.5

var active: bool = false
var dest_index: int = 0
var time_total: float = 0.0
var time_left: float = 0.0
var start_pos := Vector2.ZERO


func start(index: int, from: Vector2) -> void:
	dest_index = clampi(index, 0, DESTINATIONS.size() - 1)
	start_pos = from
	var d := distance()
	time_total = maxf(MIN_TIME, d * TIME_PER_METRE)
	time_left = time_total
	active = true


func dest_name() -> String:
	return DESTINATIONS[dest_index][0]


func dest_pos() -> Vector2:
	return Vector2(DESTINATIONS[dest_index][1], DESTINATIONS[dest_index][2])


func distance() -> float:
	return start_pos.distance_to(dest_pos())


## Returns true when the clock just ran out.
func tick(delta: float) -> bool:
	if not active:
		return false
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		active = false
		return true
	return false


func is_near(pos: Vector2) -> bool:
	return active and pos.distance_to(dest_pos()) <= DROP_RADIUS


## Payment if delivered right now: base + distance, tip up to +50% for speed.
func payout() -> int:
	var base := BASE_PAY + distance() * PAY_PER_METRE
	var frac := 0.0 if time_total <= 0.0 else time_left / time_total
	return int(round(base * (1.0 + 0.5 * frac)))


## Completes the job. Returns the pay (0 if no job running).
func complete() -> int:
	if not active:
		return 0
	var pay := payout()
	active = false
	return pay


const COMPASS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]  ## world +x = E, +z = S


## Compass direction (8-way) from a position to the drop-off.
func compass_from(pos: Vector2) -> String:
	var d := dest_pos() - pos
	var ang := fposmod(atan2(d.y, d.x), TAU)
	return COMPASS[int(round(ang / (TAU / 8.0))) % 8]


## One-line HUD text: timer, distance, heading, current tip.
func hud_line(pos: Vector2) -> String:
	if not active:
		return ""
	return "PARCEL: %s  %ds  %dm %s  (+$%d)" % [dest_name(), int(ceil(time_left)), int(pos.distance_to(dest_pos())), compass_from(pos), payout()]
