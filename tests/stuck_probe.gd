extends SceneTree
# Headless: drop a chaser and a guard where the bot found them stuck in chapter 2
# and watch whether they move toward the player.
var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var es: Array = []


func _initialize() -> void:
	Meta.test_mode = true
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 5:
		game.next_chapter()
		game.dev_god = true
	if frame == 200:
		for r in game.arena.rects:
			print("rect ", r)
		for e in game.enemies.list:
			e.state = Enemies.DEAD
		es.append(game.enemies.spawn(Enemies.CHASER, Vector2(496, 853)))
		es.append(game.enemies.spawn(Enemies.GUARD, Vector2(1432, 219)))
	if frame > 200:
		game.player.pos = Vector2(960, 540) if frame < 800 else Vector2(300, 300)
		game.wave_ctl.t = 0.0
	if frame in [260, 400, 600, 800, 1000, 1200]:
		for e in es:
			print("f%d kind=%d state=%d pos=%s vel=%s" % [frame, e.kind, e.state, str(e.pos.round()), str(e.vel.round())])
	return frame > 1200
