class_name ScarecrowSpot
extends Interactable
## The Scarecrow build piece. It keeps the goose off every crop within REACH, wobbles on its
## pole when you brush past, and E changes its outfit (saved with your house).

const REACH := 3.4      ## one in the middle covers all but the four corner plots
const CLOTH := preload("res://scripts/shaders/plaid.gdshader")
const BURLAP := Color(0.82, 0.68, 0.43)
const STRAW := Color(0.97, 0.8, 0.28)
## name, hat style, shirt, check stripe, hat colour
const OUTFITS := [
	["Straw Stan", "straw", Color(0.78, 0.22, 0.18), Color(0.98, 0.84, 0.6), Color(0.93, 0.76, 0.32)],
	["Sir Reginald", "tophat", Color(0.2, 0.22, 0.34), Color(0.55, 0.5, 0.75), Color(0.12, 0.11, 0.14)],
	["Captain Beaky-Bane", "pirate", Color(0.9, 0.88, 0.82), Color(0.72, 0.16, 0.16), Color(0.14, 0.12, 0.12)],
	["Wizard Wanda", "wizard", Color(0.38, 0.2, 0.62), Color(0.95, 0.8, 0.35), Color(0.3, 0.16, 0.55)],
	["Astro Ada", "space", Color(0.92, 0.93, 0.96), Color(0.95, 0.5, 0.15), Color(0.7, 0.88, 1.0)],
]

var outfit := 0
var body: Node3D          ## everything above the foot of the pole; this is what wobbles
var _dress: Node3D
var _tilt := Vector2.ZERO
var _vel := Vector2.ZERO
var _spin := 0.0
var _ring: MeshInstance3D
var _ring_t := 0.0


## Pure (tested): the next outfit in the wardrobe.
static func next_outfit(i: int) -> int:
	return posmod(i + 1, OUTFITS.size())


## Pure (tested): can a scarecrow standing at `at` see off a goose at `plot`?
static func covers(at: Vector3, plot: Vector3) -> bool:
	return Vector2(at.x - plot.x, at.z - plot.z).length() <= REACH


static func guards(tree: SceneTree, plot: Vector3) -> bool:
	for n in tree.get_nodes_in_group("scarecrow"):
		if not n.is_queued_for_deletion() and covers((n as Node3D).global_position, plot):
			return true
	return false


static func nearest(tree: SceneTree, to: Vector3) -> Node3D:
	var best: Node3D = null
	for n in tree.get_nodes_in_group("scarecrow"):
		var s := n as Node3D
		if best == null or s.global_position.distance_to(to) < best.global_position.distance_to(to):
			best = s
	return best


