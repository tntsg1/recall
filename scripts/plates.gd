class_name Plates
extends Node2D
# The orbital shipyard's floor (chapter 10): loose hull plates adrift in zero
# gravity, cover that moves. A round that strikes a plate shoves it on along
# the round's line; a round embedded in a plate, recalled, yanks the plate
# back toward you as it leaves. A plate moving fast enough hurts what it
# hits, so you can throw your cover into the enemies.

const SIZES := [Vector2(170, 38), Vector2(170, 38), Vector2(38, 160), Vector2(38, 160), Vector2(150, 38)]
const STARTS := [Vector2(380, 650), Vector2(1540, 660), Vector2(700, 830), Vector2(1220, 830), Vector2(960, 650)]
const SHOVE := 70.0          # px/s a striking round gives
const YANK := 230.0          # px/s a recalled round gives, toward its way home
const DRAG := 0.35           # per second: almost nothing slows it
const MAX_SPEED := 420.0
const RAM_SPEED := 150.0     # faster than this, it hurts what it hits
const RAM_DMG := 0.14        # damage per px/s

var on := false
var game
var sizes: Array = SIZES.duplicate()   # each plate's size (a generated room's own)
var starts: Array = STARTS.duplicate()
var t := 0.0
var pos: Array = []          # centres
var vel: Array = []
var spin: Array = []         # a little drawn wobble
var ram_cd: Array = []
var hits: Array = []         # [pos, t]: recent impacts, drawn as rings


func _init() -> void:
	z_index = 2
	z_as_relative = false


