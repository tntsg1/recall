class_name Testbed
extends Node2D
# 军械试验平台 THE ORDNANCE TESTBED (chapter 3): a weapons platform bolted to
# the range's top wall. It runs its test programme on you, one item at a
# time, with every laser fence lit; its screen names each test. After each
# one it passes itself, drops the beams and opens its vents to cool: the core
# shows through the slot, and the rounds you left in the walls can come home
# through it.
#  测试 01 远程压制: missiles fall on marked circles
#  测试 02 人群驱散: flame fans sweep the floor (cover stops them, a dash goes through)
#  测试 03 重点清除: a rail gun locks on, holds, fires
#  测试 04 全项联测 (last phase): missiles and the rail gun together
# Shares the bosses' interface (state, hp, hit_test, damage, ...).

enum { OFF, ENTER, RUN, DYING, DEAD }
enum { BOOT, ANNOUNCE, TEST, PASS, VENT }

const HP := 1500.0
const HULL := Rect2(700, 120, 520, 180)
const HOME := Vector2(960, 210)
const SLOT := Rect2(880, 214, 160, 86)     # the vent slot in the hull's front
const CORE := Vector2(960, 256)
const CORE_R := 40.0
const CORE_HIT := 58.0
const TURRET := Vector2(960, 176)
const BARREL := 150.0
const NOZZLES := [Vector2(752, 300), Vector2(1168, 300)]
const SCREEN := Rect2(716, 134, 208, 64)
const POD := Rect2(1000, 134, 204, 64)
const ENTER_TIME := 1.4
const BOOT_TIME := 1.0
const ANNOUNCE_TIME := 1.1
const PASS_TIME := 0.7
const VENT_TIME := [3.4, 3.1, 2.8]
const MIS_R := 92.0
const MIS_FALL := 1.25
const FLAME_TIME := 3.0
const FLAME_HALF := 0.22
const FLAME_REACH := 980.0
const RAIL_LOCK := 1.3
const RAIL_HOLD := 0.4
const RAIL_GAP := 0.35
const RAIL_W := 24.0

var game
var state := OFF
var t := 0.0
var hp := HP
var phase := 0
var pos := HOME              # the hull's centre (it slides down on entry)
var drop := 0.0              # how far above its home the hull still hangs
var core_open := 0.0
var flash := 0.0
var red := 0.0
var guard_t := 0.0
var dying_t := 0.0
var enter_t := 0.0
var stage := BOOT
var stage_t := 0.0
var test := 0                # 0..3: which test is running
var tests_run := 0
var missiles: Array = []     # [from, target, t]
var mis_left := 0
var mis_cd := 0.0
var flames: Array = []       # [nozzle index, a0, a1]
var flame_t := 0.0
var rail_a := PI / 2.0
var rail_ext := 1.0          # the barrel runs back into the deck while it cools
var rail_mode := 0           # 0 idle, 1 lock, 2 hold, 3 gap after a shot
var rail_t := 0.0
var rail_left := 0
var rail_shot := 0.0         # fades the last beam
var rail_end := Vector2.ZERO
var stamp := 0.0             # the "passed" stamp on the screen
var steam_cd := 0.0
var puff_cd := 0.0
var pod_open := 0.0          # the missile pod's lid, slid back for a missile test


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_testbed"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


func begin_track() -> void:
	state = OFF
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	_fresh()
	drop = 1.0
	game.sfx.play("horn", 0.7, -2.0)
	game.cam.add_trauma(0.3)
	game.hud.radio(Txt.t("radio_testbed"))
	game.lasers.force(false)


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
	stage = BOOT
	stage_t = 0.0
	test = 0
	tests_run = 0
	missiles.clear()
	flames.clear()
	rail_mode = 0
	rail_shot = 0.0
	rail_a = PI / 2.0
	rail_ext = 1.0
	stamp = 0.0
	drop = 0.0
	pos = HOME


func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	damage(HP, false, CORE, Vector2.UP)


func core_pos() -> Vector2:
	return CORE + Vector2(0, pos.y - HOME.y)


func core_vel() -> Vector2:
	return Vector2.ZERO


func _off() -> Vector2:
	return pos - HOME


# ---------------------------------------------------------------- bullets

# Closed, the whole hull is armour. Open, the slot in its front leads to the
# core, and only the two halves either side still turn rounds away.
func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	var o := _off()
	if core_open < 0.5:
		var h := _rect_hit(a, b, Rect2(HULL.position + o, HULL.size))
		if h.is_empty():
			return {}
		return {"point": h.point, "normal": h.normal, "core": false, "car": 0}
	var best := {}
	var bt := 2.0
	for r: Rect2 in [Rect2(HULL.position.x, HULL.position.y, SLOT.position.x - HULL.position.x, HULL.size.y),
			Rect2(SLOT.end.x, HULL.position.y, HULL.end.x - SLOT.end.x, HULL.size.y),
			Rect2(SLOT.position.x, HULL.position.y, SLOT.size.x, SLOT.position.y - HULL.position.y)]:
		var h2 := _rect_hit(a, b, Rect2(r.position + o, r.size))
		if not h2.is_empty() and h2.t < bt:
			bt = h2.t
			best = {"point": h2.point, "normal": h2.normal, "core": false, "car": 0}
	var c := core_pos()
	var hc := Geometry2D.segment_intersects_circle(a, b, c, CORE_HIT)
	if hc >= 0.0 and hc < bt:
		var p := a + (b - a) * hc
		return {"point": p, "normal": (p - c).normalized(), "core": true, "mult": 1.0}
	return best


