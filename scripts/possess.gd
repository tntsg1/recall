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
const KINDS := [Enemies.CHASER, Enemies.LEECH, Enemies.GUARD, Enemies.CHARGER, Enemies.PRISM, Enemies.PULSE, Enemies.ECHO]
const NAMES := {Enemies.CHASER: "chaser", Enemies.LEECH: "leech", Enemies.GUARD: "guard", Enemies.CHARGER: "charger",
	Enemies.PRISM: "prism", Enemies.PULSE: "pulse", Enemies.ECHO: "echo"}
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
# guard: shove, sweep, then the shield rush that pins a row of bodies to the wall
const SHOVE_DMG := 30.0
const SWEEP_DMG := 35.0
const RUSH_SPEED := 1150.0
const RUSH_TIME := 0.45
const RUSH_DMG := 70.0
# charger: hold to aim the lane, let go to ram; the walls throw it back twice, the third one blows
const RAM_SPEED := 1500.0
const RAM_DMG := [50.0, 55.0, 60.0]
const RAM_BURST_R := 160.0
const RAM_BURST_DMG := 80.0
# prism: one beam, three beams, then twelve
const BEAM_DMG := [40.0, 38.0, 50.0]
# pulse: beat blink — two blinks, then a leap that slams; on the beat ×1.5
const BLINK_REACH := 320.0
const BLINK_R := 130.0
const BLINK_DMG := 40.0
const LEAP_TIME := 0.36
const BLINK_SLAM_R := 220.0
const BLINK_SLAM_DMG := 90.0
# echo: two copies trace where you walked, then everything replays and detonates
const ECHO_TOUCH := 25.0
const ECHO_BURST_R := 110.0
const ECHO_BURST_DMG := 60.0

var game
var state := IDLE
var shell = null                # Enemies.E while seized
var t_left := 0.0
var cooldown := 0.0
var flow_t := 0.0
var flow_from := Vector2.ZERO
var marks := {}                 # enemy id -> [E, time left]
var hinted := false
var endless := false            # the training yard: no time limit, no cooldown
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
var queue_t := 0.0             # a click held over a short recovery (0.4 s) instead of being lost
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
# guard
var rush_t := 0.0
var carried := {}
# charger
var winding := false
var wind := 0.0
var ram_t := 0.0
var ram_seg := 0
var lanes: Array = []           # [a, b, age] — the red line a ram leaves
# prism
var beams: Array = []           # [a, b, age]
# pulse
var last_beat := -1
var leap_t := -1.0
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var afterlines: Array = []      # [from, to, age] — the streak a blink leaves
# echo
var clones: Array = []          # {pos, path, replay, idx, hit, done}
var clone_t := 0.0

var _parts := {}
var boss_hit := {}              # one boss hit per dash / ram / beam
# the floor infection: the shell itself, its recent trail, and the big landings
var residue: Array = []         # [pos, radius, life, max life]
var residue_cd := 0.0


func _ready() -> void:
	z_index = 5
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for k in NAMES:
		for suffix in ["", "_spk1", "_spk2"]:
			var n: String = NAMES[k] + suffix
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


# The 夺壳 school. Lv1: longer in the shell, marks last longer. Lv2: when a shell
# ends, the mind jumps straight into the nearest marked enemy. Lv3: every shell
# hits a third harder and its last blast is twice as wide.
func lvl() -> int:
	return game.lv.get("possess", 0)


func duration() -> float:
	return DURATION * (1.5 if lvl() >= 1 else 1.0)


func power() -> float:
	return 1.35 if lvl() >= 3 else 1.0


func busy() -> bool:
	return state != IDLE


# ---------------------------------------------------------------- marks

func mark(e) -> void:
	if e.state != Enemies.ALIVE or not KINDS.has(e.kind):
		return
	var fresh := not marks.has(e.id)
	marks[e.id] = [e, MARK_TIME * (1.5 if lvl() >= 1 else 1.0)]
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
		end(false, false, true)
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


# The training yard's number keys: straight in, no mark and no flight.
func seize_now(e) -> void:
	shell = e
	game.player.visible = false
	_begin_host()


func _begin_host() -> void:
	if shell == null or shell.state != Enemies.ALIVE:
		# it died while the mind was in flight: land back in the body
		_restore(game.player.pos)
		return
	state = HOST
	shell.state = Enemies.HOST
	if game.lore != null and not endless:
		game.lore.on_seize(shell)
	shell.knock = Vector2.ZERO
	shell.vel = Vector2.ZERO
	shell.burn = 0.0
	if shell.grip != null:
		# a seized leech lets go of everything it stole: the rounds fly home to you
		for b in game.bullets.held_by(shell.grip):
			game.bullets.send_home(b)
	vel = Vector2.ZERO
	aim = Vector2.from_angle(shell.rot)
	t_left = duration()
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
	rush_t = 0.0
	carried.clear()
	winding = false
	ram_t = 0.0
	clones.clear()
	leap_t = -1.0
	last_beat = int(floor(game.sfx.beat()))
	fire_prev = true          # the E press must not also count as a click
	game.player.pos = shell.pos
	game.player.position = shell.pos
	game.sfx.play("p_grow", 1.0, -3.0)
	game.fx.ring(shell.pos, 12.0, 150.0, 0.45, cyan(1.0, 2.4), 3.0)
	game.fx.flash(shell.pos, 90.0, 0.25, cyan(0.5, 2.0))
	infect_patch(shell.pos, 200.0)
	game.fx.sparks(shell.pos, Vector2.UP, 18, cyan(1.0, 2.4), 520.0, 0.35, PI)
	game.cam.add_trauma(0.3)
	game.cam.punch(0.03)
	game.post.shock(game.screen_uv(shell.pos), 0.8, 1.6)
	bursts.append([shell.pos, 150.0, 0.0])
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE and e.pos.distance_to(shell.pos) < 150.0:
			e.knock += (e.pos - shell.pos).normalized() * 420.0


