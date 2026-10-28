class_name Lockdown
extends Node2D
# 封锁者 LOCKDOWN: the security mech that seals 13th Street after R-0 wakes.
# Three phases, one for each thing R-0 can do (design/DECISIONS.md):
#  1 搜捕 SEARCH — two lamps sweep the yard; stand in a beam and it locks on
#    and fires down it. Pillars cast shadows. The lamps break to rounds
#    coming home (an outbound round only chips them).
#  2 镇压 SUPPRESS — it plants four legs that turn rounds away (a chip gets
#    through) and calls guards and chargers: seize one and ram the legs.
#  3 过载 OVERLOAD — its hull splits and the core shows; four wall sockets
#    light up, and rounds embedded in a lit socket are charged ×3 — recall
#    them through the core. An arc sweeps round it; pillars stop it too.
# Shares the train's interface (state, hp, hit_test, damage, ...).

enum { OFF, ENTER, RUN, DYING, DEAD }

const HOME := Vector2(960, 250)   # low enough that nothing of it crosses the HUD
const LAMP_HP := 220.0
const LEG_HP := 160.0
const CORE_HP := 450.0
const HP := LAMP_HP * 2.0 + LEG_HP * 4.0 + CORE_HP
# the drawing is laid out at 1:1 and shown a quarter larger (SIZE); radii below
# are already at size
const SIZE := 1.25
const HULL := [Vector2(-80, 0), Vector2(0, 0), Vector2(80, 0)]   # armour circles, local
const HULL_R := 70.0
const LAMPS := [Vector2(-190, 30), Vector2(190, 30)]
const LAMP_R := 30.0
const LAMP_HIT := 42.0          # a returning round only has to pass close
const LEGS := [Vector2(-240, -20), Vector2(240, -20), Vector2(-160, 120), Vector2(160, 120)]
const LEG_R := 37.0
const CORE_R := 50.0
const CORE_HIT := 64.0
const CONE_LEN := 1100.0
const CONE_HALF := 0.16
const LOCK_TIME := 0.8
const AIM_TIME := 0.7
const LEG_CHIP := 0.2           # what a round does to a leg
const LAMP_CHIP := 0.2          # what an outbound round does to a lamp
const LEG_SHELL := 1.6          # what a seized shell's move does to it
const SOCKETS := [[Vector2(80, 540), Vector2(1, 0)], [Vector2(1840, 540), Vector2(-1, 0)], [Vector2(560, 1010), Vector2(0, -1)], [Vector2(1360, 1010), Vector2(0, -1)]]
const SOCKET_HALF := 64.0
const ARC_LEN := 900.0
const ARC_CYCLE := 5.0          # warn 0.8 s, live 3 s, off 1.2 s
const ARC_WARN := 0.8
const ARC_LIVE := 3.8

var game
var state := OFF
var t := 0.0
var hp := HP
var phase := 0
var pos := HOME
var vel := Vector2.ZERO
var tilt := 0.0
var flash := 0.0
var red := 0.0
var core_open := 0.0          # 0 shut .. 1 open (P3); read by the HUD and the bots
var enter_t := 0.0
var dying_t := 0.0
var lamp_hp := [LAMP_HP, LAMP_HP]
var lamp_a := [PI / 2.0, PI / 2.0]   # where each beam points
var lamp_lock := [0.0, 0.0]          # time you have stood in it
var lamp_aim := [-1.0, -1.0]         # >=0: aiming, counting to the shot
var lamp_at := [Vector2.ZERO, Vector2.ZERO]
var lamp_cool := [0.0, 0.0]
var lamp_flash := [0.0, 0.0]
var leg_hp := [LEG_HP, LEG_HP, LEG_HP, LEG_HP]
var leg_flash := [0.0, 0.0, 0.0, 0.0]
var plant := 0.0                     # 0 legs up .. 1 planted
var core_hp := CORE_HP
var summon_t := 0.0
var wave_t := 0.0
var waves: Array = []                # suppression rings [radius, t]
var arc_a := PI / 2.0
var arc_t := 0.0
var charged := {}                    # embedded rounds a lit socket has charged
var shots: Array = []                # beam shots [from, to, t]


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_lockdown"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


func begin_track() -> void:
	# during the title the yard's warning stripes come on along the top wall
	state = OFF
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	_fresh()
	pos = HOME + Vector2(0, -90)
	game.sfx.play("horn", 0.8, -2.0)
	game.cam.add_trauma(0.35)


func reset() -> void:
	state = OFF
	t = 0.0
	enter_t = 0.0
	_fresh()


