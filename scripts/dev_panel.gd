class_name DevPanel
extends CanvasLayer
# The developer panel: every dev action as something to click. The host (title
# or run) hands over the rows; clicks call host.dev_action(id, arg). Buttons light
# up under the pointer and dip when pressed with a ripple, toggles slide, the
# speed selector's highlight springs between options, school chips pop when they
# level. The panel slides in from the left and its rows arrive one by one.

const W := 380.0
const PAD := 18.0

var host: Object
var rows: Array = []
var view: Control
var font_s: Font
var font_b: Font
var font_l: Font
var open_s := Motion.Spring.new(0.0, 300.0, 0.8)
var t := 0.0
var hover := ""
var over := false              # the pointer is on the panel (the run must not shoot)
var hov: Dictionary = {}       # id -> Spring (hover light)
var press: Dictionary = {}     # id -> Spring (press dip)
var knobs: Dictionary = {}     # id -> Spring (toggle knob)
var seg_s: Dictionary = {}     # id -> Spring (selector highlight x)
var pops: Dictionary = {}      # id -> float
var ripples: Array = []        # [pos, t]
var regions: Array = []        # [Rect2, id, arg]
var closing := false
var mouse := Vector2.ZERO


func setup(h: Object, r: Array) -> DevPanel:
	host = h
	rows = r
	return self


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_s = Fonts.get_font("Regular")
	font_b = Fonts.get_font("SemiBold")
	font_l = Fonts.get_font("Light")
	view = Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view)
	add_child(view)
	open_s.target = 1.0


func close() -> void:
	closing = true
	open_s.target = 0.0


func _process(delta: float) -> void:
	var dt := clampf(delta / maxf(Engine.time_scale, 0.00001), 0.0, 0.05)
	t += dt
	open_s.step(dt)
	mouse = view.get_global_mouse_position()
	over = open_s.x > 0.3 and _panel_rect().has_point(mouse)
	hover = ""
	for r in regions:
		if (r[0] as Rect2).has_point(mouse):
			hover = r[1]
	for id in hov:
		hov[id].target = 1.0 if id == hover else 0.0
		hov[id].step(dt)
	for id in press:
		press[id].step(dt)
	for id in knobs:
		knobs[id].step(dt)
	for id in seg_s:
		seg_s[id].step(dt)
	for id in pops:
		pops[id] = maxf(0.0, pops[id] - dt / 0.5)
	var i := 0
	while i < ripples.size():
		ripples[i][1] += dt
		if ripples[i][1] > 0.5:
			ripples.remove_at(i)
		else:
			i += 1
	if closing and open_s.x < 0.01:
		queue_free()
	view.queue_redraw()


func _input(ev: InputEvent) -> void:
	if closing or open_s.x < 0.3:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if not _panel_rect().has_point(ev.position):
			return
		get_viewport().set_input_as_handled()
		if not ev.pressed:
			return
		for r in regions:
			if (r[0] as Rect2).has_point(ev.position):
				_spring(press, r[1], 0.0, 600.0, 0.35).kick(-9.0)
				ripples.append([ev.position, 0.0])
				pops[r[1]] = 1.0
				if r[1] == "__close":
					host.dev_action("close", null)
				else:
					host.dev_action(r[1], r[2])
				return
	elif ev is InputEventMouseButton and _panel_rect().has_point(ev.position):
		get_viewport().set_input_as_handled()


func _spring(d: Dictionary, id: String, start: float, k: float = 380.0, z: float = 0.7) -> Motion.Spring:
	if not d.has(id):
		d[id] = Motion.Spring.new(start, k, z)
	return d[id]


func _panel_rect() -> Rect2:
	return Rect2(24.0 - (1.0 - open_s.x) * (W + 60.0), 88.0, W, _height())


func _row_h(r: Dictionary) -> float:
	match r.kind:
		"head":
			return 34.0
		"stat":
			return 22.0
		"btns":
			return 46.0
		"toggle":
			return 40.0
		"seg":
			return 46.0
		"chips":
			return ceili(r.items.size() / 4.0) * 58.0 + 4.0
	return 30.0


func _height() -> float:
	var h := 64.0
	for r in rows:
		h += _row_h(r)
	return h + 30.0


# ---------------------------------------------------------------- drawing

