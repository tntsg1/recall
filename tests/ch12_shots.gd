extends SceneTree
# Stills of chapter 12 (off-screen): the board's core at the opening, a control
# node reaching for rounds in the walls, the takeover, a column cut, every
# remnant awake; the war body, its breaking, the Chairman in a shell, thrown
# out and coming for you; the true ending: the lights, their flight home, a
# card, the title. Then it checks the run reaches its results.
# -> proofs/lore/ch12_*.png
# Usage: tools/run_test.sh tests/ch12_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(12)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/lore"))
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
	Cap.save(root, "res://proofs/lore/ch12_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 12:
		game.next_chapter()
	await frames(80)
	game.player.pos = Vector2(960, 640)
	await frames(10)
	await shot("1_open")
	while game.wave_ctl.phase != Waves.FIGHT:
		await process_frame
	game.dev_god = true
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var anchor = game.enemies.spawn(Enemies.GUARD, Vector2(1700, 980))
	anchor.state = Enemies.ALIVE
	anchor.hp = 1e9
	await frames(30)
	# rounds into the top wall near the left column, then it powers
	game.nodes.clock = -99.0
	game.player.pos = Vector2(700, 520)
	for k in 5:
		game.bullets.fire(game.player.pos, Vector2.from_angle(-PI * 0.5 + (k - 2) * 0.22))
		await frames(3)
	await frames(30)
	game.player.pos = Vector2(1500, 700)
	game.nodes._power()
	await frames(50)
	await shot("2_node_warn")
	while game.nodes.live_t < ControlNodes.WARN + ControlNodes.TAKE * 0.6:
		await process_frame
	await shot("3_taking")
	while not game.nodes.taken.is_empty():
		await process_frame
		var lit := false
		for b in game.bullets.list:
			if b.foe and b.zero_pass and b.state == Bullets.RETURN:
				lit = true
		if lit:
			break
	await frames(4)
	await shot("3b_called")
	# a column cut by a round into it
	await frames(60)
	game.nodes._power()
	await frames(20)
	var col: Vector2 = ControlNodes.NODES[game.nodes.live]
	game.player.pos = col + Vector2(0, 300 if col.y < 540.0 else -300)
	game.bullets.fire(game.player.pos, (col - game.player.pos).normalized())
	await frames(14)
	await shot("4_cut")
	for e in game.enemies.list:
		if e != anchor:
			e.state = Enemies.DEAD
	for w in Lore.walls(12):
		game.lore.hold["w12_%s" % w[0]] = 9.0
	await frames(40)
	await shot("5_remnants")
	game.dev_jump(Waves.BOSS)
	while game.boss.state != Zero.RUN:
		await process_frame
	var bs = game.boss
	game.player.pos = Vector2(960, 800)
	await frames(200)
	await shot("6_body")
	bs.guard_t = 0.0
	bs.phase = 2
	bs.hp = 1.0
	bs.damage(50.0, false, bs.pos, Vector2.UP)
	await frames(70)
	await shot("7_break")
	while bs.stage != 1 or bs.mode != Zero.IN:
		await process_frame
	await frames(30)
	await shot("8_vessel")
	# seize the shell he is in: he is thrown out, and comes for you
	var v = bs.vessel
	game.possess.cooldown = 0.0
	game.possess.seize_now(v)
	await frames(62)
	await shot("9_out")
	game.possess.end(false, true)
	# finish him; the ending plays
	bs.guard_t = 0.0
	bs.band = 2
	bs.mode = Zero.OUT
	bs.hp = 1.0
	bs.damage(50.0, true, bs.sig, Vector2.UP)
	while not game.ending.running():
		await process_frame
	while game.ending.state != Ending.READY:
		await process_frame
	await frames(20)
	bot.focus = true
	await frames(40)
	await shot("10_lights")
	bot.focus = false
	while game.ending.state != Ending.FLY:
		await process_frame
	await frames(70)
	await shot("11_home")
	while game.ending.state != Ending.CARDS:
		await process_frame
	await frames(80)
	await shot("12_card")
	while game.ending.card < 1 or game.ending.card_t < 1.8:
		await process_frame
	await shot("12b_face")
	while game.ending.card_t < 3.2:
		await process_frame
	await shot("12b2_wipe")
	while game.ending.card < 3 or game.ending.card_t < 2.6:
		await process_frame
	await shot("12c_door")
	while game.ending.card < Ending.CARD_KEYS.size():
		await process_frame
	await frames(80)
	await shot("13_title")
	var w := 0
	while game.wave_ctl.phase != Waves.DONE and w < 1200:
		w += 1
		await process_frame
	print("RUN DONE ", game.wave_ctl.phase == Waves.DONE)
	await frames(90)
	await shot("14_results")
	quit()
