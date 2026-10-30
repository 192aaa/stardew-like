extends Node
## 全局状态（自动加载）：金币、天数、种子/作物/背包物品、体力与工具等级、鱼类与配方

signal state_changed
signal skill_up(kind: String, lv: int)
signal achievement_done(id: String)

## 作物图鉴：days = 需要浇水的生长天数；regrow = 收获后保留植株回退的节数（再次结果）
const CROPS := {
	"parsnip": {"name": "防风草", "seed_cost": 20, "sell": 40, "days": 3},
	"potato": {"name": "土豆", "seed_cost": 35, "sell": 90, "days": 5},
	"straw": {"name": "草莓", "seed_cost": 80, "sell": 130, "days": 6},
	"pumpkin": {"name": "南瓜", "seed_cost": 100, "sell": 320, "days": 8},
	"corn": {"name": "玉米", "seed_cost": 120, "sell": 210, "days": 6, "regrow": 3},
	"blue": {"name": "蓝莓", "seed_cost": 90, "sell": 130, "days": 5, "regrow": 2, "yield": 2},
}

## 鱼类图鉴：w = 咬钩权重，night = 只在 18 点后出现，
## dusk = 只在 20 点后，rain = 只在雨天，legend = 传说鱼（金色标记，不进订单池）
const FISH := {
	"smelt": {"name": "小银鱼", "sell": 35, "w": 50, "night": false},
	"perch": {"name": "河鲈", "sell": 70, "w": 30, "night": false},
	"trout": {"name": "虹鳟", "sell": 120, "w": 20, "night": true},
	"moon": {"name": "月光鱼", "sell": 240, "w": 8, "dusk": true},
	"rainy": {"name": "雨鱼", "sell": 200, "w": 8, "rain": true},
	"legend": {"name": "鱼王·金鳞鲤", "sell": 1200, "w": 2, "legend": true},
}

## 采集材料（鸡蛋算入可售物品；铜/铁/宝石为矿洞产物，锭为熔炉产物，奶/毛为畜棚产出）
const MATERIALS := {
	"wood": {"name": "木材", "sell": 8},
	"stone": {"name": "石料", "sell": 12},
	"berry": {"name": "野莓", "sell": 25},
	"egg": {"name": "鸡蛋", "sell": 60},
	"copper": {"name": "铜矿", "sell": 40},
	"iron": {"name": "铁矿", "sell": 90},
	"gem": {"name": "宝石", "sell": 250},
	"copper_bar": {"name": "铜锭", "sell": 150},
	"iron_bar": {"name": "铁锭", "sell": 320},
	"milk": {"name": "牛奶", "sell": 240},
	"wool": {"name": "羊毛", "sell": 340},
}

## 加工产品（机器隔夜转化，售价比原料高）
const PRODUCTS := {
	"mayo": {"name": "蛋黄酱", "sell": 160},
	"jam": {"name": "草莓酱", "sell": 300},
	"pickle": {"name": "腌菜", "sell": 110},
	"pie": {"name": "南瓜派", "sell": 700},
	"cheese": {"name": "奶酪", "sell": 550},
}

## 料理（灶台现做）：energy = 吃下回复的体力，sell = 售价
const DISHES := {
	"salad": {"name": "田园沙拉", "sell": 120, "energy": 60, "cost": {"berry": 2, "egg": 1}},
	"soup": {"name": "南瓜浓汤", "sell": 400, "energy": 140, "cost": {"pumpkin": 1, "mayo": 1}},
	"dessert": {"name": "草莓甜点", "sell": 260, "energy": 90, "cost": {"straw": 2, "egg": 1}},
}

## 加工机收料表：原料 -> 产品（蛋黄酱机收鸡蛋；加工机收作物；
## 熔炉收矿石铸锭；奶酪机收牛奶）
const MACHINE_INPUTS := {
	"mayo": {"egg": "mayo"},
	"jam": {"straw": "jam", "pumpkin": "pie", "parsnip": "pickle"},
	"furnace": {"copper": "copper_bar", "iron": "iron_bar"},
	"cheese": {"milk": "cheese"},
}

