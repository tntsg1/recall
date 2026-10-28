class_name Arms
extends Node2D
# The production union's floor (chapter 4): robot arms on the walls and the
# strategic reserve crate. Each arm in turn rises, marks the floor it will
# sweep, then sweeps it: it cuts you (a dash goes through) and plucks every
# round of yours embedded in that sector, carrying it off to the reserve crate.
# The round is not lost: it sits in the crate's wall, and a recall still
# brings it home, along a line from where you fired it to the crate.
# In the testbed-style last phase of the boss ("full-capacity production") the
# arms feed what the crate holds into the intake's mouth and shove enemies in.
# The belts are only the floor's motion; they carry ration boxes, not you.

enum { REST, RISE, SWEEP, BACK }

const L := 320.0
const HALF := deg_to_rad(92.0)   # the whole half-disc and a little more: the wall either side is in reach
const RISE_TIME := 1.0
const SWEEP_TIME := 0.85
const BACK_TIME := 1.0
const PERIOD := 9.0
const CARRY := 0.65
const CRATE := Rect2(220, 840, 190, 100)

var arms: Array = []      # {base, face, offset, mode, t, a, prev}
var carry: Array = []     # [bullet, from, to, t, feed]
var crate: Array = []     # rounds sitting in the crate's wall
var belts: Array = []     # [from, to]
var t := 0.0
var feed_cd := 0.0
var game


func _init() -> void:
	z_index = 2
	z_as_relative = false


func setup(room: int) -> void:
	arms.clear()
	carry.clear()
	crate.clear()
	belts.clear()
	t = 0.0
	feed_cd = 6.0
	if room == 2:
		for spec in [[Vector2(80, 540), Vector2.RIGHT, 0.0], [Vector2(1840, 540), Vector2.LEFT, 3.0], [Vector2(1400, 1010), Vector2.UP, 6.0]]:
			var face: Vector2 = spec[1]
			arms.append({"base": spec[0], "face": face, "offset": spec[2], "mode": REST, "t": 0.0, "a": _rest(face), "prev": _rest(face)})
		belts.append([Vector2(250, 290), Vector2(760, 290)])
		belts.append([Vector2(1640, 290), Vector2(1160, 290)])
		belts.append([Vector2(560, 965), Vector2(1270, 965)])
	visible = not arms.is_empty()
	queue_redraw()


func active() -> bool:
	return not arms.is_empty()


func _rest(face: Vector2) -> float:
	# folded flat along its wall
	return face.angle() - PI / 2.0


func step(dt: float) -> void:
	if arms.is_empty():
		return
	t += dt
	var fighting: bool = game.wave_ctl.phase == Waves.FIGHT
	var full := _full_capacity()
	for arm in arms:
		var face: Vector2 = arm.face
		var a0: float = face.angle() - HALF
		var a1: float = face.angle() + HALF
		arm.prev = arm.a
		arm.t += dt
		match arm.mode:
			REST:
				arm.a = lerp_angle(arm.a, _rest(face), 1.0 - exp(-6.0 * dt))
				var ph := fmod(t + PERIOD - arm.offset, PERIOD)
				if fighting and ph < dt * 1.5 and t > 1.5:
					arm.mode = RISE
					arm.t = 0.0
					game.sfx.play("windup", 0.8, -9.0)
			RISE:
				arm.a = lerp_angle(_rest(face), a0, Pal.ease_io(clampf(arm.t / 0.4, 0.0, 1.0)))
				if arm.t >= RISE_TIME:
					arm.mode = SWEEP
					arm.t = 0.0
					game.sfx.play("dash_e", 0.6, -4.0)
			SWEEP:
				arm.a = lerpf(a0, a1, Pal.ease_io(clampf(arm.t / SWEEP_TIME, 0.0, 1.0)))
				_sweep(arm, full)
				if arm.t >= SWEEP_TIME:
					arm.mode = BACK
					arm.t = 0.0
			BACK:
				arm.a = lerp_angle(a1, _rest(face), Pal.ease_io(clampf(arm.t / BACK_TIME, 0.0, 1.0)))
				if arm.t >= BACK_TIME:
					arm.mode = REST
					arm.a = _rest(face)
	_step_carry(dt)
	if full:
		feed_cd -= dt
		if feed_cd <= 0.0:
			feed_cd = 6.0
			_feed()
	queue_redraw()


func _full_capacity() -> bool:
	return game.boss is Devourer and game.boss.state == Devourer.RUN and game.boss.phase >= 2


func claw(arm: Dictionary) -> Vector2:
	return (arm.base as Vector2) + Vector2.from_angle(arm.a) * L


