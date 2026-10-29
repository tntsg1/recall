class_name Archivist
extends Node2D
# 档案修订机 THE ARCHIVIST (chapter 8): the deep archive's index cabinet. It
# keeps history by striking it out. Black redaction bars slam across the
# floor (a red pen line runs their length first) and stand there a while:
# solid to walk into, and a round that meets one — flying out or coming home —
# is struck from the record until the bar lifts, when it is back in the
# magazine. Between strikes it pulls out a drawer to file the change; an open
# drawer is its one soft spot. A drawer a phase: the old era, 13th Street,
# and last R-0's own file, whose page it redacts line by line — and every
# line struck out lays another bar on the floor. When it falls, the bars on
# the page lift.

enum { OFF, ENTER, RUN, DYING, DEAD }
enum { IDLE, MARK, OPEN }

const HP := 1300.0
const HOME := Vector2(960, 290)
const HALF := Vector2(150, 92)
const FACES := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]
const DRAWER_KEYS := ["arc_drawer_0", "arc_drawer_1", "arc_drawer_2"]
const OUT := 110.0
const BAR_W := 36.0
const BAR_WARN := 1.0
const BAR_LIFE := [5.5, 5.0, 4.6]
const BAR_LEN := [900.0, 980.0, 1060.0]
const BARS_N := [2, 3, 3]
const IDLE_TIME := [1.6, 1.3, 1.1]
const OPEN_TIME := [4.6, 4.2, 3.8]
const KEEP := Rect2(680, 180, 560, 330)    # the cabinet and its drawers: no bar crosses it
const PAGE := Rect2(1262, 104, 452, 296)
const FILE_N := 6                          # R-0's page: a heading and five lines
const LINE_EVERY := 3.4
const STAMP_R := 72.0
const STAMP_WARN := 0.8
const STAMP_EVERY := [0.0, 1.8, 1.3]     # while a drawer is open (none in the first phase)

var game
var state := OFF
var t := 0.0
var hp := HP
var phase := 0
var pos := HOME
var core_open := 0.0
var flash := 0.0
var red := 0.0
var guard_t := 0.0
var dying_t := 0.0
var enter_t := 0.0
var mode := IDLE
var mode_t := 0.0
var drawer_k := 0.0
var drawer_want := 0.0
var bars: Array = []          # {r, t, life, held: Array, horiz, from_lo}
var bar_n := 0
var mark_len := 0.0
var stamps: Array = []        # {c, t}: "revised" stamped where you stand
var stamp_cd := 0.0
var file_t := -1.0            # time since R-0's file came out (the last phase)
var struck := 0               # lines of it struck out
var strike_t := 0.0
var strikes: Array = []       # per line: 0..1 how far its bar has run
var stamp_t := -1.0
var dead_t := -1.0            # after it falls: the page's bars lift


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_archivist"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


func begin_track() -> void:
	state = OFF
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	_fresh()
	game.sfx.play("horn", 0.5, -2.0)
	game.cam.add_trauma(0.3)
	game.hud.radio(Txt.t("radio_archive"))


func reset() -> void:
	state = OFF
	t = 0.0
	enter_t = 0.0
	_fresh()
	dead_t = -1.0


func _fresh() -> void:
	hp = HP
	phase = 0
	pos = HOME
	core_open = 0.0
	guard_t = 0.0
	flash = 0.0
	red = 0.0
	mode = IDLE
	mode_t = 0.0
	drawer_k = 0.0
	drawer_want = 0.0
	bars.clear()
	stamps.clear()
	stamp_cd = 0.0
	bar_n = 0
	file_t = -1.0
	struck = 0
	strike_t = 0.0
	strikes = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	stamp_t = -1.0
	if game != null:
		game.arena.soft.clear()


func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	mode = OPEN
	drawer_k = 1.0
	damage(HP, false, pos, Vector2.UP)


func body() -> Rect2:
	return Rect2(pos - HALF, HALF * 2.0)


# The drawer of this phase, as far out as it is.
func drawer(k: float = -1.0) -> Rect2:
	if k < 0.0:
		k = drawer_k
	var f: Vector2 = FACES[phase]
	var out := OUT * k
	if f.x < 0.0:
		return Rect2(pos.x - HALF.x - out, pos.y - 44.0, out, 88.0)
	if f.x > 0.0:
		return Rect2(pos.x + HALF.x, pos.y - 44.0, out, 88.0)
	return Rect2(pos.x - 60.0, pos.y + HALF.y, 120.0, out)


