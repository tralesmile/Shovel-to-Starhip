class_name Player
extends CharacterBody3D
## Third-person farmer: WASD to walk, Shift to run, Space to jump,
## mouse to look, E / left click to use the selected tool.

const WALK_SPEED := 5.0
const RUN_SPEED := 8.5
const CROUCH_SPEED := 2.6
var crouching: bool = false
var in_cover: bool = false   ## crouched in tall grass: rabbits and the constable struggle to see you
var skidding: bool = false
var _skid_puff := 0.0
var _face_prev := 0.0
var _lean := Vector2.ZERO    ## x = forward pitch, y = roll
const JUMP_VELOCITY := 5.0
const MOUSE_SENS := 0.0035

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var target: Interactable = null

const PAD_LOOK_SPEED := 2.6
var _yaw: float = 0.0
var _pitch: float = -0.45
var _zoom: float = 7.0
var _pivot: Node3D
var _arm: SpringArm3D
var camera: Camera3D
var _model: Node3D
var vehicle: Car = null
var mount: Critter = null
var _hoof_t: float = 0.0
var _shape: CollisionShape3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	add_child(shape)
	_shape = shape
	_build_model()

	_pivot = Node3D.new()
	_pivot.top_level = true
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = _zoom
	_arm.margin = 0.3
	_arm.add_excluded_object(get_rid())
	_pivot.add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 65
	_arm.add_child(camera)
	camera.current = true
	_dust = FX.emitter(self, Color(0.78, 0.7, 0.55), 16, 0.6, 0.14, Vector3(0.15, 0.02, 0.15), Vector3(0, 0.6, 0), false, "sphere")
	_dust.position = Vector3(0, 0.05, 0)
	_dust.emitting = false
	add_to_group("player")
	Game.shake.connect(func(a: float): _trauma = min(1.0, _trauma + a))
	Game.tool_changed.connect(_on_tool_changed)
	Game.inventory_changed.connect(_refresh_hoe_model)
	_on_tool_changed(Game.current_tool)
	_refresh_hoe_model()


const MODEL_SCALE := 0.72
const LOOPS := ["Idle", "Walking_A", "Running_A", "Jump_Idle"]

var _anim: AnimationPlayer
var _hand: Node3D
var _action_time: float = 0.0
var _hand_items: Dictionary = {}
var _dust: CPUParticles3D
var _trauma: float = 0.0
var _coyote: float = 0.0
var _jump_buf: float = 0.0
var stamina: float = FX.STAMINA_MAX
var winded: bool = false
var _was_floor: bool = true
var _last_vy: float = 0.0
var _squash: float = 1.0



func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var body := Models.put(_model, Models.CHAR + "Barbarian.glb", Vector3.ZERO, MODEL_SCALE)
	_anim = body.find_children("*", "AnimationPlayer", true, false)[0]
	Models.set_loops(_anim, LOOPS)
	_anim.play("Idle")
	# Put away the barbarian's weapons; he's a farmer now.
	for n in ["1H_Axe_Offhand", "Barbarian_Round_Shield", "2H_Axe", "Mug"]:
		var node := body.find_child(n, true, false)
		if node:
			node.visible = false
	_hand = body.find_child("handslot_r", true, false)
	_hand_items[GameState.Tool.AXE] = body.find_child("1H_Axe", true, false)
	_hand_items[GameState.Tool.HOE] = _make_hoe()
	_hoe_node = _hand_items[GameState.Tool.HOE]
	_scythe_node = _make_scythe()
	_scythe_node.visible = false
	_hand_items[GameState.Tool.PICKAXE] = _make_pickaxe()
	_hand_items[GameState.Tool.BUILD] = _make_hammer()
	_hand_items[GameState.Tool.SLINGSHOT] = _make_slingshot()
	_hand_items[GameState.Tool.WATER] = Models.put(_hand, Models.MED + "bucket_water.gltf", Vector3(0, -0.05, 0), 3.2)
	_hand_items[GameState.Tool.SEEDS] = Models.put(_hand, Models.MED + "sack.gltf", Vector3(0, 0, 0), 3.0)


var _hoe_node: Node3D
var _scythe_node: Node3D


func _make_scythe() -> Node3D:
	var s := Node3D.new()
	_hand.add_child(s)
	var handle := Art.cylinder(0.035, 0.035, 1.5, Art.WOOD, 6)
	handle.position.y = 0.4
	s.add_child(handle)
	# A curved blade made of three tapering steel segments.
	for k in 3:
		var seg := Art.box(Vector3(0.05, 0.14 - 0.03 * k, 0.3), Color(0.82, 0.86, 0.92))
		seg.position = Vector3(0, 1.14 - 0.07 * k * k, 0.14 + 0.25 * k)
		seg.rotation.x = 0.28 * k
		s.add_child(seg)
	var grip := Art.box(Vector3(0.22, 0.05, 0.05), Art.WOOD.darkened(0.2))
	grip.position = Vector3(0.1, 0.35, 0)
	s.add_child(grip)
	return s


var _net: Node3D


## Whoosh the Bug Net through the air: the net pops into your hand for the swing.
func swing_net() -> void:
	if mount != null or vehicle != null:
		return
	if _net == null:
		_net = _make_net()
	_net.visible = true
	var held: Node3D = _hand_items.get(Game.current_tool)
	if held != null:
		held.visible = false
	play_action("1H_Melee_Attack_Slice_Horizontal", 0.55)
	Sfx.play_on(self, "swish", 1.5)
	_sweep_arc(1.7, 150.0)
	get_tree().create_timer(0.6).timeout.connect(func():
		_net.visible = false
		_on_tool_changed(Game.current_tool))


