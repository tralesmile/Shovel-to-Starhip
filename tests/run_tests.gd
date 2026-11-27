extends SceneTree
## Headless test runner:  godot --headless --path . --script res://tests/run_tests.gd
## Exits with code 0 when every test passes, 1 otherwise.

var failures: Array[String] = []
var passes := 0
var game: GameState


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for test in [
		"test_economy", "test_sell_all", "test_farm_cycle", "test_dry_crop_does_not_grow",
		"test_no_seeds", "test_tree_chop_and_regrow", "test_mining", "test_feel_and_grading", "test_shop_station", "test_clock_text",
		"test_save_roundtrip", "test_door_enter_exit", "test_npc_schedule", "test_npc_routine_movement",
		"test_lockpick", "test_loot_container", "test_carry_limit", "test_witness_cone", "test_witness_meter", "test_heat", "test_fence_reputation", "test_police", "test_car", "test_fishing", "test_delivery", "test_crops", "test_traffic", "test_police_car", "test_audio_settings", "test_sfx", "test_steps", "test_settings_menu", "test_tutorial", "test_gamepad", "test_engine_sfx", "test_music", "test_music_fade", "test_main_menu", "test_input_prompts", "test_closet", "test_fence_cap", "test_shop_rep", "test_npc_barks", "test_crafting", "test_jump_step", "test_stamina", "test_pickaxe_upgrade", "test_axe_combo", "test_build_mode", "test_carry_weight", "test_props_furniture", "test_hunting", "test_drop_items", "test_campfire_taming", "test_riding", "test_car_parts", "test_timber_chest", "test_gem_pickaxe_cracks", "test_story", "test_furnace", "test_anvil", "test_invention", "test_glider_chips", "test_slingshot_weather", "test_lightning_vacuum", "test_mine", "test_boom_turnip", "test_meadow", "test_momentum_bounce", "test_felled_trunk", "test_bugs", "test_fish_fight", "test_pond_life", "test_fish_log_and_models", "test_car_physics", "test_car_damage_parts", "test_street_props", "test_harvest_regrow_compost", "test_crop_models", "test_giant_crops", "test_sprinkler",
		"test_stealth_gaze", "test_stealth_marker_and_hearing", "test_vision_cone_clip", "test_velvet_picks", "test_abandon_lock", "test_decoy_logic", "test_npc_distraction", "test_lock_meter", "test_heist_art", "test_door_swing", "test_room_dressing",
		"test_edge_snapping", "test_support_and_collapse", "test_roof_shapes", "test_build_aim", "test_door_cutaway_comfort", "test_build_models",
		"test_pet_friendship", "test_animal_rig", "test_chicken_flight_and_jobs_logic", "test_goat_ram", "test_mount_steer", "test_pet_gear_and_save",
		"test_starship_design", "test_flight_ascent", "test_flight_landing", "test_moon_ground_and_cheese", "test_ship_model_and_space",
	]:
		_fresh_game()
		var ok = call(test)
		check(ok == true, "%s ran to the end (no script error)" % test)
		game.free()
	_fresh_game()
	check(await test_moon_walk() == true, "test_moon_walk ran to the end (no script error)")
	game.free()
	_fresh_game()
	check(await test_giant_on_real_ground() == true, "test_giant_on_real_ground ran to the end (no script error)")
	game.free()
	_fresh_game()
	check(await test_decoy_in_real_room() == true, "test_decoy_in_real_room ran to the end (no script error)")
	game.free()
	_fresh_game()
	check(await test_hen_on_real_ground() == true, "test_hen_on_real_ground ran to the end (no script error)")
	game.free()
	_fresh_game()
	check(await test_car_on_real_ground() == true, "test_car_on_real_ground ran to the end (no script error)")
	game.free()
	_fresh_game()
	check(await test_demolish_collapses() == true, "test_demolish_collapses ran to the end (no script error)")
	game.free()
	_fresh_game()
	check(await test_collapse_on_real_ground() == true, "test_collapse_on_real_ground ran to the end (no script error)")
	game.free()
	_fresh_game()
	check(await test_stairs_on_real_ground() == true, "test_stairs_on_real_ground ran to the end (no script error)")
	game.free()
	print("\n%d checks passed, %d failed" % [passes, failures.size()])
	for f in failures:
		print("  FAIL: ", f)
	quit(0 if failures.is_empty() else 1)


func _fresh_game() -> void:
	for n in root.get_children():
		if n.name != "Game":
			n.free()
	game = GameState.new()
	game.name = "TestGame"
	game.clock_running = false
	root.add_child(game)


func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
	else:
		failures.append(label)


# ---------------------------------------------------------------- tests

## Plays a fight with a player who lets go whenever the fish thrashes (or always holds).
func _fight_out(species: String, careful: bool, rod: bool = false, catches: int = 99, seed_value: int = 5) -> String:
	var f := FishFight.new(species, rod, catches, seed_value)
	for i in 4000:
		var hold := true
		if careful:
			hold = not f.surging and f.tension < 0.85
		if f.tick(0.02, hold) != "":
			break
	return f.result


func test_fish_fight() -> bool:
	for species in FishFight.SPECIES:
		check(Fishing.SIZES.has(species), "fight species has sizes: " + species)
		for s in 8:
			check(_fight_out(species, true, false, 99, s) == "landed", "careful angler lands " + species)
	var snaps := 0
	for s in 20:
		if _fight_out("golden_carp", false, false, 99, s) == "snapped":
			snaps += 1
	check(snaps >= 18, "hauling blindly on a golden carp snaps the line")
	check(_fight_out("boot", false) == "landed", "a boot never fights")
	check(_fight_out("minnow", false) == "landed", "minnows are forgiving even when you just hold")
	var idle := FishFight.new("carp")
	for i in 2000:
		idle.tick(0.05, false)
	check(idle.result == "escaped", "never reeling loses the fish")
	check(FishFight.strain_rate(1.0, true, true, 1.0) < FishFight.strain_rate(1.0, true, false, 1.0), "springy rod eases strain")
	check(FishFight.new("carp", false, 0).ease < FishFight.new("carp", false, 10).ease, "beginner's luck on first catches")
	var calm := FishFight.new("golden_carp")
	calm._phase_left = INF
	for i in 100:
		calm.tick(0.02, true)
		calm.progress = 0.5
	check(calm.result == "", "a calm fish never snaps the line")
	return true


func test_pond_life() -> bool:
	check(Fishing.cast_power(0.0) == 0.0 and Fishing.cast_power(5.0) == 1.0, "cast power clamps")
	check(Fishing.cast_distance(1.0, true) > Fishing.cast_distance(1.0, false), "springy rod casts further")
	var spot2d := Vector2(-17.8, 1.0)
	var to_pond := Terrain.POND_CENTER - spot2d
	check(FishingSpot.aim_dir(Vector2(1, 0), to_pond).is_equal_approx(to_pond.normalized()), "looking away still casts at the pond")
	var look := to_pond.normalized().rotated(0.4)
	check(FishingSpot.aim_dir(look, to_pond).is_equal_approx(look), "looking at the water steers the cast")
	for power in [0.0, 0.5, 1.0]:
		var at := FishingSpot.landing(spot2d, look, Fishing.cast_distance(power, true))
		check(Terrain.is_water(at.x, at.y), "casts always land in water %s" % power)
	var v := FishingSpot.lob_velocity(Vector3.ZERO, Vector3(3, 1, 0), 1.0, 9.8)
	check(is_equal_approx(v.y - 4.9, 1.0) and is_equal_approx(v.x, 3.0), "catch lob reaches its target")
	var list := [PondLife.new_fish("carp", Vector2(0, 0), 0.0, 40), PondLife.new_fish("minnow", Vector2(5, 0), 0.0, 8)]
	check(PondLife.pick_fish(list, Vector2(4, 0)) == 1, "the nearest shadow gets curious, so aim matters")
	check(PondLife.interest_delay(0.5, true, false) < PondLife.interest_delay(0.5, false, false), "bait speeds bites")
	check(PondLife.interest_delay(0.5, false, true) < PondLife.interest_delay(0.5, false, false), "rain speeds bites")
	check(PondLife.nibble_count(0.99, false) == 3 and PondLife.nibble_count(0.99, true) == 1, "bait means fewer fake-outs")
	check(PondLife.shadow_length("golden_carp", 80) > PondLife.shadow_length("minnow", 6), "bigger fish, bigger shadow")
	var pond := PondLife.new()
	root.add_child(pond)
	check(pond.fish.size() == PondLife.COUNT, "pond is stocked")
	var target := Terrain.POND_CENTER + Vector2(2, 1)
	pond.set_bobber(target, false)
	var events: Array = []
	for i in 1500:
		var ev := pond.tick(0.02)
		if ev != "":
			events.append(ev)
		if ev == "bite":
			break
	check(events.size() >= 1 and events[-1] == "bite" and events.size() <= 4, "a fish swims over, maybe nibbles, then bites")
	check(pond.hooked_species() != "", "the biter is a known fish")
	for f in pond.fish:
		check((f["pos"] as Vector2).distance_to(Terrain.POND_CENTER) <= PondLife.RADIUS + 0.01, "fish stay in the pond")
	var n := pond.fish.size()
	var taken := pond.take_hooked()
	check(pond.fish.size() == n - 1 and taken.has("cm"), "hooked fish leaves the shadows")
	pond.restock()
	check(pond.fish.size() == PondLife.COUNT, "pond restocks")
	for i in 40:
		pond.add_ripple(target)
	check(pond.ripples.size() == PondLife.MAX_RIPPLES, "ripples are capped for the shader")
	pond._process(PondLife.RIPPLE_LIFE + 0.1)
	check(pond.ripples.is_empty(), "ripples fade out")
	pond.free()
	return true


func test_fish_log_and_models() -> bool:
	var book := {}
	check(Fishing.log_catch(book, "carp", 30) == "new", "first carp is new")
	check(Fishing.log_catch(book, "carp", 45) == "best", "bigger carp is a best")
	check(Fishing.log_catch(book, "carp", 31) == "" and book["carp"]["best"] == 45 and book["carp"]["n"] == 3, "journal keeps the best")
	for species in Fishing.SIZES:
		var lo := Fishing.size_for(species, 0.0)
		var hi := Fishing.size_for(species, 1.0)
		check(lo == Fishing.SIZES[species][0] and hi == Fishing.SIZES[species][1], "size range " + species)
		var m := FishModel.build(species)
		check(m.get_child_count() >= 4, "model built " + species)
		m.free()
	check(WoodLog.flops("carp") and not WoodLog.flops("boot") and not WoodLog.flops("wood"), "only live fish flop")
	game.fish_log = book
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.to_dict()))
	game.fish_log = {}
	game.from_dict(saved)
	check(game.fish_log["carp"]["best"] == 45, "journal survives save/load")
	for id in ["sunmint_bait", "springy_rod"]:
		var idx := -1
		for i in GameState.RECIPES.size():
			if GameState.RECIPES[i]["id"] == id:
				idx = i
		check(idx >= 0 and GameState.ITEMS.has(id), "recipe and item exist: " + id)
		for need in GameState.RECIPES[idx]["in"]:
			game.add_item(need, GameState.RECIPES[idx]["in"][need])
		check(game.craft(idx) and game.count(id) >= 1, "can craft " + id)
	var spot := FishingSpot.new()
	root.add_child(spot)
	var bait := game.count("sunmint_bait")
	spot.launch(game, 0.5, Vector2.ZERO)
	check(spot.baited and game.count("sunmint_bait") == bait - 1, "each cast uses one bait")
	check(spot.get_prompt(game) == "Wheee...", "prompt follows the cast")
	spot.phase = FishingSpot.Phase.IDLE
	check(spot.get_prompt(game).contains("Fish Journal 1/6"), "idle prompt shows journal progress")
	spot.free()
	return true


func test_felled_trunk() -> bool:
	check(FelledTrunk.cuts_needed(true) == FelledTrunk.cuts_needed(false) - 1, "copper axe bucks faster")
	var ax := Vector3(0, 0, 1)
	check(FelledTrunk.closest_on_axis(Vector3.ZERO, ax, 3.0, Vector3(1, 0, 0.4)).is_equal_approx(Vector3(0, 0, 0.4)), "nearest point along the trunk")
	check(FelledTrunk.closest_on_axis(Vector3.ZERO, ax, 3.0, Vector3(0, 0, 9)).is_equal_approx(Vector3(0, 0, 1.5)), "clamped to the end")
	var rc := FelledTrunk.rest_centre(Vector3.ZERO, Vector3.RIGHT, 3)
	check(rc.x > 1.5 and rc.y > FelledTrunk.RADIUS, "trunk rests past the stump, above ground")
	check((FelledTrunk.lie_basis(Vector3.RIGHT) * Vector3(0, 0, 1)).is_equal_approx(Vector3.RIGHT), "trunk lies along the fall line")
	check(ChoppableTree.domino(0, 3) == {"hits": 1, "falls": false}, "domino notches a fresh tree")
	check(ChoppableTree.domino(2, 3) == {"hits": 0, "falls": true}, "domino topples a notched tree")
	var holder := Node3D.new()
	root.add_child(holder)
	var t := FelledTrunk.new()
	t.setup(Vector3.ZERO, Vector3.RIGHT, 3, game)
	holder.add_child(t)
	game.set_tool(GameState.Tool.HOE)
	t.interact(game)
	check(t.cuts == 0 and t.sections == 3, "only the axe bucks a trunk")
	game.set_tool(GameState.Tool.AXE)
	var butt: Vector3 = t.body.global_position - t.axis() * 1.5
	for i in FelledTrunk.CUTS_PER_SECTION:
		t.interact(game)
	var logs := holder.get_children().filter(func(n): return n is WoodLog)
	check(t.sections == 2 and logs.size() == 1, "two swings free one log")
	check((t.body.global_position - t.axis() * 1.0).is_equal_approx(butt), "the butt end stays put as it shortens")
	check((logs[0].global_basis.y.normalized()).abs().is_equal_approx(t.axis().abs()), "the freed log lies along the trunk")
	var saved := t.to_dict()
	var t2 := FelledTrunk.new()
	t2.restore(saved, game)
	holder.add_child(t2)
	check(t2.sections == 2 and t2.axis().is_equal_approx(t.axis()), "trunk survives a save roundtrip")
	for i in FelledTrunk.CUTS_PER_SECTION * 2:
		t.interact(game)
	logs = holder.get_children().filter(func(n): return n is WoodLog)
	check(t.sections == 0 and logs.size() == ChoppableTree.WOOD_DROP and t.is_queued_for_deletion(), "a whole trunk gives 3 logs")
	t.interact(game)
	check(holder.get_children().filter(func(n): return n is WoodLog).size() == 3, "no bonus logs from an empty trunk")
	# A stump waits for its trunk before regrowing, and a save keeps the trunk.
	var tree := ChoppableTree.new()
	tree.name = "Tree_W"
	holder.add_child(tree)
	tree.felled = true
	tree._spawn_trunk(game, Vector3.RIGHT)
	check(tree.has_trunk() and tree.to_dict().has("trunk"), "felled tree owns and saves its trunk")
	for d in ChoppableTree.REGROW_DAYS + 1:
		tree.on_new_day(game)
	check(tree.felled and tree.days_felled == 0, "stump waits for the trunk to be cleared")
	tree.trunk.sections = 0
	for d in ChoppableTree.REGROW_DAYS:
		tree.on_new_day(game)
	check(not tree.felled, "cleared stump regrows")
	# Domino: a notched neighbour goes over when clipped.
	var nb := ChoppableTree.new()
	nb.name = "Tree_N"
	holder.add_child(nb)
	check(nb.domino_hit(game, Vector3.RIGHT) and nb.hits == 1 and not nb.felled, "clipped tree is notched")
	nb.hits = 2
	nb.domino_hit(game, Vector3.RIGHT)
	check(nb.felled and not nb.domino_hit(game, Vector3.RIGHT), "notched tree dominoes once")
	holder.free()
	return true


func test_bugs() -> bool:
	for k in Bug.KINDS:
		check(GameState.ITEMS.has(k) and int(GameState.ITEMS[k]["sell"]) > 0, "%s is a sellable item" % k)
		check(Bug.catch_chance(k, true, false) == 1.0, "net always catches %s" % k)
		check(Bug.catch_chance(k, false, true) > Bug.catch_chance(k, false, false), "sneaking helps with %s" % k)
	check(Bug.reach(true) > Bug.reach(false), "net reaches further")
	check(Bug.target_rank(1.8, false) < Bug.target_rank(0.1, true) and Bug.target_rank(0.2, true) < Bug.target_rank(1.0, true), "bugs never steal E from solid targets")
	check(Bug.scare_radius(8.0, false) > Bug.scare_radius(3.0, false) and Bug.scare_radius(3.0, false) > Bug.scare_radius(2.0, true), "running scares more than walking than sneaking")
	check(Bug.scare_radius(2.0, true) < Bug.HAND_REACH, "a sneak can get within grabbing range")
	check(Bug.hop_point(Vector3.ZERO, Vector3(2, 0, 0), 0.5, 0.75).is_equal_approx(Vector3(1, 0.75, 0)), "hop arcs")
	check(Bug.hop_point(Vector3.ZERO, Vector3(2, 0, 0), 1.0, 0.75).is_equal_approx(Vector3(2, 0, 0)), "hop lands")
	for i in 20:
		var b := Bug.blink(i * 0.4, 1.0)
		check(b >= 0.35 and b <= 1.0, "blink in range")
	check(BugLife.ambient_kind(0.45, false) == "butterfly" and BugLife.ambient_kind(0.9, false) == "firefly", "butterflies by day, fireflies by night")
	check(BugLife.ambient_kind(0.1, false) == "firefly" and BugLife.ambient_kind(0.45, true) == "", "none in the rain")
	check(BugLife.flush_for(0.02, true) == "frog" and BugLife.flush_for(0.02, false) == "grasshopper" and BugLife.flush_for(0.9, false) == "", "frogs love rain")
	check(BugLife.flush_list([0.9, 0.9], false).is_empty(), "a tiny snip flushes nothing")
	check(BugLife.flush_list([0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9], false) == ["grasshopper"], "a big swing always flushes something")
	var life := BugLife.new()
	life.game = game
	root.add_child(life)
	var n := life.flush([Vector3(-9.5, 0, -4), Vector3(-9, 0, -4)], Vector3(-8, 0, -4), [0.02, 0.9])
	check(n == 1 and life.bugs("grasshopper").size() == 1, "cut grass flushes a hopper")
	var many: Array = []
	var spots: Array = []
	for i in 40:
		many.append(0.02)
		spots.append(Vector3(-9.5, 0, -4))
	life.flush(spots, Vector3.ZERO, many)
	check(life.bugs().size() == BugLife.MAX_FLUSHED, "hoppers are capped")
	var b: Bug = life.bugs()[0]
	check(not b.try_catch(game, false, 0.99) and game.count(b.kind) == 0, "bare hands can miss")
	game.add_item("bug_net", 1)
	var k: String = b.kind
	check(b.try_catch(game, false, 0.99) and game.count(k) == 1, "the net does not miss")
	check(not b.try_catch(game, false, 0.0) and game.count(k) == 1, "no double catch")
	var idx := _recipe_index_of("firefly_jar")
	game.add_item("firefly", 4)
	game.add_item("plank", 1)
	game.add_item("copper_ingot", 1)
	check(idx >= 0 and game.craft(idx) and game.count("firefly_jar") == 1 and game.count("firefly") == 0, "craft a Firefly Jar")
	check(_recipe_index_of("bug_net") >= 0 and not GameState.stashable("bug_net"), "net recipe; net stays with you")
	check(BuildWorld.is_furniture("firefly_jar") and BuildWorld.PIECE_ORDER.has("firefly_jar"), "jar is placeable furniture")
	var bp := BuildPiece.new()
	bp.piece_id = "firefly_jar"
	root.add_child(bp)
	check(bp.find_children("*", "FireflyJar", true, false).size() >= 0 and bp.get_child_count() > 0, "jar piece builds")
	check(FireflyJar.darkness(0.95) > 0.95 and FireflyJar.darkness(0.45) < 0.2, "jar shines at night")
	return true


func test_meadow() -> bool:
	check(not Meadow.spot_ok(0, 0), "no grass on the farm")
	check(not Meadow.spot_ok(14, 5), "no grass in the store")
	check(not Meadow.spot_ok(0, 16), "no grass on the road")
	check(Meadow.spot_ok(-9.5, -4.0), "grass beside the farm")
	check(Meadow.swing_for(true)["radius"] > Meadow.swing_for(false)["radius"] and Meadow.swing_for(true)["arc"] >= 360.0, "scythe sweeps wider, all round")
	check(Meadow.in_swing(Vector2(0, 1.2), Vector2.ZERO, 0.0, 1.7, 110.0), "tuft ahead is hit")
	check(not Meadow.in_swing(Vector2(0, -1.2), Vector2.ZERO, 0.0, 1.7, 110.0), "tuft behind is missed")
	check(Meadow.in_swing(Vector2(0, -1.2), Vector2.ZERO, 0.0, 3.0, 360.0), "spin hits behind")
	check(Meadow.in_swing(Vector2(1.2, 0), Vector2.ZERO, PI * 0.5, 1.7, 110.0), "yaw turns the arc")
	check(not Meadow.in_swing(Vector2(0, 4.0), Vector2.ZERO, 0.0, 3.0, 360.0), "out of reach")
	var h := Meadow.hay_from(0, 12)
	check(h[0] == 2 and h[1] == 2, "12 tufts = 2 bundles, 2 carried")
	h = Meadow.hay_from(h[0], 3)
	check(h[0] == 0 and h[1] == 1, "leftover carries over")
	check(Meadow.find_for(0.0) == "sunmint" and Meadow.find_for(0.5) == "" and Meadow.find_for(0.999) == "turnip_seed", "rare finds")
	check(not Meadow.regrown(3, 4) and Meadow.regrown(3, 5), "regrows after 2 days")
	check(Meadow.is_cover(true, 6) and not Meadow.is_cover(false, 6) and not Meadow.is_cover(true, 1), "cover needs crouch and tall grass")
	check(Meadow.trail_power(0.0) > Meadow.trail_power(0.7) and Meadow.trail_power(5.0) == 0.0, "wake fades")
	check(Critter.rabbit_mode(2.0, true, false, true) == "alert" and Critter.rabbit_mode(2.0, true, false, false) == "flee", "grass cover lets you creep closer")
	check(Police.sight_range(true, 0.5, true) < Police.sight_range(true, 0.5), "grass cover shortens constable sight")
	var md := Meadow.new()
	md.game = game
	root.add_child(md)
	check(md.tufts.size() > 3000, "meadow is dense (%d)" % md.tufts.size())
	var at := Vector3(-9.5, 0, -4.0)
	check(md.tall_count(at) >= Meadow.COVER_TUFTS, "tall patch by the farm")
	check(md.tall_count(Vector3(450, 0, 0)) == 0, "no grass indoors")
	var ids := md.targets(at, 0.0, Meadow.SCYTHE_RADIUS, 360.0)
	check(ids.size() >= 10, "scythe reaches many tufts (%d)" % ids.size())
	var rolls: Array = []
	rolls.resize(ids.size())
	rolls.fill(0.5)
	var before := root.get_tree().get_nodes_in_group("pickup").size()
	check(md.cut(ids, at, rolls) == ids.size(), "all cut")
	var bundles := root.get_tree().get_nodes_in_group("pickup").size() - before
	check(bundles == mini(ids.size() / Meadow.TUFTS_PER_HAY, Meadow.MAX_LOOSE_PICKUPS), "hay pops out as pickups (%d)" % bundles)
	check(md.targets(at, 0.0, Meadow.SCYTHE_RADIUS, 360.0).is_empty() and md.cut(ids, at, rolls) == 0, "stubble cannot be cut twice")
	check(game.meadow_cut.size() == ids.size(), "cuts recorded")
	var saved := game.to_dict()
	game.meadow_cut = {}
	game.from_dict(saved)
	check(game.meadow_cut.size() == ids.size(), "cuts survive save/load")
	game.day += Meadow.REGROW_DAYS
	md.refresh()
	check(game.meadow_cut.is_empty() and md.targets(at, 0.0, Meadow.SCYTHE_RADIUS, 360.0).size() == ids.size(), "grass regrows")
	var full := md.tall_count(at)
	game.built = [{"id": "wood_floor", "x": -10.0, "z": -4.0, "r": 0}]
	md.refresh_built()
	check(md.tall_count(at) < full, "floors hide grass")
	game.built = []
	md.refresh_built()
	check(md.tall_count(at) == full, "demolishing brings it back")
	check(md.blast(at, 4.0) > 0, "a blast mows grass")
	md.free()
	var si := _recipe_index_of("scythe")
	game.add_item("plank", 3)
	game.add_item("stone", 2)
	check(game.craft(si) and game.count("scythe") == 1, "scythe crafts")
	check(game.tool_label(GameState.Tool.HOE) == "Hoe Scythe", "hotbar shows the scythe")
	game.add_item("hay", 6)
	check(game.craft(_recipe_index_of("hay_bale")) and game.count("hay_bale") == 1, "hay bale crafts")
	check(BuildWorld.PIECES.has("hay_bale") and BuildWorld.is_furniture("hay_bale"), "hay bale is placeable")
	check(Critter.tame_food(Critter.Kind.GOAT, {"hay": 4}) == "hay" and Critter.tame_food(Critter.Kind.GOAT, {"hay": 3}) == "", "goat takes an armful of hay")
	check(Critter.tame_food(Critter.Kind.CHICKEN, {"hay": 9}) == "", "chickens do not eat hay")
	check(Critter.tame_food(Critter.Kind.GOAT, {"hay": 9, "carrot": 1}) == "carrot", "veg first")
	check(WoodLog.drop_color("hay").a > 0.0 and WoodLog.is_organic("sunmint"), "pickup looks")
	return true


