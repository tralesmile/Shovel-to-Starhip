class_name Npc
extends Node3D
## Townsperson with a daily routine: sleeps/wakes/relaxes in their home interior,
## and works at a spot outdoors during the day. Follows Game.time_of_day.

var home_spot: Vector3          ## global position inside the home interior
var work_spot: Vector3          ## global position outdoors
var door_outside: Vector3       ## global position just outside the home door
var wake_shift: float = 0.0     ## hours; lets NPCs have different habits
var activity: int = -1
var npc_name: String = "Townsperson"
var witness := Witness.new()
var indoors: bool = true
var speed: float = 2.0
var _anim: AnimationPlayer

# Heist awareness: where the valuables are, what they hear and what shows over their head.
const TURN_SPEED := 4.5
const ALARM_SHOW := 2.5
var guard_spot := Vector3.INF    ## their drawer; INF = nothing to guard
var room := Rect2()              ## XZ bounds of their home interior (clips the sight cone)
var gaze_seed: int = 0
var _gaze_t := 0.0
var _distract_t := 0.0
var _distract_at := Vector3.ZERO
var _alarm_t := 0.0
var _startle := 0.0
var _base_y := 0.0
var marker: Label3D = null
var cone: VisionCone = null


func is_asleep() -> bool:
	return activity == Buildings.Schedule.Activity.SLEEP


func is_distracted() -> bool:
	return _distract_t > 0.0


func gaze_mood() -> int:
	if not indoors or guard_spot == Vector3.INF or is_asleep() or is_distracted():
		return Stealth.Mood.CALM
	return Stealth.gaze_mood(_gaze_t, gaze_seed)


## A squeaky chicken (or similar) went off nearby: stare at it. Sleepers sleep on.
func hear_noise(at: Vector3) -> bool:
	if not Stealth.hears(global_position, at, is_asleep()):
		return false
	if _distract_t <= 0.0:
		_startle = 1.0
	_distract_t = 1.6   # refreshed by every squeak
	_distract_at = at
	return true


func raise_alarm() -> void:
	_alarm_t = ALARM_SHOW
	_startle = 1.0


## Heads turn: toward a noise first, otherwise the look-about routine indoors.
func update_awareness(delta: float) -> void:
	_alarm_t = maxf(0.0, _alarm_t - delta)
	_distract_t = maxf(0.0, _distract_t - delta)
	_startle = maxf(0.0, _startle - delta * 3.0)
	if is_asleep():
		return
	if _distract_t > 0.0:
		rotation.y = Stealth.turn_toward(rotation.y, Stealth.yaw_to(global_position, _distract_at), TURN_SPEED * delta)
	elif indoors and guard_spot != Vector3.INF:
		_gaze_t += delta
		var want := Stealth.gaze_yaw(_gaze_t, gaze_seed, Stealth.yaw_to(global_position, guard_spot))
		rotation.y = Stealth.turn_toward(rotation.y, want, TURN_SPEED * delta)


## Head marker and floor sight cone. `sneaking` = the player is crouched or picking nearby.
func show_awareness(delta: float, sneaking: bool, player_pos: Vector3) -> void:
	if marker == null:
		marker = Art.label("", 72, Color.WHITE)
		marker.no_depth_test = true
		marker.top_level = true
		marker.pixel_size = 0.007
		add_child(marker)
		cone = VisionCone.new()
		add_child(cone)
	var near := global_position.distance_to(player_pos) < 12.0
	var mood := gaze_mood()
	var text := Stealth.marker(witness.suspicion, _alarm_t > 0.0, is_distracted(), is_asleep(), mood)
	# The idle tells only matter while you are up to something.
	if not sneaking and _alarm_t <= 0.0 and not is_distracted() and not is_asleep():
		text = ""
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var in_face := cam != null and cam.global_position.distance_to(global_position + Vector3(0, 2.15, 0)) < 2.8
	marker.visible = near and text != "" and not in_face
	marker.text = text
	marker.modulate = Color(1.0, 0.25, 0.2) if _alarm_t > 0.0 else (Color(1.0, 0.9, 0.3) if is_distracted() else Stealth.cone_color(witness.suspicion, mood))
	var hop := sin(_startle * PI) * 0.25
	marker.global_position = global_position + Vector3(0, 2.15 + hop * 1.6, 0)
	marker.scale = Vector3.ONE * (1.0 + 0.5 * _startle + 0.35 * witness.suspicion)
	var tint := Color(1.0, 0.15, 0.1) if _alarm_t > 0.0 else Stealth.cone_color(witness.suspicion, mood)
	cone.refresh(delta, near and sneaking and can_witness(), global_position, rotation.y, room if indoors else Rect2(), tint, witness.suspicion)


func _enter_tree() -> void:
	add_to_group("npc")


func setup(model_path: String) -> void:
	var m := Models.put(self, model_path, Vector3.ZERO, 0.72, 0.0)
	var found := m.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_anim = found[0]
		Models.set_loops(_anim, ["Idle", "Walking_A"])
		_anim.play("Idle")
	for n in ["Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff"]:
		var node := m.find_child(n, true, false)
		if node:
			node.visible = false


