class_name Tutorial
extends Node
## First-run hints. Pure state machine (advance) plus a thin node that feeds it game signals.
## Each step waits for an event, then the next hint is shown through Game.say.

const STEPS := [
	{"wait": "start", "tip": "Tip: WASD to walk, Shift to sprint. The turnips will not plant themselves."},
	{"wait": "move", "tip": "Press 1-4 to switch tools. Hoe a patch, then plant seeds with [2]."},
	{"wait": "tool", "tip": "Water your crops and wait a night. Sleeping in your bed skips to the next day."},
	{"wait": "money", "tip": "Cha-ching! Sell goods at the bin, buy seeds at the store. Wallet goes up, shame goes down."},
	{"wait": "day", "tip": "New day! Press H any time for help, F5 to save, Esc to pause."},
]

var index := 0
var done := false


## Feed an event name; returns the hint to show, or "" if nothing changes.
func advance(event: String) -> String:
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
	_event("start")


func _event(e: String) -> void:
	var tip := advance(e)
	if tip != "":
		get_node("/root/Game").say(tip)


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
