class_name Story
extends RefCounted
## Story spine v1: "Gran's Busted Rocket" in 5 acts. Stardew-bundle style: a visible checklist with
## progress counters (nothing is consumed, so it never blocks other crafting). Pure logic, tested.

const ACTS := [
	{"title": "Gran's Note", "intro": "Gran left a note: 'Rocket needs money. Also turnips.'", "reward": 50,
		"goals": [{"kind": "earned", "n": 150, "text": "Earn $150 from the farm"}]},
	{"title": "Trust or Infamy", "intro": "Town will only help if it loves you... or fears you.", "reward": 75,
		"goals": [{"kind": "rep", "n": 3, "text": "Become well known (Lawful or Outlaw, 3 points)"}]},
	{"title": "Parts Quest", "intro": "Gran's rocket needs hull plates and shiny bits.", "reward": 100,
		"goals": [{"kind": "have", "id": "rocket_plate", "n": 2, "text": "Craft Rocket Hull Plates"},
			{"kind": "have", "id": "gem", "n": 2, "text": "Hold gems"}]},
	{"title": "Wheels for the Moon", "intro": "Test the booster on something with wheels first.", "reward": 150,
		"goals": [{"kind": "car", "n": 1, "text": "Own a car"}, {"kind": "part", "id": "rocket_booster", "n": 1, "text": "Bolt a Rocket Booster on it"}]},
	{"title": "Build the Starship", "intro": "Stack the hull. The Moon is waiting (and probably cheese).", "reward": 300,
		"goals": [{"kind": "have", "id": "rocket_plate", "n": 4, "text": "Hold Rocket Hull Plates"},
			{"kind": "have", "id": "polished_gem", "n": 2, "text": "Hold Polished Gems"}]},
]


static func act_count() -> int:
	return ACTS.size()


static func is_finished(act: int) -> bool:
	return act >= ACTS.size()


## Current value of a goal for the given game state.
static func goal_value(goal: Dictionary, g) -> int:
	match goal["kind"]:
		"earned":
			return g.total_earned
		"rep":
			return int(floor(absf(g.reputation)))
		"have":
			return g.count_with_stash(goal["id"])
		"car":
			return 1 if g.car_owned else 0
		"part":
			return 1 if g.car_parts.has(goal["id"]) else 0
	return 0


## [{text, cur, target, done}] for an act ([] when the story is finished).
static func progress(act: int, g) -> Array:
	var out: Array = []
	if is_finished(act):
		return out
	for goal in ACTS[act]["goals"]:
		var cur := mini(goal_value(goal, g), int(goal["n"]))
		out.append({"text": goal["text"], "cur": cur, "target": int(goal["n"]), "done": cur >= int(goal["n"])})
	return out


static func act_complete(act: int, g) -> bool:
	if is_finished(act):
		return false
	for p in progress(act, g):
		if not p["done"]:
			return false
	return true


## Compact HUD text, e.g. "Act 3/5 Parts Quest\n[x] Craft Rocket Hull Plates 2/2\n[ ] ...".
static func hud_text(act: int, g) -> String:
	if is_finished(act):
		return "Story: the Starship is ready. (Launch is coming soon!)"
	var lines: PackedStringArray = ["Act %d/%d  %s" % [act + 1, ACTS.size(), ACTS[act]["title"]]]
	for p in progress(act, g):
		lines.append("%s %s  %d/%d" % ["[x]" if p["done"] else "[ ]", p["text"], p["cur"], p["target"]])
	return "\n".join(lines)


## Rocket build stage for the landmark: 0 (wreck) .. ACTS.size() (finished starship).
static func rocket_stage(act: int) -> int:
	return clampi(act, 0, ACTS.size())
