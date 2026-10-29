extends SceneTree
# Stills of chapter 8 (off-screen): the archive at the opening, an aisle about
# to close, rounds riding a shelf, a proofreader's correction, every remnant
# awake, the archivist's bars and an open drawer, R-0's file struck out, and
# the page after it falls. -> proofs/lore/ch8_*.png
# Usage: tools/run_test.sh tests/ch8_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(8)
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
	Cap.save(root, "res://proofs/lore/ch8_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 8:
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
	var anchor = game.enemies.spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(1600, 860))
	anchor.state = Enemies.ALIVE
	anchor.hp = 1e9
	await frames(150)
	# rounds into the left bank's shelves, then wait for the bank to move
	game.player.pos = Vector2(960, 640)
	for k in 6:
		game.bullets.fire(game.player.pos, Vector2.from_angle(PI + (k - 2.5) * 0.06))
	await frames(20)
	game.shelves.clock[0] = Shelves.PERIOD - 0.02
	while game.shelves.move_t[0] < 0.6:
		await process_frame
	await shot("2_closing")
	while game.shelves.move_t[0] >= 0.0 and game.shelves.move_t[0] < Shelves.WARN + Shelves.MOVE * 0.8:
		await process_frame
	game.focusing = true
	bot.focus = true
	await frames(30)
	await shot("3_carried")
	bot.focus = false
	await frames(5)
	game.focusing = false
	# a proofreader at work
	for b in game.bullets.list:
		b.state = Bullets.FADE
	game.player.pos = Vector2(960, 860)
	game.bullets.fire(game.player.pos, Vector2(0.3, -1).normalized())
	await frames(30)
	var w = game.enemies.spawn(Enemies.PROOFREADER, Vector2(1180, 140))
	w.state = Enemies.ALIVE
	var t := 0
	while game.enemies.fixes.is_empty() and t < 600:
		t += 1
		await process_frame
	await frames(24)
	await shot("4_corrected")
	w.state = Enemies.DEAD
	for wl in Lore.walls(8):
		game.lore.hold["w8_%s" % wl[0]] = 9.0
	await frames(40)
	await shot("5_remnants")
	game.dev_jump(Waves.BOSS)
	while game.boss.state != Archivist.RUN:
		await process_frame
	var bs = game.boss
	game.player.pos = Vector2(700, 760)
	while bs.mode != Archivist.MARK or bs.mode_t < 0.75:
		await process_frame
	await shot("6_marked")
	while bs.mode != Archivist.OPEN or bs.mode_t < 0.6:
		await process_frame
	game.player.pos = Vector2(500, 600)
	await shot("7_open")
	bs.guard_t = 0.0
	bs.core_open = 1.0
	bs.damage(bs.HP * 0.36 * Loadout.boss_hp(), false, bs.core_pos(), Vector2.UP)
	# the second phase: a cross through you, then the stamp while the drawer is open
	game.player.pos = Vector2(1500, 900)
	while bs.mode != Archivist.MARK or bs.mode_t < 0.8:
		await process_frame
	await shot("7b_cross")
	while bs.stamps.is_empty() or bs.stamps[0].t < 0.6:
		game.player.pos = Vector2(1500, 300)
		await process_frame
	await shot("7c_stamp")
	bs.guard_t = 0.0
	bs.mode = Archivist.OPEN
	bs.drawer_k = 1.0
	bs.core_open = 1.0
	bs.damage(bs.HP * 0.36 * Loadout.boss_hp(), false, bs.core_pos(), Vector2.UP)
	while bs.struck < Archivist.FILE_N - 1:
		await process_frame
	await frames(30)
	await shot("8_file")
	bs.guard_t = 0.0
	bs.mode = Archivist.OPEN
	bs.drawer_k = 1.0
	bs.core_open = 1.0
	bs.damage(bs.HP * Loadout.boss_hp(), false, bs.core_pos(), Vector2.UP)
	while bs.dead_t < 3.4:
		await process_frame
	await shot("9_restored")
	quit()
