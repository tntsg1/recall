extends SceneTree
# Headless: merging a cloud copy of the meta save only ever adds progress.

func _initialize() -> void:
	Meta.test_mode = true
	Meta.data = {"runs": 5, "wins": 1, "best_chapter": 2, "best_wave": 3, "best_time": 900.0, "kills": 100,
		"ach": {"a": 1}, "unlocks": {"u1": true}, "stake_won": 0, "gun_wins": {"std": 1}, "beat": 0, "crit": 2, "cross": 1}
	var cloud := {"runs": 3, "wins": 2, "best_chapter": 4, "best_wave": 0, "best_time": 800.0, "kills": 50,
		"ach": {"b": 2}, "unlocks": {"u2": true}, "stake_won": 2, "gun_wins": {"std": 0, "rail": 1}, "crit": 1}
	var fails := 0
	var changed := Meta.merge(cloud)
	var d := Meta.data
	for c in [[changed, "changed"], [d.runs == 5, "runs max"], [d.wins == 2, "wins max"], [d.best_chapter == 4 and d.best_wave == 0, "best reach"],
			[is_equal_approx(d.best_time, 800.0), "best time min"], [d.ach.has("a") and d.ach.has("b"), "ach union"],
			[d.unlocks.has("u1") and d.unlocks.has("u2"), "unlock union"], [d.stake_won == 2, "stake"], [d.gun_wins.std == 1 and d.gun_wins.rail == 1, "gun wins"],
			[d.crit == 2, "crit max"], [not Meta.merge(cloud), "second merge no-op"]]:
		print(("ok   " if c[0] else "FAIL ") + c[1])
		if not c[0]:
			fails += 1
	print("MERGE CHECK " + ("PASS" if fails == 0 else "FAIL"))
	quit(fails)
