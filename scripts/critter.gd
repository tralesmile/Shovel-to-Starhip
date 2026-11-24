class_name Critter
extends Interactable
## Wandering animals and flying things built from simple cartoon shapes.
## Chickens and the goat can be petted. Butterflies and birds only come out by day.

enum Kind { CHICKEN, GOAT, BUTTERFLY, BIRD, RABBIT }

@export var kind: int = Kind.CHICKEN
var home: Vector3
var roam: float = 3.0

var _body: Node3D
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _target: Vector3
var _wait: float = 0.0
var _t: float = 0.0
var _speed: float = 1.0
var _phase: float = 0.0

const RABBIT_FLEE := 5.5       ## player closer than this and the rabbit bolts
const RABBIT_ALERT := 9.0      ## ears up (and a freeze) inside this
const RABBIT_RESPAWN := 70.0   ## seconds until a bonked rabbit hops back in
var _alert_t := 0.0
var _flee_dir := Vector3.ZERO
var _hop := 0.0
var _gone := 0.0
var _ears: Array[Node3D] = []

const BONK_LINES := ["BONK! The rabbit files a complaint and drops its lunch.", "Boing! Rabbit has left the chat (and some supplies).",
	"The rabbit says 'rude' and vanishes in a puff."]

## Pure (tested): rabbit mood from distance. Crouching halves the scare range, sprinting widens it.
static func rabbit_mode(dist: float, crouched: bool, sprinting: bool) -> String:
	var k := 1.0
	if crouched:
		k = 0.5
	elif sprinting:
		k = 1.45
	if dist < RABBIT_FLEE * k:
		return "flee"
	if dist < RABBIT_ALERT * k:
		return "alert"
	return "calm"


## Pure (tested): what a bonked rabbit drops. Always meat, a pelt about half the time, a lucky carrot rarely.
static func rabbit_drops(roll: float) -> Array:
	var d: Array = [{"item": "rabbit_meat", "amount": 1}]
	if roll < 0.5:
		d.append({"item": "rabbit_pelt", "amount": 1})
	if roll > 0.9:
		d.append({"item": "carrot", "amount": 1})
	return d


## Pure (tested): hop arc height for a phase 0..1 (a quick parabola).
static func hop_height(phase: float) -> float:
	var f := clampf(phase, 0.0, 1.0)
	return 4.0 * f * (1.0 - f) * 0.35


## Taming (Stardew-style affection): feed a veggie 3 times and the animal becomes a follower.
const TAME_FEEDS := 3
const FOLLOW_KEEP := 2.2      ## pets stop this far from you
const FOLLOW_RUN := 7.0       ## farther than this and they trot at double speed
const FOLLOW_WARP := 30.0     ## lost pets pop back next to you
const EGG_EVERY := 80.0       ## seconds between eggs from a tamed chicken
var affection := 0
var tamed := false
var _egg_t := 0.0
var _heart_t := 0.0


## Pure (tested): what a critter eats to befriend it ("" when it cannot be tamed or you hold none).
static func tame_food(kind: int, inv: Dictionary) -> String:
	if kind != Kind.CHICKEN and kind != Kind.GOAT:
		return ""
	for f in ["carrot", "turnip", "tomato"]:
		if int(inv.get(f, 0)) > 0:
			return f
	return ""


## Pure (tested): affection after a feed, and whether that made it tame.
static func feed_result(aff: int) -> Dictionary:
	var a := aff + 1
	return {"affection": a, "tamed": a >= TAME_FEEDS}


## Pure (tested): [direction-length-wanted-speed-multiplier]. 0 inside the keep radius, 1 trot, 2 run, -1 warp.
static func follow_mode(dist: float) -> int:
	if dist > FOLLOW_WARP:
		return -1
	if dist > FOLLOW_RUN:
		return 2
	if dist > FOLLOW_KEEP:
		return 1
	return 0


## Riding (Stardew horse x Palworld mounts, goat edition): tamed goat + saddle. Shift gallops and drains stamina.
const MOUNT_WALK := 6.5
const MOUNT_GALLOP := 13.0
const MOUNT_JUMP := 7.2
const MOUNT_SCALE := 1.5       ## the goat swells with pride (and so the farmer fits)
const MOUNT_SEAT_Y := 1.0      ## seat height of the rider model above the ground at MOUNT_SCALE
var ridden := false
var _saddle: Node3D
var _stride := 0.0


