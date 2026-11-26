class_name FishFight
extends RefCounted
## Pure tug-of-war after the hook. Hold the button to reel: the line gets tighter.
## The fish alternates between calm and thrashing; reeling into a thrash tightens the
## line fast. Let it tire, then pull. Too tight = snap. No ground gained = it swims off.
## Small fish are deliberately very forgiving (Stardew's creator says his started too hard).

const START_PROGRESS := 0.3
const BEGINNER_CATCHES := 3     ## the first few catches go easy on your line
const BEGINNER_EASE := 0.65
const ROD_EASE := 0.62          ## Springy Rod: line tightens slower
const ROD_REEL := 1.25
const SLACK_RECOVERY := 0.85

## species -> strength (line strain), reel speed, calm seconds, thrash seconds
const SPECIES := {
	"boot": {"strength": 0.0, "reel": 0.55, "calm": 9.0, "surge": 0.0},
	"old_wizard_hat": {"strength": 0.0, "reel": 0.5, "calm": 9.0, "surge": 0.0},
	"minnow": {"strength": 0.35, "reel": 0.5, "calm": 1.6, "surge": 0.5},
	"carp": {"strength": 0.75, "reel": 0.34, "calm": 1.5, "surge": 0.9},
	"trout": {"strength": 1.0, "reel": 0.3, "calm": 1.2, "surge": 0.9},
	"golden_carp": {"strength": 1.3, "reel": 0.25, "calm": 1.1, "surge": 1.2},
}

var species := "minnow"
var progress := START_PROGRESS
var tension := 0.0
var surging := false
var result := ""                ## "", "landed", "snapped", "escaped"
var rod := false
var ease := 1.0
var _phase_left := 0.7
var rng := RandomNumberGenerator.new()


func _init(fish: String = "minnow", has_rod: bool = false, catches_so_far: int = 99, seed_value: int = 1) -> void:
	species = fish if SPECIES.has(fish) else "minnow"
	rod = has_rod
	ease = BEGINNER_EASE if catches_so_far < BEGINNER_CATCHES else 1.0
	rng.seed = seed_value


## Line strain per second while reeling.
static func strain_rate(strength: float, thrashing: bool, has_rod: bool, ease_mult: float) -> float:
	if strength <= 0.0:
		return 0.0
	var r := (0.35 + 0.65 * strength) if thrashing else 0.14 * strength
	return r * (ROD_EASE if has_rod else 1.0) * ease_mult


func tick(delta: float, reeling: bool) -> String:
	if result != "":
		return result
	var s: Dictionary = SPECIES[species]
	_phase_left -= delta
	if _phase_left <= 0.0:
		surging = not surging and float(s["surge"]) > 0.0
		_phase_left = float(s["surge" if surging else "calm"]) * rng.randf_range(0.75, 1.25)
	var strength := float(s["strength"])
	if reeling:
		var gain := float(s["reel"]) * (ROD_REEL if rod else 1.0) * (0.25 if surging else 1.0)
		progress += gain * delta
		tension += strain_rate(strength, surging, rod, ease) * delta
		if not surging:
			tension = minf(tension, 0.92)   # a calm fish never snaps the line, only a thrash does
	else:
		tension -= SLACK_RECOVERY * delta
		progress -= (0.11 * strength if surging else 0.035) * delta
	tension = clampf(tension, 0.0, 1.0)
	progress = clampf(progress, 0.0, 1.0)
	if tension >= 1.0:
		result = "snapped"
	elif progress >= 1.0:
		result = "landed"
	elif progress <= 0.0:
		result = "escaped"
	return result
