extends Node2D
## 场景装饰：房屋/商店/树木/栅栏/小路/花与荷叶，全部基于像素贴图，并负责碰撞
## 附加：水面动画、夜晚灯光与萤火虫、烟囱炊烟、草丛石子散布

const FARM := preload("res://scripts/farm.gd")

const TEX_HOUSE := preload("res://assets/house.png")
const TEX_STALL := preload("res://assets/stall.png")
const TEX_TREE := preload("res://assets/tree.png")
const TEX_PINE := preload("res://assets/tree2.png")
const TEX_POST := preload("res://assets/fence_post.png")
const TEX_RAIL := preload("res://assets/fence_rail.png")
const TEX_FLOWERS := preload("res://assets/flowers.png")
const TEX_LILY := preload("res://assets/lily.png")
const TEX_STONE := preload("res://assets/stone.png")
const TEX_TUFT := preload("res://assets/tuft.png")
const TEX_SHADOW := preload("res://assets/shadow.png")
const TEX_SIGN := preload("res://assets/sign.png")
const TEX_LAMP := preload("res://assets/lamp.png")
const TEX_GLOW := preload("res://assets/glow.png")
const TEX_GLOW_S := preload("res://assets/glow_small.png")
const TEX_POND_EDGE := preload("res://assets/pond_edge.png")
const TEX_WELL := preload("res://assets/well.png")
const TEX_MAILBOX := preload("res://assets/mailbox.png")
const TEX_LOG := preload("res://assets/log.png")
const TEX_STUMP := preload("res://assets/stump.png")
const TEX_MUSHROOM := preload("res://assets/mushroom.png")
const TEX_BUTTERFLY := preload("res://assets/butterfly.png")
const TEX_CLOUD := preload("res://assets/cloud_shadow.png")
const TEX_LEAF := preload("res://assets/leaf.png")
const TEX_BOARD := preload("res://assets/order_board.png")
const TEX_COOP := preload("res://assets/coop.png")
const TEX_BARN := preload("res://assets/barn.png")
const TEX_MINE := preload("res://assets/mine_arch.png")
const TEX_BUNTING := preload("res://assets/bunting.png")

const WATER_FRAMES := [
	preload("res://assets/water0.png"), preload("res://assets/water1.png"),
	preload("res://assets/water2.png"), preload("res://assets/water3.png"),
]

const HOUSE_RECT := Rect2(-780, -580, 240, 170)
const DOOR_POS := Vector2(-660, -410)
const STALL_RECT := Rect2(560, -450, 220, 120)
const SHOP_POS := Vector2(670, -330)
const POND_RECT := Rect2(560, -60, 240, 160)
const LAMP_POS := Vector2(524, -374)
## 扩展区兴趣点：水井 / 信箱 / 花田 / 原木树桩
const WELL_POS := Vector2(-1300, -320)
const MAILBOX_POS := Vector2(-590, -396)
const GARDEN_RECT := Rect2(-1320, 560, 300, 200)
const LOG_POS := Vector2(-1210, -470)
const STUMP_POS := Vector2(-1420, -180)
## 北部野莓丛（Gather 系统负责交互）
const BUSH_SPOTS := [
	Vector2(-560, -880), Vector2(-430, -945), Vector2(-295, -865),
	Vector2(-150, -950), Vector2(-680, -985), Vector2(-30, -830),
]
## 订单任务牌（货摊右侧）
const BOARD_POS := Vector2(810, -330)
## 鸡舍与鸡的散步区（屋旁空地）
const COOP_POS := Vector2(-480, -500)
const COOP_ROAM := Rect2(-540, -450, 140, 100)
## 鸡蛋堆放点（鸡舍门前，最多 10 颗）
const EGG_SPOTS := [
	Vector2(-512, -452), Vector2(-492, -458), Vector2(-472, -452), Vector2(-452, -458),
	Vector2(-522, -438), Vector2(-502, -444), Vector2(-482, -438), Vector2(-462, -444),
	Vector2(-532, -424), Vector2(-512, -430),
]
## 西侧畜棚与牛羊散步区
const BARN_POS := Vector2(-820, -306)
const BARN_ROAM := Rect2(-890, -220, 170, 95)
## 牛奶瓶堆放点（畜棚门前左侧，最多 4 瓶）
const MILK_SPOTS := [
	Vector2(-852, -248), Vector2(-828, -254), Vector2(-838, -236), Vector2(-860, -240),
]
## 羊毛团堆放点（畜棚门前右侧，最多 4 团）
const WOOL_SPOTS := [
	Vector2(-788, -248), Vector2(-812, -236), Vector2(-776, -238), Vector2(-800, -226),
]
## 东侧矿洞：入口拱门与矿岩刷新区
const MINE_POS := Vector2(1480, 240)
const MINE_ZONE := Rect2(1240, 60, 460, 400)
## 额外路灯（屋旁与农田边），夜里和主路灯一起亮
const EXTRA_LAMPS := [Vector2(-600, -376), Vector2(300, -300)]
const MUSHROOM_POS := [
	Vector2(-1090, 320), Vector2(-1180, 760), Vector2(1120, 480),
	Vector2(1560, -820), Vector2(-1560, -620), Vector2(1340, 900),
]

