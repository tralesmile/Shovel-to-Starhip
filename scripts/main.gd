extends Node3D
## Builds the Phase 0 test map: Bumpkin Bay farm, store, sell bin, trees,
## and a very closed spaceport. Placeholder art; real models come in Phase 1.

var player: Player
var sun: DirectionalLight3D
var env: Environment
var _clouds: Array[Node3D] = []
var _sky_mat: ShaderMaterial
var _lamps: Array[OmniLight3D] = []
var _lamp_mat: ShaderMaterial
var _fireflies: Array[CPUParticles3D] = []
var _rain: CPUParticles3D
var _bolt_timer := -1.0      ## seconds to next strike (storms only)
var _bolt_age := 99.0        ## seconds since the last strike flash
var _thunder_in := -1.0      ## countdown to the rumble
var _bolt_dist := 0.0
var _rain_level := 0.0   ## eased 0..1 so rain fades in/out
var _day_critters: Array[Node3D] = []
var goose: Goose
var _npcs: Array[Npc] = []
var _water_mat: ShaderMaterial
var _police: Police
var _police_car: PoliceCar
var space: SpaceProgram

const TREE_SPOTS := [
	Vector3(-8, 0, -9), Vector3(-4, 0, -11), Vector3(2, 0, -10), Vector3(7, 0, -9),
	Vector3(11, 0, -4), Vector3(-17, 0, -10), Vector3(-36, 0, 8), Vector3(-17, 0, 9),
	Vector3(9, 0, -14), Vector3(-1, 0, -16), Vector3(-12, 0, -15), Vector3(3, 0, -19),
	Vector3(24, 0, 2), Vector3(-37, 0, -6),
]


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_farm()
	_build_house()
	_build_store()
	_build_sell_bin()
	_build_workbench()
	_build_fence()
	_build_fishing_spot()
	_build_delivery_depot()
	_build_car_dealer()
	_build_police()
	_build_police_car()
	_build_trees()
	_build_rocks()
	_build_mine()
	_build_crates()
	_build_street_props()
	add_child(BuildWorld.new())
	var bug_life := BugLife.new()
	bug_life.name = "BugLife"
	bug_life.game = Game
	add_child(bug_life)
	_build_road_and_signs()
	_build_interiors()
	_build_spaceport()
	_build_scenery()
	_build_flowers()
	_build_critters()
	_build_lamps()
	_build_bounds()
	Graphics.apply_high(env, sun)
	_mirror_signs()

	player = Player.new()
	player.name = "Player"
	player.position = Vector3(0, 0.5, 8)
	add_child(player)

	var sfx := Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)

	var music := Music.new()
	music.name = "Music"
	add_child(music)

	var menu := SettingsMenu.new()
	menu.name = "SettingsMenu"
	add_child(menu)

	var hud := Hud.new()
	hud.player = player
	add_child(hud)

	space = SpaceProgram.new()
	space.name = "SpaceProgram"
	space.player = player
	space.hud_layer = hud
	space.rocket = get_node("Spaceport/GranRocket")
	add_child(space)
	(get_node("Spaceport/LaunchConsole") as LaunchConsole).program = space

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			var director: Node = load("res://tests/screenshot_director.gd").new()
			director.set("out_dir", arg.trim_prefix("--shots="))
			add_child(director)
			return

	var loaded := Game.load_game()
	_spawn_player_car()
	if OS.get_cmdline_user_args().has("--launch-ready"):
		_playtest_launch_ready()
	if OS.get_cmdline_user_args().has("--goose"):
		_playtest_goose()
	if loaded:
		hud.set_help_visible(false)
		Game.say("Welcome back to Bumpkin Bay! Day %d." % Game.day)
	else:
		Game.say("Welcome to Bumpkin Bay! Press H for help.")
		var prompts := InputPrompts.new()
		prompts.name = "InputPrompts"
		add_child(prompts)
		var tut := Tutorial.new()
		tut.name = "Tutorial"
		add_child(tut)
	if not MainMenu.consume_skip():
		var title_menu := MainMenu.new()
		title_menu.name = "MainMenu"
		title_menu.has_save = loaded
		title_menu.new_game_requested.connect(Game.delete_save)
		add_child(title_menu)


## Playtest shortcut (run with  -- --launch-ready): Gran's story finished, spare parts in your
## pockets and you standing by the launch console. It changes the save it is used on.
func _playtest_launch_ready() -> void:
	Game.story_act = Story.act_count()
	Game.story_advanced.emit(Game.story_act)
	for spec in [["plank", 12], ["copper_ingot", 10], ["turnip", 12], ["gem", 2], ["polished_gem", 2], ["rocket_plate", 2], ["copper_pickaxe", 1]]:
		Game.add_item(spec[0], spec[1])
	player.position = (get_node("Spaceport/LaunchConsole") as Node3D).global_position + Vector3(-1.2, 0.5, 1.8)
	Game.say("Playtest: the Starship is ready. Use the launch console.")


## Playtest shortcut (run with  -- --goose): ripe crops, a scarecrow to place and Lady
## Honksworth on her way. It changes the save it is used on.
func _playtest_goose() -> void:
	for i in [0, 5, 6, 10]:
		var plot := get_node("Farm/Plot_%02d" % i) as FarmPlot
		plot.from_dict({"state": FarmPlot.State.PLANTED, "crop": "carrot", "growth": 9})
	Game.add_item("scarecrow", 2)
	player.position = Vector3(0, 0.5, 9.0)
	get_tree().create_timer(6.0).timeout.connect(func(): goose.visit(Game))


var _creak_t := 0.0
var _creak_n := 0
var _bark_t := 0.0
var _bark_n := 0
var _bark_last := ""


