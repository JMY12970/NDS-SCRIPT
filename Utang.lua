--[[
    SUKI Pwede Utang | Script Hub          (Obsidian UI, single LocalScript)
    PlaceId 109475655864288 (sari-sari store tycoon).

    Built from the instance tree of your dump (script sources were not
    recoverable, so server logic and remote arguments are unknown).
    Everything here is CLIENT-SIDE: movement, visuals, world tools, prompt
    helpers, teleports, ESP, and a Remote Spy to learn real remote arguments.

    Executor functions used when present (all guarded): fireproximityprompt,
    fireclickdetector, firetouchinterest, hookmetamethod, setclipboard,
    setfpscap, gethui, getgenv. Missing ones just disable that feature.
]]

local genv = (getgenv and getgenv()) or _G
if genv.SukiHub_Unload then
	pcall(genv.SukiHub_Unload)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")
local LP = Players.LocalPlayer

----------------------------------------------------------------------
-- Obsidian UI
----------------------------------------------------------------------
local REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local function fetch(path)
	return loadstring(game:HttpGet(REPO .. path))()
end

local okL, Library = pcall(fetch, "Library.lua")
if not okL or type(Library) ~= "table" then
	warn("[SukiHub] Obsidian failed to load: " .. tostring(Library))
	return
end
local okT, ThemeManager = pcall(fetch, "addons/ThemeManager.lua")
local okS, SaveManager = pcall(fetch, "addons/SaveManager.lua")
local Options, Toggles = Library.Options, Library.Toggles

----------------------------------------------------------------------
-- Core helpers
----------------------------------------------------------------------
local Conns = {}
local Cleanup = {}
local Ticks = {} -- id -> fn(dt)
local OnNew = {} -- key -> fn(newInstance)
local Saved = { Gravity = Workspace.Gravity }

