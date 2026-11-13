class_name Cards
# The card pool: schools (levelled, up to 4 held), relics (passive, up to 5
# held) and items (spent the moment they are picked, or armed for the next
# recall / wave). Each offer draws three distinct cards.

const SCHOOL_SLOTS := 4
const RELIC_SLOTS := 5

const SCHOOLS := ["bounce", "split", "orbit", "magnet", "blast", "charge", "shadow", "chain", "possess", "walk"]
# what has to happen before some of the pool appears (Meta unlock keys)
const SCHOOL_LOCK := {"charge": "boss_3", "shadow": "boss_4", "chain": "win"}
const LEGEND_LOCK := "boss_2"
# The same relic again raises its rank: what picks are for once the case is full.
const MAX_STAR := 3
const UP_CHANCE := 0.6       # of relic draws, once all five slots are taken
const STEAL_FROM := 4        # the story chapter where rounds first get stolen

# id: [rarity 0 common / 1 rare / 2 legendary, name zh, name en, desc zh, desc en]
const RELICS := {
	"whet": [0, "磨利弹头", "WHETTED TIP", "子弹去程造成的伤害提高 50%。", "Outbound damage +50%."],
	"quick": [0, "快速装填", "QUICKLOADER", "射击速度提高 25%。", "Fire rate +25%."],
	"deepmag": [0, "厚弹匣", "DEEP MAGAZINE", "弹匣容量增加 6 发。", "Magazine +6 rounds."],
	"longfuse": [0, "长引信", "LONG FUSE", "嵌入目标的子弹可以保留 20 秒才熄灭，原本只能保留 12 秒。", "Embedded rounds last 20 s before going dark, up from 12 s."],
	"lightstep": [0, "轻步", "LIGHT STEP", "闪避冷却时间缩短 40%，闪避期间不会受到伤害。", "Dash cooldown -40%, and you take no damage while dashing."],
	"aftershock": [0, "余震", "AFTERSHOCK", "回收子弹时击杀敌人，会在击杀位置产生一圈冲击波，对周围敌人造成 25 点伤害。", "Killing an enemy during a recall sends a shockwave out from the kill, dealing 25 damage to nearby enemies."],
	"chain": [1, "连锁增幅", "CHAIN GAIN", "同一次回收中，每贯穿一个目标，后续返程造成的伤害就会提高 6%。", "In one recall, each target pierced raises the damage of the rest of the return by 6%."],
	"critical": [1, "临界", "CRITICAL HOLD", "子弹即将熄灭的前 3 秒内进行回收，可以造成双倍伤害。", "Recalling a round in its last 3 s before it goes dark deals double damage."],
	"crossfire": [1, "交叉火力", "CROSSFIRE", "同一次回收中，第 3 次贯穿同一个敌人时，会额外造成 60 点伤害。", "In one recall, the 3rd pierce through the same enemy deals 60 extra damage."],
	"stillheart": [1, "静止之心", "STILL HEART", "按住 Q 可以让时间进一步减慢，最多维持 2 秒。", "Hold Q to slow time even further, for up to 2 s."],
	"reaper": [1, "收割", "REAPER", "同一次回收中，每击杀一个敌人，后续子弹的返程伤害提高 12%。", "In one recall, each kill raises the return damage of the following rounds by 12%."],
	"mirror": [1, "镜返", "MIRROR ARC", "子弹返回弹匣时形成的弧形轨迹，也可以对沿途的敌人造成伤害。", "The arc a round traces as it flies back into the magazine also damages enemies along the way."],
	"gravity": [2, "引力井", "GRAVITY WELL", "按住 Q 时，已经嵌入目标的子弹会产生引力效果，将附近的敌人吸向嵌入位置。", "While you hold Q, embedded rounds pull nearby enemies toward them."],
	"zeroblade": [2, "归零之刃", "ZERO EDGE", "同一次回收中，每次贯穿目标都会让本次回收伤害乘以 1.08，最高可以叠加到 4 倍。", "In one recall, every pierce multiplies that recall's damage by 1.08, stacking up to ×4."],
	"undying": [2, "不灭", "UNDYING", "每章可以触发 1 次。当最后一格裂痕即将被击碎时，自动抵消这次攻击。", "Once per chapter: when your last crack is about to break, the blow is cancelled."],
	"edge": [0, "棱边", "HONED EDGE", "子弹每次经过墙面、镜面或棱镜反射，造成的伤害都会提高 25%。", "Each time a round bends off a wall, mirror or prism, its damage rises by 25%."],
	"steady": [0, "稳手", "STEADY HAND", "保持原地不动时，射击速度提高 40%。", "Fire rate +40% while standing still."],
	"spare_round": [0, "备弹", "SPARE ROUNDS", "弹匣中的子弹全部打完后，最早嵌入目标的 3 颗子弹会立即返回弹匣。", "When the magazine runs dry, the 3 earliest embedded rounds come straight back to it."],
	"thick": [0, "厚壳", "THICK SHELL", "裂痕上限增加 1 格，并立即修复 1 格裂痕。", "Crack limit +1, and mend 1 crack now."],
	"refract": [1, "棱镜心", "PRISM HEART", "去程子弹第一次命中敌人后，会偏转 30° 并继续向前飞行。", "An outbound round bends 30° after its first enemy hit and keeps flying."],
	"focus_lens": [1, "聚焦", "FOCUS LENS", "按住 Q 超过 0.8 秒后再松开，本次回收造成的伤害提高 40%。", "Hold Q for more than 0.8 s, then release: that recall deals 40% more damage."],
	"mirror_skin": [1, "镜肤", "MIRROR SKIN", "受到攻击时，所有已经嵌入目标的子弹都会立即回收。", "When you are hit, every embedded round recalls at once."],
	"hunter": [1, "猎手", "HUNTER", "首次命中生命值全满的敌人时，造成的伤害提高 50%。", "Your first hit on an enemy at full health deals 50% more damage."],
	"twin": [2, "双生", "TWIN", "每次射击都会额外发射 1 颗小型分裂弹，不会消耗弹匣中的子弹。", "Every shot also fires 1 small split round, without using magazine ammo."],
	"eclipse": [2, "日蚀", "ECLIPSE", "单次回收达到 12 颗子弹时，本次回收造成的伤害翻倍。", "A recall of 12 rounds or more deals double damage."],
	"magnetic_tip": [0, "磁尖", "MAGNETIC TIP", "已经嵌入目标的子弹会使周围 120 像素范围内的敌人减速 30%。", "Embedded rounds slow enemies within 120 px by 30%."],
	"quick_recall": [0, "疾归", "SWIFT RETURN", "子弹的返程飞行速度提高 30%。", "Returning rounds fly 30% faster."],
	"lean": [0, "轻装", "TRAVEL LIGHT", "移动速度提高 12%。", "Move speed +12%."],
	"first_blood": [0, "先声", "OPENING SHOT", "每波战斗第一次命中敌人时，造成 3 倍伤害。", "Your first hit on an enemy each wave deals triple damage."],
	"leech_ward": [1, "护弹", "KEEPSAKE", "按住 Q 时，被敌人偷走或吞下的子弹都会立即返回。", "While you hold Q, rounds stolen or swallowed by enemies come straight back."],
	"echo": [1, "回响", "ECHO", "每次回收结束后，第一个被贯穿的敌人会额外受到伤害，数值为本次贯穿总次数乘以 6。", "When a recall ends, the first enemy it pierced takes extra damage equal to that recall's total pierces × 6."],
	"brace": [1, "架势", "BRACE", "按住 Q 期间不会受到任何伤害。", "You take no damage at all while holding Q."],
	"overflow": [1, "满溢", "BRIMMING", "弹匣处于满弹状态时发射的子弹，造成的伤害提高 40%。", "Shots fired while the magazine is full deal 40% more damage."],
	"singularity": [2, "奇点", "SINGULARITY", "单次回收累计贯穿达到 20 次时，场上所有敌人都会受到 50 点伤害。", "When one recall reaches 20 pierces in total, every enemy on the field takes 50 damage."],
	"phoenix": [2, "涅槃", "PHOENIX", "每局可以触发 1 次。当所有裂痕全部被击碎时，立即恢复 3 格裂痕。", "Once per run: when all your cracks are broken, 3 cracks are restored at once."],
	"downbeat": [0, "踩点", "DOWNBEAT", "在节拍点松开 Q，本次回收造成的伤害提高 30%。", "Release Q on the beat: that recall deals 30% more damage."],
	"reserve": [0, "储备", "RESERVE", "弹匣容量增加 3 发。", "Magazine +3 rounds."],
	"swift_feet": [0, "疾步", "SWIFT FEET", "闪避移动距离增加 40%。", "Dash distance +40%."],
	"heavy": [0, "重弹", "HEAVY ROUNDS", "去程子弹伤害提高 25%，但射击速度降低 10%。", "Outbound damage +25%, but fire rate -10%."],
	"beat_heart": [1, "节拍心", "BEAT HEART", "每经过 8 个节拍，所有已经嵌入目标的子弹都会释放一次脉冲，对周围敌人造成 8 点伤害。", "Every 8 beats, every embedded round releases a pulse dealing 8 damage to enemies around it."],
	"afterburn": [1, "余烬", "AFTERBURN", "被返程子弹命中的敌人会进入燃烧状态，持续 2 秒。", "Enemies hit by returning rounds burn for 2 s."],
	"vampire": [1, "汲取", "DRAIN", "每累计完成 40 次返程贯穿，就能修复 1 格裂痕。", "Every 40 returning pierces in total mend 1 crack."],
	"grit": [1, "坚韧", "GRIT", "受到攻击后获得 2 秒无敌效果，并在接下来的 3 秒内提高 20% 的伤害。", "After taking a hit, you are invulnerable for 2 s and deal 20% more damage for the next 3 s."],
	"crescendo": [2, "渐强", "CRESCENDO", "在 4 秒内连续进行回收，每次回收造成的伤害都会额外提高 25%，最多提高 100%。", "Recall again within 4 s: each recall deals an extra 25% damage, up to 100%."],
	"time_lord": [2, "时主", "TIME LORD", "按住 Q 时，所有敌人都会完全停止行动。", "While you hold Q, every enemy stops completely."],
	"long_barrel": [0, "长管", "LONG BARREL", "子弹飞行速度提高 30%。", "Rounds fly 30% faster."],
	"wide_ring": [0, "宽环", "WIDE RING", "行星轨道半径增加 40%，轨道造成的伤害提高 50%。", "Orbit radius +40%, and orbit damage +50%."],
	"spark": [0, "火花", "SPARK", "子弹嵌入目标时，会对周围 30 像素范围内的敌人造成 6 点伤害。", "When a round embeds, it deals 6 damage to enemies within 30 px."],
	"second_wind": [0, "回气", "SECOND WIND", "每完成 3 波战斗，就能修复 1 格裂痕。", "Every 3 waves cleared mend 1 crack."],
	"homing_spark": [1, "回镜", "RETURN SPARK", "每颗子弹返回弹匣时，都会额外向距离最近的敌人发射 1 颗免费小弹。", "Each round that returns to the magazine also fires 1 free small round at the nearest enemy."],
	"zero_point": [1, "零点", "ZERO POINT", "回收过程中，每颗子弹第一次命中敌人时都会造成双倍伤害。", "During a recall, each round's first hit on an enemy deals double damage."],
	"sniper": [1, "狙击", "SNIPER", "去程子弹每飞行 100 像素，造成的伤害就会提高 4%。", "Outbound rounds deal 4% more damage for every 100 px flown."],
	"fortress": [1, "堡垒", "FORTRESS", "每损失 1 格裂痕，造成的伤害就会提高 8%。", "Each crack lost raises your damage by 8%."],
	"overkill": [2, "余波", "OVERKILL", "击杀敌人时，超出其剩余生命值的伤害会有 50% 转移到距离最近的其他敌人身上。", "When you kill an enemy, 50% of the damage beyond its remaining health carries over to the nearest other enemy."],
	"encore": [2, "安可", "ENCORE", "每波战斗的第一次回收结束后，会额外触发一次影子回收，造成原本 60% 的伤害。", "After each wave's first recall ends, a shadow recall follows, dealing 60% of the original damage."],
	"keen_edge": [0, "锋刃", "KEEN EDGE", "子弹返程造成的伤害提高 15%。", "Returning damage +15%."],
	"deep_focus": [0, "深定", "DEEP FOCUS", "按住 Q 时可以让时间进一步减慢，同时将持续时间延长 0.3 秒。", "Holding Q slows time even further and lasts 0.3 s longer."],
	"lucky": [1, "幸运", "LUCKY", "每章额外获得 1 次刷新机会。", "1 extra reroll each chapter."],
	"glass_cannon": [1, "玻璃炮", "GLASS CANNON", "所有伤害提高 40%，但裂痕上限减少 1 格。", "All damage +40%, but crack limit -1."],
	"apex": [2, "顶点", "APEX", "同时拥有 3 个达到 3 级的流派时，所有伤害提高至原来的 1.5 倍。", "With 3 schools at Lv3 at once, all damage becomes 1.5×."],
}

