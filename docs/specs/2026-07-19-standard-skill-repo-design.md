# VideoLens 标准 Skill 仓库改造 — 规格文档

**文档版本**：v1.2（DocReview 第二轮已通过，N1/N2 低严重度建议已修复）
**创建日期**：2026-07-19
**状态**：审核通过，可进入实施
**作者**： brainstorming 协作产出

---

## 1. 背景与目标

### 1.1 背景

当前 `/workspace` 仓库是一个混合结构，包含四类异质产物：

1. **VideoLens 核心 SDK**（`src/videolens/`）：Python 包，提供 CLI、流水线、MCP server、9 种分析模式
2. **Hermes 技能定义**（`hermes-skill/`）：`SKILL.md` + `references/`，服务于 Hermes Agent 平台
3. **Hermes 视频生成工具**（`hermes-video-tools/`）：`video_generation_tool.py` 与 `xai_video_tools.py`，注册到 Hermes 工具 registry
4. **Web 部署产物**（`app.py` / `Dockerfile` / `railway.json` / `src/videolens/web/`）：FastAPI + Streamlit + Railway 部署

仓库仅 1 次提交（`b5b27ef feat: add VideoLens full source code`），分支 `dev`。

### 1.2 目标

将仓库改造为**单一职责的标准 Skill 仓库**，满足以下硬性目标：

| 编号 | 目标 | 验证方式 |
|------|------|--------|
| G1 | **三生态兼容**：同一份 `SKILL.md` 与目录结构可被 Hermes Agent、Trae IDE、Anthropic 通用 Skill 宿主识别 | 三生态目标路径均存在 `SKILL.md` 且 frontmatter 含 `name`/`description`/`tags`（注：`tags` 为 Hermes 必需、Trae/Anthropic 忽略字段，三生态均会扫描到但仅 Hermes 用于触发匹配） |
| G2 | **安装即可用**：执行 `install.sh` 后，宿主立即可调用 `videolens analyze` 完成视频分析 | `install.sh` 退出码 0 后，`videolens version` 与 `videolens analyze` 对本地 mp4 输出 report.md |
| G3 | **单技能多模式**：1 个 `videolens` 技能，9 种分析模式通过 `--mode` 参数选择 | `skills/videolens/SKILL.md` 是仓库内唯一的技能定义文件 |
| G4 | **仅视频分析**：移除视频生成工具与 Web 部署 | 旧路径全部删除（见 §5 迁移映射） |
| G5 | **多颗粒度可调**：通过帧数、时间线密度、置信度阈值等参数控制输出粒度 | `SKILL.md` 工作流章节明确参数表与自适应规则 |

### 1.3 非目标（YAGNI）

- 不拆分多个细粒度技能（已否决方案 B/C）
- 不发布到 PyPI（用户选择"一键安装脚本"）
- 不保留 Web UI / Docker / Railway 部署能力
- 不实现 MCP 多技能路由（保留现有 `mcp_server.py` 单文件即可）
- 不修改 `src/videolens/` 内部的业务逻辑代码

---

## 2. 三生态兼容策略

### 2.1 三生态识别机制对比

| 生态 | 识别机制 | frontmatter 必需字段 | 安装目标路径 |
|------|---------|---------------------|-------------|
| Hermes Agent | 扫描 skills 目录下 `SKILL.md` | `name` + `description` + `tags` | `<hermes_root>/skills/<name>/` |
| Trae IDE | 扫描 `/data/user/skills/<name>/SKILL.md` | `name` + `description` | `/data/user/skills/<name>/` |
| Anthropic 通用 | `SKILL.md` + `scripts/` + `references/` + `assets/` 目录约定 | `name` + `description` | 用户自定义，通常 `~/.skills/<name>/` |

### 2.2 兼容策略

**Frontmatter 字段取并集**：`name` + `description` + `tags`。Hermes 使用 `tags` 做触发匹配，其他生态忽略未使用字段，不冲突。

**目录结构遵循 Anthropic 通用约定**：`SKILL.md` + `scripts/` + `references/` + `assets/`。此约定同时被 Trae IDE 与 Hermes 接受。

**安装目标路径多写**：`install.sh` 同时将技能目录复制/软链到三个生态的目标路径，幂等执行。

---

## 3. 仓库目录结构（目标态）

### 3.1 顶层结构

