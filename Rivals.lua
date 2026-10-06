if not game:IsLoaded() then game.Loaded:Wait() end

if getgenv and getgenv().OzionHubUnload then
    pcall(getgenv().OzionHubUnload)
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===================================================================
--  Obsidian UI library
-- ===================================================================
local OBSIDIAN_REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local function loadRemote(path)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(OBSIDIAN_REPO .. path))()
    end)
    if not ok then
        warn("[OzionHub] Failed to load " .. path .. ": " .. tostring(result))
        return nil
    end
    return result
end

local Library = loadRemote("Library.lua")
if not Library then
    warn("[OzionHub] Obsidian could not be loaded. Check your connection / executor HttpGet support.")
    return
end
local ThemeManager = loadRemote("addons/ThemeManager.lua")
local Options = Library.Options
local Toggles = Library.Toggles


local isRunning = true
local activeConnections = {}
local cleanUpInstances = {}
local originalNamecall = nil
local originalUtilityRaycast = nil

local function hideFromStack(fn)
    if typeof(fn) == "function" and setstackhidden then
        pcall(setstackhidden, fn, true)
    end
end

local autoReinjectScript = [[
    task.spawn(function()
        repeat task.wait(0.5) until game:IsLoaded()
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        repeat task.wait(0.5) until lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        task.wait(1.5)
        local success, err = pcall(function()
            if loadfile then
                local f = loadfile("ozionhub.luau") or loadfile("OzionHub.luau") or loadfile("rivals.luau") or loadfile("Rivals.luau")
                if f then f() end
            end
        end)
    end)
]]

if queue_on_teleport then
    pcall(function() queue_on_teleport(autoReinjectScript) end)
elseif syn and syn.queue_on_teleport then
    pcall(function() syn.queue_on_teleport(autoReinjectScript) end)
end

LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started or state == Enum.TeleportState.InProgress then
        if queue_on_teleport then
            pcall(function() queue_on_teleport(autoReinjectScript) end)
        elseif syn and syn.queue_on_teleport then
            pcall(function() syn.queue_on_teleport(autoReinjectScript) end)
        end
    end
end)

local Config = {

    Aimbot = false,
    TeamCheck = true,
    AimbotKey = Enum.UserInputType.MouseButton2,
    AimbotKeyMode = "Hold",
    AimbotPart = "Closest",
    AimbotSmoothing = 0.28,
    AimbotFOV = 120,
    AimbotVisibleOnly = true,
    AimbotScopeOnly = false,
    AimbotDisableReloading = true,
    ContinuousTargeting = true,
    InstantCameraLock = false,
    TrackThroughWalls = true,
    CorrectLockedShots = true,

    SilentAim = true,
    SilentKey = Enum.KeyCode.C,
    SilentKeyMode = "Always",
    SilentTargetPart = "Head",
    SilentFOV = 242,
    SilentHitChance = 78,
    SilentHeadChance = 59,
    SilentVisibleOnly = true,
    SilentVulnerableOnly = true,
    SilentIgnoreDeflecting = true,
    SilentIgnoreShielded = true,

    Ragebot = false,
    RagebotAutoShoot = false,
    RagebotTargetStrafe = false,
    TargetStrafeRadius = 14,
    TargetStrafeSpeed = 6,
    Autoplay = false,
    AutoplayDistance = 18,
    RagebotTargetPriority = "Distance",
    RagebotWallbang = true,
    AutoRespawn = false,
    AutoQueue = false,
    QueueMode = "1v1",
    AutoVoteMaps = false,
    MapPriority = "Arena, Onyx, Crossroads",
    AutoBanWeapons = false,
    WeaponBanPriority = "Grenade Launcher, Minigun, RPG",
    SecondBanPriority = "Grenade Launcher, Minigun, RPG",
    AutoLoadout = true,
    LoadoutOnlySelected = false,
    EnabledMaps = "Arena, Crossroads",
    AntiAim = false,
    AntiAimMode = "Jitter",
    AntiAimSpeed = 10,
    HackerDetector = true,
    NotifyHackers = true,
    HackerAutoLoad = true,
    HackerProfile = "rage",
    SpeedThreshold = 180,
    SpeedDuration = 0.75,
    ModDetector = true,
    NotifyMods = true,
    MinGroupRank = 200,
    ModUsernames = "name1, name2",
    ModFriendList = "name1, name2",
    AutoPickup = false,
    PickupRadius = 25,

    ESP_Master = true,
    ESP_EnemyOnly = true,
    ESP_Lobby = true,
    ESP_MaxDistance = 500,
    ESP_Boxes = true,
    ESP_Names = true,
    ESP_Distance = true,
    ESP_HealthBar = true,
    ESP_Weapon = true,
    ESP_Tracers = false,
    ESP_Chams = false,
    ESP_Skeleton = true,
    ESP_HeadDot = true,
    ESP_Tripmines = true,
    ESP_FOV = true,
    TargetVisualizer = true,
    TargetVisualizerHUD = true,
    TargetVisualizerPath = true,
    VisualizerArrowSpacing = 10,
    VisualizerArrowSpeed = 14,

    SpeedHack = false,
    SpeedValue = 49,
    FlyHack = false,
    FlySpeed = 50,
    InfiniteJump = false,
    BunnyHop = false,
    Noclip = false,

    NoRecoil = true,
    NoSpread = true,
    FastReload = false,
    RapidFire = false,
    InstantEquip = false,
    AutomaticGuns = false,
    InfiniteAmmo = false,

    UnlockAllSkins = false,
    SelectedCategory = "Primary",
    SelectedWeapon = "Assault Rifle",
    SelectedWrap = "Liquid Gold",
    SelectedCharm = "Dice",
    SelectedFinisher = "Gingerbreadify",
    RainbowGunSkin = false,
    WeaponChams = false,
    CustomViewModelFOV = false,
    ViewModelFOVValue = 70,
    ViewModelXOffset = 0,
    ViewModelYOffset = 0,
    ViewModelZOffset = 0,
    HideViewModel = false,

    Fullbright = false,
    NoFog = true,
    CustomFOV = false,
    FOVValue = 90,
    BulletTracers = false,
    HitSound = "Skeet",

    ThirdPerson = false,
    ThirdPersonDist = 12,
    Freecam = false,
    FreecamSpeed = 40,

    MenuKey = Enum.KeyCode.RightControl,
    MobileToggle = false
}

local Theme = {
    OuterBorder     = Color3.fromRGB(215, 106, 141),
    BorderPink      = Color3.fromRGB(215, 106, 141),
    BorderPinkDark  = Color3.fromRGB(150, 60, 92),

    WindowBg        = Color3.fromRGB(22, 17, 21),
    WindowBgTop     = Color3.fromRGB(28, 20, 26),
    WindowBgBottom  = Color3.fromRGB(16, 12, 15),
    InnerCanvasBg   = Color3.fromRGB(20, 15, 19),
    HeaderBg        = Color3.fromRGB(24, 18, 23),

    CardBg          = Color3.fromRGB(33, 24, 30),
    CardBgTop       = Color3.fromRGB(44, 32, 41),
    CardBgBottom    = Color3.fromRGB(22, 16, 20),
    BorderDark      = Color3.fromRGB(56, 40, 52),
    BorderCard      = Color3.fromRGB(64, 46, 59),

    AccentPink      = Color3.fromRGB(226, 120, 152),
    AccentPinkLight = Color3.fromRGB(245, 152, 182),
    AccentPinkDark  = Color3.fromRGB(180, 72, 108),
    AccentPinkDim   = Color3.fromRGB(120, 42, 70),

    TextWhite       = Color3.fromRGB(242, 240, 243),
    TextMuted       = Color3.fromRGB(152, 132, 144),
    TextDark        = Color3.fromRGB(105, 88, 100),
    ControlBg       = Color3.fromRGB(15, 11, 14),
    ButtonBg        = Color3.fromRGB(32, 23, 29),
    ButtonHoverBg   = Color3.fromRGB(48, 34, 44),
    ButtonBorder    = Color3.fromRGB(68, 48, 62),
    Red             = Color3.fromRGB(235, 75, 75),
    Yellow          = Color3.fromRGB(245, 195, 65),

    AccentGreen     = Color3.fromRGB(226, 120, 152),
    AccentGreenLight= Color3.fromRGB(245, 152, 182),
    AccentGreenDark = Color3.fromRGB(180, 72, 108),
    AccentGreenDim  = Color3.fromRGB(120, 42, 70)
}

local MainFont = Enum.Font.RobotoMono

-- OzionHub palette for Obsidian (applied before the window is created)
pcall(function()
    Library.Scheme.BackgroundColor = Theme.WindowBg
    Library.Scheme.MainColor = Theme.CardBg
    Library.Scheme.AccentColor = Theme.AccentPink
    Library.Scheme.OutlineColor = Theme.BorderCard
    Library.Scheme.FontColor = Theme.TextWhite
end)

local LOBBY_CENTER = Vector3.new(109, -680, 1184)
local function isInLobby()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return (root.Position - LOBBY_CENTER).Magnitude < 450
end

local function isTeammate(p)
    if not p then return false end
    if p == LocalPlayer then return true end
    if Config.TeamCheck == false then return false end

    local pl = nil
    if typeof(p) == "Instance" then
        if p:IsA("Player") then
            pl = p
        elseif LocalPlayer.Character and (p == LocalPlayer.Character or p:IsDescendantOf(LocalPlayer.Character)) then
            return true
        else
            pl = Players:GetPlayerFromCharacter(p:IsA("Model") and p or p:FindFirstAncestorOfClass("Model"))
        end
    end

    if pl and LocalPlayer.Team and pl.Team and LocalPlayer.Team == pl.Team then
        return true
    end

    if pl then
        local myT = LocalPlayer:GetAttribute("TeamID") or LocalPlayer:GetAttribute("Team")
        local theirT = pl:GetAttribute("TeamID") or pl:GetAttribute("Team")
        if myT ~= nil and theirT ~= nil and myT == theirT then
            return true
        end
    end

    local pChar = pl and pl.Character or (typeof(p) == "Instance" and (p:IsA("Model") and p or p:FindFirstAncestorOfClass("Model")))
    local myChar = LocalPlayer.Character
    if pChar and myChar then
        local myCT = myChar:GetAttribute("TeamID") or myChar:GetAttribute("Team")
        local theirCT = pChar:GetAttribute("TeamID") or pChar:GetAttribute("Team")
        if myCT ~= nil and theirCT ~= nil and myCT == theirCT then
            return true
        end
        if pChar:FindFirstChild("TeammateLabel", true) or pChar:FindFirstChild("AllyLabel", true) then
            return true
        end
    end

    return false
end
hideFromStack(isTeammate)

local function isEnemyPlayer(p)
    if not p or p == LocalPlayer then return false end

    if isInLobby() then
        return Config.ESP_Lobby == true
    end

    if isTeammate(p) then
        return false
    end

    if Config.ESP_EnemyOnly and LocalPlayer.Team and p.Team and LocalPlayer.Team == p.Team then
        return false
    end

    return true
end
hideFromStack(isEnemyPlayer)

local function getGuiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, gui = pcall(function() return CoreGui end)
    if ok and gui then return gui end
    return LocalPlayer:WaitForChild("PlayerGui", 5) or LocalPlayer:FindFirstChild("PlayerGui")
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OzionHubUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 100
screenGui.Parent = getGuiParent()
table.insert(cleanUpInstances, screenGui)

local isUnloading = false
local function UnloadScript()
    if isUnloading then return end
    isUnloading = true
    isRunning = false
    for _, conn in ipairs(activeConnections) do pcall(function() conn:Disconnect() end) end
    table.clear(activeConnections)
    for _, inst in ipairs(cleanUpInstances) do pcall(function() inst:Destroy() end) end
    table.clear(cleanUpInstances)
    if originalUtilityRaycast then
        pcall(function()
            local util = require(ReplicatedStorage.Modules.Utility)
            util.Raycast = originalUtilityRaycast
        end)
    end
    pcall(function() ContextActionService:UnbindAction("OzionHubMenuFreeze") end)
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local pm = ps and ps:FindFirstChild("PlayerModule")
        if pm then
            local controls = require(pm):GetControls()
            if controls then controls:Enable() end
        end
    end)
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.Anchored = false
        end
    end)
    if getgenv then getgenv().OzionHubUnload = nil end
    pcall(function() Library:Unload() end)
end

if getgenv then getgenv().OzionHubUnload = UnloadScript end
pcall(function()
    Library:OnUnload(function() UnloadScript() end)
end)

local originalWeaponStats = {}
local function ApplyWeaponModifications()
    if not isRunning then return end
    pcall(function()
        local rep = game:GetService("ReplicatedStorage")
        local itemModule = rep:FindFirstChild("Modules") and rep.Modules:FindFirstChild("ItemLibrary")
        if not itemModule then return end
        local itemLib = require(itemModule)
        if itemLib and itemLib.Items then
            for name, item in pairs(itemLib.Items) do
                if type(item) == "table" and item.ShootRecoil ~= nil then
                    if not originalWeaponStats[name] then
                        originalWeaponStats[name] = {
                            ShootRecoil = item.ShootRecoil,
                            ShootSpread = item.ShootSpread,
                            AimSpreadMultiplier = item.AimSpreadMultiplier,
                            ShootSpreadPerVelocityUnit = item.ShootSpreadPerVelocityUnit,
                            ShootSpreadPerVelocityLimit = item.ShootSpreadPerVelocityLimit,
                            EquipCooldown = item.EquipCooldown,
                            ReloadLength = item.ReloadLength,
                            EmptyReloadLength = item.EmptyReloadLength,
                            ReloadActionTimestamp = item.ReloadActionTimestamp,
                            EmptyReloadActionTimestamp = item.EmptyReloadActionTimestamp,
                            ShootCooldown = item.ShootCooldown,
                            MaxAmmo = item.MaxAmmo,
                            MaxAmmoReserve = item.MaxAmmoReserve
                        }
                    end

                    local orig = originalWeaponStats[name]
                    item.ShootRecoil = Config.NoRecoil and 0 or orig.ShootRecoil
                    item.ShootSpread = Config.NoSpread and 0 or orig.ShootSpread
                    item.AimSpreadMultiplier = Config.NoSpread and 0 or orig.AimSpreadMultiplier
                    item.ShootSpreadPerVelocityUnit = Config.NoSpread and 0 or orig.ShootSpreadPerVelocityUnit
                    item.ShootSpreadPerVelocityLimit = Config.NoSpread and 0 or orig.ShootSpreadPerVelocityLimit
                    item.EquipCooldown = Config.InstantEquip and 0.01 or orig.EquipCooldown
                    item.ReloadLength = Config.FastReload and 0.05 or orig.ReloadLength
                    item.EmptyReloadLength = Config.FastReload and 0.05 or orig.EmptyReloadLength
                    item.ReloadActionTimestamp = Config.FastReload and 0.01 or orig.ReloadActionTimestamp
                    item.EmptyReloadActionTimestamp = Config.FastReload and 0.01 or orig.EmptyReloadActionTimestamp
                    item.ShootCooldown = Config.RapidFire and (orig.ShootCooldown * 0.4) or orig.ShootCooldown
                    if orig.MaxAmmo then
                        item.MaxAmmo = Config.InfiniteAmmo and 9999 or orig.MaxAmmo
                    end
                    if orig.MaxAmmoReserve then
                        item.MaxAmmoReserve = Config.InfiniteAmmo and 9999 or orig.MaxAmmoReserve
                    end
                end
            end
        end
    end)
end

-- What the account REALLY owns (taken the first time "unlock all" runs).
-- Equip requests for anything else are handled locally and never sent to the server.
local realOwnedCosmetics = nil
local cosmeticDebugLog = false

-- Updates the local player data the same way the server would after a successful equip,
-- so the game's own UI sees the item as equipped.
local function SetLocalEquippedCosmetic(weaponName, slot, cosmeticName)
    local changed = false
    pcall(function()
        local pdCtrl = require(LocalPlayer.PlayerScripts.Controllers.PlayerDataController)
        local weapInv = pdCtrl and pdCtrl.CurrentData and pdCtrl.CurrentData.Data and pdCtrl.CurrentData.Data.WeaponInventory
        if typeof(weapInv) ~= "table" then return end
        local isClear = (cosmeticName == nil or cosmeticName == "None" or cosmeticName == "Default")
        for _, weapon in pairs(weapInv) do
            if typeof(weapon) == "table" and weapon.Name == weaponName then
                if isClear then
                    weapon[slot] = nil
                elseif slot == "Wrap" then
                    local old = weapon.Wrap
                    weapon.Wrap = { Name = cosmeticName, Inverted = (typeof(old) == "table" and old.Inverted) or false }
                else
                    local sample = nil
                    for _, other in pairs(weapInv) do
                        if typeof(other) == "table" and other[slot] ~= nil then
                            sample = other[slot]
                            break
                        end
                    end
                    if type(sample) == "string" then
                        weapon[slot] = cosmeticName
                    else
                        weapon[slot] = { Name = cosmeticName }
                    end
                end
                changed = true
            end
        end
    end)
    return changed
end

local function UnlockAllCosmeticsClientSide()
    pcall(function()
        local rep = game:GetService("ReplicatedStorage")
        local pdCtrl = require(LocalPlayer.PlayerScripts.Controllers.PlayerDataController)
        local cosmeticLib = require(rep.Modules.CosmeticLibrary)
        local itemLib = require(rep.Modules.ItemLibrary)

        if pdCtrl and pdCtrl.CurrentData and pdCtrl.CurrentData.Data then
            local cosmInv = pdCtrl.CurrentData.Data.CosmeticInventory or {}
            local rawWeapInv = pdCtrl.CurrentData.Data.WeaponInventory or {}

            if not realOwnedCosmetics then
                realOwnedCosmetics = {}
                for name, _ in pairs(cosmInv) do
                    realOwnedCosmetics[name] = true
                end
            end

            if cosmeticLib and cosmeticLib.Cosmetics then
                for name, _ in pairs(cosmeticLib.Cosmetics) do
                    cosmInv[name] = true
                end
            end

            local weapInv = {}
            local existing = {}
            if typeof(rawWeapInv) == "table" then
                for _, item in pairs(rawWeapInv) do
                    if typeof(item) == "table" and item.Name then
                        table.insert(weapInv, item)
                        existing[item.Name] = true
                    end
                end
            end

            if itemLib and itemLib.Items then
                for name, _ in pairs(itemLib.Items) do
                    if not existing[name] then
                        table.insert(weapInv, {
                            Name = name,
                            Level = 100,
                            Prestige = 5,
                            XP = 99999,
                            IsFavorited = false
                        })
                        existing[name] = true
                    end
                end
            end

            pdCtrl.CurrentData.Data.CosmeticInventory = cosmInv
            pdCtrl.CurrentData.Data.WeaponInventory = weapInv
        end
    end)
end

-- Local-only equip: unlocks (once) and writes the item into your local data.
-- Nothing is sent to the server.
local function EquipCosmeticLocal(weaponName, slot, cosmeticName)
    if not realOwnedCosmetics then
        UnlockAllCosmeticsClientSide()
    end
    return SetLocalEquippedCosmetic(weaponName, slot, cosmeticName)
end

-- A BindableEvent lives only on this client, so it's the local equivalent of the remote:
--   OzionHubEquip:Fire("Weapon Name", "Skin" | "Wrap" | "Charm" | "Finisher", "Item Name")
local equipLocalEvent = Instance.new("BindableEvent")
equipLocalEvent.Name = "OzionHubEquip"
equipLocalEvent.Parent = screenGui
table.insert(cleanUpInstances, equipLocalEvent)
table.insert(activeConnections, equipLocalEvent.Event:Connect(function(weaponName, slot, cosmeticName)
    EquipCosmeticLocal(weaponName, slot, cosmeticName)
end))
if getgenv then getgenv().OzionHubEquipLocal = EquipCosmeticLocal end

