class_name Decoy
extends RigidBody3D
## The Squeaky Chicken: a thrown rubber chicken that bounces, flops about and
## squeaks. Anyone awake within earshot turns to stare at it, which is when you
## get to work. Reusable: walk over it once it goes quiet to pocket it again.

const SQUEAKS := 6
const SQUEAK_GAP := Stealth.DISTRACT_TIME / SQUEAKS
const ARM_TIME := 0.5
const PICKUP_DIST := 1.3
const ITEM := "squeaky_chicken"

var game: GameState
var age := 0.0
var squeaks := 0
var landed := false
var _next := 0.0
var _model: Node3D
var _squash := 0.0


## Pure (tested): a soft underarm lob that stays under an indoor ceiling.
static func throw_velocity(yaw: float, pitch: float) -> Vector3:
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var lift := clampf(3.0 + (pitch + 0.45) * 3.0, 1.8, 4.2)
	return fwd * 6.0 + Vector3(0, lift, 0)


## Pure (tested): can it be pocketed again?
static func can_collect(age_s: float, squeaks_done: int, dist: float) -> bool:
	return age_s >= ARM_TIME and squeaks_done >= SQUEAKS and dist <= PICKUP_DIST


static func build_model() -> Node3D:
	var n := Node3D.new()
	var yellow := Color(1.0, 0.86, 0.2)
	var body := Art.sphere(0.16, yellow)
	body.scale = Vector3(0.85, 0.8, 1.35)
	n.add_child(body)
	var neck := Art.cylinder(0.045, 0.065, 0.24, yellow, 8)
	neck.position = Vector3(0, 0.15, 0.17)
	neck.rotation.x = 0.45
	n.add_child(neck)
	var head := Art.sphere(0.085, yellow)
	head.position = Vector3(0, 0.27, 0.24)
	n.add_child(head)
	var comb := Art.box(Vector3(0.03, 0.08, 0.1), Color(0.92, 0.16, 0.12))
	comb.position = Vector3(0, 0.36, 0.23)
	n.add_child(comb)
	var beak := Art.box(Vector3(0.07, 0.04, 0.11), Color(1.0, 0.48, 0.08))
	beak.position = Vector3(0, 0.25, 0.34)
	n.add_child(beak)
	for sx in [-1.0, 1.0]:
		var eye := Art.sphere(0.024, Color(0.05, 0.04, 0.06))
		eye.position = Vector3(sx * 0.055, 0.3, 0.29)
		n.add_child(eye)
		var leg := Art.cylinder(0.015, 0.015, 0.22, Color(1.0, 0.48, 0.08), 6)
		leg.position = Vector3(sx * 0.07, -0.08, -0.22)
		leg.rotation.x = 1.15
		n.add_child(leg)
	return n


func _ready() -> void:
	add_to_group("decoy")
	mass = 0.5
	angular_damp = 1.8
	linear_damp = 0.3
	contact_monitor = true
	max_contacts_reported = 3
	continuous_cd = true
	collision_mask |= Buildings.CEILING_LAYER
	var phys := PhysicsMaterial.new()
	phys.bounce = 0.5
	phys.friction = 0.9
	physics_material_override = phys
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.17
	cs.shape = sph
	add_child(cs)
	_model = build_model()
	add_child(_model)
	body_entered.connect(func(_b): land())


## First thing it touches: the show begins.
func land() -> void:
	if landed:
		return
	landed = true
	_next = 0.0


func _process(delta: float) -> void:
	step(delta)
	_squash = maxf(0.0, _squash - delta * 4.0)
	_model.scale = Vector3(1.0 + 0.25 * _squash, 1.0 - 0.4 * _squash, 1.0 + 0.25 * _squash)
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null and game != null and can_collect(age, squeaks, pl.global_position.distance_to(global_position)):
		collect()


## Advances the squeak schedule (also driven directly by tests).
func step(delta: float) -> void:
	age += delta
	if not landed and age > 1.5:
		land()   # never let a snagged chicken stay silent
	if not landed or squeaks >= SQUEAKS:
		return
	_next -= delta
	if _next <= 0.0:
		_next = SQUEAK_GAP
		squeak()


func squeak() -> void:
	squeaks += 1
	_squash = 1.0
	Sfx.play_on(self, "squeak", 0.9 + 0.05 * (squeaks % 4))
	if is_inside_tree():
		FX.burst(self, global_position + Vector3(0, 0.35, 0), Color(1.0, 0.95, 0.5), 5, 0.05, 1.6, -1.0, "sphere", 70.0)
		for n in get_tree().get_nodes_in_group("npc"):
			if n.has_method("hear_noise"):
				n.hear_noise(global_position)


func collect() -> void:
	game.add_item(ITEM, 1)
	Sfx.play_on(get_parent(), "squeak", 1.5)
	FX.burst(get_parent(), global_position + Vector3(0, 0.3, 0), Color(1.0, 0.86, 0.2), 8, 0.07, 2.0)
	queue_free()
