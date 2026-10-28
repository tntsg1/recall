class_name Lasers
extends Node2D
# The laser range's fences (chapter 3): red beams strung between emitters.
# Two groups take turns; a group flickers for WARN seconds before it lights.
# A lit beam cuts you (a dash goes through) and burns any round of yours that
# crosses it; the burnt round comes straight back to the magazine, but it
# hits nothing on the way. Enemies walk through them: they were built here.
# The boss can hold every beam on during a test and drop them for its vents.

const WARN := 0.9
const PERIOD := 8.0
const LIVE := 3.2
const HURT_R := 6.0

var fences: Array = []    # [a, b, group]
var live := [false, false]
var warn := [0.0, 0.0]    # 0..1: how near a dark group is to lighting
var forced := -1          # -1 take turns; 0 every beam off; 1 every beam on
var force_t := 0.0
var t := 0.0
var game


func _init() -> void:
	z_index = 2
	z_as_relative = false


func setup(room: int) -> void:
	fences.clear()
	t = 0.0
	forced = -1
	live = [false, false]
	warn = [0.0, 0.0]
	if room == 5:
		# upper: from the side walls in to the two posts, the middle left open
		fences.append([Vector2(80, 420), Vector2(600, 420), 0])
		fences.append([Vector2(1320, 420), Vector2(1840, 420), 0])
		# lower: one long beam between the low posts, the sides left open
		fences.append([Vector2(420, 700), Vector2(1500, 700), 1])
	visible = not fences.is_empty()
	queue_redraw()


func active() -> bool:
	return not fences.is_empty()


func lit(g: int) -> bool:
	return live[g]


func any_lit() -> bool:
	return live[0] or live[1]


# The boss takes the beams over: all on (after the usual flicker) or all off.
func force(on: bool) -> void:
	var f := 1 if on else 0
	if forced != f:
		forced = f
		force_t = 0.0


# back to taking turns, the upper group first after its flicker
func release() -> void:
	if forced != -1:
		forced = -1
		t = PERIOD - WARN - 0.4


func step(dt: float) -> void:
	if fences.is_empty():
		return
	t += dt
	force_t += dt
	for g in 2:
		var on := false
		var w := 0.0
		match forced:
			-1:
				var ph := fmod(t + g * PERIOD * 0.5, PERIOD)
				on = ph < LIVE
				if ph > PERIOD - WARN:
					w = (ph - (PERIOD - WARN)) / WARN
			1:
				on = force_t >= WARN
				if not on:
					w = force_t / WARN
		if on and not live[g] and game:
			game.sfx.play("windup", 1.7, -13.0)
			for f in fences:
				if f[2] == g:
					game.fx.flash(f[0], 22.0, 0.12, Pal.red(0.8, 2.6))
					game.fx.flash(f[1], 22.0, 0.12, Pal.red(0.8, 2.6))
		live[g] = on
		warn[g] = w
	if game:
		_hurt()
	queue_redraw()


func _hurt() -> void:
	var p: Vector2 = game.player.pos
	if game.player.dash_t > 0.0:
		return
	for f in fences:
		if not live[f[2]]:
			continue
		var q := Geometry2D.get_closest_point_to_segment(p, f[0], f[1])
		if q.distance_to(p) < Player.R + HURT_R:
			var n: Vector2 = (f[1] - f[0]).orthogonal().normalized()
			if n.dot(p - q) < 0.0:
				n = -n
			if game.on_player_hit(n, null):
				game.fx.sparks(q, n, 8, Pal.red(1.0, 3.0), 380.0, 0.22, 1.0)
			# out of the beam either way, to the side you came from
			game.player.vel += n * 520.0
			return


# The nearest crossing of segment a->b with a lit beam: {} or {point, t}.
func cut(a: Vector2, b: Vector2) -> Dictionary:
	if not (live[0] or live[1]):
		return {}
	var best := {}
	var bt := 2.0
	var len := a.distance_to(b)
	if len < 0.001:
		return {}
	for f in fences:
		if not live[f[2]]:
			continue
		var x = Geometry2D.segment_intersects_segment(a, b, f[0], f[1])
		if x == null:
			continue
		var tt: float = a.distance_to(x) / len
		if tt < bt:
			bt = tt
			best = {"point": x, "t": tt}
	return best


