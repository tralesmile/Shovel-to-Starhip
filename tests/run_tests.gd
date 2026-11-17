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
		"test_no_seeds", "test_tree_chop_and_regrow", "test_shop_station", "test_clock_text",
		"test_save_roundtrip", "test_door_enter_exit", "test_npc_schedule", "test_npc_routine_movement",
		"test_lockpick", "test_loot_container", "test_carry_limit", "test_witness_cone", "test_witness_meter", "test_heat", "test_fence_reputation", "test_police", "test_car", "test_fishing", "test_delivery", "test_crops", "test_traffic", "test_police_car", "test_audio_settings",
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
	check(t.felled and game.count("wood") == ChoppableTree.WOOD_DROP, "tree falls and drops wood")
	t.interact(game)
	check(game.count("wood") == ChoppableTree.WOOD_DROP, "stump gives no more wood")
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
