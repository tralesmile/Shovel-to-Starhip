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
var _alert_pose := false
var _flee_dir := Vector3.ZERO
var _hop := 0.0
var _gone := 0.0
var rig: AnimalRig
var _prev_pos := Vector3.ZERO
var _speed_now := 0.0

# --- Friendship, jobs, carrying (Stardew petting x Palworld work x farmyard slapstick) ---
const MAX_HEARTS := 5
const FETCH_HEARTS := 2        ## chickens this fond of you run errands
const FETCH_MIN_AGE := 3.0     ## leave fresh drops (and things you just threw away) alone
const FLAP_FALL := 1.8         ## fastest a flapping chicken sinks
const CARRY_FALL := 2.0        ## ...and with a farmer hanging underneath
const CARRY_DRIFT := 1.3       ## air speed while chicken-parachuting
const CALL_TIME := 7.0         ## seconds a whistled pet sprints to you
const CALL_WARP_DIST := 14.0
var hearts := 0
var petted_day := -1
var held := false
var thrown := false
var fly_vel := Vector3.ZERO
var _fetch: WoodLog = null
var _cargo: WoodLog = null
var _fetch_scan := 0.0
var _fetch_time := 0.0
var _happy_t := 0.0
var _startle_t := 0.0
var _called := 0.0
var _flap_t := 0.0
var _air := false
var _squawk := 0.0

const BONK_LINES := ["BONK! The rabbit files a complaint and drops its lunch.", "Boing! Rabbit has left the chat (and some supplies).",
	"The rabbit says 'rude' and vanishes in a puff."]

## Pure (tested): rabbit mood from distance. Crouching halves the scare range, sprinting widens it,
## and crouching in tall grass (cover) halves it again.
static func rabbit_mode(dist: float, crouched: bool, sprinting: bool, cover: bool = false) -> String:
	var k := 1.0
	if crouched:
		k = 0.25 if cover else 0.5
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
const GOAT_HAY := 4            ## the goat will also take hay, an armful at a time
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
	if kind == Kind.GOAT and int(inv.get("hay", 0)) >= GOAT_HAY:
		return "hay"
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


## Pure (tested): one pat a day grows friendship; later pats are just nice.
static func pet_result(h: int, last_day: int, today: int) -> Dictionary:
	if last_day == today or h >= MAX_HEARTS:
		return {"hearts": h, "day": today, "gained": false}
	return {"hearts": h + 1, "day": today, "gained": true}


## Pure (tested): what E does to a tamed animal. Today's first E is always the pat.
static func tamed_action(k: int, petted_today: bool, rideable: bool) -> String:
	if not petted_today:
		return "pet"
	if k == Kind.CHICKEN:
		return "pickup"
	return "ride" if rideable else "pet"


static func heart_text(h: int) -> String:
	return "%d/%d hearts" % [clampi(h, 0, MAX_HEARTS), MAX_HEARTS]


## Pure (tested): how far from you a chicken will go for loose loot (0 = no job yet).
static func fetch_range(h: int) -> float:
	return 0.0 if h < FETCH_HEARTS else 7.0 + 2.5 * float(mini(h, MAX_HEARTS) - FETCH_HEARTS)


## Pure (tested): fonder hens lay faster.
static func egg_interval(h: int) -> float:
	return EGG_EVERY * (1.0 - 0.1 * float(clampi(h, 1, MAX_HEARTS) - 1))


## Pure (tested): is this loose pick-up worth a chicken's trip? Not if the magnet will get it
## anyway, not fresh drops, and not logs you are saving to chop.
static func worth_fetching(age_s: float, to_player: float, reach: float, magnet: float, saving_log: bool) -> bool:
	return age_s >= FETCH_MIN_AGE and not saving_log and to_player > magnet + 0.6 and to_player <= reach


