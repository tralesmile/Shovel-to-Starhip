class_name GiantBall
extends RigidBody3D
## A pulled giant crop: a heavy rolling vegetable. Push it or heave it (E) to the sell bin for a
## weigh-in bonus, or chop it with the axe into a shower of ordinary produce.

const RADIUS := 0.85
const CHOPS := 3
const CHOP_YIELD := 8
const WEIGH_RANGE := 2.5
const WEIGH_MULT := 10        ## sale = unit price x this (beats chopping, which gives 8 units)
const BIN_POS := Vector2(6.4, 6.2)
const HOME := Vector3(0, 2.0, 0)

var crop := "turnip"
var game: GameState
var chops := 0
var _done := false
var _spot: Spot
var _tag: Label3D
var _prev_vy := 0.0
var _roll_puff := 0.0


## The E target that rides along with the ball (kept upright while the ball tumbles).
class Spot extends Interactable:
	var ball: GiantBall

	func get_prompt(g: GameState) -> String:
		if g.current_tool == GameState.Tool.AXE:
			return "[E] Chop up the giant %s (%d/%d)" % [ball.crop, ball.chops, GiantBall.CHOPS]
		return "[E] Heave it!  Roll to the SELL BIN: $%d  (or Axe [4] to chop)" % GiantBall.weigh_value(ball.crop)

	func interact(g: GameState) -> void:
		if g.current_tool == GameState.Tool.AXE:
			ball.chop(g)
		else:
			ball.heave(g)


## Pure (tested): the weigh-in payout.
static func weigh_value(crop_id: String) -> int:
	return int(GameState.ITEMS[crop_id]["sell"]) * WEIGH_MULT


## Pure (tested): the (silly) weight announced at the scales.
static func weight_kg(crop_id: String, day: int) -> int:
	return 90 + posmod(hash("%s:%d" % [crop_id, day]), 140)


## Pure (tested): close enough to the bin to be weighed?
static func at_bin(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(BIN_POS) <= WEIGH_RANGE


## Pure (tested): has it gone somewhere you could never get it back from?
static func lost(p: Vector3, in_water: bool) -> bool:
	return p.y < -3.0 or absf(p.x) > 75.0 or absf(p.z) > 75.0 or (in_water and p.y < Terrain.WATER_LEVEL + RADIUS)


## Heave velocity: forward along `yaw`, with enough lift to clear the farm fence.
static func heave_velocity(yaw: float) -> Vector3:
	return Vector3(sin(yaw) * 4.2, 6.2, cos(yaw) * 4.2)


func _ready() -> void:
	add_to_group("giantball")
	mass = 22.0
	linear_damp = 0.25
	angular_damp = 0.9
	continuous_cd = true
	var phys := PhysicsMaterial.new()
	phys.friction = 0.9
	phys.bounce = 0.35
	physics_material_override = phys
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = RADIUS
	cs.shape = sh
	add_child(cs)
	var veg := CropModel.produce(crop)
	veg.scale = Vector3.ONE * GiantCrop.SCALE
	add_child(veg)
	_spot = Spot.new()
	_spot.ball = self
	_spot.interact_radius = 2.0
	add_child(_spot)
	_tag = Art.label("GIANT %s\nto the SELL BIN!" % crop.to_upper(), 40, Color(1.0, 0.95, 0.6))
	_tag.top_level = true
	add_child(_tag)


## First hop out of the soil. Sets velocity directly: an impulse on a body added this same frame is
## applied before the physics server knows its mass, which fired a 22 kg turnip 130 m into the sky.
func launch(v: Vector3) -> void:
	linear_velocity = v
	angular_velocity = Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))


func heave(g: GameState) -> void:
	if _done:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var yaw := 0.0
	if pl != null:
		yaw = atan2(global_position.x - pl.global_position.x, global_position.z - pl.global_position.z)
	var v := heave_velocity(yaw)
	linear_velocity = Vector3.ZERO
	apply_central_impulse(v * mass)
	apply_torque_impulse(Vector3(cos(yaw), 0, -sin(yaw)) * mass * 1.2)
	g.shake.emit(0.2)
	Sfx.play_on(self, "boing", 0.55)


