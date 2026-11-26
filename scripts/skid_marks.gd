class_name SkidMarks
extends MultiMeshInstance3D
## Tyre marks: a ring buffer of flat quads on the ground that fade out. One MultiMesh, so
## hundreds of marks cost a single draw call.

const CAPACITY := 700
const LIFE := 16.0
const FADE := 6.0
const WIDTH := 0.28
const RUBBER := Color(0.06, 0.06, 0.08, 0.7)
const DIRT := Color(0.34, 0.22, 0.12, 0.65)

var _born := PackedFloat32Array()
var _base: Array[Color] = []
var _next := 0
var _clock := 0.0
var _refresh := 0.0
var used := 0


## Pure (tested): opacity multiplier for a mark `age` seconds old.
static func alpha_for(age: float) -> float:
	return clampf((LIFE - age) / FADE, 0.0, 1.0)


func _init() -> void:
	top_level = true
	var quad := PlaneMesh.new()
	quad.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Instances are scattered all over the map: never cull the whole batch by a stale box.
	custom_aabb = AABB(Vector3(-140, -5, -140), Vector3(280, 30, 280))
	_born.resize(CAPACITY)
	_base.resize(CAPACITY)


## Lay a strip of rubber from a to b.
func add_segment(a: Vector3, b: Vector3, color: Color) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.02 or length > 3.0:
		return   # standing still, or a teleport
	var z := d / length
	var x := Vector3.UP.cross(z).normalized()
	var basis_ := Basis(x * WIDTH, z.cross(x), z * (length + 0.04))
	multimesh.set_instance_transform(_next, Transform3D(basis_, (a + b) * 0.5))
	multimesh.set_instance_color(_next, color)
	_born[_next] = _clock
	_base[_next] = color
	_next = (_next + 1) % CAPACITY
	used = mini(used + 1, CAPACITY)
	multimesh.visible_instance_count = used


func _process(delta: float) -> void:
	_clock += delta
	_refresh -= delta
	if _refresh > 0.0 or used == 0:
		return
	_refresh = 0.25
	for i in used:
		var age := _clock - _born[i]
		if age > LIFE - FADE:
			var c := _base[i]
			c.a *= alpha_for(age)
			multimesh.set_instance_color(i, c)
