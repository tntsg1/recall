class_name Maglev
extends Node2D
# The superconducting line's floor (chapter 5): magnetic guide rails set into
# the floor inside the train's loop. Two groups take turns to power up, with a
# flicker first. A powered rail grips any round of yours that flies across it
# and turns it to run along the rail, so a shot can be bent onto the train's
# path; standing on one drags at your feet. While any rail is live the
# central express runs faster.

const WARN := 0.8
const PERIOD := 8.0
const LIVE := 4.0
const HALF_W := 18.0

var rails: Array = []     # [a, b, group]
var live := [false, false]
var warn := [0.0, 0.0]
var bend_flash: Array = []   # [point, t, dir]
var drag_cd := 0.0
var thrown: Array = []       # [bullet, from, t]: rounds a rail turned, drawn bold for a moment
var t := 0.0
var game


func _init() -> void:
	z_index = 2
	z_as_relative = false


func setup(room: int, story: int) -> void:
	rails.clear()
	bend_flash.clear()
	t = 0.0
	live = [false, false]
	warn = [0.0, 0.0]
	if room == 0 and story == 5:
		rails.append([Vector2(700, 540), Vector2(1220, 540), 0])
		rails.append([Vector2(960, 250), Vector2(960, 430), 1])
		rails.append([Vector2(960, 650), Vector2(960, 830), 1])
	visible = not rails.is_empty()
	queue_redraw()


# A generated room's guide rails ([a, b, group]); the groups take turns as ever.
func set_rails(list: Array) -> void:
	rails = list.duplicate(true)
	bend_flash.clear()
	t = 0.0
	live = [false, false]
	warn = [0.0, 0.0]
	visible = not rails.is_empty()
	queue_redraw()


func active() -> bool:
	return not rails.is_empty()


func any_lit() -> bool:
	return live[0] or live[1]


func step(dt: float) -> void:
	if rails.is_empty():
		return
	t += dt
	for g in 2:
		var ph := fmod(t + g * PERIOD * 0.5, PERIOD)
		var on := ph < LIVE
		var w := 0.0
		if ph > PERIOD - WARN:
			w = (ph - (PERIOD - WARN)) / WARN
		if on and not live[g] and game:
			game.sfx.play("lit", 0.5, -10.0)
		live[g] = on
		warn[g] = w
	# a powered rail drags at your feet
	if game:
		var p: Vector2 = game.player.pos
		for r in rails:
			if live[r[2]] and Geometry2D.get_closest_point_to_segment(p, r[0], r[1]).distance_to(p) < HALF_W + Player.R * 0.5:
				game.player.pos -= game.player.vel * dt * 0.45
				# the field drags: ripples at your feet while you push through
				drag_cd -= dt
				if drag_cd <= 0.0 and game.player.vel.length() > 40.0:
					drag_cd = 0.14
					game.fx.ring(p, 8.0, 34.0, 0.3, Pal.ink(0.45, 1.4), 1.5)
				break
	var j2 := 0
	while j2 < thrown.size():
		thrown[j2][2] += dt
		var tb2 = thrown[j2][0]
		if tb2.state == Bullets.EMBED and thrown[j2].size() < 4:
			thrown[j2].append(true)
			game.fx.flash(tb2.pos, 40.0, 0.14, Pal.ink(0.6, 2.0))
			game.fx.ring(tb2.pos, 6.0, 46.0, 0.3, Pal.ink(0.8, 1.8), 2.5)
			game.fx.sparks(tb2.pos, -tb2.dir, 8, Pal.ink(1.0, 2.0), 340.0, 0.2, 1.0)
			game.cam.add_trauma(0.06)
		if thrown[j2][2] > 1.4:
			thrown.remove_at(j2)
		else:
			j2 += 1
	var i := 0
	while i < bend_flash.size():
		bend_flash[i][1] += dt
		if bend_flash[i][1] > 0.35:
			bend_flash.remove_at(i)
		else:
			i += 1
	queue_redraw()


# A round flying a->b across a powered rail: where it is gripped and the way
# it is turned. Each rail grips a round once.
func cross(a: Vector2, b: Vector2, bullet) -> Dictionary:
	if not (live[0] or live[1]):
		return {}
	var best := {}
	var bt := INF
	var k := -1
	for r in rails:
		k += 1
		if not live[r[2]]:
			continue
		var key := "mg%d" % k
		if bullet.hit.has(key):
			continue
		var x = Geometry2D.segment_intersects_segment(a, b, r[0], r[1])
		if x == null:
			continue
		var d: Vector2 = ((r[1] as Vector2) - (r[0] as Vector2)).normalized()
		if absf(bullet.dir.dot(d)) > 0.97:
			continue
		var dist: float = a.distance_to(x)
		if dist < bt:
			bt = dist
			best = {"point": x, "dir": d if bullet.dir.dot(d) >= 0.0 else -d, "key": key}
	if not best.is_empty():
		bullet.hit[best.key] = true
	return best


func on_bend(at: Vector2, dir: Vector2 = Vector2.ZERO, bullet = null) -> void:
	bend_flash.append([at, 0.0, dir])
	if bullet != null:
		thrown.append([bullet, at, 0.0])
	game.fx.flash(at, 26.0, 0.12, Pal.ink(0.6, 2.0))
	game.fx.sparks(at, Vector2.UP, 3, Pal.ink(0.9, 1.8), 220.0, 0.15, PI)
	game.sfx.play("shield", randf_range(1.6, 1.8), -12.0)


