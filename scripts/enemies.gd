class_name Enemies
extends Node2D
# Chasers swarm in straight lines, guards hold a shield toward you, chargers
# wind up and dash. Every body is a white polygon whose edges break away as
# its armour goes; it shatters into those edges when it dies.

enum { WARN, SPAWN, ALIVE, DEAD, HOST }   # HOST: seized by you (Possess drives it)
enum { CHASER, GUARD, CHARGER, PRISM, LEECH, PULSE, ECHO, INSPECTOR, PROOFREADER, ESCORT, PHASE,
	COUPLER, SIGNAL, QUEUE, QSEG, REGISTRAR, TURNSTILE, HOUND, DUD, BYSTANDER }
enum { APPROACH, WINDUP, DASH, STUN, RECOVER }

const SPEC := {
	CHASER: {"hp": 30.0, "r": 14.0, "sides": 3, "speed": 245.0},
	GUARD: {"hp": 140.0, "r": 22.0, "sides": 4, "speed": 72.0},
	CHARGER: {"hp": 60.0, "r": 18.0, "sides": 4, "speed": 100.0},
	PRISM: {"hp": 50.0, "r": 22.0, "sides": 3, "speed": 55.0},
	LEECH: {"hp": 45.0, "r": 16.0, "sides": 5, "speed": 125.0},
	PULSE: {"hp": 70.0, "r": 19.0, "sides": 6, "speed": 0.0},
	ECHO: {"hp": 40.0, "r": 13.0, "sides": 8, "speed": 0.0},
	INSPECTOR: {"hp": 55.0, "r": 23.0, "sides": 4, "speed": 110.0},
	PROOFREADER: {"hp": 50.0, "r": 27.0, "sides": 5, "speed": 125.0},
	ESCORT: {"hp": 26.0, "r": 12.0, "sides": 3, "speed": 520.0},
	PHASE: {"hp": 48.0, "r": 21.0, "sides": 6, "speed": 150.0},
	# chapter 1, the yard: chained pairs and the signalman
	COUPLER: {"hp": 28.0, "r": 20.0, "sides": 14, "speed": 235.0},
	SIGNAL: {"hp": 40.0, "r": 13.0, "sides": 4, "speed": 90.0},
	# chapter 2, the registration hall: the queue, the registrar, the turnstile
	QUEUE: {"hp": 40.0, "r": 18.0, "sides": 5, "speed": 190.0},
	QSEG: {"hp": 20.0, "r": 12.0, "sides": 4, "speed": 190.0},
	REGISTRAR: {"hp": 70.0, "r": 23.0, "sides": 8, "speed": 90.0},
	TURNSTILE: {"hp": 80.0, "r": 18.0, "sides": 6, "speed": 60.0},
	# chapter 3, the ordnance institute: the hound, the dud, the passers-by
	HOUND: {"hp": 55.0, "r": 19.0, "sides": 6, "speed": 210.0},
	DUD: {"hp": 35.0, "r": 20.0, "sides": 5, "speed": 70.0},
	BYSTANDER: {"hp": 1.0, "r": 11.0, "sides": 12, "speed": 80.0},
}
# each chapter's own enemies wear that chapter's colour (red stays for danger alone)
const RUST := Color(1.0, 0.52, 0.2)      # chapter 1, the yard
const FILE_BLUE := Color(0.36, 0.62, 1.0)  # chapter 2, the registration hall
const STERILE := Color(0.3, 1.0, 0.62)     # chapter 3, the institute
const ACCENT := {COUPLER: RUST, SIGNAL: RUST, QUEUE: FILE_BLUE, QSEG: FILE_BLUE, REGISTRAR: FILE_BLUE, TURNSTILE: FILE_BLUE,
	HOUND: STERILE, DUD: STERILE, BYSTANDER: STERILE}
const CHAIN_MIN := 140.0      # a coupled pair's chain goes taut between these
const CHAIN_MAX := 290.0
const CHAIN_WARN := 0.5
const SIGNAL_R := 360.0       # the signalman's "away!" reaches this far
const STAMP := Vector2(140, 140)
const STAMP_WARN := 0.9
const INK_TIME := 4.0
const ARM := 46.0             # a turnstile's arms, beyond its hub
const LEAP := 340.0           # a hound's leap
const LEAP_T := 0.35
const FUSE := 1.8
const FUSE_R := 140.0
const BLAST_DUD := 60.0
const WARN_TIME := 0.55
const SPAWN_TIME := 0.6
const SHIELD_R := 36.0
const SHIELD_HALF := 1.05
const WINDUP_TIME := 0.8
const DASH_SPEED := 1150.0

class E:
	var id := 0
	var kind := 0
	var state := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var knock := Vector2.ZERO
	var dazed := 0.0            # left reeling for you to seize: it does nothing
	var hp := 1.0
	var maxhp := 1.0
	var r := 14.0
	var sides := 3
	var speed := 100.0
	var rot := 0.0
	var face := Vector2.RIGHT
	var t := 0.0
	var flash := 0.0
	var squash := 0.0
	var squash_dir := Vector2.RIGHT
	var seed := 0.0
	var offs: Array = []
	var red := 0.0
	var mode := 0
	var mode_t := 0.0
	var cool := 0.0
	var dash_dir := Vector2.RIGHT
	var shield_flash := 0.0
	var ghosts: Array = []
	var pass_hits := 0
	var anchor = null
	var grip = null             # Grip: what a leech's stolen rounds orbit
	var last_beat := -1
	var burn := 0.0
	var lag := 2.5
	var orbit_a := 0.0
	var bounce := 0.0           # knocked hard by a seized shell: a wall throws it back
	var pinned := 0.0           # rammed into a wall by a seized guard: recalls cut it twice as hard
	var elite := false          # the harder way's: more of it, ringed red
	var seen_at := -1.0         # when it last had you in sight (generated rooms)
	var link = null             # a coupled pair's other half; a queue piece's one ahead
	var cut := false            # a pair's chain cut by a recall; a dud that has gone off
	var rush := 0.0             # a signalman's "away!": faster for a while
	var shunt := false          # chapter 1's chargers: twin-rail lane, a slide after the dash
	var aim_at := Vector2.ZERO  # where a hound will land; where a bystander is walking to
	var leap_from := Vector2.ZERO

var list: Array[E] = []
var game
var halo_tex: Texture2D
var next_id := 1
var fixes: Array = []        # a proofreader's corrections: [round, from, to, t]
var zones: Array = []        # ground danger: {c, size, t, warn, ink, hit, by}
var misfired_wave := -1      # (the broadcast about hitting a passer-by: once a wave)


func _ready() -> void:
	# above the rounds' trails and the walls, so a shell is never drawn under
	# the light passing through it
	z_index = 3
	z_as_relative = false
	halo_tex = Fx.make_glow_texture()


func remaining() -> int:
	var n := 0
	for e in list:
		if e.state != DEAD and e.state != HOST and e.kind != BYSTANDER:
			n += 1
	return n


func spawn(kind: int, pos: Vector2, delay: float = 0.0) -> E:
	var e := E.new()
	var s: Dictionary = SPEC[kind]
	e.id = next_id
	next_id += 1
	e.kind = kind
	e.state = WARN
	e.t = -delay
	e.pos = pos
	e.hp = s.hp
	e.maxhp = s.hp
	e.hp *= Loadout.enemy_hp() * Loadout.chapter_hp(game.chapter)
	e.maxhp = e.hp
	if game.wave_half:
		e.hp *= 0.5
	e.r = s.r
	e.sides = s.sides
	e.speed = s.speed * randf_range(0.92, 1.08)
	e.seed = randf() * 100.0
	e.face = (game.player.pos - pos).normalized()
	e.rot = e.face.angle()
	e.cool = randf_range(1.2, 2.4)
	if kind == LEECH:
		e.grip = Grip.new(e)
	if kind == ECHO:
		e.lag = randf_range(1.6, 3.4)
	if kind == CHARGER and Chapters.story(game.chapter) == 1:
		e.shunt = true
	if kind == BYSTANDER:
		# they walk across, to the far side of the room from where they came in
		e.aim_at = Arena.ROOM.get_center() * 2.0 - pos
	if kind == SIGNAL or kind == REGISTRAR:
		e.cool = randf_range(2.0, 3.0)
	for k in e.sides:
		e.offs.append([Vector2.from_angle(randf() * TAU) * randf_range(50, 90), randf_range(-2.5, 2.5)])
	list.append(e)
	return e


func make_elite(e: E) -> void:
	e.elite = true
	e.hp *= 2.2
	e.maxhp *= 2.2
	e.r *= 1.12


# ---------------------------------------------------------------- bullets

