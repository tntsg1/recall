extends SceneTree
# Logic check (headless): rounds are conserved through fire, embed, recall,
# expiry and regen; the magazine ends full. Prints PASS / FAIL.

var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 100), "fire": false, "focus": false, "dash": false}
var bad := 0


func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	if "max" in OS.get_cmdline_user_args():
		game.lv = {"bounce": 3, "split": 3, "orbit": 3, "magnet": 3, "blast": 3, "charge": 0, "shadow": 0, "chain": 0, "possess": 0}


var ch3_done := false


func _total() -> int:
	return game.ammo + game.bullets.originals_alive() + game.regen.size()


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2 and "ch3" in OS.get_cmdline_user_args() and not ch3_done:
		ch3_done = true
		game.next_chapter()
		game.next_chapter()
		game.dev_jump(1)
	var t := frame / 60.0
	bot.fire = t > 0.5 and t < 3.5 or (t > 8.0 and t < 9.0)
	bot.aim = game.player.pos + Vector2.from_angle(-PI / 2.0 + sin(t * 3.0) * 1.2) * 300.0
	bot.focus = t > 5.0 and t < 5.6
	if frame > 5 and _total() != 24:
		bad += 1
		if bad < 4:
			print("mismatch at ", t, ": ammo ", game.ammo, " live ", game.bullets.list.size(), " regen ", game.regen.size())
	if t > 7.0 and t < 7.02 and game.ammo != 24 and not "max" in OS.get_cmdline_user_args() and not "ch3" in OS.get_cmdline_user_args():
		print("FAIL not full after recall: ", game.ammo)
		for b in game.bullets.list:
			if not b.child:
				print("  state ", b.state, " pos ", b.pos, " t ", b.t)
		bad += 1
	if frame >= 60 * 26:
		# the second burst expired after 12 s and regenerated
		# in the Maw rounds may still be in a leech's grip; only conservation counts there
		var ok: bool = bad == 0 and (game.ammo == 24 or "ch3" in OS.get_cmdline_user_args())
		print("PASS" if ok else "FAIL", " ammo ", game.ammo, " mismatches ", bad)
		return true
	return false
