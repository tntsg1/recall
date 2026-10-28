class_name Warden
extends Node2D
# 镜面守卫 THE MIRROR WARDEN: a great octagon behind a 140-degree mirror that
# turns to face you and throws your rounds back. It cannot guard every side
# at once: lay lines around it and recall them into its back.
# Phase 2 (66%): two prisms circle it and it turns faster.
# Phase 3 (33%): it braces, then lunges down a dashed lane.
# Shares the train's interface (state, hp, hit_test, damage, ...).

enum { OFF, ENTER, RUN, DYING, DEAD }
enum { HOLD, BRACE, LUNGE }

const HP := 1500.0
const R := 58.0
const SHIELD_R := 98.0
const SHIELD_HALF := deg_to_rad(70.0)
const TURN := [0.8, 1.15, 1.5]
const HOME := Vector2(960, 540)

var game
var state := OFF
var t := 0.0
var hp := HP
var phase := 0
var pos := HOME
var vel := Vector2.ZERO
var face := Vector2.DOWN
var guard_t := 0.0
var flash := 0.0
var shield_flash := 0.0
var red := 0.0
var core_open := 1.0          # its back is always open; kept for the shared HUD and bots
var mode := HOLD
var mode_t := 0.0
var lunge_cd := 6.0
var lunge_dir := Vector2.DOWN
var enter_t := 0.0
var dying_t := 0.0
var shards: Array = []        # entrance shards [from, angle]


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_2"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


func begin_track() -> void:
	# the glass gathers in the middle of the hall during the title
	state = OFF
	shards.clear()
	for k in 24:
		shards.append([Vector2.from_angle(randf() * TAU) * randf_range(500, 900), randf() * TAU])
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	hp = HP
	phase = 0
	pos = HOME
	vel = Vector2.ZERO
	face = (game.player.pos - pos).normalized()
	mode = HOLD
	lunge_cd = 6.0
	game.sfx.play("horn", 1.5, -4.0)
	game.cam.add_trauma(0.3)


func reset() -> void:
	state = OFF
	t = 0.0
	hp = HP
	phase = 0
	pos = HOME
	enter_t = 0.0
	shards.clear()
	mode = HOLD
	guard_t = 0.0


func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	damage(HP, false, pos, Vector2.UP)


func core_pos() -> Vector2:
	return pos - face * R * 0.7


func core_vel() -> Vector2:
	return vel


# ---------------------------------------------------------------- bullets

# The mirror arc first (reflects), then the body (hurts) — from behind the
# arc is not there, so rounds reach the body.
func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	var d := b - a
	var hits := Geometry2D.segment_intersects_circle(a, b, pos, SHIELD_R)
	if hits >= 0.0:
		var p := a + d * hits
		var off := (p - pos).normalized()
		if absf(off.angle_to(face)) <= SHIELD_HALF and d.dot(off) < 0.0:
			return {"point": p, "normal": off, "core": false, "car": 0}
	var hb := Geometry2D.segment_intersects_circle(a, b, pos, R)
	if hb >= 0.0:
		var pb := a + d * hb
		return {"point": pb, "normal": (pb - pos).normalized(), "core": true, "mult": 1.0}
	return {}


func on_armor(_k: int, at_p: Vector2, normal: Vector2) -> void:
	shield_flash = 1.0
	game.fx.sparks(at_p, normal, 6, Pal.foe(1.0, 2.0), 460.0, 0.2, 0.9)
	game.fx.flash(at_p, 20.0, 0.1, Pal.foe(0.5, 1.6))
	game.sfx.play("shield", randf_range(1.1, 1.3), -6.0)


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
	var c := Pal.red(1.0, 3.2) if ret else Pal.foe(1.0, 1.8)
	game.fx.sparks(at_p, d, 8 if ret else 5, c, 560.0, 0.28, 0.8)
	game.fx.flash(at_p, 34.0, 0.14, Color(c.r, c.g, c.b, 0.4))
	game.on_target_hit(ret)
	var want := clampi(int((1.0 - hp / HP) * 3.0), 0, 2)
	while phase < want:
		phase += 1
		_phase_break()
	if hp <= 0.0:
		state = DYING
		dying_t = 0.0
		game.on_boss_dying()


