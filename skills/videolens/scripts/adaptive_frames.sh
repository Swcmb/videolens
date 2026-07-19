#!/usr/bin/env bash
# 帧数自适应辅助脚本
# 根据视频时长返回推荐的 --max-frames 与 --frame-interval
# 用法：adaptive_frames.sh <video_path>
# 输出：<max_frames>:<frame_interval>
# 退出码：0 成功 / 1 失败

set -euo pipefail

VIDEO_PATH="${1:-}"

if [[ -z "$VIDEO_PATH" ]]; then
  echo "用法: adaptive_frames.sh <video_path>" >&2
  exit 1
fi

if [[ ! -f "$VIDEO_PATH" ]]; then
  echo "视频文件不存在：$VIDEO_PATH" >&2
  exit 1
fi

# 获取视频时长（秒）
# 优先使用 ffprobe（ffmpeg 套件），不可用时退回到 mediainfo
DURATION=""

if command -v ffprobe >/dev/null 2>&1; then
  DURATION=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$VIDEO_PATH" 2>/dev/null || echo "")
elif command -v mediainfo >/dev/null 2>&1; then
  DURATION=$(mediainfo --Output="General;%Duration%" "$VIDEO_PATH" 2>/dev/null || echo "")
  # mediainfo 返回毫秒，转为秒
  if [[ "$DURATION" =~ ^[0-9]+$ ]]; then
    DURATION=$((DURATION / 1000))
  fi
fi

if [[ -z "$DURATION" || ! "$DURATION" =~ ^[0-9]+\.?[0-9]*$ ]]; then
  # 无法获取时长，使用 > 60s 的默认值
  echo "8:15.0"
  exit 0
fi

# 取整
DURATION_INT=$(printf "%.0f" "$DURATION")

# 帧数自适应规则
if [[ "$DURATION_INT" -lt 30 ]]; then
  # 短视频 < 30s
  echo "3:10.0"
elif [[ "$DURATION_INT" -le 60 ]]; then
  # 中视频 30s-60s
  echo "6:10.0"
else
  # 长视频 > 60s
  echo "8:15.0"
fi
