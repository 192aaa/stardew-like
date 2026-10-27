extends Node2D
## 农田系统：网格地块的开垦/浇水/种植/逐日生长/收获，全部用 _draw 自绘

const CELL := 32
const TEX_SOIL := preload("res://assets/soil.png")
const TEX_SOIL_WET := preload("res://assets/soil_wet.png")
const TEX_CROPS := preload("res://assets/crops.png")
const TEX_SCARECROW := preload("res://assets/scarecrow.png")
const TEX_SPRINKLER := preload("res://assets/sprinkler.png")
const TEX_MACHINE_MAYO := preload("res://assets/machine_mayo.png")
const TEX_MACHINE_JAM := preload("res://assets/machine_jam.png")
const TEX_STOVE := preload("res://assets/stove.png")
const TEX_FURNACE := preload("res://assets/furnace.png")
const TEX_CHEESE := preload("res://assets/machine_cheese.png")
const TEX_SPRINKLER2 := preload("res://assets/sprinkler2.png")
const SCARE_RADIUS := 150.0
## 作物 -> 图集列（每株占 4 列：苗/小/大/成熟）
const CROP_COL := {"parsnip": 0, "potato": 4, "straw": 8, "pumpkin": 12, "corn": 16, "blue": 20}
const ZONES := [
	Rect2(-420, -320, 240, 170),
	Rect2(250, -260, 270, 140),
	Rect2(-520, 260, 220, 120),
	Rect2(180, 240, 250, 120),
]

## 全局格坐标 -> {tilled, watered, crop, stage, wtoday}
var tiles := {}
## 洒水器占用的格子（浇四邻）/ 高级洒水器（金，浇 3x3）/ 稻草人占用的格子与位置
var sprinklers := {}
var sprinklers2 := {}
var scare_cells := {}
var protectors: Array[Vector2] = []
## 加工机：格子 -> {type: "mayo"/"jam", input: 原料id, ready: 完工产品id}
var machines := {}
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
	if sprinklers.has(c) or sprinklers2.has(c):
		return "洒水器占着这里"
	if scare_cells.has(c):
		return "稻草人立在这里"
	if machines.has(c):
		return "机器停在这里"
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
	if sprinklers.has(c) or sprinklers2.has(c):
		return "洒水器占着这里"
	if scare_cells.has(c):
		return "稻草人立在这里"
	if machines.has(c):
		return "机器停在这里"
	if not tiles.has(c):
		return "先用锄头开垦这块地"
	if tiles[c].crop != "":
		return "这里已经种了作物"
	tiles[c].crop = id
	tiles[c].stage = 0
	queue_redraw()
	return ""


## 收获成熟作物，返回作物 id；无则返回 ""。
## 多季作物（regrow>0）收获后保留植株，回退 regrow 节继续长，不用重种
func try_harvest(c: Vector2i) -> String:
	if not tiles.has(c):
		return ""
	var t: Dictionary = tiles[c]
	if t.crop == "" or t.stage < Game.CROPS[t.crop].days:
		return ""
	var id: String = t.crop
	var regrow: int = int(Game.CROPS[id].get("regrow", 0))
	if regrow > 0:
		t.stage = maxi(1, int(Game.CROPS[id].days) - regrow)
	else:
		tiles.erase(c)
	queue_redraw()
	return id


## 放置稻草人（占用格子，守护周围作物）
func place_scarecrow(c: Vector2i) -> String:
	if sprinklers.has(c) or sprinklers2.has(c):
		return "洒水器占着这里"
	if scare_cells.has(c):
		return "这里已经有稻草人"
	if machines.has(c):
		return "机器停在这里"
	if tiles.has(c) and tiles[c].crop != "":
		return "先收获这里的作物"
	scare_cells[c] = true
	protectors.append(Vector2(c.x * CELL + 16, c.y * CELL + 16))
	queue_redraw()
	return ""


## 放置洒水器（清晨自动浇灌四邻格）
func place_sprinkler(c: Vector2i) -> String:
	if sprinklers.has(c) or sprinklers2.has(c):
		return "这里已经有洒水器"
	if scare_cells.has(c):
		return "稻草人立在这里"
	if machines.has(c):
		return "机器停在这里"
	if tiles.has(c) and tiles[c].crop != "":
		return "先收获这里的作物"
	sprinklers[c] = true
	queue_redraw()
	return ""


