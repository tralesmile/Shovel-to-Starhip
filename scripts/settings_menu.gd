class_name SettingsMenu
extends CanvasLayer
## Pause/settings overlay (ESC): Master/Music/SFX sliders backed by AudioSettings.
## Volumes are applied live and saved to user://audio.json.

const FONT := preload("res://assets/fonts/lilita_one_regular.ttf")

var settings := AudioSettings.new()
var _panel: PanelContainer
var _sliders := {}


## Loads saved volumes and creates the buses. Safe to call before the UI exists.
func load_and_apply() -> void:
	settings.load_file()
	settings.apply()


## Slider percent (0..100) -> stored volume, and back. Pure helpers for tests.
static func percent_to_volume(p: float) -> float:
	return clampf(p / 100.0, 0.0, 1.0)


static func volume_to_percent(v: float) -> float:
	return roundf(clampf(v, 0.0, 1.0) * 100.0)


func _ready() -> void:
	layer = 20
	load_and_apply()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 24
	root.theme = theme
	add_child(root)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.position = Vector2(-260, -170)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.14, 0.92)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Paused (the turnips wait for no one)"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	for b in AudioSettings.BUSES:
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = b
		lab.custom_minimum_size = Vector2(120, 0)
		row.add_child(lab)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 5
		s.value = volume_to_percent(settings.volumes[b])
		s.custom_minimum_size = Vector2(320, 30)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.value_changed.connect(_on_slider.bind(b))
		row.add_child(s)
		box.add_child(row)
		_sliders[b] = s
	var resume := Button.new()
	resume.text = "Resume  (Esc)"
	resume.pressed.connect(close)
	box.add_child(resume)
	_panel.visible = false


func _on_slider(v: float, bus: String) -> void:
	settings.set_volume(bus, percent_to_volume(v))
	settings.apply()
	settings.save()


func is_open() -> bool:
	return _panel != null and _panel.visible


func open() -> void:
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
