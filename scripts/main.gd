extends Node2D
## 主场景逻辑：昼夜循环、天气（晴/雨）、八种工具（锄/壶/种子x4/鱼竿/斧镐）、体力系统、
## 钓鱼小游戏、村民对话与好感度、商店（种子/作物/鱼/材料/工具升级）、制作与放置、HUD 提示

const DAY_START_MIN := 6 * 60
const DAY_END_MIN := 24 * 60
const MINUTES_PER_SECOND := 6.0  # 现实 180 秒 = 游戏 1 天（放慢节奏，一天更从容）

enum Tool { HOE, CAN, SEED_PARSNIP, SEED_POTATO, SEED_STRAW, SEED_PUMP, SEED_CORN, SEED_BLUE, ROD, AXE }

const TOOL_NAMES := ["锄头", "水壶", "防风草种", "土豆种", "草莓种", "南瓜种", "玉米种", "蓝莓种", "鱼竿", "斧镐"]
## 物品栏槽位（1锄 2壶 3-6 春种 9玉米 0蓝莓 7鱼竿 8斧镐）→ 工具枚举，点选与高亮共用
const TOOL_OF_SLOT := [Tool.HOE, Tool.CAN, Tool.SEED_PARSNIP, Tool.SEED_POTATO,
	Tool.SEED_STRAW, Tool.SEED_PUMP, Tool.SEED_CORN, Tool.SEED_BLUE, Tool.ROD, Tool.AXE]
const TOOL_SEED := {
	Tool.SEED_PARSNIP: "parsnip", Tool.SEED_POTATO: "potato",
	Tool.SEED_STRAW: "straw", Tool.SEED_PUMP: "pumpkin",
	Tool.SEED_CORN: "corn", Tool.SEED_BLUE: "blue",
}
const TEX_BOBBER := preload("res://assets/bobber.png")
const TEX_FISH := preload("res://assets/fish.png")
const TEX_FISH_GOLD := preload("res://assets/fish_gold.png")
const TEX_EGG := preload("res://assets/egg.png")
const TEX_MILK := preload("res://assets/milk.png")
const TEX_WOOL := preload("res://assets/wool.png")
const RainScript := preload("res://scripts/rain.gd")
const MinimapScript := preload("res://scripts/minimap.gd")
const FriendArrowScript := preload("res://scripts/friend_arrow.gd")
const GoalArrowScript := preload("res://scripts/goal_arrow.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")
const TEX_GRASS_SNOW := preload("res://assets/grass_snow.png")
const TEX_PATCH_SNOW := [
	preload("res://assets/patch_snow1.png"),
	preload("res://assets/patch_snow2.png"),
	preload("res://assets/patch_snow3.png"),
	preload("res://assets/patch_snow4.png"),
]
const VillagerScript := preload("res://scripts/villager.gd")
const ChickenScript := preload("res://scripts/chicken.gd")
const LivestockScript := preload("res://scripts/livestock.gd")
const MineScript := preload("res://scripts/mine.gd")
const PetScript := preload("res://scripts/pet.gd")
const WorldChunksScript := preload("res://scripts/world_chunks.gd")
const MineWorldScript := preload("res://scripts/mine_world.gd")

## 节日活动：每 7 天一次，两类交替（当日达标睡前结算奖励）
const FESTS := {
	"fish": {"name": "钓鱼大赛", "goal": 3, "reward": 300, "unit": "钓鱼"},
	"harvest": {"name": "丰收祭", "goal": 5, "reward": 400, "unit": "收获作物"},
}

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
@onready var sun_grade: ColorRect = $UI/Sunlight
@onready var day_label: Label = $UI/DayTime
@onready var gold_label: Label = $UI/Gold
@onready var hint_label: Label = $UI/Hint
@onready var toast_label: Label = $UI/Toast
@onready var fade: ColorRect = $UI/Fade
@onready var shop_panel: PanelContainer = $UI/ShopPanel
@onready var _slot_labels: Array = [
	$UI/Hotbar/Slot1/L, $UI/Hotbar/Slot2/L, $UI/Hotbar/Slot3/L,
	$UI/Hotbar/Slot4/L, $UI/Hotbar/Slot5/L, $UI/Hotbar/Slot6/L,
	$UI/Hotbar/Slot7/L, $UI/Hotbar/Slot8/L, $UI/Hotbar/Slot9/L,
	$UI/Hotbar/Slot10/L,
]
@onready var _slot_panels: Array = [
	$UI/Hotbar/Slot1, $UI/Hotbar/Slot2, $UI/Hotbar/Slot3,
	$UI/Hotbar/Slot4, $UI/Hotbar/Slot5, $UI/Hotbar/Slot6,
	$UI/Hotbar/Slot7, $UI/Hotbar/Slot8, $UI/Hotbar/Slot9,
	$UI/Hotbar/Slot10,
]

## 可建造建筑在农舍东侧的 4 个固定槽位（小屋 / 矿洞入口都占一格）
const BUILD_SLOTS := [
	Vector2(-486, -372), Vector2(-396, -372),
	Vector2(-306, -372), Vector2(-216, -372),
]
## 矿洞场景：每挥一镐消耗 4 体力，挖够六成矿岩梯子出现
const MINE_HIT_COST := 4.0
## 矿洞场景在世界的远处（与农场互不干扰），进出矿洞只切换显示与传送
const MINE_WORLD_POS := Vector2(6400, 0)

var current_tool: int = Tool.HOE
var time_min := float(DAY_START_MIN)
var sleeping := false
var weather := "sun"  # "sun" / "rain" / "snow"
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

# 低配模式 / 每日农场小报 / 目标指引箭头
var _perf_low := false
var _set_perf_btn: Button
var _set_new_btn: Button
var _daily_open := false
var _daily_panel: PanelContainer
var _daily_vb: VBoxContainer
var _daily_text: Label
var _goal_arrow: Control

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
## 牛羊牧场：牛/羊节点、奶/毛产物精灵、商店购买按钮
var _cows: Array = []
var _sheeps: Array = []
var _milk_sprites: Array = []
var _wool_sprites: Array = []
var _cow_btn: Button
var _sheep_btn: Button
var _rod_btn: Button

# 矿洞 / 宠物 / 节日
var mine: Node2D
## 无限地图：核心农场外围的区块地形（world_chunks.gd）
var chunks: Node2D
var _pets: Array = []
var _petted_today := {}
var _pet_btns := {}
var _pet_house: Sprite2D = null   # 宠物窝（建好后显示在农舍旁）
var _pet_house_btn: Button = null
var _fest_count := 0

## 建筑（小屋仓库 / 矿洞入口）：V 键建造面板 + 世界里的建筑精灵
var build_open := false
var _build_panel: PanelContainer
var _build_dim: ColorRect
var _build_rows := {}        # kind -> {have: Label, btn: Button}
var _build_gold: Label
var _building_sprites: Array = []

## 仓库界面（进小屋后）：背包 ↔ 仓库存取
var storage_open := false
var _storage_panel: PanelContainer
var _storage_dim: ColorRect
var _storage_list: VBoxContainer
var _storage_cap: Label

## 矿洞场景（另一个世界）：进矿洞入口后玩家被传送到地下洞穴，地面世界整体隐藏
var mine_world: Node2D
var in_mine := false
var _mine_depth := 0
## 进洞前站在地面的位置：出洞时回到这里；在洞里存档也记这个位置
var _mine_return_pos := Vector2.ZERO
## 地面世界各节点的可见性快照（进洞时隐藏、出洞时原样恢复）
var _farm_vis_state := {}
## 本层梯子出现提示只弹一次
var _mine_ladder_told := false

# 钓鱼状态机：0 无 / 1 等待咬钩 / 2 咬钩窗口 / 3 搏鱼小游戏
var fish_state := 0
var _bobber: Sprite2D
var _bobber_base := Vector2.ZERO
var _bite_t := 0.0
var _bite_window := 0.0
# 钓鱼时机玩法：光标上下扫动，在绿区内按一下算命中，命中 N 次收鱼
var _cursor_y := 0.0
var _cursor_dir := 1.0
var _zone_y := 0.5
var _zone_half := 0.12
var _hits := 0
var _misses := 0
var _need_hits := 3
var _max_miss := 3
var _hit_flash := 0.0
var _hit_ok := false
var _hook_cd := 0.0
var _wt := 0.0
var _hooked_id := ""       # 本次咬钩的鱼（提竿瞬间按权重抽出）
var _fight_legend := false # 鱼王专属战斗：金条、更凶猛
var _fish_tip: Label       # 战斗提示文字（鱼王战换文案）
var _fish_root: Control
var _fish_bar: ColorRect
var _zone_rect: ColorRect
var _fish_icon: TextureRect
var _prog_fill: ColorRect

# 主角主动技能：冷却计时 / 阿茉「吆喝」的临时卖价加成 / HUD 技能按钮
var _skill_cd := 0.0
var _sell_buff_t := 0.0
var _skill_btn: Button

# 烹饪面板（灶台）
var cook_open := false
var _cook_panel: PanelContainer
var _cook_rows := {}      # dish id -> 原料持有 Label
var _cook_eat_rows := {}  # dish id -> [数量 Label, 吃 按钮]

# 送礼面板（村民）
var gift_open := false
var _gift_panel: PanelContainer
var _gift_title: Label
var _gift_rows := {}      # item id -> [持有 Label, 按钮]
var _gift_villager_id := ""
var _gifted_today := {}   # {村民id: 今日已送礼次数}，不存档

# 联机（Net autoload）
var _shadow: Node2D = null   # 对方玩家影子精灵
var _shadow_tp := Vector2.ZERO # 影子目标位置（收到快照后平滑插值）
var _snap_t := 0.0           # 10Hz 快照/位置播报计时
var _pf_t := 0.0             # host 周期全量推送计时
var _full_t := 0.0           # 全量推送防抖
var _remote_exec := false    # host 正在替 guest 执行动作（抑制面板与二次转发）
var _guest_sleeping := false # guest 本地睡觉演出，等 host 全量数据落地
var _boot_panel: PanelContainer
var _boot_status: Label
var _boot_input: LineEdit
var _boot_btn_new: Button
var _hero_panel: PanelContainer  # 新游戏选角面板
var _hero_dim: ColorRect         # 选角时的全屏遮罩
var _hero_back := "boot"         # 选角来源（boot / save / settings），取消时回到对应面板

# 世界存档选择页：6 个存档位（进入 / 删除 / 空位新建）
var _save_panel: PanelContainer
var _save_dim: ColorRect
var _save_list: VBoxContainer
var _save_confirm := -1          # 二次确认删除的槽位号
var _pending_slot := -1          # 新建世界时预选的空槽

# 背包页面（I 键）：分类标签、物品格子、右侧详情与卖出
var bag_open := false
var _bag_panel: PanelContainer
var _bag_dim: ColorRect
var _bag_grid: GridContainer
var _bag_tabs: Array = []
var _bag_tab := 0
var _bag_sel_id := ""
var _bag_gold: Label
var _bag_name: Label
var _bag_cat: Label
var _bag_hold: Label
var _bag_unit: Label
var _bag_note: Label
var _bag_sell1: Button
var _bag_sellall: Button
var _last_season := -1       # 季节变化时重刷地表色调

# 花钱传送面板（R 键 / 触屏菜单）
var _tel_panel: PanelContainer
var _tel_dim: ColorRect

# 一键功能范围档：false=玩家附近 3×3（默认），true=全田，G 键切换
var _aoe_all := false
var _tex_ground_orig: Texture2D = null
var _tex_patch_orig: Array = []
var _minimap: Control
var _arrow: Control
var _chat_log: VBoxContainer
var _chat_input: LineEdit
var _chat_open := false

# 设置面板（音乐/音效/触屏按钮/UI 缩放/全屏），配置由 Save 持久化
var settings_open := false
var _settings_panel: PanelContainer
var _settings_dim: ColorRect
var _set_music_btn: Button
var _set_sfx_btn: Button
var _set_touch_btn: Button
var _set_scale_btn: Button
var _set_fs_btn: Button
var _set_music_slider: HSlider
var _set_sfx_slider: HSlider
var _set_music_pct: Label
var _set_sfx_pct: Label
# 触屏控制层（虚拟摇杆 + 动作按钮），由 touch_controls.gd 实现
var _touch

# 新手引导条 / 七日目标/ 收集包面板 / 温室购买按钮（新增系统）
var _guide_panel: PanelContainer
var _guide_label: Label
var _goal_panel: PanelContainer
var _goal_label: Label
var _goal_t := 0.0
var bundles_open := false
var _bundles_panel: PanelContainer
var _bundle_descs: Array = []
var _bundle_btns: Array = []
var _gh_btn: Button
# 目标清单面板（Y 键）：七日目标像成就一样随时可看，过期未完成也不会消失
var goals_open := false
var _goals_panel: PanelContainer
var _goals_head: Label
var _goals_labels: Array = []


func _ready() -> void:
	_ui_font = SystemFont.new()
	_ui_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "SimSun"])
	# 上次玩的世界存档槽：开局先读它，读档/存档都落在这个槽
	Save.current = clampi(int(Save.setting("last_slot", 0)), 0, Save.SLOT_COUNT - 1)
	Game.state_changed.connect(_refresh_hud)
	Game.state_changed.connect(_ach_tick)
	Game.skill_up.connect(_on_skill_up)
	Game.achievement_done.connect(_on_achievement)
	_build_shop()
	_build_pet_house()
	_build_craft()
	_build_help()
	_build_stamina()
	_build_fishing_ui()
	_build_orders()
	_build_dex()
	_build_cook()
	_build_gift()
	_build_eggs()
	_build_barn_products()
	mine = MineScript.new()
	add_child(mine)
	chunks = WorldChunksScript.new()
	add_child(chunks)
	# 矿洞场景（另一个世界）：放在世界远处，平时隐藏，进矿洞入口才显示
	mine_world = MineWorldScript.new()
	mine_world.position = MINE_WORLD_POS
	mine_world.visible = false
	mine_world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(mine_world)
	_bobber = Sprite2D.new()
	_bobber.texture = TEX_BOBBER
	_bobber.visible = false
	_bobber.z_index = -2885  # 浮标贴在水面上：压在地面层之上、人和树之下
	add_child(_bobber)
	_build_dialog()
	_build_hud_extras()
	_build_bag()
	_build_structures_ui()
	_build_guide()
	_build_goals()
	_build_bundles()
	_build_daily()
	_rain_node = RainScript.new()
	_rain_node.z_index = 40
	_rain_node.visible = false
	add_child(_rain_node)
	for cfg in VILLAGERS:
		var npc = VillagerScript.new()
		npc.setup(load(cfg.tex), cfg.roam, cfg.name, cfg.spawn)
		add_child(npc)
		_villagers.append(npc)
	_roll_weather()
	_apply_season_tint()
	_refresh_hud()
	player.position = decor.DOOR_POS + Vector2(0, 44)
	if _do_load(false):
		_toast("已读取第 %d 天存档 · F5 存档 / F9 读档 · 按 H 看帮助" % Game.day)
	else:
		_gen_orders()
		_sync_chickens()
		_sync_livestock()
		_sync_pets()
		_toggle_help(true)
		_toast("欢迎回来！锄地(1) 浇水(2) 种地，7 鱼竿 8 斧镐，C 制作，H 帮助")
	decor.set_greenhouse(Game.greenhouse_built)
	_sync_buildings()
	# 读档可能把玩家放到核心区外，先把周围区块补上
	chunks.update_around(player.position, true)
	_refresh_guide()
	_goal_refresh()
	_refresh_festival()
	Net.net_message.connect(_on_net_msg)
	Net.net_error.connect(_on_net_error)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	_build_boot()
	_build_settings()
	_apply_settings()
	# 低配模式（设置里切换，落盘持久化）：关掉氛围粒子，移动端更省电
	_perf_low = bool(Save.setting("perf_low", false))
	decor.set_low_perf(_perf_low)
	get_viewport().size_changed.connect(_apply_ui_scale)
	# 触屏控制层与物品栏点选（点格子直接切工具，触屏/鼠标通用）
	# 触控层用独立 CanvasLayer（layer=2），不随设置里的 UI 缩放变化，按钮位置恒定
	_touch = TouchScript.new()
	_touch.main = self
	var tl := CanvasLayer.new()
	tl.name = "TouchLayer"
	tl.layer = 2
	add_child(tl)
	tl.add_child(_touch)
	_touch.refresh_mode()
	for i in _slot_panels.size():
		var sp: Control = _slot_panels[i]
		sp.mouse_filter = Control.MOUSE_FILTER_STOP
		sp.gui_input.connect(_on_slot_gui_input.bind(i))


func _process(delta: float) -> void:
	_wt += delta
	if not sleeping and not Net.is_guest():
		time_min += delta * MINUTES_PER_SECOND
		if time_min >= DAY_END_MIN:
			_do_sleep(true)
	if Game.season_index() != _last_season:  # 跨季换地表色调
		_last_season = Game.season_index()
		_apply_season_tint()
	canvas_mod.color = _sky_color(time_min)
	if weather == "rain":
		canvas_mod.color = canvas_mod.color.lerp(Color(0.62, 0.68, 0.8), 0.4)
	elif weather == "snow":
		canvas_mod.color = canvas_mod.color.lerp(Color(0.76, 0.82, 0.94), 0.35)
	# 洞里永远是暗色，洞外按天色（进出矿洞靠这个色调一眼区分）
	if in_mine:
		canvas_mod.color = Color(0.34, 0.32, 0.40)
	# 暖阳叠加随天色衰减：正午最暖，入夜自动消失
	if sun_grade != null and sun_grade.material != null:
		var day_lum := canvas_mod.color.get_luminance()
		sun_grade.material.set_shader_parameter("strength",
				clampf((day_lum - 0.34) / 0.42, 0.0, 1.0) * 0.2)
	day_label.text = "第 %d 天 · %s %d/%d  %s · %s" % [
		Game.day, Game.season_name(), Game.season_day(), Game.SEASON_DAYS,
		_clock_text(), _weather_name()]
	if _shadow != null:
		_shadow.position = _shadow.position.lerp(_shadow_tp, clampf(delta * 12.0, 0.0, 1.0))
	_update_target()
	_update_hint()
	# 洞里不用外围区块地形（矿洞场景是独立的一张图）
	if not in_mine:
		chunks.update_around(player.position)
	# 七日目标每秒校验一次（统计口径来自累计计数，跨联机 guest 不参与结算）
	_goal_t += delta
	if _goal_t >= 1.0:
		_goal_t = 0.0
		if not Net.is_guest():
			_goal_check()
		_goal_refresh()
	if shop_open and player.position.distance_to(decor.SHOP_POS) > 130.0:
		_toggle_shop(false)
	if orders_open and player.position.distance_to(decor.BOARD_POS) > 100.0:
		_toggle_orders(false)
	if dialog_open and player.position.distance_to(_dialog_villager.position) > 110.0:
		_toggle_dialog(false)
	Music.update_phase(time_min, weather == "rain")
	_update_fishing(delta)
	_skill_tick(delta)
	_net_tick(delta)


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
	elif event.is_action_pressed("tool_9"):
		_switch_tool(Tool.SEED_CORN)
	elif event.is_action_pressed("tool_10"):
		_switch_tool(Tool.SEED_BLUE)
	elif event.is_action_pressed("mute"):
		var m: bool = Music.toggle_mute()
		Save.set_setting("music_on", not m)  # 与设置面板共用同一状态并落盘
		if settings_open:
			_refresh_settings_ui()
		_toast("背景音乐已%s（M 切换）" % ("开启" if not m else "关闭"))
	elif event.is_action_pressed("bag"):
		if bag_open:
			_toggle_bag(false)
		elif (not _panels_blocking() or (in_mine and not sleeping)) \
				and not (_boot_panel != null and _boot_panel.visible):
			_toggle_bag(true)  # 标题页/其它面板打开时按 I 不弹背包
	elif event.is_action_pressed("codex"):
		_toggle_dex(not dex_open)
	elif event.is_action_pressed("goals"):
		_toggle_goals(not goals_open)
	elif event.is_action_pressed("bundle"):
		_toggle_bundles(not bundles_open)
	elif event.is_action_pressed("minimap"):
		_minimap.toggle()
	elif event.is_action_pressed("chat"):
		_chat_begin()
	elif event.is_action_pressed("craft"):
		if help_open:
			_toggle_help(false)
		elif place_mode != "":
			_cancel_place()
		else:
			_toggle_craft(not craft_open)
	elif event.is_action_pressed("build"):
		if storage_open:
			_toggle_storage(false)
		elif build_open:
			_toggle_build(false)
		elif not _panels_blocking() and place_mode == "" and not in_mine:
			_toggle_build(true)
	elif event.is_action_pressed("help"):
		_toggle_help(not help_open)
	elif event.is_action_pressed("save_game"):
		if not sleeping and not Net.is_guest():
			_do_save()
	elif event.is_action_pressed("load_game"):
		if not sleeping and not Net.is_guest():
			_do_load()
	elif event.is_action_pressed("harvest_all"):
		if not _panels_blocking():
			_harvest_all()
	elif event.is_action_pressed("water_all"):
		if not _panels_blocking():
			_water_all()
	elif event.is_action_pressed("till_all"):
		if not _panels_blocking():
			_till_all()
	elif event.is_action_pressed("plant_all"):
		if not _panels_blocking():
			_plant_all()
	elif event.is_action_pressed("aoe_toggle"):
		if not _panels_blocking():
			_aoe_all = not _aoe_all
			_toast("一键范围已切换为：%s（收获/浇水/开垦/种植通用）" %
				("全部农田" if _aoe_all else "附近 3×3"))
	elif event.is_action_pressed("teleport"):
		if _tel_panel != null:
			_toggle_teleport(false)
		elif not _panels_blocking():
			_toggle_teleport(true)
	elif event.is_action_pressed("use"):
		if _daily_open:
			_toggle_daily(false)
			return
		if settings_open:
			return
		if bag_open:
			return
		if build_open or storage_open:
			return
		if help_open:
			_toggle_help(false)
		elif dex_open:
			_toggle_dex(false)
		elif goals_open:
			_toggle_goals(false)
		elif bundles_open:
			_toggle_bundles(false)
		elif orders_open:
			_toggle_orders(false)
		elif craft_open:
			_toggle_craft(false)
		elif cook_open:
			_toggle_cook(false)
		elif gift_open:
			_toggle_gift(false)
		elif dialog_open:
			_toggle_dialog(false)
		elif place_mode != "":
			if Net.is_guest():
				_guest_place_intent()
			else:
				_place_at_target()
		elif shop_open:
			_toggle_shop(false)
		else:
			_use_tool()
	elif event.is_action_pressed("skill"):
		if not _panels_blocking():
			_cast_skill()
	elif event.is_action_pressed("interact"):
		_interact_chain()
	elif event.is_action_pressed("ui_cancel"):
		if _chat_open:
			_chat_close()
		elif build_open:
			_toggle_build(false)
		elif storage_open:
			_toggle_storage(false)
		elif bag_open:
			_toggle_bag(false)
		elif _daily_open:
			_toggle_daily(false)
		elif settings_open:
			_toggle_settings(false)
		elif help_open:
			_toggle_help(false)
		elif dex_open:
			_toggle_dex(false)
		elif goals_open:
			_toggle_goals(false)
		elif bundles_open:
			_toggle_bundles(false)
		elif orders_open:
			_toggle_orders(false)
		elif shop_open:
			_toggle_shop(false)
		elif craft_open:
			_toggle_craft(false)
		elif cook_open:
			_toggle_cook(false)
		elif gift_open:
			_toggle_gift(false)
		elif dialog_open:
			_toggle_dialog(false)
		elif place_mode != "":
			_cancel_place()
		else:
			_toggle_settings(true)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and not shop_open and not craft_open \
			and not orders_open and not dex_open and place_mode == "" \
			and not cook_open and not gift_open and not settings_open \
			and not bundles_open and not _daily_open and not goals_open \
			and not bag_open and not build_open and not storage_open:
		_use_tool()


# ---------- E 键交互链 ----------

## E 键交互链：面板开关 / 摘野莓 / 收蛋收奶 / 摸宠 / 睡觉 / 机器
## 联机时 guest 的突变动作改为发意图，由 host 执行后回推全量
func _interact_chain() -> void:
	if bag_open or build_open:
		return
	# 在矿洞场景里：E 只处理「入口梯子回地面」与「层间梯子下潜」
	if in_mine:
		_mine_interact()
		return
	if help_open:
		_toggle_help(false)
	elif dex_open:
		_toggle_dex(false)
	elif goals_open:
		_toggle_goals(false)
	elif bundles_open:
		_toggle_bundles(false)
	elif orders_open:
		_toggle_orders(false)
	elif shop_open:
		_toggle_shop(false)
	elif craft_open:
		_toggle_craft(false)
	elif cook_open:
		_toggle_cook(false)
	elif gift_open:
		_toggle_gift(false)
	elif dialog_open:
		_toggle_dialog(false)
	elif _near_villager() != null and not _remote_exec:
		_open_gift(_near_villager())
	elif _berry_try() > 0:
		player.pop()
		if Net.is_guest():
			Net.send({t = "intent", k = "berry",
					d = {"pos": [player.position.x, player.position.y]}})
		else:
			Game.add_xp("gather", 4)
		Sfx.play("pick")
		_float_text("+野莓", player.position + Vector2(0, -30), Color(1, 0.55, 0.5))
		_toast("摘到了野莓！已放进背包，明天会再结果")
	elif player.position.distance_to(decor.BOARD_POS) < 70.0 and not _remote_exec:
		_toggle_orders(true)
	elif player.position.distance_to(decor.COOP_POS) < 80.0:
		if Net.is_guest():
			Net.send({t = "intent", k = "eggs", d = {}})
		else:
			_collect_eggs()
	elif player.position.distance_to(decor.BARN_POS) < 90.0:
		if Net.is_guest():
			Net.send({t = "intent", k = "barn", d = {}})
		else:
			_collect_barn()
	elif player.position.distance_to(decor.SHOP_POS) < 90.0 and not _remote_exec:
		_toggle_shop(true)
	elif player.position.distance_to(decor.DOOR_POS) < 80.0 and not sleeping:
		if Net.is_guest():
			_guest_sleep_start()
		else:
			_do_sleep(false)
	elif _machine_near() != null:
		var m: Dictionary = _machine_near()
		if m.data.type == "stove":
			if not _remote_exec:
				Sfx.play("plant")
				_toggle_cook(true)
		elif Net.is_guest():
			Net.send({t = "intent", k = "machine",
					d = {"cx": m.cell.x, "cy": m.cell.y}})
		else:
			_machine_interact(m)
	# 建筑门口按 E：小屋进仓库界面，矿洞入口进另一个场景（地下矿洞）
	elif _near_building() != null:
		_enter_building(_near_building())
	# 宠物放在链尾：附近没有村民/野莓/货摊/机器等可交互对象时，才摸宠物或安放
	elif _near_pet() != null:
		if Net.is_guest():
			Net.send({t = "intent", k = "pet", d = {"kind": _near_pet().kind}})
		else:
			_pet_pet(_near_pet())
	elif _near_pet_house():
		if Net.is_guest():
			_toast("联机模式暂不支持安放宠物")
		else:
			_toggle_pets_home()


## 摘野莓：本地/host 真摘（入背包），guest 只做视觉（入账走意图）
func _berry_try() -> int:
	if Net.is_guest():
		return 1 if gather.pick_berry_visual(player.position) else 0
	return gather.pick_berry(player.position)


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
		# 稻草人/洒水器/加工机/灶台/熔炉/奶酪机有放置预览图，施肥无实体
		var pm: String = place_mode \
				if (place_mode == "scarecrow" or place_mode == "sprinkler" \
				or place_mode == "sprinkler2" \
				or (place_mode != "" and Game.MACHINE_INPUTS.has(place_mode))) else ""
		farm.set_preview(pm, cell, pm != "")


func _area_cells(center: Vector2i, level: int) -> Array:
	if level < 2:
		return [center]
	var r := 1 if level == 2 else (2 if level == 3 else 3)
	var out: Array = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			out.append(center + Vector2i(dx, dy))
	return out