```
/workspace/
├── skills/                          # 新增：技能定义根目录
│   └── videolens/                   # 唯一技能
│       ├── SKILL.md                 # 技能清单（frontmatter + 工作流）
│       ├── scripts/                 # 调用封装脚本
│       │   ├── analyze.sh           # 封装 videolens analyze 调用
│       │   ├── adaptive_frames.sh   # 帧数自适应辅助
│       │   └── validate_env.sh      # 环境变量校验
│       ├── references/              # 平台特定说明
│       │   ├── douyin-extraction.md # 抖音视频提取（迁移自 hermes-skill/references/）
│       │   ├── youtube-bilibili.md  # YouTube/B站下载说明
│       │   └── whisper-setup.md     # 本地 Whisper 模型说明
│       └── assets/                  # 静态资源（如有示例 prompt 模板）
│           └── prompt-templates.md  # 9 种模式的 prompt 模板
├── src/
│   └── videolens/                   # 保留：核心 SDK（不动业务代码）
│       ├── cli.py
│       ├── pipeline.py
│       ├── mcp_server.py
│       ├── config.py
│       ├── types.py
│       ├── cache.py
│       ├── analysis/
│       ├── processors/
│       ├── outputs/
│       └── resolvers/
├── tests/
│   └── test_production_recipe_mode.py
├── docs/
│   └── specs/
│       └── 2026-07-19-standard-skill-repo-design.md  # 本文档
├── install.sh                       # 新增：一键安装脚本
├── uninstall.sh                     # 新增：卸载脚本
├── pyproject.toml                   # 保留：SDK 依赖声明
├── README.md                        # 保留：更新为技能仓库说明
├── LICENSE                          # 保留
├── .gitignore                       # 保留
└── .python-version                  # 保留
```

### 3.2 删除清单

以下文件/目录在改造中**整文件/目录删除**：

| 路径 | 删除原因 |
|------|---------|
| `app.py` | Web 部署入口（FastAPI），不再保留 |
| `Dockerfile` | Docker 部署，不再保留 |
| `railway.json` | Railway 部署配置，不再保留 |
| `src/videolens/web/` | Streamlit Web UI，不再保留 |
| `src/videolens/outputs/write_pdf.py` | PDF 输出依赖 weasyprint/markdown（属 `[ui]` extra），与"仅视频分析、移除 Web/PDF 部署"目标一致，删除 |
| `hermes-video-tools/` | 视频生成工具，仅保留视频分析 |
| `hermes-skill/` | 内容迁移到 `skills/videolens/` 后删除原目录 |

**局部修改**（不整文件删除）：

- `pyproject.toml`：删除 `[project.optional-dependencies] ui` 段、`[tool.vercel]` 段、`[dependency-groups] dev` 中的 `videolens[ui]` 自引用、主依赖中的 `fastapi`（详见 §7.1）
- `src/videolens/outputs/__init__.py`：删除 `from videolens.outputs.write_pdf import render_pdf, write_pdf` 与 `__all__` 中的 `write_pdf`、`render_pdf` 两项
- `src/videolens/cli.py`：删除 `ui` 命令（第 33–59 行），同步删除文件顶部不再使用的 `import os` / `import subprocess` / `import sys` / `from importlib.util import find_spec` / `from pathlib import Path` 中仅被 `ui` 命令使用的 import（详见 §10 T18）

### 3.3 SKILL.md Frontmatter 规范

```yaml
---
name: videolens
description: >-
  VideoLens — Universal video intelligence. Analyze any video (local files,
  YouTube, Douyin/TikTok, B站, etc.) with prompt-directed AI analysis.
  Timestamped evidence, frame description, audio transcription, synthesis
  report. 9 analysis modes: general / bug / meeting / ux / tutorial /
  product_demo / content / privacy / production_recipe. Runs in background.
tags: [video, analysis, ai, douyin, tiktok, youtube, bilibili, media, ocr, transcription]
---
```

**字段约束**：

- `name`：必须为 `videolens`，全小写，与目录名一致
- `description`：单段英文，不超过 500 字符，必须列出支持的平台与 9 种模式
- `tags`：英文小写数组，不少于 5 个、不超过 15 个