local function ApplySelectedCosmeticsClientSide(weaponName, wrapName, charmName, finisherName)
    pcall(function()
        local rep = game:GetService("ReplicatedStorage")
        local pdCtrl = require(LocalPlayer.PlayerScripts.Controllers.PlayerDataController)
        if pdCtrl and pdCtrl.CurrentData and pdCtrl.CurrentData.Data then
            local weapInv = pdCtrl.CurrentData.Data.WeaponInventory
            if typeof(weapInv) == "table" then
                for _, weapon in ipairs(weapInv) do
                    if typeof(weapon) == "table" and (weapon.Name == weaponName or weaponName == "All") then
                        if wrapName and wrapName ~= "Default" and wrapName ~= "None" then
                            weapon.Wrap = { Name = wrapName, Inverted = false }
                        elseif wrapName == "Default" or wrapName == "None" then
                            weapon.Wrap = nil
                        end

                        if charmName and charmName ~= "None" then
                            weapon.Charm = { Name = charmName }
                        elseif charmName == "None" then
                            weapon.Charm = nil
                        end

                        if finisherName and finisherName ~= "None" then
                            weapon.Finisher = { Name = finisherName }
                        elseif finisherName == "None" then
                            weapon.Finisher = nil
                        end
                    end
                end
            end
        end

        local rem = rep:FindFirstChild("Remotes")
        local dataRem = rem and rem:FindFirstChild("Data")
        local equipCosm = dataRem and dataRem:FindFirstChild("EquipCosmetic")
        if equipCosm and weaponName ~= "All" then
            if wrapName and wrapName ~= "Default" and wrapName ~= "None" then
                equipCosm:FireServer(weaponName, "Wrap", wrapName)
            end
            if charmName and charmName ~= "None" then
                equipCosm:FireServer(weaponName, "Charm", charmName)
            end
            if finisherName and finisherName ~= "None" then
                equipCosm:FireServer(weaponName, "Finisher", finisherName)
            end
        end
    end)
end

local watermarkFrame = Instance.new("Frame")
watermarkFrame.Name = "OzionHubWatermark"
watermarkFrame.Size = UDim2.new(0, 275, 0, 22)
watermarkFrame.Position = UDim2.new(1, -285, 0, 8)
watermarkFrame.BackgroundColor3 = Theme.CardBg
watermarkFrame.BorderSizePixel = 0
watermarkFrame.ZIndex = 90
watermarkFrame.Parent = screenGui
table.insert(cleanUpInstances, watermarkFrame)

local wmGrad = Instance.new("UIGradient")
wmGrad.Rotation = 90
wmGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.CardBgTop),
    ColorSequenceKeypoint.new(1, Theme.CardBgBottom)
})
wmGrad.Parent = watermarkFrame

local wmStroke = Instance.new("UIStroke")
wmStroke.Color = Theme.BorderCard
wmStroke.Thickness = 1
wmStroke.Parent = watermarkFrame

local wmTopLine = Instance.new("Frame")
wmTopLine.Size = UDim2.new(1, 0, 0, 1.5)
wmTopLine.BackgroundColor3 = Theme.AccentPink
wmTopLine.BorderSizePixel = 0
wmTopLine.ZIndex = 91
wmTopLine.Parent = watermarkFrame

local wmLineGrad = Instance.new("UIGradient")
wmLineGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.AccentPinkLight),
    ColorSequenceKeypoint.new(1, Theme.AccentPinkDark)
})
wmLineGrad.Parent = wmTopLine

local wmLbl = Instance.new("TextLabel")
wmLbl.Size = UDim2.new(1, -12, 1, -2)
wmLbl.Position = UDim2.new(0, 8, 0, 2)
wmLbl.BackgroundTransparency = 1
wmLbl.Font = MainFont
wmLbl.RichText = true
wmLbl.Text = '<b>O</b>  |  <font color="#e27898">ozionhub</font>  |  60 fps  |  0 ms'
wmLbl.TextColor3 = Theme.TextWhite
wmLbl.TextSize = 10.5
wmLbl.TextXAlignment = Enum.TextXAlignment.Left
wmLbl.ZIndex = 92
wmLbl.Parent = watermarkFrame

-- Notifications now go through Obsidian (same signature as before)
local function ShowNotification(title, message, notifType, duration)
    if not isRunning then return end
    pcall(function()
        duration = duration or 3.5
        notifType = notifType or "INFO"
        local description = tostring(message)
        if notifType == "WARN" then
            description = "[!] " .. description
        elseif notifType == "ERROR" then
            description = "[x] " .. description
        end
        Library:Notify({
            Title = tostring(title),
            Description = description,
            Time = duration,
        })
    end)
end

local TargetVis = {
    hudFrame = nil,
    hudTitle = nil,
    hudAvatar = nil,
    hudName = nil,
    hudHpFill = nil,
    visualizerFolder = nil,
    poolLines = {},
    poolChevrons = {},
    cachedWaypoints = {},
    autoplayWpIndex = 1,
    lastAutoplayStuckTime = 0,
    lastAutoplayPos = nil,
    lastTargetUserId = nil,
    activeRoot = nil,
    activeChar = nil,
    activeHum = nil,
    activePlayer = nil,
    cachedEnemies = {},
    lastEnemyUpdateTime = 0,
    targetCache = {},
    staticRayParams = nil,
    lastFullbrightCheck = 0,
    lastNoFogCheck = 0,
    lastPathMyPos = nil,
    lastPathActPos = nil,
}

local function initTargetVisualizer()
    local hud = Instance.new("Frame")
    hud.Name = "TargetHUD"
    hud.Size = UDim2.new(0, 310, 0, 72)
    hud.Position = UDim2.new(0.5, -155, 1, -125)
    hud.BackgroundColor3 = Color3.fromRGB(15, 18, 15)
    hud.BorderSizePixel = 0
    hud.Visible = false
    hud.ZIndex = 80
    hud.Parent = screenGui
    table.insert(cleanUpInstances, hud)
    TargetVis.hudFrame = hud

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(45, 55, 45)
    stroke.Thickness = 1.2
    stroke.Parent = hud

    local topLine = Instance.new("Frame")
    topLine.Size = UDim2.new(1, 0, 0, 2.5)
    topLine.BackgroundColor3 = Color3.fromRGB(195, 255, 30)
    topLine.BorderSizePixel = 0
    topLine.ZIndex = 81
    topLine.Parent = hud

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 18)
    title.Position = UDim2.new(0, 10, 0, 4)
    title.BackgroundTransparency = 1
    title.Font = MainFont
    title.Text = "Target  -  150/150"
    title.TextColor3 = Theme.TextWhite
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 82
    title.Parent = hud
    TargetVis.hudTitle = title

    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.new(0, 42, 0, 42)
    avatar.Position = UDim2.new(0, 10, 0, 24)
    avatar.BackgroundColor3 = Color3.fromRGB(20, 24, 20)
    avatar.BorderSizePixel = 0
    avatar.ZIndex = 82
    avatar.Parent = hud
    TargetVis.hudAvatar = avatar

    local avStroke = Instance.new("UIStroke")
    avStroke.Color = Color3.fromRGB(195, 255, 30)
    avStroke.Thickness = 1.2
    avStroke.Parent = avatar

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -68, 0, 18)
    nameLbl.Position = UDim2.new(0, 60, 0, 24)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = MainFont
    nameLbl.Text = "Player (@username)"
    nameLbl.TextColor3 = Theme.TextWhite
    nameLbl.TextSize = 13
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.ZIndex = 82
    nameLbl.Parent = hud
    TargetVis.hudName = nameLbl

    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(1, -68, 0, 8)
    hpBg.Position = UDim2.new(0, 60, 0, 48)
    hpBg.BackgroundColor3 = Color3.fromRGB(28, 34, 28)
    hpBg.BorderSizePixel = 0
    hpBg.ZIndex = 82
    hpBg.Parent = hud

    local hpCorner = Instance.new("UICorner")
    hpCorner.CornerRadius = UDim.new(0, 2)
    hpCorner.Parent = hpBg

    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(195, 255, 30)
    hpFill.BorderSizePixel = 0
    hpFill.ZIndex = 83
    hpFill.Parent = hpBg
    TargetVis.hudHpFill = hpFill

    local hpFillCorner = Instance.new("UICorner")
    hpFillCorner.CornerRadius = UDim.new(0, 2)
    hpFillCorner.Parent = hpFill

    local vFolder = Instance.new("Folder")
    vFolder.Name = "OzionHubTargetVisualizer"
    vFolder.Parent = Workspace
    table.insert(cleanUpInstances, vFolder)
    TargetVis.visualizerFolder = vFolder

    for i = 1, 40 do
        local p = Instance.new("Part")
        p.Name = "VisLine_" .. i
        p.Anchored = true
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.CastShadow = false
        p.Material = Enum.Material.Neon
        p.Color = Color3.fromRGB(195, 255, 30)
        p.Transparency = 1
        p.Size = Vector3.new(0.18, 0.06, 1)
        p.Parent = vFolder
        table.insert(TargetVis.poolLines, p)
    end

    for i = 1, 30 do
        local wingL = Instance.new("Part")
        wingL.Name = "ChevL_" .. i
        wingL.Anchored = true
        wingL.CanCollide = false
        wingL.CanTouch = false
        wingL.CanQuery = false
        wingL.CastShadow = false
        wingL.Material = Enum.Material.Neon
        wingL.Color = Color3.fromRGB(195, 255, 30)
        wingL.Transparency = 1
        wingL.Size = Vector3.new(0.22, 0.08, 1.2)
        wingL.Parent = vFolder

        local wingR = Instance.new("Part")
        wingR.Name = "ChevR_" .. i
        wingR.Anchored = true
        wingR.CanCollide = false
        wingR.CanTouch = false
        wingR.CanQuery = false
        wingR.CastShadow = false
        wingR.Material = Enum.Material.Neon
        wingR.Color = Color3.fromRGB(195, 255, 30)
        wingR.Transparency = 1
        wingR.Size = Vector3.new(0.22, 0.08, 1.2)
        wingR.Parent = vFolder

        table.insert(TargetVis.poolChevrons, { Left = wingL, Right = wingR })
    end
end
initTargetVisualizer()

-- `mainWindow.Visible` is used all over the game logic, so keep that name alive
-- and point it at Obsidian's open/closed state.
local mainWindow = setmetatable({}, {
    __index = function(_, key)
        if key == "Visible" then
            return Library.Toggled == true
        end
        return nil
    end,
})


local frozenCameraCFrame = nil
local frozenCameraFOV = nil
local FreecamState = { enabled = false, rotX = 0, rotY = 0, pos = Vector3.zero }
local sPing = nil
local lastBhopJumpTime = 0
local lastRageAutoShootTime = 0
local lastAutoShootTime = 0
local isTargetStrafing = false

local function hasWeaponEquipped()
    local char = LocalPlayer.Character
    if not char then return false end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") then return true end
    end
    local vm = Workspace:FindFirstChild("ViewModels")
    local fp = vm and vm:FindFirstChild("FirstPerson")
    if fp and #fp:GetChildren() > 0 then
        for _, c in ipairs(fp:GetChildren()) do
            if c:IsA("Model") or c:IsA("BasePart") then
                return true
            end
        end
    end
    return false
end

local function setPlayerControlsEnabled(enabled)
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local pm = ps and ps:FindFirstChild("PlayerModule")
        if pm then
            local controls = require(pm):GetControls()
            if controls then
                if enabled then
                    controls:Enable()
                else
                    controls:Disable()
                end
            end
        end
    end)
end

local function applyMenuState(visible)
    if visible then
        frozenCameraCFrame = Camera.CFrame
        frozenCameraFOV = Camera.FieldOfView
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true

        setPlayerControlsEnabled(false)

        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
        end

        pcall(function()
            ContextActionService:BindActionAtPriority(
                "OzionHubMenuFreeze",
                function() return Enum.ContextActionResult.Sink end,
                false,
                Enum.ContextActionPriority.High.Value + 5000,
                Enum.UserInputType.MouseMovement,
                Enum.UserInputType.Touch,
                Enum.KeyCode.W,
                Enum.KeyCode.A,
                Enum.KeyCode.S,
                Enum.KeyCode.D,
                Enum.KeyCode.Space,
                Enum.KeyCode.LeftShift,
                Enum.KeyCode.LeftControl,
                Enum.KeyCode.Up,
                Enum.KeyCode.Down,
                Enum.KeyCode.Left,
                Enum.KeyCode.Right
            )
        end)
    else
        frozenCameraCFrame = nil
        frozenCameraFOV = nil

        setPlayerControlsEnabled(true)

        pcall(function()
            ContextActionService:UnbindAction("OzionHubMenuFreeze")
        end)
    end
end

-- Opens/closes the Obsidian window (same name and meaning as the old function)
local function setMenuVisible(visible)
    if type(Library.Toggled) ~= "boolean" then return end
    if Library.Toggled ~= (visible == true) then
        task.spawn(Library.Toggle)
    end
end

-- Whenever the window opens/closes (keybind, mobile button, close button...)
-- run the camera/controls freeze logic that used to live in setMenuVisible.
local lastAppliedMenuState = nil
table.insert(activeConnections, RunService.RenderStepped:Connect(function()
    if not isRunning then return end
    local open = (Library.Toggled == true)
    if open ~= lastAppliedMenuState then
        lastAppliedMenuState = open
        applyMenuState(open)
    end
end))

-- ===================================================================
--  Obsidian window + tabs
-- ===================================================================
local uiBuilding = true

local windowSize = UDim2.fromOffset(720, 520)
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
    local vp = Camera.ViewportSize
    windowSize = UDim2.fromOffset(
        math.clamp(vp.X - 80, 360, 640),
        math.clamp(vp.Y - 60, 260, 420)
    )
end

local Window = Library:CreateWindow({
    Title = "OzionHub",
    Footer = "OzionHub  |  rivals",
    Center = true,
    AutoShow = true,
    Size = windowSize,
    ShowCustomCursor = false,
})

local tabDefs = {
    { name = "home",  title = "Home",   icon = "house" },
    { name = "aim",   title = "Aim",    icon = "crosshair" },
    { name = "auto",  title = "Auto",   icon = "bot" },
    { name = "esp",   title = "ESP",    icon = "eye" },
    { name = "move",  title = "Move",   icon = "move" },
    { name = "guns",  title = "Guns",   icon = "sword" },
    { name = "skins", title = "Skins",  icon = "palette" },
    { name = "world", title = "World",  icon = "sun" },
    { name = "view",  title = "View",   icon = "camera" },
    { name = "config", title = "Config", icon = "settings" },
}

-- tabPages[name]:FindFirstChild("LeftCol"/"RightCol") keeps working like before,
-- it just hands back an Obsidian column instead of a ScrollingFrame.
local tabPages = {}
for _, def in ipairs(tabDefs) do
    local obsidianTab = Window:AddTab(def.title, def.icon)
    tabPages[def.name] = {
        Tab = obsidianTab,
        FindFirstChild = function(self, columnName)
            return {
                Tab = self.Tab,
                Side = (columnName == "RightCol") and "Right" or "Left",
            }
        end,
    }
end

-- ===================================================================
--  Widget helpers (same names / signatures as the old custom UI, now Obsidian)
-- ===================================================================
local elementCounter = 0
local function nextId(kind)
    elementCounter = elementCounter + 1
    return "Ozion" .. kind .. tostring(elementCounter)
end

local function createGroupbox(parent, title, desc, bottomNote)
    local groupbox
    if parent.Side == "Right" then
        groupbox = parent.Tab:AddRightGroupbox(title)
    else
        groupbox = parent.Tab:AddLeftGroupbox(title)
    end
    if desc then
        groupbox:AddLabel(desc, true)
    end
    if bottomNote then
        groupbox:AddLabel(bottomNote, true)
    end
    return groupbox
end

local function addCheckbox(parent, labelText, defaultVal, callback)
    local toggle = parent:AddToggle(nextId("Toggle"), {
        Text = labelText,
        Default = defaultVal and true or false,
        Callback = function(value)
            if uiBuilding then return end
            if type(callback) == "function" then callback(value) end
        end,
    })

    return {
        Set = function(newVal) toggle:SetValue(not not newVal) end,
        Get = function() return toggle.Value end,
    }
end

local function parseSliderTemplate(template)
    template = template or "%d"
    local rounding = 0
    local decimals = template:match("%%%.(%d)f")
    if decimals then rounding = tonumber(decimals) or 0 end
    local _, specEnd = template:find("%%[%.%d]*[dfi]")
    local rest = specEnd and template:sub(specEnd + 1) or ""
    local suffix = rest:match("^([^/]*)") or ""
    suffix = (suffix:gsub("%%%%", "%%"))
    return rounding, suffix
end

local function addSlider(parent, labelText, minVal, maxVal, defaultVal, displayTemplate, callback)
    local rounding, suffix = parseSliderTemplate(displayTemplate)
    local startVal = math.clamp(tonumber(defaultVal) or minVal, minVal, maxVal)

    local slider = parent:AddSlider(nextId("Slider"), {
        Text = labelText,
        Default = startVal,
        Min = minVal,
        Max = maxVal,
        Rounding = rounding,
        Suffix = suffix,
        HideMax = true,
        Callback = function(value)
            if uiBuilding then return end
            if type(callback) == "function" then callback(value) end
        end,
    })

    return {
        Set = function(v)
            local num = tonumber(v)
            if num then
                slider:SetValue(math.clamp(num, minVal, maxVal))
            end
        end,
        Get = function() return slider.Value end,
    }
end

