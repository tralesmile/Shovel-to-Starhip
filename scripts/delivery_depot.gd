class_name DeliveryDepot
extends Interactable
## Parcel Pete's depot. Needs a car (the timer is tight!). Take a parcel, drive to the
## glowing beacon (car or on foot) before time runs out.

var job := DeliveryJob.new()
var beacon: Node3D = null
var next_index: int = 0


func get_prompt(game: GameState) -> String:
	if job.active:
		return "Parcel Pete: \"Still here? Deliver to %s! (%ds)\"" % [job.dest_name(), int(job.time_left)]
	if not game.car_owned:
		return "Parcel Pete: \"No car, no parcels. Policy.\""
	return "[E] Take a parcel job"


func interact(game: GameState) -> void:
	if job.active or not game.car_owned:
		return
	next_index = (next_index + game.day) % DeliveryJob.DESTINATIONS.size()
	job.start(next_index, Vector2(global_position.x, global_position.z))
	next_index += 1
	_place_beacon()
	game.say("Parcel for %s. You have %ds. It ticks. Parcels do not normally tick." % [job.dest_name(), int(job.time_left)])


func _place_beacon() -> void:
	if beacon == null:
		beacon = Node3D.new()
		beacon.top_level = true
		add_child(beacon)
		var m := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.6
		cyl.bottom_radius = 0.6
		cyl.height = 14.0
		m.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.85, 0.2, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.mesh.material = mat
		m.position.y = 7.0
		beacon.add_child(m)
	var p := job.dest_pos()
	beacon.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
	beacon.visible = true


func _process(delta: float) -> void:
	if not job.active:
		if beacon and beacon.visible:
			beacon.visible = false
		return
	var game: GameState = get_node_or_null("/root/Game")
	if game == null:
		return
	if job.tick(delta):
		beacon.visible = false
		game.say("Time's up! The parcel ticked away on its own. Pete is 'disappointed'.")
		return
	var who: Node3D = get_tree().get_first_node_in_group("car")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var hit := false
	for n in [who, player]:
		if n and job.is_near(Vector2(n.global_position.x, n.global_position.z)):
			hit = true
	if hit:
		var pay := job.complete()
		beacon.visible = false
		game.earn(pay)
		game.add_reputation(0.5)
		game.say("Delivered! +$%d. The recipient said 'oh, it's you again'." % pay)
