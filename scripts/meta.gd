class_name Meta
# What survives between runs (user://recall_meta.json): runs played, best
# reach and times, kills, achievements, unlocks (guns, stakes, pool content)
# and running counters. Test runs (a bot is driving) never touch the file.

const PATH := "user://recall_meta.json"

static var data := {}
static var test_mode := false
static var dev_unlock := false   # developer mode from the title: everything open, nothing saved
static var dev_auth := false     # the passcode was entered this session (DevPrompt)
static var resume = null         # a run snapshot the next game should continue from
static var training_requested := 0 # 1: before new run; 2: replay from title
static var training_active := false
static var possess_trial := false  # the title's "seize trial": an endless practice room


# Started by a test script (-s / --script)? Then the game reads and writes a
# sandbox file instead of the player's, so no test can ever touch a real save,
# whatever it sets or whichever scene resets test_mode on the way. The sandbox
# starts empty each time a test process first touches it.
static var _sandbox_fresh := false


static func under_test() -> bool:
	for a in OS.get_cmdline_args():
		if a == "-s" or a == "--script" or a.begins_with("res://tests/") or a.begins_with("tests/"):
			return true
	return false


static func path() -> String:
	if not under_test():
		return PATH
	var p := "user://recall_meta.test.json"
	if not _sandbox_fresh:
		_sandbox_fresh = true
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	return p

static func needs_tutorial() -> bool:
	var d := load_data()
	return not bool(d.get("tutorial_seen", false)) and int(d.runs) == 0 and run_saved() == null

static func finish_tutorial(completed: bool) -> void:
	var d := load_data()
	d.tutorial_seen = true
	d.tutorial_completed = bool(d.get("tutorial_completed", false)) or completed
	save()


static func load_data() -> Dictionary:
	if not data.is_empty():
		return data
	data = {"runs": 0, "wins": 0, "best_chapter": 0, "best_wave": 0, "best_time": 0.0, "kills": 0,
		"ach": {}, "unlocks": {}, "lore": {}, "stake_won": -1, "gun_wins": {}, "beat": 0, "crit": 0, "cross": 0}
	if FileAccess.file_exists(path()):
		var f := FileAccess.open(path(), FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for k in parsed:
				data[k] = parsed[k]
	return data


static func save() -> void:
	if test_mode or dev_unlock:
		return
	var d := load_data()
	d.saved_at = int(Time.get_unix_time_from_system())
	var text := JSON.stringify(d, "\t")
	# keep the previous file as a rolling backup before writing the new one
	if FileAccess.file_exists(path()):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path()), ProjectSettings.globalize_path(path() + ".bak"))
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
	var sh = shell()
	if sh:
		var summary := {"runs": int(d.runs), "wins": int(d.wins), "ach": d.ach.size(), "best": int(d.best_chapter) + 1}
		sh.saved(text, int(d.saved_at), JSON.stringify(summary))


# ---------------------------------------------------------------- browser
# In the browser the page around the game (RecallShell) uploads every save to
# the player's account and hands back the cloud copy. Progress here is only
# ever gained, so the two copies are merged rather than one replacing the other.

static var _shell = null
static var _shell_checked := false
static var cloud_seq := 0


static func shell():
	if not _shell_checked:
		_shell_checked = true
		if OS.has_feature("web"):
			_shell = JavaScriptBridge.get_interface("RecallShell")
	return _shell


# Called every frame on the title: takes in a cloud copy when one arrives.
static func poll_cloud() -> bool:
	var sh = shell()
	if sh == null:
		return false
	var seq := int(sh.cloudSeq)
	if seq == cloud_seq:
		return false
	cloud_seq = seq
	var parsed = JSON.parse_string(str(sh.cloudText()))
	if not parsed is Dictionary:
		return false
	if merge(parsed):
		save()
		return true
	return false


