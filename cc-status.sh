#!/bin/bash
# Claude Code 红绿灯：从 hook 的 stdin JSON 取 session_id + cwd，驱动 Hammerspoon 圆点。
# hook 调用： bash cc-status.sh red|green|yellow|remove
HS='/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs'

input=$(cat)                                                   # stdin 只能读一次，先存下来
sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"
[ -z "$sid" ] && sid="default"
title=$(basename "$cwd" 2>/dev/null | tr -d "'\"\\\\")          # 工作目录名做标题，去掉危险字符

if [ "$1" = "remove" ]; then
  "$HS" -c "removeCC('$sid')" >/dev/null 2>&1
else
  "$HS" -c "setCC('$sid','$1','$title')" >/dev/null 2>&1
fi
exit 0
