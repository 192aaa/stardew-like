extends Node2D
## 采集系统：地图随机刷新石头与树枝，用斧镐敲击采集，每天补充刷新

const TEX_ROCK := preload("res://assets/boulder.png")
const TEX_BRANCH := preload("res://assets/branch.png")
const FARM := preload("res://scripts/farm.gd")
const DECOR := preload("res://scripts/decor.gd")

const MAX_OBJECTS := 14

## 对象：{kind: "rock"/"branch", pos, hp, spr}
var _objs: Array = []


func _ready() -> void:
	_spawn(4)


## 每天清晨补充刷新
func spawn_daily() -> void:
	_spawn(3 + randi() % 3)


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
		var p := Vector2(randf_range(-1400.0, 1400.0), randf_range(-880.0, 880.0))
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