static func merge(o: Dictionary) -> bool:
	var d := load_data()
	var before := JSON.stringify(d)
	for k in ["tutorial_seen", "tutorial_completed"]:
		if bool(o.get(k, false)):
			d[k] = true
	for k in ["runs", "wins", "kills", "beat", "crit", "cross", "stake_won"]:
		if o.has(k):
			d[k] = maxi(int(d.get(k, 0)), int(o[k]))
	if int(o.get("best_chapter", 0)) * 100 + int(o.get("best_wave", 0)) > int(d.best_chapter) * 100 + int(d.best_wave):
		d.best_chapter = int(o.best_chapter)
		d.best_wave = int(o.best_wave)
	var bt := float(o.get("best_time", 0.0))
	if bt > 0.0 and (float(d.best_time) <= 0.0 or bt < float(d.best_time)):
		d.best_time = bt
	for k in ["ach", "unlocks", "lore"]:
		if o.get(k) is Dictionary:
			if not d.get(k) is Dictionary:
				d[k] = {}
			for id in o[k]:
				if not d[k].has(id):
					d[k][id] = o[k][id]
	# the run in progress: whichever copy was written last wins (null = it ended)
	if int(o.get("run_at", 0)) > int(d.get("run_at", 0)):
		d.run = o.get("run")
		d.run_at = int(o.run_at)
	if o.get("gun_wins") is Dictionary:
		for g in o.gun_wins:
			d.gun_wins[g] = maxi(int(d.gun_wins.get(g, 0)), int(o.gun_wins[g]))
	return JSON.stringify(d) != before


# ---------------------------------------------------------------- the run in progress
# A snapshot is written as every wave begins; quitting and coming back starts that
# wave again with everything kept. It goes to the cloud with the rest of the save.

static func run_saved():
	var r = load_data().get("run")
	return r if r is Dictionary and not r.is_empty() else null


static func save_run(snap: Dictionary) -> void:
	var d := load_data()
	d.run = snap
	d.run_at = int(Time.get_unix_time_from_system() * 1000.0)
	save()


static func clear_run() -> void:
	var d := load_data()
	if d.get("run") == null:
		return
	d.run = null
	d.run_at = int(Time.get_unix_time_from_system() * 1000.0)
	save()


# Quit: in the browser hand the player back to the page instead of freezing it.
static func leave(tree: SceneTree) -> bool:
	var sh = shell()
	if sh and bool(JavaScriptBridge.eval("window.parent !== window", true)):
		sh.post("home")
		return true
	tree.quit()
	return false


static func unlocked(key: String) -> bool:
	if key == "" or test_mode or dev_unlock:
		return true
	var d := load_data()
	return d.unlocks.has(key) or d.ach.has(key)


static func gun_open(id: String) -> bool:
	return unlocked(Loadout.GUNS[id][4])


static func stake_open(i: int) -> bool:
	return i == 0 or test_mode or dev_unlock or int(load_data().stake_won) >= i - 1


# Returns true the first time.
static func achieve(id: String) -> bool:
	if training_active:
		return false
	var d := load_data()
	if d.ach.has(id):
		return false
	d.ach[id] = Time.get_unix_time_from_system()
	SteamBridge.unlock(id)
	save()
	return true


static func count(key: String, n: int = 1) -> int:
	var d := load_data()
	if training_active:
		return int(d.get(key, 0))
	d[key] = int(d.get(key, 0)) + n
	return d[key]


static func record_run(game, won: bool) -> void:
	if game.bot != null or dev_unlock:
		return
	var d := load_data()
	d.runs += 1
	d.kills += game.kills
	var reach: int = game.chapter * 100 + game.wave_ctl.index
	if reach > d.best_chapter * 100 + d.best_wave:
		d.best_chapter = game.chapter
		d.best_wave = game.wave_ctl.index
	if won:
		d.wins += 1
		if d.best_time <= 0.0 or game.run_time < d.best_time:
			d.best_time = game.run_time
		d.stake_won = maxi(int(d.stake_won), Loadout.stake)
		d.gun_wins[Loadout.gun] = int(d.gun_wins.get(Loadout.gun, 0)) + 1
		d.unlocks["win"] = true
	save()
