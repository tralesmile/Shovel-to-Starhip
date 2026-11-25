class_name Tutorial
extends Node
## First-run hints. Pure state machine (advance) plus a thin node that feeds it game signals.
## Each step waits for an event, then the next hint is shown through Game.say.

const STEPS := [
	{"wait": "start", "tip": "Tip: WASD or the left stick to walk, {sprint} to sprint. The turnips will not plant themselves."},
	{"wait": "move", "tip": "Switch tools with {tool_1}-{tool_7}. Hoe a patch, then plant seeds with {tool_2}."},
	{"wait": "tool", "tip": "Water your crops and wait a night. Sleeping in your bed skips to the next day."},
	{"wait": "money", "tip": "Cha-ching! Sell goods at the bin, buy seeds at the store. Wallet goes up, shame goes down."},
	{"wait": "day", "tip": "New day! Press {help} any time for help, {save} to save, {pause} to pause."},
]

## One-time context hints, shown the first time the player does something new.
const ONCE := {
	"pick": "Lockpicking: press {interact} when the marker is in the zone. Miss and the pick snaps; get seen and Constable Bumble hears about it.",
	"cast": "Fishing: wait for the bite, then press {interact} fast. Not too early, not too late. Fish judge.",
	"heat": "Heat! Someone saw you. Duck indoors or crouch ({crouch}) out of sight, or Constable Bumble will take your loot and a slice of your cash.",
	"fence": "Fencing: Shady Sal pays half price for stolen goods, a bit more the more Outlaw you are. No receipts.",
	"arrest": "Busted. Loot confiscated, wallet lighter, heat down to 1. Lawful or not, the constable is very proud.",
	"drive": "Driving: WASD or the left stick steers, Space is the handbrake, {interact} hops out. Pedestrians are not bonus points.",
}

## Global switch (settings menu). When false no hints are shown.
static var enabled := true

var index := 0
var done := false
var seen := {}


## Returns the one-time hint for a context event the first time only, else "".
func once(event: String) -> String:
	if not enabled:
		return ""
	if seen.has(event) or not ONCE.has(event):
		return ""
	seen[event] = true
	return ONCE[event]


## Feed an event name; returns the hint to show, or "" if nothing changes.
func advance(event: String) -> String:
	if not enabled:
		return ""
	if done or index >= STEPS.size():
		return ""
	if STEPS[index]["wait"] != event:
		return ""
	var tip: String = STEPS[index]["tip"]
	index += 1
	if index >= STEPS.size():
		done = true
	return tip


func _ready() -> void:
	var g: Node = get_node("/root/Game")
	g.tool_changed.connect(func(_i): _event("tool"))
	g.money_changed.connect(func(_v): _event("money"))
	g.day_changed.connect(func(_d): _event("day"))
	g.hint_event.connect(func(e): _once_event(e))
	_event("start")


func _once_event(e: String) -> void:
	var tip := once(e)
	if tip != "":
		get_node("/root/Game").say(InputPrompts.format(tip, InputPrompts.use_pad))


func _event(e: String) -> void:
	var tip := advance(e)
	if tip != "":
		get_node("/root/Game").say(InputPrompts.format(tip, InputPrompts.use_pad))


func _physics_process(_d: float) -> void:
	if done:
		set_physics_process(false)
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back") \
			or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		_event("move")
