class_name Boss
extends Node2D
# 逆行列车 THE RETROGRADE: a seven-car train on a loop around the middle of the
# room. Its armour turns bullets away; only the core in the tail car can be
# hurt, and only while its shutters are open. Every quarter of the core's
# health strips armour off the front cars and the train runs faster. Now and
# then it brakes, stops and runs backwards.

enum { OFF, ENTER, RUN, DYING, DEAD }
enum { CLOSED, WARN, OPEN }

const TRACK := Rect2(240, 170, 1440, 740)
const CORNER := 170.0
const CARS := 7
const SPACING := 82.0
const HP := 500.0
const CORE_R := 20.0
const SPEEDS := [360.0, 430.0, 500.0, 580.0]
const OPEN_TIME := [3.8, 3.5, 3.2, 3.0]
const BREAKS := [[1, 2], [3, 4], [5]]   # cars whose armour falls at 75 / 50 / 25 %

var game
var state := OFF
var t := 0.0
var pts := PackedVector2Array()    # sampled loop
var cum := PackedFloat32Array()
var loop_len := 0.0
var head := 0.0                    # distance of car 0 along the loop
var speed := 0.0
var dir := 1.0                     # 1 forward, -1 running backwards
var target_speed := 0.0
var reverse_t := 0.0               # >0 while braking / turning around
var next_reverse := 11.0
var horn_t := -1.0
var hp := HP
var phase := 0
var core := CLOSED
var core_t := 0.0
var core_open := 0.0               # shutter 0..1 (eased)
var core_flash := 0.0
var core_red := 0.0
var stripped := []                 # per car: armour gone
var strip_t := []                  # per car: time since stripped (for the burst)
var car_flash := []
var spawn_cd := 9.0
var track_draw := 0.0              # 0..1 rails tracing in
var dying_t := 0.0
var blown := []
var hit_cd := 0.0
var guard_t := 0.0               # after an armour break the core holds for a moment
var rails: Node2D


func _ready() -> void:
	z_index = 3
	z_as_relative = false
	rails = Node2D.new()
	rails.z_index = -7
	rails.z_as_relative = false
	rails.draw.connect(_draw_rails)
	add_child(rails)
	_build_track()
	for k in CARS:
		stripped.append(false)
		strip_t.append(-1.0)
		car_flash.append(0.0)
		blown.append(false)


func _build_track() -> void:
	# a rounded rectangle, sampled every ~6 px, clockwise from the top-left straight
	var r := CORNER
	var a := TRACK.position
	var b := TRACK.end
	var segs: Array = []
	segs.append(["line", Vector2(a.x + r, a.y), Vector2(b.x - r, a.y)])
	segs.append(["arc", Vector2(b.x - r, a.y + r), -PI / 2.0, 0.0])
	segs.append(["line", Vector2(b.x, a.y + r), Vector2(b.x, b.y - r)])
	segs.append(["arc", Vector2(b.x - r, b.y - r), 0.0, PI / 2.0])
	segs.append(["line", Vector2(b.x - r, b.y), Vector2(a.x + r, b.y)])
	segs.append(["arc", Vector2(a.x + r, b.y - r), PI / 2.0, PI])
	segs.append(["line", Vector2(a.x, b.y - r), Vector2(a.x, a.y + r)])
	segs.append(["arc", Vector2(a.x + r, a.y + r), PI, PI * 1.5])
	pts.clear()
	for sg in segs:
		if sg[0] == "line":
			var p0: Vector2 = sg[1]
			var p1: Vector2 = sg[2]
			var n := maxi(1, int(p0.distance_to(p1) / 6.0))
			for i in n:
				pts.append(p0.lerp(p1, float(i) / n))
		else:
			var c: Vector2 = sg[1]
			var n2 := 40
			for i in n2:
				pts.append(c + Vector2.from_angle(lerpf(sg[2], sg[3], float(i) / n2)) * r)
	pts.append(pts[0])
	cum.clear()
	var acc := 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		cum.append(acc)
	loop_len = acc


