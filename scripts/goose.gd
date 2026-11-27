class_name Goose
extends Node3D
## Lady Honksworth, the crop thief. Some mornings she glides in, waddles to your best crop,
## heaves it out of the ground and legs it. Bonk her (any swing or a pebble) and she drops it as
## a pick-up. Stand your ground while she hisses and she gives up. A scarecrow keeps her off every
## plot it can see. She only calls while you are near enough to do something about it.

enum State { AWAY, ARRIVE, STALK, TUG, FLEE, FLY, BALK }

const FIRST_DAY := 3
const VISIT_CHANCE := 0.65
const EARLIEST := 0.34          ## about 8 AM
const LATEST := 0.68            ## about 4 PM
const NEAR_FARM := 38.0         ## she waits until you are this close to the field
const WADDLE := 1.25
const FLEE_SPEED := 4.2         ## slower than your sprint, so a chase can be won
const FLEE_TIME := 6.5
const TUG_TIME := 3.2
const ARRIVE_TIME := 2.8
const FLY_TIME := 2.6
const BALK_TIME := 3.4
const FACE_OFF_RANGE := 2.3
const FACE_OFF_TIME := 2.6      ## stand this close this long and she backs down
const BONK_HEIGHT := 1.6        ## higher than this she is out of a swing's reach
const HIT_RADIUS := 0.85
const PEN := 4.8                ## half-width of your fenced field; the gate is in the south side
const GATE := Vector3(0.0, 0.0, 5.9)

var state: int = State.AWAY
var loot := ""
var visited_day := -1
var game: GameState
var target: FarmPlot
var rig: AnimalRig

var _t := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _face := 0.0
var _honk_t := 0.0
var _tug_n := 0
var _speed := 0.0
var _flee_dir := Vector3.BACK
var _loot_model: Node3D
var _mark: Label3D
var _scarer: Node3D


# ---------------------------------------------------------------- pure helpers (tested)

## When (time of day) she calls on this day, or -1 for a quiet day. Same answer every time.
static func visit_time(day: int) -> float:
	if day < FIRST_DAY:
		return -1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([day, "goose"])
	rng.randi()
	if rng.randf() >= VISIT_CHANCE:
		return -1.0
	return rng.randf_range(EARLIEST, LATEST)


## Pure: which crop does she fancy? `cells` entries: {planted, ripe, growth, giant, guarded}.
## Ripe beats leafy; bare seeds, giants and anything a scarecrow watches are ignored. -1 = nothing.
static func pick_target(cells: Array, roll: int) -> int:
	var ripe: Array = []
	var leafy: Array = []
	for i in cells.size():
		var c: Dictionary = cells[i]
		if not c["planted"] or c["giant"] or c["guarded"]:
			continue
		if c["ripe"]:
			ripe.append(i)
		elif int(c["growth"]) > 0:
			leafy.append(i)
	var pool := ripe if not ripe.is_empty() else leafy
	return -1 if pool.is_empty() else int(pool[posmod(roll, pool.size())])


## Pure: is there something she would want if no scarecrow were there? (She still turns up to glare.)
static func is_scared_off(cells: Array) -> bool:
	var open: Array = cells.map(func(c): var d: Dictionary = c.duplicate(); d["guarded"] = false; return d)
	return pick_target(cells, 0) < 0 and pick_target(open, 0) >= 0


## Pure: the way she runs, carrying loot: straight away from you, with a comedy zig-zag.
static func flee_heading(goose: Vector3, player: Vector3, t: float) -> Vector3:
	var away := Vector3(goose.x - player.x, 0, goose.z - player.z)
	if away.length() < 0.1:
		away = Vector3.BACK
	return away.normalized().rotated(Vector3.UP, sin(t * 5.0) * 0.5)


## Pure: she does not walk through your fence. Penned in, she makes for the gate (so you can
## head her off there); once out, she runs from you.
static func escape_heading(goose: Vector3, player: Vector3, t: float) -> Vector3:
	if absf(goose.x) >= PEN or absf(goose.z) >= PEN:
		return flee_heading(goose, player, t)
	var gap := GATE - goose
	gap.y = 0.0
	# Line up with the opening first if she is still off to one side of it.
	if absf(goose.x) > 0.7 and goose.z > PEN - 1.4:
		gap = Vector3(-goose.x, 0.0, PEN - 1.5 - goose.z)
	return gap.normalized().rotated(Vector3.UP, sin(t * 5.0) * 0.18)


