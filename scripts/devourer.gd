class_name Devourer
extends Node2D
# 战略储备回收机 THE RESERVE INTAKE (chapter 4; it was the Devourer): the
# production union's intake hopper, a mouth in the middle of the floor. Every few seconds
# it inhales the rounds embedded around it and keeps them circling inside.
# The more it holds, the wider its core opens. Hitting the core makes it spit
# rounds back out; anything it swallowed comes back on its own after 10 s.
# Phase 2 (66%): longer reach, it creeps toward you. Phase 3 (33%): "full
# capacity" — it births leeches, and the floor's arms feed it the reserve
# crate's stock and shove enemies in. Shares the boss interface and the
# bullet-holder interface.

enum { OFF, ENTER, RUN, DYING, DEAD }
enum { IDLE, INHALE }

const HP := 1100.0
const R := 72.0
const HOME := Vector2(960, 540)
const REACH := [380.0, 520.0, 520.0]
const EVERY := [7.0, 6.0, 6.0]
const KEEP := 10.0

var game
var state := OFF
var t := 0.0
var hp := HP
var phase := 0
var pos := HOME
var vel := Vector2.ZERO
var guard_t := 0.0
var flash := 0.0
var red := 0.0
var core_open := 0.3
var mode := IDLE
var mode_t := 0.0
var cd := 4.0
var spawn_cd := 8.0
var enter_t := 0.0
var dying_t := 0.0
var pulled: Array = []       # rounds being drawn in: [bullet, from]


func _ready() -> void:
	z_index = 0   # under the bullets, so what it holds is seen circling inside
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_3"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


# ---- bullet-holder interface
func holds() -> bool:
	return state == RUN or state == ENTER


func hold_center() -> Vector2:
	return pos


func hold_radius() -> float:
	return core_r() + 9.0 + 3.0 * sin(t * 2.0)


func held() -> int:
	return game.bullets.held_by(self).size()


func core_r() -> float:
	return 20.0 + minf(26.0, held() * 2.0)


func begin_track() -> void:
	state = OFF
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	hp = HP
	phase = 0
	pos = HOME
	cd = 4.0
	spawn_cd = 8.0
	mode = IDLE
	game.sfx.play("horn", 0.6, -2.0)
	game.cam.add_trauma(0.3)
	game.hud.radio(Txt.t("radio_intake"))


func reset() -> void:
	state = OFF
	t = 0.0
	hp = HP
	phase = 0
	pos = HOME
	enter_t = 0.0
	guard_t = 0.0
	mode = IDLE
	pulled.clear()


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

# The open core hurts; the jaw around it turns rounds away.
func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	if a.distance_to(pos) < R:
		return {}   # already inside the mouth: it flies on through
	var d := b - a
	var hb := Geometry2D.segment_intersects_circle(a, b, pos, R)
	if hb < 0.0:
		return {}
	var p := a + d * hb
	# a round whose line runs through the open core goes in; the rest glance off the jaw
	var dir := d.normalized()
	var rel := pos - a
	var perp := (rel - dir * rel.dot(dir)).length()
	if perp <= core_r():
		return {"point": p, "normal": (p - pos).normalized(), "core": true, "mult": 1.0}
	return {"point": p, "normal": (p - pos).normalized(), "core": false, "car": 0}


