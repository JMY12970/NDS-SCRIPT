--[[
    SAE_Obsidian_OneScript.client.lua

    ONE-SCRIPT Obsidian-style UI version.
    Put this single LocalScript in:
        StarterPlayer > StarterPlayerScripts

    No chat commands.
    No separate server script.
    No auth/admin check.
    Everyone gets the UI because it is inside StarterPlayerScripts.

    Important:
    - This is for YOUR OWN Roblox experience.
    - This does not bypass server anti-cheat.
    - Server-authoritative actions still depend on your game accepting normal character movement
      and normal ProximityPrompt interactions.
    - It does not scan/fire unknown RemoteEvents.
    - It does not use executor-only functions such as fireproximityprompt, hookmetamethod, getgc, etc.

    Features:
    - Built-in Obsidian-style UI library
    - Teleport to nearest egg
    - Tween to nearest egg
    - Tween speed box
    - Auto proximity prompt/interact
    - Auto steal eggs through nearby ProximityPrompts
    - Teleport to base/deposit
    - Auto teleport base/deposit
    - Local lighting/fullbright
    - Local FPS boost

    Toggle UI:
        RightShift
]]

--------------------
-- SERVICES
--------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

--------------------
-- CONFIG
--------------------

local CONFIG = {
    DEFAULT_TWEEN_SPEED = 75,
    MIN_TWEEN_SPEED = 16,
    MAX_TWEEN_SPEED = 220,
    TELEPORT_HEIGHT_OFFSET = 4.5,

    AUTO_STEP_SECONDS = 0.75,
    PROMPT_HOLD_EXTRA_SECONDS = 0.08,
    SEARCH_RADIUS = 10000,

    -- If true, Auto Prompt will move to the prompt before trying it.
    MOVE_TO_PROMPTS = true,

    -- If true, Auto Prompt prefers deposit prompts while carrying an egg.
    PREFER_DEPOSIT_WHEN_CARRYING = true,

    -- Scanning the entire workspace constantly can be expensive in large maps.
    -- This limits per-scan object checks.
    MAX_OBJECTS_PER_SCAN = 25000,
}

--------------------
-- STATE
--------------------

local State = {
    TweenSpeed = CONFIG.DEFAULT_TWEEN_SPEED,
    AutoPrompt = false,
    AutoSteal = false,
    AutoBase = false,
    BusyMoving = false,
    LastStatus = "Loaded.",
}

--------------------
-- SMALL UTILS
--------------------

local function setStatusText(text)
    State.LastStatus = tostring(text)
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function isAlive()
    local humanoid = getHumanoid()
    return humanoid and humanoid.Health > 0
end

local function distanceFromRoot(part)
    local root = getRoot()
    if not root or not part then
        return math.huge
    end
    return (root.Position - part.Position).Magnitude
end

local function lower(text)
    return string.lower(tostring(text or ""))
end

local function contains(text, needle)
    return string.find(lower(text), lower(needle), 1, true) ~= nil
end

local function getPromptPart(prompt)
    if not prompt or not prompt.Parent then
        return nil
    end

    if prompt.Parent:IsA("BasePart") then
        return prompt.Parent
    end

    return prompt.Parent:FindFirstAncestorWhichIsA("BasePart")
end

local function isInsideAnyCharacter(inst)
    local model = inst and inst:FindFirstAncestorOfClass("Model")
    if not model then
        return false
    end
    return Players:GetPlayerFromCharacter(model) ~= nil
end

local function isInsideLocalCharacter(inst)
    local character = getCharacter()
    return character and inst and inst:IsDescendantOf(character)
end

local function getPlayerFromPart(part)
    local model = part and part:FindFirstAncestorOfClass("Model")
    return model and Players:GetPlayerFromCharacter(model) or nil
end

--------------------
-- OBSIDIAN UI LIBRARY
--------------------

