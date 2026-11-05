extends SceneTree
# The rooms' screens playing their pixel loops (off-screen): walks the rooms of
# chapters 1, 2 and 7 until it finds a wall screen, a kiosk, a terminal and a
# monitor, and takes each one's still.
# Usage: tools/run_test.sh tests/screen_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var want := {"screen": false, "kiosk": false, "terminal": false, "monitor": false}
var wave := 0
var wait := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/pixelfx"))
	seed(3)
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 30:
		return false
	wait += 1
	if wait < 40:
		return false
	wait = 0
	var lay: Dictionary = game.rooms.lay
	var found := []
	for k in ["screen", "terminal", "monitor"]:
		if not want[k] and lay.get("spots", {}).has(k):
			found.append(k)
	if not want.kiosk and Array(lay.get("kinds", [])).has("kiosk"):
		found.append("kiosk")
	for k in found:
		want[k] = true
		Cap.save(root, "res://proofs/pixelfx/screen_%s.png" % k)
		print("  ok  ", k, " · chapter ", game.chapter + 1, " wave ", wave + 1)
	wave += 1
	if wave > 5:
		wave = 0
		if game.chapter == 1:
			for i in 5:
				game.next_chapter()   # on to the seventh
		else:
			game.next_chapter()
	if game.chapter > 6 or not want.values().has(false):
		print("SCREEN SHOTS ", want)
		return true
	game.dev_jump(wave)
	return false
