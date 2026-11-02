extends Node2D
## 矿洞场景（另一个世界）：程序化绘制的地下洞穴，逐层生成矿岩与梯子
## 进矿洞入口后玩家被传送到这里（地面世界整体隐藏），E 踩入口梯子回地面

const ROOM := Rect2(-520, -360, 1040, 720)
const WALL := 48.0
const COLS := 8
const ROWS := 5
const GRID := Vector2(100, 100)
const GRID_ORIGIN := Vector2(-360, -220)
## 矿岩配色（石头/铜/铁/宝石/金/铱）
const ORE_COL := {
	"stone": Color(0.52, 0.51, 0.54),
	"copper": Color(0.95, 0.60, 0.32),
	"iron": Color(0.78, 0.86, 0.94),
	"gem": Color(0.86, 0.55, 0.98),
	"gold": Color(1.0, 0.84, 0.30),
	"iridium": Color(0.62, 0.42, 0.90),
}
## 矿岩硬度：石 2，铜/铁/宝石 3，金 4，铱 5（镐头等级每下伤害更高）
const ORE_HP := {"stone": 2, "copper": 3, "iron": 3, "gem": 3, "gold": 4, "iridium": 5}

## 怪物撞到玩家（扣生命）：dmg 伤害值，pos 世界坐标（飘字用）
signal player_hurt(dmg: int, pos: Vector2)

## 当前层数（1 起，不进存档：出洞就重新从第 1 层算）
var depth := 1
## 矿岩数组：{pos: Vector2, ore: String, hp: int, max_hp: int, done: bool}
var rocks: Array = []
## 洞内怪物：{pos: 局部坐标, kind, hp, atk, cd, t, dir}
var monsters: Array = []
## 宝箱层（每 3 层一个）：位置与开合状态
var has_chest := false
var chest_open := false
var chest_pos := Vector2.ZERO

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


## 生成第 d 层：矿岩越多、深层出现金矿/铱矿，每 3 层有宝箱，深层有怪物
func generate(d: int) -> void:
	depth = maxi(1, d)
	_seed = int(Time.get_unix_time_from_system()) % 100000 + depth * 37
	ladder_ready = false
	ladder_pos = Vector2.ZERO
	rocks.clear()
	monsters.clear()
	has_chest = false
	chest_open = false
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
	# 金矿第 4 层起出现，铱矿第 7 层起出现，深度越大概率越高
	var gold_c: float = 0.0
	var irid_c: float = 0.0
	if depth >= 4:
		gold_c = clampf(float(depth - 3) * 0.05, 0.04, 0.22)
	if depth >= 7:
		irid_c = clampf(float(depth - 6) * 0.045, 0.03, 0.20)
	for k in n:
		var r := randf()
		var ore := "stone"
		if r < irid_c:
			ore = "iridium"
		elif r < irid_c + gold_c:
			ore = "gold"
		elif r < irid_c + gold_c + gem_c:
			ore = "gem"
		elif r < irid_c + gold_c + gem_c + iron_c:
			ore = "iron"
		elif r < irid_c + gold_c + gem_c + iron_c + 0.24:
			ore = "copper"
		var hp: int = int(ORE_HP[ore])
		rocks.append({"pos": cells[k], "ore": ore, "hp": hp, "max_hp": hp, "done": false})
	# 宝箱层：第 3/6/9/12 层，找一块没放矿岩的空地
	if depth % 3 == 0 and n < cells.size():
		has_chest = true
		chest_pos = cells[n]
	_build_rock_bodies()
	_spawn_monsters()
	queue_redraw()


## 按深度放怪物：第 1~2 层 1 只史莱姆，之后逐渐变多，第 3 层起混入蝙蝠
func _spawn_monsters() -> void:
	var total: int = mini(1 + int(depth / 3.0), 4)
	var inner := ROOM.grow(-WALL - 20.0)
	for k in total:
		var p := Vector2.ZERO
		for try_i in 12:
			p = Vector2(randf_range(inner.position.x, inner.end.x),
					randf_range(inner.position.y, inner.end.y))
			if p.distance_to(spawn_pos) < 200.0 or p.distance_to(exit_pos) < 140.0:
				continue
			if has_chest and p.distance_to(chest_pos) < 90.0:
				continue
			break
		var bat := depth >= 3 and (randi() % 3 == 0)
		var kind := "bat" if bat else "slime"
		monsters.append({"pos": p, "kind": kind, "hp": 2, "atk": 6 if bat else 8,
			"cd": randf_range(0.2, 0.9), "t": randf_range(0.0, 6.0), "dir": Vector2.ZERO})



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


## 敲一下某块矿岩：dmg 为镐头每下伤害（1 木 / 2 铜 / 3 铁）
## 返回 {result: "hit"/"break"/"none", ore, pos}
func hit(i: int, dmg: int = 1) -> Dictionary:
	if i < 0 or i >= rocks.size():
		return {"result": "none"}
	var r: Dictionary = rocks[i]
	if bool(r.done):
		return {"result": "none"}
	r.hp = int(r.hp) - maxi(1, dmg)
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


## 宝箱是否在脚边（未开过才算）
func near_chest(p: Vector2) -> bool:
	return has_chest and not chest_open and to_local(p).distance_to(chest_pos) < 62.0


## 打开宝箱：返回 {gold, item, n}，已开过返回空字典
func open_chest() -> Dictionary:
	if not has_chest or chest_open:
		return {}
	chest_open = true
	queue_redraw()
	return {"gold": 260 + depth * 80,
		"item": "gem" if depth >= 6 else "copper",
		"n": 2 if depth >= 6 else 3}


