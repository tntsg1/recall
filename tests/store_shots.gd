extends SceneTree
# Steam store screenshots (off-screen, 1920x1080): the test bot plays a
# chapter (or its boss) and every few seconds, when rounds are lit or flying
# home, the frame is saved. One language a run (broadcasts keep the language
# they were made in), so run it once per language with the same arguments.
# -> proofs/store/<lang>/ch<N>_<wave|boss>_<i>.png
# Usage: tools/run_test.sh tests/store_shots.gd --fixed-fps 60 -- <ch 1-12> <wave|boss> <shots> <english|schinese> [warmup s] [gap s]

const Cap = preload("res://tests/cap.gd")
var game
var brain
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var ch := 1
var boss := false
var want := 4
var warm := 8.0
var gap := 5.0
var lang := "english"


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Meta.test_mode = true
	var a := OS.get_cmdline_user_args()
	ch = int(a[0]) if a.size() > 0 else 1
	boss = a.size() > 1 and a[1] == "boss"
	want = int(a[2]) if a.size() > 2 else 4
	lang = a[3] if a.size() > 3 else "english"
	warm = float(a[4]) if a.size() > 4 else 8.0
	gap = float(a[5]) if a.size() > 5 else 5.0
	Txt.zh = lang == "schinese"
	seed(900 + ch * 7 + (1 if boss else 0))
	Meta.next_seed = 31337 + ch
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/store/" + lang))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game
	brain = preload("res://tests/brain.gd").new(bot)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await frames(2)
	for i in ch - 1:
		game.next_chapter()
	game.dev_god = true
	game.lightwalk.tip_done = true
	game.lv = {"bounce": 1, "split": 1, "orbit": 1, "magnet": 0, "blast": 1, "charge": 0, "shadow": 0, "chain": 1, "possess": 1}
	if boss:
		while game.wave_ctl.phase != Waves.FIGHT:
			brain.think(game)
			await frames(1)
		game.wave_ctl.index = Waves.BOSS - 1
		game.wave_ctl.phase = Waves.CLEAR
		game.wave_ctl.pick_state = 2
		game.wave_ctl.t = 10.0
	var t := 0.0
	var last := -99.0
	var held := 0
	var got := 0
	while got < want and t < warm + want * gap * 4.0:
		brain.think(game)
		game.hud.hint_a = 0.0
		await frames(1)
		t += 1.0 / 60.0
		held = held + 1 if bot.focus else 0
		var homing := 0
		for b in game.bullets.list:
			if b.state == Bullets.RETURN:
				homing += 1
		var lively: bool = held >= 16 or homing >= 3
		if t > warm and t - last > gap and lively and not game.picking and game.wave_ctl.phase == Waves.FIGHT:
			last = t
			await _shot("ch%d_%s_%d" % [ch, "boss" if boss else "wave", got])
			got += 1
	print("STORE SHOTS DONE ", got)
	quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/store/%s/%s.png" % [lang, name])
