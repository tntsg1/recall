class_name Loadout
# What a run starts with: the magazine (gun) and the stake (difficulty).
# Guns change how you shoot; stakes stack, each adding to the ones below it.
# The title screen writes `gun` and `stake`; the game reads them in _ready.

static var gun := "standard"
static var stake := 0
static var trail := 0     # the dodge's colour: the title writes it from the save

# id: [name zh, name en, desc zh, desc en, unlock key ("" = from the start)]
const GUNS := {
	"standard": ["标准弹匣", "STANDARD", "24 发，一切照常", "24 rounds, as it comes", ""],
	"heavy": ["重弹", "HEAVY", "12 发，伤害 ×2，射速慢", "12 rounds, ×2 damage, slower fire", "boss_1"],
	"swarm": ["轻弹群", "SWARM", "36 发，伤害 ×0.65，射速快", "36 rounds, ×0.65 damage, faster fire", "boss_2"],
	"ricochet": ["跳弹", "RICOCHET", "开局带反弹 1 级", "Start with Ricochet Lv1", "boss_3"],
	"scatter": ["散射", "SCATTER", "30 发，每次射出 3 颗扇形弹，射速慢", "30 rounds, each shot fans out 3, slower fire", "kills_300"],
	"rail": ["磁轨", "RAIL", "子弹速度 ×2，去程无视盾卫的盾", "Rounds fly ×2 and pass guards' shields going out", "boss_4"],
	"orbiter": ["回旋", "ORBITER", "20 发，开局带行星轨道 2 级", "20 rounds, start with Orbit Lv2", "pierce30"],
	"zero": ["零式", "ZERO", "开局随机 2 个遗物，但裂痕只有 3 格", "Two random relics to start, but only 3 cracks", "win"],
}

# stacking: stake n includes every rule up to n
const STAKES := [
	["白", "WHITE", "标准难度", "As intended"],
	["灰", "GREY", "敌人生命 +20%", "Enemies +20% health"],
	["银", "SILVER", "每章没有免费刷新", "No free reroll each chapter"],
	["铁", "IRON", "敌人速度 +15%", "Enemies +15% speed"],
	["钢", "STEEL", "裂痕上限 4 格", "Only 4 cracks"],
	["铬", "CHROME", "每波 1 个精英，Boss 生命 +30%", "An elite every wave, bosses +30% health"],
	["墨", "INK", "每波敌人 +20%，特殊敌人更多", "+20% enemies a wave, more of them special"],
	["红", "RED", "每波 2 个精英，Boss 生命 +60%，章节之间只修复 1 格", "Two elites a wave, bosses +60% health, one crack mended between chapters"],
]

# What a stake comes to, each rule at its final number: [first stake, last, zh, en]
const RULES := [
	[1, 7, "敌人生命 +20%", "enemies +20% health"],
	[3, 7, "敌人速度 +15%", "enemies +15% speed"],
	[6, 7, "每波敌人数量 +20%", "20% more enemies a wave"],
	[6, 7, "特殊敌人翻倍", "twice the specials"],
	[5, 6, "每波 1 个精英（生命 ×2.2）", "an elite every wave (×2.2 health)"],
	[7, 7, "每波 2 个精英（生命 ×2.2）", "two elites a wave (×2.2 health)"],
	[5, 6, "Boss 生命 +30%", "bosses +30% health"],
	[7, 7, "Boss 生命 +60%", "bosses +60% health"],
	[4, 7, "裂痕上限 4 格", "only 4 cracks"],
	[2, 7, "每章没有免费刷新", "no free reroll"],
	[7, 7, "章节之间只修复 1 格", "one crack mended between chapters"],
]

# Finishing a run on stake i opens trail i + 1. Red stays the enemy's colour, so
# no trail uses it; the last one flows through every hue but red.
const TRAILS := [
	["白", "WHITE", Color(0.925, 0.93, 0.935)],
	["青", "CYAN", Color(0.2, 0.9, 1.0)],
	["蓝", "BLUE", Color(0.3, 0.52, 1.0)],
	["紫", "VIOLET", Color(0.66, 0.42, 1.0)],
	["绿", "GREEN", Color(0.28, 1.0, 0.6)],
	["黄", "YELLOW", Color(0.96, 0.92, 0.3)],
	["金", "GOLD", Color(1.0, 0.72, 0.2)],
	["粉", "PINK", Color(1.0, 0.45, 0.85)],
	["流光", "FLOW", Color(1, 1, 1)],
]


static func gun_name(id: String) -> String:
	return GUNS[id][0] if Txt.zh else GUNS[id][1]


static func gun_desc(id: String) -> String:
	return GUNS[id][2] if Txt.zh else GUNS[id][3]


static func stake_name(i: int) -> String:
	return STAKES[i][0] if Txt.zh else STAKES[i][1]


static func stake_desc(i: int) -> String:
	return STAKES[i][2] if Txt.zh else STAKES[i][3]


static func trail_name(i: int) -> String:
	return TRAILS[i][0] if Txt.zh else TRAILS[i][1]


# Trail i's colour; `along` runs down the streak, so the flow shifts as it goes.
static func trail_color(i: int, a: float, k: float, along := 0.0) -> Color:
	var c: Color = TRAILS[i][2]
	if i == TRAILS.size() - 1:
		var wave := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0012 + along * 2.4)
		c = Color.from_hsv(0.1 + 0.82 * wave, 0.72, 1.0)
	return Pal.tint(c, a, k)


static func stake_rules(i: int) -> String:
	var out: Array = []
	for r in RULES:
		if i >= r[0] and i <= r[1]:
			out.append(r[2] if Txt.zh else r[3])
	return "  ·  ".join(out) if not out.is_empty() else stake_desc(0)


static func at_least(i: int) -> bool:
	return stake >= i


# --- gun numbers the game asks for
static func mag() -> int:
	match gun:
		"heavy":
			return 12
		"swarm":
			return 36
		"scatter":
			return 30
		"orbiter":
			return 20
	return 24


static func dmg_mult() -> float:
	match gun:
		"heavy":
			return 2.0
		"swarm":
			return 0.65
	return 1.0


static func fire_mult() -> float:
	match gun:
		"heavy":
			return 1.6
		"swarm":
			return 0.7
		"scatter":
			return 1.8
	return 1.0


# --- stake numbers
static func enemy_hp() -> float:
	return 1.2 if at_least(1) else 1.0


# On every stake, white too: from the seventh chapter enemies take more killing.
static func chapter_hp(ch: int) -> float:
	return 1.0 + 0.08 * maxi(0, ch - 5)


static func enemy_speed() -> float:
	return 1.15 if at_least(3) else 1.0


static func boss_hp() -> float:
	if at_least(7):
		return 1.6
	return 1.3 if at_least(5) else 1.0


static func budget() -> float:
	return 1.2 if at_least(6) else 1.0


# Elites in every ordinary wave.
static func elites() -> int:
	if at_least(7):
		return 2
	return 1 if at_least(5) else 0


# More of a wave's budget goes on specials, so fewer plain chasers.
static func specials() -> float:
	return 2.0 if at_least(6) else 1.0


# Cracks mended between chapters.
static func mend() -> int:
	return 1 if at_least(7) else 2
