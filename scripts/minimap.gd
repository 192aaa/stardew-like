extends Control
## 右上角小地图：无限地图下以玩家为中心的固定视窗，绘制农田/建筑/矿洞/外围林地与两名玩家
## 由 main.gd 每帧刷新；按 Tab 在「小/大」两档之间切换

const SIZE_S := Vector2(190, 130)
const SIZE_L := Vector2(380, 260)
## 地图视窗覆盖的世界尺寸（跟随玩家移动），比例与面板一致
const VIEW_W := 2800.0
const VIEW_H := 1915.0
## 与 world_chunks.CHUNK 一致，用来画已加载的区块
const CELL := 512.0

const C_GROUND := {
	"spring": Color(0.3, 0.44, 0.24),
	"summer": Color(0.36, 0.47, 0.21),
	"autumn": Color(0.46, 0.36, 0.17),
	"winter": Color(0.7, 0.77, 0.86),
}
const C_WATER := Color(0.28, 0.52, 0.85)
const C_WOOD := Color(0.78, 0.58, 0.34)
const C_BARN := Color(0.75, 0.35, 0.3)
const C_MINE := Color(0.3, 0.28, 0.34)
const C_FOREST := Color(0.16, 0.3, 0.16)
const C_GARDEN := Color(0.58, 0.78, 0.42)
const C_SOIL := Color(0.68, 0.48, 0.3)
const C_CROP := Color(0.55, 0.9, 0.42)
const C_MACHINE := Color(0.95, 0.75, 0.3)
const C_SELF := Color(1, 1, 1)
const C_FRIEND := Color(0.35, 0.9, 1.0)
const C_NPC := Color(0.98, 0.86, 0.32)
const C_PET := Color(0.9, 0.5, 0.9)
const C_ANIMAL := Color(0.97, 0.97, 0.95)
const C_OUTLINE := Color(0.12, 0.1, 0.08)

var main: Node2D
var big := false


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP  # 点一下地图就能放大/缩小
	clip_contents = true  # 视窗跟随玩家后，区块/建筑矩形会超出面板，裁掉避免盖住 HUD
	gui_input.connect(_on_gui_input)
	_apply_size()


func _apply_size() -> void:
	var s: Vector2 = SIZE_L if big else SIZE_S
	offset_left = -s.x - 16.0
	offset_right = -16.0
	offset_top = 56.0
	offset_bottom = 56.0 + s.y
	custom_minimum_size = s
	queue_redraw()


## Tab 或点击地图切换大小
func toggle() -> void:
	big = not big
	_apply_size()


func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		toggle()
		accept_event()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## 当前视窗（以玩家为中心的世界矩形）
func _view() -> Rect2:
	var c := Vector2.ZERO
	if main != null:
		c = (main.player as Node2D).position
	return Rect2(c - Vector2(VIEW_W, VIEW_H) * 0.5, Vector2(VIEW_W, VIEW_H))


func _k() -> float:
	return minf(size.x / VIEW_W, size.y / VIEW_H)


func _off() -> Vector2:
	return -_view().position * _k()


## 世界坐标 -> 地图坐标
func _p(w: Vector2) -> Vector2:
	return w * _k() + _off()


## 世界矩形 -> 地图矩形
func _r(w: Rect2) -> Rect2:
	var s := w.size * _k()
	return Rect2(_p(w.position), Vector2(maxf(s.x, 1.5), maxf(s.y, 1.5)))


func _dot(w: Vector2, col: Color, rad := 1.8) -> void:
	draw_circle(_p(w), rad, col)