## Pure (tested): a thrown chicken flaps: forward speed bleeds off and it refuses to fall fast.
static func flutter_step(v: Vector3, delta: float) -> Vector3:
	var keep := maxf(0.0, 1.0 - 0.9 * delta)
	return Vector3(v.x * keep, maxf(v.y - 12.0 * delta, -FLAP_FALL), v.z * keep)


## Pure (tested): underhand lob along the camera heading (camera yaw, as the player uses it).
static func toss_velocity(yaw: float, run: Vector3 = Vector3.ZERO) -> Vector3:
	return Vector3(-sin(yaw) * 9.0, 5.5, -cos(yaw) * 9.0) + Vector3(run.x, 0, run.z) * 0.5


## Ground height for walking animals, including the raised road surface.
static func ground_y(x: float, z: float) -> float:
	return Terrain.height_at(x, z) + CarPhysics.road_height(x, z)


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
			rig.body.add_child(_saddle)
			_part(Art.box(Vector3(0.5, 0.06, 0.4), Color(0.55, 0.12, 0.12)), Vector3(0, 0.96, -0.05), _saddle)    # blanket
			_part(Art.box(Vector3(0.3, 0.08, 0.26), Color(0.42, 0.24, 0.12)), Vector3(0, 1.02, -0.05), _saddle)   # seat
			_part(Art.box(Vector3(0.3, 0.12, 0.05), Color(0.42, 0.24, 0.12)), Vector3(0, 1.08, -0.2), _saddle)   # back
		_saddle.visible = true
		scale = Vector3.ONE * MOUNT_SCALE
	else:
		if _saddle != null:
			_saddle.visible = false
		scale = Vector3.ONE
		rig.body.position.y = 0.0
		_body.rotation = Vector3.ZERO
		_body.position.y = 0.0
		for leg in _legs:
			leg.rotation.x = 0.0


## Called every physics frame by the rider: gallop animation from the real speed.
func ride_tick(delta: float, speed: float, on_floor: bool, ramming: bool = false, lean: float = 0.0) -> void:
	_t += delta
	_refresh_bags()
	rig.animate(delta, speed / MOUNT_SCALE, {"gallop": speed > MOUNT_WALK + 1.0, "air": not on_floor,
		"ram": ramming, "happy": speed < 0.5, "chew": speed < 0.2 and fmod(_t, 7.0) < 2.0})
	_body.rotation.x = lerpf(_body.rotation.x, -0.12 * clampf(speed / MOUNT_GALLOP, 0.0, 1.0) + (0.16 if ramming else 0.0), minf(1.0, 8.0 * delta))
	_body.rotation.z = lerpf(_body.rotation.z, lean, minf(1.0, 7.0 * delta))


const PET_LINES := {
	Kind.CHICKEN: ["The chicken accepts your offering of pats.", "Bawk. (That means thanks.)", "The chicken judges your farming. Gently."],
	Kind.GOAT: ["The goat is the 13th citizen. It knows.", "The goat eats your sleeve. Bonding!", "Mehhh. (The goat approves.)"],
}


func _ready() -> void:
	home = position
	_target = position
	_phase = randf() * TAU
	_prev_pos = position
	_body = Node3D.new()
	add_child(_body)
	if kind == Kind.CHICKEN or kind == Kind.GOAT or kind == Kind.RABBIT:
		add_child(blob_shadow(0.55 if kind == Kind.GOAT else 0.32 if kind == Kind.CHICKEN else 0.26))
	if kind == Kind.CHICKEN or kind == Kind.GOAT:
		add_to_group("saveable")
	if kind == Kind.CHICKEN or kind == Kind.GOAT or kind == Kind.RABBIT:
		add_to_group("grass_bender")
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
	if held or thrown:
		return ""
	if tamed:
		match tamed_action(kind, petted_day == game.day, can_mount(kind, tamed, game.inventory)):
			"pickup":
				return "[E] Pick up your chicken (%s) - hold Jump to float" % heart_text(hearts)
			"ride":
				return "[E] Saddle up and ride the goat (%s)" % heart_text(hearts)
		return "[E] Pet your %s (%s)" % [nm, heart_text(hearts)]
	var food := tame_food(kind, game.inventory)
	if food != "":
		return "[E] Feed %s to the %s (%d/%d hearts)" % [GameState.ITEMS[food]["name"], nm, affection, TAME_FEEDS]
	return "[E] Pet the %s" % nm