## Pure (tested): can this critter be ridden with these pockets?
static func can_mount(k: int, is_tamed: bool, inv: Dictionary) -> bool:
	return k == Kind.GOAT and is_tamed and int(inv.get("saddle", 0)) > 0


## Pure (tested): ride speed. Galloping needs stamina (sprinting from FX.stamina_step); load slows the goat too.
static func mount_speed(gallop: bool, load_mult: float) -> float:
	return (MOUNT_GALLOP if gallop else MOUNT_WALK) * clampf(load_mult, 0.55, 1.0)


## Pure (tested): seconds between hoof-beat puffs; faster at a gallop, 0 when standing still.
static func hoof_interval(speed: float) -> float:
	if speed < 1.0:
		return 0.0
	return clampf(2.4 / speed, 0.16, 0.5)


## Pure (tested): leg swing amplitude by speed (stiff when idle, wide at a gallop).
static func gait_swing(speed: float) -> float:
	return clampf(speed / MOUNT_GALLOP, 0.0, 1.0) * 0.9


func set_ridden(on: bool) -> void:
	ridden = on
	_stride = 0.0
	if on:
		if _saddle == null:
			_saddle = Node3D.new()
			_body.add_child(_saddle)
			_part(Art.box(Vector3(0.5, 0.06, 0.4), Color(0.55, 0.12, 0.12)), Vector3(0, 0.96, -0.05), _saddle)    # blanket
			_part(Art.box(Vector3(0.3, 0.08, 0.26), Color(0.42, 0.24, 0.12)), Vector3(0, 1.02, -0.05), _saddle)   # seat
			_part(Art.box(Vector3(0.3, 0.12, 0.05), Color(0.42, 0.24, 0.12)), Vector3(0, 1.08, -0.2), _saddle)   # back
		_saddle.visible = true
		scale = Vector3.ONE * MOUNT_SCALE
	else:
		if _saddle != null:
			_saddle.visible = false
		scale = Vector3.ONE
		_body.position.y = 0.0
		for leg in _legs:
			leg.rotation.x = 0.0


## Called every physics frame by the rider: gallop animation from the real speed.
func ride_tick(delta: float, speed: float, on_floor: bool) -> void:
	_t += delta
	var amp := gait_swing(speed) if on_floor else 0.5
	var rate := 6.0 + speed * 0.9
	_stride += delta * rate
	for i in _legs.size():
		var front := 1.0 if i < 2 else -1.0
		# Gallop: front pair and back pair swing together, opposite to each other.
		_legs[i].rotation.x = sin(_stride + (0.0 if i < 2 else PI * 0.6)) * amp * (1.0 if i % 2 == 0 else 0.85) * front
	_body.position.y = absf(sin(_stride)) * 0.05 * clampf(speed / MOUNT_WALK, 0.0, 1.6) if on_floor else 0.0
	_body.rotation.x = lerpf(_body.rotation.x, -0.12 * clampf(speed / MOUNT_GALLOP, 0.0, 1.0), 8.0 * delta)


const PET_LINES := {
	Kind.CHICKEN: ["The chicken accepts your offering of pats.", "Bawk. (That means thanks.)", "The chicken judges your farming. Gently."],
	Kind.GOAT: ["The goat is the 13th citizen. It knows.", "The goat eats your sleeve. Bonding!", "Mehhh. (The goat approves.)"],
}


func _ready() -> void:
	home = position
	_target = position
	_phase = randf() * TAU
	_body = Node3D.new()
	add_child(_body)
	if kind == Kind.CHICKEN or kind == Kind.GOAT or kind == Kind.RABBIT:
		add_child(blob_shadow(0.55 if kind == Kind.GOAT else 0.32 if kind == Kind.CHICKEN else 0.26))
	if kind == Kind.CHICKEN or kind == Kind.GOAT:
		add_to_group("saveable")
	match kind:
		Kind.CHICKEN:
			_build_chicken()
			_speed = 1.2
			interact_radius = 1.2
		Kind.GOAT:
			_build_goat()
			_speed = 1.0
			interact_radius = 1.7
		Kind.BUTTERFLY:
			_build_butterfly()
			_speed = 1.5
			remove_from_group("interactable")
		Kind.BIRD:
			_build_bird()
			_speed = 9.0
			remove_from_group("interactable")
		Kind.RABBIT:
			_build_rabbit()
			_speed = 2.0
			remove_from_group("interactable")
			add_to_group("huntable")


