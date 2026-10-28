extends Control
## 目标指引箭头：当前目标在屏幕外时，于屏幕边缘画一个指向它的箭头
## 目标由 main.goal_target() 决定（成熟作物 / 订单板 / 引导农田 / 商店）

var main: Node2D
const INSET := 52.0


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null:
		return
	var target = main.goal_target()
	if target == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var screen: Vector2 = get_viewport().get_canvas_transform() * (target as Vector2)
	var inner := Rect2(Vector2(INSET, INSET), vs - Vector2(INSET, INSET) * 2.0)
	if inner.has_point(screen):
		return  # 目标已在画面内，不画箭头
	var c := vs * 0.5
	var dir := (screen - c).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var half := vs * 0.5 - Vector2(INSET, INSET)
	var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var pos := c + dir * t
	# 避开右上角小地图
	if main._minimap != null and main._minimap.visible:
		var mr: Rect2 = main._minimap.get_global_rect()
		if mr.has_point(pos):
			pos = Vector2(mr.position.x - 20.0, clampf(pos.y, mr.position.y + 24.0, mr.end.y - 24.0))
	var perp := Vector2(-dir.y, dir.x)
	var tip := pos + dir * 13.0
	var a := pos - dir * 7.0 + perp * 8.0
	var b := pos - dir * 7.0 - perp * 8.0
	draw_colored_polygon(PackedVector2Array([tip, a, b]), Color(1.0, 0.87, 0.35, 0.92))
	draw_arc(pos, 17.0, 0.0, TAU, 20, Color(1.0, 0.87, 0.35, 0.32), 2.0)
