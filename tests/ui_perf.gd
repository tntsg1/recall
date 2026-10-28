extends SceneTree
# Frame times while the UI animates (vsync off, real time): the title paging
# back and forth, then a run with cards and the pause menu open and closing.
# Usage: tools/run_test.sh tests/ui_perf.gd

var frame := 0
var title
var game
var times := {}
var phase := "title"
var last := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/ui"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Meta.test_mode = true   # tests never write the player's save
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title


func _process(_dt: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	if last > 0 and frame > 20:
		if not times.has(phase):
			times[phase] = []
		times[phase].append((now - last) / 1000.0)
	last = now
	var t := frame
	if phase == "title":
		if t > 300 and t % 30 == 0:
			if title.page == "menu":
				title._go(["settings", "achievements"][(t / 30) % 2])
			else:
				title._go("menu")
		if t % 7 == 0:
			title._move(1)
		if t == 900:
			title.page = "menu"
			title.sel["menu"] = 0
			title.gun_i = 0
			title._accept(0)
			phase = "transition"
	elif phase == "transition" and current_scene is Game:
		game = current_scene
		game.bot = {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
		phase = "run"
	elif phase == "run":
		var k := t % 120
		if k == 0:
			game.picking = true
			game.offers = [{"type": "school", "id": "split", "level": 0}, {"type": "relic", "id": "zeroblade"}, {"type": "item", "id": "overload"}]
			game.hud.show_cards(game.offers)
		elif k == 60:
			game.choose(0)
			game.replacing = {}
		elif k == 80:
			game.paused = true
			game.hud.paused = true
			game.hud.pause_open()
		elif k == 110:
			game.paused = false
			game.hud.paused = false
		if t > 2100:
			for p in times:
				var arr: Array = times[p]
				var s := 0.0
				var w := 0.0
				var over := 0
				for v in arr:
					s += v
					w = maxf(w, v)
					if v > 16.7:
						over += 1
				print("UIPERF %-10s avg %.2f ms (%.0f fps)  worst %.2f ms  frames>16.7ms %d/%d" % [p, s / arr.size(), 1000.0 / (s / arr.size()), w, over, arr.size()])
			return true
	return false
