extends SceneTree
# Stills of every ride between chapters (Transit), off-screen: the map, three
# moments of the ride, and the next chapter coming up after it. Checks that
# each ride starts, that nothing aboard can hurt you, and that it lands you in
# the next chapter with the room put back.
# Usage: tools/run_test.sh tests/transit_shots.gd --fixed-fps 60 [-- legs=1,7]

const Cap = preload("res://tests/cap.gd")
const DIR := "res://proofs/transit/%s.png"
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(1300, 540), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []
var legs: Array = []
var li := 0
var f := 0           # frames into this leg
var cracks0 := 0
var us := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/transit"))
	seed(11)
	Txt.zh = true
	Transit.force = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("legs="):
			for s in a.substr(5).split(","):
				legs.append(int(s))
	if legs.is_empty():
		legs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
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
	if f < 30:
		return false
	if li >= legs.size():
		print("TRANSIT SHOTS " + ("PASS" if fails.is_empty() else "FAIL (%d)" % fails.size()))
		return true
	var leg: int = legs[li]
	var tr: Transit = game.transit
	match f:
		30:
			while Chapters.story(game.chapter) < leg:
				game.next_chapter()
			# as after the chapter's boss, its pick already taken
			game.wave_ctl.phase = Waves.CLEAR
			game.wave_ctl.index = Waves.COUNT - 1
			game.wave_ctl.pick_state = 2
			game.picking = false
			game.hud.cards_t = -1.0
			cracks0 = game.cracks
			check(tr.take(game.chapter), "第 %d 段开始" % leg)
		90:
			Cap.save(root, DIR % ("%02d_map" % leg))
		150:
			check(tr.state == Transit.RIDE, "第 %d 段地图后进入乘坐" % leg)
			tr.t = 3.0
			tr.u = 0.18
		190:
			Cap.save(root, DIR % ("%02d_ride_a" % leg))
			tr.t = 10.4
			tr.u = 0.5
		220:
			us = Time.get_ticks_usec()
		259:
			print("  ride frame %.2f ms, scenery draw %.2f ms, %d objects (leg %d)" % [(Time.get_ticks_usec() - us) / 39000.0, tr.scenery.draw_us / 1000.0, tr.scenery.objs.size(), leg])
		260:
			Cap.save(root, DIR % ("%02d_ride_b" % leg))
			check(game.enemies.remaining() > 0, "第 %d 段有敌人爬上平台" % leg)
			tr.t = 14.0
			tr.u = 0.86
		292:
			Cap.save(root, DIR % ("%02d_ride_c" % leg))
			check(game.cracks == cracks0, "第 %d 段乘坐时不受伤" % leg)
			tr._arrive()
		360:
			check(tr.state == Transit.OFF, "第 %d 段到站" % leg)
			check(Chapters.story(game.chapter) == leg + 1, "第 %d 段到站后是第 %d 章" % [leg, leg + 1])
			check(not game.arena.open and game.floor_rect.visible, "第 %d 段到站后房间恢复" % leg)
			Cap.save(root, DIR % ("%02d_arrive" % leg))
			li += 1
			f = 29
	return false
