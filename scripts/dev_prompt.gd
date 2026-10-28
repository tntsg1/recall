class_name DevPrompt
extends CanvasLayer
# The passcode box for developer mode (~ / ` opens it, 111 + Enter unlocks it
# for the session). Springs in over a dimmed frame; each digit lands as a
# dot; a wrong code shakes and clears, the right one flashes red and closes.
# Runs on unscaled time so it moves while the run is frozen behind it.

signal unlocked

const CODE := "111"
const MAX := 8
const SIZE := Vector2(440, 560)
const PAD_KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]

var view: Control
var font_l: Font
var font_s: Font
var font_b: Font
var typed := ""
var open_s := Motion.Spring.new(0.0, 320.0, 0.72)
var shake := Motion.Spring.new(0.0, 900.0, 0.18)
var dots: Array = []          # per typed digit: Spring (0 -> 1 pop)
var wrong := 0.0
var ok_t := -1.0
var keys: Array = []          # [screen Rect2, label] for the on-screen pad
var key_h: Dictionary = {}    # label -> Spring (hover)
var key_p: Dictionary = {}    # label -> Spring (press)
var mouse := Vector2.ZERO
var closing := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_l = Fonts.get_font("Light")
	font_s = Fonts.get_font("Regular")
	font_b = Fonts.get_font("SemiBold")
	view = Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.draw.connect(_draw_view)
	add_child(view)
	open_s.target = 1.0


func _process(delta: float) -> void:
	# undo the run's time scale (it is nearly stopped while the box is open)
	var dt := clampf(delta / maxf(Engine.time_scale, 0.00001), 0.0, 0.05)
	open_s.step(dt)
	shake.step(dt)
	for d in dots:
		d.step(dt)
	wrong = maxf(0.0, wrong - dt / 0.5)
	mouse = view.get_global_mouse_position()
	for kk in PAD_KEYS:
		if not key_h.has(kk):
			key_h[kk] = Motion.Spring.new(0.0, 420.0, 0.7)
			key_p[kk] = Motion.Spring.new(0.0, 600.0, 0.35)
		key_h[kk].target = 0.0
	for kr in keys:
		if (kr[0] as Rect2).has_point(mouse):
			key_h[kr[1]].target = 1.0
	for kk in key_h:
		key_h[kk].step(dt)
		key_p[kk].step(dt)
	if ok_t >= 0.0:
		ok_t += dt
		if ok_t > 0.45 and not closing:
			unlocked.emit()
			_close()
	if closing and open_s.x < 0.02:
		queue_free()
	view.queue_redraw()


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not closing and ok_t < 0.0:
			for kr in keys:
				if (kr[0] as Rect2).has_point(ev.position):
					_pad(kr[1])
		return
	if not (ev is InputEventKey) or not ev.pressed or closing or ok_t >= 0.0:
		if ev is InputEventKey or ev is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	var k: int = ev.physical_keycode
	get_viewport().set_input_as_handled()
	if k == KEY_ESCAPE or k == KEY_QUOTELEFT:
		_close()
	elif k == KEY_BACKSPACE:
		if typed.length() > 0:
			typed = typed.substr(0, typed.length() - 1)
			dots.pop_back()
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		_submit()
	else:
		var ch := ""
		if k >= KEY_0 and k <= KEY_9:
			ch = str(k - KEY_0)
		elif k >= KEY_KP_0 and k <= KEY_KP_9:
			ch = str(k - KEY_KP_0)
		if ch != "" and typed.length() < MAX:
			typed += ch
			var s := Motion.Spring.new(0.0, 520.0, 0.45)
			s.target = 1.0
			dots.append(s)


func _pad(label: String) -> void:
	if key_p.has(label):
		key_p[label].kick(-9.0)
	match label:
		"C":
			typed = ""
			dots.clear()
		"OK":
			_submit()
		_:
			if typed.length() < MAX:
				typed += label
				var s := Motion.Spring.new(0.0, 520.0, 0.45)
				s.target = 1.0
				dots.append(s)


func _submit() -> void:
	if typed == CODE:
		ok_t = 0.0
		return
	wrong = 1.0
	shake.kick(900.0)
	typed = ""
	dots.clear()


func _close() -> void:
	closing = true
	open_s.target = 0.0