func at(s: float) -> Vector2:
	s = fposmod(s, loop_len)
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg := cum[hi] - cum[lo]
	var f := 0.0 if seg <= 0.0 else (s - cum[lo]) / seg
	return pts[lo].lerp(pts[hi], f)


func tangent(s: float) -> Vector2:
	return (at(s + 3.0) - at(s - 3.0)).normalized()


func car_s(k: int) -> float:
	return head - k * SPACING


func car_size(k: int) -> Vector2:
	return Vector2(88, 40) if k == 0 else Vector2(68, 34)


func car_xform(k: int) -> Transform2D:
	var s := car_s(k)
	return Transform2D(tangent(s).angle(), at(s))


func car_visible(k: int) -> bool:
	if blown[k]:
		return false
	return state != ENTER or car_s(k) >= 0.0


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


# Dev jumps: put the train back in its shed.
func reset() -> void:
	state = OFF
	t = 0.0
	hp = HP
	phase = 0
	core = CLOSED
	core_open = 0.0
	guard_t = 0.0
	reverse_t = 0.0
	next_reverse = 11.0
	track_draw = 0.0
	for k in CARS:
		stripped[k] = false
		strip_t[k] = -1.0
		blown[k] = false
	rails.queue_redraw()


# Dev: knock the core down to its next armour break (or finish it).
func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	damage(HP, false, core_pos(), Vector2.UP)


func begin_track() -> void:
	track_draw = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	head = 0.0
	speed = 0.0
	target_speed = SPEEDS[0]
	dir = 1.0
	hp = HP
	phase = 0
	core = CLOSED
	core_t = 0.0
	game.sfx.play("horn", 1.0, -2.0)
	game.cam.add_trauma(0.2)


func core_pos() -> Vector2:
	return at(car_s(CARS - 1))


func core_vel() -> Vector2:
	return tangent(car_s(CARS - 1)) * speed * dir


# ---------------------------------------------------------------- bullets

# Nearest contact of segment a->b with the train.
# {point, normal, core: bool}; armoured cars turn rounds away, the open core is hit.
func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	var best := {}
	var bd := INF
	if core_open > 0.5:
		var cp := core_pos()
		var q := Geometry2D.get_closest_point_to_segment(cp, a, b)
		if q.distance_to(cp) <= CORE_R + 6.0:
			var d0 := a.distance_to(q)
			if d0 < bd:
				bd = d0
				best = {"point": q, "normal": (a - cp).normalized(), "core": true, "mult": 1.0}
	for k in CARS:
		if not car_visible(k):
			continue
		if stripped[k]:
			# a bare frame: rounds pass through and still hurt it, at half weight
			var fp := at(car_s(k))
			var fq := Geometry2D.get_closest_point_to_segment(fp, a, b)
			if fq.distance_to(fp) <= 20.0:
				var d1 := a.distance_to(fq)
				if d1 < bd:
					bd = d1
					best = {"point": fq, "normal": (a - fp).normalized(), "core": true, "mult": 0.35, "frame": k}
			continue
		if k == CARS - 1 and core_open > 0.5:
			continue
		var tr := car_xform(k)
		var inv := tr.affine_inverse()
		var la := inv * a
		var lb := inv * b
		var sz := car_size(k)
		var r := Rect2(-sz / 2.0, sz)
		var h := _seg_rect(la, lb, r)
		if h.is_empty():
			continue
		var p: Vector2 = tr * (la.lerp(lb, h.t))
		var d := a.distance_to(p)
		if d < bd:
			bd = d
			best = {"point": p, "normal": tr.basis_xform(h.normal).normalized(), "core": false, "car": k}
	return best


static func _seg_rect(a: Vector2, b: Vector2, r: Rect2) -> Dictionary:
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
	return {"t": t0, "normal": n}


