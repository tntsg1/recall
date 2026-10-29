class_name Observed
extends Node2D
# 观测对象 THE OBSERVED (chapter 11): the institute's superposed subject. It
# is in several places at once — three, then four, then five — and every one
# of them fires. Rounds pass through all of them: none is there until it is
# observed. A recalled round sweeping over one observes it: a copy goes out
# like a blown bulb; the real one collapses into view, solid, and for a few
# seconds can be hurt. Then it spreads out again, and the copies with it.
# Second stage: the states tunnel at you down marked lanes. Last stage: they
# imitate you — fire their own rounds into the walls and recall them across
# your floor. Recall those yourself and they fly back, and then on into the
# real one.

enum { OFF, ENTER, RUN, DYING, DEAD }

const HP := 1500.0
const R := 52.0
const N := [3, 4, 5]
const COLLAPSE := [5.0, 4.6, 4.2]       # seconds the real one stays observed
const SPREAD := 0.7                     # spreading out again
const POP := 2.6                        # a blown copy re-forms after this
const BURST_EVERY := [3.0, 2.8, 3.2]
const BURST := [3, 4, 3]
const ORB_SPEED := 440.0
const ORB_R := 7.0
const RING_N := 10
const LANE_EVERY := 4.6
const LANE_WARN := 0.9
const LANE_SPEED := 1250.0
const MIMIC_EVERY := 7.5
const MIMIC_RECALL := 3.4               # after firing, they call their rounds home
const STEAL_DMG := 14.0
const AREA := Rect2(300, 190, 1320, 640)

class S:
	var pos := Vector2.ZERO
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var move_t := 1.0                   # 0..1 along from -> to
	var move_dur := 3.0
	var real := false
	var popped := 0.0                   # >0: blown, re-forming
	var shot_cd := 1.0
	var lane := Vector2.ZERO            # a tunnelling lane's end (zero: none)
	var lane_t := -1.0
	var seed := 0.0

var game
var state := OFF
var t := 0.0
var hp := HP
var phase := 0
var core_open := 0.0
var flash := 0.0
var red := 0.0
var guard_t := 0.0
var dying_t := 0.0
var enter_t := 0.0
var ss: Array = []                      # the states; exactly one is real
var collapsed := 0.0                    # >0: observed, seconds left
var spread_t := -1.0                    # >=0: spreading out from one point
var orbs: Array = []                    # [pos, vel, life]
var pops: Array = []                    # [pos, t]: copies going out
var lane_cd := LANE_EVERY
var mimic_cd := 4.0
var mimic_warned := false
var mimic_at := -1.0
var seen_t := 0.0                       # the "observed" label's flash


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_observed"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


func begin_track() -> void:
	state = OFF
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	_fresh()
	_spread(Vector2(960, 470), true)
	game.sfx.play("horn", 1.2, -3.0)
	game.cam.add_trauma(0.3)
	game.hud.radio(Txt.t("radio_observed"))


func reset() -> void:
	state = OFF
	t = 0.0
	enter_t = 0.0
	_fresh()


func _fresh() -> void:
	hp = HP
	phase = 0
	core_open = 0.0
	guard_t = 0.0
	flash = 0.0
	red = 0.0
	collapsed = 0.0
	spread_t = -1.0
	orbs.clear()
	pops.clear()
	ss.clear()
	lane_cd = LANE_EVERY
	mimic_cd = 4.0
	mimic_warned = false
	mimic_at = -1.0


func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	_collapse()
	damage(HP, false, core_pos(), Vector2.UP)


func _real() -> S:
	for s: S in ss:
		if s.real:
			return s
	return null


func core_pos() -> Vector2:
	var r := _real()
	return r.pos if r != null else Vector2(960, 470)


func core_vel() -> Vector2:
	return Vector2.ZERO


# ---------------------------------------------------------------- bullets

# Only the real one, observed, is there to be hit.
func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if state != RUN or collapsed <= 0.0:
		return {}
	var r := _real()
	if r == null:
		return {}
	var hb := Geometry2D.segment_intersects_circle(a, b, r.pos, R)
	if hb < 0.0:
		return {}
	var p := a + (b - a) * hb
	return {"point": p, "normal": (p - r.pos).normalized(), "core": true, "mult": 1.0}


