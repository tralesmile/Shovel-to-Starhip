class_name InputPrompts
extends Node
## Tracks the last used input device and turns {action} tokens in text into key or pad labels.

const KEY_LABELS := {
	"interact": "E", "jump": "Space", "sprint": "Shift", "help": "H", "save": "F5", "pause": "Esc",
	"tool_1": "1", "tool_2": "2", "tool_3": "3", "tool_4": "4", "interact_click": "Click",
	"move": "WASD", "look": "Mouse", "tools": "1-4", "use": "E / Left click",
}
const PAD_LABELS := {
	"interact": "X", "jump": "A", "sprint": "L3", "help": "Y", "save": "F5", "pause": "Start",
	"tool_1": "D-pad Up", "tool_2": "D-pad Right", "tool_3": "D-pad Down", "tool_4": "D-pad Left",
	"interact_click": "RB",
	"move": "Left stick", "look": "Right stick", "tools": "D-pad", "use": "X / RB",
}

const HELP_TEMPLATE := """SHOVEL TO STARSHIP  —  prototype 0.3

{move}  walk      {sprint}  run      {jump}  jump
{look}  look     Wheel  zoom
{tools}  pick tool  {use}  use it

Goal: till, plant, water, sleep, harvest, sell.
Seeds at the General Store. Sell at the red bin.
Sleep in the bed (inside your house) to skip the night.
Chop trees with the Axe for wood.

Pet the chickens and the goat. They like it.

{save} save (also saves every morning and on quit)
G  graphics: %s  (switching restarts the game)
{help}  hide / show this help"""

static var use_pad := false


static func label(action: String, pad: bool) -> String:
	var table: Dictionary = PAD_LABELS if pad else KEY_LABELS
	return table.get(action, action)


## Replace every {action} token with the label for the chosen device.
static func format(text: String, pad: bool) -> String:
	var out := text
	for action in KEY_LABELS:
		out = out.replace("{%s}" % action, label(action, pad))
	return out


## Swap a leading "[E]" interact tag for the device's interact label (pad: "[X]").
static func prompt_text(text: String, pad: bool) -> String:
	if text.begins_with("[E] "):
		return "[%s] %s" % [label("interact", pad), text.substr(4)]
	return text


## Decide device from an event; returns the new use_pad value (unchanged for other events).
static func device_for_event(event: InputEvent, current: bool) -> bool:
	if event is InputEventJoypadButton:
		return true
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > 0.5 or current
	if event is InputEventKey or event is InputEventMouseButton:
		return false
	return current


func _input(event: InputEvent) -> void:
	use_pad = device_for_event(event, use_pad)
