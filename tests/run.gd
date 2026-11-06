extends SceneTree
## C4 最小回归网：自写断言，不引第三方，不依赖 build/、网络、编辑器 GUI。
##
## 执行：godot --headless --path . --script tests/run.gd
##       （godot 不在 PATH 时换成可执行文件绝对路径；失败时退出码非零）
##
## 覆盖边界（如实声明，勿误读为「直连了全部产品实现」）：
## --script 模式不注册项目 Autoload（实测 Engine.has_singleton("Game") == false，
## 手动 Engine.register_singleton 后仍报 Identifier not found: Game），
## 因此 main.gd / farm.gd 在编译期即失败，_do_sleep() / farm.on_new_day() 不可调用。
## · 直连产品代码：季节推导（game.gd 实例）、输入映射（project.godot + InputMap）、
##   存档往返（save.gd 真实文件 IO）、机器转换表（game.gd 数据表）。
## · 规格复刻：时间流速与跨日、作物生长/复生。常量一律通过 Expression 从 main.gd
##   源码动态求值，并对 farm.gd / main.gd 的公式原文做静态防漂移断言；
##   产品改公式时测试会变红，迫使同步，而不是静默通过。

const TEST_SLOT := 5

var _pass := 0
var _fail := 0
var _groups := 0
var _game: Variant
var _save: Variant
var _src_main := ""
var _src_farm := ""
var _slot_backup := ""


func _init() -> void:
	_game = load("res://scripts/game.gd").new()
	_save = load("res://scripts/save.gd").new()
	# 任何用例执行前先备份，确保中途出错也不会误清用户存档
	_slot_backup = _save.read_slot(TEST_SLOT)
	_src_main = FileAccess.get_file_as_string("res://scripts/main.gd")
	_src_farm = FileAccess.get_file_as_string("res://scripts/farm.gd")
	print("C4 最小回归网 · --script 模式")
	print("覆盖边界：main.gd/farm.gd 不可加载；公式类用例为产品常量 + 规格复刻 + 防漂移断言")
	_run_all()
	_restore_slot()
	print("RESULT  cases=%d  pass=%d  fail=%d" % [_groups, _pass, _fail])
	quit(1 if _fail > 0 else 0)


func _run_all() -> void:
	_group("季节推导 · 直连 game.gd")
	_t_season()
	_group("输入映射唯一性 · project.godot + InputMap")
	_t_input_map()
	_group("存档载荷往返与 v1 兼容 · 直连 save.gd")
	_t_save_roundtrip()
	_group("时间流速与跨日 · 源码常量求值 + 规格复刻")
	_t_time_flow()
	_group("作物生长 · 真实 CROPS + 规格复刻")
	_t_crop_growth()
	_group("作物复生 · 真实 CROPS.regrow + 规格复刻")
	_t_crop_regrow()
	_group("MACHINE_INPUTS 转换 · 真实数据表 + 规格复刻")
	_t_machine_inputs()


func _group(name: String) -> void:
	_groups += 1
	print("[%d] %s" % [_groups, name])


func _check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		printerr("  FAIL  ", label, "  ", detail)


# ---------- 1. 季节推导（直连 game.gd 实例，真实函数） ----------
func _t_season() -> void:
	var g: Variant = _game
	_check(int(g.get("SEASON_DAYS")) == 14 and (g.get("SEASONS") as Array).size() == 4,
		"1 季节表：每季 14 天、共 4 季")
	var cases := [
		[1, 0, "春", 1], [14, 0, "春", 14], [15, 1, "夏", 1],
		[28, 1, "夏", 14], [29, 2, "秋", 1], [56, 3, "冬", 14],
		[57, 0, "春", 1],
	]
	var ok := true
	for c in cases:
		g.day = int(c[0])
		if g.season_index() != int(c[1]) or g.season_name() != String(c[2]) \
				or g.season_day() != int(c[3]):
			ok = false
			printerr("    day=", c[0], " got ", g.season_index(), "/",
				g.season_name(), "/", g.season_day())
	_check(ok, "1 season_index/season_name/season_day 跨 56 天正确循环")
	g.day = 1
	var in_spring: bool = g.can_plant("parsnip")
	g.day = 15
	var in_summer: bool = g.can_plant("parsnip")
	_check(in_spring and not in_summer, "1 当季播种判定随季节变化")


