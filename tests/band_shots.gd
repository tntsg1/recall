extends SceneTree
# The band under the arena with a full build: hints, cracks, ammo, five relics
# and four schools in one row.
# Usage: tools/run_test.sh tests/band_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(1200, 700), "fire": false, "focus": false, "dash": false}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/ui"))
	Meta.test_mode = true
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 40:
		game.lv.split = 2
		game.lv.bounce = 1
		game.lv.orbit = 3
		game.lv.possess = 1
		for r in ["whet", "quick", "deepmag", "longfuse", "lightstep"]:
			game.relics.append(r)
	if frame == 220:
		Cap.save(root, "res://proofs/ui/band_full.png")
		return true
	return false
