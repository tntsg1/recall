class_name Ach
# Thirty achievements. They live in the meta save and are mirrored to Steam
# through SteamBridge when it is present.

# id: [name zh, name en, desc zh, desc en]
const LIST := {
	"first_recall": ["归来", "COME BACK", "完成第一次子弹回收。", "Complete your first recall."],
	"pierce10": ["穿针", "THREAD", "单次回收累计贯穿 10 次。", "Pierce 10 times in total in one recall."],
	"pierce30": ["引线", "WEAVE", "单次回收累计贯穿 30 次。", "Pierce 30 times in total in one recall."],
	"pierce60": ["织网", "THE NET", "单次回收累计贯穿 60 次。", "Pierce 60 times in total in one recall."],
	"boss_1": ["终点站", "LAST STOP", "成功击毁中央直达专列。", "Destroy the Central Express."],
	"boss_2": ["碎镜", "BROKEN GLASS", "成功击碎镜面守卫。", "Shatter the Mirror Warden."],
	"boss_3": ["反刍", "SPAT OUT", "击败战略储备回收机。", "Defeat the Strategic Reserve Intake."],
	"boss_4": ["停摆", "STOPPED CLOCK", "成功摧毁情绪同步器。", "Destroy the Mood Synchroniser."],
	"boss_5": ["归零", "ZEROED", "击败 Boss“归零”。", "Defeat the boss Zero."],
	"win": ["一局", "A FULL RUN", "成功完成一局游戏。", "Complete a run."],
	"win_stake4": ["铁一般", "IRON NERVE", "在“铁”或更高难度下完成通关。", "Clear the game on Iron or higher."],
	"win_stake8": ["红线", "RED LINE", "在“红”难度下完成通关。", "Clear the game on Red."],
	"nohit_chapter": ["无痕", "UNMARKED", "在整个章节中没有受到任何攻击。", "Take no hits for an entire chapter."],
	"all_s_chapter": ["满分", "STRAIGHT S", "单章所有波次均获得 S 评级。", "Get an S on every wave of one chapter."],
	"relics5": ["满箱", "FULL CASE", "同时装备满 5 件遗物。", "Equip a full 5 relics at once."],
	"school3": ["专精", "MASTERY", "将任意一个流派提升至 3 级。", "Raise any school to Lv3."],
	"two_school3": ["双修", "TWO ARTS", "同时拥有两个达到 3 级的流派。", "Have two schools at Lv3 at the same time."],
	"kills_300": ["清场", "CLEARANCE", "累计击败 300 名敌人。", "Defeat 300 enemies in total."],
	"kills_3000": ["长夜", "LONG NIGHT", "累计击败 3000 名敌人。", "Defeat 3,000 enemies in total."],
	"runs10": ["老练", "SEASONED", "累计进行 10 局游戏。", "Play 10 runs in total."],
	"steal12": ["物归原主", "RETURN TO SENDER", "在同一局游戏中，从“归零”手中夺回 12 颗被偷走的子弹。", "In one run, take back 12 stolen rounds from Zero."],
	"leech4": ["失而复得", "FOUND AGAIN", "击败一只携带 4 颗子弹的吸附者。", "Defeat a leech carrying 4 rounds."],
	"beat10": ["合拍", "ON THE BEAT", "累计 10 次在正确的节拍点松开 Q。", "Release Q on the beat 10 times in total."],
	"crit20": ["临界点", "TIPPING POINT", "累计回收 20 颗即将熄灭的子弹。", "Recall 20 rounds that were about to go dark, in total."],
	"cross50": ["交叉网", "CROSSHATCH", "累计触发 50 次交叉攻击，也就是让 3 条返程轨迹穿过同一个敌人。", "Trigger 50 crossfires in total, sending 3 return paths through the same enemy."],
	"mirror8": ["万花筒", "KALEIDOSCOPE", "让同一颗子弹完成 8 次反射。", "Make one round bend 8 times."],
	"orbit20": ["星环", "RING SYSTEM", "让场上同时存在 20 颗轨道弹。", "Have 20 orbiting rounds on the field at once."],
	"no_reroll": ["不回头", "NO SECOND LOOK", "整局游戏没有刷新过任何卡牌，并成功完成通关。", "Clear a run without ever rerolling a card."],
	"guns3": ["三把枪", "THREE GUNS", "使用 3 种不同的弹匣完成通关。", "Clear the game with 3 different magazines."],
	"fast_ch1": ["快车", "EXPRESS", "在 150 秒内完成第 1 章。", "Clear chapter 1 within 150 s."],
}


static func name_of(id: String) -> String:
	return LIST[id][0] if Txt.zh else LIST[id][1]


static func desc_of(id: String) -> String:
	return LIST[id][2] if Txt.zh else LIST[id][3]