func _process(delta: float) -> void:
	for c in _clouds:
		c.position.x += delta * 0.8
		if c.position.x > 110.0:
			c.position.x = -110.0
	_update_daylight()
	if space != null:
		space.apply_environment(env, sun, _sky_mat)
		if space.away():
			_rain.emitting = false
			_rain.visible = false
			_thunder_in = -1.0
	for n in _npcs:
		n.update_routine(Game.time_of_day, delta)
	_update_witnesses(delta)
	_update_barks(delta)
	var busted := false
	var off_world := space != null and space.away()
	if not off_world and _police and _police.update_police(delta, player.global_position, Game.heat, player.crouching, Game.time_of_day, player.in_cover):
		busted = true
	if not off_world and _police_car and _police_car.update_chase(delta, player.global_position, Game.heat, player.vehicle != null):
		busted = true
		Game.say("Squad car: \"Pull over! Your tyres look suspiciously stolen!\"")
	var chased: bool = _police != null and _police.state == Police.State.CHASE
	var unseen := not chased and not (_police_car != null and _police_car.active) \
		and not (_police != null and _police.sees_player(player.global_position, player.crouching, Game.time_of_day, player.in_cover))
	if Game.in_closet and not _near_closet():
		Game.in_closet = false
	var ck := Closet.creak_tick(_creak_t, delta, Game.in_closet)
	_creak_t = ck["timer"]
	if ck["creak"]:
		_creak_n += 1
		Game.say(Closet.creak_line(_creak_n))
	player.set_model_shown(Closet.model_visible(Game.in_closet, player.vehicle != null) and not (space != null and space.flying()))
	Game.cool_heat(delta, Police.is_hidden(player.global_position), chased, unseen, player.crouching, Game.in_closet)
	if busted:
		player.exit_car()
		var r := Game.arrest()
		player.global_position = Vector3(0, 2, 8)
		Game.say("Busted! Fined $%d and %d stolen item(s) confiscated. Heat: %s" % [r["fine"], r["loot"], Game.heat_name()])


## Watchers fill a suspicion meter while the player picks a lock in their view.
func _update_witnesses(delta: float) -> void:
	var crime := false
	for c in get_tree().get_nodes_in_group("lootbox"):
		if c.state == "picking":
			crime = true
	Game.crime_suspicion = 0.0
	var sneaking: bool = crime or player.crouching
	for n in _npcs:
		var seen := crime and n.can_witness() and Witness.can_see(n.global_position, n.rotation.y, player.global_position)
		var d := n.global_position.distance_to(player.global_position)
		if n.witness.update(delta, seen, d, player.crouching):
			n.raise_alarm()
			Sfx.play_on(player, "squeak", 0.45)
			Game.shake.emit(0.3)
			Game.add_heat(1.0)
			Game.say("%s: \"HEY! Is that MY spoon?!\"  Heat: %s" % [n.npc_name, Game.heat_name()])
		Game.crime_suspicion = maxf(Game.crime_suspicion, n.witness.suspicion)
		n.show_awareness(delta, sneaking, player.global_position)