## A glowing circle on the ground showing how far something reaches.
static func reach_ring(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2.ONE * (radius * 2.0 + 0.3)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/reach_ring.gdshader")
	m.set_shader_parameter("ring_color", color)
	m.set_shader_parameter("radius", radius / (radius + 0.15))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.2
	return mi


func _ready() -> void:
	add_to_group("scarecrow")
	body = Node3D.new()
	add_child(body)
	var wood := Color(0.5, 0.33, 0.19)
	_part(body, Art.cylinder(0.055, 0.075, 1.5, wood, 7), Vector3(0, 0.75, 0))
	_dress = Node3D.new()
	body.add_child(_dress)
	_ring = reach_ring(REACH, Color(1.0, 0.82, 0.3))
	_ring.visible = false
	add_child(_ring)
	set_outfit(outfit)


func _part(parent: Node3D, mi: MeshInstance3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cloth(parent: Node3D, size: Vector3, pos: Vector3, base: Color, stripe: Color, flutter: float, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	m.subdivide_height = 4
	m.subdivide_width = 4
	mi.mesh = m
	var sm := ShaderMaterial.new()
	sm.shader = CLOTH
	sm.set_shader_parameter("base", base)
	sm.set_shader_parameter("stripe", stripe)
	sm.set_shader_parameter("flutter", flutter)
	sm.set_shader_parameter("half_height", size.y * 0.5)
	mi.material_override = sm
	_part(parent, mi, pos, rot)


func _straw(parent: Node3D, at: Vector3, toward: Vector3, count: int) -> void:
	for k in count:
		var spread := Vector3(sin(k * 2.4), cos(k * 3.7), sin(k * 5.1)) * 0.45
		var dir := (toward + spread).normalized()
		var blade := Art.cylinder(0.0, 0.016, 0.22, STRAW.darkened(0.12 * (k % 3)), 4)
		var side := Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.BACK
		var z := side.cross(dir).normalized()
		blade.transform = Transform3D(Basis(dir.cross(z).normalized(), dir, z), at + dir * 0.1)
		parent.add_child(blade)


func set_outfit(i: int) -> void:
	outfit = posmod(i, OUTFITS.size())
	if _dress == null:
		return
	for c in _dress.get_children():
		_dress.remove_child(c)
		c.queue_free()
	var o: Array = OUTFITS[outfit]
	var shirt: Color = o[2]
	var stripe: Color = o[3]
	var hat: Color = o[4]
	_cloth(_dress, Vector3(0.46, 0.52, 0.26), Vector3(0, 1.05, 0), shirt, stripe, 0.012)
	_cloth(_dress, Vector3(0.5, 0.22, 0.24), Vector3(0, 0.72, 0), shirt.darkened(0.2), stripe.darkened(0.2), 0.07)
	for sx in [-1.0, 1.0]:
		_cloth(_dress, Vector3(0.5, 0.17, 0.17), Vector3(sx * 0.44, 1.22, 0), shirt, stripe, 0.015, Vector3(0, 0, sx * -0.1))
		_cloth(_dress, Vector3(0.12, 0.26, 0.04), Vector3(sx * 0.62, 1.05, 0), shirt, stripe, 0.09)
		_straw(_dress, Vector3(sx * 0.68, 1.19, 0), Vector3(sx, -0.25, 0), 9)
	_straw(_dress, Vector3(0, 0.66, 0.02), Vector3.DOWN, 12)
	_straw(_dress, Vector3(0, 1.32, 0.02), Vector3(0, -0.2, 1), 7)
	_part(_dress, Art.box(Vector3(0.12, 0.12, 0.02), stripe.darkened(0.25)), Vector3(0.1, 0.98, 0.137), Vector3(0, 0, 0.25))
	# Sack head with button eyes and a stitched grin.
	_part(_dress, Art.sphere(0.23, BURLAP, 9, 14), Vector3(0, 1.55, 0))
	_part(_dress, Art.cylinder(0.12, 0.15, 0.07, BURLAP.darkened(0.3), 10), Vector3(0, 1.35, 0))
	var ink := Color(0.13, 0.09, 0.07)
	for sx2 in [-1.0, 1.0]:
		_part(_dress, Art.cylinder(0.045, 0.045, 0.025, ink, 10), Vector3(sx2 * 0.085, 1.59, 0.212), Vector3(PI / 2, 0, 0))
	for k in 5:
		var x := -0.1 + k * 0.05
		var y := 1.475 + x * x * 2.6
		_part(_dress, Art.box(Vector3(0.014, 0.05, 0.014), ink), Vector3(x, y, 0.222), Vector3(0, 0, x * 3.0))
	_part(_dress, Art.cylinder(0.0, 0.03, 0.12, Color(0.95, 0.5, 0.12), 6), Vector3(0, 1.53, 0.27), Vector3(PI / 2, 0, 0))
	match str(o[1]):
		"straw":
			_part(_dress, Art.cylinder(0.38, 0.4, 0.035, hat, 14), Vector3(0, 1.72, 0))
			_part(_dress, Art.cylinder(0.16, 0.21, 0.19, hat, 12), Vector3(0, 1.83, 0))
			_part(_dress, Art.cylinder(0.205, 0.215, 0.05, shirt, 12), Vector3(0, 1.76, 0))
		"tophat":
			_part(_dress, Art.cylinder(0.29, 0.29, 0.03, hat, 14), Vector3(0, 1.73, 0))
			_part(_dress, Art.cylinder(0.18, 0.17, 0.36, hat, 14), Vector3(0, 1.92, 0), Vector3(0, 0, 0.1))
			_part(_dress, Art.cylinder(0.183, 0.18, 0.06, stripe, 14), Vector3(0, 1.79, 0))
		"pirate":
			_part(_dress, Art.sphere(0.25, hat, 7, 12), Vector3(0, 1.74, -0.02)).scale = Vector3(1.35, 0.55, 0.75)
			_part(_dress, Art.sphere(0.05, Color(0.95, 0.95, 0.9), 4, 8), Vector3(0, 1.76, 0.18))
			_part(_dress, Art.cylinder(0.06, 0.06, 0.02, ink, 10), Vector3(0.085, 1.59, 0.226), Vector3(PI / 2, 0, 0))
			_part(_dress, Art.box(Vector3(0.44, 0.022, 0.022), ink), Vector3(0, 1.61, 0.215), Vector3(0, 0, 0.18))
		"wizard":
			_part(_dress, Art.cylinder(0.34, 0.36, 0.03, hat, 14), Vector3(0, 1.71, 0))
			_part(_dress, Art.cylinder(0.08, 0.21, 0.34, hat, 12), Vector3(0, 1.88, 0))
			_part(_dress, Art.cylinder(0.0, 0.082, 0.22, hat, 12), Vector3(0.05, 2.12, 0), Vector3(0, 0, -0.42))
			for k2 in 3:
				var star := Art.box(Vector3.ONE * 0.045, stripe)
				star.material_override = Art.mat(stripe, true)
				_part(_dress, star, Vector3(-0.1 + k2 * 0.1, 1.78 + 0.07 * k2, 0.19 - 0.025 * k2), Vector3(0, 0, PI / 4))
		"space":
			var glass := Art.sphere(0.34, hat, 12, 18)
			var gm := StandardMaterial3D.new()
			gm.albedo_color = Color(hat.r, hat.g, hat.b, 0.2)
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gm.roughness = 0.05
			gm.metallic = 0.4
			gm.rim_enabled = true
			glass.material_override = gm
			_part(_dress, glass, Vector3(0, 1.6, 0))
			_part(_dress, Art.cylinder(0.25, 0.27, 0.07, stripe, 16), Vector3(0, 1.34, 0))
			_part(_dress, Art.cylinder(0.012, 0.012, 0.2, Color(0.6, 0.62, 0.66), 5), Vector3(0.17, 1.99, 0))
			_part(_dress, Art.sphere(0.04, stripe, 4, 8), Vector3(0.17, 2.1, 0))


func get_prompt(_game: GameState) -> String:
	return "[E] Change %s's outfit" % OUTFITS[outfit][0]


func interact(game: GameState) -> void:
	set_outfit(next_outfit(outfit))
	_spin = TAU
	show_reach(2.5)
	Sfx.play_on(self, "swish", 1.1)
	if is_inside_tree():
		FX.burst(self, global_position + Vector3(0, 1.3, 0), STRAW, 16, 0.07, 2.4, -5.0, "box", 150.0)
	var piece := get_parent() as BuildPiece
	if piece != null and piece.get_parent() is BuildWorld:
		(piece.get_parent() as BuildWorld).save_tint(piece, outfit, game)
	game.say("Meet %s. The ring shows what's guarded." % OUTFITS[outfit][0])


func show_reach(seconds: float) -> void:
	_ring_t = seconds


## A goose is looking: spin round like you mean it.
func shoo() -> void:
	_spin = TAU * 2.0
	show_reach(3.0)
	Sfx.play_on(self, "swish", 0.8)


func _process(delta: float) -> void:
	_ring_t -= delta
	_ring.visible = _ring_t > 0.0
	if _spin > 0.0:
		var step := minf(_spin, delta * (4.0 + _spin * 2.2))
		_spin -= step
		body.rotate_y(step)
	var pl := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if pl != null:
		var off := Vector2(global_position.x - pl.global_position.x, global_position.z - pl.global_position.z)
		var spd := Vector2(pl.velocity.x, pl.velocity.z).length()
		if spd > 1.0 and off.length() < 0.95 and _vel.length() < 0.9:
			var away := global_basis.inverse() * Vector3(off.x, 0, off.y).normalized()
			_vel += Vector2(away.z, -away.x) * clampf(spd * 0.3, 0.5, 2.4)
			Sfx.play_on(self, "rustle", 0.75)
	var r := FarmPlot.spring_step(_tilt, _vel, delta)
	_tilt = r[0]
	_vel = r[1]
	var yaw := body.rotation.y
	body.rotation = Vector3(_tilt.x, yaw, _tilt.y)