**YAML 折叠块兼容性**：`description` 使用 `>-` 折叠块标量。三生态 frontmatter 解析器均基于完整 YAML 1.2 解析（Hermes 使用 PyYAML、Trae IDE 使用 ruamel.yaml、Anthropic 通用约定使用 js-yaml），均支持折叠块标量。若实施时发现某生态解析异常，回退为单行字符串（与旧 `hermes-skill/SKILL.md` 一致）。

---

## 4. SKILL.md 工作流规范

### 4.1 触发条件

用户发送视频链接或本地视频文件路径时**自动触发分析**。

**支持的视频链接格式**：

- 抖音：`https://v.douyin.com/xxx`、`https://www.douyin.com/video/xxx`
- YouTube：`https://youtube.com/watch?v=xxx`、`https://youtu.be/xxx`
- B站：`https://www.bilibili.com/video/xxx`
- TikTok：`https://www.tiktok.com/@user/video/xxx`
- 直链：以 `.mp4` / `.mov` / `.webm` / `.avi` 结尾的 URL
- 本地路径：`/path/to/video.mp4`

**检测规则**：链接或路径中包含 `douyin.com`、`youtube.com`、`youtu.be`、`bilibili.com`、`tiktok.com`、`video/`、`.mp4`、`.mov`、`.webm`、`.avi` 时自动触发。

### 4.2 分析模式（9 种）

| 模式 | `--mode` 值 | 用途 |
|------|------------|------|
| 通用分析 | `general` | 默认模式，开放式分析 |
| Bug 检测 | `bug` | 检测软件 Bug 与异常 |
| UX 分析 | `ux` | 用户体验分析 |
| 教程分析 | `tutorial` | 教程类视频拆解 |
| 产品演示 | `product_demo` | 产品演示视频分析 |
| 会议总结 | `meeting` | 会议视频纪要 |
| 内容审核 | `content` | 内容合规审核 |
| 隐私检查 | `privacy` | 隐私信息检测 |
| 生产配方 | `production_recipe` | 生产流程配方提取 |

### 4.3 多颗粒度参数

| 参数 | CLI 选项 | 默认值 | 作用 |
|------|---------|--------|------|
| 帧数上限 | `--max-frames` | 40 | 控制送入视觉模型的帧数（成本控制） |
| 帧间隔 | `--frame-interval` | 5.0 | 秒，控制时间线密度 |
| 捕获时长 | `--capture-duration` | 60.0 | 浏览器捕获时长（PostHog/Hotjar 等） |
| 强制重分析 | `--force` | false | 跳过缓存 |
| 仅 JSON 输出 | `--json` | false | 跳过 markdown |

**帧数自适应规则**（短视频避免重复抽取）：

| 视频时长 | `--max-frames` | `--frame-interval` |
|---------|---------------|-------------------|
| < 30s | 3 | 10.0 |
| 30s–60s | 6 | 10.0 |
| > 60s | 8 | 15.0 |

### 4.4 标准调用流程

1. **环境校验**：`scripts/validate_env.sh` 检查 `OPENAI_API_KEY`、`OPENAI_BASE_URL`、`VIDEOLENS_MODEL_VISION`、`VIDEOLENS_MODEL_SYNTHESIZE`、`VIDEOLENS_WHISPER_DIR` 是否设置
2. **视频获取**：
   - 抖音 → Playwright 抓取 `aweme/v1/web/aweme/detail/` API 提取直链 → `curl -L` 下载
   - YouTube/B站/TikTok → `yt-dlp` 下载
   - 直链 → 直接下载
   - 本地文件 → 直接使用
3. **分析执行**：调用 `scripts/analyze.sh`，后台运行 `videolens analyze`
4. **结果输出**：读取 `report.md`，提取 Findings（标题、置信度、证据时间戳），结构化摘要返回用户

### 4.5 已知陷阱（必须在 SKILL.md 中保留）

- 抖音页面需浏览器访问获取 video URL，下载地址有时效性
- 国内网络限制：HuggingFace 被墙，使用 `hf-mirror.com`；本地 Whisper 模型必须用绝对路径
- 商汤 API（`sensenova-6.7-flash-lite`）：支持 vision 与 JSON mode，不支持音频转录 API，自动回退本地 whisper
- 视频缓存位于 `~/.videolens/cache/`，重复分析相同视频直接使用缓存

---

## 5. 迁移映射（旧路径 → 新路径）

