class_name CrackedWall
extends Interactable
## A weak patch of rock with gold light leaking through the cracks. Pickaxes bounce off;
## a Boom Turnip blows it into tumbling physics boulders. Stays open once blown (saved).

const WIDTH := 6.0
const HEIGHT := 6.0
const RUBBLE := 14
const RUBBLE_LIFE := 7.0

var broken := false
var _visual: Node3D
var _body: StaticBody3D


func _ready() -> void:
	add_to_group("blastable")
	add_to_group("saveable")
	interact_radius = 2.2
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	_visual = Node3D.new()
	add_child(_visual)
	for ix in 4:
		for iy in 4:
			var rock := MineCave.boulder(0.85, Color(0.5, 0.4, 0.33).darkened(rng.randf() * 0.2), rng)
			rock.scale.x *= 0.6
			rock.position = Vector3(0, 0.6 + iy * 1.45, -2.25 + ix * 1.5)
			_visual.add_child(rock)
	# A forked zig-zag of glowing cracks on the cave side (joined segments).
	var trunk := [Vector2(-0.1, 4.3), Vector2(0.35, 3.55), Vector2(-0.15, 3.0), Vector2(0.2, 2.2), Vector2(-0.25, 1.6), Vector2(0.1, 0.7), Vector2(-0.05, 0.1)]
	var branches := [[trunk[2], Vector2(-0.9, 2.6), Vector2(-1.3, 1.9)], [trunk[3], Vector2(0.95, 1.9), Vector2(1.2, 1.1)], [trunk[1], Vector2(1.0, 3.8)]]
	_crack_line(trunk, 0.09)
	for br in branches:
		_crack_line(br, 0.05)
	_body = MineCave.wall_body(self, Vector3(1.2, HEIGHT, WIDTH), Vector3(0, HEIGHT / 2.0, 0))


## Glowing polyline on the wall face; points are (z, y).
func _crack_line(pts: Array, width: float) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := b - a
		var seg := Art.box(Vector3(0.05, d.length() + width * 0.5, width), Color(1.0, 0.8, 0.35))
		seg.material_override = Art.mat(Color(1.0, 0.8, 0.35), true)
		seg.rotation.x = atan2(d.x, d.y)
		seg.position = Vector3(0.82, (a.y + b.y) * 0.5, (a.x + b.x) * 0.5)
		_visual.add_child(seg)


func get_prompt(_game: GameState) -> String:
	if broken:
		return ""
	return "A cracked wall. Gold light leaks through... [B] throw a Boom Turnip"


func interact(game: GameState) -> void:
	if not broken:
		game.say("You tap it. It sounds hollow, and a little smug. Only a Boom Turnip will do.")


## Pure (tested): does a blast at distance `d` from the wall's centre line open it?
static func blast_opens(d: float, radius: float) -> bool:
	return d <= radius


## Distance from a world point to the wall slab (not just its centre), so edge hits count.
func blast_distance(p: Vector3) -> float:
	var local := p - global_position
	var dz := maxf(0.0, absf(local.z) - WIDTH / 2.0)
	var dy := maxf(0.0, local.y - HEIGHT)
	return Vector3(maxf(0.0, absf(local.x) - 0.6), dy, dz).length()


func blast(game: GameState, from: Vector3) -> bool:
	if broken:
		return false
	broken = true
	_apply_state()
	_spawn_rubble(from)
	FX.burst(self, global_position + Vector3(0, 2.0, 0), Color(1.0, 0.8, 0.35), 30, 0.12, 6.0, -8.0, "box", 180.0)
	game.say("THE WALL GIVES WAY! Gran had a secret pocket!")
	return true


## Real rigid-body boulders tumble away from the blast, then sink out of the world.
func _spawn_rubble(from: Vector3) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var away := signf(global_position.x - from.x)
	if away == 0.0:
		away = -1.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in RUBBLE:
		var rb := RigidBody3D.new()
		rb.mass = 3.0
		var rad := rng.randf_range(0.28, 0.5)
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = rad * 0.8
		cs.shape = sph
		rb.add_child(cs)
		rb.add_child(MineCave.boulder(rad, Color(0.5, 0.4, 0.33).darkened(rng.randf() * 0.25), rng))
		rb.add_to_group("rubble")
		host.add_child(rb)
		rb.global_position = global_position + Vector3(rng.randf_range(-0.2, 0.2), 0.6 + (i % 4) * 1.2, -2.0 + (i % 5))
		rb.apply_central_impulse(Vector3(away * rng.randf_range(3.0, 8.0), rng.randf_range(1.0, 5.0), rng.randf_range(-2.5, 2.5)) * rb.mass)
		rb.apply_torque_impulse(Vector3(rng.randf(), rng.randf(), rng.randf()) * 3.0)
		var tw := rb.create_tween()
		tw.tween_interval(RUBBLE_LIFE + rng.randf())
		tw.tween_property(rb.get_child(1), "scale", Vector3.ONE * 0.05, 0.6)
		tw.tween_callback(rb.queue_free)


func _apply_state() -> void:
	if _visual != null:
		_visual.visible = not broken
	if _body != null:
		_body.process_mode = Node.PROCESS_MODE_DISABLED if broken else Node.PROCESS_MODE_INHERIT
	if broken:
		remove_from_group("interactable")
	elif is_inside_tree():
		add_to_group("interactable")


func to_dict() -> Dictionary:
	return {"broken": broken}


func from_dict(d: Dictionary) -> void:
	broken = bool(d.get("broken", false))
	_apply_state()
