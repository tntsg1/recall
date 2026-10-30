class_name Vents
extends Node2D
# The orbital lift's car (chapter 9): airlock doors in the side walls. In
# turn one is marked (red hazard stripes, its warning lit), then opens, and
# the air rushes out through it: you, the enemies and every round in flight
# are drawn toward the gap; an enemy drawn into it is gone. Rounds lying in
# the walls near an open door are torn loose and fly to it, so the rounds a
# door has gathered come home from one place.

const DOORS := [[Vector2(80, 330), Vector2(1, 0)], [Vector2(1840, 760), Vector2(-1, 0)], [Vector2(80, 760), Vector2(1, 0)], [Vector2(1840, 330), Vector2(-1, 0)]]
const HALF := 62.0           # half the door's width along the wall
const PERIOD := 6.5
const WARN := 1.3
const OPEN := 2.8
const R := 560.0             # how far the draught reaches
const PULL := 300.0          # px/s at the door
const LOOSE_R := 300.0       # rounds in the walls this near an open door tear loose
const MOUTH := 44.0

var on := false
var game
var doors: Array = DOORS.duplicate(true)   # [centre on the wall, normal into the room]
var t := 0.0
var clock := 0.0
var door := -1               # the door marked or open, -1 none
var door_t := 0.0            # 0..WARN warning, WARN..WARN+OPEN open
var turn := 0
var streaks: Array = []      # [pos, life]: air rushing to the door


func _init() -> void:
	z_index = 2
	z_as_relative = false


func setup(story: int) -> void:
	on = story == 9
	set_doors(DOORS)


# The airlock doors this room has (the hand-made car: four, at DOORS).
func set_doors(list: Array) -> void:
	doors = list.duplicate(true)
	visible = on and not doors.is_empty()
	t = 0.0
	clock = 2.0
	door = -1
	door_t = 0.0
	turn = 0
	streaks.clear()
	queue_redraw()


func active() -> bool:
	return on


func open_k() -> float:
	if door < 0 or door_t < WARN:
		return 0.0
	var k := door_t - WARN
	return clampf(k / 0.3, 0.0, 1.0) * clampf((OPEN - k) / 0.4, 0.0, 1.0)


func door_pos(i: int) -> Vector2:
	return doors[i][0]


# The draught at a point, as a velocity toward the open door.
func force_at(p: Vector2) -> Vector2:
	var k := open_k()
	if k <= 0.0:
		return Vector2.ZERO
	var d: Vector2 = door_pos(door) - p
	var l := d.length()
	if l >= R or l < 0.001:
		return Vector2.ZERO
	return d / l * PULL * pow(1.0 - l / R, 1.2) * k


# A round in flight bends into the draught; its path takes a new point each
# time it has turned a little, so the way home follows the curve.
func pull_round(b, dt: float) -> void:
	var f := force_at(b.pos)
	if f == Vector2.ZERO:
		return
	var want: Vector2 = (b.dir * Bullets.SPEED + f * 15.0 * dt).normalized()
	var ang: float = absf(b.dir.angle_to(want))
	if ang < 0.0005:
		return
	b.curve_acc += ang
	if b.curve_acc > 0.06 and b.path.size() < 40:
		b.curve_acc = 0.0
		b.set_head(b.pos)
		b.path.append(b.pos)
		b.cum.append(b.cum[b.cum.size() - 1])
		b.set_head(b.pos)
	b.dir = want


