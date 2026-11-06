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
## 剩余面板（商店/制作/背包/设置/图鉴等）由后续任务 T2.1b 继续迁入。

var main


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
