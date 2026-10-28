extends Node2D
## 天气粒子：跟随相机的斜向雨丝 / 冬季飘雪，程序化绘制（z_index 由 main 设置）

const N := 170
const HALF := Vector2(700, 420)

var mode := "rain"       # "rain" 雨丝 / "snow" 雪花
var _drops: Array = []  # {off: 相对屏幕中心偏移, v: 速度, len: 长度, ph: 飘摆相位}
var _cam: Camera2D
var _t := 0.0


func _ready() -> void:
	_cam = get_viewport().get_camera_2d()
	for i in N:
		_drops.append({
			"off": Vector2(randf_range(-HALF.x, HALF.x), randf_range(-HALF.y, HALF.y)),
			"v": randf_range(400.0, 560.0),
			"len": randf_range(0.7, 1.5),
			"ph": randf_range(0.0, TAU),
		})


func _process(delta: float) -> void:
	if not visible:
		return
	for d in _drops:
		var off: Vector2 = d.off
		if mode == "snow":
			# 雪花：下落慢 + 左右飘摆
			off += Vector2(sin(_t * 1.6 + float(d.ph)) * 24.0, float(d.v) * 0.2) * delta
		else:
			off += Vector2(-60.0, d.v) * delta
		if off.y > HALF.y:
			off.y -= HALF.y * 2.0
			off.x = randf_range(-HALF.x, HALF.x)
		if off.x < -HALF.x - 40.0:
			off.x += HALF.x * 2.0 + 80.0
		d.off = off
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := _cam.get_screen_center_position()
	if mode == "snow":
		for d in _drops:
			var p: Vector2 = c + d.off
			var r := 1.6 + float(d.len) * 1.4
			draw_circle(p, r, Color(0.99, 1.0, 1.0, 0.95))
		return
	for d in _drops:
		var p: Vector2 = c + d.off
		draw_line(p, p + Vector2(-2.0, 10.0) * d.len, Color(0.72, 0.82, 0.95, 0.34), 1.3)
