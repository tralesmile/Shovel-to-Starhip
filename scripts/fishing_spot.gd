class_name FishingSpot
extends Interactable
## The jetty. Hold E to wind up a cast (release to throw where the camera looks), watch
## the shadows nibble, press E when the bobber dunks, then win the tug-of-war: hold to
## reel, let go while the fish thrashes. The catch flies out and flops on the bank.

enum Phase { IDLE, CHARGING, FLYING, LINE, FIGHT }

const WALK_AWAY := 3.6         ## stray further than this and the line comes in
const CAST_RADIUS := 7.0       ## casts are nudged to stay on the water
const FLIGHT_TIME := 0.75
const CATCH_FLIGHT := 0.95

var fishing: Fishing = null
var fight: FishFight = null
var phase: int = Phase.IDLE
var next_seed: int = 1
var pond: PondLife
var held_override := -1        ## tests: -1 read input, 0 released, 1 held
var charge := 0.0
var baited := false
var bobber_pos := Vector2.ZERO

var _game: GameState
var _t := 0.0
var _from := Vector3.ZERO
var _hook := {}                ## species / cm of what is on the line
var _fight_start := Vector2.ZERO
var _dunk := 0.0
var _bobber: Node3D
var _line: MeshInstance3D
var _line_mat: StandardMaterial3D
var _target_ring: MeshInstance3D
var _alert: Label3D
var _splash_in := 0.0
var _reel_tick := 0.0


func _ready() -> void:
	add_to_group("fishing_spot")


## Which way to throw: where the camera looks if that is roughly at the water,
## otherwise straight at the middle of the pond (no casting into the shrubbery). Pure.
static func aim_dir(look: Vector2, to_pond: Vector2) -> Vector2:
	var p := to_pond.normalized()
	if look.length() < 0.01:
		return p
	var l := look.normalized()
	return l if l.dot(p) > 0.5 else p


static func landing(from: Vector2, dir: Vector2, dist: float) -> Vector2:
	return PondLife.clamp_to_pond(from + dir.normalized() * dist, CAST_RADIUS)


## Launch velocity that takes a body from `a` to `b` in `t` seconds under gravity `g`. Pure.
static func lob_velocity(a: Vector3, b: Vector3, t: float, g: float) -> Vector3:
	var v := (b - a) / t
	v.y += 0.5 * g * t
	return v


func is_busy() -> bool:
	return phase != Phase.IDLE


func get_prompt(g: GameState) -> String:
	match phase:
		Phase.CHARGING:
			return "Let go to cast!"
		Phase.FLYING:
			return "Wheee..."
		Phase.FIGHT:
			return "HOLD [E] to reel  -  LET GO while it thrashes!"
		Phase.LINE:
			match fishing.state:
				"bite":
					return "[E] NOW!! Something is pulling!"
				"done":
					return "[E] Reel in (it seems to have left)"
			return "Waiting... (E to reel in)"
	if g != null and not g.fish_log.is_empty():
		return "[E] Hold to cast a line   (Fish Journal %d/%d)" % [g.fish_log.size(), Fishing.SIZES.size()]
	return "[E] Hold to cast a line"


func interact(game: GameState) -> void:
	_game = game
	match phase:
		Phase.IDLE:
			phase = Phase.CHARGING
			charge = 0.0
		Phase.LINE:
			_set_hook(game)


func _held() -> bool:
	if held_override >= 0:
		return held_override == 1
	return Input.is_action_pressed("interact") or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)


## Untyped on purpose: naming Player here would drag the Game autoload into headless tests.
func _player():
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Release the wind-up: pick a landing spot and send the bobber flying.
func launch(game: GameState, power: float, look: Vector2) -> void:
	_game = game
	var from := _flat(global_position if is_inside_tree() else position)
	var dir := aim_dir(look, Terrain.POND_CENTER - from)
	var has_rod := game.count("springy_rod") > 0
	bobber_pos = landing(from, dir, Fishing.cast_distance(power, has_rod))
	baited = game.count("sunmint_bait") > 0 and game.remove_item("sunmint_bait", 1)
	next_seed += 7
	fishing = Fishing.new(next_seed + game.day * 13 + int(Time.get_ticks_msec()))
	phase = Phase.FLYING
	_t = 0.0
	var p = _player()
	if p != null:
		_from = p.rod_tip()
		p.face_point(Vector3(bobber_pos.x, p.global_position.y, bobber_pos.y))
		p.rod_cast()
	else:
		_from = Vector3(from.x, 1.8, from.y)
	Sfx.play_on(self, "swish", 1.25)
	game.hint_event.emit("cast")


