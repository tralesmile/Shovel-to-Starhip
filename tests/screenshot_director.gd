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
	if Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--only=7")):
		await _heist_before(p)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=21,22,23,24,25"):
		await _pet_action_shots(p)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=26"):
		await _whistle_shot(p)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=20"):
		await _pet_shots(p, "20")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=b0"):
		await _house_before(p)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=b1,b2,b3,b4,b5,b6,b7,b8"):
		await _house_after(p)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=b9"):
		await _house_walk(p)
		get_tree().quit()
		return
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
	if OS.get_cmdline_user_args().has("--only=30"):
		await _farm_overview(p, "30_farm.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=31,32,33,34,35,36"):
		await _farm_shots(p)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=40"):
		await _car_before_shot(p)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=41,42,43,44,45"):
		await _car_shots(p)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=50,51,52,53,54,55,56,57"):
		await _fishing_shots(p)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=60,61,62,63,64,65,66"):
		await _timber_and_bug_shots(p)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=70,71,72,73"):
		var md: Meadow = p.meadow()
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		var spot := Vector2(9.5, -8.0)
		for o in main.get_node("Trees").get_children():
			(o as Node3D).visible = (o as Node3D).global_position.distance_to(Vector3(spot.x, 0, spot.y)) > 8.0
		var at := Vector3(spot.x, 0.1, spot.y + 0.4)
		p._model.rotation.y = PI * 0.75
		await _view(p, 0.70, at, 0.15, -0.42, 6.0, "70_meadow.png")
		p._model.rotation.y = PI
		await _wait(5)
		Game.add_item("scythe", 1)
		Game.set_tool(GameState.Tool.HOE)
		p.global_position = at
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		await _wait(20)
		var before := md.tall_count(p.global_position, 3.0)
		Engine.time_scale = 0.12   # slow motion: software frames are too long to catch a 0.2s slash
		print("SWING cut=", p.swing_grass(), " tall before=", before)
		await get_tree().create_timer(0.3, true, false, true).timeout   # outlast the hit-stop
		Engine.time_scale = 0.12
		p._sweep_arc(Meadow.SCYTHE_RADIUS, 360.0)
		md._blade_burst(p.global_position + Vector3(1.4, 0.4, 0.3), p.global_position, 0.3)
		md._blade_burst(p.global_position + Vector3(-1.2, 0.4, 0.8), p.global_position, 0.9)
		await _wait(3)
		var img := get_viewport().get_texture().get_image()
		img.save_png(out_dir.path_join("71_scythe_swing.png"))
		Engine.time_scale = 1.0
		await _wait(6)
		await _shot("72_stubble_hay.png")
		print("PICKUPS ", get_tree().get_nodes_in_group("pickup").size(), " hay in pockets ", Game.count("hay"))
		var bw := get_tree().get_first_node_in_group("buildworld") as BuildWorld
		Game.add_item("hay_bale", 1)
		bw.place("hay_bale", Vector3(-4, 0, 16 - 22), 0, Game)
		var top := Vector3(-4, Terrain.height_at(-4, -6) + 3.4, -6)
		p.global_position = top
		p.velocity = Vector3.ZERO
		p._yaw = 0.5
		p._pitch = -0.2
		p._zoom = 6.0
		p._pivot.global_position = top
		Input.action_press("jump")
		var peak := 0.0
		var shot := false
		for i in 240:
			await get_tree().physics_frame
			if i % 20 == 0:
				print("  y=", p.global_position.y, " vy=", p.velocity.y, " floor=", p.is_on_floor())
			if p.velocity.y > 6.0 and not shot:
				shot = true
				print("BOUNCE vy=", p.velocity.y)
				await _wait(2)
				get_viewport().get_texture().get_image().save_png(out_dir.path_join("73_hay_bounce.png"))
		Input.action_release("jump")
		print("BOUNCED ", shot)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=88"):
		var gr: GranRocket = main.get_node("Spaceport/GranRocket")
		Game.time_of_day = 0.45
		Game.total_earned = 200
		var rp := gr.global_position + Vector3(-9, 0.1, 2)
		p.global_position = rp
		p._yaw = -1.57
		p._pitch = -0.15
		p._zoom = 9.0
		p._pivot.global_position = rp + Vector3(0, 1.4, 0)
		await _wait(45)
		await _shot("88_rocket_wreck.png")
		Game.story_act = 4
		gr.set_stage(4, false)
		await _wait(30)
		await _shot("88_rocket_almost.png")
		Game.story_act = 5
		gr.set_stage(5, true)
		await _wait(50)
		await _shot("88_rocket_done.png")
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
	if OS.get_cmdline_user_args().has("--only=87"):
		var bw9: BuildWorld = main.get_node("BuildWorld")
		Game.time_of_day = 0.45
		Game.add_item("anvil", 1)
		Game.add_item("copper_ingot", 2)
		var p9: Player = main.player
		p9.global_position = Vector3(4, Terrain.height_at(4, -2), -2)
		p9._yaw = 1.0
		p9._pitch = -0.4
		p9._zoom = 6.0
		p9._pivot.global_position = p9.global_position + Vector3(0, 1.4, 0)
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		await _wait(10)
		bw9.place("anvil", Vector3(6, 0, -5), 0, Game)
		await _wait(20)
		var tr9 := ChoppableTree.new()
		main.add_child(tr9)
		tr9.global_position = Vector3(2.5, Terrain.height_at(2.5, -7), -7)
		await _wait(5)
		Game.current_tool = GameState.Tool.AXE
		tr9.interact(Game)
		for n in get_tree().get_nodes_in_group("interactable"):
			if n is AnvilSpot:
				n.interact(Game)
		await _wait(8)
		await _shot("87_anvil_chips.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=84"):
		var d84 := 3
		while Weather.for_day(d84) != Weather.STORM:
			d84 += 1
		Game.day = d84
		Game.time_of_day = 0.45
		var p84: Player = main.player
		p84.global_position = Vector3(4, Terrain.height_at(4, -2), -2)
		p84._yaw = 1.0
		p84._pitch = -0.1
		p84._zoom = 6.0
		main._rain_level = 0.9
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		await _wait(10)
		await _shot("84_storm_calm.png")
		main._bolt_age = 0.02
		main._bolt_timer = 99.0
		await _wait(1)
		await _shot("84_storm_flash.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=85"):
		var d85 := 3
		while Weather.for_day(d85) != Weather.RAIN:
			d85 += 1
		Game.day = d85
		Game.time_of_day = 0.45
		Game.add_item("slingshot", 1)
		Game.add_item("stone", 5)
		Game.set_tool(GameState.Tool.SLINGSHOT)
		var p85: Player = main.player
		p85.global_position = Vector3(4, Terrain.height_at(4, -2), -2)
		p85._yaw = 1.0
		p85._pitch = -0.2
		p85._zoom = 5.0
		main._rain_level = 0.55
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		await _wait(10)
		p85._fire_slingshot()
		await _wait(8)
		await _shot("85_rain_slingshot.png")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only=86"):
		var bw10: BuildWorld = main.get_node("BuildWorld")
		Game.time_of_day = 0.8
		Game.add_item("invention_bench", 1)
		Game.add_item("copper_ingot", 2)
		Game.add_item("gem", 1)
		Game.add_item("plank", 1)
		var p10: Player = main.player
		p10.global_position = Vector3(4, Terrain.height_at(4, -2), -2)
		p10._yaw = 1.0
		p10._pitch = -0.35
		p10._zoom = 5.0
		p10._pivot.global_position = p10.global_position + Vector3(0, 1.4, 0)
		main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
		await _wait(10)
		bw10.place("invention_bench", Vector3(6, 0, -5), 0, Game)
		await _wait(20)
		for n in get_tree().get_nodes_in_group("interactable"):
			if n is InventionSpot:
				n.interact(Game)
		await _wait(6)
		await _shot("86_invention_bench.png")
		get_tree().quit()
		return
	if "--only=80,81,82,83,84,85" in OS.get_cmdline_user_args():
		await _mine_shots(p)
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
		rock.interact(Game)
		await _wait(6)
		await _shot("89_rock_chips.png")
		Game.add_item("glider", 1)
		p._set_glider_wing(true)
		for i in 2:
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


