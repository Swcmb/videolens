#!/usr/bin/env bash
# VideoLens 环境校验脚本
# 检查必需环境变量、关键二进制、Whisper 模型目录
# 用法：validate_env.sh
# 退出码：0 全部就绪 / 1 缺失项
#
# 自动加载顺序（找到第一个即停止）：
#   1. 仓库根目录的 .env 文件（推荐：cp .env.example .env 后填入实际值）
#   2. 当前 shell 已 export 的环境变量（向后兼容）

set -euo pipefail

# === 自动加载 .env 配置文件 ===
# 定位仓库根目录（脚本位于 skills/videolens/scripts/）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

if [[ -f "$ENV_FILE" ]]; then
  # 仅当变量未在当前 shell 设置时才加载 .env 中的值（不覆盖现有环境变量）
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

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
    echo "  请参考 $SCRIPT_DIR/../references/whisper-setup.md 下载模型" >&2
  elif [[ -z "$(ls -A "$VIDEOLENS_WHISPER_DIR" 2>/dev/null)" ]]; then
    MISSING+=("WHISPER_DIR_EMPTY")
    echo "Whisper 目录为空：$VIDEOLENS_WHISPER_DIR" >&2
    echo "  请参考 $SCRIPT_DIR/../references/whisper-setup.md 下载模型文件" >&2
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