# Time up, E, broken, or the wave is over: the shell goes off and you step out.
func end(broken: bool, quiet: bool = false, by_hand: bool = false) -> void:
	if state != HOST:
		return
	var at: Vector2 = shell.pos
	var blast_r := BLAST_R * (2.0 if lvl() >= 3 else 1.0)
	if not quiet:
		for e in game.enemies.list:
			if e.state == Enemies.ALIVE and e.pos.distance_to(at) < blast_r + e.r:
				_deal(e, BLAST_DMG, (e.pos - at).normalized(), true)
		_boss_area(at, blast_r, BLAST_DMG)
		game.sfx.play("p_blast", 1.0, -1.0)
		game.cam.add_trauma(0.45)
		game.cam.punch(0.04)
		game.post.shock(game.screen_uv(at), 1.1, 1.8)
		game.post.pulse(0.006)
		game.add_hitstop(0.06)
		bursts.append([at, blast_r, 0.0])
		game.fx.ring(at, 10.0, blast_r + 20.0, 0.4, cyan(1.0, 2.6), 3.0)
		game.fx.flash(at, blast_r, 0.25, cyan(0.55, 2.0))
	_shatter(at, broken)
	# Lv2 chain: out of the blast and straight into the next marked shell
	if not quiet and not by_hand and lvl() >= 2:
		var next = null
		var nd := 450.0
		for id in marks:
			var me = marks[id][0]
			if me.state == Enemies.ALIVE and me.pos.distance_to(at) < nd:
				nd = me.pos.distance_to(at)
				next = me
		if next != null:
			shell = next
			marks.erase(next.id)
			state = FLOW
			flow_t = 0.0
			flow_from = at
			game.player.pos = at
			game.player.position = at
			game.sfx.play("p_possess", 1.2, -2.0)
			game.hud.flash_text(Txt.t("possess_chain"), at)
			return
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
	rush_t = 0.0
	ram_t = 0.0
	winding = false
	clones.clear()
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
	if iframes > 0.0 or game.wave_ctl.phase != Waves.FIGHT or game.dev_god or spin_t >= 0.0 or rush_t > 0.0 or ram_t > 0.0 or leap_t >= 0.0:
		return false
	if shell.kind == Enemies.GUARD and dir.dot(aim) < -0.2:
		# the raised shield takes it
		game.fx.sparks(shell.pos + aim * 24.0, aim, 8, cyan(1.0, 2.2), 480.0, 0.22, 0.8)
		game.sfx.play("shield", randf_range(1.0, 1.15), -6.0)
		game.cam.add_trauma(0.08)
		iframes = 0.25
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
	_update_infection(dt)
	var i := 0
	while i < ghosts.size():
		ghosts[i][1] += dt
		if ghosts[i][1] > 0.3:
			ghosts.remove_at(i)
		else:
			i += 1
	for arr in [lanes, beams, afterlines]:
		var j := 0
		while j < arr.size():
			arr[j][2] += dt
			if arr[j][2] > (3.0 if arr == lanes else (0.18 if arr == beams else 0.3)):
				arr.remove_at(j)
			else:
				j += 1
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
	if endless:
		t_left = duration()
	t_left -= sdt
	iframes = maxf(0.0, iframes - sdt)
	recover = maxf(0.0, recover - sdt)
	grow = minf(1.0, grow + dt / 0.35)
	shell.flash = maxf(0.0, shell.flash - dt / 0.12)
	shell.t += sdt
	var to_aim: Vector2 = aim_at - shell.pos
	if to_aim.length() > 4.0:
		aim = to_aim.normalized()
	var raw := fire_held and not fire_prev
	fire_prev = fire_held
	if raw:
		queued = true
		queue_t = 0.4
	queue_t -= sdt
	if queue_t <= 0.0:
		queued = false
	# guard, prism and echo take the remembered click once they are ready again
	var pressed := queued and recover <= 0.0 and dash_t <= 0.0 and spin_t < 0.0 and rush_t <= 0.0 and leap_t < 0.0
	if pressed and shell.kind in [Enemies.GUARD, Enemies.PRISM, Enemies.ECHO, Enemies.PULSE]:
		queued = false
	var r: float = shell.r * 1.3
	var before: Vector2 = shell.pos
	match shell.kind:
		Enemies.CHASER:
			_chaser(sdt, false, move)
		Enemies.LEECH:
			_leech(sdt, fire_held, move, aim_at)
		Enemies.GUARD:
			_guard(sdt, pressed, move)
		Enemies.CHARGER:
			_charger(sdt, fire_held, move)
		Enemies.PRISM:
			_prism(sdt, pressed, move)
		Enemies.PULSE:
			_pulse(sdt, pressed, move, aim_at)
		Enemies.ECHO:
			_echo(sdt, pressed, move)
	var free_pos: Vector2 = shell.pos
	shell.pos = game.arena.push_circle(shell.pos, r)
	shell.pos = shell.pos.clamp(Arena.ROOM.position + Vector2(r, r), Arena.ROOM.end - Vector2(r, r))
	if dash_t > 0.0 or ram_t > 0.0:
		_drill_sweep(before, shell.pos)
	if free_pos.distance_to(shell.pos) > 1.5:
		_on_wall((shell.pos - free_pos).normalized())
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
			_boss_area(shell.pos, SPIN_R, SPIN_TICK_DMG)
		if spin_t >= SPIN_TIME:
			_spin_burst()
	else:
		_move(sdt, move, 520.0, 14.0)
		if vel.length() > 20.0:
			shell.rot = lerp_angle(shell.rot, vel.angle(), 1.0 - exp(-12.0 * sdt))


