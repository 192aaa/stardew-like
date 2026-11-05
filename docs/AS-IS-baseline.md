# 星露谷Like — AS-IS 现状基线调研（参考资料）

> **本文不是契约，不具放行效力。** 规格驱动体系的唯一契约是 `../spec.md`，红线是 `../AGENTS.md`，执行表是 `../plan.md`。本文仅保存从代码读得的现状事实、架构说明与数据表，供编写契约时查证；与契约冲突时一律以 `../spec.md` 为准。
>
> 本文产自一次理解偏差：最初按 Software Design Document 写成，后改用规格驱动（Spec-Driven Development）三件套，故降级为参考资料并重命名。

| 项 | 值 |
| --- | --- |
| 文档类型 | 现状调研 / 系统设计说明（参考资料） |
| 快照日期 | 2026-11-05 |
| 代码基线 | `3899548` (2026-10-27，`内置 Fusion Pixel 中文字体，修复 Web 导出中文乱码`) + 其后的**未提交工作区变更** |
| 适用范围 | `StardewLike/` 仓库全部内容；不含工作区顶层的 `*.msi` / `*.log` 等无关文件 |
| 事实来源 | 全部数值与行为描述均从当前工作区代码/配置读取，非设计愿景；引用格式 `文件:行号` |

> 说明：项目已是可运行成品，因此**不是从零设计**。第 4 章记录现状规格，第 5 章登记差距，第 6–7 章的改造建议已被 `../spec.md` / `../plan.md` 取代，仅作背景保留，不得据此执行任务。

---

## 1. 现状摘要（AS-IS Snapshot）

一句话：一个用 Godot 4.7 + GDScript 编写、可导出桌面与 Web 的像素风农场模拟游戏，功能闭环完整，配套程序化素材生成、Web 部署与双人联机中继，但**版本管理与代码组织明显滞后于功能演进**。

### 1.1 规模

| 指标 | 值 |
| --- | --- |
| GDScript 脚本 | 22 个，合计约 9847 行 |
| `main.gd` | 6233 行 / 235.7 KB / 270 个函数（占全部脚本约 63% 行数） |
| 其余体量较大者 | `decor.gd` 33.5 KB、`game.gd` 20.8 KB、`mine_world.gd` 14.6 KB、`touch_controls.gd` 13 KB、`farm.gd` 12.5 KB、`world_chunks.gd` 10 KB |
| 场景 | 2 个：`scenes/main.tscn`、`scenes/player.tscn` |
| Autoload 单例 | 5 个：`Game` / `Sfx` / `Save` / `Music` / `Net` |
| 着色器 | 1 个：`shaders/sunlight.gdshader` |
| 素材 | 程序化生成的 PNG/WAV/TTF（约 86 张 PNG + 12 个 WAV + 1 个字体） |
| 辅助工具 | 4 个 Python 脚本 + 1 个 Node 中继服务 |
| Web 构建产物 | `build/web/`：`index.wasm` 37.68 MB、`index.wasm.gz` 9.61 MB、`index.pck` 1.12 MB、`index.js` 0.27 MB |
| 测试 | **0 个**测试文件 / 测试场景 |

### 1.2 版本状态（当前最高风险）

| 项 | 值 |
| --- | --- |
| 提交历史 | 3 次提交，均在 2026-10-27 |
| 已跟踪文件被修改 | 21 个（含 `project.godot`、`scenes/main.tscn`、9 个 `.gd`、素材与导出配置） |
| 已跟踪文件 diff | `+9736 / −388` 行 |
| 未跟踪文件 | 342 个（大量新素材、`tools/shot*.png` 90 张调试截图、`web_shell.html`、`subset_font.py` 等） |
| 结论 | 养殖/宠物/矿洞/联机/BGM/四季/多存档槽等后续大版本**全部只存在于本地工作区，尚未入库** |

---

## 2. 系统上下文与运行形态

