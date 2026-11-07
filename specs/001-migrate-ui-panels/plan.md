# 实现计划：迁移剩余 UI 面板到独立控制器

**分支**：`001-migrate-ui-panels`（未启用 git 扩展，仅作标识） | **日期**：2026-11-06 | **规格**：[spec.md](spec.md)

**输入**：来自 `specs/001-migrate-ui-panels/spec.md` 的功能规格（已由放行记录 #18 验收通过）

**说明**：本计划由 `/speckit.plan` 生成。需求契约以 `SDD/spec.md` 为准，执行表与放行记录以 `SDD/plan.md` 为准；本功能对应 T2.1b（C5-①b），完成后按 R0 停下等待裁决。

## 摘要（Summary）

把 `main.gd` 中剩余的约 2500 行 UI 面板实现（商店 / 制作 / 背包 / 设置 / 图鉴 / 帮助 / 标题 / 选角等）迁入 `scripts/ui/panels.gd`，沿用 T2.1 已验收的「组合而非继承 + 薄转发壳」做法。本步不新增玩法、不改动数值、不引入依赖、不新增持久化字段，目标是让 `main.gd` 继续瘦身并为 C5 后续四步拆分让路。技术路线已由 `SDD/spec.md` C5 与放行记录 #14 定死，详见 [research.md](research.md)。

## 技术上下文（Technical Context）

- **语言/版本（Language/Version）**：Godot 4.7 标准版（非 .NET）+ GDScript 静态类型；可执行文件 4.7.2（`godot` 不在 PATH，需绝对路径）。
- **主要依赖（Primary Dependencies）**：无第三方运行时依赖（INV-3）。`tools/` 下 Python 工具仅用于素材生成，`tools/relay/` 的 Node.js `ws` 仅用于联机中继，二者与本步无关。
- **存储（Storage）**：单 JSON 存档，6 槽（键 `stardew_save_v1_N`），Web 端 `localStorage`；载荷 64 字段、`v=2`。`scripts/save.gd` 只做字符串读写，不理解字段。
- **测试（Testing）**：`tests/run.gd` 自写断言，命令 `godot --headless --path . --script tests/run.gd`，判据 `RESULT cases=7 pass=24 fail=0` 且退出码 0；另用 `read_lints` 与 `git diff --check`。
- **目标平台（Target Platform）**：桌面（编辑器 F5）与 Web/WASM（唯一导出预设 `export_presets.cfg`，输出 `build/web/index.html`，`thread_support=false`）。
- **项目类型（Project Type）**：Godot 桌面 / Web 游戏，单体主脚本渐进拆分（C5）。
- **性能目标（Performance Goals）**：无新增指标；`gl_compatibility`、1280x720、最近邻纹理过滤不变，不得引入渲染或帧率退化（INV-6 冒烟）。
- **约束（Constraints）**：`SDD/spec.md` INV-1~7、C5-AC2~4 与 §5 非目标；`SDD/AGENTS.md` R0（单任务、完成即停）、R1（只改登记文件）、R2（提交需授权）、R3（验证诚实）；每步独立提交（C5 SHALL）。
- **规模/范围（Scale/Scope）**：`main.gd` 起点 6801 行，迁移约 2500 行面板函数；登记文件为 `scripts/main.gd` 与 `scripts/ui/panels.gd`。C5-AC1「≤3000 行」是五步阶段终点，本步不判定。

技术上下文无 `NEEDS CLARIFICATION` 项，Phase 0 调研结论见 [research.md](research.md)。

## 宪法检查（Constitution Check）

*闸门：必须在 Phase 0 调研前通过，并在 Phase 1 设计后复核。*

| 原则 | 判定 | 依据 |
| --- | --- | --- |
| I. 契约优先与单步放行 | 通过 | 本功能对应 `SDD/plan.md` T2.1b，由记录 #17 放行；完成后停下等裁决 |
| II. 不变量冻结 | 通过 | FR-005 明确冻结玩法数值、存档兼容、技术栈；非目标沿用 §5 |
| III. 回归网与诚实验证 | 通过 | [quickstart.md](quickstart.md) 规定 `pass=24 fail=0`、如实标注未执行冒烟项 |
| IV. 变更边界与提交授权 | 通过 | 只改 `scripts/main.gd` 与 `scripts/ui/panels.gd`；提交需 R2 授权；新模块文件头 `##` |
| V. 真相源与文档优先级 | 通过 | 契约/执行表 > 代码现状 > `docs/AS-IS-baseline.md`；本计划声明从属关系 |
| VI. 工件与沟通语言 | 通过 | 全部工件用简体中文，标识符/路径/编号保留原文 |

**Phase 0 前结论**：无违规，闸门通过，无需填写复杂度追踪表。
**Phase 1 设计后复核**：[research.md](research.md) 的决策 1/2/4 均未新增 Autoload、未改 `project.godot`、未触碰非登记文件；[data-model.md](data-model.md) 确认不引入新数据实体与字段；[quickstart.md](quickstart.md) 的验证口径与 C5-AC2~4 一致。复核结论仍为无违规。

## 项目结构（Project Structure）

### 文档（本功能）

```text
specs/001-migrate-ui-panels/
├── spec.md              # 功能规格（已验收，记录 #18）
├── plan.md              # 本文件（/speckit.plan 产物）
├── research.md          # Phase 0：决策与备选方案
├── data-model.md        # Phase 1：无新数据实体及现有约束
├── quickstart.md        # Phase 1：验证指南
├── checklists/
│   └── requirements.md  # 规格质量清单（4 项已知偏差如实标注）
└── tasks.md             # Phase 2 产物（/speckit.tasks，不由本命令创建）
```

### 源码（仓库根目录）

```text
scripts/
├── main.gd               # 玩法编排 + 面板薄转发壳 + 面板状态变量
├── ui/
│   └── panels.gd         # UI 面板控制器（T2.1 已建，本步扩展）
├── touch_controls.gd     # 直接读 main 的 16 个 *_open 状态（组合链，不改）
├── save.gd               # 只做字符串读写，不理解字段（不改）
└── game.gd               # 静态数据表与玩法常量（不改）
scenes/main.tscn          # 主场景（不改）
tests/run.gd              # C4 回归网（不改）
```

**结构决策**：沿用 T2.1 已验收的 `scripts/ui/` 分层，不新建目录、不新增 Autoload、不改导出配置。控制器在 `_ready()` 中于 `_ui_font` 之后、全部 `_build_*` 之前挂载；面板实现迁入控制器，`main.gd` 保留同名薄转发壳，玩法写入与状态变量仍留在 `main.gd`，由控制器显式 `main.<member>` 回调。依据见 [research.md](research.md) 决策 1、2、4。本功能为纯内部重构，不生成 `contracts/`。

## 复杂度追踪（Complexity Tracking）

本步宪法检查无违规，按模板约定不填写违规说明表。

## 完成条件（Done When）

- [x] 技术上下文全部确定，无待澄清项
- [x] 宪法检查（Phase 0 前 + Phase 1 后）均通过
- [x] Phase 0 产出 `research.md`
- [x] Phase 1 产出 `data-model.md`、`quickstart.md`；`contracts/` 按内部重构条款跳过
- [ ] 等待人类对本计划的裁决；之后才进入 `/speckit.tasks`（R0）
