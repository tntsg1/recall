class_name Stasis
extends Node2D
# The anomalous physics institute's floor (chapter 11): stasis fields. Two
# pairs of field rings take turns; each warns, then holds time still for a
# few seconds. A round flying into a held field stops dead in mid-air — an
# anchor in the open floor: recall it and it flies its line back from there.
# When the field lets go, the rounds it held fly on as they were going.
# Bodies inside move slowly (a dash still carries you through).

const FIELDS := [Vector2(500, 560), Vector2(1420, 560), Vector2(960, 300), Vector2(960, 830)]
const PAIR := [0, 0, 1, 1]
const R := 118.0
const WARN := 1.0
const ON := 4.2
const PERIOD := 12.0          # both pairs' turns: each warns, holds, then rests
const SLOW := 0.42            # bodies inside move at this much of their speed
const INSET := 22.0           # a caught round stops this far inside the rim

var on := false
var game
var t := 0.0
var clock := 0.0
var held: Array = [0.0, 0.0, 0.0, 0.0]   # 0..1 how fully each field holds (eased)
var caught_n: Array = [0, 0, 0, 0]
var motes: Array = []                    # [field, offset, phase]


func _init() -> void:
	z_index = 1
	z_as_relative = false


func setup(story: int) -> void:
	on = story == 11
	visible = on
	t = 0.0
	clock = PERIOD * 0.5 - 0.6     # both resting; the far pair warns soon after the fight starts
	held = [0.0, 0.0, 0.0, 0.0]
	caught_n = [0, 0, 0, 0]
	motes.clear()
	if on:
		for k in FIELDS.size():
			for j in 14:
				motes.append([k, Vector2.from_angle(randf() * TAU) * sqrt(randf()) * (R - 12.0), randf() * TAU])
	queue_redraw()


func active() -> bool:
	return on


# Where a pair is in its turn: -1 resting, 0..WARN warning, then holding.
func _pair_t(p: int) -> float:
	var c := fmod(clock - p * PERIOD * 0.5 + PERIOD, PERIOD)
	return c if c < WARN + ON else -1.0


func warn_k(k: int) -> float:
	var pt := _pair_t(PAIR[k])
	return clampf(pt / WARN, 0.0, 1.0) if pt >= 0.0 and pt < WARN else 0.0


func is_on(k: int) -> bool:
	var pt := _pair_t(PAIR[k])
	return pt >= WARN


# Seconds left on a holding field (0 when not holding).
func left(k: int) -> float:
	var pt := _pair_t(PAIR[k])
	return WARN + ON - pt if pt >= WARN else 0.0


# How much of its speed a body at p keeps.
func slow_at(p: Vector2) -> float:
	if not on:
		return 1.0
	var s := 1.0
	for k in FIELDS.size():
		if held[k] <= 0.0:
			continue
		var d: float = p.distance_to(FIELDS[k])
		if d < R:
			s = minf(s, lerpf(1.0, SLOW, held[k] * clampf((R - d) / 24.0, 0.0, 1.0)))
	return s


# A round in flight from a to b: the first held field it flies into, or {}.
func catch(a: Vector2, b: Vector2) -> Dictionary:
	var best := {}
	var bt := 2.0
	for k in FIELDS.size():
		if not is_on(k):
			continue
		var c: Vector2 = FIELDS[k]
		if a.distance_to(c) <= R:
			continue        # fired from inside: it flies out
		var ht := Geometry2D.segment_intersects_circle(a, b, c, R)
		if ht >= 0.0 and ht < bt:
			bt = ht
			var d := (b - a).normalized()
			var at := a + (b - a) * ht + d * INSET
			best = {"point": at, "k": k}
	return best


func on_catch(b, k: int) -> void:
	caught_n[k] += 1
	game.fx.ring(b.pos, 4.0, 22.0, 0.3, Pal.ink(0.8, 1.8), 1.5)
	game.fx.flash(b.pos, 16.0, 0.1, Pal.ink(0.6, 1.6))
	game.sfx.play("embed", randf_range(1.7, 1.9), -14.0)


func step(dt: float) -> void:
	if not on:
		return
	t += dt
	var fighting: bool = game.wave_ctl.phase == Waves.FIGHT and game.hud.intro_t < 0.0
	var was: Array = []
	for k in FIELDS.size():
		was.append(is_on(k))
	var wwarn: Array = []
	for k in FIELDS.size():
		wwarn.append(warn_k(k) > 0.0)
	if fighting:
		clock += dt
	for k in FIELDS.size():
		var now := is_on(k)
		held[k] = minf(1.0, held[k] + dt / 0.18) if now else maxf(0.0, held[k] - dt / 0.25)
		if warn_k(k) > 0.0 and not wwarn[k] and k % 2 == 0:
			game.sfx.play("windup", 0.62, -9.0)
		if now and not was[k]:
			caught_n[k] = 0
			game.fx.ring(FIELDS[k], R, R + 30.0, 0.35, Pal.ink(0.7, 1.6), 2.0)
			if k % 2 == 0:
				game.sfx.play("focus", 0.55, -8.0)
		if was[k] and not now:
			_release(k)
	# rounds that left a field some other way (recalled, moved) forget it
	for b in game.bullets.list:
		if b.stasis >= 0 and b.state != Bullets.EMBED:
			b.stasis = -1
	queue_redraw()


