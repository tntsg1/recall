extends SceneTree

var fails := 0
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(1840, 800), "fire": false, "focus": false, "dash": false, "possess": false}
var visual := false
var captured := {}

func _initialize() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	call_deferred("run")

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func shot(label: String) -> void:
	if not visual or captured.has(label):
		return
	captured[label] = true
	var keep: bool = game.paused
	game.paused = true
	game.hud.open_t = 1.0
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var helper = load("E:/godot/cshi_dev/tests/cap.gd")
	helper.save(root, "E:/godot/cshi_dev/proofs/tutorial-" + label + ".png")
	game.paused = keep

func run() -> void:
	if visual:
		root.add_child(load("E:/godot/cshi_dev/tests/test_window.gd").new())
	Settings.loaded = true
	Settings.lang = "zh"
	Settings.fullscreen = false
	Meta.data = {}
	var d := Meta.load_data()
	d.runs = 0
	d.run = null
	d.tutorial_seen = false
	d.tutorial_completed = false
	check(Meta.needs_tutorial(), "fresh player needs training")
	d.runs = 1
	check(not Meta.needs_tutorial(), "existing players are not forced into training")
	d.runs = 0
	d.run = {"chapter": 1, "wave": 2}
	check(not Meta.needs_tutorial(), "continue takes priority over first-time training")
	d.run = null
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	title.sel.menu = title._menu().find("start")
	title._accept(0)
	check(Meta.training_requested == 1, "first Start routes to real training")
	title.start_t = -1.0
	title.queue_free()
	await process_frame
	var saved_run := {"chapter": 1, "wave": 2, "gun": "heavy", "stake": 1}
	d.run = saved_run.duplicate(true)
	Loadout.gun = "heavy"
	Loadout.stake = 2
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game
	check(game.tutorial != null and game.tutorial.stage == TutorialGate.MOVE, "training starts with movement")
	check(Loadout.gun == "standard" and Loadout.stake == 0, "training uses basic gun and difficulty")
	game._save_run()
	check(Meta.run_saved() == saved_run, "training does not overwrite a saved formal run")
	game.on_player_hit(Vector2.LEFT, null)
	check(game.cracks == 5, "practice is safe from damage")
	var counters := JSON.stringify(d)
	game.ach("first_recall")
	Meta.count("beat")
	check(JSON.stringify(d) == counters, "practice does not award achievements or change meta counters")
	var early_done := false
	var short_hold := 0
	var last_stage := -1
	var pstep := 0
	var pt := 0
	for frame in 3600:
		var t = game.tutorial
		if t.stage != last_stage:
			print("STAGE ", t.stage)
			await shot(str(t.stage))
			last_stage = t.stage
		bot.move = Vector2.ZERO
		bot.fire = false
		bot.focus = false
		bot.dash = false
		bot.possess = false
		match t.stage:
			TutorialGate.MOVE:
				bot.move = (TutorialGate.GOAL - game.player.pos).normalized()
			TutorialGate.SHOOT:
				if short_hold > 6:
					early_done = true
				bot.fire = true
			TutorialGate.HOLD:
				if not early_done:
					short_hold += 1
					bot.focus = short_hold <= 6
				else:
					bot.focus = true
			TutorialGate.DASH:
				bot.dash = not t.dashed
			TutorialGate.POSSESS:
				# shoot through the target into the wall, recall, seize it, break the others
				pt += 1
				var hd = t.host_dummy
				match pstep:
					0:
						bot.aim = hd.pos + (hd.pos - game.player.pos).normalized() * 400.0
						if pt > 20:
							bot.fire = true
						if game.bullets.count_state(Bullets.EMBED) > 0:
							pstep = 1
							pt = 0
					1:
						bot.focus = pt < 30
						if game.possess.marks.has(hd.id):
							pstep = 2
							pt = 0
						elif pt > 200:
							pstep = 0
							pt = 0
					2:
						bot.possess = pt < 3
						if game.possess.hosting():
							pstep = 3
							pt = 0
					3:
						var near = null
						for td in t.targets:
							if td.state == Enemies.ALIVE:
								near = td
								break
						if near != null:
							bot.aim = near.pos
							bot.move = (near.pos - game.player.pos).normalized() if near.pos.distance_to(game.player.pos) > 120.0 else Vector2.ZERO
						bot.fire = pt % 12 < 2
			TutorialGate.COMPLETE:
				break
		await process_frame
	var t = game.tutorial
	print("TRAINING END stage=", t.stage, " hit=", t.return_hit, " arrived=", t.returned, " focus=", game.focusing, " ammo=", game.ammo, " embed=", game.bullets.count_state(Bullets.EMBED), " active=", game.bullets.recall_active(), " dummy=", t.dummy.hp if t.dummy != null else -1)
	check(early_done and t.retry_note, "releasing too early offers a recoverable retry")
	check(t.stage == TutorialGate.COMPLETE, "real move/fire/embed/preview/return/dash/seize sequence completes")
	check(t.return_hit and t.returned, "real return round hits target and reaches magazine")
	check(t.dashed, "actual successful dash required")
	check(game.wave_ctl.index == 0 and not game.picking, "random waves and card rewards stay out of training")
	check(Meta.run_saved() == saved_run, "completion preserves existing formal save")
	Meta.test_mode = false
	Meta.finish_tutorial(true)
	Meta.data = {}
	check(bool(Meta.load_data().get("tutorial_completed", false)) and not Meta.needs_tutorial(), "completion persists on disk and suppresses future first-time routing")
	if visual:
		Txt.zh = false
		await shot("complete-en")
	game.queue_free()
	await process_frame
	check(Loadout.gun == "heavy" and Loadout.stake == 2 and not Meta.training_active, "leaving restores selected gun and stake")
	Meta.training_requested = 2
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game
	bot.move = Vector2.ZERO
	game.paused = true
	game.tutorial.step(60.0)
	check(game.tutorial.stage == TutorialGate.MOVE, "reading or waiting does not auto-complete a task")
	game._pause_choice("restart")
	for i in 100:
		await process_frame
	game = current_scene
	game.paused = true
	check(game.tutorial != null and game.tutorial.stage == TutorialGate.MOVE and game.tutorial.entry == 2, "pause Restart restarts training rather than entering a formal run")
	var cancel := InputEventAction.new()
	cancel.action = "ui_focus_next"
	cancel.pressed = true
	game.tutorial.handle_input(cancel)
	check(game.tutorial.leaving and not game.lost, "skip works without a death or loss")
	for i in 100:
		await process_frame
	check(current_scene != game and current_scene.get_script().resource_path == "res://scripts/title.gd", "replay skip returns to title")
	var persisted = Meta.run_saved()
	check(persisted != null and int(persisted.chapter) == 1 and int(persisted.wave) == 2 and str(persisted.gun) == "heavy", "replay skip preserves Continue")
	var replay_title = current_scene
	replay_title.start_t = -1.0
	replay_title.sel.menu = replay_title._menu().find("tutorial")
	replay_title._accept(0)
	check(Meta.training_requested == 2, "title always offers a replay route")
	replay_title.start_t = -1.0
	Meta.training_requested = 0
	Meta.merge({"tutorial_seen": true, "tutorial_completed": true})
	check(bool(Meta.load_data().tutorial_completed), "cloud merge retains tutorial completion")
	replay_title.queue_free()
	await process_frame
	Meta.training_requested = 1
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game
	game.tutorial.finish(false)
	for i in 100:
		await process_frame
	game = current_scene
	game.paused = true
	check(game.tutorial == null and not Meta.training_active, "first-time skip leads into a normal playable run")
	print("TUTORIAL CHECK " + ("PASS" if fails == 0 else "FAIL"))
	quit(0 if fails == 0 else 1)
