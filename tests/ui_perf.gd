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
var frame_base := 0
var run_base := 0
var out: Array = []        # spike lines, printed at the end (printing is slow)
var stamps: Array = []
var proc_a := 0     # all nodes' _process runs between these two
var proc_b := 0


class Probe extends Node:
	var cb: Callable
	func _process(_dt: float) -> void:
		cb.call()


func _watch(n: Node) -> void:
	if n is CanvasItem and not n.has_meta("perf_watch"):
		n.set_meta("perf_watch", true)
		var par := n.get_parent()
		var nm := String(n.name) if n.get_script() == null else "%s(%s)" % [n.name, (n.get_script() as Script).resource_path.get_file()]
		if par != null and par.get_script() != null:
			nm += "<" + (par.get_script() as Script).resource_path.get_file()
		# the stamp must fire before the node's own draw handlers, so take
		# them off and put them back after it
		var own := n.get_signal_connection_list("draw")
		for c in own:
			n.draw.disconnect(c.callable)
		n.draw.connect(func(): stamps.append([nm, Time.get_ticks_usec()]))
		for c in own:
			n.draw.connect(c.callable, c.flags)
	for c in n.get_children():
		_watch(c)
var pre_at := 0      # when this frame's rendering began / ended
var post_at := 0
var prev_last := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/ui"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	RenderingServer.frame_pre_draw.connect(func(): pre_at = Time.get_ticks_usec())
	var pa := Probe.new()
	pa.process_priority = -100000
	pa.cb = func(): proc_a = Time.get_ticks_usec()
	root.add_child.call_deferred(pa)
	var pb := Probe.new()
	pb.process_priority = 100000
	pb.cb = func(): proc_b = Time.get_ticks_usec()
	root.add_child.call_deferred(pb)
	RenderingServer.frame_post_draw.connect(func(): post_at = Time.get_ticks_usec())
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
		if (now - last) / 1000.0 > 7.0 and "spikes" in OS.get_cmdline_user_args():
			var vp := root.get_viewport_rid()
			out.append(str("SPIKE %s frame %d (t%%120=%d, t%%30=%d, t%%7=%d): %.1f ms  logic+draw %.1f  render %.1f  after %.1f  gpu-cpu %.1f gpu %.1f  objs %d" % [phase, frame, frame % 120, frame % 30, frame % 7, (now - last) / 1000.0,
				(pre_at - last) / 1000.0, (post_at - pre_at) / 1000.0, (now - post_at) / 1000.0,
				RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp), Performance.get_monitor(Performance.OBJECT_COUNT)]))
			if game == null:
				var draws0 := {}
				for i in stamps.size():
					var end0: int = stamps[i + 1][1] if i + 1 < stamps.size() else pre_at
					draws0[stamps[i][0]] = draws0.get(stamps[i][0], 0.0) + (end0 - stamps[i][1]) / 1000.0
				var dp := []
				for k in draws0:
					if draws0[k] > 0.3:
						dp.append("%s %.1f" % [k, draws0[k]])
				out.append(str("    draws: ", ", ".join(dp), "  first-draw at %.1f  title.t %.2f  node-process %.1f (starts at %.1f)" % [((stamps[0][1] if stamps.size() > 0 else pre_at) - last) / 1000.0, title.t if is_instance_valid(title) else -1.0, (proc_b - proc_a) / 1000.0, (proc_a - last) / 1000.0]))
			if game != null:
				var parts := []
				for k in game.prof:
					if game.prof[k] > 0.3:
						parts.append("%s %.1f" % [k, game.prof[k]])
				var gsum := 0.0
				for k in game.prof:
					gsum += game.prof[k]
				parts.append("game total %.1f" % gsum)
				var draws := {}
				for i in stamps.size():
					var end: int = stamps[i + 1][1] if i + 1 < stamps.size() else pre_at
					draws[stamps[i][0]] = draws.get(stamps[i][0], 0.0) + (end - stamps[i][1]) / 1000.0
				for k in draws:
					if draws[k] > 0.3:
						parts.append("draw %s %.1f" % [k, draws[k]])
				out.append(str("    k=%d " % ((frame - run_base) % 120), " | ".join(parts), "   enemies %d bullets %d flashes %d sparks %d rings %d phase %d first-draw at %.1f" % [game.enemies.list.size(), game.bullets.list.size(), game.fx.flashes.size(), game.fx.sp_list.size(), game.fx.rings.size(), game.wave_ctl.phase, ((stamps[0][1] if stamps.size() > 0 else pre_at) - last) / 1000.0]))
	last = now
	stamps.clear()
	if frame % 10 == 0:
		_watch(root)
	var t := frame
	if phase == "title":
		# page through once the menu is in, as a player would
		if title.t < 4.0:
			t = 0
			frame_base = frame
		t = frame - frame_base
		if t > 0 and t % 30 == 0:
			if title.page == "menu":
				title._go(["settings", "achievements"][(t / 60) % 2])
			else:
				title._go("menu")
		if t % 7 == 0:
			title._move(1)
		if t == 600:
			title.page = "menu"
			title.sel["menu"] = 0
			title.gun_i = 0
			title._accept(0)
			phase = "transition"
	elif phase == "transition" and current_scene is Game:
		game = current_scene
		game.prof_on = true
		game.bot = {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
		phase = "run"
		run_base = frame
	elif phase == "run":
		t = frame - run_base
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
		if t > 1500:
			for ln in out:
				print(ln)
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