## Felled trunk, bucking, domino, meadow critters and the Firefly Jar at night.
func _timber_and_bug_shots(p: Player) -> void:
	await _domino_shot(p)
	main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
	Game.time_of_day = 0.42
	var tree: ChoppableTree = main.get_node("Trees/Tree_05")   # open ground west of the farm
	var base := tree.global_position
	Game.set_tool(GameState.Tool.AXE)
	p.global_position = base + Vector3(2.6, 0.1, 0.6)
	p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
	var cam := _free_cam(base + Vector3(0.5, 4.2, 7.0), base + Vector3(-2.2, 0.4, 0))
	await _wait(10)
	for i in 3:
		tree.interact(Game)
	await get_tree().create_timer(2.6, true, false, true).timeout
	await _shot("60_trunk_down.png")
	print("TRUNK ", tree.has_trunk(), " at ", tree.trunk.body.global_position if tree.has_trunk() else Vector3.ZERO)
	var tk: FelledTrunk = tree.trunk
	p.global_position = tk.body.global_position + Vector3(0.2, 0.1, 1.2)
	p._model.rotation.y = PI
	await _wait(10)
	p._find_target()
	print("TARGET is trunk: ", p.target == tk)
	for i in FelledTrunk.CUTS_PER_SECTION:
		tk.interact(Game)
		p.play_action("1H_Melee_Attack_Chop", 0.55)
		await get_tree().create_timer(0.15, true, false, true).timeout
	await get_tree().create_timer(0.5, true, false, true).timeout
	Engine.time_scale = 1.0
	await _shot("61_bucked.png")
	print("sections left ", tk.sections, " logs ", get_tree().get_nodes_in_group("pickup").size())
	# Daytime meadow with butterflies and flushed hoppers.
	var life: BugLife = main.get_node("BugLife")
	var spot := Vector3(9.5, 0.1, -8.0)
	for o in main.get_node("Trees").get_children():
		if o is Node3D:
			(o as Node3D).visible = (o as Node3D).global_position.distance_to(spot) > 9.0
	Game.add_item("bug_net", 1)
	Game.set_tool(GameState.Tool.HOE)
	p.global_position = spot + Vector3(0, 0, 2.2)
	p._model.rotation.y = PI
	cam.global_position = spot + Vector3(3.0, 2.3, 4.2)
	cam.look_at(spot + Vector3(0, 0.45, 0.3))
	cam.fov = 55.0
	await _wait(10)
	for i in 4:
		var a := i * 1.7
		life.spawn("butterfly", spot + Vector3(cos(a) * 1.4, 1.0 + 0.15 * i, sin(a) * 1.0 + 0.3))
	var fg := life.spawn("frog", spot + Vector3(1.2, 0, 2.2), true)
	var gh := life.spawn("grasshopper", spot + Vector3(-0.5, 0, 2.9), true)
	for b in [fg, gh]:
		b._hop_wait = 30.0
	await _wait(4)
	await _shot("62_critters_day.png")
	p._model.rotation.y = PI * 0.4   # side on, so the net shows
	Engine.time_scale = 0.12
	p.swing_net()
	await _wait(5)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("63_net_swing.png"))
	Engine.time_scale = 1.0
	p._model.rotation.y = PI
	# Night: fireflies and the jar.
	var bw := get_tree().get_first_node_in_group("buildworld") as BuildWorld
	Game.add_item("firefly_jar", 1)
	bw.place("firefly_jar", Vector3(12, Terrain.height_at(12, -8), -8), 0, Game)
	Game.time_of_day = 0.9
	await _wait(30)
	for b in life.bugs("butterfly"):
		b.queue_free()
	for i in 14:
		life.spawn("firefly", spot + Vector3(randf_range(-3.5, 3.0), randf_range(0.6, 1.8), randf_range(-3.0, 2.6)))
	await _wait(25)
	await _shot("64_fireflies_night.png")
	print("BUGS ", life.bugs().size())


## Fell Tree_00 straight at Tree_01 and report whether the neighbour got clipped.
func _domino_shot(p: Player) -> void:
	Game.time_of_day = 0.42
	var a: ChoppableTree = main.get_node("Trees/Tree_00")
	var b: ChoppableTree = main.get_node("Trees/Tree_01")
	var d := b.global_position - a.global_position
	d.y = 0.0
	b.hits = 2   # already notched: it should go over too
	Game.set_tool(GameState.Tool.AXE)
	p.global_position = a.global_position - d.normalized() * 1.8 + Vector3(0, 0.1, 0)
	var mid := (a.global_position + b.global_position) * 0.5
	var cam := _free_cam(mid + Vector3(2.0, 6.5, 8.5), mid + Vector3(-1.0, 0.4, 0))
	await _wait(10)
	for i in 3:
		a.interact(Game)
	await get_tree().create_timer(1.55, true, false, true).timeout
	await _shot("65_domino_mid.png")
	await get_tree().create_timer(3.0, true, false, true).timeout
	await _shot("66_two_trunks.png")
	print("DOMINO neighbour felled=", b.felled, " trunks=", get_tree().get_nodes_in_group("trunk").size())
	cam.queue_free()
	for t in [a, b]:
		if t.has_trunk():
			t.trunk.queue_free()