# The swept slice since last frame: you, rounds in the wall, and (at full
# capacity) enemies, which get shoved toward the intake.
func _sweep(arm: Dictionary, full: bool) -> void:
	var base: Vector2 = arm.base
	var lo := minf(arm.prev, arm.a) - 0.04
	var hi := maxf(arm.prev, arm.a) + 0.04
	var p: Vector2 = game.player.pos
	if game.player.dash_t <= 0.0 and _in_slice(p - base, lo, hi, L + Player.R):
		var n := Vector2.from_angle(arm.a).orthogonal() * signf(arm.a - arm.prev)
		if game.on_player_hit(n, null):
			game.fx.sparks(p, n, 8, Pal.foe(1.0, 2.2), 420.0, 0.25, 1.0)
			game.cam.add_trauma(0.25)
		game.player.vel += n * 600.0
	for b in game.bullets.list:
		if b.state != Bullets.EMBED or b.foe or _carried(b) or crate.has(b):
			continue
		if _in_slice(b.pos - base, lo, hi, L + 34.0):
			_pluck(b, arm)
	if full:
		var to: Vector2 = game.boss.core_pos()
		for e in game.enemies.list:
			if e.state == Enemies.ALIVE and _in_slice(e.pos - base, lo, hi, L + e.r):
				e.knock += (to - e.pos).normalized() * 700.0


func _in_slice(v: Vector2, lo: float, hi: float, reach: float) -> bool:
	if v.length() > reach:
		return false
	var a := v.angle()
	var mid := (lo + hi) * 0.5
	return absf(wrapf(a - mid, -PI, PI)) <= (hi - lo) * 0.5


func _carried(b) -> bool:
	for c in carry:
		if c[0] == b:
			return true
	return false


# Take a round off the wall: its line now runs from where you fired it to
# the crate, and it rides the claw's arc over to it.
func _pluck(b, arm: Dictionary) -> void:
	var to := Vector2(randf_range(CRATE.position.x + 14.0, CRATE.end.x - 14.0), CRATE.position.y - 1.0)
	if randf() < 0.4:
		to = Vector2(CRATE.end.x + 1.0, randf_range(CRATE.position.y + 12.0, CRATE.end.y - 12.0))
	carry.append([b, b.pos, to, 0.0, false])
	game.fx.sparks(b.pos, -b.dir, 4, Pal.ink(0.9, 1.6), 260.0, 0.18, 0.9)
	game.sfx.play("p_hit", randf_range(1.3, 1.5), -12.0)


func _step_carry(dt: float) -> void:
	var i := 0
	while i < carry.size():
		var c: Array = carry[i]
		var b = c[0]
		c[3] += dt / CARRY
		if b.state != Bullets.EMBED:
			# recalled or gone mid-carry: let it be
			carry.remove_at(i)
			continue
		var from: Vector2 = c[1]
		var to: Vector2 = game.boss.core_pos() if c[4] else c[2]
		var k := Pal.ease_io(minf(1.0, c[3]))
		var mid := from.lerp(to, 0.5) + (to - from).orthogonal().normalized() * from.distance_to(to) * 0.2
		var p := from.lerp(mid, k).lerp(mid.lerp(to, k), k)
		b.pos = p
		b.path = PackedVector2Array([b.path[0], p])
		b.cum = PackedFloat32Array([0.0, b.path[0].distance_to(p)])
		if b.settled:
			b.settled = false
			game.bullets.faint_dirty = true
		if c[3] >= 1.0:
			carry.remove_at(i)
			if c[4]:
				if game.boss is Devourer and game.boss.holds():
					game.bullets.capture(b, game.boss)
			else:
				b.dir = (to - b.path[0]).normalized()
				crate.append(b)
				game.fx.sparks(to, Vector2.UP, 3, Pal.ink(0.8, 1.5), 200.0, 0.15, 1.0)
				game.sfx.play("embed", randf_range(0.8, 0.95), -12.0)
			continue
		i += 1
	# rounds that left the crate (recalled, expired) are no longer in it
	var j := 0
	while j < crate.size():
		if crate[j].state != Bullets.EMBED:
			crate.remove_at(j)
		else:
			j += 1


# Full capacity: the crate's whole stock goes into the intake's mouth.
func _feed() -> void:
	if crate.is_empty():
		return
	for b in crate:
		carry.append([b, b.pos, Vector2.ZERO, 0.0, true])
	crate.clear()
	game.sfx.play("focus", 0.5, -2.0)
	game.fx.flash(CRATE.get_center(), 90.0, 0.2, Pal.foe(0.4, 1.6))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f: float = game.focus if game else 0.0
	var dim := 1.0 - 0.45 * f
	_draw_belts(dim)
	for arm in arms:
		_draw_sector(arm, dim)
	for c in carry:
		var b = c[0]
		draw_line(c[1], b.pos, Pal.ink(0.12 * dim), 1.0)
	for arm in arms:
		_draw_arm(arm, dim)


