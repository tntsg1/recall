extends SceneTree
# Still of the 训练场 with its key panel, seized as a charger mid wind-up.
# Usage: tools/run_test.sh tests/yard_shots.gd --fixed-fps 60  -> proofs/possess/yard.png

const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/possess"))
	Meta.possess_trial = true
	var bot := {"move": Vector2.ZERO, "aim": Vector2(1500, 300), "fire": false, "focus": false, "dash": false, "possess": false}
	var game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	game.trial = true
	root.add_child(game)
	for i in 60 * 5:
		await process_frame
	for k in [KEY_L, KEY_L, KEY_L, KEY_Y, KEY_4, KEY_M]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.pressed = true
		game._unhandled_input(ev)
	for i in 40:
		await process_frame
	bot.fire = true
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/possess/yard.png")
	print("yard saved")
	quit(0)
