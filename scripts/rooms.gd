class_name Rooms
extends Node2D
# The walk from room to room (RoomGen) in the chapters that have it: each
# wave in a room of its own, the boss in the chapter's hand-made room. A
# cleared room opens its ways on (two, now and then: the harder way pays an
# extra pick); walk through one and the rounds in the walls come home, the
# view slides on, and you step into the next room from its far side.
# Enemies come in through the room's spawn gates.

const SLIDE := 0.5
const FIRST_ENTRY := {1: "L"}       # the side the first room is entered from

var game
var active := false
var cseed := 0
var lay := {}                       # the room you stand in ({} = the hand-made room)
var room_index := -1                # the wave this room is for
var entry_side := "L"
var risky_now := false              # this room was reached the harder way
var forks: Array = []               # rooms that offer a harder way on
var homes := {}                     # remnant id -> the room that holds it
var bonus := 0                      # extra picks owed
var open := false
var open_k := 0.0
var open_t := 0.0
var trans_t := -1.0
var trans_dir := Vector2.ZERO
var swapped := false
var taken := {}
var gate_hot := {}                  # gate index -> 1..0 as it lights for a spawn
var ahead := {}                     # "index entry" -> the room laid out before you get there
var t := 0.0
var font: Font
var font_s: Font


func _ready() -> void:
	z_index = 3
	z_as_relative = false
	font = Fonts.get_font("SemiBold")
	font_s = Fonts.get_font("Regular")


func setup(ch: int) -> void:
	var story := Chapters.story(ch)
	active = RoomGen.on(story) and game.tutorial == null and not game.trial
	lay = {}
	room_index = -1
	bonus = 0
	trans_t = -1.0
	_close()
	queue_redraw()
	if not active:
		return
	cseed = hash([game.run_seed, ch])
	var rng := RandomNumberGenerator.new()
	rng.seed = cseed
	# two of the first four rooms offer a harder way on
	var pool: Array = [0, 1, 2, 3]
	RoomGen._shuffle(pool, rng)
	forks = [pool[0], pool[1]]
	# the remnants spread one to a room; the first room keeps its own
	homes = {}
	# (where the first room keeps remnants of its own, the rest go to the others)
	var rooms: Array = [1, 2, 3, 4, 5] if not RoomGen.STYLE[story].get("first_room", []).is_empty() else [0, 1, 2, 3, 4, 5]
	RoomGen._shuffle(rooms, rng)
	var first: Array = RoomGen.STYLE[story].get("first_room", [])
	# the remnants that need the most wall go to the earliest rooms: a room
	# that finds no wall for one hands it on, and the earlier, the more rooms
	# there are to hand it to (the boss's room shows them all in any case)
	var ws: Array = Lore.walls(story).duplicate()
	var props: Dictionary = RoomGen.STYLE[story].get("props", {})
	ws.sort_custom(func(p, q): return float((props.get(p[0], [0.0]) as Array)[0]) > float((props.get(q[0], [0.0]) as Array)[0]))
	# (the biggest of them: the earlier of the first two rooms drawn)
	if rooms.size() >= 2 and rooms[1] < rooms[0]:
		var tmp = rooms[0]
		rooms[0] = rooms[1]
		rooms[1] = tmp
	for w in ws:
		if first.has(w[0]):
			homes[w[0]] = 0
		elif not rooms.is_empty():
			homes[w[0]] = rooms.pop_front()
	build(0, FIRST_ENTRY.get(story, "L"), false)


