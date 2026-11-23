extends SceneTree
# The coupled pair's new look (chapter colour, real coupler, real chain), next to
# an old chaser for scale: one pair slack, one pulled taut. -> proofs/foes/coupler_*.png
# Usage: tools/run_test.sh tests/coupler_sample_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}


func _initialize() -> void:
	Meta.test_mode = true
	seed(21)
	root.add_child(preload("res://tests/test_window.gd").new())
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func put(kind: int, at: Vector2):
	var e = game.enemies.spawn(kind, at, 0.0)
	return e


func _run() -> void:
	await frames(2)
	game.dev_god = true
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.hud.intro_t = -1.0
	game.hud.radio_t = -1.0
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	var c: Vector2 = Arena.ROOM.get_center()
	game.player.pos = c + Vector2(0, 330)
	var a = put(Enemies.COUPLER, c + Vector2(-330, -40))
	var b = put(Enemies.COUPLER, c + Vector2(-240, 10))
	a.link = b
	b.link = a
	b.seed = a.seed + 1.0
	var p = put(Enemies.COUPLER, c + Vector2(120, -60))
	var q = put(Enemies.COUPLER, c + Vector2(400, -60))
	p.link = q
	q.link = p
	q.seed = p.seed + 1.0
	var ch = put(Enemies.CHASER, c + Vector2(-40, 150))
	await frames(70)
	for i in 50:
		# hold them still so the still shows the pose, not the chase
		for e in [a, b, p, q]:
			e.vel = Vector2.ZERO
		a.pos = c + Vector2(-330, -40)
		b.pos = c + Vector2(-240, 10)
		p.pos = c + Vector2(120, -60)
		q.pos = c + Vector2(400, -60)
		ch.pos = c + Vector2(-40, 120)
		ch.vel = Vector2.ZERO
		game.player.pos = c + Vector2(0, 330)
		game.wave_ctl.phase = Waves.FIGHT
		await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/foes/coupler_sample.png")
	print("coupler sample ok")
	quit()
