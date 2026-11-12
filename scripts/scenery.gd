class_name Scenery
extends Node2D
# What passes beneath the deck on a ride between chapters (Transit): the FCU's
# megastructures as a wireframe seen from straight above, in perspective. The
# eye moves along a path (sideways over the city, or up / down a shaft); every
# point projects as C + (p.xy - eye.xy) * F / (eye.z - p.z), so the deck sits
# at depth D0 at scale 1, what lies deeper shrinks toward the middle and fades
# into the dark, and whatever rises past the deck swells out to the edges.
# Fills are near-black, edges are white ink; only a few lines glow.

const F := 1000.0
const D0 := 1000.0          # the deck's depth below the eye
const C0 := Vector2(960, 540)
var C := C0                 # where straight down falls on screen (above the deck on a ride)
const NEAR := 140.0         # nothing closer than this to the eye is drawn
const SCREEN := Rect2(-80, -80, 2080, 1240)
const DECK := Transit.DECK

enum { BOX, CYL, LINE, RING, CLOUD, TEXT, FRAME, GRID, ARC, BEAM, TUBE, TRAIN, CAR }

var leg := 0
var objs: Array = []        # sorted deepest first
var eye := Vector3.ZERO
var eye_prev := Vector3.ZERO
var vel := Vector3.ZERO
var path: Array[Vector3] = []   # the eye's way, as points spaced evenly in u
var u := 0.0
var t := 0.0
var fog := 4200.0
var stars := 0.0            # 0..1 how much of the sky is space
var star_pts: Array = []
var dust: Array[Vector3] = []
var planet := false
var linear := false         # the title's endless drift: no easing at the ends
var plain := false          # (the title) no heroes, no fly-bys
const BEATS := [0.3, 0.6, 0.9]   # where something huge goes by close
var beat := 0               # set when the way passes one of BEATS (Transit shakes and sounds it)
var beats_done := 0
var font: Font
var rng := RandomNumberGenerator.new()
static var LIT: Array[bool] = []   # which windows burn, a fixed pattern


func _ready() -> void:
	if LIT.is_empty():
		var g := RandomNumberGenerator.new()
		g.seed = 4242
		for i in 4096:
			LIT.append(g.randf() < 0.36)
	z_index = -12
	z_as_relative = false
	font = Fonts.get_font("SemiBold")
	visible = false


# ------------------------------------------------------------------ set up

func begin(from_story: int) -> void:
	leg = from_story
	objs.clear()
	path.clear()
	u = 0.0
	t = 0.0
	stars = 0.0
	planet = false
	fog = 4200.0
	rng.seed = 7919 * from_story + 17
	beat = 0
	beats_done = 0
	# a ride looks ahead and down: the deep middle sits above the deck, where
	# what is coming can be seen coming
	C = Vector2(960, 230) if [1, 7, 8, 9].has(from_story) else Vector2(1260, 250)
	if from_story == 11:
		# (the tower comes in ahead: the view leans the other way to see it come)
		C = Vector2(640, 260)
	match from_story:
		1: _leg_undercity()
		2: _leg_side("corp", "industry", 0.0)
		3: _leg_side("industry", "silos", 0.0)
		4: _leg_side("silos", "rails", 0.0)
		5: _leg_side("rails", "energy", 0.0)
		6: _leg_side("energy", "screens", 0.0)
		7: _leg_sea_down()
		8: _leg_sea_up()
		9: _leg_space_up()
		10: _leg_orbit()
		_: _leg_tower_down()
	if not plain:
		_heroes(from_story)
	for o in objs:
		if int(o[0]) == LINE and (o[1] as PackedVector3Array).size() == 2:
			var a0: Vector3 = o[1][0]
			var a1: Vector3 = o[1][1]
			if absf(a0.z - a1.z) > 1500.0:
				var dense := PackedVector3Array()
				for k in 13:
					dense.append(a0.lerp(a1, k / 12.0))
				o[1] = dense
	objs.sort_custom(func(a, b): return _top(a) < _top(b))
	star_pts.clear()
	for i in 160:
		star_pts.append([Vector2(rng.randf_range(0, 1920), rng.randf_range(0, 1080)), rng.randf_range(0.2, 1.0), rng.randf() * TAU])
	dust.clear()
	eye = _eye_at(0.0)
	eye_prev = eye
	vel = Vector3.ZERO
	for i in 90:
		dust.append(_dust_point(true))
	visible = true
	queue_redraw()


# A still of a leg at one point of its way: what lies under a chapter's room
# (seen through its floor grates and windows). Drawn once.
func still(from_story: int, at: float) -> void:
	begin(from_story)
	dust.clear()
	step(0.0, at)


# What lies under a chapter's rooms, the whole floor's width of it (seen
# only through the grates and windows): the chapter's own kind of structure,
# deep below and still. Drawn once.
const UNDER := {1: "dorms", 2: "corp", 3: "industry", 4: "silos", 5: "rails", 6: "energy", 7: "screens",
	8: "sea", 9: "sky", 10: "hulls", 11: "arcs", 12: "crown"}


func under(story: int) -> void:
	C = C0
	objs.clear()
	path.clear()
	dust.clear()
	stars = 0.0
	planet = false
	fog = 4200.0
	t = 0.0
	leg = 0
	rng.seed = 104729 * story + 3
	var style: String = UNDER.get(story, "corp")
	path.append(Vector3.ZERO)
	path.append(Vector3.ZERO)
	match style:
		"sea":
			for i in 26:
				var p := Vector2(rng.randf_range(-2600, 2600), rng.randf_range(-1500, 1500))
				objs.append([CYL, p.x, p.y, rng.randf_range(160, 300), -D0 - 3600.0, -D0 - rng.randf_range(900, 2200), 3])
			objs.append([GRID, -D0 - 3600.0, 500.0, 5000.0])
			for k in 3:
				objs.append([TEXT, -1500.0 + k * 1300.0, 700.0 - k * 500.0, -D0 - 1400.0, "-4200 M", 34])
		"sky":
			_city_below(-D0 - 9000.0)
			for i in 30:
				var p := Vector2(rng.randf_range(-3600, 3600), rng.randf_range(-2400, 2400))
				objs.append([CLOUD, p.x, p.y, rng.randf_range(400, 900), rng.randf_range(200, 420), -D0 - rng.randf_range(700, 2200)])
		"hulls":
			planet = true
			stars = 1.0
			var y := -1800.0
			while y < 1800.0:
				var x := -3200.0 + rng.randf_range(0, 600)
				while x < 3200.0:
					var w := rng.randf_range(1400, 2600)
					var top := -D0 - rng.randf_range(600, 1600)
					objs.append([BOX, x, y, x + w, y + rng.randf_range(260, 420), top - 380.0, top, 4, false])
					x += w + rng.randf_range(300, 700)
				y += rng.randf_range(560, 760)
		"arcs":
			stars = 1.0
			for k in 10:
				objs.append([ARC, rng.randf_range(-1600, 1600), rng.randf_range(-900, 900), -D0 - rng.randf_range(500, 2600), rng.randf_range(500, 1300), 0.8, k])
		"crown":
			var tiers := [[5200.0, 3400.0, -D0 - 2600.0], [3500.0, 2300.0, -D0 - 1700.0], [2200.0, 1450.0, -D0 - 950.0]]
			for tr in tiers:
				objs.append([BOX, -tr[0], -tr[1], tr[0], tr[1], tr[2] - 700.0, tr[2], 5, true])
			for i in 30:
				var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2000, 5200)
				objs.append([CLOUD, p.x, p.y, rng.randf_range(700, 1300), rng.randf_range(320, 640), -D0 - 3400.0])
			_city_below(-D0 - 9000.0)
		"dorms":
			# the dormitory floors under the yard: concrete blocks stacked down, lit cells
			var gx := -3000.0
			while gx < 3000.0:
				var gy := -1900.0
				while gy < 1900.0:
					var w := rng.randf_range(380, 620)
					var d := rng.randf_range(260, 420)
					objs.append([BOX, gx, gy, gx + w, gy + d, -D0 - 4000.0, -D0 - rng.randf_range(400, 1600), 2, false])
					gy += d + rng.randf_range(80, 200)
				gx += rng.randf_range(560, 720)
			for i in 10:
				var y := rng.randf_range(-1600, 1600)
				objs.append([LINE, PackedVector3Array([Vector3(-4000, y, -D0 - 350.0), Vector3(4000, y, -D0 - 350.0)]), 1.0, 3.0])
		_:
			for side in [-1.0, 1.0]:
				for r in 3:
					var x := -3600.0 + rng.randf_range(0, 300)
					while x < 3600.0:
						x += _place(style, x, side, r)
			for k in 3:
				objs.append([TRAIN, [-900.0, 300.0, 1200.0][k], -D0 - 600.0 - k * 300.0, [-1400.0, 1100.0, -900.0][k], 8, rng.randf_range(-4000, 2000)])
			if style == "rails":
				for k in 8:
					var ry := -1400.0 + k * 400.0
					objs.append([LINE, PackedVector3Array([Vector3(-4000, ry, -D0 - 700.0), Vector3(4000, ry, -D0 - 700.0)]), 1.4, 2.0])
			objs.append([GRID, -D0 - 4400.0, 1000.0, 8000.0])
	objs.sort_custom(func(a, b): return _top(a) < _top(b))
	eye = Vector3.ZERO
	eye_prev = eye
	vel = Vector3.ZERO
	visible = true
	queue_redraw()


