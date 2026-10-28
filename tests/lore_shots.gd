extends SceneTree
# Stills of chapter 1's world (off-screen): the worker by the door as the yard
# wakes, remnants surfacing on the walls, a seized chaser's memory, the city
# broadcast, the death line, and the title's archive page.
# -> proofs/lore/*.png
# Usage: tools/run_test.sh tests/lore_shots.gd --fixed-fps 60

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
	Cap.save(root, "res://proofs/lore/%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(100)
	await shot("1_worker")
	# every remnant on the walls at once, as if recalls had swept them
	while game.wave_ctl.phase != Waves.FIGHT:
		await process_frame
	for w in Lore.walls(1):
		var id := "w1_%s" % w[0]
		game.lore.hold[id] = 9.0
	await frames(30)
	await shot("2_remnants")
	# a chaser seized: its memory
	game.dev_god = true
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var anchor = game.enemies.spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60))
	anchor.state = Enemies.ALIVE
	anchor.hp = 1e9
	game.player.pos = Vector2(760, 640)
	var c = game.enemies.spawn(Enemies.CHASER, Vector2(880, 600))
	c.state = Enemies.ALIVE
	c.speed = 0.0
	game.possess.mark(c)
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(70)
	await shot("3_memory")
	game.possess.t_left = 0.01
	await frames(20)
	game.hud.radio(Lore.radio_line(1, "wave", 0).text)
	await frames(200)
	await shot("4_radio")
	game.hud.game_over()
	await frames(150)
	await shot("5_death")
	quit()