## 制作配方
const RECIPES := {
	"scarecrow": {"name": "稻草人", "cost": {"wood": 5}},
	"sprinkler": {"name": "洒水器", "cost": {"stone": 4, "wood": 2}},
	"fertilizer": {"name": "速效肥", "cost": {"wood": 2, "stone": 2}},
	"mayo": {"name": "蛋黄酱机", "cost": {"wood": 6, "stone": 3}},
	"jam": {"name": "食品加工机", "cost": {"wood": 8, "stone": 5}},
	"stove": {"name": "灶台", "cost": {"stone": 6, "wood": 4}},
	"furnace": {"name": "熔炉", "cost": {"stone": 8, "wood": 2}},
	"cheese": {"name": "奶酪机", "cost": {"wood": 8, "stone": 6}},
	"sprinkler2": {"name": "高级洒水器", "cost": {"iron_bar": 1, "stone": 4}},
}

## 季节系统：每季 14 天，一年 4 季共 56 天；季节由天数推导，不单独存档
## crops = 本季可播种的作物；tint = 地表色调（春常色/夏偏暖/秋偏橙/冬偏冷）
const SEASON_DAYS := 14
const SEASONS := [
	{"id": "spring", "name": "春", "tint": Color(1.0, 1.0, 1.0), "crops": ["parsnip", "potato", "straw"]},
	{"id": "summer", "name": "夏", "tint": Color(1.05, 1.0, 0.84), "crops": ["straw", "corn", "blue"]},
	{"id": "autumn", "name": "秋", "tint": Color(1.06, 0.86, 0.62), "crops": ["pumpkin", "corn", "blue"]},
	{"id": "winter", "name": "冬", "tint": Color(0.84, 0.9, 1.02), "crops": []},
]

const HOE_UP_COST := 500
const CAN_UP_COST := 500
## 铁质升级：金币 + 铜矿，范围 5x5
const HOE_UP2_COST := 2200
const CAN_UP2_COST := 2200
const IRON_ORE_COST := 5
## 金质升级：金币 + 铁锭，范围 7x7
const HOE_UP3_COST := 5000
const CAN_UP3_COST := 5000
const GOLD_BAR_COST := 3
## 钓竿升级：金币 + 铜矿；收线更稳，稀有鱼权重翻倍
const ROD_UP_COST := 1800
const ROD_UP_ORE := 5

## 宠物：领养价（猫/狗各一只）
const PET_COST := 500

## 新手引导：首日五步（与 main.gd 顶部引导条一一对应）
const GUIDE_STEPS := ["锄地", "浇水", "播种", "收获", "卖货"]
## 建造温室的花费（温室无视季节，冬天也能种）
const GH_COST := 6000
const GH_WOOD := 25
const GH_STONE := 15

## 七日目标：逐日阶段目标，达成后自动发奖（kind 对应 goal_progress 统计口径）
const DAY_GOALS := [
	{"day": 1, "name": "开垦 3 块地", "kind": "till", "n": 3,
		"gold": 100, "seed": "parsnip", "seed_n": 2},
	{"day": 2, "name": "种下 3 株作物", "kind": "plant", "n": 3,
		"gold": 120, "seed": "parsnip", "seed_n": 2},
	{"day": 3, "name": "收获 3 株作物", "kind": "harvest", "n": 3,
		"gold": 150, "seed": "potato", "seed_n": 2},
	{"day": 4, "name": "钓上 1 条鱼", "kind": "fish", "n": 1,
		"gold": 150, "seed": "straw", "seed_n": 2},
	{"day": 5, "name": "累计赚到 500 金币", "kind": "earn", "n": 500,
		"gold": 200, "seed": "corn", "seed_n": 2},
	{"day": 6, "name": "完成 1 张订单", "kind": "order", "n": 1,
		"gold": 200, "seed": "blue", "seed_n": 2},
	{"day": 7, "name": "村民好感合计 20", "kind": "friend", "n": 20,
		"gold": 300, "seed": "pumpkin", "seed_n": 2},
]

## 社区收集包：need = [分类 crop/fish/mat, 物品id, 数量]，
## 交付完成给金币并永久提高体力上限（换成长线目标感）
const BUNDLES := {
	"crop": {"name": "农产收集包", "gold": 900, "stamina": 10, "need": [
		["crop", "parsnip", 5], ["crop", "potato", 3], ["crop", "straw", 2]]},
	"fish": {"name": "渔夫收集包", "gold": 1200, "stamina": 10, "need": [
		["fish", "smelt", 4], ["fish", "perch", 3], ["fish", "trout", 1]]},
	"mine": {"name": "矿工收集包", "gold": 1500, "stamina": 10, "need": [
		["mat", "copper", 10], ["mat", "iron", 6], ["mat", "gem", 1]]},
	"ranch": {"name": "牧场收集包", "gold": 1000, "stamina": 10, "need": [
		["mat", "milk", 3], ["mat", "wool", 2], ["mat", "egg", 5]]},
}

