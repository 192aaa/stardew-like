extends CharacterBody2D
## 玩家角色：WASD / 方向键八方向移动，像素精灵四帧行走动画与朝向翻转

const SPEED := 220.0
const WALK_FRAMES := [0, 1, 0, 2]  # 站 / 迈左腿 / 站 / 迈右腿

var facing := Vector2.DOWN

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
var _walk_t := 0.0


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	move_and_slide()
	if direction.length() > 0.1:
		if absf(direction.x) > absf(direction.y):
			facing = Vector2(signf(direction.x), 0)
		else:
			facing = Vector2(0, signf(direction.y))
		_walk_t += delta * 8.0
		var f: int = WALK_FRAMES[int(_walk_t) % 4]
		sprite.frame_coords = Vector2i(f, _row())
	else:
		_walk_t = 0.0
		sprite.frame_coords = Vector2i(0, _row())


## 精灵表行：0 朝下 / 1 朝上 / 2 侧面
func _row() -> int:
	if absf(facing.x) > 0.5:
		sprite.flip_h = facing.x < 0
		return 2
	sprite.flip_h = false
	return 0 if facing.y > 0 else 1


## 使用工具时的弹跳反馈
func pop() -> void:
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector2(1.1, 0.9), 0.06)
	tw.tween_property(visual, "scale", Vector2.ONE, 0.1)