func _fresh() -> void:
	hp = HP
	phase = 0
	pos = HOME
	vel = Vector2.ZERO
	tilt = 0.0
	core_open = 0.0
	lamp_hp = [LAMP_HP, LAMP_HP]
	lamp_a = [PI / 2.0 - 0.5, PI / 2.0 + 0.5]
	lamp_lock = [0.0, 0.0]
	lamp_aim = [-1.0, -1.0]
	lamp_cool = [0.0, 0.0]
	leg_hp = [LEG_HP, LEG_HP, LEG_HP, LEG_HP]
	plant = 0.0
	core_hp = CORE_HP
	summon_t = 0.0
	wave_t = 3.0
	waves.clear()
	shots.clear()
	_uncharge()


func dev_strike() -> void:
	if state != RUN:
		return
	match phase:
		0:
			for k in 2:
				_hurt_lamp(k, LAMP_HP, lamp_pos(k))
		1:
			for k in 4:
				_hurt_leg(k, LEG_HP, leg_pos(k))
		_:
			_hurt_core(CORE_HP, pos)


# ---------------------------------------------------------------- where things are

func _local(p: Vector2) -> Vector2:
	return pos + (p * SIZE).rotated(tilt)


func lamp_pos(k: int) -> Vector2:
	return _local(LAMPS[k])


func leg_pos(k: int) -> Vector2:
	# the legs reach out from under the hull as it plants
	return _local((LEGS[k] as Vector2) * lerpf(0.45, 1.0, Pal.ease_out(plant)))


func core_pos() -> Vector2:
	# whatever can be hurt right now, nearest to you
	var pl: Vector2 = game.player.pos if game else HOME
	var best := pos
	var bd := INF
	if phase == 0:
		for k in 2:
			if lamp_hp[k] > 0.0 and lamp_pos(k).distance_to(pl) < bd:
				bd = lamp_pos(k).distance_to(pl)
				best = lamp_pos(k)
	elif phase == 1:
		for k in 4:
			if leg_hp[k] > 0.0 and leg_pos(k).distance_to(pl) < bd:
				bd = leg_pos(k).distance_to(pl)
				best = leg_pos(k)
	return best


func core_vel() -> Vector2:
	return vel


# ---------------------------------------------------------------- rounds

# The nearest thing along a + (b - a): lamps (P1), legs (P2) and the core (P3)
# can be hurt; the hull turns rounds away.
func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	var best_t := INF
	var out := {}
	var d := b - a
	var cands: Array = []
	for c in HULL:
		var hc: Vector2 = c
		if phase == 2:
			# split open: the armour parts to the sides
			hc = Vector2(signf(hc.x) * (60.0 + 50.0 * core_open), 0.0) if hc.x != 0.0 else Vector2.INF
		if hc != Vector2.INF:
			cands.append([_local(hc), HULL_R * (0.7 if phase == 2 else 1.0), false, 0, 1.0])
	if phase == 0:
		for k in 2:
			if lamp_hp[k] > 0.0:
				cands.append([lamp_pos(k), LAMP_HIT, true, 1 + k, 1.0])
	elif phase == 1:
		for k in 4:
			if leg_hp[k] > 0.0:
				cands.append([leg_pos(k), LEG_R, true, 11 + k, LEG_CHIP])
	elif core_open > 0.5:
		cands.append([pos, CORE_HIT, true, 20, 1.0])
	for c in cands:
		var ht := Geometry2D.segment_intersects_circle(a, b, c[0], c[1])
		if ht >= 0.0 and ht < best_t:
			best_t = ht
			var p := a + d * ht
			out = {"point": p, "normal": (p - (c[0] as Vector2)).normalized(), "core": c[2], "car": 0, "frame": c[3], "mult": c[4]}
	return out


func on_armor(_k: int, at_p: Vector2, normal: Vector2) -> void:
	flash = maxf(flash, 0.4)
	game.fx.sparks(at_p, normal, 6, Pal.foe(1.0, 2.0), 460.0, 0.2, 0.9)
	game.fx.flash(at_p, 20.0, 0.1, Pal.foe(0.5, 1.6))
	game.sfx.play("shield", randf_range(0.8, 0.95), -6.0)


