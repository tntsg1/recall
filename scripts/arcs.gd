class_name Arcs
extends Node2D
# The energy bureau's floor (chapter 6): rounds of yours embedded close to
# one another are wired by the room's live current, and an arc jumps between
# them. An arc cuts any enemy that crosses it, and you too (a dash goes
# through) — so a spread of rounds laid on purpose is a fence of your own,
# the way 13th Street wires its own lights. A round an inspector has put out
# carries no current. Arcs across the grid master's cables cut those too.

const ARC_D := 170.0
const MAX_LINKS := 2
const HIT_EVERY := 0.3
const ARC_DMG := 9.0
const CABLE_DMG := 7.0

var reach := ARC_D        # how far the current jumps (a generated room's place sets it)
var arcs: Array = []      # [a, b]
var on := false
var t := 0.0
var rebuild := 0.0
var enemy_cd := {}        # enemy id -> seconds until it can be cut again
var cable_cd := 0.0
var game


func _init() -> void:
	z_index = 3
	z_as_relative = false


func setup(story: int) -> void:
	on = story == 6
	reach = ARC_D
	arcs.clear()
	enemy_cd.clear()
	visible = on
	queue_redraw()


func active() -> bool:
	return on


func step(dt: float) -> void:
	if not on:
		return
	queue_redraw()
	t += dt
	rebuild -= dt
	if rebuild <= 0.0:
		rebuild = 0.08
		_link()
	for k in enemy_cd.keys():
		enemy_cd[k] -= dt
		if enemy_cd[k] <= 0.0:
			enemy_cd.erase(k)
	cable_cd -= dt
	if not arcs.is_empty():
		_cut()
	queue_redraw()


# Each live round links to its nearest live neighbours within reach.
func _link() -> void:
	arcs.clear()
	var pts: Array = []
	for b in game.bullets.list:
		if b.state == Bullets.EMBED and not b.foe and not b.child and b.dark_by == 0:
			pts.append(b.pos)
			if pts.size() >= 40:
				break
	var seen := {}
	for i in pts.size():
		var near: Array = []
		for j in pts.size():
			if i == j:
				continue
			var d: float = (pts[i] as Vector2).distance_to(pts[j])
			if d > 18.0 and d < reach:
				near.append([d, j])
		near.sort_custom(func(x, y): return x[0] < y[0])
		for n in mini(MAX_LINKS, near.size()):
			var j: int = near[n][1]
			var key := "%d_%d" % [mini(i, j), maxi(i, j)]
			if seen.has(key):
				continue
			seen[key] = true
			arcs.append([pts[i], pts[j]])


func _cut() -> void:
	var p: Vector2 = game.player.pos
	var hurt := false
	for a in arcs:
		var q := Geometry2D.get_closest_point_to_segment(p, a[0], a[1])
		if not hurt and q.distance_to(p) < Player.R + 3.0 and game.player.dash_t <= 0.0:
			hurt = true
			var n: Vector2 = (p - q).normalized() if p.distance_to(q) > 0.5 else Vector2.UP
			if game.on_player_hit(n, null):
				game.fx.sparks(q, n, 8, Pal.ink(1.0, 2.6), 380.0, 0.2, 1.0)
		for e in game.enemies.list:
			if e.state != Enemies.ALIVE or enemy_cd.has(e.id):
				continue
			var qe := Geometry2D.get_closest_point_to_segment(e.pos, a[0], a[1])
			if qe.distance_to(e.pos) < e.r + 4.0:
				enemy_cd[e.id] = HIT_EVERY
				game.enemies.blast_hit(e, (e.pos - qe).normalized(), ARC_DMG)
				game.fx.sparks(qe, (e.pos - qe).normalized(), 5, Pal.ink(1.0, 2.6), 300.0, 0.18, 1.0)
		if cable_cd <= 0.0 and game.boss is GridMaster and game.boss.state == GridMaster.RUN:
			if game.boss.arc_cross(a[0], a[1], CABLE_DMG):
				cable_cd = HIT_EVERY


func _draw() -> void:
	if not on or game == null or game.bullets == null:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.4 * f
	var marks := PackedVector2Array()
	for b in game.bullets.list:
		if b.dark_by != 0 and b.state == Bullets.EMBED:
			var c: Vector2 = b.pos
			draw_circle(c, 13.0, Color(0.03, 0.03, 0.035))
			draw_arc(c, 13.0, 0.0, TAU, 18, Pal.foe(0.7 * dim, 1.2), 2.0)
			marks.append_array(PackedVector2Array([c + Vector2(-7, -7), c + Vector2(7, 7), c + Vector2(7, -7), c + Vector2(-7, 7)]))
	if marks.size() > 0:
		draw_multiline(marks, Pal.foe(0.95 * dim, 1.4), 3.0)
	if arcs.is_empty():
		return
	var glow := PackedVector2Array()
	var core := PackedVector2Array()
	var wglow := PackedVector2Array()
	var wcore := PackedVector2Array()
	var room := Arena.ROOM.grow(-8.0)
	var k := 0
	for a in arcs:
		k += 1
		var p0: Vector2 = a[0]
		var p1: Vector2 = a[1]
		# along a wall: both ends on the same edge
		var on_wall := (p0.x < room.position.x and p1.x < room.position.x) or (p0.x > room.end.x and p1.x > room.end.x) \
			or (p0.y < room.position.y and p1.y < room.position.y) or (p0.y > room.end.y and p1.y > room.end.y)
		var gl: PackedVector2Array = wglow if on_wall else glow
		var co: PackedVector2Array = wcore if on_wall else core
		var d := p1 - p0
		var n := d.orthogonal().normalized()
		var segs := 6
		var prev := p0
		for j in range(1, segs + 1):
			var u := j / float(segs)
			# (in a generated room the arcs jump wider: the room's brightest line)
			var amp := 22.0 if game.arena.generated else 9.0
			var jit := 0.0 if j == segs else sin(t * 47.0 + k * 3.1 + j * 2.3) * amp * (1.0 - absf(u - 0.5) * 1.2)
			var q := p0 + d * u + n * jit
			gl.append(prev)
			gl.append(q)
			co.append(prev)
			co.append(q)
			prev = q
		if on_wall:
			wglow = gl
			wcore = co
		else:
			glow = gl
			core = co
	var bold: bool = game.arena.generated
	if wglow.size() > 0:
		draw_multiline(wglow, Pal.ink((0.12 if bold else 0.06) * dim, 1.4), 10.0 if bold else 6.0)
		draw_multiline(wcore, Pal.ink((0.95 if bold else 0.45) * dim, 2.6 if bold else 1.6), 3.0 if bold else 1.4)
	if glow.size() > 0:
		draw_multiline(glow, Pal.ink(0.05 * dim, 1.2), 5.0)
		draw_multiline(core, Pal.ink(0.95 * dim, 2.8), 2.0)