## A free camera that ignores the player rig, so small things can always be framed.
## The field with every crop at every stage: a before/after view for the farm.
func _farm_overview(p: Player, file: String) -> void:
	main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
	Game.time_of_day = 0.42
	var crops := ["turnip", "carrot", "tomato"]
	for i in 16:
		var plot: FarmPlot = main.get_node("Farm/Plot_%02d" % i)
		var col := i / 4     # x column
		var row := i % 4     # z row (3 = nearest the south gate)
		plot.from_dict({"state": FarmPlot.State.PLANTED if col < 3 else FarmPlot.State.TILLED,
			"crop": crops[mini(col, 2)], "growth": [99, 2, 1, 0][3 - row] if row < 3 else 99, "watered": (i % 2) == 0})
	p.global_position = Vector3(1.0, 0.1, 7.5)
	_free_cam(Vector3(3.2, 4.6, 7.4), Vector3(-0.4, 0.0, 0.4), 52.0)
	await _wait(60)
	await _shot(file)


func _snap(file: String) -> void:
	await _wait(2)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)


## Wait for `seconds` of scaled game time (software frames are far too slow to time shots by wall clock).
func _game_wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


## Watering pour, the harvest pop, a giant crop (rooted then loose) and a sprinkler, with real physics.
func _farm_shots(p: Player) -> void:
	await _farm_overview(p, "31_overview_start.png")
	var plot: FarmPlot = main.get_node("Farm/Plot_03")
	plot.from_dict({"state": FarmPlot.State.PLANTED, "crop": "carrot", "growth": 2, "watered": false})
	var cam := _free_cam(Vector3(-0.7, 2.7, 4.5), Vector3(-3.0, 0.4, 2.8), 55.0)
	p.global_position = Vector3(-4.4, 0.1, 2.5)
	p._model.rotation.y = PI * 0.4
	Game.set_tool(GameState.Tool.WATER)
	await _wait(20)
	Engine.time_scale = 0.1
	plot.interact(Game)
	await _game_wait(0.27)
	await _snap("31_pour.png")
	Engine.time_scale = 1.0
	await _wait(30)
	plot.from_dict({"state": FarmPlot.State.PLANTED, "crop": "carrot", "growth": 3, "composted": true})
	p.global_position = Vector3(-4.4, 0.1, 3.4)
	await _wait(10)
	Engine.time_scale = 0.15
	plot.interact(Game)
	await _game_wait(0.5)
	await _snap("32_harvest_pop.png")
	Engine.time_scale = 1.0
	cam.queue_free()
	# A composted turnip block overnight.
	var field: FarmField = main.get_node("Farm/FarmField")
	for i in [5, 6, 9, 10]:
		(field.plots[i] as FarmPlot).from_dict({"state": FarmPlot.State.PLANTED, "crop": "turnip", "growth": 9, "watered": true, "composted": true})
	for n in get_tree().get_nodes_in_group("pickup"):
		n.queue_free()
	Game.advance_day()
	Game.time_of_day = 0.42
	print("GIANTS ", field.giants().size())
	var g: GiantCrop = field.giants()[0]
	p.global_position = g.global_position + Vector3(1.9, 0.1, 1.7)
	p._model.rotation.y = atan2(-1.9, -1.7)
	var cam2 := _free_cam(Vector3(4.6, 3.6, 6.4), Vector3(0.0, 0.7, 0.2), 50.0)
	await _wait(90)
	await _shot("33_giant_rooted.png")
	for k in GiantCrop.TUGS:
		g.interact(Game)
		await _wait(8)
	var ball: GiantBall = field.loose_giants()[0]
	var popped := 0.0
	for k in 60:
		await get_tree().physics_frame
		popped = maxf(popped, ball.global_position.y)
	print("UPROOT apex ", popped, " rest ", ball.global_position)
	await _wait(30)
	await _shot("34_giant_loose.png")
	cam2.queue_free()
	var from := ball.global_position
	p.global_position = from + Vector3(-1.7, 0.0, -0.4)
	ball.heave(Game)
	var apex := 0.0
	for k in 60:
		await get_tree().physics_frame
		apex = maxf(apex, ball.global_position.y)
	print("HEAVE moved ", ball.global_position - from, " apex ", apex)
	# Roll it down to the bin and watch the weigh-in.
	ball.linear_velocity = Vector3.ZERO
	ball.global_position = Vector3(6.4, 1.0, 10.5)
	p.global_position = Vector3(6.4, 0.1, 12.6)
	var cam3 := _free_cam(Vector3(10.8, 3.2, 10.6), Vector3(6.3, 0.9, 6.9), 52.0)
	await _wait(30)
	ball.linear_velocity = Vector3(0, 0, -3.2)
	var money := Game.money
	var guard := 0
	while is_instance_valid(ball) and Game.money == money and guard < 900:
		guard += 1
		await get_tree().physics_frame
	print("WEIGHED ", Game.money - money, " frames ", guard)
	Engine.time_scale = 0.15
	await _game_wait(0.35)
	await _snap("35_weigh_in.png")
	Engine.time_scale = 1.0
	cam3.queue_free()
	var bw := get_tree().get_first_node_in_group("buildworld") as BuildWorld
	for i in 16:
		(field.plots[i] as FarmPlot).from_dict({"state": FarmPlot.State.PLANTED, "crop": ["turnip", "carrot", "tomato"][(i / 4) % 3], "growth": 1 + i % 4})
	Game.add_item("sprinkler", 4)
	for at in [Vector3(-2, 0, -2), Vector3(2, 0, -2), Vector3(-2, 0, 2), Vector3(2, 0, 2)]:
		bw.place("sprinkler", at, 0, Game)
	p.global_position = Vector3(0, 0.1, 6.5)
	_free_cam(Vector3(0.6, 5.4, 7.6), Vector3(0.0, 0.0, 0.2), 52.0)
	await _wait(40)
	for n in get_tree().get_nodes_in_group("sprinkler"):
		n.spray(60.0)
	await _wait(25)
	await _shot("36_sprinklers.png")


func _free_cam(from: Vector3, at: Vector3, fov: float = 65.0) -> Camera3D:
	var c := Camera3D.new()
	c.fov = fov
	main.add_child(c)
	c.global_position = from
	c.look_at(at)
	c.current = true
	return c


