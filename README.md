# SwipeShortcuts.spoon

Option + three-finger swipe gestures mapped to browser tab shortcuts.

| Gesture | Default Hotkey |
|---------|----------------|
| ↑       | `⌘T` – New tab |
| ↓       | `⌘W` – Close tab |
| ←       | `⌘⇧[` – Previous tab |
| →       | `⌘⇧]` – Next tab |

## Features

* **Lazy activation** – watcher runs only while ⌥ is held (can be disabled).
* **Direction lock & velocity trigger** – fast response with zero false positives.
* **Adaptive threshold** – auto-tunes sensitivity to your swipe style.
* **Power profile** – raises thresholds on battery to avoid accidental triggers.
* **Raw-event shortcuts** – CGEvent keycodes are prebuilt once, minimal overhead.
* **App whitelist** – works in Chrome by default; easily extendable to other apps.
* **External `config.json`** – edit & save the file and the Spoon auto-reloads.

## Installation

Get the Hammerspoon:

```bash
brew install hammerspoon --cask
```

Get the Spoon:

```bash
mkdir -p ~/.hammerspoon/Spoons
cd ~/.hammerspoon/Spoons
git clone https://github.com/nplusp/SwipeShortcuts.spoon
```

Add the Spoon to your `init.lua`:

```lua
-- init.lua
hs.loadSpoon("SwipeShortcuts")
spoon.SwipeShortcuts:start()
```

### Optional Tweaks

```lua
local S = spoon.SwipeShortcuts
S.threshold       = 15   -- accumulate delta
S.velThreshold    = 30   -- 3-frame velocity
S.requireModifier = false
S.appWhitelist    = { ["Google Chrome"] = true, ["Visual Studio Code"] = true }
S.showAlert       = false
S:stop():start()  -- apply changes
```

Alternatively drop a `config.json` near `init.lua` of the Spoon:

```json
{
  "threshold":        20,
  "velThreshold":     50,
  "requireModifier":  true,
  "appWhitelist": { "Safari": true, "Google Chrome": true }
}
```

## Config Fields

* `threshold` (number) – Δ required to fire, adaptive base.
* `velThreshold` (number) – summed velocity of last 3 frames.
* `requireModifier` (bool) – if `true`, hold ⌥ to enable watcher.
* `showAlert` (bool) – tiny HUD arrow on trigger.
* `appWhitelist` (table or nil) – `{ ["AppName"] = true }`; `nil` ⇒ always.

## Author & License

© 2025 Mikita Pridorozhko – MIT, see [LICENSE](LICENSE).