```
                    ┌──────────────────────────┐
  gen_pixel_art.py ─│ assets/ (PNG/WAV/TTF)    │
  subset_font.py   ─│                          │
                    └────────────┬─────────────┘
                                 │ res://
   Godot 4.7 ────────────────────▼────────────────────────────┐
   project.godot / main.tscn / *.gd                           │
   ├─ 桌面导出 ──> 本机运行，user://saves/slot_N.json           │
   └─ Web 导出  ──> build/web/index.html (web_shell.html)      │
                     ├─ index.js + index.wasm(.gz) + index.pck  │
                     ├─ localStorage 存档                       │
                     └─ WebSocket ───────────┐                  │
                                            ▼                  │
                     tools/relay/server.js (Node + ws :8765)    │
                                                               │
   deploy_web.py ──> GitHub Git Data API ──> gh-pages           │
   commit_main.py ─> GitHub Git Data API ──> main               │
                                                               └── 游戏逻辑全部在 .gd
```

- **引擎/渲染**：Godot 4.7，`gl_compatibility`（桌面与 mobile 均同），1280×720，`canvas_items` 拉伸 + `expand`，最近邻纹理过滤（`project.godot:26-31,223-227`）。
- **中文字体**：全局主题字体 `res://assets/fonts/fusion_pixel.ttf`（`project.godot:35`），由 `tools/subset_font.py` 裁剪以压缩 pck；`main.tscn` 的 Hint 标签另有 `SystemFont` 回退（`scenes/main.tscn:17-18`）。
- **联机中继地址优先级**（`scripts/net.gd:86-96`）：环境变量 `SL_RELAY` → Web 查询参数 `?ws=` → `ws://localhost:8765`。HTTPS 页面必须用 `wss://`（`tools/relay/README.md:19-27`）。
- **本机验证前置条件**：当前环境 `godot` 不在 PATH，运行/导出需使用 Godot 4.7 编辑器；`build/web/` 已有可用产物，无需重新导出即可做 Web 冒烟。

---

## 3. 架构现状

### 3.1 场景树与渲染分层

`scenes/main.tscn` 只有静态骨架，绝大多数 UI 与动态对象由 `main.gd` 运行时创建：

| 节点 | z_index | 职责 |
| --- | --- | --- |
| `Ground` / `Patch1-4` / `Pond` / `River` | −3000 ~ −2990 | 地形贴图，用 `region_rect` 平铺（地面 5200×2800） |
| `CanvasModulate` | — | 昼夜底色 |
| `Decor` | −2900 | `decor.gd` 自绘建筑/栅栏/装饰 |
| `Farm` | −2890 | `farm.gd` 自绘地块与作物 |
| `Gather` | −2880 | `gather.gd` 自绘采集物 |
| `Player` | — | `player.tscn` 实例，Y 排序 |
| `UI` (CanvasLayer) | — | `Sunlight`(shader) / `Vignette` / `Hint` / `DayTime` / `Gold` / `Toast` / 10 格 Hotbar / `ShopPanel` / `Fade` |

渲染策略：**大量使用 `_draw()` 自绘 + 分块渲染**（`world_chunks.gd`、`mine_world.gd`），而非逐对象 Node，这是性能上的主动取舍，也是新模块接入时必须遵守的约束。

### 3.2 模块职责与状态所有权

| 层 | 文件 | 职责 |
| --- | --- | --- |
| 全局状态 | `game.gd` | 金币/天数/种子/背包/体力/技能等级/好感/成就，**所有静态数据表与常量**，信号 `state_changed` / `skill_up` / `achievement_done` |
| 持久化 | `save.gd` | 6 槽世界存档、独立设置 KV、旧档迁移；**只做字符串读写，不理解字段** |
| 音频 | `sfx.gd` / `music.gd` | 音效播放 / 昼夜 BGM 与静音状态 |
| 联机 | `net.gd` | WebSocket 客户端、房间码、消息路由；**不含同步逻辑** |
| 编排 | `main.gd` | 输入分发、昼夜天气、钓鱼、商店、制作/建造、UI 面板、存档组装与应用、联机同步、引导/目标/节日/成就 |
| 世界子系统 | `farm.gd` `gather.gd` `decor.gd` `mine.gd` `mine_world.gd` `world_chunks.gd` `rain.gd` | 各自维护领域状态并自绘 |
| 角色 | `player.gd` `villager.gd` `chicken.gd` `livestock.gd` `pet.gd` | 移动/动画/AI |
| 辅助 UI | `minimap.gd` `goal_arrow.gd` `friend_arrow.gd` `touch_controls.gd` | 小地图、指示箭头、触屏按钮 |

