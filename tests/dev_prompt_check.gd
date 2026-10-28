extends SceneTree
# Headless: ~ opens the passcode box, a wrong code is refused, 111 opens developer
# mode for the session, then ~ toggles it directly; in a run the box freezes time.

var title
var game
var frame := 0
var fails := 0


func _initialize() -> void:
	Meta.test_mode = true
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title


func _key(code: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = down
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
		14:
			_ok(title.has_node("DevPrompt"), "~ opens the passcode box on the title")
			_ok(not Meta.dev_unlock, "not unlocked yet")
			for k in [KEY_2, KEY_2, KEY_ENTER]:
				_key(k)
		24:
			_ok(title.has_node("DevPrompt") and not Meta.dev_unlock, "wrong code refused, box stays")
			for k in [KEY_1, KEY_1, KEY_1, KEY_ENTER]:
				_key(k)
		80:
			_ok(Meta.dev_unlock and Meta.dev_auth, "111 opens developer mode")
			_ok(not title.has_node("DevPrompt") and is_instance_valid(title.dev_panel), "box closes, the dev panel opens")
			title.dev_action("unlock", null)
			_ok(not Meta.dev_unlock, "panel toggle switches unlock-all off")
			_key(KEY_QUOTELEFT)
		84:
			_ok(not title.has_node("DevPrompt") and title.dev_panel == null, "after the code, ~ hides the panel without asking again")
			Meta.dev_auth = false
			Meta.dev_unlock = false
			title.queue_free()
			game = load("res://scenes/main.tscn").instantiate()
			root.add_child(game)
			current_scene = game
		100:
			_key(KEY_QUOTELEFT)
		104:
			_ok(game.has_node("DevPrompt") and Engine.time_scale < 0.001, "in a run ~ opens the box and the run stands still")
			_key(KEY_ESCAPE)
		140:
			_ok(not game.has_node("DevPrompt") and Engine.time_scale == 1.0 and not game.dev, "Esc cancels and time runs again")
			_key(KEY_QUOTELEFT)
		144:
			for k in [KEY_1, KEY_KP_1, KEY_1, KEY_KP_ENTER]:
				_key(k)
		200:
			_ok(game.dev and Engine.time_scale == 1.0 and is_instance_valid(game.dev_panel), "111 in a run opens the dev panel")
			game.dev_action("god", null)
			game.dev_action("speed", 3)
			game.dev_action("sch:split", null)
			_ok(game.dev_god and is_equal_approx(Engine.time_scale, 2.0) and game.lv.split == 1, "panel actions: invulnerable, ×2, split +1")
			game.dev_action("close", null)
			_ok(not game.dev and game.dev_panel == null and is_equal_approx(Engine.time_scale, 1.0), "close button ends developer mode")
			print("DEV PROMPT CHECK " + ("PASS" if fails == 0 else "FAIL"))
			return true
	return false