func get_prompt(game: GameState) -> String:
	var nm := "chicken" if kind == Kind.CHICKEN else "goat"
	if kind != Kind.CHICKEN and kind != Kind.GOAT:
		return ""
	if tamed and can_mount(kind, tamed, game.inventory):
		return "[E] Saddle up and ride the goat"
	if tamed:
		return "[E] Pet your %s (best friend)" % nm
	var food := tame_food(kind, game.inventory)
	if food != "":
		return "[E] Feed %s to the %s (%d/%d hearts)" % [GameState.ITEMS[food]["name"], nm, affection, TAME_FEEDS]
	return "[E] Pet the %s" % nm


func interact(game: GameState) -> void:
	if can_mount(kind, tamed, game.inventory):
		var pl := get_tree().get_first_node_in_group("player")
		if pl != null and pl.has_method("mount_critter") and pl.mount_critter(self):
			return
	var food := "" if tamed else tame_food(kind, game.inventory)
	if food != "":
		game.remove_item(food, 1)
		var r := feed_result(affection)
		affection = int(r["affection"])
		FX.burst(self, global_position + Vector3(0, 1.0, 0), Color(1, 0.3, 0.45), 8, 0.16, 1.8, -1.0, "sphere", 40.0)
		Sfx.play_on(self, "happy")
		_wait = 1.2
		if bool(r["tamed"]):
			tamed = true
			FX.burst(self, global_position + Vector3(0, 1.2, 0), Color(1, 0.85, 0.3), 16, 0.12, 3.5, -3.0, "sphere", 120.0)
			game.say("%s is now your friend and will follow you around!" % ("The chicken" if kind == Kind.CHICKEN else "The goat"))
		else:
			game.say("Nom! The %s likes you a little more." % ("chicken" if kind == Kind.CHICKEN else "goat"))
		return
	var lines: Array = PET_LINES.get(kind, [])
	if lines.size() > 0:
		game.say(lines[randi() % lines.size()])
		FX.burst(self, global_position + Vector3(0, 1.0, 0), Color(1, 0.45, 0.6), 6, 0.14, 1.5, -1.0, "sphere")
		_wait = 1.5


# ---------------------------------------------------------------- shapes

func _part(mesh: MeshInstance3D, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	mesh.position = pos
	(parent if parent else _body).add_child(mesh)
	return mesh


func _build_chicken() -> void:
	_part(Art.sphere(0.22, Color(0.98, 0.97, 0.92)), Vector3(0, 0.32, 0)).scale = Vector3(1, 0.9, 1.25)
	_part(Art.sphere(0.13, Color(0.98, 0.97, 0.92)), Vector3(0, 0.55, 0.18))
	_part(Art.box(Vector3(0.05, 0.09, 0.12), Color(0.9, 0.15, 0.15)), Vector3(0, 0.7, 0.18))
	_part(Art.box(Vector3(0.07, 0.05, 0.1), Color(1.0, 0.65, 0.15)), Vector3(0, 0.54, 0.32))
	_part(Art.box(Vector3(0.12, 0.14, 0.06), Color(0.95, 0.94, 0.88)), Vector3(0, 0.42, -0.26)).rotation.x = -0.5
	for x in [-0.07, 0.07]:
		var leg := Node3D.new()
		leg.position = Vector3(x, 0.2, 0)
		_body.add_child(leg)
		_part(Art.box(Vector3(0.03, 0.2, 0.03), Color(1.0, 0.65, 0.15)), Vector3(0, -0.1, 0), leg)
		_legs.append(leg)


func _build_goat() -> void:
	var white := Color(0.93, 0.9, 0.84)
	_part(Art.box(Vector3(0.45, 0.42, 0.85), white), Vector3(0, 0.72, 0))
	var head := Node3D.new()
	head.position = Vector3(0, 1.0, 0.48)
	_body.add_child(head)
	_part(Art.box(Vector3(0.26, 0.3, 0.36), white), Vector3(0, 0, 0.08), head)
	_part(Art.box(Vector3(0.05, 0.16, 0.05), Color(0.45, 0.4, 0.35)), Vector3(-0.08, 0.2, -0.02), head).rotation.x = -0.5
	_part(Art.box(Vector3(0.05, 0.16, 0.05), Color(0.45, 0.4, 0.35)), Vector3(0.08, 0.2, -0.02), head).rotation.x = -0.5
	_part(Art.box(Vector3(0.08, 0.14, 0.06), white.darkened(0.1)), Vector3(0, -0.2, 0.2), head)  # beard
	_part(Art.sphere(0.03, Color(0.1, 0.1, 0.1)), Vector3(-0.1, 0.06, 0.26), head)
	_part(Art.sphere(0.03, Color(0.1, 0.1, 0.1)), Vector3(0.1, 0.06, 0.26), head)
	for p in [Vector2(-0.15, 0.3), Vector2(0.15, 0.3), Vector2(-0.15, -0.3), Vector2(0.15, -0.3)]:
		var leg := Node3D.new()
		leg.position = Vector3(p.x, 0.52, p.y)
		_body.add_child(leg)
		_part(Art.box(Vector3(0.09, 0.52, 0.09), white.darkened(0.15)), Vector3(0, -0.26, 0), leg)
		_legs.append(leg)


static var _blob_tex: GradientTexture2D

## Soft round contact shadow that stays on the ground while the animal hops, so jumps read clearly.
static func blob_shadow(radius: float) -> MeshInstance3D:
	if _blob_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.55))
		g.set_color(1, Color(0, 0, 0, 0.0))
		_blob_tex = GradientTexture2D.new()
		_blob_tex.gradient = g
		_blob_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_tex.fill_from = Vector2(0.5, 0.5)
		_blob_tex.fill_to = Vector2(1.0, 0.5)
		_blob_tex.width = 64
		_blob_tex.height = 64
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _blob_tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material_override = m
	q.position.y = 0.03
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return q


