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
		var wd: float = bs.pos.distance_to(p)
		if wd < 260.0:
			move += (p - bs.pos) / maxf(wd, 1.0) * (260.0 - wd) / 60.0
		# circle round to its open back
		move += (p - bs.pos).orthogonal().normalized() * 0.8
	if (bs is Boss and (bs.state == Boss.RUN or bs.state == Boss.ENTER)) or (bs is Warden and bs.state == Warden.RUN) or (bs is Devourer and bs.state == Devourer.RUN) or (bs is Metronome and bs.state == Metronome.RUN) or (bs is Zero and bs.state == Zero.RUN):
		if bs.core_open > 0.5 or not (bs is Boss):
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
	elif emb >= 8 and (game.ammo <= 3 or emb >= 18) and (es.size() > 0 or game.boss.core_open > 0.5):
		focus_hold = 0.25
		bot.focus = true
	else:
		bot.focus = false
