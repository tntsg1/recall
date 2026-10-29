class_name Zero
extends Node2D
# 归零 ZERO — the First Chairman (chapter 12), in two stages.
#
# The body: a second you, built from your own protocol. It fires its rounds
# into the walls and every few seconds recalls them — that return cuts you
# (the lines light up first). Your own shots barely touch it; hold Q and its
# rounds light up for you too: recall them yourself and they fly its paths
# back, then on into it. Second phase: it dashes and fires wider fans. Third:
# echoes of you.
#
# The man: the body broken, the Chairman's mind leaves it — a signal that
# hides in the shells on the floor, hopping between them. Mark the one he is
# in with a recall and seize it: he is thrown out, and goes for your body —
# the one body he cannot take over. While he is out he can be hurt; three
# times he is driven back into a shell, and the third time he does not come
# back. Shares the boss interface.

enum { OFF, ENTER, RUN, DYING, DEAD }
enum { IN, TRAVEL, OUT }

const HP := 3000.0
const SIGNAL_HP := 600.0
const R := 44.0
const SIG_R := 20.0
const HOME := Vector2(960, 540)    # the seal at the centre of the hall
const VOLLEY := [5.0, 4.5, 4.0]
const SHOTS := [8, 12, 16]
const RECALL_EVERY := [9.0, 8.0, 6.0]
const STEAL_DMG := 30.0
const BREAK_TIME := 2.6       # the body going down, before the man comes out
const HOP_EVERY := 7.5        # unbothered, he changes shells this often
const TRAVEL_TIME := 0.55
const OUT_HOLD := 0.7         # thrown out: a moment of stillness, then he comes for you
const OUT_SPEED := 330.0
const OUT_MAX := 6.5          # then he dives into the nearest shell anyway
const SIG_MULT := 2.5
const VESSELS := [Enemies.CHASER, Enemies.GUARD, Enemies.CHARGER, Enemies.LEECH, Enemies.PRISM]

var game
var state := OFF
var t := 0.0
var hp := HP
var phase := 0
var pos := HOME
var vel := Vector2.ZERO
var aim := Vector2.DOWN
var guard_t := 0.0
var flash := 0.0
var red := 0.0
var core_open := 1.0
var enter_t := 0.0
var dying_t := 0.0
var volley_cd := 2.0
var recall_cd := 9.0
var warned := false
var dash_cd := 3.0
var dash_t := 0.0
var ghosts: Array = []
var echo_cd := 6.0
var orbit_dir := 1.0
# the second stage
var stage := 0                 # 0 the body, 1 the man
var break_t := -1.0
var wreck := Vector2.ZERO
var sig := Vector2.ZERO        # where the signal is
var mode := IN
var mode_t := 0.0
var vessel = null              # the shell he is in
var travel_from := Vector2.ZERO
var band := 0                  # times he has been driven back in
var spoke := 0
var spawn_cd := 0.0
var trail: Array = []          # [pos, age]
var out_from := 0.0            # how far off you he was thrown out


func _ready() -> void:
	z_index = 4
	z_as_relative = false


func max_hp() -> float:
	return SIGNAL_HP if stage == 1 else HP


func name_key() -> String:
	return "boss_chairman" if stage == 1 else "boss_5"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


func begin_track() -> void:
	state = OFF
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	_fresh()
	game.sfx.play("horn", 1.8, -4.0)
	game.cam.add_trauma(0.3)
	game.hud.radio(Txt.t("chair_0"), "chair_tag")


func reset() -> void:
	state = OFF
	t = 0.0
	enter_t = 0.0
	_fresh()


func _fresh() -> void:
	hp = HP
	phase = 0
	pos = HOME
	guard_t = 0.0
	volley_cd = 2.0
	recall_cd = RECALL_EVERY[0]
	warned = false
	ghosts.clear()
	stage = 0
	break_t = -1.0
	vessel = null
	band = 0
	spoke = 0
	trail.clear()
	core_open = 1.0


func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	if stage == 0:
		damage(HP, false, pos, Vector2.UP)
	elif mode == OUT:
		damage(SIGNAL_HP, false, sig, Vector2.UP)


func core_pos() -> Vector2:
	if stage == 1:
		return sig
	return pos