func _use_tool() -> void:
	# 在矿洞场景里：任何工具都当镐用（敲前方的矿岩）
	if in_mine:
		_mine_swing()
		return
	if Net.is_guest() and current_tool != Tool.ROD:
		# 联机：guest 的工具动作发意图由 host 结算（鱼竿小游戏本地自打）
		Net.send({t = "intent", k = "tool", d = {
			"tool": current_tool,
			"pos": [player.position.x, player.position.y],
			"fx": player.facing.x, "fy": player.facing.y,
		}})
		return
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
	# 收获优先：任何工具对着成熟作物都能收（蓝莓一次结两颗，玉米等多季作物不拔根）
	var got = farm.try_harvest(cell)
	if got != "":
		var n := int(Game.CROPS[got].get("yield", 1))
		Game.add_harvest(got, n)
		Game.total_harvest += n
		Game.add_xp("farm", 6)
		var hmsg := "收获了%s x%d！" % [Game.CROPS[got].name, n]
		if Game.CROPS[got].has("regrow"):
			hmsg += "（留着植株，还会再结果）"
		if _fest_kind(Game.day) == "harvest":
			_fest_count += n
			hmsg += "　[丰收祭 %d/5]" % _fest_count
		_guide_advance(3)  # 新手引导：收获
		_toast(hmsg)
		_float_text("+%d %s" % [n, Game.CROPS[got].name], _cell_center(cell), Color(1, 0.9, 0.35))
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
				Game.total_tilled += done
				_guide_advance(0)  # 新手引导：锄地
				if Game.hoe_level == 2:
					_toast("铜锄开垦了 %d 块地" % done)
				elif Game.hoe_level == 3:
					_toast("铁锄开垦了 %d 块地" % done)
				else:
					_toast("金锄开垦了 %d 块地" % done)
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
				_guide_advance(1)  # 新手引导：浇水
				if Game.can_level == 2:
					_toast("铜壶浇了 %d 块地" % done)
				elif Game.can_level == 3:
					_toast("铁壶浇了 %d 块地" % done)
				else:
					_toast("金壶浇了 %d 块地" % done)
			else:
				_toast(err)
		Tool.SEED_PARSNIP, Tool.SEED_POTATO, Tool.SEED_STRAW, Tool.SEED_PUMP, \
		Tool.SEED_CORN, Tool.SEED_BLUE:
			var id: String = TOOL_SEED[current_tool]
			if Game.seeds[id] <= 0:
				_toast("没有%s种子了，去商店买吧" % Game.CROPS[id].name)
				return
			var msg: String = farm.try_plant(cell, id)
			if msg == "":
				Game.use_seed(id, 1)
				Game.add_xp("farm", 2)
				Game.total_planted += 1
				_guide_advance(2)  # 新手引导：播种
				_toast("种下了%s" % Game.CROPS[id].name)
				Sfx.play("plant")
				player.pop()
			else:
				_toast(msg)


func _axe_action() -> void:
	var p: Vector2 = player.position + player.facing * 36.0
	# 树木优先：站在树旁按斧镐直接砍倒，得木材并留下树桩
	var tree: int = decor.tree_near(p)
	if tree >= 0:
		if not Game.use_stamina(6.0):
			_toast("体力不够了，回床上睡一觉吧")
			return
		var wood := 3 + (2 if randf() < 0.5 else 0) + Game.ore_bonus()
		decor.chop_tree(tree)
		Game.add_item("wood", wood)
		Game.add_xp("gather", 8)
		Sfx.play("axe")
		player.pop()
		_float_text("+%d 木材" % wood, decor.TREES[tree] + Vector2(0, 8), Color(0.8, 0.65, 0.45))
		_toast("砍倒一棵树！获得木材 x%d（留下树桩）" % wood)
		return
	var is_ore: bool = mine.near(p)
	if not is_ore and not gather.near(p):
		_toast("附近没有能砍的树、能敲的石头或矿岩")
		return
	if not Game.use_stamina(4.0 if is_ore else 3.0):
		_toast("体力不够了，回床上睡一觉吧")
		return
	var res: Dictionary = mine.hit_at(p) if is_ore else gather.hit_at(p)
	Sfx.play("axe")
	player.pop()
	if res.result != "break":
		return
	if is_ore:
		var id: String = res.kind
		var n := (1 if id == "gem" else 1 + (1 if randf() < 0.4 else 0)) + Game.ore_bonus()
		Game.add_item(id, n)
		Game.add_xp("gather", {"copper": 6, "iron": 8, "gem": 12}[id])
		_toast("敲碎矿岩！获得%s x%d" % [Game.MATERIALS[id].name, n])
		_float_text("+%d %s" % [n, Game.MATERIALS[id].name], p, Color(0.95, 0.75, 0.4))
		return
	var n2 := 1 + (1 if randf() < 0.3 else 0)
	Game.add_xp("gather", 4)
	if res.kind == "rock":
		Game.add_item("stone", n2)
		_toast("敲碎了石头！获得石料 x%d" % n2)
		_float_text("+%d 石料" % n2, p, Color(0.85, 0.88, 0.95))
	else:
		Game.add_item("wood", n2)
		_toast("捡到了木材 x%d" % n2)
		_float_text("+%d 木材" % n2, p, Color(0.8, 0.65, 0.45))


# ---------- 钓鱼 ----------

func _fishing_action() -> void:
	match fish_state:
		0:
			if not decor.near_water(player.position, 44.0):
				_toast("要靠近水边（池塘或东边河岸）才能甩竿")
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
			_hooked_id = _pick_fish()
			_fight_legend = _hooked_id == "legend"
			_hits = 0
			_misses = 0
			_cursor_y = 0.0
			_cursor_dir = 1.0
			_hook_cd = 0.2  # 提竿这一下不算一次点击
			_hit_flash = 0.0
			_need_hits = 5 if _fight_legend else 3
			_max_miss = 4 if _fight_legend else 3
			# 鱼王绿区更窄；铜钓竿让绿区变大；阿溪被动再加宽并多给一次失误
			_zone_half = (0.10 if _fight_legend else 0.16) + (0.03 if Game.rod_lv >= 2 else 0.0)
			if Game.hero_kind() == "fish":
				_zone_half *= 1.2
				_max_miss += 1
			_next_zone()
			_bobber.visible = false
			_fish_icon.texture = TEX_FISH_GOLD if _fight_legend else TEX_FISH
			_fish_icon.modulate = Color(1, 1, 1)
			_fish_root.visible = true
			_update_fish_ui()
			if _fight_legend:
				_toast("水底金光大作——是鱼王！绿区很窄，稳住手！")
			else:
				_toast("咬住了！光标进入绿区时按 空格 / 点击，命中 3 次就能拉上来")
		3:
			pass


func _cast() -> void:
	var pr: Rect2 = decor.water_rect_near(player.position)
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


## 随机换一个新的绿区位置（不贴边）
func _next_zone() -> void:
	_zone_y = randf_range(_zone_half + 0.02, 1.0 - _zone_half - 0.02)


func _fight_update(delta: float) -> void:
	_hook_cd = maxf(_hook_cd - delta, 0.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	# 光标匀速上下扫，撞到两端反弹；鱼王更快，铜钓竿稍慢
	var spd := (0.78 if _fight_legend else 0.52) - (0.07 if Game.rod_lv >= 2 else 0.0)
	_cursor_y += _cursor_dir * spd * delta
	if _cursor_y >= 1.0:
		_cursor_y = 1.0
		_cursor_dir = -1.0
	elif _cursor_y <= 0.0:
		_cursor_y = 0.0
		_cursor_dir = 1.0
	if _hook_cd <= 0.0 and Input.is_action_just_pressed("use"):
		_hook_cd = 0.18
		_hit_flash = 0.3
		if absf(_cursor_y - _zone_y) <= _zone_half:
			_hits += 1
			_hit_ok = true
			Sfx.play("coin")
			_next_zone()
			if _hits >= _need_hits:
				_land_fish()
				return
		else:
			_misses += 1
			_hit_ok = false
			Sfx.play("bite")
			if _misses >= _max_miss:
				_end_fishing()
				_toast("鱼挣脱了……下次等光标进绿区再按")
				return
	_update_fish_ui()


## 刷新钓鱼 UI：绿区 + 光标 + 命中进度 + 提示文案
func _update_fish_ui() -> void:
	var zc := _zone_y * 240.0 - 120.0
	var zh := _zone_half * 240.0
	_zone_rect.offset_top = zc - zh
	_zone_rect.offset_bottom = zc + zh
	if _hit_flash > 0.0:
		_zone_rect.color = Color(0.62, 1.0, 0.5, 0.9) if _hit_ok else Color(1.0, 0.48, 0.42, 0.9)
	else:
		_zone_rect.color = Color(0.35, 0.95, 0.45, 0.33)
	var cc := _cursor_y * 240.0 - 120.0
	_fish_bar.offset_top = cc - 3.0
	_fish_bar.offset_bottom = cc + 3.0
	_fish_bar.color = Color(1, 0.95, 0.75, 0.95)
	_fish_icon.offset_top = cc - 12.0
	_fish_icon.offset_bottom = cc + 12.0
	_prog_fill.offset_top = 118.0 - 236.0 * float(_hits) / float(_need_hits)
	_prog_fill.color = Color(0.45, 0.9, 0.5) if _hits < _need_hits else Color(0.98, 0.85, 0.35)
	_fish_tip.text = "光标进绿区时按 空格 / 点击　命中 %d/%d · 失误 %d/%d" % [
		_hits, _need_hits, _misses, _max_miss]


## 按时间/天气筛出当前可钓的鱼并按权重抽一条（铜钓竿让稀有鱼权重翻倍）
func _pick_fish() -> String:
	var pool: Array = []
	var total := 0
	for id in Game.FISH:
		var f: Dictionary = Game.FISH[id]
		if f.get("night", false) and time_min < 1080.0:
			continue  # 虹鳟只在 18 点后
		if f.get("dusk", false) and time_min < 1200.0:
			continue  # 月光鱼只在 20 点后
		if f.get("rain", false) and weather != "rain":
			continue  # 雨鱼只在雨天
		var w := int(f.w)
		if Game.rod_lv >= 2 and (f.get("dusk", false) or f.get("rain", false) or f.get("legend", false)):
			w *= 2
		pool.append([id, w])
		total += w
	var r := randi() % total
	for pw in pool:
		r -= int(pw[1])
		if r < 0:
			return String(pw[0])
	return "smelt"


func _land_fish() -> void:
	_end_fishing()
	if Net.is_guest():
		# 联机：钓获由主机入账，本地只等 evt 表现反馈
		if randf() < 0.12:
			if randf() < 0.5:
				Net.send({t = "intent", k = "fish", d = {"kind": "chest_g",
						"g": [100, 150, 200, 300, 400][randi() % 5]}})
			else:
				Net.send({t = "intent", k = "fish", d = {"kind": "chest_i",
						"id": ["wood", "stone", "berry"][randi() % 3], "n": 2 + randi() % 3}})
		else:
			Net.send({t = "intent", k = "fish", d = {"kind": "fish", "id": _hooked_id}})
		return
	if randf() < 0.12:
		# 12% 概率钓上宝箱：金币或材料大礼
		if randf() < 0.5:
			_apply_chest_gold([100, 150, 200, 300, 400][randi() % 5])
		else:
			_apply_chest_item(["wood", "stone", "berry"][randi() % 3], 2 + randi() % 3)
		return
	_apply_fish(_hooked_id)


## 宝箱·金币结算
func _apply_chest_gold(g: int) -> void:
	Game.chest_opened += 1
	Game.add_gold(g)
	_toast("钓上来一个宝箱！打开获得 %d 金币！" % g)
	_float_text("+%d 金币" % g, player.position + Vector2(0, -34), Color(1, 0.9, 0.35))
	Game.add_xp("fish", 8)
	Sfx.play("coin")
	player.pop()


## 宝箱·材料结算
func _apply_chest_item(mat: String, n: int) -> void:
	Game.chest_opened += 1
	Game.add_item(mat, n)
	_toast("钓上来一个宝箱！打开获得%s x%d" % [Game.MATERIALS[mat].name, n])
	_float_text("+%d %s" % [n, Game.MATERIALS[mat].name],
			player.position + Vector2(0, -34), Color(1, 0.9, 0.35))
	Game.add_xp("fish", 8)
	Sfx.play("coin")
	player.pop()


## 钓到鱼的入账结算
func _apply_fish(pick: String) -> void:
	var first: bool = Game.mark_fish(pick)
	Game.add_item(pick, 1)
	Game.add_xp("fish", 30 if pick == "legend" else 10)
	var msg := "钓到了%s！已放进背包，去商店卖掉吧" % Game.FISH[pick].name
	if pick == "legend":
		msg = "传说鱼王·金鳞鲤上钩了！！！这运气百年难遇！"
	if first:
		msg += "　★ 图鉴新增！按 G 查看"
	if _fest_kind(Game.day) == "fish":
		_fest_count += 1
		msg += "　[大赛 %d/3]" % _fest_count
	_toast(msg)
	_float_text("+1 %s" % Game.FISH[pick].name, player.position + Vector2(0, -34), Color(0.55, 0.85, 1))
	Sfx.play("harvest")
	player.pop()


func _end_fishing() -> void:
	fish_state = 0
	_bobber.visible = false
	_bobber.modulate = Color(1, 1, 1)
	_fish_root.visible = false
	_fish_icon.texture = TEX_FISH
	_fish_icon.modulate = Color(1, 1, 1)
	_fight_legend = false
	if not sleeping:
		player.set_physics_process(true)


# ---------- 主角主动技能（Q 键 / HUD 按钮） ----------

## 每帧推进技能冷却与吆喝加成，并刷新 HUD 技能按钮文案
func _skill_tick(delta: float) -> void:
	_skill_cd = maxf(_skill_cd - delta, 0.0)
	_sell_buff_t = maxf(_sell_buff_t - delta, 0.0)
	if _skill_btn == null:
		return
	var h: Dictionary = Game.hero()
	var txt := "%s Q" % h.skill_name
	if _sell_buff_t > 0.0:
		txt = "吆喝 %.0fs" % ceilf(_sell_buff_t)
	elif _skill_cd > 0.0:
		txt = "%s %.0fs" % [h.skill_name, ceilf(_skill_cd)]
	if _skill_btn.text != txt:
		_skill_btn.text = txt
	_skill_btn.disabled = _skill_cd > 0.0


## 释放主动技能：耗体力 + 进冷却，效果按主角类型分流
func _cast_skill() -> void:
	var h: Dictionary = Game.hero()
	if _skill_cd > 0.0:
		_toast("%s还在冷却，剩 %.0f 秒" % [h.skill_name, ceilf(_skill_cd)])
		return
	if Net.is_guest():
		_toast("联机客人暂时借不到技能，回自己农场再用吧")
		return
	if fish_state != 0:
		_toast("先把鱼竿收起来再用技能")
		return
	var aim: Vector2 = player.position + player.facing * 30.0
	if Game.hero_kind() == "fish" and not decor.near_water(player.position, 60.0):
		_toast("要靠近水边才能撒网")
		return
	if Game.hero_kind() == "mine" and mine.count_within(aim, 110.0) == 0:
		_toast("身边没有矿岩，这一炮放空了")
		return
	if not Game.use_stamina(float(h.cost)):
		_toast("体力不够，放不出技能")
		return
	_skill_cd = float(h.cd)
	match Game.hero_kind():
		"stamina":
			player.sprint(4.0)
			Sfx.play("pick")
			_toast("疾行！4 秒内脚下生风")
		"sell":
			_sell_buff_t = 30.0
			Sfx.play("coin")
			_toast("吆喝开张！30 秒内卖价 +50%")
		"mine":
			player.pop()
			Sfx.play("axe")
			var kinds: Array = mine.smash_around(aim, 110.0)
			var total := 0
			for k in kinds:
				var n := 1 + Game.ore_bonus()
				Game.add_item(String(k), n)
				Game.add_xp("gather", {"copper": 6, "iron": 8, "gem": 12}[k])
				total += n
			_toast("爆破震碎 %d 块矿岩，共得矿石 x%d" % [kinds.size(), total])
		"fish":
			player.pop()
			_apply_fish(_pick_fish())


## 卖价倍率：阿茉被动 + 临时吆喝加成（四舍五入到整数金币）
func _sell_price(base: int) -> int:
	var mult := Game.sell_mult() * (1.5 if _sell_buff_t > 0.0 else 1.0)
	return int(round(float(base) * mult))


# ---------- 存档与读档 ----------

## 组装进度：Game 全局 + 时间/工具 + 玩家位置 + 农田地块与放置物 + 订单/鸡/宠物/图鉴/成就
func _save_payload() -> Dictionary:
	var tiles: Array = []
	for c in farm.tiles:
		var t: Dictionary = farm.tiles[c]
		tiles.append([c.x, c.y, int(t.tilled), int(t.watered), t.crop, int(t.stage), int(t.wtoday)])
	var sprink: Array = []
	for c in farm.sprinklers:
		sprink.append([c.x, c.y])
	var sprink2: Array = []
	for c in farm.sprinklers2:
		sprink2.append([c.x, c.y])
	var scare: Array = []
	for c in farm.scare_cells:
		scare.append([c.x, c.y])
	var mach: Array = []
	for c in farm.machines:
		var m: Dictionary = farm.machines[c]
		mach.append([c.x, c.y, m.type, m.input, m.ready])
	var orders: Array = []
	for o in _orders:
		orders.append([o.kind, o.item, o.n, o.gold, o.who, int(o.done)])
	# 在矿洞里存档：位置记成洞口（读档总是回到地面农场）
	var save_pos: Vector2 = _mine_return_pos if in_mine else player.position
	return {
		"day": Game.day, "gold": Game.gold, "hero_id": Game.hero_id,
		"saved_at": int(Time.get_unix_time_from_system()),
		"seeds": Game.seeds, "harvest": Game.harvest, "items": Game.items,
		"stamina": Game.stamina, "max_stamina": Game.max_stamina,
		"hoe_level": Game.hoe_level, "can_level": Game.can_level,
		"friends": Game.friends, "weather": weather,
		"time_min": time_min, "tool": current_tool,
		"px": save_pos.x, "py": save_pos.y,
		"tiles": tiles, "sprinklers": sprink, "sprinklers2": sprink2,
		"scarecrows": scare, "machines": mach,
		"xp": Game.xp, "skill_lv": Game.skill_lv,
		"caught_fish": Game.caught_fish, "chest_opened": Game.chest_opened,
		"chicken_count": Game.chicken_count, "eggs_ready": Game.eggs_ready,
		"total_eggs": Game.total_eggs, "total_harvest": Game.total_harvest,
		"rod_lv": Game.rod_lv,
		"cow_count": Game.cow_count, "sheep_count": Game.sheep_count,
		"milk_ready": Game.milk_ready, "wool_ready": Game.wool_ready,
		"total_milk": Game.total_milk, "total_wool": Game.total_wool,
		"total_bars": Game.total_bars, "total_cheese": Game.total_cheese,
		"pets": Game.pets, "pet_mood": Game.pet_mood,
		"pet_house": Game.pet_house, "pets_home": Game.pets_home,
		"buildings": Game.buildings, "storage": Game.storage,
		"orders_done": Game.orders_done, "orders": orders,
		"achievements": Game.achievements.keys(),
		"gift_milestones": Game.gift_milestones,
		"total_cooked": Game.total_cooked, "gift_count": Game.gift_count,
		"rocks": mine.payload(),
		# 新手引导 / 七日目标 / 温室 / 收集包
		"guide_step": Game.guide_step,
		"total_tilled": Game.total_tilled, "total_planted": Game.total_planted,
		"total_earned": Game.total_earned, "goals_claimed": Game.goals_claimed,
		"greenhouse_built": Game.greenhouse_built, "bundles_done": Game.bundles_done,
		"cut_trees": decor.cut_list(),
	}


func _apply_payload(d: Dictionary) -> void:
	_loading = true
	if Net.is_guest():
		# 联机：guest 的位置与工具选择本地保留，其余以 host 全量为准
		d["px"] = player.position.x
		d["py"] = player.position.y
		d["tool"] = current_tool
	Game.day = int(d.get("day", 1))
	Game.gold = int(d.get("gold", 500))
	# 主角：旧档没有 hero_id 时默认阿蓝，并补上一次体力上限加成
	var had_hero: bool = d.has("hero_id")
	Game.hero_id = clampi(int(d.get("hero_id", 0)), 0, Game.HEROES.size() - 1)
	player.set_hero(Game.hero_id)
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
	if not had_hero and Game.hero_kind() == "stamina":
		Game.max_stamina += 20.0
		Game.stamina += 20.0
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
	Game.rod_lv = clampi(int(d.get("rod_lv", 1)), 1, 2)
	Game.cow_count = clampi(int(d.get("cow_count", 0)), 0, Game.MAX_COWS)
	Game.sheep_count = clampi(int(d.get("sheep_count", 0)), 0, Game.MAX_SHEEP)
	Game.milk_ready = clampi(int(d.get("milk_ready", 0)), 0, decor.MILK_SPOTS.size())
	Game.wool_ready = clampi(int(d.get("wool_ready", 0)), 0, decor.WOOL_SPOTS.size())
	Game.total_milk = int(d.get("total_milk", 0))
	Game.total_wool = int(d.get("total_wool", 0))
	Game.total_bars = int(d.get("total_bars", 0))
	Game.total_cheese = int(d.get("total_cheese", 0))
	Game.pets = []
	for k in d.get("pets", []):
		if String(k) == "cat" or String(k) == "dog":
			Game.pets.append(String(k))
	var mood_d: Dictionary = d.get("pet_mood", {})
	for k in Game.pet_mood:
		Game.pet_mood[k] = int(mood_d.get(k, 0))
	Game.pet_house = bool(d.get("pet_house", false))
	var home_d: Dictionary = d.get("pets_home", {})
	for k in Game.pets_home:
		Game.pets_home[k] = bool(home_d.get(k, false))
	# 建筑与仓库存量：旧档默认没有建筑、仓库空
	Game.buildings = []
	for b in d.get("buildings", []):
		if typeof(b) != TYPE_DICTIONARY:
			continue
		var kind := String(b.get("kind", ""))
		var slot := int(b.get("slot", -1))
		if Game.BUILD_DEFS.has(kind) and slot >= 0 and slot < BUILD_SLOTS.size():
			Game.buildings.append({"kind": kind, "slot": slot})
	Game.storage = {}
	var st_d: Dictionary = d.get("storage", {})
	for k in st_d:
		if Game.items.has(k):
			var sn := int(st_d[k])
			if sn > 0:
				Game.storage[k] = sn
	Game.orders_done = int(d.get("orders_done", 0))
	Game.total_cooked = int(d.get("total_cooked", 0))
	Game.gift_count = int(d.get("gift_count", 0))
	var gm_d: Dictionary = d.get("gift_milestones", {})
	for who in Game.gift_milestones:
		var arr: Array = Game.gift_milestones[who]
		var saved: Array = gm_d.get(who, [])
		for i in arr.size():
			arr[i] = i < saved.size() and bool(saved[i])
	Game.achievements = {}
	for id in d.get("achievements", []):
		if Game.ACHIEVEMENTS.has(id):
			Game.achievements[id] = true
	# 新增系统：旧档没有这些字段时默认「引导已完成、未建温室」，避免老玩家被引导打扰
	Game.guide_step = clampi(int(d.get("guide_step", 5)), 0, Game.GUIDE_STEPS.size())
	Game.total_tilled = int(d.get("total_tilled", 0))
	Game.total_planted = int(d.get("total_planted", 0))
	Game.total_earned = int(d.get("total_earned", 0))
	Game.greenhouse_built = bool(d.get("greenhouse_built", false))
	Game.bundles_done = []
	for b in d.get("bundles_done", []):
		if Game.BUNDLES.has(String(b)):
			Game.bundles_done.append(String(b))
	Game.goals_claimed = {}
	var gc: Dictionary = d.get("goals_claimed", {})
	for k in gc:
		var gd: int = String(k).to_int()
		if gd >= 1 and gd <= Game.DAY_GOALS.size() and bool(gc[k]):
			Game.goals_claimed[gd] = true
	decor.set_greenhouse(Game.greenhouse_built)
	# 砍树状态：按存档恢复（空数组 = 所有树都在）
	decor.restore_cut(d.get("cut_trees", []))
	_refresh_guide()
	_orders.clear()
	for row in d.get("orders", []):
		_orders.append({
			"kind": String(row[0]), "item": String(row[1]), "n": int(row[2]),
			"gold": int(row[3]), "who": String(row[4]), "done": int(row[5]) == 1,
		})
	if _orders.is_empty():
		_gen_orders()
	weather = String(d.get("weather", "sun"))
	_apply_weather_visual()
	time_min = clampf(float(d.get("time_min", DAY_START_MIN)), DAY_START_MIN, DAY_END_MIN - 1.0)
	current_tool = clampi(int(d.get("tool", 0)), 0, 9)
	player.position = Vector2(
		float(d.get("px", decor.DOOR_POS.x)),
		float(d.get("py", decor.DOOR_POS.y + 44.0)))
	mine.restore(d.get("rocks", []))
	farm.restore_from(d)
	_sync_chickens()
	_sync_livestock()
	_refresh_barn_products()
	_sync_pets()
	_sync_buildings()
	_petted_today.clear()
	_fest_count = 0
	_refresh_eggs()
	_refresh_festival()
	Game.check_achievements(true)  # 旧档补录成就，静默不弹提示
	if orders_open:
		_refresh_orders()
	if dex_open:
		_refresh_dex()
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
	# 读档总是回到地面（存档里矿洞位置已记成洞口坐标）
	if in_mine:
		_leave_mine(true, false)
	# 清理残留的界面与钓鱼状态
	if shop_open:
		_toggle_shop(false)
	if craft_open:
		_toggle_craft(false)
	if help_open:
		_toggle_help(false)
	if cook_open:
		_toggle_cook(false)
	if gift_open:
		_toggle_gift(false)
	if fish_state > 0:
		_end_fishing()
	place_mode = ""
	farm.set_preview("", Vector2i.ZERO, false)
	if with_toast:
		Sfx.play("pick")
		_toast("已读取第 %d 天存档" % Game.day)
	return true


# ---------- 昼夜与睡觉 ----------

## 节日类型：day%7==0 才是节日；%14==7 钓鱼大赛，%14==0 丰收祭
func _fest_kind(d: int) -> String:
	if d % 7 != 0:
		return ""
	return "fish" if d % 14 == 7 else "harvest"


## 彩旗随当天是否节日开合
func _refresh_festival() -> void:
	decor.set_festival(_fest_kind(Game.day) != "")


func _do_sleep(passed_out: bool) -> void:
	if sleeping or Net.is_guest():
		return
	# 睡在矿洞里（含 24 点昏睡）：先回到地面，再按农场流程过夜
	if in_mine:
		_leave_mine(true, false)
	sleeping = true
	_close_panels()
	if fish_state > 0:
		_end_fishing()
	place_mode = ""
	farm.set_preview("", Vector2i.ZERO, false)
	player.set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.7)
	await tw.finished
	# 节日结算：睡觉时若今天是节日，按当日计数发奖
	var fest_msg := ""
	var fk := _fest_kind(Game.day)
	if fk != "":
		var cfg: Dictionary = FESTS[fk]
		if _fest_count >= int(cfg.goal):
			Game.add_gold(int(cfg.reward))
			fest_msg = " · %s达标，奖励 %d 金币！" % [cfg.name, cfg.reward]
		else:
			fest_msg = " · %s未达标（%d/%d）" % [cfg.name, _fest_count, cfg.goal]
	_fest_count = 0
	var before_season := Game.season_index()
	Game.day += 1
	time_min = float(DAY_START_MIN)
	_roll_weather()
	_refresh_festival()
	var season_msg := ""
	if Game.season_index() != before_season:
		_apply_season_tint()
		season_msg = " · %s季到了" % Game.season_name()
	var lost: int = farm.on_new_day(weather == "rain")
	gather.spawn_daily()
	mine.spawn_daily()
	# 鸡过夜下蛋；牛羊过夜产出牛奶/羊毛；订单板刷新 3 张新订单
	if Game.chicken_count > 0:
		Game.eggs_ready = mini(Game.eggs_ready + Game.chicken_count, 10)
		_refresh_eggs()
	if Game.cow_count > 0:
		Game.milk_ready = mini(Game.milk_ready + Game.cow_count, decor.MILK_SPOTS.size())
	if Game.sheep_count > 0:
		Game.wool_ready = mini(Game.wool_ready + Game.sheep_count, decor.WOOL_SPOTS.size())
	_refresh_barn_products()
	_gen_orders()
	_goal_check()  # 新的一天：补发已达成的阶段目标
	Game.stamina = Game.max_stamina
	Game.state_changed.emit()
	_talked_today.clear()
	_petted_today.clear()
	_gifted_today.clear()
	player.position = decor.DOOR_POS + Vector2(0, 46)
	var save_ok := _autosave()
	var tail := " · 已自动存档" if save_ok else ""
	var rtail := season_msg
	if weather == "rain":
		rtail += " · 今天下雨，农田已浇好"
	elif weather == "snow":
		rtail += " · 今天下雪了"
	if Game.eggs_ready > 0:
		rtail += " · 鸡下了 %d 颗蛋" % Game.eggs_ready
	if Game.milk_ready > 0:
		rtail += " · 奶牛产了 %d 瓶牛奶" % Game.milk_ready
	if Game.wool_ready > 0:
		rtail += " · 绵羊产了 %d 团羊毛" % Game.wool_ready
	for kind in Game.pets:  # 心情好的宠物次晨送礼
		if int(Game.pet_mood.get(kind, 0)) >= 60:
			Game.pet_mood[kind] = 20
			var pname: String = "小猫" if kind == "cat" else "小狗"
			var roll := randf()
			if roll < 0.4:
				var g := 40 + (randi() % 5) * 10
				Game.add_gold(g)
				rtail += " · %s叼来了 %d 金币" % [pname, g]
			elif roll < 0.75:
				Game.add_item("berry", 2)
				rtail += " · %s叼来了野莓 x2" % pname
			else:
				var f := "perch" if randf() < 0.6 else "smelt"
				Game.add_item(f, 1)
				rtail += " · %s叼来了%s" % [pname, Game.FISH[f].name]
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.7)
	await tw2.finished
	player.set_physics_process(true)
	sleeping = false
	var nf := _fest_kind(Game.day)
	var head := ""
	if nf != "":
		var ncfg: Dictionary = FESTS[nf]
		head = "今天是%s！%s %d 个就达标，睡前结算 %d 金币 · " % [
			ncfg.name, ncfg.unit, ncfg.goal, ncfg.reward]
	if lost > 0:
		_toast("%s乌鸦夜里偷吃了 %d 株作物！快做个稻草人（C）%s%s%s" % [head, lost, rtail, fest_msg, tail])
	elif passed_out:
		_toast("%s你累倒了……醒来已是第 %d 天%s%s%s" % [head, Game.day, rtail, fest_msg, tail])
	else:
		_toast("%s睡了个好觉！第 %d 天，体力已回满%s%s%s" % [head, Game.day, rtail, fest_msg, tail])
	if Net.is_host():
		_net_full_now()  # 联机：把新的一天全量同步给 guest
	_toggle_daily(true)  # 起床小报：天气 / 当季作物 / 订单 / 目标


