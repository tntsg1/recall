extends SceneTree
# Each of chapters 7-9's own enemies in its own room, running a few seconds,
# with stills: they spawn, move, telegraph and attack without errors.
# -> proofs/foes/*.png
# Usage: tools/run_test.sh tests/chapter_foes3_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(21)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/foes"))
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
	Cap.save(root, "res://proofs/foes/%s.png" % name)
	print(name, " saved")


func clear() -> void:
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	game.enemies.zones.clear()


func put(kind: int, at: Vector2):
	var e = game.enemies.spawn(kind, at, 0.0)
	return e


func goto(story: int) -> void:
	while Chapters.story(game.chapter) < story:
		game.next_chapter()
	await frames(30)
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.hud.intro_t = -1.0
	game.hud.radio_t = -1.0
	clear()
	game.picking = false
	# a stand-in that never dies, far off, so the wave does not end and offer cards
	var keep = put(Enemies.TANK, Arena.ROOM.end - Vector2(60, 60))
	keep.hp = 1e9
	keep.maxhp = 1e9
	keep.speed = 0.0


func _run() -> void:
	await frames(2)
	game.dev_god = true
	var pl: Vector2 = Arena.ROOM.get_center()
	var bad := 0
	# ---- chapter 7: subwoofer rings, a choir sung back, a choir ended in one beat
	await goto(7)
	game.player.pos = pl + Vector2(0, 250)
	put(Enemies.SUBWOOFER, Vector2(Arena.ROOM.position.x + 80, pl.y))
	var mem: Array = []
	for k in 4:
		mem.append(put(Enemies.CHOIR, pl + Vector2.from_angle(k * PI * 0.5) * 48.0 + Vector2(200, -150)))
	game.enemies.form_choir(mem)
	var seen_ring := false
	for k in 150:
		await frames(1)
		if not game.enemies.rings.is_empty():
			seen_ring = true
	await shot("7_thought")
	var gid: int = mem[0].pass_hits
	game.enemies.blast_hit(mem[0], Vector2.UP, 9999.0)
	print("  dead after kill ", game.enemies.choirs[gid].dead, " bpm ", game.sfx.bpm(), " state ", mem[0].state)
	for q in 8:
		await frames(10)
		print("  t ", q, " alive ", game.enemies.choir_alive(gid), " dead ", game.enemies.choirs[gid].dead if game.enemies.choirs.has(gid) else "gone")
	var back: int = game.enemies.choir_alive(gid)
	for m in game.enemies.list:
		if m.kind == Enemies.CHOIR and m.state == Enemies.ALIVE:
			game.enemies.blast_hit(m, Vector2.UP, 9999.0)
	await frames(80)
	var gone: bool = not game.enemies.choirs.has(gid)
	print("ring seen ", seen_ring, " choir back to ", back, " ended ", gone)
	if not seen_ring or back != 4 or not gone:
		bad += 1
	# ---- chapter 8: a forger copies a round, the copy flies at you on recall; a redactor's ink
	await goto(8)
	game.player.pos = pl
	game.dev_ammo = true
	bot.aim = pl + Vector2(-600, 0)
	for sh in 3:
		bot.fire = true
		await frames(4)
		bot.fire = false
		await frames(8)
	await frames(60)
	var fg = put(Enemies.FORGER, pl + Vector2(-300, 120))
	put(Enemies.REDACTOR, pl + Vector2(420, -220))
	var faked := false
	for k in 700:
		await frames(1)
		game.wave_ctl.phase = Waves.FIGHT
		if not game.enemies.fakes.is_empty():
			faked = true
			break
	var emb := 0
	for b in game.bullets.list:
		if b.state == Bullets.EMBED:
			emb += 1
	print("  embedded ", emb, " bullets ", game.bullets.list.size(), " forger mode ", fg.mode, " state ", fg.state, " pos ", fg.pos, " cool ", fg.cool)
	await frames(30)
	await shot("8_archive")
	var foes0 := 0
	for b in game.bullets.list:
		if b.foe:
			foes0 += 1
	game.enemies.on_recall()
	await frames(45)
	var foes1 := 0
	for b in game.bullets.list:
		if b.foe:
			foes1 += 1
	for k in 200:
		await frames(1)
		game.wave_ctl.phase = Waves.FIGHT
		if not game.enemies.blots.is_empty() and game.enemies.blots[0].w <= 0.0:
			break
	await shot("8_archive_b")
	print("forged ", faked, " false rounds fired ", foes1 - foes0, " ink ", game.enemies.blots.size())
	if not faked or foes1 <= foes0 or game.enemies.blots.is_empty():
		bad += 1
	# ---- chapter 9: drifters, a bootman at a door, a tank's jet
	await goto(9)
	game.player.pos = pl
	for k in 5:
		put(Enemies.DRIFTER, pl + Vector2(-400, -200 + 60 * k))
	var bm = put(Enemies.BOOTMAN, pl + Vector2(300, 0))
	var tk = put(Enemies.TANK, pl + Vector2(-120, 200))
	var held := false
	await frames(200)
	await shot("9_elevator")
	await frames(200)
	# make its door the next to open
	var best := 0
	for k in game.vents.doors.size():
		if game.vents.door_pos(k).distance_to(bm.pos) < game.vents.door_pos(best).distance_to(bm.pos):
			best = k
	game.vents.door = best
	game.vents.door_t = game.vents.WARN + 0.2
	for k in 60:
		await frames(1)
		game.wave_ctl.phase = Waves.FIGHT
		if bm.mode == 1:
			held = true
	await shot("9_elevator_b")
	game.picking = false
	tk.state = Enemies.ALIVE
	tk.pos = pl
	var ch = put(Enemies.CHASER, tk.pos + Vector2(80, 0))
	ch.state = Enemies.ALIVE
	ch.hp = 999.0
	await frames(1)
	var before: Vector2 = ch.pos
	game.enemies.blast_hit(tk, Vector2.RIGHT, 9999.0)
	await frames(10)
	print("bootman held a door ", held, " jet threw ", int(ch.pos.distance_to(before)))
	if not held or ch.pos.distance_to(before) < 40.0:
		bad += 1
	# ---- each new shell
	for k in [Enemies.SUBWOOFER, Enemies.CHOIR, Enemies.FORGER, Enemies.REDACTOR, Enemies.DRIFTER, Enemies.BOOTMAN, Enemies.TANK]:
		clear()
		if game.possess.state != Possess.IDLE:
			game.possess.end(false)
			await frames(30)
		game.player.pos = pl
		var sh = put(k, pl)
		sh.state = Enemies.ALIVE
		sh.pos = pl
		var foes: Array = []
		for j in 5:
			var f = put(Enemies.CHASER, pl + Vector2(140 + 40 * j, -60 + 30 * j))
			f.state = Enemies.ALIVE
			f.hp = 999.0
			foes.append(f)
		game.wave_ctl.phase = Waves.FIGHT
		game.possess.seize_now(sh)
		await frames(20)
		game.picking = false
		bot.aim = pl + Vector2(300, 0)
		var hp0 := 0.0
		for f in foes:
			hp0 += f.hp
		for c in 3:
			bot.fire = true
			await frames(2)
			bot.fire = false
			game.wave_ctl.phase = Waves.FIGHT
			await frames(28)
		await frames(20)
		var hp1 := 0.0
		for f in foes:
			hp1 += f.hp
		print("shell ", Txt.t("shell_k%d" % k), " dealt ", int(hp0 - hp1))
		if hp1 >= hp0:
			bad += 1
	print("bad ", bad)
	print("foes3 ok" if bad == 0 else "foes3 FAIL")
	quit()
