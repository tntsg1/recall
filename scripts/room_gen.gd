class_name RoomGen
extends RefCounted
# Dead Cells-style rooms: each wave of a chapter is fought in a room of its
# own, laid out fresh every run from that chapter's hand-made pieces (the
# yard's crates and pallets...) and room shapes, then checked so it plays:
# every floor reachable, spawn gates and doors kept clear, an open floor to
# move in, no slivers for a round to jam in, and as much cover as the
# hand-made room had, give or take a quarter. The boss keeps its own room.

const ROOM := Arena.ROOM
const CELL := 20.0
const GAP := 90.0          # between pieces, and to the walls: never a sliver
const CLEAR := 200.0       # no cover this close to a spawn gate or a door
const DOOR_W := 150.0
const GATE_W := 110.0
const BODY := 16.0         # the player's radius, for what can be reached
const OPEN := Vector2(500, 300)
const NORMAL := {"T": Vector2(0, 1), "B": Vector2(0, -1), "L": Vector2(1, 0), "R": Vector2(-1, 0)}
const OPPOSITE := {"T": "B", "B": "T", "L": "R", "R": "L"}
const HUD_STRIP := Rect2(80, 70, 680, 110)   # the city broadcast's strip, top left
const BANNER := Rect2(640, 320, 640, 170)    # where a wave's title and its note show
const HUD_FOOT := Rect2(640, 940, 600, 70)    # the cracks and the magazine count, bottom middle
const HUD_LORE := Rect2(80, 860, 300, 150)    # where "archive +1" shows, bottom left
const EXIT_APART := 480.0                     # two ways on: this far apart, their labels and light their own
const FROM_ENTRY := 700.0                     # a way on this far from the way in: the room is crossed

# The chapters that walk room to room; the rest keep their one hand-made room.
const ON := [1, 2]
const POST := 48.0

# Per chapter: room shapes (weights), its pieces of cover (weight, rects,
# kind), the landmarks one of which every room is built round, the hand-made
# room's cover (rect count, area) the rooms are held to, and how much floor
# each remnant's prop needs along its wall and in front of it.
const STYLE := {
	1: {
		"shapes": {"hall": 3, "corner": 3, "twin": 2, "neck": 1, "bays": 3},
		"pieces": [
			[3, [Rect2(0, 0, 88, 88)], "crate"],
			[2, [Rect2(0, 0, 88, 88), Rect2(0, 88, 88, 88)], "crate"],          # two, stacked
			[2, [Rect2(0, 0, 88, 88), Rect2(88, 44, 88, 88)], "crate"],         # two, staggered
			[3, [Rect2(0, 0, 190, 50)], "pallet"],                              # a pallet row
			[2, [Rect2(0, 0, 88, 88), Rect2(88, 38, 150, 50)], "crate_pallet"], # a crate on its pallet
			[2, [Rect2(0, 0, 64, 64)], "small"],
			[2, [Rect2(0, 0, 60, 40)], "buffer"],                               # a track's buffer stop
			[2, [Rect2(0, 0, 96, 96)], "drums"],                                # four oil drums, strapped
			[2, [Rect2(0, 0, 160, 96)], "tarp"],                                # a load under a tarp
			[2, [Rect2(0, 0, 88, 88), Rect2(88, 0, 88, 88)], "open"],           # a crate, and one forced open
			[1, [Rect2(0, 0, 260, 72)], "container"],
		],
		# each room's freight leans one way: these kinds weigh four times over
		"themes": [["drums", "tarp"], ["container", "pallet"], ["open", "small"], ["tarp", "crate_pallet"], ["drums", "buffer"], ["crate", "open"]],
		# the yard's big things: a container, a gantry's two legs, a row of crates
		"landmarks": [
			[3, [Rect2(0, 0, 260, 72)], "container"],
			[3, [Rect2(0, 0, 56, 56), Rect2(320, 0, 56, 56)], "gantry"],
			[2, [Rect2(0, 0, 88, 88), Rect2(88, 0, 88, 88), Rect2(176, 0, 88, 88)], "row"],
		],
		"count": 6, "area": 50000.0,
		"props": {"door": [300.0, 140.0], "screen": [260.0, 190.0], "graffiti": [220.0, 130.0], "notice": [180.0, 130.0]},
		# the sealed lab you wake in is the first room's way in; the first
		# room also holds the graffiti, so its far side has words on it
		"entry_prop": "door",
		"first_room": ["door", "graffiti"],
	},
	2: {
		# the Hall of Mirrors: a shareholders' registry. Registration pillars,
		# benches for the queue, kiosks; the chapter's mirror panels laid with
		# them, more of them room by room.
		"shapes": {"hall": 3, "corner": 2, "twin": 2, "neck": 1, "columns": 3},
		"pieces": [
			[3, [Rect2(0, 0, 80, 80)], "pillar"],
			[3, [Rect2(0, 0, 200, 44)], "bench"],
			[2, [Rect2(0, 0, 90, 64)], "kiosk"],
			[1, [Rect2(0, 0, 200, 44), Rect2(0, 44, 200, 44)], "bench"],     # two benches back to back
		],
		"landmarks": [
			[3, [Rect2(0, 0, 300, 64)], "desk"],                                # the registry desk
			[3, [Rect2(0, 0, 80, 80), Rect2(300, 0, 80, 80)], "pillar"],        # a pair of registration pillars
			[2, [Rect2(0, 0, 90, 40), Rect2(90, 0, 90, 40), Rect2(180, 0, 90, 40)], "turnstile"],
		],
		# the chapter's own: mirror panels, one in the first room, four by the last
		"mech": {"pieces": [[1, [Rect2(0, 0, 28, 200)], "mirror"], [1, [Rect2(0, 0, 220, 28)], "mirror"]], "count": [1, 2, 3, 3, 4, 4]},
		# the hand-made hall: two pillars and four mirrors
		"count": 6, "area": 36000.0,
		"themes": [["bench"], ["kiosk"], ["pillar"], ["bench", "kiosk"]],
		"props": {"terminal": [200.0, 170.0], "gate": [420.0, 160.0], "queue": [600.0, 140.0], "retire": [160.0, 150.0]},
	},
	3: {
		# the weapons range: arms crates, sandbag walls, target stands; the
		# chapter's own is its laser fences, strung between posts across open
		# floor, one fence in the first room, three by the last
		"shapes": {"hall": 3, "bays": 3, "twin": 2, "corner": 2, "neck": 1},
		"pieces": [
			[3, [Rect2(0, 0, 110, 64)], "arms"],
			[2, [Rect2(0, 0, 110, 64), Rect2(0, 64, 110, 64)], "arms"],          # two, stacked
			[3, [Rect2(0, 0, 170, 36)], "sandbag"],
			[2, [Rect2(0, 0, 64, 30)], "stand"],                                # a target stand
		],
		"landmarks": [
			[3, [Rect2(0, 0, 260, 50)], "firing"],                               # a firing bench
			[2, [Rect2(0, 0, 180, 90)], "bunker"],                               # a concrete blind
			[2, [Rect2(0, 0, 220, 56)], "rack"],                                 # a weapons rack
		],
		"fences": [1, 1, 2, 2, 3, 3],
		# the hand-made range: four posts, four crate stacks
		"count": 8, "area": 37400.0,
		"themes": [["arms"], ["sandbag"], ["stand", "arms"]],
		"props": {"log": [220.0, 180.0], "target": [200.0, 130.0], "crate": [0.0, 0.0], "safety": [170.0, 130.0]},
		# a remnant read off a piece of cover, not a wall: the crate's stencil
		"on_cover": {"crate": "arms"},
	},
}


