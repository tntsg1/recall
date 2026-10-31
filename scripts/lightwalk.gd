class_name Lightwalk
extends Node2D
# Light-speed travel (from chapter 2): while you hold recall and the lines of
# your rounds glow red, a dodge that strikes one of those lines takes you into
# it — you run its length as light, toward whichever end your dodge leaned,
# cutting what stands on it (half a recall's hurt, and a shove). Run it to the
# round's end and you take the round back with you; run it to where it was
# fired from and the round stays where it is. A line can be run once; the
# dodge's cooldown is spent either way.
# The Lightrun school (game.lv.walk): 1 a run leaves its line burning; 2 for a
# moment after a run another lit line can be struck, twice over, cooldown free,
# and running does not use up the recall hold; 3 a run takes back the rounds it
# passes, each adding to that run's cut.

const SPEED := 3600.0        # px/s along the line
const REACH := 240.0         # how far ahead of you a dodge can strike a line
const CATCH := 34.0          # how near the dodge must pass to it
const CUT := 16.0            # how near a body on the line must stand to be cut
const OFF_WALL := 22.0       # where you come out, short of the round's wall
const BURN_LIFE := 1.5       # a light scar, in sim seconds
const BURN_TICK := 0.2
const BURN_R := 16.0
const CHAIN_WINDOW := 0.7    # real seconds to strike the next line
const CHAIN_MAX := 2         # further runs after the first
const CHAIN_REACH := 420.0
const LOAD_R := 130.0
const LOAD_GAIN := 0.25
const LOAD_MAX := 6          # rounds that count toward the bonus

var game
var on := false
var b = null                 # the round whose line you are running
var s := 0.0                 # where along its line you are
var to := 0.0                # where you will come out
var dir := 1.0               # +1 toward the round, -1 toward where it was fired from
var cut: Dictionary = {}     # enemies already cut this run
var flare := 0.0             # the burst as you enter the line (0..1)
var at_in := Vector2.ZERO


func _init() -> void:
	z_index = 4
	z_as_relative = false


# From chapter 2 on (the training yard and tests may force it).
var force := false


func available() -> bool:
	return force or game.chapter >= 1


var tip_t := -1.0            # the one-time hint by you, the first time a line can be run
var tip_done := false
var aim_b = null              # while you hold recall: the line a dodge now would take
var aim_s := 0.0
var aim_dir := 1.0
var burns: Array = []         # light scars: {pts, life, tick}
var burn = null               # the one being laid by the run under way
var chain_t := 0.0            # >0: the next line can be struck, free
var chain_n := 0              # further runs taken in this chain
var chain_owed := 0.0         # the cooldown that falls due if the chain ends here
var loaded := 0               # rounds taken back on this run
var run_hit := 0.0            # hurt dealt on this run: shown once, as you come out


func level() -> int:
	return int(game.lv.get("walk", 0))


# Running (and the moment after) does not use up the recall hold at level 2.
func holds_focus() -> bool:
	return level() >= 2 and (on or chain_t > 0.0)


# The line a dodge toward `move` would strike: [round, where along it, its way there] or [].
func _find(move: Vector2) -> Array:
	var p: Vector2 = game.player.pos
	var d: Vector2 = move.normalized() if move.length() > 0.1 else game.player.aim
	var q := p + d * (CHAIN_REACH if chain_t > 0.0 else REACH)
	var best = null
	var best_k := INF
	var best_s := 0.0
	var best_t := Vector2.ZERO
	for rb in game.bullets.list:
		if rb.state != Bullets.EMBED or rb.foe or rb.light <= 0.3 or rb.dark_by != 0 or rb.walked or rb.path.size() < 2:
			continue
		for i in range(1, rb.path.size()):
			var a: Vector2 = rb.path[i - 1]
			var c: Vector2 = rb.path[i]
			var cp := Geometry2D.get_closest_points_between_segments(p, q, a, c)
			if cp[0].distance_to(cp[1]) > CATCH:
				continue
			var k := p.distance_to(cp[0])
			if k < best_k:
				best_k = k
				best = rb
				best_s = rb.cum[i - 1] + a.distance_to(cp[1])
				best_t = (c - a).normalized()
	if best == null:
		return []
	return [best, best_s, 1.0 if d.dot(best_t) >= 0.0 else -1.0]