func on_armor(k: int, at_p: Vector2, normal: Vector2) -> void:
	car_flash[k] = 1.0
	game.fx.sparks(at_p, normal, 5, Pal.ink(1.0, 1.9), 420.0, 0.2, 0.9)
	game.fx.flash(at_p, 16.0, 0.08, Pal.ink(0.4, 1.4))
	game.sfx.play("shield", randf_range(0.7, 0.85), -8.0)


func damage(dmg: float, ret: bool, at_p: Vector2, d: Vector2, frame_k: int = -1) -> void:
	if state != RUN:
		return
	dmg /= Loadout.boss_hp()
	# never skip a phase: the floor is the next break until its show has played
	var floor_hp := HP * (1.0 - (phase + 1) * 0.25) if phase < 3 else 0.0
	if guard_t > 0.0:
		floor_hp = maxf(floor_hp, hp)
	hp = maxf(floor_hp - (0.001 if guard_t <= 0.0 else 0.0), hp - dmg)
	if frame_k >= 0:
		car_flash[frame_k] = 1.0
	core_flash = 1.0
	if ret:
		core_red = 1.0
	game.fx.number(at_p, dmg, ret)
	var c := Pal.red(1.0, 3.2) if ret else Pal.ink(1.0, 1.8)
	game.fx.sparks(at_p, d, 8 if ret else 5, c, 560.0, 0.28, 0.8)
	game.fx.flash(at_p, 34.0, 0.14, Color(c.r, c.g, c.b, 0.4))
	game.on_target_hit(ret)
	# armour falls car by car as the core weakens
	var want := clampi(int((1.0 - hp / HP) * 4.0), 0, 3)
	while phase < want:
		_break(phase)
		phase += 1
		target_speed = SPEEDS[phase]
	if hp <= 0.0:
		_die()


func _break(p: int) -> void:
	for k in BREAKS[p]:
		stripped[k] = true
		strip_t[k] = 0.0
		var tr := car_xform(k)
		var sz := car_size(k)
		var corners := [Vector2(-sz.x, -sz.y) / 2.0, Vector2(sz.x, -sz.y) / 2.0, Vector2(sz.x, sz.y) / 2.0, Vector2(-sz.x, sz.y) / 2.0]
		for j in 4:
			var a: Vector2 = corners[j]
			var b: Vector2 = corners[(j + 1) % 4]
			var mid := (a + b) * 0.5
			var out := tr.basis_xform(mid).normalized()
			game.fx.shard(tr * mid, tr.basis_xform(a - mid), tr.basis_xform(b - mid), out * randf_range(260, 420) + tangent(car_s(k)) * speed * dir * 0.5, randf_range(-8, 8), 1.1, Pal.ink(1.0, 1.5), 3.0)
		game.fx.sparks(tr.origin, Vector2.UP, 18, Pal.ink(1.0, 1.9), 700.0, 0.45, PI)
		game.fx.ring(tr.origin, 20.0, 160.0, 0.5, Pal.ink(0.9, 1.4), 2.5)
	# the shutters slam shut for a moment
	core = CLOSED
	core_t = -1.2
	guard_t = 1.5
	game.sfx.play("armor", 1.0, 0.0)
	game.add_hitstop(0.09)
	game.cam.add_trauma(0.6)
	game.cam.punch(0.04)
	game.hud.boss_phase()


func _die() -> void:
	state = DYING
	dying_t = 0.0
	hp = 0.0
	target_speed = 0.0
	game.on_boss_dying()


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	if track_draw > 0.0 and track_draw < 1.0:
		track_draw = minf(1.0, track_draw + dt / 1.3)
		rails.queue_redraw()
	if state == OFF or state == DEAD:
		queue_redraw()
		return
	t += dt
	core_flash = maxf(0.0, core_flash - dt / 0.12)
	core_red = maxf(0.0, core_red - dt / 0.8)
	hit_cd -= dt
	guard_t = maxf(0.0, guard_t - dt)
	for k in CARS:
		car_flash[k] = maxf(0.0, car_flash[k] - dt / 0.15)
		if strip_t[k] >= 0.0:
			strip_t[k] += dt
	match state:
		ENTER:
			speed = Pal.damp(speed, target_speed, 1.5, dt)
			head += speed * dt
			if car_s(CARS - 1) > 40.0:
				state = RUN
		RUN:
			_run(dt)
		DYING:
			_dying(dt)
	if state != DEAD:
		_contact()
	queue_redraw()