local Obsidian = {}
Obsidian.Theme = {
    Background = Color3.fromRGB(11, 11, 15),
    Window = Color3.fromRGB(17, 17, 24),
    Panel = Color3.fromRGB(25, 25, 34),
    Panel2 = Color3.fromRGB(32, 32, 44),
    Stroke = Color3.fromRGB(105, 82, 175),
    Accent = Color3.fromRGB(138, 92, 255),
    Accent2 = Color3.fromRGB(82, 214, 255),
    Text = Color3.fromRGB(246, 246, 252),
    Muted = Color3.fromRGB(166, 166, 184),
    Good = Color3.fromRGB(77, 236, 147),
    Bad = Color3.fromRGB(255, 92, 118),
}

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Obsidian.Theme.Stroke
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.15
    s.Parent = parent
    return s
end

local function padding(parent, amount)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, amount)
    p.PaddingBottom = UDim.new(0, amount)
    p.PaddingLeft = UDim.new(0, amount)
    p.PaddingRight = UDim.new(0, amount)
    p.Parent = parent
    return p
end

local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart = nil
    local startPos = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function Obsidian:CreateWindow(options)
    options = options or {}

    local gui = Instance.new("ScreenGui")
    gui.Name = options.Name or "ObsidianOneScriptUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local window = Instance.new("Frame")
    window.Name = "Window"
    window.AnchorPoint = Vector2.new(0, 0.5)
    window.Position = options.Position or UDim2.fromOffset(20, 320)
    window.Size = options.Size or UDim2.fromOffset(370, 550)
    window.BackgroundColor3 = Obsidian.Theme.Window
    window.Parent = gui
    corner(window, 16)
    stroke(window, Obsidian.Theme.Accent, 1.5, 0.08)

    local glow = Instance.new("ImageLabel")
    glow.Name = "Glow"
    glow.BackgroundTransparency = 1
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Position = UDim2.fromScale(0.5, 0.5)
    glow.Size = UDim2.new(1, 50, 1, 50)
    glow.Image = "rbxassetid://5028857084"
    glow.ImageColor3 = Obsidian.Theme.Accent
    glow.ImageTransparency = 0.72
    glow.ScaleType = Enum.ScaleType.Slice
    glow.SliceCenter = Rect.new(24, 24, 276, 276)
    glow.ZIndex = 0
    glow.Parent = window

    local topbar = Instance.new("Frame")
    topbar.Name = "Topbar"
    topbar.BackgroundColor3 = Obsidian.Theme.Background
    topbar.Size = UDim2.new(1, 0, 0, 54)
    topbar.ZIndex = 2
    topbar.Parent = window
    corner(topbar, 16)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(14, 7)
    title.Size = UDim2.new(1, -80, 0, 24)
    title.Text = options.Title or "Obsidian"
    title.TextColor3 = Obsidian.Theme.Text
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 3
    title.Parent = topbar

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.fromOffset(14, 31)
    subtitle.Size = UDim2.new(1, -80, 0, 18)
    subtitle.Text = options.Subtitle or "One Script UI"
    subtitle.TextColor3 = Obsidian.Theme.Muted
    subtitle.TextSize = 11
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 3
    subtitle.Parent = topbar

    local minimize = Instance.new("TextButton")
    minimize.Name = "Minimize"
    minimize.AnchorPoint = Vector2.new(1, 0)
    minimize.Position = UDim2.new(1, -12, 0, 12)
    minimize.Size = UDim2.fromOffset(30, 30)
    minimize.BackgroundColor3 = Obsidian.Theme.Panel
    minimize.Text = "–"
    minimize.TextColor3 = Obsidian.Theme.Text
    minimize.TextSize = 20
    minimize.Font = Enum.Font.GothamBold
    minimize.ZIndex = 4
    minimize.Parent = topbar
    corner(minimize, 8)
    stroke(minimize, Obsidian.Theme.Stroke, 1, 0.2)

    local body = Instance.new("ScrollingFrame")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.Position = UDim2.fromOffset(12, 66)
    body.Size = UDim2.new(1, -24, 1, -118)
    body.CanvasSize = UDim2.fromOffset(0, 0)
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    body.ScrollBarThickness = 4
    body.ScrollBarImageColor3 = Obsidian.Theme.Accent
    body.ZIndex = 2
    body.Parent = window

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = body

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.BackgroundTransparency = 1
    status.Position = UDim2.new(0, 14, 1, -40)
    status.Size = UDim2.new(1, -28, 0, 32)
    status.Text = "Loaded. RightShift toggles UI."
    status.TextColor3 = Obsidian.Theme.Muted
    status.TextSize = 12
    status.TextWrapped = true
    status.Font = Enum.Font.Gotham
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.ZIndex = 3
    status.Parent = window

    local minimized = false
    local fullSize = window.Size
    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        body.Visible = not minimized
        status.Visible = not minimized
        window.Size = minimized and UDim2.fromOffset(fullSize.X.Offset, 54) or fullSize
        minimize.Text = minimized and "+" or "–"
    end)

    makeDraggable(window, topbar)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.KeyCode == Enum.KeyCode.RightShift then
            window.Visible = not window.Visible
        end
    end)

    local api = {}
    api.Gui = gui
    api.Window = window
    api.Body = body
    api.Status = status

    function api:SetStatus(text)
        status.Text = tostring(text)
        setStatusText(text)
    end

    function api:Label(text)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -4, 0, 26)
        label.Text = text
        label.TextColor3 = Obsidian.Theme.Muted
        label.TextSize = 13
        label.Font = Enum.Font.GothamSemibold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 3
        label.Parent = body
        return label
    end

    function api:Button(text, callback)
        local button = Instance.new("TextButton")
        button.Name = text:gsub("%W", "")
        button.Size = UDim2.new(1, -4, 0, 38)
        button.BackgroundColor3 = Obsidian.Theme.Panel
        button.Text = text
        button.TextColor3 = Obsidian.Theme.Text
        button.TextSize = 14
        button.Font = Enum.Font.GothamSemibold
        button.AutoButtonColor = true
        button.ZIndex = 3
        button.Parent = body
        corner(button, 10)
        stroke(button, Obsidian.Theme.Stroke, 1, 0.22)

        button.MouseButton1Click:Connect(function()
            if callback then
                callback()
            end
        end)

        return button
    end

    function api:Toggle(text, default, callback)
        local enabled = default == true
        local button

        local function refresh()
            button.Text = (enabled and "[ON]  " or "[OFF] ") .. text
            button.TextColor3 = enabled and Obsidian.Theme.Good or Obsidian.Theme.Text
            button.BackgroundColor3 = enabled and Color3.fromRGB(28, 43, 37) or Obsidian.Theme.Panel
        end

        button = self:Button("", function()
            enabled = not enabled
            refresh()
            if callback then
                callback(enabled)
            end
        end)

        refresh()

        return {
            Button = button,
            Set = function(_, value, silent)
                enabled = value == true
                refresh()
                if callback and not silent then
                    callback(enabled)
                end
            end,
            Get = function()
                return enabled
            end,
        }
    end

    function api:TextBox(labelText, default, callback)
        local row = Instance.new("Frame")
        row.Name = labelText:gsub("%W", "") .. "Row"
        row.Size = UDim2.new(1, -4, 0, 38)
        row.BackgroundTransparency = 1
        row.ZIndex = 3
        row.Parent = body

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(0.42, -4, 1, 0)
        label.Text = labelText
        label.TextColor3 = Obsidian.Theme.Muted
        label.TextSize = 13
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 4
        label.Parent = row

        local box = Instance.new("TextBox")
        box.Position = UDim2.new(0.42, 4, 0, 0)
        box.Size = UDim2.new(0.58, -4, 1, 0)
        box.BackgroundColor3 = Obsidian.Theme.Panel
        box.Text = tostring(default or "")
        box.PlaceholderText = labelText
        box.TextColor3 = Obsidian.Theme.Text
        box.PlaceholderColor3 = Obsidian.Theme.Muted
        box.TextSize = 14
        box.Font = Enum.Font.GothamSemibold
        box.ClearTextOnFocus = false
        box.ZIndex = 4
        box.Parent = row
        corner(box, 10)
        stroke(box, Obsidian.Theme.Stroke, 1, 0.22)

        box.FocusLost:Connect(function(enterPressed)
            if callback then
                callback(box.Text, enterPressed)
            end
        end)

        return box
    end

    return api
