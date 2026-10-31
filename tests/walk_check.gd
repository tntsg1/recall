extends SceneTree
# Headless: the Lightrun school (光行).
# Run: Godot --headless --path . -s tests/walk_check.gd --fixed-fps 60
#  1. it stays out of the card pool until light-speed travel is yours
#  2. level 1: a run leaves its line burning; what touches it is hurt; it dies out
#  3. level 2: after a run the dodge is back for a moment, the next line can be
#     struck, and the run does not use up the recall hold
#  4. level 3: a run takes back the rounds it passes, and hits harder for each

var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []


func _initialize() -> void:
	Meta.test_mode = true
	seed(5)
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


func lay_line(at: Vector2, dir: Vector2):
	game.player.pos = at
	game.bullets.fire(at, dir)
	game.ammo -= 1
	var rb = game.bullets.list[game.bullets.list.size() - 1]
	for k in 120:
		await frames(1)
		game.player.pos = at
		if rb.state == Bullets.EMBED and rb.t > 0.6:
			break
	return rb


func hold_recall() -> void:
	bot.focus = true
	for k in 30:
		await frames(1)


func dash(dir: Vector2) -> void:
	bot.move = dir
	bot.dash = true
	await frames(2)
	bot.dash = false
	bot.move = Vector2.ZERO


func land() -> void:
	for k in 90:
		if not game.lightwalk.on:
			break
		await frames(1)


func dummy(at: Vector2):
	var foe = game.enemies.spawn(Enemies.CHASER, at)
	foe.state = Enemies.ALIVE
	foe.t = 1.0
	foe.hp = 999.0
	return foe


func settle() -> void:
	bot.focus = false
	await frames(60)
	for b in game.bullets.list:
		b.walked = false
	game.player.dash_cd = 0.0


func _run() -> void:
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	clear()
	# 1. the card pool
	var seen := false
	game.chapter = 0
	for k in 300:
		var c: Dictionary = Cards._school(game)
		seen = seen or c.get("id", "") == "walk"
	check(not seen, "第 1 章卡池里没有光行")
	game.next_chapter()
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	await frames(2)
	clear()
	for k in 300:
		var c: Dictionary = Cards._school(game)
		seen = seen or c.get("id", "") == "walk"
	check(seen, "第 2 章起光行进卡池")
	var c0: Vector2 = Arena.ROOM.get_center()
	# 2. level 1
	game.lv.walk = 1
	var r1 = await lay_line(c0, Vector2.RIGHT)
	await hold_recall()
	game.player.pos = c0 + Vector2(20, 20)
	await dash(Vector2.RIGHT)
	check(game.lightwalk.on, "光痕：撞线开始穿行")
	await land()
	check(game.lightwalk.burns.size() == 1, "光痕：穿过的线留下灼烧带")
	var foe = dummy(c0.lerp(r1.pos, 0.5))
	var hp0: float = foe.hp
	await frames(50)
	foe.pos = c0.lerp(r1.pos, 0.5)
	check(foe.hp < hp0, "光痕：碰到灼烧带的敌人掉血（%.0f）" % (hp0 - foe.hp))
	foe.state = Enemies.DEAD
	await frames(120)
	check(game.lightwalk.burns.is_empty(), "光痕：灼烧带 1.5 秒后消失")
	await settle()
	clear()
	# 3. level 2
	game.lv.walk = 2
	var r2 = await lay_line(c0, Vector2.RIGHT)
	var r3 = await lay_line(c0, Vector2.UP)
	await hold_recall()
	var held: float = game.focus_time
	game.player.pos = c0.lerp(r2.pos, 0.5) + Vector2(0, 16)
	await dash(Vector2.LEFT)
	check(game.lightwalk.on, "折射连跳：第一条线开始穿行")
	await land()
	check(game.lightwalk.chain_t > 0.0, "折射连跳：穿到头后打开连跳窗口")
	check(game.player.dash_cd <= 0.0, "折射连跳：窗口内闪避冷却清零")
	check(game.focus_time - held < 0.2, "折射连跳：穿行不消耗回收预览时间（%.2f）" % (game.focus_time - held))
	await dash(Vector2.UP)
	check(game.lightwalk.on and game.lightwalk.b == r3, "折射连跳：窗口内撞上下一条线")
	check(game.lightwalk.chain_n == 1, "折射连跳：连跳计数 +1")
	await land()
	await frames(50)
	check(game.player.dash_cd > 0.0 or game.lightwalk.chain_t > 0.0 or not game.focusing, "折射连跳：窗口结束后冷却照常")
	await settle()
	clear()
	# 4. level 3
	game.lv.walk = 3
	var r4 = await lay_line(c0, Vector2.RIGHT)
	var r5 = await lay_line(c0 + Vector2(0, 60), Vector2.RIGHT)
	var foe2 = dummy(c0.lerp(r4.pos, 0.96))
	await hold_recall()
	foe2.pos = c0.lerp(r4.pos, 0.96)
	var hp1: float = foe2.hp
	var plain: float = Bullets.RET_DMG * 0.5 * game.gun_dmg()
	game.player.pos = c0 + Vector2(20, 16)
	await dash(Vector2.RIGHT)
	await land()
	check(r5.state != Bullets.EMBED, "满载：沿线的另一颗子弹被收回")
	check(game.lightwalk.loaded >= 1, "满载：记下收回数（%d）" % game.lightwalk.loaded)
	check(hp1 - foe2.hp > plain, "满载：穿行伤害提高（%.1f > %.1f）" % [hp1 - foe2.hp, plain])
	bot.focus = false
	print("WALK ", "PASS" if fails.is_empty() else "FAIL %s" % str(fails))
	quit(1 if fails.size() > 0 else 0)