## Gran's Old Mine: entrance, gameplay view, a Boom Turnip in flight, the blast and the secret pocket.
func _mine_shots(p: Player) -> void:
	main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
	Game.time_of_day = 0.45
	var e := MineCave.ENTRANCE
	p.global_position = e + Vector3(1.4, 0.2, 4.0)
	var outside := _free_cam(e + Vector3(4.5, 3.6, 9.5), e + Vector3(0, 1.9, 0))
	await _wait(30)
	await _shot("80_mine_entrance.png")
	outside.queue_free()
	p.camera.current = true
	Game.set_tool(GameState.Tool.PICKAXE)
	await _view(p, 0.45, MineCave.ORIGIN + Vector3(0.5, 0.2, 6.0), 0.0, -0.32, 7.0, "81_mine_cave.png")
	var o := MineCave.ORIGIN
	Game.add_item("miner_helmet", 1)
	Game.add_item("boom_turnip", 3)
	p.global_position = o + Vector3(-5.0, 0.1, 1.0)
	p._yaw = PI / 2.0
	p._model.rotation.y = -PI / 2.0
	var cam := _free_cam(o + Vector3(-1.0, 3.6, 5.8), o + Vector3(-10.5, 1.3, -0.5))
	await _wait(30)
	await _shot("82_cracked_wall.png")
	var bomb := p.throw_bomb()
	await _wait(2)
	var early := get_viewport().get_texture().get_image()
	early.save_png(out_dir.path_join("82_boom_thrown.png"))
	if bomb != null and is_instance_valid(bomb):
		bomb.freeze = true
		bomb.global_position = o + Vector3(-8.6, 0.7, 0.6)
		await _wait(1)
		Engine.max_fps = 0
		bomb.explode()
	# Slow the world right down: software rendering is so slow the blast would be over in one frame.
	for i in 3:
		await get_tree().process_frame
		Engine.time_scale = 0.12
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("83_boom.png"))
	Engine.time_scale = 1.0
	await get_tree().create_timer(1.6).timeout
	await _shot("83_wall_open.png")
	cam.global_position = o + Vector3(-12.2, 2.9, 2.5)
	cam.look_at(o + Vector3(-17.0, 0.8, -0.3))
	p.global_position = o + Vector3(-15.0, 0.1, 0.8)
	p._model.rotation.y = -PI / 2.0
	await _wait(30)
	await _shot("84_secret_pocket.png")
	cam.global_position = o + Vector3(4.5, 2.6, -3.0)
	cam.look_at(o + Vector3(9.0, 1.0, -7.6))
	await _wait(20)
	await _shot("85_geode.png")


## The pond and fishing, from a fixed free camera so before/after shots line up.
func _fishing_shots(p: Player) -> void:
	main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
	Game.time_of_day = 0.45
	var spot: FishingSpot = main.get_node("FishingSpot")
	var pond := spot.pond
	p.global_position = spot.global_position + Vector3(0.2, 0.2, 0)
	p._model.rotation.y = -PI / 2.0
	p._yaw = PI / 2.0
	var cam := _free_cam(Vector3(-15.0, 5.2, 8.5), Vector3(-23.5, -0.6, 0.5), 55.0)
	await _wait(40)
	await _shot("50_pond.png")
	spot.held_override = 1
	spot.interact(Game)
	while spot.charge < 0.75:
		await _wait(1)
	await _shot("51_windup.png")
	spot.held_override = 0
	while spot.phase != FishingSpot.Phase.LINE:
		await _wait(1)
	await _wait(6)
	await _shot("52_cast.png")
	var guard := 0
	while spot.fishing != null and spot.fishing.state != "bite" and guard < 3000:
		guard += 1
		await _wait(1)
	spot.fishing.timer = -1000.0   # hold the bite open for the camera
	await _wait(3)
	var close := _free_cam(Vector3(spot.bobber_pos.x + 2.6, 1.7, spot.bobber_pos.y + 3.0), Vector3(spot.bobber_pos.x, -0.8, spot.bobber_pos.y), 50.0)
	await _shot("53_bite.png")
	close.queue_free()
	cam.current = true
	spot.interact(Game)
	# Fight it with a thrash on screen, then cheat the last stretch.
	spot.fight.surging = true
	spot.fight._phase_left = 1000.0
	spot.fight.tension = 0.75
	spot.held_override = 0
	await _wait(14)
	spot.fight.tension = 0.8
	await _shot("54_fight.png")
	spot.fight.surging = false
	spot.fight.progress = 0.99
	spot.fight.tension = 0.2
	spot.held_override = 1
	while spot.phase == FishingSpot.Phase.FIGHT:
		await _wait(1)
	spot.held_override = 0
	# Slow time right down and use a side camera so the leap and the flop can be seen.
	Engine.time_scale = 0.12
	var side := _free_cam(p.global_position + Vector3(0.6, 3.2, 5.2), p.global_position + Vector3(-2.2, 0.2, 0.0), 55.0)
	await _wait(14)
	await _shot("55_catch_flying.png")
	var fish_items := get_tree().get_nodes_in_group("pickup").filter(func(n): return n is WoodLog and FishModel.has_model(n.item_id))
	if not fish_items.is_empty():
		fish_items[0].age = -60.0   # leave it flopping for the camera
		Engine.time_scale = 1.0
		await _wait(12)
		side.look_at(fish_items[0].global_position)
		side.fov = 32.0
		Engine.time_scale = 0.2
		await _shot("56_catch_after.png")
	Engine.time_scale = 1.0
	side.queue_free()
	cam.current = true
	# Models side by side.
	var i := 0
	for species in Fishing.SIZES:
		var m := FishModel.build(species)
		main.add_child(m)
		m.position = Vector3(-16.8 + (i % 3) * 0.75, 1.6 - (i / 3) * 0.65, 3.4)
		i += 1
	var mc := _free_cam(Vector3(-16.05, 1.45, 5.4), Vector3(-16.05, 1.28, 3.4), 50.0)
	await _wait(10)
	await _shot("57_catch_models.png")
	mc.queue_free()


func _spawn_shot_car(at: Vector3, heading: float) -> Car:
	Game.car_owned = true
	Game.car_pos = [at.x, at.y, at.z, heading]
	var old := get_tree().get_first_node_in_group("car")
	if old != null:
		old.free()
	main._spawn_player_car()
	return get_tree().get_first_node_in_group("car") as Car


func _car_before_shot(p: Player) -> void:
	main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
	Game.time_of_day = 0.45
	var car := _spawn_shot_car(Vector3(4.0, 0.1, 9.0), PI / 2)
	p.global_position = Vector3(4.0, 0.1, 3.0)
	await _wait(40)
	_free_cam(car.global_position + Vector3(3.6, 1.9, -4.6), car.global_position + Vector3(0, 0.6, 0), 50.0)
	await _shot("40_car_grass.png")
	car.global_position = Vector3(4.0, 0.6, 14.4)
	await _wait(40)
	_free_cam(car.global_position + Vector3(3.6, 1.9, -4.6), car.global_position + Vector3(0, 0.6, 0), 50.0)
	await _shot("40_car_road.png")
	print("CARY ", car.global_position.y)


