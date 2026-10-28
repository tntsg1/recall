extends SceneTree
# Stills of the recall cinematic (off-screen): the bot plays until it recalls a
# handful of rounds, then three frames are saved as the moment unfolds.
# Usage: tools/run_test.sh tests/cine_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var brain
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var frame := 0
var at := -1


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Meta.test_mode = true
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game
	brain = preload("res://tests/brain.gd").new(bot)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 5:
		game.dev_god = true
		game.hud.hint_a = 0.0
	brain.think(game)
	if at < 0 and game.cine_t >= 0.0 and game.cine_k > 0.5:
		at = frame
	if at > 0:
		match frame - at:
			4:
				Cap.save(root, "res://proofs/ui/c1_recall.png")
			10:
				Cap.save(root, "res://proofs/ui/c2_recall.png")
			18:
				Cap.save(root, "res://proofs/ui/c3_recall.png")
				return true
	return frame > 60 * 120