| 旧路径 | 新路径 | 操作 |
|--------|--------|------|
| `hermes-skill/SKILL.md` | `skills/videolens/SKILL.md` | 内容合并 + frontmatter 升级（增加 9 种模式说明）。目录名由 `hermes-skill` 改为 `videolens`，与 frontmatter `name` 字段对齐，符合 Anthropic 通用约定（目录名 = name），修正既有不一致 |
| `hermes-skill/references/douyin-extraction.md` | `skills/videolens/references/douyin-extraction.md` | 直接迁移 |
| `hermes-skill/references/`（其他） | `skills/videolens/references/` | 直接迁移 |
| `hermes-skill/` | （删除） | 内容迁移完成后删除整个目录 |
| `hermes-video-tools/` | （删除） | 整个目录删除 |
| `app.py` | （删除） | — |
| `Dockerfile` | （删除） | — |
| `railway.json` | （删除） | — |
| `src/videolens/web/` | （删除） | — |
| `src/videolens/`（其他） | `src/videolens/`（原位保留） | 不动业务代码 |
| `tests/` | `tests/`（原位保留） | 不动 |
| `pyproject.toml` | `pyproject.toml`（原位修改） | 删除 `[ui]` 可选依赖、`[tool.vercel]` 段 |
| `README.md` | `README.md`（重写） | 改为技能仓库说明，含安装与使用 |
| `LICENSE` / `.gitignore` / `.python-version` | 原位保留 | — |

---

## 6. 安装脚本规范

### 6.1 install.sh

**职责**：

1. 检测 Python ≥ 3.12 与 `uv` 是否可用，缺失则报错并给出安装指引
2. 在仓库根执行 `uv sync --extra capture --extra mcp`（安装 SDK 依赖 + Playwright 抖音捕获 + MCP server 依赖）
3. 执行 `uv run playwright install chromium`（下载抖音捕获所需的浏览器二进制；失败时输出 warning 但不阻断，退出码仍为 0）
4. 将 `skills/videolens/` **复制**（非软链）到三个生态目标路径：
   - Trae IDE：`/data/user/skills/videolens/`
   - Hermes Agent：`$HERMES_SKILLS_DIR/videolens/`（若环境变量存在）
   - Anthropic 通用：`$HOME/.skills/videolens/`（若目录存在或可创建）
5. 校验 `videolens version` 可执行（typer 子命令模式，非 `--version`）
6. 输出安装结果摘要

**复制策略（固化）**：采用 `cp -r` 复制而非软链。理由：(a) 三生态目标路径隔离，源变更不传播避免半一致性；(b) 软链在部分宿主（如 Windows Git Bash）不跟随，且 SKILL.md 内相对路径解析会跟随软链基目录导致 references/assets 加载异常。

**幂等性实现**：重复执行 `install.sh` 必须安全。每个目标路径先 `rm -rf <target>` 再 `cp -r skills/videolens <target>`，确保旧文件不残留。

**退出码**：

- `0`：成功
- `1`：依赖缺失（Python/uv）
- `2`：`uv sync` 失败
- `3`：技能目录复制失败
- `4`：`videolens version` 校验失败

### 6.2 uninstall.sh

**职责**：

1. 删除三个生态目标路径下的 `videolens/` 目录
2. 不删除 `uv sync` 安装的 Python 包（避免破坏其他依赖）
3. 输出卸载结果摘要

**退出码**：`0` 成功，`1` 删除失败

### 6.3 validate_env.sh

**职责**：检查必需的环境变量是否设置、关键二进制是否在 PATH、Whisper 模型目录是否真实存在，缺失则输出缺失项与示例值。

**必需环境变量**：

| 变量 | 说明 | 示例值 |
|------|------|--------|
| `OPENAI_API_KEY` | OpenAI 兼容 API 密钥 | `sk-xxx` |
| `OPENAI_BASE_URL` | API 端点 | `https://token.sensenova.cn/v1` |
| `VIDEOLENS_MODEL_VISION` | 视觉模型 | `sensenova-6.7-flash-lite` |
| `VIDEOLENS_MODEL_SYNTHESIZE` | 综合模型 | `sensenova-6.7-flash-lite` |
| `VIDEOLENS_WHISPER_DIR` | Whisper 模型目录（指向模型文件直接父目录） | `/home/admin/.cache/whisper/tiny` |

**关键二进制校验**：