# Nearest guard shield crossed by a->b while travelling into its face.
func shield_hit(a: Vector2, b: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	var d := b - a
	for e in list:
		if e.kind != GUARD or e.state != ALIVE:
			continue
		if d.dot(e.face) >= 0.0:
			continue
		if e.pos.distance_to(a) > SHIELD_R + d.length() + 4.0:
			continue
		var p1 := e.pos + e.face.rotated(SHIELD_HALF) * SHIELD_R
		var p2 := e.pos + e.face.rotated(-SHIELD_HALF) * SHIELD_R
		var x = Geometry2D.segment_intersects_segment(a, b, p1, p2)
		if x != null:
			var l: float = a.distance_to(x)
			if l < bd:
				bd = l
				best = {"point": x, "normal": e.face, "e": e}
	return best


# An escort drone across a returning round's line: it takes the round.
func escort_hit(a: Vector2, b: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	for e in list:
		if e.kind != ESCORT or e.state != ALIVE or e.cool > 0.0:
			continue
		var q := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
		if q.distance_to(e.pos) <= e.r + 8.0:
			var d := a.distance_to(q)
			if d < bd:
				bd = d
				best = {"point": q, "e": e}
	return best


func on_escort(e: E, at: Vector2, dir: Vector2) -> void:
	e.cool = 1.4
	e.shield_flash = 1.0
	e.knock += dir * 260.0
	game.fx.sparks(at, -dir, 8, Pal.foe(1.0, 2.0), 420.0, 0.22, 0.9)
	game.fx.ring(at, 6.0, 60.0, 0.3, Pal.ink(1.0, 2.2), 3.0)
	game.fx.flash(at, 30.0, 0.15, Pal.ink(0.8, 2.0))
	game.sfx.play("shield", randf_range(1.2, 1.35), -6.0)


# Prisms bend outbound rounds by a fixed 60 degrees (each prism has its own hand).
func prism_hit(a: Vector2, b: Vector2, bullet) -> Dictionary:
	var best := {}
	var bd := INF
	for e in list:
		if e.kind != PRISM or e.state != ALIVE or bullet.hit.has(e.id):
			continue
		var q := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
		if q.distance_to(e.pos) <= e.r:
			var d := a.distance_to(q)
			if d < bd:
				bd = d
				best = {"point": q, "e": e, "turn": PI / 3.0 * (1.0 if fmod(e.seed, 2.0) < 1.0 else -1.0)}
	return best


func on_prism(e: E, at: Vector2) -> void:
	e.shield_flash = 1.0
	game.fx.sparks(at, Vector2.from_angle(e.rot), 5, Pal.foe(1.0, 2.0), 360.0, 0.2, PI)
	game.sfx.play("cross", randf_range(1.2, 1.4), -10.0)


func on_shield(e: E, at: Vector2, dir: Vector2, ret: bool) -> void:
	e.shield_flash = 1.0
	e.knock += -e.face * (70.0 if ret else 40.0)
	game.fx.sparks(at, e.face, 6, Pal.foe(1.0, 1.9), 420.0, 0.22, 0.9)
	game.fx.flash(at, 18.0, 0.1, Pal.foe(0.35, 1.3))
	game.sfx.play("shield", randf_range(0.92, 1.1), -6.0)
	game.cam.add_trauma(0.03)


func sweep(a: Vector2, b: Vector2, bullet, ret: bool) -> void:
	if ret:
		_cut_chains(a, b)
	for e in list:
		if e.state != ALIVE or bullet.hit.has(e.id):
			continue
		if e.kind == HOUND and e.mode == 2:
			continue
		if e.kind == PHASE and phased(e):
			# it passes through: a glint where it crossed
			if not bullet.hit.has(-e.id):
				var qp := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
				if qp.distance_to(e.pos) <= e.r + 3.0:
					bullet.hit[-e.id] = true
					game.fx.ring(qp, 3.0, e.r * 1.4, 0.22, Pal.foe(0.6, 1.5), 1.2)
					game.fx.flash(qp, 14.0, 0.08, Pal.foe(0.4, 1.4))
			continue
		var q := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
		if q.distance_to(e.pos) <= e.r + 3.0:
			bullet.hit[e.id] = true
			if ret:
				game.possess.mark(e)
			var d: Vector2 = (b - a).normalized() if b.distance_squared_to(a) > 0.01 else bullet.dir
			var dmg: float = bullet.dmg * (game.ret_mult() if ret else game.out_mult())
			if game.has("hunter") and e.hp >= e.maxhp:
				dmg *= 1.0 + game.sv("hunter") / 100.0
			if ret and bullet.first_bonus:
				bullet.first_bonus = false
				dmg *= game.sv("zero_point")
			if not ret and game.has("sniper"):
				dmg *= 1.0 + game.sv("sniper") / 100.0 * bullet.total() / 100.0
			if e.kind == PULSE:
				# its shell is open just after each beat
				dmg *= 1.5 if game.sfx.beat_frac() < 0.35 else 0.25
			if ret and e.pinned > 0.0:
				dmg *= 2.0
			if ret:
				dmg *= game.possess.lane_bonus(q)
			if ret and game.has("afterburn"):
				e.burn = game.sv("afterburn")
			if game.first_blood_ready:
				game.first_blood_ready = false
				dmg *= game.sv("first_blood")
				game.hud.flash_text(Cards.relic_name("first_blood"), e.pos)
			if ret:
				if game.pass_first == null:
					game.pass_first = e
				bullet.charge += 1
				bullet.last_hit = q
				if game.lv.blast >= 3:
					game.fx.ring(q, 4.0, 34.0, 0.2, Pal.red(0.8, 2.4), 1.5)
					for o in list:
						if o != e and o.state == ALIVE and o.pos.distance_to(q) < 34.0 + o.r:
							blast_hit(o, (o.pos - q).normalized(), 15.0)
			# (the one a recall would finish is left reeling, for you to seize)
			if ret and game.possess.spare(e, dmg):
				dmg = maxf(0.0, e.hp - 1.0)
			if dmg > 0.0:
				_hit(e, dmg, d, q, ret)
			if ret and game.lv.magnet >= 3 and e.state == ALIVE:
				# magnet lv3: a returning round drags what it pierces
				e.knock += d * 420.0
			if ret and game.lv.chain > 0:
				_chain(e, dmg)
			if ret and e.state == ALIVE:
				e.pass_hits += 1
				if e.pass_hits == 3:
					game.crosses += 1
					if Meta.count("cross") >= 50:
						game.ach("cross50")
				if e.pass_hits == 3 and game.has("crossfire"):
					# Crossfire: the third line through one body detonates
					game.fx.ring(e.pos, 6.0, 70.0, 0.3, Pal.red(1.0, 2.6), 2.5)
					game.sfx.play("cross", 1.0, -2.0)
					game.hud.flash_text(Txt.t("crossfire"), e.pos)
					_hit(e, game.sv("crossfire"), d, e.pos, true)
			if bullet.state != Bullets.ORBIT:
				game.bullets.on_enemy_hit(bullet, q, d, ret)


func _edges_left(e: E) -> int:
	return ceili(clampf(e.hp / e.maxhp, 0.0, 1.0) * e.sides - 0.001)


func _hit(e: E, dmg: float, dir: Vector2, at: Vector2, ret: bool) -> void:
	if e.kind == BYSTANDER:
		_misfire(e)
		return
	var before := _edges_left(e)
	e.hp -= dmg
	var after := _edges_left(e)
	e.flash = 1.0
	e.squash = 1.0
	e.squash_dir = dir
	var kb := 1.0 if e.kind == CHASER else (0.35 if e.kind == GUARD else 0.6)
	e.knock += dir * (300.0 if ret else 150.0) * kb
	if ret:
		e.red = 1.0
	if e.hp > 0.0:
		var pts := _poly(e)
		var tr := Transform2D(e.rot, e.pos)
		for k in range(after, before):
			var mid := (pts[k] + pts[k + 1]) * 0.5
			var wm := tr * mid
			var out := (wm - e.pos).normalized()
			game.fx.shard(wm, (pts[k] - mid) * 0.45, (pts[k + 1] - mid) * 0.45, out * randf_range(140, 220) + dir * 160.0, randf_range(-10, 10), 0.55, Pal.foe(0.9, 1.3), 2.0)
	game.fx.number(at, dmg, ret)
	var c := Pal.red(1.0, 3.2) if ret else Pal.foe(1.0, 1.8)
	game.fx.sparks(at, dir, 7 if ret else 4, c, 520.0 if ret else 380.0, 0.26, 0.7)
	if Fx.PIXEL_HITS:
		game.fx.pixel("spark", at, 2.0, 1.4, dir.x < 0.0)
	game.fx.sparks(at, -dir, 2, Pal.foe(0.8, 1.4), 200.0, 0.2, 1.2)
	game.fx.flash(at, 30.0 if ret else 22.0, 0.14, Color(c.r, c.g, c.b, 0.35))
	game.on_target_hit(ret)
	if e.hp <= 0.0:
		var excess := -e.hp
		_die(e, dir)
		if game.has("overkill") and excess > 1.0:
			# the leftover jumps to the nearest enemy
			var best: E = null
			var bd := 220.0
			for o in list:
				if o.state == ALIVE and o.pos.distance_to(e.pos) < bd:
					bd = o.pos.distance_to(e.pos)
					best = o
			if best != null:
				game.fx.spark(e.pos, (best.pos - e.pos).normalized() * 900.0, 0.15, Pal.red(1.0, 2.6), 2.0, 20.0)
				blast_hit(best, (best.pos - e.pos).normalized(), excess * game.sv("overkill") / 100.0)
		if ret and game.pass_active:
			game.on_pass_kill(e.pos)


# Chain school: a returning hit arcs on to the next body nearby.
func _chain(from: E, dmg: float) -> void:
	var lvl: int = game.lv.chain
	var frac: float = [0.0, 0.5, 0.6, 0.75][lvl]
	var done := {from.id: true}
	var cur := from
	for j in lvl:
		var best: E = null
		var bd := 150.0
		for o in list:
			if o.state == ALIVE and not done.has(o.id) and o.pos.distance_to(cur.pos) < bd:
				bd = o.pos.distance_to(cur.pos)
				best = o
		if best == null:
			return
		done[best.id] = true
		# a jagged arc between the two
		var a := cur.pos
		var b := best.pos
		var prev := a
		for k in 5:
			var p := a.lerp(b, (k + 1) / 5.0) + ((b - a).orthogonal().normalized() * randf_range(-10, 10) if k < 4 else Vector2.ZERO)
			game.fx.spark(prev, (p - prev) * 0.0001, 0.18, Pal.red(1.0, 2.6), 2.0, prev.distance_to(p))
			prev = p
		game.fx.ring(b, 4.0, 22.0, 0.2, Pal.red(0.9, 2.4), 1.5)
		blast_hit(best, (b - a).normalized(), dmg * frac)
		cur = best


# Blast school / Echo / Singularity damage: plain, no chain of its own.
func blast_hit(e: E, dir: Vector2, dmg: float, show_number: bool = true) -> void:
	if e.kind == BYSTANDER:
		return
	if e.kind == PHASE and phased(e):
		return
	e.hp -= dmg
	e.flash = 1.0
	e.knock += dir * 220.0
	if show_number:
		game.fx.number(e.pos, dmg, true)
	if e.hp <= 0.0:
		_die(e, dir)


# A light scar's burn: hurts in place, no shove.
func burn_hit(e: E, dir: Vector2, dmg: float) -> void:
	if e.kind == BYSTANDER:
		return
	if e.kind == PHASE and phased(e):
		return
	e.hp -= dmg
	e.flash = 1.0
	game.fx.sparks(e.pos, dir, 2, Pal.red(0.9, 2.2), 180.0, 0.14, 0.8)
	if e.hp <= 0.0:
		_die(e, dir)


# Aftershock damage: no recall bonus and no chain of its own.
func aftershock_hit(e: E, dir: Vector2) -> void:
	if e.kind == BYSTANDER:
		return
	var dmg: float = game.sv("aftershock")
	e.hp -= dmg
	e.flash = 1.0
	e.knock += dir * 260.0
	game.fx.number(e.pos, dmg, true)
	if e.hp <= 0.0:
		_die(e, dir)


func _die(e: E, dir: Vector2) -> void:
	e.state = DEAD
	_died(e)
	if e.kind == INSPECTOR:
		var n := 0
		for b in game.bullets.list:
			if b.dark_by == e.id:
				b.dark_by = 0
				n += 1
				game.fx.flash(b.pos, 26.0, 0.18, Pal.ink(0.7, 2.0))
		if n > 0:
			game.sfx.play("lit", 1.2, -6.0)
		game.lore.on_inspector_down(e.pos)
	if e.kind == PROOFREADER:
		game.lore.on_kind_down(PROOFREADER, e.pos)
	if e.kind == ESCORT:
		game.lore.on_kind_down(ESCORT, e.pos)
	if e.grip != null:
		if game.bullets.held_by(e.grip).size() >= 4:
			game.ach("leech4")
		e.grip.alive = false
		for b in game.bullets.held_by(e.grip):
			game.bullets.drop(b)
		game.sfx.play("mend", 1.3, -6.0)
	var tr := Transform2D(e.rot, e.pos)
	var col := Pal.foe(0.85, 1.2).lerp(Pal.red(1.0, 2.6), e.red)
	var pts := _poly(e)
	# its tubes go out where it stood, as the pieces fly
	var ghost := PackedVector2Array()
	for k in e.sides + 1:
		ghost.append(tr * pts[k % e.sides])
	game.fx.power_off(ghost, Pal.foe(1.0, 1.6), 0.7)
	for k in e.sides:
		var a := pts[k]
		var b := pts[k + 1]
		var mid := (a + b) * 0.5
		var out := tr.basis_xform(mid).normalized()
		var vel := out * randf_range(160, 320) + dir * randf_range(180, 360)
		game.fx.shard(tr * mid, tr.basis_xform(a - mid), tr.basis_xform(b - mid), vel, randf_range(-9, 9), randf_range(0.6, 0.95), col, 2.0)
	if e.kind == GUARD:
		for k in 3:
			var a2 := Vector2.from_angle(lerpf(-SHIELD_HALF, SHIELD_HALF, k / 3.0) + e.face.angle()) * SHIELD_R
			var b2 := Vector2.from_angle(lerpf(-SHIELD_HALF, SHIELD_HALF, (k + 1) / 3.0) + e.face.angle()) * SHIELD_R
			var m2 := (a2 + b2) * 0.5
			game.fx.shard(e.pos + m2, a2 - m2, b2 - m2, m2.normalized() * randf_range(200, 300) + dir * 200.0, randf_range(-8, 8), 0.8, Pal.foe(1.0, 1.4), 4.0)
	game.fx.ring(e.pos, e.r * 0.6, e.r * 4.0, 0.45, col, 2.0)
	game.fx.ring(e.pos, e.r * 0.3, e.r * 2.2, 0.3, Pal.foe(0.6), 1.0)
	# (a short flash: the tube's outline going out has to read through it)
	game.fx.flash(e.pos, e.r * 2.0, 0.12, Color(col.r, col.g, col.b, 0.08))
	game.fx.sparks(e.pos, dir, 10 + e.sides * 2, col, 700.0, 0.4, 1.3)
	if Fx.PIXEL_ELITE and e.red > 0.5:
		game.fx.pixel("zap", e.pos, 2.0, 1.6, dir.x < 0.0)
	game.on_target_die(e.pos, e.kind)


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	var pl: Vector2 = game.player.pos
	_step_fixes(dt)
	_step_zones(dt, pl)
	var i := 0
	while i < list.size():
		var e := list[i]
		if e.state == DEAD:
			list.remove_at(i)
			continue
		e.t += dt
		e.flash = maxf(0.0, e.flash - dt / 0.12)
		if e.burn > 0.0 and e.state == ALIVE:
			# Afterburn: 6 damage a second while it lasts
			e.burn -= dt
			e.hp -= 6.0 * dt
			if e.hp <= 0.0:
				_die(e, Vector2.UP)
		e.squash = maxf(0.0, e.squash - dt / 0.22)
		e.red = maxf(0.0, e.red - dt / 1.2)
		e.pinned = maxf(0.0, e.pinned - dt)
		e.rush = maxf(0.0, e.rush - dt)
		e.shield_flash = maxf(0.0, e.shield_flash - dt / 0.2)
		var j := 0
		while j < e.ghosts.size():
			e.ghosts[j][1] += dt
			if e.ghosts[j][1] > 0.25:
				e.ghosts.remove_at(j)
			else:
				j += 1
		match e.state:
			WARN:
				if e.t >= WARN_TIME:
					e.state = SPAWN
					e.t = 0.0
					game.sfx.play("spawn", randf_range(0.95, 1.08) * (0.8 if e.kind != CHASER else 1.0), -12.0)
			SPAWN:
				e.rot = lerp_angle(e.rot, e.face.angle(), 1.0 - exp(-6.0 * dt))
				if e.t >= SPAWN_TIME:
					e.state = ALIVE
					e.t = 0.0
					game.fx.ring(e.pos, e.r, e.r * 2.0, 0.35, Pal.foe(0.7, 1.3), 1.5)
					game.fx.flash(e.pos, e.r * 2.5, 0.2, Pal.foe(0.5, 1.2))
			ALIVE:
				if e.dazed > 0.0:
					e.dazed -= dt
					e.vel = Vector2.ZERO
				match -1 if e.dazed > 0.0 else e.kind:
					PRISM:
						if e.anchor != null and e.anchor.alive():
							# circling the warden
							e.orbit_a += 0.9 * dt
							var want: Vector2 = e.anchor.pos + Vector2.from_angle(e.orbit_a) * 170.0
							e.vel = (want - e.pos) * 6.0
						else:
							var ang := sin(e.t * 0.31 + e.seed) * 2.2 + cos(e.t * 0.19 + e.seed * 1.3) * 1.5
							# (in a generated room, out of sight it drifts round to where you are)
							e.vel = Pal.damp2(e.vel, _steer(e, _seek(e, game.player.pos, Vector2.from_angle(ang))) * e.speed, 1.5, dt)
						e.rot += (0.5 if fmod(e.seed, 2.0) < 1.0 else -0.5) * dt
					LEECH:
						_leech(e, pl, dt)
					INSPECTOR:
						_inspector(e, pl, dt)
					PROOFREADER:
						_proofreader(e, pl, dt)
					ESCORT:
						_escort(e, pl, dt)
					PHASE:
						_phaser(e, pl, dt)
					PULSE:
						_pulse(e, pl, dt)
					ECHO:
						# it walks where you walked a few seconds ago
						var want: Vector2 = game.trail_at(e.lag)
						e.vel = (want - e.pos) / maxf(dt, 0.001)
						e.vel = e.vel.limit_length(560.0)
						if e.vel.length() > 5.0:
							e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-12.0 * dt))
					CHASER:
						_chaser(e, pl, dt)
					GUARD:
						_guard(e, pl, dt)
					CHARGER:
						_charger(e, pl, dt)
					COUPLER:
						_coupler(e, pl, dt)
					SIGNAL:
						_signal(e, pl, dt)
					QUEUE:
						_queue_head(e, pl, dt)
					QSEG:
						_queue_seg(e, dt)
					REGISTRAR:
						_registrar(e, pl, dt)
					TURNSTILE:
						_turnstile(e, pl, dt)
					HOUND:
						_hound(e, pl, dt)
					DUD:
						_dud(e, pl, dt)
						if e.state == DEAD:
							i += 1
							continue
					BYSTANDER:
						_bystander(e, dt)
				if e.kind != QSEG and e.kind != BYSTANDER and not (e.kind == HOUND and e.mode == 2):
					_separate(e, dt)
				if game.focusing and game.has("gravity"):
					_gravity(e, dt)
				if game.lv.magnet > 0:
					_magnet(e, dt)
				var spd: float = game.enemy_speed() * game.stasis.slow_at(e.pos)
				if e.rush > 0.0:
					spd *= 1.35
				if e.kind == HOUND and e.mode == 2:
					spd = 1.0
				if game.has("magnetic_tip") and _near_round(e.pos, 120.0):
					spd *= 1.0 - game.sv("magnetic_tip") / 100.0
				var intended: Vector2 = e.pos + (e.vel * spd + e.knock) * dt
				e.knock *= exp(-7.0 * dt)
				e.pos = game.arena.push_circle(intended, e.r)
				e.pos = e.pos.clamp(Arena.ROOM.position + Vector2(e.r, e.r), Arena.ROOM.end - Vector2(e.r, e.r))
				if e.bounce > 0.0:
					e.bounce -= dt
					if e.pos.distance_to(intended) > 2.0 and e.knock.length() > 150.0:
						# thrown into a wall by a seized shell: it bounces back and takes more
						var n := (e.pos - intended).normalized()
						e.knock = e.knock.bounce(n) * 0.6
						e.bounce = 0.0
						game.possess.wall_slam(e, e.pos - n * e.r, n)
						if e.state == DEAD:
							i += 1
							continue
				if e.kind == CHARGER and e.mode == DASH and e.pos.distance_to(intended) > 2.0:
					_slam(e)
				_contact(e, pl)
		i += 1
	queue_redraw()


