extends Node
## 全局状态（自动加载）：金币、天数、种子/作物/背包物品、体力与工具等级、鱼类与配方

signal state_changed
signal skill_up(kind: String, lv: int)
signal achievement_done(id: String)

## 作物图鉴：days = 需要浇水的生长天数
const CROPS := {
	"parsnip": {"name": "防风草", "seed_cost": 20, "sell": 40, "days": 3},
	"potato": {"name": "土豆", "seed_cost": 35, "sell": 90, "days": 5},
	"straw": {"name": "草莓", "seed_cost": 80, "sell": 130, "days": 6},
	"pumpkin": {"name": "南瓜", "seed_cost": 100, "sell": 320, "days": 8},
}

## 鱼类图鉴：w = 咬钩权重，night = 只在 18 点后出现
const FISH := {
	"smelt": {"name": "小银鱼", "sell": 35, "w": 50, "night": false},
	"perch": {"name": "河鲈", "sell": 70, "w": 30, "night": false},
	"trout": {"name": "虹鳟", "sell": 120, "w": 20, "night": true},
}

## 采集材料（鸡蛋算入可售物品）
const MATERIALS := {
	"wood": {"name": "木材", "sell": 8},
	"stone": {"name": "石料", "sell": 12},
	"berry": {"name": "野莓", "sell": 25},
	"egg": {"name": "鸡蛋", "sell": 60},
}

## 制作配方
const RECIPES := {
	"scarecrow": {"name": "稻草人", "cost": {"wood": 5}},
	"sprinkler": {"name": "洒水器", "cost": {"stone": 4, "wood": 2}},
	"fertilizer": {"name": "速效肥", "cost": {"wood": 2, "stone": 2}},
}

const HOE_UP_COST := 500
const CAN_UP_COST := 500

## 技能系统：三类经验，每 XP_PER_LEVEL 点升 1 级，升级 max_stamina +10
const XP_PER_LEVEL := 100
const MAX_SKILL_LV := 5
const SKILL_NAMES := {"farm": "务农", "fish": "钓鱼", "gather": "采集"}

## 家禽养殖
const CHICKEN_COST := 800
const MAX_CHICKENS := 4

## 成就图鉴（check_achievements 里逐条校验）
const ACHIEVEMENTS := {
	"first_harvest": {"name": "初次收获", "desc": "收获第一株作物"},
	"harvest_50": {"name": "丰收在望", "desc": "累计收获 50 株作物"},
	"gold_5000": {"name": "小有积蓄", "desc": "持有金币达到 5000"},
	"first_fish": {"name": "愿者上钩", "desc": "钓起第一条鱼"},
	"fish_dex": {"name": "鱼类学家", "desc": "集齐全部 3 种鱼"},
	"first_egg": {"name": "鸡窝喜讯", "desc": "捡到第一颗鸡蛋"},
	"chicken_4": {"name": "养鸡大户", "desc": "鸡舍里养满 4 只鸡"},
	"skill_3": {"name": "技艺精进", "desc": "任一技能达到 3 级"},
	"order_10": {"name": "供货明星", "desc": "完成 10 张订单"},
	"friend_70": {"name": "知心好友", "desc": "与任一村民好感度达到 70"},
	"day_10": {"name": "扎下根来", "desc": "在农场度过第 10 天"},
}

var gold := 500
var day := 1
var seeds := {"parsnip": 5, "potato": 0, "straw": 0, "pumpkin": 0}
var harvest := {"parsnip": 0, "potato": 0, "straw": 0, "pumpkin": 0}
## 背包：木材/石料/野莓/鱼
var items := {"wood": 0, "stone": 0, "berry": 0, "smelt": 0, "perch": 0, "trout": 0}

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

## 统计与成就
var total_harvest := 0
var orders_done := 0
var achievements := {}  # id -> true


func add_gold(n: int) -> void:
	gold += n
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
	return false