# A dodge pressed while you hold recall: take the line it strikes, if any.
func try_start(move: Vector2) -> bool:
	if on or not available() or not game.focusing or game.player.dash_cd > 0.0:
		return false
	var found := _find(move)
	if found.is_empty():
		return false
	if chain_t > 0.0:
		chain_n += 1
		chain_t = 0.0
	else:
		chain_n = 0
	loaded = 0
	run_hit = 0.0
	b = found[0]
	s = found[1]
	dir = found[2]
	to = maxf(0.0, b.total() - OFF_WALL) if dir > 0.0 else 0.0
	cut.clear()
	on = true
	flare = 1.0
	at_in = b.sample(s)
	b.walked = true
	if level() >= 1:
		burn = {"pts": PackedVector2Array([at_in]), "life": BURN_LIFE, "tick": 0.0}
		burns.append(burn)
	var pl = game.player
	pl.dash_cd = Player.DASH_CD * (0.6 if game.has("lightstep") else 1.0)
	pl.dash_t = 0.0
	pl.invuln = maxf(pl.invuln, absf(to - s) / SPEED + 0.2)
	pl.light = 0.6
	pl.streak.clear()
	pl.streak.append([pl.pos, 0.0])
	game.sfx.play("dash", 1.6, -3.0)
	game.sfx.play("release", 1.5, -8.0)
	game.fx.ring(at_in, 6.0, 46.0, 0.25, Pal.you(1.0, 2.4), 2.0)
	game.cam.add_trauma(0.06)
	return true


# Run on along the line (the player's own step has run; this places you).
func step(sdt: float) -> void:
	flare = maxf(0.0, flare - sdt / 0.25)
	_step_burns(sdt * game.slow)
	if chain_t > 0.0:
		chain_t -= sdt
		if chain_t <= 0.0 or not game.focusing:
			chain_t = 0.0
			game.player.dash_cd = maxf(game.player.dash_cd, chain_owed)
	aim_b = null
	if not on and available() and game.focusing and game.player.dash_cd <= 0.0 and not game.possess.busy():
		var found := _find(game._in_move())
		if not found.is_empty():
			aim_b = found[0]
			aim_s = found[1]
			aim_dir = found[2]
			# the first time it can be done: a short word by you, once a run
			if not tip_done and game.tutorial == null and not game.boss.alive():
				tip_done = true
				tip_t = 0.0
	# it would only sit over the cards or a boss's attacks
	if game.hud.cards_t >= 0.0 or game.boss.alive():
		tip_t = -1.0
	if tip_t >= 0.0:
		tip_t += sdt if not game.focusing else sdt * 3.0
		if tip_t > 3.2:
			tip_t = -1.0
	if not on:
		queue_redraw()
		return
	var pl = game.player
	var from: Vector2 = pl.pos
	var ns := move_toward(s, to, SPEED * sdt)
	var now: Vector2 = b.sample(ns)
	s = ns
	pl.pos = now
	pl.position = now
	pl.vel = Vector2.ZERO
	pl.streak.append([now, 0.0])
	pl.light = 0.6
	if burn != null:
		burn.pts.append(now)
	if level() >= 3:
		_take_rounds(from, now)
	# what stands on the line is cut as you pass
	var dmg: float = Bullets.RET_DMG * 0.5 * game.gun_dmg() * (1.0 + LOAD_GAIN * mini(loaded, LOAD_MAX))
	var going: Vector2 = (now - from).normalized() if now.distance_to(from) > 0.01 else Vector2.RIGHT
	for e in game.enemies.list:
		if e.state != Enemies.ALIVE or cut.has(e.id):
			continue
		if Geometry2D.get_closest_point_to_segment(e.pos, from, now).distance_to(e.pos) < e.r + CUT:
			cut[e.id] = true
			game.enemies.blast_hit(e, going, dmg, false)
			run_hit += dmg
			# cut through: a white slash across it, and it is thrown off the line
			e.knock += going.orthogonal() * (240.0 if going.orthogonal().dot(e.pos - now) >= 0.0 else -240.0)
			game.fx.sparks(e.pos, going, 8, Pal.you(1.0, 2.2), 520.0, 0.22, 0.6)
			game.fx.ring(e.pos, e.r * 0.5, e.r * 2.2, 0.18, Pal.you(0.9, 2.2), 2.0)
			# its tubes stutter where the light went through
			var outline := PackedVector2Array()
			var poly: PackedVector2Array = game.enemies._poly(e)
			var etr := Transform2D(e.rot, e.pos)
			for k in poly.size():
				outline.append(etr * poly[k])
			game.fx.power_off(outline, Pal.foe(1.0, 1.6), 0.2)
	if is_equal_approx(s, to):
		_arrive(going)
	queue_redraw()