func _draw() -> void:
	var now: float = game.real_time if game else t
	for f in fences:
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		var g: int = f[2]
		var d := (b - a).normalized()
		var n := d.orthogonal()
		if live[g]:
			# the beam: a hot core with a modest glow. Held on by the boss, the
			# glow drops further so its own attacks read over the fences.
			var soft := 0.55 if forced == 1 else 1.0
			if forced == 1:
				# held on through a test: a low steady line, so the boss's own
				# attacks read over it; it flares up only near you
				draw_line(a, b, Pal.red(0.5, 1.5), 2.0)
				if game:
					var pp: Vector2 = game.player.pos
					var q := Geometry2D.get_closest_point_to_segment(pp, a, b)
					var near := clampf(1.0 - (q.distance_to(pp) - 40.0) / 140.0, 0.0, 1.0)
					if near > 0.01:
						# brightest across from you, fading out either way
						var span4 := a.distance_to(b)
						var u := a.distance_to(q)
						for k in 12:
							var o0 := -180.0 + 30.0 * k
							var s0 := clampf(u + o0, 0.0, span4)
							var s1 := clampf(u + o0 + 30.0, 0.0, span4)
							if s1 - s0 < 1.0:
								continue
							var fall := pow(1.0 - absf(o0 + 15.0) / 195.0, 1.6) * near
							draw_line(a + d * s0, a + d * s1, Pal.red(0.1 * fall, 1.4), 12.0)
							draw_line(a + d * s0, a + d * s1, Pal.red(0.5 + 0.5 * fall, 1.5 + 1.5 * fall), 2.0 + 0.5 * fall)
			else:
				draw_line(a, b, Pal.red(0.08, 1.2), 12.0)
				draw_line(a, b, Pal.red(0.3, 1.6), 4.0)
				draw_line(a, b, Pal.red(1.0, 2.8), 2.0)
			var span := a.distance_to(b)
			var runs := PackedVector2Array()
			var s := fmod(now * 520.0, 90.0)
			while s < span:
				runs.append(a + d * s)
				runs.append(a + d * minf(span, s + 26.0))
				s += 90.0
			if runs.size() > 0:
				draw_multiline(runs, Pal.red(0.8 * soft, 3.0 * soft), 3.0 if forced != 1 else 2.0)
		elif warn[g] > 0.0:
			# about to light: a thick pulsing band and hatching on the floor either
			# side, both growing as it nears
			var w: float = warn[g]
			var fl := 0.5 + 0.5 * sin(now * (18.0 + 26.0 * w))
			draw_line(a, b, Pal.red((0.18 + 0.4 * w) * fl, 1.8), 2.0 + 4.0 * w)
			var span3 := a.distance_to(b)
			var hatch := PackedVector2Array()
			var s3 := 8.0
			while s3 < span3 - 8.0:
				for side: float in [-1.0, 1.0]:
					var q := a + d * s3 + n * side * 12.0
					hatch.append(q)
					hatch.append(q + n * side * 9.0 + d * 7.0)
				s3 += 18.0
			draw_multiline(hatch, Pal.red(0.15 + 0.35 * w, 1.3), 2.0)
		else:
			# dark: only a dotted guide where the beam will be
			var span2 := a.distance_to(b)
			var dots := PackedVector2Array()
			var s2 := 0.0
			while s2 < span2:
				dots.append(a + d * s2)
				dots.append(a + d * minf(span2, s2 + 6.0))
				s2 += 22.0
			draw_multiline(dots, Pal.red(0.16, 1.0), 1.0)
		for e: Vector2 in [a, b]:
			_emitter(e, d if e == a else -d, n, live[g], warn[g], now)


# an emitter: a dark housing on the wall or post, a lens that shows its state
func _emitter(at: Vector2, out: Vector2, n: Vector2, on: bool, w: float, now: float) -> void:
	var c := at - out * 6.0
	var pts := PackedVector2Array([c - n * 11.0 - out * 6.0, c + n * 11.0 - out * 6.0, c + n * 11.0 + out * 8.0, c - n * 11.0 + out * 8.0])
	draw_colored_polygon(pts, Pal.WALL)
	pts.append(pts[0])
	draw_polyline(pts, Pal.ink(0.55), 1.5)
	var lens := c + out * 8.0
	if on:
		draw_circle(lens, 7.0, Pal.red(0.3, 1.6))
		draw_circle(lens, 3.5, Pal.red(1.0, 3.6))
	elif w > 0.0:
		# charging: the lens swells and blinks faster as it nears
		var bl := 1.0 if fmod(now * (6.0 + 10.0 * w), 1.0) < 0.5 else 0.3
		draw_circle(lens, 4.0 + 5.0 * w, Pal.red(0.25 * w, 1.6))
		draw_circle(lens, 3.5, Pal.red(0.9 * bl, 2.6))
	else:
		draw_circle(lens, 3.0, Pal.red(0.25, 1.0))