## 技能系统：三类经验，每 XP_PER_LEVEL 点升 1 级，升级 max_stamina +10
const XP_PER_LEVEL := 100
const MAX_SKILL_LV := 5
const SKILL_NAMES := {"farm": "务农", "fish": "钓鱼", "gather": "采集"}

## 家禽养殖
const CHICKEN_COST := 800
const MAX_CHICKENS := 4

## 牛羊牧场（畜棚在西侧，过夜产出牛奶/羊毛）
const COW_COST := 2500
const SHEEP_COST := 2000
const MAX_COWS := 2
const MAX_SHEEP := 2

## 成就图鉴（check_achievements 里逐条校验）
const ACHIEVEMENTS := {
	"first_harvest": {"name": "初次收获", "desc": "收获第一株作物"},
	"harvest_50": {"name": "丰收在望", "desc": "累计收获 50 株作物"},
	"gold_5000": {"name": "小有积蓄", "desc": "持有金币达到 5000"},
	"first_fish": {"name": "愿者上钩", "desc": "钓起第一条鱼"},
	"fish_dex": {"name": "鱼类学家", "desc": "集齐全部 6 种鱼"},
	"legend_fish": {"name": "天选钓手", "desc": "钓起传说鱼王"},
	"first_cook": {"name": "小厨神", "desc": "在灶台做出第一道料理"},
	"gift_5": {"name": "礼尚往来", "desc": "累计送礼 5 次"},
	"first_egg": {"name": "鸡窝喜讯", "desc": "捡到第一颗鸡蛋"},
	"chicken_4": {"name": "养鸡大户", "desc": "鸡舍里养满 4 只鸡"},
	"skill_3": {"name": "技艺精进", "desc": "任一技能达到 3 级"},
	"order_10": {"name": "供货明星", "desc": "完成 10 张订单"},
	"friend_70": {"name": "知心好友", "desc": "与任一村民好感度达到 70"},
	"day_10": {"name": "扎下根来", "desc": "在农场度过第 10 天"},
	"metal_10": {"name": "冶炼师傅", "desc": "累计熔炼 10 块金属锭"},
	"cheese_1": {"name": "奶香四溢", "desc": "做出第一块奶酪"},
}

## 送礼好感里程碑：达到对应好感首次回赠（金币/种子/宝石/金币）
const GIFT_MILESTONES := [20, 40, 60, 80]
const GIFT_REWARDS := {"gold": 100, "seeds": 3, "gem": 1, "gold2": 300}
const GIFT_DAILY := 2  # 每人每天最多收 2 份礼

## 可选主角：4 位，各有 1 个被动特长 + 1 个主动技能（Q 键释放，耗体力、有冷却）
## kind 决定被动/主动走哪套逻辑：stamina 体力 / sell 卖价 / mine 矿石 / fish 钓鱼
const HEROES := [
	{"name": "阿蓝", "title": "农夫", "tex": "res://assets/player_lan.png",
		"color": Color(0.36, 0.52, 0.86),
		"passive": "stamina", "passive_name": "勤劳",
		"passive_text": "体力上限 +20",
		"skill_name": "疾行", "skill_text": "4 秒内移速 +60%", "cd": 20.0, "cost": 8.0},
	{"name": "阿茉", "title": "商人", "tex": "res://assets/player_mo.png",
		"color": Color(0.86, 0.40, 0.44),
		"passive": "sell", "passive_name": "精明",
		"passive_text": "卖价 +15%",
		"skill_name": "吆喝", "skill_text": "30 秒内卖价再 +50%", "cd": 60.0, "cost": 5.0},
	{"name": "阿铁", "title": "矿工", "tex": "res://assets/player_tie.png",
		"color": Color(0.86, 0.60, 0.28),
		"passive": "mine", "passive_name": "矿工直觉",
		"passive_text": "敲碎矿石额外 +1",
		"skill_name": "爆破", "skill_text": "一次震碎身边所有矿石", "cd": 45.0, "cost": 15.0},
	{"name": "阿溪", "title": "渔夫", "tex": "res://assets/player_xi.png",
		"color": Color(0.30, 0.62, 0.58),
		"passive": "fish", "passive_name": "稳步",
		"passive_text": "钓鱼绿区 +20%，失误上限 +1",
		"skill_name": "撒网", "skill_text": "立刻钓上一条鱼", "cd": 60.0, "cost": 12.0},
]