func _build_rabbit() -> void:
	var fur := Color(0.78, 0.7, 0.6)
	_part(Art.sphere(0.2, fur), Vector3(0, 0.22, 0)).scale = Vector3(0.9, 0.85, 1.3)
	_part(Art.sphere(0.12, fur), Vector3(0, 0.34, 0.2))
	_part(Art.sphere(0.07, Color(1, 1, 1)), Vector3(0, 0.22, -0.27))  # cotton tail
	_part(Art.sphere(0.02, Color(0.1, 0.1, 0.1)), Vector3(-0.06, 0.38, 0.3))
	_part(Art.sphere(0.02, Color(0.1, 0.1, 0.1)), Vector3(0.06, 0.38, 0.3))
	_part(Art.sphere(0.03, Color(1.0, 0.6, 0.65)), Vector3(0, 0.33, 0.32))
	for x in [-0.05, 0.05]:
		var ear := Node3D.new()
		ear.position = Vector3(x, 0.44, 0.18)
		_body.add_child(ear)
		_part(Art.box(Vector3(0.04, 0.22, 0.03), fur.lightened(0.1)), Vector3(0, 0.11, 0), ear)
		_ears.append(ear)


func _build_butterfly() -> void:
	var c: Color = [Color(1.0, 0.55, 0.15), Color(0.95, 0.9, 0.25), Color(0.55, 0.75, 1.0), Color(1.0, 0.5, 0.8)][randi() % 4]
	_part(Art.box(Vector3(0.03, 0.03, 0.14), Color(0.15, 0.12, 0.1)), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		_body.add_child(hinge)
		var w := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.01, 0.14)
		w.mesh = bm
		w.material_override = Toon.color(c, false, false)
		w.position = Vector3(0.08 * side, 0, 0)
		hinge.add_child(w)
		hinge.set_meta("side", side)
		_wings.append(hinge)
	_body.scale = Vector3.ONE * 1.3