func interact(game: GameState) -> void:
	if held or thrown:
		return
	if tamed:
		var pl := get_tree().get_first_node_in_group("player")
		match tamed_action(kind, petted_day == game.day, can_mount(kind, tamed, game.inventory)):
			"ride":
				if pl != null and pl.has_method("mount_critter") and pl.mount_critter(self):
					return
			"pickup":
				if pl != null and pl.has_method("pickup_pet") and pl.pickup_pet(self):
					return
		pet(game)
		return
	var food := tame_food(kind, game.inventory)
	if food != "":
		game.remove_item(food, GOAT_HAY if food == "hay" else 1)
		var r := feed_result(affection)
		affection = int(r["affection"])
		_hearts_burst(8)
		Sfx.play_on(self, "happy")
		_wait = 1.2
		_happy_t = 1.5
		if bool(r["tamed"]):
			befriend(game)
			FX.burst(self, global_position + Vector3(0, 1.2, 0), Color(1, 0.85, 0.3), 16, 0.12, 3.5, -3.0, "sphere", 120.0)
			game.say("%s is now your friend! Pet it every day to grow closer." % ("The chicken" if kind == Kind.CHICKEN else "The goat"))
		else:
			game.say("Nom! The %s likes you a little more." % ("chicken" if kind == Kind.CHICKEN else "goat"))
		return
	pet(game)


## Tamed: follows you, and starts with one heart.
func befriend(game: GameState) -> void:
	tamed = true
	hearts = maxi(hearts, 1)
	if kind == Kind.GOAT and game != null:
		game.goat_friend = true


## A pat: wiggle, hearts, and (once a day, for friends) a friendship point.
func pet(game: GameState) -> void:
	_happy_t = 1.8
	_wait = 1.5
	Sfx.play_on(self, "cluck" if kind == Kind.CHICKEN else "bleat", randf_range(0.9, 1.15))
	if _body != null and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(_body, "scale", Vector3(1.18, 0.76, 1.18), 0.09)
		tw.tween_property(_body, "scale", Vector3(0.9, 1.14, 0.9), 0.12)
		tw.tween_property(_body, "scale", Vector3.ONE, 0.2)
	if tamed:
		var r := pet_result(hearts, petted_day, game.day)
		hearts = int(r["hearts"])
		petted_day = int(r["day"])
		if bool(r["gained"]):
			_hearts_burst(10)
			var perk := ""
			if kind == Kind.CHICKEN and hearts == FETCH_HEARTS:
				perk = " New job: it now fetches loose loot for you!"
			elif kind == Kind.CHICKEN and hearts > FETCH_HEARTS:
				perk = " It fetches from farther and lays faster."
			elif kind == Kind.GOAT:
				perk = " Its headbutts feel more confident."
			game.say("Friendship up! %s.%s" % [heart_text(hearts), perk])
			return
	_hearts_burst(5)
	var lines: Array = PET_LINES.get(kind, [])
	if lines.size() > 0:
		game.say(lines[randi() % lines.size()])


func _hearts_burst(n: int) -> void:
	if is_inside_tree():
		FX.burst(self, global_position + Vector3(0, 1.0, 0), Color(1, 0.3, 0.45), n, 0.12, 1.8, -1.0, "sphere", 45.0)


# ---------------------------------------------------------------- carried and thrown

func can_be_carried() -> bool:
	return kind == Kind.CHICKEN and tamed and not held and not thrown


func set_held(on: bool) -> void:
	held = on
	thrown = false
	_drop_cargo()
	_body.rotation = Vector3.ZERO
	_body.scale = Vector3.ONE
	_called = 0.0
	if on:
		Sfx.play_on(self, "cluck", 1.2)


