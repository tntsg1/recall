extends SceneTree
# Stills of the lockdown (off-screen): its drop into the yard, a lamp locking
# on, the legs planted with a seized charger, the core open with the sockets lit.
# -> proofs/boss/lockdown_*.png
# Usage: tools/run_test.sh tests/lockdown_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(5)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/boss"))
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
	Cap.save(root, "res://proofs/boss/lockdown_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	game.dev_god = true
	game.dev_jump(Waves.BOSS)
	var L = game.boss
	while L.state != Lockdown.ENTER:
		await process_frame
	await frames(40)
	await shot("1_drop")
	while L.state != Lockdown.RUN:
		await process_frame
	game.player.pos = Vector2(820, 760)
	await frames(90)
	# stand in the left lamp's beam until it locks
	L.lamp_a[0] = (game.player.pos - L.lamp_pos(0)).angle()
	L.lamp_lock[0] = Lockdown.LOCK_TIME
	L.lamp_aim[0] = 0.0
	L.lamp_at[0] = game.player.pos
	await frames(24)
	await shot("2_lock")
	# phase 2: lamps out, legs planted, a charger seized near a leg
	L._hurt_lamp(0, 999.0, L.lamp_pos(0))
	L._hurt_lamp(1, 999.0, L.lamp_pos(1))
	await frames(50)
	var c = game.enemies.spawn(Enemies.CHARGER, Vector2(700, 520))
	c.state = Enemies.ALIVE
	game.possess.mark(c)
	game.player.pos = Vector2(760, 640)
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(40)
	L.waves.append([0.0, 0.3])
	await frames(14)
	await shot("3_legs")
	# phase 3: legs gone, core open, sockets lit, some rounds charged
	game.possess.t_left = 0.01
	await frames(10)
	for k in 4:
		L._hurt_leg(k, 999.0, L.leg_pos(k))
	await frames(70)
	game.player.pos = Vector2(960, 760)
	for k in 6:
		game.bullets.fire(game.player.pos, (Vector2(80, 540 + (k - 2.5) * 24.0) - game.player.pos).normalized())
	for k in 5:
		game.bullets.fire(game.player.pos, (Vector2(560 + (k - 2) * 26.0, 1010) - game.player.pos).normalized())
	L.arc_t = 1.5
	await frames(50)
	await shot("4_overload")
	quit()
