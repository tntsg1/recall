extends SceneTree
# Stills of Continue: the chapter's opening alone, then the wave's title with
# "from the start of this wave" under it — never on top of each other.
# Usage: tools/run_test.sh tests/resume_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/ui"))
	Meta.test_mode = true
	Meta.resume = {"chapter": 0, "wave": 4, "gun": "standard", "stake": 0}
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_dt: float) -> bool:
	frame += 1
	if frame in [40, 100, 150, 190, 230]:
		Cap.save(root, "res://proofs/ui/resume_%d.png" % frame)
	return frame > 240
