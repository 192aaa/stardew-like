# 重构/迁移安全检查清单：迁移剩余 UI 面板到独立控制器

**用途**：校验 T2.1b「UI 面板迁移」相关**需求**是否已写得完整、清晰、一致、可测、覆盖到位。本清单只测需求质量，不测实现是否正确（实现验证由 quickstart.md 与 tests/run.gd 负责）。
**创建日期**：2026-11-06
**所属功能**：[spec.md](../spec.md) · [plan.md](../plan.md) · [tasks.md](../tasks.md)

**说明**：本自定义检查清单由 `/speckit.checklist` 命令依据功能上下文与需求生成，领域聚焦「重构/迁移安全」。用户未指定领域参数，按默认深度 Standard、受众为评审人（PR/review）、聚焦 Top-2 相关簇（范围边界确定性、验证可测性）生成。
**评审归属**：本清单是由**评审人负责**的需求质量评审工件。仅当评审人确认某条需求质量标准已满足时，才把该项标记为 `[x]`。
**标记含义**：`[x]` 表示该条标准已就「需求质量」通过评审，并不代表实现工作已完成。

<!--
  ============================================================================
  重要：下列检查项仅为示例，用于说明格式。
  /speckit.checklist 命令已依据 T2.1b 功能上下文替换为真实检查项。
  ============================================================================
-->

## 需求完整性（Requirement Completeness）

- [ ] CHK001 是否明确列出了本步全部待迁移面板（商店/制作/背包/设置/图鉴/帮助/标题/选角）的清单？[Completeness, Spec §用户故事1 / §边界]
- [ ] CHK002 规格是否已定义「迁移过程中断或失败」时的回退/恢复/安全终止策略（FR-008 与 §失败与回退处理）？[Completeness, Spec §FR-008 / §失败与回退处理]
- [ ] CHK003 是否定义了薄转发壳的契约：哪些函数迁入 `panels.gd`、哪些玩法逻辑必须留在 `main.gd`？[Gap, Spec FR-006]
- [ ] CHK004 是否明确了面板状态变量（`_save_*` / `_boot_*` / `*_open` 等）必须留在 `main.gd` 的约束？[Completeness, Spec §边界 / Edge Case]

## 需求清晰性（Requirement Clarity）

- [ ] CHK005 「不引入依赖」是否明确排除任何第三方**运行时**库/模块（仅工具链 Python/Node 用于素材与中继）？[Clarity, Spec FR-005]
- [ ] CHK006 「玩法数值零改动」是否给出可客观判定的口径（对照 `SDD/spec.md` 数值表逐项不变）？[Clarity, Spec FR-005 / SC-002]
- [ ] CHK007 C5-AC2「字段集合相同」是否明确了比较方法（静态解析 `_save_payload` + 真实主场景运行时探针）？[Clarity, Spec FR-002]
- [ ] CHK008 「薄转发壳」是否定义了可接受的实现形式（保留同名函数、转发调用、状态不迁移）？[Clarity, Spec FR-006 / research §决策1]

## 需求一致性（Requirement Consistency）

- [ ] CHK009 `plan.md` 技术上下文与 `spec.md` 的「起点 6801 行 / 约 2500 行迁移量 / panels.gd 384 行基线」是否数值一致？[Consistency, Plan §技术上下文 vs Spec §SC-001 / tasks T002]
- [ ] CHK010 `tasks.md` 的依赖顺序（先迁移 T008~T010、后验证 T015~T018）是否反映「先动代码、后验回归」，且不与 constitution R0 单任务放行冲突？[Consistency, tasks.md]
- [ ] CHK011 constitution 原则 II（INV-1~7 冻结）与 `spec.md` FR-005 是否逐条对应、无遗漏？[Consistency, constitution II vs Spec FR-005]

## 验收标准质量（Acceptance Criteria Quality）

- [ ] CHK012 SC-002（`pass=24 fail=0`）与 SC-003（64 键、`v=2`、CSV 逐字相同）是否可被客观验证、不依赖主观判断？[Measurability, Spec §SC-002 / SC-003]
- [ ] CHK013 C5-AC1「≤3000 行」被本步显式声明为「五步终点、本步不判定」，是否写清以避免误读为验收门槛？[Clarity, Spec §SC-001]
- [ ] CHK014 SC-004（静态诊断 0、`git diff --check` 无空白错误）是否定义了清晰的通过/失败边界？[Measurability, Spec §SC-004]

## 场景覆盖（Scenario Coverage）

- [ ] CHK015 是否定义了触屏输入路径（`touch_controls.gd` 读取 16 个 `*_open`）在重构后保持可用的需求？[Coverage, Spec §边界]
- [ ] CHK016 是否定义了主场景 `_ready()` 初始化顺序（控制器挂载先于全部 `_build_*`）的需求？[Coverage, Spec §边界 / Edge Case]
- [ ] CHK017 是否定义了「真实主场景运行时」与 `--script` 模式差异的处理需求（R3 诚实性，不把空输出当通过）？[Coverage, Spec §边界 / R3]

## 边界/异常覆盖（Edge Case Coverage）

- [ ] CHK018 是否定义了引擎不可用时验证应如何降级（标「阻塞」而非通过）的需求？[Edge Case, Spec §边界 / R3]
- [ ] CHK019 是否定义了临时探针不得写入用户存档、用后须清理 `project.godot` 与探针文件的需求？[Edge Case, quickstart §3 / T005]

## 依赖与假设（Dependencies & Assumptions）

- [ ] CHK020 「只改 `scripts/main.gd` 与 `scripts/ui/panels.gd` 两文件」的假设是否已验证为不破坏任何非登记文件？[Assumption, Spec §假设 / R1]
- [ ] CHK021 是否已声明本步不新增持久化字段、不改动存档 schema 版本？[Assumption, data-model.md §结论]

## 歧义与冲突（Ambiguities & Conflicts）

- [ ] CHK022 `checklists/requirements.md` 中 4 项「未通过」（与通用模板口径冲突）是否已声明为已知约束而非缺陷？[Conflict, checklists/requirements.md §备注]
- [ ] CHK023 `tasks.md` 的 `T001…` 编号体系与 `SDD/plan.md` 的 `T2.1b` 是否已在文档中显式区分、避免混淆？[Ambiguity, tasks.md §编号体系说明]

## 备注（Notes）

- 仅在评审确认需求质量标准已满足后，才把条目标记为 `[x]`；仍需澄清或修正的条目保持未勾选。
- `/speckit.implement` 会读取勾选状态作为放行闸门，且**不得**修改勾选标记。
- `checklists/requirements.md` 有独立的内建生命周期（由 `/speckit.specify` 维护），与本清单并存、互不覆盖。
- 本清单条目面向「需求质量」，凡出现「验证/测试/确认实现行为」类表述均属越界，已在生成时规避。
- 条目按顺序编号，便于在 `SDD/plan.md` 放行记录中引用（如「CHK012 通过」）。
