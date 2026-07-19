#!/usr/bin/env bash
# VideoLens 环境校验脚本
# 检查必需环境变量、关键二进制、Whisper 模型目录
# 用法：validate_env.sh
# 退出码：0 全部就绪 / 1 缺失项

set -euo pipefail

MISSING=()

# === 环境变量校验 ===
check_var() {
  local var="$1"
  local desc="$2"
  local example="$3"
  if [[ -z "${!var:-}" ]]; then
    MISSING+=("$var")
    echo "缺失环境变量：$var" >&2
    echo "  说明：$desc" >&2
    echo "  示例：export $var=\"$example\"" >&2
  fi
}

check_var "OPENAI_API_KEY" "OpenAI 兼容 API 密钥" "sk-xxx"
check_var "OPENAI_BASE_URL" "API 端点" "https://token.sensenova.cn/v1"
check_var "VIDEOLENS_MODEL_VISION" "视觉模型" "sensenova-6.7-flash-lite"
check_var "VIDEOLENS_MODEL_SYNTHESIZE" "综合模型" "sensenova-6.7-flash-lite"
check_var "VIDEOLENS_WHISPER_DIR" "Whisper 模型目录（指向模型文件直接父目录）" "/home/admin/.cache/whisper/tiny"

# === 关键二进制校验 ===
check_bin() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    MISSING+=("$bin")
    echo "缺失二进制：$bin 未在 PATH" >&2
    echo "  请运行 install.sh 安装" >&2
  fi
}

check_bin "uv"
check_bin "videolens"

# === Whisper 模型目录校验 ===
if [[ -n "${VIDEOLENS_WHISPER_DIR:-}" ]]; then
  if [[ ! -d "$VIDEOLENS_WHISPER_DIR" ]]; then
    MISSING+=("WHISPER_DIR_NOT_FOUND")
    echo "Whisper 目录不存在：$VIDEOLENS_WHISPER_DIR" >&2
    echo "  请参考 references/whisper-setup.md 下载模型" >&2
  elif [[ -z "$(ls -A "$VIDEOLENS_WHISPER_DIR" 2>/dev/null)" ]]; then
    MISSING+=("WHISPER_DIR_EMPTY")
    echo "Whisper 目录为空：$VIDEOLENS_WHISPER_DIR" >&2
    echo "  请参考 references/whisper-setup.md 下载模型文件" >&2
  fi
fi

# === 汇总 ===
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "" >&2
  echo "环境校验失败，共 ${#MISSING[@]} 项缺失" >&2
  exit 1
fi

echo "环境校验通过"
exit 0