func step(dt: float, progress: float) -> void:
	t += dt
	u = progress
	while beats_done < BEATS.size() and u >= BEATS[beats_done] and path.size() >= 2 and not linear:
		beats_done += 1
		beat = beats_done
	eye_prev = eye
	eye = _eye_at(u)
	if dt > 0.0:
		vel = vel.lerp((eye - eye_prev) / dt, 1.0 - exp(-10.0 * dt))
	for i in dust.size():
		var d := dust[i] - eye
		if absf(d.x) > 3200.0 or absf(d.y) > 2200.0 or -d.z < NEAR + 40.0 or -d.z > D0 + 2600.0:
			dust[i] = _dust_point(false)
	queue_redraw()


# Depart, run, arrive: the way taken as u goes 0..1, slow at both ends.
static func ease_way(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x - sin(TAU * x) / TAU


func _eye_at(x: float) -> Vector3:
	if path.size() < 2:
		return Vector3.ZERO
	var f := (clampf(x, 0.0, 1.0) if linear else ease_way(x)) * (path.size() - 1)
	var i := mini(int(f), path.size() - 2)
	return path[i].lerp(path[i + 1], f - i)


func _dust_point(anywhere: bool) -> Vector3:
	# new motes come in ahead of the way the eye is going
	var v := vel.normalized() if vel.length() > 10.0 else Vector3(1, 0, 0)
	var p := eye + Vector3(rng.randf_range(-3000, 3000), rng.randf_range(-2000, 2000), -rng.randf_range(NEAR + 80.0, D0 + 2400.0))
	if not anywhere:
		p += Vector3(v.x * 2800.0, v.y * 1800.0, 0.0)
		if absf(v.z) > 0.5:
			p.z = eye.z + (-(NEAR + 90.0) if v.z > 0.0 else -(D0 + 2300.0)) + rng.randf_range(-60, 60)
	return p


# The deepest point an object reaches (for drawing deepest first).
func _top(o: Array) -> float:
	match int(o[0]):
		BOX: return o[6]
		CYL: return o[5]
		LINE: return (o[1] as PackedVector3Array)[0].z
		RING: return o[4]
		CLOUD: return o[5]
		TEXT: return o[3]
		FRAME: return o[3]
		GRID: return o[1]
		ARC: return o[3]
		BEAM: return o[3]
		TUBE: return o[4]
		TRAIN: return o[2]
		CAR: return o[5]
	return 0.0


# ------------------------------------------------------------------ the legs

# The way out of 13th Street: a freight shaft up twelve floors of dormitory,
# a hatch at street level, and the white towers of the centre all round.
func _leg_undercity() -> void:
	var floor_h := 300.0
	for k in 13:
		var z := k * floor_h
		var label := ("B%d" % (12 - k)) if k < 12 else ""
		objs.append([FRAME, 640.0, 380.0, z, 120.0 if k < 12 else 260.0, label, k < 12])
	var g := 12 * floor_h
	objs.append([GRID, g - 4.0, 700.0, 6000.0])
	_towers_ring(Vector2.ZERO, 950.0, 2900.0, g, 250.0, 800.0, 34, "corp")
	path.append(Vector3(0, 0, -200.0 + D0))
	path.append(Vector3(0, 0, g + 900.0 + D0))
	fog = 5200.0


# Sideways over the city, down a canyon of buildings: style a for the first
# half of the way, b for the second; bridges cross under the deck now and then.
func _leg_side(a: String, b: String, _y: float) -> void:
	var length := 24000.0
	path.append(Vector3(0, 0, 0))
	path.append(Vector3(length, 0, 0))
	var mid := length * 0.5
	for side in [-1.0, 1.0]:
		for row in 3:
			var x := -5000.0 + rng.randf_range(0, 300)
			while x < length + 5000.0:
				var style := a if x < mid + rng.randf_range(-1200, 1200) else b
				x += _place(style, x, side, row)
	var bx := 1800.0
	while bx < length + 3000.0:
		objs.append([BOX, bx, -1600.0, bx + 150.0, 1600.0, -D0 - 520.0, -D0 - 330.0, 0, true])
		bx += rng.randf_range(2400, 3400)
	objs.append([GRID, -D0 - 4400.0, 1000.0, 32000.0])
	if a == "rails" or b == "rails":
		# the network's tracks: bundles of lit line both sides, sleepers across them
		var from := 0.0 if a == "rails" else mid - 2000.0
		var to := mid + 2000.0 if a == "rails" else length + 5000.0
		for side in [-1.0, 1.0]:
			for k in 3:
				var ry: float = side * (560.0 + k * 150.0)
				var rz := -D0 - 650.0 - k * 120.0
				objs.append([LINE, PackedVector3Array([Vector3(from - 4000.0, ry, rz), Vector3(to + 4000.0, ry, rz)]), 1.5, 2.0])
				objs.append([LINE, PackedVector3Array([Vector3(from - 4000.0, ry + side * 40.0, rz), Vector3(to + 4000.0, ry + side * 40.0, rz)]), 1.1, 1.0])
			var sx := from - 4000.0
			while sx < to + 4000.0:
				objs.append([LINE, PackedVector3Array([Vector3(sx, side * 520.0, -D0 - 660.0), Vector3(sx, side * 900.0, -D0 - 900.0)]), 0.8, 1.0])
				sx += 420.0
	fog = 4400.0


# One building of a style at x along one side, in row 0 (the canyon wall), 1
# or 2 (further out); returns how far on the next one starts.
func _place(style: String, x: float, side: float, row: int) -> float:
	var y0: float = [330.0, 1000.0, 2000.0][row] + rng.randf_range(0, 120)
	if leg == 0:
		# (under a room: the rows start right under the middle)
		y0 = [40.0, 700.0, 1500.0][row] + rng.randf_range(0, 120)
	var tall: Vector2 = [Vector2(1060, 1500), Vector2(1250, 2100), Vector2(1700, 3000)][row]
	var ground := -D0 - 4400.0
	var top := -rng.randf_range(tall.x, tall.y)
	match style:
		"corp", "screens":
			var w := rng.randf_range(260, 560)
			var d := rng.randf_range(300, 620)
			var y := side * (y0 + d / 2.0)
			var win := 3 if (style == "screens" and rng.randf() < 0.45) or rng.randf() < 0.08 else 2
			objs.append([BOX, x, y - d / 2.0, x + w, y + d / 2.0, ground, top, win, rng.randf() < 0.18])
			if rng.randf() < 0.3:
				objs.append([BEAM, x + w / 2.0, y, top, top + rng.randf_range(140, 300)])
			return w + rng.randf_range(40, 180)
		"industry":
			var w := rng.randf_range(700, 1400)
			var d := rng.randf_range(420, 800)
			var y := side * (y0 + d / 2.0)
			var t2 := top - 500.0
			objs.append([BOX, x, y - d / 2.0, x + w, y + d / 2.0, ground, t2, 1, false])
			if rng.randf() < 0.55:
				objs.append([CYL, x + w * 0.8, y, rng.randf_range(50, 80), ground, top + 200.0, 1])
			if row == 0 and rng.randf() < 0.4:
				objs.append([LINE, PackedVector3Array([Vector3(x + w * 0.3, y, t2 - 40.0), Vector3(x + w * 0.3, -y, t2 - 40.0)]), 1.0, 3.0])
			return w + rng.randf_range(60, 200)
		"silos":
			var r := rng.randf_range(260, 420) if row < 2 else rng.randf_range(300, 500)
			var y := side * (y0 + r)
			objs.append([CYL, x + r, y, r, ground, top - 100.0, 3])
			return r * 2.0 + rng.randf_range(30, 120)
		"rails":
			if row == 0:
				var w := rng.randf_range(500, 900)
				var d := rng.randf_range(200, 360)
				var y := side * (y0 + d / 2.0)
				objs.append([BOX, x, y - d / 2.0, x + w, y + d / 2.0, ground, top - 700.0, 0, false])
				return w + rng.randf_range(300, 700)
			# bundles of lit line, the network's tracks running alongside
			var ry := side * (y0 + rng.randf_range(0, 500))
			var rz := top - 300.0
			objs.append([LINE, PackedVector3Array([Vector3(x - 3000, ry, rz), Vector3(x + 3000, ry * 0.9, rz)]), 1.3, 2.0])
			objs.append([BOX, x, minf(side * 300.0, ry + side * 120.0), x + 90, maxf(side * 300.0, ry + side * 120.0), rz - 400.0, rz + 40.0, 0, false])
			return rng.randf_range(1400, 2200)
		"energy":
			if row > 0 and rng.randf() < 0.5:
				var r := rng.randf_range(450, 680)
				var y := side * (y0 + r)
				objs.append([CYL, x + r, y, r, ground, top - 300.0, 4])
				return r * 2.0 + 160.0
			var w := 80.0
			var y := side * (y0 + 60.0)
			var t3 := top + 250.0
			objs.append([BOX, x, y - w / 2.0, x + w, y + w / 2.0, ground, t3, 0, true])
			var pts := PackedVector3Array()
			for k in 9:
				var f := k / 8.0
				pts.append(Vector3(x + w / 2.0 + f * 900.0, y, t3 - 240.0 * sin(PI * f)))
			objs.append([LINE, pts, 1.4, 1.5])
			return 900.0
	return 400.0


# A ring of towers round a point, from r0 to r1 out, standing on ground g.
func _towers_ring(c: Vector2, r0: float, r1: float, g: float, h0: float, h1: float, n: int, style: String) -> void:
	for i in n * 3:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(r0 * r0, r1 * r1))
		var p := c + Vector2.from_angle(a) * r
		var w := rng.randf_range(260, 520)
		var d := rng.randf_range(260, 520)
		objs.append([BOX, p.x - w / 2.0, p.y - d / 2.0, p.x + w / 2.0, p.y + d / 2.0, g, g + rng.randf_range(h0, h1), 2 if style == "corp" else 1, rng.randf() < 0.15])


