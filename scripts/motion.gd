class_name Motion
# Shared motion for every piece of UI: springs that can be retargeted mid-flight
# (no restart, no snap), number rollers, and staggered timing. Everything is
# integrated with the real frame delta, so it looks the same at 60, 120 or
# 144 Hz.

# A 1-D spring. `stiff` sets speed, `damp` sets bounce (1.0 = no overshoot,
# below 1 = a little overshoot that settles).
class Spring:
	var x := 0.0
	var v := 0.0
	var target := 0.0
	var stiff := 260.0
	var damp := 0.75

	func _init(start: float = 0.0, k: float = 260.0, zeta: float = 0.75) -> void:
		x = start
		target = start
		stiff = k
		damp = zeta

	func step(dt: float) -> float:
		# sub-step long frames so a hitch never makes it explode
		var n := maxi(1, ceili(dt / (1.0 / 240.0)))
		var h := dt / n
		var c := 2.0 * damp * sqrt(stiff)
		for i in n:
			v += (-(x - target) * stiff - v * c) * h
			x += v * h
		return x

	func snap(val: float) -> void:
		x = val
		v = 0.0
		target = val

	func kick(impulse: float) -> void:
		v += impulse

	func settled() -> bool:
		return absf(x - target) < 0.001 and absf(v) < 0.01


class Spring2:
	var x := Vector2.ZERO
	var v := Vector2.ZERO
	var target := Vector2.ZERO
	var stiff := 260.0
	var damp := 0.75

	func _init(start: Vector2 = Vector2.ZERO, k: float = 260.0, zeta: float = 0.75) -> void:
		x = start
		target = start
		stiff = k
		damp = zeta

	func step(dt: float) -> Vector2:
		var n := maxi(1, ceili(dt / (1.0 / 240.0)))
		var h := dt / n
		var c := 2.0 * damp * sqrt(stiff)
		for i in n:
			v += (-(x - target) * stiff - v * c) * h
			x += v * h
		return x

	func snap(val: Vector2) -> void:
		x = val
		v = Vector2.ZERO
		target = val


# A number that rolls toward its value (counters, timers, volumes).
class Roller:
	var shown := 0.0
	var target := 0.0
	var speed := 12.0
	var pop := 0.0

	func _init(start: float = 0.0, rate: float = 12.0) -> void:
		shown = start
		target = start
		speed = rate

	func set_to(v: float) -> void:
		if not is_equal_approx(v, target):
			pop = 1.0
		target = v

	func step(dt: float) -> float:
		shown = lerpf(shown, target, 1.0 - exp(-speed * dt))
		if absf(shown - target) < 0.01:
			shown = target
		pop = maxf(0.0, pop - dt / 0.25)
		return shown


# An odometer: each character that changes rolls out while its successor
# rolls in (up for rising values, down for falling ones). Digits share one
# advance so a ticking number never jitters sideways.
class Odo:
	var text := ""
	var old: Array = []     # per character: [previous char, progress 0..1, direction]
	var dur := 0.16
	var lift_k := 0.62
	var still_tail := 0     # trailing characters that change too often to roll (tenths)

	func _init(rate: float = 0.16, lift: float = 0.62, tail: int = 0) -> void:
		dur = rate
		lift_k = lift
		still_tail = tail

	func set_text(s: String, dir: float = 1.0) -> void:
		if s == text:
			return
		var n := s.length()
		var shift := n - text.length()
		var next: Array = []
		for i in n:
			var j := i - shift
			var oc := text[j] if j >= 0 and j < text.length() else ""
			if i >= n - still_tail:
				next.append(["", 1.0, dir])
			elif oc == s[i]:
				next.append(old[j] if j >= 0 and j < old.size() else ["", 1.0, dir])
			else:
				next.append([oc, 0.0, dir])
		text = s
		old = next

	func step(dt: float) -> void:
		for o in old:
			o[1] = minf(1.0, o[1] + dt / dur)

	func busy() -> bool:
		for o in old:
			if o[1] < 1.0:
				return true
		return false

	# align: -1 left of x, 0 centred on x, 1 ending at x. y is the baseline.
	func draw(ci: CanvasItem, font: Font, x: float, y: float, size: int, col: Color, align: int = 0) -> void:
		var dw := font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var ws: Array = []
		var total := 0.0
		for ch in text:
			var w := dw if ch >= "0" and ch <= "9" else font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			ws.append(w)
			total += w
		var cx := x - total * (0.5 if align == 0 else (1.0 if align == 1 else 0.0))
		var lift := size * lift_k
		for i in text.length():
			var o: Array = old[i] if i < old.size() else ["", 1.0, 1.0]
			var p: float = o[1]
			var e := 1.0 - pow(1.0 - p, 3.0)
			var d: float = o[2]
			var ch: String = text[i]
			var w: float = ws[i]
			var nw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if p >= 1.0:
				ci.draw_string(font, Vector2(cx + (w - nw) * 0.5, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			else:
				var cn := Color(col.r, col.g, col.b, col.a * e)
				ci.draw_string(font, Vector2(cx + (w - nw) * 0.5, y + (1.0 - e) * lift * d), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, cn)
				var oc: String = o[0]
				if oc != "":
					var ow := font.get_string_size(oc, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
					var co := Color(col.r, col.g, col.b, col.a * (1.0 - e) * (1.0 - e))
					ci.draw_string(font, Vector2(cx + (w - ow) * 0.5, y - e * lift * d), oc, HORIZONTAL_ALIGNMENT_LEFT, -1, size, co)
			cx += w


# 0..1 for item i of a list that starts at time t0, each `gap` apart.
static func stagger(t: float, i: int, gap: float = 0.045, dur: float = 0.35) -> float:
	return clampf((t - i * gap) / dur, 0.0, 1.0)


# An ease-out-back with a gentle overshoot, handy for one-shot entrances.
static func out_back(x: float, k: float = 1.4) -> float:
	return Pal.back(x, k)