## Pure: how long you have stood your ground. It drains again if you back off.
static func face_off(meter: float, dist: float, delta: float) -> float:
	return clampf(meter + (delta if dist <= FACE_OFF_RANGE else -delta * 0.7), 0.0, FACE_OFF_TIME)


## Pure: a glide from `a` down (or up) to `b`: eases forward, height falls away on a curve.
static func glide(a: Vector3, b: Vector3, k: float) -> Vector3:
	var u := clampf(k, 0.0, 1.0)
	var flat := a.lerp(b, u)
	flat.y = lerpf(a.y, b.y, 1.0 - pow(1.0 - u, 1.45))   # still high enough to clear the fence
	return flat


# ---------------------------------------------------------------- node

func _ready() -> void:
	name = "Goose"
	add_to_group("saveable")
	add_to_group("goose")
	rig = AnimalRig.make("goose")
	add_child(rig)
	_mark = Art.label("HONK!", 40, Color(1.0, 0.86, 0.25))
	_mark.position.y = 1.45
	_mark.visible = false
	add_child(_mark)
	visible = false


func to_dict() -> Dictionary:
	return {"visited": visited_day}


func from_dict(d: Dictionary) -> void:
	visited_day = int(d.get("visited", -1))
	_leave()


## On the ground and close enough to be swatted.
func bonkable() -> bool:
	if not visible or state == State.AWAY:
		return false
	if state == State.FLY and _t > 0.5:
		return false
	return position.y - Terrain.height_at(position.x, position.z) < BONK_HEIGHT


func cells() -> Array:
	var out: Array = []
	for p in _plots():
		out.append({"planted": p.state == FarmPlot.State.PLANTED, "ripe": p.is_ripe(), "growth": p.growth,
			"giant": p.giant, "guarded": ScarecrowSpot.guards(get_tree(), p.global_position)})
	return out


func _plots() -> Array:
	return get_tree().get_nodes_in_group("farmplot")


## Start a visit now. Returns false if there is nothing at all to be nosy about.
func visit(g: GameState) -> bool:
	game = g
	var info := cells()
	var pick := pick_target(info, g.day)
	if pick >= 0:
		target = _plots()[pick]
		_begin_arrival(target.global_position)
		g.say("HONK! A goose is gliding in, eyeing your %s!" % target.crop)
		return true
	if is_scared_off(info):
		target = null
		_scarer = ScarecrowSpot.nearest(get_tree(), Vector3.ZERO)
		_begin_arrival(Vector3(0.0, 0.0, 6.6))
		return true
	return false


func _begin_arrival(goal: Vector3) -> void:
	var side := Vector3(1.0 if goal.x >= 0.0 else -1.0, 0.0, 0.9).normalized()
	# Beside her crop on the side nearer the middle, so she never has to waddle through the fence.
	var inward := Vector3(-1.0 if goal.x >= 0.0 else 1.0, 0.0, 0.35).normalized()
	_to = goal + inward * (2.2 if target != null else 0.0)
	_to.y = Terrain.height_at(_to.x, _to.z)
	_from = _to + side * 15.0 + Vector3(0, 9.0, 0)
	position = _from
	_face = atan2(-side.x, -side.z)
	rotation.y = _face
	loot = ""
	_set_loot_model("")
	visible = true
	_go(State.ARRIVE)
	_honk(1.0)


func _go(next: int) -> void:
	state = next
	_t = 0.0
	_tug_n = 0
	_face = 0.0 if next == State.AWAY else _face
	_mark.visible = next in [State.TUG, State.FLEE, State.BALK]
	_mark.text = "MINE!" if next == State.FLEE else "HONK!"


func _leave() -> void:
	loot = ""
	target = null
	if rig != null:
		_set_loot_model("")
	visible = false
	if _mark != null:
		_go(State.AWAY)


