extends SceneTree
# Headless: a run snapshot taken in chapter 2, wave 4 brings a fresh game back to
# the start of that wave with relics, levels, cracks and stats intact; the cloud
# merge keeps whichever run was written last.

var a
var b
var frame := 0
var fails := 0
var snap := {}
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}


func _initialize() -> void:
	Meta.test_mode = true
	a = load("res://scenes/main.tscn").instantiate()
	a.bot = bot
	root.add_child(a)


func _ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c:
		fails += 1


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		5:
			a.next_chapter()
			a.dev_jump(3)
			a.dev_action("relic", null)
			a.dev_action("relic", null)
			a.lv.split = 2
			a.lv.chain = 1
			a.cracks = 3
			a.kills = 77
		40:
			snap = JSON.parse_string(JSON.stringify(a.run_snapshot()))   # as it travels through the save
			_ok(int(snap.chapter) == 1 and int(snap.wave) == 3, "snapshot: chapter 2, wave 4")
			a.queue_free()
			Meta.resume = snap
			b = load("res://scenes/main.tscn").instantiate()
			b.bot = bot
			root.add_child(b)
		60:
			_ok(b.chapter == 1, "resumed in chapter 2")
			_ok(b.relics.size() == 2 and b.relics[0] == snap.relics[0], "relics restored")
			_ok(b.lv.split == 2 and b.lv.chain == 1, "school levels restored")
			_ok(b.cracks == 3 and b.kills == 77, "cracks and stats restored")
			_ok(Meta.resume == null, "the snapshot is used once")
		200:
			_ok(b.wave_ctl.index == 3 and b.wave_ctl.phase in [Waves.TITLE, Waves.FIGHT], "starts wave 4 again (index %d phase %d)" % [b.wave_ctl.index, b.wave_ctl.phase])
			# cloud merge: the later run wins, an ended run (null) newer than ours clears it
			Meta.data = {"runs": 1, "wins": 0, "best_chapter": 0, "best_wave": 0, "best_time": 0.0, "kills": 0, "ach": {}, "unlocks": {}, "stake_won": -1, "gun_wins": {}, "beat": 0, "crit": 0, "cross": 0, "run": {"chapter": 0, "wave": 2}, "run_at": 100}
			Meta.merge({"run": {"chapter": 3, "wave": 1}, "run_at": 200})
			_ok(int(Meta.data.run.chapter) == 3, "newer cloud run replaces ours")
			Meta.merge({"run": {"chapter": 0, "wave": 0}, "run_at": 150})
			_ok(int(Meta.data.run.chapter) == 3, "older cloud run is ignored")
			Meta.merge({"run": null, "run_at": 300})
			_ok(Meta.data.run == null, "a run that ended elsewhere clears ours")
			print("RESUME CHECK " + ("PASS" if fails == 0 else "FAIL"))
			return true
	return false
