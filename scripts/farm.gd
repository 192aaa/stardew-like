extends Node2D
## 农田系统：网格地块的开垦/浇水/种植/逐日生长/收获，全部用 _draw 自绘

const CELL := 32
const TEX_SOIL := preload("res://assets/soil.png")
const TEX_SOIL_WET := preload("res://assets/soil_wet.png")
const TEX_CROPS := preload("res://assets/crops.png")
const TEX_SCARECROW := preload("res://assets/scarecrow.png")
const TEX_SPRINKLER := preload("res://assets/sprinkler.png")
const SCARE_RADIUS := 150.0
const ZONES := [
	Rect2(-420, -320, 240, 170),
	Rect2(250, -260, 270, 140),
	Rect2(-520, 260, 220, 120),
	Rect2(180, 240, 250, 120),
]

## 全局格坐标 -> {tilled, watered, crop, stage, wtoday}
var tiles := {}
## 洒水器占用的格子 / 稻草人占用的格子与位置
var sprinklers := {}
var scare_cells := {}
var protectors: Array[Vector2] = []
var _target := Vector2i.ZERO
var _target_valid := false
var _preview := ""
var _preview_cell := Vector2i.ZERO
var _preview_valid := false


func zone_at(p: Vector2) -> bool:
	for z in ZONES:
		if z.has_point(p):
			return true
	return false


## 返回 Vector2i 或 null（不在农田内）
func cell_at(p: Vector2) -> Variant:
	if not zone_at(p):
		return null
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))


func set_target(cell: Vector2i, valid: bool) -> void:
	if cell != _target or valid != _target_valid:
		_target = cell
		_target_valid = valid
		queue_redraw()


## 放置预览（稻草人 / 洒水器）
func set_preview(mode: String, cell: Vector2i, valid: bool) -> void:
	if mode != _preview or cell != _preview_cell or valid != _preview_valid:
		_preview = mode
		_preview_cell = cell
		_preview_valid = valid
		queue_redraw()


## 以下 try_* 返回 "" 表示成功，否则返回错误提示
func try_till(c: Vector2i) -> String:
	if sprinklers.has(c):
		return "洒水器占着这里"
	if scare_cells.has(c):
		return "稻草人立在这里"
	if tiles.has(c):
		if tiles[c].crop != "":
			return "作物还长在这里呢"
		if tiles[c].tilled:
			return "这块地已经开垦过了"
	tiles[c] = {"tilled": true, "watered": false, "crop": "", "stage": 0, "wtoday": false}
	queue_redraw()
	return ""


func try_water(c: Vector2i) -> String:
	if not tiles.has(c):
		return "先用锄头开垦这块地"
	tiles[c].watered = true
	tiles[c].wtoday = true
	queue_redraw()
	return ""


func try_plant(c: Vector2i, id: String) -> String:
	if sprinklers.has(c):
		return "洒水器占着这里"
	if scare_cells.has(c):
		return "稻草人立在这里"
	if not tiles.has(c):
		return "先用锄头开垦这块地"
	if tiles[c].crop != "":
		return "这里已经种了作物"
	tiles[c].crop = id
	tiles[c].stage = 0
	queue_redraw()
	return ""


## 收获成熟作物，返回作物 id；无则返回 ""
func try_harvest(c: Vector2i) -> String:
	if not tiles.has(c):
		return ""
	var t: Dictionary = tiles[c]
	if t.crop == "" or t.stage < Game.CROPS[t.crop].days:
		return ""
	var id: String = t.crop
	tiles.erase(c)
	queue_redraw()
	return id


## 放置稻草人（占用格子，守护周围作物）
func place_scarecrow(c: Vector2i) -> String:
	if sprinklers.has(c):
		return "洒水器占着这里"
	if scare_cells.has(c):
		return "这里已经有稻草人"
	if tiles.has(c) and tiles[c].crop != "":
		return "先收获这里的作物"
	scare_cells[c] = true
	protectors.append(Vector2(c.x * CELL + 16, c.y * CELL + 16))
	queue_redraw()
	return ""


## 放置洒水器（清晨自动浇灌四邻格）
func place_sprinkler(c: Vector2i) -> String:
	if sprinklers.has(c):
		return "这里已经有洒水器"
	if scare_cells.has(c):
		return "稻草人立在这里"
	if tiles.has(c) and tiles[c].crop != "":
		return "先收获这里的作物"
	sprinklers[c] = true
	queue_redraw()
	return ""


## 格子中心是否受稻草人保护
func is_protected(p: Vector2) -> bool:
	for q in protectors:
		if q.distance_to(p) <= SCARE_RADIUS:
			return true
	return false


## 新的一天：乌鸦偷食 unprotected 作物 → 浇过水的作物长一节 → 洒水器浇灌 → 湿润重置。
## 返回被乌鸦吃掉的作物数。
func on_new_day() -> int:
	var lost := 0
	for c in tiles.duplicate():
		var t: Dictionary = tiles[c]
		if t.crop != "":
			var center := Vector2(c.x * CELL + 16, c.y * CELL + 16)
			if not is_protected(center) and randf() < 0.12:
				tiles.erase(c)
				lost += 1
				continue
		if t.crop != "" and t.wtoday and t.stage < Game.CROPS[t.crop].days:
			t.stage += 1
		t.watered = false
		t.wtoday = false
	for s in sprinklers:  # 洒水器清晨自动浇水
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = s + off
			if tiles.has(n) and tiles[n].crop != "":
				tiles[n].watered = true
				tiles[n].wtoday = true
	queue_redraw()
	return lost


func _draw() -> void:
	for c in tiles:
		var t: Dictionary = tiles[c]
		var r := Rect2(c.x * CELL, c.y * CELL, CELL, CELL)
		draw_texture_rect(TEX_SOIL_WET if t.watered else TEX_SOIL, r, false)
		if t.crop != "":
			# 图集：0-3 列防风草（苗/小/大/成熟），4-7 列土豆
			var idx: int = mini(t.stage, 3)
			var col := 0 if t.crop == "parsnip" else 4
			draw_texture_rect_region(TEX_CROPS, r, Rect2((col + idx) * CELL, 0, CELL, CELL))
	for s in sprinklers:
		draw_texture_rect(TEX_SPRINKLER, Rect2(s.x * CELL, s.y * CELL, CELL, CELL), false)
	for sc in scare_cells:
		draw_texture_rect(TEX_SCARECROW, Rect2(sc.x * CELL, sc.y * CELL - 48, 32, 64), false)
	if _preview_valid and _preview != "":
		var pr := Rect2(_preview_cell.x * CELL, _preview_cell.y * CELL - 48, 32, 64) \
				if _preview == "scarecrow" \
				else Rect2(_preview_cell.x * CELL, _preview_cell.y * CELL, CELL, CELL)
		var tex := TEX_SCARECROW if _preview == "scarecrow" else TEX_SPRINKLER
		draw_texture_rect(tex, pr, false, Color(1, 1, 1, 0.55))
	if _target_valid:
		var trect := Rect2(_target.x * CELL + 1, _target.y * CELL + 1, CELL - 2, CELL - 2)
		draw_rect(trect, Color(1, 1, 1, 0.85), false, 2.0)
