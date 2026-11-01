extends SceneTree
# Stills of the rank cards (off-screen): an upgrade offer, ranked slots, the school swap, the S count.
# Usage: tools/run_test.sh tests/stars_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(9)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/stars"))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/stars/%s.png" % name)
	print(name, " saved")


func _run() -> void:
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.dev_god = true
	for id in ["whet", "critical", "brace", "deepmag", "fortress"]:
		game._gain_relic(id)
	game._star_up("whet")
	game._star_up("whet")
	game._star_up("critical")
	game.lv.bounce = 3
	game.lv.blast = 2
	game.lv.split = 1
	game.lv.magnet = 1
	game.offers = [{"type": "relic", "id": "critical", "star": 3}, {"type": "relic", "id": "deepmag", "star": 2}, {"type": "school", "id": "orbit", "level": 0, "full": true}]
	game.picking = true
	game.hud.show_cards(game.offers)
	await frames(70)
	await shot("1_upgrade_cards")
	game.picking = false
	game.hud.cards_t = -1.0
	game.hud.cards.clear()
	game.replacing = {"type": "school", "id": "orbit", "level": 0, "full": true}
	game.hud.show_replace(game.replacing)
	await frames(40)
	await shot("2_school_swap")
	game.replacing = {"type": "relic", "id": "gravity"}
	game.hud.show_replace(game.replacing)
	await frames(40)
	game.replace_key(0)
	await frames(10)
	await shot("2b_relic_swap")
	game.replacing = {}
	game.hud.replace_done()
	game.s_count = 1
	game.on_wave_clear(0, 10.0, "S")
	await frames(30)
	await shot("3_s_count")
	await frames(150)
	game.on_wave_clear(0, 10.0, "S")
	await frames(30)
	await shot("4_s_bonus")
	await frames(150)
	bot.aim = game.hud._relic_slot_i(0, Vector2(1920, 1080))
	await frames(40)
	await shot("5_slots_tip")
	bot.aim = Vector2(960, 300)
	game.extra_pick = true
	game.offers = [{"type": "relic", "id": "reaper"}, {"type": "school", "id": "bounce", "level": 0}, {"type": "item", "id": "ward"}]
	game.picking = true
	game.hud.show_cards(game.offers)
	await frames(70)
	await shot("6_extra_pick")
	quit()
