class_name InputPrompts
extends Node
## Tracks the last used input device and turns {action} tokens in text into key or pad labels.

const KEY_LABELS := {
	"interact": "E", "jump": "Space", "sprint": "Shift", "crouch": "C", "help": "H", "save": "F5", "pause": "Esc",
	"tool_1": "1", "tool_2": "2", "tool_3": "3", "tool_4": "4", "tool_5": "5", "tool_6": "6", "tool_7": "7", "build_cycle": "F", "interact_click": "Click", "craft_next": "Q", "drop_item": "G", "throw_bomb": "B", "throw_decoy": "V", "whistle": "R",
	"move": "WASD", "look": "Mouse", "tools": "1-6", "use": "E / Left click",
}
const PAD_LABELS := {
	"interact": "X", "jump": "A", "sprint": "L3", "crouch": "B", "help": "Y", "save": "F5", "pause": "Start",
	"tool_1": "D-pad Up", "tool_2": "D-pad Right", "tool_3": "D-pad Down", "tool_4": "D-pad Left", "tool_5": "LB", "tool_6": "R3", "tool_7": "L3 click", "build_cycle": "L3",
	"interact_click": "RB", "craft_next": "Back", "drop_item": "Paddle", "throw_bomb": "RT", "throw_decoy": "LT", "whistle": "Paddle 2",
	"move": "Left stick", "look": "Right stick", "tools": "D-pad", "use": "X / RB",
}

const HELP_TEMPLATE := """SHOVEL TO STARSHIP  —  prototype 0.3

{move}  walk      {sprint}  run      {crouch}  sneak      {jump}  jump
{look}  look     Wheel  zoom
{tools}  pick tool  {use}  use it

Goal: till, plant, water, sleep, harvest, sell.
Seeds at the General Store. Sell at the red bin.
Sleep in the bed (inside your house) to skip the night.
Chop trees with the Axe for wood. Craft fence panels, then [6] Builder to place them.
Gran's Old Mine is north-west of the farm. {throw_bomb}  throw a Boom Turnip.

Cut tall grass with the Hoe (craft a Scythe!) for hay. Crouch in it to hide.
Felled trees leave a trunk: buck it with the Axe. Catch meadow critters (craft a Bug Net!).
Feed veg to chickens or the goat to befriend them, then pet daily.
Friendly hens can be carried (hold {jump} to float) and thrown.
Riding: {interact_click} headbutts. {whistle} blows the Goat Whistle.
Heists: sneak to see sight cones. {throw_decoy} throws a Squeaky Chicken.

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