func _fly_off() -> void:
	_from = position
	var away := Vector3(sin(rotation.y), 0, cos(rotation.y))
	_to = _from + away * 17.0 + Vector3(0, 10.0, 0)
	_go(State.FLY)
	Sfx.play_on(self, "flap", 0.65)


func _honk(pitch: float) -> void:
	_honk_t = 0.35
	Sfx.play_on(self, "honk", pitch * randf_range(0.93, 1.08))


func _feathers(amount: int) -> void:
	if is_inside_tree():
		FX.burst(get_parent(), global_position + Vector3(0, 0.6, 0), Color(0.97, 0.96, 0.92), amount, 0.07, 2.6, -2.2, "box", 160.0)


## Swatted by a tool or a pebble: loot pops out onto the ground, a feather too.
func bonk(g: GameState) -> void:
	if not bonkable():
		return
	var had := loot
	loot = ""
	_set_loot_model("")
	_feathers(34)
	_honk(1.5)
	Sfx.play_on(self, "flap", 0.8)
	if is_inside_tree():
		if had != "":
			_drop(g, had)
		_drop(g, "goose_feather")
	if had != "":
		g.say("BONK! She drops your %s and a feather." % had)
	else:
		g.say("BONK! Feathers everywhere. Lady Honksworth is outraged.")
	g.shake.emit(0.2)
	_fly_off()


func _drop(g: GameState, id: String) -> void:
	var item := WoodLog.new()
	item.item_id = id
	item.game = g
	item.chunk_color = WoodLog.drop_color(id)
	get_parent().add_child(item)
	item.global_position = global_position + Vector3(0, 0.75, 0)
	item.pop()


func _set_loot_model(id: String) -> void:
	if _loot_model != null:
		_loot_model.queue_free()
		_loot_model = null
	if id == "" or rig.head == null:
		return
	_loot_model = CropModel.produce(id)
	_loot_model.scale = Vector3.ONE * 0.55
	_loot_model.position = Vector3(0, -0.1, 0.27)
	rig.head.add_child(_loot_model)


func _process(delta: float) -> void:
	var g := game if game != null else get_node_or_null("/root/Game") as GameState
	if g == null:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if state == State.AWAY:
		_check_schedule(g, pl)
		return
	tick(delta, g, pl.global_position if pl != null else Vector3(999, 0, 999))


func _check_schedule(g: GameState, pl: Node3D) -> void:
	if pl == null or visited_day == g.day or not g.clock_running:
		return
	var when := visit_time(g.day)
	if when < 0.0 or g.time_of_day < when or g.time_of_day > LATEST + 0.1:
		return
	if Vector2(pl.global_position.x, pl.global_position.z).length() > NEAR_FARM:
		return
	if visit(g):
		visited_day = g.day


