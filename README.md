# 🚦 Claude Code 红绿灯

给 Claude Code 加一个**桌面状态灯**：每个会话一颗发光小球浮在屏幕角落，实时显示它在「跑 / 等你确认 / 完成」，带正计时和醒目的完成提醒。

## 功能
- 🔴 进行中（呼吸）/ 🟡 待确认（慢闪）/ 🟢 完成（脉冲）
- **多会话**各一颗灯，竖排；关闭会话自动消失
- **hover** 看「项目名 · 状态 · 用时」
- **正计时**：发消息开始走表，完成时定格显示本次用时
- **完成提醒**：Glass 提示音 + **所有屏幕**边缘虚化绿光呼吸 30 秒（点任意灯 / 发新消息即取消）
- **拖动**整列移动、记住位置；**点灯**跳回 Claude

## 依赖（macOS）
- [Hammerspoon](https://www.hammerspoon.org/) —— 画悬浮灯（install.sh 会自动装，需 Homebrew）
- jq —— 合并 settings.json（install.sh 会自动装）

## 安装
```bash
cd cc-traffic-light
./install.sh
```
然后**手动授权一次**（拖动功能需要）：
系统设置 › 隐私与安全性 › 辅助功能 › 勾选 **Hammerspoon** → 退出重开 Hammerspoon。

装完在 Claude Code 里发条消息：右上角出现状态灯，跑完亮绿灯 + 边缘呼吸。

## 它改了哪些文件
| 文件 | 改动 |
|------|------|
| `~/.hammerspoon/cc-traffic-light.lua` | 新增（红绿灯逻辑） |
| `~/.hammerspoon/cc-status.sh` | 新增（从 hook 取 session_id/cwd） |
| `~/.hammerspoon/init.lua` | 末尾**追加一行** `dofile(...)`（不覆盖你现有配置） |
| `~/.claude/settings.json` | hooks 里加 5 条（SessionStart/UserPromptSubmit/Notification/Stop/SessionEnd），合并前备份为 `settings.json.cc-bak` |

## 卸载
1. 删 `~/.hammerspoon/cc-traffic-light.lua` 和 `~/.hammerspoon/cc-status.sh`
2. 从 `~/.hammerspoon/init.lua` 删掉 `dofile(... cc-traffic-light.lua)` 那行
3. 从 `~/.claude/settings.json` 的 hooks 删掉含 `cc-status` / `open -a Hammerspoon` 的条目（或直接还原 `settings.json.cc-bak`）

## 说明
- 安装**幂等**：重复跑 `install.sh` 不会重复加 hook。
- **不破坏**已有 Hammerspoon 配置（红绿灯逻辑独立成文件，init.lua 只追加一行加载）。
- `hs` 命令行路径写死为标准安装位置 `/Applications/Hammerspoon.app/...`。
- 自定义：调色 / 大小 / 呼吸时长等都在 `cc-traffic-light.lua` 顶部，改完菜单栏 Hammerspoon → Reload Config。