static var last_why := ""        # tests: where the last try gave up
static var force_off := false     # tests: the hand-made rooms, to compare against


static func on(story: int) -> bool:
	return ON.has(story) and not force_off


# A room for wave `index`: entered through `entry`, left by one door per entry
# of `exits` ({risky, boss}), holding the remnants named. Same arguments, same
# room. Returns {} only if no attempt passed (never seen; the test counts).
static func make(story: int, index: int, cseed: int, entry: String, exits: Array, remnants: Array) -> Dictionary:
	var st: Dictionary = STYLE[story]
	var rng := RandomNumberGenerator.new()
	for attempt in 150:
		rng.seed = hash([cseed, story, index, entry, exits.size(), attempt])
		var lay := _try(st, story, index, cseed, entry, exits, remnants, rng, attempt >= 100)
		if lay.is_empty():
			continue
		lay["attempt"] = attempt
		if check(lay).ok:
			return lay
	return {}


# `spare`: late tries may leave out a remnant there is no wall for (Rooms
# carries it on to the next room)
static func _try(st: Dictionary, story: int, index: int, cseed: int, entry: String, exits: Array, remnants: Array, rng: RandomNumberGenerator, spare := false) -> Dictionary:
	var sparse := index == 0 and story == 1
	var shape := "hall" if sparse else _weighted(st.shapes, rng)
	var walls := _shape(shape, rng)
	var themes: Array = st.get("themes", [[]])
	var theme: Array = themes[(absi(cseed) + index) % themes.size()]
	var lay := {"story": story, "index": index, "shape": shape, "walls": walls, "cover": [] as Array[Rect2], "piece": [], "kinds": [], "gates": [], "exits": [], "spots": {}, "sparse": sparse, "theme": theme}
	# the way in
	var e := _door_on(entry, walls, [], rng, DOOR_W)
	if e.is_empty():
		last_why = "t1"
		return {}
	if index == 0 and st.has("entry_prop"):
		e["w"] = float(st.props[st.entry_prop][0])
	lay["entry"] = e
	var taken: Array = [e]
	# the ways on, on other walls than the way in
	var sides: Array = ["T", "B", "L", "R"]
	sides.erase(entry)
	_shuffle(sides, rng)
	# a single way on prefers the far wall: the room is crossed, not doubled back
	if exits.size() == 1 and rng.randf() < 0.6:
		sides.erase(OPPOSITE[entry])
		sides.push_front(OPPOSITE[entry])
	for spec: Dictionary in exits:
		# the first wall in turn with a place for it: far from the way in, apart from the other way on
		var d := {}
		while d.is_empty() and not sides.is_empty():
			var side: String = sides.pop_front()
			for k in 8:
				var c := _door_on(side, walls, taken, rng, DOOR_W)
				if c.is_empty():
					break
				c["label"] = label_rect(c)
				var ok := (c.pos as Vector2).distance_to(e.pos) >= FROM_ENTRY
				for wr: Rect2 in walls:
					if wr.grow(12.0).intersects(c.label):
						ok = false
				for o: Dictionary in lay.exits:
					if (o.pos as Vector2).distance_to(c.pos) < EXIT_APART or (o.label as Rect2).grow(30.0).intersects(c.label):
						ok = false
				if ok:
					d = c
					break
		if d.is_empty():
			last_why = "t2"
			return {}
		d["risky"] = spec.get("risky", false)
		d["boss"] = spec.get("boss", false)
		lay.exits.append(d)
		taken.append(d)
	# spawn gates: one on each wall that has room for one, two on the long walls
	for s in ["T", "B", "L", "R"]:
		for k in (2 if s == "T" or s == "B" else 1):
			var g := _door_on(s, walls, taken, rng, GATE_W)
			if not g.is_empty():
				lay.gates.append(g)
				taken.append(g)
	if lay.gates.size() < 3:
		last_why = "t3"
		return {}
	lay["start"] = (e.pos as Vector2) + (e.n as Vector2) * 110.0
	# cover, piece by piece
	var lo_n := 3 if sparse else int(ceil(st.count * 0.75))
	var hi_n := 5 if sparse else int(floor(st.count * 1.25))
	var lo_a: float = st.area * (0.4 if sparse else 0.75)
	var hi_a: float = st.area * (0.9 if sparse else 1.25)
	var want_n := rng.randi_range(lo_n, hi_n)
	var area := 0.0
	var pid := 0
	# the room is built round one landmark (the first room keeps to small things)
	var mark: Array = _weighted_piece(st.landmarks, rng)
	if st.has("fences"):
		# the landmark first, then the fences round it
		var rs0 := _turn(mark[1], rng)
		var bb0 := _bounds(rs0)
		var placed0 := false
		for k in 80:
			var at0 := Vector2(rng.randf_range(ROOM.position.x + GAP, ROOM.end.x - GAP - bb0.size.x), rng.randf_range(ROOM.position.y + GAP, ROOM.end.y - GAP - bb0.size.y))
			var pl0: Array[Rect2] = []
			for r: Rect2 in rs0:
				pl0.append(Rect2(r.position + at0 - bb0.position, r.size))
			if _fits(pl0, lay, taken):
				for r in pl0:
					lay.cover.append(r)
					lay.piece.append(pid)
					lay.kinds.append(mark[2])
					area += r.get_area()
				pid += 1
				placed0 = true
				break
		if not placed0:
			last_why = "landmark"
			return {}
	while sparse and (mark[1] as Array).size() != 1:
		mark = _weighted_piece(st.landmarks, rng)   # the first room: the container, to leave it room for more pieces
	lay["fences"] = []
	if st.has("fences"):
		var want_f: int = (st.fences as Array)[mini(index, (st.fences as Array).size() - 1)]
		if not _fence_up(lay, taken, rng, want_f, pid):
			last_why = "fences"
			return {}
		pid += want_f
	var mech: Dictionary = st.get("mech", {})
	var mech_left: int = (mech.count as Array)[mini(index, (mech.count as Array).size() - 1)] if not mech.is_empty() else 0
	for tries in 500:
		# at least three pieces: a room is never its landmark alone
		if lay.cover.size() >= want_n and area >= lo_a and pid >= (4 if sparse else 3) and mech_left == 0:
			break
		var is_mech := pid > 0 and mech_left > 0
		var piece: Array = mark if pid == 0 else (_weighted_piece(mech.pieces, rng) if is_mech else _weighted_piece(st.pieces, rng, lay.theme))
		if tries > 120 and pid == 0:
			last_why = "t4"
			return {}
		if tries > 300 and mech_left > 0:
			last_why = "t5"
			return {}
		if lay.cover.size() + (piece[1] as Array).size() > hi_n:
			continue
		var rs := _turn(piece[1], rng)
		var bb := _bounds(rs)
		var at := Vector2(rng.randf_range(ROOM.position.x + GAP, ROOM.end.x - GAP - bb.size.x), rng.randf_range(ROOM.position.y + GAP, ROOM.end.y - GAP - bb.size.y))
		var placed: Array[Rect2] = []
		var pa := 0.0
		for r: Rect2 in rs:
			placed.append(Rect2(r.position + at - bb.position, r.size))
			pa += r.get_area()
		if area + pa > hi_a or not _fits(placed, lay, taken):
			continue
		for r in placed:
			lay.cover.append(r)
			lay.piece.append(pid)
			lay.kinds.append(piece[2])
		pid += 1
		area += pa
		if is_mech:
			mech_left -= 1
	# the remnants this room holds, each on a wall facing the way its words read
	var all_w: Array = Lore.walls(story)
	for id: String in remnants:
		var w: Array = []
		for ww in all_w:
			if ww[0] == id:
				w = ww
		if w.is_empty():
			continue
		var need: Array = st.props.get(id, [220.0, 140.0])
		var spot: Array = []
		var on_kind: String = st.get("on_cover", {}).get(id, "")
		if on_kind != "":
			# on the lid of a piece of that kind, read from above
			for ci in (lay.cover as Array).size():
				if lay.kinds[ci] == on_kind:
					var cr: Rect2 = lay.cover[ci]
					spot = [Vector2(cr.get_center().x, cr.position.y), Vector2(0, -1)]
					break
		elif id == st.get("entry_prop", "") and index == 0:
			if NORMAL[entry] == w[2]:
				spot = [e.pos, e.n]
		else:
			spot = _spot_for(w[2], need, lay, taken, rng)
		if spot.is_empty() and spare:
			continue
		if spot.is_empty():
			last_why = "t6"
			return {}
		lay.spots[id] = spot
		taken.append({"pos": spot[0], "n": spot[1], "w": need[0]})
	# both halves of the room have something in them (the first room: a fair piece each)
	var halves := [0.0, 0.0]
	for r: Rect2 in lay.cover:
		halves[0 if r.get_center().x < 960.0 else 1] += r.get_area()
	var least: float = 6000.0 if sparse else 0.18 * (halves[0] + halves[1])
	if halves[0] < least or halves[1] < least:
		last_why = "t7"
		return {}
	if story == 2:
		_paint_hall(lay, taken, rng)
	elif story == 3:
		_paint_range(lay, taken, rng)
	else:
		_paint(lay, taken, rng)
	return lay


