extends Node2D
## 无限地图：核心农场（decor.WORLD）之外按 512px 区块（chunk）确定性生成地形与树林
## 玩家走动时加载前方区块、卸载远处区块；区块内容由「世界种子 + 区块坐标」推导，无需存档
## 核心农场地标（房屋/商店/农田/矿洞/河流等）全部保留，区块只在核心区外落脚，重叠部分让位

const TEX_GRASS := preload("res://assets/grass.png")
const TEX_GRASS_SNOW := preload("res://assets/grass_snow.png")
const TEX_TREE := preload("res://assets/tree.png")
const TEX_PINE := preload("res://assets/tree2.png")
const TEX_BIRCH := preload("res://assets/tree3.png")
const TEX_MAPLE := preload("res://assets/tree4.png")
const TEX_SHADOW := preload("res://assets/shadow.png")
const TEX_TUFT := preload("res://assets/tuft.png")
const TEX_STONE := preload("res://assets/stone.png")
const TEX_FLOWERS := preload("res://assets/flowers.png")
const TEX_GRASS_PATCH := preload("res://assets/grass_patch.png")
const TEX_LEAF_LITTER := preload("res://assets/leaf_litter.png")

const CHUNK := 512
const LOAD_R := 2      # 加载半径：视野约 1.2 块，向前多留一屏做缓冲，走起来看不到“无地”
const UNLOAD_R := 3    # 卸载半径：比加载多一圈做迟滞，来回跨块不会反复重建
## 核心农场范围（与 decor.WORLD 一致）
const CORE := Rect2(-2600, -1400, 5200, 2800)
const SEED := 20261029
const EDGE := 44.0     # 树/装饰离区块边缘的最小距离，避免跨块重复与贴边残缺
const Z_GROUND := -2900  # 与 decor 地面层同层：区块地面只画在地面层，树用绝对 z

## 单块视觉：地面/投影/草丛/石子/野花/地皮贴花在 _draw 里画；树是独立 Sprite，走绝对 z 和玩家一起排序
class ChunkView extends Node2D:
	var size_px := 512.0
	var ground_tex: Texture2D
	var ground_tint := Color(1, 1, 1)
	var deco_tint := Color(1, 1, 1)
	var assets := {}
	var skip_rect := Rect2()      # 本地坐标里要让位给核心农场的部分（核心地面由 main.tscn 绘制）
	var trees: Array = []         # [[Vector2 本地坐标, int 变体], ...]
	var tree_sprites: Array = []
	var patches: Array = []       # [[Vector2, bool 是否落叶], ...]
	var tufts: Array = []
	var stones: Array = []
	var flowers: Array = []       # [[Vector2, int 花色帧], ...]

	func _draw() -> void:
		_draw_ground()
		# 树影留在地面层，树冠本体是 Sprite（见 add_tree_sprite）
		for t in trees:
			draw_texture_rect(assets["shadow"],
					Rect2((t[0] as Vector2).x - 28.0, (t[0] as Vector2).y + 15.0, 56.0, 22.0), false, deco_tint)
		for p in patches:
			var tex: Texture2D = assets["litter"] if bool(p[1]) else assets["patch"]
			draw_texture_rect(tex, Rect2((p[0] as Vector2).x - 16.0, (p[0] as Vector2).y - 16.0, 32.0, 32.0), false, deco_tint)
		for p in tufts:
			draw_texture_rect(assets["tuft"], Rect2(p.x - 8.0, p.y - 8.0, 16.0, 16.0), false, deco_tint)
		for p in stones:
			draw_texture_rect(assets["stone"], Rect2(p.x - 8.0, p.y - 5.0, 16.0, 10.0), false, deco_tint)
		for f in flowers:
			var fp: Vector2 = f[0]
			draw_texture_rect_region(assets["flowers"],
					Rect2(fp.x - 8.0, fp.y - 8.0, 16.0, 16.0),
					Rect2(int(f[1]) * 16.0, 0.0, 16.0, 16.0), deco_tint)

	## 树木换成绝对 z 的 Sprite：玩家走到树冠后面会被挡住（Y 排序）
	func add_tree_sprite(local: Vector2, variant: int) -> void:
		var s := Sprite2D.new()
		var key: String = ["tree", "pine", "birch", "maple"][variant]
		s.texture = assets[key]
		s.position = local + Vector2(0.0, -14.0)
		s.z_as_relative = false
		s.z_index = int((position.y + local.y + 34.0) / 4.0)
		s.modulate = deco_tint
		add_child(s)
		tree_sprites.append(s)

	func apply_tint() -> void:
		for s in tree_sprites:
			(s as Sprite2D).modulate = deco_tint
		queue_redraw()

	## 地面：核心农场压住的区域不画（避免与 main.tscn 的 Ground 纹理相位错开出现接缝）
	func _draw_ground() -> void:
		var full := Rect2(Vector2.ZERO, Vector2(size_px, size_px))
		if skip_rect.size == Vector2.ZERO or not skip_rect.intersects(full):
			draw_texture_rect(ground_tex, full, true, ground_tint)
			return
		var inter := skip_rect.intersection(full)
		if inter.position.y > 0.0:
			draw_texture_rect(ground_tex, Rect2(0.0, 0.0, size_px, inter.position.y), true, ground_tint)
		if inter.end.y < size_px:
			draw_texture_rect(ground_tex,
					Rect2(0.0, inter.end.y, size_px, size_px - inter.end.y), true, ground_tint)
		if inter.position.x > 0.0:
			draw_texture_rect(ground_tex,
					Rect2(0.0, inter.position.y, inter.position.x, inter.size.y), true, ground_tint)
		if inter.end.x < size_px:
			draw_texture_rect(ground_tex,
					Rect2(inter.end.x, inter.position.y, size_px - inter.end.x, inter.size.y), true, ground_tint)


