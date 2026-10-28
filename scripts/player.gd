class_name Player
extends Node2D
# A white disc with a notch toward the aim. The magazine is the ring of 24
# ticks around it; rounds that come home pop their tick back in.

const R := 13.0
const SPEED := 430.0
const DASH_SPEED := 1500.0
const DASH_TIME := 0.15
const DASH_CD := 0.55

var game
var pos := Vector2(960, 860)
var vel := Vector2.ZERO
var aim := Vector2.RIGHT
var recoil := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.RIGHT
var ghosts: Array = []   # [pos, age]
var ghost_cd := 0.0
var tick_pop := PackedFloat32Array()
var tick_red := PackedFloat32Array()
var shown := 24.0
var empty_pulse := 0.0
var focus_ring := 0.0
var invuln := 0.0
var stun := 0.0
var hurt_t := 0.0
var cracks: Array = []   # [from, to] in local space, shown while hurt
var gone := false


func _ready() -> void:
	z_index = 4
	z_as_relative = false
	tick_pop.resize(40)
	tick_red.resize(40)


func step(dt: float, real_dt: float, move: Vector2, aim_at: Vector2) -> void:
	var to_aim := aim_at - pos
	if to_aim.length() > 4.0:
		var want := to_aim.normalized()
		aim = Vector2.from_angle(lerp_angle(aim.angle(), want.angle(), 1.0 - exp(-30.0 * real_dt)))
	dash_cd -= dt
	invuln = maxf(0.0, invuln - dt)
	hurt_t = maxf(0.0, hurt_t - real_dt / 0.6)
	if stun > 0.0:
		stun -= dt
		vel = Pal.damp2(vel, Vector2.ZERO, 5.0, dt)
	elif dash_t > 0.0:
		dash_t -= dt
		vel = dash_dir * DASH_SPEED * lerpf(0.55, 1.0, clampf(dash_t / DASH_TIME, 0.0, 1.0))
		ghost_cd -= dt
		if ghost_cd <= 0.0:
			ghost_cd = 0.022
			ghosts.append([pos, 0.0])
		if dash_t <= 0.0:
			vel = dash_dir * SPEED
	else:
		var target := move.limit_length(1.0) * SPEED * (1.12 if game.has("lean") else 1.0) * (1.25 if game.wave_haste else 1.0)
		vel = Pal.damp2(vel, target, 16.0 if move != Vector2.ZERO else 12.0, dt)
	pos += vel * dt
	pos = game.arena.push_circle(pos, R)
	recoil = Pal.damp(recoil, 0.0, 18.0, dt)
	var i := 0
	while i < ghosts.size():
		ghosts[i][1] += dt
		if ghosts[i][1] > 0.28:
			ghosts.remove_at(i)
		else:
			i += 1
	for k in 40:
		tick_pop[k] = maxf(0.0, tick_pop[k] - real_dt / 0.3)
		tick_red[k] = maxf(0.0, tick_red[k] - real_dt / 0.45)
	shown = Pal.damp(shown, float(game.ammo), 20.0, real_dt)
	empty_pulse = maxf(0.0, empty_pulse - real_dt / 0.35)
	focus_ring += real_dt
	position = pos
	queue_redraw()


func try_dash(move: Vector2) -> bool:
	if dash_cd > 0.0 or dash_t > 0.0:
		return false
	dash_dir = move.normalized() if move.length() > 0.1 else aim
	dash_t = DASH_TIME * (1.4 if game.has("swift_feet") else 1.0)
	dash_cd = DASH_CD * (0.6 if game.has("lightstep") else 1.0)
	ghost_cd = 0.0
	return true


func hurt(dir: Vector2) -> void:
	invuln = 0.8
	stun = 0.16
	hurt_t = 1.0
	dash_t = 0.0
	vel = dir * 760.0
	cracks.clear()
	for k in 4:
		var a := randf() * TAU
		var p0 := Vector2.from_angle(a) * R * 0.15
		var p1 := Vector2.from_angle(a + randf_range(-0.4, 0.4)) * R * 0.6
		var p2 := Vector2.from_angle(a + randf_range(-0.5, 0.5)) * R * 1.05
		cracks.append([p0, p1, p2])
	for k in 40:
		tick_pop[k] = 1.0


