# plan.md — 执行表

| 项 | 值 |
| --- | --- |
| 契约 | `spec.md` **v0.1.1**（已批准 2026-11-05；基线刷新，SHALL/AC/INV 未变） |
| 红线 | `AGENTS.md`（R5 基线已同步） |
| 基线 | `dcd502d`（2026-11-05，与 `origin/main` 一致） |
| 当前闸门 | **T2.1 进行中（已放行；拆分范围/提交检查点待人类裁决）；其余阻塞** |

> 基线注记：`spec.md` §2 与 `AGENTS.md` R5 已按人类授权于 2026-11-05 刷新至 `dcd502d`；`docs/AS-IS-baseline.md` 仍为 v0.1 制定时旧快照（无契约效力），本次未改。

## 1. 状态机

```
阻塞 ──(人类放行)──> 已放行 ──(代理开始)──> 进行中 ──(提交证据)──> 待验收
                                                                    │
                          ┌──(AC 未通过，修复后重验)───────────────────┤
                          └──────────────────(AC 全通过)──> 已验收 ──> 放行下一任务
```

- 状态只允许按上流转；「已验收」不可回退，需变更时新开契约版本。
- **同一时刻至多一个「进行中」**（`AGENTS.md` R0）。
- 验收未通过按 `AGENTS.md` R0 第 4 条回到「已放行」，不得推进后续任务。

## 2. 任务表

| ID | 契约 | 动作 | 涉及文件 | 验收 | 依赖 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| T0.0 | — | 批准 `spec.md` v0.1（人类） | `spec.md` | 状态改为「已批准」，或给出修订意见 | — | 已验收 |
| T0.1 | C1 | `.gitignore` 增补 + 342 个未跟踪文件归类清单 | `.gitignore` | C1-AC1、AC2 | T0.0 | 已验收（补记） |
| T0.2 | C1 | 当前大版本完整提交（**需 R2 额外授权**） | 全仓库 | C1-AC3 | T0.1 | 已验收（AC3 偏差已接受） |
| T0.3 | C1 | 新增根 `README.md`（运行/导出/联机/部署） | `README.md` | C1-AC4 | T0.2 | **已验收（2026-11-05）** |
| T1.1 | C2 | 修 `aoe_toggle` 键位冲突 + 键位常量 + 文案漂移 | `project.godot`, `scripts/main.gd`, `scenes/main.tscn`, `scripts/touch_controls.gd` | C2-AC1~3 | T0.3 | **已验收（2026-11-05）** |
| T1.2 | C3 | 存档载荷加 `v: 2` 与迁移分派 | `scripts/main.gd`, `scripts/save.gd` | C3-AC1~3 | T0.3 | **已验收（2026-11-05）** |
| T1.3 | C4 | 建 `tests/run.gd` 与首批 6 条断言 | `tests/run.gd`, `README.md` | C4-AC1~3 | T1.2 | **已验收（2026-11-06，人类认可覆盖口径）** |
| T2.1 | C5-① | 抽出 UI 面板控制器 | `scripts/main.gd` → `scripts/ui/` | C5-AC2~4 | T1.3 | **进行中（待范围/提交裁决，见记录 #13）** |
| T2.2 | C5-② | 抽出钓鱼状态机，处理 `3: pass` | `scripts/main.gd` → `scripts/fishing.gd` | C5-AC2~4 | T2.1 | 阻塞 |
| T2.3 | C5-③ | 抽出商店 / 制作建造 | `scripts/main.gd` → `scripts/shop.gd`, `scripts/craft.gd` | C5-AC2~4 | T2.2 | 阻塞 |
| T2.4 | C5-④ | 抽出联机同步与能力表 | `scripts/main.gd` → `scripts/net_sync.gd` | C5-AC2~4 | T2.3 | 阻塞 |
| T2.5 | C5-⑤ | 抽出昼夜 / 季节推进 | `scripts/main.gd` → `scripts/day_cycle.gd` | C5-AC1~4 | T2.4 | 阻塞 |
| T3.1 | C6 | 联机受限能力对齐 + 结论入 `README.md` | `scripts/net_sync.gd`, `README.md` | C6-AC1~3 | T2.4 | 阻塞 |
| T3.2 | C1/INV-5 | 导出前检查（Godot 版本 / 字体子集 / `wasm.gz` 时效） | `tools/` | `build/web/` 一次成功导出 | T2.5 | 阻塞 |

