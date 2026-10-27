extends Node2D
## 主场景逻辑：昼夜循环、天气（晴/雨）、八种工具（锄/壶/种子x4/鱼竿/斧镐）、体力系统、
## 钓鱼小游戏、村民对话与好感度、商店（种子/作物/鱼/材料/工具升级）、制作与放置、HUD 提示

const DAY_START_MIN := 6 * 60
const DAY_END_MIN := 24 * 60
const MINUTES_PER_SECOND := 12.0  # 现实 90 秒 = 游戏 1 天

enum Tool { HOE, CAN, SEED_PARSNIP, SEED_POTATO, SEED_STRAW, SEED_PUMP, ROD, AXE }

const TOOL_NAMES := ["锄头", "水壶", "防风草种", "土豆种", "草莓种", "南瓜种", "鱼竿", "斧镐"]
const TOOL_SEED := {
	Tool.SEED_PARSNIP: "parsnip", Tool.SEED_POTATO: "potato",
	Tool.SEED_STRAW: "straw", Tool.SEED_PUMP: "pumpkin",
}
const TEX_BOBBER := preload("res://assets/bobber.png")
const TEX_FISH := preload("res://assets/fish.png")
const TEX_EGG := preload("res://assets/egg.png")
const RainScript := preload("res://scripts/rain.gd")
const VillagerScript := preload("res://scripts/villager.gd")
const ChickenScript := preload("res://scripts/chicken.gd")

## 村民称呼（订单/对话用）
const VILLAGER_NAMES := {"rosa": "罗莎", "ben": "老本"}

## 村民配置：活动区与出生点（已避开建筑/池塘/栅栏）
const VILLAGERS := [
	{"id": "rosa", "name": "罗莎", "tex": "res://assets/villager_rosa.png",
		"roam": Rect2(-1290, 590, 240, 140), "spawn": Vector2(-1170, 640)},
	{"id": "ben", "name": "老本", "tex": "res://assets/villager_ben.png",
		"roam": Rect2(330, -280, 300, 160), "spawn": Vector2(480, -170)},
]

## 村民台词：好感 <30 陌生 / <70 熟悉 / >=70 好友
const DIALOGS := {
	"rosa": {
		"low": [
			"花田的花今天开得真好看，你注意到了吗？",
			"水井边很凉快，我常在那儿发呆。",
			"听说下雨天鱼儿特别爱咬钩哦。",
			"新来的农场主？你的地收拾得还不错嘛。",
		],
		"mid": [
			"我们已经是朋友啦，有空来花田找我玩。",
			"老本的南瓜饼可香了，可惜他不肯给我配方。",
			"夜里池塘边有萤火虫，非常美的。",
			"草莓红红的最可爱了，种一点吧？",
		],
		"high": [
			"有你在这个村子，热闹多了。谢谢你！",
			"这朵花本来想送你的……啊，忘带了，明天一定！",
			"等你农场大丰收，一定要请我吃草莓！",
		],
	},
	"ben": {
		"low": [
			"后生，种子钱要攒好，别乱花。",
			"我这把老骨头，敲不动石头喽。",
			"雨天省水壶，晴天别偷懒，记住了？",
			"货摊上的东西随便看，别客气。",
		],
		"mid": [
			"你小子干活挺麻利，像年轻时候的我。",
			"南瓜要长很久，耐心点，收获时你就懂了。",
			"乌鸦最怕稻草人，农田边立一个准没错。",
		],
		"high": [
			"好小子，这村子以后就指望你啦。",
			"改天教你两手钓鱼的诀窍……先收你点学费，哈哈。",
			"南瓜熟了给我留一个，我给你做南瓜饼。",
		],
	},
}

@onready var player: CharacterBody2D = $Player
@onready var farm: Node2D = $Farm
@onready var decor: Node2D = $Decor
@onready var gather: Node2D = $Gather
@onready var canvas_mod: CanvasModulate = $CanvasModulate
@onready var day_label: Label = $UI/DayTime
@onready var gold_label: Label = $UI/Gold
@onready var hint_label: Label = $UI/Hint
@onready var toast_label: Label = $UI/Toast
@onready var fade: ColorRect = $UI/Fade
@onready var shop_panel: PanelContainer = $UI/ShopPanel
@onready var _slot_labels: Array = [
	$UI/Hotbar/Slot1/L, $UI/Hotbar/Slot2/L, $UI/Hotbar/Slot3/L,
	$UI/Hotbar/Slot4/L, $UI/Hotbar/Slot5/L, $UI/Hotbar/Slot6/L,
	$UI/Hotbar/Slot7/L, $UI/Hotbar/Slot8/L,
]
@onready var _slot_panels: Array = [
	$UI/Hotbar/Slot1, $UI/Hotbar/Slot2, $UI/Hotbar/Slot3,
	$UI/Hotbar/Slot4, $UI/Hotbar/Slot5, $UI/Hotbar/Slot6,
	$UI/Hotbar/Slot7, $UI/Hotbar/Slot8,
]

var current_tool: int = Tool.HOE
var time_min := float(DAY_START_MIN)
var sleeping := false
var weather := "sun"  # "sun" / "rain"
var shop_open := false
var craft_open := false
var place_mode := ""
var dialog_open := false
var orders_open := false
var dex_open := false
var _loading := false
var _dialog_villager: Node2D = null
var _talked_today := {}
var _villagers: Array = []
var _rain_node: Node2D
var _dialog_panel: PanelContainer
var _dialog_name: Label
var _dialog_text: Label
var _toast_tween: Tween
var _ui_font: SystemFont
var _shop_rows := {}
var _shop_kinds := {}
var _shop_gold_label: Label
var _hoe_btn: Button
var _can_btn: Button
var craft_panel: PanelContainer
var _craft_rows := {}
var _craft_gold: Label
var help_open := false
var help_panel: PanelContainer
var _stam_fill: ColorRect
var _stam_label: Label

# 订单任务板
var _orders: Array = []  # {kind, item, n, gold, who, done}
var _orders_panel: PanelContainer
var _orders_gold: Label
var _order_descs: Array = []
var _order_btns: Array = []

# 图鉴 · 技能 · 成就面板
var _dex_panel: PanelContainer
var _dex_skill_labels := {}
var _dex_fish_labels := {}
var _dex_chest: Label
var _dex_ach_labels := {}

# 家禽养殖
var _chickens: Array = []
var _egg_sprites: Array = []
var _chicken_btn: Button

# 钓鱼状态机：0 无 / 1 等待咬钩 / 2 咬钩窗口 / 3 搏鱼小游戏
var fish_state := 0
var _bobber: Sprite2D
var _bobber_base := Vector2.ZERO
var _bite_t := 0.0
var _bite_window := 0.0
var _bar_y := 0.5
var _bar_v := 0.0
var _fish_y := 0.5
var _fish_target := 0.5
var _fish_timer := 0.0
var _progress := 30.0
var _wt := 0.0
var _fish_root: Control
var _fish_bar: ColorRect
var _fish_icon: TextureRect
var _prog_fill: ColorRect


func _ready() -> void:
	_ui_font = SystemFont.new()
	_ui_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "SimSun"])
	Game.state_changed.connect(_refresh_hud)
	Game.state_changed.connect(_ach_tick)
	Game.skill_up.connect(_on_skill_up)
	Game.achievement_done.connect(_on_achievement)
	_build_shop()
	_build_craft()
	_build_help()
	_build_stamina()
	_build_fishing_ui()
	_build_orders()
	_build_dex()
	_build_eggs()
	_bobber = Sprite2D.new()
	_bobber.texture = TEX_BOBBER
	_bobber.visible = false
	add_child(_bobber)
	_build_dialog()
	_rain_node = RainScript.new()
	_rain_node.z_index = 40
	_rain_node.visible = false
	add_child(_rain_node)
	for cfg in VILLAGERS:
		var npc = VillagerScript.new()
		npc.setup(load(cfg.tex), cfg.roam, cfg.name, cfg.spawn)
		add_child(npc)
		_villagers.append(npc)
	weather = "rain" if randf() < 0.3 else "sun"
	_rain_node.visible = weather == "rain"
	_refresh_hud()
	player.position = decor.DOOR_POS + Vector2(0, 44)
	if _do_load(false):
		_toast("已读取第 %d 天存档 · F5 存档 / F9 读档 · 按 H 看帮助" % Game.day)
	else:
		_gen_orders()
		_sync_chickens()
		_toggle_help(true)
		_toast("欢迎回来！锄地(1) 浇水(2) 种地，7 鱼竿 8 斧镐，C 制作，H 帮助")