func _start_dash() -> void:
	boss_hit.clear()
	stage += 1
	dash_dir = aim
	dash_t = DRILL_TIME
	dash_hit.clear()
	ghost_cd = 0.0
	game.sfx.play("dash", 1.25 + stage * 0.1, -4.0)
	game.cam.kick(-dash_dir, 2.0)
	game.fx.ring(shell.pos, 8.0, 40.0, 0.2, cyan(0.8, 2.0), 1.5)


func _drill_sweep(a: Vector2, b: Vector2) -> void:
	_boss_line(a, b, 50.0, "dash%d" % ram_seg if ram_t > 0.0 else "dash%d" % stage)
	var dmg: float = DRILL_DMG[clampi(stage - 1, 0, 1)]
	if ram_t > 0.0:
		dmg = RAM_DMG[clampi(ram_seg - 1, 0, 2)]
	for e in game.enemies.list:
		if e.state != Enemies.ALIVE or dash_hit.has(e.id):
			continue
		var q := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
		if q.distance_to(e.pos) <= e.r + shell.r * 1.3 + 6.0:
			dash_hit[e.id] = true
			_deal(e, dmg, dash_dir, true)
			game.sfx.play("p_drill", randf_range(1.05, 1.2) * (0.85 if ram_t > 0.0 else 1.0), -4.0)


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
	_boss_area(at, SPIN_BURST_R, SPIN_BURST_DMG)
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
			_boss_area(well_pos, 85.0, SQUEEZE_DMG)
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
		_boss_area(at, WELL_BURST_R, WELL_BURST_DMG)
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
	if state != HOST:
		return
	match shell.kind:
		Enemies.CHASER:
			var d := dash_dir.rotated(randf_range(-0.12, 0.12))
			wakes.append([shell.pos, d * 1700.0, 0.0, {}, 0.32])
		Enemies.PRISM:
			# the prism splits every round that comes home into three
			for k in 3:
				wakes.append([shell.pos, aim.rotated((k - 1) * 0.32 + randf_range(-0.05, 0.05)) * 1700.0, 0.0, {}, 0.36])


func _step_wakes(sdt: float) -> void:
	var i := 0
	while i < wakes.size():
		var w: Array = wakes[i]
		var a: Vector2 = w[0]
		var b: Vector2 = a + w[1] * sdt
		w[0] = b
		w[2] += sdt
		if not w[3].has("boss"):
			var bs = game.boss
			if bs != null and bs.alive():
				var bh: Dictionary = bs.hit_test(a, b)
				if not bh.is_empty() and bh.get("core", false):
					w[3]["boss"] = true
					bs.damage(WAKE_DMG * power() * BOSS_MULT * bh.get("mult", 1.0), true, bh.point, w[1].normalized(), bh.get("frame", -1))
		for e in game.enemies.list:
			if e.state == Enemies.ALIVE and not w[3].has(e.id):
				var q := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
				if q.distance_to(e.pos) <= e.r + 6.0:
					w[3][e.id] = true
					_deal(e, WAKE_DMG, w[1].normalized(), false)
		if w[2] > w[4] or not Arena.ROOM.has_point(b) or game.arena.raycast(a, b):
			wakes.remove_at(i)
		else:
			i += 1


# ---------------------------------------------------------------- guard

func _guard(sdt: float, pressed: bool, move: Vector2) -> void:
	stage_window -= sdt
	if rush_t > 0.0:
		rush_t -= sdt
		vel = dash_dir * RUSH_SPEED
		shell.pos += vel * sdt
		shell.rot = dash_dir.angle()
		ghost_cd -= sdt
		if ghost_cd <= 0.0:
			ghost_cd = 0.025
			ghosts.append([shell.pos, 0.0, shell.rot])
		# scoop up whatever is in front of the shield and carry it along
		for e in game.enemies.list:
			if e.state != Enemies.ALIVE:
				continue
			var d: Vector2 = e.pos - shell.pos
			var ahead := d.dot(dash_dir)
			if ahead > 0.0 and ahead < shell.r * 1.3 + e.r + 70.0 and absf(d.dot(dash_dir.orthogonal())) < 64.0:
				if not carried.has(e.id):
					carried[e.id] = e
					game.sfx.play("p_hit", randf_range(1.1, 1.25), -8.0)
				e.knock = dash_dir * RUSH_SPEED * 1.05
		if rush_t <= 0.0:
			_rush_end(false)
		return
	_move(sdt, move, 300.0, 12.0)
	shell.rot = lerp_angle(shell.rot, aim.angle(), 1.0 - exp(-14.0 * sdt))
	if not pressed or recover > 0.0:
		return
	stage = stage + 1 if stage_window > 0.0 and stage < 3 else 1
	stage_window = 0.6
	recover = 0.2
	match stage:
		1:
			_cone(aim, 0.8, 130.0, SHOVE_DMG, 380.0)
			game.sfx.play("shield", 0.85, -3.0)
			game.cam.kick(-aim, 2.5)
		2:
			_cone(aim, 1.5, 150.0, SWEEP_DMG, 300.0, true)
			game.sfx.play("dash", 0.9, -4.0)
			game.cam.kick(aim.orthogonal(), 2.5)
		3:
			rush_t = RUSH_TIME
			dash_dir = aim
			carried.clear()
			ghost_cd = 0.0
			game.sfx.play("dash_e", 0.9, -2.0)
			game.cam.kick(-aim, 3.0)