func _make_net() -> Node3D:
	var n := Node3D.new()
	_hand.add_child(n)
	var handle := Art.cylinder(0.03, 0.03, 1.4, Art.WOOD, 6)
	handle.position.y = 0.45
	n.add_child(handle)
	var hoop := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.28
	tm.outer_radius = 0.34
	tm.rings = 16
	tm.ring_segments = 6
	hoop.mesh = tm
	hoop.material_override = Art.mat(Color(0.82, 0.62, 0.3))
	hoop.rotation.z = PI * 0.5
	hoop.position.y = 1.45
	n.add_child(hoop)
	var bag := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.29
	cone.height = 0.55
	cone.radial_segments = 10
	cone.cap_bottom = false
	bag.mesh = cone
	var bm := StandardMaterial3D.new()
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(1, 1, 1, 0.38)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bag.material_override = bm
	bag.rotation.z = PI * 0.5
	bag.position = Vector3(-0.27, 1.45, 0)
	n.add_child(bag)
	return n


## Owning the Scythe swaps it in for the hoe model (the hoe still tills farm plots).
func _refresh_hoe_model() -> void:
	var scythe := Game.count("scythe") > 0
	var want: Node3D = _scythe_node if scythe else _hoe_node
	if _hand_items.get(GameState.Tool.HOE) == want:
		return
	_hand_items[GameState.Tool.HOE] = want
	_hoe_node.visible = false
	_scythe_node.visible = false
	want.visible = Game.current_tool == GameState.Tool.HOE


func meadow() -> Meadow:
	return get_tree().get_first_node_in_group("meadow") as Meadow


## Hoe swing through wild grass: a short chop, or a full spinning sweep with the Scythe.
func swing_grass() -> int:
	var md := meadow()
	if md == null or Game.current_tool != GameState.Tool.HOE or _action_time > 0.0 or mount != null:
		return 0
	var scythe := Game.count("scythe") > 0
	var sw := Meadow.swing_for(scythe)
	var ids := md.targets(global_position, _model.rotation.y, sw["radius"], sw["arc"])
	if ids.is_empty():
		return 0
	play_action("2H_Melee_Attack_Spin" if scythe else "1H_Melee_Attack_Slice_Horizontal", 0.5)
	Sfx.play_on(self, "swish", 0.85 if scythe else 1.2)
	var n := md.cut(ids, global_position)
	_sweep_arc(float(sw["radius"]), float(sw["arc"]))
	Game.shake.emit(0.08 + minf(n, 30) * 0.004)
	if n >= 8:
		FX.hit_stop(get_tree(), 0.35)
	return n