数据流：`Input → main.gd 的 _unhandled_input → 领域子系统 → Game 全局状态 → signal 刷新 HUD`；持久化由 `main.gd:_save_payload()/_apply_payload()` 双向翻译，联机由 `main.gd` 负责「主机权威」的状态广播。

**关键耦合**：`main.gd` 同时是输入路由、玩法编排、UI 构造、存档序列化与网络同步层，是整个架构的单点。

### 3.3 五种主动设计取舍（改造时须保留）

1. 素材全部由 `tools/gen_pixel_art.py` 程序化生成，不引入外部美术管线。
2. 世界与农田用 `_draw()` 自绘而非节点树，避免数千节点开销。
3. 存档为**单个 JSON 字符串**，存储层与业务层解耦（`Save` 不理解字段）。
4. Web 端绕过 `user://`，用 `JavaScriptBridge` 直接写 `localStorage`。
5. 联机采用**主机权威 + 中继纯转发**，服务端不保存游戏状态。

---

## 4. 功能规格（AS-IS 基线规格）

### 4.1 时间 / 季节 / 天气

| 规格 | 值 | 证据 |
| --- | --- | --- |
| 每日时间窗 | 06:00 – 24:00（`DAY_START_MIN=360`, `DAY_END_MIN=1440`） | `main.gd:5-6` |
| 时间流速 | 6 游戏分钟/现实秒 → 180 秒 = 1 游戏日 | `main.gd:7` |
| 季节 | 每季 14 天、4 季共 56 天，由 `day` 推导，**不单独存档** | `game.gd:84-92` |
| 可播种作物 | 春 `parsnip/potato/straw`；夏 `straw/corn/blue`；秋 `pumpkin/corn/blue`；冬 **禁种**（温室除外） | `game.gd:88-91`, `farm.gd:55-59` |
| 天气 | 晴/雨，雨天免浇水并影响鱼种 | `rain.gd`, `game.gd:18-27` |
| 光照 | `sunlight.gdshader` + `CanvasModulate`，warm/cool/strength 参数 | `main.tscn:20-25,74` |
| 节日 | 每 7 天一次，钓鱼大赛(3 条/300g) 与 丰收祭(5 株/400g) 交替，睡前结算 | `main.gd:46-50` |
| 引导 / 目标 | 首日五步 `["锄地","浇水","播种","收获","卖货"]`；七日目标逐日发奖 | `game.gd:119-140` |

### 4.2 农田

- 网格 `CELL = 32`，全局格坐标 → `{tilled, watered, crop, stage, wtoday}`（`farm.gd:4,30-31`）。
- 4 片可耕区 `ZONES`（`farm.gd:19-24`）；温室 `GH_RECT(1120,-600,280,200)` / 可种区 `GH_ZONE(1140,-584,240,140)`，造价 6000g + 25 木 + 15 石（`game.gd:121-123`）。
- 设施：稻草人（半径 150）、洒水器（四邻）、高级洒水器（3×3）、加工机（蛋黄酱/果酱/灶台/熔炉/奶酪机），`MACHINE_INPUTS` 定义原料→产品（`game.gd:62-69`）。
- 作物图鉴：`days` 为需浇水的生长天数；`regrow` 为收获后回退节数；`yield` 为单次产量（`game.gd:8-16`）。

| 作物 | 种子价 | 售价 | 生长天数 | 复生 | 产量 |
| --- | --- | --- | --- | --- | --- |
| 防风草 parsnip | 20 | 40 | 3 | — | 1 |
| 土豆 potato | 35 | 90 | 5 | — | 1 |
| 草莓 straw | 80 | 130 | 6 | — | 1 |
| 南瓜 pumpkin | 100 | 320 | 8 | — | 1 |
| 玉米 corn | 120 | 210 | 6 | 3 | 1 |
| 蓝莓 blue | 90 | 130 | 5 | 2 | 2 |