local function addDropdown(parent, labelText, options, defaultIdx, callback)
    local values = table.clone(options)
    local suppress = false

    local function resolve(valOrIdx)
        local targetIdx = 1
        if type(valOrIdx) == "number" then
            targetIdx = math.clamp(valOrIdx, 1, math.max(#values, 1))
        elseif type(valOrIdx) == "string" then
            for i, name in ipairs(values) do
                if name == valOrIdx then
                    targetIdx = i
                    break
                end
            end
        end
        return values[targetIdx]
    end

    local dropdown = parent:AddDropdown(nextId("Dropdown"), {
        Text = labelText,
        Values = values,
        Default = math.clamp(defaultIdx or 1, 1, math.max(#values, 1)),
        Multi = false,
        Searchable = #values > 8,
        Callback = function(value)
            if uiBuilding or suppress or value == nil then return end
            if type(callback) == "function" then
                callback(value, table.find(values, value) or 1)
            end
        end,
    })

    return {
        Set = function(valOrIdx)
            local name = resolve(valOrIdx)
            if name ~= nil then dropdown:SetValue(name) end
        end,
        SetOptions = function(newOptions, newSelected)
            values = table.clone(newOptions)
            suppress = true
            pcall(function()
                dropdown:SetValues(values)
                local name = resolve(newSelected)
                if name ~= nil then dropdown:SetValue(name) end
            end)
            suppress = false
        end,
        Get = function() return dropdown.Value end,
    }
end

local function addTextbox(parent, labelText, defaultVal, placeholder, callback)
    local input = parent:AddInput(nextId("Input"), {
        Text = labelText,
        Default = defaultVal or "",
        Placeholder = placeholder or "",
        Finished = true,
        ClearTextOnFocus = false,
        Callback = function(value)
            if uiBuilding then return end
            if type(callback) == "function" then callback(value) end
        end,
    })

    return {
        Set = function(txt) input:SetValue(tostring(txt)) end,
        Get = function() return input.Value end,
    }
end

local function addButton(parent, btnText, callback)
    return parent:AddButton({
        Text = btnText,
        Func = function()
            if type(callback) == "function" then callback() end
        end,
    })
end


local function clickWeapon()
    if mouse1click then
        pcall(mouse1click)
        return
    end
    if mouse1press and mouse1release then
        pcall(function()
            mouse1press()
            task.wait(0.01)
            mouse1release()
        end)
        return
    end
    local vim = game:GetService("VirtualInputManager")
    if vim then
        local vp = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
        local cx = math.floor(vp.X * 0.5)
        local cy = math.floor(vp.Y * 0.5)
        if UserInputService.TouchEnabled and not UserInputService.MouseEnabled and vim.SendTouchEvent then
            pcall(function()
                vim:SendTouchEvent(0, 0, cx, cy)
                task.wait(0.01)
                vim:SendTouchEvent(0, 2, cx, cy)
            end)
            return
        end
        if vim.SendMouseButtonEvent then
            pcall(function()
                vim:SendMouseButtonEvent(cx, cy, 0, true, Workspace, 0)
                task.wait(0.01)
                vim:SendMouseButtonEvent(cx, cy, 0, false, Workspace, 0)
            end)
            return
        end
    end
end
hideFromStack(clickWeapon)

local uiRegistry = {}
local isSyncingTeamCheck = false
local function updateTeamCheck(v)
    if isSyncingTeamCheck then return end
    isSyncingTeamCheck = true
    Config.TeamCheck = v
    for _, name in ipairs({"AimbotTeamCheck", "SilentTeamCheck", "RagebotTeamCheck"}) do
        if uiRegistry[name] and uiRegistry[name].Set and uiRegistry[name].Get() ~= v then
            pcall(function() uiRegistry[name].Set(v) end)
        end
    end
    isSyncingTeamCheck = false
end
hideFromStack(updateTeamCheck)

local isSyncingFOV = false
local function updateSilentFOV(v)
    if isSyncingFOV then return end
    isSyncingFOV = true
    Config.SilentFOV = v
    for _, name in ipairs({ "SilentFOV", "SilentFOVCircle" }) do
        local entry = uiRegistry[name]
        if entry and entry.Get() ~= v then
            pcall(function() entry.Set(v) end)
        end
    end
    isSyncingFOV = false
end
hideFromStack(updateSilentFOV)

local function getEnemyPlayers()
    local now = tick()
    if (now - TargetVis.lastEnemyUpdateTime < 0.15) and (#TargetVis.cachedEnemies > 0) then
        return TargetVis.cachedEnemies
    end
    table.clear(TargetVis.cachedEnemies)

    local inLobby = isInLobby()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            if inLobby then
                if Config.ESP_Lobby or Config.TargetVisualizer then
                    table.insert(TargetVis.cachedEnemies, p)
                end
            else
                if isEnemyPlayer(p) then
                    table.insert(TargetVis.cachedEnemies, p)
                end
            end
        end
    end
    TargetVis.lastEnemyUpdateTime = now
    return TargetVis.cachedEnemies
end

local function getClosestTarget(maxFOV, checkVisible, partMode, targetPriority)
    local now = tick()
    local cacheKey = tostring(maxFOV) .. "_" .. tostring(checkVisible) .. "_" .. tostring(partMode) .. "_" .. tostring(targetPriority)
    local cached = TargetVis.targetCache[cacheKey]
    if cached and (now - cached.time < 0.06) and cached.target and cached.target.Parent then
        return cached.target
    end

    if not TargetVis.staticRayParams then
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Exclude
        p.IgnoreWater = true
        TargetVis.staticRayParams = p
    end

    local closest, closestScore = nil, math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local camPos = Camera.CFrame.Position
    local camLook = Camera.CFrame.LookVector
    local is360 = (maxFOV == nil) or (maxFOV >= 999)

    TargetVis.staticRayParams.FilterDescendantsInstances = {myChar, Camera}

    for _, p in ipairs(getEnemyPlayers()) do
        local char = p.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")

        if char and hum and hum.Health > 0 and rootPart then

            local toRoot = rootPart.Position - camPos
            if is360 or toRoot:Dot(camLook) > -5 then

                local isDeflecting = char:GetAttribute("Deflecting") or char:FindFirstChild("Deflect") or char:FindFirstChild("KatanaDeflect")
                local isShielded = char:GetAttribute("Shielded") or char:FindFirstChild("Shield") or char:FindFirstChild("EnergyShield")
                local isProtected = char:GetAttribute("SpawnImmunity") or char:FindFirstChildOfClass("ForceField")

                local skip = false
                if isTeammate(p) or isTeammate(char) then skip = true end
                if Config.SilentIgnoreDeflecting and isDeflecting then skip = true end
                if Config.SilentIgnoreShielded and isShielded then skip = true end
                if Config.SilentVulnerableOnly and isProtected then skip = true end

                if not skip then
                    local headCandidate = char:FindFirstChild("Head") or char:FindFirstChild("HitboxHead")
                    local bodyCandidate = char:FindFirstChild("UpperTorso") or rootPart
                    local hitPart = nil

                    if partMode == "Head" then
                        hitPart = headCandidate or bodyCandidate
                    elseif partMode == "Body" then
                        hitPart = bodyCandidate or headCandidate
                    elseif partMode == "Closest" then
                        if headCandidate and bodyCandidate then
                            local hScr, hOn = Camera:WorldToViewportPoint(headCandidate.Position)
                            local bScr, bOn = Camera:WorldToViewportPoint(bodyCandidate.Position)
                            if hOn and bOn then
                                local hDist = (Vector2.new(hScr.X, hScr.Y) - mousePos).Magnitude
                                local bDist = (Vector2.new(bScr.X, bScr.Y) - mousePos).Magnitude
                                hitPart = (hDist <= bDist) and headCandidate or bodyCandidate
                            elseif hOn then
                                hitPart = headCandidate
                            elseif bOn then
                                hitPart = bodyCandidate
                            else
                                hitPart = headCandidate
                            end
                        else
                            hitPart = headCandidate or bodyCandidate
                        end
                    else
                        hitPart = headCandidate or bodyCandidate
                    end

                    if hitPart then
                        local inRange = false
                        local score = math.huge
                        if is360 then
                            local worldDist = myRoot and (hitPart.Position - myRoot.Position).Magnitude or (hitPart.Position - camPos).Magnitude
                            if worldDist <= (maxFOV or math.huge) then
                                inRange = true
                                if targetPriority == "Health" then
                                    score = hum.Health
                                else
                                    score = worldDist
                                end
                            end
                        else
                            local scrPos, onScreen = Camera:WorldToViewportPoint(hitPart.Position)
                            if onScreen and scrPos.Z > 0 then
                                local fovDist = (Vector2.new(scrPos.X, scrPos.Y) - mousePos).Magnitude
                                if fovDist <= (maxFOV or math.huge) then
                                    inRange = true
                                    if targetPriority == "Health" then
                                        score = hum.Health
                                    elseif targetPriority == "Distance" and myRoot then
                                        score = (hitPart.Position - myRoot.Position).Magnitude
                                    else
                                        score = fovDist
                                    end
                                end
                            end
                        end

                        if inRange and score < closestScore then
                            if checkVisible then
                                local dir = hitPart.Position - camPos
                                local res = Workspace:Raycast(camPos, dir, TargetVis.staticRayParams)
                                if not res or res.Instance:IsDescendantOf(char) then
                                    closest = hitPart
                                    closestScore = score
                                end
                            else
                                closest = hitPart
                                closestScore = score
                            end
                        end
                    end
                end
            end
        end
    end

    TargetVis.targetCache[cacheKey] = { target = closest, time = now }
    return closest
end

local pageHome = tabPages["home"]
local homeLeft = pageHome:FindFirstChild("LeftCol")
local homeRight = pageHome:FindFirstChild("RightCol")

local gbAccount = createGroupbox(homeLeft, "Account")
gbAccount:AddLabel(LocalPlayer.Name)
gbAccount:AddLabel("(@" .. LocalPlayer.DisplayName .. ")")

local gbBuild = createGroupbox(homeLeft, "Build")
gbBuild:AddLabel("OzionHub P1003 build")

local gbSessionInfo = createGroupbox(homeRight, "Current Session")
gbSessionInfo:AddLabel("Player: " .. LocalPlayer.Name)
local sPingLabel = gbSessionInfo:AddLabel("0 ms - " .. #Players:GetPlayers() .. " players")

-- The render loop does `sPing.Text = ...`, so give it something that accepts .Text
sPing = setmetatable({ Parent = true }, {
    __newindex = function(t, key, value)
        if key == "Text" then
            pcall(function() sPingLabel:SetText(tostring(value)) end)
        else
            rawset(t, key, value)
        end
    end,
})


local gbSessionActions = createGroupbox(homeRight, "Session")
addButton(gbSessionActions, "Rejoin server", function()
    ShowNotification("OzionHub", "Reconnecting to experience...", "INFO", 3)
    task.spawn(function()
        task.wait(0.5)
        pcall(function()
            TeleportService:Teleport(17625359962, LocalPlayer)
        end)
    end)
end)

addButton(gbSessionActions, "Join lowest-ping server", function()
    ShowNotification("OzionHub", "Searching for lowest-ping public server...", "INFO", 3)
    task.spawn(function()
        local placeId = 17625359962
        local HttpService = game:GetService("HttpService")
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/0?sortOrder=2&excludeFullGames=true&limit=25", placeId)
        local success, res = pcall(function() return game:HttpGet(url) end)
        local targetServer = nil
        if success and res then
            local sDec, data = pcall(function() return HttpService:JSONDecode(res) end)
            if sDec and data and data.data then
                for _, s in ipairs(data.data) do
                    if s.id ~= game.JobId and s.playing and s.maxPlayers and (s.playing < s.maxPlayers) then
                        if not targetServer or (s.ping and targetServer.ping and s.ping < targetServer.ping) or (s.ping and not targetServer.ping) then
                            targetServer = s
                        end
                    end
                end
            end
        end

        if targetServer then
            ShowNotification("OzionHub", string.format("Joining server (%d ms ping)...", targetServer.ping or 0), "SUCCESS", 3)
            task.wait(0.5)
            pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
            end)
        else
            ShowNotification("OzionHub", "Connecting to optimal regional server...", "INFO", 3)
            task.wait(0.5)
            pcall(function()
                TeleportService:Teleport(placeId, LocalPlayer)
            end)
        end
    end)
end)

local pageAuto = tabPages["auto"]
local autoLeft = pageAuto:FindFirstChild("LeftCol")
local autoRight = pageAuto:FindFirstChild("RightCol")

local gbRagebot = createGroupbox(autoLeft, "Ragebot", "Automatically targets and shoots\nenemies.")
uiRegistry["Ragebot"] = addCheckbox(gbRagebot, "Enable ragebot", Config.Ragebot, function(v) Config.Ragebot = v end)
uiRegistry["RagebotTeamCheck"] = addCheckbox(gbRagebot, "Team check", Config.TeamCheck, function(v) updateTeamCheck(v) end)
uiRegistry["RagebotAutoShoot"] = addCheckbox(gbRagebot, "Auto shoot", Config.RagebotAutoShoot, function(v) Config.RagebotAutoShoot = v end)
uiRegistry["RagebotTargetStrafe"] = addCheckbox(gbRagebot, "Target strafe", Config.RagebotTargetStrafe, function(v) Config.RagebotTargetStrafe = v end)
uiRegistry["TargetStrafeRadius"] = addSlider(gbRagebot, "Strafe radius", 6, 30, Config.TargetStrafeRadius, "%d studs", function(v) Config.TargetStrafeRadius = v end)
uiRegistry["TargetStrafeSpeed"] = addSlider(gbRagebot, "Strafe speed", 2, 15, Config.TargetStrafeSpeed, "%d spd", function(v) Config.TargetStrafeSpeed = v end)
uiRegistry["Autoplay"] = addCheckbox(gbRagebot, "Autoplay", Config.Autoplay, function(v) Config.Autoplay = v end)
uiRegistry["AutoplayDistance"] = addSlider(gbRagebot, "Autoplay stop distance", 8, 40, Config.AutoplayDistance, "%d studs", function(v) Config.AutoplayDistance = v end)

local gbMatch = createGroupbox(autoLeft, "Match Automation")
uiRegistry["AutoRespawn"] = addCheckbox(gbMatch, "Auto respawn", Config.AutoRespawn, function(v) Config.AutoRespawn = v end)
uiRegistry["AutoQueue"] = addCheckbox(gbMatch, "Auto queue", Config.AutoQueue, function(v) Config.AutoQueue = v end)
uiRegistry["QueueMode"] = addDropdown(gbMatch, "Queue", {"1v1", "2v2", "3v3", "4v4", "5v5"}, 1, function(v) Config.QueueMode = v end)

local gbVote = createGroupbox(autoLeft, "Automatic Voting")
uiRegistry["AutoVoteMaps"] = addCheckbox(gbVote, "Auto vote maps", Config.AutoVoteMaps, function(v) Config.AutoVoteMaps = v end)
uiRegistry["MapPriority"] = addDropdown(gbVote, "Map priority", {"Arena, Onyx, Crossroads", "Onyx, Arena, Crossroads", "Crossroads, Arena, Onyx"}, 1, function(v) Config.MapPriority = v end)
uiRegistry["AutoBanWeapons"] = addCheckbox(gbVote, "Auto ban weapons", Config.AutoBanWeapons, function(v) Config.AutoBanWeapons = v end)
uiRegistry["WeaponBanPriority"] = addDropdown(gbVote, "Weapon ban priority", {"Grenade Launcher, Minigun, RPG", "RPG, Grenade Launcher, Sniper", "Minigun, RPG, Shotgun"}, 1, function(v) Config.WeaponBanPriority = v end)
uiRegistry["SecondBanPriority"] = addDropdown(gbVote, "Second ban priority", {"Grenade Launcher, Minigun, RPG", "Sniper, Katana, Bow"}, 1, function(v) Config.SecondBanPriority = v end)

local gbLoadout = createGroupbox(autoLeft, "Automatic Loadout")
uiRegistry["AutoLoadout"] = addCheckbox(gbLoadout, "Auto loadout", Config.AutoLoadout, function(v) Config.AutoLoadout = v end)
uiRegistry["LoadoutOnlySelected"] = addCheckbox(gbLoadout, "Only on selected maps", Config.LoadoutOnlySelected, function(v) Config.LoadoutOnlySelected = v end)
uiRegistry["EnabledMaps"] = addDropdown(gbLoadout, "Enabled maps", {"Arena, Crossroads", "Onyx, Crossroads", "All Maps"}, 1, function(v) Config.EnabledMaps = v end)

local gbAntiAim = createGroupbox(autoRight, "Anti-Aim", "Changes the replicated pose only;\nyour camera and aim stay normal.")
uiRegistry["AntiAim"] = addCheckbox(gbAntiAim, "Enable anti-aim", Config.AntiAim, function(v) Config.AntiAim = v end)
uiRegistry["AntiAimMode"] = addDropdown(gbAntiAim, "Mode", {"Spin", "Jitter", "Backwards"}, 1, function(v) Config.AntiAimMode = v end)
uiRegistry["AntiAimSpeed"] = addSlider(gbAntiAim, "Spin speed", 10, 100, Config.AntiAimSpeed, "%d spd", function(v) Config.AntiAimSpeed = v end)

local gbDetectors = createGroupbox(autoRight, "Detectors", nil, "Ragebot's hacker priority consumes this detector and\ngame-provided Hacker attributes.")
uiRegistry["HackerDetector"] = addCheckbox(gbDetectors, "Hacker detector", Config.HackerDetector, function(v) Config.HackerDetector = v end)
uiRegistry["NotifyHackers"] = addCheckbox(gbDetectors, "Notify detected hackers", Config.NotifyHackers, function(v) Config.NotifyHackers = v end)
uiRegistry["HackerAutoLoad"] = addCheckbox(gbDetectors, "Auto load config on detect", Config.HackerAutoLoad, function(v) Config.HackerAutoLoad = v end)
uiRegistry["HackerProfile"] = addTextbox(gbDetectors, "Profile to auto load", Config.HackerProfile, "profile name (e.g. rage)", function(v) Config.HackerProfile = v end)
uiRegistry["SpeedThreshold"] = addSlider(gbDetectors, "Speed threshold", 50, 400, Config.SpeedThreshold, "%d studs/s/%d studs/s", function(v) Config.SpeedThreshold = v end)
uiRegistry["SpeedDuration"] = addSlider(gbDetectors, "Required duration", 0.1, 3, Config.SpeedDuration, "%.2f s/%.0f s", function(v) Config.SpeedDuration = v end)
uiRegistry["ModDetector"] = addCheckbox(gbDetectors, "Moderator detector", Config.ModDetector, function(v) Config.ModDetector = v end)
uiRegistry["NotifyMods"] = addCheckbox(gbDetectors, "Notify moderators", Config.NotifyMods, function(v) Config.NotifyMods = v end)
uiRegistry["MinGroupRank"] = addSlider(gbDetectors, "Minimum group rank", 1, 255, Config.MinGroupRank, "%d/%d", function(v) Config.MinGroupRank = v end)
uiRegistry["ModUsernames"] = addTextbox(gbDetectors, "Moderator usernames", Config.ModUsernames, "name1, name2", function(v) Config.ModUsernames = v end)
uiRegistry["ModFriendList"] = addTextbox(gbDetectors, "Moderator friend list", Config.ModFriendList, "name1, name2", function(v) Config.ModFriendList = v end)

local gbPickups = createGroupbox(autoRight, "Pickups & Tripmines")
uiRegistry["AutoPickup"] = addCheckbox(gbPickups, "Auto pickup nearby drops", Config.AutoPickup, function(v) Config.AutoPickup = v end)
uiRegistry["PickupRadius"] = addSlider(gbPickups, "Pickup radius", 10, 60, Config.PickupRadius, "%d studs/%d studs", function(v) Config.PickupRadius = v end)

local pageAim = tabPages["aim"]
local aimLeft = pageAim:FindFirstChild("LeftCol")
local aimRight = pageAim:FindFirstChild("RightCol")

local gbAimbot = createGroupbox(aimLeft, "Aimbot")
uiRegistry["Aimbot"] = addCheckbox(gbAimbot, "Enable aimbot", Config.Aimbot, function(v) Config.Aimbot = v end)
uiRegistry["AimbotTeamCheck"] = addCheckbox(gbAimbot, "Team check", Config.TeamCheck, function(v) updateTeamCheck(v) end)
uiRegistry["ContinuousTargeting"] = addCheckbox(gbAimbot, "Continuous targeting", Config.ContinuousTargeting, function(v) Config.ContinuousTargeting = v end)
uiRegistry["AimbotKeyMode"] = addDropdown(gbAimbot, "Key mode", {"Hold", "Toggle", "Always"}, 1, function(v) Config.AimbotKeyMode = v end)
uiRegistry["AimbotScopeOnly"] = addCheckbox(gbAimbot, "Scope only", Config.AimbotScopeOnly, function(v) Config.AimbotScopeOnly = v end)
uiRegistry["AimbotDisableReloading"] = addCheckbox(gbAimbot, "Disable while reloading", Config.AimbotDisableReloading, function(v) Config.AimbotDisableReloading = v end)
uiRegistry["AimbotSmoothing"] = addSlider(gbAimbot, "Smoothing speed", 0.05, 1, Config.AimbotSmoothing, "%.2f", function(v) Config.AimbotSmoothing = v end)
uiRegistry["InstantCameraLock"] = addCheckbox(gbAimbot, "Instant camera lock", Config.InstantCameraLock, function(v) Config.InstantCameraLock = v end)
uiRegistry["TrackThroughWalls"] = addCheckbox(gbAimbot, "Track lock through walls", Config.TrackThroughWalls, function(v) Config.TrackThroughWalls = v end)
uiRegistry["AimbotPart"] = addDropdown(gbAimbot, "Persistent lock part", {"Head", "Body", "Closest"}, 1, function(v) Config.AimbotPart = v end)
uiRegistry["CorrectLockedShots"] = addCheckbox(gbAimbot, "Correct locked shots", Config.CorrectLockedShots, function(v) Config.CorrectLockedShots = v end)

local gbSilent = createGroupbox(aimRight, "Silent Aim", "Redirects valid gun shots inside the FOV without moving your camera.")
uiRegistry["SilentAim"] = addCheckbox(gbSilent, "Enable silent aim", Config.SilentAim, function(v) Config.SilentAim = v end)
uiRegistry["SilentTeamCheck"] = addCheckbox(gbSilent, "Team check", Config.TeamCheck, function(v) updateTeamCheck(v) end)
uiRegistry["SilentKeyMode"] = addDropdown(gbSilent, "Key mode", {"Always", "Hold", "Toggle"}, 1, function(v) Config.SilentKeyMode = v end)
uiRegistry["SilentVisibleOnly"] = addCheckbox(gbSilent, "Visible targets only", Config.SilentVisibleOnly, function(v) Config.SilentVisibleOnly = v end)
uiRegistry["SilentVulnerableOnly"] = addCheckbox(gbSilent, "Vulnerable targets only", Config.SilentVulnerableOnly, function(v) Config.SilentVulnerableOnly = v end)
uiRegistry["SilentIgnoreDeflecting"] = addCheckbox(gbSilent, "Ignore deflecting", Config.SilentIgnoreDeflecting, function(v) Config.SilentIgnoreDeflecting = v end)
uiRegistry["SilentIgnoreShielded"] = addCheckbox(gbSilent, "Ignore shielded", Config.SilentIgnoreShielded, function(v) Config.SilentIgnoreShielded = v end)
uiRegistry["SilentTargetPart"] = addDropdown(gbSilent, "Target part", {"Head", "Body", "Closest"}, 1, function(v) Config.SilentTargetPart = v end)
uiRegistry["SilentHeadChance"] = addSlider(gbSilent, "Random head percentage", 0, 100, Config.SilentHeadChance, "%d%%", function(v) Config.SilentHeadChance = v end)
uiRegistry["SilentHitChance"] = addSlider(gbSilent, "Hit chance", 0, 100, Config.SilentHitChance, "%d%%", function(v) Config.SilentHitChance = v end)
uiRegistry["SilentFOV"] = addSlider(gbSilent, "FOV Radius", 30, 400, Config.SilentFOV, "%d px", function(v) updateSilentFOV(v) end)

local pageEsp = tabPages["esp"]
local espLeft = pageEsp:FindFirstChild("LeftCol")
local espRight = pageEsp:FindFirstChild("RightCol")

local gbEspMain = createGroupbox(espLeft, "Player ESP")
uiRegistry["ESP_Master"] = addCheckbox(gbEspMain, "Enable ESP", Config.ESP_Master, function(v) Config.ESP_Master = v end)
uiRegistry["ESP_EnemyOnly"] = addCheckbox(gbEspMain, "Enemy only", Config.ESP_EnemyOnly, function(v) Config.ESP_EnemyOnly = v end)
uiRegistry["ESP_Lobby"] = addCheckbox(gbEspMain, "Show in lobby", Config.ESP_Lobby, function(v) Config.ESP_Lobby = v end)
uiRegistry["ESP_MaxDistance"] = addSlider(gbEspMain, "Max distance", 100, 1000, Config.ESP_MaxDistance, "%d studs", function(v) Config.ESP_MaxDistance = v end)
uiRegistry["ESP_Boxes"] = addCheckbox(gbEspMain, "Box ESP", Config.ESP_Boxes, function(v) Config.ESP_Boxes = v end)
uiRegistry["ESP_Names"] = addCheckbox(gbEspMain, "Name ESP", Config.ESP_Names, function(v) Config.ESP_Names = v end)
uiRegistry["ESP_HealthBar"] = addCheckbox(gbEspMain, "Health bar", Config.ESP_HealthBar, function(v) Config.ESP_HealthBar = v end)
uiRegistry["ESP_Distance"] = addCheckbox(gbEspMain, "Distance ESP", Config.ESP_Distance, function(v) Config.ESP_Distance = v end)
uiRegistry["ESP_Weapon"] = addCheckbox(gbEspMain, "Weapon ESP", Config.ESP_Weapon, function(v) Config.ESP_Weapon = v end)

local gbEspExtra = createGroupbox(espRight, "Render & Chams")
uiRegistry["ESP_Chams"] = addCheckbox(gbEspExtra, "Chams / Highlight", Config.ESP_Chams, function(v) Config.ESP_Chams = v end)
uiRegistry["ESP_HeadDot"] = addCheckbox(gbEspExtra, "Head dot", Config.ESP_HeadDot, function(v) Config.ESP_HeadDot = v end)
uiRegistry["ESP_Tracers"] = addCheckbox(gbEspExtra, "Tracers", Config.ESP_Tracers, function(v) Config.ESP_Tracers = v end)
uiRegistry["ESP_Skeleton"] = addCheckbox(gbEspExtra, "Skeleton ESP", Config.ESP_Skeleton, function(v) Config.ESP_Skeleton = v end)
uiRegistry["ESP_Tripmines"] = addCheckbox(gbEspExtra, "Tripmines ESP", Config.ESP_Tripmines, function(v) Config.ESP_Tripmines = v end)
uiRegistry["ESP_FOV"] = addCheckbox(gbEspExtra, "Draw FOV Circle", Config.ESP_FOV, function(v) Config.ESP_FOV = v end)
uiRegistry["SilentFOVCircle"] = addSlider(gbEspExtra, "FOV circle size", 30, 400, Config.SilentFOV, "%d px", function(v) updateSilentFOV(v) end)

local gbTargetVis = createGroupbox(espRight, "Target Visualizer", "Renders an animated ground path and\nlive HUD card for active target.")
uiRegistry["TargetVisualizer"] = addCheckbox(gbTargetVis, "Enable target visualizer", Config.TargetVisualizer, function(v) Config.TargetVisualizer = v end)
uiRegistry["TargetVisualizerHUD"] = addCheckbox(gbTargetVis, "Target HUD card", Config.TargetVisualizerHUD, function(v) Config.TargetVisualizerHUD = v end)
uiRegistry["TargetVisualizerPath"] = addCheckbox(gbTargetVis, "Ground path & arrows", Config.TargetVisualizerPath, function(v) Config.TargetVisualizerPath = v end)
uiRegistry["VisualizerArrowSpacing"] = addSlider(gbTargetVis, "Arrow spacing", 5, 25, Config.VisualizerArrowSpacing, "%d studs", function(v) Config.VisualizerArrowSpacing = v end)
uiRegistry["VisualizerArrowSpeed"] = addSlider(gbTargetVis, "Arrow speed", 5, 30, Config.VisualizerArrowSpeed, "%d spd", function(v) Config.VisualizerArrowSpeed = v end)

local pageMove = tabPages["move"]
local moveLeft = pageMove:FindFirstChild("LeftCol")
local moveRight = pageMove:FindFirstChild("RightCol")

local gbMovement = createGroupbox(moveLeft, "Ground Movement")
uiRegistry["SpeedHack"] = addCheckbox(gbMovement, "Speed hack", Config.SpeedHack, function(v) Config.SpeedHack = v end)
uiRegistry["SpeedValue"] = addSlider(gbMovement, "WalkSpeed", 16, 120, Config.SpeedValue, "%d ws", function(v) Config.SpeedValue = v end)
uiRegistry["InfiniteJump"] = addCheckbox(gbMovement, "Infinite jump", Config.InfiniteJump, function(v) Config.InfiniteJump = v end)
uiRegistry["BunnyHop"] = addCheckbox(gbMovement, "Bunny hop", Config.BunnyHop, function(v) Config.BunnyHop = v end)

local gbAirMovement = createGroupbox(moveRight, "Flight & Collision")
uiRegistry["FlyHack"] = addCheckbox(gbAirMovement, "Fly hack", Config.FlyHack, function(v) Config.FlyHack = v end)
uiRegistry["FlySpeed"] = addSlider(gbAirMovement, "Fly speed", 20, 150, Config.FlySpeed, "%d spd", function(v) Config.FlySpeed = v end)
uiRegistry["Noclip"] = addCheckbox(gbAirMovement, "Noclip", Config.Noclip, function(v) Config.Noclip = v end)

local pageGuns = tabPages["guns"]
local gunsLeft = pageGuns:FindFirstChild("LeftCol")
local gunsRight = pageGuns:FindFirstChild("RightCol")

local gbGunMods = createGroupbox(gunsLeft, "Weapon Mechanics")
uiRegistry["NoRecoil"] = addCheckbox(gbGunMods, "No recoil", Config.NoRecoil, function(v)
    Config.NoRecoil = v
    ApplyWeaponModifications()
end)
uiRegistry["NoSpread"] = addCheckbox(gbGunMods, "No spread", Config.NoSpread, function(v)
    Config.NoSpread = v
    ApplyWeaponModifications()
end)
uiRegistry["FastReload"] = addCheckbox(gbGunMods, "Fast reload", Config.FastReload, function(v)
    Config.FastReload = v
    ApplyWeaponModifications()
end)
uiRegistry["RapidFire"] = addCheckbox(gbGunMods, "Rapid fire", Config.RapidFire, function(v)
    Config.RapidFire = v
    ApplyWeaponModifications()
end)
uiRegistry["InstantEquip"] = addCheckbox(gbGunMods, "Instant weapon equip", Config.InstantEquip, function(v)
    Config.InstantEquip = v
    ApplyWeaponModifications()
end)

local gbGunExtras = createGroupbox(gunsRight, "Weapon Features")
uiRegistry["AutomaticGuns"] = addCheckbox(gbGunExtras, "Automatic mode", Config.AutomaticGuns, function(v) Config.AutomaticGuns = v end)
uiRegistry["InfiniteAmmo"] = addCheckbox(gbGunExtras, "Infinite ammo", Config.InfiniteAmmo, function(v)
    Config.InfiniteAmmo = v
    ApplyWeaponModifications()
end)

gbGunExtras:AddLabel("Note: Fast reload, automatic mode, & infinite ammo are client-sided and may be clamped by server authority in ranked matches.", true)

local pageSkins = tabPages["skins"]
local skinsLeft = pageSkins:FindFirstChild("LeftCol")
local skinsRight = pageSkins:FindFirstChild("RightCol")

local gbSkins = createGroupbox(skinsLeft, "Weapon Customizer")
uiRegistry["UnlockAllSkins"] = addCheckbox(gbSkins, "Unlock all skins (Client)", Config.UnlockAllSkins, function(v)
    Config.UnlockAllSkins = v
    if v then
        UnlockAllCosmeticsClientSide()
        ShowNotification("OzionHub", "All 1,249 skins & cosmetics unlocked client-side.", "SUCCESS", 3)
    end
end)

uiRegistry["SelectedCategory"] = addDropdown(gbSkins, "Category", {"Primary", "Secondary", "Melee", "Utility"}, 1, function(v)
    Config.SelectedCategory = v
end)

uiRegistry["SelectedWeapon"] = addDropdown(gbSkins, "Weapon", {
    "Assault Rifle", "Sniper", "Shotgun", "Katana", "Revolver", "RPG",
    "Submachine Gun", "Hand Gun", "Minigun", "Grenade Launcher", "Energy Rifle", "Bow"
}, 1, function(v)
    Config.SelectedWeapon = v
end)

uiRegistry["SelectedWrap"] = addDropdown(gbSkins, "Equipped Wrap", {
    "Liquid Gold", "Mainframe", "Obsidian", "Scribble", "Vexed", "Igneous",
    "Candy Apple", "Red Rubber", "Tidal", "Purple", "Popsicle", "Lighthouse",
    "Celtic", "Empress", "PixelBlight", "Sunset", "Money", "Portal", "Venom", "Default"
}, 1, function(v)
    Config.SelectedWrap = v
end)

uiRegistry["SelectedCharm"] = addDropdown(gbSkins, "Equipped Charm", {
    "Dice", "Kashy", "Jolly Hat", "Devious Pumpkin", "Chibi Grenade",
    "Lucky Horseshoe", "Bat Daggers", "Pirate Hook", "Mini Present", "None"
}, 1, function(v)
    Config.SelectedCharm = v
end)

uiRegistry["SelectedFinisher"] = addDropdown(gbSkins, "Equipped Finisher", {
    "Flop", "Rising Star", "Gingerbreadify", "Warp Sickness", "Freeze",
    "Batsplosion", "Northern Light Show", "Supernova", "Orbital Strike", "Disintegrate", "None"
}, 1, function(v)
    Config.SelectedFinisher = v
end)

addButton(gbSkins, "Apply Skin to Weapon", function()
    UnlockAllCosmeticsClientSide()
    ApplySelectedCosmeticsClientSide(Config.SelectedWeapon, Config.SelectedWrap, Config.SelectedCharm, Config.SelectedFinisher)
    ShowNotification("OzionHub", "Equipped " .. tostring(Config.SelectedWrap) .. " on " .. tostring(Config.SelectedWeapon), "SUCCESS", 2.5)
end)

addButton(gbSkins, "Apply Skin to ALL Weapons", function()
    UnlockAllCosmeticsClientSide()
    ApplySelectedCosmeticsClientSide("All", Config.SelectedWrap, Config.SelectedCharm, Config.SelectedFinisher)
    ShowNotification("OzionHub", "Equipped " .. tostring(Config.SelectedWrap) .. " on ALL weapons!", "SUCCESS", 2.5)
end)

local function DumpCosmeticDebug()
    local out = {}
    local function add(text) table.insert(out, text) end
    pcall(function()
        local pdCtrl = require(LocalPlayer.PlayerScripts.Controllers.PlayerDataController)
        add("== PlayerDataController ==")
        for k, v in pairs(pdCtrl) do add("  " .. tostring(k) .. " : " .. typeof(v)) end
        local data = pdCtrl.CurrentData and pdCtrl.CurrentData.Data
        if data then
            add("== Data keys ==")
            for k, v in pairs(data) do add("  " .. tostring(k) .. " : " .. typeof(v)) end
            local inv = data.WeaponInventory
            if typeof(inv) == "table" then
                for _, w in pairs(inv) do
                    if typeof(w) == "table" and (w.Wrap or w.Charm or w.Finisher) then
                        add("== Example weapon entry: " .. tostring(w.Name) .. " ==")
                        for k, v in pairs(w) do
                            local extra = ""
                            if typeof(v) == "table" then
                                local keys = {}
                                for kk, vv in pairs(v) do table.insert(keys, tostring(kk) .. "=" .. tostring(vv)) end
                                extra = " {" .. table.concat(keys, ", ") .. "}"
                            end
                            add("  " .. tostring(k) .. " : " .. typeof(v) .. extra)
                        end
                        break
                    end
                end
            end
        end
    end)
    pcall(function()
        add("== Remotes.Data ==")
        for _, r in ipairs(ReplicatedStorage.Remotes.Data:GetChildren()) do
            add("  " .. r.Name .. " (" .. r.ClassName .. ")")
        end
    end)
    pcall(function()
        add("== PlayerScripts.Modules ==")
        for _, m in ipairs(LocalPlayer.PlayerScripts.Modules:GetDescendants()) do
            local n = m.Name:lower()
            if n:find("cosmetic") or n:find("emote") or n:find("inventory") or n:find("wrap") or n:find("charm") then
                add("  " .. m:GetFullName())
            end
        end
    end)
    local text = table.concat(out, "\n")
    print(text)
    if setclipboard then
        pcall(setclipboard, text)
        ShowNotification("OzionHub", "Cosmetics debug info copied to clipboard", "SUCCESS", 3)
    else
        ShowNotification("OzionHub", "Cosmetics debug info printed to the console", "SUCCESS", 3)
    end
end

addCheckbox(gbSkins, "Log equip requests (debug)", false, function(v) cosmeticDebugLog = v end)
addButton(gbSkins, "Copy cosmetics debug info", DumpCosmeticDebug)

local gbViewModel = createGroupbox(skinsRight, "Viewmodel & Render")
uiRegistry["RainbowGunSkin"] = addCheckbox(gbViewModel, "Rainbow gun skin", Config.RainbowGunSkin, function(v) Config.RainbowGunSkin = v end)
uiRegistry["WeaponChams"] = addCheckbox(gbViewModel, "Weapon chams & glow", Config.WeaponChams, function(v) Config.WeaponChams = v end)
uiRegistry["CustomViewModelFOV"] = addCheckbox(gbViewModel, "Custom Viewmodel FOV", Config.CustomViewModelFOV, function(v) Config.CustomViewModelFOV = v end)
uiRegistry["ViewModelFOVValue"] = addSlider(gbViewModel, "Viewmodel FOV", 50, 110, Config.ViewModelFOVValue, "%d°", function(v) Config.ViewModelFOVValue = v end)
uiRegistry["ViewModelXOffset"] = addSlider(gbViewModel, "Viewmodel X offset", -30, 30, Config.ViewModelXOffset, "%d/30", function(v) Config.ViewModelXOffset = v end)
uiRegistry["ViewModelYOffset"] = addSlider(gbViewModel, "Viewmodel Y offset", -30, 30, Config.ViewModelYOffset, "%d/30", function(v) Config.ViewModelYOffset = v end)
uiRegistry["ViewModelZOffset"] = addSlider(gbViewModel, "Viewmodel Z offset", -30, 30, Config.ViewModelZOffset, "%d/30", function(v) Config.ViewModelZOffset = v end)
uiRegistry["HideViewModel"] = addCheckbox(gbViewModel, "Hide viewmodel", Config.HideViewModel, function(v) Config.HideViewModel = v end)

local pageWorld = tabPages["world"]
local worldLeft = pageWorld:FindFirstChild("LeftCol")
local worldRight = pageWorld:FindFirstChild("RightCol")

local gbWorldMods = createGroupbox(worldLeft, "World & Visuals")
uiRegistry["Fullbright"] = addCheckbox(gbWorldMods, "Fullbright", Config.Fullbright, function(v)
    Config.Fullbright = v
    if v then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
    else
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
    end
end)
uiRegistry["NoFog"] = addCheckbox(gbWorldMods, "No fog", Config.NoFog, function(v)
    Config.NoFog = v
    if v then
        Lighting.FogEnd = 1000000
    else
        Lighting.FogEnd = 1000
    end
end)
uiRegistry["CustomFOV"] = addCheckbox(gbWorldMods, "Custom FOV", Config.CustomFOV, function(v)
    Config.CustomFOV = v
    if v then Camera.FieldOfView = Config.FOVValue end
end)
uiRegistry["FOVValue"] = addSlider(gbWorldMods, "FOV Angle", 70, 120, Config.FOVValue, "%d°", function(v)
    Config.FOVValue = v
    if Config.CustomFOV then Camera.FieldOfView = v end
end)

local gbWorldAudio = createGroupbox(worldRight, "Effects & Sounds")
uiRegistry["BulletTracers"] = addCheckbox(gbWorldAudio, "Bullet tracers", Config.BulletTracers, function(v) Config.BulletTracers = v end)
uiRegistry["HitSound"] = addDropdown(gbWorldAudio, "Hit sound", {"Skeet", "Rust", "Ding"}, 1, function(v) Config.HitSound = v end)

local pageView = tabPages["view"]
local viewLeft = pageView:FindFirstChild("LeftCol")
local viewRight = pageView:FindFirstChild("RightCol")

local gbView = createGroupbox(viewLeft, "Third-Person")
uiRegistry["ThirdPerson"] = addCheckbox(gbView, "Third-person mode", Config.ThirdPerson, function(v)
    Config.ThirdPerson = v
end)
uiRegistry["ThirdPersonDist"] = addSlider(gbView, "Third-person distance", 5, 30, Config.ThirdPersonDist, "%d studs", function(v) Config.ThirdPersonDist = v end)

local gbFreecam = createGroupbox(viewRight, "Freecam")
uiRegistry["Freecam"] = addCheckbox(gbFreecam, "Freecam mode", Config.Freecam, function(v) Config.Freecam = v end)
uiRegistry["FreecamSpeed"] = addSlider(gbFreecam, "Freecam speed", 10, 100, Config.FreecamSpeed, "%d spd", function(v) Config.FreecamSpeed = v end)

local function SerializeConfig()
    local tbl = {}
    for k, v in pairs(Config) do
        if typeof(v) == "EnumItem" then
            tbl[k] = { __type = "EnumItem", enumType = tostring(v.EnumType), name = v.Name }
        elseif typeof(v) == "Color3" then
            tbl[k] = { __type = "Color3", r = v.R, g = v.G, b = v.B }
        elseif typeof(v) == "Vector3" then
            tbl[k] = { __type = "Vector3", x = v.X, y = v.Y, z = v.Z }
        else
            tbl[k] = v
        end
    end
    return tbl
end

local function DeserializeConfig(data)
    local res = {}
    for k, v in pairs(data) do
        if type(v) == "table" and v.__type == "EnumItem" then
            local grp = Enum[v.enumType]
            if grp and grp[v.name] then
                res[k] = grp[v.name]
            end
        elseif type(v) == "table" and v.__type == "Color3" then
            res[k] = Color3.new(v.r, v.g, v.b)
        elseif type(v) == "table" and v.__type == "Vector3" then
            res[k] = Vector3.new(v.x, v.y, v.z)
        else
            res[k] = v
        end
    end
    return res
end

local ProfileSystem = {
    current = "default",
    autoload = "default",
    names = { "default", "rage" },
    profiles = {},
    nameInput = nil,
    dropdown = nil,
    autoLoadLabel = nil,
    defaultProfiles = {
        ["default"] = {
            Aimbot = false,
            TeamCheck = true,
            AimbotDisableReloading = true,
            AimbotFOV = 120,
            AimbotKey = Enum.UserInputType.MouseButton2,
            AimbotKeyMode = "Hold",
            AimbotPart = "Closest",
            AimbotScopeOnly = false,
            AimbotSmoothing = 0.28,
            AimbotVisibleOnly = true,
            AntiAim = false,
            AntiAimMode = "Jitter",
            AntiAimSpeed = 10,
            AutoBanWeapons = false,
            AutoLoadout = true,
            AutoPickup = false,
            AutoQueue = false,
            AutoRespawn = false,
            AutoVoteMaps = false,
            AutomaticGuns = false,
            Autoplay = false,
            AutoplayDistance = 18,
            BulletTracers = false,
            BunnyHop = false,
            CorrectLockedShots = true,
            ContinuousTargeting = true,
            CustomFOV = false,
            CustomViewModelFOV = false,
            ESP_Boxes = true,
            ESP_Chams = false,
            ESP_Distance = true,
            ESP_EnemyOnly = true,
            ESP_FOV = true,
            ESP_HeadDot = true,
            ESP_HealthBar = true,
            ESP_Lobby = true,
            ESP_Master = true,
            ESP_MaxDistance = 500,
            ESP_Names = true,
            ESP_Skeleton = true,
            ESP_Tracers = false,
            ESP_Tripmines = true,
            ESP_Weapon = true,
            EnabledMaps = "Arena, Crossroads",
            FastReload = false,
            FlyHack = false,
            FlySpeed = 50,
            FOVValue = 90,
            Freecam = false,
            FreecamSpeed = 40,
            Fullbright = false,
            HackerAutoLoad = true,
            HackerDetector = true,
            HackerProfile = "rage",
            HideViewModel = false,
            HitSound = "Skeet",
            InfiniteAmmo = false,
            InfiniteJump = false,
            InstantCameraLock = false,
            InstantEquip = false,
            LoadoutOnlySelected = false,
            MapPriority = "Arena, Onyx, Crossroads",
            MenuKey = Enum.KeyCode.RightControl,
            MinGroupRank = 200,
            ModDetector = true,
            ModFriendList = "name1, name2",
            ModUsernames = "name1, name2",
            NoFog = true,
            NoRecoil = true,
            NoSpread = true,
            Noclip = false,
            NotifyHackers = true,
            NotifyMods = true,
            PickupRadius = 25,
            QueueMode = "1v1",
            Ragebot = false,
            RagebotAutoShoot = false,
            RagebotTargetPriority = "Distance",
            RagebotTargetStrafe = false,
            RagebotWallbang = true,
            RainbowGunSkin = false,
            RapidFire = false,
            SecondBanPriority = "Grenade Launcher, Minigun, RPG",
            SelectedCategory = "Primary",
            SelectedCharm = "Dice",
            SelectedFinisher = "Gingerbreadify",
            SelectedWeapon = "Assault Rifle",
            SelectedWrap = "Liquid Gold",
            SilentAim = true,
            SilentFOV = 242,
            SilentHeadChance = 59,
            SilentHitChance = 78,
            SilentIgnoreDeflecting = true,
            SilentIgnoreShielded = true,
            SilentKey = Enum.KeyCode.C,
            SilentKeyMode = "Always",
            SilentTargetPart = "Head",
            SilentVisibleOnly = true,
            SilentVulnerableOnly = true,
            SpeedDuration = 0.75,
            SpeedHack = false,
            SpeedThreshold = 180,
            SpeedValue = 49,
            TargetStrafeRadius = 14,
            TargetStrafeSpeed = 6,
            TargetVisualizer = true,
            TargetVisualizerHUD = true,
            TargetVisualizerPath = true,
            ThirdPerson = false,
            ThirdPersonDist = 12,
            TrackThroughWalls = true,
            UnlockAllSkins = false,
            ViewModelFOVValue = 70,
            ViewModelXOffset = 0,
            ViewModelYOffset = 0,
            ViewModelZOffset = 0,
            VisualizerArrowSpacing = 10,
            VisualizerArrowSpeed = 14,
            WeaponBanPriority = "Grenade Launcher, Minigun, RPG",
            WeaponChams = false,
        },
        ["rage"] = {
            Aimbot = false,
            TeamCheck = true,
            AimbotDisableReloading = true,
            AimbotFOV = 120,
            AimbotKey = Enum.UserInputType.MouseButton2,
            AimbotKeyMode = "Hold",
            AimbotPart = "Closest",
            AimbotScopeOnly = false,
            AimbotSmoothing = 0.28,
            AimbotVisibleOnly = true,
            AntiAim = false,
            AntiAimMode = "Jitter",
            AntiAimSpeed = 10,
            AutoBanWeapons = false,
            AutoLoadout = false,
            AutoPickup = false,
            AutoQueue = false,
            AutoRespawn = false,
            AutoVoteMaps = false,
            AutomaticGuns = false,
            Autoplay = true,
            AutoplayDistance = 18,
            BulletTracers = true,
            BunnyHop = true,
            CorrectLockedShots = true,
            ContinuousTargeting = true,
            CustomFOV = false,
            CustomViewModelFOV = false,
            ESP_Boxes = true,
            ESP_Chams = true,
            ESP_Distance = true,
            ESP_EnemyOnly = true,
            ESP_FOV = true,
            ESP_HeadDot = true,
            ESP_HealthBar = true,
            ESP_Lobby = true,
            ESP_Master = true,
            ESP_MaxDistance = 500,
            ESP_Names = true,
            ESP_Skeleton = true,
            ESP_Tracers = false,
            ESP_Tripmines = true,
            ESP_Weapon = true,
            EnabledMaps = "Arena, Crossroads",
            FastReload = false,
            FlyHack = false,
            FlySpeed = 50,
            FOVValue = 90,
            Freecam = false,
            FreecamSpeed = 40,
            Fullbright = false,
            HackerAutoLoad = true,
            HackerDetector = true,
            HackerProfile = "rage",
            HideViewModel = false,
            HitSound = "Skeet",
            InfiniteAmmo = false,
            InfiniteJump = false,
            InstantCameraLock = false,
            InstantEquip = false,
            LoadoutOnlySelected = false,
            MapPriority = "Arena, Onyx, Crossroads",
            MenuKey = Enum.KeyCode.RightControl,
            MinGroupRank = 200,
            ModDetector = true,
            ModFriendList = "name1, name2",
            ModUsernames = "name1, name2",
            NoFog = true,
            NoRecoil = true,
            NoSpread = true,
            Noclip = false,
            NotifyHackers = true,
            NotifyMods = true,
            PickupRadius = 25,
            QueueMode = "1v1",
            Ragebot = true,
            RagebotAutoShoot = true,
            RagebotTargetPriority = "Distance",
            RagebotTargetStrafe = true,
            RagebotWallbang = true,
            RainbowGunSkin = false,
            RapidFire = false,
            SecondBanPriority = "Grenade Launcher, Minigun, RPG",
            SelectedCategory = "Primary",
            SelectedCharm = "Dice",
            SelectedFinisher = "Gingerbreadify",
            SelectedWeapon = "Assault Rifle",
            SelectedWrap = "Liquid Gold",
            SilentAim = true,
            SilentFOV = 400,
            SilentHeadChance = 100,
            SilentHitChance = 100,
            SilentIgnoreDeflecting = true,
            SilentIgnoreShielded = true,
            SilentKey = Enum.KeyCode.C,
            SilentKeyMode = "Always",
            SilentTargetPart = "Head",
            SilentVisibleOnly = true,
            SilentVulnerableOnly = true,
            SpeedDuration = 0.75,
            SpeedHack = true,
            SpeedThreshold = 180,
            SpeedValue = 49,
            TargetStrafeRadius = 14,
            TargetStrafeSpeed = 6,
            TargetVisualizer = true,
            TargetVisualizerHUD = true,
            TargetVisualizerPath = true,
            ThirdPerson = false,
            ThirdPersonDist = 12,
            TrackThroughWalls = true,
            UnlockAllSkins = false,
            ViewModelFOVValue = 70,
            ViewModelXOffset = 0,
            ViewModelYOffset = 0,
            ViewModelZOffset = 0,
            VisualizerArrowSpacing = 10,
            VisualizerArrowSpeed = 14,
            WeaponBanPriority = "Grenade Launcher, Minigun, RPG",
            WeaponChams = false,
        }
    }
}

function ProfileSystem.readStore()
    local ok, res = pcall(function()
        if readfile and isfile and isfile("ozionhub_config.json") then
            local raw = readfile("ozionhub_config.json")
            return HttpService:JSONDecode(raw)
        end
        return nil
    end)
    if ok and type(res) == "table" then
        if type(res.profiles) == "table" then
            ProfileSystem.profiles = res.profiles
            ProfileSystem.autoload = tostring(res.autoload or "default")
        else
            ProfileSystem.profiles = { ["default"] = res }
            ProfileSystem.autoload = "default"
        end
    else
        ProfileSystem.profiles = {}
        ProfileSystem.autoload = "default"
    end

    for pName, pData in pairs(ProfileSystem.defaultProfiles) do
        if not ProfileSystem.profiles[pName] then
            local copy = {}
            for k, v in pairs(pData) do copy[k] = v end
            ProfileSystem.profiles[pName] = copy
        end
    end

    local list = {}
    for name, _ in pairs(ProfileSystem.profiles) do
        table.insert(list, tostring(name))
    end
    table.sort(list)
    if #list == 0 then
        list = { "default", "rage" }
    end
    ProfileSystem.names = list

    local found = false
    for _, name in ipairs(ProfileSystem.names) do
        if name == ProfileSystem.autoload then
            found = true
            break
        end
    end
    if not found then
        ProfileSystem.autoload = "default"
    end
    ProfileSystem.current = ProfileSystem.autoload

    if not (isfile and isfile("ozionhub_config.json")) then
        ProfileSystem.writeStore()
    end
end

function ProfileSystem.writeStore()
    if not writefile then return false end
    local store = {
        autoload = ProfileSystem.autoload or "default",
        profiles = ProfileSystem.profiles
    }
    local ok = pcall(function()
        local json = HttpService:JSONEncode(store)
        writefile("ozionhub_config.json", json)
    end)
    return ok
end

function ProfileSystem.applyProfile(pName, notify)
    pName = tostring(pName or ProfileSystem.current or "default")
    local data = ProfileSystem.profiles[pName]
    if not data then
        if notify then
            ShowNotification("OzionHub", "Profile not found: " .. pName, "WARN", 2.5)
        end
        return false
    end

    local res = DeserializeConfig(data)
    for k, v in pairs(res) do
        Config[k] = v
        if uiRegistry[k] and uiRegistry[k].Set then
            pcall(function() uiRegistry[k].Set(v) end)
        end
    end
    ApplyWeaponModifications()
    if Config.UnlockAllSkins then UnlockAllCosmeticsClientSide() end

    ProfileSystem.current = pName
    if ProfileSystem.nameInput and ProfileSystem.nameInput.Set then
        ProfileSystem.nameInput.Set(pName)
    end
    if ProfileSystem.dropdown and ProfileSystem.dropdown.Set then
        ProfileSystem.dropdown.Set(pName)
    end
    if notify then
        ShowNotification("OzionHub", "Loaded profile: " .. pName, "SUCCESS", 2.5)
    end
    return true
end

function ProfileSystem.saveProfile(pName)
    local rawName = pName or (ProfileSystem.nameInput and ProfileSystem.nameInput.Get and ProfileSystem.nameInput.Get())
    if not rawName or rawName:gsub("%s+", "") == "" then
        rawName = ProfileSystem.current or "default"
    end
    local cleanName = rawName:match("^%s*(.-)%s*$")
    ProfileSystem.profiles[cleanName] = SerializeConfig()
    ProfileSystem.current = cleanName

    local list = {}
    for name, _ in pairs(ProfileSystem.profiles) do
        table.insert(list, tostring(name))
    end
    table.sort(list)
    ProfileSystem.names = list

    ProfileSystem.writeStore()
    if ProfileSystem.dropdown and ProfileSystem.dropdown.SetOptions then
        ProfileSystem.dropdown.SetOptions(ProfileSystem.names, cleanName)
    end
    if ProfileSystem.nameInput and ProfileSystem.nameInput.Set then
        ProfileSystem.nameInput.Set(cleanName)
    end
    ShowNotification("OzionHub", "Saved profile: " .. cleanName, "SUCCESS", 2.5)
end

function ProfileSystem.setAutoload(pName)
    local target = pName or ProfileSystem.current or "default"
    if not ProfileSystem.profiles[target] then
        ProfileSystem.profiles[target] = SerializeConfig()
    end
    ProfileSystem.autoload = target
    ProfileSystem.writeStore()
    if ProfileSystem.autoLoadLabel then
        ProfileSystem.autoLoadLabel.Text = "Auto-load on start: " .. target
    end
    ShowNotification("OzionHub", "Auto-load set to: " .. target, "SUCCESS", 2.5)
end

function ProfileSystem.deleteProfile(pName)
    local target = pName or ProfileSystem.current
    if #ProfileSystem.names <= 1 then
        ShowNotification("OzionHub", "Cannot delete only remaining profile.", "WARN", 2.5)
        return
    end

    ProfileSystem.profiles[target] = nil
    local list = {}
    for name, _ in pairs(ProfileSystem.profiles) do
        table.insert(list, tostring(name))
    end
    table.sort(list)
    ProfileSystem.names = list

    if ProfileSystem.autoload == target then
        ProfileSystem.autoload = ProfileSystem.names[1]
    end
    ProfileSystem.current = ProfileSystem.names[1]

    ProfileSystem.writeStore()
    if ProfileSystem.dropdown and ProfileSystem.dropdown.SetOptions then
        ProfileSystem.dropdown.SetOptions(ProfileSystem.names, ProfileSystem.current)
    end
    if ProfileSystem.nameInput and ProfileSystem.nameInput.Set then
        ProfileSystem.nameInput.Set(ProfileSystem.current)
    end
    if ProfileSystem.autoLoadLabel then
        ProfileSystem.autoLoadLabel.Text = "Auto-load on start: " .. ProfileSystem.autoload
    end
    ProfileSystem.applyProfile(ProfileSystem.current, false)
    ShowNotification("OzionHub", "Deleted profile: " .. target, "INFO", 2.5)
end

ProfileSystem.readStore()

local pageConfig = tabPages["config"]
local cfgLeft = pageConfig:FindFirstChild("LeftCol")
local cfgRight = pageConfig:FindFirstChild("RightCol")

local gbConfig = createGroupbox(cfgLeft, "Profiles")

ProfileSystem.nameInput = addTextbox(gbConfig, "Profile name", ProfileSystem.current, "Profile name...", function(txt)
    ProfileSystem.current = txt
end)

ProfileSystem.dropdown = addDropdown(gbConfig, "Select profile", ProfileSystem.names, 1, function(selected)
    ProfileSystem.current = selected
    if ProfileSystem.nameInput and ProfileSystem.nameInput.Set then
        ProfileSystem.nameInput.Set(selected)
    end
end)

addButton(gbConfig, "Save profile", function()
    ProfileSystem.saveProfile()
end)

addButton(gbConfig, "Load profile", function()
    ProfileSystem.applyProfile(ProfileSystem.current, true)
end)

addButton(gbConfig, "Set as auto-load", function()
    ProfileSystem.setAutoload(ProfileSystem.current)
end)

addButton(gbConfig, "Delete profile", function()
    ProfileSystem.deleteProfile(ProfileSystem.current)
end)

local autoLoadObsidianLabel = gbConfig:AddLabel("Auto-load on start: " .. ProfileSystem.autoload)
-- ProfileSystem assigns `.Text = ...` on this, so proxy it to Obsidian's SetText
ProfileSystem.autoLoadLabel = setmetatable({}, {
    __newindex = function(t, key, value)
        if key == "Text" then
            pcall(function() autoLoadObsidianLabel:SetText(tostring(value)) end)
        else
            rawset(t, key, value)
        end
    end,
})

addButton(gbConfig, "Unload script", UnloadScript)

local gbShortcuts = createGroupbox(cfgRight, "Keybinds & Info")

gbShortcuts:AddLabel("Menu toggle"):AddKeyPicker("MenuKeybind", {
    Default = "RightControl",
    NoUI = true,
    Mode = "Toggle",
    Text = "Menu keybind",
    ChangedCallback = function(newKey)
        if uiBuilding then return end
        pcall(function()
            if typeof(newKey) == "EnumItem" then
                Config.MenuKey = newKey
            elseif type(newKey) == "string" and Enum.KeyCode[newKey] then
                Config.MenuKey = Enum.KeyCode[newKey]
            end
        end)
    end,
})
Library.ToggleKeybind = Options.MenuKeybind

uiRegistry["MobileToggle"] = addCheckbox(gbShortcuts, "Mobile toggle button", Config.MobileToggle, function(v)
    Config.MobileToggle = v
    local mBtn = screenGui:FindFirstChild("OzionHubMobileToggle")
    if mBtn then mBtn.Visible = v end
end)

-- Theme picker (Obsidian ThemeManager) lives on the Config tab too
if ThemeManager then
    pcall(function()
        ThemeManager:SetLibrary(Library)
        ThemeManager:SetFolder("OzionHub")
        ThemeManager:ApplyToTab(pageConfig.Tab)
    end)
    -- make sure OzionHub's pink palette is what the pickers start on
    local brand = {
        BackgroundColor = Theme.WindowBg,
        MainColor = Theme.CardBg,
        AccentColor = Theme.AccentPink,
        OutlineColor = Theme.BorderCard,
        FontColor = Theme.TextWhite,
    }
    for optName, color in pairs(brand) do
        pcall(function()
            if Options[optName] then Options[optName]:SetValueRGB(color) end
        end)
    end
end

uiBuilding = false

pcall(function()
    ProfileSystem.applyProfile(ProfileSystem.autoload, false)
end)

local fovCircleGui = Instance.new("Frame")
fovCircleGui.Name = "FOVCircle"
fovCircleGui.Size = UDim2.new(0, Config.SilentFOV * 2, 0, Config.SilentFOV * 2)
fovCircleGui.Position = UDim2.new(0.5, -Config.SilentFOV, 0.5, -Config.SilentFOV)
fovCircleGui.BackgroundTransparency = 1
fovCircleGui.Visible = Config.ESP_FOV
fovCircleGui.ZIndex = 1
fovCircleGui.Parent = screenGui
table.insert(cleanUpInstances, fovCircleGui)

Instance.new("UICorner", fovCircleGui).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Theme.AccentGreen
fovStroke.Transparency = 0.5
fovStroke.Thickness = 1.2
fovStroke.Parent = fovCircleGui

do
    local mBtn = Instance.new("TextButton")
    mBtn.Name = "OzionHubMobileToggle"
    mBtn.Size = UDim2.new(0, 36, 0, 36)
    mBtn.Position = UDim2.new(0, 16, 0, 50)
    mBtn.BackgroundColor3 = Theme.ButtonBg
    mBtn.BorderSizePixel = 0
    mBtn.Font = MainFont
    mBtn.Text = "O"
    mBtn.TextColor3 = Theme.AccentPinkLight
    mBtn.TextSize = 16
    mBtn.ZIndex = 50
    mBtn.Visible = (Config.MobileToggle == true or (Config.MobileToggle == nil and UserInputService.TouchEnabled))
    mBtn.Parent = screenGui
    table.insert(cleanUpInstances, mBtn)

    Instance.new("UICorner", mBtn).CornerRadius = UDim.new(0, 8)
    local mStroke = Instance.new("UIStroke")
    mStroke.Color = Theme.AccentPink
    mStroke.Thickness = 1.2
    mStroke.Parent = mBtn

    local mDragging = false
    local mDragStart, mStartPos
    mBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            mDragging = true
            mDragStart = input.Position
            mStartPos = mBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then mDragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if mDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - mDragStart
            mBtn.Position = UDim2.new(mStartPos.X.Scale, mStartPos.X.Offset + delta.X, mStartPos.Y.Scale, mStartPos.Y.Offset + delta.Y)
        end
    end)
    mBtn.MouseButton1Click:Connect(function()
        setMenuVisible(not mainWindow.Visible)
    end)
end


local isSilentKeyDown = false

local function performSilentAimRedirect(origin, defaultTargetPos, maxDist)
    if not isRunning or not Config.SilentAim then return defaultTargetPos end
    if Config.SilentKeyMode == "Hold" and not isSilentKeyDown then return defaultTargetPos end

    local target = getClosestTarget(Config.SilentFOV, Config.SilentVisibleOnly, Config.SilentTargetPart)
    if target then
        if isTeammate(target) then return defaultTargetPos end
        local hitRoll = math.random(1, 100)
        if hitRoll <= Config.SilentHitChance then
            local aimPos = target.Position
            if math.random(1, 100) <= Config.SilentHeadChance then
                local tChar = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
                local head = tChar and (tChar:FindFirstChild("Head") or tChar:FindFirstChild("HitboxHead"))
                if head then aimPos = head.Position end
            end
            return aimPos
        end
    end
    return defaultTargetPos
end

local hitSoundIds = {
    Skeet = "rbxassetid://4817809188",
    Rust = "rbxassetid://1255040462",
    Ding = "rbxassetid://9114223175"
}

local lastHitSoundTime = 0
local function PlayHitSound()
    local now = tick()
    if now - lastHitSoundTime < 0.04 then return end
    lastHitSoundTime = now

    pcall(function()
        local sndId = hitSoundIds[Config.HitSound] or hitSoundIds.Skeet
        local snd = Instance.new("Sound")
        snd.SoundId = sndId
        snd.Volume = 1.2
        snd.Parent = SoundService
        snd:Play()
        local deb = game:GetService("Debris")
        if deb then
            deb:AddItem(snd, 1.5)
        else
            task.delay(1.5, function()
                if snd and snd.Parent then snd:Destroy() end
            end)
        end
    end)
end

local function CreateBulletTracer(origin, targetPos)
    if not Config.BulletTracers or not isRunning then return end
    pcall(function()
        if typeof(origin) ~= "Vector3" or typeof(targetPos) ~= "Vector3" then return end
        local diff = targetPos - origin
        local dist = diff.Magnitude
        if dist < 3 or dist > 1500 then return end

        local a0 = Instance.new("Attachment")
        a0.Position = origin
        a0.Parent = Workspace.Terrain

        local a1 = Instance.new("Attachment")
        a1.Position = targetPos
        a1.Parent = Workspace.Terrain

        local beam = Instance.new("Beam")
        beam.Name = "OzionHubBulletTracer"
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Width0 = 0.06
        beam.Width1 = 0.06
        beam.FaceCamera = true
        beam.LightEmission = 1
        beam.LightInfluence = 0
        beam.Color = ColorSequence.new(Theme.AccentPinkLight)
        beam.Transparency = NumberSequence.new(0)
        beam.Parent = Workspace.Terrain
        table.insert(cleanUpInstances, a0)
        table.insert(cleanUpInstances, a1)
        table.insert(cleanUpInstances, beam)

        task.spawn(function()
            local d = 0.35
            local t0 = tick()
            while isRunning and (tick() - t0 < d) do
                local alpha = math.clamp((tick() - t0) / d, 0, 1)
                beam.Transparency = NumberSequence.new(alpha)
                task.wait(0.03)
            end
            if a0.Parent then a0:Destroy() end
            if a1.Parent then a1:Destroy() end
            if beam.Parent then beam:Destroy() end
        end)
    end)
end

pcall(function()
    local crc = LocalPlayer.PlayerScripts:FindFirstChild("Modules") and LocalPlayer.PlayerScripts.Modules:FindFirstChild("ClientReplicatedClasses")
    local cf = crc and crc:FindFirstChild("ClientFighter")
    local ciMod = cf and cf:FindFirstChild("ClientItem")
    if ciMod then
        local ci = require(ciMod)
        if ci and type(ci._PlayHitmarkerQueue) == "function" then
            local origHitmarker = ci._PlayHitmarkerQueue
            ci._PlayHitmarkerQueue = function(self, ...)
                pcall(function()
                    local fighter = self and (self.Fighter or self._fighter or self.Player)
                    local isLocal = (fighter == LocalPlayer) or (self and self.Character == LocalPlayer.Character)
                    if isLocal then
                        PlayHitSound()
                    end
                end)
                return origHitmarker(self, ...)
            end
        end

        local ii = ciMod:FindFirstChild("ItemInterface")
        local mMod = ii and ii:FindFirstChild("Mouse")
        local mcMod = mMod and mMod:FindFirstChild("MouseCrosshair")
        if mcMod then
            local mc = require(mcMod)
            if mc and type(mc.DamageEffect) == "function" then
                local origDamageEffect = mc.DamageEffect
                mc.DamageEffect = function(self, ...)
                    pcall(PlayHitSound)
                    return origDamageEffect(self, ...)
                end
            end
        end
    end
end)

pcall(function()
    local gunModule = LocalPlayer.PlayerScripts:FindFirstChild("Modules") and LocalPlayer.PlayerScripts.Modules:FindFirstChild("ItemTypes") and LocalPlayer.PlayerScripts.Modules.ItemTypes:FindFirstChild("Gun")
    if gunModule then
        local gun = require(gunModule)
        if gun and type(gun._LocalTracers) == "function" then
            local origLocalTracers = gun._LocalTracers
            gun._LocalTracers = function(self, ...)
                if Config.BulletTracers and isRunning then
                    pcall(function()
                        local cam = Workspace.CurrentCamera
                        local mPos = UserInputService:GetMouseLocation()
                        local ray = cam:ViewportPointToRay(mPos.X, mPos.Y)
                        local origin = cam.CFrame.Position - Vector3.new(0, 0.4, 0)
                        local hitPos = origin + (ray.Direction * 350)
                        local rp = RaycastParams.new()
                        rp.FilterType = Enum.RaycastFilterType.Exclude
                        rp.FilterDescendantsInstances = {LocalPlayer.Character, cam}
                        local res = Workspace:Raycast(origin, ray.Direction * 350, rp)
                        if res then hitPos = res.Position end
                        CreateBulletTracer(origin, hitPos)
                    end)
                end
                return origLocalTracers(self, ...)
            end
        end
    end
end)

pcall(function()
    local utilModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Utility")
    if utilModule then
        local util = require(utilModule)
        if util and type(util.Raycast) == "function" then
            originalUtilityRaycast = util.Raycast
            util.Raycast = function(...)
                local n = select("#", ...)
                local args = {...}
                local offset = 0
                if typeof(args[1]) == "table" or typeof(args[1]) == "Instance" then
                    offset = 1
                end
                local originVec = args[offset + 1]
                local targetPos = args[offset + 2]
                local maxDist = args[offset + 3]
                if isRunning and Config.SilentAim then
                    pcall(function()
                        if typeof(originVec) == "Vector3" and typeof(targetPos) == "Vector3" then
                            local redirectedPos = performSilentAimRedirect(originVec, targetPos, maxDist)
                            if redirectedPos and typeof(redirectedPos) == "Vector3" and redirectedPos ~= targetPos then
                                local diff = redirectedPos - originVec
                                if diff.Magnitude > 0.05 then
                                    local dir = diff.Unit * (maxDist or 1000)
                                    args[offset + 2] = originVec + dir
                                end
                            end
                        end
                    end)
                end
                return originalUtilityRaycast(unpack(args, 1, n))
            end
        end
    end
end)

if hookmetamethod and newcclosure and checkcaller then
    originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if not isRunning or checkcaller() or not method then
            if setnamecallmethod then setnamecallmethod(method) end
            return originalNamecall(self, ...)
        end

        local m = method:lower()
        if m ~= "fireserver" and m ~= "invokeserver" then
            if setnamecallmethod then setnamecallmethod(method) end
            return originalNamecall(self, ...)
        end

        local args = {...}

        -- Equip clicks from the game's own inventory UI
        if m == "fireserver" and typeof(self) == "Instance" and self.Name == "EquipCosmetic" then
            local weaponName, slot, cosmeticName = args[1], args[2], args[3]

            if cosmeticDebugLog then
                local parts = {}
                for i = 1, select("#", ...) do
                    parts[i] = typeof(args[i]) .. ":" .. tostring(args[i])
                end
                print("[OzionHub] EquipCosmetic(" .. table.concat(parts, ", ") .. ")")
            end

            if realOwnedCosmetics and type(weaponName) == "string" and (slot == "Wrap" or slot == "Charm" or slot == "Finisher" or slot == "Skin") then
                SetLocalEquippedCosmetic(weaponName, slot, cosmeticName)
                local isClear = (cosmeticName == nil or cosmeticName == "None" or cosmeticName == "Default")
                if not isClear and realOwnedCosmetics[cosmeticName] ~= true then
                    return -- not really owned: the server would reject it, so keep it local
                end
            end
        elseif cosmeticDebugLog and typeof(self) == "Instance" and type(self.Name) == "string" and (self.Name:lower():find("equip") or self.Name:lower():find("emote")) then
            local parts = {}
            for i = 1, select("#", ...) do
                parts[i] = typeof(args[i]) .. ":" .. tostring(args[i])
            end
            print("[OzionHub] " .. self.Name .. "(" .. table.concat(parts, ", ") .. ")")
        end

        if Config.SilentAim and typeof(self) == "Instance" and (self.Name == "UseItem" or self.Name == "UseItemFeedback" or self.Name == "SnowballThrow") then
            local target = getClosestTarget(Config.SilentFOV, Config.SilentVisibleOnly, Config.SilentTargetPart)
            if target and not isTeammate(target) then
                local hitRoll = math.random(1, 100)
                if hitRoll <= Config.SilentHitChance then
                    local aimPos = target.Position
                    if math.random(1, 100) <= Config.SilentHeadChance then
                        local tChar = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
                        local head = tChar and (tChar:FindFirstChild("Head") or tChar:FindFirstChild("HitboxHead"))
                        if head then aimPos = head.Position end
                    end
                    if #args >= 2 and typeof(args[2]) == "Vector3" then
                        args[2] = aimPos
                    elseif #args >= 1 and typeof(args[1]) == "Vector3" then
                        args[1] = aimPos
                    end
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        CreateBulletTracer(LocalPlayer.Character.HumanoidRootPart.Position, aimPos)
                    end
                    if setnamecallmethod then setnamecallmethod(method) end
                    return originalNamecall(self, unpack(args))
                end
            end
        end

        if m == "invokeserver" and typeof(self) == "Instance" and self.ClassName == "RemoteFunction" then
            return self.InvokeServer(self, ...)
        end

        if setnamecallmethod then setnamecallmethod(method) end
        return originalNamecall(self, ...)
    end))
end

pcall(function()
    local lp = Players.LocalPlayer
    local ctrl = lp.PlayerScripts:FindFirstChild("Controllers")
    if ctrl then
        local tc = ctrl:FindFirstChild("TimerController")
        if tc then
            local tcm = require(tc)
            if tcm and type(tcm.SetTimeRemaining) == "function" then
                local origSet = tcm.SetTimeRemaining
                tcm.SetTimeRemaining = function(self, name, duration, ...)
                    if typeof(duration) ~= "number" then
                        if typeof(name) == "number" then
                            duration = name
                            name = "Timer"
                        else
                            return
                        end
                    end
                    return origSet(self, name, duration, ...)
                end
            end
        end

        local fc = ctrl:FindFirstChild("FFlagController")
        if fc then
            local fcm = require(fc)
            if fcm and type(fcm._Fetch) == "function" then
                fcm._Fetch = function(self, ...)
                    local res
                    pcall(function()
                        res = ReplicatedStorage.Remotes.Misc.RequestFFlags:InvokeServer()
                    end)
                    if typeof(res) == "table" then
                        for i, v in pairs(res) do
                            pcall(function() self:SetFFlag(i, v) end)
                        end
                    end
                end
            end
        end
    end
end)

local SKELETON_CONNECTIONS_R15 = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" }
}

local SKELETON_CONNECTIONS_R6 = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" }
}