# ---------- 2. 输入映射唯一性（直连 project.godot 配置 + InputMap） ----------
func _t_input_map() -> void:
	var txt := FileAccess.get_file_as_string("res://project.godot")
	var re_action := RegEx.new()
	re_action.compile("^([A-Za-z_][A-Za-z_0-9]*)=\\{$")
	var re_key := RegEx.new()
	re_key.compile('"physical_keycode":([0-9]+)')
	var in_input := false
	var cur := ""
	var seen := {}
	var dups: Array = []
	var count := 0
	for line in txt.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("["):
			in_input = (s == "[input]")
			continue
		if not in_input:
			continue
		var ma := re_action.search(s)
		if ma:
			cur = ma.get_string(1)
			continue
		var mk := re_key.search(s)
		if mk and cur != "":
			var kc := int(mk.get_string(1))
			count += 1
			if seen.has(kc):
				dups.append("%d => %s / %s" % [kc, seen[kc], cur])
			else:
				seen[kc] = cur
	_check(dups.is_empty(), "2 所有 action 的 physical_keycode 无重复", ", ".join(dups))
	_check(count >= 30, "2 项目键盘 action 数 >= 30（实际 %d）" % count)
	var aoe := InputMap.action_get_events("aoe_toggle")
	var cod := InputMap.action_get_events("codex")
	_check(aoe.size() > 0 and aoe[0] is InputEventKey and aoe[0].physical_keycode == 88,
		"2 InputMap 实测 aoe_toggle = X(88)")
	_check(cod.size() > 0 and cod[0] is InputEventKey and cod[0].physical_keycode == 71,
		"2 InputMap 实测 codex = G(71)")


# ---------- 3/4. 存档载荷往返（直连 save.gd 真实文件 IO） ----------
func _t_save_roundtrip() -> void:
	var payload := {
		"v": 2, "day": 31, "gold": 12345, "hero_id": 1,
		"tiles": [[-10, -9, 1, 0, "", 0, 0], [-7, -9, 1, 1, "corn", 3, 1]],
		"sprinklers": [[0, 0]], "sprinklers2": [], "scarecrows": [[2, 2]],
		"machines": [[1, 1, "mayo", "egg", ""]],
		"chicken_count": 3, "eggs_ready": 4, "total_eggs": 77,
		"cow_count": 2, "sheep_count": 1, "milk_ready": 1, "wool_ready": 1,
		"total_milk": 55, "total_wool": 66,
		"achievements": ["first_harvest"], "cut_trees": [[3, 4]],
	}
	var wrote: bool = _save.write_slot(TEST_SLOT, JSON.stringify(payload))
	var parsed: Variant = JSON.parse_string(_save.read_slot(TEST_SLOT))
	_check(wrote and typeof(parsed) == TYPE_DICTIONARY and _equiv(payload, parsed),
		"3 v2 载荷 → JSON.stringify → 写盘 → 读盘 → parse 全字段一致")
	var summary: Dictionary = _save.slot_summary(TEST_SLOT)
	_check(int(summary.get("v", -1)) == 2, "3 slot_summary() 读出 v = 2")

	# v1 旧档（无 v）同样完整，且不会凭空多出 v
	var legacy: Dictionary = payload.duplicate(true)
	legacy.erase("v")
	_save.write_slot(TEST_SLOT, JSON.stringify(legacy))
	var back: Dictionary = _save.slot_summary(TEST_SLOT)
	_check(not back.has("v"), "4 v1 旧档读入后无 v 字段（缺省视为 v1）")
	var fields := ["day", "gold", "hero_id", "tiles", "sprinklers", "sprinklers2",
		"scarecrows", "machines", "chicken_count", "eggs_ready", "total_eggs",
		"cow_count", "sheep_count", "milk_ready", "wool_ready",
		"total_milk", "total_wool", "achievements", "cut_trees"]
	var intact := true
	for k in fields:
		if not _equiv(legacy[k], back.get(k)):
			intact = false
			printerr("    v1 字段丢失/变化: ", k)
	_check(intact, "4 v1 旧档金币/天数/农田/养殖/机器字段完整")


func _restore_slot() -> void:
	if _slot_backup.strip_edges() == "":
		_save.erase_slot(TEST_SLOT)
	else:
		_save.write_slot(TEST_SLOT, _slot_backup)
	_check(_save.read_slot(TEST_SLOT) == _slot_backup,
		"3/4 测试用的 5 号槽已还原，不污染用户存档")


# ---------- 5. 时间流速与跨日（源码常量求值 + 规格公式 + 防漂移） ----------
func _t_time_flow() -> void:
	var start: Variant = _const_expr(_src_main, "DAY_START_MIN")
	var finish: Variant = _const_expr(_src_main, "DAY_END_MIN")
	var rate: Variant = _const_expr(_src_main, "MINUTES_PER_SECOND")
	_check(start != null and finish != null and rate != null
			and float(start) == 360.0 and float(finish) == 1440.0 and float(rate) == 6.0,
		"5 从 main.gd 源码求值常量 6:00 / 24:00 / 6 分钟每秒")
	if start == null or finish == null or rate == null:
		return
	# 规格公式：time_min += delta * MINUTES_PER_SECOND；到达 END 时 day+1、time 归 START
	var t: float = float(start)
	var day := 1
	var seconds := 0.0
	while t < float(finish) and seconds < 10000.0:
		t += 1.0 * float(rate)
		seconds += 1.0
	if t >= float(finish):
		day += 1
		t = float(start)
	_check(is_equal_approx(seconds, 180.0) and day == 2 and t == float(start),
		"5 现实 180 秒跨一日：day+1 且时间回到 6:00（实测 %.0f 秒）" % seconds)
	_check(_src_main.contains("time_min += delta * MINUTES_PER_SECOND")
			and _src_main.contains("Game.day += 1"),
		"5 推进与跨日公式原文未漂移")


