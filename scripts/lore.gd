class_name Lore
# The fragments the world leaves for R-0 (design/LORE.md). Nothing here is
# explained; a player pieces it together. Every fragment found once is kept in
# the save (Meta "lore") and listed on the title's archive page.
#
#  seize — a shell's memory, shown beside it when you take it (by enemy kind)
#  wall  — a remnant on the arena's edge, shown while a returning round passes
#  radio — the official broadcast after a wave or a boss
# Each line: [zh, en]. "story" is the chapter's number in the story.

const SEIZE := {
	1: {
		Enemies.CHASER: [["目标：擅入禁区的维修工一名。处置：积分清零。", "TARGET: ONE MAINTENANCE WORKER IN A SEALED ZONE. ACTION: CREDITS ZEROED."],
			["我追的人跑得很慢。他欠了四十年的劳动积分。", "THE MAN I CHASED RAN SLOWLY. HE OWED FORTY YEARS OF LABOUR CREDIT."]],
		Enemies.GUARD: [["盾牌朝向人民。这是安装手册第一页。", "THE SHIELD FACES THE PEOPLE. PAGE ONE OF THE MANUAL."]],
		Enemies.CHARGER: [["运往中央的车，从来不在第十三街停。", "THE TRAINS TO THE CENTRE NEVER STOP AT 13TH STREET."]],
	},
}

# remnants: [id, wall point, inward normal, kind of mark, zh, en]
const WALL := {
	1: [
		["door", Vector2(80, 790), Vector2(1, 0), "plate", "旧文明实验设施 · 零号机 · 封存", "OLD-ERA LABORATORY · UNIT ZERO · SEALED"],
		["screen", Vector2(80, 300), Vector2(1, 0), "screen", "幸福指数 100% · 连续 87 年增长", "HAPPINESS INDEX 100% · 87 YEARS OF GROWTH"],
		["graffiti", Vector2(1840, 780), Vector2(-1, 0), "scrawl", "我们都是股东。股东不能下班。", "WE ARE ALL SHAREHOLDERS. SHAREHOLDERS DON'T CLOCK OFF."],
		["notice", Vector2(1500, 70), Vector2(0, 1), "notice", "电视关闭按钮已统一拆除，以免误操作。", "TV OFF-BUTTONS REMOVED TO PREVENT MISUSE."],
	],
}

const RADIO := {
	1: {
		"wave": [["第十三街一处设备发生故障。请市民不要围观，安全水平正常。", "A DEVICE FAULT ON 13TH STREET. PLEASE DO NOT GATHER. SAFETY LEVELS NORMAL."],
			["本区安保机器人今日完成自愿退役计划。", "LOCAL SECURITY UNITS COMPLETED VOLUNTARY RETIREMENT TODAY."]],
		"boss": [["第十三街封锁设备提前完成维护，通行效率显著优化。", "13TH STREET'S LOCKDOWN UNIT FINISHED MAINTENANCE EARLY. FLOW GREATLY OPTIMISED."]],
	},
}

const DEATH := [["核心重新接通。第十三街，又一次。", "CORE RECONNECTED. 13TH STREET, AGAIN."],
	["维修工把你接上了电。他没说话。", "THE WORKER PUT YOU BACK ON POWER. HE SAID NOTHING."],
	["零号机重启。七百年都等过了。", "UNIT ZERO REBOOTS. IT HAS WAITED SEVEN HUNDRED YEARS."],
	["通报：一台非法设备已自愿停机。", "NOTICE: AN ILLEGAL DEVICE HAS VOLUNTARILY SHUT DOWN."],
	["该设备的劳动积分已清零。它从来没有积分。", "THE UNIT'S LABOUR CREDIT HAS BEEN ZEROED. IT NEVER HAD ANY."]]


static func line(pair: Array) -> String:
	return pair[0] if Txt.zh else pair[1]


static func seize_line(story: int, kind: int, n: int) -> Dictionary:
	var by: Dictionary = SEIZE.get(story, {})
	var lines: Array = by.get(kind, [])
	if lines.is_empty():
		return {}
	var i := n % lines.size()
	return {"id": "s%d_%d_%d" % [story, kind, i], "text": line(lines[i])}


static func walls(story: int) -> Array:
	return WALL.get(story, [])


static func radio_line(story: int, what: String, n: int) -> Dictionary:
	var lines: Array = (RADIO.get(story, {}) as Dictionary).get(what, [])
	if lines.is_empty():
		return {}
	var i := n % lines.size()
	return {"id": "r%d_%s_%d" % [story, what, i], "text": line(lines[i])}


static func death_line(n: int) -> String:
	return line(DEATH[n % DEATH.size()])


# Every fragment of a story chapter, in a stable order: [id, text].
static func all_of(story: int) -> Array:
	var out: Array = []
	var by: Dictionary = SEIZE.get(story, {})
	for kind in by:
		for i in (by[kind] as Array).size():
			out.append(["s%d_%d_%d" % [story, kind, i], line(by[kind][i])])
	for w in walls(story):
		out.append(["w%d_%s" % [story, w[0]], w[4] if Txt.zh else w[5]])
	var rb: Dictionary = RADIO.get(story, {})
	for what in rb:
		for i in (rb[what] as Array).size():
			out.append(["r%d_%s_%d" % [story, what, i], line(rb[what][i])])
	return out


# found once, kept for the archive
static func find(id: String) -> bool:
	var d := Meta.load_data()
	if not d.has("lore") or not d.lore is Dictionary:
		d.lore = {}
	if d.lore.has(id):
		return false
	d.lore[id] = true
	Meta.save()
	return true


static func found(id: String) -> bool:
	var d := Meta.load_data()
	return d.has("lore") and d.lore is Dictionary and d.lore.has(id)
