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
const HUD_TOP := Rect2(740, 50, 440, 80)      # the wave, its clock and its grade, top middle
const EXIT_APART := 480.0                     # two ways on: this far apart, their labels and light their own
const FROM_ENTRY := 700.0                     # a way on this far from the way in: the room is crossed

# The chapters that walk room to room; the rest keep their one hand-made room.
const ON := [1, 2, 3, 4, 5, 6, 7, 8, 9]
const ARM_W := 200.0       # an arm's footing on its wall
const RING_R := 92.0       # a mood-scan ring's radius (ScanRings.R)
const RING_WARN := 66.0    # how far past it the red warning closes in from
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
		"shapes": {"hall": 3, "bays": 2, "twin": 2, "corner": 2, "neck": 1},
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
	4: {
		# the production union: presses, stacked rations, work stations; the
		# chapter's own are its robot arms on the walls (one in the first room,
		# three by the last) and the strategic reserve crate they fill
		"shapes": {"hall": 3, "bays": 2, "twin": 2, "corner": 2, "neck": 1},
		"pieces": [
			[3, [Rect2(0, 0, 68, 68)], "press"],
			[2, [Rect2(0, 0, 80, 80)], "press"],
			[2, [Rect2(0, 0, 92, 92)], "press"],
			[3, [Rect2(0, 0, 80, 80)], "rations"],
			[2, [Rect2(0, 0, 80, 80), Rect2(80, 0, 80, 80)], "rations"],
			[2, [Rect2(0, 0, 120, 50)], "station"],
		],
		"landmarks": [
			[3, [Rect2(0, 0, 92, 92), Rect2(92, 0, 92, 92)], "press"],          # a pair of big presses
			[2, [Rect2(0, 0, 140, 140)], "silo"],                               # a flour silo
			[2, [Rect2(0, 0, 240, 80)], "machine"],                             # a packing machine
		],
		"mech": {"pieces": [[1, [Rect2(0, 0, 190, 100)], "reserve"]], "count": [1, 1, 1, 1, 1, 1]},
		"arms": [1, 1, 2, 2, 3, 3],
		# the hand-made floor: six blocks and the crate
		"count": 7, "area": 54400.0,
		"themes": [["press"], ["rations"], ["station", "rations"]],
		"props": {"board": [220.0, 180.0], "crate": [0.0, 0.0], "notice": [180.0, 130.0], "scrawl": [220.0, 130.0]},
		"on_cover": {"crate": "reserve"},
	},
	5: {
		# the superconducting line's concourse: freight containers, ticket
		# barriers, station pillars; the chapter's own are its maglev guide
		# rails set in the floor, one in the first room and three by the last
		"shapes": {"hall": 3, "twin": 2, "corner": 1, "neck": 1, "bays": 2},
		"pieces": [
			[3, [Rect2(0, 0, 160, 60)], "cargo"],
			[2, [Rect2(0, 0, 160, 60), Rect2(0, 60, 160, 60)], "cargo"],
			[2, [Rect2(0, 0, 160, 48)], "barrier"],
			[2, [Rect2(0, 0, 70, 70)], "pillar5"],
		],
		"landmarks": [
			[3, [Rect2(0, 0, 300, 70)], "cargo"],                                # a long container
			[2, [Rect2(0, 0, 160, 60), Rect2(160, 30, 160, 60)], "cargo"],      # two, staggered
			[2, [Rect2(0, 0, 120, 120)], "signal"],                             # a signal box
		],
		"maglev": [1, 1, 2, 2, 3, 3],
		# the hand-made station (the yard's floor): six blocks
		"count": 6, "area": 50000.0,
		"themes": [["cargo"], ["barrier", "pillar5"], ["cargo", "barrier"]],
		"props": {"timetable": [220.0, 180.0], "yellow": [620.0, 90.0], "manifest": [0.0, 0.0], "scrawl": [220.0, 130.0]},
		"on_cover": {"manifest": "cargo"},
	},
	6: {
		# the energy bureau's floor: switch housings, meter cabinets, cable
		# drums, battery banks. The chapter's own is the current itself: it
		# arcs between your rounds, reaching further room by room
		"shapes": {"hall": 3, "twin": 2, "corner": 2, "neck": 2, "bays": 2},
		"pieces": [
			[3, [Rect2(0, 0, 80, 64)], "switch"],
			[2, [Rect2(0, 0, 60, 100)], "meter"],
			[2, [Rect2(0, 0, 84, 84)], "drum"],
			[2, [Rect2(0, 0, 140, 46)], "battery"],
		],
		"landmarks": [
			[3, [Rect2(0, 0, 150, 100)], "transformer"],
			[2, [Rect2(0, 0, 220, 50)], "switchboard"],
			[2, [Rect2(0, 0, 80, 64), Rect2(80, 0, 80, 64)], "switch"],
		],
		"arc_reach": [150.0, 155.0, 160.0, 170.0, 180.0, 190.0],
		# the hand-made floor: four low switch housings
		"count": 4, "area": 20500.0,
		"themes": [["switch"], ["meter", "battery"], ["drum"]],
		"props": {"ledger": [220.0, 180.0], "cabinet": [160.0, 150.0], "notice": [160.0, 150.0], "scrawl": [260.0, 150.0]},
	},
	7: {
		# the bureau of thought: mood-sample cabinets, speaker amps, the
		# synchronisation chairs; the chapter's own are its mood-scan rings set
		# in the floor, two in the first room and four by the last
		"shapes": {"hall": 3, "twin": 2, "corner": 2, "neck": 1, "bays": 2},
		"pieces": [
			[3, [Rect2(0, 0, 72, 72)], "sample"],
			[2, [Rect2(0, 0, 130, 50)], "amp"],
			[2, [Rect2(0, 0, 90, 90)], "chair"],
			[2, [Rect2(0, 0, 110, 60)], "console"],
			[2, [Rect2(0, 0, 54, 54)], "sample"],
			[1, [Rect2(0, 0, 90, 90), Rect2(90, 0, 90, 90)], "chair"],
		],
		"landmarks": [
			[3, [Rect2(0, 0, 90, 90), Rect2(90, 0, 90, 90), Rect2(180, 0, 90, 90)], "chair"],   # a row of chairs
			[2, [Rect2(0, 0, 150, 56), Rect2(0, 56, 150, 56), Rect2(0, 112, 150, 56)], "amp"],     # a stack of amps
			[2, [Rect2(0, 0, 320, 72)], "console"],                                               # the operators' desk
		],
		"rings": [2, 2, 3, 3, 4, 4],
		# the hand-made room: four corner pillars and a bar
		"count": 5, "area": 25500.0,
		"themes": [["sample"], ["chair"], ["amp", "console"]],
		"props": {"monitor": [220.0, 180.0], "chair": [160.0, 150.0], "slogan": [320.0, 200.0], "scrawl": [220.0, 150.0]},
	},
	8: {
		# the deep archive: card-index cabinets, reading desks, book trolleys;
		# the chapter's own are its banks of mobile shelving on floor rails,
		# one bank in the first rooms and two by the last
		"shapes": {"hall": 4, "twin": 2, "corner": 2, "bays": 1},
		"pieces": [
			[3, [Rect2(0, 0, 70, 70)], "catalog"],
			[2, [Rect2(0, 0, 150, 60)], "desk8"],
			[2, [Rect2(0, 0, 90, 46)], "trolley"],
		],
		"landmarks": [
			[3, [Rect2(0, 0, 70, 70), Rect2(70, 0, 70, 70)], "catalog"],
			[2, [Rect2(0, 0, 220, 64)], "desk8"],
		],
		"banks": [1, 1, 1, 2, 2, 2],
		# (the hand-made archive is nothing but shelving: the rest is held to a little cover)
		"count": 4, "area": 22000.0,
		"themes": [["catalog"], ["desk8", "trolley"]],
		"props": {"index": [220.0, 180.0], "plate": [440.0, 90.0], "rules": [160.0, 150.0], "scrawl": [220.0, 150.0]},
	},
	9: {
		# the orbital lift's car: rows of bolted seats, pillars, luggage racks,
		# the kiosks that bill the handrails by the minute; the chapter's own are
		# its airlock doors in the side walls, two in the first room and four by
		# the last
		"shapes": {"hall": 4, "twin": 2, "corner": 2, "bays": 1},
		"pieces": [
			[3, [Rect2(0, 0, 180, 44)], "seats"],
			[2, [Rect2(0, 0, 136, 44)], "seats"],
			[2, [Rect2(0, 0, 56, 56)], "pillar9"],
			[2, [Rect2(0, 0, 96, 60)], "luggage"],
			[1, [Rect2(0, 0, 70, 90)], "kiosk"],
		],
		"landmarks": [
			[3, [Rect2(0, 0, 180, 44), Rect2(0, 44, 180, 44)], "seats"],   # two rows back to back
			[2, [Rect2(0, 0, 90, 120)], "kiosk"],                           # the handrail kiosk
		],
		"vents": [2, 2, 3, 3, 4, 4],
		"windows": true,
		# the hand-made car: two benches and two pillars
		"count": 4, "area": 22000.0,
		"themes": [["seats"], ["pillar9", "luggage", "kiosk"]],
		# (the notice is a board read across: it stands well out from its side wall)
		"props": {"altitude": [220.0, 180.0], "deck": [440.0, 90.0], "rail": [130.0, 400.0], "scrawl": [220.0, 150.0]},
	},
	10: {
		# the orbital shipyard: crates of armour steel, cable spools, tether
		# bollards, welding rigs, a hull section waiting to go on; the
		# chapter's own are its loose hull plates adrift, three in the first
		# room and six by the last
		"shapes": {"hall": 4, "twin": 2, "corner": 2, "bays": 1},
		"pieces": [
			[3, [Rect2(0, 0, 120, 60)], "steelcrate"],
			[2, [Rect2(0, 0, 80, 80)], "spool"],
			[2, [Rect2(0, 0, 60, 60)], "bollard"],
			[2, [Rect2(0, 0, 120, 50)], "weldrig"],
		],
		"landmarks": [
			[3, [Rect2(0, 0, 120, 60), Rect2(0, 60, 120, 60)], "steelcrate"],   # two crates stacked
			[2, [Rect2(0, 0, 240, 56)], "hull"],                                # a hull section
		],
		"plates": [3, 3, 4, 4, 5, 6],
		# the hand-made yard: two crates, the rest is the plates
		"count": 4, "area": 24000.0,
		"themes": [["steelcrate", "hull"], ["spool", "bollard", "weldrig"]],
		"on_cover": {"steel": "steelcrate"},
		# (the notice is a board read across: it stands well out from its side wall)
		"props": {"schedule": [220.0, 180.0], "tether": [130.0, 400.0], "scrawl": [220.0, 150.0]},
	},
}


