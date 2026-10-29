extends SceneTree
# Headless: the bot plays chapter 1's six waves, room to room (or in the
# hand-made room, "hand"), always taking the plain way on, and prints each
# wave's time and hits; at the end the mean per wave. The rooms must come
# within 20% of the hand-made room's times. Also flags a wave or a walk to
# the door that never ends.
# Usage: $G --headless --path . -s tests/rooms_bot.gd --fixed-fps 60 -- [runs] [hand]

var game
var brain
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "plain": true}
var runs := 3
var run := 0
var all: Array = []
var hits: Array = []
var last_hits := 0
var stall := 0
var story := 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	RoomGen.force_off = "hand" in args
	for a in args:
		if a.begins_with("story="):
			story = int(a.substr(6))
	_start()


func _start() -> void:
	if game:
		game.queue_free()
	seed(300 + run)
	Meta.next_seed = 5000 + run
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	brain = preload("res://tests/brain.gd").new(bot)
	while Chapters.story(game.chapter) < story:
		game.next_chapter()
	frame = 0
	hits = []
	last_hits = 0
	stall = 0


func _process(_dt: float) -> bool:
	frame += 1
	if game == null or not game.is_inside_tree():
		return false
	brain.think(game)
	var w = game.wave_ctl
	if w.results.size() > hits.size():
		hits.append(game.hits_taken - last_hits)
		last_hits = game.hits_taken
	if game.rooms.open:
		stall += 1
		if stall == 60 * 25:
			print("  STUCK AT THE DOOR room %d pos %s exits %s" % [game.rooms.room_index, str(game.player.pos), str(game.rooms.lay.exits)])
	else:
		stall = 0
	if w.phase == Waves.FIGHT and w.t > 120.0 and frame % 600 == 0:
		print("  LONG WAVE w%d t=%.0f remaining=%d shape=%s" % [w.index + 1, w.t, game.enemies.remaining(), game.rooms.lay.get("shape", "hand")])
		if w.t < 132.0:
			print("    player %s walls %s" % [str(game.player.pos), str(game.arena.walls)])
			for e in game.enemies.list:
				if e.state != Enemies.DEAD:
					print("    enemy kind=%d state=%d pos=%s free=%s" % [e.kind, e.state, str(e.pos), str(game.arena.is_free(e.pos, e.r))])
					for r: Rect2 in game.arena.inner + game.arena.movers + game.arena.soft:
						if r.grow(e.r).has_point(e.pos):
							print("      inside %s (r %.0f)" % [str(r), e.r])
	if w.index >= Waves.BOSS or game.lost or frame > 60 * 60 * 15 or stall > 60 * 30 or (w.phase == Waves.FIGHT and w.t > 140.0):
		var line := "RUN %d %s:" % [run, "LOST" if game.lost else ("OK" if w.index >= Waves.BOSS else "TIMEOUT")]
		for i in w.results.size():
			line += "  w%d %.1fs h%d" % [i + 1, w.results[i][0], hits[i] if i < hits.size() else -1]
		print(line)
		all.append(w.results.duplicate())
		run += 1
		if run >= runs:
			var means := ""
			var tot := 0.0
			for i in 6:
				var s := 0.0
				var n := 0
				for r in all:
					if i < r.size():
						s += r[i][0]
						n += 1
				means += "  w%d %.1f" % [i + 1, s / maxf(1, n)]
				tot += s / maxf(1, n)
			print("MEAN%s  total %.1f" % [means, tot])
			quit()
			return true
		_start()
	return false
