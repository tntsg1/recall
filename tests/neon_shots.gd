extends SceneTree
# Stills of the neon in R-0's powers (off-screen): the title sign striking on
# letter by letter, an enemy's tube striking and going out, rounds in the
# wall hot and then cooled, the light running home and you lit by it, a
# dodge's streak, and the signal you break into a shell by.
# -> proofs/neon/*.png
# Usage: tools/run_test.sh tests/neon_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var title
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	Meta.dev_unlock = true   # tests never write the player's save
	Meta.next_seed = 424242
	seed(5)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/neon"))
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame
		if game != null and game.picking:
			bot["pick"] = 0


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/neon/%s.png" % name)
	print(name, " saved")


func _run() -> void:
	# the title: the sign strikes on, letter by letter
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await frames(152)
	await shot("1_title_striking")
	await frames(16)
	await shot("2_title_half")
	await frames(90)
	await shot("3_title_lit")
	title.queue_free()
	await frames(2)
	Meta.dev_unlock = false
	# a run
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	await frames(200)   # the wave's title and the grade stamp gone
	game.dev_god = true
	var c: Vector2 = Arena.ROOM.get_center()
	var crops: Array = []   # [name, centre]: close-ups laid side by side after
	game.player.pos = c + Vector2(-320, 160)
	# an enemy striking on: dark, the starter's stutter, the surge
	var e1 = game.enemies.spawn(Enemies.CHASER, c + Vector2(40, -40))
	e1.state = Enemies.SPAWN
	for st: Array in [[0.3, "a_strike_dark"], [0.5, "b_strike_stutter"], [0.72, "c_strike_surge"], [1.1, "d_lit"]]:
		e1.t = st[0]
		if st[0] >= 1.0:
			e1.state = Enemies.ALIVE
		await frames(1)
		e1.t = st[0]
		await shot(st[1])
		crops.append([st[1], e1.pos])
	# and going out (not the wave's last: that one gets the finishing slow-mo)
	var by = game.enemies.spawn(Enemies.GUARD, c + Vector2(560, 300))
	by.state = Enemies.ALIVE
	by.t = 1.0
	await frames(2)
	var at: Vector2 = e1.pos
	game.enemies.blast_hit(e1, Vector2.RIGHT, e1.hp + 1.0)
	game.fx.numbers.clear()
	for st2: Array in [[3, "e_out_stutter"], [14, "f_out_afterglow"], [30, "g_out_gone"]]:
		await frames(st2[0] if st2[1] == "e_out_stutter" else (11 if st2[1] == "f_out_afterglow" else 16))
		game.fx.numbers.clear()
		await shot(st2[1])
		crops.append([st2[1], at])
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	await frames(20)
	# a round in flight, then the same round landing white-hot, and cooled
	game.player.pos = c + Vector2(-200, 0)
	game.bullets.fire(game.player.pos, Vector2.RIGHT)
	game.ammo -= 1
	await frames(5)
	var fb = game.bullets.list[game.bullets.list.size() - 1]
	await shot("h_round_flying")
	crops.append(["h_round_flying", fb.pos])
	while fb.state != Bullets.EMBED:
		await frames(1)
	await frames(6)
	await shot("i_round_landed_hot")
	crops.append(["i_round_landed_hot", fb.pos])
	await frames(200)
	await shot("j_round_cooled_3s")
	crops.append(["j_round_cooled_3s", fb.pos])
	# the light running home, and you lit by it
	for j in 3:
		game.bullets.fire(game.player.pos, Vector2.from_angle(-PI * 0.5 + (j - 1) * 0.5))
		game.ammo -= 1
	await frames(60)
	var n: int = game.bullets.recall(game.player.pos)
	print("recalled ", n)
	await frames(8)
	await shot("k_recall_running")
	for k in 90:
		await frames(1)
		if game.player.light > 0.6:
			break
	await shot("l_light_home")
	crops.append(["l_light_home", game.player.pos])
	await frames(60)
	# a dodge
	game.player.pos = c + Vector2(-260, 60)
	game.player.try_dash(Vector2.RIGHT)
	await frames(7)
	await shot("m_dodge")
	crops.append(["m_dodge", game.player.pos + Vector2(-90, 0)])
	await frames(40)
	# the signal into a shell
	var sh = game.enemies.spawn(Enemies.CHASER, c + Vector2(180, -120))
	sh.state = Enemies.ALIVE
	sh.t = 1.0
	await frames(2)
	game.possess.flow_from = game.player.pos
	game.possess.seize_now(sh)
	await frames(4)
	await shot("n_possess_signal")
	crops.append(["n_possess_signal", (game.possess.flow_from + sh.pos) * 0.5])
	# the close-ups' centres, for tools to lay out
	var f := FileAccess.open("res://proofs/neon/crops.txt", FileAccess.WRITE)
	for cr in crops:
		f.store_line("%s %d %d" % [cr[0], int(cr[1].x), int(cr[1].y)])
	f.close()
	print("NEON SHOTS DONE")
	quit()
