local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
​local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local parentGui = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or CoreGui or PlayerGui
​for _, old in ipairs(parentGui:GetChildren()) do
if old.Name:find("OzionHub") or old.Name:find("Kennys") then
old:Destroy()
end
end
​local Modules = ReplicatedStorage:FindFirstChild("Modules")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
​local Checkout = Remotes and Remotes:FindFirstChild("Checkout")
local PamphletsRemotes = Remotes and Remotes:FindFirstChild("Pamphlets")
local EnclosuresRemotes = Remotes and Remotes:FindFirstChild("Enclosures")
local BatRemotes = Remotes and Remotes:FindFirstChild("Bat")
local MessRemotes = Remotes and Remotes:FindFirstChild("Mess")
​local CheckoutController = Modules and Modules:FindFirstChild("CheckoutController") and require(Modules.CheckoutController)
local CheckoutGamepad = Modules and Modules:FindFirstChild("CheckoutGamepad") and require(Modules.CheckoutGamepad)
local CheckoutMoney = Modules and Modules:FindFirstChild("CheckoutMoney") and require(Modules.CheckoutMoney)
local PedestrianController = Modules and Modules:FindFirstChild("PedestrianController") and require(Modules.PedestrianController)
​local WalkersTable = (PedestrianController and debug and debug.getupvalue) and pcall(function() return debug.getupvalue(PedestrianController.walkerNearRay, 1) end) or nil
​local ScanCurrentRE = Checkout and Checkout:FindFirstChild("ScanCurrent")
local AcceptPresentedPaymentRE = Checkout and Checkout:FindFirstChild("AcceptPresentedPayment")
local SubmitCashChangeRE = Checkout and Checkout:FindFirstChild("SubmitCashChange")
local SubmitCardAmountRE = Checkout and Checkout:FindFirstChild("SubmitCardAmount")
​local GrabPamphletRE = PamphletsRemotes and PamphletsRemotes:FindFirstChild("Grab")
local GivePamphletRE = PamphletsRemotes and PamphletsRemotes:FindFirstChild("Give")
​local MaintainRE = EnclosuresRemotes and EnclosuresRemotes:FindFirstChild("Maintain")
local CleanMessRE = MessRemotes and MessRemotes:FindFirstChild("Clean")
local SwingBatRE = BatRemotes and BatRemotes:FindFirstChild("Swing")
​local Config = {
AutoCheckout = false,
ScanDelay = 0.08,
PaymentDelay = 0.12,
LastScanTime = 0,
LastPaymentTime = 0,
LastEnterAttempt = 0,
AutoPamphlets = false,
AutoTeleportWalkers = false,
AutoGrabPamphlets = false,
LastPamphletTime = 0,
LastGrabTime = 0,
LastTeleportTime = 0,
ToggleKey = Enum.KeyCode.RightControl,
AutoLoadConfig = true
}
​local DenomHierarchy = {
{ id = "bill100", cents = 10000 },
{ id = "bill50", cents = 5000 },
{ id = "bill20", cents = 2000 },
{ id = "bill10", cents = 1000 },
{ id = "bill5", cents = 500 },
{ id = "bill1", cents = 100 },
{ id = "coin50", cents = 50 },
{ id = "coin25", cents = 25 },
{ id = "coin10", cents = 10 },
{ id = "coin5", cents = 5 },
{ id = "coin1", cents = 1 }
}
​local function calculateExactChange(centsDue)
local counts = {}
local remaining = centsDue or 0
for _, denom in ipairs(DenomHierarchy) do
if remaining >= denom.cents then
local count = math.floor(remaining / denom.cents)
counts[denom.id] = count
remaining = remaining - (count * denom.cents)
end
end
return counts
end
​local function getMyPlot()
local plots = workspace:FindFirstChild("Plots")
if not plots then return nil end
for _, plot in ipairs(plots:GetChildren()) do
if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId or plot:GetAttribute("Owner") == LocalPlayer.Name or plot.Name:find(LocalPlayer.Name) then
return plot
end
end
for _, plot in ipairs(plots:GetChildren()) do
if plot:FindFirstChild("Checkout") then
return plot
end
end
return nil
end
​local function getPamphletStand()
local plot = getMyPlot()
if not plot then return nil end
local items = plot:FindFirstChild("Items")
if items and items:FindFirstChild("PamphletStand") then
return items:FindFirstChild("PamphletStand")
end
return plot:FindFirstChild("PamphletStand")
end
​local function enterRegister(till)
if not till then return end
local char = LocalPlayer.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
local playerPoint = till:FindFirstChild("PlayerPoint")
local screen = till:FindFirstChild("RegisterScreen") or till:FindFirstChild("Computer") or till:FindFirstChild("Desk")
​if hrp and playerPoint and screen then
hrp.CFrame = CFrame.lookAt(playerPoint.Position + Vector3.new(0, 1, 0), screen.Position)
local cam = workspace.CurrentCamera
if cam then
cam.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(0, 1.5, 0), screen.Position)
end
VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
task.wait(0.05)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end
end
​local Obsidian = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Obsidian.lua"))()
​local Window = Obsidian:CreateWindow({
Title = "OzionHub",
SubTitle = "Pet Store Automation",
TabWidth = 150,
Size = UDim2.fromOffset(560, 400),
Theme = "Dark"
})
​local RegisterTab = Window:AddTab("Register")
​RegisterTab:AddToggle({
Name = "Auto Checkout (Scan & Pay)",
Default = Config.AutoCheckout,
Callback = function(val)
Config.AutoCheckout = val
end
})
​RegisterTab:AddButton({
Name = "⚡ Hop On Register (Auto E)",
Callback = function()
local plot = getMyPlot()
local till = plot and plot:FindFirstChild("Checkout")
enterRegister(till)
end
})
​local PamphletTab = Window:AddTab("Pamphlets")
​PamphletTab:AddToggle({
Name = "⚡ Fast Auto-Teleport to Walkers & Give",
Default = Config.AutoTeleportWalkers,
Callback = function(val)
Config.AutoTeleportWalkers = val
Config.AutoPamphlets = val
end
})
​PamphletTab:AddToggle({
Name = "Auto-Give Pamphlets (Aura Only)",
Default = Config.AutoPamphlets,
Callback = function(val)
Config.AutoPamphlets = val
end
})
​PamphletTab:AddToggle({
Name = "Auto-Refill At Pamphlet Stand",
Default = Config.AutoGrabPamphlets,
Callback = function(val)
Config.AutoGrabPamphlets = val
end
})
​PamphletTab:AddButton({
Name = "⚡ Teleport to Stand & Refill",
Callback = function()
local stand = getPamphletStand()
local char = LocalPlayer.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
if stand and hrp then
hrp.CFrame = stand:GetPivot() + Vector3.new(0, 3, 0)
if GrabPamphletRE then
GrabPamphletRE:FireServer()
end
end
end
})
​local SettingsTab = Window:AddTab("Settings")
​SettingsTab:AddKeybind({
Name = "Toggle UI Keybind",
Default = Config.ToggleKey,
Callback = function(key)
Config.ToggleKey = key
end
})
​local DeliveredWalkers = {}
​RunService.Heartbeat:Connect(function()
local char = LocalPlayer.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
local plot = (getMyPlot and getMyPlot()) or nil
local till = (CheckoutController and CheckoutController.getMannedTill and CheckoutController.getMannedTill()) or (plot and plot:FindFirstChild("Checkout"))
local isManning = CheckoutController and CheckoutController.isManning and CheckoutController.isManning()
local state = CheckoutController and CheckoutController.getState and CheckoutController.getState()
local pamphletCount = LocalPlayer:GetAttribute("Pamphlets") or 0
​if Config.AutoPamphlets and hrp then
if pamphletCount <= 0 and Config.AutoGrabPamphlets then
local now = tick()
if now - Config.LastGrabTime >= 0.8 then
Config.LastGrabTime = now
local stand = getPamphletStand()
if Config.AutoTeleportWalkers and stand then
hrp.CFrame = stand:GetPivot() + Vector3.new(0, 3, 0)
end
pcall(function()
GrabPamphletRE:FireServer()
end)
end
end
​if pamphletCount > 0 and WalkersTable then
local now = tick()
​if Config.AutoTeleportWalkers and (now - Config.LastTeleportTime >= 0.28) then
local bestWalker = nil
local bestId = nil
local bestDist = 9999
​local myPos = hrp.Position
for id, walker in pairs(WalkersTable) do
if walker.root and not walker.ragdolled and not DeliveredWalkers[id] then
local d = (walker.root.Position - myPos).Magnitude
if d < bestDist then
bestDist = d
bestWalker = walker
bestId = id
end
end
end
​if not bestWalker then
DeliveredWalkers = {}
for id, walker in pairs(WalkersTable) do
if walker.root and not walker.ragdolled then
bestWalker = walker
bestId = id
break
end
end
end
​if bestWalker and bestWalker.root then
Config.LastTeleportTime = now
DeliveredWalkers[bestId] = true
​hrp.CFrame = CFrame.lookAt(bestWalker.root.Position + (bestWalker.root.CFrame.LookVector * 2.5) + Vector3.new(0, 0.5, 0), bestWalker.root.Position)
workspace.CurrentCamera.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(0, 1.5, 0), bestWalker.root.Position)
​GivePamphletRE:FireServer(bestId)
end
​elseif not Config.AutoTeleportWalkers and (now - Config.LastPamphletTime >= 0.3) then
local myPos = hrp.Position
for walkerId, walker in pairs(WalkersTable) do
local root = walker.root
if root and not walker.ragdolled then
if (root.Position - myPos).Magnitude <= 12 then
Config.LastPamphletTime = now
GivePamphletRE:FireServer(walkerId)
break
end
end
end
end
end
end
​if Config.AutoCheckout and not Config.AutoTeleportWalkers then
if not isManning and till and hrp then
local pivot = till:GetPivot()
local dist = (pivot.Position - hrp.Position).Magnitude
if dist <= 12 then
local now = tick()
if now - Config.LastEnterAttempt >= 1.0 then
Config.LastEnterAttempt = now
enterRegister(till)
end
end
return
end
​if isManning and state then
local phase = state.phase
​if phase == "Scanning" then
local now = tick()
if now - Config.LastScanTime >= Config.ScanDelay then
Config.LastScanTime = now
local itemToScan = CheckoutGamepad.nextItem(till, (state.scannedCount or 0) + 1, state.transactionId, state.scannedIndices)
if itemToScan then
pcall(function()
ScanCurrentRE:FireServer(itemToScan, state.transactionId, itemToScan:GetAttribute("CheckoutItemIndex"))
end)
end
end
​elseif phase == "AwaitingPayment" then
local now = tick()
if now - Config.LastPaymentTime >= Config.PaymentDelay then
Config.LastPaymentTime = now
pcall(function()
AcceptPresentedPaymentRE:FireServer(true)
end)
end
​elseif phase == "CashChange" then
local changeDue = state.changeDueCents or 0
local now = tick()
if now - Config.LastPaymentTime >= Config.PaymentDelay then
Config.LastPaymentTime = now
local changeBreakdown = calculateExactChange(changeDue)
pcall(function()
SubmitCashChangeRE:FireServer(changeBreakdown)
end)
end
​elseif phase == "CardEntry" then
local totalCents = state.totalCents or 0
local now = tick()
if now - Config.LastPaymentTime >= Config.PaymentDelay then
Config.LastPaymentTime = now
pcall(function()
SubmitCardAmountRE:FireServer(totalCents)
end)
end
end
end
end
end)
​LocalPlayer.Idled:Connect(function()
VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
task.wait(0.1)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
end)
​print("[OzionHub] Pet Store edition deployed successfully!")
return true