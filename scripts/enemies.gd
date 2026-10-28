class_name Enemies
extends Node2D
# Chasers swarm in straight lines, guards hold a shield toward you, chargers
# wind up and dash. Every body is a white polygon whose edges break away as
# its armour goes; it shatters into those edges when it dies.

enum { WARN, SPAWN, ALIVE, DEAD, HOST }   # HOST: seized by you (Possess drives it)
enum { CHASER, GUARD, CHARGER, PRISM, LEECH, PULSE, ECHO }
enum { APPROACH, WINDUP, DASH, STUN, RECOVER }

const SPEC := {
	CHASER: {"hp": 30.0, "r": 14.0, "sides": 3, "speed": 245.0},
	GUARD: {"hp": 140.0, "r": 22.0, "sides": 4, "speed": 72.0},
	CHARGER: {"hp": 60.0, "r": 18.0, "sides": 4, "speed": 100.0},
	PRISM: {"hp": 50.0, "r": 22.0, "sides": 3, "speed": 55.0},
	LEECH: {"hp": 45.0, "r": 16.0, "sides": 5, "speed": 125.0},
	PULSE: {"hp": 70.0, "r": 19.0, "sides": 6, "speed": 0.0},
	ECHO: {"hp": 40.0, "r": 13.0, "sides": 8, "speed": 0.0},
}
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

var list: Array[E] = []
var game
var next_id := 1


func _ready() -> void:
	z_index = 0
	z_as_relative = false


func remaining() -> int:
	var n := 0
	for e in list:
		if e.state != DEAD and e.state != HOST:
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
	e.hp *= Loadout.enemy_hp()
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
	for k in e.sides:
		e.offs.append([Vector2.from_angle(randf() * TAU) * randf_range(50, 90), randf_range(-2.5, 2.5)])
	list.append(e)
	return e


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
	game.fx.sparks(at, Vector2.from_angle(e.rot), 5, Pal.ink(1.0, 2.0), 360.0, 0.2, PI)
	game.sfx.play("cross", randf_range(1.2, 1.4), -10.0)


func on_shield(e: E, at: Vector2, dir: Vector2, ret: bool) -> void:
	e.shield_flash = 1.0
	e.knock += -e.face * (70.0 if ret else 40.0)
	game.fx.sparks(at, e.face, 6, Pal.ink(1.0, 1.9), 420.0, 0.22, 0.9)
	game.fx.flash(at, 18.0, 0.1, Pal.ink(0.35, 1.3))
	game.sfx.play("shield", randf_range(0.92, 1.1), -6.0)
	game.cam.add_trauma(0.03)


func sweep(a: Vector2, b: Vector2, bullet, ret: bool) -> void:
	for e in list:
		if e.state != ALIVE or bullet.hit.has(e.id):
			continue
		var q := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
		if q.distance_to(e.pos) <= e.r + 3.0:
			bullet.hit[e.id] = true
			if ret:
				game.possess.mark(e)
			var d: Vector2 = (b - a).normalized() if b.distance_squared_to(a) > 0.01 else bullet.dir
			var dmg: float = bullet.dmg * (game.ret_mult() if ret else game.out_mult())
			if game.has("hunter") and e.hp >= e.maxhp:
				dmg *= 1.5
			if ret and bullet.first_bonus:
				bullet.first_bonus = false
				dmg *= 2.0
			if not ret and game.has("sniper"):
				dmg *= 1.0 + 0.04 * bullet.total() / 100.0
			if e.kind == PULSE:
				# its shell is open just after each beat
				dmg *= 1.5 if game.sfx.beat_frac() < 0.35 else 0.25
			if ret and e.pinned > 0.0:
				dmg *= 2.0
			if ret:
				dmg *= game.possess.lane_bonus(q)
			if ret and game.has("afterburn"):
				e.burn = 2.0
			if game.first_blood_ready:
				game.first_blood_ready = false
				dmg *= 3.0
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
					_hit(e, 60.0, d, e.pos, true)
			if bullet.state != Bullets.ORBIT:
				game.bullets.on_enemy_hit(bullet, q, d, ret)


func _edges_left(e: E) -> int:
	return ceili(clampf(e.hp / e.maxhp, 0.0, 1.0) * e.sides - 0.001)


func _hit(e: E, dmg: float, dir: Vector2, at: Vector2, ret: bool) -> void:
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
			game.fx.shard(wm, (pts[k] - mid) * 0.45, (pts[k + 1] - mid) * 0.45, out * randf_range(140, 220) + dir * 160.0, randf_range(-10, 10), 0.55, Pal.ink(0.9, 1.3), 2.0)
	game.fx.number(at, dmg, ret)
	var c := Pal.red(1.0, 3.2) if ret else Pal.ink(1.0, 1.8)
	game.fx.sparks(at, dir, 7 if ret else 4, c, 520.0 if ret else 380.0, 0.26, 0.7)
	game.fx.sparks(at, -dir, 2, Pal.ink(0.8, 1.4), 200.0, 0.2, 1.2)
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
				blast_hit(best, (best.pos - e.pos).normalized(), excess * 0.5)
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
func blast_hit(e: E, dir: Vector2, dmg: float) -> void:
	e.hp -= dmg
	e.flash = 1.0
	e.knock += dir * 220.0
	game.fx.number(e.pos, dmg, true)
	if e.hp <= 0.0:
		_die(e, dir)


