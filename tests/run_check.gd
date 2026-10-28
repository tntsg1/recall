extends SceneTree
# Headless: the run rules — replacing a relic, dropping a new card, items,
# cracks running out, and that test runs never write the meta save.

var game
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var fails := 0


func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_dt: float) -> bool:
	frame += 1
	if frame != 5:
		return frame > 10
	var meta_existed := FileAccess.file_exists(Meta.PATH)
	var meta_before := FileAccess.get_file_as_string(Meta.PATH) if meta_existed else ""
	# five relics, then a sixth must ask for a swap
	for id in ["whet", "quick", "deepmag", "chain", "reaper"]:
		game._gain_relic(id)
	_ok(game.mag == 30 and game.ammo == 30, "Deep Magazine adds six rounds")
	game.picking = true
	game.offers = [{"type": "relic", "id": "zeroblade"}]
	game.choose(0)
	_ok(not game.replacing.is_empty(), "a sixth relic asks which to give up")
	game.replace_slot(2)
	_ok(game.relics.size() == 5 and game.relics.has("zeroblade") and not game.relics.has("deepmag") and game.mag == 24, "swap drops Deep Magazine and the extra rounds")
	game.picking = true
	game.offers = [{"type": "relic", "id": "gravity"}]
	game.choose(0)
	game.replace_slot(-1)
	_ok(not game.relics.has("gravity") and game.replacing.is_empty(), "keeping mine drops the new card")
	# items
	game.cracks = 3
	game.picking = true
	game.offers = [{"type": "item", "id": "patch"}]
	game.choose(0)
	_ok(game.cracks == 4, "Patch mends a crack")
	game.picking = true
	game.offers = [{"type": "item", "id": "overload"}]
	game.choose(0)
	_ok(game.armed.overload, "Overload waits for the next recall")
	game.pass_hits = 0
	game.pass_overload = true
	_ok(is_equal_approx(game.ret_mult(), 3.0 * 1.0 * 1.0), "Overload triples a recall (chain / zero edge at 0 pierces)")
	game.pass_overload = false
	game.pass_hits = 10
	_ok(game.ret_mult() > 1.6 * 2.0, "Chain and Zero Edge grow with pierces (%.2f)" % game.ret_mult())
	# cracks run out
	game.wave_ctl.phase = Waves.FIGHT
	for i in 6:
		game.player.invuln = 0.0
		game.on_player_hit(Vector2.RIGHT, null)
	_ok(game.lost and game.cracks <= 0, "five hits end the run")
	var meta_after := FileAccess.get_file_as_string(Meta.PATH) if FileAccess.file_exists(Meta.PATH) else ""
	_ok(meta_after == meta_before, "test runs leave the meta save alone")
	print("RUN CHECK ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	return false
