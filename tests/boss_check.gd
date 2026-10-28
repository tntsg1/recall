extends SceneTree
# Headless: jump straight to the train, let the bot fight it, print the result.
# Usage: godot --headless --path . -s tests/boss_check.gd --fixed-fps 60 -- [runs] [max]

var game
var brain
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var frame := 0
var runs := 1
var run := 0
var maxed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	maxed = "max" in args
	_start()


func _start() -> void:
	if game:
		game.queue_free()
	seed(300 + run)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	brain = preload("res://tests/brain.gd").new(bot)
	frame = 0
	await process_frame
	if "ch2" in OS.get_cmdline_user_args():
		game.next_chapter()
	if "ch3" in OS.get_cmdline_user_args():
		game.next_chapter()
		game.next_chapter()
	if "ch5" in OS.get_cmdline_user_args():
		for i in 4:
			game.next_chapter()
	if "ch4" in OS.get_cmdline_user_args():
		for i in 3:
			game.next_chapter()
	game.wave_ctl.index = Waves.BOSS - 1
	game.wave_ctl.phase = Waves.CLEAR
	game.wave_ctl.pick_state = 2
	game.wave_ctl.t = 10.0
	game.lv = {"bounce": 3, "split": 3, "orbit": 3, "magnet": 0, "blast": 0, "charge": 0, "shadow": 0, "chain": 0} if maxed else {"bounce": 1, "split": 2, "orbit": 2, "magnet": 0, "blast": 0, "charge": 0, "shadow": 0, "chain": 0}


func _process(_dt: float) -> bool:
	frame += 1
	if game == null or not game.is_inside_tree():
		return false
	brain.think(game)
	var w = game.wave_ctl
	if frame % 600 == 0:
		print("  t %.0fs hp %.0f phase %d state %d core %.2f bullets %d" % [frame / 60.0, game.boss.hp, game.boss.phase, game.boss.state, game.boss.core_open, game.bullets.list.size()])
	if w.results.size() > 0 or frame > 60 * 240:
		var r = w.results[0] if w.results.size() > 0 else ["timeout", "-"]
		print("BOSS run %d: %s %s hits %d" % [run, str(r[0]), r[1], game.hits_taken])
		run += 1
		if run >= runs:
			return true
		_start()
	return false