# Lay out the room for wave i, entered from `entry`.
func build(i: int, entry: String, risky: bool) -> void:
	room_index = i
	entry_side = entry
	risky_now = risky
	_close()
	gate_hot.clear()
	var hand: int = Chapters.room(game.chapter)
	lay = {}
	if i < Waves.BOSS:
		lay = ahead.get("%d %s" % [i, entry], {})
		if lay.is_empty():
			lay = _make(i, entry)
	ahead.clear()
	# a remnant this room found no wall for goes on to the next room
	if not lay.is_empty():
		for id in homes:
			if homes[id] == i and not (lay.spots as Dictionary).has(id) and i + 1 < Waves.BOSS:
				homes[id] = i + 1
	game.arena.setup(hand, lay)
	# the range's laser fences: this room's, or the hand-made room's
	if lay.is_empty():
		game.lasers.setup(hand)
		game.arms.setup(hand)
		game.maglev.setup(hand, Chapters.story(game.chapter))
		game.arcs.reach = Arcs.ARC_D
		if game.scan_rings.on:
			game.scan_rings.set_spots(ScanRings.SPOTS)
	else:
		game.lasers.set_fences(lay.get("fences", []))
		game.maglev.set_rails(lay.get("maglev", []))
		game.arcs.reach = lay.get("arc_reach", Arcs.ARC_D)
		if game.scan_rings.on:
			game.scan_rings.set_spots(lay.get("rings", []))
		var crate_at := Rect2()
		for ci in (lay.cover as Array).size():
			if lay.kinds[ci] == "reserve":
				crate_at = lay.cover[ci]
		game.arms.set_layout(lay.get("arms", []), crate_at, lay.get("belts", []))
	# the central express's loop belongs to its own (hand-made) room
	if game.bosses_by.has("train") and Chapters.story(game.chapter) == 5:
		var tr = game.bosses_by["train"]
		tr.track_draw = 1.0 if lay.is_empty() else 0.0
		tr.rails.queue_redraw()
	game.lore.queue_redraw()
	queue_redraw()


func _make(i: int, entry: String) -> Dictionary:
	var exits: Array = [{"boss": true}] if i == Waves.BOSS - 1 else ([{}, {"risky": true}] if forks.has(i) else [{}])
	var story := Chapters.story(game.chapter)
	var rem: Array = []
	for w in Lore.walls(story):
		# one that reads off the wall you come in by waits for a later room
		# (the way in crowds that wall); the first room's own stays
		if homes.get(w[0], -1) == i and (RoomGen.NORMAL[entry] != w[2] or RoomGen.STYLE[story].get("first_room", []).has(w[0]) or i + 1 >= Waves.BOSS):
			rem.append(w[0])
	return RoomGen.make(story, i, cseed, entry, exits, rem)


# Where you stand as the room begins.
func start_pos() -> Vector2:
	if not lay.is_empty():
		return lay.start
	var p: Vector2 = {"L": Vector2(200, 540), "R": Vector2(1720, 540), "T": Vector2(960, 190), "B": Vector2(960, 890)}.get(entry_side, Vector2(960, 860))
	return p if game.arena.is_free(p, 20.0) else Vector2(960, 860)


func open_doors() -> void:
	if open or lay.is_empty():
		return
	open = true
	open_t = 0.0
	# lay out now the rooms these doors lead to, so the slide never waits on it
	if room_index + 1 < Waves.BOSS:
		for d: Dictionary in lay.exits:
			var e: String = RoomGen.OPPOSITE[d.side]
			ahead["%d %s" % [room_index + 1, e]] = _make(room_index + 1, e)
	game.sfx.play("windup", 0.55, -6.0)
	game.sfx.play("lit", 0.8, -4.0)


func _close() -> void:
	open = false
	open_k = 0.0
	open_t = 0.0


# A spawn gate on `side` for a group, away from you: where they come in.
# (-1, -1) when the room has no gates (the hand-made rooms).
func gate_for(side: String, pl: Vector2) -> Vector2:
	if not active or lay.is_empty():
		return Vector2(-1, -1)
	var gates: Array = lay.gates
	var pick := -1
	var far := -1.0
	var opts: Array = []
	for k in gates.size():
		var g: Dictionary = gates[k]
		var d := (g.pos as Vector2).distance_to(pl)
		if g.side == side and d > 420.0:
			opts.append(k)
		if d > far:
			far = d
			pick = k
	if not opts.is_empty():
		pick = opts[randi() % opts.size()]
	gate_hot[pick] = 1.0
	var g: Dictionary = gates[pick]
	return (g.pos as Vector2) + (g.n as Vector2) * 70.0