func _arrive(going: Vector2) -> void:
	on = false
	var pl = game.player
	pl.vel = going * Player.SPEED
	pl.pos = game.arena.push_circle(pl.pos, Player.R)
	pl.position = pl.pos
	if dir > 0.0 and b != null and b.state == Bullets.EMBED:
		# the round's own end: you take it back with you
		game.bullets.send_home(b)
	game.fx.ring(pl.pos, 6.0, 40.0, 0.22, Pal.you(0.9, 2.2), 1.6)
	game.sfx.play("home", 1.8, -8.0)
	if run_hit > 0.0:
		game.fx.number(pl.pos + Vector2(0, -26), run_hit, true)
	b = null
	burn = null
	if level() >= 2 and chain_n < CHAIN_MAX and game.focusing:
		# refraction: the dodge comes straight back, for a moment
		chain_t = CHAIN_WINDOW
		chain_owed = pl.dash_cd
		pl.dash_cd = 0.0
		game.fx.ring(pl.pos, 10.0, 70.0, 0.3, Pal.you(0.7, 2.4), 2.0)
		game.sfx.play("lit", 1.3 + chain_n * 0.2, -6.0)


# Full Load: rounds near the run go home with you.
func _take_rounds(from: Vector2, now: Vector2) -> void:
	for rb in game.bullets.list:
		if rb == b or rb.state != Bullets.EMBED or rb.foe or rb.child or rb.filed or rb.dark_by != 0:
			continue
		if Geometry2D.get_closest_point_to_segment(rb.pos, from, now).distance_to(rb.pos) > LOAD_R:
			continue
		if rb.settled:
			rb.settled = false
			game.bullets.faint_dirty = true
		game.bullets.send_home(rb)
		loaded += 1
		game.fx.flash(rb.pos, 22.0, 0.16, Pal.you(0.8, 2.2))
		game.sfx.play("lit", 1.0 + minf(loaded, 12.0) * 0.08, -10.0)


# Light scars burn for a moment: everything touching one is hurt on each tick.
func _step_burns(dt: float) -> void:
	var i := 0
	while i < burns.size():
		var br: Dictionary = burns[i]
		if is_same(br, burn):
			i += 1
			continue
		br.life -= dt
		br.tick -= dt
		if br.tick <= 0.0:
			br.tick += BURN_TICK
			_burn_tick(br.pts)
		if br.life <= 0.0:
			burns.remove_at(i)
		else:
			i += 1
	if not burns.is_empty():
		queue_redraw()


