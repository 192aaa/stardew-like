extends Node
## 存档存储层（自动加载）：Web 端走 localStorage（FileAccess user:// 在浏览器
## 刷新后会丢，不可靠），桌面端走 user://save.json；内容为 JSON 字符串，
## 由 main.gd 负责组装与应用

const KEY := "stardew_save_v1"
const SAVE_PATH := "user://save.json"


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
