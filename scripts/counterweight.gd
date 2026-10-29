class_name Counterweight
extends Node2D
# 配重块 THE COUNTERWEIGHT (chapter 9): the lift's counterweight, hung on its
# cable above the car's floor — stacked plates stencilled with what they are
# made of. It drifts overhead after you; then it picks its spot, its shadow
# swelling on the floor, and drops. Landed, it is a block on the floor and
# its plates have sprung: for a few seconds the whole of it can be hurt.
# Then the cable takes it up again. From the second phase every landing
# sends a shock across the floor; in the last, the spare weight comes down
# too, the two taking turns.

enum { OFF, ENTER, RUN, DYING, DEAD }
enum { HANG, AIM, DOWN, RISE }

const HP := 1400.0
const HALF := [100.0, 80.0]            # the main weight, the spare
const AIM_TIME := [1.6, 1.45, 1.35]    # the shadow swelling (locked for the last LOCK s)
const DOWN_TIME := [3.2, 2.8, 2.5]     # landed: hurtable
const HANG_TIME := [1.4, 1.1, 0.9]
const RISE_TIME := 0.7
const LOCK := 0.5
const SHOCK_R := 420.0
const SHOCK_TIME := 1.4
const SHOCK_DELAY := 0.5                # after landing: the plates spring, then the shock goes
const HOME := Vector2(960, 300)

class W:
	var on := false
	var mode := 0
	var mode_t := 0.0
	var pos := Vector2(960, 300)       # over the floor (where its shadow is)
	var target := Vector2.ZERO
	var half := 100.0
	var spare := false
	var hang_t := 0.0
	var plates := 0.0                  # 0..1 sprung open after landing

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
var ws: Array = []                     # the weights: the main, then the spare
var shocks: Array = []                 # [centre, t, struck]
var next_w := 0
var load_k := 0.0


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_counterweight"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


func begin_track() -> void:
	state = OFF
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	_fresh()
	game.sfx.play("horn", 0.4, -2.0)
	game.cam.add_trauma(0.3)
	game.hud.radio(Txt.t("radio_counterweight"))


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
	shocks.clear()
	next_w = 0
	ws.clear()
	for k in 2:
		var w := W.new()
		w.half = HALF[k]
		w.spare = k == 1
		w.on = k == 0
		w.pos = HOME + Vector2(0 if k == 0 else 400, 0)
		w.mode = HANG
		w.hang_t = 1.0
		ws.append(w)
	if game != null:
		game.arena.soft.clear()


func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	var w: W = ws[0]
	w.mode = DOWN
	w.mode_t = 0.0
	core_open = 1.0
	damage(HP, false, w.pos, Vector2.UP)


func rect_of(w: W) -> Rect2:
	return Rect2(w.pos - Vector2(w.half, w.half), Vector2(w.half, w.half) * 2.0)


# The weight on the floor (the one to hit), or the main one.
func _landed() -> W:
	for w: W in ws:
		if w.on and w.mode == DOWN:
			return w
	return null


func core_pos() -> Vector2:
	var w := _landed()
	return w.pos if w != null else (ws[0] as W).pos


func core_vel() -> Vector2:
	return Vector2.ZERO


# ---------------------------------------------------------------- bullets

