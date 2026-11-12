extends SceneTree
# Stills of the megastructure under the rooms (full game): each chapter's
# first room (floor grates) and its second (grates and, where an outer wall
# has no door, a window), then the title with the city drifting behind it.
# Usage: tools/run_test.sh tests/vista_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const DIR := "res://proofs/vista/%s.png"
const STORIES := [1, 2, 4, 5, 7, 8, 9, 10, 12]
var game
var title
var bot := {"move": Vector2.ZERO, "aim": Vector2(1300, 540), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []
var si := 0
var f := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/vista"))
	seed(3)
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
	f += 1
	if f < 40:
		return false
	if si < STORIES.size():
		var st: int = STORIES[si]
		match f:
			40:
				while Chapters.story(game.chapter) < st:
					game.next_chapter()
				game.hud.intro_t = -1.0
				check(game.vista != null and game.vista.visible, "第 %d 章有脚下的巨构" % st)
			70:
				check(not game.arena.grates.is_empty() or not game.rooms.active, "第 %d 章第一个房间有格栅" % st)
				Cap.save(root, DIR % ("%02d_room0" % st))
				if game.rooms.active:
					game.rooms.build(1, "L", false)
			100:
				Cap.save(root, DIR % ("%02d_room1%s" % [st, ("G" if game.arena.glass.size.x > 0.0 else "")]))
				si += 1
				f = 39
		return false
	match f:
		40:
			game.queue_free()
			title = load("res://scenes/title.tscn").instantiate()
			root.add_child(title)
			current_scene = title
		260:
			Cap.save(root, DIR % "title")
			print("VISTA SHOTS " + ("PASS" if fails.is_empty() else "FAIL (%d)" % fails.size()))
			return true
	return false
