class_name Warden
extends Node2D
# 镜面守卫 THE MIRROR WARDEN: a great octagon behind a 140-degree mirror that
# turns to face you and throws your rounds back. It cannot guard every side
# at once: lay lines around it and recall them into its back.
# Its skills, one at a time between pauses:
#   shard volley — a slow fan of glass; every round it threw back adds a shard
#   registration stamps — three red circles hunt you and slam; your embedded
#     rounds under one are filed, and on recall they fly into its keeping
#     (it throws them out again with its next volley)
#   spotlight — a beam sweeps the half of the hall you stand in: dash through
#     it; embedded rounds it passes are bent into straight lines at it
# Phase 2 (66%): two prisms circle it, it turns faster, stamps and spotlight.
# Phase 3 (33%): it braces and lunges, and your reflections in the glass
#   panels copy your shots 0.4 s later until a recall line breaks them.
# Shares the train's interface (state, hp, hit_test, damage, ...).

enum { OFF, ENTER, RUN, DYING, DEAD }
enum { HOLD, BRACE, LUNGE }

const HP := 1900.0
const R := 112.0
const SHIELD_R := 182.0
const SHIELD_HALF := deg_to_rad(70.0)
const TURN := [0.8, 1.15, 1.5]
const HOME := Vector2(960, 540)
const GAP := [5.0, 3.6, 3.2]          # quiet between skills, by phase
const STAMP_R := 86.0
const STAMP_TRACK := 1.4
const STAMP_SLAM := 2.0
const BEAM_WARN := 0.9
const BEAM_SWEEP := 2.4
const BEAM_W := 10.0
const SHARD_SPEED := [300.0, 330.0, 360.0]
const COPY_DELAY := 0.4
const BOLT_SPEED := 760.0
const REFL_BREAK := 8.0

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
var skill := ""               # "", "volley", "stamp", "beam"
var skill_t := 0.0
var skill_cd := 4.0
var rot := 0
var glint := 0                # rounds thrown back since its last volley
var shots: Array = []         # its glass: {p, v, kind (0 shard, 1 bolt), pass, life}
var stamps: Array = []        # {c, off, t, at}
var beam_a0 := 0.0
var beam_sd := 1.0
var beam_a := 0.0
var beam_len := 0.0
var refl_cut := {}            # mirror index -> seconds its reflection stays broken
var refl_cd := {}             # mirror index -> seconds until it copies again
var copies: Array = []        # [left, origin, dir, mirror index]


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
	_clear_skills()
	game.sfx.play("horn", 1.5, -4.0)
	game.cam.add_trauma(0.3)
	game.hud.radio(Txt.t("radio_warden"))


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
	_clear_skills()


func _clear_skills() -> void:
	skill = ""
	skill_t = 0.0
	skill_cd = 4.0
	rot = 0
	glint = 0
	shots.clear()
	stamps.clear()
	refl_cut.clear()
	refl_cd.clear()
	copies.clear()


func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	damage(HP, false, pos, Vector2.UP)


func core_pos() -> Vector2:
	return pos - face * R * 0.7


func core_vel() -> Vector2:
	return vel


# Filed rounds, recalled, come into its keeping (Bullets.capture).
func holds() -> bool:
	return state == RUN or state == ENTER


func hold_center() -> Vector2:
	return pos


func hold_radius() -> float:
	return R + 30.0


# Your shot, as the glass would copy it (phase 3).
func on_player_fire(at: Vector2, dir: Vector2) -> void:
	if state != RUN or phase < 2:
		return
	var ms: Array = game.arena.mirrors
	for i in ms.size():
		if refl_cut.get(i, 0.0) > 0.0 or refl_cd.get(i, 0.0) > 0.0:
			continue
		var r := _reflect(ms[i], at, dir)
		if r.is_empty():
			continue
		refl_cd[i] = 0.22
		copies.append([COPY_DELAY, r.p, r.d, i])


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
	glint = mini(glint + 1, 10)
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
	skill = ""
	skill_cd = 2.4
	stamps.clear()
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
	var turn: float = TURN[phase] * (0.3 if mode == LUNGE else 1.0) * (0.55 if skill == "beam" and skill_t >= BEAM_WARN else 1.0)
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
				if lunge_cd <= 0.0 and skill == "" and not game.arena.raycast(pos, pl):
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
	if mode == HOLD and guard_t <= 0.0:
		if skill == "":
			skill_cd -= dt
			if skill_cd <= 0.0:
				_begin_skill(pl)
		else:
			_skill(dt, pl)
	_step_stamps(dt, pl)
	_step_shots(dt, pl)
	_step_reflections(dt)


