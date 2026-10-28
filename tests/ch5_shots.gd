extends SceneTree
# Stills of chapter 5 (off-screen): the line at the opening, a powered rail
# turning a shot, every remnant awake, a seized charger's memory, the central
# express passing the platform. -> proofs/lore/ch5_*.png
# Usage: tools/run_test.sh tests/ch5_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(5)
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
	Cap.save(root, "res://proofs/lore/ch5_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 5:
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
	# the middle rail powered: shots fired up across it turn along it
	game.maglev.t = 0.5
	game.player.pos = Vector2(820, 700)
	await frames(10)
	for k in 5:
		game.bullets.fire(game.player.pos, Vector2.from_angle(-PI / 2.0 + (k - 2) * 0.25))
		await frames(4)
	await frames(12)
	await shot("2_rail_bend")
	for w in Lore.walls(5):
		game.lore.hold["w5_%s" % w[0]] = 9.0
	await frames(40)
	await shot("3_remnants")
	game.player.pos = Vector2(560, 440)
	var p = game.enemies.spawn(Enemies.CHARGER, Vector2(680, 440))
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
	while game.boss.state != Boss.RUN:
		await process_frame
	game.player.pos = Vector2(960, 700)
	# wait for the engine to pass the platform
	var bs = game.boss
	# the moment it tears past the platform
	while not (bs.station_t > 0.12 and bs.station_t < 0.3):
		await process_frame
	await shot("5_express")
	await frames(120)
	await shot("6_express_rails")
	quit()
