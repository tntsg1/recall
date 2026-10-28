class_name Zero
extends Node2D
# 归零 ZERO: a second you. It fires its own rounds into the walls and, every few
# seconds, recalls them — that return cuts you (the lines light up first).
# Your own shots barely touch it. But when you hold Q its rounds light up for
# you too: recall them yourself and they fly its paths back, then on into it.
# Phase 2 (66%): it dashes and fires wider fans. Phase 3 (33%): echoes of you.
# Shares the boss interface.

enum { OFF, ENTER, RUN, DYING, DEAD }

const HP := 3600.0
const R := 30.0
const HOME := Vector2(960, 300)
const VOLLEY := [5.0, 4.5, 4.0]
const SHOTS := [8, 12, 16]
const RECALL_EVERY := [9.0, 8.0, 6.0]
const STEAL_DMG := 30.0

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


func _ready() -> void:
	z_index = 4
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_5"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


func begin_track() -> void:
	state = OFF
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	hp = HP
	phase = 0
	pos = HOME
	volley_cd = 2.0
	recall_cd = RECALL_EVERY[0]
	warned = false
	game.sfx.play("horn", 1.8, -4.0)
	game.cam.add_trauma(0.3)


func reset() -> void:
	state = OFF
	t = 0.0
	hp = HP
	phase = 0
	pos = HOME
	enter_t = 0.0
	guard_t = 0.0
	ghosts.clear()


func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	damage(HP, false, pos, Vector2.UP)


func core_pos() -> Vector2:
	return pos


func core_vel() -> Vector2:
	return vel


# ---------------------------------------------------------------- bullets

func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
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
	if state != RUN:
		return
	damage(STEAL_DMG, true, at_p, (pos - at_p).normalized())
	game.steals += 1
	if game.steals >= 12:
		game.ach("steal12")
	game.fx.ring(pos, R, R * 3.0, 0.3, Pal.red(1.0, 2.6), 2.5)


func damage(dmg: float, ret: bool, at_p: Vector2, d: Vector2, _frame_k: int = -1) -> void:
	if state != RUN:
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
	var c := Pal.red(1.0, 3.2) if ret else Pal.ink(1.0, 1.8)
	game.fx.sparks(at_p, d, 6 if ret else 3, c, 500.0, 0.25, 0.8)
	game.on_target_hit(ret)
	var want := clampi(int((1.0 - hp / HP) * 3.0), 0, 2)
	while phase < want:
		phase += 1
		guard_t = 1.4
		game.fx.ring(pos, R, 360.0, 0.6, Pal.ink(0.9, 1.5), 3.0)
		game.sfx.play("armor", 1.4, 0.0)
		game.add_hitstop(0.09)
		game.cam.add_trauma(0.6)
		game.cam.punch(0.04)
		game.hud.boss_phase()
	if hp <= 0.0:
		state = DYING
		dying_t = 0.0
		game.on_boss_dying()


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
	var pl: Vector2 = game.player.pos
	match state:
		ENTER:
			if t >= 0.8:
				state = RUN
				t = 0.0
		RUN:
			_run(dt, pl)
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
		game.fx.ring(pos, R, R + 26.0, 0.2, Pal.ink(0.7, 1.4), 1.5)
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


func _dying(dt: float) -> void:
	dying_t += dt
	game.bullets.clear_foe()
	pos += Vector2(sin(dying_t * 60.0), cos(dying_t * 53.0)) * 2.0 * dying_t
	if dying_t >= 1.6:
		state = DEAD
		for k in 12:
			var a := TAU * k / 12.0
			var p0 := Vector2.from_angle(a) * R
			var p1 := Vector2.from_angle(a + TAU / 12.0) * R
			game.fx.shard(pos + (p0 + p1) * 0.5, (p0 - p1) * 0.5, (p1 - p0) * 0.5, p0.normalized() * randf_range(200, 420), randf_range(-8, 8), 2.0, Pal.ink(1.0, 1.8), 3.0)
		game.on_boss_dead(pos)


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
				draw_line(HOME + d * r, HOME + d * (r + 8.0), Pal.ink(0.6 * e * dim), 1.5)
		return
	if state == DEAD:
		return
	for g in ghosts:
		var k2: float = 1.0 - g[1] / 0.3
		draw_arc(g[0], R * 0.9, 0.0, TAU, 32, Pal.ink(0.3 * k2 * dim), 1.5, false)
	var appear := Pal.back(clampf(t / 0.8, 0.0, 1.0)) if state == ENTER else 1.0
	# it looks like you, inverted: a hollow disc with a solid notch
	var col := Pal.ink(dim, 1.0 + 0.8 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	draw_arc(pos, R * appear, 0.0, TAU, 48, col, 3.0, false)
	draw_arc(pos, R * 0.62 * appear, 0.0, TAU, 40, Pal.ink(0.35 * dim), 1.0, false)
	var a := aim.angle()
	var notch := PackedVector2Array([pos + Vector2.from_angle(a - 0.32) * R * appear, pos + Vector2.from_angle(a) * R * 0.3 * appear, pos + Vector2.from_angle(a + 0.32) * R * appear])
	draw_colored_polygon(notch, col)
	# its own magazine ring counts down to the next volley
	var n: int = SHOTS[phase]
	var left := clampf(volley_cd / VOLLEY[phase], 0.0, 1.0)
	for k in n:
		var d2 := Vector2.from_angle(-PI / 2.0 + TAU * k / n)
		var on := float(k) / n < 1.0 - left
		draw_line(pos + d2 * (R + 6.0), pos + d2 * (R + 11.0), Pal.ink(0.7 if on else 0.15, 1.0), 1.5)
