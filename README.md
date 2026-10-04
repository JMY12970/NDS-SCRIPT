# Vanta UI

A polished, animated, dependency-free UI library for Roblox. Vanta is an original dark interface inspired by modern dashboard design, with smooth transitions, themes, config serialization, and a compact component API.

> Vanta uses normal Roblox APIs and is intended for experiences you own or are authorized to modify. It does not include exploit, injection, or cheat functionality.

## Highlights

- Spring-style window open, minimize, tab, toggle, and press animations
- Animated button ripples and rotating accent gradients
- Draggable and resizable window with a configurable hotkey
- Dashboard tabs with search and animated page transitions
- Buttons, toggles, sliders, dropdowns, inputs, keybinds, color pickers, and paragraphs
- Stacked notifications with info, success, warning, and error variants
- Runtime theme switching and custom theme registration
- Flag-based state plus JSON config export/import
- Mouse and touch input support
- No packages, image libraries, or third-party dependencies

## Install

### Roblox Studio

1. Create a `ModuleScript` named `VantaUI` in `ReplicatedStorage`.
2. Copy [`src/VantaUI.lua`](src/VantaUI.lua) into that ModuleScript.
3. Create a `LocalScript` in `StarterPlayer > StarterPlayerScripts`.
4. Require the module from that LocalScript:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VantaUI = require(ReplicatedStorage:WaitForChild("VantaUI"))
```

A complete example is available in [`examples/showcase.client.lua`](examples/showcase.client.lua).

### Rojo

The included [`default.project.json`](default.project.json) maps the library into `ReplicatedStorage` and the showcase into `StarterPlayerScripts`:

```sh
rojo serve
```

## Quick start

```lua
local VantaUI = require(game.ReplicatedStorage.VantaUI)

local Window = VantaUI:CreateWindow({
    Title = "My Hub",
    Subtitle = "PRIVATE BUILD",
    Theme = "Obsidian",
    ToggleKey = Enum.KeyCode.RightShift,
    Size = Vector2.new(760, 500),
})

local Main = Window:AddTab({
    Title = "Main",
    Icon = "◆",
    Description = "Primary controls",
})

local Player = Main:AddSection({
    Title = "Player",
    Description = "Example settings",
})

Player:AddToggle({
    Title = "Enabled",
    Default = false,
    Flag = "enabled",
    Callback = function(value)
        print("Enabled:", value)
    end,
})

Player:AddSlider({
    Title = "Speed",
    Min = 1,
    Max = 100,
    Default = 25,
    Increment = 1,
    Suffix = "%",
    Flag = "speed",
    Callback = function(value)
        print("Speed:", value)
    end,
})

Window:Notify({
    Title = "Loaded",
    Content = "The interface is ready.",
    Type = "Success",
})
```

## API

### Library

#### `VantaUI:CreateWindow(options)`

Creates and returns a window.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Title` | string | `"Vanta"` | Brand title |
| `Subtitle` | string | `"UI LIBRARY"` | Small brand caption |
| `Size` | Vector2 | `Vector2.new(760, 500)` | Initial window size |
| `MinSize` | Vector2 | `Vector2.new(620, 400)` | Resize floor |
| `Theme` | string/table | `"Obsidian"` | Built-in name or custom palette |
| `ToggleKey` | Enum.KeyCode | `RightShift` | Show/hide hotkey |
| `Resizable` | boolean | `true` | Enables resize handle |
| `Parent` | Instance | `LocalPlayer.PlayerGui` | Optional GUI parent |

#### `VantaUI:RegisterTheme(name, colors)`

Adds a reusable theme. Missing tokens inherit from `Obsidian`.

```lua
VantaUI:RegisterTheme("Emerald", {
    Accent = Color3.fromRGB(45, 220, 145),
    AccentAlt = Color3.fromRGB(64, 180, 255),
})
```

Built-in themes: `Obsidian`, `Midnight`, and `Rose`.

### Window

| Method | Description |
| --- | --- |
| `Window:AddTab(options)` | Creates a tab |
| `Window:SelectTab(tabOrTitle)` | Selects a tab |
| `Window:SetTheme(nameOrColors)` | Changes the palette with animated transitions |
| `Window:Notify(options)` | Shows a stacked toast |
| `Window:Toggle()` | Toggles visibility |
| `Window:SetMinimized(boolean)` | Changes minimized state |
| `Window:GetFlag(name)` | Returns a control value |
| `Window:SetFlag(name, value)` | Updates a control value |
| `Window:ExportConfig()` | Returns all flagged values as JSON |
| `Window:ImportConfig(jsonOrTable)` | Applies serialized values |
| `Window:Destroy()` | Disconnects events and removes the UI |

Notification options:

```lua
Window:Notify({
    Title = "Saved",
    Content = "Your settings were saved.",
    Type = "Success", -- Info, Success, Warning, Error
    Duration = 4,
})
```

### Tab and section

```lua
local Tab = Window:AddTab({ Title = "Visuals", Icon = "✦" })
local Section = Tab:AddSection({ Title = "Display", Description = "Appearance" })
```

`Tab:AddSection` also accepts a title string directly.

### Controls

Every stateful control returns an object with:

- `control:GetValue()`
- `control:SetValue(value, silent?)`
- `control.Flag`

#### Button

```lua
Section:AddButton({
    Title = "Run action",
    Description = "Optional helper text",
    Callback = function() end,
})
```

The returned button also has `button:Fire()`.

#### Toggle

```lua
Section:AddToggle({
    Title = "Enabled",
    Default = true,
    Flag = "enabled",
    Callback = function(value) end,
})
```

#### Slider

```lua
Section:AddSlider({
    Title = "Amount",
    Min = 0,
    Max = 10,
    Default = 5,
    Increment = 0.5,
    Suffix = "x",
    Flag = "amount",
    Callback = function(value) end,
})
```

#### Dropdown

```lua
local Dropdown = Section:AddDropdown({
    Title = "Mode",
    Values = { "Legit", "Fast", "Custom" },
    Default = "Legit",
    Flag = "mode",
    Callback = function(value) end,
})

Dropdown:Refresh({ "One", "Two", "Three" }, "Two")
Dropdown:SetOpen(false)
```

#### Input

```lua
Section:AddInput({
    Title = "Nickname",
    Placeholder = "Type here...",
    Default = "",
    Numeric = false,
    Finished = true,
    Flag = "nickname",
    Callback = function(text) end,
})
```

Set `Finished = false` to run the callback while text changes.

#### Keybind

```lua
Section:AddKeybind({
    Title = "Action key",
    Default = Enum.KeyCode.F,
    Flag = "action_key",
    ChangedCallback = function(key) end,
    Callback = function(key) end,
})
```

Press `Escape` while binding to clear the key.

#### Color picker

```lua
Section:AddColorPicker({
    Title = "Accent",
    Default = Color3.fromRGB(132, 91, 255),
    Flag = "accent",
    Callback = function(color) end,
})
```

`SetValue` accepts either a `Color3` or a six-digit hex string.

#### Paragraph

```lua
Section:AddParagraph({
    Title = "Tip",
    Content = "Paragraphs automatically grow to fit wrapped content.",
    Accent = true,
})
```

## Config notes

Vanta only serializes the current values. Storage is intentionally left to your game so you can use the appropriate Roblox system, such as a server-validated DataStore flow. `Color3` values become hex strings and keybinds become key names in exported JSON.

```lua
local json = Window:ExportConfig()
print(json)

Window:ImportConfig(json)
-- or
Window:ImportConfig({ enabled = true, speed = 80 })
```

## License

MIT. See [`LICENSE`](LICENSE).
