extends SceneTree
# Headless: drive developer mode with synthetic key presses and check each switch.

var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var fails := 0


func _initialize() -> void:
	Meta.dev_auth = true   # the passcode box is checked in dev_prompt_check
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _key(code: int, ctrl := false) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = down
		ev.ctrl_pressed = ctrl
		Input.parse_input_event(ev)


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		10:
			_key(KEY_QUOTELEFT)
		12:
			_ok(game.dev, "backtick turns dev on")
			_key(KEY_B)
		14:
			_ok(game.wave_ctl.index == Waves.BOSS and game.wave_ctl.phase == Waves.TITLE, "B jumps to the boss title")
		260:
			_ok(game.boss.state == Boss.RUN or game.boss.state == Boss.ENTER, "train is running")
		400:
			for i in 4:
				game.boss.guard_t = 0.0
				game.boss.dev_strike()
		402:
			_ok(game.boss.state == Boss.DYING or game.boss.state == Boss.DEAD, "K strikes down the boss (state %d)" % game.boss.state)
		420:
			_key(KEY_PAGEDOWN)
		422:
			_ok(game.wave_ctl.index == Waves.BOSS - 1 and game.boss.state == Boss.OFF, "PgDn goes back a wave and resets the train")
			_key(KEY_1, true)
			_key(KEY_2, true)
			_key(KEY_2, true)
		424:
			_ok(game.lv.bounce == 1 and game.lv.split == 2, "Ctrl+1/2 raise levels")
			_key(KEY_G)
			_key(KEY_I)
			_key(KEY_BRACKETRIGHT)
		426:
			_ok(game.dev_god and game.dev_ammo, "G and I toggle")
			_ok(is_equal_approx(Engine.time_scale, 2.0), "] doubles time")
			_key(KEY_Z)
		428:
			_ok(game.enemies.list.size() > 0, "Z spawns a chaser")
			_ok(not game.on_player_hit(Vector2.RIGHT, null), "god mode ignores hits")
			_key(KEY_QUOTELEFT)
		430:
			_ok(not game.dev and is_equal_approx(Engine.time_scale, 1.0), "backtick off restores time")
			print("DEV CHECK ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
			return true
	return false