local function createGuiLine(parent, zIndex)
    local line = Instance.new("Frame")
    line.BorderSizePixel = 0
    line.BackgroundColor3 = Theme.AccentPinkLight
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.Visible = false
    line.ZIndex = zIndex or 2
    line.Parent = parent
    return line
end

local function updateGuiLine(line, p1, p2, thickness, color)
    local diff = p2 - p1
    local dist = diff.Magnitude
    if dist < 1 then
        line.Visible = false
        return
    end
    line.Size = UDim2.new(0, dist, 0, thickness or 1.2)
    line.Position = UDim2.new(0, (p1.X + p2.X) * 0.5, 0, (p1.Y + p2.Y) * 0.5)
    line.Rotation = math.deg(math.atan2(diff.Y, diff.X))
    if color then line.BackgroundColor3 = color end
    line.Visible = true
end

local espObjects = {}
local function createESPForPlayer(p)
    local holder = Instance.new("Folder")
    holder.Name = "ESP_" .. p.Name
    holder.Parent = screenGui
    table.insert(cleanUpInstances, holder)

    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.ZIndex = 2
    box.Parent = holder
    local bStroke = Instance.new("UIStroke")
    bStroke.Color = Theme.AccentPink
    bStroke.Thickness = 1.2
    bStroke.Parent = box

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0, 120, 0, 14)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = MainFont
    nameLbl.Text = p.DisplayName
    nameLbl.TextColor3 = Theme.TextWhite
    nameLbl.TextSize = 11.5
    nameLbl.Visible = false
    nameLbl.ZIndex = 3
    nameLbl.Parent = holder

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(0, 60, 0, 14)
    distLbl.BackgroundTransparency = 1
    distLbl.Font = MainFont
    distLbl.Text = "0m"
    distLbl.TextColor3 = Theme.AccentPinkLight
    distLbl.TextSize = 10.5
    distLbl.Visible = false
    distLbl.ZIndex = 3
    distLbl.Parent = holder

    local healthBg = Instance.new("Frame")
    healthBg.Size = UDim2.new(0, 2, 1, 0)
    healthBg.Position = UDim2.new(0, -6, 0, 0)
    healthBg.BackgroundColor3 = Theme.ControlBg
    healthBg.BorderSizePixel = 0
    healthBg.Visible = false
    healthBg.ZIndex = 3
    healthBg.Parent = box

    local healthFill = Instance.new("Frame")
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.Position = UDim2.new(0, 0, 1, 0)
    healthFill.AnchorPoint = Vector2.new(0, 1)
    healthFill.BackgroundColor3 = Theme.AccentPink
    healthFill.BorderSizePixel = 0
    healthFill.ZIndex = 4
    healthFill.Parent = healthBg

    local headDot = Instance.new("Frame")
    headDot.Size = UDim2.new(0, 4, 0, 4)
    headDot.AnchorPoint = Vector2.new(0.5, 0.5)
    headDot.BackgroundColor3 = Theme.AccentPinkLight
    headDot.BorderSizePixel = 0
    headDot.Visible = false
    headDot.ZIndex = 5
    headDot.Parent = holder
    Instance.new("UICorner", headDot).CornerRadius = UDim.new(1, 0)

    local chamsHighlight = Instance.new("Highlight")
    chamsHighlight.Name = "OzionHubHighlight"
    chamsHighlight.FillColor = Theme.AccentPink
    chamsHighlight.FillTransparency = 0.6
    chamsHighlight.OutlineColor = Theme.AccentPinkLight
    chamsHighlight.OutlineTransparency = 0.1
    chamsHighlight.Enabled = false
    local weapLbl = Instance.new("TextLabel")
    weapLbl.Size = UDim2.new(0, 120, 0, 14)
    weapLbl.BackgroundTransparency = 1
    weapLbl.Font = MainFont
    weapLbl.Text = "Weapon"
    weapLbl.TextColor3 = Theme.AccentPinkLight
    weapLbl.TextSize = 10.5
    weapLbl.Visible = false
    weapLbl.ZIndex = 3
    weapLbl.Parent = holder

    local skeletonLines = {}
    for i = 1, #SKELETON_CONNECTIONS_R15 do
        table.insert(skeletonLines, createGuiLine(holder, 2))
    end

    local tracerLine = createGuiLine(holder, 2)

    espObjects[p] = {
        holder = holder,
        box = box,
        nameLbl = nameLbl,
        distLbl = distLbl,
        weapLbl = weapLbl,
        healthBg = healthBg,
        healthFill = healthFill,
        headDot = headDot,
        highlight = chamsHighlight,
        skeletonLines = skeletonLines,
        tracerLine = tracerLine,
        isShown = false
    }
