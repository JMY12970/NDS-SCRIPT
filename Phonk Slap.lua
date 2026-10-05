local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkManagerNew = require(ReplicatedStorage.Shared.Modules.NetworkManagerNew)
local VirtualUser = game:GetService("VirtualUser")

_G.__PSGen = (_G.__PSGen or 0) + 1
local GEN = _G.__PSGen
_G.__PSClean = _G.__PSClean or {}
for _, c in ipairs(_G.__PSClean) do
	pcall(c.Disconnect, c)
end
_G.__PSClean = {}
local function conn(sig, fn)
	local c = sig:Connect(function(...)
		if GEN ~= _G.__PSGen then
			return
		end
		return fn(...)
	end)
	table.insert(_G.__PSClean, c)
	return c
end

local function destroyOldWindow()
	for _, gui in ipairs(game.CoreGui.RobloxGui:GetChildren()) do
		if gui:IsA("ScreenGui") then
			for _, d in ipairs(gui:GetDescendants()) do
				if d:IsA("TextLabel") and d.Text == "Phonk Slap" then
					gui:Destroy()
					break
				end
			end
		end
	end
end
destroyOldWindow()

local S = {
	enabled = false,
	delay = 0.2,
	range = 40,
	aim = true,
	noCd = false,
	walk = 16,
	jump = 50,
	fly = false,
	flySpeed = 50,
	noclip = false,
	esp = false,
	tracer = false,
	instantInter = false,
	antiAfk = false,
}

local Window = Library:CreateWindow({
	Title = "Phonk Slap | Made by st00kkk",
	Footer = "PhonkSlapHub",
	ToggleKeybind = Enum.KeyCode.RightShift,
	CornerRadius = UDim.new(0, 6),
})

local Tabs = {
	Aura = Window:AddTab("Slap Aura", "sword"),
	Movement = Window:AddTab("Movement", "footprints"),
	Esp = Window:AddTab("ESP", "eye"),
	Utility = Window:AddTab("Utility", "wrench"),
	Settings = Window:AddTab("Settings", "settings"),
}

-- Groups Setup
local AuraGroup = Tabs.Aura:AddLeftGroupbox("Aura Controls")
local AuraSettingsGroup = Tabs.Aura:AddRightGroupbox("Targeting Settings")

local MovementGroup = Tabs.Movement:AddLeftGroupbox("Character Movement")
local FlightGroup = Tabs.Movement:AddRightGroupbox("Flight & Noclip")

local EspGroup = Tabs.Esp:AddLeftGroupbox("Visual Render")
local UtilGroup = Tabs.Utility:AddLeftGroupbox("Game Utilities")

-- ===================== TOGGLES & SLIDERS =====================

AuraGroup:AddToggle("SlapAuraToggle", {
	Text = "Slap Aura",
	Default = false,
	Tooltip = "Automatically slaps targets within range.",
	Callback = function(v)
		S.enabled = v
	end,
})

AuraGroup:AddSlider("AuraRangeSlider", {
	Text = "Target range",
	Default = 40,
	Min = 10,
	Max = 120,
	Rounding = 0,
	Suffix = " studs",
	Callback = function(v)
		S.range = v
	end,
})

AuraGroup:AddSlider("AuraSpeedSlider", {
	Text = "Slap speed",
	Default = 5,
	Min = 1,
	Max = 12,
	Rounding = 0,
	Suffix = " /s",
	Callback = function(v)
		S.delay = 1 / v
	end,
})

AuraSettingsGroup:AddToggle("AuraAimToggle", {
	Text = "Auto-aim",
	Default = true,
	Tooltip = "Spin to a target before each slap. Skips your Roblox friends.",
	Callback = function(v)
		S.aim = v
	end,
})

AuraSettingsGroup:AddToggle("NoSlapCooldownToggle", {
	Text = "No slap cooldown",
	Default = false,
	Tooltip = "Removes the cooldown for slap AND ability (E).",
	Callback = function(v)
		S.noCd = v
		LocalPlayer:SetAttribute("NoCooldown", v)
	end,
})

FlightGroup:AddToggle("FlyToggle", {
	Text = "Fly",
	Default = false,
	Tooltip = "WASD / joystick to move, Space up, Ctrl down.",
	Callback = function(v)
		S.fly = v
	end,
})

FlightGroup:AddSlider("FlySpeedSlider", {
	Text = "Fly speed",
	Default = 50,
	Min = 10,
	Max = 300,
	Rounding = 0,
	Suffix = " /s",
	Callback = function(v)
		S.flySpeed = v
	end,
})