## 放置高级洒水器（金色喷头，清晨自动浇灌 3x3）
func place_sprinkler2(c: Vector2i) -> String:
	if sprinklers.has(c) or sprinklers2.has(c):
		return "这里已经有洒水器"
	if scare_cells.has(c):
		return "稻草人立在这里"
	if machines.has(c):
		return "机器停在这里"
	if tiles.has(c) and tiles[c].crop != "":
		return "先收获这里的作物"
	sprinklers2[c] = true
	queue_redraw()
	return ""


## 放置加工机（蛋黄酱机/加工机/灶台/熔炉/奶酪机，占一格）
func place_machine(c: Vector2i, type: String) -> String:
	if machines.has(c):
		return "这里已经有机器了"
	if sprinklers.has(c) or sprinklers2.has(c):
		return "洒水器占着这里"
	if scare_cells.has(c):
		return "稻草人立在这里"
	if tiles.has(c) and tiles[c].crop != "":
		return "先收获这里的作物"
	machines[c] = {"type": type, "input": "", "ready": ""}
	queue_redraw()
	return ""


## 格子中心是否受稻草人保护
func is_protected(p: Vector2) -> bool:
	for q in protectors:
		if q.distance_to(p) <= SCARE_RADIUS:
			return true
	return false


## 施肥：对已种作物的地块立刻生长一节；返回 "" 成功，否则错误提示
func try_fertilize(c: Vector2i) -> String:
	if not tiles.has(c):
		return "这里还没有种作物"
	var t: Dictionary = tiles[c]
	if t.crop == "":
		return "这里还没有种作物"
	if t.stage >= Game.CROPS[t.crop].days:
		return "%s已经成熟了" % Game.CROPS[t.crop].name
	t.stage += 1
	queue_redraw()
	return ""


## 新的一天：乌鸦偷食 unprotected 作物 → 雨天/浇过水的作物长一节 → 洒水器浇灌 → 湿润重置。
## 雨天清晨所有耕地自动湿润。返回被乌鸦吃掉的作物数。
func on_new_day(raining := false) -> int:
	var lost := 0
	for c in tiles.duplicate():
		var t: Dictionary = tiles[c]
		if t.crop != "":
			var center := Vector2(c.x * CELL + 16, c.y * CELL + 16)
			if not is_protected(center) and randf() < 0.12:
				tiles.erase(c)
				lost += 1
				continue
		if t.crop != "" and (t.wtoday or raining) and t.stage < Game.CROPS[t.crop].days:
			t.stage += 1
		t.watered = raining
		t.wtoday = raining
	for s in sprinklers:  # 洒水器清晨自动浇水
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = s + off
			if tiles.has(n) and tiles[n].crop != "":
				tiles[n].watered = true
				tiles[n].wtoday = true
	for s2 in sprinklers2:  # 高级洒水器清晨浇灌 3x3
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n2: Vector2i = s2 + Vector2i(dx, dy)
				if tiles.has(n2) and tiles[n2].crop != "":
					tiles[n2].watered = true
					tiles[n2].wtoday = true
	for c in machines:  # 加工机过夜把原料变成产品（灶台无转化，跳过）
		var m: Dictionary = machines[c]
		if not Game.MACHINE_INPUTS.has(m.type):
			continue
		if m.input != "" and m.ready == "":
			var want: Dictionary = Game.MACHINE_INPUTS[m.type]
			if want.has(m.input):
				m.ready = want[m.input]
				m.input = ""
	queue_redraw()
	return lost


## 存档恢复：按 JSON 数据重建地块/洒水器/稻草人/加工机并重绘
func restore_from(d: Dictionary) -> void:
	tiles.clear()
	sprinklers.clear()
	sprinklers2.clear()
	scare_cells.clear()
	protectors.clear()
	machines.clear()
	for row in d.get("tiles", []):
		var c := Vector2i(int(row[0]), int(row[1]))
		tiles[c] = {
			"tilled": int(row[2]) == 1,
			"watered": int(row[3]) == 1,
			"crop": String(row[4]),
			"stage": int(row[5]),
			"wtoday": int(row[6]) == 1,
		}
	for s in d.get("sprinklers", []):
		sprinklers[Vector2i(int(s[0]), int(s[1]))] = true
	for s in d.get("sprinklers2", []):
		sprinklers2[Vector2i(int(s[0]), int(s[1]))] = true
	for s in d.get("scarecrows", []):
		var sc := Vector2i(int(s[0]), int(s[1]))
		scare_cells[sc] = true
		protectors.append(Vector2(sc.x * CELL + 16, sc.y * CELL + 16))
	for row2 in d.get("machines", []):
		machines[Vector2i(int(row2[0]), int(row2[1]))] = {
			"type": String(row2[2]), "input": String(row2[3]), "ready": String(row2[4]),
		}
	queue_redraw()