var _chunks := {}              # Vector2i -> ChunkView
var _center := Vector2i(2147483647, 0)
var _noise := FastNoiseLite.new()
var _ground_tex: Texture2D = TEX_GRASS
var _ground_tint := Color(1, 1, 1)
var _deco_tint := Color(1, 1, 1)
var _assets := {
	"tree": TEX_TREE, "pine": TEX_PINE, "birch": TEX_BIRCH, "maple": TEX_MAPLE,
	"shadow": TEX_SHADOW, "tuft": TEX_TUFT, "stone": TEX_STONE, "flowers": TEX_FLOWERS,
	"patch": TEX_GRASS_PATCH, "litter": TEX_LEAF_LITTER,
}


func _ready() -> void:
	z_index = Z_GROUND  # 只画地面；树用绝对 z，和玩家一起做 Y 排序
	_noise.seed = SEED
	_noise.frequency = 0.0022  # 约 450px 尺度的疏密变化：成片林地与小片空地
	update_around(player_pos(), true)


func _process(_delta: float) -> void:
	update_around(player_pos())


func player_pos() -> Vector2:
	var p := get_parent().get_node_or_null("Player") as Node2D
	return p.position if p else Vector2.ZERO


## 玩家跨入新区块时补载周围一圈；走远超过 UNLOAD_R 的区块释放
func update_around(p: Vector2, force := false) -> void:
	var c := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
	if not force and c == _center:
		return
	_center = c
	for dy in range(-LOAD_R, LOAD_R + 1):
		for dx in range(-LOAD_R, LOAD_R + 1):
			var key := Vector2i(c.x + dx, c.y + dy)
			if _chunks.has(key):
				continue
			var node := _build_chunk(key)
			_chunks[key] = node
			add_child(node)
	for key in _chunks.keys():
		var d := maxi(absi((key as Vector2i).x - c.x), absi((key as Vector2i).y - c.y))
		if d > UNLOAD_R:
			(_chunks[key] as Node).queue_free()
			_chunks.erase(key)


## 季节切换：地面贴图/染色与树木染色跟随核心区（冬天地面换雪图，树泛冷白）
func set_season(winter: bool, tint: Color, deco_tint: Color) -> void:
	_ground_tex = TEX_GRASS_SNOW if winter else TEX_GRASS
	_ground_tint = tint
	_deco_tint = deco_tint
	for c in _chunks.values():
		(c as ChunkView).ground_tex = _ground_tex
		(c as ChunkView).ground_tint = _ground_tint
		(c as ChunkView).deco_tint = _deco_tint
		(c as ChunkView).apply_tint()