const TREES := [
	Vector2(-1050, -780), Vector2(-900, -350), Vector2(-1000, 400),
	Vector2(-350, 700), Vector2(60, -800), Vector2(450, -750),
	Vector2(1050, -750), Vector2(1150, -50), Vector2(900, 350),
	Vector2(300, 600), Vector2(-1000, 850), Vector2(1200, 800),
	Vector2(480, -520), Vector2(880, -520),
	# 扩展区内部树木（北 / 南 / 西 / 东）
	Vector2(-800, -1120), Vector2(-1250, -1140), Vector2(320, -1150),
	Vector2(920, -1120), Vector2(-1050, -1080), Vector2(-600, 1120),
	Vector2(120, 1140), Vector2(820, 1120), Vector2(1420, 1090),
	Vector2(-1700, 60), Vector2(-1660, 720), Vector2(-1720, -660),
	Vector2(1700, -240), Vector2(1680, 420),
]

## 石板小路：门口 → 农田 / 商店 / 水井 / 池塘
const PATHS := [
	[Vector2(-660, -395), Vector2(-390, -230)],
	[Vector2(-636, -388), Vector2(-160, -362), Vector2(420, -348), Vector2(636, -322)],
	[Vector2(-684, -402), Vector2(-1000, -386), Vector2(-1252, -348)],
	[Vector2(-390, -230), Vector2(-80, -150), Vector2(300, -90), Vector2(498, -20)],
]

const FLOWER_POS := [
	Vector2(-500, -500), Vector2(-260, -450), Vector2(120, -420),
	Vector2(650, -250), Vector2(900, 150), Vector2(-150, -80),
	Vector2(-80, 120), Vector2(420, 80), Vector2(700, 300),
	Vector2(900, 550), Vector2(-700, 100), Vector2(-950, -100),
	Vector2(-400, 500), Vector2(200, 500),
]

const LILY_POS := [Vector2(630, -10), Vector2(710, 40), Vector2(755, -25)]

const FIREFLY_BASE := [
	Vector2(600, 20), Vector2(690, 90), Vector2(750, -30), Vector2(500, 70),
	Vector2(860, 40), Vector2(620, 140), Vector2(770, 120), Vector2(470, -30),
]
## 池塘水面碎光起点（波光闪烁用）
const SPARKLE_BASE := [
	Vector2(600, 30), Vector2(660, -20), Vector2(720, 60),
	Vector2(770, 10), Vector2(620, 100), Vector2(700, 130),
]