func _rect_hit(a: Vector2, b: Vector2, r: Rect2) -> Dictionary:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var n := Vector2.ZERO
	for axis in 2:
		var p: float = a[axis]
		var dd: float = d[axis]
		var lo: float = r.position[axis]
		var hi: float = r.end[axis]
		if absf(dd) < 1e-9:
			if p < lo or p > hi:
				return {}
		else:
			var ta := (lo - p) / dd
			var tb := (hi - p) / dd
			var nn := -1.0
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
				nn = 1.0
			if ta > t0:
				t0 = ta
				n = Vector2.ZERO
				n[axis] = nn
			t1 = minf(t1, tb)
			if t0 > t1:
				return {}
	if n == Vector2.ZERO:
		return {}
	return {"point": a + d * t0, "normal": n, "t": t0}


func on_armor(_k: int, at_p: Vector2, normal: Vector2) -> void:
	game.fx.sparks(at_p, normal, 6, Pal.foe(1.0, 2.0), 460.0, 0.2, 0.9)
	game.fx.flash(at_p, 18.0, 0.1, Pal.foe(0.5, 1.6))
	game.sfx.play("armor", randf_range(1.3, 1.5), -9.0)


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
		missiles.clear()
		flames.clear()
		rail_mode = 0
		game.lasers.force(false)
		game.on_boss_dying()


func _phase_break() -> void:
	guard_t = 1.2
	var c := core_pos()
	game.fx.ring(c, CORE_R, 300.0, 0.6, Pal.foe(0.9, 1.5), 3.0)
	for k in 8:
		var p := c + Vector2.from_angle(TAU * k / 8.0) * CORE_R
		game.fx.shard(p, Vector2(-8, -3), Vector2(8, 3), (p - c).normalized() * randf_range(260, 460), randf_range(-9, 9), 1.0, Pal.foe(1.0, 1.6), 2.5)
	game.sfx.play("armor", 1.0, 0.0)
	game.add_hitstop(0.09)
	game.cam.add_trauma(0.6)
	game.cam.punch(0.04)
	game.hud.boss_phase()
	if phase == 1:
		# two pursuit prototypes are let out of the side bays
		for k in 2:
			game.enemies.spawn(Enemies.ECHO, Vector2(HULL.position.x - 60.0 if k == 0 else HULL.end.x + 60.0, 360.0), 0.3 * k)


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	if state == OFF or state == DEAD:
		return
	t += dt
	flash = maxf(0.0, flash - dt / 0.12)
	red = maxf(0.0, red - dt / 0.8)
	guard_t = maxf(0.0, guard_t - dt)
	rail_shot = maxf(0.0, rail_shot - dt / 0.35)
	stamp = maxf(0.0, stamp - dt / 2.0)
	match state:
		ENTER:
			drop = 1.0 - Pal.ease_out(clampf(t / ENTER_TIME, 0.0, 1.0))
			pos = HOME + Vector2(0, -300.0 * drop)
			if t >= ENTER_TIME:
				state = RUN
				t = 0.0
				pos = HOME
				drop = 0.0
				game.cam.add_trauma(0.5)
				game.sfx.play("slam", 0.6, 0.0)
				for k in 10:
					game.fx.sparks(Vector2(lerpf(HULL.position.x, HULL.end.x, randf()), 70.0), Vector2.DOWN, 2, Pal.ink(0.8, 1.4), 300.0, 0.3, 1.2)
				stage = BOOT
				stage_t = 0.0
		RUN:
			_run(dt)
			# the deck shudders while a test spins up
			var sh := 0.0
			if stage == ANNOUNCE:
				sh = 3.0 * (1.0 - stage_t / ANNOUNCE_TIME)
			pos = HOME + Vector2(sin(t * 83.0), cos(t * 71.0)) * sh
			var pods := (stage == ANNOUNCE or stage == TEST) and (test == 0 or test == 3)
			pod_open = move_toward(pod_open, 1.0 if pods else 0.0, dt / 0.5)
		DYING:
			_dying(dt)
	_step_missiles(dt)
	if state == RUN or state == ENTER:
		_shove()
	queue_redraw()


# the hull is solid: you are pushed out of it, not hurt by it
func _shove() -> void:
	var r := Rect2(HULL.position + _off(), HULL.size)
	var p: Vector2 = game.player.pos
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	var d := p - q
	var l := d.length()
	if l < Player.R:
		var n := d / l if l > 0.01 else Vector2.DOWN
		game.player.pos = q + n * Player.R
		if game.player.vel.dot(n) < 0.0:
			game.player.vel -= n * game.player.vel.dot(n)


func _run(dt: float) -> void:
	stage_t += dt
	core_open = move_toward(core_open, 1.0 if stage == VENT else 0.0, dt / 0.3)
	var pl: Vector2 = game.player.pos
	match stage:
		BOOT:
			_aim_rail(dt, pl, 1.0)
			if stage_t >= BOOT_TIME:
				_announce()
		ANNOUNCE:
			_aim_rail(dt, pl, 1.0)
			if stage_t >= ANNOUNCE_TIME:
				_begin_test()
		TEST:
			var done := true
			if test == 0 or test == 3:
				done = _step_launcher(dt, pl) and done
			if test == 1:
				done = _step_flames(dt, pl) and done
			if test == 2 or test == 3:
				done = _step_rail(dt, pl) and done
			else:
				_aim_rail(dt, pl, 0.6)
			if done and missiles.is_empty():
				stage = PASS
				stage_t = 0.0
				stamp = 1.0
				tests_run += 1
				game.lasers.force(false)
				# the stamp comes down hard
				game.sfx.play("stamp", 0.8, 0.0)
				game.sfx.play("slam", 0.7, -6.0)
				game.cam.add_trauma(0.25)
				game.cam.punch(0.02)
				game.fx.flash(SCREEN.get_center() + _off(), 80.0, 0.14, Pal.ink(0.3, 1.5))
				game.fx.ring(SCREEN.get_center() + _off() + Vector2(56, 0), 10.0, 90.0, 0.3, Pal.red(0.8, 1.6), 3.0)
				game.add_hitstop(0.05)
		PASS:
			_park_rail(dt)
			if stage_t >= PASS_TIME:
				stage = VENT
				stage_t = 0.0
				game.lasers.force(false)
				game.sfx.play("release", 0.6, -4.0)
				game.fx.ring(core_pos(), CORE_R, 140.0, 0.4, Pal.foe(0.8, 1.6), 2.0)
		VENT:
			_park_rail(dt)
			steam_cd -= dt
			if steam_cd <= 0.0:
				steam_cd = 0.09
				for side: float in [-1.0, 1.0]:
					var at := Vector2(SLOT.get_center().x + side * SLOT.size.x * 0.5, SLOT.end.y - 10.0) + _off()
					game.fx.sparks(at, Vector2(side * 0.4, 1.0).normalized(), 2, Pal.ink(0.4, 1.1), 220.0, 0.6, 0.7)
			puff_cd -= dt
			if puff_cd <= 0.0:
				# steam off the deck, either side of the turret
				puff_cd = 0.2
				for side2: float in [-1.0, 1.0]:
					var pa := Vector2(SLOT.get_center().x + side2 * (SLOT.size.x * 0.5 + 24.0), SLOT.end.y - 6.0) + _off()
					game.fx.flash(pa + Vector2(side2 * randf_range(4, 18), randf_range(0, 14)), randf_range(30.0, 46.0), 0.5, Pal.ink(0.22, 1.2))
					game.fx.sparks(pa, Vector2(side2 * 0.3, 1.0).normalized(), 2, Pal.ink(0.5, 1.2), 180.0, 0.6, 0.8)
			if stage_t >= VENT_TIME[phase]:
				_announce()


