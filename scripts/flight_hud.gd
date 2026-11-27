class_name FlightHud
extends Control
## Gauges drawn for the flight: altitude ladder, fuel, engine heat, a lean needle, the
## countdown, the booster prompt, and full-screen fades and title cards.

const FONT := preload("res://assets/fonts/lilita_one_regular.ttf")

var sim: FlightSim
var big := ""            ## countdown / shout in the middle
var big_scale := 1.0
var hint := ""
var card_title := ""
var card_text := ""
var fade := 0.0
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func shout(text: String) -> void:
	big = text
	big_scale = 1.5


func _process(delta: float) -> void:
	_t += delta
	big_scale = lerpf(big_scale, 1.0, minf(1.0, 9.0 * delta))
	queue_redraw()


func _text(at: Vector2, text: String, px: int, col: Color, center: bool = true) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := at - Vector2(w * 0.5 if center else 0.0, 0)
	draw_string_outline(FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 10, Color(0, 0, 0, 0.75))
	draw_string(FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _bar(r: Rect2, v: float, col: Color, label: String) -> void:
	draw_rect(r.grow(4), Color(0.04, 0.05, 0.1, 0.75))
	var h := r.size.y * clampf(v, 0.0, 1.0)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - h), Vector2(r.size.x, h)), col)
	_text(r.position + Vector2(r.size.x * 0.5, r.size.y + 30), label, 20, Color.WHITE)


func _draw() -> void:
	var s := get_viewport_rect().size
	if sim != null:
		var ascent := sim.mode == FlightSim.Mode.ASCENT
		var top := FlightSim.ORBIT_ALT if ascent else FlightSim.LAND_START_ALT
		var ladder := Rect2(46, s.y * 0.2, 26, s.y * 0.56)
		_bar(ladder, sim.alt / top, Color(0.55, 0.8, 1.0), "ALT")
		if ascent:
			var y_lo := ladder.end.y - ladder.size.y * FlightSim.SEP_PERFECT_LO / top
			var y_hi := ladder.end.y - ladder.size.y * FlightSim.SEP_PERFECT_HI / top
			if not sim.separated:
				draw_rect(Rect2(ladder.position.x - 8, y_hi, 42, y_lo - y_hi), Color(1.0, 0.85, 0.3, 0.55))
				_text(Vector2(ladder.end.x + 16, y_hi + 24), "booster drop", 18, Color(1.0, 0.88, 0.4), false)
			_text(Vector2(ladder.position.x + 13, ladder.position.y - 18), "MOON", 22, Color(1.0, 0.95, 0.75))
		_text(Vector2(ladder.end.x + 16, ladder.end.y - ladder.size.y * clampf(sim.alt / top, 0.0, 1.0) + 6), "%d m" % int(sim.alt), 22, Color.WHITE, false)
		_bar(Rect2(s.x - 150, s.y * 0.38, 30, s.y * 0.38), sim.fuel, Color(0.45, 0.9, 0.45) if sim.fuel > 0.25 else Color(1.0, 0.35, 0.25), "FUEL")
		if ascent:
			var hot := Color(1.0, 0.75, 0.25).lerp(Color(1.0, 0.15, 0.1), smoothstep(0.55, 0.95, sim.heat))
			if sim.overheated and fmod(_t, 0.3) < 0.15:
				hot = Color.WHITE
			_bar(Rect2(s.x - 82, s.y * 0.38, 30, s.y * 0.38), sim.heat, hot, "HEAT")
			# Lean needle: keep it inside the green wedge.
			var c := Vector2(s.x * 0.5, s.y - 70)
			draw_arc(c, 92, -PI * 0.5 - 0.95, -PI * 0.5 + 0.95, 40, Color(1.0, 0.3, 0.25, 0.9), 12.0)
			draw_arc(c, 92, -PI * 0.5 - FlightSim.WOBBLE_ANGLE, -PI * 0.5 + FlightSim.WOBBLE_ANGLE, 30, Color(0.4, 0.95, 0.5), 13.0)
			var a := -PI * 0.5 + clampf(sim.tilt, -0.95, 0.95)
			draw_line(c, c + Vector2(cos(a), sin(a)) * 104.0, Color.WHITE, 6.0, true)
			draw_circle(c, 9, Color.WHITE)
			_text(c + Vector2(0, 40), "LEAN", 20, Color.WHITE)
		else:
			var speed := -sim.vel
			var sc := Color(0.5, 1.0, 0.55) if speed <= FlightSim.SOFT_SPEED else (Color(1.0, 0.85, 0.35) if speed <= FlightSim.OK_SPEED else Color(1.0, 0.4, 0.3))
			_text(Vector2(s.x * 0.5, s.y - 112), "Falling %.1f m/s" % maxf(speed, 0.0), 34, sc)
			var off := sim.side
			var arrow := "ON THE PAD" if absf(off) <= FlightSim.PAD_HALF else ("<<  pad %d m" % int(absf(off)) if off > 0.0 else "pad %d m  >>" % int(absf(off)))
			_text(Vector2(s.x * 0.5, s.y - 72), arrow, 28, Color(0.5, 1.0, 0.55) if absf(off) <= FlightSim.PAD_HALF else Color.WHITE)
	if big != "":
		_text(Vector2(s.x * 0.5, s.y * 0.27), big, int(76 * big_scale), Color(1.0, 0.9, 0.45))
	if hint != "":
		_text(Vector2(s.x * 0.5, s.y - 186), hint, 28, Color.WHITE)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.02, fade))
	if card_title != "":
		var h := 260.0
		var r := Rect2(s.x * 0.5 - 440, s.y * 0.5 - h * 0.5, 880, h)
		draw_rect(r, Color(0.05, 0.07, 0.15, 0.93))
		draw_rect(r, Color(1.0, 0.8, 0.35), false, 3.0)
		_text(Vector2(s.x * 0.5, r.position.y + 72), card_title, 52, Color(1.0, 0.86, 0.4))
		var y := r.position.y + 130
		for line in card_text.split("\n"):
			_text(Vector2(s.x * 0.5, y), line, 26, Color.WHITE)
			y += 36