func _near_round(p: Vector2, r: float) -> bool:
	for b in game.bullets.list:
		if b.state == Bullets.EMBED and b.pos.distance_squared_to(p) < r * r:
			return true
	return false


# Magnet school: embedded rounds keep a weak pull on anything close.
func _magnet(e: E, dt: float) -> void:
	var lvl: int = game.lv.magnet
	var reach := 120.0 if lvl == 1 else 180.0
	var pull := 120.0 if lvl == 1 else 220.0
	for b in game.bullets.list:
		if b.state == Bullets.EMBED:
			var dv: Vector2 = b.pos - e.pos
			var d := dv.length()
			if d < reach and d > 1.0:
				e.knock += dv / d * pull * (1.0 - d / reach) * dt * 4.0


# Gravity Well: lit rounds in the walls drag nearby bodies toward them.
func _gravity(e: E, dt: float) -> void:
	var best := Vector2.ZERO
	var bd := 220.0
	for b in game.bullets.list:
		if b.state == Bullets.EMBED and b.light > 0.0:
			var d: float = b.pos.distance_to(e.pos)
			if d < bd:
				bd = d
				best = b.pos
	if best != Vector2.ZERO:
		e.knock += (best - e.pos).normalized() * 900.0 * (1.0 - bd / 220.0) * dt * 6.0


# Pulses move only on the beat: a hop toward you, then stillness.
func _pulse(e: E, pl: Vector2, dt: float) -> void:
	var bi := int(floor(game.sfx.beat()))
	e.vel = Pal.damp2(e.vel, Vector2.ZERO, 9.0, dt)
	if bi != e.last_beat:
		e.last_beat = bi
		var to := _steer(e, _route(e, pl))
		e.vel = to * 520.0
		e.squash = 1.0
		e.squash_dir = to
	e.rot += dt * 0.3


# Leeches swim to the nearest round in a wall and carry up to four away.
func _leech(e: E, pl: Vector2, dt: float) -> void:
	var held: int = game.bullets.held_by(e.grip).size()
	var target = null
	var td := 1200.0
	if held < 4:
		for b in game.bullets.list:
			if b.state == Bullets.EMBED:
				var d: float = b.pos.distance_to(e.pos)
				if d < td:
					td = d
					target = b
	var want := Vector2.ZERO
	if target != null:
		want = (target.pos - e.pos).normalized()
		if td < e.r + 10.0:
			game.bullets.capture(target, e.grip)
			game.fx.flash(target.pos, 20.0, 0.12, Pal.foe(0.5, 1.4))
			game.sfx.play("lit", 0.7, -10.0)
	else:
		# full, or nothing to take: keep away from you
		var away := e.pos - pl
		want = away.normalized() if away.length() < 420.0 else Vector2.from_angle(sin(e.t * 0.4 + e.seed) * 3.0)
	e.vel = Pal.damp2(e.vel, _steer(e, _seek(e, pl, want)) * e.speed * (0.7 if held >= 4 else 1.0), 3.0, dt)
	if e.vel.length() > 5.0:
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-6.0 * dt))


# The energy-saving inspector: walks to the nearest lit round of yours and
# puts it out (up to six); a dark round cannot be recalled until it falls.
const DIM_R := 95.0
const DIM_MAX := 6


func _inspector(e: E, pl: Vector2, dt: float) -> void:
	var mine := 0
	for b in game.bullets.list:
		if b.dark_by == e.id:
			mine += 1
	var target = null
	var td := 1400.0
	if mine < DIM_MAX:
		for b in game.bullets.list:
			if b.state == Bullets.EMBED and b.dark_by == 0 and not b.foe:
				var d: float = b.pos.distance_to(e.pos)
				if d < td:
					td = d
					target = b
	var want := Vector2.ZERO
	if target != null:
		want = (target.pos - e.pos).normalized()
		if td < DIM_R:
			target.dark_by = e.id
			target.light = 0.0
			game.fx.flash(target.pos, 22.0, 0.15, Pal.ink(0.3, 1.0))
			game.fx.ring(target.pos, 14.0, 2.0, 0.25, Pal.foe(0.7, 1.4), 1.5)
			game.sfx.play("tick", 0.6, -10.0)
	else:
		var away := e.pos - pl
		want = away.normalized() if away.length() < 380.0 else Vector2.from_angle(sin(e.t * 0.4 + e.seed) * 3.0)
	e.vel = Pal.damp2(e.vel, _steer(e, want) * e.speed, 3.0, dt)
	if e.vel.length() > 5.0:
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-6.0 * dt))


# The proofreader: walks to the nearest of your rounds it has not corrected,
# writes over it a moment, then moves it to another wall — farther from you.
# The line home is no longer the line you laid; what it corrects stays put.
const FIX_R := 80.0
const FIX_WRITE := 0.7
const FIX_SLIDE := 0.35
const FIX_SHOW := 1.8


func _proofreader(e: E, pl: Vector2, dt: float) -> void:
	e.cool = maxf(0.0, e.cool - dt)
	var target = e.anchor
	if target != null and (target.state != Bullets.EMBED or target.corrected):
		target = null
	if e.mode != 1 and target == null and e.cool <= 0.0:
		var td := 1400.0
		for b in game.bullets.list:
			if b.state == Bullets.EMBED and not b.foe and not b.corrected and b.dark_by == 0 and not _claimed(b, e):
				var d: float = b.pos.distance_to(e.pos)
				if d < td:
					td = d
					target = b
	e.anchor = target
	if e.mode == 1:
		e.mode_t += dt
		e.vel = Pal.damp2(e.vel, Vector2.ZERO, 8.0, dt)
		if target == null:
			e.mode = 0
		elif e.mode_t >= FIX_WRITE:
			_correct(e, target)
			e.mode = 0
			e.anchor = null
			e.cool = 1.4
		return
	var want := Vector2.ZERO
	if target != null:
		var d2: float = target.pos.distance_to(e.pos)
		want = _route(e, target.pos)
		if d2 < FIX_R:
			e.mode = 1
			e.mode_t = 0.0
			game.sfx.play("tick", 1.4, -12.0)
	else:
		var away := e.pos - pl
		want = away.normalized() if away.length() < 380.0 else Vector2.from_angle(sin(e.t * 0.4 + e.seed) * 3.0)
	e.vel = Pal.damp2(e.vel, _steer(e, want) * e.speed, 3.0, dt)
	if e.vel.length() > 5.0:
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-6.0 * dt))


# The escort drone: it keeps close round another enemy (or the ship) and,
# when one of your rounds is coming home at its ward, puts itself in the way.
# Having taken one it tumbles off for a moment before it can guard again.
const ESCORT_R := 58.0


func _escort(e: E, pl: Vector2, dt: float) -> void:
	e.cool = maxf(0.0, e.cool - dt)
	var ward = e.anchor
	if ward != null and (not (ward is E) or ward.state != ALIVE):
		ward = null
	if ward == null:
		var bd := INF
		for o in list:
			if o != e and o.kind != ESCORT and o.state == ALIVE:
				var d: float = o.pos.distance_to(e.pos)
				if d < bd:
					bd = d
					ward = o
		e.anchor = ward
	var wp: Vector2
	var wr := 20.0
	if ward != null:
		wp = ward.pos
		wr = ward.r
	elif game.boss.alive():
		wp = game.boss.core_pos()
		wr = 40.0
	else:
		wp = pl + Vector2.from_angle(e.seed) * 300.0
	e.orbit_a += 2.4 * dt
	var want: Vector2 = wp + Vector2.from_angle(e.orbit_a) * (ESCORT_R + wr)
	if e.cool <= 0.0:
		# a round coming home toward the ward: get between
		for b in game.bullets.list:
			if b.state != Bullets.RETURN or b.foe:
				continue
			var ahead: Vector2 = b.pos + b.dir * 420.0
			var q := Geometry2D.get_closest_point_to_segment(wp, b.pos, ahead)
			if q.distance_to(wp) < wr + 40.0 and b.pos.distance_to(wp) > wr + 30.0:
				want = wp + (b.pos - wp).normalized() * (wr + 26.0)
				break
	var to := want - e.pos
	e.vel = to.limit_length(e.speed if e.cool <= 0.0 else 160.0) if to.length() > 2.0 else Vector2.ZERO
	if e.vel.length() > 5.0:
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-10.0 * dt))


const PH_SOLID := 1.9
const PH_GONE := 1.6
const PH_TURN := 0.35         # the flicker at the end of each state


# A phaser: solid, then not. Its clock stands still in a held stasis field,
# so one caught there stays as it was.
func _phaser(e: E, pl: Vector2, dt: float) -> void:
	var sl: float = game.stasis.slow_at(e.pos)
	e.mode_t += dt * (0.12 if sl < 0.9 else 1.0)
	var span := PH_SOLID if e.mode == 0 else PH_GONE
	if e.mode_t >= span:
		e.mode = 1 - e.mode
		e.mode_t = 0.0
		game.fx.ring(e.pos, e.r, e.r * 2.2, 0.25, Pal.foe(0.5 if e.mode == 1 else 0.9, 1.4), 1.5)
		game.sfx.play("focus" if e.mode == 1 else "spawn", 1.6 if e.mode == 1 else 1.3, -16.0)
	var want := _steer(e, _route(e, pl))
	# it closes in while faint, and holds off a little while solid
	var sp := e.speed * (1.55 if e.mode == 1 else 0.8)
	e.vel = Pal.damp2(e.vel, want * sp, 3.0, dt)
	if e.vel.length() > 5.0:
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-8.0 * dt))


# 0 solid .. 1 faint (it flickers across in the last PH_TURN of each state).
func phase_k(e: E) -> float:
	var span := PH_SOLID if e.mode == 0 else PH_GONE
	var tk := clampf((e.mode_t - (span - PH_TURN)) / PH_TURN, 0.0, 1.0)
	return tk if e.mode == 0 else 1.0 - tk


func phased(e: E) -> bool:
	return phase_k(e) > 0.5


func _claimed(b, me: E) -> bool:
	for o in list:
		if o != me and o.kind == PROOFREADER and o.anchor == b:
			return true
	return false


# Pick another wall within reach, the farther from you the better.
func _correct(e: E, b) -> void:
	var best := Vector2.INF
	var bs := -INF
	var best_rect := -1
	for k in 16:
		var d := Vector2.from_angle(TAU * k / 16.0 + e.seed)
		var h: Dictionary = game.arena.raycast(e.pos, e.pos + d * 1600.0)
		if h.is_empty():
			continue
		var q: Vector2 = h.point
		var moved := q.distance_to(b.pos)
		if moved < 220.0 or moved > 760.0 or _near_corner(q):
			continue
		var score := q.distance_to(game.player.pos) + randf() * 120.0
		if score > bs:
			bs = score
			best = q
			best_rect = int(h.get("rect", -1))
	b.corrected = true
	if best == Vector2.INF:
		return
	b.shelf = game.shelves.shelf_of(best_rect) if game.shelves.active() else -1
	# it carries the round over in a red arc that bows in toward the room
	var mid: Vector2 = (b.pos + best) * 0.5
	var ctrl: Vector2 = mid + (Arena.ROOM.get_center() - mid).normalized() * 120.0
	fixes.append([b, b.pos, best, 0.0, ctrl])
	game.fx.flash(b.pos, 20.0, 0.12, Pal.red(0.5, 1.8))
	game.sfx.play("tick", 0.8, -8.0)


func _near_corner(q: Vector2) -> bool:
	var r := Arena.ROOM
	for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		if q.distance_to(c) < 90.0:
			return true
	return false


