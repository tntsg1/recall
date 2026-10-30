extends SceneTree
# Stills of the room-to-room chapter (off-screen): the first room out of the
# sealed lab, enemies through the spawn gates, a cleared room with two ways
# on, the slide between rooms, the next room, a spread of generated rooms of
# every shape, the elite of the harder way, and the walk into the boss's room.
# -> proofs/rooms/*.png (chapter 1) or proofs/rooms/chN_*.png
# Usage: tools/run_test.sh tests/rooms_shots.gd --fixed-fps 60 -- [story=N]

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var story := 1
var prefix := ""


func _initialize() -> void:
	Meta.test_mode = true
	Meta.next_seed = 424242
	for a in OS.get_cmdline_user_args():
		if a.begins_with("story="):
			story = int(a.substr(6))
	prefix = "" if story == 1 else "ch%d_" % story
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
	Cap.save(root, "res://proofs/rooms/%s%s.png" % [prefix, name])
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
	while Chapters.story(game.chapter) < story:
		game.next_chapter()
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
	# a room holding as many of the chapter's remnants as fit, every one woken
	if story >= 5:
		for id in game.rooms.homes:
			game.rooms.homes[id] = 2
		var best_n := -1
		var best_seed := 52000
		for k3 in 240:
			# (a room that can't fit one hands it on to the next: put them all back)
			for id in game.rooms.homes:
				game.rooms.homes[id] = 2
			game.rooms.cseed = 52000 + k3
			game.rooms.build(2, ["L", "R", "T", "B"][k3 % 4], false)
			var sp: Dictionary = game.rooms.lay.get("spots", {})
			var nsp := sp.size() + (2 if sp.has("yellow") else 0)
			if story != 5 and sp.size() >= 3:
				best_n = nsp
				best_seed = k3
				break
			if nsp > best_n:
				best_n = nsp
				best_seed = k3
			if sp.has("yellow") and sp.size() >= 3:
				break
		for id in game.rooms.homes:
			game.rooms.homes[id] = 2
		game.rooms.cseed = 52000 + best_seed
		game.rooms.build(2, ["L", "R", "T", "B"][best_seed % 4], false)
		print("remnants in the room: ", game.rooms.lay.get("spots", {}).keys())
		game.player.pos = game.rooms.start_pos()
		for w in Lore.walls(story):
			game.lore.hold["w%d_%s" % [story, w[0]]] = 9.0
		await frames(50)
		await shot("08_remnants")
	# the core's columns at work: one powering up, its cables reaching your rounds in the walls
	if story == 12 and game.nodes.active():
		game.rooms.cseed = 121000
		game.rooms.build(3, "L", false)
		game.wave_ctl.phase = Waves.FIGHT
		var nc: Vector2 = game.nodes.nodes[0]
		game.player.pos = nc + Vector2(-260, 120)
		if not Arena.ROOM.grow(-60).has_point(game.player.pos):
			game.player.pos = nc + Vector2(260, 120)
		for j12 in 5:
			game.bullets.fire(game.player.pos, Vector2.from_angle(j12 * TAU / 5.0 + 0.3))
		await frames(60)
		game.nodes.clock = 999.0
		for k12 in 80:
			await frames(1)
			if game.nodes.live >= 0 and game.nodes.live_t >= ControlNodes.WARN + 0.5:
				break
		await shot("08_node_take")
	# the institute's fields at work: rounds flown into a held field stop in mid-air
	if story == 11 and game.stasis.active():
		game.rooms.cseed = 111000
		game.rooms.build(3, "L", false)
		game.wave_ctl.phase = Waves.FIGHT
		var fc: Vector2 = game.stasis.fields[0]
		game.stasis.clock = Stasis.WARN * 0.5
		await frames(2)
		await shot("08_field_warn")
		game.stasis.clock = Stasis.WARN + 0.3
		game.player.pos = fc + Vector2(-Stasis.R - 200.0, 40.0)
		if not Arena.ROOM.grow(-60).has_point(game.player.pos):
			game.player.pos = fc + Vector2(Stasis.R + 200.0, 40.0)
		await frames(12)
		for j11 in 4:
			game.bullets.fire(game.player.pos, (fc - game.player.pos).normalized().rotated((j11 - 1.5) * 0.12))
			await frames(4)
		await frames(30)
		await shot("08_field_hold")
	# the shipyard's plates at work: one thrown into an enemy
	if story == 10 and game.plates.active():
		game.rooms.cseed = 101000
		game.rooms.build(3, "L", false)
		game.wave_ctl.phase = Waves.FIGHT
		var pc: Vector2 = game.plates.pos[0]
		var foe10 = game.enemies.spawn(Enemies.GUARD, pc + Vector2(220, 0))
		foe10.state = Enemies.ALIVE
		foe10.t = 1.0
		game.player.pos = pc + Vector2(-260, 60)
		for j10 in 3:
			game.bullets.fire(game.player.pos, (pc - game.player.pos).normalized().rotated((j10 - 1) * 0.05))
		await frames(12)
		await shot("08_plate_shove")
		game.plates.vel[0] = Vector2(Plates.MAX_SPEED, 0)
		for k10 in 60:
			foe10.pos = pc + Vector2(220, 0) if foe10.flash <= 0.0 else foe10.pos
			await frames(1)
			if foe10.flash > 0.0:
				break
		await frames(3)
		await shot("08_plate_ram")
	# the lift's airlock at work: a door marked, then open, the air rushing to it
	if story == 9 and game.vents.active():
		game.rooms.cseed = 91000
		game.rooms.build(3, "L", false)
		game.wave_ctl.phase = Waves.FIGHT
		var dv: Array = game.vents.doors[0]
		var at9: Vector2 = (dv[0] as Vector2) + (dv[1] as Vector2) * 330.0
		game.player.pos = at9 + Vector2(0, 140)
		for j9 in 3:
			var fe = game.enemies.spawn(Enemies.CHASER, at9 + Vector2(-60 + j9 * 60, -40))
			fe.state = Enemies.ALIVE
			fe.t = 1.0
		for j9 in 3:
			game.bullets.fire(game.player.pos, Vector2.from_angle(-PI * 0.5 + (j9 - 1) * 0.3))
		game.vents.clock = 0.0
		game.vents.door = 0
		game.vents.door_t = Vents.WARN * 0.6
		await frames(2)
		await shot("08_vent_warn")
		game.vents.door_t = Vents.WARN + 0.2
		await frames(40)
		await shot("08_vent_open")
	# the archive's shelving at work: an aisle marked to close with you in it, then shut
	if story == 8 and game.shelves.active():
		game.rooms.cseed = 81000
		game.rooms.build(3, "L", false)
		game.wave_ctl.phase = Waves.FIGHT
		game.dev_god = false
		game.player.invuln = 0.0
		game.fx.numbers.clear()
		var g8: int = game.shelves.aisle[0]
		if g8 <= 0 or g8 >= Shelves.N:
			game.shelves.set_banks(game.shelves.banks)
			g8 = game.shelves.aisle[0]
		var lo8: float = game.shelves.xs[g8 - 1] + Shelves.W
		var hi8: float = game.shelves.xs[g8]
		var in_aisle := Vector2((lo8 + hi8) * 0.5, game.shelves.top_of(0) + Shelves.H * 0.4)
		var foe8 = game.enemies.spawn(Enemies.GUARD, in_aisle + Vector2(0, 110))
		foe8.state = Enemies.ALIVE
		foe8.t = 1.0
		game.shelves.clock[0] = Shelves.PERIOD - 0.02
		var c8: int = game.cracks
		var warned := false
		for k8 in 400:
			game.player.pos = in_aisle
			await frames(1)
			if not warned and game.shelves.move_t[0] >= Shelves.WARN * 0.6:
				warned = true
				await shot("08_shelf_warn")
			if game.cracks < c8:
				break
		await frames(10)
		await shot("08_shelf_crush")
		# and an enemy caught in an aisle as it shuts, you standing clear
		game.player.pos = Vector2(game.shelves.xs[0] - 160.0, game.shelves.top_of(0) - 120.0)
		var g9: int = game.shelves.aisle[0]
		if g9 <= 0 or g9 >= Shelves.N:
			game.shelves.set_banks(game.shelves.banks)
			g9 = game.shelves.aisle[0]
		var mid9 := Vector2((game.shelves.xs[g9 - 1] + Shelves.W + game.shelves.xs[g9]) * 0.5, game.shelves.top_of(0) + Shelves.H * 0.5)
		var foe9 = game.enemies.spawn(Enemies.GUARD, mid9)
		foe9.state = Enemies.ALIVE
		foe9.t = 1.0
		game.shelves.clock[0] = Shelves.PERIOD - 0.02
		var hp9: float = foe9.hp
		for k9 in 400:
			if foe9.hp >= hp9:
				foe9.pos = mid9
			game.player.pos = Vector2(game.shelves.xs[0] - 160.0, game.shelves.top_of(0) - 120.0)
			await frames(1)
			if foe9.hp < hp9:
				break
		await frames(4)
		await shot("08_shelf_crush_foe")
		game.dev_god = true
	# the bureau of thought's rings at work: standing in one as it lights
	if story == 7 and game.scan_rings.active():
		game.rooms.cseed = 71000
		game.rooms.build(3, "L", false)
		game.wave_ctl.phase = Waves.FIGHT
		game.dev_god = false
		game.player.invuln = 0.0
		var ring: Vector2 = game.scan_rings.spots[0]
		game.player.pos = ring + Vector2(20, 10)
		game.fx.numbers.clear()
		var c0: int = game.cracks
		for k6 in 240:
			await frames(1)
			game.player.pos = ring + Vector2(20, 10)
			if game.cracks < c0:
				break
		await frames(2)
		await shot("08_ring_hit")
		game.dev_god = true
	# the bureau's current at work: rounds in the walls arced together, an enemy crossing an arc
	if story == 6:
		game.rooms.cseed = 61000
		game.rooms.build(3, "L", false)
		# four rounds a step apart down the right-hand wall: the current chains them
		game.wave_ctl.phase = Waves.FIGHT
		for j in 4:
			game.player.pos = Vector2(1760, 360 + j * 110)
			game.bullets.fire(game.player.pos, Vector2.RIGHT)
			await frames(4)
		game.player.pos = Vector2(1300, 860)
		await frames(40)
		await shot("08_arcs")
		var foe = game.enemies.spawn(Enemies.CHASER, Vector2(1790, 300))
		foe.state = Enemies.ALIVE
		foe.t = 1.0
		for k5 in 40:
			await frames(1)
			if foe.flash > 0.0:
				break
		await shot("08_arc_cut")
	# the line's guide rails at work: a round crossing a powered rail turns along it
	if story == 5 and game.maglev.active():
		game.rooms.cseed = 41000
		game.rooms.build(3, "L", false)
		var rl: Array = game.maglev.rails[0]
		var mid: Vector2 = ((rl[0] as Vector2) + (rl[1] as Vector2)) * 0.5
		var along: Vector2 = ((rl[1] as Vector2) - (rl[0] as Vector2)).normalized()
		var side: Vector2 = along.orthogonal()
		game.player.pos = (mid + side * 260.0).clamp(Arena.ROOM.position + Vector2(60, 60), Arena.ROOM.end - Vector2(60, 60))
		game.wave_ctl.phase = Waves.FIGHT
		game.maglev.t = 0.5 - float(rl[2]) * Maglev.PERIOD * 0.5 + Maglev.PERIOD
		await frames(6)
		for j in 3:
			game.bullets.fire(game.player.pos, ((mid + along * (j - 1) * 70.0) - game.player.pos).normalized())
			await frames(4)
		await frames(10)
		await shot("08_rail_bend")
	# the production floor's arms at work: marking, sweeping, plucking rounds
	if story == 4 and game.arms.active():
		game.rooms.cseed = 31000
		game.rooms.build(3, "L", false)
		game.player.pos = game.rooms.start_pos()
		var arm: Dictionary = game.arms.arms[0]
		var base: Vector2 = arm.base
		var face: Vector2 = arm.face
		game.player.pos = (base + face * 420.0).clamp(Arena.ROOM.position + Vector2(60, 60), Arena.ROOM.end - Vector2(60, 60))
		var tan := Vector2(face.y, -face.x)
		for j in 6:
			game.bullets.fire(game.player.pos, ((base + tan * (j - 2.5) * 70.0) - game.player.pos).normalized())
			await frames(3)
		await frames(40)
		game.wave_ctl.phase = Waves.FIGHT
		arm.mode = Arms.RISE
		arm.t = 0.0
		await frames(30)
		await shot("08_arm_mark")
		while arm.mode != Arms.SWEEP:
			await frames(1)
		await frames(20)
		await shot("08_arm_sweep")
		await frames(14)
		await shot("08_arm_pluck")
	# freight of every kind: a room holding a forced-open crate and a tarp
	for k2 in 400:
		game.rooms.cseed = 20000 + k2
		game.rooms.build(2, "L", false)
		var ks: Array = game.rooms.lay.get("kinds", [])
		if story != 1 or (ks.has("open") and ks.has("tarp")):
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