end

--------------------
-- FINDERS
--------------------

local function looksLikeEgg(part)
    if not part or not part:IsA("BasePart") then
        return false
    end

    if isInsideLocalCharacter(part) then
        return false
    end

    if part:GetAttribute("Claimed") == true or part:GetAttribute("SAE_Carried") == true then
        return false
    end

    local owner = getPlayerFromPart(part)
    if owner ~= nil then
        return false
    end

    local name = lower(part.Name)
    local parentName = part.Parent and lower(part.Parent.Name) or ""

    return part:GetAttribute("IsEgg") == true
        or part:GetAttribute("EggName") ~= nil
        or part:GetAttribute("EggValue") ~= nil
        or string.find(name, "egg", 1, true) ~= nil
        or string.find(parentName, "egg", 1, true) ~= nil
end

local function findNearestEgg()
    local root = getRoot()
    if not root then
        return nil, math.huge
    end

    local best = nil
    local bestDistance = math.huge
    local checked = 0

    for _, inst in ipairs(workspace:GetDescendants()) do
        checked += 1
        if checked > CONFIG.MAX_OBJECTS_PER_SCAN then
            break
        end

        if looksLikeEgg(inst) then
            local d = (root.Position - inst.Position).Magnitude
            if d < bestDistance and d <= CONFIG.SEARCH_RADIUS then
                best = inst
                bestDistance = d
            end
        end
    end

    return best, bestDistance