func core_pos() -> Vector2:
	return drawer(1.0).get_center()


func core_vel() -> Vector2:
	return Vector2.ZERO


# ---------------------------------------------------------------- bullets

func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	var best := {}
	var bt := 2.0
	if drawer_k > 0.25:
		var hd := _rect_hit(a, b, drawer())
		if not hd.is_empty():
			bt = hd.t
			best = {"point": hd.point, "normal": hd.normal, "core": core_open > 0.5, "mult": 1.0, "frame": -1, "car": 0}
	var hb := _rect_hit(a, b, body())
	if not hb.is_empty() and hb.t < bt:
		best = {"point": hb.point, "normal": hb.normal, "core": false, "car": 0}
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


# The nearest standing bar the segment meets: {point, bar} or {}.
func cut(a: Vector2, b: Vector2) -> Dictionary:
	if state == OFF or state == DEAD or bars.is_empty():
		return {}
	var best := {}
	var bt := 2.0
	for i in bars.size():
		var br: Dictionary = bars[i]
		if br.t < BAR_WARN:
			continue
		var h := _rect_hit(a, b, br.r)
		if not h.is_empty() and h.t < bt:
			bt = h.t
			best = {"point": h.point, "bar": i}
	return best


# A round struck from the record: it waits in the bar until the bar lifts.
func take(b, at: Vector2, i: int) -> void:
	if i < 0 or i >= bars.size():
		return
	(bars[i].held as Array).append([b, at])
	game.fx.flash(at, 18.0, 0.12, Pal.ink(0.35, 1.2))
	game.fx.sparks(at, -b.dir, 4, Color(0.0, 0.0, 0.0, 1.0), 220.0, 0.2, 0.9)
	game.sfx.play("expire", randf_range(0.6, 0.7), -9.0)


func on_armor(_k: int, at_p: Vector2, normal: Vector2) -> void:
	game.fx.sparks(at_p, normal, 6, Pal.foe(1.0, 2.0), 460.0, 0.2, 0.9)
	game.fx.flash(at_p, 18.0, 0.1, Pal.foe(0.5, 1.6))
	game.sfx.play("shield", randf_range(0.9, 1.1), -8.0)


func damage(dmg: float, ret: bool, at_p: Vector2, d: Vector2, _frame_k: int = -1) -> void:
	if state != RUN or core_open < 0.5:
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
	# index cards fly out of the drawer
	if ret:
		for j in 2:
			game.fx.shard(at_p, Vector2(-6, -4), Vector2(6, 4), Vector2.from_angle(randf() * TAU) * randf_range(200, 420), randf_range(-8, 8), 0.6, Pal.ink(0.8, 1.2), 1.5)
	game.on_target_hit(ret)
	var want := clampi(int((1.0 - hp / HP) * 3.0), 0, 2)
	while phase < want:
		phase += 1
		_phase_break()
	if hp <= 0.0:
		state = DYING
		dying_t = 0.0
		mode = IDLE
		drawer_want = 0.0
		game.on_boss_dying()


func _phase_break() -> void:
	guard_t = 1.4
	game.fx.ring(pos, HALF.y, 360.0, 0.6, Pal.foe(0.9, 1.5), 3.0)
	game.sfx.play("armor", 0.8, 0.0)
	game.add_hitstop(0.09)
	game.cam.add_trauma(0.6)
	game.cam.punch(0.04)
	game.hud.boss_phase()
	# the drawer slams shut; the next one is another face's
	drawer_k = 0.0
	drawer_want = 0.0
	mode = IDLE
	mode_t = 0.0
	if phase == 2:
		file_t = 0.0
		strike_t = 0.0
		game.hud.radio(Txt.t("radio_archive_r0"))


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	if dead_t >= 0.0:
		dead_t += dt
		queue_redraw()
	if state == OFF or state == DEAD:
		return
	t += dt
	flash = maxf(0.0, flash - dt / 0.12)
	red = maxf(0.0, red - dt / 0.8)
	guard_t = maxf(0.0, guard_t - dt)
	drawer_k = move_toward(drawer_k, drawer_want, dt / 0.35)
	match state:
		ENTER:
			if t >= 1.2:
				state = RUN
				t = 0.0
				game.cam.add_trauma(0.4)
				game.sfx.play("slam", 0.6, -2.0)
		RUN:
			_run(dt)
		DYING:
			_dying(dt)
	core_open = 1.0 if state == RUN and mode == OPEN and drawer_k > 0.6 else 0.0
	_step_bars(dt)
	_step_stamps(dt)
	_step_file(dt)
	var soft: Array[Rect2] = [body()]
	if drawer_k > 0.05:
		soft.append(drawer())
	for br in bars:
		if br.t >= BAR_WARN:
			soft.append(br.r)
	game.arena.soft = soft
	queue_redraw()


