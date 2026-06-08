-- ===== Claude Code 多会话红绿灯 2.5（完成=全屏幕边缘呼吸30s，点灯/发消息取消）=====
-- 颜色： hs -c 'setCC("<sid>","red"/"green"/"yellow","<title>")' / removeCC("<sid>")
-- 交互：hover=项目·状态·用时；点灯=取消边缘提醒+跳回Claude；拖动=移动整列
-- 完成：🔊完成音 + 所有屏幕边缘虚化绿光持续呼吸 30 秒（点任意灯 / 发新消息即取消）

local DOT, GAP, MARGIN = 34, 10, 18
local LW, LH = 48, 18
local EDGE_HOLD = 30
local palette = {
  red    = { bright = {red=1.00, green=0.46, blue=0.42}, deep = {red=0.82, green=0.14, blue=0.16} },
  yellow = { bright = {red=1.00, green=0.86, blue=0.45}, deep = {red=0.92, green=0.62, blue=0.06} },
  green  = { bright = {red=0.52, green=0.92, blue=0.60}, deep = {red=0.10, green=0.64, blue=0.32} },
  grey   = { bright = {red=0.72, green=0.74, blue=0.78}, deep = {red=0.42, green=0.44, blue=0.48} },
}
local label = { red = "● 进行中", yellow = "● 待确认", green = "● 已完成", grey = "● 空闲" }

local function wa(c, a) return { red=c.red, green=c.green, blue=c.blue, alpha=a } end
local function norm(sid) if sid == nil or sid == "" then return "default" end return sid end
local function textWidth(s)
  local w = 0
  for _, cp in utf8.codes(s) do w = w + (cp > 127 and 13 or 7) end
  return w
end
local function fmt(sec)
  sec = math.max(0, math.floor(sec))
  if sec < 3600 then return string.format("%d:%02d", math.floor(sec/60), sec%60)
  else return string.format("%d:%02d:%02d", math.floor(sec/3600), math.floor(sec%3600/60), sec%60) end
end

local sf      = hs.screen.primaryScreen():frame()
local anchor  = hs.settings.get("ccAnchor") or { x = sf.x + sf.w - DOT - MARGIN, y = sf.y + MARGIN }
local dots, tlabels, order = {}, {}, {}
local status, titles, starts, spans = {}, {}, {}, {}
local bubbles = {}
local edgeCanvases, edgeUntil, edgeET = {}, 0, 0
local dragging, moved, pressedSid = false, false, nil
local dragOff = { dx = 0, dy = 0 }

local function elapsedOf(sid)
  if spans[sid] then return spans[sid]
  elseif starts[sid] then return os.time() - starts[sid]
  else return nil end
end

local function relayout()
  for i, sid in ipairs(order) do
    local y = anchor.y + (i - 1) * (DOT + GAP)
    if dots[sid]    then dots[sid]:topLeft({ x = anchor.x, y = y }) end
    if tlabels[sid] then tlabels[sid]:topLeft({ x = anchor.x - LW - 4, y = y + (DOT - LH) / 2 }) end
  end
end

local function hideBubble(sid)
  local r = bubbles[sid]
  if r then
    if r.fade then r.fade:stop() end
    if r.timer then r.timer:stop() end
    r.canvas:delete(); bubbles[sid] = nil
  end
end

local function showBubble(sid, text, sticky)
  local dot = dots[sid]; if not dot then return end
  hideBubble(sid)
  local tl = dot:topLeft()
  local W, H = math.max(70, textWidth(text) + 24), 26
  local b = hs.canvas.new({ x = tl.x - W - 10, y = tl.y + (DOT - H) / 2, w = W, h = H })
  b:level(hs.canvas.windowLevels.overlay)
  b:behavior({ "canJoinAllSpaces", "stationary" })
  b:replaceElements(
    { type = "rectangle", action = "fill", roundedRectRadii = { xRadius = 8, yRadius = 8 },
      fillColor = { white = 0.10, alpha = 0.95 } },
    { type = "text", text = text, textColor = { white = 0.97 }, textSize = 12,
      textAlignment = "center", frame = { x = "0%", y = "14%", w = "100%", h = "74%" } }
  )
  b:show()
  local rec = { canvas = b }
  if not sticky then
    rec.timer = hs.timer.doAfter(2.6, function()
      local a = 1.0
      rec.fade = hs.timer.doEvery(0.03, function()
        a = a - 0.1
        if a <= 0 then rec.fade:stop(); b:delete(); if bubbles[sid] == rec then bubbles[sid] = nil end
        else b:alpha(a) end
      end)
    end)
  end
  bubbles[sid] = rec
