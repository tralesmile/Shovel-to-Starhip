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
		for i in 3:
			tree.interact(Game)
		await _wait(110)
		await _shot("99_logs.png")
		print("LOGS ", get_tree().get_nodes_in_group("pickup").size())
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=98"):
		var rock: MineRock = main.get_node("Rocks/Rock_00")
		Game.set_tool(GameState.Tool.PICKAXE)
		p.global_position = rock.global_position + Vector3(0, 0.1, -3.5)
		p._yaw = PI
		p._pitch = -0.3
		p._zoom = 8.0
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		for i in 2:
			rock.interact(Game)
		await _wait(30)
		await _shot("98_rock_cracked.png")
		for i in 2:
			rock.interact(Game)
		await _wait(60)
		await _shot("98_rock_broken.png")
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