func _draw() -> void:
	for c in tiles:
		var t: Dictionary = tiles[c]
		var r := Rect2(c.x * CELL, c.y * CELL, CELL, CELL)
		draw_texture_rect(TEX_SOIL_WET if t.watered else TEX_SOIL, r, false)
		if t.crop != "":
			# 图集：每株作物占 4 列（苗/小/大/成熟），按生长进度取列，熟透才画成熟贴图
			var days: int = Game.CROPS[t.crop].days
			var idx: int = clampi(int(floor(t.stage * 3.0 / days)), 0, 3)
			var col: int = CROP_COL[t.crop]
			draw_texture_rect_region(TEX_CROPS, r, Rect2((col + idx) * CELL, 0, CELL, CELL))
	for s in sprinklers:
		draw_texture_rect(TEX_SPRINKLER, Rect2(s.x * CELL, s.y * CELL, CELL, CELL), false)
	for s in sprinklers2:  # 高级洒水器：金色喷头
		draw_texture_rect(TEX_SPRINKLER2, Rect2(s.x * CELL, s.y * CELL, CELL, CELL), false)
	for c in machines:
		var m: Dictionary = machines[c]
		var tex: Texture2D = TEX_MACHINE_MAYO
		var mh := 24.0
		if m.type == "jam":
			tex = TEX_MACHINE_JAM
			mh = 22.0
		elif m.type == "stove":
			tex = TEX_STOVE
			mh = 28.0
		elif m.type == "furnace":
			tex = TEX_FURNACE
			mh = 26.0
		elif m.type == "cheese":
			tex = TEX_CHEESE
			mh = 24.0
		draw_texture_rect(tex, Rect2(c.x * CELL, c.y * CELL + CELL - mh, CELL, mh), false)
		if m.ready != "":  # 完工标记：机器上方亮一颗金星
			draw_rect(Rect2(c.x * CELL + 13, c.y * CELL - 12, 6, 6), Color(1, 0.9, 0.3))
			draw_rect(Rect2(c.x * CELL + 13, c.y * CELL - 12, 6, 6), Color(0.5, 0.4, 0.1), false, 1.0)
		elif m.input != "":  # 加工中标记：小蓝点
			draw_rect(Rect2(c.x * CELL + 13, c.y * CELL - 12, 6, 6), Color(0.4, 0.7, 1))
	for sc in scare_cells:
		draw_texture_rect(TEX_SCARECROW, Rect2(sc.x * CELL, sc.y * CELL - 48, 32, 64), false)
	if _preview_valid and _preview != "":
		var pr: Rect2
		var ptex: Texture2D
		if _preview == "scarecrow":
			pr = Rect2(_preview_cell.x * CELL, _preview_cell.y * CELL - 48, 32, 64)
			ptex = TEX_SCARECROW
		elif _preview == "sprinkler":
			pr = Rect2(_preview_cell.x * CELL, _preview_cell.y * CELL, CELL, CELL)
			ptex = TEX_SPRINKLER
		elif _preview == "sprinkler2":
			pr = Rect2(_preview_cell.x * CELL, _preview_cell.y * CELL, CELL, CELL)
			ptex = TEX_SPRINKLER2
		else:  # 加工机/灶台/熔炉/奶酪机预览
			var pmh := 24.0
			if _preview == "jam":
				pmh = 22.0
				ptex = TEX_MACHINE_JAM
			elif _preview == "stove":
				pmh = 28.0
				ptex = TEX_STOVE
			elif _preview == "furnace":
				pmh = 26.0
				ptex = TEX_FURNACE
			elif _preview == "cheese":
				pmh = 24.0
				ptex = TEX_CHEESE
			pr = Rect2(_preview_cell.x * CELL, _preview_cell.y * CELL + CELL - pmh, CELL, pmh)
			if _preview == "mayo":
				ptex = TEX_MACHINE_MAYO
		draw_texture_rect(ptex, pr, false, Color(1, 1, 1, 0.55))
	if _target_valid:
		var trect := Rect2(_target.x * CELL + 1, _target.y * CELL + 1, CELL - 2, CELL - 2)
		draw_rect(trect, Color(1, 1, 1, 0.85), false, 2.0)
