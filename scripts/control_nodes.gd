class_name ControlNodes
extends Node2D
# The board's core (chapter 12): control nodes. Four server columns stand in
# the hall. In turn one powers up — its cables light toward every round of
# yours in the walls within its reach — and then it takes them over: a ring
# fills round each, and a round fully taken is the board's now. Shortly after
# the board calls the taken rounds home, and their way back cuts you. Recall
# yours before the ring closes, or put a round into the column itself, and
# the takeover is cut. A round taken is gone from your magazine until it
# grows back.

const NODES := [Vector2(560, 160), Vector2(1360, 160), Vector2(560, 920), Vector2(1360, 920)]
const HALF := 46.0
const REACH := 400.0
const WARN := 1.1
const TAKE := 1.7
const CALL := 1.3            # after the takeover, the board calls them home
const PERIOD := [6.0, 4.6]   # between powerings: in the waves, in the fight
const CUT_SHOW := 0.8

var on := false
var game
var nodes: Array = NODES.duplicate()   # this room's columns' centres
var t := 0.0
var clock := 0.0
var live := -1               # the node powering up or taking over (-1: none)
var live_t := 0.0
var turn := 0
var targets: Array = []      # rounds it is reaching for
var taken: Array = []        # [round, t]: the board's, waiting to be called
var cut_t := -1.0
var cut_at := Vector2.ZERO
var second := -1             # in the fight's second half two nodes power at once
var cut_n := 0


func _init() -> void:
	z_index = 2
	z_as_relative = false


static func rects() -> Array[Rect2]:
	return rects_for(NODES)