# id: [how the number reads in its description, rank 1, rank 2, rank 3]. Rank 2
# is about ×1.25 of the bonus and rank 3 ×1.5, more where a bonus sits on top of
# the base (+50% to +75% is only a sixth more damage), so a rank can be felt.
# A relic not listed is a switch, on or off, and has no ranks.
const STARS := {
	"whet": ["+%s%%", 50.0, 70.0, 90.0],
	"quick": ["+%s%%", 25.0, 31.0, 37.0],
	"deepmag": ["+%s", 6.0, 9.0, 12.0],
	"longfuse": ["%s", 20.0, 22.0, 24.0],
	"lightstep": ["-%s%%", 40.0, 50.0, 60.0],
	"aftershock": ["%s", 25.0, 31.0, 37.0],
	"chain": ["+%s%%", 6.0, 7.5, 9.0],
	"critical": ["×%s", 2.0, 2.5, 3.0],
	"crossfire": ["%s", 60.0, 75.0, 90.0],
	"stillheart": ["%s", 2.0, 2.5, 3.0],
	"reaper": ["+%s%%", 12.0, 15.0, 18.0],
	"zeroblade": ["×%s", 1.08, 1.11, 1.14],
	"edge": ["+%s%%", 25.0, 31.0, 37.0],
	"steady": ["+%s%%", 40.0, 50.0, 60.0],
	"spare_round": ["%s", 3.0, 5.0, 7.0],
	"focus_lens": ["+%s%%", 40.0, 60.0, 80.0],
	"hunter": ["+%s%%", 50.0, 75.0, 100.0],
	"eclipse": ["×%s", 2.0, 2.5, 3.0],
	"magnetic_tip": ["%s%%", 30.0, 37.0, 45.0],
	"quick_recall": ["%s%%", 30.0, 37.0, 45.0],
	"lean": ["%s%%", 12.0, 15.0, 18.0],
	"first_blood": ["×%s", 3.0, 4.0, 5.0],
	"echo": ["%s", 6.0, 7.5, 9.0],
	"overflow": ["+%s%%", 40.0, 60.0, 80.0],
	"singularity": ["%s", 50.0, 62.0, 75.0],
	"downbeat": ["+%s%%", 30.0, 45.0, 60.0],
	"reserve": ["+%s", 3.0, 5.0, 7.0],
	"swift_feet": ["%s%%", 40.0, 50.0, 60.0],
	"heavy": ["+%s%%", 25.0, 40.0, 55.0],
	"beat_heart": ["%s", 8.0, 10.0, 12.0],
	"afterburn": ["%s", 2.0, 2.5, 3.0],
	"vampire": ["%s", 40.0, 32.0, 27.0],
	"grit": ["+%s%%", 20.0, 25.0, 30.0],
	"crescendo": ["+%s%%", 25.0, 31.0, 37.0],
	"long_barrel": ["%s%%", 30.0, 37.0, 45.0],
	"wide_ring": ["+%s%%", 50.0, 62.0, 75.0],
	"spark": ["%s", 6.0, 7.5, 9.0],
	"zero_point": ["×%s", 2.0, 2.5, 3.0],
	"sniper": ["+%s%%", 4.0, 5.0, 6.0],
	"fortress": ["+%s%%", 8.0, 10.0, 12.0],
	"overkill": ["%s%%", 50.0, 62.0, 75.0],
	"encore": ["%s%%", 60.0, 75.0, 90.0],
	"keen_edge": ["+%s%%", 15.0, 25.0, 35.0],
	"deep_focus": ["%s", 0.3, 0.4, 0.5],
	"glass_cannon": ["+%s%%", 40.0, 50.0, 60.0],
	"apex": ["×%s", 1.5, 1.6, 1.75],
}