end

local function hoverText(sid)
  local e = elapsedOf(sid)
  local ts = e and ("   " .. fmt(e)) or ""
  return (titles[sid] or "会话") .. "   " .. (label[status[sid] or "grey"]) .. ts
end

local function updateTimeLabel(sid)
  local c = tlabels[sid]; if not c then return end
  local e = elapsedOf(sid)
  c[1].text = e and fmt(e) or ""
  c[1].textColor = spans[sid] and { red=0.45, green=0.92, blue=0.55, alpha=0.95 } or { white=0.80 }
end

local function pulse(sid)
  local c = dots[sid]; if not c then return end
  local seq, i = { "40%", "46%", "49%", "45%", "41%", "36%" }, 0
  local t
  t = hs.timer.doEvery(0.045, function()
    i = i + 1
    if i > #seq then t:stop(); return end
    if dots[sid] then dots[sid][2].radius = seq[i] end
  end)
end

-- ===== 完成提示：声音 + 全屏幕边缘虚化绿光（持续呼吸，可取消）=====
local function playDone()
  hs.execute("/usr/bin/afplay /System/Library/Sounds/Glass.aiff &")
end

local function buildEdgeForScreen(scr)           -- 单块屏幕的边缘光（鼠标穿透：不设 mouseEvents）
  local f = scr:fullFrame()
  local W, H = f.w, f.h
  local c = hs.canvas.new(f)
  c:level(hs.canvas.windowLevels.overlay)
  c:behavior({ "canJoinAllSpaces", "stationary" })
  for k = 0, 27 do
    local a = 0.55 * (1 - k / 28) ^ 2
    c[k + 1] = {
      type = "rectangle", action = "stroke",
      strokeColor = { red = 0.25, green = 0.95, blue = 0.5, alpha = a },
      strokeWidth = 2.5,
      frame = { x = k * 2, y = k * 2, w = W - 4 * k, h = H - 4 * k },
      roundedRectRadii = { xRadius = 18, yRadius = 18 },
    }
  end
  c:alpha(0)
  return c
end