# A shove or a sweep: everything inside the arc in front takes it and flies.
func _cone(dir: Vector2, half: float, reach: float, dmg: float, push: float, sideways: bool = false) -> void:
	var at: Vector2 = shell.pos
	for e in game.enemies.list:
		if e.state != Enemies.ALIVE:
			continue
		var d: Vector2 = e.pos - at
		if d.length() > reach + e.r or absf(dir.angle_to(d)) > half:
			continue
		var kd: Vector2 = d.normalized()
		if sideways:
			kd = (kd + dir.orthogonal() * signf(dir.orthogonal().dot(d))).normalized()
		_deal(e, dmg, kd, true)
		e.knock += kd * push
		e.bounce = 0.0      # a shove sets them up for the rush; only the rush slams them into walls
	_boss_area(at + dir * reach * 0.5, reach * 0.6, dmg)
	for k in 7:
		var a := dir.angle() + lerpf(-half, half, k / 6.0)
		bursts.append([at + Vector2.from_angle(a) * reach * 0.6, 14.0, 0.15])
	game.fx.sparks(at + dir * 30.0, dir, 10, cyan(1.0, 2.2), 560.0, 0.22, half)


func _rush_end(hit_wall: bool) -> void:
	rush_t = 0.0
	stage = 0
	recover = 0.3
	var at: Vector2 = shell.pos + dash_dir * 30.0
	for id in carried:
		var e = carried[id]
		if e.state != Enemies.ALIVE:
			continue
		e.pinned = 2.0 if hit_wall else 1.0
		_deal(e, RUSH_DMG * (1.4 if hit_wall else 1.0), dash_dir, true)
	carried.clear()
	_boss_area(at, 120.0, RUSH_DMG)
	if hit_wall:
		game.sfx.play("p_slam", 1.1, -1.0)
	_finisher(at, 120.0)


# ---------------------------------------------------------------- charger

func _charger(sdt: float, fire_held: bool, move: Vector2) -> void:
	if ram_t > 0.0:
		ram_t -= sdt
		vel = dash_dir * RAM_SPEED
		var from: Vector2 = shell.pos
		shell.pos += vel * sdt
		shell.rot = dash_dir.angle()
		lanes.append([from, shell.pos, 0.0])
		ghost_cd -= sdt
		if ghost_cd <= 0.0:
			ghost_cd = 0.02
			ghosts.append([shell.pos, 0.0, shell.rot])
		if ram_t <= 0.0:
			ram_t = 0.0
			recover = 0.3
			vel = dash_dir * 260.0
		return
	if winding:
		wind += sdt
		vel = Pal.damp2(vel, -aim * 30.0, 8.0, sdt)
		shell.pos += vel * sdt
		shell.rot = aim.angle()
		if not fire_held:
			winding = false
			if wind >= 0.12:
				ram_t = 0.85
				ram_seg = 1
				dash_dir = aim
				dash_hit.clear()
				ghost_cd = 0.0
				game.sfx.play("dash_e", 1.0, -2.0)
				boss_hit.clear()
				game.cam.kick(-aim, 3.5)
				game.fx.ring(shell.pos, 10.0, 50.0, 0.25, cyan(0.9, 2.2), 2.0)
		return
	_move(sdt, move, 300.0, 12.0)
	shell.rot = lerp_angle(shell.rot, aim.angle(), 1.0 - exp(-12.0 * sdt))
	if fire_held and recover <= 0.0:
		winding = true
		wind = 0.0
		game.sfx.play("windup", 1.15, -6.0)


func _on_wall(n: Vector2) -> void:
	if shell.kind == Enemies.GUARD and rush_t > 0.0:
		_rush_end(true)
	elif shell.kind == Enemies.CHARGER and ram_t > 0.0:
		var at: Vector2 = shell.pos - n * shell.r
		if ram_seg >= 3:
			ram_t = 0.0
			recover = 0.35
			vel = n * 200.0
			for e in game.enemies.list:
				if e.state == Enemies.ALIVE and e.pos.distance_to(at) < RAM_BURST_R + e.r:
					var d: Vector2 = (e.pos - at).normalized()
					_deal(e, RAM_BURST_DMG, d, true)
					e.knock += d * 640.0
			_boss_area(at, RAM_BURST_R, RAM_BURST_DMG)
			game.sfx.play("p_slam", 1.0, 0.0)
			_finisher(at, RAM_BURST_R)
			return
		# the wall throws it back: a fresh run down the new line
		ram_seg += 1
		dash_dir = dash_dir.bounce(n).normalized() if absf(dash_dir.dot(n)) > 0.05 else n
		ram_t = maxf(ram_t, 0.6)
		dash_hit.clear()
		boss_hit.clear()
		game.sfx.play("slam", randf_range(1.0, 1.1), -3.0)
		game.cam.add_trauma(0.25)
		game.add_hitstop(0.04)
		game.fx.sparks(at, n, 14, cyan(1.0, 2.4), 620.0, 0.3, 1.0)
		bursts.append([at, 60.0, 0.0])


# Charger: a round coming home along the ram's red line cuts harder.
func lane_bonus(p: Vector2) -> float:
	for l in lanes:
		if Geometry2D.get_closest_point_to_segment(p, l[0], l[1]).distance_to(p) < 40.0:
			return 1.5
	return 1.0


# ---------------------------------------------------------------- prism