func core_vel() -> Vector2:
	return vel if stage == 0 else Vector2.ZERO


# ---------------------------------------------------------------- bullets

func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	if stage == 1:
		if mode != OUT or mode_t < 0.15:
			return {}
		var hs := Geometry2D.segment_intersects_circle(a, b, sig, SIG_R + 6.0)
		if hs < 0.0:
			return {}
		var ps := a + (b - a) * hs
		return {"point": ps, "normal": (ps - sig).normalized(), "core": true, "mult": SIG_MULT}
	if break_t >= 0.0:
		return {}
	var hb := Geometry2D.segment_intersects_circle(a, b, pos, R)
	if hb < 0.0:
		return {}
	var p := a + (b - a) * hb
	# your own rounds barely mark it
	return {"point": p, "normal": (p - pos).normalized(), "core": true, "mult": 0.2}


func on_armor(_k: int, _at: Vector2, _n: Vector2) -> void:
	pass


# One of its own rounds, recalled by you, flies home into it.
func stolen_hit(at_p: Vector2) -> void:
	if state != RUN or stage != 0 or break_t >= 0.0:
		return
	damage(STEAL_DMG, true, at_p, (pos - at_p).normalized())
	game.steals += 1
	if game.steals >= 12:
		game.ach("steal12")
	game.fx.ring(pos, R, R * 3.0, 0.3, Pal.red(1.0, 2.6), 2.5)


func damage(dmg: float, ret: bool, at_p: Vector2, d: Vector2, _frame_k: int = -1) -> void:
	if state != RUN:
		return
	if stage == 1:
		_signal_damage(dmg, ret, at_p, d)
		return
	if break_t >= 0.0:
		return
	dmg /= Loadout.boss_hp()
	var floor_hp := HP * (1.0 - (phase + 1) / 3.0) if phase < 2 else 0.0
	if guard_t > 0.0:
		floor_hp = maxf(floor_hp, hp)
	hp = maxf(floor_hp - (0.001 if guard_t <= 0.0 else 0.0), hp - dmg)
	flash = 1.0
	if ret:
		red = 1.0
	game.fx.number(at_p, dmg, ret)
	var c := Pal.red(1.0, 3.2) if ret else Pal.foe(1.0, 1.8)
	game.fx.sparks(at_p, d, 6 if ret else 3, c, 500.0, 0.25, 0.8)
	game.on_target_hit(ret)
	var want := clampi(int((1.0 - hp / HP) * 3.0), 0, 2)
	while phase < want:
		phase += 1
		guard_t = 1.4
		game.fx.ring(pos, R, 360.0, 0.6, Pal.foe(0.9, 1.5), 3.0)
		game.sfx.play("armor", 1.4, 0.0)
		game.add_hitstop(0.09)
		game.cam.add_trauma(0.6)
		game.cam.punch(0.04)
		game.hud.boss_phase()
		game.hud.radio(Txt.t("chair_%d" % phase), "chair_tag")
	if hp <= 0.0:
		_body_down()


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	if enter_t > 0.0 and enter_t < 1.0 and state == OFF:
		enter_t = minf(1.0, enter_t + dt / 2.4)
	if state == OFF or state == DEAD:
		queue_redraw()
		return
	t += dt
	flash = maxf(0.0, flash - dt / 0.12)
	red = maxf(0.0, red - dt / 0.8)
	guard_t = maxf(0.0, guard_t - dt)
	var i := 0
	while i < ghosts.size():
		ghosts[i][1] += dt
		if ghosts[i][1] > 0.3:
			ghosts.remove_at(i)
		else:
			i += 1
	i = 0
	while i < trail.size():
		trail[i][1] += dt
		if trail[i][1] > 0.5:
			trail.remove_at(i)
		else:
			i += 1
	var pl: Vector2 = game.player.pos
	match state:
		ENTER:
			if t >= 0.8:
				state = RUN
				t = 0.0
		RUN:
			if stage == 0:
				if break_t >= 0.0:
					_breaking(dt)
				else:
					_run(dt, pl)
			else:
				_man(dt, pl)
		DYING:
			_dying(dt)
	queue_redraw()


