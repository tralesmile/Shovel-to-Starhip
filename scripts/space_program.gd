class_name SpaceProgram
extends Node3D
## Everything between the launch pad and the Moon: the workshop camera, countdown, the
## hands-on climb to orbit, the lunar landing, walking about up there, and the trip home.

enum State { IDLE, WORKSHOP, COUNTDOWN, ASCENT, TRANSIT, LANDING, ARRIVING, MOON, HOMEWARD }

const VIEW_RISE := 0.28      ## world metres drawn per metre of flight altitude
const LAND_RISE := 0.24
const COUNT_TIME := 3.6
const PAD_CAM := Vector3(-9.0, 2.2, 14.5)

var state: int = State.IDLE
var player: CharacterBody3D   ## the Player (untyped so this compiles without the Game autoload)
var game: GameState
var rocket: GranRocket
var moon: Moon
var hud_layer: CanvasLayer     ## the everyday HUD, hidden while flying
var sim: FlightSim
var scripted := Callable()     ## tests/screenshots: returns [throttle, steer, separate]
var cam: Camera3D
var ui: FlightHud
var ship: Node3D               ## the ship being flown
var lander: Node3D             ## parked on the Moon
var workshop: ShipWorkshop

var _flames: Array[Node3D] = []
var _flame_light: OmniLight3D
var _smoke: CPUParticles3D
var _streaks: CPUParticles3D
var _boosters: Array[Node3D] = []
var _chute: Node3D
var _roar: AudioStreamPlayer
var _t := 0.0
var _count_n := -1
var _shake := 0.0
var _power := 0.0
var _smoke_acc := 0.0
var _clock_was := true
var _lean_warned := false
var _shout_t := 0.0


## True while the player is anywhere but the valley (flying or on the Moon).
func away() -> bool:
	return state != State.IDLE and state != State.WORKSHOP


func flying() -> bool:
	return away() and state != State.MOON


func _ready() -> void:
	add_to_group("space_program")
	if game == null:
		game = get_node_or_null("/root/Game") as GameState
	moon = Moon.new()
	add_child(moon)
	moon.visible = false
	_build_lander()
	cam = Camera3D.new()
	cam.fov = 62
	add_child(cam)
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	ui = FlightHud.new()
	ui.visible = false
	layer.add_child(ui)
	_roar = AudioStreamPlayer.new()
	_roar.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	_roar.stream = make_roar()
	add_child(_roar)


