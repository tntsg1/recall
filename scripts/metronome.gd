class_name Metronome
extends Node2D
# 情绪同步器 THE MOOD SYNCHRONISER (chapter 7; it was the Metronome): a great
# arm hung from the top of the room that sweeps across it in time with the
# music the bureau plays to keep everyone happy. A national happiness index
# over it ticks up with every beat; in its last phase it raises the music to
# 140 BPM, and the index goes past a hundred. The bob at its end is the core: it takes
# ×1.5 on the beat window and ×0.4 off it. The rod turns rounds away; the
# weights are what hurt.
# Phase 2 (66%): it swings every beat, and each downbeat sends a shock ring.
# Phase 3 (33%): a second arm rises from the floor, swinging against it.
# Shares the boss interface.

enum { OFF, ENTER, RUN, DYING, DEAD }

const HP := 700.0
const PIVOT := Vector2(960, 40)
const PIVOT2 := Vector2(960, 1040)
const LEN := 820.0
const LEN2 := 640.0
const BOB_R := 54.0
const AMP := 1.0
const ARM_W := 9.0

var game
var state := OFF
var t := 0.0
var hp := HP
var phase := 0
var guard_t := 0.0
var flash := 0.0
var red := 0.0
var core_open := 1.0
var enter_t := 0.0
var dying_t := 0.0
var arm_k := 0.0            # how far the arm has come down (entrance)
var arm2_k := 0.0
var theta := 0.0
var theta2 := 0.0
var bob := Vector2.ZERO
var bob_prev := Vector2.ZERO
var rings: Array = []       # shock rings [center, age]
var last_beat := -1
var fall_v := Vector2.ZERO
var joy := 97.0             # the happiness index on its screen
var fast_said := false


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_4"


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
	rings.clear()
	arm2_k = 0.0
	joy = 97.0
	fast_said = false
	game.sfx.play("horn", 0.9, -2.0)
	game.cam.add_trauma(0.3)
	game.hud.radio(Txt.t("radio_sync"))


func reset() -> void:
	if game and game.sfx.tempo != 1.0:
		game.sfx.set_tempo(1.0)
	state = OFF
	t = 0.0
	hp = HP
	phase = 0
	enter_t = 0.0
	arm_k = 0.0
	arm2_k = 0.0
	guard_t = 0.0
	rings.clear()


func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	damage(HP, false, bob, Vector2.UP)


func core_pos() -> Vector2:
	return bob


func core_vel() -> Vector2:
	return (bob - bob_prev) * 60.0


func on_beat_window() -> bool:
	return game.sfx.beat_frac() < 0.35


func _bob_of(pivot: Vector2, length: float, th: float, down: float) -> Vector2:
	return pivot + Vector2(sin(th), cos(th) * down) * length


# ---------------------------------------------------------------- bullets

func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	var d := b - a
	var hb := Geometry2D.segment_intersects_circle(a, b, bob, BOB_R)
	if hb >= 0.0:
		var p := a + d * hb
		return {"point": p, "normal": (p - bob).normalized(), "core": true, "mult": 1.5 if on_beat_window() else 0.4}
	for arm in _arms():
		var x = Geometry2D.segment_intersects_segment(a, b, arm[0], arm[1])
		if x != null:
			var along: Vector2 = (arm[1] - arm[0]).normalized()
			var n := along.orthogonal()
			if n.dot(a - (x as Vector2)) < 0.0:
				n = -n
			return {"point": x, "normal": n, "core": false, "car": 0}
	return {}


func _arms() -> Array:
	var out: Array = []
	if arm_k > 0.05:
		out.append([PIVOT, PIVOT.lerp(bob, 1.0 - BOB_R / LEN)])
	if arm2_k > 0.05:
		var b2 := _bob_of(PIVOT2, LEN2 * arm2_k, theta2, -1.0)
		out.append([PIVOT2, b2])
	return out