func damage(dmg: float, ret: bool, at_p: Vector2, d: Vector2, frame_k: int = -1) -> void:
	if state != RUN:
		return
	dmg /= Loadout.boss_hp()
	var f := frame_k
	if f < 0:
		f = _frame_near(at_p)
	if f >= 1 and f <= 2:
		if not ret:
			# outbound rounds mostly glance off the glass: a chip, so no one is
			# ever stuck, but the way in is a round coming home
			lamp_flash[f - 1] = 0.5
			game.fx.sparks(at_p, -d, 4, Pal.foe(1.0, 2.0), 380.0, 0.16, 0.8)
			game.sfx.play("shield", randf_range(1.3, 1.5), -9.0)
			_hurt_lamp(f - 1, dmg * LAMP_CHIP, at_p)
			return
		_hurt_lamp(f - 1, dmg, at_p)
	elif f >= 11 and f <= 14:
		_hurt_leg(f - 11, dmg * LEG_CHIP, at_p)
	elif f == 20:
		_hurt_core(dmg, at_p)
	else:
		return
	if ret:
		red = 1.0
	var c := Pal.red(1.0, 3.2) if ret else Pal.foe(1.0, 1.8)
	game.fx.sparks(at_p, d, 8 if ret else 5, c, 560.0, 0.28, 0.8)
	game.on_target_hit(ret)


# A seized shell's move (Possess asks before the usual armour test): it is
# what breaks the legs, and it can smash a lamp too.
func shell_strike(a: Vector2, b: Vector2, radius: float, dmg: float) -> bool:
	if state != RUN:
		return false
	dmg /= Loadout.boss_hp()
	var hit := false
	if phase == 0:
		for k in 2:
			if lamp_hp[k] > 0.0 and _seg_near(a, b, lamp_pos(k), LAMP_R + radius):
				_hurt_lamp(k, dmg, lamp_pos(k))
				hit = true
	elif phase == 1:
		for k in 4:
			if leg_hp[k] > 0.0 and _seg_near(a, b, leg_pos(k), LEG_R + radius):
				_hurt_leg(k, dmg * LEG_SHELL, leg_pos(k))
				hit = true
	return hit


func _seg_near(a: Vector2, b: Vector2, c: Vector2, r: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c) <= r


func _frame_near(p: Vector2) -> int:
	var best := -1
	var bd := INF
	if phase == 0:
		for k in 2:
			if lamp_hp[k] > 0.0 and lamp_pos(k).distance_to(p) < bd:
				bd = lamp_pos(k).distance_to(p)
				best = 1 + k
	elif phase == 1:
		for k in 4:
			if leg_hp[k] > 0.0 and leg_pos(k).distance_to(p) < bd:
				bd = leg_pos(k).distance_to(p)
				best = 11 + k
	elif core_open > 0.5:
		best = 20
	return best


func _hurt_lamp(k: int, dmg: float, at_p: Vector2) -> void:
	if lamp_hp[k] <= 0.0:
		return
	var took := minf(dmg, lamp_hp[k])
	lamp_hp[k] -= took
	lamp_flash[k] = 1.0
	flash = 1.0
	game.fx.number(at_p, took, true)
	if lamp_hp[k] <= 0.0:
		# the glass bursts and the beam dies with a flicker
		var lp := lamp_pos(k)
		for j in 12:
			var a := TAU * j / 12.0
			game.fx.shard(lp, Vector2.from_angle(a) * 6.0, Vector2.from_angle(a + 0.4) * 10.0, Vector2.from_angle(a) * randf_range(240, 480), randf_range(-10, 10), 0.9, Pal.foe(1.0, 2.0), 2.0)
		game.fx.ring(lp, LAMP_R, 160.0, 0.45, Pal.foe(1.0, 2.2), 2.5)
		game.sfx.play("armor", 1.4, -2.0)
		game.add_hitstop(0.06)
		game.cam.add_trauma(0.35)
		lamp_aim[k] = -1.0
		if lamp_hp[0] <= 0.0 and lamp_hp[1] <= 0.0:
			_to_phase(1)
	_sum()


func _hurt_leg(k: int, dmg: float, at_p: Vector2) -> void:
	if leg_hp[k] <= 0.0:
		return
	var took := minf(dmg, leg_hp[k])
	leg_hp[k] -= took
	leg_flash[k] = 1.0
	flash = maxf(flash, 0.6)
	game.fx.number(at_p, took, true)
	if leg_hp[k] <= 0.0:
		var lp := leg_pos(k)
		for j in 10:
			var a := TAU * j / 10.0
			game.fx.shard(lp, Vector2.from_angle(a) * 8.0, Vector2.from_angle(a + 0.5) * 14.0, Vector2.from_angle(a) * randf_range(200, 420), randf_range(-8, 8), 1.0, Pal.foe(1.0, 1.8), 2.5)
		game.fx.ring(lp, LEG_R, 200.0, 0.5, Pal.foe(0.9, 1.8), 3.0)
		game.sfx.play("slam", 0.7, 0.0)
		game.add_hitstop(0.08)
		game.cam.add_trauma(0.5)
		game.cam.punch(0.03)
		var left := 0
		for v in leg_hp:
			if v > 0.0:
				left += 1
		if left == 0:
			_to_phase(2)
	_sum()


