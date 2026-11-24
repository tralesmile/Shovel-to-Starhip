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


## Pure (tested): with the axe equipped a plain log waits to be chopped instead of flying to you.
static func wants_chop(id: String, tool: int) -> bool:
	return id == "wood" and tool == GameState.Tool.AXE


## Pure (tested): contact-shadow scale and opacity for a pickup `h` metres above the ground.
static func shadow_for(h: float) -> Vector2:
	var t := clampf(h / 3.0, 0.0, 1.0)
	return Vector2(lerpf(1.0, 0.45, t), lerpf(1.0, 0.25, t))


## Pure (tested): where a dropped item lands; a toss ahead of the player, up a bit.
static func toss_dir(facing_y: float) -> Vector3:
	return Vector3(sin(facing_y), 0.0, cos(facing_y)) * 2.4


var _shadow: MeshInstance3D


func _ready() -> void:
	add_to_group("pickup")
	_shadow = Critter.blob_shadow(0.3)
	_shadow.top_level = true
	add_child(_shadow)
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
	if item_id == "plank":
		_build_plank()
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


## A pale board that tumbles out when a log is chopped.
func _build_plank() -> void:
	mass = 0.8
	var sz := Vector3(0.7, 0.07, 0.2)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = sz
	cs.shape = bx
	add_child(cs)
	add_child(Art.box(sz, Art.WOOD.lightened(0.35)))


## Pure (tested): how many planks a chopped log yields, and the pickup item.
const PLANKS_PER_LOG := 2


## Splits this log into plank pickups with sawdust + chop juice. Returns planks spawned.
func chop_into_planks() -> int:
	if _collected or item_id != "wood" or chunk_color.a > 0.0:
		return 0
	_collected = true
	var host := get_parent()
	var pos := global_position
	FX.burst(host, pos + Vector3(0, 0.2, 0), Color(0.9, 0.78, 0.5), 14, 0.06, 2.6, -5.0, "sphere", 120.0)
	Sfx.play_on(self, "chop", 1.15)
	for i in PLANKS_PER_LOG:
		var pl := WoodLog.new()
		pl.item_id = "plank"
		pl.game = game
		host.add_child(pl)
		pl.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0.3 + i * 0.1, randf_range(-0.2, 0.2))
		pl.pop()
	queue_free()
	return PLANKS_PER_LOG


## Pure (tested): chunk colour for a drop item (alpha 0 = plain log).
static func drop_color(id: String) -> Color:
	match id:
		"rabbit_meat": return Color(0.9, 0.42, 0.45)
		"rabbit_pelt": return Color(0.78, 0.7, 0.6)
		"egg":
			return Color(0.98, 0.95, 0.85)
		"egg": return Color(0.98, 0.95, 0.85)
		"cooked_meat", "rabbit_stew": return Color(0.6, 0.32, 0.18)
		"carrot": return Color(1.0, 0.55, 0.1)
		"copper_ore": return Color(0.85, 0.5, 0.28)
		"gem": return Color(0.4, 0.9, 1.0)
		"copper_ingot": return Color(0.95, 0.62, 0.32)
		"turnip": return Color(0.92, 0.85, 0.95)
		"tomato": return Color(0.9, 0.2, 0.15)
	return Color(0.6, 0.6, 0.62)


## Organic drops (meat, pelts, carrots) do not shimmer like ore.
static func is_organic(id: String) -> bool:
	return id in ["rabbit_meat", "rabbit_pelt", "carrot", "cooked_meat", "egg", "rabbit_stew", "turnip", "tomato"]


## Stone / ore / gem chunk: a small tumbling rock.
func _build_chunk() -> void:
	mass = 1.0
	var sz := 0.3 if item_id == "stone" else 0.22
	if is_organic(item_id):
		sz = 0.26
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3.ONE * sz
	cs.shape = bx
	add_child(cs)
	var mi := Art.box(Vector3.ONE * sz, chunk_color)
	if item_id != "stone" and not is_organic(item_id):
		mi.material_override = Art.mat(chunk_color, true)   # ore and gems shimmer
	if item_id == "rabbit_pelt":
		mi.scale = Vector3(1.3, 0.35, 1.3)   # a flat furry rug
	add_child(mi)
	if item_id != "stone" and not is_organic(item_id):
		var sp := FX.emitter(self, chunk_color.lightened(0.5), 4, 0.9, 0.05, Vector3(0.15, 0.1, 0.15), Vector3(0, 0.4, 0), true, "sphere")
		sp.emitting = true
	if item_id == "gem":
		var glow := OmniLight3D.new()
		glow.light_color = chunk_color
		glow.light_energy = 0.8
		glow.omni_range = 2.5
		add_child(glow)


## Keeps the soft contact shadow glued to the ground below, shrinking and fading as the item flies.
func _update_shadow() -> void:
	if _shadow == null:
		return
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -6, 0))
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_shadow.visible = false
		return
	_shadow.visible = true
	var h: float = global_position.y - (hit["position"] as Vector3).y
	_shadow.global_position = (hit["position"] as Vector3) + Vector3(0, 0.03, 0)
	_shadow.global_rotation = Vector3.ZERO
	var sh := shadow_for(h)
	_shadow.scale = Vector3(sh.x, 1.0, sh.x)
	(_shadow.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, sh.y)


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
	_update_shadow()
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	var to := pl.global_position + Vector3(0, 0.8, 0) - global_position
	var st := state_for(to.length(), age)
	# Axe in hand: loose logs stay put so you can chop them into planks (walk over one to take it whole).
	if st == "magnet" and wants_chop(item_id, game.current_tool if game != null else -1):
		st = "idle"
	match st:
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
