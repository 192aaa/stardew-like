# 技术调研：迁移剩余 UI 面板到独立控制器

**日期**：2026-11-06
**功能**：`specs/001-migrate-ui-panels/spec.md`
**说明**：技术上下文的全部条目均已确定，无 `NEEDS CLARIFICATION` 项。本文件记录既定决策、理由与被否决的备选方案；需求契约以 `SDD/spec.md` 为准，放行记录以 `SDD/plan.md` 为准。

## 决策 1：沿用「组合而非继承 + 薄转发壳」

- **决策**：继续按 T2.1 已验收的做法，把面板实现迁入 `scripts/ui/panels.gd`，`main.gd` 原位置保留同名薄转发壳，控制器通过显式 `main.<member>` 回调玩法逻辑。
- **理由**：T2.1 已验证该做法使 `_mk_label` / `_mk_btn` 等调用点零改动，风险最低；C5 SHALL 要求按固定顺序渐进拆分，不宜中途换范式。
- **备选方案**：① 让面板控制器继承 `main.gd` —— 会形成循环依赖且状态归属不清，否决；② 全量重写所有调用点 —— 改动面扩大到数千行，违反 R1「只改登记文件」，否决。

## 决策 2：面板状态变量留在 `main.gd`

- **决策**：`_save_*` / `_boot_*` / `*_open` 等状态变量不迁移，控制器只持有行为、不持有状态。
- **理由**：`scripts/touch_controls.gd:216-223` 直接读取 main 的 16 个 `*_open`，组合链不能断；迁移状态会波及非登记文件。
- **备选方案**：把状态一并搬入控制器并让 touch_controls 改读控制器 —— 需改登记范围外的文件，且触碰触屏输入路径，否决。

## 决策 3：验收采用「等效方法」（静态解析 + 真实主场景运行时探针）

- **决策**：C5-AC2 用静态解析 `_save_payload()` 字段集合 + 真实主场景运行时探针取载荷 CSV 与基线比对，二者互相印证。
- **理由**：放行记录 #14 的人类裁决明确授权该等效方法；`--script` 模式不加载 Autoload，单靠静态解析不足以证明运行时行为。
- **备选方案**：只做静态 diff —— 无法覆盖运行时，否决；只做 `--script` 探针 —— 主脚本在该模式下编译期失败，否决。

## 决策 4：不新增 Autoload、不新建目录、不改导出配置

- **决策**：沿用 T2.1 建立的 `scripts/ui/` 分层，`_ready()` 中在全部 `_build_*` 之前完成控制器挂载。
- **理由**：INV-3 冻结技术栈、INV-5 要求既有能力不回归；新增 Autoload 会改变主场景初始化顺序并影响 `project.godot`（非登记文件）。
- **备选方案**：为面板单独注册 Autoload —— 影响面超出登记范围，否决。

## 决策 5：不生成 `contracts/`

- **决策**：本功能为纯内部重构，不对外暴露新接口，按 `/speckit.plan` Phase 1 的「项目纯内部时跳过」条款跳过 `contracts/`。
- **理由**：面板交互契约已由 `SDD/spec.md` C5 与既有冒烟清单定义，另建契约文档会造成重复且可能与唯一契约冲突。
- **备选方案**：为 22+ 个面板接口生成契约文件 —— 与 `SDD/spec.md` 重复，否决。

## 决策 6：跳过 `/speckit.clarify`

- **决策**：规格中无 `[NEEDS CLARIFICATION]` 标记，质量清单的 4 项未通过均属「内部重构与通用模板口径冲突」的已知约束，不是需求模糊。
- **理由**：放行记录 #18 的人类裁决为「规格通过」；按 `/speckit.plan` 的 handoff 直接进入技术计划。
- **备选方案**：为这 4 项发起澄清提问 —— 会重复已裁决事项，否决。

## 实现基线（T001~T007，2026-11-07 采集）

> 本节为 `/speckit.implement` 第 1~2 阶段的实测证据，作为迁移前后比对基准。全部数值为实际执行输出，未推断。

**T001 引擎**：`godot` 不在 PATH，使用绝对路径 `C:\Users\19275\AppData\Local\Temp\godot_web\Godot_v4.7.2-stable_win64.exe`；`--version` = `4.7.2.stable.official.ed1daf0bf`，与 `quickstart.md` 记录一致。工作目录为仓库根 `StardewLike`。

