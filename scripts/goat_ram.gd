class_name GoatRam
extends RefCounted
## Horns first: what a charging goat does to whatever is in front of it. A galloping goat
## barges through light things; a headbutt lunge also cracks rocks and shakes trees.

const BARGE_SPEED := 9.5     ## galloping faster than this barges things aside
const LUNGE_SPEED := 15.0
const LUNGE_TIME := 0.34
const COOLDOWN := 1.1
const REACH := 1.5


## Pure (tested): does the goat hit things right now?
static func is_ramming(speed: float, lunge_left: float) -> bool:
	return lunge_left > 0.0 or speed >= BARGE_SPEED


## Pure (tested): is `at` inside the strike zone in front of a goat at `from` facing `yaw`?
static func in_front(from: Vector3, yaw: float, at: Vector3, reach: float = REACH, half_width: float = 0.95) -> bool:
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var to := at - from
	if absf(to.y) > 2.0:
		return false
	var along := to.x * f.x + to.z * f.z
	var across := absf(to.x * f.z - to.z * f.x)
	return along > -0.2 and along <= reach and across <= half_width


## Pure (tested): the launch given to a loose thing. Fonder goats hit harder.
static func fling(yaw: float, speed: float, hearts: int, lunge: bool) -> Vector3:
	var power := clampf(speed, 6.0, 16.0) * (0.75 + 0.05 * float(clampi(hearts, 0, 5)))
	if lunge:
		power *= 1.15
	return Vector3(sin(yaw) * power, 3.0 + power * 0.28, cos(yaw) * power)


## Strike everything new in the zone. `done` remembers what this charge already hit.
## Returns how many things were hit this call.
static func strike(tree: SceneTree, game: GameState, from: Vector3, yaw: float, speed: float, hearts: int,
		lunge: bool, done: Dictionary) -> int:
	var n := 0
	var v := fling(yaw, speed, hearts, lunge)
	for node in tree.get_nodes_in_group("smashable"):
		var c := node as PropCrate
		if c != null and not done.has(c) and in_front(from, yaw, c.global_position):
			done[c] = true
			n += 1
			c.game = game
			for i in PropCrate.HITS_TO_SMASH:
				if c.smash_hit():
					break
	for node in tree.get_nodes_in_group("knockable"):
		var k := node as KnockProp
		if k != null and not done.has(k) and in_front(from, yaw, k.global_position, REACH + 0.3):
			done[k] = true
			if k.knock(v):
				n += 1
	for node in tree.get_nodes_in_group("huntable"):
		var r := node as Critter
		if r != null and r.visible and not done.has(r) and in_front(from, yaw, r.global_position):
			done[r] = true
			r.bonk(game)
			n += 1
	for group in ["pickup", "giantball"]:
		for node in tree.get_nodes_in_group(group):
			var b := node as RigidBody3D
			if b == null or done.has(b) or b.freeze or not in_front(from, yaw, b.global_position):
				continue
			done[b] = true
			b.sleeping = false
			if group == "pickup":
				# Loose loot gets a hop rather than a launch, so it stays findable.
				b.apply_central_impulse(v * 0.35 * b.mass)
			else:
				b.apply_central_impulse(v * 0.55 * b.mass)
				n += 1
	for node in tree.get_nodes_in_group("trunk"):
		var t := node as Node3D
		if t == null or done.has(t) or not (t is FelledTrunk):
			continue
		var body := (t as FelledTrunk).body
		if body != null and in_front(from, yaw, body.global_position, REACH + 0.6, 1.5):
			done[t] = true
			n += 1
			body.sleeping = false
			body.apply_central_impulse(Vector3(v.x, 1.0, v.z) * 0.3 * body.mass)
	if lunge:
		for node in tree.get_nodes_in_group("blastable"):
			var rock := node as MineRock
			if rock != null and not done.has(rock) and in_front(from, yaw, rock.global_position, REACH + 0.4):
				done[rock] = true
				if rock.ram(game):
					n += 1
		for node in tree.get_nodes_in_group("daily"):
			var wood := node as ChoppableTree
			if wood != null and not done.has(wood) and in_front(from, yaw, wood.global_position, REACH + 0.5):
				done[wood] = true
				if wood.shake_tree(game):
					n += 1
	return n