static var last_why := ""        # tests: where the last try gave up
static var why_tally := {}        # tests: how often each reason gave a try up
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
		last_ditch = attempt >= 120
		var lay := _try(st, story, index, cseed, entry, exits, remnants, rng, attempt >= 60)
		if lay.is_empty():
			why_tally[last_why] = int(why_tally.get(last_why, 0)) + 1
			continue
		lay["attempt"] = attempt
		var verdict := check(lay)
		if verdict.ok:
			return lay
		var cw := "check: " + str(verdict.why).left(20)
		why_tally[cw] = int(why_tally.get(cw, 0)) + 1
	return {}


# `spare`: late tries may leave out a remnant there is no wall for (Rooms
# carries it on to the next room)
static var last_ditch := false   # the last tries of make(): settle for less of a chapter's own


static func _try(st: Dictionary, story: int, index: int, cseed: int, entry: String, exits: Array, remnants: Array, rng: RandomNumberGenerator, spare := false) -> Dictionary:
	var sparse := index == 0 and story == 1
	var shape := "hall" if sparse else _weighted(st.shapes, rng)
	var walls := _shape(shape, rng)
	if not _clear_titles(walls):
		last_why = "titles"
		return {}
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
	lay["start"] = (e.pos as Vector2) + (e.n as Vector2) * 110.0
	# the arms take their walls before the gates do
	lay["arms"] = []
	if st.has("arms"):
		var want_a: int = (st.arms as Array)[mini(index, (st.arms as Array).size() - 1)]
		var sides_a: Array = ["T", "B", "L", "R"]
		_shuffle(sides_a, rng)
		for k in want_a:
			var got := {}
			for tries in 32:
				got = _door_on(sides_a[(k + tries) % 4], walls, taken, rng, ARM_W)
				if not got.is_empty() and (got.pos as Vector2).distance_to(lay.start) > 360.0:
					var zone := arm_zone(got.pos, got.n)
					var clear := true
					# its folded reach: not over a door's label, the HUD, or out past a corner
					var gp: Vector2 = got.pos
					var tan := Vector2(absf((got.n as Vector2).y), absf((got.n as Vector2).x))
					var u := gp.dot(tan)
					var lo := (ROOM.position.x if tan.x > 0.5 else ROOM.position.y) + 210.0
					var hi := (ROOM.end.x if tan.x > 0.5 else ROOM.end.y) - 210.0
					if u < lo or u > hi:
						clear = false
					for z: Rect2 in [HUD_STRIP, HUD_TOP, HUD_LORE, HUD_FOOT]:
						if zone.intersects(z):
							clear = false
					for d: Dictionary in lay.exits:
						if zone.intersects((d.label as Rect2).grow(20.0)):
							clear = false
					if clear:
						break
				got = {}
			if got.is_empty():
				last_why = "arms"
				return {}
			got["arm"] = true
			lay["arm_zones"] = lay.get("arm_zones", []) + [arm_zone(got.pos, got.n)]
			taken.append(got)
			lay.arms.append([got.pos, got.n, 3.0 * k])
	# spawn gates: one on each wall that has room for one, two on the long walls
	# (where airlocks take the side walls, the remnants on walls go first:
	# the airlocks and the gates work round them; the last tries, as elsewhere)
	if st.has("vents") and not last_ditch and not _remnants(lay, st, story, index, e, remnants, taken, rng, spare, false):
		last_why = "t6"
		return {}
	# the lift's airlock doors: in the side walls, the floor before each kept
	# clear, none by the way in
	lay["vents"] = []
	if st.has("vents"):
		var want_v: int = (st.vents as Array)[mini(index, (st.vents as Array).size() - 1)]
		for k in want_v:
			var done := false
			for tries in 12:
				var vn: Vector2 = [Vector2(1, 0), Vector2(-1, 0)][(k + tries) % 2]
				var need_v := [Vents.HALF * 2.0 + 36.0, 170.0]
				var sp := _spot_for(vn, need_v, lay, taken, rng, true)
				if sp.is_empty() or (sp[0] as Vector2).distance_to(lay.start) < 320.0:
					continue
				# (well apart from the ways in and out on the same wall: a draught
				# toward a door reads as a way out)
				var near_door := false
				for d: Dictionary in lay.exits + lay.gates + [lay.entry]:
					if d.has("n") and d.n == sp[1] and (d.pos as Vector2).distance_to(sp[0]) < need_v[0] / 2.0 + float(d.get("w", DOOR_W)) / 2.0 + (80.0 if last_ditch else 170.0):
						near_door = true
				# (two to a wall at most, well apart, and clear of the room's own wall blocks)
				var on_wall := 0
				for v: Array in lay.vents:
					if v[1] == sp[1]:
						on_wall += 1
						if (v[0] as Vector2).distance_to(sp[0]) < need_v[0] + (40.0 if last_ditch else 120.0):
							near_door = true
				if on_wall >= 2 and not last_ditch:
					near_door = true
				for r: Rect2 in walls:
					if _dist(r, sp[0]) < need_v[0] / 2.0 + (20.0 if last_ditch else 70.0):
						near_door = true
				if near_door:
					continue
				lay.vents.append([sp[0], sp[1]])
				var front := Rect2(sp[0] - Vector2(0, need_v[0] / 2.0), Vector2.ZERO).expand(sp[0] + Vector2(0, need_v[0] / 2.0) + (sp[1] as Vector2) * need_v[1]).abs()
				taken.append({"pos": sp[0], "n": sp[1], "w": need_v[0], "front": front})
				done = true
				break
			# (late tries: one door fewer will do; the very last, whatever fits)
			if not done and spare and k >= (1 if last_ditch else maxi(2, want_v - 1)):
				break
			if not done:
				last_why = "vents"
				return {}
	for s in ["T", "B", "L", "R"]:
		for k in (2 if s == "T" or s == "B" else 1):
			var g := _door_on(s, walls, taken, rng, GATE_W)
			if not g.is_empty():
				lay.gates.append(g)
				taken.append(g)
	# (where arms hold two or three walls, or airlocks the sides, two gates will do)
	if lay.gates.size() < (2 if (lay.arms as Array).size() >= 2 or not (lay.get("vents", []) as Array).is_empty() else 3):
		last_why = "t3"
		return {}
	# the remnants on walls first: their stretch of wall and the floor in front
	# are kept for them, and the cover goes round
	if (not st.has("vents") or last_ditch) and not _remnants(lay, st, story, index, e, remnants, taken, rng, spare, false):
		last_why = "t6"
		return {}
	# the car's windows onto the earth: one at least, in the upper half, clear
	# of the titles and the grade's stamp (placed before the cover, which keeps off them)
	lay["windows"] = []
	if st.get("windows", false):
		for k in (2 if rng.randf() < 0.5 else 1):
			var got := false
			for tries in 40:
				var sz := Vector2(rng.randf_range(280.0, 360.0), rng.randf_range(140.0, 170.0))
				var wr := Rect2(Vector2(rng.randf_range(ROOM.position.x + 60.0, ROOM.end.x - 60.0 - sz.x), rng.randf_range(ROOM.position.y + 70.0, 560.0 - sz.y)), sz)
				var ok := not wr.grow(20.0).intersects(HUD_STRIP) and not wr.grow(20.0).intersects(HUD_TOP) and not wr.intersects(TITLES.grow(60.0)) and not wr.intersects(Rect2(800, 220, 320, 240))
				for r: Rect2 in lay.walls:
					if r.grow(GAP).intersects(wr):
						ok = false
				for d: Dictionary in taken:
					if _dist(wr, d.pos) < 130.0:
						ok = false
					var fr: Rect2 = d.get("front", Rect2())
					if fr.size.x > 0.0 and fr.intersects(wr.grow(20.0)):
						ok = false
				for d: Dictionary in lay.exits:
					if (d.label as Rect2).grow(30.0).intersects(wr):
						ok = false
				for o: Rect2 in lay.windows:
					if o.grow(80.0).intersects(wr):
						ok = false
				if ok:
					lay.windows.append(wr)
					got = true
					break
			if not got and k == 0 and not last_ditch:
				last_why = "windows"
				return {}
	# the archive's shelving: on the low half of the room, clear of the wave's
	# title, so the middle stays open floor (placed before the cover, which goes round it)
	lay["banks"] = []
	if st.has("banks"):
		var want_b: int = (st.banks as Array)[mini(index, (st.banks as Array).size() - 1)]
		var foot_w := Shelves.span() + 24.0
		for k in want_b:
			var done := false
			for tries in 60:
				var x0 := rng.randf_range(ROOM.position.x + 72.0, ROOM.end.x - 72.0 - foot_w + 24.0)
				var foot := Rect2(x0 - 12.0, rng.randf_range(BANNER.end.y + 44.0, ROOM.end.y - 90.0 - Shelves.H - 48.0), foot_w, Shelves.H + 48.0)
				var ok := ROOM.grow(-60.0).encloses(foot)
				for r: Rect2 in lay.walls:
					if r.grow(GAP).intersects(foot):
						ok = false
				for d: Dictionary in taken:
					if _dist(foot, d.pos) < 120.0:
						ok = false
					var fr: Rect2 = d.get("front", Rect2())
					if fr.size.x > 0.0 and fr.intersects(foot):
						ok = false
				if _dist(foot, lay.start) < 200.0:
					ok = false
				for o: Rect2 in lay.get("bank_feet", []):
					if o.grow(140.0).intersects(foot):
						ok = false
				for z: Rect2 in [HUD_FOOT, HUD_LORE, BANNER]:
					if z.intersects(foot):
						ok = false
				for d: Dictionary in lay.exits:
					if (d.label as Rect2).grow(20.0).intersects(foot):
						ok = false
				if ok:
					lay.banks.append([x0, foot.position.y + 24.0])
					lay["bank_feet"] = lay.get("bank_feet", []) + [foot]
					done = true
					break
			# (late tries: a room with one bank fewer will do)
			if not done and spare and k > 0:
				break
			if not done:
				last_why = "banks"
				return {}
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
		var before := (lay.cover as Array).size()
		if not _fence_up(lay, taken, rng, want_f, pid):
			last_why = "fences"
			return {}
		pid += want_f
		for ci in range(before, (lay.cover as Array).size()):
			area += (lay.cover[ci] as Rect2).get_area()
	lay["rings"] = []
	if st.has("rings"):
		var want_r: int = (st.rings as Array)[mini(index, (st.rings as Array).size() - 1)]
		for k in want_r:
			var done := false
			for tries in 80:
				var c := Vector2(rng.randf_range(ROOM.position.x + RING_R + 40.0, ROOM.end.x - RING_R - 40.0), rng.randf_range(ROOM.position.y + RING_R + 40.0, ROOM.end.y - RING_R - 40.0))
				var ok := true
				# (its warning, closing in from well outside it, overlies nothing either)
				for r: Rect2 in lay.walls + lay.cover:
					if _dist(r, c) < RING_R + RING_WARN:
						ok = false
				for d: Dictionary in taken:
					if (d.pos as Vector2).distance_to(c) < RING_R + 130.0:
						ok = false
					var fr: Rect2 = d.get("front", Rect2())
					if fr.size.x > 0.0 and _dist(fr, c) < RING_R + RING_WARN:
						ok = false
				if c.distance_to(lay.start) < RING_R + 140.0:
					ok = false
				for z: Rect2 in [HUD_STRIP, HUD_TOP, BANNER, HUD_LORE]:
					if _dist(z, c) < RING_R + 10.0:
						ok = false
				for d: Dictionary in lay.exits:
					if _dist(d.label, c) < RING_R + RING_WARN:
						ok = false
				for o: Vector2 in lay.rings:
					if o.distance_to(c) < RING_R * 2.0 + 90.0:
						ok = false
				if ok:
					lay.rings.append(c)
					done = true
					break
			if not done:
				last_why = "rings"
				return {}
	# the shipyard's loose plates: in open floor, apart, none by a door
	lay["plates"] = []
	if st.has("plates"):
		var want_p: int = (st.plates as Array)[mini(index, (st.plates as Array).size() - 1)]
		var plate_sizes := [Vector2(170, 38), Vector2(38, 160), Vector2(150, 38), Vector2(120, 38), Vector2(38, 120)]
		for k in want_p:
			var done := false
			for tries in 60:
				var sz: Vector2 = plate_sizes[rng.randi() % plate_sizes.size()]
				var c := Vector2(rng.randf_range(ROOM.position.x + 120.0, ROOM.end.x - 120.0), rng.randf_range(ROOM.position.y + 140.0, ROOM.end.y - 120.0))
				var r := Rect2(c - sz * 0.5, sz)
				var ok := true
				for o: Rect2 in lay.walls + lay.cover:
					if o.grow(GAP).intersects(r):
						ok = false
				for d: Dictionary in taken:
					if _dist(r, d.pos) < CLEAR:
						ok = false
					var fr: Rect2 = d.get("front", Rect2())
					if fr.size.x > 0.0 and fr.intersects(r.grow(20.0)):
						ok = false
				if _dist(r, lay.start) < 220.0:
					ok = false
				for pl: Array in lay.plates:
					if Rect2((pl[0] as Vector2) - (pl[1] as Vector2) * 0.5, pl[1]).grow(90.0).intersects(r):
						ok = false
				for z: Rect2 in [HUD_STRIP, HUD_TOP, HUD_FOOT, HUD_LORE, BANNER]:
					if z.intersects(r):
						ok = false
				for d: Dictionary in lay.exits:
					if (d.label as Rect2).grow(30.0).intersects(r):
						ok = false
				if ok:
					lay.plates.append([c, sz])
					done = true
					break
			if not done and spare and k >= 2:
				break
			if not done:
				last_why = "plates"
				return {}
	lay["maglev"] = []
	if st.has("maglev"):
		var want_m: int = (st.maglev as Array)[mini(index, (st.maglev as Array).size() - 1)]
		if not _rails_down(lay, taken, rng, want_m):
			last_why = "maglev"
			return {}
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
	# then the remnants read off cover, once the cover stands
	if not _remnants(lay, st, story, index, e, remnants, taken, rng, spare, true):
		last_why = "t6"
		return {}
	# both halves of the room have something in them (the first room: a fair piece each)
	var halves := [0.0, 0.0]
	# (the shipyard's loose plates are cover too)
	for r: Rect2 in lay.cover + Plates.rects_for(lay.get("plates", [])):
		halves[0 if r.get_center().x < 960.0 else 1] += r.get_area()
	var least: float = 6000.0 if sparse else 0.18 * (halves[0] + halves[1])
	if halves[0] < least or halves[1] < least:
		last_why = "t7"
		return {}
	if story == 2:
		_paint_hall(lay, taken, rng)
	elif story == 3:
		_paint_range(lay, taken, rng)
	elif story == 4:
		_paint_union(lay, taken, rng)
	elif story == 5:
		_paint_station(lay, taken, rng)
	elif story == 6:
		_paint_bureau(lay, taken, rng)
	elif story == 8:
		_paint_archive(lay, taken, rng)
	elif story == 9:
		_paint_lift(lay, taken, rng)
	elif story == 10:
		_paint_dock(lay, taken, rng)
	elif story == 1:
		_paint(lay, taken, rng)
	else:
		lay["quiet"] = _quiet(lay)
	return lay