## A pale crescent that flashes along the cutting edge and fades.
func _sweep_arc(radius: float, arc_deg: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 28
	var half := deg_to_rad(arc_deg * 0.5)
	for i in steps:
		var a0 := -half + 2.0 * half * i / steps
		var a1 := -half + 2.0 * half * (i + 1) / steps
		var quad := []
		for a in [a0, a1]:
			var d := Vector3(sin(a), 0, cos(a))
			var fade := float(i) / steps   # brightest at the leading edge
			quad.append([d * radius * 0.62, Color(1, 1, 0.85, 0.0)])
			quad.append([d * radius, Color(1, 1, 0.85, 0.8 * fade * fade)])   # transparent tail, bright head
		for k in [0, 1, 2, 2, 1, 3]:
			st.set_color(quad[k][1])
			st.add_vertex(quad[k][0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.global_position = global_position + Vector3(0, 0.5, 0)
	mi.rotation.y = _model.rotation.y - 0.9
	mi.scale = Vector3.ONE * 0.7
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.06, 0.2)
	tw.tween_property(mi, "rotation:y", _model.rotation.y + 0.5, 0.2)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.24).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


func _make_pickaxe() -> Node3D:
	var pick := Node3D.new()
	_hand.add_child(pick)
	var handle := Art.cylinder(0.035, 0.035, 1.2, Art.WOOD, 6)
	handle.position.y = 0.3
	pick.add_child(handle)
	var head := Art.box(Vector3(0.07, 0.09, 0.7), Color(0.62, 0.64, 0.7))
	head.position = Vector3(0, 0.9, 0)
	pick.add_child(head)
	return pick


func _make_hammer() -> Node3D:
	var h := Node3D.new()
	_hand.add_child(h)
	var handle := Art.cylinder(0.035, 0.035, 0.9, Art.WOOD, 6)
	handle.position.y = 0.2
	h.add_child(handle)
	var head := Art.box(Vector3(0.12, 0.14, 0.34), Color(0.5, 0.52, 0.58))
	head.position = Vector3(0, 0.68, 0)
	h.add_child(head)
	return h


func _make_slingshot() -> Node3D:
	var s := Node3D.new()
	_hand.add_child(s)
	var grip := Art.box(Vector3(0.07, 0.4, 0.07), Art.WOOD)
	grip.position.y = 0.15
	s.add_child(grip)
	for sx in [-1.0, 1.0]:
		var arm := Art.box(Vector3(0.06, 0.3, 0.06), Art.WOOD)
		arm.position = Vector3(sx * 0.12, 0.42, 0)
		arm.rotation.z = -sx * 0.4
		s.add_child(arm)
	var band := Art.box(Vector3(0.26, 0.022, 0.022), Color(0.85, 0.25, 0.2))
	band.position = Vector3(0, 0.55, 0)
	s.add_child(band)
	return s


func _make_hoe() -> Node3D:
	var hoe := Node3D.new()
	_hand.add_child(hoe)
	var handle := Art.cylinder(0.035, 0.035, 1.3, Art.WOOD, 6)
	handle.position.y = 0.35
	hoe.add_child(handle)
	var blade := Art.box(Vector3(0.08, 0.1, 0.32), Color(0.65, 0.66, 0.7))
	blade.position = Vector3(0, 0.95, 0.14)
	hoe.add_child(blade)
	return hoe


func _on_tool_changed(index: int) -> void:
	for k in _hand_items.keys():
		if _hand_items[k]:
			_hand_items[k].visible = (k == index) and not _rod_out


const ROD_SEGMENTS := 4
const ROD_SEG := 0.42
var _rod: Node3D
var _rod_joints: Array[Node3D] = []
var _rod_end: Node3D
var _rod_out := false
var _rod_pitch := 0.0     ## added to the resting angle: negative = cocked back
var _rod_tween: Tween


## A jointed rod held out in front, so it can visibly wind up, whip and bend.
func _make_rod() -> void:
	_rod = Node3D.new()
	_rod.position = Vector3(-0.28, 0.85, 0.28)
	_model.add_child(_rod)
	var parent: Node3D = _rod
	for i in ROD_SEGMENTS:
		var joint := Node3D.new()
		joint.position.y = 0.0 if i == 0 else ROD_SEG
		parent.add_child(joint)
		var r := 0.032 - 0.006 * i
		var seg := Art.cylinder(r - 0.005, r, ROD_SEG, Art.WOOD.lightened(0.07 * i), 6)
		seg.position.y = ROD_SEG * 0.5
		joint.add_child(seg)
		_rod_joints.append(joint)
		parent = joint
	_rod_end = Node3D.new()
	_rod_end.position.y = ROD_SEG
	parent.add_child(_rod_end)
	var reel := Art.cylinder(0.08, 0.08, 0.07, Color(0.82, 0.62, 0.25), 10)
	reel.position = Vector3(0, 0.18, -0.07)
	reel.rotation.z = PI / 2.0
	_rod_joints[0].add_child(reel)
	rod_bend(0.0)


func set_rod(out: bool) -> void:
	if out and _rod == null:
		_make_rod()
	_rod_out = out
	if _rod != null:
		_rod.visible = out
	if not out:
		_rod_pitch = 0.0
	_on_tool_changed(Game.current_tool)


## bend 0..1 curls the upper joints toward the water.
func rod_bend(bend: float) -> void:
	if not _rod_out and _rod != null:
		return
	if _rod == null:
		return
	for i in _rod_joints.size():
		var base := 0.75 + _rod_pitch if i == 0 else 0.0
		_rod_joints[i].rotation.x = base + bend * 0.17 * i


func rod_windup(power: float) -> void:
	set_rod(true)
	if _rod_tween != null:
		_rod_tween.kill()
	_rod_pitch = -1.7 * power
	rod_bend(0.0)


## The forward whip of a cast.
func rod_cast() -> void:
	set_rod(true)
	if _rod_tween != null:
		_rod_tween.kill()
	_rod_tween = create_tween()
	_rod_tween.tween_method(_set_rod_pitch, _rod_pitch, 0.55, 0.14)
	_rod_tween.tween_method(_set_rod_pitch, 0.55, 0.0, 0.3)
	play_action("Throw", 0.45)
	_squash = 0.88


func _set_rod_pitch(v: float) -> void:
	_rod_pitch = v
	rod_bend(0.0)


func rod_tip() -> Vector3:
	if _rod_end != null and _rod_out:
		return _rod_end.global_position
	return global_position + Vector3(0, 1.6, 0)


func face_point(at: Vector3) -> void:
	var to := at - global_position
	_model.rotation.y = atan2(to.x, to.z)


func play_action(anim_name: String, duration: float) -> void:
	if _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.1)
		_anim.speed_scale = 1.6
		_action_time = duration


