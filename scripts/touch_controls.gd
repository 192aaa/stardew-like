extends Control
## 手机触屏控制层（程序化 UI）：左下虚拟摇杆 + 右下动作按钮 + 菜单弹窗
## 摇杆经 Input.action_press 驱动 player.gd 现有 Input.get_vector（玩家脚本零改动）
## 按钮经合成 InputEventAction 走与键盘完全一致的处理分支
## 显示与否由设置 touch_buttons 决定（auto=检测触摸设备 / on=强制开 / off=关闭）

var main

## 位置随画布尺寸动态计算（stretch 用 expand 后画布宽度会随手机屏幕比例变化，
## 所以按钮必须贴右/贴底锚定，不能写死坐标）；数值以 1280x720 为基准换算
const BASE_R := 95.0
const KNOB_R := 42.0
const DEAD := 0.16                         # 摇杆死区（比例）

var JOY_AREA := Rect2(0, 290, 330, 280)    # 摇杆感应区（画布坐标，外扩 24px 判定）
var BASE := Vector2(150, 470)              # 摇杆底座中心

var _enabled := false
var _joy_active := false
var _joy_index := -99  # 正在拖动摇杆的手指 index；鼠标为 -1
var _knob := BASE
var _menu_open := false
var _menu: PanelContainer
var _btn_use: Button
var _btn_act: Button
var _btn_more: Button
var _btn_set: Button
var _use_timer: Timer
var _last_btn_ms := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 不用 FULL_RECT 锚点：CanvasLayer 下的锚点尺寸会被引擎在 _ready 后重算，
	# 与手动 size 冲突并刷 WARNING，这里改为完全手动同步视口尺寸
	position = Vector2.ZERO
	_btn_use = _mk_btn("用", Vector2.ZERO, 58.0, 30)
	_btn_use.button_down.connect(_on_use_down)
	_btn_use.button_up.connect(_on_use_up)
	add_child(_btn_use)
	_btn_act = _mk_btn("互动", Vector2.ZERO, 40.0, 16)
	_btn_act.button_down.connect(_on_act_down)
	add_child(_btn_act)
	_btn_more = _mk_btn("菜单", Vector2.ZERO, 34.0, 14)
	_btn_more.pressed.connect(_on_more_pressed)
	add_child(_btn_more)
	_btn_set = _mk_btn("设置", Vector2.ZERO, 34.0, 14)
	_btn_set.pressed.connect(_on_set_pressed)
	add_child(_btn_set)
	_build_menu()
	_use_timer = Timer.new()
	_use_timer.wait_time = 0.4
	_use_timer.timeout.connect(_on_use_repeat)
	add_child(_use_timer)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_sync_size)
	_sync_size()
	visible = false


## CanvasLayer 下的 Control 不会自动跟随视口尺寸，这里手动同步（旋转/全屏切换都会触发）
func _sync_size() -> void:
	size = get_viewport().get_visible_rect().size
	_layout()


## 按当前画布尺寸摆放摇杆与按钮：右/下边缘固定距离，屏幕再宽再长都不会跑偏
func _layout() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	BASE = Vector2(150.0, h - 250.0)
	JOY_AREA = Rect2(0.0, BASE.y - 180.0, 330.0, 280.0)
	_knob = BASE
	if _btn_use != null:
		_place(_btn_use, Vector2(w - 130.0, h - 160.0))
		_place(_btn_act, Vector2(w - 274.0, h - 128.0))
		_place(_btn_more, Vector2(w - 64.0, h - 268.0))
		_place(_btn_set, Vector2(w - 228.0, h - 242.0))
	if _menu != null:
		_menu.position = Vector2(w - 538.0, h * 0.47)
	queue_redraw()


func _place(b: Button, center: Vector2) -> void:
	b.position = center - b.size * 0.5