### 4.3 经济与升级

- 鱼类 6 种（`game.gd:20-27`）：咬钩权重 `w`；`night`(18 点后) / `dusk`(20 点后) / `rain` / `legend`(鱼王，不进订单池)。鱼王售价 1200g。
- 材料 13 种、加工品 5 种、料理 3 种（含 `energy` 回复与 `cost` 配方）、制作配方 9 种（`game.gd:29-82`）。
- 工具升级价格：锄/壶 500 → 2200(+5 铜矿) → 5000(+3 铁锭)，范围 3×3 → 5×5 → 7×7；钓竿 1800g + 5 铜矿；镐 900g + 5 铜矿 → 3000g + 3 铁锭，可下矿层 `[4, 8, 12]`（`game.gd:94-114`）；宠物 500g。
- 一键农事：`harvest_all` / `water_all` / `till_all` / `plant_all`，范围由 `_aoe_all` 在「附近 3×3 / 全部农田」间切换（`main.gd:603-619`）。

### 4.4 工具与输入映射

- 工具枚举 10 项：`HOE, CAN, SEED_PARSNIP, SEED_POTATO, SEED_STRAW, SEED_PUMP, SEED_CORN, SEED_BLUE, ROD, AXE`；槽位映射见 `TOOL_OF_SLOT`（`main.gd:9-14`）：`1/2` 锄壶、`3-6` 春夏种、`7` 鱼竿、`8` 斧镐、`9` 玉米、`0` 蓝莓。
- `project.godot:41-221` 定义 30+ action，主要按键：WASD/方向键移动、空格 `use`、Q `skill`、E `interact`、I `bag`、C `craft`、V `build`、H `help`、M `mute`、T `chat`、F/P/J/K/R 一键操作、F5/F9 存读档、Tab 小地图、B 收集包、Y 目标、G 图鉴 / 范围切换。
- 触屏：`touch_controls.gd` 把同名 action 映射为按钮（含「图鉴」与「范围切换」两个按钮，`touch_controls.gd:115-120`）。

> **已确认缺陷 D1**：`codex` 与 `aoe_toggle` 均绑定 `physical_keycode=71`（G 键），`project.godot:162-166,197-201`；而 `_unhandled_input` 中 `codex` 分支在 `main.gd:571`、`aoe_toggle` 在 `main.gd:615`，属同一条 `elif` 链 —— 键盘 G 永远先命中图鉴，**范围切换在键盘上不可达**，仅触屏按钮可用。

### 4.5 存档规格

| 规格 | 值 | 证据 |
| --- | --- | --- |
| 槽位 | `SLOT_COUNT = 6`，`Save.current` 指定当前槽，开局从设置 `last_slot` 恢复 | `save.gd:12-16`, `main.gd:388-389` |
| 存储键 | 世界 `stardew_save_v1_N`；设置 `stardew_settings_v1` | `save.gd:7-10,49-54` |
| 桌面路径 | `user://saves/slot_N.json`；Web 走 `localStorage` | `save.gd:57-89` |
| 旧档迁移 | 老单档 `user://save.json` / localStorage `stardew_save_v1` 自动搬入 0 号槽 | `save.gd:124-141` |
| 序列化 | `main.gd:_save_payload()` 组装单个 Dictionary → `JSON.stringify` | `main.gd:1332-1392,1556-1557` |
| 载荷字段分组 | 时间/角色（`day,gold,hero_id,saved_at,time_min,tool,px,py,weather,stamina,health`）、资源（`seeds,harvest,items,xp,skill_lv`）、农田（`tiles,sprinklers,sprinklers2,scarecrows,machines`，均为紧凑数组）、进度（`friends,caught_fish,chest_opened,achievements,orders,buildings,storage,total_*`）、养殖（`chicken/cow/sheep_count,*_ready,pets,pet_mood,pet_house,pets_home`）、矿洞 `rocks`、引导/温室/收集包 | `main.gd:1355-1392` |
| 反序列化 | `_apply_payload()` 逐字段 `d.get(key, default)` 容错；guest 读档时保留本地位置与工具 | `main.gd:1394-1416` |
| 触发 | 睡觉 / F5；guest 禁止存读档 | `main.gd:597-602` |
| 设置独立 | 音量/触屏/缩放等不随清档丢失 | `save.gd:5,24-32` |