## 玩家前方的怪物下标（没有返回 -1）
func monster_near(p: Vector2, r: float) -> int:
	var lp := to_local(p)
	var best := -1
	var best_d := r
	for i in monsters.size():
		var d: float = lp.distance_to(monsters[i].pos)
		if d < best_d:
			best_d = d
			best = i
	return best


## 镐头敲怪物：两下赶跑，被敲时往反方向退一步
func hit_monster(i: int, dmg: int = 1) -> Dictionary:
	if i < 0 or i >= monsters.size():
		return {}
	var m: Dictionary = monsters[i]
	m.hp = int(m.hp) - maxi(1, dmg)
	var pos: Vector2 = to_global(m.pos)
	if int(m.hp) <= 0:
		monsters.remove_at(i)
		queue_redraw()
		return {"killed": true, "pos": pos}
	var lp := _player_local()
	var away: Vector2 = (m.pos - lp)
	if away.length() < 1.0:
		away = Vector2(1, 0)
	m.pos += away.normalized() * 34.0
	m.cd = 0.6
	queue_redraw()
	return {"killed": false, "pos": pos}


## 玩家在矿洞里的局部坐标（矿洞节点是 main 的子节点，玩家是它的兄弟节点）
func _player_local() -> Vector2:
	var p := get_parent().get_node_or_null("Player") as Node2D
	if p == null:
		return Vector2(INF, INF)
	return to_local(p.position)


## 怪物 AI：玩家靠近就追，够近就撞一下扣生命；平时在洞里慢慢游荡
func _process(delta: float) -> void:
	if monsters.is_empty() and not (has_chest and not chest_open):
		return
	var lp := _player_local()
	var inner := ROOM.grow(-WALL - 18.0)
	for m in monsters:
		m.t = float(m.t) + delta
		var pos: Vector2 = m.pos
		var chase := lp.x < INF / 2.0 and pos.distance_to(lp) < 320.0
		if chase:
			var sp: float = 42.0 if String(m.kind) == "slime" else 76.0
			var dir: Vector2 = (lp - pos)
			if dir.length() > 1.0:
				pos += dir.normalized() * sp * delta
		else:
			pos += Vector2(cos(float(m.t) * 1.3), sin(float(m.t) * 0.9)) * 20.0 * delta
		pos.x = clampf(pos.x, inner.position.x, inner.end.x)
		pos.y = clampf(pos.y, inner.position.y, inner.end.y)
		m.pos = pos
		m.cd = maxf(0.0, float(m.cd) - delta)
		if chase and float(m.cd) <= 0.0 and pos.distance_to(lp) < 30.0:
			m.cd = 1.3
			player_hurt.emit(int(m.atk), to_global(pos))
	queue_redraw()


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
	# 宝箱与怪物
	if has_chest:
		_draw_chest()
	for m in monsters:
		_draw_monster(m)
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


## 宝箱：未开时暖光闪动，开过只剩敞开的空箱
func _draw_chest() -> void:
	var p := chest_pos
	draw_circle(p + Vector2(0, 9), 24.0, Color(0, 0, 0, 0.3))
	if not chest_open:
		var glow := 0.10 + 0.05 * sin(float(Time.get_ticks_msec()) / 240.0)
		draw_circle(p, 34.0, Color(1, 0.85, 0.4, glow))
	draw_rect(Rect2(p + Vector2(-20, -6), Vector2(40, 24)), Color(0.55, 0.36, 0.16))
	draw_rect(Rect2(p + Vector2(-20, -14), Vector2(40, 10)), Color(0.66, 0.45, 0.20))
	draw_rect(Rect2(p + Vector2(-20, -6), Vector2(40, 4)), Color(0.95, 0.76, 0.32))
	draw_rect(Rect2(p + Vector2(-3, -12), Vector2(6, 9)), Color(1.0, 0.87, 0.45))
	if chest_open:
		draw_rect(Rect2(p + Vector2(-20, -22), Vector2(40, 6)), Color(0.48, 0.31, 0.14))
		draw_rect(Rect2(p + Vector2(-14, -2), Vector2(28, 14)), Color(0.28, 0.19, 0.10))


## 怪物：史莱姆是压扁的绿果冻，蝙蝠是拍着翅膀的紫色小团
func _draw_monster(m: Dictionary) -> void:
	var p: Vector2 = m.pos
	var kind := String(m.kind)
	var bob := sin(float(m.t) * (2.4 if kind == "slime" else 6.0))
	draw_circle(p + Vector2(0, 10), 15.0, Color(0, 0, 0, 0.28))
	if kind == "slime":
		var squash := 1.0 + bob * 0.08
		draw_circle(p + Vector2(0, 2), 15.0 * squash, Color(0.36, 0.72, 0.40))
		draw_circle(p + Vector2(-5, -4), 9.0, Color(0.52, 0.84, 0.52))
		draw_circle(p + Vector2(-5, -1), 2.6, Color(0.10, 0.18, 0.12))
		draw_circle(p + Vector2(5, -1), 2.6, Color(0.10, 0.18, 0.12))
	else:
		var flap := 10.0 + absf(bob) * 8.0
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-4, 0), p + Vector2(-4 - flap, -6), p + Vector2(-4, -12)]),
			Color(0.46, 0.34, 0.62))
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(4, 0), p + Vector2(4 + flap, -6), p + Vector2(4, -12)]),
			Color(0.46, 0.34, 0.62))
		draw_circle(p + Vector2(0, -6 + bob * 2.0), 9.0, Color(0.60, 0.44, 0.82))
		draw_circle(p + Vector2(-3, -8), 2.2, Color(1.0, 0.92, 0.55))
		draw_circle(p + Vector2(3, -8), 2.2, Color(1.0, 0.92, 0.55))

