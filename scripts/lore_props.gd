class_name LoreProps
extends Node2D
# What a chapter's room keeps of the world (design/LORE.md), drawn in the same
# thin lines as everything else: the props on its walls, the remnants that
# surface while a round coming home passes them, the maintenance worker by the
# door at the start of 13th Street, and a seized shell's memory beside it.

const REVEAL_R := 110.0      # a returning round this close wakes a remnant
const HOLD := 2.6

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
		_draw_door(Vector2(960, 1010), dim)
		_draw_screen(Vector2(80, 300), dim)
		_draw_scrawl(Vector2(1840, 780), dim)
		_draw_notice(Vector2(1500, 70), dim)
		if worker_t >= 0.0:
			_draw_worker(dim)
	for w in Lore.walls(story):
		var id := "w%d_%s" % [story, w[0]]
		var k: float = shows.get(id, 0.0)
		if k <= 0.01:
			continue
		_draw_remnant(w, Pal.ease_out(k), dim)


func _draw_remnant(w: Array, k: float, dim: float) -> void:
	var at: Vector2 = w[1]
	var n: Vector2 = w[2]
	var txt: String = w[4] if Txt.zh else w[5]
	var size := 15
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	# the words sit just inside the wall, reading along it
	var p := at + n * (34.0 + 10.0 * k)
	var origin := p - Vector2(tw / 2.0, -5.0)
	if absf(n.x) > 0.5:
		origin = Vector2(p.x if n.x > 0.0 else p.x - tw, p.y + 5.0)
	if n.y > 0.5:
		origin = Vector2(p.x - tw / 2.0, p.y + 10.0)
	# a scan glitch as it surfaces, then steady
	var flick := 1.0 if k > 0.9 else (0.6 + 0.4 * float(int(t * 30.0) % 2))
	draw_string(font, origin + Vector2(1.5, 1.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7 * k))
	draw_string(font, origin, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Pal.ink(0.9 * k * flick * dim, 1.3))
	draw_line(origin + Vector2(0, 7), origin + Vector2(tw * k, 7), Pal.ink(0.3 * k * dim), 1.0)


# The old-era door R-0 came out of: two heavy panels, one slid half open.
func _draw_door(c: Vector2, dim: float) -> void:
	var w := 150.0
	var h := 26.0
	var top := c.y - h
	draw_rect(Rect2(c.x - w / 2.0 - 8.0, top - 6.0, w + 16.0, h + 6.0), Color(0.03, 0.03, 0.035, 1.0))
	draw_rect(Rect2(c.x - w / 2.0 - 8.0, top - 6.0, w + 16.0, h + 6.0), Pal.ink(0.5 * dim), false, 1.5)
	# left panel shut, right panel pushed aside: a dark gap between
	draw_rect(Rect2(c.x - w / 2.0, top, w * 0.42, h), Pal.ink(0.12 * dim))
	draw_rect(Rect2(c.x - w / 2.0, top, w * 0.42, h), Pal.ink(0.45 * dim), false, 1.0)
	draw_rect(Rect2(c.x + w * 0.22, top, w * 0.28, h), Pal.ink(0.12 * dim))
	draw_rect(Rect2(c.x + w * 0.22, top, w * 0.28, h), Pal.ink(0.45 * dim), false, 1.0)
	for j in 3:
		var x := c.x - w / 2.0 + 10.0 + j * 18.0
		draw_line(Vector2(x, top + 6.0), Vector2(x + 8.0, top + h - 6.0), Pal.ink(0.2 * dim), 1.0)
	# a faint light still inside
	var glow := 0.08 + 0.04 * sin(t * 1.3)
	draw_rect(Rect2(c.x - w / 2.0 + w * 0.42, top + 2.0, w * 0.22 + w * 0.08, h - 4.0), Color(1, 1, 1, glow * dim))


