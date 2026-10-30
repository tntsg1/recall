extends SceneTree
func _initialize() -> void:
	var story := int(OS.get_cmdline_user_args()[0])
	var sides := ["L", "T", "R", "B"]
	for k in int(OS.get_cmdline_user_args()[1]):
		for idx in 6:
			var entry: String = "L" if idx == 0 else sides[(k + idx) % 4]
			var exits: Array = [{}]
			if idx == 5:
				exits = [{"boss": true}]
			elif (k + idx) % 3 == 0 and idx < 4:
				exits = [{}, {"risky": true}]
			var ids: Array = []
			for w in Lore.walls(story):
				ids.append(w[0])
			var rem: Array = [ids[(k + idx) % ids.size()]] if (k + idx) % 3 != 0 else []
			for w in Lore.walls(story):
				if rem.has(w[0]) and RoomGen.NORMAL[entry] == w[2] and idx < 5:
					rem.erase(w[0])
			var lay := RoomGen.make(story, idx, 1000 + k, entry, exits, rem)
			if lay.is_empty():
				print("FAIL k=", k, " idx=", idx, " entry=", entry, " rem=", rem, " last=", RoomGen.last_why)
	print("TALLY ", RoomGen.why_tally)
	quit()
