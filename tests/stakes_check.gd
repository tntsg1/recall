extends SceneTree
# Headless: the eight stakes, the dodge trails and the red card.
# Run: Godot --headless --path . -s tests/stakes_check.gd --fixed-fps 60
#  1. enemy health: the stake's share, and each chapter from the seventh
#  2. boss health, elites and specials arrive on their stakes
#  3. red mends one crack between chapters, the others two
#  4. a trail opens with the stake below it, and a locked one is never worn
#  5. the flowing trail never turns red, and no trail is red
#  6. the last card appears on red only
#  7. a first finish names what it opened

var game
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false, "possess": false}
var fails: Array[String] = []


func _initialize() -> void:
	Meta.test_mode = true
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func elites_in(plan: Dictionary) -> int:
	var n := 0
	for g in plan.groups:
		if g.size() > 4 and g[4]:
			n += 1
	return n


func chasers_in(plan: Dictionary) -> int:
	var n := 0
	for g in plan.groups:
		if g[1] == Enemies.CHASER:
			n += g[2]
	return n


func _run() -> void:
	await frames(5)
	var w = game.wave_ctl
	# 1
	Loadout.stake = 0
	check(is_equal_approx(Loadout.chapter_hp(5), 1.0), "the sixth chapter is unchanged")
	check(is_equal_approx(Loadout.chapter_hp(6), 1.08), "the seventh adds 8 percent")
	check(is_equal_approx(Loadout.chapter_hp(11), 1.48), "the twelfth adds 48 percent")
	var e0 = game.enemies.spawn(Enemies.CHASER, Vector2(960, 300))
	check(is_equal_approx(e0.maxhp, 30.0), "a first chapter chaser on white is untouched")
	Loadout.stake = 1
	var chapter0: int = game.chapter
	game.chapter = 11
	var e1 = game.enemies.spawn(Enemies.CHASER, Vector2(960, 300))
	check(is_equal_approx(e1.maxhp, 30.0 * 1.2 * 1.48), "stake and chapter multiply")
	game.chapter = chapter0
	game.enemies.list.clear()
	# 2
	var bosses := {0: 1.0, 4: 1.0, 5: 1.3, 6: 1.3, 7: 1.6}
	for s in bosses:
		Loadout.stake = s
		check(is_equal_approx(Loadout.boss_hp(), bosses[s]), "stake %d boss health" % s)
	var elites := {0: 0, 4: 0, 5: 1, 6: 1, 7: 2}
	for s in elites:
		Loadout.stake = s
		var ok := true
		for ch in [0, 3, 8, 11]:
			w.chapter = ch
			w.pool = Chapters.pool(ch)
			for i in 6:
				ok = ok and elites_in(w._wave_plan(i, 1.0, false)) == elites[s]
		check(ok, "stake %d: %d elites in every wave" % [s, elites[s]])
	Loadout.stake = 5
	w.chapter = 8
	w.pool = Chapters.pool(8)
	check(elites_in(w._wave_plan(4, 1.3, true)) == 2, "the harder way adds its elite to the stake's")
	var low := 0
	var high := 0
	seed(9)
	for k in 200:
		Loadout.stake = 5
		low += chasers_in(w._wave_plan(5, 1.0, false))
		Loadout.stake = 6
		high += chasers_in(w._wave_plan(5, 1.0, false))
	# (the wave itself is 20 percent bigger on ink)
	check(high < low, "ink's waves bring fewer chasers: %d against %d" % [high, low])
	Loadout.stake = 7
	w.chapter = 0
	w.pool = Chapters.pool(0)
	var first = w._wave_plan(0, 1.0, false)
	var plain := true
	for g in first.groups:
		if g.size() > 4 and g[4]:
			plain = plain and g[1] == Enemies.CHASER
	check(plain, "the first wave's elites are chasers, no shield yet")
	var red := Loadout.stake_rules(7)
	check(red.find("+60%") >= 0 and red.find("+30%") < 0 and red.find("2 个") >= 0 and red.find("1 个精英") < 0, "red's summary keeps only the final numbers")
	check(Loadout.stake_rules(0) == Loadout.stake_desc(0), "white says it is the standard")
	# 3
	for s in [0, 6, 7]:
		Loadout.stake = s
		game.max_cracks = 5
		game.cracks = 1
		game.cracks = mini(game.max_cracks, game.cracks + Loadout.mend())
		check(game.cracks == (2 if s == 7 else 3), "stake %d mends %d" % [s, 1 if s == 7 else 2])
	# 4
	Meta.test_mode = false
	var keep: Dictionary = Meta.data
	Meta.data = {"stake_won": -1, "trail": 1}
	check(Meta.trail_open(0) and not Meta.trail_open(1), "before any finish only white is open")
	check(Meta.saved_trail() == 0, "a trail not held is not worn")
	Meta.data = {"stake_won": 0, "trail": 1}
	check(Meta.trail_open(1) and not Meta.trail_open(2), "white opens the first colour")
	check(Meta.saved_trail() == 1, "a held trail is worn")
	Meta.data = {"stake_won": 7}
	check(Meta.trail_open(8), "red opens the flow")
	Meta.data = keep
	Meta.test_mode = true
	check(Loadout.TRAILS.size() == Loadout.STAKES.size() + 1, "one colour for each stake, and white")
	# 5
	for i in Loadout.TRAILS.size() - 1:
		var c: Color = Loadout.TRAILS[i][2]
		check(i == 0 or (c.h > 0.08 and c.h < 0.94), "%s is not red" % Loadout.TRAILS[i][1])
	var flow_ok := true
	for k in 400:
		var c := Loadout.trail_color(8, 1.0, 1.0, k * 0.1)
		flow_ok = flow_ok and c.h > 0.08 and c.h < 0.94
	check(flow_ok, "the flow stays out of red")
	# 6
	Loadout.stake = 6
	game.ending.start(Vector2(960, 540))
	check(not game.ending.keys.has("end_6"), "ink ends as before")
	Loadout.stake = 7
	game.ending.start(Vector2(960, 540))
	check(game.ending.keys[-1] == "end_6", "red earns the last card")
	check(Txt.S.has("end_6"), "the last card has words")
	game.ending.state = Ending.OFF
	var light := Fonts.get_font("Light")
	for zh in [true, false]:
		Txt.zh = zh
		for k in Ending.CARD_KEYS + ["end_2", "end_4", "end_6"]:
			if Txt.S.has(k):
				for ln in game.ending._lines(Txt.t(k), light, 30):
					check(light.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x < 1800.0, "%s fits (%s)" % [k, "zh" if zh else "en"])
	Txt.zh = true
	# 7
	game.run_opened = 3
	Loadout.stake = 0
	check(Txt.t("r_trail") % Loadout.trail_name(4) != "", "the finish can name a trail")
	Loadout.stake = 0
	if fails.is_empty():
		print("STAKES PASS")
	else:
		print("STAKES FAIL ", fails)
	quit()
