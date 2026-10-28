class_name Possess
extends Node2D
# Seizing a shell (the move that came over from NEON RAID). A returning round that
# pierces an enemy leaves a cyan mark on it for a few seconds; E sends your mind
# into the nearest marked one. For five seconds you ARE that machine: it turns
# into neon pixels, grows crystal spikes, and its weak little attack becomes a
# three-stage combo. Q still recalls — the rounds come home to the shell. When
# the time runs out (or E again) the shell detonates and you step out of the
# blast, briefly untouchable. A broken shell costs you nothing.

enum { IDLE, FLOW, HOST }

const MARK_TIME := 3.0
const DURATION := 5.0
const COOLDOWN := 8.0
const RANGE := 680.0
const FLOW_TIME := 0.16
const SHELL_HITS := 3
const PX := 2.0                 # one effect pixel = two world units
const BODY_PX := 3.0            # the seized body is drawn chunkier: one sprite pixel = three units
const KINDS := [Enemies.CHASER, Enemies.LEECH]   # N1: these two can be seized
const BLAST_R := 120.0
const BLAST_DMG := 40.0
# chaser: drill dash ×2, then the spiral
const DRILL_SPEED := 1500.0
const DRILL_TIME := 0.17
const DRILL_DMG := [45.0, 55.0]
const SPIN_TIME := 0.55
const SPIN_R := 105.0
const SPIN_TICK_DMG := 16.0
const SPIN_BURST_R := 165.0
const SPIN_BURST_DMG := 75.0
const WAKE_DMG := 22.0
# leech: hold to pull, keep holding to crush, let go to detonate
const WELL_REACH := 320.0
const WELL_R := 260.0
const SQUEEZE_AT := 0.5
const SQUEEZE_DMG := 14.0
const WELL_MAX := 1.4
const WELL_BURST_R := 175.0
const WELL_BURST_DMG := 85.0

var game
var state := IDLE
var shell = null                # Enemies.E while seized
var t_left := 0.0
var cooldown := 0.0
var flow_t := 0.0
var flow_from := Vector2.ZERO
var marks := {}                 # enemy id -> [E, time left]
var hinted := false
var grow := 0.0
var hits_left := SHELL_HITS
var iframes := 0.0
var combo := 0
var vel := Vector2.ZERO
var aim := Vector2.RIGHT
var t := 0.0
var tick_cd := 0.0
var fire_prev := false
var ghosts: Array = []          # [pos, age, angle]
var ghost_cd := 0.0
var wakes: Array = []           # [pos, vel, age, hit]
var bursts: Array = []          # [pos, radius, age] — pixel shock rings
# chaser
var stage := 0
var stage_window := 0.0
var queued := false
var dash_t := 0.0
var dash_dir := Vector2.RIGHT
var dash_hit := {}
var spin_t := -1.0
var spin_tick := 0.0
var recover := 0.0
# leech
var well_on := false
var well_t := 0.0
var well_pos := Vector2.ZERO
var squeeze_tick := 0.0

var _parts := {}


func _ready() -> void:
	z_index = 5
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for n in ["chaser", "chaser_spk1", "chaser_spk2", "leech", "leech_spk1", "leech_spk2"]:
		_parts[n] = PixelPart.get_part("res://assets/sprites/shell/" + n)


static func cyan(a: float = 1.0, k: float = 1.0) -> Color:
	if Pal.ldr:
		a = pow(clampf(a, 0.0, 1.0), Pal.LDR_ALPHA)
	var c := Color(0.17, 0.77, 0.84)
	if k <= 1.0:
		return Color(c.r * k, c.g * k, c.b * k, a)
	# above 1 the light goes mostly into green and blue, so the glow stays cyan
	return Color(c.r * (1.0 + (k - 1.0) * 0.4), c.g * k, c.b * k, a)


func hosting() -> bool:
	return state == HOST


func busy() -> bool:
	return state != IDLE


# ---------------------------------------------------------------- marks

func mark(e) -> void:
	if e.state != Enemies.ALIVE or not KINDS.has(e.kind):
		return
	var fresh := not marks.has(e.id)
	marks[e.id] = [e, MARK_TIME]
	if fresh:
		game.fx.ring(e.pos, e.r, e.r + 22.0, 0.3, cyan(0.9, 2.0), 2.0)
		if not hinted and game.bot == null:
			hinted = true
			game.hud.flash_text(Txt.t("possess_hint"))