# The field lets go: what it held flies on.
func _release(k: int) -> void:
	var n := 0
	for b in game.bullets.list:
		if b.state == Bullets.EMBED and b.stasis == k:
			b.stasis = -1
			b.state = Bullets.FLY
			b.t = 0.0
			b.settled = false
			b.light = 0.0
			b.light_delay = -1.0
			n += 1
			game.fx.sparks(b.pos, -b.dir, 2, Pal.ink(0.8, 1.6), 200.0, 0.12, 0.6)
	if n > 0:
		game.bullets.faint_dirty = true
	game.fx.ring(FIELDS[k], R * 0.4, R + 10.0, 0.3, Pal.ink(0.5, 1.4), 1.5)
	if k % 2 == 0:
		game.sfx.play("release", 1.3, -8.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not on:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if game.hud.intro_t >= 0.0:
		dim *= clampf((game.hud.intro_t - 2.2) / 0.6, 0.25, 1.0)
	for k in FIELDS.size():
		_draw_field(k, dim)
	# rounds held in mid-air: a small still frame round each
	for b in game.bullets.list:
		if b.state == Bullets.EMBED and b.stasis >= 0:
			var p: Vector2 = b.pos
			draw_arc(p, 9.0, 0.0, TAU, 14, Pal.ink(0.55 * dim, 1.4), 1.2)
			for j in 4:
				var d := Vector2.from_angle(PI * 0.25 + j * PI * 0.5)
				draw_line(p + d * 11.0, p + d * 15.0, Pal.ink(0.45 * dim, 1.3), 1.2)


# A field: a ring of emitter posts set in the floor and a floor stencil; on
# warning the posts light in turn and ticks close in on the rim; held, the
# disc goes still and pale, its motes stop, and a rim arc counts down what
# is left of the hold.
func _draw_field(k: int, dim: float) -> void:
	var c: Vector2 = FIELDS[k]
	var hk: float = held[k]
	var wk := warn_k(k)
	# the floor ring and its posts
	draw_arc(c, R, 0.0, TAU, 72, Pal.ink((0.16 + 0.1 * wk) * dim), 1.0)
	draw_arc(c, R + 8.0, 0.0, TAU, 72, Pal.ink(0.08 * dim), 1.0)
	for j in 6:
		var a := TAU * j / 6.0 + PI / 6.0
		var q := c + Vector2.from_angle(a) * (R + 8.0)
		var lit := hk > 0.0 or (wk > 0.0 and wk * 6.0 > j)
		draw_rect(Rect2(q - Vector2(5, 5), Vector2(10, 10)), Color(0.05, 0.05, 0.055))
		draw_rect(Rect2(q - Vector2(5, 5), Vector2(10, 10)), Pal.ink((0.75 if lit else 0.3) * dim, 1.6 if lit else 1.0), false, 1.5)
		if lit:
			draw_circle(q, 2.0, Pal.ink(0.9 * dim, 2.0))
	# the stencil on the floor below it
	var font := Fonts.get_font("SemiBold")
	var lab := Txt.t("stasis_tag")
	var fs := 12
	var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# (the lowest field has it above, clear of the floor's own lettering)
	var sy := R + 32.0 if c.y < 700.0 else -R - 24.0
	draw_string(font, c + Vector2(-lw * 0.5, sy), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.3 * dim))
	if wk > 0.0:
		# warning: ticks closing on the rim, the rim flickering
		var fl := 0.55 + 0.45 * sin(t * 26.0)
		for j in 24:
			var d := Vector2.from_angle(TAU * j / 24.0 + t * 0.6)
			var r0 := R + 46.0 * (1.0 - wk)
			draw_line(c + d * r0, c + d * (r0 + 9.0), Pal.ink(0.7 * wk * dim, 1.5), 1.5)
		draw_arc(c, R, 0.0, TAU, 72, Pal.ink((0.25 + 0.5 * wk) * fl * dim, 1.6), 2.0)
	if hk > 0.0:
		# held: a pale still disc, rings frozen part-way out, motes stopped
		draw_circle(c, R, Color(0.7, 0.72, 0.75, 0.028 * hk * dim))
		for j in 3:
			draw_arc(c, R * (0.3 + 0.22 * j), 0.0, TAU, 48, Pal.ink(0.12 * hk * dim), 1.0)
		# about to let go: the whole ring flickers in its last half second
		var ending := left(k) < 0.5 and left(k) > 0.0
		var efl := (0.35 + 0.65 * absf(sin(t * 28.0))) if ending else 1.0
		draw_arc(c, R, 0.0, TAU, 72, Pal.ink(0.8 * hk * efl * dim, 1.8 + (0.6 if ending else 0.0)), 2.5 + (1.5 if ending else 0.0))
		# what is left of the hold, as an arc just outside the rim
		var lk := clampf(left(k) / ON, 0.0, 1.0)
		var red := lk < 0.25
		var col := Pal.red(0.9 * hk * dim, 2.0) if red else Pal.ink(0.7 * hk * dim, 1.6)
		draw_arc(c, R + 15.0, -PI * 0.5, -PI * 0.5 + TAU * lk, 64, col, 3.0)
		# a frozen clock face at the centre: its hand stopped
		draw_arc(c, 14.0, 0.0, TAU, 20, Pal.ink(0.4 * hk * dim), 1.2)
		draw_line(c, c + Vector2.from_angle(-PI * 0.5 + k * 1.3) * 11.0, Pal.ink(0.6 * hk * dim, 1.4), 1.5)
	# motes drifting through the ring; still while it holds
	var pts := PackedVector2Array()
	for m in motes:
		if m[0] != k:
			continue
		var off: Vector2 = m[1]
		var drift := Vector2(sin(t * 0.7 + m[2]), cos(t * 0.53 + m[2] * 1.3)) * 10.0 * (1.0 - hk)
		var q: Vector2 = c + off + drift
		pts.append(q)
		pts.append(q + Vector2(1.5, 0))
	if pts.size() > 0:
		draw_multiline(pts, Pal.ink((0.25 + 0.4 * hk) * dim, 1.2), 1.5)
