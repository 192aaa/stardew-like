# 星露谷Like

用 **Godot 4.7 + GDScript** 编写的像素风农场模拟游戏，可导出桌面与 Web（WASM）。已实现种田、钓鱼、采集、矿洞与战斗、养殖与宠物、村民好感与订单、四季天气与昼夜光照、6 槽存档、10 槽工具栏、双人联机与触屏控制。

- 仓库：https://github.com/192aaa/stardew-like
- 在线版：https://192aaa.github.io/stardew-like/
- 主场景：`res://scenes/main.tscn`｜Autoload：`Game` / `Sfx` / `Save` / `Music` / `Net`
- 渲染：`gl_compatibility`，1280×720，`canvas_items` 拉伸，最近邻纹理过滤

---

## 1. 运行

**桌面（推荐）**

1. 安装 **Godot 4.7 标准版**（非 .NET 版）。当前开发环境 `godot` 不在 PATH，请直接用编辑器。
2. 编辑器「导入项目」→ 选择本目录的 `project.godot` → F5 运行。
3. 首次导入会生成 `.godot/` 缓存与素材 `.import` 文件，属正常现象，均已忽略。

**Web（无需 Godot）**

```bash
cd build/web
python -m http.server 8000
# 浏览器打开 http://localhost:8000/
```

必须用 HTTP 服务，不能用 `file://`。`build/` 不入库，若目录为空请按第 3 节导出。

**命令行自测**

在项目根目录执行（`godot` 不在 PATH 时换成 Godot 可执行文件的绝对路径）：

```bash
godot --headless --path . --script tests/run.gd
# 例："/path/to/Godot_v4.7.2-stable_win64.exe" --headless --path . --script tests/run.gd
```

输出 `RESULT  pass=N  fail=0` 且退出码 0 为通过，退出码非 0 为失败。测试用自写断言，不依赖 `build/`、网络或编辑器 GUI，覆盖季节推导、输入映射唯一性、存档载荷往返、时间流速与跨日、作物生长/复生、`MACHINE_INPUTS` 转换。覆盖边界（哪些直连产品代码、哪些因 `--script` 不加载 Autoload 而采用规格复刻）见 `tests/run.gd` 文件头。

---

## 2. 键位速查

| 操作 | 按键 | 操作 | 按键 |
| --- | --- | --- | --- |
| 移动 | WASD / 方向键 | 使用工具 | 空格 / 鼠标左键 |
| 互动 | E | 技能 | Q |
| 切换 10 槽工具 | 1–0 | 背包 | I |
| 制作 | C | 建造 | V |
| 收集包 | B | 七日目标 | Y |
| 帮助 | H | 音乐开关 | M |
| 聊天 | T | 图鉴 | G |
| 一键开垦 / 种植 | F / P | 一键收获 / 浇水 | J / K |
| 传送 | R | 存档 / 读档 | F5 / F9 |

完整映射见 `project.godot` 的 `[input]` 段。

> **已知问题**：`codex` 与 `aoe_toggle` 目前都绑定 G 键，且 `main.gd` 的 `elif` 链先命中图鉴，因此键盘上的「一键范围切换」暂不可达，请用触屏按钮。修复已列入 `SDD/plan.md` 的 T1.1（契约 C2），完成前请勿按「X 键」操作。

---

## 3. 导出 Web

1. Godot 编辑器：**项目 → 导出**，使用已配置的 `Web` 预设（`export_presets.cfg`）。
2. 输出 `build/web/index.html`；预设排除 `tools/*` 与 `build/*`，自定义壳为 `web_shell.html`。
3. `web_shell.html` 会拦截引擎对 `index.wasm` 的请求，改取 `index.wasm.gz` 并用 `DecompressionStream('gzip')` 流式解压，首屏传输从 37.7 MB 降到约 9.6 MB；同时给 `index.pck` 加体积参数以绕开 GitHub Pages 的静态缓存。不支持流式解压的浏览器自动回退原始 wasm。
4. 更新 wasm 后，`tools/deploy_web.py` 会自动重新生成 `.gz`，无需手动压缩。

预设为 `variant/thread_support=false`，因此不需要 COOP/COEP 响应头，普通静态服务即可运行。

---

## 4. 联机

```bash
cd tools/relay
npm install
npm start          # 默认端口 8765，可用环境变量 PORT 覆盖
```