func _run(dt: float) -> void:
	mode_t += dt
	match mode:
		IDLE:
			if mode_t >= IDLE_TIME[phase]:
				mode = MARK
				mode_t = 0.0
				mark_len = _pattern()
				game.sfx.play("windup", 0.6, -4.0)
		MARK:
			if mode_t >= BAR_WARN + mark_len + 0.35:
				mode = OPEN
				mode_t = 0.0
				drawer_want = 1.0
				game.sfx.play("release", 0.7, -4.0)
		OPEN:
			if STAMP_EVERY[phase] > 0.0:
				stamp_cd -= dt
				if stamp_cd <= 0.0 and drawer_k > 0.9:
					stamp_cd = STAMP_EVERY[phase]
					stamps.append({"c": game.player.pos + game.player.vel * 0.25, "t": 0.0})
					game.sfx.play("windup", 1.3, -8.0)
			if mode_t >= OPEN_TIME[phase]:
				mode = IDLE
				mode_t = 0.0
				drawer_want = 0.0
				game.sfx.play("slam", 0.9, -8.0)


# A phase's strike: two bars at first; then a cross through where you are
# heading; last, a whole paragraph struck out — four lines with narrow gaps.
# Returns the delay of its last bar.
func _pattern() -> float:
	var room := Arena.ROOM
	var p: Vector2 = game.player.pos + game.player.vel * 0.3
	match phase:
		0:
			_mark(0, 0.0)
			_mark(1, -0.3)
			return 0.3
		1:
			_bar(true, p.y, p.x < 960.0, 0.0)
			_bar(false, p.x, p.y < 540.0, 0.0)
			_mark(1, -0.45)
			return 0.45
	var y0 := clampf(p.y + randf_range(-70.0, 70.0) - 180.0, room.position.y + 40.0, room.end.y - 40.0 - 360.0)
	var lo := randf() < 0.5
	for j in 4:
		_bar(true, y0 + j * 120.0, lo, -0.12 * j)
	return 0.36


# A bar marked out across the floor, through or near where you stand.
func _mark(k: int, t0: float) -> void:
	var p: Vector2 = game.player.pos
	var horiz := (bar_n + k) % 2 == 0
	if horiz:
		_bar(true, p.y + (0.0 if k == 0 else randf_range(-230.0, 230.0)), p.x < 960.0 if k == 0 else randf() < 0.5, t0)
	else:
		_bar(false, p.x + (0.0 if k == 0 else randf_range(-260.0, 260.0)), p.y < 540.0 if k == 0 else randf() < 0.5, t0)


# One bar: across at "at" (a y when horizontal, an x when not), run in from
# the low wall or the high one; never through the cabinet.
func _bar(horiz: bool, at: float, from_lo: bool, t0: float) -> void:
	var room := Arena.ROOM
	var r: Rect2
	if horiz:
		var y := clampf(at, room.position.y + 40.0, room.end.y - 40.0)
		var len: float = BAR_LEN[phase]
		r = Rect2(room.position.x if from_lo else room.end.x - len, y - BAR_W * 0.5, len, BAR_W)
		if r.intersects(KEEP):
			if from_lo:
				r.size.x = KEEP.position.x - 12.0 - r.position.x
			else:
				var nx := KEEP.end.x + 12.0
				r.size.x = r.end.x - nx
				r.position.x = nx
	else:
		var x := clampf(at, room.position.x + 40.0, room.end.x - 40.0)
		var span := room.size.y * 0.7
		r = Rect2(x - BAR_W * 0.5, room.position.y if from_lo else room.end.y - span, BAR_W, span)
		if r.intersects(KEEP):
			# never down through the cabinet: from the floor's far wall instead
			from_lo = false
			var ny := KEEP.end.y + 12.0
			r = Rect2(r.position.x, ny, BAR_W, room.end.y - ny)
	if r.size.x < 120.0 and r.size.y < 120.0:
		return
	bars.append({"r": r, "t": t0, "life": BAR_LIFE[phase], "held": [], "horiz": horiz, "from_lo": from_lo})
	bar_n += 1


