extends SceneTree
# Real play, real frame times: the bot plays the opening of a run (vsync off,
# no fixed fps) and every frame over the budget is printed with where its time
# went. Ends with the average, the 99th percentile and the worst frame.
# Usage: tools/run_test.sh tests/play_perf.gd -- [seconds] [budget_ms] [cold] [story=N] [boss]
# (cold: skip the title's warm-up, to see what it saves)

const BUDGET := 7.0

var game
var brain
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var times: Array = []
var last := 0
var pre_at := 0
var start_ms := 0
var seconds := 40.0
var budget := BUDGET
var over := 0
var brain_ms := 0.0
var tot_draw := {}         # node -> summed draw ms over the whole run
var tot_proc := 0.0
var tot_n := 0
var out: Array = []        # spike lines, printed at the end (printing is slow)
var stamps: Array = []     # [name, usec] as each canvas item starts drawing


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Meta.test_mode = true
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		seconds = float(args[0])
	if args.size() > 1:
		budget = float(args[1])
	RenderingServer.frame_pre_draw.connect(func(): pre_at = Time.get_ticks_usec())
	seed(7)
	# as in play: the title's warm-up runs first (with the same glow), then the run
	if not "cold" in OS.get_cmdline_user_args():
		var env := WorldEnvironment.new()
		env.environment = Game.make_environment()
		env.environment.glow_intensity = 0.0001
		root.add_child(env)
		var w := Warm.new()
		root.add_child(w)
		while not Warm.done:
			await process_frame
		# leaving the title frees it, page text and all
		if is_instance_valid(w):
			w.queue_free()
		env.queue_free()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	game.prof_on = true
	brain = preload("res://tests/brain.gd").new(bot)
	# story=N: start in that story chapter; boss: straight to its boss
	for a in args:
		if a.begins_with("story="):
			await process_frame
			while Chapters.story(game.chapter) < int(a.substr(6)) and game.chapter < Chapters.count() - 1:
				game.next_chapter()
	if "boss" in args:
		await process_frame
		game.dev_jump(Waves.BOSS)
	_watch.call_deferred(game)


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


func _process(_dt: float) -> bool:
	if game == null:
		return false
	frame += 1
	var now := Time.get_ticks_usec()
	if last > 0 and frame > 30:
		var ms := (now - last) / 1000.0
		times.append(ms)
		var first0 := pre_at
		for i in stamps.size():
			var end0: int = stamps[i + 1][1] if i + 1 < stamps.size() else pre_at
			first0 = mini(first0, stamps[i][1])
			tot_draw[stamps[i][0]] = tot_draw.get(stamps[i][0], 0.0) + (end0 - stamps[i][1]) / 1000.0
		tot_proc += (first0 - last) / 1000.0 - brain_ms
		tot_n += 1
		for k in game.prof:
			if String(k).begins_with("d_"):
				tot_draw["fx." + k] = tot_draw.get("fx." + k, 0.0) + game.prof[k]
		if ms > budget:
			over += 1
			if over <= 60:
				var parts := []
				for k in game.prof:
					if game.prof[k] > 0.25:
						parts.append("%s %.1f" % [k, game.prof[k]])
				var draws := {}
				var first := pre_at
				for i in stamps.size():
					var end: int = stamps[i + 1][1] if i + 1 < stamps.size() else pre_at
					first = mini(first, stamps[i][1])
					var d: float = (end - stamps[i][1]) / 1000.0
					draws[stamps[i][0]] = draws.get(stamps[i][0], 0.0) + d
				var dp := []
				for k in draws:
					if draws[k] > 0.3:
						dp.append("%s %.1f" % [k, draws[k]])
				out.append(str("    process %.1f (bot %.1f)  draws: %s" % [(first - last) / 1000.0 - brain_ms, brain_ms, ", ".join(dp)]))
				var w = game.wave_ctl
				out.append(str("SPIKE f%d %.1f ms  logic+draw %.1f  render %.1f | %s | wave %d phase %d enemies %d bullets %d fx %d" % [frame, ms, (pre_at - last) / 1000.0, (now - pre_at) / 1000.0, " ".join(parts), w.index + 1, w.phase, game.enemies.list.size(), game.bullets.list.size(), game.fx.sp_list.size() + game.fx.shards.size() + game.fx.rings.size()]))
	last = now
	stamps.clear()
	if frame % 20 == 0:
		_watch(game)
	if start_ms == 0:
		start_ms = Time.get_ticks_msec()
	if game.is_inside_tree():
		var tb := Time.get_ticks_usec()
		brain.think(game)
		brain_ms = (Time.get_ticks_usec() - tb) / 1000.0
	if (Time.get_ticks_msec() - start_ms) / 1000.0 > seconds or game.lost:
		for ln in out:
			print(ln)
		var sorted := times.duplicate()
		sorted.sort()
		var s := 0.0
		for v in times:
			s += v
		print("PLAYPERF frames %d  avg %.2f ms  p99 %.2f ms  worst %.2f ms  over %.0f ms: %d  (wave %d, lost %s)" % [times.size(), s / times.size(), sorted[int(sorted.size() * 0.99)], sorted[-1], budget, over, game.wave_ctl.index + 1, str(game.lost)])
		print("PLAYPERF node processing avg %.2f ms (bot excluded)" % (tot_proc / tot_n))
		var keys := tot_draw.keys()
		keys.sort_custom(func(a, b): return tot_draw[a] > tot_draw[b])
		for k in keys.slice(0, 12):
			print("PLAYPERF draw avg %.3f ms  %s" % [tot_draw[k] / tot_n, k])
		return true
	return false