func _announce() -> void:
	stage = ANNOUNCE
	stage_t = 0.0
	if phase >= 2 and tests_run % 2 == 1:
		test = 3
	else:
		test = tests_run % 3
	game.lasers.force(true)
	game.sfx.play("tick", 0.8, -4.0)
	game.sfx.play("windup", 0.5, -6.0)
	game.cam.add_trauma(0.1)
	if test == 3:
		game.hud.radio(Txt.t("radio_testbed_4"))


func _begin_test() -> void:
	stage = TEST
	stage_t = 0.0
	match test:
		0:
			mis_left = 7 + 2 * phase
			mis_cd = 0.0
		1:
			flames.clear()
			flame_t = 0.0
			# the left nozzle sweeps from your left to your right; later the right one crosses it
			flames.append([0, deg_to_rad(165.0), deg_to_rad(25.0)])
			if phase >= 1:
				flames.append([1, deg_to_rad(15.0), deg_to_rad(155.0)])
			game.sfx.play("windup", 0.6, -2.0)
		2:
			rail_left = 2 + mini(phase, 1)
			_rail_lock()
		3:
			mis_left = 4
			mis_cd = 0.4
			rail_left = 2
			_rail_lock()


# ---- 测试 01: missiles on marked circles

func _step_launcher(dt: float, pl: Vector2) -> bool:
	if mis_left <= 0:
		return true
	mis_cd -= dt
	if mis_cd <= 0.0:
		mis_cd = 0.42 if test == 0 else 1.0
		mis_left -= 1
		var lead: Vector2 = game.player.vel * 0.45
		var room := Arena.ROOM.grow(-40.0)
		# the full demonstration fires in volleys: one on you, two either side
		var marks: Array = [pl + lead + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 70.0)]
		if test == 3:
			var side := Vector2.from_angle(randf() * TAU)
			marks.append(pl + side * 190.0)
			marks.append(pl - side * 190.0)
		for at0: Vector2 in marks:
			var at := Vector2(clampf(at0.x, room.position.x, room.end.x), clampf(at0.y, HULL.end.y + 80.0, room.end.y))
			var tube := Vector2(lerpf(POD.position.x + 20.0, POD.end.x - 20.0, randf()), POD.get_center().y) + _off()
			missiles.append([tube, at, randf_range(-0.12, 0.0)])
			game.fx.flash(tube, 20.0, 0.1, Pal.red(0.6, 2.2))
		game.sfx.play("shot", 0.55, -8.0)
	return mis_left <= 0


func _step_missiles(dt: float) -> void:
	var i := 0
	while i < missiles.size():
		var m: Array = missiles[i]
		m[2] += dt
		if m[2] >= MIS_FALL:
			var at: Vector2 = m[1]
			game.fx.ring(at, 10.0, MIS_R, 0.35, Pal.red(0.9, 2.6), 3.0)
			game.fx.flash(at, MIS_R * 0.8, 0.14, Pal.red(0.5, 2.2))
			game.fx.sparks(at, Vector2.UP, 10, Pal.red(1.0, 2.6), 420.0, 0.3, PI)
			game.sfx.play("slam", randf_range(1.1, 1.3), -6.0)
			game.cam.add_trauma(0.12)
			var p: Vector2 = game.player.pos
			if p.distance_to(at) < MIS_R + Player.R * 0.4 and game.player.dash_t <= 0.0:
				game.on_player_hit((p - at).normalized() if p.distance_to(at) > 1.0 else Vector2.DOWN, null)
			missiles.remove_at(i)
			continue
		i += 1


# ---- 测试 02: flame fans, cut short by cover

func _step_flames(dt: float, pl: Vector2) -> bool:
	flame_t += dt
	var lead := 0.45
	if flame_t < lead:
		return false
	var k := clampf((flame_t - lead) / FLAME_TIME, 0.0, 1.0)
	if game.player.dash_t <= 0.0:
		for f in flames:
			var a := _flame_angle(f, k)
			var noz: Vector2 = NOZZLES[f[0]] + _off()
			var to := pl - noz
			if absf(wrapf(to.angle() - a, -PI, PI)) < FLAME_HALF and to.length() < _flame_reach(noz, to.angle()):
				game.on_player_hit(Vector2.from_angle(a), null)
				break
	if randf() < 0.6:
		# sparks thrown off the tip
		for f in flames:
			var fa := _flame_angle(f, k)
			var fn: Vector2 = NOZZLES[f[0]] + _off()
			var tip := fn + Vector2.from_angle(fa) * _flame_reach(fn, fa) * randf_range(0.55, 0.95)
			game.fx.sparks(tip, Vector2.from_angle(fa), 1, Pal.red(1.0, 2.4), 220.0, 0.3, 0.9)
	if int(flame_t * 8.0) != int((flame_t - dt) * 8.0):
		game.sfx.play("p_drill", randf_range(0.5, 0.6), -14.0)
	return flame_t >= lead + FLAME_TIME