func _build_bird() -> void:
	_part(Art.box(Vector3(0.12, 0.1, 0.4), Color(0.25, 0.25, 0.3)), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		_body.add_child(hinge)
		var w := Art.box(Vector3(0.5, 0.03, 0.18), Color(0.3, 0.3, 0.36))
		w.position = Vector3(0.25 * side, 0, 0)
		hinge.add_child(w)
		hinge.set_meta("side", side)
		_wings.append(hinge)
	_body.scale = Vector3.ONE * 1.6


# ---------------------------------------------------------------- behaviour

func _process(delta: float) -> void:
	if ridden:
		return   # the rider drives (ride_tick)
	_t += delta
	match kind:
		Kind.CHICKEN, Kind.GOAT:
			_walk(delta)
		Kind.BUTTERFLY:
			_flutter(delta)
		Kind.BIRD:
			_circle(delta)
		Kind.RABBIT:
			_rabbit(delta)


func to_dict() -> Dictionary:
	return {"affection": affection, "tamed": tamed}


func from_dict(d: Dictionary) -> void:
	affection = int(d.get("affection", 0))
	tamed = bool(d.get("tamed", false))


func _follow(delta: float, pl: Node3D) -> void:
	var to := pl.global_position - global_position
	to.y = 0
	var mode := follow_mode(to.length())
	if mode == -1:
		position = pl.global_position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		FX.burst(self, global_position + Vector3(0, 0.4, 0), Color(1, 1, 1), 8, 0.12, 2.0, -1.0, "sphere", 180.0)
		return
	if mode == 0:
		for leg in _legs:
			leg.rotation.x = lerp(leg.rotation.x, 0.0, 8.0 * delta)
		_heart_t += delta
		if _heart_t > 6.0:
			_heart_t = 0.0
			FX.burst(self, global_position + Vector3(0, 1.1, 0), Color(1, 0.4, 0.55), 2, 0.12, 0.8, 0.2, "sphere", 20.0)
		return
	var spd := _speed * (2.6 if mode == 2 else 1.5)
	position += to.normalized() * spd * delta
	position.y = Terrain.height_at(position.x, position.z)
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 8.0 * delta)
	var swing := sin(_t * spd * 9.0) * 0.6
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 2 == 0 else -1.0) * (1.0 if i < 2 else -1.0)
	_body.position.y = absf(sin(_t * spd * 9.0)) * 0.05
	home = position


func _lay_egg() -> void:
	var host := get_parent()
	if host == null:
		return
	var p := WoodLog.new()
	p.game = get_node("/root/Game")
	p.item_id = "egg"
	p.amount = 1
	p.chunk_color = WoodLog.drop_color("egg")
	host.add_child(p)
	p.global_position = global_position + Vector3(0, 0.3, 0)
	p.pop()
	Sfx.play_on(self, "blip", 1.4)
	p.game.say("Your chicken laid an egg. Good bird.")


func _walk(delta: float) -> void:
	if tamed:
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl != null and pl.visible:
			if kind == Kind.CHICKEN:
				_egg_t += delta
				if _egg_t >= EGG_EVERY:
					_egg_t = 0.0
					_lay_egg()
			_follow(delta, pl)
			return
	if _wait > 0.0:
		_wait -= delta
		for leg in _legs:
			leg.rotation.x = lerp(leg.rotation.x, 0.0, 8.0 * delta)
		# Chickens peck while they wait.
		if kind == Kind.CHICKEN:
			_body.rotation.x = max(0.0, sin(_t * 9.0)) * 0.5 if int(_t) % 3 == 0 else 0.0
		return
	_body.rotation.x = 0.0
	var to := _target - position
	to.y = 0
	if to.length() < 0.2:
		_wait = randf_range(1.0, 4.0)
		var a := randf() * TAU
		var r := randf() * roam
		_target = home + Vector3(cos(a) * r, 0, sin(a) * r)
		return
	var step := to.normalized() * _speed * delta
	position += step
	position.y = Terrain.height_at(position.x, position.z)
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 6.0 * delta)
	var swing := sin(_t * _speed * 9.0) * 0.6
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 2 == 0 else -1.0) * (1.0 if i < 2 else -1.0)
	_body.position.y = abs(sin(_t * _speed * 9.0)) * 0.04


func _flutter(delta: float) -> void:
	var a := _t * 0.6 + _phase
	var target := home + Vector3(sin(a) * roam, 0.8 + sin(_t * 1.7 + _phase) * 0.35, cos(a * 1.3) * roam)
	var prev := position
	position = position.lerp(target, 1.5 * delta)
	var v := position - prev
	if v.length() > 0.0005:
		rotation.y = atan2(v.x, v.z)
	for w in _wings:
		w.rotation.z = sin(_t * 22.0) * 1.1 * float(w.get_meta("side"))


func _circle(delta: float) -> void:
	var a := _t * _speed / roam + _phase
	var prev := position
	position = home + Vector3(cos(a) * roam, sin(_t * 0.5 + _phase) * 1.5, sin(a) * roam)
	var v := position - prev
	if v.length() > 0.0001:
		rotation.y = atan2(v.x, v.z)
	rotation.z = 0.25
	var flap := 0.0
	if fmod(_t + _phase, 3.0) < 1.2:
		flap = sin(_t * 14.0) * 0.6
	for w in _wings:
		w.rotation.z = flap * float(w.get_meta("side"))


