class_name Police
extends Node3D
## Constable Bumble. Patrols the town while heat is at max (level 3), chases the
## player on sight, and arrests on touch. Hiding indoors (any interior) makes him
## lose interest. State logic is static/pure so it is unit testable.

signal spotted

enum State { OFF, PATROL, CHASE, SEARCH }

const SIGHT_RANGE := 14.0
const SIGHT_FOV := 140.0
const CROUCH_SIGHT_MULT := 0.5  ## crouching halves how far he can spot you
const NIGHT_SIGHT_MULT := 0.5  ## darkness halves it again


## Effective sight range for a player who may be crouching.
static func sight_range(crouched: bool, tod: float = 0.5) -> float:
	return SIGHT_RANGE * (CROUCH_SIGHT_MULT if crouched else 1.0) * (NIGHT_SIGHT_MULT if is_night(tod) else 1.0)


## Night = before 6:00 or from 20:00 (time_of_day is 0..1 of a day).
static func is_night(tod: float) -> bool:
	return tod < 0.25 or tod >= 0.8333
const CATCH_DIST := 1.3
const PATROL_SPEED := 2.6
const CHASE_SPEED := 6.4      ## slower than sprinting (8.5), faster than walking (5.0)
const LOSE_DIST := 24.0
const SEARCH_TIME := 12.0  ## seconds he pokes around where he last saw you
const SEARCH_SPEED := 3.6
const SEARCH_RADIUS := 4.5  ## after checking the last spot he sweeps a ring this wide
const SEARCH_POINTS := 4

## Point `i` of the sweep around where the player was last seen (i=0 is the spot itself).
static func search_point(center: Vector3, i: int) -> Vector3:
	if i <= 0:
		return center
	var a := float(i - 1) / float(SEARCH_POINTS) * TAU
	return center + Vector3(cos(a), 0.0, sin(a)) * SEARCH_RADIUS
var search_i: int = 0

var search_t: float = 0.0
var last_seen := Vector3.ZERO

var state: int = State.OFF
var waypoints: Array[Vector3] = []
var _wp: int = 0
var _anim: AnimationPlayer


## Pure state machine. `sees` = player in view cone; `hidden` = player indoors.
static func next_state(current: int, heat: float, sees: bool, hidden: bool, dist: float) -> int:
	if heat < GameState.MAX_HEAT - 0.001:
		return State.OFF
	if hidden:
		return State.PATROL
	match current:
		State.OFF:
			return State.PATROL
		State.PATROL:
			return State.CHASE if sees else State.PATROL
		State.CHASE:
			return State.PATROL if dist > LOSE_DIST else State.CHASE
	return State.PATROL


static func is_hidden(player_pos: Vector3) -> bool:
	return player_pos.x > Buildings.INTERIOR_ORIGIN.x - 50.0


func setup() -> void:
	var m := Models.put(self, Models.CHAR + "Knight.glb", Vector3.ZERO, 0.72, 0.0)
	var found := m.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_anim = found[0]
		Models.set_loops(_anim, ["Idle", "Walking_A"])
		_anim.play("Idle")
	visible = false


## Returns true on the tick the player is arrested.
## True when this constable has the player in his view cone (used for outdoor heat cooling).
func sees_player(player_pos: Vector3, crouched: bool = false, tod: float = 0.5) -> bool:
	if is_hidden(player_pos):
		return false
	return Witness.can_see(global_position, rotation.y, player_pos, sight_range(crouched, tod), SIGHT_FOV)


func update_police(delta: float, player_pos: Vector3, heat: float, crouched: bool = false, tod: float = 0.5) -> bool:
	var hidden := is_hidden(player_pos)
	var to := player_pos - global_position
	to.y = 0.0
	var sees := Witness.can_see(global_position, rotation.y, player_pos, sight_range(crouched, tod), SIGHT_FOV) and not hidden
	var prev := state
	state = next_state(State.PATROL if state == State.SEARCH else state, heat, sees, hidden, to.length())
	if prev == State.SEARCH and state == State.PATROL:
		state = State.SEARCH if search_t > 0.0 else State.PATROL
	if prev == State.CHASE and state == State.PATROL:
		state = State.SEARCH  # lost you: go check the last spot before resuming the beat
		search_t = SEARCH_TIME
		search_i = 0
		last_seen = player_pos
	if state == State.OFF:
		visible = false
		return false
	if prev == State.OFF:
		global_position = waypoints[0] if not waypoints.is_empty() else global_position
		_wp = 0
		visible = true
	if state == State.CHASE:
		if prev != State.CHASE:
			spotted.emit()
		_move(to, CHASE_SPEED * delta)
		if to.length() <= CATCH_DIST:
			state = State.PATROL
			search_t = 0.0
			return true
	elif state == State.SEARCH:
		search_t -= delta
		var s := search_point(last_seen, search_i) - global_position
		s.y = 0.0
		if s.length() > 1.0:
			_move(s, SEARCH_SPEED * delta)
		elif search_i < SEARCH_POINTS:
			search_i += 1  # next spot on the sweep
		else:
			rotation.y += delta * 2.0  # look around
		if search_t <= 0.0:
			state = State.PATROL
	else:
		if waypoints.is_empty():
			return false
		var g := waypoints[_wp] - global_position
		g.y = 0.0
		if g.length() < 0.6:
			_wp = (_wp + 1) % waypoints.size()
		_move(g, PATROL_SPEED * delta)
	return false


func _move(dir: Vector3, step: float) -> void:
	dir.y = 0.0
	if dir.length() > 0.05:
		global_position += dir.normalized() * minf(step, dir.length())
		rotation.y = atan2(dir.x, dir.z)
		if _anim and _anim.has_animation("Walking_A") and _anim.current_animation != "Walking_A":
			_anim.play("Walking_A")