# ---------------------------------------------------------------- skills

func _begin_skill(pl: Vector2) -> void:
	var order := ["volley"] if phase == 0 else ["stamp", "volley", "beam", "volley"]
	skill = order[rot % order.size()]
	rot += 1
	skill_t = 0.0
	match skill:
		"volley":
			game.sfx.play("windup", 1.3, -6.0)
		"stamp":
			# one on you, two either side; they follow you with a lag, then slam
			var base := randf() * TAU
			for k in 3:
				var off := Vector2.ZERO if k == 0 else Vector2.from_angle(base + PI * k) * 150.0
				stamps.append({"c": pl + off, "off": off, "t": 0.0, "at": STAMP_SLAM + 0.25 * k})
			game.sfx.play("stamp", 0.8, -4.0)
			game.hud.radio(Txt.t("radio_warden_stamp"))
		"beam":
			# the half of the hall you are in, starting beside you
			beam_sd = 1.0 if randf() < 0.5 else -1.0
			beam_a0 = (pl - pos).angle() - beam_sd * PI * 0.5
			beam_a = beam_a0
			beam_len = _beam_reach(beam_a)
			game.sfx.play("windup", 0.6, -2.0)


func _skill(dt: float, pl: Vector2) -> void:
	var was := skill_t
	skill_t += dt
	match skill:
		"volley":
			if was < 0.8 and skill_t >= 0.8:
				_volley(pl)
			if skill_t >= 1.0:
				_end_skill()
		"stamp":
			if stamps.is_empty():
				_end_skill()
		"beam":
			if skill_t < BEAM_WARN:
				beam_a = beam_a0
				beam_len = _beam_reach(beam_a)
				return
			var prev := beam_a
			var k := clampf((skill_t - BEAM_WARN) / BEAM_SWEEP, 0.0, 1.0)
			beam_a = beam_a0 + beam_sd * PI * k
			beam_len = _beam_reach(beam_a)
			if was < BEAM_WARN:
				game.sfx.play("dash_e", 0.5, -2.0)
				game.cam.add_trauma(0.15)
			_beam_bend(prev, beam_a)
			var a := pos + Vector2.from_angle(beam_a) * R
			var b := pos + Vector2.from_angle(beam_a) * beam_len
			var q := Geometry2D.get_closest_point_to_segment(pl, a, b)
			if q.distance_to(pl) < Player.R + BEAM_W and game.player.dash_t <= 0.0:
				game.on_player_hit(Vector2.from_angle(beam_a).orthogonal() * beam_sd, null)
			if k >= 1.0:
				_end_skill()


func _end_skill() -> void:
	skill = ""
	skill_t = 0.0
	skill_cd = GAP[phase]


func _volley(pl: Vector2) -> void:
	var held: Array = game.bullets.held_by(self)
	var n := 5 + 2 * phase + glint
	glint = 0
	var aim := (pl - pos).angle()
	var spread := 0.8 + 0.035 * n
	for k in n:
		var a := aim + lerpf(-spread, spread, (k + 0.5) / n) * 0.5
		var d := Vector2.from_angle(a)
		shots.append({"p": pos + d * (SHIELD_R + 6.0), "v": d * SHARD_SPEED[phase] * randf_range(0.92, 1.08), "kind": 0, "pass": -1, "life": 6.0, "spin": randf() * TAU})
	# what it filed goes out with the glass: yours again once it lands
	for i in held.size():
		var a2 := aim + lerpf(-spread, spread, (i + 0.5) / maxf(1.0, held.size())) * 0.5
		game.bullets.fling(held[i], Vector2.from_angle(a2))
	shield_flash = 1.0
	game.sfx.play("armor", 1.6, -4.0)
	game.cam.add_trauma(0.12)
	game.fx.flash(pos + Vector2.from_angle(aim) * SHIELD_R, 60.0, 0.2, Pal.foe(0.8, 2.0))


