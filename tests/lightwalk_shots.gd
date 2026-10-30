extends SceneTree
# Stills of light-speed travel (off-screen): the second chapter's first wave
# telling it, the lines lit while you hold recall, the dodge into one and the
# run along it as light cutting an enemy, and coming out with the round.
# -> proofs/lightwalk/*.png
# Usage: tools/run_test.sh tests/lightwalk_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	Meta.next_seed = 424242
	seed(5)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/lightwalk"))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/lightwalk/%s.png" % name)
	print(name, " saved")


func _run() -> void:
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.next_chapter()
	# the second chapter's first wave: its title tells the power
	while game.hud.title_note != "note_lightwalk" or game.hud.title_t < 0.0:
		await frames(1)
	await frames(60)
	await shot("1_chapter2_note")
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	# a still dummy far off keeps the wave open
	var d = game.enemies.spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(80, 80))
	d.state = Enemies.ALIVE
	d.hp = 99999.0
	d.t = 1.0
	await frames(150)
	game.dev_god = true
	var c: Vector2 = Arena.ROOM.get_center() + Vector2(-260, 60)
	game.player.pos = c
	for j in 4:
		game.bullets.fire(c, Vector2.from_angle(-0.35 + j * 0.25))
		game.ammo -= 1
	await frames(70)
	var rb = null
	for b in game.bullets.list:
		if b.state == Bullets.EMBED and absf(b.dir.angle() - (-0.35 + 0.25)) < 0.05:
			rb = b
	if rb == null:
		rb = game.bullets.list[1]
	var foes := []
	for u: float in [0.45, 0.7]:
		var f = game.enemies.spawn(Enemies.CHASER, c.lerp(rb.pos, u))
		f.state = Enemies.ALIVE
		f.t = 1.0
		f.hp = 999.0
		foes.append(f)
	bot.focus = true
	for k in 40:
		await frames(1)
		for j in foes.size():
			foes[j].pos = c.lerp(rb.pos, [0.45, 0.7][j])
	game.player.pos = c + (rb.pos - c).normalized() * 30.0 + (rb.pos - c).normalized().orthogonal() * 18.0
	bot.move = (rb.pos - c).normalized()
	await frames(3)
	game.player.pos = c + (rb.pos - c).normalized() * 30.0 + (rb.pos - c).normalized().orthogonal() * 18.0
	await shot("2_lines_lit")
	bot.move = (rb.pos - c).normalized()
	print("rb light %.2f state %d len %.0f cd %.2f" % [rb.light, rb.state, rb.total(), game.player.dash_cd])
	bot.dash = true
	await frames(2)
	bot.dash = false
	bot.move = Vector2.ZERO
	for k in 30:
		await frames(1)
		for j in foes.size():
			foes[j].pos = c.lerp(rb.pos, [0.45, 0.7][j])
		if game.lightwalk.on and game.lightwalk.s > rb.total() * 0.55:
			break
	await shot("3_running_as_light")
	for k in 30:
		await frames(1)
		if not game.lightwalk.on:
			break
	var a0: int = game.ammo
	for k in 90:
		await frames(1)
		if game.ammo > a0:
			break
	await frames(4)
	await shot("4_out_with_the_round")
	print("ammo ", a0, " -> ", game.ammo)
	print("on=", game.lightwalk.on, " walked=", rb.walked)
	bot.focus = false
	print("LIGHTWALK SHOTS DONE")
	quit()
