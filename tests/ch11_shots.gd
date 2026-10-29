extends SceneTree
# Stills of chapter 11 (off-screen): the institute at the opening, a pair of
# stasis fields holding rounds in mid-air, those rounds recalled from there,
# phasers solid and faint, every remnant awake, the Observed superposed, one
# collapsed, the lanes of the second stage, the mimicry of the last.
# -> proofs/lore/ch11_*.png
# Usage: tools/run_test.sh tests/ch11_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(11)
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
	Cap.save(root, "res://proofs/lore/ch11_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 11:
		game.next_chapter()
	await frames(80)
	game.player.pos = Vector2(960, 640)
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
	await frames(60)
	# the side pair holding: a fan of rounds into the left field
	game.stasis.clock = Stasis.WARN + 0.3
	await frames(20)
	game.player.pos = Vector2(820, 620)
	for k in 6:
		game.bullets.fire(game.player.pos, Vector2.from_angle(PI + (k - 2.5) * 0.12))
		await frames(3)
	var c = game.enemies.spawn(Enemies.CHASER, Vector2(500, 560))
	c.state = Enemies.ALIVE
	c.hp = 1e9
	await frames(30)
	await shot("2_held")
	game.player.pos = Vector2(1000, 760)
	game.bullets.recall(game.player.pos)
	await frames(6)
	await shot("3_recalled")
	c.state = Enemies.DEAD
	await frames(60)
	# phasers: one solid, one faint; a round through the faint one
	var ph1 = game.enemies.spawn(Enemies.PHASE, Vector2(1250, 760))
	ph1.state = Enemies.ALIVE
	ph1.hp = 1e9
	var ph2 = game.enemies.spawn(Enemies.PHASE, Vector2(1300, 880))
	ph2.state = Enemies.ALIVE
	ph2.hp = 1e9
	ph2.mode = 1
	ph2.mode_t = 0.4
	game.player.pos = Vector2(1000, 880)
	await frames(10)
	game.bullets.fire(game.player.pos, (ph2.pos - game.player.pos).normalized())
	await frames(4)
	await shot("4_phase")
	for e in game.enemies.list:
		if e != anchor:
			e.state = Enemies.DEAD
	for w in Lore.walls(11):
		game.lore.hold["w11_%s" % w[0]] = 9.0
	await frames(40)
	await shot("5_remnants")
	game.dev_jump(Waves.BOSS)
	while game.boss.state != Observed.RUN:
		await process_frame
	var bs = game.boss
	game.player.pos = Vector2(960, 900)
	await frames(90)
	await shot("6_superposed")
	bs._collapse()
	await frames(8)
	await shot("7_collapsed")
	bs.guard_t = 0.0
	bs.damage(bs.HP * 0.36 * Loadout.boss_hp(), false, bs.core_pos(), Vector2.UP)
	await frames(60)
	bs.lane_cd = 0.01
	await frames(36)
	await shot("8_lanes")
	bs.guard_t = 0.0
	bs.collapsed = 0.1
	bs.damage(bs.HP * 0.36 * Loadout.boss_hp(), false, bs.core_pos(), Vector2.UP)
	await frames(60)
	bs.mimic_cd = 0.01
	while bs.mimic_at < Observed.MIMIC_RECALL - 0.5:
		await process_frame
	await shot("9_mimic")
	quit()
