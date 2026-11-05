extends SceneTree
# The demo (off-screen): the title with its DEMO sign and wishlist row, three
# chapters to a run, no achievements, and the end page with its wishlist line,
# in both languages. Prints ok / FAIL lines as it goes.
# Usage: tools/run_test.sh tests/demo_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const DIR := "res://proofs/demo/%s.png"
var frame := 0
var title
var game
var fails: Array[String] = []


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/demo"))
	Demo.forced = true
	Meta.test_mode = true
	Meta.load_data()
	Txt.zh = true
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title


func check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		260:
			var m: Array = title._menu()
			check(m.has("wishlist") and not m.has("achievements"), "试玩版菜单：成就换成加入心愿单")
			check(Chapters.count() == 3, "试玩版一局 3 章")
			check(Meta.DEMO_PATH != Meta.PATH, "试玩版存档单独一个文件")
			check(not Demo.extras(), "试玩版不放像素特效和新动效")
			title.sel["menu"] = m.find("wishlist")
			title._move(0)
		300:
			Cap.save(root, DIR % "1_title_zh")
			Txt.zh = false
		340:
			Cap.save(root, DIR % "2_title_en")
			Txt.zh = true
			title.queue_free()
			game = load("res://scenes/main.tscn").instantiate()
			game.bot = {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
			root.add_child(game)
			current_scene = game
		420:
			game.bot = null
			game.ach("kills_300")
			check(game.run_ach.is_empty(), "试玩版不发成就")
			game.fx.pixel("implosion", Vector2(960, 540))
			check(game.fx.pixels.is_empty(), "试玩版不放像素爆炸")
			var rows := []
			for i in 3:
				rows.append([Chapters.label(i) + " · " + Chapters.title(i), 300.0, "S2 A3 B1"])
			game.hud.final(rows)
		640:
			check(game.hud.wish_at != Vector2.INF and game.hud.wishlist_hit(game.hud.wish_at + Vector2(0, -8)), "结束页有可点的加入心愿单")
			Cap.save(root, DIR % "3_end_zh")
			Txt.zh = false
		680:
			Cap.save(root, DIR % "4_end_en")
			Txt.zh = true
			print("DEMO SHOTS " + ("PASS" if fails.is_empty() else "FAIL (%d)" % fails.size()))
			return true
	return false
