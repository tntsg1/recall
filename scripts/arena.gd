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
var movers: Array[Rect2] = []
var nav_tracks: Array[Rect2] = []   # the shelving's whole tracks, kept for refresh_nav()  # the archive's shelves: solid, moved by Shelves (drawn there)
var mover_from := 9999         # index in rects where movers begin
var soft: Array[Rect2] = []    # solid to bodies only (the archivist's cabinet and bars)
var walls: Array[Rect2] = []   # a generated room's wall blocks (drawn as the room's own wall)
var generated := false         # a room from RoomGen: found its way round over the grid
var shine := 0.0
var game
# the way round walls: steps to a target over a 40 px grid (rooms with wall blocks)
const NAV := 40.0
var nav_nx := 0
var nav_ny := 0
var nav_block := PackedByteArray()
var nav_cache := {}            # target cell -> distance field
var nav_order: Array = []


func _init() -> void:
	z_index = 2
	z_as_relative = false
	setup(0)


# `lay` (RoomGen) replaces the chapter's hand-made room with a generated one.
func setup(ch: int, lay := {}) -> void:
	rects.clear()
	inner.clear()
	mirrors.clear()
	soft.clear()
	walls.clear()
	var r := ROOM
	rects.append(Rect2(r.position.x - OUTER, r.position.y - OUTER, r.size.x + OUTER * 2.0, OUTER))
	rects.append(Rect2(r.position.x - OUTER, r.end.y, r.size.x + OUTER * 2.0, OUTER))
	rects.append(Rect2(r.position.x - OUTER, r.position.y, OUTER, r.size.y))
	rects.append(Rect2(r.end.x, r.position.y, OUTER, r.size.y))
	generated = not lay.is_empty()
	if generated:
		walls.assign(lay.walls)
		# the chapter's own pieces sort out by kind: mirror panels turn rounds away
		var kinds: Array = lay.get("kinds", [])
		for i in (lay.cover as Array).size():
			if i < kinds.size() and kinds[i] == "mirror":
				mirrors.append(lay.cover[i])
			else:
				inner.append(lay.cover[i])
		rects.append_array(walls)
		ch = -1
	match ch:
		-1:
			pass
		0:
			for c in [Vector2(600, 330), Vector2(1320, 330), Vector2(600, 750), Vector2(1320, 750)]:
				inner.append(Rect2(c - Vector2(44, 44), Vector2(88, 88)))
			inner.append(Rect2(300, 515, 190, 50))
			inner.append(Rect2(1430, 515, 190, 50))
		4:
			# Zero: almost nothing to hide behind
			for c in [Vector2(390, 232), Vector2(1530, 232), Vector2(390, 848), Vector2(1530, 848)]:
				inner.append(Rect2(c - Vector2(90, 12), Vector2(180, 24)))
			# and the board's server columns, the control nodes
			inner.append_array(ControlNodes.rects())
		3:
			# the Beat: four corner pillars, the middle swept by the arm
			for c in [Vector2(320, 260), Vector2(1600, 260), Vector2(320, 820), Vector2(1600, 820)]:
				inner.append(Rect2(c - Vector2(36, 36), Vector2(72, 72)))
			inner.append(Rect2(880, 960, 160, 30))
		6:
			# the energy bureau: four low switch housings for cover, the middle
			# left to the transformer and its cables
			for c in [Vector2(470, 300), Vector2(1450, 300), Vector2(845, 790), Vector2(1075, 790)]:
				inner.append(Rect2(c - Vector2(40, 32), Vector2(80, 64)))
		5:
			# the laser range: the four posts the beams hang from, two crate stacks low down
			for c in [Vector2(624, 420), Vector2(1296, 420), Vector2(396, 700), Vector2(1524, 700)]:
				inner.append(Rect2(c - Vector2(24, 24), Vector2(48, 48)))
			inner.append(Rect2(230, 860, 110, 64))
			inner.append(Rect2(1580, 860, 110, 64))
			# two more stacks mid-range: cover from the flame and the rail gun
			inner.append(Rect2(730, 530, 110, 64))
			inner.append(Rect2(1080, 530, 110, 64))
		7:
			# the deep archive: nothing fixed to hide behind but the shelving
			pass
		10:
			# the institute: four instrument plinths, the floor between left to the fields
			for c in [Vector2(330, 250), Vector2(1590, 250), Vector2(330, 870), Vector2(1590, 870)]:
				inner.append(Rect2(c - Vector2(48, 28), Vector2(96, 56)))
			inner.append(Rect2(700, 545, 70, 40))
			inner.append(Rect2(1150, 545, 70, 40))
		9:
			# the shipyard: a crate of armour steel; the rest is the plates adrift
			inner.append(Rect2(170, 880, 150, 70))
			inner.append(Rect2(1600, 880, 150, 70))
		8:
			# the lift car: two rows of bolted seats, a pillar either side
			inner.append(Rect2(560, 600, 180, 44))
			inner.append(Rect2(1180, 600, 180, 44))
			inner.append(Rect2(420, 860, 56, 56))
			inner.append(Rect2(1444, 860, 56, 56))
		2:
			# the Maw: six blocks in a ring, the middle left for what lives there
			for k in 6:
				var c := Vector2(960, 540) + Vector2.from_angle(PI / 6.0 + TAU * k / 6.0) * Vector2(520, 330)
				var hw := 46.0 if k == 1 or k == 4 else 34.0
				inner.append(Rect2(c - Vector2(hw, hw), Vector2(hw, hw) * 2.0))
			# the strategic reserve crate, where the arms put what they take
			inner.append(Arms.CRATE)
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
	mover_from = rects.size()
	movers = Shelves.initial(ch) if not generated else Shelves.rects_for(lay.get("banks", []))
	movers.append_array(Plates.initial(ch) if not generated else Plates.rects_for(lay.get("plates", [])))
	rects.append_array(movers)
	mirror_from = rects.size()
	rects.append_array(mirrors)
	# the way round a bank of shelving is round the whole of its track: its
	# aisle opens and shuts too often to be a way through
	var tracks: Array[Rect2] = []
	if generated:
		for b: Array in lay.get("banks", []):
			tracks.append(Rect2(b[0], b[1], Shelves.span(), Shelves.H))
	_build_nav(tracks)
	queue_redraw()