func on_armor(_k: int, at_p: Vector2, normal: Vector2) -> void:
	flash = maxf(flash, 0.4)
	game.fx.sparks(at_p, normal, 5, Pal.foe(1.0, 1.8), 400.0, 0.2, 0.9)
	game.sfx.play("shield", randf_range(0.6, 0.75), -8.0)


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
	game.on_target_hit(ret)
	# a hit in the core makes it cough a round back up
	var inside: Array = game.bullets.held_by(self)
	if inside.size() > 0:
		var b = inside[0]
		game.bullets.fling(b, (b.pos - pos).normalized())
		game.fx.flash(b.pos, 20.0, 0.12, Pal.foe(0.6, 1.6))
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
	# it spits everything out at once
	for b in game.bullets.held_by(self):
		game.bullets.fling(b, (b.pos - pos).normalized().rotated(randf_range(-0.3, 0.3)))
	game.fx.ring(pos, R, 360.0, 0.6, Pal.foe(0.9, 1.5), 3.0)
	game.sfx.play("armor", 0.8, 0.0)
	game.add_hitstop(0.09)
	game.cam.add_trauma(0.6)
	game.cam.punch(0.04)
	game.hud.boss_phase()
	if phase == 2:
		game.hud.radio(Txt.t("radio_intake_full"))


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	if enter_t > 0.0 and enter_t < 1.0 and state == OFF:
		enter_t = minf(1.0, enter_t + dt / 2.4)
	if state == OFF or state == DEAD:
		queue_redraw()
		return
	t += dt
	flash = maxf(0.0, flash - dt / 0.15)
	red = maxf(0.0, red - dt / 0.8)
	guard_t = maxf(0.0, guard_t - dt)
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
	core_open = clampf(core_r() / 40.0, 0.3, 1.0)
	if state == RUN or state == ENTER:
		pos = game.arena.push_circle(pos, R)
		if pos.distance_to(pl) < R + Player.R - 6.0:
			game.on_player_hit((pl - pos).normalized(), null)
	queue_redraw()


func _run(dt: float, pl: Vector2) -> void:
	# swallowed rounds come back on their own (the fallback)
	for b in game.bullets.held_by(self):
		if b.hold_t > KEEP:
			game.bullets.fling(b, (b.pos - pos).normalized())
	mode_t += dt
	match mode:
		IDLE:
			cd -= dt
			if cd <= 0.0:
				mode = INHALE
				mode_t = 0.0
				pulled.clear()
				for b in game.bullets.list:
					if b.state == Bullets.EMBED and b.pos.distance_to(pos) < REACH[phase]:
						pulled.append([b, b.pos])
				game.sfx.play("focus", 0.6, 0.0)
				game.cam.add_trauma(0.15)
		INHALE:
			# rounds slide in along straight lines, then are taken
			var k := Pal.ease_in(clampf(mode_t / 0.7, 0.0, 1.0))
			for pr in pulled:
				var b = pr[0]
				if b.state == Bullets.EMBED:
					b.pos = (pr[1] as Vector2).lerp(pos, k * 0.85)
			if mode_t >= 0.7:
				for pr in pulled:
					var b2 = pr[0]
					if b2.state == Bullets.EMBED:
						game.bullets.capture(b2, self)
				pulled.clear()
				mode = IDLE
				cd = EVERY[phase]
				game.sfx.play("slam", 0.6, -3.0)
	# from phase 2 it creeps toward you
	var drift := Vector2.ZERO
	if phase >= 1:
		drift = (pl - pos).normalized() * 45.0
	drift += (HOME - pos) * 0.15
	vel = Pal.damp2(vel, drift, 2.0, dt)
	pos += vel * dt
	if phase >= 2:
		spawn_cd -= dt
		if spawn_cd <= 0.0:
			spawn_cd = 9.0
			for k2 in 2:
				game.enemies.spawn(Enemies.LEECH, pos + Vector2.from_angle(randf() * TAU) * (R + 30.0), k2 * 0.2)


