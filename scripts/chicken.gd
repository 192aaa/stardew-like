extends Node2D
## 鸡：在鸡舍附近小范围散步（等待/踱步交替），两帧迈步动画，flip_h 转向

const SPEED := 22.0
const TEX := preload("res://assets/chicken.png")

var _sprite: Sprite2D
var _roam := Rect2()
var _state := "wait"
var _wait := 1.0
var _target := Vector2.ZERO
var _t := 0.0


func setup(r: Rect2, pos: Vector2) -> void:
	_roam = r
	position = pos
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.hframes = 2
	add_child(_sprite)


func _process(delta: float) -> void:
	_t += delta
	z_index = int((position.y + 13.0) / 4.0)  # Y 排序（鸡很矮，底部偏移 13）
	if _state == "wait":
		_sprite.frame = 0
		_wait -= delta
		if _wait <= 0.0:
			_target = Vector2(
				randf_range(_roam.position.x, _roam.end.x),
				randf_range(_roam.position.y, _roam.end.y))
			_state = "walk"
	else:
		var d := _target - position
		if d.length() < 4.0:
			_state = "wait"
			_wait = randf_range(1.5, 4.5)
			return
		position += d.normalized() * SPEED * delta
		_sprite.flip_h = d.x < 0
		_sprite.frame = int(_t * 6.0) % 2