func _step_stamps(dt: float, pl: Vector2) -> void:
	var i := 0
	while i < stamps.size():
		var st: Dictionary = stamps[i]
		st.t += dt
		if st.t < STAMP_TRACK:
			st.c = Pal.damp2(st.c, pl + st.off, 3.2, dt)
		if st.t >= st.at and not st.has("done"):
			st.done = true
			_slam(st.c)
		if st.t >= st.at + 0.7:
			stamps.remove_at(i)
		else:
			i += 1


func _slam(c: Vector2) -> void:
	game.sfx.play("slam", 1.3, -3.0)
	game.cam.add_trauma(0.18)
	game.fx.ring(c, STAMP_R * 0.6, STAMP_R * 1.2, 0.35, Pal.red(0.9, 2.4), 4.0)
	game.fx.flash(c, STAMP_R, 0.16, Pal.red(0.35, 2.0))
	var pl: Vector2 = game.player.pos
	if pl.distance_to(c) < STAMP_R + Player.R * 0.5 and game.player.dash_t <= 0.0:
		game.on_player_hit((pl - c).normalized() if pl.distance_to(c) > 1.0 else Vector2.DOWN, null)
	for b in game.bullets.list:
		if b.state == Bullets.EMBED and not b.foe and not b.child and b.pos.distance_to(c) < STAMP_R:
			b.filed = true
			game.fx.flash(b.pos, 18.0, 0.2, Pal.red(0.8, 2.4))


func _beam_reach(a: float) -> float:
	var d := Vector2.from_angle(a)
	var h: Dictionary = game.arena.raycast(pos + d * R, pos + d * 2400.0)
	return R + (2400.0 - R) * (h.t if h else 1.0)


# Embedded rounds the beam passes over are bent: their way home becomes one
# straight line into its body.
func _beam_bend(a0: float, a1: float) -> void:
	var lo := minf(a0, a1)
	var span := absf(a1 - a0)
	for b in game.bullets.list:
		if b.state != Bullets.EMBED or b.foe or b.corrected:
			continue
		var off: Vector2 = b.pos - pos
		if off.length() < SHIELD_R:
			continue
		var da := wrapf(off.angle() - lo, 0.0, TAU)
		if da > span:
			continue
		var n := off.normalized()
		if game.arena.raycast(pos + n * R, b.pos - n * 3.0):
			continue
		var from := pos + n * R * 0.4
		b.path = PackedVector2Array([from, b.pos])
		b.cum = PackedFloat32Array([0.0, from.distance_to(b.pos)])
		b.dir = n
		b.bounces = 0
		b.bends = 0
		if b.settled:
			b.settled = false
			game.bullets.faint_dirty = true
		game.fx.flash(b.pos, 16.0, 0.14, Pal.foe(0.7, 2.0))


func _step_shots(dt: float, pl: Vector2) -> void:
	var i := 0
	while i < shots.size():
		var s: Dictionary = shots[i]
		var a: Vector2 = s.p
		var b: Vector2 = a + (s.v as Vector2) * dt
		s.life -= dt
		var gone: bool = s.life <= 0.0 or state != RUN
		var h: Dictionary = game.arena.raycast(a, b)
		if h and not (h.mirror and h.rect == s.pass):
			gone = true
			game.fx.sparks(h.point, h.normal, 4, Pal.foe(0.9, 1.8), 220.0, 0.16, 0.8)
		if not gone:
			var q := Geometry2D.get_closest_point_to_segment(pl, a, b)
			if q.distance_to(pl) < Player.R + (5.0 if s.kind == 0 else 4.0) and game.player.dash_t <= 0.0:
				game.on_player_hit((s.v as Vector2).normalized(), null)
				gone = true
		if not gone and s.kind == 0:
			# your own rounds, out or coming home, break the glass
			for r in game.bullets.list:
				if r.foe or not (r.state == Bullets.FLY or r.state == Bullets.RETURN or r.state == Bullets.HOME):
					continue
				if r.pos.distance_squared_to(b) < 22.0 * 22.0:
					gone = true
					game.fx.sparks(b, (s.v as Vector2).normalized(), 5, Pal.foe(1.0, 2.0), 260.0, 0.18, 0.9)
					game.sfx.play("cross", randf_range(1.6, 2.0), -14.0)
					break
		if gone:
			shots.remove_at(i)
		else:
			s.p = b
			i += 1


