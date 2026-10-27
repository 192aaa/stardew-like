extends Node2D
## 采集系统：地图随机刷新石头与树枝，用斧镐敲击采集，每天补充刷新

const TEX_ROCK := preload("res://assets/boulder.png")
const TEX_BRANCH := preload("res://assets/branch.png")
const TEX_BUSH_BERRY := preload("res://assets/bush_berry.png")
const TEX_BUSH_PLAIN := preload("res://assets/bush_plain.png")
const FARM := preload("res://scripts/farm.gd")
const DECOR := preload("res://scripts/decor.gd")

const MAX_OBJECTS := 14

## 对象：{kind: "rock"/"branch", pos, hp, spr}
var _objs: Array = []
## 野莓丛：{pos, picked, spr}
var _bushes: Array = []


func _ready() -> void:
	for p in DECOR.BUSH_SPOTS:
		var spr := Sprite2D.new()
		spr.texture = TEX_BUSH_BERRY
		spr.position = p
		add_child(spr)
		_bushes.append({"pos": p, "picked": false, "spr": spr})
	_spawn(4)


## 每天清晨补充刷新；野莓重新结果
func spawn_daily() -> void:
	_spawn(3 + randi() % 3)
	for b in _bushes:
		if b.picked:
			b.picked = false
			b.spr.texture = TEX_BUSH_BERRY


## 附近是否有可摘的野莓丛
func near_bush(p: Vector2) -> bool:
	for b in _bushes:
		if not b.picked and (b.pos as Vector2).distance_to(p) < 48.0:
			return true
	return false


## 摘野莓：返回颗数（0 = 附近没有可摘的）
func pick_berry(p: Vector2) -> int:
	for b in _bushes:
		if not b.picked and (b.pos as Vector2).distance_to(p) < 48.0:
			b.picked = true
			b.spr.texture = TEX_BUSH_PLAIN
			var n := 1 + (1 if randf() < 0.35 else 0)
			Game.add_item("berry", n)
			return n
	return 0


func _spawn(n: int) -> void:
	for i in n:
		if _objs.size() >= MAX_OBJECTS:
			return
		var p := _find_spot()
		if p == Vector2.INF:
			return
		var kind := "rock" if randf() < 0.55 else "branch"
		var spr := Sprite2D.new()
		spr.texture = TEX_ROCK if kind == "rock" else TEX_BRANCH
		spr.position = p
		add_child(spr)
		_objs.append({"kind": kind, "pos": p, "hp": 2, "spr": spr})


func _find_spot() -> Vector2:
	for attempt in 24:
		var p := Vector2(randf_range(-1700.0, 1700.0), randf_range(-1120.0, 1120.0))
		if _free(p):
			return p
	return Vector2.INF


func _free(p: Vector2) -> bool:
	for z in FARM.ZONES:
		if z.grow(12).has_point(p):
			return false
	if DECOR.POND_RECT.grow(34).has_point(p) or DECOR.HOUSE_RECT.grow(30).has_point(p):
		return false
	if DECOR.STALL_RECT.grow(30).has_point(p) or p.distance_to(DECOR.DOOR_POS) < 90.0:
		return false
	if p.distance_to(DECOR.SHOP_POS) < 90.0 or p.distance_to(DECOR.LAMP_POS) < 46.0:
		return false
	if p.distance_to(DECOR.WELL_POS) < 80.0 or p.distance_to(DECOR.MAILBOX_POS) < 46.0:
		return false
	if p.distance_to(DECOR.LOG_POS) < 44.0 or p.distance_to(DECOR.STUMP_POS) < 44.0:
		return false
	if DECOR.GARDEN_RECT.grow(28).has_point(p):
		return false
	for b in DECOR.BUSH_SPOTS:
		if p.distance_to(b) < 64.0:
			return false
	for t in DECOR.TREES:
		if p.distance_to(t) < 72.0:
			return false
	for o in _objs:
		if (o.pos as Vector2).distance_to(p) < 64.0:
			return false
	return true


## 斧镐可命中范围内是否有对象
func near(p: Vector2) -> bool:
	for o in _objs:
		if (o.pos as Vector2).distance_to(p) < 42.0:
			return true
	return false


## 敲击最近的对象：返回 {result: "none"/"hit"/"break", kind: String}
func hit_at(p: Vector2) -> Dictionary:
	var best = null
	var best_d := 42.0
	for o in _objs:
		var d: float = (o.pos as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best = o
	if best == null:
		return {"result": "none", "kind": ""}
	best.hp -= 1
	if best.hp > 0:
		var tw := create_tween()
		tw.tween_property(best.spr, "position", best.pos + Vector2(3, 0), 0.05)
		tw.tween_property(best.spr, "position", best.pos, 0.05)
		return {"result": "hit", "kind": best.kind}
	var kind: String = best.kind
	best.spr.queue_free()
	_objs.erase(best)
	return {"result": "break", "kind": kind}