func _run(dt: float) -> void:
	# reversing: brake, pause with the horn, run the other way
	next_reverse -= dt
	if reverse_t <= 0.0 and next_reverse <= 0.0:
		reverse_t = 2.0
		horn_t = 0.0
		game.sfx.play("brake", 1.0, -4.0)
	if reverse_t > 0.0:
		reverse_t -= dt
		if reverse_t > 1.2:
			speed = Pal.damp(speed, 0.0, 5.0, dt)
			if randf() < 0.5:
				var k := randi() % CARS
				if car_visible(k):
					var p := at(car_s(k)) + tangent(car_s(k)).orthogonal() * randf_range(-18, 18)
					game.fx.spark(p, -tangent(car_s(k)) * dir * randf_range(200, 400), 0.25, Pal.ink(1.0, 1.8), 1.2, 8.0)
		elif reverse_t > 0.9:
			speed = Pal.damp(speed, 0.0, 12.0, dt)
		else:
			if reverse_t <= 0.9 and reverse_t + dt > 0.9:
				dir = -dir
				game.sfx.play("horn", 0.85, -3.0)
				game.cam.add_trauma(0.15)
			speed = Pal.damp(speed, target_speed, 2.2, dt)
		if reverse_t <= 0.0:
			next_reverse = randf_range(10.0, 14.0) - phase * 1.2
	else:
		speed = Pal.damp(speed, target_speed, 1.2, dt)
	head += speed * dir * dt
	if horn_t >= 0.0:
		horn_t += dt
		if horn_t > 2.0:
			horn_t = -1.0
	# the core's shutters cycle
	core_t += dt
	match core:
		CLOSED:
			if core_t >= 4.2 - phase * 0.4:
				core = WARN
				core_t = 0.0
				game.sfx.play("core", 0.9, -6.0)
		WARN:
			if core_t >= 0.6:
				core = OPEN
				core_t = 0.0
				game.sfx.play("core", 1.2, -3.0)
		OPEN:
			if core_t >= OPEN_TIME[phase]:
				core = CLOSED
				core_t = 0.0
				game.sfx.play("core", 0.7, -8.0)
	core_open = Pal.damp(core_open, 1.0 if core == OPEN else 0.0, 14.0, dt)
	# from the second phase the engine drops chasers
	if phase >= 1:
		spawn_cd -= dt
		if spawn_cd <= 0.0:
			spawn_cd = 10.0 - phase * 1.5
			var p0 := at(car_s(0))
			for i in 3:
				game.enemies.spawn(Enemies.CHASER, p0 + Vector2.from_angle(randf() * TAU) * 40.0, i * 0.1)


func _dying(dt: float) -> void:
	dying_t += dt
	speed = Pal.damp(speed, 0.0, 2.0, dt)
	head += speed * dir * dt
	core_open = Pal.damp(core_open, 1.0, 10.0, dt)
	# cars burst from the engine back to the core
	for k in CARS - 1:
		if not blown[k] and dying_t >= 0.25 + k * 0.17:
			blown[k] = true
			_burst(k, 1.0)
	if dying_t >= 0.25 + (CARS - 1) * 0.17 + 0.35 and not blown[CARS - 1]:
		blown[CARS - 1] = true
		_burst(CARS - 1, 2.0)
		game.on_boss_dead(core_pos())
		state = DEAD


