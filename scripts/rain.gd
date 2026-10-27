extends Node2D
## 雨天效果：跟随相机的斜向雨丝，程序化绘制（z_index 由 main 设置）

const N := 130
const HALF := Vector2(700, 420)

var _drops: Array = []  # {off: 相对屏幕中心偏移, v: 速度, len: 长度}
var _cam: Camera2D


func _ready() -> void:
	_cam = get_viewport().get_camera_2d()
	for i in N:
		_drops.append({
			"off": Vector2(randf_range(-HALF.x, HALF.x), randf_range(-HALF.y, HALF.y)),
			"v": randf_range(400.0, 560.0),
			"len": randf_range(0.7, 1.5),
		})


func _process(delta: float) -> void:
	if not visible:
		return
	for d in _drops:
		var off: Vector2 = d.off
		off += Vector2(-60.0, d.v) * delta
		if off.y > HALF.y:
			off.y -= HALF.y * 2.0
			off.x = randf_range(-HALF.x, HALF.x)
		if off.x < -HALF.x - 40.0:
			off.x += HALF.x * 2.0 + 80.0
		d.off = off
	queue_redraw()


func _draw() -> void:
	var c := _cam.get_screen_center_position()
	for d in _drops:
		var p: Vector2 = c + d.off
		draw_line(p, p + Vector2(-2.0, 10.0) * d.len, Color(0.72, 0.82, 0.95, 0.34), 1.3)