static func initial(room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if room != 9:
		return out
	for k in SIZES.size():
		out.append(Rect2(STARTS[k] - SIZES[k] * 0.5, SIZES[k]))
	return out


func setup(story: int) -> void:
	on = story == 10
	set_plates([])


# The plates this room starts with, [centre, size] each (none given: the
# hand-made yard's five).
func set_plates(list: Array) -> void:
	sizes = SIZES.duplicate()
	starts = STARTS.duplicate()
	if not list.is_empty():
		sizes.clear()
		starts.clear()
		for pl: Array in list:
			starts.append(pl[0])
			sizes.append(pl[1])
	visible = on
	t = 0.0
	pos.clear()
	vel.clear()
	spin.clear()
	ram_cd.clear()
	hits.clear()
	if on:
		for k in sizes.size():
			pos.append(starts[k])
			vel.append(Vector2.ZERO)
			spin.append(randf() * TAU)
			ram_cd.append(0.0)
	queue_redraw()


# A generated room's plates as rects, where they start.
static func rects_for(list: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for pl: Array in list:
		out.append(Rect2((pl[0] as Vector2) - (pl[1] as Vector2) * 0.5, pl[1]))
	return out


func active() -> bool:
	return on


func rect(k: int) -> Rect2:
	return Rect2((pos[k] as Vector2) - sizes[k] * 0.5, sizes[k])


# The plate an arena rect index belongs to, or -1 (the plates follow any
# shelving in the arena's movers; in this room there is none).
func plate_of(rect_i: int) -> int:
	if not on or rect_i < 0:
		return -1
	var k: int = rect_i - game.arena.mover_from
	return k if k >= 0 and k < sizes.size() else -1


# A round struck the plate and stayed in it: the plate takes its push.
func on_embed(b) -> void:
	if b.plate < 0:
		return
	var k: int = b.plate
	vel[k] = ((vel[k] as Vector2) + b.dir * SHOVE).limit_length(MAX_SPEED)
	hits.append([b.pos, 0.0])


func step(dt: float) -> void:
	if not on:
		return
	t += dt
	# rounds leaving a plate on a recall pull it after them
	for b in game.bullets.list:
		if b.plate >= 0 and b.state != Bullets.EMBED:
			var k: int = b.plate
			b.plate = -1
			if b.state == Bullets.PULL or b.state == Bullets.RETURN:
				var n: int = b.path.size()
				var back: Vector2 = (b.path[n - 2] - b.path[n - 1]) if n >= 2 else (game.player.pos - b.pos)
				if back.length() > 0.01:
					vel[k] = ((vel[k] as Vector2) + back.normalized() * YANK).limit_length(MAX_SPEED)
	var obstacles: Array[Rect2] = []
	obstacles.append_array(game.arena.inner)
	obstacles.append_array(game.arena.soft)
	obstacles.append_array(game.arena.walls)
	for k in sizes.size():
		ram_cd[k] = maxf(0.0, ram_cd[k] - dt)
		var v: Vector2 = vel[k]
		v *= exp(-DRAG * dt)
		if v.length() < 2.0:
			v = Vector2.ZERO
		var before := rect(k)
		var p: Vector2 = pos[k] + v * dt
		var r := Rect2(p - sizes[k] * 0.5, sizes[k])
		# the room's walls
		var room := Arena.ROOM
		if r.position.x < room.position.x:
			p.x += room.position.x - r.position.x
			v.x = absf(v.x) * 0.55
		if r.end.x > room.end.x:
			p.x -= r.end.x - room.end.x
			v.x = -absf(v.x) * 0.55
		if r.position.y < room.position.y:
			p.y += room.position.y - r.position.y
			v.y = absf(v.y) * 0.55
		if r.end.y > room.end.y:
			p.y -= r.end.y - room.end.y
			v.y = -absf(v.y) * 0.55
		r = Rect2(p - sizes[k] * 0.5, sizes[k])
		# fixed cover, the ship, and the other plates
		var others: Array[Rect2] = obstacles.duplicate()
		for j in sizes.size():
			if j != k:
				others.append(rect(j))
		for o: Rect2 in others:
			if not r.intersects(o):
				continue
			var ox := minf(r.end.x, o.end.x) - maxf(r.position.x, o.position.x)
			var oy := minf(r.end.y, o.end.y) - maxf(r.position.y, o.position.y)
			if v.length() > 70.0:
				# a knock: sparks where it struck
				var hp := Vector2(clampf(p.x, o.position.x, o.end.x), clampf(p.y, o.position.y, o.end.y))
				game.fx.sparks(hp, (p - hp).normalized() if p.distance_to(hp) > 0.1 else Vector2.UP, 4, Pal.ink(0.9, 1.6), 260.0, 0.18, 1.0)
				game.sfx.play("embed", 0.7, -14.0)
			if ox < oy:
				var sx := 1.0 if r.get_center().x > o.get_center().x else -1.0
				p.x += ox * sx
				v.x = absf(v.x) * 0.55 * sx
			else:
				var sy := 1.0 if r.get_center().y > o.get_center().y else -1.0
				p.y += oy * sy
				v.y = absf(v.y) * 0.55 * sy
			r = Rect2(p - sizes[k] * 0.5, sizes[k])
		# it stops against you rather than pinning you
		var pl: Vector2 = game.player.pos
		if r.grow(Player.R).has_point(pl):
			v *= 0.4
		var speed := v.length()
		# ramming
		if speed > RAM_SPEED and ram_cd[k] <= 0.0:
			for e in game.enemies.list:
				if e.state == Enemies.ALIVE and r.grow(e.r).has_point(e.pos):
					game.enemies.blast_hit(e, v.normalized(), speed * RAM_DMG)
					game.fx.sparks(e.pos, v.normalized(), 6, Pal.ink(0.9, 1.6), 380.0, 0.2, 0.8)
					game.sfx.play("slam", 1.3, -8.0)
					ram_cd[k] = 0.35
					v *= 0.6
		var delta := p - (pos[k] as Vector2)
		pos[k] = p
		vel[k] = v
		spin[k] = float(spin[k]) + dt * (0.4 + speed * 0.004)
		if delta.length_squared() > 0.0001:
			game.arena.set_mover(k, rect(k))
			for b in game.bullets.list:
				if b.plate == k and b.state == Bullets.EMBED:
					b.pos += delta
					b.set_head(b.pos)
					game.bullets.faint_dirty = true
	var i := 0
	while i < hits.size():
		hits[i][1] += dt
		if hits[i][1] > 0.3:
			hits.remove_at(i)
		else:
			i += 1
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not on:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if game.hud.intro_t >= 0.0:
		dim *= clampf((game.hud.intro_t - 2.2) / 0.6, 0.25, 1.0)
	for k in sizes.size():
		_draw_plate(k, dim)
	for h in hits:
		var hk: float = h[1] / 0.3
		draw_arc(h[0], 6.0 + 18.0 * hk, 0.0, TAU, 16, Pal.ink(0.6 * (1.0 - hk) * dim, 1.4), 1.5)


# A hull plate: riveted edges, a stencilled frame number, weld seams; its
# drift drawn as fading streaks behind it, and a few rcs puffs when fast.
func _draw_plate(k: int, dim: float) -> void:
	var r := rect(k)
	var v: Vector2 = vel[k]
	var sp := v.length()
	if sp > 20.0:
		var back := -v.normalized()
		for j in 3:
			var o := back * (14.0 + j * 16.0) * clampf(sp / 240.0, 0.3, 1.0)
			draw_rect(Rect2(r.position + o, r.size), Pal.ink(0.12 * (1.0 - j / 3.0) * dim), false, 1.0)
	draw_rect(r, Color(0.06, 0.06, 0.065))
	var hot := clampf((sp - RAM_SPEED) / 120.0, 0.0, 1.0)
	draw_rect(r, Pal.ink((0.62 + 0.3 * hot) * dim, 1.0 + 0.6 * hot), false, 2.0)
	draw_rect(r.grow(-6.0), Pal.ink(0.18 * dim), false, 1.0)
	var long_x := r.size.x > r.size.y
	var span := r.size.x if long_x else r.size.y
	var s := 12.0
	while s < span - 8.0:
		var q := r.position + (Vector2(s, 4) if long_x else Vector2(4, s))
		var q2 := r.position + (Vector2(s, r.size.y - 4) if long_x else Vector2(r.size.x - 4, s))
		draw_circle(q, 1.5, Pal.ink(0.45 * dim))
		draw_circle(q2, 1.5, Pal.ink(0.45 * dim))
		s += 18.0
	var sf := Fonts.get_font("SemiBold")
	var lab := "H-%02d" % (k * 7 + 11)
	if long_x:
		draw_string(sf, r.get_center() + Vector2(-16, 5), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.6 * dim))
	else:
		draw_set_transform(r.get_center() + Vector2(4, -16), PI * 0.5, Vector2.ONE)
		draw_string(sf, Vector2.ZERO, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.6 * dim))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a tether ring at one end, its cut line drifting
	var tq := r.position + (Vector2(6, r.size.y * 0.5) if long_x else Vector2(r.size.x * 0.5, 6))
	draw_arc(tq, 4.0, 0.0, TAU, 10, Pal.ink(0.5 * dim), 1.5)
	var sw := sin(float(spin[k]) * 2.0) * 10.0
	draw_polyline(PackedVector2Array([tq, tq + Vector2(-14, sw * 0.5) if long_x else tq + Vector2(sw * 0.5, -14), tq + Vector2(-26, sw) if long_x else tq + Vector2(sw, -26)]), Pal.ink(0.25 * dim), 1.0)