func target():
	var best = null
	var bd := RANGE
	for id in marks:
		var e = marks[id][0]
		if e.state != Enemies.ALIVE:
			continue
		var d: float = e.pos.distance_to(game.player.pos)
		if d < bd:
			bd = d
			best = e
	return best


# E: in, or (while seized) out early.
func press() -> void:
	if state == HOST:
		end(false)
		return
	if state != IDLE:
		return
	var e = target()
	if cooldown > 0.0 or e == null:
		game.player.empty_pulse = 1.0
		game.sfx.play("empty", 1.25, -8.0)
		return
	state = FLOW
	flow_t = 0.0
	flow_from = game.player.pos
	shell = e
	marks.erase(e.id)
	game.cine_k = 0.75
	game.cine_t = 0.0
	game.sfx.play("p_possess", 1.0, -2.0)
	game.fx.flash(flow_from, 60.0, 0.18, cyan(0.6, 2.2))
	game.fx.ring(flow_from, 10.0, 70.0, 0.3, cyan(0.9, 2.2), 2.0)
	game.player.visible = false


func _begin_host() -> void:
	if shell == null or shell.state != Enemies.ALIVE:
		# it died while the mind was in flight: land back in the body
		_restore(game.player.pos)
		return
	state = HOST
	shell.state = Enemies.HOST
	shell.knock = Vector2.ZERO
	shell.vel = Vector2.ZERO
	shell.burn = 0.0
	if shell.grip != null:
		# a seized leech lets go of everything it stole: the rounds fly home to you
		for b in game.bullets.held_by(shell.grip):
			game.bullets.send_home(b)
	vel = Vector2.ZERO
	aim = Vector2.from_angle(shell.rot)
	t_left = DURATION
	hits_left = SHELL_HITS
	iframes = 0.35
	grow = 0.0
	combo = 0
	stage = 0
	stage_window = 0.0
	queued = false
	dash_t = 0.0
	spin_t = -1.0
	recover = 0.0
	well_on = false
	fire_prev = true          # the E press must not also count as a click
	game.player.pos = shell.pos
	game.player.position = shell.pos
	game.sfx.play("p_grow", 1.0, -3.0)
	game.fx.ring(shell.pos, 12.0, 150.0, 0.45, cyan(1.0, 2.4), 3.0)
	game.fx.flash(shell.pos, 90.0, 0.25, cyan(0.5, 2.0))
	game.fx.sparks(shell.pos, Vector2.UP, 18, cyan(1.0, 2.4), 520.0, 0.35, PI)
	game.cam.add_trauma(0.3)
	game.cam.punch(0.03)
	game.post.shock(game.screen_uv(shell.pos), 0.8, 1.6)
	bursts.append([shell.pos, 150.0, 0.0])
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE and e.pos.distance_to(shell.pos) < 150.0:
			e.knock += (e.pos - shell.pos).normalized() * 420.0


# Time up, E, broken, or the wave is over: the shell goes off and you step out.
func end(broken: bool, quiet: bool = false) -> void:
	if state != HOST:
		return
	var at: Vector2 = shell.pos
	if not quiet:
		for e in game.enemies.list:
			if e.state == Enemies.ALIVE and e.pos.distance_to(at) < BLAST_R + e.r:
				_deal(e, BLAST_DMG, (e.pos - at).normalized(), true)
		game.sfx.play("p_blast", 1.0, -1.0)
		game.cam.add_trauma(0.45)
		game.cam.punch(0.04)
		game.post.shock(game.screen_uv(at), 1.1, 1.8)
		game.post.pulse(0.006)
		game.add_hitstop(0.06)
		bursts.append([at, BLAST_R, 0.0])
		game.fx.ring(at, 10.0, BLAST_R + 20.0, 0.4, cyan(1.0, 2.6), 3.0)
		game.fx.flash(at, BLAST_R, 0.25, cyan(0.55, 2.0))
	_shatter(at, broken)
	_restore(at)
	game.player.invuln = 1.0
	cooldown = COOLDOWN
	if combo > 0:
		game.hud.combo_end()


