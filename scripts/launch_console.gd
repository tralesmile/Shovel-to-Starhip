class_name LaunchConsole
extends Interactable
## The launch pad's control desk: opens the Starship workshop, where you also launch.

var program: Node
var _lamp: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	interact_radius = 2.2
	var desk := Art.solid_box(self, Vector3.ZERO, Vector3(1.5, 0.95, 0.75), Color(0.3, 0.34, 0.42))
	desk.name = "Desk"
	var top := Art.box(Vector3(1.6, 0.1, 0.85), Color(0.85, 0.87, 0.92))
	top.position = Vector3(0, 1.0, 0.0)
	add_child(top)
	var screen := Art.box(Vector3(0.8, 0.5, 0.07), Color(0.2, 0.8, 0.9))
	screen.material_override = Art.mat(Color(0.2, 0.75, 0.85), true)
	screen.position = Vector3(-0.28, 1.34, -0.2)
	screen.rotation.x = -0.25
	add_child(screen)
	_lamp = Art.sphere(0.17, Color(0.95, 0.2, 0.15), 6, 12)
	_lamp.material_override = Art.mat(Color(0.95, 0.2, 0.15), true)
	_lamp.position = Vector3(0.45, 1.12, 0.1)
	add_child(_lamp)
	var l := Art.label("STARSHIP WORKSHOP", 56, Color(1.0, 0.9, 0.5))
	l.position = Vector3(0, 2.15, 0)
	l.visibility_range_end = 22.0
	add_child(l)


func get_prompt(game: GameState) -> String:
	if Story.is_finished(game.story_act):
		return "[E] Starship workshop  -  READY FOR LAUNCH"
	return "[E] Starship workshop  (design her now, launch when Gran's story is done)"


func interact(_game: GameState) -> void:
	if program != null:
		program.open_workshop()


func _process(delta: float) -> void:
	_t += delta
	if _lamp != null:
		_lamp.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 4.0))
