extends SceneTree
# Records the bot playing all six waves with upgrade picks (proofs/m3_run.mp4)
# and saves stills: titles, shields, chargers, a hit, stamps, the cards
# (flip-in and the chosen one flying home), split storms, the orbit ring, the final card.
# Usage: tools/run_test.sh tests/run_movie.gd --fixed-fps 60 -- [out.mp4] [shots_dir]

const Rec = preload("res://tests/rec.gd")
const Cap = preload("res://tests/cap.gd")

var game
var rec
var brain
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var out := "res://proofs/m3_run.mp4"
var dir := "res://proofs/m3"
const ORDER := ["split", "orbit", "bounce", "split", "orbit"]
var picks := 0
var taken := {}
var forced := false
var end_frame := -1


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		dir = args[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	seed(101)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	brain = preload("res://tests/brain.gd").new(bot)
	rec = Rec.new()
	root.add_child(rec)


func _shot(key: String) -> void:
	if taken.has(key):
		return
	taken[key] = true
	Cap.save(root, dir + "/" + key + ".png")


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		rec.start(out, 60)
	brain.think(game)
	# deterministic picks so the record shows every school
	if game.picking and bot.has("pick_wait") and bot["pick_wait"] <= 1:
		bot.erase("pick_wait")
		bot["pick"] = max(0, game.offers.find(ORDER[picks % ORDER.size()]))
		picks += 1
	var cards_t: float = game.hud.cards_t
	if cards_t > 0.62 and cards_t < 0.66:
		_shot("cards_%d" % picks)
	if game.hud.chosen >= 0 and game.hud.chosen_t > 0.32 and game.hud.chosen_t < 0.36:
		_shot("chosen_%d" % picks)
	if game.bullets.list.size() > 120:
		_shot("storm_w%d" % (game.wave_ctl.index + 1))
	if game.bullets.orbit_count() >= 6:
		_shot("orbit_w%d" % (game.wave_ctl.index + 1))
	var w = game.wave_ctl
	var hud = game.hud
	if hud.title_t > 0.7 and hud.title_t < 0.75:
		_shot("title_%d" % (hud.title_i + 1))
	if hud.stamp_t > 0.3 and hud.stamp_t < 0.34:
		_shot("stamp_%d" % w.index)
	for e in game.enemies.list:
		if e.kind == Enemies.GUARD and e.shield_flash > 0.9:
			_shot("shield")
		if e.kind == Enemies.CHARGER and e.mode == Enemies.WINDUP and e.mode_t > 0.6:
			_shot("charger_windup")
	if game.focusing and game.focus > 0.9:
		_shot("focus_w%d" % (w.index + 1))
	if game.pass_active and game.pass_hits >= 4:
		_shot("recall_w%d" % (w.index + 1))
	# stage one hit so the +5 s flight is on record
	if not forced and w.index == 1 and w.phase == Waves.FIGHT and w.t > 3.0:
		forced = true
		game.on_player_hit(Vector2.RIGHT, null)
	if forced and not taken.has("hit") and hud.pens.size() > 0 and hud.pens[0][1] > 0.25:
		_shot("hit")
	if w.phase == Waves.DONE and end_frame < 0:
		end_frame = frame
	if end_frame > 0 and frame == end_frame + 150:
		_shot("final")
	if frame > 1:
		rec.grab()
	if (end_frame > 0 and frame >= end_frame + 200) or frame > 60 * 60 * 5:
		rec.finish()
		var line := "RESULT"
		for i in w.results.size():
			line += "  w%d %.1fs %s" % [i + 1, w.results[i][0], w.results[i][1]]
		print(line, "  hits ", game.hits_taken)
		return true
	return false
