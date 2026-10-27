extends Node2D
## 矿洞采矿：东侧矿洞区每天刷新矿岩（铜/铁/宝石），用斧镐敲击产出矿石

const DECOR := preload("res://scripts/decor.gd")

const TEX_ORES := {
	"copper": preload("res://assets/ore_copper.png"),
	"iron": preload("res://assets/ore_iron.png"),
	"gem": preload("res://assets/ore_gem.png"),
}
const ORE_HP := {"copper": 2, "iron": 3, "gem": 3}
const MAX_ORES := 9

## 矿岩节点：{kind, pos, hp, spr}
var _ores: Array = []


func _ready() -> void:
	_spawn(6)


## 每天清晨补充刷新
func spawn_daily() -> void:
	_spawn(4 + randi() % 3)


## 斧镐可命中范围内是否有矿岩
func near(p: Vector2) -> bool:
	for o in _ores:
		if (o.pos as Vector2).distance_to(p) < 42.0:
			return true
	return false


## 敲击最近的矿岩：返回 {result: "none"/"hit"/"break", kind: String}
func hit_at(p: Vector2) -> Dictionary:
	var best = null
	var best_d := 42.0
	for o in _ores:
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
	_ores.erase(best)
	return {"result": "break", "kind": kind}


func _spawn(n: int) -> void:
	for i in n:
		if _ores.size() >= MAX_ORES:
			return
		var p := _find_spot()
		if p == Vector2.INF:
			return
		var r := randf()
		var kind := "copper" if r < 0.6 else ("iron" if r < 0.9 else "gem")
		var spr := Sprite2D.new()
		spr.texture = TEX_ORES[kind]
		spr.position = p
		add_child(spr)
		_ores.append({"kind": kind, "pos": p, "hp": ORE_HP[kind], "spr": spr})


func _find_spot() -> Vector2:
	var z: Rect2 = DECOR.MINE_ZONE
	for attempt in 30:
		var p := Vector2(
			randf_range(z.position.x + 22.0, z.end.x - 22.0),
			randf_range(z.position.y + 22.0, z.end.y - 22.0))
		if _free(p):
			return p
	return Vector2.INF


func _free(p: Vector2) -> bool:
	if p.distance_to(DECOR.MINE_POS) < 70.0:
		return false
	for o in _ores:
		if (o.pos as Vector2).distance_to(p) < 58.0:
			return false
	for t in DECOR.TREES:
		if p.distance_to(t) < 62.0:
			return false
	return true