end

local function hideESP(esp)
    if esp.isShown then
        esp.isShown = false
        esp.box.Visible = false
        esp.nameLbl.Visible = false
        esp.distLbl.Visible = false
        esp.headDot.Visible = false
        esp.healthBg.Visible = false
        if esp.weapLbl then esp.weapLbl.Visible = false end
        if esp.highlight then esp.highlight.Enabled = false end
        if esp.skeletonLines then
            for _, line in ipairs(esp.skeletonLines) do line.Visible = false end
        end
        if esp.tracerLine then esp.tracerLine.Visible = false end
    end
end

local playerWeaponCache = {}
local function getPlayerWeapon(pChar)
    if not pChar then return "Unarmed" end
    local now = tick()
    local cached = playerWeaponCache[pChar]
    if cached and (now - cached.time < 0.5) then
        return cached.name
    end

    local foundName = "Fighter"
    for _, child in ipairs(pChar:GetChildren()) do
        if child:IsA("Tool") then
            foundName = child.Name
            break
        end
    end
    if foundName == "Fighter" then
        local rHand = pChar:FindFirstChild("RightHand") or pChar:FindFirstChild("Right Arm")
        if rHand then
            for _, w in ipairs(rHand:GetChildren()) do
                if (w:IsA("Weld") or w:IsA("Motor6D")) and w.Part1 and w.Part1.Parent and w.Part1.Parent ~= pChar and w.Part1.Parent ~= Workspace then
                    foundName = w.Part1.Parent.Name
                    break
                end
            end
        end
    end

    playerWeaponCache[pChar] = { name = foundName, time = now }
    return foundName
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createESPForPlayer(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then createESPForPlayer(p) end
end)
Players.PlayerRemoving:Connect(function(p)
    if espObjects[p] then
        espObjects[p].holder:Destroy()
        espObjects[p] = nil
    end
end)

