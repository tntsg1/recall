extends SceneTree
# Stills of the passcode pad and the developer panel (off-screen).
# Usage: tools/run_test.sh tests/dev_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Meta.test_mode = true
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		60:
			game._ask_dev_code()
		80:
			game.get_node("DevPrompt")._pad("1")
			game.get_node("DevPrompt")._pad("1")
		100:
			Cap.save(root, "res://proofs/ui/d1_pad.png")
			game.get_node("DevPrompt")._pad("1")
			game.get_node("DevPrompt")._pad("OK")
		170:
			Cap.save(root, "res://proofs/ui/d2_panel.png")
			return true
	return false
