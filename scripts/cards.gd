class_name Cards
# The card pool: schools (levelled, up to 4 held), relics (passive, up to 5
# held) and items (spent the moment they are picked, or armed for the next
# recall / wave). Each offer draws three distinct cards.

const SCHOOL_SLOTS := 4
const RELIC_SLOTS := 5

const SCHOOLS := ["bounce", "split", "orbit", "magnet", "blast", "charge", "shadow", "chain", "possess"]
# what has to happen before some of the pool appears (Meta unlock keys)
const SCHOOL_LOCK := {"charge": "boss_3", "shadow": "boss_4", "chain": "win"}
const LEGEND_LOCK := "boss_1"

# id: [rarity 0 common / 1 rare / 2 legendary, name zh, name en, desc zh, desc en]
const RELICS := {
	"whet": [0, "磨利弹头", "WHETTED TIP", "去程伤害 +50%", "Outbound damage +50%"],
	"quick": [0, "快速装填", "QUICKLOADER", "射速 +25%", "Fire rate +25%"],
	"deepmag": [0, "厚弹匣", "DEEP MAGAZINE", "弹匣 +6 发", "Magazine +6 rounds"],
	"longfuse": [0, "长引信", "LONG FUSE", "嵌入弹 20 秒才熄灭（原 12 秒）", "Embedded rounds last 20 s (from 12)"],
	"lightstep": [0, "轻步", "LIGHT STEP", "闪避冷却 -40%，闪避时无敌", "Dash cooldown -40%; dashing is invulnerable"],
	"aftershock": [0, "余震", "AFTERSHOCK", "回收中击杀会在原地炸出一圈冲击（25 伤害）", "Kills during a recall burst outward (25 damage)"],
	"chain": [1, "连锁增幅", "CHAIN GAIN", "一次回收中，每次贯穿让后续返程伤害 +6%", "In a recall, every pierce adds +6% to the rest"],
	"critical": [1, "临界", "CRITICAL HOLD", "熄灭前 3 秒内被回收的子弹伤害 ×2", "Rounds recalled in their last 3 s deal ×2"],
	"crossfire": [1, "交叉火力", "CROSSFIRE", "一次回收中第 3 次贯穿同一敌人时额外造成 60 伤害", "The 3rd return through one enemy in a recall deals +60"],
	"stillheart": [1, "静止之心", "STILL HEART", "按住 Q 可维持 2 秒，时间更慢", "Hold Q for up to 2 s; time slows further"],
	"reaper": [1, "收割", "REAPER", "一次回收中每击杀一个敌人，返程伤害 +12%", "In a recall, each kill adds +12% return damage"],
	"mirror": [1, "镜返", "MIRROR ARC", "子弹归匣的那道弧线也会伤敌", "The arc home into the magazine also cuts"],
	"gravity": [2, "引力井", "GRAVITY WELL", "按住 Q 时，嵌入弹把附近敌人吸向自己", "While you hold Q, embedded rounds pull enemies in"],
	"zeroblade": [2, "归零之刃", "ZERO EDGE", "一次回收中每次贯穿，本次回收伤害 ×1.08（最高 ×4）", "In a recall, every pierce multiplies its damage ×1.08 (up to ×4)"],
	"undying": [2, "不灭", "UNDYING", "每章一次：本该碎掉最后一格裂痕的那一击无效", "Once per chapter, the blow that would end the run misses"],
	"edge": [0, "棱边", "HONED EDGE", "子弹每折一次（墙、镜、棱镜），伤害 +25%", "Each bend a round takes (wall, mirror, prism) adds +25% damage"],
	"steady": [0, "稳手", "STEADY HAND", "站着不动时射速 +40%", "Standing still: fire rate +40%"],
	"spare_round": [0, "备弹", "SPARE ROUNDS", "弹匣打空时，最早嵌入的 3 颗子弹立刻回来", "When the magazine runs dry, the 3 oldest embedded rounds come straight home"],
	"thick": [0, "厚壳", "THICK SHELL", "裂痕上限 +1，并立刻修复 1 格", "One more crack to spare, and mend one now"],
	"refract": [1, "棱镜心", "PRISM HEART", "去程子弹第一次命中敌人后折出 30° 继续飞", "An outbound round bends 30° after its first hit and flies on"],
	"focus_lens": [1, "聚焦", "FOCUS LENS", "按住 Q 超过 0.8 秒再松开，这次回收伤害 +40%", "Hold Q past 0.8 s: that recall deals +40%"],
	"mirror_skin": [1, "镜肤", "MIRROR SKIN", "受击时所有嵌入弹立刻回收", "When you are hit, every embedded round recalls at once"],
	"hunter": [1, "猎手", "HUNTER", "对满血敌人的第一下伤害 +50%", "+50% on the first hit against an unhurt enemy"],
	"twin": [2, "双生", "TWIN", "每次射击额外射出一颗分裂小弹（不耗弹匣）", "Every shot also fires a small split round (free)"],
	"eclipse": [2, "日蚀", "ECLIPSE", "一次回收 12 颗以上时，伤害 ×2", "A recall of 12 or more rounds deals ×2"],
	"magnetic_tip": [0, "磁尖", "MAGNETIC TIP", "嵌入弹 120 像素内的敌人减速 30%", "Enemies within 120 px of an embedded round move 30% slower"],
	"quick_recall": [0, "疾归", "SWIFT RETURN", "返程速度 +30%", "Returning rounds fly 30% faster"],
	"lean": [0, "轻装", "TRAVEL LIGHT", "移动速度 +12%", "Move 12% faster"],
	"first_blood": [0, "先声", "OPENING SHOT", "每波第一下命中伤害 ×3", "The first hit of every wave deals ×3"],
	"leech_ward": [1, "护弹", "KEEPSAKE", "按住 Q 时，被偷走、被吞下的子弹立刻回来", "Holding Q calls stolen and swallowed rounds straight home"],
	"echo": [1, "回响", "ECHO", "一次回收结束时，第一个被贯穿的敌人再受 贯穿数×6 伤害", "When a recall ends, the first enemy it pierced takes 6 × the pierce count"],
	"brace": [1, "架势", "BRACE", "按住 Q 的时候不会受伤", "You cannot be hurt while holding Q"],
	"overflow": [1, "满溢", "BRIMMING", "弹匣全满时射出的子弹伤害 +40%", "Shots fired from a full magazine deal +40%"],
	"singularity": [2, "奇点", "SINGULARITY", "一次回收贯穿 20 次以上，全场敌人受 50 伤害", "A recall of 20+ pierces deals 50 to every enemy"],
	"phoenix": [2, "涅槃", "PHOENIX", "每局一次：裂痕碎光时恢复 3 格", "Once a run, when the last crack goes, three come back"],
	"downbeat": [0, "踩点", "DOWNBEAT", "在拍点上松开 Q，这次回收伤害 +30%", "Release on the beat: that recall deals +30%"],
	"reserve": [0, "储备", "RESERVE", "弹匣 +3 发", "Magazine +3 rounds"],
	"swift_feet": [0, "疾步", "SWIFT FEET", "闪避距离 +40%", "Dashes go 40% further"],
	"heavy": [0, "重弹", "HEAVY ROUNDS", "去程伤害 +25%，射速 -10%", "Outbound damage +25%, fire rate -10%"],
	"beat_heart": [1, "节拍心", "BEAT HEART", "每 8 拍，所有嵌入弹脉冲一次（周围 8 伤害）", "Every 8 beats, each embedded round pulses (8 damage around it)"],
	"afterburn": [1, "余烬", "AFTERBURN", "被返程子弹命中的敌人燃烧 2 秒", "Enemies hit by returning rounds burn for 2 s"],
	"vampire": [1, "汲取", "DRAIN", "每累计 40 次返程贯穿修复 1 格裂痕", "Every 40 returning pierces mend a crack"],
	"grit": [1, "坚韧", "GRIT", "受击后 2 秒无敌，3 秒内伤害 +20%", "After a hit: 2 s invulnerable, +20% damage for 3 s"],
	"crescendo": [2, "渐强", "CRESCENDO", "4 秒内连续回收，每次伤害再 +25%（最多 +100%）", "Recall again within 4 s: each adds +25% (up to +100%)"],
	"time_lord": [2, "时主", "TIME LORD", "按住 Q 时敌人完全静止", "Enemies freeze completely while you hold Q"],
	"long_barrel": [0, "长管", "LONG BARREL", "子弹飞行速度 +30%", "Rounds fly 30% faster"],
	"wide_ring": [0, "宽环", "WIDE RING", "行星轨道半径 +40%，轨道伤害 +50%", "Orbit radius +40%, orbit damage +50%"],
	"spark": [0, "火花", "SPARK", "子弹嵌入时对 30 像素内的敌人造成 6 伤害", "Rounds that embed deal 6 to enemies within 30 px"],
	"second_wind": [0, "回气", "SECOND WIND", "每清完 3 波修复 1 格裂痕", "Every third wave cleared mends a crack"],
	"homing_spark": [1, "回镜", "RETURN SPARK", "每颗归匣的子弹会朝最近的敌人射出一颗免费小弹", "Each round that comes home fires a free small round at the nearest enemy"],
	"zero_point": [1, "零点", "ZERO POINT", "回收时每颗子弹第一次命中伤害 ×2", "Each recalled round's first hit deals ×2"],
	"sniper": [1, "狙击", "SNIPER", "去程子弹每飞 100 像素伤害 +4%", "Outbound rounds deal +4% per 100 px flown"],
	"fortress": [1, "堡垒", "FORTRESS", "每碎一格裂痕，伤害 +8%", "Each missing crack adds +8% damage"],
	"overkill": [2, "余波", "OVERKILL", "击杀溢出的伤害一半跳到最近的敌人", "Half of any overkill jumps to the nearest enemy"],
	"encore": [2, "安可", "ENCORE", "每波第一次回收会再来一遍影子回收（60% 伤害）", "Each wave's first recall plays twice (a shadow pass at 60%)"],
	"keen_edge": [0, "锋刃", "KEEN EDGE", "返程伤害 +15%", "Returning damage +15%"],
	"deep_focus": [0, "深定", "DEEP FOCUS", "按住 Q 时时间更慢，并多撑 0.3 秒", "Holding Q slows time further and lasts 0.3 s longer"],
	"lucky": [1, "幸运", "LUCKY", "每章多 1 次刷新", "One more reroll each chapter"],
	"glass_cannon": [1, "玻璃炮", "GLASS CANNON", "所有伤害 +40%，裂痕上限 -1", "All damage +40%, one fewer crack"],
	"apex": [2, "顶点", "APEX", "有 3 个流派达到 3 级时，所有伤害 ×1.5", "With three schools at Lv3, all damage ×1.5"],
}

