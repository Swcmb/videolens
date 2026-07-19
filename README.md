# VideoLens Skill 仓库

VideoLens 是一个 AI 驱动的视频智能分析**技能包**，支持对本地视频文件、YouTube、抖音、B站、TikTok 等平台的视频进行深度分析。本仓库同时是 **Hermes Agent / Trae IDE / Anthropic 通用 Skill** 三生态兼容的标准 Skill 仓库。

## 功能特性

- **多平台支持**：本地视频、YouTube、抖音、B站、TikTok、直链
- **多维度分析**：画面识别、OCR 文字提取、语音转录、时间线拆解
- **9 种分析模式**：通用分析、Bug 检测、UX 分析、教程分析、产品演示、会议总结、内容审核、隐私检查、生产配方
- **结构化输出**：Markdown 报告 + JSON 结构化数据
- **置信度评估**：对每个发现给出置信度评分
- **多颗粒度可调**：帧数、时间线密度、置信度阈值等参数控制输出粒度
- **三生态兼容**：一份 `SKILL.md` 同时被 Hermes / Trae / Anthropic 宿主识别

## 仓库结构

```
videolens-skill/
├── skills/                          # 技能定义根目录
│   └── videolens/                   # 唯一技能
│       ├── SKILL.md                 # 技能清单（frontmatter + 工作流）
│       ├── scripts/                 # 调用封装脚本
│       │   ├── analyze.sh           # 封装 videolens analyze 调用
│       │   ├── adaptive_frames.sh   # 帧数自适应辅助
│       │   └── validate_env.sh      # 环境变量校验
│       ├── references/              # 平台特定说明
│       │   ├── douyin-extraction.md
│       │   ├── youtube-bilibili.md
│       │   └── whisper-setup.md
│       └── assets/                  # 静态资源
│           └── prompt-templates.md  # 9 种模式的 prompt 模板
├── src/videolens/                   # 核心 SDK（保留，作为本地依赖）
│   ├── cli.py
│   ├── pipeline.py
│   ├── mcp_server.py
│   ├── analysis/modes/              # 9 种分析模式
│   ├── processors/
│   ├── outputs/
│   └── resolvers/
├── tests/
├── docs/specs/                      # 规格文档
├── install.sh                       # 一键安装脚本
├── uninstall.sh                     # 卸载脚本
└── pyproject.toml                   # SDK 依赖声明
```

## 快速开始

### 1. 安装

```bash
bash install.sh
```

安装脚本会：

1. 检测 Python ≥ 3.12 与 `uv`
2. 执行 `uv sync --extra capture --extra mcp` 安装 SDK 依赖
3. 执行 `uv run playwright install chromium` 下载浏览器二进制（用于抖音捕获）
4. 复制技能目录到 Trae IDE / Hermes Agent / Anthropic 通用三生态目标路径
5. 校验 `videolens version` 可执行（typer 子命令模式）

### 2. 配置环境变量

**方式 A（推荐）：使用 .env 配置文件**

```bash
cp .env.example .env
vi .env  # 填入实际值
```

`.env` 文件已被 `.gitignore` 忽略，不会被提交。`install.sh` / `validate_env.sh` / `analyze.sh` 会自动加载。

**方式 B：直接 export 环境变量**

```bash
export OPENAI_API_KEY="sk-xxx"
export OPENAI_BASE_URL="https://token.sensenova.cn/v1"
export VIDEOLENS_MODEL_VISION="sensenova-6.7-flash-lite"
export VIDEOLENS_MODEL_SYNTHESIZE="sensenova-6.7-flash-lite"
export VIDEOLENS_WHISPER_DIR="/home/admin/.cache/whisper/tiny"
```

### 3. 分析视频

```bash
# 方式一：直接调用 CLI
videolens analyze /path/to/video.mp4 --prompt "主题" --mode general --output-dir /tmp/out

# 方式二：使用技能封装脚本
bash skills/videolens/scripts/analyze.sh /path/to/video.mp4 --mode general --output-dir /tmp/out

# 方式三：分析 YouTube 视频
videolens analyze https://youtube.com/watch?v=xxx --mode general
```

### 4. 卸载

```bash
bash uninstall.sh
```

## 分析模式

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

Prompt 模板详见 [skills/videolens/assets/prompt-templates.md](skills/videolens/assets/prompt-templates.md)。

## 环境变量

| 变量 | 说明 |
|------|------|
| `OPENAI_API_KEY` | OpenAI 兼容 API 密钥（用于分析） |
| `OPENAI_BASE_URL` | 自定义 API 端点 |
| `VIDEOLENS_MODEL_VISION` | 视觉模型名 |
| `VIDEOLENS_MODEL_SYNTHESIZE` | 综合模型名 |
| `VIDEOLENS_WHISPER_DIR` | 本地 Whisper 模型目录（绝对路径） |

环境变量校验：`bash skills/videolens/scripts/validate_env.sh`

## 三生态兼容

| 生态 | 安装目标路径 | 识别机制 |
|------|-------------|---------|
| Trae IDE | `/data/user/skills/videolens/` | frontmatter `name` + `description` |
| Hermes Agent | `$HERMES_SKILLS_DIR/videolens/` | frontmatter `name` + `description` + `tags` |
| Anthropic 通用 | `~/.skills/videolens/` | `SKILL.md` + `scripts/` + `references/` + `assets/` |

`install.sh` 自动复制到三生态目标路径。

## 设计文档

规格文档详见 [docs/specs/2026-07-19-standard-skill-repo-design.md](docs/specs/2026-07-19-standard-skill-repo-design.md)。

## 许可证

MIT
