--[[
    OzionUI -- full feature showcase.

    Paste this straight into your executor to see every element in action,
    or copy the bits you need into your own script.
]]

-- While this branch has not been merged into main yet, use:
--   ".../JMY12970/Unknown/arena/01a1049a-unknown/"
local Repo = "https://raw.githubusercontent.com/JMY12970/Unknown/main/"

local Library = loadstring(game:HttpGet(Repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(Repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(Repo .. "addons/SaveManager.lua"))()

--//////////////////////////////////////////////////////////////// window //

local Window = Library:CreateWindow({
	Title = "OzionUI",
	Footer = "showcase build",
	Icon = "rocket",
	NotifySide = "Right",
	ShowCustomCursor = true,
	Size = UDim2.fromOffset(680, 540),
	Resizable = true,
	AutoShow = true,
	ToggleKeybind = Enum.KeyCode.RightControl,
})

local Tabs = {
	Main = Window:AddTab("Main", "home"),
	Visuals = Window:AddTab("Visuals", "eye"),
	Players = Window:AddTab("Players", "user"),
	Settings = Window:AddTab("Settings", "settings"),
}

--////////////////////////////////////////////////////////////////// main //

local LeftBox = Tabs.Main:AddLeftGroupbox("Automation", "zap")

LeftBox:AddToggle("AutoFarm", {
	Text = "Auto farm",
	Default = false,
	Tooltip = "Collects everything nearby on a loop.",
	Callback = function(Value)
		print("[example] auto farm:", Value)
	end,
})

LeftBox:AddSlider("FarmRadius", {
	Text = "Farm radius",
	Default = 60,
	Min = 10,
	Max = 250,
	Rounding = 0,
	Suffix = " studs",
	Callback = function(Value)
		print("[example] radius:", Value)
	end,
})

LeftBox:AddDropdown("FarmMode", {
	Text = "Mode",
	Values = { "Closest", "Highest value", "Random" },
	Default = 1,
	Callback = function(Value)
		print("[example] mode:", Value)
	end,
})

LeftBox:AddDivider("Danger zone")

LeftBox:AddToggle("RiskyToggle", {
	Text = "Server hop on detection",
	Risky = true,
	Tooltip = "Marked red because it can get you flagged.",
})

-- dependency boxes only show while their condition is met
local SpeedBox = LeftBox:AddDependencyBox()
SpeedBox:AddSlider("WalkSpeed", {
	Text = "Walk speed",
	Default = 16,
	Min = 16,
	Max = 120,
	Rounding = 0,
})
SpeedBox:AddToggle("NoClip", { Text = "No clip" })

local SpeedToggle = LeftBox:AddToggle("CustomSpeed", { Text = "Custom walk speed" })
SpeedBox:SetupDependencies({ { SpeedToggle, true } })

local RightBox = Tabs.Main:AddRightGroupbox("Actions", "terminal")

local MainButton = RightBox:AddButton({
	Text = "Rejoin server",
	Tooltip = "Teleports you back into the same place.",
	Func = function()
		Library:Notify({ Title = "Rejoining", Description = "See you in a second.", Time = 3, Type = "Success" })
	end,
})

MainButton:AddButton({
	Text = "Server hop",
	Func = function()
		Library:Notify("Looking for a new server...", 3)
	end,
})

RightBox:AddButton({
	Text = "Unload OzionUI",
	DoubleClick = true,
	Tooltip = "Click twice to confirm.",
	Func = function()
		Library:Unload()
	end,
})

RightBox:AddInput("WebhookUrl", {
	Text = "Webhook",
	Placeholder = "https://discord.com/api/webhooks/...",
	Finished = true,
	Callback = function(Value)
		print("[example] webhook set:", Value)
	end,
})

RightBox:AddLabel("Press Right Ctrl to hide the menu.", true)

--/////////////////////////////////////////////////////////////// visuals //

local VisualsBox = Tabs.Visuals:AddLeftTabbox()
local EspTab = VisualsBox:AddTab("ESP")
local WorldTab = VisualsBox:AddTab("World")

local EspToggle = EspTab:AddToggle("EspEnabled", {
	Text = "Enable ESP",
	Default = false,
})

EspToggle:AddColorPicker("EspColor", {
	Default = Color3.fromRGB(125, 90, 255),
	Title = "ESP colour",
	Callback = function(Value)
		print("[example] esp colour:", Value)
	end,
})

EspToggle:AddKeyPicker("EspKey", {
	Default = "F",
	Mode = "Toggle",
	Text = "ESP",
	SyncToggleState = true,
})

EspTab:AddDropdown("EspParts", {
	Text = "Draw",
	Values = { "Box", "Name", "Health", "Distance", "Tracer" },
	Default = { "Box", "Name" },
	Multi = true,
	Searchable = true,
})

EspTab:AddSlider("EspDistance", {
	Text = "Max distance",
	Default = 500,
	Min = 50,
	Max = 2000,
	Rounding = 0,
	HideMax = true,
})

WorldTab:AddToggle("Fullbright", { Text = "Fullbright" })
WorldTab:AddSlider("FieldOfView", {
	Text = "Field of view",
	Default = 70,
	Min = 30,
	Max = 120,
	Rounding = 0,
	Compact = true,
})
WorldTab:AddLabel("Ambient"):AddColorPicker("AmbientColor", {
	Default = Color3.fromRGB(80, 80, 110),
	Title = "Ambient colour",
	Transparency = 0,
})

local HudBox = Tabs.Visuals:AddRightGroupbox("HUD", "monitor")

HudBox:AddToggle("ShowWatermark", {
	Text = "Watermark",
	Default = true,
	Callback = function(Value)
		Library:SetWatermarkVisibility(Value)
	end,
})

HudBox:AddToggle("ShowKeybinds", {
	Text = "Keybind list",
	Default = false,
	Callback = function(Value)
		Library:SetKeybindVisibility(Value)
	end,
})

HudBox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightControl",
	Mode = "Toggle",
	Text = "Menu",
	NoUI = true,
})

