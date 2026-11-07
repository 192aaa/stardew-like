extends Node
## UI 面板控制器（C5-① / T2.1 第一阶段，低耦合先行）
##
## 职责：集中纯 UI 构造（Label / Button / 全屏模态遮罩 / 各类 StyleBox）、
## 从 InputMap 取键帽、存档日期文案，以及「世界存档选择页」的开关、卡片构造与刷新。
## 本模块不持有面板状态：*_open / _save_* / _boot_* 等状态仍由 main.gd 持有并读写，
## 因为 touch_controls.gd 会直接访问 main 的这些变量，组合链不能断。
##
## 对外接口（main.gd 在 main.panels 持有本类实例，并保留同名薄转发壳）：
##   mk_label(txt, size) / mk_btn(txt)
##   modal_style() / hero_btn_style(c, hot) / hero_card_style(c, hot)
##   bag_side_style() / bag_cell_style(c, sel, hot) / bag_tab_style(active) / bag_cat_color(cat)
##   key_cap(action) / slot_date_text(d) / fmt_time(unix) / boot_info_text()
##   make_modal(w, h) -> [dim, panel] / modal_freeze(on)
##   open_save_select() / close_save_select(restore_boot) / refresh_save_list()
##   save_slot_card(i) / enter_slot(i) / new_slot(i) / delete_slot(i)
##
## 组合而非继承：需要主场景能力时一律显式 main.<member>，不复制玩法逻辑与数值。
## T2.1b 迁入的面板构造（对外接口，main 保留同名薄转发壳）：
##   build_shop() / add_crop_row(vb,id) / add_item_row(vb,cat,id)
##   build_craft() / build_structures_ui() / build_pet_house()
##   build_dex() / build_help() / build_settings() / build_bag()
##   build_boot() / open_hero_select(origin) / hero_card(i)
##   free_hero_select() / close_hero_select()
## 以上接口与通用控件、存档选择页共用 main.<member> 组合链；状态变量仍留在 main.gd。

var main
const TouchScript := preload("res://scripts/touch_controls.gd")


func ui_root() -> Node:
	return main.get_node("UI")


# ---------- 通用控件与样式 ----------

