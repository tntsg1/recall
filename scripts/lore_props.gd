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
	if story == 5 and game.bosses_by.has("train"):
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
	for w in Lore.walls(story):
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
func on_seize(shell) -> void:
	var m := Lore.seize_line(story, shell.kind, seize_n)
	seize_n += 1
	if m.is_empty():
		return
	memory = m.text
	memory_t = 0.0
	memory_at = game.possess
	if Lore.find(m.id):
		game.hud.lore_found()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if story == 1:
		_draw_floor(dim)
		_draw_crates(dim)
		# the door stands in the left wall, read as if the wall were its floor
		draw_set_transform(Vector2(80, 790), PI / 2.0, Vector2.ONE)
		_draw_door(Vector2.ZERO, dim)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_screen(Vector2(80, 300), dim)
		_draw_scrawl(Vector2(1840, 780), dim)
		if shows.get("w1_notice", 0.0) <= 0.01:
			_draw_notice(Vector2(1500, 70), dim)
		if worker_t >= 0.0 and game.wave_ctl.index <= 0:
			_draw_worker(dim)
	elif story == 2:
		_draw_seal(Vector2(330, 880), dim)
		_draw_pillars(dim)
		_draw_reflections(dim)
		_draw_queue(dim)
		# the gates, half again as large, a little clear of the wall
		draw_set_transform(Vector2(1500, 96), 0.0, Vector2(1.5, 1.5))
		_draw_gates(Vector2.ZERO, dim)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_scan(Vector2(1500 - 114, 96 + 72), dim)
		_draw_terminal(Vector2(80, 300), dim, "w2_terminal")
		_draw_terminal(Vector2(80, 760), dim, "")
		if shows.get("w2_retire", 0.0) <= 0.01:
			_draw_wall_notice(Vector2(1840, 760), dim)
	elif story == 3:
		_draw_lanes(dim)
		_draw_weapon_crates(dim)
		_draw_terminal(Vector2(80, 600), dim, "w3_log")
		_draw_target(Vector2(1840, 600), Vector2(-1, 0), dim, 0)
		_draw_target(Vector2(600, 70), Vector2(0, 1), dim, 1)
		if shows.get("w3_safety", 0.0) <= 0.01:
			_draw_floor_notice(Vector2(1490, 1010), dim)
	elif story == 5:
		_draw_platform(dim)
		_draw_containers(dim)
		_draw_terminal(Vector2(80, 300), dim, "w5_timetable")
	elif story == 4:
		_draw_stations(dim)
		_draw_presses(dim)
		_draw_reserve(dim)
		_draw_terminal(Vector2(80, 260), dim, "w4_board")
		if shows.get("w4_notice", 0.0) <= 0.01:
			_draw_notice(Vector2(1500, 70), dim)
		_draw_floor_wear(dim)
		_draw_quota(dim)
		_draw_scrawl(Vector2(1840, 820), dim)
	for w in Lore.walls(story):
		var id := "w%d_%s" % [story, w[0]]
		var k: float = shows.get(id, 0.0)
		if k <= 0.01:
			continue
		_draw_remnant(w, Pal.ease_out(k), dim)


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
	var at: Vector2 = (w[1] as Vector2) + Vector2(0, 66.0)
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
	var sc := Vector2(r.end.x - 20.0, r.position.y + 20.0)
	var sr := 17.0
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
	var at: Vector2 = (w[1] as Vector2) + Vector2(0, -36.0)
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
	var body := Rect2(c.x + 4.0, c.y - 80.0, 130.0, 160.0)
	draw_rect(body, Color(0.05, 0.05, 0.055, 1.0))
	draw_rect(body, Pal.ink(0.55 * dim), false, 2.0)
	var scr := Rect2(body.position + Vector2(10, 12), Vector2(110, 86))
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
		var rows := _rows(full, scr.size.x - 12.0, fs)
		if rows.size() > 3:
			fs = 13
			rows = _rows(full, scr.size.x - 10.0, fs)
		var step := 21.0 if fs == 15 else 18.0
		var budget := int(ceil(full.length() * clampf(wake * 1.6, 0.0, 1.0)))
		var yy := scr.position.y + (24.0 if fs == 15 else 19.0)
		for row in rows:
			draw_string(font, Vector2(scr.position.x + 6.0, yy), String(row).substr(0, clampi(budget, 0, String(row).length())), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.92 * wake * dim, 1.4))
			budget -= String(row).length()
			yy += step
	elif id != "" or int(t * 2.0) % 3 != 0:
		var dots := ".".repeat(int(t * 2.0) % 4)
		draw_string(font, scr.position + Vector2(8, 30), Txt.t({3: "term_log", 4: "term_output", 5: "term_timetable"}.get(story, "term_idle")) + dots, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.4 * dim))


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
func _draw_door(c: Vector2, dim: float) -> void:
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
	var pool_c := Vector2(80, 790) + Vector2(-(top - 40.0), gap.get_center().x)
	draw_set_transform(pool_c, 0.0, Vector2(0.9, 1.5))
	draw_texture_rect(Fx.make_glow_texture(), Rect2(-Vector2(60, 60), Vector2(120, 120)), false, Color(1, 1, 1, glow * 0.9 * dim))
	draw_set_transform(Vector2(80, 790), PI / 2.0, Vector2.ONE)
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
	var rows := _rows(full, lid.size.x - 8.0, 13)
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


