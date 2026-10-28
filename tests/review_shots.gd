extends SceneTree
# Stills of real play for a reviewer: the bot plays the first waves and the
# frame is captured at a few moments (fight, recall, after a pick).
# Usage: tools/run_test.sh tests/review_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var brain
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var shots := 0
var recall_shot := false


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/review"))
	Meta.test_mode = true
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	brain = preload("res://tests/brain.gd").new(bot)


func _process(_dt: float) -> bool:
	frame += 1
	brain.think(game)
	if frame in [700, 1300, 2400, 3600]:
		Cap.save(root, "res://proofs/review/play_%d.png" % frame)
	# the moment a recall is in flight with several rounds coming home
	if not recall_shot and game.bullets.count_state(Bullets.RETURN) >= 6:
		recall_shot = true
		Cap.save(root, "res://proofs/review/play_recall.png")
	if game.picking and game.hud.cards_t > 0.8 and game.hud.cards_t < 0.85:
		Cap.save(root, "res://proofs/review/play_cards_%d.png" % frame)
	return frame > 3700