# Aftershock damage: no recall bonus and no chain of its own.
func aftershock_hit(e: E, dir: Vector2) -> void:
	e.hp -= 25.0
	e.flash = 1.0
	e.knock += dir * 260.0
	game.fx.number(e.pos, 25.0, true)
	if e.hp <= 0.0:
		_die(e, dir)


func _die(e: E, dir: Vector2) -> void:
	e.state = DEAD
	if e.grip != null:
		if game.bullets.held_by(e.grip).size() >= 4:
			game.ach("leech4")
		e.grip.alive = false
		for b in game.bullets.held_by(e.grip):
			game.bullets.drop(b)
		game.sfx.play("mend", 1.3, -6.0)
	var tr := Transform2D(e.rot, e.pos)
	var col := Pal.ink(1.0, 1.6).lerp(Pal.red(1.0, 2.6), e.red)
	var pts := _poly(e)
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
			game.fx.shard(e.pos + m2, a2 - m2, b2 - m2, m2.normalized() * randf_range(200, 300) + dir * 200.0, randf_range(-8, 8), 0.8, Pal.ink(1.0, 1.4), 4.0)
	game.fx.ring(e.pos, e.r * 0.6, e.r * 4.0, 0.45, col, 2.0)
	game.fx.ring(e.pos, e.r * 0.3, e.r * 2.2, 0.3, Pal.ink(0.6), 1.0)
	game.fx.flash(e.pos, e.r * 3.0, 0.26, Color(col.r, col.g, col.b, 0.4))
	game.fx.sparks(e.pos, dir, 10 + e.sides * 2, col, 700.0, 0.4, 1.3)
	game.on_target_die(e.pos, e.kind)


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	var pl: Vector2 = game.player.pos
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
					game.fx.ring(e.pos, e.r, e.r * 2.0, 0.35, Pal.ink(0.7, 1.3), 1.5)
					game.fx.flash(e.pos, e.r * 2.5, 0.2, Pal.ink(0.5, 1.2))
			ALIVE:
				match e.kind:
					PRISM:
						if e.anchor != null and e.anchor.alive():
							# circling the warden
							e.orbit_a += 0.9 * dt
							var want: Vector2 = e.anchor.pos + Vector2.from_angle(e.orbit_a) * 170.0
							e.vel = (want - e.pos) * 6.0
						else:
							var ang := sin(e.t * 0.31 + e.seed) * 2.2 + cos(e.t * 0.19 + e.seed * 1.3) * 1.5
							e.vel = Pal.damp2(e.vel, _steer(e, Vector2.from_angle(ang)) * e.speed, 1.5, dt)
						e.rot += (0.5 if fmod(e.seed, 2.0) < 1.0 else -0.5) * dt
					LEECH:
						_leech(e, pl, dt)
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
				_separate(e, dt)
				if game.focusing and game.has("gravity"):
					_gravity(e, dt)
				if game.lv.magnet > 0:
					_magnet(e, dt)
				var spd: float = game.enemy_speed()
				if game.has("magnetic_tip") and _near_round(e.pos, 120.0):
					spd *= 0.7
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
			game.fx.flash(target.pos, 20.0, 0.12, Pal.ink(0.5, 1.4))
			game.sfx.play("lit", 0.7, -10.0)
	else:
		# full, or nothing to take: keep away from you
		var away := e.pos - pl
		want = away.normalized() if away.length() < 420.0 else Vector2.from_angle(sin(e.t * 0.4 + e.seed) * 3.0)
	e.vel = Pal.damp2(e.vel, _steer(e, want) * e.speed * (0.7 if held >= 4 else 1.0), 3.0, dt)
	if e.vel.length() > 5.0:
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-6.0 * dt))


# When a pillar stands between it and the target, head for the pillar corner that
# makes the shortest way round instead of rubbing along the face.
func _route(e: E, target: Vector2) -> Vector2:
	var direct := (target - e.pos).normalized()
	var h: Dictionary = game.arena.raycast(e.pos, target)
	if h.is_empty() or int(h.get("rect", -1)) < 0:
		return direct
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


func _steer(e: E, want: Vector2) -> Vector2:
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
			e.vel = Pal.damp2(e.vel, _steer(e, (radial + orbit).normalized()) * e.speed, 2.5, dt)
			e.face = e.face.slerp(to.normalized(), 1.0 - exp(-6.0 * dt))
			e.rot = e.face.angle()
			e.cool -= dt
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
				game.fx.ring(e.pos, e.r, e.r * 2.5, 0.25, Pal.ink(0.6), 1.5)
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
	game.fx.sparks(at, -e.dash_dir, 12, Pal.ink(1.0, 1.8), 520.0, 0.3, 1.2)
	game.fx.ring(at, 6.0, 46.0, 0.35, Pal.ink(0.8), 1.5)
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
	pts.append(pts[0])
	return pts


