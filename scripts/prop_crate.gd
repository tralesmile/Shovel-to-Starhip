class_name PropCrate
extends RigidBody3D
## A shove-able physics prop (crate or barrel). Walk into it to push it around; swing the axe or
## pickaxe at it ([E]) to smash it into plank pickups plus a funny bit of loot.

const HITS_TO_SMASH := 2
const WOOD := Color(0.74, 0.52, 0.3)

var kind := "crate"   ## "crate" or "barrel"
var hits := 0
var game: GameState
var _mesh: Node3D
var _wobble := 0.0
var _smashed := false


## Pure (tested): loot table. roll in 0..1 -> items popped out besides the planks.
static func loot_for(roll: float) -> Array:
	if roll < 0.35:
		return []
	if roll < 0.65:
		return [{"item": "turnip_seed", "amount": 2}]
	if roll < 0.85:
		return [{"item": "wood", "amount": 1}]
	if roll < 0.96:
		return [{"item": "copper_ore", "amount": 1}]
	return [{"item": "gem", "amount": 1}]


## Pure (tested): planks a smash yields (barrels are thinner).
static func planks_for(k: String) -> int:
	return 2 if k == "barrel" else 3


## Pure (tested): impulse magnitude when the player walks into a body of `mass`.
static func push_strength(mass_kg: float, player_speed: float) -> float:
	return clampf(player_speed, 0.0, 8.0) * 0.9 * clampf(3.0 / maxf(mass_kg, 0.5), 0.3, 1.5)


func _ready() -> void:
	add_to_group("smashable")
	mass = 6.0 if kind == "crate" else 5.0
	linear_damp = 1.2
	angular_damp = 3.0
	var phys := PhysicsMaterial.new()
	phys.friction = 0.9
	phys.bounce = 0.15
	physics_material_override = phys
	var cs := CollisionShape3D.new()
	_mesh = Node3D.new()
	add_child(_mesh)
	if kind == "barrel":
		var cy := CylinderShape3D.new()
		cy.radius = 0.4
		cy.height = 0.9
		cs.shape = cy
		cs.position.y = 0.45
		var body := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.38
		cm.bottom_radius = 0.38
		cm.height = 0.9
		cm.radial_segments = 10
		cm.material = Art.mat(WOOD.darkened(0.1), false)
		body.mesh = cm
		body.position.y = 0.45
		_mesh.add_child(body)
		for hy in [0.2, 0.7]:
			var hoop := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.405
			hm.bottom_radius = 0.405
			hm.height = 0.07
			hm.radial_segments = 10
			hm.material = Art.mat(Color(0.35, 0.36, 0.4), false)
			hoop.mesh = hm
			hoop.position.y = hy
			_mesh.add_child(hoop)
	else:
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.8, 0.8, 0.8)
		cs.shape = bs
		cs.position.y = 0.4
		var b := Art.box(Vector3(0.8, 0.8, 0.8), WOOD)
		b.position.y = 0.4
		_mesh.add_child(b)
		# Darker slats on the corners and a lid cross so it reads as a crate.
		for sx in [-0.34, 0.34]:
			var post := Art.box(Vector3(0.12, 0.84, 0.84), WOOD.darkened(0.25))
			post.position = Vector3(sx, 0.4, 0)
			_mesh.add_child(post)
		var lid := Art.box(Vector3(0.84, 0.08, 0.2), WOOD.darkened(0.25))
		lid.position = Vector3(0, 0.82, 0)
		_mesh.add_child(lid)
	add_child(cs)


func _process(delta: float) -> void:
	if _wobble > 0.0 and _mesh != null:
		_wobble = maxf(0.0, _wobble - delta * 5.0)
		_mesh.rotation.z = sin(_wobble * 36.0) * 0.12 * _wobble


func prompt_text() -> String:
	return "[E] Smash %s (%d/%d) - or just shove it" % [kind, hits, HITS_TO_SMASH]


## One swing. Returns true when it smashed.
func smash_hit() -> bool:
	if _smashed:
		return false
	hits += 1
	_wobble = 1.0
	Sfx.play_on(self, "chop", 0.9 + randf() * 0.2)
	FX.burst(self, global_position + Vector3(0, 0.5, 0), WOOD.lightened(0.2), 6, 0.07, 2.8)
	apply_central_impulse(Vector3(randf_range(-1, 1), 1.2, randf_range(-1, 1)) * mass)
	if hits < HITS_TO_SMASH:
		FX.hit_stop(get_tree(), 0.3)
		return false
	_smashed = true
	FX.hit_stop(get_tree(), 0.7)
	var host := get_parent()
	var pos := global_position
	FX.burst(host, pos + Vector3(0, 0.5, 0), WOOD, 16, 0.12, 4.5, -9.0)
	FX.burst(host, pos + Vector3(0, 0.2, 0), Color(0.75, 0.68, 0.55), 8, 0.2, 1.6, -1.0, "sphere", 80.0)
	var drops: Array = []
	for i in planks_for(kind):
		drops.append({"item": "plank", "amount": 1})
	drops.append_array(loot_for(randf()))
	for i in drops.size():
		var d: Dictionary = drops[i]
		var p := WoodLog.new()
		p.game = game
		p.item_id = d["item"]
		p.amount = int(d["amount"])
		if p.item_id == "copper_ore":
			p.chunk_color = Color(0.85, 0.5, 0.28)
		elif p.item_id == "gem":
			p.chunk_color = Color(0.4, 0.9, 1.0)
		elif p.item_id == "turnip_seed":
			p.chunk_color = Color(0.85, 0.8, 0.5)
		host.add_child(p)
		p.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0.4 + i * 0.12, randf_range(-0.25, 0.25))
		p.pop()
	queue_free()
	return true
