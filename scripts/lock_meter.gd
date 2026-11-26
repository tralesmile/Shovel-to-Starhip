class_name LockMeter
extends Control
## The lockpick minigame drawn as a cut-away pin tumbler lock: three spring pins,
## a pick that sweeps along underneath, a gold sweet spot, pins that stay up once
## set, and a shake plus a flying pick tip when you snap one.

const PANEL := Vector2(440, 214)
const TRACK_X := 44.0
const TRACK_W := 352.0

var lock: Lockpick = null
var _last_pins := 0
var _last_picks := 3
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _lift := [0.0, 0.0, 0.0]
var _broken_t := 9.0
var _broken_x := 0.0
var _hold := 0.0           ## keeps the meter up briefly after opening or failing
var _kept: Lockpick = null
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = PANEL
	size = PANEL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Where the pick tip sits for a cursor value 0..1 (pure, tested).
static func cursor_x(c: float) -> float:
	return TRACK_X + clampf(c, 0.0, 1.0) * TRACK_W


func _process(delta: float) -> void:
	var live: Lockpick = null
	for c in get_tree().get_nodes_in_group("lootbox"):
		if c.state == "picking":
			live = c.lock
	if live != null:
		if live != _kept:
			_kept = live
			_last_pins = 0
			_last_picks = live.picks_left
			_lift = [0.0, 0.0, 0.0]
		_hold = 0.7
	else:
		_hold -= delta
		if _kept == null or not (_kept.is_open() or _kept.is_broken()):
			_hold = 0.0   # walked away: vanish at once
	lock = _kept if _hold > 0.0 else null
	visible = lock != null
	if lock == null:
		if _hold <= 0.0:
			_kept = null
		return
	advance(delta)
	queue_redraw()


## Reacts to changes in the lock and eases the pins.
func advance(delta: float) -> void:
	_t += delta
	if lock.picks_left < _last_picks:
		_shake = 1.0
		_flash = 1.0
		_flash_color = Color(1.0, 0.2, 0.15)
		_broken_t = 0.0
		_broken_x = cursor_x(lock.cursor())
	elif lock.pins_set > _last_pins:
		_flash = 1.0
		_flash_color = Color(1.0, 0.85, 0.3)
		_shake = 0.3
	_last_picks = lock.picks_left
	_last_pins = lock.pins_set
	_shake = maxf(0.0, _shake - delta * 3.0)
	_flash = maxf(0.0, _flash - delta * 2.5)
	_broken_t += delta
	for i in Lockpick.PINS:
		var want := 1.0 if i < lock.pins_set else 0.0
		_lift[i] = move_toward(_lift[i], want, delta * 7.0)