func _process(delta: float) -> void:
	_wt += delta
	if not sleeping:
		time_min += delta * MINUTES_PER_SECOND
		if time_min >= DAY_END_MIN:
			_do_sleep(true)
	canvas_mod.color = _sky_color(time_min)
	if weather == "rain":
		canvas_mod.color = canvas_mod.color.lerp(Color(0.62, 0.68, 0.8), 0.4)
	day_label.text = "第 %d 天  %s · %s" % [Game.day, _clock_text(), "雨" if weather == "rain" else "晴"]
	_update_target()
	_update_hint()
	if shop_open and player.position.distance_to(decor.SHOP_POS) > 130.0:
		_toggle_shop(false)
	if orders_open and player.position.distance_to(decor.BOARD_POS) > 100.0:
		_toggle_orders(false)
	if dialog_open and player.position.distance_to(_dialog_villager.position) > 110.0:
		_toggle_dialog(false)
	Music.update_phase(time_min, weather == "rain")
	_update_fishing(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tool_1"):
		_switch_tool(Tool.HOE)
	elif event.is_action_pressed("tool_2"):
		_switch_tool(Tool.CAN)
	elif event.is_action_pressed("tool_3"):
		_switch_tool(Tool.SEED_PARSNIP)
	elif event.is_action_pressed("tool_4"):
		_switch_tool(Tool.SEED_POTATO)
	elif event.is_action_pressed("tool_5"):
		_switch_tool(Tool.SEED_STRAW)
	elif event.is_action_pressed("tool_6"):
		_switch_tool(Tool.SEED_PUMP)
	elif event.is_action_pressed("tool_7"):
		_switch_tool(Tool.ROD)
	elif event.is_action_pressed("tool_8"):
		_switch_tool(Tool.AXE)
	elif event.is_action_pressed("mute"):
		var m: bool = Music.toggle_mute()
		_toast("背景音乐已%s（M 切换）" % ("开启" if not m else "关闭"))
	elif event.is_action_pressed("codex"):
		_toggle_dex(not dex_open)
	elif event.is_action_pressed("craft"):
		if help_open:
			_toggle_help(false)
		elif place_mode != "":
			_cancel_place()
		else:
			_toggle_craft(not craft_open)
	elif event.is_action_pressed("help"):
		_toggle_help(not help_open)
	elif event.is_action_pressed("save_game"):
		if not sleeping:
			_do_save()
	elif event.is_action_pressed("load_game"):
		if not sleeping:
			_do_load()
	elif event.is_action_pressed("use"):
		if help_open:
			_toggle_help(false)
		elif dex_open:
			_toggle_dex(false)
		elif orders_open:
			_toggle_orders(false)
		elif craft_open:
			_toggle_craft(false)
		elif dialog_open:
			_toggle_dialog(false)
		elif place_mode != "":
			_place_at_target()
		elif shop_open:
			_toggle_shop(false)
		else:
			_use_tool()
	elif event.is_action_pressed("interact"):
		if help_open:
			_toggle_help(false)
		elif dex_open:
			_toggle_dex(false)
		elif orders_open:
			_toggle_orders(false)
		elif shop_open:
			_toggle_shop(false)
		elif craft_open:
			_toggle_craft(false)
		elif dialog_open:
			_toggle_dialog(false)
		elif _near_villager() != null:
			_talk_to(_near_villager())
		elif gather.pick_berry(player.position) > 0:
			player.pop()
			Game.add_xp("gather", 4)
			Sfx.play("pick")
			_float_text("+野莓", player.position + Vector2(0, -30), Color(1, 0.55, 0.5))
			_toast("摘到了野莓！已放进背包，明天会再结果")
		elif player.position.distance_to(decor.BOARD_POS) < 70.0:
			_toggle_orders(true)
		elif player.position.distance_to(decor.COOP_POS) < 80.0:
			_collect_eggs()
		elif player.position.distance_to(decor.SHOP_POS) < 90.0:
			_toggle_shop(true)
		elif player.position.distance_to(decor.DOOR_POS) < 80.0 and not sleeping:
			_do_sleep(false)
	elif event.is_action_pressed("ui_cancel"):
		if help_open:
			_toggle_help(false)
		elif dex_open:
			_toggle_dex(false)
		elif orders_open:
			_toggle_orders(false)
		elif shop_open:
			_toggle_shop(false)
		elif craft_open:
			_toggle_craft(false)
		elif dialog_open:
			_toggle_dialog(false)
		elif place_mode != "":
			_cancel_place()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and not shop_open and not craft_open \
			and not orders_open and not dex_open and place_mode == "":
		_use_tool()


# ---------- 工具与动作 ----------

func _switch_tool(t: int) -> void:
	if fish_state > 0:
		_end_fishing()
		_toast("收起了鱼竿")
	current_tool = t
	_toast("切换到 %s" % TOOL_NAMES[t])
	_refresh_hud()


func _update_target() -> void:
	var cell = farm.cell_at(player.position + player.facing * 26.0)
	if cell == null:
		cell = farm.cell_at(player.position)
	if cell == null:
		farm.set_target(Vector2i.ZERO, false)
		farm.set_preview("", Vector2i.ZERO, false)
	else:
		farm.set_target(cell, true)
		# 只有稻草人/洒水器有放置预览图，施肥无实体
		var pm: String = place_mode if (place_mode == "scarecrow" or place_mode == "sprinkler") else ""
		farm.set_preview(pm, cell, pm != "")


func _area_cells(center: Vector2i, level: int) -> Array:
	if level < 2:
		return [center]
	var out: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			out.append(center + Vector2i(dx, dy))
	return out


func _use_tool() -> void:
	if current_tool == Tool.ROD:
		_fishing_action()
		return
	if current_tool == Tool.AXE:
		_axe_action()
		return
	var cell = farm.cell_at(player.position + player.facing * 26.0)
	if cell == null:
		cell = farm.cell_at(player.position)
	if cell == null:
		_toast("只能对农田使用工具")
		return
	# 收获优先：任何工具对着成熟作物都能收
	var got = farm.try_harvest(cell)
	if got != "":
		Game.add_harvest(got, 1)
		Game.total_harvest += 1
		Game.add_xp("farm", 6)
		_toast("收获了%s！" % Game.CROPS[got].name)
		_float_text("+1 %s" % Game.CROPS[got].name, _cell_center(cell), Color(1, 0.9, 0.35))
		Sfx.play("harvest")
		player.pop()
		return
	match current_tool:
		Tool.HOE:
			if not Game.use_stamina(3.0):
				_toast("体力不够了，回床上睡一觉吧")
				return
			var done := 0
			var err := ""
			for c in _area_cells(cell, Game.hoe_level):
				var msg: String = farm.try_till(c)
				if msg == "":
					done += 1
				elif err == "":
					err = msg
			if done > 0:
				player.pop()
				Sfx.play("hoe")
				if Game.hoe_level >= 2:
					_toast("铜锄开垦了 %d 块地" % done)
			else:
				_toast(err)
		Tool.CAN:
			if not Game.use_stamina(2.0):
				_toast("体力不够了，回床上睡一觉吧")
				return
			var done := 0
			var err := ""
			for c in _area_cells(cell, Game.can_level):
				var msg: String = farm.try_water(c)
				if msg == "":
					done += 1
				elif err == "":
					err = msg
			if done > 0:
				player.pop()
				Sfx.play("water")
				if Game.can_level >= 2:
					_toast("铜壶浇了 %d 块地" % done)
			else:
				_toast(err)
		Tool.SEED_PARSNIP, Tool.SEED_POTATO, Tool.SEED_STRAW, Tool.SEED_PUMP:
			var id: String = TOOL_SEED[current_tool]
			if Game.seeds[id] <= 0:
				_toast("没有%s种子了，去商店买吧" % Game.CROPS[id].name)
				return
			var msg: String = farm.try_plant(cell, id)
			if msg == "":
				Game.use_seed(id, 1)
				Game.add_xp("farm", 2)
				_toast("种下了%s" % Game.CROPS[id].name)
				Sfx.play("plant")
				player.pop()
			else:
				_toast(msg)


func _axe_action() -> void:
	var p: Vector2 = player.position + player.facing * 36.0
	if not gather.near(p):
		_toast("附近没有能敲的石头或树枝")
		return
	if not Game.use_stamina(3.0):
		_toast("体力不够了，回床上睡一觉吧")
		return
	var res: Dictionary = gather.hit_at(p)
	Sfx.play("axe")
	player.pop()
	if res.result == "break":
		var n := 1 + (1 if randf() < 0.3 else 0)
		Game.add_xp("gather", 4)
		if res.kind == "rock":
			Game.add_item("stone", n)
			_toast("敲碎了石头！获得石料 x%d" % n)
			_float_text("+%d 石料" % n, p, Color(0.85, 0.88, 0.95))
		else:
			Game.add_item("wood", n)
			_toast("捡到了木材 x%d" % n)
			_float_text("+%d 木材" % n, p, Color(0.8, 0.65, 0.45))


# ---------- 钓鱼 ----------

func _fishing_action() -> void:
	match fish_state:
		0:
			if not decor.POND_RECT.grow(44.0).has_point(player.position):
				_toast("要靠近池塘才能甩竿")
				return
			if not Game.use_stamina(5.0):
				_toast("体力不够了，回床上睡一觉吧")
				return
			_cast()
		1:
			_end_fishing()
			_toast("收回了鱼线")
		2:
			fish_state = 3
			_bar_y = 0.5
			_bar_v = 0.0
			_progress = 30.0
			_fish_y = 0.5
			_fish_target = randf()
			_fish_timer = 0.0
			_bobber.visible = false
			_fish_root.visible = true
			_toast("按住空格抬起绿条，罩住游动的鱼！")
		3:
			pass


func _cast() -> void:
	var pr: Rect2 = decor.POND_RECT
	var aim: Vector2 = player.position + player.facing * 52.0
	_bobber_base = Vector2(
		clampf(aim.x, pr.position.x + 16.0, pr.end.x - 16.0),
		clampf(aim.y, pr.position.y + 16.0, pr.end.y - 16.0))
	_bobber.position = _bobber_base
	_bobber.modulate = Color(1, 1, 1)
	_bobber.visible = true
	fish_state = 1
	# 雨天鱼更活跃，咬钩更快
	_bite_t = randf_range(0.9, 2.2) if weather == "rain" else randf_range(1.6, 4.6)
	player.set_physics_process(false)
	_toast("甩竿……等鱼上钩（再按空格收回）")


func _update_fishing(delta: float) -> void:
	if fish_state == 1:
		_bite_t -= delta
		_bobber.position = _bobber_base + Vector2(0.0, sin(_wt * 3.2) * 1.5)
		if _bite_t <= 0.0:
			fish_state = 2
			_bite_window = 0.9
			_bobber.modulate = Color(1.0, 0.45, 0.4)
			Sfx.play("bite")
			_toast("咬钩了！快按空格提竿！")
	elif fish_state == 2:
		_bite_window -= delta
		_bobber.position = _bobber_base + Vector2(0.0, sin(_wt * 26.0) * 3.0)
		if _bite_window <= 0.0:
			_end_fishing()
			_toast("鱼跑掉了……")
	elif fish_state == 3:
		_fight_update(delta)


func _fight_update(delta: float) -> void:
	var hold := Input.is_action_pressed("use")
	_bar_v += (-880.0 if hold else 880.0) * delta
	_bar_v = clampf(_bar_v, -420.0, 420.0)
	_bar_y += _bar_v * delta
	if _bar_y < 0.09 or _bar_y > 0.91:
		_bar_y = clampf(_bar_y, 0.09, 0.91)
		_bar_v = 0.0
	_fish_timer -= delta
	if _fish_timer <= 0.0:
		_fish_timer = randf_range(0.4, 1.0)
		_fish_target = randf()
	_fish_y = lerpf(_fish_y, _fish_target, 1.0 - pow(0.02, delta))
	var overlap := absf(_fish_y - _bar_y) < 0.14
	_progress += (40.0 if overlap else -24.0) * delta
	_update_fish_ui(overlap)
	if _progress >= 100.0:
		_land_fish()
	elif _progress <= 0.0:
		_end_fishing()
		_toast("鱼挣脱了……")


func _update_fish_ui(overlap: bool) -> void:
	var bar_c := _bar_y * 240.0 - 120.0
	_fish_bar.offset_top = bar_c - 20.0
	_fish_bar.offset_bottom = bar_c + 20.0
	_fish_bar.color = Color(0.55, 0.92, 0.42, 0.6) if overlap else Color(0.35, 0.75, 0.32, 0.45)
	var fish_c := _fish_y * 240.0 - 120.0
	_fish_icon.offset_top = fish_c - 12.0
	_fish_icon.offset_bottom = fish_c + 12.0
	_prog_fill.offset_top = 118.0 - 236.0 * clampf(_progress, 0.0, 100.0) / 100.0
	_prog_fill.color = Color(0.95, 0.75, 0.3) if _progress > 70.0 else Color(0.9, 0.5, 0.25)


func _land_fish() -> void:
	_end_fishing()
	# 12% 概率钓上宝箱：金币或材料大礼
	if randf() < 0.12:
		Game.chest_opened += 1
		if randf() < 0.5:
			var g: int = [100, 150, 200, 300, 400][randi() % 5]
			Game.add_gold(g)
			_toast("钓上来一个宝箱！打开获得 %d 金币！" % g)
			_float_text("+%d 金币" % g, player.position + Vector2(0, -34), Color(1, 0.9, 0.35))
		else:
			var mat: String = ["wood", "stone", "berry"][randi() % 3]
			var n := 2 + randi() % 3
			Game.add_item(mat, n)
			_toast("钓上来一个宝箱！打开获得%s x%d" % [Game.MATERIALS[mat].name, n])
			_float_text("+%d %s" % [n, Game.MATERIALS[mat].name],
					player.position + Vector2(0, -34), Color(1, 0.9, 0.35))
		Game.add_xp("fish", 8)
		Sfx.play("coin")
		player.pop()
		return
	var pool: Array = []
	var total := 0
	for id in Game.FISH:
		var f: Dictionary = Game.FISH[id]
		if f.night and time_min < 1080.0:
			continue
		pool.append(id)
		total += int(f.w)
	var pick: String = pool[0]
	var r := randi() % total
	for id in pool:
		r -= int(Game.FISH[id].w)
		if r < 0:
			pick = id
			break
	var first: bool = Game.mark_fish(pick)
	Game.add_item(pick, 1)
	Game.add_xp("fish", 10)
	var msg := "钓到了%s！已放进背包，去商店卖掉吧" % Game.FISH[pick].name
	if first:
		msg += "　★ 图鉴新增！按 G 查看"
	_toast(msg)
	_float_text("+1 %s" % Game.FISH[pick].name, player.position + Vector2(0, -34), Color(0.55, 0.85, 1))
	Sfx.play("harvest")
	player.pop()


func _end_fishing() -> void:
	fish_state = 0
	_bobber.visible = false
	_bobber.modulate = Color(1, 1, 1)
	_fish_root.visible = false
	if not sleeping:
		player.set_physics_process(true)


# ---------- 存档与读档 ----------

## 组装进度：Game 全局 + 时间/工具 + 玩家位置 + 农田地块与放置物 + 订单/鸡/图鉴/成就
func _save_payload() -> Dictionary:
	var tiles: Array = []
	for c in farm.tiles:
		var t: Dictionary = farm.tiles[c]
		tiles.append([c.x, c.y, int(t.tilled), int(t.watered), t.crop, int(t.stage), int(t.wtoday)])
	var sprink: Array = []
	for c in farm.sprinklers:
		sprink.append([c.x, c.y])
	var scare: Array = []
	for c in farm.scare_cells:
		scare.append([c.x, c.y])
	var orders: Array = []
	for o in _orders:
		orders.append([o.kind, o.item, o.n, o.gold, o.who, int(o.done)])
	return {
		"day": Game.day, "gold": Game.gold,
		"seeds": Game.seeds, "harvest": Game.harvest, "items": Game.items,
		"stamina": Game.stamina, "max_stamina": Game.max_stamina,
		"hoe_level": Game.hoe_level, "can_level": Game.can_level,
		"friends": Game.friends, "weather": weather,
		"time_min": time_min, "tool": current_tool,
		"px": player.position.x, "py": player.position.y,
		"tiles": tiles, "sprinklers": sprink, "scarecrows": scare,
		"xp": Game.xp, "skill_lv": Game.skill_lv,
		"caught_fish": Game.caught_fish, "chest_opened": Game.chest_opened,
		"chicken_count": Game.chicken_count, "eggs_ready": Game.eggs_ready,
		"total_eggs": Game.total_eggs, "total_harvest": Game.total_harvest,
		"orders_done": Game.orders_done, "orders": orders,
		"achievements": Game.achievements.keys(),
	}


func _apply_payload(d: Dictionary) -> void:
	_loading = true
	Game.day = int(d.get("day", 1))
	Game.gold = int(d.get("gold", 500))
	var seeds: Dictionary = d.get("seeds", {})
	for k in Game.seeds:
		if seeds.has(k):
			Game.seeds[k] = int(seeds[k])
	var harvest_d: Dictionary = d.get("harvest", {})
	for k in Game.harvest:
		if harvest_d.has(k):
			Game.harvest[k] = int(harvest_d[k])
	var items_d: Dictionary = d.get("items", {})
	for k in Game.items:
		if items_d.has(k):
			Game.items[k] = int(items_d[k])
	Game.stamina = float(d.get("stamina", 100.0))
	Game.max_stamina = float(d.get("max_stamina", 100.0))
	Game.hoe_level = int(d.get("hoe_level", 1))
	Game.can_level = int(d.get("can_level", 1))
	var friends_d: Dictionary = d.get("friends", {})
	for k in Game.friends:
		if friends_d.has(k):
			Game.friends[k] = int(friends_d[k])
	var xp_d: Dictionary = d.get("xp", {})
	for k in Game.xp:
		if xp_d.has(k):
			Game.xp[k] = int(xp_d[k])
	var lv_d: Dictionary = d.get("skill_lv", {})
	for k in Game.skill_lv:
		if lv_d.has(k):
			Game.skill_lv[k] = int(lv_d[k])
	Game.caught_fish = {}
	var fish_d: Dictionary = d.get("caught_fish", {})
	for k in fish_d:
		if Game.FISH.has(k):
			Game.caught_fish[k] = int(fish_d[k])
	Game.chest_opened = int(d.get("chest_opened", 0))
	Game.chicken_count = clampi(int(d.get("chicken_count", 0)), 0, Game.MAX_CHICKENS)
	Game.eggs_ready = clampi(int(d.get("eggs_ready", 0)), 0, 10)
	Game.total_eggs = int(d.get("total_eggs", 0))
	Game.total_harvest = int(d.get("total_harvest", 0))
	Game.orders_done = int(d.get("orders_done", 0))
	Game.achievements = {}
	for id in d.get("achievements", []):
		if Game.ACHIEVEMENTS.has(id):
			Game.achievements[id] = true
	_orders.clear()
	for row in d.get("orders", []):
		_orders.append({
			"kind": String(row[0]), "item": String(row[1]), "n": int(row[2]),
			"gold": int(row[3]), "who": String(row[4]), "done": int(row[5]) == 1,
		})
	if _orders.is_empty():
		_gen_orders()
	weather = String(d.get("weather", "sun"))
	_rain_node.visible = weather == "rain"
	time_min = clampf(float(d.get("time_min", DAY_START_MIN)), DAY_START_MIN, DAY_END_MIN - 1.0)
	current_tool = clampi(int(d.get("tool", 0)), 0, 7)
	player.position = Vector2(
		float(d.get("px", decor.DOOR_POS.x)),
		float(d.get("py", decor.DOOR_POS.y + 44.0)))
	farm.restore_from(d)
	_sync_chickens()
	_refresh_eggs()
	Game.check_achievements(true)  # 旧档补录成就，静默不弹提示
	_loading = false
	Game.state_changed.emit()


## 睡觉醒来时自动存档；返回是否成功
func _autosave() -> bool:
	return Save.write(JSON.stringify(_save_payload()))


func _do_save() -> void:
	if _autosave():
		Sfx.play("pick")
		_toast("已存档（第 %d 天 %s）" % [Game.day, _clock_text()])
	else:
		_toast("存档失败了……")


## 读档；返回是否成功。开局静默调用（with_toast=false）
func _do_load(with_toast := true) -> bool:
	var text := Save.read()
	if text == "":
		if with_toast:
			_toast("还没有存档，睡觉或按 F5 就会存档")
		return false
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		if with_toast:
			_toast("存档数据损坏了")
		return false
	_apply_payload(parsed)
	# 清理残留的界面与钓鱼状态
	if shop_open:
		_toggle_shop(false)
	if craft_open:
		_toggle_craft(false)
	if help_open:
		_toggle_help(false)
	if fish_state > 0:
		_end_fishing()
	place_mode = ""
	farm.set_preview("", Vector2i.ZERO, false)
	if with_toast:
		Sfx.play("pick")
		_toast("已读取第 %d 天存档" % Game.day)
	return true


# ---------- 昼夜与睡觉 ----------

func _do_sleep(passed_out: bool) -> void:
	if sleeping:
		return
	sleeping = true
	if shop_open:
		_toggle_shop(false)
	if craft_open:
		_toggle_craft(false)
	if help_open:
		_toggle_help(false)
	if orders_open:
		_toggle_orders(false)
	if dex_open:
		_toggle_dex(false)
	if fish_state > 0:
		_end_fishing()
	place_mode = ""
	farm.set_preview("", Vector2i.ZERO, false)
	player.set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.7)
	await tw.finished
	Game.day += 1
	time_min = float(DAY_START_MIN)
	weather = "rain" if randf() < 0.3 else "sun"
	_rain_node.visible = weather == "rain"
	var lost: int = farm.on_new_day(weather == "rain")
	gather.spawn_daily()
	# 鸡过夜下蛋；订单板刷新 3 张新订单
	if Game.chicken_count > 0:
		Game.eggs_ready = mini(Game.eggs_ready + Game.chicken_count, 10)
		_refresh_eggs()
	_gen_orders()
	Game.stamina = Game.max_stamina
	Game.state_changed.emit()
	_talked_today.clear()
	player.position = decor.DOOR_POS + Vector2(0, 46)
	var save_ok := _autosave()
	var tail := " · 已自动存档" if save_ok else ""
	var rtail := " · 今天下雨，农田已浇好" if weather == "rain" else ""
	if Game.eggs_ready > 0:
		rtail += " · 鸡下了 %d 颗蛋" % Game.eggs_ready
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.7)
	await tw2.finished
	player.set_physics_process(true)
	sleeping = false
	if lost > 0:
		_toast("乌鸦夜里偷吃了 %d 株作物！快做个稻草人（C）%s%s" % [lost, rtail, tail])
	elif passed_out:
		_toast("你累倒了……醒来已是第 %d 天%s%s" % [Game.day, rtail, tail])
	else:
		_toast("睡了个好觉！第 %d 天，体力已回满%s%s" % [Game.day, rtail, tail])