# id: [name zh, name en, desc zh, desc en]
const ITEMS := {
	"patch": ["修补", "PATCH", "立即修复 1 格裂痕。", "Mend 1 crack now."],
	"overload": ["过载", "OVERLOAD", "下一次子弹回收造成 3 倍伤害。", "Your next recall deals triple damage."],
	"spare": ["备用刷新", "SPARE REROLL", "当前章节的刷新次数增加 1 次。", "+1 reroll for the current chapter."],
	"firststrike": ["先手", "FIRST STRIKE", "下一波敌人登场时，生命值只有最大生命值的 50%。", "The next wave of enemies arrives with only 50% of their max health."],
	"stasis": ["时滞", "STASIS", "下一波战斗开始后的前 6 秒内，所有敌人的行动速度都会降低至正常的 30%。", "For the first 6 s of the next wave, every enemy moves at 30% of normal speed."],
	"ward": ["护盾", "WARD", "可以抵消本章接下来受到的 1 次伤害。", "Cancels the next 1 hit you take this chapter."],
	"longhold": ["凝神", "LONG BREATH", "下一波战斗中，按住 Q 最多可以维持 3 秒。", "Next wave: hold Q for up to 3 s."],
	"recall_order": ["回收令", "RECALL ORDER", "立即将被敌人偷走或吞下的子弹全部送回弹匣。", "Every round stolen or swallowed by enemies goes straight back to your magazine."],
	"slowfield": ["迟滞场", "DRAG FIELD", "下一波战斗期间，所有敌人的行动速度降低至正常的 80%。", "During the next wave, every enemy moves at 80% of normal speed."],
	"tempo": ["加速", "TEMPO", "下一波战斗中，射击速度提高 40%。", "Next wave: fire rate +40%."],
	"mend_all": ["大修补", "OVERHAUL", "立即修复 2 格裂痕。", "Mend 2 cracks now."],
	"haste": ["疾风", "TAILWIND", "下一波战斗中，移动速度提高 25%。", "Next wave: move speed +25%."],
	"calm_mind": ["静心", "STILL MIND", "下一波战斗中，子弹回收造成的伤害提高 20%。", "Next wave: recalls deal 20% more damage."],
	"card_luck": ["好运", "GOOD FORTUNE", "下一次选择卡牌时，至少会出现 1 张传说遗物卡牌。", "Your next card pick shows at least 1 legendary relic card."],
	"rewind": ["回溯", "REWIND", "立即重置所有嵌入子弹的熄灭倒计时。", "Reset the go-dark countdown of every embedded round now."],
}