local isAimbotKeyDown = false
table.insert(activeConnections, UserInputService.InputBegan:Connect(function(input, gpe)
    -- menu toggle key is handled by Obsidian (Library.ToggleKeybind)
    if gpe then return end
    if input.UserInputType == Config.AimbotKey or input.KeyCode == Config.AimbotKey then
        isAimbotKeyDown = true
    elseif input.KeyCode == Config.SilentKey then
        if Config.SilentKeyMode == "Toggle" then
            Config.SilentAim = not Config.SilentAim
            ShowNotification("OzionHub", "Silent Aim: " .. (Config.SilentAim and "ON" or "OFF"), "INFO", 1.5)
        elseif Config.SilentKeyMode == "Hold" then
            isSilentKeyDown = true
        end
    end
end))

local lastInfJumpTime = 0
table.insert(activeConnections, UserInputService.JumpRequest:Connect(function()
    if isRunning and not mainWindow.Visible then
        if Config.InfiniteJump then
            local now = tick()
            if now - lastInfJumpTime >= 0.25 then
                lastInfJumpTime = now
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end
end))

table.insert(activeConnections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Config.AimbotKey or input.KeyCode == Config.AimbotKey then
        isAimbotKeyDown = false
    elseif input.KeyCode == Config.SilentKey then
        if Config.SilentKeyMode == "Hold" then
            isSilentKeyDown = false
        end
    end
end))