| 检查项 | 校验命令 | 失败处理 |
|--------|---------|---------|
| `uv` 在 PATH | `command -v uv` | 提示 "uv not found, run install.sh first" |
| `videolens` 在 PATH | `command -v videolens` | 提示 "videolens not found, run install.sh first" |

**Whisper 目录校验**：

| 检查项 | 校验命令 | 失败处理 |
|--------|---------|---------|
| `$VIDEOLENS_WHISPER_DIR` 目录存在 | `[ -d "$VIDEOLENS_WHISPER_DIR" ]` | 提示 "Whisper dir not found: $VIDEOLENS_WHISPER_DIR" |
| 目录非空（含模型文件） | `[ -n "$(ls -A "$VIDEOLENS_WHISPER_DIR" 2>/dev/null)" ]` | 提示 "Whisper dir is empty, download model first" |

**退出码**：`0` 全部就绪，`1` 缺失项（环境变量/二进制/目录任一缺失均返回 1）

---

## 7. 依赖与环境

### 7.1 pyproject.toml 修改

**保留**：

- `[project]` 主依赖（typer、pydantic、openai、yt-dlp、httpx、rich、faster-whisper）
- `[project.optional-dependencies] mcp` 与 `capture`
- `[project.scripts]`（`videolens` 与 `videolens-mcp`）
- `[build-system]`、`[dependency-groups] dev`（移除 `videolens[ui]` 后保留 pytest/ruff）、`[tool.ruff]`

**修改**：

- 删除 `[project.optional-dependencies] ui`（streamlit/pandas/markdown/weasyprint）
- 删除 `[tool.vercel]` 段
- 删除 `[dependency-groups] dev` 中的 `videolens[ui]` 自引用
- 删除主依赖中的 `fastapi`（经 Grep 实证：`src/videolens/` 内无 `import fastapi` / `from fastapi`，仅仓库根 `app.py` 使用，而 `app.py` 已在 T12 删除）
- `description` 改为反映技能仓库定位

**fastapi 决策（已决，非开放问题）**：经审核阶段 Grep 实证，`src/videolens/` 内零 fastapi import，`mcp_server.py` 的 imports 仅含 `asyncio/json/os/pathlib/typing/openai/videolens.*`，不依赖 fastapi。fastapi 从主依赖移除安全，无需移入 mcp extra。

### 7.2 环境变量

环境变量通过 `validate_env.sh` 校验，不写入仓库。用户在调用前自行 export。

---

## 8. 错误处理与回退

| 场景 | 处理方式 |
|------|---------|
| `install.sh` 检测到 Python < 3.12 | 退出码 1，输出 "Python >= 3.12 required, found <version>" |
| `install.sh` 检测到 `uv` 不可用 | 退出码 1，输出 "uv not found. Install: curl -LsSf https://astral.sh/uv/install.sh \| sh" |
| `uv sync` 失败 | 退出码 2，输出 stderr，提示用户检查网络与 pyproject.toml |
| 技能目录复制失败（权限） | 退出码 3，输出目标路径与权限检查命令 |
| `videolens version` 失败 | 退出码 4，提示用户运行 `uv sync` 与 `which videolens` |
| `validate_env.sh` 缺失变量 | 退出码 1，列出缺失变量与示例值 |
| 抖音视频 URL 时效过期 | `analyze.sh` 输出 "视频地址已过期，请重新获取链接" |
| Whisper 模型路径错误 | `analyze.sh` 输出 "Whisper 模型未找到，请检查 VIDEOLENS_WHISPER_DIR" |
| 网络下载失败 | `analyze.sh` 输出 "下载失败：<url>"，退出码非 0 |
| 重复执行 `install.sh` | 先清理目标目录再复制，幂等 |

---

## 9. 测试与验收

### 9.1 验收前置条件

执行 AC4–AC10 前需满足以下前置条件：

