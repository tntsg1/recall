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
	2: {
		Enemies.CHASER: [["逾期账户一律追回。包括账户的主人。", "OVERDUE ACCOUNTS ARE RECOVERED. THEIR OWNERS TOO."],
			["编号 0417 出生登记完成。资产状态：良好。", "NO. 0417 BIRTH REGISTERED. ASSET CONDITION: GOOD."]],
		Enemies.GUARD: [["排队请保持微笑。微笑计入考评。", "PLEASE SMILE IN THE QUEUE. SMILES ARE ASSESSED."]],
		Enemies.CHARGER: [["退休窗口今日不开放。明天也不。", "THE RETIREMENT WINDOW IS CLOSED TODAY. AND TOMORROW."]],
		Enemies.PRISM: [["我把光折进镜子里，让每个人看起来都很幸福。", "I BEND THE LIGHT INTO THE MIRRORS SO EVERYONE LOOKS HAPPY."]],
	},
	3: {
		Enemies.CHASER: [["测试对象编号 R-0。处置等级：无需审批。", "TEST SUBJECT R-0. DISPOSAL LEVEL: NO APPROVAL NEEDED."],
			["出厂说明：对外防御。验收地点：第十三街。", "FACTORY NOTE: FOR EXTERNAL DEFENCE. ACCEPTANCE SITE: 13TH STREET."]],
		Enemies.ECHO: [["它走过的路我都记得。我被造出来就是为了这个。", "I REMEMBER EVERY STEP IT TOOK. THAT IS WHAT I WAS MADE FOR."]],
		Enemies.GUARD: [["防暴盾第九版：更轻，更结实，更朝向人群。", "RIOT SHIELD V9: LIGHTER, STRONGER, MORE FACING THE CROWD."]],
		Enemies.CHARGER: [["靶纸上画的不是敌军。是排队的人。", "THE TARGETS DON'T SHOW ENEMY SOLDIERS. THEY SHOW PEOPLE IN A QUEUE."]],
	},
	4: {
		Enemies.CHASER: [["工人编号 2207。本月产出 1400 件。个人配额：0。", "WORKER 2207. OUTPUT THIS MONTH: 1,400 UNITS. PERSONAL QUOTA: 0."],
			["他们说储备是为了将来。我没见过将来。", "THEY SAY THE RESERVE IS FOR THE FUTURE. I HAVE NEVER SEEN THE FUTURE."]],
		Enemies.GUARD: [["守卫储备仓第三年。仓门一次也没开过。", "THIRD YEAR GUARDING THE RESERVE. THE DOOR HAS NEVER OPENED."]],
		Enemies.CHARGER: [["装配线每年提速一成。工人的工资不变。", "THE LINE RUNS TEN PER CENT FASTER EVERY YEAR. THE WAGES DO NOT."]],
		Enemies.LEECH: [["我把一切吸进来，再交上去。自己什么也不留。", "I TAKE EVERYTHING IN AND HAND IT UP. I KEEP NOTHING."]],
	},
	5: {
		Enemies.CHASER: [["押运第 9 年。车厢里装着什么，我没有权限知道。", "NINE YEARS ESCORTING. WHAT THE CARS CARRY, I AM NOT CLEARED TO KNOW."],
			["车过第十三街时会鸣笛。不是打招呼，是让人让开。", "IT SOUNDS ITS HORN AT 13TH STREET. NOT A GREETING. A WARNING TO MOVE."]],
		Enemies.GUARD: [["站台上的人想上车。我的任务是让他们一直想。", "THE PEOPLE ON THE PLATFORM WANT TO BOARD. MY JOB IS TO KEEP THEM WANTING."]],
		Enemies.CHARGER: [["专列时速六百。第十三街的公交，上次来是三年前。", "THE EXPRESS RUNS AT SIX HUNDRED. 13TH STREET'S BUS LAST CAME THREE YEARS AGO."]],
		Enemies.PRISM: [["我把站台的灯调亮，让等车的人看起来有希望。", "I TURN UP THE PLATFORM LIGHTS SO THE WAITING LOOK HOPEFUL."]],
		Enemies.LEECH: [["货单上写着“民生物资”。终点写着“中央储备”。", "THE MANIFEST SAYS 'GOODS FOR THE PEOPLE'. THE DESTINATION SAYS 'CENTRAL RESERVE'."]],
	},
	6: {
		Enemies.CHASER: [["抄表员 3301。第十三街的电表，指针从来不动。", "METER READER 3301. ON 13TH STREET THE NEEDLES NEVER MOVE."],
			["他们说限电是暂时的。暂时了十一年。", "THEY SAID THE RATIONING WAS TEMPORARY. ELEVEN YEARS TEMPORARY."]],
		Enemies.GUARD: [["配电柜要上锁。锁比电贵。", "THE CABINETS MUST BE LOCKED. THE LOCKS COST MORE THAN THE POWER."]],
		Enemies.CHARGER: [["中央的灯整夜亮着。说是为了安全。", "THE CENTRE'S LIGHTS BURN ALL NIGHT. FOR SAFETY, THEY SAY."]],
		Enemies.LEECH: [["我把多余的电收回来，再卖回给他们。", "I TAKE BACK THE SPARE POWER AND SELL IT TO THEM AGAIN."]],
		Enemies.INSPECTOR: [["我关掉每一盏不该亮的灯。今天关了三千盏。", "I PUT OUT EVERY LIGHT THAT SHOULD NOT BE ON. THREE THOUSAND TODAY."]],
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
	2: [
		["terminal", Vector2(80, 300), Vector2(1, 0), "terminal", "新生儿资产登记 · 终身劳动账户已开通", "NEWBORN ASSET REGISTERED · LIFETIME LABOUR ACCOUNT OPENED"],
		["gate", Vector2(1500, 70), Vector2(0, 1), "plaque", "请出示股东卡 · 未持卡者按遗失物品处理", "SHOW YOUR SHAREHOLDER CARD · THE CARDLESS ARE LOST PROPERTY"],
		["queue", Vector2(1240, 1010), Vector2(0, -1), "floor", "等候区 · 请勿越线 · 请勿思考", "WAITING AREA · DO NOT CROSS · DO NOT THINK"],
		["retire", Vector2(1840, 760), Vector2(-1, 0), "notice", "本年度退休申请批准 0 份。感谢您的耐心。", "RETIREMENT APPLICATIONS APPROVED THIS YEAR: 0. THANK YOU FOR YOUR PATIENCE."],
	],
	3: [
		["log", Vector2(80, 600), Vector2(1, 0), "screen", "第 4127 次测试：目标为非武装人员。结果：合格。", "TEST 4127: TARGET UNARMED. RESULT: PASSED."],
		["target", Vector2(1840, 600), Vector2(-1, 0), "sheet", "C 型靶标：成人 · 手无寸铁 · 排队姿势", "TARGET TYPE C: ADULT · UNARMED · QUEUEING"],
		["crate", Vector2(285, 860), Vector2(0, -1), "crate", "人民卫士 Ⅳ 型 · 仅限国内使用", "PEOPLE'S GUARDIAN MK IV · DOMESTIC USE ONLY"],
		["safety", Vector2(1490, 1010), Vector2(0, -1), "notice", "试射期间请勿抗议。抗议者将被视为测试目标。", "DO NOT PROTEST DURING LIVE FIRE. PROTESTERS WILL BE TREATED AS TARGETS."],
	],
	4: [
		["board", Vector2(80, 260), Vector2(1, 0), "screen", "今日产出口粮 98400 份 · 入库 98105 · 发放 295", "RATIONS MADE TODAY 98,400 · TO RESERVE 98,105 · ISSUED 295"],
		["crate", Vector2(315, 845), Vector2(0, -1), "crate", "战略储备 · 开启须经全民董事会批准", "STRATEGIC RESERVE · OPENING REQUIRES THE BOARD'S APPROVAL"],
		["notice", Vector2(1500, 70), Vector2(0, 1), "notice", "为庆祝产量再创新高，午餐时间缩短为 4 分钟。", "TO CELEBRATE RECORD OUTPUT, LUNCH IS NOW FOUR MINUTES."],
		["scrawl", Vector2(1840, 820), Vector2(-1, 0), "scrawl", "我们造的面包，我们买不起。", "WE BAKE THE BREAD. WE CAN'T AFFORD IT."],
	],
	5: [
		["timetable", Vector2(80, 300), Vector2(1, 0), "screen", "下一班：中央专列 · 本站不停 · 候车：无限期", "NEXT: CENTRAL EXPRESS · DOES NOT STOP HERE · WAIT: INDEFINITE"],
		["yellow", Vector2(1185, 1010), Vector2(0, -1), "sign", "请勿越过黄线 · 越线者按货物处理", "DO NOT CROSS THE YELLOW LINE · THOSE WHO DO ARE CARGO"],
		["manifest", Vector2(1525, 530), Vector2(0, -1), "crate", "货单：民生物资 1200 吨 · 收货方：中央储备", "MANIFEST: GOODS FOR THE PEOPLE, 1,200 T · CONSIGNEE: CENTRAL RESERVE"],
		["scrawl", Vector2(300, 70), Vector2(0, 1), "scrawl_top", "它每天都经过。我们一次也没上去。", "IT PASSES EVERY DAY. WE HAVE NEVER BEEN ON IT."],
	],
	6: [
		["ledger", Vector2(80, 700), Vector2(1, 0), "screen", "本月配额：中央区 98.6% · 第十三街 0.02%", "THIS MONTH: CENTRAL 98.6% · 13TH STREET 0.02%"],
		["cabinet", Vector2(1840, 700), Vector2(-1, 0), "notice", "私接电线者，按窃取国家资产论处", "ANYONE WIRING THEIR OWN LINE WILL BE TREATED AS A THIEF OF STATE ASSETS"],
		["notice", Vector2(1840, 205), Vector2(-1, 0), "notice", "节约用电是每位股东的美德。今晚 19 点至次日 7 点停电。", "SAVING POWER IS EVERY SHAREHOLDER'S VIRTUE. NO POWER 19:00 TO 07:00 TONIGHT."],
		["scrawl", Vector2(1320, 70), Vector2(0, 1), "scrawl_top", "我们自己接的线，比他们的灯亮。", "THE LINE WE WIRED OURSELVES BURNS BRIGHTER THAN THEIR LIGHTS."],
	],
}