# ---------- 6. 作物生长（真实 CROPS 数据 + 规格公式 + 防漂移） ----------
func _t_crop_growth() -> void:
	var crops: Dictionary = _game.get("CROPS")
	var capped := true
	for id in crops:
		var days := int(crops[id].days)
		var stage := 0
		for i in days + 3:  # 浇满并多浇 3 天，stage 应封顶在 days
			if stage < days:
				stage += 1
		if stage != days:
			capped = false
	_check(capped, "6 各作物浇水 days 天成熟，且 stage 封顶不超过 days")
	var days_parsnip := int(crops["parsnip"].days)
	var partial := 0
	for i in days_parsnip - 1:
		if partial < days_parsnip:
			partial += 1
	_check(partial == days_parsnip - 1 and partial < days_parsnip,
		"6 浇水不足时不提前成熟（防风草 %d/%d）" % [partial, days_parsnip])
	_check(_src_farm.contains("t.stage += 1")
			and _src_farm.contains("t.wtoday or raining"),
		"6 生长条件（已浇水或雨天）公式原文未漂移")


# ---------- 7. 作物复生（真实 CROPS.regrow + 规格公式 + 防漂移） ----------
func _t_crop_regrow() -> void:
	var crops: Dictionary = _game.get("CROPS")
	var ok := true
	var multi := 0
	for id in crops:
		var days := int(crops[id].days)
		var regrow := int(crops[id].get("regrow", 0))
		if regrow <= 0:
			continue
		multi += 1
		# 规格公式：stage = maxi(1, days - regrow)
		var stage := maxi(1, days - regrow)
		if stage < 1 or stage >= days:
			ok = false
		if id == "corn" and stage != 3:
			ok = false
		if id == "blue" and stage != 3:
			ok = false
	_check(multi >= 2 and ok, "7 多季作物收获回退 maxi(1, days - regrow)（%d 种）" % multi)
	_check(int(crops["parsnip"].get("regrow", 0)) == 0,
		"7 无 regrow 的作物收获后移除地块")
	_check(_src_farm.contains("maxi(1, int(Game.CROPS[id].days) - regrow)")
			and _src_farm.contains("tiles.erase(c)"),
		"7 复生/移除公式原文未漂移")


# ---------- 8. MACHINE_INPUTS 转换（真实数据表 + 规格公式 + 防漂移） ----------
func _t_machine_inputs() -> void:
	var table: Dictionary = _game.get("MACHINE_INPUTS")
	var products: Dictionary = _game.get("PRODUCTS")
	var materials: Dictionary = _game.get("MATERIALS")
	var n := 0
	var ok := true
	for typ in table:
		for input in table[typ]:
			var product: String = String(table[typ][input])
			# 规格公式：m.ready = table[m.type][m.input]; m.input = ""
			if product == "" or String(input) == "":
				ok = false
			if not products.has(product) and not materials.has(product):
				ok = false
				printerr("    未知产出: ", product)
			n += 1
	_check(n >= 6 and ok, "8 MACHINE_INPUTS 全部 %d 条转换均有合法产出" % n)
	_check(not table.has("stove"), "8 灶台不参与隔夜转换")
	_check(_src_farm.contains("Game.MACHINE_INPUTS.has(m.type)")
			and _src_farm.contains("m.ready = want[m.input]"),
		"8 机器转换公式原文未漂移")


# ---------- 辅助 ----------
## 从产品源码里取 `const NAME := <表达式>` 并求值，避免测试里硬编码常量
func _const_expr(src: String, name: String) -> Variant:
	var re := RegEx.new()
	re.compile("const " + name + " := ([^\\n#]+)")
	var m := re.search(src)
	if m == null:
		return null
	var ex := Expression.new()
	if ex.parse(m.get_string(1).strip_edges()) != OK:
		return null
	return ex.execute([], null, false)


## 数值语义相等：JSON 往返会把 int 变 float，-10 / -10.0 视为相同
func _equiv(x: Variant, y: Variant) -> bool:
	if typeof(x) == TYPE_ARRAY and typeof(y) == TYPE_ARRAY:
		if x.size() != y.size():
			return false
		for i in x.size():
			if not _equiv(x[i], y[i]):
				return false
		return true
	if typeof(x) == TYPE_DICTIONARY and typeof(y) == TYPE_DICTIONARY:
		if x.size() != y.size():
			return false
		for k in x:
			if not y.has(k) or not _equiv(x[k], y[k]):
				return false
		return true
	var xn := typeof(x) == TYPE_INT or typeof(x) == TYPE_FLOAT
	var yn := typeof(y) == TYPE_INT or typeof(y) == TYPE_FLOAT
	if xn and yn:
		return is_equal_approx(float(x), float(y))
	return typeof(x) == typeof(y) and x == y
