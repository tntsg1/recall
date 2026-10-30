class_name LoreProps
extends Node2D
# What a chapter's room keeps of the world (design/LORE.md), drawn in the same
# thin lines as everything else: the props on its walls, the remnants that
# surface while a round coming home passes them, the maintenance worker by the
# door at the start of 13th Street, and a seized shell's memory beside it.

const REVEAL_R := 110.0      # a returning round this close wakes a remnant
const HOLD := 2.6
const REMNANT_OFF := {"plate": 80.0, "screen": 120.0, "scrawl": 130.0, "notice": 110.0}

var game
var story := 1
var shows := {}              # remnant id -> 0..1 shown, fading
var hold := {}               # remnant id -> seconds left at full
var memory := ""             # a shell's memory, shown beside it
var memory_t := -1.0
var memory_at: Node2D = null
var memory_fixed := Vector2.INF   # a memory pinned where it was found (a fallen inspector)
var seize_n := 0
var worker_t := -1.0         # the worker by the door, from the chapter's start
var t := 0.0
var font: Font
var mem_layer: Node2D
var mem_shown := false
var tick := 0.0
var focus_last := 0.0
var row_cache := {}
var mirror_tick := 0.0
var shutter_up := 0.0        # chapter 4: the quota window opens once the intake falls
var told := {}               # kinds whose fallen last log was shown this chapter


func _ready() -> void:
	z_index = 2
	z_as_relative = false
	font = Fonts.get_font("Regular")
	mem_layer = Node2D.new()
	mem_layer.z_index = 8
	mem_layer.z_as_relative = false
	mem_layer.draw.connect(_draw_memory)
	add_child(mem_layer)


func start_chapter(ch: int) -> void:
	story = Chapters.story(ch)
	shows.clear()
	hold.clear()
	shutter_up = 0.0
	told.clear()
	memory_fixed = Vector2.INF
	if story == 5 and game.bosses_by.has("train") and not game.rooms.active:
		# the line runs here: its loop is laid from the start
		var tr = game.bosses_by["train"]
		tr.track_draw = 1.0
		tr.rails.queue_redraw()
	memory_t = -1.0
	worker_t = 0.0 if story == 1 else -1.0


func step(dt: float) -> void:
	t += dt
	if worker_t >= 0.0:
		worker_t += dt
		if worker_t > 6.0:
			worker_t = -1.0
	# remnants wake while a round coming home passes them
	for w in _walls():
		var id := "w%d_%s" % [story, w[0]]
		var at: Vector2 = (w[1] as Vector2) + (w[2] as Vector2) * 40.0
		var near := false
		for b in game.bullets.list:
			if (b.state == Bullets.RETURN or b.state == Bullets.PULL) and b.pos.distance_squared_to(at) < REVEAL_R * REVEAL_R:
				near = true
				break
		if near:
			if shows.get(id, 0.0) <= 0.01:
				# the wall answers: a click of current, a flicker where it wakes
				game.sfx.play("lit", 0.62, -5.0)
				game.cam.add_trauma(0.05)
				game.fx.flash(at, 46.0, 0.22, Pal.ink(0.5, 1.6))
				if Lore.find(id):
					game.hud.lore_found()
			hold[id] = HOLD
		var h: float = hold.get(id, 0.0)
		if h > 0.0:
			hold[id] = h - dt
			shows[id] = minf(1.0, shows.get(id, 0.0) + dt / 0.25)
		else:
			shows[id] = maxf(0.0, shows.get(id, 0.0) - dt / 0.6)
	if memory_t >= 0.0:
		memory_t += dt
		if memory_t > 3.4 or not is_instance_valid(memory_at):
			memory_t = -1.0
			memory_fixed = Vector2.INF
		mem_layer.queue_redraw()
	elif mem_shown:
		mem_layer.queue_redraw()
	mem_shown = memory_t >= 0.0
	# the props only flicker: ten redraws a second do; anything moving gets all
	if story == 4 and game.boss is Devourer and game.boss.state == Devourer.DEAD and shutter_up < 1.0:
		shutter_up = minf(1.0, shutter_up + dt / 2.0)
		if shutter_up == dt / 2.0 or shutter_up < dt:
			game.sfx.play("windup", 0.5, -10.0)
	var busy: bool = worker_t >= 0.0 or focus_last != game.focus or (story == 4 and (_full() or (shutter_up > 0.0 and shutter_up < 1.0)))
	for k in shows:
		if shows[k] > 0.0:
			busy = true
			break
	focus_last = game.focus
	# the hall's mirrors carry a slow light: the room redraws twenty times a second
	if story == 2:
		mirror_tick -= dt
		if mirror_tick <= 0.0:
			mirror_tick = 0.05
			game.arena.queue_redraw()
	tick -= dt
	if busy or tick <= 0.0:
		tick = 0.1
		queue_redraw()


# A shell was seized: its memory, once per seizing, cycling through its lines.
# A fallen inspector's last log, once a chapter, where it fell.
func on_inspector_down(at: Vector2) -> void:
	on_kind_down(Enemies.INSPECTOR, at)


# A fallen inspector's or proofreader's last log, once a chapter, where it fell.
func on_kind_down(kind: int, at: Vector2) -> void:
	if told.has(kind):
		return
	told[kind] = true
	var m := Lore.seize_line(story, kind, 0)
	if m.is_empty():
		return
	memory = m.text
	memory_t = 0.0
	memory_at = game.possess
	memory_fixed = at
	if Lore.find(m.id):
		game.hud.lore_found()


func on_seize(shell) -> void:
	var m := Lore.seize_line(story, shell.kind, seize_n)
	seize_n += 1
	if m.is_empty():
		return
	memory = m.text
	memory_t = 0.0
	memory_at = game.possess
	memory_fixed = Vector2.INF
	if Lore.find(m.id):
		game.hud.lore_found()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if story == 1:
		if game.arena.generated:
			# a generated room: its own paint, and its freight drawn by kind
			_draw_yard_paint(dim)
			_draw_yard_cover(dim)
		else:
			_draw_floor(dim)
			_draw_crates(dim)
		# each where this room holds it (the hand-made room: all, in their places)
		var door_at = game.rooms.spot("door", Vector2(80, 790))
		if door_at != null:
			# the door stands in the left wall, read as if the wall were its floor
			draw_set_transform(door_at, PI / 2.0, Vector2.ONE)
			_draw_door(Vector2.ZERO, dim, door_at)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var screen_at = game.rooms.spot("screen", Vector2(80, 300))
		if screen_at != null:
			_draw_screen(screen_at, dim)
		var scrawl_at = game.rooms.spot("graffiti", Vector2(1840, 780))
		if scrawl_at != null:
			_draw_scrawl(scrawl_at, dim)
		var notice_at = game.rooms.spot("notice", Vector2(1500, 70))
		if notice_at != null and shows.get("w1_notice", 0.0) <= 0.01:
			_draw_notice(notice_at, dim)
		if worker_t >= 0.0 and game.wave_ctl.index <= 0 and door_at != null:
			_draw_worker(dim, door_at - Vector2(80, 790))
	elif story == 2:
		var gen: bool = game.arena.generated
		if gen:
			_draw_hall_paint(dim)
			_draw_hall_cover(dim)
		else:
			_draw_seal(Vector2(330, 880), dim)
			_draw_pillars(dim)
		_draw_reflections(dim)
		var queue_at = game.rooms.spot("queue", Vector2(1240, 1010))
		if queue_at != null:
			draw_set_transform(queue_at - Vector2(1240, 1010), 0.0, Vector2.ONE)
			_draw_queue(dim)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# the gates, half again as large, a little clear of the wall
		var gate_at = game.rooms.spot("gate", Vector2(1500, 70))
		if gate_at != null:
			draw_set_transform(gate_at + Vector2(0, 26), 0.0, Vector2(1.5, 1.5))
			_draw_gates(Vector2.ZERO, dim)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_draw_scan(gate_at + Vector2(-114, 98), dim)
		var term_at = game.rooms.spot("terminal", Vector2(80, 300))
		if term_at != null:
			_draw_terminal(term_at, dim, "w2_terminal")
		if not gen:
			_draw_terminal(Vector2(80, 760), dim, "")
		var retire_at = game.rooms.spot("retire", Vector2(1840, 760))
		if retire_at != null and shows.get("w2_retire", 0.0) <= 0.01:
			_draw_wall_notice(retire_at, dim)
	elif story == 3:
		var gen3: bool = game.arena.generated
		if gen3:
			_draw_range_paint(dim)
			_draw_range_cover(dim)
		else:
			_draw_lanes(dim)
			_draw_weapon_crates(dim)
		var log_at = game.rooms.spot("log", Vector2(80, 600))
		if log_at != null:
			_draw_terminal(log_at, dim, "w3_log")
		var tgt_at = game.rooms.spot("target", Vector2(1840, 600))
		if tgt_at != null:
			_draw_target(tgt_at, Vector2(-1, 0), dim, 0)
		if not gen3:
			_draw_target(Vector2(600, 70), Vector2(0, 1), dim, 1)
		var safe_at = game.rooms.spot("safety", Vector2(1490, 1010))
		if safe_at != null and shows.get("w3_safety", 0.0) <= 0.01:
			_draw_floor_notice(safe_at, dim)
	elif story == 5:
		var gen5: bool = game.arena.generated
		var plat_at = game.rooms.spot("yellow", Vector2(960, 1010))
		if plat_at != null:
			# (a generated room keeps a shorter stretch of wall for it: drawn a little narrower)
			var sx := 0.84 if gen5 else 1.0
			draw_set_transform(plat_at - Vector2(960.0 * sx, 1010.0), 0.0, Vector2(sx, 1.0))
			_draw_platform(dim)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if gen5:
			_draw_station_paint(dim)
			_draw_station_cover(dim)
		else:
			_draw_containers(dim)
		var tt_at = game.rooms.spot("timetable", Vector2(80, 300))
		if tt_at != null:
			_draw_terminal(tt_at, dim, "w5_timetable")
	elif story == 6:
		var gen6: bool = game.arena.generated
		if gen6:
			_draw_bureau_paint(dim)
			_draw_bureau_cover(dim)
		else:
			_draw_floor_cables(dim)
			_draw_cabinets(dim)
		var ledger_at = game.rooms.spot("ledger", Vector2(80, 700))
		if ledger_at != null:
			_draw_terminal(ledger_at, dim, "w6_ledger")
		var n6_at = game.rooms.spot("notice", Vector2(1840, 205))
		if n6_at != null and shows.get("w6_notice", 0.0) <= 0.01:
			_draw_wall_notice(n6_at, dim)
		var c6_at = game.rooms.spot("cabinet", Vector2(1840, 700))
		if c6_at != null and shows.get("w6_cabinet", 0.0) <= 0.01:
			_draw_wall_notice(c6_at, dim)
		# the bulb someone wired themselves hangs over the graffiti
		var s6_at = game.rooms.spot("scrawl", Vector2(1320, 70))
		if s6_at != null:
			draw_set_transform(s6_at - Vector2(1320, 70), 0.0, Vector2.ONE)
			_draw_wired_bulb(dim)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif story == 7:
		var gen7: bool = game.arena.generated
		if gen7:
			_draw_thought_cover(dim)
		else:
			_draw_samples(dim)
			_draw_chairs(dim)
		var slogan_at = game.rooms.spot("slogan", Vector2(350, 70))
		if slogan_at != null:
			var shift: Vector2 = slogan_at - Vector2(350, 70)
			if gen7:
				# hung on its wall: the board (240 x 46, centred at 498, 203 as
				# drawn) just off the wall, on the room's side
				var sn: Vector2 = game.rooms.lay.spots.slogan[1]
				var off := 23.0 + 14.0 if absf(sn.y) > 0.5 else 120.0 + 14.0
				shift = (slogan_at as Vector2) + sn * off - Vector2(498, 203)
			draw_set_transform(shift, 0.0, Vector2.ONE)
			_draw_lightboards(dim, gen7)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var mon_at = game.rooms.spot("monitor", Vector2(80, 560))
		if mon_at != null:
			_draw_terminal(mon_at, dim, "w7_monitor")
		var sc7 = game.rooms.spot("scrawl", Vector2(1840, 380))
		if gen7 and sc7 != null:
			_draw_scrawl(sc7, dim)
		var ch7 = game.rooms.spot("chair", Vector2(1840, 690))
		if gen7 and ch7 != null and shows.get("w7_chair", 0.0) <= 0.01:
			_draw_wall_notice(ch7, dim)
	elif story == 10:
		var gen10: bool = game.arena.generated
		if gen10:
			_draw_dock_gen(dim)
		else:
			_draw_yard(dim)
		var sch_at = game.rooms.spot("schedule", Vector2(80, 560))
		if sch_at != null:
			_draw_terminal(sch_at, dim, "w10_schedule")
		var teth_at = game.rooms.spot("tether", Vector2(1840, 530))
		if teth_at != null and shows.get("w10_tether", 0.0) <= 0.01:
			_draw_wall_notice(teth_at, dim)
		var sc10 = game.rooms.spot("scrawl", Vector2(1840, 740))
		if gen10 and sc10 != null:
			_draw_scrawl(sc10, dim)
	elif story == 12:
		_draw_core(dim)
		_draw_terminal(Vector2(80, 560), dim, "w12_board")
		if shows.get("w12_quiet", 0.0) <= 0.01:
			_draw_wall_notice(Vector2(1840, 470), dim)
	elif story == 11:
		_draw_lab(dim)
		_draw_terminal(Vector2(80, 560), dim, "w11_eliminated")
		if shows.get("w11_observe", 0.0) <= 0.01:
			_draw_wall_notice(Vector2(1840, 470), dim)
	elif story == 9:
		var gen9: bool = game.arena.generated
		if gen9:
			_draw_lift_gen(dim)
		else:
			_draw_lift(dim)
		var alt_at = game.rooms.spot("altitude", Vector2(80, 545))
		if alt_at != null:
			_draw_terminal(alt_at, dim, "w9_altitude")
		var rail_at = game.rooms.spot("rail", Vector2(1840, 545))
		if rail_at != null and shows.get("w9_rail", 0.0) <= 0.01:
			_draw_wall_notice(rail_at, dim)
		var sc9 = game.rooms.spot("scrawl", Vector2(1840, 756))
		if gen9 and sc9 != null:
			_draw_scrawl(sc9, dim)
	elif story == 8:
		var gen8: bool = game.arena.generated
		if gen8:
			_draw_archive_cover(dim)
		_draw_deep(dim, gen8)
		var idx_at = game.rooms.spot("index", Vector2(80, 300))
		if idx_at != null:
			_draw_terminal(idx_at, dim, "w8_index")
		var rules_at = game.rooms.spot("rules", Vector2(1840, 476))
		if rules_at != null and shows.get("w8_rules", 0.0) <= 0.01:
			_draw_wall_notice(rules_at, dim)
		var sc8 = game.rooms.spot("scrawl", Vector2(1840, 900))
		if gen8 and sc8 != null:
			_draw_scrawl(sc8, dim)
	elif story == 4:
		var gen4: bool = game.arena.generated
		if gen4:
			_draw_union_paint(dim)
			_draw_union_cover(dim)
		else:
			_draw_stations(dim)
			_draw_presses(dim)
		if game.arms.crate_r.size.x > 0.0:
			_draw_reserve(dim)
		var board_at = game.rooms.spot("board", Vector2(80, 260))
		if board_at != null:
			_draw_terminal(board_at, dim, "w4_board")
		var notice_at4 = game.rooms.spot("notice", Vector2(1500, 70))
		if notice_at4 != null and shows.get("w4_notice", 0.0) <= 0.01:
			_draw_notice(notice_at4, dim)
		if not gen4:
			_draw_floor_wear(dim)
			_draw_quota(dim)
		var scrawl_at4 = game.rooms.spot("scrawl", Vector2(1840, 820))
		if scrawl_at4 != null:
			_draw_scrawl(scrawl_at4, dim)
	var quiet := story == 8 and _archivist_up()
	for w in _walls():
		var id := "w%d_%s" % [story, w[0]]
		var k: float = shows.get(id, 0.0)
		if k <= 0.01:
			continue
		if quiet and (w[0] == "plate" or w[0] == "scrawl"):
			# the floor along the bottom wall is the archivist's to strike
			continue
		_draw_remnant(w, Pal.ease_out(k), dim)


# The chapter's remnants as this room holds them: in a generated room only
# those it was given, each where it was put (Rooms); in the hand-made room all.
func _walls() -> Array:
	var all: Array = Lore.walls(story)
	if not game.rooms.active:
		return all
	var out: Array = []
	for w in all:
		var p = game.rooms.spot(w[0], w[1])
		if p == null:
			continue
		if p == w[1]:
			out.append(w)
		else:
			var c: Array = w.duplicate()
			c[1] = p
			out.append(c)
	return out


