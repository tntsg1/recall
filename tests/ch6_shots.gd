extends SceneTree
# Stills of chapter 6 (off-screen): the bureau at the opening, arcs between
# rounds laid close, an inspector putting rounds out, every remnant awake,
# the grid master shielded, a district fed, the transformer open.
# -> proofs/lore/ch6_*.png
# Usage: tools/run_test.sh tests/ch6_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(6)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/lore"))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/lore/ch6_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 6:
		game.next_chapter()
	await frames(80)
	game.player.pos = Vector2(960, 860)
	await frames(10)
	await shot("1_open")
	while game.wave_ctl.phase != Waves.FIGHT:
		await process_frame
	game.dev_god = true
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var anchor = game.enemies.spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(1600, 60))
	anchor.state = Enemies.ALIVE
	anchor.hp = 1e9
	# rounds laid into both faces of the gate between the two low housings:
	# the arcs close it, and a chaser runs into it
	game.player.pos = Vector2(960, 640)
	for k in 4:
		game.bullets.fire(Vector2(960, 760 + k * 18), Vector2.LEFT)
		game.bullets.fire(Vector2(960, 768 + k * 18), Vector2.RIGHT)
		await frames(3)
	await frames(30)
	game.player.pos = Vector2(960, 560)
	var c = game.enemies.spawn(Enemies.CHASER, Vector2(960, 960))
	c.state = Enemies.ALIVE
	c.hp = 1e9
	await frames(8)
	await shot("2_arcs")
	# an inspector walks to the rounds and puts them out
	c.state = Enemies.DEAD
	var ins = game.enemies.spawn(Enemies.INSPECTOR, Vector2(700, 960))
	ins.state = Enemies.ALIVE
	ins.hp = 1e9
	await frames(100)
	await shot("3_inspector")
	ins.hp = 1.0
	game.enemies.blast_hit(ins, Vector2.UP, 50.0)
	await frames(30)
	await shot("4_inspector_down")
	for w in Lore.walls(6):
		game.lore.hold["w6_%s" % w[0]] = 9.0
	await frames(40)
	await shot("5_remnants")
	game.dev_jump(Waves.BOSS)
	while game.boss.state != GridMaster.RUN:
		await process_frame
	var bs = game.boss
	game.player.pos = Vector2(960, 880)
	await frames(60)
	# one cable cut into, so its bar shows
	bs._hurt_cable(2, 70.0, bs.cable_from(2).lerp(bs.cable_to(2), 0.4))
	await frames(10)
	await shot("6_grid")
	while bs.mode != GridMaster.WARN or bs.mode_t < 0.9:
		await process_frame
	await shot("7_zone")
	# three districts fed at once, you between them
	bs.phase = 2
	bs.mode = GridMaster.IDLE
	bs.zone_cd = 0.0
	game.player.pos = Vector2(960, 800)
	while bs.mode != GridMaster.WARN or bs.mode_t < 0.8:
		await process_frame
	await shot("9_zones")
	bs.phase = 0
	await frames(30)
	for k in 3:
		bs.cable_hp[k] = 0.0
	bs._hurt_cable(0, 0.0, bs.pos)
	while bs.rings.is_empty() or bs.rings[0][0] < 0.35:
		await process_frame
	await shot("8_open")
	quit()