func _restore(at: Vector2) -> void:
	state = IDLE
	shell = null
	well_on = false
	spin_t = -1.0
	dash_t = 0.0
	game.player.pos = at
	game.player.vel = Vector2.ZERO
	game.player.position = at
	game.player.visible = true


func _shatter(at: Vector2, broken: bool) -> void:
	shell.state = Enemies.DEAD
	if shell.grip != null:
		shell.grip.alive = false
	game.on_target_die(at, shell.kind)
	for k in 10:
		var a := TAU * k / 10.0 + randf() * 0.3
		var d := Vector2.from_angle(a)
		var p0 := d.orthogonal() * randf_range(4.0, 8.0)
		game.fx.shard(at + d * 8.0, p0, -p0, d * randf_range(260, 460), randf_range(-10, 10), randf_range(0.6, 0.9), cyan(1.0, 2.2 if broken else 1.8), 3.0)
	game.fx.sparks(at, Vector2.UP, 24, cyan(1.0, 2.4), 760.0, 0.42, PI)


# A hit meant for you lands on the shell instead. Returns true when it counted.
func shell_hit(dir: Vector2) -> bool:
	if state != HOST:
		return false
	if iframes > 0.0 or game.wave_ctl.phase != Waves.FIGHT or game.dev_god or spin_t >= 0.0:
		return false
	hits_left -= 1
	iframes = 0.6
	shell.flash = 1.0
	vel = dir * 520.0
	game.sfx.play("hurt", 1.25, -3.0)
	game.cam.add_trauma(0.35)
	game.cam.kick(dir, 4.0)
	game.post.hurt(0.5)
	game.fx.sparks(shell.pos, dir, 10, cyan(1.0, 2.0), 520.0, 0.3, 1.2)
	if hits_left <= 0:
		end(true)
	return true


# ---------------------------------------------------------------- update

func step(sdt: float, dt: float) -> void:
	t += dt
	for id in marks.keys():
		var m: Array = marks[id]
		m[1] -= sdt
		if m[1] <= 0.0 or m[0].state != Enemies.ALIVE:
			marks.erase(id)
	if state == IDLE:
		cooldown = maxf(0.0, cooldown - sdt)
	elif state == FLOW:
		flow_t += dt
		if flow_t >= FLOW_TIME:
			_begin_host()
	if state == HOST and game.wave_ctl.phase != Waves.FIGHT:
		end(false, true)
	_step_wakes(sdt)
	var i := 0
	while i < ghosts.size():
		ghosts[i][1] += dt
		if ghosts[i][1] > 0.3:
			ghosts.remove_at(i)
		else:
			i += 1
	i = 0
	while i < bursts.size():
		bursts[i][2] += dt
		if bursts[i][2] > 0.4:
			bursts.remove_at(i)
		else:
			i += 1
	queue_redraw()


func host_step(sdt: float, dt: float, move: Vector2, aim_at: Vector2, fire_held: bool) -> void:
	if state != HOST:
		return
	if shell.state != Enemies.HOST:
		_restore(shell.pos)
		return
	t_left -= sdt
	iframes = maxf(0.0, iframes - sdt)
	recover = maxf(0.0, recover - sdt)
	grow = minf(1.0, grow + dt / 0.35)
	shell.flash = maxf(0.0, shell.flash - dt / 0.12)
	shell.t += sdt
	var to_aim: Vector2 = aim_at - shell.pos
	if to_aim.length() > 4.0:
		aim = to_aim.normalized()
	var pressed := fire_held and not fire_prev
	fire_prev = fire_held
	var r: float = shell.r * 1.3
	var before: Vector2 = shell.pos
	match shell.kind:
		Enemies.CHASER:
			_chaser(sdt, pressed, move)
		Enemies.LEECH:
			_leech(sdt, fire_held, move, aim_at)
	shell.pos = game.arena.push_circle(shell.pos, r)
	shell.pos = shell.pos.clamp(Arena.ROOM.position + Vector2(r, r), Arena.ROOM.end - Vector2(r, r))
	if dash_t > 0.0:
		_drill_sweep(before, shell.pos)
	# shoulder anything in the way aside
	for e in game.enemies.list:
		if e.state != Enemies.ALIVE:
			continue
		var d: Vector2 = e.pos - shell.pos
		var rr: float = e.r + r + 2.0
		if d.length() < rr and d.length() > 0.01:
			e.knock += d.normalized() * 900.0 * sdt * 4.0
	game.player.pos = shell.pos
	game.player.position = shell.pos
	game.player.vel = vel
	game.player.aim = aim
	# the last 1.5 s: the shell ticks like a fuse
	if t_left < 1.5:
		tick_cd -= dt
		if tick_cd <= 0.0:
			tick_cd = lerpf(0.12, 0.34, t_left / 1.5)
			game.sfx.play("tick", 1.4 + (1.5 - t_left) * 0.3, -6.0)
	if t_left <= 0.0:
		end(false)


