extends SceneTree
# Headless: the four music loops share one length, and their volumes follow
# the fight (pulse in a wave, boss layer at the boss, base only at the end).

var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var fails := 0


func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_dt: float) -> bool:
	frame += 1
	var s = game.sfx
	match frame:
		5:
			var lens := []
			for k in s.layers:
				lens.append(snappedf(s.layers[k].stream.get_length(), 0.001))
			_ok(s.layers.size() == 4, "four layers loaded")
			_ok(lens.min() == lens.max(), "all loops the same length %s" % str(lens))
		400:
			_ok(game.wave_ctl.phase == Waves.FIGHT and s.level.pulse > 0.7 and s.level.boss < 0.1, "a wave brings in the pulse (%.2f)" % s.level.pulse)
			game.dev_jump(Waves.BOSS)
		900:
			_ok(s.level.boss > 0.7, "the train brings in its layer (%.2f)" % s.level.boss)
			game.lost = true
		1300:
			_ok(s.level.pulse < 0.1 and s.level.base > 0.5, "after the run only the base remains")
			print("MUSIC CHECK ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
			return true
	return false