var gold := 500
var day := 1
## 当前主角（HEROES 下标）：新游戏选角写入存档，旧档默认 0 = 阿蓝
var hero_id := 0
var seeds := {"parsnip": 5, "potato": 0, "straw": 0, "pumpkin": 0, "corn": 0, "blue": 0}
var harvest := {"parsnip": 0, "potato": 0, "straw": 0, "pumpkin": 0, "corn": 0, "blue": 0}
## 背包：木材/石料/野莓/鱼/矿石/金属锭/奶毛/加工产品/料理
var items := {
	"wood": 0, "stone": 0, "berry": 0, "smelt": 0, "perch": 0, "trout": 0,
	"copper": 0, "iron": 0, "gem": 0,
	"copper_bar": 0, "iron_bar": 0, "milk": 0, "wool": 0,
	"mayo": 0, "jam": 0, "pickle": 0, "pie": 0, "cheese": 0,
	"salad": 0, "soup": 0, "dessert": 0,
}

## 村民好感度（聊天涨，影响对话台词）
var friends := {"rosa": 0, "ben": 0}

## 体力与工具等级（2 = 铜，3x3 范围）
var stamina := 100.0
var max_stamina := 100.0
var hoe_level := 1
var can_level := 1

## 技能经验与等级（farm 务农 / fish 钓鱼 / gather 采集）
var xp := {"farm": 0, "fish": 0, "gather": 0}
var skill_lv := {"farm": 1, "fish": 1, "gather": 1}

## 鱼类图鉴：{鱼id: 累计钓到条数}；宝箱累计打开次数
var caught_fish := {}
var chest_opened := 0

## 家禽养殖：鸡的数量与待捡鸡蛋数
var chicken_count := 0
var eggs_ready := 0
var total_eggs := 0

## 牛羊牧场：数量、待收产出与累计统计
var cow_count := 0
var sheep_count := 0
var milk_ready := 0
var wool_ready := 0
var total_milk := 0
var total_wool := 0
var total_bars := 0    # 累计熔炼金属锭数
var total_cheese := 0  # 累计做出奶酪数
var rod_lv := 1        # 鱼竿等级（2 = 铜钓竿）

## 宠物：已领养的宠物（"cat"/"dog"）与心情（0-100）
var pets: Array = []
var pet_mood := {"cat": 0, "dog": 0}
## 宠物窝（安放宠物的地方）：是否已建好 + 每只宠物现在是否待在窝里
const PET_HOUSE_COST := 800
var pet_house := false
var pets_home := {"cat": false, "dog": false}

## 可建造建筑：小屋（进去是仓库界面）/ 矿洞入口（进去是矿洞界面）
## 每座建筑占农舍旁一个固定槽位，重复建造同种也会开新槽
const BUILD_DEFS := {
	"storehouse": {"name": "小屋仓库", "gold": 1200, "wood": 20,
		"desc": "建好后按 E 进门：独立仓库界面，背包材料可存可取"},
	"mine_entrance": {"name": "矿洞入口", "gold": 1500, "wood": 30,
		"desc": "建好后按 E 进洞：独立矿洞界面，一层层往下挖矿"},
}
## 仓库容量：最多存 8 种物品（每种数量不限）
const STORAGE_CAP := 8
## 已建建筑：每项 {kind, slot}
var buildings: Array = []
## 仓库：物品id -> 数量（进存档）
var storage := {}

## 统计与成就
var total_harvest := 0
var orders_done := 0
var achievements := {}  # id -> true
var total_cooked := 0   # 累计烹饪次数
var gift_count := 0     # 累计送礼次数
## 送礼里程碑回赠记录：{村民id: [4 个 bool]}，入存档防重复领取
var gift_milestones := {"rosa": [false, false, false, false], "ben": [false, false, false, false]}

