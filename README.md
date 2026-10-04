<div align="center">

```
 ██████╗ ███████╗ ██████╗ ██╗  ██╗██╗   ██╗███████╗██╗
 ██╔═══██╗██╔════╝██╔════██╗██║ ██╔╝██║   ██║██╔════╝██║
 ██║   ██║█████╗  ██║   ██║█████╔╝ ██║   ██║███████╗██║
 ██║   ██║██╔══╝  ██║   ██║██╔═██╗ ██║   ██║╚════██║██║
 ╚██████╔╝███████╗╚██████╔╝██║  ██╗╚██████╔╝███████║███████╗
  ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝
```

# OzionUI

**A sleek, heavily-animated UI library for Roblox script executors.**
API modelled after the Obsidian library — but with more polish, more motion, and a built-in config system.

`v1.0.0` · single file · zero dependencies · works on every major executor

</div>

---

## ✨ Why OzionUI?

Obsidian-style API you already know, with **20+ animations** layered on top:

| Animation | Where |
|---|---|
| Splash intro (logo scale-in, glowing stroke, loading bar) | on load |
| Window open with **back-overshoot** + fade, close shrink | show / hide |
| "Shine" sweep across the topbar | first open |
| **Sliding tab pill** that glides between tabs | tab switch |
| Cross-fade + slide-up of tab content | tab switch |
| **Ripple** expanding from the exact click point | buttons |
| Press-down scale with spring release | all buttons |
| Toggle knob **spring slide** + track color crossfade + glow ring | toggles |
| Value **bubble pops above the slider** while dragging, value text "pops" | sliders |
| Height expand with **staggered item cascade** + rotating chevron | dropdowns |
| Popover scale-in from the color chip, live HSV dragging | color pickers |
| Toasts **slide in from the right with back-easing**, drain a progress bar, then collapse | notifications |
| **Inertial smooth-follow dragging** (window eases toward your cursor) | window drag |
| Pulsing stroke while waiting for a key | keybind capture |
| Live rainbow accent cycling at 30 Hz | `SetRainbow(true)` |
| Watermark slides in, live clock + FPS counter | watermark |
| Minimize morphs the window into a tiny pill | minimize button |
| Splash, toasts, popovers all animate out before destroying | everywhere |

And the boring-but-important stuff:

- ✅ Obsidian-compatible API (`CreateWindow` → `AddTab` → `AddSection` → `AddToggle`…)
- ✅ **Executor-safe parenting** — `gethui()` → `syn.protect_gui` → `CoreGui` → `PlayerGui` fallback chain
- ✅ **CanvasGroup** whole-UI fades, with automatic `Frame` fallback for ancient executors
- ✅ Flag-based **config system** (auto-save, load, list — JSON via `writefile`/`readfile`)
- ✅ Live **theme engine** — recolor every open UI instantly, 7 built-in presets
- ✅ Callbacks wrapped in `pcall` — a user error can never kill your UI
- ✅ Clean `Destroy()` that unhooks every connection
- ✅ **137 automated checks** passing in a headless Roblox-API mock (see `test/`)

---

## 🚀 Quick start

```lua
local OzionUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/OzionUI.lua"
))()

local Window = OzionUI:CreateWindow({
    Title = "My Hub",
    SubTitle = "by me",
    Icon = "✦",                          -- emoji/text icon (or "rbxassetid://...")
    Size = UDim2.fromOffset(600, 460),
    TabWidth = 150,
    Key = Enum.KeyCode.RightControl,      -- UI show/hide key
    ShowSplash = true,                    -- animated intro
    SaveConfig = true,                    -- auto-save flagged elements
    ConfigFolder = "MyHub",
})

local Tab = Window:AddTab({ Title = "Main", Icon = "🏠" })
local Section = Tab:AddSection({ Title = "Combat" })

Section:AddToggle({
    Title = "Aimbot",
    Default = false,
    Flag = "aimbot",                      -- saved by the config system
    Callback = function(value)
        print("aimbot:", value)
    end,
})
```

Testing locally before hosting: `local OzionUI = loadstring(readfile("OzionUI.lua"))()`

---

## 📚 Full API

### `OzionUI:CreateWindow(config)` → `Window`

