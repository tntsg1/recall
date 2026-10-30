extends SceneTree

var fails := 0
var game

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		fails += 1

func hit() -> void:
	game.player.invuln = 0.0
	game.on_player_hit(Vector2.LEFT, null)

func run() -> void:
	Settings.loaded = true
	Settings.assist = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.paused = true
	Meta.test_mode = true
	game.wave_ctl.phase = Waves.FIGHT
	game.wave_ctl.index = 2
	game.cracks = 5
	hit()
	check(game.cracks == 4, "assist off: one hit costs one crack")
	Settings.assist = true
	Settings.damage_reduction = 20
	game.cracks = 5
	for i in 5:
		hit()
	check(game.cracks == 1, "20 percent reduction: five hits cost four cracks")
	check(game.hits_taken == 6 and game.wave_ctl.penalty == 30.0, "hit count and penalties still apply")
	Settings.damage_reduction = 80
	game.assist_damage = 0.0
	game.cracks = 5
	for i in 5:
		hit()
	check(game.cracks == 4, "80 percent reduction: five hits cost one crack")
	Settings.damage_reduction = 0
	Settings.retry_limit = 1
	game.cracks = 3
	game.lv.split = 2
	game.phoenix_used = true
	game._save_run()
	var original_plan: String = JSON.stringify(game.wave_ctl.plan)
	game.cracks = 1
	game.lv.split = 0
	hit()
	check(not game.lost and game.assist_retries_used == 1, "fatal hit spends one retry without recording a loss")
	check(int(Meta.resume.assist_retries_used) == 1, "spent retry is in resume snapshot")
	for i in 6:
		await process_frame
	game = current_scene
	game.paused = true
	Meta.test_mode = true
	check(game.cracks == 3 and game.lv.split == 2, "actual scene reload restores checkpoint health and build")
	check(game.assist_retries_used == 1 and game.phoenix_used, "reload preserves spent retries and once-per-run relic state")
	check(JSON.stringify(game.wave_ctl.plan) == original_plan, "reload preserves the same random enemy plan")
	game.wave_ctl.phase = Waves.FIGHT
	game.wave_ctl.index = 2
	game.on_wave_start()
	check(game.player.invuln == 2.0, "restored checkpoint grants entry protection")
	Settings.assist = false
	Settings.assist = true
	check(game.assist_retries_used == 1, "toggle does not refill retries")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.run_snapshot()))
	Meta.save_run(snap)
	check(int(Meta.run_saved().assist_retries_used) == 1, "saved run retains retry counter")
	game.cracks = 1
	hit()
	check(game.lost, "allowance exhausted: fatal hit ends the run")
	Settings.damage_reduction = 40
	Settings.retry_limit = 5
	Settings.save()
	Settings.assist = false
	Settings.damage_reduction = 0
	Settings.retry_limit = 0
	Settings.loaded = false
	Settings.load_all()
	check(Settings.assist and Settings.damage_reduction == 40 and Settings.retry_limit == 5, "assist settings survive config reload")
	game.queue_free()
	await process_frame
	Settings.damage_reduction = 0
	Settings.retry_limit = 3
	for chapter in 5:
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.paused = true
		Meta.test_mode = true
		var boss_snap := snap.duplicate(true)
		boss_snap.chapter = chapter
		boss_snap.story = Chapters.story(chapter)
		boss_snap.wave = Waves.BOSS
		boss_snap.cracks = 3
		boss_snap.assist_retries_used = 0
		boss_snap.erase("plan")
		game._resume(boss_snap)
		game.wave_ctl.index = Waves.BOSS
		game.wave_ctl.phase = Waves.TITLE
		game.wave_ctl.t = 3.0
		game.wave_ctl.step(0.01)
		game.cracks = 1
		hit()
		for i in 6:
			await process_frame
		game = current_scene
		game.paused = true
		Meta.test_mode = true
		game.wave_ctl.index = Waves.BOSS
		game.wave_ctl.phase = Waves.TITLE
		game.wave_ctl.t = 3.0
		game.wave_ctl.step(0.01)
		check(game.chapter == chapter and game.cracks == 3 and game.assist_retries_used == 1 and game.boss.state != Boss.DEAD, "chapter %d boss checkpoint restarts with health and spent allowance" % (chapter + 1))
		game.queue_free()
		await process_frame
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	title.page = "settings"
	title.sel.settings = title.SETTINGS.find("assist")
	title._set_change(1)
	check(is_instance_valid(title.assist_panel), "title settings opens assist panel")
	title.assist_panel.close()
	# (it fades out first)
	for k in 30:
		await process_frame
	check(not is_instance_valid(title.assist_panel), "back closes panel")
	while ResourceLoader.load_threaded_get_status("res://scenes/main.tscn") == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await process_frame
	title.queue_free()
	await process_frame
	await process_frame
	print("ASSIST CHECK " + ("PASS" if fails == 0 else "FAIL"))
	quit(0 if fails == 0 else 1)