## 白天氛围：蝴蝶活动点（花田与野花丛）/ 云影初始位置
const BUTTERFLY_SPOTS := [
	Vector2(-1170, 660), Vector2(-500, -500), Vector2(650, -250),
	Vector2(900, 150), Vector2(-80, 120),
]
const CLOUD_SEEDS := [
	Vector2(-900, -620), Vector2(500, 140), Vector2(-350, 760), Vector2(1250, -450),
]

var sign_font: Font
var _stones: Array[Vector2] = []
var _wt := 0.0
var _glow_window: Sprite2D
var _glow_lamp: Sprite2D
var _glow_coop: Sprite2D
var _glow_barn: Sprite2D
var _fireflies: Array[Sprite2D] = []
var _butterflies: Array[Sprite2D] = []
var _clouds: Array[Sprite2D] = []
var _bunting: Sprite2D
# 四季飘落物：春花瓣 / 秋落叶（复用树叶粒子）/ 冬雪
var _petals: CPUParticles2D
var _snow: CPUParticles2D
var _leaf_emitters: Array[CPUParticles2D] = []
var _sparkles: Array[Sprite2D] = []
var _season := 0
# 温室：建成后绘制玻璃房并挡墙（脚本创建，读档后由 main 调用 set_greenhouse 恢复）
var _gh_built := false
var _gh_bodies: Array = []