> T0.2 与 T3.2 分别涉及 `git commit` 与导出动作，除常规放行外还需按 `AGENTS.md` R2 明确授权。

## 3. 放行记录（由人类填写 / 代理补记证据）

| # | 任务 | 日期 | 放行结论 | 验收证据 | 备注 |
| --- | --- | --- | --- | --- | --- |
| 1 | T0.0 | 2026-11-05 | 批准 | 用户「sdd写的可以，开始执行」→ 契约 v0.1 生效 | — |
| 2 | T0.1 | 2026-11-05 | 批准（补记） | **C1-AC1 通过**：`git status --porcelain` 为空，无 `?? tools/shot*` 条目；`.gitignore:17-19` 含 `tools/shot*.png*` / `tools/shot*.wav*`。**AC2 通过**：344 个未跟踪文件归类为 180 个 shot 调试产物（忽略）、新素材 / 16 个 `.gd`+`.uid` / SDD 文档 / 中继配置（纳入），结果见提交 `dcd502d` | 任务在上一轮「先提交」时已完成，补记 |
| 3 | T0.2 | 2026-11-05 | 批准（补记，带偏差） | **C1-AC3 部分达成**：`dcd502d` 已推送、`git diff HEAD --stat` 为空、commit body 列出 10 个文件；但提交描述未含「玩法能力清单」——该能力清单实际已在远端 30 个提交中，本次提交本质是补齐缺件 + 对齐历史。已推送提交不 amend | 用户按 R2 显式授权。**AC3 偏差经人类 2026-11-05 明确「接受」** |
| 4 | T0.3 | 2026-11-05 | 批准；**已验收** | 已创建 `README.md`（9 节）。**静态验证**：21/21 引用路径存在；5/5 参数与代码一致；node 24.19.0 / npm 11.17.0 / Python 3.14.1 可用。**中继**：`node server.js` 进程存活、8765 可连。**补跑见记录 #6**：桌面与 Web 双端实际启动并截图，中文无乱码，标题页显示「共 6 个存档位」 | 2026-11-05 人类确认「验收通过」 |
| 5 | 裁决 | 2026-11-05 | 人类裁决 | 「3 刷新、2 接受、1 询问含义」→ 基线刷新与偏差接受已执行；裁决 1 经解释后用户选择「补跑」并提供 Godot 路径 | 非任务，仅记录裁决 |
| 6 | T0.3 补跑 | 2026-11-05 | 补跑完成 | 见下方「补跑证据」 | 未改动任何登记文件，仅执行验证 |
| 7 | T0.3 / T1.1 | 2026-11-05 | 人类确认 + 放行 | 用户「验收通过，放行 T1.1」→ T0.3 转「已验收」，T1.1 进入执行 | — |
| 8 | T1.1 | 2026-11-05 | 执行完成，待验收 | 见下方「T1.1 验收证据」 | 只改 4 个登记文件，未提交 |
| 9 | T1.1 / T1.2 | 2026-11-05 | 人类裁决：**T1.1 验收通过，放行 T1.2** | T1.1 的 AC1/AC3 通过、AC2 经 2026-11-05 补验通过（PostMessage+PrintWindow 画面级 G 键、真实主场景 `_unhandled_input` 的 X 键实证）；T1.2 由「阻塞」转「进行中」 | 按 R0 逐任务放行，不预做 T1.3 |
| 10 | T1.2 | 2026-11-05 | 执行完成，待验收 | 见下方「T1.2 验收证据」：AC1/AC2/AC3、INV-2、冒烟 3 全通过 | 只改 1 个登记文件 `scripts/main.gd`；探针与临时槽均已还原；未提交 |
| 11 | T1.2 / T1.3 | 2026-11-05 | 人类裁决：**T1.2 验收通过，放行 T1.3** | T1.2 转「已验收」；T1.3 由「阻塞」转「进行中」 | 按 R0 逐任务放行 |
| 12 | T1.3 | 2026-11-05 | 执行完成，待验收 | 见下方「T1.3 验收证据」：AC1/AC2/AC3 字面通过；SHALL 覆盖口径偏差已标注，待人类裁决 | 只改 2 个登记文件 `tests/run.gd`（新建）、`README.md`；未提交 |
| 13 | T1.3 / T2.1 | 2026-11-06 | 人类裁决：**认可 C4 覆盖口径，T1.3 验收通过，放行 T2.1** | T1.3 转「已验收」；T2.1 转「进行中」。代理完成前置探索后按 R4 停下，待裁决拆分范围与提交检查点，见「T2.1 前置探索」 | 尚未改动任何游戏代码 |

