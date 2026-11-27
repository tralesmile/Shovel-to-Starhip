class_name Pebble
extends Node3D
## Slingshot ammo in flight: a small stone on a gravity arc. Hits rabbits (bonk), crates (smash) and
## the ground (dust + a chance to land as a pick-up-able stone again). Stepped by hand, no RigidBody.

const SPEED := 26.0
const GRAVITY := -14.0
const MAX_LIFE := 2.2
const COOLDOWN := 0.5
const HIT_RADIUS := 0.75   ## generous cartoon hit radius around a rabbit
const RECOVER_CHANCE := 0.6

var game: GameState
var vel := Vector3.ZERO
var life := 0.0
var shooter: Node
var _mesh: MeshInstance3D
var _trail: CPUParticles3D


## Pure (tested): can the slingshot fire right now?
static func can_fire(owned: int, stones: int, cooldown_left: float) -> bool:
	return owned > 0 and stones > 0 and cooldown_left <= 0.0


const CHARGE_TIME := 0.8
const MIN_POWER := 0.45


## Pure (tested): 0..1 draw strength after holding the sling for `held` seconds (a tap is a weak plink).
static func charge_power(held: float) -> float:
	return lerpf(MIN_POWER, 1.0, clampf(held / CHARGE_TIME, 0.0, 1.0))


## Pure (tested): launch velocity from camera yaw/pitch. Aim a touch above the crosshair so shots lob in.
static func launch_velocity(yaw: float, pitch: float, power: float = 1.0) -> Vector3:
	var fwd := Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3(0, 0, -1)
	fwd.y += 0.1
	return fwd.normalized() * SPEED * power


## Pure (tested): one Euler step of the arc.
static func step_arc(pos: Vector3, v: Vector3, dt: float) -> Array:
	var nv := v + Vector3(0, GRAVITY * dt, 0)
	return [pos + nv * dt, nv]


## Pure (tested): did a pebble at `p` hit a target at `t` (flat-ish sphere test, target hop height 0.4)?
static func hits_target(p: Vector3, t: Vector3, radius: float = HIT_RADIUS) -> bool:
	return p.distance_to(t + Vector3(0, 0.4, 0)) <= radius


## Pure (tested): does a missed pebble survive as a pick-up stone? (roll in 0..1)
static func recovers(roll: float) -> bool:
	return roll < RECOVER_CHANCE


## Pure (tested): wind-up squash scale for the slingshot hand model after firing (t seconds since shot).
static func recoil_scale(t: float) -> float:
	if t < 0.0 or t > 0.25:
		return 1.0
	return 1.0 + 0.35 * sin(t / 0.25 * PI) * (1.0 - t / 0.25)


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 8
	sm.rings = 4
	_mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.6, 0.58)
	_mesh.material_override = mat
	add_child(_mesh)
	_trail = CPUParticles3D.new()
	_trail.amount = 14
	_trail.lifetime = 0.3
	_trail.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(1, 1, 1, 0.7)
	tm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = tm
	_trail.mesh = qm
	_trail.gravity = Vector3.ZERO
	_trail.scale_amount_min = 0.5
	_trail.scale_amount_max = 1.0
	add_child(_trail)


func _physics_process(delta: float) -> void:
	life += delta
	var start := global_position
	var r := step_arc(start, vel, delta)
	var end: Vector3 = r[0]
	vel = r[1]
	# Rabbits have no colliders: distance test along the segment end points.
	for n in get_tree().get_nodes_in_group("huntable"):
		var c := n as Critter
		if c != null and c.visible and (hits_target(end, c.global_position) or hits_target((start + end) * 0.5, c.global_position)):
			c.bonk(game)
			FX.hit_stop(get_tree(), 0.4)
			game.shake.emit(0.15)
			_pop(end, Color(1, 1, 1))
			return
	for n2 in get_tree().get_nodes_in_group("goose"):
		var goose := n2 as Goose
		if goose.bonkable() and (hits_target(end, goose.global_position, Goose.HIT_RADIUS) or hits_target((start + end) * 0.5, goose.global_position, Goose.HIT_RADIUS)):
			goose.bonk(game)
			FX.hit_stop(get_tree(), 0.4)
			_pop(end, Color(1, 1, 1))
			return
	var q := PhysicsRayQueryParameters3D.create(start, end)
	if shooter is CollisionObject3D:
		q.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var col = hit["collider"]
		if col is PropCrate:
			(col as PropCrate).game = game
			(col as PropCrate).smash_hit()
			FX.hit_stop(get_tree(), 0.3)
			game.shake.emit(0.12)
		elif col is RigidBody3D:
			(col as RigidBody3D).apply_impulse(vel.normalized() * 2.0, hit["position"] - (col as Node3D).global_position)
		_land(hit["position"])
		return
	global_position = end
	if life > MAX_LIFE or end.y < -5.0:
		queue_free()


func _pop(pos: Vector3, col: Color) -> void:
	FX.burst(get_parent(), pos, col, 6, 0.08, 2.5, -6.0, "sphere")
	queue_free()


func _land(pos: Vector3) -> void:
	var host := get_parent()
	FX.burst(host, pos, Color(0.6, 0.55, 0.4), 7, 0.1, 2.0, -7.0, "box")
	Sfx.play_on(self, "thud", 1.8)
	if recovers(randf()) and game != null:
		var p := WoodLog.new()
		p.game = game
		p.item_id = "stone"
		p.chunk_color = WoodLog.drop_color("stone")
		host.add_child(p)
		p.global_position = pos + Vector3(0, 0.25, 0)
		p.pop()
	queue_free()