local function buildEdges()                      -- 每块屏幕建一层
  for _, c in ipairs(edgeCanvases) do c:delete() end
  edgeCanvases = {}
  for _, scr in ipairs(hs.screen.allScreens()) do
    edgeCanvases[#edgeCanvases + 1] = buildEdgeForScreen(scr)
  end
end

local function startEdgeBreath()
  edgeUntil = os.time() + EDGE_HOLD
  edgeET = 0
  for _, c in ipairs(edgeCanvases) do c:show() end
end

local function stopEdgeBreath()
  edgeUntil = 0
  for _, c in ipairs(edgeCanvases) do c:alpha(0); c:hide() end
end

local function makeTimeLabel(sid)
  local t = hs.canvas.new({ x = anchor.x - LW - 4, y = anchor.y + (DOT - LH) / 2, w = LW, h = LH })
  t:level(hs.canvas.windowLevels.overlay)
  t:behavior({ "canJoinAllSpaces", "stationary" })
  t:replaceElements(
    { type = "text", text = "", textColor = { white = 0.80 }, textSize = 11,
      textAlignment = "right", frame = { x = "0%", y = "0%", w = "100%", h = "100%" } }
  )
  t:show()
  return t
end

local function makeDot(sid)
  local c = hs.canvas.new({ x = anchor.x, y = anchor.y, w = DOT, h = DOT })
  c:level(hs.canvas.windowLevels.overlay)
  c:behavior({ "canJoinAllSpaces", "stationary" })
  c:clickActivating(false)
  c:replaceElements(
    { type = "circle", action = "fill", center = { x = "50%", y = "50%" }, radius = "46%",
      fillColor = wa(palette.grey.deep, 0.30) },
    { type = "circle", action = "fill", center = { x = "50%", y = "50%" }, radius = "36%",
      fillGradient = "radial", fillGradientColors = { palette.grey.bright, palette.grey.deep },
      fillGradientCenter = { x = -0.35, y = -0.35 } },
    { type = "circle", action = "fill", center = { x = "40%", y = "36%" }, radius = "12%",
      fillColor = { white = 1, alpha = 0.85 } }
  )
  c:canvasMouseEvents(true, false, true, false)
  c:mouseCallback(function(_, msg)
    if msg == "mouseDown" then
      dragging, moved, pressedSid = true, false, sid
      local m = hs.mouse.absolutePosition()
      dragOff = { dx = m.x - anchor.x, dy = m.y - anchor.y }
    elseif msg == "mouseEnter" then
      if not dragging then showBubble(sid, hoverText(sid), true) end
    elseif msg == "mouseExit" then
      if not dragging then hideBubble(sid) end
    end
  end)
  c:show()
  return c
end

function setCC(sid, st, title)
  sid = norm(sid)
  if not dots[sid] then
    dots[sid] = makeDot(sid)
    tlabels[sid] = makeTimeLabel(sid)
    table.insert(order, sid); relayout()
  end
  status[sid] = st
  if title and title ~= "" then titles[sid] = title end
  if st == "red" then
    starts[sid] = os.time(); spans[sid] = nil
    stopEdgeBreath()
  elseif st == "green" then
    if starts[sid] then spans[sid] = os.time() - starts[sid] end
  end
  local p = palette[st] or palette.grey
  local c = dots[sid]
  c[2].fillGradientColors = { p.bright, p.deep }
  c[1].fillColor = wa(p.deep, 0.30)
  updateTimeLabel(sid)
  if st == "green" then
    pulse(sid)
    showBubble(sid, "✓ 完成  用时 " .. fmt(spans[sid] or 0), false)
    playDone(); startEdgeBreath()
  end
  return st
end

function removeCC(sid)
  sid = norm(sid)
  hideBubble(sid)
  if tlabels[sid] then tlabels[sid]:delete(); tlabels[sid] = nil end
  if dots[sid] then dots[sid]:delete(); dots[sid] = nil end
  status[sid], titles[sid], starts[sid], spans[sid] = nil, nil, nil, nil
  for i, s in ipairs(order) do if s == sid then table.remove(order, i); break end end
  relayout()
end

ccDragTap = hs.eventtap.new(
  { hs.eventtap.event.types.leftMouseDragged, hs.eventtap.event.types.leftMouseUp },
  function(e)
    if not dragging then return false end
    local t = e:getType()
    if t == hs.eventtap.event.types.leftMouseDragged then
      moved = true
      local m = hs.mouse.absolutePosition()
      anchor = { x = m.x - dragOff.dx, y = m.y - dragOff.dy }
      relayout()
    else
      dragging = false
      if moved then
        hs.settings.set("ccAnchor", anchor)
      elseif pressedSid then
        stopEdgeBreath()
        local app = hs.application.get("com.anthropic.claudefordesktop") or hs.application.find("Claude")
        if app then app:activate() end
      end
    end
    return false
  end
)
ccDragTap:start()

local breath = 0
breathTimer = hs.timer.doEvery(0.06, function()
  breath = breath + 0.16
  local s = 0.5 + 0.5 * math.sin(breath)
  for sid, st in pairs(status) do
    local c = dots[sid]
    if c then
      if st == "red" then c[1].fillColor = wa(palette.red.deep, 0.18 + 0.34 * s)
      elseif st == "yellow" then c[1].fillColor = wa(palette.yellow.deep, 0.15 + 0.28 * s) end
    end
  end
end)

clockTimer = hs.timer.doEvery(1, function()
  for sid in pairs(starts) do
    if not spans[sid] then
      updateTimeLabel(sid)
      local b = bubbles[sid]
      if b then b.canvas[2].text = hoverText(sid) end
    end
  end
end)

-- 边缘呼吸（所有屏幕统一驱动）
buildEdges()
edgeTimer = hs.timer.doEvery(0.04, function()
  if os.time() < edgeUntil then
    edgeET = edgeET + 0.04
    local a = 0.22 + 0.5 * (0.5 + 0.5 * math.sin(edgeET * math.pi))
    for _, c in ipairs(edgeCanvases) do c:alpha(a) end
  else
    for _, c in ipairs(edgeCanvases) do
      if c:isShowing() then c:alpha(0); c:hide() end
    end
  end
end)

-- 插拔显示器：重建各屏边缘光，若正在呼吸则继续
screenWatcher = hs.screen.watcher.new(function()
  local active = (os.time() < edgeUntil)
  buildEdges()
  if active then for _, c in ipairs(edgeCanvases) do c:show() end end
end)
screenWatcher:start()

require("hs.ipc")

if hs.accessibilityState() then
  hs.alert.show("🟢 CC 红绿灯 2.5（多屏边缘呼吸）")
end
