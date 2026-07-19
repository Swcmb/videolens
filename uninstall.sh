#!/usr/bin/env bash
# VideoLens Skill 卸载脚本
# 删除三生态目标路径下的 videolens 技能目录
# 注意：不删除 uv sync 安装的 Python 包（避免破坏其他依赖）
# 退出码：0 成功 / 1 删除失败

set -euo pipefail

SKILL_NAME="videolens"
FAILED=0

echo "=== VideoLens Skill 卸载开始 ==="
echo ""

remove_skill_from() {
  local target_dir="$1"
  local label="$2"
  local target_path="$target_dir/$SKILL_NAME"

  if [[ -d "$target_path" ]] || [[ -L "$target_path" ]]; then
    if rm -rf "$target_path"; then
      echo "  [$label] 已删除 $target_path"
    else
      echo "  [$label] 错误：删除失败 $target_path" >&2
      FAILED=1
    fi
  else
    echo "  [$label] 跳过：$target_path 不存在"
  fi
}

echo "[1/3] 删除三生态目标路径下的技能目录..."
echo ""

# Trae IDE
remove_skill_from "/data/user/skills" "Trae IDE"

# Hermes Agent
if [[ -n "${HERMES_SKILLS_DIR:-}" ]]; then
  remove_skill_from "$HERMES_SKILLS_DIR" "Hermes Agent"
else
  echo "  [Hermes Agent] 跳过：HERMES_SKILLS_DIR 未设置"
fi

# Anthropic 通用
remove_skill_from "$HOME/.skills" "Anthropic"

echo ""
echo "[2/3] Python 包保留"
echo "  uv sync 安装的 Python 包未删除（避免破坏其他依赖）"
echo "  如需彻底清理，请手动运行：uv pip uninstall videolens"
echo ""

echo "[3/3] 卸载完成"
echo ""
exit $FAILED
