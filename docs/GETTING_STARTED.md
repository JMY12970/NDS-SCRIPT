# Getting started with OzionUI

This guide shows how to install OzionUI, create a window, and add buttons and every other included control.

OzionUI is a client UI library, so create and require it from a `LocalScript`. Use it in Roblox experiences you own or are authorized to edit.

## 1. Install the module in Roblox Studio

1. Open your experience in Roblox Studio.
2. In **Explorer**, right-click `ReplicatedStorage` and choose **Insert Object > ModuleScript**.
3. Rename the ModuleScript to `OzionUI`.
4. Open [`src/OzionUI.lua`](../src/OzionUI.lua), copy all of it, and replace the ModuleScript's contents.
5. Right-click `StarterPlayer > StarterPlayerScripts` and choose **Insert Object > LocalScript**.
6. Put your interface code in that LocalScript.

Your Explorer should look like this:

```text
ReplicatedStorage
└── OzionUI              (ModuleScript)

StarterPlayer
└── StarterPlayerScripts
    └── MyInterface      (LocalScript)
```

## 2. Create a window

Start your `MyInterface` LocalScript with:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OzionUI = require(ReplicatedStorage:WaitForChild("OzionUI"))

local Window = OzionUI:CreateWindow({
    Title = "My Interface",
    Subtitle = "OZIONUI",
    Theme = "Obsidian",
    Size = Vector2.new(760, 500),
    ToggleKey = Enum.KeyCode.RightShift,
    Resizable = true,
})
```

Press `RightShift` while testing to hide or show the window. You can drag the top bar and resize from the bottom-right corner.

## 3. Add a tab and section

Controls live inside sections, and sections live inside tabs:

```lua
local MainTab = Window:AddTab({
    Title = "Main",
    Icon = "◆",
    Description = "Main interface controls",
})

local GeneralSection = MainTab:AddSection({
    Title = "General",
    Description = "Buttons and settings",
})
```

You can use short forms when you only need a title:

```lua
local SettingsTab = Window:AddTab("Settings")
local AppearanceSection = SettingsTab:AddSection("Appearance")
```

## 4. Add a button

Call `AddButton` on a section. Code inside `Callback` runs when the player clicks the button.

```lua
GeneralSection:AddButton({
    Title = "Say hello",
    Description = "Click to show a notification",
    Callback = function()
        Window:Notify({
            Title = "Hello!",
            Content = "Your OzionUI button works.",
            Type = "Success",
            Duration = 3,
        })
    end,
})
```

You can keep the returned button and activate it from code:

```lua
local ResetButton = GeneralSection:AddButton({
    Title = "Reset preview",
    Callback = function()
        print("Preview reset")
    end,
})

ResetButton:Fire()
```

## 5. Add a toggle

A toggle sends `true` when on and `false` when off.

```lua
local EnabledToggle = GeneralSection:AddToggle({
    Title = "Enabled",
    Description = "Turns this feature on or off",
    Default = false,
    Flag = "enabled",
    Callback = function(enabled)
        print("Enabled:", enabled)
    end,
})
```

Read or change it later:

```lua
print(EnabledToggle:GetValue())
EnabledToggle:SetValue(true)
```

## 6. Add a slider

```lua
local VolumeSlider = GeneralSection:AddSlider({
    Title = "Volume",
    Min = 0,
    Max = 100,
    Default = 50,
    Increment = 5,
    Suffix = "%",
    Flag = "volume",
    Callback = function(value)
        print("Volume:", value)
    end,
})

VolumeSlider:SetValue(75)
```

- `Min` and `Max` define the range.
- `Increment` controls each step and must be greater than zero.
- `Suffix` is display text and does not change the numeric callback value.

## 7. Add a dropdown

```lua
local ModeDropdown = GeneralSection:AddDropdown({
    Title = "Mode",
    Values = { "Smooth", "Fast", "Custom" },
    Default = "Smooth",
    Flag = "mode",
    Callback = function(selected)
        print("Selected mode:", selected)
    end,
})
```

Replace its choices later:

```lua
ModeDropdown:Refresh({ "Low", "Medium", "High" }, "Medium")
```

## 8. Add a text input

```lua
GeneralSection:AddInput({
    Title = "Display name",
    Placeholder = "Type a name...",
    Default = "Ozion user",
    Numeric = false,
    Finished = true,
    Flag = "display_name",
    Callback = function(text)
        print("New text:", text)
    end,
})
```

- `Finished = true` calls the callback after editing finishes.
- `Finished = false` calls it while the text changes.
- `Numeric = true` filters non-numeric characters.

## 9. Add a keybind

```lua
GeneralSection:AddKeybind({
    Title = "Action key",
    Default = Enum.KeyCode.F,
    Flag = "action_key",
    ChangedCallback = function(newKey)
        print("Key changed to:", newKey.Name)
    end,
    Callback = function(key)
        print(key.Name, "was pressed")
    end,
})
```

Click the key chip and press a new key. Press `Escape` while rebinding to clear it.

## 10. Add a color picker

```lua
GeneralSection:AddColorPicker({
    Title = "Preview color",
    Default = Color3.fromRGB(132, 91, 255),
    Flag = "preview_color",
    Callback = function(color)
        print("Selected color:", color)
    end,
})
```

`SetValue` accepts a `Color3` or hex string:

```lua
local Picker = GeneralSection:AddColorPicker({ Title = "Accent" })
Picker:SetValue("#42D6A4")
```

## 11. Add information text

Paragraphs are useful for instructions, warnings, or status text:

```lua
GeneralSection:AddParagraph({
    Title = "Tip",
    Content = "Press RightShift to hide or show this window.",
    Accent = true,
})
```

## 12. Use flags

Give stateful controls unique `Flag` names. The window keeps their current values:

```lua
local enabled = Window:GetFlag("enabled")
local volume = Window:GetFlag("volume")