func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	var best := {}
	var bt := 2.0
	for w: W in ws:
		if not w.on or w.mode != DOWN:
			continue
		var h := _rect_hit(a, b, rect_of(w))
		if not h.is_empty() and h.t < bt:
			bt = h.t
			if w.plates > 0.5:
				best = {"point": h.point, "normal": h.normal, "core": true, "mult": 1.0, "frame": -1, "car": 0}
			else:
				best = {"point": h.point, "normal": h.normal, "core": false, "car": 0}
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
	game.sfx.play("shield", randf_range(0.8, 0.9), -8.0)


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
	var w := _landed()
	var at: Vector2 = w.pos if w != null else HOME
	game.fx.ring(at, 60.0, 360.0, 0.6, Pal.foe(0.9, 1.5), 3.0)
	game.sfx.play("armor", 0.7, 0.0)
	game.add_hitstop(0.09)
	game.cam.add_trauma(0.6)
	game.cam.punch(0.04)
	game.hud.boss_phase()
	# the cable takes the weight up at once
	for ww: W in ws:
		if ww.on and ww.mode == DOWN:
			ww.mode = RISE
			ww.mode_t = 0.0
	if phase == 2:
		var sp: W = ws[1]
		sp.on = true
		sp.mode = HANG
		sp.hang_t = 1.6
		sp.pos = Vector2(game.player.pos.x + (300 if game.player.pos.x < 960 else -300), 300)
		game.hud.radio(Txt.t("radio_counterweight_spare"))


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	if state == OFF or state == DEAD:
		return
	t += dt
	flash = maxf(0.0, flash - dt / 0.12)
	red = maxf(0.0, red - dt / 0.8)
	guard_t = maxf(0.0, guard_t - dt)
	load_k = 0.5 + 0.5 * sin(t * 0.7)
	match state:
		ENTER:
			if t >= 1.2:
				state = RUN
				t = 0.0
		RUN:
			for k in ws.size():
				_step_w(ws[k], k, dt)
		DYING:
			_dying(dt)
	var lw := _landed()
	core_open = 1.0 if state == RUN and lw != null and lw.plates > 0.5 else 0.0
	_step_shocks(dt)
	var soft: Array[Rect2] = []
	for w: W in ws:
		if w.on and w.mode == DOWN:
			soft.append(rect_of(w))
	game.arena.soft = soft
	queue_redraw()


func _step_w(w: W, k: int, dt: float) -> void:
	if not w.on:
		return
	w.mode_t += dt
	var p: Vector2 = game.player.pos
	match w.mode:
		HANG:
			# drifting overhead after you; the spare keeps to one side
			var side := 1.0 if p.x < 960.0 else -1.0
			var hp_at := p if not w.spare else p + Vector2(280.0 * side, -120.0)
			if _other_down(w):
				# the other is coming down or is down: wait off to one side
				hp_at = p + Vector2(380.0 * side * (1.0 if w.spare else -1.0), -200.0)
			w.pos = w.pos.lerp(_clear_of_cover(_clamp(hp_at), w.half), 1.0 - exp(-1.6 * dt))
			w.hang_t -= dt
			# the two take turns
			var turn_ok := not (phase == 2 and next_w != k)
			if w.hang_t <= 0.0 and turn_ok and _other_down(w) == false:
				w.mode = AIM
				w.mode_t = 0.0
				w.target = _clear_of_cover(_clamp(p + game.player.vel * 0.25), w.half)
				game.sfx.play("windup", 0.5 if not w.spare else 0.62, -4.0)
		AIM:
			var lock: float = AIM_TIME[phase] - LOCK
			if w.mode_t < lock:
				w.target = w.target.lerp(_clear_of_cover(_clamp(p + game.player.vel * 0.2), w.half), 1.0 - exp(-5.0 * dt))
			w.pos = w.pos.lerp(w.target, 1.0 - exp(-8.0 * dt))
			if w.mode_t >= AIM_TIME[phase]:
				w.pos = w.target
				_land(w)
		DOWN:
			w.plates = minf(1.0, w.plates + dt / 0.25)
			if w.mode_t >= DOWN_TIME[phase]:
				w.mode = RISE
				w.mode_t = 0.0
				game.sfx.play("release", 0.5, -6.0)
		RISE:
			w.plates = maxf(0.0, w.plates - dt / 0.2)
			if w.mode_t >= RISE_TIME:
				w.mode = HANG
				w.mode_t = 0.0
				w.hang_t = HANG_TIME[phase]
				next_w = (k + 1) % 2 if phase == 2 else 0


func _other_down(me: W) -> bool:
	for w: W in ws:
		if w != me and w.on and (w.mode == AIM or w.mode == DOWN):
			return true
	return false


func _clamp(p: Vector2) -> Vector2:
	var m := 130.0
	var r := Arena.ROOM
	return Vector2(clampf(p.x, r.position.x + m, r.end.x - m), clampf(p.y, r.position.y + m, r.end.y - m))


# Nudge a landing spot off the seats and pillars.
func _clear_of_cover(at: Vector2, half: float) -> Vector2:
	for off: Vector2 in [Vector2.ZERO, Vector2(0, -150), Vector2(0, 150), Vector2(-170, 0), Vector2(170, 0)]:
		var q := _clamp(at + off)
		var rr := Rect2(q - Vector2(half, half), Vector2(half, half) * 2.0)
		var hit := false
		for ir: Rect2 in game.arena.inner:
			if ir.intersects(rr):
				hit = true
				break
		if not hit:
			return q
	return at


