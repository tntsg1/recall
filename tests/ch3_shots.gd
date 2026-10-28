extends SceneTree
# Stills of chapter 3 (off-screen): the laser range at the opening, the fences
# lit, every remnant awake, a seized echo's memory, and the testbed running
# each of its tests and venting. -> proofs/lore/ch3_*.png
# Usage: tools/run_test.sh tests/ch3_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(3)
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
	Cap.save(root, "res://proofs/lore/ch3_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 3:
		game.next_chapter()
	await frames(80)
	game.player.pos = Vector2(960, 860)
	await frames(10)
	await shot("1_open")
	while game.wave_ctl.phase != Waves.FIGHT:
		await process_frame
	game.dev_god = true
	game.lasers.force(true)
	game.player.pos = Vector2(760, 780)
	await frames(70)
	await shot("2_lasers")
	game.lasers.release()
	for w in Lore.walls(3):
		game.lore.hold["w3_%s" % w[0]] = 9.0
	await frames(40)
	await shot("3_remnants")
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var anchor = game.enemies.spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60))
	anchor.state = Enemies.ALIVE
	anchor.hp = 1e9
	game.player.pos = Vector2(820, 600)
	var p = game.enemies.spawn(Enemies.ECHO, Vector2(940, 580))
	p.state = Enemies.ALIVE
	game.possess.mark(p)
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(60)
	await shot("4_memory")
	game.possess.t_left = 0.01
	await frames(20)
	game.dev_jump(Waves.BOSS)
	while game.boss.state != Testbed.RUN:
		await process_frame
	var bs = game.boss
	game.player.pos = Vector2(1100, 820)
	while not (bs.stage == Testbed.TEST and bs.stage_t > 1.6):
		await process_frame
	await shot("5_missiles")
	bs.tests_run = 1
	bs.missiles.clear()
	bs._announce()
	game.player.pos = Vector2(700, 800)
	# the fan sweeping onto the left crate stack, splashing on its face
	while not (bs.stage == Testbed.TEST and bs.flame_t > 1.95):
		await process_frame
	await shot("6_flames")
	bs.tests_run = 2
	bs._announce()
	game.player.pos = Vector2(1200, 760)
	while bs.rail_mode != 2:
		await process_frame
	await shot("7_rail")
	# the stamp coming down: the frame just after it lands
	while bs.stage != Testbed.PASS:
		await process_frame
	await frames(3)
	await shot("9_stamp")
	while bs.stage != Testbed.VENT:
		await process_frame
	await frames(30)
	game.player.pos = Vector2(960, 640)
	await frames(2)
	await shot("8_vent")
	# the full demonstration, in the last phase
	bs.phase = 2
	bs.tests_run = 3
	bs._announce()
	game.player.pos = Vector2(1240, 800)
	while not (bs.stage == Testbed.TEST and bs.stage_t > 1.2):
		await process_frame
	await shot("10_demo")
	quit()
