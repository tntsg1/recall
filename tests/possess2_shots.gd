extends SceneTree
# Stills of the N2 shells mid-move (off-screen window, no video):
# guard rush, charger ram with its red line, prism burst, pulse ring, echo copies.
# -> proofs/possess/n2_*.png   Usage: tools/run_test.sh tests/possess2_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(1300, 540), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(8)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/possess"))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/possess/%s.png" % name)
	print(name, " saved")


func spawn(kind: int, at: Vector2, hp: float = 600.0):
	var e = game.enemies.spawn(kind, at)
	e.state = Enemies.ALIVE
	e.t = 0.0
	e.speed = 0.0
	e.hp = hp
	e.maxhp = hp
	return e


func seize(kind: int, at: Vector2):
	if game.possess.hosting():
		game.possess.end(false, true)
	game.wave_ctl.queue.clear()
	var anchor = spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60), 1e9)
	for e in game.enemies.list:
		if e != anchor and e.state != Enemies.HOST:
			e.state = Enemies.DEAD
	await frames(3)
	game.possess.cooldown = 0.0
	game.player.pos = at - Vector2(80, 0)
	var e = spawn(kind, at)
	game.possess.mark(e)
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(30)
	return e


func click() -> void:
	bot.fire = true
	await frames(2)
	bot.fire = false


func _run() -> void:
	var n := 0
	while game.wave_ctl.phase != Waves.FIGHT and n < 600:
		await process_frame
		n += 1
	game.dev_god = true
	game.dev_ammo = true
	# guard: shove, sweep, rush a row into the wall
	var g = await seize(Enemies.GUARD, Vector2(1250, 540))
	bot.aim = g.pos + Vector2(600, 0)
	for k in 4:
		spawn(Enemies.CHASER, g.pos + Vector2(90 + k * 45, (k % 2) * 30 - 15))
	await frames(8)
	await click()
	await frames(14)
	await click()
	await frames(14)
	await click()
	await frames(9)
	await shot("n2_1_guard_rush")
	# charger: wind up, then ram
	var c = await seize(Enemies.CHARGER, Vector2(700, 600))
	bot.aim = c.pos + Vector2(700, -260)
	for k in 4:
		spawn(Enemies.GUARD, c.pos + Vector2(180 + k * 150, -60 - k * 55))
	bot.fire = true
	await frames(20)
	await shot("n2_2_charger_aim")
	bot.fire = false
	await frames(30)
	await shot("n2_3_charger_ram")
	# prism: one, three, twelve
	var p = await seize(Enemies.PRISM, Vector2(960, 540))
	bot.aim = p.pos + Vector2(500, 0)
	for k in 10:
		spawn(Enemies.CHASER, p.pos + Vector2.from_angle(TAU * k / 10.0 + 0.2) * randf_range(180, 320))
	await click()
	await frames(14)
	await click()
	await frames(14)
	await click()
	await frames(2)
	await shot("n2_4_prism_burst")
	# pulse: a ring on the beat
	var u = await seize(Enemies.PULSE, Vector2(960, 540))
	for k in 8:
		spawn(Enemies.CHASER, u.pos + Vector2.from_angle(TAU * k / 8.0) * 150.0)
	var w := 0
	while not game.possess.on_beat_now() and w < 200:
		await process_frame
		w += 1
	await click()
	await frames(4)
	await shot("n2_5_pulse_ring")
	# echo: two copies then the replay
	var o = await seize(Enemies.ECHO, Vector2(600, 540))
	await click()
	bot.move = Vector2(1, -0.4).normalized()
	await frames(30)
	bot.move = Vector2(1, 0.6).normalized()
	await frames(30)
	bot.move = Vector2.ZERO
	await click()
	for k in 5:
		spawn(Enemies.CHASER, o.pos + Vector2(80 + k * 70, -50 + (k % 2) * 60))
	bot.move = Vector2(0, 1)
	await frames(20)
	bot.move = Vector2.ZERO
	await shot("n2_6_echo_copies")
	await click()
	await frames(24)
	await shot("n2_7_echo_replay")
	quit(0)