func _update_animation(delta: float) -> void:
	if _action_time > 0.0:
		_action_time -= delta
		return
	_anim.speed_scale = 1.0
	var flat := Vector2(velocity.x, velocity.z).length()
	var want := "Idle"
	if mount != null:
		want = "Idle"   # seated; the goat does the leg work
	elif not is_on_floor():
		want = "Jump_Idle"
	elif flat > 6.0:
		want = "Running_A"
	elif flat > 0.3:
		want = "Walking_A"
	if _anim.current_animation != want:
		_anim.play(want, 0.15)


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENS, -1.2, 0.25)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = max(3.0, _zoom - 0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = min(14.0, _zoom + 0.6)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not captured:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
			else:
				_use()
	elif event.is_action_pressed("interact"):
		_use()
	elif event.is_action_pressed("drop_item"):
		drop_item()
	elif event.is_action_pressed("throw_bomb"):
		throw_bomb()
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 7:
		if event.is_action_pressed("tool_%d" % (i + 1)):
			Game.set_tool(i)


## G: toss the heaviest droppable item from your pockets onto the ground as a physics pickup.
## It cannot be re-collected for a couple of seconds, so you can actually leave it (e.g. to dodge the carry limit).
## A falling tree landed on you: shoved sideways, squashed flat, winded for a moment.
func timber_bonk(side: Vector3) -> void:
	var sgn := 1.0 if randf() < 0.5 else -1.0
	velocity += side * 6.0 * sgn + Vector3(0, 3.0, 0)
	_squash = 0.55
	stamina = 0.0
	winded = true
	_trauma = minf(1.0, _trauma + 0.8)
	FX.burst(self, global_position + Vector3(0, 0.3, 0), Color(1.0, 0.9, 0.3), 8, 0.1, 3.5, -4.0, "box")  # cartoon stars


func drop_item() -> bool:
	if vehicle != null:
		return false
	var id := Game.drop_candidate()
	if id == "":
		Game.say("Nothing droppable. Your pockets are suspiciously light.")
		return false
	if not Game.remove_item(id, 1):
		return false
	var p := WoodLog.new()
	p.item_id = id
	if id != "wood" and id != "plank":
		p.chunk_color = WoodLog.drop_color(id)
	p.game = Game
	p.age = -1.6   # long arm delay (ARM_TIME 0.7 + 1.6) so it does not magnet straight back
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 1.1, 0)
	var dir := WoodLog.toss_dir(_model.rotation.y if _model != null else 0.0)
	p.pop(dir)
	Sfx.play_on(p, "thud", 1.45)
	Game.say("Dropped %s" % GameState.ITEMS.get(id, {}).get("name", id))
	return true


var _bomb_cd := 0.0


## B: lob a Boom Turnip along the camera heading. Returns the thrown bomb (null if none).
func throw_bomb() -> BoomTurnip:
	if vehicle != null or Game.in_closet:
		return null
	if not BoomTurnip.can_throw(Game.count("boom_turnip"), _bomb_cd):
		if Game.count("boom_turnip") <= 0:
			Game.say("No Boom Turnips. Workbench: 1 turnip + 2 stone + 1 copper ore.")
		return null
	Game.remove_item("boom_turnip", 1)
	_bomb_cd = BoomTurnip.COOLDOWN
	var v := BoomTurnip.throw_velocity(_yaw, _pitch)
	_model.rotation.y = atan2(v.x, v.z)
	play_action("Throw", 0.4)
	var b := BoomTurnip.new()
	b.game = Game
	get_parent().add_child(b)
	b.global_position = global_position + Vector3(0, 1.5, 0) + Vector3(v.x, 0, v.z).normalized() * 0.6
	b.linear_velocity = v + Vector3(velocity.x, 0, velocity.z) * 0.5
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
	b.add_collision_exception_with(self)
	Sfx.play_on(self, "sizzle", 1.2)
	return b


var _blast_time := 0.0


## Caught in your own blast: launched, eyebrows singed. No damage.
func blast_knock(v: Vector3) -> void:
	if vehicle != null:
		return
	if mount != null:
		dismount()
	velocity = v
	_blast_time = 0.45
	_coyote = 0.0
	if v.length() > 7.0:
		Game.say("You have been rapidly relocated. Eyebrows: singed.")


var _helmet: Node3D
var _helmet_light: OmniLight3D


## The Miner's Helmet sits on the head bone; its lamp switches on in the dark.
func set_helmet(owned: bool, lamp_on: bool) -> void:
	if not owned:
		if _helmet != null:
			_helmet.visible = false
			_helmet_light.visible = false
		return
	if _helmet == null:
		var skel: Skeleton3D = null
		var found := _model.find_children("*", "Skeleton3D", true, false)
		if not found.is_empty():
			skel = found[0]
		var holder: Node3D = _model
		var lift := 1.75
		if skel != null and skel.find_bone("head") >= 0:
			var ba := BoneAttachment3D.new()
			ba.bone_name = "head"
			skel.add_child(ba)
			holder = ba
			lift = 0.92
		_helmet = Node3D.new()
		_helmet.position.y = lift
		holder.add_child(_helmet)
		var dome := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.56
		hm.height = 0.56
		hm.is_hemisphere = true
		hm.radial_segments = 12
		hm.rings = 5
		dome.mesh = hm
		dome.material_override = Art.mat(Color(1.0, 0.78, 0.12))
		_helmet.add_child(dome)
		var brim := Art.cylinder(0.66, 0.66, 0.07, Color(0.95, 0.68, 0.08), 14)
		_helmet.add_child(brim)
		var lamp := Art.box(Vector3(0.22, 0.2, 0.14), Color(1.0, 0.97, 0.75))
		lamp.material_override = Art.mat(Color(1.0, 0.97, 0.75), true)
		lamp.position = Vector3(0, 0.22, 0.54)
		_helmet.add_child(lamp)
		_helmet_light = OmniLight3D.new()
		_helmet_light.light_color = Color(1.0, 0.93, 0.75)
		_helmet_light.light_energy = 2.0
		_helmet_light.omni_range = 9.0
		add_child(_helmet_light)
	_helmet.visible = true
	_helmet_light.visible = lamp_on
	var ahead := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	_helmet_light.position = Vector3(0, 2.4, 0) + ahead * 1.6


## Show/hide the character model (hidden while in a wardrobe or driving).
func set_model_shown(shown: bool) -> void:
	if _model != null:
		_model.visible = shown