func _hurt_core(dmg: float, at_p: Vector2) -> void:
	if core_hp <= 0.0:
		return
	var took := minf(dmg, core_hp)
	core_hp -= took
	flash = 1.0
	game.fx.number(at_p, took, true)
	_sum()
	if core_hp <= 0.0:
		state = DYING
		dying_t = 0.0
		_uncharge()
		game.on_boss_dying()


func _sum() -> void:
	hp = maxf(0.0, lamp_hp[0]) + maxf(0.0, lamp_hp[1]) + core_hp
	for v in leg_hp:
		hp += maxf(0.0, v)


func _to_phase(p: int) -> void:
	phase = p
	game.hud.boss_phase()
	game.sfx.play("armor", 0.9, 0.0)
	game.add_hitstop(0.1)
	game.cam.add_trauma(0.6)
	game.cam.punch(0.04)
	game.fx.ring(pos, 90.0, 420.0, 0.6, Pal.foe(0.9, 1.6), 3.0)
	if p == 1:
		summon_t = 0.6
		wave_t = 4.0
		_summon(Enemies.CHARGER)
	elif p == 2:
		waves.clear()
		game.sfx.play("core", 0.8, 0.0)
		# its hull splits: plates fly a little way out
		for j in 16:
			var a := TAU * j / 16.0
			game.fx.shard(pos + Vector2.from_angle(a) * 60.0, Vector2.from_angle(a) * 10.0, Vector2.from_angle(a + 0.3) * 18.0, Vector2.from_angle(a) * randf_range(160, 360), randf_range(-6, 6), 1.2, Pal.foe(1.0, 1.6), 2.5)


func _summon(kind: int) -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	var at := Vector2(960.0 + side * randf_range(420.0, 700.0), randf_range(420.0, 620.0))
	if not game.arena.is_free(at, 30.0):
		at = Vector2(960.0 + side * 560.0, 450.0)
	game.enemies.spawn(kind, at, 0.0)


func _uncharge() -> void:
	for b in charged:
		b.dmg = charged[b]
	charged.clear()


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
	for k in 2:
		lamp_flash[k] = maxf(0.0, lamp_flash[k] - dt / 0.18)
	for k in 4:
		leg_flash[k] = maxf(0.0, leg_flash[k] - dt / 0.18)
	for s in shots:
		s[2] += dt
	while shots.size() > 0 and shots[0][2] > 0.35:
		shots.pop_front()
	var pl: Vector2 = game.player.pos
	match state:
		ENTER:
			# it settles out of the dark above the yard (never across the HUD)
			var k := Pal.ease_in(clampf(t / 0.9, 0.0, 1.0))
			pos = (HOME + Vector2(0, -90)).lerp(HOME, k)
			if t >= 0.9 and t - dt < 0.9:
				game.sfx.play("slam", 0.6, 2.0)
				game.cam.add_trauma(0.7)
				game.fx.ring(pos, 60.0, 500.0, 0.6, Pal.foe(1.0, 1.8), 3.0)
			if t >= 1.3:
				state = RUN
				t = 0.0
		RUN:
			_run(dt, pl)
		DYING:
			_dying(dt)
	if state == RUN and not game.possess.busy():
		# the hull shoves you out of the way; it only hurts when it is moving
		for c in HULL:
			var hp_c := _local(c)
			var dd := hp_c.distance_to(pl)
			if dd < HULL_R + Player.R:
				var out := (pl - hp_c) / maxf(dd, 0.01)
				game.player.pos = hp_c + out * (HULL_R + Player.R + 1.0)
				if vel.length() > 60.0:
					game.on_player_hit(out, null)
	queue_redraw()


