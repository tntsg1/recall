extends SceneTree
# Each of chapters 4-6's own enemies in its own room, running a few seconds,
# with stills: they spawn, move, telegraph and attack without errors.
# -> proofs/foes/*.png
# Usage: tools/run_test.sh tests/chapter_foes2_shots.gd --fixed-fps 60

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


func goto(story: int) -> void:
	while Chapters.story(game.chapter) < story:
		game.next_chapter()
	await frames(30)
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.hud.intro_t = -1.0
	game.hud.radio_t = -1.0
	clear()


func _run() -> void:
	await frames(2)
	game.dev_god = true
	var pl: Vector2 = Arena.ROOM.get_center()
	var bad := 0
	# ---- chapter 4: hopper, forklift, a reserve leech
	await goto(4)
	game.player.pos = pl
	var hop = put(Enemies.HOPPER, Vector2(Arena.ROOM.position.x + 80, pl.y - 120))
	var fk = put(Enemies.FORKLIFT, pl + Vector2(380, -260))
	put(Enemies.LEECH, pl + Vector2(-200, 240))
	await frames(330)
	await shot("4_union")
	var cans := 0
	for e in game.enemies.list:
		if e.kind == Enemies.CAN and e.state == Enemies.ALIVE:
			cans += 1
	print("cans out ", cans, " hopper at wall ", hop.pos.x < Arena.ROOM.position.x + 40.0, " fork mode ", fk.mode)
	if cans < 2:
		bad += 1
	game.player.pos = Vector2(fk.pos.x, pl.y + 150)
	await frames(50)
	await shot("4_union_b")
	# ---- chapter 5: sleds on the rails, a consist, pantographs
	await goto(5)
	game.player.pos = pl + Vector2(0, 300)
	var sl = put(Enemies.SLED, pl + Vector2(-100, 0))
	put(Enemies.PANTO, pl + Vector2(120, 60))
	var head = put(Enemies.CONSIST, pl + Vector2(-500, -300))
	var ahead = head
	for j in 3:
		var car = put(Enemies.CAR, pl + Vector2(-540 - 36 * j, -300))
		car.link = ahead
		ahead = car
	var modes := {}
	for k in 9:
		await frames(60)
		modes[sl.mode] = true
		game.wave_ctl.phase = Waves.FIGHT
		if k == 4:
			await shot("5_line")
	await shot("5_line_b")
	print("sled modes seen ", modes.keys())
	if modes.size() < 2:
		bad += 1
	# ---- chapter 6: surge, cabler
	await goto(6)
	game.player.pos = pl
	put(Enemies.SURGE, pl + Vector2(-320, -160))
	var cb = put(Enemies.CABLER, pl + Vector2(360, 200))
	await frames(180)
	await shot("6_bureau")
	print("cable points ", cb.cable.size())
	if cb.cable.size() < 4:
		bad += 1
	# ---- each new shell: seize it, three clicks, with targets around
	for k in [Enemies.HOPPER, Enemies.FORKLIFT, Enemies.SLED, Enemies.CONSIST, Enemies.PANTO, Enemies.SURGE, Enemies.CABLER]:
		clear()
		if game.possess.state != Possess.IDLE:
			game.possess.end(false)
			await frames(30)
		game.player.pos = pl
		var sh = put(k, pl)
		sh.state = Enemies.ALIVE
		sh.pos = pl
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
		print("shell ", Txt.t("shell_k%d" % k), " dealt ", int(hp0 - hp1))
		if hp1 >= hp0:
			bad += 1
	print("bad ", bad)
	print("foes2 ok" if bad == 0 else "foes2 FAIL")
	quit()
