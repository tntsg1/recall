extends SceneTree
# Headless: the room generator. For each story chapter that walks room to
# room, 1000 rooms per wave slot must all pass the check, and no two of the
# 1000 must be alike (shared solid floor under 70%). Prints how many tries a
# room took, which rule turned tries down, and the most alike pair.
# Usage: $G --headless --path . -s tests/roomgen_check.gd -- [n=1000]

var fails := 0


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	var n := 1000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.substr(2))
	for story in RoomGen.ON:
		var t0 := Time.get_ticks_msec()
		var rooms: Array = []
		var sparse: Array = []
		var empty := 0
		var tries := 0
		var worst := 0
		var shapes := {}
		var railed := 0
		var sides := ["T", "B", "L", "R"]
		for k in n:
			for idx in 6:
				var entry: String = "L" if idx == 0 else sides[(k + idx) % 4]
				var exits: Array = [{}]
				if idx == 5:
					exits = [{"boss": true}]
				elif (k + idx) % 3 == 0:
					exits = [{}, {"risky": true}]
				# the chapter's remnants, one to a room in turn (the first room its own where it has them)
				var ids: Array = []
				for w in Lore.walls(story):
					ids.append(w[0])
				var first: Array = RoomGen.STYLE[story].get("first_room", [])
				var rem: Array = first.duplicate() if idx == 0 and not first.is_empty() else ([ids[(k + idx) % ids.size()]] if not ids.is_empty() and (k + idx) % 3 != 0 else [])
				# as Rooms does: one that reads off the wall you come in by waits for a later room
				for w in Lore.walls(story):
					if rem.has(w[0]) and not first.has(w[0]) and RoomGen.NORMAL[entry] == w[2] and idx < 5:
						rem.erase(w[0])
				var lay := RoomGen.make(story, idx, 1000 + k, entry, exits, rem)
				if lay.is_empty():
					empty += 1
					continue
				tries += int(lay.attempt) + 1
				if not (lay.get("rails", lay.get("lanes", [])) as Array).is_empty():
					railed += 1
				worst = maxi(worst, int(lay.attempt) + 1)
				shapes[lay.shape] = shapes.get(lay.shape, 0) + 1
				if idx == 0:
					sparse.append(lay)
				elif idx == 1 + k % 5:
					rooms.append(lay)   # one room of the five per seed: 1000 different runs
		var gen_ms := Time.get_ticks_msec() - t0
		_ok(empty == 0, "story %d: every one of %d rooms came out (%d none)" % [story, n * 6, empty])
		print("     tries per room %.2f (worst %d), %.2f ms a room, shapes %s" % [float(tries) / (n * 6 - empty), worst, float(gen_ms) / (n * 6), shapes])
		_ok(railed >= (n * 6 - empty) * 0.65, "story %d: floor lines (tracks, lanes) in %.0f%% of rooms (at least 65%%)" % [story, 100.0 * railed / (n * 6 - empty)])
		for set_name in ["rooms · cover", "rooms · cover and walls", "first rooms · cover"]:
			var lays: Array = sparse if set_name.begins_with("first") else rooms
			var with_walls: bool = set_name.ends_with("walls")
			var t1 := Time.get_ticks_msec()
			var best := [0.0, -1, -1]
			var cells: Array = []
			var grids: Array = []
			for lay in lays:
				var g := RoomGen.occupancy(lay, with_walls)
				var lst := PackedInt32Array()
				for c in g.size():
					if g[c] == 1:
						lst.append(c)
				cells.append(lst)
				grids.append(g)
			var over := 0
			for a in lays.size():
				var la: PackedInt32Array = cells[a]
				for b in range(a + 1, lays.size()):
					var gb: PackedByteArray = grids[b]
					var both := 0
					for c in la:
						both += gb[c]
					var u := la.size() + (cells[b] as PackedInt32Array).size() - both
					var o := float(both) / maxf(1.0, u)
					if o >= 0.7:
						over += 1
						if over <= 6:
							print("     alike: %s / %s %.0f%%" % [lays[a].shape, lays[b].shape, o * 100.0])
					if o > best[0]:
						best = [o, a, b]
			_ok(over == 0, "story %d %s: no two of %d alike (most alike %.0f%%, %d pairs ≥ 70%%, %d ms)" % [story, set_name, lays.size(), best[0] * 100.0, over, Time.get_ticks_msec() - t1])
	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)