# id: [name zh, name en, desc zh, desc en]
const ITEMS := {
	"patch": ["修补", "PATCH", "立即修复 1 格裂痕", "Mend 1 crack now"],
	"overload": ["过载", "OVERLOAD", "下一次回收伤害 ×3", "Your next recall deals ×3"],
	"spare": ["备用刷新", "SPARE REROLL", "本章刷新次数 +1", "+1 reroll this chapter"],
	"firststrike": ["先手", "FIRST STRIKE", "下一波敌人带着一半生命登场", "Next wave's enemies arrive at half health"],
	"stasis": ["时滞", "STASIS", "下一波开场 6 秒内敌人只有 30% 速度", "Next wave: enemies move at 30% for the first 6 s"],
	"ward": ["护盾", "WARD", "本章下一次受击无效", "The next hit this chapter misses"],
	"longhold": ["凝神", "LONG BREATH", "下一波按住 Q 可维持 3 秒", "Next wave: hold Q for up to 3 s"],
	"recall_order": ["回收令", "RECALL ORDER", "被偷走、被吞下的子弹立刻回到弹匣", "Stolen and swallowed rounds come home now"],
	"slowfield": ["迟滞场", "DRAG FIELD", "下一波敌人全程 80% 速度", "Next wave: enemies move at 80% throughout"],
	"tempo": ["加速", "TEMPO", "下一波射速 +40%", "Next wave: fire rate +40%"],
	"mend_all": ["大修补", "OVERHAUL", "立即修复 2 格裂痕", "Mend 2 cracks now"],
	"haste": ["疾风", "TAILWIND", "下一波移动速度 +25%", "Next wave: move 25% faster"],
	"calm_mind": ["静心", "STILL MIND", "下一波回收伤害 +20%", "Next wave: recalls deal +20%"],
	"card_luck": ["好运", "GOOD FORTUNE", "下一次选卡至少出现一张传说遗物", "Your next pick shows at least one legendary relic"],
	"rewind": ["回溯", "REWIND", "所有嵌入弹的熄灭倒计时重置", "Every embedded round's timer starts over"],
}