const RARITY_WEIGHT := [[70.0, 25.0, 5.0], [60.0, 31.0, 9.0], [50.0, 36.0, 14.0], [42.0, 40.0, 18.0], [35.0, 42.0, 23.0]]


static func relic_name(id: String) -> String:
	return RELICS[id][1] if Txt.zh else RELICS[id][2]


# The description at a rank: the one number that rises is swapped in place,
# or, on the card that raises it, shown going from the old to the new.
static func relic_desc(id: String, star := 1, rising := false) -> String:
	var d: String = RELICS[id][3] if Txt.zh else RELICS[id][4]
	if star <= 1 or not STARS.has(id):
		return d
	var s: Array = STARS[id]
	var from: String = s[0] % num(s[1])
	var at := d.rfind(from)
	if at < 0:
		return d
	var now: String = s[0] % num(s[star])
	if rising:
		now = (s[0] % num(s[star - 1])) + " → " + now
	return d.substr(0, at) + now + d.substr(at + from.length())


# What the next rank would read; "" at the top rank.
static func next_value(id: String, star: int) -> String:
	if star >= MAX_STAR:
		return ""
	return STARS[id][0] % num(STARS[id][star + 1])


static func num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else String.num(v, 2)


# A relic's number at a rank.
static func sv(id: String, star: int) -> float:
	return STARS[id][star]


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
				c = _item(game)
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
		# no use before light-speed travel itself is yours
		if k == "walk" and not game.lightwalk.available():
			continue
		pool.append(k)
	if pool.is_empty():
		return {}
	var id: String = pool[randi() % pool.size()]
	return {"type": "school", "id": id, "level": game.lv.get(id, 0), "full": game.lv.get(id, 0) == 0 and held >= SCHOOL_SLOTS}