# Down from the bureau into the sea: a round pressure shaft, its depth called
# at every third ring, pipes down its wall, the archive's vaults below.
func _leg_sea_down() -> void:
	var floor_z := -5200.0
	for k in 17:
		var z := -k * 300.0
		objs.append([TUBE, 0.0, 0.0, 700.0, z, 80.0 if k % 3 == 0 else 46.0, ("-%d M" % (k * 250)) if k % 3 == 0 else ""])
	for i in 8:
		var v := Vector2.from_angle(TAU * i / 8.0 + 0.2) * 650.0
		objs.append([LINE, PackedVector3Array([Vector3(v.x, v.y, -60.0), Vector3(v.x, v.y, floor_z)]), 1.0 if i % 2 == 0 else 0.8, 3.0])
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		var p := Vector2.from_angle(a) * rng.randf_range(900, 1800)
		objs.append([CYL, p.x, p.y, rng.randf_range(260, 420), floor_z - 400.0, floor_z + rng.randf_range(700, 1400), 3])
	objs.append([GRID, floor_z, 600.0, 4200.0])
	path.append(Vector3(0, 0, 200.0 + D0))
	path.append(Vector3(0, 0, floor_z + 1700.0 + D0))
	fog = 3800.0


# Up from the anchor on the sea floor: guide rings round the cable, the sea's
# surface going by, then up into the clouds.
func _leg_sea_up() -> void:
	var floor_z := 0.0
	for i in 9:
		var a := TAU * i / 9.0
		var p := Vector2.from_angle(a) * rng.randf_range(1000, 1900)
		objs.append([CYL, p.x, p.y, rng.randf_range(260, 400), floor_z - 300.0, floor_z + rng.randf_range(500, 1100), 3])
	objs.append([GRID, floor_z, 600.0, 4200.0])
	for k in 16:
		objs.append([TUBE, 0.0, 0.0, 720.0, 1200.0 + k * 460.0, 70.0 if k % 2 == 0 else 40.0, ""])
	var sea := 4800.0
	objs.append([GRID, sea, 380.0, 7000.0, true])
	for i in 30:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(800, 3400)
		objs.append([CLOUD, p.x, p.y, rng.randf_range(500, 1000), rng.randf_range(260, 520), sea + rng.randf_range(1500, 2300)])
	path.append(Vector3(0, 0, floor_z + 700.0 + D0))
	path.append(Vector3(0, 0, sea + 2900.0 + D0))
	fog = 4400.0


# The lift climbing out of the air: the clouds fall away below, the capital's
# rings shrink to a map, the sky turns to stars, the shipyard closes round.
func _leg_space_up() -> void:
	_city_below(0.0)
	for i in 34:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(700, 3800)
		objs.append([CLOUD, p.x, p.y, rng.randf_range(500, 1100), rng.randf_range(260, 560), 6000.0 + rng.randf_range(-300, 300)])
	for k in 12:
		objs.append([TUBE, 0.0, 0.0, 720.0, 7000.0 + k * 620.0, 60.0 if k % 2 == 0 else 34.0, ""])
	for k in 4:
		objs.append([FRAME, 860.0 + k * 140.0, 560.0 + k * 110.0, 14000.0 + k * 220.0, 110.0, "", false])
	path.append(Vector3(0, 0, 4400.0 + D0))
	path.append(Vector3(0, 0, 14500.0 + D0))
	fog = 9000.0


# The capital far below, as the Board's map shows it: rings of light round the tower.
func _city_below(g: float) -> void:
	for k in 5:
		objs.append([RING, 0.0, 0.0, 900.0 + k * 900.0, g, 1.2 if k == 2 else 0.7, 120])
	for i in 140:
		var a := rng.randf() * TAU
		var r := rng.randf_range(300, 4400)
		objs.append([TEXT, cos(a) * r, sin(a) * r, g, ".", 60])
	objs.append([CYL, 0.0, 0.0, 160.0, g, g + 3000.0, 4])


# Along the shipyard in orbit: warship hulls on their slips both sides,
# gantries across under the deck, the planet's rim far below; the
# institute's rings ahead.
func _leg_orbit() -> void:
	planet = true
	var length := 24000.0
	path.append(Vector3(0, 0, 0))
	path.append(Vector3(length, 0, 0))
	for side in [-1.0, 1.0]:
		var x := -4000.0
		while x < length * 0.62:
			var w := rng.randf_range(2200, 3600)
			var d := rng.randf_range(420, 640)
			var y: float = side * rng.randf_range(560, 900)
			var top := -rng.randf_range(1150, 1500)
			objs.append([BOX, x, y - d / 2.0, x + w, y + d / 2.0, top - 420.0, top, 4, false])
			# the slip's frame round it
			objs.append([BOX, x - 60.0, y - d / 2.0 - 80.0, x + w + 60.0, y + d / 2.0 + 80.0, top - 900.0, top - 520.0, 0, false])
			x += w + rng.randf_range(260, 600)
	var gx := 1200.0
	while gx < length * 0.66:
		objs.append([BOX, gx, -1800.0, gx + 90.0, 1800.0, -D0 - 520.0, -D0 - 380.0, 0, true])
		gx += rng.randf_range(1600, 2400)
	for k in 8:
		var cx := length * 0.68 + k * 1200.0
		objs.append([ARC, cx, 0.0, -D0 - 600.0 - (k % 3) * 400.0, 1200.0 + (k % 2) * 500.0, 0.7 + 0.2 * (k % 2), k])
	fog = 5200.0
	stars = 1.0


