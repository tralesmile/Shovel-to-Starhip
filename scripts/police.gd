class_name Police
extends Node3D
## Constable Bumble. Patrols the town while heat is at max (level 3), chases the
## player on sight, and arrests on touch. Hiding indoors (any interior) makes him
## lose interest. State logic is static/pure so it is unit testable.

signal spotted

enum State { OFF, PATROL, CHASE }

const SIGHT_RANGE := 14.0
const SIGHT_FOV := 140.0
const CATCH_DIST := 1.3
const PATROL_SPEED := 2.6
const CHASE_SPEED := 6.4      ## slower than sprinting (8.5), faster than walking (5.0)
const LOSE_DIST := 24.0

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
func sees_player(player_pos: Vector3) -> bool:
	if is_hidden(player_pos):
		return false
	return Witness.can_see(global_position, rotation.y, player_pos, SIGHT_RANGE, SIGHT_FOV)


func update_police(delta: float, player_pos: Vector3, heat: float) -> bool:
	var hidden := is_hidden(player_pos)
	var to := player_pos - global_position
	to.y = 0.0
	var sees := Witness.can_see(global_position, rotation.y, player_pos, SIGHT_RANGE, SIGHT_FOV) and not hidden
	var prev := state
	state = next_state(state, heat, sees, hidden, to.length())
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
			return true
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
