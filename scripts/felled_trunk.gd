class_name FelledTrunk
extends Interactable
## The trunk of a felled tree: a heavy rigid body lying along the fall line (Valheim-style).
## It can be shoved and rolled, and the axe "bucks" it one section at a time: each section
## cuts free from the far end as a log you pick up (and can split into planks).
## The Interactable node slides along the trunk to the point nearest the player, so you can
## chop it from anywhere along its length.

const SECTION := 1.0         ## metres of trunk per log
const RADIUS := 0.27
const CUTS_PER_SECTION := 2  ## axe swings to free one log (1 with the Copper Axe)
const STUMP_GAP := 0.55      ## the butt end starts this far from the stump

var sections := 3
var cuts := 0
var game: GameState
var body: RigidBody3D
var _shape: CylinderShape3D
var _visual: Node3D
var _crown: Node3D
var _start: Transform3D


# ---------------------------------------------------------------- pure helpers (tested)

static func cuts_needed(upgraded: bool) -> int:
	return CUTS_PER_SECTION - 1 if upgraded else CUTS_PER_SECTION


## Pure: nearest point to `p` on the segment of length `length` centred at `centre` along unit `axis`.
static func closest_on_axis(centre: Vector3, axis: Vector3, length: float, p: Vector3) -> Vector3:
	var t := clampf((p - centre).dot(axis), -length * 0.5, length * 0.5)
	return centre + axis * t


## Pure: where the trunk centre rests for a tree at `base` that fell along `dir`.
static func rest_centre(base: Vector3, dir: Vector3, count: int) -> Vector3:
	return base + dir * (STUMP_GAP + count * SECTION * 0.5) + Vector3(0, RADIUS + 0.12, 0)


## Pure: the basis whose local +z points along the fall line (towards the old tree top).
static func lie_basis(dir: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(dir.x, dir.z))


# ---------------------------------------------------------------- build

## Call before adding to the tree.
func setup(base: Vector3, dir: Vector3, count: int, g: GameState) -> void:
	sections = maxi(count, 1)
	game = g
	_start = Transform3D(lie_basis(dir), rest_centre(base, dir, sections))


func _ready() -> void:
	add_to_group("trunk")
	interact_radius = 1.5
	body = RigidBody3D.new()
	body.top_level = true
	body.mass = 45.0
	body.linear_damp = 1.2
	body.angular_damp = 3.5
	var phys := PhysicsMaterial.new()
	phys.friction = 0.9
	phys.bounce = 0.12
	body.physics_material_override = phys
	var cs := CollisionShape3D.new()
	_shape = CylinderShape3D.new()
	_shape.radius = RADIUS
	cs.shape = _shape
	cs.rotation.x = PI * 0.5
	body.add_child(cs)
	add_child(body)
	body.global_transform = _start
	position = _start.origin
	_visual = Node3D.new()
	body.add_child(_visual)
	_rebuild()
	_build_crown()


## Bark, knots and pale cut rings, rebuilt each time a section comes off.
func _rebuild() -> void:
	var length := sections * SECTION
	_shape.height = length
	for c in _visual.get_children():
		c.queue_free()
	var bark := Color(0.42, 0.27, 0.17)
	var trunk := Art.cylinder(RADIUS * 0.94, RADIUS, length, bark, 9)
	trunk.rotation.x = PI * 0.5
	_visual.add_child(trunk)
	# Darker bark bands mark where each log will come free.
	for k in range(1, sections):
		var band := Art.cylinder(RADIUS * 1.04, RADIUS * 1.04, 0.05, bark.darkened(0.35), 9)
		band.rotation.x = PI * 0.5
		band.position.z = -length * 0.5 + k * SECTION
		_visual.add_child(band)
	for s in [-1.0, 1.0]:
		for ring in 3:
			var wood := Art.WOOD.lightened(0.45) if ring % 2 == 0 else Art.WOOD.lightened(0.15)
			var cap := Art.cylinder(RADIUS * (0.86 - ring * 0.27), RADIUS * (0.86 - ring * 0.27), 0.02, wood, 9)
			cap.rotation.x = PI * 0.5
			cap.position.z = s * (length * 0.5 + 0.004 + ring * 0.006)
			_visual.add_child(cap)
	# A snapped branch stub or two.
	for k in sections:
		var stub := Art.cylinder(0.03, 0.07, 0.28, bark.darkened(0.15), 5)
		var side := 1.0 if k % 2 == 0 else -1.0
		stub.position = Vector3(side * RADIUS * 0.9, RADIUS * 0.5, -length * 0.5 + k * SECTION + 0.55)
		stub.rotation.z = -side * 0.95
		_visual.add_child(stub)