func enter_car(car: Car) -> void:
	if vehicle != null:
		return
	vehicle = car
	if not car.bumped.is_connected(_on_car_bump):
		car.bumped.connect(_on_car_bump)
		car.bumped_prop.connect(func(): Game.shake.emit(0.14))
		car.smoke_started.connect(func(stage: int): Game.say("Your car is making soup noises." if stage == 1 else "Black smoke! The car would like a Repair Kit."))
	car.driven = true
	_shape.set_deferred("disabled", true)
	_model.visible = false
	skidding = false
	in_cover = false
	velocity = Vector3.ZERO
	_yaw = car.heading + PI
	Game.say("Vroom. Hold Space while steering to drift; let go for a turbo.")
	Game.hint_event.emit("drive")


## Climb onto a saddled, tamed goat (Critter.interact). Returns false if something blocks it.
func mount_critter(c: Critter) -> bool:
	if mount != null or vehicle != null or not Critter.can_mount(c.kind, c.tamed, Game.inventory):
		return false
	mount = c
	c.set_ridden(true)
	global_position = c.global_position
	_model.position.y = Critter.MOUNT_SEAT_Y
	_model.rotation.y = c.rotation.y
	_zoom = maxf(_zoom, 8.0)
	FX.burst(self, global_position + Vector3(0, 0.3, 0), Color(0.85, 0.8, 0.6), 12, 0.14, 2.2, -1.0, "sphere", 120.0)
	Sfx.play_on(self, "happy", 0.8)
	Game.shake.emit(0.15)
	Game.say("Giddy-up! Shift to gallop, Space to jump, E to hop off.")
	return true


func dismount() -> void:
	if mount == null:
		return
	mount.set_ridden(false)
	mount.home = mount.position
	mount = null
	_model.position.y = 0.0
	FX.burst(self, global_position + Vector3(0, 0.1, 0), Color(0.78, 0.7, 0.55), 8, 0.12, 1.8, -1.0, "sphere", 90.0)
	Game.say("You slide off. The goat looks smug.")


func _on_car_bump() -> void:
	var hit := vehicle.last_impact if vehicle != null else 6.0
	Game.shake.emit(clampf(hit * 0.04, 0.12, 0.6))


func exit_car() -> void:
	if vehicle == null:
		return
	var car := vehicle
	vehicle = null
	car.driven = false
	car.halt()
	global_position = car.exit_position()
	_shape.set_deferred("disabled", false)
	_model.visible = true
	Game.car_pos = [car.global_position.x, car.global_position.y, car.global_position.z, car.heading]


func _use() -> void:
	if vehicle != null:
		exit_car()
		return
	if mount != null:
		dismount()
		return
	var fs := get_tree().get_first_node_in_group("fishing_spot") as FishingSpot
	if fs != null and fs.is_busy():
		fs.interact(Game)   # the rod has your hands: never swallow the hook-set, never swing a tool
		return
	if Game.current_tool == GameState.Tool.BUILD:
		var bw := get_tree().get_first_node_in_group("buildworld") as BuildWorld
		if bw != null and _action_time <= 0.0:
			var a := bw.use(self)
			if a != "":
				play_action(a, 0.45)
		return
	if Game.current_tool == GameState.Tool.SLINGSHOT:
		if _sling_charge < 0.0 and Pebble.can_fire(Game.count("slingshot"), Game.count("stone"), _sling_cd):
			_sling_charge = 0.0   # start drawing; release fires
		else:
			_fire_slingshot(0.0)
		return
	if target == null and _action_time <= 0.0 and _smash_tool():
		var cr := _crate_ahead()
		if cr != null:
			var tc := cr.global_position - global_position
			_model.rotation.y = atan2(tc.x, tc.z)
			play_action("1H_Melee_Attack_Chop", 0.55)
			cr.game = Game
			if cr.smash_hit():
				Game.shake.emit(0.3)
			else:
				Game.shake.emit(0.12)
			return
	if target == null and _action_time <= 0.0:
		var rb := _rabbit_ahead()
		if rb != null:
			var tr := rb.global_position - global_position
			_model.rotation.y = atan2(tr.x, tr.z)
			play_action("1H_Melee_Attack_Chop", 0.5)
			rb.bonk(Game)
			Game.shake.emit(0.2)
			FX.hit_stop(get_tree(), 0.5)
			return
	if target == null and Game.current_tool == GameState.Tool.AXE and _action_time <= 0.0:
		var lg := _log_ahead()
		if lg != null:
			var tl := lg.global_position - global_position
			_model.rotation.y = atan2(tl.x, tl.z)
			play_action("1H_Melee_Attack_Chop", 0.55)
			lg.chop_into_planks()
			Game.shake.emit(0.1)
			FX.hit_stop(get_tree(), 0.4)
		return
	if target == null and swing_grass() > 0:
		return
	if target == null or _action_time > 0.0:
		return
	var anim := "Interact"
	if ((target is ChoppableTree or target is FelledTrunk) and Game.current_tool == GameState.Tool.AXE) or (target is MineRock and Game.current_tool == GameState.Tool.PICKAXE):
		anim = "1H_Melee_Attack_Chop"
	elif target is FarmPlot:
		if (target as FarmPlot).is_ripe():
			anim = "PickUp"
		elif Game.current_tool == GameState.Tool.HOE:
			anim = "1H_Melee_Attack_Chop"
		elif Game.current_tool == GameState.Tool.WATER:
			anim = "Use_Item"
	elif target is Station and (target as Station).kind == Station.Kind.SELL_BIN:
		anim = "Cheer"
	# Face what we're using.
	var to := target.global_position - global_position
	_model.rotation.y = atan2(to.x, to.z)
	play_action(anim, 0.55)
	target.interact(Game)


