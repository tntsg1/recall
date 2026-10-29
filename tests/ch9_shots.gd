extends SceneTree
# Stills of chapter 9 (off-screen): the lift car at the opening, a door being
# marked, a door open with the rounds gathered at it, every remnant awake,
# the counterweight's shadow swelling, the weight landed and open, the shock
# of a landing, the spare weight with it. -> proofs/lore/ch9_*.png
# Usage: tools/run_test.sh tests/ch9_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(9)
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
	Cap.save(root, "res://proofs/lore/ch9_%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 9:
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
	var anchor = game.enemies.spawn(Enemies.GUARD, Vector2(1500, 160))
	anchor.state = Enemies.ALIVE
	anchor.hp = 1e9
	await frames(150)
	# rounds into the left wall around the upper door, then the door is marked
	game.player.pos = Vector2(700, 420)
	for k in 7:
		game.bullets.fire(game.player.pos, Vector2.from_angle(PI + (k - 3) * 0.16))
	await frames(20)
	game.vents.clock = Vents.PERIOD
	game.vents.turn = 0
	while game.vents.door < 0 or game.vents.door_t < 0.8:
		game.player.pos = Vector2(700, 420)
		await process_frame
	await shot("2_marked")
	while game.vents.door_t < Vents.WARN + 1.4:
		await process_frame
	game.player.pos = Vector2(760, 600)
	game.bullets.fire(game.player.pos, Vector2(-1, -0.2).normalized())
	await frames(8)
	await shot("3_open")
	for w in Lore.walls(9):
		game.lore.hold["w9_%s" % w[0]] = 9.0
	await frames(40)
	await shot("4_remnants")
	game.dev_jump(Waves.BOSS)
	while game.boss.state != Counterweight.RUN:
		await process_frame
	var bs = game.boss
	game.player.pos = Vector2(960, 760)
	while (bs.ws[0] as Counterweight.W).mode != Counterweight.AIM or bs.ws[0].mode_t < 1.0:
		await process_frame
	await shot("5_shadow")
	while (bs.ws[0] as Counterweight.W).mode != Counterweight.DOWN or bs.ws[0].mode_t < 0.5:
		await process_frame
	game.player.pos = Vector2(960, 860)
	await shot("6_landed")
	bs.guard_t = 0.0
	bs.damage(bs.HP * 0.36 * Loadout.boss_hp(), false, bs.core_pos(), Vector2.UP)
	while (bs.ws[0] as Counterweight.W).mode != Counterweight.DOWN or bs.ws[0].mode_t < 0.35:
		await process_frame
	await shot("7_shock")
	while (bs.ws[0] as Counterweight.W).mode != Counterweight.DOWN:
		await process_frame
	await frames(20)
	bs.guard_t = 0.0
	bs.damage(bs.HP * 0.36 * Loadout.boss_hp(), false, bs.core_pos(), Vector2.UP)
	var sp: Counterweight.W = bs.ws[1]
	while sp.mode != Counterweight.AIM or sp.mode_t < 0.9:
		await process_frame
	await shot("8_spare")
	quit()