## The leafy top lies past the far end until the first log is cut free.
func _build_crown() -> void:
	_crown = Node3D.new()
	body.add_child(_crown)
	var z := sections * SECTION * 0.5
	for k in 3:
		var tier := Art.cylinder(0.0, 0.72 - k * 0.15, 1.15 - k * 0.12, Color(0.09, 0.52, 0.40).lightened(0.07 * k), 8)
		tier.rotation.x = PI * 0.5
		tier.scale = Vector3(1.0, 1.0, 0.62)   # squashed by the landing (local z of the cone is world up)
		tier.position = Vector3(0, 0.12 - k * 0.03, z + 0.35 + k * 0.55)
		_crown.add_child(tier)


## The axis (towards the far end) in world space.
func axis() -> Vector3:
	return body.global_basis.z.normalized() if body.is_inside_tree() else body.basis.z.normalized()


func _physics_process(_delta: float) -> void:
	if body == null:
		return
	var at := body.global_position
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null:
		at = closest_on_axis(body.global_position, axis(), sections * SECTION, pl.global_position)
	global_position = at
	if body.global_position.y < -20.0:   # fell out of the world: don't lose the wood
		body.global_position = at + Vector3(0, 25.0, 0)
		body.linear_velocity = Vector3.ZERO


func get_prompt(g: GameState) -> String:
	if g.current_tool == GameState.Tool.AXE:
		return "[E] Buck the trunk (%d/%d)  - %d log(s) left" % [cuts, cuts_needed(g.count("copper_axe") > 0), sections]
	return "A felled trunk. Use the Axe [4] to cut it into logs."


func interact(g: GameState) -> void:
	if sections <= 0:
		return
	if g.current_tool != GameState.Tool.AXE:
		g.say("You try to pocket the whole tree. Your pockets file a complaint.")
		return
	game = g
	cuts += 1
	var need := cuts_needed(g.count("copper_axe") > 0)
	Sfx.play_on(self, "chop", 0.9 + 0.12 * cuts)
	FX.chips(self, global_position + Vector3(0, 0.25, 0), Vector3(axis().z, 0, -axis().x), cuts, need)
	FX.hit_stop(get_tree(), 0.25 if cuts < need else 0.55)
	g.shake.emit(0.1)
	_jolt()
	if cuts >= need:
		cuts = 0
		_free_log()


## The whole trunk hops a little with every bite of the axe.
func _jolt() -> void:
	body.sleeping = false
	body.apply_central_impulse(Vector3.UP * 0.7 * body.mass)
	_visual.scale = Vector3(1.14, 0.88, 1.0)
	var tw := _visual.create_tween()
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Cuts the far section loose as a pick-up-able log; the butt end stays where it is.
func _free_log() -> void:
	var ax := axis()
	var length := sections * SECTION
	var tip := body.global_position + ax * (length * 0.5 - SECTION * 0.5)
	if _crown != null:
		FX.burst(self, tip + ax * 1.0 + Vector3(0, 0.3, 0), Color(0.16, 0.62, 0.42), 28, 0.13, 3.2, -3.0, "box", 150.0)
		Sfx.play_on(self, "rustle", 0.8)
		_crown.queue_free()
		_crown = null
	var lg := WoodLog.new()
	lg.game = game
	var host := get_parent()
	host.add_child(lg)
	var side := ax.cross(Vector3.UP).normalized()
	lg.global_transform = Transform3D(Basis(side, PI * 0.5), tip + Vector3(0, 0.25, 0))   # lies along the trunk
	lg.pop(ax * 1.4)
	FX.burst(self, tip - ax * SECTION * 0.5, Color(0.9, 0.78, 0.5), 16, 0.06, 2.6, -5.0, "sphere", 120.0)
	sections -= 1
	if sections <= 0:
		remove_from_group("interactable")
		remove_from_group("trunk")
		queue_free()
		return
	body.global_position -= ax * SECTION * 0.5
	_rebuild()


# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	var p := body.global_position
	var a := axis()
	return {"sections": sections, "cuts": cuts, "x": p.x, "y": p.y, "z": p.z, "yaw": atan2(a.x, a.z)}


## Restores a saved trunk (call before adding to the tree).
func restore(d: Dictionary, g: GameState) -> void:
	game = g
	sections = clampi(int(d.get("sections", 3)), 1, 3)
	cuts = int(d.get("cuts", 0))
	_start = Transform3D(Basis(Vector3.UP, float(d.get("yaw", 0.0))),
		Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.5)) + 0.05, float(d.get("z", 0.0))))