func _burst(k: int, big: float) -> void:
	var tr := car_xform(k)
	var sz := car_size(k)
	var corners := [Vector2(-sz.x, -sz.y) / 2.0, Vector2(sz.x, -sz.y) / 2.0, Vector2(sz.x, sz.y) / 2.0, Vector2(-sz.x, sz.y) / 2.0]
	for j in 4:
		var a: Vector2 = corners[j]
		var b: Vector2 = corners[(j + 1) % 4]
		var mid := (a + b) * 0.5
		var out := tr.basis_xform(mid).normalized()
		game.fx.shard(tr * mid, tr.basis_xform(a - mid), tr.basis_xform(b - mid), out * randf_range(300, 520) * big, randf_range(-10, 10), 1.2, Pal.ink(1.0, 1.6), 2.5)
	game.fx.sparks(tr.origin, Vector2.UP, int(16 * big), Pal.ink(1.0, 1.9), 800.0 * big, 0.5, PI)
	game.fx.ring(tr.origin, 20.0, 180.0 * big, 0.55, Pal.ink(0.9, 1.5), 2.5)
	game.fx.flash(tr.origin, 90.0 * big, 0.3, Pal.ink(0.5, 1.4))
	game.sfx.play("die", randf_range(0.7, 0.8), 0.0)
	game.cam.add_trauma(0.3 * big)
	game.add_hitstop(0.05)


func _contact() -> void:
	var pl: Vector2 = game.player.pos
	for k in CARS:
		if not car_visible(k):
			continue
		var tr := car_xform(k)
		var lp := tr.affine_inverse() * pl
		var sz := car_size(k) / 2.0 + Vector2(Player.R - 2.0, Player.R - 2.0)
		if absf(lp.x) < sz.x and absf(lp.y) < sz.y:
			var away := tr.basis_xform(Vector2(0, signf(lp.y) if lp.y != 0.0 else 1.0)).normalized()
			game.on_player_hit(away, null)
			return


# ---------------------------------------------------------------- drawing

func _draw_rails() -> void:
	if track_draw <= 0.0:
		return
	var upto := loop_len * Pal.ease_io(track_draw)
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	var ties := PackedVector2Array()
	var s := 0.0
	var step_len := 6.0
	var tie_acc := 0.0
	while s <= upto:
		var p := at(s)
		var n := tangent(s).orthogonal()
		inner.append(p + n * 13.0)
		outer.append(p - n * 13.0)
		tie_acc += step_len
		if tie_acc >= 30.0:
			tie_acc = 0.0
			ties.append(p + n * 19.0)
			ties.append(p - n * 19.0)
		s += step_len
	if inner.size() > 1:
		rails.draw_polyline(inner, Pal.ink(0.28), 1.5, false)
		rails.draw_polyline(outer, Pal.ink(0.28), 1.5, false)
	if ties.size() > 0:
		rails.draw_multiline(ties, Pal.ink(0.09), 3.0)
	# the gate the train comes through
	if track_draw >= 1.0:
		var g := at(0.0)
		var gn := tangent(0.0).orthogonal()
		rails.draw_line(g + gn * 30.0, g + gn * 22.0, Pal.ink(0.7), 3.0)
		rails.draw_line(g - gn * 30.0, g - gn * 22.0, Pal.ink(0.7), 3.0)


