extends SceneTree
# Stills of the band while seizing (off-screen): the E key cooling and ready,
# the band turned into the shell's status, a hit taken, the last seconds.
# -> proofs/possess/band_*.png
# Usage: tools/run_test.sh tests/host_hud_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(1300, 540), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(4)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/possess"))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/possess/%s.png" % name)
	print(name, " saved")


func spawn(kind: int, at: Vector2, still := true):
	var e = game.enemies.spawn(kind, at)
	e.state = Enemies.ALIVE
	e.t = 0.0
	if still:
		e.speed = 0.0
	return e


func clear() -> void:
	game.wave_ctl.queue.clear()
	var anchor = spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60))
	anchor.hp = 1e9
	anchor.maxhp = 1e9
	for e in game.enemies.list:
		if e != anchor and e.state != Enemies.HOST:
			e.state = Enemies.DEAD
	await frames(2)


func _run() -> void:
	var n := 0
	while game.wave_ctl.phase != Waves.FIGHT and n < 600:
		await process_frame
		n += 1
	game.dev_god = true
	game.dev_ammo = true
	await clear()
	var p: Player = game.player
	p.pos = Vector2(800, 600)
	game.possess.cooldown = 3.5
	var m = spawn(Enemies.CHASER, Vector2(1000, 560))
	game.possess.mark(m)
	await frames(10)
	await shot("band_1_cooling")
	game.possess.cooldown = 0.0
	await frames(12)
	await shot("band_2_ready_ping")
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(40)
	await shot("band_3_host")
	game.dev_god = false
	game.possess.iframes = 0.0
	game.possess.shell_hit(Vector2.RIGHT)
	game.dev_god = true
	await frames(8)
	await shot("band_4_hit")
	game.possess.t_left = 1.2
	await frames(3)
	await shot("band_5_last_seconds")
	quit()