func _draw_view() -> void:
	var vp := view.get_viewport_rect().size
	var a := clampf(open_s.x, 0.0, 1.0)
	view.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.62 * a))
	var k := 0.92 + 0.08 * open_s.x
	var c := vp / 2.0 + Vector2(shake.x * 0.04, (1.0 - a) * 30.0)
	view.draw_set_transform(c, 0.0, Vector2(k, k))
	var r := Rect2(-SIZE / 2.0, SIZE)
	view.draw_rect(r, Color(0.035, 0.035, 0.04, a))
	var edge := Pal.ink(0.35 * a).lerp(Pal.red(a, 1.8), wrong)
	view.draw_rect(r, edge, false, 1.5)
	# red corner ticks, the game's frame
	var tick := 18.0
	for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if p.x < 0.0 else -1.0
		var sy := 1.0 if p.y < 0.0 else -1.0
		view.draw_line(p, p + Vector2(tick * sx, 0), Pal.red(a, 2.0), 2.0)
		view.draw_line(p, p + Vector2(0, tick * sy), Pal.red(a, 2.0), 2.0)
	_text_c(font_b, Txt.t("devp_title"), Vector2(0, r.position.y + 48.0), 15, Pal.red(a, 1.6))
	_text_c(font_s, Txt.t("devp_hint"), Vector2(0, r.end.y - 22.0), 13, Pal.ink(0.4 * a))
	# the pad: twelve keys that light under the pointer and dip when pressed
	keys.clear()
	var kw := 104.0
	var kh := 54.0
	for i in PAD_KEYS.size():
		var lab: String = PAD_KEYS[i]
		var col := i % 3
		var row := i / 3
		var kc := Vector2((col - 1) * (kw + 12.0), -40.0 + row * (kh + 12.0) + kh / 2.0)
		var h: float = key_h[lab].x if key_h.has(lab) else 0.0
		var pz: float = key_p[lab].x if key_p.has(lab) else 0.0
		var ks := 1.0 + 0.05 * pz
		var kr := Rect2(kc - Vector2(kw, kh) * ks / 2.0 + Vector2(0, -2.0 * h), Vector2(kw, kh) * ks)
		keys.append([Rect2(c + kr.position * k, kr.size * k), lab])
		var special := lab == "OK" or lab == "C"
		view.draw_rect(kr, Color(1, 1, 1, (0.03 + 0.05 * h) * a))
		view.draw_rect(kr, (Pal.red((0.5 + 0.5 * h) * a, 1.6) if lab == "OK" else Pal.ink((0.16 + 0.4 * h) * a)), false, 1.0)
		if h > 0.02:
			var uw := kr.size.x * Pal.ease_out(h)
			view.draw_line(Vector2(kc.x - uw / 2.0, kr.end.y), Vector2(kc.x + uw / 2.0, kr.end.y), Pal.red(a, 2.0), 2.0)
		var shown := Txt.t("devp_clear") if lab == "C" else (Txt.t("devp_ok") if lab == "OK" else lab)
		_text_c(font_b if special else font_l, shown, Vector2(kc.x, kr.get_center().y + (6.0 if special else 9.0)), 16 if special else 26, Pal.ink((0.75 + 0.25 * h) * a))
	# the slots: one per typed digit, plus the next empty one blinking
	var n := maxi(3, typed.length() + (1 if typed.length() < MAX else 0))
	var gap := 44.0
	var x0 := -(n - 1) * gap / 2.0
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	for i in n:
		var p := Vector2(x0 + i * gap, -150.0)
		view.draw_line(p + Vector2(-14, 22), p + Vector2(14, 22), Pal.ink((0.25 + (0.5 * blink if i == typed.length() else 0.0)) * a), 1.5)
		if i < dots.size():
			var s: float = dots[i].x
			var col := Pal.ink(a, 1.2)
			if ok_t >= 0.0:
				col = Pal.red(a, 2.4)
			view.draw_circle(p, 6.0 * clampf(s, 0.0, 1.4), col)
	if wrong > 0.0:
		_text_c(font_s, Txt.t("devp_wrong"), Vector2(0, -88.0), 14, Pal.red(wrong * a, 1.6))
	if ok_t >= 0.0:
		var e := clampf(ok_t / 0.45, 0.0, 1.0)
		view.draw_arc(Vector2(0, -150), 30.0 + 260.0 * (1.0 - pow(1.0 - e, 3.0)), 0.0, TAU, 64, Pal.red((1.0 - e) * a, 2.4), 2.0, false)
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Pal.pointer(view, mouse, a)


func _text_c(font: Font, txt: String, center: Vector2, size: int, col: Color) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	view.draw_string(font, Vector2(center.x - w / 2.0, center.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