func mk_label(txt: String, size: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", main._ui_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	l.add_theme_constant_override("outline_size", 5)
	return l


func mk_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_override("font", main._ui_font)
	b.add_theme_font_size_override("font_size", 14)
	return b


func modal_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.97)
	sb.border_color = Color(0.38, 0.5, 0.68, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	return sb


## 选择按钮：用角色主色铺底，悬停略亮
func hero_btn_style(c: Color, hot: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c.r, c.g, c.b, 0.92 if hot else 0.78)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## 角色卡片底框：角色主色的细边框，鼠标悬停时加亮
func hero_card_style(c: Color, hot: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.17, 0.22, 0.96) if not hot else Color(0.19, 0.23, 0.3, 0.98)
	sb.border_color = Color(c.r, c.g, c.b, 1.0 if hot else 0.55)
	sb.set_border_width_all(2 if hot else 1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	return sb


func bag_side_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.2, 0.95)
	sb.border_color = Color(0.3, 0.4, 0.55, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	return sb


## 背包格子底框：分类色细边框，选中/悬停时边框更亮
func bag_cell_style(c: Color, sel: bool, hot: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.3, 0.4, 0.98) if sel else Color(0.15, 0.18, 0.23, 0.96)
	sb.border_color = Color(c.r, c.g, c.b, 1.0 if sel else (0.85 if hot else 0.5))
	sb.set_border_width_all(2 if sel else 1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	return sb


func bag_tab_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.48, 0.68, 0.95) if active else Color(0.14, 0.17, 0.22, 0.9)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func bag_cat_color(cat: String) -> Color:
	match cat:
		"crop": return Color(0.55, 0.82, 0.52)
		"seed": return Color(0.86, 0.8, 0.45)
		"fish": return Color(0.5, 0.72, 0.95)
		"ore": return Color(0.95, 0.7, 0.45)
		"mat": return Color(0.82, 0.74, 0.62)
		"food": return Color(0.95, 0.62, 0.67)
	return Color(0.75, 0.8, 0.88)


## 从 InputMap 读取动作的首个键盘键帽文字：键位唯一真源是 project.godot
func key_cap(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var kc: int = e.physical_keycode
			if kc == 0:
				kc = e.keycode
			return OS.get_keycode_string(kc).trim_prefix("Key")
	return "?"


## 全屏界面打开时停住主角移动（界面不暂停世界，天色照常走）
func modal_freeze(on: bool) -> void:
	if main.player != null:
		main.player.set_physics_process(not on)


## 全屏遮罩 + 居中面板（建造 / 仓库 / 矿洞 / 存档页共用同一套样式）
func make_modal(w: float, h: float) -> Array:
	var root := ui_root()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.visible = false
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -w * 0.5
	panel.offset_top = -h * 0.5
	panel.offset_right = w * 0.5
	panel.offset_bottom = h * 0.5
	panel.add_theme_stylebox_override("panel", modal_style())
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	root.add_child(panel)
	# 遮罩与面板压到 UI 最上层：盖住小地图 / 目标条 / 物品栏
	dim.z_index = 900
	panel.z_index = 901
	root.move_child(dim, -1)
	root.move_child(panel, -1)
	return [dim, panel]


# ---------- 世界存档选择页 ----------

## 标题页信息行文案
func boot_info_text() -> String:
	var used := Save.used_slots()
	if used == 0:
		return "还没有世界存档，新建一个世界开始吧"
	return "已有 %d 个世界存档（共 %d 个存档位）" % [used, Save.SLOT_COUNT]


## 存档日期 → 「第 12 天 · 春季第 12 天」
func slot_date_text(d: Dictionary) -> String:
	var day := int(d.get("day", 1))
	var idx := int(floor((day - 1) / float(Game.SEASON_DAYS))) % Game.SEASONS.size()
	var sd := (day - 1) % Game.SEASON_DAYS + 1
	return "第 %d 天 · %s季第 %d 天" % [day, String(Game.SEASONS[idx].name), sd]


## 时间戳 → 「10-30 21:05」
func fmt_time(unix: int) -> String:
	if unix <= 0:
		return "—"
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d-%02d %02d:%02d" % [int(dt.month), int(dt.day), int(dt.hour), int(dt.minute)]


## 存档选择面板：6 个世界存档位，可进入 / 删除 / 在空位新建
func open_save_select() -> void:
	if main._save_panel != null:
		return
	get_tree().paused = true
	if main._boot_panel != null:
		main._boot_panel.visible = false
	var root := ui_root()
	main._save_dim = ColorRect.new()
	main._save_dim.color = Color(0.02, 0.03, 0.05, 0.62)
	main._save_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	main._save_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(main._save_dim)
	main._save_panel = PanelContainer.new()
	main._save_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	main._save_panel.anchor_left = 0.5
	main._save_panel.anchor_top = 0.5
	main._save_panel.anchor_right = 0.5
	main._save_panel.anchor_bottom = 0.5
	main._save_panel.offset_left = -430.0
	main._save_panel.offset_top = -272.0
	main._save_panel.offset_right = 430.0
	main._save_panel.offset_bottom = 272.0
	main._save_panel.add_theme_stylebox_override("panel", modal_style())
	root.add_child(main._save_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	main._save_panel.add_child(vb)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(800, 0)
	vb.add_child(pad)
	var title := mk_label("世 界 存 档", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := mk_label("共 %d 个存档位 · 进入一个世界继续，或在空位新建" % Save.SLOT_COUNT, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.72)
	vb.add_child(sub)
	var hr := HSeparator.new()
	hr.modulate = Color(1, 1, 1, 0.22)
	vb.add_child(hr)
	main._save_list = VBoxContainer.new()
	main._save_list.add_theme_constant_override("separation", 8)
	vb.add_child(main._save_list)
	refresh_save_list()
	var back := mk_btn("← 返回标题页")
	back.custom_minimum_size = Vector2(220, 32)
	back.add_theme_font_size_override("font_size", 13)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: self.close_save_select())
	vb.add_child(back)


## 重绘 6 个存档位卡片
func refresh_save_list() -> void:
	if main._save_list == null:
		return
	for c in main._save_list.get_children():
		c.queue_free()
	for i in Save.SLOT_COUNT:
		main._save_list.add_child(save_slot_card(i))


## 单个存档位：左侧世界信息，右侧进入 / 删除（空位为新建）
func save_slot_card(i: int) -> Control:
	var d := Save.slot_summary(i)
	var empty := d.is_empty()
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.16, 0.21, 0.95)
	sb.border_color = Color(0.42, 0.48, 0.58, 0.5 if empty else 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(0, 62)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	if empty:
		var t0 := mk_label("%d 号世界 · 空白" % (i + 1), 17)
		t0.modulate = Color(1, 1, 1, 0.55)
		info.add_child(t0)
		var t1 := mk_label("还没有世界，点右侧「新建世界」开始", 12)
		t1.modulate = Color(1, 1, 1, 0.45)
		info.add_child(t1)
		var b_new := mk_btn("新建世界")
		b_new.custom_minimum_size = Vector2(120, 34)
		b_new.add_theme_font_size_override("font_size", 14)
		b_new.pressed.connect(func() -> void: self.new_slot(i))
		hb.add_child(b_new)
		return card
	var hid := clampi(int(d.get("hero_id", 0)), 0, Game.HEROES.size() - 1)
	var hero: Dictionary = Game.HEROES[hid]
	var c: Color = hero.color
	var t := mk_label("%d 号世界 · %s" % [i + 1, hero.name], 17)
	t.add_theme_color_override("font_color", c)
	info.add_child(t)
	var line := mk_label("%s · %d 金币" % [slot_date_text(d), int(d.get("gold", 0))], 12)
	line.modulate = Color(1, 1, 1, 0.8)
	info.add_child(line)
	var saved := int(d.get("saved_at", 0))
	var tl := "上次保存：%s" % fmt_time(saved) if saved > 0 else "尚未保存"
	var t2 := mk_label(tl, 11)
	t2.modulate = Color(1, 1, 1, 0.5)
	info.add_child(t2)
	var b_in := mk_btn("进入")
	b_in.custom_minimum_size = Vector2(84, 34)
	b_in.add_theme_font_size_override("font_size", 14)
	b_in.add_theme_stylebox_override("normal", hero_btn_style(c, false))
	b_in.add_theme_stylebox_override("hover", hero_btn_style(c, true))
	b_in.add_theme_stylebox_override("pressed", hero_btn_style(c, true))
	b_in.pressed.connect(func() -> void: self.enter_slot(i))
	hb.add_child(b_in)
	var b_del := mk_btn("确认删除？" if main._save_confirm == i else "删除")
	b_del.custom_minimum_size = Vector2(100, 34)
	b_del.add_theme_font_size_override("font_size", 13)
	b_del.pressed.connect(func() -> void: self.delete_slot(i))
	hb.add_child(b_del)
	return card


## 进入指定世界：切槽、读档、收掉面板开局
func enter_slot(i: int) -> void:
	Save.current = i
	Save.set_setting("last_slot", i)
	main._save_confirm = -1
	close_save_select(false)
	if not main._do_load(false):
		main._toast("这个存档读取失败了……")
		get_tree().paused = false
		return
	main._last_season = Game.season_index()
	main._apply_season_tint()
	main.chunks.update_around(main.player.position, true)
	main._boot_finish(false)
	Sfx.play("pick")
	main._toast("已进入 %d 号世界 · 第 %d 天 · %s" % [i + 1, Game.day, Game.hero().name])


## 空位新建：记下预选槽，进入选角
func new_slot(i: int) -> void:
	main._pending_slot = i
	main._save_confirm = -1
	main._open_hero_select("save")


## 删除世界：首次点变「确认删除？」，再点才真删
func delete_slot(i: int) -> void:
	if main._save_confirm != i:
		main._save_confirm = i
		refresh_save_list()
		return
	main._save_confirm = -1
	Save.erase_slot(i)
	refresh_save_list()
	main._toast("%d 号世界已删除" % (i + 1))


## 关闭存档页：回到标题页或直接继续游戏
func close_save_select(restore_boot := true) -> void:
	if main._save_panel != null:
		main._save_panel.queue_free()
		main._save_panel = null
	if main._save_dim != null:
		main._save_dim.queue_free()
		main._save_dim = null
	main._save_list = null
	main._save_confirm = -1
	if restore_boot and main._boot_panel != null:
		main._boot_panel.visible = true
		main._boot_status.text = boot_info_text()
	elif restore_boot:
		get_tree().paused = false

# ---------- T2.1b：迁移的面板构造（组合挂载；状态与玩法仍由 main 持有） ----------

func build_shop() -> void:
	# 行数较多，套一层纵向滚动容器
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.shop_panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)
	vb.add_child(mk_label("皮埃尔的种子商店", 19))
	main._shop_gold_label = mk_label("", 14)
	vb.add_child(main._shop_gold_label)
	for id in Game.CROPS:
		main._add_crop_row(vb, id)
	for cat in [Game.FISH, Game.MATERIALS]:
		for id in cat:
			main._add_item_row(vb, cat, id)
	for id in Game.PRODUCTS:  # 加工产品只出售
		main._add_item_row(vb, Game.PRODUCTS, id)
	for id in Game.DISHES:  # 料理可出售（灶台现做）
		main._add_item_row(vb, Game.DISHES, id)
	var up_row := HBoxContainer.new()
	up_row.add_theme_constant_override("separation", 8)
	vb.add_child(up_row)
	var up_l := mk_label("工具升级（铜 3x3 / 铁 5x5 范围）", 14)
	up_l.custom_minimum_size = Vector2(250, 0)
	up_row.add_child(up_l)
	main._hoe_btn = mk_btn("")
	main._hoe_btn.pressed.connect(main._upgrade.bind("hoe"))
	up_row.add_child(main._hoe_btn)
	main._can_btn = mk_btn("")
	main._can_btn.pressed.connect(main._upgrade.bind("can"))
	up_row.add_child(main._can_btn)
	# 家禽养殖：买小鸡
	var ck_row := HBoxContainer.new()
	ck_row.add_theme_constant_override("separation", 8)
	vb.add_child(ck_row)
	var ck_l := mk_label("小鸡（住在屋旁鸡舍，每天下一颗蛋）", 14)
	ck_l.custom_minimum_size = Vector2(250, 0)
	ck_row.add_child(ck_l)
	main._chicken_btn = mk_btn("")
	main._chicken_btn.pressed.connect(main._buy_chicken)
	ck_row.add_child(main._chicken_btn)
	# 牛羊牧场：买奶牛/绵羊（住西侧畜棚，过夜产出）
	var cow_row := HBoxContainer.new()
	cow_row.add_theme_constant_override("separation", 8)
	vb.add_child(cow_row)
	var cow_l := mk_label("买奶牛（每天产一瓶牛奶，可做奶酪）", 14)
	cow_l.custom_minimum_size = Vector2(250, 0)
	cow_row.add_child(cow_l)
	main._cow_btn = mk_btn("")
	main._cow_btn.pressed.connect(main._buy_livestock.bind("cow"))
	cow_row.add_child(main._cow_btn)
	var sheep_row := HBoxContainer.new()
	sheep_row.add_theme_constant_override("separation", 8)
	vb.add_child(sheep_row)
	var sheep_l := mk_label("买绵羊（每天产一团羊毛）", 14)
	sheep_l.custom_minimum_size = Vector2(250, 0)
	sheep_row.add_child(sheep_l)
	main._sheep_btn = mk_btn("")
	main._sheep_btn.pressed.connect(main._buy_livestock.bind("sheep"))
	sheep_row.add_child(main._sheep_btn)
	# 温室建造：玻璃房内无视季节，冬天也能种
	var gh_row := HBoxContainer.new()
	gh_row.add_theme_constant_override("separation", 8)
	vb.add_child(gh_row)
	var gh_l := mk_label("建造温室（东侧玻璃房，冬天也能种植）", 14)
	gh_l.custom_minimum_size = Vector2(250, 0)
	gh_row.add_child(gh_l)
	main._gh_btn = mk_btn("")
	main._gh_btn.pressed.connect(main._buy_greenhouse)
	gh_row.add_child(main._gh_btn)
	# 钓竿升级：铜钓竿
	var rod_row := HBoxContainer.new()
	rod_row.add_theme_constant_override("separation", 8)
	vb.add_child(rod_row)
	var rod_l := mk_label("钓竿升级为铜钓竿（收线更稳，稀有鱼出现率翻倍）", 14)
	rod_l.custom_minimum_size = Vector2(250, 0)
	rod_row.add_child(rod_l)
	main._rod_btn = mk_btn("")
	main._rod_btn.pressed.connect(main._upgrade_rod)
	rod_row.add_child(main._rod_btn)
	# 镐头升级：决定能下到矿洞第几层，以及每下挖掉多少矿岩血量
	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 8)
	vb.add_child(pick_row)
	var pick_l := mk_label("镐头升级（铜镐下到 8 层、铁镐 12 层，每下伤害更高）", 14)
	pick_l.custom_minimum_size = Vector2(300, 0)
	pick_row.add_child(pick_l)
	main._pick_btn = mk_btn("")
	main._pick_btn.pressed.connect(main._upgrade_pick)
	pick_row.add_child(main._pick_btn)
	# 宠物领养：猫/狗各一只
	for pk in ["cat", "dog"]:
		var p_row := HBoxContainer.new()
		p_row.add_theme_constant_override("separation", 8)
		vb.add_child(p_row)
		var p_l := mk_label("领养%s（跟着你散步，按 E 摸摸头）" % ("小猫" if pk == "cat" else "小狗"), 14)
		p_l.custom_minimum_size = Vector2(250, 0)
		p_row.add_child(p_l)
		var p_btn := mk_btn("")
		p_btn.pressed.connect(main._adopt_pet.bind(pk))
		p_row.add_child(p_btn)
		main._pet_btns[pk] = p_btn
	# 宠物窝：建好后可以把猫狗安放在窝边待命
	var ph_row := HBoxContainer.new()
	ph_row.add_theme_constant_override("separation", 8)
	vb.add_child(ph_row)
	var ph_l := mk_label("建宠物窝（在窝边按 E 让猫狗回窝待命/放出）", 14)
	ph_l.custom_minimum_size = Vector2(300, 0)
	ph_row.add_child(ph_l)
	main._pet_house_btn = mk_btn("")
	main._pet_house_btn.pressed.connect(main._buy_pet_house)
	ph_row.add_child(main._pet_house_btn)
	vb.add_child(mk_label("按 E / Esc 关闭", 12))

func add_crop_row(vb: VBoxContainer, id: String) -> void:
	var c: Dictionary = Game.CROPS[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var name_l := mk_label("%s（种子%dg / 售%dg）" % [c.name, c.seed_cost, c.sell], 14)
	name_l.custom_minimum_size = Vector2(250, 0)
	row.add_child(name_l)
	var count_l := mk_label("", 14)
	count_l.custom_minimum_size = Vector2(150, 0)
	row.add_child(count_l)
	main._shop_rows[id] = count_l
	main._shop_kinds[id] = "crop"
	var buy := mk_btn("买1种")
	buy.pressed.connect(main._buy.bind(id))
	row.add_child(buy)
	var s1 := mk_btn("卖1")
	s1.pressed.connect(main._sell.bind(id, false))
	row.add_child(s1)
	var sa := mk_btn("全卖")
	sa.pressed.connect(main._sell.bind(id, true))
	row.add_child(sa)

func add_item_row(vb: VBoxContainer, cat: Dictionary, id: String) -> void:
	var info: Dictionary = cat[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var name_l := mk_label("%s（售%dg）" % [info.name, info.sell], 14)
	name_l.custom_minimum_size = Vector2(250, 0)
	row.add_child(name_l)
	var count_l := mk_label("", 14)
	count_l.custom_minimum_size = Vector2(150, 0)
	row.add_child(count_l)
	main._shop_rows[id] = count_l
	main._shop_kinds[id] = "item"
	var s1 := mk_btn("卖1")
	s1.pressed.connect(main._sell_item.bind(cat, id, false))
	row.add_child(s1)
	var sa := mk_btn("全卖")
	sa.pressed.connect(main._sell_item.bind(cat, id, true))
	row.add_child(sa)

func build_pet_house() -> void:
	var img := Image.create(26, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var roof := Color(0.44, 0.27, 0.20)
	var roof_hi := Color(0.56, 0.36, 0.27)
	var wall := Color(0.78, 0.55, 0.33)
	var wall_dk := Color(0.58, 0.39, 0.23)
	var hole := Color(0.15, 0.11, 0.09)
	var cx := 13
	# 人字屋顶
	for y in 8:
		var half := 3 + y
		for x in range(cx - half, cx + half + 1):
			if x < 0 or x >= 26:
				continue
			img.set_pixel(x, y, roof_hi if y < 2 else roof)
	# 木墙（两侧与底部加深，当作描边）
	for y in range(8, 21):
		for x in range(4, 22):
			var c := wall
			if x <= 5 or x >= 20 or y >= 19:
				c = wall_dk
			img.set_pixel(x, y, c)
	# 圆拱门洞
	for y in range(13, 21):
		for x in range(10, 17):
			if y < 15 and (x <= 10 or x >= 16):
				continue
			img.set_pixel(x, y, hole)
	# 门口两侧的小名牌
	img.set_pixel(8, 17, Color(0.95, 0.90, 0.78))
	img.set_pixel(18, 17, Color(0.95, 0.90, 0.78))
	main._pet_house = Sprite2D.new()
	main._pet_house.texture = ImageTexture.create_from_image(img)
	main._pet_house.position = main._pet_house_pos()
	main._pet_house.scale = Vector2(2, 2)
	main._pet_house.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	main._pet_house.visible = Game.pet_house
	add_child(main._pet_house)

func build_structures_ui() -> void:
	# ---- 建造面板 ----
	var m := make_modal(780.0, 280.0)
	main._build_dim = m[0]
	main._build_panel = m[1]
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	main._build_panel.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	var title := mk_label("建 造", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	main._build_gold = mk_label("", 14)
	main._build_gold.add_theme_color_override("font_color", Color(1, 0.86, 0.42))
	top.add_child(main._build_gold)
	var close := mk_btn("×")
	close.custom_minimum_size = Vector2(34, 30)
	close.pressed.connect(func() -> void: main._toggle_build(false))
	top.add_child(close)
	vb.add_child(mk_label("农舍东侧有 4 个建筑位：造好后走过去按 E 进门（都是独立界面）", 13))
	for id in Game.BUILD_DEFS:
		var d: Dictionary = Game.BUILD_DEFS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var nm := mk_label(String(d.name), 16)
		nm.custom_minimum_size = Vector2(110, 0)
		row.add_child(nm)
		var desc := mk_label(String(d.desc), 12)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(330, 0)
		desc.modulate = Color(1, 1, 1, 0.72)
		row.add_child(desc)
		var cost := mk_label("", 13)
		cost.custom_minimum_size = Vector2(170, 0)
		cost.add_theme_color_override("font_color", Color(1, 0.86, 0.42))
		row.add_child(cost)
		var btn := mk_btn("建造")
		btn.custom_minimum_size = Vector2(74, 30)
		btn.pressed.connect(main._buy_building.bind(id))
		row.add_child(btn)
		main._build_rows[id] = {"btn": btn, "cost": cost}
	vb.add_child(mk_label("小屋仓库：进门后把背包材料存着，最多存 8 种；矿洞挖到的东西也能存", 12))
	vb.add_child(mk_label("矿洞入口：进门后一层层往下挖，每镐 4 体力；深层有宝箱、怪物与金/铱矿", 12))
	vb.add_child(mk_label("按 V / Esc 关闭", 12))

	# ---- 仓库界面 ----
	var ms := make_modal(800.0, 470.0)
	main._storage_dim = ms[0]
	main._storage_panel = ms[1]
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 8)
	main._storage_panel.add_child(svb)
	var stop := HBoxContainer.new()
	stop.add_theme_constant_override("separation", 10)
	svb.add_child(stop)
	var stitle := mk_label("仓 库", 22)
	stitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop.add_child(stitle)
	main._storage_cap = mk_label("", 14)
	main._storage_cap.add_theme_color_override("font_color", Color(0.66, 0.9, 0.72))
	stop.add_child(main._storage_cap)
	var sclose := mk_btn("×")
	sclose.custom_minimum_size = Vector2(34, 30)
	sclose.pressed.connect(func() -> void: main._toggle_storage(false))
	stop.add_child(sclose)
	svb.add_child(mk_label("背包里的材料和加工品都能存进来，取出后直接回到背包", 13))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	svb.add_child(sc)
	main._storage_list = VBoxContainer.new()
	main._storage_list.add_theme_constant_override("separation", 6)
	main._storage_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(main._storage_list)
	var sfoot := HBoxContainer.new()
	sfoot.alignment = BoxContainer.ALIGNMENT_END
	svb.add_child(sfoot)
	var leave := mk_btn("离开仓库（返回农场）")
	leave.custom_minimum_size = Vector2(200, 32)
	leave.pressed.connect(func() -> void: main._toggle_storage(false))
	sfoot.add_child(leave)

func build_craft() -> void:
	main.craft_panel = PanelContainer.new()
	main.craft_panel.anchor_left = 0.5
	main.craft_panel.anchor_top = 0.5
	main.craft_panel.anchor_right = 0.5
	main.craft_panel.anchor_bottom = 0.5
	main.craft_panel.offset_left = -250.0
	main.craft_panel.offset_top = -330.0
	main.craft_panel.offset_right = 250.0
	main.craft_panel.offset_bottom = 330.0
	main.craft_panel.visible = false
	ui_root().add_child(main.craft_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	main.craft_panel.add_child(vb)
	vb.add_child(mk_label("制作", 20))
	main._craft_gold = mk_label("", 13)
	vb.add_child(main._craft_gold)
	for id in Game.RECIPES:
		var r: Dictionary = Game.RECIPES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var parts := []
		for k in r.cost:
			parts.append("%s x%d" % [Game.MATERIALS[k].name, r.cost[k]])
		var name_l := mk_label("%s（%s）" % [r.name, " + ".join(parts)], 15)
		name_l.custom_minimum_size = Vector2(260, 0)
		row.add_child(name_l)
		var have_l := mk_label("", 14)
		have_l.custom_minimum_size = Vector2(130, 0)
		row.add_child(have_l)
		main._craft_rows[id] = have_l
		var b := mk_btn("制作并放置")
		b.pressed.connect(main._craft_start.bind(id))
		row.add_child(b)
	vb.add_child(mk_label("稻草人：守护周围作物，夜里乌鸦不敢来", 13))
	vb.add_child(mk_label("洒水器：每天清晨自动浇灌上下左右四格", 13))
	vb.add_child(mk_label("高级洒水器：金色喷头，清晨自动浇灌 3x3 九宫格", 13))
	vb.add_child(mk_label("速效肥：对已种作物的格子按空格施肥，立刻长一节", 13))
	vb.add_child(mk_label("蛋黄酱机：按 E 放入鸡蛋，隔天收蛋黄酱（160g）", 13))
	vb.add_child(mk_label("食品加工机：按 E 放入南瓜/草莓/防风草，隔天变派/酱/腌菜", 13))
	vb.add_child(mk_label("灶台：放到农田格子上，对它按 E 打开烹饪面板做料理", 13))
	vb.add_child(mk_label("熔炉：按 E 放入铜矿/铁矿，隔天熔成铜锭（150g）/铁锭（320g）", 13))
	vb.add_child(mk_label("奶酪机：按 E 放入牛奶，隔天变奶酪（550g）", 13))
	vb.add_child(mk_label("按 C / Esc 关闭", 12))

func build_dex() -> void:
	main._dex_panel = PanelContainer.new()
	main._dex_panel.anchor_left = 0.5
	main._dex_panel.anchor_top = 0.5
	main._dex_panel.anchor_right = 0.5
	main._dex_panel.anchor_bottom = 0.5
	main._dex_panel.offset_left = -290.0
	main._dex_panel.offset_top = -330.0
	main._dex_panel.offset_right = 290.0
	main._dex_panel.offset_bottom = 330.0
	main._dex_panel.visible = false
	ui_root().add_child(main._dex_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	main._dex_panel.add_child(vb)
	var title := mk_label("图鉴 · 技能 · 成就", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	# 技能
	var st := mk_label("—— 技能 ——", 14)
	st.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(st)
	for kind in ["farm", "fish", "gather"]:
		var l := mk_label("", 13)
		vb.add_child(l)
		main._dex_skill_labels[kind] = l
	vb.add_child(mk_label("收获/钓鱼/采集/交付订单得经验，每 100 点升 1 级，体力上限 +10", 12))
	# 鱼类图鉴
	var ft := mk_label("—— 鱼类图鉴 ——", 14)
	ft.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ft)
	for id in Game.FISH:
		var fl := mk_label("", 13)
		vb.add_child(fl)
		main._dex_fish_labels[id] = fl
	main._dex_chest = mk_label("", 13)
	vb.add_child(main._dex_chest)
	# 成就
	var at := mk_label("—— 成就 ——", 14)
	at.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(at)
	for id in Game.ACHIEVEMENTS:
		var al := mk_label("", 13)
		vb.add_child(al)
		main._dex_ach_labels[id] = al
	var close_l := mk_label("按 G / E / Esc 关闭", 12)
	close_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(close_l)

func build_help() -> void:
	main.help_panel = PanelContainer.new()
	main.help_panel.anchor_left = 0.5
	main.help_panel.anchor_top = 0.5
	main.help_panel.anchor_right = 0.5
	main.help_panel.anchor_bottom = 0.5
	main.help_panel.offset_left = -455.0
	main.help_panel.offset_top = -330.0
	main.help_panel.offset_right = 455.0
	main.help_panel.offset_bottom = 330.0
	main.help_panel.visible = false
	ui_root().add_child(main.help_panel)
	# 双栏布局：左右两列各 6 个分区，容纳 12 块玩法说明
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	main.help_panel.add_child(hb)
	var col_l := VBoxContainer.new()
	col_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_l.add_theme_constant_override("separation", 3)
	var col_r := VBoxContainer.new()
	col_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_r.add_theme_constant_override("separation", 3)
	hb.add_child(col_l)
	hb.add_child(col_r)
	var title := mk_label("《星露谷Like》玩法说明", 21)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col_l.add_child(title)
	main._help_section(col_l, "基础操作", [
		"WASD / 方向键 移动　　空格 / 鼠标左键 使用工具　　E 互动",
		"1-0 切换工具　　I 背包　　C 制作　　V 建造　　H 帮助　　Esc 设置 / 关闭　　F5 存档 / F9 读档　　M 音乐",
		"J 收获 / K 浇水 / F 开垦 / P 种植：默认附近 3×3，按 %s %s；%s 打开%s" % [
			key_cap("aoe_toggle"), TouchScript.ACTION_LABELS["aoe_toggle"],
			key_cap("codex"), TouchScript.ACTION_LABELS["codex"]],
		"R 花钱传送（每次 200g）",
		"Tab 小地图放大缩小（也能直接点小地图）　　T 和联机好友打字聊天",
	])
	main._help_section(col_l, "种田流程", [
		"1 锄头开垦 → 3~6/9/0 播种 → 2 浇水 → 每天浇水才生长 → 成熟后空格收获",
		"首日跟着屏幕左侧「新手引导」做：锄地→浇水→播种→收获→卖货，完成奖 200g + 种子",
		"玉米/蓝莓收获后不拔根，过几天会再次结果；蓝莓一次结两颗",
		"对着货摊按 E 开商店：买种子、卖作物和鱼、升级工具",
	])
	main._help_section(col_l, "四季轮作（新增）", [
		"每季 14 天轮换春夏秋冬：春萝卜土豆草莓 / 夏草莓玉米蓝莓 / 秋南瓜玉米蓝莓",
		"冬季休耕不能播种（已种的继续长），改为钓鱼、挖矿、加工与节日为主",
		"商店可建温室（东侧玻璃房）：温室内无视季节，冬天也能种任何作物",
		"换季地面与树木随之变色，冬天下雪；雨天自动浇灌农田、鱼更容易上钩",
	])
	main._help_section(col_l, "钓鱼（7 鱼竿）", [
		"池塘边空格甩竿 → 浮漂变红瞬间再按空格提竿",
		"光标进入绿区时按空格（手机上点「用」）算命中，命中 3 次、失误 3 次内就能拉上来；鱼王需命中 5 次",
		"虹鳟只在 18:00 后，月光鱼 20:00 后、雨鱼雨天；雨天鱼更容易上钩",
		"商店可升铜钓竿（1800g+铜x5）：绿区更大、光标更慢，稀有鱼出现率翻倍",
		"传说鱼王上钩时绿区很窄（价值 1200g）；12% 概率钓上宝箱",
	])
	main._help_section(col_l, "采集与制作（8 斧镐 / C 制作）", [
		"8 斧镐对着树按空格就能砍倒：得木材并留下树桩（砍树状态随存档保存）",
		"敲石头得石料、敲树枝得木材，北边野莓丛按 E 采摘野莓，每天会补充刷新",
		"洒水器浇四邻格；高级洒水器（铁锭造）浇 3x3；速效肥让作物立刻长一节",
		"制作后移动到目标格子按空格放置，Esc 取消",
	])
	main._help_section(col_l, "地图与三区（轻扩图）", [
		"西侧森林采集区：野莓、蘑菇、倒木与矿岩更密集，前期攒材料就去这儿",
		"东侧河岸：整条河都能甩竿，沿石板小径走到木栈道上钓鱼最稳",
		"无限地图：核心农场四周不再封边，越过边界后自动生成新地形（边走边加载、走远即卸载）",
		"Tab 放大后小地图跟随玩家：深绿=森林、蓝色=河流，玩家白点带描边",
	])
	main._help_section(col_l, "矿洞挖矿与熔炉（新增）", [
		"东侧矿洞区每天刷新矿岩：8 斧镐敲击，可得铜矿/铁矿/宝石",
		"C 造熔炉（石8木2）：放矿隔夜铸锭；金币+矿可升铜→铁→金锄壶（3x3/5x5/7x7）",
	])
	main._help_section(col_r, "烹饪料理（新增）", [
		"C 制作灶台（石6木4）放到农田，对灶台按 E 打开烹饪面板",
		"沙拉/浓汤/甜点吃下大量回体力，也能卖钱，熬夜赶工必备",
	])
	main._help_section(col_r, "送礼与好感（新增）", [
		"罗莎在花田、老本在集市散步，靠近按 E 打开送礼面板",
		"作物/鱼/矿石/产品/料理都能送，好感 = 售价的 1/10（最高 +8），每天 2 份",
		"好感达 20/40/60/80 首次回赠：金币/种子/宝石/挚友大礼；聊天每天一次 +10",
	])
	main._help_section(col_r, "加工产业链（新增）", [
		"C 制作蛋黄酱机/食品加工机/灶台/熔炉/奶酪机，放到农田格子上",
		"对着机器按 E 放入原料，隔天机器亮金点再按 E 收成品",
		"蛋→蛋黄酱　南瓜→派；矿→铜/铁锭　牛奶→奶酪，售价更高",
	])
	main._help_section(col_r, "宠物与节日（新增）", [
		"商店领养小猫/小狗（500g），按 E 摸头 +30 心情；再建个宠物窝（800g）就能把它们安放在窝边",
		"每 7 天一次节日：7 日钓鱼大赛（3 条奖 300g）、14 日丰收祭（5 株奖 400g）",
	])
	main._help_section(col_r, "建筑与矿洞（新增）", [
		"V 打开建造面板：小屋仓库（1200g+木20）、矿洞入口（1500g+木30），造在农舍东侧 4 个建筑位",
		"走到建筑门口按 E：小屋进仓库界面（背包 ↔ 仓库存取，最多 8 种）；矿洞入口直接进地下矿洞场景（另一张地图）",
		"矿洞里 8 斧镐敲矿岩（每下 4 体力），挖掉六成梯子出现，走过去按 E 下一层；踩入口梯子按 E 回地面",
		"洞里怪物（史莱姆/蝙蝠）靠近会撞人扣生命，用镐敲两下赶跑；生命归零会被抬回地面并损失金币",
		"第 3/6/9/12 层有宝箱（金币 + 稀有矿）；第 4 层起有金矿，第 7 层起有铱矿",
		"镐头决定能下几层：木镐 4 层、铜镐 8 层、铁镐 12 层，商店可升级，每级伤害更高",
	])
	main._help_section(col_r, "订单与养殖", [
		"货摊旁任务板按 E 接订单：每天 3 张，交作物/鱼/材料得金币与好感",
		"养鸡 800g/只（最多4）每天下蛋；奶牛 2500g、绵羊 2000g 住畜棚产奶产毛",
		"七天阶段目标显示在左上（没做完的会一直保留），按 Y 看全部 7 条清单",
		"目标不会过期：隔几天再补做也算，达成后自动发金币与对应季节种子",
		"B 打开收集包：交作物/鱼/矿石/牧产换金币 + 永久体力上限",
		"每天起床会弹「农场小报」：天气、当季作物、订单与节日提醒；Esc/空格关闭",
	])
	main._help_section(col_r, "图鉴·技能·存档（G）", [
		"按 G 打开面板：技能等级、6 种鱼类图鉴（含鱼王）、宝箱与成就进度",
		"收获/钓鱼/采集/订单攒经验，每 100 点升 1 级体力上限 +10",
		"家门口按 E 睡觉：回满体力进入次日并自动存档（F5/F9 手动存读档）",
	])
	var close_l := mk_label("按 H / E / Esc 关闭", 13)
	close_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col_r.add_child(close_l)

func build_settings() -> void:
	# 半透明黑色遮罩：压暗背后画面、挡住点击穿透（鼠标事件由它吸收）
	main._settings_dim = ColorRect.new()
	main._settings_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	main._settings_dim.anchor_right = 1.0
	main._settings_dim.anchor_bottom = 1.0
	main._settings_dim.color = Color(0.04, 0.03, 0.02, 0.92)
	main._settings_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	main._settings_dim.visible = false
	ui_root().add_child(main._settings_dim)
	main._settings_panel = PanelContainer.new()
	main._settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	main._settings_panel.anchor_left = 0.5
	main._settings_panel.anchor_top = 0.5
	main._settings_panel.anchor_right = 0.5
	main._settings_panel.anchor_bottom = 0.5
	main._settings_panel.offset_left = -250.0
	main._settings_panel.offset_top = -290.0
	main._settings_panel.offset_right = 250.0
	main._settings_panel.offset_bottom = 290.0
	main._settings_panel.visible = false
	# 实色底板：设置面板盖在压暗的场景/标题之上，避免下层文字透出来
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.1, 0.08, 0.98)
	sb.border_color = Color(0.36, 0.28, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	main._settings_panel.add_theme_stylebox_override("panel", sb)
	ui_root().add_child(main._settings_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 9)
	main._settings_panel.add_child(vb)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(460, 0)
	vb.add_child(pad)
	var title := mk_label("设 置", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	vb.add_child(HSeparator.new())
	# 音乐
	var row_m = main._settings_row(vb, "音乐")
	main._set_music_btn = mk_btn("开启")
	main._set_music_btn.custom_minimum_size = Vector2(110, 32)
	main._set_music_btn.pressed.connect(main._on_music_toggle)
	row_m.add_child(main._set_music_btn)
	var pair_m = main._settings_slider(vb, main._on_music_volume)
	main._set_music_slider = pair_m[0]
	main._set_music_pct = pair_m[1]
	# 音效
	var row_s = main._settings_row(vb, "音效")
	main._set_sfx_btn = mk_btn("开启")
	main._set_sfx_btn.custom_minimum_size = Vector2(110, 32)
	main._set_sfx_btn.pressed.connect(main._on_sfx_toggle)
	row_s.add_child(main._set_sfx_btn)
	var pair_s = main._settings_slider(vb, main._on_sfx_volume)
	main._set_sfx_slider = pair_s[0]
	main._set_sfx_pct = pair_s[1]
	vb.add_child(HSeparator.new())
	# 触屏按钮 / 界面缩放 / 全屏
	var row_t = main._settings_row(vb, "触屏按钮")
	main._set_touch_btn = mk_btn("自动")
	main._set_touch_btn.custom_minimum_size = Vector2(110, 32)
	main._set_touch_btn.pressed.connect(main._on_touch_cycle)
	row_t.add_child(main._set_touch_btn)
	var row_c = main._settings_row(vb, "界面缩放")
	main._set_scale_btn = mk_btn("100%")
	main._set_scale_btn.custom_minimum_size = Vector2(110, 32)
	main._set_scale_btn.pressed.connect(main._on_scale_cycle)
	row_c.add_child(main._set_scale_btn)
	var row_f = main._settings_row(vb, "全屏显示")
	main._set_fs_btn = mk_btn("进入全屏")
	main._set_fs_btn.custom_minimum_size = Vector2(110, 32)
	main._set_fs_btn.pressed.connect(main._on_fullscreen_toggle)
	row_f.add_child(main._set_fs_btn)
	# 低配模式：关掉氛围粒子与萤火，移动端省电
	var row_p = main._settings_row(vb, "低配模式")
	main._set_perf_btn = mk_btn("关闭")
	main._set_perf_btn.custom_minimum_size = Vector2(110, 32)
	main._set_perf_btn.pressed.connect(main._on_perf_toggle)
	row_p.add_child(main._set_perf_btn)
	vb.add_child(HSeparator.new())
	# 存档操作：保存 / 读取
	var row_sv := HBoxContainer.new()
	row_sv.add_theme_constant_override("separation", 10)
	vb.add_child(row_sv)
	var b_save := mk_btn("保存进度（F5）")
	b_save.custom_minimum_size = Vector2(0, 36)
	b_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_save.pressed.connect(func() -> void: main._do_save())
	row_sv.add_child(b_save)
	var b_load := mk_btn("读取存档（F9）")
	b_load.custom_minimum_size = Vector2(0, 36)
	b_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_load.pressed.connect(func() -> void: main._do_load())
	row_sv.add_child(b_load)
	# 新游戏 / 返回标题
	var row_ng := HBoxContainer.new()
	row_ng.add_theme_constant_override("separation", 10)
	vb.add_child(row_ng)
	main._set_new_btn = mk_btn("开始新游戏")
	main._set_new_btn.custom_minimum_size = Vector2(0, 36)
	main._set_new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main._set_new_btn.pressed.connect(main._settings_new_game)
	row_ng.add_child(main._set_new_btn)
	var b_title := mk_btn("返回标题画面")
	b_title.custom_minimum_size = Vector2(0, 36)
	b_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_title.pressed.connect(main._settings_back_title)
	row_ng.add_child(b_title)
	var tip := mk_label("Esc 随时打开或关闭设置 · 手机上触屏按钮会自动出现", 12)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.custom_minimum_size = Vector2(460, 0)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.modulate = Color(1, 1, 1, 0.66)
	vb.add_child(tip)
	var back := mk_btn("返 回")
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func() -> void: main._toggle_settings(false))
	vb.add_child(back)

func build_boot() -> void:
	get_tree().paused = true
	main._boot_panel = PanelContainer.new()
	main._boot_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	main._boot_panel.anchor_left = 0.5
	main._boot_panel.anchor_top = 0.5
	main._boot_panel.anchor_right = 0.5
	main._boot_panel.anchor_bottom = 0.5
	main._boot_panel.offset_left = -290.0
	main._boot_panel.offset_top = -238.0
	main._boot_panel.offset_right = 290.0
	main._boot_panel.offset_bottom = 238.0
	ui_root().add_child(main._boot_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 9)
	main._boot_panel.add_child(vb)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(540, 0)
	vb.add_child(pad)
	# 标题
	var title := mk_label("像 素 农 场", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := mk_label("四季流转 · 双人联机", 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.8)
	vb.add_child(sub)
	var hr := HSeparator.new()
	vb.add_child(hr)
	# 存档信息
	main._boot_status = mk_label(boot_info_text(), 13)
	main._boot_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main._boot_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main._boot_status.custom_minimum_size = Vector2(540, 0)
	vb.add_child(main._boot_status)
	var b_solo := mk_btn("开始游戏（选择世界）")
	b_solo.custom_minimum_size = Vector2(0, 40)
	b_solo.pressed.connect(open_save_select)
	vb.add_child(b_solo)
	main._boot_btn_new = mk_btn("新游戏（新建一个世界）")
	main._boot_btn_new.custom_minimum_size = Vector2(0, 36)
	main._boot_btn_new.pressed.connect(main._boot_new)
	vb.add_child(main._boot_btn_new)
	var b_host := mk_btn("建房联机（生成房间码给好友）")
	b_host.custom_minimum_size = Vector2(0, 40)
	b_host.pressed.connect(main._boot_host)
	vb.add_child(b_host)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	main._boot_input = LineEdit.new()
	main._boot_input.placeholder_text = "好友的房间码"
	main._boot_input.custom_minimum_size = Vector2(300, 40)
	main._boot_input.max_length = 4
	main._boot_input.add_theme_font_override("font", main._ui_font)
	main._boot_input.add_theme_font_size_override("font_size", 16)
	main._boot_input.text_submitted.connect(func(_t: String) -> void: main._boot_join())
	row.add_child(main._boot_input)
	var b_join := mk_btn("加入好友")
	b_join.custom_minimum_size = Vector2(230, 40)
	b_join.pressed.connect(main._boot_join)
	row.add_child(b_join)
	var b_opt := mk_btn("设置（音乐 / 音量 / 缩放 / 全屏）")
	b_opt.custom_minimum_size = Vector2(0, 36)
	b_opt.pressed.connect(func() -> void: main._toggle_settings(true))
	vb.add_child(b_opt)
	var tip := mk_label("H 帮助 · Tab 地图 · T 聊天 · Esc 设置 · 联机需中继服务器（网页版用 ?ws= 指定）", 12)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(540, 0)
	tip.modulate = Color(1, 1, 1, 0.65)
	vb.add_child(tip)
	Net.room_created.connect(main._on_room_created)
	Net.joined_room.connect(main._on_joined_room)
	# 标题画面期间先收起小地图与好友箭头，进游戏后再显示
	main._minimap.visible = false
	main._arrow.visible = false

func open_hero_select(origin := "boot") -> void:
	if main._hero_panel != null:
		return
	get_tree().paused = true
	main._hero_back = origin
	if origin == "save":
		if main._save_panel != null:
			main._save_panel.visible = false
		if main._save_dim != null:
			main._save_dim.visible = false
	elif main._boot_panel != null:
		main._boot_panel.visible = false
	# 半透明遮罩：压暗身后的农场与 HUD，让选角页成为视觉焦点
	main._hero_dim = ColorRect.new()
	main._hero_dim.color = Color(0.02, 0.03, 0.05, 0.62)
	main._hero_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	main._hero_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root().add_child(main._hero_dim)
	main._hero_panel = PanelContainer.new()
	main._hero_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	main._hero_panel.anchor_left = 0.5
	main._hero_panel.anchor_top = 0.5
	main._hero_panel.anchor_right = 0.5
	main._hero_panel.anchor_bottom = 0.5
	main._hero_panel.offset_left = -500.0
	main._hero_panel.offset_top = -280.0
	main._hero_panel.offset_right = 500.0
	main._hero_panel.offset_bottom = 280.0
	main._hero_panel.add_theme_stylebox_override("panel", modal_style())
	ui_root().add_child(main._hero_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	main._hero_panel.add_child(vb)
	var title := mk_label("选 择 主 角", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := mk_label("每人一套被动特长 + 一个主动技能（Q 键 / 右下技能按钮，耗体力、有冷却）", 13)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.78)
	vb.add_child(sub)
	var hr := HSeparator.new()
	hr.modulate = Color(1, 1, 1, 0.25)
	vb.add_child(hr)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(row)
	for i in Game.HEROES.size():
		row.add_child(main._hero_card(i))
	var back := mk_btn("← 返回")
	back.custom_minimum_size = Vector2(220, 32)
	back.add_theme_font_size_override("font_size", 13)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(main._close_hero_select)
	vb.add_child(back)

func hero_card(i: int) -> Control:
	var h: Dictionary = Game.HEROES[i]
	var c: Color = h.color
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(214, 0)
	card.add_theme_stylebox_override("panel", hero_card_style(c, false))
	card.mouse_entered.connect(func() -> void:
		card.add_theme_stylebox_override("panel", hero_card_style(c, true)))
	card.mouse_exited.connect(func() -> void:
		card.add_theme_stylebox_override("panel", hero_card_style(c, false)))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	card.add_child(vb)
	# 顶部角色主色条：一眼区分四张卡
	var bar := ColorRect.new()
	bar.color = Color(c.r, c.g, c.b, 0.9)
	bar.custom_minimum_size = Vector2(0, 3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(bar)
	# 立绘：32x64 单元 3 倍最近邻放大（96x192），像素不发糊
	var at := AtlasTexture.new()
	at.atlas = load(String(h.tex))
	at.region = Rect2(0, 0, 32, 64)
	var pic := TextureRect.new()
	pic.texture = at
	pic.custom_minimum_size = Vector2(96, 192)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(pic)
	var nm := mk_label("%s · %s" % [h.name, h.title], 18)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_color_override("font_color", c)
	vb.add_child(nm)
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.18)
	vb.add_child(sep)
	# 被动 / 主动两段：标题行用角色色，描述用次级灰白；耗体力与冷却单独一行小字
	var hp := mk_label("被动 · %s" % h.passive_name, 13)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_theme_color_override("font_color", Color(0.82, 0.87, 0.95))
	vb.add_child(hp)
	var dp := mk_label(String(h.passive_text), 11)
	dp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dp.custom_minimum_size = Vector2(196, 0)
	dp.modulate = Color(1, 1, 1, 0.72)
	vb.add_child(dp)
	var ha := mk_label("主动 · %s（Q）" % h.skill_name, 13)
	ha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ha.add_theme_color_override("font_color", c)
	vb.add_child(ha)
	var da := mk_label(String(h.skill_text), 11)
	da.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	da.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	da.custom_minimum_size = Vector2(196, 0)
	da.modulate = Color(1, 1, 1, 0.72)
	vb.add_child(da)
	var dc := mk_label("耗 %.0f 体力 · 冷却 %.0fs" % [h.cost, h.cd], 10)
	dc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dc.modulate = Color(1, 1, 1, 0.5)
	vb.add_child(dc)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	var b := mk_btn("选 %s" % h.name)
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_stylebox_override("normal", hero_btn_style(c, false))
	b.add_theme_stylebox_override("hover", hero_btn_style(c, true))
	b.add_theme_stylebox_override("pressed", hero_btn_style(c, true))
	b.pressed.connect(func() -> void: main._pick_hero(i))
	vb.add_child(b)
	return card

func free_hero_select() -> void:
	if main._hero_panel != null:
		main._hero_panel.queue_free()
		main._hero_panel = null
	if main._hero_dim != null:
		main._hero_dim.queue_free()
		main._hero_dim = null

func close_hero_select() -> void:
	main._free_hero_select()
	main._pending_slot = -1
	if main._hero_back == "save" and main._save_panel != null:
		main._save_panel.visible = true
		if main._save_dim != null:
			main._save_dim.visible = true
		refresh_save_list()
	elif main._boot_panel != null:
		main._boot_panel.visible = true
		main._boot_status.text = boot_info_text()
	else:
		get_tree().paused = false

func build_bag() -> void:
	main._bag_dim = ColorRect.new()
	main._bag_dim.color = Color(0.02, 0.03, 0.05, 0.6)
	main._bag_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	main._bag_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._bag_dim.visible = false
	ui_root().add_child(main._bag_dim)
	main._bag_panel = PanelContainer.new()
	main._bag_panel.anchor_left = 0.5
	main._bag_panel.anchor_top = 0.5
	main._bag_panel.anchor_right = 0.5
	main._bag_panel.anchor_bottom = 0.5
	main._bag_panel.offset_left = -500.0
	main._bag_panel.offset_top = -290.0
	main._bag_panel.offset_right = 500.0
	main._bag_panel.offset_bottom = 290.0
	main._bag_panel.add_theme_stylebox_override("panel", modal_style())
	main._bag_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停世界时面板仍可点
	main._bag_panel.visible = false
	ui_root().add_child(main._bag_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	main._bag_panel.add_child(vb)
	# 顶栏：标题 · 金币 · 关闭
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	var title := mk_label("背 包", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	main._bag_gold = mk_label("", 14)
	main._bag_gold.add_theme_color_override("font_color", Color(1, 0.86, 0.42))
	top.add_child(main._bag_gold)
	var close := mk_btn("×")
	close.custom_minimum_size = Vector2(34, 30)
	close.add_theme_font_size_override("font_size", 16)
	close.pressed.connect(func() -> void: main._toggle_bag(false))
	top.add_child(close)
	# 分类标签行：整排等宽，选中项用蓝色高亮
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vb.add_child(tabs)
	for i in main.BAG_TABS.size():
		var tb := mk_btn(String(main.BAG_TABS[i][1]))
		tb.custom_minimum_size = Vector2(0, 28)
		tb.add_theme_font_size_override("font_size", 12)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(main._on_bag_tab.bind(i))
		main._bag_tabs.append(tb)
		tabs.add_child(tb)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	vb.add_child(body)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	main._bag_grid = GridContainer.new()
	main._bag_grid.columns = 6
	main._bag_grid.add_theme_constant_override("h_separation", 8)
	main._bag_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(main._bag_grid)
	# 右侧详情
	var det := PanelContainer.new()
	det.custom_minimum_size = Vector2(250, 0)
	det.add_theme_stylebox_override("panel", bag_side_style())
	body.add_child(det)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 7)
	det.add_child(dv)
	main._bag_name = mk_label("—", 19)
	main._bag_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main._bag_name.custom_minimum_size = Vector2(214, 0)
	dv.add_child(main._bag_name)
	main._bag_cat = mk_label("", 12)
	main._bag_cat.modulate = Color(1, 1, 1, 0.7)
	dv.add_child(main._bag_cat)
	var sp1 := HSeparator.new()
	sp1.modulate = Color(1, 1, 1, 0.2)
	dv.add_child(sp1)
	main._bag_hold = mk_label("", 13)
	dv.add_child(main._bag_hold)
	main._bag_unit = mk_label("", 13)
	main._bag_unit.add_theme_color_override("font_color", Color(1, 0.86, 0.42))
	dv.add_child(main._bag_unit)
	main._bag_note = mk_label("", 11)
	main._bag_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main._bag_note.custom_minimum_size = Vector2(214, 0)
	main._bag_note.modulate = Color(1, 1, 1, 0.62)
	dv.add_child(main._bag_note)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(sp2)
	main._bag_sell1 = mk_btn("卖 1 个")
	main._bag_sell1.custom_minimum_size = Vector2(0, 32)
	main._bag_sell1.add_theme_font_size_override("font_size", 13)
	main._bag_sell1.pressed.connect(main._bag_sell.bind(false))
	dv.add_child(main._bag_sell1)
	main._bag_sellall = mk_btn("全部卖出")
	main._bag_sellall.custom_minimum_size = Vector2(0, 32)
	main._bag_sellall.add_theme_font_size_override("font_size", 13)
	main._bag_sellall.pressed.connect(main._bag_sell.bind(true))
	dv.add_child(main._bag_sellall)
	var hint := mk_label("I 关闭 · 点格子查看详情 · 卖出按角色加成即时结算", 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.55)
	vb.add_child(hint)
