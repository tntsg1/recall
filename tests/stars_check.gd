extends SceneTree
# Headless: relic ranks, the school swap, the cards that could do nothing, the S rank's pick.
# Run: Godot --headless --path . -s tests/stars_check.gd --fixed-fps 60
#  1. every ranked relic's description shows its number rising, in both languages
#  2. once the case is full ranks are offered; a rank needs no swap and raises the number
#  3. magazine relics pay out their rank and take it back; a save keeps ranks
#  4. a swapped-in school takes the old one's level
#  5. no card is offered that could do nothing
#  6. three S ranks bring one more pick

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


func offers_of(n: int, pred: Callable) -> int:
	var found := 0
	for i in n:
		for c in Cards.offer(game):
			if pred.call(c):
				found += 1
	return found


func _run() -> void:
	while game.wave_ctl.phase != Waves.FIGHT:
		await frames(1)
	# 1. the numbers
	var was_zh: bool = Txt.zh
	var bad: Array = []
	for id in Cards.STARS:
		if not Cards.RELICS.has(id):
			bad.append(id)
			continue
		for zh in [true, false]:
			Txt.zh = zh
			var d1 := Cards.relic_desc(id, 1)
			var s: Array = Cards.STARS[id]
			if d1.find(s[0] % Cards.num(s[1])) < 0 or d1 == Cards.relic_desc(id, 3):
				bad.append(id)
	Txt.zh = was_zh
	check(bad.is_empty(), "%d 个可升星遗物的说明都随星级变化 %s" % [Cards.STARS.size(), str(bad)])
	Txt.zh = true
	print("  例：", Cards.relic_desc("beat_heart", 3), " / ", Cards.relic_desc("zeroblade", 2))
	Txt.zh = was_zh
	# 2. offers and a rank
	check(offers_of(50, func(c): return c.has("star")) == 0, "槽未满时不出升星卡")
	for id in ["whet", "deepmag", "reserve", "brace", "fortress"]:
		game._gain_relic(id)
	var ups := offers_of(300, func(c): return c.has("star"))
	check(ups > 40, "槽满后出升星卡（300 次选卡出现 %d 张）" % ups)
	check(offers_of(200, func(c): return c.get("star", 0) > 0 and c.id == "brace") == 0, "开关型遗物不出升星卡")
	var base: float = game.out_dmg()
	var mag0: int = game.mag
	game.offers = [{"type": "relic", "id": "whet", "star": 2}]
	game.picking = true
	game.wave_ctl.pick_state = 1
	game.choose(0)
	check(game.replacing.is_empty(), "升星不需要替换")
	check(game.star("whet") == 2 and game.relics.size() == 5, "磨利弹头到 2 星，遗物数不变")
	check(is_equal_approx(game.out_dmg() / base, 1.7 / 1.5), "去程伤害按 2 星算（%.3f）" % (game.out_dmg() / base))
	game.hud.cards_t = -1.0
	game.hud.cards.clear()
	# 3. the magazine, and a save
	game._star_up("deepmag")
	game._star_up("deepmag")
	check(game.mag == mag0 + 6, "厚弹匣 3 星多给 6 发（%d）" % (game.mag - mag0))
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.run_snapshot()))
	var mag3: int = game.mag
	game._lose_relic("deepmag")
	game.relics.erase("deepmag")
	check(game.mag == mag3 - 12 and not game.stars.has("deepmag"), "失去 3 星厚弹匣时收回 12 发并清星级")
	game.relics.clear()
	game.stars.clear()
	game.mag = Loadout.mag()
	for id in snap.relics:
		game._gain_relic(id)
	var sst: Dictionary = snap.stars
	for id in sst:
		for n in int(sst[id]) - 1:
			game._star_up(id)
	check(game.mag == mag3 and game.star("deepmag") == 3 and game.star("whet") == 2, "存档读回星级和弹匣（mag %d）" % game.mag)
	# the replace page guards what was hard won
	game.relics.clear()
	game.stars.clear()
	game.relics.append("whet")
	game.stars["whet"] = 3
	game.replacing = {"type": "relic", "id": "brace"}
	game.hud.show_replace(game.replacing)
	game.replace_key(0)
	check(not game.replacing.is_empty() and game.hud.rep_armed == -1, "替换页刚打开时忽略按键")
	game.hud.rep_t = 1.0
	game.replace_key(0)
	check(game.relics.has("whet") and game.hud.rep_armed == 0, "3 星遗物第一次按键只选中")
	game.replace_key(0)
	check(game.replacing.is_empty() and game.relics.has("brace") and not game.relics.has("whet"), "第二次按键才替换")
	game.relics.clear()
	# 4. the swap
	for k in game.lv:
		game.lv[k] = 0
	game.lv.bounce = 3
	game.lv.blast = 2
	game.lv.split = 1
	game.lv.magnet = 1
	game.replacing = {"type": "school", "id": "orbit", "level": 0, "full": true}
	game.replace_slot(0)
	check(game.lv.bounce == 0 and game.lv.orbit == 3, "替换流派继承 3 级（行星轨道 Lv%d）" % game.lv.orbit)
	# 5. nothing that does nothing
	game.lv.orbit = 0
	game.relics.clear()
	game.stars.clear()
	check(offers_of(300, func(c): return c.id == "wide_ring" or c.id == "leech_ward") == 0, "没有行星轨道、第 1 章时不出宽环和护弹")
	game.lv.orbit = 1
	check(offers_of(300, func(c): return c.type == "relic" and c.id == "wide_ring") > 0, "有行星轨道时出宽环")
	game.lv.orbit = 0
	for id in ["wide_ring", "whet", "deepmag", "reserve", "fortress"]:
		game._gain_relic(id)
	check(offers_of(200, func(c): return c.get("star", 0) > 0 and c.id == "wide_ring") == 0, "没有行星轨道时不出宽环升星")
	for id in ["wide_ring", "whet", "deepmag", "reserve", "fortress"]:
		game._lose_relic(id)
	game.relics.clear()
	game.cracks = game.max_cracks
	check(offers_of(200, func(c): return c.type == "item" and (c.id == "patch" or c.id == "mend_all")) == 0, "裂痕满时不出修补")
	game.cracks = game.max_cracks - 1
	check(offers_of(300, func(c): return c.type == "item" and c.id == "patch") > 0, "有裂痕时出修补")
	check(offers_of(200, func(c): return c.type == "item" and c.id == "recall_order") == 0, "没有被偷的子弹时不出回收令")
	game.wave_ctl.index = Waves.BOSS - 1
	check(offers_of(300, func(c): return c.type == "item" and ["firststrike", "stasis", "slowfield"].has(c.id)) == 0, "下一波是 Boss 时不出只对小怪有效的道具")
	game.wave_ctl.index = 0
	check(Cards.LEGEND_LOCK == "boss_2", "传说遗物改为第 2 章 Boss 解锁")
	# 6. three S ranks
	game.rooms.bonus = 0
	game.s_count = 0
	game.on_wave_clear(0, 10.0, "S")
	game.on_wave_clear(1, 10.0, "A")
	game.on_wave_clear(1, 10.0, "S")
	check(game.rooms.bonus == 0 and game.s_count == 2, "两个 S 还没有奖励")
	game.on_wave_clear(2, 10.0, "S")
	check(game.rooms.bonus == 1, "第三个 S 多一次选卡")
	print("STARS ", "PASS" if fails.is_empty() else "FAIL %s" % str(fails))
	quit(1 if fails.size() > 0 else 0)