# Paint on the yard's floor, worn almost away: the street's number and a lane,
# down in the corner where no words are ever written over it.
func _draw_floor(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var c := Color(1, 1, 1, 0.03 * dim)
	draw_string(sf, Vector2(1440.0, 980.0), "13", HORIZONTAL_ALIGNMENT_LEFT, -1, 170, c)
	var x := 260.0
	while x < 1360.0:
		draw_line(Vector2(x, 900.0), Vector2(x + 40.0, 900.0), c, 6.0)
		x += 80.0
	draw_string(sf, Vector2(1230.0, 888.0), "B3 →", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, c)


# A generated room's floor paint (RoomGen._paint): rails across it with
# their sleepers, a row of parking bays, stains, the bay's number. None of
# it is drawn where cover or a wall block stands.
func _draw_yard_paint(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var solid: Array = game.arena.walls + game.arena.inner
	var cut: Array = []
	for r: Rect2 in solid:
		cut.append(r.grow(10.0))
	for d: Dictionary in lay.get("gates", []) + lay.get("exits", []) + [lay.get("entry", {})]:
		if not d.is_empty():
			cut.append(Rect2(d.pos - Vector2(110, 110), Vector2(220, 220)))
	cut.append_array(lay.get("quiet", []))
	var rail := Color(1, 1, 1, 0.05 * dim)
	var sleeper := Color(1, 1, 1, 0.022 * dim)
	var room := Arena.ROOM
	for rl: Array in lay.get("rails", []):
		var horiz: bool = rl[0]
		var c: float = rl[1]
		var a := Vector2(room.position.x, c) if horiz else Vector2(c, room.position.y)
		var b := Vector2(room.end.x, c) if horiz else Vector2(c, room.end.y)
		var o := Vector2(0, 18) if horiz else Vector2(18, 0)
		for sgn: float in [-1.0, 1.0]:
			for sp: Array in _open_spans(a + o * sgn, b + o * sgn, cut):
				draw_line(sp[0], sp[1], rail, 2.0)
		var along := (b - a).normalized()
		var d := 14.0
		while d < a.distance_to(b):
			var m := a + along * d
			var free := true
			for r: Rect2 in cut:
				if r.grow(6.0).has_point(m):
					free = false
					break
			if free:
				draw_line(m - o * 1.6, m + o * 1.6, sleeper, 7.0)
			d += 30.0
	var bay := Color(1, 1, 1, 0.06 * dim)
	var sf := Fonts.get_font("SemiBold")
	var k := 0
	for r: Rect2 in lay.get("bays", []):
		k += 1
		draw_rect(r.grow(-6.0), bay, false, 3.0)
		draw_string(sf, r.get_center() + Vector2(-14, 8), "%d" % k, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.07 * dim))
	for st: Array in lay.get("stains", []):
		var p: Vector2 = st[0]
		var rad: float = st[1]
		var free := true
		for r: Rect2 in solid:
			if r.grow(rad).has_point(p):
				free = false
		if free:
			draw_set_transform(p, st[2], Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, rad, Color(0, 0, 0, 0.35))
			draw_circle(Vector2(rad * 0.3, 0), rad * 0.45, Color(0, 0, 0, 0.25))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sten: Array = lay.get("stencil", [])
	if not sten.is_empty():
		var c := Color(1, 1, 1, 0.022 * dim)
		draw_string(sf, sten[0], sten[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 150, c)
		draw_string(sf, (sten[0] as Vector2) + Vector2(4, 30), "B3 →", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.05 * dim))


# A generated hall's floor (RoomGen._paint_hall): tile seams, queue lanes
# with their posts, the Union's seal and the hall's number. Not drawn where
# cover or a wall block stands, nor where words are shown.
func _draw_hall_paint(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var room := Arena.ROOM
	var cut: Array = []
	for r: Rect2 in game.arena.walls + game.arena.inner + game.arena.mirrors:
		cut.append(r.grow(6.0))
	var seam := Color(1, 1, 1, 0.018 * dim)
	var tile: float = lay.get("tile", 130.0)
	var x := room.position.x + tile
	while x < room.end.x:
		for sp: Array in _open_spans(Vector2(x, room.position.y), Vector2(x, room.end.y), cut):
			draw_line(sp[0], sp[1], seam, 1.0)
		x += tile
	var y := room.position.y + tile
	while y < room.end.y:
		for sp: Array in _open_spans(Vector2(room.position.x, y), Vector2(room.end.x, y), cut):
			draw_line(sp[0], sp[1], seam, 1.0)
		y += tile
	# queue lanes: two lines a lane apart, posts along them, stopped where words are
	var lane_cut: Array = cut + lay.get("quiet", [])
	for d: Dictionary in lay.get("gates", []) + lay.get("exits", []) + [lay.get("entry", {})]:
		if not d.is_empty():
			lane_cut.append(Rect2(d.pos - Vector2(110, 110), Vector2(220, 220)))
	var lc := Color(1, 1, 1, 0.06 * dim)
	for ln: Array in lay.get("lanes", []):
		var horiz: bool = ln[0]
		var c: float = ln[1]
		var a := Vector2(room.position.x + 40.0, c) if horiz else Vector2(c, room.position.y + 40.0)
		var b := Vector2(room.end.x - 40.0, c) if horiz else Vector2(c, room.end.y - 40.0)
		var o := Vector2(0, 34) if horiz else Vector2(34, 0)
		for sgn: float in [-1.0, 1.0]:
			for sp: Array in _open_spans(a + o * sgn, b + o * sgn, lane_cut):
				var p0: Vector2 = sp[0]
				var p1: Vector2 = sp[1]
				if p0.distance_to(p1) < 220.0:
					continue      # a stub between two cuts reads as litter, not a lane
				var along := (p1 - p0).normalized()
				var d := 0.0
				while d < p0.distance_to(p1) - 12.0:
					draw_line(p0 + along * d, p0 + along * minf(d + 22.0, p0.distance_to(p1)), lc, 3.0)
					d += 34.0
	var sten: Array = lay.get("stencil", [])
	if not sten.is_empty():
		_draw_seal(sten[0], dim)
		var sf := Fonts.get_font("SemiBold")
		draw_string(sf, (sten[0] as Vector2) + Vector2(-46, 196), sten[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.05 * dim))


# A generated hall's furniture by kind: registration pillars (a number, a
# scan strip), benches, kiosks, the registry desk, turnstiles. The mirrors
# are the arena's own.
func _draw_hall_cover(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var kinds: Array = lay.get("kinds", [])
	var sf := Fonts.get_font("SemiBold")
	var cover: Array = lay.get("cover", [])
	var n := 0
	for i in cover.size():
		var r: Rect2 = cover[i]
		var kind: String = kinds[i] if i < kinds.size() else "pillar"
		var long_x := r.size.x >= r.size.y
		var ins := r.grow(-8.0)
		match kind:
			"pillar":
				n += 1
				var pi := r.grow(-10.0)
				draw_string(sf, pi.position + Vector2(4, 16), "REG-%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * dim))
				var sy := pi.position.y + 22.0 + fmod(t * 30.0 + n * 17.0, pi.size.y - 26.0)
				draw_line(Vector2(pi.position.x + 4.0, sy), Vector2(pi.end.x - 4.0, sy), Pal.ink(0.45 * dim, 1.4), 1.5)
				draw_rect(Rect2(pi.position + Vector2(4, 22), Vector2(pi.size.x - 8.0, pi.size.y - 26.0)), Pal.ink(0.18 * dim), false, 1.0)
			"bench":
				# a waiting bench: the backrest a bright bar along one side, the
				# seat behind it, armrests dividing it into places
				var back := Rect2(ins.position, Vector2(ins.size.x, 7)) if long_x else Rect2(ins.position, Vector2(7, ins.size.y))
				draw_rect(back, Pal.ink(0.55 * dim))
				var places := 4 if (r.size.x if long_x else r.size.y) > 150.0 else 2
				for k in range(1, places):
					var u := float(k) / places
					if long_x:
						var xx := lerpf(ins.position.x, ins.end.x, u)
						draw_line(Vector2(xx, ins.position.y + 7.0), Vector2(xx, ins.end.y), Pal.ink(0.38 * dim), 3.0)
					else:
						var yy := lerpf(ins.position.y, ins.end.y, u)
						draw_line(Vector2(ins.position.x + 7.0, yy), Vector2(ins.end.x, yy), Pal.ink(0.38 * dim), 3.0)
			"kiosk":
				# a self-service kiosk: a canopy over it, its lit screen asking for your card
				draw_rect(Rect2(r.position - Vector2(6, 6), Vector2(r.size.x + 12.0, 8)), Pal.ink(0.6 * dim))
				var scr := Rect2(ins.position + ins.size * Vector2(0.15, 0.2), ins.size * Vector2(0.7, 0.45))
				draw_rect(scr, Pal.ink(0.12 * dim))
				draw_rect(scr.grow(2.0), Pal.ink(0.7 * dim, 1.4), false, 1.5)
				var blink := 0.5 + 0.5 * sin(t * 3.0 + i)
				draw_rect(Rect2(scr.position + Vector2(4, 4), Vector2(scr.size.x * 0.5, 3)), Pal.ink(0.5 * blink * dim, 1.4))
				draw_rect(Rect2(Vector2(ins.get_center().x - 10.0, ins.end.y - 12.0), Vector2(20, 4)), Pal.red(0.6 * dim, 1.4))
			"desk":
				# the registry desk, drawn the way it stands: a counter, two screens, the stamp
				var cen := r.get_center()
				var rot := 0.0 if long_x else PI / 2.0
				var lw := maxf(r.size.x, r.size.y) - 16.0
				var lh := minf(r.size.x, r.size.y) - 16.0
				draw_set_transform(cen, rot, Vector2.ONE)
				var o := Vector2(-lw / 2.0, -lh / 2.0)
				draw_line(o + Vector2(0, lh * 0.35), o + Vector2(lw, lh * 0.35), Pal.ink(0.3 * dim), 1.0)
				for k in 2:
					draw_rect(Rect2(o + Vector2(lw * (0.2 + 0.45 * k), 4.0), Vector2(46, 12)), Pal.ink(0.4 * dim), false, 1.5)
				draw_circle(o + Vector2(lw * 0.85, lh * 0.7), 6.0, Pal.red(0.5 * dim, 1.4))
				var dt2 := Txt.t("hall_desk")
				var tw := sf.get_string_size(dt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				# its name along the middle of the counter, on its own dark strip
				var tx := -tw / 2.0
				draw_rect(Rect2(Vector2(tx - 5.0, 2.0), Vector2(tw + 10.0, 20)), Color(0, 0, 0, 0.65))
				draw_string(sf, Vector2(tx, 17.0), dt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.8 * dim))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"turnstile":
				# one lane of the gate: a cabinet each side, the barrier arm across,
				# the lamp over it red (refused) or white (pass)
				var c := ins.get_center()
				var side := Vector2(0, ins.size.y / 2.0 - 3.0) if long_x else Vector2(ins.size.x / 2.0 - 3.0, 0)
				var along := Vector2(ins.size.x / 2.0, 0) if long_x else Vector2(0, ins.size.y / 2.0)
				draw_line(c - side - along * 0.9, c - side + along * 0.9, Pal.ink(0.6 * dim), 5.0)
				draw_line(c + side - along * 0.9, c + side + along * 0.9, Pal.ink(0.6 * dim), 5.0)
				var refused := int(t * 1.5 + i * 0.7) % 4 == 0
				var arm_a := 0.0 if refused else 0.9
				var arm := (side * 1.6).rotated(arm_a)
				draw_line(c - side * 0.8, c - side * 0.8 + arm, Pal.ink(0.5 * dim), 2.0)
				draw_circle(c, 3.5, Pal.red(0.9 * dim, 2.0) if refused else Pal.ink(0.7 * dim, 1.4))


# A generated range's floor (RoomGen._paint_range): numbered firing lanes
# out from a wall with their distance marks, scorch, bullet holes.
func _draw_range_paint(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var sf := Fonts.get_font("SemiBold")
	var cut: Array = []
	for r: Rect2 in game.arena.walls + game.arena.inner:
		cut.append(r.grow(6.0))
	for d: Dictionary in lay.get("gates", []) + lay.get("exits", []) + [lay.get("entry", {})]:
		if not d.is_empty():
			cut.append(Rect2(d.pos - Vector2(110, 110), Vector2(220, 220)))
	var ln: Array = lay.get("lanes3", [])
	if not ln.is_empty():
		var side: String = ln[0]
		var all: Rect2 = ln[1]
		var n: int = ln[2]
		var horiz := side == "T"
		var c := Color(1, 1, 1, 0.045 * dim)
		for k in n + 1:
			var u := float(k) / n
			var a := Vector2(lerpf(all.position.x, all.end.x, u), all.position.y) if horiz else Vector2(all.position.x, lerpf(all.position.y, all.end.y, u))
			var b := a + (Vector2(0, all.size.y) if horiz else Vector2(all.size.x, 0))
			for sp: Array in _open_spans(a, b, cut):
				var p0: Vector2 = sp[0]
				var along := ((sp[1] as Vector2) - p0).normalized()
				var d := 0.0
				while d < p0.distance_to(sp[1]):
					draw_line(p0 + along * d, p0 + along * minf(d + 22.0, p0.distance_to(sp[1])), c, 3.0)
					d += 40.0
		for k in n:
			var u := (k + 0.5) / n
			var at := Vector2(lerpf(all.position.x, all.end.x, u) - 20.0, all.position.y + 52.0) if horiz else Vector2((all.position.x + 24.0) if side == "L" else (all.end.x - 70.0), lerpf(all.position.y, all.end.y, u) + 14.0)
			var free := true
			for r: Rect2 in cut:
				if r.grow(20.0).has_point(at):
					free = false
			if free:
				draw_string(sf, at, "%02d" % (k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.05 * dim))
		# distance marks down the lanes
		var far := Vector2(0, all.size.y) if horiz else Vector2(all.size.x * (1.0 if side == "L" else -1.0), 0)
		var root := Vector2(all.end.x + 12.0, all.position.y) if horiz else Vector2(all.position.x if side == "L" else all.end.x, all.end.y + 26.0)
		for m in [[0.5, "25 m"], [1.0, "50 m"]]:
			var mp: Vector2 = root + far * float(m[0])
			draw_string(sf, mp, m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.08 * dim))
	for sc: Array in lay.get("scorch", []):
		var sp2: Vector2 = sc[0]
		var sr: float = sc[1]
		var free2 := true
		for r: Rect2 in cut:
			if r.grow(sr).has_point(sp2):
				free2 = false
		if free2:
			for j in 4:
				draw_circle(sp2 + Vector2.from_angle(j * 1.9) * sr * 0.4, sr * (0.75 - j * 0.1), Color(0, 0, 0, 0.22 * dim))
	var holes := PackedVector2Array()
	var hn := 0
	for spot: Array in lay.get("holes", []):
		for j in int(spot[2]):
			hn += 1
			var hp: Vector2 = (spot[0] as Vector2) + Vector2.from_angle(hn * 2.39) * float(spot[1]) * sqrt(fmod(hn * 0.618, 1.0))
			var inside := false
			for r: Rect2 in game.arena.walls + game.arena.inner:
				if r.has_point(hp):
					inside = true
			if inside:
				continue
			holes.append(hp - Vector2(2, 2))
			holes.append(hp + Vector2(2, 2))
	if holes.size() > 0:
		draw_multiline(holes, Color(0, 0, 0, 0.55 * dim), 2.0)


# A generated range's things by kind: beam posts, arms crates (as in the
# hand-made range), sandbag walls, target stands, a firing bench, a concrete
# blind, a weapons rack.
func _draw_range_cover(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	# a fence strung from a wall: its emitter is bolted to the wall, as big as a post
	for f: Array in lay.get("fences", []):
		var a: Vector2 = f[0]
		var on_post := false
		for ci in (lay.cover as Array).size():
			if lay.kinds[ci] == "post" and (lay.cover[ci] as Rect2).has_point(a):
				on_post = true
		if on_post:
			continue
		var into := ((f[1] as Vector2) - a).normalized()
		var base := Rect2(a + into * 12.0 - Vector2(18, 18), Vector2(36, 36))
		draw_rect(base, Color(0.03, 0.03, 0.035, 1.0))
		draw_rect(base, Pal.ink(0.5 * dim), false, 1.5)
		draw_rect(Rect2(base.get_center() - Vector2(12, 3) if absf(into.y) > 0.5 else base.get_center() - Vector2(3, 12), Vector2(24, 6) if absf(into.y) > 0.5 else Vector2(6, 24)), Pal.red(0.45 * dim, 1.4))
		draw_circle(base.get_center() + into * 6.0, 5.0, Pal.red(0.7 * dim, 1.8))
	var kinds: Array = lay.get("kinds", [])
	var cover: Array = lay.get("cover", [])
	var sf := Fonts.get_font("SemiBold")
	for i in cover.size():
		var r: Rect2 = cover[i]
		var kind: String = kinds[i] if i < kinds.size() else "arms"
		var long_x := r.size.x >= r.size.y
		var ins := r.grow(-6.0)
		match kind:
			"post":
				# an emitter post: dark, its red band, the lens toward its beam
				draw_rect(ins, Color(0.03, 0.03, 0.035, 1.0))
				draw_rect(ins, Pal.ink(0.35 * dim), false, 1.0)
				draw_rect(Rect2(r.position.x + 6.0, r.get_center().y - 3.0, r.size.x - 12.0, 6.0), Pal.red(0.45 * dim, 1.4))
				draw_circle(r.get_center(), 5.0, Pal.red(0.7 * dim, 1.8))
			"arms":
				draw_colored_polygon(PackedVector2Array([Vector2(r.end.x, r.position.y + 8.0), Vector2(r.end.x + 12.0, r.position.y + 20.0), Vector2(r.end.x + 12.0, r.end.y + 12.0),
					Vector2(r.position.x + 12.0, r.end.y + 12.0), Vector2(r.position.x + 8.0, r.end.y), Vector2(r.end.x, r.end.y)]), Color(0, 0, 0, 0.45 * dim))
				if long_x:
					draw_line(Vector2(ins.get_center().x, ins.position.y), Vector2(ins.get_center().x, ins.end.y), Pal.ink(0.35 * dim), 1.5)
				else:
					draw_line(Vector2(ins.position.x, ins.get_center().y), Vector2(ins.end.x, ins.get_center().y), Pal.ink(0.35 * dim), 1.5)
				draw_string(sf, ins.position + Vector2(8, 20), "PG-IV", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * dim))
				draw_circle(Vector2(ins.end.x - 9.0, ins.position.y + 9.0), 4.0, Pal.ink(0.4 * dim))
				# the upper of a stacked pair: a lip, and the lower one's shadow under it
				if i > 0 and (lay.piece[i] == lay.piece[i - 1]):
					var top_r: Rect2 = cover[i - 1]
					var seam_y := minf(top_r.end.y, r.end.y) if absf(top_r.end.y - r.position.y) < 2.0 or absf(r.end.y - top_r.position.y) < 2.0 else -1.0
					if seam_y > 0.0:
						draw_line(Vector2(r.position.x, seam_y), Vector2(r.end.x, seam_y), Pal.ink(0.8 * dim), 3.0)
						draw_rect(Rect2(r.position.x, seam_y, r.size.x, 8.0), Color(0, 0, 0, 0.4 * dim))
			"sandbag":
				# a wall of sandbags: rounded bags in two courses
				var span := r.size.x if long_x else r.size.y
				var nb := int(span / 34.0)
				for row in 2:
					for k in nb:
						var u := (k + 0.5 + 0.5 * row) / (nb + 0.5)
						var bc := Vector2(lerpf(ins.position.x, ins.end.x, u), lerpf(ins.position.y, ins.end.y, 0.3 + 0.4 * row)) if long_x else Vector2(lerpf(ins.position.x, ins.end.x, 0.3 + 0.4 * row), lerpf(ins.position.y, ins.end.y, u))
						draw_set_transform(bc, 0.0 if long_x else PI / 2.0, Vector2(1.0, 0.55))
						draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 14, Pal.ink(0.38 * dim), 1.5)
						draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"stand":
				# a target stand: its frame and the paper figure on it, holed
				draw_line(ins.position + Vector2(4, ins.size.y * 0.5), Vector2(ins.end.x - 4.0, ins.position.y + ins.size.y * 0.5), Pal.ink(0.5 * dim), 3.0)
				var hc := ins.get_center()
				draw_circle(hc, 8.0, Pal.ink(0.2 * dim))
				draw_arc(hc, 8.0, 0.0, TAU, 12, Pal.red(0.6 * dim, 1.4), 1.5)
			"firing":
				# a firing bench: the table, its rests, the spent casings by it
				draw_line(ins.position + Vector2(0, ins.size.y * 0.5), Vector2(ins.end.x, ins.position.y + ins.size.y * 0.5) if long_x else ins.position + Vector2(ins.size.x * 0.5, ins.size.y), Pal.ink(0.3 * dim), 1.0)
				for k in 3:
					var u := (k + 0.5) / 3.0
					var rp := Vector2(lerpf(ins.position.x, ins.end.x, u), ins.position.y + 10.0) if long_x else Vector2(ins.position.x + 10.0, lerpf(ins.position.y, ins.end.y, u))
					draw_rect(Rect2(rp - Vector2(8, 4), Vector2(16, 8)), Pal.ink(0.45 * dim))
				for k in 5:
					draw_circle(r.end + Vector2(8.0 + k * 5.0, -6.0 - (k % 2) * 6.0), 1.5, Pal.ink(0.5 * dim))
			"bunker":
				# a concrete blind: thick, a firing slit along its face
				draw_rect(ins.grow(-6.0), Pal.ink(0.12 * dim), false, 3.0)
				var slit := Rect2(ins.position + Vector2(ins.size.x * 0.2, 10.0), Vector2(ins.size.x * 0.6, 6)) if long_x else Rect2(ins.position + Vector2(10.0, ins.size.y * 0.2), Vector2(6, ins.size.y * 0.6))
				draw_rect(slit, Color(0, 0, 0, 0.9))
				draw_rect(slit, Pal.ink(0.5 * dim), false, 1.0)
			"rack":
				# a weapons rack: rifles leant in a row, stock down, barrel up
				var span2 := r.size.x if long_x else r.size.y
				var ng := int(span2 / 26.0)
				for k in ng:
					var u := (k + 0.5) / ng
					var a := Vector2(lerpf(ins.position.x, ins.end.x, u), ins.end.y - 4.0) if long_x else Vector2(ins.end.x - 4.0, lerpf(ins.position.y, ins.end.y, u))
					var up := Vector2(10.0, -(ins.size.y - 10.0)) if long_x else Vector2(-(ins.size.x - 10.0), 10.0)
					var b := a + up
					draw_line(a, b, Pal.ink(0.5 * dim), 2.0)
					# the stock, a wedge at the foot; the magazine, a tick part way up
					var sd := up.orthogonal().normalized() * 6.0
					# the stock: a solid butt at the foot
					draw_colored_polygon(PackedVector2Array([a - sd * 0.4, a + sd, a + up * 0.3 + sd * 0.5, a + up * 0.3 - sd * 0.3]), Pal.ink(0.55 * dim))
					# the magazine, a short block under the barrel part way up
					draw_colored_polygon(PackedVector2Array([a + up * 0.45, a + up * 0.45 + sd * 1.4, a + up * 0.55 + sd * 1.4, a + up * 0.55]), Pal.ink(0.5 * dim))
				draw_string(sf, ins.position + Vector2(4, 12), "PG-IV ×%d" % ng, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Pal.ink(0.45 * dim))


# A generated union floor: oil worn in where the work goes on (the belts are
# the arms' own to draw).
func _draw_union_paint(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	for st: Array in lay.get("stains", []):
		var p: Vector2 = st[0]
		var rad: float = st[1]
		var free := true
		for r: Rect2 in game.arena.walls + game.arena.inner:
			if r.grow(rad).has_point(p):
				free = false
		if free:
			draw_set_transform(p, st[2], Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, rad, Color(0, 0, 0, 0.3))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# A generated union floor's machines by kind: presses (as in the hand-made
# floor, rams beating at full capacity), stacked rations, work stations, a
# silo, a packing machine. The reserve crate is drawn on its own.
func _draw_union_cover(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var kinds: Array = lay.get("kinds", [])
	var cover: Array = lay.get("cover", [])
	var sf := Fonts.get_font("SemiBold")
	var n := 0
	for i in cover.size():
		var r: Rect2 = cover[i]
		var kind: String = kinds[i] if i < kinds.size() else "press"
		var long_x := r.size.x >= r.size.y
		var ins := r.grow(-7.0)
		match kind:
			"press":
				n += 1
				var hz := PackedVector2Array()
				var x := ins.position.x
				while x < ins.end.x - 6.0:
					hz.append(Vector2(x, ins.end.y))
					hz.append(Vector2(x + 8.0, ins.end.y - 12.0))
					x += 10.0
				draw_multiline(hz, Pal.ink(0.3 * dim), 2.0)
				# the ram, beating on its own clock inside the frame's lower part
				var bed := Rect2(ins.position + Vector2(8, 22), ins.size - Vector2(16, 36))
				var ph := fmod(t * (2.5 if _full() else 0.6) + i * 0.37, 1.0)
				var ram := 1.0 - Pal.ease_out(ph) if ph < 0.5 else (ph - 0.5) * 2.0
				var rr := bed.grow(-bed.size.x * 0.12 - 5.0 * (1.0 - ram))
				draw_rect(rr, Color(0.07, 0.07, 0.08))
				draw_rect(rr, Pal.ink((0.8 if ph < 0.1 else 0.3) * dim, 1.4 if ph < 0.1 else 1.0), false, 2.0)
				# its number on a dark strip across the top of the frame
				var pn := "PR-%02d" % n
				draw_rect(Rect2(ins.position + Vector2(2, 2), Vector2(sf.get_string_size(pn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6.0, 15)), Color(0, 0, 0, 0.45))
				draw_string(sf, ins.position + Vector2(5, 13), pn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.75 * dim))
			"rations":
				# a pallet of ration boxes: four to a layer, the stencil on top
				for k in 4:
					var q := Rect2(ins.position + ins.size * Vector2(0.5 * (k % 2), 0.5 * (k / 2)), ins.size * 0.5).grow(-2.0)
					draw_rect(q, Pal.ink(0.22 * dim), false, 1.0)
				draw_string(sf, ins.get_center() + Vector2(-14, 5), Txt.t("ration"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * dim))
			"station":
				# a work station, and what its worker left on it: a lunch box half
				# eaten (four minutes was not enough), chopsticks across it, a cup
				draw_string(sf, r.position + Vector2(0, -6), Txt.t("station") % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * dim))
				draw_circle(Vector2(ins.end.x - 6.0, ins.end.y - 6.0), 3.5, Pal.red(dim, 2.0) if _full() else Pal.ink(0.25 * dim))
				var lb := ins.get_center() + (Vector2(-14, 6) if long_x else Vector2(0, -4))
				var box := Rect2(lb - Vector2(14, 8), Vector2(28, 16))
				draw_rect(box, Color(0.08, 0.08, 0.085))
				draw_rect(box, Pal.ink(0.6 * dim, 1.2), false, 1.5)
				draw_line(box.position + Vector2(14, 0), box.position + Vector2(14, 16), Pal.ink(0.4 * dim), 1.0)
				draw_circle(box.position + Vector2(7, 8), 4.0, Pal.ink(0.45 * dim))
				draw_line(box.position + Vector2(-4, 20), box.position + Vector2(32, 15), Pal.ink(0.5 * dim), 1.0)
				var cp := lb + (Vector2(34, 0) if long_x else Vector2(0, 26))
				draw_arc(cp, 6.0, 0.0, TAU, 14, Pal.ink(0.6 * dim, 1.2), 1.5)
				draw_arc(cp + Vector2(7, 0), 3.0, -PI / 2.0, PI / 2.0, 6, Pal.ink(0.5 * dim), 1.0)
			"silo":
				# a flour silo seen from above: its rings, the hatch
				var c := r.get_center()
				var rad := r.size.x * 0.42
				draw_arc(c, rad, 0.0, TAU, 32, Pal.ink(0.45 * dim), 2.0)
				# its roof's ribs, the hatch, the ladder up its side, the feed pipe out
				for k in 8:
					var a := TAU * k / 8.0
					draw_line(c + Vector2.from_angle(a) * 14.0, c + Vector2.from_angle(a) * rad, Pal.ink(0.18 * dim), 1.0)
				draw_rect(Rect2(c - Vector2(11, 11), Vector2(22, 22)), Pal.ink(0.55 * dim), false, 1.5)
				draw_line(c + Vector2(-6, -4), c + Vector2(6, -4), Pal.ink(0.55 * dim), 2.0)
				var l0 := c + Vector2(rad - 4.0, -18.0)
				draw_line(l0, l0 + Vector2(0, 36), Pal.ink(0.5 * dim), 1.5)
				draw_line(l0 + Vector2(8, 0), l0 + Vector2(8, 36), Pal.ink(0.5 * dim), 1.5)
				for k in 5:
					draw_line(l0 + Vector2(0, 4 + k * 7), l0 + Vector2(8, 4 + k * 7), Pal.ink(0.45 * dim), 1.0)
				draw_line(c + Vector2(-rad * 0.7, rad * 0.7), r.position + Vector2(-6, r.size.y + 6), Pal.ink(0.4 * dim), 4.0)
				draw_string(sf, r.position + Vector2(0, -6), Txt.t("silo"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * dim))
			"machine":
				# a packing machine: its rollers turning, the belt over them, its name
				var span := r.size.x if long_x else r.size.y
				var nr := int(span / 34.0)
				for k in nr:
					var u := (k + 0.5) / nr
					var cc := Vector2(lerpf(ins.position.x, ins.end.x, u), ins.end.y - 14.0) if long_x else Vector2(ins.end.x - 14.0, lerpf(ins.position.y + 24.0, ins.end.y, u))
					draw_arc(cc, 9.0, 0.0, TAU, 14, Pal.ink(0.4 * dim), 1.5)
					var sp := Vector2.from_angle(t * 4.0 + k) * 9.0
					draw_line(cc, cc + sp, Pal.ink(0.55 * dim), 2.0)
				var pk := Txt.t("packer")
				draw_rect(Rect2(ins.position + Vector2(2, 2), Vector2(sf.get_string_size(pk, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 6.0, 16)), Color(0, 0, 0, 0.7))
				draw_string(sf, ins.position + Vector2(5, 14), pk, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.6 * dim))


# A generated archive's furniture by kind: card-index cabinets (drawers and
# their brass pulls), reading desks (a lamp, an open volume with lines struck
# through), book trolleys.
func _draw_archive_cover(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var kinds: Array = lay.get("kinds", [])
	var cover: Array = lay.get("cover", [])
	for i in cover.size():
		var r: Rect2 = cover[i]
		var kind: String = kinds[i] if i < kinds.size() else "catalog"
		var long_x := r.size.x >= r.size.y
		var ins := r.grow(-6.0)
		match kind:
			"catalog":
				# a card-index cabinet: a grid of small drawers, each with its pull
				for row in 3:
					for col in 3:
						var cell := Rect2(ins.position + ins.size * Vector2(col / 3.0, row / 3.0), ins.size / 3.0).grow(-2.0)
						draw_rect(cell, Pal.ink(0.25 * dim), false, 1.0)
						draw_line(cell.get_center() + Vector2(-3, 2), cell.get_center() + Vector2(3, 2), Pal.ink(0.55 * dim), 1.5)
			"desk8":
				# a reading desk: its lamp's pool, an open volume, its lines struck out
				var lamp := ins.position + Vector2(14, 14)
				draw_texture_rect(Fx.make_glow_texture(), Rect2(lamp - Vector2(40, 40), Vector2(80, 80)), false, Color(1, 1, 1, 0.08 * dim))
				draw_circle(lamp, 5.0, Pal.ink(0.7 * dim, 1.4))
				var book := Rect2(ins.get_center() - Vector2(26, 14), Vector2(52, 28))
				draw_rect(book, Pal.ink(0.12 * dim))
				draw_line(Vector2(book.get_center().x, book.position.y), Vector2(book.get_center().x, book.end.y), Pal.ink(0.4 * dim), 1.0)
				for k in 4:
					var y := book.position.y + 5.0 + k * 6.0
					draw_line(Vector2(book.position.x + 4.0, y), Vector2(book.end.x - 4.0, y), Color(0, 0, 0, 0.9), 3.0)
			"trolley":
				# a book trolley: its spines in a row, wheels at the corners
				var span := r.size.x if long_x else r.size.y
				var nb := int(span / 9.0)
				for k in nb:
					var u := (k + 0.5) / nb
					var a := Vector2(lerpf(ins.position.x, ins.end.x, u), ins.position.y + 4.0) if long_x else Vector2(ins.position.x + 4.0, lerpf(ins.position.y, ins.end.y, u))
					var b := a + (Vector2(0, ins.size.y - 8.0 - (k % 3) * 4.0) if long_x else Vector2(ins.size.x - 8.0 - (k % 3) * 4.0, 0))
					draw_line(a, b, Pal.ink(0.3 * dim), 2.0)
				for q: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
					draw_circle(q, 3.0, Pal.ink(0.5 * dim))


# A generated room of the bureau of thought by kind: mood-sample cabinets,
# amps pumping on the beat, synchronisation chairs (helmet over the seat,
# a fixed smile under it where someone sits), the operators' console.
func _draw_thought_cover(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var kinds: Array = lay.get("kinds", [])
	var cover: Array = lay.get("cover", [])
	var sf := Fonts.get_font("SemiBold")
	var beat_k := 1.0 - clampf(game.sfx.beat_frac() / 0.3, 0.0, 1.0)
	for i in cover.size():
		var r: Rect2 = cover[i]
		var kind: String = kinds[i] if i < kinds.size() else "sample"
		var long_x := r.size.x >= r.size.y
		var ins := r.grow(-6.0)
		match kind:
			"sample":
				# a sample cabinet: jars of bottled mood, their levels, the label
				for k in 3:
					var jc := Vector2(lerpf(ins.position.x + 12.0, ins.end.x - 12.0, k / 2.0), ins.get_center().y + 4.0)
					draw_rect(Rect2(jc - Vector2(7, 14), Vector2(14, 28)), Pal.ink(0.4 * dim), false, 1.2)
					var lvl := 0.3 + 0.5 * fmod(i * 0.37 + k * 0.29, 1.0)
					draw_rect(Rect2(jc + Vector2(-5, 12 - 24.0 * lvl), Vector2(10, 24.0 * lvl)), Pal.foe(0.35 * dim, 1.2))
				draw_string(sf, r.position + Vector2(0, -5), Txt.t("mood_sample"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * dim))
			"amp":
				# an amplifier: its speaker cones pump on the beat
				var span := r.size.x if long_x else r.size.y
				var nc := int(span / 34.0)
				for k in nc:
					var u := (k + 0.5) / nc
					var gc := Vector2(lerpf(ins.position.x, ins.end.x, u), ins.get_center().y) if long_x else Vector2(ins.get_center().x, lerpf(ins.position.y, ins.end.y, u))
					draw_arc(gc, 12.0, 0.0, TAU, 16, Pal.ink(0.35 * dim), 1.5)
					draw_circle(gc, 5.0 + 2.0 * beat_k, Pal.ink((0.3 + 0.4 * beat_k) * dim))
			"chair":
				# a synchronisation chair from above: the seat, armrests with straps,
				# the helmet over the head-rest, lit on the beat
				var c := r.get_center()
				draw_rect(Rect2(c - Vector2(26, 22), Vector2(52, 44)), Pal.ink(0.35 * dim), false, 1.5)
				for sx: float in [-1.0, 1.0]:
					draw_line(c + Vector2(sx * 32.0, -16), c + Vector2(sx * 32.0, 18), Pal.ink(0.45 * dim), 3.0)
				var hm := c + Vector2(0, -6)
				draw_circle(hm, 14.0, Color(0.05, 0.05, 0.055))
				draw_arc(hm, 14.0, 0.0, TAU, 18, Pal.ink(0.75 * dim, 1.2), 2.0)
				draw_circle(hm, 3.5, Pal.foe((0.3 + 0.7 * beat_k) * dim, 1.4 + 1.4 * beat_k))
				if i % 3 == 1:
					# someone in it: the smile under the helmet's rim
					draw_arc(hm + Vector2(0, 6), 7.0, PI * 0.2, PI * 0.8, 8, Pal.foe((0.6 + 0.4 * beat_k) * dim, 1.6), 2.0)
				draw_string(sf, r.position + Vector2(0, -5), "NI-%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * dim))
			"console":
				# the operators' console: its tempo on a strip outside it, faders
				# down its length all pushed to "happy"
				draw_string(sf, r.position + Vector2(0, -6), "140 BPM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.foe((0.6 + 0.3 * beat_k) * dim, 1.3))
				var span2 := r.size.x if long_x else r.size.y
				var nf := int((span2 - 20.0) / 18.0)
				for k in nf:
					var u := 10.0 + k * 18.0 + 9.0
					var f0 := Vector2(ins.position.x + u, ins.position.y + 8.0) if long_x else Vector2(ins.position.x + 8.0, ins.position.y + u)
					var f1 := Vector2(ins.position.x + u, ins.end.y - 8.0) if long_x else Vector2(ins.end.x - 8.0, ins.position.y + u)
					draw_line(f0, f1, Pal.ink(0.25 * dim), 1.0)
					var knob := f0.lerp(f1, 0.12)
					draw_rect(Rect2(knob - Vector2(4, 2) if long_x else knob - Vector2(2, 4), Vector2(8, 4) if long_x else Vector2(4, 8)), Pal.ink(0.6 * dim))


# A generated bureau floor: the cables feeding its cover, a voltage stencil.
func _draw_bureau_paint(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var quiet: Array = lay.get("quiet", [])
	# (cut where words are, and where cover or a wall block stands over it)
	var cable_cut: Array = quiet.duplicate()
	for r: Rect2 in game.arena.walls + game.arena.inner:
		cable_cut.append(r.grow(2.0))
	for cb: Array in lay.get("cables", []):
		for k in cb.size() - 1:
			var a: Vector2 = cb[k]
			var b: Vector2 = cb[k + 1]
			if a.distance_to(b) < 2.0:
				continue
			for sp: Array in _open_spans(a, b, cable_cut):
				draw_line(sp[0], sp[1], Color(0.09, 0.09, 0.095), 9.0)
				draw_line(sp[0], sp[1], Pal.ink(0.2 * dim), 1.5)
		# a junction box where it leaves the wall
		var jb: Vector2 = cb[0]
		draw_rect(Rect2(jb - Vector2(12, 12), Vector2(24, 24)), Color(0.08, 0.08, 0.085))
		draw_rect(Rect2(jb - Vector2(12, 12), Vector2(24, 24)), Pal.ink(0.5 * dim), false, 1.5)
	# the districts' meter cabinets: a locked box, the needle at its share, the name
	var sf2 := Fonts.get_font("SemiBold")
	for cab: Array in lay.get("cabinets", []):
		var c: Vector2 = cab[0]
		var n: Vector2 = cab[1]
		var k2: int = cab[2]
		var side := n.orthogonal()
		var box := PackedVector2Array([c - side * 46.0, c + side * 46.0, c + side * 46.0 + n * 34.0, c - side * 46.0 + n * 34.0])
		draw_colored_polygon(box, Color(0.07, 0.07, 0.075))
		box.append(box[0])
		draw_polyline(box, Pal.ink(0.6 * dim), 1.5)
		var dc := c + n * 17.0 - side * 22.0
		draw_arc(dc, 11.0, 0.0, TAU, 16, Pal.ink(0.5 * dim), 1.2)
		var share: float = [1.0, 0.8, 0.005][k2]
		draw_line(dc, dc + Vector2.from_angle(PI + PI * share) * 9.0, Pal.ink(0.85 * dim, 1.2), 1.5)
		var lk := c + n * 17.0 + side * 24.0
		draw_rect(Rect2(lk - Vector2(6, 5), Vector2(12, 11)), Pal.ink(0.5 * dim), false, 1.5)
		var lab: String = Txt.t(GridMaster.CABLE_KEYS[k2]) + " · " + GridMaster.CABLE_SHARE[k2]
		var lw := sf2.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		# its name and share just clear of the box, on the room's side of it
		var lp: Vector2
		if n.x > 0.5:
			lp = Vector2(c.x + 46.0, c.y + 5.0)
		elif n.x < -0.5:
			lp = Vector2(c.x - 46.0 - lw, c.y + 5.0)
		else:
			lp = Vector2(c.x - lw / 2.0, c.y + n.y * 56.0 + 5.0)
		draw_string(sf2, lp, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink((0.95 if k2 == 2 else 0.6) * dim, 1.3 if k2 == 2 else 1.0))
	# 13th Street's own line: the wire looping off the wall, and its lit bulb
	var sw: Array = lay.get("selfwire", [])
	if sw.size() >= 2:
		var wire := PackedVector2Array()
		for q: Vector2 in sw:
			wire.append(q)
		draw_polyline(wire, Pal.ink(0.5 * dim), 1.5)
		var bulb: Vector2 = sw[sw.size() - 1]
		draw_texture_rect(Fx.make_glow_texture(), Rect2(bulb - Vector2(60, 60), Vector2(120, 120)), false, Color(1, 1, 1, 0.14 * dim))
		draw_circle(bulb, 7.0, Pal.ink(0.85 * dim, 1.8))
	var sten: Array = lay.get("stencil", [])
	if not sten.is_empty():
		var sf := Fonts.get_font("SemiBold")
		draw_string(sf, sten[0], sten[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.045 * dim))


# A generated bureau floor's equipment by kind: switch housings, meter
# cabinets (their needles barely off zero), cable drums, battery banks, a
# transformer, a switchboard.
func _draw_bureau_cover(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var kinds: Array = lay.get("kinds", [])
	var cover: Array = lay.get("cover", [])
	var sf := Fonts.get_font("SemiBold")
	for i in cover.size():
		var r: Rect2 = cover[i]
		var kind: String = kinds[i] if i < kinds.size() else "switch"
		var long_x := r.size.x >= r.size.y
		var ins := r.grow(-7.0)
		match kind:
			"switch":
				# a switch housing: its lever, a warning flash, its number
				draw_line(ins.get_center() + Vector2(-10, 8), ins.get_center() + Vector2(10, -10), Pal.ink(0.55 * dim), 3.0)
				draw_circle(ins.get_center() + Vector2(-10, 8), 3.0, Pal.ink(0.6 * dim))
				draw_colored_polygon(PackedVector2Array([ins.position + Vector2(6, 18), ins.position + Vector2(14, 4), ins.position + Vector2(12, 12), ins.position + Vector2(18, 12), ins.position + Vector2(9, 26), ins.position + Vector2(11, 18)]), Pal.ink(0.45 * dim))
				# one number for a pair stood together, outside the pair
				var pair_first: bool = i + 1 < cover.size() and lay.piece[i + 1] == lay.piece[i]
				var pair_second: bool = i > 0 and lay.piece[i - 1] == lay.piece[i]
				if pair_first:
					var both: Rect2 = r.merge(cover[i + 1])
					draw_string(sf, both.position + Vector2(0, -5), "SW-%02d/%02d" % [i + 1, i + 2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.55 * dim))
				elif not pair_second:
					draw_string(sf, r.position + Vector2(0, -5), "SW-%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.55 * dim))
			"meter":
				# a meter cabinet: its dial, the needle all but at zero
				var dc := ins.get_center() - Vector2(0, ins.size.y * 0.15)
				draw_arc(dc, 14.0, PI, TAU, 14, Pal.ink(0.5 * dim), 1.5)
				draw_line(dc, dc + Vector2.from_angle(PI + 0.12) * 12.0, Pal.ink(0.85 * dim, 1.2), 1.5)
				draw_rect(Rect2(ins.position + Vector2(6, ins.size.y - 18.0), Vector2(ins.size.x - 12.0, 10)), Pal.ink(0.25 * dim), false, 1.0)
			"drum":
				# a cable drum seen from above: the reel, the wound cable
				var c := r.get_center()
				draw_arc(c, r.size.x * 0.42, 0.0, TAU, 24, Pal.ink(0.45 * dim), 2.0)
				for k in 4:
					draw_arc(c, r.size.x * (0.34 - k * 0.05), 0.0, TAU, 20, Pal.ink(0.2 * dim), 1.0)
				draw_circle(c, 6.0, Pal.ink(0.5 * dim))
			"battery":
				# a battery bank: cells in a row, terminals on top
				var span := r.size.x if long_x else r.size.y
				var nc := int(span / 28.0)
				for k in nc:
					var u := (k + 0.5) / nc
					var cc := Vector2(lerpf(ins.position.x, ins.end.x, u), ins.get_center().y) if long_x else Vector2(ins.get_center().x, lerpf(ins.position.y, ins.end.y, u))
					draw_rect(Rect2(cc - Vector2(9, 9), Vector2(18, 18)), Pal.ink(0.3 * dim), false, 1.0)
					draw_line(cc + Vector2(-4, -2), cc + Vector2(4, -2), Pal.ink(0.5 * dim), 1.5)
			"transformer":
				# a transformer: its fins along both sides, the bushings on top, the danger plate
				var n2 := int(ins.size.x / 12.0)
				for k in n2:
					var x := ins.position.x + 6.0 + k * 12.0
					draw_line(Vector2(x, ins.position.y), Vector2(x, ins.position.y + 14.0), Pal.ink(0.35 * dim), 2.0)
					draw_line(Vector2(x, ins.end.y - 14.0), Vector2(x, ins.end.y), Pal.ink(0.35 * dim), 2.0)
				for k in 3:
					draw_circle(ins.get_center() + Vector2((k - 1) * 30.0, 0), 8.0, Pal.ink(0.5 * dim))
				draw_string(sf, ins.position + Vector2(6, ins.size.y * 0.5 + 24.0), Txt.t("hv_danger"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.red(0.6 * dim, 1.0))
			"switchboard":
				# a switchboard: a row of breakers, all but one thrown off
				var span2 := r.size.x if long_x else r.size.y
				var nb := int(span2 / 24.0)
				for k in nb:
					var u := (k + 0.5) / nb
					var bc := Vector2(lerpf(ins.position.x, ins.end.x, u), ins.get_center().y) if long_x else Vector2(ins.get_center().x, lerpf(ins.position.y, ins.end.y, u))
					var up := k == nb - 1
					draw_line(bc, bc + (Vector2(0, -10) if up else Vector2(0, 8)), Pal.ink((0.8 if up else 0.35) * dim, 1.2 if up else 1.0), 3.0)


# A generated concourse floor: way-arrows for the line.
func _draw_station_paint(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	for ar: Array in game.rooms.lay.get("arrows", []):
		var c: Vector2 = ar[0]
		var dirx: float = ar[1]
		var col := Color(1, 1, 1, 0.05 * dim)
		var tip := c + Vector2(90.0 * dirx, 0)
		draw_line(c - Vector2(90.0 * dirx, 0), tip, col, 10.0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(22.0 * dirx, 0), tip + Vector2(-10.0 * dirx, -22), tip + Vector2(-10.0 * dirx, 22)]), col)
		draw_string(sf, c + Vector2(-60, 40), Txt.t("line_name"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.06 * dim))


# A generated concourse's things by kind: freight containers (as the
# hand-made platform has them), ticket barriers, station pillars, a signal box.
func _draw_station_cover(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var kinds: Array = lay.get("kinds", [])
	var cover: Array = lay.get("cover", [])
	var sf := Fonts.get_font("SemiBold")
	for i in cover.size():
		var rr: Rect2 = cover[i]
		var kind: String = kinds[i] if i < kinds.size() else "cargo"
		var long_x := rr.size.x >= rr.size.y
		var ins := rr.grow(-6.0)
		match kind:
			"cargo":
				var ribs := PackedVector2Array()
				if long_x:
					var x := ins.position.x + 8.0
					while x < ins.end.x - 4.0:
						ribs.append(Vector2(x, ins.position.y))
						ribs.append(Vector2(x, ins.end.y))
						x += 9.0
				else:
					var y := ins.position.y + 8.0
					while y < ins.end.y - 4.0:
						ribs.append(Vector2(ins.position.x, y))
						ribs.append(Vector2(ins.end.x, y))
						y += 9.0
				draw_multiline(ribs, Pal.ink(0.12 * dim), 1.0)
				draw_string(sf, ins.position + Vector2(4, 14), "CX-%04d" % ((i + 1) * 4127 % 9973), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.55 * dim))
				if long_x:
					draw_string(sf, Vector2(ins.position.x + 4, ins.end.y - 6), Txt.t("cx_dest"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.4 * dim))
			"barrier":
				# a ticket barrier: a cabinet at each end, two flaps reaching for
				# each other across the passage, the card reader on the near cabinet
				var c := ins.get_center()
				var along := Vector2(ins.size.x * 0.5, 0) if long_x else Vector2(0, ins.size.y * 0.5)
				var across := Vector2(0, ins.size.y * 0.5) if long_x else Vector2(ins.size.x * 0.5, 0)
				for sd: float in [-1.0, 1.0]:
					var cab := Rect2(c + along * sd * 0.82 - (along.normalized() * 8.0 + across), Vector2.ZERO).expand(c + along * sd * 0.82 + along.normalized() * 8.0 + across).abs()
					draw_rect(cab, Pal.ink(0.4 * dim))
					var flap_from := c + along * sd * 0.62
					var open := 0.5 + 0.5 * sin(t * 0.8 + i)
					draw_line(flap_from, flap_from - along * sd * 0.5 * (1.0 - 0.6 * open), Pal.ink(0.6 * dim), 3.0)
				var reading := fmod(t * 0.6 + i * 0.37, 1.0) < 0.12
				draw_circle(c - along * 0.82 - across * 0.4, 2.5, Pal.red(0.8 * dim, 1.2) if reading else Pal.ink(0.3 * dim))
			"pillar5":
				# a station pillar: the line's roundel on it
				var c2 := rr.get_center()
				draw_arc(c2, 18.0, 0.0, TAU, 20, Pal.ink(0.5 * dim), 3.0)
				draw_line(c2 - Vector2(24, 0), c2 + Vector2(24, 0), Pal.ink(0.5 * dim), 5.0)
			"signal":
				# a signal box: its panel of small white lamps, the one in turn red (no glow)
				for k in 6:
					var lp := ins.position + Vector2(18.0 + (k % 3) * 34.0, 30.0 + (k / 3) * 34.0)
					draw_circle(lp, 5.0, Pal.red(0.7 * dim, 1.0) if k == int(t * 0.7) % 6 else Pal.ink(0.35 * dim))
				draw_string(sf, ins.position + Vector2(4, 14), "SIG-5", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * dim))


# The parts of axis-aligned line a-b outside every rect, as [from, to].
func _open_spans(a: Vector2, b: Vector2, rects: Array) -> Array:
	var horiz := absf(b.y - a.y) < 0.5
	# (either way along the line: the spans run from its low end)
	if (horiz and b.x < a.x) or (not horiz and b.y < a.y):
		var sw := a
		a = b
		b = sw
	var lo := a.x if horiz else a.y
	var hi := b.x if horiz else b.y
	var cuts: Array = []
	for r: Rect2 in rects:
		var g := r.grow(4.0)
		if horiz and (a.y < g.position.y or a.y > g.end.y):
			continue
		if not horiz and (a.x < g.position.x or a.x > g.end.x):
			continue
		cuts.append([g.position.x if horiz else g.position.y, g.end.x if horiz else g.end.y])
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


# A generated room's freight by kind: crates as in the hand-made yard,
# pallets slatted, a container ribbed with its doors at one end, a gantry's
# two steel legs with the beam between them overhead, a buffer stop.
func _draw_yard_cover(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var kinds: Array = lay.get("kinds", [])
	var sf := Fonts.get_font("SemiBold")
	var inner: Array = lay.get("cover", [])
	var gantry: Array = []
	for i in inner.size():
		var r: Rect2 = inner[i]
		var kind: String = kinds[i] if i < kinds.size() else "crate"
		var long_x := r.size.x >= r.size.y
		var ins := r.grow(-8.0)
		var c := Pal.ink(0.2 * dim)
		if kind == "crate_pallet":
			kind = "pallet" if minf(r.size.x, r.size.y) <= 50.0 else "crate"
		match kind:
			"pallet":
				# deck boards along it with gaps between, the three blocks they sit on
				for k in 3:
					var u := (k + 0.5) / 3.0
					var blk := Rect2((Vector2(lerpf(ins.position.x, ins.end.x, u), ins.get_center().y) if long_x else Vector2(ins.get_center().x, lerpf(ins.position.y, ins.end.y, u))) - Vector2(9, 9), Vector2(18, 18))
					draw_rect(blk, Pal.ink(0.12 * dim))
				for k in 3:
					var v := (k + 0.5) / 3.0
					if long_x:
						var y := lerpf(ins.position.y, ins.end.y, v)
						draw_line(Vector2(ins.position.x, y), Vector2(ins.end.x, y), Pal.ink(0.34 * dim), 6.0)
					else:
						var x := lerpf(ins.position.x, ins.end.x, v)
						draw_line(Vector2(x, ins.position.y), Vector2(x, ins.end.y), Pal.ink(0.34 * dim), 6.0)
			"drums":
				# four drums, banded, strapped together
				var q := r.size / 4.0
				for k in 4:
					var dc := r.position + q * Vector2(1 + (k % 2) * 2, 1 + (k / 2) * 2)
					draw_circle(dc, q.x * 0.92, Color(0.05, 0.05, 0.055, 1.0))
					draw_arc(dc, q.x * 0.92, 0.0, TAU, 20, Pal.ink(0.55 * dim), 1.5)
					draw_arc(dc, q.x * 0.55, 0.0, TAU, 16, Pal.ink(0.22 * dim), 1.0)
					draw_circle(dc + Vector2(q.x * 0.35, -q.x * 0.3), 2.5, Pal.ink(0.5 * dim))
				draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Pal.ink(0.3 * dim), 2.0)
			"tarp":
				# a load under a tarp: the folds run from the ropes, the ropes cross it
				# wavy folds across the long way, the cloth sagging between the load's corners
				var span := ins.size.x if long_x else ins.size.y
				var across := ins.size.y if long_x else ins.size.x
				for k in 4:
					var v := (k + 0.5) / 4.0
					var pts := PackedVector2Array()
					for j in 13:
						var u := j / 12.0
						var off := sin(u * TAU * 2.0 + k * 1.3) * 5.0
						var q := Vector2(u * span, v * across + off)
						pts.append(ins.position + (q if long_x else Vector2(q.y, q.x)))
					draw_polyline(pts, Pal.ink(0.24 * dim), 1.5)
				# one rope over it, tied off at the edges
				var r0 := ins.position + (Vector2(span * 0.5, 0) if long_x else Vector2(0, span * 0.5))
				var r1 := r0 + (Vector2(0, across) if long_x else Vector2(across, 0))
				draw_line(r0, r1, Pal.ink(0.6 * dim), 2.5)
				draw_circle(r0, 3.0, Pal.ink(0.7 * dim))
				draw_circle(r1, 3.0, Pal.ink(0.7 * dim))
			"container":
				# ribbed sides, doors and their locking bars at one end
				var span := r.size.x if long_x else r.size.y
				var d := 14.0
				while d < span - 34.0:
					var a := Vector2(r.position.x + d, ins.position.y) if long_x else Vector2(ins.position.x, r.position.y + d)
					var b := Vector2(a.x, ins.end.y) if long_x else Vector2(ins.end.x, a.y)
					draw_line(a, b, Pal.ink(0.16 * dim), 1.0)
					d += 12.0
				var door := Rect2(r.end.x - 30.0, ins.position.y, 22.0, ins.size.y) if long_x else Rect2(ins.position.x, r.end.y - 30.0, ins.size.x, 22.0)
				draw_rect(door, Pal.ink(0.45 * dim), false, 1.5)
				for k in 2:
					if long_x:
						var x := door.position.x + 6.0 + k * 10.0
						draw_line(Vector2(x, door.position.y + 4.0), Vector2(x, door.end.y - 4.0), Pal.ink(0.55 * dim), 1.5)
					else:
						var y := door.position.y + 6.0 + k * 10.0
						draw_line(Vector2(door.position.x + 4.0, y), Vector2(door.end.x - 4.0, y), Pal.ink(0.55 * dim), 1.5)
				if long_x:
					draw_string(sf, ins.position + Vector2(6, 16), "FCU · 13-%02d" % (i * 11 % 97), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * dim))
				else:
					# stood on end: its number runs down its side
					draw_set_transform(ins.position + Vector2(14, 6), PI / 2.0, Vector2.ONE)
					draw_string(sf, Vector2.ZERO, "FCU · 13-%02d" % (i * 11 % 97), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * dim))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"gantry":
				# a steel leg in section, an I-beam: two flanges and the web, bolted
				var fl := 7.0
				draw_rect(Rect2(ins.position, Vector2(ins.size.x, fl)), Pal.ink(0.42 * dim))
				draw_rect(Rect2(Vector2(ins.position.x, ins.end.y - fl), Vector2(ins.size.x, fl)), Pal.ink(0.42 * dim))
				draw_rect(Rect2(Vector2(ins.get_center().x - 3.0, ins.position.y), Vector2(6.0, ins.size.y)), Pal.ink(0.32 * dim))
				for q: Vector2 in [r.position + Vector2(4, 4), Vector2(r.end.x - 4, r.position.y + 4), r.end - Vector2(4, 4), Vector2(r.position.x + 4, r.end.y - 4)]:
					draw_circle(q, 2.5, Pal.ink(0.6 * dim))
				gantry.append(r.get_center())
			"buffer":
				# a buffer stop: hazard stripes and two buffers on its face
				for k in 4:
					var u := (k + 0.5) / 4.0
					var a := ins.position.lerp(Vector2(ins.end.x, ins.position.y), u) if long_x else ins.position.lerp(Vector2(ins.position.x, ins.end.y), u)
					draw_line(a, a + (Vector2(-8, ins.size.y) if long_x else Vector2(ins.size.x, -8)), Pal.ink((0.5 if k % 2 == 0 else 0.22) * dim), 5.0)
				for sgn: float in [-1.0, 1.0]:
					var bp := r.get_center() + (Vector2(r.size.x * 0.28 * sgn, -r.size.y / 2.0 - 3.0) if long_x else Vector2(-r.size.x / 2.0 - 3.0, r.size.y * 0.28 * sgn))
					draw_circle(bp, 6.0, Pal.ink(0.6 * dim))
			"open" when (game.rooms.lay.get("piece", []) as Array).size() > i and _first_of_piece(i):
				# forced open: the lid knocked askew, straw spilling, nothing inside now
				draw_rect(Rect2(ins.position + Vector2(6, -4), ins.size * Vector2(0.9, 0.5)).abs(), Pal.ink(0.32 * dim), false, 1.5)
				for k in 6:
					var sp := ins.get_center() + Vector2(cos(k * 1.7), sin(k * 2.3)) * ins.size.x * 0.3
					draw_line(sp, sp + Vector2(8, 3).rotated(k * 0.9), Pal.ink(0.3 * dim), 1.0)
				draw_string(sf, ins.position + Vector2(4, ins.size.y - 4), "已开封", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.45 * dim))
			_:
				# a crate (as in the hand-made yard)
				draw_line(ins.position, ins.end, c, 1.0)
				draw_line(Vector2(ins.end.x, ins.position.y), Vector2(ins.position.x, ins.end.y), c, 1.0)
				draw_string(sf, ins.position + Vector2(4, 14), "FCU-%02d" % ((i + 1) * 7 % 97), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * dim))
				var o := ins.end
				for j in 3:
					var dd := 8.0 + j * 9.0
					draw_line(o - Vector2(dd, 0), o - Vector2(0, dd), Pal.ink((0.55 if j % 2 == 0 else 0.25) * dim), 4.0)
	# the gantry's beam runs overhead from leg to leg: a truss, and its hook
	if gantry.size() == 2:
		var a: Vector2 = gantry[0]
		var b: Vector2 = gantry[1]
		var side := (b - a).orthogonal().normalized() * 10.0
		var col := Pal.ink(0.42 * dim)
		draw_line(a + side, b + side, col, 2.0)
		draw_line(a - side, b - side, col, 2.0)
		var n := int(a.distance_to(b) / 24.0)
		for k in n:
			var p0 := a.lerp(b, float(k) / n)
			var p1 := a.lerp(b, float(k + 1) / n)
			draw_line(p0 + side * (1.0 if k % 2 == 0 else -1.0), p1 + side * (-1.0 if k % 2 == 0 else 1.0), Pal.ink(0.25 * dim), 1.0)
		var hook := a.lerp(b, 0.5 + 0.12 * sin(t * 0.4))
		draw_rect(Rect2(hook - Vector2(10, 7), Vector2(20, 14)), Color(0.05, 0.05, 0.055, 1.0))
		draw_rect(Rect2(hook - Vector2(10, 7), Vector2(20, 14)), Pal.ink(0.6 * dim), false, 1.5)


# Is cover rect i the first of its piece? (the "open" pair: the first is forced open)
func _first_of_piece(i: int) -> bool:
	var piece: Array = game.rooms.lay.get("piece", [])
	return i == 0 or piece[i - 1] != piece[i]


# The yard's cover is freight left where it stood: braced crates, each with
# its stencilled number, a strip of hazard tape, a dent.
func _draw_crates(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var n := 0
	for r: Rect2 in game.arena.inner:
		n += 1
		var ins := r.grow(-9.0)
		var c := Pal.ink(0.2 * dim)
		draw_line(ins.position, ins.end, c, 1.0)
		draw_line(Vector2(ins.end.x, ins.position.y), Vector2(ins.position.x, ins.end.y), c, 1.0)
		draw_string(sf, ins.position + Vector2(4, 14), "FCU-%02d" % (n * 7 % 97), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * dim))
		# hazard tape across one corner
		var o := ins.end
		for j in 3:
			var d := 8.0 + j * 9.0
			draw_line(o - Vector2(d, 0), o - Vector2(0, d), Pal.ink((0.55 if j % 2 == 0 else 0.25) * dim), 4.0)
		if n % 2 == 0:
			# a dent in its side
			draw_polyline(PackedVector2Array([Vector2(r.position.x, r.position.y + r.size.y * 0.35), Vector2(r.position.x + 7.0, r.position.y + r.size.y * 0.45), Vector2(r.position.x, r.position.y + r.size.y * 0.55)]), Pal.ink(0.6 * dim), 1.5)


func _draw_remnant(w: Array, k: float, dim: float) -> void:
	var full: String = w[4] if Txt.zh else w[5]
	# a sweep writes the words in, letter by letter, in the hand of what holds them
	var n := int(ceil(full.length() * clampf(k * 1.6, 0.0, 1.0)))
	var shown := full.substr(0, n)
	match w[3]:
		"plate":
			_remnant_stencil(w, shown, k, dim)
		"screen", "terminal":
			pass      # screens show it on their own glass
		"plaque":
			_remnant_plaque(w, shown, k, dim)
		"floor":
			_remnant_floor(w, shown, full, k, dim)
		"scrawl":
			_remnant_hand(w, shown, k, dim)
		"crate":
			_remnant_crate(w, shown, full, k, dim)
		"sign":
			pass      # the platform's sign shows it on its own face
		"scrawl_top":
			_remnant_hand_top(w, shown, k, dim)
		_:
			_remnant_print(w, shown, full, k, dim)


# Stencilled beside the door, letters spaced as if sprayed through a plate.
func _remnant_stencil(w: Array, shown: String, k: float, dim: float) -> void:
	var at: Vector2 = (w[1] as Vector2) + (w[2] as Vector2) * 74.0
	var sf := Fonts.get_font("SemiBold")
	# down the wall beside the door's frame, two columns from its top edge
	var x := at.x
	var y0 := at.y - 112.0
	var y := y0
	var i := 0
	for ch in shown:
		if ch == " " or ch == "·":
			continue
		draw_string(sf, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.85 * k * dim, 1.2))
		y += 26.0
		i += 1
		if i == 6:
			x += 30.0
			y = y0


# Sprayed by hand: each letter a little off its line, larger, rough.
func _remnant_hand(w: Array, shown: String, k: float, dim: float) -> void:
	var at: Vector2 = (w[1] as Vector2) + (w[2] as Vector2) * 150.0 + Vector2(0, 54.0)
	var sf := Fonts.get_font("SemiBold")
	var total := sf.get_string_size(shown + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var x := at.x - total
	var i := 0
	for ch in shown:
		var rot := sin(i * 2.7) * 0.12
		var dy := sin(i * 1.9) * 4.0
		draw_set_transform(Vector2(x, at.y + dy), rot, Vector2.ONE)
		draw_string(sf, Vector2.ZERO, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.ink(0.8 * k * dim, 1.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += sf.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 2.0
		i += 1


# Sprayed along the top wall, in the strip between the wall and the track.
func _remnant_hand_top(w: Array, shown: String, k: float, dim: float) -> void:
	var at: Vector2 = (w[1] as Vector2) + Vector2(0, 56.0)
	var sf := Fonts.get_font("SemiBold")
	var x := at.x
	var i := 0
	for ch in shown:
		var rot := sin(i * 2.7) * 0.12
		var dy := sin(i * 1.9) * 4.0
		draw_set_transform(Vector2(x, at.y + dy), rot, Vector2.ONE)
		draw_string(sf, Vector2.ZERO, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.ink(0.8 * k * dim, 1.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += sf.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 2.0
		i += 1


# Printed on the notice's own paper, which unfolds to hold it.
func _remnant_print(w: Array, shown: String, full: String, k: float, dim: float) -> void:
	var at: Vector2 = w[1]
	var size := 16
	var tw := font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var wide := 120.0 + (tw + 30.0 - 120.0) * Pal.ease_out(k)
	var r := Rect2(at.x - 60.0, at.y + 22.0, wide, 72.0)
	r.position.x = minf(r.position.x, Arena.ROOM.end.x - r.size.x - 8.0)
	if (w[2] as Vector2).x < -0.5:
		# on the right wall the paper unfolds leftward from where it hangs
		# (clear of the target sheet when it is the sheet's own words)
		r = Rect2(at.x - (128.0 if w[3] == "sheet" else 24.0) - wide, at.y - 36.0, wide, 72.0)
	elif (w[2] as Vector2).y < -0.5:
		# on the bottom wall it unfolds upward and leftward of its board
		r = Rect2(minf(at.x - wide * 0.5, at.x + 50.0 - wide), at.y - 150.0, wide, 72.0)
	draw_rect(r, Color(0.08, 0.08, 0.085, 1.0))
	draw_rect(r, Pal.ink(0.6 * dim), false, 1.5)
	draw_string(font, r.position + Vector2(15, 30), Txt.t("notice_head"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.45 * k * dim))
	draw_string(font, r.position + Vector2(15, 54), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Pal.ink(0.9 * k * dim, 1.2))
	var on_top := (w[2] as Vector2).y > 0.5
	var sc := Vector2(r.end.x - 24.0, r.position.y + 18.0)
	var sr := 14.0
	draw_arc(sc, sr, 0.0, TAU, 28, Pal.red(0.75 * k * dim, 1.4), 2.5 if on_top else 1.5, false)
	draw_set_transform(sc, -0.3, Vector2.ONE)
	var sw := Txt.t("notice_stamp")
	var ss := 16 if on_top else 13
	draw_string(Fonts.get_font("SemiBold"), Vector2(-Fonts.get_font("SemiBold").get_string_size(sw, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x / 2.0, ss * 0.36), sw, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Pal.red(0.9 * k * dim, 1.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- the asset centre

# Stencilled under the ID gates along the top wall, letters spaced wide.
func _remnant_plaque(w: Array, shown: String, k: float, dim: float) -> void:
	var at: Vector2 = (w[1] as Vector2) + Vector2(0, 150.0)
	var sf := Fonts.get_font("SemiBold")
	var full: String = w[4] if Txt.zh else w[5]
	var step := 22.0
	var x := at.x - full.length() * step / 2.0
	draw_rect(Rect2(x - 14.0, at.y - 22.0, full.length() * step + 28.0, 32.0), Color(0, 0, 0, 0.55 * k))
	for ch in shown:
		draw_string(sf, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.85 * k * dim, 1.2))
		x += step


# Painted on the floor by the queue, worn, in big flat letters.
func _remnant_floor(w: Array, shown: String, full: String, k: float, dim: float) -> void:
	# (a generated room's: higher off the wall, clear of the HUD's bottom bar)
	var at: Vector2 = (w[1] as Vector2) + Vector2(0, -64.0 if game.arena.generated else -36.0)
	var sf := Fonts.get_font("SemiBold")
	var tw := sf.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(sf, Vector2(at.x - tw / 2.0, at.y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.ink(0.8 * k * dim, 1.2))


# A great registration seal painted on the hall's floor, worn faint.
func _draw_seal(c: Vector2, dim: float) -> void:
	var col := Color(1, 1, 1, 0.024 * dim)
	draw_arc(c, 150.0, 0.0, TAU, 64, col, 6.0, false)
	draw_arc(c, 124.0, 0.0, TAU, 64, col, 2.0, false)
	var sf := Fonts.get_font("SemiBold")
	var word := Txt.t("floor_seal")
	draw_string(sf, c + Vector2(-sf.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x / 2.0, 20.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, col)
	for j in 12:
		var a := TAU * j / 12.0
		draw_line(c + Vector2.from_angle(a) * 130.0, c + Vector2.from_angle(a) * 144.0, col, 3.0)


# The hall's two pillars are registration columns: a number, a scan strip.
func _draw_pillars(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var n := 0
	for r: Rect2 in game.arena.inner:
		n += 1
		var ins := r.grow(-10.0)
		draw_string(sf, ins.position + Vector2(4, 16), "REG-%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * dim))
		var sy := ins.position.y + 22.0 + fmod(t * 30.0 + n * 17.0, ins.size.y - 26.0)
		draw_line(Vector2(ins.position.x + 4.0, sy), Vector2(ins.end.x - 4.0, sy), Pal.ink(0.45 * dim, 1.4), 1.5)
		draw_rect(Rect2(ins.position + Vector2(4, 22), Vector2(ins.size.x - 8.0, ins.size.y - 26.0)), Pal.ink(0.18 * dim), false, 1.0)


# The mirrors give back a citizen: as you pass, a faint figure of you shows
# beyond the glass, smiling the way a registered asset should.
func _draw_reflections(dim: float) -> void:
	var p: Vector2 = game.player.pos
	for m: Rect2 in game.arena.mirrors:
		var long_x := m.size.x > m.size.y
		var mirrored := p
		var inside := false
		var dist := 0.0
		if long_x:
			inside = p.x > m.position.x and p.x < m.end.x
			var my := m.get_center().y
			dist = absf(p.y - my)
			mirrored = Vector2(p.x, 2.0 * my - p.y)
		else:
			inside = p.y > m.position.y and p.y < m.end.y
			var mx := m.get_center().x
			dist = absf(p.x - mx)
			mirrored = Vector2(2.0 * mx - p.x, p.y)
		if not inside or dist < 20.0:
			continue
		var a := lerpf(0.14, 0.6, clampf(1.0 - dist / 300.0, 0.0, 1.0)) * dim
		# you, as the glass would rather have you: your outline, a little ring of
		# light about it, and a smile you are not wearing
		draw_circle(mirrored, 26.0, Color(1, 1, 1, a * 0.08))
		draw_arc(mirrored, 26.0, 0.0, TAU, 32, Pal.ink(a), 2.0, false)
		draw_arc(mirrored, 34.0, 0.0, TAU, 40, Pal.ink(a * 0.4), 1.0, false)
		draw_circle(mirrored + Vector2(-9, -7), 2.6, Pal.ink(a))
		draw_circle(mirrored + Vector2(9, -7), 2.6, Pal.ink(a))
		var smile := PackedVector2Array()
		for j in 9:
			var u := lerpf(-1.0, 1.0, j / 8.0)
			smile.append(mirrored + Vector2(u * 13.0, 5.0 + 6.0 * (1.0 - u * u)))
		draw_polyline(smile, Pal.ink(a), 2.0, false)


# A row of ID gates against the top wall: posts, arms, a scanner light each.
func _draw_gates(c: Vector2, dim: float) -> void:
	var n := 4
	var gap := 76.0
	var x0 := c.x - gap * (n - 1) / 2.0
	var y := c.y + 4.0
	draw_line(Vector2(x0 - 50.0, y + 50.0), Vector2(x0 + gap * (n - 1) + 50.0, y + 50.0), Pal.ink(0.3 * dim), 1.5)
	for i in n + 1:
		var px := x0 - gap / 2.0 + i * gap
		draw_rect(Rect2(px - 6.0, y, 12.0, 48.0), Color(0.06, 0.06, 0.065, 1.0))
		draw_rect(Rect2(px - 6.0, y, 12.0, 48.0), Pal.ink(0.5 * dim), false, 1.5)
	for i in n:
		var gx := x0 + i * gap
		# the arm across the lane, and the scanner's eye that blinks red on refusal
		draw_line(Vector2(gx - gap / 2.0 + 8.0, y + 30.0), Vector2(gx + gap / 2.0 - 8.0, y + 30.0), Pal.ink(0.4 * dim), 2.0)
		var on: bool = int(t * 1.5 + i * 0.7) % 4 == 0 or (game.boss is Warden and game.boss.state == Warden.ENTER)
		draw_circle(Vector2(gx - gap / 2.0, y + 12.0), 3.0, Pal.red(0.8 * dim, 2.0) if on else Pal.ink(0.35 * dim))
		draw_line(Vector2(gx - gap / 2.0 + 6.0, y + 12.0), Vector2(gx - gap / 2.0 + 6.0 + 20.0 * (0.5 + 0.5 * sin(t * 3.0 + i)), y + 12.0), Pal.ink(0.25 * dim), 1.0)


# The gates' scanner: a soft fan that sweeps the floor in front of them.
func _draw_scan(o: Vector2, dim: float) -> void:
	var a := PI / 2.0 + 0.55 + sin(t * 0.7) * 0.35
	for layer in [[0.14, 0.03], [0.07, 0.05]]:
		var w: float = layer[0]
		var pts := PackedVector2Array([o, o + Vector2.from_angle(a - w) * 420.0, o + Vector2.from_angle(a + w) * 420.0])
		draw_polygon(pts, PackedColorArray([Color(1, 1, 1, layer[1] * dim), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))


# A registration terminal on the left wall: a kiosk with a screen that
# shows its remnant when a recall sweeps it, "REGISTERING..." otherwise.
func _draw_terminal(c: Vector2, dim: float, id: String) -> void:
	var wide := 40.0 if story >= 9 else 0.0
	var tall := 24.0 if story >= 10 else 0.0
	var body := Rect2(c.x + 4.0, c.y - 80.0 - tall, 130.0 + wide, 160.0 + tall)
	draw_rect(body, Color(0.05, 0.05, 0.055, 1.0))
	draw_rect(body, Pal.ink(0.55 * dim), false, 2.0)
	var scr := Rect2(body.position + Vector2(10, 12), Vector2(110 + wide, 86 + tall))
	# the screen's glow on the wall around it
	draw_texture_rect(Fx.make_glow_texture(), scr.grow(40.0), false, Color(1, 1, 1, 0.07 * dim))
	draw_rect(scr, Color(0.03, 0.03, 0.035, 1.0))
	draw_rect(scr, Pal.ink(0.35 * dim), false, 1.0)
	# keypad and a card slot under the screen
	for j in 3:
		for i in 4:
			draw_rect(Rect2(body.position + Vector2(14 + i * 14, 108 + j * 12), Vector2(9, 7)), Pal.ink(0.22 * dim), false, 1.0)
	draw_line(body.position + Vector2(84, 116), body.position + Vector2(118, 116), Pal.ink(0.45 * dim), 3.0)
	var wake: float = shows.get(id, 0.0) if id != "" else 0.0
	if wake > 0.01:
		var full := ""
		for w in Lore.walls(story):
			if "w%d_%s" % [story, w[0]] == id:
				full = w[4] if Txt.zh else w[5]
		# four rows only fit a little smaller
		var fs := 15
		var rows := _split_rows(full, scr.size.x - 12.0, fs)
		if rows.size() > 3:
			fs = 13
			rows = _split_rows(full, scr.size.x - 10.0, fs)
		var step := 21.0 if fs == 15 else 18.0
		var budget := int(ceil(full.length() * clampf(wake * 1.6, 0.0, 1.0)))
		var yy := scr.position.y + (24.0 if fs == 15 else 19.0)
		for row in rows:
			draw_string(font, Vector2(scr.position.x + 6.0, yy), String(row).substr(0, clampi(budget, 0, String(row).length())), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.92 * wake * dim, 1.4))
			budget -= String(row).length()
			yy += step
	elif id != "" or int(t * 2.0) % 3 != 0:
		var dots := ".".repeat(int(t * 2.0) % 4)
		if story == 9:
			# the lift's altimeter, climbing
			draw_string(font, scr.position + Vector2(8, 26), Txt.t("term_altitude"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.4 * dim))
			draw_string(Fonts.get_font("SemiBold"), scr.position + Vector2(8, 56), Txt.t("altitude") % _alt_str(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.75 * dim, 1.2))
			return
		if story == 12:
			# the board's vote: one member, every time
			draw_string(font, scr.position + Vector2(8, 26), Txt.t("term_board"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.4 * dim))
			draw_string(Fonts.get_font("SemiBold"), scr.position + Vector2(8, 70), "1 : 0", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Pal.ink(0.75 * dim, 1.2))
			draw_string(font, scr.position + Vector2(8, 96), Txt.t("term_board_2"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.35 * dim))
			return
		if story == 11:
			# the anomaly count: nought, as it has been for 87 years
			draw_string(font, scr.position + Vector2(8, 26), Txt.t("term_anomaly"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.4 * dim))
			draw_string(Fonts.get_font("SemiBold"), scr.position + Vector2(8, 74), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Pal.ink(0.75 * dim, 1.2))
			return
		draw_string(font, scr.position + Vector2(8, 30), Txt.t({3: "term_log", 4: "term_output", 5: "term_timetable", 6: "term_power", 7: "term_mood", 8: "term_archive", 10: "term_schedule"}.get(story, "term_idle")) + dots, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.4 * dim))


# The queue: posts with a rope slung between them, and the waiting line.
func _draw_queue(dim: float) -> void:
	var y := 920.0
	var xs := [1000.0, 1100.0, 1200.0, 1300.0, 1400.0, 1500.0]
	for i in xs.size():
		var x: float = xs[i]
		draw_line(Vector2(x, y - 26.0), Vector2(x, y + 8.0), Pal.ink(0.5 * dim), 3.0)
		draw_circle(Vector2(x, y - 26.0), 4.0, Pal.ink(0.5 * dim))
		if i + 1 < xs.size():
			var x2: float = xs[i + 1]
			draw_polyline(PackedVector2Array([Vector2(x, y - 22.0), Vector2((x + x2) / 2.0, y - 12.0), Vector2(x2, y - 22.0)]), Pal.ink(0.4 * dim), 2.0)
	var lx := 990.0
	while lx < 1500.0:
		draw_line(Vector2(lx, y - 48.0), Vector2(lx + 24.0, y - 48.0), Pal.ink(0.25 * dim), 3.0)
		lx += 40.0


# A notice pinned to the right wall.
func _draw_wall_notice(c: Vector2, dim: float) -> void:
	var r := Rect2(c.x - 130.0, c.y - 36.0, 110.0, 72.0)
	draw_rect(r, Color(0.07, 0.07, 0.075, 1.0))
	draw_rect(r, Pal.ink(0.5 * dim), false, 1.5)
	draw_line(r.position + Vector2(10, 14), r.position + Vector2(70, 14), Pal.ink(0.45 * dim), 2.0)
	for j in 4:
		draw_line(r.position + Vector2(10, 28 + j * 9), r.position + Vector2(96 - (j % 2) * 24, 28 + j * 9), Pal.ink(0.22 * dim), 1.0)
	draw_circle(r.position + Vector2(55, 3), 3.0, Pal.ink(0.6 * dim))


# The old-era door R-0 came out of: two heavy panels, one slid half open,
# hazard hatching, the stencilled 00, and a little light still inside.
# `at`: where on the left wall the door stands (it is drawn turned onto it)
func _draw_door(c: Vector2, dim: float, at := Vector2(80, 790)) -> void:
	var w := 260.0
	var h := 46.0
	var top := c.y - h
	var frame := Rect2(c.x - w / 2.0 - 12.0, top - 10.0, w + 24.0, h + 10.0)
	draw_rect(frame, Color(0.03, 0.03, 0.035, 1.0))
	draw_rect(frame, Pal.ink(0.6 * dim), false, 2.0)
	# the inside: dark, a breath of light where the panel stands open
	var gap := Rect2(c.x - 10.0, top + 2.0, 74.0, h - 4.0)
	var glow := 0.10 + 0.05 * sin(t * 1.3)
	draw_rect(gap, Color(1, 1, 1, glow * dim))
	# and that light spills out across the floor in front of the door
	# the door is drawn turned onto the left wall: put the pool where that lands
	var pool_c := at + Vector2(-(top - 40.0), gap.get_center().x)
	draw_set_transform(pool_c, 0.0, Vector2(0.9, 1.5))
	draw_texture_rect(Fx.make_glow_texture(), Rect2(-Vector2(60, 60), Vector2(120, 120)), false, Color(1, 1, 1, glow * 0.9 * dim))
	draw_set_transform(at, PI / 2.0, Vector2.ONE)
	for j in 4:
		draw_line(Vector2(gap.position.x + 8.0 + j * 16.0, gap.position.y + 4.0), Vector2(gap.position.x + 8.0 + j * 16.0, gap.end.y - 4.0), Color(1, 1, 1, 0.05 * dim), 1.0)
	var left := Rect2(c.x - w / 2.0, top, w / 2.0 - 10.0, h)
	var right := Rect2(c.x + 64.0, top, w / 2.0 - 64.0, h)
	for r in [left, right]:
		var rr: Rect2 = r
		draw_rect(rr, Color(0.07, 0.07, 0.075, 1.0))
		draw_rect(rr, Pal.ink(0.55 * dim), false, 1.5)
		# hazard hatching along the panel's foot
		var x := rr.position.x + 4.0
		while x < rr.end.x - 10.0:
			draw_line(Vector2(x, rr.end.y - 3.0), Vector2(x + 8.0, rr.end.y - 13.0), Pal.ink(0.3 * dim), 2.0)
			x += 14.0
	draw_string(Fonts.get_font("SemiBold"), Vector2(left.position.x + 16.0, top + 24.0), "00", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.55 * dim))
	draw_line(Vector2(left.position.x + 50.0, top + 17.0), Vector2(left.end.x - 12.0, top + 17.0), Pal.ink(0.25 * dim), 1.0)


# A propaganda screen on the left wall, cracked, still trying to say its line.
func _draw_screen(c: Vector2, dim: float) -> void:
	var r := Rect2(c.x + 4.0, c.y - 110.0, 150.0, 220.0)
	draw_rect(r, Color(0.04, 0.04, 0.045, 1.0))
	draw_rect(r, Pal.ink(0.6 * dim), false, 2.0)
	draw_rect(r.grow(-4.0), Pal.ink(0.2 * dim), false, 1.0)
	var y := r.position.y + 6.0
	while y < r.end.y - 6.0:
		var on := sin(y * 0.5 + t * 7.0) > 0.7
		draw_line(Vector2(r.position.x + 6.0, y), Vector2(r.end.x - 6.0, y), Pal.ink((0.3 if on else 0.08) * dim), 1.0)
		y += 6.0
	# what is left of its slogan, running down the glass, stuttering
	# the crack, under whatever the glass still says
	draw_polyline(PackedVector2Array([r.position + Vector2(6, 40), r.position + Vector2(40, 88), r.position + Vector2(26, 130), r.position + Vector2(70, 176), r.position + Vector2(58, 220)]), Pal.ink(0.35 * dim, 1.1), 1.5)
	draw_line(r.position + Vector2(40, 88), r.position + Vector2(86, 102), Pal.ink(0.25 * dim, 1.1), 1.0)
	var wake: float = shows.get("w1_screen", 0.0)
	var sf := Fonts.get_font("SemiBold")
	var full: String = Txt.t("screen_full")
	var rows: Array = Array(full.split("\n"))
	# asleep it shows only its first two rows, stuttering; awake, all of them
	var show_n := rows.size() if wake > 0.01 else 1
	var lit := wake > 0.01 or int(t * 3.0) % 5 != 0
	if lit:
		var total_chars := 0
		for k in show_n:
			total_chars += String(rows[k]).length()
		var budget := int(ceil(total_chars * clampf(wake * 1.6, 0.0, 1.0))) if wake > 0.01 else total_chars
		var yy := r.get_center().y - show_n * 13.0 + 18.0
		for k in show_n:
			var row: String = rows[k]
			var part := row.substr(0, clampi(budget, 0, row.length()))
			budget -= row.length()
			var rw := sf.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(sf, Vector2(r.get_center().x - rw / 2.0, yy), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink((0.95 if wake > 0.01 else 0.6) * dim, 1.4))
			yy += 26.0



func _rows(txt: String, width: float, size: int) -> Array:
	var key := "%d|%d|%s" % [size, int(width), txt]
	if row_cache.has(key):
		return row_cache[key]
	var out: Array = []
	var cur := ""
	for ch in txt:
		# closing punctuation stays on the row it ends, even a little past the edge
		if font.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and cur != "" and not "，。：；、！？）」".contains(ch):
			# a number or a latin word moves down whole rather than splitting
			var cut := cur.length()
			while cut > 0 and _word_char(cur[cut - 1]) and _word_char(ch):
				cut -= 1
			if cut == 0:
				cut = cur.length()
			out.append(cur.substr(0, cut))
			cur = cur.substr(cut) + ch
		else:
			cur += ch
	if cur != "":
		out.append(cur)
	row_cache[key] = out
	return out


# rows broken first at the text's own dots, then by width
func _split_rows(txt: String, width: float, size: int) -> Array:
	var out: Array = []
	for part in txt.split(" · "):
		var ci := part.find("：")
		if ci > 0 and ci < part.length() - 1 and font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append_array(_rows(part.substr(0, ci + 1), width, size))
			out.append_array(_rows(part.substr(ci + 1), width, size))
		else:
			out.append_array(_rows(part, width, size))
	return out


func _word_char(c: String) -> bool:
	return (c >= "0" and c <= "9") or (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or c == "-"


# Graffiti on the right wall: the Union's mark, crossed out, the paint running.
func _draw_scrawl(c: Vector2, dim: float) -> void:
	var o := c + Vector2(-60.0, 0.0)
	var col := Pal.ink(0.42 * dim)
	# the mark: a circle with a bar (the Union's seal), sprayed rough
	draw_arc(o, 34.0, 0.0, TAU, 28, col, 4.0, false)
	draw_line(o + Vector2(-24, 0), o + Vector2(24, 0), col, 4.0)
	# the cross through it
	draw_line(o + Vector2(-44, -44), o + Vector2(44, 44), Pal.ink(0.55 * dim), 5.0)
	draw_line(o + Vector2(44, -44), o + Vector2(-44, 44), Pal.ink(0.55 * dim), 5.0)
	# drips
	for j in 4:
		var x := o.x - 30.0 + j * 20.0
		var l := 14.0 + float((j * 7) % 13)
		draw_line(Vector2(x, o.y + 40.0), Vector2(x, o.y + 40.0 + l), Pal.ink(0.3 * dim), 2.0)


# A notice on the top wall, half torn, with the bureau's red stamp.
func _draw_notice(c: Vector2, dim: float) -> void:
	var r := Rect2(c.x - 60.0, c.y + 22.0, 120.0, 72.0)
	draw_rect(r, Color(0.07, 0.07, 0.075, 1.0))
	draw_rect(r, Pal.ink(0.55 * dim), false, 1.5)
	draw_line(r.position + Vector2(10, 12), r.position + Vector2(60, 12), Pal.ink(0.5 * dim), 2.0)
	for j in 4:
		draw_line(r.position + Vector2(10, 24 + j * 7), r.position + Vector2(84 - (j % 2) * 20, 24 + j * 7), Pal.ink(0.22 * dim), 1.0)
	draw_arc(r.position + Vector2(76, 42), 11.0, 0.0, TAU, 20, Pal.red(0.6 * dim, 1.4), 2.0, false)
	# the torn corner
	draw_colored_polygon(PackedVector2Array([r.end - Vector2(22, 0), r.end, r.end - Vector2(0, 18)]), Color(0.02, 0.02, 0.022, 1.0))
	draw_line(r.end - Vector2(22, 0), r.end - Vector2(0, 18), Pal.ink(0.5 * dim), 1.0)


# ---------------------------------------------------------------- the ordnance institute

# The range's floor: firing lanes painted up from the bottom wall, numbered,
# with distance marks, and the test zone under the platform hatched off.
func _draw_lanes(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var c := Color(1, 1, 1, 0.045 * dim)
	for i in 5:
		var x := 520.0 + i * 220.0
		var y := 1000.0
		while y > 730.0:
			draw_line(Vector2(x, y), Vector2(x, y - 22.0), c, 3.0)
			y -= 40.0
	for i in 4:
		draw_string(sf, Vector2(600.0 + i * 220.0, 990.0), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.05 * dim))
	for m in [[732.0, "25 m"], [452.0, "50 m"]]:
		draw_string(sf, Vector2(250.0, m[0]), m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.08 * dim))
	# what the tests leave on the floor: scorch, holes, a spent casing or two
	for sc in [[Vector2(640, 820), 34.0], [Vector2(1290, 880), 26.0], [Vector2(880, 470), 30.0], [Vector2(1460, 560), 22.0], [Vector2(330, 620), 28.0]]:
		var sp: Vector2 = sc[0]
		var sr: float = sc[1]
		# scorch: a few overlapping dark blots, no rim
		for j in 4:
			draw_circle(sp + Vector2.from_angle(j * 1.9) * sr * 0.4, sr * (0.75 - j * 0.1), Color(0, 0, 0, 0.22 * dim))
	# holes cluster where things were aimed: round the targets and the crates
	var holes := PackedVector2Array()
	var spots := [[Vector2(1760, 590), 70.0, 14], [Vector2(600, 210), 60.0, 10], [Vector2(785, 620), 60.0, 8], [Vector2(1135, 620), 60.0, 8], [Vector2(560, 490), 40.0, 6], [Vector2(1340, 490), 40.0, 6]]
	var hn := 0
	for spot in spots:
		for j in int(spot[2]):
			hn += 1
			var hp: Vector2 = spot[0] + Vector2.from_angle(hn * 2.39) * spot[1] * sqrt(fmod(hn * 0.618, 1.0))
			holes.append(hp - Vector2(2, 2))
			holes.append(hp + Vector2(2, 2))
			holes.append(hp + Vector2(-2, 2))
			holes.append(hp + Vector2(2, -2))
	draw_multiline(holes, Pal.ink(0.16 * dim), 1.0)
	for cs: Vector2 in [Vector2(700, 905), Vector2(712, 914), Vector2(1135, 948), Vector2(1020, 780)]:
		draw_line(cs, cs + Vector2(7, 3), Pal.ink(0.3 * dim), 2.0)
	# the middle of the range: a painted firing line with its target boxes,
	# and arrows down the lanes toward the platform
	var fl := PackedVector2Array()
	var fx := 460.0
	while fx < 1460.0:
		fl.append(Vector2(fx, 640.0))
		fl.append(Vector2(fx + 26.0, 640.0))
		fx += 40.0
	for tb in 4:
		var bx := 560.0 + tb * 260.0
		if absf(bx - 785.0) < 70.0 or absf(bx - 1135.0) < 70.0:
			continue
		fl.append_array(PackedVector2Array([Vector2(bx - 34, 462), Vector2(bx + 34, 462), Vector2(bx + 34, 462), Vector2(bx + 34, 514),
			Vector2(bx + 34, 514), Vector2(bx - 34, 514), Vector2(bx - 34, 514), Vector2(bx - 34, 462)]))
	for ax: float in [520.0, 960.0, 1400.0]:
		fl.append_array(PackedVector2Array([Vector2(ax - 12, 600), Vector2(ax, 586), Vector2(ax, 586), Vector2(ax + 12, 600)]))
	draw_multiline(fl, Color(1, 1, 1, 0.06 * dim), 3.0)
	draw_string(sf, Vector2(388.0, 646.0), Txt.t("range_line"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.09 * dim))
	# the target boxes' numbers and the figure each one stood for
	for tb in 4:
		var bx2 := 560.0 + tb * 260.0
		if absf(bx2 - 785.0) < 70.0 or absf(bx2 - 1135.0) < 70.0:
			continue
		draw_string(sf, Vector2(bx2 - 30.0, 456.0), "A-%d" % (tb + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.22 * dim))
		# the figures that stood here, in a queue behind its arrow, and the
		# tick that cleared them
		for qn in 3:
			var qx := bx2 - 22.0 + qn * 13.0
			draw_circle(Vector2(qx, 484.0), 3.5, Color(1, 1, 1, 0.18 * dim))
			draw_line(Vector2(qx, 489.0), Vector2(qx, 506.0), Color(1, 1, 1, 0.18 * dim), 3.0)
		draw_line(Vector2(bx2 - 28, 474), Vector2(bx2 + 8, 474), Color(1, 1, 1, 0.14 * dim), 1.5)
		draw_line(Vector2(bx2 + 8, 474), Vector2(bx2 + 3, 470), Color(1, 1, 1, 0.14 * dim), 1.5)
		draw_line(Vector2(bx2 + 8, 474), Vector2(bx2 + 3, 478), Color(1, 1, 1, 0.14 * dim), 1.5)
		draw_polyline(PackedVector2Array([Vector2(bx2 + 14, 490), Vector2(bx2 + 20, 497), Vector2(bx2 + 30, 480)]), Pal.ink(0.45 * dim), 2.5)
	# the test zone: a hatched band across the floor under the platform
	var y0 := 330.0
	var x := 700.0
	while x < 1220.0:
		draw_line(Vector2(x, y0), Vector2(x + 14.0, y0 - 14.0), Pal.ink(0.1 * dim), 3.0)
		x += 26.0
	draw_line(Vector2(700, y0 + 2.0), Vector2(1220, y0 + 2.0), Pal.ink(0.16 * dim), 1.0)
	# while the testbed vents, its guide marks take this spot
	var zk := 1.0
	if game.boss is Testbed and game.boss.alive():
		zk = 0.0
	if zk <= 0.01:
		return
	var tz := Txt.t("range_zone")
	var tw := sf.get_string_size(tz, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(sf, Vector2(960.0 - tw / 2.0, y0 + 24.0), tz, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.28 * dim * zk))


# The posts the beams hang from, and the crate stacks: arms crates with their
# stencil and seals.
func _draw_weapon_crates(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var n := 0
	for r: Rect2 in game.arena.inner:
		n += 1
		if r.size.x < 60.0:
			# a beam post: a dark column with a red band round it
			draw_rect(r.grow(-6.0), Color(0.03, 0.03, 0.035, 1.0))
			draw_rect(r.grow(-6.0), Pal.ink(0.3 * dim), false, 1.0)
			draw_rect(Rect2(r.position.x + 6.0, r.get_center().y - 3.0, r.size.x - 12.0, 6.0), Pal.ink(0.3 * dim))
			continue
		# an arms crate stack: a shadow off its lower right, two lids, a seam,
		# its stencil and a seal
		draw_colored_polygon(PackedVector2Array([Vector2(r.end.x, r.position.y + 8.0), Vector2(r.end.x + 12.0, r.position.y + 20.0), Vector2(r.end.x + 12.0, r.end.y + 12.0),
			Vector2(r.position.x + 12.0, r.end.y + 12.0), Vector2(r.position.x + 8.0, r.end.y), Vector2(r.end.x, r.end.y)]), Color(0, 0, 0, 0.45 * dim))
		var ins := r.grow(-6.0)
		draw_line(Vector2(ins.get_center().x, ins.position.y), Vector2(ins.get_center().x, ins.end.y), Pal.ink(0.35 * dim), 1.5)
		for half in 2:
			var hr := Rect2(ins.position.x + half * ins.size.x * 0.5, ins.position.y, ins.size.x * 0.5, ins.size.y)
			draw_rect(hr.grow(-5.0), Pal.ink(0.16 * dim), false, 1.0)
			draw_string(sf, hr.position + Vector2(8, 20), "PG-IV", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * dim))
		# the seal on the lid's corner
		draw_circle(Vector2(ins.end.x - 9.0, ins.position.y + 9.0), 4.0, Pal.ink(0.4 * dim))
		var tag := Txt.t("crate_tag")
		draw_string(sf, Vector2(ins.position.x + 8.0, ins.end.y - 8.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.35 * dim))


# A paper target on the wall: a figure standing in a queue, rings over it,
# holes through it. "in" points into the room from the wall it hangs on.
func _draw_target(at: Vector2, inn: Vector2, dim: float, which: int) -> void:
	var c := at + inn * 64.0
	var r := Rect2(c - Vector2(36, 50), Vector2(72, 100))
	if inn.x < -0.5:
		r = Rect2(at.x - 18.0 - 72.0, at.y - 50.0, 72.0, 100.0)
	elif inn.y > 0.5:
		r = Rect2(at.x - 36.0, at.y + 14.0, 72.0, 100.0)
	draw_rect(r, Color(0.09, 0.09, 0.095, 1.0))
	draw_rect(r, Pal.ink(0.55 * dim), false, 1.5)
	var m := r.get_center() + Vector2(0, 4)
	# the figure: head, shoulders, hands at its sides — no weapon
	draw_circle(m + Vector2(0, -26), 10.0, Pal.ink(0.22 * dim))
	draw_polyline(PackedVector2Array([m + Vector2(-22, 34), m + Vector2(-20, -6), m + Vector2(-10, -14), m + Vector2(10, -14), m + Vector2(20, -6), m + Vector2(22, 34)]), Pal.ink(0.3 * dim), 2.0)
	for k in 3:
		draw_arc(m + Vector2(0, -6), 12.0 + k * 11.0, 0.0, TAU, 24, Pal.ink((0.4 - k * 0.1) * dim), 1.0)
	# holes, mostly through the head and chest
	for h in [Vector2(-3, -27), Vector2(4, -8), Vector2(-6, 2), Vector2(9, -22), Vector2(1, 12)]:
		var hp: Vector2 = m + h + Vector2(which * 3.0, -which * 2.0)
		draw_circle(hp, 2.2, Color(0.0, 0.0, 0.0, 1.0))
		draw_arc(hp, 3.0, 0.0, TAU, 8, Pal.ink(0.5 * dim), 1.0)
	draw_string(Fonts.get_font("SemiBold"), r.position + Vector2(6, 14), "C", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * dim))


# The crate's own stencil, sprayed across its lid in rows.
func _remnant_crate(w: Array, shown: String, full: String, k: float, dim: float) -> void:
	var at: Vector2 = w[1]
	var lid := Rect2(at.x - 49.0, at.y + 6.0, 98.0, 52.0)
	for r: Rect2 in game.arena.inner:
		if r.has_point(at + Vector2(0, 10)):
			lid = r.grow(-6.0)
	draw_rect(lid, Color(0.05, 0.05, 0.055, k))
	var sf := Fonts.get_font("SemiBold")
	var rows: Array = []
	for part in full.split(" · "):
		rows.append_array(_rows(part, lid.size.x - 8.0, 13))
	var budget := shown.length()
	var yy := lid.position.y + 16.0
	for row in rows:
		draw_string(sf, Vector2(lid.position.x + 4.0, yy), String(row).substr(0, clampi(budget, 0, String(row).length())), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.75 * k * dim, 1.1))
		budget -= String(row).length()
		yy += 16.0


# A safety board on the bottom wall.
func _draw_floor_notice(c: Vector2, dim: float) -> void:
	var r := Rect2(c.x - 60.0, c.y - 66.0, 120.0, 56.0)
	draw_rect(r, Color(0.07, 0.07, 0.075, 1.0))
	draw_rect(r, Pal.ink(0.5 * dim), false, 1.5)
	# a warning triangle and printed lines
	var tc := r.position + Vector2(22, 30)
	draw_polyline(PackedVector2Array([tc + Vector2(0, -13), tc + Vector2(12, 9), tc + Vector2(-12, 9), tc + Vector2(0, -13)]), Pal.ink(0.6 * dim), 2.0)
	draw_line(tc + Vector2(0, -5), tc + Vector2(0, 2), Pal.ink(0.6 * dim), 2.0)
	for j in 3:
		draw_line(r.position + Vector2(44, 16 + j * 11), r.position + Vector2(108 - (j % 2) * 20, 16 + j * 11), Pal.ink(0.25 * dim), 1.0)


# ---------------------------------------------------------------- the bureau of thought

# Neural-interface chairs along the bottom wall: a seat, a helmet on an arm,
# cables to the wall, a number on the back. Their lamps pulse on the beat.
func _draw_chairs(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var beat_k := 1.0 - clampf(game.sfx.beat_frac() / 0.3, 0.0, 1.0)
	var n := 0
	for x: float in [360.0, 560.0, 1300.0, 1500.0]:
		n += 1
		var c := Vector2(x, 920.0)
		# from above: the seat, a backrest toward the wall, two armrests with straps
		var seat := Rect2(c - Vector2(38, 30), Vector2(76, 60))
		draw_rect(seat, Color(0.06, 0.06, 0.065))
		draw_rect(seat, Pal.ink(0.55 * dim), false, 1.5)
		var back := Rect2(Vector2(seat.position.x - 4.0, seat.end.y - 4.0), Vector2(84, 22))
		draw_rect(back, Color(0.08, 0.08, 0.085))
		draw_rect(back, Pal.ink(0.5 * dim), false, 1.5)
		for sx: float in [-1.0, 1.0]:
			var arm := Rect2(Vector2(c.x + sx * 46.0 - 6.0, seat.position.y + 6.0), Vector2(12, 46))
			draw_rect(arm, Color(0.08, 0.08, 0.085))
			draw_rect(arm, Pal.ink(0.45 * dim), false, 1.2)
			draw_line(arm.position + Vector2(-2, 18), arm.position + Vector2(14, 18), Pal.ink(0.6 * dim), 2.0)
		# the helmet on its arm, held over where a head would rest
		var hm := c + Vector2(0, 8)
		draw_line(Vector2(seat.end.x + 4.0, back.get_center().y), Vector2(seat.end.x + 4.0, c.y - 40.0), Pal.ink(0.45 * dim), 3.0)
		draw_line(Vector2(seat.end.x + 4.0, c.y - 40.0), hm + Vector2(16, -24), Pal.ink(0.45 * dim), 3.0)
		draw_circle(hm, 18.0, Color(0.05, 0.05, 0.055))
		draw_arc(hm, 18.0, 0.0, TAU, 20, Pal.ink(0.8 * dim, 1.2), 2.5)
		for k in 6:
			var a := TAU * k / 6.0
			draw_circle(hm + Vector2.from_angle(a) * 11.0, 1.8, Pal.ink(0.5 * dim))
		draw_circle(hm, 4.0, Pal.foe((0.3 + 0.7 * beat_k) * dim, 1.4 + 1.6 * beat_k))
		if n == 2 or n == 3:
			# someone in it: shoulders, arms on the rests, the helmet down on
			# the head, and below its rim the fixed smile
			var body := PackedVector2Array([c + Vector2(-26, 26), c + Vector2(-24, 6), c + Vector2(-12, -2), c + Vector2(12, -2), c + Vector2(24, 6), c + Vector2(26, 26)])
			draw_polyline(body, Pal.ink(0.75 * dim, 1.2), 2.0)
			draw_line(c + Vector2(-24, 8), c + Vector2(-44, 20), Pal.ink(0.6 * dim), 2.0)
			draw_line(c + Vector2(24, 8), c + Vector2(44, 20), Pal.ink(0.6 * dim), 2.0)
			draw_arc(hm + Vector2(0, 6), 8.0, PI * 0.2, PI * 0.8, 8, Pal.foe((0.6 + 0.4 * beat_k) * dim, 1.6), 2.0)
		draw_string(sf, seat.position + Vector2(5, 14), "NI-%02d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.55 * dim))


# The pillars are crates of mood samples; the bar at the bottom is the amplifier.
func _draw_samples(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var beat_k := 1.0 - clampf(game.sfx.beat_frac() / 0.3, 0.0, 1.0)
	for r: Rect2 in game.arena.inner:
		var ins := r.grow(-6.0)
		if r.size.x > 100.0:
			# the amplifier: speaker grilles that pump on the beat
			for k in 4:
				var gc := Vector2(lerpf(ins.position.x + 16.0, ins.end.x - 16.0, k / 3.0), ins.get_center().y)
				draw_circle(gc, 6.0 + 2.0 * beat_k, Pal.ink((0.3 + 0.4 * beat_k) * dim))
			continue
		var tx := Txt.t("mood_sample")
		var tw := sf.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(sf, Vector2(ins.get_center().x - tw / 2.0, ins.get_center().y + 4.0), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * dim))
		draw_line(ins.position + Vector2(4, 10), Vector2(ins.end.x - 4.0, ins.position.y + 10.0), Pal.ink(0.2 * dim), 1.0)
		draw_line(Vector2(ins.position.x + 4.0, ins.end.y - 10.0), ins.end - Vector2(4, 10), Pal.ink(0.2 * dim), 1.0)


# Light boards along the top wall: the slogan, and a row of faces from the
# mood monitor, every one smiling but one.
# (`slogan_only`: a generated room carries the slogan board, not the faces)
func _draw_lightboards(dim: float, slogan_only := false) -> void:
	var sf := Fonts.get_font("SemiBold")
	var beat_k := 1.0 - clampf(game.sfx.beat_frac() / 0.3, 0.0, 1.0)
	# the slogan board; woken by a recall it runs the slogan in full
	var wake: float = shows.get("w7_slogan", 0.0)
	var r := Rect2(378, 180, 240, 46 + 26.0 * Pal.ease_out(wake))
	draw_rect(r, Color(0.03, 0.03, 0.035))
	draw_rect(r, Pal.foe(0.5 * dim), false, 1.5)
	var tx := Txt.t("slogan_happy")
	var tw := sf.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(sf, Vector2(r.get_center().x - tw / 2.0, r.position.y + 31.0), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.foe((0.65 + 0.35 * beat_k) * dim, 1.2 + 0.5 * beat_k))
	if wake > 0.01:
		var full := ""
		for w in Lore.walls(7):
			if w[0] == "slogan":
				full = (w[4] if Txt.zh else w[5]).split(" · ")[1]
		var n := int(ceil(full.length() * clampf(wake * 1.6, 0.0, 1.0)))
		var fw := sf.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(sf, Vector2(r.get_center().x - fw / 2.0, r.position.y + 62.0), full.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.red(0.9 * wake * dim, 1.4))
	if slogan_only:
		return
	var fr := Rect2(1450, 80, 290, 46)
	draw_rect(fr, Color(0.03, 0.03, 0.035))
	draw_rect(fr, Pal.ink(0.45 * dim), false, 1.5)
	for j in 8:
		var fc := fr.position + Vector2(22.0 + j * 35.0, 23.0)
		draw_arc(fc, 12.0, 0.0, TAU, 16, Pal.ink(0.55 * dim), 1.5)
		draw_circle(fc + Vector2(-4, -3), 1.6, Pal.ink(0.7 * dim))
		draw_circle(fc + Vector2(4, -3), 1.6, Pal.ink(0.7 * dim))
		if j == 5:
			# this one is not smiling; a tear runs down
			draw_arc(fc + Vector2(0, 8), 5.0, PI * 1.15, PI * 1.85, 6, Pal.red(0.8 * dim, 1.4), 1.5)
			draw_line(fc + Vector2(5, -1), fc + Vector2(5, 5), Pal.ink(0.7 * dim, 1.3), 1.5)
		else:
			draw_arc(fc + Vector2(0, 1), 5.0, PI * 0.15, PI * 0.85, 6, Pal.ink(0.7 * dim), 1.5)


# ---------------------------------------------------------------- the energy bureau

# The cables run under the floor plates from each cabinet to the middle: dark
# until the transformer comes up (it draws its own live ones over them).
func _draw_floor_cables(dim: float) -> void:
	var grid_on: bool = game.boss is GridMaster and game.boss.alive()
	if grid_on:
		return
	if game.hud.intro_t >= 0.0:
		dim *= clampf((game.hud.intro_t - 2.2) / 0.6, 0.0, 1.0)
	for k in 3:
		var to: Vector2 = GridMaster.CABINETS[k]
		var n := Vector2(1, 0) if to.x < 100.0 else (Vector2(-1, 0) if to.x > 1800.0 else Vector2(0, -1))
		var b := to + n * 34.0
		var a: Vector2 = GridMaster.HOME + (b - GridMaster.HOME).normalized() * 90.0
		var cw: float = GridMaster.CABLE_W[k]
		draw_line(a, b, Color(0.07, 0.07, 0.075), cw * 1.2 + 2.0)
		draw_line(a, b, Pal.ink(0.22 * dim), 1.0)
		if k == 2:
			# 13th Street's line: a faint pulse now and then, all it ever gets
			var ph := fmod(t * 0.5, 1.0)
			var q := b.lerp(a, ph)
			draw_line(q, q + (a - b).normalized() * 30.0, Pal.foe(0.5 * dim * (1.0 - ph), 1.4), 1.5)
	# the transformer's empty plinth in the middle
	var pr := Rect2(GridMaster.HOME - Vector2(90, 90), Vector2(180, 180))
	draw_rect(pr, Pal.ink(0.12 * dim), false, 2.0)
	var hz := PackedVector2Array()
	var x := pr.position.x + 8.0
	while x < pr.end.x - 8.0:
		hz.append(Vector2(x, pr.end.y - 6.0))
		hz.append(Vector2(x + 10.0, pr.end.y - 16.0))
		x += 16.0
	draw_multiline(hz, Pal.ink(0.12 * dim), 2.0)


# The cabinets on the walls: a locked box, a meter whose needle sits where
# that district's share puts it, and the district's name and share.
func _draw_cabinets(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	for k in 3:
		var c: Vector2 = GridMaster.CABINETS[k]
		var n := Vector2(1, 0) if c.x < 100.0 else (Vector2(-1, 0) if c.x > 1800.0 else Vector2(0, -1))
		var side := n.orthogonal()
		var box := PackedVector2Array([c - side * 46.0, c + side * 46.0, c + side * 46.0 + n * 34.0, c - side * 46.0 + n * 34.0])
		draw_colored_polygon(box, Color(0.07, 0.07, 0.075))
		box.append(box[0])
		draw_polyline(box, Pal.ink(0.6 * dim), 1.5)
		# the meter dial and its needle: the share it is given
		var dc := c + n * 17.0 - side * 22.0
		draw_arc(dc, 11.0, 0.0, TAU, 16, Pal.ink(0.5 * dim), 1.2)
		var share: float = [1.0, 0.8, 0.005][k]
		var na := PI + PI * share
		draw_line(dc, dc + Vector2.from_angle(na) * 9.0, Pal.ink(0.85 * dim, 1.2), 1.5)
		# the lock
		var lk := c + n * 17.0 + side * 24.0
		draw_rect(Rect2(lk - Vector2(6, 5), Vector2(12, 11)), Pal.ink(0.5 * dim), false, 1.5)
		draw_arc(lk - Vector2(0, 5), 4.0, PI, TAU, 8, Pal.ink(0.5 * dim), 1.5)
		# its label, out on the floor in front of it
		var lab: String = Txt.t(GridMaster.CABLE_KEYS[k]) + " · " + GridMaster.CABLE_SHARE[k]
		var lw := sf.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var lp: Vector2 = [Vector2(150, 356), Vector2(1772, 356), Vector2(1378, 994)][k]
		var poor := k == 2
		draw_string(sf, Vector2(lp.x - lw / 2.0, lp.y + 5.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink((0.95 if poor else 0.6) * dim, 1.3 if poor else 1.0))


# Above the graffiti, a bulb on a wire someone ran themselves, lit.
func _draw_wired_bulb(dim: float) -> void:
	var a := Vector2(1290, 70)
	var b := Vector2(1270, 150)
	var wire := PackedVector2Array([a, Vector2(1280, 100), Vector2(1274, 128), b])
	draw_polyline(wire, Pal.ink(0.45 * dim), 1.5)
	draw_circle(b + Vector2(0, 8), 7.0, Pal.ink(0.8 * dim, 1.8))
	draw_texture_rect(Fx.make_glow_texture(), Rect2(b + Vector2(-50, -42), Vector2(100, 100)), false, Color(1, 1, 1, 0.12 * dim))


# ---------------------------------------------------------------- the superconducting line

# 13th Street's platform, between the loop's bottom run and the wall: its
# edge, the yellow line, the station's name board, and the people painted
# where they wait, facing a train that never stops.
func _draw_platform(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var r := Rect2(600, 946, 720, 58)
	var passed := 9.0
	if game.boss is Boss and game.boss.alive():
		passed = game.boss.station_t
	draw_rect(r, Color(0.06, 0.06, 0.065))
	draw_line(r.position, Vector2(r.end.x, r.position.y), Pal.ink(0.6 * dim), 2.0)
	draw_rect(r, Pal.ink(0.3 * dim), false, 1.0)
	# the yellow line, a dashed band a step back from the edge
	var yl := PackedVector2Array()
	var x := r.position.x + 6.0
	while x < r.end.x - 6.0:
		yl.append(Vector2(x, r.position.y + 10.0))
		yl.append(Vector2(x + 18.0, r.position.y + 10.0))
		x += 28.0
	draw_multiline(yl, Pal.ink(0.55 * dim, 1.2), 4.0)
	# the name board at its left end
	var nb := Rect2(Vector2(r.position.x + 12.0, r.position.y + 18.0), Vector2(128, 32))
	draw_rect(nb, Color(0.09, 0.09, 0.095))
	draw_rect(nb, Pal.ink(0.6 * dim), false, 1.5)
	var nm := Txt.t("station_name")
	var nw := sf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(sf, Vector2(nb.get_center().x - nw / 2.0, nb.position.y + 22.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.85 * dim, 1.2))
	# the people waiting, a long queue facing the track; as the express
	# tears past they flinch back from the edge
	var flinch := maxf(0.0, 1.0 - passed / 0.8)
	var figs := PackedVector2Array()
	var poses := [0, 1, 0, 2, 0, 1, 3, 0, 2, 1]
	for j in poses.size():
		var c := Vector2(162.0 + r.position.x + j * 33.0, r.position.y + 36.0)
		c += Vector2(sin(j * 3.1 + passed * 30.0) * 3.0 * flinch, 6.0 * flinch)
		var pose: int = poses[j]
		var head_r := 7.0 if pose != 3 else 5.0
		var hy := -12.0 if pose != 3 else -4.0
		draw_circle(c + Vector2(0, hy), head_r, Pal.ink(0.42 * dim))
		var sw := 11.0 if pose != 3 else 7.0
		figs.append_array(PackedVector2Array([c + Vector2(-sw - 2.0, 16), c + Vector2(-sw, 0), c + Vector2(-sw, 0), c + Vector2(sw, 0), c + Vector2(sw, 0), c + Vector2(sw + 2.0, 16)]))
		if pose == 1:
			# a bag in hand
			figs.append_array(PackedVector2Array([c + Vector2(sw + 3.0, 6), c + Vector2(sw + 3.0, 14), c + Vector2(sw + 3.0, 14), c + Vector2(sw + 10.0, 14), c + Vector2(sw + 10.0, 14), c + Vector2(sw + 10.0, 6)]))
		elif pose == 2:
			# an arm raised, waving at a train that does not stop
			figs.append_array(PackedVector2Array([c + Vector2(sw, 0), c + Vector2(sw + 8.0, -18)]))
	draw_multiline(figs, Pal.ink(0.5 * dim), 2.0)
	# the sign: 本站不停, flashing as it passes; when woken, it runs the rule
	var sg := Rect2(Vector2(r.end.x - 212.0, r.position.y + 8.0), Vector2(200, 46))
	draw_rect(sg, Color(0.02, 0.025, 0.03))
	draw_rect(sg, Pal.ink(0.55 * dim), false, 1.5)
	var wake: float = shows.get("w5_yellow", 0.0)
	if wake > 0.01:
		var full := ""
		for w in Lore.walls(5):
			if w[0] == "yellow":
				full = w[4] if Txt.zh else w[5]
		# the rule in two lines, whole: the second is the one that bites
		var parts := full.split(" · ")
		var budget := int(ceil(full.length() * clampf(wake * 1.6, 0.0, 1.0)))
		for li in parts.size():
			var line: String = parts[li]
			var part := line.substr(0, clampi(budget, 0, line.length()))
			budget -= line.length() + 3
			var lw := sf.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			draw_string(sf, Vector2(sg.get_center().x - lw / 2.0, sg.position.y + 21.0 + li * 21.0), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Pal.ink((0.75 if li == 0 else 1.0) * wake * dim, 1.5))
	else:
		var hot := flinch > 0.0 and fmod(passed * 8.0, 1.0) < 0.5
		var msg := Txt.t("no_stop")
		var mw := sf.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(sf, Vector2(sg.get_center().x - mw / 2.0, sg.position.y + 32.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.foe((1.0 if hot else 0.6) * dim, 2.0 if hot else 1.2))


# The four pillars are freight containers bound for the centre.
func _draw_containers(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var n := 0
	for rr: Rect2 in game.arena.inner:
		n += 1
		var ins := rr.grow(-6.0)
		var ribs := PackedVector2Array()
		var y := ins.position.y + 8.0
		while y < ins.end.y - 4.0:
			ribs.append(Vector2(ins.position.x, y))
			ribs.append(Vector2(ins.end.x, y))
			y += 9.0
		draw_multiline(ribs, Pal.ink(0.12 * dim), 1.0)
		draw_string(sf, ins.position + Vector2(4, 14), "CX-%04d" % (n * 4127 % 9973), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.55 * dim))
		if ins.size.y > 40.0:
			draw_string(sf, Vector2(ins.position.x + 4, ins.end.y - 6), Txt.t("cx_dest"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.4 * dim))
		else:
			var dw := sf.get_string_size(Txt.t("cx_dest"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(sf, Vector2(ins.end.x - dw - 4.0, ins.position.y + 14), Txt.t("cx_dest"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.4 * dim))


# ---------------------------------------------------------------- the production union

# Work stations painted along the belts: a numbered box each, two worn
# footprints where someone stood all day.
func _draw_stations(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var lines := PackedVector2Array()
	var n := 0
	for st: Vector2 in [Vector2(360, 360), Vector2(680, 360), Vector2(1240, 360), Vector2(1560, 360), Vector2(1140, 900), Vector2(1290, 900)]:
		n += 1
		var r := Rect2(st - Vector2(34, 22), Vector2(68, 44))
		lines.append_array(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y), r.end,
			r.end, Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y), r.position]))
		for fs: float in [-1.0, 1.0]:
			var fp := st + Vector2(fs * 9.0, 4.0)
			draw_colored_polygon(PackedVector2Array([fp + Vector2(-4, -9), fp + Vector2(4, -9), fp + Vector2(5, 8), fp + Vector2(-5, 8)]), Color(1, 1, 1, 0.05 * dim))
		draw_string(sf, r.position + Vector2(4, -4), Txt.t("station") % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.12 * dim))
		# each station's lamp: off, or red when the line runs flat out
		var lamp := Vector2(r.end.x - 6.0, r.position.y - 8.0)
		if _full() and (n == 2 or n == 5):
			draw_circle(lamp, 5.0, Pal.red(dim, 2.4))
		else:
			draw_circle(lamp, 4.0, Pal.ink(0.2 * dim))
	draw_multiline(lines, Color(1, 1, 1, 0.07 * dim), 2.0)
	# what the people at these stations left behind: a lunch box half eaten
	# (four minutes was not enough), a cup, a badge on the belt's edge
	for lb: Vector2 in [Vector2(404, 376), Vector2(1604, 376)]:
		var box := Rect2(lb - Vector2(20, 12), Vector2(40, 24))
		draw_rect(box, Color(0.08, 0.08, 0.085))
		draw_rect(box, Pal.ink(0.65 * dim, 1.2), false, 2.0)
		draw_line(box.position + Vector2(20, 0), box.position + Vector2(20, 24), Pal.ink(0.4 * dim), 1.5)
		# half of it left: rice in one side, a few grains of the other
		draw_circle(box.position + Vector2(10, 12), 6.0, Pal.ink(0.45 * dim))
		draw_circle(box.position + Vector2(30, 15), 2.0, Pal.ink(0.35 * dim))
		draw_line(box.position + Vector2(3, 3), box.position + Vector2(14, 3), Pal.ink(0.9 * dim, 1.4), 1.5)
		draw_line(box.position + Vector2(0, -3), box.position + Vector2(36, -18), Pal.ink(0.6 * dim), 3.0)
		# chopsticks laid across, still where they were put down
		draw_line(box.position + Vector2(-6, 30), box.position + Vector2(44, 22), Pal.ink(0.5 * dim), 1.5)
		draw_line(box.position + Vector2(-6, 34), box.position + Vector2(44, 26), Pal.ink(0.5 * dim), 1.5)
	for cp: Vector2 in [Vector2(716, 380), Vector2(1276, 380), Vector2(1172, 920)]:
		draw_circle(cp, 9.0, Color(0.08, 0.08, 0.085))
		draw_arc(cp, 9.0, 0.0, TAU, 18, Pal.ink(0.65 * dim, 1.2), 2.0)
		draw_arc(cp + Vector2(10, 0), 4.5, -PI / 2.0, PI / 2.0, 8, Pal.ink(0.5 * dim), 1.5)
		draw_arc(cp, 5.0, PI * 1.1, PI * 1.5, 6, Pal.ink(0.8 * dim, 1.4), 1.5)
		# a wisp of steam: still warm, nobody here to drink it
		var wisp := PackedVector2Array()
		for q in 6:
			wisp.append(cp + Vector2(sin(t * 2.0 + q * 0.9) * 3.0, -12.0 - q * 5.0))
		draw_polyline(wisp, Pal.ink(0.25 * dim), 1.2)
	var badge := Rect2(Vector2(612, 318), Vector2(18, 24))
	draw_rect(badge, Color(0.09, 0.09, 0.095))
	draw_rect(badge, Pal.ink(0.55 * dim), false, 1.2)
	draw_circle(badge.position + Vector2(9, 9), 4.0, Pal.ink(0.3 * dim))
	draw_line(badge.position + Vector2(4, 18), badge.position + Vector2(14, 18), Pal.ink(0.35 * dim), 1.5)
	draw_line(badge.position + Vector2(9, 0), badge.position + Vector2(9, -6), Pal.ink(0.4 * dim), 1.0)


# By the crate, the quota window: a painted queue line, footprints that wait,
# badges dropped by people who gave up, and the window's board.
func _draw_quota(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	# the window: its board on top, a roller shutter below. When the intake
	# falls the shutter rolls up on what the quota was: one empty tray.
	var w := Rect2(424, 860, 178, 72)
	draw_rect(w, Color(0.06, 0.06, 0.065))
	draw_rect(w, Pal.ink(0.5 * dim), false, 1.5)
	draw_string(sf, w.position + Vector2(8, 16), Txt.t("quota_window"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.7 * dim))
	draw_string(sf, w.position + Vector2(8, 31), Txt.t("quota_today"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * dim))
	var hole := Rect2(w.position.x + 10.0, w.position.y + 38.0, w.size.x - 20.0, 28.0)
	draw_rect(hole, Color(0.02, 0.02, 0.022))
	# behind it: a counter, and on it a tray with nothing on it
	var tray := Rect2(hole.get_center() - Vector2(22, 6), Vector2(44, 12))
	draw_rect(tray, Pal.ink(0.55 * dim), false, 1.5)
	draw_line(tray.position + Vector2(4, 3), tray.position + Vector2(18, 3), Pal.ink(0.7 * dim, 1.2), 1.0)
	var up := clampf(shutter_up, 0.0, 1.0)
	var sh_h := hole.size.y * (1.0 - Pal.ease_io(up))
	if sh_h > 0.5:
		var shr := Rect2(hole.position, Vector2(hole.size.x, sh_h))
		draw_rect(shr, Color(0.07, 0.07, 0.075))
		var sl := PackedVector2Array()
		var y := shr.position.y + 4.0
		while y < shr.end.y - 1.0:
			sl.append(Vector2(shr.position.x + 2.0, y))
			sl.append(Vector2(shr.end.x - 2.0, y))
			y += 5.0
		if sl.size() > 0:
			draw_multiline(sl, Pal.ink(0.32 * dim), 1.0)
		# the handle at its foot
		draw_line(Vector2(shr.get_center().x - 10.0, shr.end.y - 2.0), Vector2(shr.get_center().x + 10.0, shr.end.y - 2.0), Pal.ink(0.7 * dim), 2.5)
	draw_rect(hole, Pal.ink(0.4 * dim), false, 1.0)
	# the queue: a dashed line out across the floor, footprints along it
	var q2 := PackedVector2Array()
	var x := 616.0
	while x < 830.0:
		q2.append(Vector2(x, 914.0))
		q2.append(Vector2(x + 12.0, 914.0))
		x += 22.0
	draw_multiline(q2, Color(1, 1, 1, 0.1 * dim), 2.0)
	for fx: float in [610.0, 670.0, 730.0, 790.0]:
		for fs: float in [-1.0, 1.0]:
			var fp := Vector2(fx + fs * 5.0, 900.0)
			draw_colored_polygon(PackedVector2Array([fp + Vector2(-3, -6), fp + Vector2(3, -6), fp + Vector2(4, 6), fp + Vector2(-4, 6)]), Color(1, 1, 1, 0.06 * dim))
	for bd in [[Vector2(650, 936), 0.4], [Vector2(735, 884), -0.6], [Vector2(812, 930), 1.1]]:
		draw_set_transform(bd[0], bd[1], Vector2.ONE)
		draw_rect(Rect2(-8, -11, 16, 22), Color(0.09, 0.09, 0.095))
		draw_rect(Rect2(-8, -11, 16, 22), Pal.ink(0.5 * dim), false, 1.2)
		draw_circle(Vector2(0, -3), 3.5, Pal.ink(0.3 * dim))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Oil under the presses, scuffed lanes where the carts run, stacked ration
# boxes waiting by the belts.
func _draw_floor_wear(dim: float) -> void:
	for oil in [[Vector2(560, 420), 26.0], [Vector2(1360, 730), 34.0], [Vector2(1010, 250), 20.0], [Vector2(470, 740), 22.0]]:
		var op: Vector2 = oil[0]
		var orr: float = oil[1]
		for j in 3:
			draw_circle(op + Vector2.from_angle(j * 2.1) * orr * 0.35, orr * (0.8 - j * 0.15), Color(0, 0, 0, 0.3 * dim))
	for st: Vector2 in [Vector2(820, 300), Vector2(1080, 300), Vector2(1700, 980)]:
		for j in 3:
			var br := Rect2(st + Vector2(j * 24.0 - 36.0, -(j % 2) * 10.0), Vector2(22, 22))
			draw_rect(br, Color(0.07, 0.07, 0.075))
			draw_rect(br, Pal.ink(0.35 * dim), false, 1.0)
			draw_line(br.position + Vector2(0, 11), br.position + Vector2(22, 11), Pal.ink(0.18 * dim), 1.0)


func _full() -> bool:
	return game.boss is Devourer and game.boss.state == Devourer.RUN and game.boss.phase >= 2


# The six blocks are stamping-press bases: a hazard band, a number, bolts.
func _draw_presses(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var n := 0
	for r: Rect2 in game.arena.inner:
		if r.size.x > 100.0:
			continue
		n += 1
		var ins := r.grow(-7.0)
		var hz := PackedVector2Array()
		var x := ins.position.x
		while x < ins.end.x - 6.0:
			hz.append(Vector2(x, ins.end.y))
			hz.append(Vector2(x + 8.0, ins.end.y - 12.0))
			x += 10.0
		draw_multiline(hz, Pal.ink(0.3 * dim), 2.0)
		draw_string(sf, ins.position + Vector2(4, 16), "PR-%02d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * dim))
		if _full():
			# the ram comes down and springs back, every press together
			var ph := fmod(t * 2.5, 1.0)
			var ram := 1.0 - Pal.ease_out(ph) if ph < 0.5 else (ph - 0.5) * 2.0
			var rr := ins.grow(-ins.size.x * 0.2 - 8.0 * (1.0 - ram))
			draw_rect(rr, Color(0.07, 0.07, 0.08))
			var strike := ph < 0.1
			draw_rect(rr, Pal.ink((0.9 if strike else 0.3) * dim, 1.5 if strike else 1.0), false, 2.0)
			if ph < 0.18:
				# the strike rings out round the base
				draw_rect(r.grow(4.0 + ph * 60.0), Pal.ink(0.5 * (1.0 - ph / 0.18) * dim, 1.2), false, 1.5)
			draw_string(sf, ins.position + Vector2(4, 16), "PR-%02d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.6 * dim))
		for b: Vector2 in [ins.position, Vector2(ins.end.x, ins.position.y)]:
			draw_circle(b + Vector2(0, 26), 2.5, Pal.ink(0.35 * dim))


# The strategic reserve crate: banded, padlocked, sealed, its stencil big.
func _draw_reserve(dim: float) -> void:
	var r: Rect2 = game.arms.crate_r
	var sf := Fonts.get_font("SemiBold")
	# stood on end: drawn turned, so its bands, its name and its lock stay square to it
	var turned := r.size.y > r.size.x
	if turned:
		draw_set_transform(r.get_center(), PI / 2.0, Vector2.ONE)
		r = Rect2(-Vector2(r.size.y, r.size.x) / 2.0, Vector2(r.size.y, r.size.x))
	var ins := r.grow(-8.0)
	draw_rect(ins, Pal.ink(0.2 * dim), false, 1.0)
	for bx: float in [r.position.x + 46.0, r.end.x - 46.0]:
		draw_line(Vector2(bx, r.position.y + 2.0), Vector2(bx, r.end.y - 2.0), Pal.ink(0.35 * dim), 4.0)
	if shows.get("w4_crate", 0.0) <= 0.01:
		var tx := Txt.t("crate_reserve")
		var tw := sf.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(sf, Vector2(r.get_center().x - tw / 2.0, r.get_center().y + 4.0), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.6 * dim))
	# the padlock on its front edge, and a seal strip across the lid
	var lk := Vector2(r.get_center().x, r.end.y - 14.0)
	draw_rect(Rect2(lk - Vector2(9, 6), Vector2(18, 14)), Pal.WALL)
	draw_rect(Rect2(lk - Vector2(9, 6), Vector2(18, 14)), Pal.ink(0.6 * dim), false, 1.5)
	draw_arc(lk - Vector2(0, 6), 6.0, PI, TAU, 10, Pal.ink(0.6 * dim), 1.5)
	var fl: float = game.arms.crate_flash
	draw_line(Vector2(r.position.x + 10.0, r.position.y + 18.0), Vector2(r.end.x - 10.0, r.position.y + 30.0), Pal.ink(0.35 * dim).lerp(Pal.red(dim, 1.8), fl), 3.0)
	if turned:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# The maintenance worker: by the door as the chapter opens, then back inside.
func _draw_worker(dim: float, shift := Vector2.ZERO) -> void:
	var k := worker_t
	var a := clampf(k / 0.6, 0.0, 1.0) * (1.0 - clampf((k - 4.6) / 0.6, 0.0, 1.0))
	if a <= 0.01:
		return
	var y := 700.0
	if k > 3.2:
		y = lerpf(700.0, 790.0, Pal.ease_io(clampf((k - 3.2) / 1.4, 0.0, 1.0)))
	var foot := Vector2(150.0 - 40.0 * clampf((k - 3.2) / 1.4, 0.0, 1.0), y) + shift
	var c := Pal.ink(0.7 * a * dim)
	draw_set_transform(foot, 0.0, Vector2(1.7, 1.7))
	foot = Vector2.ZERO
	# a plain figure in work clothes: head, shoulders, a lamp in hand
	draw_circle(foot + Vector2(0, -38), 6.0, c)
	draw_line(foot + Vector2(0, -32), foot + Vector2(0, -12), c, 3.0)
	draw_line(foot + Vector2(0, -12), foot + Vector2(-5, 0), c, 2.5)
	draw_line(foot + Vector2(0, -12), foot + Vector2(5, 0), c, 2.5)
	draw_line(foot + Vector2(0, -28), foot + Vector2(-9, -18), c, 2.0)
	draw_line(foot + Vector2(0, -28), foot + Vector2(10, -20), c, 2.0)
	# the hand lamp, pointed at you as the yard wakes
	var lamp := foot + Vector2(12, -20)
	draw_circle(lamp, 2.5, Pal.ink(a * dim, 2.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var lamp_w := Vector2(150.0, y) + shift + Vector2(12, -20) * 1.7
	var aim_w: Vector2 = (game.player.pos - lamp_w).normalized()
	draw_polygon(PackedVector2Array([lamp_w, lamp_w + aim_w.rotated(0.2) * 140.0, lamp_w + aim_w.rotated(-0.2) * 140.0]), PackedColorArray([Color(1, 1, 1, 0.14 * a * dim), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	# what he says, once, as you wake
	var say := Txt.t("worker_line")
	var sa := a * clampf((k - 0.8) / 0.3, 0.0, 1.0) * (1.0 - clampf((k - 3.0) / 0.4, 0.0, 1.0))
	if sa > 0.01:
		var sw := font.get_string_size(say, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_rect(Rect2(Vector2(150.0 + 22.0, y - 114.0) + shift, Vector2(sw + 16.0, 30.0)), Color(0, 0, 0, 0.6 * sa))
		draw_string(font, Vector2(150.0 + 30.0, y - 92.0) + shift, say, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.95 * sa * dim, 1.2))


func _draw_memory() -> void:
	if memory_t < 0.0:
		return
	var anchor := memory_fixed
	if anchor == Vector2.INF:
		if not game.possess.hosting() and memory_t > 0.6:
			return
		var sh = game.possess.shell
		if sh == null:
			return
		anchor = sh.pos
	var a := clampf(memory_t / 0.3, 0.0, 1.0) * (1.0 - clampf((memory_t - 2.8) / 0.6, 0.0, 1.0))
	var size := 18
	# typed out, a few characters at a time, like a log being read
	var n := int(memory.length() * clampf(memory_t / 0.5, 0.0, 1.0))
	var txt := memory.substr(0, n)
	var tw := font.get_string_size(memory, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = anchor + Vector2(-tw / 2.0, 92.0)
	if p.y > Arena.ROOM.end.y - 24.0:
		p.y = anchor.y - 74.0
	p.x = clampf(p.x, Arena.ROOM.position.x + 10.0, Arena.ROOM.end.x - tw - 10.0)
	# keep the plate off cover and floor rails: step it away, one way only
	var away := 40.0 if p.y < Arena.ROOM.get_center().y else -40.0
	for k in 8:
		var plate := Rect2(p + Vector2(-12, -24), Vector2(tw + 24, 34))
		var hit := false
		for rr: Rect2 in game.arena.inner:
			if plate.intersects(rr.grow(4.0)):
				hit = true
		if game.maglev.active():
			for rl in game.maglev.rails:
				if plate.grow(4.0).has_point(rl[0]) or plate.grow(4.0).has_point(rl[1]) or Geometry2D.segment_intersects_segment(rl[0], rl[1], plate.position, plate.end) != null:
					hit = true
		if not hit:
			break
		p.y += away
	mem_layer.draw_rect(Rect2(p + Vector2(-12, -24), Vector2(tw + 24, 34)), Color(0.01, 0.015, 0.02, 0.94 * a))
	mem_layer.draw_rect(Rect2(p + Vector2(-12, -24), Vector2(tw + 24, 34)), Possess.cyan(0.25 * a, 1.0), false, 1.0)
	mem_layer.draw_line(p + Vector2(-12, -24), p + Vector2(-12, 10), Possess.cyan(a, 1.8), 2.0)
	mem_layer.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Possess.cyan(0.95 * a, 1.4))


# ---------------------------------------------------------------- the deep archive

# Portholes in the top wall onto the black water, marine snow drifting past;
# a pressure gauge by the floor's corner; the plaque set in the floor.
# (`gen`: a generated room: its viewport, its gauge and the plaque where the
# room put them, or not at all)
func _draw_deep(dim: float, gen := false) -> void:
	var sf := Fonts.get_font("SemiBold")
	var lay: Dictionary = game.rooms.lay
	var vps: Array = [[Vector2(470, 250), 62.0, 0.0]]
	if gen:
		var vc: Vector2 = lay.get("viewport", Vector2(-1, -1))
		vps = [] if vc.x < 0.0 else [[vc, 62.0, 0.0]]
	# viewports in the floor onto the black water: marine snow rising past,
	# now and then something large and slow crossing under the glass
	for vp: Array in vps:
		var c: Vector2 = vp[0]
		var rr: float = vp[1]
		draw_circle(c, rr, Color(0.012, 0.016, 0.02))
		for j in 14:
			var sx := fmod(j * 53.0 + sin(j * 1.7) * 9.0, rr * 2.0) - rr
			var sy := rr - fmod(j * 41.0 + t * (5.0 + j % 4 * 2.0), rr * 2.0)
			var q := c + Vector2(sx, sy)
			if q.distance_to(c) < rr - 5.0:
				draw_circle(q, 1.1 + (j % 3) * 0.5, Pal.ink(0.32 * dim))
		# (a generated room's one window: it passes more often, and nearer the glass)
		var cyc := fmod(t + float(vp[2]), 9.0 if gen else 16.0)
		var big := 1.35 if gen else 1.0
		if cyc < 7.0:
			# a long shape gliding through, only its outline catching the light
			var u := cyc / 7.0
			var fc := c + Vector2(lerpf(-rr * 1.8, rr * 1.8, u), sin(u * 3.0) * rr * 0.2)
			var body := PackedVector2Array()
			for k in 13:
				var a := TAU * k / 12.0
				body.append(fc + Vector2(cos(a) * rr * 0.55 * big, sin(a) * rr * 0.16 * big))
			var inside := PackedVector2Array()
			for k in body.size() - 1:
				if body[k].distance_to(c) < rr - 4.0 and body[k + 1].distance_to(c) < rr - 4.0:
					inside.append(body[k])
					inside.append(body[k + 1])
			if inside.size() > 0:
				draw_multiline(inside, Pal.ink((0.3 if gen else 0.16) * dim), 1.5 if not gen else 2.0)
		draw_arc(c, rr, 0.0, TAU, 48, Pal.ink(0.32 * dim), 2.5)
		draw_arc(c, rr + 8.0, 0.0, TAU, 48, Pal.ink(0.14 * dim), 1.5)
		for b in 12:
			var a := TAU * b / 12.0
			draw_circle(c + Vector2.from_angle(a) * (rr + 4.0), 1.6, Pal.ink(0.3 * dim))
	# the gauge (a generated room: on the stretch of bottom wall it was given)
	var g := Vector2(140.0, 950.0)
	if gen:
		var gs: Array = lay.get("gauge", [])
		if gs.is_empty():
			g = Vector2(-1000, -1000)
		else:
			g = (gs[0] as Vector2) + Vector2(-130, -50)
	var gauge_on := g.x > -500.0
	if gauge_on:
		_draw_gauge(g, sf, dim)
	# the plaque in the floor, before a sweep wakes its words
	_draw_plate(dim)


# the depth gauge at `g`, its reading beside it
func _draw_gauge(g: Vector2, sf: Font, dim: float) -> void:
	draw_circle(g, 30.0, Color(0.04, 0.04, 0.045))
	draw_arc(g, 30.0, 0.0, TAU, 32, Pal.ink(0.55 * dim), 2.0)
	var ticks := PackedVector2Array()
	for k in 9:
		var a := PI * 0.75 + PI * 1.5 * k / 8.0
		ticks.append(g + Vector2.from_angle(a) * 19.0)
		ticks.append(g + Vector2.from_angle(a) * 23.0)
	draw_multiline(ticks, Pal.ink(0.4 * dim), 1.2)
	var na := PI * 0.75 + PI * 1.5 * (0.82 + 0.01 * sin(t * 1.3))
	draw_line(g, g + Vector2.from_angle(na) * 18.0, Pal.red(0.85 * dim, 1.5), 2.0)
	draw_circle(g, 3.0, Pal.ink(0.6 * dim))
	draw_string(sf, g + Vector2(42.0, 7.0), Txt.t("depth_gauge"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.5 * dim))


func _draw_plate(dim: float) -> void:
	var plate_at = game.rooms.spot("plate", Vector2(960, 1010))
	if plate_at != null and shows.get("w8_plate", 0.0) <= 0.01 and not _archivist_up():
		var pr := Rect2((plate_at as Vector2) + Vector2(-200.0, -88.0 if game.arena.generated else -60.0), Vector2(400.0, 34.0))
		draw_rect(pr, Color(0.05, 0.05, 0.055))
		draw_rect(pr, Pal.ink(0.3 * dim), false, 1.5)
		for k in 4:
			draw_circle(pr.position + Vector2(8.0 + (pr.size.x - 16.0) * (k % 2), 8.0 + (pr.size.y - 16.0) * (k / 2)), 2.0, Pal.ink(0.4 * dim))
		var bars := PackedVector2Array()
		var x := pr.position.x + 30.0
		while x < pr.end.x - 30.0:
			bars.append(Vector2(x, pr.get_center().y))
			bars.append(Vector2(minf(x + 36.0, pr.end.x - 30.0), pr.get_center().y))
			x += 48.0
		draw_multiline(bars, Pal.ink(0.18 * dim), 6.0)


func _archivist_up() -> bool:
	return game.boss is Archivist and game.boss.alive()


# ---------------------------------------------------------------- the sky lift

func _alt() -> float:
	return 28000.0 + t * 42.0


func _alt_str() -> String:
	var n := int(_alt())
	return "%d,%03d" % [n / 1000, n % 1000]


# Two great windows in the floor: the earth far below, its rim curving more
# as the car climbs, the lit cities on it and, off on its own, the faint few
# lights of 13th Street. Seats with their backs and belts; numbered pillars;
# handrails along the side walls; the viewing deck's limit across the floor.
const LIFT_WINDOWS := [Rect2(330, 160, 380, 200), Rect2(1210, 160, 380, 200)]


# A generated room of the car: its windows where the room put them, its
# furniture by kind (rows of bolted seats with their belts, pillars with
# their numbers, luggage racks strapped down, the kiosk that bills the
# handrails by the minute), the handrails between the doors, and the deck's
# limit before its plaque.
func _draw_lift_gen(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	# (the earth curves more room by room: the car is climbing)
	var climb := clampf(0.15 + 0.17 * int(lay.get("index", 0)) + 0.02 * sin(t * 0.3), 0.0, 1.0)
	var wins: Array = lay.get("windows", [])
	for wi in wins.size():
		_draw_lift_window(wins[wi], wi, climb, dim)
	var sf := Fonts.get_font("SemiBold")
	var kinds: Array = lay.get("kinds", [])
	var cover: Array = lay.get("cover", [])
	var pillar_n := 17
	for i in cover.size():
		var r: Rect2 = cover[i]
		var kind: String = kinds[i] if i < kinds.size() else "seats"
		var long_x := r.size.x >= r.size.y
		var ins := r.grow(-6.0)
		match kind:
			"seats":
				# a row of bolted seats from above: each a cushion between two
				# armrests, its back a bar on the side away from its neighbour row
				# (two rows back to back share the middle)
				var back_low := false
				for j2 in cover.size():
					var o: Rect2 = cover[j2]
					if j2 != i and kinds[j2] == "seats" and absf(o.position.y - r.end.y) < 1.0 and o.position.x < r.end.x and o.end.x > r.position.x:
						back_low = true
				var span := r.size.x if long_x else r.size.y
				var ns := maxi(int(span / 44.0), 1)
				var step := (span - 12.0) / ns
				for k in ns:
					var sr := Rect2(ins.position + Vector2(k * step, 0.0), Vector2(step - 6.0, ins.size.y)) if long_x else Rect2(ins.position + Vector2(0.0, k * step), Vector2(ins.size.x, step - 6.0))
					if long_x:
						var by := sr.end.y - 4.0 if back_low else sr.position.y + 4.0
						var fy := sr.position.y + 2.0 if back_low else sr.end.y - 2.0
						draw_line(Vector2(sr.position.x + 2.0, by), Vector2(sr.end.x - 2.0, by), Pal.ink(0.55 * dim), 6.0)
						draw_line(Vector2(sr.position.x, by), Vector2(sr.position.x, fy), Pal.ink(0.4 * dim), 2.0)
						draw_line(Vector2(sr.end.x, by), Vector2(sr.end.x, fy), Pal.ink(0.4 * dim), 2.0)
						draw_line(Vector2(sr.position.x + 5.0, fy), Vector2(sr.end.x - 5.0, fy), Pal.ink(0.22 * dim), 1.5)
					else:
						var bx := sr.position.x + 4.0
						var fx := sr.end.x - 2.0
						draw_line(Vector2(bx, sr.position.y + 2.0), Vector2(bx, sr.end.y - 2.0), Pal.ink(0.55 * dim), 6.0)
						draw_line(Vector2(bx, sr.position.y), Vector2(fx, sr.position.y), Pal.ink(0.4 * dim), 2.0)
						draw_line(Vector2(bx, sr.end.y), Vector2(fx, sr.end.y), Pal.ink(0.4 * dim), 2.0)
						draw_line(Vector2(fx, sr.position.y + 5.0), Vector2(fx, sr.end.y - 5.0), Pal.ink(0.22 * dim), 1.5)
			"pillar9":
				# a pillar: its bolts, its number
				for q: Vector2 in [ins.position, Vector2(ins.end.x, ins.position.y), ins.end, Vector2(ins.position.x, ins.end.y)]:
					draw_circle(q + (ins.get_center() - q).normalized() * 5.0, 2.0, Pal.ink(0.45 * dim))
				var num := "%02d" % pillar_n
				pillar_n += 1
				var nw := sf.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				draw_string(sf, r.get_center() + Vector2(-nw / 2.0, 6.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.5 * dim))
			"luggage":
				# a luggage rack: the cases strapped down under two belts
				var nc := 3 if long_x else 2
				for k in nc:
					var cr := Rect2(ins.position + (Vector2(ins.size.x / nc * k, 0.0) if long_x else Vector2(0.0, ins.size.y / nc * k)), (Vector2(ins.size.x / nc, ins.size.y) if long_x else Vector2(ins.size.x, ins.size.y / nc))).grow(-3.0)
					draw_rect(cr, Pal.ink(0.28 * dim), false, 1.5)
					# its carry handle
					draw_arc(cr.get_center(), 6.0, PI, TAU, 8, Pal.ink(0.45 * dim), 2.0)
				for k in 2:
					var u := (k + 1) / 3.0
					if long_x:
						draw_line(Vector2(lerpf(r.position.x, r.end.x, u), r.position.y), Vector2(lerpf(r.position.x, r.end.x, u), r.end.y), Pal.ink(0.5 * dim), 2.5)
					else:
						draw_line(Vector2(r.position.x, lerpf(r.position.y, r.end.y, u)), Vector2(r.end.x, lerpf(r.position.y, r.end.y, u)), Pal.ink(0.5 * dim), 2.5)
			"kiosk":
				# the handrail kiosk: a meter running on its screen, a card slot
				var scr := Rect2(ins.position + Vector2(4, 4), Vector2(ins.size.x - 8.0, minf(36.0, ins.size.y * 0.4)))
				draw_rect(scr, Color(0.02, 0.025, 0.03))
				draw_rect(scr, Pal.ink(0.45 * dim), false, 1.0)
				var secs := int(t) % 60
				var meter := "0:%02d" % secs
				var mw := sf.get_string_size(meter, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				draw_string(sf, scr.get_center() + Vector2(-mw / 2.0, 5.0), meter, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.red(0.85 * dim, 1.4))
				draw_string(sf, Vector2(r.position.x, r.position.y - 6.0), "RAIL 0.30/MIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.5 * dim))
				draw_line(Vector2(ins.get_center().x - 12.0, ins.end.y - 12.0), Vector2(ins.get_center().x + 12.0, ins.end.y - 12.0), Pal.ink(0.55 * dim), 3.0)
	# the handrails, broken at the doors
	for hr: Array in lay.get("handrails", []):
		var a: Vector2 = hr[0]
		var b: Vector2 = hr[1]
		draw_line(a, b, Pal.ink(0.4 * dim), 3.0)
		var inward := 12.0 if a.x < 960.0 else -12.0
		var y := a.y
		while y <= b.y:
			draw_line(Vector2(a.x, y), Vector2(a.x + inward, y), Pal.ink(0.3 * dim), 2.0)
			y += 70.0
	# the viewing deck's limit before its plaque
	var deck_at = game.rooms.spot("deck", Vector2(700, 1010))
	if deck_at != null:
		var dy: float = (deck_at as Vector2).y - 110.0
		var dx: float = (deck_at as Vector2).x - 260.0
		while dx < (deck_at as Vector2).x + 260.0:
			draw_line(Vector2(dx, dy), Vector2(dx + 30.0, dy), Pal.ink(0.14 * dim), 4.0)
			draw_line(Vector2(dx + 10.0, dy - 16.0), Vector2(dx + 22.0, dy - 24.0), Pal.ink(0.08 * dim), 3.0)
			dx += 52.0


# A window of the car: the stars, the earth's rim curving below, its city
# lights (13th Street's three dim ones, far from the rest, in the first).
func _draw_lift_window(r: Rect2, wi: int, climb: float, dim: float) -> void:
	draw_rect(r.grow(10.0), Color(0.05, 0.05, 0.055))
	draw_rect(r, Color(0.006, 0.008, 0.014))
	# stars over the rim
	for j in 18:
		var sp := r.position + Vector2(fmod(j * 83.0 + wi * 37.0, r.size.x - 8.0) + 4.0, fmod(j * 29.0, r.size.y * 0.45) + 4.0)
		draw_circle(sp, 0.8 + (j % 3) * 0.4, Pal.ink(0.22 * dim))
	# the earth: a great circle below, curving more as we rise
	var rr := lerpf(2600.0, 760.0, climb)
	var cc := Vector2(r.get_center().x + (wi * 2 - 1) * 120.0, r.position.y + r.size.y * 0.42 + rr)
	var rim := PackedVector2Array()
	var ground := PackedVector2Array()
	for j in 41:
		var x := r.position.x + r.size.x * j / 40.0
		var dy := rr - sqrt(maxf(0.0, rr * rr - pow(x - cc.x, 2.0)))
		var y := clampf(cc.y - rr + dy, r.position.y, r.end.y)
		rim.append(Vector2(x, y))
		ground.append(Vector2(x, y))
	ground.append(r.end)
	ground.append(Vector2(r.position.x, r.end.y))
	draw_colored_polygon(ground, Color(0.03, 0.04, 0.055))
	draw_polyline(rim, Pal.ink(0.12 * dim, 1.2), 9.0)
	draw_polyline(rim, Pal.ink(0.55 * dim, 1.3), 2.0)
	# city lights: clusters on the night side
	for k in 5:
		var cx := r.position.x + 40.0 + fmod(k * 97.0 + wi * 53.0, r.size.x - 80.0)
		var dy2 := rr - sqrt(maxf(0.0, rr * rr - pow(cx - cc.x, 2.0)))
		var cy := cc.y - rr + dy2 + 26.0 + fmod(k * 31.0, 60.0)
		for m in 7:
			var q := Vector2(cx + sin(m * 2.1 + k) * 14.0, cy + cos(m * 1.7 + k) * 8.0)
			# (none near 13th Street's three, low in the first window's corner)
			if wi == 0 and q.distance_to(Vector2(r.position.x + 57.0, r.end.y - 30.0)) < 60.0:
				continue
			if r.has_point(q):
				draw_circle(q, 1.1, Pal.ink(0.5 * dim, 1.4))
	if wi == 0:
		# 13th Street: three dim lights, far from the rest
		var tq := Vector2(r.position.x + 52.0, r.end.y - 30.0)
		for m in 3:
			draw_circle(tq + Vector2(m * 5.0, (m % 2) * 3.0), 0.9, Pal.ink(0.22 * dim))
	# the frame, its bolts and the glass's glint
	# (a generated room's: fainter, glass in the floor, not a thing in the way)
	var fk := 0.6 if game.arena.generated else 1.0
	draw_rect(r, Pal.ink(0.45 * fk * dim), false, 2.5)
	draw_rect(r.grow(10.0), Pal.ink(0.2 * fk * dim), false, 1.5)
	for k in 6:
		var bx := r.position.x + r.size.x * k / 5.0
		draw_circle(Vector2(bx, r.position.y - 5.0), 1.6, Pal.ink(0.35 * dim))
		draw_circle(Vector2(bx, r.end.y + 5.0), 1.6, Pal.ink(0.35 * dim))
	draw_line(r.position + Vector2(18, 14), r.position + Vector2(70, 14), Pal.ink(0.12 * dim, 1.2), 2.0)


func _draw_lift(dim: float) -> void:
	var climb := clampf((_alt() - 28000.0) / 16000.0, 0.0, 1.0)
	for wi in 2:
		_draw_lift_window(LIFT_WINDOWS[wi], wi, climb, dim)
	# the seats on their two benches: backs, arms, belts
	for b in [Rect2(560, 600, 180, 44), Rect2(1180, 600, 180, 44)]:
		var br: Rect2 = b
		for k in 4:
			var sr := Rect2(br.position.x + 6.0 + k * 43.0, br.position.y + 6.0, 38.0, 32.0)
			draw_rect(sr, Pal.ink(0.35 * dim), false, 1.5)
			draw_line(Vector2(sr.position.x + 3.0, sr.position.y + 5.0), Vector2(sr.end.x - 3.0, sr.position.y + 5.0), Pal.ink(0.5 * dim), 3.0)
			draw_line(sr.position + Vector2(8, 10), sr.end - Vector2(8, 4), Pal.ink(0.22 * dim), 1.5)
	var sf := Fonts.get_font("SemiBold")
	for pi in 2:
		var pc: Vector2 = [Vector2(448, 888), Vector2(1472, 888)][pi]
		draw_string(sf, pc + Vector2(-9, 6), "%02d" % (17 + pi), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.5 * dim))
	# handrails along the side walls, broken where the doors are
	for side: float in [96.0, 1824.0]:
		var segs := [[110.0, 250.0], [410.0, 680.0], [840.0, 990.0]]
		for sg: Array in segs:
			draw_line(Vector2(side, sg[0]), Vector2(side, sg[1]), Pal.ink(0.4 * dim), 3.0)
			var y: float = sg[0]
			while y <= float(sg[1]):
				draw_line(Vector2(side, y), Vector2(side + (-12.0 if side < 960.0 else 12.0), y), Pal.ink(0.3 * dim), 2.0)
				y += 70.0
	# the viewing deck's limit, and a hazard line before it
	var dx := 120.0
	while dx < 1800.0:
		draw_line(Vector2(dx, 940.0), Vector2(dx + 30.0, 940.0), Pal.ink(0.14 * dim), 4.0)
		draw_line(Vector2(dx + 10.0, 924.0), Vector2(dx + 22.0, 916.0), Pal.ink(0.08 * dim), 3.0)
		dx += 52.0


# ---------------------------------------------------------------- the orbital yard

# The dock open to space: stars where the floor plating stops at the edges,
# tether anchors along the walls with their lines, the two crates of armour
# steel, weld scars and hazard marks on the deck.
# A generated room of the shipyard: the deck's plating seams, tether
# anchors with their slack lines, weld scars and hazard chevrons, and its
# furniture by kind (armour-steel crates strapped, cable spools, bollards
# with a rope's turn, welding rigs with their bottles, a hull section
# riveted along its rib).
func _draw_dock_gen(dim: float) -> void:
	var lay: Dictionary = game.rooms.lay
	var room := Arena.ROOM
	var seams := PackedVector2Array()
	var x := room.position.x + 80.0
	while x < room.end.x:
		seams.append(Vector2(x, room.position.y + 10.0))
		seams.append(Vector2(x, room.end.y - 10.0))
		x += 160.0
	var y := room.position.y + 70.0
	while y < room.end.y:
		seams.append(Vector2(room.position.x + 10.0, y))
		seams.append(Vector2(room.end.x - 10.0, y))
		y += 160.0
	draw_multiline(seams, Pal.ink(0.05 * dim), 1.0)
	for a: Vector2 in lay.get("anchors", []):
		draw_circle(a, 5.0, Color(0.06, 0.06, 0.065))
		draw_arc(a, 5.0, 0.0, TAU, 12, Pal.ink(0.5 * dim), 1.5)
		var sw := sin(t * 0.7 + a.y * 0.01) * 14.0
		var dirx := 1.0 if a.x < 960.0 else -1.0
		draw_polyline(PackedVector2Array([a, a + Vector2(26.0 * dirx, 18.0 + sw * 0.4), a + Vector2(48.0 * dirx, 30.0 + sw)]), Pal.ink(0.22 * dim), 1.0)
	for sc: Array in lay.get("scars", []):
		var c: Vector2 = sc[0]
		var ang: float = sc[1]
		if int(sc[2]) == 0:
			# a weld scar: a jagged seam, still faintly warm at one end
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(c + Vector2.from_angle(ang) * (k * 14.0 - 42.0) + Vector2.from_angle(ang + PI * 0.5) * (4.0 if k % 2 == 0 else -4.0))
			draw_polyline(pts, Pal.ink(0.18 * dim), 2.0)
			draw_circle(pts[pts.size() - 1], 3.0, Pal.red(0.35 * dim, 1.3))
		else:
			# hazard chevrons
			for k in 3:
				var o := c + Vector2.from_angle(ang) * (k * 22.0 - 22.0)
				var f := Vector2.from_angle(ang)
				var sd := f.orthogonal()
				draw_polyline(PackedVector2Array([o - f * 6.0 + sd * 12.0, o + f * 6.0, o - f * 6.0 - sd * 12.0]), Pal.ink(0.12 * dim), 4.0)
	var kinds: Array = lay.get("kinds", [])
	var cover: Array = lay.get("cover", [])
	for i in cover.size():
		var r: Rect2 = cover[i]
		var kind: String = kinds[i] if i < kinds.size() else "steelcrate"
		var ins := r.grow(-8.0)
		match kind:
			"steelcrate":
				draw_line(ins.position, ins.end, Pal.ink(0.2 * dim), 1.0)
				draw_line(Vector2(ins.end.x, ins.position.y), Vector2(ins.position.x, ins.end.y), Pal.ink(0.2 * dim), 1.0)
				var nst := maxi(int(r.size.x / 50.0), 2)
				for j in nst:
					var sx := r.position.x + 10.0 + j * (r.size.x - 20.0) / nst
					draw_line(Vector2(sx, r.position.y + 4.0), Vector2(sx + 20.0, r.position.y + 4.0), Pal.ink(0.5 * dim), 3.0)
			"spool":
				var cc := r.get_center()
				var rr := minf(r.size.x, r.size.y) * 0.5 - 6.0
				draw_arc(cc, rr, 0.0, TAU, 24, Pal.ink(0.45 * dim), 2.0)
				draw_arc(cc, rr * 0.7, 0.0, TAU, 20, Pal.ink(0.2 * dim), 4.0)
				draw_arc(cc, rr * 0.45, 0.0, TAU, 16, Pal.ink(0.2 * dim), 4.0)
				draw_circle(cc, 5.0, Pal.ink(0.5 * dim))
			"bollard":
				var bc := r.get_center()
				draw_circle(bc, 14.0, Color(0.06, 0.06, 0.065))
				draw_arc(bc, 14.0, 0.0, TAU, 20, Pal.ink(0.55 * dim), 2.0)
				draw_arc(bc, 20.0, -0.4, 2.4, 14, Pal.ink(0.25 * dim), 2.0)
			"weldrig":
				for k in 2:
					var gb := Vector2(ins.position.x + 14.0 + k * 22.0, ins.get_center().y)
					draw_circle(gb, 9.0, Color(0.05, 0.05, 0.055))
					draw_arc(gb, 9.0, 0.0, TAU, 16, Pal.ink(0.5 * dim), 1.5)
				draw_line(Vector2(ins.position.x + 50.0, ins.get_center().y), ins.end - Vector2(6, 8), Pal.ink(0.35 * dim), 1.5)
				draw_circle(ins.end - Vector2(6, 8), 2.5, Pal.red(0.6 * dim, 1.4))
			"hull":
				# a curved rib down its length, rivets along both edges
				var long_x := r.size.x >= r.size.y
				var rib := PackedVector2Array()
				for k in 9:
					var u := k / 8.0
					rib.append(Vector2(lerpf(ins.position.x, ins.end.x, u), ins.get_center().y + sin(u * PI) * -8.0) if long_x else Vector2(ins.get_center().x + sin(u * PI) * -8.0, lerpf(ins.position.y, ins.end.y, u)))
				draw_polyline(rib, Pal.ink(0.35 * dim), 2.0)
				var span := r.size.x if long_x else r.size.y
				var nr := int(span / 24.0)
				for k in nr:
					var u := (k + 0.5) / nr
					for e in 2:
						var q := Vector2(lerpf(ins.position.x, ins.end.x, u), ins.position.y + 4.0 + e * (ins.size.y - 8.0)) if long_x else Vector2(ins.position.x + 4.0 + e * (ins.size.x - 8.0), lerpf(ins.position.y, ins.end.y, u))
						draw_circle(q, 1.6, Pal.ink(0.4 * dim))


func _draw_yard(dim: float) -> void:
	# deck plating seams
	var seams := PackedVector2Array()
	var x := 160.0
	while x < 1800.0:
		seams.append(Vector2(x, 480.0))
		seams.append(Vector2(x, 1000.0))
		x += 160.0
	var y := 520.0
	while y < 1000.0:
		seams.append(Vector2(90.0, y))
		seams.append(Vector2(1830.0, y))
		y += 160.0
	draw_multiline(seams, Pal.ink(0.05 * dim), 1.0)
	# tether anchors on the side walls, a slack line from each
	for side: float in [92.0, 1828.0]:
		for ay: float in [300.0, 820.0]:
			var a := Vector2(side, ay)
			draw_circle(a, 5.0, Color(0.06, 0.06, 0.065))
			draw_arc(a, 5.0, 0.0, TAU, 12, Pal.ink(0.5 * dim), 1.5)
			var sw := sin(t * 0.7 + ay * 0.01) * 14.0
			var dirx := 1.0 if side < 960.0 else -1.0
			draw_polyline(PackedVector2Array([a, a + Vector2(26.0 * dirx, 18.0 + sw * 0.4), a + Vector2(48.0 * dirx, 30.0 + sw)]), Pal.ink(0.22 * dim), 1.0)
	# the crates of armour steel
	for c in [Rect2(170, 880, 150, 70), Rect2(1600, 880, 150, 70)]:
		var cr: Rect2 = c
		var ins := cr.grow(-8.0)
		draw_line(ins.position, ins.end, Pal.ink(0.2 * dim), 1.0)
		draw_line(Vector2(ins.end.x, ins.position.y), Vector2(ins.position.x, ins.end.y), Pal.ink(0.2 * dim), 1.0)
		for j in 3:
			draw_line(Vector2(cr.position.x + 10.0 + j * 46.0, cr.position.y + 4.0), Vector2(cr.position.x + 30.0 + j * 46.0, cr.position.y + 4.0), Pal.ink(0.5 * dim), 3.0)
	# before the ship is laid down: its keel line and frame marked out on the
	# slip, faint, where it will be built
	if not (game.boss is Peace and game.boss.alive()):
		var kr := Rect2(Peace.X0 - 70.0, Peace.Y0, Peace.SEC_W * Peace.N + 160.0, Peace.H)
		var dl := PackedVector2Array()
		var x2 := kr.position.x
		while x2 < kr.end.x:
			dl.append(Vector2(x2, kr.position.y))
			dl.append(Vector2(minf(x2 + 16.0, kr.end.x), kr.position.y))
			dl.append(Vector2(x2, kr.end.y))
			dl.append(Vector2(minf(x2 + 16.0, kr.end.x), kr.end.y))
			x2 += 28.0
		draw_multiline(dl, Pal.ink(0.18 * dim), 1.5)
		draw_line(Vector2(kr.position.x, kr.get_center().y), Vector2(kr.end.x, kr.get_center().y), Pal.ink(0.15 * dim), 3.0)
		for k in Peace.N + 1:
			var rx := Peace.X0 + Peace.SEC_W * k
			draw_line(Vector2(rx, kr.position.y + 8.0), Vector2(rx, kr.end.y - 8.0), Pal.ink(0.07 * dim), 1.5)
		# the slip's cradles
		for k in 4:
			var cx := Peace.X0 + 60.0 + k * 170.0
			draw_rect(Rect2(cx - 22.0, kr.end.y + 6.0, 44.0, 14.0), Pal.ink(0.14 * dim), false, 1.5)


# The institute's floor: lab tiling, cable runs from the instrument plinths
# to the field posts, a sensor on each plinth sweeping the room, and the
# banner over the door with the year's count of anomalies.
func _draw_lab(dim: float) -> void:
	var tiles := PackedVector2Array()
	var x := 200.0
	while x < 1800.0:
		tiles.append(Vector2(x, 90.0))
		tiles.append(Vector2(x, 1000.0))
		x += 120.0
	var y := 130.0
	while y < 1000.0:
		tiles.append(Vector2(90.0, y))
		tiles.append(Vector2(1830.0, y))
		y += 120.0
	draw_multiline(tiles, Pal.ink(0.04 * dim), 1.0)
	var plinths := [Vector2(330, 250), Vector2(1590, 250), Vector2(330, 870), Vector2(1590, 870)]
	# cable runs, each plinth to its nearest field, laid in right angles
	var runs := PackedVector2Array()
	for k in plinths.size():
		var p: Vector2 = plinths[k]
		var best: Vector2 = Stasis.FIELDS[0]
		for fc: Vector2 in Stasis.FIELDS:
			if fc.distance_to(p) < best.distance_to(p):
				best = fc
		var edge: Vector2 = best + (p - best).normalized() * (Stasis.R + 8.0)
		var mid := Vector2(p.x, edge.y)
		runs.append(p)
		runs.append(mid)
		runs.append(mid)
		runs.append(edge)
	draw_multiline(runs, Pal.ink(0.1 * dim), 3.0)
	draw_multiline(runs, Color(0.03, 0.03, 0.035), 1.0)
	# the instruments, one of each: a sensor dish sweeping, an oscilloscope,
	# a clock whose hand will not settle, a pendulum swinging the wrong way
	for k in plinths.size():
		var p: Vector2 = plinths[k] + Vector2(0, -4)
		match k:
			0:
				var a := t * 0.5
				draw_arc(p, 16.0, a - 0.9, a + 0.9, 14, Pal.ink(0.6 * dim, 1.2), 2.5)
				draw_line(p, p + Vector2.from_angle(a) * 20.0, Pal.ink(0.5 * dim), 1.5)
				draw_circle(p, 3.0, Pal.ink(0.6 * dim))
			1:
				var sc := Rect2(p - Vector2(30, 14), Vector2(60, 28))
				draw_rect(sc, Color(0.03, 0.03, 0.035))
				draw_rect(sc, Pal.ink(0.4 * dim), false, 1.0)
				var wv := PackedVector2Array()
				for j in 25:
					var wx := sc.position.x + 3.0 + j * 2.25
					wv.append(Vector2(wx, sc.get_center().y + sin(j * 0.7 - t * 6.0) * 7.0 * (1.0 if j % 9 != 4 else 0.2)))
				draw_polyline(wv, Pal.ink(0.7 * dim, 1.4), 1.2)
			2:
				draw_arc(p, 15.0, 0.0, TAU, 24, Pal.ink(0.55 * dim), 1.5)
				for j in 12:
					var d := Vector2.from_angle(TAU * j / 12.0)
					draw_line(p + d * 12.0, p + d * 14.5, Pal.ink(0.4 * dim), 1.0)
				var ha := -PI * 0.5 + sin(t * 3.1) * 0.6 + sin(t * 7.3) * 0.25
				draw_line(p, p + Vector2.from_angle(ha) * 12.0, Pal.ink(0.75 * dim, 1.3), 1.5)
			3:
				var top := p + Vector2(0, -18)
				var sw := sin(-t * 1.7) * 0.7
				var bob := top + Vector2.from_angle(PI * 0.5 + sw) * 30.0
				draw_line(top + Vector2(-10, 0), top + Vector2(10, 0), Pal.ink(0.5 * dim), 2.0)
				draw_line(top, bob, Pal.ink(0.55 * dim), 1.2)
				draw_circle(bob, 4.0, Pal.ink(0.7 * dim, 1.3))
		for j in 5:
			var on := int(t * 3.0 + j + k) % 5 != 0
			draw_rect(Rect2((plinths[k] as Vector2) + Vector2(-38 + j * 8, 18), Vector2(5, 4)), Pal.ink((0.5 if on else 0.15) * dim), true)
	# the two sample boxes mid-floor, stencilled and taped shut
	var sbf := Fonts.get_font("SemiBold")
	var bl := Txt.t("sample_box")
	var bw := sbf.get_string_size(bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	for bx: Rect2 in [Rect2(700, 545, 70, 40), Rect2(1150, 545, 70, 40)]:
		draw_line(bx.position + Vector2(0, 20), bx.position + Vector2(70, 20), Pal.ink(0.3 * dim), 4.0)
		draw_rect(Rect2(bx.get_center() - Vector2(bw * 0.5 + 4.0, 8.0), Vector2(bw + 8.0, 15.0)), Color(0.05, 0.05, 0.055))
		draw_string(sbf, bx.get_center() + Vector2(-bw * 0.5, 4.0), bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.65 * dim))
	# the banner over the top wall
	var sf := Fonts.get_font("SemiBold")
	var lab := Txt.t("anomaly_gauge")
	var lw := sf.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var bc := Vector2(1340, 92)
	draw_rect(Rect2(bc - Vector2(lw * 0.5 + 12.0, 12.0), Vector2(lw + 24.0, 24.0)), Color(0.05, 0.05, 0.055))
	draw_rect(Rect2(bc - Vector2(lw * 0.5 + 12.0, 12.0), Vector2(lw + 24.0, 24.0)), Pal.ink(0.4 * dim), false, 1.0)
	draw_string(sf, bc + Vector2(-lw * 0.5, 5.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.6 * dim))


# The board's core: the hall's seal set in the floor round the centre, ticked
# like a dial; cable runs from each server column in to it, pulsing when that
# column powers; racks of servers along the top and bottom walls, their lights
# ticking over; the board's motto stencilled across the seal.
func _draw_core(dim: float) -> void:
	var c := Vector2(960, 540)
	draw_arc(c, 250.0, 0.0, TAU, 128, Pal.ink(0.1 * dim), 2.0)
	draw_arc(c, 236.0, 0.0, TAU, 128, Pal.ink(0.05 * dim), 1.0)
	var ticks := PackedVector2Array()
	var lit_ticks := PackedVector2Array()
	# as the war body is worn down, the seal's ticks light one by one; once it
	# is broken, the seal is cracked across
	var bs = game.boss
	var worn := 0.0
	var cracked := false
	if bs is Zero and bs.alive():
		worn = 1.0 - bs.hp / Zero.HP if bs.stage == 0 else 1.0
		cracked = bs.stage == 1 or bs.phase >= 2
	for k in 72:
		var d := Vector2.from_angle(TAU * k / 72.0 - PI * 0.5)
		var into := lit_ticks if float(k) / 72.0 < worn else ticks
		into.append(c + d * (236.0 if k % 6 == 0 else 242.0))
		into.append(c + d * 250.0)
	draw_multiline(ticks, Pal.ink(0.12 * dim), 1.0)
	if lit_ticks.size() > 0:
		draw_multiline(lit_ticks, Pal.red(0.6 * dim, 1.6), 2.0)
	if cracked:
		for k in 5:
			var a0 := k * 1.257 + 0.3
			var p0 := c + Vector2.from_angle(a0) * 40.0
			var p1 := c + Vector2.from_angle(a0 + 0.15) * 150.0
			var p2 := c + Vector2.from_angle(a0 - 0.1) * 248.0
			draw_polyline(PackedVector2Array([p0, p1, p2]), Pal.ink(0.22 * dim), 1.5)
	var sf := Fonts.get_font("SemiBold")
	var motto := Txt.t("core_motto")
	var mw := sf.get_string_size(motto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(sf, c + Vector2(-mw * 0.5, 284.0), motto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.22 * dim))
	# the cable runs in from the columns
	var nodes = game.nodes
	for k in ControlNodes.NODES.size():
		var p: Vector2 = ControlNodes.NODES[k]
		var hot: bool = nodes.active() and (nodes.live == k or nodes.second == k)
		var a := p + (c - p).normalized() * (ControlNodes.HALF + 8.0)
		var b := c + (p - c).normalized() * 252.0
		draw_line(a, b, Pal.ink(0.12 * dim), 4.0)
		draw_line(a, b, Color(0.03, 0.03, 0.035), 2.0)
		if hot:
			var u := (b - a)
			var l := u.length()
			var s0 := fmod(t * 260.0, 40.0)
			while s0 < l:
				draw_line(a + u / l * s0, a + u / l * minf(s0 + 14.0, l), Pal.red(0.7 * dim, 1.8), 2.0)
				s0 += 40.0
	# the standby bars: stencilled
	var sp := Txt.t("spare_power")
	var spw := sf.get_string_size(sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	for bc: Vector2 in [Vector2(390, 232), Vector2(1530, 232), Vector2(390, 848), Vector2(1530, 848)]:
		draw_string(sf, bc + Vector2(-spw * 0.5, 4.0), sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.45 * dim))
	# server racks along the top wall
	for y: float in [96.0]:
		var x := 180.0
		while x < 1760.0:
			if absf(x - 560.0) > 70.0 and absf(x - 1360.0) > 70.0 and absf(x - 960.0) > 90.0:
				var r := Rect2(x - 22.0, y - 9.0, 44.0, 18.0)
				draw_rect(r, Color(0.045, 0.045, 0.05))
				draw_rect(r, Pal.ink(0.22 * dim), false, 1.0)
				for j in 4:
					var on := int(t * 5.0 + x * 0.37 + j * 3.0) % 4 != 0
					draw_rect(Rect2(r.position + Vector2(5 + j * 9, 7), Vector2(4, 3)), Pal.ink((0.45 if on else 0.12) * dim), true)
			x += 64.0
