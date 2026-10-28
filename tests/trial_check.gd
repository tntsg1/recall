extends SceneTree
# Headless: the title's 训练场 (training yard). Dummies stand on their spots and come
# back after they die; 1–7 put you straight into each shell with no time limit;
# nothing ends and nothing is saved.
# Run: Godot --headless --path . -s tests/trial_check.gd --fixed-fps 60

var fails: Array[String] = []
var game


func check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.pressed = true
	game._unhandled_input(ev)


func _run() -> void:
	Meta.possess_trial = true
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.trial and Meta.test_mode, "进入训练场：不写存档")
	for i in 60 * 6:
		await process_frame
	var alive := 0
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE:
			alive += 1
	check(alive == game.yard_slots.size() and alive >= 10, "木桩全部站好（%d）" % alive)
	var p0: Vector2 = game.yard_slots[0][1]
	await process_frame
	check(game.yard_slots[0][2].pos.distance_to(p0) < 20.0, "木桩待在原位不追人")
	# every number key is a different shell, straight away
	for i in 7:
		key(KEY_1 + i)
		for f in 20:
			await process_frame
		check(game.possess.hosting() and game.possess.shell.kind == game.YARD_KEYS[i], "按 %d 直接变成 %s" % [i + 1, Possess.NAMES[game.YARD_KEYS[i]]])
	for f in 60 * 8:
		await process_frame
	check(game.possess.hosting(), "训练场里附身不限时（8 秒后还在）")
	# kill everything: they come back, the wave never ends
	for sl in game.yard_slots:
		if sl[2] != null:
			sl[2].state = Enemies.DEAD
	for f in 60 * 3:
		await process_frame
	check(game.wave_ctl.phase == Waves.FIGHT and game.enemies.remaining() == game.yard_slots.size(), "打死的木桩 1.2 秒后原地复活（%d）" % game.enemies.remaining())
	# L: the 夺壳 school level; Y: real time limit; M: mark every dummy -> the Lv2 chain
	key(KEY_L)
	key(KEY_L)
	check(game.lv.possess == 2, "L：夺壳流派切到 Lv2（%d）" % game.lv.possess)
	key(KEY_1)
	for f in 20:
		await process_frame
	key(KEY_M)
	check(game.possess.marks.size() >= 5, "M：标记所有木桩（%d）" % game.possess.marks.size())
	key(KEY_Y)
	check(game.yard_timed and not game.possess.endless, "Y：打开限时")
	var first = game.possess.shell
	game.possess.t_left = 0.05
	for f in 40:
		await process_frame
	check(game.possess.hosting() and game.possess.shell != first, "限时到了，2 级连锁跳进下一个被标记的木桩")
	key(KEY_Y)
	key(KEY_L)
	key(KEY_L)
	check(game.lv.possess == 0 and not game.yard_timed, "再按回到 Lv0、不限时")
	key(KEY_T)
	check(game.yard_live, "T：木桩动起来")
	key(KEY_E)
	print("TRIAL CHECK " + ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)