# ---------------------------------------------------------------- the superconducting line

# 13th Street's platform, between the loop's bottom run and the wall: its
# edge, the yellow line, the station's name board, and the people painted
# where they wait, facing a train that never stops.
func _draw_platform(dim: float) -> void:
	var sf := Fonts.get_font("SemiBold")
	var r := Rect2(600, 934, 720, 70)
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
	var nb := Rect2(Vector2(r.position.x + 12.0, r.position.y + 24.0), Vector2(128, 34))
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
		var c := Vector2(170.0 + r.position.x + j * 38.0, r.position.y + 42.0)
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
	var sg := Rect2(Vector2(r.end.x - 188.0, r.position.y + 22.0), Vector2(176, 40))
	draw_rect(sg, Color(0.02, 0.025, 0.03))
	draw_rect(sg, Pal.ink(0.55 * dim), false, 1.5)
	var wake: float = shows.get("w5_yellow", 0.0)
	if wake > 0.01:
		var full := ""
		for w in Lore.walls(5):
			if w[0] == "yellow":
				full = w[4] if Txt.zh else w[5]
		var fw := sf.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var off := fmod(t * 90.0, fw + sg.size.x)
		var tx := sg.end.x - off
		var clipped := ""
		var cx := tx
		for ch in full:
			var chw := sf.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			if cx >= sg.position.x + 4.0 and cx + chw <= sg.end.x - 4.0:
				draw_string(sf, Vector2(cx, sg.position.y + 26.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.95 * wake * dim, 1.4))
			cx += chw
	else:
		var hot := flinch > 0.0 and fmod(passed * 8.0, 1.0) < 0.5
		var msg := Txt.t("no_stop")
		var mw := sf.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(sf, Vector2(sg.get_center().x - mw / 2.0, sg.position.y + 27.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.foe((1.0 if hot else 0.6) * dim, 2.0 if hot else 1.2))


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
	var r := Arms.CRATE
	var sf := Fonts.get_font("SemiBold")
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


# The maintenance worker: by the door as the chapter opens, then back inside.
func _draw_worker(dim: float) -> void:
	var k := worker_t
	var a := clampf(k / 0.6, 0.0, 1.0) * (1.0 - clampf((k - 4.6) / 0.6, 0.0, 1.0))
	if a <= 0.01:
		return
	var y := 700.0
	if k > 3.2:
		y = lerpf(700.0, 790.0, Pal.ease_io(clampf((k - 3.2) / 1.4, 0.0, 1.0)))
	var foot := Vector2(150.0 - 40.0 * clampf((k - 3.2) / 1.4, 0.0, 1.0), y)
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
	var lamp_w := Vector2(150.0, y) + Vector2(12, -20) * 1.7
	var aim_w: Vector2 = (game.player.pos - lamp_w).normalized()
	draw_polygon(PackedVector2Array([lamp_w, lamp_w + aim_w.rotated(0.2) * 140.0, lamp_w + aim_w.rotated(-0.2) * 140.0]), PackedColorArray([Color(1, 1, 1, 0.14 * a * dim), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	# what he says, once, as you wake
	var say := Txt.t("worker_line")
	var sa := a * clampf((k - 0.8) / 0.3, 0.0, 1.0) * (1.0 - clampf((k - 3.0) / 0.4, 0.0, 1.0))
	if sa > 0.01:
		draw_string(font, Vector2(150.0 + 30.0, y - 92.0), say, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.95 * sa * dim, 1.2))


func _draw_memory() -> void:
	if memory_t < 0.0 or not game.possess.hosting() and memory_t > 0.6:
		return
	var sh = game.possess.shell
	if sh == null:
		return
	var a := clampf(memory_t / 0.3, 0.0, 1.0) * (1.0 - clampf((memory_t - 2.8) / 0.6, 0.0, 1.0))
	var size := 18
	# typed out, a few characters at a time, like a log being read
	var n := int(memory.length() * clampf(memory_t / 0.5, 0.0, 1.0))
	var txt := memory.substr(0, n)
	var tw := font.get_string_size(memory, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = (sh.pos as Vector2) + Vector2(-tw / 2.0, 92.0)
	p.x = clampf(p.x, Arena.ROOM.position.x + 10.0, Arena.ROOM.end.x - tw - 10.0)
	mem_layer.draw_rect(Rect2(p + Vector2(-12, -24), Vector2(tw + 24, 34)), Color(0, 0, 0, 0.7 * a))
	mem_layer.draw_line(p + Vector2(-12, -24), p + Vector2(-12, 10), Possess.cyan(a, 1.8), 2.0)
	mem_layer.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Possess.cyan(0.95 * a, 1.4))