func step(dt: float) -> void:
	if not on or doors.is_empty():
		return
	t += dt
	var fighting: bool = game.wave_ctl.phase == Waves.FIGHT and game.hud.intro_t < 0.0
	if door < 0:
		if fighting:
			clock += dt
		if clock >= PERIOD:
			clock = 0.0
			# the doors take turns, but never the one you stand by
			door = turn % doors.size()
			turn += 1
			if door_pos(door).distance_to(game.player.pos) < 260.0:
				door = turn % doors.size()
				turn += 1
			door_t = 0.0
			game.sfx.play("windup", 0.45, -6.0)
	else:
		var was := door_t
		door_t += dt
		if was < WARN and door_t >= WARN:
			game.sfx.play("release", 0.4, -2.0)
			game.cam.add_trauma(0.25)
		if door_t >= WARN + OPEN:
			door = -1
			game.sfx.play("slam", 0.55, -6.0)
	var k := open_k()
	if k > 0.0:
		_draught(dt, k)
	var i := 0
	while i < streaks.size():
		streaks[i][1] -= dt
		var p: Vector2 = streaks[i][0]
		var f := force_at(p)
		streaks[i][0] = p + f * dt * 3.2
		if streaks[i][1] <= 0.0 or (door >= 0 and p.distance_to(door_pos(door)) < 30.0):
			streaks.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _draught(dt: float, k: float) -> void:
	var dp: Vector2 = door_pos(door)
	var n: Vector2 = doors[door][1]
	# you lean against it
	var pl: Vector2 = game.player.pos
	if not game.possess.hosting():
		var np: Vector2 = game.arena.push_circle(pl + force_at(pl) * dt, Player.R)
		game.player.pos = np
		if np.distance_to(dp) < MOUTH + Player.R and game.player.dash_t <= 0.0:
			game.on_player_hit(n, null)
			game.player.pos = dp + n * 140.0
	# enemies are drawn out through it
	for e in game.enemies.list:
		if e.state != Enemies.ALIVE:
			continue
		e.pos = game.arena.push_circle(e.pos + force_at(e.pos) * dt * 1.3, e.r)
		if e.pos.distance_to(dp) < MOUTH + e.r:
			# out through the door: a flash at the gap, its pieces flung into space
			game.fx.sparks(e.pos, -n, 10, Pal.foe(1.0, 1.8), 620.0, 0.35, 0.5)
			game.fx.ring(dp, 10.0, 70.0, 0.3, Pal.foe(0.8, 1.6), 2.0)
			game.sfx.play("cross", 0.5, -6.0)
			game.enemies.blast_hit(e, -n, 9999.0)
	# rounds in the walls near it tear loose and fly to it
	for b in game.bullets.list:
		if b.state != Bullets.EMBED or b.foe:
			continue
		var d: float = b.pos.distance_to(dp)
		if d < LOOSE_R and d > HALF + 20.0 and randf() < dt * 2.2 * k:
			# off the wall first, so its way to the door crosses the floor
			var wn: Vector2 = (Arena.ROOM.get_center() - b.pos).normalized()
			var off: Vector2 = b.pos + wn * 16.0
			b.set_head(b.pos)
			b.path.append(off)
			b.cum.append(b.cum[b.cum.size() - 1])
			b.set_head(off)
			b.pos = off
			var aim: Vector2 = dp + Vector2(absf(n.y), absf(n.x)) * randf_range(-0.6, 0.6) * HALF
			b.dir = (aim - b.pos).normalized()
			b.state = Bullets.FLY
			b.bounces = 0
			b.t = 0.0
			b.shelf = -1
			b.settled = false
			game.bullets.faint_dirty = true
	# streaks of air along the floor
	if randf() < dt * 40.0 * k:
		var a := randf() * TAU
		var q: Vector2 = dp + Vector2.from_angle(a) * randf_range(120.0, R)
		if Arena.ROOM.grow(-10.0).has_point(q):
			streaks.append([q, randf_range(0.5, 0.9)])


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not on:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if game.hud.intro_t >= 0.0:
		dim *= clampf((game.hud.intro_t - 2.2) / 0.6, 0.25, 1.0)
	for i in doors.size():
		_draw_door(i, dim)
	# air rushing to the door
	var seg := PackedVector2Array()
	for s in streaks:
		var p: Vector2 = s[0]
		var fv := force_at(p)
		if fv.length() < 1.0:
			continue
		var d := fv.normalized()
		seg.append(p)
		seg.append(p - d * minf(56.0, fv.length() * 0.3))
		seg.append(p)
		seg.append(p - d * 8.0 + d.orthogonal() * 5.0)
		seg.append(p)
		seg.append(p - d * 8.0 - d.orthogonal() * 5.0)
	if seg.size() > 0:
		draw_multiline(seg, Pal.ink(0.38 * dim, 1.2), 1.5)
	# whatever is being drawn in wears a small arrow toward the door
	if open_k() > 0.0:
		var marks := PackedVector2Array()
		for b in game.bullets.list:
			if b.state == Bullets.FLY and not b.foe:
				_arrow(marks, b.pos, force_at(b.pos))
		for e in game.enemies.list:
			if e.state == Enemies.ALIVE:
				_arrow(marks, e.pos + Vector2(0, -e.r - 10.0), force_at(e.pos))
		if marks.size() > 0:
			draw_multiline(marks, Pal.ink(0.7 * dim, 1.4), 2.5)


func _arrow(out: PackedVector2Array, p: Vector2, f: Vector2) -> void:
	if f.length() < 30.0:
		return
	var d := f.normalized()
	var tip := p + d * 22.0
	out.append(p + d * 4.0)
	out.append(tip)
	out.append(tip)
	out.append(tip - d * 6.0 + d.orthogonal() * 4.0)
	out.append(tip)
	out.append(tip - d * 6.0 - d.orthogonal() * 4.0)


