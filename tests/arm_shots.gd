extends SceneTree
# Stills of the chapter 4 arms only (iterate on their look). Cut from ch4_shots.gd.
# Stills of chapter 4 (off-screen): the production floor at the opening, an
# arm marking and sweeping, rounds carried to the reserve crate, every remnant
# awake, a seized leech's memory, the reserve intake and its full capacity.
# -> proofs/lore/ch4_*.png
# Usage: tools/run_test.sh tests/ch4_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(4)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/arms"))
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
	Cap.save(root, "res://proofs/arms/%s.png" % name)
	print(name, " saved")


func _run() -> void:
	await frames(2)
	while Chapters.story(game.chapter) < 4:
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
	# rounds into the left wall, then the left arm marks and sweeps them off
	game.player.pos = Vector2(700, 640)
	for k in 10:
		game.bullets.fire(game.player.pos, Vector2.from_angle(PI + (k - 4.5) * 0.09))
	await frames(40)
	var arm: Dictionary = game.arms.arms[0]
	arm.mode = Arms.RISE
	arm.t = 0.0
	while arm.t < 0.8:
		await process_frame
	await shot("2_arm_mark")
	while not (arm.mode == Arms.SWEEP and arm.t > 0.45):
		await process_frame
	await shot("3_arm_sweep")
	while game.arms.carry.size() > 0:
		await process_frame
	await frames(20)
	await shot("4_crate")
	while arm.mode != Arms.REST:
		await process_frame
	await frames(30)
	await shot("5_rest")
	quit()