FlightGroup:AddToggle("NoclipToggle", {
	Text = "Noclip",
	Default = false,
	Tooltip = "Walk through walls.",
	Callback = function(v)
		S.noclip = v
	end,
})

MovementGroup:AddSlider("WalkSpeedSlider", {
	Text = "WalkSpeed",
	Default = 16,
	Min = 16,
	Max = 300,
	Rounding = 0,
	Suffix = " studs/s",
	Callback = function(v)
		S.walk = v
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = v
		end
	end,
})

local function applyJump(hum)
	if not hum then return end
	hum.JumpPower = S.jump
	local g = workspace.Gravity
	if g and g > 0 then
		hum.JumpHeight = (S.jump * S.jump) / (2 * g)
	end
end

MovementGroup:AddSlider("JumpBoostSlider", {
	Text = "JumpBoost",
	Default = 50,
	Min = 30,
	Max = 300,
	Rounding = 0,
	Suffix = " jump power",
	Callback = function(v)
		S.jump = v
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		applyJump(hum)
	end,
})

EspGroup:AddToggle("EspToggle", {
	Text = "Player ESP",
	Default = false,
	Tooltip = "3D boxes, names and distance over alive players.",
	Callback = function(v)
		S.esp = v
	end,
})

EspGroup:AddToggle("EspTracerToggle", {
	Text = "Tracer lines",
	Default = false,
	Tooltip = "Line from screen bottom to each player.",
	Callback = function(v)
		S.tracer = v
	end,
})

UtilGroup:AddToggle("InstantInterToggle", {
	Text = "Instant interact",
	Default = false,
	Tooltip = "Single tap E instantly completes prompts.",
	Callback = function(v)
		S.instantInter = v
	end,
})

UtilGroup:AddToggle("AntiAfkToggle", {
	Text = "Anti-AFK",
	Default = false,
	Tooltip = "Automatically clears the AFK idle kick.",
	Callback = function(v)
		S.antiAfk = v
	end,
})

-- Library Configuration & Themes Setup
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Library:Notify("Phonk Slap loaded successfully! Use with caution.")

-- ===================== CHARACTER HELPERS =====================

local function getChar()
	return LocalPlayer.Character
end

local function getHumanoid()
	local char = getChar()
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
	local char = getChar()
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function fireSlap(tool)
	NetworkManagerNew.General.ToolServiceBasic:Fire("ToolActivated", tool, nil)
end

local friendCache = {}
local function isFriend(p)
	local uid = p.UserId
	local cached = friendCache[uid]
	if cached ~= nil then
		return cached
	end
	local ok, res = pcall(function()
		return LocalPlayer:IsFriendsWith(uid)
	end)
	local v = ok and res or false
	friendCache[uid] = v
	return v
end

-- ===================== VIRTUAL JOYSTICK (mobile) =====================
local joy = { active = false, x = 0, y = 0 }
local joystickGui, joyBase

local function buildJoystick()
	if not UserInputService.TouchEnabled then
		return
	end
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Name == "PhonkJoystick" then
			g:Destroy()
		end
	end
	joystickGui = Instance.new("ScreenGui")
	joystickGui.Name = "PhonkJoystick"
	joystickGui.IgnoreGuiInset = true
	joystickGui.ResetOnSpawn = false
	joystickGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	joyBase = Instance.new("Frame")
	joyBase.Name = "Base"
	joyBase.Size = UDim2.new(0, 150, 0, 150)
	joyBase.Position = UDim2.new(0, 40, 1, -190)
	joyBase.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	joyBase.BackgroundTransparency = 0.7
	joyBase.BorderSizePixel = 0
	local bStroke = Instance.new("UICorner")
	bStroke.CornerRadius = UDim.new(1, 0)
	bStroke.Parent = joyBase

	local joyThumb = Instance.new("Frame")
	joyThumb.Name = "Thumb"
	joyThumb.Size = UDim2.new(0, 60, 0, 60)
	joyThumb.Position = UDim2.new(0, 45, 0, 45)
	joyThumb.AnchorPoint = Vector2.new(0.5, 0.5)
	joyThumb.BackgroundColor3 = Color3.fromRGB(120, 120, 220)
	joyThumb.BackgroundTransparency = 0.2
	joyThumb.BorderSizePixel = 0
	local tStroke = Instance.new("UICorner")
	tStroke.CornerRadius = UDim.new(1, 0)
	tStroke.Parent = joyThumb
	joyThumb.Parent = joyBase

	joyBase.Parent = joystickGui
	joystickGui.Parent = playerGui

	local function setThumb(clamped)
		joyThumb.Position = UDim2.new(0, 45 + clamped.X, 0, 45 + clamped.Y)
	end

	joyBase.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			joy.active = true
			joy.x = 0
			joy.y = 0
		end
	end)

	joyBase.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and joy.active then
			local basePos = joyBase.AbsolutePosition
			local baseSize = joyBase.AbsoluteSize
			local rel = input.Position - basePos - baseSize / 2
			local radius = baseSize.X / 2
			local mag = rel.Magnitude
			local clamped = rel
			if mag > radius then
				clamped = rel * (radius / mag)
			end
			joy.x = clamped.X / radius
			joy.y = -(clamped.Y / radius)
			setThumb(clamped)
		end
	end)

	joyBase.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			joy.active = false
			joy.x = 0
			joy.y = 0
			setThumb(Vector2.new(0, 0))
		end
	end)
