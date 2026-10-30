extends SceneTree

const Cap = preload("res://tests/cap.gd")
var title

func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	# (long enough for the panel's rows to finish coming in)
	for i in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, path)

func run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Settings.loaded = true
	Settings.assist = false
	Settings.fullscreen = false
	Settings.lang = "zh"
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	title.t = 8.0
	title._go("settings")
	title.page_t = 8.0
	await shot("res://proofs/assist-settings.png")
	title.sel.settings = title.SETTINGS.find("assist")
	title._set_change(1)
	await shot("res://proofs/assist-zh-off.png")
	title.assist_panel.close()
	await process_frame
	Settings.assist = true
	Txt.zh = false
	title._set_change(1)
	await shot("res://proofs/assist-en-on.png")
	title.assist_panel.close()
	title.queue_free()
	await process_frame
	Txt.zh = true
	var game = load("res://scenes/main.tscn").instantiate()
	game.bot = {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
	root.add_child(game)
	game.paused = true
	game.hud.paused = true
	game.hud.pause_open()
	for i in 50:
		await process_frame
	await shot("res://proofs/assist-pause.png")
	game._pause_choice("assist")
	await shot("res://proofs/assist-pause-panel.png")
	game.assist_panel.close()
	await process_frame
	print("ASSIST SHOTS PASS")
	quit()