func _flame_angle(f: Array, k: float) -> float:
	return lerpf(f[1], f[2], Pal.ease_io(k))


# does cover (not the room's walls) stop the flame along this angle?
func _flame_cover(noz: Vector2, a: float) -> bool:
	var h: Dictionary = game.arena.raycast(noz + Vector2.from_angle(a) * 4.0, noz + Vector2.from_angle(a) * FLAME_REACH)
	return not h.is_empty() and int(h.rect) >= 4


func _flame_reach(noz: Vector2, a: float) -> float:
	var h: Dictionary = game.arena.raycast(noz + Vector2.from_angle(a) * 4.0, noz + Vector2.from_angle(a) * FLAME_REACH)
	return FLAME_REACH * h.t if h else FLAME_REACH


# ---- 测试 03: the rail gun

func _rail_lock() -> void:
	rail_mode = 1
	rail_t = 0.0
	game.sfx.play("windup", 1.3, -6.0)


func _aim_rail(dt: float, pl: Vector2, rate: float) -> void:
	rail_ext = move_toward(rail_ext, 1.0, dt * 2.5)
	var want := (pl - (TURRET + _off())).angle()
	rail_a += clampf(wrapf(want - rail_a, -PI, PI), -2.6 * rate * dt, 2.6 * rate * dt)


func _park_rail(dt: float) -> void:
	rail_ext = move_toward(rail_ext, 0.3, dt * 2.5)
	rail_a += clampf(wrapf(-PI / 2.0 - rail_a, -PI, PI), -3.0 * dt, 3.0 * dt)


func _step_rail(dt: float, pl: Vector2) -> bool:
	rail_t += dt
	match rail_mode:
		1:
			_aim_rail(dt, pl, 1.0 if phase < 2 else 1.3)
			if rail_t >= RAIL_LOCK:
				rail_mode = 2
				rail_t = 0.0
				game.sfx.play("lit", 0.6, -4.0)
		2:
			if rail_t >= RAIL_HOLD:
				_fire_rail()
				rail_mode = 3
				rail_t = 0.0
		3:
			if rail_t >= RAIL_GAP:
				if rail_left > 0:
					_rail_lock()
				else:
					rail_mode = 0
		_:
			return true
	return false


func _rail_muzzle() -> Vector2:
	return TURRET + _off() + Vector2.from_angle(rail_a) * BARREL * rail_ext


func _rail_line_end() -> Vector2:
	var m := _rail_muzzle()
	var h: Dictionary = game.arena.raycast(m, m + Vector2.from_angle(rail_a) * 2400.0)
	return h.point if h else m + Vector2.from_angle(rail_a) * 2400.0


func _fire_rail() -> void:
	rail_left -= 1
	var m := _rail_muzzle()
	rail_end = _rail_line_end()
	rail_shot = 1.0
	game.sfx.play("cross", 0.5, 0.0)
	game.cam.add_trauma(0.35)
	game.cam.punch(0.03)
	game.fx.flash(m, 40.0, 0.12, Pal.red(0.8, 3.0))
	game.fx.sparks(rail_end, -Vector2.from_angle(rail_a), 12, Pal.red(1.0, 3.0), 520.0, 0.3, 1.0)
	var p: Vector2 = game.player.pos
	var q := Geometry2D.get_closest_point_to_segment(p, m, rail_end)
	if q.distance_to(p) < RAIL_W + Player.R * 0.5 and game.player.dash_t <= 0.0:
		game.on_player_hit(Vector2.from_angle(rail_a), null)