task.spawn(function()
    local navPath = PathfindingService:CreatePath({
        AgentRadius = 2.0,
        AgentHeight = 5.0,
        AgentCanJump = true,
        WaypointSpacing = 3.5
    })
    local groundRayParams = RaycastParams.new()
    groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
    groundRayParams.IgnoreWater = true

    while isRunning do
        task.wait(0.28)
        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        local actRoot = TargetVis.activeRoot
        if ((Config.TargetVisualizer and Config.TargetVisualizerPath) or Config.Autoplay) and r and actRoot then
            local rPos = r.Position
            local aPos = actRoot.Position
            if TargetVis.lastPathMyPos and TargetVis.lastPathActPos and #TargetVis.cachedWaypoints >= 2 then
                if (rPos - TargetVis.lastPathMyPos).Magnitude < 3.5 and (aPos - TargetVis.lastPathActPos).Magnitude < 3.5 then
                    continue
                end
            end
            TargetVis.lastPathMyPos = rPos
            TargetVis.lastPathActPos = aPos
            pcall(function()
                groundRayParams.FilterDescendantsInstances = {c, TargetVis.visualizerFolder}
                local success = pcall(function()
                    navPath:ComputeAsync(rPos, aPos)
                end)
                if success and navPath.Status == Enum.PathStatus.Success then
                    local rawWps = navPath:GetWaypoints()
                    local clamped = {}
                    for _, wp in ipairs(rawWps) do
                        local ray = Workspace:Raycast(wp.Position + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), groundRayParams)
                        local groundY = ray and (ray.Position.Y + 0.1) or (wp.Position.Y - 2.4)
                        table.insert(clamped, {
                            Position = Vector3.new(wp.Position.X, groundY, wp.Position.Z),
                            Action = wp.Action
                        })
                    end
                    if #clamped >= 2 then
                        TargetVis.cachedWaypoints = clamped
                        if TargetVis.autoplayWpIndex > #clamped then TargetVis.autoplayWpIndex = 1 end
                    end
                else
                    local rayL = Workspace:Raycast(r.Position + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), groundRayParams)
                    local rayT = Workspace:Raycast(actRoot.Position + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), groundRayParams)
                    local posL = rayL and (rayL.Position + Vector3.new(0, 0.1, 0)) or (r.Position - Vector3.new(0, 2.4, 0))
                    local posT = rayT and (rayT.Position + Vector3.new(0, 0.1, 0)) or (actRoot.Position - Vector3.new(0, 2.4, 0))
                    TargetVis.cachedWaypoints = {
                        { Position = posL, Action = Enum.PathWaypointAction.Custom },
                        { Position = posT, Action = Enum.PathWaypointAction.Custom }
                    }
                    TargetVis.autoplayWpIndex = 1
                end
            end)
        else
            if not actRoot then
                TargetVis.cachedWaypoints = {}
                TargetVis.autoplayWpIndex = 1
            end
        end
    end
end)

local flyBV, flyBG
local fpsFrameCount = 0
local lastFpsSampleTime = tick()
local liveFps = 60
local livePing = 0

table.insert(activeConnections, RunService.RenderStepped:Connect(function(dt)
    if not isRunning then return end

    if mainWindow.Visible then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        if frozenCameraCFrame then
            Camera.CFrame = frozenCameraCFrame
        else
            frozenCameraCFrame = Camera.CFrame
        end
        if frozenCameraFOV then
            Camera.FieldOfView = frozenCameraFOV
        else
            frozenCameraFOV = Camera.FieldOfView
        end

        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if r then
            r.AssemblyLinearVelocity = Vector3.new(0, math.min(r.AssemblyLinearVelocity.Y, 0), 0)
        end
    end

    fpsFrameCount = fpsFrameCount + 1
    local curTime = tick()
    if curTime - lastFpsSampleTime >= 0.25 then
        liveFps = math.floor(fpsFrameCount / (curTime - lastFpsSampleTime) + 0.5)
        fpsFrameCount = 0
        lastFpsSampleTime = curTime

        pcall(function()
            if LocalPlayer and LocalPlayer.GetNetworkPing then
                livePing = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
            else
                local stats = game:GetService("Stats")
                local net = stats and stats:FindFirstChild("Network")
                local sStats = net and net:FindFirstChild("ServerStatsItem")
                local pingItem = sStats and sStats:FindFirstChild("Data Ping")
                if pingItem then livePing = math.floor(pingItem:GetValue() + 0.5) end
            end
        end)

        if wmLbl and wmLbl.Parent then
            wmLbl.Text = '<b>O</b>  |  <font color="#e27898">ozionhub</font>  |  ' .. tostring(liveFps) .. ' fps  |  ' .. tostring(livePing) .. ' ms'
        end
        if sPing and sPing.Parent then
            sPing.Text = tostring(livePing) .. " ms - " .. tostring(#Players:GetPlayers()) .. " players"
        end
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local cam = Workspace.CurrentCamera

    if Config.ESP_FOV then
        fovCircleGui.Visible = true
        fovCircleGui.Size = UDim2.new(0, Config.SilentFOV * 2, 0, Config.SilentFOV * 2)
        -- fixed at the centre of the screen (no longer follows the mouse)
        fovCircleGui.Position = UDim2.new(0.5, -Config.SilentFOV, 0.5, -Config.SilentFOV)
    else
        fovCircleGui.Visible = false
    end

    if Config.SpeedHack and root and hum and not mainWindow.Visible then
        hum.WalkSpeed = tonumber(Config.SpeedValue) or 32
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0 then
            local baseSpeed = 16
            local targetSpeed = tonumber(Config.SpeedValue) or 32
            local extraSpeed = math.max(0, targetSpeed - baseSpeed)
            if extraSpeed > 0 then
                root.CFrame = root.CFrame + (moveDir.Unit * (extraSpeed * dt))
            end
        end
    end

    if Config.FlyHack and root and hum and cam then
        if not flyBV or flyBV.Parent ~= root then
            if flyBV then flyBV:Destroy() end
            flyBV = Instance.new("BodyVelocity")
            flyBV.Velocity = Vector3.zero
            flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flyBV.Parent = root
            table.insert(cleanUpInstances, flyBV)
        end
        if not flyBG or flyBG.Parent ~= root then
            if flyBG then flyBG:Destroy() end
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            flyBG.Parent = root
            table.insert(cleanUpInstances, flyBG)
        end

        local camCF = cam.CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

        flyBG.CFrame = camCF
        flyBV.Velocity = (dir.Magnitude > 0) and (dir.Unit * Config.FlySpeed) or Vector3.zero
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
    end

    if Config.Fullbright and (tick() - (TargetVis.lastFullbrightCheck or 0) >= 1) then
        TargetVis.lastFullbrightCheck = tick()
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    end
    if Config.NoFog and (tick() - (TargetVis.lastNoFogCheck or 0) >= 1) then
        TargetVis.lastNoFogCheck = tick()
        pcall(function()
            Lighting.FogEnd = 100000
            for _, eff in ipairs(Lighting:GetChildren()) do
                if eff:IsA("Atmosphere") then
                    eff.Density = 0
                elseif eff:IsA("PostEffect") then
                    if not eff.Name:find("Teleporting") then
                        eff.Enabled = false
                    end
                end
            end
        end)
    end

    if Config.CustomFOV and cam and not (Config.AimbotScopeOnly and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then
        cam.FieldOfView = tonumber(Config.FOVValue) or 90
    end

    if Config.BunnyHop and hum and root and not mainWindow.Visible then
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            if hum.FloorMaterial ~= Enum.Material.Air then
                local now = tick()
                if now - lastBhopJumpTime > 0.08 then
                    lastBhopJumpTime = now
                    hum.Jump = true
                end
            end
        end
    end

    if (Config.ThirdPerson or Config.Freecam) and cam then
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.LocalTransparencyModifier = 0
                end
            end
        end
    end

    if Config.ThirdPerson and root and hum and not Config.Freecam then
        local head = char:FindFirstChild("Head") or root
        local headPos = head.Position + Vector3.new(0, 0.5, 0)
        local targetDist = tonumber(Config.ThirdPersonDist) or 12
        local backDir = -cam.CFrame.LookVector * targetDist
        local hitParams = RaycastParams.new()
        hitParams.FilterDescendantsInstances = {char, cam}
        hitParams.FilterType = Enum.RaycastFilterType.Exclude
        local rayRes = Workspace:Raycast(headPos, backDir, hitParams)
        local camPos = rayRes and (rayRes.Position + rayRes.Normal * 0.4) or (headPos + backDir)
        cam.CFrame = CFrame.lookAt(camPos, headPos + cam.CFrame.LookVector * 100)
    end

    if Config.Freecam and cam then
        if not FreecamState.enabled then
            FreecamState.enabled = true
            local rx, ry = cam.CFrame:ToOrientation()
            FreecamState.rotX = rx
            FreecamState.rotY = ry
            FreecamState.pos = cam.CFrame.Position
        end
        if root then
            root.Anchored = true
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if not mainWindow.Visible then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            local delta = UserInputService:GetMouseDelta()
            if delta.Magnitude > 0 then
                FreecamState.rotY = FreecamState.rotY - math.rad(delta.X * 0.25)
                FreecamState.rotX = math.clamp(FreecamState.rotX - math.rad(delta.Y * 0.25), math.rad(-89), math.rad(89))
            end
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        local camRot = CFrame.Angles(0, FreecamState.rotY, 0) * CFrame.Angles(FreecamState.rotX, 0, 0)
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camRot.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camRot.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camRot.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camRot.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        if moveDir.Magnitude > 0 then
            FreecamState.pos = FreecamState.pos + (moveDir.Unit * (Config.FreecamSpeed or 40) * dt)
        end
        cam.CFrame = CFrame.new(FreecamState.pos) * camRot
    else
        if FreecamState.enabled then
            FreecamState.enabled = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            if root then
                root.Anchored = false
            end
        end
    end

    if Config.AntiAim and root then
        if Config.AntiAimMode == "Spin" then
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(math.min(Config.AntiAimSpeed, 35) * dt * 60), 0)
        elseif Config.AntiAimMode == "Jitter" then
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(math.random(-45, 45)), 0)
        elseif Config.AntiAimMode == "Backwards" then
            root.CFrame = CFrame.lookAt(root.Position, root.Position - cam.CFrame.LookVector)
        end
    end

    if Config.Aimbot and (Config.AimbotKeyMode == "Always" or isAimbotKeyDown) and not mainWindow.Visible then
        local isScoped = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or cam.FieldOfView < 70
        local isReloading = char and char:GetAttribute("Reloading")
        if (not Config.AimbotScopeOnly or isScoped) and (not Config.AimbotDisableReloading or not isReloading) then
            local checkVis = Config.AimbotVisibleOnly and not Config.TrackThroughWalls
            local target = getClosestTarget(Config.AimbotFOV, checkVis, Config.AimbotPart)
            if target and cam then
                local targetPos = target.Position
                if Config.InstantCameraLock then
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)
                else
                    local scrPos, onScreen = cam:WorldToViewportPoint(targetPos)
                    if onScreen and scrPos.Z > 0 then
                        local mPos = UserInputService:GetMouseLocation()
                        local deltaX = scrPos.X - mPos.X
                        local deltaY = scrPos.Y - mPos.Y
                        local smooth = math.clamp(tonumber(Config.AimbotSmoothing) or 0.28, 0.02, 1)
                        if mousemoverel then
                            mousemoverel(deltaX * smooth, deltaY * smooth)
                        elseif typeof(mouse_move) == "function" then
                            mouse_move(deltaX * smooth, deltaY * smooth)
                        else
                            local curCF = cam.CFrame
                            local goalCF = CFrame.lookAt(curCF.Position, targetPos)
                            cam.CFrame = curCF:Lerp(goalCF, math.clamp(smooth * 45 * dt, 0.05, 1))
                        end
                    else
                        local curCF = cam.CFrame
                        local goalCF = CFrame.lookAt(curCF.Position, targetPos)
                        cam.CFrame = curCF:Lerp(goalCF, math.clamp(Config.AimbotSmoothing * 45 * dt, 0.05, 1))
                    end
                end
            end
        end
    end

    local rageTarget = nil
    if Config.Ragebot and root and not mainWindow.Visible and hasWeaponEquipped() then
        rageTarget = getClosestTarget(1000, true, "Head", Config.RagebotTargetPriority)
    end
    local candidateTarget = rageTarget
    if not candidateTarget then
        if Config.TargetVisualizer or (not isInLobby() and hasWeaponEquipped()) then
            candidateTarget = getClosestTarget(1000, false, "Head", "Distance")
        end
    end
    if candidateTarget and candidateTarget.Parent then
        local tChar = candidateTarget.Parent
        local tHum = tChar:FindFirstChildOfClass("Humanoid")
        local tRoot = tChar:FindFirstChild("HumanoidRootPart")
        if tHum and tHum.Health > 0 and tRoot then
            TargetVis.activeChar = tChar
            TargetVis.activeHum = tHum
            TargetVis.activeRoot = tRoot
            TargetVis.activePlayer = Players:GetPlayerFromCharacter(tChar)
        else
            TargetVis.activeChar = nil
            TargetVis.activeHum = nil
            TargetVis.activeRoot = nil
            TargetVis.activePlayer = nil
        end
    else
        TargetVis.activeChar = nil
        TargetVis.activeHum = nil
        TargetVis.activeRoot = nil
        TargetVis.activePlayer = nil
    end

    if Config.TargetVisualizer and Config.TargetVisualizerHUD and TargetVis.activePlayer and TargetVis.activeHum and TargetVis.activeHum.Health > 0 then
        if TargetVis.hudTitle then
            TargetVis.hudTitle.Text = string.format("Target  -  %d/%d", math.floor(TargetVis.activeHum.Health), math.floor(TargetVis.activeHum.MaxHealth))
        end
        if TargetVis.lastTargetUserId ~= TargetVis.activePlayer.UserId then
            TargetVis.lastTargetUserId = TargetVis.activePlayer.UserId
            if TargetVis.hudAvatar then
                TargetVis.hudAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. TargetVis.activePlayer.UserId .. "&w=100&h=100"
            end
            if TargetVis.hudName then
                TargetVis.hudName.Text = TargetVis.activePlayer.DisplayName .. "  (@" .. TargetVis.activePlayer.Name .. ")"
            end
        end
        if TargetVis.hudHpFill then
            local hpPct = math.clamp(TargetVis.activeHum.Health / math.max(TargetVis.activeHum.MaxHealth, 1), 0, 1)
            TargetVis.hudHpFill.Size = UDim2.new(hpPct, 0, 1, 0)
        end
        if TargetVis.hudFrame then TargetVis.hudFrame.Visible = true end
    else
        if TargetVis.hudFrame then TargetVis.hudFrame.Visible = false end
    end

    if Config.TargetVisualizer and Config.TargetVisualizerPath and TargetVis.activeRoot and #TargetVis.cachedWaypoints >= 2 then
        local wps = TargetVis.cachedWaypoints
        local numSegments = #wps - 1
        local lineCount = math.min(numSegments, #TargetVis.poolLines)

        for i = 1, lineCount do
            local pA = wps[i].Position
            local pB = wps[i + 1].Position
            local diff = pB - pA
            local dist = diff.Magnitude
            local part = TargetVis.poolLines[i]
            if dist > 0.1 then
                part.Size = Vector3.new(0.18, 0.06, dist)
                part.CFrame = CFrame.lookAt((pA + pB) * 0.5, pB)
                part.Transparency = 0
            else
                part.Transparency = 1
            end
        end
        for i = lineCount + 1, #TargetVis.poolLines do
            TargetVis.poolLines[i].Transparency = 1
        end

        local segDists = {}
        local totalLength = 0
        for i = 1, numSegments do
            local d = (wps[i + 1].Position - wps[i].Position).Magnitude
            table.insert(segDists, d)
            totalLength = totalLength + d
        end

        local spacing = math.max(tonumber(Config.VisualizerArrowSpacing) or 10, 5)
        local speed = math.max(tonumber(Config.VisualizerArrowSpeed) or 14, 2)
        local travelOffset = (tick() * speed) % spacing
        local numChevrons = math.min(math.floor(totalLength / spacing) + 1, 16, #TargetVis.poolChevrons)

        local wingLen = 1.1
        local curSeg = 1
        local curAcc = 0
        for cIdx = 1, numChevrons do
            local distOnPath = (cIdx - 1) * spacing + travelOffset
            if distOnPath <= totalLength and distOnPath >= 0.5 then
                while curSeg < numSegments and (curAcc + segDists[curSeg]) < distOnPath do
                    curAcc = curAcc + segDists[curSeg]
                    curSeg = curSeg + 1
                end
                local segLen = segDists[curSeg] or 1
                local t = segLen > 0 and ((distOnPath - curAcc) / segLen) or 0
                local pos = wps[curSeg].Position:Lerp(wps[curSeg + 1].Position, math.clamp(t, 0, 1))
                local fwd = (wps[curSeg + 1].Position - wps[curSeg].Position).Unit

                local chev = TargetVis.poolChevrons[cIdx]
                local baseCF = CFrame.lookAt(pos, pos + fwd)
                chev.Left.CFrame = baseCF * CFrame.Angles(0, math.rad(-140), 0) * CFrame.new(0, 0, wingLen * 0.5)
                chev.Left.Size = Vector3.new(0.2, 0.08, wingLen)
                chev.Left.Transparency = 0

                chev.Right.CFrame = baseCF * CFrame.Angles(0, math.rad(140), 0) * CFrame.new(0, 0, wingLen * 0.5)
                chev.Right.Size = Vector3.new(0.2, 0.08, wingLen)
                chev.Right.Transparency = 0
            else
                TargetVis.poolChevrons[cIdx].Left.Transparency = 1
                TargetVis.poolChevrons[cIdx].Right.Transparency = 1
            end
        end
        for cIdx = numChevrons + 1, #TargetVis.poolChevrons do
            TargetVis.poolChevrons[cIdx].Left.Transparency = 1
            TargetVis.poolChevrons[cIdx].Right.Transparency = 1
        end
    else
        for _, p in ipairs(TargetVis.poolLines) do p.Transparency = 1 end
        for _, c in ipairs(TargetVis.poolChevrons) do
            c.Left.Transparency = 1
            c.Right.Transparency = 1
        end
    end

    if Config.Ragebot and root and not mainWindow.Visible and hasWeaponEquipped() then
        local target = rageTarget
        if target and target.Parent and cam then
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, target.Position)

            if Config.RagebotTargetStrafe and hum and root then
                isTargetStrafing = true
                local tPos = target.Position
                local currentAngle = tick() * (tonumber(Config.TargetStrafeSpeed) or 6)
                local rad = tonumber(Config.TargetStrafeRadius) or 14
                local goalWorldPos = Vector3.new(
                    tPos.X + math.cos(currentAngle) * rad,
                    root.Position.Y,
                    tPos.Z + math.sin(currentAngle) * rad
                )
                local moveOffset = goalWorldPos - root.Position
                local moveDir = Vector3.new(moveOffset.X, 0, moveOffset.Z)
                if moveDir.Magnitude > 0.5 then
                    hum:Move(moveDir.Unit, false)
                else
                    hum:Move(Vector3.zero, false)
                end
            elseif isTargetStrafing and hum and not Config.Autoplay then
                isTargetStrafing = false
                hum:Move(Vector3.zero, false)
            end

            if Config.RagebotAutoShoot then
                local now = tick()
                if now - lastRageAutoShootTime >= 0.12 then
                    lastRageAutoShootTime = now
                    clickWeapon()
                end
            end
        else
            if isTargetStrafing and hum and not Config.Autoplay then
                isTargetStrafing = false
                hum:Move(Vector3.zero, false)
            end
        end
    else
        if isTargetStrafing and hum and not Config.Autoplay then
            isTargetStrafing = false
            hum:Move(Vector3.zero, false)
        end
    end

    if Config.Autoplay and root and hum and not mainWindow.Visible and hasWeaponEquipped() then
        if TargetVis.activeRoot and TargetVis.activeHum and TargetVis.activeHum.Health > 0 then
            if cam then
                local enemyHead = TargetVis.activeChar and (TargetVis.activeChar:FindFirstChild("Head") or TargetVis.activeChar:FindFirstChild("HitboxHead"))
                local aimPoint = enemyHead and enemyHead.Position or (TargetVis.activeRoot.Position + Vector3.new(0, 1.5, 0))
                cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimPoint)

                if Config.RagebotAutoShoot then
                    local dir = aimPoint - cam.CFrame.Position
                    local res = Workspace:Raycast(cam.CFrame.Position, dir, TargetVis.staticRayParams)
                    if not res or (TargetVis.activeChar and res.Instance:IsDescendantOf(TargetVis.activeChar)) then
                        local now = tick()
                        if now - lastRageAutoShootTime >= 0.12 then
                            lastRageAutoShootTime = now
                            pcall(function()
                                if mouse1click then
                                    mouse1click()
                                elseif mouse1press and mouse1release then
                                    mouse1press()
                                    task.wait(0.01)
                                    mouse1release()
                                end
                            end)
                        end
                    end
                end
            end

            local tDist = (TargetVis.activeRoot.Position - root.Position).Magnitude
            local stopDist = tonumber(Config.AutoplayDistance) or 18

            if TargetVis.cachedWaypoints and #TargetVis.cachedWaypoints >= 2 then
                local curWp = TargetVis.cachedWaypoints[TargetVis.autoplayWpIndex]
                if curWp then
                    local wpDist = (Vector3.new(curWp.Position.X, root.Position.Y, curWp.Position.Z) - root.Position).Magnitude
                    if wpDist < 4.5 and TargetVis.autoplayWpIndex < #TargetVis.cachedWaypoints then
                        TargetVis.autoplayWpIndex = TargetVis.autoplayWpIndex + 1
                        curWp = TargetVis.cachedWaypoints[TargetVis.autoplayWpIndex]
                    end
                end

                if tDist > stopDist and curWp then
                    local moveVec = Vector3.new(curWp.Position.X - root.Position.X, 0, curWp.Position.Z - root.Position.Z)
                    if moveVec.Magnitude > 0.5 then
                        hum:Move(moveVec.Unit, false)
                    end

                    if curWp.Action == Enum.PathWaypointAction.Jump then
                        hum.Jump = true
                    end

                    if TargetVis.lastAutoplayPos and (root.Position - TargetVis.lastAutoplayPos).Magnitude < 0.6 then
                        TargetVis.lastAutoplayStuckTime = TargetVis.lastAutoplayStuckTime + dt
                        if TargetVis.lastAutoplayStuckTime > 0.35 then
                            hum.Jump = true
                            TargetVis.lastAutoplayStuckTime = 0
                        end
                    else
                        TargetVis.lastAutoplayStuckTime = 0
                    end
                    TargetVis.lastAutoplayPos = root.Position
                else
                    if not Config.RagebotTargetStrafe then
                        hum:Move(Vector3.zero, false)
                    end
                end
            else
                local toEnemy = Vector3.new(TargetVis.activeRoot.Position.X - root.Position.X, 0, TargetVis.activeRoot.Position.Z - root.Position.Z)
                if toEnemy.Magnitude > stopDist then
                    hum:Move(toEnemy.Unit, false)
                else
                    if not Config.RagebotTargetStrafe then
                        hum:Move(Vector3.zero, false)
                    end
                end
            end
        else
            if not Config.RagebotTargetStrafe then
                hum:Move(Vector3.zero, false)
            end
        end
    end

    if Config.AutomaticGuns and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not mainWindow.Visible and hasWeaponEquipped() then
        local now = tick()
        if now - lastAutoShootTime >= 0.08 then
            lastAutoShootTime = now
            clickWeapon()
        end
    end

    local vmFolder = Workspace:FindFirstChild("ViewModels") or cam
    if vmFolder and (Config.RainbowGunSkin or Config.HideViewModel or Config.WeaponChams or Config.CustomViewModelFOV or Config.ViewModelXOffset ~= 0 or Config.ViewModelYOffset ~= 0 or Config.ViewModelZOffset ~= 0) then
        local fpModel = vmFolder:FindFirstChild("FirstPerson") or vmFolder
        local hue = (tick() * 0.4) % 1
        local rainbowColor = Color3.fromHSV(hue, 0.8, 1)

        for _, part in ipairs(fpModel:GetDescendants()) do
            if part:IsA("BasePart") then
                if Config.HideViewModel then
                    part.Transparency = 1
                else
                    if Config.RainbowGunSkin and part.Transparency < 1 then
                        part.Color = rainbowColor
                    end
                    if Config.WeaponChams and part.Transparency < 1 then
                        part.Material = Enum.Material.Neon
                        part.Color = Theme.AccentPink
                    end
                end
            end
        end
    end

    pcall(function()
        if not Config.ESP_Master then
            for _, esp in pairs(espObjects) do
                hideESP(esp)
            end
            return
        end

        local camCF = Camera.CFrame
        local camPos = camCF.Position
        local camLook = camCF.LookVector
        local maxDist = tonumber(Config.ESP_MaxDistance) or 500
        if isInLobby() then maxDist = math.min(maxDist, 160) end
        local visibleSkeletonsCount = 0
        local maxSkeletons = isInLobby() and 2 or 4
        local maxSkeletonDist = isInLobby() and 60 or 120

        for p, esp in pairs(espObjects) do
            local pChar = p.Character
            local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")
            local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
            local pHead = pChar and (pChar:FindFirstChild("Head") or pChar:FindFirstChild("HitboxHead") or pChar:FindFirstChild("HitboxHeadSmall"))

            if isEnemyPlayer(p) and pChar and pHum and pRoot and pHead and pHum.Health > 0 then
                local toRoot = pRoot.Position - camPos
                local distStuds = toRoot.Magnitude
                local inFront = toRoot:Dot(camLook) > 0

                if (not inFront) or (distStuds > maxDist) then
                    hideESP(esp)
                else
                    local top3D = pHead.Position + Vector3.new(0, 0.8, 0)
                    local bot3D = pRoot.Position - Vector3.new(0, 2.85, 0)

                    local top2D, tOn = Camera:WorldToViewportPoint(top3D)
                    local bot2D, bOn = Camera:WorldToViewportPoint(bot3D)
                    local head2D, hOn = Camera:WorldToViewportPoint(pHead.Position)
                    local root2D = Camera:WorldToViewportPoint(pRoot.Position)

                    if tOn and bOn and top2D.Z > 0 and bot2D.Z > 0 then
                        esp.isShown = true

                        local boxHeight = math.abs(bot2D.Y - top2D.Y)
                        local boxWidth = boxHeight * 0.65
                        local boxTopY = top2D.Y
                        local boxLeftX = root2D.X - (boxWidth / 2)

                        if Config.ESP_Boxes then
                            esp.box.Visible = true
                            esp.box.Size = UDim2.new(0, boxWidth, 0, boxHeight)
                            esp.box.Position = UDim2.new(0, boxLeftX, 0, boxTopY)
                        else
                            esp.box.Visible = false
                        end

                        if Config.ESP_Names then
                            esp.nameLbl.Visible = true
                            esp.nameLbl.Position = UDim2.new(0, root2D.X - 60, 0, boxTopY - 16)
                            esp.nameLbl.Size = UDim2.new(0, 120, 0, 14)
                        else
                            esp.nameLbl.Visible = false
                        end

                        if Config.ESP_Distance then
                            local dist = math.floor(distStuds * 0.28)
                            esp.distLbl.Visible = true
                            esp.distLbl.Text = tostring(dist) .. "m"
                            esp.distLbl.Position = UDim2.new(0, root2D.X - 30, 0, bot2D.Y + 2)
                            esp.distLbl.Size = UDim2.new(0, 60, 0, 14)
                        else
                            esp.distLbl.Visible = false
                        end

                        if Config.ESP_Weapon and esp.weapLbl then
                            esp.weapLbl.Visible = true
                            esp.weapLbl.Text = getPlayerWeapon(pChar)
                            esp.weapLbl.Position = UDim2.new(0, root2D.X - 60, 0, (Config.ESP_Distance and (bot2D.Y + 16) or (bot2D.Y + 2)))
                        elseif esp.weapLbl then
                            esp.weapLbl.Visible = false
                        end

                        if Config.ESP_HealthBar then
                            esp.healthBg.Visible = true
                            local hpPct = math.clamp(pHum.Health / pHum.MaxHealth, 0, 1)
                            esp.healthFill.Size = UDim2.new(1, 0, hpPct, 0)
                        else
                            esp.healthBg.Visible = false
                        end

                        if Config.ESP_HeadDot and hOn and head2D.Z > 0 then
                            esp.headDot.Visible = true
                            esp.headDot.Position = UDim2.new(0, head2D.X, 0, head2D.Y)
                        else
                            esp.headDot.Visible = false
                        end

                        if Config.ESP_Chams then
                            esp.highlight.Enabled = true
                            esp.highlight.Adornee = pChar
                        else
                            esp.highlight.Enabled = false
                        end
                    else
                        hideESP(esp)
                    end

                    if Config.ESP_Skeleton and esp.skeletonLines and distStuds <= maxSkeletonDist and tOn and bOn and visibleSkeletonsCount < maxSkeletons then
                        visibleSkeletonsCount = visibleSkeletonsCount + 1
                        local isR15 = pChar:FindFirstChild("UpperTorso") ~= nil
                        local connections = isR15 and SKELETON_CONNECTIONS_R15 or SKELETON_CONNECTIONS_R6
                        for i, bonePair in ipairs(connections) do
                            local line = esp.skeletonLines[i]
                            local partA = pChar:FindFirstChild(bonePair[1])
                            local partB = pChar:FindFirstChild(bonePair[2])
                            if partA and partB and line then
                                local posA, onA = Camera:WorldToViewportPoint(partA.Position)
                                local posB, onB = Camera:WorldToViewportPoint(partB.Position)
                                if (onA or onB) and posA.Z > 0 and posB.Z > 0 then
                                    updateGuiLine(line, Vector2.new(posA.X, posA.Y), Vector2.new(posB.X, posB.Y), 1.2, Theme.AccentPinkLight)
                                else
                                    line.Visible = false
                                end
                            elseif line then
                                line.Visible = false
                            end
                        end
                        for i = #connections + 1, #esp.skeletonLines do
                            if esp.skeletonLines[i] then esp.skeletonLines[i].Visible = false end
                        end
                    elseif esp.skeletonLines then
                        for _, line in ipairs(esp.skeletonLines) do line.Visible = false end
                    end

                    if Config.ESP_Tracers and esp.tracerLine and distStuds <= 350 and bot2D and bot2D.Z > 0 and bOn then
                        local vpSize = Camera.ViewportSize
                        local origin2D = Vector2.new(vpSize.X * 0.5, vpSize.Y)
                        local target2D = Vector2.new(root2D.X, bot2D.Y)
                        updateGuiLine(esp.tracerLine, origin2D, target2D, 1.2, Theme.AccentPink)
                    elseif esp.tracerLine then
                        esp.tracerLine.Visible = false
                    end
                end
            else
                hideESP(esp)
            end
        end
    end)
end))