## 菜单弹窗：手机上没有键盘，把 C/G/H/T/Tab/F5/F9 的功能收进这里
func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.position = Vector2(742, 336)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.1, 0.08, 0.96)
	sb.border_color = Color(0.36, 0.28, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	_menu.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_menu.add_child(vb)
	for item in [
		["收获全部", "harvest_all"], ["浇水全部", "water_all"],
		["制作", "craft"], ["图鉴", "codex"], ["收集包", "bundle"], ["帮助", "help"],
		["聊天", "chat"], ["地图", "minimap"], ["存档", "save_game"],
		["读档", "load_game"],
	]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(120, 30)
		b.add_theme_font_override("font", main._ui_font)
		b.add_theme_font_size_override("font_size", 14)
		var act: String = item[1]
		# 只在菜单仍打开时响应：触屏+模拟鼠标双触发时第二次会自动忽略
		b.pressed.connect(func() -> void:
			if _menu_open:
				_menu_open = false
				_menu.visible = false
				_fire_tap(act))
		vb.add_child(b)
	_menu.visible = false
	add_child(_menu)


## 圆形半透明动作按钮（角半径拉满即成圆形，三种状态各一份样式）
func _mk_btn(txt: String, center: Vector2, r: float, fsize: int) -> Button:
	var b := Button.new()
	b.text = txt
	var d := int(r * 2.0)
	b.custom_minimum_size = Vector2(d, d)
	b.size = Vector2(d, d)
	b.position = center - Vector2(r, r)
	b.add_theme_font_override("font", main._ui_font)
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.7))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.06, 0.55)
	sb.border_color = Color(0.38, 0.3, 0.2, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(d)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = Color(0.26, 0.21, 0.13, 0.82)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## 由 main 在启动与设置变更时调用：按 touch_buttons 决定是否显示
func refresh_mode() -> void:
	var mode := String(Save.setting("touch_buttons", "auto"))
	if mode == "on":
		_enabled = true
	elif mode == "off":
		_enabled = false
	else:
		_enabled = _detect_touch()
	if not _enabled and _joy_active:
		_joy_end()
	visible = _enabled and not _blocked()
	if _enabled:
		queue_redraw()


## 触摸设备检测：引擎的 is_touchscreen_available() 在 iOS Safari / 微信内置浏览器
## 常常返回 false，导致摇杆与按钮完全不显示，所以再补一层 JS 探测；
## 另外支持 URL 参数强制覆盖（?touch=1 强制开 / ?touch=0 强制关），方便排查
func _detect_touch() -> bool:
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("window.location.search", true))
		if q.contains("touch=1"):
			return true
		if q.contains("touch=0"):
			return false
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		# maxTouchPoints > 0 / ontouchstart / 指针为 coarse（触屏）任一成立即视为触屏设备
		var v = JavaScriptBridge.eval(
			"(navigator.maxTouchPoints > 0) || ('ontouchstart' in window)"
			+ " || window.matchMedia('(pointer: coarse)').matches", true)
		return bool(v)
	return false


## 有面板/睡觉/开局/聊天时收起触控层，回到纯键盘或面板交互
func _blocked() -> bool:
	return get_tree().paused or main.sleeping or main._chat_open \
			or main._daily_open \
			or main.settings_open or main.help_open or main.dex_open \
			or main.orders_open or main.bundles_open or main.shop_open or main.craft_open \
			or main.cook_open or main.gift_open or main.dialog_open \
			or main._boot_panel != null


func _process(_d: float) -> void:
	var want := _enabled and not _blocked()
	if want != visible:
		visible = want
		queue_redraw()
	if not want:
		if _joy_active:
			_joy_end()
		if _menu_open:
			_menu_open = false
			_menu.visible = false
		return
	# 放置模式下「设置」按钮临时变成「取消」
	var set_txt := "取消" if main.place_mode != "" else "设置"
	if _btn_set.text != set_txt:
		_btn_set.text = set_txt


# ---------- 摇杆：_input 层捕获，手指滑出感应区也不丢 ----------