func _dying(dt: float) -> void:
	dying_t += dt
	core_open = move_toward(core_open, 1.0, dt / 0.3)
	pos = HOME + Vector2(sin(dying_t * 70.0), cos(dying_t * 63.0)) * 3.0 * dying_t
	if dying_t > 0.2 and int(dying_t * 10.0) != int((dying_t - dt) * 10.0):
		var at := Vector2(lerpf(HULL.position.x, HULL.end.x, randf()), lerpf(HULL.position.y, HULL.end.y, randf()))
		game.fx.sparks(at, Vector2.from_angle(randf() * TAU), 6, Pal.foe(1.0, 1.8), 420.0, 0.3, 1.0)
		game.fx.flash(at, 30.0, 0.12, Pal.red(0.5, 2.4))
		game.sfx.play("cross", randf_range(0.7, 1.3), -6.0)
	if dying_t >= 1.6:
		state = DEAD
		for k in 40:
			var p0 := Vector2(lerpf(HULL.position.x, HULL.end.x, randf()), lerpf(HULL.position.y, HULL.end.y, randf()))
			game.fx.shard(p0, Vector2(-10, -4), Vector2(10, 4), (p0 - HOME).normalized() * randf_range(300, 700), randf_range(-12, 12), 1.4, Pal.foe(1.0, 1.7), 2.0)
		game.on_boss_dead(core_pos())
		queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if state == OFF or state == DEAD:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	var o := _off()
	if test == 3 and (stage == ANNOUNCE or stage == TEST) and state == RUN:
		_draw_alarm(dim)
	_draw_dangers(dim)
	# gantry arms up to the wall it hangs from
	for x: float in [HOME.x - 150.0, HOME.x + 150.0]:
		draw_rect(Rect2(x - 14.0, 70.0, 28.0, HULL.position.y + o.y - 70.0 + 4.0), Pal.WALL)
		draw_rect(Rect2(x - 14.0, 70.0, 28.0, HULL.position.y + o.y - 70.0 + 4.0), Pal.ink(0.4 * dim), false, 1.5)
		var hatch := PackedVector2Array()
		var y := 76.0
		while y < HULL.position.y + o.y:
			hatch.append(Vector2(x - 14.0, y))
			hatch.append(Vector2(x + 14.0, y + 14.0))
			y += 16.0
		if hatch.size() > 0:
			draw_multiline(hatch, Pal.ink(0.18 * dim), 1.0)
	var hull := Rect2(HULL.position + o, HULL.size)
	var col := Pal.foe(dim, 1.0 + 0.8 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	if test == 3 and (stage == ANNOUNCE or stage == TEST) and state == RUN and fmod(t * 4.0, 1.0) < 0.5:
		# the full demonstration: the hull's edge strobes red
		col = Pal.red(dim, 2.2)
	# the hull: chamfered plate, darker than the floor
	var ch := 18.0
	var hp_pts := PackedVector2Array([hull.position + Vector2(ch, 0), Vector2(hull.end.x - ch, hull.position.y), Vector2(hull.end.x, hull.position.y + ch),
		Vector2(hull.end.x, hull.end.y - ch), Vector2(hull.end.x - ch, hull.end.y), Vector2(hull.position.x + ch, hull.end.y),
		Vector2(hull.position.x, hull.end.y - ch), Vector2(hull.position.x, hull.position.y + ch)])
	draw_colored_polygon(hp_pts, Color(0.045, 0.045, 0.05))
	hp_pts.append(hp_pts[0])
	draw_polyline(hp_pts, col, 2.5)
	draw_rect(hull.grow(-9.0), Pal.foe(0.16 * dim), false, 1.0)
	# stencil on the deck
	draw_string(Fonts.get_font("SemiBold"), Vector2(hull.position.x + 22.0, hull.end.y - 16.0), "TB-03", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.foe(0.45 * dim))
	_draw_screen(o, dim)
	_draw_pod(o, dim)
	_draw_slot(o, dim, col)
	for k in 2:
		_draw_nozzle(k, o, dim)
	_draw_turret(o, dim, col)
	_draw_stamp(o, dim)


# The full demonstration: the whole range's edge pulses red in time with
# the hull, and warning chevrons run along the top and bottom walls.
func _draw_alarm(dim: float) -> void:
	var ph := fmod(t * 4.0, 1.0)
	if ph >= 0.5:
		return
	var k := sin(ph * 2.0 * PI) * dim
	var r := Arena.ROOM
	for j in 2:
		var w := 4.0 + j * 8.0
		var a := (0.12 - j * 0.05) * k
		draw_rect(Rect2(r.position, Vector2(r.size.x, w)), Pal.red(a, 1.4))
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), Pal.red(a, 1.4))
		draw_rect(Rect2(r.position, Vector2(w, r.size.y)), Pal.red(a, 1.4))
		draw_rect(Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y)), Pal.red(a, 1.4))
	var ch := PackedVector2Array()
	var x := r.position.x + fmod(t * 120.0, 60.0)
	while x < r.end.x - 20.0:
		for y: float in [r.end.y - 14.0]:
			ch.append(Vector2(x, y))
			ch.append(Vector2(x + 12.0, y - 8.0))
			ch.append(Vector2(x + 12.0, y - 8.0))
			ch.append(Vector2(x + 24.0, y))
		x += 60.0
	draw_multiline(ch, Pal.red(0.45 * k, 1.4), 2.0)


func _draw_screen(o: Vector2, dim: float) -> void:
	var r := Rect2(SCREEN.position + o, SCREEN.size)
	draw_rect(r, Color(0.02, 0.025, 0.03))
	draw_rect(r, Pal.foe(0.55 * dim), false, 1.5)
	var font := Fonts.get_font("SemiBold")
	var head := ""
	var sub := ""
	var sub_col := Pal.foe(0.6 * dim, 1.2)
	match stage:
		BOOT:
			head = Txt.t("tb_boot")
			sub = "▮".repeat(1 + int(stage_t * 8.0) % 6)
		ANNOUNCE, TEST:
			head = Txt.t("tb_test_%d" % (test + 1))
			if stage == ANNOUNCE and fmod(stage_t * 6.0, 1.0) < 0.5:
				head = ""
			sub = Txt.t("tb_running" if test != 3 else "tb_running_4")
			sub_col = Pal.red(0.8 * dim, 1.8)
		PASS:
			head = Txt.t("tb_test_%d" % (test + 1))
			# the stamp says it; the screen only files it away
			sub = Txt.t("tb_pass") if stamp > 0.97 else Txt.t("tb_filed")
		VENT:
			head = Txt.t("tb_vent")
			sub = ""
	if state == DYING:
		head = Txt.t("tb_fail")
		sub = ""
		sub_col = Pal.red(dim, 2.4)
	if head != "":
		var size := 19
		var w := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if w > r.size.x - 20.0:
			size = int(floor(size * (r.size.x - 20.0) / w))
		draw_string(font, r.position + Vector2(10, 27), head, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Pal.foe(0.95 * dim, 1.6))
	if sub != "":
		draw_string(font, r.position + Vector2(10, 52), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, sub_col)
	if stage == VENT and state == RUN:
		# the cooling count, big, beside its label
		var cnt := "%.1f" % maxf(0.0, VENT_TIME[phase] - stage_t)
		draw_string(font, r.position + Vector2(10, 59), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.foe(0.95 * dim, 1.8))
	# scan lines, in one batch
	var sl := PackedVector2Array()
	var y := r.position.y + 3.0
	while y < r.end.y:
		sl.append(Vector2(r.position.x + 1.0, y))
		sl.append(Vector2(r.end.x - 1.0, y))
		y += 4.0
	draw_multiline(sl, Color(0, 0, 0, 0.25), 1.0)