## 新手引导进度：0 锄地 / 1 浇水 / 2 播种 / 3 收获 / 4 卖货，5 = 已完成
var guide_step := 0
## 七日目标：统计口径 + 已发奖记录 {day: true}
var total_tilled := 0
var total_planted := 0
var total_earned := 0
var goals_claimed := {}
## 温室是否已建造 / 已完成的收集包 id
var greenhouse_built := false
var bundles_done: Array = []


## 当前季节下标（0 春 / 1 夏 / 2 秋 / 3 冬）
func season_index() -> int:
	return int(floor((day - 1) / float(SEASON_DAYS))) % SEASONS.size()


func season() -> Dictionary:
	return SEASONS[season_index()]


func season_name() -> String:
	return String(season().name)


## 本季第几天（1 起）
func season_day() -> int:
	return (day - 1) % SEASON_DAYS + 1


## 该作物本季能否播种
func can_plant(id: String) -> bool:
	return (season().crops as Array).has(id)


## 该作物允许播种的季节名（错误提示用）
func crop_seasons(id: String) -> String:
	var out: Array = []
	for s in SEASONS:
		if (s.crops as Array).has(id):
			out.append(String(s.name))
	return "" if out.is_empty() else "、".join(out)


## 温室播种判定：温室内无视季节（farm.try_plant 调用）
func can_plant_in(greenhouse: bool, id: String) -> bool:
	return greenhouse or can_plant(id)


## 七日目标统计口径 -> 当前累计值
func goal_progress(kind: String) -> int:
	match kind:
		"till":
			return total_tilled
		"plant":
			return total_planted
		"harvest":
			return total_harvest
		"fish":
			var n := 0
			for k in caught_fish:
				n += int(caught_fish[k])
			return n
		"earn":
			return total_earned
		"order":
			return orders_done
		"friend":
			return int(friends.get("rosa", 0)) + int(friends.get("ben", 0))
	return 0


## 收集包物品持有量（作物在 harvest 仓，其余在 items 背包）
func bundle_stock(kind: String, id: String) -> int:
	if kind == "crop":
		return int(harvest.get(id, 0))
	return int(items.get(id, 0))


func bundle_name(kind: String, id: String) -> String:
	if kind == "crop":
		return String(CROPS[id].name)
	if kind == "fish":
		return String(FISH[id].name)
	return String(MATERIALS.get(id, {"name": id}).name)


func add_gold(n: int) -> void:
	gold += n
	if n > 0:
		total_earned += n  # 七日目标「累计赚钱」统计
	state_changed.emit()


func add_seed(id: String, n: int) -> void:
	seeds[id] += n
	state_changed.emit()


func use_seed(id: String, n: int) -> void:
	seeds[id] -= n
	state_changed.emit()


func add_harvest(id: String, n: int) -> void:
	harvest[id] += n
	state_changed.emit()


func remove_harvest(id: String, n: int) -> void:
	harvest[id] -= n
	state_changed.emit()


## 消耗体力，不足返回 false
func use_stamina(v: float) -> bool:
	if stamina < v:
		return false
	stamina -= v
	state_changed.emit()
	return true


func add_item(id: String, n: int) -> void:
	items[id] = items.get(id, 0) + n
	state_changed.emit()


## 检查材料是否够
func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if items.get(k, 0) < int(cost[k]):
			return false
	return true


## 扣除材料（先确认 can_afford）
func consume(cost: Dictionary) -> void:
	for k in cost:
		items[k] -= int(cost[k])
	state_changed.emit()


## 增加技能经验；满 XP_PER_LEVEL 升 1 级：体力上限 +10（最高 MAX_SKILL_LV 级）
func add_xp(kind: String, n: int) -> void:
	if skill_lv[kind] >= MAX_SKILL_LV:
		return
	xp[kind] += n
	while xp[kind] >= XP_PER_LEVEL and skill_lv[kind] < MAX_SKILL_LV:
		xp[kind] -= XP_PER_LEVEL
		skill_lv[kind] += 1
		max_stamina += 10.0
		stamina = minf(stamina + 10.0, max_stamina)
		skill_up.emit(kind, skill_lv[kind])
	state_changed.emit()