## 已加载区块坐标（小地图画外围林地用）
func active_cells() -> Array:
	return _chunks.keys()


func _build_chunk(cell: Vector2i) -> ChunkView:
	var root := ChunkView.new()
	root.size_px = float(CHUNK)
	root.assets = _assets
	root.ground_tex = _ground_tex
	root.ground_tint = _ground_tint
	root.deco_tint = _deco_tint
	root.position = Vector2(cell.x * CHUNK, cell.y * CHUNK)
	var full := Rect2(Vector2.ZERO, Vector2(CHUNK, CHUNK))
	var core_local := Rect2(CORE.position - root.position, CORE.size)
	if core_local.intersects(full):
		root.skip_rect = core_local

	var rng := RandomNumberGenerator.new()
	rng.seed = absi(int(SEED * 73856093) ^ int(cell.x * 19349663) ^ int(cell.y * 83492791))
	# 树：128px 网格加抖动，按噪声决定疏密（噪声正值为林地，负值为林间空地）
	for gy in 4:
		for gx in 4:
			var lp := Vector2(
				(gx + 0.5) * 128.0 + rng.randf_range(-46.0, 46.0),
				(gy + 0.5) * 128.0 + rng.randf_range(-46.0, 46.0))
			if lp.x < EDGE or lp.x > CHUNK - EDGE or lp.y < EDGE or lp.y > CHUNK - EDGE:
				continue
			var gp: Vector2 = root.position + lp
			if CORE.grow(46.0).has_point(gp):
				continue  # 核心农场内不放树（那里由 decor 负责）
			var n := _noise.get_noise_2d(gp.x, gp.y)
			if rng.randf() > 0.10 + maxf(n, 0.0) * 0.62:
				continue
			root.trees.append([lp, _tree_variant(rng)])
		if root.trees.size() > 0:
			var body := StaticBody2D.new()
			for t in root.trees:
				var cs := CollisionShape2D.new()
				var shape := CircleShape2D.new()
				shape.radius = 12.0
				cs.shape = shape
				cs.position = (t[0] as Vector2) + Vector2(0.0, 16.0)
				body.add_child(cs)
			root.add_child(body)
			for t in root.trees:
				root.add_tree_sprite(t[0] as Vector2, int(t[1]))

	# 地皮贴花：草簇打散草地平铺的重复感（落叶贴花给林地点缀秋色）
	# 注意：整块都在核心农场里的区块会全部被拒，用尝试次数兜底，避免死循环
	var patched := 0
	var patch_tries := 0
	while patched < 18 and patch_tries < 160:
		patch_tries += 1
		var lp := Vector2(rng.randf_range(EDGE, CHUNK - EDGE), rng.randf_range(EDGE, CHUNK - EDGE))
		if CORE.grow(20.0).has_point(root.position + lp):
			continue
		root.patches.append([lp, rng.randf() < 0.22])
		patched += 1

	# 草丛 / 石子 / 野花：纯装饰，避开树与核心区
	var tries := 0
	while tries < 40 and (root.tufts.size() + root.stones.size()) < 14:
		tries += 1
		var lp := Vector2(rng.randf_range(EDGE, CHUNK - EDGE), rng.randf_range(EDGE, CHUNK - EDGE))
		if CORE.grow(30.0).has_point(root.position + lp) or _near_tree(root.trees, lp, 54.0):
			continue
		if rng.randf() < 0.72:
			root.tufts.append(lp)
		else:
			root.stones.append(lp)
	for i in 5:
		var lp := Vector2(rng.randf_range(EDGE, CHUNK - EDGE), rng.randf_range(EDGE, CHUNK - EDGE))
		if CORE.grow(30.0).has_point(root.position + lp) or _near_tree(root.trees, lp, 46.0):
			continue
		root.flowers.append([lp, rng.randi_range(0, 3)])
	return root


## 树的外观权重：橡树最多，松树次之，少量白桦与红枫点缀
func _tree_variant(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if r < 0.46:
		return 0
	if r < 0.74:
		return 1
	if r < 0.92:
		return 2
	return 3


func _near_tree(trees: Array, p: Vector2, dist: float) -> bool:
	for t in trees:
		if (t[0] as Vector2).distance_to(p) < dist:
			return true
	return false
