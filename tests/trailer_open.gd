extends SceneTree
# The trailer's opening, staged (off-screen): the first chapter's hand-made
# room, no schools, the standard magazine. R-0 shoots down a few chasers and
# keeps firing till the magazine is empty; a whole pack then pours in from the
# wall where the rounds sit; R-0 holds recall and lets go - every round comes
# home through the pack and wipes it.
# Shots:  tools/run_test.sh tests/trailer_open.gd --fixed-fps 60 -- shots
# Movie:  tools/run_test.sh tests/trailer_open.gd --write-movie <out.avi> --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 540), "fire": false, "focus": false, "dash": false, "possess": false}
var shots := false
var frame := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Meta.test_mode = true
	shots = "shots" in OS.get_cmdline_user_args()
	Txt.zh = "zh" in OS.get_cmdline_user_args()
	RoomGen.force_off = true
	seed(4242)
	Meta.next_seed = 4242
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/trailer"))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game
	_run.call_deferred()


var dummy = null


func frames(n: int) -> void:
	for i in n:
		await process_frame
		game.hud.hint_a = 0.0
		# an unkillable dummy far outside the room keeps the wave open (no cards)
		if dummy != null:
			dummy.pos = Vector2(-4000, -4000)
			dummy.hp = 99999.0


func shot(name: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/trailer/%s.png" % name)


func alive() -> Array:
	return game.enemies.list.filter(func(e): return e.state == Enemies.ALIVE and e != dummy)


func nearest(p: Vector2):
	var best = null
	for e in alive():
		if best == null or e.pos.distance_to(p) < best.pos.distance_to(p):
			best = e
	return best


func _run() -> void:
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	dummy = game.enemies.spawn(Enemies.GUARD, Vector2(-4000, -4000))
	dummy.state = Enemies.ALIVE
	dummy.t = 1.0
	game.dev_god = true
	game.lightwalk.tip_done = true
	var room: Rect2 = Arena.ROOM
	# (the gap between the upper-left pillar and the left bar: a clear field of fire to the right)
	var me := Vector2(330.0, 440.0)
	game.player.pos = me
	game.player.position = me
	await frames(30)
	# 1. plain fighting: three chasers from the right, shot down in short bursts
	for k in 3:
		game.enemies.spawn(Enemies.CHASER, Vector2(1500.0, 300.0 + k * 150.0), 0.5 * k)
	var t := 0.0
	var tap := 0
	while t < 7.0:
		game.player.pos = me
		var e = nearest(me)
		if e == null and t > 1.5:
			break
		if e != null:
			bot.aim = e.pos + (e.pos - me).normalized() * 20.0
		tap += 1
		bot.fire = e != null and tap % 22 < 7
		await frames(1)
		t += 1.0 / 60.0
	bot.fire = false
	print("three down at %.2f s, ammo %d" % [t, game.ammo])
	await frames(20)
	# 2. something is coming: the rest of the magazine sprayed across the far wall
	var sway := 0.0
	while game.ammo > 0 and sway < 6.0:
		sway += 1.0 / 60.0
		bot.aim = me + Vector2.from_angle(lerpf(-0.24, 0.40, 0.5 + 0.5 * sin(sway * 3.0))) * 700.0
		bot.fire = true
		await frames(1)
	bot.fire = false
	print("empty after %.2f s spraying" % sway)
	await shot("1_empty")
	# 3. the pack pours in from that wall
	await frames(24)
	for k in 12:
		var y := room.position.y + 90.0 + k * (room.size.y - 180.0) / 11.0
		game.enemies.spawn(Enemies.CHASER, Vector2(1380.0 - (k % 2) * 80.0, y), 0.03 * k)
	# R-0 clicks on an empty magazine as they come
	var waited := 0.0
	while waited < 10.0:
		var near := 0
		for e in alive():
			if e.pos.distance_to(me) < 270.0:
				near += 1
		bot.aim = me + Vector2(400, 0)
		bot.fire = int(waited * 60.0) % 20 < 3
		await frames(1)
		waited += 1.0 / 60.0
		if near >= alive().size() * 0.6 and alive().size() > 0:
			break
	bot.fire = false
	var ds := alive().map(func(e): return int(e.pos.distance_to(me)))
	print("recall after %.2f s, distances %s" % [waited, ds])
	await shot("2_pack_close")
	# 4. hold recall: the lines light; let go
	bot.focus = true
	await frames(28)
	await shot("3_lines_lit")
	bot.focus = false
	var before := alive().size()
	await frames(12)
	await shot("4_coming_home")
	await frames(40)
	print("pack %d -> %d alive" % [before, alive().size()])
	await frames(50)
	await shot("5_wiped")
	print("then %d alive" % alive().size())
	await frames(60)
	print("TRAILER OPEN DONE")
	quit()