const RADIO := {
	1: {
		"wave": [["第十三街一处设备发生故障。请市民不要围观，安全水平正常。", "A DEVICE FAULT ON 13TH STREET. PLEASE DO NOT GATHER. SAFETY LEVELS NORMAL."],
			["本区安保机器人今日完成自愿退役计划。", "LOCAL SECURITY UNITS COMPLETED VOLUNTARY RETIREMENT TODAY."]],
		"boss": [["第十三街封锁设备提前完成维护，通行效率显著优化。", "13TH STREET'S LOCKDOWN UNIT FINISHED MAINTENANCE EARLY. FLOW GREATLY OPTIMISED."]],
	},
	2: {
		"wave": [["资产管理中心今日接待股东十二万人次，满意度 100%。", "THE ASSET CENTRE RECEIVED 120,000 SHAREHOLDERS TODAY. SATISFACTION 100%."],
			["近日有不明设备擅入登记大厅。资产安全不受影响。", "AN UNKNOWN DEVICE ENTERED THE REGISTRATION HALL. ASSETS REMAIN SECURE."]],
		"boss": [["镜面守卫提前结束服役。大厅将换上更明亮的镜子。", "THE MIRROR WARDEN HAS RETIRED EARLY. THE HALL WILL GET BRIGHTER MIRRORS."]],
	},
	3: {
		"wave": [["仿生军械研究院今日完成例行测试。一切武器均用于守护和平。", "THE BIONIC ORDNANCE INSTITUTE FINISHED ROUTINE TESTS. ALL WEAPONS SERVE PEACE."],
			["请勿靠近研究院围墙。围墙后面就是和平。", "KEEP AWAY FROM THE INSTITUTE WALLS. BEHIND THEM IS PEACE."]],
		"boss": [["军械试验平台已完成全部测试项目，即将投入民用。", "THE ORDNANCE TESTBED HAS PASSED EVERY TEST. CIVILIAN SERVICE BEGINS SOON."]],
	},
	4: {
		"wave": [["中央生产联合体本季度超额完成任务，战略储备再创新高。", "THE CENTRAL PRODUCTION UNION BEAT ITS QUOTA. THE STRATEGIC RESERVE HITS A NEW HIGH."],
			["口粮配给调整为每日一份，以支援战略储备建设。", "RATIONS ARE NOW ONE A DAY, IN SUPPORT OF THE STRATEGIC RESERVE."]],
		"boss": [["储备回收机进入例行检修。储备物资安全，无需关注。", "THE RESERVE INTAKE IS UNDER ROUTINE MAINTENANCE. RESERVES ARE SAFE. NO NEED TO LOOK."]],
	},
	5: {
		"wave": [["超导运输网络今日准点率 100%。第十三街站暂停服务第 12 年。", "THE SUPERCONDUCTING LINE RAN 100% ON TIME TODAY. 13TH STREET STATION: CLOSED, YEAR 12."],
			["专列运载的全部是民生物资，请市民放心。", "THE EXPRESS CARRIES ONLY GOODS FOR THE PEOPLE. CITIZENS NEED NOT WORRY."]],
		"boss": [["中央专列因故临时停运。请市民不要靠近事故现场，也不要拍照。", "THE CENTRAL EXPRESS IS TEMPORARILY SUSPENDED. KEEP AWAY FROM THE SITE. NO PHOTOGRAPHS."]],
	},
	6: {
		"wave": [["全国电网运行平稳。停电区域居民请早点休息。", "THE NATIONAL GRID IS STABLE. RESIDENTS OF BLACKOUT DISTRICTS, PLEASE SLEEP EARLY."],
			["近期发现私接电线行为。私接者的积分已全部冻结。", "UNAUTHORISED WIRING HAS BEEN FOUND. THE OFFENDERS' CREDITS ARE FROZEN."]],
		"boss": [["配电总闸进入检修。检修期间第十三街恢复供电——此为临时措施。", "THE GRID MASTER IS UNDER REPAIR. 13TH STREET HAS POWER MEANWHILE — A TEMPORARY MEASURE."]],
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