func _burn_tick(pts: PackedVector2Array) -> void:
	var dmg: float = Bullets.RET_DMG * 0.2 * game.gun_dmg()
	for e in game.enemies.list:
		if e.state != Enemies.ALIVE:
			continue
		for k in pts.size() - 1:
			if Geometry2D.get_closest_point_to_segment(e.pos, pts[k], pts[k + 1]).distance_to(e.pos) < e.r + BURN_R:
				game.enemies.burn_hit(e, (pts[k + 1] - pts[k]).normalized(), dmg)
				break
	var boss = game.boss
	if boss == null or not boss.alive():
		return
	for k in pts.size() - 1:
		var bh: Dictionary = boss.hit_test(pts[k], pts[k + 1])
		if bh and bh.get("core", false):
			boss.damage(dmg * bh.get("mult", 1.0), false, bh.point, (pts[k + 1] - pts[k]).normalized(), bh.get("frame", -1))
			break


# A run cut short (a new room, the wave over, you hurt).
func stop() -> void:
	on = false
	b = null
	burn = null
	burns.clear()
	chain_t = 0.0


func _draw() -> void:
	for br in burns:
		var fade: float = clampf(br.life / 0.5, 0.0, 1.0)
		var flick := 0.8 + 0.2 * sin(game.real_time * 37.0 + br.pts.size())
		Fx.tube(self, br.pts, Pal.red(0.8 * fade * flick, 2.6), 3.0, 16.0, 0.16)
	if chain_t > 0.0:
		var ck := chain_t / CHAIN_WINDOW
		draw_arc(game.player.pos, 26.0, -PI * 0.5, -PI * 0.5 + TAU * ck, 32, Pal.you(0.9, 2.4), 2.0)
	if tip_t >= 0.0:
		var ta := clampf(tip_t / 0.25, 0.0, 1.0) * clampf((3.2 - tip_t) / 0.4, 0.0, 1.0)
		var font := Fonts.get_font("SemiBold")
		var txt := Txt.t("lightwalk_tip")
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var at: Vector2 = game.player.pos + Vector2(-tw / 2.0, -58.0)
		draw_rect(Rect2(at + Vector2(-12, -26), Vector2(tw + 24, 36)), Color(0, 0, 0, 0.8 * ta))
		draw_rect(Rect2(at + Vector2(-12, -26), Vector2(tw + 24, 36)), Pal.you(0.6 * ta, 1.6), false, 1.5)
		draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.you(ta, 1.6))
	# holding recall: the line a dodge would take now stands out, an arrow at its way in
	if aim_b != null and not on:
		var pts := PackedVector2Array()
		for j in 25:
			pts.append(aim_b.sample(aim_b.total() * j / 24.0))
		var pulse := 0.75 + 0.25 * sin(game.real_time * 9.0)
		Fx.tube(self, pts, Pal.you(0.55 * pulse, 2.0), 2.5, 10.0, 0.1)
		var ip: Vector2 = aim_b.sample(aim_s)
		var ia: Vector2 = aim_b.sample(clampf(aim_s + 12.0 * aim_dir, 0.0, aim_b.total()))
		var fd := (ia - ip).normalized() if ia.distance_to(ip) > 0.1 else Vector2.RIGHT
		var tip := ip + fd * 14.0
		draw_polyline(PackedVector2Array([tip - fd * 10.0 + fd.orthogonal() * 7.0, tip, tip - fd * 10.0 - fd.orthogonal() * 7.0]), Pal.you(pulse, 2.4), 2.5)
		draw_arc(ip, 9.0, 0.0, TAU, 20, Pal.you(0.8 * pulse, 2.2), 1.5)
	if flare > 0.0:
		var r := 18.0 + 30.0 * (1.0 - flare)
		draw_arc(at_in, r, 0.0, TAU, 32, Pal.you(0.8 * flare, 2.4), 2.0)
	if not on or b == null:
		return
	# the rest of the line ahead of you, lit white as you run it
	var ahead := PackedVector2Array()
	var steps := 16
	for j in steps + 1:
		ahead.append(b.sample(lerpf(s, to, float(j) / steps)))
	Fx.tube(self, ahead, Pal.you(0.55, 2.0), 2.0, 12.0, 0.1)
