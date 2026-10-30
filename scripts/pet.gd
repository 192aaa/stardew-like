extends Node2D
## 宠物（猫/狗）：默认一路小跑跟随主角，距离过远自动传送，两帧迈步动画
## 建好宠物窝后可以「安放」到窝边待命，不再追着人跑

const TEX_CAT := preload("res://assets/pet_cat.png")
const TEX_DOG := preload("res://assets/pet_dog.png")
const SPEED := 170.0
const TELEPORT_DIST := 420.0

var kind := "cat"
var pet_name := "小猫"
var stop_dist := 48.0
var _player: Node2D
var _sprite: Sprite2D
var _t := 0.0
# 窝：待命位置与状态（at_home = 不追人，只在窝附近溜达）
var home_pos := Vector2.ZERO
var at_home := false
var _wander_target := Vector2.ZERO
var _wander_t := 0.0


func setup(k: String, player: Node2D) -> void:
	kind = k
	pet_name = "小猫" if k == "cat" else "小狗"
	stop_dist = 48.0 if k == "cat" else 66.0
	_player = player
	position = player.position + Vector2(40 if k == "dog" else -40, 24)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX_CAT if k == "cat" else TEX_DOG
	_sprite.hframes = 2
	add_child(_sprite)


## 设置窝的位置与是否待在窝里（窝建好后玩家在窝边按 E 让宠物回家/放出）
func set_home(pos: Vector2, home: bool) -> void:
	home_pos = pos
	at_home = home
	if home:
		_wander_target = pos + Vector2(randf_range(-26, 26), randf_range(6, 22))
		_wander_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		return
	if at_home:
		_process_home(delta)
		_sync_z()
		return
	var d: Vector2 = _player.position - position
	if d.length() > TELEPORT_DIST:
		position = _player.position + Vector2(40 if kind == "dog" else -40, 24)
		_sync_z()
		return
	if d.length() > stop_dist:
		position += d.normalized() * SPEED * delta
		_sprite.flip_h = d.x < 0
		_sprite.frame = int(_t * 7.0) % 2
	else:
		_sprite.frame = 0
	_sync_z()


## 待在窝边：在窝附近小范围溜达，走远了慢慢走回窝
func _process_home(delta: float) -> void:
	_wander_t -= delta
	var d: Vector2 = _wander_target - position
	if d.length() > 6.0:
		position += d.normalized() * SPEED * 0.35 * delta
		_sprite.flip_h = d.x < 0
		_sprite.frame = int(_t * 5.0) % 2
	else:
		_sprite.frame = 0
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.6, 3.6)
		if randf() < 0.55:
			_wander_target = home_pos + Vector2(randf_range(-30, 30), randf_range(4, 24))
	if position.distance_to(home_pos) > 90.0:
		position = home_pos + Vector2(24, 10)


## Y 排序：脚底 y → z_index（宠物比人矮，底部偏移 11）
func _sync_z() -> void:
	z_index = int((position.y + 11.0) / 4.0)