local function connect(signal, fn)
	local c = signal:Connect(fn)
	Conns[#Conns + 1] = c
	return c
end

connect(RunService.Heartbeat, function(dt)
	for id, fn in pairs(Ticks) do
		local ok, err = pcall(fn, dt)
		if not ok then
			Ticks[id] = nil
			warn("[SukiHub] feature '" .. tostring(id) .. "' stopped: " .. tostring(err))
		end
	end
end)

local function notify(title, desc, t)
	pcall(function()
		Library:Notify({ Title = title, Description = desc, Time = t or 3 })
	end)
end

local function hum()
	local c = LP.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function root()
	local c = LP.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function W(...)
	local cur = Workspace
	for _, n in ipairs({ ... }) do
		cur = cur and cur:FindFirstChild(n)
	end
	return cur
end

local function children(inst, filter)
	local out = {}
	if inst then
		for _, c in ipairs(inst:GetChildren()) do
			if not filter or filter(c) then
				out[#out + 1] = c
			end
		end
	end
	return out
end

local function nameHas(...)
	local pats = { ... }
	return function(c)
		local n = c.Name:lower()
		for _, p in ipairs(pats) do
			if n:find(p, 1, true) then
				return true
			end
		end
		return false
	end
end

local function keysOf(set)
	local out = {}
	for k in pairs(set) do
		out[#out + 1] = k
	end
	return out
end

local function worldPos(inst)
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Attachment") then
		return inst.WorldPosition
	elseif inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then
		return worldPos(inst.Parent)
	elseif inst:IsA("Model") then
		local ok, cf = pcall(inst.GetPivot, inst)
		if ok then
			return cf.Position
		end
	end
	local sum, n = Vector3.zero, 0
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			sum += d.Position
			n += 1
			if n >= 80 then
				break
			end
		end
	end
	if n > 0 then
		return sum / n
	end
	return nil
end

local function tpTo(p, offset)
	local r = root()
	if r and p then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.new(p + (offset or Vector3.new(0, 4, 0)))
		return true
	end
	return false
end

local function myPos()
	local r = root()
	return r and r.Position
end

local function nearest(list, maxDist)
	local mp = myPos()
	if not mp then
		return nil
	end
	local best, bd = nil, maxDist or math.huge
	for _, inst in ipairs(list) do
		local p = worldPos(inst)
		if p then
			local d = (p - mp).Magnitude
			if d < bd then
				best, bd = inst, d
			end
		end
	end
	return best, bd
end

local function val(id, default)
	local o = Options[id] or Toggles[id]
	if o and o.Value ~= nil then
		return o.Value
	end
	return default
end

local function isOn(id)
	local t = Toggles[id]
	return t and t.Value or false
end

local function copy(text)
	if setclipboard then
		setclipboard(text)
		notify("Copied", "Copied to clipboard.")
	else
		print(text)
		notify("No clipboard", "Executor lacks setclipboard; printed to console.")
	end
end

local function guiParent()
	local ok, p = pcall(function()
		return (gethui and gethui()) or game:GetService("CoreGui")
	end)
	return ok and p or LP:WaitForChild("PlayerGui")
end

-- UI shorthands ------------------------------------------------------
local function tog(gb, id, text, tip, cb)
	return gb:AddToggle(id, {
		Text = text,
		Tooltip = tip,
		Default = false,
		Callback = function(v)
			local ok, e = pcall(cb, v)
			if not ok then
				warn("[SukiHub] " .. id .. ": " .. tostring(e))
			end
		end,
	})
end

local function sld(gb, id, text, min, max, def, rnd, cb, suffix)
	return gb:AddSlider(id, {
		Text = text,
		Min = min,
		Max = max,
		Default = def,
		Rounding = rnd or 0,
		Suffix = suffix or "",
		Callback = function(v)
			if cb then
				pcall(cb, v)
			end
		end,
	})
end

local function btn(gb, text, fn, tip)
	Saved.Buttons = (Saved.Buttons or 0) + 1
	return gb:AddButton({
		Text = text,
		Tooltip = tip,
		Func = function()
			local ok, e = pcall(fn)
			if not ok then
				warn("[SukiHub] " .. text .. ": " .. tostring(e))
				notify(text, "Failed: " .. tostring(e), 4)
			end
		end,
	})
end

local function tickTog(gb, id, text, tip, fn, offFn)
	return tog(gb, id, text, tip, function(v)
		if v then
			Ticks[id] = fn
		else
			Ticks[id] = nil
			if offFn then
				offFn()
			end
		end
	end)
end

local function throttle(interval, fn)
	local acc = interval
	return function(dt)
		acc += dt
		if acc >= interval then
			acc = 0
			fn()
		end
	end
end

----------------------------------------------------------------------
-- World scan (one pass, then kept current through DescendantAdded)
----------------------------------------------------------------------
local Prompts, Clicks, Seats, Emitters, Beams, Lights = {}, {}, {}, {}, {}, {}
local Decals, SGuis, BGuis, Sounds, Spawns = {}, {}, {}, {}, {}
local Sets = { Prompts, Clicks, Seats, Emitters, Beams, Lights, Decals, SGuis, BGuis, Sounds, Spawns }
local ScanDone = false

local function register(d)
	if d:IsA("ProximityPrompt") then
		Prompts[d] = true
	elseif d:IsA("ClickDetector") then
		Clicks[d] = true
	elseif d:IsA("Seat") or d:IsA("VehicleSeat") then
		Seats[d] = true
	elseif d:IsA("SpawnLocation") then
		Spawns[d] = true
	elseif d:IsA("ParticleEmitter") then
		Emitters[d] = true
	elseif d:IsA("Beam") then
		Beams[d] = true
	elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
		Lights[d] = true
	elseif d:IsA("Decal") then
		Decals[d] = true
	elseif d:IsA("SurfaceGui") then
		SGuis[d] = true
	elseif d:IsA("BillboardGui") then
		BGuis[d] = true
	elseif d:IsA("Sound") then
		Sounds[d] = true
	end
end

task.spawn(function()
	local n = 0
	for _, d in ipairs(Workspace:GetDescendants()) do
		register(d)
		n += 1
		if n % 3000 == 0 then
			task.wait()
		end
	end
	for _, d in ipairs(SoundService:GetDescendants()) do
		if d:IsA("Sound") then
			Sounds[d] = true
		end
	end
	ScanDone = true
end)

connect(Workspace.DescendantAdded, function(d)
	register(d)
	for _, fn in pairs(OnNew) do
		pcall(fn, d)
	end
end)

connect(Workspace.DescendantRemoving, function(d)
	for _, s in ipairs(Sets) do
		s[d] = nil
	end
end)

----------------------------------------------------------------------
-- Reversible property overrides (remember originals, restore on off)
----------------------------------------------------------------------
local Orig = {} -- key -> weak table inst -> original

local function ovr1(key, inst, prop, value)
	Orig[key] = Orig[key] or setmetatable({}, { __mode = "k" })
	local store = Orig[key]
	if store[inst] == nil then
		local ok, cur = pcall(function()
			return inst[prop]
		end)
		if not ok then
			return
		end
		store[inst] = cur
	end
	local newVal = value
	if type(value) == "function" then
		newVal = value(store[inst], inst)
	end
	pcall(function()
		inst[prop] = newVal
	end)
end

local function ovrSet(key, set, prop, value)
	for inst in pairs(set) do
		ovr1(key, inst, prop, value)
	end
end

local function unovr(key, prop)
	local store = Orig[key]
	if not store then
		return
	end
	for inst, v in pairs(store) do
		pcall(function()
			inst[prop] = v
		end)
	end
	Orig[key] = nil
end

local Reapply = {}

-- returns a toggle callback that applies/reverts `prop` on every item of `set`
local function setFeature(key, set, prop, value)
	local function applyAll()
		ovrSet(key, set, prop, value)
	end
	Reapply[key] = applyAll
	return function(on)
		if on then
			applyAll()
			OnNew[key] = function(d)
				if set[d] then
					ovr1(key, d, prop, value)
				end
			end
		else
			OnNew[key] = nil
			unovr(key, prop)
		end
	end
end

-- same idea for an explicit list of parts under some folders (client-only look/collide)
local function partsUnder(folder)
	local out = {}
	if folder then
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") then
				out[#out + 1] = d
			end
		end
	end
	return out
end

local function folderFeature(key, getFolder, prop, value)
	return function(on)
		local f = getFolder()
		if not f then
			notify("Not loaded", "That area isn't in memory yet (streaming?).")
			return
		end
		if on then
			for _, p in ipairs(partsUnder(f)) do
				ovr1(key, p, prop, value)
			end
		else
			unovr(key, prop)
		end
	end
end

----------------------------------------------------------------------
-- Window + tabs
----------------------------------------------------------------------
local Window = Library:CreateWindow({
	Title = "SUKI Hub",
	Footer = "Pwede Utang | client-side tools",
	NotifySide = "Right",
	ShowCustomCursor = false,
	Center = true,
	AutoShow = true,
})

local Tabs = {
	Move = Window:AddTab("Movement", "user"),
	Tele = Window:AddTab("Teleports", "map-pin"),
	Inter = Window:AddTab("Interact", "hand"),
	Vis = Window:AddTab("Visuals", "eye"),
	World = Window:AddTab("World", "globe"),
	Game = Window:AddTab("Game Tools", "wrench"),
}

----------------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------------
local MoveA = Tabs.Move:AddLeftGroupbox("Speed & Jump", "gauge")
local MoveB = Tabs.Move:AddRightGroupbox("Flight & Collision", "plane")
local MoveC = Tabs.Move:AddLeftGroupbox("Character State", "heart-pulse")
local MoveD = Tabs.Move:AddRightGroupbox("Positions & Tools", "navigation")

-- Walk speed
tickTog(MoveA, "SpeedOn", "Walk Speed", "Overrides WalkSpeed every frame.", function()
	local h = hum()
	if h then
		if not Saved.Walk then
			Saved.Walk = h.WalkSpeed
		end
		h.WalkSpeed = val("WalkSpeed", 32)
	end
end, function()
	local h = hum()
	if h then
		h.WalkSpeed = Saved.Walk or 16
	end
	Saved.Walk = nil
end):AddKeyPicker("SpeedKey", { Default = "V", Mode = "Toggle", Text = "Walk Speed", SyncToggleState = true })
sld(MoveA, "WalkSpeed", "Speed", 1, 300, 32, 0)

-- Jump power
tickTog(MoveA, "JumpOn", "Jump Power", "Forces JumpPower.", function()
	local h = hum()
	if h then
		if not Saved.Jump then
			Saved.Jump = { h.UseJumpPower, h.JumpPower }
		end
		h.UseJumpPower = true
		h.JumpPower = val("JumpPower", 90)
	end
end, function()
	local h = hum()
	if h and Saved.Jump then
		h.UseJumpPower = Saved.Jump[1]
		h.JumpPower = Saved.Jump[2]
	end
	Saved.Jump = nil
end)
sld(MoveA, "JumpPower", "Jump Power", 10, 500, 90, 0)

tog(MoveA, "InfJump", "Infinite Jump", "Jump again in mid-air.", function() end)
connect(UIS.JumpRequest, function()
	if isOn("InfJump") then
		local h = hum()
		if h then
			h:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

tickTog(MoveA, "AutoJump", "Auto Jump", "Keeps jumping while on the ground.", function()
	local h = hum()
	if h then
		h.Jump = true
	end
end)

tog(MoveA, "GravOn", "Custom Gravity", "Workspace.Gravity (default ~196.2).", function(on)
	Workspace.Gravity = on and val("GravityVal", 60) or Saved.Gravity
end)
sld(MoveA, "GravityVal", "Gravity", 0, 400, 60, 0, function(v)
	if isOn("GravOn") then
		Workspace.Gravity = v
	end
end)

tickTog(MoveA, "HipOn", "Hip Height", "Raises or lowers the character.", function()
	local h = hum()
	if h then
		if not Saved.Hip then
			Saved.Hip = h.HipHeight
		end
		h.HipHeight = val("HipVal", 4)
	end
end, function()
	local h = hum()
	if h and Saved.Hip then
		h.HipHeight = Saved.Hip
	end
	Saved.Hip = nil
end)
sld(MoveA, "HipVal", "Hip Height", 0, 40, 4, 1)

btn(MoveA, "Dash Forward", function()
	local r = root()
	if r then
		r.AssemblyLinearVelocity = r.CFrame.LookVector * val("DashPower", 120) + Vector3.new(0, 18, 0)
	end
end)
sld(MoveA, "DashPower", "Dash Power", 20, 400, 120, 0)

btn(MoveA, "Teleport Forward", function()
	local r = root()
	if r then
		r.CFrame = r.CFrame + r.CFrame.LookVector * val("TpForward", 25)
	end
end)
sld(MoveA, "TpForward", "Teleport Distance", 3, 200, 25, 0, nil, " st")

-- Fly (BodyVelocity so gravity is cancelled while hovering)
local FlyBV
local function stopFly()
	if FlyBV then
		FlyBV:Destroy()
		FlyBV = nil
	end
end
tickTog(MoveB, "FlyOn", "Fly", "Joystick moves, camera pitch climbs/dives. Jump = up, Ctrl = down.", function()
	local r, h = root(), hum()
	if not (r and h) then
		return
	end
	if not (FlyBV and FlyBV.Parent == r) then
		stopFly()
		FlyBV = Instance.new("BodyVelocity")
		FlyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		FlyBV.Velocity = Vector3.zero
		FlyBV.Parent = r
	end
	local sp = val("FlySpeed", 60)
	local md = h.MoveDirection
	local look = Workspace.CurrentCamera.CFrame.LookVector
	local dir = Vector3.zero
	if md.Magnitude > 0.05 then
		local fl = Vector3.new(look.X, 0, look.Z)
		local fwd = fl.Magnitude > 0.01 and md:Dot(fl.Unit) or 0
		dir = md * sp + Vector3.new(0, look.Y * fwd * sp, 0)
	end
	if UIS:IsKeyDown(Enum.KeyCode.Space) or h.Jump then
		dir += Vector3.new(0, sp, 0)
	end
	if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
		dir -= Vector3.new(0, sp, 0)
	end
	FlyBV.Velocity = dir
end, stopFly):AddKeyPicker("FlyKey", { Default = "F", Mode = "Toggle", Text = "Fly", SyncToggleState = true })
sld(MoveB, "FlySpeed", "Fly Speed", 5, 300, 60, 0)

-- Noclip (Stepped so it runs before physics)
connect(RunService.Stepped, function()
	if isOn("NoclipOn") and LP.Character then
		for _, p in ipairs(LP.Character:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				p.CanCollide = false
			end
		end
	end
end)
tog(MoveB, "NoclipOn", "Noclip", "Walk through walls.", function() end):AddKeyPicker(
	"NoclipKey",
	{ Default = "N", Mode = "Toggle", Text = "Noclip", SyncToggleState = true }
)

tickTog(MoveB, "SpinOn", "Spin", "Rotates your character.", function(dt)
	local r = root()
	if r then
		r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(val("SpinSpeed", 360)) * dt, 0)
	end
end)
sld(MoveB, "SpinSpeed", "Spin Speed", 30, 1440, 360, 0, nil, " deg/s")

tog(MoveB, "FreezeOn", "Freeze In Place", "Anchors your root part (client).", function(on)
	local r = root()
	if r then
		r.Anchored = on
	end
end)

-- Walk through map groups (client collision only)
local function colToggle(id, text, getFolder)
	tog(
		MoveB,
		id,
		text,
		"Client-side only: turns collision off for this group so you can pass through.",
		folderFeature("col_" .. id, getFolder, "CanCollide", false)
	)
end
colToggle("ColHedges", "Pass Through Hedges", function()
	return W("Suki", "Hedges")
end)
colToggle("ColStones", "Pass Through Stones", function()
	return W("Suki", "Stones")
end)
colToggle("ColGreens", "Pass Through Plants", function()
	return W("Suki", "Greens")
end)
colToggle("ColProps", "Pass Through Props", function()
	return W("Suki", "Props")
end)
colToggle("ColBagsakan", "Pass Through Bagsakan Goods", function()
	return W("Suki", "Bagsakan")
end)
colToggle("ColTambayan", "Pass Through Tambayan Chairs", function()
	return W("Suki", "Tambayan")
end)

-- Character state
tickTog(MoveC, "AntiSit", "Anti-Sit", "Stands you back up whenever you sit.", function()
	local h = hum()
	if h and h.Sit then
		h.Sit = false
	end
end)

local FallStates = {
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.PlatformStanding,
}
tog(MoveC, "NoRagdoll", "No Ragdoll / Fall-Down", "Disables knock-down states.", function(on)
	local h = hum()
	if h then
		for _, s in ipairs(FallStates) do
			h:SetStateEnabled(s, not on)
		end
	end
end)

tickTog(MoveC, "GodStand", "Keep Health Full (client display)", "Client-only; the server still decides damage.", function()
	local h = hum()
	if h and h.Health < h.MaxHealth and h.Health > 0 then
		h.Health = h.MaxHealth
	end
end)

tickTog(MoveC, "HideSelf", "Hide My Character", "Local transparency only.", function()
	if LP.Character then
		for _, p in ipairs(LP.Character:GetDescendants()) do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 1
			end
		end
	end
end, function()
	if LP.Character then
		for _, p in ipairs(LP.Character:GetDescendants()) do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 0
			end
		end
	end
end)

tickTog(MoveC, "RainbowSelf", "Rainbow Character (local)", "Recolors your parts on your screen.", function()
	if LP.Character then
		local c = Color3.fromHSV((os.clock() % 4) / 4, 0.8, 1)
		for _, p in ipairs(LP.Character:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				p.Color = c
			end
		end
	end
end)

btn(MoveC, "Stop All Animations", function()
	local h = hum()
	local a = h and h:FindFirstChildOfClass("Animator")
	if a then
		for _, t in ipairs(a:GetPlayingAnimationTracks()) do
			t:Stop()
		end
	end
end)
btn(MoveC, "Reset Character", function()
	local h = hum()
	if h then
		h.Health = 0
	end
end)
btn(MoveC, "Sit / Stand Toggle", function()
	local h = hum()
	if h then
		h.Sit = not h.Sit
	end
end)
btn(MoveC, "Unequip Tools", function()
	local h = hum()
	if h then
		h:UnequipTools()
	end
end)

-- Positions & tools
local Slots = {}
MoveD:AddDropdown("SlotPick", { Values = { "1", "2", "3", "4", "5" }, Default = 1, Text = "Position Slot" })
btn(MoveD, "Save Position To Slot", function()
	local r = root()
	if r then
		Slots[Options.SlotPick.Value] = r.CFrame
		notify("Saved", "Position stored in slot " .. tostring(Options.SlotPick.Value))
	end
end)
btn(MoveD, "Teleport To Slot", function()
	local r, cf = root(), Slots[Options.SlotPick.Value]
	if r and cf then
		r.CFrame = cf
	else
		notify("Empty slot", "Save a position there first.")
	end
end)

local ClickTool
btn(MoveD, "Give Click-TP Tool", function()
	local bp = LP:FindFirstChildOfClass("Backpack")
	if not bp or (ClickTool and ClickTool.Parent) then
		return
	end
	ClickTool = Instance.new("Tool")
	ClickTool.Name = "Click TP"
	ClickTool.RequiresHandle = false
	ClickTool.CanBeDropped = false
	ClickTool.Activated:Connect(function()
		local m = LP:GetMouse()
		if m and m.Hit then
			tpTo(m.Hit.Position)
		end
	end)
	ClickTool.Parent = bp
end, "Equip it and tap/click a spot to teleport there.")

-- Fix for respawn: clear per-character state
connect(LP.CharacterAdded, function()
	FlyBV = nil
	Saved.Walk, Saved.Jump, Saved.Hip = nil, nil, nil
end)

----------------------------------------------------------------------
-- TELEPORTS
----------------------------------------------------------------------
local TeleA = Tabs.Tele:AddLeftGroupbox("Suki Map", "map")
local TeleB = Tabs.Tele:AddLeftGroupbox("Players", "users")
local TeleC = Tabs.Tele:AddRightGroupbox("Neighbors & NPCs", "contact")
local TeleD = Tabs.Tele:AddRightGroupbox("Nearest Thing", "crosshair")

local Locs = {
	{ "Street Spawn", function() return W("Suki", "StreetSpawn") end },
	{ "Stall 1", function() return W("Suki", "Stalls", "Stall1") end },
	{ "Stall 2", function() return W("Suki", "Stalls", "Stall2") end },
	{ "Stall 3", function() return W("Suki", "Stalls", "Stall3") end },
	{ "Stall 4", function() return W("Suki", "Stalls", "Stall4") end },
	{ "Stall 5", function() return W("Suki", "Stalls", "Stall5") end },
	{ "Stall 6", function() return W("Suki", "Stalls", "Stall6") end },
	{ "Bagsakan (wholesale yard)", function() return W("Suki", "Bagsakan") end },
	{ "Hardware", function() return W("Suki", "Hardware") end },
	{ "Peralco (electric office)", function() return W("Suki", "Peralco") end },
	{ "Kuryente (transformers)", function() return W("Suki", "Kuryente") end },
	{ "Tambayan (hangout)", function() return W("Suki", "Tambayan") end },
	{ "Hall", function() return W("Suki", "Hall") end },
	{ "Leaderboards", function() return W("Suki", "Leaderboards") end },
	{ "Winners Podium", function() return W("Suki", "Winners") end },
	{ "Greens (plants)", function() return W("Suki", "Greens") end },
	{ "Stones", function() return W("Suki", "Stones") end },
	{ "Screen", function() return W("Suki", "Screen") end },
	{ "Street", function() return W("Suki", "Street") end },
	{ "Props (bikes, chickens)", function() return W("Suki", "Props") end },
	{ "Coins Folder", function() return W("SukiCoins") end },
	{ "Guide Arrow", function() return W("GuideArrow") end },
}
local LocNames = {}
for _, l in ipairs(Locs) do
	LocNames[#LocNames + 1] = l[1]
end

TeleA:AddDropdown("LocPick", { Values = LocNames, Default = 1, Text = "Destination" })
btn(TeleA, "Teleport To Destination", function()
	for _, l in ipairs(Locs) do
		if l[1] == Options.LocPick.Value then
			local p = worldPos(l[2]())
			if p then
				tpTo(p, Vector3.new(0, 6, 0))
			else
				notify("Not loaded", l[1] .. " is empty or streamed out. Walk closer and retry.", 4)
			end
			return
		end
	end
end)

TeleA:AddDropdown("SpawnPick", { Values = { "(press refresh)" }, Default = 1, Text = "Spawn Points" })
local SpawnMap = {}
local function refreshSpawns()
	SpawnMap = {}
	local names = {}
	for sp in pairs(Spawns) do
		local label = sp.Name .. " @ " .. math.floor(sp.Position.X) .. "," .. math.floor(sp.Position.Z)
		SpawnMap[label] = sp
		names[#names + 1] = label
	end
	table.sort(names)
	if #names == 0 then
		names = { "(none found)" }
	end
	Options.SpawnPick:SetValues(names)
end
btn(TeleA, "Refresh Spawn Points", refreshSpawns)
btn(TeleA, "Teleport To Spawn Point", function()
	local sp = SpawnMap[Options.SpawnPick.Value]
	if sp then
		tpTo(sp.Position, Vector3.new(0, 5, 0))
	end
end)

-- Players -------------------------------------------------------------
local function playerNames()
	local t = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			t[#t + 1] = p.Name
		end
	end
	table.sort(t)
	if #t == 0 then
		t = { "(nobody else here)" }
	end
	return t
end
local function pickedPlayer()
	local n = Options.PlayerPick and Options.PlayerPick.Value
	return type(n) == "string" and Players:FindFirstChild(n) or nil
end

TeleB:AddDropdown("PlayerPick", { Values = playerNames(), Default = 1, Text = "Player" })
local function refreshPlayers()
	if Options.PlayerPick then
		Options.PlayerPick:SetValues(playerNames())
	end
end
connect(Players.PlayerAdded, refreshPlayers)
connect(Players.PlayerRemoving, function()
	task.defer(refreshPlayers)
end)
btn(TeleB, "Refresh Player List", refreshPlayers)
btn(TeleB, "Teleport To Player", function()
	local p = pickedPlayer()
	local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if r then
		tpTo(r.Position, Vector3.new(3, 3, 0))
	else
		notify("Player", "Pick a player whose character is loaded.")
	end
end)
tickTog(TeleB, "FollowPlayer", "Follow Player", "Keeps you next to them.", throttle(0.15, function()
	local p = pickedPlayer()
	local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if r then
		tpTo((r.CFrame * CFrame.new(0, 0, val("FollowDist", 5))).Position, Vector3.new(0, 2, 0))
	end
end))
sld(TeleB, "FollowDist", "Follow Distance", 2, 30, 5, 0, nil, " st")
tickTog(TeleB, "SpectatePlayer", "Spectate Player", "Camera follows them.", function()
	local p = pickedPlayer()
	local h = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if h then
		Workspace.CurrentCamera.CameraSubject = h
	end
end, function()
	local h = hum()
	if h then
		Workspace.CurrentCamera.CameraSubject = h
	end
end)
btn(TeleB, "Copy Player UserId", function()
	local p = pickedPlayer()
	if p then
		copy(tostring(p.UserId))
	end
end)
btn(TeleB, "Show Player Info", function()
	local p = pickedPlayer()
	if p then
		notify(p.DisplayName, "@" .. p.Name .. " | id " .. p.UserId .. " | age " .. p.AccountAge .. "d", 6)
	end
end)

-- NPCs ------------------------------------------------------------------
local NPCMap = {}
TeleC:AddDropdown("NPCPick", { Values = { "(press refresh)" }, Default = 1, Text = "Neighbor / NPC" })
local function refreshNPCs()
	NPCMap = {}
	local names = {}
	local function add(folderName, tag)
		for i, m in ipairs(children(W(folderName))) do
			if i > 120 then
				break
			end
			local label = tag .. ": " .. m.Name .. " #" .. i
			NPCMap[label] = m
			names[#names + 1] = label
		end
	end
	add("SukiPeople", "Neighbor")
	add("SukiAmbient", "Ambient")
	table.sort(names)
	if #names == 0 then
		names = { "(none loaded)" }
	end
	Options.NPCPick:SetValues(names)
end
btn(TeleC, "Refresh NPC List", refreshNPCs)
btn(TeleC, "Teleport To NPC", function()
	local m = NPCMap[Options.NPCPick.Value]
	local p = m and worldPos(m)
	if p then
		tpTo(p, Vector3.new(3, 3, 0))
	end
end)
tickTog(TeleC, "FollowNPC", "Follow NPC", "Stays beside the selected NPC.", throttle(0.2, function()
	local m = NPCMap[Options.NPCPick.Value]
	local p = m and worldPos(m)
	if p then
		tpTo(p, Vector3.new(4, 3, 0))
	end
end))
btn(TeleC, "Print NPC Attributes To Console", function()
	local m = NPCMap[Options.NPCPick.Value]
	if not m then
		return
	end
	print("--- " .. m:GetFullName() .. " ---")
	for k, v in pairs(m:GetAttributes()) do
		print(k, v)
	end
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("ValueBase") then
			print(c.Name, c.Value)
		end
	end
	notify("NPC", "Attributes printed to console.")
end)

-- Nearest thing ---------------------------------------------------------
local NearKinds = {
	"Seat",
	"Proximity Prompt",
	"Click Detector",
	"Coin",
	"Neighbor NPC",
	"Ambient NPC",
	"Stall",
	"Chicken",
	"Bike / Trike",
	"Display",
	"Kahon (box)",
	"Rice Sack",
	"Drum",
	"Cart",
	"Transformer",
	"Plant",
	"Monobloc Chair",
	"Other Player",
}
local function nearestList(kind)
	if kind == "Seat" then
		return keysOf(Seats)
	elseif kind == "Proximity Prompt" then
		return keysOf(Prompts)
	elseif kind == "Click Detector" then
		return keysOf(Clicks)
	elseif kind == "Coin" then
		return children(W("SukiCoins"))
	elseif kind == "Neighbor NPC" then
		return children(W("SukiPeople"))
	elseif kind == "Ambient NPC" then
		return children(W("SukiAmbient"))
	elseif kind == "Stall" then
		return children(W("Suki", "Stalls"))
	elseif kind == "Chicken" then
		return children(W("Suki", "Props"), nameHas("chicken"))
	elseif kind == "Bike / Trike" then
		return children(W("Suki", "Props"), nameHas("bike", "trike"))
	elseif kind == "Display" then
		return children(W("Suki", "Props"), nameHas("display"))
	elseif kind == "Kahon (box)" then
		return children(W("Suki", "Bagsakan"), nameHas("kahon"))
	elseif kind == "Rice Sack" then
		return children(W("Suki", "Bagsakan"), nameHas("sackrice"))
	elseif kind == "Drum" then
		return children(W("Suki", "Bagsakan"), nameHas("drum"))
	elseif kind == "Cart" then
		return children(W("Suki", "Bagsakan"), nameHas("cart"))
	elseif kind == "Transformer" then
		return children(W("Suki", "Kuryente"), nameHas("transformer"))
	elseif kind == "Plant" then
		return children(W("Suki", "Greens"))
	elseif kind == "Monobloc Chair" then
		return children(W("Suki", "Tambayan"))
	elseif kind == "Other Player" then
		local t = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then
				t[#t + 1] = p.Character
			end
		end
		return t
	end
	return {}
end
TeleD:AddDropdown("NearKind", { Values = NearKinds, Default = 1, Text = "What" })
btn(TeleD, "Teleport To Nearest", function()
	local inst, d = nearest(nearestList(Options.NearKind.Value))
	if inst then
		tpTo(worldPos(inst), Vector3.new(0, 4, 0))
		notify("Teleported", inst.Name .. " (" .. math.floor(d) .. " studs away)")
	else
		notify("Nothing found", "No '" .. tostring(Options.NearKind.Value) .. "' loaded near you.")
	end
end)
btn(TeleD, "Print Nearest 10 To Console", function()
	local mp = myPos()
	local list = nearestList(Options.NearKind.Value)
	local rows = {}
	for _, i in ipairs(list) do
		local p = worldPos(i)
		if p and mp then
			rows[#rows + 1] = { i, (p - mp).Magnitude }
		end
	end
	table.sort(rows, function(a, b)
		return a[2] < b[2]
	end)
	for k = 1, math.min(10, #rows) do
		print(string.format("%5.0f st  %s", rows[k][2], rows[k][1]:GetFullName()))
	end
end)
btn(TeleD, "Sit In Nearest Seat", function()
	local seat = nearest(keysOf(Seats))
	if seat then
		tpTo(seat.Position, Vector3.new(0, 2.5, 0))
	end
end)

----------------------------------------------------------------------
-- INTERACT (prompts, click detectors, coins)
----------------------------------------------------------------------
local IntA = Tabs.Inter:AddLeftGroupbox("Proximity Prompts", "mouse-pointer-click")
local IntB = Tabs.Inter:AddRightGroupbox("Click Detectors & Seats", "pointer")
local IntC = Tabs.Inter:AddRightGroupbox("Coins (SukiCoins)", "coins")

local function dyn(sliderId, default, fn)
	local acc = 0
	return function(dt)
		acc += dt
		if acc >= val(sliderId, default) then
			acc = 0
			fn()
		end
	end
end

tog(IntA, "InstantPrompts", "Instant Prompts", "HoldDuration = 0 on every prompt.", setFeature("instant", Prompts, "HoldDuration", 0))
tog(IntA, "LongReach", "Longer Prompt Reach", "Multiplies MaxActivationDistance.", setFeature("reach", Prompts, "MaxActivationDistance", function(orig)
	return orig * val("ReachMult", 3)
end))
sld(IntA, "ReachMult", "Reach Multiplier", 1, 12, 3, 1, function()
	if isOn("LongReach") and Reapply.reach then
		Reapply.reach()
	end
end, "x")
tog(IntA, "NoLOS", "Ignore Line Of Sight", "RequiresLineOfSight = false.", setFeature("los", Prompts, "RequiresLineOfSight", false))
tog(IntA, "ForceEnable", "Force-Enable Prompts", "Turns disabled prompts back on locally.", setFeature("penable", Prompts, "Enabled", true))

local function actionOf(p)
	local a = p.ActionText
	if a == "" then
		a = "(blank)"
	end
	return a
end
local function actionAllowed(p)
	local sel = Options.ActionFilter and Options.ActionFilter.Value
	if type(sel) ~= "table" then
		return true
	end
	local any = false
	for _, v in pairs(sel) do
		if v then
			any = true
			break
		end
	end
	return (not any) or sel[actionOf(p)] == true
end
IntA:AddDropdown("ActionFilter", { Values = { "(press refresh)" }, Default = nil, Multi = true, Text = "Only These Actions" })
IntA:AddDropdown("ActionPick", { Values = { "(press refresh)" }, Default = 1, Text = "Teleport By Action" })
local function refreshActions()
	local seen, vals = {}, {}
	for p in pairs(Prompts) do
		local a = actionOf(p)
		if not seen[a] then
			seen[a] = true
			vals[#vals + 1] = a
		end
	end
	table.sort(vals)
	if #vals == 0 then
		vals = { "(none yet)" }
	end
	Options.ActionFilter:SetValues(vals)
	Options.ActionPick:SetValues(vals)
	notify("Prompts", #vals .. " different actions found.")
end
btn(IntA, "Refresh Action Lists", refreshActions)
btn(IntA, "Teleport To Nearest Prompt With Action", function()
	local list = {}
	for p in pairs(Prompts) do
		if actionOf(p) == Options.ActionPick.Value then
			list[#list + 1] = p
		end
	end
	local p = nearest(list)
	if p then
		tpTo(worldPos(p), Vector3.new(0, 3, 3))
	else
		notify("Nothing", "No prompt with that action is loaded.")
	end
end)

local function promptsInRange(radius)
	local out, mp = {}, myPos()
	if not mp then
		return out
	end
	for p in pairs(Prompts) do
		if p.Enabled and actionAllowed(p) then
			local pp = worldPos(p)
			if pp and (pp - mp).Magnitude <= radius then
				out[#out + 1] = p
			end
		end
	end
	return out
end
local function firePrompt(p)
	if fireproximityprompt then
		fireproximityprompt(p)
	else
		notify("Executor", "fireproximityprompt is not available here.")
	end
end

tickTog(IntA, "AutoPrompt", "Auto-Trigger Nearby Prompts", "Fires prompts in range (respects action filter).", dyn("PromptInterval", 0.6, function()
	local list = promptsInRange(val("PromptRadius", 12))
	for k = 1, math.min(#list, val("PromptBurst", 3)) do
		firePrompt(list[k])
	end
end))
sld(IntA, "PromptRadius", "Trigger Radius", 3, 60, 12, 0, nil, " st")
sld(IntA, "PromptInterval", "Trigger Interval", 0.1, 5, 0.6, 1, nil, " s")
sld(IntA, "PromptBurst", "Prompts Per Trigger", 1, 10, 3, 0)
btn(IntA, "Trigger Nearest Prompt", function()
	local p = nearest(promptsInRange(60))
	if p then
		firePrompt(p)
	else
		notify("Prompts", "None in range.")
	end
end)
btn(IntA, "Trigger All Prompts In Range", function()
	for _, p in ipairs(promptsInRange(val("PromptRadius", 12))) do
		firePrompt(p)
	end
end)
btn(IntA, "Print All Prompt Actions To Console", function()
	for p in pairs(Prompts) do
		print(string.format("[%s] %s / %s  <- %s", tostring(p.Enabled), p.ObjectText, p.ActionText, p:GetFullName()))
	end
end)

-- Click detectors
tog(IntB, "ClickReach", "Longer Click Reach", "Multiplies ClickDetector distance.", setFeature("clickreach", Clicks, "MaxActivationDistance", function(orig)
	return orig * val("ClickMult", 3)
end))
sld(IntB, "ClickMult", "Click Reach Multiplier", 1, 12, 3, 1, function()
	if isOn("ClickReach") and Reapply.clickreach then
		Reapply.clickreach()
	end
end, "x")
local function clicksInRange(radius)
	local out, mp = {}, myPos()
	if mp then
		for c in pairs(Clicks) do
			local p = worldPos(c)
			if p and (p - mp).Magnitude <= radius then
				out[#out + 1] = c
			end
		end
	end
	return out
end
tickTog(IntB, "AutoClick", "Auto-Click Nearby Detectors", "Fires ClickDetectors in range.", dyn("ClickInterval", 0.8, function()
	if not fireclickdetector then
		return
	end
	local list = clicksInRange(val("ClickRadius", 12))
	for k = 1, math.min(#list, 4) do
		fireclickdetector(list[k])
	end
end))
sld(IntB, "ClickRadius", "Click Radius", 3, 60, 12, 0, nil, " st")
sld(IntB, "ClickInterval", "Click Interval", 0.1, 5, 0.8, 1, nil, " s")
btn(IntB, "Click Nearest Detector", function()
	local c = nearest(clicksInRange(60))
	if c and fireclickdetector then
		fireclickdetector(c)
	else
		notify("Click", "None in range, or fireclickdetector missing.")
	end
end)
btn(IntB, "Print Detector Count By Parent Name", function()
	local counts = {}
	for c in pairs(Clicks) do
		local n = c.Parent and c.Parent.Name or "?"
		counts[n] = (counts[n] or 0) + 1
	end
	for n, k in pairs(counts) do
		print(n, k)
	end
end)

-- Coins
IntC:AddDropdown("CoinMethod", { Values = { "Touch", "Teleport" }, Default = 1, Text = "Collect Method" })
local function coinParts()
	local out = {}
	for _, c in ipairs(children(W("SukiCoins"))) do
		if c:IsA("BasePart") then
			out[#out + 1] = c
		else
			local p = c:FindFirstChildWhichIsA("BasePart", true)
			if p then
				out[#out + 1] = p
			end
		end
	end
	return out
end
local function collectCoin(part)
	local r = root()
	if not r then
		return
	end
	if val("CoinMethod", "Touch") == "Touch" and firetouchinterest then
		firetouchinterest(r, part, 0)
		firetouchinterest(r, part, 1)
	else
		task.spawn(function()
			local cf = r.CFrame
			r.CFrame = part.CFrame
			task.wait(0.06)
			if r.Parent then
				r.CFrame = cf
			end
		end)
	end
end
local function collectCoinsInRange()
	local mp = myPos()
	local n = 0
	for _, part in ipairs(coinParts()) do
		if mp and (part.Position - mp).Magnitude <= val("CoinRadius", 150) then
			collectCoin(part)
			n += 1
			if n >= 6 then
				break
			end
		end
	end
	return n
end
tickTog(IntC, "AutoCoins", "Auto-Collect Coins", "Collects coins that spawn in Workspace.SukiCoins.", dyn("CoinInterval", 0.4, collectCoinsInRange))
sld(IntC, "CoinRadius", "Coin Radius", 10, 600, 150, 0, nil, " st")
sld(IntC, "CoinInterval", "Coin Interval", 0.1, 3, 0.4, 1, nil, " s")
btn(IntC, "Collect Coins Now", function()
	notify("Coins", collectCoinsInRange() .. " coin(s) targeted.")
end)
btn(IntC, "Count Coins On Map", function()
	notify("Coins", #coinParts() .. " coin part(s) loaded.")
end)

----------------------------------------------------------------------
-- VISUALS: ESP
----------------------------------------------------------------------
local VisA = Tabs.Vis:AddLeftGroupbox("ESP: People & Animals", "users")
local VisB = Tabs.Vis:AddLeftGroupbox("ESP: Map Objects", "box")
local VisC = Tabs.Vis:AddRightGroupbox("ESP Style", "palette")
local VisD = Tabs.Vis:AddRightGroupbox("Camera", "camera")

local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "SukiHubESP"
ESPFolder.Parent = guiParent()

local ESPObjs, ESPCats, HLCount = {}, {}, 0

local function adorneePart(inst)
	if inst:IsA("BasePart") then
		return inst
	elseif inst:IsA("Attachment") then
		return inst.Parent
	elseif inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then
		local p = inst.Parent
		if p and p:IsA("Attachment") then
			p = p.Parent
		end
		if p and p:IsA("BasePart") then
			return p
		end
		return p and p:FindFirstChildWhichIsA("BasePart", true)
	elseif inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function clearESP(inst)
	local o = ESPObjs[inst]
	if not o then
		return
	end
	pcall(function()
		o.bb:Destroy()
	end)
	if o.hl then
		pcall(function()
			o.hl:Destroy()
		end)
		HLCount -= 1
	end
	ESPObjs[inst] = nil
end

local function addESP(inst, cat)
	local part = adorneePart(inst)
	if not part then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Adornee = part
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(190, 46)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.LightInfluence = 0
	bb.Parent = ESPFolder
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.TextSize = 13
	tl.Font = Enum.Font.GothamBold
	tl.TextStrokeTransparency = 0.3
	tl.TextColor3 = cat.color
	tl.Text = ""
	tl.Parent = bb
	local hl
	if HLCount < 28 and isOn("ESPHighlight") then
		hl = Instance.new("Highlight")
		hl.Adornee = (inst:IsA("Model") or inst:IsA("BasePart")) and inst or part
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillColor = cat.color
		hl.OutlineColor = cat.color
		hl.Parent = ESPFolder
		HLCount += 1
	end
	ESPObjs[inst] = { bb = bb, tl = tl, hl = hl, part = part, cat = cat }
end

local function espLabel(inst)
	local base = inst.Name
	if inst:IsA("ProximityPrompt") then
		base = (inst.ObjectText ~= "" and (inst.ObjectText .. " - ") or "") .. inst.ActionText
	elseif inst:IsA("Model") then
		local pl = Players:GetPlayerFromCharacter(inst)
		if pl then
			base = pl.DisplayName
		end
	end
	if isOn("ESPAttrs") then
		local n, s = 0, {}
		for k, v in pairs(inst:GetAttributes()) do
			n += 1
			if n > 3 then
				break
			end
			s[#s + 1] = k .. "=" .. tostring(v)
		end
		if #s > 0 then
			base = base .. "\n" .. table.concat(s, " ")
		end
	end
	return base
end

local function espRefresh()
	local mp = myPos()
	local maxD = val("ESPDist", 400) * 1.15
	local want = {}
	for _, cat in pairs(ESPCats) do
		if cat.on then
			local n = 0
			for _, inst in ipairs(cat.get()) do
				local p = mp and worldPos(inst)
				if not mp or (p and (p - mp).Magnitude <= maxD) then
					want[inst] = cat
					n += 1
					if n >= 200 then
						break
					end
				end
			end
		end
	end
	for inst in pairs(ESPObjs) do
		if not want[inst] or not inst.Parent then
			clearESP(inst)
		end
	end
	for inst, cat in pairs(want) do
		if not ESPObjs[inst] then
			addESP(inst, cat)
		end
	end
end

local function espPaint()
	local mp = myPos()
	local maxD = val("ESPDist", 400)
	local rainbow = isOn("ESPRainbow")
	local showNames, showDist = isOn("ESPNames"), isOn("ESPDistance")
	local fillT = val("ESPFillT", 0.6)
	local rc = Color3.fromHSV((os.clock() % 5) / 5, 0.85, 1)
	for inst, o in pairs(ESPObjs) do
		if not (o.part and o.part.Parent) then
			clearESP(inst)
		else
			local d = mp and (o.part.Position - mp).Magnitude or 0
			local vis = d <= maxD
			local col = rainbow and rc or o.cat.color
			o.bb.Enabled = vis and showNames
			if vis and showNames then
				o.tl.TextColor3 = col
				o.tl.Text = espLabel(inst) .. (showDist and ("\n[" .. math.floor(d) .. " st]") or "")
			end
			if o.hl then
				o.hl.Enabled = vis
				o.hl.FillColor = col
				o.hl.OutlineColor = col
				o.hl.FillTransparency = fillT
			end
		end
	end
end

do
	local accR, accP = 99, 99
	Ticks.ESP = function(dt)
		accR += dt
		accP += dt
		if accR >= 1.2 then
			accR = 0
			pcall(espRefresh)
		end
		if accP >= 0.15 then
			accP = 0
			pcall(espPaint)
		end
	end
end

local espIndex = 0
local function espCat(gb, id, text, getter)
	espIndex += 1
	ESPCats[id] = {
		get = getter,
		on = false,
		color = Color3.fromHSV(((espIndex * 0.137) % 1), 0.75, 1),
	}
	local t = tog(gb, "ESP_" .. id, text, nil, function(on)
		ESPCats[id].on = on
		pcall(espRefresh)
	end)
	pcall(function()
		t:AddColorPicker("ESPCol_" .. id, {
			Default = ESPCats[id].color,
			Title = text .. " color",
			Callback = function(c)
				ESPCats[id].color = c
			end,
		})
	end)
end

local function otherChars()
	local t = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			t[#t + 1] = p.Character
		end
	end
	return t
end

espCat(VisA, "Players", "Other Players", otherChars)
espCat(VisA, "Neighbors", "Neighbors / Customers", function()
	return children(W("SukiPeople"))
end)
espCat(VisA, "Ambient", "Ambient Crowd", function()
	return children(W("SukiAmbient"))
end)
espCat(VisA, "Chickens", "Chickens", function()
	return children(W("Suki", "Props"), nameHas("chicken"))
end)
espCat(VisA, "Winners", "Leaderboard Winners", function()
	return children(W("Suki", "Winners"))
end)

espCat(VisB, "Stalls", "Stalls", function()
	return children(W("Suki", "Stalls"))
end)
espCat(VisB, "Prompts", "Interaction Prompts", function()
	return keysOf(Prompts)
end)
espCat(VisB, "Clicks", "Click Detectors", function()
	return keysOf(Clicks)
end)
espCat(VisB, "Seats", "Seats", function()
	return keysOf(Seats)
end)
espCat(VisB, "Coins", "Coins", function()
	return children(W("SukiCoins"))
end)
espCat(VisB, "Kahon", "Kahon (boxes)", function()
	return children(W("Suki", "Bagsakan"), nameHas("kahon"))
end)
espCat(VisB, "Sacks", "Rice Sacks", function()
	return children(W("Suki", "Bagsakan"), nameHas("sackrice"))
end)
espCat(VisB, "Drums", "Drums", function()
	return children(W("Suki", "Bagsakan"), nameHas("drum"))
end)
espCat(VisB, "Carts", "Carts", function()
	return children(W("Suki", "Bagsakan"), nameHas("cart"))
end)
espCat(VisB, "Bikes", "Bikes / Trikes", function()
	return children(W("Suki", "Props"), nameHas("bike", "trike"))
end)
espCat(VisB, "Displays", "Displays", function()
	return children(W("Suki", "Props"), nameHas("display"))
end)
espCat(VisB, "Transformers", "Transformers (Kuryente)", function()
	return children(W("Suki", "Kuryente"), nameHas("transformer"))
end)
espCat(VisB, "Plants", "Plants (Greens)", function()
	return children(W("Suki", "Greens"))
end)
espCat(VisB, "Stones", "Stones", function()
	return children(W("Suki", "Stones"))
end)
espCat(VisB, "Hedges", "Hedges", function()
	return children(W("Suki", "Hedges"))
end)
espCat(VisB, "Tambayan", "Tambayan Chairs", function()
	return children(W("Suki", "Tambayan"))
end)
espCat(VisB, "Hardware", "Hardware Area", function()
	return children(W("Suki", "Hardware"))
end)
espCat(VisB, "Peralco", "Peralco Area", function()
	return children(W("Suki", "Peralco"))
end)
espCat(VisB, "Boards", "Leaderboards", function()
	return children(W("Suki", "Leaderboards"))
end)
espCat(VisB, "Spawns", "Spawn Points", function()
	return keysOf(Spawns)
end)

VisC:AddToggle("ESPNames", { Text = "Show Labels", Default = true })
VisC:AddToggle("ESPDistance", { Text = "Show Distance", Default = true })
VisC:AddToggle("ESPHighlight", { Text = "Highlight Outline (max 28)", Default = true })
VisC:AddToggle("ESPAttrs", { Text = "Show Attributes In Label", Default = false, Tooltip = "Reveals customer/object data the game stores as attributes." })
VisC:AddToggle("ESPRainbow", { Text = "Rainbow Colors", Default = false })
sld(VisC, "ESPDist", "Max ESP Distance", 30, 2000, 400, 0, nil, " st")
sld(VisC, "ESPFillT", "Highlight Fill Transparency", 0, 1, 0.6, 2)
btn(VisC, "Enable All ESP", function()
	for id, t in pairs(Toggles) do
		if id:sub(1, 4) == "ESP_" then
			t:SetValue(true)
		end
	end
end)
btn(VisC, "Disable All ESP", function()
	for id, t in pairs(Toggles) do
		if id:sub(1, 4) == "ESP_" then
			t:SetValue(false)
		end
	end
end)

-- Camera --------------------------------------------------------------
tickTog(VisD, "FovOn", "Custom Field Of View", nil, function()
	local cam = Workspace.CurrentCamera
	if not Saved.Fov then
		Saved.Fov = cam.FieldOfView
	end
	cam.FieldOfView = val("FovVal", 90)
end, function()
	Workspace.CurrentCamera.FieldOfView = Saved.Fov or 70
	Saved.Fov = nil
end)
sld(VisD, "FovVal", "Field Of View", 30, 120, 90, 0)

tog(VisD, "ZoomOn", "Unlimited Zoom Range", "Raises max zoom, lowers min zoom.", function(on)
	if on then
		Saved.ZoomMax, Saved.ZoomMin = LP.CameraMaxZoomDistance, LP.CameraMinZoomDistance
		LP.CameraMaxZoomDistance = val("ZoomMax", 600)
		LP.CameraMinZoomDistance = 0.5
	else
		LP.CameraMaxZoomDistance = Saved.ZoomMax or 128
		LP.CameraMinZoomDistance = Saved.ZoomMin or 0.5
	end
end)
sld(VisD, "ZoomMax", "Max Zoom", 20, 2000, 600, 0, function(v)
	if isOn("ZoomOn") then
		LP.CameraMaxZoomDistance = v
	end
end, " st")

tickTog(VisD, "CamOffsetOn", "Camera Offset", "Shifts the camera relative to your head.", function()
	local h = hum()
	if h then
		h.CameraOffset = Vector3.new(0, val("CamY", 2), val("CamZ", 0))
	end
end, function()
	local h = hum()
	if h then
		h.CameraOffset = Vector3.zero
	end
end)
sld(VisD, "CamY", "Offset Height", -10, 30, 2, 1)
sld(VisD, "CamZ", "Offset Depth", -30, 30, 0, 1)

tog(VisD, "FirstPersonLock", "Lock First Person", nil, function(on)
	LP.CameraMode = on and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
end)
btn(VisD, "Reset Camera", function()
	local cam, h = Workspace.CurrentCamera, hum()
	cam.CameraType = Enum.CameraType.Custom
	if h then
		cam.CameraSubject = h
	end
end)

----------------------------------------------------------------------
-- WORLD: lighting, cleanup, hiding, audio, graphics
----------------------------------------------------------------------
local WorldA = Tabs.World:AddLeftGroupbox("Lighting", "sun")
local WorldB = Tabs.World:AddLeftGroupbox("Effects Cleanup", "sparkles")
local WorldC = Tabs.World:AddRightGroupbox("Hide Map Groups", "eye-off")
local WorldD = Tabs.World:AddRightGroupbox("Audio", "volume-2")
local WorldE = Tabs.World:AddRightGroupbox("Graphics & Performance", "cpu")

local LightSaved = {}
local function lsave(k)
	if LightSaved[k] == nil then
		LightSaved[k] = Lighting[k]
	end
end
local function lrestore(...)
	for _, k in ipairs({ ... }) do
		if LightSaved[k] ~= nil then
			Lighting[k] = LightSaved[k]
			LightSaved[k] = nil
		end
	end
end
local function lightKid(name)
	return Lighting:FindFirstChild(name)
end

tickTog(WorldA, "Fullbright", "Fullbright", "Bright ambient, no shadows.", function()
	for _, k in ipairs({ "Brightness", "Ambient", "OutdoorAmbient", "GlobalShadows" }) do
		lsave(k)
	end
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.new(1, 1, 1)
	Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
	Lighting.GlobalShadows = false
end, function()
	lrestore("Brightness", "Ambient", "OutdoorAmbient", "GlobalShadows")
end)

tickTog(WorldA, "NoFog", "Remove Fog", nil, function()
	lsave("FogEnd")
	lsave("FogStart")
	Lighting.FogEnd = 1e6
	Lighting.FogStart = 1e6
end, function()
	lrestore("FogEnd", "FogStart")
end)

tickTog(WorldA, "BrightOn", "Custom Brightness", nil, function()
	lsave("Brightness")
	Lighting.Brightness = val("BrightVal", 3)
end, function()
	lrestore("Brightness")
end)
sld(WorldA, "BrightVal", "Brightness", 0, 10, 3, 1)

tickTog(WorldA, "ExposureOn", "Custom Exposure", nil, function()
	lsave("ExposureCompensation")
	Lighting.ExposureCompensation = val("ExposureVal", 0.5)
end, function()
	lrestore("ExposureCompensation")
end)
sld(WorldA, "ExposureVal", "Exposure", -3, 3, 0.5, 1)

tickTog(WorldA, "ClockOn", "Custom Time Of Day", nil, function()
	lsave("ClockTime")
	Lighting.ClockTime = val("ClockVal", 14)
end, function()
	lrestore("ClockTime")
end)
sld(WorldA, "ClockVal", "Clock Time", 0, 24, 14, 1)

do
	local frozen
	tickTog(WorldA, "FreezeTime", "Freeze Time", "Locks the clock where it is now.", function()
		frozen = frozen or Lighting.ClockTime
		Lighting.ClockTime = frozen
	end, function()
		frozen = nil
	end)
end
btn(WorldA, "Set Noon", function()
	Lighting.ClockTime = 12
end)
btn(WorldA, "Set Midnight", function()
	Lighting.ClockTime = 0
end)

tog(WorldA, "NoAtmo", "Disable Atmosphere Haze", nil, function(on)
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("Atmosphere") then
			if on then
				ovr1("atmo", c, "Density", 0)
			end
		end
	end
	if not on then
		unovr("atmo", "Density")
	end
end)
tog(WorldA, "NoSukiGrade", "Disable SukiGrade Color Filter", "ColorCorrection named SukiGrade.", function(on)
	local e = lightKid("SukiGrade")
	if e then
		if on then
			ovr1("sukigrade", e, "Enabled", false)
		else
			unovr("sukigrade", "Enabled")
		end
	end
end)
tog(WorldA, "NoWarSky", "Disable WarSky Filter", "ColorCorrection named WarSky (war event tint).", function(on)
	local e = lightKid("WarSky")
	if e then
		if on then
			ovr1("warsky", e, "Enabled", false)
		else
			unovr("warsky", "Enabled")
		end
	end
end)
tog(WorldA, "NoPostFX", "Disable All Post-Processing", "Blur, bloom, color correction, sun rays, depth of field.", function(on)
	for _, c in ipairs(Lighting:GetDescendants()) do
		if c:IsA("PostEffect") then
			if on then
				ovr1("postfx", c, "Enabled", false)
			end
		end
	end
	if not on then
		unovr("postfx", "Enabled")
	end
end)
tog(WorldA, "NoShadows", "Disable Global Shadows", nil, function(on)
	if on then
		lsave("GlobalShadows")
		Lighting.GlobalShadows = false
	else
		lrestore("GlobalShadows")
	end
end)

-- Effects cleanup
tog(WorldB, "NoEmitters", "Disable Particles (rain, dust, smoke)", nil, setFeature("emit", Emitters, "Enabled", false))
tog(WorldB, "NoBeams", "Hide Beams (power lines)", nil, setFeature("beam", Beams, "Enabled", false))
tog(WorldB, "NoLights", "Turn Off Map Lights", nil, setFeature("lights", Lights, "Enabled", false))
tog(WorldB, "BigLights", "Boost Light Range", nil, setFeature("lightrange", Lights, "Range", function(o)
	return o * val("LightMult", 2)
end))
sld(WorldB, "LightMult", "Light Range Multiplier", 1, 8, 2, 1, function()
	if isOn("BigLights") and Reapply.lightrange then
		Reapply.lightrange()
	end
end, "x")
tog(WorldB, "NoDecals", "Hide Decals & Textures", "Posters, stains, graffiti.", setFeature("decals", Decals, "Transparency", 1))
tog(WorldB, "NoSurfGuis", "Hide World Screens / Signs", "Disables SurfaceGuis.", setFeature("sgui", SGuis, "Enabled", false))
tog(WorldB, "NoBillboards", "Hide World Billboards", "Disables BillboardGuis in the map.", setFeature("bgui", BGuis, "Enabled", false))

-- Hide map groups (LocalTransparencyModifier = client-only)
local function hideToggle(id, text, getFolder)
	tog(WorldC, id, text, "Client-only invisibility for this group.", folderFeature("hide_" .. id, getFolder, "LocalTransparencyModifier", 1))
end
hideToggle("HideHedges", "Hide Hedges", function() return W("Suki", "Hedges") end)
hideToggle("HidePlants", "Hide Plants", function() return W("Suki", "Greens") end)
hideToggle("HideStones", "Hide Stones", function() return W("Suki", "Stones") end)
hideToggle("HideProps", "Hide Props", function() return W("Suki", "Props") end)
hideToggle("HideBagsakan", "Hide Bagsakan Goods", function() return W("Suki", "Bagsakan") end)
hideToggle("HideTambayan", "Hide Tambayan Chairs", function() return W("Suki", "Tambayan") end)
hideToggle("HideKuryente", "Hide Transformers & Poles", function() return W("Suki", "Kuryente") end)
hideToggle("HideNeighbors", "Hide Neighbors", function() return W("SukiPeople") end)
hideToggle("HideAmbient", "Hide Ambient Crowd", function() return W("SukiAmbient") end)
hideToggle("HideWinners", "Hide Winner Statues", function() return W("Suki", "Winners") end)
hideToggle("HideBase", "Hide Environment Base", function() return W("Environment_Base") end)
tickTog(WorldC, "HideOthers", "Hide Other Players", "Client-only.", throttle(0.4, function()
	for _, c in ipairs(otherChars()) do
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 1
			end
		end
	end
end), function()
	for _, c in ipairs(otherChars()) do
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 0
			end
		end
	end
end)

-- Audio
local function singleFeature(key, getInst, prop, value)
	local function apply()
		local i = getInst()
		if i then
			ovr1(key, i, prop, value)
		end
	end
	Reapply[key] = apply
	return function(on)
		if on then
			apply()
		else
			unovr(key, prop)
		end
	end
end
local function radio()
	return SoundService:FindFirstChild("SukiRadio")
end
tog(WorldD, "MuteRadio", "Mute Street Radio", "SoundService.SukiRadio.", singleFeature("radiomute", radio, "Volume", 0))
tog(WorldD, "RadioVol", "Custom Radio Volume", nil, singleFeature("radiovol", radio, "Volume", function()
	return val("RadioVolVal", 0.5)
end))
sld(WorldD, "RadioVolVal", "Radio Volume", 0, 10, 0.5, 1, function()
	if isOn("RadioVol") and Reapply.radiovol then
		Reapply.radiovol()
	end
end)
tog(WorldD, "RadioSpeed", "Custom Radio Speed", nil, singleFeature("radiospeed", radio, "PlaybackSpeed", function()
	return val("RadioSpeedVal", 1.25)
end))
sld(WorldD, "RadioSpeedVal", "Radio Speed", 0.2, 3, 1.25, 2, function()
	if isOn("RadioSpeed") and Reapply.radiospeed then
		Reapply.radiospeed()
	end
end)
tog(WorldD, "MuteAll", "Mute Every Sound", nil, setFeature("muteall", Sounds, "Volume", 0))
tog(WorldD, "SoundScale", "Scale All Sound Volume", nil, setFeature("soundscale", Sounds, "Volume", function(o)
	return o * val("SoundMult", 0.3)
end))
sld(WorldD, "SoundMult", "Sound Multiplier", 0, 3, 0.3, 2, function()
	if isOn("SoundScale") and Reapply.soundscale then
		Reapply.soundscale()
	end
end, "x")

-- Graphics / performance
tog(WorldE, "LowQuality", "Lowest Render Quality", nil, function(on)
	pcall(function()
		local r = settings().Rendering
		if on then
			Saved.Quality = r.QualityLevel
			r.QualityLevel = Enum.QualityLevel.Level01
		elseif Saved.Quality then
			r.QualityLevel = Saved.Quality
		end
	end)
end)
tog(WorldE, "No3D", "Disable 3D Rendering (AFK saver)", "Black screen, near-zero GPU use.", function(on)
	RunService:Set3dRenderingEnabled(not on)
end)
sld(WorldE, "FpsCap", "FPS Cap (0 = unlimited)", 0, 240, 0, 0, function(v)
	if setfpscap then
		setfpscap(v)
	end
end)
btn(WorldE, "Apply FPS Preset", function()
	for _, id in ipairs({ "NoEmitters", "NoBeams", "NoDecals", "NoSurfGuis", "NoShadows", "LowQuality", "NoPostFX" }) do
		if Toggles[id] then
			Toggles[id]:SetValue(true)
		end
	end
	notify("FPS Preset", "Particles, beams, decals, signs, shadows, post-FX off.")
end)
btn(WorldE, "Undo FPS Preset", function()
	for _, id in ipairs({ "NoEmitters", "NoBeams", "NoDecals", "NoSurfGuis", "NoShadows", "LowQuality", "NoPostFX" }) do
		if Toggles[id] then
			Toggles[id]:SetValue(false)
		end
	end
end)

----------------------------------------------------------------------
-- GAME TOOLS
----------------------------------------------------------------------
local GameA = Tabs.Game:AddLeftGroupbox("Remote Spy (SukiRemotes)", "radio")
local GameB = Tabs.Game:AddLeftGroupbox("Player Data", "database")
local GameC = Tabs.Game:AddRightGroupbox("Live Stats", "activity")
local GameD = Tabs.Game:AddRightGroupbox("Utility", "wrench")
local GameE = Tabs.Game:AddRightGroupbox("Server", "server")
local GameF = Tabs.Game:AddLeftGroupbox("Chat & Interface", "message-square")

-- Remote spy: learn the real arguments of Tawad, Singil, Lista, AskUtang, Shop...
local Spy = { on = false, hooked = false, all = false, log = {}, counts = {}, watch = {}, block = {}, last = "(nothing captured yet)" }
local SpyRemotes = RS:FindFirstChild("SukiRemotes")

local function ser(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "string" then
		return string.format("%q", #v > 60 and (v:sub(1, 60) .. "...") or v)
	elseif t == "table" then
		if depth >= 2 then
			return "{...}"
		end
		local parts, n = {}, 0
		for k, x in pairs(v) do
			n += 1
			if n > 8 then
				parts[#parts + 1] = "..."
				break
			end
			parts[#parts + 1] = (type(k) == "number" and "" or ("[" .. tostring(k) .. "]=")) .. ser(x, depth + 1)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "Instance" then
		return v:GetFullName()
	end
	return tostring(v)
end

local function spyRecord(remote, method, args)
	local parts = {}
	for i = 1, args.n do
		parts[#parts + 1] = ser(args[i])
	end
	if args.n == 0 then
		parts[1] = "(no args)"
	end
	local line = string.format("[%0.1fs] %s:%s(%s)", os.clock() % 100000, remote.Name, method, table.concat(parts, ", "))
	Spy.log[#Spy.log + 1] = line
	if #Spy.log > 300 then
		table.remove(Spy.log, 1)
	end
	Spy.counts[remote.Name] = (Spy.counts[remote.Name] or 0) + 1
	Spy.last = line
	if isOn("SpyPrint") then
		print("[SukiSpy] " .. line)
	end
end

local function startSpy()
	if Spy.hooked then
		return true
	end
	if not (hookmetamethod and getnamecallmethod) then
		return false
	end
	local old
	local function handler(self, ...)
		local method = getnamecallmethod()
		if (method == "FireServer" or method == "InvokeServer") and (Spy.on or next(Spy.block) ~= nil) then
			local args = table.pack(...)
			local own = false
			if checkcaller then
				local okc, res = pcall(checkcaller)
				own = okc and res or false
			end
			if not own then
				local okr, isGame = pcall(function()
					return typeof(self) == "Instance" and SpyRemotes ~= nil and self.Parent == SpyRemotes
				end)
				if okr and isGame and Spy.block[self.Name] then
					return nil
				end
				if Spy.on then
					pcall(function()
						if typeof(self) == "Instance" and (Spy.all or isGame) and (next(Spy.watch) == nil or Spy.watch[self.Name]) then
							spyRecord(self, method, args)
						end
					end)
				end
			end
		end
		return old(self, ...)
	end
	local ok = pcall(function()
		old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(handler) or handler)
	end)
	Spy.hooked = ok and old ~= nil
	return Spy.hooked
end

tog(GameA, "SpyOn", "Capture Remote Calls", "Logs FireServer/InvokeServer made by the game's own scripts.", function(on)
	if on then
		if not startSpy() then
			notify("Remote Spy", "This executor can't hook __namecall.", 5)
			Toggles.SpyOn:SetValue(false)
			return
		end
		Spy.on = true
		notify("Remote Spy", "Now play normally: sell, haggle, collect debt, buy stock.", 5)
	else
		Spy.on = false
	end
end)
tog(GameA, "SpyAll", "Capture Every Remote (not just SukiRemotes)", nil, function(on)
	Spy.all = on
end)
tog(GameA, "SpyPrint", "Echo Each Call To Console", nil, function() end)
local SpyLabel = GameA:AddLabel("Last: (nothing captured yet)", true)
local SpyCount = GameA:AddLabel("Counts: -", true)
btn(GameA, "Copy Full Log", function()
	copy(table.concat(Spy.log, "\n"))
end)
btn(GameA, "Print Log To Console", function()
	for _, l in ipairs(Spy.log) do
		print(l)
	end
end)
btn(GameA, "Clear Log", function()
	Spy.log, Spy.counts, Spy.last = {}, {}, "(cleared)"
end)
btn(GameA, "List All SukiRemotes In Console", function()
	if not SpyRemotes then
		notify("Remotes", "ReplicatedStorage.SukiRemotes not found.")
		return
	end
	for _, r in ipairs(SpyRemotes:GetChildren()) do
		print(r.ClassName, r.Name)
	end
end)

-- Player data dumps -----------------------------------------------------
local function dumpObject(obj, label)
	print("=== " .. label .. " ===")
	for k, v in pairs(obj:GetAttributes()) do
		print("  attr", k, v)
	end
	for _, c in ipairs(obj:GetDescendants()) do
		if c:IsA("ValueBase") then
			print("  value", c:GetFullName(), c.Value)
		end
	end
end
btn(GameB, "Dump My Player Data", function()
	dumpObject(LP, "LocalPlayer")
	local ls = LP:FindFirstChild("leaderstats")
	if ls then
		dumpObject(ls, "leaderstats")
	end
	if LP.Character then
		dumpObject(LP.Character, "Character")
	end
	notify("Dump", "Printed to console (F9 or Delta console).")
end)
btn(GameB, "Dump Everyone's Leaderstats", function()
	for _, p in ipairs(Players:GetPlayers()) do
		local ls = p:FindFirstChild("leaderstats")
		if ls then
			local row = {}
			for _, v in ipairs(ls:GetChildren()) do
				if v:IsA("ValueBase") then
					row[#row + 1] = v.Name .. "=" .. tostring(v.Value)
				end
			end
			print(p.DisplayName, table.concat(row, "  "))
		end
	end
end)
btn(GameB, "Dump My PlayerGui Text", function()
	local pg = LP:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local n = 0
	for _, d in ipairs(pg:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.Text ~= "" then
			print(d:GetFullName(), "=", d.Text)
			n += 1
			if n >= 150 then
				break
			end
		end
	end
end)
btn(GameB, "Dump Workspace.Suki Child Counts", function()
	local s = W("Suki")
	if not s then
		return
	end
	for _, c in ipairs(s:GetChildren()) do
		print(c.Name, c.ClassName, #c:GetDescendants() .. " descendants")
	end
end)
btn(GameB, "Print Loaded Interaction Counts", function()
	local function count(t)
		local n = 0
		for _ in pairs(t) do
			n += 1
		end
		return n
	end
	notify(
		"Loaded",
		string.format(
			"%d prompts, %d click detectors, %d seats, %d coins%s",
			count(Prompts),
			count(Clicks),
			count(Seats),
			#children(W("SukiCoins")),
			ScanDone and "" or " (scan still running)"
		),
		6
	)
end)

-- Live stats --------------------------------------------------------------
local StatFPS = GameC:AddLabel("FPS: -")
local StatPing = GameC:AddLabel("Ping: -")
local StatPos = GameC:AddLabel("Position: -")
local StatSpd = GameC:AddLabel("Speed: -")
local StatPl = GameC:AddLabel("Players: -")
local StatUp = GameC:AddLabel("Server age: -")
local StatMem = GameC:AddLabel("Memory: -")
local StatVer = GameC:AddLabel("Place version: " .. tostring(game.PlaceVersion), true)
local fpsSmooth = 60
connect(RunService.RenderStepped, function(dt)
	if dt > 0 then
		fpsSmooth = fpsSmooth * 0.92 + (1 / dt) * 0.08
	end
end)
task.spawn(function()
	while not Library.Unloaded do
		pcall(function()
			StatFPS:SetText("FPS: " .. math.floor(fpsSmooth))
			local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			StatPing:SetText("Ping: " .. math.floor(ping) .. " ms")
			local r = root()
			if r then
				local p, v = r.Position, r.AssemblyLinearVelocity
				StatPos:SetText(string.format("Position: %d, %d, %d", p.X, p.Y, p.Z))
				StatSpd:SetText(string.format("Speed: %.1f st/s", Vector3.new(v.X, 0, v.Z).Magnitude))
			end
			StatPl:SetText("Players: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers)
			local t = math.floor(Workspace.DistributedGameTime)
			StatUp:SetText(string.format("Server age: %dm %ds", t // 60, t % 60))
			StatMem:SetText("Memory: " .. math.floor(Stats:GetTotalMemoryUsageMb()) .. " MB")
			SpyLabel:SetText("Last: " .. Spy.last)
			local rows = {}
			for n, c in pairs(Spy.counts) do
				rows[#rows + 1] = n .. " x" .. c
			end
			table.sort(rows)
			SpyCount:SetText("Counts: " .. (#rows > 0 and table.concat(rows, ", ") or "-"))
		end)
		task.wait(0.5)
	end
end)

-- Utility -------------------------------------------------------------------
tog(GameD, "AntiAFK", "Anti-AFK", "Stops the 20 minute idle kick.", function(on)
	if on and not Saved.AFKConn then
		Saved.AFKConn = LP.Idled:Connect(function()
			if isOn("AntiAFK") then
				local ok, VU = pcall(function()
					return game:GetService("VirtualUser")
				end)
				if ok then
					VU:CaptureController()
					VU:ClickButton2(Vector2.new())
				end
			end
		end)
		Conns[#Conns + 1] = Saved.AFKConn
	end
end)

tog(GameD, "AutoRejoin", "Auto-Rejoin On Disconnect", nil, function(on)
	if on and not Saved.RejoinConn then
		pcall(function()
			Saved.RejoinConn = GuiService.ErrorMessageChanged:Connect(function()
				if isOn("AutoRejoin") then
					task.wait(2)
					TeleportService:Teleport(game.PlaceId, LP)
				end
			end)
			Conns[#Conns + 1] = Saved.RejoinConn
		end)
	end
end)

local CoreTypes = {
	{ "HideChat", "Hide Chat Window", Enum.CoreGuiType.Chat },
	{ "HidePlayerList", "Hide Player List", Enum.CoreGuiType.PlayerList },
	{ "HideBackpack", "Hide Backpack Bar", Enum.CoreGuiType.Backpack },
	{ "HideHealth", "Hide Health Bar", Enum.CoreGuiType.Health },
	{ "HideEmotes", "Hide Emotes Menu", Enum.CoreGuiType.EmotesMenu },
}
for _, c in ipairs(CoreTypes) do
	tog(GameD, c[1], c[2], nil, function(on)
		StarterGui:SetCoreGuiEnabled(c[3], not on)
	end)
end
btn(GameD, "Open Developer Console", function()
	StarterGui:SetCore("DevConsoleVisible", true)
end)
btn(GameD, "Copy Position", function()
	local p = myPos()
	if p then
		copy(string.format("Vector3.new(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z))
	end
end)
btn(GameD, "Copy PlaceId", function()
	copy(tostring(game.PlaceId))
end)
btn(GameD, "Copy JobId", function()
	copy(game.JobId)
end)
btn(GameD, "Copy Join-Server Script", function()
	copy(string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s")', game.PlaceId, game.JobId))
end)

-- Server ----------------------------------------------------------------------
btn(GameE, "Rejoin Same Server", function()
	if #Players:GetPlayers() <= 1 then
		TeleportService:Teleport(game.PlaceId, LP)
	else
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
	end
end)
btn(GameE, "Hop To Another Server", function()
	local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok then
		notify("Server hop", "Could not fetch the server list.", 4)
		return
	end
	local data = HttpService:JSONDecode(body)
	for _, s in ipairs(data.data or {}) do
		if s.id ~= game.JobId and s.playing < s.maxPlayers then
			TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
			return
		end
	end
	notify("Server hop", "No other open server found.", 4)
end)

-- Chat -------------------------------------------------------------------------
GameF:AddInput("ChatText", { Default = "", Text = "Message", Placeholder = "type here..." })
btn(GameF, "Send Chat Message", function()
	local msg = Options.ChatText.Value
	if not msg or msg == "" then
		return
	end
	local ok = pcall(function()
		local ch = TextChatService:FindFirstChild("TextChannels")
		ch = ch and ch:FindFirstChild("RBXGeneral")
		ch:SendAsync(msg)
	end)
	if not ok then
		notify("Chat", "Couldn't send through TextChatService.")
	end
end)
btn(GameF, "Open Chat Window", function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
end)


----------------------------------------------------------------------
-- EXPANSION PACK  (Lighting+, Character+, Groups, Audio+, Social)
-- Many controls here are generated per effect / per map group; each one
-- is a real working control, but they share code, so "500 controls" is
-- not "500 different ideas". The exact count is shown in Settings.
----------------------------------------------------------------------
local X = {}

function X.chat(msg)
	local ok = pcall(function()
		local ch = TextChatService:FindFirstChild("TextChannels")
		ch = ch and ch:FindFirstChild("RBXGeneral")
		ch:SendAsync(msg)
	end)
	if not ok then
		notify("Chat", "Couldn't send through TextChatService.")
	end
end

-- Toggle + sliders + color pickers that create/destroy an Instance
-- spec = { id, text, tip, class, parent = fn, sliders = {{prop,text,min,max,def,rnd}}, colors = {{prop,text,def}} }
function X.effect(gb, spec)
	local inst
	local function apply()
		if not inst then
			return
		end
		for _, s in ipairs(spec.sliders or {}) do
			pcall(function()
				inst[s[1]] = val(spec.id .. "_" .. s[1], s[5])
			end)
		end
		for _, c in ipairs(spec.colors or {}) do
			pcall(function()
				inst[c[1]] = val(spec.id .. "_" .. c[1], c[3])
			end)
		end
	end
	tog(gb, spec.id, spec.text, spec.tip, function(on)
		if on then
			local parent = spec.parent()
			if not parent then
				notify(spec.text, "Target isn't available right now.")
				Toggles[spec.id]:SetValue(false)
				return
			end
			inst = Instance.new(spec.class)
			inst.Name = "SukiHub_" .. spec.class
			inst.Parent = parent
			apply()
		elseif inst then
			inst:Destroy()
			inst = nil
		end
	end)
	for _, s in ipairs(spec.sliders or {}) do
		sld(gb, spec.id .. "_" .. s[1], s[2], s[3], s[4], s[5], s[6], function()
			apply()
		end)
	end
	for _, c in ipairs(spec.colors or {}) do
		gb:AddLabel(c[2]):AddColorPicker(spec.id .. "_" .. c[1], {
			Default = c[3],
			Title = c[2],
			Callback = function()
				apply()
			end,
		})
	end
end

----------------------------------------------------------------------
-- LIGHTING+  (59 controls)
----------------------------------------------------------------------
do
	local Tab = Window:AddTab("Lighting+", "sun-moon")
	local gP = Tab:AddLeftGroupbox("Presets", "palette")
	local gC = Tab:AddLeftGroupbox("Colors & Values", "pipette")
	local gA = Tab:AddRightGroupbox("Atmosphere, Sky & Day Cycle", "cloud")
	local gF = Tab:AddRightGroupbox("Post-Processing", "sparkles")

	local PROPS = {
		"ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogColor", "FogStart", "FogEnd",
		"ColorShift_Top", "ColorShift_Bottom", "ExposureCompensation", "EnvironmentDiffuseScale",
		"EnvironmentSpecularScale", "ShadowSoftness", "GeographicLatitude", "GlobalShadows",
	}
	local Snap = {}
	for _, p in ipairs(PROPS) do
		pcall(function()
			Snap[p] = Lighting[p]
		end)
	end
	local function setL(props)
		for k, v in pairs(props) do
			pcall(function()
				Lighting[k] = v
			end)
		end
	end
	local C = Color3.fromRGB

	local Presets = {
		{ "Sunrise", { ClockTime = 6.2, Brightness = 2, Ambient = C(120, 90, 80), OutdoorAmbient = C(170, 120, 100), FogColor = C(255, 190, 150), FogStart = 0, FogEnd = 1500, ColorShift_Top = C(255, 170, 110) } },
		{ "Noon", { ClockTime = 12, Brightness = 3, Ambient = C(140, 140, 140), OutdoorAmbient = C(170, 170, 170), FogEnd = 100000, ExposureCompensation = 0 } },
		{ "Golden Hour", { ClockTime = 17.2, Brightness = 2.5, Ambient = C(130, 100, 70), OutdoorAmbient = C(200, 150, 90), FogColor = C(255, 205, 140), FogEnd = 3000, ColorShift_Top = C(255, 190, 110) } },
		{ "Sunset", { ClockTime = 18.3, Brightness = 2, Ambient = C(110, 70, 80), OutdoorAmbient = C(190, 100, 90), FogColor = C(255, 120, 90), FogEnd = 1800, ColorShift_Top = C(255, 120, 80) } },
		{ "Dusk", { ClockTime = 19.2, Brightness = 1.2, Ambient = C(70, 60, 100), OutdoorAmbient = C(100, 80, 130), FogColor = C(110, 80, 140), FogEnd = 1200 } },
		{ "Night", { ClockTime = 22, Brightness = 0.6, Ambient = C(40, 45, 80), OutdoorAmbient = C(50, 60, 110), FogColor = C(20, 25, 50), FogEnd = 1500 } },
		{ "Midnight", { ClockTime = 0, Brightness = 0.3, Ambient = C(20, 25, 50), OutdoorAmbient = C(25, 30, 60), FogColor = C(5, 8, 20), FogEnd = 900 } },
		{ "Foggy Morning", { ClockTime = 7.5, Brightness = 1.5, Ambient = C(160, 165, 170), OutdoorAmbient = C(180, 185, 190), FogColor = C(200, 205, 210), FogStart = 0, FogEnd = 220 } },
		{ "Overcast", { ClockTime = 13, Brightness = 1.4, Ambient = C(150, 150, 155), OutdoorAmbient = C(160, 160, 165), FogColor = C(170, 170, 175), FogEnd = 900, ColorShift_Top = C(160, 165, 175) } },
		{ "Neon Night", { ClockTime = 23, Brightness = 1, Ambient = C(90, 40, 140), OutdoorAmbient = C(40, 120, 160), FogColor = C(60, 20, 100), FogEnd = 1000, ColorShift_Top = C(255, 60, 200), ColorShift_Bottom = C(40, 200, 255) } },
		{ "Horror Red", { ClockTime = 1, Brightness = 0.4, Ambient = C(80, 10, 10), OutdoorAmbient = C(90, 15, 15), FogColor = C(70, 0, 0), FogStart = 0, FogEnd = 300 } },
		{ "Winter Blue", { ClockTime = 11, Brightness = 2.2, Ambient = C(120, 140, 175), OutdoorAmbient = C(150, 175, 215), FogColor = C(200, 220, 245), FogEnd = 1500, ColorShift_Top = C(190, 215, 255) } },
		{ "Sepia Warm", { ClockTime = 15, Brightness = 2, Ambient = C(150, 120, 90), OutdoorAmbient = C(180, 145, 105), FogColor = C(200, 165, 120), FogEnd = 4000, ColorShift_Top = C(255, 215, 160) } },
	}
	for _, p in ipairs(Presets) do
		btn(gP, "Preset: " .. p[1], function()
			setL(Snap)
			setL(p[2])
		end)
	end
	btn(gP, "Reset Lighting To Original", function()
		setL(Snap)
	end)

	local function colorProp(id, text, prop)
		gC:AddLabel(text):AddColorPicker(id, {
			Default = Snap[prop] or Color3.new(1, 1, 1),
			Title = text,
			Callback = function(c)
				pcall(function()
					Lighting[prop] = c
				end)
			end,
		})
	end
	colorProp("L_Ambient", "Ambient Color", "Ambient")
	colorProp("L_Outdoor", "Outdoor Ambient", "OutdoorAmbient")
	colorProp("L_Fog", "Fog Color", "FogColor")
	colorProp("L_ShiftTop", "Color Shift Top", "ColorShift_Top")
	colorProp("L_ShiftBottom", "Color Shift Bottom", "ColorShift_Bottom")

	local function lightSlider(id, text, prop, min, max, rnd)
		local def = tonumber(Snap[prop]) or min
		sld(gC, id, text, min, max, math.clamp(def, min, max), rnd, function(v)
			pcall(function()
				Lighting[prop] = v
			end)
		end)
	end
	lightSlider("L_Diffuse", "Environment Diffuse", "EnvironmentDiffuseScale", 0, 1, 2)
	lightSlider("L_Specular", "Environment Specular", "EnvironmentSpecularScale", 0, 1, 2)
	lightSlider("L_ShadowSoft", "Shadow Softness", "ShadowSoftness", 0, 1, 2)
	lightSlider("L_Latitude", "Geographic Latitude", "GeographicLatitude", 0, 90, 0)
	lightSlider("L_FogStart", "Fog Start", "FogStart", 0, 5000, 0)
	lightSlider("L_FogEnd", "Fog End", "FogEnd", 0, 20000, 0)
	lightSlider("L_Clock", "Clock Time (manual)", "ClockTime", 0, 24, 2)

	tickTog(gA, "DayCycle", "Auto Day Cycle", "Advances the clock continuously.", function(dt)
		local dir = isOn("DayReverse") and -1 or 1
		Lighting.ClockTime = (Lighting.ClockTime + dir * val("DaySpeed", 0.5) * dt) % 24
	end)
	sld(gA, "DaySpeed", "Hours Per Second", 0.01, 6, 0.5, 2)
	tog(gA, "DayReverse", "Reverse Day Cycle", nil, function() end)

	X.effect(gA, {
		id = "AtmoFX", text = "Custom Atmosphere", tip = "Adds an Atmosphere object (may override the game's own).",
		class = "Atmosphere", parent = function() return Lighting end,
		sliders = {
			{ "Density", "Atmo Density", 0, 1, 0.3, 2 },
			{ "Offset", "Atmo Offset", 0, 1, 0, 2 },
			{ "Glare", "Atmo Glare", 0, 10, 0, 1 },
			{ "Haze", "Atmo Haze", 0, 10, 0, 1 },
		},
		colors = {
			{ "Color", "Atmo Color", Color3.fromRGB(199, 199, 199) },
			{ "Decay", "Atmo Decay Color", Color3.fromRGB(92, 60, 13) },
		},
	})

	local function sky()
		return Lighting:FindFirstChildOfClass("Sky")
	end
	local function skySlider(id, text, prop, min, max, def)
		sld(gA, id, text, min, max, def, 0, function(v)
			local s = sky()
			if s then
				pcall(function()
					s[prop] = v
				end)
			end
		end)
	end
	skySlider("SkyStars", "Star Count", "StarCount", 0, 5000, 3000)
	skySlider("SkySun", "Sun Size", "SunAngularSize", 0, 60, 21)
	skySlider("SkyMoon", "Moon Size", "MoonAngularSize", 0, 60, 11)
	tog(gA, "SkyHide", "Hide Sun & Moon", "Needs a Sky object in Lighting.", function(on)
		local s = sky()
		if s then
			s.CelestialBodiesShown = not on
		end
	end)

	local LS = function() return Lighting end
	X.effect(gF, { id = "FXBloom", text = "Bloom", class = "BloomEffect", parent = LS, sliders = {
		{ "Intensity", "Bloom Intensity", 0, 5, 1, 2 }, { "Size", "Bloom Size", 0, 60, 24, 0 }, { "Threshold", "Bloom Threshold", 0, 5, 2, 2 },
	} })
	X.effect(gF, { id = "FXBlur", text = "Blur", class = "BlurEffect", parent = LS, sliders = {
		{ "Size", "Blur Size", 0, 60, 12, 0 },
	} })
	X.effect(gF, { id = "FXRays", text = "Sun Rays", class = "SunRaysEffect", parent = LS, sliders = {
		{ "Intensity", "Rays Intensity", 0, 1, 0.25, 2 }, { "Spread", "Rays Spread", 0, 1, 1, 2 },
	} })
	X.effect(gF, { id = "FXColor", text = "Color Correction", class = "ColorCorrectionEffect", parent = LS, sliders = {
		{ "Brightness", "CC Brightness", -1, 1, 0, 2 }, { "Contrast", "CC Contrast", -1, 1, 0, 2 }, { "Saturation", "CC Saturation", -1, 1, 0, 2 },
	}, colors = { { "TintColor", "CC Tint", Color3.new(1, 1, 1) } } })
	X.effect(gF, { id = "FXDof", text = "Depth Of Field", class = "DepthOfFieldEffect", parent = LS, sliders = {
		{ "FarIntensity", "DoF Far Intensity", 0, 1, 0.75, 2 }, { "FocusDistance", "DoF Focus Distance", 0, 500, 50, 0 },
		{ "InFocusRadius", "DoF In-Focus Radius", 0, 500, 30, 0 }, { "NearIntensity", "DoF Near Intensity", 0, 1, 0, 2 },
	} })
end

----------------------------------------------------------------------
-- CHARACTER+  (about 80 controls)
----------------------------------------------------------------------
do
	local Tab = Window:AddTab("Character+", "person-standing")
	local gP = Tab:AddLeftGroupbox("Speed & Jump Presets", "gauge")
	local gH = Tab:AddLeftGroupbox("Humanoid Settings", "user-cog")
	local gE = Tab:AddLeftGroupbox("Emotes (via chat)", "party-popper")
	local gT = Tab:AddLeftGroupbox("Tools", "briefcase")
	local gS = Tab:AddRightGroupbox("Humanoid States", "activity")
	local gM = Tab:AddRightGroupbox("Movement Modes", "wind")

	for _, s in ipairs({ 8, 16, 24, 32, 50, 100 }) do
		btn(gP, "Walk Speed " .. s, function()
			local h = hum()
			if h then
				h.WalkSpeed = s
			end
		end)
	end
	for _, j in ipairs({ 30, 50, 75, 100, 200 }) do
		btn(gP, "Jump Power " .. j, function()
			local h = hum()
			if h then
				h.UseJumpPower = true
				h.JumpPower = j
			end
		end)
	end

	-- Humanoid settings (9)
	tog(gH, "NoAutoRotate", "Disable Auto-Rotate", "Character no longer turns toward movement.", function(on)
		local h = hum()
		if h then
			h.AutoRotate = not on
		end
	end)
	tog(gH, "HideOwnName", "Hide My Name Tag", nil, function(on)
		local h = hum()
		if h then
			h.DisplayDistanceType = on and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer
		end
	end)
	tickTog(gH, "HideAllNames", "Hide Everyone's Name Tags", "Local only.", throttle(1, function()
		for _, c in ipairs(otherChars()) do
			local h = c:FindFirstChildOfClass("Humanoid")
			if h then
				h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
	end), function()
		for _, c in ipairs(otherChars()) do
			local h = c:FindFirstChildOfClass("Humanoid")
			if h then
				h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			end
		end
	end)
	sld(gH, "NameDist", "Name Display Distance", 0, 500, 100, 0, function(v)
		local h = hum()
		if h then
			h.NameDisplayDistance = v
		end
	end)
	sld(gH, "HealthDist", "Health Display Distance", 0, 500, 100, 0, function(v)
		local h = hum()
		if h then
			h.HealthDisplayDistance = v
		end
	end)
	sld(gH, "SlopeAngle", "Max Slope Angle", 0, 89, 89, 0, function(v)
		local h = hum()
		if h then
			h.MaxSlopeAngle = v
		end
	end)
	tickTog(gH, "AnimSpeedOn", "Animation Speed Override", nil, function()
		local h = hum()
		local a = h and h:FindFirstChildOfClass("Animator")
		if a then
			for _, t in ipairs(a:GetPlayingAnimationTracks()) do
				t:AdjustSpeed(val("AnimSpeed", 2))
			end
		end
	end)
	sld(gH, "AnimSpeed", "Animation Speed", 0, 6, 2, 1, nil, "x")
	tog(gH, "PlatformStandOn", "Platform Stand", "Humanoid stops driving the character.", function(on)
		local h = hum()
		if h then
			h.PlatformStand = on
		end
	end)

	-- Emotes (11)
	for _, e in ipairs({ "dance", "dance2", "dance3", "wave", "cheer", "laugh", "point", "salute", "stadium", "tilt", "shrug" }) do
		btn(gE, "Emote: " .. e, function()
			X.chat("/e " .. e)
		end)
	end

	-- Tools (3)
	btn(gT, "Equip First Tool", function()
		local bp, h = LP:FindFirstChildOfClass("Backpack"), hum()
		local t = bp and bp:FindFirstChildOfClass("Tool")
		if t and h then
			h:EquipTool(t)
		else
			notify("Tools", "No tool in your backpack.")
		end
	end)
	tickTog(gT, "AutoEquip", "Auto-Equip A Tool", "Re-equips the first tool if your hands are empty.", throttle(1, function()
		local c, bp = LP.Character, LP:FindFirstChildOfClass("Backpack")
		if c and bp and not c:FindFirstChildOfClass("Tool") then
			local t, h = bp:FindFirstChildOfClass("Tool"), hum()
			if t and h then
				h:EquipTool(t)
			end
		end
	end))
	btn(gT, "Print Backpack To Console", function()
		local bp = LP:FindFirstChildOfClass("Backpack")
		for _, t in ipairs(bp and bp:GetChildren() or {}) do
			print(t.ClassName, t.Name)
		end
	end)

	-- States (27)
	local StateList = {
		"FallingDown", "Ragdoll", "GettingUp", "Jumping", "Freefall", "Flying", "Running", "RunningNoPhysics",
		"Climbing", "Swimming", "Landed", "Seated", "PlatformStanding", "Physics", "StrafingNoPhysics",
	}
	for _, n in ipairs(StateList) do
		tog(gS, "St_" .. n, "Disable State: " .. n, "Careful: disabling Running/Jumping stops that movement.", function(on)
			local h = hum()
			if h then
				h:SetStateEnabled(Enum.HumanoidStateType[n], not on)
			end
		end)
	end
	connect(LP.CharacterAdded, function()
		task.wait(1)
		local h = hum()
		if not h then
			return
		end
		for _, n in ipairs(StateList) do
			if isOn("St_" .. n) then
				pcall(function()
					h:SetStateEnabled(Enum.HumanoidStateType[n], false)
				end)
			end
		end
	end)
	for _, n in ipairs({ "Jumping", "Freefall", "Flying", "Climbing", "Swimming", "Seated", "Physics", "Ragdoll", "FallingDown", "GettingUp", "Running", "PlatformStanding" }) do
		btn(gS, "Force State: " .. n, function()
			local h = hum()
			if h then
				h:ChangeState(Enum.HumanoidStateType[n])
			end
		end)
	end

	-- Movement modes (19)
	local AirPart
	tickTog(gM, "AirWalk", "Air Walk", "Invisible platform under your feet. Hold Ctrl to drop.", function()
		local r, h = root(), hum()
		if not (r and h) then
			return
		end
		if not (AirPart and AirPart.Parent) then
			AirPart = Instance.new("Part")
			AirPart.Name = "SukiHubAir"
			AirPart.Anchored = true
			AirPart.Transparency = 1
			AirPart.Size = Vector3.new(8, 0.5, 8)
			AirPart.Parent = Workspace
		end
		local drop = UIS:IsKeyDown(Enum.KeyCode.LeftControl) and 4 or 0
		local y = r.Position.Y - h.HipHeight - r.Size.Y / 2 - 0.25 - drop
		AirPart.CFrame = CFrame.new(r.Position.X, y, r.Position.Z)
	end, function()
		if AirPart then
			AirPart:Destroy()
			AirPart = nil
		end
	end)

	tickTog(gM, "Glide", "Glide / Slow Fall", "Caps your falling speed.", function()
		local r = root()
		if r then
			local v = r.AssemblyLinearVelocity
			local cap = val("GlideCap", 8)
			if v.Y < -cap then
				r.AssemblyLinearVelocity = Vector3.new(v.X, -cap, v.Z)
			end
		end
	end)
	sld(gM, "GlideCap", "Max Fall Speed", 0, 100, 8, 0)

	tickTog(gM, "Bhop", "Bunny Hop", "Auto-jumps while moving and adds air speed.", function()
		local h, r = hum(), root()
		if h and r and h.MoveDirection.Magnitude > 0.1 then
			if h.FloorMaterial ~= Enum.Material.Air then
				h.Jump = true
			else
				local v = r.AssemblyLinearVelocity
				local add = h.MoveDirection * val("BhopBoost", 4)
				r.AssemblyLinearVelocity = Vector3.new(v.X + add.X * 0.1, v.Y, v.Z + add.Z * 0.1)
			end
		end
	end)
	sld(gM, "BhopBoost", "Bhop Air Boost", 0, 40, 4, 0)

	tickTog(gM, "MoonJump", "Moon Jump", "Low gravity only while airborne.", function()
		local h = hum()
		if h then
			Workspace.Gravity = (h.FloorMaterial == Enum.Material.Air) and val("MoonG", 40) or Saved.Gravity
		end
	end, function()
		Workspace.Gravity = Saved.Gravity
	end)
	sld(gM, "MoonG", "Moon Gravity", 0, 196, 40, 0)

	tog(gM, "LongJump", "Long Jump", "Pushes you forward when you jump.", function() end)
	sld(gM, "LongJumpPower", "Long Jump Power", 5, 150, 40, 0)
	connect(UIS.JumpRequest, function()
		local r = root()
		if r and isOn("LongJump") then
			r.AssemblyLinearVelocity = r.AssemblyLinearVelocity + r.CFrame.LookVector * val("LongJumpPower", 40)
		end
	end)

	tickTog(gM, "AutoRun", "Auto Run Forward", "Keeps moving the way you face.", function()
		local h = hum()
		if h then
			h:Move(Vector3.new(0, 0, -1), true)
		end
	end)

	tickTog(gM, "ShiftSprint", "Hold Shift To Sprint", "Keyboard only.", function()
		local h = hum()
		if not h then
			return
		end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
			if not Saved.Sprinting then
				Saved.SprintBase = h.WalkSpeed
				Saved.Sprinting = true
			end
			h.WalkSpeed = (Saved.SprintBase or 16) * val("SprintMult", 2)
		elseif Saved.Sprinting then
			h.WalkSpeed = Saved.SprintBase or 16
			Saved.Sprinting = false
		end
	end, function()
		local h = hum()
		if h and Saved.Sprinting then
			h.WalkSpeed = Saved.SprintBase or 16
		end
		Saved.Sprinting = false
	end)
	sld(gM, "SprintMult", "Sprint Multiplier", 1, 6, 2, 1, nil, "x")

	tickTog(gM, "CFrameSpeed", "CFrame Speed", "Moves you by position instead of WalkSpeed.", function(dt)
		local h, r = hum(), root()
		if h and r and h.MoveDirection.Magnitude > 0.1 then
			r.CFrame = r.CFrame + h.MoveDirection * val("CFSpeed", 30) * dt
		end
	end)
	sld(gM, "CFSpeed", "CFrame Speed", 5, 200, 30, 0, nil, " st/s")

	tickTog(gM, "AntiVoid", "Anti-Void Rescue", "Sends you back to a safe spot if you fall too low.", function()
		local r, h = root(), hum()
		if not (r and h) then
			return
		end
		if r.Position.Y < val("VoidY", -50) then
			tpTo(Saved.SafePos or Vector3.new(0, 60, 0))
		elseif h.FloorMaterial ~= Enum.Material.Air and not Saved.ManualSafe then
			Saved.SafePos = r.Position + Vector3.new(0, 3, 0)
		end
	end)
	sld(gM, "VoidY", "Void Height", -500, 100, -50, 0)
	btn(gM, "Mark Safe Spot", function()
		local p = myPos()
		if p then
			Saved.SafePos, Saved.ManualSafe = p + Vector3.new(0, 3, 0), true
			notify("Safe spot", "Saved. Anti-Void will return you here.")
		end
	end)
	btn(gM, "Return To Safe Spot", function()
		if Saved.SafePos then
			tpTo(Saved.SafePos)
		else
			notify("Safe spot", "None saved yet.")
		end
	end)

	local LastCF
	connect(RunService.Heartbeat, function()
		local r, h = root(), hum()
		if r and h and h.Health > 0 then
			LastCF = r.CFrame
		end
	end)
	tog(gM, "RespawnHere", "Respawn Where I Died", nil, function() end)
	connect(LP.CharacterAdded, function(c)
		local cf = LastCF
		if isOn("RespawnHere") and cf then
			local r = c:WaitForChild("HumanoidRootPart", 5)
			task.wait(0.5)
			if r then
				r.CFrame = cf
			end
		end
	end)
end

----------------------------------------------------------------------
-- GROUPS  (about 100 controls, generated for every map group)
----------------------------------------------------------------------
do
	local Tab = Window:AddTab("Groups", "layers")
	local S = "Suki"
	local Defs = {
		{ "Kuryente (power)", { S, "Kuryente" } },
		{ "Greens (plants)", { S, "Greens" } },
		{ "Tambayan", { S, "Tambayan" } },
		{ "Stones", { S, "Stones" } },
		{ "Bagsakan", { S, "Bagsakan" } },
		{ "Screen", { S, "Screen" } },
		{ "Hardware", { S, "Hardware" } },
		{ "Peralco", { S, "Peralco" } },
		{ "Hedges", { S, "Hedges" } },
		{ "Leaderboards", { S, "Leaderboards" } },
		{ "WallPaint", { S, "WallPaint" } },
		{ "Props", { S, "Props" } },
		{ "Winners", { S, "Winners" } },
		{ "Stalls", { S, "Stalls" } },
		{ "Street", { S, "Street" } },
		{ "Hall", { S, "Hall" } },
		{ "Coins", { "SukiCoins" } },
		{ "Environment Base", { "Environment_Base" } },
		{ "Neighbors (SukiPeople)", { "SukiPeople" } },
		{ "Ambient Crowd", { "SukiAmbient" } },
		{ "Guide Arrow", { "GuideArrow" } },
	}
	-- only add Hide / Walk-Through where the Movement/World tabs don't already have one
	local HideNew = { Screen = true, Hardware = true, Peralco = true, Leaderboards = true, WallPaint = true, Stalls = true, Street = true, Hall = true, ["Guide Arrow"] = true }
	local PassNew = { ["Kuryente (power)"] = true, Screen = true, Hardware = true, Peralco = true, Leaderboards = true, WallPaint = true, Winners = true, Stalls = true, Hall = true, ["Guide Arrow"] = true }

	for i, d in ipairs(Defs) do
		local label, path = d[1], d[2]
		local function folder()
			return W(table.unpack(path))
		end
		local id = "G" .. i .. "_"
		local gb = (i % 2 == 1) and Tab:AddLeftGroupbox(label) or Tab:AddRightGroupbox(label)

		btn(gb, "Teleport Here", function()
			local p = worldPos(folder())
			if p then
				tpTo(p, Vector3.new(0, 8, 0))
			else
				notify(label, "Not loaded (streaming?). Walk closer and retry.")
			end
		end)

		local token = 0
		sld(gb, id .. "Op", "Hide Amount", 0, 1, 0, 2, function(v)
			token += 1
			local my = token
			task.delay(0.12, function()
				if my ~= token then
					return
				end
				for _, p in ipairs(partsUnder(folder())) do
					p.LocalTransparencyModifier = v
				end
			end)
		end)

		tog(gb, id .. "Neon", "Neon Material", "Client-only look.", folderFeature("neon" .. id, folder, "Material", Enum.Material.Neon))

		btn(gb, "Print Stats To Console", function()
			local f = folder()
			if not f then
				notify(label, "Not loaded.")
				return
			end
			local n = { parts = 0, meshes = 0, models = 0, prompts = 0, clicks = 0, lights = 0 }
			for _, x in ipairs(f:GetDescendants()) do
				if x:IsA("MeshPart") then
					n.meshes += 1
					n.parts += 1
				elseif x:IsA("BasePart") then
					n.parts += 1
				elseif x:IsA("Model") then
					n.models += 1
				elseif x:IsA("ProximityPrompt") then
					n.prompts += 1
				elseif x:IsA("ClickDetector") then
					n.clicks += 1
				elseif x:IsA("Light") then
					n.lights += 1
				end
			end
			local p = worldPos(f)
			print(string.format("[%s] parts=%d meshparts=%d models=%d prompts=%d clicks=%d lights=%d pos=%s", label, n.parts, n.meshes, n.models, n.prompts, n.clicks, n.lights, p and string.format("%d,%d,%d", p.X, p.Y, p.Z) or "?"))
			notify(label, n.parts .. " parts, " .. n.prompts .. " prompts (see console)")
		end)

		if HideNew[label] then
			tog(gb, id .. "Hide", "Hide Group", "Client-only.", folderFeature("hide" .. id, folder, "LocalTransparencyModifier", 1))
		end
		if PassNew[label] then
			tog(gb, id .. "Pass", "Walk Through Group", "Client-only collision off.", folderFeature("pass" .. id, folder, "CanCollide", false))
		end
	end
end

----------------------------------------------------------------------
-- AUDIO+  (about 57 controls)
----------------------------------------------------------------------
do
	local Tab = Window:AddTab("Audio+", "music")
	local gT = Tab:AddLeftGroupbox("Radio Transport", "play")
	local gB = Tab:AddLeftGroupbox("Sound Browser", "list-music")
	local gG = Tab:AddLeftGroupbox("Global Audio", "globe")
	local gE1 = Tab:AddRightGroupbox("Radio Effects: EQ / Reverb / Echo", "sliders-horizontal")
	local gE2 = Tab:AddRightGroupbox("Radio Effects: Mods", "audio-waveform")

	-- Transport (5)
	btn(gT, "Radio: Play", function()
		local r = radio()
		if r then
			r:Play()
		end
	end)
	btn(gT, "Radio: Pause", function()
		local r = radio()
		if r then
			r:Pause()
		end
	end)
	btn(gT, "Radio: Restart", function()
		local r = radio()
		if r then
			r.TimePosition = 0
			r:Play()
		end
	end)
	tog(gT, "RadioLoop", "Radio Loop", nil, function(on)
		local r = radio()
		if r then
			r.Looped = on
		end
	end)
	sld(gT, "RadioSeek", "Radio Position (sec)", 0, 600, 0, 0, function(v)
		local r = radio()
		if r then
			r.TimePosition = math.min(v, math.max(r.TimeLength - 0.1, 0))
		end
	end)

	-- Sound browser (9)
	gB:AddDropdown("SndPick", { Values = { "(press refresh)" }, Default = 1, Text = "Sound" })
	local function pickSound()
		for s in pairs(Sounds) do
			if s.Name == Options.SndPick.Value then
				return s
			end
		end
	end
	btn(gB, "Refresh Sound List", function()
		local seen, vals = {}, {}
		for s in pairs(Sounds) do
			if not seen[s.Name] then
				seen[s.Name] = true
				vals[#vals + 1] = s.Name
			end
		end
		table.sort(vals)
		if #vals == 0 then
			vals = { "(no sounds)" }
		end
		Options.SndPick:SetValues(vals)
		notify("Sounds", #vals .. " unique sound names.")
	end)
	btn(gB, "Play Sound", function()
		local s = pickSound()
		if s then
			s:Play()
		end
	end)
	btn(gB, "Stop Sound", function()
		local s = pickSound()
		if s then
			s:Stop()
		end
	end)
	tog(gB, "SndMute", "Mute This Sound", nil, function(on)
		local s = pickSound()
		if s then
			if on then
				ovr1("sndmute", s, "Volume", 0)
			else
				unovr("sndmute", "Volume")
			end
		end
	end)
	sld(gB, "SndVol", "Sound Volume", 0, 10, 1, 1, function(v)
		local s = pickSound()
		if s then
			s.Volume = v
		end
	end)
	sld(gB, "SndSpeed", "Sound Speed", 0.2, 4, 1, 2, function(v)
		local s = pickSound()
		if s then
			s.PlaybackSpeed = v
		end
	end)
	tog(gB, "SndLoop", "Loop This Sound", nil, function(on)
		local s = pickSound()
		if s then
			s.Looped = on
		end
	end)
	btn(gB, "Print Sound Info", function()
		local s = pickSound()
		if s then
			print(s:GetFullName(), "id=" .. tostring(s.SoundId), "vol=" .. s.Volume, "len=" .. s.TimeLength, "playing=" .. tostring(s.Playing))
		end
	end)

	-- Global (6)
	local rv = {}
	for _, it in ipairs(Enum.ReverbType:GetEnumItems()) do
		rv[#rv + 1] = it.Name
	end
	gG:AddDropdown("AmbReverb", {
		Values = rv, Default = "NoReverb", Text = "Ambient Reverb Type",
		Callback = function(v)
			pcall(function()
				SoundService.AmbientReverb = Enum.ReverbType[v]
			end)
		end,
	})
	local function ssSlider(id, text, prop, min, max, def)
		sld(gG, id, text, min, max, def, 2, function(v)
			pcall(function()
				SoundService[prop] = v
			end)
		end)
	end
	ssSlider("SS_Doppler", "Doppler Scale", "DopplerScale", 0, 10, 1)
	ssSlider("SS_Rolloff", "Rolloff Scale", "RolloffScale", 0, 10, 1)
	ssSlider("SS_Distance", "Distance Factor", "DistanceFactor", 0.1, 10, 3.33)
	tickTog(gG, "MuteMine", "Mute My Character Sounds", nil, throttle(1, function()
		if LP.Character then
			for _, d in ipairs(LP.Character:GetDescendants()) do
				if d:IsA("Sound") then
					ovr1("ownsnd", d, "Volume", 0)
				end
			end
		end
	end), function()
		unovr("ownsnd", "Volume")
	end)
	tickTog(gG, "MuteOthers", "Mute Other Players' Sounds", nil, throttle(1, function()
		for _, c in ipairs(otherChars()) do
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("Sound") then
					ovr1("othersnd", d, "Volume", 0)
				end
			end
		end
	end), function()
		unovr("othersnd", "Volume")
	end)

	-- Radio effects (37)
	local R = function() return radio() end
	X.effect(gE1, { id = "RFXEq", text = "Equalizer", class = "EqualizerSoundEffect", parent = R, sliders = {
		{ "LowGain", "EQ Low Gain", -80, 10, 0, 0 }, { "MidGain", "EQ Mid Gain", -80, 10, 0, 0 }, { "HighGain", "EQ High Gain", -80, 10, 0, 0 },
	} })
	X.effect(gE1, { id = "RFXRev", text = "Reverb", class = "ReverbSoundEffect", parent = R, sliders = {
		{ "DecayTime", "Reverb Decay", 0.1, 20, 1.5, 1 }, { "Density", "Reverb Density", 0, 1, 1, 2 }, { "Diffusion", "Reverb Diffusion", 0, 1, 1, 2 },
		{ "DryLevel", "Reverb Dry", -80, 20, -6, 0 }, { "WetLevel", "Reverb Wet", -80, 20, 0, 0 },
	} })
	X.effect(gE1, { id = "RFXEcho", text = "Echo", class = "EchoSoundEffect", parent = R, sliders = {
		{ "Delay", "Echo Delay", 0.01, 5, 1, 2 }, { "Feedback", "Echo Feedback", 0, 1, 0.5, 2 },
		{ "DryLevel", "Echo Dry", -80, 10, 0, 0 }, { "WetLevel", "Echo Wet", -80, 10, 0, 0 },
	} })
	X.effect(gE2, { id = "RFXDist", text = "Distortion", class = "DistortionSoundEffect", parent = R, sliders = {
		{ "Level", "Distortion Level", 0, 1, 0.5, 2 },
	} })
	X.effect(gE2, { id = "RFXPitch", text = "Pitch Shift", class = "PitchShiftSoundEffect", parent = R, sliders = {
		{ "Octave", "Pitch Octave", 0.5, 2, 1.25, 2 },
	} })
	X.effect(gE2, { id = "RFXChorus", text = "Chorus", class = "ChorusSoundEffect", parent = R, sliders = {
		{ "Depth", "Chorus Depth", 0, 1, 0.45, 2 }, { "Mix", "Chorus Mix", 0, 1, 0.5, 2 }, { "Rate", "Chorus Rate", 0, 20, 0.5, 1 },
	} })
	X.effect(gE2, { id = "RFXComp", text = "Compressor", class = "CompressorSoundEffect", parent = R, sliders = {
		{ "Threshold", "Comp Threshold", -80, 0, -40, 0 }, { "Ratio", "Comp Ratio", 1, 50, 40, 0 }, { "Attack", "Comp Attack", 0, 1, 0.1, 2 },
		{ "Release", "Comp Release", 0, 5, 0.1, 2 }, { "GainMakeup", "Comp Makeup Gain", 0, 30, 0, 0 },
	} })
	X.effect(gE2, { id = "RFXFlange", text = "Flanger", class = "FlangeSoundEffect", parent = R, sliders = {
		{ "Depth", "Flange Depth", 0, 1, 0.45, 2 }, { "Mix", "Flange Mix", 0, 1, 0.85, 2 }, { "Rate", "Flange Rate", 0, 20, 5, 1 },
	} })
	X.effect(gE2, { id = "RFXTrem", text = "Tremolo", class = "TremoloSoundEffect", parent = R, sliders = {
		{ "Depth", "Tremolo Depth", 0, 1, 0.5, 2 }, { "Duty", "Tremolo Duty", 0, 1, 0.5, 2 }, { "Frequency", "Tremolo Frequency", 0.1, 20, 5, 1 },
	} })
end

----------------------------------------------------------------------
-- SOCIAL  (30 controls)
----------------------------------------------------------------------
do
	local Tab = Window:AddTab("Social", "message-circle")
	local gQ = Tab:AddLeftGroupbox("Quick Phrases (Taglish)", "message-square-quote")
	local gP = Tab:AddRightGroupbox("Players", "users")

	local Phrases = {
		"Pwede utang?", "Salamat po!", "Magkano po ito?", "Tawad po!", "Bayad na po!", "Suki, may bago kayong paninda?",
		"Pabili po!", "Isa pa po!", "Walang sukli po?", "Ingat po!", "Kumusta po kayo?", "Mamaya na lang po bayad",
		"Libre ba 'to?", "Sarap!", "Init ngayon!", "Tara tambay!", "Good morning po!", "Good afternoon po!",
		"Good evening po!", "Pasensya na po", "Opo", "Hindi po", "Sandali lang po", "Pwede po bang magtanong?",
	}
	for _, ph in ipairs(Phrases) do
		btn(gQ, ph, function()
			X.chat(ph)
		end)
	end

	local function others()
		local t = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local r = p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r then
				t[#t + 1] = r
			end
		end
		return t
	end
	local function byDistance(far)
		local mp, best, bd = myPos(), nil, far and -1 or math.huge
		if not mp then
			return nil
		end
		for _, r in ipairs(others()) do
			local d = (r.Position - mp).Magnitude
			if (far and d > bd) or (not far and d < bd) then
				best, bd = r, d
			end
		end
		return best
	end
	btn(gP, "Teleport To Nearest Player", function()
		local r = byDistance(false)
		if r then
			tpTo(r.Position, Vector3.new(3, 3, 0))
		else
			notify("Players", "Nobody else is loaded.")
		end
	end)
	btn(gP, "Teleport To Farthest Player", function()
		local r = byDistance(true)
		if r then
			tpTo(r.Position, Vector3.new(3, 3, 0))
		else
			notify("Players", "Nobody else is loaded.")
		end
	end)
	btn(gP, "Teleport To Random Player", function()
		local list = others()
		if #list > 0 then
			tpTo(list[math.random(#list)].Position, Vector3.new(3, 3, 0))
		else
			notify("Players", "Nobody else is loaded.")
		end
	end)
	tickTog(gP, "FollowNearest", "Follow Nearest Player", nil, throttle(0.2, function()
		local r = byDistance(false)
		if r then
			tpTo((r.CFrame * CFrame.new(0, 0, 5)).Position, Vector3.new(0, 2, 0))
		end
	end))
	btn(gP, "Print All Players To Console", function()
		for _, p in ipairs(Players:GetPlayers()) do
			print(p.DisplayName, "@" .. p.Name, p.UserId, p.AccountAge .. "d")
		end
	end)
	btn(gP, "Show Server Player Count", function()
		notify("Players", #Players:GetPlayers() .. " / " .. Players.MaxPlayers)
	end)
end

----------------------------------------------------------------------
-- REMOTES tab: per-remote watch / block for ReplicatedStorage.SukiRemotes
----------------------------------------------------------------------
do
	local Tab = Window:AddTab("Remotes", "radio-tower")
	local L = Tab:AddLeftGroupbox("Watch (log only these)", "eye")
	local R = Tab:AddRightGroupbox("Block outgoing (advanced)", "ban")
	L:AddLabel("Turn on the Remote Spy in Game Tools first. With no watch toggles on, every SukiRemote is logged.", true)
	R:AddLabel("Blocking stops YOUR client from sending that remote. It can desync or soft-lock the game.", true)
	if SpyRemotes then
		for _, r in ipairs(SpyRemotes:GetChildren()) do
			if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
				local name = r.Name
				tog(L, "RW_" .. name, "Watch " .. name, r.ClassName, function(on)
					Spy.watch[name] = on or nil
					if on and not Toggles.SpyOn.Value then
						Toggles.SpyOn:SetValue(true)
					end
				end)
				tog(R, "RB_" .. name, "Block " .. name, r.ClassName, function(on)
					if on and not startSpy() then
						notify("Block", "This executor can't hook __namecall.", 4)
						Toggles["RB_" .. name]:SetValue(false)
						return
					end
					Spy.block[name] = on or nil
				end)
			end
		end
	end
	btn(L, "Clear All Watches", function()
		for k in pairs(Spy.watch) do
			local t = Toggles["RW_" .. k]
			if t then
				t:SetValue(false)
			end
		end
	end)
	btn(R, "Unblock Everything", function()
		for k in pairs(Spy.block) do
			local t = Toggles["RB_" .. k]
			if t then
				t:SetValue(false)
			end
		end
	end)
end
----------------------------------------------------------------------
-- SETTINGS
----------------------------------------------------------------------
Tabs.Set = Window:AddTab("Settings", "settings")
local SetA = Tabs.Set:AddLeftGroupbox("Menu", "layout-dashboard")
SetA:AddLabel("Menu Key"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Options.MenuKeybind

SetA:AddDropdown("DPIDropdown", {
	Values = { "50%", "75%", "90%", "100%", "125%", "150%" },
	Default = "100%",
	Text = "UI Scale",
	Callback = function(v)
		local n = tonumber((tostring(v):gsub("%%", "")))
		if n then
			pcall(function()
				Library:SetDPIScale(n)
			end)
		end
	end,
})
SetA:AddDropdown("NotifySideDD", {
	Values = { "Left", "Right" },
	Default = "Right",
	Text = "Notification Side",
	Callback = function(v)
		pcall(function()
			Library:SetNotifySide(v)
		end)
	end,
})
btn(SetA, "Unload Hub (restores everything)", function()
	if genv.SukiHub_Unload then
		genv.SukiHub_Unload()
	end
end)

local function fullUnload()
	for _, t in pairs(Toggles) do
		pcall(function()
			if t.Value then
				t:SetValue(false)
			end
		end)
	end
	Library:Unload()
end
genv.SukiHub_Unload = fullUnload

Library:OnUnload(function()
	Spy.on = false
	for _, c in ipairs(Conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(Conns)
	table.clear(Ticks)
	table.clear(OnNew)
	pcall(function()
		ESPFolder:Destroy()
	end)
	if ClickTool then
		pcall(function()
			ClickTool:Destroy()
		end)
	end
	pcall(function()
		RunService:Set3dRenderingEnabled(true)
	end)
	genv.SukiHub_Unload = nil
end)

local nTog, nOpt = 0, 0
for _ in pairs(Toggles) do
	nTog += 1
end
for _ in pairs(Options) do
	nOpt += 1
end
local nBtn = Saved.Buttons or 0
local nTotal = nTog + nOpt + nBtn
SetA:AddLabel(string.format("Controls loaded: %d\n(%d toggles, %d sliders/dropdowns/pickers, %d buttons)", nTotal, nTog, nOpt, nBtn), true)

if okT and okS then
	pcall(function()
		ThemeManager:SetLibrary(Library)
		SaveManager:SetLibrary(Library)
		SaveManager:IgnoreThemeSettings()
		SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
		ThemeManager:SetFolder("SukiHub")
		SaveManager:SetFolder("SukiHub/pwede-utang")
		SaveManager:BuildConfigSection(Tabs.Set)
		ThemeManager:ApplyToTab(Tabs.Set)
	end)
end

refreshActions()
refreshNPCs()
refreshSpawns()
notify("SUKI Hub", nTotal .. " controls loaded. Menu: RightShift or the on-screen button.", 6)