| 前置项 | 要求 | 准备方式 |
|--------|------|---------|
| 测试视频 | `/tmp/test.mp4`，时长 ≥ 30s（覆盖 30s–60s 帧数自适应档，便于边界验证），含清晰画面与语音 | `ffmpeg -f lavfi -i testsrc=duration=30:size=320x240:rate=25 -f lavfi -i sine=frequency=440 -c:v libx264 -c:a aac /tmp/test.mp4`（无 ffmpeg 时从 `https://example.com/sample.mp4` 下载） |
| 环境变量 | `OPENAI_API_KEY` / `OPENAI_BASE_URL` / `VIDEOLENS_MODEL_VISION` / `VIDEOLENS_MODEL_SYNTHESIZE` / `VIDEOLENS_WHISPER_DIR` 全部 export | 由用户准备（消耗真实 API 配额，单次分析约 8 帧视觉调用 + 1 次综合调用，成本量级 < $0.01） |
| Whisper 模型 | `$VIDEOLENS_WHISPER_DIR` 目录存在且非空 | 已预下载到 `/home/admin/.cache/whisper/tiny`（沙箱环境，与 §6.3 示例值一致） |

### 9.2 验收清单

| 编号 | 验收项 | 验证命令 | 期望结果 |
|------|--------|---------|---------|
| AC1 | 仓库目录结构符合规范 | `ls skills/videolens/` | 输出含 `SKILL.md`、`scripts/`、`references/`、`assets/` |
| AC2 | 旧路径已删除 | `ls app.py Dockerfile railway.json hermes-skill hermes-video-tools src/videolens/web src/videolens/outputs/write_pdf.py 2>&1` | 全部 "No such file or directory" |
| AC3 | Frontmatter 字段完整 | `grep -E '^(name|description|tags):' skills/videolens/SKILL.md` | 输出 3 行（`description:` 因 YAML 折叠块可能只显示键名，需 `grep -A1 '^description:'` 验证值存在） |
| AC4 | `install.sh` 执行成功 | `bash install.sh && echo $?` | 退出码 0 |
| AC5a | Trae IDE 路径存在 SKILL.md | `ls /data/user/skills/videolens/SKILL.md` | 文件存在 |
| AC5b | Hermes 路径存在 SKILL.md（条件性） | `if [ -n "$HERMES_SKILLS_DIR" ]; then ls "$HERMES_SKILLS_DIR/videolens/SKILL.md"; else echo "HERMES_SKILLS_DIR 未设置，跳过"; fi` | 文件存在或输出跳过说明 |
| AC5c | Anthropic 通用路径存在 SKILL.md | `ls "$HOME/.skills/videolens/SKILL.md"` | 文件存在 |
| AC6 | `videolens version` 可执行 | `videolens version` 或 `uv run videolens version` | 输出版本号 |
| AC7 | 本地 mp4 分析成功 | `videolens analyze /tmp/test.mp4 --prompt "主题" --mode general --output-dir /tmp/out` | `/tmp/out/report.md` 存在 |
| AC8 | `validate_env.sh` 检测全变量缺失 | `unset OPENAI_API_KEY OPENAI_BASE_URL VIDEOLENS_MODEL_VISION VIDEOLENS_MODEL_SYNTHESIZE VIDEOLENS_WHISPER_DIR && bash skills/videolens/scripts/validate_env.sh; echo $?` | 退出码 1，列出 5 个缺失变量 |
| AC9 | `uninstall.sh` 执行成功 | `bash uninstall.sh && echo $?` | 退出码 0，目标路径已清空 |
| AC10 | `install.sh` 幂等 | 连续执行两次 `bash install.sh` | 两次均退出码 0 |
| AC11 | `pyproject.toml` 已清理 | `grep -E 'streamlit|weasyprint|vercel|fastapi' pyproject.toml` | 无输出 |
| AC12 | README.md 已更新 | `head -5 README.md` | 标题含 "Skill" 或 "技能" |
| AC13 | 9 种分析模式与 SDK 一致 | `grep -cE 'general|bug|meeting|ux|tutorial|product_demo|content|privacy|production_recipe' skills/videolens/SKILL.md` | 输出 ≥ 9 |
| AC14 | `cli.py` 中 `ui` 命令已删除 | `grep -c 'def ui' src/videolens/cli.py` | 输出 0 |
| AC15 | `outputs/__init__.py` 已清理 PDF 引用 | `grep -c 'write_pdf\|render_pdf' src/videolens/outputs/__init__.py` | 输出 0 |

### 9.3 测试策略

- **手动验证**：AC1–AC15 由人工按命令执行
- **回归测试**：保留 `tests/test_production_recipe_mode.py`，确保 SDK 业务逻辑未被破坏；若该测试依赖被删除模块（如 `web/`），同步修复测试 import
- **不新增**自动化测试脚本（YAGNI）

---

## 10. 实施任务清单