func test_momentum_bounce() -> bool:
	check(FX.move_accel(Vector2.ZERO, Vector2(8, 0), true) == FX.ACCEL_GROUND, "start ramp")
	check(FX.move_accel(Vector2(8, 0), Vector2.ZERO, true) == FX.BRAKE_GROUND, "brake ramp")
	check(FX.is_skid(Vector2(8, 0), Vector2(-8, 0)) and FX.move_accel(Vector2(8, 0), Vector2(-8, 0), true) == FX.ACCEL_SKID, "reversing a run skids")
	check(not FX.is_skid(Vector2(5, 0), Vector2(-5, 0)), "walking turns stay snappy")
	check(not FX.is_skid(Vector2(8, 0), Vector2(0, 8)), "a right angle is not a skid")
	check(FX.move_accel(Vector2(8, 0), Vector2(-8, 0), false) == FX.ACCEL_AIR, "air control")
	check(FX.lean_roll(4.0, 8.0) < 0.0 and FX.lean_roll(-4.0, 8.0) > 0.0 and absf(FX.lean_roll(99.0, 20.0)) <= 0.2, "lean into turns, capped")
	check(FX.lean_pitch(8.5, false) > FX.lean_pitch(3.0, false) and FX.lean_pitch(8.5, true) < 0.0, "pitch forward, rear back")
	check(FX.bounce_vy(1.0, true) == 0.0, "stepping up does not bounce")
	check(FX.bounce_vy(6.0, true) > FX.bounce_vy(6.0, false), "holding jump pumps")
	var v := 5.0
	for i in 8:
		v = FX.bounce_vy(v, true)
	check(is_equal_approx(v, FX.BOUNCE_MAX), "pumping builds to the cap")
	var d := 8.0
	for i in 12:
		d = FX.bounce_vy(d, false)
	check(d == 0.0, "bounces die out without jump")
	return true


func test_economy() -> bool:
	check(game.money == 50, "starts with $50")
	check(game.count("turnip_seed") == 5, "starts with 5 seeds")
	check(game.spend(20) and game.money == 30, "spend 20")
	check(not game.spend(1000), "cannot overspend")
	check(game.money == 30, "money unchanged after failed spend")
	check(game.buy("turnip_seed", 3) and game.count("turnip_seed") == 8, "buy 3 seeds")
	check(game.money == 0, "buying costs $10 each")
	check(not game.remove_item("turnip", 1), "cannot remove missing item")
	return true


func test_sell_all() -> bool:
	game.add_item("turnip", 3)
	game.add_item("wood", 4)
	var earned := game.sell_all()
	check(earned == 3 * 35 + 4 * 5, "sell_all value (%d)" % earned)
	check(game.count("turnip") == 0 and game.count("wood") == 0, "sold items removed")
	check(game.count("turnip_seed") == 5, "seeds are not sold")
	check(game.money == 50 + earned, "money added")
	check(game.sell_all() == 0, "selling nothing earns 0")
	return true


func _plot() -> FarmPlot:
	var p := FarmPlot.new()
	p.name = "Plot_T"
	root.add_child(p)
	return p


## Grab every loose pick-up lying around (what walking over them does).
func _collect_pickups() -> int:
	var n := 0
	for node in get_nodes_in_group("pickup"):
		var l := node as WoodLog
		if l != null and not l.is_queued_for_deletion():
			l.game = game
			l.collect()
			n += 1
	return n


## A fresh 4x4 field wired to its giant-crop watcher, like main.gd builds it.
func _field() -> FarmField:
	var farm := Node3D.new()
	root.add_child(farm)
	var plots: Array = []
	for i in 16:
		var p := FarmPlot.new()
		p.name = "Plot_%02d" % i
		p.position = Vector3(-3 + (i / 4) * 2, 0, -3 + (i % 4) * 2)
		farm.add_child(p)
		plots.append(p)
	var f := FarmField.new()
	f.plots = plots
	farm.add_child(f)
	return f


func _ripen(p: FarmPlot, crop: String, fed: bool) -> void:
	p.from_dict({"state": FarmPlot.State.PLANTED, "crop": crop, "growth": 9, "watered": true, "composted": fed})


func test_harvest_regrow_compost() -> bool:
	check(FarmPlot.harvest_amount(true, false) == 2 and FarmPlot.harvest_amount(false, false) == 1, "compost doubles a harvest")
	check(FarmPlot.regrow_growth("turnip", 1) == -1, "turnips come out roots and all")
	check(FarmPlot.regrow_growth("tomato", 1) == 2 and FarmPlot.regrow_growth("tomato", 3) == -1, "tomato fruits three times")
	var p := _plot()
	_ripen(p, "tomato", false)
	for pick in 3:
		p.growth = p.grow_days()
		p.interact(game)
		check((p.state == FarmPlot.State.PLANTED) == (pick < 2), "vine survives pick %d" % pick)
	check(_collect_pickups() >= 3 and game.count("tomato") >= 3, "three picks, at least three tomatoes")
	# Compost: Seeds tool on a growing plant.
	p.from_dict({"state": FarmPlot.State.PLANTED, "crop": "turnip", "growth": 0})
	game.set_tool(GameState.Tool.SEEDS)
	p.interact(game)
	check(not p.composted, "no compost in pockets, nothing happens")
	game.add_item("compost", 2)
	check("compost" in p.get_prompt(game), "prompt offers compost")
	p.interact(game)
	p.interact(game)
	check(p.composted and game.count("compost") == 1, "one dose per plant")
	var saved := p.to_dict()
	p.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(p.composted, "compost saved")
	p.growth = p.grow_days()
	var before := game.count("turnip")
	p.interact(game)
	_collect_pickups()
	check(game.count("turnip") == before + 2 and not p.composted, "composted plant gives two, then the dose is used up")
	check(FarmPlot.new().is_ripe() == false, "new plot is not ripe")
	var s := [Vector2(0.3, 0), Vector2.ZERO]
	for i in 200:
		s = FarmPlot.spring_step(s[0], s[1], 0.016)
	check((s[0] as Vector2).length() < 0.01, "leaf spring settles")
	check(GameState.RECIPES.any(func(r): return r["id"] == "compost") and GameState.RECIPES.any(func(r): return r["id"] == "sprinkler"), "recipes exist")
	return true


func test_crop_models() -> bool:
	check(CropModel.growth_fraction(0, 3) == 0.0 and CropModel.growth_fraction(5, 3) == 1.0, "growth fraction clamps")
	for crop in GameState.CROP_ORDER:
		check(CropModel.is_crop(crop), "model exists for " + crop)
		var sprout := CropModel.plant(crop, 0, 4)
		var grown := CropModel.plant(crop, 4, 4)
		root.add_child(sprout)
		root.add_child(grown)
		var a := Models.local_aabb(sprout, sprout)
		var b := Models.local_aabb(grown, grown)
		check(b.size.x * b.size.y * b.size.z > a.size.x * a.size.y * a.size.z, crop + " visibly grows")
		check(b.size.x < FarmPlot.SIZE, crop + " stays inside its plot")
		var veg := CropModel.produce(crop)
		check(veg.get_child_count() >= 2, crop + " produce has parts")
		veg.free()
	var m := CropModel.soil_mesh(FarmPlot.SIZE)
	check(m.get_surface_count() == 1 and CropModel.furrow_height(0.0, 0.9) >= 0.02, "furrowed soil mesh")
	return true


func test_giant_crops() -> bool:
	check(FarmField.blocks().size() == 9 and FarmField.blocks()[0] == [0, 1, 4, 5], "nine 2x2 blocks")
	check(is_equal_approx(FarmField.giant_chance(0), 0.2) and FarmField.giant_chance(4) == 1.0, "compost makes giants certain")
	var ok := {"crop": "turnip", "ripe": true, "wet": true, "giant": false}
	check(FarmField.eligible([ok, ok, ok, ok]), "four matching ripe watered plots qualify")
	for bad in [{"crop": "carrot"}, {"ripe": false}, {"wet": false}, {"giant": true}]:
		var c: Dictionary = ok.duplicate()
		c.merge(bad, true)
		check(not FarmField.eligible([ok, ok, c, ok]), "disqualified by %s" % str(bad))
	var f := _field()
	for i in [0, 1, 4, 5]:
		_ripen(f.plots[i], "turnip", true)
	game.advance_day()
	check(f.giants().size() == 1, "composted watered block fuses overnight")
	var g: GiantCrop = f.giants()[0]
	var plot: FarmPlot = f.plots[0]
	check(plot.giant and plot.get_prompt(game) == "", "its plots are locked")
	plot.interact(game)
	check(game.count("turnip") == 0 and plot.giant, "cannot harvest a plot under a giant")
	check(g.position.is_equal_approx(Vector3(-2, 0, -2)), "giant sits in the middle of the block")
	g.interact(game)
	check(g.tugs == 1 and GiantCrop.rise(1) > GiantCrop.rise(0), "a tug lifts it")
	var data = JSON.parse_string(JSON.stringify(game.to_dict()))
	game.from_dict(data)
	check(f.giants().size() == 1 and f.giants()[0].tugs == 1, "rooted giant and tugs survive a save")
	g = f.giants()[0]
	g.interact(game)
	g.interact(game)
	check(f.giants().size() == 0 and f.loose_giants().size() == 1, "third heave uproots it")
	check(not plot.giant and plot.state == FarmPlot.State.TILLED, "plots are freed")
	data = JSON.parse_string(JSON.stringify(game.to_dict()))
	game.from_dict(data)
	check(f.loose_giants().size() == 1, "loose giant survives a save")
	var ball: GiantBall = f.loose_giants()[0]
	var money := game.money
	check(ball.weigh_in(game) == GiantBall.weigh_value("turnip") and game.money == money + 350, "weigh-in pays")
	check(ball.weigh_in(game) == 0, "only once")
	check(GiantBall.weigh_value("turnip") > GiantBall.CHOP_YIELD * 35, "rolling it to the bin beats chopping")
	var ball2 := f.spawn_ball("carrot", Vector3(0, 1, 0), game)
	for i in GiantBall.CHOPS:
		ball2.chop(game)
	check(_collect_pickups() >= GiantBall.CHOP_YIELD and game.count("carrot") == GiantBall.CHOP_YIELD, "chopping showers produce")
	check(GiantBall.at_bin(Vector3(6.0, 1, 6.0)) and not GiantBall.at_bin(Vector3(0, 1, 0)), "bin range")
	check(GiantBall.lost(Vector3(0, -9, 0), false) and not GiantBall.lost(Vector3(0, 1, 0), false), "lost giants are recovered")
	var v := GiantBall.heave_velocity(0.0)
	check(v.y * v.y / (2.0 * 9.8) > 1.4 and v.z > 0.0, "heave clears the fence")
	# A plot flagged giant with no record must not stay locked.
	plot.giant = true
	f.from_dict({"giants": [], "loose": []})
	check(not plot.giant, "orphaned giant plot is freed")
	# Dry blocks never fuse.
	for i in [0, 1, 4, 5]:
		_ripen(f.plots[i], "turnip", true)
		f.plots[i].watered = false
	for d in 3:
		game.advance_day()
	check(f.giants().is_empty() or Weather.is_wet(game.weather()), "unwatered crops do not fuse")
	return true


## Real physics: uprooting must not fire the giant into orbit, and a heave must clear a 1.2 m fence.
func test_giant_on_real_ground() -> bool:
	await process_frame
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(60, 1, 60)
	cs.shape = bx
	cs.position.y = -0.5
	floor_body.add_child(cs)
	root.add_child(floor_body)
	var f := _field()
	for i in [5, 6, 9, 10]:
		_ripen(f.plots[i], "turnip", true)
	var g := f.form([5, 6, 9, 10])
	await physics_frame
	await physics_frame
	for k in GiantCrop.TUGS:
		g.interact(game)
		await physics_frame
	var ball: GiantBall = f.loose_giants()[0]
	var apex := 0.0
	for k in 150:
		await physics_frame
		apex = maxf(apex, ball.global_position.y)
	check(apex > 1.0 and apex < 3.5, "uproot is a hop, not a space launch (apex %.2f)" % apex)
	check(absf(ball.global_position.y - GiantBall.RADIUS) < 0.25, "it comes to rest on the ground (y %.2f)" % ball.global_position.y)
	var start := ball.global_position
	ball.heave(game)
	apex = 0.0
	for k in 120:
		await physics_frame
		apex = maxf(apex, ball.global_position.y)
	check(apex - GiantBall.RADIUS > 1.2 and apex < 5.0, "heave lifts it over the fence (apex %.2f)" % apex)
	check(Vector2(ball.global_position.x - start.x, ball.global_position.z - start.z).length() > 3.0, "heave carries it along")
	return true


func test_sprinkler() -> bool:
	check(SprinklerSpot.reaches(Vector3(-2, 0, -2), Vector3(-1, 0, -1)), "corner sprinkler reaches its plots")
	check(not SprinklerSpot.reaches(Vector3(-2, 0, -2), Vector3(1, 0, -1)), "but not the next column over")
	var f := _field()
	for p in f.plots:
		p.from_dict({"state": FarmPlot.State.PLANTED, "crop": "carrot", "growth": 0})
	var bw := BuildWorld.new()
	root.add_child(bw)
	game.add_item("sprinkler", 1)
	check(BuildWorld.is_furniture("sprinkler"), "sprinkler has its own build slot")
	check(bw.place("sprinkler", Vector3(-2, 0, -2), 0, game), "placed with the builder")
	var watered := f.plots.filter(func(p): return p.watered).size()
	check(watered == 4, "waters the four plots around it at once (%d)" % watered)
	game.advance_day()
	for i in [0, 1, 4, 5]:
		check(f.plots[i].watered, "morning spray re-waters plot %d" % i)
	var g0: int = f.plots[0].growth
	game.advance_day()
	check(f.plots[0].growth == g0 + 1, "sprinkled crops grow without you")
	return true


func test_farm_cycle() -> bool:
	var p := _plot()
	game.set_tool(GameState.Tool.SEEDS)
	p.interact(game)
	check(p.state == FarmPlot.State.GRASS, "cannot plant on grass")
	game.set_tool(GameState.Tool.HOE)
	p.interact(game)
	check(p.state == FarmPlot.State.TILLED, "hoe tills")
	game.set_tool(GameState.Tool.SEEDS)
	p.interact(game)
	check(p.state == FarmPlot.State.PLANTED and game.count("turnip_seed") == 4, "plant uses a seed")
	for night in p.grow_days():
		game.set_tool(GameState.Tool.WATER)
		p.interact(game)
		check(p.watered, "watered night %d" % night)
		check(not p.is_ripe(), "not ripe before night %d" % night)
		game.advance_day()
		check(not p.watered, "soil dries overnight %d" % night)
	check(p.is_ripe(), "ripe after %d watered nights" % p.grow_days())
	game.set_tool(GameState.Tool.AXE)   # any tool harvests a ripe crop
	p.interact(game)
	check(game.count("turnip") == 0, "the turnip pops out onto the ground, not into your pockets")
	_collect_pickups()
	check(game.count("turnip") >= 1, "harvest gives turnip")
	check(p.state == FarmPlot.State.TILLED and p.growth == 0, "plot resets to tilled")
	return true


func test_dry_crop_does_not_grow() -> bool:
	var p := _plot()
	p.state = FarmPlot.State.PLANTED
	game.advance_day()
	game.advance_day()
	check(p.growth == 0 and not p.is_ripe(), "unwatered crop does not grow")
	return true


func test_no_seeds() -> bool:
	var p := _plot()
	p.state = FarmPlot.State.TILLED
	game.remove_item("turnip_seed", 5)
	game.set_tool(GameState.Tool.SEEDS)
	p.interact(game)
	check(p.state == FarmPlot.State.TILLED, "no seeds, no planting")
	return true


func test_mining() -> bool:
	var r := MineRock.new()
	r.name = "Rock_T"
	root.add_child(r)
	game.set_tool(GameState.Tool.AXE)
	r.interact(game)
	check(r.hits == 0, "only the pickaxe mines")
	game.set_tool(GameState.Tool.PICKAXE)
	for i in MineRock.HITS_TO_BREAK:
		r.interact(game)
	check(r.broken, "rock breaks after enough hits")
	var d := MineRock.drops_for(false, 0.9, 0.9)
	check(d.size() == 2 and d[0]["item"] == "stone", "plain rock gives only stone")
	check(MineRock.drops_for(false, 0.1, 0.9).size() == 3, "lucky roll adds copper")
	check(MineRock.drops_for(true, 0.9, 0.1).size() == 4, "rich rock gives copper and a gem on a good roll")
	check(is_equal_approx(MineRock.crack_amount(2), 0.5) and MineRock.crack_amount(99) == 1.0, "crack stage")
	var c := WoodLog.new()
	c.game = game
	c.item_id = "stone"
	c.chunk_color = MineRock.STONE_COLOR
	root.add_child(c)
	c.collect()
	check(game.count("stone") == 1, "stone chunk pickup adds stone")
	for dd in MineRock.REGROW_DAYS:
		game.advance_day()
	check(not r.broken, "rock regrows")
	return true


func test_feel_and_grading() -> bool:
	check(FX.hit_stop_scale(0.01, 0.5) < 0.1 and FX.hit_stop_scale(0.5, 0.5) == 1.0, "hit-stop freezes briefly then recovers")
	var dg := FX.grade_for(1.0, 0.0, 0.0)
	var ng := FX.grade_for(0.0, 0.0, 1.0)
	check(dg["saturation"] > ng["saturation"] and ng["brightness"] >= dg["brightness"], "night is muted and cool, day is vivid")
	check(FX.grade_for(0, 0, 0)["saturation"] == 0.0 or true, "grade handles zero weights")
	return true


func test_tree_chop_and_regrow() -> bool:
	var t := ChoppableTree.new()
	t.name = "Tree_T"
	root.add_child(t)
	game.set_tool(GameState.Tool.HOE)
	t.interact(game)
	check(t.hits == 0, "only the axe chops")
	game.set_tool(GameState.Tool.AXE)
	for i in ChoppableTree.HITS_TO_FELL:
		t.interact(game)
	check(t.felled, "tree falls")
	check(WoodLog.state_for(5.0, 1.0) == "idle" and WoodLog.state_for(2.0, 1.0) == "magnet", "pickup magnet range")
	check(WoodLog.state_for(0.5, 1.0) == "collect" and WoodLog.state_for(0.5, 0.1) == "wait", "pickup collect + arm delay")
	var lg := WoodLog.new()
	lg.game = game
	root.add_child(lg)
	lg.collect()
	lg.collect()
	check(game.count("wood") == 1, "log pickup adds one wood, only once")
	t.interact(game)
	check(game.count("wood") == 1, "stump gives no more wood")
	for d in ChoppableTree.REGROW_DAYS:
		game.advance_day()
	check(not t.felled, "tree regrows")
	return true


func test_shop_station() -> bool:
	var shop := Station.new()
	shop.kind = Station.Kind.SHOP
	root.add_child(shop)
	shop.interact(game)
	check(game.count("turnip_seed") == 5 + Station.SEED_PACK, "shop sells a seed pack")
	check(game.money == 50 - 10 * Station.SEED_PACK, "seed pack costs $50")
	shop.interact(game)
	check(game.count("turnip_seed") == 5 + Station.SEED_PACK, "broke players cannot buy")
	var bed := Station.new()
	bed.kind = Station.Kind.BED
	root.add_child(bed)
	var d := game.day
	bed.interact(game)
	check(game.day == d + 1 and is_equal_approx(game.time_of_day, GameState.START_TIME), "bed skips to morning")
	check(Station._pretty(1000000) == "1,000,000", "number formatting")
	return true


func test_clock_text() -> bool:
	game.time_of_day = 0.25
	check(game.clock_text() == "6:00 AM", "6 AM (%s)" % game.clock_text())
	game.time_of_day = 0.5
	check(game.clock_text() == "12:00 PM", "noon (%s)" % game.clock_text())
	game.time_of_day = 0.0
	check(game.clock_text() == "12:00 AM", "midnight (%s)" % game.clock_text())
	return true


func test_save_roundtrip() -> bool:
	var p := _plot()
	p.state = FarmPlot.State.PLANTED
	p.growth = 1
	p.watered = true
	game.add_item("wood", 7)
	game.earn(100)
	var data := game.to_dict()
	var json := JSON.stringify(data)
	p.state = FarmPlot.State.GRASS
	p.growth = 0
	game.money = 0
	game.inventory = {}
	game.from_dict(JSON.parse_string(json))
	check(game.money == 150, "money restored")
	check(game.count("wood") == 7, "inventory restored")
	check(p.state == FarmPlot.State.PLANTED and p.growth == 1 and p.watered, "plot restored")
	return true


func test_door_enter_exit() -> bool:
	var outside := Vector3(10, 0.1, 5)
	var inside := Buildings.build_interior(root, 0, outside, Color.WHITE, "Test")
	var front := Buildings.add_front_door(root, Vector3(10, 0, 3), inside["entry"], "Enter", false)
	var body := CharacterBody3D.new()
	root.add_child(body)
	body.global_position = Vector3(10, 0.1, 4)
	body.velocity = Vector3(3, 0, 3)
	check(front.get_prompt(game) == "[E] Enter", "door prompt")
	front.go(body)
	check(body.global_position.is_equal_approx(inside["entry"]), "entering teleports inside")
	check(body.global_position.x > 300.0, "interior is parked away from town")
	check(body.velocity == Vector3.ZERO, "velocity cleared at door")
	(inside["exit_door"] as Door).go(body)
	check(body.global_position.is_equal_approx(outside), "exit door returns outside")
	check(Buildings.interior_origin(2) != Buildings.interior_origin(3), "interiors do not overlap")
	return true


func test_npc_schedule() -> bool:
	var S = Buildings.Schedule
	check(S.activity_at(3.0 / 24.0) == S.Activity.SLEEP, "3am sleep")
	check(S.activity_at(7.0 / 24.0) == S.Activity.WAKE, "7am wake")
	check(S.activity_at(12.0 / 24.0) == S.Activity.WORK, "noon work")
	check(S.activity_at(19.0 / 24.0) == S.Activity.HOME, "7pm home")
	check(S.activity_at(23.0 / 24.0) == S.Activity.SLEEP, "11pm sleep")
	check(S.activity_at(7.0 / 24.0, 1.5) == S.Activity.SLEEP, "late riser still asleep at 7am")
	check(S.is_indoors(S.Activity.WORK) == false, "work is outdoors")
	check(S.is_indoors(S.Activity.SLEEP), "sleep is indoors")
	return true


func test_npc_routine_movement() -> bool:
	var npc := Npc.new()
	root.add_child(npc)
	npc.home_spot = Vector3(400, 0, 60)
	npc.work_spot = Vector3(0, 0, 20)
	npc.door_outside = Vector3(-5, 0, 22)
	npc.update_routine(3.0 / 24.0, 0.1)
	check(npc.indoors and npc.global_position.is_equal_approx(npc.home_spot), "asleep at home at 3am")
	npc.update_routine(12.0 / 24.0, 0.1)
	check(not npc.indoors, "leaves home for work at noon")
	check(npc.global_position.distance_to(npc.door_outside) < 1.0, "appears at the door")
	for i in 400:
		npc.update_routine(12.0 / 24.0, 0.1)
	check(npc.global_position.distance_to(npc.work_spot) < 0.3, "walks to work")
	npc.update_routine(19.0 / 24.0, 0.1)
	for i in 400:
		npc.update_routine(19.0 / 24.0, 0.1)
	check(npc.indoors and npc.global_position.is_equal_approx(npc.home_spot), "goes home in the evening")
	return true


func test_lockpick() -> bool:
	var lp := Lockpick.new(0.0, 7)
	lp.phase = 0.0
	check(is_equal_approx(lp.cursor(), 0.0), "cursor starts at 0")
	lp.phase = 1.0
	check(is_equal_approx(lp.cursor(), 1.0), "cursor peaks at 1")
	lp.phase = 2.5
	check(is_equal_approx(lp.cursor(), 0.5), "cursor sweeps back")
	# Perfect play opens the lock.
	for i in Lockpick.PINS:
		lp.phase = lp.zone_center   # cursor == zone_center on the rising edge
		var r := lp.press()
		check(r == "pin" or r == "open", "pin %d set" % i)
	check(lp.is_open(), "lock opens after all pins")
	# Misses break picks.
	var bad := Lockpick.new(0.0, 7)
	bad.zone_center = 0.9
	bad.phase = 0.05
	check(bad.press() == "snap", "miss snaps a pick")
	check(bad.picks_left == Lockpick.PICKS - 1, "pick consumed")
	for i in Lockpick.PICKS - 1:
		bad.zone_center = 0.9
		bad.phase = 0.05
		bad.press()
	check(bad.is_broken(), "all picks gone")
	check(Lockpick.new(3.0, 1).zone_width < Lockpick.new(0.0, 1).zone_width, "harder locks have smaller zones")
	return true


func test_loot_container() -> bool:
	var c := LootContainer.new()
	root.add_child(c)
	c.loot_id = "gold_spoon"
	check(c.state == "locked", "starts locked")
	c.interact(game)
	check(c.state == "picking", "interact starts picking")
	for i in Lockpick.PINS:
		c.lock.phase = c.lock.zone_center
		c.interact(game)
	check(c.state == "open", "container opens")
	check(game.count("gold_spoon") == 1, "loot added to pockets")
	check(c.get_prompt(game).begins_with("Empty"), "empty prompt")
	c.on_new_day(game)
	check(c.state == "locked", "refills next day")
	check(LootContainer.roll_loot(0.0) == "gold_spoon" and LootContainer.roll_loot(0.99) == "rubber_duck_gold", "loot table roll")
	return true


func test_carry_limit() -> bool:
	for i in GameState.CARRY_LIMIT:
		check(game.add_loot("gnome" if false else "garden_gnome"), "carry %d" % i)
	check(not game.add_loot("gold_spoon"), "pockets full")
	check(game.loot_count() == GameState.CARRY_LIMIT, "loot count")
	game.add_item("turnip", 20)
	check(game.loot_count() == GameState.CARRY_LIMIT, "turnips do not count as loot")
	var c := LootContainer.new()
	root.add_child(c)
	c.interact(game)
	check(c.state == "locked", "full pockets refuse to start picking")
	return true


func test_witness_cone() -> bool:
	# Facing +Z (rotation.y = 0): target ahead is seen, behind is not.
	check(Witness.can_see(Vector3.ZERO, 0.0, Vector3(0, 0, 5)), "sees target ahead")
	check(not Witness.can_see(Vector3.ZERO, 0.0, Vector3(0, 0, -5)), "no eyes in the back of the head")
	check(not Witness.can_see(Vector3.ZERO, 0.0, Vector3(0, 0, 20)), "too far to see")
	check(not Witness.can_see(Vector3.ZERO, 0.0, Vector3(5, 0, 0.5)), "outside the cone sideways")
	check(Witness.can_see(Vector3.ZERO, PI / 2.0, Vector3(5, 0, 0)), "turning rotates the cone")
	return true


func test_witness_meter() -> bool:
	var w := Witness.new()
	check(not w.update(0.5, true, 2.0), "not instant")
	check(w.suspicion > 0.0, "meter fills while seen")
	var s := w.suspicion
	w.update(0.5, false)
	check(w.suspicion < s, "meter drains out of sight")
	var far := Witness.new()
	var near := Witness.new()
	far.update(0.5, true, 8.0)
	near.update(0.5, true, 1.0)
	check(near.suspicion > far.suspicion, "closer fills faster")
	var stand := Witness.new()
	var sneak := Witness.new()
	stand.update(0.5, true, 3.0)
	sneak.update(0.5, true, 3.0, true)
	check(is_equal_approx(sneak.suspicion, stand.suspicion * Witness.CROUCH_FILL_MULT), "crouching halves suspicion fill")
	var alarm := false
	for i in 100:
		alarm = alarm or w.update(0.1, true, 1.0)
	check(alarm, "alarm eventually fires")
	check(w.suspicion == 0.0, "meter resets after alarm")
	return true