func _draw() -> void:
	if main == null:
		return
	var dec = main.decor
	var farm = main.farm
	var gid := String(Game.season().id)
	var bg: Color = C_GROUND.get(gid, C_GROUND.spring)
	# 底板 + 边框
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	# 无限地图：已加载的区块（核心农场外的部分）铺深绿，一眼看出外面还有可走的地
	var chunk_col: Color = C_FOREST if gid != "winter" else Color(0.52, 0.62, 0.58)
	if main.chunks != null:
		for c in main.chunks.active_cells():
			var cr := Rect2(Vector2(c) * CELL, Vector2(CELL, CELL))
			if cr.intersects(dec.WORLD):
				continue
			draw_rect(_r(cr), chunk_col)
	# 三区底色：西侧森林 / 东侧河流，一眼看清能去哪
	draw_rect(_r(dec.FOREST_RECT), C_FOREST)
	draw_rect(_r(dec.RIVER_RECT), C_WATER)
	# 地形要素
	draw_rect(_r(dec.POND_RECT), C_WATER)
	draw_rect(_r(dec.GARDEN_RECT), C_GARDEN)
	draw_rect(_r(dec.MINE_ZONE), C_MINE)
	# 农田地块：已开垦棕色，有作物叠绿色
	for c in farm.tiles:
		var t: Dictionary = farm.tiles[c]
		var cell := Vector2i(c)
		draw_rect(_r(Rect2(cell.x * 32, cell.y * 32, 32, 32)), C_SOIL)
		if t.crop != "":
			_dot(Vector2(cell.x * 32 + 16, cell.y * 32 + 16), C_CROP, 2.0)
	# 建筑（描边 + 色块，保证小尺寸下也能分辨）
	for br in [
		[dec.HOUSE_RECT, C_WOOD], [dec.STALL_RECT, C_WOOD],
		[Rect2(dec.BOARD_POS - Vector2(14, 14), Vector2(28, 28)), C_WOOD],
		[Rect2(dec.COOP_POS - Vector2(20, 16), Vector2(40, 32)), C_WOOD],
		[Rect2(dec.BARN_POS - Vector2(22, 19), Vector2(44, 38)), C_BARN],
	]:
		var rr := _r(br[0])
		draw_rect(rr, C_OUTLINE, false, 1.0)
		draw_rect(rr.grow(-0.5), br[1])
	_dot(dec.WELL_POS, C_WATER, 2.8)
	# 加工机 / 矿岩
	for c2 in farm.machines:
		var cc2 := Vector2i(c2)
		_dot(Vector2(cc2.x * 32 + 16, cc2.y * 32 + 16), C_MACHINE, 1.6)
	for o in main.mine._ores:
		var kind := String(o.kind)
		var oc := Color(0.85, 0.55, 0.3)
		if kind == "iron":
			oc = Color(0.8, 0.82, 0.86)
		elif kind == "gem":
			oc = Color(0.55, 0.9, 0.95)
		_dot(o.pos, oc, 1.8)
	# 村民 / 宠物 / 家畜
	for v in main._villagers:
		_dot((v as Node2D).position, C_NPC, 2.0)
	for p in main._pets:
		_dot((p as Node2D).position, C_PET, 1.8)
	for n in main._chickens + main._cows + main._sheeps:
		_dot((n as Node2D).position, C_ANIMAL, 1.6)
	# 两名玩家（自己白点带描边，好友青色）
	if main._shadow != null:
		_dot(main._shadow.global_position, C_OUTLINE, 3.4)
		_dot(main._shadow.global_position, C_FRIEND, 2.6)
	_dot(main.player.position, C_OUTLINE, 3.4)
	_dot(main.player.position, C_SELF, 2.6)
	# 当前视野方框
	var cam: Camera2D = main.player.get_node("Camera")
	var half := get_viewport().get_visible_rect().size * 0.5 / cam.zoom.x
	draw_rect(_r(Rect2(cam.get_screen_center_position() - half, half * 2.0)),
			Color(1, 1, 1, 0.35), false, 1.0)
	# 外框
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.09, 0.07, 0.9), false, 2.0)
	if big:
		draw_string(main._ui_font, Vector2(6, 14), "农场 · %s季" % Game.season_name(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
