extends SceneTree
# Stills of the Lightrun school (off-screen): its card, a run, a burning line.
# Usage: tools/run_test.sh tests/walk_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(7)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/walk"))
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
	Cap.save(root, "res://proofs/walk/%s.png" % name)
	print(name, " saved")


func lay_line(at: Vector2, dir: Vector2):
	game.player.pos = at
	game.bullets.fire(at, dir)
	var rb = game.bullets.list[game.bullets.list.size() - 1]
	for k in 90:
		await frames(1)
		game.player.pos = at
		if rb.state == Bullets.EMBED and rb.t > 0.6:
			break
	return rb


func dash(dir: Vector2) -> void:
	bot.move = dir
	bot.dash = true
	await frames(2)
	bot.dash = false
	bot.move = Vector2.ZERO


func _run() -> void:
	await frames(2)
	game.next_chapter()
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.dev_god = true
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var d = game.enemies.spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60))
	d.state = Enemies.ALIVE
	d.hp = 99999.0
	var c: Vector2 = Arena.ROOM.get_center()
	game.lv.walk = 3
	var r1 = await lay_line(c, Vector2.RIGHT)
	var r2 = await lay_line(c, Vector2(0.3, -1.0))
	await lay_line(c + Vector2(0, 70), Vector2.RIGHT)
	for k in 5:
		var e = game.enemies.spawn(Enemies.CHASER, c.lerp(r1.pos, 0.2 + k * 0.16) + Vector2(0, 8))
		e.state = Enemies.ALIVE
		e.hp = 9999.0
		e.t = 1.0
	bot.focus = true
	await frames(30)
	game.player.pos = c.lerp(r1.pos, 0.1) + Vector2(0, 16)
	await dash(Vector2.RIGHT)
	await frames(3)
	await shot("1_run")
	while game.lightwalk.on:
		await frames(1)
	await frames(3)
	await shot("2_chain_window")
	game.player.pos = game.player.pos
	await dash((r2.pos - game.player.pos).normalized())
	await frames(3)
	await shot("3_second_run")
	bot.focus = false
	for k in 8:
		await frames(1)
	await shot("4_burning")
	game.lv.walk = 1
	game.hud.show_cards([{"type": "school", "id": "walk", "level": 1, "full": false}, {"type": "school", "id": "bounce", "level": 0, "full": false}, {"type": "relic", "id": "lightstep", "rarity": 0, "full": false}])
	await frames(70)
	await shot("5_cards")
	quit()