# The belts: two rails, slats running along, ration boxes riding.
func _draw_belts(dim: float) -> void:
	if belts.is_empty():
		return
	var rails := PackedVector2Array()
	var slats := PackedVector2Array()
	for bl in belts:
		var a: Vector2 = bl[0]
		var b: Vector2 = bl[1]
		var d := (b - a).normalized()
		var n := d.orthogonal()
		var span := a.distance_to(b)
		for side: float in [-1.0, 1.0]:
			rails.append(a + n * 20.0 * side)
			rails.append(b + n * 20.0 * side)
		var s := fmod(t * 60.0, 18.0)
		while s < span:
			slats.append(a + d * s + n * 17.0)
			slats.append(a + d * s - n * 17.0)
			s += 18.0
		# ration boxes, all heading the one way
		var bx := fmod(t * 60.0, 150.0)
		while bx < span - 20.0:
			var c := a + d * (bx + 10.0)
			draw_rect(Rect2(c - Vector2(11, 11), Vector2(22, 22)), Color(0.07, 0.07, 0.075))
			draw_rect(Rect2(c - Vector2(11, 11), Vector2(22, 22)), Pal.ink(0.4 * dim), false, 1.0)
			draw_line(c - Vector2(11, 0), c + Vector2(11, 0), Pal.ink(0.2 * dim), 1.0)
			bx += 150.0
	draw_multiline(slats, Pal.ink(0.08 * dim), 2.0)
	draw_multiline(rails, Pal.ink(0.3 * dim), 2.0)


# Before a sweep: the floor it will cover, hatched, its edge closing in.
func _draw_sector(arm: Dictionary, dim: float) -> void:
	if arm.mode != RISE and arm.mode != SWEEP:
		return
	var base: Vector2 = arm.base
	var face: Vector2 = arm.face
	var a0: float = face.angle() - HALF
	var a1: float = face.angle() + HALF
	var k: float = clampf(arm.t / RISE_TIME, 0.0, 1.0) if arm.mode == RISE else 1.0
	var pts := PackedVector2Array([base])
	var n := 24
	for j in n + 1:
		pts.append(base + Vector2.from_angle(lerpf(a0, a1, j / float(n))) * L)
	draw_colored_polygon(pts, Pal.foe(0.004 + 0.01 * k))
	var rim := pts.slice(1)
	draw_polyline(rim, Pal.foe((0.3 + 0.6 * k) * dim, 1.6), 2.0)
	# hatch lines across the slice, thickening as the sweep nears
	var hatch := PackedVector2Array()
	for j in 9:
		var aj := lerpf(a0, a1, (j + 0.5) / 9.0)
		hatch.append(base + Vector2.from_angle(aj) * 40.0)
		hatch.append(base + Vector2.from_angle(aj) * L * (0.35 + 0.65 * k))
	draw_multiline(hatch, Pal.foe(0.2 * k * dim, 1.2), 1.0 + k)
	if arm.mode == SWEEP:
		# the swept part goes dark behind the arm
		var done := PackedVector2Array([base])
		var steps := 12
		for j in steps + 1:
			done.append(base + Vector2.from_angle(lerpf(a0, arm.a, j / float(steps))) * L)
		draw_colored_polygon(done, Color(0, 0, 0, 0.25))


# An arm: a plate bolted to the wall, a shoulder, an elbow, a two-pronged claw.
func _draw_arm(arm: Dictionary, dim: float) -> void:
	var base: Vector2 = arm.base
	var face: Vector2 = arm.face
	var side := face.orthogonal()
	var plate := PackedVector2Array([base - side * 40.0 - face * 6.0, base + side * 40.0 - face * 6.0, base + side * 40.0 + face * 26.0, base - side * 40.0 + face * 26.0])
	draw_colored_polygon(plate, Pal.WALL)
	plate.append(plate[0])
	draw_polyline(plate, Pal.ink(0.55 * dim), 1.5)
	for s: float in [-1.0, 1.0]:
		draw_circle(base + side * 30.0 * s + face * 10.0, 3.0, Pal.ink(0.4 * dim))
	var dir := Vector2.from_angle(arm.a)
	var sh := base + face * 14.0
	var elbow := sh + dir * L * 0.52 + dir.orthogonal() * 16.0
	var cl := base + dir * L
	var live: bool = arm.mode == SWEEP
	var col := Pal.foe(dim, 1.6) if live else Pal.ink(0.75 * dim)
	for seg in [[sh, elbow, 14.0], [elbow, cl, 10.0]]:
		draw_line(seg[0], seg[1], Pal.WALL, seg[2])
		draw_line(seg[0], seg[1], col, 2.0)
	draw_circle(sh, 13.0, Pal.WALL)
	draw_arc(sh, 13.0, 0.0, TAU, 20, col, 2.0)
	draw_circle(elbow, 8.0, Pal.WALL)
	draw_arc(elbow, 8.0, 0.0, TAU, 16, col, 1.5)
	# the claw opens on its way in, closes as it sweeps
	var open := 0.5 if live else 0.25
	for s2: float in [-1.0, 1.0]:
		var prong := dir.rotated(open * s2)
		draw_line(cl, cl + prong * 22.0, col, 3.0)
		draw_line(cl + prong * 22.0, cl + prong * 22.0 + dir.rotated(-0.5 * s2) * 10.0, col, 2.0)
	if live:
		draw_circle(cl, 5.0, Pal.foe(dim, 2.4))
