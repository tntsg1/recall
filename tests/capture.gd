extends SceneTree
# Off-screen footage for the website and trailer (Movie Maker, no window focus).
# Usage: tools/run_test.sh tests/capture.gd --write-movie <out.avi> --fixed-fps 60 -- <ch 1-5> <boss|wave> <seconds> [max]

var game
var brain
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var frame := 0
var secs := 10.0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Meta.test_mode = true
	var a := OS.get_cmdline_user_args()
	var ch := int(a[0]) if a.size() > 0 else 1
	var boss := a.size() > 1 and a[1] == "boss"
	secs = float(a[2]) if a.size() > 2 else 10.0
	seed(77 + ch)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	brain = preload("res://tests/brain.gd").new(bot)
	await process_frame
	for i in ch - 1:
		game.next_chapter()
	game.lv = {"bounce": 2, "split": 2, "orbit": 1, "magnet": 1, "blast": 1, "charge": 0, "shadow": 1, "chain": 1, "possess": 0} if "max" in a else {"bounce": 1, "split": 1, "orbit": 0, "magnet": 0, "blast": 0, "charge": 0, "shadow": 0, "chain": 0, "possess": 0}
	game.hud.hint_a = 0.0
	if boss:
		game.wave_ctl.index = Waves.BOSS - 1
		game.wave_ctl.phase = Waves.CLEAR
		game.wave_ctl.pick_state = 2
		game.wave_ctl.t = 10.0


func _process(_dt: float) -> bool:
	frame += 1
	if game == null or not game.is_inside_tree():
		return false
	game.hud.hint_a = 0.0
	brain.think(game)
	return frame > int(secs * 60.0)