# Over the clouds to the white tower: you come in level above the cloud
# deck, the tower's crown grows ahead, its walls go down through the clouds
# out of sight, red down its corners and its middle, and the deck comes to
# rest over its roof.
func _leg_tower_down() -> void:
	stars = 1.0
	fog = 16000.0
	path.append(Vector3(-6500, 0, 0))
	path.append(Vector3(0, 0, 0))
	var top := -D0 - 160.0
	var roof := -D0 - 900.0
	var foot := -26000.0
	# the tower: its wall toward you windowed floor on floor; two narrower tiers
	# stepping up off its roof, the landing on the topmost
	objs.append([BOX, -1100.0, -820.0, 1100.0, 820.0, foot, roof, 2, 2])
	objs.append([BOX, -760.0, -560.0, 760.0, 560.0, roof, roof + 420.0, 2, 2])
	objs.append([BOX, -460.0, -340.0, 460.0, 340.0, roof + 420.0, top, 2, 2])
	var fz := roof - 420.0
	while fz > roof - 9000.0:
		objs.append([LINE, PackedVector3Array([Vector3(-1100.0, -820.0, fz), Vector3(-1100.0, 820.0, fz)]), 1.5, 3.0])
		objs.append([LINE, PackedVector3Array([Vector3(-1100.0, -820.0, fz - 60.0), Vector3(-1100.0, 820.0, fz - 60.0)]), 1.0, 1.0])
		fz -= 420.0
	objs.append([RING, 0.0, 0.0, 300.0, top + 4.0, 1.0, 48, true])
	objs.append([LINE, PackedVector3Array([Vector3(-1100.0, 0.0, roof), Vector3(-1100.0, 0.0, foot)]), 2.2, 6.0, true])
	for y in [-820.0, 820.0]:
		objs.append([LINE, PackedVector3Array([Vector3(-1100.0, y, roof), Vector3(-1100.0, y, foot)]), 2.0, 3.0, true])
	objs.append([RING, 0.0, 0.0, 560.0, top + 2.0, 1.0, 64])
	objs.append([RING, 0.0, 0.0, 700.0, top + 2.0, 1.0, 72, true])
	for s2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		objs.append([BEAM, s2.x * 1100.0, s2.y * 820.0, roof, roof + 380.0])
	# its crown's lower tiers, stepping out under the roof
	for tr in [[1500.0, 1150.0, roof - 1400.0], [1950.0, 1500.0, roof - 2900.0]]:
		objs.append([BOX, -tr[0], -tr[1], tr[0], tr[1], tr[2] - 600.0, tr[2], 5, true])
	# the cloud deck far below, and the lesser towers that do not reach it
	for i in 70:
		var p := Vector2(rng.randf_range(-19000, 3000), rng.randf_range(-5200, 5200))
		objs.append([CLOUD, p.x, p.y, rng.randf_range(900, 1700), rng.randf_range(420, 800), -7000.0 + rng.randf_range(-400, 400)])
	for i in 26:
		var p := Vector2(rng.randf_range(-18000, 2000), rng.randf_range(-4800, 4800) )
		if absf(p.y) < 1400.0:
			continue
		var w := rng.randf_range(500, 900)
		objs.append([BOX, p.x, p.y, p.x + w, p.y + w * 0.7, foot, -rng.randf_range(4200, 6400), 2, false])
	# the defence platforms riding the sky
	for i in 10:
		var p := Vector2(rng.randf_range(-15000, -2000), rng.randf_range(-2600, 2600))
		var z := -D0 - rng.randf_range(600, 2600)
		var w := rng.randf_range(160, 260)
		objs.append([BOX, p.x - w / 2.0, p.y - 70.0, p.x + w / 2.0, p.y + 70.0, z - 90.0, z, 0, true])
		objs.append([BOX, p.x - w / 2.0 - 520.0, p.y - 120.0, p.x - w / 2.0 - 30.0, p.y + 120.0, z - 30.0, z - 10.0, 4, false])
		objs.append([BOX, p.x + w / 2.0 + 30.0, p.y - 120.0, p.x + w / 2.0 + 520.0, p.y + 120.0, z - 30.0, z - 10.0, 4, false])


# ------------------------------------------------------------------ drawing

func proj(p: Vector3) -> Vector3:
	var d := eye.z - p.z
	if d < NEAR:
		return Vector3(0, 0, -1)
	var s := F / d
	return Vector3(C.x + (p.x - eye.x) * s, C.y + (p.y - eye.y) * s, s)


func _p2(p: Vector3) -> Vector2:
	var q := proj(p)
	return Vector2(q.x, q.y)


# How visible a thing at depth d is: faded out near the eye, into the dark far below.
func fade(d: float) -> float:
	if d < D0:
		return clampf((d - NEAR) / 260.0, 0.0, 1.0)
	return clampf(1.0 - (d - D0) / fog, 0.0, 1.0)


func _fill(a: float, lift := 1.0) -> Color:
	var c := Color(0.062, 0.062, 0.07) * lift
	return Pal.BG.lerp(Color(c.r, c.g, c.b), a)


var draw_us := 0.0           # (profiling) how long the last _draw took
var drawn := 0


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	drawn = 0
	draw_rect(SCREEN, Pal.BG)
	var sk := stars if leg != 9 else clampf((u - 0.45) / 0.4, 0.0, 1.0)
	if sk > 0.0:
		for s: Array in star_pts:
			var tw := 0.6 + 0.4 * sin(t * 2.0 + s[2])
			draw_rect(Rect2(s[0], Vector2(2, 2)), Pal.ink(0.5 * s[1] * tw * sk, 1.2))
	if planet:
		_draw_planet()
	for o: Array in objs:
		match int(o[0]):
			BOX: _box(o)
			CYL: _cyl(o)
			LINE: _line3(o)
			RING: _ring(o)
			CLOUD: _cloud(o)
			TEXT: _text(o)
			FRAME: _frame(o)
			GRID: _grid(o)
			ARC: _arc(o)
			BEAM: _beam(o)
			TUBE: _tube(o)
			TRAIN: _train(o)
			CAR: _car(o)
	_dust()
	draw_us = Time.get_ticks_usec() - t0


func _draw_planet() -> void:
	# the rim of the world far below, the air a few thin lines over it
	var c := Vector2(1240, 3500)
	var r := 2900.0
	draw_circle(c, r, Color(0.03, 0.032, 0.04))
	draw_arc(c, r, PI * 1.05, PI * 1.95, 160, Pal.ink(0.35, 1.0), 2.0)
	for k in 4:
		draw_arc(c, r + 14.0 + k * 16.0, PI * 1.08, PI * 1.92, 160, Pal.ink(0.12 / (k + 1), 1.0), 1.5)
	# the night side's cities: a scatter of points
	for i in 60:
		var a := PI * 1.15 + fmod(i * 0.618, 1.0) * PI * 0.7
		var rr := r - 30.0 - fmod(i * 73.0, 900.0)
		draw_rect(Rect2(c + Vector2.from_angle(a) * rr, Vector2(2, 2)), Pal.ink(0.25, 1.3))


func _visible_poly(pts: PackedVector2Array) -> bool:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	if not SCREEN.intersects(r):
		return false
	return not DECK.grow(-4).encloses(r)