# A reflection of point p in the panel m (only while you stand along it).
func _reflect(m: Rect2, p: Vector2, d: Vector2) -> Dictionary:
	if m.size.x > m.size.y:
		var my := m.get_center().y
		if p.x <= m.position.x or p.x >= m.end.x or absf(p.y - my) < 20.0:
			return {}
		return {"p": Vector2(p.x, 2.0 * my - p.y), "d": Vector2(d.x, -d.y)}
	var mx := m.get_center().x
	if p.y <= m.position.y or p.y >= m.end.y or absf(p.x - mx) < 20.0:
		return {}
	return {"p": Vector2(2.0 * mx - p.x, p.y), "d": Vector2(-d.x, d.y)}


func _step_reflections(dt: float) -> void:
	for k in refl_cut.keys():
		refl_cut[k] = maxf(0.0, refl_cut[k] - dt)
	for k in refl_cd.keys():
		refl_cd[k] = maxf(0.0, refl_cd[k] - dt)
	if phase < 2:
		return
	var ms: Array = game.arena.mirrors
	# a recall line through a reflection breaks it for a while
	for i in ms.size():
		if refl_cut.get(i, 0.0) > 0.0:
			continue
		var r := _reflect(ms[i], game.player.pos, Vector2.RIGHT)
		if r.is_empty():
			continue
		for b in game.bullets.list:
			if (b.state == Bullets.RETURN or b.state == Bullets.HOME) and b.pos.distance_squared_to(r.p) < 40.0 * 40.0:
				refl_cut[i] = REFL_BREAK
				for k in 8:
					var a := TAU * k / 8.0
					game.fx.shard(r.p + Vector2.from_angle(a) * 14.0, Vector2.from_angle(a - 0.4) * 9.0, Vector2.from_angle(a + 0.4) * 9.0, Vector2.from_angle(a) * randf_range(140, 280), randf_range(-8, 8), 0.8, Pal.foe(0.9, 1.6), 2.0)
				game.sfx.play("armor", 1.8, -6.0)
				break
	var j := 0
	while j < copies.size():
		var c: Array = copies[j]
		c[0] -= dt
		if c[0] <= 0.0:
			var mi: int = c[3]
			if refl_cut.get(mi, 0.0) <= 0.0:
				shots.append({"p": c[1], "v": (c[2] as Vector2) * BOLT_SPEED, "kind": 1, "pass": game.arena.mirror_from + mi, "life": 3.0, "spin": 0.0})
				game.sfx.play("shot", 0.7, -12.0)
			copies.remove_at(j)
		else:
			j += 1


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
	if state == ENTER:
		dim *= clampf(t / 0.6, 0.0, 1.0)   # it steps out of the dark of the hall
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
	# the Bureau's mark across its back: a band of red hazard stripes
	var bk := -face
	var bs := bk.orthogonal()
	var b0 := pos + bk * R * 0.62 * appear - bs * R * 0.42 * appear
	var b1 := pos + bk * R * 0.62 * appear + bs * R * 0.42 * appear
	for j in 7:
		var q := b0.lerp(b1, (j + 0.5) / 7.0)
		draw_line(q - bk * 7.0, q + bk * 7.0 + bs * 6.0, Pal.red(0.7 * dim, 1.6), 3.0)
	# its unit number, stencilled
	draw_set_transform(pos + bk * R * 0.25 * appear, bk.angle() + PI / 2.0, Vector2.ONE)
	draw_string(Fonts.get_font("SemiBold"), Vector2(-22, 6), "BSB-02", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.foe(0.5 * dim))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the face: a lens that smiles at you, two dots and a curve, always
	var eye := pos + face * R * 0.5 * appear
	var side := face.orthogonal()
	draw_circle(eye - side * 22.0 - face * 10.0, 5.5, Pal.foe(dim, 2.2))
	draw_circle(eye + side * 22.0 - face * 10.0, 5.5, Pal.foe(dim, 2.2))
	var smile := PackedVector2Array()
	for j in 11:
		var u := lerpf(-1.0, 1.0, j / 10.0)
		smile.append(eye + side * u * 34.0 + face * (12.0 - 12.0 * u * u))
	draw_polyline(smile, Pal.foe(dim, 2.4), 4.0, false)
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
		draw_arc(pos, SHIELD_R, sh - 0.06, sh + 0.06, 6, Pal.foe(dim, 1.5), 5.0, false)
	if state == RUN:
		_draw_skills(dim)
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


