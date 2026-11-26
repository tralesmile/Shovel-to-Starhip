class_name Stealth
extends RefCounted
## Pure stealth rules for the heist system (no scene state, unit tested):
## where a resident is looking, how far their sight reaches inside a room, what
## their head marker shows, and who can hear a squeaky decoy.

const GAZE_PERIOD := 9.0      ## seconds for one full look-about cycle
const GAZE_TELL := 1.1        ## seconds of "hm?" warning before the head turns to the valuables
const GAZE_WATCH := 2.4       ## seconds spent staring at the valuables
const HEAR_RANGE := 9.0
const DISTRACT_TIME := 6.0
const ABANDON_DIST := 2.4     ## walk this far from a lock and you give up on it

enum Mood { CALM, TELL, WATCHING }


## Phase of the look-about cycle: CALM (looking away), TELL (about to turn) or WATCHING.
static func gaze_mood(t: float, seed_value: int) -> int:
	var p := fposmod(t + float(seed_value % 7) * 1.3, GAZE_PERIOD)
	var calm := GAZE_PERIOD - GAZE_TELL - GAZE_WATCH
	if p < calm:
		return Mood.CALM
	if p < calm + GAZE_TELL:
		return Mood.TELL
	return Mood.WATCHING


## Yaw (rotation.y) a resident wants to face. `guard_yaw` points at their valuables.
## While calm they potter between two spots that both leave the valuables out of view.
static func gaze_yaw(t: float, seed_value: int, guard_yaw: float) -> float:
	if gaze_mood(t, seed_value) == Mood.WATCHING:
		return guard_yaw
	var cycle := int(floor((t + float(seed_value % 7) * 1.3) / GAZE_PERIOD))
	var side := 1.0 if (cycle + seed_value) % 2 == 0 else -1.0
	return wrapf(guard_yaw + side * deg_to_rad(125.0), -PI, PI)


static func yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


## Turns `cur` toward `want` by at most `step` radians, the short way round.
static func turn_toward(cur: float, want: float, step: float) -> float:
	var diff := wrapf(want - cur, -PI, PI)
	return wrapf(cur + clampf(diff, -step, step), -PI, PI)


## Distance along `dir` (flat, unit) from `origin` to the walls of a room given as a
## Rect2 in XZ. Capped at `max_dist`. Used to stop vision cones poking through walls.
static func sight_length(origin: Vector2, dir: Vector2, room: Rect2, max_dist: float) -> float:
	var best := max_dist
	if dir.x > 0.0001:
		best = minf(best, (room.end.x - origin.x) / dir.x)
	elif dir.x < -0.0001:
		best = minf(best, (room.position.x - origin.x) / dir.x)
	if dir.y > 0.0001:
		best = minf(best, (room.end.y - origin.y) / dir.y)
	elif dir.y < -0.0001:
		best = minf(best, (room.position.y - origin.y) / dir.y)
	return maxf(0.0, best)


## Text over a resident's head. "!" for an alarm, a filling "?" while suspicious.
static func marker(suspicion: float, alarmed: bool, distracted: bool, asleep: bool, mood: int) -> String:
	if alarmed:
		return "!!"
	if suspicion > 0.02:
		return "?" + "|".repeat(clampi(int(ceil(suspicion * 5.0)), 1, 5))
	if distracted:
		return "chicken?!"
	if asleep:
		return "zzz"
	if mood == Mood.TELL:
		return "hm?"
	if mood == Mood.WATCHING:
		return "o_o"
	return ""


## Green (calm) -> amber -> red as suspicion rises.
static func cone_color(suspicion: float, mood: int) -> Color:
	var calm := Color(0.35, 0.95, 0.55) if mood != Mood.TELL else Color(1.0, 0.85, 0.25)
	if suspicion <= 0.0:
		return calm
	if suspicion < 0.5:
		return Color(1.0, 0.85, 0.25).lerp(Color(1.0, 0.55, 0.15), suspicion * 2.0)
	return Color(1.0, 0.55, 0.15).lerp(Color(1.0, 0.15, 0.1), (suspicion - 0.5) * 2.0)


static func hears(listener: Vector3, noise: Vector3, asleep: bool) -> bool:
	return not asleep and listener.distance_to(noise) <= HEAR_RANGE
