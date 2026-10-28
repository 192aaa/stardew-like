extends Control
## 好友在屏幕外时，于屏幕边缘绘制一个指向好友位置的箭头（联机用）

var main: Node2D
const INSET := 52.0


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null or main._shadow == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var screen: Vector2 = get_viewport().get_canvas_transform() * main._shadow.global_position
	var inner := Rect2(Vector2(INSET, INSET), vs - Vector2(INSET, INSET) * 2.0)
	if inner.has_point(screen):
		return  # 好友已在画面内，不画箭头
	var c := vs * 0.5
	var dir := (screen - c).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	# 沿方向射线与内缩边框求交，得到箭头落点
	var half := vs * 0.5 - Vector2(INSET, INSET)
	var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var pos := c + dir * t
	# 箭头若落在右上角小地图上，则贴着小地图左侧显示，避免被盖住
	if main._minimap != null and main._minimap.visible:
		var mr: Rect2 = main._minimap.get_global_rect()
		if mr.has_point(pos):
			pos = Vector2(mr.position.x - 20.0, clampf(pos.y, mr.position.y + 24.0, mr.end.y - 24.0))
	var perp := Vector2(-dir.y, dir.x)
	var tip := pos + dir * 12.0
	var a := pos - dir * 6.0 + perp * 7.0
	var b := pos - dir * 6.0 - perp * 7.0
	draw_colored_polygon(PackedVector2Array([tip, a, b]), Color(0.35, 0.88, 1.0, 0.92))
	draw_arc(pos, 16.0, 0.0, TAU, 20, Color(0.35, 0.88, 1.0, 0.35), 2.0)