func on_armor(_k: int, _at: Vector2, _n: Vector2) -> void:
	pass


# A recalled round's line, a to b: whatever state it sweeps is observed.
func observe(a: Vector2, b: Vector2) -> void:
	if state != RUN or collapsed > 0.0 or spread_t >= 0.0:
		return
	for s: S in ss:
		if s.popped > 0.0:
			continue
		var q := Geometry2D.get_closest_point_to_segment(s.pos, a, b)
		if q.distance_to(s.pos) > R + 4.0:
			continue
		if s.real:
			_collapse()
			return
		_pop(s)


# One of its own rounds, recalled by you, flies home into the real one.
func stolen_hit(at_p: Vector2) -> void:
	if state != RUN:
		return
	if collapsed <= 0.0 and spread_t < 0.0:
		_collapse()
	damage(STEAL_DMG, true, at_p, (core_pos() - at_p).normalized())
	game.steals += 1
	game.fx.ring(core_pos(), R, R * 3.0, 0.3, Pal.red(1.0, 2.6), 2.5)


func damage(dmg: float, ret: bool, at_p: Vector2, d: Vector2, _frame_k: int = -1) -> void:
	if state != RUN or collapsed <= 0.0:
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
	game.on_target_hit(ret)
	var want := clampi(int((1.0 - hp / HP) * 3.0), 0, 2)
	while phase < want:
		phase += 1
		_phase_break()
	if hp <= 0.0:
		state = DYING
		dying_t = 0.0
		game.bullets.clear_foe()
		game.on_boss_dying()


func _phase_break() -> void:
	guard_t = 1.4
	var at := core_pos()
	game.fx.ring(at, 60.0, 360.0, 0.6, Pal.foe(0.9, 1.5), 3.0)
	game.sfx.play("armor", 1.1, 0.0)
	game.add_hitstop(0.09)
	game.cam.add_trauma(0.6)
	game.cam.punch(0.04)
	game.hud.boss_phase()
	game.hud.radio(Txt.t("radio_observed_%d" % phase))
	# it spreads again at once, into more places
	collapsed = 0.0
	_spread(at, false)
	if phase == 1:
		for k in 2:
			var e = game.enemies.spawn(Enemies.PHASE, at + Vector2.from_angle(k * PI + 0.5) * 120.0, k * 0.3)
			e.mode_t = k * 0.9
	mimic_cd = 2.5


# ---------------------------------------------------------------- the states

# Out from one point into N places: all at once, all alike.
func _spread(from: Vector2, first: bool) -> void:
	var n: int = N[phase]
	var spots := _spots(n)
	ss.clear()
	var ri := randi() % n
	for k in n:
		var s := S.new()
		s.from = from
		s.pos = from
		s.to = spots[k]
		s.move_t = 0.0
		s.move_dur = SPREAD
		s.real = k == ri
		s.shot_cd = 1.2 + k * BURST_EVERY[phase] / n
		s.seed = randf() * 100.0
		ss.append(s)
	spread_t = 0.0
	game.fx.ring(from, R, R * 4.0, 0.4, Pal.foe(0.8, 1.6), 2.0)
	if not first:
		game.sfx.play("release", 1.5, -4.0)


# n spots in the area, apart from each other and from you, off the cover.
func _spots(n: int) -> Array:
	var out: Array = []
	var pl: Vector2 = game.player.pos
	var tries := 0
	while out.size() < n and tries < 400:
		tries += 1
		var q := Vector2(randf_range(AREA.position.x, AREA.end.x), randf_range(AREA.position.y, AREA.end.y))
		var gap := 300.0 if tries < 200 else 200.0
		if q.distance_to(pl) < (340.0 if tries < 300 else 200.0):
			continue
		if not game.arena.is_free(q, R + 10.0):
			continue
		if tries < 250 and _on_field(q):
			continue
		var ok := true
		for o: Vector2 in out:
			if o.distance_to(q) < gap:
				ok = false
				break
		if ok:
			out.append(q)
	while out.size() < n:
		out.append(Vector2(randf_range(AREA.position.x, AREA.end.x), randf_range(AREA.position.y, AREA.end.y)))
	return out