func _run(dt: float, pl: Vector2) -> void:
	match phase:
		0:
			# patrols along the top, the lamps sweeping out of step
			var gx := 960.0 + sin(t * 0.3) * 140.0
			vel = Pal.damp2(vel, Vector2((gx - pos.x) * 1.2, (HOME.y - pos.y) * 2.0), 3.0, dt)
			pos += vel * dt
			for k in 2:
				_lamp(k, dt, pl)
		1:
			# planted: it stands, calls the guard, and pushes rings out
			plant = minf(1.0, plant + dt / 0.6)
			vel = Pal.damp2(vel, Vector2.ZERO, 6.0, dt)
			pos += vel * dt
			var broken := 0
			var lean := 0.0
			for k in 4:
				if leg_hp[k] <= 0.0:
					broken += 1
					lean += -signf((LEGS[k] as Vector2).x) * 0.05
			tilt = Pal.damp(tilt, lean, 3.0, dt)
			summon_t -= dt
			if summon_t <= 0.0:
				summon_t = 5.0
				if game.enemies.remaining() < 4:
					_summon(Enemies.CHARGER if randf() < 0.5 else Enemies.GUARD)
			wave_t -= dt
			if wave_t <= 0.0:
				wave_t = 8.0 - broken * 0.6
				waves.append([0.0, -0.8])   # 0.8 s of warning first
				game.sfx.play("windup", 0.6, -2.0)
			_step_waves(dt, pl)
		2:
			plant = maxf(0.0, plant - dt / 0.5)
			core_open = minf(1.0, core_open + dt / 0.8)
			tilt = Pal.damp(tilt, 0.0, 2.0, dt)
			var gx2 := 960.0 + sin(t * 0.22) * 160.0
			vel = Pal.damp2(vel, Vector2((gx2 - pos.x) * 1.0, (HOME.y + 30.0 - pos.y) * 2.0), 2.0, dt)
			pos += vel * dt
			_charge_sockets()
			# the arc: one line out of the core, turning; pillars stop it. It
			# comes in beats — a thin warning, three seconds live, a breath off
			arc_t = fmod(arc_t + dt, ARC_CYCLE)
			arc_a += dt * 0.45
			if arc_live():
				var end := _arc_end()
				if Geometry2D.get_closest_point_to_segment(pl, pos, end).distance_to(pl) < Player.R + 4.0 and game.player.dash_t <= 0.0:
					game.on_player_hit((pl - pos).normalized(), null)


func _lamp(k: int, dt: float, pl: Vector2) -> void:
	if lamp_hp[k] <= 0.0:
		return
	var lp := lamp_pos(k)
	lamp_cool[k] = maxf(0.0, lamp_cool[k] - dt)
	if lamp_aim[k] >= 0.0:
		# locked: a thin line first, then the shot down it
		lamp_aim[k] += dt
		if lamp_aim[k] < AIM_TIME * 0.55:
			lamp_at[k] = lamp_at[k].lerp(pl, 1.0 - exp(-10.0 * dt))
		lamp_a[k] = (lamp_at[k] - lp).angle()
		if lamp_aim[k] >= AIM_TIME:
			lamp_aim[k] = -1.0
			lamp_cool[k] = 1.3
			lamp_lock[k] = 0.0
			var to: Vector2 = lp + (lamp_at[k] - lp).normalized() * 1800.0
			var h: Dictionary = game.arena.raycast(lp, to)
			if h:
				to = h.point
			shots.append([lp, to, 0.0])
			game.sfx.play("dash_e", 1.4, -3.0)
			game.cam.add_trauma(0.12)
			game.fx.flash(lp, 40.0, 0.12, Pal.red(0.7, 2.4))
			if Geometry2D.get_closest_point_to_segment(pl, lp, to).distance_to(pl) < Player.R + 6.0 and game.player.dash_t <= 0.0:
				game.on_player_hit((to - lp).normalized(), null)
		return
	# sweeping: a slow swing, out of step with the other lamp
	var swing := PI / 2.0 + sin(t * 0.55 + k * PI) * 0.95
	lamp_a[k] = lerp_angle(lamp_a[k], swing, 1.0 - exp(-3.0 * dt))
	if lamp_cool[k] > 0.0:
		return
	var to_p := pl - lp
	var lit: bool = to_p.length() < CONE_LEN and absf(wrapf(to_p.angle() - lamp_a[k], -PI, PI)) < CONE_HALF and not game.arena.raycast(lp, pl)
	if lit:
		lamp_lock[k] += dt
		if lamp_lock[k] >= LOCK_TIME:
			lamp_aim[k] = 0.0
			lamp_at[k] = pl
			game.sfx.play("lit", 1.6, -4.0)
	else:
		lamp_lock[k] = maxf(0.0, lamp_lock[k] - dt * 2.0)


func _step_waves(dt: float, pl: Vector2) -> void:
	var i := 0
	while i < waves.size():
		var w: Array = waves[i]
		w[1] += dt
		if w[1] >= 0.0:
			if w[1] - dt < 0.0:
				game.sfx.play("slam", 0.8, -2.0)
				game.cam.add_trauma(0.25)
			w[0] = Pal.ease_out(clampf(w[1] / 1.2, 0.0, 1.0)) * 760.0
			# the ring's edge hurts; a dash carries you through it
			if absf(pos.distance_to(pl) - w[0]) < 10.0 and game.player.dash_t <= 0.0 and w[1] < 1.2:
				game.on_player_hit((pl - pos).normalized(), null)
		if w[1] >= 1.3:
			waves.remove_at(i)
		else:
			i += 1