# A propaganda screen, cracked, its image long gone to scanlines.
func _draw_screen(c: Vector2, dim: float) -> void:
	var r := Rect2(c.x + 4.0, c.y - 70.0, 16.0, 140.0)
	draw_rect(r, Color(0.04, 0.04, 0.045, 1.0))
	draw_rect(r, Pal.ink(0.45 * dim), false, 1.5)
	var y := r.position.y + 4.0
	while y < r.end.y - 4.0:
		var on := sin(y * 0.7 + t * 9.0) > 0.6
		draw_line(Vector2(r.position.x + 3.0, y), Vector2(r.end.x - 3.0, y), Pal.ink((0.25 if on else 0.08) * dim), 1.0)
		y += 5.0
	draw_polyline(PackedVector2Array([r.position + Vector2(2, 40), r.position + Vector2(10, 58), r.position + Vector2(6, 76), r.position + Vector2(14, 96)]), Pal.ink(0.5 * dim), 1.0)


func _draw_scrawl(c: Vector2, dim: float) -> void:
	# a few hurried strokes on the right wall
	for j in 5:
		var y0 := c.y - 50.0 + j * 22.0
		draw_line(Vector2(c.x - 6.0, y0), Vector2(c.x - 18.0 - (j % 3) * 6.0, y0 + 12.0), Pal.ink(0.28 * dim), 2.0)


func _draw_notice(c: Vector2, dim: float) -> void:
	var r := Rect2(c.x - 26.0, c.y + 4.0, 52.0, 18.0)
	draw_rect(r, Color(0.06, 0.06, 0.065, 1.0))
	draw_rect(r, Pal.ink(0.4 * dim), false, 1.0)
	for j in 3:
		draw_line(r.position + Vector2(6, 5 + j * 4), r.position + Vector2(46 - j * 9, 5 + j * 4), Pal.ink(0.25 * dim), 1.0)
	# one corner torn off
	draw_line(r.end - Vector2(10, 0), r.end - Vector2(0, 8), Pal.ink(0.4 * dim), 1.0)


# The maintenance worker: by the door as the chapter opens, then back inside.
func _draw_worker(dim: float) -> void:
	var k := worker_t
	var a := clampf(k / 0.6, 0.0, 1.0) * (1.0 - clampf((k - 4.6) / 0.6, 0.0, 1.0))
	if a <= 0.01:
		return
	var x := 1070.0
	if k > 3.2:
		x = lerpf(1070.0, 1000.0, Pal.ease_io(clampf((k - 3.2) / 1.4, 0.0, 1.0)))
	var foot := Vector2(x, 990.0)
	var c := Pal.ink(0.55 * a * dim)
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
	var aim: Vector2 = (game.player.pos - lamp).normalized()
	var pts := PackedVector2Array([lamp, lamp + aim.rotated(0.22) * 120.0, lamp + aim.rotated(-0.22) * 120.0])
	draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 0.12 * a * dim), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))


func _draw_memory() -> void:
	if memory_t < 0.0 or not game.possess.hosting() and memory_t > 0.6:
		return
	var sh = game.possess.shell
	if sh == null:
		return
	var a := clampf(memory_t / 0.3, 0.0, 1.0) * (1.0 - clampf((memory_t - 2.8) / 0.6, 0.0, 1.0))
	var size := 15
	# typed out, a few characters at a time, like a log being read
	var n := int(memory.length() * clampf(memory_t / 1.0, 0.0, 1.0))
	var txt := memory.substr(0, n)
	var tw := font.get_string_size(memory, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = (sh.pos as Vector2) + Vector2(-tw / 2.0, -62.0)
	p.x = clampf(p.x, Arena.ROOM.position.x + 10.0, Arena.ROOM.end.x - tw - 10.0)
	mem_layer.draw_rect(Rect2(p + Vector2(-8, -18), Vector2(tw + 16, 26)), Color(0, 0, 0, 0.6 * a))
	mem_layer.draw_line(p + Vector2(-8, -18), p + Vector2(-8, 8), Possess.cyan(a, 1.8), 2.0)
	mem_layer.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Possess.cyan(0.95 * a, 1.4))
