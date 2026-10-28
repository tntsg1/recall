class_name Arena
extends Node2D
# The room for each chapter: boundary walls plus that chapter's pillars, bars
# and (from the Hall of Mirrors on) mirror panels that turn rounds away.
# All collision is our own geometry (segment vs rect, circle vs rect), so the
# exact polyline every bullet flies is known.

const ROOM := Rect2(80, 70, 1760, 940)
const OUTER := 900.0

var rects: Array[Rect2] = []   # every solid; mirrors last
var inner: Array[Rect2] = []   # pillars and bars (drawn with full outline)
var mirrors: Array[Rect2] = [] # panels that reflect instead of holding a round
var mirror_from := 9999        # index in rects where mirrors begin
var shine := 0.0
var game


func _init() -> void:
	z_index = 2
	z_as_relative = false
	setup(0)


func setup(ch: int) -> void:
	rects.clear()
	inner.clear()
	mirrors.clear()
	var r := ROOM
	rects.append(Rect2(r.position.x - OUTER, r.position.y - OUTER, r.size.x + OUTER * 2.0, OUTER))
	rects.append(Rect2(r.position.x - OUTER, r.end.y, r.size.x + OUTER * 2.0, OUTER))
	rects.append(Rect2(r.position.x - OUTER, r.position.y, OUTER, r.size.y))
	rects.append(Rect2(r.end.x, r.position.y, OUTER, r.size.y))
	match ch:
		0:
			for c in [Vector2(600, 330), Vector2(1320, 330), Vector2(600, 750), Vector2(1320, 750)]:
				inner.append(Rect2(c - Vector2(44, 44), Vector2(88, 88)))
			inner.append(Rect2(300, 515, 190, 50))
			inner.append(Rect2(1430, 515, 190, 50))
		4:
			# Zero: almost nothing to hide behind
			for c in [Vector2(390, 232), Vector2(1530, 232), Vector2(390, 848), Vector2(1530, 848)]:
				inner.append(Rect2(c - Vector2(90, 12), Vector2(180, 24)))
		3:
			# the Beat: four corner pillars, the middle swept by the arm
			for c in [Vector2(320, 260), Vector2(1600, 260), Vector2(320, 820), Vector2(1600, 820)]:
				inner.append(Rect2(c - Vector2(36, 36), Vector2(72, 72)))
			inner.append(Rect2(880, 960, 160, 30))
		2:
			# the Maw: six blocks in a ring, the middle left for what lives there
			for k in 6:
				var c := Vector2(960, 540) + Vector2.from_angle(PI / 6.0 + TAU * k / 6.0) * Vector2(520, 330)
				inner.append(Rect2(c - Vector2(34, 34), Vector2(68, 68)))
		_:
			# the Hall of Mirrors: two pillars, four panels, the middle kept open
			inner.append(Rect2(390, 500, 80, 80))
			inner.append(Rect2(1450, 500, 80, 80))
			# mirrors stand thick enough to read as glass panels
			mirrors.append(Rect2(613, 200, 28, 200))
			mirrors.append(Rect2(1279, 680, 28, 200))
			mirrors.append(Rect2(1180, 255, 220, 28))
			mirrors.append(Rect2(520, 797, 220, 28))
	rects.append_array(inner)
	mirror_from = rects.size()
	rects.append_array(mirrors)
	queue_redraw()


# Nearest hit of segment a->b. Returns {} or {point, normal, t}.
func raycast(a: Vector2, b: Vector2) -> Dictionary:
	var d := b - a
	var best := 2.0
	var nrm := Vector2.ZERO
	var best_i := -1
	var ri := -1
	for r in rects:
		ri += 1
		var t0 := 0.0
		var t1 := 1.0
		var n := Vector2.ZERO
		var miss := false
		for axis in 2:
			var p: float = a[axis]
			var dd: float = d[axis]
			var lo: float = r.position[axis]
			var hi: float = r.end[axis]
			if absf(dd) < 1e-9:
				if p < lo or p > hi:
					miss = true
					break
			else:
				var ta := (lo - p) / dd
				var tb := (hi - p) / dd
				var nn := -1.0
				if ta > tb:
					var tmp := ta
					ta = tb
					tb = tmp
					nn = 1.0
				if ta > t0:
					t0 = ta
					n = Vector2.ZERO
					n[axis] = nn
				t1 = minf(t1, tb)
				if t0 > t1:
					miss = true
					break
		if miss or n == Vector2.ZERO:
			continue
		if t0 < best:
			best = t0
			nrm = n
			best_i = ri
	if best > 1.0:
		return {}
	return {"point": a + d * best, "normal": nrm, "t": best, "mirror": best_i >= mirror_from, "rect": best_i}


