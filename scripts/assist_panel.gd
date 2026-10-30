class_name AssistPanel
extends CanvasLayer
# Settings · Assist mode, drawn the way the title's settings page is: rows on
# a centre line, a soft band and a red underline that spring to the chosen
# row, values with ◂ ▸ that slide when they change, a knob toggle. Opened
# from the title's settings and from the pause menu; Esc / B closes it.
# Keyboard: ↑↓ choose, ←→ change, Enter toggles; the mouse hovers and clicks.

signal closed
var game
var old_mouse := Input.MOUSE_MODE_HIDDEN

const ROWS := ["enable", "damage", "retries", "back"]
const ROW_W := 720.0
const ROW_H := 58.0
const DAMAGE := [0, 20, 40, 60, 80]
const RETRIES := [0, 1, 3, 5]

var view: Control
var font_s: Font
var font_b: Font
var font_xl: Font
var sel := 0
var t := 0.0
var leaving := -1.0                       # time since closing began, or -1
var hl := Motion.Spring2.new(Vector2.ZERO, 420.0, 0.78)
var lift: Array = []                      # per row: how lifted it is
var press: Array = []                     # per row: a press squash
var knob := Motion.Spring.new(0.0, 380.0, 0.62)
var val_old := ""
var val_row := -1
var val_dir := 0
var val_t := 9.0


func _ready() -> void:
	layer = 110
	old_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	font_s = Fonts.get_font("Regular")
	font_b = Fonts.get_font("SemiBold")
	font_xl = Fonts.get_font("Medium")
	view = Control.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.draw.connect(_draw_view)
	view.gui_input.connect(_gui)
	add_child(view)
	for i in ROWS.size():
		lift.append(Motion.Spring.new(0.0, 300.0, 0.7))
		press.append(Motion.Spring.new(0.0, 520.0, 0.5))
	knob.snap(1.0 if Settings.assist else 0.0)
	hl.snap(_row_rect(0).get_center())


func _vp() -> Vector2:
	return view.get_rect().size if view != null and view.get_rect().size.x > 10.0 else get_viewport().get_visible_rect().size


func _row_rect(i: int) -> Rect2:
	var vp := _vp()
	var top := vp.y * 0.5 - 150.0
	return Rect2(vp.x / 2.0 - ROW_W / 2.0, top + i * ROW_H, ROW_W, ROW_H - 10.0)


# A row the cursor may rest on: the two values only while assist is on.
func _usable(i: int) -> bool:
	return ROWS[i] in ["enable", "back"] or Settings.assist


func _process(dt: float) -> void:
	t += dt
	val_t += dt
	if leaving >= 0.0:
		leaving += dt
		if leaving > 0.22:
			_finish()
			return
	hl.target = _row_rect(sel).get_center()
	hl.step(dt)
	for i in ROWS.size():
		lift[i].target = 1.0 if i == sel else 0.0
		lift[i].step(dt)
		press[i].step(dt)
	knob.target = 1.0 if Settings.assist else 0.0
	knob.step(dt)
	view.queue_redraw()


