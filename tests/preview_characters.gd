extends SceneTree
## QA helper: close-up of the KayKit characters playing Idle; prints node names and bones.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var world := Node3D.new()
	root.add_child(world)
	var names := ["Barbarian", "Knight", "Mage", "Rogue"]
	for i in names.size():
		var inst: Node3D = load("res://assets/kaykit_characters/%s.glb" % names[i]).instantiate()
		world.add_child(inst)
		inst.position = Vector3(i * 2.2 - 3.3, 0, 0)
		inst.scale = Vector3.ONE * 0.75
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("Walking_A" if i % 2 == 0 else "Idle")
		if i == 0:
			for c in inst.find_children("*", "", true, false):
				var extra := ""
				if c is Skeleton3D:
					var bones := []
					for b in c.get_bone_count():
						bones.append(c.get_bone_name(b))
					extra = " bones=" + str(bones)
				print(c.get_path(), " [", c.get_class(), "]", extra)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 1.6, 6)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	world.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.75, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	we.environment = env
	world.add_child(we)
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