func push_circle(p: Vector2, rad: float) -> Vector2:
	for r in rects:
		var c := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var d := p - c
		var l := d.length()
		if l < rad:
			if l < 0.001:
				var opts := [Vector2(r.position.x - rad, p.y), Vector2(r.end.x + rad, p.y), Vector2(p.x, r.position.y - rad), Vector2(p.x, r.end.y + rad)]
				var bestp: Vector2 = opts[0]
				for o: Vector2 in opts:
					if o.distance_to(p) < bestp.distance_to(p):
						bestp = o
				p = bestp
			else:
				p = c + d / l * rad
	return p


func is_free(p: Vector2, rad: float) -> bool:
	if not ROOM.grow(-rad).has_point(p):
		return false
	for r in inner:
		if r.grow(rad).has_point(p):
			return false
	return true


func _draw() -> void:
	var f: float = game.focus if game else 0.0
	var edge := Pal.ink(0.9 - 0.35 * f)
	var faint := Pal.ink(0.13 - 0.06 * f)
	# boundary: dark mass outside the room, a single crisp inner edge and a hairline inset
	var big := ROOM.grow(OUTER)
	draw_rect(Rect2(big.position, Vector2(big.size.x, ROOM.position.y - big.position.y)), Pal.WALL)
	draw_rect(Rect2(Vector2(big.position.x, ROOM.end.y), Vector2(big.size.x, big.end.y - ROOM.end.y)), Pal.WALL)
	draw_rect(Rect2(Vector2(big.position.x, ROOM.position.y), Vector2(ROOM.position.x - big.position.x, ROOM.size.y)), Pal.WALL)
	draw_rect(Rect2(Vector2(ROOM.end.x, ROOM.position.y), Vector2(big.end.x - ROOM.end.x, ROOM.size.y)), Pal.WALL)
	draw_rect(ROOM, edge, false, 2.0)
	draw_rect(ROOM.grow(10), faint, false, 1.0)
	_corner_marks(ROOM.grow(22), Pal.ink(0.35 - 0.2 * f))
	# cover sits a step below you and the enemies in brightness: the room's
	# edge, then its blocks, then whatever moves
	var block := Pal.ink(0.62 - 0.25 * f)
	for r in inner:
		draw_rect(r, Pal.WALL)
		draw_rect(r, block, false, 2.0)
		draw_rect(r.grow(-7), faint, false, 1.0)
	# mirrors: bright glass with a sheen that slides along when struck
	for m in mirrors:
		var long_x := m.size.x > m.size.y
		# glass: a pale gradient across it and one bright edge, so it reads as a mirror
		var gp := PackedVector2Array([m.position, Vector2(m.end.x, m.position.y), m.end, Vector2(m.position.x, m.end.y)])
		var g0 := Color(0.12, 0.12, 0.14)
		var g1 := Color(0.24, 0.24, 0.27)
		draw_polygon(gp, PackedColorArray([g1, g0 if long_x else g1, g0, g0 if not long_x else g1]))
		if long_x:
			draw_line(m.position, Vector2(m.end.x, m.position.y), Pal.ink(0.9, 1.6), 2.0)
		else:
			draw_line(m.position, Vector2(m.position.x, m.end.y), Pal.ink(0.9, 1.6), 2.0)
		# glass: slanted streaks of reflected light along its length
		var span := m.size.x if long_x else m.size.y
		var sp := 10.0
		while sp < span - 10.0:
			var q := m.position + (Vector2(sp, 0) if long_x else Vector2(0, sp))
			var d := Vector2(-6, m.size.y) if long_x else Vector2(m.size.x, -6)
			draw_line(q, q + d, Pal.ink(0.22, 1.2), 1.5)
			sp += 26.0
		# a slow band of light slides along the glass
		var slide := fmod(game_t() * 0.25 + m.position.x * 0.001, 1.0) * span
		var sq := m.position + (Vector2(slide, 0) if long_x else Vector2(0, slide))
		var sd := Vector2(-10, m.size.y) if long_x else Vector2(m.size.x, -10)
		draw_line(sq, sq + sd, Pal.ink(0.7, 1.8), 4.0)
		draw_rect(m, Pal.ink(0.95 - 0.3 * f, 1.4), false, 1.5)
		var a0 := m.position + (Vector2(0, m.size.y / 2.0) if long_x else Vector2(m.size.x / 2.0, 0))
		var a1 := a0 + (Vector2(m.size.x, 0) if long_x else Vector2(0, m.size.y))
		draw_line(a0, a1, Pal.ink(0.5, 1.6), 1.0)


func game_t() -> float:
	return game.real_time if game else 0.0


func _corner_marks(r: Rect2, c: Color) -> void:
	var l := 26.0
	for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if p.x < r.get_center().x else -1.0
		var sy := 1.0 if p.y < r.get_center().y else -1.0
		draw_line(p, p + Vector2(l * sx, 0), c, 1.0)
		draw_line(p, p + Vector2(0, l * sy), c, 1.0)
