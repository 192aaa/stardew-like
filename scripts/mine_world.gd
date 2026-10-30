extends Node2D
## 矿洞场景（另一个世界）：程序化绘制的地下洞穴，逐层生成矿岩与梯子
## 进矿洞入口后玩家被传送到这里（地面世界整体隐藏），E 踩入口梯子回地面

const ROOM := Rect2(-520, -360, 1040, 720)
const WALL := 48.0
const COLS := 8
const ROWS := 5
const GRID := Vector2(100, 100)
const GRID_ORIGIN := Vector2(-360, -220)
## 矿岩配色（石头/铜/铁/宝石）
const ORE_COL := {
	"stone": Color(0.52, 0.51, 0.54),
	"copper": Color(0.95, 0.60, 0.32),
	"iron": Color(0.78, 0.86, 0.94),
	"gem": Color(0.86, 0.55, 0.98),
}

## 当前层数（1 起，不进存档：出洞就重新从第 1 层算）
var depth := 1
## 矿岩数组：{pos: Vector2, ore: String, hp: int, max_hp: int, done: bool}
var rocks: Array = []
## 梯子是否已出现 / 梯子位置
var ladder_ready := false
var ladder_pos := Vector2.ZERO
## 入口梯子（回地面）与出生点
var exit_pos := Vector2(-430, 268)
var spawn_pos := Vector2(-360, 258)
var _wall_body: StaticBody2D
var _rock_body: Node2D
var _seed := 7


func _ready() -> void:
	z_as_relative = false
	z_index = -2400
	_build_walls()
	_rock_body = Node2D.new()
	_rock_body.name = "RockBodies"
	add_child(_rock_body)
	generate(1)


## 洞壁碰撞：四面石墙围住这个洞穴
func _build_walls() -> void:
	_wall_body = StaticBody2D.new()
	_wall_body.name = "Walls"
	add_child(_wall_body)
	var t := WALL * 2.0
	var frames := [
		[Vector2(0, ROOM.position.y + WALL), Vector2(ROOM.size.x, t)],
		[Vector2(0, ROOM.end.y - WALL), Vector2(ROOM.size.x, t)],
		[Vector2(ROOM.position.x + WALL, 0), Vector2(t, ROOM.size.y)],
		[Vector2(ROOM.end.x - WALL, 0), Vector2(t, ROOM.size.y)],
	]
	for f in frames:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = f[1]
		cs.shape = sh
		cs.position = f[0]
		_wall_body.add_child(cs)


## 生成第 d 层的矿岩：越深矿岩越多、铜铁与宝石比例越高
func generate(d: int) -> void:
	depth = maxi(1, d)
	_seed = int(Time.get_unix_time_from_system()) % 100000 + depth * 37
	ladder_ready = false
	ladder_pos = Vector2.ZERO
	rocks.clear()
	for c in _rock_body.get_children():
		c.queue_free()
	var cells: Array = []
	for j in ROWS:
		for i in COLS:
			var p := GRID_ORIGIN + Vector2(i * GRID.x, j * GRID.y)
			if p.distance_to(exit_pos) < 150.0 or p.distance_to(spawn_pos) < 120.0:
				continue
			cells.append(p + Vector2(randf_range(-14, 14), randf_range(-14, 14)))
	cells.shuffle()
	var n: int = mini(10 + (depth - 1) * 2, cells.size())
	var gem_c: float = clampf(float(depth - 2) * 0.06, 0.0, 0.25)
	var iron_c: float = clampf(0.10 + float(depth) * 0.03, 0.10, 0.36)
	for k in n:
		var r := randf()
		var ore := "stone"
		if r < gem_c:
			ore = "gem"
		elif r < gem_c + iron_c:
			ore = "iron"
		elif r < gem_c + iron_c + 0.24:
			ore = "copper"
		rocks.append({"pos": cells[k], "ore": ore, "hp": 2 if ore == "stone" else 3,
			"max_hp": 2 if ore == "stone" else 3, "done": false})
	_build_rock_bodies()
	queue_redraw()


## 给每块矿岩配一个圆形碰撞，走路不会被穿过去
func _build_rock_bodies() -> void:
	for i in rocks.size():
		_add_rock_body(i)


func _add_rock_body(i: int) -> void:
	var b := StaticBody2D.new()
	b.name = "r%d" % i
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 22.0
	cs.shape = sh
	cs.position = Vector2(0, 4)
	b.position = rocks[i].pos - Vector2(0, 4)
	b.add_child(cs)
	_rock_body.add_child(b)


func _free_rock_body(i: int) -> void:
	var b := _rock_body.get_node_or_null("r%d" % i)
	if b != null:
		b.queue_free()


## 玩家前方最近的未挖矿岩（命中半径内），没有返回 -1
## 注意：p 是世界坐标，矿岩存的是本节点内的局部坐标，先转局部再比距离
func rock_near(p: Vector2, r: float) -> int:
	var lp := to_local(p)
	var best := -1
	var best_d := r
	for i in rocks.size():
		if bool(rocks[i].done):
			continue
		var d: float = lp.distance_to(rocks[i].pos)
		if d < best_d:
			best_d = d
			best = i
	return best


## 出生点 / 入口梯子的世界坐标
func spawn_global() -> Vector2:
	return to_global(spawn_pos)


func rock_pos(i: int) -> Vector2:
	if i < 0 or i >= rocks.size():
		return Vector2.ZERO
	return rocks[i].pos


