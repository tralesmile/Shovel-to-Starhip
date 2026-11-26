class_name BoomTurnip
extends RigidBody3D
## Terraria-style bomb, farm edition: a turnip stuffed with ore dust. Thrown as a real physics
## body (it bounces and rolls), blinks faster as the fuse burns, then blows up rocks, crates and
## cracked walls, flings loose objects and launches you if you stand too close. Nobody dies.

const FUSE := 2.2
const RADIUS := 4.2
const THROW_SPEED := 10.0
const COOLDOWN := 0.8
const NOISE_RANGE := 14.0
const BODY_IMPULSE := 9.0
const PLAYER_KNOCK := 11.0

var game: GameState
var fuse := FUSE
var _mesh: Node3D
var _mat: StandardMaterial3D
var _spark: CPUParticles3D
var _light: OmniLight3D
var _blink := 0.0
var _done := false


## Pure (tested): can a Boom Turnip be thrown now?
static func can_throw(owned: int, cooldown_left: float) -> bool:
	return owned > 0 and cooldown_left <= 0.0


## Pure (tested): lob velocity from camera yaw/pitch (always arcs upward a bit).
static func throw_velocity(yaw: float, pitch: float) -> Vector3:
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var lift := clampf(4.0 + (pitch + 0.45) * 6.0, 2.0, 7.0)
	return fwd * THROW_SPEED * 0.75 + Vector3(0, lift, 0)


## Pure (tested): blinks per second; speeds up as the fuse runs out.
static func blink_rate(fuse_left: float) -> float:
	return lerpf(14.0, 3.0, clampf(fuse_left / FUSE, 0.0, 1.0))


## Pure (tested): 1 at the centre, 0 at the edge of the blast.
static func falloff(dist: float, radius: float = RADIUS) -> float:
	return clampf(1.0 - dist / radius, 0.0, 1.0)


## Pure (tested): velocity change for something at `to` from a blast at `from`.
static func knock(from: Vector3, to: Vector3, strength: float, radius: float = RADIUS) -> Vector3:
	var d := to - from
	var f := falloff(d.length(), radius)
	if f <= 0.0:
		return Vector3.ZERO
	var flat := Vector3(d.x, 0, d.z)
	var out := flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
	return (out + Vector3(0, 0.8, 0)).normalized() * strength * (0.4 + 0.6 * f)


func _ready() -> void:
	add_to_group("bomb")
	mass = 1.2
	angular_damp = 1.5
	linear_damp = 0.2
	var phys := PhysicsMaterial.new()
	phys.bounce = 0.4
	phys.friction = 0.9
	physics_material_override = phys
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.24
	cs.shape = sph
	add_child(cs)
	_mesh = Node3D.new()
	add_child(_mesh)
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.46
	sm.radial_segments = 10
	sm.rings = 5
	body.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.82, 0.5, 0.78)
	_mat.roughness = 0.9
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.25, 0.1)
	_mat.emission_energy_multiplier = 0.0
	body.material_override = _mat
	_mesh.add_child(body)
	var stalk := Art.cylinder(0.02, 0.05, 0.22, Color(0.3, 0.6, 0.25), 6)
	stalk.position.y = 0.3
	_mesh.add_child(stalk)
	_spark = FX.emitter(self, Color(1.0, 0.8, 0.25), 18, 0.35, 0.05, Vector3(0.02, 0.02, 0.02), Vector3(0, -4.0, 0), true, "box")
	_spark.position.y = 0.45
	_spark.local_coords = false
	_spark.initial_velocity_min = 0.8
	_spark.initial_velocity_max = 2.2
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.light_energy = 0.8
	_light.omni_range = 3.0
	_light.position.y = 0.5
	add_child(_light)


func _physics_process(delta: float) -> void:
	if _done:
		return
	fuse -= delta
	_blink += delta * blink_rate(fuse)
	var on := fmod(_blink, 1.0) < 0.5
	_mat.emission_energy_multiplier = 1.6 if on else 0.0
	_mesh.scale = Vector3.ONE * (1.0 + (0.18 if on else 0.0) * (1.0 - clampf(fuse / FUSE, 0.0, 1.0)))
	_light.light_energy = 1.8 if on else 0.5
	if fuse <= 0.0 or global_position.y < -10.0:
		explode()