func _input(e: InputEvent) -> void:
	# 兜底：自动模式下若检测误判成桌面（老 WebView 常见），只要真的收到触摸就打开触控层
	if not _enabled and e is InputEventScreenTouch and e.pressed \
			and String(Save.setting("touch_buttons", "auto")) == "auto":
		_enabled = true
		if not _blocked():
			visible = true
		queue_redraw()
	if not _enabled or not visible:
		return
	if e is InputEventScreenTouch:
		if e.pressed and not _joy_active and _in_joy(e.position):
			_joy_index = e.index
			_joy_active = true
			_joy_move(e.position)
			get_viewport().set_input_as_handled()
		elif not e.pressed and _joy_active and e.index == _joy_index:
			_joy_end()
			get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and _joy_active and e.index == _joy_index:
		_joy_move(e.position)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		# 鼠标路径：桌面测试与「强制开」时可用；触屏的模拟鼠标也走这里（幂等）
		if e.pressed and not _joy_active and _in_joy(e.position):
			_joy_index = -1
			_joy_active = true
			_joy_move(e.position)
			get_viewport().set_input_as_handled()
		elif not e.pressed and _joy_active and _joy_index == -1:
			_joy_end()
			get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and _joy_active and _joy_index == -1 \
			and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_joy_move(e.position)
		get_viewport().set_input_as_handled()


func _in_joy(p: Vector2) -> bool:
	return JOY_AREA.grow(24.0).has_point(p)


func _joy_move(p: Vector2) -> void:
	var v := p - BASE
	if v.length() > BASE_R:
		v = v.normalized() * BASE_R
	_knob = BASE + v
	var l := v.length() / BASE_R
	var dir := Vector2.ZERO
	if l > DEAD:
		dir = v.normalized() * ((l - DEAD) / (1.0 - DEAD))
	_apply_move(dir)
	queue_redraw()


func _joy_end() -> void:
	_joy_active = false
	_joy_index = -99
	_knob = BASE
	_apply_move(Vector2.ZERO)
	queue_redraw()


## 摇杆向量写进四个方向动作的强度，player.gd 的 Input.get_vector 直接可用
func _apply_move(dir: Vector2) -> void:
	_set_axis("move_left", "move_right", dir.x)
	_set_axis("move_up", "move_down", dir.y)


func _set_axis(neg: String, pos: String, val: float) -> void:
	if val > 0.0:
		Input.action_release(neg)
		Input.action_press(pos, val)
	elif val < 0.0:
		Input.action_release(pos)
		Input.action_press(neg, -val)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


# ---------- 按钮：合成 InputEventAction，与键盘走同一分支 ----------

func _fire(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


## 单发动作（互动/菜单项）：60ms 防抖，防触屏+模拟鼠标双触发
func _fire_tap(action: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_btn_ms < 60:
		return
	_last_btn_ms = now
	_fire(action, true)
	_fire(action, false)


func _on_act_down() -> void:
	_fire_tap("interact")


func _on_more_pressed() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_btn_ms < 60:
		return
	_last_btn_ms = now
	_toggle_menu()


func _toggle_menu() -> void:
	_menu_open = not _menu_open
	_menu.visible = _menu_open


func _on_set_pressed() -> void:
	if main.place_mode != "":
		main._cancel_place()
	else:
		main._toggle_settings(true)


func _on_use_down() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_btn_ms < 60:
		return
	_last_btn_ms = now
	_fire("use", true)
	_use_timer.start()


func _on_use_up() -> void:
	_use_timer.stop()
	_fire("use", false)


## 按住「用」每 0.4s 重发一次使用：连片浇水/收割不用连点
func _on_use_repeat() -> void:
	if _blocked() or main.sleeping:
		_use_timer.stop()
		return
	_fire("use", true)


func _draw() -> void:
	if not _enabled:
		return
	if _joy_active:
		draw_circle(BASE, BASE_R, Color(0.05, 0.04, 0.03, 0.32))
		draw_arc(BASE, BASE_R, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0)
		draw_circle(_knob, KNOB_R, Color(1, 1, 1, 0.55))
		draw_arc(_knob, KNOB_R, 0.0, TAU, 36, Color(1, 1, 1, 0.85), 2.0)
	else:
		# 静止提示圈：告诉玩家左下角这里可以按住拖动
		draw_circle(BASE, BASE_R, Color(0.05, 0.04, 0.03, 0.24))
		draw_arc(BASE, BASE_R, 0.0, TAU, 48, Color(1, 1, 1, 0.42), 2.0)
		draw_circle(BASE, KNOB_R, Color(1, 1, 1, 0.36))