end

local function promptText(prompt)
    if not prompt then
        return ""
    end
    return lower((prompt.ActionText or "") .. " " .. (prompt.ObjectText or "") .. " " .. (prompt.Name or ""))
end

local function promptMatches(prompt, mode)
    local text = promptText(prompt)
    local part = getPromptPart(prompt)
    local partName = part and lower(part.Name) or ""
    text = text .. " " .. partName

    if mode == "egg" then
        return contains(text, "egg") or contains(text, "grab") or contains(text, "pickup") or contains(text, "pick") or contains(text, "collect")
    elseif mode == "steal" then
        return contains(text, "steal")
    elseif mode == "deposit" then
        return contains(text, "deposit") or contains(text, "place") or contains(text, "base")
    elseif mode == "any" then
        return true
    end

    return false
end

local function findNearestPrompt(mode, requireInRange)
    local root = getRoot()
    if not root then
        return nil, nil, math.huge
    end

    local bestPrompt = nil
    local bestPart = nil
    local bestDistance = math.huge
    local checked = 0

    for _, inst in ipairs(workspace:GetDescendants()) do
        checked += 1
        if checked > CONFIG.MAX_OBJECTS_PER_SCAN then
            break
        end

        if inst:IsA("ProximityPrompt") and inst.Enabled and promptMatches(inst, mode) then
            local part = getPromptPart(inst)
            if part then
                local d = (root.Position - part.Position).Magnitude
                local maxD = (inst.MaxActivationDistance or 10) + 4
                if d < bestDistance and d <= CONFIG.SEARCH_RADIUS and (not requireInRange or d <= maxD) then
                    bestPrompt = inst
                    bestPart = part
                    bestDistance = d
                end
            end
        end
    end

    return bestPrompt, bestPart, bestDistance
end

local function isCarryingEgg()
    local character = getCharacter()
    if not character then
        return false
    end

    if character:FindFirstChild("CarriedEgg") then
        return true
    end

    for _, inst in ipairs(character:GetDescendants()) do
        if inst:IsA("BasePart") then
            local name = lower(inst.Name)
            if inst:GetAttribute("SAE_Carried") == true or contains(name, "carriedegg") or contains(name, "egg") then
                return true
            end
        end
    end

    return false
end