func _draw_view() -> void:
	regions.clear()
	var a := clampf(open_s.x, 0.0, 1.0)
	if a <= 0.01:
		return
	var pr := _panel_rect()
	# glass: a dark slab, a lighter rim, the game's red corner ticks
	view.draw_rect(pr.grow(6.0), Color(0, 0, 0, 0.35 * a))
	view.draw_rect(pr, Color(0.03, 0.03, 0.035, a))
	Pal.band(view, Rect2(pr.position, Vector2(pr.size.x, 52.0)), 0.04 * a)
	view.draw_rect(pr, Pal.ink(0.22 * a), false, 1.0)
	# a red hairline along the top that breathes, and a faint scanline texture
	var glow := 0.55 + 0.45 * sin(t * 2.2)
	view.draw_line(pr.position + Vector2(18, 0), Vector2(pr.end.x - 18.0, pr.position.y), Pal.red(0.7 * glow * a, 2.2), 1.5)
	var sl := PackedVector2Array()
	var yy := pr.position.y + 60.0
	while yy < pr.end.y - 10.0:
		sl.append(Vector2(pr.position.x + 1.0, yy))
		sl.append(Vector2(pr.end.x - 1.0, yy))
		yy += 4.0
	view.draw_multiline(sl, Color(1, 1, 1, 0.012 * a), 1.0)
	for p: Vector2 in [pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]:
		var sx := 1.0 if p.x < pr.get_center().x else -1.0
		var sy := 1.0 if p.y < pr.get_center().y else -1.0
		view.draw_line(p, p + Vector2(16.0 * sx, 0), Pal.red(a, 2.0), 2.0)
		view.draw_line(p, p + Vector2(0, 16.0 * sy), Pal.red(a, 2.0), 2.0)
	var x := pr.position.x + PAD
	var w := W - PAD * 2.0
	# header: a pulsing dot, the word, and a close button
	var pulse := 0.6 + 0.4 * sin(t * 4.0)
	view.draw_circle(Vector2(x + 4.0, pr.position.y + 30.0), 3.5, Pal.red(pulse * a, 2.2))
	view.draw_string(font_b, Vector2(x + 18.0, pr.position.y + 36.0), "DEVELOPER", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(a))
	view.draw_string(font_s, Vector2(x + 128.0, pr.position.y + 36.0), Txt.t("devx_sub"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.45 * a))
	var cr := Rect2(pr.end.x - PAD - 26.0, pr.position.y + 16.0, 26.0, 26.0)
	_close_btn(cr, a)
	var y := pr.position.y + 64.0
	var heads := 0
	for i in rows.size():
		var r: Dictionary = rows[i]
		# rows arrive one after another
		var k := Pal.ease_out(Motion.stagger(t, i, 0.03, 0.35))
		var ra := a * k
		var dx := (1.0 - k) * -24.0
		match r.kind:
			"head":
				heads += 1
				view.draw_string(font_l, Vector2(x + dx, y + 25.0), "%02d" % heads, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.red(0.9 * ra, 1.6))
				view.draw_string(font_b, Vector2(x + dx + 26.0, y + 24.0), r.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.8 * ra))
				var lx0 := x + dx + 26.0 + font_b.get_string_size(r.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
				view.draw_line(Vector2(lx0, y + 20.0), Vector2(x + w, y + 20.0), Pal.ink(0.1 * ra), 1.0)
				view.draw_line(Vector2(x + w - 6.0, y + 17.0), Vector2(x + w, y + 20.0), Pal.ink(0.25 * ra), 1.0)
			"stat":
				view.draw_string(font_s, Vector2(x + dx, y + 15.0), r.get.call(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.55 * ra))
			"btns":
				var n: int = r.items.size()
				var bw := (w - (n - 1) * 8.0) / n
				for j in n:
					var it: Dictionary = r.items[j]
					_button(Rect2(x + dx + j * (bw + 8.0), y + 4.0, bw, 36.0), it.label, it.id, it.get("arg"), ra)
			"toggle":
				_toggle(Rect2(x + dx, y + 2.0, w, 34.0), r.label, r.id, r.get.call(), ra)
			"seg":
				_seg(Rect2(x + dx, y + 6.0, w, 32.0), r.options, r.id, r.get.call(), ra)
			"chips":
				var cw := (w - 3 * 8.0) / 4.0
				for j in r.items.size():
					var it2: Dictionary = r.items[j]
					var cx: float = x + dx + (j % 4) * (cw + 8.0)
					var cy: float = y + 4.0 + floorf(j / 4.0) * 58.0
					_chip(Rect2(cx, cy, cw, 50.0), it2, ra)
		y += _row_h(r)
	view.draw_string(font_s, Vector2(x, pr.end.y - 12.0), Txt.t("devx_keys"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.3 * a))
	if over:
		Pal.pointer(view, mouse, a)
	for rp in ripples:
		var e := Pal.ease_out(rp[1] / 0.5)
		view.draw_arc(rp[0], 6.0 + 50.0 * e, 0.0, TAU, 28, Pal.red((1.0 - e) * 0.8 * a, 2.0), 1.5, false)


func _close_btn(r: Rect2, a: float) -> void:
	regions.append([r, "__close", null])
	var h: float = _spring(hov, "__close", 0.0).x
	var c := r.get_center()
	view.draw_circle(c, 13.0, Color(1, 1, 1, 0.04 * h * a))
	var s := 5.0 + h
	var col := Pal.ink((0.5 + 0.5 * h) * a).lerp(Pal.red(a, 1.8), h)
	view.draw_set_transform(c, h * PI / 2.0, Vector2.ONE)
	view.draw_line(Vector2(-s, -s), Vector2(s, s), col, 1.6)
	view.draw_line(Vector2(-s, s), Vector2(s, -s), col, 1.6)
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# A rectangle with two opposite corners cut, the game's angular frame.
func _cut(r: Rect2, c: float = 8.0) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(c, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - c), r.end - Vector2(c, 0), Vector2(r.position.x, r.end.y), r.position + Vector2(0, c)])