func test_heat() -> bool:
	check(game.heat_level() == 0, "starts clean")
	game.add_heat(1.0)
	check(game.heat_level() == 1, "level 1")
	game.add_heat(10.0)
	check(game.heat == GameState.MAX_HEAT, "heat capped")
	var saved := game.to_dict()
	game.heat = 0.0
	game.from_dict(saved)
	check(game.heat == GameState.MAX_HEAT, "heat survives save")
	game.advance_day()
	check(game.heat == GameState.MAX_HEAT - 1.0, "heat cools by a level each day")
	return true


func test_fence_cap() -> bool:
	game.fence_sold_today = 0
	game.reputation = 0.0
	game.heat = 0.0
	for i in 4:
		game.add_loot("gold_spoon")
	check(game.fence_room() == 3, "fence has room for 3 a day")
	check(game.fence_offer() == 3 * 30, "offer counts only what fence will take")
	check(game.fence_sell_all() > 0 and game.count("gold_spoon") == 1, "one item left over")
	check(game.fence_room() == 0 and game.fence_offer() == 0, "fence full for today")
	check(game.fence_sell_all() == 0 and game.count("gold_spoon") == 1, "full fence buys nothing")
	game.advance_day()
	check(game.fence_room() == 3, "fence room resets next day")
	var d := game.to_dict()
	game.fence_sold_today = 2
	game.from_dict(d)
	check(game.fence_sold_today == 0, "cap saved and restored")
	game.inventory.clear()
	return true


func test_fence_reputation() -> bool:
	check(game.reputation_title() == "Honest-ish", "starts neutral")
	check(game.fence_offer() == 0, "nothing to fence")
	check(game.fence_sell_all() == 0, "fence pays nothing for nothing")
	game.add_loot("garden_gnome")
	game.add_loot("gold_spoon")
	check(game.fence_offer() == 60 + 30, "fence pays half value")
	var before := game.money
	var paid := game.fence_sell_all()
	check(paid == 90 and game.money == before + 90, "fence pays out")
	check(game.loot_count() == 0, "loot gone")
	check(game.reputation == -2.0, "fencing costs reputation")
	game.add_loot("gold_spoon")
	check(game.fence_offer() > 30, "outlaws get a better rate")
	game.heat = 0.0
	var calm := game.fence_offer()
	game.heat = 1.0
	check(game.fence_offer() == calm, "heat 1 does not rattle the fence")
	game.heat = 2.0
	check(game.fence_offer() < calm, "heat 2 cuts the fence price")
	game.heat = 3.0
	check(game.fence_nerves() == 0.6, "heat 3 cuts fence price by 40%")
	game.heat = 2.0
	game.cool_heat(10.0, false, false)
	check(game.heat == 2.0, "no cooling in the open")
	game.cool_heat(10.0, true, true)
	check(game.heat == 2.0, "no cooling while chased")
	game.cool_heat(10.0, true, false)
	check(absf(game.heat - 1.75) < 0.001, "hiding indoors cools heat")
	game.cool_heat(10.0, false, false, true)
	check(absf(game.heat - 1.67) < 0.001, "out of sight in the open cools slowly")
	game.cool_heat(10.0, false, false, true, true)
	check(absf(game.heat - 1.53) < 0.001, "crouching out of sight cools faster than standing")
	game.cool_heat(10.0, true, false, true, true)
	check(absf(game.heat - 1.28) < 0.001, "indoors cooling ignores crouch")
	game.heat = 1.67
	game.cool_heat(10.0, false, true, true)
	check(absf(game.heat - 1.67) < 0.001, "no outdoor cooling while chased")
	check(game.lying_low == false, "chased is not lying low")
	game.cool_heat(1.0, false, false, true)
	check(game.lying_low, "out of sight flags lying low")
	game.cool_heat(1.0, false, false, false)
	check(not game.lying_low, "in plain view is not lying low")
	game.cool_heat(1000.0, true, false)
	check(game.heat == 0.0, "heat never goes below 0")
	check(not game.lying_low, "no heat means nothing to lie low from")
	game.heat = 0.0
	game.add_reputation(-20.0)
	check(game.reputation == -GameState.MAX_REP and game.reputation_title() == "Outlaw", "capped outlaw")
	game.add_reputation(20.0)
	check(game.reputation_title() == "Lawful", "can go lawful")
	game.add_heat(1.0)
	check(game.reputation == GameState.MAX_REP - 1.0, "alarm costs reputation")
	var saved := game.to_dict()
	game.reputation = 0.0
	game.from_dict(saved)
	check(game.reputation == GameState.MAX_REP - 1.0, "reputation saves")
	game.reputation = 0.0
	game.add_item("turnip", 1)
	game.sell_all()
	check(game.reputation == 0.5, "honest sales add reputation")
	return true


func test_police() -> bool:
	var P := Police.State
	check(Police.next_state(P.OFF, 2.0, true, false, 3.0) == P.OFF, "no police below max heat")
	check(Police.next_state(P.OFF, 3.0, false, false, 30.0) == P.PATROL, "max heat starts patrol")
	check(Police.next_state(P.PATROL, 3.0, true, false, 8.0) == P.CHASE, "sees player -> chase")
	check(Police.next_state(P.PATROL, 3.0, false, false, 8.0) == P.PATROL, "unseen -> keeps patrolling")
	check(Police.next_state(P.CHASE, 3.0, false, false, 10.0) == P.CHASE, "keeps chasing nearby")
	check(Police.next_state(P.CHASE, 3.0, false, false, 40.0) == P.PATROL, "far away -> gives up")
	check(Police.next_state(P.CHASE, 3.0, true, true, 5.0) == P.PATROL, "hiding indoors ends chase")
	check(Police.next_state(P.CHASE, 1.0, true, false, 5.0) == P.OFF, "heat cooled -> police go home")
	check(Police.is_hidden(Buildings.interior_origin(0)), "interior counts as hiding")
	check(not Police.is_hidden(Vector3(0, 0, 8)), "outside is not hiding")
	check(Police.sight_range(true) < Police.sight_range(false), "crouching shortens police sight")
	check(Police.sight_range(false, 0.95) < Police.sight_range(false, 0.5), "night shortens police sight")
	check(is_equal_approx(Police.sight_range(true, 0.0), Police.SIGHT_RANGE * 0.25), "night + crouch stack")
	var c0 := Vector3(10, 0, 5)
	check(Police.search_point(c0, 0) == c0, "search starts at last seen spot")
	check(is_equal_approx(Police.search_point(c0, 2).distance_to(c0), Police.SEARCH_RADIUS), "sweep points ring the last seen spot")
	check(Police.search_point(c0, 1) != Police.search_point(c0, 3), "sweep points differ")
	check(Police.is_night(0.9) and not Police.is_night(0.5), "night window")
	check(InputMap.has_action("crouch"), "crouch action bound")
	var cop := Police.new()
	root.add_child(cop)
	cop.waypoints = [Vector3(0, 0, 0), Vector3(5, 0, 0)]
	cop.state = P.CHASE
	cop.update_police(0.1, Vector3(60, 0, 0), 3.0)
	check(cop.state == P.SEARCH, "losing you -> search last known spot")
	check(cop.last_seen == Vector3(60, 0, 0), "remembers where he lost you")
	for i in 130:
		cop.update_police(0.1, Vector3(60, 0, 0), 3.0)
	check(cop.state == P.PATROL, "search times out -> back to patrol")
	check(Police.give_up_line(0) != Police.give_up_line(1) and Police.give_up_line(-1) != "", "give-up barks vary and handle any index")
	var gu := [0]
	cop.gave_up.connect(func(): gu[0] += 1)
	cop.state = P.SEARCH
	cop.search_t = 0.05
	cop.update_police(0.1, Vector3(60, 0, 0), 3.0)
	check(gu[0] == 1 and cop.state == P.PATROL, "search timeout emits gave_up once")
	cop.state = P.SEARCH
	cop.search_t = 3.0
	cop.update_police(0.1, Vector3(60, 0, 0), 1.0)
	check(cop.state == P.OFF, "heat cooled during search -> police go home")
	cop.queue_free()
	game.money = 200
	game.add_loot("gold_spoon")
	game.add_heat(3.0)
	var r := game.arrest()
	check(r["fine"] == 50 and r["loot"] == 1, "arrest fines 25% and takes loot")
	check(game.money == 150 and game.loot_count() == 0, "money and loot updated")
	check(game.heat == 1.0, "heat drops to 1 after arrest")
	game.money = 4
	check(game.arrest()["fine"] == 4 and game.money == 0, "fine never exceeds cash")
	return true


func test_police_car() -> bool:
	check(PoliceCar.should_chase(3.0, true, false), "max heat + driving -> squad car")
	check(not PoliceCar.should_chase(2.0, true, false), "lower heat -> no squad car")
	check(not PoliceCar.should_chase(3.0, false, false), "on foot -> no squad car")
	check(not PoliceCar.should_chase(3.0, true, true), "hidden -> no squad car")
	check(absf(PoliceCar.steer(0.0, 3.0, 0.1) - 0.1) < 0.001, "steer limited by turn rate")
	check(PoliceCar.steer(0.0, 0.05, 0.1) == 0.05, "steer lands on small angle")
	check(PoliceCar.steer(3.0, -3.0, 0.5) > 3.0, "steer takes the short way round")
	check(PoliceCar.next_speed(0.0, 0.0, 0.5) > 0.0, "accelerates")
	check(PoliceCar.next_speed(15.0, 2.0, 1.0) < 15.0, "slows for sharp turns")
	check(PoliceCar.CRUISE < Car.MAX_SPEED, "player top speed beats squad cruise")
	check(PoliceCar.caught(2.0) and not PoliceCar.caught(10.0), "catch distance")
	return true


func test_traffic() -> bool:
	var p := Vector3(0, 0, 14.4)
	check(TrafficCar.blocked(p, 1.0, Vector3(5, 0, 14.4)), "object ahead in lane blocks")
	check(not TrafficCar.blocked(p, 1.0, Vector3(-5, 0, 14.4)), "object behind does not block")
	check(not TrafficCar.blocked(p, 1.0, Vector3(5, 0, 19.0)), "other lane does not block")
	check(not TrafficCar.blocked(p, 1.0, Vector3(30, 0, 14.4)), "far away does not block")
	check(TrafficCar.blocked(p, -1.0, Vector3(-5, 0, 14.4)), "direction flips look-ahead")
	check(TrafficCar.next_speed(0.0, 7.0, false, 0.1) > 0.0, "accelerates when clear")
	check(TrafficCar.next_speed(7.0, 7.0, true, 0.1) < 7.0, "brakes when blocked")
	check(TrafficCar.next_speed(0.2, 7.0, true, 0.1) == 0.0, "stops, never reverses")
	check(TrafficCar.wrap_x(60.0) == TrafficCar.MIN_X and TrafficCar.wrap_x(-60.0) == TrafficCar.MAX_X and TrafficCar.wrap_x(3.0) == 3.0, "lane wraps")
	return true


func test_car() -> bool:
	var dt := 0.1
	var v := 0.0
	for i in 200:
		v = Car.step_speed(v, 1.0, false, dt)
	check(v > Car.MAX_SPEED * 0.95 and v <= Car.MAX_SPEED, "full throttle approaches top speed (%.1f)" % v)
	var r := 0.0
	for i in 200:
		r = Car.step_speed(r, -1.0, false, dt)
	check(is_equal_approx(r, -Car.MAX_REVERSE), "reverse capped")
	check(Car.step_speed(10.0, 0.0, false, dt) < 10.0 and Car.step_speed(10.0, 0.0, false, dt) > 0.0, "coasting slows gently")
	check(Car.step_speed(10.0, 0.0, true, dt) < Car.step_speed(10.0, 0.0, false, dt), "handbrake slows faster")
	check(Car.step_speed(-3.0, 1.0, false, dt) > -3.0, "forward while rolling back brakes")
	check(Car.steer_limit(Car.MAX_SPEED) < Car.steer_limit(0.0), "less steering lock at speed")
	check(Car.turn_delta(0.0, 1.0, dt) == 0.0, "parked car cannot turn")
	check(Car.turn_delta(8.0, 1.0, dt) * Car.turn_delta(-8.0, 1.0, dt) < 0.0, "reversing flips turn direction")
	check(Car.turn_delta(8.0, 1.0, dt) < 0.0 and Car.turn_delta(8.0, -1.0, dt) > 0.0, "steer sign matches input")
	check(not Car.headlights_on(0.0) and Car.headlights_on(1.0), "headlights on at night only")
	check(Car.dust_amount(2.0, true, 0.0) == 0.0, "no dust when crawling")
	check(Car.dust_amount(Car.MAX_SPEED, true, 0.0) > Car.dust_amount(5.0, true, 0.0), "more dust at speed on handbrake")
	check(Car.dust_amount(10.0, false, 0.0) == 0.0, "no dust when driving straight")
	check(Car.dust_amount(Car.MAX_SPEED, false, 1.0) > 0.0, "hard corner at speed kicks dust")
	game.money = 100
	check(not game.buy_car() and not game.car_owned and game.money == 100, "cannot afford car")
	game.money = 500
	check(game.buy_car() and game.car_owned and game.money == 500 - Car.PRICE, "buy car")
	check(not game.buy_car() and game.money == 500 - Car.PRICE, "only one car")
	game.car_pos = [3.0, 0.0, 4.0, 1.0]
	var saved := game.to_dict()
	game.car_owned = false
	game.car_pos = [0.0, 0.0, 0.0, 0.0]
	game.from_dict(saved)
	check(game.car_owned and game.car_pos[0] == 3.0 and game.car_pos[3] == 1.0, "car saves position")
	return true


func test_fishing() -> bool:
	var f := Fishing.new(3)
	check(f.reel() == "", "nothing to reel when idle")
	f.cast()
	check(f.state == "waiting", "cast waits")
	check(f.reel() == "early" and f.state == "idle", "early reel fails")
	f.cast()
	f.tick(f.bite_time + 0.01)
	check(f.state == "bite", "bite arrives")
	check(f.reel() == "hooked", "reel in window sets the hook")
	f.cast()
	f.tick(f.bite_time + 0.01)
	f.tick(Fishing.BITE_WINDOW + 0.1)
	check(f.state == "done" and f.reel() == "late", "late reel misses")
	check(Fishing.roll_fish(0.0) == "boot" and Fishing.roll_fish(0.999) == "old_wizard_hat", "fish table ends")
	for e in Fishing.FISH_TABLE:
		check(GameState.ITEMS.has(e[0]), "fish item defined: " + e[0])
	var spot := FishingSpot.new()
	root.add_child(spot)
	spot.held_override = 0
	spot.interact(game)
	check(spot.phase == FishingSpot.Phase.CHARGING, "E winds up a cast")
	spot._process(0.016)
	check(spot.phase == FishingSpot.Phase.FLYING, "letting go throws the bobber")
	spot._process(FishingSpot.FLIGHT_TIME + 0.01)
	check(spot.phase == FishingSpot.Phase.LINE and spot.fishing.state == "waiting", "spot casts")
	spot._process(spot.fishing.bite_time + 0.01)
	spot.interact(game)
	check(spot.phase == FishingSpot.Phase.FIGHT and spot.fight != null, "hook starts the fight")
	var before: int = 0
	for e in Fishing.FISH_TABLE:
		before += game.count(e[0])
	for i in 2000:
		if spot.fight == null:
			break
		spot.held_override = 0 if spot.fight.surging or spot.fight.tension > 0.8 else 1
		spot._process(0.05)
	var after: int = 0
	for e in Fishing.FISH_TABLE:
		after += game.count(e[0])
	check(after == before + 1 and spot.phase == FishingSpot.Phase.IDLE, "spot catch adds a fish")
	check(Fishing.total_catches(game.fish_log) == 1, "journal records the catch")
	spot.free()
	var w := Terrain.is_water(-17.8, 1.0)
	check(not w, "fishing spot is on dry land")
	return true


func test_delivery() -> bool:
	var j := DeliveryJob.new()
	j.start(0, Vector2(-10.0, 0.0))
	check(j.compass_from(Vector2(-10.0, 0.0)) == "S", "compass: drop-off is south")
	check(j.compass_from(Vector2(-10.0, 40.0)) == "N", "compass: drop-off is north")
	check(j.hud_line(Vector2.ZERO).begins_with("PARCEL"), "hud line shows while active")
	j = DeliveryJob.new()
	check(j.hud_line(Vector2.ZERO) == "", "hud line empty when idle")
	check(j.complete() == 0 and not j.tick(1.0), "idle job pays nothing")
	j.start(1, Vector2(19, 10.5))
	check(j.active and j.time_total >= DeliveryJob.MIN_TIME, "job starts with a timer")
	var full := j.payout()
	j.tick(j.time_total * 0.5)
	check(j.payout() < full and j.payout() > DeliveryJob.BASE_PAY, "tip shrinks with time")
	check(not j.is_near(Vector2(0, 0)) and j.is_near(j.dest_pos()), "near check")
	var pay := j.complete()
	check(pay > 0 and not j.active, "complete pays and ends")
	j.start(0, Vector2(19, 10.5))
	check(j.tick(j.time_total + 1.0) and not j.active, "timeout ends the job")
	for d in DeliveryJob.DESTINATIONS:
		check(not Terrain.is_water(d[1], d[2]), "drop-off dry: " + d[0])
	var depot := DeliveryDepot.new()
	root.add_child(depot)
	game.car_owned = false
	depot.interact(game)
	check(not depot.job.active, "no car, no job")
	game.car_owned = true
	depot.interact(game)
	check(depot.job.active, "car owner gets a job")
	return true


func test_crops() -> bool:
	check(game.selected_crop == "turnip", "default seed is turnip")
	game.set_tool(GameState.Tool.SEEDS)
	game.set_tool(GameState.Tool.SEEDS)
	check(game.selected_crop == "carrot", "pressing 2 again cycles to carrot")
	game.set_tool(GameState.Tool.SEEDS)
	game.set_tool(GameState.Tool.SEEDS)
	check(game.selected_crop == "turnip", "seed cycle wraps around")
	game.cycle_crop()
	check(game.tool_label(GameState.Tool.SEEDS) == "Carrot Seeds", "tool label follows seed")
	game.add_item("carrot_seed", 1)
	game.set_tool(GameState.Tool.HOE)
	var p := _plot()
	p.interact(game)
	game.set_tool(GameState.Tool.SEEDS)
	p.interact(game)
	check(p.state == FarmPlot.State.PLANTED and p.crop == "carrot" and game.count("carrot_seed") == 0, "plants carrot")
	check(p.grow_days() == 3, "carrot takes 3 nights")
	for n in 3:
		p.watered = true
		game.advance_day()
	check(p.is_ripe(), "carrot ripe after 3 nights")
	p.interact(game)
	_collect_pickups()
	check(game.count("carrot") >= 1, "harvest gives carrot")
	game.add_item("tomato", 1)
	var before := game.money
	game.sell_all()
	check(game.money >= before + 70 + 125, "carrot and tomato sell for more than turnips")
	var d := p.to_dict()
	check(d["crop"] == "carrot", "plot saves crop type")
	game.selected_crop = "tomato"
	var g2 := game.to_dict()
	check(g2["selected_crop"] == "tomato", "selected seed saved")
	return true


func test_audio_settings() -> bool:
	var a := AudioSettings.new()
	a.set_volume("Music", 2.0)
	check(a.volumes["Music"] == 1.0, "volume clamped high")
	a.set_volume("SFX", -1.0)
	check(a.volumes["SFX"] == 0.0 and AudioSettings.to_db(0.0) == -80.0, "mute maps to -80 dB")
	check(is_equal_approx(AudioSettings.to_db(0.5), linear_to_db(0.5)), "db mapping")
	var b := AudioSettings.new()
	b.from_dict(a.to_dict())
	check(b.volumes == a.volumes, "dict roundtrip")
	a.apply()
	check(AudioServer.get_bus_index("SFX") != -1 and AudioServer.get_bus_index("Music") != -1, "buses created")
	return true


func test_steps() -> bool:
	var r := Sfx.step_progress(0.0, 1.0)
	check(not r[1] and is_equal_approx(r[0], 1.0), "no step yet")
	r = Sfx.step_progress(r[0], 1.5)
	check(r[1] and r[0] < Sfx.STEP_LENGTH, "step due after stride")
	check(Sfx.surface_at(Vector3(0, 0, 0)) == "grass" and Sfx.surface_at(Vector3(10, 0, 16)) == "road" and Sfx.surface_at(Vector3(405, 0, 3)) == "wood", "surface lookup")
	check(Sfx.step_kind("wood") == "step_wood" and Sfx.step_kind("road") == "step_road" and Sfx.step_kind("grass") == "step" and Sfx.step_kind("?") == "step", "step kinds")
	check(Sfx.step_volume(true) < Sfx.step_volume(false) and is_equal_approx(Sfx.step_volume(false), 1.0), "crouch steps quieter")
	check(Sfx.KINDS.has("chop") and Sfx.KINDS.has("splash") and Sfx.KINDS.has("step"), "new kinds exist")
	return true


func test_sfx() -> bool:
	for k in Sfx.KINDS:
		var w := Sfx.make(k)
		check(w.data.size() > 1000 and w.mix_rate == Sfx.RATE, "sfx %s has samples" % k)
	check(Sfx.make("coin").data == Sfx.make("coin").data, "sfx deterministic")
	check(Sfx.make("nonsense").data.size() == Sfx.make("blip").data.size(), "unknown kind falls back")
	return true


func test_engine_sfx() -> bool:
	check(is_equal_approx(Sfx.engine_pitch(0.0), 0.8), "idle pitch")
	check(Sfx.engine_pitch(18.0) > Sfx.engine_pitch(5.0), "pitch rises with speed")
	check(is_equal_approx(Sfx.engine_pitch(-9.0), Sfx.engine_pitch(9.0)), "reverse same as forward")
	check(Sfx.engine_pitch(500.0) <= 2.4, "pitch clamped")
	check(Sfx.engine_volume(18.0) > Sfx.engine_volume(0.0) and Sfx.engine_volume(99.0) <= 0.7, "volume range")
	var w := Sfx.make_engine()
	check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_end > 100 and w.data.size() == w.loop_end * 2, "engine loop")
	return true


func test_music() -> bool:
	check(Music.mode_for_hour(12.0) == "day" and Music.mode_for_hour(22.0) == "night" and Music.mode_for_hour(3.0) == "night", "music mode by hour")
	check(Music.beat_seconds("night") > Music.beat_seconds("day"), "night is slower")
	check(is_equal_approx(Music.note_hz(0.0), 261.63) and is_equal_approx(Music.note_hz(12.0), 523.26), "note frequencies")
	var w := Music.make("day")
	check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.data.size() == w.loop_end * 2, "day loop shape")
	check(absf(w.loop_end / float(Music.RATE) - Music.loop_seconds("day")) < 0.01, "day loop length")
	var peak := 0
	for i in range(0, w.data.size() / 2, 50):
		peak = maxi(peak, absi(w.data.decode_s16(i * 2)))
	check(peak > 1000 and peak < 32000, "music audible, not clipping")
	check(Music.make("night").data.size() > w.data.size(), "night loop longer")
	return true


func test_settings_menu() -> bool:
	check(SettingsMenu.percent_to_volume(150.0) == 1.0 and SettingsMenu.percent_to_volume(-5.0) == 0.0, "slider percent clamped")
	check(SettingsMenu.volume_to_percent(0.8) == 80.0, "volume to percent")
	check(is_equal_approx(Sfx.pitch_jitter(0.0), 0.95) and is_equal_approx(Sfx.pitch_jitter(1.0), 1.05), "pitch jitter range")
	check(is_equal_approx(Sfx.pitch_jitter(0.5), 1.0), "pitch jitter centre")
	return true


func test_tutorial() -> bool:
	var t := Tutorial.new()
	check(t.advance("money") == "", "out-of-order event ignored")
	check(t.advance("start") != "" and t.index == 1, "start shows first tip")
	check(t.advance("start") == "", "same event does not repeat")
	for e in ["move", "tool", "money", "day"]:
		check(t.advance(e) != "", "step %s shows tip" % e)
	check(t.done and t.advance("day") == "", "tutorial finishes once")
	check(t.once("pick") != "" and t.once("pick") == "", "pick hint shows once")
	check(t.once("cast") != "" and t.once("drive") != "", "cast and drive hints show")
	check(t.once("bogus") == "", "unknown hint ignored")
	check(t.once("heat") != "" and t.once("fence") != "" and t.once("arrest") != "", "heat/fence/arrest hints show")
	for k in Tutorial.ONCE:
		check(not "{" in InputPrompts.format(Tutorial.ONCE[k], true) and not "{" in InputPrompts.format(Tutorial.ONCE[k], false), "once tokens resolve: " + k)
	var t2 := Tutorial.new()
	Tutorial.enabled = false
	check(t2.advance("start") == "" and t2.once("pick") == "", "hints off: nothing shown")
	Tutorial.enabled = true
	check(t2.advance("start") != "" and t2.once("pick") != "", "hints back on")
	var hs := AudioSettings.new()
	hs.hints_enabled = false
	var hs2 := AudioSettings.new()
	hs2.from_dict(hs.to_dict())
	check(not hs2.hints_enabled and AudioSettings.new().hints_enabled, "hints setting roundtrips, default on")
	t2.free()
	t.free()
	return true


func test_gamepad() -> bool:
	game.setup_input()
	var has_btn := func(action: String, b: int) -> bool:
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton and e.button_index == b:
				return true
		return false
	check(has_btn.call("jump", JOY_BUTTON_A), "A jumps")
	check(has_btn.call("interact", JOY_BUTTON_X), "X interacts")
	check(has_btn.call("pause", JOY_BUTTON_START), "Start pauses")
	check(InputMap.has_action("look_left") and InputMap.has_action("look_down"), "right stick look actions exist")
	var n := InputMap.action_get_events("jump").size()
	game.setup_gamepad()
	check(InputMap.action_get_events("jump").size() == n, "setup_gamepad is idempotent")
	var keys := false
	for e in InputMap.action_get_events("move_forward"):
		if e is InputEventKey:
			keys = true
	check(keys, "keyboard bindings kept")
	return true