func _prism(sdt: float, pressed: bool, move: Vector2) -> void:
	stage_window -= sdt
	_move(sdt, move, 260.0, 10.0)
	shell.rot += 1.2 * sdt
	if not pressed or recover > 0.0:
		return
	stage = stage + 1 if stage_window > 0.0 and stage < 3 else 1
	stage_window = 0.6
	recover = 0.16
	match stage:
		1:
			_beam(aim, BEAM_DMG[0])
			game.sfx.play("cross", 1.0, -3.0)
		2:
			for k in 3:
				_beam(aim.rotated((k - 1) * 0.26), BEAM_DMG[1])
			game.sfx.play("cross", 1.15, -2.0)
		3:
			for k in 12:
				_beam(aim.rotated(TAU * k / 12.0), BEAM_DMG[2])
			game.sfx.play("cross", 0.8, 0.0)
			stage = 0
			_finisher(shell.pos, 140.0)
	game.cam.kick(-aim, 1.5)


func _beam(dir: Vector2, dmg: float) -> void:
	var a: Vector2 = shell.pos + dir * shell.r
	var h: Dictionary = game.arena.raycast(a, a + dir * 2200.0)
	var b: Vector2 = h.point if h else a + dir * 2200.0
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE and Geometry2D.get_closest_point_to_segment(e.pos, a, b).distance_to(e.pos) <= e.r + 16.0:
			_deal(e, dmg, dir, false)
	boss_hit.clear()
	_boss_line(a, b, dmg, "beam")
	beams.append([a, b, 0.0])
	game.fx.flash(b, 18.0, 0.1, cyan(0.4, 1.8))


# ---------------------------------------------------------------- pulse

func on_beat_now() -> bool:
	var f: float = game.sfx.beat_frac()
	return f < 0.2 or f > 0.85


# Pulse: a recall let go on the beat sends every round at once, harder.
func pulse_beat() -> bool:
	return state == HOST and shell.kind == Enemies.PULSE and on_beat_now()


# Beat blink: click and you are already at the reticle (up to 320 px), the landing
# goes off like a kick drum. Twice; the third click leaps high and comes down on
# the reticle hard. On the beat everything hits half again as hard — a bonus, never
# a requirement.
func _pulse(sdt: float, pressed: bool, move: Vector2, aim_at: Vector2) -> void:
	stage_window -= sdt
	if leap_t >= 0.0:
		leap_t += sdt
		var k := clampf(leap_t / LEAP_TIME, 0.0, 1.0)
		shell.pos = leap_from.lerp(leap_to, Pal.ease_io(k))
		vel = Vector2.ZERO
		if k >= 1.0:
			leap_t = -1.0
			_blink_land(leap_to, BLINK_SLAM_R, BLINK_SLAM_DMG, true)
			stage = 0
			recover = 0.3
		return
	_move(sdt, move, 340.0, 12.0)
	var bi := int(floor(game.sfx.beat()))
	if bi != last_beat:
		last_beat = bi
		shell.squash = 1.0
	if not pressed:
		return
	stage = stage + 1 if stage_window > 0.0 and stage < 3 else 1
	stage_window = 0.8
	recover = 0.14
	var to: Vector2 = shell.pos + (aim_at - shell.pos).limit_length(BLINK_REACH)
	to = game.arena.push_circle(to, shell.r * 1.3)
	to = to.clamp(Arena.ROOM.position + Vector2(30, 30), Arena.ROOM.end - Vector2(30, 30))
	if stage >= 3:
		leap_t = 0.0
		leap_from = shell.pos
		leap_to = to
		game.sfx.play("dash_e", 0.8, -3.0)
		return
	var from: Vector2 = shell.pos
	ghosts.append([from, 0.0, shell.rot])
	shell.pos = to
	afterlines.append([from, to, 0.0])
	_blink_land(to, BLINK_R, BLINK_DMG, false)


func _blink_land(at: Vector2, radius: float, dmg: float, slam: bool) -> void:
	var beat := on_beat_now()
	var mult := 1.5 if beat else 1.0
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE and e.pos.distance_to(at) < radius + e.r:
			var d: Vector2 = (e.pos - at).normalized()
			_deal(e, dmg * mult, d, true)
			e.knock += d * (640.0 if slam else 420.0)
	_boss_area(at, radius, dmg * mult)
	bursts.append([at, radius, 0.0])
	if beat:
		bursts.append([at, radius * 0.6, 0.1])
		game.hud.flash_text(Txt.t("on_beat"), at)
	game.sfx.play("p_slam" if slam else "p_hit", 1.0 if slam else 1.15, -1.0 if slam else -4.0)
	game.cam.add_trauma(0.4 if slam else 0.18)
	if slam:
		_finisher(at, radius)


func _ring_hit(radius: float, dmg: float, heavy: bool) -> void:
	var at: Vector2 = shell.pos
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE and e.pos.distance_to(at) < radius + e.r:
			var d: Vector2 = (e.pos - at).normalized()
			_deal(e, dmg, d, heavy)
			e.knock += d * (420.0 if heavy else 160.0)
	bursts.append([at, radius, 0.0])
	if heavy:
		game.cam.add_trauma(0.15)


# ---------------------------------------------------------------- echo

