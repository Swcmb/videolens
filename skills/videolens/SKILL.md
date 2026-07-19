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

# VideoLens 视频分析技能

## 触发条件

用户发送视频链接或本地视频文件路径时**自动触发分析**，无需用户额外说明。

**支持的视频链接格式：**

- 抖音：`https://v.douyin.com/xxx`、`https://www.douyin.com/video/xxx`
- YouTube：`https://youtube.com/watch?v=xxx`、`https://youtu.be/xxx`
- B站：`https://www.bilibili.com/video/xxx`
- TikTok：`https://www.tiktok.com/@user/video/xxx`
- 直链：以 `.mp4` / `.mov` / `.webm` / `.avi` 结尾的 URL
- 本地路径：`/path/to/video.mp4`

**检测规则：** 链接或路径中包含 `douyin.com`、`youtube.com`、`youtu.be`、`bilibili.com`、`tiktok.com`、`video/`、`.mp4`、`.mov`、`.webm`、`.avi` 等视频关键词时，自动触发分析流程。用户直接发送 `.mp4` 文件时同样自动触发。

## 分析模式（9 种）

通过 `--mode` 参数选择分析模式：

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

## 工作流（自动化）

### 1. 环境校验

调用 `scripts/validate_env.sh` 检查必需环境变量、`uv` / `videolens` 二进制、Whisper 模型目录是否就绪。

**配置方式（二选一）：**

- **方式 A（推荐）**：在仓库根目录创建 `.env` 文件（`cp .env.example .env` 后填入实际值），`validate_env.sh` / `analyze.sh` / `install.sh` 会自动加载
- **方式 B**：在 shell 中 `export` 环境变量（向后兼容）

**必需环境变量：**

| 变量 | 说明 | 示例值 |
|------|------|--------|
| `OPENAI_API_KEY` | OpenAI 兼容 API 密钥 | `sk-xxx` |
| `OPENAI_BASE_URL` | API 端点 | `https://token.sensenova.cn/v1` |
| `VIDEOLENS_MODEL_VISION` | 视觉模型 | `sensenova-6.7-flash-lite` |
| `VIDEOLENS_MODEL_SYNTHESIZE` | 综合模型 | `sensenova-6.7-flash-lite` |
| `VIDEOLENS_WHISPER_DIR` | Whisper 模型目录（指向模型文件直接父目录） | `/home/admin/.cache/whisper/tiny` |

### 2. 视频获取

- 抖音链接 → 通过 Playwright 浏览器访问页面，从 `aweme/v1/web/aweme/detail/` API 提取视频直链 → 用 `curl -L` 下载（详见 `references/douyin-extraction.md`）
- YouTube / B站 / TikTok → 通过 `yt-dlp` 下载（已内置在 VideoLens venv）
- 直链 → 直接下载
- 本地文件 → 直接使用

### 3. 分析执行

调用 `scripts/analyze.sh`，后台运行 `videolens analyze`：

```bash
videolens analyze /tmp/video_xxx.mp4 \
  --prompt "这个视频的主题是什么？核心观点是什么？" \
  --mode general \
  --max-frames 8 \
  --frame-interval 15.0 \
  --output-dir /tmp/videolens_result
```

### 4. 多颗粒度参数

| 参数 | CLI 选项 | 默认值 | 作用 |
|------|---------|--------|------|
| 帧数上限 | `--max-frames` | 40 | 控制送入视觉模型的帧数（成本控制） |
| 帧间隔 | `--frame-interval` | 5.0 | 秒，控制时间线密度 |
| 捕获时长 | `--capture-duration` | 60.0 | 浏览器捕获时长（PostHog/Hotjar 等） |
| 强制重分析 | `--force` | false | 跳过缓存 |
| 仅 JSON 输出 | `--json` | false | 跳过 markdown |

**帧数自适应规则**（短视频避免重复抽取，由 `scripts/adaptive_frames.sh` 实现）：

| 视频时长 | `--max-frames` | `--frame-interval` |
|---------|---------------|-------------------|
| < 30s | 3 | 10.0 |
| 30s–60s | 6 | 10.0 |
| > 60s | 8 | 15.0 |

