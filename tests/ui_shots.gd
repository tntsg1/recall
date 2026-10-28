extends SceneTree
# Stills of the run UI (off-screen window, no video): chapter intro, a mixed
# card offer, the replace step, the shattered card.
# Usage: tools/run_test.sh tests/ui_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(1300, 380), "fire": false, "focus": false, "dash": false}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/m5"))
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		50:
			Cap.save(root, "res://proofs/m5/1_intro.png")
		60:
			game.wave_ctl.phase = Waves.CLEAR
			game.wave_ctl.pick_state = 1
			game.wave_ctl.index = 2
			for id in ["whet", "chain", "gravity", "critical"]:
				game._gain_relic(id)
			game.lv.bounce = 1
			game.cracks = 3
			game.picking = true
			game.offers = [{"type": "school", "id": "split", "level": 0}, {"type": "relic", "id": "zeroblade"}, {"type": "item", "id": "overload"}]
			game.hud.show_cards(game.offers)
		110:
			Cap.save(root, "res://proofs/m5/2_cards.png")
		120:
			game._gain_relic("quick")
			game.picking = true
			game.offers = [{"type": "relic", "id": "undying"}]
			game.hud.show_cards(game.offers)
			game.choose(0)
		170:
			Cap.save(root, "res://proofs/m5/3_replace.png")
			game.replace_slot(-1)
		180:
			game.wave_ctl.phase = Waves.FIGHT
			for i in 3:
				game.player.invuln = 0.0
				game.on_player_hit(Vector2.LEFT, null)
		330:
			Cap.save(root, "res://proofs/m5/4_shattered.png")
			return true
	return false
