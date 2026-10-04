# Making your own script with OzionUI

A complete walk-through: from an empty file to a script with a menu, working
features, keybinds, saved configs and a clean unload. Every snippet here runs —
they are the same calls the test suite exercises.

- [1. Load the library](#1-load-the-library)
- [2. Create the window](#2-create-the-window)
- [3. Add tabs](#3-add-tabs)
- [4. Add groupboxes](#4-add-groupboxes)
- [5. Add elements](#5-add-elements)
- [6. Read values back](#6-read-values-back)
- [7. Write the actual feature loop](#7-write-the-actual-feature-loop)
- [8. Keybinds and colour pickers](#8-keybinds-and-colour-pickers)
- [9. Dependency boxes](#9-dependency-boxes)
- [10. Notifications, watermark, keybind list](#10-notifications-watermark-keybind-list)
- [11. Configs and themes](#11-configs-and-themes)
- [12. Unloading properly](#12-unloading-properly)
- [13. The finished script](#13-the-finished-script)
- [Tips and gotchas](#tips-and-gotchas)

---

## 1. Load the library

```lua
local Repo = "https://raw.githubusercontent.com/JMY12970/Unknown/main/"

local Library      = loadstring(game:HttpGet(Repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(Repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(Repo .. "addons/SaveManager.lua"))()
```

`Library.lua` is self-contained — the two addons are optional. Loading the library
immediately gives you two globals as well (they are also on the table itself):

```lua
Toggles  -- every toggle / checkbox you create, keyed by its index
Options  -- every other element with an index
```

Stop a double-execution from stacking two menus:

```lua
if getgenv().MyScriptLoaded then return end
getgenv().MyScriptLoaded = true
```

---

## 2. Create the window

```lua
local Window = Library:CreateWindow({
    Title  = "Fish Hub",
    Footer = "v1.2.0",
    Icon   = "fish",                          -- name, rbxassetid://..., or a number
    Size   = UDim2.fromOffset(640, 520),
    Resizable     = true,
    AutoShow      = true,
    ShowCustomCursor = true,
    NotifySide    = "Right",
    ToggleKeybind = Enum.KeyCode.RightControl,
})
```

Every field is optional. The defaults give you a 640×520 centred, draggable,
resizable window that fades in with a slight scale-up.

---

## 3. Add tabs

Tabs appear in the left sidebar. The second argument is an icon.

```lua
local Tabs = {
    Main     = Window:AddTab("Main", "home"),
    Combat   = Window:AddTab("Combat", "sword"),
    Visuals  = Window:AddTab("Visuals", "eye"),
    Settings = Window:AddTab("Settings", "settings"),
}
```

Icons are resolved in this order:

1. a number → `rbxassetid://<number>`
2. a string starting with `rbxassetid://`, `rbxasset://` or `http` → used as-is
3. a name from `Library.Icons` (`home`, `settings`, `eye`, `sword`, `zap`, `key`,
   `palette`, `fish`, `rocket`, … ~70 of them) → drawn as a glyph
4. anything else → the first letter

Need a real icon pack? Just register the assets you want:

```lua
Library.Icons["skull"] = "rbxassetid://7733658504"
```

### Key systems

```lua
local KeyTab = Window:AddKeyTab("Key System")
KeyTab:AddLeftGroupbox("Enter key"):AddInput("Key", {
    Text = "Key", Finished = true,
    Callback = function(Value)
        if Value == "letmein" then
            KeyTab:Unlock()           -- reveals the rest of the tabs
        else
            Library:Notify({ Title = "Wrong key", Time = 4, Type = "Error" })
        end
    end,
})
```

While a key tab exists the other tab buttons are hidden and cannot be selected.

---

## 4. Add groupboxes

Each tab has a left and a right column.

```lua
local LeftBox  = Tabs.Main:AddLeftGroupbox("Automation", "zap")
local RightBox = Tabs.Main:AddRightGroupbox("Info")
```

Need sub-sections inside one box? Use a tabbox:

```lua
local Tabbox = Tabs.Visuals:AddLeftTabbox()
local EspTab   = Tabbox:AddTab("ESP")
local WorldTab = Tabbox:AddTab("World")
```

`EspTab` and `WorldTab` accept exactly the same `Add*` calls as a groupbox.

---

## 5. Add elements

The first argument of most elements is the **index** — the key you will use to
read the value later and the key the SaveManager writes into the config file.
Pass `nil` if the element should not be saved or looked up.

```lua
LeftBox:AddToggle("AutoFarm", {
    Text     = "Auto farm",
    Default  = false,
    Tooltip  = "Collects everything within the radius below",
    Callback = function(Value) print("auto farm:", Value) end,
})

LeftBox:AddSlider("FarmRadius", {
    Text = "Radius", Default = 60, Min = 10, Max = 250,
    Rounding = 0, Suffix = " studs",
})

LeftBox:AddDropdown("FarmMode", {
    Text = "Mode",
    Values = { "Closest", "Most valuable", "Random" },
    Default = 1,
})

LeftBox:AddDropdown("Rarities", {
    Text = "Rarities", Multi = true, Searchable = true,
    Values = { "Common", "Rare", "Epic", "Legendary" },
    Default = { "Epic", "Legendary" },
})

LeftBox:AddInput("WebhookUrl", {
    Text = "Webhook", Placeholder = "https://...", Finished = true,
})

LeftBox:AddDivider("Danger zone")

LeftBox:AddToggle("ServerHop", { Text = "Hop on detection", Risky = true })

RightBox:AddLabel("Everything you enable here is saved per game.", true)

local Button = RightBox:AddButton({
    Text = "Rejoin",
    Func = function() Library:Notify("Rejoining...", 3) end,
})
Button:AddButton({ Text = "Server hop", Func = function() end })  -- sits beside it
```

`Risky = true` paints the label red. `DoubleClick = true` on a button turns the
first click into an "Are you sure?" confirmation.

---

## 6. Read values back

Three equivalent ways:

```lua
-- 1. the callback
Box:AddToggle("Fly", { Callback = function(Value) Flying = Value end })

-- 2. the global table, any time
if Toggles.Fly.Value then ... end
local radius = Options.FarmRadius.Value

-- 3. subscribe later (fires immediately with the current value)
Toggles.Fly:OnChanged(function(Value) print("fly:", Value) end)
```

Multi-dropdowns give you a set, not a list:

```lua
for Rarity, Enabled in pairs(Options.Rarities.Value) do
    if Enabled then print("farming", Rarity) end
end
```

Writing back is symmetrical and triggers the same callbacks:

```lua
Toggles.Fly:SetValue(true)
Options.FarmRadius:SetValue(120)
Options.FarmMode:SetValue("Random")
Options.Rarities:SetValue({ "Common" })
```

Add `true` as a second argument to set a value **without** firing callbacks —
useful while restoring state yourself.

---

## 7. Write the actual feature loop

The library never runs your logic for you. The standard pattern:

```lua
task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoFarm.Value then
            local radius = Options.FarmRadius.Value
            -- ... your farming code ...
        end
        task.wait(0.5)
    end
end)
```

`Library.Unloaded` flips to `true` the moment the menu is destroyed, so the loop
ends on its own. For per-frame work use a connection and clean it up:

```lua
local conn = game:GetService("RunService").RenderStepped:Connect(function()
    if not Toggles.Fullbright.Value then return end
    game:GetService("Lighting").Brightness = 2
end)

Library:OnUnload(function() conn:Disconnect() end)
```

---

## 8. Keybinds and colour pickers

Both attach to an existing element (a toggle or a label), not to the groupbox:

```lua
local EspToggle = EspTab:AddToggle("Esp", { Text = "Enable ESP" })

EspToggle:AddKeyPicker("EspKey", {
    Default = "F",
    Mode    = "Toggle",      -- "Toggle" | "Hold" | "Always"
    Text    = "ESP",         -- label used in the keybind list
    SyncToggleState = true,  -- pressing the key also flips the toggle
})

EspToggle:AddColorPicker("EspColor", {
    Default = Color3.fromRGB(125, 90, 255),
    Title   = "ESP colour",
    Callback = function(Value) print(Value) end,
})
```

A keybind that is not attached to a toggle hangs off a label:

```lua
Box:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightControl", Mode = "Toggle", Text = "Menu", NoUI = true,
})
Library.ToggleKeybind = Options.MenuKeybind   -- now that key opens/closes the UI
```

Read a keybind's live state with `Options.EspKey:GetState()` — it accounts for the
mode, so `Always` is permanently `true` and `Hold` is only `true` while held.
Right-clicking a keybind button opens the mode menu.

---

## 9. Dependency boxes

Hide a block of elements until a condition is true:

```lua
local SpeedToggle = LeftBox:AddToggle("CustomSpeed", { Text = "Custom walk speed" })

local SpeedBox = LeftBox:AddDependencyBox()
SpeedBox:AddSlider("WalkSpeed", { Text = "Walk speed", Default = 16, Min = 16, Max = 200 })
SpeedBox:AddToggle("NoClip", { Text = "No clip" })

SpeedBox:SetupDependencies({ { SpeedToggle, true } })
```

Conditions are `{ element, expectedValue }` pairs — any element with a `.Value`
works, so you can depend on a dropdown selection too:
`{ Options.FarmMode, "Random" }`.

---

## 10. Notifications, watermark, keybind list

```lua
Library:Notify("Quick message", 3)

Library:Notify({
    Title = "Config saved",
    Description = "Stored as 'main'.",
    Time = 4,
    Type = "Success",              -- Normal | Success | Warning | Error
})

Library:SetWatermark("Fish Hub | " .. game.PlaceId)
Library:SetWatermarkVisibility(true)

Library:SetKeybindVisibility(true)   -- the floating list of active keybinds
Library:SetNotifySide("Left")
```

`Library:Notify` returns a handle with `:ChangeTitle()`, `:ChangeDescription()`
and `:Destroy()` if you want to keep one on screen and update it.

---

## 11. Configs and themes

```lua
SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()                  -- don't save theme colours in configs
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })    -- never save the menu bind

ThemeManager:SetFolder("FishHub")                  -- FishHub/themes/
SaveManager:SetFolder("FishHub/" .. game.PlaceId)  -- FishHub/<placeid>/settings/

SaveManager:BuildConfigSection(Tabs.Settings)      -- builds the whole config panel
ThemeManager:ApplyToTab(Tabs.Settings)             -- builds the whole appearance panel

SaveManager:LoadAutoloadConfig()                   -- call last, after every element exists
```

Order matters: `LoadAutoloadConfig` restores values into elements, so every
element must already exist when you call it.

Programmatic access is there too:

```lua
SaveManager:Save("pvp")
SaveManager:Load("pvp")
SaveManager:Delete("pvp")
SaveManager:RefreshConfigList()      --> { "pvp", "farming" }
ThemeManager:ApplyTheme("Tokyo Night")
```

---

## 12. Unloading properly

```lua
Library:OnUnload(function()
    -- stop loops, disconnect events, delete ESP drawings, restore the character
    for _, drawing in pairs(MyDrawings) do drawing:Remove() end
    Humanoid.WalkSpeed = 16
end)
```

`Library:Unload()` runs your callbacks, disconnects every connection the library
made, destroys the ScreenGui, removes the blur, restores the mouse icon and
clears `Toggles` / `Options`. The window's ✕ button calls it for you.

---

## 13. The finished script

```lua
local Repo = "https://raw.githubusercontent.com/JMY12970/Unknown/main/"
local Library      = loadstring(game:HttpGet(Repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(Repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(Repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({ Title = "Fish Hub", Footer = "v1.2.0", Icon = "fish" })
local Tabs = {
    Main     = Window:AddTab("Main", "home"),
    Settings = Window:AddTab("Settings", "settings"),
}

local Box = Tabs.Main:AddLeftGroupbox("Automation", "zap")
Box:AddToggle("AutoFarm", { Text = "Auto farm" })
Box:AddSlider("FarmRadius", { Text = "Radius", Default = 60, Min = 10, Max = 250, Rounding = 0 })
Box:AddButton({ Text = "Rejoin", Func = function() Library:Notify("Rejoining...", 3) end })

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoFarm.Value then
            -- farm within Options.FarmRadius.Value
        end
        task.wait(0.5)
    end
end)

SaveManager:SetLibrary(Library); ThemeManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder("FishHub")
SaveManager:SetFolder("FishHub/" .. game.PlaceId)
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Library:OnUnload(function() print("bye") end)
```

---

## Tips and gotchas

**Index names must be unique.** `Toggles` and `Options` are flat tables — two
elements called `"Speed"` will overwrite each other. Prefix them: `CombatSpeed`,
`VisualSpeed`.

**Callbacks fire for defaults.** An element created with `Default = true` calls
its callback once during creation, so your state starts in sync.

**Never let a callback error silently break things** — it can't. Everything is
wrapped; errors show up as a red notification and a `warn()`.

**Don't yield in a callback.** `task.spawn` long work so the UI thread keeps
animating:

```lua
Func = function()
    task.spawn(function() SomethingSlow() end)
end
```

**Mobile.** `Library.IsMobile` is set automatically and a floating round toggle
button is created. Force it on desktop for testing with
`CreateWindow{ ForceMobileButton = true }`.

**Performance.** Turn everything off on weak devices:

```lua
Library.Animations    = false
Library.UseBlur       = false
Library.RippleEnabled = false
```

**Search.** The sidebar search box filters elements in the *current* tab by their
label text — give your elements descriptive `Text`.

Full reference: [API.md](API.md). Coming from Obsidian: [MIGRATING.md](MIGRATING.md).