func _echo(sdt: float, pressed: bool, move: Vector2) -> void:
	stage_window -= sdt
	_move(sdt, move, 420.0, 14.0)
	if vel.length() > 20.0:
		shell.rot = lerp_angle(shell.rot, vel.angle(), 1.0 - exp(-10.0 * sdt))
		ghost_cd -= sdt
		if ghost_cd <= 0.0:
			ghost_cd = 0.05
			ghosts.append([shell.pos, 0.0, shell.rot])
	var replaying := false
	for c in clones:
		if c.replay:
			replaying = true
			_clone_replay(c, sdt)
		else:
			c.path.append(shell.pos)
			if c.path.size() > 240:
				c.path.remove_at(0)
	var i := 0
	while i < clones.size():
		if clones[i].done:
			clones.remove_at(i)
		else:
			i += 1
	if not clones.is_empty() and not replaying:
		clone_t += sdt
		if clone_t > 4.0:
			_echo_replay()
	if not pressed or recover > 0.0 or replaying:
		return
	recover = 0.15
	if clones.size() < 2:
		clones.append({"pos": shell.pos, "path": PackedVector2Array([shell.pos]), "replay": false, "idx": 0.0, "hit": {}, "done": false})
		clone_t = 0.0
		stage = clones.size()
		game.sfx.play("p_ready", 0.9 + clones.size() * 0.15, -4.0)
		game.fx.ring(shell.pos, 6.0, 40.0, 0.3, cyan(0.8, 2.0), 1.5)
	else:
		_echo_replay()


func _echo_replay() -> void:
	stage = 3
	for c in clones:
		c.replay = true
		c.idx = 0.0
	game.sfx.play("p_well", 1.3, -3.0)


func _clone_replay(c: Dictionary, sdt: float) -> void:
	var path: PackedVector2Array = c.path
	c.idx += sdt * 150.0       # three times the speed you walked it
	var k := mini(int(c.idx), path.size() - 1)
	c.pos = path[k]
	for e in game.enemies.list:
		if e.state != Enemies.ALIVE:
			continue
		var d: Vector2 = c.pos - e.pos
		if d.length() < 150.0:
			e.knock += d.normalized() * 900.0 * sdt     # drawn to the copy
		if d.length() < e.r + 20.0 and not c.hit.has(e.id):
			c.hit[e.id] = true
			_deal(e, ECHO_TOUCH, -d.normalized(), false)
	if k >= path.size() - 1:
		c.done = true
		var at: Vector2 = c.pos
		for e in game.enemies.list:
			if e.state == Enemies.ALIVE and e.pos.distance_to(at) < ECHO_BURST_R + e.r:
				var dd: Vector2 = (e.pos - at).normalized()
				_deal(e, ECHO_BURST_DMG, dd, true)
				e.knock += dd * 520.0
		_boss_area(at, ECHO_BURST_R, ECHO_BURST_DMG)
		_finisher(at, ECHO_BURST_R)
		stage = 0


# Echo: when you recall, every copy sends rounds of its own back to you.
func on_recall_release() -> void:
	if state != HOST or shell.kind != Enemies.ECHO:
		return
	for c in clones:
		var to: Vector2 = shell.pos - c.pos
		if to.length() < 30.0:
			continue
		for k in 4:
			var v: Vector2 = to.normalized().rotated(randf_range(-0.08, 0.08)) * 1700.0
			wakes.append([c.pos + to.normalized().orthogonal() * (k - 1.5) * 8.0, v, 0.0, {}, to.length() / 1700.0])


# ---------------------------------------------------------------- bosses
# A boss cannot be seized, but a shell's moves hurt it — through the same armour
# rules as a round: only what reaches the open core counts, at half weight.
const BOSS_MULT := 0.5


func _boss_line(a: Vector2, b: Vector2, dmg: float, key: String) -> void:
	var bs = game.boss
	if bs == null or not bs.alive() or boss_hit.has(key):
		return
	# some bosses have parts only a shell can break (the lockdown's legs)
	if bs.has_method("shell_strike") and bs.shell_strike(a, b, 0.0, dmg * power()):
		boss_hit[key] = true
		game.fx.sparks(b, (b - a).normalized(), 10, cyan(1.0, 2.4), 560.0, 0.25, 0.8)
		return
	var bh: Dictionary = bs.hit_test(a, b)
	if bh.is_empty() or not bh.get("core", false):
		return
	boss_hit[key] = true
	bs.damage(dmg * power() * BOSS_MULT * bh.get("mult", 1.0), true, bh.point, (b - a).normalized(), bh.get("frame", -1))
	game.fx.sparks(bh.point, (b - a).normalized(), 10, cyan(1.0, 2.4), 560.0, 0.25, 0.8)


func _boss_area(at: Vector2, radius: float, dmg: float) -> void:
	var bs = game.boss
	if bs == null or not bs.alive():
		return
	if bs.has_method("shell_strike") and bs.shell_strike(at, at, radius, dmg * power()):
		game.fx.sparks(at, Vector2.UP, 10, cyan(1.0, 2.4), 560.0, 0.25, PI)
		return
	var cp: Vector2 = bs.core_pos()
	if cp.distance_to(at) > radius + 60.0:
		return
	var d := (cp - at).normalized() if cp.distance_to(at) > 1.0 else Vector2.RIGHT
	var bh: Dictionary = bs.hit_test(at - d * 4.0, cp + d * 20.0)
	if bh.is_empty() or not bh.get("core", false):
		return
	bs.damage(dmg * power() * BOSS_MULT * bh.get("mult", 1.0), true, bh.point, d, bh.get("frame", -1))
	game.fx.sparks(bh.point, d, 10, cyan(1.0, 2.4), 560.0, 0.25, 0.8)


# ---------------------------------------------------------------- damage

func _deal(e, dmg: float, dir: Vector2, heavy: bool) -> void:
	if e.state != Enemies.ALIVE:
		return
	# no damage numbers here: the shell's hits speak through sparks, shake and sound
	dmg *= power()
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
	infect_patch(at, radius * 1.3)
	game.hud.combo_hit(combo, true)


# ---------------------------------------------------------------- drawing