func _land(w: W) -> void:
	w.mode = DOWN
	w.mode_t = 0.0
	w.plates = 0.0
	var r := rect_of(w)
	game.sfx.play("slam", 0.35 if not w.spare else 0.45, 2.0)
	game.cam.add_trauma(0.7)
	game.cam.punch(0.05)
	game.add_hitstop(0.06)
	game.fx.ring(w.pos, w.half, w.half * 2.6, 0.4, Pal.ink(0.8, 1.5), 3.0)
	for j in 14:
		var a := TAU * j / 14.0
		game.fx.sparks(w.pos + Vector2.from_angle(a) * w.half, Vector2.from_angle(a), 2, Pal.ink(0.8, 1.3), 380.0, 0.3, 0.5)
	var p: Vector2 = game.player.pos
	if r.grow(Player.R).has_point(p) and game.player.dash_t <= 0.0:
		game.on_player_hit((p - w.pos).normalized() if p.distance_to(w.pos) > 1.0 else Vector2.DOWN, null)
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE and r.grow(e.r).has_point(e.pos):
			game.enemies.blast_hit(e, (e.pos - w.pos).normalized(), 80.0)
	if phase >= 1 and not w.spare:
		shocks.append([w.pos, -SHOCK_DELAY, false, w.half])


func _step_shocks(dt: float) -> void:
	var p: Vector2 = game.player.pos
	var i := 0
	while i < shocks.size():
		shocks[i][1] += dt
		var c: Vector2 = shocks[i][0]
		var rr: float = SHOCK_R * Pal.ease_out(maxf(0.0, shocks[i][1]) / SHOCK_TIME)
		if shocks[i][1] >= 0.0 and not shocks[i][2] and rr > 120.0 and absf(p.distance_to(c) - rr) < 12.0 and game.player.dash_t <= 0.0 and state == RUN:
			shocks[i][2] = true
			game.on_player_hit((p - c).normalized(), null)
		if shocks[i][1] >= SHOCK_TIME:
			shocks.remove_at(i)
		else:
			i += 1


func _dying(dt: float) -> void:
	dying_t += dt
	var w := _landed()
	var at: Vector2 = w.pos if w != null else (ws[0] as W).pos
	if dying_t > 0.2 and int(dying_t * 10.0) != int((dying_t - dt) * 10.0):
		var q := at + Vector2(randf_range(-90, 90), randf_range(-90, 90))
		game.fx.sparks(q, Vector2.from_angle(randf() * TAU), 6, Pal.foe(1.0, 1.8), 420.0, 0.3, 1.0)
		game.sfx.play("cross", randf_range(0.6, 1.0), -6.0)
	if dying_t >= 1.5:
		state = DEAD
		game.arena.soft.clear()
		for k in 36:
			var p0 := at + Vector2(randf_range(-100, 100), randf_range(-100, 100))
			game.fx.shard(p0, Vector2(-14, -5), Vector2(14, 5), (p0 - at).normalized() * randf_range(300, 700), randf_range(-12, 12), 1.4, Pal.foe(1.0, 1.7) if k % 3 else Pal.ink(0.9, 1.4), 2.0)
		game.on_boss_dead(at)
		queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if state == OFF or state == DEAD:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	var appear := Pal.ease_out(clampf(t / 1.2, 0.0, 1.0)) if state == ENTER else 1.0
	for s in shocks:
		if s[1] < 0.0:
			# about to go: a red ring flickering round the weight
			var wk: float = 1.0 + s[1] / SHOCK_DELAY
			var fl := 0.5 + 0.5 * sin(t * 30.0)
			draw_arc(s[0], float(s[3]) * 1.45 + 10.0 * (1.0 - wk), 0.0, TAU, 64, Pal.red((0.3 + 0.6 * wk) * fl * dim, 1.6), 2.5)
			continue
		var ks: float = s[1] / SHOCK_TIME
		var rr: float = SHOCK_R * Pal.ease_out(ks)
		draw_arc(s[0], rr - 12.0, 0.0, TAU, 96, Color(0, 0, 0, 0.45 * (1.0 - ks)), 20.0)
		draw_arc(s[0], rr, 0.0, TAU, 96, Pal.red((1.0 - ks) * dim, 2.2), 4.0)
		draw_arc(s[0], rr - 26.0, 0.0, TAU, 96, Pal.red(0.3 * (1.0 - ks) * dim, 1.4), 1.5)
	for w: W in ws:
		if w.on:
			_draw_shadow(w, dim * appear)
	# landed weights first, the ones overhead above them
	for w: W in ws:
		if w.on and w.mode == DOWN:
			_draw_weight(w, dim * appear)
	for w: W in ws:
		if w.on and w.mode != DOWN:
			_draw_weight(w, dim * appear)
	# where it will land, over everything it is hanging above
	for w: W in ws:
		if w.on and w.mode == AIM:
			_draw_mark(w, dim * appear)