- 游戏开局面板选「建房联机」（生成 4 位房间码）或「加入好友」（输入房间码）。
- 同一台电脑双开游戏即可联机；局域网另一台机器用 `SL_RELAY=ws://<服务器内网IP>:8765` 启动游戏。
- 网页版部署在 HTTPS 上，浏览器禁止 `ws://` 混合内容，必须用 `wss://`：
  `https://192aaa.github.io/stardew-like/?ws=wss://<你的域名>`
- 中继地址优先级：环境变量 `SL_RELAY` → 网页 `?ws=` 参数 → `ws://localhost:8765`。
- 协议、房间码字符集与 15s 心跳见 `tools/relay/README.md`。

采用**主机权威**同步：guest 不支持存读档、传送与安放宠物，这些限制会在 UI 上给出提示。

---

## 5. 部署与提交

```bash
python tools/deploy_web.py                      # 把 build/web 部署到 gh-pages 分支
python tools/commit_main.py "提交信息"          # github.com git 端点不稳时的备用提交通道
```

前提：已执行 `gh auth login`（脚本通过 `gh auth token` 取凭据）；`deploy_web.py` 还需要第 3 节导出的 `build/web/`。`deploy_web.py` 按 blob sha 复用未变文件，避免重复上传 37 MB 的 wasm。

**两点必须知道**：

1. 本机 `github.com` 的 git 端点经常连接重置，两个脚本改走 `api.github.com` Git Data API。**用脚本提交后本地 git 引用不会更新**，会出现「本地落后远端很多提交」的假象，需 `git fetch origin main` + `git reset --mixed origin/main` 对齐（2026-11-05 已处理过一次）。标准 `git push` 若报 `Recv failure: Connection was reset`，可加 `-c http.version=HTTP/1.1` 重试。
2. `commit_main.py` 只读取 `git status --porcelain` 中的 `M` / `A` / `??` 单文件条目，**会跳过 `?? 目录/` 折叠条目和 `D` 删除**，历史上曾导致整个 `shaders/` 目录未入库。优先用标准 `git add -A` + `git commit` + `git push`。

---

## 6. 存档

- 6 个独立世界槽；桌面写 `user://saves/slot_N.json`，Web 写 `localStorage`（键 `stardew_save_v1_N`）。
- 设置（音量 / 触屏 / 缩放等）单独存放，不随清档丢失；旧版单档会自动迁入 0 号槽。
- F5 存档、F9 读档、睡觉自动存档；矿洞内存档会把位置记成洞口，读档总是回到地面农场。

---

## 7. 素材与工具

```bash
python tools/gen_pixel_art.py     # 程序化生成全部 PNG 到 assets/
python tools/subset_font.py       # 裁剪 Fusion Pixel 中文字体，减小 pck 体积
```

`assets/*.png` 与其 `.import` 由脚本生成，请勿手改。`tools/shot*` 是本地调试截图/录音，已被 `.gitignore` 忽略。

---

## 8. 目录结构

```
project.godot          引擎配置、输入映射、Autoload
export_presets.cfg     Web 导出预设
web_shell.html         Web 自定义加载壳（gzip wasm）
scenes/                main.tscn / player.tscn
scripts/               22 个 .gd：main.gd 玩法编排，game.gd 全局状态与数据表
tests/                 命令行回归网 run.gd（执行方式见第 1 节）
shaders/               sunlight.gdshader（昼夜光照）
assets/                PNG / WAV / TTF
tools/                 素材生成、字体裁剪、提交/部署、relay 中继服务
build/web/             Web 构建产物（忽略，不入库）
SDD/                   规格驱动：spec.md 契约 / AGENTS.md 红线 / plan.md 执行表
docs/                  AS-IS-baseline.md（现状调研，无契约效力）
```

---

## 9. 开发流程

本项目按规格驱动（SDD）执行：**先定契约 → 拆分任务 → 单步放行 → 验收再往下走**。

- 唯一契约：`SDD/spec.md`（不变式、契约条目 C1–C6、可判定 AC）
- 红线：`SDD/AGENTS.md`（优先于会话指令）
- 执行表与放行记录：`SDD/plan.md`

当前契约状态、任务进度与放行记录见 `SDD/plan.md` §3 / §6。命令行回归网见第 1 节「命令行自测」，改动纯逻辑后应先跑一次再提交验收。