# Over a stasis field's ring (it would sit on top of it, hard to read).
func _on_field(q: Vector2) -> bool:
	for fc: Vector2 in Stasis.FIELDS:
		if q.distance_to(fc) < Stasis.R + R * 0.6:
			return true
	return false


func _collapse() -> void:
	var r := _real()
	if r == null:
		return
	collapsed = COLLAPSE[phase]
	seen_t = 1.0
	r.lane_t = -1.0
	r.to = r.pos
	r.move_t = 1.0
	for s: S in ss:
		if not s.real and s.popped <= 0.0:
			pops.append([s.pos, 0.0])
	ss = [r]
	game.fx.ring(r.pos, R, R * 5.0, 0.45, Pal.ink(1.0, 2.4), 3.0)
	game.fx.flash(r.pos, R * 3.0, 0.2, Pal.ink(0.8, 2.2))
	game.sfx.play("crit", 0.8, -2.0)
	game.add_hitstop(0.05)
	game.cam.add_trauma(0.3)
	# decoherence: a ring of its orbs thrown out as it becomes one
	for k in RING_N:
		var a := TAU * k / RING_N + randf() * 0.2
		orbs.append([r.pos + Vector2.from_angle(a) * (R + 6.0), Vector2.from_angle(a) * ORB_SPEED * 0.8, 3.0])


func _pop(s: S) -> void:
	s.popped = POP
	s.lane_t = -1.0
	pops.append([s.pos, 0.0])
	game.fx.ring(s.pos, R, R * 2.2, 0.3, Pal.foe(0.6, 1.4), 1.5)
	for j in 8:
		var a := TAU * j / 8.0
		game.fx.sparks(s.pos + Vector2.from_angle(a) * R, Vector2.from_angle(a), 1, Pal.foe(0.7, 1.4), 260.0, 0.2, 0.4)
	game.sfx.play("expire", 0.7, -6.0)


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
	seen_t = maxf(0.0, seen_t - dt / 1.2)
	var i := 0
	while i < pops.size():
		pops[i][1] += dt
		if pops[i][1] > 0.5:
			pops.remove_at(i)
		else:
			i += 1
	match state:
		ENTER:
			_move(dt)
			if t >= 1.2:
				state = RUN
				t = 0.0
		RUN:
			_run(dt)
		DYING:
			_dying(dt)
	_step_orbs(dt)
	core_open = 1.0 if state == RUN and collapsed > 0.0 else 0.0
	queue_redraw()


func _move(dt: float) -> void:
	if spread_t >= 0.0:
		spread_t += dt
		if spread_t >= SPREAD:
			spread_t = -1.0
	for s: S in ss:
		if s.lane_t >= LANE_WARN:
			continue
		if s.move_t < 1.0:
			s.move_t = minf(1.0, s.move_t + dt / s.move_dur)
			var e := Pal.ease_io(s.move_t) if s.move_dur > SPREAD else Pal.ease_out(s.move_t)
			s.pos = s.from.lerp(s.to, e)
		else:
			# a new place to drift to
			s.from = s.pos
			var q := s.pos + Vector2.from_angle(randf() * TAU) * randf_range(140.0, 300.0)
			q = q.clamp(AREA.position, AREA.end)
			if not game.arena.is_free(q, R + 10.0) or q.distance_to(game.player.pos) < 220.0 or _on_field(q):
				q = s.pos
			s.to = q
			s.move_t = 0.0
			s.move_dur = randf_range(2.4, 3.6) * (1.6 if collapsed > 0.0 else 1.0)