# Its shadow on the floor: faint while it hangs, swelling and darkening as it
# aims, a red frame and cross once the spot is locked.
func _draw_shadow(w: W, dim: float) -> void:
	if w.mode == DOWN:
		return
	var k := 0.25
	var locked := false
	if w.mode == AIM:
		k = 0.25 + 0.75 * Pal.ease_in(clampf(w.mode_t / AIM_TIME[phase], 0.0, 1.0))
		locked = w.mode_t >= AIM_TIME[phase] - LOCK
	elif w.mode == RISE:
		k = 1.0 - 0.75 * clampf(w.mode_t / RISE_TIME, 0.0, 1.0)
	var at: Vector2 = w.target if w.mode == AIM else w.pos
	var h: float = w.half * (0.55 + 0.45 * k)
	var r := Rect2(at - Vector2(h, h), Vector2(h, h) * 2.0)
	draw_rect(r, Color(0, 0, 0, 0.25 + 0.45 * k))


# The red frame where it will land and, once locked, the cross.
func _draw_mark(w: W, dim: float) -> void:
	var k: float = 0.25 + 0.75 * Pal.ease_in(clampf(w.mode_t / AIM_TIME[phase], 0.0, 1.0))
	var locked: bool = w.mode_t >= AIM_TIME[phase] - LOCK
	var at: Vector2 = w.target
	if true:
		var fl := 0.6 + 0.4 * sin(t * (14.0 + 20.0 * k))
		var full := Rect2(at - Vector2(w.half, w.half), Vector2(w.half, w.half) * 2.0)
		draw_rect(full, Pal.red((0.25 + 0.6 * k) * fl * dim, 1.3 + (0.6 if locked else 0.0)), false, 2.0 + (1.5 if locked else 0.0))
		for c: Vector2 in [full.position, Vector2(full.end.x, full.position.y), full.end, Vector2(full.position.x, full.end.y)]:
			var sx := 1.0 if c.x < at.x else -1.0
			var sy := 1.0 if c.y < at.y else -1.0
			draw_line(c, c + Vector2(18.0 * sx, 0), Pal.red(0.9 * fl * dim, 1.6), 3.0)
			draw_line(c, c + Vector2(0, 18.0 * sy), Pal.red(0.9 * fl * dim, 1.6), 3.0)
		if locked:
			draw_line(at + Vector2(-16, 0), at + Vector2(16, 0), Pal.red(dim, 1.8), 2.0)
			draw_line(at + Vector2(0, -16), at + Vector2(0, 16), Pal.red(dim, 1.8), 2.0)


