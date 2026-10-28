extends SceneTree
# Stills of the in-run HUD motion (off-screen): chapter/wave titles letter by
# letter, the grade stamp with its ink, a crack breaking and mending, the boss
# bar opening and losing a piece, and the pause menu leaving.
# Usage: tools/run_test.sh tests/hud_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(1200, 700), "fire": false, "focus": false, "dash": false}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/ui"))
	Meta.dev_unlock = true
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _shot(n: String) -> void:
	Cap.save(root, "res://proofs/ui/%s.png" % n)


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		20, 34, 150:
			_shot("h_intro_%d" % frame)
		200:
			game.hud.title_t = -1.0   # in play the stamp never shares the screen with a title
			game.hud.stamp(0, 23.4, "S")
		213:
			_shot("h_stamp")
		240:
			game.cracks -= 1
			game.hud.crack_break(game.cracks)
		246:
			_shot("h_crack_break")
		280:
			game.cracks = game.max_cracks
			game.hud.crack_mend(game.cracks)
		292:
			_shot("h_crack_mend")
		320:
			game.dev = true
			game.dev_jump(Waves.BOSS)
		360:
			_shot("h_boss_bar")
		460:
			game.hud.boss_phase()
		466:
			_shot("h_boss_phase")
		500:
			game.paused = true
			game.hud.paused = true
			game.hud.pause_open()
		540:
			game.paused = false
			game.hud.paused = false
		545:
			_shot("h_pause_leave")
			return true
	return false
