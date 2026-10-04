--[[
    OzionUI -- minimal starter.

    1. Copy the whole of OzionUI.lua into your executor.
    2. Paste this underneath it.
    3. Execute, then start replacing the placeholder callbacks with your code.
]]

local Library = OzionUI or (getgenv and getgenv().OzionUI)
assert(Library, "Paste the contents of OzionUI.lua above this line first.")

local SaveManager = Library.SaveManager
local ThemeManager = Library.ThemeManager

-- 1. the window -----------------------------------------------------------

local Window = Library:CreateWindow({
	Title = "My Script",
	Footer = "v1.0.0",
	Icon = "rocket",
	Size = UDim2.fromOffset(620, 500),
	AutoShow = true,
	ToggleKeybind = Enum.KeyCode.RightShift,
})

-- 2. tabs -----------------------------------------------------------------

local MainTab = Window:AddTab("Main", "home")
local SettingsTab = Window:AddTab("Settings", "settings")

-- 3. groupboxes and elements ----------------------------------------------

local Box = MainTab:AddLeftGroupbox("Features", "zap")

Box:AddToggle("AutoFarm", {
	Text = "Auto farm",
	Default = false,
	Tooltip = "Turn the main loop on.",
	Callback = function(Value)
		print("auto farm:", Value)
	end,
})

Box:AddSlider("Speed", {
	Text = "Speed",
	Default = 16,
	Min = 16,
	Max = 100,
	Rounding = 0,
	Callback = function(Value)
		print("speed:", Value)
	end,
})

Box:AddDropdown("Mode", {
	Text = "Mode",
	Values = { "Safe", "Fast", "Insane" },
	Default = 1,
	Callback = function(Value)
		print("mode:", Value)
	end,
})

Box:AddButton({
	Text = "Do the thing",
	Func = function()
		Library:Notify("Did the thing.", 3)
	end,
})

-- colour and key pickers attach to any element
Box:AddColorPicker("HighlightColor", {
	Default = Color3.fromRGB(125, 90, 255),
	Title = "Highlight",
})

Box:AddKeyPicker("PanicKey", {
	Default = "P",
	Mode = "Toggle",
	Text = "Panic",
})

-- 4. configs and themes ---------------------------------------------------
-- SaveManager and ThemeManager are already pointed at the library.

SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder("MyScript")
SaveManager:SetFolder("MyScript/game")

SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)

-- 5. finish ---------------------------------------------------------------

Library:SetWatermark("My Script | OzionUI")
SaveManager:LoadAutoloadConfig()

Library:Notify("Loaded. Press Right Shift to toggle.", 5)

-- read values any time:
--   Library.Toggles.AutoFarm.Value
--   Library.Options.Speed.Value
--   Library.Options.HighlightColor.Value