func _run(dt: float, pl: Vector2) -> void:
	var to := pl - pos
	aim = aim.slerp(to.normalized(), 1.0 - exp(-8.0 * dt))
	# keep its distance and circle, as you would
	if dash_t > 0.0:
		dash_t -= dt
		ghosts.append([pos, 0.0])
	else:
		var radial := to.normalized() * clampf((to.length() - 420.0) / 150.0, -1.0, 1.0)
		var around := to.orthogonal().normalized() * orbit_dir * 0.7
		vel = Pal.damp2(vel, (radial + around).normalized() * 260.0, 3.0, dt)
		if phase >= 1:
			dash_cd -= dt
			if dash_cd <= 0.0:
				dash_cd = randf_range(2.5, 3.5)
				dash_t = 0.15
				vel = (to.orthogonal().normalized() * orbit_dir + to.normalized() * 0.3).normalized() * 1300.0
				orbit_dir = -orbit_dir
				game.sfx.play("dash", 0.8, -6.0)
	pos += vel * dt
	pos = game.arena.push_circle(pos, R)
	pos = pos.clamp(Arena.ROOM.position + Vector2(R, R), Arena.ROOM.end - Vector2(R, R))
	if pos.distance_to(pl) < R + Player.R - 4.0:
		game.on_player_hit((pl - pos).normalized(), null)
	# a fan of its own rounds, aimed past you so their way back crosses your ground
	volley_cd -= dt
	if volley_cd <= 0.0:
		volley_cd = VOLLEY[phase]
		var n: int = SHOTS[phase]
		for k in n:
			var a := to.angle() + lerpf(-0.9, 0.9, (k + 0.5) / n)
			game.bullets.fire_foe(pos + Vector2.from_angle(a) * (R + 8.0), Vector2.from_angle(a))
		game.sfx.play("shot", 0.7, -2.0)
		game.fx.ring(pos, R, R + 26.0, 0.2, Pal.foe(0.7, 1.4), 1.5)
	# it calls them home — the lines light up first
	recall_cd -= dt
	if recall_cd <= 0.8 and not warned:
		warned = true
		game.bullets.zero_light()
		game.sfx.play("focus", 1.4, -6.0)
	if recall_cd <= 0.0:
		recall_cd = RECALL_EVERY[phase]
		warned = false
		if game.bullets.zero_recall() > 0:
			game.sfx.play("release", 0.8, -3.0)
			game.cam.add_trauma(0.2)
	if phase >= 2:
		echo_cd -= dt
		if echo_cd <= 0.0:
			echo_cd = 12.0
			for k2 in 2:
				game.enemies.spawn(Enemies.ECHO, pos + Vector2.from_angle(randf() * TAU) * 60.0, k2 * 0.2)


# The body is broken: it stands, shaking, and comes apart — and something
# leaves it.
func _body_down() -> void:
	break_t = 0.0
	wreck = pos
	vel = Vector2.ZERO
	game.bullets.clear_foe()
	game.add_hitstop(0.09)
	game.cam.add_trauma(0.9)
	game.cam.punch(0.07)
	game.sfx.play("boss_die", 0.8, -2.0)
	game.victory_slow = 0.7
	game.hud.radio(Txt.t("chair_break"), "chair_tag")
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE:
			game.enemies.blast_hit(e, (e.pos - pos).normalized(), 9999.0)


func _breaking(dt: float) -> void:
	break_t += dt
	pos = wreck + Vector2(sin(break_t * 70.0), cos(break_t * 61.0)) * 3.0 * (1.0 - break_t / BREAK_TIME)
	if int(break_t * 8.0) != int((break_t - dt) * 8.0):
		game.fx.sparks(pos + Vector2.from_angle(randf() * TAU) * R, Vector2.from_angle(randf() * TAU), 4, Pal.foe(1.0, 1.8), 380.0, 0.3, 1.0)
		game.sfx.play("cross", randf_range(0.6, 0.9), -8.0)
	if break_t >= BREAK_TIME:
		# the shell of it falls apart; the man comes out
		for k in 12:
			var a := TAU * k / 12.0
			var p0 := Vector2.from_angle(a) * R
			var p1 := Vector2.from_angle(a + TAU / 12.0) * R
			game.fx.shard(wreck + (p0 + p1) * 0.5, (p0 - p1) * 0.5, (p1 - p0) * 0.5, p0.normalized() * randf_range(200, 420), randf_range(-8, 8), 2.0, Pal.foe(1.0, 1.8), 3.0)
		stage = 1
		hp = SIGNAL_HP
		phase = 0
		guard_t = 0.0
		sig = wreck
		game.fx.flash(wreck, 160.0, 0.35, Pal.ink(0.8, 2.2))
		game.fx.ring(wreck, 10.0, 420.0, 0.6, Pal.ink(0.9, 2.0), 3.0)
		game.hud.boss_phase()
		game.hud.flash_text(Txt.t("chair_hint"))
		for k in 4:
			_spawn_vessel(k * 0.15)
		mode = OUT
		mode_t = OUT_HOLD + 0.2
		_dive()


