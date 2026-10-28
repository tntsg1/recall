extends SceneTree
# Headless: the title's 夺壳试玩 room keeps six chasers and two leeches coming,
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
	var ch := 0
	var le := 0
	var other := 0
	for e in game.enemies.list:
		if e.state == Enemies.DEAD:
			continue
		if e.kind == Enemies.CHASER:
			ch += 1
		elif e.kind == Enemies.LEECH:
			le += 1
		else:
			other += 1
	check(ch == 6 and le == 2 and other == 0, "场上 6 追击者 + 2 吸附者，没有别的（%d / %d / %d）" % [ch, le, other])
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	for i in 60 * 6:
		await process_frame
	check(game.wave_ctl.phase == Waves.FIGHT and game.enemies.remaining() == 8, "打光了会马上补，试玩不会结束（%d）" % game.enemies.remaining())
	print("TRIAL CHECK " + ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)