## Follow the routine. Leaving home: appear at the door, walk to work. Going home:
## walk to the door, then vanish inside (interiors are far-away rooms).
func update_routine(time_of_day: float, delta: float) -> void:
	var act := Buildings.Schedule.activity_at(time_of_day, wake_shift)
	var want_in := Buildings.Schedule.is_indoors(act)
	activity = act
	if indoors and not want_in:
		indoors = false
		global_position = door_outside
	var goal := work_spot
	if want_in:
		goal = home_spot if indoors else door_outside
	if indoors:
		global_position = home_spot
		_play("Idle")
		update_awareness(delta)
		return
	var to := goal - global_position
	to.y = 0.0
	if to.length() > 0.2:
		global_position += to.normalized() * min(speed * delta, to.length())
		rotation.y = atan2(to.x, to.z)
		_play("Walking_A")
	else:
		_play("Idle")
		if want_in:
			indoors = true
			global_position = home_spot
	update_awareness(delta)


## Sleeping neighbours see nothing (snoring is not a witness statement).
func can_witness() -> bool:
	return activity != Buildings.Schedule.Activity.SLEEP


func _play(anim: String) -> void:
	if _anim and _anim.has_animation(anim) and _anim.current_animation != anim:
		_anim.play(anim)


const BARKS_LAWFUL := ["Ah, our favourite upstanding turnip enthusiast!", "Morning! Your halo is looking freshly polished.", "If everyone were like you, I could retire my door lock."]
const BARKS_NEUTRAL := ["Lovely weather for minding my own business.", "Hello there. Nothing suspicious here. Or there.", "Nice shovel. Very... shovel-y."]
## Notorious tier (reputation <= -7): townsfolk are openly terrified or oddly impressed.
const BARKS_NOTORIOUS := ["Please, take the spoons, just leave the kettle!", "Is it true you stole a lighthouse? Asking for a very nervous friend.", "I've put 'Do Not Rob' on my fridge. It's a start.", "Autograph? No? Please don't rob me."]
const BARKS_OUTLAW := ["I'm watching my spoons. All of them.", "Oh no, it's *you*. Hide the good cutlery!", "Nice night for a stroll. Please stay out of my drawers."]


const BARKS_LOOT := ["Is that a gnome in your pocket, or are you just happy to see me?", "That bulge in your coat is clinking. Suspiciously.", "Lovely loot... I mean, lovely day!"]


const BARKS_NIGHT := ["Shouldn't you be in bed? I should. Yet here we both are.", "The moon's out. So are my suspicions.", "Night shift on the gossip beat. Care to contribute?"]


## Per-NPC personality lines, used every other bark so each townsperson feels distinct.
const BARKS_PERSONAL := {
	"Pip": ["Did you know turnips have feelings? Mine told me.", "I'm not short, I'm aerodynamic!"],
	"Dame Gertrude": ["In my day we stole turnips uphill both ways.", "Back, citizen! ...Oh, it's you. Carry on."],
	"Bork": ["Bork. That is all. That is the bark.", "I sniffed a mystery today. It was soup."],
}


## Name-specific line; empty for unknown names. Wraps idx.
static func personal_bark(npc_name: String, idx: int) -> String:
	if not BARKS_PERSONAL.has(npc_name):
		return ""
	var pool: Array = BARKS_PERSONAL[npc_name]
	return pool[posmod(idx, pool.size())]


## Reputation-flavoured greeting; idx wraps so callers can rotate lines.
## Carrying stolen goods overrides the reputation pool (everyone notices the clinking).
const NOTORIOUS_REP := -7.0


static func bark(reputation: float, idx: int, carrying_loot: bool = false, npc_name: String = "", night: bool = false) -> String:
	if carrying_loot:
		return BARKS_LOOT[posmod(idx, BARKS_LOOT.size())]
	if night and idx % 4 == 2:
		return BARKS_NIGHT[posmod(idx / 4, BARKS_NIGHT.size())]
	if idx % 2 == 1:
		var own := personal_bark(npc_name, idx / 2)
		if own != "":
			return own
	var pool: Array = BARKS_NEUTRAL
	if reputation >= 3.0:
		pool = BARKS_LAWFUL
	elif reputation <= NOTORIOUS_REP:
		pool = BARKS_NOTORIOUS
	elif reputation <= -3.0:
		pool = BARKS_OUTLAW
	return pool[posmod(idx, pool.size())]


## Like bark(), but skips ahead so the same line never plays twice in a row.
## Returns {"idx": index actually used, "line": text}.
static func fresh_bark(reputation: float, idx: int, last_line: String, carrying_loot: bool = false, npc_name: String = "", night: bool = false) -> Dictionary:
	var line := bark(reputation, idx, carrying_loot, npc_name, night)
	var tries := 0
	while line == last_line and tries < 8:
		idx += 1
		tries += 1
		line = bark(reputation, idx, carrying_loot, npc_name, night)
	return {"idx": idx, "line": line}


## Pure cooldown: returns {"timer", "fire"}; fires when near and the timer has run out.
static func bark_tick(timer: float, delta: float, near: bool, cooldown: float = 25.0) -> Dictionary:
	var t := maxf(0.0, timer - delta)
	if near and t <= 0.0:
		return {"timer": cooldown, "fire": true}
	return {"timer": t, "fire": false}
