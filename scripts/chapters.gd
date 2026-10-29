class_name Chapters
# The run's chapters in story order (design/LORE.md: twelve in all, three acts).
# Only the built ones are listed; each names the story chapter it is, the room,
# the enemy pool, the music and the boss it uses. A run plays this list in
# order, so a chapter not built yet is simply not there.

const LIST := [
	{"story": 1, "room": 0, "pool": 0, "music": 0, "boss": "lockdown", "note": "note_boss_lockdown", "par": [90.0, 130.0]},
	{"story": 2, "room": 1, "pool": 1, "music": 1, "boss": "warden", "note": "note_boss_2", "par": [45.0, 70.0]},
	{"story": 3, "room": 5, "pool": 6, "music": 1, "boss": "testbed", "note": "note_boss_testbed", "par": [70.0, 110.0]},
	{"story": 4, "room": 2, "pool": 2, "music": 2, "boss": "devourer", "note": "note_boss_3", "par": [45.0, 70.0]},
	{"story": 5, "room": 0, "pool": 5, "music": 0, "boss": "train", "note": "note_boss", "par": [70.0, 105.0]},
	{"story": 6, "room": 6, "pool": 7, "music": 2, "boss": "grid", "note": "note_boss_grid", "par": [90.0, 130.0]},
	{"story": 7, "room": 3, "pool": 3, "music": 3, "boss": "metronome", "note": "note_boss_4", "par": [55.0, 90.0]},
	{"story": 8, "room": 7, "pool": 8, "music": 1, "boss": "archivist", "note": "note_boss_archivist", "par": [72.0, 108.0]},
	{"story": 9, "room": 8, "pool": 9, "music": 2, "boss": "counterweight", "note": "note_boss_counterweight", "par": [50.0, 80.0]},
	{"story": 12, "room": 4, "pool": 4, "music": 4, "boss": "zero", "note": "note_boss_5", "par": [60.0, 90.0]},
]

# The boss achievements keep the names they were earned under.
const BOSS_ACH := {"train": "boss_1", "warden": "boss_2", "devourer": "boss_3", "metronome": "boss_4", "zero": "boss_5"}

# Saved runs record the story number (v3). Older ones kept a position in the
# list of their day: v1 the first five chapters, v2 the six of the first table.
const V1_STORY := [1, 2, 4, 7, 12]
const V2_STORY := [1, 2, 4, 5, 7, 12]


# Where a saved run's chapter now sits in the run.
static func from_save(snap: Dictionary) -> int:
	var v := int(snap.get("v", 1))
	var st := 1
	if v >= 3:
		st = int(snap.get("story", 1))
	else:
		var i := int(snap.get("chapter", 0))
		var old: Array = V1_STORY if v < 2 else V2_STORY
		st = old[clampi(i, 0, old.size() - 1)]
	for k in LIST.size():
		if int(LIST[k].story) >= st:
			return k
	return LIST.size() - 1


static func count() -> int:
	return LIST.size()


static func at(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]


static func story(i: int) -> int:
	return int(at(i).story)


static func room(i: int) -> int:
	return int(at(i).room)


static func pool(i: int) -> int:
	return int(at(i).pool)


static func music(i: int) -> int:
	return int(at(i).music)


static func boss(i: int) -> String:
	return at(i).boss


# "Chapter 5 · The Superconducting Line": the story number, not the run's
static func title(i: int) -> String:
	return Txt.t("chapter_%d" % story(i))


static func sub(i: int) -> String:
	return Txt.t("chapter_%d_sub" % story(i))


static func label(i: int) -> String:
	return Txt.t("chapter_n") % story(i)