func _run(dt: float) -> void:
	var pl: Vector2 = game.player.pos
	if collapsed > 0.0:
		collapsed -= dt
		if collapsed <= 0.0:
			collapsed = 0.0
			_spread(core_pos(), false)
	_move(dt)
	for s: S in ss:
		if s.popped > 0.0:
			s.popped -= dt
			if s.popped <= 0.0:
				# it re-forms somewhere else
				s.popped = 0.0
				var sp: Array = _spots(1)
				s.pos = sp[0]
				s.to = s.pos
				s.move_t = 1.0
				game.fx.ring(s.pos, 6.0, R, 0.3, Pal.foe(0.6, 1.4), 1.5)
			continue
		if spread_t >= 0.0:
			continue
		# aimed bursts of orbs
		s.shot_cd -= dt
		if s.shot_cd <= 0.0 and s.lane_t < 0.0:
			s.shot_cd = BURST_EVERY[phase] * randf_range(0.9, 1.1)
			var to := (pl - s.pos).normalized()
			var n: int = BURST[phase]
			for k in n:
				var a := to.angle() + (k - (n - 1) * 0.5) * 0.16
				orbs.append([s.pos + Vector2.from_angle(a) * (R + 6.0), Vector2.from_angle(a) * ORB_SPEED, 3.4])
			game.sfx.play("shot", 1.3, -10.0)
		# a tunnelling lane: marked, then it crosses the floor along it
		if s.lane_t >= 0.0:
			s.lane_t += dt
			if s.lane_t >= LANE_WARN:
				var d := (s.lane - s.pos)
				var step_l := LANE_SPEED * dt
				if d.length() <= step_l:
					s.pos = s.lane
					s.lane_t = -1.0
					s.to = s.pos
					s.move_t = 1.0
					game.fx.ring(s.pos, R, R * 1.8, 0.25, Pal.foe(0.7, 1.5), 2.0)
				else:
					var p0 := s.pos
					s.pos += d.normalized() * step_l
					var q := Geometry2D.get_closest_point_to_segment(pl, p0, s.pos)
					if q.distance_to(pl) < R + Player.R - 6.0 and game.player.dash_t <= 0.0:
						game.on_player_hit(d.normalized().orthogonal(), null)
	if phase >= 1 and collapsed <= 0.0 and spread_t < 0.0:
		lane_cd -= dt
		if lane_cd <= 0.0:
			lane_cd = LANE_EVERY - phase * 0.6
			# two of them (one in the second stage) cut across toward you
			var picks: Array = []
			for s: S in ss:
				if s.popped <= 0.0 and s.lane_t < 0.0:
					picks.append(s)
			picks.shuffle()
			for k in mini(phase, picks.size()):
				var s: S = picks[k]
				var d2 := (pl - s.pos).normalized()
				var far := s.pos + d2 * 900.0
				var h: Dictionary = game.arena.raycast(s.pos + d2 * (R + 2.0), far)
				var end: Vector2 = h.point - d2 * (R + 4.0) if h else far
				end = end.clamp(Arena.ROOM.position + Vector2(R, R), Arena.ROOM.end - Vector2(R, R))
				s.lane = end
				s.lane_t = 0.0
			game.sfx.play("windup", 1.2, -6.0)
	if phase >= 2:
		_mimic(dt)
	# the real one, observed, is solid: touching it hurts
	if collapsed > 0.0:
		var r := _real()
		if r != null and r.pos.distance_to(pl) < R + Player.R - 4.0:
			game.on_player_hit((pl - r.pos).normalized(), null)


# The last stage: it does what you do. Each state fires a fan of rounds into
# the walls past you; a while later the lines light and it calls them home.
func _mimic(dt: float) -> void:
	if mimic_at >= 0.0:
		mimic_at += dt
		if mimic_at >= MIMIC_RECALL - 0.8 and not mimic_warned:
			mimic_warned = true
			game.bullets.zero_light()
			game.sfx.play("focus", 1.4, -6.0)
		if mimic_at >= MIMIC_RECALL:
			mimic_at = -1.0
			mimic_warned = false
			if game.bullets.zero_recall() > 0:
				game.sfx.play("release", 0.8, -3.0)
				game.cam.add_trauma(0.2)
		return
	if collapsed > 0.0 or spread_t >= 0.0:
		return
	mimic_cd -= dt
	if mimic_cd > 0.0:
		return
	mimic_cd = MIMIC_EVERY
	mimic_at = 0.0
	var pl: Vector2 = game.player.pos
	var shooters: Array = []
	for s: S in ss:
		if s.popped <= 0.0:
			shooters.append(s)
	shooters.shuffle()
	for s: S in shooters.slice(0, 2):
		var to := pl - s.pos
		for k in 2:
			var a := to.angle() + (k - 0.5) * 0.6
			game.bullets.fire_foe(s.pos + Vector2.from_angle(a) * (R + 8.0), Vector2.from_angle(a))
		game.fx.ring(s.pos, R, R + 26.0, 0.2, Pal.foe(0.7, 1.4), 1.5)
	game.sfx.play("shot", 0.7, -2.0)


