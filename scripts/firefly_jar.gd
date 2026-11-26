class_name FireflyJar
extends Node3D
## The glass part of the Firefly Jar build piece: captured fireflies orbit inside, blinking,
## with a halo and a soft light that comes up as it gets dark. No firefly was harmed; they
## have a union.

const MOTES := 7

var _motes: Array[MeshInstance3D] = []
var _halo_mat: ShaderMaterial
var _light: OmniLight3D
var _t := 0.0


## Pure (tested): how brightly the jar shines at this time of day, 0.15 (noon) .. 1 (night).
static func darkness(time_of_day: float) -> float:
	var day := smoothstep(0.22, 0.30, time_of_day) - smoothstep(0.68, 0.78, time_of_day)
	return lerpf(1.0, 0.15, clampf(day, 0.0, 1.0))


func _ready() -> void:
	var glass := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.22
	cm.height = 0.46
	cm.radial_segments = 12
	glass.mesh = cm
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.75, 0.95, 1.0, 0.2)
	gm.roughness = 0.1
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = gm
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	var lid := Art.cylinder(0.17, 0.17, 0.07, Color(0.78, 0.5, 0.25), 12)
	lid.position.y = 0.27
	add_child(lid)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.96, 1.0, 0.5)
	for i in MOTES:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.022
		sm.height = 0.044
		sm.radial_segments = 5
		sm.rings = 3
		m.mesh = sm
		m.material_override = mm
		add_child(m)
		_motes.append(m)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	halo.mesh = q
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = load("res://scripts/shaders/glow_halo.gdshader")
	halo.material_override = _halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.85, 1.0, 0.45)
	_light.omni_range = 6.5
	add_child(_light)
	_process(0.0)


func _process(delta: float) -> void:
	_t += delta
	for i in _motes.size():
		var a := _t * (0.9 + 0.23 * i) + i * 1.7
		_motes[i].position = Vector3(cos(a) * 0.12, sin(_t * (0.6 + 0.17 * i) + i) * 0.16, sin(a * 1.3) * 0.12)
		_motes[i].scale = Vector3.ONE * (0.55 + 0.7 * Bug.blink(_t, i * 2.0))
	var game := get_node_or_null("/root/Game") as GameState
	var d := darkness(game.time_of_day) if game != null else 1.0
	var pulse := 0.85 + 0.15 * sin(_t * 2.1)
	_halo_mat.set_shader_parameter("strength", 0.65 * d * pulse)
	_light.light_energy = 2.2 * d * pulse