func _step_bars(dt: float) -> void:
	var i := 0
	while i < bars.size():
		var br: Dictionary = bars[i]
		var was: float = br.t
		br.t += dt
		if was < BAR_WARN and br.t >= BAR_WARN:
			_land(br, i)
		if br.t >= BAR_WARN + br.life or (state != RUN and state != ENTER and br.t >= BAR_WARN):
			_lift(br)
			bars.remove_at(i)
			continue
		if state != RUN and state != ENTER and br.t < BAR_WARN:
			bars.remove_at(i)
			continue
		i += 1


func _land(br: Dictionary, i: int) -> void:
	var r: Rect2 = br.r
	game.sfx.play("slam", randf_range(0.75, 0.85), -4.0)
	game.cam.add_trauma(0.22)
	var c := r.get_center()
	var long_x: bool = br.horiz
	for j in 8:
		var q := r.position + Vector2(randf() * r.size.x, randf() * r.size.y)
		var out := Vector2(0, 1 if q.y > c.y else -1) if long_x else Vector2(1 if q.x > c.x else -1, 0)
		game.fx.sparks(q, out, 2, Pal.ink(0.7, 1.3), 260.0, 0.18, 0.6)
	var p: Vector2 = game.player.pos
	if r.grow(Player.R).has_point(p) and game.player.dash_t <= 0.0:
		var n := Vector2(0, 1 if p.y > c.y else -1) if long_x else Vector2(1 if p.x > c.x else -1, 0)
		game.on_player_hit(n, null)
	# rounds lying under it are struck out with it
	for b in game.bullets.list:
		if b.state == Bullets.EMBED and not b.foe and r.grow(6.0).has_point(b.pos):
			b.state = Bullets.FADE
			b.t = 0.0
			b.settled = false
			take(b, b.pos, i)
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE and r.grow(e.r).has_point(e.pos):
			game.enemies.blast_hit(e, Vector2(0, 1 if e.pos.y > c.y else -1) if long_x else Vector2(1 if e.pos.x > c.x else -1, 0), 25.0)


# A stamp comes down: whatever stands under it is revised.
func _step_stamps(dt: float) -> void:
	var i := 0
	while i < stamps.size():
		var st: Dictionary = stamps[i]
		var was: float = st.t
		st.t += dt
		if was < STAMP_WARN and st.t >= STAMP_WARN:
			if state != RUN:
				stamps.remove_at(i)
				continue
			game.sfx.play("slam", 1.2, -5.0)
			game.cam.add_trauma(0.18)
			var p: Vector2 = game.player.pos
			if p.distance_to(st.c) < STAMP_R + Player.R * 0.5 and game.player.dash_t <= 0.0:
				game.on_player_hit((p - st.c).normalized() if p.distance_to(st.c) > 1.0 else Vector2.DOWN, null)
			for e in game.enemies.list:
				if e.state == Enemies.ALIVE and e.pos.distance_to(st.c) < STAMP_R + e.r:
					game.enemies.blast_hit(e, (e.pos - st.c).normalized(), 25.0)
		if st.t >= STAMP_WARN + 0.7:
			stamps.remove_at(i)
		else:
			i += 1


# The bar lifts: what it held comes back.
func _lift(br: Dictionary) -> void:
	var n := 0
	for h in br.held:
		var b = h[0]
		game.fx.flash(h[1], 22.0, 0.15, Pal.ink(0.6, 1.8))
		if not b.child:
			game.on_ammo_home(b)
			n += 1
	if n > 0:
		game.sfx.play("lit", 1.1, -8.0)


# R-0's file: its lines come up one after another, then one by one they are
# struck out, and each struck line lays a bar on the floor.
func _step_file(dt: float) -> void:
	if file_t < 0.0:
		return
	file_t += dt
	for j in FILE_N:
		if j >= 1 and j <= struck:
			strikes[j] = minf(1.0, strikes[j] + dt / 0.45)
	if stamp_t >= 0.0:
		stamp_t += dt
	if state != RUN or file_t < 2.4:
		return
	strike_t += dt
	if struck < FILE_N - 1 and strike_t >= LINE_EVERY:
		strike_t = 0.0
		struck += 1
		game.sfx.play("tick", 0.5, -4.0)
		_mark(0, 0.0)
		if struck == FILE_N - 1:
			stamp_t = 0.0
			game.sfx.play("slam", 1.1, -6.0)


