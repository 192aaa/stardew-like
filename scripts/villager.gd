extends Node2D
## 村民 NPC：活动区域内随机散步（等待→走向随机点），精灵表与玩家同规格（4x3）
## 对话逻辑在 main.gd，好感度存 Game.friends

const SPEED := 46.0
const WALK_FRAMES := [0, 1, 0, 3]

var display_name := ""
var roam := Rect2()

var _sprite: Sprite2D
var _state := "wait"
var _wait := 1.0
var _target := Vector2.ZERO
var _walk_t := 0.0


func setup(tex: Texture2D, r: Rect2, nm: String, pos: Vector2) -> void:
	display_name = nm
	roam = r
	position = pos
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.hframes = 4
	_sprite.vframes = 3
	_sprite.position = Vector2(0, -10)  # 16x32 单元：把精灵上移，脚底保持在原点 +22
	add_child(_sprite)


func _process(delta: float) -> void:
	if not _sprite:
		return
	z_index = int((position.y + 22.0) / 4.0)  # Y 排序，和玩家/树木一致
	if _state == "wait":
		_wait -= delta
		_sprite.frame_coords = Vector2i(0, 0)
		if _wait <= 0.0:
			_target = Vector2(
				randf_range(roam.position.x, roam.end.x),
				randf_range(roam.position.y, roam.end.y))
			_state = "walk"
	else:
		var d := _target - position
		if d.length() < 6.0:
			_state = "wait"
			_wait = randf_range(2.0, 5.5)
			_sprite.frame_coords = Vector2i(0, 0)
			return
		var dir := d.normalized()
		position += dir * SPEED * delta
		_walk_t += delta * 7.0
		_sprite.frame_coords = Vector2i(WALK_FRAMES[int(_walk_t) % 4], _row(dir))


## 精灵表行：0 朝下 / 1 朝上 / 2 侧面
func _row(dir: Vector2) -> int:
	if absf(dir.x) > absf(dir.y):
		_sprite.flip_h = dir.x < 0
		return 2
	_sprite.flip_h = false
	return 0 if dir.y > 0 else 1
