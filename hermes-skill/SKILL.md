---
name: videolens
description: VideoLens — Universal video intelligence. Analyze any video (local files, YouTube, Douyin/TikTok, etc.) with prompt-directed AI analysis. Timestamped evidence, frame description, audio transcription, synthesis report. Runs in background.
tags: [video, analysis, ai, douyin, tiktok, youtube, media]
---

# VideoLens 视频分析技能

## 触发条件

用户发送视频链接时**自动触发分析**，无需用户额外说明。

**支持的视频链接格式：**
- 抖音：`https://v.douyin.com/xxx` `https://www.douyin.com/video/xxx`
- YouTube：`https://youtube.com/watch?v=xxx` `https://youtu.be/xxx`
- B站：`https://www.bilibili.com/video/xxx`
- 其他 Mp4/视频文件直链

**检测规则：** 链接中包含 `douyin.com`、`youtube.com`、`youtu.be`、`bilibili.com`、`tiktok.com`、`video/`、`.mp4` 等视频关键词时，自动触发分析流程。用户直接发送 `.mp4` 文件（QQ 文件消息）时，同样自动触发分析。

## 工作流（自动化）

### 1. 视频获取
- 抖音链接 → 通过浏览器访问页面，从 `aweme/v1/web/aweme/detail/` API 提取视频直链 → 用 `curl -L` 下载
- YouTube/B站 → 通过 `yt-dlp` 下载（已内置在 VideoLens venv）
- 直链 → 直接下载

### 2. 环境变量配置
```bash
export OPENAI_API_KEY="sk-xxx"
export OPENAI_BASE_URL="https://token.sensenova.cn/v1"
export VIDEOLENS_MODEL_VISION="sensenova-6.7-flash-lite"
export VIDEOLENS_MODEL_SYNTHESIZE="sensenova-6.7-flash-lite"
export VIDEOLENS_WHISPER_DIR="/home/admin/.cache/whisper"
```

### 3. 分析执行
使用 `videolens analyze` 命令，后台运行（terminal background=true）：

```bash
cd /home/admin/videolens && export PATH="$HOME/.local/bin:$PATH" && \
export OPENAI_API_KEY="..." && \
export OPENAI_BASE_URL="https://token.sensenova.cn/v1" && \
export VIDEOLENS_MODEL_VISION="sensenova-6.7-flash-lite" && \
export VIDEOLENS_MODEL_SYNTHESIZE="sensenova-6.7-flash-lite" && \
export VIDEOLENS_WHISPER_DIR="/home/admin/.cache/whisper" && \
uv run videolens analyze /tmp/video_xxx.mp4 \
  --prompt "这个视频的主题是什么？核心观点是什么？" \
  --mode general \
  --max-frames 8 \
  --frame-interval 15.0 \
  --output-dir /tmp/videolens_result 2>&1
```

### 4. 结果输出
- 分析完成后读取 `/tmp/videolens_result/report.md`
- 提取关键 Findings（标题、置信度、证据时间戳）
- 以结构化摘要格式输出给用户

### 5. 帧数自适应
根据视频时长调整帧数，避免过度抽取（短视频抽太多帧会重复）：
- 视频 < 30s：`--max-frames 3 --frame-interval 10.0`
- 视频 30s-60s：`--max-frames 6 --frame-interval 10.0`
- 视频 > 60s：`--max-frames 8 --frame-interval 15.0`

## 后台运行规则

1. 使用 `terminal(background=true, notify_on_complete=true)` 启动分析
2. 分析期间回复用户「收到，正在分析这个视频，稍等…」
3. 分析完成后的通知会自动触发，此时读取报告并输出摘要
4. 如果分析超时（超过600s），重新尝试或告知用户

## 已知陷阱

### 抖音视频获取
- 抖音页面需要浏览器访问来获取 video URL（从 `aweme_detail` API 提取）
- 下载地址在 `aweme_detail.video.play_addr.url_list[0]` 或 `video.download_addr.url_list[0]`
- 下载时需添加 `-H "Referer: https://www.douyin.com/"` 和 `-A "Mozilla/5.0..."` 防反爬
- 视频 URL 有时效性，解析后尽快下载

### 国内网络限制
- HuggingFace 被墙 → 使用 `hf-mirror.com` 下载模型文件
- 本地 whisper 模型已预下载到 `/home/admin/.cache/whisper/tiny/`
- 需设置 `VIDEOLENS_WHISPER_DIR` 环境变量指向该目录
- `faster-whisper` 加载模型时**必须使用绝对路径**而非 `"tiny"`（否则会尝试联网下载）

### 商汤 API 注意事项
- 模型：`sensenova-6.7-flash-lite`（免费）
- 支持 vision 和 JSON mode，不支持音频转录 API
- 音频转录自动回退到本地 whisper（见 `transcribe_audio.py` 的 `_transcribe_local` 函数）
- 模型响应会先输出 `reasoning` 字段再输出 `content`，VideoLens SDK 读取 `content` 字段不受影响

### 视频缓存
- 已分析的视频缓存在 `/home/admin/videolens/.videolens/cache/` 目录
- 重复分析相同视频会直接使用缓存（更快）
- 如需重新分析，删除缓存目录即可

## 快速测试命令

```bash
# 单条分析（后台）
cd /home/admin/videolens && export PATH="$HOME/.local/bin:$PATH" && \
export OPENAI_API_KEY="sk-xxx" && \
export OPENAI_BASE_URL="https://token.sensenova.cn/v1" && \
export VIDEOLENS_MODEL_VISION="sensenova-6.7-flash-lite" && \
export VIDEOLENS_MODEL_SYNTHESIZE="sensenova-6.7-flash-lite" && \
export VIDEOLENS_WHISPER_DIR="/home/admin/.cache/whisper" && \
uv run videolens analyze /tmp/video.mp4 --mode general --max-frames 8 --output-dir /tmp/videolens_result
```