extends SceneTree
# Stills of the "pixel invasion" seize style in the training yard:
# a chaser that has just drilled across the floor (infected trail healing),
# a guard mid-growth, a leech's well pulling a knot together.
# -> proofs/possess/invade_*.png   Usage: tools/run_test.sh tests/invade_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(1500, 540), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.pressed = true
	game._unhandled_input(ev)


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/possess/%s.png" % name)
	# and a 2x close-up around the shell
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://proofs/possess/%s.png" % name))
	var c: Vector2 = game.get_viewport().get_canvas_transform() * game.possess.shell.pos
	var r := Rect2i(int(clampf(c.x - 240, 0, 1920 - 480)), int(clampf(c.y - 135, 0, 1080 - 270)), 480, 270)
	var crop := img.get_region(r)
	crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://proofs/possess/%s_zoom.png" % name)


func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/possess"))
	Meta.possess_trial = true
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	await frames(60 * 5)
	game.player.pos = Vector2(560, 700)
	await frames(2)
	key(KEY_1)
	await frames(50)
	bot.aim = game.player.pos + Vector2(700, -260)
	bot.fire = true
	await frames(2)
	bot.fire = false
	await frames(16)
	bot.fire = true
	await frames(2)
	bot.fire = false
	await frames(8)
	await shot("invade_1_chaser_trail")
	key(KEY_3)
	await frames(12)
	game.paused = true
	game.possess.grow = 0.7
	game.possess.queue_redraw()
	await shot("invade_2_guard_growing")
	game.paused = false
	key(KEY_2)
	await frames(40)
	bot.aim = game.player.pos + Vector2(260, -40)
	bot.fire = true
	await frames(45)
	await shot("invade_3_leech_well")
	bot.fire = false
	quit(0)