func _spawn_vessel(delay: float) -> void:
	var at := Vector2.ZERO
	for tries in 30:
		at = Vector2(randf_range(260, 1660), randf_range(200, 880))
		if at.distance_to(game.player.pos) > 360.0 and game.arena.is_free(at, 30.0):
			break
	game.enemies.spawn(VESSELS[randi() % VESSELS.size()], at, delay)


func _alive_shells() -> Array:
	var out: Array = []
	for e in game.enemies.list:
		if (e.state == Enemies.ALIVE or e.state == Enemies.SPAWN or e.state == Enemies.WARN) and Possess.KINDS.has(e.kind):
			out.append(e)
	return out


# Into the nearest shell (away from you if he can), flying there.
func _dive(avoid = null) -> void:
	var best = null
	var bd := INF
	for e in _alive_shells():
		if e == avoid or e.state != Enemies.ALIVE:
			continue
		var d: float = e.pos.distance_to(sig) - e.pos.distance_to(game.player.pos) * 0.35
		if d < bd:
			bd = d
			best = e
	if best == null:
		# nothing to hide in yet: he waits where he is, out in the open
		mode = OUT
		mode_t = 0.0
		return
	vessel = best
	mode = TRAVEL
	mode_t = 0.0
	travel_from = sig
	game.sfx.play("p_possess", 0.7, -6.0)


func _man(dt: float, pl: Vector2) -> void:
	mode_t += dt
	# keep the floor stocked with shells for him
	spawn_cd -= dt
	if spawn_cd <= 0.0:
		spawn_cd = 1.8
		if _alive_shells().size() < 5:
			_spawn_vessel(0.0)
	# your seizing comes back quickly while he is loose
	game.possess.cooldown = minf(game.possess.cooldown, 1.2)
	match mode:
		TRAVEL:
			var to: Vector2 = vessel.pos if vessel != null and vessel.state == Enemies.ALIVE else sig
			var k := clampf(mode_t / TRAVEL_TIME, 0.0, 1.0)
			var e := Pal.ease_io(k)
			var mid := travel_from.lerp(to, 0.5) + (to - travel_from).orthogonal().normalized() * travel_from.distance_to(to) * 0.25
			sig = travel_from.lerp(mid, e).lerp(mid.lerp(to, e), e)
			trail.append([sig, 0.0])
			if vessel == null or vessel.state != Enemies.ALIVE:
				_dive()
			elif k >= 1.0:
				mode = IN
				mode_t = 0.0
				vessel.hp = maxf(vessel.hp, vessel.maxhp * 2.0)
				vessel.maxhp = maxf(vessel.maxhp, vessel.hp)
				game.fx.ring(vessel.pos, 6.0, 60.0, 0.3, Pal.ink(0.9, 2.0), 2.0)
		IN:
			if game.possess.hosting() and game.possess.shell == vessel:
				_thrown_out()
			elif vessel == null or vessel.state != Enemies.ALIVE:
				# the shell he was in is gone: on to another
				_dive()
			else:
				sig = vessel.pos
				if mode_t >= HOP_EVERY:
					_dive(vessel)
		OUT:
			if mode_t > OUT_HOLD:
				# he goes for your body
				var d := pl - sig
				var sp := OUT_SPEED * (1.0 + 0.15 * band)
				sig += d.normalized() * minf(sp * dt, d.length()) + d.orthogonal().normalized() * sin(t * 5.0) * 60.0 * dt
				trail.append([sig, 0.0])
				if sig.distance_to(pl) < SIG_R + Player.R:
					game.on_player_hit(d.normalized(), null)
					_dive()
				elif mode_t >= OUT_MAX:
					_dive()