func _move(sdt: float, move: Vector2, speed: float, rate: float) -> void:
	vel = Pal.damp2(vel, move.limit_length(1.0) * speed, rate, sdt)
	shell.pos += vel * sdt


# ---------------------------------------------------------------- chaser

func _chaser(sdt: float, pressed: bool, move: Vector2) -> void:
	if pressed:
		queued = true
	stage_window -= sdt
	if stage_window <= 0.0 and dash_t <= 0.0 and spin_t < 0.0 and stage < 3:
		stage = 0
	if queued and dash_t <= 0.0 and spin_t < 0.0 and recover <= 0.0:
		queued = false
		if stage >= 2:
			_start_spin()
		else:
			_start_dash()
	if dash_t > 0.0:
		dash_t -= sdt
		var k := clampf(dash_t / DRILL_TIME, 0.0, 1.0)
		vel = dash_dir * DRILL_SPEED * lerpf(0.55, 1.0, k)
		shell.pos += vel * sdt
		shell.rot = dash_dir.angle()
		ghost_cd -= sdt
		if ghost_cd <= 0.0:
			ghost_cd = 0.018
			ghosts.append([shell.pos, 0.0, shell.rot])
		if dash_t <= 0.0:
			vel = dash_dir * 320.0
			stage_window = 0.5
	elif spin_t >= 0.0:
		spin_t += sdt
		shell.rot += 38.0 * sdt
		_move(sdt, move, 160.0, 8.0)
		spin_tick -= sdt
		if spin_tick <= 0.0:
			spin_tick = 0.07
			for e in game.enemies.list:
				if e.state == Enemies.ALIVE and e.pos.distance_to(shell.pos) < SPIN_R + e.r:
					var d: Vector2 = (e.pos - shell.pos).normalized()
					_deal(e, SPIN_TICK_DMG, d.orthogonal(), false)
					e.knock += -d * 260.0
			game.fx.sparks(shell.pos, Vector2.from_angle(shell.rot), 3, cyan(1.0, 2.4), 620.0, 0.2, 0.4)
			game.cam.add_trauma(0.06)
		if spin_t >= SPIN_TIME:
			_spin_burst()
	else:
		_move(sdt, move, 520.0, 14.0)
		if vel.length() > 20.0:
			shell.rot = lerp_angle(shell.rot, vel.angle(), 1.0 - exp(-12.0 * sdt))


func _start_dash() -> void:
	stage += 1
	dash_dir = aim
	dash_t = DRILL_TIME
	dash_hit.clear()
	ghost_cd = 0.0
	game.sfx.play("dash", 1.25 + stage * 0.1, -4.0)
	game.cam.kick(-dash_dir, 2.0)
	game.fx.ring(shell.pos, 8.0, 40.0, 0.2, cyan(0.8, 2.0), 1.5)


func _drill_sweep(a: Vector2, b: Vector2) -> void:
	var dmg: float = DRILL_DMG[clampi(stage - 1, 0, 1)]
	for e in game.enemies.list:
		if e.state != Enemies.ALIVE or dash_hit.has(e.id):
			continue
		var q := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
		if q.distance_to(e.pos) <= e.r + shell.r * 1.3 + 6.0:
			dash_hit[e.id] = true
			_deal(e, dmg, dash_dir, true)
			game.sfx.play("p_drill", randf_range(1.05, 1.2), -4.0)