# A remnant's place: where it stands in this room, its hand-made place in the
# hand-made room, or null if this room does not hold it.
func spot(id: String, hand_at: Vector2):
	if not active or lay.is_empty():
		return hand_at
	if lay.spots.has(id):
		return lay.spots[id][0]
	return null


func snapshot() -> Dictionary:
	return {"entry": entry_side, "risky": risky_now, "bonus": bonus}


func step(dt: float) -> void:
	t += dt
	if not active:
		return
	var busy := false
	for k in gate_hot.keys():
		gate_hot[k] = maxf(0.0, gate_hot[k] - dt / 0.9)
		busy = true
		if gate_hot[k] <= 0.0:
			gate_hot.erase(k)
	if trans_t >= 0.0:
		trans_t += dt
		if not swapped and trans_t >= SLIDE * 0.5:
			_swap()
		if trans_t >= SLIDE:
			trans_t = -1.0
			game.cam.add_trauma(0.12)
			game.wave_ctl._next()
		queue_redraw()
		return
	if open:
		open_t += dt
		open_k = minf(1.0, open_k + dt / 0.6)
		busy = true
		if open_k > 0.5 and not game.possess.hosting():
			for d: Dictionary in lay.exits:
				if _at_door(game.player.pos, d):
					_go(d)
					break
	if busy:
		queue_redraw()


func _at_door(p: Vector2, d: Dictionary) -> bool:
	var n: Vector2 = d.n
	var tan := Vector2(absf(n.y), absf(n.x))
	var off := p - (d.pos as Vector2)
	return absf(off.dot(tan)) < float(d.w) / 2.0 - 6.0 and off.dot(n) < Player.R + 16.0


# Through a door: the rounds come home, and the view slides on.
func _go(d: Dictionary) -> void:
	taken = d
	trans_t = 0.0
	swapped = false
	trans_dir = -(d.n as Vector2)
	for b in game.bullets.list:
		if not b.child and b.state != Bullets.FADE:
			game.fx.ring(b.pos, 3.0, 16.0, 0.2, Pal.ink(0.7, 1.8), 1.2)
	game.ammo = mini(game.mag, game.ammo + game.bullets.clear_for_chapter())
	game.sfx.play("home", 0.8, -3.0)
	game.sfx.play("dash", 0.7, -6.0)
	game.player.vel = Vector2.ZERO


func _swap() -> void:
	swapped = true
	var d := taken
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var risky: bool = d.get("risky", false)
	build(room_index + 1, RoomGen.OPPOSITE[d.side], risky)
	if risky:
		game.wave_ctl.harder(room_index)
	game.player.pos = start_pos()
	game.player.vel = Vector2.ZERO
	game.player.position = game.player.pos
	game.player.queue_redraw()
	game.fx.clear_room()
	game.possess.residue.clear()


# The view's offset while sliding: out toward the door, then in from the far side.
func slide() -> Vector2:
	if trans_t < 0.0:
		return Vector2.ZERO
	var span := trans_dir * (Vector2(1920, 1080) * trans_dir.abs()).length()
	var h := SLIDE * 0.5
	if trans_t < h:
		return span * Pal.ease_in(trans_t / h)
	return -span * (1.0 - Pal.ease_out((trans_t - h) / h))


func sliding() -> bool:
	return trans_t >= 0.0


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not active or lay.is_empty():
		return
	var dim: float = 1.0 - 0.45 * game.focus
	for k in (lay.gates as Array).size():
		_draw_gate(lay.gates[k], gate_hot.get(k, 0.0), dim)
	var story := Chapters.story(game.chapter)
	var ep: String = RoomGen.STYLE[story].get("entry_prop", "")
	# the first room's way in is the sealed lab's door, drawn with the yard
	if not (room_index == 0 and lay.spots.has(ep)):
		_draw_door(lay.entry, 0.0, dim, "")
	for d: Dictionary in lay.exits:
		var kind := "boss" if d.boss else ("risky" if d.risky else "on")
		_draw_door(d, open_k, dim, kind if lay.exits.size() > 1 or d.boss else "on")


