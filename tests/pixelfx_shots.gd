extends SceneTree
# Stills of the pixel effects and the Motion Prompt moves (off-screen): the
# chapter title breaking up and its line decoding, the rooms' screens, a seize,
# a boss's end, an achievement going off, the iris on a death, the title's
# light sweep. Prints ok / FAIL lines as it goes.
# Usage: tools/run_test.sh tests/pixelfx_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const DIR := "res://proofs/pixelfx/%s.png"
var game
var title
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []
var seized := -1     # the frame the seize happened on
var stage := 0       # 0 waiting for a shell, 1 seized, 2 the rest


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/pixelfx"))
	seed(5)
	Txt.zh = true
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game


func check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _process(_dt: float) -> bool:
	frame += 1
	if frame >= 70 and stage == 0:
		# wait for the wave's first shell, then seize it
		for x in game.enemies.list:
			if x.state == Enemies.ALIVE:
				game.possess.seize_now(x)
				seized = frame
				stage = 1
				break
		if stage == 0 and frame > 600:
			check(false, "有敌人可以夺壳")
			stage = 2
		return false
	if stage == 1:
		if frame == seized + 16:
			check(game.fx.pixels.size() > 0, "夺壳时放出像素收缩环")
			Cap.save(root, DIR % "4_seize")
			game.possess._restore(game.player.pos)
			stage = 2
			frame = 150
		return false
	match frame:
		40:
			check(Demo.extras(), "正式版打开新效果")
			game.hud.intro_t = 0.62
		41:
			check(Picks.glitch_step(game.hud.intro_t) >= 0, "章节标题在故障闪烁那几步里")
			Cap.save(root, DIR % "1_intro_glitch")
		60:
			game.hud.intro_t = 1.05
		61:
			Cap.save(root, DIR % "2_intro_scramble")
		160:
			# as on_boss_dead and a boss car's burst throw them
			game.fx.pixel("implosion", Vector2(700, 560), 3.0, 1.3)
			game.fx.pixel("implosion", Vector2(1300, 420), 2.0, 1.1)
		182:
			Cap.save(root, DIR % "5_boss_end")
		200:
			game.hud.flash_text("获得成就 · 测试", null, true)
		209:
			Cap.save(root, DIR % "6_ach_burst")
		230:
			game.hud.game_over()
		280:
			Cap.save(root, DIR % "7_iris")
		330:
			Cap.save(root, DIR % "8_iris_summary")
			game.hud.over_t = -1.0
			game.next_chapter()
		420:
			Cap.save(root, DIR % "3_hall_kiosks")
			game.queue_free()
			title = load("res://scenes/title.tscn").instantiate()
			root.add_child(title)
			current_scene = title
		600:
			title.sweep_from = title.t - 0.95
		601:
			Cap.save(root, DIR % "9_title_sweep")
			print("PIXELFX SHOTS " + ("PASS" if fails.is_empty() else "FAIL (%d)" % fails.size()))
			return true
	return false
