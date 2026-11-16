class_name Hud
extends CanvasLayer
## Money, clock, hotbar, inventory, interaction prompt, toasts and help panel.

var player: Player

var _money: Label
var _clock: Label
var _inv: Label
var _prompt: Label
var _heat: Label
var _toast_box: VBoxContainer
var _slots: Array[PanelContainer] = []
var _help: PanelContainer
var _click_hint: Label


const FONT := preload("res://assets/fonts/lilita_one_regular.ttf")

var _icons: Array[Texture2D] = []


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = FONT
	root.theme = theme
	add_child(root)
	_build_icons()

	_money = _label(root, 30)
	_place(_money, 0, 0, 0, 0, 24, 14, 424, 54)
	_clock = _label(root, 26)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_clock, 1, 0, 1, 0, -424, 16, -24, 56)
	_inv = _label(root, 20)
	_place(_inv, 0, 0, 0, 0, 24, 58, 1024, 88)

	_heat = _label(root, 22)
	_heat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_heat, 1, 0, 1, 0, -524, 58, -24, 88)
	_prompt = _label(root, 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_prompt, 0.5, 1, 0.5, 1, -600, -156, 600, -116)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bar)
	_place(bar, 0.5, 1, 0.5, 1, -400, -100, 400, -24)
	for i in GameState.TOOL_NAMES.size():
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(170, 68)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var key := Label.new()
		key.text = str(i + 1)
		key.add_theme_font_size_override("font_size", 16)
		key.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		row.add_child(key)
		var icon := TextureRect.new()
		icon.texture = _icons[i]
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var l := Label.new()
		l.text = GameState.TOOL_NAMES[i].replace(" ", "\n")
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 17)
		row.add_child(l)
		p.add_child(row)
		bar.add_child(p)
		_slots.append(p)

	_toast_box = VBoxContainer.new()
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)
	_place(_toast_box, 0.5, 0, 0.5, 0, -450, 80, 450, 280)

	_click_hint = _label(root, 24)
	_click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_hint.text = "Click to play  ·  Esc frees the mouse"
	_place(_click_hint, 0.5, 0.5, 0.5, 0.5, -400, 60, 400, 100)

	_help = PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.08, 0.08, 0.12, 0.72)
	hsb.set_corner_radius_all(10)
	hsb.set_content_margin_all(14)
	_help.add_theme_stylebox_override("panel", hsb)
	var help_text := Label.new()
	help_text.add_theme_font_size_override("font_size", 16)
	help_text.text = """SHOVEL TO STARSHIP  —  prototype 0.3

WASD  walk      Shift  run      Space  jump
Mouse  look     Wheel  zoom
1-4  pick tool  E / Left click  use it

Goal: till, plant, water, sleep, harvest, sell.
Seeds at the General Store. Sell at the red bin.
Sleep in the bed (inside your house) to skip the night.
Chop trees with the Axe for wood.

Pet the chickens and the goat. They like it.

F5 save (also saves every morning and on quit)
G  graphics: %s  (switching restarts the game)
H  hide / show this help""" % Graphics.label()
	_help.add_child(help_text)
	root.add_child(_help)
	_place(_help, 0, 0, 0, 0, 24, 100, 444, 400)

	Game.money_changed.connect(func(_v): _refresh())
	Game.inventory_changed.connect(_refresh)
	Game.tool_changed.connect(func(_i): _refresh())
	Game.day_changed.connect(func(_d): _refresh())
	Game.toast.connect(_on_toast)
	_refresh()


## Renders each tool's 3D model into a small texture for the hotbar.
func _build_icons() -> void:
	var models := [
		_hoe_model(),
		Models.put(Node3D.new(), Models.MED + "sack.gltf", Vector3.ZERO, 1.0),
		Models.put(Node3D.new(), Models.MED + "bucket_water.gltf", Vector3.ZERO, 1.0),
		Models.put(Node3D.new(), Models.CHAR + "axe_1handed.gltf", Vector3.ZERO, 1.0),
	]
	for m in models:
		var root3d: Node3D = m.get_parent() if m.get_parent() else m
		var vp := SubViewport.new()
		vp.size = Vector2i(128, 128)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		vp.add_child(root3d)
		var box := Models.local_aabb(root3d, root3d)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = max(box.size.x, max(box.size.y, box.size.z)) * 1.35
		var c := box.get_center()
		vp.add_child(cam)
		cam.position = c + Vector3(1.6, 1.2, 2.0).normalized() * 10.0
		cam.look_at(c)
		var l := DirectionalLight3D.new()
		l.rotation = Vector3(-0.9, 0.7, 0)
		vp.add_child(l)
		var we := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.8, 0.8, 0.85)
		e.ambient_light_energy = 0.6
		we.environment = e
		vp.add_child(we)
		_icons.append(vp.get_texture())


func _hoe_model() -> Node3D:
	var hoe := Node3D.new()
	var handle := Art.cylinder(0.035, 0.035, 1.3, Art.WOOD, 6)
	handle.position.y = 0.35
	handle.rotation.z = 0.5
	hoe.add_child(handle)
	var blade := Art.box(Vector3(0.08, 0.1, 0.32), Color(0.65, 0.66, 0.7))
	blade.position = Vector3(-0.29, 0.9, 0.14)
	blade.rotation.z = 0.5
	hoe.add_child(blade)
	return hoe


## Anchors (0..1) + pixel offsets, set explicitly so layout never depends on order.
func _place(c: Control, al: float, at: float, ar: float, ab: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func _label(parent: Control, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func set_help_visible(v: bool) -> void:
	_help.visible = v


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		_help.visible = not _help.visible
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		Game.say("Switching graphics... see you in a second!")
		Graphics.toggle.call_deferred()
	elif event.is_action_pressed("save"):
		Game.save_game()
		Game.say("Game saved. Your turnips are safe.")


func _process(_delta: float) -> void:
	_clock.text = "Day %d   %s" % [Game.day, Game.clock_text()]
	if Game.crime_suspicion > 0.02:
		_heat.text = "Someone is watching... [%s%s]" % ["#".repeat(int(Game.crime_suspicion * 10)), "-".repeat(10 - int(Game.crime_suspicion * 10))]
	elif Game.heat_level() > 0:
		_heat.text = "Heat: %s" % Game.heat_name()
	else:
		_heat.text = ""
	_click_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if player and player.target:
		_prompt.text = player.target.get_prompt(Game)
	else:
		_prompt.text = ""


func _refresh() -> void:
	_money.text = "$%d" % Game.money
	var parts: Array[String] = []
	for id in Game.inventory.keys():
		parts.append("%s ×%d" % [Game.item_name(id), Game.count(id)])
	_inv.text = "  ·  ".join(parts) if parts.size() > 0 else "Pockets: empty (and a bit of lint)"
	for i in _slots.size():
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		if i == Game.current_tool:
			sb.bg_color = Color(1.0, 0.75, 0.25, 0.9)
			sb.set_border_width_all(3)
			sb.border_color = Color.WHITE
		else:
			sb.bg_color = Color(0.1, 0.1, 0.15, 0.7)
		_slots[i].add_theme_stylebox_override("panel", sb)


func _on_toast(text: String) -> void:
	var l := _label(_toast_box, 24)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(900, 34)
	while _toast_box.get_child_count() > 4:
		_toast_box.get_child(0).free()
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
