--[[
    OzionUI -- starter template.

    Copy this file, rename it, and start filling in your own features.
    Everything you do not need can be deleted; nothing here is mandatory
    except the first three lines and CreateWindow.
]]

local Repo = "https://raw.githubusercontent.com/JMY12970/Unknown/main/"

local Library = loadstring(game:HttpGet(Repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(Repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(Repo .. "addons/SaveManager.lua"))()

-- 1. the window -----------------------------------------------------------

local Window = Library:CreateWindow({
	Title = "My Script",
	Footer = "v1.0.0",
	Icon = "rocket",
	Size = UDim2.fromOffset(620, 500),
	AutoShow = true,
	ToggleKeybind = Enum.KeyCode.RightControl,
})

-- 2. tabs -----------------------------------------------------------------

local Tabs = {
	Main = Window:AddTab("Main", "home"),
	Settings = Window:AddTab("Settings", "settings"),
}

-- 3. your features --------------------------------------------------------

local Box = Tabs.Main:AddLeftGroupbox("Features", "zap")

Box:AddToggle("MyToggle", {
	Text = "Do the thing",
	Default = false,
	Tooltip = "Explain what this does",
	Callback = function(Value)
		print("toggle is now", Value)
	end,
})

Box:AddSlider("MySlider", {
	Text = "Speed",
	Default = 50,
	Min = 0,
	Max = 100,
	Rounding = 0,
	Callback = function(Value)
		print("speed is now", Value)
	end,
})

Box:AddButton({
	Text = "Run once",
	Func = function()
		Library:Notify("Done!", 3)
	end,
})

-- 4. a loop that respects the toggle --------------------------------------

task.spawn(function()
	while not Library.Unloaded do
		if Library.Toggles.MyToggle.Value then
			-- ... do the thing, once per second ...
		end
		task.wait(1)
	end
end)

-- 5. settings tab: configs + theme ----------------------------------------

SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder("MyScript")
SaveManager:SetFolder("MyScript/" .. tostring(game.PlaceId))

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

SaveManager:LoadAutoloadConfig()

-- 6. clean up after yourself ----------------------------------------------

Library:OnUnload(function()
	-- stop loops, remove ESP drawings, restore walkspeed, ...
	print("script unloaded")
end)