table.insert(activeConnections, RunService.Stepped:Connect(function()
    if not isRunning then return end
    local char = LocalPlayer.Character
    if Config.Noclip and char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end))


task.spawn(function()
    local hackerDetectionTimestamps = {}
    local hackerNotifiedTimestamps = {}
    local modNotifiedCache = {}

    ApplyWeaponModifications()
    while isRunning do
        pcall(function()
            local rem = ReplicatedStorage:FindFirstChild("Remotes")
            local duels = rem and rem:FindFirstChild("Duels")
            local matchmaking = rem and rem:FindFirstChild("Matchmaking")

            if Config.AutoRespawn and duels and duels:FindFirstChild("RespawnNow") then
                duels.RespawnNow:FireServer()
            end

            if Config.AutoQueue and matchmaking and matchmaking:FindFirstChild("JoinQueue") then
                local targetQueue = Config.QueueMode or "1v1"
                task.spawn(function()
                    pcall(function()
                        matchmaking.JoinQueue:InvokeServer(targetQueue)
                    end)
                end)
            end

            if (Config.AutoVoteMaps or Config.AutoBanWeapons) then
                if duels and duels:FindFirstChild("Vote") then
                    if Config.AutoVoteMaps then
                        local topMap = string.split(Config.MapPriority or "Arena", ",")[1]:match("^%s*(.-)%s*$")
                        pcall(function() duels.Vote:FireServer("Map", topMap or "Arena") end)
                        pcall(function() duels.Vote:FireServer(topMap or "Arena") end)
                    end
                    if Config.AutoBanWeapons then
                        local topBan = string.split(Config.WeaponBanPriority or "Grenade Launcher", ",")[1]:match("^%s*(.-)%s*$")
                        pcall(function() duels.Vote:FireServer("Weapon", topBan or "Grenade Launcher") end)
                        pcall(function() duels.Vote:FireServer(topBan or "Grenade Launcher") end)
                    end
                end

                pcall(function()
                    local pages = LocalPlayer.PlayerScripts:FindFirstChild("Modules") and LocalPlayer.PlayerScripts.Modules:FindFirstChild("Pages")
                    local pwMod = pages and pages:FindFirstChild("PickWeapons")
                    if pwMod then
                        local pw = require(pwMod)
                        if pw and pw._is_open then
                            if Config.AutoVoteMaps and pw.MapFrame then
                                for _, d in ipairs(pw.MapFrame:GetDescendants()) do
                                    if (d:IsA("TextButton") or d:IsA("ImageButton")) and getconnections then
                                        for _, c in ipairs(getconnections(d.MouseButton1Click) or {}) do c:Fire() end
                                    end
                                end
                            end
                            if Config.AutoBanWeapons and pw._ban_frames then
                                for _, frame in pairs(pw._ban_frames) do
                                    if typeof(frame) == "Instance" then
                                        for _, btn in ipairs(frame:GetDescendants()) do
                                            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and getconnections then
                                                for _, c in ipairs(getconnections(btn.MouseButton1Click) or {}) do c:Fire() end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end

            if Config.AutoLoadout and duels and duels:FindFirstChild("PickWeaponsAheadOfTime") then
                duels.PickWeaponsAheadOfTime:FireServer()
            end

            if Config.HackerDetector then
                local threshold = tonumber(Config.SpeedThreshold) or 180
                local duration = tonumber(Config.SpeedDuration) or 0.75
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
                        if pRoot then
                            local vel = pRoot.AssemblyLinearVelocity.Magnitude
                            if vel > threshold then
                                if not hackerDetectionTimestamps[p] then
                                    hackerDetectionTimestamps[p] = tick()
                                elseif tick() - hackerDetectionTimestamps[p] >= duration then
                                    if not hackerNotifiedTimestamps[p] or tick() - hackerNotifiedTimestamps[p] > 12 then
                                        hackerNotifiedTimestamps[p] = tick()
                                        if Config.NotifyHackers then
                                            ShowNotification("OzionHub", "Hacker Flag: " .. p.DisplayName .. " (" .. math.floor(vel) .. " studs/s)", "WARN", 3.5)
                                        end
                                        if Config.HackerAutoLoad and Config.HackerProfile and Config.HackerProfile ~= "" then
                                            local targetProfile = Config.HackerProfile:match("^%s*(.-)%s*$")
                                            if ProfileSystem and ProfileSystem.current ~= targetProfile then
                                                local loaded = ProfileSystem.applyProfile(targetProfile, false)
                                                if loaded then
                                                    ShowNotification("OzionHub", "Hacker detected! Loaded profile: " .. targetProfile, "SUCCESS", 3.5)
                                                end
                                            end
                                        end
                                    end
                                end
                            else
                                hackerDetectionTimestamps[p] = nil
                            end
                        end
                    end
                end
            end

            if Config.ModDetector then
                local minRank = tonumber(Config.MinGroupRank) or 200
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and not modNotifiedCache[p] then
                        local isMod = false
                        local rank = p:GetAttribute("GroupRank")
                        if not rank then
                            pcall(function() rank = p:GetRankInGroup(game.CreatorId > 0 and game.CreatorId or 16124806) end)
                        end
                        if rank and rank >= minRank then
                            isMod = true
                        end
                        if not isMod and Config.ModUsernames and Config.ModUsernames ~= "" then
                            for uName in Config.ModUsernames:gmatch("[^,%s]+") do
                                if p.Name:lower() == uName:lower() or p.DisplayName:lower() == uName:lower() then
                                    isMod = true
                                    break
                                end
                            end
                        end
                        if isMod then
                            modNotifiedCache[p] = true
                            if Config.NotifyMods then
                                ShowNotification("OzionHub", "STAFF / MOD DETECTED: " .. p.DisplayName .. " (Rank: " .. tostring(rank or "Staff") .. ")", "ERROR", 5)
                            end
                        end
                    end
                end
            end

            if Config.AutoPickup then
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    for _, obj in ipairs(Workspace:GetChildren()) do
                        if obj.Name:find("Drop") or obj.Name:find("Tripmine") or obj.Name:find("Ammo") then
                            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                            if part and (part.Position - root.Position).Magnitude <= Config.PickupRadius then
                                if firetouchinterest then
                                    firetouchinterest(root, part, false)
                                    firetouchinterest(root, part, true)
                                end
                            end
                        end
                    end
                end
            end
        end)
        task.wait(1)
    end
end)

setMenuVisible(true)
ShowNotification("OzionHub", "Loaded OzionHub successfully.", "SUCCESS", 4)
