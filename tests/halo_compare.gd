extends SceneTree
# Before/after of the player's halo and floor shadow, in a busy chapter-12 room.
# Usage: tools/run_test.sh tests/halo_compare.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}

func _initialize() -> void:
	Meta.test_mode = true
	seed(4)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/halo"))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 7:
		game.next_chapter()
	game.dev_god = true
	await frames(240)
	game.player.pos = Vector2(1000, 640)
	for k in 2:
		Player.halo = k == 1
		await frames(3)
		await RenderingServer.frame_post_draw
		Cap.save(root, "res://proofs/halo/%s.png" % ("after" if k == 1 else "before"))
	quit()
