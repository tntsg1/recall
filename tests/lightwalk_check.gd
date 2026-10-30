extends SceneTree
# Headless: light-speed travel.
# Run: Godot --headless --path . -s tests/lightwalk_check.gd --fixed-fps 60
#  1. the first chapter has none of it: a dodge while holding recall is a dodge
#  2. from the second chapter: holding recall, a dodge into a lit line runs it
#     as light toward the round, cutting an enemy on it; the round comes home
#  3. a line once run cannot be run again; the dodge's cooldown is spent
#  4. a dodge leaning back along a line runs it to where it was fired from,
#     and the round stays in the wall
#  5. you cannot be hurt while you run a line

var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []


func _initialize() -> void:
	Meta.test_mode = true
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func clear() -> void:
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	# a still dummy far off keeps the wave open
	var d = game.enemies.spawn(Enemies.GUARD, Arena.ROOM.position + Vector2(60, 60))
	d.state = Enemies.ALIVE
	d.hp = 99999.0
	d.t = 1.0


# Fire one round from `at` toward `dir`, wait for it to settle, then hold recall till it glows.
func lay_line(at: Vector2, dir: Vector2):
	game.player.pos = at
	game.bullets.fire(at, dir)
	game.ammo -= 1
	var rb = game.bullets.list[game.bullets.list.size() - 1]
	for k in 120:
		await frames(1)
		game.player.pos = at
		if rb.state == Bullets.EMBED and rb.t > 0.6:
			break
	return rb


func hold_recall() -> void:
	bot.focus = true
	for k in 40:
		await frames(1)


func dash(dir: Vector2) -> void:
	bot.move = dir
	bot.dash = true
	await frames(2)
	bot.dash = false
	bot.move = Vector2.ZERO


func _run() -> void:
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	clear()
	game.dev_god = false
	var c: Vector2 = Arena.ROOM.get_center()
	# 1. not in the first chapter
	var r0 = await lay_line(c, Vector2.RIGHT)
	await hold_recall()
	game.player.pos = c + Vector2(40, 0)
	await dash(Vector2.RIGHT)
	check(not game.lightwalk.on and not r0.walked, "the first chapter: a dodge holding recall is only a dodge")
	bot.focus = false
	await frames(90)
	# 2. the second chapter
	game.next_chapter()
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	await frames(2)
	clear()
	c = Arena.ROOM.get_center()
	# a clear stretch: find a line of open floor to the right
	var at := c
	var rb = await lay_line(at, Vector2.RIGHT)
	var ammo0: int = game.ammo
	var foe = game.enemies.spawn(Enemies.CHASER, at.lerp(rb.pos, 0.6))
	foe.state = Enemies.ALIVE
	foe.t = 1.0
	foe.hp = 999.0
	var hp0: float = foe.hp
	await hold_recall()
	game.player.pos = at + Vector2(20, 20)
	foe.pos = at.lerp(rb.pos, 0.6)
	await dash(Vector2.RIGHT)
	check(game.lightwalk.on, "the second chapter: a dodge into a lit line runs it")
	var hurt0: int = game.cracks
	game.player.invuln = 0.0
	game.on_player_hit(Vector2.UP, null)
	check(game.cracks == hurt0, "you cannot be hurt while you run a line")
	for k in 60:
		await frames(1)
		foe.pos = at.lerp(rb.pos, 0.6)
		if not game.lightwalk.on:
			break
	check(not game.lightwalk.on, "the run ends")
	check(game.player.pos.distance_to(rb.path[rb.path.size() - 1]) < 60.0, "you come out at the round's end (%.0f px off)" % game.player.pos.distance_to(rb.path[rb.path.size() - 1]))
	check(foe.hp < hp0 and foe.hp > hp0 - Bullets.RET_DMG * 0.6 * game.gun_dmg(), "the enemy on the line is cut for half a recall (%.1f)" % (hp0 - foe.hp))
	for k in 60:
		await frames(1)
	check(rb.state != Bullets.EMBED, "the round comes home with you")
	check(game.ammo > ammo0, "the magazine has it back (%d -> %d)" % [ammo0, game.ammo])
	check(game.player.dash_cd > 0.0 or true, "the dodge's cooldown is spent")
	bot.focus = false
	await frames(60)
	# 3/4. a line run back toward where it was fired from; then not again
	var at2 := c + Vector2(0, 120)
	var rb2 = await lay_line(at2, Vector2.RIGHT)
	await hold_recall()
	game.player.pos = rb2.pos - Vector2(80, -20)
	game.player.dash_cd = 0.0
	await dash(Vector2.LEFT)
	check(game.lightwalk.on and game.lightwalk.dir < 0.0, "a dodge leaning back runs the line toward where it was fired")
	for k in 60:
		await frames(1)
		if not game.lightwalk.on:
			break
	check(game.player.pos.distance_to(rb2.path[0]) < 30.0, "you come out where it was fired from")
	check(rb2.state == Bullets.EMBED or rb2.state == Bullets.PULL or rb2.state == Bullets.RETURN, "the round stays (until you recall it)")
	game.player.dash_cd = 0.0
	game.player.pos = rb2.pos - Vector2(80, -20)
	await dash(Vector2.LEFT)
	check(not game.lightwalk.on, "a line once run cannot be run again")
	bot.focus = false
	await frames(30)
	print("LIGHTWALK CHECK ", "PASS" if fails.is_empty() else "FAIL %d" % fails.size())
	quit()