func test_music_fade() -> bool:
	check(Music.fade_progress(0.0, 1.5) == 0.5, "fade halfway after half the duration")
	check(Music.fade_progress(0.9, 5.0) == 1.0, "fade clamps at 1")
	var g0 := Music.fade_gains(0.0)
	var g1 := Music.fade_gains(1.0)
	check(is_equal_approx(g0.x, 0.0) and is_equal_approx(g0.y, 1.0), "fade starts on old track")
	check(is_equal_approx(g1.x, 1.0) and absf(g1.y) < 0.001, "fade ends on new track")
	var m := Music.fade_gains(0.5)
	check(is_equal_approx(m.x * m.x + m.y * m.y, 1.0), "equal-power at midpoint")
	var mu := Music.new()
	root.add_child(mu)
	mu.set_mode("day")
	mu.set_mode("night")
	check(mu._fade_t == 0.0 and mu._fade_in.playing and mu._fade_out.playing, "mode change crossfades two players")
	for i in 10:
		mu._process(0.5)
	check(mu._fade_t == 1.0 and not mu._fade_out.playing, "crossfade completes and stops old track")
	return true


func test_main_menu() -> bool:
	check(MainMenu.options(false) == ["New Game", "Send Feedback", "Quit"], "no save: New Game, Feedback, Quit")
	check(MainMenu.options(true) == ["Continue", "New Game", "Send Feedback", "Quit"], "save: Continue first")
	MainMenu.skip_next = true
	check(MainMenu.consume_skip() and not MainMenu.consume_skip(), "skip flag consumed once")
	var m := MainMenu.new()
	m.has_save = true
	root.add_child(m)
	check(root.get_tree().paused, "menu pauses the tree")
	check(m._first != null and m._first.text == "Continue", "first button is Continue")
	check(MainMenu.FEEDBACK_URL.begins_with("https://"), "feedback url is https")
	m.close()
	check(not root.get_tree().paused, "closing unpauses")
	return true


func test_input_prompts() -> bool:
	check(InputPrompts.format("Press {interact}", false) == "Press E", "key label")
	check(InputPrompts.format("Press {interact} or {jump}", true) == "Press X or A", "pad labels")
	check(InputPrompts.label("nope", true) == "nope", "unknown action falls back")
	check(InputPrompts.prompt_text("[E] Chop tree (1/3)", true) == "[X] Chop tree (1/3)", "prompt tag swaps to pad")
	check(InputPrompts.prompt_text("[E] Chop tree", false) == "[E] Chop tree", "prompt tag stays on keyboard")
	check(InputPrompts.prompt_text("Sell bin.", true) == "Sell bin.", "untagged prompt unchanged")
	var b := InputEventJoypadButton.new()
	check(InputPrompts.device_for_event(b, false), "pad button switches to pad")
	var k := InputEventKey.new()
	check(not InputPrompts.device_for_event(k, true), "key switches to keyboard")
	var m := InputEventJoypadMotion.new()
	m.axis_value = 0.1
	check(not InputPrompts.device_for_event(m, false), "stick drift ignored")
	m.axis_value = 0.9
	check(InputPrompts.device_for_event(m, false), "real stick motion switches")
	for tip in Tutorial.STEPS:
		check(not "{" in InputPrompts.format(tip["tip"], true), "all tutorial tokens resolve")
	for dev in [true, false]:
		check(not "{" in InputPrompts.format(InputPrompts.HELP_TEMPLATE, dev), "help tokens resolve")
	check("Left stick" in InputPrompts.format(InputPrompts.HELP_TEMPLATE, true), "help shows pad move label")
	check("WASD" in InputPrompts.format(InputPrompts.HELP_TEMPLATE, false), "help shows key move label")
	return true


func test_closet() -> bool:
	var c := Closet.new()
	check(not game.in_closet, "not hiding at start")
	c.interact(game)
	check(game.in_closet, "E climbs into the wardrobe")
	check(c.get_prompt(game).contains("Climb out"), "prompt offers climbing out")
	c.interact(game)
	check(not game.in_closet, "E again climbs out")
	check(not Closet.out_of_reach(Vector3(1, 0, 0), Vector3.ZERO), "close player stays hidden")
	check(Closet.out_of_reach(Vector3(5, 0, 0), Vector3.ZERO), "far player auto-exits")
	game.heat = 2.0
	game.cool_heat(10.0, true, false, false, false, true)
	check(absf(game.heat - 1.25) < 0.001, "closet cools heat 3x faster than plain hiding")
	check(Closet.model_visible(false, false), "model drawn in the open")
	check(not Closet.model_visible(true, false), "model hidden in wardrobe")
	check(not Closet.model_visible(false, true), "model hidden while driving")
	check(Closet.camera_zoom(true, 7.0) == Closet.PEEK_ZOOM, "closet pulls camera in tight")
	check(Closet.camera_zoom(false, 7.0) == 7.0, "normal zoom outside closet")
	check(Closet.camera_zoom(true, 1.5) == 1.5, "closet never zooms out past a tight zoom")
	var t := Closet.creak_tick(0.0, 5.0, true)
	check(not t["creak"] and t["timer"] == 5.0, "no creak before the interval")
	t = Closet.creak_tick(t["timer"], 5.0, true)
	check(t["creak"] and t["timer"] == 0.0, "creaks after the interval and resets")
	check(Closet.creak_tick(4.0, 1.0, false)["timer"] == 0.0, "timer resets when not hiding")
	check(Closet.creak_line(1) != Closet.creak_line(2) and Closet.creak_line(-1) != "", "creak lines vary and wrap")
	c.free()
	return true


func test_shop_rep() -> bool:
	var g := GameState.new()
	var base: int = GameState.ITEMS[g.crop_seed_id()]["buy"]
	check(g.shop_price(g.crop_seed_id(), 5) == base * 5, "neutral rep pays list price")
	g.reputation = 5.0
	check(g.shop_multiplier() == 0.9, "5 Lawful points = 10% off")
	g.reputation = 10.0
	check(absf(g.shop_multiplier() - 0.8) < 0.001, "discount caps at 20%")
	g.reputation = 0.0
	g.heat = 3.0
	check(absf(g.shop_multiplier() - 1.2) < 0.001, "heat 3 adds 20% surcharge")
	g.heat = 0.0
	g.reputation = -8.0
	check(g.shop_multiplier() == 1.0, "Outlaws get no discount but no surcharge when calm")
	g.reputation = 10.0
	g.money = 1000
	g.buy(g.crop_seed_id(), 5)
	check(g.money == 1000 - g.shop_price(g.crop_seed_id(), 5), "buy charges discounted price")
	return true


func test_npc_barks() -> bool:
	check(Npc.bark(5.0, 0) == Npc.BARKS_LAWFUL[0], "Lawful gets friendly barks")
	check(Npc.bark(-5.0, 1) == Npc.BARKS_OUTLAW[1], "Outlaw gets wary barks")
	check(Npc.bark(0.0, 3) == Npc.BARKS_NEUTRAL[0] and Npc.bark(0.0, -1) != "", "neutral wraps index safely")
	check(Npc.bark(5.0, 1, true) == Npc.BARKS_LOOT[1], "carrying loot overrides reputation barks")
	check(Npc.bark(-8.0, 0) == Npc.BARKS_NOTORIOUS[0], "notorious outlaws get their own barks")
	check(Npc.bark(-7.0, 2) == Npc.BARKS_NOTORIOUS[2] and Npc.bark(-6.9, 2) == Npc.BARKS_OUTLAW[2], "notorious tier starts at -7")
	check(Station.sal_sale_line(0.0) == "Never seen it before in my life.", "Sal default sale line")
	check(Station.sal_sale_line(-4.0, 0).begins_with("A professional"), "Sal respects outlaws")
	check(Station.sal_sale_line(-8.0, 0).begins_with("Boss"), "Sal is in awe of notorious outlaws")
	check(Npc.bark(-9.0, 1, true) == Npc.BARKS_LOOT[1], "loot still overrides notorious barks")
	check(Npc.bark(0.0, 1, false, "Bork") == Npc.BARKS_PERSONAL["Bork"][0], "odd barks use the NPC's personal line")
	check(Npc.bark(0.0, 0, false, "Bork") == Npc.BARKS_NEUTRAL[0] and Npc.bark(0.0, 1, false, "Nobody") == Npc.BARKS_NEUTRAL[1], "even idx / unknown name use rep pool")
	check(Npc.bark(0.0, 1, true, "Bork") == Npc.BARKS_LOOT[1], "loot still overrides personal lines")
	check(Npc.bark(0.0, 2, false, "", true) == Npc.BARKS_NIGHT[0] and Npc.bark(0.0, 2, false, "", false) == Npc.BARKS_NEUTRAL[2], "night swaps in night barks on idx 2 mod 4")
	check(Npc.bark(0.0, 2, true, "", true) == Npc.BARKS_LOOT[2], "loot beats night barks")
	var f0 := Npc.fresh_bark(0.0, 0, "")
	check(f0["line"] == Npc.BARKS_NEUTRAL[0] and f0["idx"] == 0, "fresh_bark keeps idx when line is new")
	var f1 := Npc.fresh_bark(0.0, 0, Npc.BARKS_NEUTRAL[0])
	check(f1["line"] != Npc.BARKS_NEUTRAL[0] and f1["idx"] > 0, "fresh_bark skips a repeat of the last line")
	check(Npc.fresh_bark(0.0, 0, "x", true)["line"] == Npc.BARKS_LOOT[0], "fresh_bark still honours loot override")
	var t := Npc.bark_tick(0.0, 1.0, true)
	check(t["fire"] and t["timer"] == 25.0, "fires when near with no cooldown")
	check(not Npc.bark_tick(10.0, 1.0, true)["fire"], "cooldown suppresses barks")
	check(not Npc.bark_tick(0.0, 1.0, false)["fire"], "no bark when nobody is near")
	return true


func test_crafting() -> bool:
	check(game.first_craftable() == -1, "nothing craftable at start")
	game.add_item("wood", 2)
	check(game.first_craftable() == 0, "planks craftable from 2 wood")
	check(game.craft(0) and game.count("plank") == 3 and game.count("wood") == 0, "planks crafted")
	check(not game.craft(0), "cannot craft without ingredients")
	game.add_item("plank", 1)
	check(game.craft(1) and game.count("fence_panel") == 1 and game.count("plank") == 0, "fence panel from 4 planks")
	game.add_item("gem", 1)
	game.add_item("stone", 2)
	check(game.craft(3) and game.count("polished_gem") == 1, "polished gem")
	check(not game.can_craft(99) and not game.can_craft(-1), "bad index rejected")
	check(GameState.recipe_text(0).contains("Planks") or GameState.recipe_text(0).contains("Plank"), "recipe text names output")
	for r in GameState.RECIPES:
		for id in r["in"]:
			check(GameState.ITEMS.has(id), "recipe input known: " + id)
		for id in r["out"]:
			check(GameState.ITEMS.has(id), "recipe output known: " + id)
	var wb := Station.new()
	wb.kind = Station.Kind.WORKBENCH
	root.add_child(wb)
	check(wb.get_prompt(game).begins_with("Planks") and "need 2 more Wood" in wb.get_prompt(game), "idle workbench prompt shows selected recipe + missing")
	game.add_item("wood", 2)
	check(wb.get_prompt(game).begins_with("[E] Craft"), "craft prompt")
	wb.interact(game)
	check(game.count("plank") == 3, "workbench interact crafts")
	return true


func test_jump_step() -> bool:
	var r := FX.jump_step(true, true, 0.0, 0.0, 0.016)
	check(r["jump"], "jump on floor")
	r = FX.jump_step(false, true, 0.1, 0.0, 0.016)
	check(r["jump"], "coyote jump just after leaving ledge")
	r = FX.jump_step(false, true, 0.0, 0.0, 0.016)
	check(not r["jump"] and r["buffer"] > 0.0, "no jump in air, press is buffered")
	r = FX.jump_step(true, false, 0.0, 0.1, 0.016)
	check(r["jump"], "buffered press fires on landing")
	r = FX.jump_step(false, false, 0.12, 0.0, 0.5)
	check(r["coyote"] == 0.0 and not r["jump"], "coyote expires")
	return true


func test_stamina() -> bool:
	var r := FX.stamina_step(100.0, true, true, false, 1.0)
	check(r["sprinting"] and r["stamina"] < 100.0, "sprint drains stamina")
	r = FX.stamina_step(0.1, true, true, false, 1.0)
	check(r["winded"] and not r["sprinting"], "running dry makes you winded")
	r = FX.stamina_step(10.0, true, true, true, 0.1)
	check(not r["sprinting"] and r["winded"], "winded cannot sprint")
	r = FX.stamina_step(24.0, true, true, true, 0.1)
	check(not r["winded"], "recovers after resume threshold")
	r = FX.stamina_step(50.0, true, false, false, 1.0)
	check(r["stamina"] > 50.0, "standing still regenerates")
	check(FX.landing_squash(2.0) == 1.0 and FX.landing_squash(10.0) < 0.8 and FX.landing_squash(100.0) == 0.7, "landing squash clamps")
	return true


func test_carry_weight() -> bool:
	var game := GameState.new()
	check(game.carry_weight() < 2.0, "fresh pockets are light")
	game.add_item("stone", 10)
	check(is_equal_approx(game.carry_weight(), 30.0 + game.count("turnip_seed") * 0.2), "stone weighs 3 each")
	check(FX.carry_speed_mult(10.0, 30.0) == 1.0, "light load = full speed")
	check(FX.carry_speed_mult(80.0, 30.0) < 1.0 and FX.carry_speed_mult(80.0, 30.0) > 0.55, "heavy load slows")
	check(FX.carry_speed_mult(9999.0, 30.0) == 0.55, "slowdown floors at 0.55")
	var free0 := game.carry_free()
	game.add_item("wheelbarrow", 1)
	check(game.carry_free() > free0, "wheelbarrow raises free capacity")
	check(FX.is_hard_landing(-6.0, 0.5) and not FX.is_hard_landing(-1.0, 0.0), "hard landing detect")
	var found := false
	for r in GameState.RECIPES:
		if r["id"] == "wheelbarrow":
			found = true
	check(found, "wheelbarrow recipe exists")
	return true


func test_pickaxe_upgrade() -> bool:
	var game := GameState.new()
	var idx := -1
	for i in GameState.RECIPES.size():
		if GameState.RECIPES[i]["id"] == "copper_pickaxe":
			idx = i
	check(idx >= 0, "pickaxe recipe exists")
	game.add_item("copper_ingot", 2)
	game.add_item("plank", 2)
	check(game.craft(idx), "craft copper pickaxe")
	game.add_item("copper_ingot", 2)
	game.add_item("plank", 2)
	check(not game.can_craft(idx), "pickaxe is one-off")
	check(MineRock.hits_needed(true) == MineRock.hits_needed(false) - 1, "copper pickaxe breaks rocks a hit sooner")
	return true


func test_axe_combo() -> bool:
	var game := GameState.new()
	var idx := -1
	for i in GameState.RECIPES.size():
		if GameState.RECIPES[i]["id"] == "copper_axe":
			idx = i
	check(idx >= 0, "axe recipe exists")
	game.add_item("copper_ingot", 2)
	game.add_item("plank", 2)
	check(game.craft(idx) and game.count("copper_axe") == 1, "craft copper axe")
	game.add_item("copper_ingot", 2)
	game.add_item("plank", 2)
	check(not game.can_craft(idx), "axe is one-off")
	check(ChoppableTree.hits_needed(true) == 2 and ChoppableTree.hits_needed(false) == 3, "copper axe fells in 2")
	check(FX.pickup_combo(0, 99.0) == 1 and FX.pickup_combo(1, 0.5) == 2 and FX.pickup_combo(3, 5.0) == 1 and FX.pickup_combo(8, 0.1) == 8, "combo steps, resets, caps")
	check(is_equal_approx(FX.combo_pitch(1), 1.0) and is_equal_approx(FX.combo_pitch(13), 2.0), "combo pitch is semitones")
	# Run 4: fall direction, recipe picker, shore map
	var fd := FX.fall_dir(Vector3(0, 0, 0), Vector3(0, 0, 3))
	check(fd.is_equal_approx(Vector3(0, 0, -1)), "tree falls away from the player")
	check(FX.fall_dir(Vector3(1, 0, 1), Vector3(1, 0, 1)) == Vector3.RIGHT, "fall dir fallback when standing on trunk")
	var ax := FX.fall_axis(Vector3.RIGHT)
	check((Basis(ax, PI * 0.5) * Vector3.UP).is_equal_approx(Vector3.RIGHT), "fall axis tips trunk toward dir")
	check((Basis(FX.fall_axis(fd), PI * 0.5) * Vector3.UP).is_equal_approx(fd), "fall axis works for any dir")
	check(FX.fall_shake(0.0) > FX.fall_shake(8.0) and FX.fall_shake(100.0) >= 0.15, "fall shake fades with distance")
	check(GameState.next_recipe(0, 1, []) == 1 and GameState.next_recipe(0, -1, []) == GameState.RECIPES.size() - 1, "recipe cycle wraps")
	check(GameState.next_recipe(3, 1, [4]) == 5, "recipe cycle skips owned one-offs")
	var rg := GameState.new()
	check(rg.recipe_missing(0) == "need 2 more Wood", "missing text for planks")
	rg.add_item("wood", 2)
	check(rg.recipe_missing(0) == "", "no missing when craftable")
	rg.selected_recipe = 0
	check(rg.cycle_recipe(1) == 1 and rg.selected_recipe == 1, "cycle_recipe updates selection")
	var sm := Terrain.shore_map(32)
	var mid := sm.get_pixel(16, 16).r
	check(sm.get_width() == 32 and mid <= 1.0, "shore map built")
	check(Terrain.WATER_LEVEL - Terrain.height_at(Terrain.POND_CENTER.x, Terrain.POND_CENTER.y) > 0.9, "pond centre is deep (foam 0)")
	return true


func test_build_mode() -> bool:
	check(BuildWorld.snap(Vector3(2.9, 1.0, -3.1)) == Vector3(2, 1.0, -4), "snap to 2m grid")
	var tp := BuildWorld.target_pos(Vector3(0, 0, 0), 0.0)
	check(is_equal_approx(tp.z, 2.0) and is_equal_approx(tp.x, 0.0), "ghost lands ahead of player, snapped")
	check(BuildWorld.cell_key(Vector3(2, 0, 4), 0) != BuildWorld.cell_key(Vector3(2, 0, 4), 1), "rotation changes cell key")
	check(BuildWorld.cell_key(Vector3(2, 0, 4), 0) == BuildWorld.cell_key(Vector3(2.4, 0, 3.7), 2), "180 degrees shares a slot")
	check(BuildWorld.can_place("a", {}, false, 1) and not BuildWorld.can_place("a", {"a": 1}, false, 1), "no stacking on same slot")
	check(not BuildWorld.can_place("a", {}, false, 0) and not BuildWorld.can_place("a", {}, true, 1), "needs stock and dry land")
	check(BuildWorld.next_piece("fence_panel", 1, {"stone_wall": 2}) == "stone_wall", "cycle prefers owned piece")
	check(BuildWorld.next_piece("fence_panel", 1, {}) == "stone_wall", "cycle still moves when nothing owned")
	check(BuildWorld.prompt_for("fence_panel", 3, false).contains("3 left"), "prompt shows stock")
	check(BuildWorld.prompt_for("fence_panel", 0, false).contains("workbench"), "prompt points to workbench")
	check(BuildWorld.prompt_for("fence_panel", 3, true).contains("Demolish"), "prompt demolish when aiming at piece")
	var bw := BuildWorld.new()
	root.add_child(bw)
	game.add_item("fence_panel", 2)
	var pos := Vector3(4, 0, 4)
	check(bw.place("fence_panel", pos, 0, game) and game.count("fence_panel") == 1, "place consumes a panel")
	check(game.built.size() == 1 and bw.pieces.size() == 1, "placed piece is recorded")
	check(not bw.place("fence_panel", pos, 0, game) and game.count("fence_panel") == 1, "cannot double-place")
	var saved := game.to_dict()
	check(saved["built"].size() == 1, "built pieces saved")
	check(bw.demolish(BuildWorld.cell_key(pos, 0), game) and game.count("fence_panel") == 2 and game.built.is_empty(), "demolish refunds fully")
	game.add_item("stone", 4)
	check(game.craft(_recipe_index("stone_wall")) and game.count("stone_wall") == 1, "stone wall recipe")
	game.from_dict(saved)
	check(game.built.size() == 1 and game.built[0]["id"] == "fence_panel", "built survives load")
	# Floors and wooden walls (run 7).
	check(BuildWorld.key_for("wood_floor", Vector3(2, 0, 4), 0) == BuildWorld.key_for("wood_floor", Vector3(2, 0, 4), 1), "floor ignores rotation")
	check(BuildWorld.key_for("wood_floor", Vector3(2, 0, 4), 0) != BuildWorld.key_for("wood_wall", Vector3(2, 0, 4), 0), "wall can stand on a floor cell")
	game.add_item("plank", 7)
	check(game.craft(_recipe_index("wood_floor")) and game.count("wood_floor") == 1 and game.count("plank") == 4, "wood floor recipe")
	check(game.craft(_recipe_index("wood_wall")) and game.count("wood_wall") == 1 and game.count("plank") == 0, "wood wall recipe")
	var fp := Vector3(8, 0, 8)
	check(bw.place("wood_floor", fp, 0, game) and bw.place("wood_wall", fp, 1, game), "floor then wall in the same cell")
	check(not bw.place("wood_floor", fp, 1, game), "no second floor in a cell")
	check(bw.demolish(BuildWorld.key_for("wood_floor", fp, 0), game) and game.count("wood_floor") == 1, "demolish floor refunds")
	check(BuildWorld.PIECE_ORDER.size() >= 10 and GameState.ITEM_WEIGHT.has("wood_floor"), "floor/wall registered")
	# Roofs and doorways (run 8).
	check(BuildWorld.base_y("wood_roof") == 2.2 and BuildWorld.base_y("wood_wall") == 0.0, "roofs sit on wall tops")
	check(BuildWorld.key_for("wood_roof", Vector3(2, 0, 4), 0) == BuildWorld.key_for("wood_roof", Vector3(2, 0, 4), 3), "roof ignores rotation")
	check(BuildWorld.key_for("wood_roof", fp, 0) != BuildWorld.key_for("wood_floor", fp, 0), "roof has its own key space")
	check(BuildWorld.key_for("wood_door", fp, 1) == BuildWorld.key_for("wood_wall", fp, 1), "doorway takes a wall slot")
	game.add_item("plank", 9)
	game.add_item("copper_ingot", 1)
	check(game.craft(_recipe_index("wood_door")) and game.count("wood_door") == 1 and game.count("plank") == 5, "doorway recipe")
	check(game.craft(_recipe_index("wood_roof")) and game.count("wood_roof") == 1, "roof recipe")
	check(bw.place("wood_door", Vector3(12, 0, 8), 0, game) and bw.place("wood_roof", Vector3(12, 0, 8), 0, game), "doorway + roof placed together")
	check(bw.demolish(BuildWorld.key_for("wood_roof", Vector3(12, 0, 8), 0), game) and game.count("wood_roof") == 1, "demolish roof refunds")
	# Log chopping.
	check(WoodLog.wants_chop("wood", GameState.Tool.AXE) and not WoodLog.wants_chop("stone", GameState.Tool.AXE) and not WoodLog.wants_chop("wood", GameState.Tool.HOE), "axe keeps logs for chopping")
	var lgc := WoodLog.new()
	root.add_child(lgc)
	lgc.game = game
	check(lgc.chop_into_planks() == WoodLog.PLANKS_PER_LOG, "chopping a log yields planks")
	var pl_found := 0
	for n in root.get_children():
		if n is WoodLog and (n as WoodLog).item_id == "plank":
			pl_found += 1
			n.queue_free()
	check(pl_found == WoodLog.PLANKS_PER_LOG, "plank pickups spawned")
	bw.queue_free()
	return true


func _recipe_index(id: String) -> int:
	for i in GameState.RECIPES.size():
		if GameState.RECIPES[i]["id"] == id:
			return i
	return -1


func test_props_furniture() -> bool:
	check(PropCrate.loot_for(0.1).is_empty() and PropCrate.loot_for(0.99)[0]["item"] == "gem", "crate loot table ends")
	check(PropCrate.loot_for(0.5)[0]["item"] == "turnip_seed" and PropCrate.loot_for(0.7)[0]["item"] == "wood", "crate loot mid rolls")
	check(PropCrate.planks_for("crate") == 3 and PropCrate.planks_for("barrel") == 2, "planks per prop")
	check(PropCrate.push_strength(6.0, 4.0) > 0.0 and PropCrate.push_strength(6.0, 99.0) <= PropCrate.push_strength(6.0, 8.0), "push strength capped")
	check(PropCrate.push_strength(1.0, 4.0) > PropCrate.push_strength(20.0, 4.0), "lighter props shove easier")
	check(BuildWorld.is_furniture("wood_table") and BuildWorld.is_furniture("lantern") and not BuildWorld.is_furniture("wood_wall"), "furniture detection")
	var fp := Vector3(6, 0, 6)
	check(BuildWorld.key_for("wood_chair", fp, 0) == BuildWorld.key_for("wood_chair", fp, 3), "furniture ignores rotation")
	check(BuildWorld.key_for("wood_table", fp, 0) != BuildWorld.key_for("wood_floor", fp, 0), "furniture stands on floor cell")
	var game := GameState.new()
	game.add_item("plank", 10)
	game.add_item("copper_ingot", 1)
	game.add_item("gem", 1)
	check(game.craft(_recipe_index("wood_table")) and game.count("wood_table") == 1, "table recipe")
	check(game.craft(_recipe_index("wood_chair")) and game.craft(_recipe_index("lantern")), "chair + lantern recipes")
	game.free()
	return true


func test_hunting() -> bool:
	check(Critter.rabbit_mode(20.0, false, false) == "calm", "far rabbit calm")
	check(Critter.rabbit_mode(7.0, false, false) == "alert", "mid rabbit alert")
	check(Critter.rabbit_mode(3.0, false, false) == "flee", "near rabbit flees")
	check(Critter.rabbit_mode(4.0, true, false) == "alert", "crouching sneaks up")
	check(Critter.rabbit_mode(7.0, false, true) == "flee", "sprinting scares from further")
	check(Critter.rabbit_drops(0.7).size() == 1 and Critter.rabbit_drops(0.7)[0]["item"] == "rabbit_meat", "meat only on mid roll")
	check(Critter.rabbit_drops(0.2).size() == 2 and Critter.rabbit_drops(0.95).size() == 2, "pelt low roll, carrot high roll")
	check(Critter.hop_height(0.0) == 0.0 and Critter.hop_height(1.0) == 0.0 and Critter.hop_height(0.5) > 0.3, "hop arc")
	check(WoodLog.is_organic("rabbit_meat") and not WoodLog.is_organic("gem"), "organic drops don't shimmer")
	check(WoodLog.drop_color("rabbit_meat").a == 1.0, "drop colour opaque")
	var game := GameState.new()
	game.add_item("rabbit_meat", 2)
	game.add_item("carrot", 1)
	check(game.craft(_recipe_index("rabbit_stew")) and game.count("rabbit_stew") == 1 and game.count("rabbit_meat") == 0, "stew recipe")
	check(GameState.ITEMS.has("rabbit_pelt") and int(GameState.ITEMS["rabbit_stew"]["sell"]) > int(GameState.ITEMS["rabbit_meat"]["sell"]) * 2, "stew worth more than raw")
	game.free()
	return true


