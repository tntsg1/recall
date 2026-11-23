extends SceneTree
# Each of chapters 1-3's own enemies in its own room, running a few seconds,
# with stills: they spawn, move, telegraph and attack without errors.
# -> proofs/foes/*.png
# Usage: tools/run_test.sh tests/chapter_foes_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(21)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/foes"))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/foes/%s.png" % name)
	print(name, " saved")


func clear() -> void:
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	game.enemies.zones.clear()


func put(kind: int, at: Vector2):
	var e = game.enemies.spawn(kind, at, 0.0)
	return e


func _run() -> void:
	await frames(2)
	game.dev_god = true
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.hud.intro_t = -1.0
	game.hud.radio_t = -1.0
	var pl: Vector2 = Arena.ROOM.get_center()
	# ---- chapter 1
	clear()
	game.player.pos = pl
	var a = put(Enemies.COUPLER, pl + Vector2(-260, -120))
	var b = put(Enemies.COUPLER, pl + Vector2(-260, 120))
	a.link = b
	b.link = a
	b.seed = a.seed + 1.0
	put(Enemies.SIGNAL, pl + Vector2(420, -200))
	put(Enemies.CHASER, pl + Vector2(380, -100))
	var h = put(Enemies.CHARGER, pl + Vector2(300, 260))
	h.shunt = true
	await frames(150)
	await shot("1_yard")
	await frames(120)
	await shot("1_yard_b")
	# ---- chapter 2
	while Chapters.story(game.chapter) < 2:
		game.next_chapter()
	await frames(30)
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.hud.intro_t = -1.0
	game.hud.radio_t = -1.0
	clear()
	game.player.pos = pl
	var head = put(Enemies.QUEUE, pl + Vector2(-380, 0))
	var ahead = head
	for j in 4:
		var sg = put(Enemies.QSEG, pl + Vector2(-410 - 24 * j, 0))
		sg.link = ahead
		ahead = sg
	put(Enemies.REGISTRAR, pl + Vector2(320, -200))
	put(Enemies.TURNSTILE, pl + Vector2(260, 220))
	await frames(170)
	await shot("2_hall")
	await frames(140)
	await shot("2_hall_b")
	# ---- chapter 3
	while Chapters.story(game.chapter) < 3:
		game.next_chapter()
	await frames(30)
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.hud.intro_t = -1.0
	game.hud.radio_t = -1.0
	clear()
	game.player.pos = pl
	put(Enemies.HOUND, pl + Vector2(-300, -160))
	put(Enemies.HOUND, pl + Vector2(300, 180))
	put(Enemies.DUD, pl + Vector2(-240, 220))
	for j in 4:
		put(Enemies.BYSTANDER, Vector2(Arena.ROOM.position.x + 60, pl.y - 60 + 30 * j))
	await frames(110)
	await shot("3_institute")
	await frames(90)
	await shot("3_institute_b")
	# ---- each new shell: seize it, three clicks, with targets around
	var bad := 0
	for k in [Enemies.COUPLER, Enemies.SIGNAL, Enemies.QUEUE, Enemies.REGISTRAR, Enemies.TURNSTILE, Enemies.HOUND, Enemies.DUD]:
		clear()
		if game.possess.state != Possess.IDLE:
			game.possess.end(false)
			await frames(30)
		game.player.pos = pl
		var sh = put(k, pl)
		sh.state = Enemies.ALIVE
		var foes: Array = []
		for j in 5:
			var f = put(Enemies.CHASER, pl + Vector2(140 + 40 * j, -60 + 30 * j))
			f.state = Enemies.ALIVE
			f.hp = 999.0
			foes.append(f)
		game.wave_ctl.phase = Waves.FIGHT
		game.possess.seize_now(sh)
		await frames(20)
		bot.aim = pl + Vector2(300, 0)
		var hp0 := 0.0
		for f in foes:
			hp0 += f.hp
		for c in 3:
			bot.fire = true
			await frames(2)
			bot.fire = false
			game.wave_ctl.phase = Waves.FIGHT
			await frames(28)
		await frames(20)
		var hp1 := 0.0
		for f in foes:
			hp1 += f.hp
		var nm: String = Txt.t("shell_k%d" % k)
		print("shell ", nm, " dealt ", int(hp0 - hp1))
		if hp1 >= hp0:
			bad += 1
		if k == Enemies.TURNSTILE:
			await shot("shell_turnstile")
	print("shells bad ", bad)
	print("foes ok")
	quit()