func _box(o: Array) -> void:
	var x0: float = o[1]
	var y0: float = o[2]
	var x1: float = o[3]
	var y1: float = o[4]
	var z0: float = o[5]
	var z1: float = o[6]
	var d := eye.z - z1
	if d < NEAR:
		return
	var a := fade(d)
	if a < 0.02:
		return
	# the top face, projected straight (no Vector3s: this runs for hundreds a frame)
	var s1 := F / d
	var ax := C.x + (x0 - eye.x) * s1
	var bx := C.x + (x1 - eye.x) * s1
	var ay := C.y + (y0 - eye.y) * s1
	var by := C.y + (y1 - eye.y) * s1
	if bx < -80.0 or ax > 2000.0 or by < -80.0 or ay > 1160.0:
		# (its foot leans in toward the middle, so the top shows the most of it)
		return
	var zb := maxf(z0, eye.z - D0 - fog * 1.4)
	var s0 := F / (eye.z - zb)
	var cx := C.x - eye.x * s0
	var cy := C.y - eye.y * s0
	var T := PackedVector2Array([Vector2(ax, ay), Vector2(bx, ay), Vector2(bx, by), Vector2(ax, by)])
	var B := PackedVector2Array([Vector2(cx + x0 * s0, cy + y0 * s0), Vector2(cx + x1 * s0, cy + y0 * s0), Vector2(cx + x1 * s0, cy + y1 * s0), Vector2(cx + x0 * s0, cy + y1 * s0)])
	var hull := Rect2(T[0], T[2] - T[0]).merge(Rect2(B[0], B[2] - B[0]))
	if DECK.grow(-4).encloses(hull):
		return
	var glow: int = int(o[8])     # 0 plain, 1 lit, 2 the leg's hero
	var faint := Pal.ink(0.22 * a, 1.0)
	if a > 0.3:
		# the sides that face the eye: lit at the top, gone into the dark at the foot
		var faces := [eye.y < y0, eye.x > x1, eye.y > y1, eye.x < x0]
		var c_top := _fill(a, (0.8 if o[7] == 4 else 1.45) if glow == 2 else 1.0)
		var c_bot := Pal.BG
		var e_top := Pal.ink((0.95 if glow == 2 else 0.22) * a, 1.7 if glow == 2 else 1.0)
		var e_bot := Pal.ink(0.0)
		var win: int = o[7] if a > 0.45 else 0
		for i in 4:
			if not faces[i]:
				continue
			var j := (i + 1) % 4
			if glow == 2 and leg != 0 and Rect2(T[i], Vector2.ZERO).expand(T[j]).expand(B[i]).expand(B[j]).intersects(DECK.grow(-20.0)):
				# (a hero's wall would stand across the deck: its roof says enough)
				continue
			draw_polygon(PackedVector2Array([T[i], T[j], B[j], B[i]]), PackedColorArray([c_top, c_top, c_bot, c_bot]))
			draw_polyline_colors(PackedVector2Array([T[i], B[i], B[j], T[j]]), PackedColorArray([e_top, e_bot, e_bot, e_top]), 1.0)
			if win > 0:
				_windows(T[i], T[j], B[j], B[i], win, a, x0 + y0 + i)
	draw_colored_polygon(T, _fill(a, (1.1 if o[7] == 4 else 2.4) if glow == 2 else 1.6))
	var top := T.duplicate()
	top.append(T[0])
	if glow == 2:
		# the hero: a halo, a hard bright rim, a red edge and red lights at its corners
		draw_polyline(top, Pal.ink(0.16 * a), 14.0)
		draw_polyline(top, Pal.ink(a, 2.0), 3.5)
		if o[7] == 3:
			draw_polyline(top, Pal.red(0.22 * a), 20.0)
			draw_polyline(top, Pal.red(a, 2.0), 7.0)
			for fy in [0.69, 0.75]:
				var l0 := T[0].lerp(T[3], fy)
				var l1 := T[1].lerp(T[2], fy)
				draw_line(l0, l1, Pal.red(0.2 * a), 26.0)
				draw_line(l0, l1, Pal.red(0.9 * a, 1.8), 6.0)
		else:
			draw_line(T[3], T[2], Pal.red(0.25 * a), 12.0)
			draw_line(T[3], T[2], Pal.red(a, 2.0), 3.0)
		var blink := 0.35 + 0.65 * absf(sin(t * 2.4))
		for q in T:
			draw_circle(q, 6.0, Pal.red(blink * a, 2.4))
		var cols := 8 if o[7] != 3 else 12
		var rows := 4 if o[7] != 3 else 8
		for k in range(1, cols):
			draw_line(T[0].lerp(T[1], float(k) / cols), T[3].lerp(T[2], float(k) / cols), Pal.ink(0.16 * a), 1.0)
		for k in range(1, rows):
			draw_line(T[0].lerp(T[3], float(k) / rows), T[1].lerp(T[2], float(k) / rows), Pal.ink(0.16 * a), 1.0)
		if o[7] == 3:
			# every few panels lit, flickering as a screen does
			for i in cols:
				for j in rows:
					if (i * 7 + j * 3) % 5 != 0:
						continue
					var fa := float(i) / cols
					var fb := float(j) / rows
					var fa2 := float(i + 1) / cols
					var fb2 := float(j + 1) / rows
					var q := PackedVector2Array([T[0].lerp(T[1], fa).lerp(T[3].lerp(T[2], fa), fb), T[0].lerp(T[1], fa2).lerp(T[3].lerp(T[2], fa2), fb), T[0].lerp(T[1], fa2).lerp(T[3].lerp(T[2], fa2), fb2), T[0].lerp(T[1], fa).lerp(T[3].lerp(T[2], fa), fb2)])
					draw_colored_polygon(q, Pal.ink((0.07 + 0.05 * sin(t * 5.0 + i + j)) * a, 1.2))
	else:
		draw_polyline(top, Pal.ink(0.75 * a, 1.5) if glow == 1 else Pal.ink(0.3 * a, 1.0), 1.5)
	if o[7] == 1:
		# a factory roof: saw-tooth ridges across the top
		for k in range(1, 6):
			var f := k / 6.0
			draw_line(T[0].lerp(T[1], f), T[3].lerp(T[2], f), faint, 1.0)
	elif o[7] == 5:
		# a tier of the tower's crown: its roof ruled toward the middle, lit along the rim
		for k in range(1, 4):
			var f := k * 0.11
			var q := PackedVector2Array([T[0].lerp(T[2], f), T[1].lerp(T[3], f), T[2].lerp(T[0], f), T[3].lerp(T[1], f), T[0].lerp(T[2], f)])
			draw_polyline(q, Pal.ink(0.28 * a / k, 1.0), 1.0)
		for i in 4:
			draw_line(T[i], T[i].lerp(T[(i + 2) % 4], 0.33), Pal.ink(0.22 * a), 1.0)
		var n := 18
		for i in 4:
			for k in n:
				var p := T[i].lerp(T[(i + 1) % 4], (k + 0.5) / n)
				draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Pal.ink(0.7 * a * (0.6 + 0.4 * sin(t * 2.0 + k + i)), 1.5))
	elif o[7] == 4:
		# a hull: ribs across it
		for k in range(1, 12):
			var f := k / 12.0
			draw_line(T[0].lerp(T[1], f), T[3].lerp(T[2], f), faint, 1.0)
		draw_line(T[0].lerp(T[3], 0.5), T[1].lerp(T[2], 0.5), Pal.ink(0.4 * a, 1.3), 1.0)
		if glow == 2:
			# a warship: a pointed bow ahead, its keel lit along its length
			var mid := T[1].lerp(T[2], 0.5)
			var tip := mid + (T[1] - T[0]).normalized() * (T[2] - T[1]).length() * 0.24
			draw_colored_polygon(PackedVector2Array([T[1], tip, T[2]]), _fill(a, 1.1))
			draw_polyline(PackedVector2Array([T[1], tip, T[2]]), Pal.ink(a, 1.9), 3.5)
			draw_line(T[0].lerp(T[3], 0.5), tip, Pal.ink(0.8 * a, 1.6), 2.5)
			# lit ports down both flanks, the drives red at its stern
			for k in 14:
				var f2 := (k + 0.5) / 14.0
				for side in [0.62, 0.74, 0.86]:
					var pp: Vector2 = T[0].lerp(T[1], f2).lerp(T[3].lerp(T[2], f2), side)
					draw_rect(Rect2(pp - Vector2(6, 4), Vector2(12, 8)), Pal.ink(0.9 * a, 1.9))
			for k in 3:
				var q2 := T[0].lerp(T[3], 0.6 + k * 0.14)
				var rr := maxf(46.0, (T[3] - T[0]).length() * 0.06)
				draw_circle(q2 + (T[0] - T[1]).normalized() * rr * 0.8, rr * 2.2, Pal.red(0.16 * a))
				draw_circle(q2 + (T[0] - T[1]).normalized() * rr * 0.8, rr * 1.4, Pal.red(0.4 * a, 1.6))
				draw_circle(q2, rr, Pal.red(0.95 * a, 2.4))


# Lit windows across a side face (a quad from top-left round to bottom-left).
func _windows(tl: Vector2, tr: Vector2, br: Vector2, bl: Vector2, kind: int, a: float, seed: float) -> void:
	var h := (tl.distance_to(bl) + tr.distance_to(br)) * 0.5
	var w := (tl.distance_to(tr) + bl.distance_to(br)) * 0.5
	if h < 24.0 or w < 10.0:
		return
	if kind == 3:
		# a screen as big as the building's face: a slogan you cannot read from here
		var q := PackedVector2Array([tl.lerp(bl, 0.08).lerp(tr.lerp(br, 0.08), 0.1), tl.lerp(bl, 0.08).lerp(tr.lerp(br, 0.08), 0.9), tl.lerp(bl, 0.42).lerp(tr.lerp(br, 0.42), 0.9), tl.lerp(bl, 0.42).lerp(tr.lerp(br, 0.42), 0.1)])
		var flick := 0.75 + 0.25 * sin(t * 9.0 + seed)
		draw_colored_polygon(q, Pal.ink(0.08 * a * flick, 1.0))
		q.append(q[0])
		draw_polyline(q, Pal.ink(0.6 * a * flick, 1.6), 1.5)
		for k in 5:
			var f := 0.12 + k * 0.06
			draw_line(tl.lerp(bl, f).lerp(tr.lerp(br, f), 0.14), tl.lerp(bl, f).lerp(tr.lerp(br, f), 0.86), Pal.ink(0.2 * a, 1.2), 1.0)
		return
	if h < 40.0:
		return
	# rows down the lit upper part of the face; which windows are on comes
	# from a fixed table, one draw for the lot
	var rows := clampi(int(h * 0.6 / 26.0), 1, 10)
	var cols := clampi(int(w / 22.0), 1, 8)
	var base := int(absf(seed) * 7.0) & 4095
	var pts := PackedVector2Array()
	var cs := PackedColorArray()
	for r in rows:
		var fy := (r + 0.5) / rows * 0.6
		var l := tl.lerp(bl, fy)
		var rr := tr.lerp(br, fy)
		var dx := (rr - l) / cols * 0.28
		var lit := Pal.ink(0.34 * a * (1.0 - fy * 1.2), 1.35)
		for c in cols:
			if not LIT[(base + r * 37 + c * 11) & 4095]:
				continue
			var p := l.lerp(rr, (c + 0.5) / cols)
			pts.append(p - dx)
			pts.append(p + dx)
			cs.append(lit)
	if pts.size() >= 2:
		draw_multiline_colors(pts, cs, 1.5)