func chop(g: GameState) -> void:
	if _done:
		return
	chops += 1
	g.shake.emit(0.2 + 0.1 * chops)
	if is_inside_tree():
		FX.hit_stop(get_tree(), 0.35)
		Sfx.play_on(self, "chop", 0.75)
		FX.burst(self, global_position + Vector3(0, 0.5, 0), CropModel.COLORS[crop]["body"], 12 + 6 * chops, 0.12, 4.0)
	if chops < CHOPS:
		return
	_done = true
	var host := get_parent()
	for i in CHOP_YIELD:
		var item := WoodLog.new()
		item.item_id = crop
		item.game = g
		host.add_child(item)
		var a := i * TAU / CHOP_YIELD
		item.position = position + Vector3(cos(a) * 0.5, 0.2 + (i % 3) * 0.25, sin(a) * 0.5)
		item.pop(Vector3(cos(a), 0.5, sin(a)) * 1.2)
	if is_inside_tree():
		FX.burst(host, global_position, CropModel.COLORS[crop]["body"], 40, 0.18, 6.0)
		FX.burst(host, global_position, CropModel.COLORS[crop]["cap"], 20, 0.14, 5.0)
		Sfx.play_on(self, "crunch", 1.2)
	g.say("It comes apart into %d perfectly normal %ss." % [CHOP_YIELD, crop])
	queue_free()


## Sell it at the scales. Returns the money paid.
func weigh_in(g: GameState) -> int:
	if _done:
		return 0
	_done = true
	var pay := weigh_value(crop)
	g.earn(pay)
	g.add_reputation(1.0)
	g.say("WEIGH-IN: %d kg of %s! Blue ribbon! +$%d" % [weight_kg(crop, g.day), crop, pay])
	g.shake.emit(0.5)
	if is_inside_tree():
		var host := get_parent()
		for c in [Color(1.0, 0.82, 0.2), Color(0.35, 0.65, 1.0), Color(1.0, 0.4, 0.55), Color(0.5, 0.95, 0.45)]:
			FX.burst(host, global_position + Vector3(0, 0.8, 0), c, 18, 0.12, 6.5, -7.0, "box", 55.0)
		Sfx.play_on(self, "fanfare", 1.1)
	queue_free()
	return pay


func _physics_process(delta: float) -> void:
	if _done or game == null:
		return
	_spot.global_position = global_position + Vector3(0, -RADIUS, 0)
	_tag.global_position = global_position + Vector3(0, 1.5, 0)
	if at_bin(global_position):
		weigh_in(game)
		return
	if lost(global_position, Terrain.is_water(global_position.x, global_position.z)):
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		global_position = HOME
		game.say("Your giant %s rolled off to see the world. It has been returned to the farm." % crop)
		return
	if FX.is_hard_landing(_prev_vy, linear_velocity.y):
		FX.burst(self, global_position + Vector3(0, -RADIUS, 0), Color(0.75, 0.65, 0.48), 20, 0.22, 3.0, -2.0, "sphere", 85.0)
		Sfx.play_on(self, "thud", 0.65)
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl != null:
			game.shake.emit(clampf(0.5 - pl.global_position.distance_to(global_position) * 0.05, 0.05, 0.4))
	_prev_vy = linear_velocity.y
	# Dust trail while it is really rolling.
	_roll_puff -= delta
	var flat := Vector2(linear_velocity.x, linear_velocity.z).length()
	if flat > 1.5 and absf(linear_velocity.y) < 1.0 and _roll_puff <= 0.0:
		_roll_puff = 0.14
		FX.burst(self, global_position + Vector3(0, -RADIUS + 0.05, 0), Color(0.75, 0.66, 0.5), 3, 0.18, 1.0, -0.5, "sphere", 80.0)