# The range's floor: numbered firing lanes out from one wall, distance marks
# down them, scorch where things burned, holes round what was shot at.
static func _paint_range(lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> void:
	lay["quiet"] = _quiet(lay)
	var solid: Array = lay.walls + lay.cover
	lay["lanes3"] = []
	for tries in 16:
		var side: String = ["T", "L", "R"][rng.randi() % 3]
		if side == lay.entry.side:
			continue
		var horiz := side == "T"
		var n := rng.randi_range(3, 5)
		var lw := rng.randf_range(150.0, 200.0)
		var deep := rng.randf_range(260.0, 360.0)
		var u0 := rng.randf_range((ROOM.position.x if horiz else ROOM.position.y) + 120.0, (ROOM.end.x if horiz else ROOM.end.y) - 120.0 - lw * n)
		var base: float = {"T": ROOM.position.y, "L": ROOM.position.x, "R": ROOM.end.x - deep}[side]
		var all := Rect2(u0, base, lw * n, deep) if horiz else Rect2(base, u0, deep, lw * n)
		var ok := not all.intersects(HUD_STRIP) and not all.intersects(BANNER)
		for d: Dictionary in taken:
			if all.grow(40.0).has_point(d.pos):
				ok = false
		for r: Rect2 in lay.walls:
			if r.intersects(all):
				ok = false
		if ok:
			lay.lanes3 = [side, all, n]
			break
	var scorch: Array = []
	for k in rng.randi_range(3, 5):
		scorch.append([Vector2(rng.randf_range(ROOM.position.x + 100.0, ROOM.end.x - 100.0), rng.randf_range(ROOM.position.y + 100.0, ROOM.end.y - 100.0)), rng.randf_range(20.0, 36.0)])
	lay["scorch"] = scorch
	# holes cluster round what stood to be shot at
	var holes: Array = []
	for ci in (lay.cover as Array).size():
		if rng.randf() < 0.5:
			holes.append([(lay.cover[ci] as Rect2).get_center(), 50.0 + (lay.cover[ci] as Rect2).size.length() * 0.3, rng.randi_range(5, 10)])
	lay["holes"] = holes


# The registry hall's floor: tile seams, queue lanes (pairs of lines with
# their posts) across it, the Union's seal and the hall's number on it.
static func _paint_hall(lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> void:
	lay["quiet"] = _quiet(lay)
	lay["tile"] = rng.randf_range(110.0, 150.0)
	var lanes: Array = []
	for n in rng.randi_range(1, 2):
		var horiz := rng.randf() < 0.7
		var c := rng.randf_range(ROOM.position.y + 160.0, ROOM.end.y - 160.0) if horiz else rng.randf_range(ROOM.position.x + 200.0, ROOM.end.x - 200.0)
		lanes.append([horiz, c])
	lay["lanes"] = lanes
	var solid: Array = lay.walls + lay.cover
	# the seal keeps off the lanes and the waiting area's rope: one thing to a patch of floor
	var keep_off: Array = []
	for ln: Array in lanes:
		keep_off.append(Rect2(ROOM.position.x, ln[1] - 100.0, ROOM.size.x, 200.0) if ln[0] else Rect2(ln[1] - 100.0, ROOM.position.y, 200.0, ROOM.size.y))
	if lay.spots.has("queue"):
		var q: Vector2 = lay.spots.queue[0]
		keep_off.append(Rect2(q - Vector2(320, 180), Vector2(640, 200)))
	lay["stencil"] = []
	for tries in 40:
		var at := Vector2(rng.randf_range(ROOM.position.x + 200.0, ROOM.end.x - 200.0), rng.randf_range(ROOM.position.y + 200.0, ROOM.end.y - 280.0))
		var box := Rect2(at - Vector2(160, 160), Vector2(320, 380))
		var ok := ROOM.encloses(box) and not box.intersects(BANNER)
		for r: Rect2 in solid + lay.quiet + keep_off:
			if r.intersects(box):
				ok = false
		for d: Dictionary in taken:
			if box.grow(60.0).has_point(d.pos):
				ok = false
		if ok:
			lay.stencil = [at, "REG-%02d" % (lay.index + 1)]
			break


# The yard's floor, painted: a track or two of rails across it, a row of
# parking bays along a wall, oil stains, the bay's stencilled number. Paint
# only: where cover or a wall block stands, it is not drawn (see LoreProps).
# Where words are shown, which the floor's tracks leave bare: the titles, the
# way in (the first words are spoken there), the doors' labels, the broadcast.
static func _quiet(lay: Dictionary) -> Array:
	var out: Array = [BANNER.grow(40.0), Rect2(lay.start - Vector2(300, 300), Vector2(600, 600)), HUD_STRIP.grow(60.0), HUD_LORE]
	for d: Dictionary in lay.exits:
		out.append((d.label as Rect2).grow(60.0))
	return out


static func _paint(lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> void:
	var solid: Array = lay.walls + lay.cover
	# rails: the line that crosses the least cover
	var rails: Array = []
	var roll := rng.randf()
	for n in (0 if roll < 0.2 else (1 if roll < 0.65 else 2)):
		var best: Array = []
		var bc := INF
		for tries in 10:
			var horiz := rng.randf() < 0.6
			var c := rng.randf_range(ROOM.position.y + 120.0, ROOM.end.y - 120.0) if horiz else rng.randf_range(ROOM.position.x + 160.0, ROOM.end.x - 160.0)
			var band := Rect2(ROOM.position.x, c - 24.0, ROOM.size.x, 48.0) if horiz else Rect2(c - 24.0, ROOM.position.y, 48.0, ROOM.size.y)
			var cost := 0.0
			for r: Rect2 in solid:
				if r.intersects(band):
					cost += r.intersection(band).get_area()
			for o: Array in rails:
				if o[0] == horiz and absf(o[1] - c) < 200.0:
					cost += 1e6
			# where words stand it is cut: the less of it lost there the better
			for z: Rect2 in _quiet(lay):
				if z.intersects(band):
					cost += z.intersection(band).get_area() * 0.5
			if cost < bc:
				bc = cost
				best = [horiz, c]
		rails.append(best)
	lay["rails"] = rails
	# (a track stops short of the doors and gates it meets, and of the quiet
	# places: LoreProps cuts it at every one)
	lay["quiet"] = _quiet(lay)
	var keep_off: Array = []          # what the bays and the number keep clear of
	for rl: Array in rails:
		keep_off.append(Rect2(ROOM.position.x, rl[1] - 40.0, ROOM.size.x, 80.0) if rl[0] else Rect2(rl[1] - 40.0, ROOM.position.y, 80.0, ROOM.size.y))
	for d: Dictionary in lay.exits:
		keep_off.append(d.label)
	# parking bays along one wall (not the bottom, under the HUD), where the floor in front is clear
	var bays: Array = []
	for tries in 12:
		var side: String = ["T", "L", "R"][rng.randi() % 3]
		if side == lay.entry.side:
			continue      # the way in has the room's opening there (and the first room its worker)
		var n: Vector2 = NORMAL[side]
		var horiz := n.y != 0.0
		var count := rng.randi_range(3, 5)
		var bw := 96.0
		var deep := 150.0
		var span := bw * count
		var u0 := rng.randf_range((ROOM.position.x if horiz else ROOM.position.y) + 60.0, (ROOM.end.x if horiz else ROOM.end.y) - 60.0 - span)
		var base: float = {"T": ROOM.position.y, "B": ROOM.end.y - deep, "L": ROOM.position.x, "R": ROOM.end.x - deep}[side]
		var all := Rect2(u0, base, span, deep) if horiz else Rect2(base, u0, deep, span)
		var ok := not all.intersects(HUD_STRIP)
		for r: Rect2 in solid + keep_off:
			if r.grow(10.0).intersects(all):
				ok = false
		for d: Dictionary in taken:
			if all.grow(60.0).has_point(d.pos):
				ok = false
		if not ok:
			continue
		for k in count:
			bays.append(Rect2(u0 + bw * k, base, bw, deep) if horiz else Rect2(base, u0 + bw * k, deep, bw))
		break
	lay["bays"] = bays
	# stains, and the bay's number on open floor
	var stains: Array = []
	for k in rng.randi_range(2, 4):
		stains.append([Vector2(rng.randf_range(ROOM.position.x + 80.0, ROOM.end.x - 80.0), rng.randf_range(ROOM.position.y + 80.0, ROOM.end.y - 80.0)), rng.randf_range(18.0, 46.0), rng.randf() * TAU])
	lay["stains"] = stains
	lay["stencil"] = []
	for tries in 20:
		var at := Vector2(rng.randf_range(ROOM.position.x + 120.0, ROOM.end.x - 360.0), rng.randf_range(ROOM.position.y + 200.0, ROOM.end.y - 60.0))
		var box := Rect2(at - Vector2(0, 140), Vector2(300, 180))
		var ok := not box.intersects(BANNER)
		for r: Rect2 in solid + bays + keep_off:
			if r.intersects(box):
				ok = false
		for d: Dictionary in taken:
			if box.grow(80.0).has_point(d.pos):
				ok = false
		if ok:
			lay.stencil = [at, "%02d" % (13 + lay.index)]
			break


# ---------------------------------------------------------------- shapes

static func _shape(shape: String, rng: RandomNumberGenerator) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var x0 := ROOM.position.x
	var y0 := ROOM.position.y
	var x1 := ROOM.end.x
	var y1 := ROOM.end.y
	match shape:
		"corner":
			# a corner walled off: the room turns an L
			var w := rng.randf_range(340.0, 700.0)
			var h := rng.randf_range(220.0, 400.0)
			var k := rng.randi() % 4
			var x := x0 if k % 2 == 0 else x1 - w
			var y := y0 if k < 2 else y1 - h
			out.append(Rect2(x, y, w, h))
			# stepped: a lower shoulder runs on along one of its two walls
			if rng.randf() < 0.5:
				var w2 := rng.randf_range(140.0, 320.0)
				var h2 := h * rng.randf_range(0.3, 0.65)
				out.append(Rect2(x + w if k % 2 == 0 else x - w2, y if k < 2 else y1 - h2, w2, h2))
			else:
				var h2 := rng.randf_range(120.0, 240.0)
				var w2 := w * rng.randf_range(0.3, 0.65)
				out.append(Rect2(x if k % 2 == 0 else x1 - w2, y + h if k < 2 else y - h2, w2, h2))
			# and more often than not a short wall out from the far long wall
			if rng.randf() < 0.7:
				var depth := rng.randf_range(180.0, 280.0)
				var sx := rng.randf_range(x0 + 260.0, x1 - 260.0)
				out.append(Rect2(sx - 28.0, y1 - depth if k < 2 else y0, 56.0, depth))
		"twin":
			# a partition down the middle with two ways through: two halls
			var x := 960.0 + rng.randf_range(-260.0, 260.0)
			var th := 56.0
			var g1 := rng.randf_range(200.0, 240.0)
			var g2 := rng.randf_range(200.0, 240.0)
			var extra := (y1 - y0) - g1 - g2 - 380.0
			var ea := rng.randf_range(0.0, extra)
			var eb := rng.randf_range(0.0, extra - ea)
			var a := 110.0 + ea
			var m := 160.0 + eb
			var b := (y1 - y0) - a - g1 - m - g2
			out.append(Rect2(x - th / 2.0, y0, th, a))
			out.append(Rect2(x - th / 2.0, y0 + a + g1, th, m))
			out.append(Rect2(x - th / 2.0, y1 - b, th, b))
		"neck":
			# two halls joined by a narrow way through: side by side, or one
			# above the other through a gap in a wall across the room
			var gap := rng.randf_range(200.0, 260.0)
			if rng.randf() < 0.55:
				# the wall above and the wall below each their own width and place
				var cx := 960.0 + rng.randf_range(-380.0, 380.0)
				var cy := 540.0 + rng.randf_range(-150.0, 150.0)
				var w := rng.randf_range(200.0, 440.0)
				var cx2 := cx + rng.randf_range(-160.0, 160.0)
				var w2 := rng.randf_range(200.0, 440.0)
				out.append(Rect2(cx - w / 2.0, y0, w, cy - gap / 2.0 - y0))
				out.append(Rect2(cx2 - w2 / 2.0, cy + gap / 2.0, w2, y1 - cy - gap / 2.0))
			else:
				# each side of the gap its own thickness and height: a stepped wall
				var cx := 960.0 + rng.randf_range(-480.0, 480.0)
				for k in 2:
					var h := rng.randf_range(90.0, 200.0)
					var cy := rng.randf_range(370.0 + h / 2.0, 710.0 - h / 2.0)
					if k == 0:
						out.append(Rect2(x0, cy - h / 2.0, cx - gap / 2.0 - x0, h))
					else:
						out.append(Rect2(cx + gap / 2.0, cy - h / 2.0, x1 - cx - gap / 2.0, h))
				# now and then a second way through the longer side
				var li := 0 if out[0].size.x > out[1].size.x else 1
				var lr: Rect2 = out[li]
				if rng.randf() < 0.6 and lr.size.x > 760.0:
					var g2 := rng.randf_range(200.0, 240.0)
					var at := rng.randf_range(lr.position.x + 260.0, lr.end.x - 260.0 - g2)
					out[li] = Rect2(lr.position.x, lr.position.y, at - lr.position.x, lr.size.y)
					out.append(Rect2(at + g2, lr.position.y, lr.end.x - at - g2, lr.size.y))
		"columns":
			# a row of great columns down the hall, standing free
			var n := rng.randi_range(2, 4)
			var size := rng.randf_range(100.0, 150.0)
			var horiz := rng.randf() < 0.65
			var c := rng.randf_range(380.0, 700.0) if horiz else rng.randf_range(500.0, 1420.0)
			var span := (x1 - x0 - 500.0) / maxf(1.0, n - 1) if horiz else (y1 - y0 - 340.0) / maxf(1.0, n - 1)
			for k in n:
				var u := (x0 + 250.0 + span * k) if horiz else (y0 + 170.0 + span * k)
				u += rng.randf_range(-40.0, 40.0)
				out.append(Rect2(u - size / 2.0, c - size / 2.0, size, size) if horiz else Rect2(c - size / 2.0, u - size / 2.0, size, size))
		"bays":
			# loading bays: short walls out from one long wall
			var top := rng.randf() < 0.5
			var n := rng.randi_range(2, 3)
			var span := rng.randf_range(330.0, 420.0)
			var x := rng.randf_range(x0 + 300.0, x1 - 300.0 - span * (n - 1))
			for k in n:
				var depth := rng.randf_range(220.0, 300.0)
				out.append(Rect2(x + span * k - 28.0, y0 if top else y1 - depth, 56.0, depth))
	return out


# ---------------------------------------------------------------- placing

# A door or gate of width `w` on wall `side`, clear of the room's walls and of
# what is already on that wall. {} if the wall has no room for it.
static func _door_on(side: String, walls: Array, taken: Array, rng: RandomNumberGenerator, w: float) -> Dictionary:
	var horiz := side == "T" or side == "B"
	var lo := (ROOM.position.x if horiz else ROOM.position.y) + 150.0
	var hi := (ROOM.end.x if horiz else ROOM.end.y) - 150.0
	var n: Vector2 = NORMAL[side]
	for tries in 24:
		var u := rng.randf_range(lo, hi)
		var p := Vector2.ZERO
		match side:
			"T":
				p = Vector2(u, ROOM.position.y)
			"B":
				p = Vector2(u, ROOM.end.y)
			"L":
				p = Vector2(ROOM.position.x, u)
			_:
				p = Vector2(ROOM.end.x, u)
		var ok := not HUD_STRIP.grow(80.0).has_point(p) and not (side == "T" and absf(u - 960.0) < 300.0) and not (side == "B" and u > 640.0 and w >= DOOR_W) and not (side == "B" and w < DOOR_W and not ((u > 515.0 and u < 645.0) or (u > 1175.0 and u < 1325.0)))
		# the wall must be open there, a step into the room
		var t := Vector2(n.y, n.x).abs()
		for k in 5:
			var q := p + n * 30.0 + t * (w / 2.0 + 30.0) * (k / 2.0 - 1.0)
			for r: Rect2 in walls:
				if r.grow(BODY + 8.0).has_point(q):
					ok = false
		for d: Dictionary in taken:
			var dn: Vector2 = d.n
			var mixed: bool = (w < DOOR_W) != (float(d.get("w", DOOR_W)) < DOOR_W)
			var keep := w / 2.0 + float(d.get("w", DOOR_W)) / 2.0 + (300.0 if mixed else 120.0)
			if dn == n and (d.pos as Vector2).distance_to(p) < keep:
				ok = false
			elif (d.pos as Vector2).distance_to(p) < (380.0 if mixed else 260.0):
				ok = false     # round a corner, still too close
		if ok:
			return {"side": side, "pos": p, "n": n, "w": w}
	return {}


# Where a way on's label stands (Rooms draws it there): a plate past its
# chevrons, out from the door.
static func label_rect(d: Dictionary) -> Rect2:
	var n: Vector2 = d.n
	var at: Vector2 = (d.pos as Vector2) + n * (190.0 if n.x == 0.0 else 280.0)
	return Rect2(at - Vector2(150, 40), Vector2(300, 130))


static func _fits(placed: Array[Rect2], lay: Dictionary, taken: Array) -> bool:
	var inside := ROOM.grow(-GAP)
	# nothing under the wave's title (a gantry's beam spans the gap between its legs)
	if _bounds(placed).intersects(BANNER.grow(30.0)):
		return false
	for d: Dictionary in lay.exits:
		if _bounds(placed).intersects((d.label as Rect2).grow(20.0)):
			return false
	for f: Array in lay.get("fences", []):
		for r in placed:
			if _seg_hits(f[0], f[1], r.grow(34.0)):
				return false
	for r in placed:
		if not inside.encloses(r):
			return false
		for w: Rect2 in lay.walls:
			if w.grow(GAP).intersects(r):
				return false
		for c: Rect2 in lay.cover:
			if c.grow(GAP).intersects(r):
				return false
		for d: Dictionary in taken:
			if _dist(r, d.pos) < CLEAR:
				return false
		if _dist(r, lay.start) < 170.0:
			return false
	return true


# A place for a remnant's prop: on a wall (the room's or a wall block's face)
# whose face looks the way the words were written to be read, with the length
# of wall and the floor in front of it the prop needs.
static func _spot_for(n: Vector2, need: Array, lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> Array:
	var faces: Array = []    # [a, b] segments facing n
	if n == Vector2(1, 0):
		faces.append([ROOM.position, Vector2(ROOM.position.x, ROOM.end.y)])
	elif n == Vector2(-1, 0):
		faces.append([Vector2(ROOM.end.x, ROOM.position.y), ROOM.end])
	elif n == Vector2(0, 1):
		faces.append([ROOM.position, Vector2(ROOM.end.x, ROOM.position.y)])
	else:
		faces.append([Vector2(ROOM.position.x, ROOM.end.y), ROOM.end])
	for r: Rect2 in lay.walls:
		if n == Vector2(1, 0):
			faces.append([Vector2(r.end.x, r.position.y), r.end])
		elif n == Vector2(-1, 0):
			faces.append([r.position, Vector2(r.position.x, r.end.y)])
		elif n == Vector2(0, 1):
			faces.append([Vector2(r.position.x, r.end.y), r.end])
		else:
			faces.append([r.position, Vector2(r.end.x, r.position.y)])
	var half: float = need[0] / 2.0
	var deep: float = need[1]
	var tan := Vector2(absf(n.y), absf(n.x))
	for tries in 40:
		var f: Array = faces[rng.randi() % faces.size()]
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		var len := a.distance_to(b)
		if len < half * 2.0 + 40.0:
			continue
		var p := a.lerp(b, rng.randf_range((half + 20.0) / len, 1.0 - (half + 20.0) / len))
		# the floor in front of it: open, and not inside another wall block
		var front := Rect2(p - tan * half, Vector2.ZERO).expand(p + tan * half + n * deep)
		front = front.abs()
		var ok := ROOM.grow(1.0).encloses(front) and not front.intersects(HUD_STRIP) and not front.intersects(HUD_LORE)
		for d: Dictionary in lay.exits:
			if front.grow(30.0).intersects(d.label):
				ok = false
		for r: Rect2 in lay.walls + lay.cover:
			if r.intersects(front.grow(-1.0)):
				ok = false
		for d: Dictionary in taken:
			if (d.pos as Vector2).distance_to(p) < half + float(d.get("w", DOOR_W)) / 2.0 + 30.0:
				ok = false
		if ok:
			return [p, n]
	return []


# ---------------------------------------------------------------- the check

# Whether a room plays: {ok, why}.
static func check(lay: Dictionary) -> Dictionary:
	var solids: Array[Rect2] = []
	solids.append_array(lay.walls)
	solids.append_array(lay.cover)
	var nx := int(ROOM.size.x / CELL)
	var ny := int(ROOM.size.y / CELL)
	var reach := PackedByteArray()
	reach.resize(nx * ny)
	var raw := PackedInt32Array()       # summed area of cells any solid covers
	raw.resize((nx + 1) * (ny + 1))
	var body_free := PackedByteArray()
	body_free.resize(nx * ny)
	var free_n := 0
	for j in ny:
		for i in nx:
			var c := ROOM.position + Vector2(i + 0.5, j + 0.5) * CELL
			var cell := Rect2(ROOM.position + Vector2(i, j) * CELL, Vector2(CELL, CELL))
			var hit := 0
			var bf := 1
			if not ROOM.grow(-BODY).has_point(c):
				bf = 0
			for r in solids:
				if r.intersects(cell):
					hit = 1
				if r.grow(BODY).has_point(c):
					bf = 0
			body_free[j * nx + i] = bf
			free_n += bf
			raw[(j + 1) * (nx + 1) + i + 1] = hit + raw[j * (nx + 1) + i + 1] + raw[(j + 1) * (nx + 1) + i] - raw[j * (nx + 1) + i]
	# 1. every floor reachable from the way in
	var start: Vector2 = lay.start
	var si := _cell(start, nx, ny)
	if si < 0 or body_free[si] == 0:
		return {"ok": false, "why": "start blocked"}
	var q := PackedInt32Array([si])
	reach[si] = 1
	var head := 0
	var got := 1
	while head < q.size():
		var k := q[head]
		head += 1
		var i := k % nx
		var j := k / nx
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var a := i + o.x
			var b := j + o.y
			if a < 0 or b < 0 or a >= nx or b >= ny:
				continue
			var kk := b * nx + a
			if reach[kk] == 0 and body_free[kk] == 1:
				reach[kk] = 1
				got += 1
				q.append(kk)
	if got < free_n * 0.98:
		return {"ok": false, "why": "unreached %.1f%%" % (100.0 - 100.0 * got / free_n)}
	# 2. the gates and doors open onto that floor
	for d: Dictionary in lay.gates + lay.exits + [lay.entry]:
		var ci := _cell((d.pos as Vector2) + (d.n as Vector2) * 50.0, nx, ny)
		if ci < 0 or reach[ci] == 0:
			return {"ok": false, "why": "door or gate shut in"}
		for r: Rect2 in lay.cover:
			if _dist(r, d.pos) < CLEAR - 1.0:
				return {"ok": false, "why": "cover at a door"}
	# 3. an open floor somewhere to move in
	var wx := int(OPEN.x / CELL)
	var wy := int(OPEN.y / CELL)
	var open := false
	for j in ny - wy + 1:
		for i in nx - wx + 1:
			var s := raw[(j + wy) * (nx + 1) + i + wx] - raw[j * (nx + 1) + i + wx] - raw[(j + wy) * (nx + 1) + i] + raw[j * (nx + 1) + i]
			if s == 0:
				open = true
				break
		if open:
			break
	if not open:
		return {"ok": false, "why": "no open floor"}
	# 4. no slivers: pieces touch or stand a body and more apart
	var cover: Array = lay.cover
	for a in cover.size():
		var ra: Rect2 = cover[a]
		if not ROOM.grow(-GAP + 1.0).encloses(ra):
			return {"ok": false, "why": "cover hugs the wall"}
		for r: Rect2 in lay.walls:
			if _gap(ra, r) < GAP - 1.0:
				return {"ok": false, "why": "cover hugs a wall block"}
		for b in range(a + 1, cover.size()):
			if lay.piece[a] == lay.piece[b]:
				continue
			if _gap(ra, cover[b]) < GAP - 1.0:
				return {"ok": false, "why": "sliver between pieces"}
	# 5. as much cover as the hand-made room, give or take a quarter
	var st: Dictionary = STYLE[lay.story]
	var area := 0.0
	for r: Rect2 in cover:
		area += r.get_area()
	var sparse: bool = lay.sparse
	var lo_n := 3 if sparse else int(ceil(st.count * 0.75))
	var hi_n := 5 if sparse else int(floor(st.count * 1.25))
	if cover.size() < lo_n or cover.size() > hi_n:
		return {"ok": false, "why": "cover count %d" % cover.size()}
	if area < st.area * (0.4 if sparse else 0.75) or area > st.area * (0.9 if sparse else 1.25):
		return {"ok": false, "why": "cover area %d" % int(area)}
	# 6. the wave's title and the doors' labels stand over open floor
	for r: Rect2 in cover:
		if r.intersects(BANNER.grow(29.0)):
			return {"ok": false, "why": "cover under the title"}
		for d: Dictionary in lay.exits:
			if r.intersects(d.label):
				return {"ok": false, "why": "cover under a door's label"}
	# 6b. no gate under the HUD's foot or the clock; no remnant on a label
	for g: Dictionary in lay.gates:
		var gx: float = (g.pos as Vector2).x
		if (g.side == "B" and not ((gx > 515.0 and gx < 645.0) or (gx > 1175.0 and gx < 1325.0))) or (g.side == "T" and absf(gx - 960.0) < 300.0):
			return {"ok": false, "why": "a gate under the HUD"}
	var ex: Array = lay.exits
	for a in ex.size():
		for b in range(a + 1, ex.size()):
			if (ex[a].pos as Vector2).distance_to(ex[b].pos) < EXIT_APART - 1.0 or (ex[a].label as Rect2).intersects(ex[b].label):
				return {"ok": false, "why": "two ways on too close"}
	for d: Dictionary in ex:
		if (d.pos as Vector2).distance_to(lay.entry.pos) < FROM_ENTRY - 1.0:
			return {"ok": false, "why": "a way on by the way in"}
	for id in lay.spots:
		for d: Dictionary in lay.exits:
			if (d.label as Rect2).grow(30.0).has_point(lay.spots[id][0]):
				return {"ok": false, "why": "a remnant on a label"}
	# 7. no track through the titles or by the way in (where the first words are)
	if not lay.get("rails", []).is_empty() and lay.get("quiet", []).is_empty():
		return {"ok": false, "why": "tracks with nowhere marked to stop"}
	# 8. the remnants' props stand clear (placed so; checked again here)
	for id in lay.spots:
		var sp: Array = lay.spots[id]
		for r: Rect2 in cover:
			if _dist(r, sp[0]) < 120.0:
				return {"ok": false, "why": "cover on a remnant"}
	return {"ok": true, "why": ""}


# How alike two rooms are: shared solid floor over all solid floor (40 px
# cells); the cover alone, or the cover with the room's wall blocks.
static func overlap(a: Dictionary, b: Dictionary) -> float:
	var ga := occupancy(a)
	var gb := occupancy(b)
	var both := 0
	var any := 0
	for k in ga.size():
		if ga[k] == 1 and gb[k] == 1:
			both += 1
		if ga[k] == 1 or gb[k] == 1:
			any += 1
	return float(both) / maxf(1.0, any)


static func occupancy(lay: Dictionary, walls := true) -> PackedByteArray:
	var nx := int(ROOM.size.x / 40.0)
	var ny := int(ROOM.size.y / 40.0)
	var g := PackedByteArray()
	g.resize(nx * ny)
	for r: Rect2 in (lay.walls + lay.cover if walls else lay.cover):
		var i0 := clampi(int((r.position.x - ROOM.position.x) / 40.0), 0, nx - 1)
		var i1 := clampi(int((r.end.x - ROOM.position.x - 0.01) / 40.0), 0, nx - 1)
		var j0 := clampi(int((r.position.y - ROOM.position.y) / 40.0), 0, ny - 1)
		var j1 := clampi(int((r.end.y - ROOM.position.y - 0.01) / 40.0), 0, ny - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				g[j * nx + i] = 1
	return g


# Laser fences: `n` pairs of posts, each pair's beam across open floor (clear of
# every solid but its own posts, of doors, gates and where you start), the
# two groups taking turns (Lasers). Posts join the cover; beams go in lay.fences.
static func _fence_up(lay: Dictionary, taken: Array, rng: RandomNumberGenerator, n: int, pid: int) -> bool:
	for k in n:
		var done := false
		for tries in 60:
			var horiz := rng.randf() < 0.65
			var len := rng.randf_range(380.0, 760.0)
			var a := Vector2(rng.randf_range(ROOM.position.x + 140.0, ROOM.end.x - 140.0 - (len if horiz else 0.0)), rng.randf_range(ROOM.position.y + 140.0, ROOM.end.y - 140.0 - (0.0 if horiz else len)))
			var b := a + (Vector2(len, 0) if horiz else Vector2(0, len))
			var posts: Array[Rect2] = [Rect2(a - Vector2(POST, POST) / 2.0, Vector2(POST, POST)), Rect2(b - Vector2(POST, POST) / 2.0, Vector2(POST, POST))]
			if not _fits(posts, lay, taken):
				continue
			var ok := true
			for r: Rect2 in lay.walls + lay.cover:
				if _seg_hits(a, b, r.grow(30.0)):
					ok = false
			for d: Dictionary in taken:
				if Geometry2D.get_closest_point_to_segment(d.pos, a, b).distance_to(d.pos) < 170.0:
					ok = false
			if Geometry2D.get_closest_point_to_segment(lay.start, a, b).distance_to(lay.start) < 220.0:
				ok = false
			for f: Array in lay.fences:
				if (f[0] as Vector2).distance_to(a) < 160.0 or Geometry2D.segment_intersects_segment(a, b, f[0], f[1]) != null:
					ok = false
			if not ok:
				continue
			for r in posts:
				lay.cover.append(r)
				lay.piece.append(pid + k)
				lay.kinds.append("post")
			lay.fences.append([a, b, k % 2])
			done = true
			break
		if not done:
			return false
	return true


static func _seg_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[k], c[(k + 1) % 4]) != null:
			return true
	return false


# ---------------------------------------------------------------- helpers

static func _cell(p: Vector2, nx: int, ny: int) -> int:
	var i := int((p.x - ROOM.position.x) / CELL)
	var j := int((p.y - ROOM.position.y) / CELL)
	if i < 0 or j < 0 or i >= nx or j >= ny:
		return -1
	return j * nx + i


static func _dist(r: Rect2, p: Vector2) -> float:
	var c := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return c.distance_to(p)


static func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()


static func _bounds(rs: Array) -> Rect2:
	var bb: Rect2 = rs[0]
	for r: Rect2 in rs:
		bb = bb.merge(r)
	return bb


# a piece turned a quarter or not, and mirrored either way
static func _turn(piece: Array, rng: RandomNumberGenerator) -> Array[Rect2]:
	var rot := rng.randf() < 0.5
	var fx := rng.randf() < 0.5
	var fy := rng.randf() < 0.5
	var out: Array[Rect2] = []
	for r: Rect2 in piece:
		var q := r
		if rot:
			q = Rect2(q.position.y, q.position.x, q.size.y, q.size.x)
		if fx:
			q.position.x = -q.end.x
		if fy:
			q.position.y = -q.end.y
		out.append(q)
	return out


static func _weighted(d: Dictionary, rng: RandomNumberGenerator) -> String:
	var tot := 0
	for k in d:
		tot += int(d[k])
	var x := rng.randi() % tot
	for k in d:
		x -= int(d[k])
		if x < 0:
			return k
	return d.keys()[0]


# [weight, rects, kind] by weight; the room's theme's kinds weigh four times over
static func _weighted_piece(pieces: Array, rng: RandomNumberGenerator, theme: Array = []) -> Array:
	var tot := 0
	for p in pieces:
		tot += int(p[0]) * (4 if theme.has(p[2]) else 1)
	var x := rng.randi() % tot
	for p in pieces:
		x -= int(p[0]) * (4 if theme.has(p[2]) else 1)
		if x < 0:
			return p
	return pieces[0]


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
