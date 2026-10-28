extends SceneTree
# Stills of seizing a shell (off-screen window, no video): the cyan marks and the
# E key, the seized chaser mid-drill, its spiral finish, the seized leech's well
# pulling a crowd in. -> proofs/possess/*.png
# Usage: tools/run_test.sh tests/possess_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(1300, 540), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(4)
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


func spawn(kind: int, at: Vector2, still := true):
	var e = game.enemies.spawn(kind, at)
	e.state = Enemies.ALIVE
	e.t = 0.0
	if still:
		e.speed = 0.0
	return e


func clear() -> void:
	game.wave_ctl.queue.clear()
	var anchor = spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60))
	anchor.hp = 1e9
	anchor.maxhp = 1e9
	for e in game.enemies.list:
		if e != anchor and e.state != Enemies.HOST:
			e.state = Enemies.DEAD
	await frames(2)


func _run() -> void:
	var n := 0
	while game.wave_ctl.phase != Waves.FIGHT and n < 600:
		await process_frame
		n += 1
	game.dev_god = true
	game.dev_ammo = true
	await clear()
	var p: Player = game.player
	p.pos = Vector2(600, 600)
	# 1) marks: three marked chasers and a leech, the nearest shows the E key
	var marked: Array = []
	for k in 3:
		marked.append(spawn(Enemies.CHASER, Vector2(880 + k * 130, 480 + (k % 2) * 140)))
	marked.append(spawn(Enemies.LEECH, Vector2(1300, 640)))
	spawn(Enemies.GUARD, Vector2(1150, 820))
	for e in marked:
		game.possess.mark(e)
	await frames(20)
	await shot("1_marks")
	# 2) seize the nearest chaser and drill into a line
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(30)
	var c = game.possess.shell
	for k in 5:
		spawn(Enemies.CHASER, c.pos + Vector2(150 + k * 70, (k % 2) * 36 - 18))
	bot.aim = c.pos + Vector2(800, 0)
	bot.fire = true
	await frames(2)
	bot.fire = false
	await frames(5)
	await shot("2_drill")
	await frames(14)
	bot.fire = true
	await frames(2)
	bot.fire = false
	await frames(14)
	for k in 6:
		spawn(Enemies.CHASER, game.possess.shell.pos + Vector2.from_angle(TAU * k / 6.0) * 90.0)
	bot.fire = true
	await frames(2)
	bot.fire = false
	await frames(16)
	await shot("3_spiral")
	await frames(30)
	await shot("4_finish")
	# 3) the leech's well
	game.possess.t_left = 0.05
	await frames(20)
	await clear()
	game.possess.cooldown = 0.0
	p.pos = Vector2(700, 540)
	var l = spawn(Enemies.LEECH, Vector2(760, 540))
	game.possess.mark(l)
	bot.possess = true
	await frames(2)
	bot.possess = false
	await frames(30)
	var well: Vector2 = l.pos + Vector2(260, 0)
	for k in 7:
		var e = spawn(Enemies.CHASER if k % 2 == 0 else Enemies.CHARGER, well + Vector2.from_angle(TAU * k / 7.0) * 200.0)
		e.hp = 500.0
		e.maxhp = 500.0
	bot.aim = well
	bot.fire = true
	await frames(40)
	await shot("5_well")
	await frames(50)
	bot.fire = false
	await frames(6)
	await shot("6_well_burst")
	quit(0)