func on_armor(_k: int, at_p: Vector2, normal: Vector2) -> void:
	game.fx.sparks(at_p, normal, 5, Pal.foe(1.0, 1.9), 420.0, 0.2, 0.9)
	game.sfx.play("shield", randf_range(0.85, 1.0), -8.0)


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
	if on_beat_window():
		game.fx.ring(bob, BOB_R, BOB_R + 30.0, 0.25, Pal.foe(0.9, 1.8), 2.0)
	game.on_target_hit(ret)
	var want := clampi(int((1.0 - hp / HP) * 3.0), 0, 2)
	while phase < want:
		phase += 1
		guard_t = 1.4
		game.fx.ring(bob, BOB_R, 360.0, 0.6, Pal.foe(0.9, 1.5), 3.0)
		game.sfx.play("armor", 1.1, 0.0)
		game.add_hitstop(0.09)
		game.cam.add_trauma(0.6)
		game.cam.punch(0.04)
		game.hud.boss_phase()
		if phase == 2 and not fast_said:
			fast_said = true
			game.hud.radio(Txt.t("radio_sync_fast"))
	if hp <= 0.0:
		state = DYING
		dying_t = 0.0
		fall_v = core_vel() * 0.5
		game.on_boss_dying()


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	if enter_t > 0.0 and enter_t < 1.0 and state == OFF:
		enter_t = minf(1.0, enter_t + dt / 2.4)
		arm_k = Pal.ease_io(enter_t)
		theta = 0.0
		bob = _bob_of(PIVOT, LEN * arm_k, 0.0, 1.0)
	if state == OFF or state == DEAD:
		queue_redraw()
		return
	t += dt
	flash = maxf(0.0, flash - dt / 0.12)
	red = maxf(0.0, red - dt / 0.8)
	guard_t = maxf(0.0, guard_t - dt)
	bob_prev = bob
	var beat: float = game.sfx.beat()
	match state:
		ENTER:
			arm_k = 1.0
			if t >= 0.6:
				state = RUN
				t = 0.0
		DYING:
			_dying(dt)
			queue_redraw()
			return
	# the swing follows the music: one sweep per two beats, then one per beat
	var per := 2.0 if phase == 0 else 1.0
	var target := AMP * sin(PI * beat / per)
	theta = lerp_angle(theta, target, 1.0 - exp(-14.0 * dt))
	bob = _bob_of(PIVOT, LEN * arm_k, theta, 1.0)
	if phase >= 2:
		arm2_k = minf(1.0, arm2_k + dt / 1.2)
		theta2 = -target
		# 140 BPM of happiness
		var want_t: float = 140.0 / game.sfx.bpm()
		if game.sfx.tempo < want_t:
			game.sfx.set_tempo(minf(want_t, game.sfx.tempo + dt * 0.2))
	var bi := int(floor(beat))
	if bi != last_beat:
		last_beat = bi
		joy = minf(99.9 if phase < 2 else 140.0, joy + (0.1 if phase < 2 else 0.4))
		if state == RUN:
			game.fx.ring(bob, BOB_R * 0.6, BOB_R * 1.4, 0.3, Pal.foe(0.5, 1.4), 1.5)
			if phase >= 1 and bi % 4 == 0:
				rings.append([bob, 0.0])
				game.sfx.play("slam", 1.2, -6.0)
	var i := 0
	while i < rings.size():
		rings[i][1] += dt
		if rings[i][1] > 0.9:
			rings.remove_at(i)
		else:
			i += 1
	_contact()
	queue_redraw()


func _contact() -> void:
	var pl: Vector2 = game.player.pos
	if pl.distance_to(bob) < BOB_R + Player.R - 4.0:
		game.on_player_hit((pl - bob).normalized(), null)
		return
	# the rods only turn rounds away; the weights are what hurt
	if arm2_k > 0.5:
		var b2 := _bob_of(PIVOT2, LEN2 * arm2_k, theta2, -1.0)
		if pl.distance_to(b2) < 22.0 + Player.R - 4.0:
			game.on_player_hit((pl - b2).normalized(), null)
			return
	# a dash carries you through a shock ring
	if game.player.dash_t > 0.0:
		return
	for r in rings:
		var rad: float = Pal.ease_out(r[1] / 0.9) * 300.0
		if absf((r[0] as Vector2).distance_to(pl) - rad) < 12.0:
			game.on_player_hit((pl - r[0]).normalized(), null)
			return