> **规格缺口 S1**：载荷中**没有显式 schema version 字段**，版本仅体现在存储键 `stardew_save_v1`；兼容性完全依赖逐字段默认值。新增/重命名字段时无法做确定性迁移。

### 4.6 联机规格

- 模式 `SOLO / HOST / GUEST`，房间码 4 位，字符集去掉易混淆的 `0/O/1/I/L`（`net.gd:13`, `server.js:13-15`）。
- 协议（`tools/relay/README.md:29-33`）：客户端 `{t:"host"}` / `{t:"join",code}` / `{t:"msg",data}` / `{t:"leave"}`；服务端 `{t:"hosted",code}` / `{t:"joined",code}` / `{t:"err",msg}` / `{t:"peer_joined"}` / `{t:"peer_left"}` / `{t:"msg",data}`；15s 心跳 ping/pong，未响应即清房（`server.js:106-113`）。
- 主机权威：**guest 禁止存读档**，guest 读档仅覆盖本地位置与工具（`main.gd:1396-1400`）。
- 已知限制：guest 不可安放宠物（`main.gd:795-799`）、不可传送（`main.gd:2025-2028`）。

### 4.7 Web 导出与发布

- 预设 `Web`，排除 `tools/*,build/*`，自定义壳 `res://web_shell.html`，输出 `build/web/index.html`（`export_presets.cfg:1-35`）。
- `web_shell.html` 拦截 `index.wasm` 的 fetch，改取 `index.wasm.gz`，用 `DecompressionStream('gzip')` 流式解压（首屏 37.7 MB → 9.6 MB），不支持时回退原始 wasm；并给 `index.pck` 加 `?v=<体积>` 破缓存（`web_shell.html:198-239`）。
- `tools/deploy_web.py` 走 GitHub Git Data API 推 `gh-pages`（orphan 提交），按 blob sha 复用未变文件避免重复上传大 wasm；`tools/commit_main.py` 为 `main` 分支的备用提交通道（github.com git 端点不稳时使用）。

### 4.8 其它已实现能力

钓鱼小游戏（咬钩/绿区/命中次数状态机，`main.gd:1035-1053`）、矿洞逐层与战斗（`mine_world.gd`）、村民三档好感台词与送礼（`main.gd:52-100`）、养殖与宠物、图鉴/收集包/成就、小地图与好友/目标指示箭头、中文帮助与设置面板、触屏控制、4 位可选主角（`gen_pixel_art.py`）。

---

## 5. 差距与风险登记

严重度：**高** = 已影响功能或存在数据丢失风险；**中** = 影响可维护性/协作；**低** = 一致性打磨。