func _draw_skills(dim: float) -> void:
	var font := Fonts.get_font("SemiBold")
	# volley: the glass gathers light, a fan of faint aim lines
	if skill == "volley" and skill_t < 0.8:
		var k := skill_t / 0.8
		var n := 5 + 2 * phase + glint
		var aim: float = (game.player.pos - pos).angle()
		var spread := 0.8 + 0.035 * n
		var segs := PackedVector2Array()
		for j in n:
			var a: float = aim + lerpf(-spread, spread, (j + 0.5) / n) * 0.5
			var d := Vector2.from_angle(a)
			segs.append(pos + d * (SHIELD_R + 10.0))
			segs.append(pos + d * (SHIELD_R + 10.0 + 150.0 * Pal.ease_out(k)))
		draw_multiline(segs, Pal.foe((0.15 + 0.35 * k) * dim, 1.4), 1.0)
		draw_arc(pos, SHIELD_R + 4.0, aim - spread * 0.5, aim + spread * 0.5, 24, Pal.foe(k * dim, 2.0 + k), 3.0, false)
	# spotlight: the warned half, then the beam
	if skill == "beam":
		var d := Vector2.from_angle(beam_a)
		if skill_t < BEAM_WARN:
			var k := skill_t / BEAM_WARN
			var blink := 0.5 + 0.5 * sin(skill_t * 30.0)
			var segs := PackedVector2Array()
			var s0 := R + 8.0
			while s0 < beam_len:
				segs.append(pos + d * s0)
				segs.append(pos + d * minf(s0 + 14.0, beam_len))
				s0 += 28.0
			draw_multiline(segs, Pal.foe((0.3 + 0.5 * blink) * dim, 1.6), 2.0)
			# the half it will sweep, swept in thin rings
			var lo := minf(beam_a0, beam_a0 + beam_sd * PI)
			for r in [260.0, 420.0, 580.0]:
				draw_arc(pos, r, lo, lo + PI * Pal.ease_out(k), 48, Pal.foe(0.16 * dim), 1.0, false)
			var tip := pos + Vector2.from_angle(beam_a0 + beam_sd * 0.35) * 300.0
			var td := Vector2.from_angle(beam_a0 + beam_sd * 0.35).orthogonal() * beam_sd
			draw_line(tip - td * 16.0 + td.orthogonal() * 8.0, tip, Pal.foe(0.6 * dim, 1.6), 2.0)
			draw_line(tip - td * 16.0 - td.orthogonal() * 8.0, tip, Pal.foe(0.6 * dim, 1.6), 2.0)
		else:
			var a := pos + d * (R * 0.6)
			var b := pos + d * beam_len
			draw_line(a, b, Pal.foe(0.10 * dim, 1.4), BEAM_W * 4.0)
			draw_line(a, b, Pal.foe(0.35 * dim, 1.8), BEAM_W * 1.6)
			draw_line(a, b, Pal.foe(dim, 3.0), 3.0)
			draw_circle(b, 14.0, Pal.foe(0.35 * dim, 2.2))
			draw_circle(b, 5.0, Pal.foe(dim, 3.0))
	# registration stamps
	for st in stamps:
		var c: Vector2 = st.c
		var t0: float = st.t
		if t0 < st.at:
			var lock := t0 >= STAMP_TRACK
			var k := clampf((t0 - STAMP_TRACK) / maxf(0.01, st.at - STAMP_TRACK), 0.0, 1.0) if lock else 0.0
			var a := (0.45 + 0.4 * k) * dim * clampf(t0 / 0.2, 0.0, 1.0)
			if lock:
				draw_circle(c, STAMP_R * k, Color(Pal.red(1.0).r, Pal.red(1.0).g, Pal.red(1.0).b, 0.16 * dim))
				draw_arc(c, STAMP_R, 0.0, TAU, 48, Pal.red(a, 2.0 + k), 3.0, false)
			else:
				var n := 16
				for j in n:
					var a0 := TAU * j / n + t0 * 1.2
					draw_arc(c, STAMP_R, a0, a0 + TAU / n * 0.55, 6, Pal.red(a, 1.6), 2.0, false)
			draw_arc(c, STAMP_R - 10.0, 0.0, TAU, 40, Pal.red(a * 0.5, 1.4), 1.0, false)
			draw_line(c - Vector2(10, 0), c + Vector2(10, 0), Pal.red(a, 1.6), 1.5)
			draw_line(c - Vector2(0, 10), c + Vector2(0, 10), Pal.red(a, 1.6), 1.5)
		else:
			# the mark it leaves: a double ring and the word
			var f: float = 1.0 - (t0 - st.at) / 0.7
			var a2: float = f * dim
			draw_arc(c, STAMP_R, 0.0, TAU, 48, Pal.red(a2, 2.2), 4.0, false)
			draw_arc(c, STAMP_R - 9.0, 0.0, TAU, 48, Pal.red(a2 * 0.7, 1.8), 2.0, false)
			var word := Txt.t("warden_filed")
			var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_set_transform(c, -0.2, Vector2.ONE)
			draw_string(font, Vector2(-w * 0.5, 11), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.red(a2, 2.4))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# filed rounds carry a small red square
	for b in game.bullets.list:
		if b.filed and b.state == Bullets.EMBED:
			var q: Vector2 = b.pos - b.dir * 6.0
			draw_rect(Rect2(q - Vector2(7, 7), Vector2(14, 14)), Pal.red(0.85 * dim, 2.2), false, 2.0)
	# your reflections, turned against you
	if phase >= 2:
		var ms: Array = game.arena.mirrors
		for i in ms.size():
			var r := _reflect(ms[i], game.player.pos, Vector2.RIGHT)
			if r.is_empty():
				continue
			var p: Vector2 = r.p
			var cut: float = refl_cut.get(i, 0.0)
			if cut > 0.0:
				var ca := 0.5 * dim * clampf(cut / 1.0, 0.0, 1.0)
				for j in 5:
					var a := TAU * j / 5.0 + 0.4
					draw_line(p + Vector2.from_angle(a) * 6.0, p + Vector2.from_angle(a + 0.3) * 30.0, Pal.foe(ca, 1.2), 1.0)
				continue
			var hot := 0.0
			for c in copies:
				if c[3] == i:
					hot = maxf(hot, 1.0 - c[0] / COPY_DELAY)
			draw_circle(p + Vector2(-9, -7), 3.2, Pal.red(dim, 2.0 + 2.0 * hot))
			draw_circle(p + Vector2(9, -7), 3.2, Pal.red(dim, 2.0 + 2.0 * hot))
			draw_arc(p, 30.0 + 6.0 * hot, 0.0, TAU, 32, Pal.red((0.35 + 0.6 * hot) * dim, 1.6 + 1.4 * hot), 2.0, false)
	# its glass in flight
	for s in shots:
		var p2: Vector2 = s.p
		var v: Vector2 = (s.v as Vector2).normalized()
		var o := v.orthogonal()
		if s.kind == 0:
			var sp: float = s.spin + s.life * 5.0
			var w := o.rotated(sin(sp) * 0.5)
			draw_circle(p2, 18.0, Pal.foe(0.07 * dim, 1.4))
			var pts := PackedVector2Array([p2 + v * 17.0, p2 + w * 6.0, p2 - v * 13.0, p2 - w * 6.0])
			draw_colored_polygon(pts, Pal.foe(0.9 * dim, 1.6))
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Pal.foe(dim, 2.6), 1.5)
			draw_line(p2 - v * 8.0, p2 + v * 14.0, Pal.foe(dim, 3.2), 1.5)
		else:
			draw_line(p2 - v * 24.0, p2, Pal.red(0.35 * dim, 1.6), 5.0)
			draw_line(p2 - v * 20.0, p2, Pal.red(dim, 2.6), 2.0)
