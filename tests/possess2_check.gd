extends SceneTree
# Headless: seizing a shell, N2 — guard, charger, prism, pulse, echo.
# Run: Godot --headless --path . -s tests/possess2_check.gd --fixed-fps 60

var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []


func _initialize() -> void:
	Meta.test_mode = true
	seed(21)
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func clear() -> void:
	game.wave_ctl.queue.clear()
	var anchor = spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60))
	anchor.hp = 1e9
	anchor.maxhp = 1e9
	for e in game.enemies.list:
		if e != anchor and e.state != Enemies.HOST:
			e.state = Enemies.DEAD
	await frames(2)


func spawn(kind: int, at: Vector2, hp: float = -1.0):
	var e = game.enemies.spawn(kind, at)
	e.state = Enemies.ALIVE
	e.t = 0.0
	e.speed = 0.0
	if hp > 0.0:
		e.hp = hp
		e.maxhp = hp
	return e


func seize(kind: int, at: Vector2):
	if game.possess.hosting():
		game.possess.end(false, true)
	await clear()
	game.possess.cooldown = 0.0
	game.player.pos = at - Vector2(80, 0)
	var e = spawn(kind, at)
	game.possess.mark(e)
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(16)
	check(game.possess.hosting() and game.possess.shell == e, "夺下 %s" % Possess.NAMES[kind])
	return e


func click(n: int = 1, gap: int = 12) -> void:
	for k in n:
		bot.fire = true
		await frames(2)
		bot.fire = false
		await frames(gap)


func hurt_total(list: Array) -> float:
	var d := 0.0
	for e in list:
		d += e.maxhp - maxf(e.hp, 0.0) if e.state != Enemies.DEAD else e.maxhp
	return d


func _run() -> void:
	var n := 0
	while game.wave_ctl.phase != Waves.FIGHT and n < 600:
		await process_frame
		n += 1
	game.dev_ammo = true

	# ---- guard: front blocks, shove + sweep, then the rush pins a row to the wall
	var g = await seize(Enemies.GUARD, Vector2(1200, 540))
	bot.aim = g.pos + Vector2(600, 0)
	await frames(10)
	var cracks: int = game.cracks
	var hl: int = game.possess.hits_left
	game.possess.iframes = 0.0
	game.on_player_hit(Vector2.LEFT, null)
	check(game.possess.hits_left == hl and game.cracks == cracks, "盾卫壳：正面来的攻击被盾挡下")
	var row: Array = []
	for k in 3:
		row.append(spawn(Enemies.CHASER, g.pos + Vector2(70 + k * 40, (k - 1) * 18), 400.0))
	await click(2, 10)
	await click(1, 50)
	var pinned := 0
	for e in row:
		if e.state == Enemies.DEAD or e.pinned > 0.0:
			pinned += 1
	check(hurt_total(row) > 300.0, "盾推 + 横扫 + 盾冲：一排敌人受伤 %.0f" % hurt_total(row))
	check(pinned >= 2, "盾冲把 %d 个敌人顶到墙上钉住（回收伤害 ×2）" % pinned)

	# ---- charger: hold, release, the walls throw it back, the third blows
	var c = await seize(Enemies.CHARGER, Vector2(960, 540))
	bot.aim = c.pos + Vector2(600, -90)
	var lane: Array = []
	for k in 4:
		lane.append(spawn(Enemies.GUARD, c.pos + Vector2(150 + k * 110, -22 - k * 17), 600.0))
	bot.fire = true
	await frames(25)
	bot.fire = false
	var segs := 0
	for i in 150:
		await process_frame
		segs = maxi(segs, game.possess.ram_seg)
	check(segs >= 2, "冲锋者壳：撞墙反弹再冲（%d 段）" % segs)
	check(hurt_total(lane) >= 200.0, "冲锋路线上的敌人被撞穿（伤害 %.0f）" % hurt_total(lane))
	check(game.possess.lane_bonus(c.pos + Vector2(300, -45)) > 1.0 or game.possess.lanes.size() > 0, "冲过的地方留下红线（沿线回收加伤）")

	# ---- prism: one, three, twelve beams
	var p = await seize(Enemies.PRISM, Vector2(960, 540))
	bot.aim = p.pos + Vector2(500, 0)
	var ring: Array = []
	for k in 8:
		ring.append(spawn(Enemies.CHASER, p.pos + Vector2.from_angle(TAU * k / 12.0 + 0.05) * 230.0, 300.0))
	await click(3, 10)
	await frames(10)
	var hit := 0
	for e in ring:
		if e.state == Enemies.DEAD or e.hp < e.maxhp:
			hit += 1
	check(hit >= 6, "棱镜壳：第三下棱镜爆 12 道光，打中四周 %d / 8" % hit)

	# ---- pulse: beat blink — blink, blink, leap and slam
	var u = await seize(Enemies.PULSE, Vector2(600, 540))
	var start: Vector2 = u.pos
	var spot := Vector2(1150, 540)
	var crowd: Array = []
	for k in 6:
		crowd.append(spawn(Enemies.GUARD, spot + Vector2.from_angle(TAU * k / 6.0) * 150.0, 900.0))
	bot.aim = spot
	await click(1, 8)
	check(u.pos.distance_to(start) > 250.0, "脉冲体壳：点一下瞬移到准星方向（%.0f 像素）" % u.pos.distance_to(start))
	await click(1, 8)
	await click(1, 40)
	var touched := 0
	for e in crowd:
		if e.hp < e.maxhp - 60.0:
			touched += 1
	check(touched >= 4, "第三下跃起砸地，大范围打到 %d / 6" % touched)
	check(u.pos.distance_to(spot) < 40.0, "砸在准星处")

	# ---- echo: two copies, then they replay your path and blow
	var o = await seize(Enemies.ECHO, Vector2(700, 540))
	await click(1, 4)
	bot.move = Vector2.RIGHT
	await frames(40)
	bot.move = Vector2.ZERO
	await click(1, 4)
	var path_foes: Array = []
	for k in 4:
		path_foes.append(spawn(Enemies.CHASER, o.pos + Vector2(-60 - k * 45, 30), 200.0))
	await click(1, 4)
	check(not game.possess.clones.is_empty() and game.possess.clones[0].replay, "回声壳：第三下两个分身开始重走你的路线")
	await frames(90)
	check(hurt_total(path_foes) > 100.0, "分身路过和爆炸打伤路上的敌人（%.0f）" % hurt_total(path_foes))

	print("POSSESS2 CHECK " + ("PASS" if fails.is_empty() else "FAIL (%d)" % fails.size()))
	quit(0 if fails.is_empty() else 1)
