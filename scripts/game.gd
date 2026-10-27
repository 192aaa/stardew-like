extends Node
## 全局状态（自动加载）：金币、天数、种子/作物/背包物品、体力与工具等级、鱼类与配方

signal state_changed

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

## 采集材料
const MATERIALS := {
	"wood": {"name": "木材", "sell": 8},
	"stone": {"name": "石料", "sell": 12},
	"berry": {"name": "野莓", "sell": 25},
}

## 制作配方
const RECIPES := {
	"scarecrow": {"name": "稻草人", "cost": {"wood": 5}},
	"sprinkler": {"name": "洒水器", "cost": {"stone": 4, "wood": 2}},
	"fertilizer": {"name": "速效肥", "cost": {"wood": 2, "stone": 2}},
}

const HOE_UP_COST := 500
const CAN_UP_COST := 500

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