| ID | 类别 | 描述与证据 | 影响 | 严重度 |
| --- | --- | --- | --- | --- |
| R1 | 版本管理 | 21 个已跟踪文件改动（+9736/−388）+ 342 个未跟踪文件，末次提交停在 2026-10-27（§1.2） | 本地丢失即丢失整个大版本；远端与实际能力严重不符 | **高** |
| R2 | 仓库卫生 | `tools/shot*.png` 90 张调试截图及 `.import` 未跟踪，`.gitignore` 未覆盖；顶层工作区另有 252 MB `EpicGamesLauncherInstaller.msi` 等无关文件 | 提交体积膨胀、误提交二进制 | **中** |
| D1 | 功能缺陷 | G 键同时绑 `codex` 与 `aoe_toggle`，`elif` 链导致范围切换不可达（§4.4） | 键盘玩家无法使用「全部农田」模式 | **高** |
| D2 | 一致性 | 注释仍称「八种工具」（`main.gd:2`），`main.tscn:124` 提示仍是「1-4 切换工具」，实际 10 槽 | 误导玩家与后续维护者 | **低** |
| D3 | 功能缺口 | 钓鱼状态机 `3: pass` 空分支（`main.gd:1052-1053`） | 预留状态未定义，行为不明确 | **低** |
| D4 | 功能缺口 | 联机 guest 禁用宠物/传送/存读档（§4.6） | 联机与单机能力不对等，需在规格中显式标注 | **中** |
| S1 | 数据兼容 | 存档无 schema version，靠默认值容错（§4.5） | 字段语义变更时无法确定性迁移，旧档可能静默错值 | **中** |
| A1 | 架构 | `main.gd` 6233 行 / 270 函数，兼任输入、玩法、UI、存档、网络五职（§3.2） | 单点改动风险高，无法并行开发 | **中** |
| A2 | 质量保障 | 全库 0 个测试文件；无 CI | 回归只能靠手动，重构无安全网 | **中** |
| A3 | 文档 | 项目根无 README；仅 `tools/relay/README.md` | 新人无法自助运行/导出/联机 | **中** |
| A4 | 可复现性 | `godot` 不在 PATH；导出依赖本机 Godot 4.7 标准版与 `gh auth token`，未固化为脚本前置检查 | 换机后重建成本高 | **低** |

---

## 6. 目标规格（TO-BE，规格驱动）

**总原则**：不重写、不改玩法数值、不引入新引擎依赖；所有改造必须能被第 8 章的冒烟清单验证。以下每条规格都带可判定的验收标准（AC）。

### SPEC-1 工作区收敛与可复现基线

- 规格：把当前工作区变更作为一个完整版本入库；`.gitignore` 增补 `tools/shot*.png*`、字体备份目录、调试产物；顶层 `.msi`/`.log` 明确排除在项目范围外；新增根 `README.md` 说明「打开方式 / 导出 / 联机 / 部署」四条最短路径。
- AC：
  1. `git status --porcelain` 中不再出现 `?? tools/shot*.png` 与 `.import`。
  2. `git log -1` 的描述包含本次新增能力清单，且 `git diff HEAD --stat` 为空。
  3. 一个未接触过项目的人按 `README.md` 能在 10 分钟内启动游戏与本地联机中继。

### SPEC-2 输入映射单一真源

- 规格：消除 `project.godot` 中重复键位；`aoe_toggle` 改绑未占用键（如 `X`），`codex` 保留 `G`；把「键位 → 中文标签」抽成一份常量供 `touch_controls.gd` 与帮助面板共用；同步修正 `main.tscn:124` 提示为 10 槽说明，修正 `main.gd:2` 注释为「十种工具」。
- AC：
  1. `project.godot` 中任意两个 action 的 `physical_keycode` 不重复（可脚本校验）。
  2. 桌面按新键能弹出「一键范围已切换为…」提示，按 G 仍打开图鉴；触屏两个按钮行为不变。
  3. 场景提示与帮助面板的工具数量、键位与 `project.godot` 一致。

### SPEC-3 存档 schema 版本化

- 规格：`_save_payload()` 增加 `"v": 2`；`_apply_payload()` 按 `v` 分派迁移函数（缺省视为 v1，沿用现有默认值逻辑）；`Save` 层保持「不理解字段」不变；槽位摘要读取 `v` 以便 UI 提示旧档。
- AC：
  1. 现有未带 `v` 的存档仍能完整读入，金币/天数/农田/养殖字段无丢失。
  2. 新存档含 `v`，`slot_summary()` 能返回版本号。
  3. 增加一条最小回归：写入 → 读取 → 再写入，两次载荷除 `saved_at` 外一致。

### SPEC-4 `main.gd` 渐进拆分