static func _arc(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	return a.lerp(c, u).lerp(c.lerp(b, u), u)


func _step_fixes(dt: float) -> void:
	var i := 0
	while i < fixes.size():
		var fx_: Array = fixes[i]
		var was: float = fx_[3]
		fx_[3] = was + dt
		var b = fx_[0]
		if was < FIX_SLIDE and b.state == Bullets.EMBED:
			var k: float = Pal.ease_io(clampf(fx_[3] / FIX_SLIDE, 0.0, 1.0))
			b.pos = _arc(fx_[1], fx_[4], fx_[2], k)
			b.set_head(b.pos)
			game.bullets.faint_dirty = true
			if fx_[3] >= FIX_SLIDE:
				game.fx.flash(b.pos, 24.0, 0.14, Pal.red(0.6, 2.0))
				game.fx.ring(b.pos, 4.0, 22.0, 0.25, Pal.red(0.8, 2.0), 1.5)
		if fx_[3] >= FIX_SHOW:
			fixes.remove_at(i)
		else:
			i += 1


# When a pillar stands between it and the target, head for the pillar corner that
# makes the shortest way round instead of rubbing along the face.
func _route(e: E, target: Vector2) -> Vector2:
	var direct := (target - e.pos).normalized()
	var h: Dictionary = game.arena.raycast(e.pos, target)
	if h.is_empty() or int(h.get("rect", -1)) < 0:
		return direct
	if game.arena.generated:
		# a generated room: the way round is found over the grid
		return game.arena.nav_dir(e.pos, target)
	var r: Rect2 = game.arena.rects[h.rect]
	if not Arena.ROOM.grow(-10.0).encloses(r):
		return direct
	var g := r.grow(e.r + 24.0)
	var best := Vector2.INF
	var bc := INF
	for c: Vector2 in [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]:
		# a corner it is already standing on is no help: go on to the next one
		if e.pos.distance_to(c) < e.r + 20.0:
			continue
		if not Arena.ROOM.has_point(c) or not game.arena.raycast(e.pos, c).is_empty():
			continue
		var cost := e.pos.distance_to(c) + c.distance_to(target)
		# prefer a corner from which the target can be seen
		if not game.arena.raycast(c, target).is_empty():
			cost += 400.0
		if cost < bc:
			bc = cost
			best = c
	if best == Vector2.INF:
		return direct
	return (best - e.pos).normalized()


# In a generated room a wall can stand between it and you: one that circles
# at a distance would circle there for ever, so it goes round to find you.
func _seek(e: E, pl: Vector2, want: Vector2) -> Vector2:
	if not game.arena.generated or game.arena.raycast(e.pos, pl).is_empty():
		return want
	return _route(e, pl)


func _steer(e: E, want: Vector2) -> Vector2:
	# in a generated room nothing waits out of sight for ever: five seconds
	# without a line to you and it comes round to find you, whatever it was doing
	if game.arena.generated:
		var now: float = game.sim_time
		if e.seen_at < 0.0 or game.arena.raycast(e.pos, game.player.pos).is_empty():
			e.seen_at = now
		elif now - e.seen_at > 5.0:
			want = game.arena.nav_dir(e.pos, game.player.pos)
	# Near the room's edge, lean back toward the middle: otherwise anything that
	# wanders or keeps its distance ends up pressed to the outer wall, sliding along it.
	var room := Arena.ROOM
	var m := 160.0
	var inward := Vector2.ZERO
	inward.x += maxf(0.0, 1.0 - (e.pos.x - room.position.x) / m) - maxf(0.0, 1.0 - (room.end.x - e.pos.x) / m)
	inward.y += maxf(0.0, 1.0 - (e.pos.y - room.position.y) / m) - maxf(0.0, 1.0 - (room.end.y - e.pos.y) / m)
	if inward != Vector2.ZERO:
		want = (want + inward * 1.6).normalized()
	# slide around pillars instead of grinding into them
	var h: Dictionary = game.arena.raycast(e.pos, e.pos + want * (e.r + 70.0))
	if h:
		var tg: Vector2 = h.normal.orthogonal()
		if tg.dot(want) < 0.0:
			tg = -tg
		return (want * 0.3 + tg).normalized()
	return want


func _chaser(e: E, pl: Vector2, dt: float) -> void:
	var to := pl - e.pos
	var want := _steer(e, _route(e, pl))
	var sp := e.speed * (1.0 + 0.15 * sin(e.t * 3.0 + e.seed))
	e.vel = Pal.damp2(e.vel, want * sp, 3.2, dt)
	if e.vel.length() > 5.0:
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-10.0 * dt))


func _guard(e: E, pl: Vector2, dt: float) -> void:
	var to := pl - e.pos
	var d := to.length()
	# turn slowly toward you: that slowness is the opening to flank it
	var want_a := to.angle()
	var cur := e.face.angle()
	var diff := wrapf(want_a - cur, -PI, PI)
	cur += clampf(diff, -1.25 * dt, 1.25 * dt)
	e.face = Vector2.from_angle(cur)
	e.rot = cur
	var mv := Vector2.ZERO
	if d > 150.0:
		mv = _steer(e, _route(e, pl))
	e.vel = Pal.damp2(e.vel, mv * e.speed, 2.5, dt)


func _charger(e: E, pl: Vector2, dt: float) -> void:
	e.mode_t += dt
	var to := pl - e.pos
	var d := to.length()
	match e.mode:
		APPROACH:
			# hold a middle distance and circle, then wind up when the lane is clear
			var radial := to / maxf(d, 1.0) * clampf((d - 360.0) / 120.0, -1.0, 1.0)
			var orbit := to.orthogonal().normalized() * (0.6 if fmod(e.seed, 2.0) < 1.0 else -0.6)
			e.vel = Pal.damp2(e.vel, _steer(e, _seek(e, pl, (radial + orbit).normalized())) * e.speed, 2.5, dt)
			e.face = e.face.slerp(to.normalized(), 1.0 - exp(-6.0 * dt))
			e.rot = e.face.angle()
			e.cool -= dt * (2.0 if e.rush > 0.0 else 1.0)
			if e.cool <= 0.0 and d < 640.0 and not game.arena.raycast(e.pos, pl):
				e.mode = WINDUP
				e.mode_t = 0.0
				e.dash_dir = to / d
				game.sfx.play("windup", 1.0, -6.0)
		WINDUP:
			e.vel = Pal.damp2(e.vel, -e.dash_dir * 30.0, 8.0, dt)
			# tracks you for most of the wind-up, then locks
			if e.mode_t < WINDUP_TIME - 0.3:
				e.dash_dir = e.dash_dir.slerp(to.normalized(), 1.0 - exp(-5.0 * dt))
			e.face = e.dash_dir
			e.rot = e.face.angle()
			if e.mode_t >= WINDUP_TIME:
				e.mode = DASH
				e.mode_t = 0.0
				e.vel = e.dash_dir * DASH_SPEED
				game.sfx.play("dash_e", randf_range(0.95, 1.05), -4.0)
				game.fx.ring(e.pos, e.r, e.r * 2.5, 0.25, Pal.foe(0.6), 1.5)
		DASH:
			e.vel = e.dash_dir * DASH_SPEED * lerpf(1.0, 0.7, clampf(e.mode_t / 0.6, 0.0, 1.0))
			if int(e.mode_t * 60.0) % 2 == 0:
				e.ghosts.append([e.pos, 0.0, e.rot])
			if e.mode_t > 0.62:
				e.mode = RECOVER
				e.mode_t = 0.0
		STUN:
			e.vel = Pal.damp2(e.vel, Vector2.ZERO, 10.0, dt)
			if e.mode_t > 1.0:
				e.mode = RECOVER
				e.mode_t = 0.0
		RECOVER:
			if e.shunt and e.mode_t < 0.5:
				# a shunter rolls on along its rails a moment, unable to turn
				e.vel = Pal.damp2(e.vel, e.dash_dir * 260.0, 2.0, dt)
			else:
				e.vel = Pal.damp2(e.vel, Vector2.ZERO, 6.0, dt)
			if e.mode_t > 0.55:
				e.mode = APPROACH
				e.mode_t = 0.0
				e.cool = randf_range(0.9, 1.9)


func _slam(e: E) -> void:
	e.mode = STUN
	e.mode_t = 0.0
	e.knock = -e.dash_dir * 160.0
	e.vel = Vector2.ZERO
	e.squash = 1.0
	e.squash_dir = e.dash_dir
	var at := e.pos + e.dash_dir * e.r
	game.fx.sparks(at, -e.dash_dir, 12, Pal.foe(1.0, 1.8), 520.0, 0.3, 1.2)
	game.fx.ring(at, 6.0, 46.0, 0.35, Pal.foe(0.8), 1.5)
	game.sfx.play("slam", randf_range(0.95, 1.05), -4.0)
	game.cam.add_trauma(0.16)


func _separate(e: E, dt: float) -> void:
	for o in list:
		if o == e or o.state != ALIVE:
			continue
		var d := e.pos - o.pos
		var rr := e.r + o.r + 6.0
		var l2 := d.length_squared()
		if l2 < rr * rr and l2 > 0.01:
			var l := sqrt(l2)
			e.vel += d / l * 260.0 * (1.0 - l / rr) * dt * 60.0 * 0.1


func _contact(e: E, pl: Vector2) -> void:
	if e.kind == PHASE and phased(e):
		return
	if e.kind == BYSTANDER or (e.kind == HOUND and e.mode == 2):
		return
	if e.kind == TURNSTILE:
		for k in 3:
			var tip := e.pos + Vector2.from_angle(e.rot + TAU * k / 3.0) * (e.r + ARM)
			if Geometry2D.get_closest_point_to_segment(pl, e.pos, tip).distance_to(pl) < Player.R + 3.0:
				game.on_player_hit((pl - e.pos).normalized(), e)
				break
	if e.kind == COUPLER and _chain_live(e) and e.id < e.link.id:
		if Geometry2D.get_closest_point_to_segment(pl, e.pos, e.link.pos).distance_to(pl) < Player.R + 3.0:
			game.on_player_hit((pl - e.pos).normalized().orthogonal(), e)
	var d := pl - e.pos
	if d.length() < e.r + Player.R - 3.0:
		if game.on_player_hit(d.normalized() if d.length() > 0.1 else Vector2.RIGHT, e):
			e.knock -= d.normalized() * 220.0
			if e.kind == CHARGER and e.mode == DASH:
				e.mode = RECOVER
				e.mode_t = 0.0


# ---------------------------------------------------------------- drawing

func _poly(e: E) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	match e.kind:
		CHASER:
			pts = [Vector2(e.r * 1.25, 0), Vector2(-e.r * 0.85, -e.r * 0.85), Vector2(-e.r * 0.85, e.r * 0.85)]
		GUARD:
			for k in 4:
				pts.append(Vector2.from_angle(PI / 4.0 + TAU * k / 4.0) * e.r)
		CHARGER:
			pts = [Vector2(e.r * 1.45, 0), Vector2(0, -e.r * 0.8), Vector2(-e.r * 1.0, 0), Vector2(0, e.r * 0.8)]
		PRISM:
			for k in 3:
				pts.append(Vector2.from_angle(TAU * k / 3.0) * e.r)
		PULSE:
			var open: bool = game.sfx.beat_frac() < 0.35
			var k6: float = 1.0 + (0.18 * (1.0 - game.sfx.beat_frac() / 0.35) if open else 0.0)
			for k in 6:
				pts.append(Vector2.from_angle(TAU * k / 6.0) * e.r * k6)
		ECHO:
			for k in 8:
				pts.append(Vector2.from_angle(TAU * k / 8.0) * e.r)
		LEECH:
			for k in 5:
				pts.append(Vector2.from_angle(TAU * k / 5.0) * e.r * (1.0 + 0.08 * sin(e.t * 6.0 + k * 1.7)))
		INSPECTOR:
			# a clipboard-shaped body, longer than it is wide
			pts = [Vector2(e.r * 1.1, -e.r * 0.75), Vector2(e.r * 1.1, e.r * 0.75), Vector2(-e.r * 1.1, e.r * 0.75), Vector2(-e.r * 1.1, -e.r * 0.75)]
		ESCORT:
			# a small dart
			pts = [Vector2(e.r * 1.3, 0), Vector2(-e.r * 0.8, e.r * 0.8), Vector2(-e.r * 0.8, -e.r * 0.8)]
		PHASE:
			# a six-pointed star, its points blurring when it goes faint
			for k in 6:
				pts.append(Vector2.from_angle(TAU * k / 6.0) * e.r * (1.0 if k % 2 == 0 else 0.62))
		PROOFREADER:
			# a pen nib, pointing the way it walks
			pts = [Vector2(e.r * 1.35, 0), Vector2(e.r * 0.15, e.r * 0.72), Vector2(-e.r * 0.95, e.r * 0.55), Vector2(-e.r * 0.95, -e.r * 0.55), Vector2(e.r * 0.15, -e.r * 0.72)]
		COUPLER:
			# seen from above: the buffer beam, the drawbar, the coupler head with its jaw
			for v in [Vector2(-1.0, -0.85), Vector2(-0.7, -0.85), Vector2(-0.7, -0.3), Vector2(0.45, -0.3), Vector2(0.62, -0.72),
					Vector2(1.38, -0.72), Vector2(1.38, -0.2), Vector2(1.38, 0.2), Vector2(1.38, 0.72), Vector2(0.62, 0.72),
					Vector2(0.45, 0.3), Vector2(-0.7, 0.3)]:
				pts.append(v * e.r)
			pts.append(Vector2(-0.7, 0.85) * e.r)
			pts.append(Vector2(-1.0, 0.85) * e.r)
		SIGNAL:
			# a post, three times as tall as it is wide (it does not turn)
			pts = [Vector2(e.r * 0.55, -e.r * 1.6), Vector2(e.r * 0.55, e.r * 1.6), Vector2(-e.r * 0.55, e.r * 1.6), Vector2(-e.r * 0.55, -e.r * 1.6)]
		QUEUE:
			for k in 5:
				pts.append(Vector2.from_angle(TAU * k / 5.0) * e.r)
		QSEG:
			for k in e.sides:
				pts.append(Vector2.from_angle(PI / 4.0 + TAU * k / e.sides) * e.r)
		BYSTANDER:
			# a person from above: the shoulders, wider than deep
			for k in e.sides:
				var q := Vector2.from_angle(TAU * k / e.sides)
				pts.append(Vector2(q.x * 0.5, q.y) * e.r)
		REGISTRAR:
			# a desk, corners cut
			for v in [Vector2(-1.15, -0.45), Vector2(-0.95, -0.65), Vector2(0.95, -0.65), Vector2(1.15, -0.45),
					Vector2(1.15, 0.45), Vector2(0.95, 0.65), Vector2(-0.95, 0.65), Vector2(-1.15, 0.45)]:
				pts.append(v * e.r)
		TURNSTILE:
			for k in 6:
				pts.append(Vector2.from_angle(TAU * k / 6.0) * e.r)
		HOUND:
			# a long low body, longer still as it crouches
			var crouch := 1.0 + (0.25 if e.mode == 1 else 0.0)
			for v in [Vector2(1.6, 0), Vector2(0.9, -0.45), Vector2(-0.6, -0.55), Vector2(-1.35, 0), Vector2(-0.6, 0.55), Vector2(0.9, 0.45)]:
				pts.append(Vector2(v.x * crouch, v.y / crouch) * e.r)
		DUD:
			# a shell case: long, a blunt nose
			pts = [Vector2(e.r * 1.4, 0), Vector2(e.r * 0.7, -e.r * 0.55), Vector2(-e.r * 1.1, -e.r * 0.55), Vector2(-e.r * 1.1, e.r * 0.55), Vector2(e.r * 0.7, e.r * 0.55)]
	pts.append(pts[0])
	return pts