func _sky_color(t: float) -> Color:
	var stops := [
		[360.0, Color(1, 1, 1)],
		[960.0, Color(1, 1, 1)],
		[1140.0, Color(1.0, 0.85, 0.68)],
		[1275.0, Color(0.52, 0.47, 0.64)],
		[1440.0, Color(0.3, 0.33, 0.52)],
	]
	if t <= stops[0][0]:
		return stops[0][1]
	for i in range(1, stops.size()):
		if t <= stops[i][0]:
			var a: Array = stops[i - 1]
			var b: Array = stops[i]
			var k: float = (t - a[0]) / (b[0] - a[0])
			return (a[1] as Color).lerp(b[1], k)
	return stops[-1][1]


func _clock_text() -> String:
	if time_min >= DAY_END_MIN:
		return "24:00"
	return "%02d:%02d" % [int(time_min / 60.0), int(fmod(time_min, 60.0))]


# ---------- 商店 ----------

func _build_shop() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	shop_panel.add_child(vb)
	vb.add_child(_mk_label("皮埃尔的种子商店", 19))
	_shop_gold_label = _mk_label("", 14)
	vb.add_child(_shop_gold_label)
	for id in Game.CROPS:
		_add_crop_row(vb, id)
	for cat in [Game.FISH, Game.MATERIALS]:
		for id in cat:
			_add_item_row(vb, cat, id)
	var up_row := HBoxContainer.new()
	up_row.add_theme_constant_override("separation", 8)
	vb.add_child(up_row)
	var up_l := _mk_label("工具升级（3x3 范围）", 14)
	up_l.custom_minimum_size = Vector2(250, 0)
	up_row.add_child(up_l)
	_hoe_btn = _mk_btn("")
	_hoe_btn.pressed.connect(_upgrade.bind("hoe"))
	up_row.add_child(_hoe_btn)
	_can_btn = _mk_btn("")
	_can_btn.pressed.connect(_upgrade.bind("can"))
	up_row.add_child(_can_btn)
	# 家禽养殖：买小鸡
	var ck_row := HBoxContainer.new()
	ck_row.add_theme_constant_override("separation", 8)
	vb.add_child(ck_row)
	var ck_l := _mk_label("小鸡（住在屋旁鸡舍，每天下一颗蛋）", 14)
	ck_l.custom_minimum_size = Vector2(250, 0)
	ck_row.add_child(ck_l)
	_chicken_btn = _mk_btn("")
	_chicken_btn.pressed.connect(_buy_chicken)
	ck_row.add_child(_chicken_btn)
	vb.add_child(_mk_label("按 E / Esc 关闭", 12))


