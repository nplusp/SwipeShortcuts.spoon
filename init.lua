--- === SwipeShortcuts ===
---
--- Option + three-finger swipes:
--- ↑ => ⌘T - new tab
--- ↓ => ⌘W - close tab
--- ← => ⌘⇧[ - previous tab
--- → => ⌘⇧] - next tab

local obj = {}
obj.__index = obj
obj.name = "SwipeShortcuts"
obj.version = "0.1"
obj.author = "Mikita Pridorozhko"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/nplusp/SwipeShortcuts.spoon"
obj.logger = hs.logger.new('SwipeShortcuts','info')

-- Config
obj.threshold = 10
obj.velThreshold = 1 -- summed delta over last 3 frames for early trigger
obj.shortcutUp = {{'cmd'}, hs.keycodes.map['t']}
obj.shortcutDn = {{'cmd'}, hs.keycodes.map['w']}
obj.shortcutLt = {{'cmd', 'shift'}, hs.keycodes.map[']']}
obj.shortcutRt = {{'cmd', 'shift'}, hs.keycodes.map['[']}
obj.requireModifier = true
obj.showAlert = false
-- optional table-set of allowed application names; empty/nil = any
-- obj.appWhitelist = { ["Google Chrome"] = true, ["Firefox"] = true }
obj.appWhitelist = nil

-- Cache frequently used values
local watcher = nil      -- scrollWheel watcher (created under Alt)
local flagsWatcher = nil -- flagsChanged watcher (follows Alt)
local altActive = false
-- Separate accumulators for vertical (Y) and horizontal (X)
local accumY = 0
local accumX = 0
local handled = false -- whether shortcut already triggered for current gesture
local keyStroke = hs.eventtap.keyStroke -- fallback for string keys
local alert = hs.alert.show
local abs = math.abs

-- Spoon directory (for config and path watcher)
local spoonDir = (debug.getinfo(1, "S").source:match("^@(.*/)") or "")

-- External JSON config support
local cfg = hs.json.read(spoonDir .. "config.json")
if cfg then
  for k,v in pairs(cfg) do obj[k] = v end
end

-- Preserve baseline thresholds for power-profiles
local baseThreshold   = obj.threshold
local baseVelThreshold = obj.velThreshold

-- Adaptive threshold variables
local adaptiveAvg = obj.threshold
local function adaptThreshold(len)
  adaptiveAvg = adaptiveAvg * 0.8 + len * 0.2 -- EMA α=0.2
  obj.threshold     = math.max(5,  adaptiveAvg * 0.7)
  obj.velThreshold  = math.max(1,  obj.threshold / 2)
end

-- Power-profile: tweak thresholds on battery
local function applyPowerProfile()
  local onBattery = (hs.battery.powerSource() == "Battery Power")
  if onBattery then
    obj.threshold    = baseThreshold   * 1.2
    obj.velThreshold = baseVelThreshold * 1.2
  else
    obj.threshold    = baseThreshold
    obj.velThreshold = baseVelThreshold
  end
end

local battWatcher = hs.battery.watcher.new(applyPowerProfile):start()
applyPowerProfile()

-- Raw CGEvent shortcuts (pre-built)
local fireUp, fireDn, fireLt, fireRt = nil, nil, nil, nil
local function buildFire(mods, key)
  if type(key) == "number" then
    local down = hs.eventtap.event.newKeyEvent(mods, key, true)
    local up   = hs.eventtap.event.newKeyEvent(mods, key, false)
    return function()
      down:post(); up:post()
    end
  else -- fallback to keyStroke for string keys
    return function() keyStroke(mods, key, 0) end
  end
end

-- Path watcher for auto-reload
local pw = hs.pathwatcher.new(spoonDir, function(files)
  obj.logger.i("Spoon files changed – reloading")
  hs.timer.doAfter(0.5, function() obj:stop(); obj:start() end)
end):start()

-- Use documented property constants instead of magic numbers
local props = hs.eventtap.event.properties
local AXIS_Y  = props.scrollWheelEventDeltaAxis1     -- 96
local AXIS_X  = props.scrollWheelEventDeltaAxis2     -- 97
local PHASE   = props.scrollWheelEventScrollPhase    -- 99
local MOMENT  = props.scrollWheelEventMomentumPhase  -- 123

-- Direction locking and velocity buffers
local dirLocked = nil -- 'vertical' | 'horizontal' | nil
local velY, velX = {0,0,0}, {0,0,0}
local velIdx, VEL_N = 1, 3

-- Pre-cache shortcuts to avoid table lookups
local cmdUp, keyUp, cmdDn, keyDn, cmdLt, keyLt, cmdRt, keyRt

local function isAllowedApp()
  if not obj.appWhitelist then return true end
  local win = hs.window.frontmostWindow()
  if not win then return false end
  local name = win:application():name()
  return obj.appWhitelist[name] == true
end

