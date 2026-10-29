class_name ScanRings
extends Node2D
# The bureau of thought's floor (chapter 7): mood-scan rings set in the floor,
# lit in pairs that trade on every beat of the music. The beat a ring lights,
# whoever stands in it is "found to be unhappy" and struck (a dash goes
# through) — so you move on the beat. A round of yours that crosses a lit ring
# is made happy: its damage doubles, once a flight. Laying your lines across
# the rings pays.

const R := 92.0
const SPOTS := [Vector2(520, 600), Vector2(760, 330), Vector2(1400, 600), Vector2(1160, 330)]

var on := false
var spots: Array = SPOTS.duplicate()   # this room's rings (the hand-made room: SPOTS)
var last_beat := -1
var lit := [false, false, false, false]
var flash := [0.0, 0.0, 0.0, 0.0]
var t := 0.0
var game


func _init() -> void:
	z_index = 2
	z_as_relative = false
	# off until a chapter turns it on (the first chapter never calls setup)
	visible = false


func setup(story: int) -> void:
	on = story == 7
	spots = SPOTS.duplicate()
	last_beat = -1
	lit = [false, false, false, false]
	flash = [0.0, 0.0, 0.0, 0.0]
	visible = on
	queue_redraw()


# A generated room's rings (centres); they trade on the beat as ever.
func set_spots(list: Array) -> void:
	spots = list.duplicate()
	last_beat = -1
	lit.clear()
	flash.clear()
	for i in spots.size():
		lit.append(false)
		flash.append(0.0)
	visible = on and not spots.is_empty()
	queue_redraw()


func active() -> bool:
	return on


# which pair lights on beat b
func lit_on(i: int, b: int) -> bool:
	return (b + i) % 2 == 0


func step(dt: float) -> void:
	if not on:
		return
	t += dt
	for i in spots.size():
		flash[i] = maxf(0.0, flash[i] - dt / 0.3)
	var bi := int(floor(game.sfx.beat()))
	if bi != last_beat:
		last_beat = bi
		for i in spots.size():
			var now := lit_on(i, bi)
			if now and not lit[i]:
				flash[i] = 1.0
				_scan(i)
			lit[i] = now
	queue_redraw()


# the beat a ring lights: anyone standing in it is found unhappy
func _scan(i: int) -> void:
	if game.wave_ctl.phase != Waves.FIGHT:
		return
	var p: Vector2 = game.player.pos
	var c: Vector2 = spots[i]
	if p.distance_to(c) < R and game.player.dash_t <= 0.0:
		if game.on_player_hit((p - c).normalized() if p.distance_to(c) > 1.0 else Vector2.DOWN, null):
			game.fx.ring(c, R * 0.5, R * 1.3, 0.3, Pal.red(0.9, 2.4), 3.0)


# A round crossing a lit ring: doubled, once a flight.
func cross(a: Vector2, b: Vector2, bullet) -> bool:
	if bullet.hit.has("joy"):
		return false
	for i in spots.size():
		if not lit[i]:
			continue
		var c: Vector2 = spots[i]
		if a.distance_to(c) < R or Geometry2D.segment_intersects_circle(a, b, c, R) >= 0.0:
			bullet.hit["joy"] = true
			bullet.dmg *= 2.0
			flash[i] = maxf(flash[i], 0.8)
			game.fx.ring(a, 6.0, 26.0, 0.25, Pal.ink(0.8, 1.6), 1.5)
			game.sfx.play("lit", 1.5, -10.0)
			return true
	return false


func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if game.hud.intro_t >= 0.0:
		dim *= clampf((game.hud.intro_t - 2.2) / 0.6, 0.15, 1.0)
	# made happy: a round that crossed a lit ring flies with a halo and a smile
	for b in game.bullets.list:
		if b.hit.has("joy") and (b.state == Bullets.FLY or b.state == Bullets.RETURN):
			var p: Vector2 = b.pos
			draw_arc(p, 13.0, 0.0, TAU, 16, Pal.ink(0.7 * dim, 1.3), 1.5)
			draw_circle(p + Vector2(-4, -3), 1.5, Pal.ink(0.9 * dim, 1.3))
			draw_circle(p + Vector2(4, -3), 1.5, Pal.ink(0.9 * dim, 1.3))
			draw_arc(p + Vector2(0, 1), 6.0, PI * 0.15, PI * 0.85, 6, Pal.ink(0.9 * dim, 1.3), 1.5)
	var frac: float = game.sfx.beat_frac()
	var nb := last_beat + 1
	for i in spots.size():
		var c: Vector2 = spots[i]
		var is_lit: bool = lit[i]
		var next := lit_on(i, nb) and not is_lit
		# the floor ring itself: a double band with ticks round it
		draw_arc(c, R, 0.0, TAU, 64, Pal.ink(0.22 * dim), 2.0)
		draw_arc(c, R - 10.0, 0.0, TAU, 64, Pal.ink(0.1 * dim), 1.0)
		var ticks := PackedVector2Array()
		for j in 24:
			var a := TAU * j / 24.0 + t * 0.2
			ticks.append(c + Vector2.from_angle(a) * (R + 3.0))
			ticks.append(c + Vector2.from_angle(a) * (R + 9.0))
		draw_multiline(ticks, Pal.ink(0.18 * dim), 1.5)
		if is_lit:
			# lit: the scan is on — a filled disc, a bright rim, a sweep line
			# (in a generated room: a pale fill inside and a rim with no bloom
			# round it, so what stands beside it still reads)
			var calm: bool = game.arena.generated
			if calm:
				draw_circle(c, R, Color(Pal.INK.r, Pal.INK.g, Pal.INK.b, 0.016 * dim))   # (linear: about 13% on screen)
			draw_arc(c, R, 0.0, TAU, 64, Pal.foe((0.7 + 0.3 * flash[i]) * dim, (1.15 if calm else 1.8) + (0.3 if calm else 1.0) * flash[i]), 3.0)
			var sa := t * 5.0 + i
			draw_line(c, c + Vector2.from_angle(sa) * R, Pal.foe(0.6 * dim, 1.6), 2.0)
			draw_arc(c, R - 4.0, sa - 0.6, sa, 12, Pal.foe(0.35 * dim, 1.4), 6.0)
		elif next and (game.hud.intro_t < 0.0):
			# about to light: a ring closing in to the rim over the beat
			var k := Pal.ease_in(frac)
			draw_arc(c, R + 60.0 * (1.0 - k), 0.0, TAU, 64, Pal.red((0.2 + 0.6 * k) * dim, 1.6), 3.0 if game.arena.generated else 2.0)
		if flash[i] > 0.0:
			draw_arc(c, R + 14.0 * (1.0 - flash[i]), 0.0, TAU, 64, Pal.foe(flash[i] * dim, 1.3 if game.arena.generated else 2.4), 2.0)