func _thrown_out() -> void:
	mode = OUT
	mode_t = 0.0
	# flung out of the shell (you are in it): well clear of you, then he turns back
	var away := Vector2.from_angle(randf() * TAU)
	var room := Arena.ROOM.grow(-80.0)
	var flung: Vector2 = vessel.pos + away * 340.0
	if not room.has_point(flung):
		flung = vessel.pos - away * 340.0
	travel_from = vessel.pos
	sig = flung.clamp(room.position, room.end)
	vessel = null
	out_from = maxf(120.0, sig.distance_to(game.player.pos))
	game.fx.flash(sig, 70.0, 0.2, Pal.ink(0.8, 2.2))
	game.fx.ring(sig, 6.0, 120.0, 0.4, Pal.ink(1.0, 2.2), 3.0)
	game.fx.ring(travel_from, 6.0, 90.0, 0.3, Pal.ink(0.8, 2.0), 2.0)
	for k in 8:
		game.fx.spark(travel_from.lerp(sig, k / 8.0), (sig - travel_from).normalized() * 300.0, 0.25, Pal.ink(0.9, 2.0), 1.0, 4.0)
	game.sfx.play("crit", 0.7, -2.0)
	game.cam.add_trauma(0.35)
	game.add_hitstop(0.05)
	if spoke < 3:
		game.hud.radio(Txt.t("chair_out_%d" % spoke), "chair_tag")
		spoke += 1


func _signal_damage(dmg: float, ret: bool, at_p: Vector2, d: Vector2) -> void:
	if mode != OUT:
		return
	dmg /= Loadout.boss_hp()
	var floor_hp := SIGNAL_HP * (1.0 - (band + 1) / 3.0) if band < 2 else 0.0
	if guard_t > 0.0:
		floor_hp = maxf(floor_hp, hp)
	hp = maxf(floor_hp - (0.001 if guard_t <= 0.0 else 0.0), hp - dmg)
	flash = 1.0
	if ret:
		red = 1.0
	sig += d * 18.0
	game.fx.number(at_p, dmg, ret)
	game.fx.sparks(at_p, d, 8, Pal.red(1.0, 3.0) if ret else Pal.ink(1.0, 2.0), 520.0, 0.25, 0.9)
	game.on_target_hit(ret)
	var want := clampi(int((1.0 - hp / SIGNAL_HP) * 3.0), 0, 2)
	if hp <= 0.0:
		state = DYING
		dying_t = 0.0
		game.hud.radio(Txt.t("chair_end"), "chair_tag")
		game.on_boss_dying()
		return
	while band < want:
		band += 1
		phase = band
		guard_t = 1.2
		game.hud.boss_phase()
		game.fx.ring(sig, 10.0, 260.0, 0.5, Pal.ink(0.9, 2.0), 3.0)
		game.sfx.play("armor", 1.6, -2.0)
		game.add_hitstop(0.08)
		game.cam.add_trauma(0.5)
		# driven back into a shell
		_dive()