### 补跑证据（记录 #6）

用户提供 `C:\Users\19275\AppData\Local\Temp\godot_web\Godot_v4.7.2-stable_win64.exe`（`--version` = `4.7.2.stable.official.ed1daf0bf`）。

| 项 | 结果 |
| --- | --- |
| 冒烟 1 · headless | `godot --headless --path . --quit-after 60` → `exit 0`，主场景跑满 60 帧，**无 `SCRIPT ERROR` / `Parse Error`**；退出时有 `1 resources still in use` 与 `2 ObjectDB instances leaked`（强制退出的资源清理警告，非脚本错误） |
| 冒烟 1 · 桌面画面 | Godot 窗口模式启动并截屏：标题页「像素农场」、中文正常、明确显示**「已有 1 个世界存档（共 6 个存档位）」** |
| 冒烟 6 · 静态服务 | `python -m http.server 8000 --directory build/web`；`index.html` / `index.js` / `index.wasm.gz`(10,074,706 B) / `index.pck` 均 HTTP 200 |
| 冒烟 6 · Web 画面 | 本机 Edge headless 打开 `http://127.0.0.1:8000/`：加载页进度 100%、中文正常；加大虚拟时间后**进入游戏画面**（标题页、HUD、10 格物品栏、中文无乱码）→ 实证 `wasm.gz` 流式解压链路生效 |
| 顺带发现 | 两张截图均显示左上角仍为「1-4 切换工具」，实证 D2 文案漂移 |
| 清理 | 8000 / 8765 端口无残留监听，无残留 Godot 进程，Edge 临时 profile 已删除 |
| 截图证据（系统 TEMP，未入仓库） | `%TEMP%\stardew_web_smoke.png`、`%TEMP%\stardew_web_smoke2.png`、`%TEMP%\stardew_desktop_smoke.png` |

**按 R3 如实标注未验证的细化子项**（属 §4 冒烟清单，非 C1-AC4 措辞范围）：冒烟 1 的「可选主角」未展开；冒烟 6 的「刷新后 localStorage 存档保留」未做交互式存档→刷新→读档；冒烟 7 的「双开同步」未做。

### T1.1 验收证据（记录 #8）

改动：`project.godot` `aoe_toggle` 71(G) → 88(X)；`main.tscn` 提示「1-4」→「1-0」；`main.gd:2` 注释「八种工具/种子x4」→「十种工具/种子x6」，帮助面板改由 `_key_cap()` 从 `InputMap` 取键帽，`touch_controls.gd` 抽出 `ACTION_LABELS` / `MENU_ORDER` 供触屏菜单与帮助面板共用。合计 **4 个登记文件，+37/−14**，未新建文件、未改玩法数值、未提交。