## Drives the car for `secs` of physics time with fixed inputs.
func _drive_for(car: Car, secs: float, throttle: float, steer: float, hand: bool) -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var t := 0.0
	while t < secs:
		await get_tree().physics_frame
		car.drive(dt, throttle, steer, hand)
		t += dt


## The player's real driving path: scripted key presses, chase camera and dashboard.
func _hold(actions: Array, secs: float) -> void:
	for a in actions:
		Input.action_press(a)
	var t := 0.0
	while t < secs:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	for a in actions:
		Input.action_release(a)


func _car_shots(p: Player) -> void:
	main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
	Game.time_of_day = 0.45
	for t in get_tree().get_nodes_in_group("traffic"):
		t.free()
	# 41: drifting on the road through the real player input path.
	var car := _spawn_shot_car(Vector3(-56.0, 0.1, 15.2), PI / 2)
	p.global_position = car.global_position + Vector3(0, 0, -2)
	await _wait(10)
	p.enter_car(car)
	await _hold(["move_forward"], 2.6)
	print("SPEED before drift ", car.speed)
	for a in ["move_forward", "jump", "move_right"]:
		Input.action_press(a)
	var t := 0.0
	while t < 0.62:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	Engine.time_scale = 0.04
	await _grab("42_drift_chasecam.png")
	var fwd := Vector3(sin(car.heading), 0, cos(car.heading))
	var cam := _free_cam(car.global_position + Vector3(5.0, 4.2, -6.0), car.global_position + Vector3(-2.2, 0.2, 0), 60.0)
	await _grab("41_drift.png")
	print("DRIFT lat=", car.lat, " v=", car.speed, " charge=", car.drift_charge, " marks=", car.skids.used, " dmg=", car.damage)
	for a in ["move_forward", "jump", "move_right"]:
		Input.action_release(a)
	Engine.time_scale = 1.0
	cam.queue_free()
	p.camera.current = true
	p.exit_car()
	car.global_position = Vector3(-60, 0.1, -40)
	# 43: cones and the bale pyramid getting bowled over.
	car = _spawn_shot_car(Vector3(30.0, 0.1, 8.6), PI / 2)
	car.speed = 13.0
	car.set_parts(["bull_bar", "drift_tyres"])
	var cam2 := _free_cam(Vector3(48.5, 3.4, 16.5), Vector3(44.5, 1.1, 8.4), 52.0)
	var dt := 1.0 / Engine.physics_ticks_per_second
	var hit := false
	var after := 0.0
	while after < 0.28 and car.global_position.x < 52.0:
		await get_tree().physics_frame
		car.drive(dt, 1.0, 0.0, false)
		hit = hit or get_tree().get_nodes_in_group("knockable").any(func(k): return k.cluster == "pyramid" and k.knocked)
		if hit:
			after += dt
	Engine.time_scale = 0.04
	car.driven = false
	await _grab("43_bowling.png")
	Engine.time_scale = 1.0
	cam2.queue_free()
	# 44: the new bolt-on parts, parked.
	car.halt()
	car.global_position = Vector3(2.0, 0.1, 9.0)
	car.heading = PI / 2
	car.rotation.y = car.heading
	await _wait(60)
	var cam3 := _free_cam(car.global_position + Vector3(4.6, 1.7, -3.4), car.global_position + Vector3(0.4, 0.6, 0), 48.0)
	await _shot("44_parts.png")
	cam3.queue_free()
	# 45: a wreck at dusk, smoking, brake lights on.
	car.set_parts(["offroad_wheels"])
	car.global_position = Vector3(-8.0, 0.4, 15.0)
	car.damage = 0.85
	car.driven = true
	car.braking = true
	Game.time_of_day = 0.76
	var cam4 := _free_cam(car.global_position + Vector3(-5.2, 2.2, -3.6), car.global_position + Vector3(0, 1.0, 0), 52.0)
	await _wait(100)
	await _shot("45_wreck_dusk.png")
	cam4.queue_free()


## Grab the next rendered frame without the long settle that _shot uses (for things in motion).
func _grab(file: String) -> void:
	await _wait(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)


## Heist check: pick the drawer in Pip's home while Pip is in.
func _heist_before(p: Player) -> void:
	var hud: Hud = main.get_children().filter(func(n): return n is Hud)[0]
	hud.set_help_visible(false)
	hud._click_hint.modulate.a = 0.0
	Game.time_of_day = 0.76
	var drawer: LootContainer = main.get_node("Interiors/Interior_2/Drawer_0")
	var npc: Npc = main.get_node("Npc_0")
	p.global_position = drawer.global_position + Vector3(0.9, 0.1, 1.35)
	p._model.rotation.y = PI + 0.55
	p._yaw = -0.5
	p._pitch = -0.55
	p._zoom = 5.0
	p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
	await _wait(30)
	npc._gaze_t = 6.0 - float(npc.gaze_seed % 7) * 1.3   # head about to turn
	drawer.interact(Game)
	drawer.lock.phase = drawer.lock.zone_center
	drawer.interact(Game)
	await _wait(14)
	drawer.set_process(false)
	drawer.lock.phase = drawer.lock.zone_center
	await _shot("70_pick.png")
	npc.witness.suspicion = 0.6
	npc._gaze_t = 7.6 - float(npc.gaze_seed % 7) * 1.3
	await _wait(10)
	await _shot("71_spotted.png")
	npc.witness.suspicion = 0.0
	drawer.lock.picks_left -= 1
	await _wait(5)
	await _shot("72_snap.png")
	for i in 2:
		drawer.lock.phase = drawer.lock.zone_center
		drawer.interact(Game)
	Engine.time_scale = 0.2
	await _wait(14)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1800:
		await get_tree().process_frame
	await _freeze_shot("73_open.png")
	await _wait(80)
	Game.add_item("squeaky_chicken", 1)
	drawer.dresser.close()
	p.global_position = drawer.global_position + Vector3(2.3, 0.1, 1.9)
	p._yaw = -0.1
	p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
	p._zoom = 5.5
	await _wait(10)
	p.crouching = true
	var d := Decoy.new()
	d.game = Game
	main.add_child(d)
	d.global_position = drawer.global_position + Vector3(5.6, 1.2, 1.4)
	await _wait(14)
	await _freeze_shot("74_decoy.png")
	print("DECOY landed=", d.landed, " squeaks=", d.squeaks, " pos=", d.global_position - drawer.global_position, " npc_distracted=", npc.is_distracted())
	var door: Door = main.get_node("Interiors/Interior_2/ExitDoor")
	p.global_position = door.global_position + Vector3(0.3, 0.1, -1.7)
	p._yaw = PI - 0.35
	p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
	p._zoom = 3.5
	await _wait(40)
	Engine.time_scale = 0.1
	door.interact(Game)
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 1500:
		await get_tree().process_frame
	await _freeze_shot("75_door.png")
	await _wait(10)
	await _room_shots(p)