func _bobber_lands() -> void:
	phase = Phase.LINE
	fishing.cast()
	Sfx.play_on(self, "splash", 1.35)
	if pond != null:
		fishing.bite_time = INF      # the fish in the pond decide when
		pond.splash(bobber_pos, 0.45)
		if pond.set_bobber(bobber_pos, baited):
			_game.say("SPLOOSH. Right on a fish's head. It has opinions.")
		elif baited:
			_game.say("Sunmint bait out. Smells like a very fresh sock.")
	else:
		_game.say("Plop. Now we wait. Fish are famously punctual.")


## E pressed while the line is out: set the hook, or reel in early/late.
func _set_hook(game: GameState) -> void:
	match fishing.reel():
		"early":
			game.say("Too eager. The fish saw you coming.")
			_end()
		"late":
			game.say("Too slow. The fish took the bait AND your dignity.")
			_end()
		"hooked":
			var species := pond.hooked_species() if pond != null else ""
			var cm := 0
			if species != "":
				cm = pond.hooked_cm()
				_hook = pond.take_hooked()
			else:
				species = Fishing.roll_fish(fishing.rng.randf())
				cm = Fishing.size_for(species, fishing.rng.randf())
				_hook = {}
			_hook["species"] = species
			_hook["cm"] = cm
			start_fight(game, species)


func start_fight(game: GameState, species: String) -> void:
	_game = game
	phase = Phase.FIGHT
	fight = FishFight.new(species, game.count("springy_rod") > 0, Fishing.total_catches(game.fish_log), fishing.rng.randi())
	_fight_start = bobber_pos
	game.say("Hooked something %s!" % ("HEAVY" if int(_hook.get("cm", 20)) > 40 else "wriggly"))
	game.shake.emit(0.2)
	Sfx.play_on(self, "splash", 0.9)
	if is_inside_tree():
		FX.hit_stop(get_tree(), 0.5)
	if pond != null:
		pond.splash(bobber_pos, 1.0)
	game.hint_event.emit("fight")


func _process(delta: float) -> void:
	match phase:
		Phase.CHARGING:
			if _held():
				charge += delta
				var p = _player()
				if p != null:
					p.rod_windup(Fishing.cast_power(charge))
			else:
				var p2 = _player()
				var look := Vector2.ZERO
				if p2 != null:
					look = Vector2(-sin(p2._yaw), -cos(p2._yaw))
				launch(_game, Fishing.cast_power(charge), look)
		Phase.FLYING:
			_t += delta / FLIGHT_TIME
			if _t >= 1.0:
				_bobber_lands()
		Phase.LINE:
			_tick_line(delta)
		Phase.FIGHT:
			_tick_fight(delta)
	if phase != Phase.IDLE:
		var p3 = _player()
		if p3 != null and (p3.vehicle != null or p3.mount != null or _flat(p3.global_position - global_position).length() > WALK_AWAY):
			_game.say("You wandered off, so the line came home.")
			_end()
	_update_visuals(delta)


func _tick_line(delta: float) -> void:
	var was := fishing.state
	fishing.tick(delta)
	if pond != null:
		var ev := pond.tick_event
		pond.tick_event = ""
		if ev == "nibble" and fishing.state == "waiting":
			_dunk = 0.09
			pond.add_ripple(bobber_pos, 0.45)
			Sfx.play_on(self, "drip", 0.8)
		elif ev == "bite" and fishing.state == "waiting":
			fishing.bite()
	if was != "bite" and fishing.state == "bite":
		_dunk = 0.32
		Sfx.play_on(self, "splash", 1.7)
		if pond != null:
			pond.splash(bobber_pos, 0.7)
		if _game != null:
			_game.shake.emit(0.12)
	if was == "bite" and fishing.state == "done" and pond != null:
		pond.clear_bobber()


