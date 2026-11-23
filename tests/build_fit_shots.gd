extends SceneTree
# The pause screen's build column with a full build (five schools, five relics)
# must stay clear of the slot bar, in both languages.
# Usage: tools/run_test.sh tests/build_fit_shots.gd --fixed-fps 60

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
		for k in 5:
			game.dev_action("relic", null)
		game.lv.bounce = 3
		game.lv.split = 3
		game.lv.chain = 3
		game.lv.possess = 2
		game.lv.walk = 1
	match frame:
		60:
			game.paused = true
			game.hud.paused = true
			game.hud.pause_open()
		110:
			Cap.save(root, "res://proofs/ui/build_fit_zh.png")
			Txt.zh = false
		130:
			Cap.save(root, "res://proofs/ui/build_fit_en.png")
			Txt.zh = true
			print("build fit shots ok")
			return true
	return false