## 记录钓到的鱼；返回是否为图鉴首次收录
func mark_fish(id: String) -> bool:
	var first: bool = not caught_fish.has(id)
	caught_fish[id] = int(caught_fish.get(id, 0)) + 1
	return first


## 逐条校验成就，新达成的发 achievement_done 信号；silent=true 用于读档补录不弹提示
func check_achievements(silent := false) -> void:
	for id in ACHIEVEMENTS:
		if not achievements.has(id) and _ach_ok(id):
			achievements[id] = true
			if not silent:
				achievement_done.emit(id)


func _ach_ok(id: String) -> bool:
	match id:
		"first_harvest":
			return total_harvest >= 1
		"harvest_50":
			return total_harvest >= 50
		"gold_5000":
			return gold >= 5000
		"first_fish":
			return not caught_fish.is_empty()
		"fish_dex":
			return caught_fish.size() >= FISH.size()
		"first_egg":
			return total_eggs >= 1
		"chicken_4":
			return chicken_count >= MAX_CHICKENS
		"skill_3":
			return skill_lv.farm >= 3 or skill_lv.fish >= 3 or skill_lv.gather >= 3
		"order_10":
			return orders_done >= 10
		"friend_70":
			return friends.rosa >= 70 or friends.ben >= 70
		"day_10":
			return day >= 10
		"legend_fish":
			return int(caught_fish.get("legend", 0)) >= 1
		"first_cook":
			return total_cooked >= 1
		"gift_5":
			return gift_count >= 5
		"metal_10":
			return total_bars >= 10
		"cheese_1":
			return total_cheese >= 1
	return false


## 新游戏：把全局状态恢复到初始值（标题界面「新游戏」清档后调用）
func reset_state() -> void:
	gold = 500
	day = 1
	seeds = {"parsnip": 5, "potato": 0, "straw": 0, "pumpkin": 0, "corn": 0, "blue": 0}
	harvest = {"parsnip": 0, "potato": 0, "straw": 0, "pumpkin": 0, "corn": 0, "blue": 0}
	items = {
		"wood": 0, "stone": 0, "berry": 0, "smelt": 0, "perch": 0, "trout": 0,
		"copper": 0, "iron": 0, "gem": 0,
		"copper_bar": 0, "iron_bar": 0, "milk": 0, "wool": 0,
		"mayo": 0, "jam": 0, "pickle": 0, "pie": 0, "cheese": 0,
		"salad": 0, "soup": 0, "dessert": 0,
	}
	friends = {"rosa": 0, "ben": 0}
	stamina = 100.0
	max_stamina = 100.0
	hoe_level = 1
	can_level = 1
	xp = {"farm": 0, "fish": 0, "gather": 0}
	skill_lv = {"farm": 1, "fish": 1, "gather": 1}
	caught_fish = {}
	chest_opened = 0
	chicken_count = 0
	eggs_ready = 0
	total_eggs = 0
	cow_count = 0
	sheep_count = 0
	milk_ready = 0
	wool_ready = 0
	total_milk = 0
	total_wool = 0
	total_bars = 0
	total_cheese = 0
	rod_lv = 1
	pets = []
	pet_mood = {"cat": 0, "dog": 0}
	pet_house = false
	pets_home = {"cat": false, "dog": false}
	buildings = []
	storage = {}
	total_harvest = 0
	orders_done = 0
	achievements = {}
	total_cooked = 0
	gift_count = 0
	gift_milestones = {"rosa": [false, false, false, false], "ben": [false, false, false, false]}
	guide_step = 0
	total_tilled = 0
	total_planted = 0
	total_earned = 0
	goals_claimed = {}
	greenhouse_built = false
	bundles_done = []
	state_changed.emit()


## 当前主角数据表（越界保护，存档损坏时退回阿蓝）
func hero() -> Dictionary:
	return HEROES[clampi(hero_id, 0, HEROES.size() - 1)]


## 当前主角的被动类型：stamina / sell / mine / fish
func hero_kind() -> String:
	return String(hero().passive)


## 卖价倍率（阿茉被动 +15%）；临时吆喝加价由 main 另外叠乘
func sell_mult() -> float:
	return 1.15 if hero_kind() == "sell" else 1.0


## 敲碎一块矿石额外多给的矿料（阿铁被动）
func ore_bonus() -> int:
	return 1 if hero_kind() == "mine" else 0
