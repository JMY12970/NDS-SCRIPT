--[[
    PWT Panel  |  Obsidian UI  |  Single LocalScript  |  Built for Delta
    Target game: Pet Store Tycoon (already arrived studios)  PlaceId 118845698633260
    Press RightShift (or the floating "UI" button on mobile) to hide/show.

    NOTE: Game-specific remotes are unknown (the uploaded zip contained only
    empty stubs), so Auto Buy / Auto Collect / Auto Claim work by scanning the
    game's own ProximityPrompts, ClickDetectors, touch parts and GUI buttons
    using keywords you can edit live in the UI.
]]

if getgenv and getgenv().PWT_PANEL_LOADED then
    pcall(function() getgenv().PWT_PANEL_UNLOAD() end)
end

----------------------------------------------------------------------
-- Services / helpers
----------------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local VirtualUser       = game:GetService("VirtualUser")
local SoundService      = game:GetService("SoundService")
local StarterGui        = game:GetService("StarterGui")
local CoreGui           = game:GetService("CoreGui")
local Stats             = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local env = (getgenv and getgenv()) or _G

local function safe(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local function getChar()  return LocalPlayer.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local c = getChar()
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
end

-- executor function fallbacks (all optional)
local fireprompt  = fireproximityprompt
local firetouch   = firetouchinterest
local fireclick   = fireclickdetector
local fireSig     = firesignal
local getConns    = getconnections
local queueTP     = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
local setClip     = setclipboard or toclipboard or (Clipboard and Clipboard.set)
local httpReq     = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- Game config -------------------------------------------------------
local TARGET_PLACE_ID = 118845698633260   -- Pet Store Tycoon (already arrived studios)
local LOCK_TO_GAME    = false             -- set to true to refuse to run in any other game
if LOCK_TO_GAME and game.PlaceId ~= TARGET_PLACE_ID then
    warn("[PWT Panel] Wrong game (PlaceId " .. tostring(game.PlaceId) .. "). Locked to " .. TARGET_PLACE_ID)
    return
end
-----------------------------------------------------------------------

local Connections = {}   -- every connection we make, for clean Unload
local function track(c) Connections[#Connections + 1] = c; return c end

----------------------------------------------------------------------
-- Load Obsidian
----------------------------------------------------------------------
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
    Title  = "PWT Panel | Pet Store Tycoon",
    Footer = "Obsidian | Delta | 1 script",
    Center = true,
    AutoShow = true,
    ToggleKeybind = Enum.KeyCode.RightShift,
    NotifyOnError = true,
})

local Tabs = {
    Auto     = Window:AddTab("Auto",     "bot"),
    Player   = Window:AddTab("Player",   "user"),
    Visuals  = Window:AddTab("Visuals",  "eye"),
    World    = Window:AddTab("Teleport", "map-pin"),
    Server   = Window:AddTab("Server",   "server"),
    Settings = Window:AddTab("UI Settings", "settings"),
}

local function notify(text, t)
    if Toggles.NotifyEnabled and Toggles.NotifyEnabled.Value == false then return end
    Library:Notify(text, t or 3)
end

----------------------------------------------------------------------
-- Shared scanning utilities (used by Auto Buy / Collect / Claim)
----------------------------------------------------------------------
local function splitKeywords(str)
    local list = {}
    for word in tostring(str or ""):gmatch("[^,]+") do
        word = word:lower():gsub("^%s+", ""):gsub("%s+$", "")
        if #word > 0 then list[#list + 1] = word end
    end
    return list
end

local function matchesAny(text, words)
    text = tostring(text or ""):lower()
    if text == "" then return false end
    for _, w in ipairs(words) do
        if text:find(w, 1, true) then return true end
    end
    return false
end

-- never auto-trigger real-money purchases
local BLOCKED_WORDS = { "robux", "r$", "premium", "gamepass", "game pass", "gift", "vip", "donate", "developer product" }

local function isBlocked(text)
    return matchesAny(text, BLOCKED_WORDS)
end

local function promptPart(prompt)
    local p = prompt.Parent
    if p and p:IsA("BasePart") then return p end
    if p and p:IsA("Attachment") then return p.Parent end
    if p and p:IsA("Model") then return p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true) end
    return p and p:FindFirstChildWhichIsA("BasePart", true)
end

local function distTo(part)
    local root = getRoot()
    if not root or not part then return math.huge end
    return (root.Position - part.Position).Magnitude
end

local function firePrompt(prompt)
    if fireprompt then
        pcall(fireprompt, prompt)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.05)
            prompt:InputHoldEnd()
        end)
    end
end

local function pressGuiButton(btn)
    -- try the executor route first, then fall back to the Activated/MouseButton1Click connections
    local done = false
    if getConns then
        for _, sigName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" }) do
            local ok, conns = pcall(getConns, btn[sigName])
            if ok and conns then
                for _, c in ipairs(conns) do
                    pcall(function() c:Fire() end)
                    done = true
                end
            end
        end
    end
    if not done and fireSig then
        pcall(fireSig, btn.Activated)
        pcall(fireSig, btn.MouseButton1Click)
    end
end

local function guiText(obj)
    local t = ""
    if obj:IsA("TextButton") then t = obj.Text end
    if t == "" then
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" then t = t .. " " .. d.Text end
        end
    end
    return t
end

local function guiVisible(obj)
    local cur = obj
    while cur and cur:IsA("GuiObject") do
        if not cur.Visible then return false end
        cur = cur.Parent
    end
    return true
end