func arc_live() -> bool:
	return arc_t >= ARC_WARN and arc_t < ARC_LIVE


func _arc_end() -> Vector2:
	var end := pos + Vector2.from_angle(arc_a) * ARC_LEN
	var h: Dictionary = game.arena.raycast(pos, end)
	return h.point if h else end


func socket_lit(k: int) -> bool:
	return phase == 2 and core_open >= 1.0


func _in_socket(p: Vector2, k: int) -> bool:
	var c: Vector2 = SOCKETS[k][0]
	var n: Vector2 = SOCKETS[k][1]
	var along := (p - c).dot(n.orthogonal())
	var into := (p - c).dot(n)
	return absf(along) <= SOCKET_HALF and into >= -8.0 and into <= 30.0


func _charge_sockets() -> void:
	if core_open < 1.0:
		return
	for b in game.bullets.list:
		if b.state != Bullets.EMBED or charged.has(b):
			continue
		for k in SOCKETS.size():
			if _in_socket(b.pos, k):
				charged[b] = b.dmg
				b.dmg *= 3.0
				game.fx.sparks(b.pos, SOCKETS[k][1], 8, Pal.ink(1.0, 2.6), 420.0, 0.2, 1.2)
				game.sfx.play("lit", 1.2, -6.0)
				break
	# forget rounds that have gone home or out
	for b in charged.keys():
		if b.state != Bullets.EMBED and b.state != Bullets.PULL and b.state != Bullets.RETURN:
			b.dmg = charged[b]
			charged.erase(b)