static func _relic(game, chapter: int) -> Dictionary:
	# the case is full: most draws now raise something you hold
	if game.relics.size() >= RELIC_SLOTS and randf() < UP_CHANCE and not game.armed.get("card_luck", false):
		var ups: Array = []
		for id in game.relics:
			if STARS.has(id) and game.star(id) < MAX_STAR and _useful(game, id):
				ups.append(id)
		if not ups.is_empty():
			var u: String = ups[randi() % ups.size()]
			return {"type": "relic", "id": u, "star": game.star(u) + 1}
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
		if RELICS[id][0] == rarity and not game.relics.has(id) and _useful(game, id):
			pool.append(id)
	if pool.is_empty():
		for id in RELICS:
			if not game.relics.has(id) and _useful(game, id):
				pool.append(id)
	if pool.is_empty():
		return {}
	return {"type": "relic", "id": pool[randi() % pool.size()]}


# No card is offered that could do nothing for you here.
static func _useful(game, id: String) -> bool:
	match id:
		"wide_ring":
			return game.lv.get("orbit", 0) > 0
		"leech_ward":
			return Chapters.story(game.chapter) >= STEAL_FROM
	return true


static func _item(game) -> Dictionary:
	var pool: Array = []
	for id in ITEMS:
		if _item_useful(game, id):
			pool.append(id)
	if pool.is_empty():
		return {}
	return {"type": "item", "id": pool[randi() % pool.size()]}


static func _item_useful(game, id: String) -> bool:
	match id:
		"patch", "mend_all":
			return game.cracks < game.max_cracks
		"recall_order":
			return game.bullets.count_state(Bullets.CAPTURED) > 0
		"rewind":
			return game.bullets.count_state(Bullets.EMBED) > 0
		"card_luck":
			return Meta.unlocked(LEGEND_LOCK)
		"firststrike", "stasis", "slowfield":
			# the boss is next: these would only reach its small fry
			return game.wave_ctl.index + 1 != Waves.BOSS
	return true