func _ready() -> void:
	sign_font = ThemeDB.fallback_font
	# 小路的石板（固定随机种子，保证每次一致）
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for path in PATHS:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var n := maxi(int(a.distance_to(b) / 34.0), 1)
			for k in n:
				_stones.append(a.lerp(b, (k + 0.5) / n)
						+ Vector2(rng.randf_range(-7, 7), rng.randf_range(-6, 6)))
	# 树木与投影（橡树 / 松树交替）
	for i in TREES.size():
		var p: Vector2 = TREES[i]
		_add_sprite(TEX_SHADOW, p + Vector2(0, 26))
		_add_sprite(TEX_PINE if i % 2 == 1 else TEX_TREE, p + Vector2(0, -14))
	# 野花（图集 4 种花色）
	for i in FLOWER_POS.size():
		_add_sprite(TEX_FLOWERS, FLOWER_POS[i], Rect2((i % 4) * 16, 0, 16, 16))
	# 荷叶与池塘沙边
	for p in LILY_POS:
		_add_sprite(TEX_LILY, p)
	_add_sprite(TEX_POND_EDGE, POND_RECT.get_center())
	# 扩展区：水井 / 信箱 / 原木树桩 / 蘑菇 / 花田花丛
	_add_sprite(TEX_SHADOW, WELL_POS + Vector2(0, 20))
	_add_sprite(TEX_WELL, WELL_POS)
	_add_sprite(TEX_MAILBOX, MAILBOX_POS)
	_add_sprite(TEX_LOG, LOG_POS)
	_add_sprite(TEX_STUMP, STUMP_POS)
	# 订单任务牌 / 鸡舍
	_add_sprite(TEX_SHADOW, BOARD_POS + Vector2(0, 10))
	_add_sprite(TEX_BOARD, BOARD_POS)
	_add_sprite(TEX_SHADOW, COOP_POS + Vector2(0, 16))
	_add_sprite(TEX_COOP, COOP_POS + Vector2(0, -6))
	# 西侧畜棚（牛羊住这里）
	_add_sprite(TEX_SHADOW, BARN_POS + Vector2(0, 26))
	_add_sprite(TEX_BARN, BARN_POS + Vector2(0, -6))
	# 东侧矿洞入口 / 节日彩旗（默认收起，节日当天挂出）
	_add_sprite(TEX_SHADOW, MINE_POS + Vector2(0, 24))
	_add_sprite(TEX_MINE, MINE_POS + Vector2(0, -2))
	_bunting = _add_sprite(TEX_BUNTING, Vector2(670, -368))
	_bunting.visible = false
	for p in MUSHROOM_POS:
		_add_sprite(TEX_MUSHROOM, p)
	for p in BUSH_SPOTS:
		_add_sprite(TEX_SHADOW, p + Vector2(0, 9))
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 5
	for i in 14:
		var fp := Vector2(
			rng2.randf_range(GARDEN_RECT.position.x + 24, GARDEN_RECT.end.x - 24),
			rng2.randf_range(GARDEN_RECT.position.y + 24, GARDEN_RECT.end.y - 24))
		_add_sprite(TEX_FLOWERS, fp, Rect2((i % 4) * 16, 0, 16, 16))
	# 草丛与石子散布（避开农田/池塘/建筑/新区兴趣点）
	_scatter_detail()
	# 夜景：路灯、房屋/鸡舍/畜棚窗户灯光、萤火虫、炊烟
	_add_sprite(TEX_LAMP, LAMP_POS)
	_glow_lamp = _add_glow(LAMP_POS + Vector2(0, -12), 1.4)
	for p in EXTRA_LAMPS:
		_add_sprite(TEX_LAMP, p)
		_add_glow(p + Vector2(0, -12), 1.1)
	_glow_window = _add_glow(Vector2(-722, -468), 2.0)
	_glow_coop = _add_glow(COOP_POS + Vector2(-6, -14), 1.1)
	_glow_barn = _add_glow(BARN_POS + Vector2(6, -8), 1.3)
	for b in FIREFLY_BASE:
		var f := _add_sprite(TEX_GLOW, b)
		f.material = _add_material()
		f.scale = Vector2(0.4, 0.4)
		f.modulate = Color(0.85, 1.0, 0.5, 0.0)  # 黄绿色萤火
		_fireflies.append(f)
	_setup_smoke()
	_setup_ambience()
	# 碰撞：房屋、商店、池塘、灯柱、树干、水井、信箱、花田栅栏、任务牌、鸡舍、地图边界
	_add_blocker_rect(HOUSE_RECT)
	_add_blocker_rect(STALL_RECT)
	_add_blocker_rect(POND_RECT)
	_add_blocker_circle(LAMP_POS, 6.0)
	for p in EXTRA_LAMPS:
		_add_blocker_circle(p, 6.0)
	_add_blocker_circle(BOARD_POS, 9.0)
	_add_blocker_circle(COOP_POS, 20.0)
	_add_blocker_circle(MINE_POS + Vector2(0, 6), 24.0)
	for p in TREES:
		_add_blocker_circle(p + Vector2(0, 16), 12.0)
	_add_blocker_circle(WELL_POS, 18.0)
	_add_blocker_circle(MAILBOX_POS, 5.0)
	_add_blocker_rect(Rect2(GARDEN_RECT.position.x, GARDEN_RECT.position.y + 2, GARDEN_RECT.size.x, 6))
	_add_blocker_rect(Rect2(GARDEN_RECT.position.x, GARDEN_RECT.end.y - 8, GARDEN_RECT.size.x, 6))
	_add_blocker_rect(Rect2(GARDEN_RECT.position.x, GARDEN_RECT.position.y, 6, GARDEN_RECT.size.y))
	_add_blocker_rect(Rect2(GARDEN_RECT.end.x - 6, GARDEN_RECT.position.y, 6, GARDEN_RECT.size.y))
	# 地图边界（草地 3800x2600，树墙内侧留出通行缓冲）
	_add_blocker_rect(Rect2(-1960, -1300, 3920, 72))
	_add_blocker_rect(Rect2(-1960, 1228, 3920, 72))
	_add_blocker_rect(Rect2(-1900, -1300, 72, 2600))
	_add_blocker_rect(Rect2(1828, -1300, 72, 2600))