func _start_spin() -> void:
	stage = 3
	spin_t = 0.0
	spin_tick = 0.0
	game.sfx.play("p_well", 1.4, -4.0)
	game.fx.ring(shell.pos, 10.0, SPIN_R, 0.3, cyan(1.0, 2.2), 2.0)


func _spin_burst() -> void:
	spin_t = -1.0
	stage = 0
	recover = 0.3
	var at: Vector2 = shell.pos
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE and e.pos.distance_to(at) < SPIN_BURST_R + e.r:
			var d: Vector2 = (e.pos - at).normalized()
			_deal(e, SPIN_BURST_DMG, d, true)
			e.knock += d * 620.0
	_finisher(at, SPIN_BURST_R)


# ---------------------------------------------------------------- leech

func _leech(sdt: float, fire_held: bool, move: Vector2, aim_at: Vector2) -> void:
	_move(sdt, move, 400.0 if not well_on else 200.0, 12.0)
	shell.rot += (2.0 + (6.0 if well_on else 0.0)) * sdt
	if fire_held and not well_on and recover <= 0.0:
		well_on = true
		well_t = 0.0
		squeeze_tick = 0.0
		well_pos = shell.pos + (aim_at - shell.pos).limit_length(WELL_REACH)
		game.sfx.play("p_well", 1.0, -3.0)
		game.fx.ring(well_pos, WELL_R, 20.0, 0.35, cyan(0.8, 2.0), 2.0)
	if not well_on:
		return
	well_t += sdt
	well_pos = Pal.damp2(well_pos, shell.pos + (aim_at - shell.pos).limit_length(WELL_REACH), 8.0, sdt)
	var squeeze := well_t >= SQUEEZE_AT
	for e in game.enemies.list:
		if e.state != Enemies.ALIVE:
			continue
		var d: Vector2 = well_pos - e.pos
		var l := d.length()
		if l < WELL_R + e.r and l > 2.0:
			var f: float = 1.0 - l / (WELL_R + e.r)
			e.knock += d / l * (2600.0 + 2400.0 * f) * sdt * (1.6 if squeeze else 1.0)
			e.vel *= exp(-6.0 * sdt)
	if squeeze:
		squeeze_tick -= sdt
		if squeeze_tick <= 0.0:
			squeeze_tick = 0.15
			for e in game.enemies.list:
				if e.state == Enemies.ALIVE and e.pos.distance_to(well_pos) < 85.0 + e.r:
					_deal(e, SQUEEZE_DMG, (e.pos - well_pos).normalized(), false)
			game.cam.add_trauma(0.05)
			bursts.append([well_pos, 70.0, 0.25])
	if not fire_held or well_t >= WELL_MAX:
		_well_release()


func _well_release() -> void:
	well_on = false
	recover = 0.35
	var at := well_pos
	if well_t >= SQUEEZE_AT:
		for e in game.enemies.list:
			if e.state == Enemies.ALIVE and e.pos.distance_to(at) < WELL_BURST_R + e.r:
				var d: Vector2 = (e.pos - at).normalized()
				_deal(e, WELL_BURST_DMG, d, true)
				e.knock += d * 700.0
		_finisher(at, WELL_BURST_R)
	else:
		for e in game.enemies.list:
			if e.state == Enemies.ALIVE and e.pos.distance_to(at) < 100.0 + e.r:
				var d2: Vector2 = (e.pos - at).normalized()
				_deal(e, 25.0, d2, false)
				e.knock += d2 * 420.0
		game.fx.ring(at, 10.0, 110.0, 0.3, cyan(0.9, 2.2), 2.0)
		game.sfx.play("p_hit", 1.2, -5.0)
		game.cam.add_trauma(0.12)


# Leech: while its well is open, the rounds coming home bend through the knot.
func home_through():
	if state == HOST and shell.kind == Enemies.LEECH and well_on:
		return well_pos
	return null


# Chaser: each round that reaches the shell flies on down the drill's last line.
func on_round_home() -> void:
	if state != HOST or shell.kind != Enemies.CHASER:
		return
	var d := dash_dir.rotated(randf_range(-0.12, 0.12))
	wakes.append([shell.pos, d * 1700.0, 0.0, {}])


