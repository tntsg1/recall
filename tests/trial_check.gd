extends SceneTree
# Headless: the title's 夺壳试玩 room keeps three chasers and one of every other seizable kind coming,
# nothing else, never ends, and never writes the save.
# Run: Godot --headless --path . -s tests/trial_check.gd --fixed-fps 60

var fails: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Meta.possess_trial = true
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.trial and Meta.test_mode, "进入夺壳试玩：不写存档")
	for i in 60 * 12:
		await process_frame
	var have := {}
	for e in game.enemies.list:
		if e.state != Enemies.DEAD:
			have[e.kind] = have.get(e.kind, 0) + 1
	check(have.get(Enemies.CHASER, 0) == 3 and have.size() == 7, "七种能夺的敌人都在场：%s" % str(have))
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	for i in 60 * 6:
		await process_frame
	check(game.wave_ctl.phase == Waves.FIGHT and game.enemies.remaining() == 9, "打光了会马上补，试玩不会结束（%d）" % game.enemies.remaining())
	print("TRIAL CHECK " + ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)
