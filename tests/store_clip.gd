extends SceneTree
# Steam trailer footage (off-screen, Movie Maker): the test bot plays a chapter
# or its boss in English; the first <warm> seconds are cut off afterwards.
# Usage: tools/run_test.sh tests/store_clip.gd --write-movie <out.avi> --fixed-fps 60 -- <ch 1-12> <wave|boss> <seconds>

var game
var brain
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var frame := 0
var secs := 10.0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Meta.test_mode = true
	var a := OS.get_cmdline_user_args()
	var ch := int(a[0]) if a.size() > 0 else 1
	var boss := a.size() > 1 and a[1] == "boss"
	secs = float(a[2]) if a.size() > 2 else 10.0
	Txt.zh = false
	seed(900 + ch * 7 + (1 if boss else 0))
	Meta.next_seed = 31337 + ch
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	current_scene = game
	brain = preload("res://tests/brain.gd").new(bot)
	_setup.call_deferred(ch, boss)


func _setup(ch: int, boss: bool) -> void:
	for i in ch - 1:
		game.next_chapter()
	game.dev_god = true
	game.lightwalk.tip_done = true
	game.lv = {"bounce": 1, "split": 1, "orbit": 1, "magnet": 0, "blast": 1, "charge": 0, "shadow": 0, "chain": 1, "possess": 1}
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