## Sun, moon, sky colours, lamps and fireflies follow the clock.
func _update_daylight() -> void:
	var angle := (Game.time_of_day - 0.25) * TAU     # 0 = sunrise, PI/2 = noon
	var sun_dir := Vector3(cos(angle), sin(angle), -0.35).normalized()
	var elev := sun_dir.y
	var day: float = smoothstep(0.08, 0.35, elev)
	var night: float = 1.0 - smoothstep(-0.22, 0.0, elev)
	var sunset: float = clamp(1.0 - day - night, 0.0, 1.0)
	_sky_mat.set_shader_parameter("sun_dir", sun_dir)
	_sky_mat.set_shader_parameter("day", day)
	_sky_mat.set_shader_parameter("sunset", sunset)
	_sky_mat.set_shader_parameter("night", night)
	# The light comes from the sun by day and the moon by night (kept above the horizon for shadows).
	var src := sun_dir if elev > -0.05 else -sun_dir
	src.y = max(src.y, 0.32)
	src = src.normalized()
	sun.global_transform = Transform3D(Basis.looking_at(-src, Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(1, 0.97, 0.92) * day + Color(1.0, 0.62, 0.38) * sunset + Color(0.55, 0.65, 1.0) * night
	sun.light_energy = 0.95 * day + 0.7 * sunset + 0.28 * night
	env.ambient_light_color = Color(0.75, 0.8, 0.95) * day + Color(0.8, 0.6, 0.6) * sunset + Color(0.3, 0.36, 0.6) * night
	env.ambient_light_energy = 0.45 * day + 0.4 * sunset + 0.32 * night
	env.fog_light_color = Color(0.72, 0.82, 0.93) * day + Color(0.95, 0.65, 0.5) * sunset + Color(0.07, 0.09, 0.18) * night
	var grade := FX.grade_for(day, sunset, night)
	RoomDressing.update_light(day, sunset, night)
	env.adjustment_enabled = true
	env.adjustment_saturation = grade["saturation"]
	env.adjustment_contrast = grade["contrast"]
	env.adjustment_brightness = grade["brightness"]
	var dark: float = night + sunset * 0.5
	for l in _lamps:
		l.visible = dark > 0.3
		l.light_energy = 4.5 * dark
	_lamp_mat.set_shader_parameter("emission_energy", 2.5 * dark)
	for lt in get_tree().get_nodes_in_group("lantern"):
		lt.visible = dark > 0.3
		lt.light_energy = 3.2 * dark
	_update_weather(day, sunset, night)
	var underground := player != null and MineCave.inside(player.global_position)
	if underground:
		MineCave.apply_light(env, sun)
	if player != null:
		player.set_helmet(Game.count("miner_helmet") > 0, underground or dark > 0.35)
	Toon.set_night(dark)
	BuildKit.set_night(dark)
	for c in get_tree().get_nodes_in_group("car"):
		if c.has_method("set_dark"):
			c.set_dark(dark)
	for f in _fireflies:
		f.emitting = night > 0.5
	for c in _day_critters:
		c.visible = day + sunset > 0.4


func _update_weather(day: float, sunset: float, night: float) -> void:
	var w := Game.weather()
	var want := Weather.gloom(w)
	_rain_level = lerpf(_rain_level, want, 0.02)
	_sky_mat.set_shader_parameter("overcast", _rain_level)
	env.fog_density = Weather.fog_density(w, 0.0035) if _rain_level >= want else 0.0035 * (1.0 + 2.2 * _rain_level)
	# Grey the light and colours when it rains.
	sun.light_energy *= 1.0 - 0.45 * _rain_level
	env.adjustment_saturation = lerpf(env.adjustment_saturation, 0.78, _rain_level * 0.8)
	env.fog_light_color = env.fog_light_color.lerp(Color(0.5, 0.54, 0.6) * (1.0 - night * 0.8), _rain_level * 0.7)
	if _rain == null:
		_rain = Weather.make_rain()
		add_child(_rain)
	_update_lightning(w, get_process_delta_time())
	var indoors := player != null and Police.is_hidden(player.global_position)
	_rain.emitting = _rain_level > 0.05 and not indoors
	_rain.visible = not indoors
	var n := Weather.drops(w)
	if n > 0 and _rain.amount != n:
		_rain.amount = n
	if player != null and player.camera != null:
		_rain.global_position = player.global_position + Vector3(0, 10, 0)


## Storm lightning: sky flash + brief light surge, then the rumble arrives later (farther bolt = longer wait).
func _update_lightning(w: String, delta: float) -> void:
	if w == Weather.STORM and _rain_level > 0.6:
		if _bolt_timer < 0.0:
			_bolt_timer = Weather.lightning_gap(w, randf())
		_bolt_timer -= delta
		if _bolt_timer <= 0.0:
			_bolt_timer = -1.0
			_bolt_age = 0.0
			_bolt_dist = randf_range(30.0, 320.0)
			_thunder_in = Weather.thunder_delay(_bolt_dist)
	else:
		_bolt_timer = -1.0
	_bolt_age += delta
	var f := Weather.flash_level(_bolt_age)
	_sky_mat.set_shader_parameter("flash", f)
	if f > 0.0:
		sun.light_energy += 2.6 * f
		env.ambient_light_energy += 1.8 * f
	if _thunder_in >= 0.0:
		_thunder_in -= delta
		if _thunder_in < 0.0 and player != null:
			Sfx.play_on(player, "thunder", randf_range(0.85, 1.1))
			Game.shake.emit(clampf(1.0 - _bolt_dist / 360.0, 0.05, 0.6) * 0.5)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://scripts/shaders/sky.gdshader")
	sky.sky_material = _sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.82, 0.93)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	env.glow_enabled = false
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 1.5
	add_child(sun)


func _build_ground() -> void:
	add_child(Terrain.new())
	var water := MeshInstance3D.new()
	water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(Terrain.SIZE, Terrain.SIZE)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	water.mesh = plane
	var wm := ShaderMaterial.new()
	wm.shader = load("res://scripts/shaders/water.gdshader")
	wm.set_shader_parameter("shore_tex", ImageTexture.create_from_image(Terrain.shore_map(256)))
	wm.set_shader_parameter("world_size", Terrain.SIZE)
	_water_mat = wm
	water.material_override = wm
	water.position.y = Terrain.WATER_LEVEL
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# Reeds and lily pads around the pond.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for k in 10:
		var a := rng.randf() * TAU
		var r := Terrain.POND_RADIUS + rng.randf_range(-0.5, 1.5)
		var p := Vector3(Terrain.POND_CENTER.x + cos(a) * r, 0, Terrain.POND_CENTER.y + sin(a) * r)
		p.y = Terrain.height_at(p.x, p.z)
		Models.put(self, Models.MED + "waterplant_A.gltf", p, rng.randf_range(4.0, 6.0), rng.randf() * TAU)
	Models.solid(self, Models.MED + "bucket_empty.gltf", Vector3(Terrain.POND_CENTER.x + 6.5, 0, Terrain.POND_CENTER.y + 5.0), 4.0)
	var sign := Art.label("POND\n(no swimming, the fish are shy)", 44, Color(0.85, 0.95, 1))
	sign.position = Vector3(Terrain.POND_CENTER.x + 7.5, 1.6, Terrain.POND_CENTER.y + 4.5)
	add_child(sign)


func _build_farm() -> void:
	var farm := Node3D.new()
	farm.name = "Farm"
	add_child(farm)
	var i := 0
	for x in [-3, -1, 1, 3]:
		for z in [-3, -1, 1, 3]:
			var plot := FarmPlot.new()
			plot.name = "Plot_%02d" % i
			plot.position = Vector3(x, 0, z)
			farm.add_child(plot)
			i += 1
	var field := FarmField.new()
	for k in i:
		field.plots.append(farm.get_node("Plot_%02d" % k))
	farm.add_child(field)
	goose = Goose.new()
	add_child(goose)
	# Wooden fence around the field, with a gap on the south side.
	var fence := Models.MED + "fence_wood_straight.gltf"
	for k in 5:
		var t := -3.84 + k * 1.92
		Models.solid(farm, fence, Vector3(-4.8, 0, t), 1.8)
		Models.solid(farm, fence, Vector3(4.8, 0, t), 1.8)
		Models.solid(farm, fence, Vector3(t, 0, -4.8), 1.8, PI / 2)
		if k != 2:
			Models.solid(farm, fence, Vector3(t, 0, 4.8), 1.8, PI / 2)
	var sign := Art.label("YOUR FARM\n(it's a start)", 56, Color(1, 0.95, 0.7))
	sign.position = Vector3(0, 1.6, 5.3)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	farm.add_child(sign)
	Models.put(farm, Models.MED + "flag_red.gltf", Vector3(-1.2, 0.0, 5.0), 4.0)
	Models.put(farm, Models.MED + "flag_red.gltf", Vector3(1.2, 0.0, 5.0), 4.0)


func _build_house() -> void:
	var house := Node3D.new()
	house.name = "House"
	house.position = Vector3(-13, 0, -2)
	add_child(house)
	Models.solid(house, Models.MED + "building_home_B_red.gltf", Vector3.ZERO, 5.0, 0.0, 0.8)
	Models.solid(self, Models.MED + "building_windmill_red.gltf", Vector3(-23, 0, -11), 6.0, 0.4, 0.6)
	Models.solid(self, Models.MED + "building_well_red.gltf", Vector3(-7, 0, -7.5), 3.2, 0.3, 0.6)
	# Farm clutter, because every farm has a pile of stuff.
	Models.solid(house, Models.MED + "barrel.gltf", Vector3(3.4, 0, 1.2), 4.5)
	Models.solid(house, Models.MED + "barrel.gltf", Vector3(3.9, 0, 0.2), 4.5)
	Models.solid(house, Models.MED + "crate_A_big.gltf", Vector3(-3.4, 0, 1.6), 4.5, 0.3)
	Models.solid(house, Models.MED + "crate_B_small.gltf", Vector3(-3.2, 0.95, 1.6), 4.5, 0.8)
	Models.put(house, Models.MED + "sack.gltf", Vector3(-2.6, 0, 2.6), 4.5, 0.4)
	Models.solid(house, Models.MED + "wheelbarrow.gltf", Vector3(5.5, 0, 3.0), 4.5, 2.2)
	Models.solid(self, Models.MED + "resource_lumber.gltf", Vector3(-8, 0, -12), 4.5, 0.2)
	for bx in [-2.0, 2.0]:
		Models.put(house, Models.CITY + "bush.gltf", Vector3(bx, 0, 2.8), 3.0)


func _build_store() -> void:
	var store := Node3D.new()
	store.name = "Store"
	store.position = Vector3(14, 0, 4)
	add_child(store)
	Models.solid(store, Models.MED + "building_market_red.gltf", Vector3.ZERO, 5.0, 0.0, 0.85)
	var sign := Art.label("GENERAL STORE\nseeds · snacks · questionable advice", 60, Color(1, 1, 0.8))
	sign.position = Vector3(0, 6.2, 3.6)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	store.add_child(sign)


## Interiors for the player house, the store and three town homes, plus NPCs
## with daily routines. Interiors live far away; doors teleport the player.
func _build_interiors() -> void:
	var interiors := Node3D.new()
	interiors.name = "Interiors"
	add_child(interiors)
	# 0: player house (the bed finally moved indoors)
	var house := get_node("House") as Node3D
	var out0 := house.global_position + Vector3(0, 0.1, 4.2)
	var in0 := Buildings.build_interior(interiors, 0, out0, Art.WALL, "HOME SWEET HOME\n(rent: free, quality: also free)")
	Buildings.add_front_door(house, Vector3(0, 0, 2.7), in0["entry"], "Enter your house")
	var bed := Station.new()
	bed.name = "Bed"
	bed.kind = Station.Kind.BED
	bed.position = Vector3(-2.4, 0, -1.6)
	bed.interact_radius = 1.6
	in0["root"].add_child(bed)
	Buildings.solid_box(bed, Vector3(1.2, 0.4, 2.1), Vector3(0, 0.2, 0), Art.WOOD)
	Buildings.solid_box(bed, Vector3(1.3, 0.9, 0.12), Vector3(0, 0.45, -1.05), Art.WOOD.darkened(0.15))
	var sheet := Art.box(Vector3(1.1, 0.15, 1.5), Color(0.35, 0.55, 0.85))
	sheet.position = Vector3(0, 0.47, 0.25)
	bed.add_child(sheet)
	var pillow := Art.box(Vector3(0.9, 0.18, 0.4), Color(0.97, 0.95, 0.9))
	pillow.position = Vector3(0, 0.48, -0.72)
	bed.add_child(pillow)
	# 1: general store
	var store := get_node("Store") as Node3D
	var out1 := store.global_position + Vector3(-2.5, 0.1, 5.2)
	var in1 := Buildings.build_interior(interiors, 1, out1, Color(0.9, 0.78, 0.6), "GENERAL STORE\nseeds, snacks, questionable advice")
	Buildings.add_front_door(store, Vector3(-2.5, 0, 3.3), in1["entry"], "Enter the store")
	var counter := Station.new()
	counter.name = "ShopCounter"
	counter.kind = Station.Kind.SHOP
	counter.position = Vector3(0, 0, -0.2)
	counter.interact_radius = 1.9
	in1["root"].add_child(counter)
	Models.solid(counter, Models.FOOD + "crate_onions.gltf", Vector3(-1.3, 0, 0), 0.55)
	Models.solid(counter, Models.FOOD + "crate_carrots.gltf", Vector3(0, 0, 0), 0.55)
	Models.solid(counter, Models.FOOD + "crate_tomatoes.gltf", Vector3(1.3, 0, 0), 0.55)
	var keeper := Models.put(in1["root"], Models.CHAR + "Mage.glb", Vector3(0, 0, -1.6), 0.72, 0.0)
	var ap: AnimationPlayer = keeper.find_children("*", "AnimationPlayer", true, false)[0]
	Models.set_loops(ap, ["Idle"])
	ap.play("Idle")
	for n in ["Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff"]:
		var node := keeper.find_child(n, true, false)
		if node:
			node.visible = false
	# 2-4: town homes across the road, each with a resident on a daily routine.
	var town := get_node("Town") as Node3D
	var homes := [
		{"x": -36.0, "color": Color(0.85, 0.9, 0.95), "model": "Rogue.glb", "work": Vector3(11, 0, 9), "shift": 0.0, "name": "Pip"},
		{"x": -25.5, "color": Color(0.95, 0.85, 0.85), "model": "Knight.glb", "work": Vector3(-10, 0, 20), "shift": 0.5, "name": "Dame Gertrude"},
		{"x": -15.0, "color": Color(0.88, 0.95, 0.85), "model": "Barbarian.glb", "work": Vector3(-18, 0, 3), "shift": -0.5, "name": "Bork"},
	]
	for i in homes.size():
		var h: Dictionary = homes[i]
		var outside := Vector3(h["x"], 0.1, 22.8)
		var inside := Buildings.build_interior(interiors, 2 + i, outside, h["color"], "%s's place" % h["name"])
		Buildings.add_front_door(town, Vector3(h["x"], 0, 24.4), inside["entry"], "Enter %s's home" % h["name"])
		var drawer := LootContainer.new()
		drawer.name = "Drawer_%d" % i
		drawer.position = Vector3(-3.0, 0, -1.8)
		drawer.difficulty = float(i)
		drawer.seed_value = 100 + i
		drawer.loot_id = LootContainer.roll_loot(0.15 + 0.3 * i)
		drawer.interact_radius = 1.5
		inside["root"].add_child(drawer)
		var dresser_body := Buildings.solid_box(drawer, Vector3(1.0, 0.9, 0.5), Vector3(0, 0.45, 0), Art.WOOD.darkened(0.2))
		dresser_body.get_child(0).visible = false   # the DresserModel is the visible part
		drawer.dresser = DresserModel.new()
		drawer.add_child(drawer.dresser)
		var closet := Closet.new()
		closet.name = "Closet_%d" % i
		closet.position = Vector3(3.0, 0, -1.8)
		closet.interact_radius = 1.5
		inside["root"].add_child(closet)
		Buildings.solid_box(closet, Vector3(1.0, 2.0, 0.6), Vector3(0, 1.0, 0), Art.WOOD.lightened(0.1))
		var npc := Npc.new()
		npc.name = "Npc_%d" % i
		add_child(npc)
		npc.setup(Models.CHAR + h["model"])
		npc.home_spot = interior_pos(2 + i, Vector3(1.8, 0, -1.2))
		npc.work_spot = h["work"]
		npc.door_outside = outside
		npc.wake_shift = h["shift"]
		npc.npc_name = h["name"]
		npc.guard_spot = drawer.global_position
		npc.gaze_seed = i * 3 + 1
		npc.room = Buildings.room_rect(2 + i)
		npc.global_position = npc.home_spot
		_npcs.append(npc)


func _near_closet() -> bool:
	for c in get_tree().get_nodes_in_group("closet"):
		if not Closet.out_of_reach(player.global_position, (c as Node3D).global_position):
			return true
	return false


func _build_police_car() -> void:
	_police_car = PoliceCar.new()
	_police_car.name = "SquadCar"
	add_child(_police_car)
	_police_car.setup()


func _build_police() -> void:
	_police = Police.new()
	_police.name = "ConstableBumble"
	add_child(_police)
	_police.setup()
	_police.spotted.connect(func(): Game.say("Constable Bumble: \"STOP! In the name of the turnip!\""))
	_police.gave_up.connect(func(): Game.say(Police.give_up_line(randi())))
	_police.waypoints = [Vector3(-30, 0, 18), Vector3(-10, 0, 18), Vector3(-10, 0, 8), Vector3(-30, 0, 8)]


func interior_pos(index: int, local: Vector3) -> Vector3:
	return Buildings.interior_origin(index) + local


func _build_car_dealer() -> void:
	var dealer := Station.new()
	dealer.name = "CarDealer"
	dealer.kind = Station.Kind.CAR_DEALER
	dealer.position = Vector3(14, 0, 10.5)
	dealer.interact_radius = 2.4
	add_child(dealer)
	dealer.car_bought.connect(_spawn_player_car)
	Models.solid(dealer, Models.CITY + "car_hatchback.gltf", Vector3(0, 0, 0), 4.4, 0.4)
	var post := Art.box(Vector3(0.15, 2.4, 0.15), Art.WOOD)
	post.position = Vector3(-2.2, 1.2, 0)
	dealer.add_child(post)
	var l := Art.label("HONEST HANK'S CARS\nonly one previous owner", 56, Color(1, 0.95, 0.6))
	l.position = Vector3(-2.2, 3.0, 0)
	dealer.add_child(l)
	var hank := Models.put(dealer, Models.CHAR + "Rogue.glb", Vector3(-1.2, 0, 1.4), 0.72, PI)
	var found := hank.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		Models.set_loops(found[0], ["Idle"])
		found[0].play("Idle")


## Spawns (or re-spawns after load) the owned car where it was last parked.
func _spawn_player_car() -> void:
	if not Game.car_owned:
		return
	var existing := get_tree().get_first_node_in_group("car")
	if existing:
		existing.queue_free()
	var car := Car.new()
	car.name = "PlayerCar"
	car.position = Vector3(Game.car_pos[0], 0.1, Game.car_pos[2])
	car.heading = float(Game.car_pos[3])
	car.rotation.y = car.heading
	add_child(car)
	car.setup()
	car.set_parts(Game.car_parts)
	car.damage = Game.car_damage


func _build_workbench() -> void:
	var wb := Station.new()
	wb.name = "Workbench"
	wb.kind = Station.Kind.WORKBENCH
	wb.position = Vector3(4.4, 0, 6.2)
	wb.interact_radius = 1.8
	add_child(wb)
	Models.solid(wb, Models.MED + "crate_B_small.gltf", Vector3.ZERO, 5.0)
	var lamp := OmniLight3D.new()   # warm workshop glow
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.light_energy = 1.2
	lamp.omni_range = 5.0
	lamp.position = Vector3(0, 1.8, 0)
	wb.add_child(lamp)
	var embers := FX.emitter(wb, Color(1.0, 0.65, 0.2), 4, 2.0, 0.05, Vector3(0.3, 0.1, 0.3), Vector3(0, 0.5, 0), true, "sphere")
	embers.position.y = 1.0
	var l := Art.label("WORKBENCH\ncraft stuff", 44, Color(1, 0.9, 0.7))
	l.position.y = 2.2
	wb.add_child(l)


func _build_sell_bin() -> void:
	var bin := Station.new()
	bin.name = "SellBin"
	bin.kind = Station.Kind.SELL_BIN
	bin.position = Vector3(6.4, 0, 6.2)
	bin.interact_radius = 1.6
	add_child(bin)
	Models.solid(bin, Models.MED + "crate_A_big.gltf", Vector3.ZERO, 5.0)
	Models.put(bin, Models.MED + "flag_red.gltf", Vector3(0.6, 1.0, 0.0), 4.0)
	var l := Art.label("SELL BIN\nturnips & wood", 44, Color(1, 0.9, 0.9))
	l.position.y = 2.2
	bin.add_child(l)


## Shady Sal lurks behind the town homes, fittingly next to a lamp that is "broken".
## Little jetty spot on the pond's east shore.
func _build_fishing_spot() -> void:
	var spot := FishingSpot.new()
	spot.name = "FishingSpot"
	spot.position = Vector3(-17.8, 0, 1.0)
	spot.position.y = Terrain.height_at(spot.position.x, spot.position.z)
	spot.interact_radius = 2.2
	var pond := PondLife.new()
	pond.name = "PondLife"
	pond.water_mat = _water_mat
	pond.game = Game
	add_child(pond)
	spot.pond = pond
	add_child(spot)
	var l := Art.label("FISHING\n(bring patience)", 40, Color(0.7, 0.9, 1.0))
	l.position.y = 1.8
	spot.add_child(l)


func _build_delivery_depot() -> void:
	var depot := DeliveryDepot.new()
	depot.name = "DeliveryDepot"
	depot.position = Vector3(19.0, 0, 10.5)
	depot.position.y = Terrain.height_at(depot.position.x, depot.position.z)
	depot.interact_radius = 1.8
	add_child(depot)
	Models.solid(depot, Models.MED + "crate_A_big.gltf", Vector3(0.9, 0, 0), 4.0)
	var m := Models.put(depot, Models.CHAR + "Rogue.glb", Vector3.ZERO, 0.72, PI)
	var l := Art.label("PARCEL PETE\nfast-ish delivery", 44, Color(1.0, 0.9, 0.6))
	l.position.y = 2.4
	depot.add_child(l)


func _build_fence() -> void:
	var fence := Station.new()
	fence.name = "Fence"
	fence.kind = Station.Kind.FENCE
	fence.position = Vector3(-44.0, 0, 28.0)
	fence.interact_radius = 1.8
	add_child(fence)
	Models.solid(fence, Models.MED + "crate_A_big.gltf", Vector3(0.9, 0, 0), 4.0)
	var m := Models.put(fence, Models.CHAR + "Rogue.glb", Vector3.ZERO, 0.72, PI)
	var l := Art.label("SHADY SAL\nno questions", 44, Color(0.8, 1.0, 0.8))
	l.position.y = 2.4
	fence.add_child(l)


const ROCK_SPOTS := [Vector3(-8, 0, -14), Vector3(-11.5, 0, -12), Vector3(9, 0, -16), Vector3(12, 0, -13.5), Vector3(-3, 0, -19)]


func _build_rocks() -> void:
	var rocks := Node3D.new()
	rocks.name = "Rocks"
	add_child(rocks)
	for i in ROCK_SPOTS.size():
		var r := MineRock.new()
		r.name = "Rock_%02d" % i
		r.position = ROCK_SPOTS[i]
		r.position.y = Terrain.height_at(r.position.x, r.position.z)
		rocks.add_child(r)


## Gran's Old Mine: surface entrance plus the cave itself.
func _build_mine() -> void:
	var mine := MineCave.new()
	mine.name = "Mine"
	add_child(mine)
	mine.build(self)


const CRATE_SPOTS := [Vector3(4, 0, -6), Vector3(5.2, 0, -6.4), Vector3(-6, 0, 9), Vector3(11, 0, 4), Vector3(-13, 0, -4), Vector3(2.5, 0, 12)]


## Shove-able, smashable props scattered around the farm (physics fun + plank source).
func _build_crates() -> void:
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	for i in CRATE_SPOTS.size():
		var c := PropCrate.new()
		c.name = "Crate_%02d" % i
		c.kind = "barrel" if i % 3 == 2 else "crate"
		c.game = Game
		props.add_child(c)
		c.position = CRATE_SPOTS[i] + Vector3(0, Terrain.height_at(CRATE_SPOTS[i].x, CRATE_SPOTS[i].z) + 0.05, 0)


func _build_trees() -> void:
	var trees := Node3D.new()
	trees.name = "Trees"
	add_child(trees)
	for i in TREE_SPOTS.size():
		var t := ChoppableTree.new()
		t.name = "Tree_%02d" % i
		t.position = TREE_SPOTS[i]
		trees.add_child(t)
	# Background forest clumps (not choppable, they're shy).
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k in 26:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(42.0, 70.0)
		var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
		if pos.z > 10 and pos.z < 40:
			continue   # keep the town side open
		if Terrain.is_water(pos.x, pos.z) or Terrain.is_water(pos.x + 4, pos.z) or Terrain.is_water(pos.x - 4, pos.z):
			continue
		pos.y = Terrain.height_at(pos.x, pos.z) - 0.2
		var clump := "trees_A_large.gltf" if k % 2 == 0 else "trees_B_large.gltf"
		Models.solid(trees, Models.MED + clump, pos, rng.randf_range(6.0, 8.0), rng.randf() * TAU, 0.6)
	# Rocks.
	for k in 14:
		var pos := Vector3(rng.randf_range(-35, 35), 0, rng.randf_range(-35, 8))
		if pos.length() < 9.0 or (Vector2(pos.x, pos.z) - Terrain.POND_CENTER).length() < Terrain.POND_RADIUS + 2.0:
			continue
		if Vector2(pos.x - MineCave.ENTRANCE.x, pos.z - MineCave.ENTRANCE.z).length() < 7.0:
			continue   # mine mouth
		var rock: String = ["rock_single_A.gltf", "rock_single_B.gltf", "rock_single_C.gltf", "rock_single_E.gltf"][k % 4]
		Models.solid(trees, Models.MED + rock, pos, rng.randf_range(3.0, 5.0), rng.randf() * TAU)


## A few ambient cars loop the road, one lane each way.
func _spawn_traffic(parent: Node3D) -> void:
	var specs := [["car_taxi.gltf", 1.0, 14.4, -40.0], ["car_hatchback.gltf", -1.0, 17.6, 30.0], ["car_sedan.gltf", 1.0, 14.4, 20.0]]
	for sp in specs:
		var t := TrafficCar.new()
		t.model = sp[0]
		t.dir = sp[1]
		t.lane_z = sp[2]
		t.position = Vector3(sp[3], 0.1, sp[2])
		t.name = "Traffic_" + String(sp[0]).get_basename()
		parent.add_child(t)
		t.setup()


## Cones, picket panels, mailboxes and a bale pyramid: things that exist to be driven into.
func _build_street_props() -> void:
	var holder := Node3D.new()
	holder.name = "StreetProps"
	add_child(holder)
	for row in KnockProp.street_layout():
		var kp := KnockProp.new()
		kp.kind = row[0]
		kp.game = Game
		kp.cluster = row[5]
		var y: float = Terrain.height_at(row[1], row[2]) + CarPhysics.road_height(row[1], row[2]) \
			+ KnockProp.KINDS[row[0]]["size"].y * 0.5 + float(row[4])
		kp.position = Vector3(row[1], y, row[2])
		kp.rotation.y = row[3]
		holder.add_child(kp)


func _build_road_and_signs() -> void:
	var town := Node3D.new()
	town.name = "Town"
	add_child(town)
	var tile := 9.6
	for k in range(-6, 7):
		var piece := "road_straight_crossing.gltf" if k == 0 else "road_straight.gltf"
		Models.put(town, Models.CITY + piece, Vector3(k * tile, 0.0, 16), 4.8, PI / 2)
	# Buildings across the road.
	var names := ["building_A", "building_C", "building_E", "building_B", "building_G", "building_F", "building_D", "building_H"]
	for k in names.size():
		var x := -36.0 + k * 10.5
		Models.solid(town, Models.CITY + names[k] + ".gltf", Vector3(x, 0, 27), 4.8, PI, 0.95)
	for k in range(-5, 6):
		Models.put(town, Models.CITY + "streetlight.gltf", Vector3(k * 10.0 + 3.0, 0, 21.2), 4.0, PI)
	Models.solid(town, Models.CITY + "car_police.gltf", Vector3(-14, 0.62, 19.2), 4.4, PI / 2)
	Models.solid(town, Models.CITY + "car_taxi.gltf", Vector3(8, 0.62, 19.2), 4.4, -PI / 2)
	Models.solid(town, Models.CITY + "car_sedan.gltf", Vector3(24, 0.62, 12.8), 4.4, PI / 2)
	Models.solid(town, Models.CITY + "car_hatchback.gltf", Vector3(-30, 0.62, 12.8), 4.4, -PI / 2)
	_spawn_traffic(town)
	Models.solid(town, Models.CITY + "bench.gltf", Vector3(-4, 0, 21.4), 4.0, PI)
	Models.solid(town, Models.CITY + "firehydrant.gltf", Vector3(2, 0, 21.4), 4.0)
	Models.solid(town, Models.CITY + "dumpster.gltf", Vector3(18, 0, 22), 4.0, PI)
	Models.solid(self, Models.CITY + "watertower.gltf", Vector3(-34, 0, -20), 8.0, 0.0, 0.5)
	var sign := Art.label("BUMPKIN BAY\nPop. 12 (and a goat)", 72, Color(1, 1, 1))
	sign.position = Vector3(-6, 2.6, 11.6)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(sign)
	var post := Art.box(Vector3(0.2, 2.0, 0.2), Art.WOOD)
	post.position = Vector3(-6, 1.0, 11.5)
	add_child(post)


func _build_spaceport() -> void:
	var port := Node3D.new()
	port.name = "Spaceport"
	port.position = Vector3(34, 0, -28)
	add_child(port)
	Models.solid(port, Models.SPACE + "landingpad_large.gltf", Vector3.ZERO, 6.0, 0.0, 1.0)
	Models.put(port, Models.SPACE + "lander_A.gltf", Vector3(0, 3.0, 0), 6.5, 0.6)
	Models.solid(port, Models.SPACE + "structure_tall.gltf", Vector3(-11, 0, -2), 5.0, 0.0, 0.8)
	Models.solid(port, Models.SPACE + "windturbine_tall.gltf", Vector3(11, 0, -6), 4.5, -0.5, 0.4)
	Models.solid(port, Models.SPACE + "cargo_B_stacked.gltf", Vector3(-9, 0, 7), 3.0, 0.3)
	Models.solid(port, Models.SPACE + "solarpanel.gltf", Vector3(9, 0, 6), 4.0, 0.2)
	Models.solid(port, Models.SPACE + "spacetruck.gltf", Vector3(6, 0, 10), 4.4, 2.6)
	var gran := GranRocket.new()
	gran.name = "GranRocket"
	gran.position = Vector3(-9.0, 0, 13.0)   # out front where you can see it
	port.add_child(gran)
	var console := LaunchConsole.new()
	console.name = "LaunchConsole"
	console.position = Vector3(-12.2, 0, 15.4)
	console.rotation.y = -0.6
	port.add_child(console)
	var l := Art.label("SPACEPORT\nlunch is finally over", 100, Color(0.85, 0.95, 1))
	l.position = Vector3(0, 4.5, 9.0)
	l.visibility_range_end = 0.0
	port.add_child(l)


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Rolling low-poly hills ring the valley, with forest on the near ones.
	for k in 26:
		var ang := k * TAU / 26.0 + rng.randf_range(-0.06, 0.06)
		var r := rng.randf_range(115.0, 140.0)
		var hill := Art.sphere(1.0, Color(0.27, 0.47, 0.3).lerp(Color(0.38, 0.55, 0.38), rng.randf()), 5, 7)
		hill.scale = Vector3(rng.randf_range(28, 45), rng.randf_range(14, 30), rng.randf_range(22, 35))
		hill.position = Vector3(cos(ang) * r, -4.0, sin(ang) * r)
		hill.rotation.y = rng.randf() * TAU
		add_child(hill)
	for k in 30:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(80.0, 105.0)
		var clump := "trees_A_large.gltf" if k % 2 == 0 else "trees_B_large.gltf"
		var fp := Vector3(cos(ang) * r, 0, sin(ang) * r)
		if Terrain.is_water(fp.x, fp.z):
			continue
		fp.y = Terrain.height_at(fp.x, fp.z) - 0.3
		Models.put(self, Models.MED + clump, fp, rng.randf_range(9.0, 13.0), rng.randf() * TAU)
	# Clouds.
	for k in 9:
		var c := Models.put(self, Models.MED + ("cloud_big.gltf" if k % 2 == 0 else "cloud_small.gltf"),
			Vector3(rng.randf_range(-90, 90), rng.randf_range(38, 55), rng.randf_range(-90, 60)), rng.randf_range(4.0, 7.0), rng.randf() * TAU)
		_clouds.append(c)
	# Grass: bends underfoot, can be cut for hay, hides a crouching farmer.
	var meadow := Meadow.new()
	meadow.game = Game
	add_child(meadow)


func _build_flowers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var colors := [Color(1.0, 0.85, 0.2), Color(1.0, 0.45, 0.55), Color(0.95, 0.95, 1.0), Color(0.6, 0.5, 1.0), Color(1.0, 0.55, 0.2)]
	var spots: Array[Transform3D] = []
	var tints: Array[Color] = []
	var centers: Array[Vector3] = []
	while centers.size() < 34:
		var c := Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-45, 10))
		if abs(c.x) < 7 and abs(c.z) < 14:
			continue
		if c.x > 8 and c.x < 21 and c.z > -2 and c.z < 11:
			continue
		if c.x > 22 and c.z < -14:
			continue
		if c.x > -17 and c.x < -8 and c.z > -6 and c.z < 3:
			continue
		if Terrain.height_at(c.x, c.z) < -0.4:
			continue
		centers.append(c)
	for c in centers:
		var col: Color = colors[rng.randi() % colors.size()]
		for k in rng.randi_range(6, 14):
			var p := c + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
			p.y = Terrain.height_at(p.x, p.z)
			spots.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), p))
			tints.append(col.lightened(rng.randf_range(-0.1, 0.15)))
	var stem := CylinderMesh.new()
	stem.top_radius = 0.015
	stem.bottom_radius = 0.02
	stem.height = 0.32
	stem.radial_segments = 4
	stem.rings = 1
	var head := SphereMesh.new()
	head.radius = 0.08
	head.height = 0.12
	head.radial_segments = 6
	head.rings = 2
	for pass_i in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = pass_i == 1
		mm.mesh = stem if pass_i == 0 else head
		mm.instance_count = spots.size()
		for k in spots.size():
			var xf := spots[k]
			xf.origin.y += 0.16 if pass_i == 0 else 0.33
			mm.set_instance_transform(k, xf)
			if pass_i == 1:
				mm.set_instance_color(k, tints[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var fm := ShaderMaterial.new()
		fm.shader = Toon.TOON
		fm.set_shader_parameter("albedo_color", Color(0.3, 0.55, 0.25) if pass_i == 0 else Color.WHITE)
		fm.set_shader_parameter("use_vertex_color", pass_i == 1)
		mmi.material_override = fm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	# Butterflies hang around the flower patches during the day.
	for k in 10:
		var b := Critter.new()
		b.kind = Critter.Kind.BUTTERFLY
		b.roam = 2.5
		b.position = centers[k * 3 % centers.size()]
		add_child(b)
		_day_critters.append(b)


func _build_critters() -> void:
	for k in 4:
		var c := Critter.new()
		c.name = "Chicken_%d" % k
		c.kind = Critter.Kind.CHICKEN
		c.roam = 2.8
		c.position = Vector3(-8.0 + k * 0.6, 0, 6.5 + (k % 2) * 0.8)
		add_child(c)
	# Wild rabbits in the meadow beyond the farm: they bolt when you get close.
	for k in 6:
		var r := Critter.new()
		r.name = "Rabbit_%d" % k
		r.kind = Critter.Kind.RABBIT
		r.roam = 3.0
		var ang := k * 1.05 + 0.4
		r.position = Vector3(cos(ang) * (16.0 + k * 1.5), 0, sin(ang) * (16.0 + k * 1.5) - 6.0)
		add_child(r)
	var goat := Critter.new()
	goat.name = "Goat"
	goat.kind = Critter.Kind.GOAT
	goat.roam = 3.5
	goat.position = Vector3(-12, 0, 8.5)
	add_child(goat)
	for f in 2:
		for k in 5:
			var bird := Critter.new()
			bird.kind = Critter.Kind.BIRD
			bird.roam = 28.0 + f * 12.0
			bird.position = Vector3(f * 10.0 - 5.0, 26.0 + f * 6.0 + k * 0.6, -10.0)
			bird.set("_phase", k * 0.09 + f * 2.0)
			add_child(bird)
			_day_critters.append(bird)
	# Fireflies over the farm and the pond at night.
	for spot in [Vector3(0, 1.0, 0), Vector3(Terrain.POND_CENTER.x, 0.6, Terrain.POND_CENTER.y), Vector3(-14, 1.2, 6)]:
		var ff := FX.emitter(self, Color(0.95, 1.0, 0.45), 26, 5.0, 0.07, Vector3(7, 1.2, 7), Vector3(0, 0.05, 0), true, "sphere")
		ff.position = spot
		ff.emitting = false
		_fireflies.append(ff)


func _lamp(pos: Vector3, energy_range: float = 9.0, bulb: bool = true) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0, 0.78, 0.45)
	l.omni_range = energy_range
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.visible = false
	add_child(l)
	_lamps.append(l)
	if bulb:
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		b.mesh = sm
		b.material_override = _lamp_mat
		b.position = pos
		add_child(b)


func _build_lamps() -> void:
	_lamp_mat = ShaderMaterial.new()
	_lamp_mat.shader = Toon.TOON
	_lamp_mat.set_shader_parameter("albedo_color", Color(0.5, 0.35, 0.15))
	_lamp_mat.set_shader_parameter("emission_color", Vector3(1.0, 0.72, 0.3))
	# Streetlights along the road (bulb hangs over the pavement).
	for k in range(-5, 6):
		_lamp(Vector3(k * 10.0 + 3.0, 3.6, 20.3))
	# Porch lanterns.
	for p in [Vector3(-13, 2.6, 1.6), Vector3(14, 2.8, 7.3), Vector3(-4.8, 1.3, 4.8), Vector3(4.8, 1.3, 4.8), Vector3(34, 2.5, -19)]:
		var post := Art.box(Vector3(0.12, p.y, 0.12), Art.WOOD.darkened(0.2))
		post.position = Vector3(p.x, p.y * 0.5, p.z)
		add_child(post)
		_lamp(p + Vector3(0, 0.15, 0), 8.0)


## Flat signs get a twin on the back so they read correctly from both sides.
func _mirror_signs() -> void:
	for n in find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if l.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			continue
		l.double_sided = false
		var back := l.duplicate() as Label3D
		back.rotation.y += PI
		l.get_parent().add_child(back)


func _build_bounds() -> void:
	for p in [Vector3(0, -5, -78), Vector3(0, -5, 78)]:
		var w := Art.solid_box(self, p, Vector3(160, 40, 1), Color(0, 0, 0, 0))
		w.get_child(1).visible = false
	for p in [Vector3(-78, -5, 0), Vector3(78, -5, 0)]:
		var w := Art.solid_box(self, p, Vector3(1, 40, 160), Color(0, 0, 0, 0))
		w.get_child(1).visible = false


func _update_barks(delta: float) -> void:
	var near_npc: Npc = null
	for n in _npcs:
		if not n.indoors and n.global_position.distance_to(player.global_position) < 4.0:
			near_npc = n
			break
	var r := Npc.bark_tick(_bark_t, delta, near_npc != null and player.vehicle == null)
	_bark_t = r["timer"]
	if r["fire"]:
		_bark_n += 1
		var fb := Npc.fresh_bark(Game.reputation, _bark_n, _bark_last, Game.loot_count() > 0, near_npc.npc_name, Police.is_night(Game.time_of_day))
		_bark_n = fb["idx"]
		_bark_last = fb["line"]
		Game.say("%s: \"%s\"" % [near_npc.npc_name, fb["line"]])