## The other dressed rooms: your house at night and the shop by day.
func _room_shots(p: Player) -> void:
	for cfg in [[0, 0.95, "76_home_night.png"], [1, 0.45, "77_shop.png"]]:
		Game.time_of_day = cfg[1]
		p.crouching = false
		p.global_position = Buildings.interior_origin(cfg[0]) + Vector3(0.9, 0.1, 1.5)
		p._yaw = 0.25
		p._pitch = -0.55
		p._zoom = 5.2
		p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
		await _wait(30)
		await _shot(cfg[2])


## Screenshot with the action held almost still.
func _freeze_shot(file: String) -> void:
	var was := Engine.time_scale
	Engine.time_scale = 0.001
	await _shot(file)
	Engine.time_scale = was if was < 0.999 else 1.0
	Engine.time_scale = 1.0


## Animal check: the farm pets up close, then riding.
func _pet_shots(p: Player, prefix: String) -> void:
	var hud: Hud = main.get_children().filter(func(n): return n is Hud)[0]
	hud.set_help_visible(false)
	hud._click_hint.modulate.a = 0.0
	Game.time_of_day = 0.45
	var goat := main.get_node("Goat") as Critter
	var spot := Vector3(-2.0, 0, 13.0)
	spot.y = Terrain.height_at(spot.x, spot.z)
	p.global_position = spot + Vector3(-3.4, 0.1, -0.6)
	p._model.rotation.y = PI
	goat.set_process(false)
	spot.y = Critter.ground_y(spot.x, spot.z)
	goat.global_position = spot + Vector3(-1.2, 0, 0)
	goat.rotation.y = 0.9
	for k in 4:
		var c := main.get_node("Chicken_%d" % k) as Critter
		c.set_process(false)
		var at := spot + Vector3(0.1 + k * 0.62, 0, 0.5 - (k % 2) * 0.8)
		at.y = Critter.ground_y(at.x, at.z)
		c.global_position = at
		c.rotation.y = -0.7 + k * 0.4
	var bun := main.get_node("Rabbit_0") as Critter
	bun.set_process(false)
	bun.global_position = spot + Vector3(1.0, 0.0, 1.3)
	bun.rotation.y = -0.4
	for n in [goat, bun] + range(4).map(func(k): return main.get_node("Chicken_%d" % k)):
		for i in 20:
			(n as Critter).rig.animate(0.033, 0.0, {})
	var cam := _free_cam(spot + Vector3(0.4, 1.4, 3.3), spot + Vector3(0.3, 0.5, 0), 50.0)
	await _wait(30)
	await _shot(prefix + "_animals.png")
	cam.queue_free()
	p.camera.current = true


## Carrying, floating, fetching, headbutting and riding with saddle bags (real player code).
func _pet_action_shots(p: Player) -> void:
	var hud: Hud = main.get_children().filter(func(n): return n is Hud)[0]
	hud.set_help_visible(false)
	hud._click_hint.modulate.a = 0.0
	Game.time_of_day = 0.45
	var hen := main.get_node("Chicken_1") as Critter
	var goat := main.get_node("Goat") as Critter
	var spot := _clear_spot(p)
	print("clear spot ", spot)
	spot.y = Critter.ground_y(spot.x, spot.z)
	p.global_position = spot + Vector3(0, 0.1, 0)
	p._yaw = 0.5
	p._pitch = -0.2
	p._zoom = 5.0
	p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
	hen.befriend(Game)
	hen.hearts = 3
	print("pickup ", p.pickup_pet(hen))
	p._model.rotation.y = 0.5
	await _wait(30)
	var close := _free_cam(p.global_position + Vector3(2.2, 1.9, -2.8), p.global_position + Vector3(0, 1.4, 0), 45.0)
	await _shot("21_carry.png")
	close.queue_free()
	p.camera.current = true
	# Jump off a height and parachute down.
	p.global_position = spot + Vector3(0, 4.5, 0)
	p.velocity = Vector3.ZERO
	Input.action_press("jump")
	await _game_wait(0.8)
	print("floating ", p.floating, " vy=", p.velocity.y)
	close = _free_cam(p.global_position + Vector3(2.8, 0.6, 3.0), p.global_position + Vector3(0, 1.3, 0), 48.0)
	await _freeze_shot("22_float.png")
	close.queue_free()
	p.camera.current = true
	Input.action_release("jump")
	await _game_wait(1.5)
	# Throw, then let the hen run an errand for loot dropped well away.
	var thrown := p.throw_pet()
	await _game_wait(0.35)
	await _freeze_shot("23_throw.png")
	for i in 80:
		if not thrown.thrown:
			break
		await _game_wait(0.1)
	print("player ", p.global_position)
	print("landed ", not thrown.thrown, " at ", thrown.global_position)
	var loot := WoodLog.new()
	loot.game = Game
	loot.item_id = "egg"
	loot.chunk_color = WoodLog.drop_color("egg")
	main.add_child(loot)
	loot.global_position = p.global_position + Vector3(6.5, 0.5, 0)
	var eggs := Game.count("egg")
	var carried := false
	for i in 200:
		await _game_wait(0.1)
		if is_instance_valid(loot) and loot.carried:
			carried = true
		if Game.count("egg") > eggs:
			break
	print("fetch carried=", carried, " delivered=", Game.count("egg") > eggs)
	# Goat: saddle, bags, and a headbutt into a row of crates and cones.
	goat.befriend(Game)
	goat.hearts = 3
	Game.add_item("saddle", 1)
	Game.add_item("saddle_bags", 1)
	spot.y = 0.0
	spot.x -= 2.0
	p.global_position = spot + Vector3(0, Critter.ground_y(spot.x, spot.z) + 0.1, 0)
	p.velocity = Vector3.ZERO
	goat.global_position = p.global_position
	print("mounted ", p.mount_critter(goat))
	p._model.rotation.y = PI * 0.5
	p._yaw = -PI * 0.5 + 0.9
	p._pitch = -0.28
	p._zoom = 6.5
	var targets: Array = []
	for i in 3:
		var c := PropCrate.new()
		c.game = Game
		main.add_child(c)
		c.global_position = p.global_position + Vector3(4.2, 0.1, (i - 1) * 0.75)
		targets.append(c)
	await _game_wait(0.8)
	close = _free_cam(p.global_position + Vector3(1.3, 1.9, 3.4), p.global_position + Vector3(0.5, 1.0, 0), 45.0)
	await _shot("24_mounted.png")
	close.queue_free()
	p.camera.current = true
	Input.action_press("move_forward")
	p._yaw = -PI * 0.5
	for i in 60:
		await get_tree().physics_frame
		if p.global_position.x > spot.x + 2.4:
			break
	p._yaw = -PI * 0.5
	print("at ", p.global_position, " v ", p.velocity, " crate ", targets[1].global_position)
	print("headbutt ", p.headbutt())
	for i in 40:
		await get_tree().physics_frame
		if targets.any(func(c): return not is_instance_valid(c) or c.is_queued_for_deletion()):
			break
	Input.action_release("move_forward")
	close = _free_cam(p.global_position + Vector3(0.2, 2.4, 4.6), p.global_position + Vector3(1.0, 0.8, 0), 52.0)
	await _game_wait(0.12)
	await _freeze_shot("25_headbutt.png")
	print("crates smashed ", targets.filter(func(c): return not is_instance_valid(c) or c.is_queued_for_deletion()).size())