func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.5 * f
	# a soft dark pool under every shell, all first, so it reads against trails
	for e in list:
		if e.state == ALIVE or e.state == SPAWN:
			var h: float = e.r * 2.6
			draw_texture_rect(halo_tex, Rect2(e.pos - Vector2(h, h), Vector2(h, h) * 2.0), false, Color(0, 0, 0, 0.62))
	for e in list:
		if e.state == DEAD or e.state == HOST:
			continue
		if e.state == WARN:
			_draw_warn(e)
			continue
		var pts := _poly(e)
		var sq := Pal.ease_out(e.squash) * 0.22
		var sd := e.squash_dir
		var shake := Vector2.ZERO
		var extra := 1.0
		if e.kind == CHARGER and e.mode == WINDUP:
			var k := e.mode_t / WINDUP_TIME
			shake = Vector2(sin(e.t * 90.0), cos(e.t * 77.0)) * 2.2 * k
			extra = 1.0 - 0.18 * Pal.ease_in(k)
			_draw_telegraph(e, k, dim)
		var basis := Transform2D(sd.angle(), Vector2.ZERO)
		var sc := Transform2D(Vector2(1.0 - sq, 0), Vector2(0, 1.0 + sq * 0.7), Vector2.ZERO)
		var tr := Transform2D(0.0, e.pos + shake) * basis * sc * basis.affine_inverse() * Transform2D(e.rot, Vector2.ZERO) * Transform2D(Vector2(extra, 0), Vector2(0, 1.0 / maxf(extra, 0.5)), Vector2.ZERO)
		var col := Pal.foe(dim).lerp(Pal.red(dim, 2.4), e.red * 0.85)
		if ACCENT.has(e.kind):
			col = acc(e.kind, dim, 1.25).lerp(Pal.red(dim, 2.4), e.red * 0.85)
			if e.kind == BYSTANDER:
				col = acc(BYSTANDER, 0.45 * dim, 1.0)
			elif e.state == ALIVE:
				# a solid body in its chapter's colour, so it reads as a thing, not a wire
				var fill := PackedVector2Array()
				for k in pts.size() - 1:
					fill.append(tr * pts[k])
				draw_colored_polygon(fill, acc(e.kind, 0.2 * dim, 0.8))
		if e.kind == PHASE and e.state == ALIVE:
			var pk := phase_k(e)
			var turning := pk > 0.02 and pk < 0.98
			var fl := (0.5 + 0.5 * sin(e.t * 50.0)) if turning else 1.0
			col.a *= lerpf(1.0, 0.22, pk) * lerpf(0.6, 1.0, fl)
			if pk > 0.3:
				# out of step with itself: two faint copies either side
				for sgn: float in [-1.0, 1.0]:
					var off := Vector2(sin(e.t * 7.0 + e.seed), cos(e.t * 5.0 + e.seed)) * 5.0 * sgn * pk
					var gt2 := Transform2D(e.rot + 0.2 * sgn, e.pos + off)
					for k in pts.size() - 1:
						draw_line(gt2 * pts[k], gt2 * pts[k + 1], Pal.foe(0.22 * pk * dim, 1.2), 1.0)
			# its clock: an arc counting to the next change
			var span := PH_SOLID if e.mode == 0 else PH_GONE
			var ck := clampf(e.mode_t / span, 0.0, 1.0)
			draw_arc(e.pos, e.r + 7.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - ck), 24, Pal.foe((0.55 if e.mode == 0 else 0.25) * dim, 1.2), 1.5)
		for g in e.ghosts:
			var gk: float = 1.0 - g[1] / 0.25
			var gt := Transform2D(g[2], g[0])
			for k in pts.size() - 1:
				draw_line(gt * pts[k], gt * pts[k + 1], Pal.foe(0.3 * gk * gk), 1.5)
		if e.state == SPAWN:
			# its edges fly in dark, then the tube strikes: a stutter, a surge, held
			var strike := Pal.starter(e.t - 0.36, 0.3, e.seed)
			var surge := clampf(1.0 - absf(e.t - 0.72) / 0.14, 0.0, 1.0)
			if surge > 0.0:
				var hs: float = e.r * 3.2
				draw_texture_rect(halo_tex, Rect2(e.pos - Vector2(hs, hs), Vector2(hs, hs) * 2.0), false, Pal.foe(0.45 * surge * dim, 1.8))
			for k in e.sides:
				var kk := Pal.back(clampf((e.t - k * 0.06) / 0.42, 0.0, 1.0), 2.0)
				var o: Array = e.offs[k]
				var off: Vector2 = o[0] * (1.0 - kk)
				var lt := Transform2D(float(o[1]) * (1.0 - kk), Vector2.ZERO)
				var mid := (pts[k] + pts[k + 1]) * 0.5
				var lit := lerpf(0.3, 1.0, strike) if e.t > 0.36 else 0.3
				draw_line(tr * (mid + off + lt * (pts[k] - mid)), tr * (mid + off + lt * (pts[k + 1] - mid)), Pal.foe(clampf(kk * 1.4, 0.0, 1.0) * lit * dim, 1.0 + 1.6 * surge), 2.0 + 1.5 * surge)
			var core := Pal.ease_out(clampf((e.t - 0.4) / 0.35, 0.0, 1.0))
			if core > 0.0:
				_core(e, tr, core, col)
			if e.kind == GUARD:
				_draw_shield(e, dim, Pal.ease_out(clampf((e.t - 0.3) / 0.3, 0.0, 1.0)))
			continue
		if e.elite:
			# the harder way's elite: a slow red ring of eight dashes round it
			var er := e.r + 12.0
			for k in 8:
				var a0 := e.t * 0.8 + TAU * k / 8.0
				draw_arc(e.pos, er, a0, a0 + TAU / 16.0, 5, Pal.red(0.9 * dim, 2.2), 2.0)
			# and a red chevron over it, so it reads across the room
			var top := e.pos + Vector2(0, -er - 14.0)
			draw_colored_polygon(PackedVector2Array([top + Vector2(-8, -7), top + Vector2(8, -7), top + Vector2(0, 4)]), Pal.red(0.95 * dim, 2.2))
		var whole := _edges_left(e)
		# a phaser: filled while solid, only a dashed outline while faint
		var faint_now: bool = e.kind == PHASE and e.state == ALIVE and phased(e)
		if e.kind == PHASE and e.state == ALIVE and not faint_now:
			var fp := PackedVector2Array()
			for k in e.sides:
				fp.append(tr * pts[k])
			draw_colored_polygon(fp, Pal.foe(0.24 * dim))
		for k in e.sides:
			var a := tr * pts[k]
			var b := tr * pts[k + 1]
			if k < whole and faint_now:
				for j in 3:
					draw_line(a.lerp(b, j / 3.0), a.lerp(b, j / 3.0 + 0.18), col, 1.5)
			elif k < whole:
				# a tube: its soft light round a bright core
				draw_line(a, b, Color(col.r, col.g, col.b, col.a * 0.13), 7.0)
				draw_line(a, b, col, 2.0)
			else:
				var m := (a + b) * 0.5
				var out := (m - e.pos).normalized() * 2.5
				draw_line(a, a.lerp(m, 0.62) + out, Pal.foe(0.42 * dim), 1.5)
				draw_line(b, b.lerp(m, 0.55) + out * 0.6, Pal.foe(0.42 * dim), 1.5)
		_core(e, tr, 1.0, col)
		if e.kind == GUARD:
			_draw_shield(e, dim, 1.0)
		if e.kind == LEECH:
			# tendrils that reach for the nearest round
			for k in 3:
				var ta := e.rot + PI + (k - 1) * 0.5
				var tl := e.r + 10.0 + 6.0 * sin(e.t * 8.0 + k)
				draw_line(e.pos + Vector2.from_angle(ta) * e.r, e.pos + Vector2.from_angle(ta + 0.2 * sin(e.t * 5.0 + k)) * tl, Pal.foe(0.55 * dim), 1.2)
		if e.kind == PRISM:
			# the bend it gives, drawn as a fan of fine lines through the body
			for k in 3:
				var a3 := e.rot + TAU * k / 3.0 + PI / 3.0
				draw_line(e.pos, e.pos + Vector2.from_angle(a3) * e.r * 0.8, Pal.foe((0.35 + 0.6 * e.shield_flash) * dim, 1.0 + e.shield_flash), 1.0)
		if e.kind == INSPECTOR:
			# its badge: a bulb crossed out, and the reach of its hand
			var bp: Vector2 = e.pos + Vector2(0, -3)
			draw_circle(bp, 7.5, Color(0.03, 0.03, 0.035))
			draw_arc(bp, 7.5, PI * 0.75, PI * 2.25, 14, Pal.foe(0.85 * dim, 1.4), 1.5)
			# the filament and the screw base
			draw_polyline(PackedVector2Array([bp + Vector2(-3, 2), bp + Vector2(-1.5, -2), bp + Vector2(0, 1), bp + Vector2(1.5, -2), bp + Vector2(3, 2)]), Pal.foe(0.8 * dim, 1.3), 1.2)
			draw_rect(Rect2(bp + Vector2(-4, 6), Vector2(8, 5)), Pal.foe(0.7 * dim), false, 1.2)
			draw_line(bp + Vector2(-10, -10), bp + Vector2(10, 12), Pal.red(0.85 * dim, 1.4), 2.0)
			draw_arc(e.pos, DIM_R, 0.0, TAU, 40, Pal.foe(0.28 * dim), 1.5)
		if e.kind == ESCORT:
			# its little shield, turned toward you, and a tether to what it guards
			var sa: float = (game.player.pos - e.pos).angle()
			var ready: bool = e.cool <= 0.0
			# its rotor ring, spinning
			draw_arc(e.pos, e.r + 3.0, e.t * 9.0, e.t * 9.0 + PI * 1.5, 16, Pal.foe(0.45 * dim), 1.2)
			var shc := Pal.foe((0.9 if ready else 0.25) * dim, 1.2).lerp(Pal.ink(dim, 2.6), e.shield_flash)
			draw_arc(e.pos, e.r + 9.0, sa - 1.1, sa + 1.1, 14, shc, 3.0 + 2.0 * e.shield_flash)
			if e.anchor != null and e.anchor is E and e.anchor.state == ALIVE:
				# a dashed tether to what it guards
				var td: Vector2 = e.anchor.pos - e.pos
				var tl := td.length()
				var tn := td / maxf(tl, 0.001)
				var dl := PackedVector2Array()
				var s0 := e.r + 6.0
				while s0 < tl - e.anchor.r - 4.0:
					dl.append(e.pos + tn * s0)
					dl.append(e.pos + tn * minf(s0 + 7.0, tl - e.anchor.r - 4.0))
					s0 += 13.0
				if dl.size() > 0:
					draw_multiline(dl, Pal.foe(0.55 * dim), 1.6)
				# and a small shield mark over what it guards
				var wm: Vector2 = e.anchor.pos + Vector2(0, -e.anchor.r - 14.0)
				draw_polyline(PackedVector2Array([wm + Vector2(-6, -5), wm + Vector2(6, -5), wm + Vector2(6, 1), wm + Vector2(0, 6), wm + Vector2(-6, 1), wm + Vector2(-6, -5)]), Pal.foe(0.75 * dim, 1.3), 1.5)
		if e.kind == PROOFREADER:
			# the nib's slit and breather hole, red ink on its tip
			var fwd := Vector2.from_angle(e.rot)
			var tip: Vector2 = e.pos + fwd * e.r * 1.35
			draw_line(tip, e.pos + fwd * e.r * 0.1, Pal.foe(0.75 * dim), 1.2)
			draw_arc(e.pos, 3.5, 0.0, TAU, 10, Pal.foe(0.8 * dim), 1.2)
			draw_circle(tip, 3.5, Pal.red(0.95 * dim, 2.0))
			if e.mode == 1 and e.anchor != null:
				# writing over the round: a red scribble growing on it
				var wk := clampf(e.mode_t / FIX_WRITE, 0.0, 1.0)
				var q: Vector2 = e.anchor.pos
				var sl := PackedVector2Array()
				for j in 2 + int(wk * 10.0):
					sl.append(q + Vector2(-12.0 + j * 2.4, sin(j * 2.1 + e.t * 20.0) * 5.0))
				draw_polyline(sl, Pal.red(0.9 * dim, 2.0), 1.5)
				draw_line(tip, q, Pal.red(0.25 * dim, 1.4), 1.0)
		_draw_extra(e, tr, dim)
		if e.kind == CHARGER and e.mode == STUN:
			for k in 3:
				var a3 := e.t * 5.0 + TAU * k / 3.0
				draw_circle(e.pos + Vector2.from_angle(a3) * (e.r + 8.0), 1.6, Pal.foe(0.7 * dim))
		if e.flash > 0.0:
			var poly := PackedVector2Array()
			for k in e.sides:
				poly.append(tr * pts[k])
			draw_colored_polygon(poly, Pal.foe(0.7 * e.flash, 1.15))
	if not fixes.is_empty() or game.shelves.active():
		_draw_fixes(dim)
	_draw_zones(dim)


