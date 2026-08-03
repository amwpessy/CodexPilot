import Foundation

struct ShuihuCardDefinition: Identifiable, Hashable {
    let rank: Int
    let star: String
    let nickname: String
    let name: String
    let role: String
    let weapon: String
    let signature: String
    let command: Int
    let might: Int
    let wisdom: Int
    let charisma: Int

    var id: Int { rank }
    var isHeavenlySpirit: Bool { rank <= 36 }

    var averageRating: Int {
        (command + might + wisdom + charisma) / 4
    }
}

struct ShuihuCollectionEntry: Codable, Equatable {
    let cardId: Int
    let copies: Int
}

struct ShuihuCollectionStatus: Codable, Equatable {
    let pointsBalance: Int
    let drawsUsed: Int
    let dailyLimit: Int
    let drawsRemaining: Int
    let dayKey: String
    let resetsAt: Date
    let uniqueCount: Int
    let totalCopies: Int
    let rewardClaimed: Bool
    let collection: [ShuihuCollectionEntry]

    func copies(of cardId: Int) -> Int {
        collection.first(where: { $0.cardId == cardId })?.copies ?? 0
    }
}

struct ShuihuDrawReceipt: Codable, Equatable {
    let cardId: Int
    let isNew: Bool
    let copies: Int
    let cost: Int
    let pointsBalance: Int
    let drawsUsed: Int
    let dailyLimit: Int
    let drawsRemaining: Int
    let dayKey: String
    let resetsAt: Date
    let uniqueCount: Int
    let totalCopies: Int
    let rewardGranted: Bool
    let rewardAmount: Int
    let rewardClaimed: Bool
    let collection: [ShuihuCollectionEntry]

    var status: ShuihuCollectionStatus {
        ShuihuCollectionStatus(
            pointsBalance: pointsBalance,
            drawsUsed: drawsUsed,
            dailyLimit: dailyLimit,
            drawsRemaining: drawsRemaining,
            dayKey: dayKey,
            resetsAt: resetsAt,
            uniqueCount: uniqueCount,
            totalCopies: totalCopies,
            rewardClaimed: rewardClaimed,
            collection: collection
        )
    }
}

enum ShuihuCardCatalog {
    static let setKey = "shuihu-108-v1"
    static let drawCost = 1_000
    static let dailyDrawLimit = 10
    static let completionReward = 1_000_000