| AC | 结果 |
| --- | --- |
| **AC1** | **通过**：PowerShell 解析 `project.godot` 全部 39 个 `physical_keycode`，**无重复**；88 归 `aoe_toggle`、71 归 `codex` |
| **AC2 · 按键映射** | **通过**：Godot 4.7.2 探针实证 `X → aoe_toggle=true / codex=false`、`G → aoe_toggle=false / codex=true`；`main.gd` 的 `codex`（约 571 行）与 `aoe_toggle`（约 615 行）分支均未改动，同一 `elif` 链不再争抢同一按键 |
| **AC2 · 触屏** | **通过（静态）**：`MENU_ORDER` 仍含 `aoe_toggle` / `codex`，`_fire_tap(act)` 仍按 action 名派发，动作名未变 |
| **AC2 · 画面级（补验后）** | **通过**。① 通道修正：此环境游戏窗口被 explorer 全屏窗口遮挡，屏幕坐标点击与 `SendKeys` 全部打到别的窗口；改用 `PostMessage` 直接投递 + `PrintWindow(PW_RENDERFULLCONTENT)` 截取被遮挡内容。② 进入游戏链：点击「开始游戏（选择世界）」平均亮度 96.9→61.8（−35.1，切到世界选择暗遮罩）；再点「进入」上半区 75.9→124.7、下半区 45.3→102.3（进入农场）。③ **G 键画面级实证**：整体 116.1→92.2（−23.9，图鉴暗遮罩打开）。④ **X 键功能实证**：首次按 X 画面 diff 仅 0.02%，根因查明为读档后 `main.gd:450` 自动 `_toggle_help(true)` 且图鉴未关，`_panels_blocking()`（`main.gd:1728-1732`，含 `help_open`/`dex_open`）返回 true 挡住 `aoe_toggle` 分支——属既有面板阻挡逻辑，与键位绑定无关。改用临时 autoload 探针在真实主场景 `Main` 上调用真实 `_unhandled_input`：`X: _aoe_all false→true→false`、`G: dex_open→true→false`、`H: help_open→true`、`_key_cap`=`X`/`G`。⑤ **如实标注**：toast 未能单独成像——连按 G/X 后全图 diff 17.97%、底部 20.38%，昼夜/云/角色动画噪声远大于一行 toast，无法把 toast 从背景动画中分离，故不宣称「已看到 toast」 |
| **AC3** | **通过**：`main.tscn` 与 `main.gd` 均为「1-0」；帮助面板键帽由 InputMap 生成，探针实证 `keycap88=X`、`keycap71=G`；共用常量 `ACTION_LABELS` 被触屏菜单与帮助面板同时引用（探针读出「范围切换」「图鉴」）；「按 G 切换全田」等旧文案已清除 |
| **运行验证** | `godot --headless --path . --quit-after 60` → `exit 0`，无 `SCRIPT ERROR` / `Parse Error`；`read_lints` 0 诊断 |
| **探针环境说明** | 早期 `--script` 探针不加载 Autoload，`load("res://scripts/touch_controls.gd")` 报 `Identifier not found: Save` 编译错误（常量仍读出）。补验改为**临时 autoload 探针**（`project.godot` 加 `ProbeT11`，`_ready` 内等主场景就绪后调用真实 `_unhandled_input`），拿到确定性真值；跑完已还原 `project.godot`、删除 `scripts/_probe_t11.gd`，`git diff project.godot` 仅剩 `71→88` 一处，无残留 Godot 进程 |
| **截图证据** | `%TEMP%\stardew_t11b_*.png`（四张相同，记录标题页吞输入这一事实）；`%TEMP%\stardew_win_before.png` / `_win_after.png`（开局→世界选择）；`%TEMP%\t11_final_A.png` / `t11_final_X.png`（进入农场后 / 按 X 后） |

### T1.2 验收证据（记录 #10）

改动：**仅 `scripts/main.gd` 一个登记文件**（T1.2 部分约 +28 行）。`main.gd:1333-1334` 新增 `SAVE_VERSION := 2` / `SAVE_VERSION_V1 := 1`；`main.gd:1361` 载荷写入 `"v": SAVE_VERSION`；`main.gd:1402-1419` 新增 `_migrate_payload()` 按 `v` 分派（缺省视为 v1 → `_migrate_v1_to_v2()` 仅补版本标记、数据字段零改写；未知版本 `push_warning` 后按现有默认值逻辑尽力读取）；`main.gd:1422` 在应用载荷前调用分派。`scripts/save.gd` **未改动**（`git diff -- scripts/save.gd` 为空），符合 SHALL「Save 层保持不理解字段」——现有 `slot_summary()` 返回全量解析字典，`v` 自然可读。存储键 `stardew_save_v1` 与 6 槽结构未动。

