class_name Loadout
# What a run starts with: the magazine (gun) and the stake (difficulty).
# Guns change how you shoot; stakes stack, each adding to the ones below it.
# The title screen writes `gun` and `stake`; the game reads them in _ready.

static var gun := "standard"
static var stake := 0

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
	["灰", "GREY", "敌人生命 +15%", "Enemies +15% health"],
	["银", "SILVER", "每章没有免费刷新", "No free reroll each chapter"],
	["铁", "IRON", "敌人速度 +15%", "Enemies +15% speed"],
	["钢", "STEEL", "裂痕上限 4 格", "Only 4 cracks"],
	["铬", "CHROME", "Boss 生命 +25%", "Bosses +25% health"],
	["墨", "INK", "每波敌人 +20%", "+20% enemies a wave"],
	["红", "RED", "章节之间不再修复裂痕", "No mending between chapters"],
]


static func gun_name(id: String) -> String:
	return GUNS[id][0] if Txt.zh else GUNS[id][1]


static func gun_desc(id: String) -> String:
	return GUNS[id][2] if Txt.zh else GUNS[id][3]


static func stake_name(i: int) -> String:
	return STAKES[i][0] if Txt.zh else STAKES[i][1]


static func stake_desc(i: int) -> String:
	return STAKES[i][2] if Txt.zh else STAKES[i][3]


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
	return 1.15 if at_least(1) else 1.0


static func enemy_speed() -> float:
	return 1.15 if at_least(3) else 1.0


static func boss_hp() -> float:
	return 1.25 if at_least(5) else 1.0


static func budget() -> float:
	return 1.2 if at_least(6) else 1.0
