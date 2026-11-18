class_name Witness
extends RefCounted
## Pure witness logic (no scene state, unit testable). Each watcher has a
## suspicion meter 0..1 that fills while the crime is in their view cone
## (faster when close) and drains when out of sight. Full meter = alarm.

const RANGE := 9.0
const FOV_DEG := 120.0
const FILL_PER_SEC := 0.9       ## at point blank
const DRAIN_PER_SEC := 0.35
const CROUCH_FILL_MULT := 0.5   ## crouching halves how fast watchers get suspicious

var suspicion: float = 0.0


## True when `target` is inside the cone of a watcher at `pos` facing `facing_y`
## (rotation.y; forward = +Z as the Npc script uses atan2(x, z)).
static func can_see(pos: Vector3, facing_y: float, target: Vector3, view_range: float = RANGE, fov_deg: float = FOV_DEG) -> bool:
	var to := target - pos
	to.y = 0.0
	var d := to.length()
	if d > view_range:
		return false
	if d < 0.5:
		return true
	var fwd := Vector3(sin(facing_y), 0.0, cos(facing_y))
	var ang := rad_to_deg(acos(clampf(fwd.dot(to / d), -1.0, 1.0)))
	return ang <= fov_deg * 0.5


## Advance the meter. Returns true on the tick it reaches full (alarm), then resets.
func update(delta: float, seen: bool, distance: float = 0.0, crouched: bool = false) -> bool:
	if seen:
		var close := clampf(1.0 - distance / RANGE, 0.15, 1.0)
		suspicion += FILL_PER_SEC * close * (CROUCH_FILL_MULT if crouched else 1.0) * delta
	else:
		suspicion -= DRAIN_PER_SEC * delta
	suspicion = clampf(suspicion, 0.0, 1.0)
	if suspicion >= 1.0:
		suspicion = 0.0
		return true
	return false