| AC | 结果 |
| --- | --- |
| **AC1** | **通过**：构造不含 `v` 的完整 v1 载荷（gold=12345、day=31、chicken=3、eggs_ready=4、cow=2、sheep=1、milk/wool 各 1，含 tiles / sprinklers / sprinklers2 / scarecrows / machines），经真实 `_apply_payload()` 读入后游戏状态为 `gold=12345 day=31 chicken=3 cow=2 sheep=1 eggs=4`，16 个金币 / 天数 / 农田 / 养殖字段数值语义全等；迁移后 `migrated_v=2` |
| **AC2** | **通过**：`_save_payload()["v"]=2`；真实 `Save.slot_summary(5)["v"]=2`（Godot `JSON.parse_string` 数字为 float，实测 `2.0`，数值等于 2） |
| **AC3** | **通过**：载荷 1 → `JSON.stringify` → `JSON.parse_string` → `_apply_payload()` → 载荷 2，**63 个键除 `saved_at` 外完全一致**，两次 `v=2` |
| **INV-2** | **通过**：脚本比对 `git show HEAD:scripts/main.gd` 与工作区的 `_save_payload()` 键集合：63 → 64，**只新增 `v`，无删除**；不带 `v` 的旧档完整读入（AC1） |
| **冒烟 3** | **通过**：临时槽 F5 存档（saved_gold=0）→ 改金币为 7777 → `_do_load(false)` 读回 0，`restored=true`，存档含 `v=2`；旧单档迁 0 号槽逻辑未改 |
| **运行验证** | 干净 headless `--quit-after 120` → `exit 0`，无 `SCRIPT ERROR` / `Parse Error`；`read_lints` 0 诊断 |
| **探针与清理** | 临时 autoload 探针（同 T1.1 手法）跑完已删，`project.godot` 从备份还原且无 `ProbeT12`；测试用的 5 号槽内容与 `Save.current` 原样恢复（探针输出 `slot_restored=true / current_restored=true`）；无残留 Godot 进程 |
| **首轮如实记录** | 首轮探针输出 `AC1 MISMATCH tiles before=-10.0 after=-10`（JSON 往返 int/float 表示差异，数值相同）与 `SMOKE3 restored=false`（探针把 AC1 改写后的 12345 当期望值，而写入的是原始载荷 gold=0）。两处均为**探针测量方法缺陷**，非产品代码问题；修正测量方法（数值语义递归比较 + 期望值取实际写入值）后重跑全通过。严格 JSON 文本比较的 `strict_json_text_match=false` 仍保留在输出中，未隐藏 |
| **退出期提示** | headless 退出时有 `ERROR: 1 resources still in use at exit (run with --verbose for details)`，为 T0.3 补跑时即已记录的既有现象，非本次引入 |

### T1.3 验收证据（记录 #12）

改动：**只改 2 个登记文件**——新建 `tests/run.gd`，`README.md` 三处（第 1 节「命令行自测」含命令与退出码判定、第 8 节目录结构补 `tests/`、第 9 节删除过时的「回归网尚未建立」）。未改任何游戏代码、未提交。

**先探明的硬约束**（`--script` 模式实测，非推测）：

| 实验 | 输出 |
| --- | --- |
| `Engine.has_singleton("Game")` | `false` |
| `ProjectSettings.get_setting("autoload/Game")` | `*res://scripts/game.gd`（配置在、单例未注册） |
| `load("res://scripts/game.gd").new()` | 成功，`season_index()` 可调 |
| `load("res://scripts/save.gd")` | 成功 |
| `load("res://scripts/main.gd")` | `Compile Error: Identifier not found: Save` |
| `load("res://scripts/farm.gd")` | `Compile Error: Identifier not found: Game` |
| 手动 `Engine.register_singleton("Game", …)` 后重载 | `has_singleton=true`，但 `farm.gd` **仍**报 `Identifier not found: Game`（GDScript 全局标识符表不走 Engine 单例表） |

故 `main.gd` 的 `_do_sleep()`、`farm.gd` 的 `on_new_day()` / `try_harvest()` 在该命令下不可调用。

| AC | 结果 |
| --- | --- |
| **AC1** | **字面通过**：原样相对路径命令 `godot --headless --path . --script tests/run.gd` → `RESULT cases=7 pass=24 fail=0`、`exit 0`；7 组 ≥6，覆盖契约 6 类纯逻辑。另用「注入一条故意失败断言」的临时副本验证失败路径 → `RESULT cases=7 pass=24 fail=1`、`exit 1`（非零），机制为 `quit(1 if _fail > 0 else 0)` |
| **AC2** | **通过**：静态扫描 `tests/run.gd` 无 `build/`、`http`、`JavaScriptBridge`、`OS.shell`、`EditorInterface` 引用（唯一 `build/` 命中是文件头注释）。依赖仅 `FileAccess` / `InputMap` / `JSON` / `RegEx` / `Expression` / `res://scripts/{game,save}.gd` |
| **AC3** | **通过**：`README.md:35` 记录原样命令、`godot` 不在 PATH 时的绝对路径写法、`RESULT` 与退出码判定；`README.md:136` 目录结构补 `tests/` |
| **冒烟 3 / 4** | 测试内覆盖「v2/v1 存档载荷往返 + `slot_summary()` 读出 v」与「39 个 keycode 无重复、X=88 / G=71」；测试结束还原 5 号槽（断言 PASS）。真实 F5/F9 于 T1.2 已验 |
| **运行验证** | 主场景 `--headless --quit-after 120` → `exit 0` 无脚本/解析错误；`read_lints` 0 诊断 |