func _step_orbs(dt: float) -> void:
	var p: Vector2 = game.player.pos
	var i := 0
	while i < orbs.size():
		var o: Array = orbs[i]
		var a: Vector2 = o[0]
		var b: Vector2 = a + (o[1] as Vector2) * dt * game.stasis.slow_at(a)
		o[2] = float(o[2]) - dt
		var gone := float(o[2]) <= 0.0 or state == DEAD or state == DYING
		var h: Dictionary = game.arena.raycast(a, b)
		if h:
			gone = true
			game.fx.sparks(h.point, h.normal, 2, Pal.foe(0.7, 1.6), 180.0, 0.12, 0.8)
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if not gone and q.distance_to(p) < Player.R + ORB_R - 2.0 and game.player.dash_t <= 0.0:
			game.on_player_hit((o[1] as Vector2).normalized(), null)
			gone = true
		if gone:
			orbs.remove_at(i)
		else:
			o[0] = b
			i += 1


func _dying(dt: float) -> void:
	dying_t += dt
	var at := core_pos()
	if dying_t > 0.2 and int(dying_t * 10.0) != int((dying_t - dt) * 10.0):
		var q := at + Vector2.from_angle(randf() * TAU) * randf_range(10, 60)
		game.fx.ring(q, 4.0, 50.0, 0.3, Pal.foe(0.8, 1.6), 1.5)
		game.sfx.play("cross", randf_range(0.8, 1.2), -6.0)
	if dying_t >= 1.6:
		state = DEAD
		for k in 18:
			var a := TAU * k / 18.0
			var p0 := Vector2.from_angle(a) * R
			var p1 := Vector2.from_angle(a + TAU / 18.0) * R
			game.fx.shard(at + (p0 + p1) * 0.5, (p0 - p1) * 0.5, (p1 - p0) * 0.5, p0.normalized() * randf_range(200, 520), randf_range(-8, 8), 1.8, Pal.foe(1.0, 1.8) if k % 3 else Pal.ink(0.9, 1.4), 2.5)
		game.on_boss_dead(at)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if state == OFF:
		if enter_t > 0.0:
			# interference fringes closing in where it will appear
			var e := Pal.ease_io(enter_t)
			var c := Vector2(960, 470)
			for k in 4:
				draw_arc(c, lerpf(320.0, R, e) + k * 14.0, t, t + PI * 1.4, 48, Pal.foe(0.4 * e * dim), 1.5)
		return
	if state == DEAD:
		return
	var appear := Pal.ease_out(clampf(t / 1.2, 0.0, 1.0)) if state == ENTER else 1.0
	# lanes about to be tunnelled: a dashed red lane, filling
	for s: S in ss:
		if s.lane_t >= 0.0 and s.lane_t < LANE_WARN:
			_draw_lane(s, dim)
	for pp in pops:
		var k: float = pp[1] / 0.5
		draw_arc(pp[0], R * (1.0 - 0.6 * k), 0.0, TAU, 32, Pal.foe(0.6 * (1.0 - k) * dim), 1.5)
		var xx := 12.0 * (1.0 - k)
		draw_line(pp[0] + Vector2(-xx, -xx), pp[0] + Vector2(xx, xx), Pal.foe(0.7 * (1.0 - k) * dim, 1.4), 2.0)
		draw_line(pp[0] + Vector2(-xx, xx), pp[0] + Vector2(xx, -xx), Pal.foe(0.7 * (1.0 - k) * dim, 1.4), 2.0)
	if collapsed <= 0.0 and spread_t < 0.0 and ss.size() > 1:
		# faint threads between the states: one thing, in several places
		var th := PackedVector2Array()
		for a_i in ss.size():
			var sa: S = ss[a_i]
			var sb: S = ss[(a_i + 1) % ss.size()]
			if sa.popped > 0.0 or sb.popped > 0.0:
				continue
			var d := sb.pos - sa.pos
			var l := d.length()
			var u := d / maxf(l, 0.001)
			var s0 := R + 8.0 + fmod(t * 40.0, 24.0)
			while s0 < l - R - 8.0:
				th.append(sa.pos + u * s0)
				th.append(sa.pos + u * minf(s0 + 6.0, l - R - 8.0))
				s0 += 24.0
		if th.size() > 0:
			draw_multiline(th, Pal.foe(0.18 * dim), 1.0)
	for s: S in ss:
		if s.popped > 0.0:
			# re-forming: a dotted ring tightening
			var rk := 1.0 - s.popped / POP
			if rk > 0.6:
				var rr := lerpf(R * 2.0, R, (rk - 0.6) / 0.4)
				for j in 12:
					var a2 := TAU * j / 12.0 + t
					draw_circle(s.pos + Vector2.from_angle(a2) * rr, 1.6, Pal.foe(0.5 * dim))
			continue
		_draw_state(s, dim * appear)
	for o in orbs:
		var op: Vector2 = o[0]
		draw_circle(op, ORB_R + 3.0, Color(0, 0, 0, 0.55))
		draw_circle(op, ORB_R, Color(0.05, 0.05, 0.055))
		draw_arc(op, ORB_R, 0.0, TAU, 14, Pal.foe(0.95 * dim, 1.3), 2.0)
		draw_circle(op, ORB_R * 0.4, Pal.foe(0.9 * dim, 1.2))
	# how many places it is in, on the floor under the top wall
	var font := Fonts.get_font("SemiBold")
	var tag := Txt.t("observed_tag") % (1 if collapsed > 0.0 else N[phase])
	var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(960.0 - tw * 0.5, 150.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.foe(0.55 * dim, 1.2))