## Called by the farmer every physics frame while carried overhead.
func hold_tick(delta: float, at: Vector3, yaw: float, floating: bool) -> void:
	global_position = at
	rotation = Vector3(0, yaw, 0)
	_t += delta
	_flap_t = move_toward(_flap_t, 1.0 if floating else 0.0, delta * 7.0)
	rig.animate(delta, 0.0, {"flap": _flap_t, "air": floating, "call": floating and fmod(_t, 0.8) < 0.2, "happy": true})
	if floating:
		_squawk -= delta
		if _squawk <= 0.0:
			_squawk = 0.55
			Sfx.play_on(self, "flap", randf_range(0.9, 1.2))
			FX.burst(get_parent(), global_position + Vector3(0, 0.3, 0), Color(1, 0.98, 0.92), 3, 0.07, 1.2, -1.6, "box", 120.0)


func throw_from(at: Vector3, vel: Vector3) -> void:
	set_held(false)
	global_position = at
	rotation = Vector3(0, atan2(vel.x, vel.z), 0)
	fly_vel = vel
	thrown = true
	_squawk = 0.0
	Sfx.play_on(self, "cluck", 1.45)


## Put down gently (or startled off your head): lands where it is.
func set_down(at: Vector3) -> void:
	set_held(false)
	global_position = at
	home = position


func _fly(delta: float) -> void:
	fly_vel = flutter_step(fly_vel, delta)
	var from := global_position
	var to := from + fly_vel * delta
	var floor_y := ground_y(to.x, to.z) if to.x < 300.0 else -1000.0
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		# Bonk off walls instead of phasing through them.
		var ahead := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.3, 0), to + Vector3(0, 0.3, 0), 1)
		var pl := get_tree().get_first_node_in_group("player")
		if pl is CollisionObject3D:
			ahead.exclude = [(pl as CollisionObject3D).get_rid()]
		var wall := space.intersect_ray(ahead)
		if not wall.is_empty() and absf((wall["normal"] as Vector3).y) < 0.6:
			fly_vel.x *= -0.35
			fly_vel.z *= -0.35
			to = from
		var down := PhysicsRayQueryParameters3D.create(to + Vector3(0, 0.6, 0), to + Vector3(0, -0.15, 0), 1)
		down.exclude = ahead.exclude
		var hit := space.intersect_ray(down)
		if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.6:
			floor_y = maxf(floor_y, (hit["position"] as Vector3).y)
		_bonk_rabbits()
	global_position = to
	_squawk -= delta
	if _squawk <= 0.0:
		_squawk = 0.3
		Sfx.play_on(self, "flap", randf_range(0.95, 1.25))
		FX.burst(get_parent(), global_position + Vector3(0, 0.3, 0), Color(1, 0.98, 0.92), 3, 0.06, 1.0, -1.4, "box", 150.0)
	if (fly_vel.y <= 0.0 and global_position.y <= floor_y) or global_position.y < -20.0:
		_land(floor_y)


func _land(floor_y: float) -> void:
	thrown = false
	if global_position.y < -20.0:
		global_position = Vector3(-8, ground_y(-8, 6.5), 6.5)
	else:
		global_position.y = floor_y
	home = position
	_wait = 0.9
	_startle_t = 0.5
	Sfx.play_on(self, "cluck", 0.85)
	FX.burst(get_parent(), global_position + Vector3(0, 0.15, 0), Color(1, 0.98, 0.92), 9, 0.07, 2.2, -2.5, "box", 80.0)


## A flying chicken is a legitimate hunting method.
func _bonk_rabbits() -> void:
	for n in get_tree().get_nodes_in_group("huntable"):
		var r := n as Critter
		if r != null and r.visible and r.global_position.distance_to(global_position) < 0.75:
			var game := get_node("/root/Game") as GameState
			r.bonk(game)
			game.shake.emit(0.25)
			game.say("CHICKEN MISSILE. A completely legal hunting method.")
			FX.hit_stop(get_tree(), 0.6)
			fly_vel = Vector3(-fly_vel.x * 0.3, 3.5, -fly_vel.z * 0.3)
			return


