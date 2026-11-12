extends SceneTree
# A movie of rides between chapters for the user to watch: each leg from the
# end of its chapter (the map) through the ride (the bot shooting what climbs
# aboard, recalling now and then) into the next chapter's opening.
# Usage: tools/run_test.sh tests/transit_movie.gd --write-movie <out.avi> --fixed-fps 60 -- legs=1,2,7,11

var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(1300, 540), "fire": false, "focus": false, "dash": false, "possess": false}
var legs: Array = []
var li := 0
var f := 0
var after := -1


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	seed(21)
	Txt.zh = true
	Transit.force = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("legs="):
			for s in a.substr(5).split(","):
				legs.append(int(s))
	if legs.is_empty():
		legs = [1, 2, 7, 11]
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game


func _process(_dt: float) -> bool:
	f += 1
	var tr: Transit = game.transit
	if li >= legs.size():
		return true
	if f == 20:
		var leg: int = legs[li]
		while Chapters.story(game.chapter) < leg:
			game.next_chapter()
		var w: Waves = game.wave_ctl
		w.index = Waves.BOSS
		w.phase = Waves.CLEAR
		w.pick_state = 2
		w.t = 3.0
		game.picking = false
		game.hud.cards_t = -1.0
		game.hud.intro_t = -1.0
		after = -1
	if f > 20:
		_play(f)
		if tr.state == Transit.OFF and after < 0 and f > 40:
			after = f
		# the next chapter's title plays out, then on to the next leg
		if after > 0 and f - after > 150:
			li += 1
			f = 0
	return false


# The bot: drift about the deck, shoot the nearest thing aboard, recall it home now and then.
func _play(frame: int) -> void:
	var p: Vector2 = game.player.pos
	var best = null
	var bd := 1e9
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE and e.pos.distance_to(p) < bd:
			bd = e.pos.distance_to(p)
			best = e
	var cycle := frame % 150
	bot.fire = best != null and cycle < 95
	bot.focus = cycle >= 105 and cycle < 135
	bot.aim = best.pos if best != null else p + Vector2(300, 0)
	bot.move = Vector2(sin(frame * 0.021), cos(frame * 0.017) * 0.6) * 0.8