func _step_wakes(sdt: float) -> void:
	var i := 0
	while i < wakes.size():
		var w: Array = wakes[i]
		var a: Vector2 = w[0]
		var b: Vector2 = a + w[1] * sdt
		w[0] = b
		w[2] += sdt
		for e in game.enemies.list:
			if e.state == Enemies.ALIVE and not w[3].has(e.id):
				var q := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
				if q.distance_to(e.pos) <= e.r + 6.0:
					w[3][e.id] = true
					_deal(e, WAKE_DMG, w[1].normalized(), false)
		if w[2] > 0.32 or not Arena.ROOM.has_point(b) or game.arena.raycast(a, b):
			wakes.remove_at(i)
		else:
			i += 1


# ---------------------------------------------------------------- damage

func _deal(e, dmg: float, dir: Vector2, heavy: bool) -> void:
	if e.state != Enemies.ALIVE:
		return
	# no damage numbers here: the shell's hits speak through sparks, shake and sound
	e.hp -= dmg
	e.red = 0.0
	e.squash = 1.0
	e.squash_dir = dir
	e.knock += dir * (540.0 if heavy else 200.0)
	if heavy:
		e.flash = 0.6
		e.bounce = 0.5
	combo += 1
	game.hud.combo_hit(combo, true)
	game.fx.sparks(e.pos, dir, 8 if heavy else 3, cyan(1.0, 2.2), 620.0 if heavy else 420.0, 0.24, 0.7)
	if heavy:
		game.fx.flash(e.pos, 24.0, 0.1, cyan(0.25, 1.6))
	if e.hp <= 0.0:
		game.enemies._die(e, dir)
	game.add_hitstop(0.03 if heavy else 0.015)
	game.cam.add_trauma(0.1 if heavy else 0.05)
	if e.state == Enemies.DEAD:
		game.sfx.play("p_kill", randf_range(0.95, 1.08), -4.0)
	elif heavy:
		game.sfx.play("p_hit", randf_range(0.95, 1.1), -6.0)


# A knocked body hits a wall (Enemies tells us): it bounces and takes a little more.
func wall_slam(e, at: Vector2, n: Vector2) -> void:
	game.fx.sparks(at, n, 10, cyan(1.0, 2.2), 520.0, 0.26, 0.9)
	game.fx.ring(at, 4.0, 40.0, 0.25, cyan(0.8, 2.0), 1.5)
	game.sfx.play("p_bounce", randf_range(0.95, 1.08), -4.0)
	game.cam.add_trauma(0.12)
	game.add_hitstop(0.025)
	_deal(e, 20.0, n, false)


func _finisher(at: Vector2, radius: float) -> void:
	game.cine_k = 1.0
	game.cine_t = 0.0
	game.add_hitstop(0.08)
	game.sfx.play("p_finish", 1.0, 0.0)
	game.sfx.drop()
	game.cam.add_trauma(0.6)
	game.cam.punch(0.05)
	var su: Vector2 = game.screen_uv(at)
	game.post.shock(su, 1.4, 2.0)
	game.post.punch(su, 0.03)
	game.post.pulse(0.01)
	game.fx.ring(at, 12.0, radius + 30.0, 0.5, cyan(1.0, 2.8), 4.0)
	game.fx.ring(at, 6.0, radius * 0.6, 0.35, Pal.ink(0.9, 2.0), 2.0)
	game.fx.flash(at, radius, 0.3, cyan(0.6, 2.2))
	game.fx.sparks(at, Vector2.UP, 30, cyan(1.0, 2.6), 900.0, 0.45, PI)
	game.fx.wave_push(at, 400.0, 200.0)
	bursts.append([at, radius, 0.0])
	game.hud.combo_hit(combo, true)


# ---------------------------------------------------------------- drawing

func _px(p: Vector2, n: float, c: Color) -> void:
	var q := (p / PX).floor() * PX
	draw_rect(Rect2(q - Vector2(PX, PX) * floor(n * 0.5), Vector2(PX, PX) * n), c)