## A seamless rumbling loop for the engines (low-passed noise, cross-faded at the seam).
static func make_roar() -> AudioStreamWAV:
	var rate := 22050
	var n := rate
	var blend := 2000
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var raw := PackedFloat32Array()
	var y := 0.0
	var y2 := 0.0
	for i in n + blend:
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.09
		y2 += (y - y2) * 0.35
		raw.append(clampf(y2 * 3.6, -1.0, 1.0))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := raw[i]
		if i < blend:
			v = lerpf(raw[n + i], raw[i], float(i) / blend)
		data.encode_s16(i * 2, int(v * 24000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


# ------------------------------------------------------------------ workshop

func open_workshop() -> void:
	if state != State.IDLE or player == null or rocket == null:
		return
	state = State.WORKSHOP
	_freeze_player(true)
	_show_hud(false)
	var at := rocket.global_position
	cam.fov = 55
	var from := at + Vector3(-6.5, 4.6, 12.5)
	var fwd := (at + Vector3(0, 3.4, 0) - from).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	cam.global_position = from
	cam.look_at(at + Vector3(0, 3.4, 0) + right * 3.6)
	cam.current = true
	workshop = ShipWorkshop.new()
	workshop.game = game
	workshop.rocket = rocket
	workshop.closed.connect(close_workshop)
	workshop.launch_requested.connect(launch)
	add_child(workshop)
	rocket.preview(game.ship_design, true)


func close_workshop() -> void:
	if state != State.WORKSHOP:
		return
	_drop_workshop()
	rocket.end_preview()
	state = State.IDLE
	_restore_player()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _drop_workshop() -> void:
	if workshop != null:
		workshop.queue_free()
		workshop = null


func _freeze_player(on: bool) -> void:
	player.set_physics_process(not on)
	player.set_process_unhandled_input(not on)
	player.velocity = Vector3.ZERO


func _show_hud(on: bool) -> void:
	if hud_layer != null:
		hud_layer.visible = on


func _restore_player() -> void:
	_freeze_player(false)
	player.set_model_shown(true)
	player.camera.current = true
	_show_hud(true)


# ------------------------------------------------------------------ launch

func launch() -> void:
	if state != State.IDLE and state != State.WORKSHOP:
		return
	if not Story.is_finished(game.story_act):
		return
	_drop_workshop()
	rocket.end_preview()
	player.release_pet()
	_freeze_player(true)
	player.set_model_shown(false)
	_show_hud(false)
	_clock_was = game.clock_running
	game.clock_running = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rocket.visible = false
	_make_ship(true)
	ship.global_position = rocket.global_position
	sim = FlightSim.new(FlightSim.Mode.ASCENT, StarshipDesign.stats(game.ship_design), game.day * 31 + game.moon_landings)
	sim.gentle = game.moon_landings == 0
	sim.hiccups = game.ship_design["engine"] == "turnip"
	ui.sim = sim
	ui.visible = true
	ui.fade = 0.0
	ui.card_title = ""
	ui.big = ""
	ui.hint = "Strapping in..."
	state = State.COUNTDOWN
	_t = 0.0
	_count_n = -1
	_power = 0.0
	cam.fov = 62
	cam.global_position = rocket.global_position + PAD_CAM
	cam.look_at(rocket.global_position + Vector3(0, 3.6, 0))
	cam.current = true


func _make_ship(with_boosters: bool) -> void:
	_clear_ship()
	ship = Node3D.new()
	add_child(ship)
	var tilt := Node3D.new()
	tilt.name = "Tilt"
	ship.add_child(tilt)
	var built := ShipModel.build(game.ship_design)
	tilt.add_child(built["root"])
	_flames = []
	var tint := Color(0.55, 0.9, 0.25) if game.ship_design["engine"] == "turnip" else Color(1.0, 0.38, 0.06)
	for nz in ShipModel.nozzles(game.ship_design["engine"]):
		var f := ShipModel.flame(float(nz[1]) * 0.95, tint)
		f.position = nz[0]
		f.visible = false
		tilt.add_child(f)
		_flames.append(f)
	_boosters = []
	if with_boosters:
		for s in [-1.0, 1.0]:
			var b := Node3D.new()
			var tube := ShipModel._mesh_node(ShipModel.lathe([Vector2(0.3, 0.2), Vector2(0.38, 0.7), Vector2(0.38, 2.7), Vector2(0.2, 3.2), Vector2(0.0, 3.4)], 14), ShipModel.hull_material(StarshipDesign.paint_color(game.ship_design), 0.0))
			b.add_child(tube)
			var f := ShipModel.flame(0.3, tint)
			f.position = Vector3(0, 0.2, 0)
			f.visible = false
			b.add_child(f)
			_flames.append(f)
			b.position = Vector3(s * 1.45, 0.35, 0)
			tilt.add_child(b)
			_boosters.append(b)
	_flame_light = OmniLight3D.new()
	_flame_light.light_color = Color(1.0, 0.6, 0.25)
	_flame_light.omni_range = 16.0
	_flame_light.light_energy = 0.0
	_flame_light.position.y = -1.2
	tilt.add_child(_flame_light)
	_smoke = FX.emitter(ship, Color(0.86, 0.86, 0.9), 70, 1.6, 0.8, Vector3(0.35, 0.1, 0.35), Vector3(0, -1.2, 0), false, "sphere")
	_smoke.local_coords = false
	_smoke.direction = Vector3.DOWN
	_smoke.spread = 24.0
	_smoke.initial_velocity_min = 6.0
	_smoke.initial_velocity_max = 11.0
	_smoke.mesh = _soft_puff(0.75)
	_smoke.position.y = -2.6
	_smoke.emitting = false
	_streaks = FX.emitter(cam, Color(0.9, 0.95, 1.0), 40, 0.5, 0.05, Vector3(12.0, 4.0, 3.0), Vector3.ZERO, true, "box")
	_streaks.position = Vector3(0, 9.0, -18.0)
	_streaks.direction = Vector3.DOWN
	_streaks.spread = 0.0
	_streaks.initial_velocity_min = 34.0
	_streaks.initial_velocity_max = 48.0
	var sm := BoxMesh.new()
	sm.size = Vector3(0.035, 1.3, 0.035)
	sm.material = FX.particle_mat(true)
	_streaks.mesh = sm
	_streaks.emitting = false


## A see-through puff so the exhaust trail reads as smoke, not a string of balls.
static func _soft_puff(size: float) -> Mesh:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var s := SphereMesh.new()
	s.radius = size * 0.5
	s.height = size
	s.radial_segments = 8
	s.rings = 4
	s.material = m
	return s


func _clear_ship() -> void:
	if ship != null:
		ship.queue_free()
		ship = null
	if _streaks != null:
		_streaks.queue_free()
		_streaks = null
	_chute = null
	_flames = []
	_boosters = []


func _build_lander() -> void:
	lander = Node3D.new()
	lander.name = "ParkedShip"
	lander.position = Vector3(Moon.PAD.x, 0.0, Moon.PAD.y)
	moon.add_child(lander)
	var spot := LanderSpot.new()
	spot.name = "LanderSpot"
	spot.program = self
	spot.interact_radius = 2.6
	spot.position = Vector3(0, 0, 1.4)
	moon.add_child(spot)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.25
	cyl.height = 6.0
	cs.shape = cyl
	cs.position.y = 3.0
	body.add_child(cs)
	moon.add_child(body)
	# A painted landing ring.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.4
	tm.outer_radius = 3.75
	tm.rings = 48
	ring.mesh = tm
	ring.scale = Vector3(1, 0.15, 1)
	ring.material_override = Art.mat(Color(1.0, 0.8, 0.25), true)
	ring.position.y = 0.05
	moon.add_child(ring)


func _dress_lander() -> void:
	for c in lander.get_children():
		c.queue_free()
	lander.add_child(ShipModel.build(game.ship_design)["root"])


# ------------------------------------------------------------------ per frame

func _controls() -> Array:
	if scripted.is_valid():
		return scripted.call()
	var throttle := Input.is_action_pressed("jump") or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	return [throttle, Input.get_axis("move_left", "move_right"), Input.is_action_just_pressed("interact")]


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_shout_t = maxf(0.0, _shout_t - delta)
	if _shout_t == 0.0 and (state == State.ASCENT or state == State.LANDING):
		ui.big = ""
	match state:
		State.COUNTDOWN:
			_countdown(delta)
		State.ASCENT:
			_ascend(delta)
		State.LANDING:
			_descend(delta)
		State.MOON:
			moon.track(player)
	_update_effects(delta)


func _shout(text: String, secs: float = 1.4) -> void:
	ui.shout(text)
	_shout_t = secs


func _countdown(delta: float) -> void:
	_t += delta
	var n := int(ceil(COUNT_TIME - 0.6 - _t))
	if n != _count_n and n >= 1 and n <= 3:
		_count_n = n
		ui.shout(str(n))
		ui.hint = "Hold SPACE for engines   A / D to stay upright" if not _pad() else "Hold A for engines   stick to stay upright"
		Sfx.play_on(player, "blip", 0.7)
	_shake = 0.05 + 0.25 * clampf(_t / COUNT_TIME, 0.0, 1.0)
	_power = 0.35 * clampf((_t - 1.2) / 2.0, 0.0, 1.0)
	# Venting steam, then the pad disappears in a billow.
	_smoke_acc += delta
	if _smoke_acc > 0.12:
		_smoke_acc = 0.0
		var a := randf() * TAU
		FX.burst(self, rocket.global_position + Vector3(cos(a) * 1.5, 0.5, sin(a) * 1.5), Color(0.93, 0.94, 0.97), 5, 0.5 + _power, 1.6 + 5.0 * _power, 0.4, "sphere", 80.0)
	var base := rocket.global_position
	cam.global_position = base + PAD_CAM
	cam.look_at(base + Vector3(0, 3.6, 0))
	_jolt()
	if _t >= COUNT_TIME - 0.6:
		state = State.ASCENT
		sim.vel = 9.0
		_shout("LIFTOFF!", 1.6)
		Sfx.play_on(player, "boom", 0.8)
		for k in 24:
			var a := k * TAU / 24.0
			FX.burst(self, base + Vector3(cos(a) * 2.2, 0.3, sin(a) * 2.2), Color(0.88, 0.86, 0.84), 7, 0.95, 5.5, -0.5, "sphere", 75.0)


func _pad() -> bool:
	return InputPrompts.use_pad


func _ascend(delta: float) -> void:
	var c := _controls()
	if c[2] and sim.can_separate():
		sim.separate()
	sim.step(delta, c[0], c[1])
	for e in sim.events:
		match e:
			"overheat":
				_shout("OVERHEAT! Ease off!")
				Sfx.play_on(player, "sizzle", 0.7)
			"relight":
				Sfx.play_on(player, "turbo", 0.8)
			"tumble":
				_shout("WHOOPSIE-TUMBLE!")
				_shake = 1.0
				Sfx.play_on(player, "crunch")
			"hiccup":
				_shout("*hic*", 0.7)
				Sfx.play_on(player, "squeak", 0.6)
				FX.burst(self, ship.global_position, Color(0.55, 0.9, 0.35), 18, 0.25, 4.0, -3.0, "sphere", 180.0)
			"sep_perfect":
				_shout("PERFECT DROP!")
				_drop_boosters()
			"sep_ok", "sep_auto":
				_shout("Booster away!")
				_drop_boosters()
			"orbit":
				_to_orbit()
			"abort":
				_abort()
	sim.events.clear()
	if state != State.ASCENT:
		return
	ui.hint = ""
	if sim.can_separate():
		ui.hint = "[E] DROP BOOSTERS" if not _pad() else "[X] DROP BOOSTERS"
	elif sim.time < 7.0:
		ui.hint = "Hold SPACE for engines   A / D to stay upright" if not _pad() else "Hold A for engines   stick to stay upright"
	elif sim.heat > 0.78 and not sim.overheated:
		ui.hint = "Running hot - let go for a moment"
	elif absf(sim.tilt) > FlightSim.WOBBLE_ANGLE:
		ui.hint = "Leaning %s - steer the other way!" % ("right" if sim.tilt > 0.0 else "left")
	_power = lerpf(_power, 1.0 if sim.thrusting else 0.0, minf(1.0, 12.0 * delta))
	var base := rocket.global_position
	ship.global_position = base + Vector3(0, sim.alt * VIEW_RISE, 0)
	(ship.get_node("Tilt") as Node3D).rotation.z = -sim.tilt
	_shake = maxf(_shake - delta * 1.6, (0.22 if sim.thrusting else 0.03) * (1.0 - 0.6 * sim.alt / FlightSim.ORBIT_ALT) + 0.25 * maxf(0.0, sim.heat - 0.75))
	var climb := clampf(sim.alt / 260.0, 0.0, 1.0)
	var off := PAD_CAM.lerp(Vector3(-7.0, 1.0, 14.0), climb)
	cam.global_position = ship.global_position + off
	cam.look_at(ship.global_position + Vector3(0, lerpf(3.6, 2.2, climb), 0))
	cam.fov = lerpf(cam.fov, 62.0 + clampf(sim.vel, 0.0, 60.0) * 0.22, minf(1.0, 3.0 * delta))
	_jolt()


func _jolt() -> void:
	var k := _shake * _shake
	cam.h_offset = randf_range(-1.0, 1.0) * 0.35 * k
	cam.v_offset = randf_range(-1.0, 1.0) * 0.35 * k


func _update_effects(delta: float) -> void:
	if ship == null or not flying():
		_roar.stop()
		return
	var lit := _power > 0.03
	for f in _flames:
		if not is_instance_valid(f):
			continue
		f.visible = lit
		var length := (1.2 + 2.8 * _power) * randf_range(0.9, 1.1)
		f.scale = Vector3(0.7 + 0.45 * _power, length, 0.7 + 0.45 * _power)
	if _flame_light != null:
		_flame_light.light_energy = 4.0 * _power * randf_range(0.85, 1.15)
	if _smoke != null:
		_smoke.emitting = lit and state != State.LANDING and sim != null and sim.alt < 620.0
	if _streaks != null:
		_streaks.emitting = state == State.ASCENT and sim.vel > 20.0 and sim.alt > 120.0
	if lit:
		if not _roar.playing:
			_roar.play()
		_roar.volume_db = linear_to_db(clampf(_power, 0.05, 1.0) * 0.8)
		_roar.pitch_scale = 0.75 + 0.5 * _power
	else:
		_roar.stop()
	_shake = maxf(0.0, _shake - delta * 0.4)


func _drop_boosters() -> void:
	Sfx.play_on(player, "clang", 0.6)
	_shake = 0.8
	for i in _boosters.size():
		var b: Node3D = _boosters[i]
		var s := -1.0 if i == 0 else 1.0
		for c in b.get_children():
			if _flames.has(c):
				_flames.erase(c)
				c.queue_free()
		var at := b.global_position
		b.get_parent().remove_child(b)
		add_child(b)
		b.global_position = at
		FX.burst(self, at + Vector3(-s * 0.5, 1.6, 0), Color(1.0, 0.85, 0.4), 24, 0.13, 6.0, -5.0, "sphere", 180.0, true)
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "global_position", at + Vector3(s * 7.0, -22.0, 1.5), 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(b, "rotation", Vector3(1.3, 0.4 * s, -2.8 * s), 2.2)
		tw.chain().tween_callback(b.queue_free)
	_boosters = []


# ------------------------------------------------------------------ orbit, landing

func _fade(to: float, secs: float) -> Signal:
	var tw := create_tween()
	tw.tween_property(ui, "fade", to, secs)
	return tw.finished


func _wait(secs: float) -> Signal:
	return get_tree().create_timer(secs).timeout


func _to_orbit() -> void:
	state = State.TRANSIT
	_shout("ORBIT!", 5.0)
	ui.hint = ""
	Sfx.play_on(player, "fanfare")
	await _wait(1.4)
	await _fade(1.0, 0.7)
	ui.big = ""
	ui.sim = null
	ui.card_title = "Next stop: cheese"
	ui.card_text = "Three quiet days later (the goat sends its regards)...\nLAND SOFTLY: SPACE fires the retros, A / D slide to the yellow ring."
	await _wait(4.2)
	ui.card_title = ""
	start_landing()
	await _fade(0.0, 0.7)


## Begin the lunar descent (also used directly by the screenshot tool).
func start_landing() -> void:
	_make_ship(false)
	moon.visible = true
	lander.visible = false
	sim = FlightSim.new(FlightSim.Mode.LANDING, StarshipDesign.stats(game.ship_design), game.day * 17 + game.moon_landings)
	ui.sim = sim
	ui.visible = true
	state = State.LANDING
	_power = 0.0
	_place_descent()
	cam.fov = 60
	cam.current = true
	ui.hint = "SPACE: retro rockets    A / D: slide to the ring"


func _place_descent() -> void:
	var gy := Moon.height_local(sim.side * 0.5, 0.0) if absf(sim.side) > 8.0 else 0.0
	ship.global_position = Moon.ORIGIN + Vector3(sim.side * 0.8, maxf(sim.alt * LAND_RISE, 0.0) + gy * clampf(sim.alt / 20.0, 0.0, 1.0), 0)
	(ship.get_node("Tilt") as Node3D).rotation.z = -sim.tilt
	var low := clampf(1.0 - sim.alt / FlightSim.LAND_START_ALT, 0.0, 1.0)
	var focus := ship.global_position.lerp(Moon.ORIGIN + Vector3(0, 2.0, 0), 0.35)
	cam.global_position = focus + Vector3(3.0, lerpf(9.0, 4.0, low), lerpf(24.0, 17.0, low))
	cam.look_at(focus + Vector3(0, lerpf(0.0, 1.5, low), 0))


func _descend(delta: float) -> void:
	var c := _controls()
	sim.step(delta, c[0], c[1])
	_power = lerpf(_power, 0.75 if sim.thrusting else 0.0, minf(1.0, 14.0 * delta))
	_place_descent()
	if sim.time > 6.0:
		ui.hint = "Out of fuel - brace!" if sim.fuel <= 0.0 else ""
	if sim.thrusting and sim.alt < 28.0:
		_smoke_acc += delta
		if _smoke_acc > 0.07:
			_smoke_acc = 0.0
			var a := randf() * TAU
			var at := ship.global_position
			FX.burst(self, Vector3(at.x + cos(a) * 1.8, Moon.ORIGIN.y + 0.25, at.z + sin(a) * 1.8), Color(0.68, 0.68, 0.72), 9, 0.28, 6.0, -1.2, "sphere", 85.0)
	_shake = maxf(_shake - delta * 2.0, 0.12 if sim.thrusting else 0.0)
	for e in sim.events:
		match e:
			"bounce":
				_shout("BOING!")
				_shake = 0.9
				Sfx.play_on(player, "boing", 0.6)
				FX.burst(self, ship.global_position + Vector3(0, 0.2, 0), Color(0.7, 0.7, 0.74), 40, 0.3, 6.0, -2.0, "sphere", 88.0)
			"touchdown":
				_touchdown()
	sim.events.clear()
	_jolt()


func _touchdown() -> void:
	state = State.ARRIVING
	_power = 0.0
	_shake = 0.7
	Sfx.play_on(player, "thud", 0.6)
	FX.burst(self, ship.global_position + Vector3(0, 0.2, 0), Color(0.7, 0.7, 0.74), 60, 0.35, 7.0, -1.8, "sphere", 88.0)
	var words := {"perfect": "PERFECT LANDING!", "good": "Nice and tidy.", "bumpy": "Any landing you can walk away from..."}
	_shout(words[sim.grade], 3.0)
	ui.hint = ""
	var grade := sim.grade
	# Ease the ship onto the ring before everyone climbs out.
	var tw := ship.create_tween()
	tw.tween_property(ship, "global_position", Moon.ORIGIN, 0.9).set_trans(Tween.TRANS_SINE)
	await _wait(2.0)
	await _fade(1.0, 0.5)
	arrive_on_moon(grade)
	await _fade(0.0, 0.7)


## Step out onto the Moon.
func arrive_on_moon(grade: String = "good") -> void:
	_clear_ship()
	_roar.stop()
	moon.visible = true
	lander.visible = true
	_dress_lander()
	state = State.MOON
	game.clock_running = _clock_was   # days pass up there too, so cheese regrows
	ui.sim = null
	ui.big = ""
	ui.hint = ""
	ui.visible = false
	var first := game.moon_landings == 0
	game.moon_landings += 1
	moon.flag.set_planted(game.moon_flag)
	moon.flag.set_paint(StarshipDesign.paint_color(game.ship_design))
	player.global_position = Moon.ground(2.2, 5.2) + Vector3(0, 0.2, 0)
	player.set_space(true)
	player.set_view(0.0, -0.18, 7.5)
	_restore_player()
	if game.current_tool == GameState.Tool.BUILD:
		game.set_tool(GameState.Tool.PICKAXE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.say("The Moon! Gravity is optional-ish. Jump!")
	if grade == "perfect":
		_welcome_gift()
	if first:
		var e := StarshipDesign.ending(game.reputation)
		game.ending = e["id"]
		_show_card("THE END... ish:  " + e["title"], e["text"] + "\nThe Moon is yours to explore. Gran's story is complete.", 9.0)
	game.save_game()


func _welcome_gift() -> void:
	for i in 2:
		var c := WoodLog.new()
		c.game = game
		c.item_id = "moon_cheese"
		c.chunk_color = MineRock.CHEESE_COLOR
		moon.add_child(c)
		c.global_position = player.global_position + Vector3(-0.8 + 1.6 * i, 3.0, -3.5)
		c.gravity_scale = 0.35
	game.say("A perfect landing shook loose some welcome cheese.")


func _show_card(title: String, text: String, secs: float) -> void:
	ui.visible = true
	ui.card_title = title
	ui.card_text = text
	await _wait(secs)
	if state == State.MOON or state == State.IDLE:
		ui.card_title = ""
		ui.visible = false


# ------------------------------------------------------------------ home again

func _abort() -> void:
	ui.sim = null
	_shout("Out of puff!", 3.0)
	ui.hint = "Parachute out. Free refill at the pad - have another go."
	_come_down("Splashdown-ish! No harm done. The launch console is ready when you are.")


func fly_home() -> void:
	if state != State.MOON:
		return
	_freeze_player(true)
	player.set_model_shown(false)
	_show_hud(false)
	state = State.HOMEWARD
	_clock_was = game.clock_running
	game.clock_running = false
	ui.visible = true
	ui.card_title = ""
	ui.sim = null
	await _fade(1.0, 0.7)
	player.set_space(false)
	moon.visible = false
	_make_ship(false)
	_come_down("Home! Moon Cheese sells at the bin. The farm missed you.")


## Drift down to the pad under a striped parachute, then hand control back.
func _come_down(line: String) -> void:
	state = State.HOMEWARD
	var base := rocket.global_position
	if ui.fade < 0.5:
		await _wait(1.2)
		await _fade(1.0, 0.6)
		_make_ship(false)
	player.set_space(false)
	moon.visible = false
	rocket.visible = false
	_power = 0.0
	ship.global_position = base + Vector3(0, 30.0, 0)
	_chute = _parachute()
	ship.add_child(_chute)
	cam.global_position = base + PAD_CAM + Vector3(0, 2.0, 0)
	cam.look_at(base + Vector3(0, 9.0, 0))
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	cam.current = true
	var tw := ship.create_tween()
	tw.tween_property(ship, "global_position", base, 4.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(a: float):
		(ship.get_node("Tilt") as Node3D).rotation.z = sin(a * 9.0) * 0.16 * (1.0 - a)
		cam.look_at(base.lerp(ship.global_position, 0.7) + Vector3(0, 3.5, 0)), 0.0, 1.0, 4.6)
	await _fade(0.0, 0.6)
	await tw.finished
	Sfx.play_on(player, "thud", 0.7)
	FX.burst(self, base + Vector3(0, 0.3, 0), Color(0.8, 0.72, 0.58), 50, 0.45, 5.0, -3.0, "sphere", 85.0)
	await _wait(0.8)
	_finish_home(line)


func _finish_home(line: String) -> void:
	_clear_ship()
	_roar.stop()
	rocket.visible = true
	ui.visible = false
	ui.big = ""
	ui.hint = ""
	ui.sim = null
	ui.fade = 0.0
	state = State.IDLE
	game.clock_running = _clock_was
	player.global_position = rocket.global_position + Vector3(-2.5, 0.3, 4.5)
	player.set_view(0.4, -0.3, 7.5)
	_restore_player()
	game.say(line)


## The striped canopy and its strings.
func _parachute() -> Node3D:
	var root := Node3D.new()
	var paint := StarshipDesign.paint_color(game.ship_design)
	for k in 10:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := 5
		for j in rings:
			var pts: Array[Vector3] = []
			for q in [[j, 0], [j + 1, 0], [j, 1], [j + 1, 1]]:
				var el := PI * 0.5 * float(q[0]) / rings
				var az := TAU * float(k + q[1]) / 10.0
				pts.append(Vector3(sin(az) * cos(el) * 3.4, sin(el) * 1.9, cos(az) * cos(el) * 3.4))
			for idx in [0, 1, 2, 2, 1, 3]:
				st.set_normal(Vector3(pts[idx].x, pts[idx].y * 3.0, pts[idx].z).normalized())
				st.add_vertex(pts[idx])
		var m := StandardMaterial3D.new()
		m.albedo_color = paint if k % 2 == 0 else Color(0.97, 0.95, 0.88)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		root.add_child(ShipModel._mesh_node(st.commit(), m, Vector3(0, 10.5, 0)))
		var rim := Vector3(sin(TAU * k / 10.0) * 3.4, 10.5, cos(TAU * k / 10.0) * 3.4)
		var from := Vector3(0, 6.4, 0)
		var cord := Art.cylinder(0.025, 0.025, from.distance_to(rim), Color(0.35, 0.3, 0.25), 4)
		cord.position = (from + rim) * 0.5
		cord.quaternion = Quaternion(Vector3.UP, (rim - from).normalized())
		root.add_child(cord)
	return root


# ------------------------------------------------------------------ sky and light

## 0 on the ground .. 1 in space; drives the sky shader.
static func space_amount(altitude: float) -> float:
	return smoothstep(300.0, 880.0, altitude)


## Called by the main scene after the day/night update so the sky and lights follow the flight.
func apply_environment(env: Environment, sun: DirectionalLight3D, sky: ShaderMaterial) -> void:
	var space := 0.0
	var below := Color(0.22, 0.32, 0.22)
	if state == State.MOON or state == State.LANDING or state == State.ARRIVING:
		space = 1.0
		Moon.apply_light(env, sun)
		sky.set_shader_parameter("day", 0.0)
		sky.set_shader_parameter("sunset", 0.0)
		sky.set_shader_parameter("night", 1.0)
		sky.set_shader_parameter("overcast", 0.0)
		sky.set_shader_parameter("ground", Color(0.01, 0.01, 0.02))
		sky.set_shader_parameter("sun_dir", Vector3(0.62, 0.55, 0.56))
	else:
		if (state == State.ASCENT or state == State.TRANSIT) and sim != null:
			# Far below, the valley fades into the blue haze of home.
			below = below.lerp(Color(0.16, 0.36, 0.62), smoothstep(80.0, 420.0, sim.alt)).lerp(Color(0.03, 0.09, 0.22), space_amount(sim.alt))
			space = space_amount(sim.alt)
			env.fog_density *= 1.0 - clampf(sim.alt / 200.0, 0.0, 0.9)
			env.ambient_light_energy *= 1.0 - 0.35 * space
		sky.set_shader_parameter("ground", below)
	sky.set_shader_parameter("space", space)
