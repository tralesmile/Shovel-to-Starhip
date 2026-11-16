extends SceneTree
## QA helper: prints the size of every imported model and saves a lineup screenshot.
## Run: godot --path . --script res://tests/preview_assets.gd -- <out.png>

func _initialize() -> void:
	_run.call_deferred()


static func aabb_of(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/lineup.png"
	var world := Node3D.new()
	root.add_child(world)
	var files: Array[String] = []
	for dir in ["res://assets/kaykit_medieval", "res://assets/kaykit_city", "res://assets/kaykit_characters", "res://assets/kaykit_restaurant", "res://assets/kaykit_space", "res://assets/kenney"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gltf") or f.ends_with(".glb"):
				files.append(dir.path_join(f))
	var x := 0.0
	var row := 0
	var col := 0
	for f in files:
		var scene: PackedScene = load(f)
		if scene == null:
			print("FAILED ", f)
			continue
		var inst := scene.instantiate()
		world.add_child(inst)
		var b := aabb_of(inst)
		print("%-60s size %s" % [f.get_file(), str(b.size.snapped(Vector3(0.01, 0.01, 0.01)))])
		inst.position = Vector3(col * 6.0, 0, row * 6.0)
		col += 1
		if col >= 12:
			col = 0
			row += 1
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(33, 45, 60)
	cam.look_at(Vector3(33, 0, 25))
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.6, 0)
	world.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.7, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	we.environment = env
	world.add_child(we)
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