static func _h(a: float, b: float) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)


# The look: pixels invading a world of clean lines. A pixel is a 2-unit square;
# lines stay clean lines but shed pixels along their length; rings do the same.
func _px(p: Vector2, n: float, c: Color) -> void:
	var q := (p / PX).floor() * PX
	draw_rect(Rect2(q - Vector2(PX, PX) * floor(n * 0.5), Vector2(PX, PX) * n), c)


func _px_line(a: Vector2, b: Vector2, c: Color, n: float = 1.0) -> void:
	draw_line(a, b, c, 1.0 + 0.8 * n)
	var l0 := a.distance_to(b)
	var k0 := int(l0 / 14.0)
	var nrm := (b - a).orthogonal().normalized() if l0 > 0.1 else Vector2.ZERO
	var tq: float = floorf(t * 8.0)
	for j in k0:
		var h := _h(a.x + j, a.y + tq)
		if h > 0.55:
			_px(a.lerp(b, (j + h) / maxf(1.0, k0)) + nrm * (h - 0.75) * 10.0, 1.0 + floor(h * 2.0), c)


func _px_ring(o: Vector2, r: float, c: Color, _dots: int = 0) -> void:
	draw_arc(o, r, 0.0, TAU, maxi(24, int(r / 3.0)), Color(c.r, c.g, c.b, c.a * 0.8), 1.4, false)
	var n3 := maxi(6, int(TAU * r / 16.0))
	var tq: float = floorf(t * 8.0)
	for k in n3:
		var h := _h(o.x + k, o.y + tq)
		if h > 0.5:
			var ang := TAU * (k + h) / n3
			_px(o + Vector2.from_angle(ang) * (r + (h - 0.75) * 12.0), 1.0 + floor(h * 2.0), c)


# The body's outline in the enemies' own geometry (local, facing +x), a third larger.
func _shape(kind: int) -> PackedVector2Array:
	var r: float = Enemies.SPEC[kind].r * 1.3
	var pts := PackedVector2Array()
	match kind:
		Enemies.CHASER:
			pts = [Vector2(r * 1.25, 0), Vector2(-r * 0.85, -r * 0.85), Vector2(-r * 0.85, r * 0.85)]
		Enemies.CHARGER:
			pts = [Vector2(r * 1.45, 0), Vector2(0, -r * 0.8), Vector2(-r, 0), Vector2(0, r * 0.8)]
		_:
			var n: int = Enemies.SPEC[kind].sides
			var off := PI / 4.0 if kind == Enemies.GUARD else 0.0
			for k in n:
				pts.append(Vector2.from_angle(off + TAU * k / n) * r)
	return pts


const _KIND_OF := {"chaser": Enemies.CHASER, "leech": Enemies.LEECH, "guard": Enemies.GUARD, "charger": Enemies.CHARGER,
	"prism": Enemies.PRISM, "pulse": Enemies.PULSE, "echo": Enemies.ECHO}


# Invade: the enemy keeps its own clean line shape, but pixels eat it from the
# core outward — the outline breaks into pixel runs (more of it the further the
# growth has gone), a pixel body shows through, and a fringe of loose pixels
# dithers the border between the two worlds.
func _part(name: String, at: Vector2, angle: float, mod: Color) -> void:
	var parts := name.split("_")
	var kind: int = _KIND_OF[parts[0]]
	var a := mod.a
	if parts.size() > 1:
		# the spikes are pure pixel growth
		var p: PixelPart = _parts[name]
		p.draw(self, Transform2D(0.0, Vector2(PX, PX), 0.0, (at / PX).round() * PX), Vector2.ZERO, angle, false, mod)
		return
	var hot: bool = mod.r > 2.0
	# the pixel body underneath, at the outline's own size
	var body: PixelPart = _parts[name]
	body.draw(self, Transform2D(0.0, Vector2(PX, PX), 0.0, (at / PX).round() * PX), Vector2.ZERO, angle, false, Color(mod.r, mod.g, mod.b, a * 0.92))
	# the enemy's own outline, being eaten
	var tr := Transform2D(angle, at)
	var local := _shape(kind)
	var eat := clampf(0.15 + 0.3 * grow, 0.0, 0.45)
	var tq: float = floorf(t * 5.0)
	var line_c := Pal.ink(a, 2.2) if hot else Pal.ink(0.95 * a, 1.5).lerp(cyan(a, 2.0), 0.15)
	for k in local.size():
		var p0: Vector2 = tr * local[k]
		var p1: Vector2 = tr * local[(k + 1) % local.size()]
		var segs := maxi(3, int(p0.distance_to(p1) / 7.0))
		for j in segs:
			var q0 := p0.lerp(p1, float(j) / segs)
			var q1 := p0.lerp(p1, float(j + 1) / segs)
			var h := _h(k * 17.0 + j, tq + kind)
			if h > eat:
				draw_line(q0, q1, line_c, 2.0)
			else:
				# this run has gone over to pixels
				var m := (q0 + q1) * 0.5
				draw_rect(Rect2((m / 3.0).floor() * 3.0 - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), cyan(a, 2.3))
				if h < eat * 0.4:
					var out := (m - at).normalized() * (3.0 + 6.0 * h / maxf(eat, 0.01))
					draw_rect(Rect2(((m + out) / 3.0).floor() * 3.0, Vector2(3.0, 3.0)), cyan(0.7 * a, 2.0))
	# loose pixels drifting off the border
	var r: float = Enemies.SPEC[kind].r * 1.3
	for j in 8:
		var h2 := _h(j * 3.1 + kind, tq)
		var ang := TAU * h2 + angle
		var rr := r * (1.05 + 0.5 * _h(j, tq + 7.0))
		draw_rect(Rect2(((at + Vector2.from_angle(ang) * rr) / 3.0).floor() * 3.0, Vector2(3.0, 3.0)), cyan(0.55 * a * h2, 2.0))


