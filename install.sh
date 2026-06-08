#!/usr/bin/env bash
# 🚦 Claude Code 红绿灯 —— 一键安装（macOS）
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HSDIR="$HOME/.hammerspoon"
SET="$HOME/.claude/settings.json"

echo "🚦 Claude Code 红绿灯 安装开始"

# ---- [1/5] Hammerspoon ----
echo "==> [1/5] 检查 Hammerspoon"
if [ ! -d "/Applications/Hammerspoon.app" ]; then
  if command -v brew >/dev/null 2>&1; then
    echo "    安装中（brew install --cask hammerspoon）..."
    brew install --cask hammerspoon
  else
    echo "    ❌ 未检测到 Homebrew。请先手动安装 Hammerspoon: https://www.hammerspoon.org/ ，再重跑本脚本。"
    exit 1
  fi
else
  echo "    已安装 ✅"
fi

# ---- jq 依赖 ----
if ! command -v jq >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then echo "==> 安装 jq"; brew install jq
  else echo "    ❌ 需要 jq 来合并 settings.json，请先安装 jq。"; exit 1; fi
fi

# ---- [2/5] 部署脚本 ----
echo "==> [2/5] 部署脚本到 ~/.hammerspoon"
mkdir -p "$HSDIR"
cp "$DIR/cc-traffic-light.lua" "$HSDIR/cc-traffic-light.lua"
cp "$DIR/cc-status.sh"         "$HSDIR/cc-status.sh"
echo "    cc-traffic-light.lua + cc-status.sh ✅"

# ---- [3/5] 接入 Hammerspoon init.lua（不覆盖现有配置）----
echo "==> [3/5] 接入 ~/.hammerspoon/init.lua"
touch "$HSDIR/init.lua"
if ! grep -qF "cc-traffic-light.lua" "$HSDIR/init.lua"; then
  printf '\n-- Claude Code 红绿灯\ndofile(hs.configdir .. "/cc-traffic-light.lua")\n' >> "$HSDIR/init.lua"
  echo "    已追加加载行 ✅"
else
  echo "    加载行已存在，跳过 ✅"
fi

# ---- [4/5] 接入 Claude Code hooks（幂等）----
echo "==> [4/5] 接入 Claude Code hooks (~/.claude/settings.json)"
mkdir -p "$(dirname "$SET")"
[ -f "$SET" ] || echo '{}' > "$SET"
cp "$SET" "$SET.cc-bak"
SCRIPT="$HOME/.hammerspoon/cc-status.sh"
jq --arg s "$SCRIPT" '
  .hooks = (.hooks // {})
  | .hooks |= with_entries(.value |= map(select(((.hooks[0].command // "") | test("cc-status|Hammerspoon")) | not)))
  | .hooks.SessionStart     = ((.hooks.SessionStart // [])     + [{"hooks":[{"type":"command","command":"open -g -a Hammerspoon","timeout":5,"async":true}]}])
  | .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{"hooks":[{"type":"command","command":("bash "+$s+" red"),"timeout":3,"async":true}]}])
  | .hooks.Notification     = ((.hooks.Notification // [])     + [{"hooks":[{"type":"command","command":("bash "+$s+" yellow"),"timeout":3,"async":true}]}])
  | .hooks.Stop             = ((.hooks.Stop // [])             + [{"hooks":[{"type":"command","command":("bash "+$s+" green"),"timeout":3,"async":true}]}])
  | .hooks.SessionEnd       = ((.hooks.SessionEnd // [])       + [{"hooks":[{"type":"command","command":("bash "+$s+" remove"),"timeout":3,"async":true}]}])
' "$SET" > "$SET.tmp"
if jq -e . "$SET.tmp" >/dev/null 2>&1; then
  mv "$SET.tmp" "$SET"
  echo "    hooks 已接入（原文件备份: settings.json.cc-bak）✅"
else
  rm -f "$SET.tmp"; echo "    ❌ 合并失败，已保留原 settings.json。"; exit 1
fi

# ---- [5/5] 启动 ----
echo "==> [5/5] 启动 Hammerspoon（后台，不弹 Console）"
open -g -a Hammerspoon || true

cat <<'EOF'

✅ 安装完成！

⚠️  最后手动一步（拖动功能需要，只需一次）：
    系统设置 › 隐私与安全性 › 辅助功能 › 打开 Hammerspoon 开关，
    然后退出并重新打开 Hammerspoon 让权限生效。

完成后回到 Claude Code 发条消息试试：
    右上角会出现状态灯 🔴→🟢，跑完亮绿灯 + 提示音 + 屏幕边缘呼吸绿光。
EOF
