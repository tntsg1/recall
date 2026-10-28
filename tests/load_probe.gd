extends SceneTree
# Title -> run: let the title warm up for a few seconds (as a player would see it),
# then switch exactly as Start does, and time instantiate, _ready and the first
# frames of the run, vsync off.
# Usage: tools/run_test.sh tests/load_probe.gd [-- cold]

var frames: Array = []
var title_frames: Array = []
var last := 0
var n := 0
var game
var title
var cold := false


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Meta.test_mode = true
	cold = "cold" in OS.get_cmdline_user_args()
	if not cold:
		title = load("res://scenes/title.tscn").instantiate()
		root.add_child(title)


func _process(_dt: float) -> bool:
	n += 1
	var now := Time.get_ticks_usec()
	if n > 5 and n < 300 and last > 0:
		title_frames.append((now - last) / 1000.0)
		if (now - last) / 1000.0 > 25.0:
			print("TITLE slow frame %d: %.1f ms" % [n, (now - last) / 1000.0])
	if n == 300:
		if title:
			title.queue_free()
		var a := Time.get_ticks_usec()
		var packed: PackedScene = load("res://scenes/main.tscn")
		var b := Time.get_ticks_usec()
		game = packed.instantiate()
		var c := Time.get_ticks_usec()
		root.add_child(game)
		var d := Time.get_ticks_usec()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("hide="):
				var what := arg.substr(5)
				var node = game.get(what)
				if node is CanvasItem or node is CanvasLayer:
					node.visible = false
				elif what == "env":
					for ch in game.get_children():
						if ch is WorldEnvironment:
							ch.environment.glow_enabled = false
				print("HIDE ", what)
		var tw := 0.0
		for v in title_frames:
			tw = maxf(tw, v)
		print("TITLE worst %.1f ms (warm-up running)  warm done=%s" % [tw, str(Warm.done)])
		print("LOAD load %.1f ms  instantiate %.1f ms  ready %.1f ms" % [(b - a) / 1000.0, (c - b) / 1000.0, (d - c) / 1000.0])
		last = Time.get_ticks_usec()
		return false
	if n > 300 and n <= 315:
		frames.append((now - last) / 1000.0)
		if n <= 304:
			print("F%d total %.1f  process %.1f  physics %.1f  nav %.1f" % [n - 300, (now - last) / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0])
	last = now
	if n == 316:
		print("FIRST FRAMES ", frames)
		return true
	return false
