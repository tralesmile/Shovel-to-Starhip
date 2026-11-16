class_name Terrain
extends StaticBody3D
## Low-poly heightmap ground. Flat inside the play area, gentle hills outside,
## a river valley along the west, a pond south-west of the farm.
## height_at() is the single source of truth, used to place every object.

const SIZE := 260.0            ## metres across
const STEP := 2.0              ## metres per grid cell
const FLAT_RADIUS := 56.0      ## everything closer than this is flat
const BLEND := 26.0            ## metres over which hills fade in

const POND_CENTER := Vector2(-27.0, 1.0)
const POND_RADIUS := 6.0
const RIVER_X := -66.0         ## river runs north-south at this x
const RIVER_HALF := 6.0
const WATER_LEVEL := -0.9

static var _noise: FastNoiseLite


static func noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 1234
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.012
		_noise.fractal_octaves = 3
	return _noise


static func height_at(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var hills: float = noise().get_noise_2d(x, z) * 9.0 + noise().get_noise_2d(x * 3.0 + 50.0, z * 3.0) * 1.2
	var blend: float = clamp((d - FLAT_RADIUS) / BLEND, 0.0, 1.0)
	blend = blend * blend * (3.0 - 2.0 * blend)
	var h := hills * blend
	# River valley: a smooth trench along RIVER_X.
	var rd: float = abs(x - RIVER_X + sin(z * 0.06) * 5.0)
	var river: float = 1.0 - clamp((rd - RIVER_HALF) / 10.0, 0.0, 1.0)
	river = river * river * (3.0 - 2.0 * river)
	h = lerp(h, -2.4, river)
	# Pond bowl.
	var pd := (Vector2(x, z) - POND_CENTER).length()
	var pond: float = 1.0 - clamp((pd - POND_RADIUS) / 4.0, 0.0, 1.0)
	pond = pond * pond * (3.0 - 2.0 * pond)
	h = lerp(h, -2.2, pond)
	return h


static func is_water(x: float, z: float) -> bool:
	return height_at(x, z) < WATER_LEVEL - 0.15


func _ready() -> void:
	name = "Terrain"
	var n := int(SIZE / STEP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := SIZE / 2.0
	var verts: Array[Vector3] = []
	for j in n + 1:
		for i in n + 1:
			var x := -half + i * STEP
			var z := -half + j * STEP
			verts.append(Vector3(x, height_at(x, z), z))
	# Flat-shaded triangles (each gets its own vertices) for the low-poly look.
	var data := PackedVector3Array()
	for j in n:
		for i in n:
			var a := verts[j * (n + 1) + i]
			var b := verts[j * (n + 1) + i + 1]
			var c := verts[(j + 1) * (n + 1) + i]
			var d := verts[(j + 1) * (n + 1) + i + 1]
			var tris: Array = [a, c, b, b, c, d] if (i + j) % 2 == 0 else [a, d, b, a, c, d]
			_tri(st, tris[0], tris[1], tris[2])
			_tri(st, tris[3], tris[4], tris[5])
			for v in tris:
				data.append(v)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/ground.gdshader")
	mi.material_override = sm
	add_child(mi)
	var shape := CollisionShape3D.new()
	var cp := ConcavePolygonShape3D.new()
	cp.set_faces(data)
	cp.backface_collision = true
	shape.shape = cp
	add_child(shape)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	# Godot treats clockwise triangles as front faces, so emit a, c, b.
	st.set_normal(nrm)
	st.add_vertex(a)
	st.set_normal(nrm)
	st.add_vertex(c)
	st.set_normal(nrm)
	st.add_vertex(b)
