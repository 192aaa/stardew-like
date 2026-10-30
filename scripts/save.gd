extends Node
## 存档存储层（自动加载）：Web 端走 localStorage（FileAccess user:// 在浏览器
## 刷新后会丢，不可靠），桌面端走 user://save.json；内容为 JSON 字符串，
## 由 main.gd 负责组装与应用
## 另含通用设置 KV（音量/触屏/缩放等），与存档分开存放，不随清档丢失

const KEY := "stardew_save_v1"
const SAVE_PATH := "user://save.json"
const SETTINGS_KEY := "stardew_settings_v1"
const SETTINGS_PATH := "user://settings.cfg"
## 多世界存档：6 个独立槽位，每槽一份完整世界快照
const SLOT_COUNT := 6

var _settings := {}
## 当前正在玩的世界存档槽（读档/存档/自动存档都落在这里）
var current := 0


func _ready() -> void:
	_settings = _settings_load()
	_migrate_legacy()


## 读取一项设置（不存在时返回默认值）
func setting(key: String, def: Variant = null) -> Variant:
	return _settings.get(key, def)


## 写入一项设置并立即落盘
func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	_settings_store()


func has_save() -> bool:
	return read() != ""


## 写入当前世界存档槽
func write(text: String) -> bool:
	return write_slot(current, text)


## 读取当前世界存档槽
func read() -> String:
	return read_slot(current)


func _slot_key(i: int) -> String:
	return "%s_%d" % [KEY, i]


func _slot_path(i: int) -> String:
	return "user://saves/slot_%d.json" % i


func write_slot(i: int, text: String) -> bool:
	if i < 0 or i >= SLOT_COUNT:
		return false
	if OS.has_feature("web"):
		var ls: Variant = JavaScriptBridge.get_interface("localStorage")
		if ls == null:
			return false
		ls.setItem(_slot_key(i), text)
		return true
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open(_slot_path(i), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func read_slot(i: int) -> String:
	if i < 0 or i >= SLOT_COUNT:
		return ""
	if OS.has_feature("web"):
		var ls: Variant = JavaScriptBridge.get_interface("localStorage")
		if ls == null:
			return ""
		var v: Variant = ls.getItem(_slot_key(i))
		return String(v) if v != null else ""
	var f := FileAccess.open(_slot_path(i), FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func has_slot(i: int) -> bool:
	return read_slot(i) != ""


func erase_slot(i: int) -> void:
	if i < 0 or i >= SLOT_COUNT:
		return
	if OS.has_feature("web"):
		var ls: Variant = JavaScriptBridge.get_interface("localStorage")
		if ls != null:
			ls.removeItem(_slot_key(i))
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path(i)))


## 槽位摘要（解析存档 JSON），空槽返回空字典；标题页/存档列表用
func slot_summary(i: int) -> Dictionary:
	var text := read_slot(i)
	if text.strip_edges() == "":
		return {}
	var d: Variant = JSON.parse_string(text)
	return d if typeof(d) == TYPE_DICTIONARY else {}


func used_slots() -> int:
	var n := 0
	for i in SLOT_COUNT:
		if has_slot(i):
			n += 1
	return n


## 老版本单档（user://save.json / localStorage KEY）自动搬进 0 号槽，不丢进度
func _migrate_legacy() -> void:
	if read_slot(0) != "":
		return
	var old := ""
	if OS.has_feature("web"):
		var ls: Variant = JavaScriptBridge.get_interface("localStorage")
		if ls != null:
			var v: Variant = ls.getItem(KEY)
			old = String(v) if v != null else ""
	else:
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			old = f.get_as_text()
			f.close()
	if old.strip_edges() != "":
		write_slot(0, old)
		print("旧存档已迁移到 1 号世界")


## 设置读盘：解析失败或格式不对一律当作空配置
func _settings_load() -> Dictionary:
	var text := ""
	if OS.has_feature("web"):
		var ls: Variant = JavaScriptBridge.get_interface("localStorage")
		if ls == null:
			return {}
		var v: Variant = ls.getItem(SETTINGS_KEY)
		text = String(v) if v != null else ""
	else:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f == null:
			return {}
		text = f.get_as_text()
		f.close()
	if text.strip_edges() == "":
		return {}
	var d: Variant = JSON.parse_string(text)
	return d if typeof(d) == TYPE_DICTIONARY else {}


func _settings_store() -> void:
	var text := JSON.stringify(_settings)
	if OS.has_feature("web"):
		var ls: Variant = JavaScriptBridge.get_interface("localStorage")
		if ls != null:
			ls.setItem(SETTINGS_KEY, text)
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