# The 合格 stamp, over everything on the deck, at the screen's corner.
func _draw_stamp(o: Vector2, dim: float) -> void:
	var r := Rect2(SCREEN.position + o, SCREEN.size)
	var font := Fonts.get_font("SemiBold")
	if stamp > 0.0 and state != DYING:
		var sa := minf(1.0, stamp * 2.0)
		var sc := r.position + Vector2(r.size.x - 22.0, r.size.y + 4.0)
		draw_set_transform(sc, -0.2, Vector2.ONE * (1.0 + 0.4 * maxf(0.0, stamp - 0.85) / 0.15))
		var tw := font.get_string_size(Txt.t("tb_ok"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var box := Rect2(-tw / 2.0 - 8.0, -17.0, tw + 16.0, 30.0)
		draw_rect(box, Color(0.08, 0.0, 0.0, 0.85 * sa))
		draw_rect(box, Pal.red(sa * dim, 1.3), false, 3.0)
		draw_rect(box.grow(-4.0), Pal.red(0.5 * sa * dim, 1.1), false, 1.0)
		draw_string(font, Vector2(-tw / 2.0, 6.0), Txt.t("tb_ok"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.red(sa * dim, 1.4))
		# ink thrown off the edge where it struck
		for j in 7:
			var ip := Vector2(cos(j * 2.4) * (box.size.x * 0.5 + 6.0 + (j % 3) * 4.0), sin(j * 2.4) * (box.size.y * 0.5 + 4.0))
			draw_circle(ip, 1.5 + (j % 2), Pal.red(0.8 * sa * dim, 1.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pod(o: Vector2, dim: float) -> void:
	var r := Rect2(POD.position + o, POD.size)
	draw_rect(r, Color(0.03, 0.03, 0.035))
	draw_rect(r, Pal.ink(0.45 * dim), false, 1.5)
	var live := stage == TEST and (test == 0 or test == 3)
	# the tubes' rims, all in one batch
	var rims := PackedVector2Array()
	for row in 2:
		for c in 6:
			var p := r.position + Vector2(20.0 + c * 32.8, 18.0 + row * 28.0)
			for j in 10:
				rims.append(p + Vector2.from_angle(TAU * j / 10.0) * 10.0)
				rims.append(p + Vector2.from_angle(TAU * (j + 1) / 10.0) * 10.0)
			if live and (c + row * 6 + int(stage_t * 10.0)) % 5 == 0:
				draw_circle(p, 4.0, Pal.red(0.9 * dim, 2.6))
	draw_multiline(rims, Pal.ink(0.4 * dim), 1.2)
	# the lid slides back for a missile test
	var lw := r.size.x * (1.0 - Pal.ease_io(pod_open))
	if lw > 1.0:
		var lid := Rect2(r.end.x - lw, r.position.y, lw, r.size.y)
		draw_rect(lid, Color(0.06, 0.06, 0.07))
		draw_rect(lid, Pal.ink(0.5 * dim), false, 1.5)
		var st := PackedVector2Array()
		var x := lid.position.x + 10.0
		while x < lid.end.x - 14.0:
			st.append(Vector2(x, lid.end.y - 8.0))
			st.append(Vector2(x + 10.0, lid.position.y + 8.0))
			x += 18.0
		if st.size() > 0:
			draw_multiline(st, Pal.ink(0.18 * dim), 2.0)


func _draw_slot(o: Vector2, dim: float, col: Color) -> void:
	var r := Rect2(SLOT.position + o, SLOT.size)
	var c := core_pos()
	draw_rect(r, Color(0.0, 0.0, 0.0))
	# the core: a ring of light that beats faster while it is exposed
	var beat := 0.5 + 0.5 * sin(t * (4.0 + 6.0 * core_open))
	draw_circle(c, CORE_R, Color(0.03, 0.04, 0.05))
	draw_arc(c, CORE_R, 0.0, TAU, 32, col, 3.0)
	draw_circle(c, CORE_R * 0.45, Pal.foe((0.5 + 0.4 * beat) * dim, 1.3 + 0.5 * core_open))
	for k in 6:
		var a := t * 0.8 + TAU * k / 6.0
		draw_line(c + Vector2.from_angle(a) * CORE_R * 0.55, c + Vector2.from_angle(a) * CORE_R * 0.85, Pal.foe(0.4 * dim), 1.5)
	# the doors slide apart into the hull
	var open := Pal.ease_io(core_open)
	var half := r.size.x * 0.5
	for side: int in [0, 1]:
		var w := half * (1.0 - open)
		if w < 1.0:
			continue
		var dr := Rect2(r.position.x if side == 0 else r.end.x - w, r.position.y, w, r.size.y)
		draw_rect(dr, Color(0.06, 0.06, 0.07))
		draw_rect(dr, Pal.ink(0.5 * dim), false, 1.5)
		# hazard stripes across the closed doors
		var x := dr.position.x + 6.0
		while x < dr.end.x - 6.0:
			draw_line(Vector2(x, dr.end.y - 8.0), Vector2(x + 10.0, dr.end.y - 22.0), Pal.ink(0.4 * dim, 1.1), 3.0)
			x += 16.0
	if stage == VENT and state == RUN:
		# the window: a ring that beats round the core, chevrons rising into
		# the slot, and a bar under it running down with the screen's count
		var left := clampf(1.0 - stage_t / VENT_TIME[phase], 0.0, 1.0)
		var pr := fmod(t * 1.6, 1.0)
		draw_arc(c, CORE_HIT + 6.0 + 14.0 * pr, 0.0, TAU, 40, Pal.foe(0.6 * (1.0 - pr) * dim, 1.8), 2.0)
		var chev := PackedVector2Array()
		for j in 3:
			var y := r.end.y + 70.0 - fmod(t * 60.0 + j * 22.0, 66.0)
			chev.append(Vector2(c.x - 16.0, y + 10.0))
			chev.append(Vector2(c.x, y))
			chev.append(Vector2(c.x, y))
			chev.append(Vector2(c.x + 16.0, y + 10.0))
		draw_multiline(chev, Pal.foe(0.7 * dim, 1.6), 3.0)
		draw_line(Vector2(r.position.x, r.end.y + 16.0), Vector2(r.position.x + r.size.x * left, r.end.y + 16.0), Pal.foe(0.9 * dim, 1.8), 4.0)
	# a bracket under the slot so you can find it from across the room
	var lit := 0.25 + 0.7 * core_open
	draw_line(Vector2(r.position.x - 6.0, r.end.y + 8.0), Vector2(r.end.x + 6.0, r.end.y + 8.0), Pal.foe(lit * dim, 1.0 + core_open), 2.0)
	draw_line(Vector2(r.position.x - 6.0, r.end.y + 8.0), Vector2(r.position.x - 6.0, r.end.y - 4.0), Pal.foe(lit * dim), 2.0)
	draw_line(Vector2(r.end.x + 6.0, r.end.y + 8.0), Vector2(r.end.x + 6.0, r.end.y - 4.0), Pal.foe(lit * dim), 2.0)


func _draw_nozzle(k: int, o: Vector2, dim: float) -> void:
	var p: Vector2 = NOZZLES[k] + o
	var live := stage == TEST and test == 1 and flames.any(func(f): return f[0] == k)
	var pts := PackedVector2Array([p + Vector2(-20, -16), p + Vector2(20, -16), p + Vector2(12, 8), p + Vector2(-12, 8)])
	draw_colored_polygon(pts, Pal.WALL)
	pts.append(pts[0])
	draw_polyline(pts, Pal.ink(0.55 * dim), 1.5)
	draw_circle(p + Vector2(0, 4), 5.0, Pal.red((0.9 if live else 0.25) * dim, 2.4 if live else 1.0))


func _draw_turret(o: Vector2, dim: float, col: Color) -> void:
	var c := TURRET + o
	var d := Vector2.from_angle(rail_a)
	var n := d.orthogonal()
	draw_circle(c, 40.0, Color(0.05, 0.05, 0.06))
	draw_arc(c, 40.0, 0.0, TAU, 32, col, 2.0)
	draw_arc(c, 30.0, 0.0, TAU, 28, Pal.foe(0.25 * dim), 1.0)
	# twin rails with the slug channel between them
	var m := c + d * BARREL * rail_ext
	for s: float in [-1.0, 1.0]:
		var a := c + d * 18.0 + n * 9.0 * s
		var b := m + n * 9.0 * s
		draw_line(a, b, Pal.WALL, 9.0)
		draw_line(a, b, Pal.ink(0.75 * dim), 2.0)
	var charge := 0.0
	if rail_mode == 1:
		charge = rail_t / RAIL_LOCK
	elif rail_mode == 2:
		charge = 1.0
	if charge > 0.0:
		var e := c + d * lerpf(18.0, BARREL * rail_ext, charge)
		draw_line(c + d * 18.0, e, Pal.red(0.9 * dim, 1.6 + 2.0 * charge), 3.0)
	draw_circle(m, 6.0, Pal.red((0.3 + 0.7 * charge) * dim, 1.0 + 2.0 * charge))


# the warning marks and live attacks, under the hull. Each kind of attack has
# its own shape: missile marks are dashed rings that fill as the round falls,
# the flame is a ragged fan with a white-hot heart, the rail gun's aim is a
# thin white line that only turns to fire when it shoots.
func _draw_dangers(dim: float) -> void:
	for m in missiles:
		var at: Vector2 = m[1]
		var k: float = m[2] / MIS_FALL
		# the fill is the timer: it reaches the rim as the round lands
		# (linear-light blending: a little alpha already reads as a fair grey)
		draw_circle(at, MIS_R * maxf(k, 0.0), Pal.ink(0.003 + 0.007 * k))
		var dash := PackedVector2Array()
		for j in 16:
			var a0 := TAU * j / 16.0 + t * 0.9
			for q in 3:
				dash.append(at + Vector2.from_angle(a0 + 0.12 * q) * MIS_R)
				dash.append(at + Vector2.from_angle(a0 + 0.12 * (q + 1)) * MIS_R)
		draw_multiline(dash, Pal.red((0.6 + 0.4 * k) * dim, 2.2), 2.5)
		var cr := 12.0
		draw_multiline(PackedVector2Array([at - Vector2(cr, 0), at + Vector2(cr, 0), at - Vector2(0, cr), at + Vector2(0, cr)]), Pal.ink(0.6 * dim), 1.5)
		# the round itself on its arc from the pod: white, with a short trail
		var from: Vector2 = m[0]
		var mid := from.lerp(at, 0.5) + Vector2(0, -260.0)
		var p := _bez(from, mid, at, k)
		var p0 := _bez(from, mid, at, maxf(0.0, k - 0.06))
		draw_line(p0, p, Pal.ink(0.5 * dim, 1.4), 3.0)
		draw_circle(p, 4.0 + 3.0 * (1.0 - absf(k - 0.5) * 2.0), Pal.ink(dim, 2.2))
	if stage == TEST and test == 1:
		var lead := 0.45
		var k2 := clampf((flame_t - lead) / FLAME_TIME, 0.0, 1.0)
		for f in flames:
			var noz: Vector2 = NOZZLES[f[0]] + _off()
			if flame_t < lead:
				# the pilot: where the sweep starts
				var a0: float = f[1]
				var seg := PackedVector2Array()
				var s := 30.0
				while s < 700.0:
					seg.append(noz + Vector2.from_angle(a0) * s)
					seg.append(noz + Vector2.from_angle(a0) * (s + 14.0))
					s += 30.0
				draw_multiline(seg, Pal.red(0.6 * dim, 1.6), 3.0)
				continue
			var a := _flame_angle(f, k2)
			# the fan: thin fill, a sharp edge where it starts to burn, a ragged
			# licking rim; brightest near the nozzle, thinning out with distance
			var pts := PackedVector2Array([noz])
			var cols := PackedColorArray([Pal.red(0.5 * dim, 1.7)])
			var rim := PackedVector2Array()
			var rays := 15
			var reach_mid := 0.0
			for j in rays:
				var u := j / float(rays - 1)
				var aj := a + lerpf(-FLAME_HALF, FLAME_HALF, u)
				var lick := 0.86 + 0.07 * sin(t * 37.0 + j * 2.3) + 0.06 * sin(t * 23.0 + j * 1.1)
				var reach := _flame_reach(noz, aj) * minf(1.0, lick + 0.1 * (1.0 - absf(u - 0.5) * 2.0))
				if j == rays / 2:
					reach_mid = reach
				var tip := noz + Vector2.from_angle(aj) * reach
				pts.append(tip)
				rim.append(tip)
				cols.append(Pal.red(0.07 * dim, 1.2))
			draw_polygon(pts, cols)
			draw_line(noz, rim[0], Pal.red(0.85 * dim, 2.0), 2.0)
			draw_line(noz, rim[rim.size() - 1], Pal.red(0.85 * dim, 2.0), 2.0)
			draw_polyline(rim, Pal.red(0.45 * dim, 1.6), 1.5)
			# its heart: a narrow white-hot tongue
			var core := PackedVector2Array([noz, noz + Vector2.from_angle(a - FLAME_HALF * 0.35) * reach_mid * 0.4,
				noz + Vector2.from_angle(a) * reach_mid * 0.55, noz + Vector2.from_angle(a + FLAME_HALF * 0.35) * reach_mid * 0.4])
			draw_polygon(core, PackedColorArray([Pal.ink(0.75 * dim, 1.7), Pal.red(0.4 * dim, 1.7), Pal.red(0.05 * dim, 1.3), Pal.red(0.4 * dim, 1.7)]))
			# tongues of flame running outward the whole way, thinning to embers
			var near_t := PackedVector2Array()
			var far_t := PackedVector2Array()
			var embers := PackedVector2Array()
			var splash := PackedVector2Array()
			for j in 9:
				var aj2 := a + lerpf(-FLAME_HALF * 0.85, FLAME_HALF * 0.85, j / 8.0)
				var rch := _flame_reach(noz, aj2)
				var s4 := fmod(t * 900.0 + j * 57.0, 120.0) + 30.0
				while s4 < rch - 16.0:
					var p0 := noz + Vector2.from_angle(aj2) * s4
					var p1 := noz + Vector2.from_angle(aj2 + 0.02 * sin(t * 30.0 + s4)) * minf(rch, s4 + 34.0)
					if s4 < rch * 0.55:
						near_t.append(p0)
						near_t.append(p1)
					else:
						far_t.append(p0)
						far_t.append(p1.lerp(p0, 0.4))
						if int(s4 + j * 13.0) % 3 == 0:
							embers.append(p0 + Vector2.from_angle(aj2).orthogonal() * sin(t * 17.0 + s4) * 10.0)
					s4 += 120.0
				if _flame_cover(noz, aj2):
					splash.append(noz + Vector2.from_angle(aj2) * rch)
			if near_t.size() > 0:
				draw_multiline(near_t, Pal.red(0.8 * dim, 2.6), 3.0)
			if far_t.size() > 0:
				draw_multiline(far_t, Pal.red(0.45 * dim, 1.8), 2.0)
			for e in embers:
				draw_circle(e, 2.0, Pal.red(0.9 * dim, 2.4))
			# where cover stops it, the flame flashes along the crate's face
			if splash.size() >= 2:
				var sd := (splash[splash.size() - 1] - splash[0]).normalized()
				var line := PackedVector2Array([splash[0] - sd * 14.0])
				line.append_array(splash)
				line.append(splash[splash.size() - 1] + sd * 14.0)
				draw_polyline(line, Pal.ink(0.18 * dim, 1.4), 7.0)
				draw_polyline(line, Pal.ink(0.75 * dim, 2.0), 2.0)
			elif splash.size() == 1:
				draw_arc(splash[0], 9.0, a + PI - 1.2, a + PI + 1.2, 10, Pal.ink(0.7 * dim, 2.0), 2.0)
	if rail_mode == 1 or rail_mode == 2:
		var m0 := _rail_muzzle()
		var e0 := _rail_line_end()
		if rail_mode == 1:
			# locking: a thin white dashed line that steadies
			var seg2 := PackedVector2Array()
			var s2 := fmod(t * 300.0, 26.0)
			var len := m0.distance_to(e0)
			var dd := (e0 - m0) / maxf(len, 1.0)
			while s2 < len:
				seg2.append(m0 + dd * s2)
				seg2.append(m0 + dd * minf(len, s2 + 12.0))
				s2 += 26.0
			draw_multiline(seg2, Pal.ink((0.3 + 0.5 * rail_t / RAIL_LOCK) * dim, 1.4), 1.5)
		else:
			# held: the line goes solid and the width it will burn shows faintly
			var fl := 0.6 + 0.4 * sin(t * 60.0)
			draw_line(m0, e0, Pal.red(0.14 * dim, 1.2), RAIL_W * 2.0)
			draw_line(m0, e0, Pal.ink(fl * dim, 2.4), 2.0)
	if rail_shot > 0.0:
		var m1 := TURRET + _off() + (rail_end - TURRET - _off()).normalized() * BARREL
		draw_line(m1, rail_end, Pal.red(0.4 * rail_shot * dim, 2.2), RAIL_W * 2.0 * (0.5 + 0.5 * rail_shot))
		draw_line(m1, rail_end, Pal.ink(rail_shot * dim, 3.4), 5.0 * rail_shot + 1.0)


func _bez(a: Vector2, c: Vector2, b: Vector2, k: float) -> Vector2:
	var e := Pal.ease_in(k) if k > 0.5 else k
	return a.lerp(c, e).lerp(c.lerp(b, e), e)
