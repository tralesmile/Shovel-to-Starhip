class_name DoorLeaf
extends Node3D
## The swinging door of a built doorway. It shuts by itself, swings away from whoever walks up
## (with a springy overshoot), creaks open and thumps closed.

const OPEN_ANGLE := 1.75
const OPEN_DIST := 1.8
const STIFFNESS := 70.0
const DAMPING := 8.5

var angle := 0.0
var spin := 0.0
var wanted := 0.0


## Pure (tested): where the door should be for a visitor at `local` (doorway space). Once open
## it keeps its side, so walking through never slams it back into your face.
static func target_angle(local: Vector3, current: float) -> float:
	if Vector2(local.x, local.z).length() > OPEN_DIST or absf(local.y) > 1.6:
		return 0.0
	if not is_zero_approx(current):
		return current
	return OPEN_ANGLE if local.z >= 0.0 else -OPEN_ANGLE


## Pure (tested): one spring step; returns [angle, speed].
static func spring(a: float, v: float, to: float, delta: float) -> Array:
	var dt := minf(delta, 0.033)
	v += ((to - a) * STIFFNESS - v * DAMPING) * dt
	return [a + v * dt, v]


func _ready() -> void:
	position = Vector3(-0.44, 0, 0)
	var h := 1.8
	var c := Color(0.5, 0.31, 0.18)
	for k in 4:
		BuildKit.board(self, Vector3(0.212, h, 0.07), Vector3(0.11 + k * 0.22, h * 0.5 + 0.15, 0), c.lightened(0.06 * (k % 2)))
	for y in [0.3, 1.45]:
		for side in [-0.05, 0.05]:
			var strap := Art.box(Vector3(0.7, 0.09, 0.02), BuildKit.IRON)
			strap.position = Vector3(0.36, y, side)
			add_child(strap)
	for side2 in [-0.09, 0.09]:
		var knob := Art.sphere(0.055, Color(0.96, 0.8, 0.3), 4, 7)
		knob.position = Vector3(0.74, 0.95, side2)
		add_child(knob)


func _physics_process(delta: float) -> void:
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var door := get_parent() as Node3D
	if pl == null or door == null:
		return
	var to := target_angle(door.to_local(pl.global_position), wanted)
	if to != wanted:
		Sfx.play_on(self, "creak" if to != 0.0 else "step_wood", 1.25 if to != 0.0 else 0.7)
		wanted = to
	var s := spring(angle, spin, wanted, delta)
	angle = s[0]
	spin = s[1]
	rotation.y = angle
