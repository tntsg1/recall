extends SceneTree
# Still: the title with a run waiting (Continue leads the menu). Off-screen.
const Cap = preload("res://tests/cap.gd")
var title
var frame := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Meta.test_mode = true
	Meta.load_data()
	Meta.data.run = {"chapter": 2, "wave": 3, "gun": "standard", "stake": 0}
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 260:
		Cap.save(root, "res://proofs/ui/k1_continue.png")
		return true
	return false