func _draw() -> void:
	var f: float = game.focus if game else 0.0
	var dim := 1.0 - 0.45 * f
	# under the chapter's title card the rails stay dim
	if game and game.hud and game.hud.intro_t >= 0.0:
		dim *= clampf((game.hud.intro_t - 2.2) / 0.6, 0.25, 1.0)
	var now: float = game.real_time if game else t
	for r in rails:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var g: int = r[2]
		var d := (b - a).normalized()
		var n := d.orthogonal()
		var span := a.distance_to(b)
		# the bed: two conductor bars and the coils between them
		var bed := PackedVector2Array([a + n * HALF_W, b + n * HALF_W, b - n * HALF_W, a - n * HALF_W])
		draw_colored_polygon(bed, Color(0.05, 0.05, 0.055))
		var coils := PackedVector2Array()
		var s := 8.0
		while s < span - 4.0:
			coils.append(a + d * s + n * (HALF_W - 4.0))
			coils.append(a + d * s - n * (HALF_W - 4.0))
			s += 14.0
		var lit: bool = live[g]
		var w: float = warn[g]
		# in a generated room: no rungs (a belt has those) - two dark conductor
		# bars bolted down, and when it is powered a glowing core between them
		var gen: bool = game != null and game.arena.generated
		if gen:
			coils.clear()
			var bolt := 10.0
			while bolt < span - 6.0:
				for side2: float in [-1.0, 1.0]:
					draw_circle(a + d * bolt + n * HALF_W * side2, 1.8, Pal.ink(0.35 * dim))
				bolt += 40.0
			if lit:
				draw_colored_polygon(bed, Pal.ink(0.05 * dim, 1.2))
		else:
			draw_multiline(coils, Pal.ink((0.35 if lit else 0.14) * dim, 1.4 if lit else 1.0), 2.0)
		for side: float in [-1.0, 1.0]:
			draw_line(a + n * HALF_W * side, b + n * HALF_W * side, Pal.ink((0.65 if lit else 0.4) * dim, 1.4 if lit else 1.0), 2.0 if gen else 1.5)
		if lit:
			# powered: a thin bright core and chevrons running out from the middle
			# both ways, the way the field throws a round
			draw_line(a, b, Pal.ink(0.05 * dim, 1.2), 8.0)
			draw_line(a, b, Pal.ink(0.75 * dim, 1.6), 1.5)
			var chev := PackedVector2Array()
			var mid := span * 0.5
			var ps := fmod(now * 160.0, 46.0)
			while ps < mid:
				for sd: float in [-1.0, 1.0]:
					var q := a + d * (mid + sd * ps)
					var fw := d * sd
					var cw := 5.0 if game != null and game.arena.generated else 8.0
					chev.append(q - fw * 6.0 + n * cw)
					chev.append(q + fw * 2.0)
					chev.append(q + fw * 2.0)
					chev.append(q - fw * 6.0 - n * cw)
				ps += 92.0
			if chev.size() > 0:
				draw_multiline(chev, Pal.ink(0.7 * dim, 1.8), 3.0 if game != null and game.arena.generated else 2.0)
		elif w > 0.0:
			var fl := 0.5 + 0.5 * sin(now * (20.0 + 24.0 * w))
			draw_line(a, b, Pal.ink((0.15 + 0.5 * w) * fl * dim, 1.8), 1.5 + 2.0 * w)
		# end lamps
		for e: Vector2 in [a, b]:
			draw_circle(e, 7.0, Pal.WALL)
			draw_arc(e, 7.0, 0.0, TAU, 14, Pal.ink(0.55 * dim), 1.5)
			draw_circle(e, 3.0, Pal.ink((1.0 if lit else (0.8 * w if w > 0.0 else 0.2)) * dim, 2.4 if lit else 1.0))
	var calm: bool = game != null and game.arena.generated
	for th in thrown:
		var tb = th[0]
		var ka: float = 1.0 - th[2] / 1.4
		if calm:
			# a round sent along the rail: a fading tail, not a beam across the room
			var tail := (tb.pos as Vector2) - ((tb.pos as Vector2) - (th[1] as Vector2)).limit_length(220.0)
			draw_line(tail, tb.pos, Pal.ink(0.12 * ka * dim, 1.2), 5.0)
			draw_line(tail, tb.pos, Pal.ink(0.55 * ka * dim, 1.5), 2.0)
		else:
			draw_line(th[1], tb.pos, Pal.ink(0.2 * ka * dim, 1.4), 7.0)
			draw_line(th[1], tb.pos, Pal.ink(0.9 * ka * dim, 2.0), 3.0)
	for bf in bend_flash:
		var k: float = bf[1] / 0.35
		draw_arc(bf[0], 6.0 + 16.0 * k, 0.0, TAU, 16, Pal.ink((1.0 - k) * dim, 2.0), 2.0)
		var bd: Vector2 = bf[2]
		if bd != Vector2.ZERO:
			# an arrow runs off the turn, the way the round went
			var tip: Vector2 = bf[0] + bd * (20.0 + 90.0 * k)
			var bn := bd.orthogonal()
			draw_polyline(PackedVector2Array([tip - bd * 12.0 + bn * 9.0, tip, tip - bd * 12.0 - bn * 9.0]), Pal.ink((1.0 - k) * dim, 2.2), 3.0)