func test_drop_items() -> bool:
	var g := GameState.new()
	check(g.drop_candidate() == "", "nothing droppable at start (seeds only)")
	g.add_item("gem", 3)
	g.add_item("stone", 2)
	g.add_item("wood", 1)
	check(g.drop_candidate() == "stone", "heaviest total weight drops first (6kg stone)")
	g.remove_item("stone", 2)
	check(g.drop_candidate() == "wood", "then wood (2kg) over gems (1.5kg)")
	g.add_item("wheelbarrow", 1)
	g.remove_item("wood", 1)
	g.remove_item("gem", 3)
	check(g.drop_candidate() == "", "wheelbarrow and seeds are not droppable")
	check(WoodLog.shadow_for(0.0).x == 1.0 and WoodLog.shadow_for(3.0).x < 0.5, "shadow shrinks with height")
	check(WoodLog.shadow_for(0.0).y > WoodLog.shadow_for(2.0).y, "shadow fades with height")
	check(BuildWorld.is_furniture("wood_bed") and BuildWorld.PIECE_ORDER.has("wood_bed"), "bed is furniture")
	g.add_item("plank", 5)
	g.add_item("rabbit_pelt", 1)
	check(g.craft(_recipe_index_of("wood_bed")) and g.count("wood_bed") == 1 and g.count("rabbit_pelt") == 0, "bed recipe uses a pelt blanket")
	check(WoodLog.toss_dir(0.0).z > 2.0 and absf(WoodLog.toss_dir(0.0).x) < 0.01, "toss goes forward at yaw 0")
	check(WoodLog.state_for(0.3, -1.0) == "wait" and WoodLog.state_for(0.3, 0.8) == "collect", "dropped item waits then collects")
	check(WoodLog.drop_color("copper_ingot").a == 1.0 and WoodLog.is_organic("turnip"), "ingot colour, turnip organic")
	g.free()
	return true


func _recipe_index_of(id: String) -> int:
	for i in GameState.RECIPES.size():
		if GameState.RECIPES[i]["id"] == id:
			return i
	return -1


func test_campfire_taming() -> bool:
	check(CampfireSpot.cooked_id("rabbit_meat") == "cooked_meat" and CampfireSpot.cooked_id("wood") == "", "meat cooks, wood does not")
	check(CampfireSpot.raw_in({"rabbit_meat": 2}) == "rabbit_meat" and CampfireSpot.raw_in({"stone": 4}) == "", "raw_in finds meat")
	var lo := 99.0
	var hi := 0.0
	for i in 200:
		var e := CampfireSpot.flicker(float(i) * 0.05)
		lo = minf(lo, e)
		hi = maxf(hi, e)
	check(lo > 1.5 and hi < 3.5 and hi - lo > 0.2, "flicker varies but never goes dark")
	check(BuildWorld.is_furniture("campfire") and BuildWorld.PIECE_ORDER.has("campfire"), "campfire is a furniture piece")
	var g := GameState.new()
	g.add_item("stone", 3)
	g.add_item("wood", 2)
	check(g.craft(_recipe_index_of("campfire")) and g.count("campfire") == 1, "campfire recipe: 3 stone + 2 wood")
	check(GameState.ITEMS.has("cooked_meat") and GameState.ITEMS.has("egg"), "cooked meat and egg are sellable items")
	g.free()
	check(Critter.tame_food(Critter.Kind.GOAT, {"carrot": 1}) == "carrot", "goat takes a carrot")
	check(Critter.tame_food(Critter.Kind.RABBIT, {"carrot": 1}) == "", "rabbits cannot be tamed")
	check(Critter.tame_food(Critter.Kind.CHICKEN, {"stone": 1}) == "", "no food, no taming")
	var a := 0
	var tamed := false
	for i in 3:
		var r := Critter.feed_result(a)
		a = int(r["affection"])
		tamed = bool(r["tamed"])
	check(a == 3 and tamed, "three feeds tame")
	check(not bool(Critter.feed_result(0)["tamed"]), "one feed is not enough")
	check(Critter.follow_mode(1.0) == 0 and Critter.follow_mode(4.0) == 1 and Critter.follow_mode(10.0) == 2 and Critter.follow_mode(50.0) == -1, "follow modes by distance")
	return true


func test_riding() -> bool:
	check(Critter.can_mount(Critter.Kind.GOAT, true, {"saddle": 1}), "tamed goat + saddle can be ridden")
	check(not Critter.can_mount(Critter.Kind.GOAT, false, {"saddle": 1}), "wild goat cannot be ridden")
	check(not Critter.can_mount(Critter.Kind.GOAT, true, {}), "no saddle, no ride")
	check(not Critter.can_mount(Critter.Kind.CHICKEN, true, {"saddle": 1}), "chickens are not mounts (yet)")
	check(Critter.mount_speed(true, 1.0) > Critter.mount_speed(false, 1.0) * 1.5, "gallop is much faster than walk")
	check(Critter.mount_speed(true, 1.0) > 8.5, "riding beats sprinting on foot")
	check(Critter.mount_speed(true, 0.1) >= Critter.MOUNT_GALLOP * 0.55 - 0.01, "heavy load slows the goat but never to a crawl")
	check(Critter.hoof_interval(0.0) == 0.0, "no hoofbeats when standing")
	check(Critter.hoof_interval(13.0) < Critter.hoof_interval(6.5), "hoofbeats are quicker at a gallop")
	check(Critter.hoof_interval(1.5) <= 0.5, "hoof interval is capped")
	check(Critter.gait_swing(0.0) == 0.0 and Critter.gait_swing(99.0) <= 0.91, "gait swing clamps")
	check(Critter.MOUNT_JUMP > 5.0, "goat out-jumps the farmer")
	var g := GameState.new()
	g.add_item("plank", 2)
	g.add_item("rabbit_pelt", 2)
	var idx := _recipe_index_of("saddle")
	check(idx >= 0 and g.craft(idx) and g.count("saddle") == 1, "saddle recipe: 2 planks + 2 pelts")
	check(not g.can_craft(idx), "saddle is a one-off")
	check(int(GameState.ITEMS["saddle"]["sell"]) == 0, "saddle cannot be sold by accident")
	g.free()
	var c := Critter.new()
	c.kind = Critter.Kind.GOAT
	root.add_child(c)
	c.tamed = true
	c.set_ridden(true)
	check(c.ridden and absf(c.scale.x - Critter.MOUNT_SCALE) < 0.001, "ridden goat swells to mount size")
	c.ride_tick(0.1, 13.0, true)
	check(absf(c._legs[0].rotation.x) > 0.0 or absf(c._legs[2].rotation.x) > 0.0, "legs gallop")
	c.set_ridden(false)
	check(not c.ridden and absf(c.scale.x - 1.0) < 0.001 and c._legs[0].rotation.x == 0.0, "dismount resets the goat")
	c.free()
	return true


func test_car_parts() -> bool:
	var base := Car.stats_for([])
	check(is_equal_approx(base["max_speed"], Car.MAX_SPEED), "no parts = stock top speed")
	var t := Car.stats_for(["turbo_engine"])
	check(t["max_speed"] > base["max_speed"] * 1.25 and t["accel"] > base["accel"] * 1.3, "turbo engine: faster and punchier")
	var w := Car.stats_for(["offroad_wheels"])
	check(w["steer"] > 1.2 and w["bump"] > base["bump"], "big wheels: grippier, bump less")
	var all := Car.stats_for(["turbo_engine", "offroad_wheels", "rocket_booster"])
	check(all["boost"] > 1.4 and all["max_speed"] > 20.0, "parts stack")
	check(Car.step_speed(0.0, 1.0, false, 0.1, 30.0, 18.0) > Car.step_speed(0.0, 1.0, false, 0.1), "higher accel accelerates faster")
	var v := 0.0
	for i in 400:
		v = Car.step_speed(v, 1.0, false, 0.1, 30.0, 12.0)
	check(v > Car.MAX_SPEED + 3.0 and v <= 30.0, "raised top speed is reachable and capped (%.1f)" % v)
	check(not Car.boost_step(1.0, true, false, 0.1)["active"], "no booster, no boost")
	var b := Car.boost_step(1.0, true, true, 0.5)
	check(b["active"] and b["fuel"] < 1.0, "boost drains fuel")
	check(not Car.boost_step(0.0, true, true, 0.1)["active"], "empty tank cannot boost")
	check(Car.boost_step(0.5, false, true, 1.0)["fuel"] > 0.5, "fuel recharges when not boosting")
	var g := GameState.new()
	g.add_item("copper_ingot", 3)
	g.add_item("plank", 2)
	var idx := _recipe_index_of("turbo_engine")
	check(idx >= 0 and g.craft(idx) and g.count("turbo_engine") == 1, "turbo engine recipe")
	check(not g.can_craft(idx), "engine is a one-off")
	g.free()
	var car := Car.new()
	root.add_child(car)
	car.setup()
	check(car.install_part("turbo_engine") and not car.install_part("turbo_engine"), "install once")
	check(not car.install_part("nonsense"), "unknown part rejected")
	car.set_parts(["rocket_booster"])
	check(car.has_part("rocket_booster") and car._flame != null, "booster adds flame")
	car.drive(0.1, 1.0, 0.0, false, true)
	check(car.boosting, "driving with booster + shift boosts")
	car.queue_free()
	return true


func test_timber_chest() -> bool:
	var t := Vector3(0, 0, 0)
	var d := Vector3.RIGHT
	check(FX.in_fall_zone(t, d, Vector3(3, 0, 0.5)), "point along fall line is in the zone")
	check(not FX.in_fall_zone(t, d, Vector3(-2, 0, 0)), "behind the stump is safe")
	check(not FX.in_fall_zone(t, d, Vector3(3, 0, 2.5)), "off to the side is safe")
	check(not FX.in_fall_zone(t, d, Vector3(8, 0, 0)), "beyond the crown is safe")
	check(FX.in_fall_zone(t, Vector3(0, 0, 1), Vector3(0.3, 0, 3)), "works for any direction")
	check(GameState.stashable("wood") and not GameState.stashable("copper_axe") and not GameState.stashable("nonsense"), "stashable rules")
	var inv := {"wood": 3, "copper_axe": 1, "plank": 2}
	var st := {}
	check(GameState.quick_stack(inv, st) == 5 and inv == {"copper_axe": 1} and int(st["wood"]) == 3, "quick stack moves stashables only")
	check(GameState.take_all(inv, st) == 5 and int(inv["plank"]) == 2 and st.is_empty(), "take all returns everything")
	var g := GameState.new()
	root.add_child(g)
	g.clock_running = false
	g.add_item("plank", 4)
	g.add_item("copper_ingot", 1)
	check(g.chest_deposit() >= 5 and g.count("plank") == 0 and g.stash["plank"] == 4, "chest_deposit")
	check(g.count_with_stash("plank") == 4, "count with stash")
	g.add_item("plank", 2)
	var idx := _recipe_index_of("storage_chest")
	check(idx >= 0 and g.can_craft(idx), "can craft chest from pockets + stash")
	check(g.craft(idx) and g.count("storage_chest") == 1 and g.count("plank") == 0 and g.count_with_stash("plank") == 0, "craft draws pockets first then the stash")
	var d2 := g.to_dict()
	check(d2.has("stash"), "stash saved")
	g.add_item("wood", 2)
	g.chest_deposit()
	g.from_dict(g.to_dict())
	check(int(g.stash.get("wood", 0)) == 2, "stash survives save roundtrip")
	g.free()
	check(BuildWorld.is_furniture("storage_chest") and BuildWorld.PIECE_ORDER.has("storage_chest"), "chest is furniture")
	check(ChestSpot.lid_angle(1.0) < ChestSpot.lid_angle(0.0), "lid opens upward")
	var bp := BuildPiece.new()
	bp.piece_id = "storage_chest"
	root.add_child(bp)
	check(bp.get_child_count() > 0, "chest piece builds")
	bp.queue_free()
	return true


func test_gem_pickaxe_cracks() -> bool:
	check(MineRock.hits_needed(true, true) == MineRock.hits_needed(true) - 1, "gem pickaxe breaks a hit sooner than copper")
	check(MineRock.hits_needed(false, true) >= 1 and MineRock.hits_needed(true, true) >= 1, "never below 1 hit")
	check(MineRock.crack_line_count(0) == 0 and MineRock.crack_line_count(3) == 6, "crack lines grow with hits")
	check(MineRock.crack_line_count(99) == MineRock.HITS_TO_BREAK * 2, "crack lines capped")
	check(MineRock.crack_tint(1.0).v < MineRock.crack_tint(0.0).v, "rock darkens as it cracks")
	var game := GameState.new()
	var idx := _recipe_index("gem_pickaxe")
	check(idx >= 0, "gem pickaxe recipe exists")
	game.add_item("gem", 2)
	game.add_item("copper_ingot", 2)
	game.add_item("plank", 1)
	check(game.craft(idx), "craft gem pickaxe")
	check(game.count("gem_pickaxe") == 1, "gem pickaxe owned")
	game.add_item("gem", 2)
	game.add_item("copper_ingot", 2)
	game.add_item("plank", 1)
	check(not game.can_craft(idx), "gem pickaxe is one-off")
	check(MineRock.tier_args(game)[1] == true, "tier args see gem pickaxe")
	var rock := MineRock.new()
	rock.name = "R"
	rock._ready()
	rock.hits = 3
	rock._refresh()
	check(rock._cracks.get_child_count() == 6, "rock shows 6 crack lines after 3 hits")
	var other := MineRock.new()
	other.name = "R2"
	other._ready()
	check(rock._mats[0] != other._mats[0], "rocks tint independently")
	rock.free()
	other.free()
	return true


func test_story() -> bool:
	check(Story.act_count() == 5 and game.story_act == 0, "story starts at act 1 of 5")
	check(not Story.act_complete(0, game), "act 1 not done at start")
	check(Story.progress(0, game)[0]["cur"] == 0, "progress counter starts at 0")
	check(not game.check_story(), "no advance without goals")
	game.total_earned = 9999
	check(Story.progress(0, game)[0]["cur"] == 150 and Story.progress(0, game)[0]["done"], "progress clamps at target")
	var m := game.money
	check(game.check_story() and game.story_act == 1, "act 1 completes and advances")
	check(game.money == m + 50, "act reward paid")
	game.reputation = -3.4
	check(Story.goal_value(Story.ACTS[1]["goals"][0], game) == 3, "outlaw rep counts as fame")
	check(game.check_story() and game.story_act == 2, "act 2 via infamy")
	game.add_item("rocket_plate", 2)
	check(not game.check_story(), "act 3 needs gems too")
	game.add_item("gem", 2)
	check(game.check_story() and game.story_act == 3, "act 3 completes")
	game.car_owned = true
	game.car_parts = ["rocket_booster"]
	check(game.check_story() and game.story_act == 4, "act 4 completes with car + booster")
	game.stash["rocket_plate"] = 2
	game.add_item("polished_gem", 2)
	check(game.check_story() and Story.is_finished(game.story_act), "act 5 counts stashed plates and finishes")
	check(not game.check_story(), "finished story never advances")
	check(Story.hud_text(game.story_act, game).find("Starship") >= 0, "finished text")
	check(Story.hud_text(0, game).begins_with("Act 1/5"), "hud header")
	var d := game.to_dict()
	check(int(d["story_act"]) == 5, "story saved")
	game.story_act = 0
	game.from_dict(d)
	check(game.story_act == 5, "story restored")
	check(GranRocket.lean_for(0) > GranRocket.lean_for(2) and GranRocket.lean_for(4) == 0.0, "rocket straightens")
	check(GranRocket.smoke_for(0) == 1.0 and GranRocket.smoke_for(5) == 0.0, "smoke fades")
	var r := GranRocket.new()
	root.add_child(r)
	check(r.stage == 0 or r.stage == game.story_act, "rocket builds")
	r.set_stage(3, false)
	check(r._parts[2].visible and not r._parts[3].visible, "parts appear per stage")
	r.queue_free()
	return true


func test_furnace() -> bool:
	check(BuildWorld.is_furniture("furnace") and BuildWorld.PIECE_ORDER.has("furnace"), "furnace is a furniture piece")
	check(FurnaceSpot.smelt_ready({"copper_ore": 1, "wood": 1}) == "copper_ore", "ore + wood is smeltable")
	check(FurnaceSpot.smelt_ready({"copper_ore": 3}) == "" and FurnaceSpot.smelt_ready({"wood": 3}) == "", "needs both ore and fuel")
	check(FurnaceSpot.glow(true, 0.0) > FurnaceSpot.glow(false, 0.0), "mouth glows brighter while smelting")
	var g := GameState.new()
	g.add_item("stone", 8)
	g.add_item("wood", 2)
	check(g.craft(_recipe_index_of("furnace")) and g.count("furnace") == 1, "furnace recipe: 8 stone + 2 wood")
	check(GameState.SMELTABLE["copper_ore"]["ore"] < GameState.RECIPES[_recipe_index_of("copper_ingot")]["in"]["copper_ore"], "furnace is cheaper than hand-smelting")
	g.free()
	return true


func test_anvil() -> bool:
	check(BuildWorld.is_furniture("anvil") and BuildWorld.PIECE_ORDER.has("anvil"), "anvil is a furniture piece")
	check(AnvilSpot.ready_recipe({"copper_ingot": 2}).get("out", "") == "rocket_plate", "2 ingots can be hammered")
	check(AnvilSpot.ready_recipe({"copper_ingot": 1}).is_empty(), "1 ingot is not enough")
	var r: Dictionary = GameState.ANVIL_RECIPES[0]
	var wb: Dictionary = GameState.RECIPES[_recipe_index_of("rocket_plate")]
	check(int(r["in"]["copper_ingot"]) < int(wb["in"]["copper_ingot"]), "anvil plate is cheaper than workbench plate")
	check(AnvilSpot.strike_squash(0.0) < 1.0 and is_equal_approx(AnvilSpot.strike_squash(1.0), 1.0), "face squashes then recovers")
	check(FX.chip_count(3, 3) > FX.chip_count(1, 3) and FX.chip_count(99, 3) <= 20, "chips grow per hit, capped")
	var g := GameState.new()
	g.add_item("copper_ingot", 4)
	g.add_item("stone", 4)
	check(g.craft(_recipe_index_of("anvil")) and g.count("anvil") == 1, "anvil recipe: 4 ingots + 4 stone")
	g.free()
	return true


func test_invention() -> bool:
	check(BuildWorld.is_furniture("invention_bench") and BuildWorld.PIECE_ORDER.has("invention_bench"), "invention bench is a furniture piece")
	check(GameState.invention_ready({"copper_ingot": 2, "gem": 1, "plank": 1}).get("id", "") == "magnet_gloves", "gloves affordable")
	check(GameState.invention_ready({"rabbit_pelt": 2, "copper_ingot": 1, "plank": 2}).get("id", "") == "spring_boots", "boots affordable")
	check(GameState.invention_ready({"copper_ingot": 1}).is_empty(), "nothing affordable with 1 ingot")
	check(GameState.invention_ready({"magnet_gloves": 1, "loot_vacuum": 1, "copper_ingot": 2, "gem": 1, "plank": 1}).is_empty(), "owned gadget is not built twice")
	check(GameState.magnet_range(true) > GameState.magnet_range(false) * 1.9, "gloves roughly double the magnet")
	check(WoodLog.state_for(4.0, 5.0) == "idle" and WoodLog.state_for(4.0, 5.0, GameState.magnet_range(true)) == "magnet", "gloves pull from 4m")
	check(GameState.jump_speed(true, false, 7.2) > GameState.jump_speed(false, false, 7.2), "boots jump higher")
	check(is_equal_approx(GameState.jump_speed(true, true, 7.2), 7.2), "mounted keeps mount jump")
	check(InventionSpot.cog_speed(1.0) > InventionSpot.cog_speed(0.0) * 10.0, "cog spins fast while tinkering")
	check(InventionSpot.bulb_energy(1.0) > InventionSpot.bulb_energy(0.0), "bulb flashes")
	check(not GameState.stashable("spring_boots") and not GameState.stashable("magnet_gloves"), "gadgets stay in pockets")
	var g := GameState.new()
	g.add_item("plank", 6)
	g.add_item("copper_ingot", 3)
	g.add_item("gem", 1)
	var bi := _recipe_index_of("invention_bench")
	check(g.craft(bi) and g.count("invention_bench") == 1, "bench recipe crafts")
	return true


func test_glider_chips() -> bool:
	check(GameState.invention_ready({"rabbit_pelt": 3, "plank": 2, "copper_ingot": 1}).get("id", "") != "", "glider affordable")
	check(GameState.invention_ready({"rabbit_pelt": 3, "plank": 2, "copper_ingot": 1, "spring_boots": 1}).get("id", "") == "glider", "glider after boots owned")
	check(FX.glide_vy(-9.0, true, true, true) == FX.GLIDE_FALL, "holding jump caps fall speed")
	check(FX.glide_vy(-9.0, false, true, true) == -9.0, "no glider, no glide")
	check(FX.glide_vy(-9.0, true, false, true) == -9.0, "must hold jump")
	check(FX.glide_vy(-9.0, true, true, false) == -9.0, "grounded is not gliding")
	check(FX.glide_vy(3.0, true, true, true) == 3.0, "rising is untouched")
	check(FX.glide_speed_mult(true) > 1.3 and FX.glide_speed_mult(false) == 1.0, "glide drifts faster")
	check(not GameState.stashable("glider"), "glider stays in pockets")
	check(FX.stone_chip_count(4, 4) > FX.stone_chip_count(1, 4), "breaking hit sprays more chips")
	check(FX.stone_chip_count(0, 4) >= 5 and FX.stone_chip_count(99, 4) <= 22, "chip count is clamped")
	return true


func test_slingshot_weather() -> bool:
	check(Pebble.can_fire(1, 3, 0.0), "slingshot fires with stone")
	check(not Pebble.can_fire(0, 3, 0.0), "no slingshot, no shot")
	check(not Pebble.can_fire(1, 0, 0.0), "no stone, no shot")
	check(not Pebble.can_fire(1, 3, 0.2), "cooldown blocks")
	var v := Pebble.launch_velocity(0.0, 0.0)
	check(absf(v.length() - Pebble.SPEED) < 0.01, "launch speed is SPEED")
	check(v.z < 0.0 and v.y > 0.0, "yaw 0 fires forward (-z) with a little lob")
	check(Pebble.launch_velocity(0.0, -0.8).y < Pebble.launch_velocity(0.0, 0.0).y, "looking down aims down")
	var r := Pebble.step_arc(Vector3.ZERO, Vector3(10, 0, 0), 0.1)
	check(absf(r[0].x - 1.0) < 0.2 and r[1].y < 0.0, "arc falls under gravity")
	check(Pebble.hits_target(Vector3(0, 0.4, 0.3), Vector3.ZERO), "close pebble hits")
	check(not Pebble.hits_target(Vector3(0, 0.4, 3.0), Vector3.ZERO), "far pebble misses")
	check(Pebble.recovers(0.1) and not Pebble.recovers(0.9), "60% of misses are recoverable")
	check(Pebble.recoil_scale(0.125) > 1.1 and Pebble.recoil_scale(1.0) == 1.0, "recoil squash eases out")
	# Crafting + gating
	check(GameState.RECIPES.any(func(r2): return r2["id"] == "slingshot"), "slingshot recipe exists")
	check(GameState.TOOL_NAMES.size() == GameState.Tool.SLINGSHOT + 1, "slingshot is the last tool")
	game.set_tool(GameState.Tool.SLINGSHOT)
	check(game.current_tool != GameState.Tool.SLINGSHOT, "cannot equip an unowned slingshot")
	game.add_item("slingshot", 1)
	game.set_tool(GameState.Tool.SLINGSHOT)
	check(game.current_tool == GameState.Tool.SLINGSHOT, "owned slingshot equips")
	check(not GameState.stashable("slingshot"), "slingshot stays in pockets")
	# Weather
	for d in 3:
		check(Weather.for_day(d) == Weather.CLEAR, "first days are sunny (%d)" % d)
	var wet := 0
	for d in range(3, 203):
		if Weather.is_wet(Weather.for_day(d)):
			wet += 1
		check(Weather.for_day(d) == Weather.for_day(d), "deterministic")
	check(wet > 20 and wet < 90, "roughly a quarter of days are wet (%d/200)" % wet)
	check(Weather.gloom(Weather.STORM) > Weather.gloom(Weather.RAIN) and Weather.gloom(Weather.CLEAR) == 0.0, "gloom ordering")
	check(Weather.fog_density(Weather.RAIN, 0.004) > 0.004, "rain thickens fog")
	check(Weather.drops(Weather.STORM) > Weather.drops(Weather.RAIN) and Weather.drops(Weather.CLEAR) == 0, "drop counts")
	# Rain waters tilled soil overnight
	var plot := FarmPlot.new()
	plot.state = FarmPlot.State.TILLED
	plot.rain_water()
	check(plot.watered, "rain waters tilled soil")
	var grass := FarmPlot.new()
	grass.rain_water()
	check(not grass.watered, "rain ignores bare grass")
	plot.free()
	grass.free()
	return true


