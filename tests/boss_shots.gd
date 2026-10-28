extends SceneTree
# A few stills of the train fight (off-screen window, no video):
# title, entrance, open core, armour break, reversing, death, final card.
# Usage: tools/run_test.sh tests/boss_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")

var game
var brain
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var frame := 0
var taken := {}
var dir := "res://proofs/m4"
var last_phase := 0
var break_at := -1
var end_at := -1


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	seed(7)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	brain = preload("res://tests/brain.gd").new(bot)


func _shot(key: String) -> void:
	if taken.has(key):
		return
	taken[key] = true
	Cap.save(root, dir + "/" + key + ".png")


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		game.wave_ctl.index = Waves.BOSS - 1
		game.wave_ctl.phase = Waves.CLEAR
		game.wave_ctl.pick_state = 2
		game.wave_ctl.t = 10.0
		game.lv = {"bounce": 1, "split": 2, "orbit": 2, "magnet": 0, "blast": 0, "charge": 0, "shadow": 0, "chain": 0, "possess": 0}
	if frame < 3:
		return false
	brain.think(game)
	var b = game.boss
	var hud = game.hud
	if hud.title_t > 1.0 and hud.title_i == Waves.BOSS:
		_shot("1_title")
	if b.state == Boss.ENTER and b.car_s(3) > 20.0:
		_shot("2_enter")
	if b.state == Boss.RUN and b.core_open > 0.95 and b.t > 4.0:
		_shot("3_core_open")
	if b.phase != last_phase:
		last_phase = b.phase
		break_at = frame + 6
	if frame == break_at:
		_shot("4_break_%d" % b.phase)
	if b.state == Boss.RUN and b.reverse_t > 1.0 and b.reverse_t < 1.05:
		_shot("5_reverse")
	if b.state == Boss.DYING and b.dying_t > 0.7:
		_shot("6_dying")
	if b.state == Boss.DEAD and game.victory_slow > 0.6:
		_shot("7_dead")
	if game.wave_ctl.phase == Waves.DONE and end_at < 0:
		end_at = frame
	if end_at > 0 and frame == end_at + 150:
		_shot("8_final")
		return true
	return frame > 60 * 200