## 有会挡住世界输入的 UI 打开时返回 true（一键收获 / 浇水前判断）
func _panels_blocking() -> bool:
	return sleeping or settings_open or help_open or dex_open or bundles_open \
			or orders_open or craft_open or cook_open or gift_open or dialog_open \
			or shop_open or _daily_open or goals_open or bag_open or _tel_panel != null \
			or build_open or storage_open or in_mine


## 一键收获：收下范围内成熟作物（默认玩家附近 3×3，G 可切全田；每株 1 体力）
func _harvest_all() -> void:
	if Net.is_guest():
		_toast("联机模式请逐格收获")
		return
	var cells: Array = []
	for c in _aoe_cells():
		if not farm.tiles.has(c):
			continue
		var t: Dictionary = farm.tiles[c]
		if t.crop != "" and int(t.stage) >= int(Game.CROPS[t.crop].days):
			cells.append(c)
	if cells.is_empty():
		_toast("%s没有成熟作物" % ("附近 3×3 内" if not _aoe_all else "农田里"))
		return
	var total := 0
	var kinds := {}
	for c in cells:
		if not Game.use_stamina(1.0):
			break
		var got: String = farm.try_harvest(c)
		if got == "":
			continue
		var n := int(Game.CROPS[got].get("yield", 1))
		Game.add_harvest(got, n)
		Game.total_harvest += n
		Game.add_xp("farm", 6)
		if _fest_kind(Game.day) == "harvest":
			_fest_count += n
		kinds[got] = int(kinds.get(got, 0)) + n
		total += n
		_float_text("+%d" % n, _cell_center(c), Color(1, 0.9, 0.35))
	if total <= 0:
		_toast("体力不够了，回床上睡一觉吧")
		return
	_guide_advance(3)
	_goal_check()
	Sfx.play("harvest")
	player.pop()
	var parts: Array = []
	for k in kinds:
		parts.append("%s x%d" % [Game.CROPS[k].name, kinds[k]])
	_toast("一键收获 %d 个：%s" % [total, "、".join(parts)])


## 一键浇水：给范围内没浇过水的土地浇水（默认 3×3，G 可切全田；每格 1 体力）
func _water_all() -> void:
	if Net.is_guest():
		_toast("联机模式请逐格浇水")
		return
	var cells: Array = []
	for c in _aoe_cells():
		if farm.tiles.has(c) and not bool(farm.tiles[c].watered):
			cells.append(c)
	if cells.is_empty():
		_toast("%s都浇过水了" % ("附近的土地" if not _aoe_all else "所有土地"))
		return
	var done := 0
	for c in cells:
		if not Game.use_stamina(1.0):
			break
		if farm.try_water(c) == "":
			done += 1
	if done <= 0:
		_toast("体力不够了，回床上睡一觉吧")
		return
	_guide_advance(1)
	_goal_check()
	Sfx.play("water")
	player.pop()
	_toast("一键浇水：浇了 %d 块地（剩余体力 %d）" % [done, int(Game.stamina)])


## 一键开垦：把范围内没开垦的格子翻一遍（默认 3×3，G 可切全田；每格 1 体力）
func _till_all() -> void:
	if Net.is_guest():
		_toast("联机模式请逐格开垦")
		return
	var cells: Array = []
	if _aoe_all:
		for c in _farm_all_cells():
			if not farm.tiles.has(c) and farm.zone_at(Vector2(c.x * 32 + 16, c.y * 32 + 16)):
				cells.append(c)
	else:
		for c in _aoe_cells():
			if not farm.tiles.has(c) and farm.zone_at(Vector2(c.x * 32 + 16, c.y * 32 + 16)):
				cells.append(c)
	if cells.is_empty():
		_toast("%s都开垦过了" % ("附近的地" if not _aoe_all else "农田"))
		return
	var done := 0
	for c in cells:
		if not Game.use_stamina(1.0):
			break
		if farm.try_till(c) == "":
			done += 1
	if done <= 0:
		_toast("体力不够了，回床上睡一觉吧")
		return
	Game.total_tilled += done
	_guide_advance(0)  # 新手引导：锄地
	_goal_check()
	Sfx.play("hoe")
	player.pop()
	_toast("一键开垦：翻了 %d 块地（剩余体力 %d）" % [done, int(Game.stamina)])


## 一键种植：按库存顺序把种子撒进范围内空着的已开垦地（默认 3×3，G 可切全田）
func _plant_all() -> void:
	if Net.is_guest():
		_toast("联机模式请逐格播种")
		return
	var ids: Array = []
	for t in [Tool.SEED_PARSNIP, Tool.SEED_POTATO, Tool.SEED_STRAW,
			Tool.SEED_PUMP, Tool.SEED_CORN, Tool.SEED_BLUE]:
		ids.append(TOOL_SEED[t])
	var cells: Array = []
	for c in _aoe_cells():
		if not farm.tiles.has(c):
			continue
		var t2: Dictionary = farm.tiles[c]
		if not bool(t2.tilled) or String(t2.crop) != "":
			continue
		if farm.sprinklers.has(c) or farm.sprinklers2.has(c):
			continue
		if farm.scare_cells.has(c) or farm.machines.has(c):
			continue
		cells.append(c)
	if cells.is_empty():
		_toast("%s没有空着的已开垦地，先用锄头开垦" % ("附近 3×3 内" if not _aoe_all else ""))
		return
	var planted := 0
	var kinds := {}
	for c in cells:
		# 每格按种子库存顺序选一种「这一格季节能种」的种子，避免拿着过季种子空转
		var gh: bool = farm.in_greenhouse(c)
		var id := ""
		for s in ids:
			if int(Game.seeds[s]) > 0 and Game.can_plant_in(gh, s):
				id = s
				break
		if id == "":
			break
		if not Game.use_stamina(1.0):
			break
		if farm.try_plant(c, id) != "":
			continue
		Game.use_seed(id, 1)
		Game.add_xp("farm", 2)
		Game.total_planted += 1
		planted += 1
		kinds[id] = int(kinds.get(id, 0)) + 1
	if planted <= 0:
		_toast("没有能种的种子（注意换季，冬天休耕）")
		return
	_guide_advance(2)  # 新手引导：播种
	_goal_check()
	Sfx.play("plant")
	player.pop()
	var parts: Array = []
	for k in kinds:
		parts.append("%s x%d" % [Game.CROPS[k].name, kinds[k]])
	_toast("一键种植 %d 株：%s" % [planted, "、".join(parts)])


## 一键功能的目标格：默认玩家所在格为中心的 3×3，按 G 调档后为全田
func _aoe_cells() -> Array:
	if _aoe_all:
		return farm.tiles.keys()
	var pc := Vector2i(int(floor(player.position.x / 32.0)), int(floor(player.position.y / 32.0)))
	var out: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			out.append(pc + Vector2i(dx, dy))
	return out


## 所有农田区（含温室）覆盖的格子（按 32px 网格取整）
func _farm_all_cells() -> Array:
	var out: Array = []
	var rects: Array = farm.ZONES.duplicate()
	if Game.greenhouse_built:
		rects.append(farm.GH_ZONE)
	for r in rects:
		var x0 := int(floor(r.position.x / 32.0))
		var x1 := int(floor(r.end.x / 32.0)) - 1
		var y0 := int(floor(r.position.y / 32.0))
		var y1 := int(floor(r.end.y / 32.0)) - 1
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var c := Vector2i(x, y)
				if not out.has(c):
					out.append(c)
	return out


# ---------- 花钱传送 ----------

const TELEPORT_COST := 200

## 传送点：名称 + 说明 + 落点（脚下要离开障碍/水面）
func _teleport_spots() -> Array:
	return [
		{"name": "农场门口", "desc": "回屋睡觉、整理农场", "pos": decor.DOOR_POS + Vector2(0, 44)},
		{"name": "商店货摊", "desc": "买种子、卖作物", "pos": decor.SHOP_POS + Vector2(-70, 70)},
		{"name": "东岸栈道", "desc": "河边钓鱼", "pos": Vector2(decor.DOCK_RECT.get_center().x, decor.DOCK_RECT.end.y - 6)},
		{"name": "矿洞入口", "desc": "敲矿岩挖矿石", "pos": decor.MINE_POS + Vector2(-60, 90)},
		{"name": "西侧森林", "desc": "砍树、采集野莓", "pos": Vector2(-1960, -200)},
	]


## 打开/关闭传送面板（每次传送花 200 金币）
func _toggle_teleport(on: bool) -> void:
	if not on:
		if _tel_panel != null:
			_tel_panel.queue_free()
			_tel_panel = null
		if _tel_dim != null:
			_tel_dim.queue_free()
			_tel_dim = null
		get_tree().paused = false
		return
	if _tel_panel != null:
		return
	get_tree().paused = true
	_tel_dim = ColorRect.new()
	_tel_dim.color = Color(0.02, 0.03, 0.05, 0.6)
	_tel_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_tel_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(_tel_dim)
	_tel_panel = PanelContainer.new()
	_tel_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_tel_panel.anchor_left = 0.5
	_tel_panel.anchor_top = 0.5
	_tel_panel.anchor_right = 0.5
	_tel_panel.anchor_bottom = 0.5
	_tel_panel.offset_left = -250.0
	_tel_panel.offset_top = -190.0
	_tel_panel.offset_right = 250.0
	_tel_panel.offset_bottom = 190.0
	_tel_panel.add_theme_stylebox_override("panel", _modal_style())
	$UI.add_child(_tel_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_tel_panel.add_child(vb)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(440, 0)
	vb.add_child(pad)
	var title := _mk_label("花 钱 传 送", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _mk_label("每次 %d 金币 · 当前金币 %d" % [TELEPORT_COST, Game.gold], 13)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.78)
	vb.add_child(sub)
	var hr := HSeparator.new()
	hr.modulate = Color(1, 1, 1, 0.22)
	vb.add_child(hr)
	for s in _teleport_spots():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vb.add_child(row)
		var vip := VBoxContainer.new()
		vip.add_theme_constant_override("separation", 0)
		vip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(vip)
		var nm := _mk_label(String(s.name), 16)
		vip.add_child(nm)
		var ds := _mk_label(String(s.desc), 11)
		ds.modulate = Color(1, 1, 1, 0.6)
		vip.add_child(ds)
		var pos: Vector2 = s.pos
		var spot_name: String = s.name
		var b := _mk_btn("传送 %d 金币" % TELEPORT_COST)
		b.custom_minimum_size = Vector2(150, 34)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func() -> void: _teleport_to(pos, spot_name))
		row.add_child(b)
	var back := _mk_btn("关闭")
	back.custom_minimum_size = Vector2(140, 34)
	back.add_theme_font_size_override("font_size", 13)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: _toggle_teleport(false))
	vb.add_child(back)


## 扣钱并瞬移到目标点
func _teleport_to(pos: Vector2, nm: String) -> void:
	if Game.gold < TELEPORT_COST:
		_toast("金币不足：传送要 %d 金币（现在 %d）" % [TELEPORT_COST, Game.gold])
		return
	if Net.is_guest():
		_toast("联机模式暂不支持传送")
		return
	Game.add_gold(-TELEPORT_COST)
	_toggle_teleport(false)
	player.position = pos
	player.velocity = Vector2.ZERO
	chunks.update_around(pos, true)
	Sfx.play("coin")
	_toast("传送到了%s（花 %d 金币）" % [nm, TELEPORT_COST])


## 目标指引箭头要指向的位置；没有明确目标时返回 null
func goal_target():
	if _panels_blocking() or place_mode != "":
		return null
	# 1) 有成熟作物：指向作物群中心
	var mid := Vector2i.ZERO
	var cnt := 0
	for c in farm.tiles:
		var t: Dictionary = farm.tiles[c]
		if t.crop != "" and int(t.stage) >= int(Game.CROPS[t.crop].days):
			mid += c
			cnt += 1
	if cnt > 0:
		mid = Vector2i(mid.x / cnt, mid.y / cnt)
		return _cell_center(mid)
	# 2) 有没做的订单：指向订单板
	for o in _orders:
		if not bool(o.done):
			return decor.BOARD_POS
	# 3) 新手引导未完成：锄地/播种/收获指向农田，卖货指向货摊
	if Game.guide_step < Game.GUIDE_STEPS.size():
		if Game.guide_step >= 4:
			return decor.SHOP_POS
		var n := 0
		var acc := Vector2i.ZERO
		for c in farm.tiles:
			acc += c
			n += 1
		if n > 0:
			return _cell_center(Vector2i(acc.x / n, acc.y / n))
		return _cell_center(Vector2i(0, 0)) if farm.tiles.has(Vector2i(0, 0)) else null
	# 4) 种子全部用光：指向商店
	var seeds := Game.seeds as Dictionary
	var left := 0
	for k in seeds:
		left += int(seeds[k])
	if left <= 0:
		return decor.SHOP_POS
	return null


## 关闭所有已打开的面板（睡觉/联机读档前调用）
func _close_panels() -> void:
	if _daily_open:
		_toggle_daily(false)
	if settings_open:
		_toggle_settings(false)
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
	if goals_open:
		_toggle_goals(false)
	if bundles_open:
		_toggle_bundles(false)
	if cook_open:
		_toggle_cook(false)
	if gift_open:
		_toggle_gift(false)
	if dialog_open:
		_toggle_dialog(false)


## 联机 guest 睡觉：本地只做黑屏演出，天亮数据等 host 全量同步
func _guest_sleep_start() -> void:
	if sleeping:
		return
	sleeping = true
	_close_panels()
	if fish_state > 0:
		_end_fishing()
	place_mode = ""
	farm.set_preview("", Vector2i.ZERO, false)
	player.set_physics_process(false)
	Net.send({t = "intent", k = "sleep", d = {}})
	_guest_sleeping = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.7)


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
	# 行数较多，套一层纵向滚动容器
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)
	vb.add_child(_mk_label("皮埃尔的种子商店", 19))
	_shop_gold_label = _mk_label("", 14)
	vb.add_child(_shop_gold_label)
	for id in Game.CROPS:
		_add_crop_row(vb, id)
	for cat in [Game.FISH, Game.MATERIALS]:
		for id in cat:
			_add_item_row(vb, cat, id)
	for id in Game.PRODUCTS:  # 加工产品只出售
		_add_item_row(vb, Game.PRODUCTS, id)
	for id in Game.DISHES:  # 料理可出售（灶台现做）
		_add_item_row(vb, Game.DISHES, id)
	var up_row := HBoxContainer.new()
	up_row.add_theme_constant_override("separation", 8)
	vb.add_child(up_row)
	var up_l := _mk_label("工具升级（铜 3x3 / 铁 5x5 范围）", 14)
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
	# 牛羊牧场：买奶牛/绵羊（住西侧畜棚，过夜产出）
	var cow_row := HBoxContainer.new()
	cow_row.add_theme_constant_override("separation", 8)
	vb.add_child(cow_row)
	var cow_l := _mk_label("买奶牛（每天产一瓶牛奶，可做奶酪）", 14)
	cow_l.custom_minimum_size = Vector2(250, 0)
	cow_row.add_child(cow_l)
	_cow_btn = _mk_btn("")
	_cow_btn.pressed.connect(_buy_livestock.bind("cow"))
	cow_row.add_child(_cow_btn)
	var sheep_row := HBoxContainer.new()
	sheep_row.add_theme_constant_override("separation", 8)
	vb.add_child(sheep_row)
	var sheep_l := _mk_label("买绵羊（每天产一团羊毛）", 14)
	sheep_l.custom_minimum_size = Vector2(250, 0)
	sheep_row.add_child(sheep_l)
	_sheep_btn = _mk_btn("")
	_sheep_btn.pressed.connect(_buy_livestock.bind("sheep"))
	sheep_row.add_child(_sheep_btn)
	# 温室建造：玻璃房内无视季节，冬天也能种
	var gh_row := HBoxContainer.new()
	gh_row.add_theme_constant_override("separation", 8)
	vb.add_child(gh_row)
	var gh_l := _mk_label("建造温室（东侧玻璃房，冬天也能种植）", 14)
	gh_l.custom_minimum_size = Vector2(250, 0)
	gh_row.add_child(gh_l)
	_gh_btn = _mk_btn("")
	_gh_btn.pressed.connect(_buy_greenhouse)
	gh_row.add_child(_gh_btn)
	# 钓竿升级：铜钓竿
	var rod_row := HBoxContainer.new()
	rod_row.add_theme_constant_override("separation", 8)
	vb.add_child(rod_row)
	var rod_l := _mk_label("钓竿升级为铜钓竿（收线更稳，稀有鱼出现率翻倍）", 14)
	rod_l.custom_minimum_size = Vector2(250, 0)
	rod_row.add_child(rod_l)
	_rod_btn = _mk_btn("")
	_rod_btn.pressed.connect(_upgrade_rod)
	rod_row.add_child(_rod_btn)
	# 宠物领养：猫/狗各一只
	for pk in ["cat", "dog"]:
		var p_row := HBoxContainer.new()
		p_row.add_theme_constant_override("separation", 8)
		vb.add_child(p_row)
		var p_l := _mk_label("领养%s（跟着你散步，按 E 摸摸头）" % ("小猫" if pk == "cat" else "小狗"), 14)
		p_l.custom_minimum_size = Vector2(250, 0)
		p_row.add_child(p_l)
		var p_btn := _mk_btn("")
		p_btn.pressed.connect(_adopt_pet.bind(pk))
		p_row.add_child(p_btn)
		_pet_btns[pk] = p_btn
	# 宠物窝：建好后可以把猫狗安放在窝边待命
	var ph_row := HBoxContainer.new()
	ph_row.add_theme_constant_override("separation", 8)
	vb.add_child(ph_row)
	var ph_l := _mk_label("建宠物窝（在窝边按 E 让猫狗回窝待命/放出）", 14)
	ph_l.custom_minimum_size = Vector2(300, 0)
	ph_row.add_child(ph_l)
	_pet_house_btn = _mk_btn("")
	_pet_house_btn.pressed.connect(_buy_pet_house)
	ph_row.add_child(_pet_house_btn)
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
	if Net.is_guest():
		Net.send({t = "intent", k = "buy", d = {"id": id}})
		return
	var cost: int = Game.CROPS[id].seed_cost
	if Game.gold < cost:
		_toast("金币不足！")
		return
	Game.add_gold(-cost)
	Game.add_seed(id, 1)
	Sfx.play("coin")
	_toast("买了 1 包%s种子" % Game.CROPS[id].name)


func _sell(id: String, all: bool) -> void:
	if Net.is_guest():
		Net.send({t = "intent", k = "sell", d = {"id": id, "all": all}})
		return
	var have: int = Game.harvest[id]
	if have <= 0:
		_toast("没有可出售的%s" % Game.CROPS[id].name)
		return
	var n := have if all else 1
	var unit: int = _sell_price(int(Game.CROPS[id].sell))
	Game.add_gold(n * unit)
	Game.remove_harvest(id, n)
	_guide_advance(4)  # 新手引导：卖货
	Sfx.play("coin")
	_toast("卖出%s x%d，赚了 %d 金币" % [Game.CROPS[id].name, n, n * unit])


func _sell_item(cat: Dictionary, id: String, all: bool) -> void:
	if Net.is_guest():
		Net.send({t = "intent", k = "sell_item", d = {"id": id, "all": all}})
		return
	var have: int = Game.items.get(id, 0)
	if have <= 0:
		_toast("背包里没有%s" % cat[id].name)
		return
	var n := have if all else 1
	var unit: int = _sell_price(int(cat[id].sell))
	Game.add_item(id, -n)
	Game.add_gold(n * unit)
	_guide_advance(4)  # 新手引导：卖货
	Sfx.play("coin")
	_toast("卖出%s x%d，赚了 %d 金币" % [cat[id].name, n, n * unit])


func _upgrade(which: String) -> void:
	if Net.is_guest():
		Net.send({t = "intent", k = "buy", d = {"id": which}})
		return
	var lv: int = Game.hoe_level if which == "hoe" else Game.can_level
	if lv >= 4:
		return
	var lv_names: Dictionary = {
		"hoe": ["锄头", "铜锄", "铁锄", "金锄"],
		"can": ["水壶", "铜壶", "铁壶", "金壶"],
	}
	var names: Array = lv_names[which]
	if lv == 1:
		var cost: int = Game.HOE_UP_COST if which == "hoe" else Game.CAN_UP_COST
		if Game.gold < cost:
			_toast("金币不足！")
			return
		Game.add_gold(-cost)
		if which == "hoe":
			Game.hoe_level = 2
		else:
			Game.can_level = 2
		Sfx.play("coin")
		_toast("%s升级为%s！范围 3x3" % [names[0], names[1]])
		return
	if lv == 2:
		# 铁质升级：金币 + 铜矿
		var cost2: int = Game.HOE_UP2_COST if which == "hoe" else Game.CAN_UP2_COST
		if Game.gold < cost2:
			_toast("金币不足！")
			return
		if Game.items.get("copper", 0) < Game.IRON_ORE_COST:
			_toast("铜矿不够！去东侧矿洞敲 %d 块铜矿" % Game.IRON_ORE_COST)
			return
		Game.add_gold(-cost2)
		Game.add_item("copper", -Game.IRON_ORE_COST)
		if which == "hoe":
			Game.hoe_level = 3
		else:
			Game.can_level = 3
		Sfx.play("coin")
		_toast("%s升级为%s！范围 5x5" % [names[1], names[2]])
		return
	# 金质升级：金币 + 铁锭（熔炉可把铁矿熔成铁锭）
	var cost3: int = Game.HOE_UP3_COST if which == "hoe" else Game.CAN_UP3_COST
	if Game.gold < cost3:
		_toast("金币不足！")
		return
	if Game.items.get("iron_bar", 0) < Game.GOLD_BAR_COST:
		_toast("铁锭不够！先造熔炉（C 制作）把铁矿熔成铁锭 x%d" % Game.GOLD_BAR_COST)
		return
	Game.add_gold(-cost3)
	Game.add_item("iron_bar", -Game.GOLD_BAR_COST)
	if which == "hoe":
		Game.hoe_level = 4
	else:
		Game.can_level = 4
	Sfx.play("coin")
	_toast("%s升级为%s！范围 7x7，一下管到整片田" % [names[2], names[3]])


## 商店领养宠物（猫/狗各一只）
func _adopt_pet(kind: String) -> void:
	if Net.is_guest():
		Net.send({t = "intent", k = "buy", d = {"id": kind}})
		return
	if Game.pets.has(kind):
		_toast("已经领养过%s啦" % ("小猫" if kind == "cat" else "小狗"))
		return
	if Game.gold < Game.PET_COST:
		_toast("金币不足！")
		return
	Game.add_gold(-Game.PET_COST)
	Game.pets.append(kind)
	Game.pet_mood[kind] = 20
	_sync_pets()
	Sfx.play("coin")
	_toast("领养了一只%s！它会一路小跑跟着你，按 E 摸摸头" % ("小猫" if kind == "cat" else "小狗"))
	_refresh_hud()


## 同步宠物节点数量与存档一致
func _sync_pets() -> void:
	while _pets.size() > Game.pets.size():
		var old: Node2D = _pets.pop_back()
		old.queue_free()
	while _pets.size() < Game.pets.size():
		var kind: String = Game.pets[_pets.size()]
		var pet: Node2D = PetScript.new()
		pet.setup(kind, player)
		add_child(pet)
		_pets.append(pet)
	var ap := _pet_house_pos()
	for i in _pets.size():
		var pn: Node2D = _pets[i]
		# 每只宠物在窝边分左右站位，避免叠成一团
		var off := Vector2(-34, 16) if i == 0 else Vector2(30, 20)
		pn.set_home(ap + off, bool(Game.pets_home.get(pn.kind, false)))
	if _pet_house != null:
		_pet_house.visible = Game.pet_house
		_pet_house.z_index = int((_pet_house.position.y + 34.0) / 4.0)
	if not _pet_btns.is_empty():
		for pk in _pet_btns:
			var owned: bool = Game.pets.has(pk)
			(_pet_btns[pk] as Button).text = "已领养" if owned else "领养 %dg" % Game.PET_COST
			(_pet_btns[pk] as Button).disabled = owned


func _near_pet() -> Variant:
	for p in _pets:
		if player.position.distance_to((p as Node2D).position) < 84.0:
			return p
	return null


## 摸摸头：心情 +30，每天每只一次；心情满 60 次晨送礼
func _pet_pet(pet: Node2D) -> void:
	if _petted_today.get(pet.kind, false):
		_toast("%s今天已经被摸过头啦，明天再来吧" % pet.pet_name)
		return
	_petted_today[pet.kind] = true
	Game.pet_mood[pet.kind] = mini(int(Game.pet_mood[pet.kind]) + 30, 100)
	Sfx.play("talk")
	player.pop()
	_float_text("心情 +30", pet.position + Vector2(0, -28), Color(1, 0.75, 0.8))
	_toast("摸了摸%s的头！心情 %d/100（满 60 次晨会叼礼物来）" % [pet.pet_name, Game.pet_mood[pet.kind]])


## 宠物窝的位置：农舍门口东侧
func _pet_house_pos() -> Vector2:
	return decor.DOOR_POS + Vector2(78, 30)