- 规格：按现有注释块边界把 `main.gd` 拆为「领域控制器」，用组合而非继承挂载，**不改变 `main.gd` 对外的 `_save_payload()` / `_apply_payload()` / `_unhandled_input()` 契约**；优先顺序：
  1. `ui/panels.gd`：面板开关与 UI 构造（当前 UI 全部运行时创建）。
  2. `fishing.gd`：钓鱼状态机，顺带定义 D3 的状态 3 语义或删除该分支。
  3. `shop.gd` / `craft.gd`：商店与制作/建造。
  4. `net_sync.gd`：主机权威同步与 guest 限制（集中 D4 的限制清单）。
  5. `day_cycle.gd`：昼夜/天气/季节推进。
- 每拆一个模块，**单独一次提交**，且不得同时改玩法数值。
- AC：
  1. `main.gd` 单文件行数降至 ≤ 3000 行（阶段目标，非一次性要求）。
  2. 每个新模块有文件头 `##` 说明职责与对外接口，与现有脚本风格一致。
  3. 拆分前后 `_save_payload()` 输出字段集合完全相同。
  4. 每步通过第 8 章冒烟清单。

### SPEC-5 最小回归网

- 规格：新增 `tests/` 目录，用轻量 GDScript 测试场景或 GdUnit4（二选一，倾向无第三方依赖的自写断言脚本），优先覆盖**纯逻辑、无渲染依赖**的规格：时间流速与跨日、季节推导、作物生长/复生、`MACHINE_INPUTS` 转换、存档载荷往返、输入映射唯一性、房间码字符集。
- AC：
  1. 至少 6 条断言用例，可用 `godot --headless --path . --script tests/run.gd` 一条命令跑完并返回非零表示失败。
  2. 测试不依赖 `build/`、网络或 Godot 编辑器 GUI。
  3. 文档记录执行命令。

### SPEC-6 联机能力对齐

- 规格：把 guest 不可用的能力（宠物、传送、存读档）集中到 `net_sync.gd` 的显式能力表，UI 上提前置灰并给出一致文案；逐项评估哪些可安全放开（宠物/传送属状态同步，存读档应继续保持主机权威）。
- AC：
  1. guest 触发受限能力时只有一处提示来源，不再散落 `main.gd`。
  2. 主机与 guest 在农田、昼夜、天气上保持一致（人工双开验证）。

### 明确不在本轮范围

- 重做美术/UI 视觉、新增玩法内容、更换引擎或渲染方式、引入 C#、服务端权威化联机、多人 >2 人。

---

## 7. 实施计划（任务分解与依赖）

| 阶段 | 任务 ID | 动作 | 涉及文件 | 依赖 | 完成判定 |
| --- | --- | --- | --- | --- | --- |
| P0 止血（优先，建议立即） | T0.1 | 增补 `.gitignore`（`tools/shot*.png*`、`font_backup/` 等），确认 342 个未跟踪文件的取舍 | `.gitignore` | — | SPEC-1 AC1 |
| | T0.2 | 把当前大版本作为一次完整提交；必要时用 `tools/commit_main.py` 备用通道 | 全仓库 | T0.1 | SPEC-1 AC2 |
| | T0.3 | 修 D1 键位冲突 + D2 文案漂移 | `project.godot`, `main.tscn`, `main.gd` | T0.2 | SPEC-2 AC1-3 |
| P1 基线 | T1.1 | 新增根 `README.md`（运行/导出/联机/部署） | `README.md` | T0.2 | SPEC-1 AC3 |
| | T1.2 | 存档载荷加 `v` 与迁移分派 | `main.gd`, `save.gd`(可选) | T0.2 | SPEC-3 AC1-3 |
| | T1.3 | 建立 `tests/run.gd` 与首批 6 条纯逻辑断言 | `tests/` | T1.2 | SPEC-5 AC1-3 |
| P2 拆分（每步一提交） | T2.1 | 抽出 UI 面板控制器 | `main.gd` → `scripts/ui/` | T1.3 | SPEC-4 AC2-4 |
| | T2.2 | 抽出钓鱼状态机，处理 D3 | `main.gd` → `scripts/fishing.gd` | T2.1 | 同上 |
| | T2.3 | 抽出商店 / 制作建造 | `main.gd` → `scripts/shop.gd`,`craft.gd` | T2.2 | 同上 |
| | T2.4 | 抽出联机同步与能力表（SPEC-6 / D4） | `main.gd` → `scripts/net_sync.gd` | T2.3 | SPEC-6 AC1-2 |
| | T2.5 | 抽出昼夜/季节推进 | `main.gd` → `scripts/day_cycle.gd` | T2.4 | SPEC-4 AC1 |
| P3 打磨 | T3.1 | 删除/实现 D3 空分支；补齐联机受限能力评估结论 | 对应模块 | T2.x | 无 `pass` 空状态分支 |
| | T3.2 | 导出前检查脚本（Godot 版本、字体子集、wasm.gz 是否比 wasm 新） | `tools/` | T2.5 | `build/web` 一次成功导出 |