## One step of her visit. `who` is where the player stands.
func tick(delta: float, g: GameState, who: Vector3) -> void:
	_t += delta
	_honk_t -= delta
	var dist := Vector2(who.x - position.x, who.z - position.z).length()
	var pose := {}
	_speed = 0.0
	match state:
		State.ARRIVE:
			position = glide(_from, _to, _t / ARRIVE_TIME)
			pose = {"flap": 0.75, "air": _t < ARRIVE_TIME * 0.85}
			if _t >= ARRIVE_TIME:
				_feathers(6)
				Sfx.play_on(self, "thud", 1.7)
				_go(State.STALK if target != null else State.BALK)
				if state == State.BALK:
					_shoo()
		State.STALK:
			if not _target_ok():
				_fly_off()
			elif _stand_off(delta, g, dist, who, pose):
				pass
			else:
				var gap := Vector3(target.global_position.x - position.x, 0, target.global_position.z - position.z)
				if gap.length() <= 0.62:
					_go(State.TUG)
					_honk(1.1)
				else:
					_speed = WADDLE
					_walk(gap.normalized() * WADDLE * delta)
		State.TUG:
			if not _target_ok():
				_fly_off()
			elif _stand_off(delta, g, dist, who, pose):
				_t = maxf(0.0, _t - delta * 1.5)    # she cannot pull and hiss at once
			else:
				pose = {"ram": true, "flap": 0.07 + 0.07 * sin(_t * 11.0)}
				var yank := int(_t / 0.55)
				if yank > _tug_n:
					_tug_n = yank
					target.kick(Vector2(randf_range(-0.5, 0.5), randf_range(0.35, 0.7)))
					Sfx.play_on(self, "rustle", 0.8 + 0.1 * yank)
					FX.burst(self, target.global_position + Vector3(0, 0.12, 0), Art.DIRT, 7, 0.07, 1.8)
				if _t >= TUG_TIME:
					_grab(g)
		State.FLEE:
			_flee_dir = escape_heading(position, who, _t)
			_speed = FLEE_SPEED
			_walk(_flee_dir * FLEE_SPEED * delta)
			pose = {"flap": 0.55, "gallop": true}
			if _honk_t < -1.1:
				_honk(1.2)
				_feathers(3)
			if _t >= FLEE_TIME:
				g.say("Lady Honksworth got away with your %s. She looks SO pleased." % loot)
				_fly_off()
		State.BALK:
			pose = {"alert": _t < 1.6, "call": _honk_t > 0.0, "flap": maxf(0.0, sin(_t * 5.0)) * 0.7}
			if _scarer != null and is_instance_valid(_scarer):
				var to_it := _scarer.global_position - position
				_turn(atan2(to_it.x, to_it.z), delta)
			if _honk_t < -0.7:
				_honk(0.85)
			if _t >= BALK_TIME:
				g.say("The goose took one look at your scarecrow and left in a huff.")
				rotation.y += PI
				_fly_off()
		State.FLY:
			position = glide(_from, _to, _t / FLY_TIME)
			position.y = _from.y + (_to.y - _from.y) * pow(clampf(_t / FLY_TIME, 0.0, 1.0), 1.5)
			pose = {"flap": 1.0, "air": true}
			if _t >= FLY_TIME:
				_leave()
				return
	pose["call"] = _honk_t > 0.0
	_mark.position.y = 1.45 + 0.08 * sin(_t * 9.0)
	rig.animate(delta, _speed, pose)
	# The famous waddle.
	rig.rotation.z = sin(_t * 11.0) * 0.11 if _speed > 0.1 else lerpf(rig.rotation.z, 0.0, minf(1.0, delta * 8.0))


func _target_ok() -> bool:
	return target != null and is_instance_valid(target) and target.state == FarmPlot.State.PLANTED \
		and not target.giant and not ScarecrowSpot.guards(get_tree(), target.global_position)


var _brave := 0.0

## Walk up to her and she turns to hiss, wings out. Stay put and she loses her nerve.
func _stand_off(delta: float, g: GameState, dist: float, who: Vector3, pose: Dictionary) -> bool:
	_brave = face_off(_brave, dist, delta)
	if dist > FACE_OFF_RANGE:
		return false
	_turn(atan2(who.x - position.x, who.z - position.z), delta)
	pose["ram"] = true
	pose["flap"] = 0.8
	_mark.visible = true
	_mark.text = "HSSS!"
	if _honk_t < -0.6:
		_honk(0.72)
	if _brave >= FACE_OFF_TIME:
		_brave = 0.0
		g.say("You out-stare the goose. She remembers an appointment elsewhere. (Swing at her for a feather!)")
		rotation.y = atan2(position.x - who.x, position.z - who.z)
		_fly_off()
	return true


func _grab(g: GameState) -> void:
	var got := target.goose_take()
	target = null
	_brave = 0.0
	if got == "":
		g.say("She nibbled a seedling! It has lost a day's growth.")
		_fly_off()
		return
	loot = got
	_set_loot_model(got)
	_go(State.FLEE)
	_honk(1.35)
	g.shake.emit(0.12)
	g.say("She's got your %s! After her! (sprint, then swing)" % got)
	g.hint_event.emit("goose")


func _turn(want: float, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 9.0))


func _walk(step: Vector3) -> void:
	_turn(atan2(step.x, step.z), step.length() / maxf(_speed, 0.1))
	position += step
	position.y = Terrain.height_at(position.x, position.z)


## The scarecrow she is glaring at gives a cheeky spin.
func _shoo() -> void:
	if _scarer is ScarecrowSpot:
		(_scarer as ScarecrowSpot).shoo()