func _draw_fixes(dim: float) -> void:
	var font := Fonts.get_font("SemiBold")
	for fx_ in fixes:
		var b = fx_[0]
		var k: float = fx_[3]
		var a := 1.0 - clampf((k - FIX_SHOW + 0.5) / 0.5, 0.0, 1.0)
		# drawn from inside the room: the arc starts at the struck-out spot
		var from: Vector2 = (fx_[1] as Vector2).clamp(Arena.ROOM.position + Vector2(24, 24), Arena.ROOM.end - Vector2(24, 24))
		var to: Vector2 = fx_[2]
		var ctrl: Vector2 = fx_[4]
		var run := clampf(k / FIX_SLIDE, 0.0, 1.0)
		var u_end := Pal.ease_io(run)
		# the red arc, dashed, drawn as far as the round has got
		var segs := PackedVector2Array()
		var n_seg := 24
		for j in n_seg:
			var u0 := float(j) / n_seg
			var u1 := float(j + 1) / n_seg
			if j % 2 == 1 or u0 >= u_end:
				continue
			segs.append(_arc(from, ctrl, to, u0))
			segs.append(_arc(from, ctrl, to, minf(u1, u_end)))
		if segs.size() > 0:
			draw_multiline(segs, Pal.red(0.75 * a * dim, 1.8), 2.5)
		var head := _arc(from, ctrl, to, u_end)
		var tan := (head - _arc(from, ctrl, to, maxf(0.0, u_end - 0.06))).normalized()
		if tan != Vector2.ZERO:
			draw_line(head - tan * 4.0, head - tan * 18.0 + tan.orthogonal() * 8.0, Pal.red(0.85 * a * dim, 1.8), 2.5)
			draw_line(head - tan * 4.0, head - tan * 18.0 - tan.orthogonal() * 8.0, Pal.red(0.85 * a * dim, 1.8), 2.5)
		# the old spot, struck through, a little in from the wall it was in
		var xo := from
		draw_line(xo + Vector2(-8, -8), xo + Vector2(8, 8), Pal.red(0.7 * a * dim, 1.6), 2.5)
		draw_line(xo + Vector2(-8, 8), xo + Vector2(8, -8), Pal.red(0.7 * a * dim, 1.6), 2.5)
		if k >= FIX_SLIDE * 0.5:
			# "corrected", on a dark plate at the arc's middle
			var lab := Txt.t("corrected")
			var fs := 18
			var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var mid := _arc(from, ctrl, to, 0.5)
			var at := mid + Vector2(-lw * 0.5, 6.0)
			at.x = clampf(at.x, Arena.ROOM.position.x + 12.0, Arena.ROOM.end.x - lw - 12.0)
			at.y = clampf(at.y, Arena.ROOM.position.y + 30.0, Arena.ROOM.end.y - 12.0)
			draw_rect(Rect2(at + Vector2(-8, -fs - 2.0), Vector2(lw + 16, fs + 10)), Color(0.06, 0.0, 0.0, 0.85 * a))
			draw_rect(Rect2(at + Vector2(-8, -fs - 2.0), Vector2(lw + 16, fs + 10)), Pal.red(0.5 * a * dim, 1.4), false, 1.0)
			draw_string(font, at, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.red(0.95 * a * dim, 1.8))
	for b in game.bullets.list:
		if b.corrected and b.state == Bullets.EMBED:
			var p: Vector2 = b.pos + (Arena.ROOM.get_center() - b.pos).normalized() * 24.0
			draw_polyline(PackedVector2Array([p + Vector2(-7, 0), p + Vector2(-2, 5), p + Vector2(8, -7)]), Pal.red(0.9 * dim, 1.6), 2.5)


func _core(e: E, tr: Transform2D, k: float, col: Color) -> void:
	var poly := PackedVector2Array()
	var n := 6 if e.kind == CHASER else 4
	var rr := e.r * (0.3 if e.kind == CHASER else 0.36) * k
	if rr < 0.6:
		return
	for j in n:
		poly.append(tr * (Vector2.from_angle(TAU * j / n + (PI / 4.0 if n == 4 else PI / 6.0)) * rr))
	draw_colored_polygon(poly, Color(col.r, col.g, col.b, col.a * 0.9))


func _draw_shield(e: E, dim: float, k: float) -> void:
	if k <= 0.0:
		return
	var a0 := e.face.angle() - SHIELD_HALF * k
	var a1 := e.face.angle() + SHIELD_HALF * k
	var frac := e.hp / e.maxhp
	var c := Pal.foe(dim, 1.0 + 1.2 * e.shield_flash)
	var w := 5.0 + 2.0 * e.shield_flash
	if frac > 0.5:
		draw_arc(e.pos, SHIELD_R, a0, a1, 20, c, w, false)
	else:
		# cracked: the arc in three pieces with gaps that flicker
		var gap := 0.06 + 0.03 * sin(e.t * 13.0)
		for j in 3:
			var s0 := lerpf(a0, a1, j / 3.0) + gap
			var s1 := lerpf(a0, a1, (j + 1) / 3.0) - gap
			draw_arc(e.pos, SHIELD_R + (j - 1) * 1.2, s0, s1, 8, c, w - 1.0, false)
	draw_arc(e.pos, SHIELD_R + 6.0, a0 + 0.1, a1 - 0.1, 16, Pal.foe(0.18 * dim), 1.0, false)


func _draw_telegraph(e: E, k: float, dim: float) -> void:
	# the lane it is about to take: dashed, filling in, ending at the wall
	var h: Dictionary = game.arena.raycast(e.pos, e.pos + e.dash_dir * 1400.0)
	var end: Vector2 = h.point if h else e.pos + e.dash_dir * 1400.0
	var lane := e.pos.distance_to(end)
	var locked := e.mode_t >= WINDUP_TIME - 0.3
	var a := (0.18 + 0.45 * k) * dim
	var period := 22.0
	var seg := 12.0
	var off := fmod(e.t * 160.0, period)
	var at := e.r + 6.0 + off
	var reach := lane * Pal.ease_out(k * 1.6)
	var segs := PackedVector2Array()
	while at < reach:
		segs.append(e.pos + e.dash_dir * at)
		segs.append(e.pos + e.dash_dir * minf(at + seg, reach))
		at += period
	if segs.size() > 0:
		if e.shunt:
			# the yard's shunters run on rails: two lines, not one
			var off2 := e.dash_dir.orthogonal() * 5.0
			var s2 := PackedVector2Array()
			for p in segs:
				s2.append(p + off2)
			for j in segs.size():
				segs[j] -= off2
			draw_multiline(s2, Pal.foe(a, 1.4 if locked else 1.0), 1.5)
		draw_multiline(segs, Pal.foe(a, 1.4 if locked else 1.0), 2.0 if locked else 1.2)
	if locked:
		var side := e.dash_dir.orthogonal() * (e.r + 4.0)
		draw_line(e.pos + side, end + side * 0.4, Pal.foe(0.12 * dim), 1.0)
		draw_line(e.pos - side, end - side * 0.4, Pal.foe(0.12 * dim), 1.0)


func _draw_warn(e: E) -> void:
	# a marker grows where something is about to assemble
	var k := clampf((e.t) / WARN_TIME, 0.0, 1.0)
	if e.t < 0.0:
		return
	var r := e.r * 2.2 * (1.0 - 0.5 * Pal.ease_out(k))
	draw_arc(e.pos, r, 0.0, TAU, 32, Pal.foe(0.5 * k), 1.2, false)
	for j in 4:
		var d := Vector2.from_angle(TAU * j / 4.0 + k * 1.2)
		draw_line(e.pos + d * (r + 3.0), e.pos + d * (r + 9.0), Pal.foe(0.7 * k), 1.5)


# ================================================================ chapters 1-3: their own
# (design/敌人重设计_Sonnet.md) Each chapter's enemies belong to its place.

# ---- chapter 1: the coupled pair. Two halves on a chain that come at you from
# either side; held between CHAIN_MIN and CHAIN_MAX the chain goes taut and red,
# and swept across you it hurts. A recall through the chain cuts it.
func _coupler(e: E, pl: Vector2, dt: float) -> void:
	var side := 1.0 if fmod(e.seed, 2.0) < 1.0 else -1.0
	var to := pl - e.pos
	var want_p := pl
	if e.link != null and not e.cut and e.link.state == ALIVE:
		# each half aims a little to its side of you, so the chain closes across you
		want_p = pl + to.normalized().orthogonal() * 120.0 * side
		var span := e.pos.distance_to(e.link.pos)
		if span > CHAIN_MIN and span < CHAIN_MAX:
			e.mode_t += dt
		else:
			e.mode_t = 0.0
		if span > CHAIN_MAX:
			# the chain pulls the halves together
			want_p = want_p.lerp(e.link.pos, 0.6)
	var want := _steer(e, _route(e, want_p))
	var sp := e.speed * (1.0 + 0.12 * sin(e.t * 3.0 + e.seed))
	e.vel = Pal.damp2(e.vel, want * sp, 3.2, dt)
	if e.vel.length() > 5.0:
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-10.0 * dt))


func _chain_live(e: E) -> bool:
	return e.link != null and not e.cut and e.link.state == ALIVE and e.mode_t >= CHAIN_WARN


func _cut_chains(a: Vector2, b: Vector2) -> void:
	for e in list:
		if e.kind != COUPLER or e.state != ALIVE or e.cut or e.link == null or e.link.state != ALIVE or e.id > e.link.id:
			continue
		var x = Geometry2D.segment_intersects_segment(a, b, e.pos, e.link.pos)
		if x != null:
			e.cut = true
			e.link.cut = true
			game.fx.sparks(x, (b - a).normalized(), 10, Pal.red(1.0, 2.4), 420.0, 0.25, 1.2)
			game.fx.ring(x, 4.0, 30.0, 0.25, Pal.red(0.9, 2.2), 2.0)
			game.sfx.play("crack", 1.3, -8.0)


# ---- chapter 1: the signalman. Keeps well back; every few seconds its lamp
# goes red and every enemy near it is sent off faster. Kill it and that stops.
func _signal(e: E, pl: Vector2, dt: float) -> void:
	var away := e.pos - pl
	var want := Vector2.ZERO
	if away.length() < 420.0:
		want = away.normalized()
	else:
		want = Vector2.from_angle(sin(e.t * 0.5 + e.seed) * 3.0) * 0.4
	e.vel = Pal.damp2(e.vel, _steer(e, want) * e.speed, 3.0, dt)
	e.rot = 0.0
	match e.mode:
		0:
			e.cool -= dt
			if e.cool <= 0.0:
				e.mode = 1
				e.mode_t = 0.0
				game.sfx.play("windup", 1.5, -10.0)
		1:
			e.mode_t += dt
			if e.mode_t >= 0.6:
				e.mode = 0
				e.cool = 4.0
				for o in list:
					if o != e and o.state == ALIVE and o.kind != BYSTANDER and o.pos.distance_to(e.pos) < SIGNAL_R:
						o.rush = 3.0
				game.fx.ring(e.pos, 10.0, SIGNAL_R, 0.45, Pal.red(0.7, 1.8), 2.0)
				game.sfx.play("horn", 1.6, -12.0)


# ---- chapter 2: the queue. A head with a smile and four followers that walk where
# it walked; any of them hurts. One recall along the queue pierces them all.
func _queue_head(e: E, pl: Vector2, dt: float) -> void:
	var to := (pl - e.pos).normalized()
	var weave := to.orthogonal() * sin(e.t * 1.7 + e.seed) * 1.3
	var want := _steer(e, _seek(e, pl, (to + weave).normalized()))
	e.vel = Pal.damp2(e.vel, want * e.speed, 2.5, dt)
	if e.vel.length() > 5.0:
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-8.0 * dt))


func _queue_seg(e: E, dt: float) -> void:
	if e.link == null or e.link.state != ALIVE:
		e.vel = Pal.damp2(e.vel, Vector2.ZERO, 4.0, dt)
		return
	var ahead: E = e.link
	var gap := ahead.r + e.r + 4.0
	var d := e.pos - ahead.pos
	var want := ahead.pos + (d.normalized() if d.length() > 0.1 else Vector2.LEFT) * gap
	e.vel = (want - e.pos) / maxf(dt, 0.001)
	e.vel = e.vel.limit_length(900.0)
	if d.length() > 0.1:
		e.rot = (-d).angle()


# ---- chapter 2: the registrar. Keeps its distance; every few seconds it stands
# still and stamps the ground where you are going. The stamp leaves red ink.
func _registrar(e: E, pl: Vector2, dt: float) -> void:
	match e.mode:
		0:
			var away := e.pos - pl
			var want := (away.normalized() if away.length() < 280.0 else (-away.normalized() if away.length() > 420.0 else away.normalized().orthogonal()))
			e.vel = Pal.damp2(e.vel, _steer(e, _seek(e, pl, want)) * e.speed, 3.0, dt)
			e.cool -= dt
			if e.cool <= 0.0:
				e.mode = 1
				e.mode_t = 0.0
				var at: Vector2 = pl + game.player.vel * 0.35
				at = at.clamp(Arena.ROOM.position + STAMP * 0.5, Arena.ROOM.end - STAMP * 0.5)
				e.aim_at = at
				zones.append({"c": at, "sz": STAMP, "t": 0.0, "warn": STAMP_WARN, "ink": INK_TIME, "hit": false, "by": e.id})
				game.sfx.play("windup", 0.8, -9.0)
		1:
			# it does not move while it stamps
			e.vel = Pal.damp2(e.vel, Vector2.ZERO, 10.0, dt)
			e.mode_t += dt
			if e.mode_t >= STAMP_WARN:
				e.mode = 0
				e.cool = 5.0
	if e.vel.length() > 5.0:
		e.rot = lerp_angle(e.rot, 0.0, 1.0 - exp(-4.0 * dt))


