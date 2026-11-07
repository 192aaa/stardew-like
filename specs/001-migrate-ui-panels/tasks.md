---

description: "迁移剩余 UI 面板到独立控制器的任务清单"
---

# 任务清单：迁移剩余 UI 面板到独立控制器

**输入**：来自 `specs/001-migrate-ui-panels/` 的设计文档（`spec.md`、`plan.md`、`research.md`、`data-model.md`、`quickstart.md`）

**前置条件**：`plan.md`（必需）、`spec.md`（用户故事必需）、`research.md`、`data-model.md`、`quickstart.md`；`contracts/` 按内部重构条款不生成。

**测试**：本功能不新增测试文件，验证沿用既有 `tests/run.gd` 回归网与 `SDD/plan.md` §4 冒烟清单。

**组织方式**：任务按用户故事分组；所有代码改动只涉及两个登记文件 `scripts/main.gd` 与 `scripts/ui/panels.gd`。

> 编号体系说明：本文件的 `T001`… 是 Spec Kit 任务编号，与 `SDD/plan.md` 的 `T2.1b`、`T2.2` 等任务 ID 是两套体系。本文件全部任务同属 `SDD/plan.md` 的**一个**任务 T2.1b，完成后按 R0 停下等待人类裁决。

## 格式：`[ID] [P?] [Story] 描述`

- **[P]**：可并行执行（不同文件、无依赖）
- **[Story]**：该任务所属用户故事（US1 / US2 / US3）
- 描述中必须写出精确的文件路径

## 路径约定（Path Conventions）

- 工作目录：仓库根 `StardewLike`；所有路径均为项目相对路径。
- 代码改动范围：`scripts/main.gd`、`scripts/ui/panels.gd`。
- 只读核对范围：`scripts/touch_controls.gd`、`scripts/save.gd`、`scripts/game.gd`、`scenes/main.tscn`、`tests/run.gd`、`project.godot`、`export_presets.cfg`。
- 文档范围：`SDD/plan.md`、`specs/001-migrate-ui-panels/*.md`。

## 第 1 阶段：初始化（共享基础设施）

**目的**：固定基线与工具口径，避免后续证据不可比。

- [X] T001 核对 Godot 4.7.2 可执行文件绝对路径与工作目录，在 `specs/001-migrate-ui-panels/quickstart.md` 记录 `--version` 输出（实测 `4.7.2.stable.official.ed1daf0bf`）
- [X] T002 用 `[System.IO.File]::ReadAllLines` 记录 `scripts/main.gd` **6801** 行与 `scripts/ui/panels.gd` 384 行基线（与 `spec.md`、记录 #15、git HEAD 一致；`Get-Content` 的 6623 为口径少算值，已更正）
- [X] T003 [P] 在 `specs/001-migrate-ui-panels/research.md` 补录待迁面板函数清单（商店 / 制作 / 背包 / 设置 / 图鉴 / 帮助 / 标题 / 选角）

---

## 第 2 阶段：奠基（阻塞性前置条件）

**目的**：在任何迁移开始前取得可比对的基线证据。

**⚠️ 关键**：本阶段完成前，不得开始任何用户故事的工作。

- [X] T004 静态解析 `scripts/main.gd::_save_payload()` 的 return 字典键集合，保存 64 键（含 `v`）基线
- [X] T005 [P] 在真实主场景用临时探针取 `scripts/main.gd::_save_payload()` 运行时载荷（`PROBE_COUNT 64` / `PROBE_V 2` / `PROBE_LEN 620`）；`project.godot` 已字节级还原、探针已删除
- [X] T006 [P] 运行 `godot --headless --path . --script tests/run.gd`，记录迁移前 `cases=7 pass=24 fail=0` 基线
- [X] T007 记录 `scripts/touch_controls.gd:216-223` 读取的 16 个状态引用清单，作为「状态不得迁移」的核对表

**检查点**：基线齐备（行数、字段集合、运行时 CSV、回归网、状态清单），可开始迁移。

---

## 第 3 阶段：用户故事 1 - 面板实现集中化（优先级：P1）🎯 MVP

**目标**：把 T2.1b 登记的面板实现迁入 `scripts/ui/panels.gd`，`main.gd` 保留薄转发壳，使 `main.gd` 继续瘦身。

**独立测试**：核对已迁移面板的实现位置与转发壳数量，并比对 `scripts/main.gd` 行数下降；无需实现后续模块即可验证。

