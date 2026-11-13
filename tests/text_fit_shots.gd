extends SceneTree
# Stills to check the rewritten text fits (off-screen): every chapter's wall
# remnants awake in its hand-made room, a long chapter line in the broadcast
# band, long cards, a long seized memory; in Chinese and in English.
# -> proofs/textfit/*.png
# Usage: tools/run_test.sh tests/text_fit_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var lang := "zh"


func _initialize() -> void:
	Meta.test_mode = true
	seed(5)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lang="):
			lang = a.substr(5)
	Txt.zh = lang == "zh"
	RoomGen.force_off = true
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/textfit"))
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
	Cap.save(root, "res://proofs/textfit/%s_%s.png" % [lang, name])
	print(name, " saved")


func _run() -> void:
	await frames(2)
	game.dev_god = true
	var last_story := 0
	while true:
		var st := Chapters.story(game.chapter)
		if st != last_story:
			last_story = st
			await frames(30)
			game.hud.intro_t = -1.0
			game.hud.radio_t = -1.0
			for e in game.enemies.list:
				e.state = Enemies.DEAD
			game.wave_ctl.queue.clear()
			for w in Lore.walls(st):
				game.lore.hold["w%d_%s" % [st, w[0]]] = 99.0
			await frames(60)
			await shot("walls_%02d" % st)
			if st == 9:
				# the long chapter line, spoken in the band
				game.hud.radio(Chapters.sub(game.chapter), Chapters.label(game.chapter))
				await frames(int(60 * 5.0))
				await shot("sub_band_9")
		if st >= 12:
			break
		game.next_chapter()
	# the longest cards
	game.offers = [{"type": "school", "id": "split", "level": 0}, {"type": "relic", "id": "overkill"}, {"type": "relic", "id": "echo"}]
	game.picking = true
	game.hud.show_cards(game.offers)
	await frames(70)
	await shot("cards")
	quit()