## 程序化画一只像素风小木窝（2 倍最近邻放大），建好后显示在农舍旁
func _build_pet_house() -> void:
	var img := Image.create(26, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var roof := Color(0.44, 0.27, 0.20)
	var roof_hi := Color(0.56, 0.36, 0.27)
	var wall := Color(0.78, 0.55, 0.33)
	var wall_dk := Color(0.58, 0.39, 0.23)
	var hole := Color(0.15, 0.11, 0.09)
	var cx := 13
	# 人字屋顶
	for y in 8:
		var half := 3 + y
		for x in range(cx - half, cx + half + 1):
			if x < 0 or x >= 26:
				continue
			img.set_pixel(x, y, roof_hi if y < 2 else roof)
	# 木墙（两侧与底部加深，当作描边）
	for y in range(8, 21):
		for x in range(4, 22):
			var c := wall
			if x <= 5 or x >= 20 or y >= 19:
				c = wall_dk
			img.set_pixel(x, y, c)
	# 圆拱门洞
	for y in range(13, 21):
		for x in range(10, 17):
			if y < 15 and (x <= 10 or x >= 16):
				continue
			img.set_pixel(x, y, hole)
	# 门口两侧的小名牌
	img.set_pixel(8, 17, Color(0.95, 0.90, 0.78))
	img.set_pixel(18, 17, Color(0.95, 0.90, 0.78))
	_pet_house = Sprite2D.new()
	_pet_house.texture = ImageTexture.create_from_image(img)
	_pet_house.position = _pet_house_pos()
	_pet_house.scale = Vector2(2, 2)
	_pet_house.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pet_house.visible = Game.pet_house
	add_child(_pet_house)


## 买宠物窝（要先有猫或狗）
func _buy_pet_house() -> void:
	if Game.pet_house:
		return
	if Game.pets.is_empty():
		_toast("先领养一只小猫或小狗，再来建窝吧")
		return
	if Game.gold < Game.PET_HOUSE_COST:
		_toast("金币不足！宠物窝要 %d 金币" % Game.PET_HOUSE_COST)
		return
	Game.add_gold(-Game.PET_HOUSE_COST)
	Game.pet_house = true
	Game.pets_home = {"cat": false, "dog": false}
	_sync_pets()
	Sfx.play("coin")
	_toast("建好了宠物窝！在窝边按 E 可以让小猫小狗回窝待命")
	_refresh_hud()


## 宠物窝是否在玩家附近
func _near_pet_house() -> bool:
	return Game.pet_house and _pet_house != null \
			and player.position.distance_to(_pet_house.position) < 70.0


## 窝边按 E：让所有宠物回家待命 / 全部放出来继续跟着人
func _toggle_pets_home() -> void:
	var all_home := true
	for k in Game.pets:
		if not bool(Game.pets_home.get(k, false)):
			all_home = false
	var target := not all_home
	for k in Game.pets:
		Game.pets_home[k] = target
	_sync_pets()
	Sfx.play("talk")
	player.pop()
	if target:
		_toast("%s回窝歇着啦，再按 E 就能把它们叫出来" % _pets_names())
	else:
		_toast("%s从窝里跑出来，又开始跟着你散步了" % _pets_names())


func _pets_names() -> String:
	var ns: Array = []
	for k in Game.pets:
		ns.append("小猫" if k == "cat" else "小狗")
	return "和".join(ns) if not ns.is_empty() else "宠物"


# ---------- 可建造建筑 + 仓库界面 + 矿洞界面 ----------

## 建筑在槽位上的世界坐标（贴图中心）
func _building_pos(slot: int) -> Vector2:
	if slot < 0 or slot >= BUILD_SLOTS.size():
		return BUILD_SLOTS[0]
	return BUILD_SLOTS[slot]


## 玩家站在哪座建筑门口（距离 78 内返回该建筑，否则 null）
func _near_building() -> Variant:
	for b in Game.buildings:
		var pos: Vector2 = _building_pos(int(b.slot)) + Vector2(0, 18)
		if player.position.distance_to(pos) < 78.0:
			return b
	return null


## 门口按 E：小屋 → 仓库界面，矿洞入口 → 传送到矿洞场景（另一个世界）
func _enter_building(b: Dictionary) -> void:
	Sfx.play("talk")
	player.pop()
	if String(b.kind) == "storehouse":
		_toggle_storage(true)
	else:
		_enter_mine()


## 程序化画建筑贴图（28×24，2 倍最近邻放大）
func _mk_building_tex(kind: String) -> ImageTexture:
	var img := Image.create(28, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if kind == "storehouse":
		# 木屋仓库：人字屋顶 + 木墙 + 圆拱门 + 两扇窗
		var roof := Color(0.46, 0.30, 0.22)
		var roof_hi := Color(0.60, 0.40, 0.30)
		var wall := Color(0.78, 0.58, 0.36)
		var wall_dk := Color(0.58, 0.40, 0.24)
		var win := Color(0.95, 0.88, 0.60)
		var door := Color(0.16, 0.12, 0.09)
		for y in 9:
			var half := 3 + y
			for x in range(14 - half, 14 + half + 1):
				if x < 0 or x >= 28:
					continue
				img.set_pixel(x, y, roof_hi if y < 3 else roof)
		for y in range(9, 23):
			for x in range(3, 25):
				var c := wall
				if x <= 4 or x >= 23 or y >= 21:
					c = wall_dk
				img.set_pixel(x, y, c)
		for y in range(15, 23):
			for x in range(12, 17):
				if y < 17 and (x <= 12 or x >= 16):
					continue
				img.set_pixel(x, y, door)
		for y in range(11, 14):
			for x in [6, 7, 8, 20, 21, 22]:
				img.set_pixel(x, y, win)
	else:
		# 矿洞入口：灰色石堆 + 木支架 + 黑洞
		var rock := Color(0.48, 0.48, 0.50)
		var rock_hi := Color(0.62, 0.62, 0.64)
		var dark := Color(0.08, 0.08, 0.10)
		var wood := Color(0.55, 0.38, 0.22)
		for y in range(4, 23):
			var half := 3 + (y - 4)
			for x in range(14 - half, 14 + half + 1):
				if x < 0 or x >= 28:
					continue
				img.set_pixel(x, y, rock_hi if y < 8 else rock)
		for y in range(11, 23):
			var half := 4 if y < 13 else 6
			for x in range(14 - half, 14 + half + 1):
				img.set_pixel(x, y, dark)
		for y in range(13, 23):
			img.set_pixel(7, y, wood)
			img.set_pixel(21, y, wood)
		for x in range(7, 22):
			img.set_pixel(x, 13, wood)
	return ImageTexture.create_from_image(img)


## 按 Game.buildings 重建世界里的建筑精灵（建造 / 读档后调用）
func _sync_buildings() -> void:
	for s in _building_sprites:
		s.queue_free()
	_building_sprites.clear()
	for b in Game.buildings:
		var spr := Sprite2D.new()
		spr.texture = _mk_building_tex(String(b.kind))
		spr.position = _building_pos(int(b.slot))
		spr.scale = Vector2(2, 2)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_as_relative = false
		spr.z_index = int((spr.position.y + 24.0) / 4.0)
		add_child(spr)
		_building_sprites.append(spr)


## 全屏界面打开时停住主角移动（界面不暂停世界，天色照常走）
func _modal_freeze(on: bool) -> void:
	if player != null:
		player.set_physics_process(not on)


## 全屏遮罩 + 居中面板（建造 / 仓库 / 矿洞共用同一套样式）
func _make_modal(w: float, h: float) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.visible = false
	$UI.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -w * 0.5
	panel.offset_top = -h * 0.5
	panel.offset_right = w * 0.5
	panel.offset_bottom = h * 0.5
	panel.add_theme_stylebox_override("panel", _modal_style())
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	$UI.add_child(panel)
	# 遮罩与面板压到 UI 最上层：盖住小地图 / 目标条 / 物品栏，像个独立界面
	# HUD 节点是 _ready 前面加进 $UI 的，光靠 move_child 压不住后来才加的小地图/目标条，
	# 这里再给高 z_index，保证界面永远盖在 HUD 之上
	dim.z_index = 900
	panel.z_index = 901
	$UI.move_child(dim, -1)
	$UI.move_child(panel, -1)
	return [dim, panel]


## 建三个界面的 UI：建造面板（V）+ 仓库界面 + 矿洞界面
func _build_structures_ui() -> void:
	# ---- 建造面板 ----
	var m := _make_modal(780.0, 280.0)
	_build_dim = m[0]
	_build_panel = m[1]
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_build_panel.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	var title := _mk_label("建 造", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_build_gold = _mk_label("", 14)
	_build_gold.add_theme_color_override("font_color", Color(1, 0.86, 0.42))
	top.add_child(_build_gold)
	var close := _mk_btn("×")
	close.custom_minimum_size = Vector2(34, 30)
	close.pressed.connect(func() -> void: _toggle_build(false))
	top.add_child(close)
	vb.add_child(_mk_label("农舍东侧有 4 个建筑位：造好后走过去按 E 进门（都是独立界面）", 13))
	for id in Game.BUILD_DEFS:
		var d: Dictionary = Game.BUILD_DEFS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var nm := _mk_label(String(d.name), 16)
		nm.custom_minimum_size = Vector2(110, 0)
		row.add_child(nm)
		var desc := _mk_label(String(d.desc), 12)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(330, 0)
		desc.modulate = Color(1, 1, 1, 0.72)
		row.add_child(desc)
		var cost := _mk_label("", 13)
		cost.custom_minimum_size = Vector2(170, 0)
		cost.add_theme_color_override("font_color", Color(1, 0.86, 0.42))
		row.add_child(cost)
		var btn := _mk_btn("建造")
		btn.custom_minimum_size = Vector2(74, 30)
		btn.pressed.connect(_buy_building.bind(id))
		row.add_child(btn)
		_build_rows[id] = {"btn": btn, "cost": cost}
	vb.add_child(_mk_label("小屋仓库：进门后把背包材料存着，最多存 8 种；矿洞挖到的东西也能存", 12))
	vb.add_child(_mk_label("矿洞入口：进门后一层层往下挖，越深铜/铁/宝石越多（每块 6 体力）", 12))
	vb.add_child(_mk_label("按 V / Esc 关闭", 12))

	# ---- 仓库界面 ----
	var ms := _make_modal(800.0, 470.0)
	_storage_dim = ms[0]
	_storage_panel = ms[1]
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 8)
	_storage_panel.add_child(svb)
	var stop := HBoxContainer.new()
	stop.add_theme_constant_override("separation", 10)
	svb.add_child(stop)
	var stitle := _mk_label("仓 库", 22)
	stitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop.add_child(stitle)
	_storage_cap = _mk_label("", 14)
	_storage_cap.add_theme_color_override("font_color", Color(0.66, 0.9, 0.72))
	stop.add_child(_storage_cap)
	var sclose := _mk_btn("×")
	sclose.custom_minimum_size = Vector2(34, 30)
	sclose.pressed.connect(func() -> void: _toggle_storage(false))
	stop.add_child(sclose)
	svb.add_child(_mk_label("背包里的材料和加工品都能存进来，取出后直接回到背包", 13))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	svb.add_child(sc)
	_storage_list = VBoxContainer.new()
	_storage_list.add_theme_constant_override("separation", 6)
	_storage_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(_storage_list)
	var sfoot := HBoxContainer.new()
	sfoot.alignment = BoxContainer.ALIGNMENT_END
	svb.add_child(sfoot)
	var leave := _mk_btn("离开仓库（返回农场）")
	leave.custom_minimum_size = Vector2(200, 32)
	leave.pressed.connect(func() -> void: _toggle_storage(false))
	sfoot.add_child(leave)


## 打开/关闭建造面板
func _toggle_build(open: bool) -> void:
	if build_open == open:
		return
	build_open = open
	_build_panel.visible = open
	_build_dim.visible = open
	_modal_freeze(open)
	if open:
		_refresh_build()


func _refresh_build() -> void:
	if _build_gold == null:
		return
	_build_gold.text = "金币 %d · 木材 %d · 已用 %d/%d 位" % [
		Game.gold, int(Game.items.get("wood", 0)),
		Game.buildings.size(), BUILD_SLOTS.size()]
	var full: bool = Game.buildings.size() >= BUILD_SLOTS.size()
	for id in _build_rows:
		var row: Dictionary = _build_rows[id]
		var d: Dictionary = Game.BUILD_DEFS[id]
		var btn: Button = row.btn
		var cost_l: Label = row.cost
		var n := 0
		for b in Game.buildings:
			if String(b.kind) == id:
				n += 1
		if full:
			cost_l.text = "建筑位已满"
			cost_l.add_theme_color_override("font_color", Color(1, 0.5, 0.45))
			btn.disabled = true
		else:
			var ok: bool = Game.gold >= int(d.gold) \
					and int(Game.items.get("wood", 0)) >= int(d.wood)
			cost_l.text = "%dg + 木材 %d%s" % [int(d.gold), int(d.wood),
					"" if n == 0 else "（已建 %d）" % n]
			cost_l.add_theme_color_override("font_color",
					Color(1, 0.86, 0.42) if ok else Color(1, 0.5, 0.45))
			btn.disabled = not ok


## 花金币 + 木材造一座建筑，占下一个空槽位
func _buy_building(id: String) -> void:
	var d: Dictionary = Game.BUILD_DEFS[id]
	if Game.buildings.size() >= BUILD_SLOTS.size():
		_toast("建筑位已经满了（最多 %d 座）" % BUILD_SLOTS.size())
		return
	if Game.gold < int(d.gold):
		_toast("%s 需要 %d 金币" % [d.name, int(d.gold)])
		return
	if int(Game.items.get("wood", 0)) < int(d.wood):
		_toast("木材不够：%s 需要木材 %d（砍树/捡树枝）" % [d.name, int(d.wood)])
		return
	Game.add_gold(-int(d.gold))
	Game.consume({"wood": int(d.wood)})
	Game.buildings.append({"kind": id, "slot": Game.buildings.size()})
	_sync_buildings()
	Sfx.play("coin")
	_toast("建好了%s！走到农舍东侧的建筑门口按 E 进去" % d.name)
	_refresh_build()


## 打开/关闭仓库界面
func _toggle_storage(open: bool) -> void:
	if storage_open == open:
		return
	storage_open = open
	_storage_panel.visible = open
	_storage_dim.visible = open
	_modal_freeze(open)
	if open:
		_refresh_storage()


func _storage_kinds() -> int:
	var n := 0
	for k in Game.storage:
		if int(Game.storage[k]) > 0:
			n += 1
	return n


## 仓库行：背包数量 / 仓库数量 / 存入 / 取出
func _refresh_storage() -> void:
	if _storage_list == null:
		return
	_storage_cap.text = "已存 %d/%d 种" % [_storage_kinds(), Game.STORAGE_CAP]
	for ch in _storage_list.get_children():
		_storage_list.remove_child(ch)
		ch.queue_free()
	var ids: Array = []
	for id in Game.items:
		if int(Game.items[id]) > 0 or int(Game.storage.get(id, 0)) > 0:
			ids.append(String(id))
	if ids.is_empty():
		_storage_list.add_child(_mk_label("背包和仓库都还空着", 13))
		return
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(Game.items.get(a, 0)) + int(Game.storage.get(a, 0)) \
				> int(Game.items.get(b, 0)) + int(Game.storage.get(b, 0)))
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_storage_list.add_child(row)
		var nm := _mk_label(_item_name(id), 15)
		nm.custom_minimum_size = Vector2(190, 0)
		row.add_child(nm)
		var bag_l := _mk_label("背包 %d" % int(Game.items.get(id, 0)), 13)
		bag_l.custom_minimum_size = Vector2(110, 0)
		row.add_child(bag_l)
		var sto_l := _mk_label("仓库 %d" % int(Game.storage.get(id, 0)), 13)
		sto_l.custom_minimum_size = Vector2(110, 0)
		sto_l.add_theme_color_override("font_color", Color(0.66, 0.9, 0.72))
		row.add_child(sto_l)
		var put := _mk_btn("存入")
		put.custom_minimum_size = Vector2(76, 28)
		put.disabled = int(Game.items.get(id, 0)) <= 0
		put.pressed.connect(_storage_put.bind(id))
		row.add_child(put)
		var take := _mk_btn("取出")
		take.custom_minimum_size = Vector2(76, 28)
		take.disabled = int(Game.storage.get(id, 0)) <= 0
		take.pressed.connect(_storage_take.bind(id))
		row.add_child(take)


func _storage_put(id: String) -> void:
	var n := int(Game.items.get(id, 0))
	if n <= 0:
		return
	if _storage_kinds() >= Game.STORAGE_CAP and int(Game.storage.get(id, 0)) <= 0:
		_toast("仓库最多存 %d 种物品，先取走一些吧" % Game.STORAGE_CAP)
		return
	Game.items[id] = 0
	Game.storage[id] = int(Game.storage.get(id, 0)) + n
	Sfx.play("coin")
	_toast("存入 %s x%d" % [_item_name(id), n])
	Game.state_changed.emit()
	_refresh_storage()


func _storage_take(id: String) -> void:
	var n := int(Game.storage.get(id, 0))
	if n <= 0:
		return
	Game.storage.erase(id)
	Game.items[id] = int(Game.items.get(id, 0)) + n
	Sfx.play("pick")
	_toast("取出 %s x%d" % [_item_name(id), n])
	Game.state_changed.emit()
	_refresh_storage()


# ---------- 矿洞场景（另一个世界） ----------

## 进矿洞入口：隐藏地面世界，把玩家传送到地下洞穴第 1 层
func _enter_mine() -> void:
	if in_mine:
		return
	_close_panels()
	in_mine = true
	_mine_depth = 1
	_mine_ladder_told = false
	_mine_return_pos = player.position
	_set_farm_visible(false)
	mine_world.process_mode = Node.PROCESS_MODE_INHERIT
	mine_world.visible = true
	mine_world.generate(1)
	player.position = mine_world.spawn_global()
	var cam: Camera2D = player.get_node("Camera")
	cam.reset_smoothing()
	if _minimap != null:
		_minimap.visible = false
	Sfx.play("pick")
	_toast("进了矿洞第 1 层：8 斧镐敲矿岩，挖够六成梯子出现，走到梯子按 E 下一层")


## 出矿洞：恢复地面世界并回到洞口
func _leave_mine(restore_world := true, back_to_door := true) -> void:
	if not in_mine:
		return
	in_mine = false
	mine_world.visible = false
	mine_world.process_mode = Node.PROCESS_MODE_DISABLED
	if restore_world:
		_set_farm_visible(true)
	if _minimap != null:
		_minimap.visible = true
	if back_to_door:
		player.position = _mine_return_pos + Vector2(0, 26)
		var cam: Camera2D = player.get_node("Camera")
		cam.reset_smoothing()
		chunks.update_around(player.position, true)
		_toast("顺着入口梯子爬回了地面农场")


## 隐藏 / 恢复地面世界（只切可见性，节点状态与存档都不动）
func _set_farm_visible(on: bool) -> void:
	if not on:
		_farm_vis_state.clear()
		for c in get_children():
			if c == player or c == mine_world or c is CanvasLayer:
				continue
			if c is CanvasItem:
				_farm_vis_state[c] = c.visible
				c.visible = false
	else:
		for c in _farm_vis_state:
			if is_instance_valid(c):
				c.visible = bool(_farm_vis_state[c])
		_farm_vis_state.clear()


## 洞里按 E：入口梯子回地面 / 层间梯子下一层
func _mine_interact() -> void:
	if mine_world.near_exit(player.position):
		_leave_mine()
		return
	if mine_world.near_ladder(player.position):
		_mine_depth += 1
		_mine_ladder_told = false
		mine_world.generate(_mine_depth)
		player.position = mine_world.spawn_global()
		var cam: Camera2D = player.get_node("Camera")
		cam.reset_smoothing()
		Sfx.play("pick")
		_toast("下到矿洞第 %d 层：越深矿岩越多，铜铁与宝石也更多" % _mine_depth)
		return
	if mine_world.ladder_ready:
		_toast("梯子已经出现了：走到发光那块矿岩旁按 E 下一层")
	else:
		_toast("再挖掉一些矿岩（六成以上）梯子才会出现")


## 洞里挥镐：敲前方的矿岩，每下 4 体力，碎掉进背包
func _mine_swing() -> void:
	var p: Vector2 = player.position + player.facing * 34.0
	var idx: int = mine_world.rock_near(p, 62.0)
	player.pop()
	Sfx.play("axe")
	if idx < 0:
		_toast("走近矿岩再挥镐（切到 8 斧镐或用空格/左键）")
		return
	if not Game.use_stamina(MINE_HIT_COST):
		_toast("体力不够了：回地面睡觉或吃点料理再来")
		return
	var res: Dictionary = mine_world.hit(idx)
	if String(res.result) == "hit":
		return
	var id := String(res.ore)
	var n := (1 if id == "gem" else 1 + (1 if randf() < 0.45 else 0)) + Game.ore_bonus()
	Game.add_item(id, n)
	Game.add_xp("gather", {"copper": 6, "iron": 8, "gem": 12, "stone": 2}[id])
	Sfx.play("pick")
	var nm: String = "石料" if id == "stone" else String(Game.MATERIALS[id].name)
	var col: Color = {"copper": Color(0.95, 0.75, 0.4), "iron": Color(0.78, 0.86, 0.96),
		"gem": Color(0.88, 0.58, 0.98)}.get(id, Color(0.85, 0.88, 0.95))
	_float_text("+%d %s" % [n, nm], res.pos, col)
	_toast("挖到%s x%d（-4 体力）" % [nm, n])
	if mine_world.ladder_ready and not _mine_ladder_told:
		_mine_ladder_told = true
		_toast("挖穿了！这层出现了通向下一层的梯子")


## 洞里顶部提示：敲岩 / 下梯子 / 回地面
func _mine_hint() -> String:
	if mine_world.near_exit(player.position):
		return "按 E 顺着入口梯子爬回地面农场（挖到的东西都已进背包）"
	if mine_world.near_ladder(player.position):
		return "按 E 下到第 %d 层（越深矿岩越多、宝石越多）" % (_mine_depth + 1)
	if mine_world.ladder_ready:
		return "梯子已经出现：走到发光的那块矿岩旁按 E 下一层"
	return "矿洞第 %d 层：8 斧镐敲前方矿岩（每下 4 体力），挖掉六成梯子出现 · 已挖 %d/%d" % [
		_mine_depth, mine_world.done_count(), mine_world.rocks.size()]


## 附近的加工机；返回 {cell, data} 或 null
func _machine_near() -> Variant:
	var best = null
	var best_d := 48.0
	for c in farm.machines:
		var d: float = player.position.distance_to(_cell_center(c))
		if d < best_d:
			best_d = d
			best = {"cell": c, "data": farm.machines[c]}
	return best


func _item_name(id: String) -> String:
	if Game.CROPS.has(id):
		return Game.CROPS[id].name
	if Game.FISH.has(id):
		return Game.FISH[id].name
	if Game.MATERIALS.has(id):
		return Game.MATERIALS[id].name
	if Game.PRODUCTS.has(id):
		return Game.PRODUCTS[id].name
	if Game.DISHES.has(id):
		return Game.DISHES[id].name
	return id


## 原料库存（作物在 harvest，材料/蛋在 items）
func _stock_of(id: String) -> int:
	if Game.CROPS.has(id):
		return int(Game.harvest.get(id, 0))
	return int(Game.items.get(id, 0))


func _take_one(id: String) -> void:
	if Game.CROPS.has(id):
		Game.remove_harvest(id, 1)
	else:
		Game.add_item(id, -1)


func _machine_input_names(type: String) -> String:
	var names: Array = []
	for id in Game.MACHINE_INPUTS[type]:
		names.append(_item_name(id))
	return "、".join(names)


## 与机器互动：灶台打开烹饪面板；加工机收成品或放原料
func _machine_interact(m: Dictionary) -> void:
	var data: Dictionary = m.data
	if data.type == "stove":
		Sfx.play("plant")
		_toggle_cook(true)
		return
	var cname: String = Game.RECIPES[data.type].name
	if data.ready != "":
		var pid: String = data.ready
		Game.add_item(pid, 1)
		if pid == "copper_bar" or pid == "iron_bar":
			Game.total_bars += 1  # 熔炉成品计数（成就）
		elif pid == "cheese":
			Game.total_cheese += 1
		Game.add_xp("farm", 6)
		data.ready = ""
		farm.queue_redraw()
		Sfx.play("harvest")
		player.pop()
		_float_text("+1 %s" % Game.PRODUCTS[pid].name, _cell_center(m.cell), Color(1, 0.85, 0.45))
		_toast("从%s收好了%s！商店可卖 %dg" % [cname, Game.PRODUCTS[pid].name, Game.PRODUCTS[pid].sell])
		return
	if data.input != "":
		_toast("%s还在加工%s……明早完工" % [cname, _item_name(data.input)])
		return
	# 自动放入库存里产品价最高的原料
	var pick := ""
	for id in Game.MACHINE_INPUTS[data.type]:
		if _stock_of(id) > 0 and (pick == "" or Game.PRODUCTS[Game.MACHINE_INPUTS[data.type][id]].sell > Game.PRODUCTS[Game.MACHINE_INPUTS[data.type][pick]].sell):
			pick = id
	if pick == "":
		_toast("需要放原料：%s（背包/谷仓里要有货）" % _machine_input_names(data.type))
		return
	_take_one(pick)
	data.input = pick
	farm.queue_redraw()
	Sfx.play("plant")
	_toast("往%s里放入了%s，明天一早就能好" % [cname, _item_name(pick)])


func _toggle_shop(open: bool) -> void:
	shop_open = open
	shop_panel.visible = open
	if open:
		_refresh_hud()


# ---------- 烹饪（灶台） ----------

func _build_cook() -> void:
	_cook_panel = PanelContainer.new()
	_cook_panel.anchor_left = 0.5
	_cook_panel.anchor_top = 0.5
	_cook_panel.anchor_right = 0.5
	_cook_panel.anchor_bottom = 0.5
	_cook_panel.offset_left = -280.0
	_cook_panel.offset_top = -240.0
	_cook_panel.offset_right = 280.0
	_cook_panel.offset_bottom = 240.0
	_cook_panel.visible = false
	$UI.add_child(_cook_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_cook_panel.add_child(vb)
	vb.add_child(_mk_label("灶台 · 烹饪", 20))
	vb.add_child(_mk_label("菜谱（原料取自背包与谷仓，现做现吃）", 13))
	for id in Game.DISHES:
		var d: Dictionary = Game.DISHES[id]
		var parts := []
		for k in d.cost:
			parts.append("%s x%d" % [_item_name(k), d.cost[k]])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var name_l := _mk_label("%s（吃回 %d 体力 / 售 %dg）" % [d.name, d.energy, d.sell], 14)
		name_l.custom_minimum_size = Vector2(280, 0)
		row.add_child(name_l)
		var have_l := _mk_label("", 14)
		have_l.custom_minimum_size = Vector2(150, 0)
		row.add_child(have_l)
		_cook_rows[id] = have_l
		var b := _mk_btn("烹饪")
		b.pressed.connect(_cook_dish.bind(id))
		row.add_child(b)
	vb.add_child(_mk_label("—— 背包里的料理 ——", 14))
	for id in Game.DISHES:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 8)
		vb.add_child(row2)
		var l := _mk_label("", 14)
		l.custom_minimum_size = Vector2(280, 0)
		row2.add_child(l)
		var b2 := _mk_btn("吃")
		b2.pressed.connect(_eat_dish.bind(id))
		row2.add_child(b2)
		_cook_eat_rows[id] = [l, b2]
	vb.add_child(_mk_label("体力上限会随技能等级增长，料理是熬夜赶工的好帮手", 12))
	vb.add_child(_mk_label("按 E / Esc 关闭", 12))


func _toggle_cook(open: bool) -> void:
	cook_open = open
	_cook_panel.visible = open
	if open:
		_refresh_hud()


## 烹饪一道料理：原料够即做（原料可来自背包或谷仓作物），成品进背包
func _cook_dish(id: String) -> void:
	if Net.is_guest():
		Net.send({t = "intent", k = "cook", d = {"id": id}})
		return
	var d: Dictionary = Game.DISHES[id]
	for k in d.cost:
		if _stock_of(k) < int(d.cost[k]):
			_toast("原料不够！%s 需要 %s" % [d.name, _dish_cost_text(id)])
			return
	for k in d.cost:
		_take_one_n(k, int(d.cost[k]))
	Game.add_item(id, 1)
	Game.total_cooked += 1
	Game.add_xp("farm", 4)
	Sfx.play("harvest")
	_toast("做出了%s！吃下回复 %d 体力，或拿去卖 %dg" % [d.name, d.energy, d.sell])


## 扣除 n 份材料（作物走谷仓，其余走背包）
func _take_one_n(id: String, n: int) -> void:
	if Game.CROPS.has(id):
		Game.remove_harvest(id, n)
	else:
		Game.add_item(id, -n)


## 吃料理回体力（不超上限）
func _eat_dish(id: String) -> void:
	if Net.is_guest():
		Net.send({t = "intent", k = "eat", d = {"id": id}})
		return
	if int(Game.items.get(id, 0)) <= 0:
		_toast("背包里没有%s，先烹饪一份吧" % Game.DISHES[id].name)
		return
	Game.add_item(id, -1)
	var before := Game.stamina
	Game.stamina = minf(Game.stamina + float(Game.DISHES[id].energy), Game.max_stamina)
	var gained := int(Game.stamina - before)
	Sfx.play("harvest")
	_toast("吃掉了%s，体力 +%d（%d/%d）" % [Game.DISHES[id].name, gained, int(Game.stamina), int(Game.max_stamina)])
	Game.state_changed.emit()


func _dish_cost_text(id: String) -> String:
	var parts := []
	for k in Game.DISHES[id].cost:
		parts.append("%s x%d" % [_item_name(k), Game.DISHES[id].cost[k]])
	return "、".join(parts)


# ---------- 送礼（村民） ----------

func _build_gift() -> void:
	_gift_panel = PanelContainer.new()
	_gift_panel.anchor_left = 0.5
	_gift_panel.anchor_top = 0.5
	_gift_panel.anchor_right = 0.5
	_gift_panel.anchor_bottom = 0.5
	_gift_panel.offset_left = -270.0
	_gift_panel.offset_top = -292.0
	_gift_panel.offset_right = 270.0
	_gift_panel.offset_bottom = 292.0
	_gift_panel.visible = false
	$UI.add_child(_gift_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_gift_panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 5)
	scroll.add_child(vb)
	_gift_title = _mk_label("送礼", 20)
	vb.add_child(_gift_title)
	# 聊天按钮行（保留原对话玩法）
	var chat_row := HBoxContainer.new()
	chat_row.add_theme_constant_override("separation", 8)
	vb.add_child(chat_row)
	var chat_l := _mk_label("只是想聊聊天？", 14)
	chat_l.custom_minimum_size = Vector2(200, 0)
	chat_row.add_child(chat_l)
	var chat_btn := _mk_btn("聊天（好感 +10，每天一次）")
	chat_btn.pressed.connect(_gift_chat)
	chat_row.add_child(chat_btn)
	# 可送礼物行：作物 4 + 野莓 + 鱼 3 + 矿 3 + 产品 4 + 料理 3
	for id in Game.CROPS:
		_add_gift_row(vb, id)
	_add_gift_row(vb, "berry")
	for id in Game.FISH:
		if not Game.FISH[id].get("legend", false):
			_add_gift_row(vb, id)
	for id in ["copper", "iron", "gem"]:
		_add_gift_row(vb, id)
	for id in Game.PRODUCTS:
		_add_gift_row(vb, id)
	for id in Game.DISHES:
		_add_gift_row(vb, id)
	vb.add_child(_mk_label("好感增量 = 礼物售价的 1/10（最高 +8）；每人每天收 2 份", 12))
	vb.add_child(_mk_label("好感达到 20/40/60/80 时首次会收到回赠好礼", 12))
	vb.add_child(_mk_label("按 E / Esc 关闭", 12))


func _add_gift_row(vb: VBoxContainer, id: String) -> void:
	var price: int = Game.CROPS[id].sell if Game.CROPS.has(id) \
			else (Game.FISH[id].sell if Game.FISH.has(id) \
			else (Game.MATERIALS[id].sell if Game.MATERIALS.has(id) \
			else (Game.PRODUCTS[id].sell if Game.PRODUCTS.has(id) else Game.DISHES[id].sell)))
	var gain: int = clampi(price / 10, 1, 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var name_l := _mk_label("%s（%s · 好感 +%d）" % [_item_name(id), _gift_source_name(id), gain], 14)
	name_l.custom_minimum_size = Vector2(260, 0)
	row.add_child(name_l)
	var have_l := _mk_label("", 14)
	have_l.custom_minimum_size = Vector2(120, 0)
	row.add_child(have_l)
	var b := _mk_btn("送 1")
	b.pressed.connect(_give_gift.bind(id))
	row.add_child(b)
	_gift_rows[id] = [have_l, b]


func _gift_source_name(id: String) -> String:
	if Game.CROPS.has(id):
		return "谷仓作物"
	if Game.FISH.has(id) or Game.PRODUCTS.has(id) or Game.DISHES.has(id):
		return "背包"
	if id == "berry" or id == "copper" or id == "iron" or id == "gem":
		return "背包"
	return "背包"


## 靠近村民按 E：打开送礼面板
func _open_gift(v: Node2D) -> void:
	var id := ""
	for cfg in VILLAGERS:
		if cfg.name == v.display_name:
			id = cfg.id
			break
	_gift_villager_id = id
	var gifted: int = int(_gifted_today.get(id, 0))
	_gift_title.text = "送给 %s 的礼物 · 好感 %d · 今日已送 %d/%d" % [
		VILLAGER_NAMES[id], int(Game.friends[id]), gifted, Game.GIFT_DAILY]
	_toggle_gift(true)
	Sfx.play("talk")


func _toggle_gift(open: bool) -> void:
	gift_open = open
	_gift_panel.visible = open
	if open:
		_refresh_hud()
	else:
		_gift_villager_id = ""


## 送礼面板里点「聊天」：走原对话逻辑
func _gift_chat() -> void:
	var who := _gift_villager_id
	_toggle_gift(false)
	if Net.is_guest():
		if who != "":
			Net.send({t = "intent", k = "chat", d = {"who": who}})
		return
	var target: Node2D = null
	for v in _villagers:
		if who != "" and _villager_id_of(v) == who:
			target = v
			break
	if target != null:
		_talk_to(target)


func _villager_id_of(v: Node2D) -> String:
	for cfg in VILLAGERS:
		if cfg.name == v.display_name:
			return cfg.id
	return ""


## 送出 1 份礼物：好感 = 售价/10（上限 8），每日限次，里程碑回赠
func _give_gift(id: String) -> void:
	if Net.is_guest():
		if _gift_villager_id != "":
			# 本地乐观计数，host 结算后全量同步
			_gifted_today[_gift_villager_id] = int(_gifted_today.get(_gift_villager_id, 0)) + 1
			_open_gift_refresh()
		Net.send({t = "intent", k = "gift",
				d = {"who": _gift_villager_id, "id": id}})
		return
	_give_gift_to(_gift_villager_id, id)


## 送礼入账核心（本地与 host 意图共用）
func _give_gift_to(who: String, id: String) -> void:
	if who == "":
		return
	var gifted: int = int(_gifted_today.get(who, 0))
	if gifted >= Game.GIFT_DAILY:
		_toast("%s今天收够了礼物，明天再来吧" % VILLAGER_NAMES[who])
		return
	if _stock_of(id) <= 0:
		_toast("没有可以送的%s了" % _item_name(id))
		return
	_take_one(id)
	Game.gift_count += 1
	_gifted_today[who] = gifted + 1
	var price: int = Game.CROPS[id].sell if Game.CROPS.has(id) \
			else (Game.FISH[id].sell if Game.FISH.has(id) \
			else (Game.MATERIALS[id].sell if Game.MATERIALS.has(id) \
			else (Game.PRODUCTS[id].sell if Game.PRODUCTS.has(id) else Game.DISHES[id].sell)))
	var gain: int = clampi(price / 10, 1, 8)
	Game.friends[who] = mini(int(Game.friends[who]) + gain, 100)
	Sfx.play("talk")
	player.pop()
	_float_text("%s 好感 +%d" % [VILLAGER_NAMES[who], gain],
			player.position + Vector2(0, -30), Color(1, 0.7, 0.75))
	_toast("把%s送给了%s！好感 +%d（今日 %d/%d）" % [
		_item_name(id), VILLAGER_NAMES[who], gain,
		int(_gifted_today[who]), Game.GIFT_DAILY])
	_gift_milestone_check(who)
	Game.state_changed.emit()
	# 刷新面板标题里的计数
	if gift_open and not _remote_exec:
		_open_gift_refresh()


## 里程碑回赠：好感首次达到 20/40/60/80 发奖励
func _gift_milestone_check(who: String) -> void:
	var lv: int = int(Game.friends[who])
	var arr: Array = Game.gift_milestones[who]
	for i in Game.GIFT_MILESTONES.size():
		var m: int = int(Game.GIFT_MILESTONES[i])
		if lv >= m and not bool(arr[i]):
			arr[i] = true
			match i:
				0:
					Game.add_gold(int(Game.GIFT_REWARDS.gold))
					_toast("%s好感达到 %d！收到回赠 %d 金币" % [VILLAGER_NAMES[who], m, Game.GIFT_REWARDS.gold])
				1:
					var crops: Array = Game.CROPS.keys()
					var cid: String = crops[randi() % crops.size()]
					Game.add_seed(cid, int(Game.GIFT_REWARDS.seeds))
					_toast("%s好感达到 %d！收到回赠%s种子 x%d" % [VILLAGER_NAMES[who], m, Game.CROPS[cid].name, Game.GIFT_REWARDS.seeds])
				2:
					Game.add_item("gem", int(Game.GIFT_REWARDS.gem))
					_toast("%s好感达到 %d！收到回赠宝石 x1" % [VILLAGER_NAMES[who], m])
				3:
					Game.add_gold(int(Game.GIFT_REWARDS.gold2))
					_toast("%s好感达到 %d！收到回赠 %d 金币，你们是挚友了！" % [VILLAGER_NAMES[who], m, Game.GIFT_REWARDS.gold2])
			Sfx.play("coin")
			return  # 一次送礼最多触发一个里程碑


## 送礼后刷新面板标题（不重开面板）
func _open_gift_refresh() -> void:
	if _gift_villager_id == "":
		return
	var who := _gift_villager_id
	_gift_title.text = "送给 %s 的礼物 · 好感 %d · 今日已送 %d/%d" % [
		VILLAGER_NAMES[who], int(Game.friends[who]),
		int(_gifted_today.get(who, 0)), Game.GIFT_DAILY]


# ---------- 制作与放置 ----------

func _build_craft() -> void:
	craft_panel = PanelContainer.new()
	craft_panel.anchor_left = 0.5
	craft_panel.anchor_top = 0.5
	craft_panel.anchor_right = 0.5
	craft_panel.anchor_bottom = 0.5
	craft_panel.offset_left = -250.0
	craft_panel.offset_top = -330.0
	craft_panel.offset_right = 250.0
	craft_panel.offset_bottom = 330.0
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
	vb.add_child(_mk_label("高级洒水器：金色喷头，清晨自动浇灌 3x3 九宫格", 13))
	vb.add_child(_mk_label("速效肥：对已种作物的格子按空格施肥，立刻长一节", 13))
	vb.add_child(_mk_label("蛋黄酱机：按 E 放入鸡蛋，隔天收蛋黄酱（160g）", 13))
	vb.add_child(_mk_label("食品加工机：按 E 放入南瓜/草莓/防风草，隔天变派/酱/腌菜", 13))
	vb.add_child(_mk_label("灶台：放到农田格子上，对它按 E 打开烹饪面板做料理", 13))
	vb.add_child(_mk_label("熔炉：按 E 放入铜矿/铁矿，隔天熔成铜锭（150g）/铁锭（320g）", 13))
	vb.add_child(_mk_label("奶酪机：按 E 放入牛奶，隔天变奶酪（550g）", 13))
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
	_place_at_cell(place_mode, cell_v)


## 联机 guest：把放置动作打包成意图发给 host（本地只清预览）
func _guest_place_intent() -> void:
	var cell_v = farm.cell_at(player.position + player.facing * 26.0)
	if cell_v == null:
		cell_v = farm.cell_at(player.position)
	if cell_v == null:
		_toast("要在农场范围内放置")
		return
	Net.send({t = "intent", k = "place",
			d = {"mode": place_mode, "cx": cell_v.x, "cy": cell_v.y}})
	place_mode = ""
	farm.set_preview("", Vector2i.ZERO, false)


## 在指定格子放置（本地与 host 意图共用）
func _place_at_cell(mode: String, cell: Vector2i) -> void:
	var msg: String
	if mode == "scarecrow":
		msg = farm.place_scarecrow(cell)
	elif mode == "sprinkler":
		msg = farm.place_sprinkler(cell)
	elif mode == "sprinkler2":
		msg = farm.place_sprinkler2(cell)
	elif mode != "fertilizer":
		msg = farm.place_machine(cell, mode)
	else:
		msg = farm.try_fertilize(cell)
	if msg != "":
		_toast(msg)
		return
	Game.consume(Game.RECIPES[mode].cost)
	Sfx.play("plant")
	if mode == "fertilizer":
		var cn: String = farm.tiles[cell].crop
		_float_text("+1 节 %s" % Game.CROPS[cn].name, _cell_center(cell), Color(0.6, 1, 0.5))
		_toast("施了速效肥，%s马上长大了一截！" % Game.CROPS[cn].name)
	else:
		_toast("%s放置成功！" % Game.RECIPES[mode].name)
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
	var id := _villager_id_of(v)
	var line := _chat_core(id)
	_dialog_villager = v
	_dialog_name.text = "%s · 好感 %d" % [v.display_name, Game.friends[id]]
	_dialog_text.text = line
	_toggle_dialog(true)
	Sfx.play("talk")


## 聊天逻辑核心（好感 +10 每日一次）；返回台词
func _chat_core(id: String) -> String:
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
	return line


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


# ---------- 新手引导 · 七日目标 · 收集包 · 温室（新增系统） ----------

## 顶部左侧引导条 + 今日目标行（首日五步引导，完成后自动隐藏）
func _build_guide() -> void:
	_guide_panel = PanelContainer.new()
	_guide_panel.position = Vector2(20, 78)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.12, 0.08, 0.78)
	sb.border_color = Color(0.66, 0.84, 0.44, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	_guide_panel.add_theme_stylebox_override("panel", sb)
	_guide_panel.visible = false
	$UI.add_child(_guide_panel)
	_guide_label = _mk_label("", 14)
	_guide_panel.add_child(_guide_label)
	# 今日目标行：单独底板保证在花草地面上也看得清
	_goal_panel = PanelContainer.new()
	_goal_panel.position = Vector2(20, 112)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.08, 0.12, 0.08, 0.72)
	gsb.border_color = Color(0.92, 0.8, 0.42, 0.65)
	gsb.set_border_width_all(1)
	gsb.set_corner_radius_all(6)
	gsb.content_margin_left = 8.0
	gsb.content_margin_right = 8.0
	gsb.content_margin_top = 2.0
	gsb.content_margin_bottom = 2.0
	_goal_panel.add_theme_stylebox_override("panel", gsb)
	$UI.add_child(_goal_panel)
	_goal_label = _mk_label("", 13)
	_goal_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_goal_panel.add_child(_goal_label)


## 刷新引导条：已完成打 ✓，当前步 ▶，未到用 ·
func _refresh_guide() -> void:
	if _guide_panel == null:
		return
	if Game.guide_step >= Game.GUIDE_STEPS.size():
		_guide_panel.visible = false
		return
	_guide_panel.visible = true
	var parts: Array = []
	for i in Game.GUIDE_STEPS.size():
		var mark := "✓" if i < Game.guide_step else ("▶" if i == Game.guide_step else "·")
		parts.append("%s%s" % [mark, Game.GUIDE_STEPS[i]])
	_guide_label.text = "新手引导　" + "　".join(parts)


## 推进引导：只有正好在做当前步骤才前进（锄地→浇水→播种→收获→卖货）
func _guide_advance(step: int) -> void:
	if Game.guide_step != step:
		return
	Game.guide_step = step + 1
	if Game.guide_step >= Game.GUIDE_STEPS.size():
		Game.add_gold(200)
		Game.add_seed("parsnip", 3)
		_toast("新手引导完成！奖励 200 金币 + 防风草种子 x3，按 B 看收集包")
		_goal_check()
	_refresh_guide()


## 七日目标：逐日检查未领奖且已达标的阶段目标，自动发奖（错过可补领）
func _goal_check() -> void:
	for g in Game.DAY_GOALS:
		var d := int(g.day)
		if d > Game.day:
			break
		if Game.goals_claimed.has(d):
			continue
		if Game.goal_progress(String(g.kind)) >= int(g.n):
			Game.goals_claimed[d] = true
			Game.add_gold(int(g.gold))
			Game.add_seed(String(g.seed), int(g.seed_n))
			_toast("七日目标 · 第 %d 天「%s」达成！奖励 %d 金币 + %s种子 x%d" % [
				d, String(g.name), int(g.gold), Game.CROPS[String(g.seed)].name, int(g.seed_n)])
			Sfx.play("coin")
	_goal_refresh()


## 今日目标行：永远显示「最早一条未完成的目标」——当天没做完的第二天仍然挂着，
## 不会消失；全部完成才变成祝贺语
func _goal_refresh() -> void:
	if _goal_label == null:
		return
	var done := Game.goals_claimed.size()
	if done >= Game.DAY_GOALS.size():
		_goal_label.text = "七日目标全部完成 · 农场稳步走上正轨（Y 看清单）"
		if goals_open:
			_refresh_goals()
		return
	var g: Dictionary = {}
	for gg in Game.DAY_GOALS:
		if not Game.goals_claimed.has(int(gg.day)):
			g = gg
			break
	var tag := "今日目标"
	if int(g.day) < Game.day:
		tag = "补做目标"
	elif int(g.day) > Game.day:
		tag = "下一目标"
	var cur: int = mini(Game.goal_progress(String(g.kind)), int(g.n))
	_goal_label.text = "%s（第%d天）：%s　%d/%d　（Y 看全部）" % [
		tag, int(g.day), String(g.name), cur, int(g.n)]
	if goals_open:
		_refresh_goals()


## 目标清单面板：七日目标像成就一样排成一份常驻清单，随时能翻、过期也能补
func _build_goals() -> void:
	_goals_panel = PanelContainer.new()
	_goals_panel.anchor_left = 0.5
	_goals_panel.anchor_top = 0.5
	_goals_panel.anchor_right = 0.5
	_goals_panel.anchor_bottom = 0.5
	_goals_panel.offset_left = -330.0
	_goals_panel.offset_top = -192.0
	_goals_panel.offset_right = 330.0
	_goals_panel.offset_bottom = 192.0
	_goals_panel.visible = false
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.07, 0.1, 0.07, 0.95)
	gsb.border_color = Color(0.92, 0.8, 0.42, 0.8)
	gsb.set_border_width_all(2)
	gsb.set_corner_radius_all(10)
	gsb.content_margin_left = 20.0
	gsb.content_margin_right = 20.0
	gsb.content_margin_top = 14.0
	gsb.content_margin_bottom = 14.0
	_goals_panel.add_theme_stylebox_override("panel", gsb)
	$UI.add_child(_goals_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_goals_panel.add_child(vb)
	var title := _mk_label("七日目标 · 新手路线", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_goals_head = _mk_label("", 13)
	_goals_head.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	_goals_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_goals_head)
	for g in Game.DAY_GOALS:
		var l := _mk_label("", 14)
		l.custom_minimum_size = Vector2(0, 24)  # 固定行高，避免中英混排时行距挤压
		vb.add_child(l)
		_goals_labels.append(l)
	var note := _mk_label("目标不会过期：哪天想起来补做都算数，达成即自动发金币和种子", 12)
	note.add_theme_color_override("font_color", Color(0.72, 0.8, 0.62))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(note)
	var close_l := _mk_label("按 Y / E / Esc 关闭", 12)
	close_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(close_l)
	# 手机上触控层会给面板让位，这里放一个实体关闭按钮兜底
	var close_b := _mk_btn("关闭")
	close_b.pressed.connect(func() -> void: _toggle_goals(false))
	vb.add_child(close_b)


func _toggle_goals(open: bool) -> void:
	goals_open = open
	_goals_panel.visible = open
	if open:
		_refresh_goals()


## 逐条刷新：✓已达成 / ▶进行中 / ·未开始，附奖励说明
func _refresh_goals() -> void:
	if _goals_panel == null:
		return
	var done := 0
	for i in Game.DAY_GOALS.size():
		var g: Dictionary = Game.DAY_GOALS[i]
		var d := int(g.day)
		var got: bool = Game.goals_claimed.has(d)
		if got:
			done += 1
		var cur: int = mini(Game.goal_progress(String(g.kind)), int(g.n))
		var reward := "＋%d金 ＋%s种子x%d" % [int(g.gold),
			String(Game.CROPS[String(g.seed)].name), int(g.seed_n)]
		var text: String
		var col: Color
		if got:
			text = "✓ 第%d天　%s　（%s）" % [d, String(g.name), reward]
			col = Color(1, 0.85, 0.35)
		elif cur > 0:
			text = "▶ 第%d天　%s　%d/%d　（%s）" % [d, String(g.name), cur, int(g.n), reward]
			col = Color(1, 0.98, 0.92)
		else:
			text = "· 第%d天　%s　0/%d　（%s）" % [d, String(g.name), int(g.n), reward]
			col = Color(0.62, 0.6, 0.54)
		_goals_labels[i].text = text
		_goals_labels[i].add_theme_color_override("font_color", col)
	_goals_head.text = "已完成 %d/%d　·　没做完的会一直留在这里" % [done, Game.DAY_GOALS.size()]


## 收集包面板：交齐作物/鱼/矿石/牧产，换金币与永久体力上限
func _build_bundles() -> void:
	_bundles_panel = PanelContainer.new()
	_bundles_panel.anchor_left = 0.5
	_bundles_panel.anchor_top = 0.5
	_bundles_panel.anchor_right = 0.5
	_bundles_panel.anchor_bottom = 0.5
	_bundles_panel.offset_left = -310.0
	_bundles_panel.offset_top = -150.0
	_bundles_panel.offset_right = 310.0
	_bundles_panel.offset_bottom = 160.0
	_bundles_panel.visible = false
	$UI.add_child(_bundles_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_bundles_panel.add_child(vb)
	vb.add_child(_mk_label("社区收集包", 20))
	vb.add_child(_mk_label("交齐指定物资换金币 + 永久体力上限（B 键或「菜单」打开）", 13))
	for id in Game.BUNDLES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var desc := _mk_label("", 14)
		desc.custom_minimum_size = Vector2(440, 0)
		row.add_child(desc)
		_bundle_descs.append(desc)
		var btn := _mk_btn("交付")
		btn.pressed.connect(_deliver_bundle.bind(String(id)))
		row.add_child(btn)
		_bundle_btns.append(btn)
	vb.add_child(_mk_label("作物从农田仓库扣，鱼/矿石/牧产从背包扣", 13))
	vb.add_child(_mk_label("按 B / Esc 关闭", 12))


func _toggle_bundles(open: bool) -> void:
	if open:
		_close_panels()
	bundles_open = open
	_bundles_panel.visible = open
	if open:
		_refresh_bundles()


func _refresh_bundles() -> void:
	if _bundles_panel == null or not bundles_open:
		return
	var keys: Array = Game.BUNDLES.keys()
	for i in keys.size():
		var id := String(keys[i])
		var cfg: Dictionary = Game.BUNDLES[id]
		var parts: Array = []
		for need in cfg.need:
			parts.append("%s %d/%d" % [Game.bundle_name(String(need[0]), String(need[1])),
				mini(Game.bundle_stock(String(need[0]), String(need[1])), int(need[2])), int(need[2])])
		var fin: bool = Game.bundles_done.has(id)
		_bundle_descs[i].text = "%s　%s　→ %dg + 体力上限+%d%s" % [
			String(cfg.name), "　".join(parts), int(cfg.gold), int(cfg.stamina),
			"　[已完成]" if fin else ""]
		_bundle_descs[i].add_theme_color_override("font_color",
			Color(0.62, 0.58, 0.5) if fin else Color(1, 0.98, 0.92))
		_bundle_btns[i].disabled = fin


## 交付一个收集包：材料够才扣，奖金币并永久提高体力上限
func _deliver_bundle(id: String) -> void:
	if Net.is_guest():
		_toast("联机时由房主交付收集包")
		return
	if Game.bundles_done.has(id):
		return
	var cfg: Dictionary = Game.BUNDLES[id]
	var lack: Array = []
	for need in cfg.need:
		var have: int = Game.bundle_stock(String(need[0]), String(need[1]))
		if have < int(need[2]):
			lack.append("%s %d/%d" % [Game.bundle_name(String(need[0]), String(need[1])),
				have, int(need[2])])
	if not lack.is_empty():
		_toast("还差：" + "、".join(lack))
		return
	for need in cfg.need:
		if String(need[0]) == "crop":
			Game.remove_harvest(String(need[1]), int(need[2]))
		else:
			Game.add_item(String(need[1]), -int(need[2]))
	Game.bundles_done.append(id)
	Game.add_gold(int(cfg.gold))
	Game.max_stamina += float(cfg.stamina)
	Game.stamina = minf(Game.stamina + float(cfg.stamina), Game.max_stamina)
	Game.check_achievements()
	Sfx.play("coin")
	_toast("完成%s！奖励 %d 金币，体力上限永久 +%d" % [
		String(cfg.name), int(cfg.gold), int(cfg.stamina)])
	_refresh_bundles()


## 建造温室：金币 + 木材石料，建成后东侧玻璃房内无视季节播种
func _buy_greenhouse() -> void:
	if Net.is_guest():
		_toast("联机时由房主建造温室")
		return
	if Game.greenhouse_built:
		return
	if Game.gold < Game.GH_COST:
		_toast("金币不足，建造温室需要 %d 金币" % Game.GH_COST)
		return
	if Game.items.get("wood", 0) < Game.GH_WOOD or Game.items.get("stone", 0) < Game.GH_STONE:
		_toast("材料不足：需要木材 %d、石料 %d（8 斧镐敲树和石头）" % [Game.GH_WOOD, Game.GH_STONE])
		return
	Game.add_gold(-Game.GH_COST)
	Game.add_item("wood", -Game.GH_WOOD)
	Game.add_item("stone", -Game.GH_STONE)
	Game.greenhouse_built = true
	decor.set_greenhouse(true)
	Sfx.play("coin")
	_toast("温室建成了！东侧玻璃房里播种无视季节，冬天也能种")


## 每天随机 3 张订单（种类分布尽量打散，单类最多 2 张）
func _gen_orders() -> void:
	_orders.clear()
	var picks: Array = []
	for id in Game.CROPS:
		picks.append(["crop", id])
	for id in Game.FISH:
		if Game.FISH[id].get("legend", false):
			continue  # 鱼王太稀有，不进订单
		picks.append(["fish", id])
	for id in ["wood", "stone", "berry", "milk", "wool"]:
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
		n = 2 + randi() % 4 if base <= 30 else 1 + randi() % 2
	var gold := int(ceil(base * n * 1.55 / 5.0)) * 5
	return {
		"kind": kind, "item": id, "n": n, "gold": gold,
		"who": "rosa" if randf() < 0.5 else "ben", "done": false,
	}


func _deliver_order(i: int) -> void:
	if Net.is_guest():
		Net.send({t = "intent", k = "order", d = {"i": i}})
		return
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
		s.z_index = -2870  # 地上的蛋：在地面之上、人和动物之下
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
	if Net.is_guest():
		Net.send({t = "intent", k = "buy", d = {"id": "chicken"}})
		return
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


# ---------- 牛羊牧场 ----------

func _buy_livestock(kind: String) -> void:
	if Net.is_guest():
		Net.send({t = "intent", k = "buy", d = {"id": kind}})
		return
	var is_cow := kind == "cow"
	var count: int = Game.cow_count if is_cow else Game.sheep_count
	var cap: int = Game.MAX_COWS if is_cow else Game.MAX_SHEEP
	var cost: int = Game.COW_COST if is_cow else Game.SHEEP_COST
	var cname: String = "奶牛" if is_cow else "绵羊"
	if count >= cap:
		_toast("畜棚住满啦（%s最多 %d 只）" % [cname, cap])
		return
	if Game.gold < cost:
		_toast("金币不足！")
		return
	Game.add_gold(-cost)
	if is_cow:
		Game.cow_count += 1
	else:
		Game.sheep_count += 1
	_sync_livestock()
	Sfx.play("coin")
	_toast("买了一只%s！它住在西侧畜棚，每天产出%s" % [cname, "牛奶" if is_cow else "羊毛"])
	_refresh_hud()


func _sync_livestock() -> void:
	while _cows.size() > Game.cow_count:
		var c: Node2D = _cows.pop_back()
		c.queue_free()
	while _cows.size() < Game.cow_count:
		var c2: Node2D = LivestockScript.new()
		c2.setup("cow", decor.BARN_ROAM, decor.BARN_ROAM.get_center()
				+ Vector2(randf_range(-40, 40), randf_range(-20, 20)))
		add_child(c2)
		_cows.append(c2)
	while _sheeps.size() > Game.sheep_count:
		var s: Node2D = _sheeps.pop_back()
		s.queue_free()
	while _sheeps.size() < Game.sheep_count:
		var s2: Node2D = LivestockScript.new()
		s2.setup("sheep", decor.BARN_ROAM, decor.BARN_ROAM.get_center()
				+ Vector2(randf_range(-40, 40), randf_range(-20, 20)))
		add_child(s2)
		_sheeps.append(s2)


func _build_barn_products() -> void:
	for p in decor.MILK_SPOTS:
		var s := Sprite2D.new()
		s.texture = TEX_MILK
		s.position = p
		s.z_index = -2870
		s.visible = false
		add_child(s)
		_milk_sprites.append(s)
	for p in decor.WOOL_SPOTS:
		var s2 := Sprite2D.new()
		s2.texture = TEX_WOOL
		s2.position = p
		s2.z_index = -2870
		s2.visible = false
		add_child(s2)
		_wool_sprites.append(s2)
	_refresh_barn_products()


func _refresh_barn_products() -> void:
	for i in _milk_sprites.size():
		_milk_sprites[i].visible = i < Game.milk_ready
	for i in _wool_sprites.size():
		_wool_sprites[i].visible = i < Game.wool_ready


func _collect_barn() -> void:
	if Game.milk_ready + Game.wool_ready <= 0:
		if Game.cow_count + Game.sheep_count > 0:
			_toast("牛羊还没产出，明天再来收吧")
		else:
			_toast("畜棚还空着：商店可买奶牛（2500g）或绵羊（2000g）")
		return
	if Game.milk_ready > 0:
		Game.add_item("milk", Game.milk_ready)
		Game.total_milk += Game.milk_ready
		Game.add_xp("gather", 5 * Game.milk_ready)
		_float_text("+%d 牛奶" % Game.milk_ready, decor.BARN_POS + Vector2(-32, -46), Color(0.95, 0.97, 1))
	if Game.wool_ready > 0:
		Game.add_item("wool", Game.wool_ready)
		Game.total_wool += Game.wool_ready
		Game.add_xp("gather", 5 * Game.wool_ready)
		_float_text("+%d 羊毛" % Game.wool_ready, decor.BARN_POS + Vector2(32, -46), Color(1, 0.98, 0.9))
	var nm := Game.milk_ready
	var nw := Game.wool_ready
	Game.milk_ready = 0
	Game.wool_ready = 0
	_refresh_barn_products()
	player.pop()
	Sfx.play("pick")
	_toast("收好了 %d 瓶牛奶、%d 团羊毛！奶酪机可把牛奶变奶酪" % [nm, nw])


func _upgrade_rod() -> void:
	if Net.is_guest():
		Net.send({t = "intent", k = "buy", d = {"id": "rod"}})
		return
	if Game.rod_lv >= 2:
		return
	if Game.gold < Game.ROD_UP_COST:
		_toast("金币不足！")
		return
	if Game.items.get("copper", 0) < Game.ROD_UP_ORE:
		_toast("铜矿不够！去东侧矿洞敲 %d 块铜矿" % Game.ROD_UP_ORE)
		return
	Game.add_gold(-Game.ROD_UP_COST)
	Game.add_item("copper", -Game.ROD_UP_ORE)
	Game.rod_lv = 2
	Sfx.play("coin")
	_toast("鱼竿升级为铜钓竿！收线更稳，月光鱼/雨鱼/鱼王出现率翻倍")


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
	_dex_panel.offset_top = -330.0
	_dex_panel.offset_right = 290.0
	_dex_panel.offset_bottom = 330.0
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
				f.name, Game.caught_fish[id], f.sell, _fish_hint(f)]
			_dex_fish_labels[id].add_theme_color_override("font_color",
					Color(1, 0.85, 0.25) if f.get("legend", false) else Color(1, 0.98, 0.92))
		else:
			_dex_fish_labels[id].text = "？？？　尚未钓到%s" % _fish_hint(f)
			_dex_fish_labels[id].add_theme_color_override("font_color",
					Color(0.85, 0.65, 0.2) if f.get("legend", false) else Color(0.6, 0.58, 0.52))
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
	help_panel.offset_left = -455.0
	help_panel.offset_top = -330.0
	help_panel.offset_right = 455.0
	help_panel.offset_bottom = 330.0
	help_panel.visible = false
	$UI.add_child(help_panel)
	# 双栏布局：左右两列各 6 个分区，容纳 12 块玩法说明
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	help_panel.add_child(hb)
	var col_l := VBoxContainer.new()
	col_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_l.add_theme_constant_override("separation", 3)
	var col_r := VBoxContainer.new()
	col_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_r.add_theme_constant_override("separation", 3)
	hb.add_child(col_l)
	hb.add_child(col_r)
	var title := _mk_label("《星露谷Like》玩法说明", 21)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col_l.add_child(title)
	_help_section(col_l, "基础操作", [
		"WASD / 方向键 移动　　空格 / 鼠标左键 使用工具　　E 互动",
		"1-0 切换工具　　I 背包　　C 制作　　V 建造　　H 帮助　　Esc 设置 / 关闭　　F5 存档 / F9 读档　　M 音乐",
		"J 收获 / K 浇水 / F 开垦 / P 种植：默认玩家附近 3×3，按 G 切换全田",
		"R 花钱传送（每次 200g）",
		"Tab 小地图放大缩小（也能直接点小地图）　　T 和联机好友打字聊天",
	])
	_help_section(col_l, "种田流程", [
		"1 锄头开垦 → 3~6/9/0 播种 → 2 浇水 → 每天浇水才生长 → 成熟后空格收获",
		"首日跟着屏幕左侧「新手引导」做：锄地→浇水→播种→收获→卖货，完成奖 200g + 种子",
		"玉米/蓝莓收获后不拔根，过几天会再次结果；蓝莓一次结两颗",
		"对着货摊按 E 开商店：买种子、卖作物和鱼、升级工具",
	])
	_help_section(col_l, "四季轮作（新增）", [
		"每季 14 天轮换春夏秋冬：春萝卜土豆草莓 / 夏草莓玉米蓝莓 / 秋南瓜玉米蓝莓",
		"冬季休耕不能播种（已种的继续长），改为钓鱼、挖矿、加工与节日为主",
		"商店可建温室（东侧玻璃房）：温室内无视季节，冬天也能种任何作物",
		"换季地面与树木随之变色，冬天下雪；雨天自动浇灌农田、鱼更容易上钩",
	])
	_help_section(col_l, "钓鱼（7 鱼竿）", [
		"池塘边空格甩竿 → 浮漂变红瞬间再按空格提竿",
		"光标进入绿区时按空格（手机上点「用」）算命中，命中 3 次、失误 3 次内就能拉上来；鱼王需命中 5 次",
		"虹鳟只在 18:00 后，月光鱼 20:00 后、雨鱼雨天；雨天鱼更容易上钩",
		"商店可升铜钓竿（1800g+铜x5）：绿区更大、光标更慢，稀有鱼出现率翻倍",
		"传说鱼王上钩时绿区很窄（价值 1200g）；12% 概率钓上宝箱",
	])
	_help_section(col_l, "采集与制作（8 斧镐 / C 制作）", [
		"8 斧镐对着树按空格就能砍倒：得木材并留下树桩（砍树状态随存档保存）",
		"敲石头得石料、敲树枝得木材，北边野莓丛按 E 采摘野莓，每天会补充刷新",
		"洒水器浇四邻格；高级洒水器（铁锭造）浇 3x3；速效肥让作物立刻长一节",
		"制作后移动到目标格子按空格放置，Esc 取消",
	])
	_help_section(col_l, "地图与三区（轻扩图）", [
		"西侧森林采集区：野莓、蘑菇、倒木与矿岩更密集，前期攒材料就去这儿",
		"东侧河岸：整条河都能甩竿，沿石板小径走到木栈道上钓鱼最稳",
		"无限地图：核心农场四周不再封边，越过边界后自动生成新地形（边走边加载、走远即卸载）",
		"Tab 放大后小地图跟随玩家：深绿=森林、蓝色=河流，玩家白点带描边",
	])
	_help_section(col_l, "矿洞挖矿与熔炉（新增）", [
		"东侧矿洞区每天刷新矿岩：8 斧镐敲击，可得铜矿/铁矿/宝石",
		"C 造熔炉（石8木2）：放矿隔夜铸锭；金币+矿可升铜→铁→金锄壶（3x3/5x5/7x7）",
	])
	_help_section(col_r, "烹饪料理（新增）", [
		"C 制作灶台（石6木4）放到农田，对灶台按 E 打开烹饪面板",
		"沙拉/浓汤/甜点吃下大量回体力，也能卖钱，熬夜赶工必备",
	])
	_help_section(col_r, "送礼与好感（新增）", [
		"罗莎在花田、老本在集市散步，靠近按 E 打开送礼面板",
		"作物/鱼/矿石/产品/料理都能送，好感 = 售价的 1/10（最高 +8），每天 2 份",
		"好感达 20/40/60/80 首次回赠：金币/种子/宝石/挚友大礼；聊天每天一次 +10",
	])
	_help_section(col_r, "加工产业链（新增）", [
		"C 制作蛋黄酱机/食品加工机/灶台/熔炉/奶酪机，放到农田格子上",
		"对着机器按 E 放入原料，隔天机器亮金点再按 E 收成品",
		"蛋→蛋黄酱　南瓜→派；矿→铜/铁锭　牛奶→奶酪，售价更高",
	])
	_help_section(col_r, "宠物与节日（新增）", [
		"商店领养小猫/小狗（500g），按 E 摸头 +30 心情；再建个宠物窝（800g）就能把它们安放在窝边",
		"每 7 天一次节日：7 日钓鱼大赛（3 条奖 300g）、14 日丰收祭（5 株奖 400g）",
	])
	_help_section(col_r, "建筑与矿洞（新增）", [
		"V 打开建造面板：小屋仓库（1200g+木20）、矿洞入口（1500g+木30），造在农舍东侧 4 个建筑位",
		"走到建筑门口按 E：小屋进仓库界面（背包 ↔ 仓库存取，最多 8 种）；矿洞入口直接进地下矿洞场景（另一张地图）",
		"矿洞里 8 斧镐敲矿岩（每下 4 体力），挖掉六成梯子出现，走过去按 E 下一层；踩入口梯子按 E 回地面",
	])
	_help_section(col_r, "订单与养殖", [
		"货摊旁任务板按 E 接订单：每天 3 张，交作物/鱼/材料得金币与好感",
		"养鸡 800g/只（最多4）每天下蛋；奶牛 2500g、绵羊 2000g 住畜棚产奶产毛",
		"七天阶段目标显示在左上（没做完的会一直保留），按 Y 看全部 7 条清单",
		"目标不会过期：隔几天再补做也算，达成后自动发金币与对应季节种子",
		"B 打开收集包：交作物/鱼/矿石/牧产换金币 + 永久体力上限",
		"每天起床会弹「农场小报」：天气、当季作物、订单与节日提醒；Esc/空格关闭",
	])
	_help_section(col_r, "图鉴·技能·存档（G）", [
		"按 G 打开面板：技能等级、6 种鱼类图鉴（含鱼王）、宝箱与成就进度",
		"收获/钓鱼/采集/订单攒经验，每 100 点升 1 级体力上限 +10",
		"家门口按 E 睡觉：回满体力进入次日并自动存档（F5/F9 手动存读档）",
	])
	var close_l := _mk_label("按 H / E / Esc 关闭", 13)
	close_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col_r.add_child(close_l)


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


# ---------- 每日农场小报 ----------

## 起床小报面板：天气 / 当季作物 / 订单 / 节日 / 七日目标 / 一句建议
func _build_daily() -> void:
	_daily_panel = PanelContainer.new()
	_daily_panel.anchor_left = 0.5
	_daily_panel.anchor_top = 0.5
	_daily_panel.anchor_right = 0.5
	_daily_panel.anchor_bottom = 0.5
	_daily_panel.offset_left = -300.0
	_daily_panel.offset_top = -152.0
	_daily_panel.offset_right = 300.0
	_daily_panel.offset_bottom = 152.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.08, 0.98)
	sb.border_color = Color(0.42, 0.33, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_daily_panel.add_theme_stylebox_override("panel", sb)
	_daily_panel.visible = false
	$UI.add_child(_daily_panel)
	_daily_vb = VBoxContainer.new()
	_daily_vb.add_theme_constant_override("separation", 8)
	_daily_panel.add_child(_daily_vb)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(560, 0)
	_daily_vb.add_child(pad)
	var title := _mk_label("农 场 小 报", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_daily_vb.add_child(title)
	_daily_vb.add_child(HSeparator.new())
	_daily_text = _mk_label("", 14)
	_daily_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_daily_text.custom_minimum_size = Vector2(560, 0)
	_daily_vb.add_child(_daily_text)
	var back := _mk_btn("开始今天（空格 / E）")
	back.custom_minimum_size = Vector2(0, 38)
	back.pressed.connect(func() -> void: _toggle_daily(false))
	_daily_vb.add_child(back)


func _toggle_daily(open: bool) -> void:
	_daily_open = open
	if _daily_panel != null:
		_daily_panel.visible = open
	if open:
		_refresh_daily()


func _refresh_daily() -> void:
	if _daily_text == null:
		return
	var lines: Array = []
	lines.append("第 %d 天 · %s季 %d/%d · %s" % [Game.day, Game.season_name(),
		Game.season_day(), Game.SEASON_DAYS, _weather_name()])
	# 天气与农事建议
	if weather == "rain":
		lines.append("今早下雨：露天农田已自动浇好，钓鱼更爱咬钩。")
	elif weather == "snow":
		lines.append("今天下雪：露天作物不长，温室里照常生长，也可以去矿洞。")
	else:
		lines.append("今天晴天：记得给作物浇水（K 一键浇全田）。")
	# 当季可种
	var crops: Array = []
	for id in Game.CROPS:
		if Game.can_plant(id):
			crops.append(Game.CROPS[id].name)
	lines.append("当季可种：" + ("、".join(crops) if not crops.is_empty() else "无（去温室）"))
	# 订单板
	var todo := 0
	var gold_sum := 0
	for o in _orders:
		if not bool(o.done):
			todo += 1
			gold_sum += int(o.gold) * int(o.n)
	if todo > 0:
		lines.append("订单板：还有 %d 张没交，全做完可得 %d 金币（牌子在货摊东侧）" % [todo, gold_sum])
	# 节日
	var fk := _fest_kind(Game.day)
	if fk != "":
		var cfg: Dictionary = FESTS[fk]
		lines.append("今天是%s：%s %d 个达标，睡前奖励 %d 金币！" % [
			cfg.name, cfg.unit, int(cfg.goal), int(cfg.reward)])
	# 七日目标：显示最早一条未完成的（过期也能补做，按 Y 看全部）
	if Game.goals_claimed.size() < Game.DAY_GOALS.size():
		for gd in Game.DAY_GOALS:
			if not Game.goals_claimed.has(int(gd.day)):
				lines.append("目标（第%d天·不会过期）：%s（进度 %d/%d，按 Y 看全部 7 条）" % [
					int(gd.day), String(gd.name), Game.goal_progress(String(gd.kind)), int(gd.n)])
				break
	# 一句建议（按当前状态给不同提示，防劝退）
	var tip := ""
	if Game.stamina < Game.max_stamina * 0.3:
		tip = "体力快见底了：早点回床睡觉，第二天会回满。"
	elif Game.seeds.get("parsnip", 0) + Game.seeds.get("potato", 0) == 0 and Game.guide_step < 2:
		tip = "没种子了？去货摊（东边）买，防风草最便宜。"
	elif not Game.greenhouse_built and Game.gold >= Game.GH_COST:
		tip = "金币够了！商店里可以买温室，冬天也能种菜。"
	else:
		tip = "有空按 B 看看收集包，交作物能永久提升体力上限。"
	lines.append("小建议：" + tip)
	_daily_text.text = "\n".join(lines)


# ---------- 设置面板 ----------

## 设置面板：音乐/音效开关与音量、触屏按钮、界面缩放、全屏、返回
func _build_settings() -> void:
	# 半透明黑色遮罩：压暗背后画面、挡住点击穿透（鼠标事件由它吸收）
	_settings_dim = ColorRect.new()
	_settings_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_dim.anchor_right = 1.0
	_settings_dim.anchor_bottom = 1.0
	_settings_dim.color = Color(0.04, 0.03, 0.02, 0.92)
	_settings_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_dim.visible = false
	$UI.add_child(_settings_dim)
	_settings_panel = PanelContainer.new()
	_settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_panel.anchor_left = 0.5
	_settings_panel.anchor_top = 0.5
	_settings_panel.anchor_right = 0.5
	_settings_panel.anchor_bottom = 0.5
	_settings_panel.offset_left = -250.0
	_settings_panel.offset_top = -290.0
	_settings_panel.offset_right = 250.0
	_settings_panel.offset_bottom = 290.0
	_settings_panel.visible = false
	# 实色底板：设置面板盖在压暗的场景/标题之上，避免下层文字透出来
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.1, 0.08, 0.98)
	sb.border_color = Color(0.36, 0.28, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_settings_panel.add_theme_stylebox_override("panel", sb)
	$UI.add_child(_settings_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 9)
	_settings_panel.add_child(vb)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(460, 0)
	vb.add_child(pad)
	var title := _mk_label("设 置", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	vb.add_child(HSeparator.new())
	# 音乐
	var row_m := _settings_row(vb, "音乐")
	_set_music_btn = _mk_btn("开启")
	_set_music_btn.custom_minimum_size = Vector2(110, 32)
	_set_music_btn.pressed.connect(_on_music_toggle)
	row_m.add_child(_set_music_btn)
	var pair_m := _settings_slider(vb, _on_music_volume)
	_set_music_slider = pair_m[0]
	_set_music_pct = pair_m[1]
	# 音效
	var row_s := _settings_row(vb, "音效")
	_set_sfx_btn = _mk_btn("开启")
	_set_sfx_btn.custom_minimum_size = Vector2(110, 32)
	_set_sfx_btn.pressed.connect(_on_sfx_toggle)
	row_s.add_child(_set_sfx_btn)
	var pair_s := _settings_slider(vb, _on_sfx_volume)
	_set_sfx_slider = pair_s[0]
	_set_sfx_pct = pair_s[1]
	vb.add_child(HSeparator.new())
	# 触屏按钮 / 界面缩放 / 全屏
	var row_t := _settings_row(vb, "触屏按钮")
	_set_touch_btn = _mk_btn("自动")
	_set_touch_btn.custom_minimum_size = Vector2(110, 32)
	_set_touch_btn.pressed.connect(_on_touch_cycle)
	row_t.add_child(_set_touch_btn)
	var row_c := _settings_row(vb, "界面缩放")
	_set_scale_btn = _mk_btn("100%")
	_set_scale_btn.custom_minimum_size = Vector2(110, 32)
	_set_scale_btn.pressed.connect(_on_scale_cycle)
	row_c.add_child(_set_scale_btn)
	var row_f := _settings_row(vb, "全屏显示")
	_set_fs_btn = _mk_btn("进入全屏")
	_set_fs_btn.custom_minimum_size = Vector2(110, 32)
	_set_fs_btn.pressed.connect(_on_fullscreen_toggle)
	row_f.add_child(_set_fs_btn)
	# 低配模式：关掉氛围粒子与萤火，移动端省电
	var row_p := _settings_row(vb, "低配模式")
	_set_perf_btn = _mk_btn("关闭")
	_set_perf_btn.custom_minimum_size = Vector2(110, 32)
	_set_perf_btn.pressed.connect(_on_perf_toggle)
	row_p.add_child(_set_perf_btn)
	vb.add_child(HSeparator.new())
	# 存档操作：保存 / 读取
	var row_sv := HBoxContainer.new()
	row_sv.add_theme_constant_override("separation", 10)
	vb.add_child(row_sv)
	var b_save := _mk_btn("保存进度（F5）")
	b_save.custom_minimum_size = Vector2(0, 36)
	b_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_save.pressed.connect(func() -> void: _do_save())
	row_sv.add_child(b_save)
	var b_load := _mk_btn("读取存档（F9）")
	b_load.custom_minimum_size = Vector2(0, 36)
	b_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_load.pressed.connect(func() -> void: _do_load())
	row_sv.add_child(b_load)
	# 新游戏 / 返回标题
	var row_ng := HBoxContainer.new()
	row_ng.add_theme_constant_override("separation", 10)
	vb.add_child(row_ng)
	_set_new_btn = _mk_btn("开始新游戏")
	_set_new_btn.custom_minimum_size = Vector2(0, 36)
	_set_new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_new_btn.pressed.connect(_settings_new_game)
	row_ng.add_child(_set_new_btn)
	var b_title := _mk_btn("返回标题画面")
	b_title.custom_minimum_size = Vector2(0, 36)
	b_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_title.pressed.connect(_settings_back_title)
	row_ng.add_child(b_title)
	var tip := _mk_label("Esc 随时打开或关闭设置 · 手机上触屏按钮会自动出现", 12)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.custom_minimum_size = Vector2(460, 0)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.modulate = Color(1, 1, 1, 0.66)
	vb.add_child(tip)
	var back := _mk_btn("返 回")
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func() -> void: _toggle_settings(false))
	vb.add_child(back)


## 一行设置项：左侧标题 + 右侧按钮（返回容器供调用方追加控件）
func _settings_row(vb: VBoxContainer, title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	vb.add_child(h)
	var l := _mk_label(title, 16)
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	return h


## 音量滑条 + 百分比文字，返回 [HSlider, Label]
func _settings_slider(vb: VBoxContainer, on_change: Callable) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	vb.add_child(h)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 5.0
	s.custom_minimum_size = Vector2(0, 22)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(s)
	var pct := _mk_label("100%", 13)
	pct.custom_minimum_size = Vector2(56, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pct)
	s.value_changed.connect(on_change)
	return [s, pct]


func _toggle_settings(open: bool) -> void:
	if open and not settings_open:
		# 打开前先收起其它面板（此刻 settings_open 仍为 false，_close_panels 不会误关自己）
		_close_panels()
	settings_open = open
	if _settings_dim != null:
		_settings_dim.visible = open
	if _settings_panel != null:
		_settings_panel.visible = open
	if open:
		_refresh_settings_ui()


## 低配模式：关掉氛围粒子/萤火/云影，落盘持久化
func _on_perf_toggle() -> void:
	_perf_low = not _perf_low
	Save.set_setting("perf_low", _perf_low)
	decor.set_low_perf(_perf_low)
	_refresh_settings_ui()
	_toast("低配模式已%s：氛围粒子与萤火%s" % [
		"开启" if _perf_low else "关闭", "已关闭" if _perf_low else "已恢复"])


## 设置里新建世界：先存好当前世界，再挑一个空存档位选角
func _settings_new_game() -> void:
	_toggle_settings(false)
	_autosave()
	var slot := _first_empty_slot()
	if slot < 0:
		_toast("6 个存档位都满了，先在存档页删掉一个世界")
		return
	_pending_slot = slot
	_open_hero_select("settings")


## 设置里返回标题：先自动存档，再回到开局面板
func _settings_back_title() -> void:
	_toggle_settings(false)
	_autosave()
	if _boot_panel == null:
		_build_boot()


## 把面板上的按钮/滑条状态刷成当前实际配置
func _refresh_settings_ui() -> void:
	if _settings_panel == null:
		return
	_set_music_btn.text = "关闭" if Music.muted else "开启"
	_set_sfx_btn.text = "开启" if _sfx_on() else "关闭"
	var mv := int(roundf(Music.volume * 100.0))
	var sv := int(roundf(float(Save.setting("sfx_vol", 1.0)) * 100.0))
	_set_music_slider.set_value_no_signal(mv)
	_set_music_pct.text = "%d%%" % mv
	_set_sfx_slider.set_value_no_signal(sv)
	_set_sfx_pct.text = "%d%%" % sv
	_set_touch_btn.text = _touch_label()
	_set_perf_btn.text = "开启" if _perf_low else "关闭"
	_set_new_btn.text = "新建世界（不影响已有存档）"
	_set_scale_btn.text = "%d%%" % int(roundf(float(Save.setting("ui_scale", 1.0)) * 100.0))
	var fs: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_set_fs_btn.text = "退出全屏" if fs else "进入全屏"


## 启动时把已保存的配置应用到各系统
func _apply_settings() -> void:
	Music.volume = clampf(float(Save.setting("music_vol", 1.0)), 0.0, 1.0)
	Music.set_muted(not bool(Save.setting("music_on", false)))
	Music.apply_volume()
	_sfx_apply()
	_apply_ui_scale()


## 音效：开关决定是否出声，滑条数值单独记住（关掉再开音量不丢）
func _sfx_on() -> bool:
	return bool(Save.setting("sfx_on", true))


func _sfx_apply() -> void:
	var v := clampf(float(Save.setting("sfx_vol", 1.0)), 0.0, 1.0)
	Sfx.volume = v if _sfx_on() else 0.0


func _on_music_toggle() -> void:
	var on := not bool(Save.setting("music_on", false))
	Save.set_setting("music_on", on)
	Music.set_muted(not on)
	_refresh_settings_ui()


func _on_music_volume(v: float) -> void:
	Music.volume = clampf(v / 100.0, 0.0, 1.0)
	Save.set_setting("music_vol", Music.volume)
	Music.apply_volume()
	_set_music_pct.text = "%d%%" % int(v)


func _on_sfx_toggle() -> void:
	var on := not _sfx_on()
	Save.set_setting("sfx_on", on)
	_sfx_apply()
	_refresh_settings_ui()
	if on:
		Sfx.play("coin", -8.0)  # 开启时给一声试听


func _on_sfx_volume(v: float) -> void:
	Save.set_setting("sfx_vol", clampf(v / 100.0, 0.0, 1.0))
	_sfx_apply()
	_set_sfx_pct.text = "%d%%" % int(v)
	Sfx.play("pick", -10.0)  # 拖动时试听（静音时 play 内部会直接返回）


func _touch_label() -> String:
	var mode := String(Save.setting("touch_buttons", "auto"))
	if mode == "on":
		return "强制开"
	if mode == "off":
		return "关闭"
	return "自动"


## 触屏按钮三态：自动（按设备检测）→ 强制开 → 关闭
func _on_touch_cycle() -> void:
	var cur := String(Save.setting("touch_buttons", "auto"))
	var next := "on" if cur == "auto" else ("off" if cur == "on" else "auto")
	Save.set_setting("touch_buttons", next)
	if _touch != null:
		_touch.refresh_mode()
	_refresh_settings_ui()


## 点物品栏格子直接切换工具（触屏点选 / 鼠标点选通用）
func _on_slot_gui_input(e: InputEvent, i: int) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) \
			or (e is InputEventScreenTouch and e.pressed):
		_switch_tool(TOOL_OF_SLOT[i])


## 界面缩放三档：100% → 115% → 130%（只放大 UI 层，世界画面不变）
func _on_scale_cycle() -> void:
	var cur := float(Save.setting("ui_scale", 1.0))
	var next := 1.15 if cur < 1.05 else (1.3 if cur < 1.25 else 1.0)
	Save.set_setting("ui_scale", next)
	_apply_ui_scale()
	_refresh_settings_ui()


func _apply_ui_scale() -> void:
	var s := clampf(float(Save.setting("ui_scale", 1.0)), 1.0, 1.3)
	var center := get_viewport().get_visible_rect().size * 0.5
	# CanvasLayer 以左上角为原点缩放，用 offset 把锚点挪到屏幕中心
	$UI.scale = Vector2(s, s)
	$UI.offset = center * (1.0 - s)


func _on_fullscreen_toggle() -> void:
	var fs: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var mode := DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(mode)
	_refresh_settings_ui()


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
	# 绿区：命中判定的目标带（在轨道内上下随机出现）
	_zone_rect = ColorRect.new()
	_zone_rect.color = Color(0.35, 0.95, 0.45, 0.33)
	_zone_rect.anchor_left = 0.5
	_zone_rect.anchor_top = 0.5
	_zone_rect.anchor_right = 0.5
	_zone_rect.anchor_bottom = 0.5
	_zone_rect.offset_left = -84.0
	_zone_rect.offset_top = -30.0
	_zone_rect.offset_right = -56.0
	_zone_rect.offset_bottom = 30.0
	_fish_root.add_child(_zone_rect)
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
	var tip := _mk_label("光标进绿区时按 空格 / 点击", 14)
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
	_fish_tip = tip


func _refresh_hud() -> void:
	gold_label.text = "金币 %d" % Game.gold
	var texts := [
		"1 %s" % ["锄头", "铜锄头", "铁锄头", "金锄头"][Game.hoe_level - 1],
		"2 %s" % ["水壶", "铜水壶", "铁水壶", "金水壶"][Game.can_level - 1],
		"3 防风草种 x%d" % Game.seeds.parsnip,
		"4 土豆种 x%d" % Game.seeds.potato,
		"5 草莓种 x%d" % Game.seeds.straw,
		"6 南瓜种 x%d" % Game.seeds.pumpkin,
		"9 玉米种 x%d" % Game.seeds.corn,
		"0 蓝莓种 x%d" % Game.seeds.blue,
		"7 %s" % ("铜钓竿" if Game.rod_lv >= 2 else "鱼竿"),
		"8 斧镐",
	]
	# 槽位顺序：1锄 2壶 3-6 春种 | 9玉米 0蓝莓 7鱼竿 8斧镐（与 TOOL_OF_SLOT 一致）
	for i in 10:
		var ti: int = TOOL_OF_SLOT[i]
		var active: bool = current_tool == ti
		_slot_labels[i].text = ("▶ " + texts[i]) if active else texts[i]
		_slot_panels[i].self_modulate = Color(1, 1, 0.62) if active else Color(1, 1, 1, 0.82)
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
		_hoe_btn.text = "铜锄 500g" if Game.hoe_level == 1 else \
				("铁锄 2200g+铜x5" if Game.hoe_level == 2 \
				else ("金锄 5000g+铁锭x3" if Game.hoe_level == 3 else "已满级"))
		_hoe_btn.disabled = Game.hoe_level >= 4
		_can_btn.text = "铜壶 500g" if Game.can_level == 1 else \
				("铁壶 2200g+铜x5" if Game.can_level == 2 \
				else ("金壶 5000g+铁锭x3" if Game.can_level == 3 else "已满级"))
		_can_btn.disabled = Game.can_level >= 4
	# 买鸡按钮
	if _chicken_btn:
		_chicken_btn.text = "买小鸡 %dg" % Game.CHICKEN_COST \
				if Game.chicken_count < Game.MAX_CHICKENS else "已住满"
		_chicken_btn.disabled = Game.chicken_count >= Game.MAX_CHICKENS
	# 牛羊与钓竿按钮
	if _cow_btn:
		_cow_btn.text = "买奶牛 %dg" % Game.COW_COST \
				if Game.cow_count < Game.MAX_COWS else "已住满"
		_cow_btn.disabled = Game.cow_count >= Game.MAX_COWS
	if _sheep_btn:
		_sheep_btn.text = "买绵羊 %dg" % Game.SHEEP_COST \
				if Game.sheep_count < Game.MAX_SHEEP else "已住满"
		_sheep_btn.disabled = Game.sheep_count >= Game.MAX_SHEEP
	if _rod_btn:
		_rod_btn.text = "铜钓竿 1800g+铜x5" if Game.rod_lv == 1 else "已满级"
		_rod_btn.disabled = Game.rod_lv >= 2
	# 温室建造按钮
	if _gh_btn:
		_gh_btn.text = "温室已建成" if Game.greenhouse_built \
				else "建温室 %dg+木%d+石%d" % [Game.GH_COST, Game.GH_WOOD, Game.GH_STONE]
		_gh_btn.disabled = Game.greenhouse_built
	# 领养宠物按钮（在 _build_shop 后才有）
	if not _pet_btns.is_empty():
		for pk in _pet_btns:
			var owned: bool = Game.pets.has(pk)
			(_pet_btns[pk] as Button).text = "已领养" if owned else "领养 %dg" % Game.PET_COST
			(_pet_btns[pk] as Button).disabled = owned
	# 宠物窝按钮
	if _pet_house_btn:
		_pet_house_btn.text = "宠物窝已建好" if Game.pet_house else "建窝 %dg" % Game.PET_HOUSE_COST
		_pet_house_btn.disabled = Game.pet_house
	# 制作面板行
	if _craft_gold:
		_craft_gold.text = "金币：%d　　材料靠斧镐(8)敲石头和树枝获得" % Game.gold
	for id in _craft_rows:
		var parts := []
		var cost: Dictionary = Game.RECIPES[id].cost
		for k in cost:
			parts.append("%s %d/%d" % [Game.MATERIALS[k].name, Game.items.get(k, 0), cost[k]])
		_craft_rows[id].text = "  ".join(parts)
	# 烹饪面板行
	for dish in _cook_rows:
		var dc: Dictionary = Game.DISHES[dish].cost
		var dp := []
		for k in dc:
			dp.append("%s %d/%d" % [_item_name(k), _stock_of(k), dc[k]])
		_cook_rows[dish].text = "  ".join(dp)
	for dish2 in _cook_eat_rows:
		var n: int = int(Game.items.get(dish2, 0))
		(_cook_eat_rows[dish2][0] as Label).text = "%s x%d" % [Game.DISHES[dish2].name, n]
		(_cook_eat_rows[dish2][1] as Button).disabled = n <= 0
	# 送礼面板行
	for gid in _gift_rows:
		var stock: int = _stock_of(gid)
		(_gift_rows[gid][0] as Label).text = "持有 x%d" % stock
		(_gift_rows[gid][1] as Button).disabled = stock <= 0
	# 收集包面板行
	if bundles_open:
		_refresh_bundles()


func _update_hint() -> void:
	var txt: String
	var touch: bool = _touch != null and bool(_touch._enabled)
	if in_mine:
		txt = _mine_hint()
	elif place_mode != "":
		txt = "走到目标格子点「用」放置（「设置」=取消）" if touch \
				else "移动到目标格子按空格放置（Esc 取消）"
	elif _near_villager() != null:
		txt = "按 E 给 %s 送礼物（每天 2 份）或聊天" % _near_villager().display_name
	elif player.position.distance_to(decor.BOARD_POS) < 70.0:
		txt = "按 E 查看订单任务板：完成订单得金币和好感"
	elif player.position.distance_to(decor.COOP_POS) < 80.0:
		if Game.eggs_ready > 0:
			txt = "鸡舍前有 %d 颗鸡蛋：按 E 捡起来" % Game.eggs_ready
		elif Game.chicken_count > 0:
			txt = "小鸡们正在散步，下蛋后按 E 来捡"
		else:
			txt = "鸡舍还空着：商店可买小鸡（800g）"
	elif player.position.distance_to(decor.BARN_POS) < 90.0:
		if Game.milk_ready + Game.wool_ready > 0:
			txt = "畜棚前有 %d 瓶牛奶、%d 团羊毛：按 E 收起来" % [Game.milk_ready, Game.wool_ready]
		elif Game.cow_count + Game.sheep_count > 0:
			txt = "牛羊们正在散步，产出后按 E 来收"
		else:
			txt = "畜棚还空着：商店可买奶牛（2500g）或绵羊（2000g）"
	elif player.position.distance_to(decor.SHOP_POS) < 90.0:
		txt = "按 E 打开商店"
	elif player.position.distance_to(decor.DOOR_POS) < 80.0:
		txt = "按 E 睡觉，回满体力进入下一天"
	elif _machine_near() != null:
		var m: Dictionary = _machine_near()
		var md: Dictionary = m.data
		if md.type == "stove":
			txt = "灶台：按 E 打开烹饪面板，做料理回体力也能卖钱"
		elif md.ready != "":
			txt = "%s做好了！按 E 收进背包" % Game.PRODUCTS[md.ready].name
		elif md.input != "":
			txt = "%s正在加工%s，明早完工" % [Game.RECIPES[md.type].name, _item_name(md.input)]
		else:
			txt = "按 E 往%s里放原料（%s）" % [Game.RECIPES[md.type].name, _machine_input_names(md.type)]
	elif Game.greenhouse_built and farm.GH_ZONE.grow(40.0).has_point(player.position):
		txt = "温室里无视季节：锄地(1) → 播种 → 浇水(2)，冬天也能种植"
	elif decor.MINE_ZONE.has_point(player.position):
		txt = "矿洞区：8 斧镐敲矿岩，可得铜矿/铁矿/宝石"
	elif _near_building() != null:
		var nb: Dictionary = _near_building()
		var nd: Dictionary = Game.BUILD_DEFS[nb.kind]
		txt = "按 E 进入%s%s" % [nd.name, "（仓库界面）" if nb.kind == "storehouse" else "（矿洞场景）"]
	elif gather.near_bush(player.position):
		txt = "野莓熟了：按 E 采摘，第二天会再结果"
	elif decor.near_water(player.position, 30.0):
		txt = "水边适合钓鱼：7 甩竿 · 咬钩后再按空格"
	elif decor.FOREST_RECT.has_point(player.position):
		txt = "西边森林：野莓按 E 采摘，草丛里有蘑菇与倒木可捡"
	elif _near_pet() != null:
		txt = "按 E 摸摸%s的头：心情 +30，每天一次" % _near_pet().pet_name
	elif _near_pet_house():
		var any_home := false
		for k in Game.pets:
			any_home = any_home or bool(Game.pets_home.get(k, false))
		txt = "按 E 把%s叫出窝 / 让它们回窝待命" % _pets_names() if not any_home \
				else "按 E 让%s从窝里出来继续跟随" % _pets_names()
	else:
		txt = "点物品栏换工具 · 「用」使用 · 「互动」E · 「菜单」里制作/存档" if touch \
				else "1-0 切换工具 · 空格/左键 使用 · C 制作 · E 互动 · H 帮助"
	if hint_label.text != txt:
		hint_label.text = txt


## 世界坐标飘字（+N 动作反馈）：上浮并淡出
func _float_text(txt: String, world_pos: Vector2, col: Color) -> void:
	# 联机：host 替 guest 执行动作时，把飘字同步给对方
	if Net.is_host() and _remote_exec:
		Net.send({t = "evt", ek = "float", txt = txt,
				p = [world_pos.x, world_pos.y], col = [col.r, col.g, col.b]})
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


## 鱼类咬钩条件提示（图鉴用）
func _fish_hint(f: Dictionary) -> String:
	if f.get("legend", false):
		return "　★ 传说之鱼！随时可能上钩（约 2%），钓上就是缘分"
	if f.get("dusk", false):
		return "　只在 20:00 后咬钩"
	if f.get("night", false):
		return "　只在 18:00 后咬钩"
	if f.get("rain", false):
		return "　只在雨天咬钩"
	return ""


func _toast(msg: String) -> void:
	# 联机：host 替 guest 执行动作或睡觉结算时，把提示同步给对方
	if Net.is_host() and (_remote_exec or sleeping):
		Net.send({t = "evt", ek = "toast", msg = msg})
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


# ---------- 小地图 / 好友方位 / 聊天 / 季节 ----------

## 右上角小地图 + 好友方位箭头 + 联机聊天记录与输入框
func _build_hud_extras() -> void:
	_minimap = MinimapScript.new()
	_minimap.main = self
	$UI.add_child(_minimap)
	_arrow = FriendArrowScript.new()
	_arrow.main = self
	$UI.add_child(_arrow)
	# 目标指引箭头（黄色，指向成熟作物 / 订单板 / 商店）
	_goal_arrow = GoalArrowScript.new()
	_goal_arrow.main = self
	$UI.add_child(_goal_arrow)
	_chat_log = VBoxContainer.new()
	_chat_log.anchor_top = 1.0
	_chat_log.anchor_bottom = 1.0
	_chat_log.offset_left = 20.0
	_chat_log.offset_top = -252.0
	_chat_log.offset_right = 540.0
	_chat_log.offset_bottom = -140.0
	_chat_log.alignment = BoxContainer.ALIGNMENT_END
	_chat_log.add_theme_constant_override("separation", 2)
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_chat_log)
	_chat_input = LineEdit.new()
	_chat_input.anchor_top = 1.0
	_chat_input.anchor_bottom = 1.0
	_chat_input.offset_left = 20.0
	_chat_input.offset_top = -132.0
	_chat_input.offset_right = 400.0
	_chat_input.offset_bottom = -94.0
	_chat_input.placeholder_text = "对好友说点什么，回车发送 / Esc 取消"
	_chat_input.max_length = 60
	_chat_input.add_theme_font_override("font", _ui_font)
	_chat_input.add_theme_font_size_override("font_size", 15)
	_chat_input.visible = false
	_chat_input.text_submitted.connect(_chat_send)
	$UI.add_child(_chat_input)

	# 主角主动技能按钮：底部中间、物品栏正上方（Q 键同效，冷却期间变灰）
	_skill_btn = _mk_btn("技能 Q")
	_skill_btn.anchor_left = 0.5
	_skill_btn.anchor_right = 0.5
	_skill_btn.anchor_top = 1.0
	_skill_btn.anchor_bottom = 1.0
	_skill_btn.offset_left = -38.0
	_skill_btn.offset_right = 38.0
	_skill_btn.offset_top = -152.0
	_skill_btn.offset_bottom = -94.0
	_skill_btn.focus_mode = Control.FOCUS_NONE
	_skill_btn.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	_skill_btn.pressed.connect(_cast_skill)
	$UI.add_child(_skill_btn)


## 打开聊天输入（T 键）；输入期间停掉主角移动，避免边走边打字
func _chat_begin() -> void:
	if _chat_open or sleeping:
		return
	if not Net.is_online():
		_toast("单人模式下没法聊天，先建房或加入好友的房间")
		return
	_chat_open = true
	_chat_input.text = ""
	_chat_input.visible = true
	_chat_input.grab_focus()
	player.set_physics_process(false)


func _chat_close() -> void:
	if not _chat_open:
		return
	_chat_open = false
	_chat_input.visible = false
	_chat_input.release_focus()
	if not sleeping:
		player.set_physics_process(true)


## 回车发送：本地先上屏，再转发给对方
func _chat_send(text: String) -> void:
	var msg := text.strip_edges()
	_chat_close()
	if msg == "":
		return
	_add_chat_line("我：" + msg)
	Net.send({t = "chat", msg = msg})


## 聊天记录：最多留 5 条，9 秒后淡出自动清除
func _add_chat_line(txt: String) -> void:
	if _chat_log == null:
		return
	var lb := _mk_label(txt, 14)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.custom_minimum_size = Vector2(500, 0)
	_chat_log.add_child(lb)
	while _chat_log.get_child_count() > 5:
		var old := _chat_log.get_child(0)
		_chat_log.remove_child(old)
		old.queue_free()
	var tw := lb.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(lb, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lb.queue_free)


## 按季节给地面/地皮斑块染色：春常色、夏偏暖、秋偏橙、冬换成雪地图案
func _apply_season_tint() -> void:
	var g: Sprite2D = $Ground
	if _tex_ground_orig == null:  # 首次记录原贴图，切季时能换回
		_tex_ground_orig = g.texture
		for i in 4:
			_tex_patch_orig.append((get_node("Patch%d" % (i + 1)) as Sprite2D).texture)
	var sid := String(Game.season().id)
	var win := sid == "winter"
	var tint: Color = Color(1, 1, 1) if win else Game.season().tint
	g.texture = TEX_GRASS_SNOW if win else _tex_ground_orig
	g.modulate = tint
	for i in 4:
		var sp := get_node("Patch%d" % (i + 1)) as Sprite2D
		sp.texture = TEX_PATCH_SNOW[i] if win else _tex_patch_orig[i]
		sp.modulate = tint
	# 冬天地表细节（树/屋顶）微微泛冷白
	decor.modulate = Color(0.92, 0.96, 1.04) if win else Color(1, 1, 1)
	# 四季飘落物：春花瓣 / 秋落叶 / 冬雪
	decor.set_season(Game.season_index())
	# 无限地图的区块地面与树跟核心区同步换季
	chunks.set_season(win, tint, Color(0.92, 0.96, 1.04) if win else Color(1, 1, 1))


## 隔天天气：冬季可能下雪，其余季节 30% 下雨
func _roll_weather() -> void:
	if String(Game.season().id) == "winter":
		weather = "snow" if randf() < 0.4 else "sun"
	else:
		weather = "rain" if randf() < 0.3 else "sun"
	_apply_weather_visual()


## 天气粒子与显隐统一设置（雪天切 rain.gd 的雪花模式）
func _apply_weather_visual() -> void:
	_rain_node.visible = weather != "sun"
	_rain_node.mode = "snow" if weather == "snow" else "rain"


func _weather_name() -> String:
	match weather:
		"rain":
			return "雨"
		"snow":
			return "雪"
	return "晴"


# ---------- 联机：同步与意图 ----------

## 每帧联机计时：全量防抖 / host 周期全量 / 10Hz 快照与位置播报
func _net_tick(delta: float) -> void:
	if not Net.is_online():
		return
	if _full_t > 0.0:
		_full_t -= delta
		if _full_t <= 0.0:
			_net_full_now()
	if Net.is_host():
		_pf_t += delta
		if _pf_t >= 1.0:
			_pf_t = 0.0
			_net_full_now()
	_snap_t += delta
	if _snap_t < 0.1:
		return
	_snap_t = 0.0
	if Net.is_host():
		var ents := {}
		ents.c = _ents_pos(_chickens)
		ents.v = _ents_pos(_villagers)
		ents.p = _ents_pos(_pets)
		ents.w = _ents_pos(_cows)
		ents.s = _ents_pos(_sheeps)
		Net.send({t = "snap", p = [player.position.x, player.position.y,
				player._row(), int(player.sprite.flip_h)],
				time = time_min, w = weather, e = ents})
	elif Net.is_guest():
		Net.send({t = "pos", p = [player.position.x, player.position.y,
				player._row(), int(player.sprite.flip_h)]})


func _ents_pos(arr: Array) -> Array:
	var out: Array = []
	for n in arr:
		var nd := n as Node2D
		out.append([nd.position.x, nd.position.y])
	return out


## 立即推送全量状态给 guest（复用存档序列化）
func _net_full_now() -> void:
	if not Net.is_host():
		return
	_full_t = 0.0
	_pf_t = 0.0
	Net.send({t = "full", d = _save_payload()})


## 动作结算后小延迟推送全量（防抖合并连续动作）
func _net_full_soon() -> void:
	if Net.is_host() and _full_t <= 0.0:
		_full_t = 0.25


## 网络消息路由
func _on_net_msg(m: Dictionary) -> void:
	match String(m.get("t", "")):
		"pos":
			if Net.is_host():
				_update_shadow(m.get("p", []))
		"snap":
			if Net.is_guest():
				_apply_snap(m)
		"full":
			if Net.is_guest():
				var nd: Dictionary = m.get("d", {})
				var was_day := Game.day
				_apply_payload(nd)
				if _guest_sleeping and int(nd.get("day", was_day)) > was_day:
					# host 天亮结算完成（按天数前进判定，忽略睡前防抖全量）：
					# 黑屏淡出，恢复行走
					_guest_sleeping = false
					var tw := create_tween()
					tw.tween_property(fade, "color:a", 0.0, 0.7)
					tw.tween_callback(func() -> void:
						player.set_physics_process(true)
						sleeping = false)
		"intent":
			if Net.is_host():
				_apply_intent(String(m.get("k", "")), m.get("d", {}))
		"hello":
			if Net.is_host():
				_net_full_now()
		"evt":
			_apply_evt(m)
		"chat":
			_add_chat_line("好友：" + String(m.get("msg", "")))


## guest：应用 host 的 10Hz 轻量快照
func _apply_snap(m: Dictionary) -> void:
	_update_shadow(m.get("p", []))
	time_min = float(m.get("time", time_min))
	var w := String(m.get("w", weather))
	if w != weather:
		weather = w
		_apply_weather_visual()
	var e: Dictionary = m.get("e", {})
	_apply_ents(e.get("c"), _chickens)
	_apply_ents(e.get("v"), _villagers)
	_apply_ents(e.get("p"), _pets)
	_apply_ents(e.get("w"), _cows)
	_apply_ents(e.get("s"), _sheeps)


func _apply_ents(arr, nodes: Array) -> void:
	if arr == null:
		return
	for i in mini(arr.size(), nodes.size()):
		(nodes[i] as Node2D).position = Vector2(float(arr[i][0]), float(arr[i][1]))


func _update_shadow(p: Array) -> void:
	if _shadow == null or p.is_empty():
		return
	_shadow_tp = Vector2(float(p[0]), float(p[1]))
	if _shadow.position.distance_to(_shadow_tp) > 260.0:  # 瞬移（换场景/睡觉）时直接对齐
		_shadow.position = _shadow_tp
	_shadow.z_index = int((_shadow_tp.y + 22.0) / 4.0)  # 好友影子同样按脚底 y 排序
	var spr: Sprite2D = _shadow.get_node("Spr")
	spr.frame_coords = Vector2i(0, int(p[2]))
	spr.flip_h = bool(p[3])


## 创建对方玩家影子精灵（复制主角精灵表）
func _make_shadow() -> void:
	if _shadow != null:
		return
	_shadow = Node2D.new()
	_shadow.z_index = player.z_index
	var spr := Sprite2D.new()
	spr.name = "Spr"
	spr.texture = player.sprite.texture
	spr.hframes = player.sprite.hframes
	spr.vframes = player.sprite.vframes
	spr.position = player.sprite.position
	spr.scale = player.sprite.scale
	spr.offset = player.sprite.offset
	_shadow.add_child(spr)
	var lb := _mk_label("好友", 12)
	lb.size = Vector2(60, 14)
	lb.position = Vector2(-30, -42)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadow.add_child(lb)
	add_child(_shadow)


## guest：冻结世界实体（位置由主机快照驱动），只保留本地玩家与视觉层
func _freeze_entities_for_guest() -> void:
	for arr in [_villagers, _chickens, _cows, _sheeps, _pets]:
		for n in arr:
			(n as Node2D).process_mode = Node.PROCESS_MODE_DISABLED


## 断线回单人：解冻实体并移除影子
func _unfreeze_entities() -> void:
	for arr in [_villagers, _chickens, _cows, _sheeps, _pets]:
		for n in arr:
			(n as Node2D).process_mode = Node.PROCESS_MODE_INHERIT
	if _shadow != null:
		_shadow.queue_free()
		_shadow = null


## host：执行 guest 的动作意图（换位执行真实逻辑，再回推全量）
func _apply_intent(k: String, d: Dictionary) -> void:
	_remote_exec = true
	match k:
		"tool":
			var rp: Vector2 = player.position
			var rf: Vector2 = player.facing
			var rt: int = current_tool
			player.position = Vector2(float(d.pos[0]), float(d.pos[1]))
			player.facing = Vector2(float(d.fx), float(d.fy))
			current_tool = int(d.tool)
			_use_tool()
			player.position = rp
			player.facing = rf
			current_tool = rt
		"place":
			_place_at_cell(String(d.mode), Vector2i(int(d.cx), int(d.cy)))
		"berry":
			var rp2: Vector2 = player.position
			player.position = Vector2(float(d.pos[0]), float(d.pos[1]))
			if gather.pick_berry(player.position) > 0:
				Game.add_xp("gather", 4)
			player.position = rp2
		"eggs":
			_collect_eggs()
		"barn":
			_collect_barn()
		"pet":
			for p in _pets:
				if (p as Node2D).kind == String(d.kind):
					_pet_pet(p)
					break
		"machine":
			var cell := Vector2i(int(d.cx), int(d.cy))
			if farm.machines.has(cell):
				_machine_interact({"cell": cell, "data": farm.machines[cell]})
		"sleep":
			_do_sleep(false)
		"buy":
			var id := String(d.id)
			if id == "chicken":
				_buy_chicken()
			elif id == "cow" or id == "sheep":
				_buy_livestock(id)
			elif id == "hoe" or id == "can":
				_upgrade(id)
			elif id == "rod":
				_upgrade_rod()
			elif id == "cat" or id == "dog":
				_adopt_pet(id)
			else:
				_buy(id)
		"sell":
			_sell(String(d.id), bool(d.all))
		"sell_item":
			_sell_item(_cat_of(String(d.id)), String(d.id), bool(d.all))
		"cook":
			_cook_dish(String(d.id))
		"eat":
			_eat_dish(String(d.id))
		"gift":
			_give_gift_to(String(d.who), String(d.id))
		"chat":
			var line := _chat_core(String(d.who))
			Net.send({t = "evt", ek = "dialog", who = String(d.who), line = line})
		"order":
			_deliver_order(int(d.i))
		"fish":
			# guest 本地打的钓鱼小游戏，主机补扣体力并入账
			Game.use_stamina(5.0)
			if String(d.kind) == "chest_g":
				_apply_chest_gold(int(d.g))
			elif String(d.kind) == "chest_i":
				_apply_chest_item(String(d.id), int(d.n))
			else:
				_apply_fish(String(d.id))
	# 在好友头顶飘一句动作说明，让房主直接看到好友在忙什么
	if _shadow != null:
		var verb := _intent_verb(k)
		if verb != "":
			_float_text(verb, _shadow.global_position + Vector2(0, -46),
					Color(0.55, 0.9, 1.0))
	_remote_exec = false
	_net_full_soon()


## guest 动作的中文短标签（host 侧飘字用）
func _intent_verb(k: String) -> String:
	match k:
		"tool":
			return "好友在干活"
		"place":
			return "好友放置了东西"
		"berry":
			return "好友摘了野莓"
		"eggs":
			return "好友收了鸡蛋"
		"barn":
			return "好友收了奶/毛"
		"pet":
			return "好友摸了摸宠物"
		"machine":
			return "好友用了加工机"
		"sleep":
			return "好友去睡觉了"
		"buy":
			return "好友买了东西"
		"sell", "sell_item":
			return "好友卖出了东西"
		"cook":
			return "好友做了料理"
		"eat":
			return "好友吃了料理"
		"gift":
			return "好友送出了礼物"
		"chat":
			return "好友在聊天"
		"order":
			return "好友交付了订单"
		"fish":
			return "好友钓到了鱼"
	return ""


## 物品所属出售分类（联机 sell_item 意图重建 cat 字典用）
func _cat_of(id: String) -> Dictionary:
	if Game.FISH.has(id):
		return Game.FISH
	if Game.PRODUCTS.has(id):
		return Game.PRODUCTS
	if Game.DISHES.has(id):
		return Game.DISHES
	return Game.MATERIALS


## guest：应用 host 转发来的表现事件（提示 / 飘字 / 村民对话）
func _apply_evt(m: Dictionary) -> void:
	match String(m.get("ek", "")):
		"toast":
			_toast(String(m.msg))
		"float":
			_float_text(String(m.txt),
					Vector2(float(m.p[0]), float(m.p[1])),
					Color(float(m.col[0]), float(m.col[1]), float(m.col[2])))
		"dialog":
			var who := String(m.who)
			for v in _villagers:
				if _villager_id_of(v) == who:
					_dialog_villager = v
					break
			_dialog_name.text = "%s · 好感 %d" % [
				_villager_name(who), int(Game.friends.get(who, 0))]
			_dialog_text.text = String(m.line)
			_toggle_dialog(true)


func _villager_name(id: String) -> String:
	for cfg in VILLAGERS:
		if cfg.id == id:
			return cfg.name
	return id


# ---------- 标题画面：继续 / 新游戏 / 建房 / 加入 ----------

func _build_boot() -> void:
	get_tree().paused = true
	_boot_panel = PanelContainer.new()
	_boot_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_boot_panel.anchor_left = 0.5
	_boot_panel.anchor_top = 0.5
	_boot_panel.anchor_right = 0.5
	_boot_panel.anchor_bottom = 0.5
	_boot_panel.offset_left = -290.0
	_boot_panel.offset_top = -238.0
	_boot_panel.offset_right = 290.0
	_boot_panel.offset_bottom = 238.0
	$UI.add_child(_boot_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 9)
	_boot_panel.add_child(vb)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(540, 0)
	vb.add_child(pad)
	# 标题
	var title := _mk_label("像 素 农 场", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _mk_label("四季流转 · 双人联机", 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.8)
	vb.add_child(sub)
	var hr := HSeparator.new()
	vb.add_child(hr)
	# 存档信息
	_boot_status = _mk_label(_boot_info_text(), 13)
	_boot_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boot_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boot_status.custom_minimum_size = Vector2(540, 0)
	vb.add_child(_boot_status)
	var b_solo := _mk_btn("开始游戏（选择世界）")
	b_solo.custom_minimum_size = Vector2(0, 40)
	b_solo.pressed.connect(_open_save_select)
	vb.add_child(b_solo)
	_boot_btn_new = _mk_btn("新游戏（新建一个世界）")
	_boot_btn_new.custom_minimum_size = Vector2(0, 36)
	_boot_btn_new.pressed.connect(_boot_new)
	vb.add_child(_boot_btn_new)
	var b_host := _mk_btn("建房联机（生成房间码给好友）")
	b_host.custom_minimum_size = Vector2(0, 40)
	b_host.pressed.connect(_boot_host)
	vb.add_child(b_host)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	_boot_input = LineEdit.new()
	_boot_input.placeholder_text = "好友的房间码"
	_boot_input.custom_minimum_size = Vector2(300, 40)
	_boot_input.max_length = 4
	_boot_input.add_theme_font_override("font", _ui_font)
	_boot_input.add_theme_font_size_override("font_size", 16)
	_boot_input.text_submitted.connect(func(_t: String) -> void: _boot_join())
	row.add_child(_boot_input)
	var b_join := _mk_btn("加入好友")
	b_join.custom_minimum_size = Vector2(230, 40)
	b_join.pressed.connect(_boot_join)
	row.add_child(b_join)
	var b_opt := _mk_btn("设置（音乐 / 音量 / 缩放 / 全屏）")
	b_opt.custom_minimum_size = Vector2(0, 36)
	b_opt.pressed.connect(func() -> void: _toggle_settings(true))
	vb.add_child(b_opt)
	var tip := _mk_label("H 帮助 · Tab 地图 · T 聊天 · Esc 设置 · 联机需中继服务器（网页版用 ?ws= 指定）", 12)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(540, 0)
	tip.modulate = Color(1, 1, 1, 0.65)
	vb.add_child(tip)
	Net.room_created.connect(_on_room_created)
	Net.joined_room.connect(_on_joined_room)
	# 标题画面期间先收起小地图与好友箭头，进游戏后再显示
	_minimap.visible = false
	_arrow.visible = false


## 新游戏：挑一个空存档位，再选角（不影响已有世界）
func _boot_new() -> void:
	var slot := _first_empty_slot()
	if slot < 0:
		_toast("6 个存档位都满了，先在存档列表里删掉一个世界")
		_open_save_select()
		return
	_pending_slot = slot
	_open_hero_select("boot")


## 第一个空存档位；全满返回 -1
func _first_empty_slot() -> int:
	for i in Save.SLOT_COUNT:
		if not Save.has_slot(i):
			return i
	return -1


## 从零开始：清存档 + 全局状态复位 + 世界重建（当前 Game.hero_id 决定主角）
func _start_new_game() -> void:
	Save.write("")
	# 新世界：如果此刻还在矿洞里，先回地面再重置
	if in_mine:
		_leave_mine(true, false)
	Game.reset_state()
	# 阿蓝被动：体力上限 +20（reset_state 已回到 100）
	if Game.hero_kind() == "stamina":
		Game.max_stamina += 20.0
		Game.stamina = Game.max_stamina
	player.set_hero(Game.hero_id)
	farm.restore_from({})
	mine.restore([])
	mine.spawn_daily()
	gather.spawn_daily()
	time_min = float(DAY_START_MIN)
	_roll_weather()
	_refresh_eggs()
	_sync_chickens()
	_sync_livestock()
	_sync_pets()
	_refresh_barn_products()
	_gen_orders()
	_fest_count = 0
	_talked_today.clear()
	_petted_today.clear()
	_gifted_today.clear()
	_last_season = Game.season_index()
	_apply_season_tint()
	decor.set_greenhouse(false)
	decor.restore_cut([])  # 新世界：所有树都长回来
	_refresh_guide()
	_goal_refresh()
	_refresh_festival()
	_refresh_hud()
	player.position = decor.DOOR_POS + Vector2(0, 44)


# ---------- 选角：4 位主角（被动特长 + 主动技能） ----------

## 打开选角面板：标题页「新建世界」/ 存档页空位 / 设置里新建都会走这里
func _open_hero_select(origin := "boot") -> void:
	if _hero_panel != null:
		return
	get_tree().paused = true
	_hero_back = origin
	if origin == "save":
		if _save_panel != null:
			_save_panel.visible = false
		if _save_dim != null:
			_save_dim.visible = false
	elif _boot_panel != null:
		_boot_panel.visible = false
	# 半透明遮罩：压暗身后的农场与 HUD，让选角页成为视觉焦点
	_hero_dim = ColorRect.new()
	_hero_dim.color = Color(0.02, 0.03, 0.05, 0.62)
	_hero_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_hero_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(_hero_dim)
	_hero_panel = PanelContainer.new()
	_hero_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_hero_panel.anchor_left = 0.5
	_hero_panel.anchor_top = 0.5
	_hero_panel.anchor_right = 0.5
	_hero_panel.anchor_bottom = 0.5
	_hero_panel.offset_left = -500.0
	_hero_panel.offset_top = -280.0
	_hero_panel.offset_right = 500.0
	_hero_panel.offset_bottom = 280.0
	_hero_panel.add_theme_stylebox_override("panel", _modal_style())
	$UI.add_child(_hero_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_hero_panel.add_child(vb)
	var title := _mk_label("选 择 主 角", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _mk_label("每人一套被动特长 + 一个主动技能（Q 键 / 右下技能按钮，耗体力、有冷却）", 13)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.78)
	vb.add_child(sub)
	var hr := HSeparator.new()
	hr.modulate = Color(1, 1, 1, 0.25)
	vb.add_child(hr)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(row)
	for i in Game.HEROES.size():
		row.add_child(_hero_card(i))
	var back := _mk_btn("← 返回")
	back.custom_minimum_size = Vector2(220, 32)
	back.add_theme_font_size_override("font_size", 13)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_hero_select)
	vb.add_child(back)


## 角色卡片底框：角色主色的细边框，鼠标悬停时加亮
func _hero_card_style(c: Color, hot: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.17, 0.22, 0.96) if not hot else Color(0.19, 0.23, 0.3, 0.98)
	sb.border_color = Color(c.r, c.g, c.b, 1.0 if hot else 0.55)
	sb.set_border_width_all(2 if hot else 1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	return sb


## 单张角色卡：顶部色条 + 站立立绘 + 名字 + 被动 / 主动两段说明 + 选择按钮
func _hero_card(i: int) -> Control:
	var h: Dictionary = Game.HEROES[i]
	var c: Color = h.color
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(214, 0)
	card.add_theme_stylebox_override("panel", _hero_card_style(c, false))
	card.mouse_entered.connect(func() -> void:
		card.add_theme_stylebox_override("panel", _hero_card_style(c, true)))
	card.mouse_exited.connect(func() -> void:
		card.add_theme_stylebox_override("panel", _hero_card_style(c, false)))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	card.add_child(vb)
	# 顶部角色主色条：一眼区分四张卡
	var bar := ColorRect.new()
	bar.color = Color(c.r, c.g, c.b, 0.9)
	bar.custom_minimum_size = Vector2(0, 3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(bar)
	# 立绘：32x64 单元 3 倍最近邻放大（96x192），像素不发糊
	var at := AtlasTexture.new()
	at.atlas = load(String(h.tex))
	at.region = Rect2(0, 0, 32, 64)
	var pic := TextureRect.new()
	pic.texture = at
	pic.custom_minimum_size = Vector2(96, 192)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(pic)
	var nm := _mk_label("%s · %s" % [h.name, h.title], 18)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_color_override("font_color", c)
	vb.add_child(nm)
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.18)
	vb.add_child(sep)
	# 被动 / 主动两段：标题行用角色色，描述用次级灰白；耗体力与冷却单独一行小字
	var hp := _mk_label("被动 · %s" % h.passive_name, 13)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_theme_color_override("font_color", Color(0.82, 0.87, 0.95))
	vb.add_child(hp)
	var dp := _mk_label(String(h.passive_text), 11)
	dp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dp.custom_minimum_size = Vector2(196, 0)
	dp.modulate = Color(1, 1, 1, 0.72)
	vb.add_child(dp)
	var ha := _mk_label("主动 · %s（Q）" % h.skill_name, 13)
	ha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ha.add_theme_color_override("font_color", c)
	vb.add_child(ha)
	var da := _mk_label(String(h.skill_text), 11)
	da.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	da.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	da.custom_minimum_size = Vector2(196, 0)
	da.modulate = Color(1, 1, 1, 0.72)
	vb.add_child(da)
	var dc := _mk_label("耗 %.0f 体力 · 冷却 %.0fs" % [h.cost, h.cd], 10)
	dc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dc.modulate = Color(1, 1, 1, 0.5)
	vb.add_child(dc)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	var b := _mk_btn("选 %s" % h.name)
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_stylebox_override("normal", _hero_btn_style(c, false))
	b.add_theme_stylebox_override("hover", _hero_btn_style(c, true))
	b.add_theme_stylebox_override("pressed", _hero_btn_style(c, true))
	b.pressed.connect(func() -> void: _pick_hero(i))
	vb.add_child(b)
	return card


## 选择按钮：用角色主色铺底，悬停略亮
func _hero_btn_style(c: Color, hot: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c.r, c.g, c.b, 0.92 if hot else 0.78)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb



## 选定主角：切到预选存档位，清档开局并立刻写一份初始存档
func _pick_hero(i: int) -> void:
	Game.hero_id = i
	if _pending_slot >= 0:
		Save.current = _pending_slot
		Save.set_setting("last_slot", _pending_slot)
	_pending_slot = -1
	_free_hero_select()
	if _save_panel != null:
		_close_save_select(false)
	_start_new_game()
	_autosave()  # 让新世界立即出现在存档列表里
	_boot_finish(false)
	Sfx.play("coin")
	_toast("%s出发！被动「%s」，按 Q 释放「%s」" % [
		Game.hero().name, Game.hero().passive_name, Game.hero().skill_name])


## 直接销毁选角面板（不恢复来源面板）
func _free_hero_select() -> void:
	if _hero_panel != null:
		_hero_panel.queue_free()
		_hero_panel = null
	if _hero_dim != null:
		_hero_dim.queue_free()
		_hero_dim = null


## 取消选角：回到来源面板（标题页 / 存档列表），设置里则继续当前游戏
func _close_hero_select() -> void:
	_free_hero_select()
	_pending_slot = -1
	if _hero_back == "save" and _save_panel != null:
		_save_panel.visible = true
		if _save_dim != null:
			_save_dim.visible = true
		_refresh_save_list()
	elif _boot_panel != null:
		_boot_panel.visible = true
		_boot_status.text = _boot_info_text()
	else:
		get_tree().paused = false


# ---------- 世界存档选择页 ----------

## 标题页信息行文案
func _boot_info_text() -> String:
	var used := Save.used_slots()
	if used == 0:
		return "还没有世界存档，新建一个世界开始吧"
	return "已有 %d 个世界存档（共 %d 个存档位）" % [used, Save.SLOT_COUNT]


## 存档选择面板：6 个世界存档位，可进入 / 删除 / 在空位新建
func _open_save_select() -> void:
	if _save_panel != null:
		return
	get_tree().paused = true
	if _boot_panel != null:
		_boot_panel.visible = false
	_save_dim = ColorRect.new()
	_save_dim.color = Color(0.02, 0.03, 0.05, 0.62)
	_save_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(_save_dim)
	_save_panel = PanelContainer.new()
	_save_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_panel.anchor_left = 0.5
	_save_panel.anchor_top = 0.5
	_save_panel.anchor_right = 0.5
	_save_panel.anchor_bottom = 0.5
	_save_panel.offset_left = -430.0
	_save_panel.offset_top = -272.0
	_save_panel.offset_right = 430.0
	_save_panel.offset_bottom = 272.0
	_save_panel.add_theme_stylebox_override("panel", _modal_style())
	$UI.add_child(_save_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_save_panel.add_child(vb)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(800, 0)
	vb.add_child(pad)
	var title := _mk_label("世 界 存 档", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _mk_label("共 %d 个存档位 · 进入一个世界继续，或在空位新建" % Save.SLOT_COUNT, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.72)
	vb.add_child(sub)
	var hr := HSeparator.new()
	hr.modulate = Color(1, 1, 1, 0.22)
	vb.add_child(hr)
	_save_list = VBoxContainer.new()
	_save_list.add_theme_constant_override("separation", 8)
	vb.add_child(_save_list)
	_refresh_save_list()
	var back := _mk_btn("← 返回标题页")
	back.custom_minimum_size = Vector2(220, 32)
	back.add_theme_font_size_override("font_size", 13)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: _close_save_select())
	vb.add_child(back)


## 重绘 6 个存档位卡片
func _refresh_save_list() -> void:
	if _save_list == null:
		return
	for c in _save_list.get_children():
		c.queue_free()
	for i in Save.SLOT_COUNT:
		_save_list.add_child(_save_slot_card(i))


## 单个存档位：左侧世界信息，右侧进入 / 删除（空位为新建）
func _save_slot_card(i: int) -> Control:
	var d := Save.slot_summary(i)
	var empty := d.is_empty()
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.16, 0.21, 0.95)
	sb.border_color = Color(0.42, 0.48, 0.58, 0.5 if empty else 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(0, 62)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	if empty:
		var t0 := _mk_label("%d 号世界 · 空白" % (i + 1), 17)
		t0.modulate = Color(1, 1, 1, 0.55)
		info.add_child(t0)
		var t1 := _mk_label("还没有世界，点右侧「新建世界」开始", 12)
		t1.modulate = Color(1, 1, 1, 0.45)
		info.add_child(t1)
		var b_new := _mk_btn("新建世界")
		b_new.custom_minimum_size = Vector2(120, 34)
		b_new.add_theme_font_size_override("font_size", 14)
		b_new.pressed.connect(func() -> void: _new_slot(i))
		hb.add_child(b_new)
		return card
	var hid := clampi(int(d.get("hero_id", 0)), 0, Game.HEROES.size() - 1)
	var hero: Dictionary = Game.HEROES[hid]
	var c: Color = hero.color
	var t := _mk_label("%d 号世界 · %s" % [i + 1, hero.name], 17)
	t.add_theme_color_override("font_color", c)
	info.add_child(t)
	var line := _mk_label("%s · %d 金币" % [_slot_date_text(d), int(d.get("gold", 0))], 12)
	line.modulate = Color(1, 1, 1, 0.8)
	info.add_child(line)
	var saved := int(d.get("saved_at", 0))
	var tl := "上次保存：%s" % _fmt_time(saved) if saved > 0 else "尚未保存"
	var t2 := _mk_label(tl, 11)
	t2.modulate = Color(1, 1, 1, 0.5)
	info.add_child(t2)
	var b_in := _mk_btn("进入")
	b_in.custom_minimum_size = Vector2(84, 34)
	b_in.add_theme_font_size_override("font_size", 14)
	b_in.add_theme_stylebox_override("normal", _hero_btn_style(c, false))
	b_in.add_theme_stylebox_override("hover", _hero_btn_style(c, true))
	b_in.add_theme_stylebox_override("pressed", _hero_btn_style(c, true))
	b_in.pressed.connect(func() -> void: _enter_slot(i))
	hb.add_child(b_in)
	var b_del := _mk_btn("确认删除？" if _save_confirm == i else "删除")
	b_del.custom_minimum_size = Vector2(100, 34)
	b_del.add_theme_font_size_override("font_size", 13)
	b_del.pressed.connect(func() -> void: _delete_slot(i))
	hb.add_child(b_del)
	return card


## 存档日期 → 「第 12 天 · 春季第 12 天」
func _slot_date_text(d: Dictionary) -> String:
	var day := int(d.get("day", 1))
	var idx := int(floor((day - 1) / float(Game.SEASON_DAYS))) % Game.SEASONS.size()
	var sd := (day - 1) % Game.SEASON_DAYS + 1
	return "第 %d 天 · %s季第 %d 天" % [day, String(Game.SEASONS[idx].name), sd]


## 时间戳 → 「10-30 21:05」
func _fmt_time(unix: int) -> String:
	if unix <= 0:
		return "—"
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d-%02d %02d:%02d" % [int(dt.month), int(dt.day), int(dt.hour), int(dt.minute)]


## 进入指定世界：切槽、读档、收掉面板开局
func _enter_slot(i: int) -> void:
	Save.current = i
	Save.set_setting("last_slot", i)
	_save_confirm = -1
	_close_save_select(false)
	if not _do_load(false):
		_toast("这个存档读取失败了……")
		get_tree().paused = false
		return
	_last_season = Game.season_index()
	_apply_season_tint()
	chunks.update_around(player.position, true)
	_boot_finish(false)
	Sfx.play("pick")
	_toast("已进入 %d 号世界 · 第 %d 天 · %s" % [i + 1, Game.day, Game.hero().name])


## 空位新建：记下预选槽，进入选角
func _new_slot(i: int) -> void:
	_pending_slot = i
	_save_confirm = -1
	_open_hero_select("save")


## 删除世界：首次点变「确认删除？」，再点才真删
func _delete_slot(i: int) -> void:
	if _save_confirm != i:
		_save_confirm = i
		_refresh_save_list()
		return
	_save_confirm = -1
	Save.erase_slot(i)
	_refresh_save_list()
	_toast("%d 号世界已删除" % (i + 1))


## 关闭存档页：回到标题页或直接继续游戏
func _close_save_select(restore_boot := true) -> void:
	if _save_panel != null:
		_save_panel.queue_free()
		_save_panel = null
	if _save_dim != null:
		_save_dim.queue_free()
		_save_dim = null
	_save_list = null
	_save_confirm = -1
	if restore_boot and _boot_panel != null:
		_boot_panel.visible = true
		_boot_status.text = _boot_info_text()
	elif restore_boot:
		get_tree().paused = false


func _boot_host() -> void:
	_boot_status.text = "正在连接中继服务器……"
	Net.start_host()


func _boot_join() -> void:
	var code := _boot_input.text.strip_edges().to_upper()
	if code.length() != 4:
		_boot_status.text = "房间码是 4 位字符"
		return
	_boot_status.text = "正在加入房间 %s ……" % code
	Net.start_join(code)


func _on_room_created(code: String) -> void:
	_boot_status.text = "房间建好了！房间码：%s\n把房间码发给好友，等 TA 输码点「加入好友」……" % code


func _on_joined_room() -> void:
	_boot_finish(true)


func _on_peer_joined() -> void:
	if _boot_panel != null:
		_boot_finish(true)
	else:
		_toast("好友加入了你们的世界！")
		_net_full_now()


func _on_peer_left() -> void:
	if Net.is_host():
		_toast("好友离开了房间，你们继续各自游玩")
	else:
		_toast("与主机断开连接，已切换为单人模式")
		Net.close()
		_unfreeze_entities()


func _on_net_error(msg: String) -> void:
	if _boot_panel != null:
		_boot_status.text = msg + "（可先单人游戏）"
	else:
		_toast(msg)


## 开局面板收尾：恢复游戏；联机侧做影子与实体冻结
func _boot_finish(as_net: bool) -> void:
	get_tree().paused = false
	if _boot_panel != null:
		_boot_panel.queue_free()
		_boot_panel = null
	if Net.room_created.is_connected(_on_room_created):
		Net.room_created.disconnect(_on_room_created)
	if Net.joined_room.is_connected(_on_joined_room):
		Net.joined_room.disconnect(_on_joined_room)
	_minimap.visible = true
	_arrow.visible = true
	if as_net:
		_make_shadow()
		if help_open:
			_toggle_help(false)
		if Net.is_guest():
			_freeze_entities_for_guest()
			Net.send({t = "hello"})
			_toast("已加入房间 %s！移动是本地的，动作会发给房主结算" % Net.room_code)
		else:
			_toast("建房成功（%s），好友已就位！" % Net.room_code)


# ---------- 背包页面（B 键 / 右上关闭） ----------

## 分类标签：内部 id + 中文名；颜色见 _bag_cat_color
const BAG_TABS := [
	["all", "全部"], ["crop", "作物"], ["seed", "种子"],
	["fish", "鱼"], ["ore", "矿石"], ["mat", "材料"], ["food", "料理"],
]
const BAG_ORE_IDS := ["copper", "iron", "gem", "copper_bar", "iron_bar"]


## 背包面板：顶部金币与关闭、分类标签、六列物品格子（可滚动）、右侧详情与卖出
func _build_bag() -> void:
	_bag_dim = ColorRect.new()
	_bag_dim.color = Color(0.02, 0.03, 0.05, 0.6)
	_bag_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bag_dim.visible = false
	$UI.add_child(_bag_dim)
	_bag_panel = PanelContainer.new()
	_bag_panel.anchor_left = 0.5
	_bag_panel.anchor_top = 0.5
	_bag_panel.anchor_right = 0.5
	_bag_panel.anchor_bottom = 0.5
	_bag_panel.offset_left = -500.0
	_bag_panel.offset_top = -290.0
	_bag_panel.offset_right = 500.0
	_bag_panel.offset_bottom = 290.0
	_bag_panel.add_theme_stylebox_override("panel", _modal_style())
	_bag_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停世界时面板仍可点
	_bag_panel.visible = false
	$UI.add_child(_bag_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_bag_panel.add_child(vb)
	# 顶栏：标题 · 金币 · 关闭
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	var title := _mk_label("背 包", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_bag_gold = _mk_label("", 14)
	_bag_gold.add_theme_color_override("font_color", Color(1, 0.86, 0.42))
	top.add_child(_bag_gold)
	var close := _mk_btn("×")
	close.custom_minimum_size = Vector2(34, 30)
	close.add_theme_font_size_override("font_size", 16)
	close.pressed.connect(func() -> void: _toggle_bag(false))
	top.add_child(close)
	# 分类标签行：整排等宽，选中项用蓝色高亮
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vb.add_child(tabs)
	for i in BAG_TABS.size():
		var tb := _mk_btn(String(BAG_TABS[i][1]))
		tb.custom_minimum_size = Vector2(0, 28)
		tb.add_theme_font_size_override("font_size", 12)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(_on_bag_tab.bind(i))
		_bag_tabs.append(tb)
		tabs.add_child(tb)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	vb.add_child(body)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 6
	_bag_grid.add_theme_constant_override("h_separation", 8)
	_bag_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(_bag_grid)
	# 右侧详情
	var det := PanelContainer.new()
	det.custom_minimum_size = Vector2(250, 0)
	det.add_theme_stylebox_override("panel", _bag_side_style())
	body.add_child(det)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 7)
	det.add_child(dv)
	_bag_name = _mk_label("—", 19)
	_bag_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bag_name.custom_minimum_size = Vector2(214, 0)
	dv.add_child(_bag_name)
	_bag_cat = _mk_label("", 12)
	_bag_cat.modulate = Color(1, 1, 1, 0.7)
	dv.add_child(_bag_cat)
	var sp1 := HSeparator.new()
	sp1.modulate = Color(1, 1, 1, 0.2)
	dv.add_child(sp1)
	_bag_hold = _mk_label("", 13)
	dv.add_child(_bag_hold)
	_bag_unit = _mk_label("", 13)
	_bag_unit.add_theme_color_override("font_color", Color(1, 0.86, 0.42))
	dv.add_child(_bag_unit)
	_bag_note = _mk_label("", 11)
	_bag_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bag_note.custom_minimum_size = Vector2(214, 0)
	_bag_note.modulate = Color(1, 1, 1, 0.62)
	dv.add_child(_bag_note)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(sp2)
	_bag_sell1 = _mk_btn("卖 1 个")
	_bag_sell1.custom_minimum_size = Vector2(0, 32)
	_bag_sell1.add_theme_font_size_override("font_size", 13)
	_bag_sell1.pressed.connect(_bag_sell.bind(false))
	dv.add_child(_bag_sell1)
	_bag_sellall = _mk_btn("全部卖出")
	_bag_sellall.custom_minimum_size = Vector2(0, 32)
	_bag_sellall.add_theme_font_size_override("font_size", 13)
	_bag_sellall.pressed.connect(_bag_sell.bind(true))
	dv.add_child(_bag_sellall)
	var hint := _mk_label("I 关闭 · 点格子查看详情 · 卖出按角色加成即时结算", 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.55)
	vb.add_child(hint)


func _modal_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.97)
	sb.border_color = Color(0.38, 0.5, 0.68, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	return sb


func _bag_side_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.2, 0.95)
	sb.border_color = Color(0.3, 0.4, 0.55, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	return sb


## 背包格子底框：分类色细边框，选中/悬停时边框更亮
func _bag_cell_style(c: Color, sel: bool, hot: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.3, 0.4, 0.98) if sel else Color(0.15, 0.18, 0.23, 0.96)
	sb.border_color = Color(c.r, c.g, c.b, 1.0 if sel else (0.85 if hot else 0.5))
	sb.set_border_width_all(2 if sel else 1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	return sb


func _bag_cat_color(cat: String) -> Color:
	match cat:
		"crop": return Color(0.55, 0.82, 0.52)
		"seed": return Color(0.86, 0.8, 0.45)
		"fish": return Color(0.5, 0.72, 0.95)
		"ore": return Color(0.95, 0.7, 0.45)
		"mat": return Color(0.82, 0.74, 0.62)
		"food": return Color(0.95, 0.62, 0.67)
	return Color(0.75, 0.8, 0.88)


## 打开/关闭背包：暂停世界、压暗背景，关掉时恢复
func _toggle_bag(open: bool) -> void:
	if bag_open == open:
		return
	bag_open = open
	_bag_panel.visible = open
	_bag_dim.visible = open
	get_tree().paused = open
	if open:
		_bag_sel_id = ""
		_refresh_bag()


func _on_bag_tab(i: int) -> void:
	_bag_tab = i
	_bag_sel_id = ""
	_refresh_bag()


## 分类切换与卖出后都整页重刷（格子数量不多，重建比增量更新可靠）
func _refresh_bag() -> void:
	if _bag_grid == null:
		return
	_bag_gold.text = "金币 %d" % Game.gold
	for i in _bag_tabs.size():
		var active: bool = i == _bag_tab
		var tb: Button = _bag_tabs[i]
		tb.add_theme_stylebox_override("normal", _bag_tab_style(active))
		tb.add_theme_stylebox_override("hover", _bag_tab_style(true))
		tb.add_theme_color_override("font_color",
				Color(1, 1, 1) if active else Color(0.78, 0.84, 0.92))
	for ch in _bag_grid.get_children():
		_bag_grid.remove_child(ch)
		ch.queue_free()
	var entries: Array = _bag_entries()
	var tab_id := String(BAG_TABS[_bag_tab][0])
	var shown := 0
	for e in entries:
		if tab_id != "all" and String(e.cat) != tab_id:
			continue
		_bag_grid.add_child(_bag_cell(e))
		shown += 1
	if shown == 0:
		var empty := _mk_label("这一栏还空着", 12)
		empty.modulate = Color(1, 1, 1, 0.5)
		_bag_grid.add_child(empty)
	var sel: Dictionary = {}
	for e in entries:
		if String(e.id) == _bag_sel_id:
			sel = e
	if sel.is_empty():
		_bag_sel_id = ""
	_bag_show(sel)


func _bag_tab_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.48, 0.68, 0.95) if active else Color(0.14, 0.17, 0.22, 0.9)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## 背包全部条目：作物仓 / 种子袋 / 材料鱼矿加工品料理，按售价从高到低
func _bag_entries() -> Array:
	var out: Array = []
	for id in Game.harvest.keys():
		var n: int = int(Game.harvest[id])
		if n > 0:
			out.append({"id": id, "kind": "crop", "cat": "crop",
				"name": String(Game.CROPS[id].name), "n": n,
				"sell": int(Game.CROPS[id].sell)})
	for id in Game.seeds.keys():
		var ns: int = int(Game.seeds[id])
		if ns > 0:
			out.append({"id": id, "kind": "seed", "cat": "seed",
				"name": "%s种子" % Game.CROPS[id].name, "n": ns, "sell": 0})
	for id in Game.items.keys():
		var ni: int = int(Game.items[id])
		if ni <= 0:
			continue
		var d: Dictionary = _bag_item_data(String(id))
		out.append({"id": id, "kind": "item", "cat": _bag_item_cat(String(id)),
			"name": String(d.get("name", id)), "n": ni,
			"sell": int(d.get("sell", 0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a.cat) != String(b.cat):
			return String(a.cat) < String(b.cat)
		return int(a.sell) > int(b.sell))
	return out


func _bag_item_data(id: String) -> Dictionary:
	for d in [Game.FISH, Game.MATERIALS, Game.PRODUCTS, Game.DISHES]:
		if d.has(id):
			return d[id]
	return {}


func _bag_item_cat(id: String) -> String:
	if BAG_ORE_IDS.has(id):
		return "ore"
	if Game.FISH.has(id):
		return "fish"
	if Game.PRODUCTS.has(id) or Game.DISHES.has(id):
		return "food"
	return "mat"


func _bag_cat_dict(id: String) -> Dictionary:
	for d in [Game.FISH, Game.MATERIALS, Game.PRODUCTS, Game.DISHES]:
		if d.has(id):
			return d
	return Game.MATERIALS


## 单个物品格子：物品名（自动换行）+ 右下角数量
func _bag_cell(e: Dictionary) -> Control:
	var c: Color = _bag_cat_color(String(e.cat))
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(84, 84)
	cell.add_theme_stylebox_override("panel",
			_bag_cell_style(c, String(e.id) == _bag_sel_id, false))
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	cell.add_child(vb)
	var nm := _mk_label(String(e.name), 11)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	var cnt_row := HBoxContainer.new()
	cnt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cnt_row.add_child(pad)
	var cnt := _mk_label("×%d" % int(e.n), 12)
	cnt.add_theme_color_override("font_color", Color(c.r, c.g, c.b, 1.0))
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cnt_row.add_child(cnt)
	vb.add_child(cnt_row)
	cell.gui_input.connect(_on_bag_cell_input.bind(e))
	cell.mouse_entered.connect(func() -> void:
		cell.add_theme_stylebox_override("panel", _bag_cell_style(
				c, String(e.id) == _bag_sel_id, true)))
	cell.mouse_exited.connect(func() -> void:
		cell.add_theme_stylebox_override("panel", _bag_cell_style(
				c, String(e.id) == _bag_sel_id, false)))
	return cell


func _on_bag_cell_input(ev: InputEvent, e: Dictionary) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		_bag_sel_id = String(e.id)
		_refresh_bag()


## 右侧详情：名称、分类、持有、单价（含角色加成）、说明、卖出按钮
func _bag_show(e: Dictionary) -> void:
	if e.is_empty():
		_bag_name.text = "—"
		_bag_cat.text = "点左边的格子查看详情"
		_bag_hold.text = ""
		_bag_unit.text = ""
		_bag_note.text = ""
		_bag_sell1.disabled = true
		_bag_sellall.disabled = true
		_bag_sell1.text = "卖 1 个"
		_bag_sellall.text = "全部卖出"
		return
	_bag_name.text = String(e.name)
	var cat_name := ""
	for t in BAG_TABS:
		if String(t[0]) == String(e.cat):
			cat_name = String(t[1])
	var c: Color = _bag_cat_color(String(e.cat))
	_bag_cat.text = "分类 · %s" % cat_name
	_bag_cat.add_theme_color_override("font_color", c)
	_bag_hold.text = "持有 %d 个" % int(e.n)
	var unit: int = 0
	if e.kind == "seed":
		_bag_unit.text = "种子不能出售"
		_bag_unit.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		_bag_note.text = "拿到田里种下，成熟后收获再卖钱。"
		_bag_sell1.disabled = true
		_bag_sellall.disabled = true
		_bag_sell1.text = "卖 1 个"
		_bag_sellall.text = "全部卖出"
		return
	unit = _sell_price(int(e.sell))
	_bag_unit.text = "单价 %d 金币" % unit
	_bag_unit.add_theme_color_override("font_color", Color(1, 0.86, 0.42))
	_bag_sell1.disabled = false
	_bag_sellall.disabled = false
	_bag_sell1.text = "卖 1 个（+%d）" % unit
	_bag_sellall.text = "全部卖出（+%d）" % (unit * int(e.n))
	var tips := "作物可卖给货摊，也能交订单。"
	match String(e.cat):
		"fish": tips = "鱼可以卖钱，也能交订单或做料理原料。"
		"ore": tips = "矿石用于造机器和工具升级，留着更划算。"
		"mat": tips = "材料（木材/石料/毛奶蛋）是制作与加工的基础。"
		"food": tips = "料理吃下能回体力，也可以直接卖钱。"
	_bag_note.text = tips


## 卖出：作物走 _sell（作物仓），其它走 _sell_item（背包），联机时自动转发房主
func _bag_sell(all: bool) -> void:
	var e: Dictionary = {}
	for x in _bag_entries():
		if String(x.id) == _bag_sel_id:
			e = x
			break
	if e.is_empty():
		return
	if String(e.kind) == "seed":
		_toast("种子卖不出去，拿去种吧")
		return
	if String(e.kind) == "crop":
		_sell(String(e.id), all)
	else:
		_sell_item(_bag_cat_dict(String(e.id)), String(e.id), all)
	_refresh_bag()


