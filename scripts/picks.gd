class_name Picks
# Moves taken from the Motion Prompt library and redrawn in the game's ink:
# Motion Prompt #129 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#129
# Motion Prompt #023 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#023
# Motion Prompt #022 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#022
# Motion Prompt #188 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#188
# Motion Prompt #003 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#003
# Their timings, easings and amounts are the library's; the colours are the
# game's (its coral is our red, its yellow our white ink, its mint our dim ink).
# The full game only: the callers ask Demo.extras().

const CYAN := Color(0.17, 0.77, 0.84)


static func _p(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func _eio(x: float) -> float:
	return 2.0 * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0


static func _h01(n: int) -> float:
	var h := hash(n)
	return float(h & 0xffff) / 65535.0


# ------------------------------------------------------------ #129 text scramble
# Unsettled letters flick through A–Z (no I, O), 0–9 and #$%&@? every 0.062 s at
# 75 %; they lock left to right, slot i at 0.45 + 0.18 i s (closer together on a
# long line, so the last still locks by 1.17 s + its length's share); a newly
# locked letter takes the theme colour for 0.22 s (the library's yellow; not
# brighter, or the glow reads it as bolder) and settles from scale 1.2
# (1 + 0.2 e^(−14 t)).
const SCR_GL := "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#$%&@?"


static func scramble_done(text: String) -> float:
	return 0.45 + _scr_step(text.length()) * text.length()


static func _scr_step(n: int) -> float:
	return minf(0.18, 1.1 / maxf(1.0, n))


# `t`: seconds since it began. `center`: true centres the line on `pos.x`.
static func scramble(ci: CanvasItem, font: Font, text: String, pos: Vector2, size: int, c: Color, t: float, center: bool = true) -> void:
	var n := text.length()
	var widths: Array = []
	var total := 0.0
	for ch in text:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(w)
		total += w
	var x := pos.x - (total / 2.0 if center else 0.0)
	var step := int(floor(t / 0.062))
	var gap := _scr_step(n)
	# a Chinese line flicks through its own characters: the same width and weight
	# as what locks in, and every one of them is in the font
	var pool := SCR_GL
	if text.unicode_at(0) > 0x2e80 or (n > 1 and text.unicode_at(1) > 0x2e80):
		pool = text.replace(" ", "")
	for i in n:
		var ch := text[i]
		var w: float = widths[i]
		var tl := 0.45 + i * gap
		if ch == " ":
			x += w
			continue
		if t >= tl:
			var age := t - tl
			var sc := 1.0 + 0.2 * exp(-age * 14.0)
			var col := c
			if age < 0.22:
				col = Pal.red(c.a)
			ci.draw_set_transform(Vector2(x + w / 2.0, pos.y - size * 0.35), 0.0, Vector2(sc, sc))
			ci.draw_string(font, Vector2(-w / 2.0, size * 0.35), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif t >= 0.0:
			var g := pool[int(_h01(step * 131 + i * 977) * pool.length()) % pool.length()]
			var gw := font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			ci.draw_string(font, Vector2(x + (w - gw) / 2.0, pos.y), g, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c.r, c.g, c.b, c.a * 0.75))
		x += w


# ------------------------------------------------------------ #023 glitch
# Five steps of 0.14 s from 0.55 s, each one fixed disturbance: the text's red
# copy 7–16 px left and 2 px down, a cyan copy as far right and 2 px up, the
# text itself thrown 18–64 px sideways in part, three small bars (red, cyan,
# ink; 30–120 × 5–12). The brightness of the frame never changes.
# The step at `t`, or -1 outside the five.
static func glitch_step(t: float) -> int:
	if t >= 0.55 and t < 0.55 + 0.14 * 5.0:
		return int((t - 0.55) / 0.14)
	return -1


# How far the text itself is thrown at step `s` (the strips the library slides
# are, here, the whole line in one of two directions). Every amount is the
# library's for its 104 px text, scaled to `size`.
static func glitch_shift(s: int, size: int) -> float:
	if s < 0 or _h01(s * 7 + 231) < 0.45:
		return 0.0
	return (-1.0 if _h01(s * 13 + 231) < 0.5 else 1.0) * (18.0 + _h01(s * 17 + 231) * 46.0) * size / 104.0 * 0.5


# The copies and the bars, drawn under (copies) and over (bars) the text's own line.
static func glitch(ci: CanvasItem, font: Font, text: String, center: Vector2, size: int, a: float, s: int) -> void:
	if s < 0:
		return
	var u := size / 104.0
	var rgb := (7.0 + roundf(_h01(s * 3 + 231) * 9.0)) * u
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(center.x - w / 2.0, center.y)
	ci.draw_string(font, base + Vector2(-rgb, 2.0 * u), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Pal.red(0.8 * a, 1.6))
	ci.draw_string(font, base + Vector2(rgb, -2.0 * u), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(CYAN.r, CYAN.g, CYAN.b, 0.75 * a))
	var cols := [Pal.red(0.9 * a, 1.6), Color(CYAN.r, CYAN.g, CYAN.b, 0.85 * a), Pal.ink(0.9 * a, 1.3)]
	for i in 3:
		var bx := base.x - 40.0 * u + _h01(s * 41 + i * 5) * (w + 80.0 * u)
		# just above the letters or just under them, never across their middle
		var by := center.y - size * 1.05 if _h01(s * 43 + i * 7) < 0.5 else center.y + size * 0.18
		ci.draw_rect(Rect2(bx, by, (30.0 + _h01(s * 47 + i) * 90.0) * u, (5.0 + _h01(s * 53 + i) * 7.0) * u), cols[i])


# ------------------------------------------------------------ #022 light sweep
# One pass per 2.35 s inside `r`: a 116 px band (0.72 at its middle, 0 at its
# edges) and a 12 px band (0.5) 78 px behind it, tilted 0.42 rad, crossing from
# 130 px before `r` to 130 px past it at 0.45–1.5 s, quadratic ease-in-out; a
# four-point glint at its far corner at 1.38–1.98 s.
static func sweep(ci: CanvasItem, r: Rect2, u: float, a: float) -> void:
	var lu := fposmod(u, 2.35)
	var p := _eio(_p(lu, 0.45, 1.5))
	if p > 0.0 and p < 1.0:
		var cx := lerpf(r.position.x - 130.0, r.end.x + 130.0, p)
		_band(ci, r, cx, 58.0, 0.72 * a, true)
		_band(ci, r, cx + 84.0, 6.0, 0.5 * a, false)
	var tt := lu - 1.38
	if tt > 0.0 and tt < 0.6:
		var q := tt / 0.6
		var sc := sin(PI * q) * (1.0 + 0.2 * (1.0 - q)) * 0.6
		var c := r.end - Vector2(8.0, r.size.y - 6.0)
		var pts := PackedVector2Array()
		for k in 8:
			var ang := q * 0.9 + k * PI / 4.0
			pts.append(c + Vector2.from_angle(ang) * (30.0 if k % 2 == 0 else 6.6) * sc)
		ci.draw_colored_polygon(pts, Pal.ink(a, 1.8))


# A slanted band of half-width `hw` centred on x = `cx`, clipped to `r`;
# soft edges fade to nothing, a hard one is flat.
static func _band(ci: CanvasItem, r: Rect2, cx: float, hw: float, a: float, soft: bool) -> void:
	var sk := tan(0.42) * r.size.y / 2.0
	var cy := r.get_center().y
	var rect := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var halves := [[-hw, 0.0], [0.0, hw]] if soft else [[-hw, hw]]
	for h in halves:
		var x0: float = cx + h[0]
		var x1: float = cx + h[1]
		var quad := PackedVector2Array([Vector2(x0 + sk, r.position.y), Vector2(x1 + sk, r.position.y), Vector2(x1 - sk, r.end.y), Vector2(x0 - sk, r.end.y)])
		for poly in Geometry2D.intersect_polygons(rect, quad):
			var cols := PackedColorArray()
			for v in poly:
				# how far across the band this corner is: 0 at its middle
				var mid := cx - (v.y - cy) * tan(0.42)
				var d := absf(v.x - mid) / hw if soft else 0.0
				cols.append(Pal.ink(a * clampf(1.0 - d, 0.0, 1.0), 1.4))
			ci.draw_polygon(poly, cols)


# ------------------------------------------------------------ #188 iris out
# The circle closes on the subject, quadratic ease-in-out, black outside it, a
# 2 px rim while it is open. The library takes 1.4 s; here 1.2 s, the time the
# run's summary waits, so it is shut before the summary comes up.
static func iris(ci: CanvasItem, vp: Vector2, center: Vector2, t: float, r_end: float, a: float) -> void:
	if t <= 0.0:
		return
	var far := vp.length()
	var rad := lerpf(far, r_end, _eio(_p(t, 0.0, 1.2)))
	var black := Color(0.0, 0.0, 0.0, a)
	ci.draw_arc(center, (rad + far * 1.5) / 2.0, 0.0, TAU, 96, black, far * 1.5 - rad, false)
	if rad > 1.0 and rad < far:
		ci.draw_arc(center, rad, 0.0, TAU, maxi(32, int(rad * 0.4)), Pal.red(0.9 * a, 1.3), 2.0, true)


# ------------------------------------------------------------ #003 burst
# At the trigger a ring opens 44 → 90 while its line goes 16 → 0 (0.6 s,
# quintic ease-out); 10 radial lines push out 64 → 130 (y × 0.82), shrinking
# away 0.22–0.7 s; 10 dots fly 58 → 150 on an ellipse (x × 1.45, y × 0.78),
# fading 0.3–0.72 s. `tt`: seconds since the trigger; `k`: its scale.
static func burst(ci: CanvasItem, c: Vector2, tt: float, k: float, a: float) -> void:
	if tt <= 0.0 or tt >= 0.75:
		return
	var q := 1.0 - pow(1.0 - minf(1.0, tt / 0.6), 5.0)
	var fade := 1.0 - _p(tt, 0.3, 0.72)
	if q < 0.98:
		ci.draw_arc(c, (44.0 + 46.0 * q) * k, 0.0, TAU, 48, Pal.ink(0.9 * a, 1.6), maxf(0.5, 16.0 * (1.0 - q) * k), true)
	for i in 10:
		var ang := i / 10.0 * TAU - PI / 2.0
		var r1 := (64.0 + 66.0 * q) * k
		var ln := 36.0 * (1.0 - _p(tt, 0.22, 0.7)) * k
		var col := Pal.ink(0.9 * a, 1.6) if i % 2 == 0 else Pal.red(0.9 * a, 1.8)
		if ln > 0.5:
			var dir := Vector2(cos(ang), sin(ang) * 0.82)
			ci.draw_line(c + dir * (r1 - ln), c + dir * r1, col, 9.0 * k * 0.5, true)
		var a2 := ang + PI / 10.0
		var r2 := (58.0 + 92.0 * q) * k
		var dc := Pal.red(fade * a, 1.6) if i % 2 == 0 else Color(CYAN.r, CYAN.g, CYAN.b, fade * a)
		ci.draw_circle(c + Vector2(cos(a2) * r2 * 1.45, sin(a2) * r2 * 0.78), 8.0 * (1.0 - q * 0.4) * k, dc)