# ---------------------------------------------------------------- whistle and fetch job

## The Goat Whistle: a tamed pet sprints over (distant ones pop in just out of the way first).
func call_to(at: Vector3, behind: Vector3) -> bool:
	if not tamed or held or thrown or ridden:
		return false
	_drop_cargo()
	_wait = 0.0
	if Vector2(at.x - global_position.x, at.z - global_position.z).length() > CALL_WARP_DIST:
		var side := Vector3(behind.z, 0, -behind.x) * randf_range(-3.0, 3.0)
		var spot := at + behind * (CALL_WARP_DIST - 3.0) + side
		spot.y = ground_y(spot.x, spot.z) if spot.x < 300.0 else at.y
		global_position = spot
		FX.burst(get_parent(), spot + Vector3(0, 0.4, 0), Color(1, 1, 1), 8, 0.14, 2.0, -1.0, "sphere", 180.0)
	_called = CALL_TIME
	_happy_t = CALL_TIME
	return true


func _drop_cargo() -> void:
	if _cargo != null and is_instance_valid(_cargo):
		_cargo.set_carried(false)
	_cargo = null
	_fetch = null


func _find_loot(pl: Node3D) -> WoodLog:
	var game := get_node_or_null("/root/Game") as GameState
	if game == null:
		return null
	var reach := fetch_range(hearts)
	var magnet := GameState.magnet_range(game.count("magnet_gloves") > 0, game.count("loot_vacuum") > 0)
	var best: WoodLog = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("pickup"):
		var it := n as WoodLog
		if it == null or it.carried or it.is_queued_for_deletion():
			continue
		var to_pl := Vector2(it.global_position.x - pl.global_position.x, it.global_position.z - pl.global_position.z).length()
		var saving := it.chunk_color.a == 0.0 and WoodLog.wants_chop(it.item_id, game.current_tool)
		if not worth_fetching(it.age, to_pl, reach, magnet, saving) or absf(it.global_position.y - global_position.y) > 1.2:
			continue
		if _claimed_by_another(it):
			continue
		var d := it.global_position.distance_to(global_position)
		if d < best_d:
			best = it
			best_d = d
	return best


func _claimed_by_another(it: WoodLog) -> bool:
	for n in get_tree().get_nodes_in_group("flock"):
		if n != self and (n as Critter)._fetch == it:
			return true
	return false


## The chicken's job. Returns true while it is busy with it.
func _fetch_tick(delta: float, pl: Node3D) -> bool:
	# No errands without the job, or while you are somewhere the hen is not (indoors).
	if fetch_range(hearts) <= 0.0 or (pl.global_position.x > 300.0) != (global_position.x > 300.0):
		_drop_cargo()
		return false
	if _cargo != null:
		if not is_instance_valid(_cargo):
			_cargo = null
			return false
		_fetch_time += delta
		var back := pl.global_position - global_position
		back.y = 0
		_cargo.global_position = global_position + Vector3(0, 0.62, 0) + Vector3(sin(rotation.y), 0, cos(rotation.y)) * 0.32
		if back.length() < 1.7 or _fetch_time > 9.0:
			var item := _cargo
			_drop_cargo()
			if _fetch_time > 9.0:
				item.global_position = pl.global_position + Vector3(0, 1.0, 0)
			_hearts_burst(2)
			Sfx.play_on(self, "cluck", 1.25)
			_fetch_scan = 0.8
			return false
		_run_toward(delta, back, _speed * 3.4)
		return true
	if _fetch != null and (not is_instance_valid(_fetch) or _fetch.carried or _fetch.is_queued_for_deletion()):
		_fetch = null
	if _fetch == null:
		_fetch_scan -= delta
		if _fetch_scan > 0.0:
			return false
		_fetch_scan = 0.6
		_fetch = _find_loot(pl)
		_fetch_time = 0.0
		if _fetch == null:
			return false
		Sfx.play_on(self, "cluck", 1.4)
	_fetch_time += delta
	var to := _fetch.global_position - global_position
	to.y = 0
	if to.length() < 0.45:
		_cargo = _fetch
		_cargo.set_carried(true)
		_fetch_time = 0.0
		return true
	if _fetch_time > 6.0:   # stuck behind something: give up for a while
		_fetch = null
		_fetch_scan = 4.0
		return false
	_run_toward(delta, to, _speed * 3.4)
	return true


