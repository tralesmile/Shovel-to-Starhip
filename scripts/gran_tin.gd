class_name GranTin
extends Interactable
## Gran's biscuit tin behind the cracked wall: one-time cash, spare crystals and a note.

const CASH := 150
const CRYSTALS := 2

var opened := false
var _lid: Node3D


func _ready() -> void:
	add_to_group("saveable")
	var tin := Art.box(Vector3(0.8, 0.45, 0.55), Color(0.25, 0.45, 0.7))
	tin.position.y = 0.25
	add_child(tin)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.5, -0.28)
	add_child(_lid)
	var lid := Art.box(Vector3(0.86, 0.1, 0.6), Color(0.9, 0.75, 0.35))
	lid.position.z = 0.28
	_lid.add_child(lid)
	_refresh()


func get_prompt(_game: GameState) -> String:
	return "An empty biscuit tin. Still smells of ginger." if opened else "[E] Open Gran's biscuit tin"


func interact(game: GameState) -> void:
	if opened:
		game.say("Crumbs. Historic crumbs.")
		return
	opened = true
	_refresh()
	game.earn(CASH)
	game.add_item("glow_crystal", CRYSTALS)
	game.say("Gran's note: \"Glow Crystals make good rocket windows. Biscuits do not.\" +$%d, +%d Glow Crystals" % [CASH, CRYSTALS])
	Sfx.play_on(self, "fanfare")
	FX.burst(self, global_position + Vector3(0, 0.7, 0), Color(1.0, 0.85, 0.3), 20, 0.08, 3.5, -6.0, "box", 70.0)
	game.shake.emit(0.15)


func _refresh() -> void:
	if _lid != null:
		_lid.rotation.x = -1.9 if opened else 0.0


func to_dict() -> Dictionary:
	return {"opened": opened}


func from_dict(d: Dictionary) -> void:
	opened = bool(d.get("opened", false))
	_refresh()
