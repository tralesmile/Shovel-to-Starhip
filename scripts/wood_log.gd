class_name WoodLog
extends RigidBody3D
## A physical pick-up (log, later stones/ore): pops out of a felled tree, bounces,
## then magnets to the player when close and adds its item to the inventory.

const MAGNET_RANGE := 2.6
const COLLECT_RANGE := 0.75
const ARM_TIME := 0.7   ## seconds before it can be picked up (lets it pop and land)
const LIFETIME := 240.0

var item_id := "wood"
var chunk_color := Color(0, 0, 0, 0)   ## alpha 0 = a wooden log; otherwise a small rock chunk of this colour
var amount := 1
var age := 0.0
var game: GameState
var _collected := false
var _magnet := false
var _prev_vy := 0.0
static var combo := 0
static var last_pick := -10.0


## Pure helper (tested): should a pickup at `dist` and `age` be magnetised / collected?
static func state_for(dist: float, age_s: float) -> String:
	if age_s < ARM_TIME:
		return "wait"
	if dist <= COLLECT_RANGE:
		return "collect"
	if dist <= MAGNET_RANGE:
		return "magnet"
	return "idle"


func _ready() -> void:
	add_to_group("pickup")
	mass = 2.0
	linear_damp = 0.4
	angular_damp = 1.2
	var phys := PhysicsMaterial.new()
	phys.bounce = 0.35
	phys.friction = 0.8
	physics_material_override = phys
	if chunk_color.a > 0.0:
		_build_chunk()
		return
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.16
	cyl.height = 0.8
	cs.shape = cyl
	add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.17
	cm.height = 0.8
	cm.radial_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Art.WOOD
	mat.roughness = 1.0
	cm.material = mat
	mi.mesh = cm
	add_child(mi)
	# Pale end-cap rings read as cut wood.
	for s in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var d := CylinderMesh.new()
		d.top_radius = 0.15
		d.bottom_radius = 0.15
		d.height = 0.02
		d.radial_segments = 8
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Art.WOOD.lightened(0.4)
		d.material = m2
		cap.mesh = d
		cap.position.y = 0.4 * s
		add_child(cap)


## Stone / ore / gem chunk: a small tumbling rock.
func _build_chunk() -> void:
	mass = 1.0
	var sz := 0.3 if item_id == "stone" else 0.22
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3.ONE * sz
	cs.shape = bx
	add_child(cs)
	var mi := Art.box(Vector3.ONE * sz, chunk_color)
	if item_id != "stone":
		mi.material_override = Art.mat(chunk_color, true)   # ore and gems shimmer
	add_child(mi)
	if item_id != "stone":
		var sp := FX.emitter(self, chunk_color.lightened(0.5), 4, 0.9, 0.05, Vector3(0.15, 0.1, 0.15), Vector3(0, 0.4, 0), true, "sphere")
		sp.emitting = true
	if item_id == "gem":
		var glow := OmniLight3D.new()
		glow.light_color = chunk_color
		glow.light_energy = 0.8
		glow.omni_range = 2.5
		add_child(glow)


## Pop out with a small random hop.
func pop(dir: Vector3 = Vector3.ZERO) -> void:
	apply_central_impulse((Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 1.6 + dir + Vector3.UP * 4.2) * mass)
	apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 1.5)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	age += delta
	if age > LIFETIME:
		queue_free()
		return
	if FX.is_hard_landing(_prev_vy, linear_velocity.y) and not _magnet:
		FX.burst(self, global_position + Vector3(0, 0.05, 0), Color(0.72, 0.64, 0.5), 5, 0.14, 1.4, -1.0, "sphere", 80.0)
		Sfx.play_on(self, "thud", 0.9 + randf() * 0.3)
	_prev_vy = linear_velocity.y
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	var to := pl.global_position + Vector3(0, 0.8, 0) - global_position
	match state_for(to.length(), age):
		"collect":
			collect()
		"magnet":
			_magnet = true
			gravity_scale = 0.0
			linear_velocity = linear_velocity.lerp(to.normalized() * 7.0, min(1.0, delta * 10.0))
		_:
			if _magnet:
				_magnet = false
				gravity_scale = 1.0


func collect() -> void:
	if _collected:
		return
	_collected = true
	if game != null:
		game.add_item(item_id, amount)
	var now := Time.get_ticks_msec() / 1000.0
	combo = FX.pickup_combo(combo, now - last_pick)
	last_pick = now
	Sfx.play_on(self, "blip", FX.combo_pitch(combo))
	FX.burst(self, global_position, (Art.WOOD.lightened(0.3) if chunk_color.a == 0.0 else chunk_color.lightened(0.3)), 5, 0.07, 2.0, -4.0)
	queue_free()
