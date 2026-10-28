extends SceneTree
# Headless: seizing a shell (N1 — chaser and leech).
# Run: Godot --headless --path . -s tests/possess_check.gd --fixed-fps 60
#  1. a real recall that pierces a chaser leaves a cyan mark; E takes it
#  2. seized chaser: drill, drill, spiral — kills a line of chasers, combo counts
#  3. Q while seized: the rounds come home to the shell and fly on as drill wake
#  4. time up: the shell detonates, you step out untouchable, cooldown starts
#  5. seized leech: holding pulls a ring of enemies in, the release detonates it
#  6. hits on a shell cost no crack; three of them break it
#  7. a heavy blow throws an enemy into a wall: it bounces and takes more
#  8. a seized shell does not hold the wave open

var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []


func _initialize() -> void:
	Meta.test_mode = true
	seed(11)
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
	# a still, unkillable dummy in the corner keeps the wave open
	var anchor = spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60))
	anchor.speed = 0.0
	anchor.hp = 1e9
	anchor.maxhp = 1e9
	for e in game.enemies.list:
		if e != anchor and e.state != Enemies.HOST:
			e.state = Enemies.DEAD
	await frames(2)


func spawn(kind: int, at: Vector2):
	var e = game.enemies.spawn(kind, at)
	e.state = Enemies.ALIVE
	e.t = 0.0
	e.vel = Vector2.ZERO
	return e


func press_e() -> void:
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(16)


