extends Node
## QA helper: when the game is started with  -- --shots=<dir>  it sets up a few
## scenes, saves screenshots and quits. Never active in normal play.

var out_dir := ""
var main: Node3D


func _ready() -> void:
	main = get_parent()
	Game.clock_running = false
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _wanted(file: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			return file.substr(0, 2) in a.trim_prefix("--only=").split(",")
	return true


func _shot(file: String) -> void:
	if not _wanted(file):
		return
	await _wait(20)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("saved ", file)


func _view(p: Player, t: float, pos: Vector3, yaw: float, pitch: float, zoom: float, file: String) -> void:
	if not _wanted(file):
		return
	Game.time_of_day = t
	p.global_position = pos
	p._yaw = yaw
	p._pitch = pitch
	p._zoom = zoom
	p._pivot.global_position = pos + Vector3(0, 1.4, 0)
	await _wait(45)
	await _shot(file)


func _run() -> void:
	var p: Player = main.player
	# Prepare a farm in mixed states so the shot shows every stage.
	var plots := get_tree().get_nodes_in_group("daily").filter(func(n): return n is FarmPlot)
	for i in plots.size():
		var plot: FarmPlot = plots[i]
		if i % 4 == 0:
			continue
		plot.state = FarmPlot.State.TILLED if i % 4 == 1 else FarmPlot.State.PLANTED
		plot.watered = i % 3 == 0
		plot.growth = (i / 4) % 3
		plot.from_dict(plot.to_dict())
	Game.add_item("turnip", 3)
	Game.add_item("wood", 6)

	Game.time_of_day = 0.42
	p.global_position = Vector3(0, 0.1, 6.5)
	p._yaw = 0.0
	p._pitch = -0.5
	p._zoom = 8.0
	p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
	Game.say("Welcome to Bumpkin Bay! Press H for help.")
	if _wanted("99_logs.png") and OS.get_cmdline_user_args().has("--only=99"):
		var tree: ChoppableTree = main.get_node("Trees/Tree_00")
		Game.set_tool(GameState.Tool.AXE)
		p.global_position = tree.global_position + Vector3(0, 0.1, 3.5)
		p._yaw = 0.0
		p._pitch = -0.3
		p._zoom = 8.0
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		p.global_position = tree.global_position + Vector3(2.5, 0.1, 3.0)   # swing from the south-east: it falls north-west
		p._yaw = -0.6
		for i in 3:
			tree.interact(Game)
		await _wait(38)
		await _shot("99_fall_mid.png")
		await _wait(70)
		await _shot("99_logs.png")
		print("LOGS ", get_tree().get_nodes_in_group("pickup").size())
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=95"):
		var bw: BuildWorld = main.get_node("BuildWorld")
		Game.time_of_day = 16.5
		Game.add_item("fence_panel", 6)
		Game.add_item("stone_wall", 3)
		Game.set_tool(GameState.Tool.BUILD)
		p.global_position = Vector3(4, Terrain.height_at(4, -4), -4)
		p._yaw = 0.0
		p._pitch = -0.35
		p._zoom = 7.0
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		await _wait(10)
		for i in 4:
			bw.place("fence_panel", Vector3(0 + i * 2, 0, -8), 0, Game)
		bw.place("fence_panel", Vector3(6, 0, -6), 1, Game)
		bw.place("stone_wall", Vector3(-2, 0, -6), 1, Game)
		bw.place("stone_wall", Vector3(-2, 0, -4), 1, Game)
		await _wait(30)
		p._model.rotation.y = 0.0
		p.global_position = Vector3(1, Terrain.height_at(1, -3.0), -3.0)
		await _wait(3)
		p._model.rotation.y = PI
		await _wait(10)
		await _shot("95_build_mode.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=93"):
		var bw3: BuildWorld = main.get_node("BuildWorld")
		Game.time_of_day = 20.0
		Game.add_item("campfire", 1)
		Game.add_item("rabbit_meat", 2)
		var p3: Player = main.player
		p3.global_position = Vector3(4, Terrain.height_at(4, -2), -2)
		p3._yaw = 1.0
		p3._pitch = -0.35
		p3._zoom = 5.5
		p3._pivot.global_position = p3.global_position + Vector3(0, 1.4, 0)
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		await _wait(10)
		bw3.place("campfire", Vector3(4, 0, -5), 0, Game)
		await _wait(30)
		var cf: CampfireSpot = null
		for n in get_tree().get_nodes_in_group("interactable"):
			if n is CampfireSpot:
				cf = n
		cf.interact(Game)
		await _wait(60)
		await _shot("93_campfire.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=94"):
		var bw4: BuildWorld = main.get_node("BuildWorld")
		Game.time_of_day = 15.5
		Game.add_item("wood_floor", 6)
		Game.add_item("wood_wall", 6)
		p.global_position = Vector3(4, Terrain.height_at(4, -2), -2)
		p._yaw = 0.3
		p._pitch = -0.4
		p._zoom = 8.0
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		await _wait(10)
		for fx in 2:
			for fz in 2:
				bw4.place("wood_floor", Vector3(fx * 2, 0, -8 + fz * 2), 0, Game)
		bw4.place("wood_wall", Vector3(0, 0, -9), 0, Game)
		bw4.place("wood_wall", Vector3(2, 0, -9), 0, Game)
		bw4.place("wood_wall", Vector3(-1, 0, -8), 1, Game)
		bw4.place("wood_wall", Vector3(-1, 0, -6), 1, Game)
		Game.add_item("wood_door", 2)
		Game.add_item("wood_roof", 4)
		bw4.place("wood_door", Vector3(2, 0, -7), 0, Game)
		bw4.place("wood_roof", Vector3(0, 0, -8), 0, Game)
		bw4.place("wood_roof", Vector3(2, 0, -8), 0, Game)
		var lg4 := WoodLog.new()
		lg4.game = Game
		main.add_child(lg4)
		lg4.global_position = Vector3(5, Terrain.height_at(5, -4) + 0.6, -4)
		await _wait(40)
		lg4.chop_into_planks()
		await _wait(8)
		await _shot("94_wood_build.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=91"):
		Game.time_of_day = 0.55
		var goat := main.get_node("Goat") as Critter
		goat.tamed = true
		Game.add_item("saddle", 1)
		p.global_position = Vector3(2, Terrain.height_at(2, 2), 2)
		goat.global_position = p.global_position + Vector3(1.6, 0, 0)
		p._yaw = 0.0
		p._pitch = -0.3
		p._zoom = 6.0
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		await _wait(10)
		p.mount_critter(goat)
		p._model.rotation.y = PI
		Input.action_press("move_forward")
		Input.action_press("sprint")
		await _wait(50)
		p._yaw = 0.5
		await _wait(20)
		await _shot("91_riding.png")
		Input.action_release("move_forward")
		Input.action_release("sprint")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=90"):
		Game.time_of_day = 0.55
		Game.car_owned = true
		Game.car_parts = ["turbo_engine", "offroad_wheels", "rocket_booster"]
		main._spawn_player_car()
		var car := get_tree().get_first_node_in_group("car") as Car
		car.global_position = Vector3(6, Terrain.height_at(6, 6) + 0.1, 6)
		p.global_position = Vector3(2, Terrain.height_at(2, 6), 6)
		p._yaw = 1.2
		p._pitch = -0.25
		p._zoom = 8.0
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		await _wait(20)
		car._flame.emitting = true
		await _wait(20)
		await _shot("90_car_parts.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=92"):
		Game.time_of_day = 0.6
		var rb := main.get_node("Rabbit_0") as Critter
		p.global_position = Vector3(4, Terrain.height_at(4, -2), -2)
		rb.home = Vector3(5.2, 0, 0.0)
		rb.position = rb.home
		rb.global_position = Vector3(5.2, Terrain.height_at(5.2, 0.0), 0.0)
		p._yaw = 0.3
		p._pitch = -0.4
		p._zoom = 6.0
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		p._zoom = 3.5
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		rb.set_process(false)
		await _wait(30)
		await _shot("92_hunting.png")
		rb.set_process(true)
		rb.bonk(Game)
		await _wait(25)
		await _shot("92_hunting_bonk.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=98"):
		var bw8: BuildWorld = main.get_node("BuildWorld")
		Game.time_of_day = 0.45
		Game.add_item("storage_chest", 1)
		Game.add_item("wood", 4)
		var p8: Player = main.player
		var base := Vector3(4, Terrain.height_at(4, -2), -2)
		p8.global_position = base
		p8._yaw = 1.0
		p8._pitch = -0.4
		p8._zoom = 7.0
		p8._pivot.global_position = p8.global_position + Vector3(0, 1.4, 0)
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		await _wait(10)
		bw8.place("storage_chest", Vector3(6, 0, -5), 0, Game)
		await _wait(20)
		for n in get_tree().get_nodes_in_group("interactable"):
			if n is ChestSpot:
				n.interact(Game)
		var tr := ChoppableTree.new()
		tr.name = "ShotTree"
		main.add_child(tr)
		tr.global_position = Vector3(2.5, Terrain.height_at(2.5, -7), -7)
		await _wait(5)
		tr.hits = 2
		Game.current_tool = GameState.Tool.AXE
		tr.interact(Game)
		await _wait(22)
		await _shot("98_timber_chest.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=96"):
		Game.time_of_day = 0.45
		p.global_position = Vector3(Terrain.POND_CENTER.x + 8.0, 0.1, Terrain.POND_CENTER.y + 1.0)
		p._yaw = 1.57
		p._pitch = -0.35
		p._zoom = 9.0
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		await _wait(20)
		await _shot("96_pond_foam.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=97"):
		var wb: Node3D = main.get_node("Workbench")
		Game.time_of_day = 19.5
		Game.add_item("wood", 2)
		p.global_position = wb.global_position + Vector3(0, 0.1, 3.5)
		p._yaw = 0.0
		p._pitch = -0.3
		p._zoom = 6.0
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		await _wait(20)
		wb.interact(Game)
		await _wait(8)
		await _shot("97_workbench.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=89"):
		var rock: MineRock = main.get_node("Rocks/Rock_00")
		Game.set_tool(GameState.Tool.PICKAXE)
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		p.global_position = rock.global_position + Vector3(0, 0.1, -3.5)
		p._yaw = 0.0
		p._pitch = -0.3
		p._zoom = 5.0
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		for i in 3:
			rock.interact(Game)
		await _wait(30)
		await _shot("89_rock_cracked.png")
		rock.interact(Game)
		await _wait(12)
		await _shot("89_rock_broken.png")
		print("CHUNKS ", get_tree().get_nodes_in_group("pickup").size())
		get_tree().quit()
		return
	await _shot("01_farm.png")
	main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)

	p.global_position = Vector3(12, 0.1, 13)
	p._yaw = -0.9
	p._pitch = -0.35
	p._zoom = 11.0
	p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
	await _wait(30)
	await _shot("02_store_and_bin.png")

	p.global_position = Vector3(26, 0.1, -10)
	p._yaw = -0.5
	p._pitch = -0.15
	p._zoom = 9.0
	p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
	await _wait(30)
	await _shot("03_spaceport.png")

	await _view(p, 0.74, Vector3(-6, 0.1, 5), 0.7, -0.38, 11.0, "04_sunset_house.png")
	await _view(p, 0.97, Vector3(2, 0.1, 15), 0.25, -0.3, 10.0, "05_night_town.png")
	await _view(p, 0.40, Vector3(-17, 0.1, 9), 1.9, -0.42, 9.0, "06_pond_animals.png")
	await _view(p, 0.88, Vector3(0, 0.1, 7), 0.0, -0.55, 9.0, "07_night_farm.png")
	await _view(p, 0.93, Vector3(-4, 0.1, 13), PI, -0.25, 11.0, "08_night_shops.png")
	# Furniture room + crates at night (lantern glow).
	var bw := get_tree().get_first_node_in_group("buildworld") as BuildWorld
	for id in ["wood_floor", "wood_table", "wood_chair", "lantern", "wood_wall"]:
		Game.add_item(id, 3)
	for cx in [0, 2]:
		bw.place("wood_floor", Vector3(-2 + cx, 0, 3), 0, Game)
	bw.place("wood_table", Vector3(-2, 0, 3), 0, Game)
	bw.place("wood_chair", Vector3(0, 0, 3), 0, Game)
	bw.place("lantern", Vector3(2, 0, 3), 0, Game)
	bw.place("wood_wall", Vector3(-2, 0, 1), 0, Game)
	await _view(p, 0.95, Vector3(-1, 0.1, 7), 0.0, -0.3, 6.0, "09_furniture_night.png")
	# Bed + dropped items with contact shadows.
	Game.add_item("wood_bed", 1)
	bw.place("wood_bed", Vector3(-4, 0, 3), 0, Game)
	p.global_position = Vector3(-1, 0.1, 6)
	p._model.rotation.y = PI
	for it in ["stone", "stone", "gem", "wood", "copper_ore"]:
		Game.add_item(it, 1)
	for i in 5:
		p.drop_item()
		await _wait(8)
	await _view(p, 0.5, Vector3(-1, 0.1, 6.5), 0.0, -0.4, 6.5, "10_bed_and_drops.png")
	# Targeting check: stand south of a plot facing north (-Z) and see what we'd use.
	p.global_position = Vector3(-1, 0.1, 4.6)
	p._model.rotation.y = PI     # facing -Z
	await _wait(3)
	p._find_target()
	print("TARGET_CHECK plot -> ", p.target.name if p.target else "none")
	p.global_position = Vector3(6.4, 0.1, 8.2)
	p._model.rotation.y = PI
	await _wait(3)
	p._find_target()
	print("TARGET_CHECK sellbin -> ", p.target.name if p.target else "none")
	p.play_action("1H_Melee_Attack_Chop", 0.5)
	await get_tree().physics_frame
	print("ANIM_CHECK ", p._anim.current_animation, " t=", p._action_time)
	get_tree().quit()