local function findDepositZone()
    local root = getRoot()
    if not root then
        return nil, math.huge
    end

    local best = nil
    local bestDistance = math.huge
    local checked = 0
    local localName = lower(LocalPlayer.Name)

    -- Prefer bases owned by attribute.
    for _, inst in ipairs(workspace:GetDescendants()) do
        checked += 1
        if checked > CONFIG.MAX_OBJECTS_PER_SCAN then
            break
        end

        if inst:IsA("Model") and tonumber(inst:GetAttribute("OwnerUserId")) == LocalPlayer.UserId then
            for _, d in ipairs(inst:GetDescendants()) do
                if d:IsA("BasePart") and (contains(d.Name, "deposit") or contains(d.Name, "place") or contains(d.Name, "base")) then
                    return d, (root.Position - d.Position).Magnitude
                end
            end
            if inst.PrimaryPart then
                return inst.PrimaryPart, (root.Position - inst.PrimaryPart.Position).Magnitude
            end
        end
    end

    checked = 0
    for _, inst in ipairs(workspace:GetDescendants()) do
        checked += 1
        if checked > CONFIG.MAX_OBJECTS_PER_SCAN then
            break
        end

        if inst:IsA("BasePart") then
            local n = lower(inst.Name)
            local parentN = inst.Parent and lower(inst.Parent.Name) or ""
            local good = contains(n, "deposit") or contains(n, "place") or contains(n, "base")
            local personal = contains(n, localName) or contains(parentN, localName)

            if good then
                local d = (root.Position - inst.Position).Magnitude
                if personal then
                    d -= 100 -- prefer personal-looking base parts
                end
                if d < bestDistance then
                    best = inst
                    bestDistance = d
                end
            end
        end
    end

    return best, bestDistance
end

local function findNearestCarriedEggOrStealPrompt()
    local prompt, part, dist = findNearestPrompt("steal", false)
    if prompt and part then
        return "prompt", prompt, part, dist
    end

    local root = getRoot()
    if not root then
        return nil
    end

    local bestPart = nil
    local bestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            for _, inst in ipairs(player.Character:GetDescendants()) do
                if inst:IsA("BasePart") then
                    local n = lower(inst.Name)
                    if contains(n, "egg") or inst:GetAttribute("SAE_Carried") == true then
                        local d = (root.Position - inst.Position).Magnitude
                        if d < bestDistance and d <= CONFIG.SEARCH_RADIUS then
                            bestPart = inst
                            bestDistance = d
                        end
                    end
                end
            end
        end
    end

    if bestPart then
        return "part", nil, bestPart, bestDistance
    end

    return nil
end

--------------------
-- MOVEMENT / PROMPTS
--------------------

local function pivotToPosition(position)
    local character = getCharacter()
    if not character then
        return false
    end

    character:PivotTo(CFrame.new(position))
    return true
end

local function teleportToPart(part)
    if not part then
        return false
    end
    return pivotToPosition(part.Position + Vector3.new(0, CONFIG.TELEPORT_HEIGHT_OFFSET, 0))
end

local function tweenToPart(part)
    if State.BusyMoving then
        return false
    end

    local character = getCharacter()
    local root = getRoot()
    if not character or not root or not part then
        return false
    end

    State.BusyMoving = true

    local target = part.Position + Vector3.new(0, CONFIG.TELEPORT_HEIGHT_OFFSET, 0)
    local speed = math.clamp(tonumber(State.TweenSpeed) or CONFIG.DEFAULT_TWEEN_SPEED, CONFIG.MIN_TWEEN_SPEED, CONFIG.MAX_TWEEN_SPEED)
    local startTime = os.clock()

    while isAlive() and character.Parent and root.Parent do
        local current = root.Position
        local delta = target - current
        local d = delta.Magnitude

        if d <= 3 then
            break
        end

        if os.clock() - startTime > 40 then
            break
        end

        local dt = RunService.Heartbeat:Wait()
        local step = math.min(d, speed * dt)
        local nextPosition = current + delta.Unit * step
        character:PivotTo(CFrame.new(nextPosition, target))
    end

    if character.Parent then
        character:PivotTo(CFrame.new(target))
    end

    State.BusyMoving = false
    return true
end

local function activatePrompt(prompt)
    if not prompt or not prompt.Enabled then
        return false, "No prompt."
    end

    local okBegin, errBegin = pcall(function()
        prompt:InputHoldBegin()
    end)

    if not okBegin then
        return false, "Prompt activation blocked: " .. tostring(errBegin)
    end

    local holdTime = tonumber(prompt.HoldDuration) or 0
    task.wait(math.max(0.05, holdTime + CONFIG.PROMPT_HOLD_EXTRA_SECONDS))

    local okEnd, errEnd = pcall(function()
        prompt:InputHoldEnd()
    end)

    if not okEnd then
        return false, "Prompt release blocked: " .. tostring(errEnd)
    end

    return true, "Prompt activated."
end