func _process(delta: float) -> void:
	_wt += delta
	# 水面波光动画
	var pond := get_node_or_null("../Pond")
	if pond:
		pond.texture = WATER_FRAMES[int(_wt / 0.45) % 4]
	# 夜晚因子（从环境色调亮度推算）→ 灯光与萤火虫
	var lum: float = get_node("../CanvasModulate").color.get_luminance()
	var night := clampf((0.75 - lum) / 0.4, 0.0, 1.0)
	# 窗户灯光轻微呼吸闪烁，比恒定亮着更像有人住
	var flick := 0.86 + 0.1 * sin(_wt * 2.3) + 0.04 * sin(_wt * 7.1)
	_glow_window.modulate.a = night * 0.95 * flick
	_glow_lamp.modulate.a = night * 0.9 * flick
	_glow_coop.modulate.a = night * 0.8 * flick
	_glow_barn.modulate.a = night * 0.8 * flick
	for i in _fireflies.size():
		var f := _fireflies[i]
		var b: Vector2 = FIREFLY_BASE[i]
		f.position = b + Vector2(sin(_wt * 0.7 + i * 1.9) * 26.0, cos(_wt * 0.53 + i * 1.3) * 18.0)
		f.modulate.a = night * (0.5 + 0.42 * (0.5 + 0.5 * sin(_wt * 2.2 + i)))
	# 白天氛围：蝴蝶飞舞（入夜淡出，秋冬变少）与云影缓慢漂移
	var day_a := clampf(1.0 - night * 1.6, 0.0, 1.0)
	var bfly := day_a * (1.0 if _season <= 1 else (0.45 if _season == 2 else 0.0))
	for i in _butterflies.size():
		var b := _butterflies[i]
		var t := _wt * (0.5 + 0.12 * i) + i * 2.13
		b.position = BUTTERFLY_SPOTS[i] + Vector2(sin(t) * 54.0, cos(t * 0.77) * 30.0)
		b.frame = int(_wt * 10.0 + i * 1.7) % 2
		b.flip_h = sin(t * 0.9) < 0.0
		b.modulate.a = bfly
	# 水面波光：池塘上的碎光缓缓漂移、明暗交替
	for i in _sparkles.size():
		var sk := _sparkles[i]
		var st := _wt * 1.5 + i * 2.4
		sk.position = SPARKLE_BASE[i] + Vector2(sin(st * 0.6) * 11.0, cos(st * 0.45) * 7.0)
		sk.modulate.a = day_a * (0.24 + 0.42 * maxf(0.0, sin(st * 1.7)))
	for i in _clouds.size():
		var c := _clouds[i]
		c.position.x += delta * (9.0 + i * 2.5)
		if c.position.x > 2150.0:
			c.position.x = -2150.0


## 节日开关：节日当天在货摊前挂出彩旗
func set_festival(on: bool) -> void:
	if _bunting:
		_bunting.visible = on


## 季节氛围切换：春花瓣 / 秋落叶 / 冬雪各自显隐（main 换季时调用）
func set_season(i: int) -> void:
	_season = clampi(i, 0, 3)
	if _petals:
		_petals.emitting = _season == 0
		_petals.visible = _season == 0
		if _season == 0:
			_petals.restart()
	for p in _leaf_emitters:
		p.emitting = _season == 2
		p.visible = _season == 2
		if _season == 2:
			p.restart()
	if _snow:
		_snow.emitting = _season == 3
		_snow.visible = _season == 3
		if _season == 3:
			_snow.restart()


## 温室建成开关：开启后绘制玻璃房并挡住四壁（下方留门口）
func set_greenhouse(on: bool) -> void:
	_gh_built = on
	for b in _gh_bodies:
		if is_instance_valid(b):
			b.queue_free()
	_gh_bodies.clear()
	if on:
		var r: Rect2 = FARM.GH_RECT
		_gh_bodies.append(_add_blocker_rect(Rect2(r.position.x, r.position.y, r.size.x, 8)))
		_gh_bodies.append(_add_blocker_rect(Rect2(r.position.x, r.end.y - 8, 118, 8)))
		_gh_bodies.append(_add_blocker_rect(Rect2(r.position.x + 162, r.end.y - 8, 118, 8)))
		_gh_bodies.append(_add_blocker_rect(Rect2(r.position.x, r.position.y, 8, r.size.y)))
		_gh_bodies.append(_add_blocker_rect(Rect2(r.end.x - 8, r.position.y, 8, r.size.y)))
	queue_redraw()


