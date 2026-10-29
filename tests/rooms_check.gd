extends SceneTree
# Headless: the room-to-room chapter's rules. The same seed lays out the same
# rooms; a run saved in a room comes back in that very room; the ways on open
# only once the room is clear and the pick is made; the harder way redraws
# its wave bigger with an elite and pays one more pick; walking through a door
# brings every round home; a dev jump lands in that wave's room; the boss
# keeps the hand-made room.

var fails := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _game(seed_n: int, resume = null):
	Meta.next_seed = seed_n
	Meta.resume = resume
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = bot
	root.add_child(g)
	return g


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _rects(lay: Dictionary) -> String:
	return str(lay.get("walls", [])) + str(lay.get("cover", []))


func _initialize() -> void:
	Meta.test_mode = true
	_run.call_deferred()


func _run() -> void:
	var a = _game(777)
	await frames(3)
	_ok(a.rooms.active and a.rooms.room_index == 0, "chapter 1 walks room to room (room %d)" % a.rooms.room_index)
	_ok(a.arena.is_free(a.player.pos, 16.0), "you start on open floor")
	var first := _rects(a.rooms.lay)
	var b = _game(777)
	await frames(3)
	_ok(_rects(b.rooms.lay) == first, "the same seed, the same first room")
	b.queue_free()
	var c = _game(778)
	await frames(3)
	_ok(_rects(c.rooms.lay) != first, "another seed, another room")
	c.queue_free()
	# the ways on stay shut through the fight
	while a.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	await frames(30)
	_ok(not a.rooms.open, "the ways on are shut while enemies come")
	a.wave_ctl.queue.clear()
	for e in a.enemies.list:
		e.state = Enemies.DEAD
	var opened := false
	for i in 400:
		await frames(1)
		if a.picking:
			_ok(not a.rooms.open, "still shut while the pick is up")
			a.choose(0)
		if a.rooms.open:
			opened = true
			break
	_ok(opened and a.wave_ctl.index == 0, "a cleared room opens its ways on")
	# rounds in the walls come home through the door
	a.ammo = 10
	for k in 6:
		a.bullets.fire(a.player.pos, Vector2.from_angle(k))
	a.ammo -= 6
	await frames(40)
	var before: int = a.ammo
	var d: Dictionary = a.rooms.lay.exits[0]
	while a.rooms.open_k < 0.6:
		await frames(1)
	a.player.pos = (d.pos as Vector2) + (d.n as Vector2) * 18.0
	await frames(3)
	_ok(a.rooms.sliding(), "walking into the door slides on")
	_ok(a.ammo == mini(a.mag, before + 6), "every round came home (%d -> %d)" % [before, a.ammo])
	while a.rooms.sliding():
		await frames(1)
	await frames(2)
	_ok(a.rooms.room_index == 1 and a.wave_ctl.index == 1, "the next wave, in the next room (room %d wave %d)" % [a.rooms.room_index, a.wave_ctl.index])
	_ok(a.rooms.entry_side == RoomGen.OPPOSITE[d.side], "in through the far side (%s after %s)" % [a.rooms.entry_side, d.side])
	_ok(a.arena.is_free(a.player.pos, 16.0), "stepping in on open floor")
	# the harder way
	var plain_n := 0
	for g in a.wave_ctl.plan[2].groups:
		plain_n += int(g[2])
	a.rooms.risky_now = false
	a.wave_ctl.harder(2)
	var hard_n := 0
	var elite := false
	for g in a.wave_ctl.plan[2].groups:
		hard_n += int(g[2])
		if g.size() > 4 and g[4]:
			elite = true
	_ok(hard_n > plain_n and elite, "the harder way: more of them (%d > %d) and an elite" % [hard_n, plain_n])
	a.rooms.risky_now = true
	a.on_wave_clear(1, 10.0, "A")
	_ok(a.rooms.bonus == 1, "clearing the harder way's room owes a pick")
	a.wave_ctl.pick_state = 1
	a.wave_ctl.pick_done()
	_ok(a.wave_ctl.pick_state == 0 and a.rooms.bonus == 0, "the owed pick comes straight after")
	# a hit in the harder way's room takes two cracks, elsewhere one
	a.wave_ctl.phase = Waves.FIGHT
	a.player.invuln = 0.0
	var c0: int = a.cracks
	a.on_player_hit(Vector2.UP, null)
	_ok(a.cracks == c0 - 2, "the harder way's room: a hit takes two cracks (%d -> %d)" % [c0, a.cracks])
	a.rooms.risky_now = false
	a.player.invuln = 0.0
	c0 = a.cracks
	a.on_player_hit(Vector2.UP, null)
	_ok(a.cracks == c0 - 1, "the plain way: one crack (%d -> %d)" % [c0, a.cracks])
	a.cracks = a.max_cracks
	# a run saved in room 3 comes back in room 3
	a.rooms.build(3, "T", true)
	a.player.pos = a.rooms.start_pos()
	a.wave_ctl.index = 3
	var room3 := _rects(a.rooms.lay)
	var snap: Dictionary = a.run_snapshot()
	a.queue_free()
	var r = _game(1, snap)
	await frames(300)
	_ok(r.run_seed == 777, "the seed comes back with the run")
	_ok(r.rooms.room_index == 3 and _rects(r.rooms.lay) == room3, "the saved room, as it was")
	_ok(r.rooms.risky_now, "reached the harder way, still")
	_ok(r.wave_ctl.index == 3, "and its wave (index %d)" % r.wave_ctl.index)
	# dev jumps, and the boss's room
	r.dev_jump(5)
	_ok(r.rooms.room_index == 5 and not r.rooms.lay.is_empty(), "a dev jump lands in that wave's room")
	r.dev_jump(Waves.BOSS)
	_ok(r.rooms.lay.is_empty() and not r.arena.generated, "the boss keeps the hand-made room")
	r.queue_free()
	# chapters not yet laid out fresh keep their room
	var h = _game(9)
	await frames(3)
	h.next_chapter()
	await frames(3)
	_ok(not h.rooms.active and not h.arena.generated, "chapter 2 keeps its hand-made room")
	h.queue_free()
	print("ROOMS CHECK ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails > 0 else 0)
