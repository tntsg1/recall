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
		Enemies.CHASER: [["检测到一名维修工擅自进入封锁区。处罚已执行：全部积分清零。", "A MAINTENANCE WORKER HAS ENTERED A SEALED ZONE WITHOUT PERMISSION. PENALTY CARRIED OUT: ALL CREDITS ZEROED."],
			["我追的那个人根本跑不快。查了他的账户才知道，他还欠着四十年的劳动积分。", "THE MAN I WAS CHASING COULDN'T RUN FAST AT ALL. ONLY WHEN I CHECKED HIS ACCOUNT DID I SEE HE STILL OWED FORTY YEARS OF LABOUR CREDIT."]],
		Enemies.GUARD: [["安装手册第一条：盾牌必须始终朝向股东。其他人的安全不在保障范围内。", "MANUAL, RULE ONE: THE SHIELD MUST ALWAYS FACE THE SHAREHOLDERS. EVERYONE ELSE'S SAFETY IS NOT COVERED."]],
		Enemies.CHARGER: [["开往中央的列车每天经过第十三街。按照规定，本站不提供上下车服务。", "TRAINS TO THE CENTRE PASS 13TH STREET EVERY DAY. AS PER REGULATIONS, THIS STATION OFFERS NO BOARDING OR ALIGHTING."]],
	},
	2: {
		Enemies.CHASER: [["所有逾期账户必须强制追回。账户持有人也在回收范围内。", "ALL OVERDUE ACCOUNTS MUST BE FORCIBLY RECOVERED. ACCOUNT HOLDERS ARE ALSO WITHIN THE SCOPE OF RECOVERY."],
			["编号 0417 出生登记完成。资产状态：良好。", "NO. 0417 BIRTH REGISTERED. ASSET CONDITION: GOOD."]],
		Enemies.GUARD: [["排队请保持微笑。微笑计入考评。", "PLEASE SMILE IN THE QUEUE. SMILES ARE ASSESSED."]],
		Enemies.CHARGER: [["退休申请窗口已无限期关闭。如有疑问，请向您的主管提出。申请期间照常工作。", "THE RETIREMENT APPLICATION WINDOW IS CLOSED INDEFINITELY. QUESTIONS GO TO YOUR SUPERVISOR. WORK AS USUAL WHILE YOU APPLY."]],
		Enemies.PRISM: [["我调整了镜面的折射角度。现在监控画面里，每个人都在笑。上面很满意。", "I ADJUSTED THE MIRRORS' ANGLE OF REFRACTION. NOW EVERYONE ON THE CAMERA FEED IS SMILING. THE PEOPLE UPSTAIRS ARE PLEASED."]],
	},
	3: {
		Enemies.CHASER: [["已确认测试对象 R-0。清除许可自动通过，无需上级审批。", "TEST SUBJECT R-0 CONFIRMED. CLEARANCE TO ELIMINATE GRANTED AUTOMATICALLY; NO SUPERVISOR APPROVAL REQUIRED."],
			["出厂说明：对外防御。验收地点：第十三街。", "FACTORY NOTE: FOR EXTERNAL DEFENCE. ACCEPTANCE SITE: 13TH STREET."]],
		Enemies.ECHO: [["它走过的每一条路，我都能原样重现。毕竟，我就是为了追踪它才被制造出来的。", "EVERY PATH IT HAS WALKED, I CAN REPLAY EXACTLY. AFTER ALL, I WAS BUILT TO TRACK IT."]],
		Enemies.GUARD: [["第九代防暴盾已通过验收。重量减轻，防护性能提升，对人群的压制效果也比上一代更好。", "THE NINTH-GENERATION RIOT SHIELD HAS PASSED INSPECTION. LIGHTER, BETTER PROTECTION, AND BETTER AT PUSHING BACK CROWDS THAN THE LAST."]],
		Enemies.CHARGER: [["训练靶纸上的人没有武器。他们只是排着队。教官说，这就是最常见的实战场景。", "THE PEOPLE ON THE TRAINING TARGETS HAVE NO WEAPONS. THEY'RE JUST STANDING IN LINE. THE INSTRUCTOR SAYS THAT'S THE MOST COMMON REAL SCENARIO."]],
	},
	4: {
		Enemies.CHASER: [["工人编号 2207。本月产出 1400 件。个人配额：0。", "WORKER 2207. OUTPUT THIS MONTH: 1,400 UNITS. PERSONAL QUOTA: 0."],
			["他们说，储备仓里的东西是留给未来的。可这么多年过去了，我也没见谁真正用上过。", "THEY SAY WHAT'S IN THE RESERVE IS SAVED FOR THE FUTURE. YEARS HAVE GONE BY, AND I'VE NEVER SEEN ANYONE ACTUALLY USE IT."]],
		Enemies.GUARD: [["我已经守了这座储备仓三年。没人进去过，也没人出来过。有时候我都怀疑里面到底有没有东西。", "I'VE GUARDED THIS RESERVE FOR THREE YEARS. NO ONE HAS GONE IN, NO ONE HAS COME OUT. SOMETIMES I WONDER IF THERE'S ANYTHING INSIDE AT ALL."]],
		Enemies.CHARGER: [["装配线每年都要提高 10% 的生产速度。至于工资，管理层认为目前的标准已经足够了。", "THE LINE MUST RUN 10% FASTER EVERY YEAR. AS FOR WAGES, MANAGEMENT CONSIDERS THE CURRENT RATE SUFFICIENT."]],
		Enemies.LEECH: [["我吸收的所有东西，都必须原封不动地上交。至于我自己能留下多少？规定是零。", "EVERYTHING I TAKE IN MUST BE HANDED UP UNTOUCHED. HOW MUCH DO I GET TO KEEP? THE RULE SAYS ZERO."]],
	},
	5: {
		Enemies.CHASER: [["我负责押运这些车厢已经九年了。我至今没有权限知道里面装的是什么。", "I'VE ESCORTED THESE CARS FOR NINE YEARS. I STILL DON'T HAVE CLEARANCE TO KNOW WHAT'S INSIDE."],
			["列车从不在第十三街减速。鸣笛响起时，你最好已经离开轨道了。", "THE TRAIN NEVER SLOWS AT 13TH STREET. WHEN YOU HEAR THE HORN, YOU'D BETTER ALREADY BE OFF THE TRACK."]],
		Enemies.GUARD: [["上车名额一直很少。我们告诉站台上的人，下一班就可能轮到他们。我的工作，就是让他们一直等下去。", "THERE ARE NEVER MANY BOARDING PLACES. WE TELL THE PEOPLE ON THE PLATFORM THE NEXT TRAIN MIGHT BE THEIR TURN. MY JOB IS TO KEEP THEM WAITING."]],
		Enemies.CHARGER: [["专列一小时能跑六百公里。第十三街那趟公交？都三年没来过了。", "THE EXPRESS DOES SIX HUNDRED KILOMETRES AN HOUR. THE 13TH STREET BUS? HASN'T COME IN THREE YEARS."]],
		Enemies.PRISM: [["站台的灯是我调亮的。车一直不来，总得让等车的人有点盼头吧。", "I'M THE ONE WHO TURNED UP THE PLATFORM LIGHTS. THE TRAIN NEVER COMES, SO THE PEOPLE WAITING NEED SOMETHING TO HOPE FOR."]],
		Enemies.LEECH: [["我看了眼货单，上面写着“民生物资”。再往下一看，收货的全是中央储备。", "I GLANCED AT THE MANIFEST: 'GOODS FOR THE PEOPLE'. FURTHER DOWN, EVERY CONSIGNEE WAS THE CENTRAL RESERVE."]],
	},
	6: {
		Enemies.CHASER: [["我是3301号抄表员。第十三街的电表，我都三年没见它动过了。", "I'M METER READER 3301. I HAVEN'T SEEN A METER ON 13TH STREET MOVE IN THREE YEARS."],
			["当初说限电只是暂时的。这都十一年了，还没限完呢。", "THEY SAID THE POWER RATIONING WAS ONLY TEMPORARY. IT'S BEEN ELEVEN YEARS, AND IT STILL ISN'T OVER."]],
		Enemies.GUARD: [["上头规定配电柜必须上锁。我看那锁都比里面的电值钱。", "ORDERS FROM ABOVE: DISTRIBUTION CABINETS MUST BE LOCKED. IF YOU ASK ME, THE LOCK IS WORTH MORE THAN THE POWER INSIDE."]],
		Enemies.CHARGER: [["中央那边的灯一晚上都不关。说是为了安全，谁知道呢。", "THE LIGHTS AT THE CENTRE STAY ON ALL NIGHT. FOR SAFETY, THEY SAY. WHO KNOWS."]],
		Enemies.LEECH: [["他们用不完的电，我收回来，再卖给他们。反正他们还得买。", "THE POWER THEY DON'T USE, I TAKE BACK AND SELL TO THEM AGAIN. THEY'LL HAVE TO BUY IT ANYWAY."]],
		Enemies.INSPECTOR: [["我的工作就是关掉那些不该亮的灯。今天关了三千盏，明天还得接着查。", "MY JOB IS TO SWITCH OFF THE LIGHTS THAT SHOULDN'T BE ON. THREE THOUSAND TODAY, AND MORE TO CHECK TOMORROW."]],
	},
	7: {
		Enemies.CHASER: [["我每天都得检查大家有没有笑。今天查出来三个没笑的，已经报上去了。", "EVERY DAY I HAVE TO CHECK WHETHER EVERYONE IS SMILING. TODAY I FOUND THREE WHO WEREN'T. ALREADY REPORTED."],
			["他们总说这音乐能让人开心。反正我想关也不让关。", "THEY ALWAYS SAY THIS MUSIC MAKES PEOPLE HAPPY. EITHER WAY, I'M NOT ALLOWED TO TURN IT OFF."]],
		Enemies.GUARD: [["有人哭着进来？先让他把耳机戴上。这是规定。", "SOMEONE CAME IN CRYING? HAVE THEM PUT THE HEADPHONES ON FIRST. THOSE ARE THE RULES."]],
		Enemies.CHARGER: [["每年都要把节奏调快一点。谁的心跳跟不上，就按故障报上去。", "EVERY YEAR THE TEMPO GOES UP A LITTLE. ANYONE WHOSE HEART CAN'T KEEP UP GETS REPORTED AS A FAULT."]],
		Enemies.LEECH: [["有人走神，我就把那些乱七八糟的念头抽出来，存进档案里。", "WHEN SOMEONE'S MIND WANDERS, I PULL OUT THE STRAY THOUGHTS AND FILE THEM AWAY."]],
		Enemies.PULSE: [["跟着拍子动，一拍一下。没踩准拍子？那就不算。", "MOVE WITH THE BEAT, ONE BEAT, ONE STEP. MISSED THE BEAT? THEN IT DOESN'T COUNT."]],
	},
	8: {
		Enemies.CHASER: [["我是0081号档案员。我的工作就是清掉那些旧版本，免得有人翻出来。", "I'M ARCHIVIST 0081. MY JOB IS TO CLEAR OUT THE OLD EDITIONS BEFORE ANYONE DIGS THEM UP."],
			["我一天要修订四百页。你问原来写了什么？别管了，改完的才是真的。", "I REVISE FOUR HUNDRED PAGES A DAY. YOU ASK WHAT IT SAID BEFORE? NEVER MIND. THE REVISED VERSION IS THE TRUE ONE."]],
		Enemies.GUARD: [["这扇门三百年没对外开过。开过的那次，也已修订。", "THIS DOOR HAS NOT OPENED IN THREE HUNDRED YEARS. THE ONE TIME IT DID HAS BEEN REVISED."]],
		Enemies.CHARGER: [["海底很安静。被删除的东西，不会出声。", "IT IS QUIET ON THE SEABED. DELETED THINGS MAKE NO SOUND."]],
		Enemies.ECHO: [["每一版我都记得。所以他们只让我记最新一版。", "I REMEMBER EVERY EDITION. SO THEY LET ME KEEP ONLY THE LATEST."]],
		Enemies.LEECH: [["我负责吸走多余的历史。", "I'M IN CHARGE OF DRAWING OFF THE SURPLUS HISTORY."]],
		Enemies.PROOFREADER: [["文字写错了需要修改，人出了错也一样。对我来说，都是校对工作。", "WRITTEN WORDS THAT ARE WRONG MUST BE CORRECTED. SO MUST PEOPLE WHO ARE WRONG. TO ME, IT'S ALL PROOFREADING."]],
	},
	9: {
		Enemies.CHASER: [["我是4410号电梯维护员。这部电梯我修了十九年，却从来没上去过。", "I'M LIFT MAINTAINER 4410. I'VE REPAIRED THIS LIFT FOR NINETEEN YEARS AND NEVER ONCE RIDDEN IT UP."],
			["观景层的玻璃一直是我负责擦的。站在那里，能看见第十三街。", "I'VE ALWAYS BEEN THE ONE WHO CLEANS THE VIEWING DECK GLASS. FROM THERE YOU CAN SEE 13TH STREET."]],
		Enemies.GUARD: [["股东证人人都有，但那可不是登梯许可证。没有董事会批准，谁也别想上去。", "EVERYONE HAS A SHAREHOLDER CARD, BUT THAT'S NO BOARDING PASS. WITHOUT THE BOARD'S APPROVAL, NO ONE GOES UP."]],
		Enemies.CHARGER: [["还想往上走一千米？可以，先把上一段的票价翻倍交了。", "WANT TO GO ANOTHER THOUSAND METRES UP? FINE. FIRST PAY DOUBLE THE LAST STRETCH'S FARE."]],
		Enemies.PRISM: [["以前总有人投诉，说从这里看地球太远了。后来我把观景窗调成暖色，就再没人来投诉了。", "PEOPLE USED TO COMPLAIN THAT THE EARTH LOOKED TOO FAR AWAY FROM HERE. I TINTED THE VIEWING WINDOWS WARM, AND THE COMPLAINTS STOPPED."]],
		Enemies.LEECH: [["我的工作是把电梯漏出去的空气收回来。放心，每回收一升，都会算进你的账单。", "MY JOB IS TO RECOVER THE AIR THAT LEAKS FROM THE LIFT. DON'T WORRY: EVERY LITRE RECOVERED GOES ON YOUR BILL."]],
		Enemies.PULSE: [["气压又降了？收到。我已经在最新的报告里填上了“一切正常”。", "PRESSURE DROPPING AGAIN? NOTED. I'VE ALREADY PUT 'ALL NORMAL' IN THE LATEST REPORT."]],
		Enemies.ECHO: [["登梯人员的名单一直由我保管。上去的人越来越多，返程记录却始终是空的。", "I KEEP THE LIST OF EVERYONE WHO BOARDS. MORE AND MORE GO UP, BUT THE RETURN RECORDS ARE STILL EMPTY."]],
	},
	10: {
		Enemies.CHASER: [["我是6620号焊工。每天都在给战舰加厚装甲，回家却连墙上的裂缝都没钱修。", "I'M WELDER 6620. EVERY DAY I THICKEN THE ARMOUR ON WARSHIPS, AND AT HOME I CAN'T EVEN AFFORD TO FIX THE CRACKS IN MY WALL."],
			["十三街今年的口粮被取消了。配给站给每户发了几块钢板，说这是新的民生保障政策。", "13TH STREET'S RATIONS WERE CANCELLED THIS YEAR. THE DISTRIBUTION POINT GAVE EVERY HOUSEHOLD A FEW STEEL PLATES AND CALLED IT THE NEW LIVELIHOOD SECURITY POLICY."]],
		Enemies.GUARD: [["这艘战舰叫“友谊号”。名字是上面的人起的，炮口是留给下面的人的。", "THIS WARSHIP IS CALLED THE FRIENDSHIP. THE NAME WAS CHOSEN BY THE PEOPLE ABOVE; THE GUNS ARE MEANT FOR THE PEOPLE BELOW."]],
		Enemies.CHARGER: [["战舰下水那天，董事们举杯庆祝和平。有人问为什么要装这么多炮，他们说，这就是和平的保障。", "THE DAY THE WARSHIP LAUNCHED, THE DIRECTORS RAISED A TOAST TO PEACE. SOMEONE ASKED WHY IT NEEDED SO MANY GUNS. THEY SAID THAT IS WHAT GUARANTEES PEACE."]],
		Enemies.PRISM: [["舰体原本是灰黑色的。每次新闻拍摄，我都得把灯光调到最亮。毕竟，和平的象征总得是白色的。", "THE HULL IS ACTUALLY DARK GREY. EVERY TIME THE NEWS FILMS IT, I HAVE TO TURN THE LIGHTS ALL THE WAY UP. A SYMBOL OF PEACE HAS TO BE WHITE, AFTER ALL."]],
		Enemies.LEECH: [["造船剩下的焊渣也不能浪费。上面要求全部回收，送去兵工厂熔炼。听说下一批炮弹就用这些材料。", "EVEN THE WELDING SLAG FROM THE SHIPS MUST NOT GO TO WASTE. ORDERS ARE TO RECOVER IT ALL AND SEND IT TO THE ARMOURY TO BE SMELTED. I HEAR THE NEXT BATCH OF SHELLS WILL BE MADE FROM IT."]],
		Enemies.PULSE: [["我每天只负责打铆钉。系统会把每一次敲击算进生产业绩，至于这艘船以后用来干什么，没人告诉我。", "ALL I DO ALL DAY IS DRIVE RIVETS. THE SYSTEM COUNTS EVERY STRIKE TOWARD PRODUCTION FIGURES. WHAT THIS SHIP WILL BE USED FOR, NO ONE HAS TOLD ME."]],
		Enemies.ECHO: [["他们说这些战舰都是为了维护和平才造的。我已经登记到第九十艘了，每一艘都叫“和平号”。", "THEY SAY THESE WARSHIPS ARE BUILT TO KEEP THE PEACE. I'VE REGISTERED NINETY SO FAR, AND EVERY ONE IS CALLED THE PEACE."]],
		Enemies.ESCORT: [["我的护送目标享有最高级别的安全保障。至于我，系统把我归类为可替换资产。", "MY ESCORT TARGET HAS THE HIGHEST LEVEL OF PROTECTION. AS FOR ME, THE SYSTEM CLASSIFIES ME AS A REPLACEABLE ASSET."]],
	},
	11: {
		Enemies.CHASER: [["我是0703号研究员，负责研究怎么把一秒钟延长。上周实验成功了，主管说先拿来延长员工的工作时间。", "I'M RESEARCHER 0703, STUDYING HOW TO MAKE A SECOND LAST LONGER. THE EXPERIMENT WORKED LAST WEEK. MY SUPERVISOR SAYS WE'LL USE IT FIRST TO EXTEND STAFF WORKING HOURS."],
			["研究所里的仪器虽然型号不同，但都是照着七百年前的一台机器造的。至于那台机器为什么这么设计，现在已经没人知道了。", "THE INSTRUMENTS HERE ARE ALL DIFFERENT MODELS, BUT EVERY ONE WAS BUILT AFTER A SINGLE MACHINE FROM SEVEN HUNDRED YEARS AGO. WHY THAT MACHINE WAS DESIGNED THAT WAY, NO ONE KNOWS ANYMORE."]],
		Enemies.GUARD: [["实验室曾经允许研究员自由观测。后来有人发现，观测会影响实验结果。现在所有观察窗都被封死了。", "THE LAB USED TO LET RESEARCHERS OBSERVE FREELY. THEN SOMEONE FOUND THAT OBSERVING CHANGED THE RESULTS. NOW EVERY VIEWING WINDOW IS SEALED."]],
		Enemies.CHARGER: [["董事长今年两百岁了。研究所调查了三次，最后决定把人类的正常寿命上限提高到两百五十岁。", "THE CHAIRMAN TURNS TWO HUNDRED THIS YEAR. THE INSTITUTE INVESTIGATED THREE TIMES, THEN RAISED THE NORMAL HUMAN LIFESPAN LIMIT TO TWO HUNDRED AND FIFTY."]],
		Enemies.PRISM: [["上周的观测数据不太理想。我稍微调整了一下镜片的角度，今天所有指标就都达标了。", "LAST WEEK'S OBSERVATION DATA WASN'T IDEAL. I ADJUSTED THE LENS ANGLE A LITTLE, AND TODAY EVERY METRIC MET ITS TARGET."]],
		Enemies.LEECH: [["研究所发现，普通人每天都有不少时间被浪费。我负责把这些时间收集起来，转进董事们的账户。", "THE INSTITUTE FOUND THAT ORDINARY PEOPLE WASTE A LOT OF TIME EVERY DAY. I COLLECT THAT TIME AND TRANSFER IT TO THE DIRECTORS' ACCOUNTS."]],
		Enemies.PULSE: [["董事会的时间都是借来的。我每跳动一次，就有一秒钟划进他们的账上。至于什么时候还，没人提过。", "THE BOARD LIVES ON BORROWED TIME. EVERY TIME I BEAT, ONE SECOND GOES ONTO THEIR ACCOUNT. WHEN IT GETS PAID BACK, NO ONE HAS SAID."]],
		Enemies.ECHO: [["研究所给我复制了三个副本，现在档案里登记着四个我。我问他们哪个才是原件，他们说这不影响正常工作。", "THE INSTITUTE MADE THREE COPIES OF ME, SO NOW THE FILES LIST FOUR OF ME. I ASKED WHICH ONE IS THE ORIGINAL. THEY SAID IT DOESN'T AFFECT NORMAL WORK."]],
		Enemies.PHASE: [["我的身体有一半还在等待实体化审批。主管说，在手续办完之前，我只能先用剩下的一半继续工作。", "HALF MY BODY IS STILL WAITING FOR MATERIALISATION APPROVAL. MY SUPERVISOR SAYS UNTIL THE PAPERWORK IS DONE, I HAVE TO KEEP WORKING WITH THE HALF I'VE GOT."]],
	},
	12: {
		Enemies.CHASER: [["我是0001号董事会警卫，第一批入职的。两百年过去了，新来的警卫都升职了，我连董事长的办公室都没资格进。", "I'M BOARD GUARD 0001, FROM THE FIRST INTAKE. TWO HUNDRED YEARS LATER, EVERY NEWER GUARD HAS BEEN PROMOTED, AND I'M STILL NOT CLEARED TO ENTER THE CHAIRMAN'S OFFICE."],
			["我在董事长门口站了整整两百年。有时候我怀疑，他根本不知道这里还有个警卫。", "I HAVE STOOD AT THE CHAIRMAN'S DOOR FOR TWO HUNDRED YEARS. SOMETIMES I WONDER IF HE EVEN KNOWS THERE'S A GUARD HERE."]],
		Enemies.GUARD: [["董事会今天又全票通过了一项决议。其实整个董事会就董事长一个人，不过会议记录还是得写全票通过。", "TODAY THE BOARD PASSED ANOTHER RESOLUTION UNANIMOUSLY. THE WHOLE BOARD IS JUST THE CHAIRMAN, BUT THE MINUTES STILL HAVE TO SAY UNANIMOUS."]],
		Enemies.CHARGER: [["核心区的空调全年保持二十六度。十三街的居民申请了三年供暖，最后收到的答复是：能源配额不足。", "THE CORE'S AIR CONDITIONING STAYS AT TWENTY-SIX DEGREES ALL YEAR. 13TH STREET'S RESIDENTS APPLIED FOR HEATING FOR THREE YEARS. THE ANSWER: INSUFFICIENT ENERGY QUOTA."]],
		Enemies.PRISM: [["全国的屏幕每天都在播放董事长的讲话。两百年了，我换过无数次投影设备，可他的笑容连一点变化都没有。", "EVERY SCREEN IN THE COUNTRY PLAYS THE CHAIRMAN'S SPEECH EVERY DAY. IN TWO HUNDRED YEARS I'VE REPLACED THE PROJECTORS COUNTLESS TIMES, BUT HIS SMILE HAS NEVER CHANGED."]],
		Enemies.LEECH: [["每位股东都要定期上交一小部分意识，统一存放在核心区。董事会说这是为了保障大家的利益，但从来没解释过这些意识拿来做什么。", "EVERY SHAREHOLDER MUST REGULARLY HAND OVER A SMALL PART OF THEIR MIND, KEPT HERE IN THE CORE. THE BOARD SAYS IT PROTECTS EVERYONE'S INTERESTS, BUT HAS NEVER EXPLAINED WHAT THE MINDS ARE FOR."]],
		Enemies.PULSE: [["全国的心跳都由这里统一调节。我的工作就是维持这个节奏，谁的心跳不合拍，系统就会自动纠正。", "THE WHOLE COUNTRY'S HEARTBEAT IS REGULATED HERE. MY JOB IS TO HOLD THE RHYTHM. IF SOMEONE'S HEART FALLS OUT OF STEP, THE SYSTEM CORRECTS IT AUTOMATICALLY."]],
		Enemies.ECHO: [["董事长已经换过十一具身体了。每次换完，他都让我销毁旧照片。可我记得每一张脸，连他自己忘掉的那些也记得。", "THE CHAIRMAN HAS CHANGED BODIES ELEVEN TIMES. AFTER EACH CHANGE HE HAS ME DESTROY THE OLD PHOTOS. BUT I REMEMBER EVERY FACE, EVEN THE ONES HE HAS FORGOTTEN."]],
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
		["crate", Vector2(285, 860), Vector2(0, -1), "crate", "股东卫士 Ⅳ 型 · 仅限国内使用", "SHAREHOLDER GUARDIAN MK IV · DOMESTIC USE ONLY"],
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
	7: [
		["monitor", Vector2(80, 560), Vector2(1, 0), "screen", "本区快乐达标率 99.3% · 未达标者已安排加时聆听", "HAPPINESS COMPLIANCE 99.3% · NON-COMPLIANT CITIZENS BOOKED FOR EXTRA LISTENING"],
		["chair", Vector2(1840, 690), Vector2(-1, 0), "notice", "请放松。抵抗会降低同步效率。", "PLEASE RELAX. RESISTANCE LOWERS SYNCHRONISATION EFFICIENCY."],
		["slogan", Vector2(350, 70), Vector2(0, 1), "sign", "请保持愉快 · 愉快是公民的义务", "STAY HAPPY · HAPPINESS IS A CIVIC DUTY"],
		["scrawl", Vector2(1840, 380), Vector2(-1, 0), "scrawl", "我的心跳，不是你们的节拍。", "MY HEARTBEAT IS NOT YOUR TEMPO."],
	],
	8: [
		["index", Vector2(80, 300), Vector2(1, 0), "screen", "馆藏历史：1 部 · 现行版本：第 214 版", "HISTORIES HELD: 1 · CURRENT EDITION: 214"],
		["plate", Vector2(960, 1010), Vector2(0, -1), "floor", "旧文明档案 · 零号机项目 · 设计者姓名已删除", "OLD-ERA ARCHIVE · UNIT ZERO PROJECT · DESIGNER'S NAME DELETED"],
		["rules", Vector2(1840, 476), Vector2(-1, 0), "notice", "借阅须知：只可阅读现行版本。旧版本从未存在。", "READERS MAY CONSULT THE CURRENT EDITION ONLY. OLD EDITIONS NEVER EXISTED."],
		["scrawl", Vector2(1840, 900), Vector2(-1, 0), "scrawl", "他们改了所有的书。没改我们记得的。", "THEY REWROTE EVERY BOOK. NOT WHAT WE REMEMBER."],
	],
	9: [
		["altitude", Vector2(80, 545), Vector2(1, 0), "screen", "当前高度 31,200 米 · 观景层到此为止", "ALTITUDE 31,200 M · THE VIEWING DECK ENDS HERE"],
		["deck", Vector2(700, 1010), Vector2(0, -1), "floor", "观景层 · 第十三街居民止步于此", "VIEWING DECK · 13TH STREET RESIDENTS GO NO FURTHER"],
		["rail", Vector2(1840, 545), Vector2(-1, 0), "notice", "舱门开启时请抓紧扶手。扶手按分钟计费。", "HOLD THE HANDRAIL WHEN THE DOORS OPEN. HANDRAILS ARE BILLED BY THE MINUTE."],
		["scrawl", Vector2(1840, 756), Vector2(-1, 0), "scrawl", "我们把它修到了天上。他们不让我们上去。", "WE BUILT IT TO THE SKY. THEY WON'T LET US UP."],
	],
	10: [
		["schedule", Vector2(80, 560), Vector2(1, 0), "screen", "本月下水：和平级 3 艘 · 守护级 2 艘 · 第十三街供暖：暂停", "LAUNCHED THIS MONTH: 3 PEACE CLASS · 2 GUARDIAN CLASS · 13TH STREET HEATING: SUSPENDED"],
		["steel", Vector2(245, 880), Vector2(0, -1), "crate", "装甲钢 · 原料：民用口粮转产", "ARMOUR STEEL · FEEDSTOCK: CIVILIAN RATIONS, REPURPOSED"],
		["tether", Vector2(1840, 530), Vector2(-1, 0), "notice", "失重区作业请系好安全绳。安全绳从工资中扣除。", "WEAR YOUR TETHER IN ZERO-G ZONES. TETHERS ARE DEDUCTED FROM YOUR PAY."],
		["scrawl", Vector2(1840, 740), Vector2(-1, 0), "scrawl", "他们说是为了保护我们。炮口对着我们。", "THEY SAY IT IS TO PROTECT US. THE GUNS POINT AT US."],
	],
	11: [
		["eliminated", Vector2(80, 560), Vector2(1, 0), "screen", "已消除异常：时间 · 引力 · 死亡（进行中）", "ANOMALIES ELIMINATED: TIME · GRAVITY · DEATH (IN PROGRESS)"],
		["sample", Vector2(600, 1010), Vector2(0, -1), "floor", "意识转移试验 · 唯一成功样本：编号零 · 下落不明", "CONSCIOUSNESS TRANSFER · ONLY SUCCESSFUL SUBJECT: NO. ZERO · WHEREABOUTS UNKNOWN"],
		["observe", Vector2(1840, 470), Vector2(-1, 0), "notice", "实验进行中请勿观测。观测者将被列入实验对象。", "EXPERIMENT IN PROGRESS. DO NOT OBSERVE. OBSERVERS WILL BE ADDED TO THE SUBJECTS."],
		["scrawl", Vector2(1840, 690), Vector2(-1, 0), "scrawl", "他们想永远活着。我们只想活到月底。", "THEY WANT TO LIVE FOREVER. WE JUST WANT TO MAKE IT TO MONTH'S END."],
	],
	12: [
		["board", Vector2(80, 560), Vector2(1, 0), "screen", "董事会成员：1 人 · 出席率 100% · 全票通过 100%", "BOARD MEMBERS: 1 · ATTENDANCE 100% · UNANIMOUS 100%"],
		["protocol", Vector2(1300, 1010), Vector2(0, -1), "floor", "意识转移协议 · 原始版本 · 作者：零号机设计组", "CONSCIOUSNESS TRANSFER PROTOCOL · ORIGINAL · BY THE UNIT ZERO TEAM"],
		["quiet", Vector2(1840, 470), Vector2(-1, 0), "notice", "请保持安静。董事长正在思考全体股东的未来。", "QUIET PLEASE. THE CHAIRMAN IS THINKING ABOUT EVERY SHAREHOLDER'S FUTURE."],
		["scrawl", Vector2(1840, 700), Vector2(-1, 0), "scrawl", "我们不需要董事长。我们需要电。", "WE DON'T NEED A CHAIRMAN. WE NEED POWER."],
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
	7: {
		"wave": [["思想与意识管理局今日同步市民 48 万人次，零情绪事故。", "THE BUREAU OF THOUGHT SYNCHRONISED 480,000 CITIZENS TODAY. ZERO MOOD INCIDENTS."],
			["请勿在公共场所表现出疲惫，以免影响他人幸福。", "DO NOT LOOK TIRED IN PUBLIC. IT AFFECTS OTHERS' HAPPINESS."]],
		"boss": [["同步装置暂停。请市民自行保持愉快，直至恢复。", "THE SYNCHRONISER IS PAUSED. CITIZENS, STAY HAPPY ON YOUR OWN UNTIL IT RETURNS."]],
	},
	8: {
		"wave": [["深海历史档案库今日修订 1.2 万页，历史更加准确。", "THE DEEP ARCHIVE REVISED 12,000 PAGES TODAY. HISTORY IS MORE ACCURATE THAN EVER."],
			["请勿私自保存旧版本资料。旧版本已不再真实。", "DO NOT KEEP OLD EDITIONS. OLD EDITIONS ARE NO LONGER TRUE."]],
		"boss": [["档案修订机暂停工作。在此期间，历史以昨日版本为准。", "THE ARCHIVIST IS PAUSED. UNTIL IT RETURNS, YESTERDAY'S EDITION OF HISTORY APPLIES."]],
	},
	9: {
		"wave": [["天穹轨道电梯今日运送董事 12 人、货物 3000 吨，一切正常。", "THE SKY LIFT CARRIED 12 DIRECTORS AND 3,000 TONNES OF CARGO TODAY. ALL NORMAL."],
			["观景层每年开放一天。请珍惜。", "THE VIEWING DECK OPENS ONE DAY A YEAR. PLEASE CHERISH IT."]],
		"boss": [["配重系统进入检修。电梯暂停在当前高度，请保持冷静。", "THE COUNTERWEIGHT IS UNDER REPAIR. THE LIFT HOLDS AT ITS PRESENT HEIGHT. PLEASE STAY CALM."]],
	},
	10: {
		"wave": [["近地轨道船坞今日焊接装甲 4800 平方米，和平力量持续增强。", "THE ORBITAL YARD WELDED 4,800 M² OF ARMOUR TODAY. THE FORCES OF PEACE GROW STRONGER."],
			["和平九十一号即将下水。请市民收看直播并保持感动。", "PEACE NINETY-ONE LAUNCHES SOON. CITIZENS, WATCH THE BROADCAST AND REMAIN MOVED."]],
		"boss": [["和平号建造暂停。所有已完成部分均属和平用途。", "WORK ON THE PEACE IS SUSPENDED. ALL COMPLETED PARTS ARE FOR PEACEFUL USE."]],
	},
	11: {
		"wave": [["中央异常物理研究所宣布：本年度发现异常 0 起。", "THE CENTRAL INSTITUTE OF ANOMALOUS PHYSICS REPORTS: 0 ANOMALIES FOUND THIS YEAR."],
			["近日出现的不明设备不属于异常。它不存在。", "THE UNKNOWN DEVICE SEEN RECENTLY IS NOT AN ANOMALY. IT DOES NOT EXIST."]],
		"boss": [["观测实验提前结束。实验对象已确认不存在。", "THE OBSERVATION ENDED EARLY. THE SUBJECT IS CONFIRMED NOT TO EXIST."]],
	},
	12: {
		"wave": [["全民董事会核心运行正常。董事长身体健康，已连续执政 231 年。", "THE BOARD'S CORE RUNS NORMALLY. THE CHAIRMAN IS IN GOOD HEALTH, 231 YEARS IN OFFICE."],
			["近日有一台旧设备接近核心。请市民放心：它没有权限。", "AN OLD DEVICE HAS APPROACHED THE CORE. CITIZENS NEED NOT WORRY: IT HAS NO CLEARANCE."]],
		"boss": [["核心……运行……正……常。", "THE CORE ... IS RUNNING ... NOR ... MALLY."]],
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
