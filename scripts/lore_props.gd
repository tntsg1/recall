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
			if shows.get(id, 0.0) <= 0.01 and Lore.find(id):
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
	var busy: bool = worker_t >= 0.0 or focus_last != game.focus
	for k in shows:
		if shows[k] > 0.0:
			busy = true
			break
	focus_last = game.focus
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
		"screen":
			pass      # the screen shows it on its own glass (_draw_screen)
		"scrawl":
			_remnant_hand(w, shown, k, dim)
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
	var at: Vector2 = (w[1] as Vector2) + (w[2] as Vector2) * 150.0 + Vector2(0, 92.0)
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


# Printed on the notice's own paper, which unfolds to hold it.
func _remnant_print(w: Array, shown: String, full: String, k: float, dim: float) -> void:
	var at: Vector2 = w[1]
	var size := 16
	var tw := font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r := Rect2(at.x - 60.0, at.y + 22.0, 120.0 + (tw + 30.0 - 120.0) * Pal.ease_out(k), 72.0)
	r.position.x = minf(r.position.x, Arena.ROOM.end.x - r.size.x - 8.0)
	draw_rect(r, Color(0.08, 0.08, 0.085, 1.0))
	draw_rect(r, Pal.ink(0.6 * dim), false, 1.5)
	draw_string(font, r.position + Vector2(15, 30), Txt.t("notice_head"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.45 * k * dim))
	draw_string(font, r.position + Vector2(15, 54), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Pal.ink(0.9 * k * dim, 1.2))
	draw_arc(Vector2(r.end.x - 22.0, r.position.y + 22.0), 11.0, 0.0, TAU, 20, Pal.red(0.6 * k * dim, 1.4), 2.0, false)


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
	var r := Rect2(c.x + 4.0, c.y - 130.0, 92.0, 260.0)
	draw_rect(r, Color(0.04, 0.04, 0.045, 1.0))
	draw_rect(r, Pal.ink(0.6 * dim), false, 2.0)
	draw_rect(r.grow(-4.0), Pal.ink(0.2 * dim), false, 1.0)
	var y := r.position.y + 6.0
	while y < r.end.y - 6.0:
		var on := sin(y * 0.5 + t * 7.0) > 0.7
		draw_line(Vector2(r.position.x + 6.0, y), Vector2(r.end.x - 6.0, y), Pal.ink((0.3 if on else 0.08) * dim), 1.0)
		y += 6.0
	# what is left of its slogan, running down the glass, stuttering
	var wake: float = shows.get("w1_screen", 0.0)
	var sf := Fonts.get_font("SemiBold")
	var full: String = Txt.t("screen_full")
	var rows: Array = Array(full.split("\n"))
	# asleep it shows only its first two rows, stuttering; awake, all of them
	var show_n := rows.size() if wake > 0.01 else 2
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
	# the crack
	draw_polyline(PackedVector2Array([r.position + Vector2(6, 40), r.position + Vector2(40, 88), r.position + Vector2(26, 130), r.position + Vector2(70, 176), r.position + Vector2(58, 220)]), Pal.ink(0.7 * dim, 1.2), 1.5)
	draw_line(r.position + Vector2(40, 88), r.position + Vector2(86, 102), Pal.ink(0.5 * dim, 1.2), 1.0)


func _rows(txt: String, width: float, size: int) -> Array:
	var key := "%d|%d|%s" % [size, int(width), txt]
	if row_cache.has(key):
		return row_cache[key]
	var out: Array = []
	var cur := ""
	for ch in txt:
		if font.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and cur != "":
			out.append(cur)
			cur = ch
		else:
			cur += ch
	if cur != "":
		out.append(cur)
	row_cache[key] = out
	return out


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
	draw_polygon(PackedVector2Array([lamp_w, lamp_w + aim_w.rotated(0.22) * 220.0, lamp_w + aim_w.rotated(-0.22) * 220.0]), PackedColorArray([Color(1, 1, 1, 0.14 * a * dim), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
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
	var p: Vector2 = (sh.pos as Vector2) + Vector2(-tw / 2.0, -70.0)
	p.x = clampf(p.x, Arena.ROOM.position.x + 10.0, Arena.ROOM.end.x - tw - 10.0)
	mem_layer.draw_rect(Rect2(p + Vector2(-12, -24), Vector2(tw + 24, 34)), Color(0, 0, 0, 0.7 * a))
	mem_layer.draw_line(p + Vector2(-12, -24), p + Vector2(-12, 10), Possess.cyan(a, 1.8), 2.0)
	mem_layer.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Possess.cyan(0.95 * a, 1.4))