local function scanButtons(words, excludeBlocked)
    local found = {}
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return found end
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextButton") or d:IsA("ImageButton")) and guiVisible(d) then
            local txt = guiText(d)
            if matchesAny(txt, words) and not (excludeBlocked and isBlocked(txt)) then
                found[#found + 1] = d
            end
        end
    end
    return found
end

-- Cache of interactable instances (keeps the auto loops light on big maps)
local Cache = { prompts = {}, clicks = {}, touch = {} }
local function indexInstance(d)
    if d:IsA("ProximityPrompt") then
        Cache.prompts[d] = true
    elseif d:IsA("ClickDetector") then
        Cache.clicks[d] = true
    elseif d:IsA("TouchTransmitter") then
        local p = d.Parent
        if p and p:IsA("BasePart") then Cache.touch[p] = true end
    end
end
task.spawn(function()
    local n = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        indexInstance(d)
        n = n + 1
        if n % 500 == 0 then task.wait() end
    end
end)
track(Workspace.DescendantAdded:Connect(indexInstance))
track(Workspace.DescendantRemoving:Connect(function(d)
    Cache.prompts[d] = nil
    Cache.clicks[d] = nil
    Cache.touch[d] = nil
    if d:IsA("TouchTransmitter") and d.Parent then Cache.touch[d.Parent] = nil end
end))

----------------------------------------------------------------------
-- TAB: AUTO
----------------------------------------------------------------------
local AutoBuy     = Tabs.Auto:AddLeftGroupbox("Auto Buy", "shopping-cart")
local AutoCollect = Tabs.Auto:AddLeftGroupbox("Auto Collect / Claim", "coins")
local AutoMisc    = Tabs.Auto:AddRightGroupbox("Auto Utilities", "wrench")
local AutoSrv     = Tabs.Auto:AddRightGroupbox("Auto Server", "refresh-cw")

-- Auto Buy
AutoBuy:AddToggle("AutoBuyPrompt", {
    Text = "Auto Buy (prompts)",
    Tooltip = "Fires nearby ProximityPrompts whose text matches the buy keywords. Skips Robux/Premium/Gift items.",
    Default = false,
})
AutoBuy:AddToggle("AutoBuyGui", {
    Text = "Auto Buy (GUI buttons)",
    Tooltip = "Presses visible shop/restock buttons that match the buy keywords. Skips Robux/Premium/Gift items.",
    Default = false,
})
AutoBuy:AddToggle("AutoBuyTP", {
    Text = "Teleport to buy prompts",
    Tooltip = "If a matching prompt is out of range, teleports next to it first.",
    Default = false,
})
AutoBuy:AddInput("BuyKeywords", {
    Text = "Buy keywords",
    Default = "buy,purchase,order,restock,unlock,upgrade,hire,expand,adopt,open",
    Placeholder = "comma,separated,words",
    Finished = true,
})
AutoBuy:AddSlider("BuyDelay", { Text = "Buy delay (s)", Default = 0.6, Min = 0.1, Max = 5, Rounding = 1 })
AutoBuy:AddSlider("BuyRange", { Text = "Prompt range", Default = 15, Min = 5, Max = 80, Rounding = 0, Suffix = " st" })

-- Auto Collect / Claim
AutoCollect:AddToggle("AutoCollectCash", {
    Text = "Auto Collect Cash",
    Tooltip = "Touches parts whose name matches the collect keywords.",
    Default = false,
})
AutoCollect:AddToggle("AutoClaimGui", {
    Text = "Auto Claim Rewards (GUI)",
    Tooltip = "Presses visible Claim/Collect/Redeem buttons.",
    Default = false,
})
AutoCollect:AddToggle("AutoInteract", {
    Text = "Auto Interact (all prompts)",
    Tooltip = "Fires every prompt in range EXCEPT blocked (Robux/Premium/Gift).",
    Default = false,
})
AutoCollect:AddToggle("AutoClickDetect", {
    Text = "Auto Click (ClickDetectors)",
    Default = false,
})
AutoCollect:AddToggle("AutoPickup", {
    Text = "Auto Pickup Drops",
    Tooltip = "Touches parts named like drop/pickup/crate/loot.",
    Default = false,
})
AutoCollect:AddInput("CollectKeywords", {
    Text = "Collect part keywords",
    Default = "cash,coin,money,collect,income,till,tip",
    Finished = true,
})
AutoCollect:AddInput("ClaimKeywords", {
    Text = "Claim button keywords",
    Default = "claim,collect,redeem,free,reward,daily,check-in,checkin",
    Finished = true,
})
AutoCollect:AddSlider("CollectDelay", { Text = "Collect delay (s)", Default = 0.5, Min = 0.1, Max = 5, Rounding = 1 })

-- Auto utilities
AutoMisc:AddToggle("AntiAFK",      { Text = "Anti-AFK", Default = true })
AutoMisc:AddToggle("AutoRespawn",  { Text = "Auto Respawn", Tooltip = "Teleports you back to where you died.", Default = false })
AutoMisc:AddToggle("AutoEquip",    { Text = "Auto Equip Tool", Default = false })
AutoMisc:AddToggle("AutoJump",     { Text = "Auto Jump", Default = false })
AutoMisc:AddToggle("AutoRejoin",   { Text = "Auto Rejoin on kick", Default = false })
AutoMisc:AddToggle("AutoReexec",   { Text = "Re-run script after teleport", Tooltip = "Needs queue_on_teleport support.", Default = false })
AutoMisc:AddInput("ReexecURL",     { Text = "Script URL (re-run)", Default = "", Placeholder = "https://.../script.lua", Finished = true })

-- Auto Server
AutoSrv:AddToggle("AutoServerHop", {
    Text = "Auto Server Hop",
    Tooltip = "Hops to a different public server on a timer.",
    Default = false,
})
AutoSrv:AddSlider("HopInterval", { Text = "Hop every (min)", Default = 10, Min = 1, Max = 60, Rounding = 0 })
AutoSrv:AddDropdown("HopMode", {
    Text = "Hop target",
    Values = { "Random", "Fewest players", "Most players (not full)" },
    Default = 2,
})

-- Store Helper (tuned for Pet Store Tycoon: shelves, checkout, pet care)
local StoreBox = Tabs.Auto:AddRightGroupbox("Store Helper", "store")
StoreBox:AddToggle("AutoStoreTasks", {
    Text = "Auto Store Tasks",
    Tooltip = "Fires nearby prompts for stocking, checkout, feeding, cleaning and play. Blocked: Robux/Premium/Gift.",
    Default = false,
})
StoreBox:AddToggle("StoreTasksTP", {
    Text = "Walk to tasks (teleport)",
    Tooltip = "Teleports next to the closest matching prompt if none is in range.",
    Default = false,
})
StoreBox:AddInput("StoreKeywords", {
    Text = "Task keywords",
    Default = "stock,restock,shelf,checkout,serve,scan,ring,cashier,feed,clean,wash,water,play,groom,pet,trash,sweep,refill",
    Finished = true,
})
StoreBox:AddSlider("StoreDelay", { Text = "Task delay (s)", Default = 0.4, Min = 0.1, Max = 3, Rounding = 1 })
StoreBox:AddDivider()
StoreBox:AddButton({
    Text = "Scan prompt texts (copy)",
    Tooltip = "Lists the unique prompt texts within 80 studs and copies them. Use it to tune the keywords.",
    Func = function()
        local seen, list = {}, {}
        for d in pairs(Cache.prompts) do
            if d.Parent then
                local part = promptPart(d)
                if part and distTo(part) <= 80 then
                    local a = (d.ActionText ~= "" and d.ActionText) or "?"
                    local o = (d.ObjectText ~= "" and d.ObjectText) or "?"
                    local key = a .. " | " .. o .. " | " .. d.Name
                    if not seen[key] then seen[key] = true; list[#list + 1] = key end
                end
            end
        end
        table.sort(list)
        local out = table.concat(list, "\n")
        if setClip then pcall(setClip, out) end
        print("[PWT Panel] prompts nearby:\n" .. out)
        notify(("%d prompt types found%s"):format(#list, setClip and " (copied)" or " (see console)"), 4)
    end,
})
StoreBox:AddButton({
    Text = "Scan button texts (copy)",
    Tooltip = "Lists visible GUI button texts and copies them.",
    Func = function()
        local seen, list = {}, {}
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, d in ipairs(pg:GetDescendants()) do
                if (d:IsA("TextButton") or d:IsA("ImageButton")) and guiVisible(d) then
                    local t = guiText(d):gsub("%s+", " ")
                    if t ~= "" and t ~= " " and not seen[t] then seen[t] = true; list[#list + 1] = t end
                end
            end
        end
        table.sort(list)
        local out = table.concat(list, "\n")
        if setClip then pcall(setClip, out) end
        print("[PWT Panel] buttons visible:\n" .. out)
        notify(("%d button texts found%s"):format(#list, setClip and " (copied)" or " (see console)"), 4)
    end,
})

----------------------------------------------------------------------
-- TAB: PLAYER
----------------------------------------------------------------------
local PMove  = Tabs.Player:AddLeftGroupbox("Movement", "footprints")
local PFly   = Tabs.Player:AddLeftGroupbox("Fly", "plane")
local PMisc  = Tabs.Player:AddRightGroupbox("Character", "person-standing")
local PCam   = Tabs.Player:AddRightGroupbox("Camera", "camera")

PMove:AddToggle("WalkSpeedOn", { Text = "WalkSpeed", Default = false })
PMove:AddSlider("WalkSpeed",   { Text = "Speed", Default = 32, Min = 16, Max = 200, Rounding = 0 })
PMove:AddToggle("JumpPowerOn", { Text = "JumpPower", Default = false })
PMove:AddSlider("JumpPower",   { Text = "Power", Default = 80, Min = 50, Max = 300, Rounding = 0 })
PMove:AddToggle("InfJump",     { Text = "Infinite Jump", Default = false })
PMove:AddToggle("Noclip",      { Text = "Noclip", Default = false })
PMove:AddToggle("SprintOn",    { Text = "Sprint (hold Shift)", Default = false })
PMove:AddSlider("SprintSpeed", { Text = "Sprint speed", Default = 40, Min = 20, Max = 150, Rounding = 0 })
PMove:AddToggle("GravityOn",   { Text = "Custom Gravity", Default = false })
PMove:AddSlider("Gravity",     { Text = "Gravity", Default = 100, Min = 0, Max = 300, Rounding = 0 })

PFly:AddToggle("FlyOn", { Text = "Fly", Default = false }):AddKeyPicker("FlyKey", {
    Default = "F", SyncToggleState = true, Mode = "Toggle", Text = "Fly", NoUI = false,
})
PFly:AddSlider("FlySpeed", { Text = "Fly speed", Default = 60, Min = 10, Max = 250, Rounding = 0 })

PMisc:AddToggle("AntiVoid",  { Text = "Anti-Void", Tooltip = "Teleports you back when you fall below the void line.", Default = false })
PMisc:AddToggle("AntiSit",   { Text = "Anti-Sit", Default = false })
PMisc:AddToggle("Freeze",    { Text = "Freeze (anchor)", Default = false })
PMisc:AddToggle("SpinOn",    { Text = "Spin", Default = false })
PMisc:AddSlider("SpinSpeed", { Text = "Spin speed", Default = 10, Min = 1, Max = 50, Rounding = 0 })
PMisc:AddToggle("ClickTP",   { Text = "Ctrl + Click Teleport", Tooltip = "PC only.", Default = false })
PMisc:AddButton({ Text = "Reset Character", Func = function()
    local h = getHum()
    if h then h.Health = 0 end
end })

PCam:AddToggle("FOVOn",     { Text = "Custom FOV", Default = false })
PCam:AddSlider("FOV",       { Text = "FOV", Default = 90, Min = 40, Max = 120, Rounding = 0 })
PCam:AddToggle("UnlockZoom",{ Text = "Unlock Zoom", Default = false })
PCam:AddToggle("Crosshair", { Text = "Crosshair", Default = false })

----------------------------------------------------------------------
-- TAB: VISUALS
----------------------------------------------------------------------
local VEsp   = Tabs.Visuals:AddLeftGroupbox("ESP", "scan-eye")
local VLight = Tabs.Visuals:AddRightGroupbox("Lighting", "sun")
local VPerf  = Tabs.Visuals:AddRightGroupbox("Performance", "gauge")

VEsp:AddToggle("PlayerESP",   { Text = "Player ESP (highlight)", Default = false })
VEsp:AddToggle("ESPNames",    { Text = "ESP Names", Default = true })
VEsp:AddToggle("ESPDistance", { Text = "ESP Distance", Default = true })
VEsp:AddToggle("PromptESP",   { Text = "Prompt ESP", Tooltip = "Highlights interactable objects (ProximityPrompts).", Default = false })
VEsp:AddLabel("ESP color"):AddColorPicker("ESPColor", { Default = Color3.fromRGB(255, 80, 80), Title = "ESP color" })
VEsp:AddLabel("Prompt color"):AddColorPicker("PromptColor", { Default = Color3.fromRGB(80, 200, 255), Title = "Prompt ESP color" })

VLight:AddToggle("Fullbright", { Text = "Fullbright", Default = false })
VLight:AddToggle("NoFog",      { Text = "No Fog", Default = false })
VLight:AddToggle("AlwaysDay",  { Text = "Custom Time of Day", Default = false })
VLight:AddSlider("TimeOfDay",  { Text = "Clock time", Default = 14, Min = 0, Max = 24, Rounding = 1 })
VLight:AddToggle("NoShadows",  { Text = "Remove Shadows", Default = false })
VLight:AddToggle("NoPostFX",   { Text = "Remove Blur / Bloom / Rays", Default = false })

VPerf:AddToggle("FPSBoost",   { Text = "FPS Boost (materials)", Default = false })
VPerf:AddToggle("NoParticles",{ Text = "Disable Particles", Default = false })
VPerf:AddToggle("MuteAudio",  { Text = "Mute Game Audio", Default = false })
VPerf:AddToggle("StatsLabel", { Text = "FPS / Ping overlay", Default = true })

----------------------------------------------------------------------
-- TAB: TELEPORT
----------------------------------------------------------------------
local TPlayer = Tabs.World:AddLeftGroupbox("Players", "users")
local TPlace  = Tabs.World:AddRightGroupbox("Places", "map")

local function playerNames()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then t[#t + 1] = p.Name end
    end
    table.sort(t)
    if #t == 0 then t[1] = "(nobody)" end
    return t
end

TPlayer:AddDropdown("TargetPlayer", { Text = "Target", Values = playerNames(), Default = 1, Searchable = true })
TPlayer:AddButton({ Text = "Refresh list", Func = function()
    Options.TargetPlayer:SetValues(playerNames())
end })
TPlayer:AddButton({ Text = "Teleport to player", Func = function()
    local target = Players:FindFirstChild(Options.TargetPlayer.Value or "")
    local root, troot = getRoot(), target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if root and troot then root.CFrame = troot.CFrame * CFrame.new(0, 0, 3) else notify("Target not available") end
end })
TPlayer:AddToggle("FollowPlayer",  { Text = "Follow player", Default = false })
TPlayer:AddToggle("SpectatePlayer",{ Text = "Spectate player", Default = false })

local waypoint
TPlace:AddButton({ Text = "Teleport to spawn", Func = function()
    local root = getRoot()
    local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    if root and spawn then root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0) else notify("No spawn found") end
end })
TPlace:AddButton({ Text = "Save waypoint", Func = function()
    local root = getRoot()
    if root then waypoint = root.CFrame; notify("Waypoint saved") end
end })
TPlace:AddButton({ Text = "Go to waypoint", Func = function()
    local root = getRoot()
    if root and waypoint then root.CFrame = waypoint else notify("No waypoint saved") end
end })
TPlace:AddButton({ Text = "Teleport to nearest prompt", Func = function()
    local root = getRoot()
    if not root then return end
    local best, bd
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local part = promptPart(d)
            if part then
                local dist = (root.Position - part.Position).Magnitude
                if dist > 6 and (not bd or dist < bd) then best, bd = part, dist end
            end
        end
    end
    if best then root.CFrame = best.CFrame * CFrame.new(0, 3, 4) else notify("No prompts found") end
end })

----------------------------------------------------------------------
-- TAB: SERVER
----------------------------------------------------------------------
local SInfo = Tabs.Server:AddLeftGroupbox("Server Info", "info")
local SHop  = Tabs.Server:AddRightGroupbox("Server Tools", "wrench")

local InfoLabel = SInfo:AddLabel("Loading...", true)
SInfo:AddButton({ Text = "Copy JobId",   Func = function() if setClip then setClip(game.JobId); notify("JobId copied") end end })
SInfo:AddButton({ Text = "Copy PlaceId", Func = function() if setClip then setClip(tostring(game.PlaceId)); notify("PlaceId copied") end end })
SInfo:AddToggle("NotifyEnabled", { Text = "Show notifications", Default = true })

local function fetchServers(cursor)
    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s")
        :format(game.PlaceId, cursor and ("&cursor=" .. cursor) or "")
    local body
    local ok = pcall(function() body = game:HttpGet(url) end)
    if not ok or not body then
        if httpReq then
            local r = safe(httpReq, { Url = url, Method = "GET" })
            body = r and r.Body
        end
    end
    if not body then return nil end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, body)
    return ok2 and data or nil
end

local function pickServer(mode)
    local candidates = {}
    local cursor
    for _ = 1, 3 do
        local data = fetchServers(cursor)
        if not data or not data.data then break end
        for _, s in ipairs(data.data) do
            if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
                candidates[#candidates + 1] = s
            end
        end
        cursor = data.nextPageCursor
        if not cursor then break end
    end
    if #candidates == 0 then return nil end
    if mode == "Fewest players" then
        table.sort(candidates, function(a, b) return a.playing < b.playing end)
        return candidates[1]
    elseif mode == "Most players (not full)" then
        table.sort(candidates, function(a, b) return a.playing > b.playing end)
        return candidates[1]
    end
    return candidates[math.random(1, #candidates)]
end

local function queueReexec()
    if Toggles.AutoReexec and Toggles.AutoReexec.Value and queueTP then
        local url = Options.ReexecURL.Value
        if url and url ~= "" then
            pcall(queueTP, ("loadstring(game:HttpGet(%q))()"):format(url))
        end
    end
end

local hopping = false
local function serverHop(mode)
    if hopping then return end
    hopping = true
    notify("Searching for a server...")
    local s = pickServer(mode or Options.HopMode.Value)
    if s then
        queueReexec()
        local ok = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, s.id, LocalPlayer)
        if not ok then notify("Teleport failed") end
    else
        notify("No other server found")
    end
    task.delay(8, function() hopping = false end)
end

SHop:AddButton({ Text = "Hop: random server",   Func = function() serverHop("Random") end })
SHop:AddButton({ Text = "Hop: fewest players",  Func = function() serverHop("Fewest players") end })
SHop:AddButton({ Text = "Hop: most players",    Func = function() serverHop("Most players (not full)") end })
SHop:AddButton({ Text = "Rejoin this server", Func = function()
    queueReexec()
    if #Players:GetPlayers() <= 1 then
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
end })
SHop:AddInput("JoinJobId", { Text = "Join by JobId", Default = "", Placeholder = "paste JobId", Finished = true })
SHop:AddButton({ Text = "Join JobId", Func = function()
    local id = Options.JoinJobId.Value
    if id and id ~= "" then
        queueReexec()
        pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, id, LocalPlayer)
    end
end })

----------------------------------------------------------------------
-- TAB: UI SETTINGS
----------------------------------------------------------------------
local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddToggle("KeybindMenu", { Text = "Show keybind menu", Default = false, Callback = function(v) Library.KeybindFrame.Visible = v end })
MenuGroup:AddToggle("CustomCursor", { Text = "Custom cursor", Default = false, Callback = function(v) Library.ShowCustomCursor = v end })
MenuGroup:AddButton({ Text = "Unload", Func = function() Library:Unload() end })
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind", "ReexecURL", "JoinJobId" })
ThemeManager:SetFolder("PWTPanel")
SaveManager:SetFolder("PWTPanel/configs")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

----------------------------------------------------------------------
-- LOGIC
----------------------------------------------------------------------

-- Floating button for touch devices (Delta mobile)
do
    local gui = Instance.new("ScreenGui")
    gui.Name = "PWTPanelToggle"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    local ok = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
    if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(44, 44)
    b.Position = UDim2.new(0, 10, 0.5, -22)
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    b.BackgroundTransparency = 0.15
    b.Text = "UI"
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Parent = gui
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    b.MouseButton1Click:Connect(function() Library:Toggle() end)
    env.__PWT_TOGGLE_GUI = gui
end

-- Server info label + overlay
local overlay = Library:AddDraggableLabel("PWT Panel")
task.spawn(function()
    while not Library.Unloaded do
        local fps = math.floor(1 / math.max(RunService.RenderStepped:Wait(), 1e-3))
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        local showStats = Toggles.StatsLabel and Toggles.StatsLabel.Value
        pcall(function()
            if showStats then overlay:SetText(("PWT Panel | %d fps | %d ms"):format(fps, ping)) end
            if overlay.SetVisible then overlay:SetVisible(showStats and true or false) end
        end)
        pcall(InfoLabel.SetText, InfoLabel, ("Players: %d/%d\nPing: %d ms\nPlaceId: %d\nJobId: %s"):format(
            #Players:GetPlayers(), Players.MaxPlayers, ping, game.PlaceId, game.JobId:sub(1, 18)))
        task.wait(1)
    end
end)

-- Anti-AFK
track(LocalPlayer.Idled:Connect(function()
    if Toggles.AntiAFK.Value then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

-- Auto Buy / Collect / Claim / Interact / Click / Pickup loops
task.spawn(function()
    while not Library.Unloaded do
        task.wait(Options.BuyDelay.Value)
        local root = getRoot()
        if root then
            local range = Options.BuyRange.Value
            if Toggles.AutoBuyPrompt.Value then
                local words = splitKeywords(Options.BuyKeywords.Value)
                for d in pairs(Cache.prompts) do
                    if d.Parent and d.Enabled then
                        local txt = (d.ActionText or "") .. " " .. (d.ObjectText or "") .. " " .. d.Name
                        if matchesAny(txt, words) and not isBlocked(txt) then
                            local part = promptPart(d)
                            if part then
                                local dist = distTo(part)
                                if dist > range and Toggles.AutoBuyTP.Value and dist < 2000 then
                                    root.CFrame = part.CFrame * CFrame.new(0, 3, 3)
                                    task.wait(0.15)
                                    dist = distTo(part)
                                end
                                if dist <= range then firePrompt(d) end
                            end
                        end
                    end
                end
            end
            if Toggles.AutoBuyGui.Value then
                for _, b in ipairs(scanButtons(splitKeywords(Options.BuyKeywords.Value), true)) do
                    pressGuiButton(b)
                end
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(Options.CollectDelay.Value)
        local root = getRoot()
        if root then
            if Toggles.AutoCollectCash.Value and firetouch then
                local words = splitKeywords(Options.CollectKeywords.Value)
                for part in pairs(Cache.touch) do
                    if part.Parent and (matchesAny(part.Name, words) or (part.Parent and matchesAny(part.Parent.Name, words))) then
                        pcall(firetouch, root, part, 0)
                        pcall(firetouch, root, part, 1)
                    end
                end
            end
            if Toggles.AutoPickup.Value and firetouch then
                local words = { "drop", "pickup", "crate", "loot", "orb", "gem" }
                for part in pairs(Cache.touch) do
                    if part.Parent and matchesAny(part.Name, words) then
                        pcall(firetouch, root, part, 0)
                        pcall(firetouch, root, part, 1)
                    end
                end
            end
            if Toggles.AutoInteract.Value then
                local range = Options.BuyRange.Value
                for d in pairs(Cache.prompts) do
                    if d.Parent and d.Enabled then
                        local txt = (d.ActionText or "") .. " " .. (d.ObjectText or "")
                        if not isBlocked(txt) then
                            local part = promptPart(d)
                            if part and distTo(part) <= range then firePrompt(d) end
                        end
                    end
                end
            end
            if Toggles.AutoClickDetect.Value and fireclick then
                for d in pairs(Cache.clicks) do
                    if d.Parent and d.Parent:IsA("BasePart") then
                        if distTo(d.Parent) <= math.min(d.MaxActivationDistance, Options.BuyRange.Value) then
                            pcall(fireclick, d)
                        end
                    end
                end
            end
        end
        if Toggles.AutoClaimGui.Value then
            for _, b in ipairs(scanButtons(splitKeywords(Options.ClaimKeywords.Value), true)) do
                pressGuiButton(b)
            end
        end
    end
end)

-- Auto Store Tasks (Pet Store Tycoon helper)
task.spawn(function()
    while not Library.Unloaded do
        task.wait(Options.StoreDelay.Value)
        if Toggles.AutoStoreTasks.Value then
            local root = getRoot()
            if root then
                local words = splitKeywords(Options.StoreKeywords.Value)
                local range = Options.BuyRange.Value
                local nearest, nearestDist
                for d in pairs(Cache.prompts) do
                    if d.Parent and d.Enabled then
                        local txt = (d.ActionText or "") .. " " .. (d.ObjectText or "") .. " " .. d.Name
                        if matchesAny(txt, words) and not isBlocked(txt) then
                            local part = promptPart(d)
                            if part then
                                local dist = distTo(part)
                                if dist <= range then
                                    firePrompt(d)
                                    nearest = nil
                                    nearestDist = -1
                                elseif nearestDist ~= -1 and (not nearestDist or dist < nearestDist) then
                                    nearest, nearestDist = part, dist
                                end
                            end
                        end
                    end
                end
                if nearest and nearestDist ~= -1 and Toggles.StoreTasksTP.Value and nearestDist < 1500 then
                    root.CFrame = nearest.CFrame * CFrame.new(0, 3, 3)
                end
            end
        end
    end
end)

-- Auto Server Hop
local nextHopAt = os.clock() + Options.HopInterval.Value * 60
Toggles.AutoServerHop:OnChanged(function()
    nextHopAt = os.clock() + Options.HopInterval.Value * 60
end)
Options.HopInterval:OnChanged(function()
    nextHopAt = os.clock() + Options.HopInterval.Value * 60
end)
task.spawn(function()
    while not Library.Unloaded do
        task.wait(1)
        if Toggles.AutoServerHop.Value and os.clock() >= nextHopAt then
            nextHopAt = os.clock() + Options.HopInterval.Value * 60
            serverHop(Options.HopMode.Value)
        end
    end
end)

-- Auto Rejoin on kick / disconnect
task.spawn(function()
    local ok, promptOverlay = pcall(function()
        return CoreGui:WaitForChild("RobloxPromptGui", 15):WaitForChild("promptOverlay", 15)
    end)
    if ok and promptOverlay then
        track(promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" and Toggles.AutoRejoin.Value then
                task.wait(1)
                queueReexec()
                pcall(function()
                    if #Players:GetPlayers() <= 1 then
                        TeleportService:Teleport(game.PlaceId, LocalPlayer)
                    else
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                    end
                end)
            end
        end))
    end
end)

-- Auto Respawn / Auto Equip / Auto Jump / death tracking
local lastDeathCF
local function onCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    track(hum.Died:Connect(function()
        local r = char:FindFirstChild("HumanoidRootPart")
        lastDeathCF = r and r.CFrame
    end))
    if Toggles.AutoRespawn.Value and lastDeathCF then
        local root = char:WaitForChild("HumanoidRootPart", 10)
        task.wait(0.4)
        if root and lastDeathCF then root.CFrame = lastDeathCF end
    end
end
track(LocalPlayer.CharacterAdded:Connect(onCharacter))
if LocalPlayer.Character then task.spawn(onCharacter, LocalPlayer.Character) end

task.spawn(function()
    while not Library.Unloaded do
        task.wait(1)
        if Toggles.AutoEquip.Value then
            local hum = getHum()
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            if hum and bp and not getChar():FindFirstChildOfClass("Tool") then
                local tool = bp:FindFirstChildOfClass("Tool")
                if tool then pcall(function() hum:EquipTool(tool) end) end
            end
        end
        if Toggles.AutoJump.Value then
            local hum = getHum()
            if hum then hum.Jump = true end
        end
    end
end)

-- Movement: walkspeed / jump / gravity / sprint / spin / anti-sit / anti-void
local sprintHeld, sprinting, baseSpeed = false, false, nil
track(UserInputService.InputBegan:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.LeftShift then sprintHeld = true end
end))
track(UserInputService.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.LeftShift then sprintHeld = false end
end))

local defaultGravity = Workspace.Gravity
local defaultSpeed = (getHum() and getHum().WalkSpeed) or 16
local defaultJump = (getHum() and getHum().JumpPower) or 50
local voidReturn

track(RunService.Heartbeat:Connect(function()
    local hum, root = getHum(), getRoot()
    if hum then
        local sprintNow = Toggles.SprintOn.Value and sprintHeld
        if sprintNow then
            if not sprinting then sprinting = true; baseSpeed = hum.WalkSpeed end
            hum.WalkSpeed = Options.SprintSpeed.Value
        else
            if sprinting then
                sprinting = false
                hum.WalkSpeed = baseSpeed or defaultSpeed
            end
            if Toggles.WalkSpeedOn.Value then hum.WalkSpeed = Options.WalkSpeed.Value end
        end
        if Toggles.JumpPowerOn.Value then
            hum.UseJumpPower = true
            hum.JumpPower = Options.JumpPower.Value
        end
        if Toggles.AntiSit.Value and hum.Sit then hum.Sit = false end
    end
    if Toggles.GravityOn.Value then Workspace.Gravity = Options.Gravity.Value end
    if root then
        if Toggles.SpinOn.Value then
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(Options.SpinSpeed.Value), 0)
        end
        if Toggles.AntiVoid.Value then
            if root.Position.Y < Workspace.FallenPartsDestroyHeight + 60 then
                if voidReturn then root.Velocity = Vector3.zero; root.CFrame = voidReturn end
            elseif hum and hum.FloorMaterial ~= Enum.Material.Air then
                voidReturn = root.CFrame + Vector3.new(0, 4, 0)
            end
        end
    end
end))

-- restore defaults when toggles go off (only touches values when you flip the switch)
Toggles.WalkSpeedOn:OnChanged(function()
    local h = getHum()
    if h and not Toggles.WalkSpeedOn.Value then h.WalkSpeed = defaultSpeed end
end)
Toggles.JumpPowerOn:OnChanged(function()
    local h = getHum()
    if h and not Toggles.JumpPowerOn.Value then h.JumpPower = defaultJump end
end)
Toggles.GravityOn:OnChanged(function()
    if not Toggles.GravityOn.Value then Workspace.Gravity = defaultGravity end
end)
Toggles.Freeze:OnChanged(function()
    local r = getRoot()
    if r then r.Anchored = Toggles.Freeze.Value end
end)

-- Infinite jump
track(UserInputService.JumpRequest:Connect(function()
    if Toggles.InfJump.Value then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

-- Noclip
track(RunService.Stepped:Connect(function()
    if Toggles.Noclip.Value or Toggles.FlyOn.Value then
        local c = getChar()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end
end))

-- Fly
local flyBV, flyBG
local function stopFly()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
end
track(RunService.RenderStepped:Connect(function()
    if Toggles.FlyOn.Value then
        local root, hum = getRoot(), getHum()
        if not root or not hum then return end
        if not flyBV then
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flyBV.Velocity = Vector3.zero
            flyBV.Parent = root
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            flyBG.P = 9e4
            flyBG.Parent = root
        end
        hum.PlatformStand = true
        local cam = Workspace.CurrentCamera
        local dir = Vector3.zero
        local md = hum.MoveDirection
        if md.Magnitude > 0 then
            -- convert thumbstick/WASD direction into camera-relative 3D direction
            local look = cam.CFrame.LookVector
            local right = cam.CFrame.RightVector
            local flatLook = Vector3.new(look.X, 0, look.Z)
            local flatRight = Vector3.new(right.X, 0, right.Z)
            local lf = flatLook.Magnitude > 1e-3 and md:Dot(flatLook.Unit) or 0
            local rt = flatRight.Magnitude > 1e-3 and md:Dot(flatRight.Unit) or 0
            dir = look * lf + right * rt
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        flyBV.Velocity = dir * Options.FlySpeed.Value
        flyBG.CFrame = cam.CFrame
    elseif flyBV then
        stopFly()
    end
end))

-- Click teleport (Ctrl + click / long tap not needed on mobile)
local mouse = LocalPlayer:GetMouse()
track(mouse.Button1Down:Connect(function()
    if Toggles.ClickTP.Value and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local root = getRoot()
        if root and mouse.Hit then root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 4, 0)) end
    end
end))

-- Camera: FOV / zoom / crosshair
local defaultFOV = Camera.FieldOfView
local defaultMaxZoom = LocalPlayer.CameraMaxZoomDistance
local crossGui
local function setCrosshair(on)
    if on and not crossGui then
        crossGui = Instance.new("ScreenGui")
        crossGui.Name = "PWTCrosshair"
        crossGui.IgnoreGuiInset = true
        crossGui.ResetOnSpawn = false
        pcall(function() crossGui.Parent = (gethui and gethui()) or CoreGui end)
        if not crossGui.Parent then crossGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
        for _, size in ipairs({ UDim2.fromOffset(14, 2), UDim2.fromOffset(2, 14) }) do
            local f = Instance.new("Frame")
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.fromScale(0.5, 0.5)
            f.Size = size
            f.BackgroundColor3 = Color3.new(1, 1, 1)
            f.BorderSizePixel = 0
            f.Parent = crossGui
        end
    elseif not on and crossGui then
        crossGui:Destroy(); crossGui = nil
    end
end
track(RunService.RenderStepped:Connect(function()
    Camera = Workspace.CurrentCamera
    if Toggles.FOVOn.Value then Camera.FieldOfView = Options.FOV.Value end
    if Toggles.UnlockZoom.Value then
        LocalPlayer.CameraMaxZoomDistance = 100000
    elseif LocalPlayer.CameraMaxZoomDistance ~= defaultMaxZoom then
        LocalPlayer.CameraMaxZoomDistance = defaultMaxZoom
    end
end))
Toggles.FOVOn:OnChanged(function() if not Toggles.FOVOn.Value then Camera.FieldOfView = defaultFOV end end)
Toggles.Crosshair:OnChanged(function() setCrosshair(Toggles.Crosshair.Value) end)

-- Follow / Spectate
task.spawn(function()
    while not Library.Unloaded do
        task.wait(0.2)
        local target = Players:FindFirstChild(Options.TargetPlayer.Value or "")
        local tchar = target and target.Character
        local troot = tchar and tchar:FindFirstChild("HumanoidRootPart")
        if Toggles.FollowPlayer.Value and troot then
            local hum = getHum()
            if hum then hum:MoveTo(troot.Position) end
        end
        if Toggles.SpectatePlayer.Value and tchar then
            local th = tchar:FindFirstChildOfClass("Humanoid")
            if th then Workspace.CurrentCamera.CameraSubject = th end
        end
    end
end)
Toggles.SpectatePlayer:OnChanged(function()
    if not Toggles.SpectatePlayer.Value then
        local hum = getHum()
        if hum then Workspace.CurrentCamera.CameraSubject = hum end
    end
end)

-- ESP
local espObjects = {}
local promptEsp = {}
local function clearEsp(key)
    local o = espObjects[key]
    if o then
        for _, i in ipairs(o) do pcall(function() i:Destroy() end) end
        espObjects[key] = nil
    end
end

local function makeHighlight(adornee, color)
    local h = Instance.new("Highlight")
    h.Adornee = adornee
    h.FillColor = color
    h.OutlineColor = color
    h.FillTransparency = 0.6
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = (gethui and gethui()) or CoreGui
    return h
end

local function makeTag(adornee, text, color)
    local bb = Instance.new("BillboardGui")
    bb.Adornee = adornee
    bb.Size = UDim2.fromOffset(160, 30)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromScale(1, 1)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color
    l.TextStrokeTransparency = 0.4
    l.Font = Enum.Font.GothamBold
    l.TextSize = 13
    l.Parent = bb
    bb.Parent = (gethui and gethui()) or CoreGui
    return bb, l
end

task.spawn(function()
    while not Library.Unloaded do
        task.wait(0.4)
        -- player ESP
        local live = {}
        if Toggles.PlayerESP.Value then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    live[p] = true
                    local key = "p_" .. p.UserId
                    local color = Options.ESPColor.Value
                    if not espObjects[key] or not espObjects[key][1].Parent or espObjects[key][1].Adornee ~= p.Character then
                        clearEsp(key)
                        local h = makeHighlight(p.Character, color)
                        local bb, lbl = makeTag(p.Character:FindFirstChild("Head") or p.Character.HumanoidRootPart, p.DisplayName, color)
                        espObjects[key] = { h, bb, lbl }
                    end
                    local o = espObjects[key]
                    o[1].FillColor = color; o[1].OutlineColor = color
                    o[3].TextColor3 = color
                    local text = ""
                    if Toggles.ESPNames.Value then text = p.DisplayName end
                    if Toggles.ESPDistance.Value then
                        text = text .. " [" .. math.floor(distTo(p.Character.HumanoidRootPart)) .. "]"
                    end
                    o[3].Text = text
                end
            end
        end
        for key in pairs(espObjects) do
            if key:sub(1, 2) == "p_" then
                local uid = tonumber(key:sub(3))
                local pl = uid and Players:GetPlayerByUserId(uid)
                if not (Toggles.PlayerESP.Value and pl and live[pl]) then clearEsp(key) end
            end
        end

        -- prompt ESP (nearest 15 only; Roblox limits concurrent Highlights)
        if Toggles.PromptESP.Value then
            local list = {}
            for d in pairs(Cache.prompts) do
                if d.Parent and d.Enabled then
                    local part = promptPart(d)
                    if part then list[#list + 1] = { d = d, part = part, dist = distTo(part) } end
                end
            end
            table.sort(list, function(a, b) return a.dist < b.dist end)
            local keep = {}
            for i = 1, math.min(15, #list) do
                local d = list[i].d
                keep[d] = true
                local h = promptEsp[d]
                if not h or not h.Parent then
                    h = makeHighlight(list[i].part, Options.PromptColor.Value)
                    promptEsp[d] = h
                end
                h.FillColor = Options.PromptColor.Value
                h.OutlineColor = Options.PromptColor.Value
            end
            for d, h in pairs(promptEsp) do
                if not keep[d] then pcall(function() h:Destroy() end); promptEsp[d] = nil end
            end
        else
            for d, h in pairs(promptEsp) do pcall(function() h:Destroy() end); promptEsp[d] = nil end
        end
    end
end)

-- Lighting
local origLighting = {
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart, GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
}
local postFxState = {}
track(RunService.RenderStepped:Connect(function()
    if Toggles.Fullbright.Value then
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    end
    if Toggles.NoFog.Value then
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6
    end
    if Toggles.AlwaysDay.Value then Lighting.ClockTime = Options.TimeOfDay.Value end
    if Toggles.NoShadows.Value then Lighting.GlobalShadows = false end
end))
local function restoreLighting()
    if not Toggles.Fullbright.Value then
        Lighting.Brightness = origLighting.Brightness
        Lighting.Ambient = origLighting.Ambient
        Lighting.OutdoorAmbient = origLighting.OutdoorAmbient
    end
    if not Toggles.NoFog.Value then
        Lighting.FogEnd = origLighting.FogEnd
        Lighting.FogStart = origLighting.FogStart
    end
    if not Toggles.NoShadows.Value then Lighting.GlobalShadows = origLighting.GlobalShadows end
end
Toggles.Fullbright:OnChanged(restoreLighting)
Toggles.NoFog:OnChanged(restoreLighting)
Toggles.NoShadows:OnChanged(restoreLighting)

Toggles.NoPostFX:OnChanged(function()
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("BlurEffect") or e:IsA("BloomEffect") or e:IsA("SunRaysEffect")
            or e:IsA("DepthOfFieldEffect") or e:IsA("ColorCorrectionEffect") then
            if Toggles.NoPostFX.Value then
                postFxState[e] = e.Enabled
                e.Enabled = false
            elseif postFxState[e] ~= nil then
                e.Enabled = postFxState[e]
            end
        end
    end
end)

-- Performance
local matCache = setmetatable({}, { __mode = "k" })
Toggles.FPSBoost:OnChanged(function()
    local on = Toggles.FPSBoost.Value
    task.spawn(function()
        local n = 0
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                if on then
                    if matCache[d] == nil then matCache[d] = { d.Material, d.CastShadow } end
                    d.Material = Enum.Material.SmoothPlastic
                    d.CastShadow = false
                elseif matCache[d] then
                    d.Material = matCache[d][1]
                    d.CastShadow = matCache[d][2]
                end
                n = n + 1
                if n % 400 == 0 then task.wait() end
            end
        end
    end)
    pcall(function() settings().Rendering.QualityLevel = on and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic end)
end)

local particleCache = setmetatable({}, { __mode = "k" })
Toggles.NoParticles:OnChanged(function()
    local on = Toggles.NoParticles.Value
    task.spawn(function()
        local n = 0
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                if on then particleCache[d] = d.Enabled; d.Enabled = false
                elseif particleCache[d] ~= nil then d.Enabled = particleCache[d] end
                n = n + 1
                if n % 300 == 0 then task.wait() end
            end
        end
    end)
end)

local soundCache = setmetatable({}, { __mode = "k" })
Toggles.MuteAudio:OnChanged(function()
    local on = Toggles.MuteAudio.Value
    for _, s in ipairs(game:GetDescendants()) do
        if s:IsA("Sound") then
            if on then soundCache[s] = s.Volume; s.Volume = 0
            elseif soundCache[s] then s.Volume = soundCache[s] end
        end
    end
end)
track(Workspace.DescendantAdded:Connect(function(d)
    if Toggles.NoParticles.Value and (d:IsA("ParticleEmitter") or d:IsA("Trail")) then d.Enabled = false end
    if Toggles.MuteAudio.Value and d:IsA("Sound") then soundCache[d] = d.Volume; d.Volume = 0 end
end))

-- Player list refresh
track(Players.PlayerAdded:Connect(function() pcall(function() Options.TargetPlayer:SetValues(playerNames()) end) end))
track(Players.PlayerRemoving:Connect(function() task.defer(function() pcall(function() Options.TargetPlayer:SetValues(playerNames()) end) end) end))

----------------------------------------------------------------------
-- Unload / cleanup
----------------------------------------------------------------------
local function cleanup()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    stopFly()
    setCrosshair(false)
    for k in pairs(espObjects) do clearEsp(k) end
    for d, h in pairs(promptEsp) do pcall(function() h:Destroy() end); promptEsp[d] = nil end
    local root, hum = getRoot(), getHum()
    if root then root.Anchored = false end
    if hum then hum.PlatformStand = false end
    Workspace.Gravity = defaultGravity
    Camera.FieldOfView = defaultFOV
    LocalPlayer.CameraMaxZoomDistance = defaultMaxZoom
    for k, v in pairs(origLighting) do pcall(function() Lighting[k] = v end) end
    if env.__PWT_TOGGLE_GUI then pcall(function() env.__PWT_TOGGLE_GUI:Destroy() end) end
    env.PWT_PANEL_LOADED = nil
    env.PWT_PANEL_UNLOAD = nil
end

Library:OnUnload(cleanup)
env.PWT_PANEL_LOADED = true
env.PWT_PANEL_UNLOAD = function() Library:Unload() end

SaveManager:LoadAutoloadConfig()
if game.PlaceId ~= TARGET_PLACE_ID then
    notify("Heads up: this isn't Pet Store Tycoon (PlaceId " .. tostring(game.PlaceId) .. ").", 6)
end
notify("PWT Panel loaded. RightShift or the UI button toggles the menu.", 5)