func _draw() -> void:
	if state == OFF:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	# track glow under the train
	for k in CARS:
		if not car_visible(k):
			continue
		var tr := car_xform(k)
		var sz := car_size(k)
		var r := Rect2(-sz / 2.0, sz)
		var appear := 1.0
		if state == ENTER:
			appear = Pal.ease_out(clampf(car_s(k) / 60.0, 0.0, 1.0))
		draw_set_transform_matrix(tr)
		var edge := Pal.ink(dim * appear, 1.0 + 0.8 * car_flash[k])
		if stripped[k]:
			# a bare frame after the armour is gone
			var st: float = strip_t[k]
			var glow_k := maxf(0.0, 1.0 - st / 0.4)
			draw_rect(r.grow(-4), Pal.ink(0.35 * dim * appear, 1.0 + 2.0 * glow_k), false, 1.0)
			draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), Pal.ink(0.18 * dim), 1.0)
			draw_line(Vector2(r.position.x + 4, r.end.y - 4), Vector2(r.end.x - 4, r.position.y + 4), Pal.ink(0.18 * dim), 1.0)
		else:
			draw_rect(r, Color(0.06, 0.06, 0.065, appear))
			draw_rect(r, edge, false, 2.0)
			draw_rect(r.grow(-5), Pal.ink(0.16 * dim * appear), false, 1.0)
			# armour seams and windows
			var n := 3 if k > 0 else 2
			for j in n:
				var x := lerpf(r.position.x + 12.0, r.end.x - 12.0, (j + 0.5) / n)
				draw_rect(Rect2(x - 5.0, -4.0, 10.0, 8.0), Pal.ink(0.22 * dim * appear), false, 1.0)
		if k == 0:
			# the engine's nose and headlight, pointing the way it runs
			var front := r.end.x if dir > 0.0 else r.position.x
			var sgn := 1.0 if dir > 0.0 else -1.0
			draw_colored_polygon(PackedVector2Array([Vector2(r.end.x, -sz.y / 2.0), Vector2(r.end.x + 14.0, 0), Vector2(r.end.x, sz.y / 2.0)]), Pal.ink(0.9 * dim * appear))
			if horn_t >= 0.0 and int(horn_t * 8.0) % 2 == 0:
				draw_circle(Vector2(front + sgn * 4.0, 0), 5.0, Pal.ink(1.0, 2.6))
		if k == CARS - 1:
			_draw_core(r, dim * appear)
		# couplings
		if k > 0 and car_visible(k - 1):
			draw_line(Vector2(r.end.x, 0), Vector2(r.end.x + (SPACING - (car_size(k).x + car_size(k - 1).x) / 2.0), 0), Pal.ink(0.5 * dim), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the lane ahead lights up while it brakes to reverse
	if state == RUN and reverse_t > 0.0:
		var lead := CARS - 1 if dir > 0.0 else 0
		var lead_s := car_s(lead) - dir * 50.0
		var segs := PackedVector2Array()
		for i in 14:
			var s0 := lead_s - dir * (i * 26.0)
			segs.append(at(s0))
			segs.append(at(s0 - dir * 13.0))
		draw_multiline(segs, Pal.ink(0.35 + 0.3 * sin(t * 20.0)), 2.0)


func _draw_core(r: Rect2, a: float) -> void:
	var o := core_open
	var warn := 0.0
	if core == WARN:
		warn = 0.5 + 0.5 * sin(core_t * 50.0)
	# the core: a white hexagon that glows hot when open, red after a recall hit
	var cc := Pal.ink(a, 1.1 + 0.7 * o + 0.6 * core_flash).lerp(Pal.red(a, 2.2), core_red * 0.9)
	var hex := PackedVector2Array()
	for j in 6:
		hex.append(Vector2.from_angle(TAU * j / 6.0 + game.real_time * (0.6 + 2.0 * o)) * CORE_R * (0.55 + 0.45 * o))
	draw_colored_polygon(hex, cc)
	if o > 0.05:
		draw_arc(Vector2.ZERO, CORE_R + 4.0 + 3.0 * sin(game.real_time * 9.0), 0.0, TAU, 28, Pal.ink(0.6 * o * a, 1.5), 1.5, false)
	# shutters: two plates that slide apart along the car
	var gap := o * (r.size.x / 2.0 - 4.0)
	var plate_w := r.size.x / 2.0 - 2.0
	var pc := Pal.ink(a, 1.0 + warn * 0.8)
	var left := Rect2(Vector2(-plate_w - gap, -r.size.y / 2.0 + 3.0), Vector2(plate_w, r.size.y - 6.0))
	var right := Rect2(Vector2(gap, -r.size.y / 2.0 + 3.0), Vector2(plate_w, r.size.y - 6.0))
	for pr: Rect2 in [left, right]:
		var clip := pr.intersection(r)
		if clip.size.x > 1.0:
			draw_rect(clip, Color(0.07, 0.07, 0.075, a))
			draw_rect(clip, pc * Color(1, 1, 1, 0.8), false, 1.5)