**排期建议**：P0 是数据安全问题，不应排在重构之后；P2 的每一步都必须以 T1.3 的回归网为前提。

---

## 8. 验证与验收

### 8.1 手动冒烟清单（每次改动后执行）

| # | 场景 | 步骤 | 期望 |
| --- | --- | --- | --- |
| 1 | 桌面启动 | Godot 4.7 打开 `project.godot` 运行 | 进标题页，可选 6 个存档槽与世界/主角 |
| 2 | 一天循环 | 开垦→播种→浇水→睡觉 | 跨日、作物生长、季节按 14 天推进、雨天免水 |
| 3 | 存读档 | F5 存档 → 修改金币 → F9 读档 | 状态完全还原；旧单档能自动迁到 0 号槽 |
| 4 | 键位 | 按 G / 新范围键 / 1-0 | 图鉴、范围提示、10 槽工具各自正确 |
| 5 | 钓鱼/矿洞 | 各完成一次 | 状态机无卡死，镐等级限制层数生效 |
| 6 | Web | 静态服务 `build/web/` 打开 | 中文不乱码、wasm.gz 生效、localStorage 存档可刷新保留 |
| 7 | 联机 | `npm start` 后双开，建房/加码 | 农田与昼夜同步、断线心跳清理、guest 受限提示一致 |

### 8.2 完成定义（DoD）

单个任务只有同时满足以下条件才算完成：工作区变更已提交；第 8.1 清单中与改动相关的条目通过；`tests/run.gd` 全绿；SDD 中受影响的规格章节同步更新；无新增编辑器诊断错误。

---

## 9. 附录

### 9.1 目录速查

```
StardewLike/
├─ project.godot          引擎配置 / 输入映射 / Autoload
├─ export_presets.cfg     Web 导出预设
├─ web_shell.html         Web 自定义壳（gzip wasm 加载）
├─ icon.svg
├─ scenes/                main.tscn / player.tscn
├─ scripts/               22 个 .gd（各带 .uid）
├─ shaders/               sunlight.gdshader
├─ assets/                PNG / WAV / TTF（程序化生成）
├─ tools/
│  ├─ gen_pixel_art.py    程序化生成全部 PNG
│  ├─ subset_font.py      字体子集化
│  ├─ commit_main.py      Git Data API 提交 main
│  ├─ deploy_web.py       部署 gh-pages
│  ├─ relay/              server.js / package.json / README.md
│  └─ shot*.png           90 张调试截图（应忽略）
├─ build/web/             Web 导出产物（已忽略）
└─ docs/SDD.md            本文
```

### 9.2 常用命令

```bash
# 本地联机中继
cd tools/relay && npm install && npm start          # :8765，可用 PORT 覆盖

# 素材 / 字体
python tools/gen_pixel_art.py
python tools/subset_font.py

# 提交 / 部署（github.com git 端点不稳时的备用通道）
python tools/commit_main.py "提交信息"
python tools/deploy_web.py                          # 需 Godot 导出产物 + gh auth token

# 网页版指定中继（HTTPS 必须 wss://）
https://192aaa.github.io/stardew-like/?ws=wss://<域名>
```

### 9.3 规格索引

数值表见 §4.1–4.3；输入映射见 §4.4；存档字段见 §4.5；协议见 §4.6；发布链路见 §4.7；风险见 §5；改造规格与 AC 见 §6；任务见 §7；验收见 §8。
