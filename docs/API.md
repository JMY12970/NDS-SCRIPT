# OzionUI API reference

Everything the library exposes. Types are Luau-ish: `string?` means optional.

- [Library](#library)
- [Window](#window)
- [Tab](#tab)
- [Groupbox / Tabbox](#groupbox--tabbox)
- [Elements](#elements)
- [Attachable pickers](#attachable-pickers)
- [SaveManager](#savemanager)
- [ThemeManager](#thememanager)

---

## Library

### Creation

| Method | Returns | Notes |
|---|---|---|
| `Library:CreateWindow(config)` | `Window` | only one window per load; a second call warns and returns the first |

**`config`**

| Field | Type | Default | Description |
|---|---|---|---|
| `Title` | `string` | `"OzionUI"` | title bar text, drawn with an animated gradient |
| `Footer` | `string?` | – | bottom bar text; omit to remove the bar |
| `Icon` | `string\|number?` | – | title bar icon, see [icons](#icons) |
| `Size` | `UDim2` | `fromOffset(640, 520)` | initial size |
| `MinSize` | `Vector2` | `(460, 340)` | resize floor |
| `Position` | `UDim2?` | centred | initial position |
| `Center` | `boolean` | `true` | ignored when `Position` is given |
| `AutoShow` | `boolean` | `true` | open the menu right away |
| `Resizable` | `boolean` | `true` | show the bottom-right grip |
| `CornerRadius` | `number` | `6` | applies to the whole menu |
| `TabPadding` | `number` | `4` | gap between sidebar tabs |
| `SidebarWidth` | `number` | `152` | |
| `MenuFadeTime` | `number` | `0.25` | open/close duration |
| `NotifySide` | `"Left"\|"Right"` | `"Right"` | |
| `ShowCustomCursor` | `boolean` | `true` | custom cursor + comet trail while open |
| `ToggleKeybind` | `Enum.KeyCode` | `RightControl` | |
| `Animations` | `boolean` | `true` | |
| `AnimationSpeed` | `number` | `1` | multiplier |
| `ForceMobileButton` | `boolean` | `false` | show the floating button on desktop too |

### State

| Field | Type | Description |
|---|---|---|
| `Library.Toggles` / `_G.Toggles` | `table` | every toggle & checkbox by index |
| `Library.Options` / `_G.Options` | `table` | every other indexed element |
| `Library.Toggled` | `boolean` | is the menu visible |
| `Library.Unloaded` | `boolean` | flips to `true` on unload — loop on `while not Library.Unloaded` |
| `Library.IsMobile` | `boolean` | touch without keyboard |
| `Library.Scheme` | `table` | live colours, see [themes](#thememanager) |
| `Library.Window` | `Window?` | |
| `Library.ActiveTab` | `Tab?` | |
| `Library.Version` | `string` | |
| `Library.GuiParentMethod` | `string` | `"gethui"`, `"coregui"`, `"playergui"` or `"none"` |

### Behaviour flags

```lua
Library.Animations               = true
Library.AnimationSpeed           = 1
Library.RippleEnabled            = true
Library.UseBlur                  = true
Library.ShowCustomCursor         = true
Library.ShowToggleFrameInKeybinds = true
Library.NotifyOnError            = true
Library.ForceCheckbox            = false   -- render every toggle as a checkbox
Library.NotifySide               = "Right"
Library.CornerRadius             = 6
Library.MenuKeybind              = Enum.KeyCode.RightControl
Library.ToggleKeybind            = nil     -- or a KeyPicker object
```

### Methods

| Method | Description |
|---|---|
| `Library:Toggle(state?)` | show / hide the menu; no argument flips it |
| `Library:SetVisible(state)` | alias |
| `Library:Notify(text, time?, soundId?)` | quick notification |
| `Library:Notify({Title, Description, Time, Type, SoundId, Volume})` | full form; `Type` is `Normal`/`Success`/`Warning`/`Error`. Returns `{ChangeTitle, ChangeDescription, Destroy}` |
| `Library:SetWatermark(text)` | |
| `Library:SetWatermarkVisibility(bool)` | |
| `Library:SetKeybindVisibility(bool)` | the floating keybind list |
| `Library:SetNotifySide("Left"\|"Right")` | |
| `Library:SetAccent(Color3)` | accent + full restyle |
| `Library:SetFont(Enum.Font \| name)` | |
| `Library:SetDPIScale(percent)` | `100` = 1× |
| `Library:UpdateColorsUsingRegistry()` | reapply `Library.Scheme` everywhere |
| `Library:AddToRegistry(instance, {Prop = "SchemeKey"})` | register your own instances for theming; values may also be `function(scheme)` |
| `Library:AddTooltip(text, disabledText, instance)` | |
| `Library:AddDraggableButton(text, callback)` | floating button, returns `{SetText, SetVisible, Destroy}` |
| `Library:AddDraggableMenu(name)` | floating mini-groupbox, accepts all `Add*` element calls |
| `Library:OnUnload(callback)` | |
| `Library:Unload()` / `Library:Destroy()` | |
| `Library:SafeCallback(fn, ...)` | pcall + notify on error |
| `Library:Spawn(fn, ...)` | `task.spawn` + SafeCallback |
| `Library:Delay(seconds, fn)` | |
| `Library:Connect(signal, fn)` | tracked connection, auto-disconnected on unload |
| `Library:MakeDraggable(frame, handle?)` | |
| `Library:GetMouse()` | `Vector2` in ScreenGui space (inset corrected) |

### Animation helpers

| Method | Description |
|---|---|
| `Library:Tween(obj, props, duration?, preset?, repeat?, reverses?)` | `preset` = `"Smooth"`, `"Snappy"`, `"Bounce"`, `"Soft"`, `"Linear"`, `"Elastic"` or `{EasingStyle, EasingDirection}` |
| `Library:Ripple(button, x?, y?, color?)` | expanding click ripple (parent needs `ClipsDescendants`) |
| `Library:Pulse(obj, color?)` | one-shot glow ring |
| `Library:AnimateGradient(gradient, seconds?)` | endless rotation |

### Colour helpers

```lua
Library:GetShade(color, amount)   -- amount is a value delta, -1 .. 1
Library:GetDarkerColor(color)
Library:GetLighterColor(color)
Library:ColorToHex(color)         --> "#7D5AFF"
Library:HexToColor("#7D5AFF")     --> Color3 (nil when invalid)
Library:Clamp(v, min, max)
Library:Round(v, decimals)
```

### Icons

`Library:GetIcon(icon)` returns `image, glyph` (exactly one is non-nil).

Resolution order: number → `rbxassetid://n`; a string starting with
`rbxassetid://`, `rbxasset://` or `http` → used as-is; a key of `Library.Icons`
→ glyph; otherwise the first letter.

```lua
Library.Icons["skull"] = "rbxassetid://7733658504"   -- register real assets
```

Built-in names: `home` `house` `settings` `gear` `user` `users` `shield` `sword`
`crosshair` `target` `eye` `zap` `bolt` `flame` `star` `heart` `info` `key`
`lock` `palette` `save` `folder` `list` `menu` `map` `globe` `clock` `bell`
`search` `trash` `check` `cross` `plus` `minus` `arrow` `chevron` `code`
`terminal` `bug` `skull` `car` `rocket` `wrench` `misc` `box` `grid` `fish`
`coin` `money` `farm` `bag` `gamepad` `music` `moon` `sun` `cloud` `droplet`
`snowflake` `anchor` `flag` `bookmark` `book` `camera` `monitor` `cpu`
`database` `link` `refresh` `power` `play` `pause` `stop`

---

## Window

| Method | Returns | Description |
|---|---|---|
| `Window:AddTab(name, icon?)` | `Tab` | |
| `Window:AddKeyTab(name?)` | `Tab` | locks every other tab until `Tab:Unlock()` |
| `Window:SetTitle(text)` | | |
| `Window:SetFooter(text)` | | |
| `Window:SetSize(UDim2)` | | animated |
| `Window:Toggle(state?)` | | |
| `Window:Show()` / `Window:Hide()` | | |
| `Window:Destroy()` | | same as `Library:Unload()` |
| `Window.Tabs` | `{Tab}` | |
| `Window.ActiveTab` | `Tab?` | |

---

## Tab

| Method | Returns |
|---|---|
| `Tab:AddLeftGroupbox(title, icon?)` | `Groupbox` |
| `Tab:AddRightGroupbox(title, icon?)` | `Groupbox` |
| `Tab:AddLeftTabbox()` | `Tabbox` |
| `Tab:AddRightTabbox()` | `Tabbox` |
| `Tab:UpdateWarningBox({Title, Text, Visible})` | pushes a warning banner above the columns |
| `Tab:Show(instant?)` | select this tab |
| `Tab:SetVisible(bool)` | hide the sidebar button |
| `Tab:Unlock()` | key tabs only |

---

## Groupbox / Tabbox

```lua
local Groupbox = Tab:AddLeftGroupbox("Title", "icon")
Groupbox:SetTitle("New title")
Groupbox:SetVisible(false)
Groupbox:Resize()      -- no-op, kept for Linoria compatibility
Groupbox:Destroy()

local Tabbox = Tab:AddRightTabbox()
local Page   = Tabbox:AddTab("Page name")   -- Page accepts all element calls
```

---

## Elements

Every element returns an object with at least:

```lua
element.Value           -- current value (where applicable)
element.Type            -- "Toggle" | "Slider" | ...
element:OnChanged(fn)   -- fires immediately with the current value, then on change
element:SetVisible(bool)
element:SetDisabled(bool)
element:Destroy()
```

### `AddLabel(text | {Text, DoesWrap, Risky, Tooltip, Visible})`
`:SetText(text)`. Labels are the usual anchor for a standalone colour picker or
keybind.

### `AddDivider(text?)`
Gradient separator with an optional centred caption.

### `AddButton({Text, Func, DoubleClick, Tooltip, DisabledTooltip, Disabled, Visible})`
`:SetText(t)`, `:SetDisabled(b)`, `:AddButton({...})` to place a second button
beside the first (they split the row). `DoubleClick` turns click one into a
confirmation.

### `AddToggle(index, {...})` / `AddCheckbox(index, {...})`

| Field | Type | Default |
|---|---|---|
| `Text` | `string` | `"Toggle"` |
| `Default` | `boolean` | `false` |
| `Tooltip` / `DisabledTooltip` | `string?` | |
| `Risky` | `boolean` | `false` (red label) |
| `Disabled` / `Visible` | `boolean` | |
| `Callback` | `function(boolean)` | |

`:SetValue(bool, silent?)`, `:SetText(t)`, `:SetDisabled(b)`, `:OnChanged(fn)`,
`:AddColorPicker(...)`, `:AddKeyPicker(...)`.

### `AddSlider(index, {...})`

| Field | Type | Default |
|---|---|---|
| `Text` | `string` | `"Slider"` |
| `Default` / `Min` / `Max` | `number` | `Min` / `0` / `100` |
| `Rounding` | `number` | `0` decimals |
| `Suffix` | `string` | `""` |
| `Compact` | `boolean` | `false` — label inside the bar |
| `HideMax` | `boolean` | `false` — hide the ` / max` part |
| `Callback` | `function(number)` | |

`:SetValue(n, silent?)`, `:SetMin(n)`, `:SetMax(n)`, `:SetText(t)`.

### `AddDropdown(index, {...})`

| Field | Type | Default |
|---|---|---|
| `Values` | `{any}` | `{}` |
| `Default` | `number\|string\|{string}` | – (index, value, or list for multi) |
| `Multi` | `boolean` | `false` |
| `Searchable` | `boolean` | `false` |
| `AllowNull` | `boolean` | `false` — clicking the selected item clears it |
| `MaxVisibleDropdownItems` | `number` | `8` |
| `SpecialType` | `"Player"\|"Team"` | auto-populates and refreshes |
| `IncludeSelf` | `boolean` | `false` — include LocalPlayer in player lists |
| `Callback` | `function(value)` | |

`:SetValue(v, silent?)`, `:SetValues(list?)`, `:AddValue(v)`, `:RemoveValue(v)`,
`:GetActiveValues()`, `:Display()`, `:Toggle(state?)`.

Single-select `Value` is the chosen item. Multi-select `Value` is a set:
`{ Boxes = true, Names = true }`.

### `AddInput(index, {...})`

| Field | Type | Default |
|---|---|---|
| `Default` | `string` | `""` |
| `Placeholder` | `string` | `""` |
| `Numeric` | `boolean` | `false` — strips non-numeric characters |
| `Finished` | `boolean` | `false` — only commit on Enter |
| `MaxLength` | `number?` | |
| `ClearTextOnFocus` | `boolean` | `false` |
| `Callback` | `function(string)` | |

`:SetValue(s, silent?)`, `:SetText(label)`, `:GetNumber()`.

### `AddImage(index?, {Image, Height, ScaleType, Transparency, Transparent})`
`:SetImage(asset)`.

### `AddDependencyBox()`
Returns a container that accepts all element calls plus
`:SetupDependencies({ {element, expectedValue}, ... })` and `:Update()`.

---

## Attachable pickers

### `element:AddColorPicker(index, {...})`

| Field | Type |
|---|---|
| `Default` | `Color3` |
| `Title` | `string` |
| `Transparency` | `number?` — pass `0`–`1` to add an alpha bar |
| `Callback` | `function(Color3, number?)` |

`:SetValue(Color3 \| "#RRGGBB" \| {r,g,b}, alpha?)`, `:GetValue()`, `:Toggle(state?)`.

### `element:AddKeyPicker(index, {...})`

| Field | Type | Default |
|---|---|---|
| `Default` | `string` | `"None"` — `"F"`, `"MB2"`, `"RightControl"` … |
| `Mode` | `"Toggle"\|"Hold"\|"Always"` | `"Toggle"` |
| `Text` | `string` | label in the keybind list |
| `SyncToggleState` | `boolean` | mirror the parent toggle |
| `NoUI` | `boolean` | keep it out of the keybind list |
| `Callback` | `function(boolean)` | |

`:GetState()`, `:SetValue({key, mode})`, `:SetText(t)`, `:OnClick(fn)`,
`:DoClick()`, `:OnChanged(fn)`.

Left-click the button to rebind (Escape clears), right-click for the mode menu.

---

## SaveManager

```lua
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("Hub/" .. game.PlaceId)   -- Hub/<id>/settings/*.json
SaveManager:SetSubFolder("pvp")                 -- optional extra nesting
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:BuildConfigSection(Tab, "Left"|"Right")
```

| Method | Returns |
|---|---|
| `SaveManager:Save(name)` | `ok, err` |
| `SaveManager:Load(name)` | `ok, err` |
| `SaveManager:Delete(name)` | `ok, err` |
| `SaveManager:RefreshConfigList()` | `{string}` |
| `SaveManager:SetAutoLoadConfig(name)` | |
| `SaveManager:GetAutoloadConfig()` | `string?` |
| `SaveManager:DeleteAutoLoadConfig()` | |
| `SaveManager:LoadAutoloadConfig()` | `boolean` |
| `SaveManager:BuildFolderTree()` | |
| `SaveManager:IsSupported()` | `boolean` |

Saved types: `Toggle`, `Slider`, `Dropdown`, `Input`, `ColorPicker`, `KeyPicker`.
Extend `SaveManager.Parser` with your own `{Save = f, Load = f}` pair for custom
element types.

---

## ThemeManager

```lua
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("Hub")            -- Hub/themes/*.json
ThemeManager:ApplyTheme("Tokyo Night")
ThemeManager:ApplyToTab(Tab, "Left"|"Right")
ThemeManager:ApplyToGroupbox(Groupbox)
```

| Method | Returns |
|---|---|
| `ThemeManager:ApplyTheme(name)` | `ok, err` — built-in or saved custom |
| `ThemeManager:SaveCustomTheme(name)` | `ok, err` |
| `ThemeManager:Delete(name)` | `ok, err` |
| `ThemeManager:GetCustomThemeList()` | `{string}` |
| `ThemeManager:SaveDefault(name)` | |
| `ThemeManager:LoadDefault()` | |
| `ThemeManager.BuiltInThemes` | `{[name] = {hex colours}}` |

`Library.Scheme` keys: `BackgroundColor`, `MainColor`, `AccentColor`,
`OutlineColor`, `FontColor`, `Font`, plus the helpers `Red`, `Green`, `Dark`,
`White`, `Black`.

Register a theme of your own:

```lua
ThemeManager.BuiltInThemes["Neon"] = {
    BackgroundColor = "05080A",
    MainColor       = "0B1115",
    AccentColor     = "00F0A0",
    OutlineColor    = "18242B",
    FontColor       = "E8FFF8",
}
```
