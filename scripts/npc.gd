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


## Sleeping neighbours see nothing (snoring is not a witness statement).
func can_witness() -> bool:
	return activity != Buildings.Schedule.Activity.SLEEP


func _play(anim: String) -> void:
	if _anim and _anim.has_animation(anim) and _anim.current_animation != anim:
		_anim.play(anim)


const BARKS_LAWFUL := ["Ah, our favourite upstanding turnip enthusiast!", "Morning! Your halo is looking freshly polished.", "If everyone were like you, I could retire my door lock."]
const BARKS_NEUTRAL := ["Lovely weather for minding my own business.", "Hello there. Nothing suspicious here. Or there.", "Nice shovel. Very... shovel-y."]
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
