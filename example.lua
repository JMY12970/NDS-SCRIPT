--[[
    OzionUI v1.0 — full demo script
    --------------------------------------------------------------
    Paste this into your executor. It shows off every element type,
    the notification system, theming, watermark and config system.

    Loader (replace USER/REPO with your GitHub):
        local OzionUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/OzionUI.lua"))()

    Local file alternative:
        local OzionUI = loadstring(readfile("OzionUI.lua"))()
]]

local OzionUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/OzionUI.lua"))()

--------------------------------------------------------------------
-- Window
--------------------------------------------------------------------

local Window = OzionUI:CreateWindow({
    Title = "OzionUI",
    SubTitle = "demo hub",
    Icon = "✦",
    Size = UDim2.fromOffset(600, 460),
    TabWidth = 150,
    Key = Enum.KeyCode.RightControl,   -- show / hide UI
    ShowSplash = true,                 -- animated intro (set false to skip)
    SaveConfig = true,                 -- auto-save flags below to a file
    ConfigFolder = "OzionUI",
    ConfigName = "demo",
})

--------------------------------------------------------------------
-- Home tab
--------------------------------------------------------------------

local Home = Window:AddTab({ Title = "Home", Icon = "🏠" })

local Welcome = Home:AddSection({ Title = "Welcome" })
Welcome:AddParagraph({
    Text = "OzionUI is a heavily animated UI library. Everything you see reacts: "
        .. "toggles spring, sliders pop, tabs glide, notifications slide. "
        .. "Press RightControl to hide or show this window.",
})
Welcome:AddLabel({ Text = "Every element below is 100% functional." })

local Actions = Home:AddSection({ Title = "Actions" })
Actions:AddButton({
    Title = "Simple Button",
    Description = "Ripple + press animation on click",
    Icon = "⚡",
    Callback = function()
        OzionUI:Notification({ Title = "Clicked!", Description = "That was a simple button.", Duration = 3 })
    end,
})
Actions:AddButton({
    Title = "Notification Types",
    Icon = "🔔",
    Callback = function()
        OzionUI:Notification({ Title = "Success", Description = "Saved successfully.",  Type = "Success", Duration = 3 })
        OzionUI:Notification({ Title = "Error",   Description = "Something went boom.", Type = "Error",   Duration = 3 })
        OzionUI:Notification({ Title = "Warning", Description = "Be careful out there.", Type = "Warning", Duration = 3 })
        OzionUI:Notification({ Title = "Info",    Description = "Just so you know.",   Type = "Info",    Duration = 3 })
    end,
})

local FeatureToggles = Home:AddSection({ Title = "Features" })
FeatureToggles:AddToggle({
    Title = "Killaura",
    Default = false,
    Flag = "killaura",
    Callback = function(value)
        print(("[OzionUI] killaura = %s"):format(tostring(value)))
    end,
})
FeatureToggles:AddToggle({
    Title = "Noclip",
    Default = false,
    Flag = "noclip",
    Callback = function(value)
        print(("[OzionUI] noclip = %s"):format(tostring(value)))
    end,
})

--------------------------------------------------------------------
-- Player tab
--------------------------------------------------------------------

local Player = Window:AddTab({ Title = "Player", Icon = "🏃" })

local Movement = Player:AddSection({ Title = "Movement" })
Movement:AddSlider({
    Title = "WalkSpeed",
    Min = 16, Max = 200, Default = 16,
    Decimals = 0, Suffix = " sp",
    Flag = "walkspeed",
    Callback = function(value)
        local character = game.Players.LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character.Humanoid.WalkSpeed = value
        end
    end,
})
Movement:AddSlider({
    Title = "JumpPower",
    Min = 50, Max = 300, Default = 50,
    Decimals = 0, Suffix = " jp",
    Flag = "jumppower",
    Callback = function(value)
        local character = game.Players.LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character.Humanoid.JumpPower = value
        end
    end,
})
Movement:AddDropdown({
    Title = "Animation Pack",
    Values = { "Default", "Ninja", "Zombie", "Robot" },
    Default = "Default",
    Flag = "animpk",
    Callback = function(value)
        print(("[OzionUI] animation pack = %s"):format(value))
    end,
})
Movement:AddTextbox({
    Title = "Custom Chat Prefix",
    Placeholder = "type a prefix...",
    Flag = "chatprefix",
    Callback = function(text)
        print(("[OzionUI] chat prefix = %s"):format(text))
    end,
})