## First open patch of ground (nothing solid within a 16 x 8 m box) near the farm.
func _clear_spot(p: Player) -> Vector3:
	var box := BoxShape3D.new()
	box.size = Vector3(15.0, 6.0, 7.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.exclude = [p.get_rid()]
	var space := p.get_world_3d().direct_space_state
	for r in range(8, 40, 2):
		for a in 24:
			var at := Vector3(cos(a * TAU / 24.0) * r, 0, sin(a * TAU / 24.0) * r)
			q.transform = Transform3D(Basis.IDENTITY, at + Vector3(3.0, Critter.ground_y(at.x, at.z) + 3.8, 0))
			if absf(Terrain.height_at(at.x, at.z)) < 0.05 and space.intersect_shape(q, 1).is_empty():
				return at
	return Vector3(14, 0, 4)


## Blow the Goat Whistle from across the farm and watch the friends arrive.
func _whistle_shot(p: Player) -> void:
	var hud: Hud = main.get_children().filter(func(n): return n is Hud)[0]
	hud.set_help_visible(false)
	hud._click_hint.modulate.a = 0.0
	Game.time_of_day = 0.45
	var at := _clear_spot(p)
	p.global_position = at + Vector3(3.0, Critter.ground_y(at.x + 3.0, at.z) + 0.1, 0)
	p._yaw = 0.0
	p._pitch = -0.4
	p._zoom = 8.0
	p._pivot.global_position = p.global_position + Vector3(0, 1.4, 0)
	var pets: Array = [main.get_node("Goat")] + range(4).map(func(k): return main.get_node("Chicken_%d" % k))
	for c in pets:
		(c as Critter).befriend(Game)
	Game.add_item("goat_whistle", 1)
	await _wait(10)
	print("answered ", p.whistle())
	await _game_wait(0.5)
	await _freeze_shot("26_whistle.png")
	await _game_wait(5.0)
	for c in pets:
		print("  ", c.name, " dist ", snappedf((c as Critter).global_position.distance_to(p.global_position), 0.1))


## Clears trees around the building plot so the house can be framed.
func _house_site() -> Vector3:
	main.get_children().filter(func(n): return n is Hud)[0].set_help_visible(false)
	var at := Vector3(12, 0, -10)
	for o in main.get_node("Trees").get_children():
		(o as Node3D).visible = (o as Node3D).global_position.distance_to(at) > 12.0
	return at


## What a player could build before the run-31 overhaul: walls only fit in tile centres.
func _house_before(p: Player) -> void:
	var at := _house_site()
	var bw := get_tree().get_first_node_in_group("buildworld") as BuildWorld
	for id in ["wood_floor", "wood_wall", "wood_door", "wood_roof"]:
		Game.add_item(id, 40)
	for cx in 3:
		for cz in 2:
			bw.place("wood_floor", at + Vector3(cx * 2, 0, cz * 2), 0, Game)
			bw.place("wood_roof", at + Vector3(cx * 2, 0, cz * 2), 0, Game)
	for cx in 3:
		bw.place("wood_wall" if cx != 1 else "wood_door", at + Vector3(cx * 2, 0, 2), 0, Game)
		bw.place("wood_wall", at + Vector3(cx * 2, 0, 0), 0, Game)
	bw.place("wood_wall", at + Vector3(0, 0, 2), 1, Game)
	bw.place("wood_wall", at + Vector3(4, 0, 2), 1, Game)
	Game.time_of_day = 0.42
	p.global_position = at + Vector3(2, 0.1, 9)
	_free_cam(at + Vector3(9.0, 5.2, 10.0), at + Vector3(2.0, 1.4, 1.0), 50.0)
	await _wait(60)
	await _shot("b0_house_before.png")


## A two-room cottage with real corners, windows, a swinging door and one shared roof.
func _cottage(bw: BuildWorld, at: Vector3) -> void:
	for id in ["wood_floor", "wood_wall", "wood_door", "wood_roof", "wood_window", "wood_stairs", "wood_table", "wood_chair", "wood_bed", "lantern", "stone_wall", "fence_panel"]:
		Game.add_item(id, 60)
	for cx in 3:
		for cz in 2:
			bw.place("wood_floor", at + Vector3(cx * 2, 0, cz * 2), 0, Game, 0)
		bw.place("wood_wall" if cx == 1 else "wood_window", at + Vector3(cx * 2, 0, -1), 0, Game, 0)
		bw.place("wood_door" if cx == 1 else "wood_window", at + Vector3(cx * 2, 0, 3), 0, Game, 0)
	for cz2 in 2:
		bw.place("wood_wall", at + Vector3(-1, 0, cz2 * 2), 1, Game, 0)
		bw.place("wood_window" if cz2 == 1 else "wood_wall", at + Vector3(5, 0, cz2 * 2), 1, Game, 0)


func _roof_over(bw: BuildWorld, at: Vector3) -> void:
	for cx in 3:
		for cz in 2:
			bw.place("wood_roof", at + Vector3(cx * 2, 0, cz * 2), 1, Game, 1)


func _house_after(p: Player) -> void:
	var at := _house_site()
	var bw := get_tree().get_first_node_in_group("buildworld") as BuildWorld
	_cottage(bw, at)
	await _game_wait(1.2)
	_roof_over(bw, at)
	for x in [0, 2, 4]:
		bw.place("fence_panel", at + Vector3(x - 4.0, 0, 5), 0, Game, 0)
	bw.place("stone_wall", at + Vector3(8, 0, 3), 0, Game, 0)
	bw.place("lantern", at + Vector3(6, 0, 4), 0, Game, 0)
	Game.time_of_day = 0.42
	p.global_position = at + Vector3(8, 0.1, 8)
	var cam := _free_cam(at + Vector3(9.5, 5.0, 10.5), at + Vector3(1.8, 1.3, 1.0), 50.0)
	# Mid-assembly: slow motion while the roof is still flying together.
	Engine.time_scale = 0.12
	await _wait(2)
	for i in 400:
		await get_tree().process_frame
		if i > 4:
			break
	await _freeze_shot("b4_assembling.png")
	await _game_wait(1.5)
	await _shot("b1_cottage.png")
	Game.time_of_day = 0.93
	await _wait(40)
	await _shot("b2_cottage_night.png")
	# Walk up to the door: it swings, and the roof cuts away once inside.
	Game.time_of_day = 0.45
	cam.global_position = at + Vector3(5.0, 3.0, 8.0)
	cam.look_at(at + Vector3(2.0, 1.0, 2.5))
	p.global_position = at + Vector3(2.0, 0.2, 4.1)
	p._model.rotation.y = PI
	await _game_wait(1.2)
	await _shot("b3_door.png")
	cam.current = false
	p.camera.current = true
	bw.place("wood_bed", at + Vector3(0, 0, 0), 0, Game, 0)
	bw.place("wood_table", at + Vector3(4, 0, 0), 0, Game, 0)
	bw.place("wood_chair", at + Vector3(4, 0, 2), 2, Game, 0)
	var bed: BuildPiece = bw.pieces[BuildWorld.key_for("wood_bed", at, 0)]
	print("COMFORT ", bw.comfort_at(bed))
	await _view(p, 0.45, at + Vector3(2.0, 0.25, 1.2), 0.3, -0.62, 6.0, "b5_indoors.png")
	print("HIDDEN ", bw._hidden.size())
	# An upstairs balcony with stairs, and the support-coloured ghost.
	var b2 := at + Vector3(-10, 0, 2)
	bw.place("wood_stairs", b2 + Vector3(0, 0, -2), 0, Game, 0)
	for x2 in [0, 2]:
		bw.place("wood_wall", b2 + Vector3(x2, 0, 1), 0, Game, 0)
		bw.place("wood_floor", b2 + Vector3(x2, 0, 0), 0, Game, 1)
		bw.place("wood_floor", b2 + Vector3(x2, 0, 2), 0, Game, 1)
		bw.place("wood_window", b2 + Vector3(x2, 0, 3), 0, Game, 1)
	bw.place("wood_wall", b2 + Vector3(3, 0, 0), 1, Game, 1)
	bw.place("fence_panel", b2 + Vector3(-1, 0, 0), 1, Game, 1)
	Game.set_tool(GameState.Tool.BUILD)
	bw.piece_id = "wood_floor"
	p.global_position = b2 + Vector3(2.0, 2.5, 0.2)
	p._model.rotation.y = PI * 0.5
	cam.current = true
	cam.global_position = b2 + Vector3(9.0, 5.6, -7.0)
	cam.look_at(b2 + Vector3(1.0, 1.8, 0.5))
	await _game_wait(1.5)
	print("GHOST support=", bw._ghost_support, " level=", bw._ghost_level, " ok=", bw._ghost_ok, " py=", p.global_position.y)
	await _shot("b6_upstairs_ghost.png")
	# Pull out both supporting walls: the whole balcony comes down.
	Game.set_tool(GameState.Tool.HOE)
	p.global_position = b2 + Vector3(7, 0.2, -3)
	bw.demolish(BuildWorld.key_for("wood_wall", b2 + Vector3(0, 0, 1), 0, 0), Game)
	await _game_wait(0.8)
	bw.demolish(BuildWorld.key_for("wood_wall", b2 + Vector3(2, 0, 1), 0, 0), Game)
	Engine.time_scale = 1.0
	await _game_wait(0.55)
	await _freeze_shot("b7_collapse.png")
	await _game_wait(4.5)
	await _shot("b8_rubble_bundles.png")
	print("PICKUPS ", get_tree().get_nodes_in_group("pickup").size(), " debris ", get_tree().get_nodes_in_group("build_debris").size())


func _walk(p: Player, secs: float) -> void:
	Input.action_press("move_forward")
	var t := 0.0
	while t < secs:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	Input.action_release("move_forward")
	await _game_wait(0.3)


## Real player, real input: through the swinging door, up the stairs, and a placement via use().
func _house_walk(p: Player) -> void:
	var at := _house_site()
	var bw := get_tree().get_first_node_in_group("buildworld") as BuildWorld
	_cottage(bw, at)
	_roof_over(bw, at)
	Game.time_of_day = 0.45
	await _game_wait(1.0)
	p.global_position = at + Vector3(2.0, 0.2, 6.0)
	p._yaw = 0.0   # forward is -Z, into the house
	await _game_wait(0.5)
	await _walk(p, 1.5)
	var door: BuildPiece = bw.pieces[BuildWorld.key_for("wood_door", at + Vector3(2, 0, 3), 0)]
	print("WALKED_IN z=", p.global_position.z - at.z, " covered=", bw.is_covered(p.global_position), " door_angle=", door.find_children("*", "DoorLeaf", true, false)[0].angle)
	var s0 := at + Vector3(-8, 0, 0)
	bw.place("wood_stairs", s0, 0, Game, 0)
	bw.place("wood_wall", s0 + Vector3(0, 0, 3), 0, Game, 0)
	bw.place("wood_floor", s0 + Vector3(0, 0, 2), 0, Game, 1)
	await _game_wait(1.0)
	p.global_position = s0 + Vector3(0, 0.2, -2.4)
	p._yaw = PI    # forward is +Z, up the stairs
	await _game_wait(0.4)
	await _walk(p, 1.5)
	print("CLIMBED y=", p.global_position.y, " z=", p.global_position.z - s0.z)
	await _walk(p, 0.45)
	print("TOP y=", p.global_position.y, " z=", p.global_position.z - s0.z)
	Game.set_tool(GameState.Tool.BUILD)
	bw.piece_id = "fence_panel"
	p.global_position = at + Vector3(-4, 0.2, 8)
	p._model.rotation.y = 0.0
	await _game_wait(0.8)
	var n := Game.built.size()
	var anim := bw.use(p)
	await _game_wait(0.8)
	print("USE placed=", Game.built.size() - n, " anim=", anim, " entry=", Game.built[-1])
	n = Game.built.size()
	await _game_wait(0.2)
	bw.use(p)
	await _game_wait(0.3)
	print("USE demolished=", n - Game.built.size())