const RARITY_WEIGHT := [[70.0, 25.0, 5.0], [60.0, 31.0, 9.0], [50.0, 36.0, 14.0], [42.0, 40.0, 18.0], [35.0, 42.0, 23.0]]


static func relic_name(id: String) -> String:
	return RELICS[id][1] if Txt.zh else RELICS[id][2]


static func relic_desc(id: String) -> String:
	return RELICS[id][3] if Txt.zh else RELICS[id][4]


static func item_name(id: String) -> String:
	return ITEMS[id][0] if Txt.zh else ITEMS[id][1]


static func item_desc(id: String) -> String:
	return ITEMS[id][2] if Txt.zh else ITEMS[id][3]


# Three distinct cards: {type, id, level (schools: current level)}
static func offer(game) -> Array:
	var out: Array = []
	var used := {}
	var chapter: int = clampi(game.chapter, 0, RARITY_WEIGHT.size() - 1)
	for i in 3:
		for tries in 30:
			var r := randf()
			var c := {}
			if r < 0.45:
				c = _school(game)
			elif r < 0.85:
				c = _relic(game, chapter)
			else:
				c = {"type": "item", "id": ITEMS.keys()[randi() % ITEMS.size()]}
			if c.is_empty():
				continue
			var key: String = c.type + ":" + c.id
			if used.has(key):
				continue
			used[key] = true
			out.append(c)
			break
	return out


