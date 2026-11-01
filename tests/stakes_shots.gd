extends SceneTree
# Stills (off-screen): the menu's trail row, the stake line on red in both
# languages, three trails on a dodge, the red card, a first finish.
# Usage: tools/run_test.sh tests/stakes_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const DIR := "res://proofs/stakes/%s.png"
var frame := 0
var title
var game
var step := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/stakes"))
	Meta.test_mode = true
	Meta.load_data()
	Meta.data.run = {"chapter": 2, "wave": 3, "gun": "standard", "stake": 0}
	Txt.zh = true
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title


func _shot(n: String) -> void:
	Cap.save(root, DIR % n)


func _pick(key: String) -> void:
	title.sel["menu"] = title._menu().find(key)
	title._move(0)


func _streak() -> void:
	var p: Vector2 = game.player.pos
	game.player.streak = []
	for k in 16:
		game.player.streak.append([p + Vector2(-24.0 * (16 - k), 6.0 * sin(k * 0.6)), 0.3 * (16 - k) / 16.0])


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		260:
			_pick("trail")
			title.trail_i = 1
		300:
			_shot("1_trail_row_continue")
			_pick("stake")
			Loadout.stake = 7
		340:
			_shot("2_red_zh")
			Txt.zh = false
		380:
			_shot("3_red_en")
			Txt.zh = true
			Loadout.stake = 0
			Meta.data.erase("run")
			_pick("trail")
			title.trail_i = 8
		420:
			_shot("4_trail_flow_nocontinue")
			Meta.test_mode = false
			Meta.data.stake_won = 0
			title.trail_i = 3
		460:
			_shot("5_trail_locked")
			Meta.data.stake_won = 2
			_pick("stake")
			Loadout.stake = 1
		480:
			_shot("5b_stake_finished")
			Meta.test_mode = true
			Loadout.stake = 0
			title.queue_free()
			game = load("res://scenes/main.tscn").instantiate()
			game.bot = {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
			root.add_child(game)
			current_scene = game
		560:
			Loadout.trail = 1
		562, 582, 602:
			_streak()
		564:
			_shot("6_cyan")
			Loadout.trail = 6
		584:
			_shot("7_gold")
			Loadout.trail = 8
		604:
			_shot("8_flow")
			Loadout.trail = 0
			Loadout.stake = 7
			game.ending.start(Vector2(960, 540))
			game.ending.state = Ending.CARDS
			game.ending.card = 5
			game.ending.card_t = 0.0
		650:
			_shot("9_red_card_zh")
			game.ending.card_t = 0.0
			Txt.zh = false
		696:
			_shot("10_red_card_en")
			Txt.zh = true
			game.ending.state = Ending.OFF
			game.run_opened = 0
			var rows := []
			for i in 12:
				rows.append(["第 %d 章" % (i + 1), 300.0, "S2 A3 B1"])
			game.hud.final(rows)
		920:
			_shot("11_first_finish")
			return true
	return false
