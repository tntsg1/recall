extends SceneTree
# Stills of chapter 2's world (off-screen): the hall at the chapter's opening,
# every remnant awake, a seized prism's memory, the warden arriving.
# -> proofs/lore/ch2_*.png
# Usage: tools/run_test.sh tests/ch2_lore_shots.gd --fixed-fps 60

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
	Cap.save(root, "res://proofs/lore/ch2_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	game.next_chapter()
	await frames(100)
	await shot("1_open")
	while game.wave_ctl.phase != Waves.FIGHT:
		await process_frame
	for w in Lore.walls(2):
		game.lore.hold["w2_%s" % w[0]] = 9.0
	await frames(40)
	await shot("2_remnants")
	game.dev_god = true
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var anchor = game.enemies.spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60))
	anchor.state = Enemies.ALIVE
	anchor.hp = 1e9
	game.player.pos = Vector2(820, 640)
	var p = game.enemies.spawn(Enemies.PRISM, Vector2(940, 600))
	p.state = Enemies.ALIVE
	p.speed = 0.0
	game.possess.mark(p)
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(60)
	await shot("3_memory")
	game.possess.t_left = 0.01
	await frames(20)
	game.dev_jump(Waves.BOSS)
	while game.boss.state != Warden.RUN:
		await process_frame
	await frames(30)
	await shot("4_warden")
	quit()
