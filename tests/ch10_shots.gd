extends SceneTree
# Stills of chapter 10 (off-screen): the yard at the opening, a plate shoved
# by rounds, a plate yanked by a recall into a chaser, escorts round a guard
# taking a returning round, every remnant awake, the Peace being welded, its
# turrets in the second stage, the bow gun's test in the last.
# -> proofs/lore/ch10_*.png
# Usage: tools/run_test.sh tests/ch10_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(10)
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
	Cap.save(root, "res://proofs/lore/ch10_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 10:
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
	var anchor = game.enemies.spawn(Enemies.GUARD, Vector2(1700, 980))
	anchor.state = Enemies.ALIVE
	anchor.hp = 1e9
	await frames(150)
	# rounds into the left plate: it drifts off
	game.player.pos = Vector2(760, 650)
	for k in 4:
		game.bullets.fire(game.player.pos, Vector2.from_angle(PI + (k - 1.5) * 0.02))
	await frames(16)
	await shot("2_shoved")
	# a chaser between; recall: the plate is yanked back through it
	var c = game.enemies.spawn(Enemies.CHASER, Vector2(640, 600))
	c.state = Enemies.ALIVE
	c.hp = 1e9
	game.player.pos = Vector2(1100, 590)
	game.bullets.recall(game.player.pos)
	await frames(14)
	await shot("3_yanked")
	c.state = Enemies.DEAD
	await frames(30)
	# escorts round a guard; a round home through it
	var g = game.enemies.spawn(Enemies.GUARD, Vector2(1300, 760))
	g.state = Enemies.ALIVE
	g.hp = 1e9
	for k in 3:
		var x = game.enemies.spawn(Enemies.ESCORT, Vector2(1300, 760) + Vector2.from_angle(k * 2.1) * 60.0)
		x.state = Enemies.ALIVE
		x.hp = 1e9
	game.player.pos = Vector2(1000, 760)
	await frames(60)
	game.bullets.fire(game.player.pos, Vector2(1, 0.05).normalized())
	await frames(30)
	game.player.pos = Vector2(1000, 760)
	game.bullets.recall(game.player.pos)
	var wt := 0
	var flashed := false
	while wt < 90 and not flashed:
		wt += 1
		await process_frame
		for e in game.enemies.list:
			if e.kind == Enemies.ESCORT and e.shield_flash > 0.6:
				flashed = true
	await shot("4_escort")
	for e in game.enemies.list:
		if e != anchor:
			e.state = Enemies.DEAD
	for w in Lore.walls(10):
		game.lore.hold["w10_%s" % w[0]] = 9.0
	await frames(40)
	await shot("5_remnants")
	game.dev_jump(Waves.BOSS)
	while game.boss.state != Peace.RUN:
		await process_frame
	var bs = game.boss
	game.player.pos = Vector2(960, 760)
	await frames(150)
	await shot("6_welding")
	bs.guard_t = 0.0
	bs.damage(bs.HP * 0.36 * Loadout.boss_hp(), false, bs.core_pos(), Vector2.UP)
	var t := 0
	while t < 600 and not (bs.turret_aim[0] > 0.3 or bs.turret_aim[1] > 0.3):
		t += 1
		await process_frame
	await shot("7_turrets")
	await frames(30)
	bs.guard_t = 0.0
	bs.damage(bs.HP * 0.36 * Loadout.boss_hp(), false, bs.core_pos(), Vector2.UP)
	bs.gun_cd = 0.2
	while bs.gun_t < Peace.GUN_WARN * 0.8:
		await process_frame
	await shot("8_gun")
	while bs.gun_t < Peace.GUN_WARN + 0.05:
		game.player.pos = Vector2(1500, 860)
		await process_frame
	await shot("8b_gun_fire")
	quit()