func _draw_gate(g: Dictionary, hot: float, dim: float) -> void:
	var p: Vector2 = g.pos
	var n: Vector2 = g.n
	var tan := Vector2(absf(n.y), absf(n.x))
	var hw: float = float(g.w) / 2.0
	# a recess in the wall, slatted, that glows red as something comes through
	var a := p - tan * hw
	var b := p + tan * hw
	draw_colored_polygon(PackedVector2Array([a, b, b - n * 14.0, a - n * 14.0]), Color(0.02, 0.02, 0.025, 1.0))
	# (what a gate shows of itself stands a step in from the wall's edge)
	a += n * 8.0
	b += n * 8.0
	for k in 5:
		var q := a.lerp(b, (k + 0.5) / 5.0)
		draw_line(q, q - n * 12.0, Pal.ink(0.28 * dim), 2.0)
	draw_line(a, b, Pal.ink(0.5 * dim), 1.5)
	# a dim mark on the floor in front: they come in here
	var m := p + n * 22.0
	draw_polyline(PackedVector2Array([m - tan * 10.0, m + n * 8.0, m + tan * 10.0]), Pal.red(0.3 * dim, 1.2), 2.0)
	if hot > 0.0:
		# lit for a spawn: a dashed dark-red frame pushing out into the room
		var depth := 44.0 * hot
		var q0 := a + n * depth
		var q1 := b + n * depth
		for seg: Array in [[a, q0], [q0, q1], [q1, b]]:
			var s0: Vector2 = seg[0]
			var s1: Vector2 = seg[1]
			var ln := s0.distance_to(s1)
			var d := 0.0
			while d < ln:
				draw_line(s0.lerp(s1, d / ln), s0.lerp(s1, minf(1.0, (d + 9.0) / ln)), Pal.red(0.65 * hot * dim, 1.2), 2.0)
				d += 15.0
		draw_colored_polygon(PackedVector2Array([a, b, q1, q0]), Pal.red(0.06 * hot * dim, 1.0))


