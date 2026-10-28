extends RefCounted
# Shared test bot: kites away from enemies, steps off charger lanes, aims at
# the nearest enemy with a human-ish lag and wobble, recalls when low.

var bot: Dictionary
var focus_hold := 0.0
var strafe := 1.0
var aim_ang := 0.0
var skill_jitter := 0.14
var skill_turn := 7.0
var frame := 0
var possess_ai := true      # use E on marked enemies and fight with the shell
var hold_t := 0


func _init(b: Dictionary) -> void:
	bot = b


func think(game) -> void:
	frame += 1
	if not game.replacing.is_empty() and not bot.has("replace"):
		bot["replace"] = 0 if randf() < 0.5 else -1
	if game.picking and not bot.has("pick_wait"):
		bot["pick_wait"] = 40
	if bot.has("pick_wait"):
		bot["pick_wait"] -= 1
		if bot["pick_wait"] <= 0:
			bot["pick"] = randi() % game.offers.size() if game.offers.size() > 0 else -1
			bot.erase("pick_wait")
	var p: Vector2 = game.player.pos
	var es: Array = []
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE:
			es.append(e)
	bot.fire = false
	bot.dash = false
	var move := Vector2.ZERO
	var nearest = null
	var nd := INF
	for e in es:
		var d: float = e.pos.distance_to(p)
		var away: Vector2 = (p - e.pos) / maxf(d, 1.0)
		move += away * clampf((330.0 - d) / 330.0, 0.0, 1.0) * (2.0 if e.kind == Enemies.CHARGER else 1.0)
		if e.kind == Enemies.CHARGER and (e.mode == Enemies.WINDUP or e.mode == Enemies.DASH):
			# step off its lane
			var side: Vector2 = e.dash_dir.orthogonal()
			if (p - e.pos).dot(side) < 0.0:
				side = -side
			move += side * 1.6
			if e.mode == Enemies.DASH and d < 260.0:
				bot.dash = true
		if d < nd:
			nd = d
			nearest = e
	# keep clear of the train and shoot its core when it opens
	var bs = game.boss
	if bs is Boss and (bs.state == Boss.RUN or bs.state == Boss.ENTER):
		for k in Boss.CARS:
			if bs.car_visible(k):
				var cpos: Vector2 = bs.at(bs.car_s(k))
				var cd: float = cpos.distance_to(p)
				if cd < 170.0:
					move += (p - cpos) / maxf(cd, 1.0) * (170.0 - cd) / 60.0
	if bs is Devourer and bs.state == Devourer.RUN:
		var dd: float = bs.pos.distance_to(p)
		if dd < 300.0:
			move += (p - bs.pos) / maxf(dd, 1.0) * (300.0 - dd) / 60.0
		move += (p - bs.pos).orthogonal().normalized() * 0.5
	if bs is Metronome and bs.state == Metronome.RUN:
		for arm in bs._arms():
			var q := Geometry2D.get_closest_point_to_segment(p, arm[0], arm[1])
			var ad: float = q.distance_to(p)
			if ad < 200.0:
				move += (p - q) / maxf(ad, 1.0) * (200.0 - ad) / 50.0
		for r in bs.rings:
			var rr: float = Pal.ease_out(r[1] / 0.9) * 300.0
			if absf((r[0] as Vector2).distance_to(p) - rr) < 60.0 and (r[0] as Vector2).distance_to(p) > rr:
				bot.dash = true
		var bd2: float = bs.bob.distance_to(p)
		if bd2 < 220.0:
			move += (p - bs.bob) / maxf(bd2, 1.0) * 2.0
	if bs is Warden and bs.state == Warden.RUN:
		var wd: float = bs.pos.distance_to(p) - 70.0
		if wd < 260.0:
			move += (p - bs.pos) / maxf(wd, 1.0) * (260.0 - wd) / 60.0
		# circle round to its open back
		move += (p - bs.pos).orthogonal().normalized() * 0.8
	if bs is Lockdown and bs.state == Lockdown.RUN:
		# keep off the hull, step out of a beam that is locking, sidestep the shot
		var hd: float = bs.pos.distance_to(p)
		if hd < 330.0:
			move += (p - bs.pos) / maxf(hd, 1.0) * (330.0 - hd) / 50.0
		for k in 2:
			if bs.lamp_hp[k] <= 0.0:
				continue
			var lp: Vector2 = bs.lamp_pos(k)
			var side: Vector2 = (p - lp).orthogonal().normalized()
			if bs.lamp_aim[k] >= 0.0:
				move += side * 2.0
				if bs.lamp_aim[k] > Lockdown.AIM_TIME - 0.15:
					bot.dash = true
			elif bs.lamp_lock[k] > 0.1:
				move += side * 1.6
		for w in bs.waves:
			if w[1] >= 0.0 and absf(bs.pos.distance_to(p) - w[0]) < 70.0 and bs.pos.distance_to(p) > w[0]:
				bot.dash = true
		if bs.phase == 2:
			# the core shows to the front: stand below it
			move += (Vector2(bs.pos.x, 700.0) - p).normalized() * 0.6
			var ae: Vector2 = bs._arc_end()
			var q2 := Geometry2D.get_closest_point_to_segment(p, bs.pos, ae)
			if q2.distance_to(p) < 120.0:
				move += (p - q2).normalized() * 2.0
			# the arc turns toward you: dash through it just before it arrives
			var ahead: float = wrapf((p - bs.pos).angle() - bs.arc_a, -PI, PI)
			if bs.arc_live() and ahead > 0.0 and ahead < 0.12:
				bot.dash = true
	if bs is Testbed and bs.state == Testbed.RUN:
		# keep below the platform; out of missile marks, the flame and the rail line
		if p.y < 420.0:
			move += Vector2(0, 1.2)
		for m in bs.missiles:
			var md: float = (m[1] as Vector2).distance_to(p)
			if md < Testbed.MIS_R + 40.0:
				move += (p - (m[1] as Vector2)) / maxf(md, 1.0) * 2.4
				if m[2] > Testbed.MIS_FALL - 0.2 and md < Testbed.MIS_R + 10.0:
					bot.dash = true
		if bs.stage == Testbed.TEST and bs.test == 1:
			for f in bs.flames:
				var noz: Vector2 = Testbed.NOZZLES[f[0]]
				var k: float = clampf((bs.flame_t - 0.45) / Testbed.FLAME_TIME, 0.0, 1.0)
				var a: float = bs._flame_angle(f, k)
				var off: float = wrapf((p - noz).angle() - a, -PI, PI)
				var sweep: float = signf(f[2] - f[1])
				# it comes toward you: get ahead of it, dash through when it arrives
				if off * sweep > 0.0 and off * sweep < 0.45:
					move += (p - noz).orthogonal().normalized() * sweep * 1.5
					if off * sweep < 0.22:
						bot.dash = true
		if bs.rail_mode == 1 or bs.rail_mode == 2:
			var dir := Vector2.from_angle(bs.rail_a)
			move += dir.orthogonal() * (1.6 if int(frame / 90) % 2 == 0 else -1.6)
			if bs.rail_mode == 2 and bs.rail_t > Testbed.RAIL_HOLD - 0.12:
				bot.dash = true
	# laser fences: stand clear of a beam that is lit or about to be
	if game.lasers.active():
		for fe in game.lasers.fences:
			if game.lasers.live[fe[2]] or game.lasers.warn[fe[2]] > 0.0:
				var q3 := Geometry2D.get_closest_point_to_segment(p, fe[0], fe[1])
				var fd: float = q3.distance_to(p)
				if fd < 80.0:
					move += (p - q3) / maxf(fd, 1.0) * (80.0 - fd) / 20.0
	if bs is Lockdown and bs.state == Lockdown.RUN:
		var lcp: Vector2 = bs.core_pos()
		nearest = {"pos": lcp, "vel": Vector2.ZERO}
	elif (bs is Boss and (bs.state == Boss.RUN or bs.state == Boss.ENTER)) or (bs is Warden and bs.state == Warden.RUN) or (bs is Devourer and bs.state == Devourer.RUN) or (bs is Metronome and bs.state == Metronome.RUN) or (bs is Zero and bs.state == Zero.RUN) or (bs is Testbed and bs.state == Testbed.RUN):
		if bs.core_open > 0.5 or not (bs is Boss or bs is Testbed):
			var cp: Vector2 = bs.core_pos()
			nearest = {"pos": cp, "vel": bs.core_vel()}
			nd = cp.distance_to(p)
	# stay off the walls, drift around the centre
	var c := Vector2(960, 540)
	move += (c - p) / 900.0
	move += (c - p).orthogonal().normalized() * 0.25 * strafe
	if frame % 300 == 0:
		strafe = -strafe
	bot.move = move.limit_length(1.0)
	if nd < 60.0:
		bot.dash = true
	if nearest != null:
		var target: Vector2 = nearest.pos + nearest.vel * (nd / 1500.0)
		if nearest is Dictionary:
			target = nearest.pos + nearest.vel * (nd / 1500.0)
		# against a guard, aim past it so returns come back into its back
		# a human-ish hand: the aim lags behind and wobbles
		var want: float = (target - p).angle() + randfn(0.0, skill_jitter)
		aim_ang = lerp_angle(aim_ang, want, 1.0 - exp(-skill_turn / 60.0))
		bot.aim = p + Vector2.from_angle(aim_ang) * 300.0
		bot.fire = game.ammo > 0
	var emb: int = game.bullets.count_state(Bullets.EMBED)
	if focus_hold > 0.0:
		focus_hold -= 1.0 / 60.0
		bot.focus = focus_hold > 0.0
	elif emb >= 8 and (game.ammo <= 3 or emb >= 18) and (es.size() > 0 or game.boss.core_open > 0.5 or (game.boss is Lockdown and game.boss.state == Lockdown.RUN)):
		focus_hold = 0.25
		bot.focus = true
	else:
		bot.focus = false
	if possess_ai:
		_possess_think(game, nearest, p)


func _possess_think(game, nearest, p: Vector2) -> void:
	var ps = game.possess
	bot.possess = false
	if ps.state == Possess.IDLE:
		if ps.cooldown <= 0.0 and ps.target() != null and frame % 6 == 0:
			bot.possess = true
		return
	if not ps.hosting():
		return
	# inside a shell: close in on the nearest enemy and use the shell's moves
	bot.dash = false
	if nearest != null:
		var np: Vector2 = nearest.pos
		var d: float = np.distance_to(p)
		var want: Vector2 = (np - p).normalized() if d > 150.0 else (np - p).orthogonal().normalized() * 0.6
		bot.move = want
		bot.aim = np
		match ps.shell.kind:
			Enemies.LEECH, Enemies.CHARGER:
				hold_t += 1
				bot.fire = hold_t % 60 < 48
			_:
				bot.fire = frame % 10 < 2