func _run_toward(delta: float, to: Vector3, spd: float) -> void:
	position += to.normalized() * minf(spd * delta, to.length())
	position.y = ground_y(position.x, position.z) if position.x < 300.0 else position.y
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, 10.0 * delta))
	home = position


# ---------------------------------------------------------------- shapes

func _part(mesh: MeshInstance3D, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	mesh.position = pos
	(parent if parent else _body).add_child(mesh)
	return mesh


func _adopt(r: AnimalRig) -> void:
	rig = r
	_body.add_child(r)
	_legs = r.legs
	_wings = r.wings


func _build_chicken() -> void:
	add_to_group("flock")
	_adopt(AnimalRig.make("chicken", int(str(name).get_slice("_", 1)) if "_" in str(name) else 0))


func _build_goat() -> void:
	add_to_group("flock_goat")
	_adopt(AnimalRig.make("goat"))


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
	_adopt(AnimalRig.make("rabbit", int(str(name).get_slice("_", 1)) if "_" in str(name) else 0))


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
	if ridden or held:
		_prev_pos = position
		return   # the rider (ride_tick) or the carrier (hold_tick) drives
	_t += delta
	match kind:
		Kind.CHICKEN, Kind.GOAT:
			if thrown:
				_fly(delta)
			else:
				_walk(delta)
		Kind.BUTTERFLY:
			_flutter(delta)
		Kind.BIRD:
			_circle(delta)
		Kind.RABBIT:
			_rabbit(delta)
	if rig != null:
		_pose(delta)


## Turn what the animal is doing into rig poses, using how fast it really moved.
func _pose(delta: float) -> void:
	_happy_t = maxf(0.0, _happy_t - delta)
	_startle_t = maxf(0.0, _startle_t - delta)
	var moved := Vector2(position.x - _prev_pos.x, position.z - _prev_pos.z).length() / maxf(delta, 0.001)
	_prev_pos = position
	_speed_now = lerpf(_speed_now, minf(moved, 14.0), minf(1.0, 12.0 * delta))
	var idle := _speed_now < 0.15 and _happy_t <= 0.0 and not thrown
	var cycle := fmod(_t + _phase * 2.0, 9.0)
	var state := {"happy": _happy_t > 0.0, "flap": 0.0, "air": thrown, "gallop": _speed_now > 4.5}
	match kind:
		Kind.CHICKEN:
			state["graze"] = idle and cycle < 3.5
			state["call"] = thrown or _startle_t > 0.0 or (idle and cycle > 8.4)
			state["flap"] = 1.0 if thrown or _startle_t > 0.0 else (0.45 if _speed_now > 3.2 else 0.0)
			state["gallop"] = false
		Kind.GOAT:
			state["graze"] = idle and cycle < 4.0
			state["chew"] = idle and cycle >= 4.0 and cycle < 6.5
			state["call"] = _called > 0.0 and fmod(_t, 1.2) < 0.3
		Kind.RABBIT:
			state["graze"] = idle and cycle < 3.0
			state["alert"] = _alert_pose
			state["air"] = _body.position.y > 0.06
	rig.animate(delta, _speed_now, state)
	_refresh_bags()


## The Saddle Bags show on the goat as soon as you own them.
func _refresh_bags() -> void:
	if rig != null and rig.bags != null:
		var game := get_node_or_null("/root/Game") as GameState if is_inside_tree() else null
		rig.bags.visible = tamed and game != null and game.count("saddle_bags") > 0


func to_dict() -> Dictionary:
	return {"affection": affection, "tamed": tamed, "hearts": hearts, "petted_day": petted_day}


func from_dict(d: Dictionary) -> void:
	affection = int(d.get("affection", 0))
	tamed = bool(d.get("tamed", false))
	hearts = int(d.get("hearts", 1 if tamed else 0))
	petted_day = int(d.get("petted_day", -1))
	if tamed and kind == Kind.GOAT and is_inside_tree():
		var game := get_node_or_null("/root/Game") as GameState
		if game != null:
			game.goat_friend = true


func _follow(delta: float, pl: Node3D) -> void:
	var to := pl.global_position - global_position
	to.y = 0
	var mode := follow_mode(to.length())
	if mode == -1:
		position = pl.global_position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		FX.burst(self, global_position + Vector3(0, 0.4, 0), Color(1, 1, 1), 8, 0.12, 2.0, -1.0, "sphere", 180.0)
		return
	if _called > 0.0:
		_called -= delta
		if mode == 0:
			_called = 0.0
			_happy_t = 2.0
			_hearts_burst(3)
			Sfx.play_on(self, "cluck" if kind == Kind.CHICKEN else "bleat", 1.1)
		else:
			_run_toward(delta, to, 11.0 if kind == Kind.GOAT else 7.0)
			return
	if mode == 0:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, 3.0 * delta))
		_heart_t += delta
		if _heart_t > 6.0:
			_heart_t = 0.0
			FX.burst(self, global_position + Vector3(0, 1.1, 0), Color(1, 0.4, 0.55), 2, 0.12, 0.8, 0.2, "sphere", 20.0)
		return
	_run_toward(delta, to, _speed * (3.6 if mode == 2 else 1.7))


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
				if _egg_t >= egg_interval(hearts):
					_egg_t = 0.0
					_lay_egg()
				if _called <= 0.0 and _fetch_tick(delta, pl):
					return
			_follow(delta, pl)
			return
		_drop_cargo()   # you drove off: she puts it down
	elif kind == Kind.CHICKEN and _startled(delta):
		return
	if _wait > 0.0:
		_wait -= delta
		return
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
	position.y = ground_y(position.x, position.z)
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 6.0 * delta)