end

buildJoystick()

-- ===================== SLAP AURA LOOP =====================

local function getTarget()
	local root = getHRP()
	if not root then return nil end
	local best = nil
	local bestDist = math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and not isFriend(p) then
			local ch = p.Character
			if ch then
				local hrp = ch:FindFirstChild("HumanoidRootPart")
				local hum = ch:FindFirstChildOfClass("Humanoid")
				if hrp and hum and hum.Health > 0 then
					local d = (hrp.Position - root.Position).Magnitude
					if d <= S.range and d < bestDist then
						best = hrp
						bestDist = d
					end
				end
			end
		end
	end
	return best
end

task.spawn(function()
	while GEN == _G.__PSGen do
		pcall(function()
			if S.enabled then
				local char = getChar()
				local tool = char and char:FindFirstChildOfClass("Tool")
				local root = getHRP()
				local target = getTarget()
				if tool and root and target then
					if S.aim then
						local look = target.Position - root.Position
						if look.Magnitude > 0.5 then
							root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
						end
					end
					fireSlap(tool)
				end
			end
		end)
		task.wait(S.delay)
	end
end)

-- ===================== FLY + NOCLIP LOOP =====================

local flyVel = nil
local noclipWasOn = false

local function restoreNoclip()
	local char = getChar()
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.CanCollide ~= true then
				part.CanCollide = true
			end
		end
	end
end

local function doNoclip()
	local char = getChar()
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.CanCollide ~= false then
				part.CanCollide = false
			end
		end
	end
end

local function forwardPlane(cam)
	if not cam then return Vector3.new(0, 0, -1), Vector3.new(1, 0, 0) end
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	local rvec = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
	return (look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)), (rvec.Magnitude > 0.01 and rvec.Unit or Vector3.new(1, 0, 0))
end

local function getMoveDir(cam)
	local fwd, right = forwardPlane(cam)
	local dir = Vector3.zero
	local useJoy = joy.active and (math.abs(joy.x) > 0.08 or math.abs(joy.y) > 0.08)
	if useJoy then
		dir = dir + fwd * joy.y + right * joy.x
	else
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + fwd end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - fwd end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then dir = dir - Vector3.new(0, 1, 0) end
	return dir
end

conn(RunService.Heartbeat, function()
	if S.fly then
		local hrp = getHRP()
		if hrp then
			if not flyVel or flyVel.Parent == nil then
				flyVel = Instance.new("BodyVelocity")
				flyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
				flyVel.Parent = hrp
			end
			local dir = getMoveDir(workspace.CurrentCamera)
			if dir.Magnitude > 0.001 then dir = dir.Unit end
			local vel = dir * S.flySpeed
			flyVel.Velocity = vel
			hrp.AssemblyLinearVelocity = vel
		end
	elseif flyVel and flyVel.Parent then
		pcall(flyVel.Destroy, flyVel)
		flyVel = nil
	end

	if S.noclip then
		doNoclip()
		noclipWasOn = true
	elseif noclipWasOn then
		restoreNoclip()
		noclipWasOn = false
	end
end)

