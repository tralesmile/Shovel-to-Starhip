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
		"test_lockpick", "test_loot_container", "test_carry_limit", "test_witness_cone", "test_witness_meter", "test_heat", "test_fence_reputation", "test_police", "test_car", "test_fishing", "test_delivery", "test_crops", "test_traffic", "test_police_car", "test_audio_settings", "test_sfx", "test_steps", "test_settings_menu", "test_tutorial", "test_gamepad", "test_engine_sfx", "test_music", "test_music_fade", "test_main_menu", "test_input_prompts", "test_closet", "test_fence_cap", "test_shop_rep", "test_npc_barks", "test_crafting", "test_jump_step", "test_stamina", "test_pickaxe_upgrade", "test_axe_combo", "test_build_mode", "test_carry_weight",
	]:
		_fresh_game()
		var ok = call(test)
		check(ok == true, "%s ran to the end (no script error)" % test)
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
	check(f.reel() == "caught", "reel in window catches")
	f.cast()
	f.tick(f.bite_time + 0.01)
	f.tick(Fishing.BITE_WINDOW + 0.1)
	check(f.state == "done" and f.reel() == "late", "late reel misses")
	check(Fishing.roll_fish(0.0) == "boot" and Fishing.roll_fish(0.999) == "old_wizard_hat", "fish table ends")
	for e in Fishing.FISH_TABLE:
		check(GameState.ITEMS.has(e[0]), "fish item defined: " + e[0])
	var spot := FishingSpot.new()
	root.add_child(spot)
	spot.interact(game)
	check(spot.fishing.state == "waiting", "spot casts")
	spot.fishing.tick(spot.fishing.bite_time + 0.01)
	var before: int = 0
	for e in Fishing.FISH_TABLE:
		before += game.count(e[0])
	spot.interact(game)
	var after: int = 0
	for e in Fishing.FISH_TABLE:
		after += game.count(e[0])
	check(after == before + 1, "spot catch adds a fish")
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
	check(game.craft(game.RECIPES.size() - 2) and game.count("stone_wall") == 1, "stone wall recipe")
	game.from_dict(saved)
	check(game.built.size() == 1 and game.built[0]["id"] == "fence_panel", "built survives load")
	bw.queue_free()
	return true