# Feeds the floor shader: the shell infects the dots around it, its trail heals
# back over a second and a half, landings and finishers leave a wide patch.
func _update_infection(dt: float) -> void:
	var i := 0
	while i < residue.size():
		residue[i][2] -= dt
		if residue[i][2] <= 0.0:
			residue.remove_at(i)
		else:
			i += 1
	if state == HOST:
		residue_cd -= dt
		if residue_cd <= 0.0:
			residue_cd = 0.1
			residue.append([shell.pos, 70.0, 1.2, 1.2])
			if residue.size() > 7:
				residue.remove_at(0)
	var src: Array[Vector4] = []
	if state == HOST:
		src.append(Vector4(shell.pos.x, shell.pos.y, 120.0 + 20.0 * grow, clampf(grow * 1.2, 0.0, 1.0)))
	for rs in residue:
		src.append(Vector4(rs[0].x, rs[0].y, rs[1], 0.6 * rs[2] / rs[3]))
	while src.size() < 8:
		src.append(Vector4(0, 0, 0, 0))
	src.resize(8)
	game.floor_mat.set_shader_parameter("infect", src)


func infect_patch(at: Vector2, radius: float) -> void:
	residue.push_front([at, radius, 0.9, 0.9])
	if residue.size() > 7:
		residue.pop_back()


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
		_px_line(wa - wv.normalized() * 34.0, wa, cyan(1.0 - w[2] / w[4], 2.4), 1.0)
	for bst in bursts:
		var bk: float = bst[2] / 0.4
		_px_ring(bst[0], bst[1] * Pal.ease_out(bk), cyan(1.0 - bk, 2.4))
	for l in lanes:
		var la: float = 1.0 - l[2] / 3.0
		_px_line(l[0], l[1], Pal.red(0.5 * la, 2.0), 1.0)
	for al in afterlines:
		var aa: float = 1.0 - al[2] / 0.3
		_px_line(al[0], al[1], cyan(0.7 * aa, 2.2), 2.0)
	for bm in beams:
		var ba: float = 1.0 - bm[2] / 0.18
		_px_line(bm[0], bm[1], cyan(ba, 2.6), 2.0 if bm[2] < 0.05 else 1.0)
	if state != HOST or shell == null:
		return
	for c in clones:
		_part("echo", c.pos, shell.rot, Color(0.6, 1.7, 1.9, 0.55 if c.replay else 0.35))
		if not c.replay and c.path.size() > 1:
			var pth: PackedVector2Array = c.path
			for j in range(0, pth.size() - 1, 6):
				_px(pth[j], 1.0, cyan(0.25))
	if shell.kind == Enemies.CHARGER and winding:
		var hh: Dictionary = game.arena.raycast(shell.pos, shell.pos + aim * 1600.0)
		var end: Vector2 = hh.point if hh else shell.pos + aim * 1600.0
		var lane: float = shell.pos.distance_to(end)
		var off := fmod(t * 160.0, 22.0)
		var at2 := 30.0 + off
		while at2 < lane:
			_px_line(shell.pos + aim * at2, shell.pos + aim * minf(at2 + 10.0, lane), cyan(0.35 + 0.4 * minf(wind / 0.4, 1.0), 2.0), 1.0)
			at2 += 22.0
	if shell.kind == Enemies.PULSE:
		var bf: float = game.sfx.beat_frac()
		_px_ring(shell.pos, lerpf(70.0, 30.0, bf), cyan(0.15 + 0.5 * (1.0 if on_beat_now() else 0.0), 2.0), 24)
	var pos: Vector2 = shell.pos
	var kind_name: String = NAMES[shell.kind]
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
	var draw_rot: float = shell.rot
	if leap_t >= 0.0:
		var lk := clampf(leap_t / LEAP_TIME, 0.0, 1.0)
		shake.y -= sin(lk * PI) * 70.0
		_px_ring(leap_to, BLINK_SLAM_R * (1.0 - 0.6 * lk), cyan(0.3 + 0.5 * lk, 2.0))
	_part(kind_name, pos + shake, draw_rot, mod)
	if shell.kind == Enemies.GUARD:
		# the raised shield: a thick pixel arc toward the aim
		for j in 9:
			var aa := aim.angle() + lerpf(-0.9, 0.9, j / 8.0)
			_px(pos + Vector2.from_angle(aa) * 36.0, 2.0, cyan(0.9, 2.2))
	if grow > 0.35:
		_part(kind_name + ("_spk2" if grow > 0.75 else "_spk1"), pos + shake, shell.rot, Color(mod.r * 1.2, mod.g * 1.2, mod.b * 1.2, mod.a))
	# time left: a ring of pixels that empties; hits left: three pips under it
	var frac := clampf(t_left / duration(), 0.0, 1.0)
	var dots := 28
	var lit := int(ceil(dots * frac))
	var hot := t_left < 1.5 and int(t * 10.0) % 2 == 0
	for j in dots:
		var on := j < lit
		_px(pos + Vector2.from_angle(-PI / 2.0 + TAU * j / dots) * 44.0, 1.0, (Pal.red(0.75, 1.8) if hot else cyan(0.6, 1.5)) if on else cyan(0.1))
	for j in SHELL_HITS:
		_px(pos + Vector2((j - 1) * 8.0, 54.0), 2.0, cyan(0.6, 1.6) if j < hits_left else cyan(0.1))


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