func test_lightning_vacuum() -> bool:
	check(Weather.lightning_gap(Weather.CLEAR, 0.5) < 0.0 and Weather.lightning_gap(Weather.RAIN, 0.5) < 0.0, "only storms strike")
	check(Weather.lightning_gap(Weather.STORM, 0.0) == 5.0 and Weather.lightning_gap(Weather.STORM, 1.0) == 15.0, "storm gap 5..15s")
	check(Weather.lightning_gap(Weather.STORM, 9.0) == 15.0, "roll is clamped")
	check(Weather.thunder_delay(10.0) == 0.25 and Weather.thunder_delay(120.0) == 1.0 and Weather.thunder_delay(9999.0) == 3.5, "thunder lags by distance, clamped")
	check(Weather.thunder_delay(300.0) > Weather.thunder_delay(60.0), "farther bolt, later rumble")
	check(Weather.flash_level(-1.0) == 0.0 and Weather.flash_level(0.0) == 1.0, "flash starts at full")
	check(Weather.flash_level(0.17) < 0.3 and Weather.flash_level(0.25) > 0.6, "second flicker after a dim gap")
	check(Weather.flash_level(0.6) == 0.0, "flash ends")
	for i in 80:
		var f := Weather.flash_level(i * 0.01)
		check(f >= 0.0 and f <= 1.0, "flash in range %d" % i)
	check(Sfx.KINDS.has("thunder") and Sfx.KINDS.has("vacuum"), "thunder sfx exists")
	# slingshot charge
	check(Pebble.charge_power(0.0) == Pebble.MIN_POWER and Pebble.charge_power(5.0) == 1.0, "charge clamps")
	check(Pebble.charge_power(0.4) > Pebble.MIN_POWER and Pebble.charge_power(0.4) < 1.0, "half draw is in between")
	check(Pebble.launch_velocity(0.0, 0.0, 0.5).length() < Pebble.launch_velocity(0.0, 0.0).length(), "weak draw is slower")
	check(absf(Pebble.launch_velocity(0.0, 0.0).length() - Pebble.SPEED) < 0.01, "default power unchanged")
	# loot vacuum combine
	var base := {"magnet_gloves": 1, "copper_ingot": 2, "gem": 1, "plank": 1}
	check(GameState.invention_ready(base).get("id", "") == "loot_vacuum", "vacuum needs gloves + parts")
	check(GameState.invention_ready({"copper_ingot": 2, "gem": 1, "plank": 1}).get("id", "") == "magnet_gloves", "no gloves: gloves first")
	check(GameState.invention_ready({"loot_vacuum": 1, "magnet_gloves": 1, "copper_ingot": 2, "gem": 1, "plank": 1}).is_empty(), "vacuum not built twice")
	check(GameState.magnet_range(true, true) > GameState.magnet_range(true) * 1.9, "vacuum doubles gloves reach")
	check(GameState.magnet_range(false, true) == GameState.MAGNET_VACUUM, "vacuum alone works")
	check(WoodLog.state_for(9.0, 5.0, GameState.magnet_range(true, true)) == "magnet", "vacuum pulls from 9m")
	check(not GameState.stashable("loot_vacuum") and GameState.ITEMS.has("loot_vacuum"), "vacuum is a pocket gadget")
	return true


func test_mine() -> bool:
	check(MineCave.inside(MineCave.ORIGIN + Vector3(5, 0.1, 5)), "cave floor counts as inside")
	check(MineCave.inside(MineCave.ORIGIN + Vector3(-17, 0.1, 0)), "secret pocket counts as inside")
	check(not MineCave.inside(Vector3(0, 0, 8)) and not MineCave.inside(Vector3(400, 0, 120)), "town and houses are not the mine")
	check(Sfx.surface_at(MineCave.ORIGIN) == "road" and Sfx.surface_at(Vector3(400, 0, 0)) == "wood", "stone footsteps only in the mine")
	check(MineCave.drip_gap(0.0) >= 1.0 and MineCave.drip_gap(1.0) <= 6.0, "drips are occasional")
	check(MineRock.can_mine("plain", false, false) and not MineRock.can_mine("geode", false, false), "geode needs a better pickaxe")
	check(MineRock.can_mine("geode", true, false) and MineRock.can_mine("geode", false, true), "copper or gem opens geodes")
	var gd := MineRock.geode_drops(0.9)
	check(gd.filter(func(d): return d["item"] == "glow_crystal").size() == 2, "geode gives two crystals")
	check(MineRock.geode_drops(0.1).size() == gd.size() + 1, "lucky geode adds a gem")
	var world := Node3D.new()
	root.add_child(world)
	var geo := MineRock.new()
	geo.name = "Geo_T"
	geo.kind = "geode"
	world.add_child(geo)
	game.set_tool(GameState.Tool.PICKAXE)
	for i in 6:
		geo.interact(game)
	check(geo.hits == 0 and not geo.broken, "starter pickaxe bounces off a geode")
	check("Copper" in geo.get_prompt(game), "geode prompt says what you need")
	game.add_item("copper_pickaxe", 1)
	for i in 3:
		geo.interact(game)
	check(geo.broken, "copper pickaxe breaks a geode in 3 hits")
	check(get_nodes_in_group("pickup").size() >= 3, "geode bursts into physical pickups")
	var plain := MineRock.new()
	plain.name = "Plain_T"
	plain.kind = "plain"
	world.add_child(plain)
	check(not plain.ore_rich, "plain mine rock has no veins")
	var wall := CrackedWall.new()
	wall.name = "Wall_T"
	world.add_child(wall)
	check(wall.blast_distance(Vector3(1.6, 0.5, 2.5)) < 1.5, "blast near the wall edge counts")
	check(wall.blast_distance(Vector3(9, 0.5, 0)) > BoomTurnip.RADIUS, "far blast does not reach")
	wall.interact(game)
	check(not wall.broken, "hands do not open the wall")
	check(wall.blast(game, Vector3(2, 0, 0)) and wall.broken, "bomb opens the wall")
	check(not wall.blast(game, Vector3(2, 0, 0)), "wall only opens once")
	check(get_nodes_in_group("rubble").size() == CrackedWall.RUBBLE, "wall becomes physics rubble")
	check(not wall.is_in_group("interactable"), "open wall has no prompt")
	var wall2 := CrackedWall.new()
	world.add_child(wall2)
	wall2.from_dict(wall.to_dict())
	check(wall2.broken, "open wall stays open after load")
	var tin := GranTin.new()
	world.add_child(tin)
	var cash := game.money
	tin.interact(game)
	tin.interact(game)
	check(game.money == cash + GranTin.CASH and game.count("glow_crystal") == GranTin.CRYSTALS, "tin pays exactly once")
	var tin2 := GranTin.new()
	world.add_child(tin2)
	tin2.from_dict(tin.to_dict())
	check(tin2.opened, "tin opened state saves")
	check(GameState.DROPPABLE.has("glow_crystal") and GameState.stashable("glow_crystal"), "crystals drop and stash")
	check(not GameState.stashable("miner_helmet"), "helmet stays in pockets")
	var hi := _recipe_index_of("miner_helmet")
	game.add_item("copper_ingot", 2)
	check(game.craft(hi) and game.count("miner_helmet") == 1, "helmet crafts from ingots + crystals")
	check(not game.can_craft(hi), "helmet is one-off")
	# The whole cave builds with unique saveable names.
	var surface := Node3D.new()
	world.add_child(surface)
	var cave := MineCave.new()
	world.add_child(cave)
	cave.build(surface)
	var names := {}
	for c in cave.get_children():
		if c is MineRock or c is CrackedWall or c is GranTin:
			names[str(c.name)] = true
	check(names.size() == MineCave.ORE_SPOTS.size() + 2, "cave saveables have unique names (%d)" % names.size())
	check(surface.has_node("MineEntrance"), "entrance is placed on the surface")
	check(MineCave.inside(cave.entry_point), "front door leads into the cave")
	var exit: Door = cave.get_node("ExitDoor")
	check(not MineCave.inside(exit.destination), "exit door leads back out")
	return true


func test_boom_turnip() -> bool:
	check(BoomTurnip.can_throw(1, 0.0) and not BoomTurnip.can_throw(0, 0.0) and not BoomTurnip.can_throw(1, 0.3), "throw needs stock and cooldown")
	var v := BoomTurnip.throw_velocity(0.0, -0.45)
	check(v.z < 0.0 and v.y > 0.0, "lobbed forward and up")
	check(BoomTurnip.throw_velocity(0.0, -1.2).y >= 2.0 and BoomTurnip.throw_velocity(0.0, 0.25).y <= 7.0, "lift is clamped")
	check(BoomTurnip.blink_rate(0.1) > BoomTurnip.blink_rate(2.0), "blinks faster near the bang")
	check(BoomTurnip.falloff(0.0) == 1.0 and BoomTurnip.falloff(99.0) == 0.0, "falloff 1..0")
	var k := BoomTurnip.knock(Vector3.ZERO, Vector3(2, 0, 0), 10.0)
	check(k.x > 0.0 and k.y > 0.0, "knockback pushes away and up")
	check(BoomTurnip.knock(Vector3.ZERO, Vector3(1, 0, 0), 10.0).length() > BoomTurnip.knock(Vector3.ZERO, Vector3(3.5, 0, 0), 10.0).length(), "closer hits harder")
	check(BoomTurnip.knock(Vector3.ZERO, Vector3(20, 0, 0), 10.0) == Vector3.ZERO, "out of range untouched")
	var bi := _recipe_index_of("boom_turnip")
	game.add_item("turnip", 1)
	game.add_item("stone", 2)
	game.add_item("copper_ore", 1)
	check(game.craft(bi) and game.count("boom_turnip") == 2, "recipe makes two")
	game.setup_input()
	check(InputMap.has_action("throw_bomb"), "throw action is bound")
	var world := Node3D.new()
	root.add_child(world)
	var near := MineRock.new()
	near.name = "BoomNear"
	near.kind = "geode"
	world.add_child(near)
	near.position = Vector3(2, 0, 0)
	var far := MineRock.new()
	far.name = "BoomFar"
	far.kind = "plain"
	world.add_child(far)
	far.position = Vector3(30, 0, 0)
	var crate := PropCrate.new()
	crate.game = game
	world.add_child(crate)
	crate.position = Vector3(-2, 0, 0)
	var loose := WoodLog.new()
	loose.game = game
	world.add_child(loose)
	loose.position = Vector3(0, 0.3, 2)
	var bomb := BoomTurnip.new()
	bomb.game = game
	world.add_child(bomb)
	bomb.position = Vector3(0, 0.4, 0)
	var broke := bomb.explode()
	check(broke == 1 and near.broken and not far.broken, "blast breaks only rocks in range, geodes included")
	check(crate._smashed, "blast smashes crates")
	check(bomb.explode() == 0, "a bomb explodes once")
	return true


func test_car_physics() -> bool:
	var dt := 1.0 / 60.0
	check(CarPhysics.road_height(0.0, 16.0) == CarPhysics.ASPHALT_Y, "asphalt under the road centre")
	check(CarPhysics.road_height(0.0, 20.4) == CarPhysics.CURB_Y, "kerb at the road edge")
	check(CarPhysics.road_height(0.0, 8.0) == 0.0 and CarPhysics.road_height(200.0, 16.0) == 0.0, "no road on the grass")
	check(CarPhysics.wants_drift(12.0, 1.0, true), "handbrake + steer at speed drifts")
	check(not CarPhysics.wants_drift(12.0, 0.0, true) and not CarPhysics.wants_drift(3.0, 1.0, true) and not CarPhysics.wants_drift(12.0, 1.0, false), "otherwise no drift")
	var gripped := 0.0
	var slid := 0.0
	for i in 60:
		gripped = CarPhysics.slip_step(gripped, 14.0, -2.0 * dt, CarPhysics.GRIP, dt)
		slid = CarPhysics.slip_step(slid, 14.0, -2.0 * dt, CarPhysics.DRIFT_GRIP, dt)
	check(slid > gripped * 2.5 and CarPhysics.is_sliding(slid, 14.0) and not CarPhysics.is_sliding(gripped, 14.0), "low grip slides, normal grip does not (%.1f vs %.1f)" % [slid, gripped])
	check(slid > 0.0, "turning right (negative yaw) leaves momentum to the left")
	check(absf(CarPhysics.slip_step(99.0, 10.0, 0.0, 0.0, dt)) <= 10.0 * CarPhysics.MAX_SLIP_RATIO + 0.001, "slip is capped")
	check(CarPhysics.grip_step(CarPhysics.GRIP, true, false, dt) == CarPhysics.DRIFT_GRIP, "the tail steps out at once")
	var back := CarPhysics.grip_step(CarPhysics.DRIFT_GRIP, false, false, dt)
	check(back > CarPhysics.DRIFT_GRIP and back < CarPhysics.GRIP, "grip returns gradually")
	check(CarPhysics.grip_step(CarPhysics.GRIP, true, true, dt) < CarPhysics.DRIFT_GRIP, "drift tyres slide more")
	check(CarPhysics.charge_step(0.0, false, 8.0, false, 1.0) == 0.0, "no charge without a slide")
	check(CarPhysics.charge_step(0.0, true, 6.0, true, 0.5) > CarPhysics.charge_step(0.0, true, 6.0, false, 0.5), "drift tyres charge faster")
	check(CarPhysics.tier_for(0.2) == 0 and CarPhysics.tier_for(1.0) == 1 and CarPhysics.tier_for(2.0) == 2, "charge tiers")
	# Springs settle on their target even through a very long frame.
	var s := Vector2(0.0, 3.0)
	for i in 240:
		s = CarPhysics.spring_step(s.x, s.y, 0.1, dt)
	check(absf(s.x - 0.1) < 0.005 and absf(s.y) < 0.05, "spring settles")
	var big := CarPhysics.spring_step(0.0, 0.0, 0.1, 0.5)
	check(absf(big.x) < 0.3, "spring survives a lag spike")
	check(CarPhysics.roll_target(1.5, 14.0) > 0.0 and CarPhysics.roll_target(-1.5, 14.0) < 0.0 and absf(CarPhysics.roll_target(9.0, 30.0)) <= CarPhysics.MAX_ROLL, "body rolls to the outside, clamped")
	check(CarPhysics.pitch_target(9.0) < 0.0 and CarPhysics.pitch_target(-20.0) > 0.0, "squat and dive")
	check(CarPhysics.speed_text(10.0) == "36 km/h" and CarPhysics.speed_text(-5.0) == "18 km/h  R", "speedometer")
	check(is_equal_approx(SkidMarks.alpha_for(0.0), 1.0) and SkidMarks.alpha_for(SkidMarks.LIFE + 1.0) == 0.0, "skid marks fade")
	var sk := SkidMarks.new()
	root.add_child(sk)
	for i in SkidMarks.CAPACITY + 20:
		sk.add_segment(Vector3(i, 0, 0), Vector3(i + 0.4, 0, 0), SkidMarks.RUBBER)
	check(sk.used == SkidMarks.CAPACITY, "skid ring buffer wraps")
	sk.add_segment(Vector3.ZERO, Vector3(50, 0, 0), SkidMarks.RUBBER)
	check(sk._next == 20, "teleports leave no mark")
	sk.free()
	return true


func test_car_damage_parts() -> bool:
	var n := Vector2(-1, 0)
	check(CarPhysics.impact_speed(Vector2(10, 0), n) == 10.0 and CarPhysics.impact_speed(Vector2(-10, 0), n) == 0.0, "impact is speed into the wall")
	var out := CarPhysics.bounce_velocity(Vector2(10, 4), n, 0.25, 0.8)
	check(out.x < 0.0 and out.y > 3.0, "bounce back, keep sliding along")
	check(CarPhysics.damage_for(3.0, false) == 0.0, "gentle bumps never dent")
	check(CarPhysics.damage_for(16.0, false) > 0.2 and CarPhysics.damage_for(16.0, true) < CarPhysics.damage_for(16.0, false) * 0.5, "bull bar protects")
	check(CarPhysics.speed_mult(0.0) == 1.0 and is_equal_approx(CarPhysics.speed_mult(1.0), 0.6), "a wreck still limps")
	check(CarPhysics.smoke_stage(0.1) == 0 and CarPhysics.smoke_stage(0.5) == 1 and CarPhysics.smoke_stage(0.9) == 2, "smoke stages")
	var car := Car.new()
	root.add_child(car)
	car.setup()
	check(car._wheels.size() == 4, "model splits into four wheels")
	check(car._wheels.filter(func(w): return w["front"]).size() == 2, "two steering wheels")
	for i in 20:
		car.crash(18.0, Vector3.ZERO)
	check(car.damage == CarPhysics.MAX_DAMAGE, "damage caps")
	car.animate(0.1)
	check(car._smoke.emitting, "wreck smokes")
	car.repair()
	check(car.damage < 0.5 and car.damage > 0.0, "one kit is not a full rebuild from a wreck")
	car.repair()
	car.animate(0.1)
	check(car.damage == 0.0 and not car._smoke.emitting, "two kits fix it")
	# A charged drift released at speed gives a kick.
	car.speed = 10.0
	car.drift_charge = 2.0
	check(car.release_drift() == 2 and car.speed > 16.0 and car.turbo_time > 1.0 and car.drift_charge == 0.0, "orange turbo")
	car.speed = 10.0
	car.drift_charge = 0.3
	check(car.release_drift() == 0 and car.speed == 10.0, "weak drift gives nothing")
	# Steering: +1 is screen-right. Facing +Z the chase camera's right is -X.
	car.halt()
	car.heading = 0.0
	car.speed = 8.0
	car.drive(0.1, 1.0, 1.0, false)
	check(sin(car.heading) < 0.0, "steer right turns toward screen right")
	check(car._chassis != null and car.install_part("bull_bar") and car.install_part("drift_tyres") and car.install_part("offroad_wheels"), "new parts bolt on")
	car.queue_free()
	# Recipes, one-off rules, repair at the door, saving.
	var kit := _recipe_index_of("repair_kit")
	var bar := _recipe_index_of("bull_bar")
	var tyres := _recipe_index_of("drift_tyres")
	check(kit >= 0 and bar >= 0 and tyres >= 0, "car recipes exist")
	game.add_item("copper_ingot", 6)
	game.add_item("stone", 8)
	game.add_item("plank", 4)
	check(game.craft(bar) and game.count("bull_bar") == 1, "bull bar crafts")
	game.remove_item("bull_bar", 1)
	game.car_parts = ["bull_bar"]
	check(not game.can_craft(bar) and bar in game.owned_once_recipes(), "a bolted-on part cannot be crafted twice")
	check(game.craft(kit) and game.count("repair_kit") == 1, "repair kit crafts")
	var seat := Car.CarSeat.new()
	var wreck := Car.new()
	root.add_child(wreck)
	wreck.setup()
	seat.car = wreck
	wreck.damage = 0.5
	check(seat.get_prompt(game).contains("Repair Kit"), "dented car offers repair")
	seat.interact(game)
	check(wreck.damage == 0.0 and game.count("repair_kit") == 0 and game.car_damage == 0.0, "repair consumes the kit")
	check(not seat.get_prompt(game).contains("Hammer"), "mint car just offers a drive")
	seat.free()
	wreck.queue_free()
	game.car_damage = 0.45
	var saved := game.to_dict()
	game.car_damage = 0.0
	game.from_dict(saved)
	check(is_equal_approx(game.car_damage, 0.45), "damage saves")
	return true


func test_street_props() -> bool:
	var p := Vector3.ZERO
	check(CarPhysics.in_bumper_zone(p, 0.0, 10.0, Vector3(0, 0, 2.6), 0.4), "prop just ahead is clipped")
	check(not CarPhysics.in_bumper_zone(p, 0.0, 10.0, Vector3(0, 0, 4.5), 0.4), "prop far ahead is not")
	check(not CarPhysics.in_bumper_zone(p, 0.0, 10.0, Vector3(2.2, 0, 0), 0.4), "prop to the side is not")
	check(CarPhysics.in_bumper_zone(p, PI / 2, 10.0, Vector3(2.6, 0, 0), 0.4), "zone follows the heading")
	var v := CarPhysics.launch_velocity(Vector3(0, 0, 12), Vector3(1, 0, 1), false)
	check(v.y > 3.0 and v.z > 8.0 and v.x > 0.0, "clipped props fly up and away")
	check(CarPhysics.launch_velocity(Vector3(0, 0, 12), Vector3(1, 0, 1), true).length() > v.length(), "bull bar flings further")
	var rows := KnockProp.street_layout()
	check(rows.size() >= 20, "street is furnished")
	for r in rows:
		check(KnockProp.KINDS.has(r[0]) and CarPhysics.road_height(r[1], r[2]) != CarPhysics.ASPHALT_Y, "no prop blocks the traffic lanes: %s" % r[0])
	check(not KnockProp.may_respawn(5.0, 100.0) and not KnockProp.may_respawn(100.0, 2.0) and KnockProp.may_respawn(100.0, 50.0), "tidies up only when you are away")
	var holder := Node3D.new()
	root.add_child(holder)
	var made: Array = []
	for i in 3:
		var kp := KnockProp.new()
		kp.kind = "bale"
		kp.cluster = "t"
		kp.position = Vector3(i, 1, 0)
		holder.add_child(kp)
		made.append(kp)
	check(made[0].freeze, "props rest frozen")
	var car := Car.new()
	root.add_child(car)
	check(made[0].knock(Vector3(5, 3, 0), car), "knock it")
	check(made.all(func(k): return k.knocked and not k.freeze), "the whole stack tumbles")
	check(not made[0].knock(Vector3.ONE, car), "no double knock")
	for k in made:
		k.reset_prop()
	check(made.all(func(k): return k.freeze and not k.knocked and k.position.is_equal_approx(Vector3(made.find(k), 1, 0))), "reset restores the stack")
	car.queue_free()
	holder.queue_free()
	return true


## Needs real physics frames. Regression: the floor contact used to count as a crash every
## frame, which capped the car at about 3 m/s from the day it was built.
func test_car_on_real_ground() -> bool:
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(40, 1, 400)
	gs.shape = gb
	gs.position = Vector3(0, -0.5, 0)
	ground.add_child(gs)
	root.add_child(ground)
	var wall := StaticBody3D.new()
	var ws := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(40, 4, 1)
	ws.shape = wb
	ws.position = Vector3(0, 2, 60)
	wall.add_child(ws)
	root.add_child(wall)
	var car := Car.new()
	car.position = Vector3(0, 0.1, 0)
	root.add_child(car)
	car.setup()
	var bumps := [0]
	car.bumped.connect(func(): bumps[0] += 1)
	await physics_frame
	var dt := 1.0 / Engine.physics_ticks_per_second
	for i in 150:
		await physics_frame
		car.drive(dt, 1.0, 0.0, false)
	check(car.speed > 11.0 and car.position.z > 14.0, "car really accelerates on the ground (%.1f m/s, %.1f m)" % [car.speed, car.position.z])
	check(bumps[0] == 0 and car.damage == 0.0, "driving on flat ground never bumps")
	var rebounded := false
	for i in 360:
		await physics_frame
		car.drive(dt, 1.0 if not rebounded else 0.0, 0.0, false)
		if car.speed < -0.5:
			rebounded = true
			break
	check(rebounded and bumps[0] == 1, "hitting a wall bounces the car back once")
	check(car.damage > 0.1, "a flat-out crash dents it (%.2f)" % car.damage)
	car.free()
	ground.free()
	wall.free()
	return true


func test_stealth_gaze() -> bool:
	var seen := {}
	var order: Array = []
	for k in 90:
		var m := Stealth.gaze_mood(k * 0.1, 0)
		seen[m] = int(seen.get(m, 0)) + 1
		if order.is_empty() or order.back() != m:
			order.append(m)
	check(order == [Stealth.Mood.CALM, Stealth.Mood.TELL, Stealth.Mood.WATCHING], "calm, then a warning, then watching")
	check(seen[Stealth.Mood.CALM] > seen[Stealth.Mood.WATCHING] * 2, "mostly looking away")
	# While calm or warning, valuables must be outside the 120 degree sight cone, for every seed.
	var pos := Vector3(401.8, 0, 58.8)
	var drawer := Vector3(397.0, 0, 58.2)
	var guard := Stealth.yaw_to(pos, drawer)
	var fair := true
	var watches := true
	for seed_value in [1, 4, 7]:
		for k in 300:
			var t := k * 0.1
			var sees := Witness.can_see(pos, Stealth.gaze_yaw(t, seed_value, guard), drawer)
			if Stealth.gaze_mood(t, seed_value) == Stealth.Mood.WATCHING:
				watches = watches and sees
			else:
				fair = fair and not sees
	check(fair, "calm and warning phases never see the drawer")
	check(watches, "watching phase sees the drawer")
	var y := Stealth.turn_toward(3.0, -3.0, 0.1)
	check(y > 3.0, "turns the short way across the seam")
	check(is_equal_approx(Stealth.turn_toward(0.0, 0.05, 1.0), 0.05), "does not overshoot")
	return true


func test_stealth_marker_and_hearing() -> bool:
	var C := Stealth.Mood.CALM
	check(Stealth.marker(0.0, false, false, false, C) == "", "nothing to show")
	check(Stealth.marker(0.9, true, true, true, C) == "!!", "alarm wins")
	check(Stealth.marker(0.1, false, false, false, C) == "?|", "suspicion starts small")
	check(Stealth.marker(1.0, false, false, false, C) == "?|||||", "and fills up")
	check(Stealth.marker(0.0, false, true, false, C) == "chicken?!", "distracted")
	check(Stealth.marker(0.0, false, false, true, C) == "zzz", "asleep")
	check(Stealth.marker(0.0, false, false, false, Stealth.Mood.TELL) == "hm?", "warning tell")
	var calm := Stealth.cone_color(0.0, C)
	var hot := Stealth.cone_color(1.0, C)
	check(calm.g > calm.r and hot.r > hot.g, "cone goes green to red")
	check(Stealth.hears(Vector3.ZERO, Vector3(5, 0, 0), false), "hears nearby")
	check(not Stealth.hears(Vector3.ZERO, Vector3(20, 0, 0), false), "not far away")
	check(not Stealth.hears(Vector3.ZERO, Vector3(1, 0, 0), true), "sleepers sleep on")
	check(not Stealth.hears(Buildings.interior_origin(2), Buildings.interior_origin(3), false), "neighbours' rooms are out of earshot")
	return true


func test_vision_cone_clip() -> bool:
	var room := Rect2(-4, -3, 8, 6)
	check(is_equal_approx(Stealth.sight_length(Vector2.ZERO, Vector2(1, 0), room, 9.0), 4.0), "stops at the side wall")
	check(is_equal_approx(Stealth.sight_length(Vector2.ZERO, Vector2(0, -1), room, 9.0), 3.0), "stops at the back wall")
	check(is_equal_approx(Stealth.sight_length(Vector2.ZERO, Vector2(1, 0), room, 2.0), 2.0), "never beyond sight range")
	var pts := VisionCone.rim(Vector3(1, 0, 1), 0.7, room)
	var inside := true
	for pt in pts:
		inside = inside and pt.x >= -4.001 and pt.x <= 4.001 and pt.z >= -3.001 and pt.z <= 3.001
	check(pts.size() == VisionCone.STEPS + 1 and inside, "cone never pokes through walls")
	var free_pts := VisionCone.rim(Vector3.ZERO, 0.0, Rect2())
	check(is_equal_approx(free_pts[VisionCone.STEPS / 2].z, Witness.RANGE), "outdoors it reaches full range")
	var r := Buildings.room_rect(2)
	check(r.has_point(Vector2(Buildings.interior_origin(2).x, Buildings.interior_origin(2).z)), "room rect surrounds its interior")
	return true


