class_name Chapters
# The run's chapters in story order (design/LORE.md: twelve in all, three acts).
# Only the built ones are listed; each names the story chapter it is, the room,
# the enemy pool, the music and the boss it uses. A run plays this list in
# order, so a chapter not built yet is simply not there.

const LIST := [
	{"story": 1, "room": 0, "pool": 0, "music": 0, "boss": "lockdown", "note": "note_boss_lockdown", "par": [90.0, 130.0]},
	{"story": 2, "room": 1, "pool": 1, "music": 1, "boss": "warden", "note": "note_boss_2", "par": [45.0, 70.0]},
	{"story": 4, "room": 2, "pool": 2, "music": 2, "boss": "devourer", "note": "note_boss_3", "par": [45.0, 70.0]},
	{"story": 5, "room": 0, "pool": 5, "music": 0, "boss": "train", "note": "note_boss", "par": [70.0, 105.0]},
	{"story": 7, "room": 3, "pool": 3, "music": 3, "boss": "metronome", "note": "note_boss_4", "par": [70.0, 100.0]},
	{"story": 12, "room": 4, "pool": 4, "music": 4, "boss": "zero", "note": "note_boss_5", "par": [60.0, 90.0]},
]

# saved runs from before this table: chapter i of the old five-chapter run
const OLD_RUN := [0, 1, 2, 4, 5]


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
