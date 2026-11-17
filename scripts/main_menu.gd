class_name MainMenu
extends CanvasLayer
## Title screen shown at boot: Continue (if a save exists), New Game, Quit.
## The tree is paused while it is open. New Game wipes the save and reloads the scene.

const FONT := preload("res://assets/fonts/lilita_one_regular.ttf")

## Set by New Game so the reloaded scene skips the title screen once.
static var skip_next := false

## Demo feedback link (opens in the player's browser).
const FEEDBACK_URL := "https://github.com/tralesmile/Shovel-to-Starhip/issues"

signal closed
signal new_game_requested

var has_save := false
var _panel: Control
var _first: Button


## Pure helper: button labels for a given save state (used by tests).
static func options(save_exists: bool) -> Array:
	var o: Array = []
	if save_exists:
		o.append("Continue")
	o.append("New Game")
	o.append("Send Feedback")
	o.append("Quit")
	return o


## True once if the title screen should be skipped (consumes the flag).
static func consume_skip() -> bool:
	var s := skip_next
	skip_next = false
	return s


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 28
	_panel.theme = theme
	add_child(_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.14, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(420, 0)
	center.add_child(box)
	var title := Label.new()
	title.text = "Shovel to Starship"
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Dig turnips. Reach the stars. Mind the constable."
	sub.add_theme_font_size_override("font_size", 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	for label in options(has_save):
		var b := Button.new()
		b.text = label
		b.pressed.connect(_on_pressed.bind(label))
		box.add_child(b)
		if _first == null:
			_first = b
	_first.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _on_pressed(label: String) -> void:
	match label:
		"Continue":
			close()
		"New Game":
			new_game_requested.emit()
			skip_next = true
			get_tree().paused = false
			get_tree().reload_current_scene()
		"Send Feedback":
			OS.shell_open(FEEDBACK_URL)
		"Quit":
			get_tree().quit()


func close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()
