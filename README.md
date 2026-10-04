<div align="center">

# OzionUI

**An animated, executor-ready UI library for Roblox — in a single file.**

Same API shape as [Obsidian](https://github.com/deividcomsono/Obsidian) / Linoria,
with a sidebar layout, a darker look, and motion on just about everything.

`v1.0.0` · MIT · 63 passing headless tests

</div>

---

## Setup

OzionUI is **one file with no downloads**. There is no `loadstring`, no
`HttpGet`, no second request for addons — `SaveManager` and `ThemeManager` are
already inside it and already wired up.

### 1. Copy the file

Open **[`OzionUI.lua`](OzionUI.lua)** and copy the whole thing.

### 2. Paste it into your script

Paste it at the very top of your executor's editor. The bottom of the file ends
with this marker:

```lua
--[==========================================================================[
--
--   ####  YOUR SCRIPT GOES BELOW THIS LINE  ####
--
--]==========================================================================]
```

Everything you write goes **under** that line, in the same script.

### 3. Check it loaded

```lua
local Window = OzionUI:CreateWindow({ Title = "My Script" })
local Tab    = Window:AddTab("Main", "home")
local Box    = Tab:AddLeftGroupbox("Features", "zap")

Box:AddToggle("AutoFarm", {
    Text = "Auto farm",
    Callback = function(Value) print("auto farm:", Value) end,
})
```

Execute. A menu fades in, and `Right Ctrl` hides and shows it.

---

## What is in scope after pasting

| Name | What it is |
|---|---|
| `OzionUI` | the library — also aliased as `Library` |
| `SaveManager` | JSON config save / load / autoload, already `:SetLibrary`'d |
| `ThemeManager` | 12 built-in themes + custom themes, already `:SetLibrary`'d |
| `Toggles` | every toggle you create, keyed by its index |
| `Options` | every other indexed element (sliders, dropdowns, pickers…) |

In an executor they are also published on `getgenv()`, so other scripts you load
afterwards can reach the same menu through `getgenv().OzionUI`.

Reading values later:

```lua
Toggles.AutoFarm.Value          -- boolean
Options.Speed.Value             -- number
Options.EspColor.Value          -- Color3
Options.EspKey:GetState()       -- boolean (respects Toggle / Hold / Always)
```

Full reference: **[docs/API.md](docs/API.md)**.

---

## Other ways to run it

**Roblox Studio** — paste `OzionUI.lua` into a `LocalScript` under
`StarterPlayer > StarterPlayerScripts` and write your code below the marker.
`getgenv` does not exist in Studio, so the names stay local to that script —
everything else behaves identically.

**Keeping your script in its own file** — during development, keep `OzionUI.lua`
and your code separate and glue them together before you ship:

```bash
cat OzionUI.lua MyScript.lua > release.lua
```

`MyScript.lua` should then start with the same guard the examples use:

```lua
local Library = OzionUI or (getgenv and getgenv().OzionUI)
assert(Library, "Paste the contents of OzionUI.lua above this line first.")
```

**Self-hosting** — if you do want a one-line loader for your own users, upload
`OzionUI.lua` plus your script as a single concatenated file and host it
yourself. The library never fetches anything at runtime, so it works offline.

---

## Unloading

```lua
OzionUI:Unload()                       -- removes the GUI, connections and cursor
OzionUI:OnUnload(function() ... end)   -- your own cleanup
while not OzionUI.Unloaded do ... end  -- safe loop condition
```

---

## Repository layout

```
OzionUI.lua             the library, the SaveManager and the ThemeManager — paste this
Example.lua             showcase: every element, wired up
examples/Template.lua   the smallest sensible starting point
docs/API.md             complete API reference
tests/                  headless Roblox mock + test suite
```

---

## Executor compatibility

| Feature | Used for | If missing |
|---|---|---|
| `gethui()` | hiding the ScreenGui | falls back to `protect_gui` → `CoreGui` → `PlayerGui` |
| `syn.protect_gui` / `protectgui` | same | skipped |
| `writefile` / `readfile` / `listfiles` | configs + themes | SaveManager says so politely, the UI still works |
| `setclipboard` | the colour picker's copy button | button notifies that it is unsupported |
| `cloneref` | service hardening | used when present |
| `getgenv` | publishing `OzionUI` / `Toggles` / `Options` | the names stay local to your script |

Nothing in the library yields, so it cannot hang on load. Every callback is
wrapped in `pcall`, and the ScreenGui name is randomised on each run.

---

## Running the tests

```bash
npm install          # pulls wasmoon (a Lua 5.4 VM in wasm)
node tests/run.js
```

`tests/mock_roblox.lua` implements just enough of the engine — Instances,
signals, `TweenService`, `UserInputService`, `HttpService` JSON, the datatypes —
to execute `OzionUI.lua` exactly as an executor would and click through it. The
suite covers every element, the keybind modes, dragging, resizing, theming, both
addons, `Example.lua` and `examples/Template.lua`.

```
passed: 63    failed: 0    instances: 2917    tweens: 800
```

---

## Credits

API shape inspired by [Linoria](https://github.com/violin-suzutsuki/LinoriaLib)
and [Obsidian](https://github.com/deividcomsono/Obsidian). Implementation,
animation system, layout, themes and tests are original.

MIT — do what you like, credit appreciated.
