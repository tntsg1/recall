extends SceneTree
# Stills: the tooltip over a relic slot, and the build list on the pause screen.
# Usage: tools/run_test.sh tests/tip_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Meta.test_mode = true
	seed(3)
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 30:
		for k in 3:
			game.dev_action("relic", null)
		game.lv.split = 2
		game.lv.bounce = 1
	if frame >= 40 and frame < 140:
		var vp: Vector2 = root.get_visible_rect().size
		var slot: Vector2 = game.hud._relic_slot_i(1, vp)
		bot.aim = game.get_viewport().get_canvas_transform().affine_inverse() * slot
	match frame:
		100:
			Cap.save(root, "res://proofs/ui/t1_tip.png")
		140:
			game.paused = true
			game.hud.paused = true
			game.hud.pause_open()
		190:
			Cap.save(root, "res://proofs/ui/t2_build.png")
			return true
	return false