func _step_zones(dt: float, pl: Vector2) -> void:
	var i := 0
	while i < zones.size():
		var z: Dictionary = zones[i]
		z.t += dt
		var r := Rect2(z.c - z.sz * 0.5, z.sz)
		if not z.hit and z.t >= z.warn:
			z.hit = true
			game.fx.ring(z.c, 10.0, z.sz.x * 0.75, 0.3, Pal.red(1.0, 2.4), 3.0)
			game.fx.flash(z.c, z.sz.x * 0.6, 0.12, Pal.red(0.4, 2.0))
			game.cam.add_trauma(0.12)
			game.sfx.play("stamp", 1.3, -6.0)
			if r.grow(Player.R * 0.5).has_point(pl):
				game.on_player_hit((pl - z.c).normalized() if pl.distance_to(z.c) > 1.0 else Vector2.DOWN, null)
		elif z.hit and r.has_point(pl):
			# the ink: standing in it hurts (the hit's own grace keeps it from every frame)
			game.on_player_hit((pl - z.c).normalized() if pl.distance_to(z.c) > 1.0 else Vector2.DOWN, null)
		if z.t >= z.warn + z.ink:
			zones.remove_at(i)
		else:
			i += 1


# ---- chapter 2: the turnstile. A hub with three long arms, turning; the arms hurt
# you and turn your rounds away like a mirror, only the hub can be hurt.
func _turnstile(e: E, pl: Vector2, dt: float) -> void:
	e.rot += PI * 0.5 * dt
	var want := _steer(e, _route(e, pl))
	e.vel = Pal.damp2(e.vel, want * e.speed, 2.0, dt)


# An outbound round meeting a turnstile's arm: it glances off as off a mirror.
func arm_hit(a: Vector2, b: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	for e in list:
		if e.kind != TURNSTILE or e.state != ALIVE:
			continue
		if e.pos.distance_to(a) > e.r + ARM + a.distance_to(b) + 4.0:
			continue
		for k in 3:
			var dir := Vector2.from_angle(e.rot + TAU * k / 3.0)
			var p1 := e.pos + dir * e.r
			var p2 := e.pos + dir * (e.r + ARM)
			var x = Geometry2D.segment_intersects_segment(a, b, p1, p2)
			if x != null:
				var l: float = a.distance_to(x)
				if l < bd and l > 0.5:
					bd = l
					var n := dir.orthogonal()
					if n.dot(b - a) > 0.0:
						n = -n
					best = {"point": x, "normal": n, "e": e}
	return best


func on_arm(e: E, at: Vector2) -> void:
	e.shield_flash = 1.0
	game.fx.sparks(at, Vector2.from_angle(e.rot), 5, Pal.foe(1.0, 2.0), 360.0, 0.2, PI)
	game.sfx.play("shield", randf_range(1.3, 1.5), -9.0)


# ---- chapter 3: the hound. Circles you, crouches with your landing spot marked
# in red, leaps; in the air nothing reaches it, landed it stands a moment.
func _hound(e: E, pl: Vector2, dt: float) -> void:
	e.mode_t += dt
	match e.mode:
		0:
			var to := pl - e.pos
			var d := to.length()
			var radial := to / maxf(d, 1.0) * clampf((d - 260.0) / 80.0, -1.0, 1.0)
			var orbit := to.orthogonal().normalized() * (0.9 if fmod(e.seed, 2.0) < 1.0 else -0.9)
			e.vel = Pal.damp2(e.vel, _steer(e, _seek(e, pl, (radial + orbit).normalized())) * e.speed, 3.0, dt)
			e.rot = lerp_angle(e.rot, to.angle(), 1.0 - exp(-8.0 * dt))
			if e.mode_t >= (0.7 if e.rush > 0.0 else 1.2) and d < LEAP + 120.0 and not game.arena.raycast(e.pos, pl):
				e.mode = 1
				e.mode_t = 0.0
				var at: Vector2 = pl + game.player.vel * 0.45
				var off := at - e.pos
				if off.length() > LEAP:
					at = e.pos + off.normalized() * LEAP
				e.aim_at = at.clamp(Arena.ROOM.position + Vector2(e.r, e.r), Arena.ROOM.end - Vector2(e.r, e.r))
				game.sfx.play("windup", 1.2, -8.0)
		1:
			# crouched, the landing marked
			e.vel = Pal.damp2(e.vel, Vector2.ZERO, 10.0, dt)
			e.rot = (e.aim_at - e.pos).angle()
			if e.mode_t >= 0.5:
				e.mode = 2
				e.mode_t = 0.0
				e.leap_from = e.pos
				game.sfx.play("dash_e", 1.25, -6.0)
		2:
			# in the air: straight to the mark, over everything
			var k := clampf(e.mode_t / LEAP_T, 0.0, 1.0)
			var want_p := e.leap_from.lerp(e.aim_at, k)
			e.vel = (want_p - e.pos) / maxf(dt, 0.001)
			e.knock = Vector2.ZERO
			if k >= 1.0:
				e.mode = 3
				e.mode_t = 0.0
				e.vel = Vector2.ZERO
				game.fx.ring(e.pos, 8.0, 52.0, 0.3, Pal.foe(0.9, 1.6), 2.0)
				game.sfx.play("slam", 1.3, -8.0)
				game.cam.add_trauma(0.08)
				if e.pos.distance_to(pl) < e.r + Player.R + 18.0:
					game.on_player_hit((pl - e.pos).normalized(), e)
		3:
			# landed: a moment standing, the best time to recall through it
			e.vel = Pal.damp2(e.vel, Vector2.ZERO, 10.0, dt)
			if e.mode_t >= 0.6:
				e.mode = 0
				e.mode_t = randf_range(-0.6, 0.0)


# ---- chapter 3: the dud. Drifts at you; close, its fuse starts and it goes off.
# Killed anywhere, it goes off at once: blow it up among the others.
func _dud(e: E, pl: Vector2, dt: float) -> void:
	var to := pl - e.pos
	match e.mode:
		0:
			e.vel = Pal.damp2(e.vel, _steer(e, _route(e, pl)) * e.speed, 2.0, dt)
			if e.vel.length() > 5.0:
				e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-4.0 * dt))
			if to.length() < 220.0:
				e.mode = 1
				e.mode_t = 0.0
				game.sfx.play("windup", 1.8, -8.0)
		1:
			e.mode_t += dt
			e.vel = Pal.damp2(e.vel, Vector2.ZERO, 3.0, dt)
			if e.mode_t >= FUSE:
				_die(e, Vector2.UP)


func _boom(e: E) -> void:
	if e.cut:
		return
	e.cut = true
	game.fx.ring(e.pos, 10.0, FUSE_R, 0.4, Pal.red(1.0, 2.6), 3.0)
	game.fx.ring(e.pos, 6.0, FUSE_R * 0.6, 0.3, Pal.foe(0.8, 1.6), 1.5)
	game.fx.flash(e.pos, FUSE_R, 0.2, Pal.red(0.5, 2.2))
	game.fx.sparks(e.pos, Vector2.UP, 24, Pal.red(1.0, 2.4), 760.0, 0.4, PI)
	game.cam.add_trauma(0.3)
	game.sfx.play("p_blast", 1.1, -3.0)
	var pl: Vector2 = game.player.pos
	if pl.distance_to(e.pos) < FUSE_R:
		game.on_player_hit((pl - e.pos).normalized(), null)
	for o in list:
		if o != e and o.state == ALIVE and o.kind != BYSTANDER and o.pos.distance_to(e.pos) < FUSE_R + o.r:
			blast_hit(o, (o.pos - e.pos).normalized(), BLAST_DUD)


# ---- chapter 3: the passers-by. They walk across and harm no one. A round or a
# recall through one is a misfire: time added to the wave, and the city says so.
func _bystander(e: E, dt: float) -> void:
	var to := e.aim_at - e.pos
	if to.length() < 30.0:
		e.state = DEAD
		return
	e.vel = Pal.damp2(e.vel, _steer(e, _route(e, e.aim_at)) * e.speed, 3.0, dt)
	if e.vel.length() > 8.0:
		e.rot = e.vel.angle()


func _misfire(e: E) -> void:
	e.state = DEAD
	game.fx.ring(e.pos, 4.0, 40.0, 0.4, Pal.ink(0.9, 1.6), 1.5)
	game.fx.flash(e.pos, 30.0, 0.15, Pal.ink(0.6, 1.4))
	game.sfx.play("hurt", 1.4, -10.0)
	game.wave_ctl.add_penalty(5.0)
	game.hud.flash_text(Txt.t("misfire_tag"), e.pos)
	if misfired_wave != game.wave_ctl.index:
		misfired_wave = game.wave_ctl.index
		game.hud.radio(Txt.t("misfire_radio"))


# What a death leaves behind, by kind.
func _died(e: E) -> void:
	match e.kind:
		DUD:
			_boom(e)
		SIGNAL:
			for o in list:
				o.rush = 0.0
		QUEUE, QSEG:
			# the one behind takes this one's place; behind the head, it becomes the head
			for o in list:
				if o.state == ALIVE and o.link == e and (o.kind == QSEG or o.kind == QUEUE):
					o.link = e.link
					if e.kind == QUEUE:
						o.kind = QUEUE
						o.sides = 5
						o.link = null
						game.fx.ring(o.pos, o.r, o.r * 2.2, 0.3, Pal.foe(0.8, 1.6), 1.5)
		COUPLER:
			if e.link != null and e.link.link == e:
				e.link.link = null


# ---- drawing the chapters' own
func _draw_extra(e: E, tr: Transform2D, dim: float) -> void:
	match e.kind:
		COUPLER:
			_draw_coupler(e, tr, dim)
		SIGNAL:
			_draw_signal(e, tr, dim)
			if e.mode == 1:
				var k := clampf(e.mode_t / 0.6, 0.0, 1.0)
				draw_arc(e.pos, lerpf(30.0, SIGNAL_R, k), 0.0, TAU, 48, Pal.red(0.5 * (1.0 - k) * dim, 1.6), 2.0)
		QUEUE, QSEG:
			_draw_queue(e, tr, dim)
		REGISTRAR:
			_draw_desk(e, tr, dim)
			var drop := 0.0
			if e.mode == 1:
				drop = Pal.ease_in(clampf(e.mode_t / STAMP_WARN, 0.0, 1.0)) * 8.0
			var sp: Vector2 = e.pos + Vector2(sin(e.t * 2.4) * 3.0, e.r + 7.0 + drop)
			draw_rect(Rect2(sp - Vector2(6, 5), Vector2(12, 10)), Pal.red(0.85 * dim, 1.8), false, 2.0)
			draw_line(e.pos + Vector2(0, e.r), sp - Vector2(0, 5), Pal.foe(0.5 * dim), 1.0)
		TURNSTILE:
			_draw_gate(e, dim)
			var hc := acc(TURNSTILE, dim, 1.3).lerp(Pal.ink(dim, 2.4), e.shield_flash)
			for k in 3:
				var dir := Vector2.from_angle(e.rot + TAU * k / 3.0)
				var p1: Vector2 = e.pos + dir * e.r
				var p2: Vector2 = e.pos + dir * (e.r + ARM)
				draw_line(p1, p2, Color(hc.r, hc.g, hc.b, hc.a * 0.15), 9.0)
				draw_line(p1, p2, hc, 3.5)
				draw_circle(p2, 4.0, hc)
				draw_circle(p2, 1.8, Color(0.03, 0.03, 0.035, dim))
				var mid := p1.lerp(p2, 0.55)
				draw_line(mid - dir.orthogonal() * 4.0, mid + dir.orthogonal() * 4.0, Pal.red(0.8 * dim, 1.6), 1.5)
		HOUND:
			# its legs, keeping time with its stride; the red eye at the front
			var fwd := Vector2.from_angle(e.rot)
			var sd := fwd.orthogonal()
			var swing := sin(e.t * 14.0) * 4.0 if e.mode == 0 else 0.0
			_draw_hound(e, tr, dim)
			for k in 2:
				var base: Vector2 = e.pos + fwd * (e.r * (0.6 if k == 0 else -0.6))
				for sg in [-1.0, 1.0]:
					draw_line(base + sd * sg * e.r * 0.45, base + sd * sg * (e.r * 0.95) + fwd * swing * sg, Pal.foe(0.7 * dim), 1.5)
			draw_circle(tr * Vector2(e.r * 1.25, 0), 2.8, Pal.red(0.95 * dim, 2.2))
			if e.mode == 1 or e.mode == 2:
				# where it will land: a red ring closing in
				var k2 := clampf((e.mode_t if e.mode == 1 else 0.5 + e.mode_t) / (0.5 + LEAP_T), 0.0, 1.0)
				draw_arc(e.aim_at, lerpf(46.0, e.r + 10.0, k2), 0.0, TAU, 32, Pal.red(0.85 * dim, 1.8), 2.0)
				draw_line(e.aim_at - Vector2(7, 0), e.aim_at + Vector2(7, 0), Pal.red(0.7 * dim), 1.5)
				draw_line(e.aim_at - Vector2(0, 7), e.aim_at + Vector2(0, 7), Pal.red(0.7 * dim), 1.5)
			if e.mode == 2:
				# its shadow on the floor under the leap
				draw_circle(e.pos + Vector2(8, 14), e.r * 0.8, Color(0, 0, 0, 0.5))
		DUD:
			_draw_dud(e, tr, dim)
			draw_circle(tr * Vector2(e.r * 1.25, 0), 3.5, Pal.red(0.95 * dim, 2.0))
			if e.mode == 1:
				var k := clampf(e.mode_t / FUSE, 0.0, 1.0)
				draw_arc(e.pos, lerpf(FUSE_R, e.r, k), 0.0, TAU, 40, Pal.red((0.5 + 0.5 * sin(e.t * (10.0 + 30.0 * k))) * dim, 2.0), 2.0)
		BYSTANDER:
			# a head, a case in one hand; faint, and nothing red about it
			var pc := acc(BYSTANDER, 0.5 * dim, 1.0)
			draw_circle(e.pos, e.r * 0.38, acc(BYSTANDER, 0.18 * dim, 0.8))
			draw_arc(e.pos, e.r * 0.38, 0.0, TAU, 14, pc, 1.4)
			var sw := sin(e.t * 7.0 + e.seed) * 0.12 * e.r
			draw_rect(Rect2(tr * Vector2(sw, e.r * 1.15) - Vector2(4, 3), Vector2(8, 6)), pc, false, 1.2)