### 用户故事 1 的实现

- [X] T008 [US1] 迁移标题 / 选角面板函数到 `scripts/ui/panels.gd`，在 `scripts/main.gd` 保留同名薄转发壳
- [X] T009 [US1] 迁移背包 / 设置 / 图鉴 / 帮助面板函数到 `scripts/ui/panels.gd`，在 `scripts/main.gd` 保留同名薄转发壳（依赖 T008）
- [X] T010 [US1] 迁移商店 / 制作建造面板函数到 `scripts/ui/panels.gd`，在 `scripts/main.gd` 保留同名薄转发壳（依赖 T009）
- [X] T011 [US1] 核对 `scripts/main.gd::_ready()` 中控制器挂载顺序位于 `_ui_font` 之后、全部 `_build_*` 之前
- [X] T012 [US1] 核对 `scripts/main.gd` 中全部 `panels.*` 转发调用与 `scripts/ui/panels.gd` 对外接口一一对应，状态变量仍留在 main（依赖 T010）
- [X] T013 [US1] 更新 `scripts/ui/panels.gd` 的 `##` 文件头，列全对外接口与「不持有状态、不复制玩法数值」说明，满足 C5-AC3（依赖 T012）
- [X] T014 [US1] 用 `[System.IO.File]::ReadAllLines` 复测 `scripts/main.gd` 行数，确认低于 6801 行（SC-001）

**检查点**：所有登记面板的实现位置可逐项核对，`main.gd` 行数下降，组合链完整。

---

## 第 4 阶段：用户故事 2 - 玩家侧行为不回归（优先级：P1）

**目标**：证明迁移后既有面板交互、存档与输入映射均无回归。

**独立测试**：按 `specs/001-migrate-ui-panels/quickstart.md` 执行回归网、主场景启动与冒烟项，逐项记录结果。

### 用户故事 2 的验证

- [X] T015 [US2] 运行 `godot --headless --path . --script tests/run.gd`，确认 `RESULT cases=7 pass=24 fail=0`、退出码 0、5 号槽已还原
- [X] T016 [P] [US2] 运行 `godot --headless --path . --quit-after 150`，确认 `exit=0` 且 `SCRIPT ERROR` / `Parse Error` / `Compile Error` / `Identifier not found` 命中 0
- [X] T017 [US2] 在 `scripts/main.gd` 与 `scripts/ui/panels.gd` 执行 `read_lints`，确认 0 诊断
- [X] T018 [US2] 按 `specs/001-migrate-ui-panels/quickstart.md` §4 逐项打开并关闭迁移范围内的面板，记录冒烟 #1/#3/#4 结果；#2/#5/#6/#7 若未执行，按 R3 如实标注为「未执行」，不推断通过

**检查点**：回归网与冒烟结果齐备，未执行项如实标注。

---

## 第 5 阶段：用户故事 3 - 验收证据可核对（优先级：P2）

**目标**：留下可逐条核对的 AC 证据，供人类做出放行裁决。

**独立测试**：单独检查证据是否逐条给出 `路径:行号`、是否与基线一致。

### 用户故事 3 的实现

- [X] T019 [US3] 按 `specs/001-migrate-ui-panels/quickstart.md` §3 复跑静态解析 + 运行时探针，确认 64 键、`v=2`、CSV 620 字符与 T004/T005 基线逐字相同
- [X] T020 [US3] 在 `SDD/plan.md` 补记 T2.1b 执行完成，逐条给出 C5-AC2~4 与 FR-001~007 的 `路径:行号` 证据
- [X] T021 [P] [US3] 执行 `git status --short` 与 `git diff --check`，确认改动范围不超出 `scripts/main.gd`、`scripts/ui/panels.gd`、`SDD/plan.md`
- [X] T022 [US3] 按 C5 SHALL 准备本步独立提交内容，并在 `SDD/plan.md` 记录提交状态；提交动作需按 R2 取得人类明确授权后执行，未获授权则保持未提交

**检查点**：证据完整、范围合规、提交状态明确。

---

## 第 6 阶段：收尾与横切关注点

**目的**：全量复核并停在 R0 放行点。

- [X] T023 复核 `git diff --check` 无空白错误、`read_lints` 0 诊断，且 `scripts/ui/panels.gd` 无 `.uid` 残留、无临时探针文件
- [X] T024 按 R0 停下，在 `SDD/plan.md` 标记等待人类对 T2.1b 的验收裁决，不预做 T2.2 或任何后续任务