func _scatter_detail() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var placed := 0
	while placed < 46:
		var p := Vector2(rng.randf_range(-1780, 1780), rng.randf_range(-1180, 1180))
		var blocked := false
		for z in FARM.ZONES:
			if z.grow(8).has_point(p):
				blocked = true
		if POND_RECT.grow(26).has_point(p) or HOUSE_RECT.grow(20).has_point(p) \
				or STALL_RECT.grow(30).has_point(p) or p.distance_to(DOOR_POS) < 60:
			blocked = true
		if GARDEN_RECT.grow(26).has_point(p) or p.distance_to(WELL_POS) < 70 \
				or p.distance_to(MAILBOX_POS) < 40 or p.distance_to(LOG_POS) < 44 \
				or p.distance_to(STUMP_POS) < 40 or p.distance_to(BOARD_POS) < 60 \
				or p.distance_to(COOP_POS) < 70:
			blocked = true
		if MINE_ZONE.grow(14).has_point(p):
			blocked = true
		if FARM.GH_RECT.grow(12).has_point(p):
			blocked = true
		for b in BUSH_SPOTS:
			if p.distance_to(b) < 56:
				blocked = true
		for t in TREES:
			if p.distance_to(t) < 64:
				blocked = true
		for s in _stones:
			if s.distance_to(p) < 26:
				blocked = true
		if not blocked:
			var tex := TEX_TUFT if rng.randf() < 0.72 else TEX_STONE
			_add_sprite(tex, p)
			placed += 1


## 白天氛围：云影 / 蝴蝶 / 树冠落叶
func _setup_ambience() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in CLOUD_SEEDS.size():
		var c := Sprite2D.new()
		c.texture = TEX_CLOUD
		c.position = CLOUD_SEEDS[i]
		var sc := 1.6 + rng.randf() * 0.9
		c.scale = Vector2(sc, sc * (0.8 + rng.randf() * 0.3))
		c.z_index = 1
		c.modulate.a = 0.9
		add_child(c)
		_clouds.append(c)
	for p in BUTTERFLY_SPOTS:
		var b := Sprite2D.new()
		b.texture = TEX_BUTTERFLY
		b.hframes = 2
		b.position = p
		b.z_index = 1
		add_child(b)
		_butterflies.append(b)
	for i in range(0, TREES.size(), 2):
		_add_leaf_rain(TREES[i] + Vector2(0, -30))
	# 四季飘落物：春花瓣（粉色）/ 冬雪（浅蓝白，避免雪地白上看不见），秋叶由树冠落叶承担
	_petals = _make_fall_particles(TEX_LEAF, Color(1.0, 0.87, 0.94), 200, 9.0, 16.0, 1.2, 2.0)
	_snow = _make_fall_particles(TEX_GLOW_S, Color(0.55, 0.68, 0.94), 300, 9.0, 26.0, 1.6, 2.6)
	# 池塘水面碎光（白天闪烁）
	for p in SPARKLE_BASE:
		var sk := _add_sprite(TEX_GLOW, p)
		sk.material = _add_material()
		sk.scale = Vector2(0.26, 0.17)
		sk.modulate.a = 0.0
		_sparkles.append(sk)


## 全地图范围的飘落粒子（春花瓣 / 冬雪共用），默认不发射，由 set_season 开关
func _make_fall_particles(tex: Texture2D, col: Color, amount: int, life: float,
		fall: float, smin: float, smax: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1860, 1260)
	p.direction = Vector2(0.12, 1)
	p.spread = 15.0
	p.gravity = Vector2(0, fall)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.angular_velocity_min = -70.0
	p.angular_velocity_max = 70.0
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.color = col
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.95))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.z_index = 3
	p.emitting = false
	add_child(p)
	return p