# The way round the shipyard's plates changes as they drift: Plates calls
# this now and then to lay the grid again where they lie.
func refresh_nav() -> void:
	_build_nav(nav_tracks)


func _build_nav(tracks: Array[Rect2] = []) -> void:
	nav_tracks = tracks
	nav_cache.clear()
	nav_order.clear()
	nav_nx = int(ROOM.size.x / NAV)
	nav_ny = int(ROOM.size.y / NAV)
	nav_block = PackedByteArray()
	nav_block.resize(nav_nx * nav_ny)
	if not generated:
		return
	for j in nav_ny:
		for i in nav_nx:
			var c := ROOM.position + Vector2(i + 0.5, j + 0.5) * NAV
			for r: Rect2 in walls + inner + mirrors + tracks + (movers if game and game.plates.active() else ([] as Array[Rect2])):
				if r.grow(18.0).has_point(c):
					nav_block[j * nav_nx + i] = 1
					break


# Which way to head for `to` from `from`, round the walls: toward the
# neighbouring cell nearest the target, or straight on where there is no grid.
func nav_dir(from: Vector2, to: Vector2) -> Vector2:
	var direct := (to - from).normalized()
	if not generated:
		return direct
	var tc := _nav_cell(to)
	var fc := _nav_cell(from)
	if tc < 0 or fc < 0:
		return direct
	var field: PackedInt32Array = nav_cache.get(tc, PackedInt32Array())
	if field.is_empty():
		field = _nav_field(tc)
		nav_cache[tc] = field
		nav_order.append(tc)
		if nav_order.size() > 6:
			nav_cache.erase(nav_order.pop_front())
	var fi := fc % nav_nx
	var fj := fc / nav_nx
	var best := field[fc]
	var to_c := Vector2(-1, -1)
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var a := fi + o.x
		var b := fj + o.y
		if a < 0 or b < 0 or a >= nav_nx or b >= nav_ny:
			continue
		# no cutting a blocked corner
		if o.x != 0 and o.y != 0 and (nav_block[fj * nav_nx + a] == 1 or nav_block[b * nav_nx + fi] == 1):
			continue
		var d := field[b * nav_nx + a]
		if d >= 0 and (best < 0 or d < best):
			best = d
			to_c = ROOM.position + Vector2(a + 0.5, b + 0.5) * NAV
	if to_c.x < 0.0:
		return direct
	return (to_c - from).normalized()


func _nav_cell(p: Vector2) -> int:
	var i := int((p.x - ROOM.position.x) / NAV)
	var j := int((p.y - ROOM.position.y) / NAV)
	if i < 0 or j < 0 or i >= nav_nx or j >= nav_ny:
		return -1
	return j * nav_nx + i


func _nav_field(tc: int) -> PackedInt32Array:
	var f := PackedInt32Array()
	f.resize(nav_nx * nav_ny)
	f.fill(-1)
	f[tc] = 0
	var q := PackedInt32Array([tc])
	var head := 0
	while head < q.size():
		var k := q[head]
		head += 1
		var i := k % nav_nx
		var j := k / nav_nx
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var a := i + o.x
			var b := j + o.y
			if a < 0 or b < 0 or a >= nav_nx or b >= nav_ny:
				continue
			var kk := b * nav_nx + a
			if f[kk] < 0 and nav_block[kk] == 0:
				f[kk] = f[k] + 1
				q.append(kk)
	return f


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


func set_mover(i: int, r: Rect2) -> void:
	movers[i] = r
	rects[mover_from + i] = r