# ---------------------------------------------------------------- rabbit (huntable)

func _rabbit(delta: float) -> void:
	if _gone > 0.0:
		_gone -= delta
		if _gone <= 0.0:
			position = home + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			position.y = Terrain.height_at(position.x, position.z)
			visible = true
			scale = Vector3.ONE * 0.1
			FX.burst(self, global_position + Vector3(0, 0.3, 0), Color(1, 1, 1), 6, 0.1, 1.5, -1.0, "sphere")
		return
	scale = scale.lerp(Vector3.ONE, 6.0 * delta)
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var mode := "calm"
	if pl != null:
		var away := position - pl.global_position
		away.y = 0
		var sprinting := false
		var cr := false
		if pl.get("crouching") != null:
			cr = bool(pl.get("crouching"))
		if pl is CharacterBody3D:
			sprinting = Vector2((pl as CharacterBody3D).velocity.x, (pl as CharacterBody3D).velocity.z).length() > 6.0
		mode = rabbit_mode(away.length(), cr, sprinting)
		if mode == "flee":
			if _alert_t < 0.25 and _flee_dir == Vector3.ZERO:
				_alert_t += delta   # a startled freeze before the bolt
			else:
				_flee_dir = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
		else:
			_flee_dir = Vector3.ZERO
			_alert_t = 0.0
	# Ears: up when alert, flat when calm.
	for e in _ears:
		e.rotation.x = lerpf(e.rotation.x, -0.9 if mode == "calm" else 0.0, 8.0 * delta)
	if _flee_dir != Vector3.ZERO:
		var step := _flee_dir * 6.2 * delta
		position += step
		position.y = Terrain.height_at(position.x, position.z)
		rotation.y = lerp_angle(rotation.y, atan2(_flee_dir.x, _flee_dir.z), 12.0 * delta)
		_hop = fmod(_hop + delta * 3.2, 1.0)
		_body.position.y = hop_height(_hop)
		_body.rotation.x = -0.35 * sin(_hop * PI)
		# Don't flee into the sunset: keep within 18m of home.
		if (position - home).length() > 18.0:
			home = position
		return
	_body.rotation.x = 0.0
	if mode == "alert":
		_body.position.y = 0.0
		return
	# Calm: little nibbling hops around home.
	if _wait > 0.0:
		_wait -= delta
		_body.position.y = 0.0
		return
	var to := _target - position
	to.y = 0
	if to.length() < 0.15:
		_wait = randf_range(1.0, 3.5)
		var a := randf() * TAU
		_target = home + Vector3(cos(a), 0, sin(a)) * randf() * roam
		return
	position += to.normalized() * _speed * delta
	position.y = Terrain.height_at(position.x, position.z)
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 8.0 * delta)
	_hop = fmod(_hop + delta * 2.2, 1.0)
	_body.position.y = hop_height(_hop)


## A swing connected: loot pops out as physics pickups, the rabbit poofs away and hops back later.
func bonk(game: GameState) -> void:
	if kind != Kind.RABBIT or _gone > 0.0:
		return
	_gone = RABBIT_RESPAWN
	var host := get_parent()
	var pos := global_position
	FX.burst(host, pos + Vector3(0, 0.3, 0), Color(1, 1, 1), 14, 0.14, 3.0, -2.0, "sphere", 180.0)
	FX.burst(host, pos + Vector3(0, 0.4, 0), Color(1.0, 0.9, 0.3), 5, 0.1, 3.5, -4.0, "box")  # cartoon stars
	Sfx.play_on(self, "thud", 1.5)
	game.say(BONK_LINES[randi() % BONK_LINES.size()])
	var drops := rabbit_drops(randf())
	for i in drops.size():
		var d: Dictionary = drops[i]
		var p := WoodLog.new()
		p.game = game
		p.item_id = d["item"]
		p.amount = int(d["amount"])
		p.chunk_color = WoodLog.drop_color(p.item_id)
		host.add_child(p)
		p.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0.5 + i * 0.15, randf_range(-0.2, 0.2))
		p.pop()
	visible = false
	_flee_dir = Vector3.ZERO
	_alert_t = 0.0