func _dying(dt: float) -> void:
	dying_t += dt
	game.bullets.clear_foe()
	if stage == 1:
		sig += Vector2(sin(dying_t * 60.0), cos(dying_t * 53.0)) * 1.5 * dying_t
		if int(dying_t * 10.0) != int((dying_t - dt) * 10.0):
			game.fx.ring(sig, 2.0, 30.0 + dying_t * 40.0, 0.3, Pal.ink(0.7, 1.8), 1.5)
	if dying_t >= 2.0:
		state = DEAD
		var at := core_pos()
		for k in 16:
			var a := TAU * k / 16.0
			game.fx.sparks(at, Vector2.from_angle(a), 2, Pal.ink(1.0, 2.2), 600.0, 0.5, 0.3)
		game.on_boss_dead(at)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if state == OFF:
		if enter_t > 0.0:
			# a ring of ticks closes in where it will stand
			var e := Pal.ease_io(enter_t)
			for k in 24:
				var d := Vector2.from_angle(TAU * k / 24.0 + enter_t * 2.0)
				var r := lerpf(260.0, R + 6.0, e)
				draw_line(HOME + d * r, HOME + d * (r + 8.0), Pal.foe(0.6 * e * dim), 1.5)
		return
	if state == DEAD:
		return
	if stage == 1:
		_draw_man(dim)
		return
	for g in ghosts:
		var k2: float = 1.0 - g[1] / 0.3
		draw_arc(g[0], R * 0.9, 0.0, TAU, 32, Pal.foe(0.3 * k2 * dim), 1.5, false)
	var appear := Pal.back(clampf(t / 0.8, 0.0, 1.0)) if state == ENTER else 1.0
	# it looks like you, inverted: a hollow disc with a solid notch
	var col := Pal.foe(dim, 1.0 + 0.8 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	if break_t >= 0.0:
		# coming apart: cracks across it, the light inside showing
		var bk := clampf(break_t / BREAK_TIME, 0.0, 1.0)
		col = Pal.foe(dim, 1.0 + 1.6 * bk)
		for j in 5:
			var a0 := j * 1.3 + 0.4
			draw_line(pos + Vector2.from_angle(a0) * R * 0.2, pos + Vector2.from_angle(a0 + 0.2) * R * (0.4 + 0.8 * bk), Pal.ink((0.4 + 0.6 * bk) * dim, 2.0 + bk), 1.5)
		draw_circle(pos, R * 0.5 * bk, Pal.ink(0.6 * bk * dim, 2.2))
	draw_arc(pos, R * appear, 0.0, TAU, 48, col, 3.0, false)
	draw_arc(pos, R * 0.62 * appear, 0.0, TAU, 40, Pal.foe(0.35 * dim), 1.0, false)
	var a := aim.angle()
	var notch := PackedVector2Array([pos + Vector2.from_angle(a - 0.32) * R * appear, pos + Vector2.from_angle(a) * R * 0.3 * appear, pos + Vector2.from_angle(a + 0.32) * R * appear])
	draw_colored_polygon(notch, col)
	# its own magazine ring counts down to the next volley
	var n: int = SHOTS[phase]
	var left := clampf(volley_cd / VOLLEY[phase], 0.0, 1.0)
	for k in n:
		var d2 := Vector2.from_angle(-PI / 2.0 + TAU * k / n)
		var on := float(k) / n < 1.0 - left
		draw_line(pos + d2 * (R + 6.0), pos + d2 * (R + 11.0), Pal.foe(0.7 if on else 0.15, 1.0), 1.5)


# The man: the broken body left lying where it fell; the signal — a mote of
# white with a tail — and, round the shell he is in, a crown of three ticks
# and his title, so you can tell which one to take.
func _draw_man(dim: float) -> void:
	# the wreck
	draw_arc(wreck, R, 0.3, TAU - 0.5, 40, Pal.foe(0.3 * dim), 2.0, false)
	draw_line(wreck + Vector2(-R * 0.6, -R * 0.2), wreck + Vector2(R * 0.4, R * 0.5), Pal.foe(0.25 * dim), 1.5)
	var font := Fonts.get_font("SemiBold")
	for tr in trail:
		var k: float = 1.0 - tr[1] / 0.5
		draw_circle(tr[0], 4.0 * k + 1.0, Pal.ink(0.35 * k * dim, 1.6))
	if mode == IN and vessel != null and vessel.state == Enemies.ALIVE:
		# the shell he is in: a lit halo a step brighter than anything on the
		# floor, a slow crown of light turning over it, and his title
		var vp: Vector2 = vessel.pos
		var vr: float = vessel.r
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		draw_circle(vp, vr + 26.0, Color(1, 1, 1, 0.06 + 0.04 * pulse))
		draw_arc(vp, vr + 16.0, 0.0, TAU, 40, Pal.ink((0.8 + 0.2 * pulse) * dim, 2.2), 3.0)
		draw_arc(vp, vr + 24.0, 0.0, TAU, 40, Pal.ink(0.3 * dim, 1.4), 1.0)
		for j in 5:
			var ra := t * 0.8 + TAU * j / 5.0
			var d := Vector2.from_angle(ra)
			draw_line(vp + d * (vr + 28.0), vp + d * (vr + 40.0), Pal.ink(0.75 * dim, 2.0), 2.5)
		var top := vp + Vector2(0, -vr - 52.0)
		for j in 3:
			var x := (j - 1) * 11.0
			draw_line(top + Vector2(x, 6), top + Vector2(x, -6 - (6.0 if j == 1 else 0.0)), Pal.ink(dim, 2.2), 3.0)
		draw_line(top + Vector2(-14, 6), top + Vector2(14, 6), Pal.ink(dim, 2.2), 3.0)
		var lab := Txt.t("chair_tag")
		var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_rect(Rect2(top + Vector2(-lw * 0.5 - 6.0, -36.0), Vector2(lw + 12.0, 20.0)), Color(0, 0, 0, 0.6))
		draw_string(font, top + Vector2(-lw * 0.5, -20.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.95 * dim, 1.6))
		# and a thin line from the shell he left behind, fading
		if mode_t < 0.6:
			draw_line(travel_from, vp, Pal.ink(0.4 * (1.0 - mode_t / 0.6) * dim, 1.6), 1.5)
		# how long until he moves on
		var hk := clampf(mode_t / HOP_EVERY, 0.0, 1.0)
		draw_arc(vp, vr + 46.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - hk), 40, Pal.ink(0.4 * dim), 1.5)
		return
	# out (or on his way): the signal itself
	var c := sig
	var hot := flash
	var out := mode == OUT
	var r := SIG_R * (1.0 + 0.12 * sin(t * 11.0))
	draw_circle(c, r + 18.0, Color(0, 0, 0, 0.45))
	for j in 3:
		draw_arc(c, r + 6.0 + j * 6.0, t * (2.0 + j) + j, t * (2.0 + j) + j + PI * 1.2, 16, Pal.ink((0.5 - j * 0.12) * dim, 1.6), 1.5)
	draw_circle(c, r, Pal.ink((0.9 if out else 0.6) * dim, 2.0 + 0.8 * hot).lerp(Pal.red(dim, 2.6), red * 0.6))
	draw_circle(c, r * 0.45, Color(0.02, 0.02, 0.025))
	if out:
		# reaching for your body: two hands of light held out toward you
		var pl: Vector2 = game.player.pos
		var d := pl - c
		var l := d.length()
		var u := d / maxf(l, 0.001)
		var reach := clampf(mode_t / OUT_HOLD, 0.0, 1.0)
		for sgn: float in [-1.0, 1.0]:
			var base := c + u.orthogonal() * sgn * r * 0.9
			var wrist := base + u.rotated(sgn * 0.35) * (r + 16.0) * reach
			var tip := wrist + u.rotated(-sgn * 0.2) * 18.0 * reach
			draw_polyline(PackedVector2Array([base, wrist, tip]), Pal.ink(0.85 * dim, 2.0), 3.0)
			for f2 in 3:
				draw_line(tip, tip + u.rotated((f2 - 1) * 0.45) * 9.0 * reach, Pal.ink(0.7 * dim, 1.8), 1.5)
		if mode_t > OUT_HOLD:
			var seg := PackedVector2Array()
			var s0 := r + 30.0 + fmod(t * 120.0, 24.0)
			while s0 < l - Player.R - 8.0:
				seg.append(c + u * s0)
				seg.append(c + u * minf(s0 + 12.0, l - Player.R - 8.0))
				s0 += 24.0
			if seg.size() > 0:
				draw_multiline(seg, Pal.red(0.85 * dim, 2.0), 4.0)
			# how close he has come, as a ring closing round you
			var ck := clampf(1.0 - (l - SIG_R - Player.R) / maxf(out_from, 1.0), 0.0, 1.0)
			draw_arc(pl, Player.R + 16.0, -PI * 0.5, -PI * 0.5 + TAU * ck, 40, Pal.red(0.95 * dim, 2.2), 3.0)
			var lab2 := Txt.t("chair_taking")
			var lw2 := font.get_string_size(lab2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var lp := c + Vector2(-lw2 * 0.5, -r - 34.0)
			draw_rect(Rect2(lp + Vector2(-6, -17), Vector2(lw2 + 12.0, 22.0)), Color(0, 0, 0, 0.6))
			draw_string(font, lp, lab2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.red(dim, 2.0))