-- make that key picker the menu toggle
Library.ToggleKeybind = Library.Options.MenuKeybind

--/////////////////////////////////////////////////////////////// players //

local PlayerBox = Tabs.Players:AddLeftGroupbox("Target", "user")

PlayerBox:AddDropdown("TargetPlayer", {
	Text = "Player",
	SpecialType = "Player",
	Searchable = true,
	AllowNull = true,
	Tooltip = "Refreshes automatically as people join and leave.",
})

PlayerBox:AddButton({
	Text = "Teleport to player",
	Func = function()
		local Target = Library.Options.TargetPlayer.Value
		if not Target then
			return Library:Notify({ Title = "No target", Description = "Pick someone first.", Time = 3, Type = "Warning" })
		end
		Library:Notify("Teleporting to " .. Target, 3)
	end,
})

local FriendBox = Tabs.Players:AddRightGroupbox("Friends", "heart")
FriendBox:AddInput("FriendName", { Text = "Add friend", Placeholder = "username", Finished = true })
FriendBox:AddDropdown("FriendList", { Text = "Friend list", Values = {}, AllowNull = true, Multi = true })

--////////////////////////////////////////////////////////////// settings //

Tabs.Settings:UpdateWarningBox({
	Title = "Reminder",
	Text = "Configs are stored per game. Themes are shared across every script.",
	Visible = true,
})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("OzionUI")
SaveManager:SetFolder("OzionUI/showcase")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

local MenuBox = Tabs.Settings:AddLeftGroupbox("Menu", "settings")
MenuBox:AddButton({
	Text = "Unload",
	DoubleClick = true,
	Func = function()
		Library:Unload()
	end,
})

Library:OnUnload(function()
	print("[example] OzionUI unloaded")
end)

--///////////////////////////////////////////////////////////////// final //

Library:SetWatermark("OzionUI | showcase | " .. game.PlaceId)
Library:SetWatermarkVisibility(true)

SaveManager:LoadAutoloadConfig()

Library:Notify({
	Title = "OzionUI loaded",
	Description = "Press Right Ctrl to toggle the menu.",
	Time = 6,
	Type = "Success",
})

return Library