**⚠ SHALL 覆盖口径偏差（待裁决，不自行判为完全通过）**：7 组中 4 组**直连产品代码**（`game.gd` 实例的季节推导、`project.godot` + `InputMap`、`save.gd` 真实文件 IO、`game.gd` 数据表）；另 3 组（时间流速与跨日、作物生长、作物复生）因上述约束，采用「从 `main.gd` 源码用 `Expression` **动态求值常量**（不硬编码）+ 规格公式复刻 + 对 `farm.gd` / `main.gd` 公式原文做静态防漂移断言」。产品改常量或改公式时测试会变红，但**不是直接调用** `_do_sleep()` / `on_new_day()` / `try_harvest()`。此口径是否算满足 C4 SHALL「覆盖纯逻辑」请人类裁决；若要求直连，需改用 T1.1/T1.2 的临时 autoload 探针路线，但那会超出「`--script` 一条命令」的 AC1 约束，须先修订契约。

**清理**：所有临时探针写在 `%TEMP%`，已删除；`tests/run.gd` 在 `_init()` 任何用例之前备份 5 号槽、退出前还原；无残留 Godot 进程。

### T2.1 前置探索与待裁决事项（记录 #13）

**尚未改动任何游戏代码**。只读探索结论（行号以 `scripts/main.gd` 当前版本为准）：

| 事实 | 数据 |
| --- | --- |
| `main.gd` 实际行数 | **7060 行**（契约/基线里「6233 行」是旧快照） |
| 面板状态变量 | 约 60 个，与玩法状态混在 139-382 行同一 `var` 区，无法整段剪切 |
| `_toggle_*` / `_build_*` / `_refresh_*` / 样式与卡片函数 | 纯 UI 函数粒度合计 **约 2835 行**，分布在 38 个不连续区间 |
| 预置 UI 面板 | 仅 `$UI/ShopPanel` 一个，其余 19 个面板均运行时 `new()` 创建 |
| 现成组合范式 | `scripts/touch_controls.gd`（`extends Control` + `var main`），但它**直接读 main 的 16 个 `*_open` 状态变量**（`touch_controls.gd:216-223`），故状态变量必须留在 main |

**三处需人类裁决的冲突（按 R4 不自行解释、不扩大范围）**：

1. **无提交检查点，回滚风险高**：C5 SHALL 要求「每步独立提交」，但 `AGENTS.md` R2 明确「只有人类明确要求时才执行 `git commit`」，且红线优先于 `spec.md`。当前 T1.1~T1.3 全部成果**均未提交**（6 个 `M` + 2 个 `??`）。在没有已提交检查点的状态下做约 2835 行机械改写（对 main 成员的裸引用要加 `main.` 前缀、`$UI` 改 `main.get_node("UI")`、main 内约 200 处调用点改 `panels.xxx()`），一旦出错无法用 git 回滚。
2. **C5-AC2 的验收方法不可行**：AC2 写「每步前后 `_save_payload()` 输出字段集合完全相同（**用 C4 用例比对**）」，但人类刚认可的 C4 口径下 `tests/run.gd` 跑在 `--script` 模式、**无法加载 `main.gd`**，不存在能比对 `_save_payload()` 的 C4 用例。T1.2 实际用的是 PowerShell 静态解析键集合（63→64）＋临时 autoload 探针。需确认改用等效方法是否算满足 AC2。
3. **拆分范围未界定**：`docs/AS-IS-baseline.md:257` 只写「`ui/panels.gd`：面板开关与 UI 构造」，但 `_build_shop` / `_upgrade` / `_bag_sell` / `_settings_back_title` 等块内混有玩法写入（改 `Game.gold`、`_autosave()`、`paused`），而 C5 第 ③ 步才是「商店/制作建造」。若 T2.1 一次抽完约 2835 行，会与第 ③ 步范围重叠并触碰 INV-1；若只抽低耦合子集，`main.gd` 约剩 6800 行，是否算完成 C5-① 需明确。