func _dying(dt: float) -> void:
	dying_t += dt
	vel = Pal.damp2(vel, Vector2.ZERO, 4.0, dt)
	pos += vel * dt + Vector2(sin(dying_t * 70.0), cos(dying_t * 63.0)) * 3.0 * dying_t
	if dying_t > 0.2 and int(dying_t * 10.0) != int((dying_t - dt) * 10.0):
		game.fx.sparks(pos + Vector2.from_angle(randf() * TAU) * 80.0, Vector2.from_angle(randf() * TAU), 6, Pal.foe(1.0, 1.8), 420.0, 0.3, 1.0)
		game.sfx.play("cross", randf_range(0.6, 1.1), -6.0)
	if dying_t >= 1.6:
		state = DEAD
		for k in 40:
			var a := TAU * k / 40.0
			var p0 := Vector2.from_angle(a) * 120.0 * Vector2(1.0, 0.5)
			var p1 := Vector2.from_angle(a + 0.3) * 80.0 * Vector2(1.0, 0.5)
			game.fx.shard(pos + (p0 + p1) * 0.5, (p0 - p1) * 0.5, (p1 - p0) * 0.5, p0.normalized() * randf_range(300, 700), randf_range(-12, 12), 1.4, Pal.foe(1.0, 1.7), 2.0)
		game.on_boss_dead(pos)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if state == OFF:
		if enter_t > 0.0:
			pass
		return
	if state == DEAD:
		return
	if state == ENTER:
		dim *= clampf(t / 0.9, 0.0, 1.0)
	if phase == 2:
		_draw_sockets(dim)
	var col := Pal.foe(dim, 1.0 + 0.8 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	# beams under the body
	if phase == 0 and state == RUN:
		for k in 2:
			_draw_beam(k, dim)
	for s in shots:
		var sk: float = 1.0 - s[2] / 0.35
		draw_line(s[0], s[1], Pal.red(sk * dim, 3.0), 5.0 * sk + 1.0)
	# legs
	if plant > 0.01:
		for k in 4:
			var lp := leg_pos(k)
			var root := _local((LEGS[k] as Vector2) * 0.35)
			if leg_hp[k] > 0.0:
				var lc := Pal.foe(dim, 1.0 + 1.2 * leg_flash[k])
				draw_line(root, lp, lc, 4.0)
				draw_arc(lp, LEG_R, 0.0, TAU, 24, lc, 2.5, false)
				draw_arc(lp, LEG_R - 8.0, 0.0, TAU, 20, Pal.foe(0.3 * dim), 1.0, false)
				# how much is left: a bar of ticks round the pad
				var n := int(ceil(leg_hp[k] / LEG_HP * 8.0))
				for j in n:
					var a := -PI / 2.0 + TAU * j / 8.0
					draw_line(lp + Vector2.from_angle(a) * (LEG_R + 5.0), lp + Vector2.from_angle(a) * (LEG_R + 10.0), Pal.foe(0.7 * dim), 2.0)
			else:
				draw_line(root, root.lerp(lp, 0.4), Pal.foe(0.25 * dim), 2.0)
	# hull: a long low shape with ribbing; in overload it splits open
	var open := core_open
	for side in [-1.0, 1.0]:
		var sh := Vector2(side * 22.0 * open, 0.0)
		var pts := PackedVector2Array([
			_local(Vector2(side * 6.0, -50.0) + sh), _local(Vector2(side * 120.0, -50.0) + sh),
			_local(Vector2(side * 150.0, -10.0) + sh), _local(Vector2(side * 120.0, 46.0) + sh),
			_local(Vector2(side * 6.0, 46.0) + sh)])
		draw_colored_polygon(pts, Color(0.05, 0.05, 0.055, 1.0))
		pts.append(pts[0])
		draw_polyline(pts, col, 2.5, false)
		for j in 4:
			var x: float = side * (30.0 + j * 24.0)
			draw_line(_local(Vector2(x, -38.0) + sh), _local(Vector2(x, 34.0) + sh), Pal.foe(0.22 * dim), 1.0)
	# the red warning band across its face
	if open < 0.5:
		draw_line(_local(Vector2(-110, -30)), _local(Vector2(110, -30)), Pal.red(0.85 * dim, 2.0), 3.0)
	# the core
	if open > 0.01:
		var cr := CORE_R * Pal.back(open)
		var pulse := 0.5 + 0.5 * sin(t * 7.0)
		draw_circle(pos, cr, Color(0.06, 0.02, 0.02, 1.0))
		draw_arc(pos, cr, 0.0, TAU, 32, Pal.red(dim, 2.2 + 1.2 * pulse + 1.5 * flash), 3.0, false)
		draw_arc(pos, cr * 0.55, 0.0, TAU, 24, Pal.red(0.6 * dim, 2.0), 1.5, false)
		# the arc it throws round the yard: a faint line while it warns
		if state == RUN and arc_t < ARC_LIVE:
			var end := _arc_end()
			if not arc_live():
				# the warning: a red fan over the ground the arc will sweep first
				var wk := arc_t / ARC_WARN
				var fan := PackedVector2Array([pos])
				var fc := PackedColorArray([Pal.red(0.0)])
				for j in 9:
					var fa := arc_a + 0.5 * j / 8.0
					fan.append(pos + Vector2.from_angle(fa) * ARC_LEN)
					fc.append(Pal.red(0.14 * wk * dim, 1.4))
				draw_polygon(fan, fc)
				draw_line(pos, end, Pal.red((0.3 + 0.5 * wk) * dim, 2.0), 2.0)
			var segs := PackedVector2Array()
			var steps := 14 if arc_live() else 0
			for j in steps:
				var q0 := pos.lerp(end, float(j) / steps)
				var q1 := pos.lerp(end, float(j + 1) / steps)
				var jit := (end - pos).normalized().orthogonal() * randf_range(-6.0, 6.0)
				segs.append(q0 + (jit if j > 0 else Vector2.ZERO))
				segs.append(q1 + jit)
			if segs.size() > 0:
				draw_multiline(segs, Pal.red(0.9 * dim, 2.6), 6.0)
				draw_multiline(segs, Pal.ink(dim, 2.8), 1.5)
	# lamps on their arms
	for k in 2:
		var lp := lamp_pos(k)
		var arm0 := _local(Vector2(signf((LAMPS[k] as Vector2).x) * 120.0, 10.0))
		if lamp_hp[k] > 0.0:
			draw_line(arm0, lp, col, 3.0)
			# a square housing, its lens turned along the beam: nothing like you
			var face := Vector2.from_angle(lamp_a[k])
			var side := face.orthogonal()
			var box := PackedVector2Array([lp - face * LAMP_R - side * LAMP_R, lp + face * LAMP_R * 0.6 - side * LAMP_R, lp + face * LAMP_R * 0.6 + side * LAMP_R, lp - face * LAMP_R + side * LAMP_R])
			draw_colored_polygon(box, Color(0.05, 0.05, 0.055, 1.0))
			box.append(box[0])
			var hc := Pal.red(dim, 2.4) if lamp_aim[k] >= 0.0 else Pal.foe(dim, 1.4 + 1.4 * lamp_flash[k])
			draw_polyline(box, hc, 2.5, false)
			draw_line(lp + face * LAMP_R * 0.6 - side * LAMP_R * 0.75, lp + face * LAMP_R * 0.6 + side * LAMP_R * 0.75, Pal.ink(dim, 2.6 if lamp_aim[k] < 0.0 else 3.4), 6.0)
			# glass left: a broken ring that closes as it fills
			var g: float = lamp_hp[k] / LAMP_HP
			draw_arc(lp, LAMP_R + 6.0, -PI / 2.0, -PI / 2.0 + TAU * g, 24, Pal.foe(0.6 * dim), 1.5, false)
		else:
			draw_line(arm0, arm0.lerp(lp, 0.5), Pal.foe(0.3 * dim), 2.0)
	# suppression rings
	for w in waves:
		if w[1] < 0.0:
			var wk: float = 1.0 + w[1] / 0.8
			draw_arc(pos, 70.0 + 30.0 * wk, 0.0, TAU, 48, Pal.red(0.5 * wk * dim, 2.0), 2.0, false)
		else:
			var ra: float = 1.0 - clampf(w[1] / 1.2, 0.0, 1.0)
			draw_arc(pos, w[0], 0.0, TAU, 96, Pal.red(ra * dim, 2.4), 8.0, false)
			draw_arc(pos, maxf(0.0, w[0] - 12.0), 0.0, TAU, 96, Pal.red(0.3 * ra * dim, 1.4), 1.0, false)
	# charged rounds crackle where they sit
	for b in charged:
		if b.state == Bullets.EMBED:
			for j in 3:
				var a := randf() * TAU
				draw_line(b.pos, b.pos + Vector2.from_angle(a) * randf_range(6.0, 14.0), Pal.ink(0.9 * dim, 2.6), 1.0)


func _draw_beam(k: int, dim: float) -> void:
	if lamp_hp[k] <= 0.0:
		return
	var lp := lamp_pos(k)
	if lamp_aim[k] >= 0.0:
		# the lock: a thin red line that settles, then fires
		var ak: float = lamp_aim[k] / AIM_TIME
		var to: Vector2 = lp + (lamp_at[k] - lp).normalized() * 1800.0
		var h: Dictionary = game.arena.raycast(lp, to)
		if h:
			to = h.point
		draw_line(lp, to, Pal.red((0.35 + 0.6 * ak) * dim, 2.0 + 1.5 * ak), 1.0 + 2.0 * ak)
		return
	var cool := 0.35 if lamp_cool[k] > 0.0 else 1.0
	var lock_k: float = lamp_lock[k] / LOCK_TIME
	# a soft cone, cut short where a pillar stands in it
	var n := 12
	var pts := PackedVector2Array([lp])
	var cols := PackedColorArray([Color(1, 1, 1, (0.16 + 0.2 * lock_k) * cool * dim)])
	for j in n + 1:
		var a: float = lamp_a[k] - CONE_HALF + 2.0 * CONE_HALF * j / n
		var end := lp + Vector2.from_angle(a) * CONE_LEN
		var h2: Dictionary = game.arena.raycast(lp, end)
		pts.append(h2.point if h2 else end)
		cols.append(Color(1, 1, 1, 0.0))
	draw_polygon(pts, cols)
	if lock_k > 0.0:
		draw_line(lp, lp + Vector2.from_angle(lamp_a[k]) * 120.0, Pal.red(lock_k * dim, 2.2), 2.0)


func _draw_stripes(k: float, dim: float) -> void:
	# hazard stripes along the top wall: the street is sealed
	var y := 74.0
	var x := 700.0
	while x < 1220.0:
		var a := k * (0.5 + 0.3 * sin(t * 3.0 + x * 0.02))
		draw_line(Vector2(x, y), Vector2(x + 16.0, y + 14.0), Pal.red(a * 0.6 * dim, 1.6), 3.0)
		x += 30.0


func _draw_sockets(dim: float) -> void:
	for k in SOCKETS.size():
		var c: Vector2 = SOCKETS[k][0]
		var n: Vector2 = SOCKETS[k][1]
		var tg := n.orthogonal()
		var lit := core_open >= 1.0
		var pulse := 0.5 + 0.5 * sin(t * 6.0 + k)
		var cc := Pal.ink((0.55 + 0.4 * pulse) * dim, 2.2) if lit else Pal.foe(0.3 * dim)
		var a0 := c - tg * SOCKET_HALF + n * 4.0
		var a1 := c + tg * SOCKET_HALF + n * 4.0
		draw_line(a0, a1, cc, 3.0)
		draw_line(a0, a0 + n * 22.0, cc, 2.0)
		draw_line(a1, a1 + n * 22.0, cc, 2.0)
		if lit:
			# a lightning mark: this socket charges what sits in it
			var m := c + n * 16.0
			draw_polyline(PackedVector2Array([m - tg * 8.0 - n * 6.0, m + n * 2.0, m - n * 2.0, m + tg * 8.0 + n * 6.0]), cc, 2.0, false)
