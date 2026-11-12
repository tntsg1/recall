extends SceneTree
# Headless: the ride comes on by itself after a chapter's boss (through Waves),
# lands in the next chapter, and a ride already seen can be skipped by
# holding Tab. Prints ok / FAIL lines and TRANSIT CHECK PASS / FAIL.
# Usage: godot --headless --path . -s tests/transit_check.gd --fixed-fps 60

var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(1300, 540), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []
var frame := 0
var stage := 0
var started := 0


func _initialize() -> void:
	Transit.force = true
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game


func check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


# As the boss wave ends: cleared, its pick taken.
func _end_chapter() -> void:
	var w: Waves = game.wave_ctl
	w.index = Waves.BOSS
	w.phase = Waves.CLEAR
	w.pick_state = 2
	w.pick_done_t = 0.0
	w.t = 3.0
	game.picking = false


func _process(_dt: float) -> bool:
	frame += 1
	var tr: Transit = game.transit
	match stage:
		0:
			if frame == 30:
				_end_chapter()
			elif frame == 32:
				check(tr.state == Transit.MAP, "第一章打完自动出地图")
				check(not tr.seen, "第一次没看过，不能跳过")
				stage = 1
				started = frame
		1:
			if tr.state == Transit.OFF:
				var secs := (frame - started) / 60.0
				check(Chapters.story(game.chapter) == 2, "乘坐后到第二章")
				check(secs >= Transit.RIDE_MIN and secs <= Transit.RIDE_MAX + 4.0, "整段 %.1f 秒（地图 + 乘坐 + 转黑）" % secs)
				check(game.wave_ctl.phase == Waves.INTRO, "第二章从开场开始")
				# the ride counts as seen now (the test keeps it in memory only)
				Meta.load_data()["rides"] = {"1": true, "2": true}
				_end_chapter()
				stage = 2
				started = frame
			elif frame - started > 60 * 40:
				check(false, "乘坐段 40 秒内结束")
				stage = 9
		2:
			if tr.state == Transit.RIDE and frame - started > 150:
				check(tr.seen, "看过的段可以跳过")
				Input.action_press("skip_ride")
				stage = 3
				started = frame
		3:
			if tr.state != Transit.RIDE:
				Input.action_release("skip_ride")
				check(frame - started <= 50, "按住 Tab 不到一秒就跳过（%d 帧）" % (frame - started))
				stage = 4
			elif frame - started > 120:
				Input.action_release("skip_ride")
				check(false, "按住 Tab 能跳过")
				stage = 9
		4:
			if tr.state == Transit.OFF:
				check(Chapters.story(game.chapter) == 3, "跳过后到第三章")
				stage = 9
		9:
			print("TRANSIT CHECK " + ("PASS" if fails.is_empty() else "FAIL (%d)" % fails.size()))
			return true
	return false