static func _school(game) -> Dictionary:
	var pool: Array = []
	var held := 0
	for k in SCHOOLS:
		if game.lv.get(k, 0) > 0:
			held += 1
	for k in SCHOOLS:
		var l: int = game.lv.get(k, 0)
		if l >= 3 or not Meta.unlocked(SCHOOL_LOCK.get(k, "")):
			continue
		pool.append(k)
	if pool.is_empty():
		return {}
	var id: String = pool[randi() % pool.size()]
	return {"type": "school", "id": id, "level": game.lv.get(id, 0), "full": game.lv.get(id, 0) == 0 and held >= SCHOOL_SLOTS}


static func _relic(game, chapter: int) -> Dictionary:
	var w: Array = RARITY_WEIGHT[chapter]
	var roll: float = randf() * (w[0] + w[1] + w[2])
	var rarity := 0 if roll < w[0] else (1 if roll < w[0] + w[1] else 2)
	if game.armed.get("card_luck", false):
		game.armed.card_luck = false
		rarity = 2
	if rarity == 2 and not Meta.unlocked(LEGEND_LOCK):
		rarity = 1
	var pool: Array = []
	for id in RELICS:
		if RELICS[id][0] == rarity and not game.relics.has(id):
			pool.append(id)
	if pool.is_empty():
		for id in RELICS:
			if not game.relics.has(id):
				pool.append(id)
	if pool.is_empty():
		return {}
	return {"type": "relic", "id": pool[randi() % pool.size()]}
