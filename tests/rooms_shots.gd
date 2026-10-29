extends SceneTree
# Stills of the room-to-room chapter (off-screen): the first room out of the
# sealed lab, enemies through the spawn gates, a cleared room with two ways
# on, the slide between rooms, the next room, a spread of generated rooms of
# every shape, the elite of the harder way, and the walk into the boss's room.
# -> proofs/rooms/*.png
# Usage: tools/run_test.sh tests/rooms_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	Meta.next_seed = 424242
	seed(5)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/rooms"))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame
		if game.picking:
			bot["pick"] = 0


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/rooms/%s.png" % name)
	print(name, " saved  (room %d, %s)" % [game.rooms.room_index, game.rooms.lay.get("shape", "hand")])


func clear_wave() -> void:
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	while not game.rooms.open:
		await frames(1)


func walk_out(k: int) -> void:
	var d: Dictionary = game.rooms.lay.exits[mini(k, game.rooms.lay.exits.size() - 1)]
	while game.rooms.open_k < 0.6:
		await frames(1)
	game.player.pos = (d.pos as Vector2) + (d.n as Vector2) * 18.0


func _run() -> void:
	await frames(2)
	print("seed ", game.run_seed, " forks ", game.rooms.forks)
	game.dev_god = true
	game.lore.worker_t = 0.4
	await frames(70)
	await shot("01_first_room")
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	await frames(50)
	await shot("02_gates")
	# make this room one with two ways on
	if not game.rooms.forks.has(0):
		game.rooms.forks.append(0)
		game.rooms.build(0, "L", false)
		game.player.pos = game.rooms.start_pos()
	await clear_wave()
	await frames(50)
	await shot("03_two_ways")
	# the harder way
	var risky := 0
	for i in game.rooms.lay.exits.size():
		if game.rooms.lay.exits[i].risky:
			risky = i
	await walk_out(risky)
	await frames(10)
	await shot("04_slide_out")
	await frames(12)
	await shot("05_slide_in")
	await frames(30)
	await shot("06_next_room")
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	var elite = null
	for i in 400:
		await frames(1)
		for e in game.enemies.list:
			if e.elite and e.state == Enemies.ALIVE:
				elite = e
		if elite != null:
			break
	if elite != null:
		await frames(30)
		game.player.pos = (elite.pos + Vector2(0, 260)).clamp(Arena.ROOM.position + Vector2(40, 40), Arena.ROOM.end - Vector2(40, 40))
		await frames(4)
		await shot("07_elite")
	print("risky wave groups ", game.wave_ctl.plan[1].groups.size(), " vs plain ", game.wave_ctl._wave_plan(1, 1.0, false).groups.size())
	# a spread of rooms, one of each shape
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var seen := {}
	var k := 0
	var sides := ["T", "B", "L", "R"]
	while seen.size() < 5 and k < 60:
		k += 1
		game.rooms.cseed = 9000 + k
		game.rooms.build(1 + k % 4, sides[k % 4], false)
		var sh: String = game.rooms.lay.get("shape", "")
		if sh == "" or seen.has(sh):
			continue
		seen[sh] = true
		game.player.pos = game.rooms.start_pos()
		game.rooms.open_doors()
		await frames(50)
		await shot("08_shape_%s" % sh)
	# freight of every kind: a room holding a forced-open crate and a tarp
	for k2 in 400:
		game.rooms.cseed = 20000 + k2
		game.rooms.build(2, "L", false)
		var ks: Array = game.rooms.lay.get("kinds", [])
		if ks.has("open") and ks.has("tarp"):
			game.player.pos = game.rooms.start_pos()
			await frames(40)
			await shot("08_freight")
			break
	# the last room's way on: the boss's room
	game.rooms.build(5, "L", false)
	game.player.pos = game.rooms.start_pos()
	game.wave_ctl.index = 5
	game.wave_ctl.phase = Waves.CLEAR
	game.rooms.open_doors()
	await frames(50)
	await shot("09_to_boss")
	await walk_out(0)
	while game.wave_ctl.index != Waves.BOSS:
		await frames(1)
	await frames(100)
	await shot("10_boss_room")
	quit()
