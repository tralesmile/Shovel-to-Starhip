class_name AudioSettings
extends RefCounted
## Master/Music/SFX volume settings (0..1 sliders) with dB mapping and persistence.
## Buses are created at runtime so no bus layout file is needed.

const PATH := "user://audio.json"
const BUSES := ["Master", "Music", "SFX"]

var volumes := {"Master": 0.8, "Music": 0.6, "SFX": 0.9}
## Tutorial/context hints on or off (stored alongside volumes).
var hints_enabled := true


static func to_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(clampf(v, 0.0, 1.0))


func set_volume(bus: String, v: float) -> void:
	if volumes.has(bus):
		volumes[bus] = clampf(v, 0.0, 1.0)


func to_dict() -> Dictionary:
	var d := volumes.duplicate()
	d["hints"] = hints_enabled
	return d


func from_dict(d: Dictionary) -> void:
	for b in BUSES:
		if d.has(b):
			set_volume(b, float(d[b]))
	if d.has("hints"):
		hints_enabled = bool(d["hints"])


## Creates Music/SFX buses if missing and applies volumes.
func apply() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), to_db(volumes[b]))


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


func load_file() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	from_dict(d)
	return true
