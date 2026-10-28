extends SceneTree
# Headless: how much of their time do live enemies spend pressed to the room's edge?
# Runs chapter 1-3 waves with the bot and reports the share of enemy-frames within 40 px of the edge.

var game
var brain
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var frame := 0
var near := 0
var total := 0
var by_kind := {}
var stuck := {}       # enemy -> seconds in contact
var episodes := {}    # kind/where -> count of contacts over 1.5 s


func _initialize() -> void:
	Meta.test_mode = true
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	brain = preload("res://tests/brain.gd").new(bot)
	await process_frame
	var ch := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 1
	for i in ch - 1:
		game.next_chapter()


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 5:
		game.dev_god = true
	brain.think(game)
	var room: Rect2 = Arena.ROOM
	for e in game.enemies.list:
		if e.state != Enemies.ALIVE:
			continue
		total += 1
		var d: float = minf(minf(e.pos.x - room.position.x, room.end.x - e.pos.x), minf(e.pos.y - room.position.y, room.end.y - e.pos.y)) - e.r
		var k: String = str(e.kind)
		if not by_kind.has(k):
			by_kind[k] = [0, 0]
		by_kind[k][1] += 1
		# pressed to the room edge, or to a pillar
		var touching := d < 40.0
		for r in game.arena.rects:
			if (r as Rect2).grow(e.r + 6.0).has_point(e.pos) and Arena.ROOM.grow(-30.0).encloses(r):
				touching = true
		var where := "edge" if d < 40.0 else "pillar"
		if touching:
			near += 1
			by_kind[k][0] += 1
			stuck[e] = stuck.get(e, 0.0) + 1.0 / 60.0
			if absf(stuck[e] - 1.5) < 0.009:
				var key := k + "/" + where
				episodes[key] = episodes.get(key, 0) + 1
		else:
			stuck[e] = 0.0
	if frame > 60 * 150:
		print("WALL share %.1f%% of %d enemy-frames" % [100.0 * near / maxf(1, total), total])
		for k in by_kind:
			print("  kind %s: %.1f%% of %d" % [k, 100.0 * by_kind[k][0] / maxf(1, by_kind[k][1]), by_kind[k][1]])
		print("STUCK >1.5s: ", episodes)
		return true
	return false
