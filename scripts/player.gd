class_name Player
extends CharacterBody3D
## Third-person farmer: WASD to walk, Shift to run, Space to jump,
## mouse to look, E / left click to use the selected tool.

const WALK_SPEED := 5.0
const RUN_SPEED := 8.5
const CROUCH_SPEED := 2.6
var crouching: bool = false
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
	_on_tool_changed(Game.current_tool)


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
	_hand_items[GameState.Tool.PICKAXE] = _make_pickaxe()
	_hand_items[GameState.Tool.BUILD] = _make_hammer()
	_hand_items[GameState.Tool.WATER] = Models.put(_hand, Models.MED + "bucket_water.gltf", Vector3(0, -0.05, 0), 3.2)
	_hand_items[GameState.Tool.SEEDS] = Models.put(_hand, Models.MED + "sack.gltf", Vector3(0, 0, 0), 3.0)


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
			_hand_items[k].visible = (k == index)


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
	if not is_on_floor():
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
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 6:
		if event.is_action_pressed("tool_%d" % (i + 1)):
			Game.set_tool(i)


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
	car.driven = true
	_shape.set_deferred("disabled", true)
	_model.visible = false
	velocity = Vector3.ZERO
	_yaw = car.heading + PI
	Game.say("Vroom. Mind the goat.")
	Game.hint_event.emit("drive")


func _on_car_bump() -> void:
	Game.shake.emit(0.3)


func exit_car() -> void:
	if vehicle == null:
		return
	var car := vehicle
	vehicle = null
	car.driven = false
	car.speed = 0.0
	global_position = car.exit_position()
	_shape.set_deferred("disabled", false)
	_model.visible = true
	Game.car_pos = [car.global_position.x, car.global_position.y, car.global_position.z, car.heading]


func _use() -> void:
	if vehicle != null:
		exit_car()
		return
	if Game.current_tool == GameState.Tool.BUILD:
		var bw := get_tree().get_first_node_in_group("buildworld") as BuildWorld
		if bw != null and _action_time <= 0.0:
			var a := bw.use(self)
			if a != "":
				play_action(a, 0.45)
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
	if target == null or _action_time > 0.0:
		return
	var anim := "Interact"
	if (target is ChoppableTree and Game.current_tool == GameState.Tool.AXE) or (target is MineRock and Game.current_tool == GameState.Tool.PICKAXE):
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


func _drive(delta: float) -> void:
	var throttle := Input.get_axis("move_back", "move_forward")
	var steer := Input.get_axis("move_right", "move_left")
	vehicle.drive(delta, throttle, steer, Input.is_action_pressed("jump"))
	global_position = vehicle.global_position
	# Chase camera drifts behind the car unless the mouse is being used.
	_yaw = lerp_angle(_yaw, vehicle.heading + PI, 2.0 * delta)
	_zoom = max(_zoom, 8.0)
	camera.fov = lerp(camera.fov, 65.0 + absf(vehicle.speed) * 0.6, 4.0 * delta)
	_dust.emitting = false
	_update_camera(delta)
	target = null


func _physics_process(delta: float) -> void:
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
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis_yaw := Basis(Vector3.UP, _yaw)
	var dir := (basis_yaw * Vector3(input.x, 0, input.y))
	crouching = Input.is_action_pressed("crouch") and is_on_floor()
	var sr := FX.stamina_step(stamina, Input.is_action_pressed("sprint") and not crouching, dir.length() > 0.01, winded, delta)
	stamina = sr["stamina"]
	if sr["winded"] and not winded:
		Game.say("Huff... puff... turnips are heavy.")
	winded = sr["winded"]
	var speed := CROUCH_SPEED if crouching else (RUN_SPEED if sr["sprinting"] else WALK_SPEED)
	speed *= FX.carry_speed_mult(Game.carry_weight(), Game.carry_free())
	_squash = lerpf(_squash, 1.0, 10.0 * delta)
	_model.scale.y = lerpf(_model.scale.y, (0.7 if crouching else 1.0) * _squash, 12.0 * delta)
	if global_position.y < Terrain.WATER_LEVEL + 0.2:
		speed *= 0.45   # wading through the pond
	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * speed, 40.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, 40.0 * delta)
		var face := atan2(dir.x, dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, face, 12.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 40.0 * delta)
	if _action_time > 0.0:
		velocity.x *= 0.2
		velocity.z *= 0.2
	_last_vy = velocity.y
	move_and_slide()
	if is_on_floor() and not _was_floor and _last_vy < -3.0:
		_squash = FX.landing_squash(-_last_vy)
		FX.burst(self, global_position + Vector3(0, 0.05, 0), Color(0.78, 0.7, 0.55), 10, 0.14, 2.2, -1.0, "sphere", 80.0)
		Sfx.play_on(self, "thud")
	_was_floor = is_on_floor()
	if global_position.y < -20.0:
		global_position = Vector3(0, 2, 8)
		velocity = Vector3.ZERO

	_update_animation(delta)
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	_dust.emitting = is_on_floor() and flat_speed > 6.0
	camera.fov = lerp(camera.fov, 72.0 if flat_speed > 6.0 else 65.0, 4.0 * delta)
	_update_camera(delta)
	_find_target()


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
		if d < it.interact_radius and d < best_d:
			best = it
			best_d = d
	target = best if Game.current_tool != GameState.Tool.BUILD else null