func _dying(dt: float) -> void:
	dying_t += dt
	pos = HOME + Vector2(sin(dying_t * 70.0), cos(dying_t * 63.0)) * 3.0 * dying_t
	if dying_t > 0.2 and int(dying_t * 10.0) != int((dying_t - dt) * 10.0):
		var at := pos + Vector2(randf_range(-HALF.x, HALF.x), randf_range(-HALF.y, HALF.y))
		game.fx.sparks(at, Vector2.from_angle(randf() * TAU), 6, Pal.foe(1.0, 1.8), 420.0, 0.3, 1.0)
		game.fx.shard(at, Vector2(-6, -4), Vector2(6, 4), Vector2.from_angle(randf() * TAU) * randf_range(200, 500), randf_range(-8, 8), 0.9, Pal.ink(0.8, 1.2), 1.5)
		game.sfx.play("cross", randf_range(0.7, 1.3), -6.0)
	if dying_t >= 1.5:
		state = DEAD
		game.arena.soft.clear()
		for k in 40:
			var p0 := pos + Vector2(randf_range(-HALF.x, HALF.x), randf_range(-HALF.y, HALF.y))
			game.fx.shard(p0, Vector2(-8, -5), Vector2(8, 5), (p0 - HOME).normalized() * randf_range(300, 700), randf_range(-12, 12), 1.4, Pal.ink(0.9, 1.4) if k % 3 else Pal.foe(1.0, 1.7), 2.0)
		if file_t >= 0.0:
			dead_t = 0.0
		game.on_boss_dead(pos)
		queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if dead_t >= 0.0 and dead_t < 11.0:
		_draw_page(dim * (1.0 - clampf((dead_t - 10.0) / 1.0, 0.0, 1.0)))
	if state == OFF or state == DEAD:
		return
	var appear := Pal.ease_out(clampf(t / 1.2, 0.0, 1.0)) if state == ENTER else 1.0
	for br in bars:
		_draw_bar(br, dim)
	for st in stamps:
		_draw_stamp(st, dim)
	_draw_cabinet(dim, appear)
	if file_t >= 0.0:
		_draw_page(dim)