local function handle(e)
  -- app filter
  if not isAllowedApp() then return false end
  -- Ignore momentum/inertial scroll events (suggestion #2)
  if e:getProperty(MOMENT) ~= 0 then return false end

  local phase = e:getProperty(PHASE)

  if phase == 1 then
    -- Gesture began
    accumY, accumX = 0, 0
    handled = false
    dirLocked = nil
    velY = {0,0,0}
    velX = {0,0,0}
    velIdx = 1
  elseif phase == 4 then
    -- Gesture ended
    if not handled then
      local absY, absX = abs(accumY), abs(accumX)
      if absY > absX and absY > obj.threshold then
        -- Vertical gesture (fallback)
        if accumY < 0 then
          fireUp()
          if obj.showAlert then alert("↑", 0.3) end
        else
          fireDn()
          if obj.showAlert then alert("↓", 0.3) end
        end
        adaptThreshold(absY)
      elseif absX > obj.threshold then
        -- Horizontal gesture (fallback)
        if accumX < 0 then
          fireLt()
          if obj.showAlert then alert("←", 0.3) end
        else
          fireRt()
          if obj.showAlert then alert("→", 0.3) end
        end
        adaptThreshold(absX)
      end
    end
    accumY = 0
    accumX = 0
    handled = false
  else
    -- Ongoing gesture – accumulate deltas
    local deltaY = e:getProperty(AXIS_Y) or 0
    local deltaX = e:getProperty(AXIS_X) or 0
    if deltaY then accumY = accumY + deltaY end
    if deltaX then accumX = accumX + deltaX end

    -- Update velocity buffers
    velY[velIdx] = deltaY
    velX[velIdx] = deltaX
    velIdx = velIdx % VEL_N + 1

    -- Calculate summed velocity
    local sumVelY = abs(velY[1] + velY[2] + velY[3])
    local sumVelX = abs(velX[1] + velX[2] + velX[3])

    -- Determine direction lock if not yet set
    if not dirLocked then
      if (sumVelY > sumVelX and sumVelY > obj.velThreshold) or (abs(accumY) > abs(accumX) and abs(accumY) > obj.threshold) then
        dirLocked = 'vertical'
      elseif (sumVelX > obj.velThreshold) or (abs(accumX) > obj.threshold) then
        dirLocked = 'horizontal'
      end
    end

    -- Early trigger if locked and threshold passed
    if not handled and dirLocked then
      if dirLocked == 'vertical' and abs(accumY) > obj.threshold then
        if accumY < 0 then
          fireUp()
          if obj.showAlert then alert("↑", 0.3) end
        else
          fireDn()
          if obj.showAlert then alert("↓", 0.3) end
        end
        handled = true; adaptThreshold(dirLocked=='vertical' and abs(accumY) or abs(accumX)); accumY, accumX = 0, 0
      elseif dirLocked == 'horizontal' and abs(accumX) > obj.threshold then
        if accumX < 0 then
          fireLt()
          if obj.showAlert then alert("←", 0.3) end
        else
          fireRt()
          if obj.showAlert then alert("→", 0.3) end
        end
        handled = true; adaptThreshold(dirLocked=='vertical' and abs(accumY) or abs(accumX)); accumY, accumX = 0, 0
      end
    end
  end

  -- Debug output (uncomment log:setLogLevel('df') to see)
  -- obj.logger.df("dX=%d dY=%d vX=%d vY=%d dir=%s handled=%s", accumX, accumY, sumVelX, sumVelY, tostring(dirLocked), tostring(handled))
  return false
end

function obj:start()
  -- Stop existing watchers if any (hot reload safety)
  if watcher then watcher:stop(); watcher = nil end
  if flagsWatcher then flagsWatcher:stop(); flagsWatcher = nil end
  if pw then pw:stop(); pw = nil end
  if battWatcher then battWatcher:stop(); battWatcher = nil end

  -- Cache shortcut values
  cmdUp = obj.shortcutUp[1]
  keyUp = obj.shortcutUp[2]
  cmdDn = obj.shortcutDn[1]
  keyDn = obj.shortcutDn[2]
  cmdLt = obj.shortcutLt[1]
  keyLt = obj.shortcutLt[2]
  cmdRt = obj.shortcutRt[1]
  keyRt = obj.shortcutRt[2]

  -- Build raw-event fire functions
  fireUp = buildFire(cmdUp, keyUp)
  fireDn = buildFire(cmdDn, keyDn)
  fireLt = buildFire(cmdLt, keyLt)
  fireRt = buildFire(cmdRt, keyRt)

  local eventTypes = hs.eventtap.event.types

  if obj.requireModifier then
    -- Lazy: create scroll watcher only while Alt held
    flagsWatcher = hs.eventtap.new({eventTypes.flagsChanged}, function(e)
      local flags = e:getFlags()
      if flags.alt and not altActive then
        altActive = true
        if not watcher then
          watcher = hs.eventtap.new({eventTypes.scrollWheel}, handle):start()
        end
      elseif (not flags.alt) and altActive then
        altActive = false
        if watcher then watcher:stop(); watcher = nil end
      end
      return false
    end):start()
    hs.notify.show("SwipeShortcuts", "Ready", "Opt+3-finger swipe (hold ⌥)")
  else
    -- No modifier required – always listen
    watcher = hs.eventtap.new({eventTypes.scrollWheel}, handle):start()
    hs.notify.show("SwipeShortcuts", "Ready", "3-finger swipe active")
  end

  return self
end

function obj:stop()
  if watcher then watcher:stop(); watcher = nil end
  if flagsWatcher then flagsWatcher:stop(); flagsWatcher = nil end
  if pw then pw:stop(); pw = nil end
  if battWatcher then battWatcher:stop(); battWatcher = nil end
  altActive = false
  return self
end

return obj