var _sling_cd := 0.0
var _sling_charge := -1.0   ## <0 = not drawing; else seconds held


## Slingshot: costs 1 stone, lobs a Pebble along the camera heading; missed stones can be picked up again.
func _fire_slingshot(held: float = 0.0) -> void:
	if not Pebble.can_fire(Game.count("slingshot"), Game.count("stone"), _sling_cd):
		if Game.count("stone") <= 0:
			Game.say("Out of pebbles! Mine some stone.")
		return
	Game.remove_item("stone", 1)
	_sling_cd = Pebble.COOLDOWN
	var power := Pebble.charge_power(held)
	var v := Pebble.launch_velocity(_yaw, _pitch, power)
	_model.rotation.y = atan2(v.x, v.z)
	play_action("Throw", 0.35)
	var pb := Pebble.new()
	pb.game = Game
	pb.shooter = self
	pb.vel = v
	get_parent().add_child(pb)
	pb.global_position = global_position + Vector3(0, 1.3, 0) + Vector3(v.x, 0, v.z).normalized() * 0.5
	Game.shake.emit(0.03 + 0.07 * power)
	Sfx.play_on(self, "boing", 1.5 + 0.6 * power)
	var hs: Node3D = _hand_items.get(GameState.Tool.SLINGSHOT)
	if hs != null:
		var tw := create_tween()
		tw.tween_property(hs, "scale", Vector3(1, 1.35, 1), 0.06)
		tw.tween_property(hs, "scale", Vector3.ONE, 0.18)


func _smash_tool() -> bool:
	return Game.current_tool == GameState.Tool.AXE or Game.current_tool == GameState.Tool.PICKAXE


## Shove physics props you walk into (crates, barrels, loose logs).
func _push_bodies() -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd < 0.5:
		return
	for i in get_slide_collision_count():
		var rb := get_slide_collision(i).get_collider() as RigidBody3D
		if rb == null:
			continue
		var dir := Vector3(velocity.x, 0, velocity.z).normalized()
		rb.apply_central_impulse(dir * PropCrate.push_strength(rb.mass, spd) * rb.mass * 0.35)


## Nearest smashable crate/barrel in front of you.
func _crate_ahead() -> PropCrate:
	var forward := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	var probe := global_position + forward * 0.9
	var best: PropCrate = null
	var best_d := 1.5
	for n in get_tree().get_nodes_in_group("smashable"):
		var c := n as PropCrate
		if c == null:
			continue
		var d := Vector2(probe.x - c.global_position.x, probe.z - c.global_position.z).length()
		if d < best_d:
			best = c
			best_d = d
	return best


## Nearest huntable rabbit within bonking reach in front of you (any tool but the builder).
func _rabbit_ahead() -> Critter:
	var forward := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	var probe := global_position + forward * 0.9
	var best: Critter = null
	var best_d := 1.5
	for n in get_tree().get_nodes_in_group("huntable"):
		var c := n as Critter
		if c == null or not c.visible:
			continue
		var d := Vector2(probe.x - c.global_position.x, probe.z - c.global_position.z).length()
		if d < best_d:
			best = c
			best_d = d
	return best


## Nearest loose log in front of you (axe chops it into planks).
func _log_ahead() -> WoodLog:
	var forward := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	var probe := global_position + forward * 0.9
	var best: WoodLog = null
	var best_d := 1.6
	for n in get_tree().get_nodes_in_group("pickup"):
		var l := n as WoodLog
		if l == null or l.item_id != "wood" or l.chunk_color.a > 0.0 or l.age < WoodLog.ARM_TIME:
			continue
		var d := Vector2(probe.x - l.global_position.x, probe.z - l.global_position.z).length()
		if d < best_d:
			best = l
			best_d = d
	return best


var _wing: Node3D


## Pelt wings fan out from the back while gliding; a little wind puff when they open.
func _set_glider_wing(on: bool) -> void:
	if _wing == null:
		_wing = Node3D.new()
		for sx in [-1.0, 1.0]:
			var w := Art.box(Vector3(0.9, 0.04, 0.55), Color(0.78, 0.62, 0.45))
			w.position = Vector3(0.55 * sx, 1.15, -0.25)
			w.rotation.z = -0.25 * sx
			_wing.add_child(w)
		_wing.visible = false
		_model.add_child(_wing)
	if on and not _wing.visible:
		FX.burst(self, global_position + Vector3(0, 1.2, 0), Color(1, 1, 1, 0.6), 6, 0.1, 2.0, -0.5, "sphere", 120.0)
	_wing.visible = on
	_wing.scale = _wing.scale.lerp(Vector3.ONE if on else Vector3(0.3, 1, 0.3), 0.3)