func _draw_door(d: Dictionary, k: float, dim: float, kind: String) -> void:
	var p: Vector2 = d.pos
	var n: Vector2 = d.n
	var tan := Vector2(absf(n.y), absf(n.x))
	var hw: float = float(d.w) / 2.0
	var a := p - tan * hw
	var b := p + tan * hw
	var red := kind == "risky"
	var boss := kind == "boss"
	var ok := Pal.ease_out(k)
	# the opening, dark behind, and the light through it once it opens
	draw_colored_polygon(PackedVector2Array([a, b, b - n * 18.0, a - n * 18.0]), Color(0.015, 0.015, 0.02, 1.0))
	if ok > 0.01:
		var g0 := p - tan * hw * ok
		var g1 := p + tan * hw * ok
		var lc := Pal.red(0.15 * ok * dim, 1.2) if red else Color(1, 1, 1, (0.24 if boss else 0.16) * ok * dim)
		var spill := 150.0 * ok
		draw_polygon(PackedVector2Array([g0, g1, g1 + n * spill + tan * 40.0, g0 + n * spill - tan * 40.0]), PackedColorArray([lc, lc, Color(lc, 0.0), Color(lc, 0.0)]))
		draw_line(g0 - n * 4.0, g1 - n * 4.0, Pal.red(ok * dim, 2.6) if red else Pal.ink(ok * dim, 2.4), 4.0)
		if boss:
			# the way to the boss: a second frame round the door, red-edged
			draw_line(a - tan * 14.0, a - tan * 14.0 + n * 26.0, Pal.red(0.9 * ok * dim, 2.0), 3.0)
			draw_line(b + tan * 14.0, b + tan * 14.0 + n * 26.0, Pal.red(0.9 * ok * dim, 2.0), 3.0)
		# chevrons on the floor, running out through the door
		for c in 3:
			var u := fmod(t * 0.9 + c / 3.0, 1.0)
			var at := p + n * lerpf(120.0, 26.0, u)
			var ca := sin(u * PI) * ok * dim
			var col := Pal.red(0.8 * ca, 2.0) if red else Pal.ink(0.7 * ca, 1.6)
			draw_polyline(PackedVector2Array([at + tan * 16.0 + n * 10.0, at - n * 2.0, at - tan * 16.0 + n * 10.0]), col, 3.0)
	# the two leaves, sliding apart into the wall
	var leaf := hw * (1.0 - ok)
	var lcol := Pal.ink((0.5 if kind != "" else 0.4) * dim)
	if leaf > 1.0:
		draw_line(a, a + tan * leaf, lcol, 6.0)
		draw_line(b, b - tan * leaf, lcol, 6.0)
		if ok < 0.02:
			draw_line(p - n * 3.0, p + n * 3.0, Color(0, 0, 0, 1), 2.0)
	# the posts either side
	draw_line(a, a + n * 16.0, Pal.ink(0.85 * dim), 2.0)
	draw_line(b, b + n * 16.0, Pal.ink(0.85 * dim), 2.0)
	if kind == "":
		return
	# a lamp over a shut way on: red until the room is clear
	if ok < 0.02:
		draw_circle(p + n * 12.0, 3.0, Pal.red(0.8 * dim, 2.0))
		return
	# what lies through it
	var title := Txt.t("door_risky" if kind == "risky" else ("door_boss" if kind == "boss" else "door_on"))
	var sub := Txt.t("door_risky_sub") if kind == "risky" else (Txt.t("door_boss_sub") if boss else Txt.t("door_on_sub"))
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	# the terms run on two lines where there are many of them
	var subs: PackedStringArray = sub.split("\n") if sub != "" else PackedStringArray()
	var sw := 0.0
	for ln in subs:
		sw = maxf(sw, font_s.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var wmax := maxf(tw, sw)
	# past the chevrons, where the room kept its floor clear (RoomGen.label_rect)
	var at := p + n * (190.0 if n.x == 0.0 else 150.0 + wmax / 2.0)
	if d.has("label"):
		at = (d.label as Rect2).position + Vector2(150, 40)
	at.x = clampf(at.x, Arena.ROOM.position.x + wmax / 2.0 + 16.0, Arena.ROOM.end.x - wmax / 2.0 - 16.0)
	at.y = clampf(at.y, Arena.ROOM.position.y + 40.0, Arena.ROOM.end.y - 40.0)
	var ta := ok * dim
	var plate := Rect2(at.x - wmax / 2.0 - 14.0, at.y - 30.0, wmax + 28.0, 42.0 + 22.0 * subs.size())
	draw_rect(plate, Color(0.02, 0.02, 0.025, 0.82 * ta))
	draw_rect(plate, Pal.red(0.6 * ta, 1.4) if red or boss else Pal.ink(0.35 * ta), false, 1.0)
	if boss:
		draw_rect(plate.grow(4.0), Pal.red(0.35 * ta, 1.2), false, 1.0)
	draw_string(font, Vector2(at.x - tw / 2.0, at.y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.red(ta, 2.0) if red else Pal.ink(0.95 * ta, 1.3))
	for j in subs.size():
		var lw := font_s.get_string_size(subs[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font_s, Vector2(at.x - lw / 2.0, at.y + 24.0 + 22.0 * j), subs[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.red(0.9 * ta, 1.3) if boss else Pal.ink(0.8 * ta))
	# under the plate, what to do, while nobody has gone through yet
	var hint := Txt.t("door_hint")
	var hw2 := font_s.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var pulse := 0.4 + 0.25 * sin(t * 4.0)
	# on the plate's far side from the door (a door in the bottom wall: above it, clear of the chevrons)
	var hy := plate.position.y - 8.0 if n.y < -0.5 else plate.end.y + 20.0
	draw_string(font_s, Vector2(at.x - hw2 / 2.0, hy), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink((pulse + 0.3) * ta))