local function moveToPromptAndActivate(prompt, part)
    if not prompt then
        return false
    end

    part = part or getPromptPart(prompt)
    if CONFIG.MOVE_TO_PROMPTS and part then
        tweenToPart(part)
        task.wait(0.08)
    end

    local ok, message = activatePrompt(prompt)
    setStatusText(message)
    return ok
end

--------------------
-- ACTIONS
--------------------

local function teleportNearestEgg()
    local egg = findNearestEgg()
    if egg and teleportToPart(egg) then
        return true, "Teleported to nearest egg."
    end
    return false, "No egg found."
end

local function tweenNearestEgg()
    local egg = findNearestEgg()
    if egg then
        tweenToPart(egg)
        return true, "Tweened to nearest egg."
    end
    return false, "No egg found."
end

local function promptNearestEgg()
    local prompt, part = findNearestPrompt("egg", false)
    if prompt then
        return moveToPromptAndActivate(prompt, part), "Tried egg prompt."
    end

    local egg = findNearestEgg()
    if egg then
        tweenToPart(egg)
        task.wait(0.1)
        prompt, part = findNearestPrompt("egg", true)
        if prompt then
            return moveToPromptAndActivate(prompt, part), "Tried egg prompt."
        end
        return true, "Moved to egg. Press interact if needed."
    end

    return false, "No egg prompt found."
end

local function autoPromptOnce()
    local mode = "any"

    if CONFIG.PREFER_DEPOSIT_WHEN_CARRYING and isCarryingEgg() then
        mode = "deposit"
    end

    local prompt, part = findNearestPrompt(mode, false)
    if prompt then
        local ok = moveToPromptAndActivate(prompt, part)
        return ok, ok and "Auto prompt activated." or "Prompt activation failed."
    end

    return false, "No prompt found."
end

local function autoStealOnce()
    local kind, prompt, part = findNearestCarriedEggOrStealPrompt()

    if kind == "prompt" and prompt then
        local ok = moveToPromptAndActivate(prompt, part)
        return ok, ok and "Tried steal prompt." or "Steal prompt failed."
    elseif kind == "part" and part then
        tweenToPart(part)
        task.wait(0.1)
        prompt, part = findNearestPrompt("steal", true)
        if prompt then
            local ok = moveToPromptAndActivate(prompt, part)
            return ok, ok and "Tried steal prompt." or "Steal prompt failed."
        end
        return true, "Moved to carried egg. No steal prompt found nearby."
    end

    return false, "No steal target found."
end

local function teleportBase()
    local zone = findDepositZone()
    if zone and teleportToPart(zone) then
        return true, "Teleported to base/deposit."
    end
    return false, "No base/deposit found."
end

local function autoBaseOnce()
    local prompt, part = findNearestPrompt("deposit", false)
    if prompt then
        local ok = moveToPromptAndActivate(prompt, part)
        return ok, ok and "Tried deposit prompt." or "Deposit prompt failed."
    end

    local zone = findDepositZone()
    if zone then
        tweenToPart(zone)
        task.wait(0.1)
        prompt, part = findNearestPrompt("deposit", true)
        if prompt then
            local ok = moveToPromptAndActivate(prompt, part)
            return ok, ok and "Tried deposit prompt." or "Deposit prompt failed."
        end
        return true, "Moved to base/deposit. Press interact if needed."
    end

    return false, "No base/deposit found."
end

--------------------
-- VISUALS
--------------------

local OriginalLighting = nil

local function setFullbright(enabled)
    if enabled then
        if not OriginalLighting then
            OriginalLighting = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                FogEnd = Lighting.FogEnd,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
            }
        end

        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    elseif OriginalLighting then
        for key, value in pairs(OriginalLighting) do
            pcall(function()
                Lighting[key] = value
            end)
        end
    end
end

local FpsBoostDone = false

local function applyFpsBoost()
    if FpsBoostDone then
        return 0, "FPS boost already applied. Rejoin to fully restore visuals."
    end

    FpsBoostDone = true
    local changed = 0

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.Brightness = math.max(Lighting.Brightness, 2)
    end)

    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        pcall(function()
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
        end)
    end

    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles") then
            pcall(function()
                inst.Enabled = false
                changed += 1
            end)
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            pcall(function()
                inst.Transparency = 1
                changed += 1
            end)
        elseif inst:IsA("BasePart") then
            pcall(function()
                inst.Material = Enum.Material.SmoothPlastic
                inst.Reflectance = 0
                changed += 1
            end)
        end
    end

    return changed, "FPS boost applied locally. Optimized " .. tostring(changed) .. " objects."
