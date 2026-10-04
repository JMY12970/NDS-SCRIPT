# Coming from Obsidian / Linoria

OzionUI is API-shaped like Obsidian on purpose. In most cases swapping the
loadstring URL is the entire migration.

```diff
-local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
+local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/JMY12970/Unknown/main/Library.lua"))()
```

---

## Works unchanged

```lua
Library:CreateWindow({ Title, Footer, Icon, Center, AutoShow, Resizable, Size,
                       NotifySide, ShowCustomCursor, ToggleKeybind, MenuFadeTime,
                       TabPadding, CornerRadius })

Window:AddTab(name, icon)
Window:AddKeyTab(name)
Tab:AddLeftGroupbox(name, icon) / AddRightGroupbox(name, icon)
Tab:AddLeftTabbox() / AddRightTabbox()
Tab:UpdateWarningBox({ Title, Text, Visible })
Tabbox:AddTab(name)

Groupbox:AddLabel(text | { Text, DoesWrap })
Groupbox:AddDivider()
Groupbox:AddButton({ Text, Func, DoubleClick, Tooltip })   -- :AddButton{} for sub-buttons
Groupbox:AddToggle(idx, { Text, Default, Tooltip, Risky, Disabled, Visible, Callback })
Groupbox:AddCheckbox(idx, { ... })
Groupbox:AddSlider(idx, { Text, Default, Min, Max, Rounding, Suffix, Compact, HideMax, Callback })
Groupbox:AddDropdown(idx, { Text, Values, Default, Multi, Searchable, AllowNull,
                            SpecialType, MaxVisibleDropdownItems, Callback })
Groupbox:AddInput(idx, { Text, Default, Placeholder, Numeric, Finished, MaxLength, Callback })
Groupbox:AddDependencyBox()

element:AddColorPicker(idx, { Default, Title, Transparency, Callback })
element:AddKeyPicker(idx, { Default, Mode, Text, SyncToggleState, NoUI, Callback })

Toggles.X.Value / Options.X.Value
Toggles.X:SetValue(v) / :OnChanged(fn) / :SetText(t) / :SetDisabled(b) / :SetVisible(b)
Options.X:SetValue(v) / :SetValues(t) / :GetActiveValues() / :Display()
Options.Key:GetState() / :OnClick(fn) / :DoClick()

Library:Notify(text, time) and Library:Notify({ Title, Description, Time, SoundId })
Library:SetWatermark(text) / :SetWatermarkVisibility(bool)
Library:SetNotifySide(side) / :SetDPIScale(n) / :SetFont(f) / :Toggle(bool)
Library:AddTooltip(tip, disabledTip, obj)
Library:AddDraggableButton(text, cb) / :AddDraggableMenu(name)
Library:OnUnload(fn) / :Unload()
Library.ToggleKeybind = Options.MenuKeybind
Library.Scheme.AccentColor = c ; Library:UpdateColorsUsingRegistry()
Library.Toggled / .IsMobile / .ForceCheckbox / .NotifyOnError / .CornerRadius

SaveManager:SetLibrary / :SetFolder / :SetSubFolder / :IgnoreThemeSettings
           / :SetIgnoreIndexes / :BuildConfigSection / :LoadAutoloadConfig
           / :Save / :Load / :Delete / :RefreshConfigList / :SetAutoLoadConfig
ThemeManager:SetLibrary / :SetFolder / :ApplyTheme / :ApplyToTab / :ApplyToGroupbox
            / :SaveDefault / :LoadDefault
```

---

## Differences

| Topic | Obsidian | OzionUI |
|---|---|---|
| **Layout** | sidebar tabs | sidebar tabs (same), plus a live element search box above them |
| **Icons** | Lucide pack fetched over HTTP | no extra request: built-in glyph names, asset ids, or register your own in `Library.Icons` |
| **Groupbox sizing** | manual `:Resize()` | automatic; `:Resize()` is kept as a no-op |
| **Key tab unlock** | varies | `KeyTab:Unlock()` or `Window:Unlock()` |
| **Notifications** | `Library:Notify(...)` | same, plus `Type = "Success"/"Warning"/"Error"` and a returned handle with `:ChangeTitle/:ChangeDescription/:Destroy` |
| **Colour picker value** | `Color3` | `Color3`, and `:SetValue` also accepts `"#RRGGBB"` or `{r, g, b}` |
| **Config format** | Obsidian JSON | same shape (`{version, objects:[{type, idx, value}]}`) but colours are stored as `#RRGGBB` — existing Obsidian configs are **not** binary-compatible, re-save them |
| **Animation control** | — | `Library.Animations`, `Library.AnimationSpeed`, `Library.RippleEnabled`, `Library.UseBlur` |
| **Extra helpers** | — | `Library:Tween/Ripple/Pulse/AnimateGradient`, `Library:GetMouse`, `Library:Connect`, `Library:Spawn`, `Library:SetKeybindVisibility`, `Library:SetAccent` |

### Not implemented

| Obsidian | Status |
|---|---|
| `Groupbox:AddViewport(...)` | not implemented — use `AddImage` or build your own `ViewportFrame` and parent it into `Groupbox.Container` |
| `Groupbox:AddVideo(...)` | not implemented |
| `Library:SetFont(Font.fromEnum(...))` | pass `Enum.Font` values or a name string instead |

Both missing elements are easy to add by hand:

```lua
local Holder = Instance.new("Frame")
Holder.Size = UDim2.new(1, 0, 0, 120)
Holder.BackgroundTransparency = 1
Holder.Parent = Groupbox.Container          -- elements live here
```

---

## Minimal diff for a typical script

```diff
-local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
+local repo = "https://raw.githubusercontent.com/JMY12970/Unknown/main/"
 local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
 local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
 local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
```

Everything below that line usually stays exactly as it was.
