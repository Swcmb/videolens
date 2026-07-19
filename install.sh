#!/usr/bin/env bash
# VideoLens Skill 仓库一键安装脚本
# 安装 SDK 依赖 + 复制技能目录到三生态目标路径
# 退出码：0 成功 / 1 依赖缺失 / 2 uv sync 失败 / 3 复制失败 / 4 校验失败

set -euo pipefail

# 定位仓库根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SKILL_NAME="videolens"
SKILL_SRC="$SCRIPT_DIR/skills/$SKILL_NAME"

# === 加载 .env 配置文件（如果存在） ===
# .env 文件由用户基于 .env.example 创建，包含 API key 等敏感信息
# .env 已被 .gitignore 忽略，不会被提交
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
  echo "  已加载 .env 配置文件"
fi

echo "=== VideoLens Skill 安装开始 ==="
echo "仓库根目录：$SCRIPT_DIR"
echo ""

# === 步骤 1：检测 Python 与 uv ===
echo "[1/5] 检测依赖..."

if ! command -v python3 >/dev/null 2>&1; then
  echo "错误：python3 未找到" >&2
  echo "  Python >= 3.12 required" >&2
  exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "0.0")
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

if [[ "$PYTHON_MAJOR" -lt 3 ]] || { [[ "$PYTHON_MAJOR" -eq 3 ]] && [[ "$PYTHON_MINOR" -lt 12 ]]; }; then
  echo "错误：Python >= 3.12 required, found $PYTHON_VERSION" >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "错误：uv 未找到" >&2
  echo "  Install: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi

echo "  Python: $PYTHON_VERSION"
echo "  uv: $(uv --version)"
echo ""

# === 步骤 2：uv sync 安装 SDK 依赖 ===
echo "[2/5] 安装 SDK 依赖（uv sync --extra capture --extra mcp）..."

if ! uv sync --extra capture --extra mcp 2>&1; then
  echo "错误：uv sync 失败" >&2
  echo "  请检查网络与 pyproject.toml" >&2
  exit 2
fi

echo "  SDK 依赖安装完成"
echo ""

# === 步骤 3：下载 Playwright 浏览器二进制（用于抖音捕获） ===
echo "[3/5] 下载 Playwright chromium（用于抖音捕获）..."

if uv run playwright install chromium 2>&1; then
  echo "  Playwright chromium 下载完成"
else
  echo "警告：Playwright chromium 下载失败（不影响其他平台分析）" >&2
  echo "  抖音分析时如需使用，请手动运行：uv run playwright install chromium" >&2
fi
echo ""

# === 步骤 4：复制技能目录到三生态目标路径 ===
echo "[4/5] 复制技能目录到三生态目标路径..."

copy_skill_to() {
  local target_dir="$1"
  local label="$2"
  local target_path="$target_dir/$SKILL_NAME"

  if [[ ! -d "$target_dir" ]] && ! mkdir -p "$target_dir" 2>/dev/null; then
    echo "  [$label] 跳过：无法创建目录 $target_dir"
    return 0
  fi

  # 幂等：先清理旧目标
  if [[ -d "$target_path" ]] || [[ -L "$target_path" ]]; then
    rm -rf "$target_path"
  fi

  if cp -r "$SKILL_SRC" "$target_path"; then
    echo "  [$label] 已复制到 $target_path"
  else
    echo "  [$label] 错误：复制失败" >&2
    return 1
  fi
  return 0
}

# Trae IDE
copy_skill_to "/data/user/skills" "Trae IDE" || exit 3

# Hermes Agent（条件性）
if [[ -n "${HERMES_SKILLS_DIR:-}" ]]; then
  copy_skill_to "$HERMES_SKILLS_DIR" "Hermes Agent" || exit 3
else
  echo "  [Hermes Agent] 跳过：HERMES_SKILLS_DIR 未设置"
fi

# Anthropic 通用
copy_skill_to "$HOME/.skills" "Anthropic" || exit 3

echo ""

# === 步骤 5：校验 videolens 可执行 ===
echo "[5/5] 校验 videolens 命令..."

# typer 子命令模式：使用 "version" 而非 "--version"
# 三级回退：PATH → uv run → .venv/bin
if command -v videolens >/dev/null 2>&1; then
  VERSION=$(videolens version 2>&1) || {
    echo "错误：videolens version 调用失败" >&2
    exit 4
  }
elif uv run videolens version >/dev/null 2>&1; then
  VERSION=$(uv run videolens version 2>&1)
elif [[ -x "$SCRIPT_DIR/.venv/bin/videolens" ]]; then
  VERSION=$("$SCRIPT_DIR/.venv/bin/videolens" version 2>&1) || {
    echo "错误：.venv/bin/videolens version 调用失败" >&2
    exit 4
  }
  echo "  提示：videolens 未在 PATH 中，可直接使用 $SCRIPT_DIR/.venv/bin/videolens" >&2
else
  echo "错误：videolens 命令未找到" >&2
  echo "  请运行 'uv sync' 后重试，或检查 PATH 是否含 ~/.local/bin" >&2
  exit 4
fi

echo "  $VERSION"
echo ""

# === 完成 ===
echo "=== 安装完成 ==="
echo ""
echo "下一步："
echo "  1. 设置环境变量（参考 skills/$SKILL_NAME/SKILL.md）"
echo "  2. 运行分析：bash skills/$SKILL_NAME/scripts/analyze.sh /path/to/video.mp4"
echo "  3. 或直接调用：videolens analyze /path/to/video.mp4 --prompt '...' --mode general"
echo ""
exit 0
