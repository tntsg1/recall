extends SceneTree
# Headless: the split damage falloff, and the enemy a recall leaves for seizing.
# Run: Godot --headless --path . -s tests/spare_check.gd --fixed-fps 60
#  1. each generation of split rounds hits ×0.8, on the way out and on the way back
#  2. a recall that would finish an enemy leaves it on 1 HP, reeling and marked
#  3. it can be seized; it does not act while reeling
#  4. with E on cooldown, or just after a spare, a recall kills as usual

var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []


func _initialize() -> void:
	Meta.test_mode = true
	seed(3)
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
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var d = game.enemies.spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60))
	d.state = Enemies.ALIVE
	d.hp = 99999.0
	d.t = 1.0


func chaser(at: Vector2, hp: float):
	var e = game.enemies.spawn(Enemies.CHASER, at)
	e.state = Enemies.ALIVE
	e.t = 1.0
	e.hp = hp
	e.maxhp = hp
	return e


# A round laid past `e`'s spot, then recalled through it.
func recall_through(at: Vector2, e_at: Vector2, hp: float):
	game.player.pos = at
	game.bullets.fire(at, Vector2.RIGHT)
	var rb = game.bullets.list[game.bullets.list.size() - 1]
	for k in 90:
		await frames(1)
		game.player.pos = at
		if rb.state == Bullets.EMBED and rb.t > 0.6:
			break
	var e = chaser(e_at, hp)
	bot.focus = true
	await frames(12)
	e.pos = e_at
	bot.focus = false
	for k in 40:
		await frames(1)
		game.player.pos = at
		if e.state == Enemies.ALIVE and e.dazed <= 0.0:
			e.pos = e_at
	return e


func _run() -> void:
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	clear()
	# 1. the falloff
	game.lv.split = 1
	var c: Vector2 = Arena.ROOM.get_center()
	var p = Bullets.B.new()
	p.path = PackedVector2Array([c, c + Vector2(100, 0)])
	p.cum = PackedFloat32Array([0.0, 100.0])
	p.pos = c + Vector2(100, 0)
	game.bullets.list.append(p)
	game.bullets.split(p, p.pos, Vector2.RIGHT, 100.0)
	var g1 = game.bullets.list[game.bullets.list.size() - 1]
	check(is_equal_approx(g1.dmg, Bullets.CHILD_DMG * 0.8), "第 1 代分裂弹去程伤害 ×0.8（%.2f）" % g1.dmg)
	game.bullets.split(g1, g1.pos, Vector2.RIGHT, g1.total())
	var g2 = game.bullets.list[game.bullets.list.size() - 1]
	check(is_equal_approx(g2.dmg, Bullets.CHILD_DMG * 0.64), "第 2 代再 ×0.8（%.2f）" % g2.dmg)
	check(is_equal_approx(g2.split_k, 0.64), "第 2 代的回收伤害也带上系数")
	game.bullets.list.clear()
	game.lv.split = 0
	# 2-3. spared, reeling, seizable
	var e = await recall_through(c, c + Vector2(180, 0), 10.0)
	check(e.state == Enemies.ALIVE and is_equal_approx(e.hp, 1.0), "回收本该打死的敌人留 1 血（hp %.1f）" % e.hp)
	check(game.possess.marks.has(e.id), "它带着标记")
	check(game.possess.target() == e, "E 可以附身它")
	game.possess.press()
	await frames(20)
	check(game.possess.state == Possess.HOST, "按 E 成功附身")
	game.possess.end(false, true)
	await frames(30)
	game.possess.cooldown = 0.0
	clear()
	# 4. right after a spare: killed as usual
	var e2 = await recall_through(c, c + Vector2(180, 0), 10.0)
	check(e2.state != Enemies.ALIVE, "刚保留过一只，6 秒内照常打死")
	game.possess.spare_cd = 0.0
	game.possess.cooldown = 5.0
	clear()
	var e3 = await recall_through(c, c + Vector2(180, 0), 10.0)
	check(e3.state != Enemies.ALIVE, "E 在冷却时照常打死")
	print("SPARE ", "PASS" if fails.is_empty() else "FAIL %s" % str(fails))
	quit(1 if fails.size() > 0 else 0)