func _tick_fight(delta: float) -> void:
	var reeling := _held()
	var result := fight.tick(delta, reeling)
	var from := _flat(global_position if is_inside_tree() else position)
	var shore := from + (Terrain.POND_CENTER - from).normalized() * 2.6
	var side := (shore - _fight_start).normalized().orthogonal()
	_t += delta
	var wobble := sin(_t * (11.0 if fight.surging else 3.0)) * (0.55 if fight.surging else 0.12)
	bobber_pos = PondLife.clamp_to_pond(_fight_start.lerp(shore, fight.progress) + side * wobble, CAST_RADIUS + 0.4)
	_splash_in -= delta
	if _splash_in <= 0.0:
		_splash_in = 0.17 if fight.surging else 0.55
		if pond != null:
			if fight.surging:
				pond.splash(bobber_pos, 0.75)
				Sfx.play_on(self, "splash", randf_range(1.2, 1.6))
			else:
				pond.add_ripple(bobber_pos, 0.5)
	_reel_tick -= delta
	if reeling and _reel_tick <= 0.0:
		_reel_tick = 0.09
		Sfx.play_on(self, "blip", 0.55 + fight.tension * 1.1)   # the reel clicks higher as the line tightens
	if fight.surging and _game != null and reeling and fight.tension > 0.7:
		_game.shake.emit(0.05)
	if result != "":
		_finish_fight(result)


func _finish_fight(result: String) -> void:
	var species: String = fight.species
	var cm: int = int(_hook.get("cm", Fishing.size_for(species, 0.5)))
	var game := _game
	match result:
		"snapped":
			game.say("TWANG! The line snapped. Let go while it thrashes.")
			Sfx.play_on(self, "zap", 0.7)
			game.shake.emit(0.3)
		"escaped":
			game.say("It wriggled free. Reel while it rests!")
		"landed":
			_land(game, species, cm)
	if result != "landed" and pond != null:
		pond.splash(bobber_pos, 0.8)
	_end()


## The catch leaps out of the water onto the bank as a physics pickup.
func _land(game: GameState, species: String, cm: int) -> void:
	var rec := Fishing.log_catch(game.fish_log, species, cm)
	var line := "Caught: %s, %d cm!" % [game.item_name(species), cm]
	if rec == "new":
		line += "  NEW in the Fish Journal (%d/%d)" % [game.fish_log.size(), Fishing.SIZES.size()]
	elif rec == "best":
		line += "  Personal best!"
	game.say(line)
	if species == "golden_carp":
		game.say("It looks smug and valuable.")
	if rec != "":
		Sfx.play_on(self, "happy", 1.1 if rec == "new" else 1.35)
	if pond != null:
		pond.splash(bobber_pos, 1.3)
		pond.restock()
	game.shake.emit(0.18 + minf(0.3, cm * 0.004))
	var p = _player()
	if p == null:
		game.add_item(species)
		return
	var item := WoodLog.new()
	item.item_id = species
	item.catch_cm = cm
	item.game = game
	item.age = -1.4         # it gets to land and flop about before it can be scooped up
	get_parent().add_child(item)
	var start := Vector3(bobber_pos.x, Terrain.WATER_LEVEL + 0.2, bobber_pos.y)
	var away: Vector2 = _flat(p.global_position) - bobber_pos
	var aside := away.normalized().orthogonal() * (1.5 if randf() < 0.5 else -1.5)
	var dst2: Vector2 = _flat(p.global_position) + aside + away.normalized() * 0.5
	var dst := Vector3(dst2.x, Terrain.height_at(dst2.x, dst2.y) + 0.5, dst2.y)
	item.global_position = start
	item.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	item.linear_damp = 0.0
	item.linear_velocity = lob_velocity(start, dst, CATCH_FLIGHT, 9.8)
	item.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-2, 2), randf_range(5, 9))
	p.play_action("Cheer", 0.8)


## Reel everything in.
func _end() -> void:
	if pond != null:
		if _hook.has("pos"):
			pond.restock()
		else:
			pond.clear_bobber()
	_hook = {}
	fight = null
	fishing = null
	phase = Phase.IDLE
	var p = _player()
	if p != null:
		p.set_rod(false)


# ---------------------------------------------------------------- what you see