### 5. 结果输出

- 分析完成后读取 `/tmp/videolens_result/report.md`
- 提取关键 Findings（标题、置信度、证据时间戳）
- 以结构化摘要格式输出给用户

## 后台运行规则

1. 使用 `terminal(background=true, notify_on_complete=true)` 启动分析
2. 分析期间回复用户「收到，正在分析这个视频，稀等…」
3. 分析完成后的通知会自动触发，此时读取报告并输出摘要
4. 如果分析超时（超过 600s），重新尝试或告知用户

## 已知陷阱

### 抖音视频获取

- 抖音页面需要浏览器访问来获取 video URL（从 `aweme_detail` API 提取）
- 下载地址在 `aweme_detail.video.play_addr.url_list[0]` 或 `video.download_addr.url_list[0]`
- 下载时需添加 `-H "Referer: https://www.douyin.com/"` 和 `-A "Mozilla/5.0..."` 防反爬
- 视频 URL 有时效性，解析后尽快下载
- 详见 `references/douyin-extraction.md`

### 国内网络限制

- HuggingFace 被墙 → 使用 `hf-mirror.com` 下载模型文件
- 本地 whisper 模型已预下载到 `/home/admin/.cache/whisper/tiny/`
- 需设置 `VIDEOLENS_WHISPER_DIR` 环境变量指向该目录
- `faster-whisper` 加载模型时**必须使用绝对路径**而非 `"tiny"`（否则会尝试联网下载）
- 详见 `references/whisper-setup.md`

### 商汤 API 注意事项

- 模型：`sensenova-6.7-flash-lite`（免费）
- 支持 vision 和 JSON mode，不支持音频转录 API
- 音频转录自动回退到本地 whisper（见 `src/videolens/processors/transcribe_audio.py` 的 `_transcribe_local` 函数）
- 模型响应会先输出 `reasoning` 字段再输出 `content`，VideoLens SDK 读取 `content` 字段不受影响

### 视频缓存

- 已分析的视频缓存在 `~/.videolens/cache/` 目录
- 重复分析相同视频会直接使用缓存（更快）
- 如需重新分析，删除缓存目录或使用 `--force` 参数

### YouTube / B站下载

- 详见 `references/youtube-bilibili.md`

## 快速测试命令

```bash
# 单条分析（后台）
cd /path/to/videolens-skill-repo && export PATH="$HOME/.local/bin:$PATH" && \
export OPENAI_API_KEY="sk-xxx" && \
export OPENAI_BASE_URL="https://token.sensenova.cn/v1" && \
export VIDEOLENS_MODEL_VISION="sensenova-6.7-flash-lite" && \
export VIDEOLENS_MODEL_SYNTHESIZE="sensenova-6.7-flash-lite" && \
export VIDEOLENS_WHISPER_DIR="/home/admin/.cache/whisper/tiny" && \
videolens analyze /tmp/video.mp4 --mode general --max-frames 8 --output-dir /tmp/videolens_result
```

## 安装

执行仓库根目录的 `install.sh`：

```bash
bash install.sh
```

安装脚本会：

1. 检测 Python ≥ 3.12 与 `uv`
2. 自动加载 `.env` 配置文件（若存在）
3. 执行 `uv sync --extra capture --extra mcp` 安装 SDK 依赖
4. 执行 `uv run playwright install chromium` 下载浏览器二进制（用于抖音捕获）
5. 复制技能目录到 Trae IDE / Hermes Agent / Anthropic 通用三生态目标路径
6. 校验 `videolens version` 可执行（typer 子命令模式）

卸载执行 `uninstall.sh`。

### 配置 API Key

```bash
# 复制配置模板
cp .env.example .env

# 编辑 .env 填入实际值
vi .env
```

`.env` 文件已被 `.gitignore` 忽略，不会被提交到 git。

## Prompt 模板

9 种分析模式的 prompt 模板详见 `assets/prompt-templates.md`。