func _cut_line(r: Rect2, col: Color, w: float = 1.0, c: float = 8.0) -> void:
	var pts := _cut(r, c)
	pts.append(pts[0])
	view.draw_polyline(pts, col, w, true)


func _button(r: Rect2, label: String, id: String, arg, a: float) -> void:
	regions.append([r, id, arg])
	var h: float = _spring(hov, id, 0.0).x
	var p: float = _spring(press, id, 0.0, 600.0, 0.35).x
	var pop: float = pops.get(id, 0.0)
	var k := 1.0 + 0.035 * p
	var c := r.get_center()
	var rr := Rect2(c - r.size * k / 2.0 + Vector2(0, -2.0 * h), r.size * k)
	view.draw_colored_polygon(_cut(rr), Color(1, 1, 1, (0.018 + 0.025 * h) * a))
	# hover: a red wash sweeps in from the left, a marker rises on the left edge
	var e := Pal.ease_out(clampf(h, 0.0, 1.0))
	if e > 0.01:
		var sw := Rect2(rr.position, Vector2(maxf(rr.size.x * e, 10.0), rr.size.y))
		var c0 := Pal.red(0.16 * a * e, 1.0)
		var c1 := Pal.red(0.0, 1.0)
		view.draw_polygon(PackedVector2Array([sw.position + Vector2(8, 0), Vector2(sw.end.x, sw.position.y), sw.end, Vector2(sw.position.x, sw.end.y), sw.position + Vector2(0, 8)]), PackedColorArray([c0, c1, c1, c0, c0]))
		view.draw_line(Vector2(rr.position.x + 1.0, rr.end.y - 6.0), Vector2(rr.position.x + 1.0, rr.end.y - 6.0 - (rr.size.y - 14.0) * e), Pal.red(a, 2.2), 2.0)
	if pop > 0.0:
		view.draw_colored_polygon(_cut(rr), Pal.red(0.35 * pop * a, 1.6))
	_cut_line(rr, Pal.ink((0.2 + 0.45 * h) * a).lerp(Pal.red(a, 1.8), pop), 1.0)
	var tw := font_s.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	view.draw_string(font_s, Vector2(c.x - tw / 2.0 - 5.0 * e, rr.position.y + rr.size.y / 2.0 + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink((0.72 + 0.28 * h) * a, 1.0 + 0.3 * h))
	# an arrow slides in on the right
	if e > 0.05:
		var ax := rr.end.x - 14.0 - 6.0 * (1.0 - e)
		var ay := rr.get_center().y
		view.draw_polyline(PackedVector2Array([Vector2(ax - 3.0, ay - 4.0), Vector2(ax + 1.0, ay), Vector2(ax - 3.0, ay + 4.0)]), Pal.red(e * a, 2.0), 1.5, true)


func _toggle(r: Rect2, label: String, id: String, on: bool, a: float) -> void:
	regions.append([r, id, null])
	var h: float = _spring(hov, id, 0.0).x
	var kn := _spring(knobs, id, 1.0 if on else 0.0, 420.0, 0.62)
	kn.target = 1.0 if on else 0.0
	if h > 0.02:
		Pal.band(view, r, 0.03 * h * a)
	view.draw_string(font_s, Vector2(r.position.x + 4.0 + 3.0 * h, r.position.y + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink((0.7 + 0.3 * h) * a))
	var kx: float = clampf(kn.x, -0.1, 1.1)
	var on_k := clampf(kx, 0.0, 1.0)
	# a rounded track that fills red from the left as it turns on
	var tl := Vector2(r.end.x - 44.0, r.position.y + 17.0)
	var tr2 := Vector2(r.end.x - 14.0, r.position.y + 17.0)
	var track := Pal.ink((0.12 + 0.06 * h) * a)
	view.draw_line(tl, tr2, track, 18.0)
	view.draw_circle(tl, 9.0, track)
	view.draw_circle(tr2, 9.0, track)
	if on_k > 0.01:
		var fe := tl.lerp(tr2, on_k)
		var fill := Pal.red(0.55 * a, 1.4)
		view.draw_line(tl, fe, fill, 18.0)
		view.draw_circle(tl, 9.0, fill)
		view.draw_circle(fe, 9.0, fill)
	var stretch := clampf(absf(kn.v) / 14.0, 0.0, 0.5)
	var kp := tl.lerp(tr2, kx)
	view.draw_circle(kp, 13.0, Pal.ink(0.05 * a, 1.0 + on_k))
	view.draw_set_transform(kp, 0.0, Vector2(1.0 + stretch, 1.0 - stretch * 0.3))
	view.draw_circle(Vector2.ZERO, 6.5, Pal.ink(a, 1.0 + 0.8 * on_k))
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	view.draw_string(font_b, Vector2(r.end.x - 92.0, r.position.y + 22.0), "ON" if on else "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, (Pal.red(a, 1.8) if on else Pal.ink(0.35 * a)))


func _seg(r: Rect2, options: Array, id: String, sel: int, a: float) -> void:
	var n := options.size()
	var cw := r.size.x / n
	var hs := _spring(seg_s, id, float(sel), 420.0, 0.68)
	hs.target = float(sel)
	view.draw_colored_polygon(_cut(r), Pal.ink(0.035 * a))
	_cut_line(r, Pal.ink(0.2 * a))
	var stretch := clampf(absf(hs.v) / 10.0, 0.0, 0.6)
	var hw := cw * (1.0 + stretch * 0.5) - 6.0
	var hx := r.position.x + hs.x * cw + (cw - hw) / 2.0
	var hr := Rect2(hx, r.position.y + 3.0, hw, r.size.y - 6.0)
	view.draw_colored_polygon(_cut(hr, 6.0), Pal.red(0.4 * a, 1.3))
	_cut_line(hr, Pal.red(a, 2.0), 1.0, 6.0)
	for j in n:
		var cr := Rect2(r.position.x + j * cw, r.position.y, cw, r.size.y)
		var oid := "%s:%d" % [id, j]
		regions.append([cr, id, j])
		var h: float = _spring(hov, oid, 0.0).x
		hov[oid].target = 1.0 if hover == id and cr.has_point(mouse) else 0.0
		var lab: String = options[j]
		var tw := font_s.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var on := j == sel
		view.draw_string(font_b if on else font_s, Vector2(cr.get_center().x - tw / 2.0, cr.position.y + 21.0 - 2.0 * h), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink((0.55 + 0.45 * maxf(h, 1.0 if on else 0.0)) * a))


func _chip(r: Rect2, it: Dictionary, a: float) -> void:
	var id: String = it.id
	regions.append([r, id, it.get("arg")])
	var h: float = _spring(hov, id, 0.0).x
	var lv: int = it.get.call()
	var pop: float = pops.get(id, 0.0)
	var rr := Rect2(r.position + Vector2(0, -2.0 * h), r.size)
	view.draw_colored_polygon(_cut(rr, 7.0), Color(1, 1, 1, (0.018 + 0.03 * h) * a))
	if pop > 0.0:
		view.draw_colored_polygon(_cut(rr, 7.0), Pal.red(0.3 * pop * a, 1.6))
	var maxed := 0.35 if lv >= 3 else 0.0
	_cut_line(rr, Pal.ink((0.16 + 0.4 * h) * a).lerp(Pal.red(a, 1.8), maxf(pop, maxed)), 1.0, 7.0)
	var lab: String = it.label
	var tw := font_s.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	view.draw_string(font_s, Vector2(rr.get_center().x - tw / 2.0, rr.position.y + 21.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink((0.72 + 0.28 * h) * a))
	# level: three diamonds that light red, the newest one hops
	for q in 3:
		var on := q < lv
		var hop := 4.0 * pop if on and q == lv - 1 else 0.0
		var dc := Vector2(rr.get_center().x - 16.0 + q * 16.0, rr.position.y + 36.0 - hop)
		var sz := 4.5 if on else 3.5
		var d := PackedVector2Array([dc + Vector2(0, -sz), dc + Vector2(sz, 0), dc + Vector2(0, sz), dc + Vector2(-sz, 0)])
		if on:
			view.draw_colored_polygon(d, Pal.red(a, 2.0))
		else:
			d.append(d[0])
			view.draw_polyline(d, Pal.ink(0.3 * a), 1.0, true)