func push_circle(p: Vector2, rad: float) -> Vector2:
	for r: Rect2 in rects + soft:
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
	for r: Rect2 in inner + movers + soft + walls:
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
	# a generated room's wall blocks: the same dark mass, edged where they face the floor
	# (solid all through: hatched like a wall cut in a plan, where crates are crossed)
	for w in walls:
		draw_rect(w.grow(2.0), Pal.WALL)
		var hatch := Pal.ink(0.07 - 0.03 * f)
		var d := -w.size.y
		while d < w.size.x:
			var a := Vector2(w.position.x + maxf(d, 0.0), w.position.y + maxf(-d, 0.0))
			var b := Vector2(w.position.x + minf(d + w.size.y, w.size.x), w.position.y + minf(w.size.x - d, w.size.y))
			draw_line(a, b, hatch, 1.0)
			d += 16.0
	for w in walls:
		for s: Array in _faces(w):
			draw_line(s[0], s[1], edge, 2.0)
			draw_line(s[0] - s[2] * 10.0, s[1] - s[2] * 10.0, faint, 1.0)
	# cover sits a step below you and the enemies in brightness: the room's
	# edge, then its blocks, then whatever moves
	var block := Pal.ink(0.62 - 0.25 * f)
	# a generated hall of mirrors: the glass is what the room is about, the rest steps back
	var glass_room := generated and not mirrors.is_empty()
	if glass_room:
		block = Pal.ink(0.5 - 0.2 * f)
	for r in inner:
		draw_rect(r, Pal.WALL)
		draw_rect(r, block, false, 2.0)
		draw_rect(r.grow(-7), faint, false, 1.0)
	# mirrors: bright glass with a sheen that slides along when struck; in a
	# generated hall the two nearest you shine brightest, the rest a step down
	var near_m: Array = []
	if glass_room and game:
		var by: Array = mirrors.duplicate()
		var pp: Vector2 = game.player.pos
		by.sort_custom(func(p, q): return p.get_center().distance_squared_to(pp) < q.get_center().distance_squared_to(pp))
		near_m = by.slice(0, 2)
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
		var lead: bool = near_m.has(m)
		if glass_room:
			# a faint halo round the glass; the lit band wider on the near ones
			# the more glass in the room, the quieter each halo
			var hk := 2.0 / maxf(2.0, mirrors.size())
			draw_rect(m.grow(5.0), Pal.ink((0.07 if lead else 0.04) * hk, 1.0), false, 3.0)
			if lead:
				draw_line(sq, sq + sd, Pal.ink(0.75, 1.6), 5.0)
		draw_rect(m, Pal.ink(0.95 - 0.3 * f, 1.5 if lead else 1.3), false, 2.0 if glass_room else 1.5)
		var a0 := m.position + (Vector2(0, m.size.y / 2.0) if long_x else Vector2(m.size.x / 2.0, 0))
		var a1 := a0 + (Vector2(m.size.x, 0) if long_x else Vector2(0, m.size.y))
		draw_line(a0, a1, Pal.ink(0.5, 1.6), 1.0)


# The faces of wall block `w` that look onto the floor, as [a, b, normal]:
# not those against the room's edge or inside another block.
func _faces(w: Rect2) -> Array:
	var out: Array = []
	var sides := [
		[w.position, Vector2(w.end.x, w.position.y), Vector2(0, -1)],
		[Vector2(w.position.x, w.end.y), w.end, Vector2(0, 1)],
		[w.position, Vector2(w.position.x, w.end.y), Vector2(-1, 0)],
		[Vector2(w.end.x, w.position.y), w.end, Vector2(1, 0)],
	]
	for s: Array in sides:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var n: Vector2 = s[2]
		# lying on the room's edge
		if (n.y != 0.0 and (absf(a.y - ROOM.position.y) < 1.0 or absf(a.y - ROOM.end.y) < 1.0)) or (n.x != 0.0 and (absf(a.x - ROOM.position.x) < 1.0 or absf(a.x - ROOM.end.x) < 1.0)):
			continue
		# cut where another block covers it, a step out from the face
		var spans: Array = [[0.0, 1.0]]
		for o in walls:
			if o == w:
				continue
			var g := o.grow(1.0)
			var lo := 2.0
			var hi := -1.0
			for k in 21:
				var u := k / 20.0
				if g.has_point(a.lerp(b, u) + n * 1.5):
					lo = minf(lo, u)
					hi = maxf(hi, u)
			if hi < lo:
				continue
			var next: Array = []
			for sp: Array in spans:
				if sp[1] <= lo or sp[0] >= hi:
					next.append(sp)
					continue
				if sp[0] < lo:
					next.append([sp[0], lo])
				if sp[1] > hi:
					next.append([hi, sp[1]])
			spans = next
		for sp: Array in spans:
			out.append([a.lerp(b, sp[0]), a.lerp(b, sp[1]), n])
	return out


func game_t() -> float:
	return game.real_time if game else 0.0


func _corner_marks(r: Rect2, c: Color) -> void:
	var l := 26.0
	for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if p.x < r.get_center().x else -1.0
		var sy := 1.0 if p.y < r.get_center().y else -1.0
		draw_line(p, p + Vector2(l * sx, 0), c, 1.0)
		draw_line(p, p + Vector2(0, l * sy), c, 1.0)