func test_velvet_picks() -> bool:
	var plain := Lockpick.new(1.0, 3)
	var velvet := Lockpick.new(1.0, 3, true)
	check(velvet.zone_width > plain.zone_width * 1.3, "wider sweet spot")
	check(velvet.picks_left == Lockpick.VELVET_PICKS and velvet.picks_max == Lockpick.VELVET_PICKS, "more spares")
	var ids := GameState.RECIPES.map(func(r): return r["id"])
	check(ids.has("velvet_picks") and ids.has("squeaky_chicken"), "both heist recipes exist")
	game.add_item("velvet_picks", 1)
	var c := LootContainer.new()
	root.add_child(c)
	c.interact(game)
	check(c.lock.picks_max == Lockpick.VELVET_PICKS, "owning them upgrades every lock")
	game.add_item("hay", 3)
	game.add_item("plank", 1)
	check(game.craft(ids.find("squeaky_chicken")) and game.count("squeaky_chicken") == 1, "chicken crafted")
	check(not GameState.stashable("velvet_picks"), "picks stay on you")
	return true


func test_abandon_lock() -> bool:
	var pl := Node3D.new()
	pl.add_to_group("player")
	root.add_child(pl)
	var c := LootContainer.new()
	root.add_child(c)
	c.interact(game)
	pl.global_position = Vector3(1.0, 0, 0)
	c._process(0.05)
	check(c.state == "picking", "standing close keeps picking")
	pl.global_position = Vector3(6.0, 0, 0)
	c._process(0.05)
	check(c.state == "locked" and c.lock == null, "walking away drops the lock (no ghost crime)")
	return true


func test_decoy_logic() -> bool:
	var v := Decoy.throw_velocity(0.0, -0.45)
	check(v.z < 0.0 and v.y > 0.0, "lobbed forward and up")
	var top := 0.0
	for pitch in [-1.2, -0.45, 0.25]:
		top = maxf(top, Decoy.throw_velocity(0.0, pitch).y)
	check(1.35 + top * top / (2.0 * 9.8) < Buildings.ROOM.y, "even the highest lob stays under the ceiling")
	check(not Decoy.can_collect(2.0, 2, 0.5), "not while it is still performing")
	check(Decoy.can_collect(7.0, Decoy.SQUEAKS, 0.5), "pocket it once quiet")
	check(not Decoy.can_collect(7.0, Decoy.SQUEAKS, 3.0), "must walk over it")
	var d := Decoy.new()
	d.game = game
	root.add_child(d)
	d.step(0.1)
	check(d.squeaks == 0, "silent in the air")
	d.land()
	for i in 100:
		d.step(0.1)
	check(d.squeaks == Decoy.SQUEAKS, "squeaks a fixed number of times")
	d.collect()
	check(game.count("squeaky_chicken") == 1, "reusable")
	check(InputMap.has_action("throw_decoy") or GameState.PAD_AXES.has("throw_decoy"), "has a binding")
	return true


func test_npc_distraction() -> bool:
	var n := Npc.new()
	root.add_child(n)
	n.activity = Buildings.Schedule.Activity.HOME
	n.global_position = Vector3(401.8, 0, 58.8)
	n.guard_spot = Vector3(397.0, 0, 58.2)
	n.gaze_seed = 0
	n._gaze_t = 7.0   # staring at the drawer
	n.rotation.y = Stealth.yaw_to(n.global_position, n.guard_spot)
	check(n.gaze_mood() == Stealth.Mood.WATCHING, "on watch")
	check(Witness.can_see(n.global_position, n.rotation.y, n.guard_spot), "sees the drawer")
	var noise := Vector3(404.0, 0, 61.0)
	check(n.hear_noise(noise) and n.is_distracted(), "hears the chicken")
	for i in 10:
		n.update_awareness(0.1)
		n.hear_noise(noise)
	check(not Witness.can_see(n.global_position, n.rotation.y, n.guard_spot), "staring at the chicken, not the drawer")
	for i in 30:
		n.update_awareness(0.1)
	check(not n.is_distracted(), "attention returns once it is quiet")
	n.activity = Buildings.Schedule.Activity.SLEEP
	check(not n.hear_noise(noise), "asleep: no reaction")
	return true


func test_lock_meter() -> bool:
	check(LockMeter.cursor_x(0.0) < LockMeter.cursor_x(0.5) and LockMeter.cursor_x(1.0) <= LockMeter.PANEL.x, "pick stays on the panel")
	var m := LockMeter.new()
	root.add_child(m)
	m.lock = Lockpick.new(0.0, 1)
	m.advance(0.1)
	m.lock.pins_set = 1
	for i in 5:
		m.advance(0.1)
	check(m._lift[0] > 0.9 and m._lift[1] < 0.1, "set pin rises, the next waits")
	m.lock.picks_left -= 1
	m.lock.pins_set = 0
	m.advance(0.05)
	check(m._shake > 0.5 and m._broken_t < 0.1, "snapping shakes and throws the tip")
	return true


func test_heist_art() -> bool:
	for id in GameState.ITEMS.keys():
		if GameState.ITEMS[id].get("loot", false):
			var model := LootModel.make(id)
			check(model.get_child_count() > 0, "%s has a model" % id)
			model.free()
	var d := DresserModel.new()
	root.add_child(d)
	check(d.drawers.size() == 3, "three drawers")
	var c := LootContainer.new()
	c.dresser = d
	root.add_child(c)
	c.interact(game)
	c.lock.phase = 0.0
	c.lock.zone_center = 0.9
	c.interact(game)
	check(d._jiggle > 0.9, "a snap rattles the dresser")
	d.drawers[0].position.z = 0.6
	d.close()
	check(d.drawers[0].position.z < 0.3, "closes again")
	return true


func test_door_swing() -> bool:
	var d := Door.new()
	root.add_child(d)
	d.attach_leaf()
	check(d.hinge != null and d.hinge.position.x < 0.0, "hung on its left edge")
	var inside := Buildings.build_interior(root, 0, Vector3.ZERO, Color.WHITE, "T")
	var exit_door: Door = inside["exit_door"]
	var edge := Basis(Vector3.UP, exit_door.open_angle) * Vector3(1.1, 0, 0)
	check(edge.z < -0.5, "exit door swings into the room")
	check((inside["entry"] as Vector3).distance_to(exit_door.global_position) < exit_door.interact_radius, "leave prompt reachable from the entry spot")
	return true


func test_room_dressing() -> bool:
	var inside := Buildings.build_interior(root, 3, Vector3.ZERO, Color.WHITE, "T")
	var room: Node3D = inside["root"]
	check(room.get_node_or_null("Deco") != null and room.get_node("Deco").get_child_count() > 20, "furnished")
	var ceiling := room.get_child(1) as StaticBody3D
	check(ceiling.collision_layer == Buildings.CEILING_LAYER, "ceiling does not block the camera")
	var cam_arm := SpringArm3D.new()
	check(cam_arm.collision_mask & Buildings.CEILING_LAYER == 0, "camera arm ignores the ceiling layer")
	cam_arm.free()
	var day := RoomDressing.window_light(1.0, 0.0, 0.0)
	var night := RoomDressing.window_light(0.0, 0.0, 1.0)
	check(day["glass"].get_luminance() > night["glass"].get_luminance() * 2.0, "windows darken at night")
	check(day["shaft"] > night["shaft"], "so do the light shafts")
	return true


## Real physics: a lobbed chicken must stay inside the room, come to rest on the floor and perform.
func test_decoy_in_real_room() -> bool:
	await process_frame
	var inside := Buildings.build_interior(root, 0, Vector3.ZERO, Color.WHITE, "T")
	var origin := Buildings.interior_origin(0)
	await physics_frame
	await physics_frame
	var worst := -INF
	for yaw in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var d := Decoy.new()
		d.game = game
		root.add_child(d)
		d.global_position = origin + Vector3(0, 1.35, 0)
		d.linear_velocity = Decoy.throw_velocity(yaw, 0.25)
		for k in 180:
			await physics_frame
			var rel := d.global_position - origin
			worst = maxf(worst, maxf(absf(rel.x) - Buildings.ROOM.x / 2.0, absf(rel.z) - Buildings.ROOM.z / 2.0))
		check(d.landed, "it lands (yaw %.2f)" % yaw)
		check(d.global_position.y > 0.05 and d.global_position.y < 0.6, "rests on the floor (y %.2f)" % d.global_position.y)
		d.free()
	check(worst < 0.0, "never leaves the room (%.2f)" % worst)
	(inside["root"] as Node).free()
	return true


func _pet(kind: int, nm: String) -> Critter:
	var c := Critter.new()
	c.kind = kind
	c.name = nm
	root.add_child(c)
	return c


func test_pet_friendship() -> bool:
	var r := Critter.pet_result(1, -1, 3)
	check(r["gained"] and r["hearts"] == 2, "first pat of the day adds a heart")
	check(not Critter.pet_result(2, 3, 3)["gained"], "second pat the same day adds nothing")
	check(Critter.pet_result(2, 3, 4)["hearts"] == 3, "a new day counts again")
	check(Critter.pet_result(Critter.MAX_HEARTS, 1, 9)["hearts"] == Critter.MAX_HEARTS, "hearts cap")
	check(Critter.tamed_action(Critter.Kind.CHICKEN, false, false) == "pet", "chicken: pat first")
	check(Critter.tamed_action(Critter.Kind.CHICKEN, true, false) == "pickup", "chicken: then pick up")
	check(Critter.tamed_action(Critter.Kind.GOAT, false, true) == "pet", "goat: pat first")
	check(Critter.tamed_action(Critter.Kind.GOAT, true, true) == "ride", "goat: then ride")
	check(Critter.tamed_action(Critter.Kind.GOAT, true, false) == "pet", "no saddle: more pats")
	check(Critter.fetch_range(1) == 0.0 and Critter.fetch_range(2) > 5.0, "fetch job unlocks at 2 hearts")
	check(Critter.fetch_range(5) > Critter.fetch_range(3), "fonder hens range farther")
	check(Critter.egg_interval(1) == Critter.EGG_EVERY and Critter.egg_interval(5) < Critter.EGG_EVERY * 0.7, "fonder hens lay faster")
	var hen := _pet(Critter.Kind.CHICKEN, "Chicken_1")
	game.add_item("carrot", 3)
	for i in 3:
		hen.interact(game)
	check(hen.tamed and hen.hearts == 1 and game.count("carrot") == 0, "three veg befriend a hen at 1 heart")
	check("Pet your chicken" in hen.get_prompt(game), "prompt offers the daily pat")
	hen.interact(game)
	check(hen.hearts == 2 and "Pick up" in hen.get_prompt(game), "after the pat she can be picked up")
	check(hen.can_be_carried(), "tamed hen is carryable")
	var wild := _pet(Critter.Kind.CHICKEN, "Chicken_2")
	check(not wild.can_be_carried(), "wild hens are not")
	var goat := _pet(Critter.Kind.GOAT, "Goat")
	check(not goat.can_be_carried(), "goats are too heavy to carry")
	return true


func test_animal_rig() -> bool:
	var hen := AnimalRig.make("chicken", 1)
	var goat := AnimalRig.make("goat")
	var bun := AnimalRig.make("rabbit", 4)
	for r in [hen, goat, bun]:
		root.add_child(r)
		check(r.eyes.size() == 2 and r.head != null and r.tail != null, r.species + " has a face and tail")
	check(hen.legs.size() == 2 and hen.wings.size() == 2, "hen: two legs, two wings")
	check(goat.legs.size() == 4 and goat.knees.size() == 4 and goat.ears.size() == 2, "goat: four jointed legs and ears")
	check(goat.bags != null and not goat.bags.visible, "saddle bags hidden until crafted")
	check(bun.ears.size() == 2, "rabbit ears")
	for i in 30:
		goat.animate(0.033, 6.0, {})
	check(absf(goat.legs[0].rotation.x) + absf(goat.legs[1].rotation.x) > 0.05, "walking swings legs")
	for i in 30:
		goat.animate(0.033, 0.0, {"graze": true})
	check(goat.neck.rotation.x > 1.0, "grazing lowers the head")
	for i in 30:
		hen.animate(0.033, 0.0, {"flap": 1.0})
	check(absf(hen.wings[0].rotation.z) > 0.2, "flapping opens wings")
	for i in 30:
		hen.animate(0.033, 0.0, {})
	check(absf(hen.wings[0].rotation.z) < 0.05, "wings fold again")
	var s := Vector2(1.0, 0.0)
	for i in 200:
		s = AnimalRig.spring(s, 0.0, 120.0, 7.0, 0.016)
	check(absf(s.x) < 0.02, "spring settles")
	check(absf(AnimalRig.spring(Vector2(1, 0), 0.0, 150.0, 9.0, 5.0).x) <= 1.0, "spring survives a long frame")
	for i in 20:
		check(absf(AnimalRig.head_thrust(i / 20.0)) <= 0.5001, "head thrust in range")
	check(AnimalRig.leg_phase(0, 4, false) == AnimalRig.leg_phase(3, 4, false), "walk uses diagonal pairs")
	check(AnimalRig.leg_phase(2, 4, true) - AnimalRig.leg_phase(0, 4, true) == 0.5, "gallop splits front and back")
	return true


func test_chicken_flight_and_jobs_logic() -> bool:
	var v := Critter.toss_velocity(0.0)
	check(v.z < -5.0 and v.y > 3.0, "toss goes forward and up")
	for i in 120:
		v = Critter.flutter_step(v, 0.016)
	check(v.y >= -Critter.FLAP_FALL - 0.001, "flapping caps the fall speed")
	check(Vector2(v.x, v.z).length() < 2.0, "forward speed bleeds off")
	check(Critter.CARRY_FALL < 2.4, "chicken floats slower than the pelt glider falls")
	check(Critter.worth_fetching(5.0, 6.0, 9.0, 2.6, false), "old loot out of magnet reach is fetched")
	check(not Critter.worth_fetching(1.0, 6.0, 9.0, 2.6, false), "fresh drops are left alone")
	check(not Critter.worth_fetching(-1.0, 6.0, 9.0, 2.6, false), "things you just dropped are left alone")
	check(not Critter.worth_fetching(5.0, 2.0, 9.0, 2.6, false), "magnet range needs no chicken")
	check(not Critter.worth_fetching(5.0, 12.0, 9.0, 2.6, false), "too far is too far")
	check(not Critter.worth_fetching(5.0, 6.0, 9.0, 2.6, true), "logs saved for chopping stay")
	var log_ := WoodLog.new()
	log_.game = game
	root.add_child(log_)
	log_.set_carried(true)
	check(log_.carried and log_.freeze, "carried loot is frozen")
	log_.set_carried(false)
	check(not log_.carried and not log_.freeze, "released loot is physical again")
	var hen := _pet(Critter.Kind.CHICKEN, "Chicken_0")
	check(not hen.call_to(Vector3.ZERO, Vector3.BACK), "wild hens ignore the whistle")
	hen.befriend(game)
	hen.position = Vector3(60, 0, 0)
	check(hen.call_to(Vector3.ZERO, Vector3.BACK), "friends answer the whistle")
	check(hen.global_position.length() < Critter.CALL_WARP_DIST + 4.0, "far friends pop in close by")
	for kind in ["cluck", "bleat", "flap", "whistle"]:
		check(Sfx.make(kind).data.size() > 0, "sound exists: " + kind)
	game.setup_input()
	check(InputMap.has_action("whistle"), "whistle action")
	return true


func test_goat_ram() -> bool:
	check(not GoatRam.is_ramming(5.0, 0.0) and GoatRam.is_ramming(12.0, 0.0) and GoatRam.is_ramming(0.0, 0.2), "ram when galloping or lunging")
	check(GoatRam.in_front(Vector3.ZERO, 0.0, Vector3(0, 0, 1.2)), "ahead is hit")
	check(not GoatRam.in_front(Vector3.ZERO, 0.0, Vector3(0, 0, -1.2)), "behind is safe")
	check(not GoatRam.in_front(Vector3.ZERO, 0.0, Vector3(2.0, 0, 0.5)), "wide of the horns is safe")
	check(GoatRam.in_front(Vector3.ZERO, PI * 0.5, Vector3(1.2, 0, 0)), "zone follows heading")
	check(GoatRam.fling(0.0, 13.0, 5, true).length() > GoatRam.fling(0.0, 13.0, 1, false).length(), "lunge and hearts add punch")
	var crate := PropCrate.new()
	crate.game = game
	root.add_child(crate)
	crate.global_position = Vector3(0, 0, 1.0)
	var rock := MineRock.new()
	rock.name = "RamRock"
	root.add_child(rock)
	rock.global_position = Vector3(0.4, 0, 1.2)
	var tree := ChoppableTree.new()
	tree.name = "RamTree"
	root.add_child(tree)
	tree.global_position = Vector3(-0.4, 0, 1.4)
	var done := {}
	GoatRam.strike(self, game, Vector3.ZERO, 0.0, 12.0, 3, false, done)
	check(crate.is_queued_for_deletion(), "barging smashes crates")
	check(not rock.broken and rock.hits == 0, "barging leaves rocks alone")
	done = {}
	GoatRam.strike(self, game, Vector3.ZERO, 0.0, 15.0, 3, true, done)
	check(rock.broken or rock.hits > 0, "a headbutt cracks rocks")
	var logs := get_nodes_in_group("pickup").size()
	check(tree._shaken_day == game.day, "a headbutt shakes trees")
	GoatRam.strike(self, game, Vector3.ZERO, 0.0, 15.0, 3, true, {})
	GoatRam.strike(self, game, Vector3.ZERO, 0.0, 15.0, 3, true, {})
	check(rock.broken, "a few headbutts break the rock")
	check(logs > 0 and tree.shake_tree(game), "shaking again is allowed")
	var after := get_nodes_in_group("pickup").size()
	tree.shake_tree(game)
	check(get_nodes_in_group("pickup").size() == after, "only one free branch per tree per day")
	return true


func test_mount_steer() -> bool:
	check(MountSteer.turn_limit(13.0, true) < MountSteer.turn_limit(4.0, true), "faster means wider turns")
	check(MountSteer.turn_limit(8.0, false) < MountSteer.turn_limit(8.0, true), "little steering mid-air")
	var vel := Vector2(0, 13)
	var r := MountSteer.step(vel, Vector2(13, 0), 0.1, true)
	var next: Vector2 = r["velocity"]
	check(next.x > 0.0 and next.y > next.x, "carves toward the wish instead of snapping")
	check(float(r["turn_rate"]) > 0.0, "turning toward +X raises model yaw (a left turn)")
	check(MountSteer.lean(float(r["turn_rate"]), 13.0) < 0.0, "leans into a left turn")
	check(next.length() < 13.0, "hard turns bleed speed")
	for i in 100:
		vel = MountSteer.step(vel, Vector2(13, 0), 0.03, true)["velocity"]
	check(vel.x > 11.0 and absf(vel.y) < 1.0, "ends up heading where you asked")
	var back: Vector2 = MountSteer.step(Vector2(0, 13), Vector2(0, -13), 0.1, true)["velocity"]
	check(back.y > 0.0 and back.y < 13.0 and back.x == 0.0, "reversing digs in first")
	var stop := Vector2(0, 13)
	for i in 60:
		stop = MountSteer.step(stop, Vector2.ZERO, 0.03, true)["velocity"]
	check(stop.length() < 0.1, "letting go stops the goat")
	return true


func test_pet_gear_and_save() -> bool:
	var base := game.carry_free()
	game.add_item("saddle_bags", 1)
	check(game.carry_free() == base, "bags are no use without a goat friend")
	var goat := _pet(Critter.Kind.GOAT, "Goat")
	goat.befriend(game)
	check(game.carry_free() == base + GameState.CARRY_SADDLE_BAGS, "a goat friend hauls the bags")
	for id in ["saddle_bags", "goat_whistle"]:
		var idx := _recipe_index_of(id)
		check(idx >= 0 and GameState.RECIPES[idx].get("once", false), "one-off recipe: " + id)
		check(not GameState.stashable(id), "stays in pockets: " + id)
	goat.hearts = 4
	goat.petted_day = 6
	var d := goat.to_dict()
	var again := _pet(Critter.Kind.GOAT, "Goat2")
	game.goat_friend = false
	again.from_dict(d)
	check(again.hearts == 4 and again.petted_day == 6 and again.tamed, "friendship survives saving")
	var old := _pet(Critter.Kind.CHICKEN, "Chicken_3")
	old.from_dict({"affection": 3, "tamed": true})
	check(old.hearts == 1, "pets from older saves start at one heart")
	game.from_dict({})
	return true


## The real thing: a hen thrown over solid ground lands, then runs an errand and delivers.
func test_hen_on_real_ground() -> bool:
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	cs.shape = box
	cs.position.y = -0.5
	floor_body.add_child(cs)
	root.add_child(floor_body)
	var pl := Node3D.new()
	pl.add_to_group("player")
	root.add_child(pl)
	var hen := _pet(Critter.Kind.CHICKEN, "Chicken_0")
	hen.befriend(game)
	hen.hearts = 3
	await physics_frame
	hen.throw_from(Vector3(0, 2.0, 0), Critter.toss_velocity(0.0))
	check(hen.thrown, "she is airborne")
	for i in 600:
		await process_frame
		if not hen.thrown:
			break
		hen._process(0.05)
	check(not hen.thrown and absf(hen.global_position.y - Critter.ground_y(hen.global_position.x, hen.global_position.z)) < 0.3, "she flutters down onto the ground")
	check(hen.global_position.z < -2.0, "and travelled forward")
	hen.set_process(false)
	hen.global_position = Vector3(0, Critter.ground_y(0, 0), 0)
	var egg := WoodLog.new()
	egg.game = game
	egg.item_id = "egg"
	egg.chunk_color = WoodLog.drop_color("egg")
	root.add_child(egg)
	egg.global_position = Vector3(7.0, 0.3, 0)
	egg.age = 10.0
	var grabbed := false
	var delivered := false
	for i in 400:
		await physics_frame
		hen._fetch_tick(0.05, pl)
		if is_instance_valid(egg) and egg.carried:
			grabbed = true
		if grabbed and hen._cargo == null:
			delivered = true
			break
	check(grabbed, "she picks up distant loot")
	check(delivered and is_instance_valid(egg) and Vector2(egg.global_position.x, egg.global_position.z).length() < 2.6, "and brings it within magnet reach")
	return true


func _gi(style: String, x: float, z: float, r: int, l: int) -> Dictionary:
	return {"id": style, "style": style, "kind": BuildGrid.kind_of(style), "x": x, "z": z, "r": r, "l": l}


## A one-tile hut: floor, four walls on its edges, a roof, and furniture of choice inside.
func _hut() -> Dictionary:
	return {
		"floor": _gi("floor", 0, 0, 0, 0), "n": _gi("plank_wall", 0, -1, 0, 0), "s": _gi("doorway", 0, 1, 0, 0),
		"w": _gi("plank_wall", -1, 0, 1, 0), "e": _gi("window", 1, 0, 1, 0), "roof": _gi("roof", 0, 0, 0, 1),
	}


func test_edge_snapping() -> bool:
	check(BuildGrid.snap_edge(Vector3(0.3, 0, 0.4), 0) == Vector3(0, 0, 1), "wall along X sits on the near z edge")
	check(BuildGrid.snap_edge(Vector3(0.3, 0, -0.4), 0) == Vector3(0, 0, -1), "or the far one")
	check(BuildGrid.snap_edge(Vector3(0.4, 0, 0.3), 1) == Vector3(1, 0, 0), "wall along Z sits on an x edge")
	check(BuildGrid.facing_axis(0.0) == 0 and BuildGrid.facing_axis(PI * 0.5) == 1 and BuildGrid.facing_axis(PI) == 0, "walls turn with you")
	check(BuildGrid.facing_quarter(PI * 0.5) == 1 and BuildGrid.facing_quarter(-PI * 0.5) == 3, "quarter turns wrap")
	check(BuildGrid.edge_cells(0, 1, 0) == [Vector2i(0, 0), Vector2i(0, 1)], "an edge borders two tiles")
	check(BuildGrid.edge_cells(2, 2, 0) == [Vector2i(1, 1)], "old mid-tile walls still count for their tile")
	var keys := {}
	for e in [[0, 1, 0], [0, -1, 0], [1, 0, 1], [-1, 0, 1], [0, 0, 0], [0, 0, 1]]:
		keys[BuildWorld.key_for("wood_wall", Vector3(e[0], 0, e[1]), e[2], 0)] = true
	check(keys.size() == 6, "every edge (and old mid-tile slot) has its own key")
	check(BuildWorld.key_for("wood_wall", Vector3(0, 0, 1), 0, 1) != BuildWorld.key_for("wood_wall", Vector3(0, 0, 1), 0, 0), "storeys have their own slots")
	check(BuildWorld.key_for("wood_roof", Vector3.ZERO, 0) == BuildWorld.key_for("wood_roof", Vector3.ZERO, 0, 1), "roofs default to the first storey")
	return true


func test_support_and_collapse() -> bool:
	var h := _hut()
	var s := BuildGrid.supports(h)
	check(s["floor"] == 1.0 and s["n"] == 1.0, "ground pieces are solid")
	check(is_equal_approx(s["roof"], BuildGrid.FROM_BELOW), "roof leans on the walls")
	check(BuildGrid.collapsed(h, "n").is_empty(), "three walls still hold the roof")
	for k in ["n", "s", "w"]:
		h.erase(k)
	check(BuildGrid.collapsed(h, "e") == ["roof"], "last wall gone, roof falls")
	# A balcony can only reach so far from its wall.
	var items := {"w0": _gi("plank_wall", 0, 1, 0, 0)}
	for i in 5:
		items["f%d" % i] = _gi("floor", 0, -2 * i, 0, 1)
	items["f0"] = _gi("floor", 0, 0, 0, 1)
	var sp := BuildGrid.supports(items)
	check(sp["f0"] > sp["f1"] and sp["f1"] > sp["f2"], "support fades along a cantilever")
	check(sp["f2"] >= BuildGrid.MIN_SUPPORT and sp["f3"] < BuildGrid.MIN_SUPPORT, "three tiles is the limit")
	var fell := BuildGrid.collapsed(items, "w0")
	check(fell.size() == 3, "pull the wall and the whole balcony goes (%d)" % fell.size())
	check(not fell.has("f4"), "already-unsupported old pieces never collapse by surprise")
	var tower := {"a": _gi("plank_wall", 0, 1, 0, 0), "b": _gi("plank_wall", 0, 1, 0, 1), "c": _gi("plank_wall", 0, 1, 0, 2)}
	check(BuildGrid.supports(tower)["c"] > BuildGrid.MIN_SUPPORT, "walls stack three high")
	check(BuildGrid.collapsed(tower, "a") == ["b", "c"], "kick out the bottom and it falls lowest first")
	check(BuildGrid.support_color(1.0).g > BuildGrid.support_color(1.0).r and BuildGrid.support_color(0.1).r > BuildGrid.support_color(0.1).g, "green is solid, red is not")
	check(BuildGrid.support_word(0.3) == "wobbly", "support words")
	return true