func _phase_break() -> void:
	guard_t = 1.4
	# the mirror cracks off and grows back
	for k in 10:
		var a := face.angle() + lerpf(-SHIELD_HALF, SHIELD_HALF, (k + 0.5) / 10.0)
		var p0 := pos + Vector2.from_angle(a - 0.07) * SHIELD_R
		var p1 := pos + Vector2.from_angle(a + 0.07) * SHIELD_R
		var mid := (p0 + p1) * 0.5
		game.fx.shard(mid, p0 - mid, p1 - mid, (mid - pos).normalized() * randf_range(260, 460), randf_range(-9, 9), 1.0, Pal.foe(1.0, 1.6), 3.0)
	game.fx.ring(pos, R, 320.0, 0.6, Pal.foe(0.9, 1.5), 3.0)
	game.sfx.play("armor", 1.2, 0.0)
	game.add_hitstop(0.09)
	game.cam.add_trauma(0.6)
	game.cam.punch(0.04)
	game.hud.boss_phase()
	if phase == 1:
		for k in 2:
			var e = game.enemies.spawn(Enemies.PRISM, pos + Vector2.from_angle(PI * k) * 170.0, 0.2 * k)
			e.anchor = self
			e.orbit_a = PI * k
			e.hp = 80.0
			e.maxhp = 80.0


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	if enter_t > 0.0 and enter_t < 1.0 and state == OFF:
		enter_t = minf(1.0, enter_t + dt / 2.4)
	if state == OFF or state == DEAD:
		queue_redraw()
		return
	t += dt
	flash = maxf(0.0, flash - dt / 0.12)
	shield_flash = maxf(0.0, shield_flash - dt / 0.2)
	red = maxf(0.0, red - dt / 0.8)
	guard_t = maxf(0.0, guard_t - dt)
	var pl: Vector2 = game.player.pos
	match state:
		ENTER:
			if t >= 0.6:
				state = RUN
				t = 0.0
		RUN:
			_run(dt, pl)
		DYING:
			_dying(dt)
	if state == RUN or state == ENTER:
		pos = game.arena.push_circle(pos, R)
		if pos.distance_to(pl) < R + Player.R - 4.0:
			game.on_player_hit((pl - pos).normalized(), null)
	queue_redraw()


func _run(dt: float, pl: Vector2) -> void:
	var to := pl - pos
	# turn toward you at a fixed rate: that lag is the opening
	var turn: float = TURN[phase] * (0.3 if mode == LUNGE else 1.0)
	var cur := face.angle()
	cur += clampf(wrapf(to.angle() - cur, -PI, PI), -turn * dt, turn * dt)
	face = Vector2.from_angle(cur)
	mode_t += dt
	match mode:
		HOLD:
			var drift := (pl - pos).normalized() * 35.0 + (HOME - pos) * 0.4
			vel = Pal.damp2(vel, drift, 2.0, dt)
			if phase >= 2:
				lunge_cd -= dt
				if lunge_cd <= 0.0 and not game.arena.raycast(pos, pl):
					mode = BRACE
					mode_t = 0.0
					lunge_dir = to.normalized()
					game.sfx.play("windup", 0.7, -3.0)
		BRACE:
			vel = Pal.damp2(vel, -lunge_dir * 40.0, 6.0, dt)
			if mode_t < 0.6:
				lunge_dir = lunge_dir.slerp(to.normalized(), 1.0 - exp(-4.0 * dt))
			if mode_t >= 1.0:
				mode = LUNGE
				mode_t = 0.0
				vel = lunge_dir * 950.0
				game.sfx.play("dash_e", 0.7, 0.0)
				game.cam.add_trauma(0.2)
		LUNGE:
			vel = lunge_dir * 950.0 * lerpf(1.0, 0.2, clampf(mode_t / 0.55, 0.0, 1.0))
			var before := pos + vel * dt
			if game.arena.push_circle(before, R).distance_to(before) > 2.0 or mode_t > 0.55:
				if mode_t <= 0.55:
					game.sfx.play("slam", 0.8, -2.0)
					game.cam.add_trauma(0.35)
					game.fx.sparks(pos + lunge_dir * R, -lunge_dir, 14, Pal.foe(1.0, 1.8), 560.0, 0.3, 1.2)
				mode = HOLD
				mode_t = 0.0
				lunge_cd = randf_range(5.0, 7.0)
	pos += vel * dt


