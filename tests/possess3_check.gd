extends SceneTree
# Headless: N3 — the 夺壳 school's three levels, and seized shells hurting bosses.
# Run: Godot --headless --path . -s tests/possess3_check.gd --fixed-fps 60

var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []


func _initialize() -> void:
	Meta.test_mode = true
	seed(31)
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


func spawn(kind: int, at: Vector2, hp: float = 300.0):
	var e = game.enemies.spawn(kind, at)
	e.state = Enemies.ALIVE
	e.t = 0.0
	e.speed = 0.0
	e.hp = hp
	e.maxhp = hp
	return e


func clear() -> void:
	if game.possess.hosting():
		game.possess.end(false, true)
	game.wave_ctl.queue.clear()
	var anchor = spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60), 1e9)
	for e in game.enemies.list:
		if e != anchor and e.state != Enemies.HOST:
			e.state = Enemies.DEAD
	await frames(2)
	game.possess.cooldown = 0.0


func press_e() -> void:
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(16)


func _run() -> void:
	var n := 0
	while game.wave_ctl.phase != Waves.FIGHT and n < 600:
		await process_frame
		n += 1
	game.dev_ammo = true

	# ---- the school is in the card pool
	check(Cards.SCHOOLS.has("possess") and game.lv.has("possess"), "夺壳流派进了卡池")

	# ---- Lv1: 7.5 s in the shell
	await clear()
	game.lv.possess = 1
	game.player.pos = Vector2(700, 540)
	var a = spawn(Enemies.CHASER, Vector2(780, 540))
	game.possess.mark(a)
	check(game.possess.marks[a.id][1] > 4.0, "1 级：标记多留 50%%（%.1f 秒）" % game.possess.marks[a.id][1])
	await press_e()
	check(game.possess.hosting() and game.possess.t_left > 7.0, "1 级：附身时长 7.5 秒（%.1f）" % game.possess.t_left)

	# ---- Lv2: when the shell ends, the mind jumps into the next marked enemy
	game.lv.possess = 2
	var b = spawn(Enemies.GUARD, a.pos + Vector2(250, 60))
	game.possess.mark(b)
	game.possess.t_left = 0.05
	await frames(40)
	check(game.possess.hosting() and game.possess.shell == b, "2 级：壳结束后意识自动连锁跳进下一个被标记的敌人")
	game.possess.end(false, false, true)
	await frames(30)
	check(not game.possess.busy(), "按 E 主动退出时不连锁")

	# ---- Lv3: harder hits, a blast twice as wide
	await clear()
	game.lv.possess = 3
	game.player.pos = Vector2(700, 540)
	var c = spawn(Enemies.CHASER, Vector2(780, 540))
	game.possess.mark(c)
	await press_e()
	var far = spawn(Enemies.GUARD, c.pos + Vector2(190, 0), 500.0)
	game.possess.end(false)
	await frames(10)
	check(far.hp < 500.0, "3 级：自爆范围翻倍，190 像素外也炸到（%.0f）" % far.hp)
	check(is_equal_approx(game.possess.power(), 1.35), "3 级：招式伤害 ×1.35")
	game.lv.possess = 0

	# ---- bosses: a shell's moves hurt the open core (the train's tail)
	for i in Chapters.count():
		if Chapters.boss(i) == "train":
			for k in i:
				game.next_chapter()
			break
	game.dev_action("boss", null)
	n = 0
	var bs = game.boss
	while n < 60 * 40 and not (bs.alive() and bs.core_open > 0.5):
		await process_frame
		n += 1
		bs = game.boss
	check(bs.alive() and bs.core_open > 0.5, "进入 Boss 战，核心打开")
	var hp0: float = bs.hp
	game.dev_god = true
	game.possess.cooldown = 0.0
	var m = spawn(Enemies.CHASER, bs.core_pos() + Vector2(0, 40))
	game.possess.seize_now(m)
	await frames(2)
	game.possess._boss_area(bs.core_pos() + Vector2(0, 40), 120.0, 100.0)
	check(bs.hp < hp0, "壳的范围招式能打 Boss 核心（%.0f → %.0f）" % [hp0, bs.hp])
	var hp1: float = bs.hp
	var cp: Vector2 = bs.core_pos()
	game.possess.boss_hit.clear()
	game.possess._boss_line(cp + Vector2(-300, 0), cp + Vector2(300, 0), 100.0, "t")
	check(bs.hp < hp1 or not bs.core_open > 0.5, "壳的直线招式穿过核心也能打 Boss")

	print("POSSESS3 CHECK " + ("PASS" if fails.is_empty() else "FAIL (%d)" % fails.size()))
	quit(0 if fails.is_empty() else 1)