---

## 依赖与执行顺序（Dependencies & Execution Order）

### 阶段依赖

- **初始化（第 1 阶段）**：无依赖，可立即开始。
- **奠基（第 2 阶段）**：依赖 T001~T003，**阻塞**全部用户故事。
- **用户故事 1（第 3 阶段）**：依赖第 2 阶段；内部 T008 → T009 → T010 串行（同一对文件）。
- **用户故事 2（第 4 阶段）**：依赖第 3 阶段完成（必须先有迁移结果才能验证）。
- **用户故事 3（第 5 阶段）**：依赖第 4 阶段的验证结果作为证据来源。
- **收尾（第 6 阶段）**：依赖所有前述阶段完成。

### 用户故事之间的依赖

- **US1（P1）**：奠基后即可开始；是 MVP 主体。
- **US2（P1）**：与 US1 属同一次改动的两个侧面，**不可与 US1 并行**（验证必须在代码改动之后），但可独立核对。
- **US3（P2）**：依赖 US1 的代码结果 + US2 的验证输出。

### 单个用户故事内部

- 先完成迁移与转发壳，再核对挂载顺序与接口对应关系，最后更新文件头与行数。
- 本功能不新增测试文件，故无「先写失败测试」步骤；既有回归网作为验收判据在 US2 执行。
- 当前故事完成后才进入下一优先级。

### 并行机会

- T003、T005、T006、T016、T021 标记为 `[P]`，属文档/基线采集/验证类任务，可与同阶段其他任务并行。
- **代码改动任务无并行机会**：`scripts/main.gd` 与 `scripts/ui/panels.gd` 两个文件被所有迁移任务共用，同时修改会冲突，故 T008~T014 一律不标 `[P]`。
- 不同用户故事在此功能中不可由多人并行推进（同一对文件、强顺序依赖）。

---

## 并行示例：基线采集（第 2 阶段）

```bash
# 可并行启动的基线任务（互不改同一文件）：
Task: "T005 在真实主场景取 _save_payload() 运行时载荷 CSV 基线"
Task: "T006 运行 tests/run.gd 记录 cases=7 pass=24 fail=0 基线"

# 代码迁移任务必须串行：
Task: "T008 迁移标题/选角面板到 scripts/ui/panels.gd"
Task: "T009 迁移背包/设置/图鉴/帮助面板到 scripts/ui/panels.gd"
```

---

## 实施策略（Implementation Strategy）

### MVP 优先

1. 完成第 1 阶段：初始化（固定基线与工具口径）。
2. 完成第 2 阶段：奠基（关键 —— 阻塞所有故事）。
3. 完成第 3 阶段：US1 的迁移与接口核对。
4. 完成第 4 阶段：US2 的回归验证 —— **本功能必须包含此步才算可交付**，不能字面地「只做 US1」。
5. **停下并验证**：独立核对回归网与冒烟结果，等待人类裁决。

### 增量交付

1. 初始化 + 奠基 → 基线就绪。
2. US1 迁移 → 独立核对实现位置与行数（MVP 代码部分）。
3. US2 回归验证 → 独立核对无回归，构成可交付增量。
4. US3 证据整理 → 独立核对证据完整性。
5. 收尾 → 停下等裁决；每步都不破坏既有能力。

### 团队并行策略

本功能不适用多人并行：代码改动集中在 `scripts/main.gd` 与 `scripts/ui/panels.gd`，且 R0 要求同一时刻至多一个「进行中」任务。建议单人按序执行。

---

## 备注（Notes）

- `[P]` 任务 = 不同文件、无依赖；代码任务因共用文件一律不标 `[P]`。
- `[US1/US2/US3]` 标签把任务映射到 `spec.md` 的用户故事；初始化、奠基、收尾阶段不带故事标签。
- 所有代码改动 MUST 限于 `SDD/plan.md` 登记的两个文件（R1）；只读核对清单中的文件不得修改。
- 引擎不可用时按 R3 标记「阻塞」，不得把空输出当作通过证据；未执行的冒烟项如实标注。
- 提交需按 R2 取得人类明确授权，且按 C5 SHALL 每步独立提交；未获授权保持未提交。
- 全部任务完成后按 R0 停下，不预做 T2.2 或任何后续任务。
- 避免：任务描述含糊、同一文件并发修改、破坏独立性的跨故事依赖。