## 树冠飘落树叶（随机秋叶色、旋转飘落、落地图形淡出）
func _add_leaf_rain(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = TEX_LEAF
	p.position = pos
	p.amount = 3
	p.lifetime = 3.4
	p.preprocess = 3.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 20.0
	p.direction = Vector2(0.25, 1)
	p.spread = 24.0
	p.gravity = Vector2(0, 10)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 9.0
	p.angular_velocity_min = -80.0
	p.angular_velocity_max = 80.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	var autumn := Gradient.new()  # 随机初始色：绿→琥珀→赭石
	autumn.set_color(0, Color(0.45, 0.62, 0.3))
	autumn.add_point(0.5, Color(0.8, 0.62, 0.25))
	autumn.set_color(1, Color(0.75, 0.42, 0.22))
	p.color_initial_ramp = autumn
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.95))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.emitting = true
	add_child(p)
	_leaf_emitters.append(p)


func _add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _add_glow(pos: Vector2, scale_f: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = TEX_GLOW
	s.position = pos
	s.scale = Vector2(scale_f, scale_f)
	s.material = _add_material()
	s.modulate.a = 0.0
	add_child(s)
	return s


func _setup_smoke() -> void:
	var smoke := CPUParticles2D.new()
	smoke.position = Vector2(-590, -560)
	smoke.amount = 5
	smoke.lifetime = 2.4
	smoke.texture = TEX_GLOW_S
	smoke.direction = Vector2(0, -1)
	smoke.spread = 14.0
	smoke.gravity = Vector2(0, -16)
	smoke.initial_velocity_min = 7.0
	smoke.initial_velocity_max = 13.0
	smoke.scale_amount_min = 0.7
	smoke.scale_amount_max = 1.7
	smoke.color = Color(0.88, 0.88, 0.86, 0.16)
	smoke.emitting = true
	add_child(smoke)


func _add_sprite(tex: Texture2D, pos: Vector2, region := Rect2()) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	if region.size.x > 0:
		s.region_enabled = true
		s.region_rect = region
	add_child(s)
	return s


func _add_blocker_rect(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	body.position = r.get_center()
	body.add_child(cs)
	add_child(body)
	return body


func _add_blocker_circle(pos: Vector2, radius: float) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	body.position = pos
	body.add_child(cs)
	add_child(body)


func _draw() -> void:
	_draw_forest_wall()
	for z in FARM.ZONES:
		_draw_fence(z)
	_draw_fence(GARDEN_RECT)
	_draw_greenhouse()
	_draw_path()
	draw_texture_rect(TEX_HOUSE, Rect2(-784, -594, 248, 184), false)
	draw_texture_rect(TEX_STALL, Rect2(STALL_RECT.position, STALL_RECT.size), false)
	# 商店招牌
	var sign_rect := Rect2(STALL_RECT.get_center().x - 90, STALL_RECT.position.y - 68, 180, 26)
	draw_texture_rect(TEX_SIGN, sign_rect, false)
	draw_string_outline(sign_font, Vector2(sign_rect.position.x, sign_rect.position.y + 19),
			"皮埃尔种子商店", HORIZONTAL_ALIGNMENT_CENTER, sign_rect.size.x, 16, 4, Color(0.1, 0.07, 0.05))
	draw_string(sign_font, Vector2(sign_rect.position.x, sign_rect.position.y + 19),
			"皮埃尔种子商店", HORIZONTAL_ALIGNMENT_CENTER, sign_rect.size.x, 16, Color(0.24, 0.16, 0.1))


## 温室外观：半透明玻璃 + 木框 + 屋顶斜梁，建成后才绘制
func _draw_greenhouse() -> void:
	if not _gh_built:
		return
	var r: Rect2 = FARM.GH_RECT
	var wood := Color(0.44, 0.32, 0.2)
	draw_rect(r, Color(0.55, 0.85, 0.78, 0.18))
	# 内部苗床底色（未开垦时也像土床，开垦后农田格会盖在上面）
	draw_rect(FARM.GH_ZONE, Color(0.42, 0.31, 0.2, 0.85))
	var x := r.position.x + 24.0
	while x < r.end.x - 8.0:
		draw_line(Vector2(x, r.position.y + 8.0), Vector2(x, r.end.y - 10.0),
				Color(0.78, 0.96, 0.9, 0.22), 2.0)
		x += 30.0
	draw_rect(Rect2(r.position, Vector2(r.size.x, 8.0)), wood)
	# 底边留门口（与碰撞缺口对齐）
	draw_rect(Rect2(r.position.x, r.end.y - 8.0, 118.0, 8.0), wood)
	draw_rect(Rect2(r.position.x + 162.0, r.end.y - 8.0, 118.0, 8.0), wood)
	draw_rect(Rect2(r.position.x, r.position.y, 8.0, r.size.y), wood)
	draw_rect(Rect2(r.end.x - 8.0, r.position.y, 8.0, r.size.y), wood)
	draw_line(Vector2(r.position.x, r.position.y + 10.0),
			Vector2(r.get_center().x, r.position.y - 16.0), wood, 4.0)
	draw_line(Vector2(r.get_center().x, r.position.y - 16.0),
			Vector2(r.end.x, r.position.y + 10.0), wood, 4.0)
	# 招牌画在玻璃顶内侧，避免被画面上沿裁掉
	draw_string(sign_font, Vector2(r.get_center().x - 60.0, r.position.y + 34.0),
			"温 室", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(0.2, 0.13, 0.07))


func _draw_fence(r: Rect2) -> void:
	draw_texture_rect(TEX_RAIL, Rect2(r.position.x, r.position.y + 2, r.size.x, 8), false)
	draw_texture_rect(TEX_RAIL, Rect2(r.position.x, r.end.y - 4, r.size.x, 8), false)
	var x := r.position.x
	while x <= r.end.x:
		draw_texture_rect(TEX_POST, Rect2(x - 6, r.position.y - 8, 12, 28), false)
		draw_texture_rect(TEX_POST, Rect2(x - 6, r.end.y - 20, 12, 28), false)
		x += 32.0
	var y := r.position.y + 32.0
	while y < r.end.y:
		draw_texture_rect(TEX_POST, Rect2(r.position.x - 6, y - 8, 12, 28), false)
		draw_texture_rect(TEX_POST, Rect2(r.end.x - 6, y - 8, 12, 28), false)
		y += 32.0


func _draw_path() -> void:
	for s in _stones:
		draw_texture_rect(TEX_STONE, Rect2(s.x - 8, s.y - 5, 16, 10), false)


## 地图四周的森林树墙（纯绘制，实际阻挡靠边界碰撞矩形）
func _draw_forest_wall() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var i := 0
	for x in range(-1876, 1877, 52):
		_wall_tree(Vector2(x + rng.randf_range(-9, 9), -1248 + rng.randf_range(-7, 7)), i)
		_wall_tree(Vector2(x + rng.randf_range(-9, 9), 1248 + rng.randf_range(-7, 7)), i + 1)
		i += 2
	for y in range(-1244, 1245, 52):
		_wall_tree(Vector2(-1852 + rng.randf_range(-7, 7), y + rng.randf_range(-9, 9)), i)
		_wall_tree(Vector2(1852 + rng.randf_range(-7, 7), y + rng.randf_range(-9, 9)), i + 1)
		i += 2


func _wall_tree(p: Vector2, i: int) -> void:
	draw_texture_rect(TEX_PINE if i % 2 == 1 else TEX_TREE, Rect2(p.x - 32, p.y - 48, 64, 96), false)