**代理建议（待裁决）**：

- **A（推荐）**：按 R2 显式授权一次 `git commit`，把 T1.1~T1.3 成果固化为检查点；T2.1 按「低耦合先行」抽出 `scripts/ui/panels.gd`（UI 工厂 / 样式 / 键帽 / 存档选择页等内聚块），剩余面板登记为新增任务 T2.1b，避免与 C5-③ 抢范围。
- **B**：授权提交，并确认 T2.1 一次抽完全部约 2835 行面板函数（工作量与回归风险最高，需额外授权做画面级冒烟）。
- **C**：不提交，直接按 A 的低耦合范围做，报告中标明「无检查点，回滚只能靠手工」。

C5-AC1「`main.gd` ≤ 3000 行」是 5 步阶段终点（`docs/AS-IS-baseline.md:264`），本步不以此判定。

记录格式：`# | 任务ID | YYYY-MM-DD | 批准/驳回 | AC逐条结果 + 命令输出或路径:行号 | 备注`

## 4. 冒烟清单（每个任务按相关性执行）

| # | 场景 | 期望 |
| --- | --- | --- |
| 1 | 桌面启动 | 标题页可见 6 个存档槽，可选世界与主角 |
| 2 | 一天循环 | 开垦→播种→浇水→睡觉：跨日、作物生长、季节按 14 天推进、雨天免水 |
| 3 | 存读档 | F5 → 改金币 → F9 完全还原；旧单档自动迁到 0 号槽 |
| 4 | 键位 | G 图鉴 / X 范围切换 / 1-0 十槽工具各自正确 |
| 5 | 钓鱼与矿洞 | 各完成一次，状态机不卡死，镐等级限制层数生效 |
| 6 | Web | `build/web/` 静态服务：中文不乱码、`wasm.gz` 生效、刷新后 localStorage 存档保留 |
| 7 | 联机 | `npm start` 后双开建房/加码：农田与昼夜同步、断线心跳清理、guest 提示一致 |

> 第 4 项的 `X` 键自 T1.1 起为配置现状（88 归 `aoe_toggle`、71 归 `codex`）；G 键画面级已实测，X 键功能经真实主场景 `_unhandled_input` 实证（见「T1.1 验收证据」）。
>
> `AGENTS.md` R3「`godot` 不在 PATH」字面仍成立，但用户已提供 4.7.2 绝对路径，涉及 Godot 的验收可据此执行；红线文本本次未改。

## 5. 每步固定动作（代理执行清单）

1. 复述任务 ID、对应 AC、允许改动的文件列表。
2. 只改登记文件，不动其它文件（`plan.md` 状态维护属流程动作，不计入任务改动）。
3. 逐条执行 AC 与相关冒烟项，记录原始结果（含失败）。
4. `git status --short` 汇报本任务造成的变化。
5. **停下**，等待人类结论；不预做下一任务。

## 6. 当前状态

```
契约 spec.md      = v0.1.1（已批准，基线已刷新，SHALL/AC/INV 未变）
红线 AGENTS.md    = R5 基线已同步
基线              = dcd502d（35 次提交，与 origin/main 一致）
T0.0 ~ T0.3       = 已验收
T1.1 ~ T1.2       = 已验收（2026-11-05）
T1.3              = 已验收（2026-11-06，覆盖口径经人类认可）
T2.1              = 进行中（待范围/提交裁决，未改游戏代码）
其余全部           = 阻塞
进行中任务         = T2.1
未提交改动         = README.md、tests/run.gd（T1.3 新增）、SDD/plan.md、SDD/spec.md、SDD/AGENTS.md、
                    project.godot、scenes/main.tscn、scripts/main.gd、scripts/touch_controls.gd
```

**当前等待**：T2.1 前置探索发现的三处冲突裁决（见「T2.1 前置探索与待裁决事项」）：是否按 R2 授权提交检查点、C5-AC2 验收方法是否允许等效替代、T2.1 拆分范围取 A/B/C 哪个方案。裁决前不改游戏代码。