func _cyl(o: Array) -> void:
	var cx: float = o[1]
	var cy: float = o[2]
	var r: float = o[3]
	var z0: float = o[4]
	var z1: float = o[5]
	var d := eye.z - z1
	if d < NEAR:
		return
	var a := fade(d)
	if a < 0.02:
		return
	var s1 := F / d
	var tx := C.x + (cx - eye.x) * s1
	var ty := C.y + (cy - eye.y) * s1
	var rr := r * s1
	if tx + rr < -60.0 or tx - rr > 1980.0 or ty + rr < -60.0 or ty - rr > 1140.0:
		return
	var tc := Vector3(tx, ty, s1)
	var zb := maxf(z0, eye.z - D0 - fog * 1.4)
	var bc := proj(Vector3(cx, cy, zb))
	var tr := r * tc.z
	var br := r * bc.z
	var tp := Vector2(tc.x, tc.y)
	var bp := Vector2(bc.x, bc.y)
	var box := Rect2(tp - Vector2(tr, tr), Vector2(tr, tr) * 2.0).merge(Rect2(bp - Vector2(br, br), Vector2(br, br) * 2.0))
	if not SCREEN.intersects(box) or DECK.grow(-4).encloses(box):
		return
	# the side: the band between the two circles, bounded by its tangents
	var dir := (tp - bp)
	var n := Vector2(-dir.y, dir.x).normalized() if dir.length() > 0.5 else Vector2.RIGHT
	draw_colored_polygon(PackedVector2Array([tp + n * tr, tp - n * tr, bp - n * br, bp + n * br]), _fill(a, 0.85))
	draw_circle(bp, br, _fill(a, 0.85))
	draw_line(tp + n * tr, bp + n * br, Pal.ink(0.4 * a), 1.0)
	draw_line(tp - n * tr, bp - n * br, Pal.ink(0.4 * a), 1.0)
	draw_circle(tp, tr, _fill(a, 1.25))
	var rings: int = o[6]
	var k_top := 1.6 if rings == 4 else 1.0
	if o.size() > 7 and o[7]:
		# the hero: halo, a hard rim, scale marks round it, a red ring inside
		draw_arc(tp, tr, 0, TAU, 72, Pal.ink(0.16 * a), 16.0)
		draw_arc(tp, tr, 0, TAU, 72, Pal.ink(a, 2.0), 3.5)
		for k in 48:
			var v := Vector2.from_angle(TAU * k / 48.0)
			draw_line(tp + v * tr, tp + v * tr * (0.93 if k % 4 == 0 else 0.965), Pal.ink(0.6 * a, 1.3), 1.5)
		draw_arc(tp, tr * 0.8, 0, TAU, 64, Pal.red(0.22 * a), 12.0)
		draw_arc(tp, tr * 0.8, 0, TAU, 64, Pal.red(a, 2.0), 3.0)
		for k in range(1, 4):
			draw_arc(tp, tr * (0.8 - k * 0.16), 0, TAU, 48, Pal.ink((0.35 + 0.25 * sin(t * 2.6 + k)) * a, 1.4), 1.5)
		return
	draw_arc(tp, tr, 0, TAU, 40, Pal.ink(0.75 * a, k_top), 1.5)
	if rings >= 3:
		for k in range(1, 3 if rings == 3 else 4):
			draw_arc(tp, tr * (1.0 - k * 0.22), 0, TAU, 32, Pal.ink((0.35 if rings == 3 else 0.5 + 0.3 * sin(t * 3.0 + k)) * a, 1.3 if rings == 4 else 1.0), 1.0)
	elif rings == 1:
		draw_arc(tp, tr * 0.6, 0, TAU, 20, Pal.ink(0.5 * a, 1.6), 1.0)


func _line3(o: Array) -> void:
	var pts: PackedVector3Array = o[1]
	var k: float = o[2]
	var w: float = o[3]
	var out := PackedVector2Array()
	out.resize(pts.size())
	var amin := 1.0
	var amax := 0.0
	var al := PackedFloat32Array()
	al.resize(pts.size())
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	# (points up past the eye are cut away: the line runs on out of sight)
	var keep := PackedVector3Array()
	for p in pts:
		if eye.z - p.z >= NEAR:
			keep.append(p)
	if keep.size() < 2:
		return
	pts = keep
	out.resize(pts.size())
	al.resize(pts.size())
	for i in pts.size():
		var p := pts[i]
		var d := eye.z - p.z
		var sc := F / d
		var q := Vector2(C.x + (p.x - eye.x) * sc, C.y + (p.y - eye.y) * sc)
		out[i] = q
		lo = lo.min(q)
		hi = hi.max(q)
		al[i] = fade(d)
		amin = minf(amin, al[i])
		amax = maxf(amax, al[i])
	if amax < 0.02 or hi.x < -60.0 or lo.x > 1980.0 or hi.y < -60.0 or lo.y > 1140.0:
		return
	var red: bool = o.size() > 4 and o[4]
	if amax - amin < 0.05:
		if k >= 1.3:
			draw_polyline(out, Pal.red(0.14 * amin) if red else Pal.ink(0.12 * amin, 1.0), w + 6.0)
		draw_polyline(out, Pal.red(0.9 * amin, k) if red else Pal.ink(0.7 * amin, k), w)
		return
	# (a long line into the depths: bright where it is near, gone where it is far)
	var cs := PackedColorArray()
	var gs := PackedColorArray()
	cs.resize(pts.size())
	gs.resize(pts.size())
	for i in pts.size():
		cs[i] = Pal.red(0.9 * al[i], k) if red else Pal.ink(0.7 * al[i], k)
		gs[i] = Pal.red(0.14 * al[i]) if red else Pal.ink(0.12 * al[i])
	if k >= 1.3:
		draw_polyline_colors(out, gs, w + 6.0)
	draw_polyline_colors(out, cs, w)


func _ring(o: Array) -> void:
	var z: float = o[4]
	var d := eye.z - z
	if d < NEAR:
		return
	var a := fade(d) * float(o[5])
	if a < 0.02:
		return
	var c := proj(Vector3(o[1], o[2], z))
	var r: float = float(o[3]) * c.z
	if r < 4.0:
		return
	var p := Vector2(c.x, c.y)
	if r < 520.0 and DECK.grow(-4).has_point(p - Vector2(r, r)) and DECK.grow(-4).has_point(p + Vector2(r, r)):
		return
	if o.size() > 7 and o[7]:
		draw_arc(p, r, 0, TAU, int(o[6]), Pal.red(0.2 * a), 10.0)
		draw_arc(p, r, 0, TAU, int(o[6]), Pal.red(0.95 * a, 1.9), 3.0)
		# a beacon's pulse running out from it
		var pu := fmod(t * 0.7 + float(o[3]) * 0.001, 1.0)
		draw_arc(p, r * (1.0 + pu * 0.8), 0, TAU, int(o[6]), Pal.red((1.0 - pu) * 0.6 * a, 1.8), 2.0)
		return
	draw_arc(p, r, 0, TAU, int(o[6]), Pal.ink(0.12 * a), 6.0)
	draw_arc(p, r, 0, TAU, int(o[6]), Pal.ink(0.7 * a, 1.25), 1.5)
	# the ring's ribs
	for k in 12:
		var v := Vector2.from_angle(TAU * k / 12.0 + float(o[1]) * 0.001)
		draw_line(p + v * r, p + v * r * 1.06, Pal.ink(0.4 * a), 1.0)


func _cloud(o: Array) -> void:
	var z: float = o[5]
	var d := eye.z - z
	if d < NEAR:
		return
	var a := fade(d)
	if d < D0 * 1.4:
		a *= clampf((d - NEAR) / (D0 * 0.6), 0.0, 1.0)
	if a < 0.02:
		return
	var c := proj(Vector3(o[1], o[2], z))
	var rx: float = float(o[3]) * c.z
	var ry: float = float(o[4]) * c.z
	var p := Vector2(c.x, c.y)
	if not SCREEN.intersects(Rect2(p - Vector2(rx, ry), Vector2(rx, ry) * 2.0)):
		return
	# haze: a few thin streaks across it, longest through the middle
	var pts := PackedVector2Array()
	var n := 6
	for k in n:
		var fy := (k + 0.5) / n * 2.0 - 1.0
		var half := rx * sqrt(maxf(0.0, 1.0 - fy * fy)) * (0.8 + 0.2 * sin(k * 2.7 + float(o[1]) * 0.01))
		var y := p.y + fy * ry
		var x0 := p.x - half + sin(k * 1.9) * rx * 0.1
		pts.append(Vector2(x0, y))
		pts.append(Vector2(x0 + half * 2.0, y))
	draw_multiline(pts, Pal.ink(0.13 * a), maxf(1.0, 3.0 * c.z))