func _dying(dt: float) -> void:
	dying_t += dt
	vel = Pal.damp2(vel, Vector2.ZERO, 4.0, dt)
	pos += vel * dt + Vector2(sin(dying_t * 70.0), cos(dying_t * 63.0)) * 3.0 * dying_t
	if dying_t > 0.2 and int(dying_t * 10.0) != int((dying_t - dt) * 10.0):
		game.fx.sparks(pos + Vector2.from_angle(randf() * TAU) * R * 0.8, Vector2.from_angle(randf() * TAU), 6, Pal.foe(1.0, 1.8), 420.0, 0.3, 1.0)
		game.sfx.play("cross", randf_range(0.7, 1.3), -6.0)
	if dying_t >= 1.4:
		state = DEAD
		for k in 36:
			var a := TAU * k / 36.0
			var p0 := Vector2.from_angle(a) * R
			var p1 := Vector2.from_angle(a + TAU / 36.0 * 2.0) * R * randf_range(0.5, 1.0)
			game.fx.shard(pos + (p0 + p1) * 0.5, (p0 - p1) * 0.5, (p1 - p0) * 0.5, p0.normalized() * randf_range(300, 700), randf_range(-12, 12), 1.4, Pal.foe(1.0, 1.7), 2.0)
		game.on_boss_dead(pos)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if state == OFF:
		if enter_t > 0.0:
			# glass shards drift in toward the middle
			var e := Pal.ease_io(enter_t)
			for s in shards:
				var p: Vector2 = HOME + (s[0] as Vector2) * (1.0 - e)
				var a: float = s[1] + enter_t * 4.0
				draw_line(p - Vector2.from_angle(a) * 8.0, p + Vector2.from_angle(a) * 8.0, Pal.foe(0.6 * e * dim, 1.4), 2.0)
		return
	if state == DEAD:
		return
	var appear := Pal.back(clampf(t / 0.6, 0.0, 1.0)) if state == ENTER else 1.0
	var col := Pal.foe(dim, 1.0 + 0.8 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	# body: an octagon with slow inner facets
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(pos + Vector2.from_angle(face.angle() + TAU * k / 8.0 + PI / 8.0) * R * appear)
	draw_colored_polygon(pts.slice(0, 8), Color(0.05, 0.05, 0.055, appear))
	draw_polyline(pts, col, 2.5, false)
	for k in 4:
		var a := t * 0.4 + TAU * k / 4.0
		draw_line(pos + Vector2.from_angle(a) * R * 0.25 * appear, pos + Vector2.from_angle(a) * R * 0.75 * appear, Pal.foe(0.25 * dim), 1.0)
	# the eye: a slit that looks where the mirror points
	var eye := pos + face * R * 0.45 * appear
	draw_line(eye - face.orthogonal() * 12.0, eye + face.orthogonal() * 12.0, Pal.foe(dim, 2.0), 3.0)
	# the mirror arc
	var a0 := face.angle() - SHIELD_HALF * appear
	var a1 := face.angle() + SHIELD_HALF * appear
	var sc := Pal.foe(dim, 1.3 + 1.4 * shield_flash)
	var grow := Pal.ease_out(clampf(1.0 - guard_t / 1.4, 0.0, 1.0)) if guard_t > 0.0 else 1.0
	if grow > 0.02:
		var h := (a1 - a0) * grow / 2.0
		var mid := face.angle()
		draw_arc(pos, SHIELD_R, mid - h, mid + h, 32, sc, 6.0, false)
		draw_arc(pos, SHIELD_R - 8.0, mid - h, mid + h, 32, Pal.foe(0.3 * dim), 1.0, false)
		# a sheen slides along the glass
		var sh := mid - h + fmod(t * 0.7, 1.0) * 2.0 * h
		draw_arc(pos, SHIELD_R, sh - 0.06, sh + 0.06, 6, Pal.foe(dim, 2.6), 7.0, false)
	# the open back, marked with a faint bracket
	var back := face.angle() + PI
	draw_arc(pos, R + 12.0, back - 0.6, back + 0.6, 16, Pal.foe(0.22 * dim), 1.0, false)
	# lunge lane
	if state == RUN and mode == BRACE:
		var k2 := mode_t / 1.0
		var segs := PackedVector2Array()
		var s0 := R + 10.0 + fmod(t * 160.0, 24.0)
		while s0 < 900.0 * Pal.ease_out(k2 * 1.5):
			segs.append(pos + lunge_dir * s0)
			segs.append(pos + lunge_dir * (s0 + 12.0))
			s0 += 24.0
		if segs.size() > 0:
			draw_multiline(segs, Pal.foe(0.3 + 0.5 * k2), 2.0)