func _input(event: InputEvent) -> void:
	if leaving >= 0.0:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_move(-1)
	elif event.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		_move(1)
	elif event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		_change(sel, -1)
	elif event.is_action_pressed("ui_right", true):
		get_viewport().set_input_as_handled()
		_change(sel, 1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_activate(sel)


func _gui(event: InputEvent) -> void:
	if leaving >= 0.0:
		return
	if event is InputEventMouseMotion:
		var i := _row_at(event.position)
		if i >= 0 and i != sel and _usable(i):
			sel = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _row_at(event.position)
		if i < 0 or not _usable(i):
			return
		sel = i
		if ROWS[i] in ["damage", "retries"]:
			# the left third steps down, the rest steps up
			var r := _row_rect(i)
			_change(i, -1 if event.position.x < r.position.x + r.size.x * 0.33 else 1)
		else:
			_activate(i)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()


func _row_at(p: Vector2) -> int:
	for i in ROWS.size():
		if _row_rect(i).grow(4.0).has_point(p):
			return i
	return -1


func _move(d: int) -> void:
	var i := sel
	for k in ROWS.size():
		i = wrapi(i + d, 0, ROWS.size())
		if _usable(i):
			break
	sel = i


func _activate(i: int) -> void:
	press[i].kick(-6.0)
	match ROWS[i]:
		"enable":
			Settings.assist = not Settings.assist
			Settings.save()
		"damage", "retries":
			_change(i, 1)
		"back":
			close()


func _change(i: int, d: int) -> void:
	var key: String = ROWS[i]
	if key == "enable":
		if (d > 0) != Settings.assist:
			_activate(i)
		return
	if not (key in ["damage", "retries"]) or not Settings.assist:
		return
	val_old = _value(i)
	if key == "damage":
		var at := DAMAGE.find(int(Settings.damage_reduction))
		Settings.damage_reduction = DAMAGE[clampi(maxi(at, 0) + d, 0, DAMAGE.size() - 1)]
	else:
		var at := RETRIES.find(Settings.retry_limit)
		Settings.retry_limit = RETRIES[clampi(maxi(at, 0) + d, 0, RETRIES.size() - 1)]
	if _value(i) != val_old:
		Settings.save()
		val_row = i
		val_dir = d
		val_t = 0.0
		press[i].kick(-4.0)


func _value(i: int) -> String:
	match ROWS[i]:
		"damage":
			return "%d%%" % int(Settings.damage_reduction)
		"retries":
			return str(Settings.retry_limit)
	return ""


func close() -> void:
	if leaving < 0.0:
		leaving = 0.0


func _finish() -> void:
	Input.mouse_mode = old_mouse
	closed.emit()
	queue_free()


# ------------------------------------------------------------------ drawing

func _text_c(font: Font, txt: String, center: Vector2, size: int, c: Color) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	view.draw_string(font, Vector2(center.x - w / 2.0, center.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


# Each row comes in a beat after the one above; on the way out all fade together.
func _k(i: int) -> Vector2:
	var k_in := Pal.ease_out(Motion.stagger(t, i, 0.035, 0.3))
	var k_out := 1.0 - Pal.ease_in(clampf(leaving / 0.2, 0.0, 1.0)) if leaving >= 0.0 else 1.0
	return Vector2(k_in * k_out, (1.0 - k_in) * 40.0)


func _draw_view() -> void:
	var vp := _vp()
	var whole := _k(0).x
	view.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.012, 0.012, 0.016, clampf(t / 0.15, 0.0, 1.0) * (1.0 - clampf(leaving / 0.22, 0.0, 1.0) if leaving >= 0.0 else 1.0)))
	var top := _row_rect(0).position.y
	_text_c(font_xl, Txt.t("a_title"), Vector2(vp.x / 2.0, top - 96.0 + _k(0).y * 0.5), 34, Pal.ink(whole))
	_text_c(font_s, Txt.t("a_intro"), Vector2(vp.x / 2.0, top - 52.0), 16, Pal.ink(0.5 * whole))
	_draw_highlight(whole)
	for i in ROWS.size():
		var ki := _k(i + 1)
		match ROWS[i]:
			"enable":
				_row(i, Txt.t("a_enable"), " ", ki)
				_draw_toggle(i, ki)
			"damage":
				_row(i, Txt.t("a_damage_label"), _value(i), ki, not Settings.assist)
			"retries":
				_row(i, Txt.t("a_retries_label"), _value(i), ki, not Settings.assist)
			"back":
				_row(i, Txt.t("t_back_short"), "", ki)
	# below the rows: how many retries are left, then what the two settings do
	var kn := _k(ROWS.size() + 1)
	var y := _row_rect(ROWS.size() - 1).end.y + 44.0
	var status := Txt.t("a_remaining") % maxi(0, Settings.retry_limit - game.assist_retries_used) if game != null else Txt.t("a_new_run")
	_text_c(font_b, status, Vector2(vp.x / 2.0, y), 15, Pal.ink(0.62 * kn.x) if Settings.assist else Pal.ink(0.38 * kn.x))
	y += 40.0
	for key in ["a_checkpoint", "a_fraction"]:
		for line in Txt.wrap(font_s, Txt.t(key), 15, ROW_W - 40.0):
			_text_c(font_s, line, Vector2(vp.x / 2.0, y), 15, Pal.ink(0.42 * kn.x))
			y += 23.0
		y += 14.0
	_text_c(font_s, Txt.t("a_keys"), Vector2(vp.x / 2.0, vp.y - 40.0), 14, Pal.ink(0.45 * whole))


func _draw_highlight(a: float) -> void:
	var c: Vector2 = hl.x
	var w := ROW_W
	var r := Rect2(c - Vector2(w / 2.0, 24.0), Vector2(w, 48.0))
	Pal.band(view, r, 0.022 * a)
	var stretch := clampf(absf(hl.v.y) / 1200.0, 0.0, 0.5)
	var uw := w * (1.0 - stretch * 0.6)
	view.draw_line(Vector2(c.x - uw / 2.0, r.end.y), Vector2(c.x + uw / 2.0, r.end.y), Pal.red(0.85 * a, 2.0), 2.0)
	view.draw_line(Vector2(r.position.x - 10.0, r.position.y + 8.0), Vector2(r.position.x - 10.0, r.end.y - 8.0), Pal.red(a, 2.2), 2.0)


func _row(i: int, label: String, value: String, ki: Vector2, off := false) -> void:
	var r := _row_rect(i)
	var lf: float = lift[i].x
	var sc: float = 1.0 + 0.02 * lf + press[i].x * 0.01
	var a := ki.x * (0.45 if off else 1.0)
	var c := Pal.ink((0.55 + 0.4 * lf) * a)
	view.draw_set_transform(r.get_center() + Vector2(ki.y, 0), 0.0, Vector2(sc, sc))
	var lr := Rect2(-r.size / 2.0, r.size)
	if value == "":
		_text_c(font_xl, label, Vector2(0, 9), 24, c)
	else:
		view.draw_string(font_s, lr.position + Vector2(20, 31), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink((0.45 + 0.2 * lf) * a))
		var vx := lr.end.x - 24.0
		if value != " ":
			if i == val_row and val_t < 0.3:
				# the old value slides out, the new one in
				var k := Pal.ease_out(val_t / 0.3)
				var w0 := font_b.get_string_size(val_old, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				view.draw_string(font_b, Vector2(vx - w0 - 30.0 * k * val_dir, lr.position.y + 31), val_old, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink((1.0 - k) * 0.9 * a))
				var w1 := font_b.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				view.draw_string(font_b, Vector2(vx - w1 + 30.0 * (1.0 - k) * val_dir, lr.position.y + 31), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(c.r, c.g, c.b, c.a * k))
			else:
				var vw := font_b.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				view.draw_string(font_b, Vector2(vx - vw, lr.position.y + 31), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, c)
				if lf > 0.5 and not off:
					var nudge := sin(t * 5.0) * 2.0
					view.draw_string(font_b, Vector2(vx - vw - 26.0 - nudge, lr.position.y + 31), "◂", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.5 * a * lf))
					view.draw_string(font_b, Vector2(vx + 8.0 + nudge, lr.position.y + 31), "▸", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.5 * a * lf))
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_toggle(i: int, ki: Vector2) -> void:
	var r := _row_rect(i)
	var track := Rect2(r.end.x - 90.0 + ki.y, r.position.y + 14.0, 56.0, 20.0)
	var k := knob.x
	view.draw_rect(track, Pal.ink((0.12 + 0.2 * clampf(k, 0.0, 1.0)) * ki.x))
	view.draw_rect(track, Pal.ink(0.4 * ki.x), false, 1.0)
	var kx := lerpf(track.position.x + 10.0, track.end.x - 10.0, k)
	# the knob stretches a little while it travels
	var stretch := clampf(absf(knob.v) / 30.0, 0.0, 0.6)
	view.draw_set_transform(Vector2(kx, track.get_center().y), 0.0, Vector2(1.0 + stretch, 1.0 - stretch * 0.3))
	view.draw_circle(Vector2.ZERO, 8.0, Pal.ink(ki.x, 1.0 + 0.5 * clampf(k, 0.0, 1.0)).lerp(Pal.red(ki.x, 2.0), clampf(k, 0.0, 1.0) * 0.6))
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