| 编号 | 任务 | 依赖 | 输出 |
|------|------|------|------|
| T1 | 创建 `skills/videolens/` 目录树 | — | 空目录 |
| T2 | 编写 `skills/videolens/SKILL.md`（合并旧 SKILL.md + 升级 frontmatter + 9 种模式说明） | T1 | SKILL.md |
| T3 | 迁移 `hermes-skill/references/` 到 `skills/videolens/references/` | T1 | references/ 文件 |
| T4 | 新增 `skills/videolens/references/youtube-bilibili.md` 与 `whisper-setup.md` | T1 | 2 个 md |
| T5 | 编写 `skills/videolens/scripts/analyze.sh` | T1 | analyze.sh |
| T6 | 编写 `skills/videolens/scripts/adaptive_frames.sh` | T1 | adaptive_frames.sh |
| T7 | 编写 `skills/videolens/scripts/validate_env.sh`（含环境变量 + 二进制 + Whisper 目录校验） | T1 | validate_env.sh |
| T8 | 编写 `skills/videolens/assets/prompt-templates.md`（9 种模式 prompt 模板） | T1 | prompt-templates.md |
| T9 | 编写仓库根 `install.sh`（含 `uv sync --extra capture --extra mcp` + 复制到三生态路径） | T2–T7 | install.sh |
| T10 | 编写仓库根 `uninstall.sh` | T9 | uninstall.sh |
| T11 | 修改 `pyproject.toml`（删除 ui 依赖、tool.vercel 段、dev 组 videolens[ui] 自引用、主依赖 fastapi） | — | pyproject.toml |
| T12 | 删除 `app.py`、`Dockerfile`、`railway.json` | — | — |
| T13 | 删除 `src/videolens/web/` | — | — |
| T14 | 删除 `hermes-video-tools/` | — | — |
| T15 | 删除 `hermes-skill/`（内容已迁移） | T2, T3 | — |
| T16 | 重写 `README.md`（技能仓库说明 + 安装 + 使用） | T9 | README.md |
| T17 | 删除 `src/videolens/outputs/write_pdf.py` | T18 | — |
| T18 | 修改 `src/videolens/outputs/__init__.py`（移除 write_pdf/render_pdf import 与 __all__ 项）；修改 `src/videolens/cli.py`（删除 ui 命令第 33–59 行 + 清理仅 ui 使用的 import） | T13 | __init__.py、cli.py |
| T19 | 检查并修复 `tests/test_production_recipe_mode.py` 若依赖被删模块 | T13, T17, T18 | test 文件 |
| T20 | 验收 AC1–AC15 | T1–T19 | 验收记录 |

---

## 11. 风险与开放问题

### 11.1 风险

| 严重程度 | 风险 | 缓解措施 |
|---------|------|---------|
| 中 | `install.sh` 在不同操作系统（Linux/macOS）路径差异 | 仅声明支持 Linux（与 Trae IDE 沙箱环境一致），macOS 用户手动调整 |
| 中 | `HERMES_SKILLS_DIR` 环境变量未定义时无法安装到 Hermes | `install.sh` 检测变量存在性，缺失则跳过 Hermes 安装并输出 warning |
| 中 | `uv sync --extra capture` 安装 Playwright 后仍需 `playwright install chromium` 下载浏览器二进制 | `install.sh` 在 `uv sync` 后追加 `uv run playwright install chromium`，失败时输出 warning 但不阻断（抖音分析时才报错） |
| 低 | 旧 commit 历史保留被删文件 | 不清理 git 历史（YAGNI） |

### 11.2 已决项（原开放问题，审核阶段已实证闭环）

- **Q1（已决）**：`fastapi` 可从主依赖移除。经 Grep 实证 `src/videolens/` 内零 `import fastapi` / `from fastapi`，仅仓库根 `app.py`（已删除）使用。
- **Q2（已决）**：`mcp_server.py` 不依赖 fastapi。Read 后确认 imports 仅含 `asyncio/json/os/pathlib/typing/openai/videolens.*`。fastapi 无需移入 mcp extra。

---

## 12. 参考资料

- 现有 `hermes-skill/SKILL.md`（迁移来源）
- `/data/user/skills/` 下其他 Trae 技能的目录结构（参考）
- `pyproject.toml` 现有依赖声明
- `src/videolens/cli.py` 的 `analyze` 命令签名

---

**文档结束**