func _text(o: Array) -> void:
	var z: float = o[3]
	var d := eye.z - z
	if d < NEAR:
		return
	var a := fade(d)
	var c := proj(Vector3(o[1], o[2], z))
	var size := int(float(o[5]) * c.z)
	if size < 8 or size > 420 or a < 0.05:
		return
	var tw := font.get_string_size(o[4], HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	if visible_rect_hits_deck(Rect2(Vector2(c.x, c.y - tw.y * 0.8), tw)):
		return
	var loud: bool = o.size() > 6 and o[6]
	draw_string(font, Vector2(c.x, c.y), o[4], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Pal.ink(a, 1.6) if loud else Pal.ink(0.6 * a, 1.1))


# A floor slab round the shaft at height z: a square ring, the shaft's inside
# edge lit, its number stencilled, the dormitory windows below it.
func _frame(o: Array) -> void:
	var hw: float = o[1]
	var hh: float = o[2]
	var z: float = o[3]
	var th: float = o[4]
	var d := eye.z - z
	if d < NEAR:
		return
	var a := fade(d)
	if a < 0.02:
		return
	var s := F / d
	var i0 := Rect2(C.x + (-hw - eye.x) * s, C.y + (-hh - eye.y) * s, hw * 2.0 * s, hh * 2.0 * s)
	var o0 := i0.grow(th * s)
	if i0.size.x > 2600.0 or o0.size.x < DECK.size.x - 8.0:
		return
	var fc := _fill(a, 1.2)
	draw_rect(Rect2(o0.position, Vector2(o0.size.x, i0.position.y - o0.position.y)), fc)
	draw_rect(Rect2(Vector2(o0.position.x, i0.end.y), Vector2(o0.size.x, o0.end.y - i0.end.y)), fc)
	draw_rect(Rect2(Vector2(o0.position.x, i0.position.y), Vector2(i0.position.x - o0.position.x, i0.size.y)), fc)
	draw_rect(Rect2(Vector2(i0.end.x, i0.position.y), Vector2(o0.end.x - i0.end.x, i0.size.y)), fc)
	draw_rect(i0, Pal.ink(0.75 * a, 1.3), false, 2.0)
	draw_rect(o0, Pal.ink(0.25 * a), false, 1.0)
	# hazard stripes along the slab's lip
	var step := 26.0 * s
	var x := i0.position.x
	while x < i0.end.x - step:
		draw_line(Vector2(x, i0.position.y - 2.0), Vector2(x + step * 0.5, i0.position.y - 2.0 - 10.0 * s), Pal.ink(0.3 * a), 1.0)
		x += step
	var label: String = o[5]
	if label != "":
		var fs := int(42.0 * s)
		if fs >= 10 and fs < 200:
			draw_string(font, Vector2(i0.position.x - th * s * 0.85, i0.position.y + 60.0 * s), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.8 * a, 1.3))
	if o[6]:
		_dorms(hw, hh, z, a)


# The dormitory windows on the shaft's four walls, between this slab and the
# one above: rooms stacked eighteen to a room, a few lights left on.
func _dorms(hw: float, hh: float, z: float, a: float) -> void:
	var za := z + 70.0
	var zb := z + 230.0
	if eye.z - zb < NEAR:
		return
	var pts := PackedVector2Array()
	var lit := PackedVector2Array()
	var n := 7
	for wall in 4:
		for i in n:
			var f0 := (i + 0.2) / n
			var f1 := (i + 0.8) / n
			var p0: Vector3
			var p1: Vector3
			match wall:
				0:
					p0 = Vector3(lerpf(-hw, hw, f0), -hh, 0)
					p1 = Vector3(lerpf(-hw, hw, f1), -hh, 0)
				1:
					p0 = Vector3(hw, lerpf(-hh, hh, f0), 0)
					p1 = Vector3(hw, lerpf(-hh, hh, f1), 0)
				2:
					p0 = Vector3(lerpf(hw, -hw, f0), hh, 0)
					p1 = Vector3(lerpf(hw, -hw, f1), hh, 0)
				_:
					p0 = Vector3(-hw, lerpf(hh, -hh, f0), 0)
					p1 = Vector3(-hw, lerpf(hh, -hh, f1), 0)
			var q := [_p2(p0 + Vector3(0, 0, za)), _p2(p1 + Vector3(0, 0, za)), _p2(p1 + Vector3(0, 0, zb)), _p2(p0 + Vector3(0, 0, zb))]
			var on := fmod(absf(sin(z * 0.37 + wall * 11.0 + i * 3.1)) * 977.0, 1.0) < 0.3
			var target := lit if on else pts
			for k in 4:
				target.append(q[k])
				target.append(q[(k + 1) % 4])
	if pts.size() > 0:
		draw_multiline(pts, Pal.ink(0.18 * a), 1.0)
	if lit.size() > 0:
		draw_multiline(lit, Pal.ink(0.55 * a, 1.4), 1.0)


# A plane at height z: a grid of streets (or the sea, its lines rolling).
func _grid(o: Array) -> void:
	var z: float = o[1]
	var d := eye.z - z
	if d < NEAR:
		return
	var a := fade(d)
	if a < 0.02:
		return
	var step: float = o[2]
	var half: float = o[3]
	var sea: bool = o.size() > 4 and o[4]
	var pts := PackedVector2Array()
	var k := -half
	while k <= half:
		if sea:
			var line := PackedVector2Array()
			for i in 17:
				var x := -half + i * half / 8.0
				line.append(_p2(Vector3(x, k + 40.0 * sin(x * 0.002 + t * 1.4 + k), z)))
			draw_polyline(line, Pal.ink(0.22 * a), 1.0)
		else:
			pts.append(_p2(Vector3(-half, k, z)))
			pts.append(_p2(Vector3(half, k, z)))
			pts.append(_p2(Vector3(k, -half, z)))
			pts.append(_p2(Vector3(k, half, z)))
		k += step
	if pts.size() > 0:
		draw_multiline(pts, Pal.ink(0.16 * a), 1.0)


# The institute's rings: broken hoops at odd heights, each turning its own way.
func _arc(o: Array) -> void:
	var z: float = o[3]
	var d := eye.z - z
	var a := fade(d) * float(o[5])
	if a < 0.02 or d < NEAR:
		return
	var c := proj(Vector3(o[1], o[2], z))
	var r: float = float(o[4]) * c.z
	var p := Vector2(c.x, c.y)
	if p.x + r < -100.0 or p.x - r > 2020.0:
		return
	var spin: float = t * (0.3 if int(o[6]) % 2 == 0 else -0.22) + float(o[6])
	for k in 5:
		var a0 := spin + TAU * k / 5.0
		draw_arc(p, r, a0, a0 + TAU / 5.0 * 0.7, 24, Pal.ink(0.75 * a, 1.5), 2.0)
		draw_arc(p, r * 0.94, a0 + 0.1, a0 + TAU / 5.0 * 0.55, 18, Pal.ink(0.3 * a), 1.0)


# An antenna or a beacon pointing up from a roof: it leans out as you pass.
func _beam(o: Array) -> void:
	var z0: float = o[3]
	var z1: float = o[4]
	if eye.z - z1 < NEAR:
		return
	var a := fade(eye.z - z0)
	if a < 0.02:
		return
	var p0 := _p2(Vector3(o[1], o[2], z0))
	var p1 := _p2(Vector3(o[1], o[2], z1))
	if not SCREEN.has_point(p0) and not SCREEN.has_point(p1):
		return
	draw_line(p0, p1, Pal.ink(0.5 * a), 1.0)
	var blink := 0.5 + 0.5 * sin(t * 4.0 + float(o[1]) * 0.01)
	draw_circle(p1, 2.5, Pal.ink(0.9 * a * blink, 1.8))


# Motes in the air between here and the floor below, drawn as streaks along
# the way you are going: the faster, the longer.
func _dust() -> void:
	if leg == 7 or leg == 8:
		# under the sea the motes are bubbles, rising past
		for p in dust:
			var q := proj(p)
			if q.z <= 0.0:
				continue
			var a := Vector2(q.x, q.y)
			if DECK.has_point(a):
				continue
			draw_arc(a, clampf(4.0 * q.z, 1.5, 9.0), 0, TAU, 10, Pal.ink(clampf(0.5 * q.z, 0.1, 0.6), 1.2), 1.0)
		return
	var pts := PackedVector2Array()
	for p in dust:
		var q := proj(p)
		if q.z <= 0.0:
			continue
		var q2 := proj(p + vel * 0.045)
		if q2.z <= 0.0:
			continue
		var a := Vector2(q.x, q.y)
		var b := Vector2(q2.x, q2.y)
		if DECK.has_point(a) and DECK.has_point(b):
			continue
		pts.append(a)
		pts.append(b)
	if pts.size() > 0:
		draw_multiline(pts, Pal.ink(0.22, 1.0), 1.0)


# A ring of the shaft round the way (a pressure ring, a lift's guide ring):
# a thick band with its inside edge lit, studs round it, its depth called.
func _tube(o: Array) -> void:
	var z: float = o[4]
	var d := eye.z - z
	if d < NEAR:
		return
	var a := fade(d)
	if a < 0.02:
		return
	var c := proj(Vector3(o[1], o[2], z))
	var s := c.z
	var r: float = float(o[3]) * s
	var th: float = float(o[5]) * s
	var p := Vector2(c.x, c.y)
	if r + th < 300.0 or r > 2400.0:
		return
	if o.size() > 7 and o[7]:
		# a red bulkhead: the band itself glows
		draw_arc(p, r + th * 0.5, 0, TAU, 72, Pal.red(0.22 * a), th)
		draw_arc(p, r, 0, TAU, 72, Pal.red(a, 2.2), 4.0)
		draw_arc(p, r + th, 0, TAU, 72, Pal.red(0.7 * a, 1.6), 2.0)
		return
	draw_arc(p, r + th * 0.5, 0, TAU, 72, _fill(a, 1.3), th)
	draw_arc(p, r, 0, TAU, 72, Pal.ink(0.8 * a, 1.35), 2.0)
	draw_arc(p, r + th, 0, TAU, 72, Pal.ink(0.25 * a), 1.0)
	for k in 16:
		var v := Vector2.from_angle(TAU * k / 16.0)
		draw_line(p + v * r, p + v * (r + th), Pal.ink(0.3 * a), 1.0)
		if k % 4 == 0:
			draw_circle(p + v * (r + th * 0.5), maxf(2.0, 4.0 * s), Pal.ink(0.8 * a, 1.6))
	var label: String = o[6]
	if label != "":
		var fs := int(34.0 * s)
		if fs >= 10 and fs < 160:
			var lp := p + Vector2(-r - th + 6.0 * s, -10.0 * s)
			if lp.x >= 130.0 and lp.y >= 300.0 and lp.y <= 960.0:
				draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, mini(fs, 34), Pal.ink(0.75 * a, 1.3))