func _drive(delta: float) -> void:
	var throttle := Input.get_axis("move_back", "move_forward")
	var steer := Input.get_axis("move_left", "move_right")
	vehicle.drive(delta, throttle, steer, Input.is_action_pressed("jump"), Input.is_action_pressed("sprint"))
	Game.car_damage = vehicle.damage
	if vehicle.boosting:
		Game.shake.emit(0.06)
	global_position = vehicle.global_position
	# Chase camera drifts behind the car unless the mouse is being used.
	_yaw = lerp_angle(_yaw, vehicle.heading + PI, 2.0 * delta)
	_zoom = max(_zoom, 8.0)
	camera.fov = lerp(camera.fov, 65.0 + absf(vehicle.speed) * 0.6 + (10.0 if vehicle.boosting or vehicle.turbo_time > 0.0 else 0.0), 4.0 * delta)
	_dust.emitting = false
	_update_camera(delta)
	target = null


func _physics_process(delta: float) -> void:
	_sling_cd = maxf(0.0, _sling_cd - delta)
	_bomb_cd = maxf(0.0, _bomb_cd - delta)
	_blast_time = maxf(0.0, _blast_time - delta)
	if _sling_charge >= 0.0:
		if Game.current_tool != GameState.Tool.SLINGSHOT or vehicle != null or mount != null:
			_sling_charge = -1.0
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("interact"):
			_sling_charge += delta
			var hs: Node3D = _hand_items.get(GameState.Tool.SLINGSHOT)
			if hs != null:   # band stretches back as you draw
				var p := Pebble.charge_power(_sling_charge)
				hs.scale = Vector3(1.0, 1.0, 1.0 + 0.5 * p)
		else:
			var hs2: Node3D = _hand_items.get(GameState.Tool.SLINGSHOT)
			if hs2 != null:
				hs2.scale = Vector3.ONE
			var held := _sling_charge
			_sling_charge = -1.0
			_fire_slingshot(held)
	var look := Input.get_vector("look_left", "look_right", "look_down", "look_up")
	if look.length() > 0.0:
		_yaw -= look.x * PAD_LOOK_SPEED * delta
		_pitch = clamp(_pitch + look.y * PAD_LOOK_SPEED * 0.6 * delta, -1.2, 0.25)
	if vehicle != null:
		_drive(delta)
		return
	var jr := FX.jump_step(is_on_floor(), Input.is_action_just_pressed("jump"), _coyote, _jump_buf, delta)
	_coyote = jr["coyote"]
	_jump_buf = jr["buffer"]
	if not is_on_floor():
		velocity.y -= gravity * delta
	if jr["jump"]:
		var boots := Game.count("spring_boots") > 0
		velocity.y = GameState.jump_speed(boots, mount != null, Critter.MOUNT_JUMP)
		if boots and mount == null:
			Sfx.play_on(self, "boing", 0.9 + randf() * 0.3)
			FX.burst(self, global_position + Vector3(0, 0.1, 0), Color(0.72, 0.64, 0.5), 6, 0.1, 2.2, -2.0, "sphere", 90.0)

	var gliding := false
	if mount == null and Game.count("glider") > 0:
		velocity.y = FX.glide_vy(velocity.y, true, Input.is_action_pressed("jump"), not is_on_floor())
		gliding = not is_on_floor() and Input.is_action_pressed("jump") and velocity.y <= FX.GLIDE_FALL + 0.01
	_set_glider_wing(gliding)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis_yaw := Basis(Vector3.UP, _yaw)
	var dir := (basis_yaw * Vector3(input.x, 0, input.y))
	crouching = Input.is_action_pressed("crouch") and is_on_floor() and mount == null
	var sr := FX.stamina_step(stamina, Input.is_action_pressed("sprint") and not crouching, dir.length() > 0.01, winded, delta)
	stamina = sr["stamina"]
	if sr["winded"] and not winded:
		Game.say("Huff... puff... turnips are heavy.")
	winded = sr["winded"]
	var speed := CROUCH_SPEED if crouching else (RUN_SPEED if sr["sprinting"] else WALK_SPEED)
	if mount != null:
		speed = Critter.mount_speed(sr["sprinting"], FX.carry_speed_mult(Game.carry_weight(), Game.carry_free()))
	else:
		speed *= FX.carry_speed_mult(Game.carry_weight(), Game.carry_free())
	_squash = lerpf(_squash, 1.0, 10.0 * delta)
	_model.scale.y = lerpf(_model.scale.y, (0.7 if crouching else 1.0) * _squash, 12.0 * delta)
	speed *= FX.glide_speed_mult(gliding)
	if global_position.y < Terrain.WATER_LEVEL + 0.2:
		speed *= 0.45   # wading through the pond
	var flat_now := Vector2(velocity.x, velocity.z)
	var wish := Vector2.ZERO
	if dir.length() > 0.01:
		dir = dir.normalized()
		wish = Vector2(dir.x, dir.z) * speed
	var was_skid := skidding
	skidding = is_on_floor() and mount == null and FX.is_skid(flat_now, wish)
	if _blast_time > 0.0:
		skidding = false   # flying from a blast: keep the launch velocity, no steering
	else:
		var accel := FX.move_accel(flat_now, wish, is_on_floor())
		var next := flat_now.move_toward(wish, accel * delta)
		velocity.x = next.x
		velocity.z = next.y
		if dir.length() > 0.01:
			_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	_skid_puff = maxf(0.0, _skid_puff - delta)
	if skidding:
		if not was_skid:
			Sfx.play_on(self, "skid", 0.9 + randf() * 0.25)
		if _skid_puff <= 0.0:
			_skid_puff = 0.06
			FX.burst(self, global_position + Vector3(0, 0.08, 0), Color(0.78, 0.7, 0.55), 5, 0.13, 1.8, -1.0, "sphere", 70.0)
	_update_lean(delta, flat_now.length())
	if _action_time > 0.0:
		velocity.x *= 0.2
		velocity.z *= 0.2
	_last_vy = velocity.y
	move_and_slide()
	_push_bodies()
	if is_on_floor() and not _was_floor and _last_vy < -3.0:
		_squash = FX.landing_squash(-_last_vy)
		FX.burst(self, global_position + Vector3(0, 0.05, 0), Color(0.78, 0.7, 0.55), 10, 0.14, 2.2, -1.0, "sphere", 80.0)
		Sfx.play_on(self, "thud")
	if is_on_floor() and not _was_floor:
		_try_bounce(-_last_vy)
	_was_floor = is_on_floor()
	var md := meadow()
	in_cover = md != null and mount == null and Meadow.is_cover(crouching, md.tall_count(global_position) if crouching else 0)
	if in_cover and not _cover_told:
		_cover_told = true
		Game.say("Hidden in the tall grass. You are, legally speaking, a shrub.")
	if global_position.y < -20.0:
		global_position = Vector3(0, 2, 8)
		velocity = Vector3.ZERO

	_update_animation(delta)
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	_dust.emitting = is_on_floor() and flat_speed > 6.0
	var fov_want := 72.0 if flat_speed > 6.0 else 65.0
	if mount != null:
		_ride_sync(delta, flat_speed)
		fov_want = 82.0 if flat_speed > 10.0 else 68.0
		_dust.emitting = false
	camera.fov = lerp(camera.fov, fov_want, 4.0 * delta)
	_update_camera(delta)
	if mount != null:
		target = null
	else:
		_find_target()