local Friends = Player:AddSection({ Title = "Whitelist (multi dropdown)" })
Friends:AddDropdown({
    Title = "Trusted Users",
    Options = { "Alex", "Brook", "Casey", "Dee", "Eli", "Finn" },
    Multi = true,
    Flag = "whitelist",
    Callback = function(selected)
        print("[OzionUI] trusted users: " .. table.concat(selected, ", "))
    end,
})

--------------------------------------------------------------------
-- Visuals tab
--------------------------------------------------------------------

local Visuals = Window:AddTab({ Title = "Visuals", Icon = "🎨" })

local ESP = Visuals:AddSection({ Title = "ESP" })
ESP:AddToggle({
    Title = "Enabled",
    Default = true,
    Flag = "esp",
    Callback = function(value)
        print(("[OzionUI] esp = %s"):format(tostring(value)))
    end,
})
ESP:AddColorPicker({
    Title = "ESP Color",
    Default = Color3.fromRGB(138, 99, 255),
    Flag = "espcolor",
    Callback = function(color)
        print(("[OzionUI] esp color = %d, %d, %d"):format(color.R * 255, color.G * 255, color.B * 255))
    end,
})
ESP:AddSlider({
    Title = "ESP Opacity",
    Min = 0, Max = 1, Default = 0.75,
    Decimals = 2,
    Flag = "espopacity",
    Callback = function(value)
        print(("[OzionUI] esp opacity = %.2f"):format(value))
    end,
})

local Keybinds = Visuals:AddSection({ Title = "Keybinds" })
Keybinds:AddKeybind({
    Title = "Toggle ESP",
    Default = Enum.KeyCode.E,
    Mode = "Toggle",          -- Always | Toggle | Hold (right-click the chip to cycle)
    Flag = "espkey",
    Callback = function(stateOrKey)
        print("[OzionUI] esp keybind fired: " .. tostring(stateOrKey))
    end,
})
Keybinds:AddKeybind({
    Title = "Panic",
    Default = Enum.KeyCode.Delete,
    Mode = "Always",
    Flag = "panickey",
    Callback = function()
        OzionUI:Notification({ Title = "Panic!", Description = "Panic key was pressed.", Duration = 2 })
    end,
})

--------------------------------------------------------------------
-- Settings tab
--------------------------------------------------------------------

local Settings = Window:AddTab({ Title = "Settings", Icon = "⚙️" })

local ThemeSection = Settings:AddSection({ Title = "Theme" })
local themeDropdown
themeDropdown = ThemeSection:AddDropdown({
    Title = "Theme Preset",
    Values = { "Midnight", "Amethyst", "Ocean", "Emerald", "Sakura", "Sunset", "Carbon" },
    Default = "Midnight",
    Callback = function(name)
        OzionUI:SetTheme(name)
    end,
})
ThemeSection:AddToggle({
    Title = "Rainbow Accent",
    Default = false,
    Callback = function(value)
        OzionUI:SetRainbow(value)
    end,
})
ThemeSection:AddToggle({
    Title = "Watermark",
    Default = false,
    Callback = function(value)
        if value then
            OzionUI:CreateWatermark("OzionUI")
        else
            OzionUI:DestroyWatermark()
        end
    end,
})

local ConfigSection = Settings:AddSection({ Title = "Configs" })
ConfigSection:AddLabel({ Text = "Configs auto-save 1.25s after any flagged change." })
ConfigSection:AddButton({
    Title = "Save Config",
    Icon = "💾",
    Callback = function()
        local ok = OzionUI:SaveConfig("demo")
        OzionUI:Notification({
            Title = ok and "Saved" or "Save failed",
            Description = ok and "Wrote workspace/OzionUI/demo.json" or "This executor has no writefile().",
            Type = ok and "Success" or "Error",
            Duration = 3,
        })
    end,
})
ConfigSection:AddButton({
    Title = "Load Config",
    Icon = "📂",
    Callback = function()
        local ok = OzionUI:LoadConfig("demo")
        OzionUI:Notification({
            Title = ok and "Loaded" or "Load failed",
            Type = ok and "Success" or "Error",
            Duration = 3,
        })
    end,
})
ConfigSection:AddButton({
    Title = "Destroy UI",
    Icon = "✕",
    Callback = function()
        OzionUI:Destroy()
    end,
})

--------------------------------------------------------------------
-- Go!
--------------------------------------------------------------------

OzionUI:Notification({
    Title = "OzionUI loaded",
    Description = "v" .. OzionUI.Version .. " — press RightControl to toggle the UI.",
    Duration = 5,
})