# A train on the line beside you: a string of lit cars running its own way
# (x at t: start + speed * t), so the city's scale has something to go by.
# [TRAIN, y, z, speed, cars, start]
func _train(o: Array) -> void:
	var y: float = o[1]
	var z: float = o[2]
	var d := eye.z - z
	if d < NEAR:
		return
	var a := fade(d)
	if a < 0.03:
		return
	var sc := F / d
	var x0: float = float(o[5]) + float(o[3]) * t
	var cars: int = o[4]
	for k in cars:
		var cx := x0 + k * 190.0
		var px := C.x + (cx - eye.x) * sc
		if px < -300.0 or px > 2220.0:
			continue
		var py := C.y + (y - eye.y) * sc
		var r := Rect2(px, py - 26.0 * sc, 170.0 * sc, 52.0 * sc)
		draw_rect(r, _fill(a, 1.4))
		draw_rect(r, Pal.ink(0.75 * a, 1.5), false, 1.5)
		var n := 6
		for w in n:
			draw_rect(Rect2(r.position.x + (w + 0.3) * r.size.x / n, r.position.y + r.size.y * 0.3, r.size.x / n * 0.4, r.size.y * 0.4), Pal.ink(0.7 * a, 1.6))
	var tail := x0 + (cars - 1) * 190.0 + 170.0
	draw_circle(Vector2(C.x + (tail - eye.x) * sc, C.y + (y - eye.y) * sc), maxf(2.0, 6.0 * sc), Pal.red(0.9 * a, 2.2))
	# its headlight down the line
	var hx := C.x + (x0 - eye.x) * sc
	draw_line(Vector2(hx, C.y + (y - eye.y) * sc), Vector2(hx - 260.0 * sc * signf(float(o[3])), C.y + (y - eye.y) * sc), Pal.ink(0.35 * a, 1.8), 6.0 * sc)


# A cage on the shaft's wall going its own way up or down: [CAR, x, y, w, speed, z0]
func _car(o: Array) -> void:
	var z: float = float(o[5]) + float(o[4]) * t
	var d := eye.z - z
	if d < NEAR or d > D0 + 2600.0:
		return
	var a := fade(d)
	var sc := F / d
	var p := Vector2(C.x + (float(o[1]) - eye.x) * sc, C.y + (float(o[2]) - eye.y) * sc)
	var w: float = float(o[3]) * sc
	var r := Rect2(p - Vector2(w, w * 0.7) / 2.0, Vector2(w, w * 0.7))
	draw_rect(r, _fill(a, 1.5))
	draw_rect(r, Pal.ink(0.8 * a, 1.6), false, 2.0)
	draw_circle(r.get_center(), maxf(2.0, 5.0 * sc), Pal.ink(0.9 * a, 2.0))


# Each leg's hero (the one thing you will remember it by), the near
# fly-bys at the beats, and things moving at their own pace to give scale.
func _heroes(st: int) -> void:
	var lateral := not [1, 7, 8, 9, 11].has(st)   # (11 flies level too, but over the clouds: no gates, no trains)
	var length := 24000.0
	if lateral:
		# at each beat a gate goes by under the deck: two columns, a beam across
		for b in BEATS:
			var x: float = ease_way(b) * length + 400.0
			for side in [-1.0, 1.0]:
				objs.append([BOX, x, side * 470.0 - 90.0, x + 180.0, side * 470.0 + 90.0, -D0 - 4400.0, -D0 - 70.0, 0, 2])
			objs.append([BOX, x, -620.0, x + 180.0, 620.0, -D0 - 260.0, -D0 - 120.0, 0, 1])
		# trains on the lines alongside, both ways
		for k in 3:
			var y: float = [-640.0, 640.0, -900.0][k]
			objs.append([TRAIN, y, -D0 - 520.0, [-2600.0, 1800.0, -3400.0][k], 9, rng.randf_range(2000, 16000)])
	var at := [0.18, 0.5, 0.82]
	match st:
		1:
			# the hatch at street level, lit and striped red
			var g := 12 * 300.0
			objs.append([LINE, PackedVector3Array([Vector3(-900, -640, g + 2.0), Vector3(900, -640, g + 2.0)]), 2.0, 4.0, true])
			objs.append([LINE, PackedVector3Array([Vector3(-900, 640, g + 2.0), Vector3(900, 640, g + 2.0)]), 2.0, 4.0, true])
			for k in 6:
				objs.append([CAR, [-560.0, 560.0][k % 2], [-300.0, 200.0, 0.0][k % 3], 90.0, [-260.0, 220.0][k % 2], k * 600.0])
		2, 6:
			# a tower whose whole roof is a screen: 100%
			for b in at:
				var x: float = ease_way(b) * length - 600.0
				objs.append([BOX, x, -1500.0, x + 3800.0, 1700.0, -D0 - 4400.0, -D0 - 170.0, 3, 2])
				var tx := x + 120.0
				while tx < x + 3500.0:
					objs.append([TEXT, tx, 340.0, -D0 - 170.0, "100%", 270, true])
					tx += 820.0
		3:
			# the stacks, taller than anything, their crowns alight
			for b in at:
				var x: float = ease_way(b) * length + 500.0
				objs.append([CYL, x, 250.0, 300.0, -D0 - 2600.0, -D0 - 120.0, 4, true])
				objs.append([CYL, x + 900.0, 560.0, 240.0, -D0 - 2600.0, -D0 - 260.0, 4, true])
		4:
			# the strategic reserve: a silo the size of a district, named on its roof
			for b in at:
				var x: float = ease_way(b) * length + 900.0
				objs.append([CYL, x, 420.0, 1000.0, -D0 - 2800.0, -D0 - 320.0, 3, true])
				objs.append([TEXT, x - 420.0, 480.0, -D0 - 320.0, Txt.t("crate_reserve"), 150])
		5:
			# the fusion domes, their rings breathing
			for b in at:
				var x: float = ease_way(b) * length + 1000.0
				objs.append([CYL, x, 420.0, 1000.0, -D0 - 2600.0, -D0 - 520.0, 4, true])
		7:
			# the archive's vault on the sea floor, coming up to meet you
			objs.append([CYL, 0.0, -400.0, 1500.0, -5200.0 - 400.0, -5200.0 + 900.0, 3, true])
			for k in 3:
				objs.append([TUBE, 0.0, 0.0, 760.0, -(BEATS[k] * 4800.0) - 200.0, 150.0, ""])
		8:
			# the lift's anchor: a foundation ring on the sea floor, the cable lit to the surface
			objs.append([CYL, 0.0, 0.0, 1300.0, -400.0, 300.0, 3, true])
			for v in [Vector2(-680, 0), Vector2(680, 0), Vector2(0, -680), Vector2(0, 680)]:
				objs.append([LINE, PackedVector3Array([Vector3(v.x, v.y, 300.0), Vector3(v.x, v.y, 9000.0)]), 1.8, 4.0, true])
			for k in 3:
				objs.append([TUBE, 0.0, 0.0, 760.0, 1700.0 + BEATS[k] * 5200.0, 160.0, "", true])
		9:
			# the capital below, its tower a needle of red light up toward you
			objs.append([CYL, 0.0, 0.0, 420.0, -60.0, 0.0, 4, true])
			# the capital's defence beams, four pillars of red light up past you
			for k in 4:
				var v := Vector2.from_angle(TAU * k / 4.0 + 0.6) * 1500.0
				objs.append([LINE, PackedVector3Array([Vector3(v.x, v.y, 0.0), Vector3(v.x, v.y, 14000.0)]), 2.0, 5.0, true])
			for k in 3:
				objs.append([TUBE, 0.0, 0.0, 760.0, 4800.0 + BEATS[k] * 9600.0, 140.0, ""])
		10:
			# a warship on its slip, the length of a city, going by underneath
			for b in [0.24, 0.56, 0.88]:
				var x: float = ease_way(b) * length - 1500.0
				objs.append([BOX, x, -300.0, x + 2000.0, 1250.0, -D0 - 1600.0, -D0 - 200.0, 4, 2])


# (rides only: the rooms' and the title's views have no deck)
func visible_rect_hits_deck(r: Rect2) -> bool:
	return leg != 0 and DECK.grow(30.0).intersects(r)
