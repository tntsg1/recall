extends SceneTree
# Bestiary stills: every enemy kind alone in the room centre, one calm still
# and one while it winds up / attacks. -> proofs/bestiary/<nn>_<kind>.png
# plus proofs/bestiary/shots.json (kind, file, enemy position) for the sheet.
# Usage: tools/run_test.sh tests/bestiary_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const OUT := "res://proofs/bestiary/"
var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var log: Array = []
# kind, name, frames before the "attack" still, player offset from the enemy
const KINDS := [
	["CHASER", 40, Vector2(300, 0)], ["GUARD", 40, Vector2(300, 0)], ["CHARGER", 45, Vector2(300, 0)],
	["PRISM", 40, Vector2(300, 0)], ["LEECH", 40, Vector2(300, 0)], ["PULSE", 40, Vector2(300, 0)],
	["ECHO", 60, Vector2(300, 0)], ["INSPECTOR", 40, Vector2(300, 0)], ["PROOFREADER", 40, Vector2(300, 0)],
	["ESCORT", 30, Vector2(300, 0)], ["PHASE", 60, Vector2(300, 0)],
	["COUPLER", 90, Vector2(0, 0)], ["SIGNAL", 70, Vector2(300, 0)], ["QUEUE", 70, Vector2(300, 0)],
	["REGISTRAR", 100, Vector2(150, 0)], ["TURNSTILE", 50, Vector2(250, 0)], ["HOUND", 110, Vector2(250, 0)],
	["DUD", 60, Vector2(70, 0)], ["BYSTANDER", 30, Vector2(300, 0)],
	["HOPPER", 150, Vector2(300, 0)], ["FORKLIFT", 60, Vector2(0, 260)], ["SLED", 90, Vector2(0, 300)],
	["CONSIST", 60, Vector2(300, 300)], ["PANTO", 150, Vector2(0, 300)], ["SURGE", 60, Vector2(300, 0)],
	["CABLER", 120, Vector2(300, 0)],
	["SUBWOOFER", 70, Vector2(300, 0)], ["CHOIR", 60, Vector2(200, 0)], ["FORGER", 60, Vector2(300, 0)],
	["REDACTOR", 80, Vector2(450, 0)], ["DRIFTER", 60, Vector2(300, 0)], ["BOOTMAN", 60, Vector2(300, 0)],
	["TANK", 40, Vector2(300, 0)],
]


func _initialize() -> void:
	Meta.test_mode = true
	seed(21)
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String, kind: String, pos: Vector2, tag: String) -> void:
	game.hud.flashes.clear()
	await process_frame
	await RenderingServer.frame_post_draw
	Cap.save(root, OUT + name + ".png")
	print("POS ", kind, pos)
	log.append({"kind": kind, "file": name + ".png", "x": pos.x, "y": pos.y, "tag": tag})


func clear() -> void:
	game.wave_ctl.queue.clear()
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	game.enemies.zones.clear()


func put(kind: int, at: Vector2):
	var e = game.enemies.spawn(kind, at, 0.0)
	e.state = Enemies.ALIVE
	return e


func _run() -> void:
	await frames(2)
	game.dev_god = true
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	game.hud.intro_t = -1.0
	game.hud.radio_t = -1.0
	game.hud.visible = false
	var c: Vector2 = Arena.ROOM.get_center()
	var i := 0
	for spec in KINDS:
		i += 1
		var kn: String = spec[0]
		var kind: int = load("res://scripts/enemies.gd").get_script_constant_map()[kn]
		clear()
		await frames(3)
		game.wave_ctl.phase = Waves.FIGHT
		var far := Vector2(Arena.ROOM.end.x - 90, Arena.ROOM.end.y - 90)
		game.player.pos = far
		var e = put(kind, c + Vector2(260, 0) if kind == Enemies.BYSTANDER else c)
		if kind == Enemies.BYSTANDER:
			e.aim_at = c + Vector2(-700, 0)
		var extra: Array = []
		if kind == Enemies.BYSTANDER:
			var dm = put(Enemies.GUARD, far + Vector2(-60, -60))
			dm.hp = 9999.0
			dm.maxhp = 9999.0
		if kind == Enemies.COUPLER:
			var b = put(kind, c + Vector2(0, 210))
			e.link = b
			b.link = e
			b.seed = e.seed + 1.0
			extra.append(b)
		elif kind == Enemies.CHOIR:
			var mem: Array = [e]
			for j in 3:
				var m = put(kind, c + Vector2.from_angle((j + 1) * PI * 0.5) * 48.0)
				mem.append(m)
				extra.append(m)
			game.enemies.form_choir(mem)
		elif kind == Enemies.CONSIST:
			var ahead2 = e
			for j in 3:
				var car = put(Enemies.CAR, c + Vector2(-40 - 36 * j, 0))
				car.link = ahead2
				ahead2 = car
				extra.append(car)
		elif kind == Enemies.QUEUE:
			var ahead = e
			for j in 4:
				var sg = put(Enemies.QSEG, c + Vector2(-30 - 24 * j, 0))
				sg.link = ahead
				ahead = sg
				extra.append(sg)
		for k in 6:
			game.hud.flashes.clear()
			await frames(1)
		game.wave_ctl.phase = Waves.FIGHT
		await shot("%02d_%s_a" % [i, kn], kn, e.pos, "idle")
		# the attack still: bring the player near
		var po: Vector2 = spec[2]
		if po != Vector2.ZERO:
			game.player.pos = e.pos + po
		else:
			game.player.pos = c + Vector2(110, 105)
		for k in int(spec[1]):
			game.wave_ctl.phase = Waves.FIGHT
			game.hud.flashes.clear()
			e.hp = maxf(e.hp, 20.0)
			await frames(1)
		var mid: Vector2 = e.pos
		if kind == Enemies.COUPLER or kind == Enemies.QUEUE:
			mid = (e.pos + extra[0].pos) * 0.5 if kind == Enemies.COUPLER else e.pos + Vector2(-40, 0)
		await shot("%02d_%s_b" % [i, kn], kn, mid, "attack")
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "shots.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(log))
	f.close()
	print("bestiary ok")
	quit()
