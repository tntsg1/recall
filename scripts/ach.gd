class_name Ach
# Thirty achievements. They live in the meta save and are mirrored to Steam
# through SteamBridge when it is present.

# id: [name zh, name en, desc zh, desc en]
const LIST := {
	"first_recall": ["归来", "COME BACK", "第一次回收", "Recall for the first time"],
	"pierce10": ["穿针", "THREAD", "一次回收贯穿 10 次", "Pierce 10 times in one recall"],
	"pierce30": ["引线", "WEAVE", "一次回收贯穿 30 次", "Pierce 30 times in one recall"],
	"pierce60": ["织网", "THE NET", "一次回收贯穿 60 次", "Pierce 60 times in one recall"],
	"boss_1": ["终点站", "LAST STOP", "击毁中央直达专列", "Destroy the Central Express"],
	"boss_2": ["碎镜", "BROKEN GLASS", "击碎镜面守卫", "Shatter the Mirror Warden"],
	"boss_3": ["反刍", "SPAT OUT", "击败战略储备回收机", "Defeat the Reserve Intake"],
	"boss_4": ["停摆", "STOPPED CLOCK", "击败情绪同步器", "Stop the Mood Synchroniser"],
	"boss_5": ["归零", "ZEROED", "击败归零", "Defeat Zero"],
	"win": ["一局", "A FULL RUN", "通关一局", "Finish a run"],
	"win_stake4": ["铁一般", "IRON NERVE", "在“铁”或更高难度通关", "Finish on Iron or higher"],
	"win_stake8": ["红线", "RED LINE", "在“红”难度通关", "Finish on Red"],
	"nohit_chapter": ["无痕", "UNMARKED", "一整章没有受击", "Clear a chapter without a hit"],
	"all_s_chapter": ["满分", "STRAIGHT S", "一章所有波次都是 S", "Every wave of a chapter graded S"],
	"relics5": ["满箱", "FULL CASE", "同时装满 5 个遗物", "Hold five relics"],
	"school3": ["专精", "MASTERY", "一个流派升到 3 级", "Raise a school to Lv3"],
	"two_school3": ["双修", "TWO ARTS", "两个流派同时 3 级", "Two schools at Lv3"],
	"kills_300": ["清场", "CLEARANCE", "累计击杀 300", "300 kills in total"],
	"kills_3000": ["长夜", "LONG NIGHT", "累计击杀 3000", "3000 kills in total"],
	"runs10": ["老练", "SEASONED", "玩 10 局", "Play 10 runs"],
	"steal12": ["物归原主", "RETURN TO SENDER", "一局里偷回归零 12 颗子弹", "Turn 12 of Zero's rounds back on it in one run"],
	"leech4": ["失而复得", "FOUND AGAIN", "打死一只带着 4 颗子弹的吸附者", "Kill a leech carrying four rounds"],
	"beat10": ["合拍", "ON THE BEAT", "在拍点上松开 Q 共 10 次", "Release Q on the beat 10 times"],
	"crit20": ["临界点", "TIPPING POINT", "回收 20 颗快熄灭的子弹", "Recall 20 rounds in their last 3 s"],
	"cross50": ["交叉网", "CROSSHATCH", "累计 50 次交叉（三条返程穿过同一敌人）", "50 crosses (three returns through one enemy)"],
	"mirror8": ["万花筒", "KALEIDOSCOPE", "一颗子弹反射 8 次", "One round bent 8 times"],
	"orbit20": ["星环", "RING SYSTEM", "同时有 20 颗轨道弹", "20 rounds in orbit at once"],
	"no_reroll": ["不回头", "NO SECOND LOOK", "一局不刷新卡牌并通关", "Finish a run without rerolling"],
	"guns3": ["三把枪", "THREE GUNS", "用 3 种不同弹匣通关", "Finish with three different magazines"],
	"fast_ch1": ["快车", "EXPRESS", "第 1 章总用时 150 秒以内", "Clear chapter 1 in 150 s or less"],
}


static func name_of(id: String) -> String:
	return LIST[id][0] if Txt.zh else LIST[id][1]


static func desc_of(id: String) -> String:
	return LIST[id][2] if Txt.zh else LIST[id][3]