func _draw_lane(s: S, dim: float) -> void:
	var k: float = s.lane_t / LANE_WARN
	var d := s.lane - s.pos
	var l := d.length()
	var u := d / maxf(l, 0.001)
	var n := u.orthogonal()
	var fl := 0.6 + 0.4 * sin(t * 30.0)
	var w := R * 0.9
	var seg := PackedVector2Array()
	var s0 := 0.0
	while s0 < l * k:
		for sg: float in [-1.0, 1.0]:
			seg.append(s.pos + u * s0 + n * w * sg)
			seg.append(s.pos + u * minf(s0 + 14.0, l * k) + n * w * sg)
		s0 += 24.0
	if seg.size() > 0:
		draw_multiline(seg, Pal.red(0.8 * fl * dim, 1.8), 2.0)
	draw_colored_polygon(PackedVector2Array([s.pos + n * w, s.pos + u * l * k + n * w, s.pos + u * l * k - n * w, s.pos - n * w]), Pal.red(0.08 * dim, 1.2))
	# chevrons pointing the way it will go
	for j in 3:
		var c := s.pos + u * (l * k * (j + 1) / 4.0)
		draw_polyline(PackedVector2Array([c - u * 10.0 + n * 12.0, c, c - u * 10.0 - n * 12.0]), Pal.red(0.9 * fl * dim, 2.0), 2.0)


