<div align="center">

# OzionUI

**An animated, executor-ready UI library for Roblox.**

Built to feel like [Obsidian](https://github.com/deividcomsono/Obsidian) / Linoria — same API shape, same muscle memory —
with a darker look, a sidebar layout, and motion on just about everything.

`v1.0.0` · MIT · 59 passing headless tests

</div>

---

## Why another one

If you already write scripts for Obsidian, you know the shape:

```lua
local Window = Library:CreateWindow({ Title = "..." })
local Tab    = Window:AddTab("Main", "home")
local Box    = Tab:AddLeftGroupbox("Features")
Box:AddToggle("MyToggle", { Text = "Enable", Callback = print })
```

That exact code runs on OzionUI. What you get on top:

| | |
|---|---|
| **Animated everything** | ripples, sliding toggle knobs, staggered dropdown items, a rotating gradient outline, spring tab indicator, slide-in notifications with a countdown bar, hover lifts, pulses on enable |
| **Sidebar layout** | vertical icon tabs with a live search box that filters every element in the tab |
| **Executor-first** | `gethui()` → `syn.protect_gui` → `CoreGui` → `PlayerGui` fallback chain, randomised ScreenGui name, every callback wrapped in `pcall` |
| **No dependencies** | one file. No icon pack fetch, no second HTTP request, no `wait()` loops |
| **Actually tested** | `node tests/run.js` boots a Lua VM with a mocked Roblox API and drives the whole library, the addons and `Example.lua` end to end |
| **Degrades gracefully** | works in Studio, works without `writefile`, works on mobile (floating toggle button), works with animations switched off |

---

## Quick start

```lua
local Repo = "https://raw.githubusercontent.com/JMY12970/Unknown/main/"

local Library      = loadstring(game:HttpGet(Repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(Repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(Repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title  = "My Script",
    Footer = "v1.0.0",
    Icon   = "rocket",
    Size   = UDim2.fromOffset(620, 500),
})

local Tabs = {
    Main     = Window:AddTab("Main", "home"),
    Settings = Window:AddTab("Settings", "settings"),
}

local Box = Tabs.Main:AddLeftGroupbox("Features", "zap")

Box:AddToggle("AutoFarm", {
    Text = "Auto farm",
    Callback = function(Value) print("auto farm:", Value) end,
})

Box:AddSlider("Speed", { Text = "Speed", Default = 50, Min = 0, Max = 100, Rounding = 0 })

Box:AddButton({ Text = "Rejoin", Func = function() Library:Notify("Rejoining...", 3) end })

SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder("MyScript")
SaveManager:SetFolder("MyScript/" .. game.PlaceId)
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
```

> **Branch note** — until this branch is merged into `main`, point `Repo` at
> `https://raw.githubusercontent.com/JMY12970/Unknown/arena/01a1049a-unknown/`.

Two files to copy from:

* [`examples/Template.lua`](examples/Template.lua) — the smallest sensible starting point
* [`Example.lua`](Example.lua) — every single element, wired up

And the full tutorial: **[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)**.

---

## Repository layout

```
Library.lua                 the library (this is the only required file)
addons/SaveManager.lua      JSON config save / load / autoload
addons/ThemeManager.lua     12 built-in themes + custom theme files
Example.lua                 full showcase
examples/Template.lua       starter template
docs/GETTING_STARTED.md     step-by-step: build a script from nothing
docs/API.md                 complete API reference
docs/MIGRATING.md           coming from Obsidian / Linoria
tests/                      headless Roblox mock + test suite
```

---

## The elements

| Call | What you get |
|---|---|
| `Box:AddLabel(text or {Text, DoesWrap})` | text, optionally wrapping |
| `Box:AddDivider(text?)` | separator, optional centred caption |
| `Box:AddButton({Text, Func, DoubleClick, Tooltip})` | ripple button, `:AddButton{}` again for a side-by-side pair |
| `Box:AddToggle(idx, {Text, Default, Risky, Tooltip, Callback})` | sliding switch |
| `Box:AddCheckbox(idx, {...})` | same thing with a checkbox |
| `Box:AddSlider(idx, {Text, Default, Min, Max, Rounding, Suffix, Compact, HideMax})` | drag, click-to-jump, animated fill |
| `Box:AddDropdown(idx, {Text, Values, Default, Multi, Searchable, AllowNull, SpecialType})` | single / multi, searchable, auto player list |
| `Box:AddInput(idx, {Text, Default, Placeholder, Numeric, Finished, MaxLength})` | text box with an animated underline |
| `Box:AddImage({Image, Height})` | asset or decal |
| `Box:AddDependencyBox()` | child elements that appear only when a condition holds |
| `element:AddColorPicker(idx, {Default, Title, Transparency})` | HSV square, hue bar, hex field, copy button |
| `element:AddKeyPicker(idx, {Default, Mode, Text, SyncToggleState, NoUI})` | Toggle / Hold / Always, right-click for the mode menu |

Elements live on **groupboxes** (`Tab:AddLeftGroupbox`, `AddRightGroupbox`) and on
**tabbox tabs** (`Tab:AddLeftTabbox():AddTab("Name")`).

Anything with an index is reachable later through the two globals:

```lua
Toggles.AutoFarm.Value          -- boolean
Options.Speed.Value             -- number
Options.TargetPlayer.Value      -- string
Options.EspColor.Value          -- Color3
Options.EspKey:GetState()       -- boolean (respects Toggle / Hold / Always)

Toggles.AutoFarm:OnChanged(function(v) print(v) end)
Options.Speed:SetValue(75)
```

---

## Animations

Every animation runs through one function, so you can bend them globally:

```lua
Library.Animations     = true   -- master switch, false = instant everything
Library.AnimationSpeed = 1      -- 0.5 = twice as fast, 2 = half speed
Library.RippleEnabled  = true   -- click ripples
Library.UseBlur        = true   -- background blur while the menu is open
```

Use the same engine for your own elements:

```lua
Library:Tween(frame, { BackgroundTransparency = 0 }, 0.3, "Snappy")
Library:Ripple(button, mouseX, mouseY)
Library:Pulse(frame)                 -- expanding glow ring
Library:AnimateGradient(gradient, 6) -- endless rotation, 6s per turn
```

Presets: `Smooth` (Quint out), `Snappy` (Back out), `Bounce`, `Soft` (Sine), `Linear`, `Elastic`.

---

## Themes

```lua
ThemeManager:ApplyTheme("Tokyo Night")
ThemeManager:ApplyToTab(Tabs.Settings)   -- adds the whole appearance panel
```

Built in: `Ozion` · `Midnight` · `Fatality` · `Jester` · `Mint` · `Tokyo Night` ·
`Vaporwave` · `Ember` · `Quartz` · `Monochrome` · `Ubuntu` · `Bloom`

Or set colours yourself — every instance the library creates is in a registry,
so one call restyles the entire menu live:

```lua
Library.Scheme.AccentColor = Color3.fromRGB(0, 200, 255)
Library:UpdateColorsUsingRegistry()
-- shorthand
Library:SetAccent(Color3.fromRGB(0, 200, 255))
```

---

## Saving configs

```lua
SaveManager:SetFolder("MyScript/" .. game.PlaceId)
SaveManager:BuildConfigSection(Tabs.Settings)   -- name box, list, save/load/delete/autoload
SaveManager:LoadAutoloadConfig()
```

Written to `<folder>/settings/<name>.json`. Toggles, sliders, dropdowns (single and
multi), inputs, colour pickers and keybinds all round-trip — there is a test that
saves, scrambles every value, reloads and asserts they all came back.

---

## Executor compatibility

| Feature | Used for | If missing |
|---|---|---|
| `gethui()` | hiding the ScreenGui | falls back to `protect_gui` → `CoreGui` → `PlayerGui` |
| `syn.protect_gui` / `protectgui` | same | skipped |
| `writefile` / `readfile` / `listfiles` | configs + themes | SaveManager reports it politely, the UI still works |
| `setclipboard` | the colour picker's copy button | button notifies that it is unsupported |
| `cloneref` | service hardening | used when present |
| `getgenv` | exporting `Toggles` / `Options` | they stay on the `Library` table |

Tested logic paths cover Synapse-style, Script-Ware-style and plain-Studio
environments. Nothing in the library yields, so it cannot hang on load.

---

## Running the tests

```bash
npm install          # pulls wasmoon (a Lua 5.4 VM in wasm)
node tests/run.js
```

`tests/mock_roblox.lua` implements just enough of the engine — Instances, signals,
`TweenService`, `UserInputService`, `HttpService` JSON, the datatypes — to load
`Library.lua` for real and click through it. The suite covers every element, the
keybind modes, dragging, resizing, theming, both addons and `Example.lua` itself.

```
passed: 59    failed: 0    instances: 2184    tweens: 674
```

---

## Credits

API shape inspired by [Linoria](https://github.com/violin-suzutsuki/LinoriaLib) and
[Obsidian](https://github.com/deividcomsono/Obsidian). Implementation, animation
system, layout, themes and tests are original.

MIT — do what you like, credit appreciated.