var _cover_told := false


## Lean into turns, pitch into a run, rear back in a skid.
func _update_lean(delta: float, speed: float) -> void:
	var turn := wrapf(_model.rotation.y - _face_prev, -PI, PI) / maxf(delta, 0.001)
	_face_prev = _model.rotation.y
	var want := Vector2.ZERO
	if mount == null and is_on_floor() and _action_time <= 0.0 and not crouching:
		want = Vector2(FX.lean_pitch(speed, skidding), FX.lean_roll(turn, speed))
	_lean = _lean.lerp(want, minf(1.0, 10.0 * delta))
	_model.rotation.x = _lean.x
	_model.rotation.z = _lean.y


## Landed on a hay bale? Boing.
func _try_bounce(fall: float) -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var piece := col.get_collider() as BuildPiece
		if piece == null or piece.piece_id != "hay_bale" or col.get_normal().y < 0.6:
			continue
		var up := FX.bounce_vy(fall, Input.is_action_pressed("jump"))
		if up <= 0.0:
			return false
		velocity.y = up
		_coyote = 0.0
		_squash = 1.3
		piece.squish(up)
		Sfx.play_on(self, "boing", 0.7 + up * 0.04)
		FX.burst(self, global_position + Vector3(0, 0.05, 0), Color(0.95, 0.82, 0.35), 14, 0.07, 3.2, -6.0, "box", 120.0)
		Game.shake.emit(0.05 + up * 0.008)
		play_action("Jump_Full_Short", 0.3)
		return true
	return false


## Keep the goat under the rider, gallop its legs, and fling hoof clods behind it.
func _ride_sync(delta: float, flat_speed: float) -> void:
	mount.global_position = global_position
	mount.rotation.y = _model.rotation.y
	mount.ride_tick(delta, flat_speed, is_on_floor())
	var iv := Critter.hoof_interval(flat_speed)
	if iv > 0.0 and is_on_floor():
		_hoof_t -= delta
		if _hoof_t <= 0.0:
			_hoof_t = iv
			var back := -Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
			var fast := flat_speed > Critter.MOUNT_WALK + 1.0
			FX.burst(self, global_position + back * 0.7 + Vector3(0, 0.08, 0), Color(0.5, 0.38, 0.24) if fast else Color(0.78, 0.7, 0.55),
				7 if fast else 3, 0.1 if fast else 0.14, 3.2 if fast else 1.4, -9.0 if fast else -1.0, "box" if fast else "sphere", 50.0)
			if fast:
				Sfx.play_on(self, "thud", 1.9)
	else:
		_hoof_t = 0.0


func _update_camera(delta: float) -> void:
	_pivot.global_position = _pivot.global_position.lerp(global_position + Vector3(0, 1.4, 0), 12.0 * delta)
	_pivot.rotation = Vector3(_pitch, _yaw, 0)
	_arm.spring_length = lerp(_arm.spring_length, Closet.camera_zoom(Game.in_closet, _zoom), 8.0 * delta)
	_trauma = max(0.0, _trauma - delta * 1.5)
	var k := _trauma * _trauma
	camera.h_offset = randf_range(-1, 1) * 0.25 * k
	camera.v_offset = randf_range(-1, 1) * 0.25 * k


func _find_target() -> void:
	var best: Interactable = null
	var best_d := INF
	var forward := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	var probe := global_position + forward * 0.9
	for node in get_tree().get_nodes_in_group("interactable"):
		var it := node as Interactable
		if it == null or not it.is_visible_in_tree():
			continue
		var d := Vector2(probe.x - it.global_position.x, probe.z - it.global_position.z).length()
		var rank := Bug.target_rank(d, it is Bug)
		if d < it.interact_radius and rank < best_d:
			best = it
			best_d = rank
	target = best if Game.current_tool != GameState.Tool.BUILD else null