func _build_visuals() -> void:
	_bobber = Node3D.new()
	_bobber.top_level = true
	var top := Art.sphere(0.13, Color(0.95, 0.2, 0.15), 5, 10)
	top.position.y = 0.05
	_bobber.add_child(top)
	var bottom := Art.sphere(0.115, Color(0.97, 0.97, 0.93), 5, 10)
	bottom.position.y = -0.03
	_bobber.add_child(bottom)
	var stick := Art.cylinder(0.015, 0.015, 0.2, Color(0.15, 0.12, 0.1), 5)
	stick.position.y = 0.22
	_bobber.add_child(stick)
	add_child(_bobber)
	_line = MeshInstance3D.new()
	_line.top_level = true
	_line.mesh = ImmediateMesh.new()
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line.material_override = _line_mat
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_target_ring = MeshInstance3D.new()
	_target_ring.top_level = true
	var tm := TorusMesh.new()
	tm.inner_radius = 0.34
	tm.outer_radius = 0.42
	tm.rings = 24
	tm.ring_segments = 4
	_target_ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1.0, 0.92, 0.35, 0.85)
	rm.render_priority = 2
	_target_ring.material_override = rm
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_target_ring)
	_alert = Art.label("!", 200, Color(1.0, 0.85, 0.15))
	_alert.top_level = true
	add_child(_alert)


func _update_visuals(delta: float) -> void:
	if not is_inside_tree():
		return
	if _bobber == null:
		if phase == Phase.IDLE:
			return
		_build_visuals()
	var p = _player()
	_dunk = move_toward(_dunk, 0.0, delta * 0.55)
	if fishing != null and fishing.state == "bite":
		_dunk = maxf(_dunk, 0.24)
	var water_y := Terrain.WATER_LEVEL + 0.1
	var pos := Vector3(bobber_pos.x, water_y, bobber_pos.y)
	_bobber.visible = phase == Phase.FLYING or phase == Phase.LINE or phase == Phase.FIGHT
	if phase == Phase.FLYING:
		var k := clampf(_t, 0.0, 1.0)
		pos = _from.lerp(pos, k)
		pos.y += sin(k * PI) * 2.0
	elif phase == Phase.LINE:
		pos.y += sin(Time.get_ticks_msec() * 0.003) * 0.025 - _dunk
	elif phase == Phase.FIGHT:
		pos.y -= 0.14 if fight != null and fight.surging else 0.05
	if _bobber.visible:
		_bobber.global_position = pos
	_alert.visible = phase == Phase.LINE and fishing != null and fishing.state == "bite"
	if _alert.visible:
		var s := 1.0 + 0.18 * sin(Time.get_ticks_msec() * 0.025)
		_alert.global_position = pos + Vector3(0, 1.1, 0)
		_alert.scale = Vector3(s, 2.0 - s, s)
	_target_ring.visible = phase == Phase.CHARGING and _game != null
	if _target_ring.visible:
		var from := _flat(global_position)
		var look := Vector2.ZERO
		if p != null:
			look = Vector2(-sin(p._yaw), -cos(p._yaw))
		var at := landing(from, aim_dir(look, Terrain.POND_CENTER - from), Fishing.cast_distance(Fishing.cast_power(charge), _game.count("springy_rod") > 0))
		_target_ring.global_position = Vector3(at.x, Terrain.WATER_LEVEL + 0.17, at.y)
	if p != null and phase != Phase.IDLE:
		if (phase == Phase.LINE or phase == Phase.FIGHT) and Vector2(p.velocity.x, p.velocity.z).length() < 0.4:
			p.face_point(Vector3(bobber_pos.x, p.global_position.y, bobber_pos.y))
		var bend := 0.0
		if phase == Phase.FIGHT and fight != null:
			bend = 0.25 + fight.tension * 0.75
		elif phase == Phase.LINE and _dunk > 0.1:
			bend = 0.5
		if phase != Phase.CHARGING:
			p.rod_bend(bend)
	_draw_line(p)


## A thin camera-facing ribbon from rod tip to bobber: it sags when slack, goes taut
## and turns red as the line is about to snap.
func _draw_line(p) -> void:
	var im := _line.mesh as ImmediateMesh
	im.clear_surfaces()
	if not _bobber.visible or p == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var a: Vector3 = p.rod_tip()
	var b := _bobber.global_position + Vector3(0, 0.25, 0)
	var strain := fight.tension if phase == Phase.FIGHT and fight != null else 0.0
	var sag := 0.0 if phase == Phase.FIGHT else (0.25 if phase == Phase.FLYING else 0.6)
	_line_mat.albedo_color = Color(0.96, 0.96, 0.92).lerp(Color(1.0, 0.18, 0.1), smoothstep(0.55, 0.95, strain))
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 15:
		var k := i / 14.0
		var pt := a.lerp(b, k)
		pt.y -= sin(k * PI) * sag
		var side := (b - a).cross(cam.global_position - pt).normalized() * 0.011
		im.surface_add_vertex(pt - side)
		im.surface_add_vertex(pt + side)
	im.surface_end()
