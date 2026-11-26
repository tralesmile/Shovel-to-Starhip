class_name SprinklerSpot
extends Interactable
## A copper sprinkler (build piece). Dropped on a grid corner it reaches all four plots around it,
## and it waters them every morning. E runs it right now.

const REACH := 1.75          ## plot centres are 1.41 m from a grid corner
const SPRAY_TIME := 7.0
const MORNING_TIME := 25.0

var head: Node3D
var _spray := 0.0
var _jets: Array[CPUParticles3D] = []


func _ready() -> void:
	add_to_group("sprinkler")
	for k in 4:
		var jet := CPUParticles3D.new()
		jet.amount = 26
		jet.lifetime = 0.7
		jet.mesh = FX._mesh("sphere", 0.065, true)
		jet.direction = Vector3(cos(k * PI * 0.5), 1.05, sin(k * PI * 0.5)).normalized()
		jet.spread = 7.0
		jet.initial_velocity_min = 2.3
		jet.initial_velocity_max = 3.0
		jet.gravity = Vector3(0, -9.0, 0)
		jet.color = Color(0.62, 0.86, 1.0)
		jet.local_coords = false
		jet.emitting = false
		jet.position.y = 0.55
		add_child(jet)
		_jets.append(jet)


## Pure (tested): does a sprinkler at `at` reach a plot centred at `plot`?
static func reaches(at: Vector3, plot: Vector3) -> bool:
	return Vector2(at.x - plot.x, at.z - plot.z).length() <= REACH


## Water every tilled plot in reach. Returns how many were dry.
func water_around() -> int:
	var n := 0
	if not is_inside_tree():
		return 0
	for node in get_tree().get_nodes_in_group("farmplot"):
		var p := node as FarmPlot
		if p.state == FarmPlot.State.GRASS or not reaches(global_position, p.global_position):
			continue
		if not p.watered:
			n += 1
			p.watered = true
			p._apply_soil(true)
	return n


func spray(seconds: float) -> void:
	_spray = maxf(_spray, seconds)
	for j in _jets:
		j.emitting = true
	Sfx.play_on(self, "sizzle", 0.55)


## Called by GameState after every plot has had its night.
func morning_spray() -> void:
	water_around()
	spray(MORNING_TIME)


func get_prompt(_game: GameState) -> String:
	return "[E] Run the sprinkler"


func interact(game: GameState) -> void:
	var n := water_around()
	spray(SPRAY_TIME)
	game.say("Pssht-tk-tk-tk! Watered %d thirsty plot(s)." % n if n > 0 else "Pssht-tk-tk-tk! Everything is already soaked. Pretty, though.")


func _process(delta: float) -> void:
	if _spray <= 0.0:
		return
	_spray -= delta
	rotation.y += delta * 3.2
	if head != null:
		head.rotation.y = rotation.y
	if _spray <= 0.0:
		for j in _jets:
			j.emitting = false