func _add_crop_row(vb: VBoxContainer, id: String) -> void:
	var c: Dictionary = Game.CROPS[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var name_l := _mk_label("%s（种子%dg / 售%dg）" % [c.name, c.seed_cost, c.sell], 14)
	name_l.custom_minimum_size = Vector2(250, 0)
	row.add_child(name_l)
	var count_l := _mk_label("", 14)
	count_l.custom_minimum_size = Vector2(150, 0)
	row.add_child(count_l)
	_shop_rows[id] = count_l
	_shop_kinds[id] = "crop"
	var buy := _mk_btn("买1种")
	buy.pressed.connect(_buy.bind(id))
	row.add_child(buy)
	var s1 := _mk_btn("卖1")
	s1.pressed.connect(_sell.bind(id, false))
	row.add_child(s1)
	var sa := _mk_btn("全卖")
	sa.pressed.connect(_sell.bind(id, true))
	row.add_child(sa)


func _add_item_row(vb: VBoxContainer, cat: Dictionary, id: String) -> void:
	var info: Dictionary = cat[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var name_l := _mk_label("%s（售%dg）" % [info.name, info.sell], 14)
	name_l.custom_minimum_size = Vector2(250, 0)
	row.add_child(name_l)
	var count_l := _mk_label("", 14)
	count_l.custom_minimum_size = Vector2(150, 0)
	row.add_child(count_l)
	_shop_rows[id] = count_l
	_shop_kinds[id] = "item"
	var s1 := _mk_btn("卖1")
	s1.pressed.connect(_sell_item.bind(cat, id, false))
	row.add_child(s1)
	var sa := _mk_btn("全卖")
	sa.pressed.connect(_sell_item.bind(cat, id, true))
	row.add_child(sa)


func _buy(id: String) -> void:
	var cost: int = Game.CROPS[id].seed_cost
	if Game.gold < cost:
		_toast("金币不足！")
		return
	Game.add_gold(-cost)
	Game.add_seed(id, 1)
	Sfx.play("coin")
	_toast("买了 1 包%s种子" % Game.CROPS[id].name)


func _sell(id: String, all: bool) -> void:
	var have: int = Game.harvest[id]
	if have <= 0:
		_toast("没有可出售的%s" % Game.CROPS[id].name)
		return
	var n := have if all else 1
	Game.add_gold(n * int(Game.CROPS[id].sell))
	Game.remove_harvest(id, n)
	Sfx.play("coin")
	_toast("卖出%s x%d，赚了 %d 金币" % [Game.CROPS[id].name, n, n * int(Game.CROPS[id].sell)])


func _sell_item(cat: Dictionary, id: String, all: bool) -> void:
	var have: int = Game.items.get(id, 0)
	if have <= 0:
		_toast("背包里没有%s" % cat[id].name)
		return
	var n := have if all else 1
	Game.add_item(id, -n)
	Game.add_gold(n * int(cat[id].sell))
	Sfx.play("coin")
	_toast("卖出%s x%d，赚了 %d 金币" % [cat[id].name, n, n * int(cat[id].sell)])


func _upgrade(which: String) -> void:
	if which == "hoe":
		if Game.hoe_level >= 2:
			return
		if Game.gold < Game.HOE_UP_COST:
			_toast("金币不足！")
			return
		Game.add_gold(-Game.HOE_UP_COST)
		Game.hoe_level = 2
		Sfx.play("coin")
		_toast("锄头升级为铜锄！开垦范围 3x3")
	else:
		if Game.can_level >= 2:
			return
		if Game.gold < Game.CAN_UP_COST:
			_toast("金币不足！")
			return
		Game.add_gold(-Game.CAN_UP_COST)
		Game.can_level = 2
		Sfx.play("coin")
		_toast("水壶升级为铜壶！浇水范围 3x3")


func _toggle_shop(open: bool) -> void:
	shop_open = open
	shop_panel.visible = open
	if open:
		_refresh_hud()


# ---------- 制作与放置 ----------

func _build_craft() -> void:
	craft_panel = PanelContainer.new()
	craft_panel.anchor_left = 0.5
	craft_panel.anchor_top = 0.5
	craft_panel.anchor_right = 0.5
	craft_panel.anchor_bottom = 0.5
	craft_panel.offset_left = -250.0
	craft_panel.offset_top = -185.0
	craft_panel.offset_right = 250.0
	craft_panel.offset_bottom = 185.0
	craft_panel.visible = false
	$UI.add_child(craft_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	craft_panel.add_child(vb)
	vb.add_child(_mk_label("制作", 20))
	_craft_gold = _mk_label("", 13)
	vb.add_child(_craft_gold)
	for id in Game.RECIPES:
		var r: Dictionary = Game.RECIPES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var parts := []
		for k in r.cost:
			parts.append("%s x%d" % [Game.MATERIALS[k].name, r.cost[k]])
		var name_l := _mk_label("%s（%s）" % [r.name, " + ".join(parts)], 15)
		name_l.custom_minimum_size = Vector2(260, 0)
		row.add_child(name_l)
		var have_l := _mk_label("", 14)
		have_l.custom_minimum_size = Vector2(130, 0)
		row.add_child(have_l)
		_craft_rows[id] = have_l
		var b := _mk_btn("制作并放置")
		b.pressed.connect(_craft_start.bind(id))
		row.add_child(b)
	vb.add_child(_mk_label("稻草人：守护周围作物，夜里乌鸦不敢来", 13))
	vb.add_child(_mk_label("洒水器：每天清晨自动浇灌上下左右四格", 13))
	vb.add_child(_mk_label("速效肥：对已种作物的格子按空格施肥，立刻长一节", 13))
	vb.add_child(_mk_label("按 C / Esc 关闭", 12))


func _craft_start(id: String) -> void:
	if not Game.can_afford(Game.RECIPES[id].cost):
		_toast("材料不够！先去敲石头和树枝吧")
		return
	place_mode = id
	_toggle_craft(false)
	_toast("移动到目标格子，按空格放置%s" % Game.RECIPES[id].name)


func _toggle_craft(open: bool) -> void:
	craft_open = open
	craft_panel.visible = open
	if open:
		_refresh_hud()


func _place_at_target() -> void:
	var cell_v = farm.cell_at(player.position + player.facing * 26.0)
	if cell_v == null:
		cell_v = farm.cell_at(player.position)
	if cell_v == null:
		_toast("要在农场范围内放置")
		return
	var cell: Vector2i = cell_v
	var msg: String
	if place_mode == "scarecrow":
		msg = farm.place_scarecrow(cell)
	elif place_mode == "sprinkler":
		msg = farm.place_sprinkler(cell)
	else:
		msg = farm.try_fertilize(cell)
	if msg != "":
		_toast(msg)
		return
	Game.consume(Game.RECIPES[place_mode].cost)
	Sfx.play("plant")
	if place_mode == "fertilizer":
		var cn: String = farm.tiles[cell].crop
		_float_text("+1 节 %s" % Game.CROPS[cn].name, _cell_center(cell), Color(0.6, 1, 0.5))
		_toast("施了速效肥，%s马上长大了一截！" % Game.CROPS[cn].name)
	else:
		_toast("%s放置成功！" % Game.RECIPES[place_mode].name)
	place_mode = ""
	farm.set_preview("", Vector2i.ZERO, false)
	player.pop()


func _cancel_place() -> void:
	place_mode = ""
	farm.set_preview("", Vector2i.ZERO, false)
	_toast("取消了放置")


# ---------- 村民对话 ----------

func _build_dialog() -> void:
	_dialog_panel = PanelContainer.new()
	_dialog_panel.anchor_left = 0.5
	_dialog_panel.anchor_top = 1.0
	_dialog_panel.anchor_right = 0.5
	_dialog_panel.anchor_bottom = 1.0
	_dialog_panel.offset_left = -430.0
	_dialog_panel.offset_top = -158.0
	_dialog_panel.offset_right = 430.0
	_dialog_panel.offset_bottom = -96.0
	_dialog_panel.visible = false
	$UI.add_child(_dialog_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_dialog_panel.add_child(vb)
	_dialog_name = _mk_label("", 16)
	_dialog_name.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vb.add_child(_dialog_name)
	_dialog_text = _mk_label("", 14)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_dialog_text)
	vb.add_child(_mk_label("按 E / Esc 关闭", 12))


func _toggle_dialog(open: bool) -> void:
	dialog_open = open
	_dialog_panel.visible = open
	if not open:
		_dialog_villager = null


func _near_villager() -> Node2D:
	for v in _villagers:
		if player.position.distance_to(v.position) < 58.0:
			return v
	return null


func _talk_to(v: Node2D) -> void:
	var id := ""
	for cfg in VILLAGERS:
		if cfg.name == v.display_name:
			id = cfg.id
			break
	var first: bool = not _talked_today.get(id, false)
	_talked_today[id] = true
	var lv := int(Game.friends.get(id, 0))
	var tier := "low" if lv < 30 else ("mid" if lv < 70 else "high")
	var pool: Array = DIALOGS[id][tier]
	var line: String = pool[randi() % pool.size()]
	if first:
		Game.friends[id] = lv + 10
		Game.state_changed.emit()
		line += "　（好感 +10）"
	_dialog_villager = v
	_dialog_name.text = "%s · 好感 %d" % [v.display_name, Game.friends[id]]
	_dialog_text.text = line
	_toggle_dialog(true)
	Sfx.play("talk")


# ---------- 订单任务板 ----------

func _build_orders() -> void:
	_orders_panel = PanelContainer.new()
	_orders_panel.anchor_left = 0.5
	_orders_panel.anchor_top = 0.5
	_orders_panel.anchor_right = 0.5
	_orders_panel.anchor_bottom = 0.5
	_orders_panel.offset_left = -280.0
	_orders_panel.offset_top = -215.0
	_orders_panel.offset_right = 280.0
	_orders_panel.offset_bottom = 215.0
	_orders_panel.visible = false
	$UI.add_child(_orders_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_orders_panel.add_child(vb)
	vb.add_child(_mk_label("订单任务板", 20))
	_orders_gold = _mk_label("", 13)
	vb.add_child(_orders_gold)
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var desc := _mk_label("", 14)
		desc.custom_minimum_size = Vector2(400, 0)
		row.add_child(desc)
		_order_descs.append(desc)
		var btn := _mk_btn("交付")
		btn.pressed.connect(_deliver_order.bind(i))
		row.add_child(btn)
		_order_btns.append(btn)
	vb.add_child(_mk_label("每天在任务板刷新 3 张订单，交付得金币与村民好感", 13))
	vb.add_child(_mk_label("作物订单交仓里的作物，鱼/材料订单交背包物品", 13))
	vb.add_child(_mk_label("按 E / Esc 关闭", 12))


func _toggle_orders(open: bool) -> void:
	orders_open = open
	_orders_panel.visible = open
	if open:
		_refresh_orders()


func _refresh_orders() -> void:
	_orders_gold.text = "金币：%d　　今日订单" % Game.gold
	for i in 3:
		var o: Dictionary = _orders[i]
		var item_name: String = ""
		if o.kind == "crop":
			item_name = Game.CROPS[o.item].name
		elif o.kind == "fish":
			item_name = Game.FISH[o.item].name
		else:
			item_name = Game.MATERIALS[o.item].name
		var desc := "%s想要：%s x%d　　报酬 %dg + 好感12" % [
			VILLAGER_NAMES[o.who], item_name, o.n, o.gold]
		if o.done:
			desc = "%s想要：%s x%d　　[已交付]" % [VILLAGER_NAMES[o.who], item_name, o.n]
		_order_descs[i].text = desc
		_order_descs[i].add_theme_color_override(
			"font_color", Color(0.62, 0.58, 0.5) if o.done else Color(1, 0.98, 0.92))
		_order_btns[i].disabled = o.done


## 每天随机 3 张订单（种类分布尽量打散，单类最多 2 张）
func _gen_orders() -> void:
	_orders.clear()
	var picks: Array = []
	for id in Game.CROPS:
		picks.append(["crop", id])
	for id in Game.FISH:
		picks.append(["fish", id])
	for id in ["wood", "stone", "berry"]:
		picks.append(["mat", id])
	picks.shuffle()
	var cat_count := {"crop": 0, "fish": 0, "mat": 0}
	for p in picks:
		if _orders.size() >= 3:
			break
		if cat_count[p[0]] >= 2:
			continue
		cat_count[p[0]] += 1
		_orders.append(_make_order(p[0], p[1]))
	if orders_open:
		_refresh_orders()


func _make_order(kind: String, id: String) -> Dictionary:
	var base: int
	var n: int
	if kind == "crop":
		base = Game.CROPS[id].sell
		n = clampi(int(200.0 / base) + (randi() % 2), 1, 4)
	elif kind == "fish":
		base = Game.FISH[id].sell
		n = 1 if base >= 100 else 1 + randi() % 2
	else:
		base = Game.MATERIALS[id].sell
		n = 2 + randi() % 4
	var gold := int(ceil(base * n * 1.55 / 5.0)) * 5
	return {
		"kind": kind, "item": id, "n": n, "gold": gold,
		"who": "rosa" if randf() < 0.5 else "ben", "done": false,
	}


func _deliver_order(i: int) -> void:
	var o: Dictionary = _orders[i]
	if o.done:
		return
	var item_name: String = ""
	if o.kind == "crop":
		item_name = Game.CROPS[o.item].name
	elif o.kind == "fish":
		item_name = Game.FISH[o.item].name
	else:
		item_name = Game.MATERIALS[o.item].name
	var have: int = Game.harvest[o.item] if o.kind == "crop" else Game.items.get(o.item, 0)
	if have < int(o.n):
		_toast("背包里没有足够的%s（还差 %d 个）" % [item_name, int(o.n) - have])
		return
	if o.kind == "crop":
		Game.remove_harvest(o.item, int(o.n))
	else:
		Game.add_item(o.item, -int(o.n))
	Game.add_gold(int(o.gold))
	Game.friends[o.who] = int(Game.friends.get(o.who, 0)) + 12
	Game.orders_done += 1
	Game.add_xp("farm" if o.kind == "crop" else ("fish" if o.kind == "fish" else "gather"), 10)
	o.done = true
	Sfx.play("coin")
	_toast("完成订单！获得 %d 金币，%s 好感 +12" % [o.gold, VILLAGER_NAMES[o.who]])
	_refresh_orders()


# ---------- 家禽养殖 ----------

func _build_eggs() -> void:
	for p in decor.EGG_SPOTS:
		var s := Sprite2D.new()
		s.texture = TEX_EGG
		s.position = p
		s.z_index = 1
		s.visible = false
		add_child(s)
		_egg_sprites.append(s)
	_refresh_eggs()


func _refresh_eggs() -> void:
	for i in _egg_sprites.size():
		_egg_sprites[i].visible = i < Game.eggs_ready


func _sync_chickens() -> void:
	while _chickens.size() > Game.chicken_count:
		var c: Node2D = _chickens.pop_back()
		c.queue_free()
	while _chickens.size() < Game.chicken_count:
		var c2: Node2D = ChickenScript.new()
		c2.setup(decor.COOP_ROAM, decor.COOP_ROAM.get_center()
				+ Vector2(randf_range(-40, 40), randf_range(-20, 20)))
		add_child(c2)
		_chickens.append(c2)


func _buy_chicken() -> void:
	if Game.chicken_count >= Game.MAX_CHICKENS:
		_toast("鸡舍住满啦（最多 %d 只）" % Game.MAX_CHICKENS)
		return
	if Game.gold < Game.CHICKEN_COST:
		_toast("金币不足！")
		return
	Game.add_gold(-Game.CHICKEN_COST)
	Game.chicken_count += 1
	_sync_chickens()
	Sfx.play("coin")
	_toast("买了一只小鸡！它会住在屋旁鸡舍，每天下一颗蛋")
	_refresh_hud()


func _collect_eggs() -> void:
	if Game.eggs_ready <= 0:
		if Game.chicken_count > 0:
			_toast("鸡还没下蛋，明天再来捡吧")
		else:
			_toast("鸡舍里没有鸡，先去商店买一只小鸡吧（800g）")
		return
	var n := Game.eggs_ready
	Game.add_item("egg", n)
	Game.total_eggs += n
	Game.add_xp("gather", 4 * n)
	Game.eggs_ready = 0
	_refresh_eggs()
	player.pop()
	Sfx.play("pick")
	_float_text("+%d 鸡蛋" % n, decor.COOP_POS + Vector2(0, -40), Color(1, 0.96, 0.8))
	_toast("捡到了 %d 颗鸡蛋！拿去商店卖钱吧" % n)


# ---------- 图鉴 · 技能 · 成就 ----------

func _build_dex() -> void:
	_dex_panel = PanelContainer.new()
	_dex_panel.anchor_left = 0.5
	_dex_panel.anchor_top = 0.5
	_dex_panel.anchor_right = 0.5
	_dex_panel.anchor_bottom = 0.5
	_dex_panel.offset_left = -290.0
	_dex_panel.offset_top = -268.0
	_dex_panel.offset_right = 290.0
	_dex_panel.offset_bottom = 268.0
	_dex_panel.visible = false
	$UI.add_child(_dex_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_dex_panel.add_child(vb)
	var title := _mk_label("图鉴 · 技能 · 成就", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	# 技能
	var st := _mk_label("—— 技能 ——", 14)
	st.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(st)
	for kind in ["farm", "fish", "gather"]:
		var l := _mk_label("", 13)
		vb.add_child(l)
		_dex_skill_labels[kind] = l
	vb.add_child(_mk_label("收获/钓鱼/采集/交付订单得经验，每 100 点升 1 级，体力上限 +10", 12))
	# 鱼类图鉴
	var ft := _mk_label("—— 鱼类图鉴 ——", 14)
	ft.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ft)
	for id in Game.FISH:
		var fl := _mk_label("", 13)
		vb.add_child(fl)
		_dex_fish_labels[id] = fl
	_dex_chest = _mk_label("", 13)
	vb.add_child(_dex_chest)
	# 成就
	var at := _mk_label("—— 成就 ——", 14)
	at.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(at)
	for id in Game.ACHIEVEMENTS:
		var al := _mk_label("", 13)
		vb.add_child(al)
		_dex_ach_labels[id] = al
	var close_l := _mk_label("按 G / E / Esc 关闭", 12)
	close_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(close_l)


func _toggle_dex(open: bool) -> void:
	dex_open = open
	_dex_panel.visible = open
	if open:
		_refresh_dex()


func _refresh_dex() -> void:
	for kind in _dex_skill_labels:
		var lv: int = Game.skill_lv[kind]
		var xp_txt: String = "MAX" if lv >= Game.MAX_SKILL_LV \
				else "%d/%d" % [Game.xp[kind], Game.XP_PER_LEVEL]
		_dex_skill_labels[kind].text = "%s　Lv.%d　经验 %s" % [Game.SKILL_NAMES[kind], lv, xp_txt]
	for id in _dex_fish_labels:
		var f: Dictionary = Game.FISH[id]
		if Game.caught_fish.has(id):
			_dex_fish_labels[id].text = "%s　已钓 %d 条　售价 %dg%s" % [
				f.name, Game.caught_fish[id], f.sell,
				"　只在 18:00 后咬钩" if f.night else ""]
			_dex_fish_labels[id].add_theme_color_override("font_color", Color(1, 0.98, 0.92))
		else:
			_dex_fish_labels[id].text = "？？？　尚未钓到%s" % (
				"（夜钓限定）" if f.night else "")
			_dex_fish_labels[id].add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	_dex_chest.text = "宝箱：钓上并打开过 %d 次（钓鱼 12%% 概率）" % Game.chest_opened
	for id in _dex_ach_labels:
		var a: Dictionary = Game.ACHIEVEMENTS[id]
		var done: bool = Game.achievements.has(id)
		_dex_ach_labels[id].text = "%s %s · %s" % [
			"[已达成]" if done else "[未达成]", a.name, a.desc]
		_dex_ach_labels[id].add_theme_color_override(
			"font_color", Color(1, 0.85, 0.35) if done else Color(0.6, 0.58, 0.52))


# ---------- 技能升级与成就提示 ----------

func _ach_tick() -> void:
	if not _loading:
		Game.check_achievements()


func _on_skill_up(kind: String, lv: int) -> void:
	_toast("「%s」升到 %d 级！体力上限 +10（G 查看技能）" % [Game.SKILL_NAMES[kind], lv])
	Sfx.play("harvest")


func _on_achievement(id: String) -> void:
	var a: Dictionary = Game.ACHIEVEMENTS[id]
	_toast("成就达成「%s」：%s" % [a.name, a.desc])
	Sfx.play("coin")


# ---------- 玩法说明 ----------

func _build_help() -> void:
	help_panel = PanelContainer.new()
	help_panel.anchor_left = 0.5
	help_panel.anchor_top = 0.5
	help_panel.anchor_right = 0.5
	help_panel.anchor_bottom = 0.5
	help_panel.offset_left = -335.0
	help_panel.offset_top = -318.0
	help_panel.offset_right = 335.0
	help_panel.offset_bottom = 318.0
	help_panel.visible = false
	$UI.add_child(help_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	help_panel.add_child(vb)
	var title := _mk_label("《星露谷Like》玩法说明", 21)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_help_section(vb, "基础操作", [
		"WASD / 方向键 移动　　空格 / 鼠标左键 使用工具　　E 互动",
		"1-8 切换工具　　C 制作　　H 帮助　　Esc 关闭　　F5 存档 / F9 读档　　M 音乐",
	])
	_help_section(vb, "种田流程", [
		"1 锄头开垦 → 3~6 播种 → 2 浇水 → 每天浇水才生长 → 成熟后空格收获",
		"对着货摊按 E 开商店：买种子、卖作物和鱼、升级铜锄铜壶（3x3 范围）",
	])
	_help_section(vb, "钓鱼（7 鱼竿）", [
		"池塘边空格甩竿 → 浮漂变红瞬间再按空格提竿",
		"按住空格抬起绿条罩住游动的鱼，进度条满即钓获；虹鳟只在 18:00 后咬钩",
		"钓鱼有 12% 概率钓上宝箱：开箱得金币或材料大礼",
	])
	_help_section(vb, "订单与养殖（新增）", [
		"货摊旁的任务板按 E 接订单：每天 3 张，交作物/鱼/材料得金币与村民好感",
		"商店可买小鸡 800g（最多 4 只），鸡在屋旁鸡舍散步，每天下一颗蛋",
		"鸡蛋堆在鸡舍前按 E 捡起，商店可卖 60g 一颗",
	])
	_help_section(vb, "技能与成就（G 图鉴）", [
		"收获/钓鱼/采集/交付订单都能攒经验，每 100 点升 1 级，体力上限 +10",
		"按 G 打开图鉴面板：技能等级、鱼类图鉴、宝箱次数与成就进度一目了然",
	])
	_help_section(vb, "采集与制作（8 斧镐 / C 制作）", [
		"敲石头得石料、敲树枝得木材，每天地图会补充刷新",
		"北边树林的野莓丛按 E 直接采摘野莓，第二天会重新结果",
		"稻草人防乌鸦；洒水器清晨浇灌四邻格；速效肥让作物立刻长一节",
		"制作后移动到目标格子按空格放置，Esc 取消",
	])
	_help_section(vb, "天气与村民", [
		"雨天雨水自动浇灌农田、鱼更容易上钩；晴天记得自己浇水",
		"罗莎在花田、老本在集市散步，靠近按 E 聊天，每天首次聊天涨好感",
	])
	_help_section(vb, "体力与昼夜", [
		"动作消耗体力（左下角），不足则无法干活；家门口按 E 睡觉回满并进入次日，自动存档",
		"6:00 开始新一天，熬到 24:00 会累倒，作物生长都靠每天浇水",
	])
	var close_l := _mk_label("按 H / E / Esc 关闭", 13)
	close_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(close_l)


func _help_section(vb: VBoxContainer, title: String, lines: Array) -> void:
	var t := _mk_label("—— %s ——" % title, 15)
	t.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	for line in lines:
		vb.add_child(_mk_label(line, 13))


func _toggle_help(open: bool) -> void:
	help_open = open
	help_panel.visible = open


# ---------- HUD ----------

func _build_stamina() -> void:
	_stam_label = _mk_label("体力 100/100", 13)
	_stam_label.anchor_top = 1.0
	_stam_label.anchor_bottom = 1.0
	_stam_label.offset_left = 20.0
	_stam_label.offset_top = -70.0
	_stam_label.offset_right = 240.0
	_stam_label.offset_bottom = -50.0
	$UI.add_child(_stam_label)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.06, 0.78)
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 20.0
	bg.offset_top = -46.0
	bg.offset_right = 240.0
	bg.offset_bottom = -32.0
	$UI.add_child(bg)
	_stam_fill = ColorRect.new()
	_stam_fill.color = Color(0.45, 0.78, 0.34)
	_stam_fill.anchor_top = 1.0
	_stam_fill.anchor_bottom = 1.0
	_stam_fill.offset_left = 22.0
	_stam_fill.offset_top = -44.0
	_stam_fill.offset_right = 238.0
	_stam_fill.offset_bottom = -34.0
	$UI.add_child(_stam_fill)


func _build_fishing_ui() -> void:
	_fish_root = Control.new()
	_fish_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fish_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fish_root.visible = false
	$UI.add_child(_fish_root)
	var track := ColorRect.new()
	track.color = Color(0.12, 0.1, 0.09, 0.72)
	track.anchor_left = 0.5
	track.anchor_top = 0.5
	track.anchor_right = 0.5
	track.anchor_bottom = 0.5
	track.offset_left = -84.0
	track.offset_top = -120.0
	track.offset_right = -56.0
	track.offset_bottom = 120.0
	_fish_root.add_child(track)
	_fish_bar = ColorRect.new()
	_fish_bar.color = Color(0.35, 0.75, 0.32, 0.45)
	_fish_bar.anchor_left = 0.5
	_fish_bar.anchor_top = 0.5
	_fish_bar.anchor_right = 0.5
	_fish_bar.anchor_bottom = 0.5
	_fish_bar.offset_left = -81.0
	_fish_bar.offset_top = -20.0
	_fish_bar.offset_right = -59.0
	_fish_bar.offset_bottom = 20.0
	_fish_root.add_child(_fish_bar)
	_fish_icon = TextureRect.new()
	_fish_icon.texture = TEX_FISH
	_fish_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fish_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_fish_icon.anchor_left = 0.5
	_fish_icon.anchor_top = 0.5
	_fish_icon.anchor_right = 0.5
	_fish_icon.anchor_bottom = 0.5
	_fish_icon.offset_left = -82.0
	_fish_icon.offset_top = -12.0
	_fish_icon.offset_right = -58.0
	_fish_icon.offset_bottom = 12.0
	_fish_root.add_child(_fish_icon)
	var ptrack := ColorRect.new()
	ptrack.color = Color(0.12, 0.1, 0.09, 0.72)
	ptrack.anchor_left = 0.5
	ptrack.anchor_top = 0.5
	ptrack.anchor_right = 0.5
	ptrack.anchor_bottom = 0.5
	ptrack.offset_left = -38.0
	ptrack.offset_top = -120.0
	ptrack.offset_right = -30.0
	ptrack.offset_bottom = 120.0
	_fish_root.add_child(ptrack)
	_prog_fill = ColorRect.new()
	_prog_fill.color = Color(0.9, 0.5, 0.25)
	_prog_fill.anchor_left = 0.5
	_prog_fill.anchor_top = 0.5
	_prog_fill.anchor_right = 0.5
	_prog_fill.anchor_bottom = 0.5
	_prog_fill.offset_left = -37.0
	_prog_fill.offset_top = 118.0
	_prog_fill.offset_right = -31.0
	_prog_fill.offset_bottom = 118.0
	_fish_root.add_child(_prog_fill)
	var tip := _mk_label("按住 空格 抬起绿条，罩住游动的鱼", 14)
	tip.anchor_left = 0.5
	tip.anchor_top = 0.5
	tip.anchor_right = 0.5
	tip.anchor_bottom = 0.5
	tip.offset_left = -240.0
	tip.offset_top = 130.0
	tip.offset_right = 240.0
	tip.offset_bottom = 154.0
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fish_root.add_child(tip)


func _refresh_hud() -> void:
	gold_label.text = "金币 %d" % Game.gold
	var texts := [
		"1 %s" % ("铜锄头" if Game.hoe_level >= 2 else "锄头"),
		"2 %s" % ("铜水壶" if Game.can_level >= 2 else "水壶"),
		"3 防风草种 x%d" % Game.seeds.parsnip,
		"4 土豆种 x%d" % Game.seeds.potato,
		"5 草莓种 x%d" % Game.seeds.straw,
		"6 南瓜种 x%d" % Game.seeds.pumpkin,
		"7 鱼竿",
		"8 斧镐",
	]
	for i in 8:
		_slot_labels[i].text = ("▶ " + texts[i]) if i == current_tool else texts[i]
		_slot_panels[i].self_modulate = Color(1, 1, 0.62) if i == current_tool else Color(1, 1, 1, 0.82)
	# 体力条
	var ratio := Game.stamina / Game.max_stamina
	_stam_fill.offset_right = 22.0 + 216.0 * ratio
	if ratio > 0.5:
		_stam_fill.color = Color(0.45, 0.78, 0.34)
	elif ratio > 0.25:
		_stam_fill.color = Color(0.9, 0.72, 0.25)
	else:
		_stam_fill.color = Color(0.85, 0.3, 0.25)
	_stam_label.text = "体力 %d / %d" % [int(Game.stamina), int(Game.max_stamina)]
	# 商店行
	if _shop_gold_label:
		_shop_gold_label.text = "金币：%d" % Game.gold
	for id in _shop_rows:
		if _shop_kinds[id] == "crop":
			_shop_rows[id].text = "种子 x%d   作物 x%d" % [Game.seeds[id], Game.harvest[id]]
		else:
			_shop_rows[id].text = "背包 x%d" % Game.items.get(id, 0)
	if _hoe_btn:
		_hoe_btn.text = "铜锄 500g" if Game.hoe_level < 2 else "已升级"
		_hoe_btn.disabled = Game.hoe_level >= 2
		_can_btn.text = "铜壶 500g" if Game.can_level < 2 else "已升级"
		_can_btn.disabled = Game.can_level >= 2
	# 买鸡按钮
	if _chicken_btn:
		_chicken_btn.text = "买小鸡 %dg" % Game.CHICKEN_COST \
				if Game.chicken_count < Game.MAX_CHICKENS else "已住满"
		_chicken_btn.disabled = Game.chicken_count >= Game.MAX_CHICKENS
	# 制作面板行
	if _craft_gold:
		_craft_gold.text = "金币：%d　　材料靠斧镐(6)敲石头和树枝获得" % Game.gold
	for id in _craft_rows:
		var parts := []
		var cost: Dictionary = Game.RECIPES[id].cost
		for k in cost:
			parts.append("%s %d/%d" % [Game.MATERIALS[k].name, Game.items.get(k, 0), cost[k]])
		_craft_rows[id].text = "  ".join(parts)


func _update_hint() -> void:
	var txt: String
	if place_mode != "":
		txt = "移动到目标格子按空格放置（Esc 取消）"
	elif _near_villager() != null:
		txt = "按 E 和 %s 聊聊天吧" % _near_villager().display_name
	elif player.position.distance_to(decor.BOARD_POS) < 70.0:
		txt = "按 E 查看订单任务板：完成订单得金币和好感"
	elif player.position.distance_to(decor.COOP_POS) < 80.0:
		if Game.eggs_ready > 0:
			txt = "鸡舍前有 %d 颗鸡蛋：按 E 捡起来" % Game.eggs_ready
		elif Game.chicken_count > 0:
			txt = "小鸡们正在散步，下蛋后按 E 来捡"
		else:
			txt = "鸡舍还空着：商店可买小鸡（800g）"
	elif player.position.distance_to(decor.SHOP_POS) < 90.0:
		txt = "按 E 打开商店"
	elif player.position.distance_to(decor.DOOR_POS) < 80.0:
		txt = "按 E 睡觉，回满体力进入下一天"
	elif gather.near_bush(player.position):
		txt = "野莓熟了：按 E 采摘，第二天会再结果"
	elif decor.POND_RECT.grow(30.0).has_point(player.position):
		txt = "水边适合钓鱼：7 甩竿 · 咬钩后再按空格"
	else:
		txt = "1-8 切换工具 · 空格/左键 使用 · C 制作 · E 互动 · H 帮助"
	if hint_label.text != txt:
		hint_label.text = txt


## 世界坐标飘字（+N 动作反馈）：上浮并淡出
func _float_text(txt: String, world_pos: Vector2, col: Color) -> void:
	var holder := Node2D.new()
	holder.position = world_pos
	holder.z_index = 60
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", _ui_font)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.06))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(140, 20)
	l.position = Vector2(-70, -30)
	holder.add_child(l)
	add_child(holder)
	var tw := holder.create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "position:y", world_pos.y - 36.0, 0.95) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(holder, "modulate:a", 0.0, 0.95) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(holder.queue_free)


func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * farm.CELL + 16, c.y * farm.CELL + 16)


func _toast(msg: String) -> void:
	toast_label.text = msg
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _mk_label(txt: String, size: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", _ui_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _mk_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_override("font", _ui_font)
	b.add_theme_font_size_override("font_size", 14)
	return b