    static let all: [ShuihuCardDefinition] = [
        card(1, "天魁星", "呼保义", "宋江", "梁山总兵都头领 / Chief", "令旗", "及时雨，善聚人心", 98, 62, 88, 99),
        card(2, "天罡星", "玉麒麟", "卢俊义", "梁山总兵都头领 / Chief", "麒麟黄金矛", "河北豪杰，棍棒无双", 92, 99, 78, 90),
        card(3, "天机星", "智多星", "吴用", "掌管机密军师 / Strategist", "羽扇", "运筹帷幄，智取生辰纲", 94, 42, 100, 84),
        card(4, "天闲星", "入云龙", "公孙胜", "掌管机密军师 / Taoist", "松纹古剑", "呼风唤雨，五雷天罡", 86, 79, 96, 88),
        card(5, "天勇星", "大刀", "关胜", "马军五虎将 / Cavalry General", "青龙偃月刀", "将门风骨，刀势沉雄", 94, 97, 82, 91),
        card(6, "天雄星", "豹子头", "林冲", "马军五虎将 / Cavalry General", "丈八蛇矛", "八十万禁军教头", 91, 98, 82, 88),
        card(7, "天猛星", "霹雳火", "秦明", "马军五虎将 / Cavalry General", "狼牙棒", "性烈如火，冲阵如雷", 87, 96, 68, 80),
        card(8, "天威星", "双鞭", "呼延灼", "马军五虎将 / Cavalry General", "水磨八棱双鞭", "连环甲马，名将之后", 95, 94, 84, 87),
        card(9, "天英星", "小李广", "花荣", "马军八骠骑 / Vanguard", "天地日月弓", "百步穿杨，银枪神箭", 88, 96, 82, 94),
        card(10, "天贵星", "小旋风", "柴进", "掌管钱粮 / Treasurer", "丹书铁券", "仗义疏财，礼贤下士", 78, 70, 83, 98),
        card(11, "天富星", "扑天雕", "李应", "掌管钱粮 / Treasurer", "浑铁点钢枪", "飞刀五口，雄踞李庄", 84, 91, 84, 88),
        card(12, "天满星", "美髯公", "朱仝", "马军八骠骑 / Vanguard", "九龙朝阳刀", "美髯重义，神似关公", 85, 91, 77, 94),
        card(13, "天孤星", "花和尚", "鲁智深", "步军头领 / Infantry Captain", "水磨禅杖", "倒拔垂杨柳，拳打镇关西", 82, 99, 74, 95),
        card(14, "天伤星", "行者", "武松", "步军头领 / Infantry Captain", "雪花镔铁双刀", "景阳冈打虎，醉打蒋门神", 80, 100, 78, 96),
        card(15, "天立星", "双枪将", "董平", "马军五虎将 / Cavalry General", "出白梨花双枪", "双枪飞舞，风流万户侯", 86, 96, 72, 88),
        card(16, "天捷星", "没羽箭", "张清", "马军八骠骑 / Vanguard", "飞凰火石", "飞石连打十五将", 82, 95, 80, 88),
        card(17, "天暗星", "青面兽", "杨志", "马军八骠骑 / Vanguard", "祖传宝刀", "杨家将后，卖刀斗牛二", 86, 94, 79, 82),
        card(18, "天佑星", "金枪手", "徐宁", "马军八骠骑 / Vanguard", "钩镰枪", "金枪班教师，大破连环马", 87, 93, 85, 86),
        card(19, "天空星", "急先锋", "索超", "马军八骠骑 / Vanguard", "金蘸斧", "性急争先，斧劈阵门", 79, 91, 62, 77),
        card(20, "天速星", "神行太保", "戴宗", "总探声息头领 / Courier", "甲马神符", "日行八百，飞报军情", 80, 72, 86, 88),
        card(21, "天异星", "赤发鬼", "刘唐", "步军头领 / Infantry Captain", "朴刀", "赤发朱砂，夜奔东溪村", 74, 91, 68, 79),
        card(22, "天杀星", "黑旋风", "李逵", "步军头领 / Infantry Captain", "板斧双持", "嫉恶如仇，沂岭杀四虎", 68, 98, 45, 86),
        card(23, "天微星", "九纹龙", "史进", "马军八骠骑 / Vanguard", "三尖两刃刀", "身纹九龙，十八般武艺", 80, 92, 70, 90),
        card(24, "天究星", "没遮拦", "穆弘", "马军八骠骑 / Vanguard", "朴刀", "揭阳镇豪杰，气势无拦", 79, 89, 67, 82),
        card(25, "天退星", "插翅虎", "雷横", "步军头领 / Infantry Captain", "朴刀", "膂力过人，跳涧如虎", 76, 88, 65, 78),
        card(26, "天寿星", "混江龙", "李俊", "水军都督 / Naval Admiral", "七星宝剑", "水战统帅，海外称王", 95, 88, 91, 93),
        card(27, "天剑星", "立地太岁", "阮小二", "水军头领 / Naval Captain", "分水鱼叉", "石碣村长兄，水寨先锋", 83, 88, 72, 84),
        card(28, "天平星", "船火儿", "张横", "水军头领 / Naval Captain", "鱼叉", "浔阳江艄公，浪里截舟", 78, 88, 66, 75),
        card(29, "天罪星", "短命二郎", "阮小五", "水军头领 / Naval Captain", "短刀鱼叉", "水性剽悍，性烈不羁", 77, 89, 68, 78),
        card(30, "天损星", "浪里白条", "张顺", "水军头领 / Naval Captain", "分水刺", "水底伏七日，浪里疾如鱼", 82, 90, 76, 91),
        card(31, "天败星", "活阎罗", "阮小七", "水军头领 / Naval Captain", "竹篙弯刀", "快意豪放，倒船盗御酒", 75, 88, 64, 89),
        card(32, "天牢星", "病关索", "杨雄", "步军头领 / Infantry Captain", "冷艳锯齿刀", "刽子手出身，行事果决", 76, 89, 71, 78),
        card(33, "天慧星", "拼命三郎", "石秀", "步军头领 / Infantry Captain", "雁翎刀", "路见不平，劫法场拼命", 78, 92, 82, 88),
        card(34, "天暴星", "两头蛇", "解珍", "步军头领 / Hunter", "浑铁点钢叉", "登州猎户，翻山逐虎", 75, 89, 72, 79),
        card(35, "天哭星", "双尾蝎", "解宝", "步军头领 / Hunter", "浑铁点钢叉", "攀崖涉险，毒蝎双钩", 73, 88, 71, 77),
        card(36, "天巧星", "浪子", "燕青", "步军头领 / Scout", "川弩短弓", "相扑绝技，吹箫唱曲", 84, 92, 92, 99),
        card(37, "地魁星", "神机军师", "朱武", "参赞军务 / Strategist", "双刀阵图", "精通阵法，善使双刀", 88, 73, 95, 82),
        card(38, "地煞星", "镇三山", "黄信", "马军小彪将 / Cavalry Scout", "丧门剑", "镇守青州三山", 76, 84, 67, 76),
        card(39, "地勇星", "病尉迟", "孙立", "马军小彪将 / Cavalry Scout", "竹节虎眼鞭", "登州兵马提辖，枪鞭双绝", 87, 94, 82, 85),
        card(40, "地杰星", "丑郡马", "宣赞", "马军小彪将 / Cavalry Scout", "钢刀", "连珠箭胜番将，铁面忠勇", 78, 86, 70, 68),
        card(41, "地雄星", "井木犴", "郝思文", "马军小彪将 / Cavalry Scout", "长枪", "熟谙兵法，与关胜同袍", 80, 85, 78, 77),
        card(42, "地威星", "百胜将", "韩滔", "马军小彪将 / Cavalry Scout", "枣木槊", "团练使出身，百战先锋", 79, 84, 71, 75),
        card(43, "地英星", "天目将", "彭玘", "马军小彪将 / Cavalry Scout", "三尖两刃刀", "眉心天目，善使飞叉", 75, 84, 68, 74),
        card(44, "地奇星", "圣水将军", "单廷珪", "马军小彪将 / Water General", "黑杆水枪", "玄水破敌，黑甲黑马", 80, 84, 79, 77),
        card(45, "地猛星", "神火将军", "魏定国", "马军小彪将 / Fire General", "熟铜刀", "火攻冲阵，红甲赤马", 81, 85, 78, 78),
        card(46, "地文星", "圣手书生", "萧让", "文书营造 / Calligrapher", "湖笔书卷", "精通诸体，仿写文书", 62, 45, 94, 84),
        card(47, "地正星", "铁面孔目", "裴宣", "军政司赏罚 / Magistrate", "阴阳双剑", "铁面无私，赏罚分明", 78, 72, 91, 82),
        card(48, "地阔星", "摩云金翅", "欧鹏", "马军小彪将 / Cavalry Scout", "铁枪", "身健步快，如金翅摩云", 74, 84, 66, 73),
        card(49, "地阖星", "火眼狻猊", "邓飞", "马军小彪将 / Cavalry Scout", "铁链", "双眼赤红，铁链横扫", 74, 85, 64, 74),
        card(50, "地强星", "锦毛虎", "燕顺", "马军小彪将 / Cavalry Scout", "朴刀", "清风山寨主，锦衣虎胆", 73, 83, 65, 76),
        card(51, "地暗星", "锦豹子", "杨林", "马军小彪将 / Scout", "朴刀", "四海结交，探路引线", 70, 79, 76, 82),
        card(52, "地轴星", "轰天雷", "凌振", "火炮营造 / Artillery Chief", "风火炮", "宋代第一炮手，雷震城郭", 72, 58, 89, 76),
        card(53, "地会星", "神算子", "蒋敬", "钱粮核算 / Accountant", "算盘", "心算如神，掌理钱粮", 71, 46, 96, 78),
        card(54, "地佐星", "小温侯", "吕方", "中军守护 / Guard", "方天画戟", "红袍画戟，小吕布之风", 76, 87, 66, 84),
        card(55, "地佑星", "赛仁贵", "郭盛", "中军守护 / Guard", "方天画戟", "白袍银戟，戟缨交缠", 75, 86, 65, 83),
        card(56, "地灵星", "神医", "安道全", "医护营 / Physician", "银针药囊", "妙手回春，内外科皆精", 68, 40, 98, 91),
        card(57, "地兽星", "紫髯伯", "皇甫端", "兽医营 / Veterinarian", "药葫芦", "碧眼黄须，专医战马", 64, 48, 91, 80),
        card(58, "地微星", "矮脚虎", "王英", "马军头领 / Cavalry Scout", "丈八长枪", "五短身材，山路悍斗", 57, 76, 47, 58),
        card(59, "地慧星", "一丈青", "扈三娘", "马军头领 / Cavalry Scout", "日月双刀", "红锦套索，双刀擒将", 80, 92, 77, 91),
        card(60, "地暴星", "丧门神", "鲍旭", "步军将校 / Infantry", "阔剑", "黑衣阔剑，嗜战冲阵", 63, 88, 45, 62),
        card(61, "地默星", "混世魔王", "樊瑞", "芒砀山头领 / Mystic", "流星锤", "会使妖法，剑锤并用", 76, 85, 87, 80),
        card(62, "地猖星", "毛头星", "孔明", "守护中军 / Guard", "朴刀", "白虎山兄长，豪气外露", 65, 76, 54, 68),
        card(63, "地狂星", "独火星", "孔亮", "守护中军 / Guard", "朴刀", "性急如火，随兄闯荡", 61, 74, 50, 65),
        card(64, "地飞星", "八臂哪吒", "项充", "步军牌手 / Shield Trooper", "飞刀蛮牌", "二十四把飞刀，八臂齐发", 72, 86, 72, 78),
        card(65, "地走星", "飞天大圣", "李衮", "步军牌手 / Shield Trooper", "标枪团牌", "二十四支标枪，团牌滚阵", 71, 85, 70, 77),
        card(66, "地巧星", "玉臂匠", "金大坚", "印信营造 / Seal Carver", "玉石刻刀", "善刻碑印，玉臂精工", 61, 43, 93, 79),
        card(67, "地明星", "铁笛仙", "马麟", "马军小彪将 / Musician", "铁笛大滚刀", "铁笛能歌，双刀能战", 70, 81, 70, 86),
        card(68, "地进星", "出洞蛟", "童威", "水军头领 / Naval Captain", "鱼叉", "浔阳江水贩，入水如蛟", 74, 82, 67, 75),
        card(69, "地退星", "翻江蜃", "童猛", "水军头领 / Naval Captain", "水叉", "翻江搅浪，与兄同舟", 72, 81, 65, 73),
        card(70, "地满星", "玉幡竿", "孟康", "战船营造 / Shipwright", "船斧", "身长肤白，督造战船", 69, 72, 81, 75),
        card(71, "地遂星", "通臂猿", "侯健", "旌旗袍服 / Tailor", "银针软尺", "猿臂灵巧，裁制军旗", 62, 59, 88, 78),
        card(72, "地周星", "跳涧虎", "陈达", "马军小彪将 / Cavalry Scout", "出白点钢枪", "少华山先锋，跃涧突阵", 66, 79, 55, 67),
        card(73, "地隐星", "白花蛇", "杨春", "马军小彪将 / Cavalry Scout", "大杆刀", "白衣长身，刀路如蛇", 66, 78, 58, 68),
        card(74, "地异星", "白面郎君", "郑天寿", "步军将校 / Infantry", "雁翎刀", "白面俊秀，清风山三当家", 64, 77, 59, 76),
        card(75, "地理星", "九尾龟", "陶宗旺", "城垣营造 / Builder", "铁锹", "庄户出身，筑城开道", 71, 75, 70, 73),
        card(76, "地俊星", "铁扇子", "宋清", "宴席供应 / Steward", "铁扇", "谦和稳重，主管筵宴", 67, 45, 74, 84),
        card(77, "地乐星", "铁叫子", "乐和", "机密传报 / Singer", "铁叫子", "聪敏善歌，诸般乐品皆晓", 67, 61, 86, 91),
        card(78, "地捷星", "花项虎", "龚旺", "步军将校 / Infantry", "飞枪", "虎斑刺项，马上飞枪", 65, 78, 57, 67),
        card(79, "地速星", "中箭虎", "丁得孙", "步军将校 / Infantry", "飞叉", "面颊箭痕，马上飞叉", 64, 77, 56, 66),
        card(80, "地镇星", "小遮拦", "穆春", "步军将校 / Infantry", "朴刀", "揭阳镇少主，水路遮拦", 64, 75, 55, 68),
        card(81, "地羁星", "操刀鬼", "曹正", "屠宰供应 / Butcher", "剔骨尖刀", "林冲徒弟，善剔牲口", 64, 78, 64, 70),
        card(82, "地魔星", "云里金刚", "宋万", "步军将校 / Infantry", "长枪", "身躯高大，梁山元老", 65, 78, 48, 67),
        card(83, "地妖星", "摸着天", "杜迁", "步军将校 / Infantry", "朴刀", "身长臂展，梁山开山头领", 64, 76, 49, 66),
        card(84, "地幽星", "病大虫", "薛永", "步军将校 / Martial Artist", "花枪", "江湖卖艺，棒法沉稳", 65, 80, 61, 72),
        card(85, "地伏星", "金眼彪", "施恩", "步军将校 / Infantry", "棍棒", "快活林少管营，重情知恩", 63, 74, 64, 77),
        card(86, "地僻星", "打虎将", "李忠", "步军将校 / Infantry", "梨花枪", "卖药使枪，桃花山寨主", 61, 72, 53, 65),
        card(87, "地空星", "小霸王", "周通", "马军小彪将 / Cavalry Scout", "走水绿沉枪", "桃花山寨主，性情直露", 60, 74, 51, 64),
        card(88, "地孤星", "金钱豹子", "汤隆", "军器营造 / Armorer", "铁瓜锤", "遍体金钱斑，锻造钩镰枪", 70, 82, 82, 70),
        card(89, "地全星", "鬼脸儿", "杜兴", "南山酒店 / Steward", "鬼头刀", "面貌狰狞，办事老练", 66, 72, 72, 69),
        card(90, "地短星", "出林龙", "邹渊", "步军将校 / Infantry", "朴刀", "登云山头领，出林争雄", 63, 77, 57, 66),
        card(91, "地角星", "独角龙", "邹润", "步军将校 / Infantry", "铁头功", "额生肉角，一头撞折松树", 66, 84, 60, 70),
        card(92, "地囚星", "旱地忽律", "朱贵", "南山酒店 / Scout", "鹊画弓", "梁山耳目，水亭施号箭", 72, 68, 84, 78),
        card(93, "地藏星", "笑面虎", "朱富", "酿造供应 / Brewer", "麻药酒", "笑里藏机，巧救李云", 66, 64, 82, 80),
        card(94, "地平星", "铁臂膊", "蔡福", "行刑刽子 / Executioner", "鬼头大刀", "北京两院押狱兼刽子手", 68, 81, 68, 71),
        card(95, "地损星", "一枝花", "蔡庆", "行刑刽子 / Executioner", "鬼头刀", "鬓插一枝花，兄弟同心", 63, 77, 63, 70),
        card(96, "地奴星", "催命判官", "李立", "北山酒店 / Innkeeper", "短刀", "揭阳岭黑店，眼利手快", 58, 73, 56, 57),
        card(97, "地察星", "青眼虎", "李云", "城垣营造 / Builder", "朴刀", "青眼威猛，都头出身", 70, 80, 71, 72),
        card(98, "地恶星", "没面目", "焦挺", "步军将校 / Wrestler", "拳脚", "三代相扑，擒摔见长", 62, 85, 57, 63),
        card(99, "地丑星", "石将军", "石勇", "步军将校 / Infantry", "朴刀", "好赌任侠，敢赴危难", 62, 76, 55, 69),
        card(100, "地数星", "小尉迟", "孙新", "东山酒店 / Innkeeper", "钢鞭", "登州军户，鞭枪兼使", 70, 79, 70, 75),
        card(101, "地阴星", "母大虫", "顾大嫂", "东山酒店 / Innkeeper", "雌雄虎头刀", "性烈胆大，劫狱救亲", 72, 85, 72, 83),
        card(102, "地刑星", "菜园子", "张青", "西山酒店 / Innkeeper", "扁担朴刀", "十字坡掌柜，识英雄惜好汉", 64, 74, 67, 72),
        card(103, "地壮星", "母夜叉", "孙二娘", "西山酒店 / Innkeeper", "柳叶双刀", "十字坡豪侠，胆气泼辣", 68, 83, 66, 81),
        card(104, "地劣星", "活闪婆", "王定六", "北山酒店 / Innkeeper", "走线铜锤", "行走轻捷，江边传信", 61, 71, 64, 69),
        card(105, "地健星", "险道神", "郁保四", "掌管帅旗 / Standard Bearer", "梁山帅旗", "身长一丈，力举帅旗", 70, 83, 57, 73),
        card(106, "地耗星", "白日鼠", "白胜", "传令耳目 / Scout", "酒瓢扁担", "黄泥冈卖酒，智取生辰纲", 57, 61, 72, 67),
        card(107, "地贼星", "鼓上蚤", "时迁", "机密探报 / Infiltrator", "飞檐钩索", "飞檐走壁，盗甲放火", 70, 70, 92, 78),
        card(108, "地狗星", "金毛犬", "段景住", "马匹采办 / Horse Buyer", "套马索", "识尽好马，盗取照夜玉狮子", 60, 65, 72, 68),
    ]

    static func definition(id: Int) -> ShuihuCardDefinition? {
        guard all.indices.contains(id - 1) else { return nil }
        return all[id - 1]
    }

    private static func card(
        _ rank: Int,
        _ star: String,
        _ nickname: String,
        _ name: String,
        _ role: String,
        _ weapon: String,
        _ signature: String,
        _ command: Int,
        _ might: Int,
        _ wisdom: Int,
        _ charisma: Int
    ) -> ShuihuCardDefinition {
        ShuihuCardDefinition(
            rank: rank,
            star: star,
            nickname: nickname,
            name: name,
            role: role,
            weapon: weapon,
            signature: signature,
            command: command,
            might: might,
            wisdom: wisdom,
            charisma: charisma
        )
    }
}