func _px_line(a: Vector2, b: Vector2, c: Color, n: float = 1.0) -> void:
	var l := a.distance_to(b)
	var steps := maxi(1, int(l / PX))
	for k in steps + 1:
		_px(a.lerp(b, float(k) / steps), n, c)


func _px_ring(o: Vector2, r: float, c: Color, dots: int = 0) -> void:
	var n := dots if dots > 0 else maxi(12, int(TAU * r / (PX * 3.0)))
	for k in n:
		_px(o + Vector2.from_angle(TAU * k / n) * r, 1.0, c)


func _part(name: String, at: Vector2, angle: float, mod: Color) -> void:
	var p: PixelPart = _parts[name]
	var base := Transform2D(0.0, Vector2(BODY_PX, BODY_PX), 0.0, (at / BODY_PX).round() * BODY_PX)
	p.draw(self, base, Vector2.ZERO, angle, false, mod)


func _draw() -> void:
	var f: float = game.focus
	# marks: four cyan pixel corners hugging the body; the one E will take is brighter
	var tgt = target() if state == IDLE else null
	for id in marks:
		var e = marks[id][0]
		if e.state != Enemies.ALIVE:
			continue
		var left: float = marks[id][1]
		var ready: bool = e == tgt and cooldown <= 0.0
		var blink := 1.0 if left > 0.8 else (0.4 + 0.6 * float(int(t * 12.0) % 2))
		var a := (0.95 if ready else 0.5) * blink
		var rr: float = e.r + 7.0 + (2.0 * sin(t * 9.0) if ready else 0.0)
		for k in 4:
			var d := Vector2.from_angle(PI / 4.0 + TAU * k / 4.0)
			var c: Vector2 = e.pos + d * rr
			var hx := Vector2(-signf(d.x), 0.0) * PX * 3.0
			var hy := Vector2(0.0, -signf(d.y)) * PX * 3.0
			_px_line(c, c + hx, cyan(a, 2.2 if ready else 1.4))
			_px_line(c, c + hy, cyan(a, 2.2 if ready else 1.4))
		if ready:
			_draw_key(e.pos + Vector2(0, -rr - 14.0), a)
	# the cooldown, as a thin cyan arc just outside the magazine ring
	if state == IDLE and cooldown > 0.0:
		var k := 1.0 - cooldown / COOLDOWN
		var p: Vector2 = game.player.pos
		var n := 20
		for j in int(n * k):
			_px(p + Vector2.from_angle(-PI / 2.0 + TAU * j / n) * 36.0, 1.0, cyan(0.45))
	# the mind in flight: a streak of cyan pixels from you into the shell
	if state == FLOW and shell != null:
		var k2 := Pal.ease_out(flow_t / FLOW_TIME)
		var head: Vector2 = flow_from.lerp(shell.pos, k2)
		var tail: Vector2 = flow_from.lerp(shell.pos, maxf(0.0, k2 - 0.45))
		_px_line(tail, head, cyan(0.9, 2.4), 2.0)
		_px(head, 4.0, Pal.ink(1.0, 2.4))
	for w in wakes:
		var wa: Vector2 = w[0]
		var wv: Vector2 = w[1]
		_px_line(wa - wv.normalized() * 34.0, wa, cyan(1.0 - w[2] / 0.32, 2.4), 1.0)
	for bst in bursts:
		var bk: float = bst[2] / 0.4
		_px_ring(bst[0], bst[1] * Pal.ease_out(bk), cyan(1.0 - bk, 2.4))
	if state != HOST or shell == null:
		return
	var pos: Vector2 = shell.pos
	var kind_name := "chaser" if shell.kind == Enemies.CHASER else "leech"
	# afterimages
	for g in ghosts:
		var gk: float = 1.0 - g[1] / 0.3
		_part(kind_name, g[0], g[2], Color(0.5, 1.6, 1.8, 0.35 * gk * gk))
	# the leech's well and the tether to it
	if well_on:
		var squeeze := well_t >= SQUEEZE_AT
		var wr := lerpf(WELL_R, 90.0, Pal.ease_out(clampf(well_t / WELL_MAX, 0.0, 1.0)))
		for j in 3:
			var ph := fmod(t * 1.6 + j / 3.0, 1.0)
			_px_ring(well_pos, wr * (1.0 - ph) + 12.0, cyan(0.25 + 0.5 * ph, 2.0 if squeeze else 1.4))
		for j in 6:
			var a6 := t * (5.0 if squeeze else 3.0) + TAU * j / 6.0
			_px_line(well_pos + Vector2.from_angle(a6) * 18.0, well_pos + Vector2.from_angle(a6 + 0.7) * 34.0, cyan(0.8, 2.2), 1.0)
		_px(well_pos, 5.0 if squeeze else 3.0, Pal.ink(1.0, 2.4))
		_px_line(pos, well_pos, cyan(0.35, 1.6), 1.0)
	if spin_t >= 0.0:
		for j in 8:
			var a8: float = shell.rot * 0.5 + TAU * j / 8.0
			_px_line(pos + Vector2.from_angle(a8) * 30.0, pos + Vector2.from_angle(a8 + 0.5) * SPIN_R, cyan(0.7, 2.4), 1.0)
	# the body: neon pixels, blinking while untouchable, shaking on the fuse
	var mod := Color(1.25, 1.35, 1.4)
	if shell.flash > 0.0:
		mod = Color(2.4, 2.5, 2.6)
	if iframes > 0.0 and int(iframes * 20.0) % 2 == 0:
		mod.a = 0.45
	var shake := Vector2.ZERO
	if t_left < 1.5:
		shake = Vector2(sin(t * 83.0), cos(t * 71.0)) * (1.5 - t_left) * 1.6
	if shell.kind == Enemies.LEECH:
		# tendrils: three pixel lines that trail behind and reach for the well
		for k in 3:
			var ta: float = shell.rot + PI + (k - 1) * 0.6
			var reach := 24.0 + 8.0 * sin(t * 8.0 + k)
			var tip: Vector2 = pos + Vector2.from_angle(ta + 0.3 * sin(t * 5.0 + k)) * reach
			if well_on:
				tip = pos.lerp(well_pos, 0.25 + 0.05 * k)
			_px_line(pos + Vector2.from_angle(ta) * 14.0, tip, cyan(0.9, 1.8), 1.0)
	_part(kind_name, pos + shake, shell.rot, mod)
	if grow > 0.35:
		_part(kind_name + ("_spk2" if grow > 0.75 else "_spk1"), pos + shake, shell.rot, Color(mod.r * 1.2, mod.g * 1.2, mod.b * 1.2, mod.a))
	# time left: a ring of pixels that empties; hits left: three pips under it
	var frac := clampf(t_left / DURATION, 0.0, 1.0)
	var dots := 28
	var lit := int(ceil(dots * frac))
	var hot := t_left < 1.5 and int(t * 10.0) % 2 == 0
	for j in dots:
		var on := j < lit
		_px(pos + Vector2.from_angle(-PI / 2.0 + TAU * j / dots) * 44.0, 1.0, (Pal.red(0.9, 2.0) if hot else cyan(0.9, 1.8)) if on else cyan(0.15))
	for j in SHELL_HITS:
		_px(pos + Vector2((j - 1) * 8.0, 54.0), 2.0, cyan(0.9, 2.0) if j < hits_left else cyan(0.15))


# A little pixel "E" keycap over the shell you can take.
func _draw_key(at: Vector2, a: float) -> void:
	var rows := ["###", "#..", "##.", "#..", "###"]
	var o := at - Vector2(PX * 1.5, PX * 2.5)
	for y in rows.size():
		for x in 3:
			if rows[y][x] == "#":
				_px(o + Vector2(x, y) * PX, 1.0, Pal.ink(a, 2.0))
	var box := Rect2(o - Vector2(PX * 2.0, PX * 2.0), Vector2(PX * 7.0, PX * 9.0))
	_px_line(box.position, Vector2(box.end.x, box.position.y), cyan(a * 0.8, 1.6))
	_px_line(Vector2(box.position.x, box.end.y), box.end, cyan(a * 0.8, 1.6))
	_px_line(box.position, Vector2(box.position.x, box.end.y), cyan(a * 0.8, 1.6))
	_px_line(Vector2(box.end.x, box.position.y), box.end, cyan(a * 0.8, 1.6))
