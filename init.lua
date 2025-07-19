--- === SwipeShortcuts ===
---
--- Option + three-finger swipes:
--- ↑ => ⌘t - new tab
--- ↓ => ⌘w - close tab
--- ← => ⌘⇧[ - previous tab
--- → => ⌘⇧] - next tab

local obj = {}
obj.__index = obj
obj.name = "SwipeShortcuts"
obj.version = "0.1"
obj.author = "Mikita Pridorozhko"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Config
obj.threshold = 80
obj.shortcutUp = {{'cmd'}, hs.keycodes.map['t']}
obj.shortcutDn = {{'cmd'}, hs.keycodes.map['w']}
obj.shortcutLt = {{'cmd', 'shift'}, hs.keycodes.map[']']}
obj.shortcutRt = {{'cmd', 'shift'}, hs.keycodes.map['[']}
obj.requireModifier = true
obj.showAlert = false

-- Cache frequently used values
local watcher = nil
-- Separate accumulators for vertical (Y) and horizontal (X)
local accumY = 0
local accumX = 0
local handled = false -- whether shortcut already triggered for current gesture
local keyStroke = hs.eventtap.keyStroke
local alert = hs.alert.show
local abs = math.abs

-- Pre-cache shortcuts to avoid table lookups
local cmdUp, keyUp, cmdDn, keyDn, cmdLt, keyLt, cmdRt, keyRt

local function handle(e)
  -- Fast exit if modifier required but not pressed
  if obj.requireModifier and not e:getFlags().alt then
    return false
  end

  local phase = e:getProperty(99)

  if phase == 1 then
    -- Gesture began
    accumY = 0
    accumX = 0
    handled = false
  elseif phase == 4 then
    -- Gesture ended
    if not handled then
      local absY, absX = abs(accumY), abs(accumX)
      if absY > absX and absY > obj.threshold then
        -- Vertical gesture (fallback)
        if accumY < 0 then
          keyStroke(cmdUp, keyUp, 0)
          if obj.showAlert then alert("↑", 0.3) end
        else
          keyStroke(cmdDn, keyDn, 0)
          if obj.showAlert then alert("↓", 0.3) end
        end
      elseif absX > obj.threshold then
        -- Horizontal gesture (fallback)
        if accumX < 0 then
          keyStroke(cmdLt, keyLt, 0)
          if obj.showAlert then alert("←", 0.3) end
        else
          keyStroke(cmdRt, keyRt, 0)
          if obj.showAlert then alert("→", 0.3) end
        end
      end
    end
    accumY = 0
    accumX = 0
    handled = false
  else
    -- Ongoing gesture – accumulate deltas
    local deltaY = e:getProperty(96) -- Axis 1 (vertical)
    local deltaX = e:getProperty(97) -- Axis 2 (horizontal)
    if deltaY then accumY = accumY + deltaY end
    if deltaX then accumX = accumX + deltaX end

    if not handled then
      local absY, absX = abs(accumY), abs(accumX)
      if (absY > absX and absY > obj.threshold) or (absX > obj.threshold) then
        -- We've crossed threshold during gesture, fire once
        if absY > absX then
          if accumY < 0 then
            keyStroke(cmdUp, keyUp, 0)
            if obj.showAlert then alert("↑", 0.3) end
          else
            keyStroke(cmdDn, keyDn, 0)
            if obj.showAlert then alert("↓", 0.3) end
          end
        else
          if accumX < 0 then
            keyStroke(cmdLt, keyLt, 0)
            if obj.showAlert then alert("←", 0.3) end
          else
            keyStroke(cmdRt, keyRt, 0)
            if obj.showAlert then alert("→", 0.3) end
          end
        end
        handled = true
        accumY = 0 -- accumY - obj.threshold * 2
        accumX = 0 -- accumX - obj.threshold * 2
      end
    end
  end

  return false
end

function obj:start()
  if watcher then self:stop() end

  -- Cache shortcut values
  cmdUp = obj.shortcutUp[1]
  keyUp = obj.shortcutUp[2]
  cmdDn = obj.shortcutDn[1]
  keyDn = obj.shortcutDn[2]
  cmdLt = obj.shortcutLt[1]
  keyLt = obj.shortcutLt[2]
  cmdRt = obj.shortcutRt[1]
  keyRt = obj.shortcutRt[2]

  watcher = hs.eventtap.new({hs.eventtap.event.types.scrollWheel}, handle):start()

  if obj.requireModifier then
    hs.notify.show("SwipeShortcuts", "Ready", "Option + 3-finger swipe")
  end

  return self
end

function obj:stop()
  if watcher then
    watcher:stop()
    watcher = nil
  end
  return self
end

return obj