Window:SetFlag("enabled", true)
Window:SetFlag("volume", 80)
```

If two controls receive the same flag, OzionUI adds a numeric suffix to keep them unique. Explicit, unique names are recommended.

## 13. Show notifications

```lua
Window:Notify({
    Title = "Settings saved",
    Content = "Your interface settings were updated.",
    Type = "Success",
    Duration = 4,
})
```

Available types are `"Info"`, `"Success"`, `"Warning"`, and `"Error"`.

## 14. Change or create themes

Switch between built-in themes:

```lua
Window:SetTheme("Midnight")
-- Other built-ins: "Obsidian" and "Rose"
```

Register your own theme before creating or changing a window:

```lua
OzionUI:RegisterTheme("Emerald", {
    Accent = Color3.fromRGB(45, 220, 145),
    AccentAlt = Color3.fromRGB(64, 180, 255),
    Background = Color3.fromRGB(8, 16, 15),
    Surface = Color3.fromRGB(13, 25, 23),
})

Window:SetTheme("Emerald")
```

Any missing color uses the matching `Obsidian` value.

## 15. Export and import control values

```lua
local json = Window:ExportConfig()
print(json)

Window:ImportConfig(json)
```

OzionUI serializes values but does not write files or DataStores. Your game should send validated settings to the server and save them through the appropriate Roblox APIs.

## Complete copy-paste example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OzionUI = require(ReplicatedStorage:WaitForChild("OzionUI"))

local Window = OzionUI:CreateWindow({
    Title = "My Interface",
    Subtitle = "OZIONUI",
    Theme = "Obsidian",
    ToggleKey = Enum.KeyCode.RightShift,
})

local Main = Window:AddTab({
    Title = "Main",
    Icon = "◆",
    Description = "My main controls",
})

local General = Main:AddSection("General")

General:AddButton({
    Title = "Test button",
    Callback = function()
        Window:Notify({
            Title = "It works",
            Content = "The button callback ran successfully.",
            Type = "Success",
        })
    end,
})

General:AddToggle({
    Title = "Enabled",
    Default = false,
    Flag = "enabled",
    Callback = function(value)
        print("Enabled:", value)
    end,
})

General:AddSlider({
    Title = "Amount",
    Min = 0,
    Max = 100,
    Default = 50,
    Increment = 1,
    Flag = "amount",
    Callback = function(value)
        print("Amount:", value)
    end,
})

General:AddDropdown({
    Title = "Mode",
    Values = { "One", "Two", "Three" },
    Default = "One",
    Flag = "mode",
    Callback = function(value)
        print("Mode:", value)
    end,
})

Window:Notify({
    Title = "OzionUI loaded",
    Content = "Press RightShift to toggle the window.",
    Type = "Success",
})
```

## Adding a new component to the library itself

The built-in controls are methods on the `Section` table in `src/OzionUI.lua`, such as `Section:AddButton` and `Section:AddToggle`.

When implementing another stateful component:

1. Add a new `Section:AddYourControl(options)` method near the other controls.
2. Use `self:_row(options, height)` to get a consistently styled row.
3. Create Roblox UI instances inside that row.
4. Return a control object that implements `GetValue()` and `SetValue(value, silent)`.
5. Register it with `self.Window:_registerControl(options, control)` so flags and config export work.
6. Put every input connection in `self.Window._maid:Give(connection)` so it disconnects when the window is destroyed.
7. Use the shared `tween` and `safeCall` helpers for animation and callbacks.
8. Document and demonstrate the new component before publishing it.

For a non-stateful component, use `Section:AddButton` or `Section:AddParagraph` as the simplest patterns to copy.

## Troubleshooting

### `OzionUI must be created from a LocalScript`

The module was required on the server. Require it from a `LocalScript` in `StarterPlayerScripts`, `StarterGui`, or another client container.

### The module never loads

Make sure the ModuleScript is named exactly `OzionUI` and is directly inside `ReplicatedStorage`, or update the `WaitForChild` path to match its actual location.

### A callback does nothing

Open **View > Output** in Studio. OzionUI catches callback errors and prints them with an `[OzionUI]` prefix.

### The window is hidden

Press the configured `ToggleKey`, which is `RightShift` in the examples.

### The UI is duplicated

Make sure the LocalScript only runs once, or call `Window:Destroy()` before creating its replacement.