# A state of the subject: a heavy shell with an eye in it, lids and a bright
# pupil that follow you, interference fringes turning round it. Superposed,
# every state is the same: shimmering, trailed by faint copies of itself out
# of step. Observed, the real one is solid and heavy — lit rim, open eye, the
# core burning in the pupil, a ring counting down how long it stays seen.
func _draw_state(s: S, dim: float) -> void:
	var seen := collapsed > 0.0 and s.real
	var pl: Vector2 = game.player.pos
	var c := s.pos
	if not seen:
		c += Vector2(sin(t * 13.0 + s.seed), cos(t * 11.0 + s.seed * 1.7)) * 1.5
	var a := 1.0 if seen else 0.7
	var hot := flash * (1.0 if seen else 0.0)
	var col := Pal.foe(a * dim, 1.0 + 0.8 * hot).lerp(Pal.red(dim, 2.4), red * 0.8 * (1.0 if seen else 0.0))
	var look := (pl - c).normalized()
	draw_circle(c, R + 22.0, Color(0, 0, 0, 0.4 * a))
	if not seen:
		# its copies out of step, trailing it
		for j in 3:
			var off := Vector2(sin(t * 2.1 + s.seed + j * 2.0), cos(t * 1.7 + s.seed + j * 2.0)) * (6.0 + j * 5.0)
			draw_arc(c + off, R, 0.0, TAU, 44, Pal.foe((0.2 - j * 0.05) * dim), 1.0)
	draw_circle(c, R, Color(0.045, 0.045, 0.05, 0.85 + 0.15 * a))
	draw_arc(c, R, 0.0, TAU, 56, col, 4.0 if seen else 2.5)
	draw_arc(c, R - 7.0, 0.0, TAU, 48, Pal.foe(0.3 * a * dim), 1.0)
	# fringes: dashed arcs turning in opposite senses
	for j in 3:
		var rr := R + 8.0 + j * 8.0
		var sp := (0.6 + j * 0.35) * (1.0 if j % 2 == 0 else -1.0)
		var a0 := t * sp + s.seed
		for q in 3:
			var b0 := a0 + TAU * q / 3.0
			draw_arc(c, rr, b0, b0 + 0.7 - j * 0.15, 10, Pal.foe((0.42 - j * 0.1) * a * dim, 1.2), 1.3)
	# the eye: an almond turned toward you, lids, iris, pupil
	var ang := look.angle()
	var ew := R * 0.78
	# each state blinks and glances on its own: one thing, not copies of it
	var eh := R * (0.46 if seen else 0.34 * clampf(0.75 + 0.45 * sin(t * 1.3 + s.seed * 2.3), 0.12, 1.0))
	var lid := PackedVector2Array()
	for k in 17:
		var u := -1.0 + 2.0 * k / 16.0
		lid.append(c + Vector2(u * ew, -eh * (1.0 - u * u)).rotated(ang + PI * 0.5))
	for k in range(15, 0, -1):
		var u := -1.0 + 2.0 * k / 16.0
		lid.append(c + Vector2(u * ew, eh * (1.0 - u * u)).rotated(ang + PI * 0.5))
	draw_colored_polygon(lid, Color(0.02, 0.02, 0.025, 1.0))
	lid.append(lid[0])
	draw_polyline(lid, col, 2.0)
	var ic := c + (look * R * 0.12 if seen else look.rotated(sin(t * 0.9 + s.seed) * 0.5) * R * 0.14)
	draw_arc(ic, eh * 0.95, 0.0, TAU, 28, Pal.foe(0.65 * a * dim, 1.2), 1.5)
	draw_circle(ic, eh * 0.55, Pal.foe((0.85 if seen else 0.7) * dim, 1.4 + (0.8 if seen else 0.0) + 0.6 * hot))
	draw_circle(ic, eh * 0.22, Color(0.02, 0.02, 0.025))
	if seen:
		var lk := clampf(collapsed / COLLAPSE[phase], 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(t * 10.0)
		draw_arc(c, R + 36.0, -PI * 0.5, -PI * 0.5 + TAU * lk, 72, Pal.ink((0.7 + 0.3 * pulse) * dim, 1.8), 3.5)
		draw_arc(c, R + 4.0, 0.0, TAU, 56, Pal.red((0.35 + 0.35 * pulse) * dim, 2.0), 2.0)
		if flash > 0.0:
			draw_circle(c, R, Pal.foe(0.35 * flash, 1.2))
		var font := Fonts.get_font("SemiBold")
		var lab := Txt.t("observed_seen")
		var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, c + Vector2(-lw * 0.5, -R - 46.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink((0.6 + 0.4 * seen_t) * dim, 1.5))
