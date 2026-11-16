class_name Toon
extends RefCounted
## Converts imported model materials to the cartoon shader + outline pass.
## Materials are cached so identical sources share one converted material.

const TOON := preload("res://scripts/shaders/toon.gdshader")
const OUTLINE := preload("res://scripts/shaders/outline.gdshader")

static var enabled := true
static var outlines := true
static var _cache: Dictionary = {}
## Materials whose windows glow at night (houses, shops).
static var window_materials: Array[ShaderMaterial] = []


## Convert every mesh under node. wind > 0 makes it sway; windows = night glow.
static func apply(node: Node, wind: float = 0.0, windows: bool = false, outline: bool = true) -> void:
	if not enabled:
		return
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		if mi.material_override != null:
			mi.material_override = to_toon(mi.material_override, wind, windows, outline)
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			if src:
				mi.set_surface_override_material(s, to_toon(src, wind, windows, outline))


static func to_toon(src: Material, wind: float = 0.0, windows: bool = false, outline: bool = true) -> Material:
	if src is ShaderMaterial and (src as ShaderMaterial).shader == TOON:
		return src
	var key := "%d_%s_%s_%s" % [src.get_instance_id(), wind, windows, outline]
	if _cache.has(key):
		return _cache[key]
	var sm := ShaderMaterial.new()
	sm.shader = TOON
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		sm.set_shader_parameter("albedo_color", b.albedo_color)
		if b.albedo_texture:
			sm.set_shader_parameter("albedo_tex", b.albedo_texture)
			sm.set_shader_parameter("use_tex", true)
		sm.set_shader_parameter("use_vertex_color", b.vertex_color_use_as_albedo)
		if b.emission_enabled:
			sm.set_shader_parameter("emission_color", b.emission)
			sm.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
	sm.set_shader_parameter("wind", wind)
	if outline and outlines:
		sm.next_pass = outline_material(wind)
	if windows:
		window_materials.append(sm)
	_cache[key] = sm
	return sm


static func outline_material(wind: float) -> ShaderMaterial:
	var key := "outline_%s" % wind
	if _cache.has(key):
		return _cache[key]
	var o := ShaderMaterial.new()
	o.shader = OUTLINE
	o.set_shader_parameter("wind", wind)
	_cache[key] = o
	return o


## Plain coloured toon material (for code-built shapes).
static func color(c: Color, emissive: bool = false, outline: bool = true) -> ShaderMaterial:
	var key := "col_%s_%s_%s" % [c.to_html(), emissive, outline]
	if _cache.has(key):
		return _cache[key]
	var sm := ShaderMaterial.new()
	sm.shader = TOON
	sm.set_shader_parameter("albedo_color", c)
	if emissive:
		sm.set_shader_parameter("emission_color", Vector3(c.r, c.g, c.b))
		sm.set_shader_parameter("emission_energy", 0.6)
	if outline and outlines:
		sm.next_pass = outline_material(0.0)
	_cache[key] = sm
	return sm


static func set_night(amount: float) -> void:
	for m in window_materials:
		m.set_shader_parameter("window_glow", amount)
