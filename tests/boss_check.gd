extends SceneTree
# Headless: jump straight to a boss, let the bot fight it, print the result.
# Usage: godot --headless --path . -s tests/boss_check.gd --fixed-fps 60 -- [runs] [max] [boss=lockdown|warden|devourer|train|metronome|zero]

var game
var brain
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var frame := 0
var runs := 1
var run := 0
var maxed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	maxed = "max" in args
	_start()


func _start() -> void:
	if game:
		game.queue_free()
	var base := 300 + (int(OS.get_environment("BOSS_SEED")) if OS.get_environment("BOSS_SEED") != "" else 0)
	seed(base + run)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	brain = preload("res://tests/brain.gd").new(bot)
	frame = 0
	await process_frame
	# which boss: boss=<name> (Chapters), or the old ch2..ch5 for the bosses that
	# used to sit there; the first chapter's by default
	var want := Chapters.boss(0)
	var old := {"ch2": "warden", "ch3": "devourer", "ch4": "metronome", "ch5": "zero", "train": "train"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("boss="):
			want = a.substr(5)
		elif old.has(a):
			want = old[a]
	for i in Chapters.count():
		if Chapters.boss(i) == want:
			for k in i:
				game.next_chapter()
			break
	game.wave_ctl.index = Waves.BOSS - 1
	game.wave_ctl.phase = Waves.CLEAR
	game.wave_ctl.pick_state = 2
	game.wave_ctl.t = 10.0
	game.lv = {"bounce": 3, "split": 3, "orbit": 3, "magnet": 0, "blast": 0, "charge": 0, "shadow": 0, "chain": 0, "possess": 0} if maxed else {"bounce": 1, "split": 2, "orbit": 2, "magnet": 0, "blast": 0, "charge": 0, "shadow": 0, "chain": 0, "possess": 0}


func _process(_dt: float) -> bool:
	frame += 1
	if game == null or not game.is_inside_tree():
		return false
	brain.think(game)
	var w = game.wave_ctl
	if frame % 600 == 0:
		print("  t %.0fs hp %.0f phase %d state %d core %.2f bullets %d  ammo %d emb %d possess %d focus %s paused %s picking %s" % [frame / 60.0, game.boss.hp, game.boss.phase, game.boss.state, game.boss.core_open, game.bullets.list.size(), game.ammo, game.bullets.count_state(Bullets.EMBED), game.possess.state, str(game.focusing), str(game.paused), str(game.picking)])
		if game.boss is Lockdown:
			var L = game.boss
			print("    LD lamp0 %s a %s tilt %s hit %s" % [str(L.lamp_pos(0)), str(L.lamp_a), str(L.tilt), str(L.hit_test(game.player.pos, L.lamp_pos(0)))])
			print("    LD t %.1f pos %s lock %s cool %s aim %s lamp_hp %s player %s inst %d inside %s" % [L.t, str(L.pos), str(L.lamp_lock), str(L.lamp_cool), str(L.lamp_aim), str(L.lamp_hp), str(game.player.pos), L.get_instance_id(), str(L.is_inside_tree())])
		var hist := {}
		for bb in game.bullets.list:
			hist[bb.state] = hist.get(bb.state, 0) + 1
		print("    slow %.3f hitstop %.3f ts %.2f cine %.2f lost %s  " % [game.slow, game.hitstop, Engine.time_scale, game.cine_t, str(game.lost)], "bullet states ", hist, "  first: left %.2f t %.2f orbited %s pos %s dir %s path %d" % [game.bullets.list[0].orbit_left if game.bullets.list.size() > 0 else 0.0, game.bullets.list[0].t if game.bullets.list.size() > 0 else 0.0, str(game.bullets.list[0].orbited) if game.bullets.list.size() > 0 else "-", str(game.bullets.list[0].pos) if game.bullets.list.size() > 0 else "-", str(game.bullets.list[0].dir) if game.bullets.list.size() > 0 else "-", game.bullets.list[0].path.size() if game.bullets.list.size() > 0 else 0])
	if w.results.size() > 0 or frame > 60 * 300:
		var r = w.results[0] if w.results.size() > 0 else ["timeout", "-"]
		print("BOSS run %d: %s %s hits %d" % [run, str(r[0]), r[1], game.hits_taken])
		run += 1
		if run >= runs:
			return true
		_start()
	return false