# The weight itself. Overhead it is drawn larger and lifted above its
# shadow, its cable running up out of sight; on the floor, stacked plates,
# stencilled, sprung apart to show the glowing core between them.
func _draw_weight(w: W, dim: float) -> void:
	var lift := 0.0
	if w.mode == HANG:
		lift = 1.0
	elif w.mode == AIM:
		lift = 1.0 - Pal.ease_in(clampf(w.mode_t / AIM_TIME[phase], 0.0, 1.0))
	elif w.mode == RISE:
		lift = Pal.ease_in(clampf(w.mode_t / RISE_TIME, 0.0, 1.0))
	var s := 1.0 + 0.22 * lift
	var c: Vector2 = w.pos + Vector2(0, -70.0 * lift)
	var h: float = w.half * s
	var r := Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0)
	var a := 1.0 - 0.62 * lift
	# the cable, up to the top wall
	# the cable: four strands up to a pulley block, swaying a little
	# (its pulley is up past the wall: only the strands come down)
	var cy := minf(Arena.ROOM.position.y, r.position.y)
	var sway := sin(t * 1.3 + (1.0 if w.spare else 0.0)) * 6.0 * (0.3 + lift)
	var py := Vector2(c.x + sway * 0.3, cy)
	for st in 4:
		var ox := (st - 1.5) * 4.0
		draw_line(py + Vector2(ox, 0), Vector2(c.x + ox + sway, r.position.y + 6.0), Pal.ink((0.24 if st % 2 == 0 else 0.15) * dim), 1.2)
	var col := Pal.foe(a * dim, 1.0 + 0.8 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	draw_rect(r, Color(0.05, 0.05, 0.055, 0.6 + 0.4 * a))
	# the plates: five bands across it, spreading apart once it has landed
	var bands := 5
	var spread: float = w.plates * 7.0
	for j in bands:
		var y0 := r.position.y + j * r.size.y / bands + (j - 2) * spread
		var pr := Rect2(r.position.x - (j % 2) * 4.0 * w.plates, y0 + 2.0, r.size.x + (j % 2) * 8.0 * w.plates, r.size.y / bands - 4.0)
		draw_rect(pr, Color(0.06, 0.06, 0.065, a))
		draw_rect(pr, col if j == 0 or j == bands - 1 else Pal.foe(0.55 * a * dim), false, 1.5)
		# bolts at the ends of each plate
		draw_circle(pr.position + Vector2(10, pr.size.y * 0.5), 3.0, Pal.foe(0.5 * a * dim))
		draw_circle(Vector2(pr.end.x - 10.0, pr.position.y + pr.size.y * 0.5), 3.0, Pal.foe(0.5 * a * dim))
		draw_circle(pr.position + Vector2(24, pr.size.y * 0.5), 2.0, Pal.foe(0.35 * a * dim))
		draw_circle(Vector2(pr.end.x - 24.0, pr.position.y + pr.size.y * 0.5), 2.0, Pal.foe(0.35 * a * dim))
		# the plate's number, painted at one end; streaks of wear
		if j != 2 and j != bands - 1:
			draw_string(Fonts.get_font("SemiBold"), Vector2(pr.end.x - 46.0, pr.position.y + pr.size.y * 0.5 + 5.0), "%02d" % (j + 1 + (5 if w.spare else 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.35 * a * dim))
		draw_line(pr.position + Vector2(36, 4), pr.position + Vector2(60 + (j * 13) % 30, 4), Pal.ink(0.12 * a * dim), 1.0)
	draw_rect(r, col, false, 2.5)
	# sprung: the core glowing in the gaps
	if w.plates > 0.05 and w.mode != HANG:
		var pulse := 0.5 + 0.5 * sin(t * 8.0)
		for j in bands - 1:
			var gy := r.position.y + (j + 1) * r.size.y / bands + (j - 1.5) * spread
			draw_line(Vector2(r.position.x + 14.0, gy), Vector2(r.end.x - 14.0, gy), Pal.foe((0.45 + 0.4 * pulse) * w.plates * dim, 1.6), 1.5 + 1.5 * w.plates)
		draw_rect(r.grow(6.0 + 4.0 * pulse), Pal.foe(0.18 * w.plates * dim, 1.4), false, 1.5)
	# the cable clamp on top
	var cl := Rect2(Vector2(c.x - 22.0, r.position.y - 6.0), Vector2(44, 16))
	draw_rect(cl, Color(0.07, 0.07, 0.075, a))
	draw_rect(cl, Pal.foe(0.7 * a * dim), false, 1.5)
	# the stencil and the load it carries
	var font := Fonts.get_font("SemiBold")
	var lab := Txt.t("cw_spare" if w.spare else "cw_stencil")
	var fs := 18 if not w.spare else 15
	var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var mid := Rect2(r.position.x + 8.0, r.position.y + 2.0 * r.size.y / bands + 2.0, r.size.x - 16.0, r.size.y / bands - 4.0)
	draw_rect(Rect2(mid.get_center() - Vector2(lw * 0.5 + 6.0, fs * 0.5 + 3.0), Vector2(lw + 12.0, fs + 6.0)), Color(0.04, 0.04, 0.045, a))
	draw_string(font, mid.get_center() + Vector2(-lw * 0.5, fs * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.9 * a * dim, 1.3))
	if not w.spare:
		var ld := Txt.t("cw_load")
		var ls := 12
		var ldw := font.get_string_size(ld, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
		draw_string(font, Vector2(r.get_center().x - ldw * 0.5, r.end.y - r.size.y / bands * 0.5 + ls * 0.36), ld, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, Pal.ink(0.6 * a * dim))