# Columns standing at these centres, as rects.
static func rects_for(list: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c: Vector2 in list:
		out.append(Rect2(c - Vector2(HALF, HALF), Vector2(HALF, HALF) * 2.0))
	return out


func setup(story: int) -> void:
	on = story == 12
	set_nodes([])


# The columns this room has (none given: the hand-made core's four).
func set_nodes(list: Array) -> void:
	nodes = NODES.duplicate() if list.is_empty() else list.duplicate()
	visible = on
	t = 0.0
	clock = 2.5
	live = -1
	second = -1
	targets.clear()
	taken.clear()
	cut_t = -1.0
	cut_n = 0
	queue_redraw()


func active() -> bool:
	return on


# The node whose column an arena rect index is, or -1.
func node_of(rect_i: int) -> int:
	if not on or rect_i < 0:
		return -1
	var r: Rect2 = game.arena.rects[rect_i] if rect_i < game.arena.rects.size() else Rect2()
	for k in nodes.size():
		if r.get_center().distance_to(nodes[k]) < 2.0:
			return k
	return -1


# A round of yours struck a column: if that column is powering, it is cut.
func on_embed(b, rect_i: int) -> void:
	var k := node_of(rect_i)
	if k < 0 or (k != live and k != second) or live_t >= WARN + TAKE:
		return
	_cut(b.pos)


func _cut(at: Vector2) -> void:
	live = -1
	second = -1
	targets.clear()
	cut_t = 0.0
	cut_at = at
	cut_n += 1
	clock = 0.0
	game.fx.sparks(at, Vector2.UP, 14, Pal.ink(1.0, 2.2), 520.0, 0.3, PI)
	game.fx.ring(at, 8.0, 90.0, 0.35, Pal.ink(0.9, 2.0), 2.0)
	game.sfx.play("shield", 0.7, -4.0)
	game.cam.add_trauma(0.15)


func _fighting() -> bool:
	return game.wave_ctl.phase == Waves.FIGHT and game.hud.intro_t < 0.0


func _boss_on() -> bool:
	return game.boss is Zero and game.boss.state == Zero.RUN


func step(dt: float) -> void:
	if not on:
		return
	t += dt
	if cut_t >= 0.0:
		cut_t += dt
		if cut_t > CUT_SHOW:
			cut_t = -1.0
	if live < 0:
		if _fighting():
			clock += dt
		if clock >= PERIOD[1 if _boss_on() else 0]:
			clock = 0.0
			_power()
	else:
		var was := live_t
		live_t += dt
		if was < WARN and live_t >= WARN:
			game.sfx.play("focus", 0.5, -6.0)
		if live_t >= WARN:
			# the takeover: anything you call home meanwhile is no longer reached for
			var i := 0
			while i < targets.size():
				var b = targets[i]
				if b.state != Bullets.EMBED or b.foe:
					targets.remove_at(i)
				else:
					i += 1
		if live_t >= WARN + TAKE:
			for b in targets:
				_take(b)
			targets.clear()
			live = -1
			second = -1
	# the board calls home what it took
	var j := 0
	while j < taken.size():
		taken[j][1] += dt
		var b = taken[j][0]
		if b.state != Bullets.EMBED or not b.foe:
			taken.remove_at(j)
			continue
		if taken[j][1] >= CALL - 0.8 and b.zlight <= 0.0:
			b.zlight = 0.001
		if taken[j][1] >= CALL:
			b.state = Bullets.PULL
			b.t = 0.0
			b.delay = randf_range(0.0, 0.1)
			b.zero_pass = true
			b.hit.clear()
			if b.settled:
				b.settled = false
				game.bullets.faint_dirty = true
			taken.remove_at(j)
			game.sfx.play("release", 0.9, -8.0)
			continue
		j += 1
	queue_redraw()


func _power() -> void:
	# the column farthest from you first: you have time to see it coming
	var order: Array = range(nodes.size())
	order.sort_custom(func(a: int, b: int) -> bool: return (nodes[a] as Vector2).distance_to(game.player.pos) > (nodes[b] as Vector2).distance_to(game.player.pos))
	live = order[turn % 2]
	turn += 1
	second = order[mini(2, order.size() - 1)] if _boss_on() and game.boss.phase >= 1 else -1
	live_t = 0.0
	targets.clear()
	for b in game.bullets.list:
		if b.state != Bullets.EMBED or b.foe or b.stasis >= 0:
			continue
		if _reach(b.pos) >= 0:
			targets.append(b)
	game.sfx.play("windup", 0.42, -6.0)


# Which powering node reaches p (or -1).
func _reach(p: Vector2) -> int:
	for k: int in [live, second]:
		if k >= 0 and p.distance_to(nodes[k]) < REACH:
			return k
	return -1


func _take(b) -> void:
	b.foe = true
	b.zlight = 0.0
	b.light = 0.0
	b.light_delay = -1.0
	b.dmg = 0.0
	if not b.child:
		b.child = true
		game.queue_regen()
	taken.append([b, 0.0])
	game.fx.ring(b.pos, 4.0, 26.0, 0.3, Pal.red(0.9, 2.2), 1.5)
	game.fx.sparks(b.pos, -b.dir, 3, Pal.red(0.9, 2.0), 220.0, 0.15, 0.8)
	game.sfx.play("expire", 0.6, -10.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not on:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if game.hud.intro_t >= 0.0:
		dim *= clampf((game.hud.intro_t - 2.2) / 0.6, 0.25, 1.0)
	var font := Fonts.get_font("SemiBold")
	for k in nodes.size():
		_draw_node(k, dim, font)
	# reaching for your rounds: a cable of light, then a ring closing round each
	if live >= 0:
		var wk := clampf(live_t / WARN, 0.0, 1.0)
		var tk := clampf((live_t - WARN) / TAKE, 0.0, 1.0)
		for b in targets:
			var src: Vector2 = nodes[_reach(b.pos) if _reach(b.pos) >= 0 else live]
			var p: Vector2 = b.pos
			var d := p - src
			var l := d.length()
			var u := d / maxf(l, 0.001)
			# the cable runs out to it while warning
			var reach_l: float = l * Pal.ease_out(wk)
			var seg := PackedVector2Array()
			var s0 := HALF + fmod(t * 120.0, 18.0)
			while s0 < reach_l:
				seg.append(src + u * s0)
				seg.append(src + u * minf(s0 + 9.0, reach_l))
				s0 += 18.0
			if seg.size() > 0:
				draw_multiline(seg, Pal.red((0.35 + 0.4 * tk) * dim, 1.6), 1.5)
			if tk > 0.0:
				# a pie filling round the round, and its rim
				var pie := PackedVector2Array([p])
				for j in 25:
					pie.append(p + Vector2.from_angle(-PI * 0.5 + TAU * tk * j / 24.0) * 26.0)
				if tk > 0.02:
					draw_colored_polygon(pie, Color(0.6, 0.05, 0.05, 0.35 * dim))
				draw_arc(p, 26.0, -PI * 0.5, -PI * 0.5 + TAU * tk, 32, Pal.red(0.95 * dim, 2.2), 3.0)
				draw_arc(p, 26.0, 0.0, TAU, 32, Pal.red(0.3 * dim), 1.0)
	if cut_t >= 0.0:
		var ck := cut_t / CUT_SHOW
		var lab := Txt.t("node_cut")
		var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, cut_at + Vector2(-lw * 0.5, -30.0 - 16.0 * ck), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink((1.0 - ck) * dim, 1.6))


# A server column seen from above: a dark cabinet, rack lines, a ring of
# status lights; its reach marked on the floor while it powers, the lights
# racing, the label lit.
func _draw_node(k: int, dim: float, font: Font) -> void:
	var c: Vector2 = nodes[k]
	var r := Rect2(c - Vector2(HALF, HALF), Vector2(HALF, HALF) * 2.0)
	var hot := k == live or k == second
	var wk := clampf(live_t / WARN, 0.0, 1.0) if hot else 0.0
	var tk := clampf((live_t - WARN) / TAKE, 0.0, 1.0) if hot else 0.0
	if hot:
		# its reach on the floor
		var fl := 0.6 + 0.4 * sin(t * (10.0 + 16.0 * tk))
		if game.arena.generated:
			# (a generated room's: only the edge, cut where it would leave the room)
			var inside := Arena.ROOM.grow(-4.0)
			var arc := PackedVector2Array()
			for s3 in 129:
				var q := c + Vector2.from_angle(TAU * s3 / 128.0) * REACH
				if inside.has_point(q):
					arc.append(q)
				else:
					if arc.size() > 1:
						draw_polyline(arc, Pal.red((0.25 + 0.45 * tk) * fl * dim, 1.5), 1.5 + 1.5 * tk)
					arc = PackedVector2Array()
			if arc.size() > 1:
				draw_polyline(arc, Pal.red((0.25 + 0.45 * tk) * fl * dim, 1.5), 1.5 + 1.5 * tk)
		else:
			draw_circle(c, REACH, Color(0.5, 0.05, 0.05, 0.05 * wk * dim))
			draw_arc(c, REACH, 0.0, TAU, 96, Pal.red((0.25 + 0.45 * tk) * fl * dim, 1.5), 1.5 + 1.5 * tk)
	draw_rect(r, Color(0.045, 0.045, 0.05))
	for j in 5:
		var y := r.position.y + 10.0 + j * 12.0
		draw_line(Vector2(r.position.x + 8.0, y), Vector2(r.end.x - 8.0, y), Pal.ink(0.18 * dim), 1.0)
		var lit := hot and (int(t * 14.0) + j) % 3 != 0
		draw_rect(Rect2(Vector2(r.end.x - 16.0, y - 3.0), Vector2(6, 4)), Pal.red(0.9 * dim, 2.0) if lit else Pal.ink(0.3 * dim), true)
	draw_rect(r, Pal.red(0.9 * dim, 1.8) if hot else Pal.ink(0.6 * dim), false, 2.0 + (1.0 if hot else 0.0))
	var lab := Txt.t("node_taking") if tk > 0.0 else Txt.t("node_tag")
	# (a generated room: only the powering column says what it is, and larger)
	if game.arena.generated and not hot:
		return
	var fs := 16 if hot else 12
	var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ly := r.end.y + 22.0 if c.y < 540.0 else r.position.y - 12.0
	if hot:
		draw_rect(Rect2(Vector2(c.x - lw * 0.5 - 6.0, ly - fs - 1.0), Vector2(lw + 12.0, fs + 8.0)), Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(c.x - lw * 0.5, ly), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, (Pal.red(dim, 1.8) if hot else Pal.ink(0.35 * dim)))