func _dying(dt: float) -> void:
	dying_t += dt
	# the arm snaps; the bob falls and breaks
	fall_v += Vector2(0, 1400.0) * dt
	bob += fall_v * dt
	if dying_t >= 1.1:
		state = DEAD
		for k in 24:
			var a := TAU * k / 24.0
			var p0 := Vector2.from_angle(a) * BOB_R
			var p1 := Vector2.from_angle(a + 0.3) * BOB_R * 0.7
			game.fx.shard(bob + (p0 + p1) * 0.5, (p0 - p1) * 0.5, (p1 - p0) * 0.5, p0.normalized() * randf_range(300, 640), randf_range(-10, 10), 1.4, Pal.foe(1.0, 1.6), 2.5)
		game.on_boss_dead(bob)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if state == DEAD or (state == OFF and enter_t <= 0.0):
		return
	var open := on_beat_window() and state == RUN
	var beat_k := 1.0 - clampf(game.sfx.beat_frac() / 0.35, 0.0, 1.0)
	# the pivot and its gear
	draw_circle(PIVOT, 18.0, Pal.WALL)
	draw_arc(PIVOT, 18.0, 0.0, TAU, 24, Pal.foe(0.9 * dim), 2.0, false)
	for k in 6:
		var a := theta * 2.0 + TAU * k / 6.0
		draw_line(PIVOT + Vector2.from_angle(a) * 10.0, PIVOT + Vector2.from_angle(a) * 22.0, Pal.foe(0.5 * dim), 2.0)
	if state != DYING:
		for arm in _arms():
			var along: Vector2 = (arm[1] - arm[0]).normalized()
			var n := along.orthogonal() * ARM_W * 0.5
			var poly := PackedVector2Array([arm[0] + n, arm[1] + n, arm[1] - n, arm[0] - n])
			draw_colored_polygon(poly, Color(0.07, 0.07, 0.075))
			draw_polyline(PackedVector2Array([arm[0] + n, arm[1] + n, arm[1] - n, arm[0] - n, arm[0] + n]), Pal.foe(0.85 * dim), 1.5, false)
			# tick marks run down the arm like a scale
			for j in 12:
				var p: Vector2 = arm[0].lerp(arm[1], (j + 1) / 13.0)
				draw_line(p - n * 1.6, p + n * 1.6, Pal.foe(0.25 * dim), 1.0)
	if arm2_k > 0.05:
		var b2 := _bob_of(PIVOT2, LEN2 * arm2_k, theta2, -1.0)
		draw_circle(b2, 22.0, Pal.WALL)
		draw_arc(b2, 22.0, 0.0, TAU, 24, Pal.foe(0.8 * dim), 2.0, false)
	# the bob: shell plates part on the beat to show the core
	var col := Pal.foe(dim, 1.0 + 0.8 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	draw_circle(bob, BOB_R, Color(0.05, 0.05, 0.055))
	draw_arc(bob, BOB_R, 0.0, TAU, 40, col, 2.5, false)
	var core := 0.45 + 0.35 * beat_k if open else 0.3
	draw_circle(bob, BOB_R * core, Pal.foe(dim, 1.2 + 1.6 * beat_k * (1.0 if open else 0.0)).lerp(Pal.red(dim, 2.2), red * 0.8))
	for k in 4:
		var a := theta + TAU * k / 4.0 + PI / 4.0
		var gap := BOB_R * (0.35 + 0.25 * beat_k * (1.0 if open else 0.0))
		draw_arc(bob + Vector2.from_angle(a) * (gap - BOB_R * 0.35), BOB_R * 0.8, a - 0.55, a + 0.55, 10, Pal.foe(0.75 * dim), 3.0, false)
	for r in rings:
		var e := Pal.ease_out(r[1] / 0.9)
		draw_arc(r[0], e * 300.0, 0.0, TAU, 96, Pal.foe(0.9 * (1.0 - e) * dim, 1.4), 3.0, false)
	# its face: the shell smiles, whatever it does
	if state != DYING:
		var fd := Vector2.from_angle(theta + PI * 0.5)
		var fs := fd.orthogonal()
		var fc := bob + fd * BOB_R * 0.55
		draw_circle(fc - fs * 12.0 - fd * 8.0, 3.5, Pal.foe(dim, 2.0))
		draw_circle(fc + fs * 12.0 - fd * 8.0, 3.5, Pal.foe(dim, 2.0))
		var sm := PackedVector2Array()
		for j in 9:
			var u := lerpf(-1.0, 1.0, j / 8.0)
			sm.append(fc + fs * u * 18.0 + fd * (6.0 - 6.0 * u * u))
		draw_polyline(sm, Pal.foe(dim, 2.0), 2.5)
	_draw_index(dim)


# The national happiness index, over the pivot: it only goes up.
func _draw_index(dim: float) -> void:
	var font := Fonts.get_font("SemiBold")
	var r := Rect2(PIVOT + Vector2(-150, 74), Vector2(300, 64))
	draw_rect(r, Color(0.02, 0.025, 0.03))
	draw_rect(r, Pal.foe(0.55 * dim), false, 1.5)
	var fast := phase >= 2 and state == RUN
	var head: String = Txt.t("sync_index")
	draw_string(font, r.position + Vector2(12, 24), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.foe(0.7 * dim))
	var val := "%.1f%%" % joy
	var beat_k := 1.0 - clampf(game.sfx.beat_frac() / 0.25, 0.0, 1.0)
	var vc := Pal.red(dim, 2.2) if joy > 100.0 else Pal.foe(dim, 1.4 + 0.8 * beat_k)
	draw_string(font, r.position + Vector2(12, 54), val, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, vc)
	var bpm_t := "%d BPM" % int(round(game.sfx.bpm() * game.sfx.tempo))
	var bw := font.get_string_size(bpm_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(r.end.x - bw - 12.0, r.position.y + 52.0), bpm_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.red(dim, 2.0) if fast else Pal.foe(0.6 * dim))
