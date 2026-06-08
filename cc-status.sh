#!/bin/bash
# Claude Code 红绿灯：从 hook 的 stdin JSON 取 session_id + cwd，
# 通过 hammerspoon:// URL 驱动 Hammerspoon 圆点（不用 hs CLI，避免 ipc 回调报错弹 Console）。
# hook 调用： bash cc-status.sh red|green|yellow|remove

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"
[ -z "$sid" ] && sid="default"
title=$(basename "$cwd" 2>/dev/null)

enc() { printf '%s' "$1" | jq -sRr @uri; }   # URL 编码（title 可能含空格/中文）

open -g "hammerspoon://cc?sid=$(enc "$sid")&st=$1&title=$(enc "$title")"
exit 0
