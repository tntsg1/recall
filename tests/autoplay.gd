extends SceneTree
# A simple bot plays all six waves (headless, fixed 60 fps) and prints each
# wave's time, grade and hits taken. Used to set Waves.PAR.
# Usage: godot --headless --path . -s tests/autoplay.gd --fixed-fps 60 -- [runs]

var game
var frame := 0
var stall_told := false
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var last_hits := 0
var wave_hits: Array = []
var runs := 1
var run := 0
var all: Array = []
var brain
var jit := 0.14
var turn := 7.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	if args.size() > 2:
		jit = float(args[1])
		turn = float(args[2])
	_start()


func _start() -> void:
	if game:
		game.queue_free()
	seed(100 + run)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	frame = 0
	brain = preload("res://tests/brain.gd").new(bot)
	brain.skill_jitter = jit
	brain.skill_turn = turn
	wave_hits = []
	last_hits = 0


func _process(_dt: float) -> bool:
	frame += 1
	if game == null or not game.is_inside_tree():
		return false
	brain.think(game)
	var w = game.wave_ctl
	# a wave that never ends: say why, once
	if w.phase == Waves.FIGHT and w.t > 150.0 and not stall_told:
		stall_told = true
		print("  LONG WAVE ch%d w%d t=%.0f queue=%s remaining=%d list=%d lost=%s" % [game.chapter + 1, w.index + 1, w.t, str(w.queue), game.enemies.remaining(), game.enemies.list.size(), str(game.lost)])
		for e in game.enemies.list:
			print("    enemy kind=%d state=%d pos=%s hp=%.0f" % [e.kind, e.state, str(e.pos), e.hp])
	if w.results.size() > wave_hits.size():
		wave_hits.append(game.hits_taken - last_hits)
		last_hits = game.hits_taken
	if w.phase == Waves.DONE or frame > 60 * 60 * 40:
		var line := "RUN %d (%s ch%d, cracks %d, relics %s, lv %s):" % [run, "LOST" if game.lost else ("WON" if w.phase == Waves.DONE else "TIMEOUT"), game.chapter + 1, game.cracks, str(game.relics), str(game.lv)]
		for c in w.chapter_log:
			line += "  [%s %.0fs %s]" % [c[0], c[1], c[2]]
		for i in w.results.size():
			line += "  w%d %.1fs %s h%d" % [i + 1, w.results[i][0], w.results[i][1], wave_hits[i]]
		print(line)
		if w.phase != Waves.DONE and not game.lost:
			print("  STALL ch%d wave%d phase%d t=%.1f picking=%s replacing=%s queue=%d boss=%d pick_state=%d" % [game.chapter + 1, w.index + 1, w.phase, w.t, str(game.picking), str(not game.replacing.is_empty()), w.queue.size(), game.boss.state, w.pick_state])
			for e in game.enemies.list:
				print("    enemy kind=%d state=%d pos=%s hp=%.0f" % [e.kind, e.state, str(e.pos), e.hp])
		all.append(w.results.duplicate())
		run += 1
		if run >= runs:
			_summary()
			return true
		_start()
	return false


func _summary() -> void:
	var n := 0
	for r in all:
		n = maxi(n, r.size())
	for i in n:
		var ts: Array = []
		for r in all:
			if i < r.size():
				ts.append(r[i][0])
		ts.sort()
		print("WAVE %d  min %.1f  median %.1f  max %.1f" % [i + 1, ts[0], ts[ts.size() / 2], ts[ts.size() - 1]])