end

--------------------
-- BUILD UI
--------------------

local Window = Obsidian:CreateWindow({
    Name = "SAE_Obsidian_OneScript",
    Title = "Steal An Egg",
    Subtitle = "Obsidian One-Script UI",
    Size = UDim2.fromOffset(370, 550),
})

local function runAction(callback)
    task.spawn(function()
        if not isAlive() then
            Window:SetStatus("Character not ready.")
            return
        end
        local ok, message = callback()
        Window:SetStatus(message or (ok and "Done." or "Failed."))
    end)
end

Window:Label("Movement")

Window:Button("Teleport to Nearest Egg", function()
    runAction(teleportNearestEgg)
end)

Window:Button("Tween to Nearest Egg", function()
    runAction(tweenNearestEgg)
end)

Window:TextBox("Tween Speed", tostring(CONFIG.DEFAULT_TWEEN_SPEED), function(text)
    local n = tonumber(text) or CONFIG.DEFAULT_TWEEN_SPEED
    State.TweenSpeed = math.clamp(n, CONFIG.MIN_TWEEN_SPEED, CONFIG.MAX_TWEEN_SPEED)
    Window:SetStatus("Tween speed set to " .. tostring(math.floor(State.TweenSpeed)) .. " studs/sec.")
end)

Window:Button("Teleport to Base / Deposit", function()
    runAction(teleportBase)
end)

Window:Label("Egg Actions")

Window:Button("Pickup / Grab Nearest Egg", function()
    runAction(promptNearestEgg)
end)

Window:Button("Auto Proximity Prompt Once", function()
    runAction(autoPromptOnce)
end)

Window:Button("Steal Nearest Egg Once", function()
    runAction(autoStealOnce)
end)

Window:Button("Deposit / Place Once", function()
    runAction(autoBaseOnce)
end)

Window:Toggle("Auto Proximity Prompt", false, function(on)
    State.AutoPrompt = on
    Window:SetStatus("Auto proximity prompt: " .. (on and "ON" or "OFF"))
end)

Window:Toggle("Auto Steal Eggs", false, function(on)
    State.AutoSteal = on
    Window:SetStatus("Auto steal eggs: " .. (on and "ON" or "OFF"))
end)

Window:Toggle("Auto Teleport Base / Deposit", false, function(on)
    State.AutoBase = on
    Window:SetStatus("Auto base/deposit: " .. (on and "ON" or "OFF"))
end)

Window:Label("Client Visuals")

Window:Toggle("Lighting / Fullbright", false, function(on)
    setFullbright(on)
    Window:SetStatus("Fullbright: " .. (on and "ON" or "OFF"))
end)

Window:Button("FPS Boost", function()
    task.spawn(function()
        local _, message = applyFpsBoost()
        Window:SetStatus(message)
    end)
end)

Window:Label("RightShift hides/shows the UI. One LocalScript only.")

--------------------
-- AUTO LOOPS
--------------------

task.spawn(function()
    while true do
        task.wait(CONFIG.AUTO_STEP_SECONDS)

        if not isAlive() then
            continue
        end

        if State.BusyMoving then
            continue
        end

        if State.AutoBase and isCarryingEgg() then
            local ok, msg = autoBaseOnce()
            if msg then
                Window:SetStatus(msg)
            end
            task.wait(0.15)
        end

        if State.AutoSteal and not isCarryingEgg() then
            local ok, msg = autoStealOnce()
            if msg then
                Window:SetStatus(msg)
            end
            task.wait(0.15)
        end

        if State.AutoPrompt then
            local ok, msg = autoPromptOnce()
            if msg then
                Window:SetStatus(msg)
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    Window:SetStatus("Character loaded. RightShift hides/shows UI.")
end)

Window:SetStatus("Loaded. Put this one LocalScript in StarterPlayerScripts.")