# The cabinet from above: a card catalogue, rows of little drawers with label
# slots and pulls, some taped over in red; the big drawer of this phase on
# its face, labelled.
func _draw_cabinet(dim: float, appear: float) -> void:
	var r := body()
	r = Rect2(r.get_center() - r.size * 0.5 * appear, r.size * appear)
	var col := Pal.foe(dim, 1.0 + 0.8 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	draw_rect(r.grow(8.0), Color(0, 0, 0, 0.5 * appear))
	draw_rect(r, Color(0.045, 0.045, 0.05, appear))
	draw_rect(r, col, false, 2.5)
	var cols := 7
	var rows := 4
	var cw := (r.size.x - 24.0) / cols
	var ch := (r.size.y - 24.0) / rows
	for i in cols:
		for j in rows:
			var d := Rect2(r.position + Vector2(12.0 + i * cw + 3.0, 12.0 + j * ch + 3.0), Vector2(cw - 6.0, ch - 6.0))
			draw_rect(d, Pal.foe(0.3 * dim), false, 1.0)
			draw_rect(Rect2(d.position + Vector2(d.size.x * 0.25, 5.0), Vector2(d.size.x * 0.5, 6.0)), Pal.ink(0.18 * dim), false, 1.0)
			draw_circle(d.get_center() + Vector2(0, 6.0), 2.0, Pal.foe(0.45 * dim))
			if (i * 3 + j * 5) % 7 == 2:
				# taped shut in red: revised
				draw_line(d.position + Vector2(2, d.size.y - 4.0), d.end - Vector2(2, d.size.y - 4.0), Pal.red(0.55 * dim, 1.3), 3.0)
	_draw_drawer(dim * appear)


func _draw_drawer(dim: float) -> void:
	var f: Vector2 = FACES[phase]
	var b := body()
	var font := Fonts.get_font("SemiBold")
	# the face it comes out of: a heavy front with a lit pull
	var front: Rect2
	if f.x < 0.0:
		front = Rect2(b.position.x - 6.0, pos.y - 48.0, 6.0, 96.0)
	elif f.x > 0.0:
		front = Rect2(b.end.x, pos.y - 48.0, 6.0, 96.0)
	else:
		front = Rect2(pos.x - 64.0, b.end.y, 128.0, 6.0)
	var open := core_open > 0.5
	var dr := drawer()
	if drawer_k > 0.01:
		draw_rect(dr, Color(0.03, 0.03, 0.035))
		draw_rect(dr, Pal.foe(0.8 * dim, 1.4), false, 2.0)
		# the index cards standing in it
		var cards := PackedVector2Array()
		var n := 9
		for j in n:
			var u := (j + 0.5) / n
			if f.y == 0.0:
				var x := dr.position.x + dr.size.x * u
				cards.append(Vector2(x, dr.position.y + 8.0))
				cards.append(Vector2(x, dr.end.y - 8.0))
			else:
				var y := dr.position.y + dr.size.y * u
				cards.append(Vector2(dr.position.x + 8.0, y))
				cards.append(Vector2(dr.end.x - 8.0, y))
		draw_multiline(cards, Pal.ink(0.3 * dim), 1.0)
		# the original: a lit folder in the middle, the soft spot
		var cc := dr.get_center()
		var fr := Rect2(cc - Vector2(22, 16), Vector2(44, 32))
		var pulse := 0.5 + 0.5 * sin(t * 7.0)
		var cc_col := Pal.foe((0.6 + 0.4 * pulse) * dim, 2.2 + flash).lerp(Pal.red(dim, 2.6), red * 0.8)
		draw_rect(fr, Color(0.02, 0.02, 0.025))
		draw_rect(fr, cc_col, false, 2.5)
		draw_line(fr.position + Vector2(6, 10), Vector2(fr.end.x - 6.0, fr.position.y + 10.0), cc_col, 1.5)
		draw_line(fr.position + Vector2(6, 18), Vector2(fr.end.x - 14.0, fr.position.y + 18.0), cc_col, 1.5)
		if open:
			draw_rect(fr.grow(5.0 + 2.0 * pulse), Pal.red(0.6 * dim, 1.8), false, 1.5)
	draw_rect(front, Pal.foe(0.9 * dim, 1.6), false, 2.0)
	# its label: what this drawer holds, and whether it is open
	var lab := Txt.t(DRAWER_KEYS[phase])
	var sub := Txt.t("arc_open")
	var fs := 16
	var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var at: Vector2
	# beside the face, above where the drawer comes out
	var above := pos.y - 44.0 - 14.0 - (22.0 if open else 0.0)
	if f.x < 0.0:
		at = Vector2(b.position.x - 4.0 - maxf(lw, sw if open else 0.0), above)
	elif f.x > 0.0:
		at = Vector2(b.end.x + 12.0, above)
	else:
		at = Vector2(pos.x + 74.0, b.end.y + 34.0)
	var plate := Rect2(at + Vector2(-8, -18), Vector2(maxf(lw, sw if open else 0.0) + 16.0, 26.0 + (22.0 if open else 0.0)))
	draw_rect(plate, Color(0.03, 0.03, 0.035, 0.9))
	draw_rect(plate, Pal.foe(0.45 * dim), false, 1.0)
	draw_string(font, at, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.foe(0.9 * dim, 1.4) if phase < 2 else Pal.red(0.95 * dim, 1.6))
	if open:
		var blink := 1.0 if fmod(t * 3.0, 1.0) < 0.7 else 0.55
		draw_string(font, at + Vector2(0, 22), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.red(blink * dim, 2.0))


# A bar: first a red pen line runs its length with its outline flickering;
# then the black slams down, "revised" printed along it, and the rounds it
# took marked on it as small grey crosses.
func _draw_bar(br: Dictionary, dim: float) -> void:
	var r: Rect2 = br.r
	var horiz: bool = br.horiz
	var from_lo: bool = br.from_lo
	if br.t < 0.0:
		return
	if br.t < BAR_WARN:
		var k: float = br.t / BAR_WARN
		var fl := 0.55 + 0.45 * sin(t * (16.0 + 20.0 * k))
		draw_rect(r, Pal.red(0.004 * fl * dim, 1.0))
		draw_rect(r, Pal.red((0.25 + 0.4 * k) * fl * dim, 1.2), false, 1.5 + k)
		# the pen runs from the wall end to the far end
		var run := Pal.ease_out(clampf(k * 1.25, 0.0, 1.0))
		var a: Vector2
		var b: Vector2
		if horiz:
			var y := r.get_center().y
			a = Vector2(r.position.x if from_lo else r.end.x, y)
			b = a.lerp(Vector2(r.end.x if from_lo else r.position.x, y), run)
		else:
			var x := r.get_center().x
			a = Vector2(x, r.position.y if from_lo else r.end.y)
			b = a.lerp(Vector2(x, r.end.y if from_lo else r.position.y), run)
		draw_line(a, b, Pal.red(0.85 * dim, 1.4), 3.0)
		draw_circle(b, 5.0, Pal.red(dim, 1.8))
		return
	var age: float = br.t - BAR_WARN
	var left: float = BAR_WARN + br.life - br.t
	var slam := Pal.ease_out(clampf(age / 0.12, 0.0, 1.0))
	var fade := clampf(left / 0.4, 0.0, 1.0)
	var rr := r
	if horiz:
		rr = Rect2(r.position.x, r.get_center().y - r.size.y * 0.5 * slam * fade, r.size.x, r.size.y * slam * fade)
	else:
		rr = Rect2(r.get_center().x - r.size.x * 0.5 * slam * fade, r.position.y, r.size.x * slam * fade, r.size.y)
	draw_rect(rr.grow(4.0), Color(0, 0, 0, 0.45 * fade))
	draw_rect(rr, Color(0.008, 0.008, 0.01, 1.0))
	draw_rect(rr, Pal.ink(0.3 * dim * fade), false, 1.0)
	if age < 0.2:
		draw_rect(rr.grow(6.0 * (1.0 - age / 0.2)), Pal.ink(0.7 * (1.0 - age / 0.2) * dim, 1.6), false, 2.0)
	# "revised", along it
	var font := Fonts.get_font("SemiBold")
	var lab := Txt.t("arc_redacted")
	var fs := 14
	var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var span := r.size.x if horiz else r.size.y
	var s := 60.0
	while s + lw < span - 20.0:
		if horiz:
			draw_string(font, Vector2(r.position.x + s, r.get_center().y + fs * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.32 * dim * fade))
		else:
			draw_set_transform(Vector2(r.get_center().x - fs * 0.36, r.position.y + s), PI * 0.5, Vector2.ONE)
			draw_string(font, Vector2.ZERO, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.32 * dim * fade))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		s += 280.0
	for h in br.held:
		var q: Vector2 = h[1]
		draw_line(q + Vector2(-5, -5), q + Vector2(5, 5), Pal.ink(0.5 * dim * fade), 2.0)
		draw_line(q + Vector2(-5, 5), q + Vector2(5, -5), Pal.ink(0.5 * dim * fade), 2.0)
	# the last of its time, a thin line running out along its edge
	var lk := clampf(left / br.life, 0.0, 1.0)
	if horiz:
		draw_line(Vector2(r.position.x, rr.end.y + 3.0), Vector2(r.position.x + r.size.x * lk, rr.end.y + 3.0), Pal.ink(0.35 * dim * fade), 1.5)
	else:
		draw_line(Vector2(rr.end.x + 3.0, r.position.y), Vector2(rr.end.x + 3.0, r.position.y + r.size.y * lk), Pal.ink(0.35 * dim * fade), 1.5)


