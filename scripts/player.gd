extends CharacterBody2D
## 玩家角色：WASD / 方向键八方向移动，像素精灵四帧行走动画与朝向翻转

const SPEED := 220.0
const WALK_FRAMES := [0, 1, 0, 2]  # 站 / 迈左腿 / 站 / 迈右腿
const TEX_DUST := preload("res://assets/dust.png")

var facing := Vector2.DOWN

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
var _walk_t := 0.0
var _step_t := 0.0


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
		_step_t += delta
		if _step_t >= 0.26:
			_step_t = 0.0
			_spawn_dust()
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


## 脚步尘土：移动时每隔一小段在脚下冒出一团灰尘并淡出
func _spawn_dust() -> void:
	var d := Sprite2D.new()
	d.texture = TEX_DUST
	d.position = Vector2(randf_range(-4.0, 4.0), 11.0)
	d.modulate = Color(1, 1, 1, 0.62)
	add_child(d)
	var tw := d.create_tween()
	tw.set_parallel(true)
	tw.tween_property(d, "position:y", d.position.y + 5.0, 0.42)
	tw.tween_property(d, "modulate:a", 0.0, 0.42)
	tw.chain().tween_callback(d.queue_free)