## Applies the blast to everything in range. Returns how many rocks and walls it broke.
func explode() -> int:
	if _done:
		return 0
	_done = true
	var at := global_position
	var tree := get_tree()
	var broke := 0
	for n in tree.get_nodes_in_group("blastable"):
		var wall := n as CrackedWall
		if wall != null:
			if CrackedWall.blast_opens(wall.blast_distance(at), RADIUS) and wall.blast(game, at):
				broke += 1
		elif n is MineRock:
			if at.distance_to((n as MineRock).global_position + Vector3(0, 0.6, 0)) <= RADIUS and (n as MineRock).blast(game):
				broke += 1
	for n in tree.get_nodes_in_group("smashable"):
		var cr := n as PropCrate
		if cr != null and cr.global_position.distance_to(at) <= RADIUS:
			cr.game = game
			cr.hits = PropCrate.HITS_TO_SMASH - 1
			cr.smash_hit()
	for n in tree.get_nodes_in_group("huntable"):
		var c := n as Critter
		if c != null and c.visible and c.global_position.distance_to(at) <= RADIUS:
			c.bonk(game)
	for group in ["pickup", "smashable", "rubble", "bomb"]:
		for n in tree.get_nodes_in_group(group):
			var rb := n as RigidBody3D
			if rb == null or rb == self or rb.is_queued_for_deletion():
				continue
			var k := knock(at, rb.global_position, BODY_IMPULSE)
			if k != Vector3.ZERO:
				rb.apply_central_impulse(k * rb.mass)
	var pl := tree.get_first_node_in_group("player") as Node3D
	if pl != null and pl.has_method("blast_knock"):   # untyped on purpose: Player needs the Game autoload
		var d := pl.global_position + Vector3(0, 0.8, 0) - at
		var pk := knock(at, pl.global_position + Vector3(0, 0.8, 0), PLAYER_KNOCK)
		if pk != Vector3.ZERO:
			pl.call("blast_knock", pk)
		game.shake.emit(clampf(1.1 - d.length() * 0.06, 0.2, 1.0))
	if not Police.is_hidden(at):
		for n in tree.get_nodes_in_group("npc"):
			var npc := n as Npc
			if npc != null and not npc.indoors and npc.global_position.distance_to(at) <= NOISE_RANGE:
				game.add_heat(0.5)
				game.say("%s: \"WHO is exploding vegetables out here?!\"" % npc.npc_name)
				break
	_boom_fx(at)
	FX.hit_stop(tree, 1.0)
	queue_free()
	return broke


## Flash, fireball, smoke, expanding shockwave ring and a scorch mark that fades.
func _boom_fx(at: Vector3) -> void:
	var host := get_parent()
	if host == null:
		return
	Sfx.play_on(host, "boom")
	FX.burst(host, at, Color(1.0, 0.55, 0.1), 46, 0.3, 7.5, -5.0, "sphere", 180.0, true)
	FX.burst(host, at, Color(1.0, 0.95, 0.55), 24, 0.14, 10.0, -9.0, "box", 180.0, true)
	FX.burst(host, at + Vector3(0, 0.3, 0), Color(0.3, 0.28, 0.3), 22, 0.55, 2.4, 1.2, "sphere", 90.0)
	FX.burst(host, at, Color(0.82, 0.5, 0.78), 10, 0.12, 5.0, -10.0, "box", 120.0)   # turnip bits
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.3)
	flash.light_energy = 9.0
	flash.omni_range = 14.0
	host.add_child(flash)
	flash.global_position = at + Vector3(0, 0.8, 0)
	var ft := flash.create_tween()
	ft.tween_property(flash, "light_energy", 0.0, 0.45)
	ft.tween_callback(flash.queue_free)
	# Fireball core: a hot glowing ball that swells and fades in a quarter second.
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 1.0
	cm.height = 2.0
	cm.radial_segments = 10
	cm.rings = 6
	core.mesh = cm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1.0, 0.82, 0.35, 0.85)
	core.material_override = fm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(core)
	core.global_position = at
	core.scale = Vector3.ONE * 0.35
	var ct := core.create_tween().set_parallel(true)
	ct.tween_property(core, "scale", Vector3.ONE * 1.9, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ct.tween_property(fm, "albedo_color", Color(0.9, 0.25, 0.05, 0.0), 0.28)
	ct.chain().tween_callback(core.queue_free)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.86
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 6
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1.0, 0.92, 0.7, 0.8)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(ring)
	ring.global_position = at
	ring.scale = Vector3.ONE * 0.3
	var rt := ring.create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector3(RADIUS, 1.0, RADIUS), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_property(rm, "albedo_color:a", 0.0, 0.35)
	rt.chain().tween_callback(ring.queue_free)
	# Scorch mark on whatever floor is underneath.
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -2.5, 0))
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var scorch := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.3
	disc.bottom_radius = 1.3
	disc.height = 0.02
	disc.radial_segments = 11
	scorch.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.05, 0.03, 0.02, 0.6)
	scorch.material_override = sm
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(scorch)
	scorch.global_position = (hit["position"] as Vector3) + Vector3(0, 0.03, 0)
	var st := scorch.create_tween()
	st.tween_interval(8.0)
	st.tween_property(sm, "albedo_color:a", 0.0, 3.0)
	st.tween_callback(scorch.queue_free)
