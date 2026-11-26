class_name VisionCone
extends MeshInstance3D
## A resident's field of view painted on the floor, clipped to the room walls.
## Shown while you sneak or pick a lock nearby, so stealth is something you can read.

const STEPS := 28

var _mat: ShaderMaterial
var _imm := ImmediateMesh.new()
var _fade := 0.0


func _ready() -> void:
	mesh = _imm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scripts/shaders/vision_cone.gdshader")
	material_override = _mat
	visible = false


## Fan rim points around `origin` for a watcher facing `yaw`, clipped to `room`
## (XZ Rect2; an empty Rect2 means no walls). Pure, tested.
static func rim(origin: Vector3, yaw: float, room: Rect2, view_range: float = Witness.RANGE, fov_deg: float = Witness.FOV_DEG) -> PackedVector3Array:
	var out := PackedVector3Array()
	var half := deg_to_rad(fov_deg * 0.5)
	for i in STEPS + 1:
		var a := yaw - half + 2.0 * half * i / STEPS
		var dir := Vector2(sin(a), cos(a))
		var d := view_range
		if room.size != Vector2.ZERO:
			d = Stealth.sight_length(Vector2(origin.x, origin.z), dir, room, view_range)
		out.append(Vector3(origin.x + dir.x * d, origin.y, origin.z + dir.y * d))
	return out


func refresh(delta: float, wanted: bool, origin: Vector3, yaw: float, room: Rect2, tint: Color, alert: float) -> void:
	_fade = move_toward(_fade, 1.0 if wanted else 0.0, delta * 4.0)
	visible = _fade > 0.01
	if not visible:
		return
	var floor_y := origin.y + 0.06
	var o := Vector3(origin.x, floor_y, origin.z)
	var pts := rim(o, yaw, room)
	global_transform = Transform3D.IDENTITY
	_imm.clear_surfaces()
	_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STEPS:
		_imm.surface_set_uv(Vector2((i + 0.5) / STEPS, 0.0))
		_imm.surface_add_vertex(o)
		for k in [i, i + 1]:
			_imm.surface_set_uv(Vector2(float(k) / STEPS, o.distance_to(pts[k]) / Witness.RANGE))
			_imm.surface_add_vertex(pts[k])
	_imm.surface_end()
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("strength", _fade)
	_mat.set_shader_parameter("alert", alert)
