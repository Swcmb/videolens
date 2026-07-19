#!/usr/bin/env bash
# VideoLens 分析调用封装
# 用法：analyze.sh <video_path_or_url> [--mode <mode>] [--prompt <prompt>] [--output-dir <dir>] [--max-frames <n>] [--frame-interval <sec>]
# 退出码：0 成功 / 1 环境校验失败 / 2 下载失败 / 3 分析失败

set -euo pipefail

# 定位技能根目录（脚本位于 skills/videolens/scripts/）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# === 自动加载仓库根目录的 .env 配置文件 ===
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

# 默认参数
VIDEO_SOURCE=""
MODE="general"
PROMPT="这个视频的主题是什么？核心观点是什么？"
OUTPUT_DIR="/tmp/videolens_result"
MAX_FRAMES=""
FRAME_INTERVAL=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --max-frames) MAX_FRAMES="$2"; shift 2 ;;
    --frame-interval) FRAME_INTERVAL="$2"; shift 2 ;;
    --help|-h)
      echo "用法: analyze.sh <video_path_or_url> [--mode <mode>] [--prompt <prompt>] [--output-dir <dir>] [--max-frames <n>] [--frame-interval <sec>]"
      exit 0 ;;
    *)
      if [[ -z "$VIDEO_SOURCE" ]]; then
        VIDEO_SOURCE="$1"
      else
        echo "未知参数: $1" >&2
        exit 1
      fi
      shift ;;
  esac
done

if [[ -z "$VIDEO_SOURCE" ]]; then
  echo "错误：缺少视频源参数" >&2
  echo "用法: analyze.sh <video_path_or_url> [--mode <mode>] [--prompt <prompt>] ..." >&2
  exit 1
fi

# 步骤 1：环境校验
if ! bash "$SCRIPT_DIR/validate_env.sh"; then
  echo "环境校验失败，请按提示修复后重试" >&2
  exit 1
fi

# 步骤 2：视频获取（如果是 URL 则下载，本地路径则直接使用）
LOCAL_VIDEO="$VIDEO_SOURCE"
if [[ "$VIDEO_SOURCE" =~ ^https?:// ]]; then
  TEMP_VIDEO="/tmp/videolens_video_$(date +%s).mp4"
  echo "下载视频: $VIDEO_SOURCE -> $TEMP_VIDEO"

  if [[ "$VIDEO_SOURCE" =~ douyin\.com ]]; then
    # 抖音需通过 Playwright 抓取直链，详见 references/douyin-extraction.md
    echo "检测到抖音链接，需通过 Playwright 抓取直链后用 curl 下载"
    echo "请参考 references/douyin-extraction.md 手动获取直链后传入直链或本地路径"
    exit 2
  elif [[ "$VIDEO_SOURCE" =~ (youtube\.com|youtu\.be|bilibili\.com|tiktok\.com) ]]; then
    # YouTube / B站 / TikTok 使用 yt-dlp
    if ! command -v yt-dlp >/dev/null 2>&1; then
      echo "yt-dlp 未安装，请运行 install.sh" >&2
      exit 2
    fi
    if ! yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
         -o "$TEMP_VIDEO" "$VIDEO_SOURCE" 2>&1; then
      echo "下载失败：$VIDEO_SOURCE" >&2
      exit 2
    fi
  elif [[ "$VIDEO_SOURCE" =~ \.(mp4|mov|webm|avi)$ ]]; then
    # 直链
    if ! curl -L -o "$TEMP_VIDEO" "$VIDEO_SOURCE" \
         -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"; then
      echo "下载失败：$VIDEO_SOURCE" >&2
      exit 2
    fi
  else
    echo "不支持的视频 URL 格式：$VIDEO_SOURCE" >&2
    exit 2
  fi
  LOCAL_VIDEO="$TEMP_VIDEO"
fi

if [[ ! -f "$LOCAL_VIDEO" ]]; then
  echo "视频文件不存在：$LOCAL_VIDEO" >&2
  exit 2
fi

# 步骤 3：帧数自适应（若未显式指定）
if [[ -z "$MAX_FRAMES" || -z "$FRAME_INTERVAL" ]]; then
  ADAPTIVE=$(bash "$SCRIPT_DIR/adaptive_frames.sh" "$LOCAL_VIDEO")
  ADAPTIVE_MAX_FRAMES=$(echo "$ADAPTIVE" | cut -d: -f1)
  ADAPTIVE_FRAME_INTERVAL=$(echo "$ADAPTIVE" | cut -d: -f2)
  [[ -z "$MAX_FRAMES" ]] && MAX_FRAMES="$ADAPTIVE_MAX_FRAMES"
  [[ -z "$FRAME_INTERVAL" ]] && FRAME_INTERVAL="$ADAPTIVE_FRAME_INTERVAL"
fi

# 步骤 4：执行分析
echo "开始分析：$LOCAL_VIDEO"
echo "  mode=$MODE max-frames=$MAX_FRAMES frame-interval=$FRAME_INTERVAL output-dir=$OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

VIDEOLENS_ARGS=(
  analyze "$LOCAL_VIDEO"
  --prompt "$PROMPT"
  --mode "$MODE"
  --max-frames "$MAX_FRAMES"
  --frame-interval "$FRAME_INTERVAL"
  --output-dir "$OUTPUT_DIR"
)

if ! videolens "${VIDEOLENS_ARGS[@]}" 2>&1; then
  echo "分析失败" >&2
  exit 3
fi

# 步骤 5：输出结果
REPORT_PATH="$OUTPUT_DIR/report.md"
if [[ -f "$REPORT_PATH" ]]; then
  echo "分析完成，报告路径：$REPORT_PATH"
  echo "---"
  cat "$REPORT_PATH"
else
  echo "警告：未找到报告文件 $REPORT_PATH" >&2
  exit 3
fi