## 敲一下某块矿岩：返回 {result: "hit"/"break"/"none", ore, pos}
func hit(i: int) -> Dictionary:
	if i < 0 or i >= rocks.size():
		return {"result": "none"}
	var r: Dictionary = rocks[i]
	if bool(r.done):
		return {"result": "none"}
	r.hp = int(r.hp) - 1
	var pos: Vector2 = r.pos
	if int(r.hp) > 0:
		queue_redraw()
		return {"result": "hit", "ore": String(r.ore), "pos": to_global(pos)}
	r.done = true
	_free_rock_body(i)
	_check_ladder()
	queue_redraw()
	return {"result": "break", "ore": String(r.ore), "pos": to_global(pos)}


## 挖够六成矿岩，梯子出现在最后挖空的那块矿岩上
func _check_ladder() -> void:
	if ladder_ready:
		return
	var done := 0
	for r in rocks:
		if bool(r.done):
			done += 1
	if done < ceili(float(rocks.size()) * 0.6):
		return
	ladder_ready = true
	for r in rocks:
		if bool(r.done):
			ladder_pos = r.pos
			break


func done_count() -> int:
	var n := 0
	for r in rocks:
		if bool(r.done):
			n += 1
	return n


func near_exit(p: Vector2) -> bool:
	return to_local(p).distance_to(exit_pos) < 64.0


func near_ladder(p: Vector2) -> bool:
	return ladder_ready and to_local(p).distance_to(ladder_pos) < 64.0


func _draw() -> void:
	# 洞壁与地面
	draw_rect(ROOM, Color(0.10, 0.10, 0.12))
	draw_rect(ROOM.grow(-WALL), Color(0.21, 0.20, 0.23))
	# 地面碎石点（伪随机但每层固定）
	var fy := ROOM.position.y + WALL
	while fy < ROOM.end.y - WALL:
		var fx := ROOM.position.x + WALL
		while fx < ROOM.end.x - WALL:
			var h := int((int(fx) * 31 + int(fy) * 17 + _seed) * 7919) % 5
			if h < 2:
				draw_rect(Rect2(Vector2(fx + 12.0, fy + 16.0),
						Vector2(7.0 + h * 4.0, 5.0 + h * 2.0)),
						Color(0.26, 0.25, 0.29))
			fx += 80.0
		fy += 80.0
	# 四壁石块纹理
	var step := 48.0
	var wx := ROOM.position.x
	while wx < ROOM.end.x - 1.0:
		var wy := ROOM.position.y
		while wy < ROOM.end.y - 1.0:
			var in_wall := wx < ROOM.position.x + WALL or wx >= ROOM.end.x - WALL \
					or wy < ROOM.position.y + WALL or wy >= ROOM.end.y - WALL
			if in_wall:
				var h2 := int((int(wx) * 7 + int(wy) * 13 + _seed) * 1103) % 4
				draw_rect(Rect2(Vector2(wx + 1.0, wy + 1.0), Vector2(step - 3.0, step - 3.0)),
						Color(0.29 + h2 * 0.035, 0.28 + h2 * 0.035, 0.32 + h2 * 0.035))
			wy += step
		wx += step
	# 壁火：四角暖光
	for tp in [Vector2(-430, -300), Vector2(430, -300),
			Vector2(-430, 300), Vector2(430, 300)]:
		draw_circle(tp, 30.0, Color(1, 0.72, 0.35, 0.05))
		draw_circle(tp, 16.0, Color(1, 0.75, 0.4, 0.09))
		draw_circle(tp, 5.0, Color(1, 0.78, 0.45))
	# 入口梯子（回地面）与层间梯子
	_draw_ladder(exit_pos, false)
	if ladder_ready:
		_draw_ladder(ladder_pos, true)
	# 矿岩
	for r in rocks:
		_draw_rock(r)


func _draw_rock(r: Dictionary) -> void:
	if bool(r.done):
		return
	var p: Vector2 = r.pos
	draw_circle(p + Vector2(0, 8), 25.0, Color(0, 0, 0, 0.3))
	draw_circle(p, 25.0, Color(0.34, 0.33, 0.37))
	draw_circle(p + Vector2(-5, -6), 19.0, Color(0.44, 0.43, 0.47))
	var ore := String(r.ore)
	if ore != "stone":
		var oc: Color = ORE_COL[ore]
		for k in 3:
			draw_circle(p + Vector2(-11 + k * 10, -4 + (k % 2) * 11), 4.5, oc)
			draw_circle(p + Vector2(-11 + k * 10, -4 + (k % 2) * 11), 2.0, oc.lightened(0.35))
	if int(r.hp) < int(r.max_hp):
		var w := 38.0
		draw_rect(Rect2(p + Vector2(-w * 0.5, -36), Vector2(w, 5)), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(p + Vector2(-w * 0.5, -36),
				Vector2(w * float(r.hp) / float(r.max_hp), 5)), Color(0.86, 0.32, 0.32))


func _draw_ladder(p: Vector2, glow: bool) -> void:
	if glow:
		draw_circle(p + Vector2(0, -4), 36.0, Color(1, 0.9, 0.55, 0.10))
		draw_circle(p + Vector2(0, -4), 24.0, Color(1, 0.9, 0.55, 0.12))
	draw_rect(Rect2(p + Vector2(-15, -28), Vector2(5, 56)), Color(0.55, 0.38, 0.22))
	draw_rect(Rect2(p + Vector2(10, -28), Vector2(5, 56)), Color(0.55, 0.38, 0.22))
	for i in 4:
		draw_rect(Rect2(p + Vector2(-15, -22 + i * 14), Vector2(30, 5)),
				Color(0.72, 0.52, 0.30))