## Run at a wild hen and it explodes into feathers and scoots off.
func _startled(delta: float) -> bool:
	var pl := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if pl == null:
		return false
	var away := global_position - pl.global_position
	away.y = 0
	if _startle_t <= 0.0:
		if away.length() > 2.0 or Vector2(pl.velocity.x, pl.velocity.z).length() < 6.0:
			return false
		_startle_t = 0.9
		Sfx.play_on(self, "cluck", 1.5)
		FX.burst(get_parent(), global_position + Vector3(0, 0.35, 0), Color(1, 0.98, 0.92), 8, 0.07, 2.6, -2.5, "box", 100.0)
	_run_toward(delta, away if away.length() > 0.05 else Vector3.RIGHT, 4.2)
	_wait = 0.4
	return true


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
		mode = rabbit_mode(away.length(), cr, sprinting, bool(pl.get("in_cover")))
		if mode == "flee":
			if _alert_t < 0.25 and _flee_dir == Vector3.ZERO:
				_alert_t += delta   # a startled freeze before the bolt
			else:
				_flee_dir = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
		else:
			_flee_dir = Vector3.ZERO
			_alert_t = 0.0
	_alert_pose = mode == "alert"   # ears up
	if _flee_dir != Vector3.ZERO:
		var step := _flee_dir * 6.2 * delta
		position += step
		position.y = ground_y(position.x, position.z)
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
	position.y = ground_y(position.x, position.z)
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