func _run() -> void:
	# get into the first fight, then run it by hand
	var n := 0
	while game.wave_ctl.phase != Waves.FIGHT and n < 600:
		await process_frame
		n += 1
	game.dev_ammo = true
	await clear()
	var p: Player = game.player
	p.pos = Vector2(400, 540)

	# ---- 1. a real recall marks a chaser: put it on the round's own path
	bot.aim = Vector2(1800, 540)
	await frames(20)
	bot.fire = true
	await frames(3)
	bot.fire = false
	var n2 := 0
	while game.bullets.count_state(Bullets.EMBED) == 0 and n2 < 120:
		await process_frame
		n2 += 1
	var rb = game.bullets.list[0]
	var mid: Vector2 = rb.path[0].lerp(rb.path[rb.path.size() - 1], 0.6)
	var c1 = spawn(Enemies.CHASER, mid)
	c1.hp = 400.0
	c1.maxhp = 400.0
	c1.speed = 0.0
	bot.focus = true
	await frames(20)
	bot.focus = false
	n = 0
	while not game.possess.marks.has(c1.id) and n < 120:
		await process_frame
		n += 1
	check(game.possess.marks.has(c1.id), "回收子弹贯穿追击者后，它带上青色标记")
	await frames(30)
	p.pos = Vector2(800, 540)
	c1.hp = 30.0
	await press_e()
	check(game.possess.hosting() and game.possess.shell == c1, "按 E 夺下被标记的追击者")
	check(not p.visible, "附身时本体消失")
	check(game.enemies.remaining() == 1, "被附身的壳不算场上剩余敌人（只剩角落的假人）")

	# ---- 2. drill, drill, spiral
	var line: Array = []
	for k in 5:
		var e = spawn(Enemies.CHASER, c1.pos + Vector2(110 + k * 60, (k % 2) * 30 - 15))
		e.speed = 0.0
		line.append(e)
	var ring: Array = []
	bot.aim = c1.pos + Vector2(600, 0)
	for k in 3:
		bot.fire = true
		await frames(2)
		bot.fire = false
		await frames(14)
	for k in 4:
		ring.append(spawn(Enemies.CHASER, c1.pos + Vector2.from_angle(TAU * k / 4.0 + 0.4) * 70.0))
	await frames(50)
	var dead := 0
	for e in line + ring:
		if e.state == Enemies.DEAD:
			dead += 1
	check(dead >= 6, "追击者壳：钻头冲刺两段 + 螺旋钻终结，打爆 %d / 9 个" % dead)
	check(game.possess.combo >= 6, "附身连击数累计 %d" % game.possess.combo)

	# ---- 3. Q while seized: rounds come home to the shell, then fly on as wake
	await clear()
	game.possess.t_left = 5.0
	var shell_pos: Vector2 = c1.pos
	game.bullets.fire(shell_pos + Vector2(0, -30), Vector2.UP)
	await frames(40)
	var w = spawn(Enemies.GUARD, shell_pos + Vector2(300, 0))
	w.speed = 0.0
	w.hp = 500.0
	game.possess.dash_dir = Vector2.RIGHT
	bot.focus = true
	await frames(12)
	bot.focus = false
	var woke := false
	for i in 120:
		await process_frame
		if not game.possess.wakes.is_empty():
			woke = true
	check(woke, "附身时按 Q：子弹回到壳上，沿冲刺方向飞出钻头尾流")

	# ---- 4. time up
	game.possess.t_left = 0.2
	await frames(30)
	check(not game.possess.hosting() and p.visible, "时间到：壳自爆，回到本体")
	check(p.invuln > 0.5, "还原后短暂无敌（%.2f）" % p.invuln)
	check(game.possess.cooldown > 7.0, "冷却开始（%.1f 秒）" % game.possess.cooldown)

	# ---- 5. leech: pull, crush, detonate
	await clear()
	game.possess.cooldown = 0.0
	p.pos = Vector2(700, 540)
	var lch = spawn(Enemies.LEECH, Vector2(760, 540))
	lch.speed = 0.0
	game.possess.mark(lch)
	await press_e()
	check(game.possess.hosting() and game.possess.shell == lch, "夺下吸附者")
	var well: Vector2 = lch.pos + Vector2(250, 0)
	var crowd: Array = []
	for k in 6:
		var e = spawn(Enemies.CHASER, well + Vector2.from_angle(TAU * k / 6.0) * 190.0)
		e.speed = 0.0
		e.hp = 60.0
		e.maxhp = 60.0
		crowd.append(e)
	var d0 := 0.0
	for e in crowd:
		d0 += e.pos.distance_to(well)
	bot.aim = well
	bot.fire = true
	await frames(30)
	var d1 := 0.0
	for e in crowd:
		d1 += e.pos.distance_to(game.possess.well_pos) if e.state == Enemies.ALIVE else 0.0
	check(game.possess.well_on and d1 < d0 * 0.75, "吸附者壳：按住引力井把一圈敌人吸到一起（%.0f → %.0f）" % [d0, d1])
	await frames(70)
	bot.fire = false
	await frames(30)
	var gone := 0
	for e in crowd:
		if e.state == Enemies.DEAD:
			gone += 1
	check(gone >= 5, "按满后引爆整团：打爆 %d / 6" % gone)

	# ---- 6. hits on the shell
	var cracks: int = game.cracks
	for k in 3:
		game.possess.iframes = 0.0
		game.on_player_hit(Vector2.LEFT, null)
		await frames(2)
	check(game.cracks == cracks, "壳挨打不扣裂痕（%d → %d）" % [cracks, game.cracks])
	check(not game.possess.hosting() and p.visible, "壳挨 3 下报废，回到本体")

	# ---- 7. wall bounce
	await clear()
	var wb = spawn(Enemies.GUARD, Vector2(Arena.ROOM.end.x - 60.0, 540))
	wb.speed = 0.0
	wb.hp = 300.0
	var hp0: float = wb.hp
	game.possess._deal(wb, 10.0, Vector2.RIGHT, true)
	await frames(30)
	check(wb.hp <= hp0 - 30.0 + 0.1, "重击打到墙上反弹再掉血（%.0f → %.0f）" % [hp0, wb.hp])

	print("POSSESS CHECK " + ("PASS" if fails.is_empty() else "FAIL (%d)" % fails.size()))
	quit(0 if fails.is_empty() else 1)
