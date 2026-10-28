extends SceneTree
# Stress: 600 rounds embedded around the room, then hold Q and recall them all.
# Real frame times (no fixed fps, vsync off). Prints avg / worst per phase.
# Usage: tools/run_test.sh tests/perf.gd

var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var times := {}
var phase := "warm"
var last := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	if "max" in OS.get_cmdline_user_args():
		game.lv = {"bounce": 3, "split": 3, "orbit": 3, "magnet": 0, "blast": 0, "charge": 0, "shadow": 0, "chain": 0}


func _process(_dt: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	if last > 0:
		if not times.has(phase):
			times[phase] = []
		times[phase].append((now - last) / 1000.0)
	last = now
	if frame == 30:
		phase = "spawn"
		for i in (24 if "max" in OS.get_cmdline_user_args() else 600):
			var o := Vector2(randf_range(200, 1700), randf_range(150, 950))
			if game.arena.is_free(o, 4.0):
				game.bullets.fire(o, Vector2.from_angle(randf() * TAU))
	if frame == 89:
		for a in OS.get_cmdline_user_args():
			if a == "faint": game.bullets.faint.visible = false
			if a == "glow": game.bullets.glow.visible = false
			if a == "mesh": game.bullets.mm_node.visible = false
			if a == "paths": game.bullets.paths.visible = false
			if a == "fx": game.fx.visible = false
			if a == "env": game.get_child(0).environment.glow_enabled = false
	if frame == 90:
		phase = "embedded"
	if frame == 150 or frame == 230:
		print("FPS ", phase, " ", Engine.get_frames_per_second())
		var vr := root.get_viewport_rid()
		print("RENDER cpu %.2f gpu %.2f frame-setup %.2f" % [RenderingServer.viewport_get_measured_render_time_cpu(vr) + RenderingServer.get_frame_setup_time_cpu(), RenderingServer.viewport_get_measured_render_time_gpu(vr), RenderingServer.get_frame_setup_time_cpu()])
		print(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " drawcalls ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " prims")
	if frame == 200:
		phase = "focus"
		bot.focus = true
	if frame == 250:
		phase = "recall"
		bot.focus = false
	if frame == 400:
		phase = "after"
	if frame >= 460:
		for k in ["spawn", "embedded", "focus", "recall", "after"]:
			var arr: Array = times.get(k, [])
			if arr.is_empty():
				continue
			var s := 0.0
			var w := 0.0
			for v in arr:
				s += v
				w = maxf(w, v)
			print("PERF %-9s avg %.2f ms (%.0f fps)  worst %.2f ms  n=%d" % [k, s / arr.size(), 1000.0 / (s / arr.size()), w, arr.size()])
		print("bullets alive ", game.bullets.list.size())
		return true
	return false