func _draw_door(i: int, dim: float) -> void:
	var c: Vector2 = doors[i][0]
	var n: Vector2 = doors[i][1]
	var along := Vector2(absf(n.y), absf(n.x))
	var marked := door == i
	var warn_k := clampf(door_t / WARN, 0.0, 1.0) if marked else 0.0
	var ok := open_k() if marked else 0.0
	var fl := 0.55 + 0.45 * sin(t * (12.0 + 16.0 * warn_k))
	# (a generated room's doors stand deeper out, the gap a pit of space)
	var deep := 64.0 if game.arena.generated else 40.0
	# the housing, standing out from the wall
	var house := Rect2(c - along * (HALF + 18.0) - n * 6.0, Vector2.ZERO).expand(c + along * (HALF + 18.0) + n * deep)
	draw_rect(house, Color(0.05, 0.05, 0.055))
	draw_rect(house, Pal.ink(0.6 * dim), false, 2.0)
	draw_rect(house.grow(-5.0), Pal.ink(0.2 * dim), false, 1.0)
	# open: the gap, and the dark beyond it, the stars streaming past
	var gap := HALF * ok
	if ok > 0.0:
		var hole := Rect2(c - along * gap - n * 6.0, Vector2.ZERO).expand(c + along * gap + n * (deep - 10.0))
		draw_rect(hole, Color(0.0, 0.0, 0.0, 1.0))
		draw_rect(hole, Pal.red(0.5 * ok * dim, 1.3), false, 2.0)
		# out there: stars streaming past the gap
		for s2 in 22:
			var u := fmod(t * 2.4 + s2 * 0.29, 1.0)
			var q := c + along * (sin(s2 * 2.3) * gap * 0.85) + n * ((deep - 10.0) * (1.0 - u) - 4.0 * u)
			if absf((q - c).dot(along)) < gap - 2.0:
				draw_line(q, q + n * (8.0 + 14.0 * u), Pal.ink((0.95 - 0.5 * u) * ok * dim, 2.2), 1.5)
				draw_circle(q, 1.4, Pal.ink(ok * dim, 2.4))
		# rings closing on the gap across the floor before it
		for rk in 3:
			var ru := fmod(t * 1.2 + rk / 3.0, 1.0)
			draw_arc(c, 40.0 + 220.0 * (1.0 - ru), (-n).angle() + PI * 0.5 + 0.1, (-n).angle() + PI * 1.5 - 0.1, 32, Pal.ink(0.22 * ru * ok * dim, 1.2), 1.5)
	# the two panels, sliding apart into the housing
	for sd: float in [-1.0, 1.0]:
		var inner := c + along * sd * gap
		var outer := c + along * sd * (HALF + gap * 0.25)
		if (outer - inner).dot(along * sd) < 6.0:
			continue
		var pr := Rect2(inner - n * 2.0, Vector2.ZERO).expand(outer + n * (deep - 10.0))
		draw_rect(pr, Color(0.09, 0.09, 0.095))
		draw_rect(pr, Pal.ink(0.65 * dim), false, 1.5)
		var mid := (inner + outer) * 0.5
		draw_line(mid + n * 6.0, mid + n * 24.0, Pal.ink(0.4 * dim), 3.0)
	# the seam's warning lamps at both ends
	for sd2: float in [-1.0, 1.0]:
		var lp := c + along * sd2 * (HALF + 10.0) + n * (deep - 6.0)
		var lit := marked and door_t < WARN + OPEN
		draw_circle(lp, 5.0, Color(0.06, 0.02, 0.02))
		draw_circle(lp, 3.5, Pal.red((0.9 * fl if lit else 0.15) * dim, 2.0 if lit else 1.0))
	if not marked or door_t >= WARN + OPEN:
		return
	# hazard stripes across the floor before it
	var a := (0.35 + 0.5 * warn_k) * fl * dim if ok <= 0.0 else 0.7 * dim
	var hatch := PackedVector2Array()
	for j in 9:
		var q0 := c + along * (-HALF - 10.0 + j * (HALF * 2.0 + 20.0) / 8.0) + n * (deep + 8.0)
		hatch.append(q0)
		hatch.append(q0 + n * 34.0 + along * 18.0)
	draw_multiline(hatch, Pal.red(a * 0.8, 1.15), 4.0)
	if ok <= 0.0:
		# the reach of the draught, marked while it is still shut
		# (only what lies in the room: cut where the arc would leave it)
		var reach := R * (0.4 + 0.58 * warn_k)
		var a0 := (-n).angle() + PI * 0.5 + 0.05
		var a1 := (-n).angle() + PI * 1.5 - 0.05
		var arc := PackedVector2Array()
		var inside := Rect2(Arena.ROOM.position + Vector2(4, 4), Arena.ROOM.size - Vector2(8, 34))
		for s3 in 65:
			var q3 := c + Vector2.from_angle(lerpf(a0, a1, s3 / 64.0)) * reach
			if inside.has_point(q3):
				arc.append(q3)
			elif arc.size() > 1:
				draw_polyline(arc, Pal.red(0.3 * fl * dim, 1.2), 2.5)
				arc = PackedVector2Array()
			else:
				arc = PackedVector2Array()
		if arc.size() > 1:
			draw_polyline(arc, Pal.red(0.3 * fl * dim, 1.2), 2.5)
		var font := Fonts.get_font("SemiBold")
		var lab := Txt.t("vent_warn")
		var fs := 18
		var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := c + n * (deep + 64.0) + Vector2(0 if n.x > 0.0 else -lw, 6.0)
		draw_rect(Rect2(at + Vector2(-8, -fs - 2.0), Vector2(lw + 16, fs + 12)), Color(0.05, 0.0, 0.0, 0.85))
		draw_rect(Rect2(at + Vector2(-8, -fs - 2.0), Vector2(lw + 16, fs + 12)), Pal.red(0.5 * dim, 1.3), false, 1.0)
		draw_string(font, at, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.red((0.6 + 0.4 * fl) * dim, 1.6))
