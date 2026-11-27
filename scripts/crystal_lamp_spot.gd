class_name CrystalLampSpot
extends Interactable
## The Crystal Lamp build piece: Glow Crystals from Gran's Mine on a stone foot. E retunes the
## colour (saved with your house), and it brightens as it gets dark.

const TINTS := [
	["Sky blue", Color(0.35, 0.82, 1.0)], ["Amethyst", Color(0.74, 0.45, 1.0)], ["Minty", Color(0.35, 1.0, 0.62)],
	["Sunset", Color(1.0, 0.62, 0.25)], ["Bubblegum", Color(1.0, 0.45, 0.72)],
]

var tint := 0
var _crystals: Node3D
var _light: OmniLight3D
var _halo: ShaderMaterial
var _t := 0.0


## Pure (tested): the colour after this one.
static func next_tint(i: int) -> int:
	return posmod(i + 1, TINTS.size())


static func tint_color(i: int) -> Color:
	return TINTS[posmod(i, TINTS.size())][1]


func _ready() -> void:
	var foot := MeshInstance3D.new()
	foot.mesh = RockMesh.lump_mesh(Vector3(0.34, 0.2, 0.34), Vector3(0, 0.15, 0), 31, 1, RockMesh.UV_SKIN)
	foot.material_override = MineRock.rock_material("", false, false)
	add_child(foot)
	var collar := Art.cylinder(0.17, 0.2, 0.1, Color(0.88, 0.55, 0.3), 8)
	collar.position.y = 0.34
	add_child(collar)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.7, 1.7)
	halo.mesh = q
	_halo = ShaderMaterial.new()
	_halo.shader = load("res://scripts/shaders/glow_halo.gdshader")
	halo.material_override = _halo
	halo.position.y = 0.75
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	_light = OmniLight3D.new()
	_light.omni_range = 7.0
	_light.position.y = 1.0
	add_child(_light)
	set_tint(tint)


func set_tint(i: int) -> void:
	tint = posmod(i, TINTS.size())
	if _light == null:
		return
	if _crystals != null:
		_crystals.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	_crystals = MineCave.crystal_cluster(tint_color(tint), 6, 0.62, rng)
	_crystals.position.y = 0.36
	add_child(_crystals)
	_light.light_color = tint_color(tint)
	_halo.set_shader_parameter("glow_color", tint_color(tint))


func get_prompt(_game: GameState) -> String:
	return "[E] Retune the Crystal Lamp (%s)" % TINTS[tint][0]


func interact(game: GameState) -> void:
	set_tint(next_tint(tint))
	_crystals.scale = Vector3(1.3, 0.6, 1.3)
	var tw := _crystals.create_tween()
	tw.tween_property(_crystals, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play_on(self, "chime", 0.7 + 0.12 * tint)
	if is_inside_tree():
		FX.burst(self, global_position + Vector3(0, 0.8, 0), tint_color(tint), 14, 0.05, 2.4, -2.0, "sphere", 140.0, true)
	var piece := get_parent() as BuildPiece
	if piece != null and piece.get_parent() is BuildWorld:
		(piece.get_parent() as BuildWorld).save_tint(piece, tint, game)
	game.say("%s. Gran would approve." % TINTS[tint][0])


func _process(delta: float) -> void:
	_t += delta
	var game := get_node_or_null("/root/Game") as GameState
	var d := FireflyJar.darkness(game.time_of_day) if game != null else 1.0
	var pulse := 0.9 + 0.1 * sin(_t * 1.8)
	_light.light_energy = 2.6 * d * pulse
	_halo.set_shader_parameter("strength", 0.55 * d * pulse)