| Option | Type | Default | Description |
|---|---|---|---|
| `Title` | string | `"OzionUI"` | Topbar title |
| `SubTitle` | string | `"v1.0.0"` | Small text under the title |
| `Icon` | string | nil | Emoji/text icon, or `"rbxassetid://123"` |
| `Size` | UDim2 | `590×460` | Window size (clamped 500–820 × 360–620) |
| `TabWidth` | number | `150` | Sidebar width (110–220) |
| `Key` / `ToggleKey` | KeyCode or string | `RightControl` | Show/hide key |
| `ShowSplash` | boolean | `true` | Animated intro splash |
| `Theme` | string or table | `"Midnight"` | Preset name or custom table |
| `SaveConfig` | boolean | `false` | Auto-save flagged elements (debounced 1.25 s) |
| `ConfigFolder` | string | `"OzionUI"` | Folder for configs |
| `ConfigName` | string | `"default"` | File name used by auto-save |

**Window methods:** `Window:AddTab`, `Window:SelectTab(tab, instant?)`, `Window:Show/Hide/Toggle`, `Window:Minimize/Restore/ToggleMinimize`, `Window:SetTitle`, `Window:SetSubtitle`, `Window:Destroy`

### `Window:AddTab({ Title, Icon })` → `Tab`

Icons accept emoji strings (`"🏠"`) **or** asset ids (`"rbxassetid://4370185901"` / `4370185901`).
Tabs can hold sections *or* elements directly.

**Tab methods:** `Tab:AddSection(...)`, plus every `Add<Element>` below, `Tab:AddSection` → `Section` (with `Section:SetTitle(text)`).

### Elements — `Section:AddX(config)` / `Tab:AddX(config)`

Every element returns a table with `Get()` (and `Set(value)` where it makes sense).
If `Flag` is provided, the element registers in `OzionUI.Flags[flag]` and participates in configs.

#### `AddButton`
```lua
Section:AddButton({
    Title = "Click me",
    Description = "optional second line",  -- optional
    Icon = "⚡",                            -- optional
    Callback = function() end,
})
```

#### `AddToggle`
```lua
local aimbot = Section:AddToggle({
    Title = "Aimbot", Default = false, Flag = "aimbot",
    Callback = function(value) end,       -- value: boolean
})
aimbot:Set(true)      -- programmatic set (fires callback)
aimbot:Get()          -- -> true
```

#### `AddSlider`
```lua
local speed = Section:AddSlider({
    Title = "WalkSpeed", Min = 16, Max = 200, Default = 16,
    Decimals = 0,      -- 2 decimals also works (0.00–1.00 style)
    Suffix = " sp",    -- optional, appended to shown value
    Flag = "walkspeed",
    Callback = function(value) end,       -- value: number
})
```

#### `AddDropdown`
```lua
-- single select
local weapon = Section:AddDropdown({
    Title = "Weapon",
    Values = { "Pistol", "Rifle", "Sniper" },   -- Options = alias
    Default = "Rifle",
    Flag = "weapon",
    Callback = function(value) end,             -- value: string
})
-- multi select
local friends = Section:AddDropdown({
    Title = "Whitelist",
    Options = { "Alex", "Brook", "Casey" },
    Multi = true,
    Default = { "Alex" },
    Callback = function(values) end,            -- values: {string, ...}
})
weapon:Open() / weapon:Close()                  -- control the list programmatically
```

#### `AddTextbox`
```lua
Section:AddTextbox({
    Title = "Chat prefix",
    Placeholder = "type here...",
    Default = "",
    Live = false,          -- true = callback fires on every keystroke
    OnlyOnEnter = false,   -- true = only commit when Enter is pressed
    Flag = "prefix",
    Callback = function(text) end,
})
```

#### `AddKeybind`
```lua
Section:AddKeybind({
    Title = "Panic",
    Default = Enum.KeyCode.Delete,   -- accepts strings too: "Delete"
    Mode = "Always",                 -- Always | Toggle | Hold
    Flag = "panic",
    Callback = function(state) end,
    -- Always: callback() each press
    -- Toggle: callback(true/false)
    -- Hold:    callback(true) on press, callback(false) on release
})
```
UI: click the chip → press any key to bind (`Backspace` = clear, `Esc` = cancel). **Right-click the chip** to cycle the mode.