# The stamp: a red ring closing on the spot with the word in it, then the
# imprint, fading.
func _draw_stamp(st: Dictionary, dim: float) -> void:
	var c: Vector2 = st.c
	var font := Fonts.get_font("SemiBold")
	var lab := Txt.t("arc_redacted")
	var fs := 22
	var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if st.t < STAMP_WARN:
		var k: float = st.t / STAMP_WARN
		var fl := 0.6 + 0.4 * sin(t * (18.0 + 20.0 * k))
		draw_arc(c, STAMP_R, 0.0, TAU, 48, Pal.red((0.35 + 0.45 * k) * fl * dim, 1.4), 2.0)
		draw_arc(c, STAMP_R + 40.0 * (1.0 - k), 0.0, TAU, 48, Pal.red(0.5 * k * dim, 1.3), 1.5)
		draw_set_transform(c, -0.2, Vector2.ONE)
		draw_string(font, Vector2(-lw * 0.5, fs * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.red(0.35 * k * dim, 1.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var a: float = 1.0 - clampf((st.t - STAMP_WARN) / 0.7, 0.0, 1.0)
	draw_circle(c, STAMP_R, Color(0.0, 0.0, 0.0, 0.35 * a))
	draw_arc(c, STAMP_R, 0.0, TAU, 48, Pal.red(0.9 * a * dim, 1.8), 4.0)
	draw_arc(c, STAMP_R - 9.0, 0.0, TAU, 48, Pal.red(0.6 * a * dim, 1.5), 1.5)
	draw_set_transform(c, -0.2, Vector2.ONE)
	draw_string(font, Vector2(-lw * 0.5, fs * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.red(0.95 * a * dim, 1.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# R-0's original file, on a page by the cabinet: the heading, five lines
# typed in, struck out one by one; the stamp when it is done. After the
# cabinet falls, the bars peel off again, one line after another.
func _draw_page(dim: float) -> void:
	var font := Fonts.get_font("Regular")
	var bold := Fonts.get_font("SemiBold")
	var r := PAGE
	var show := clampf(file_t / 0.4, 0.0, 1.0) if dead_t < 0.0 else 1.0
	if show <= 0.0 or dim <= 0.0:
		return
	var pr := Rect2(r.position, Vector2(r.size.x, r.size.y * Pal.ease_out(show)))
	draw_rect(pr.grow(6.0), Color(0, 0, 0, 0.5 * dim))
	draw_rect(pr, Color(0.075, 0.075, 0.08, 1.0))
	draw_rect(pr, Pal.ink(0.6 * dim), false, 1.5)
	if show < 1.0:
		return
	var y := r.position.y + 34.0
	for j in FILE_N:
		var key := "arc_file_%d" % j
		var full := Txt.t(key)
		var typed := clampf((file_t - 0.4 - j * 0.32) / 0.3, 0.0, 1.0) if dead_t < 0.0 else 1.0
		var n := int(ceil(full.length() * typed))
		var fs := 19 if j == 0 else 16
		var fnt := bold if j == 0 else font
		var c := Pal.ink(0.92 * dim, 1.3) if j > 0 else Pal.ink(0.95 * dim, 1.5)
		draw_string(fnt, Vector2(r.position.x + 18.0, y), full.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
		var tw := fnt.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if j == FILE_N - 1 and typed >= 1.0:
			# already blacked out in the original
			draw_rect(Rect2(r.position.x + 18.0 + tw + 4.0, y - fs + 2.0, 110.0, fs + 2.0), Color(0, 0, 0, 1))
			tw += 118.0
		if j >= 1:
			var k: float = strikes[j]
			if dead_t >= 0.0:
				# the bars peel off, top line first
				k *= 1.0 - Pal.ease_io(clampf((dead_t - 0.8 - (j - 1) * 0.5) / 0.6, 0.0, 1.0))
			if k > 0.0:
				var bar := Rect2(r.position.x + 12.0, y - fs - 1.0, (tw + 12.0) * k, fs + 8.0)
				draw_rect(bar, Color(0.006, 0.006, 0.008, 1.0))
				draw_line(Vector2(bar.end.x, bar.position.y), Vector2(bar.end.x, bar.end.y), Pal.red(0.8 * dim, 2.0), 2.0)
		y += 42.0 if j == 0 else 36.0
	# the stamp
	var sk: float = clampf(stamp_t / 0.18, 0.0, 1.0) if stamp_t >= 0.0 else 0.0
	if dead_t >= 0.0:
		sk *= 1.0 - clampf((dead_t - 3.6) / 0.8, 0.0, 1.0)
	if sk > 0.0:
		var st := Txt.t("arc_file_stamp")
		var ss := 18
		var stw := bold.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		var sc := Vector2(r.end.x - stw * 0.5 - 30.0, r.end.y - 22.0)
		var scale := 1.0 + 0.6 * (1.0 - Pal.ease_out(sk))
		draw_set_transform(sc, -0.08, Vector2(scale, scale))
		draw_rect(Rect2(-stw * 0.5 - 10.0, -ss - 2.0, stw + 20.0, ss + 14.0), Pal.red(0.85 * sk * dim, 1.8), false, 2.5)
		draw_string(bold, Vector2(-stw * 0.5, 4.0), st, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Pal.red(0.95 * sk * dim, 2.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
