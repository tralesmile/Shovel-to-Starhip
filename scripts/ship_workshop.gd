class_name ShipWorkshop
extends CanvasLayer
## The workshop panel: flip through nose, fins, engine and paint with the real ship changing
## in front of you, pay for new parts once, then LAUNCH. Mouse, keys and pad all work.

const FONT := preload("res://assets/fonts/lilita_one_regular.ttf")

signal closed
signal launch_requested

var rocket: GranRocket
var game: GameState
var preview_design: Dictionary
var _rows: Dictionary = {}     ## slot -> name Label
var _info: Label
var _stats: Label
var _unlock: Button
var _launch: Button
var _last_slot := "nose"


## Why the launch button is greyed out ("" = good to go).
static func launch_block(story_done: bool, design: Dictionary, unlocked: Array) -> String:
	if not story_done:
		return "Finish Gran's story first"
	for slot in StarshipDesign.SLOTS:
		if not StarshipDesign.is_unlocked(slot, design[slot], unlocked):
			return "Unlock or swap the %s" % StarshipDesign.SLOT_NAMES[slot].to_lower()
	return ""


func _ready() -> void:
	layer = 12
	if game == null:
		game = get_node_or_null("/root/Game") as GameState
	preview_design = game.ship_design.duplicate()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 22
	root.theme = theme
	add_child(root)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.9)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.8, 0.35, 0.8)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -610
	panel.offset_right = -40
	panel.offset_top = -330
	panel.offset_bottom = 330
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "STARSHIP WORKSHOP"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var first: Button = null
	for slot in StarshipDesign.SLOTS:
		var row := HBoxContainer.new()
		var head := Label.new()
		head.text = StarshipDesign.SLOT_NAMES[slot]
		head.custom_minimum_size = Vector2(96, 0)
		row.add_child(head)
		var prev := Button.new()
		prev.text = " < "
		prev.pressed.connect(flip.bind(slot, -1))
		row.add_child(prev)
		var mid := Label.new()
		mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(mid)
		_rows[slot] = mid
		var next := Button.new()
		next.text = " > "
		next.pressed.connect(flip.bind(slot, 1))
		row.add_child(next)
		if first == null:
			first = next
		box.add_child(row)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(0, 78)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 19)
	box.add_child(_info)
	_unlock = Button.new()
	_unlock.pressed.connect(unlock_current)
	box.add_child(_unlock)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 20)
	box.add_child(_stats)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_launch = Button.new()
	_launch.add_theme_font_size_override("font_size", 32)
	_launch.pressed.connect(func(): launch_requested.emit())
	box.add_child(_launch)
	var done := Button.new()
	done.text = "Back to the farm  (Esc)"
	done.pressed.connect(func(): closed.emit())
	box.add_child(done)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	first.grab_focus()
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()


func flip(slot: String, dir: int) -> void:
	_last_slot = slot
	preview_design[slot] = StarshipDesign.cycle(slot, preview_design[slot], dir)
	_commit(slot)
	Sfx.play_on(self, "clang", 1.5 + 0.1 * StarshipDesign.index_of(slot, preview_design[slot]))
	if rocket != null:
		rocket.preview(preview_design, true)
	_refresh()


## Owned parts are fitted straight away; locked ones are only a preview until paid for.
func _commit(slot: String) -> void:
	if StarshipDesign.is_unlocked(slot, preview_design[slot], game.ship_unlocked):
		game.ship_design[slot] = preview_design[slot]


func unlock_current() -> void:
	var slot := _last_slot
	if not StarshipDesign.unlock(slot, preview_design[slot], game):
		return
	_commit(slot)
	Sfx.play_on(self, "fanfare", 1.2)
	if rocket != null:
		rocket.preview(preview_design, true)
		FX.burst(rocket, rocket.global_position + Vector3(0, 3.5, 0), Color(1.0, 0.85, 0.3), 40, 0.14, 6.0, -6.0, "sphere", 180.0, true)
	_refresh()


func _refresh() -> void:
	for slot in StarshipDesign.SLOTS:
		var id: String = preview_design[slot]
		var owned := StarshipDesign.is_unlocked(slot, id, game.ship_unlocked)
		_rows[slot].text = "%s%s" % [StarshipDesign.option(slot, id)["name"], "" if owned else "  (locked)"]
		_rows[slot].modulate = Color.WHITE if owned else Color(1.0, 0.75, 0.5)
	var cur: String = preview_design[_last_slot]
	var opt := StarshipDesign.option(_last_slot, cur)
	var locked := not StarshipDesign.is_unlocked(_last_slot, cur, game.ship_unlocked)
	var text: String = opt.get("line", "A fresh coat. Adds at least 3 mph.")
	if locked:
		text += "\nNeeds: " + StarshipDesign.cost_text(_last_slot, cur, game)
	_info.text = text
	_unlock.visible = locked
	var miss := StarshipDesign.missing(_last_slot, cur, game) if locked else ""
	_unlock.disabled = miss != ""
	_unlock.text = "Build this part" if miss == "" else "Still need " + miss
	var s := StarshipDesign.stats(preview_design)
	var lines: PackedStringArray = []
	for k in StarshipDesign.STAT_NAMES:
		lines.append("%s   %s  %d%%" % [StarshipDesign.STAT_NAMES[k].rpad(9), StarshipDesign.bar(s[k]), int(round(s[k] * 100.0))])
	_stats.text = "\n".join(lines)
	var block := launch_block(Story.is_finished(game.story_act), preview_design, game.ship_unlocked)
	_launch.disabled = block != ""
	_launch.text = "LAUNCH TO THE MOON" if block == "" else block
	if block != "":
		_launch.add_theme_font_size_override("font_size", 22)
	else:
		_launch.add_theme_font_size_override("font_size", 32)
