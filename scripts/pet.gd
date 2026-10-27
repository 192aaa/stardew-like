extends Node2D
## 宠物（猫/狗）：一路小跑跟随主角，距离过远自动传送，两帧迈步动画

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


func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		return
	var d: Vector2 = _player.position - position
	if d.length() > TELEPORT_DIST:
		position = _player.position + Vector2(40 if kind == "dog" else -40, 24)
		return
	if d.length() > stop_dist:
		position += d.normalized() * SPEED * delta
		_sprite.flip_h = d.x < 0
		_sprite.frame = int(_t * 7.0) % 2
	else:
		_sprite.frame = 0