func _dying(dt: float) -> void:
	dying_t += dt
	if dying_t < 0.05:
		for b in game.bullets.held_by(self):
			game.bullets.fling(b, (b.pos - pos).normalized())
	pos += Vector2(sin(dying_t * 60.0), cos(dying_t * 53.0)) * 2.5 * dying_t
	if dying_t >= 1.3:
		state = DEAD
		for k in 28:
			var a := TAU * k / 28.0
			var p0 := Vector2.from_angle(a) * R
			var p1 := Vector2.from_angle(a + 0.3) * R * 0.7
			game.fx.shard(pos + (p0 + p1) * 0.5, (p0 - p1) * 0.5, (p1 - p0) * 0.5, p0.normalized() * randf_range(260, 620), randf_range(-10, 10), 1.4, Pal.foe(1.0, 1.6), 2.5)
		game.on_boss_dead(pos)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if state == OFF:
		if enter_t > 0.0:
			# a slow spiral gathers in the middle during the title
			var e := Pal.ease_io(enter_t)
			for k in 3:
				var pts := PackedVector2Array()
				for j in 40:
					var u := j / 39.0
					var a := u * TAU * 1.5 + enter_t * 5.0 + TAU * k / 3.0
					pts.append(HOME + Vector2.from_angle(a) * lerpf(R * 3.0, R * 0.4, u) * (1.6 - e))
				draw_polyline(pts, Pal.foe(0.4 * e * dim), 1.0, false)
		return
	if state == DEAD:
		return
	var appear := Pal.back(clampf(t / 0.8, 0.0, 1.0)) if state == ENTER else 1.0
	var col := Pal.foe(dim, 1.0 + 0.6 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	var full := phase >= 2 and state == RUN
	# feed belts running in from four sides, slats and ration boxes moving in
	var slats := PackedVector2Array()
	var rails := PackedVector2Array()
	var boxes: Array = []
	var bl := 170.0
	for k0 in 4:
		var d0 := Vector2.from_angle(PI / 4.0 + TAU * k0 / 4.0)
		var n0 := d0.orthogonal()
		var a := pos + d0 * (R + 50.0) * appear
		var b := pos + d0 * (R + 50.0 + bl) * appear
		for sd: float in [-1.0, 1.0]:
			rails.append(a + n0 * 19.0 * sd)
			rails.append(b + n0 * 19.0 * sd)
		var spd := 90.0 if full else 45.0
		var s0 := fmod(t * spd, 14.0)
		while s0 < bl * appear:
			var q := b - d0 * s0
			slats.append(q + n0 * 16.0)
			slats.append(q - n0 * 16.0)
			s0 += 14.0
		var s1 := fmod(t * spd + k0 * 37.0, 80.0)
		while s1 < bl * appear - 10.0:
			boxes.append([b - d0 * s1, d0])
			s1 += 80.0
	if slats.size() > 0:
		draw_multiline(slats, Pal.ink(0.14 * dim), 2.0)
	draw_multiline(rails, Pal.ink(0.45 * dim), 2.0)
	for bx in boxes:
		var c0: Vector2 = bx[0]
		var bxr := Rect2(c0 - Vector2(10, 10), Vector2(20, 20))
		draw_rect(bxr, Color(0.07, 0.07, 0.075))
		draw_rect(bxr, Pal.ink(0.45 * dim), false, 1.0)
	# the hopper: a square mouth stepping down in three rims to the crusher,
	# hazard corners on the outer rim
	var hs := (R + 46.0) * appear
	for ring in 3:
		var rs := hs - ring * 14.0
		var rr2 := Rect2(pos - Vector2(rs, rs), Vector2(rs, rs) * 2.0)
		draw_rect(rr2, Color(0.04 + ring * 0.008, 0.04 + ring * 0.008, 0.045 + ring * 0.008, appear))
		draw_rect(rr2, col if ring == 0 else Pal.foe((0.35 - ring * 0.08) * dim), false, 2.0 if ring == 0 else 1.0)
	# funnel seams from each corner down to the crusher
	var seams := PackedVector2Array()
	for cx: float in [-1.0, 1.0]:
		for cy: float in [-1.0, 1.0]:
			seams.append(pos + Vector2(cx, cy) * hs)
			seams.append(pos + Vector2(cx, cy).normalized() * R * appear)
	draw_multiline(seams, Pal.foe(0.3 * dim), 1.5)
	var corner := PackedVector2Array()
	for cx: float in [-1.0, 1.0]:
		for cy: float in [-1.0, 1.0]:
			var c1 := pos + Vector2(cx, cy) * hs
			for j2 in 3:
				var o := 6.0 + j2 * 8.0
				corner.append(c1 - Vector2(cx * o, 0))
				corner.append(c1 - Vector2(0, cy * o))
	draw_multiline(corner, Pal.red((0.7 if full else 0.3) * dim, 1.4), 2.5)
	# the crusher: a ring of teeth that turns (faster at full capacity)
	var teeth := 14
	var pts2 := PackedVector2Array()
	for k in teeth * 2 + 1:
		var a2 := TAU * k / (teeth * 2) + t * (0.6 if full else 0.15)
		var rr := R * appear * (1.0 if k % 2 == 0 else 0.86 + 0.04 * sin(t * 3.0 + k))
		pts2.append(pos + Vector2.from_angle(a2) * rr)
	draw_colored_polygon(pts2.slice(0, teeth * 2), Color(0.05, 0.05, 0.055, appear))
	draw_polyline(pts2, col, 2.0, false)
	# funnel lines down into the throat
	var fun := PackedVector2Array()
	for k3 in 8:
		var a3 := TAU * k3 / 8.0 + t * 0.1
		fun.append(pos + Vector2.from_angle(a3) * R * 0.82 * appear)
		fun.append(pos + Vector2.from_angle(a3 + 0.5) * (core_r() + 8.0) * appear)
	draw_multiline(fun, Pal.foe(0.22 * dim), 1.0)
	# the core: opens with what it holds
	var cr := core_r() * appear
	draw_circle(pos, cr, Pal.foe(dim, 1.2 + 1.2 * flash).lerp(Pal.red(dim, 2.2), red * 0.8).lerp(Pal.ink(dim, 2.4), flash * 0.6))
	draw_arc(pos, cr + 5.0, 0.0, TAU, 32, Pal.foe(0.5 * dim), 1.0, false)
	_draw_counter(dim, appear, full)
	# inhale: lines of pull toward the mouth
	if state == RUN and mode == INHALE:
		var k2 := mode_t / 0.7
		draw_arc(pos, REACH[phase] * (1.0 - Pal.ease_in(k2)), 0.0, TAU, 96, Pal.foe(0.5 * (1.0 - k2) * dim), 2.0, false)
		for pr in pulled:
			var b = pr[0]
			if b.state == Bullets.EMBED:
				draw_line(b.pos, pos, Pal.foe(0.18 * dim), 1.0)
	elif state == RUN and cd < 1.2:
		# the warning before a breath: the reach is drawn and tightens
		var w := 1.0 - cd / 1.2
		draw_arc(pos, REACH[phase], 0.0, TAU, 96, Pal.foe((0.15 + 0.35 * w) * dim), 1.0 + w, false)


# The intake's counter, hung over the hopper: what goes to reserve, what to
# the people; at full capacity it only says so.
func _draw_counter(dim: float, appear: float, full: bool) -> void:
	if appear < 0.3:
		return
	var font := Fonts.get_font("SemiBold")
	var r := Rect2(pos + Vector2(-110.0, -R - 120.0), Vector2(220.0, 56.0))
	draw_rect(r, Color(0.02, 0.025, 0.03, appear))
	draw_rect(r, Pal.foe(0.55 * dim * appear), false, 1.5)
	draw_line(Vector2(r.get_center().x, r.end.y), pos + Vector2(0, -R - 46.0), Pal.ink(0.35 * dim), 2.0)
	if full:
		if fmod(t * 3.0, 1.0) < 0.6:
			var w := font.get_string_size(Txt.t("intake_full"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(font, Vector2(r.get_center().x - w / 2.0, r.position.y + 25.0), Txt.t("intake_full"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.red(dim, 2.0))
		# the share runs past every decimal it has
		var wild := "%.4f%%" % (99.9 + 0.0999 * fmod(t * 7.3, 1.0))
		var w2 := font.get_string_size(wild, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2(r.get_center().x - w2 / 2.0, r.position.y + 47.0), wild, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.foe(0.9 * dim, 1.6))
		return
	# the reserve share ticks up past 99.7 and never down
	var share := 99.7 + 0.05 * minf(held(), 6.0)
	draw_string(font, r.position + Vector2(10, 22), Txt.t("intake_count"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.foe(0.6 * dim))
	draw_string(font, r.position + Vector2(96, 24), "%.1f%%" % share, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.foe(0.95 * dim, 1.6))
	draw_string(font, r.position + Vector2(10, 46), Txt.t("intake_civil"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.45 * dim))
	draw_string(font, r.position + Vector2(96, 47), "%.1f%%" % (100.0 - share), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.6 * dim))
