extends SceneTree
# Stills of chapter 7 (off-screen): the bureau at the opening, the rings lit
# and a line laid across them, every remnant awake, a seized pulse's memory,
# the synchroniser, and its 140 BPM. -> proofs/lore/ch7_*.png
# Usage: tools/run_test.sh tests/ch7_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(7)
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
	Cap.save(root, "res://proofs/lore/ch7_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 7:
		game.next_chapter()
	await frames(80)
	game.player.pos = Vector2(960, 860)
	await frames(10)
	await shot("1_open")
	while game.wave_ctl.phase != Waves.FIGHT:
		await process_frame
	game.dev_god = true
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var anchor = game.enemies.spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(1600, 60))
	anchor.state = Enemies.ALIVE
	anchor.hp = 1e9
	# after the wave card, wait for the left-hand pair to light, then fire a fan through it
	await frames(150)
	while not game.scan_rings.lit[0]:
		await process_frame
	game.player.pos = Vector2(820, 600)
	for k in 6:
		game.bullets.fire(game.player.pos, Vector2.from_angle(PI + (k - 2.5) * 0.08))
	await frames(9)
	await shot("2_rings")
	for w in Lore.walls(7):
		game.lore.hold["w7_%s" % w[0]] = 9.0
	await frames(40)
	await shot("3_remnants")
	game.player.pos = Vector2(820, 640)
	var p = game.enemies.spawn(Enemies.PULSE, Vector2(940, 640))
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
	while game.boss.state != Metronome.RUN:
		await process_frame
	var bs = game.boss
	game.player.pos = Vector2(960, 900)
	await frames(120)
	await shot("5_sync")
	for k in 2:
		bs.guard_t = 0.0
		bs.damage(bs.HP * 0.36 * Loadout.boss_hp(), false, bs.bob, Vector2.UP)
	await frames(300)
	await shot("6_140bpm")
	quit()
