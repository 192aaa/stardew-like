# 验证指南：迁移剩余 UI 面板到独立控制器

**日期**：2026-11-06
**功能**：`specs/001-migrate-ui-panels/spec.md`
**用途**：本步交付后，逐条验证 SC-001~004 与 C5-AC2~4；不含实现代码，实现细节在 `tasks.md` 与实现阶段。

## 前置条件

- 工作目录：`StardewLike`（仓库根目录）。
- Godot 4.7 标准版；`godot` 不在 PATH，需使用已提供的可执行文件绝对路径 `C:\Users\19275\AppData\Local\Temp\godot_web\Godot_v4.7.2-stable_win64.exe`。
- **T001 实测（2026-11-07）**：上述路径 `--version` 输出 `4.7.2.stable.official.ed1daf0bf`，可用；工作目录为仓库根 `StardewLike`。

> **行数统计口径（T002 复核，R3 更正）**：`main.gd` 为纯 LF 行尾，须统一用 `[System.IO.File]::ReadAllLines` 统计 = **6801 行**；PowerShell `Get-Content` 在该文件上少算为 6623 行，属统计口径问题，**不是真实行数变化**。基线 6801 与 `spec.md` SC-001、`SDD/plan.md` 记录 #15、`git HEAD` 一致；`panels.gd` = 384 行。SC-001 按规格原判据「低于起点 6801 行」执行。
- 引擎不可用时按 `SDD/AGENTS.md` R3 标记「阻塞」，**不得**把空输出当作通过证据。

## 1. C4 回归网

```
godot --headless --path . --script tests/run.gd
```
预期：`RESULT cases=7 pass=24 fail=0`、退出码 0，且「5 号槽已还原」通过。

## 2. 主场景启动

```
godot --headless --path . --quit-after 150
```
预期：退出码 0；`SCRIPT ERROR` / `Parse Error` / `Compile Error` / `Identifier not found` 命中 0。退出期的 `resources still in use` / `ObjectDB instances leaked` 是 T0.3 起既有现象，非本步引入。

## 3. 存档载荷一致性（C5-AC2 等效方法）

- 静态解析：迁移前后 `_save_payload()` 的 return 字典键集合均为 64 个、`identical=True`，含 `v`。
- 运行时探针：在真实主场景调用 `_save_payload()`，得到 64 键、`v=2`，排序后 CSV 与基线 620 字符逐字相同。
- 契约函数：`has_method("_save_payload" / "_apply_payload" / "_unhandled_input")` 均为 `true`。
- 探针不得写入任何用户存档；用完按 T2.1 的清理口径还原 `project.godot`、删除临时探针文件。

## 4. 冒烟清单（`SDD/plan.md` §4）

与本次改动相关的 #1（桌面启动 / 标题页 6 槽）、#3（存读档）、#4（键位）需通过；#2 / #5 / #6 / #7 若未执行，**如实标注为未执行**，不推断通过。逐项打开并关闭迁移范围内的面板（商店 / 制作 / 背包 / 设置 / 图鉴 / 帮助 / 标题 / 选角），确认无脚本错误且交互行为与迁移前一致。

## 5. 静态与范围检查

- `read_lints`（`scripts/main.gd`、`scripts/ui/panels.gd`）= 0 诊断。
- `git diff --check` 无空白错误；改动范围不超出 `SDD/plan.md` 登记的文件。
- `main.gd` 行数低于起点 6801 行；已迁移面板实现可在 `scripts/ui/panels.gd` 逐项核对，转发壳数量与接口清单一致。
- 文件头 `##` 写明职责与对外接口（C5-AC3）。

## 交付与停下

逐条列出 AC 的 `路径:行号` 证据，汇报 `git status --short`，按 C5 SHALL 每步独立提交（提交需按 R2 取得人类明确授权），然后**停下等待人类裁决**，不预做 T2.2 或任何后续任务（R0）。
