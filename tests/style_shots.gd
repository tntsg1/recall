extends SceneTree
# The same frozen moment drawn in each seize style, tiled 2×2:
# top-left pixel (current) · top-right A dotted · bottom-left B vector · bottom-right C glitch.
# Two scenes: a seized chaser just after a drill dash, and a seized guard among marked foes.
# -> proofs/possess/style_compare_1.png, style_compare_2.png
# Usage: tools/run_test.sh tests/style_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(1500, 540), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.pressed = true
	game._unhandled_input(ev)


func grab() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://_style_tmp.png"
	Cap.save(root, path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return img


func compare(center: Vector2, name: String) -> void:
	# freeze the world, then redraw the same moment in each style
	game.paused = true
	var canvas: Vector2 = game.get_viewport().get_canvas_transform() * center
	var w := 900
	var h := 500
	var rect := Rect2i(int(clampf(canvas.x - w / 2.0, 0, 1920 - w)), int(clampf(canvas.y - h / 2.0, 0, 1080 - h)), w, h)
	var out := Image.create(w * 2 + 10, h * 2 + 10, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.3, 0.3, 0.3))
	var i := 0
	for st in Possess.STYLES:
		game.possess.style = st
		game.possess.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if st in ["pixel", "invade"] else CanvasItem.TEXTURE_FILTER_LINEAR
		game.possess.queue_redraw()
		var img := await grab()
		img.convert(Image.FORMAT_RGBA8)
		out.blit_rect(img, rect, Vector2i((i % 2) * (w + 10), (i / 2) * (h + 10)))
		i += 1
	out.save_png("res://proofs/possess/%s.png" % name)
	print(name, " saved")
	game.paused = false
	game.possess.style = "pixel"


func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/possess"))
	Meta.possess_trial = true
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	await frames(60 * 5)
	game.player.pos = Vector2(700, 540)
	await frames(2)
	# 1) chaser just after a dash: afterimages, spikes, time ring
	key(KEY_1)
	await frames(40)
	bot.aim = game.player.pos + Vector2(600, -60)
	bot.fire = true
	await frames(2)
	bot.fire = false
	await frames(9)
	await compare(game.possess.shell.pos + Vector2(80, 0), "style_compare_1")
	# 2) back in your own body: marked foes and the E key
	key(KEY_E)
	await frames(80)
	for e in game.enemies.list:
		if e.state == Enemies.ALIVE and e.pos.distance_to(game.player.pos) < 700.0:
			game.possess.mark(e)
	await frames(30)
	await compare(game.player.pos + Vector2(250, 0), "style_compare_2")
	# 3) a guard just as its spikes finish growing (C glitches here), shield raised
	key(KEY_3)
	await frames(40)
	game.possess.grow = 0.85     # mid-growth: C breaks into glitch blocks here
	await compare(game.possess.shell.pos + Vector2(120, 0), "style_compare_3")
	quit(0)
