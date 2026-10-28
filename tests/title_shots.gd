extends SceneTree
# Stills of the title (off-screen): the word assembling, the menu, a page in
# mid-transition, achievements, settings, then Start really opens a run with
# its slit, cards springing in and the pause menu.
# Usage: tools/run_test.sh tests/title_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var frame := 0
var title
var game


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/ui"))
	Meta.dev_unlock = true   # tests never write the player's save
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title


func _shot(n: String) -> void:
	Cap.save(root, "res://proofs/ui/%s.png" % n)


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		70:
			_shot("1_assemble")
		260:
			_shot("2_menu")
		262:
			title._move(1)
		268:
			_shot("3_highlight_moving")
		280:
			title._go("settings")
		290:
			_shot("4_page_in")
		330:
			_shot("5_settings")
			title._go("achievements")
		380:
			_shot("6_achievements")
			title._go("menu")
		420:
			title.sel["menu"] = 0
			title.gun_i = 0
			title._accept(0)
		440:
			_shot("7_start")
		560:
			game = current_scene
			print("SCENE ", game.name, " is_game=", game is Game)
		575:
			_shot("8_opening")
		620:
			game.picking = true
			game.offers = [{"type": "school", "id": "split", "level": 0}, {"type": "relic", "id": "zeroblade"}, {"type": "item", "id": "overload"}]
			game.hud.show_cards(game.offers)
		630:
			_shot("9_cards_rising")
		652:
			_shot("9b_cards_sheen")
		680:
			game.hud.reticle = Vector2(960 + 120, 540 - 60)
			_shot("10_cards")
		690:
			game.choose(1)
		700:
			_shot("11_cards_shatter")
		712:
			_shot("11b_card_flight")
		738:
			_shot("11c_slot_ring")
		745:
			game.pad_aim = true
			game.hud.fired()
			game.hud.kill_confirm(true)
		748:
			_shot("11d_reticle")
		760:
			game.paused = true
			game.hud.paused = true
			game.hud.pause_open()
		790:
			_shot("12_pause")
			return true
	return false