**T002 行数基线（实测，统一按 `[System.IO.File]::ReadAllLines` 口径）**：
- `scripts/main.gd` = **6801 行**；`scripts/ui/panels.gd` = 384 行。
- 与 `spec.md` SC-001 的「起点 6801 行」、`SDD/plan.md` 记录 #15、以及 `git show HEAD:scripts/main.gd`（6801 行）**一致，无偏差**。
- ⚠️ **一次统计口径错误已更正（R3）**：本轮初次采集误用 PowerShell `Get-Content` 得到 6623 行，并据此错误推断「6801 是 T2.1 前历史快照、差 178 行、T014 应按 6623 判定」。复核发现 `main.gd` 为纯 LF 行尾（`CRLF=0, loneLF=6801, loneCR=0`），`Get-Content` 少算 178 行；记录 #15 已明确说明此为混合行尾下的少算值。故**撤回该结论**，T014（SC-001）按规格原判据「低于起点 6801 行」执行。今后所有行数一律以 `ReadAllLines` 为准。

**T004 `_save_payload()` 静态键集合**：`scripts/main.gd:1368-1405` 的 return 字典共 **64 键**，含 `v`（= `SAVE_VERSION`），与规格基线一致。注意该函数是存档逻辑，含大量 `Game.*` 玩法状态，**不在迁移范围**（FR-005/FR-006）。

**T005 运行时载荷 CSV 基线**：在真实主场景经临时只读 Autoload 探针调用 `_save_payload()`，输出 `PROBE_COUNT 64` / `PROBE_V 2` / `PROBE_LEN 620`，排序后 CSV 620 字符与规格基线一致。探针不写存档；执行后 `project.godot` 已字节级还原（`git diff` 无变化）、`scripts/_probe_payload.gd` 已删除。

**T006 回归网基线**：`godot --headless --path . --script tests/run.gd` → `RESULT cases=7 pass=24 fail=0`，退出码 0。⚠️ 如实声明覆盖边界：`tests/run.gd` 在 `--script` 模式下**不加载 Autoload**，故 `main.gd` / `farm.gd` 编译期即失败，该回归网直连 `game.gd` / `save.gd` 数据表与公式，并对 `main.gd` 源码常量做静态防漂移断言 —— 它**不覆盖面板运行时行为**，迁移正确性须由 T015/T016（主场景启动 + 无脚本错误）与 T018（冒烟）另行证明。

**T007 状态变量核对表**（`scripts/touch_controls.gd:216-223`，`_blocked()` 直接读 `main.<member>`，迁移时**必须**留在 main）：
`main.sleeping`、`main._chat_open`、`main._daily_open`、`main.settings_open`、`main.help_open`、`main.dex_open`、`main.orders_open`、`main.bundles_open`、`main.shop_open`、`main.craft_open`、`main.cook_open`、`main.gift_open`、`main.dialog_open`、`main.goals_open`、`main.build_open`、`main.storage_open`，以及 `main._boot_panel != null`。共 16 个状态引用 + 1 个 boot 判空；任务清单概称「16 个 `*_open`」为近似表述，此处以源码实际为准。

**T003 待迁面板函数清单**（`scripts/main.gd` 中 `func _build_*` / `_open_*` / `_close_*` 实测定位）：

| 分组（对应任务） | 主函数（行号为迁移前实测） | 现状态 |
|---|---|---|
| 标题 / 选角（T008） | `_build_boot`(5998)、`_open_hero_select`(6138)、`_close_hero_select`(6311)、`_open_save_select`(6333)、`_close_save_select`(6365) | 其中 `_open_save_select` / `_close_save_select` 等 8 个已在 T2.1 迁为薄转发壳（`main.gd:6330-6366`） |
| 背包 / 设置 / 图鉴 / 帮助（T009） | `_build_bag`(6450)、`_build_settings`(4816)、`_build_dex`(4465)、`_build_help`(4572) | 待迁 |
| 商店 / 制作建造（T010） | `_build_shop`(2187)、`_build_craft`(3592)、`_build_structures_ui`(2733)、`_build_pet_house`(2531) | 待迁 |
| 其他（**不在** T2.1b 范围） | `_build_cook`(3267)、`_build_gift`(3378)、`_build_dialog`(3717)、`_build_orders`(3782)、`_build_guide`(3848)、`_build_goals`(3959)、`_build_bundles`(4047)、`_build_eggs`(4242)、`_build_barn_products`(4338)、`_build_daily`(4708)、`_build_stamina`(5139)、`_build_fishing_ui`(5168)、`_build_hud_extras`(5511) | 保留在 main，供 C5 后续步骤拆分 |

**T2.1 既有范式（迁移必须沿用）**：`main.gd:45` `preload` 控制器；`main.gd:392-395` 在 `_ready()` 最早处 `panels = PanelsScript.new(); panels.main = self; add_child(panels)`，早于 `_build_shop()`；`panels.gd` 以 `main.<member>` 读状态、不持有状态；main 保留**同名薄转发壳**（如 `main.gd:6334` `panels.open_save_select()`），使 main 内部既有调用点零改动。