func acc(kind: int, a: float, k: float = 1.0) -> Color:
	var c: Color = ACCENT[kind]
	return Color(c.r * k, c.g * k, c.b * k, Pal.ink(a).a)


# The coupled pair: a railway coupler seen from above, and the real chain between
# the two, sagging and swinging while slack, pulled straight and red when taut.
func _draw_coupler(e: E, tr: Transform2D, dim: float) -> void:
	var r := e.r
	var ac := acc(COUPLER, dim, 1.3)
	var hi := Pal.ink(0.9 * dim, 1.3)
	# hazard stripes across the buffer beam
	for j in 3:
		var y0 := -0.78 + j * 0.56
		draw_line(tr * Vector2(-0.97 * r, y0 * r), tr * Vector2(-0.73 * r, (y0 + 0.36) * r), ac, 2.5)
	# the two buffers on the back, springing with each step
	var push := sin(e.t * 11.0 + e.seed) * minf(1.0, e.vel.length() / 120.0) * 0.07 * r
	for sg: float in [-1.0, 1.0]:
		var bp := Vector2(-1.18 * r + push, sg * 0.55 * r)
		draw_line(tr * Vector2(-r, sg * 0.55 * r), tr * bp, hi, 2.0)
		draw_circle(tr * bp, 0.2 * r, ac)
		draw_arc(tr * bp, 0.2 * r, 0.0, TAU, 12, hi, 1.2)
	# rivets down the drawbar
	for x: float in [-0.4, 0.0, 0.32]:
		draw_circle(tr * Vector2(x * r, 0.0), 1.7, hi)
	# the knuckle: swings shut and open in the jaw, a slow mechanical breath
	var open := Pal.ease_io(0.5 + 0.5 * sin(e.t * 2.4 + e.seed))
	var piv := Vector2(1.18 * r, -0.46 * r)
	var ang := lerpf(PI * 0.5, 0.15, open)
	var kn := piv + Vector2.from_angle(ang) * 0.62 * r
	draw_line(tr * piv, tr * kn, Pal.ink(dim, 1.6), 3.0)
	draw_line(tr * kn, tr * (kn + Vector2.from_angle(ang + PI * 0.5) * 0.22 * r), Pal.ink(dim, 1.6), 3.0)
	draw_circle(tr * piv, 2.6, ac)
	if e.link == null or e.link.state != ALIVE or e.cut or e.id > e.link.id:
		return
	# the chain, head to head
	var live := _chain_live(e)
	var warm := clampf(e.mode_t / CHAIN_WARN, 0.0, 1.0) if not live else 1.0
	var a: Vector2 = e.pos + Vector2.from_angle(e.rot) * 1.3 * r
	var b: Vector2 = e.link.pos + Vector2.from_angle(e.link.rot) * 1.3 * e.link.r
	var l := a.distance_to(b)
	var n := (b - a) / maxf(l, 0.001)
	var side := n.orthogonal()
	var slack := 0.0 if live else clampf((CHAIN_MAX - l) / (CHAIN_MAX - CHAIN_MIN * 0.5), 0.0, 1.0) * (1.0 - warm)
	var sag := slack * 46.0
	var sway := sin(e.t * 2.2 + e.seed) * 0.6
	var cc := ac.lerp(Pal.red(0.95 * dim, 2.2), warm)
	if live:
		draw_line(a, b, Pal.red(0.22 * dim, 2.0), 9.0)
	var count := maxi(4, int(l / 11.0))
	var prev := a
	for i in count + 1:
		var t := float(i) / count
		var p := a.lerp(b, t) + side * sag * 4.0 * t * (1.0 - t) * (1.0 + sway * (t - 0.5))
		if i > 0:
			# links alternate: one seen flat (an oval), the next edge-on (a bar)
			var mid := (prev + p) * 0.5
			var dirl := (p - prev).normalized()
			if i % 2 == 1:
				var ov := PackedVector2Array()
				for k in 9:
					var q := Vector2.from_angle(TAU * k / 8.0)
					ov.append(mid + dirl * q.x * 7.0 + dirl.orthogonal() * q.y * 3.6)
				draw_polyline(ov, cc, 1.8)
			else:
				draw_line(mid - dirl * 6.5, mid + dirl * 6.5, cc, 2.4)
		prev = p


func _rect_pts(tr: Transform2D, x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([tr * Vector2(x0, y0), tr * Vector2(x1, y0), tr * Vector2(x1, y1), tr * Vector2(x0, y1), tr * Vector2(x0, y0)])


# The signalman: a mast with its ladder, a semaphore arm that never rests, and
# the lamp in its hood: the yard's own colour while it waits, red when it calls.
func _draw_signal(e: E, tr: Transform2D, dim: float) -> void:
	var r := e.r
	var ac := acc(SIGNAL, dim, 1.3)
	var hi := Pal.ink(0.8 * dim, 1.3)
	for j in 5:
		var y := lerpf(1.25, -1.2, j / 4.0) * r
		draw_line(tr * Vector2(-0.36 * r, y), tr * Vector2(0.36 * r, y), hi, 1.4)
	draw_colored_polygon(_rect_pts(tr, -1.0 * r, 1.45 * r, 1.0 * r, 1.85 * r), ac)
	var calling := e.mode == 1
	var sw := -0.85 if calling else 0.3 * sin(e.t * 1.6 + e.seed)
	var piv := tr * Vector2(0.55 * r, -1.1 * r)
	var tip := piv + Vector2.from_angle(sw) * 1.7 * r
	draw_line(piv, tip, Pal.ink(dim, 1.5), 4.0)
	draw_line(piv.lerp(tip, 0.55), piv.lerp(tip, 0.8), Pal.red(0.95 * dim, 2.0) if calling else ac, 4.5)
	draw_circle(piv, 3.0, ac)
	var lamp := tr * Vector2(0, -1.6 * r - 9.0)
	var on: bool = calling or int(e.t * 2.0) % 2 == 0
	var lc := Pal.red(0.95 * dim, 2.2) if calling else ac
	draw_circle(lamp, 9.0, Color(0.03, 0.03, 0.035, dim))
	draw_arc(lamp, 9.0, PI * 0.85, PI * 2.15, 16, hi, 2.2)
	if on:
		draw_circle(lamp, 13.0, Color(lc.r, lc.g, lc.b, lc.a * 0.18))
		draw_circle(lamp, 5.5, lc)
	else:
		draw_arc(lamp, 5.5, 0.0, TAU, 14, lc, 1.5)


# The queue: a number board on the head, a ticket on each behind, and the lane
# of barrier belts they walk between.
func _draw_queue(e: E, tr: Transform2D, dim: float) -> void:
	var r := e.r
	var ac := acc(e.kind, dim, 1.3)
	var hi := Pal.ink(0.85 * dim, 1.3)
	if e.kind == QUEUE:
		# the only face in the game: a small smile, and the board above it
		var fwd := Vector2.from_angle(e.rot)
		draw_arc(e.pos + fwd * 2.0, r * 0.42, e.rot - 0.9, e.rot + 0.9, 10, hi, 1.6)
		draw_colored_polygon(_rect_pts(tr, -0.85 * r, -0.4 * r, -0.2 * r, 0.4 * r), Color(0.03, 0.03, 0.035, dim))
		draw_polyline(_rect_pts(tr, -0.85 * r, -0.4 * r, -0.2 * r, 0.4 * r), ac, 1.4)
		# its number rolling over
		var n := int(e.t * 1.5 + e.seed * 7.0) % 4
		for j in 3:
			if (n + j) % 2 == 0:
				var y := lerpf(-0.25, 0.25, j / 2.0) * r
				draw_line(tr * Vector2(-0.72 * r, y), tr * Vector2(-0.33 * r, y), ac, 2.0)
		return
	# a ticket, its light running down the line
	var blink := 0.45 + 0.55 * maxf(0.0, sin(e.t * 4.0 - e.seed * 3.0))
	draw_colored_polygon(_rect_pts(tr, -0.35 * r, -0.3 * r, 0.35 * r, 0.3 * r), acc(QSEG, blink * dim, 1.4))
	if e.link != null and e.link.state == ALIVE:
		var a: Vector2 = e.pos
		var b: Vector2 = e.link.pos
		var side := (b - a).normalized().orthogonal()
		for sg: float in [-1.0, 1.0]:
			var pa := a + side * sg * (r + 7.0)
			var pb: Vector2 = b + side * sg * (e.link.r + 7.0)
			var mid: Vector2 = (pa + pb) * 0.5 + side * sg * 2.5
			draw_polyline(PackedVector2Array([pa, mid, pb]), Color(ac.r, ac.g, ac.b, ac.a * 0.7), 2.5)
			draw_circle(pa, 3.0, hi)


# The registrar: a desk, its window, a stack of forms with the top one lifting.
func _draw_desk(e: E, tr: Transform2D, dim: float) -> void:
	var r := e.r
	var ac := acc(REGISTRAR, dim, 1.3)
	var hi := Pal.ink(0.8 * dim, 1.3)
	draw_line(tr * Vector2(-0.6 * r, -0.3 * r), tr * Vector2(0.6 * r, -0.3 * r), hi, 2.4)
	for j in 3:
		var o := j * 0.07 * r
		var lift := (sin(e.t * 3.0 + e.seed) * 0.08 * r) if j == 2 else 0.0
		draw_polyline(_rect_pts(tr, -0.95 * r + o, 0.0 + o - lift, -0.4 * r + o, 0.42 * r + o - lift), ac, 1.3)
	draw_circle(tr * Vector2(0.65 * r, 0.2 * r), 0.16 * r, Pal.red(0.5 * dim, 1.2))
	draw_arc(tr * Vector2(0.65 * r, 0.2 * r), 0.16 * r, 0.0, TAU, 12, hi, 1.2)


# The turnstile: the floor it sweeps, marked out; a counter ring in its hub.
func _draw_gate(e: E, dim: float) -> void:
	var ac := acc(TURNSTILE, dim, 1.0)
	var rr := e.r + ARM + 4.0
	for k in 24:
		var a0 := TAU * k / 24.0
		draw_arc(e.pos, rr, a0, a0 + TAU / 48.0, 3, Color(ac.r, ac.g, ac.b, ac.a * 0.35), 1.5)
	for k in 6:
		var a1 := -e.rot * 1.5 + TAU * k / 6.0
		draw_line(e.pos + Vector2.from_angle(a1) * e.r * 0.45, e.pos + Vector2.from_angle(a1) * e.r * 0.7, Pal.ink(0.8 * dim, 1.3), 1.4)


# The hound: armour plates down its spine, ears back, a tail that will not keep still.
func _draw_hound(e: E, tr: Transform2D, dim: float) -> void:
	var r := e.r
	var ac := acc(HOUND, dim, 1.3)
	var hi := Pal.ink(0.85 * dim, 1.3)
	for j in 3:
		var x := lerpf(0.45, -0.75, j / 2.0) * r
		draw_colored_polygon(_rect_pts(tr, x - 0.14 * r, -0.26 * r, x + 0.14 * r, 0.26 * r), ac)
	var twitch := 0.08 * r * sin(e.t * 9.0 + e.seed) if e.mode == 0 else 0.0
	for sg: float in [-1.0, 1.0]:
		draw_line(tr * Vector2(0.95 * r, sg * 0.35 * r), tr * Vector2(0.6 * r - twitch, sg * 0.7 * r), hi, 2.0)
	var wag := sin(e.t * 12.0 + e.seed) * 0.5 if e.mode == 0 else 0.0
	var tb := tr * Vector2(-1.35 * r, 0)
	var tt := tb + Vector2.from_angle(e.rot + PI + wag) * 0.75 * r
	draw_line(tb, tt, hi, 2.0)
	draw_circle(tt, 2.2, ac)


# The dud: fins at the tail, bands round the case, and a fuse that fizzes even asleep.
func _draw_dud(e: E, tr: Transform2D, dim: float) -> void:
	var r := e.r
	var ac := acc(DUD, dim, 1.3)
	var hi := Pal.ink(0.85 * dim, 1.3)
	for sg: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([tr * Vector2(-0.75 * r, sg * 0.55 * r), tr * Vector2(-1.1 * r, sg * 0.55 * r), tr * Vector2(-1.45 * r, sg * 0.95 * r), tr * Vector2(-1.2 * r, sg * 0.95 * r)]), ac)
	draw_line(tr * Vector2(-1.1 * r, 0), tr * Vector2(-1.45 * r, 0), ac, 3.0)
	for x: float in [0.45, -0.35]:
		draw_line(tr * Vector2(x * r, -0.55 * r), tr * Vector2(x * r, 0.55 * r), hi if x > 0.0 else ac, 3.0)
	if e.mode == 0:
		for k in 3:
			var h := fmod(e.t * 3.0 + k * 0.37 + e.seed, 1.0)
			var sp := tr * Vector2(r * 1.4, 0) + Vector2.from_angle(e.seed * 5.0 + k * 2.1 + h * 1.3) * h * 12.0
			draw_circle(sp, 1.6 * (1.0 - h), Pal.ink((1.0 - h) * dim, 2.0))


func _draw_zones(dim: float) -> void:
	for z in zones:
		var r := Rect2(z.c - z.sz * 0.5, z.sz)
		if not z.hit:
			# the stamp's frame, closing in from outside, about to come down
			var k := clampf(z.t / z.warn, 0.0, 1.0)
			draw_rect(r.grow(30.0 * (1.0 - k)), Pal.red((0.4 + 0.5 * k) * dim, 1.8), false, 2.0)
			draw_rect(r, Pal.red(0.07 * k * dim, 1.2))
		else:
			# the ink, fading
			var left := 1.0 - clampf((z.t - z.warn) / z.ink, 0.0, 1.0)
			draw_rect(r, Pal.red(0.05 * left * dim, 1.0))
			draw_rect(r, Pal.red(0.5 * left * dim, 1.6), false, 1.5)