conn(LocalPlayer.CharacterAdded, function(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum.WalkSpeed = S.walk
		applyJump(hum)
	end
	noclipWasOn = false
end)

conn(LocalPlayer.CharacterRemoving, function()
	if flyVel then pcall(flyVel.Destroy, flyVel) flyVel = nil end
	restoreNoclip()
	noclipWasOn = false
end)

-- ===================== ESP =====================

local espDraws = {}

local function disposeEsp(p)
	local objs = espDraws[p]
	if objs then
		for _, d in ipairs(objs) do pcall(d.Remove, d) end
		espDraws[p] = nil
	end
end

local function makeEspFor(p)
	local name = Drawing.new("Text")
	name.Outline = true
	name.Center = true
	name.Size = 16
	name.Font = 3

	local top, bottom, left, right = Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line")
	for _, ln in ipairs({ top, bottom, left, right }) do
		ln.Thickness = 1.5
		ln.Transparency = 1
	end

	local tracer = Drawing.new("Line")
	tracer.Thickness = 1
	tracer.Transparency = 1

	local objs = { name, top, bottom, left, right, tracer }
	espDraws[p] = objs
	return objs
end

conn(RunService.RenderStepped, function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local myRoot = getHRP()
	local viewport = cam.ViewportSize

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local objs = espDraws[p] or makeEspFor(p)
			local ch = p.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			local head = ch and ch:FindFirstChild("Head")
			local show = S.esp and hrp and hum and hum.Health > 0 and head
			local name, topL, bottomL, leftL, rightL, tracerL = unpack(objs)
			
			if show then
				local friend = isFriend(p)
				local boxColor = friend and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(96, 205, 255)
				local tracerColor = friend and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(255, 96, 96)
				local sTop, onScreen1 = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
				local sBot, onScreen2 = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 2.6, 0))

				if sTop.Z > 0 and sBot.Z > 0 and onScreen1 and onScreen2 then
					local hgt = math.max(12, math.abs(sTop.Y - sBot.Y))
					local wdt = hgt * 0.55
					local cx = (sTop.X + sBot.X) / 2
					local topY = math.min(sTop.Y, sBot.Y)

					name.Position = Vector2.new(cx, topY - 18)
					name.Color = Color3.fromRGB(255, 255, 255)
					local dist = myRoot and (hrp.Position - myRoot.Position).Magnitude or 0
					name.Text = p.Name .. " [" .. math.floor(dist) .. "m]"
					name.Visible = true

					topL.From, topL.To = Vector2.new(cx - wdt / 2, topY), Vector2.new(cx + wdt / 2, topY)
					bottomL.From, bottomL.To = Vector2.new(cx - wdt / 2, topY + hgt), Vector2.new(cx + wdt / 2, topY + hgt)
					leftL.From, leftL.To = Vector2.new(cx - wdt / 2, topY), Vector2.new(cx - wdt / 2, topY + hgt)
					rightL.From, rightL.To = Vector2.new(cx + wdt / 2, topY), Vector2.new(cx + wdt / 2, topY + hgt)

					for _, ln in ipairs({ topL, bottomL, leftL, rightL }) do
						ln.Color = boxColor
						ln.Visible = true
					end

					if S.tracer then
						tracerL.Color = tracerColor
						tracerL.From = Vector2.new(viewport.X / 2, viewport.Y)
						tracerL.To = Vector2.new(cx, topY + hgt / 2)
						tracerL.Visible = true
					else
						tracerL.Visible = false
					end
				else
					name.Visible = false
					for _, ln in ipairs({ topL, bottomL, leftL, rightL, tracerL }) do ln.Visible = false end
				end
			else
				name.Visible = false
				for _, ln in ipairs({ topL, bottomL, leftL, rightL, tracerL }) do ln.Visible = false end
			end
		end
	end

	for p in pairs(espDraws) do
		if not p.Parent then disposeEsp(p) end
	end
end)

-- ===================== PROXIMITY PROMPT & ANTI-AFK =====================

local prompts = {}
for _, v in ipairs(game:GetDescendants()) do
	if v:IsA("ProximityPrompt") then table.insert(prompts, v) end
end
conn(game.DescendantAdded, function(v)
	if v:IsA("ProximityPrompt") then table.insert(prompts, v) end
end)

conn(UserInputService.InputBegan, function(input)
	if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode ~= Enum.KeyCode.E or not S.instantInter then
		return
	end
	task.defer(function()
		local root = getHRP()
		if not root then return end
		for _, pr in ipairs(prompts) do
			if pr.Enabled and pr.Parent and pr.HoldDuration > 0 then
				local parent = pr.Parent
				local pos = parent:IsA("BasePart") and parent.Position or (parent:IsA("Model") and (parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")) and parent.PrimaryPart.Position)
				if pos and (root.Position - pos).Magnitude <= pr.MaxActivationDistance then
					pcall(function()
						pr:InputHoldBegan(LocalPlayer)
						task.wait()
						pr:InputHoldEnded(LocalPlayer)
					end)
					break
				end
			end
		end
	end)
end)

conn(LocalPlayer.Idled, function()
	if S.antiAfk then
		VirtualUser:CaptureController()
		VirtualUser:Button2Down(Vector2.zero)
		task.wait(0.5)
		VirtualUser:Button2Up(Vector2.zero)
	end
end)