func _draw() -> void:
	if lock == null:
		return
	var off := Vector2(sin(_t * 70.0) * 9.0 * _shake, cos(_t * 53.0) * 4.0 * _shake)
	draw_set_transform(off)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.1, 0.18, 0.9)
	panel.set_corner_radius_all(16)
	panel.set_border_width_all(3)
	panel.border_color = Color(0.85, 0.66, 0.25).lerp(_flash_color, _flash)
	draw_style_box(panel, Rect2(Vector2.ZERO, PANEL))
	# Brass lock body and the keyway the pick travels along.
	draw_rect(Rect2(22, 36, 396, 104), Color(0.72, 0.52, 0.18))
	draw_rect(Rect2(22, 36, 396, 9), Color(0.92, 0.75, 0.32))
	draw_rect(Rect2(30, 108, 380, 24), Color(0.14, 0.09, 0.05))
	var shear := 76.0
	draw_line(Vector2(30, shear), Vector2(410, shear), Color(1, 1, 1, 0.35), 2.0)
	for i in Lockpick.PINS:
		var x := 128.0 + i * 92.0
		draw_rect(Rect2(x - 17, 46, 34, 64), Color(0.3, 0.2, 0.08))
		var active := i == lock.pins_set
		var bob := 0.0
		if active:
			var near := 1.0 - clampf(absf(lock.cursor() - lock.zone_center) / maxf(lock.zone_width, 0.01), 0.0, 1.0)
			bob = near * 9.0 + sin(_t * 30.0) * 1.5 * near
		var lift: float = _lift[i] * 20.0 + bob
		var pin_top: float = 82.0 - lift
		# Spring above the pin squashes as the pin rises.
		var pts := PackedVector2Array()
		for k in 7:
			pts.append(Vector2(x + (-11.0 if k % 2 == 0 else 11.0), lerpf(48.0, pin_top, k / 6.0)))
		draw_polyline(pts, Color(0.8, 0.82, 0.88), 2.5)
		var pin_col := Color(0.76, 0.8, 0.88)
		if i < lock.pins_set:
			pin_col = Color(1.0, 0.84, 0.28)
		elif active:
			pin_col = Color(0.95, 0.97, 1.0)
		draw_rect(Rect2(x - 12, pin_top, 24, 30), pin_col)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 12, pin_top + 30), Vector2(x + 12, pin_top + 30), Vector2(x, pin_top + 41)]), pin_col.darkened(0.12))
		if active and not lock.is_open():
			draw_colored_polygon(PackedVector2Array([Vector2(x - 8, 20), Vector2(x + 8, 20), Vector2(x, 32)]), Color(1.0, 0.85, 0.3))
	# Timing track with the gold sweet spot.
	draw_rect(Rect2(TRACK_X, 150, TRACK_W, 20), Color(0.18, 0.21, 0.3))
	if not lock.is_open():
		var zx := cursor_x(lock.zone_center - lock.zone_width / 2.0)
		var zw := lock.zone_width * TRACK_W
		var inside := lock.in_zone()
		draw_rect(Rect2(zx - 3, 146, zw + 6, 28), Color(1.0, 0.85, 0.3, 0.45 if inside else 0.15))
		draw_rect(Rect2(zx, 150, zw, 20), Color(1.0, 0.95, 0.55) if inside else Color(0.9, 0.68, 0.18))
	var cx := cursor_x(lock.cursor())
	draw_line(Vector2(cx, 143), Vector2(cx, 177), Color.WHITE, 4.0)
	# The pick itself, reaching in from the left.
	if _broken_t > 0.25:
		var tip := Vector2(cx, 118)
		draw_line(Vector2(4, 126), tip, Color(0.82, 0.86, 0.94), 5.0)
		draw_line(tip, tip + Vector2(3, -11), Color(0.82, 0.86, 0.94), 5.0)
		draw_rect(Rect2(0, 118, 26, 17), Color(0.75, 0.25, 0.2))
	if _broken_t < 0.7:
		var k := _broken_t
		var p := Vector2(_broken_x + 70.0 * k, 118.0 - 110.0 * k + 300.0 * k * k)
		var dir := Vector2.from_angle(k * 22.0) * 14.0
		draw_line(p - dir, p + dir, Color(0.82, 0.86, 0.94, 1.0 - k), 5.0)
	# Spare picks.
	for i in lock.picks_max:
		var x := 30.0 + i * 18.0
		var col := Color(0.85, 0.89, 0.96) if i < lock.picks_left else Color(0.3, 0.33, 0.42)
		draw_line(Vector2(x, 184), Vector2(x, 205), col, 4.0)
		draw_line(Vector2(x, 184), Vector2(x + 7, 188), col, 4.0)
	var font := preload("res://assets/fonts/lilita_one_regular.ttf")
	var title := "OPEN!" if lock.is_open() else ("OUT OF PICKS" if lock.is_broken() else "Pin %d of %d" % [lock.pins_set + 1, Lockpick.PINS])
	draw_string(font, Vector2(200, 201), title, HORIZONTAL_ALIGNMENT_RIGHT, 216, 20, Color(1.0, 0.93, 0.7))
	draw_set_transform(Vector2.ZERO)
