extends SceneTree
# N4 look-over (off-screen window): the neon palette and signs in a live fight,
# in chapters 1, 2, 4, and against the train. -> proofs/n4/*.png
# Usage: tools/run_test.sh tests/n4_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var brain
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	_run.call_deferred()


func play(n: int) -> void:
	for i in n:
		brain.think(game)
		await process_frame


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/n4/%s.png" % name)


func _run() -> void:
	Meta.test_mode = true
	seed(12)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/n4"))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	brain = preload("res://tests/brain.gd").new(bot)
	game.dev_god = true
	await play(60 * 9)
	await shot("1_chapter1")
	# hold a recall so the magenta lines show
	for i in 20:
		bot.focus = true
		await process_frame
	await shot("2_recall_preview")
	game.next_chapter()
	await play(60 * 9)
	await shot("3_chapter2")
	game.next_chapter()
	game.next_chapter()
	await play(60 * 9)
	await shot("4_chapter4")
	game.next_chapter()
	game.chapter = 0
	game.dev_action("boss", null)
	await play(60 * 10)
	await shot("5_boss")
	quit(0)