#### `AddColorPicker`
```lua
Section:AddColorPicker({
    Title = "ESP Color",
    Default = Color3.fromRGB(138, 99, 255),
    Flag = "espcolor",
    Callback = function(color) end,   -- live while dragging
})
```
Popover with full HSV picker, live preview, hex code and a copy-to-clipboard button. Closes when clicking anywhere else.

#### Static elements
```lua
local label = Section:AddLabel({ Text = "hello" })
local para  = Section:AddParagraph({ Text = "long wrapped text ..." })
Section:AddDivider()
label:Set("new text")
```

### Notifications
```lua
OzionUI:Notification({
    Title = "Saved",
    Description = "config written to disk",
    Type = "Success",     -- Success | Error | Warning | Info (default)
    Duration = 4,         -- seconds
})
-- returns { Frame, Close = function() end }
```
Also available as `OzionUI:Notify(...)`. Max 6 stacked; oldest is evicted.

### Theming
```lua
OzionUI:SetTheme("Ocean")                -- preset: Midnight Amethyst Ocean Emerald Sakura Sunset Carbon
OzionUI:SetTheme({ Accent = Color3.fromRGB(255, 80, 80) })  -- partial override
OzionUI:SetAccent(Color3.fromRGB(0, 255, 127))              -- just the accent
OzionUI:SetRainbow(true)                 -- animated accent cycle
```
Overridable keys: `Accent Background Topbar Section SectionStroke Element ElementHover RowHover Text SubText Stroke ToggleOff SliderTrack Knob Success Error Warning`.

### Watermark
```lua
OzionUI:CreateWatermark("MyHub")   -- pill with: name | clock | FPS
OzionUI:DestroyWatermark()
```

### Configs
```lua
OzionUI:SaveConfig("profile1")   -- -> workspace/OzionUI/profile1.json
OzionUI:LoadConfig("profile1")   -- applies every flag (fires callbacks)
OzionUI:GetConfigs()             -- -> { "default", "profile1", ... }
```
With `SaveConfig = true` on the window, any change to a **flagged** element auto-saves `ConfigName` after 1.25 s. Requires an executor with `writefile` (all major ones have it).

### Global
```lua
OzionUI:Toggle()    -- toggle the most recent window
OzionUI:Destroy()   -- destroy everything, disconnect all connections
OzionUI.Version     -- "1.0.0"
OzionUI.Flags       -- flag -> element table
OzionUI.Windows     -- active windows
```

---

## 🎨 Default hotkeys

| Key | Action |
|---|---|
| `RightControl` | Show / hide the UI (configurable per window) |

---

## 🧪 Testing / "make sure it works"

The library ships with a **headless mock of the Roblox client API** so the whole thing can be executed and verified without touching Roblox:

```bash
pip install lupa
python3 test/run_tests.py
```

```
RESULT: ALL TESTS PASSED   (137 checks, both CanvasGroup and fallback modes)
```

The mock validates **every property name and datatype** the library touches against real Roblox class definitions, simulates clicks/drags/key presses, and runs the tween + task scheduler on a virtual clock — including save/load of configs through a mock filesystem.

---

## 📁 Files

| File | What it is |
|---|---|
| `OzionUI.lua` | The library — a single self-contained file |
| `example.lua` | Full demo script using every feature |
| `GUIDE.md` | **Build your own UI library using OzionUI** — step-by-step |
| `test/harness.lua` | Headless Roblox-API mock + 137 assertions |
| `test/run_tests.py` | Test runner |

## 🌐 Executor compatibility

Tested API surface: `gethui`, `syn.protect_gui`, `cloneref`-optional, `writefile`/`readfile`/`makefolder`/`isfolder`/`listfolder` (all optional + `pcall`-guarded), `setclipboard` (optional), `task.*`, standard `Instance`/`TweenService`/`UserInputService`. Works on Synapse Z, Wave, Swift, Delta, Fluxus, Krnl, Hydrogen, Solara and friends — anything that can `loadstring`.

## 📜 License

Do whatever you want — credit appreciated. Built to be learned from: read `GUIDE.md`.
