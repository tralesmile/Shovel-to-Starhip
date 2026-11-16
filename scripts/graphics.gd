extends Node
## Graphics quality: Low = OpenGL "Compatibility" renderer (runs anywhere),
## High = Forward+ (Vulkan/D3D12) with ambient occlusion, bounce light, glow
## and volumetric fog. Switching restarts the game, because Godot picks its
## renderer at startup. If Forward+ isn't supported, Godot falls back to Low.

const SETTINGS_PATH := "user://settings.cfg"

var quality: String = "low"


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		quality = str(cfg.get_value("graphics", "quality", "low"))
	if _automation():
		return
	var want := "forward_plus" if quality == "high" else "gl_compatibility"
	if current_method() != want and not "--relaunched" in OS.get_cmdline_user_args():
		_relaunch(want)


func current_method() -> String:
	return RenderingServer.get_current_rendering_method()


func is_high() -> bool:
	return current_method() == "forward_plus"


func label() -> String:
	if quality == "high" and not is_high():
		return "High (not supported on this PC, using Low)"
	return "High" if is_high() else "Low"


func toggle() -> void:
	quality = "low" if quality == "high" else "high"
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("graphics", "quality", quality)
	cfg.save(SETTINGS_PATH)
	_relaunch("forward_plus" if quality == "high" else "gl_compatibility")


func _relaunch(method: String) -> void:
	if OS.has_feature("editor") or _automation():
		return
	if Engine.has_singleton("Game") or get_node_or_null("/root/Game"):
		get_node("/root/Game").save_game()
	OS.create_process(OS.get_executable_path(), ["--rendering-method", method, "--", "--relaunched"])
	get_tree().quit()


func _automation() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots") or a.begins_with("--noboot"):
			return true
	return false


## Extra effects that only exist on Forward+.
func apply_high(env: Environment, sun: DirectionalLight3D) -> void:
	if not is_high():
		return
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.ssil_intensity = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.9, 0.92, 1.0)
	env.volumetric_fog_length = 80.0
	sun.light_volumetric_fog_energy = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.0
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