# The bureau's floor: cables run from the walls in square bends to the
# cover they feed (cut where words are), a high-voltage stencil or two.
static func _paint_bureau(lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> void:
	lay["quiet"] = _quiet(lay)
	lay["arc_reach"] = (STYLE[6].arc_reach as Array)[mini(lay.index, 5)]
	var cables: Array = []
	var cover: Array = lay.cover
	var order: Array = range(cover.size())
	_shuffle(order, rng)
	for ci in order.slice(0, mini(3, order.size())):
		var to: Vector2 = (cover[ci] as Rect2).get_center()
		# down from the top or up from the bottom wall, a little to one side,
		# then one square bend across to it: every run straight
		var lower: bool = to.y > (ROOM.position.y + ROOM.end.y) * 0.5
		var x := clampf(to.x + rng.randf_range(-260.0, 260.0), ROOM.position.x + 40.0, ROOM.end.x - 40.0)
		var from := Vector2(x, ROOM.end.y if lower else ROOM.position.y)
		var bend := Vector2(x, to.y)
		cables.append([from, bend, to])
	lay["cables"] = cables
	# two of the districts' meter cabinets on the walls, each showing its share
	var cabs: Array = []
	var dist := [0, 1, 2]
	_shuffle(dist, rng)
	for k in 2:
		var side_n: Vector2 = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1)][rng.randi() % 3]
		var sp := _spot_for(side_n, [130.0, 80.0], lay, taken, rng, true)
		if not sp.is_empty():
			cabs.append([sp[0], sp[1], dist[k]])
			taken.append({"pos": sp[0], "n": sp[1], "w": 130.0})
	lay["cabinets"] = cabs
	# 13th Street's own line: a wire run off a wall, looping where it was
	# hung, to a bulb that is lit
	lay["selfwire"] = []
	for tries in 30:
		var side_n: Vector2 = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1)][rng.randi() % 3]
		var sp := _spot_for(side_n, [120.0, 240.0], lay, taken, rng, true)
		if sp.is_empty():
			continue
		var p0: Vector2 = sp[0]
		var n: Vector2 = sp[1]
		var tan := Vector2(n.y, -n.x)
		# not across the cables already run along the floor
		var reach := Rect2(p0 - tan * 60.0, Vector2.ZERO).expand(p0 + tan * 60.0 + n * 240.0).abs()
		var crosses := false
		for cb: Array in cables:
			for kk in cb.size() - 1:
				if _seg_hits(cb[kk], cb[kk + 1], reach):
					crosses = true
		if crosses:
			continue
		var pts: Array = [p0]
		var q := p0
		for k in 4:
			q = q + n * rng.randf_range(40.0, 60.0) + tan * rng.randf_range(-36.0, 36.0)
			pts.append(q)
		lay.selfwire = pts
		taken.append({"pos": p0, "n": n, "w": 120.0})
		break
	lay["stencil"] = []
	var solid: Array = lay.walls + lay.cover
	for tries in 30:
		var at := Vector2(rng.randf_range(ROOM.position.x + 160.0, ROOM.end.x - 300.0), rng.randf_range(ROOM.position.y + 160.0, ROOM.end.y - 200.0))
		var box := Rect2(at - Vector2(10, 50), Vector2(260, 70))
		var ok := true
		for r: Rect2 in solid + lay.quiet:
			if r.grow(20.0).intersects(box):
				ok = false
		if ok:
			lay.stencil = [at, "▲ 380 kV"]
			break


