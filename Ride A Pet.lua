--[[
OzionHub - Ride A Pet Script
Recoded and updated from RevynHub
]]--
​local OzionHub = {}
OzionHub.Version = "2.0.0"
OzionHub.GameName = "Ride A Pet"
​function OzionHub:Initialize()
print("Initializing " .. OzionHub.GameName .. " script by OzionHub...")
-- Loading screen setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OzionHubLoading"
screenGui.ResetOnSpawn = false
​local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Text = "OzionHub - Egg Farm & ESP"
titleLabel.Size = UDim2.new(0, 400, 0, 50)
titleLabel.Position = UDim2.new(0.5, -200, 0.4, -25)
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = screenGui
​if game:GetService("CoreGui"):FindFirstChild("OzionHubLoading") then
game:GetService("CoreGui").OzionHubLoading:Destroy()
end
​screenGui.Parent = game:GetService("CoreGui")
task.wait(2)
screenGui:Destroy()
​print("OzionHub successfully loaded!")
end
​OzionHub:Initialize()
return OzionHub