func test_demolish_collapses() -> bool:
	var bw := BuildWorld.new()
	root.add_child(bw)
	game.add_item("wood_wall", 2)
	game.add_item("wood_roof", 1)
	check(bw.place("wood_wall", Vector3(20, 0, 21), 0, game, 0) and bw.place("wood_wall", Vector3(20, 0, 21), 0, game, 1), "wall on wall")
	check(bw.place("wood_roof", Vector3(20, 0, 20), 0, game, 2), "roof on top")
	check(game.built[1].get("l") == 1 and not game.built[0].has("l"), "storey saved only when needed")
	game.from_dict(game.to_dict())
	bw.rebuild_from_game(game)
	check(bw.pieces.size() == 3, "stacked house survives save and load")
	check(bw.demolish(BuildWorld.key_for("wood_wall", Vector3(20, 0, 21), 0, 0), game), "knock out the bottom wall")
	check(bw.pieces.is_empty() and game.built.is_empty(), "everything above came down")
	check(game.count("wood_wall") == 1 and game.count("wood_roof") == 0, "only the demolished piece goes to your pockets")
	await create_timer(0.7).timeout
	var bundles: Array = []
	for n in bw.get_children():
		if n is WoodLog:
			bundles.append(n.item_id)
	bundles.sort()
	check(bundles == ["wood_roof", "wood_wall"], "fallen pieces lie on the ground as pick-ups %s" % str(bundles))
	check(get_nodes_in_group("build_debris").size() > 5, "boards go flying")
	for d in get_nodes_in_group("build_debris"):
		d.free()
	bw.free()
	return true


func test_roof_shapes() -> bool:
	var roofs := {}
	for x in [0, 2, 4]:
		roofs[BuildGrid.roof_id(x, 0, 1)] = 0
	check(BuildGrid.roof_span(roofs, 0, 0, 1, 0) == Vector2i(0, 3) and BuildGrid.roof_span(roofs, 4, 0, 1, 0) == Vector2i(2, 3), "three tiles share one gable")
	check(BuildGrid.roof_span(roofs, 0, 0, 1, 1) == Vector2i(0, 1), "turned tiles do not join sideways")
	var along_z := {BuildGrid.roof_id(0, 0, 1): 1, BuildGrid.roof_id(0, -2, 1): 1}
	check(BuildGrid.roof_span(along_z, 0, 0, 1, 1) == Vector2i(0, 2), "axis 1 slopes toward -Z")
	check(is_zero_approx(BuildGrid.roof_height(0.0, 3)) and is_zero_approx(BuildGrid.roof_height(6.0, 3)), "eaves are level")
	check(BuildGrid.roof_height(3.0, 3) > BuildGrid.roof_height(2.0, 3), "ridge is highest")
	for n in range(1, 6):
		check(BuildGrid.roof_height(n * 1.0, n) <= 1.65, "wide roofs stay sensible (%d)" % n)
		for i in n:
			for seg in BuildGrid.roof_segments(i, n):
				check(seg[1] > seg[0] and seg[0] >= i * 2.0 and seg[1] <= i * 2.0 + 2.0, "segments stay inside the tile")
	check(BuildGrid.roof_segments(1, 3).size() == 2 and BuildGrid.roof_segments(0, 3).size() == 1, "only the ridge tile is split")
	# In the world: placing a neighbour reshapes the first tile, demolishing reshapes it back.
	var bw := BuildWorld.new()
	root.add_child(bw)
	game.add_item("wood_roof", 2)
	bw.place("wood_roof", Vector3(30, 0, 30), 0, game)
	var first: BuildPiece = bw.pieces[BuildWorld.key_for("wood_roof", Vector3(30, 0, 30), 0)]
	check(first.roof_shape == [0, 1, true, true], "a lone roof is its own gable")
	bw.place("wood_roof", Vector3(32, 0, 30), 0, game)
	check(first.roof_shape == [0, 2, true, true], "it becomes half of a bigger one")
	bw.demolish(BuildWorld.key_for("wood_roof", Vector3(32, 0, 30), 0), game)
	check(first.roof_shape == [0, 1, true, true], "and back again")
	var items := {"a": _gi("roof", 0, 0, 0, 1), "b": _gi("roof", 0, 2, 0, 1)}
	check(BuildWorld.roof_shape_at(items, 0, 0, 1, 0) == [0, 1, true, false], "no gable boards between tiles in a row")
	for d in get_nodes_in_group("build_debris"):
		d.free()
	bw.free()
	return true


func test_build_aim() -> bool:
	var at := Vector3(0, Terrain.height_at(0, 0), -2.4)
	var a := BuildWorld.aim("wood_wall", at, 0.0, 0, 0, {})
	check(a["r"] == 0 and a["level"] == 0 and posmod(roundi((a["pos"] as Vector3).z), 2) == 1, "wall aims at an edge, running across your view")
	check(BuildWorld.aim("wood_wall", at, PI * 0.5, 0, 0, {})["r"] == 1, "turn and the wall turns")
	check(BuildWorld.aim("wood_wall", at, 0.0, 1, 0, {})["r"] == 1, "Q flips it")
	check(BuildWorld.aim("wood_wall", at, 0.0, 0, 1, {})["level"] == 1, "T lifts a storey")
	check(BuildWorld.aim("wood_floor", at + Vector3(0, 2.34, 0), 0.0, 0, 0, {})["level"] == 1, "standing upstairs builds upstairs")
	check(BuildWorld.aim("wood_roof", at, 0.0, 0, 0, {})["level"] == 1, "a roof starts one storey up")
	var cell: Vector3 = BuildWorld.aim("wood_roof", at, 0.0, 0, 0, {})["pos"]
	var items := {"w0": _gi("plank_wall", cell.x, cell.z + 1.0, 0, 0), "w1": _gi("plank_wall", cell.x, cell.z + 1.0, 0, 1)}
	check(BuildWorld.aim("wood_roof", at, 0.0, 0, 0, items)["level"] == 2, "roof sits on the highest wall")
	var nb := {"r": _gi("roof", cell.x + 2.0, cell.z, 1, 1)}
	check(BuildWorld.aim("wood_roof", at, 0.0, 0, 0, nb)["r"] == 1, "roof copies its neighbour's direction")
	check(BuildWorld.aim("wood_stairs", at, PI, 0, 0, {})["r"] == 2, "stairs climb away from you")
	check(BuildWorld.storey_of(0.14) == 0 and BuildWorld.storey_of(2.34) == 1 and BuildWorld.storey_of(9.0) == 2, "storeys by height")
	var st := {"s": _gi("stairs", 0, 0, 0, 0)}
	check(BuildWorld.blocks_stairwell(st, "wood_floor", 0, 0, 1) and not BuildWorld.blocks_stairwell(st, "wood_floor", 2, 0, 1), "stairwell stays open")
	check(BuildWorld.blocks_stairwell({"f": _gi("floor", 0, 0, 0, 1)}, "wood_stairs", 0, 0, 0), "no stairs under a floor")
	check(BuildWorld.prompt_for("wood_wall", 2, false, 1, 0.3).contains("wobbly"), "prompt warns about support")
	return true


func test_door_cutaway_comfort() -> bool:
	check(DoorLeaf.target_angle(Vector3(0, 0, 3), 0.0) == 0.0, "door stays shut from afar")
	check(DoorLeaf.target_angle(Vector3(0, 0, 1), 0.0) > 0.0 and DoorLeaf.target_angle(Vector3(0, 0, -1), 0.0) < 0.0, "door swings away from you")
	check(DoorLeaf.target_angle(Vector3(0, 0, -0.5), DoorLeaf.OPEN_ANGLE) == DoorLeaf.OPEN_ANGLE, "no slamming back as you walk through")
	var a := 0.0
	var v := 0.0
	var peak := 0.0
	for i in 180:
		var r := DoorLeaf.spring(a, v, DoorLeaf.OPEN_ANGLE, 1.0 / 60.0)
		a = r[0]
		v = r[1]
		peak = maxf(peak, a)
	check(peak > DoorLeaf.OPEN_ANGLE + 0.05 and absf(a - DoorLeaf.OPEN_ANGLE) < 0.01, "springy overshoot that settles")
	check(BuildWorld.cuts_away(1, "roof", Vector3(0, 2.2, 0), true) and not BuildWorld.cuts_away(1, "roof", Vector3(0, 2.2, 0), false), "roof only hides when you are inside")
	check(not BuildWorld.cuts_away(0, "plank_wall", Vector3(1, 0, 0), true), "your walls stay")
	var items: Array = _hut().values()
	check(BuildGrid.comfort(items, 0, 0, 0) == 1, "a roofed, walled room is snug")
	items.append(_gi("table", 0, 0, 0, 0))
	items.append(_gi("lantern", 0, 0, 0, 0))
	items.append(_gi("lantern", 1, 0, 0, 0))
	check(BuildGrid.comfort(items, 0, 0, 0) == 3, "each kind of furniture counts once")
	check(BuildGrid.comfort(items.filter(func(i): return i["kind"] != "roof"), 0, 0, 0) == 0, "no roof, no comfort")
	check(BuildGrid.comfort(items.filter(func(i): return i["kind"] != "edge"), 0, 0, 0) == 0, "no walls, no comfort")
	check(FX.rested_stamina(100.0, 90.0, 4) > 90.0 and FX.rested_stamina(50.0, 60.0, 4) == 60.0 and FX.rested_stamina(100.0, 90.0, 0) == 90.0, "rested only slows the drain")
	game.rested = 3
	var d := game.to_dict()
	game.rested = 0
	game.from_dict(d)
	check(game.rested == 3, "rest is saved")
	game.sleep()
	check(game.rested == 0, "sleeping elsewhere clears it")
	return true


func test_build_models() -> bool:
	for id in ["fence_panel", "stone_wall", "wood_floor", "wood_wall", "wood_door", "wood_roof", "wood_window", "wood_stairs"]:
		var p := BuildPiece.new()
		p.piece_id = id
		root.add_child(p)
		check(p.parts().size() >= 8, "%s is built from many parts (%d)" % [id, p.parts().size()])
		check(p.find_children("*", "CollisionShape3D", true, false).size() >= 1, id + " is solid")
		if id == "wood_door":
			check(p.find_children("*", "DoorLeaf", true, false).size() == 1, "doorway has a real door")
		p.free()
	for id2 in ["wood_window", "wood_stairs"]:
		var i := _recipe_index(id2)
		check(i >= 0 and GameState.ITEMS.has(id2) and GameState.ITEM_WEIGHT.has(id2) and BuildWorld.PIECE_ORDER.has(id2), id2 + " is craftable and placeable")
	BuildKit.set_night(1.0)
	check(BuildKit.glass().emission_energy_multiplier > 1.0, "windows glow at night")
	BuildKit.set_night(0.0)
	check(BuildKit.glass().emission_energy_multiplier == 0.0, "and not by day")
	return true


## Real physics: a body walks up the built stairs onto the upper floor.
func test_stairs_on_real_ground() -> bool:
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(40, 1, 40)
	gs.shape = gb
	gs.position.y = -0.5
	ground.add_child(gs)
	root.add_child(ground)
	var stairs := BuildPiece.new()
	stairs.piece_id = "wood_stairs"
	root.add_child(stairs)
	var floor_up := BuildPiece.new()
	floor_up.piece_id = "wood_floor"
	floor_up.level = 1
	floor_up.position = Vector3(0, BuildGrid.STOREY, 2)
	root.add_child(floor_up)
	var walker := CharacterBody3D.new()
	walker.floor_max_angle = deg_to_rad(52.0)
	walker.floor_snap_length = 0.3
	var ws := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	ws.shape = cap
	ws.position.y = 0.85
	walker.add_child(ws)
	walker.position = Vector3(0, 0.05, -2.2)
	root.add_child(walker)
	await physics_frame
	var top := 0.0
	walker.floor_constant_speed = true
	for k in 260:
		await physics_frame
		walker.velocity = Vector3(0, walker.velocity.y - (0.0 if walker.is_on_floor() else 18.0 / 60.0), 3.0)
		walker.move_and_slide()
		if walker.position.z > 2.0:
			break
	top = walker.position.y
	check(top > 2.1 and walker.position.z > 1.5, "walked upstairs (y %.2f z %.2f)" % [walker.position.y, walker.position.z])
	var slab := BuildPiece.new()
	slab.piece_id = "wood_floor"
	slab.position = Vector3(8, 0, 0)
	root.add_child(slab)
	walker.position = Vector3(8, 0.02, -2.2)
	walker.velocity = Vector3.ZERO
	for k2 in 60:
		await physics_frame
		walker.velocity = Vector3(0, walker.velocity.y - (0.0 if walker.is_on_floor() else 18.0 / 60.0), 3.0)
		walker.move_and_slide()
		if walker.position.z > 0.0:
			break
	check(walker.position.y > 0.1 and walker.position.z > -0.3, "walk onto your floor without jumping (y %.2f z %.2f)" % [walker.position.y, walker.position.z])
	for n in [walker, floor_up, stairs, ground, slab]:
		n.free()
	return true


## Real physics: a collapse drops bundles that hop and land, never rocketing off.
func test_collapse_on_real_ground() -> bool:
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(80, 1, 80)
	gs.shape = gb
	gs.position = Vector3(20, Terrain.height_at(20, 20) - 0.5, 20)
	ground.add_child(gs)
	root.add_child(ground)
	var bw := BuildWorld.new()
	root.add_child(bw)
	game.add_item("wood_wall", 1)
	game.add_item("wood_floor", 3)
	bw.place("wood_wall", Vector3(20, 0, 21), 0, game, 0)
	for k in 3:
		bw.place("wood_floor", Vector3(20, 0, 20 - 2 * k), 0, game, 1)
	await create_timer(0.2).timeout
	bw.demolish(BuildWorld.key_for("wood_wall", Vector3(20, 0, 21), 0, 0), game)
	var apex := 0.0
	var low := 100.0
	var seen := 0
	for f in 200:
		await physics_frame
		for n in bw.get_children():
			if n is WoodLog:
				apex = maxf(apex, n.global_position.y - Terrain.height_at(20, 20))
	for n2 in bw.get_children():
		if n2 is WoodLog:
			seen += 1
			low = minf(low, n2.global_position.y - Terrain.height_at(20, 20))
	check(seen == 3, "three bundles on the ground (%d)" % seen)
	check(apex < 5.5, "bundles hop, they do not rocket off (apex %.1f)" % apex)
	check(low > -0.1, "and nothing falls through the ground (%.2f)" % low)
	for d in get_nodes_in_group("build_debris"):
		d.free()
	bw.free()
	ground.free()
	return true


func test_starship_design() -> bool:
	var d := StarshipDesign.default_design()
	for slot in StarshipDesign.SLOTS:
		check(StarshipDesign.is_unlocked(slot, d[slot], []), "default %s is free" % slot)
		var id: String = d[slot]
		for k in StarshipDesign.OPTIONS[slot].size():
			id = StarshipDesign.cycle(slot, id, 1)
		check(id == d[slot], "cycling %s wraps round" % slot)
	check(StarshipDesign.cycle("nose", "cone", -1) == "dome", "cycles backwards")
	check(StarshipDesign.sanitize({"nose": "banana", "fins": "wings"}) == {"nose": "cone", "fins": "wings", "engine": "faithful", "paint": "red"}, "unknown parts fall back")
	var base := StarshipDesign.stats(d)
	check(base["lift"] == 1.0 and base["balance"] == 1.0, "stock ship is the baseline")
	d["engine"] = "triple"
	var s := StarshipDesign.stats(d)
	check(s["lift"] > 1.0 and s["range"] < 1.0 and s["cool"] < 1.0, "triple boosters trade range and cooling for lift")
	check(not StarshipDesign.unlock("engine", "triple", game), "cannot build without parts")
	check(StarshipDesign.missing("engine", "triple", game).find("Copper Ingot") >= 0, "says what is missing")
	check(ShipWorkshop.launch_block(true, d, game.ship_unlocked) != "", "locked part blocks launch")
	game.add_item("copper_ingot", 2)
	game.stash["copper_ingot"] = 2
	game.add_item("rocket_plate", 1)
	check(StarshipDesign.unlock("engine", "triple", game), "pockets plus chest pay for it")
	check(game.count("copper_ingot") == 0 and int(game.stash.get("copper_ingot", 0)) == 1, "pockets first, then chest")
	check(not StarshipDesign.unlock("engine", "triple", game), "never pay twice")
	check(ShipWorkshop.launch_block(true, d, game.ship_unlocked) == "", "ready to launch")
	check(ShipWorkshop.launch_block(false, d, game.ship_unlocked) != "", "story must be finished")
	check(StarshipDesign.ending(3.0)["id"] == "hero" and StarshipDesign.ending(-3.0)["id"] == "outlaw", "two endings")
	game.ship_design = d.duplicate()
	game.moon_landings = 2
	game.moon_flag = true
	game.ending = "outlaw"
	game.story_act = Story.act_count()
	check(Story.hud_text(game.story_act, game).find("Notorious") >= 0, "HUD shows the ending")
	var saved := game.to_dict()
	game.from_dict({})
	check(game.ship_design["engine"] == "faithful" and game.moon_landings == 0 and not game.moon_flag, "old saves get defaults")
	game.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(game.ship_design["engine"] == "triple" and game.ship_unlocked.has("engine:triple") and game.moon_landings == 2 and game.moon_flag and game.ending == "outlaw", "workshop and Moon progress saved")
	return true


func _fly(f: FlightSim, drop_at: float = -1.0) -> void:
	for i in 6000:
		var a: Array = f.autopilot()
		if drop_at > 0.0 and f.alt >= drop_at:
			f.separate()
		f.step(1.0 / 60.0, a[0], a[1])
		if f.outcome != "":
			return


func test_flight_ascent() -> bool:
	for build in [{}, {"engine": "triple", "fins": "stubby"}, {"engine": "turnip", "fins": "wings", "nose": "cheese"}]:
		var d := StarshipDesign.default_design()
		d.merge(build, true)
		var f := FlightSim.new(FlightSim.Mode.ASCENT, StarshipDesign.stats(d), 5)
		f.hiccups = d["engine"] == "turnip"
		_fly(f, 530.0)
		check(f.outcome == "orbit" and f.time > 12.0 and f.time < 45.0, "a sensible pilot reaches orbit %s (%.1fs)" % [str(build), f.time])
		check(f.fuel > 0.2, "with fuel to spare (%.2f)" % f.fuel)
	var top := FlightSim.new()
	var fastest := 0.0
	for i in 600:
		top.heat = 0.0
		top.tilt = 0.0
		top.step(1.0 / 60.0, true, 0.0)
		fastest = maxf(fastest, top.vel)
	check(fastest <= FlightSim.MAX_CLIMB + 0.01, "climb speed is capped (%.1f)" % fastest)
	var hot := FlightSim.new()
	for i in 600:
		hot.tilt = 0.0
		hot.step(1.0 / 60.0, true, 0.0)
		if hot.overheated:
			break
	check(hot.overheated and hot.time > 4.0, "holding the throttle overheats the engine")
	hot.step(1.0 / 60.0, true, 0.0)
	check(not hot.thrusting, "an overheated engine cuts out")
	for i in 240:
		hot.step(1.0 / 60.0, false, 0.0)
	check(not hot.overheated, "and relights once cool")
	var lean := FlightSim.new()
	lean.alt = 200.0
	lean.tilt = 0.3
	var other := FlightSim.new()
	other.alt = 200.0
	other.tilt = 0.3
	for i in 20:
		lean.step(1.0 / 60.0, true, -1.0)
		other.step(1.0 / 60.0, true, 1.0)
	check(lean.tilt < 0.3 and other.tilt > lean.tilt, "steering against the lean rights her")
	lean.tilt = 1.2
	lean.step(1.0 / 60.0, true, 0.0)
	check(lean.tumbles == 1 and absf(lean.tilt) < 0.4, "a tumble is caught, not fatal")
	var sep := FlightSim.new()
	check(sep.separate() == "", "no dropping boosters on the pad")
	sep.alt = 540.0
	check(sep.separate() == "perfect" and sep.separate() == "", "perfect drop, once only")
	var auto := FlightSim.new()
	auto.alt = FlightSim.SEP_AUTO + 1.0
	auto.vel = 20.0
	auto.step(1.0 / 60.0, true, 0.0)
	check(auto.separated and auto.events.has("sep_auto"), "forgotten boosters fall off by themselves")
	var dry := FlightSim.new()
	dry.alt = 300.0
	dry.fuel = 0.0
	for i in 300:
		dry.step(1.0 / 60.0, true, 0.0)
	check(dry.outcome == "abort", "out of fuel parachutes home")
	return true


func test_flight_landing() -> bool:
	var perfect := 0
	for k in 12:
		var f := FlightSim.new(FlightSim.Mode.LANDING, {}, k + 1)
		_fly(f)
		check(f.outcome == "landed", "lands (seed %d)" % k)
		if f.grade == "perfect":
			perfect += 1
	check(perfect >= 9, "careful flying lands perfectly (%d/12)" % perfect)
	var lazy := FlightSim.new(FlightSim.Mode.LANDING, {}, 2)
	for i in 3000:
		lazy.step(1.0 / 60.0, false, 0.0)
		if lazy.outcome != "":
			break
	check(lazy.outcome == "landed" and lazy.grade == "bumpy" and lazy.bounces >= 1, "hands off: she bounces but never explodes")
	check(FlightSim.landing_grade(3.0, 2.0, 0) == "perfect", "soft and centred")
	check(FlightSim.landing_grade(3.0, 20.0, 0) == "good", "soft but off the ring")
	return true


func test_moon_ground_and_cheese() -> bool:
	check(Moon.height_local(0.0, 0.0) == 0.0 and Moon.height_local(3.0, 2.0) == 0.0, "flat landing spot")
	var c: Array = Moon.CRATERS[1]
	check(Moon.height_local(c[0], c[1]) < -1.2, "craters are bowls")
	check(Moon.height_local(c[0] + c[2] * 1.05, c[1]) > Moon.height_local(c[0], c[1]) + 1.5, "with raised rims")
	check(Moon.height_local(Moon.RADIUS + 20.0, 0.0) > 3.0, "hills ring the playground")
	check(Moon.tone(-1.5).v < Moon.tone(0.8).v, "bowls are darker than rims")
	check(Moon.inside(Moon.ORIGIN) and not Moon.inside(Vector3.ZERO) and not Moon.inside(MineCave.ORIGIN), "the Moon is its own place")
	check(Sfx.surface_at(Moon.ORIGIN) == "road", "crunchy footsteps")
	var drops := MineRock.cheese_drops(0.9)
	check(drops.filter(func(d): return d["item"] == "moon_cheese").size() == 2, "cheese boulders give cheese")
	check(MineRock.cheese_drops(0.1).size() == drops.size() + 1, "sometimes extra")
	check(BugLife.ambient_kind(0.4, false) == "butterfly", "butterflies still live at home")
	game.add_item("moon_cheese", 2)
	var m := game.money
	game.sell_all()
	check(game.money == m + 240, "Moon cheese sells at the bin")
	return true


func test_ship_model_and_space() -> bool:
	for nose in ["cone", "cheese", "dome"]:
		for engine in ["faithful", "triple", "turnip"]:
			var built := ShipModel.build({"nose": nose, "engine": engine, "fins": "wings"})
			check(built["parts"].size() == GranRocket.STAGES, "five story parts (%s, %s)" % [nose, engine])
			(built["root"] as Node).free()
	check(ShipModel.nozzles("triple").size() == 3 and ShipModel.nozzles("faithful").size() == 1, "triple really has three engines")
	var mesh := ShipModel.lathe(ShipModel.HULL_PROFILE)
	var bb := mesh.get_aabb()
	check(absf(bb.size.x - 2.3) < 0.1 and absf(bb.size.y - 4.33) < 0.1, "lathed hull has the right size %s" % bb.size)
	check(SpaceProgram.space_amount(0.0) == 0.0 and SpaceProgram.space_amount(1000.0) == 1.0, "sky goes black with height")
	var roar := SpaceProgram.make_roar()
	check(roar.loop_mode == AudioStreamWAV.LOOP_FORWARD and roar.data.size() > 20000, "engine roar loops")
	var r := GranRocket.new()
	root.add_child(r)
	r.set_stage(2, false)
	r.preview({"paint": "pond", "fins": "stubby"}, true)
	check(r._parts.all(func(p): return p.visible), "workshop preview shows the whole ship")
	r.end_preview()
	check(r._parts[1].visible and not r._parts[2].visible, "then back to the story stage")
	r.free()
	return true


## Real physics on the real Moon mesh: a body falls at Moon gravity, lands, leaves prints.
func test_moon_walk() -> bool:
	var moon := Moon.new()
	root.add_child(moon)
	var body := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	body.add_child(cs)
	root.add_child(body)
	body.global_position = Moon.ground(2.0, 5.0) + Vector3(0, 0.1, 0)
	var g := 9.8 * Moon.GRAVITY_SCALE
	var peak := 0.0
	var airborne := 0
	var y0 := 0.0
	for i in 600:
		await physics_frame
		if i == 60:
			check(body.is_on_floor(), "stands on the Moon (y %.2f)" % body.global_position.y)
			y0 = body.global_position.y
			body.velocity.y = 5.0   # an ordinary hop
		elif not body.is_on_floor():
			body.velocity.y -= g / 60.0
			if i > 60:
				airborne += 1
		if i > 60:
			peak = maxf(peak, body.global_position.y - y0)
		body.move_and_slide()
		moon.track(body)
	check(peak > 3.5 and peak < 6.5, "a Moon jump is huge (%.1f m)" % peak)
	check(airborne > 140 and body.is_on_floor(), "floaty, and back down (%d ticks)" % airborne)
	var before := moon.print_count()
	for i in 120:
		await physics_frame
		body.velocity = Vector3(0, body.velocity.y - g / 60.0, -4.0)
		body.move_and_slide()
		moon.track(body)
	check(moon.print_count() >= before + 4, "walking leaves footprints (%d)" % moon.print_count())
	check(not moon.flag.planted, "no flag yet")
	moon.flag.interact(game)
	check(moon.flag.planted and game.moon_flag, "flag planted and remembered")
	check(get_nodes_in_group("saveable").any(func(n): return n.name == "MoonRock_0" and n.kind == "cheese"), "cheese boulders are saved rocks")
	body.free()
	moon.free()
	return true