func _draw() -> void:
	var f: float = game.focus
	var dim := 1.0 - 0.5 * f
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
		var col := Pal.ink(dim).lerp(Pal.red(dim, 2.4), e.red * 0.85)
		for g in e.ghosts:
			var gk: float = 1.0 - g[1] / 0.25
			var gt := Transform2D(g[2], g[0])
			for k in pts.size() - 1:
				draw_line(gt * pts[k], gt * pts[k + 1], Pal.ink(0.3 * gk * gk), 1.5)
		if e.state == SPAWN:
			for k in e.sides:
				var kk := Pal.back(clampf((e.t - k * 0.06) / 0.42, 0.0, 1.0), 2.0)
				var o: Array = e.offs[k]
				var off: Vector2 = o[0] * (1.0 - kk)
				var lt := Transform2D(float(o[1]) * (1.0 - kk), Vector2.ZERO)
				var mid := (pts[k] + pts[k + 1]) * 0.5
				draw_line(tr * (mid + off + lt * (pts[k] - mid)), tr * (mid + off + lt * (pts[k + 1] - mid)), Pal.ink(clampf(kk * 1.4, 0.0, 1.0) * dim), 2.0)
			var core := Pal.ease_out(clampf((e.t - 0.4) / 0.35, 0.0, 1.0))
			if core > 0.0:
				_core(e, tr, core, col)
			if e.kind == GUARD:
				_draw_shield(e, dim, Pal.ease_out(clampf((e.t - 0.3) / 0.3, 0.0, 1.0)))
			continue
		var whole := _edges_left(e)
		for k in e.sides:
			var a := tr * pts[k]
			var b := tr * pts[k + 1]
			if k < whole:
				draw_line(a, b, col, 2.0)
			else:
				var m := (a + b) * 0.5
				var out := (m - e.pos).normalized() * 2.5
				draw_line(a, a.lerp(m, 0.62) + out, Pal.ink(0.42 * dim), 1.5)
				draw_line(b, b.lerp(m, 0.55) + out * 0.6, Pal.ink(0.42 * dim), 1.5)
		_core(e, tr, 1.0, col)
		if e.kind == GUARD:
			_draw_shield(e, dim, 1.0)
		if e.kind == LEECH:
			# tendrils that reach for the nearest round
			for k in 3:
				var ta := e.rot + PI + (k - 1) * 0.5
				var tl := e.r + 10.0 + 6.0 * sin(e.t * 8.0 + k)
				draw_line(e.pos + Vector2.from_angle(ta) * e.r, e.pos + Vector2.from_angle(ta + 0.2 * sin(e.t * 5.0 + k)) * tl, Pal.ink(0.55 * dim), 1.2)
		if e.kind == PRISM:
			# the bend it gives, drawn as a fan of fine lines through the body
			for k in 3:
				var a3 := e.rot + TAU * k / 3.0 + PI / 3.0
				draw_line(e.pos, e.pos + Vector2.from_angle(a3) * e.r * 0.8, Pal.ink((0.35 + 0.6 * e.shield_flash) * dim, 1.0 + e.shield_flash), 1.0)
		if e.kind == CHARGER and e.mode == STUN:
			for k in 3:
				var a3 := e.t * 5.0 + TAU * k / 3.0
				draw_circle(e.pos + Vector2.from_angle(a3) * (e.r + 8.0), 1.6, Pal.ink(0.7 * dim))
		if e.flash > 0.0:
			var poly := PackedVector2Array()
			for k in e.sides:
				poly.append(tr * pts[k])
			draw_colored_polygon(poly, Pal.ink(0.7 * e.flash, 1.15))


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
	var c := Pal.ink(dim, 1.0 + 1.2 * e.shield_flash)
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
	draw_arc(e.pos, SHIELD_R + 6.0, a0 + 0.1, a1 - 0.1, 16, Pal.ink(0.18 * dim), 1.0, false)


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
		draw_multiline(segs, Pal.ink(a, 1.4 if locked else 1.0), 2.0 if locked else 1.2)
	if locked:
		var side := e.dash_dir.orthogonal() * (e.r + 4.0)
		draw_line(e.pos + side, end + side * 0.4, Pal.ink(0.12 * dim), 1.0)
		draw_line(e.pos - side, end - side * 0.4, Pal.ink(0.12 * dim), 1.0)


func _draw_warn(e: E) -> void:
	# a marker grows where something is about to assemble
	var k := clampf((e.t) / WARN_TIME, 0.0, 1.0)
	if e.t < 0.0:
		return
	var r := e.r * 2.2 * (1.0 - 0.5 * Pal.ease_out(k))
	draw_arc(e.pos, r, 0.0, TAU, 32, Pal.ink(0.5 * k), 1.2, false)
	for j in 4:
		var d := Vector2.from_angle(TAU * j / 4.0 + k * 1.2)
		draw_line(e.pos + d * (r + 3.0), e.pos + d * (r + 9.0), Pal.ink(0.7 * k), 1.5)
