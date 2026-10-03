local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

-- Setup Remote Reference
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local AdminRemote = ReplicatedStorage:FindFirstChild("AdminPanelRemote")

local Window = Library:CreateWindow({
	Title = "Disaster Sandbox Admin",
	Footer = "Obsidian UI | Client Executor",
	NotifySide = "Right",
	ShowCustomCursor = true,
})

local Tabs = {
	Main = Window:AddTab("Main", "terminal"),
	Disasters = Window:AddTab("Disasters", "flame"),
	Players = Window:AddTab("Players", "user"),
	World = Window:AddTab("World & Physics", "globe"),
	Fun = Window:AddTab("Fun", "zap"),
	["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

---------------------------------------------------------
-- 1. MAIN EXECUTOR TAB
---------------------------------------------------------
local ExecGroup = Tabs.Main:AddGroupbox({
	Side = "Left",
	Name = "Loadstring Engine",
	IconName = "code",
})

ExecGroup:AddInput("ExecCodeInput", {
	Default = "",
	Text = "Lua Code",
	Placeholder = "Enter server Lua code here...",
})

ExecGroup:AddButton({
	Text = "Run Server Loadstring",
	Func = function()
		local code = Options.ExecCodeInput.Value
		if code ~= "" and AdminRemote then
			AdminRemote:FireServer("ExecuteCode", code)
		end
	end,
})

---------------------------------------------------------
-- 2. DISASTERS TAB
---------------------------------------------------------
local SpawnerGroup = Tabs.Disasters:AddGroupbox({
	Side = "Left",
	Name = "Spawner Controls",
	IconName = "alert-triangle",
})

local ModifierGroup = Tabs.Disasters:AddGroupbox({
	Side = "Right",
	Name = "Disaster Settings",
	IconName = "sliders",
})

local disasters = {"Tsunami", "Tornado", "Meteor", "Volcano", "Acid Rain", "Sandstorm", "Blizzard"}
for _, name in ipairs(disasters) do
	SpawnerGroup:AddButton({
		Text = "Trigger " .. name,
		Func = function()
			if AdminRemote then AdminRemote:FireServer("TriggerDisaster", name) end
		end
	})
end

ModifierGroup:AddSlider("DisasterIntensity", {
	Text = "Disaster Intensity",
	Default = 5,
	Min = 1,
	Max = 10,
	Rounding = 0,
})
Options.DisasterIntensity:OnChanged(function()
	if AdminRemote then AdminRemote:FireServer("SetDisasterIntensity", Options.DisasterIntensity.Value) end
end)

ModifierGroup:AddSlider("DisasterSpeed", {
	Text = "Disaster Speed",
	Default = 1,
	Min = 1,
	Max = 5,
	Rounding = 1,
})
Options.DisasterSpeed:OnChanged(function()
	if AdminRemote then AdminRemote:FireServer("SetDisasterSpeed", Options.DisasterSpeed.Value) end
end)

ModifierGroup:AddToggle("AutoDisaster", {
	Text = "Auto Disaster Loop",
	Default = false,
})
Toggles.AutoDisaster:OnChanged(function()
	if AdminRemote then AdminRemote:FireServer("ToggleAutoDisasters", Toggles.AutoDisaster.Value) end
end)

---------------------------------------------------------
-- 3. PLAYERS TAB
---------------------------------------------------------
local TargetGroup = Tabs.Players:AddGroupbox({
	Side = "Left",
	Name = "Player Targeting",
	IconName = "users",
})

local SelfGroup = Tabs.Players:AddGroupbox({
	Side = "Right",
	Name = "Self Utilities",
	IconName = "shield",
})

TargetGroup:AddDropdown("TargetPlayer", {
	SpecialType = "Player",
	Text = "Select Target Player",
	ExcludeLocalPlayer = true,
})

TargetGroup:AddButton({
	Text = "Teleport to Player",
	Func = function()
		local target = Options.TargetPlayer.Value
		if target and AdminRemote then AdminRemote:FireServer("TeleportTo", target) end
	end
})

TargetGroup:AddButton({
	Text = "Kill Target Player",
	Func = function()
		local target = Options.TargetPlayer.Value
		if target and AdminRemote then AdminRemote:FireServer("KillPlayer", target) end
	end
})

TargetGroup:AddButton({
	Text = "Kick Target Player",
	Func = function()
		local target = Options.TargetPlayer.Value
		if target and AdminRemote then AdminRemote:FireServer("KickPlayer", target) end
	end
})

SelfGroup:AddSlider("WalkSpeed", {
	Text = "WalkSpeed",
	Default = 16,
	Min = 16,
	Max = 250,
	Rounding = 0,
})
Options.WalkSpeed:OnChanged(function()
	if AdminRemote then AdminRemote:FireServer("SetSpeed", Options.WalkSpeed.Value) end
end)

SelfGroup:AddSlider("JumpPower", {
	Text = "JumpPower",
	Default = 50,
	Min = 50,
	Max = 300,
	Rounding = 0,
})
Options.JumpPower:OnChanged(function()
	if AdminRemote then AdminRemote:FireServer("SetJumpPower", Options.JumpPower.Value) end
end)

SelfGroup:AddToggle("Godmode", {
	Text = "Godmode",
	Default = false,
})
Toggles.Godmode:OnChanged(function()
	if AdminRemote then AdminRemote:FireServer("ToggleGodmode", Toggles.Godmode.Value) end
end)

SelfGroup:AddButton({
	Text = "Instant Heal",
	Func = function()
		if AdminRemote then AdminRemote:FireServer("HealSelf") end
	end
})

SelfGroup:AddDropdown("GiveTool", {
	Values = {"Building Tool", "Grapple Hook", "Medkit", "Speed Coil"},
	Text = "Give Equipment",
})
Options.GiveTool:OnChanged(function()
	if AdminRemote then AdminRemote:FireServer("GiveItem", Options.GiveTool.Value) end
end)

---------------------------------------------------------
-- 4. WORLD & PHYSICS TAB
---------------------------------------------------------
local EnvGroup = Tabs.World:AddGroupbox({
	Side = "Left",
	Name = "Environment Controls",
	IconName = "sun",
})

local PhysicsGroup = Tabs.World:AddGroupbox({
	Side = "Right",
	Name = "Server Physics",
	IconName = "activity",
})

EnvGroup:AddSlider("TimeOfDay", {
	Text = "Time of Day (Hours)",
	Default = 12,
	Min = 0,
	Max = 24,
	Rounding = 1,
})
Options.TimeOfDay:OnChanged(function()
	if AdminRemote then AdminRemote:FireServer("SetTime", Options.TimeOfDay.Value) end
end)

EnvGroup:AddSlider("FogDensity", {
	Text = "Fog Distance",
	Default = 1000,
	Min = 50,
	Max = 5000,
	Rounding = 0,
})
Options.FogDensity:OnChanged(function()
	if AdminRemote then AdminRemote:FireServer("SetFog", Options.FogDensity.Value) end
end)

EnvGroup:AddButton({
	Text = "Clear Player Structures",
	Func = function()
		if AdminRemote then AdminRemote:FireServer("ClearMap") end
	end
})

PhysicsGroup:AddSlider("ServerGravity", {
	Text = "Server Gravity",
	Default = 196,
	Min = 0,
	Max = 500,
	Rounding = 0,
})
Options.ServerGravity:OnChanged(function()
	if AdminRemote then AdminRemote:FireServer("SetGravity", Options.ServerGravity.Value) end
end)

---------------------------------------------------------
-- 5. FUN TAB
---------------------------------------------------------
local ChaosGroup = Tabs.Fun:AddGroupbox({
	Side = "Left",
	Name = "Chaos Tools",
	IconName = "bomb",
})

ChaosGroup:AddButton({
	Text = "Explode Selected Player",
	Func = function()
		local target = Options.TargetPlayer.Value
		if target and AdminRemote then AdminRemote:FireServer("ExplodePlayer", target) end
	end
})

ChaosGroup:AddButton({
	Text = "Nuke Map Center",
	Func = function()
		if AdminRemote then AdminRemote:FireServer("NukeMap") end
	end
})

---------------------------------------------------------
-- 6. UI SETTINGS & MANAGERS
---------------------------------------------------------
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("ObsidianAdminPanel")
SaveManager:SetFolder("ObsidianAdminPanel/configs")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

Library:Notify("Admin Panel loaded successfully!", 5)
