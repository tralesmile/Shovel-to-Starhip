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
		"test_save_roundtrip",
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
	for night in FarmPlot.GROW_DAYS:
		game.set_tool(GameState.Tool.WATER)
		p.interact(game)
		check(p.watered, "watered night %d" % night)
		check(not p.is_ripe(), "not ripe before night %d" % night)
		game.advance_day()
		check(not p.watered, "soil dries overnight %d" % night)
	check(p.is_ripe(), "ripe after %d watered nights" % FarmPlot.GROW_DAYS)
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
