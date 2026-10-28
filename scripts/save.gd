extends Node
## 存档存储层（自动加载）：Web 端走 localStorage（FileAccess user:// 在浏览器
## 刷新后会丢，不可靠），桌面端走 user://save.json；内容为 JSON 字符串，
## 由 main.gd 负责组装与应用
## 另含通用设置 KV（音量/触屏/缩放等），与存档分开存放，不随清档丢失

const KEY := "stardew_save_v1"
const SAVE_PATH := "user://save.json"
const SETTINGS_KEY := "stardew_settings_v1"
const SETTINGS_PATH := "user://settings.cfg"

var _settings := {}


func _ready() -> void:
	_settings = _settings_load()


## 读取一项设置（不存在时返回默认值）
func setting(key: String, def: Variant = null) -> Variant:
	return _settings.get(key, def)


## 写入一项设置并立即落盘
func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	_settings_store()


func has_save() -> bool:
	return read() != ""


func write(text: String) -> bool:
	if OS.has_feature("web"):
		var ls: Variant = JavaScriptBridge.get_interface("localStorage")
		if ls == null:
			return false
		ls.setItem(KEY, text)
		return true
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func read() -> String:
	if OS.has_feature("web"):
		var ls: Variant = JavaScriptBridge.get_interface("localStorage")
		if ls == null:
			return ""
		var v: Variant = ls.getItem(KEY)
		return String(v) if v != null else ""
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


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