# The shipyard's deck: tether anchors along the side walls clear of their
# doors, weld scars and hazard chevrons in the open floor.
static func _paint_dock(lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> void:
	lay["quiet"] = _quiet(lay)
	lay["anchors"] = []
	for k in 4:
		for tries in 20:
			var left := rng.randf() < 0.5
			var a := Vector2(ROOM.position.x + 12.0 if left else ROOM.end.x - 12.0, rng.randf_range(ROOM.position.y + 120.0, ROOM.end.y - 160.0))
			var ok := true
			for d: Dictionary in taken:
				if (d.pos as Vector2).distance_to(a) < float(d.get("w", DOOR_W)) / 2.0 + 60.0:
					ok = false
			for r: Rect2 in lay.walls + lay.cover:
				if r.grow(40.0).has_point(a):
					ok = false
			for o: Vector2 in lay.anchors:
				if o.distance_to(a) < 200.0:
					ok = false
			if HUD_LORE.grow(20.0).has_point(a) or HUD_STRIP.grow(20.0).has_point(a):
				ok = false
			if ok:
				lay.anchors.append(a)
				break
	lay["scars"] = []
	var solid: Array = lay.walls + lay.cover + Plates.rects_for(lay.get("plates", []))
	for k in 5:
		for tries in 20:
			var c := Vector2(rng.randf_range(ROOM.position.x + 100.0, ROOM.end.x - 100.0), rng.randf_range(ROOM.position.y + 100.0, ROOM.end.y - 100.0))
			var ok := true
			for r: Rect2 in solid + lay.quiet:
				if _dist(r, c) < 60.0:
					ok = false
			for o: Array in lay.scars:
				if (o[0] as Vector2).distance_to(c) < 220.0:
					ok = false
			if ok:
				lay.scars.append([c, rng.randf() * TAU, rng.randi() % 2])
				break


# The car's walls and floor: its windows onto the earth along the top wall
# where it is clear, the handrails down the side walls broken at every door
# in them.
static func _paint_lift(lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> void:
	lay["quiet"] = _quiet(lay)
	# the handrails: what is left of each side wall between its doors and blocks
	lay["handrails"] = []
	for side in 2:
		var x: float = ROOM.position.x + 16.0 if side == 0 else ROOM.end.x - 16.0
		var cuts: Array = []
		for d: Dictionary in taken:
			var p: Vector2 = d.pos
			if absf(p.x - (ROOM.position.x if side == 0 else ROOM.end.x)) < 4.0:
				var half: float = float(d.get("w", DOOR_W)) / 2.0 + 40.0
				cuts.append([p.y - half, p.y + half])
		for r: Rect2 in lay.walls:
			if r.grow(4.0).has_point(Vector2(x, r.get_center().y)) or (side == 0 and r.position.x <= ROOM.position.x + 20.0) or (side == 1 and r.end.x >= ROOM.end.x - 20.0):
				cuts.append([r.position.y - 30.0, r.end.y + 30.0])
		var y := ROOM.position.y + 40.0
		var stops: Array = []
		while y < ROOM.end.y - 40.0:
			var free := true
			for c: Array in cuts:
				if y >= float(c[0]) and y <= float(c[1]):
					free = false
			stops.append(free)
			y += 10.0
		var run_from := -1.0
		for k2 in stops.size() + 1:
			var yy := ROOM.position.y + 40.0 + k2 * 10.0
			var free2: bool = stops[k2] if k2 < stops.size() else false
			if free2 and run_from < 0.0:
				run_from = yy
			elif not free2 and run_from >= 0.0:
				if yy - run_from >= 160.0:
					lay.handrails.append([Vector2(x, run_from), Vector2(x, yy - 10.0)])
				run_from = -1.0


# The archive's floor: a viewport onto the black water in open floor, the
# depth gauge by a wall.
static func _paint_archive(lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> void:
	lay["quiet"] = _quiet(lay)
	var solid: Array = lay.walls + lay.cover + Shelves.rects_for(lay.get("banks", []))
	lay["viewport"] = Vector2(-1, -1)
	for tries in 40:
		var c := Vector2(rng.randf_range(ROOM.position.x + 140.0, ROOM.end.x - 140.0), rng.randf_range(ROOM.position.y + 140.0, ROOM.end.y - 140.0))
		var ok := true
		for r: Rect2 in solid + lay.quiet:
			if _dist(r, c) < 90.0:
				ok = false
		for foot: Rect2 in lay.get("bank_feet", []):
			if _dist(foot, c) < 90.0:
				ok = false
		for d: Dictionary in taken:
			if (d.pos as Vector2).distance_to(c) < 160.0:
				ok = false
			var fr: Rect2 = d.get("front", Rect2())
			if fr.size.x > 0.0 and _dist(fr, c) < 130.0:
				ok = false
		if ok:
			lay.viewport = c
			taken.append({"pos": c, "n": Vector2.ZERO, "w": 160.0})
			break
	lay["gauge"] = []
	for tries in 6:
		var sp := _spot_for(Vector2(0, -1), [300.0, 80.0], lay, taken, rng, true)
		# (its dial and reading sit just off the wall: clear of the magazine count)
		if sp.is_empty() or Rect2((sp[0] as Vector2) + Vector2(-170, -90), Vector2(380, 90)).intersects(HUD_FOOT):
			continue
		lay.gauge = sp
		taken.append({"pos": sp[0], "n": sp[1], "w": 300.0})
		break


# The concourse floor: painted way-arrows for the line, the tactile strip by
# the platform's edge is the platform's own; worn patches where crowds stood.
static func _paint_station(lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> void:
	lay["quiet"] = _quiet(lay)
	var solid: Array = lay.walls + lay.cover
	var arrows: Array = []
	for tries in 30:
		if arrows.size() >= 1:
			break       # one way-arrow to a room: more reads as wallpaper
		var at := Vector2(rng.randf_range(ROOM.position.x + 160.0, ROOM.end.x - 160.0), rng.randf_range(ROOM.position.y + 160.0, ROOM.end.y - 160.0))
		var box := Rect2(at - Vector2(110, 40), Vector2(220, 80))
		var ok := true
		for r: Rect2 in solid + lay.quiet:
			if r.grow(20.0).intersects(box):
				ok = false
		for f: Array in lay.get("maglev", []):
			if _seg_hits(f[0], f[1], box.grow(30.0)):
				ok = false
		for o: Array in arrows:
			if (o[0] as Vector2).distance_to(at) < 300.0:
				ok = false
		if ok:
			arrows.append([at, [-1.0, 1.0][rng.randi() % 2]])
	lay["arrows"] = arrows


# The union's floor: a conveyor belt or two across open floor (cut where
# cover, doors, gates or words are), oil worn into it, the quota painted.
static func _paint_union(lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> void:
	lay["quiet"] = _quiet(lay)
	var cuts: Array = []
	for r: Rect2 in lay.walls + lay.cover:
		cuts.append(r.grow(40.0))
	cuts.append_array(lay.quiet)
	cuts.append_array(lay.get("arm_zones", []))
	for d: Dictionary in taken:
		cuts.append(Rect2((d.pos as Vector2) - Vector2(120, 120), Vector2(240, 240)))
	var belts: Array = []
	for n in rng.randi_range(1, 2):
		var best: Array = []
		var bl := 0.0
		for tries in 12:
			var y := rng.randf_range(ROOM.position.y + 140.0, ROOM.end.y - 140.0)
			var segs := _spans(Vector2(ROOM.position.x + 60.0, y), Vector2(ROOM.end.x - 60.0, y), cuts)
			var tot := 0.0
			var keep: Array = []
			for sg: Array in segs:
				if (sg[0] as Vector2).distance_to(sg[1]) >= 260.0:
					keep.append(sg)
					tot += (sg[0] as Vector2).distance_to(sg[1])
			for o: Array in belts:
				if absf((o[0] as Vector2).y - y) < 160.0:
					tot = 0.0
			if tot > bl:
				bl = tot
				best = keep
		for sg: Array in best:
			# a belt runs one way: half of them right to left
			belts.append(sg if rng.randf() < 0.5 else [sg[1], sg[0]])
	lay["belts"] = belts
	var stains: Array = []
	for k in rng.randi_range(3, 5):
		stains.append([Vector2(rng.randf_range(ROOM.position.x + 80.0, ROOM.end.x - 80.0), rng.randf_range(ROOM.position.y + 80.0, ROOM.end.y - 80.0)), rng.randf_range(18.0, 34.0), rng.randf() * TAU])
	lay["stains"] = stains


# The parts of horizontal or vertical line a-b outside every rect, as [from, to].
static func _spans(a: Vector2, b: Vector2, rects: Array) -> Array:
	var horiz := absf(b.y - a.y) < 0.5
	var lo := a.x if horiz else a.y
	var hi := b.x if horiz else b.y
	var cuts: Array = []
	for r: Rect2 in rects:
		if horiz and (a.y < r.position.y or a.y > r.end.y):
			continue
		if not horiz and (a.x < r.position.x or a.x > r.end.x):
			continue
		cuts.append([r.position.x if horiz else r.position.y, r.end.x if horiz else r.end.y])
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var out: Array = []
	var u := lo
	for ct: Array in cuts:
		if ct[0] > u:
			out.append([u, minf(ct[0], hi)])
		u = maxf(u, ct[1])
	if u < hi:
		out.append([u, hi])
	var segs: Array = []
	for sp: Array in out:
		if sp[1] - sp[0] > 2.0:
			segs.append([Vector2(sp[0], a.y), Vector2(sp[1], a.y)] if horiz else [Vector2(a.x, sp[0]), Vector2(a.x, sp[1])])
	return segs


# The range's floor: numbered firing lanes out from one wall, distance marks
# down them, scorch where things burned, holes round what was shot at.
static func _paint_range(lay: Dictionary, taken: Array, rng: RandomNumberGenerator) -> void:
	lay["quiet"] = _quiet(lay)
	var solid: Array = lay.walls + lay.cover
	lay["lanes3"] = []
	for tries in 16:
		var side: String = ["T", "L", "R"][rng.randi() % 3]
		# not out from a wall a way on stands in (the way in, shut behind you, will do)
		var by_door := false
		for d: Dictionary in lay.exits:
			if d.side == side:
				by_door = true
		if by_door:
			continue
		var horiz := side == "T"
		var n := rng.randi_range(3, 5)
		var lw := rng.randf_range(150.0, 200.0)
		var deep := rng.randf_range(260.0, 360.0)
		var u0 := rng.randf_range((ROOM.position.x if horiz else ROOM.position.y) + 120.0, (ROOM.end.x if horiz else ROOM.end.y) - 120.0 - lw * n)
		var base: float = {"T": ROOM.position.y, "L": ROOM.position.x, "R": ROOM.end.x - deep}[side]
		var all := Rect2(u0, base, lw * n, deep) if horiz else Rect2(base, u0, deep, lw * n)
		# (paint: where a door, a gate or a wall block stands on it, it is cut there)
		var ok := not all.intersects(HUD_STRIP) and not all.intersects(BANNER)
		for d: Dictionary in lay.exits:
			if (d.label as Rect2).grow(40.0).intersects(all):
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



# The remnants this room holds, each on a wall facing the way its words read
# (`on_cover`: just those read off a piece of cover). False if one finds no
# place and late tries may not leave it out.
static func _remnants(lay: Dictionary, st: Dictionary, story: int, index: int, e: Dictionary, remnants: Array, taken: Array, rng: RandomNumberGenerator, spare: bool, on_cover: bool) -> bool:
	var all_w: Array = Lore.walls(story)
	for id: String in remnants:
		var w: Array = []
		for ww in all_w:
			if ww[0] == id:
				w = ww
		if w.is_empty():
			continue
		var on_kind: String = st.get("on_cover", {}).get(id, "")
		if (on_kind != "") != on_cover:
			continue
		var need: Array = (st.props.get(id, [220.0, 140.0]) as Array).duplicate()
		# graffiti runs as long as its words: along a top wall the wall must be
		# that long; on a side wall the words run out into the room
		var words := 22.0 * (w[4] as String).length() + 60.0
		if w[3] == "scrawl_top":
			need[0] = maxf(need[0], words)
		elif w[3] == "scrawl":
			need[1] = maxf(need[1], minf(words, 520.0))
		var spot: Array = []
		if on_kind != "":
			# on the lid of a piece of that kind, read from above
			# (one lying the long way first: its words want the width)
			for pass_n in 2:
				for ci in (lay.cover as Array).size():
					var cr: Rect2 = lay.cover[ci]
					if lay.kinds[ci] == on_kind and (pass_n == 1 or cr.size.x >= cr.size.y):
						spot = [Vector2(cr.get_center().x, cr.position.y), Vector2(0, -1)]
						break
				if not spot.is_empty():
					break
		elif id == st.get("entry_prop", "") and index == 0:
			if NORMAL[e.side] == w[2]:
				spot = [e.pos, e.n]
		else:
			spot = _spot_for(w[2], need, lay, taken, rng, w[3] == "scrawl" or w[3] == "scrawl_top")
		if spot.is_empty() and spare:
			continue
		if spot.is_empty():
			return false
		lay.spots[id] = spot
		var tan := Vector2(absf((spot[1] as Vector2).y), absf((spot[1] as Vector2).x))
		var front := Rect2(spot[0] - tan * need[0] / 2.0, Vector2.ZERO).expand(spot[0] + tan * need[0] / 2.0 + (spot[1] as Vector2) * need[1]).abs()
		taken.append({"pos": spot[0], "n": spot[1], "w": need[0], "front": front if on_kind == "" else Rect2()})
	return true

# ---------------------------------------------------------------- shapes

# Where the chapter's title card and each wave's title show, mid-screen: no
# wall block in it. A spur off the top or bottom of the room is cut back
# short of it; anything else there and the try is given up.
const TITLES := Rect2(640, 290, 640, 210)


static func _clear_titles(walls: Array[Rect2]) -> bool:
	var k := 0
	while k < walls.size():
		var w: Rect2 = walls[k]
		if not w.intersects(TITLES):
			k += 1
			continue
		if w.position.y <= ROOM.position.y + 4.0 and w.end.y > TITLES.position.y:
			w.size.y = TITLES.position.y - 20.0 - w.position.y
		elif w.end.y >= ROOM.end.y - 4.0 and w.position.y < TITLES.end.y:
			var e := w.end.y
			w.position.y = TITLES.end.y + 20.0
			w.size.y = e - w.position.y
		else:
			return false
		if w.size.y < 60.0:
			walls.remove_at(k)
		else:
			walls[k] = w
			k += 1
	return true


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
	for tries in 48:
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
			# (a gate by a door's light: further apart; an arm's footing is not a door)
			var mixed: bool = (w < DOOR_W) != (float(d.get("w", DOOR_W)) < DOOR_W) and not d.get("arm", false)
			var keep := w / 2.0 + float(d.get("w", DOOR_W)) / 2.0 + (260.0 if mixed else 120.0)
			if dn == n and (d.pos as Vector2).distance_to(p) < keep:
				ok = false
			elif (d.pos as Vector2).distance_to(p) < (330.0 if mixed else 260.0):
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


# Where an arm folds against its wall and its claw hangs: kept clear of
# cover, belts and words.
static func arm_zone(base: Vector2, n: Vector2) -> Rect2:
	var tan := Vector2(absf(n.y), absf(n.x))
	return Rect2(base - tan * 200.0, Vector2.ZERO).expand(base + tan * 200.0 + n * 110.0).abs()


static func _fits(placed: Array[Rect2], lay: Dictionary, taken: Array) -> bool:
	var inside := ROOM.grow(-GAP)
	# nothing under the wave's title (a gantry's beam spans the gap between its legs)
	if _bounds(placed).intersects(BANNER.grow(30.0)):
		return false
	for z: Rect2 in lay.get("arm_zones", []):
		if _bounds(placed).intersects(z):
			return false
	for c: Vector2 in lay.get("rings", []):
		for r in placed:
			if _dist(r, c) < RING_R + RING_WARN:
				return false
	for foot: Rect2 in lay.get("bank_feet", []) + lay.get("windows", []):
		for r in placed:
			if foot.grow(GAP).intersects(r):
				return false
	for d: Dictionary in lay.exits:
		if _bounds(placed).intersects((d.label as Rect2).grow(20.0)):
			return false
	for f: Array in lay.get("fences", []) + lay.get("maglev", []):
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
			if (d.get("front", Rect2()) as Rect2).size.x > 0.0 and r.intersects(d.front):
				return false
		if _dist(r, lay.start) < 170.0:
			return false
	return true


# A place for a remnant's prop: on a wall (the room's or a wall block's face)
# whose face looks the way the words were written to be read, with the length
# of wall and the floor in front of it the prop needs.
# (`outer`: the room's own walls only: graffiti is sprayed on a wall, not on a stub)
static func _spot_for(n: Vector2, need: Array, lay: Dictionary, taken: Array, rng: RandomNumberGenerator, outer := false) -> Array:
	var faces: Array = []    # [a, b] segments facing n
	if n == Vector2(1, 0):
		faces.append([ROOM.position, Vector2(ROOM.position.x, ROOM.end.y)])
	elif n == Vector2(-1, 0):
		faces.append([Vector2(ROOM.end.x, ROOM.position.y), ROOM.end])
	elif n == Vector2(0, 1):
		faces.append([ROOM.position, Vector2(ROOM.end.x, ROOM.position.y)])
	else:
		faces.append([Vector2(ROOM.position.x, ROOM.end.y), ROOM.end])
	for r: Rect2 in ([] if outer else lay.walls):
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
		var ok := ROOM.grow(1.0).encloses(front) and not front.intersects(HUD_STRIP) and not front.intersects(HUD_LORE) and not front.intersects(BANNER.grow(20.0))
		for d: Dictionary in lay.exits:
			if front.grow(30.0).intersects(d.label):
				ok = false
		for r: Rect2 in lay.walls + lay.cover:
			if r.intersects(front.grow(-1.0)):
				ok = false
		for d: Dictionary in taken:
			# (a spawn gate's red frame keeps further off words)
			var gap := 70.0 if float(d.get("w", DOOR_W)) < DOOR_W else 30.0
			if (d.pos as Vector2).distance_to(p) < half + float(d.get("w", DOOR_W)) / 2.0 + gap:
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
	solids.append_array(Shelves.rects_for(lay.get("banks", [])))
	solids.append_array(Plates.rects_for(lay.get("plates", [])))
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
	for f: Array in lay.get("fences", []):
		for z: Rect2 in [HUD_STRIP.grow(19.0), HUD_TOP, BANNER.grow(19.0)]:
			if _seg_hits(f[0], f[1], z):
				return {"ok": false, "why": "a beam over the words"}
		for d: Dictionary in lay.exits:
			if _seg_hits(f[0], f[1], (d.label as Rect2).grow(23.0)):
				return {"ok": false, "why": "a beam over a door's label"}
	var on_cover: Dictionary = st.get("on_cover", {})
	for id in lay.spots:
		if on_cover.has(id):
			continue      # read off a piece of cover: it stands on one by rights
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
		for tries in 80:
			var horiz := rng.randf() < 0.65
			var len := rng.randf_range(380.0, 760.0)
			var a := Vector2(rng.randf_range(ROOM.position.x + 140.0, ROOM.end.x - 140.0 - (len if horiz else 0.0)), rng.randf_range(ROOM.position.y + 140.0, ROOM.end.y - 140.0 - (0.0 if horiz else len)))
			var b := a + (Vector2(len, 0) if horiz else Vector2(0, len))
			var posts: Array[Rect2] = [Rect2(a - Vector2(POST, POST) / 2.0, Vector2(POST, POST)), Rect2(b - Vector2(POST, POST) / 2.0, Vector2(POST, POST))]
			if rng.randf() < 0.5:
				# or from a wall in to one post, as the hand-made range has them:
				# the beam runs from the post to whatever wall it meets
				var dir := Vector2([1, -1][rng.randi() % 2], 0) if horiz else Vector2(0, [1, -1][rng.randi() % 2])
				var hit := _to_wall(b, dir, lay)
				if hit.x < -1.0 or hit.distance_to(b) < 300.0 or hit.distance_to(b) > 820.0:
					continue
				a = hit
				posts = [Rect2(b - Vector2(POST, POST) / 2.0, Vector2(POST, POST))]
			if not _fits(posts, lay, taken):
				continue
			var ok := true
			for r: Rect2 in lay.walls + lay.cover:
				# (a beam from a wall starts at that wall's face)
				if _seg_hits(a + (b - a).normalized() * 34.0, b, r.grow(30.0)):
					ok = false
			for d: Dictionary in taken:
				if Geometry2D.get_closest_point_to_segment(d.pos, a, b).distance_to(d.pos) < 170.0:
					ok = false
			if Geometry2D.get_closest_point_to_segment(lay.start, a, b).distance_to(lay.start) < 220.0:
				ok = false
			# nor across a door's label, the broadcast, the top of the HUD or the titles
			for z: Rect2 in [HUD_STRIP.grow(20.0), HUD_TOP, BANNER.grow(20.0)]:
				if _seg_hits(a, b, z):
					ok = false
			for d: Dictionary in lay.exits:
				if _seg_hits(a, b, (d.label as Rect2).grow(24.0)):
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


# Maglev guide rails: `n` straight runs set in open floor (clear of every
# solid, doors, gates, where you start and the words), the two groups taking
# turns (Maglev). Floor only: nothing stands on them.
static func _rails_down(lay: Dictionary, taken: Array, rng: RandomNumberGenerator, n: int) -> bool:
	for k in n:
		var done := false
		for tries in 80:
			var horiz := rng.randf() < 0.6
			var len := rng.randf_range(200.0, 520.0)
			var a := Vector2(rng.randf_range(ROOM.position.x + 160.0, ROOM.end.x - 160.0 - (len if horiz else 0.0)), rng.randf_range(ROOM.position.y + 160.0, ROOM.end.y - 160.0 - (0.0 if horiz else len)))
			var b := a + (Vector2(len, 0) if horiz else Vector2(0, len))
			var ok := true
			for r: Rect2 in lay.walls + lay.cover:
				if _seg_hits(a, b, r.grow(40.0)):
					ok = false
			for d: Dictionary in taken:
				if Geometry2D.get_closest_point_to_segment(d.pos, a, b).distance_to(d.pos) < 160.0:
					ok = false
			if Geometry2D.get_closest_point_to_segment(lay.start, a, b).distance_to(lay.start) < 180.0:
				ok = false
			for z: Rect2 in [HUD_STRIP.grow(20.0), HUD_TOP, BANNER.grow(20.0)]:
				if _seg_hits(a, b, z):
					ok = false
			for d: Dictionary in lay.exits:
				if _seg_hits(a, b, (d.label as Rect2).grow(24.0)):
					ok = false
			for f: Array in lay.maglev:
				if Geometry2D.segment_intersects_segment(a, b, f[0], f[1]) != null or Geometry2D.get_closest_point_to_segment(a, f[0], f[1]).distance_to(a) < 120.0:
					ok = false
			if not ok:
				continue
			lay.maglev.append([a, b, k % 2])
			done = true
			break
		if not done:
			return false
	return true


# Where a line from p heading `dir` first meets a wall (the room's edge or a
# wall block): (-9, -9) if it meets cover first.
static func _to_wall(p: Vector2, dir: Vector2, lay: Dictionary) -> Vector2:
	var best := INF
	var hit := Vector2(-9, -9)
	var far := p + dir * 3000.0
	var edges := [[ROOM.position, Vector2(ROOM.end.x, ROOM.position.y)], [Vector2(ROOM.position.x, ROOM.end.y), ROOM.end], [ROOM.position, Vector2(ROOM.position.x, ROOM.end.y)], [Vector2(ROOM.end.x, ROOM.position.y), ROOM.end]]
	var segs: Array = []
	for e2: Array in edges:
		segs.append([e2[0], e2[1], true])
	for r: Rect2 in lay.walls + lay.cover:
		var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		var is_wall: bool = (lay.walls as Array).has(r)
		for k in 4:
			segs.append([c[k], c[(k + 1) % 4], is_wall])
	for sg: Array in segs:
		var x = Geometry2D.segment_intersects_segment(p, far, sg[0], sg[1])
		if x != null and p.distance_to(x) < best:
			best = p.distance_to(x)
			hit = x if sg[2] else Vector2(-9, -9)
	return hit


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
