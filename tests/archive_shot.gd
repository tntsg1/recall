extends SceneTree
# Still: the title's archive page with part of chapter 1 found. Off-screen.
# Usage: tools/run_test.sh tests/archive_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var title
var frame := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Meta.test_mode = true
	var d := Meta.load_data()
	d.lore = {"s1_0_0": true, "w1_door": true, "w1_screen": true, "r1_wave_0": true, "s1_1_0": true}
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 300:
		title._go("archive")
	if frame == 360:
		Cap.save(root, "res://proofs/lore/6_archive.png")
		return true
	return false