# The run is over: the disc breaks into its own rim.
func shatter() -> void:
	gone = true
	for k in 8:
		var a := TAU * k / 8.0
		var p0 := Vector2.from_angle(a) * R
		var p1 := Vector2.from_angle(a + TAU / 8.0) * R
		var mid := (p0 + p1) * 0.5
		game.fx.shard(pos + mid, p0 - mid, p1 - mid, mid.normalized() * randf_range(160, 320), randf_range(-8, 8), 1.6, Pal.you(1.0, 1.6), 2.5)
	game.fx.ring(pos, 6.0, 260.0, 0.9, Pal.you(1.0, 1.6), 3.0)
	game.fx.flash(pos, 160.0, 0.5, Pal.you(0.6, 1.4))


func kick() -> void:
	recoil = 1.0


func pop_tick(index: int, red: bool) -> void:
	if index < 0 or index >= 40:
		return
	tick_pop[index] = 1.0
	if red:
		tick_red[index] = 1.0


func muzzle() -> Vector2:
	return pos + aim * (R + 9.0)


func _draw() -> void:
	if gone:
		return
	# a dark pool under you, so your own rounds' light never swallows you
	draw_texture_rect(Fx.make_glow_texture(), Rect2(-Vector2(46, 46), Vector2(92, 92)), false, Color(0, 0, 0, 0.7))
	var f: float = game.focus
	for g in ghosts:
		var k: float = 1.0 - g[1] / 0.28
		draw_arc(g[0] - pos, R * (0.8 + 0.2 * k), 0.0, TAU, 28, Pal.you(0.32 * k * k), 1.5, false)
	var speed := vel.length()
	var stretch := clampf(speed / DASH_SPEED, 0.0, 1.0) * 0.45 + clampf(speed / SPEED, 0.0, 1.0) * 0.06
	var vdir := vel.normalized() if speed > 1.0 else aim
	var body_off := -aim * recoil * 4.0
	# while invulnerable the body breathes in and out of view
	var vis := 1.0
	if invuln > 0.0:
		vis = 0.45 + 0.55 * (0.5 + 0.5 * cos(invuln * 34.0))
	draw_set_transform(body_off, vdir.angle(), Vector2(1.0 + stretch, 1.0 - stretch * 0.6))
	draw_circle(Vector2.ZERO, R, Pal.you(vis, 1.15 + 0.8 * hurt_t))
	if hurt_t > 0.0:
		for c in cracks:
			draw_polyline(PackedVector2Array([c[0], c[1], c[2]]), Color(Pal.BG, hurt_t), 1.6, false)
	draw_set_transform(body_off, aim.angle(), Vector2.ONE)
	# the notch: a dark bite out of the rim facing the aim
	var notch := PackedVector2Array([Vector2(R + 1.0, -5.0), Vector2(R * 0.38, 0.0), Vector2(R + 1.0, 5.0)])
	draw_colored_polygon(notch, Pal.BG)
	draw_line(Vector2(R + 5.0, 0), Vector2(R + 11.0 - recoil * 3.0, 0), Pal.you(0.55), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# magazine ring
	var full := int(round(shown))
	var n: int = game.mag
	for k in n:
		var a := -PI / 2.0 + TAU * k / n
		var pop := Pal.ease_out(tick_pop[k])
		var r0 := 22.0 + pop * 3.0
		var tl := 4.0 + pop * 3.0
		var on := k < full
		var c := Pal.you(0.62 if on else 0.1)
		if tick_red[k] > 0.0:
			c = c.lerp(Pal.red(1.0, 3.0), tick_red[k])
		if empty_pulse > 0.0 and not on:
			c = c.lerp(Pal.you(0.6), empty_pulse)
		var d := Vector2.from_angle(a)
		draw_line(d * r0, d * (r0 + tl), c, 1.6 + pop)
	if game.focusing or f > 0.02:
		var ph := fmod(focus_ring * 1.4, 1.0)
		draw_arc(Vector2.ZERO, lerpf(30.0, 64.0, Pal.ease_out(ph)), 0.0, TAU, 48, Pal.red(0.5 * f * (1.0 - ph), 2.0), 1.4, false)
