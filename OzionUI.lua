--[[
    ██████╗ ███████╗ ██████╗ ██╗  ██╗██╗   ██╗███████╗██╗
    ██╔═══██╗██╔════╝██╔════██╗██║ ██╔╝██║   ██║██╔════╝██║
    ██║   ██║█████╗  ██║   ██║█████╔╝ ██║   ██║███████╗██║
    ██║   ██║██╔══╝  ██║   ██║██╔═██╗ ██║   ██║╚════██║██║
    ╚██████╔╝███████╗╚██████╔╝██║  ██╗╚██████╔╝███████║███████╗
     ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝

    OzionUI v1.0.0
    A sleek, heavily-animated UI library for Roblox script executors.
    API modelled after the Obsidian library - but faster, prettier and animated everywhere.

    ─────────────────────────────────────────────────────────────────────────────
    QUICK START (executor):

        local OzionUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOURNAME/YOURREPO/main/OzionUI.lua"))()

        local Window = OzionUI:CreateWindow({
            Title = "OzionUI",
            SubTitle = "v1.0",
            Size = UDim2.fromOffset(590, 460),
            TabWidth = 150,
            Key = Enum.KeyCode.RightControl,  -- show / hide the UI
        })

        local Tab   = Window:AddTab({ Title = "Main", Icon = "🏠" })
        local Section = Tab:AddSection({ Title = "General" })

        Section:AddToggle({
            Title = "Enable godmode",
            Default = false,
            Flag = "godmode",               -- used by the config system
            Callback = function(value) end,
        })

        OzionUI:Notification({ Title = "Welcome", Description = "Hello :)", Duration = 4 })

    See README.md for the full API and GUIDE.md to learn how to build your own
    library on top of this one.
    ─────────────────────────────────────────────────────────────────────────────
]]

--------------------------------------------------------------------------------
-- Services
--------------------------------------------------------------------------------

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")

--------------------------------------------------------------------------------
-- Constants & small utilities (works on Roblox AND every major executor)
--------------------------------------------------------------------------------

local VERSION = "1.0.0"

local FONT_TITLE = Enum.Font.GothamBold
local FONT_BODY  = Enum.Font.GothamMedium
local FONT_SMALL = Enum.Font.Gotham

local _floor = math.floor

-- Luau helpers with Lua 5.1 fallbacks so the file also parses/runs anywhere
local clamp = math.clamp or function(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local tableFind = table.find or function(list, value)
    for index = 1, #list do
        if list[index] == value then return index end
    end
    return nil
end

-- `typeof` exists on Roblox / executors; the fallback keeps the mock test-harness happy
local TypeOf = typeof or function(value)
    if type(value) == "table" and value.__type then return value.__type end
    return type(value)
end

local function Round(value, decimals)
    local multiplier = 10 ^ (decimals or 0)
    return _floor(value * multiplier + 0.5) / multiplier
end

-- Runs a user callback without ever letting an error kill the UI
local function SafeCallback(callback, ...)
    if type(callback) == "function" then
        local ok, err = pcall(callback, ...)
        if not ok then
            warn("[OzionUI] element callback error: " .. tostring(err))
        end
    end
end

--------------------------------------------------------------------------------
-- Library state
--------------------------------------------------------------------------------

local Library = {
    Version    = VERSION,
    Windows    = {},
    Flags      = {},   -- flag name -> element (used by the config system)
    Themes     = {},   -- named presets, see below
    _alive     = true,
    _rainbow   = false,
    _rainbowHue  = 0,
    _rainbowAccum = 0,
    _fps       = 0,
    _fpsAverage = 60,
    _connections = {},  -- library-level connections (cleaned up on Destroy)
    _popovers    = {},  -- open color-picker popovers
    _keybinds    = {},  -- registered keybind elements
    _listeningKeybind = nil, -- keybind currently waiting for a key press
    _typing      = false,    -- true while one of our textboxes is focused
}

--------------------------------------------------------------------------------
-- Theming
-- Every colored property is registered as a "binding"; when the theme changes
-- we simply re-evaluate every binding. Bindings whose instance was destroyed
-- are removed automatically.
--------------------------------------------------------------------------------

local DefaultTheme = {
    Accent        = Color3.fromRGB(138, 99, 255),
    Background    = Color3.fromRGB(19, 19, 26),
    Topbar        = Color3.fromRGB(24, 24, 33),
    Section       = Color3.fromRGB(26, 26, 36),
    SectionStroke = Color3.fromRGB(45, 45, 62),
    Element       = Color3.fromRGB(33, 33, 46),
    ElementHover  = Color3.fromRGB(44, 44, 61),
    RowHover      = Color3.fromRGB(255, 255, 255),
    Text          = Color3.fromRGB(236, 236, 246),
    SubText       = Color3.fromRGB(156, 156, 176),
    Stroke        = Color3.fromRGB(48, 48, 65),
    ToggleOff     = Color3.fromRGB(58, 58, 78),
    SliderTrack   = Color3.fromRGB(45, 45, 62),
    Knob          = Color3.fromRGB(246, 246, 252),
    Success       = Color3.fromRGB(96, 205, 130),
    Error         = Color3.fromRGB(235, 92, 105),
    Warning       = Color3.fromRGB(245, 180, 85),
}

-- live theme table (mutated in place so bindings stay valid)
local Theme = {}
for key, value in pairs(DefaultTheme) do Theme[key] = value end

local function MakeTheme(overrides)
    local theme = {}
    for key, value in pairs(DefaultTheme) do theme[key] = value end
    for key, value in pairs(overrides or {}) do theme[key] = value end
    return theme
end

Library.Themes = {
    Midnight = MakeTheme(),
    Amethyst = MakeTheme({ Accent = Color3.fromRGB(172, 122, 255), Background = Color3.fromRGB(24, 20, 34), Topbar = Color3.fromRGB(29, 24, 41) }),
    Ocean    = MakeTheme({ Accent = Color3.fromRGB(70, 150, 255), Background = Color3.fromRGB(16, 21, 32), Topbar = Color3.fromRGB(20, 26, 40) }),
    Emerald  = MakeTheme({ Accent = Color3.fromRGB(72, 199, 142), Background = Color3.fromRGB(15, 24, 21), Topbar = Color3.fromRGB(19, 29, 26) }),
    Sakura   = MakeTheme({ Accent = Color3.fromRGB(245, 130, 175), Background = Color3.fromRGB(27, 20, 26), Topbar = Color3.fromRGB(33, 25, 32) }),
    Sunset   = MakeTheme({ Accent = Color3.fromRGB(255, 122, 89), Background = Color3.fromRGB(28, 20, 18), Topbar = Color3.fromRGB(34, 25, 22) }),
    Carbon   = MakeTheme({ Accent = Color3.fromRGB(163, 169, 181), Background = Color3.fromRGB(21, 21, 24), Topbar = Color3.fromRGB(26, 26, 30) }),
}

local ThemeBindings = {}

-- BindTheme(frame, "BackgroundColor3", "Accent")            -- static theme key
-- BindTheme(frame, "BackgroundColor3", function() ... end)  -- dynamic evaluator
local function BindTheme(object, property, keyOrFn)
    local evaluator
    if type(keyOrFn) == "function" then
        evaluator = keyOrFn
    else
        evaluator = function() return Theme[keyOrFn] end
    end
    local entry = { obj = object, prop = property, get = evaluator }
    local ok = pcall(function() object[property] = evaluator() end)
    if ok then
        table.insert(ThemeBindings, entry)
    end
    return entry
end

local function ApplyTheme(overrides)
    if type(overrides) == "table" then
        for key, value in pairs(overrides) do Theme[key] = value end
    end
    for i = #ThemeBindings, 1, -1 do
        local entry = ThemeBindings[i]
        if entry.obj.Parent == nil then
            table.remove(ThemeBindings, i)
        else
            local ok = pcall(function() entry.obj[entry.prop] = entry.get() end)
            if not ok then table.remove(ThemeBindings, i) end
        end
    end
end

local function SetAccent(color)
    ApplyTheme({ Accent = color })
end

--------------------------------------------------------------------------------
-- Executor compatibility (gui parenting)
--------------------------------------------------------------------------------

local RootParentCache

local function GetRootParent()
    if RootParentCache then return RootParentCache end
    -- 1) gethui() - best option on modern executors
    local ok, hidden = pcall(function()
        if type(gethui) == "function" then return gethui() end
    end)
    if ok and hidden then
        RootParentCache = hidden
        return hidden
    end
    -- 2) CoreGui (optionally protected by syn.protect_gui)
    local ok2, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and coreGui then
        RootParentCache = coreGui
        return coreGui
    end
    -- 3) PlayerGui (some environments)
    local ok3, playerGui = pcall(function()
        return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end)
    if ok3 and playerGui then
        RootParentCache = playerGui
        return playerGui
    end
    return game:GetService("CoreGui")
end

local function ProtectGui(gui)
    if syn and syn.protect_gui then
        pcall(function() syn.protect_gui(gui) end)
    end
end

--------------------------------------------------------------------------------
-- Misc helpers
--------------------------------------------------------------------------------

local function GetViewport()
    local ok, size = pcall(function() return Workspace.CurrentCamera.ViewportSize end)
    if ok and size then return size end
    return Vector2.new(1920, 1080)
end

local function IsPointInFrame(frame)
    local ok, point = pcall(function() return UserInputService:GetMouseLocation() end)
    if not ok or not point then return true end -- fail-safe: never close on error
    local pos, size = frame.AbsolutePosition, frame.AbsoluteSize
    return point.X >= pos.X and point.X <= pos.X + size.X
       and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

local function KeyName(key)
    if key and key ~= Enum.KeyCode.None and key.Name then
        return key.Name
    end
    return "None"
end

local function ToHex(color)
    return string.format("#%02X%02X%02X",
        _floor(color.R * 255 + 0.5),
        _floor(color.G * 255 + 0.5),
        _floor(color.B * 255 + 0.5))
end

--------------------------------------------------------------------------------
-- Animation engine
-- `Animate` keeps ONE active tween per object (new tween cancels the old one),
-- which stops tweens from fighting each other.
--------------------------------------------------------------------------------

local ActiveTweens = setmetatable({}, { __mode = "k" })

local function Animate(object, duration, props, style, direction, delayTime, onComplete)
    local previous = ActiveTweens[object]
    if previous then
        for _, tween in ipairs(previous) do
            pcall(function() tween:Cancel() end)
        end
    end
    local info = TweenInfo.new(
        duration or 0.25,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out,
        0, false,
        delayTime or 0
    )
    local tween = TweenService:Create(object, info, props)
    ActiveTweens[object] = { tween }
    if onComplete then
        tween.Completed:Connect(function(state)
            if state ~= Enum.PlaybackState.Cancelled then
                onComplete()
            end
        end)
    end
    tween:Play()
    return tween
end

-- Looping tween (never registers with the manager so it can't be cancelled by Animate)
local function AnimateLoop(object, props, duration, style)
    local info = TweenInfo.new(
        duration or 0.5,
        style or Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut,
        -1, true, 0
    )
    local tween = TweenService:Create(object, info, props)
    tween:Play()
    return tween
end

--------------------------------------------------------------------------------
-- Instance factory
--------------------------------------------------------------------------------

local function Create(className, props)
    local instance = Instance.new(className)
    local parent = nil
    for key, value in pairs(props or {}) do
        if key == "Parent" then
            parent = value
        else
            instance[key] = value
        end
    end
    if parent ~= nil then instance.Parent = parent end
    return instance
end

-- CanvasGroup lets us fade an entire branch of the UI (GroupTransparency).
-- It has existed since 2022, but we still fall back to a plain Frame if some
-- ancient environment doesn't have it.
local CanGroup = false
do
    local ok = pcall(function() Instance.new("CanvasGroup") end)
    CanGroup = ok
end

local function NewGroup(props)
    if CanGroup then
        return Create("CanvasGroup", props), true
    end
    return Create("Frame", props), false
end

local function NewCorner(parent, radius)
    return Create("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

local function NewStroke(parent, colorKeyOrFn, thickness, transparency)
    local stroke = Create("UIStroke", {
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
    BindTheme(stroke, "Color", colorKeyOrFn)
    return stroke
end

local function NewPadding(parent, left, top, right, bottom)
    return Create("UIPadding", {
        PaddingLeft   = UDim.new(0, left or 0),
        PaddingTop    = UDim.new(0, top or 0),
        PaddingRight  = UDim.new(0, right or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        Parent = parent,
    })
end

-- Connection bookkeeping so Destroy() can unhook everything cleanly
local function Track(store, signal, handler)
    local connection = signal:Connect(handler)
    table.insert(store, connection)
    return connection
end

--------------------------------------------------------------------------------
-- Interaction helpers
--------------------------------------------------------------------------------

-- Generic "drag an invisible area" helper used by sliders & color pickers.
-- onStart fires on press, onMove on every mouse move while held, onEnd on release.
local function MakeDraggableArea(store, area, onStart, onMove, onEnd)
    local active = false
    Track(store, area.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            active = true
            if onStart then onStart() end
            if onMove then onMove() end -- snap to the click position
        end
    end)
    Track(store, UserInputService.InputChanged, function(input)
        if active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if onMove then onMove() end
        end
    end)
    Track(store, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if active then
                active = false
                if onEnd then onEnd() end
            end
        end
    end)
end

-- Material-style ripple that expands from the click point
local function Ripple(frame)
    local ok, point = pcall(function() return UserInputService:GetMouseLocation() end)
    if not ok or not point then return end
    local rel = point - frame.AbsolutePosition
    local diameter = math.max(frame.AbsoluteSize.X, frame.AbsoluteSize.Y) * 1.1
    local circle = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(rel.X, rel.Y),
        Size = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = frame,
    })
    NewCorner(circle, 999)
    Animate(circle, 0.45, {
        Size = UDim2.fromOffset(diameter, diameter),
        BackgroundTransparency = 1,
    }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, function()
        circle:Destroy()
    end)
end

-- Satisfying press-down scale effect for buttons
local function PressFX(button)
    local scale = Create("UIScale", { Scale = 1, Parent = button })
    button.MouseButton1Down:Connect(function()
        Animate(scale, 0.08, { Scale = 0.96 })
    end)
    button.MouseButton1Up:Connect(function()
        Animate(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
    end)
    button.MouseLeave:Connect(function()
        Animate(scale, 0.18, { Scale = 1 })
    end)
end

-- Soft hover highlight for rows (background flashes RowHover at high transparency)
local function HoverSoft(frame, transparency)
    frame.MouseEnter:Connect(function()
        Animate(frame, 0.12, { BackgroundTransparency = transparency or 0.93 })
    end)
    frame.MouseLeave:Connect(function()
        Animate(frame, 0.18, { BackgroundTransparency = 1 })
    end)
end

--------------------------------------------------------------------------------
-- Popover management (color pickers)
--------------------------------------------------------------------------------

local function ClosePopoversForWindow(window)
    for i = #Library._popovers, 1, -1 do
        local entry = Library._popovers[i]
        if entry.Window == window then
            table.remove(Library._popovers, i)
            entry.Close()
        end
    end
end

--------------------------------------------------------------------------------
-- Config system (only when the executor exposes a filesystem)
--------------------------------------------------------------------------------

local function MarkConfigDirty(window)
    if not window or not window._saveConfig then return end
    window._configDirty = true
    if window._configTimer then return end
    window._configTimer = true
    task.delay(1.25, function()
        window._configTimer = nil
        if window._configDirty and window.Gui and window.Gui.Parent then
            window._configDirty = false
            Library:SaveConfig(window._configName, window)
        end
    end)
end

local function RegisterFlag(ctx, flag, element)
    if flag == nil or flag == "" then return end
    Library.Flags[flag] = element
    element.Flag = flag
end

local function SerializeValue(value)
    local kind = TypeOf(value)
    if kind == "Color3" then
        return { __type = "Color3", R = value.R, G = value.G, B = value.B }
    elseif kind == "EnumItem" then
        return { __type = "EnumItem", EnumType = value.EnumType, Name = value.Name }
    elseif kind == "table" then
        local copy = {}
        for i, item in ipairs(value) do copy[i] = item end
        return copy
    end
    return value
end

local function DeserializeValue(value)
    if type(value) == "table" and value.__type == "Color3" then
        return Color3.new(value.R or 1, value.G or 1, value.B or 1)
    elseif type(value) == "table" and value.__type == "EnumItem" then
        local ok, item = pcall(function() return Enum[value.EnumType][value.Name] end)
        if ok then return item end
        return nil
    end
    return value
end

local function GetConfigPath(window, name)
    local folder = (window and window._configFolder) or "OzionUI"
    return folder .. "/" .. tostring(name or "default") .. ".json"
end

function Library:GetConfigs(window)
    if type(listfolder) ~= "function" then return {} end
    local folder = (window and window._configFolder) or "OzionUI"
    local ok, list = pcall(listfolder, folder)
    if not ok or type(list) ~= "table" then return {} end
    local names = {}
    for _, item in ipairs(list) do
        if type(item) == "string" and string.sub(item, -5) == ".json" then
            table.insert(names, string.sub(item, 1, -6))
        end
    end
    table.sort(names)
    return names
end

function Library:SaveConfig(name, window)
    window = window or Library.Windows[1]
    if not window then return false end
    if type(writefile) ~= "function" then
        warn("[OzionUI] writefile() is not available on this executor - cannot save configs")
        return false
    end
    local folder = window._configFolder or "OzionUI"
    pcall(function()
        if type(makefolder) == "function" then
            if type(isfolder) ~= "function" or not isfolder(folder) then
                makefolder(folder)
            end
        end
    end)
    local data = {}
    for flag, element in pairs(Library.Flags) do
        if type(element.Get) == "function" then
            local ok, value = pcall(element.Get)
            if ok and value ~= nil then
                data[flag] = SerializeValue(value)
            end
        end
    end
    local ok, err = pcall(function()
        writefile(GetConfigPath(window, name or window._configName), HttpService:JSONEncode(data))
    end)
    if not ok then
        warn("[OzionUI] failed to save config: " .. tostring(err))
        return false
    end
    return true
end

function Library:LoadConfig(name, window)
    window = window or Library.Windows[1]
    if not window then return false end
    if type(readfile) ~= "function" then return false end
    local ok, content = pcall(readfile, GetConfigPath(window, name or window._configName))
    if not ok or type(content) ~= "string" then return false end
    local okDecode, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not okDecode or type(data) ~= "table" then return false end
    for flag, serialized in pairs(data) do
        local element = Library.Flags[flag]
        if element and type(element.Set) == "function" then
            local value = DeserializeValue(serialized)
            if value ~= nil then
                pcall(element.Set, value)
            end
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- Notifications (toast cards, top-right, animated in/out with progress bar)
--------------------------------------------------------------------------------

local NotifGui, NotifHolder, NotifOrder = nil, nil, 0

local NotifGlyphs = {
    Success = "✓",
    Error   = "✕",
    Warning = "!",
    Info    = "i",
}

local function EnsureNotificationGui()
    if NotifGui and NotifGui.Parent then return end
    NotifGui = Create("ScreenGui", {
        Name = "OzionUI_Notifications",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
        Enabled = true,
    })
    ProtectGui(NotifGui)
    NotifGui.Parent = GetRootParent()
    NotifHolder = Create("Frame", {
        Name = "Holder",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 14),
        Size = UDim2.new(0, 300, 1, -28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = NotifGui,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = NotifHolder,
    })
end

function Library:Notification(cfg)
    cfg = cfg or {}
    EnsureNotificationGui()
    NotifOrder = NotifOrder + 1

    local ntype = cfg.Type or "Info"
    local glyph = NotifGlyphs[ntype] or "i"
    local colorKey = (ntype == "Info") and "Accent" or ntype
    local duration = math.max(cfg.Duration or 4, 0.5)

    -- keep at most 6 toasts on screen
    do
        local frames, oldest = 0, nil
        for _, child in ipairs(NotifHolder:GetChildren()) do
            if child:IsA("Frame") then
                frames = frames + 1
                if oldest == nil then oldest = child end
            end
        end
        if frames >= 6 and oldest then
            pcall(function() oldest:Destroy() end)
        end
    end

    local outer = Create("Frame", {
        Name = "Notification",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = NotifOrder,
        Parent = NotifHolder,
    })

    local card, cardIsGroup = NewGroup({
        Name = "Card",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Parent = outer,
    })
    BindTheme(card, "BackgroundColor3", "Topbar")
    NewCorner(card, 8)
    NewStroke(card, "Stroke", 1, 0.5)
    NewPadding(card, 10, 10, 10, 10)
    Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

    -- icon + text row
    local row = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = card,
    })
    local icon = Create("Frame", {
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        Parent = row,
    })
    NewCorner(icon, 12)
    BindTheme(icon, "BackgroundColor3", colorKey)
    Create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = glyph,
        TextSize = 12,
        Font = FONT_TITLE,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Parent = icon,
    })

    local textCol = Create("Frame", {
        Position = UDim2.new(0, 32, 0, 0),
        Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = row,
    })
    Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = textCol })

    local titleLabel = Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = cfg.Title or "Notification",
        TextSize = 13,
        Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = textCol,
    })
    BindTheme(titleLabel, "TextColor3", "Text")

    if cfg.Description then
        local descLabel = Create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = tostring(cfg.Description),
            TextSize = 12,
            Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Parent = textCol,
        })
        BindTheme(descLabel, "TextColor3", "SubText")
    end

    -- progress bar
    local track = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Parent = card,
    })
    NewCorner(track, 1)
    BindTheme(track, "BackgroundColor3", "Stroke")
    local fill = Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Parent = track,
    })
    NewCorner(fill, 1)
    BindTheme(fill, "BackgroundColor3", "Accent")

    -- slide in
    card.Position = UDim2.new(0, 330, 0, 0)
    Animate(card, 0.4, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)

    local closing = false
    local function Collapse()
        outer.AutomaticSize = Enum.AutomaticSize.None
        outer.Size = UDim2.new(1, 0, 0, outer.AbsoluteSize.Y)
        Animate(outer, 0.22, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, function()
            outer:Destroy()
        end)
    end
    local function Close()
        if closing then return end
        closing = true
        if cardIsGroup then
            Animate(card, 0.25, {
                GroupTransparency = 1,
                Position = UDim2.new(0, 330, 0, 0),
            }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, Collapse)
        else
            Animate(card, 0.25, { Position = UDim2.new(0, 330, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, Collapse)
        end
    end

    -- progress drain, then auto-close
    Animate(fill, duration, { Size = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, Close)

    return { Frame = outer, Close = Close }
end

Library.Notify = Library.Notification

--------------------------------------------------------------------------------
-- Watermark (top-left pill with live clock + FPS)
--------------------------------------------------------------------------------

local WatermarkHandle = nil

function Library:CreateWatermark(prefix)
    Library:DestroyWatermark()
    local gui = Create("ScreenGui", {
        Name = "OzionUI_Watermark",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9998,
    })
    ProtectGui(gui)
    gui.Parent = GetRootParent()

    local pill = Create("Frame", {
        Position = UDim2.new(0, 14, 0, -34), -- starts off-screen, slides in
        Size = UDim2.new(0, 0, 0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Parent = gui,
    })
    BindTheme(pill, "BackgroundColor3", "Topbar")
    NewCorner(pill, 7)
    NewStroke(pill, "Stroke", 1, 0.5)
    NewPadding(pill, 10, 0, 10, 0)

    local label = Create("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextSize = 12,
        Font = FONT_BODY,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = pill,
    })
    BindTheme(label, "TextColor3", "Text")

    WatermarkHandle = { Gui = gui, Pill = pill, Label = label, Prefix = prefix or "OzionUI" }

    Animate(pill, 0.5, { Position = UDim2.new(0, 14, 0, 14) }, Enum.EasingStyle.Back)

    task.spawn(function()
        while gui.Parent ~= nil do
            if WatermarkHandle and WatermarkHandle.Gui == gui then
                label.Text = WatermarkHandle.Prefix
                    .. "  |  " .. os.date("%H:%M:%S")
                    .. "  |  " .. tostring(Library._fps or 0) .. " FPS"
            end
            task.wait(0.25)
        end
    end)

    return WatermarkHandle
end

function Library:DestroyWatermark()
    if WatermarkHandle then
        pcall(function() WatermarkHandle.Gui:Destroy() end)
        WatermarkHandle = nil
    end
end

--------------------------------------------------------------------------------
-- Splash screen (plays once when the window opens)
--------------------------------------------------------------------------------

local function ShowSplash(screenGui, titleText, onDone)
    local finished = false
    local overlay = Create("TextButton", {
        Name = "Splash",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 100,
        Parent = screenGui,
    })

    local card, isGroup = NewGroup({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(300, 150),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Parent = overlay,
    })
    BindTheme(card, "BackgroundColor3", "Topbar")
    NewCorner(card, 14)
    local cardStroke = NewStroke(card, "Stroke", 1, 0.6)
    local scale = Create("UIScale", { Scale = 0.6, Parent = card })

    local logo = Create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 28),
        Size = UDim2.new(1, -40, 0, 30),
        BackgroundTransparency = 1,
        Text = titleText or "OZION UI",
        TextSize = 26,
        Font = Enum.Font.GothamBlack,
        Parent = card,
    })
    Create("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(168, 168, 195)),
        Rotation = 90,
        Parent = logo,
    })

    Create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 62),
        Size = UDim2.new(1, -40, 0, 14),
        BackgroundTransparency = 1,
        Text = "v" .. VERSION,
        TextSize = 12,
        Font = FONT_SMALL,
        TextColor3 = Theme.SubText,
        Parent = card,
    })

    local barTrack = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 104),
        Size = UDim2.new(1, -70, 0, 4),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Parent = card,
    })
    NewCorner(barTrack, 2)
    BindTheme(barTrack, "BackgroundColor3", "SliderTrack")
    local barFill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Parent = barTrack,
    })
    NewCorner(barFill, 2)
    BindTheme(barFill, "BackgroundColor3", "Accent")

    -- entrance
    Animate(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
    if isGroup then
        card.GroupTransparency = 1
        Animate(card, 0.3, { GroupTransparency = 0 })
    end
    Animate(barFill, 0.85, { Size = UDim2.new(1, 0, 1, 0) }, Enum.EasingStyle.Sine)
    local pulse = AnimateLoop(cardStroke, { Transparency = 0.1 }, 0.8)

    local function Finish()
        if finished then return end
        finished = true
        pcall(function() pulse:Cancel() end)
        Animate(scale, 0.25, { Scale = 1.06 })
        if isGroup then
            Animate(card, 0.25, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, function()
                overlay:Destroy()
            end)
        else
            task.delay(0.25, function() overlay:Destroy() end)
        end
        if onDone then onDone() end
    end

    overlay.MouseButton1Click:Connect(Finish)
    task.delay(1.35, Finish)
    task.delay(6, function() overlay:Destroy() end) -- safety net
end

--------------------------------------------------------------------------------
-- Element factories
-- Every factory receives (ctx, cfg) where ctx = { Container, Window, Order }
-- and returns an element table with Get/Set used by the config system.
--------------------------------------------------------------------------------

local function NewCtx(container, window)
    return { Container = container, Window = window, Order = 0 }
end

local function NextOrder(ctx)
    ctx.Order = ctx.Order + 1
    return ctx.Order
end

-- ===== Label ================================================================
local function AddLabel(ctx, cfg)
    if type(cfg) == "string" then cfg = { Text = cfg } end
    local row = Create("Frame", {
        Name = "Label",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })
    local label = Create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -24, 0, 20),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Text or "Label"),
        TextSize = 13,
        Font = FONT_BODY,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    BindTheme(label, "TextColor3", "Text")
    return { Type = "Label", Set = function(text) label.Text = tostring(text) end }
end

-- ===== Paragraph ============================================================
local function AddParagraph(ctx, cfg)
    if type(cfg) == "string" then cfg = { Text = cfg } end
    local row = Create("Frame", {
        Name = "Paragraph",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })
    local label = Create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 2),
        Size = UDim2.new(1, -24, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = tostring(cfg.Text or ""),
        TextSize = 12,
        Font = FONT_BODY,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Parent = row,
    })
    BindTheme(label, "TextColor3", "SubText")
    return { Type = "Paragraph", Set = function(text) label.Text = tostring(text) end }
end

-- ===== Divider ==============================================================
local function AddDivider(ctx, cfg)
    local row = Create("Frame", {
        Name = "Divider",
        Size = UDim2.new(1, 0, 0, 13),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })
    local line = Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 12, 0.5, 0),
        Size = UDim2.new(1, -24, 0, 1),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = row,
    })
    BindTheme(line, "BackgroundColor3", "Stroke")
    return { Type = "Divider" }
end

-- ===== Button ===============================================================
local function AddButton(ctx, cfg)
    local window = ctx.Window
    local height = cfg.Description and 46 or 34
    local hovering = false

    local row = Create("TextButton", {
        Name = "Button",
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })
    NewCorner(row, 6)
    BindTheme(row, "BackgroundColor3", function()
        return hovering and Theme.ElementHover or Theme.Element
    end)
    PressFX(row)

    local textX = 12
    if cfg.Icon then
        local icon = Create("TextLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(20, 18),
            BackgroundTransparency = 1,
            Text = tostring(cfg.Icon),
            TextSize = 14,
            Font = FONT_BODY,
            Parent = row,
        })
        BindTheme(icon, "TextColor3", "Accent")
        textX = 36
    end

    local title = Create("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or "Button"),
        TextSize = 13,
        Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    BindTheme(title, "TextColor3", "Text")

    if cfg.Description then
        title.Position = UDim2.new(0, textX, 0, 9)
        title.Size = UDim2.new(1, -textX - 12, 0, 16)
        local desc = Create("TextLabel", {
            Position = UDim2.new(0, textX, 0, 26),
            Size = UDim2.new(1, -textX - 12, 0, 14),
            BackgroundTransparency = 1,
            Text = tostring(cfg.Description),
            TextSize = 11,
            Font = FONT_SMALL,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row,
        })
        BindTheme(desc, "TextColor3", "SubText")
    else
        title.Position = UDim2.new(0, textX, 0.5, 0)
        title.AnchorPoint = Vector2.new(0, 0.5)
        title.Size = UDim2.new(1, -textX - 12, 0, 18)
    end

    row.MouseEnter:Connect(function()
        hovering = true
        Animate(row, 0.12, { BackgroundColor3 = Theme.ElementHover })
    end)
    row.MouseLeave:Connect(function()
        hovering = false
        Animate(row, 0.2, { BackgroundColor3 = Theme.Element })
    end)
    row.MouseButton1Click:Connect(function()
        Ripple(row)
        SafeCallback(cfg.Callback)
    end)

    return { Type = "Button", Title = cfg.Title }
end

-- ===== Toggle ===============================================================
local function AddToggle(ctx, cfg)
    local window = ctx.Window
    local on = cfg.Default == true

    local row = Create("TextButton", {
        Name = "Toggle",
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })
    NewCorner(row, 6)
    BindTheme(row, "BackgroundColor3", "RowHover")
    HoverSoft(row)

    local title = Create("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 12, 0.5, 0),
        Size = UDim2.new(1, -80, 0, 18),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or "Toggle"),
        TextSize = 13,
        Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    BindTheme(title, "TextColor3", "Text")

    local track = Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(40, 20),
        BorderSizePixel = 0,
        Parent = row,
    })
    NewCorner(track, 999)
    BindTheme(track, "BackgroundColor3", function()
        return on and Theme.Accent or Theme.ToggleOff
    end)
    local trackStroke = NewStroke(track, function()
        return on and Theme.Accent or Theme.Stroke
    end, 1, 0.7)

    local knob = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.fromOffset(14, 14),
        BorderSizePixel = 0,
        Parent = track,
    })
    NewCorner(knob, 999)
    BindTheme(knob, "BackgroundColor3", "Knob")

    local function Update(instant)
        local x = on and 30 or 10
        if instant then
            knob.Position = UDim2.fromOffset(x, 10)
            track.BackgroundColor3 = on and Theme.Accent or Theme.ToggleOff
            trackStroke.Transparency = on and 0.3 or 0.7
        else
            Animate(knob, 0.3, { Position = UDim2.fromOffset(x, 10) }, Enum.EasingStyle.Back)
            Animate(track, 0.25, { BackgroundColor3 = on and Theme.Accent or Theme.ToggleOff }, Enum.EasingStyle.Quint)
            Animate(trackStroke, 0.25, { Transparency = on and 0.3 or 0.7 })
        end
    end

    local function Set(value)
        on = value == true
        Update()
        MarkConfigDirty(window)
        SafeCallback(cfg.Callback, on)
    end

    row.MouseButton1Click:Connect(function()
        Set(not on)
    end)

    Update(true)

    local element = { Type = "Toggle", Title = cfg.Title, Get = function() return on end, Set = Set }
    RegisterFlag(ctx, cfg.Flag, element)
    return element
end

-- ===== Slider ===============================================================
local function AddSlider(ctx, cfg)
    local window = ctx.Window
    local minValue = cfg.Min or 0
    local maxValue = cfg.Max or 100
    if maxValue < minValue then minValue, maxValue = maxValue, minValue end
    local decimals = cfg.Decimals or 0
    local suffix = cfg.Suffix or ""
    local value = clamp(cfg.Default or minValue, minValue, maxValue)

    local row = Create("Frame", {
        Name = "Slider",
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })
    BindTheme(row, "BackgroundColor3", "RowHover")
    HoverSoft(row)

    local title = Create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -140, 0, 16),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or "Slider"),
        TextSize = 13,
        Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    BindTheme(title, "TextColor3", "Text")

    local valueLabel = Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 6),
        Size = UDim2.new(0, 120, 0, 16),
        BackgroundTransparency = 1,
        Text = "",
        TextSize = 12,
        Font = FONT_BODY,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })
    BindTheme(valueLabel, "TextColor3", "Text")
    local valueScale = Create("UIScale", { Scale = 1, Parent = valueLabel })

    local bar = Create("Frame", {
        Position = UDim2.new(0, 12, 0, 32),
        Size = UDim2.new(1, -24, 0, 6),
        BorderSizePixel = 0,
        Parent = row,
    })
    NewCorner(bar, 3)
    BindTheme(bar, "BackgroundColor3", "SliderTrack")

    local fill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BorderSizePixel = 0,
        Parent = bar,
    })
    NewCorner(fill, 3)
    BindTheme(fill, "BackgroundColor3", "Accent")
    Create("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(185, 185, 212)),
        Parent = fill,
    })

    local knob = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = bar,
    })
    NewCorner(knob, 999)
    BindTheme(knob, "BackgroundColor3", "Knob")
    NewStroke(knob, "Accent", 1, 0.3)
    local knobScale = Create("UIScale", { Scale = 1, Parent = knob })

    -- floating value bubble shown while dragging
    local bubble = Create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0, 0, 0, -10),
        Size = UDim2.fromOffset(46, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        TextSize = 11,
        Font = FONT_SMALL,
        TextTransparency = 1,
        ZIndex = 5,
        Parent = bar,
    })
    NewCorner(bubble, 4)
    BindTheme(bubble, "BackgroundColor3", "Topbar")
    local bubbleStroke = NewStroke(bubble, "Stroke", 1, 1)

    local function Format(v)
        return tostring(Round(v, decimals)) .. suffix
    end

    local function Render(v, pct, instant)
        if instant then
            fill.Size = UDim2.new(pct, 0, 1, 0)
            knob.Position = UDim2.new(pct, 0, 0.5, 0)
            bubble.Position = UDim2.new(pct, 0, 0, -10)
        else
            Animate(fill, 0.1, { Size = UDim2.new(pct, 0, 1, 0) })
            Animate(knob, 0.1, { Position = UDim2.new(pct, 0, 0.5, 0) })
            Animate(bubble, 0.1, { Position = UDim2.new(pct, 0, 0, -10) })
        end
        valueLabel.Text = Format(v)
        bubble.Text = Format(v)
    end

    local function SetValue(v, noCallback, noPop)
        v = Round(clamp(tonumber(v) or minValue, minValue, maxValue), decimals)
        local changed = v ~= value
        value = v
        local pct = (maxValue > minValue) and (v - minValue) / (maxValue - minValue) or 0
        Render(v, pct, false)
        if noPop ~= true then
            valueScale.Scale = 1.25
            Animate(valueScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
        end
        if changed and noCallback ~= true then
            MarkConfigDirty(window)
            SafeCallback(cfg.Callback, value)
        end
    end

    MakeDraggableArea(window._connections, bar,
        function() -- press
            Animate(knobScale, 0.15, { Scale = 1.3 })
            bubble.BackgroundTransparency = 0.1
            bubble.TextTransparency = 0
            Animate(bubbleStroke, 0.15, { Transparency = 0.4 })
        end,
        function() -- move
            local ok, point = pcall(function() return UserInputService:GetMouseLocation() end)
            if not ok or not point then return end
            local rel = clamp(point.X - bar.AbsolutePosition.X, 0, bar.AbsoluteSize.X)
            local pct = (bar.AbsoluteSize.X > 0) and rel / bar.AbsoluteSize.X or 0
            SetValue(minValue + (maxValue - minValue) * pct, nil, true)
        end,
        function() -- release
            Animate(knobScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
            Animate(bubble, 0.2, { BackgroundTransparency = 1, TextTransparency = 1 })
            Animate(bubbleStroke, 0.2, { Transparency = 1 })
        end
    )

    local pct0 = (maxValue > minValue) and (value - minValue) / (maxValue - minValue) or 0
    Render(value, pct0, true)

    local element = {
        Type = "Slider",
        Title = cfg.Title,
        Get = function() return value end,
        Set = function(v) SetValue(v) end,
    }
    RegisterFlag(ctx, cfg.Flag, element)
    return element
end

-- ===== Dropdown =============================================================
local function AddDropdown(ctx, cfg)
    local window = ctx.Window
    local options = cfg.Values or cfg.Options or {}
    local multi = cfg.Multi == true
    local open = false
    local selectedMap = {}  -- multi: option -> true
    local selectedName = nil -- single
    local hasSelection = false

    if multi then
        if type(cfg.Default) == "table" then
            for _, name in ipairs(cfg.Default) do
                if tableFind(options, name) then selectedMap[name] = true end
            end
        end
    elseif cfg.Default ~= nil and tableFind(options, cfg.Default) then
        selectedName = cfg.Default
    end

    local container = Create("Frame", {
        Name = "Dropdown",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })

    local hovering = false
    local header = Create("TextButton", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        Parent = container,
    })
    NewCorner(header, 6)
    BindTheme(header, "BackgroundColor3", function()
        return hovering and Theme.ElementHover or Theme.Element
    end)

    local title = Create("TextLabel", {
        Position = UDim2.new(0, 12, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(1, -110, 0, 18),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or "Dropdown"),
        TextSize = 13,
        Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })
    BindTheme(title, "TextColor3", "Text")

    local chevron = Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1,
        Text = "▼",
        TextSize = 10,
        Font = FONT_BODY,
        Parent = header,
    })
    BindTheme(chevron, "TextColor3", "SubText")

    local selText = Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -28, 0.5, 0),
        Size = UDim2.new(0, 140, 0, 16),
        BackgroundTransparency = 1,
        Text = "",
        TextSize = 12,
        Font = FONT_SMALL,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })
    BindTheme(selText, "TextColor3", function()
        return hasSelection and Theme.Text or Theme.SubText
    end)

    local listHeight = math.min(#options, 5) * 26 + 12
    local SetOpenState -- forward-declared (item clicks close the list)
    local list = Create("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 32),
        Size = UDim2.new(1, 0, 0, listHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageTransparency = 0.4,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        ZIndex = 3,
        Parent = container,
    })
    BindTheme(list, "ScrollBarImageColor3", "Accent")
    NewPadding(list, 4, 4, 4, 4)
    Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

    local items = {}
    local function Get()
        if multi then
            local out = {}
            for _, option in ipairs(options) do
                if selectedMap[option] then table.insert(out, option) end
            end
            return out
        end
        return selectedName
    end

    local function UpdateSelection(silent)
        hasSelection = multi and (next(selectedMap) ~= nil) or (selectedName ~= nil)
        if multi then
            local shown, count = {}, 0
            for _, option in ipairs(options) do
                if selectedMap[option] then
                    count = count + 1
                    if #shown < 3 then table.insert(shown, option) end
                end
            end
            if count == 0 then
                selText.Text = "Select..."
            else
                selText.Text = table.concat(shown, ", ") .. ((count > 3) and (" +" .. (count - 3)) or "")
            end
        else
            selText.Text = selectedName or "Select..."
        end
        for _, item in ipairs(items) do
            local isSel = multi and selectedMap[item.Option] == true or (item.Option == selectedName)
            item.Selected = isSel
            item.Label.TextColor3 = isSel and Theme.Text or Theme.SubText
            item.Check.TextTransparency = isSel and 0 or 1
        end
        if not silent then
            MarkConfigDirty(window)
            SafeCallback(cfg.Callback, Get())
        end
    end

    for index, option in ipairs(options) do
        local item = Create("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            ClipsDescendants = true,
            LayoutOrder = index,
            ZIndex = 3,
            Parent = list,
        })
        NewCorner(item, 4)
        BindTheme(item, "BackgroundColor3", "RowHover")
        HoverSoft(item, 0.9)
        local itemScale = Create("UIScale", { Scale = 1, Parent = item })

        local itemLabel = Create("TextLabel", {
            Position = UDim2.new(0, 6, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(1, -26, 0, 16),
            BackgroundTransparency = 1,
            Text = tostring(option),
            TextSize = 12,
            Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 3,
            Parent = item,
        })
        local check = Create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 1,
            Text = "✓",
            TextSize = 12,
            Font = FONT_BODY,
            TextTransparency = 1,
            ZIndex = 3,
            Parent = item,
        })
        BindTheme(check, "TextColor3", "Accent")

        local entry = { Frame = item, Label = itemLabel, Check = check, Option = option, Scale = itemScale, Selected = false }
        table.insert(items, entry)

        item.MouseButton1Click:Connect(function()
            if multi then
                if selectedMap[option] then
                    selectedMap[option] = nil
                else
                    selectedMap[option] = true
                end
                UpdateSelection()
            else
                selectedName = option
                UpdateSelection()
                SetOpenState(false)
            end
        end)
    end

    SetOpenState = function(state)
        open = state
        if state then
            Animate(container, 0.3, { Size = UDim2.new(1, 0, 0, 32 + listHeight) }, Enum.EasingStyle.Quint)
            Animate(chevron, 0.25, { Rotation = 180 })
            for index, item in ipairs(items) do
                item.Scale.Scale = 0.9
                Animate(item.Scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.015 * index)
            end
        else
            Animate(container, 0.25, { Size = UDim2.new(1, 0, 0, 30) }, Enum.EasingStyle.Quint)
            Animate(chevron, 0.25, { Rotation = 0 })
        end
    end

    header.MouseEnter:Connect(function()
        hovering = true
        Animate(header, 0.12, { BackgroundColor3 = Theme.ElementHover })
    end)
    header.MouseLeave:Connect(function()
        hovering = false
        Animate(header, 0.2, { BackgroundColor3 = Theme.Element })
    end)
    header.MouseButton1Click:Connect(function()
        SetOpenState(not open)
    end)

    UpdateSelection(true)

    local function Set(value)
        if multi then
            local map = {}
            if type(value) == "table" then
                for _, name in ipairs(value) do
                    if tableFind(options, name) then map[name] = true end
                end
            end
            selectedMap = map
        else
            if value == nil then
                selectedName = nil
            elseif tableFind(options, value) then
                selectedName = value
            end
        end
        UpdateSelection()
    end

    local element = { Type = "Dropdown", Title = cfg.Title, Get = Get, Set = Set, Open = function() SetOpenState(true) end, Close = function() SetOpenState(false) end }
    RegisterFlag(ctx, cfg.Flag, element)
    return element
end

-- ===== Textbox ==============================================================
local function AddTextbox(ctx, cfg)
    local window = ctx.Window
    local focused = false

    local row = Create("Frame", {
        Name = "Textbox",
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })

    local title = Create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -24, 0, 14),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or "Textbox"),
        TextSize = 12,
        Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    BindTheme(title, "TextColor3", "Text")

    local box = Create("TextBox", {
        Position = UDim2.new(0, 12, 0, 26),
        Size = UDim2.new(1, -24, 0, 30),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = tostring(cfg.Default or ""),
        PlaceholderText = tostring(cfg.Placeholder or "Type here..."),
        TextSize = 13,
        Font = FONT_BODY,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        TextEditable = true,
        ClipsDescendants = true,
        Parent = row,
    })
    BindTheme(box, "BackgroundColor3", "Element")
    BindTheme(box, "TextColor3", "Text")
    BindTheme(box, "PlaceholderColor3", "SubText")
    NewCorner(box, 6)
    NewPadding(box, 8, 0, 8, 0)
    local boxStroke = NewStroke(box, function()
        return focused and Theme.Accent or Theme.Stroke
    end, 1, 0.8)

    local function Commit()
        MarkConfigDirty(window)
        SafeCallback(cfg.Callback, box.Text)
    end

    box.Focused:Connect(function()
        focused = true
        Library._typing = true
        Animate(boxStroke, 0.2, { Transparency = 0.25 })
    end)
    box.FocusLost:Connect(function(enterPressed)
        focused = false
        Library._typing = false
        Animate(boxStroke, 0.2, { Transparency = 0.8 })
        if not cfg.OnlyOnEnter or enterPressed then
            Commit()
        end
    end)
    if cfg.Live then
        box.Changed:Connect(function(property)
            if property == "Text" then
                MarkConfigDirty(window)
                SafeCallback(cfg.Callback, box.Text)
            end
        end)
    end

    local element = {
        Type = "Textbox",
        Title = cfg.Title,
        Get = function() return box.Text end,
        Set = function(text)
            box.Text = tostring(text)
            MarkConfigDirty(window)
            SafeCallback(cfg.Callback, box.Text)
        end,
    }
    RegisterFlag(ctx, cfg.Flag, element)
    return element
end

-- ===== Keybind ==============================================================
local function AddKeybind(ctx, cfg)
    local window = ctx.Window
    local element = { Type = "Keybind", Title = cfg.Title }
    local mode = cfg.Mode or "Always" -- Always | Toggle | Hold
    local key = cfg.Default
    local listening = false

    if type(key) == "string" and key ~= "" then
        local ok, resolved = pcall(function() return Enum.KeyCode[key] end)
        key = ok and resolved or nil
    end
    if TypeOf(key) == "EnumItem" and key.EnumType ~= "KeyCode" then
        key = nil
    end

    local row = Create("Frame", {
        Name = "Keybind",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })
    BindTheme(row, "BackgroundColor3", "RowHover")
    HoverSoft(row)

    local title = Create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -110, 0, 16),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or "Keybind"),
        TextSize = 13,
        Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    BindTheme(title, "TextColor3", "Text")

    local modeLabel = Create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 24),
        Size = UDim2.new(1, -110, 0, 12),
        BackgroundTransparency = 1,
        Text = "Mode: " .. mode .. "  •  right-click chip to cycle",
        TextSize = 11,
        Font = FONT_SMALL,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    BindTheme(modeLabel, "TextColor3", "SubText")

    local chipHover = false
    local chip = Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(72, 22),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = KeyName(key),
        TextSize = 12,
        Font = FONT_SMALL,
        Parent = row,
    })
    NewCorner(chip, 4)
    BindTheme(chip, "BackgroundColor3", function()
        return chipHover and Theme.ElementHover or Theme.Element
    end)
    BindTheme(chip, "TextColor3", "Text")
    local chipStroke = NewStroke(chip, function()
        return listening and Theme.Accent or Theme.Stroke
    end, 1, 0.7)

    local pulseTween = nil
    local function SetListening(state)
        listening = state
        if state then
            Library._listeningKeybind = element
            chip.Text = "..."
            pulseTween = AnimateLoop(chipStroke, { Transparency = 0.05 }, 0.45)
        else
            if Library._listeningKeybind == element then
                Library._listeningKeybind = nil
            end
            if pulseTween then
                pcall(function() pulseTween:Cancel() end)
                pulseTween = nil
            end
            chipStroke.Transparency = 0.7
            chip.Text = KeyName(key)
        end
    end

    element._capture = function(newKey)
        key = newKey
        SetListening(false)
        MarkConfigDirty(window)
        SafeCallback(cfg.Callback, key)
    end
    element._cancelListening = function()
        SetListening(false)
    end

    chip.MouseEnter:Connect(function()
        chipHover = true
        Animate(chip, 0.12, { BackgroundColor3 = Theme.ElementHover })
    end)
    chip.MouseLeave:Connect(function()
        chipHover = false
        Animate(chip, 0.15, { BackgroundColor3 = Theme.Element })
    end)
    chip.MouseButton1Click:Connect(function()
        SetListening(not listening)
    end)
    chip.MouseButton2Click:Connect(function()
        if listening then
            SetListening(false)
            return
        end
        if mode == "Always" then mode = "Toggle"
        elseif mode == "Toggle" then mode = "Hold"
        else mode = "Always" end
        modeLabel.Text = "Mode: " .. mode .. "  •  right-click chip to cycle"
    end)

    -- register for global dispatch
    local registration = {
        Window = window,
        Element = element,
        GetKey = function() return key end,
        GetMode = function() return mode end,
        Fire = function(...) SafeCallback(cfg.Callback, ...) end,
        ToggleState = false,
    }
    table.insert(Library._keybinds, registration)
    table.insert(window._keybindRegistrations, registration)

    element.Get = function() return key or Enum.KeyCode.None end
    element.Set = function(v)
        if type(v) == "string" then
            local ok, resolved = pcall(function() return Enum.KeyCode[v] end)
            v = ok and resolved or Enum.KeyCode.None
        end
        if TypeOf(v) == "EnumItem" and v.EnumType == "KeyCode" then
            key = v
        else
            key = nil
        end
        if listening then SetListening(false) end
        chip.Text = KeyName(key)
        SafeCallback(cfg.Callback, key)
    end
    element.SetMode = function(m)
        mode = m
        modeLabel.Text = "Mode: " .. mode .. "  •  right-click chip to cycle"
    end

    RegisterFlag(ctx, cfg.Flag, element)
    return element
end

-- ===== ColorPicker ==========================================================
local function AddColorPicker(ctx, cfg)
    local window = ctx.Window
    local element = { Type = "ColorPicker", Title = cfg.Title }
    local color = cfg.Default or Color3.fromRGB(255, 255, 255)
    local hue, sat, val = 0, 0, 1
    do
        local h, s, v = Color3.toHSV(color)
        hue, sat, val = h, s, v
    end
    local popoverOpen = false

    local row = Create("Frame", {
        Name = "ColorPicker",
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })
    BindTheme(row, "BackgroundColor3", "RowHover")
    HoverSoft(row)

    local title = Create("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 12, 0.5, 0),
        Size = UDim2.new(1, -80, 0, 18),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or "Color"),
        TextSize = 13,
        Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    BindTheme(title, "TextColor3", "Text")

    local chip = Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(38, 20),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Parent = row,
    })
    NewCorner(chip, 4)
    NewStroke(chip, "Stroke", 1, 0.6)

    -- popover (lazily positioned, parented to the ScreenGui so it never clips)
    local popover, popoverIsGroup, popoverScale
    local svBox, svGradient, svDot, hueBar, hueMarker, preview, hexLabel

    popover, popoverIsGroup = NewGroup({
        Name = "ColorPopover",
        Size = UDim2.fromOffset(226, 268),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 50,
        Parent = window.Gui,
    })
    BindTheme(popover, "BackgroundColor3", "Background")
    NewCorner(popover, 10)
    NewStroke(popover, "Stroke", 1, 0.4)
    popoverScale = Create("UIScale", { Scale = 1, Parent = popover })

    local header = Create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 12),
        Size = UDim2.new(1, -32, 0, 16),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or "Color"),
        TextSize = 13,
        Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 50,
        Parent = popover,
    })
    BindTheme(header, "TextColor3", "Text")

    -- saturation / value box
    svBox = Create("Frame", {
        Name = "SVBox",
        Position = UDim2.new(0, 16, 0, 44),
        Size = UDim2.fromOffset(184, 150),
        BorderSizePixel = 0,
        ZIndex = 50,
        Parent = popover,
    })
    NewCorner(svBox, 6)
    svGradient = Create("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromHSV(hue, 1, 1)),
        Parent = svBox,
    })
    local svOverlay = Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 50,
        Parent = svBox,
    })
    Create("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0)),
        Rotation = 90,
        Parent = svOverlay,
    })
    svDot = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(sat, 0, 1 - val, 0),
        Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 52,
        Parent = svBox,
    })
    NewCorner(svDot, 999)
    NewStroke(svDot, "Stroke", 1, 0.2)

    -- hue bar
    hueBar = Create("Frame", {
        Name = "HueBar",
        Position = UDim2.new(0, 208, 0, 44),
        Size = UDim2.fromOffset(14, 150),
        BorderSizePixel = 0,
        ZIndex = 50,
        Parent = popover,
    })
    NewCorner(hueBar, 7)
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
        }),
        Rotation = 90,
        Parent = hueBar,
    })
    hueMarker = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, hue, 0),
        Size = UDim2.fromOffset(18, 6),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 52,
        Parent = hueBar,
    })
    NewCorner(hueMarker, 3)
    NewStroke(hueMarker, "Stroke", 1, 0.2)

    -- preview + hex + copy
    preview = Create("Frame", {
        Position = UDim2.new(0, 16, 0, 206),
        Size = UDim2.fromOffset(40, 22),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        ZIndex = 50,
        Parent = popover,
    })
    NewCorner(preview, 4)
    NewStroke(preview, "Stroke", 1, 0.5)

    hexLabel = Create("TextLabel", {
        Position = UDim2.new(0, 64, 0, 206),
        Size = UDim2.fromOffset(90, 22),
        BackgroundTransparency = 1,
        Text = ToHex(color),
        TextSize = 12,
        Font = FONT_SMALL,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 50,
        Parent = popover,
    })
    BindTheme(hexLabel, "TextColor3", "SubText")

    local copyHover = false
    local copyBtn = Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 206),
        Size = UDim2.fromOffset(54, 22),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "Copy",
        TextSize = 12,
        Font = FONT_SMALL,
        ZIndex = 50,
        Parent = popover,
    })
    NewCorner(copyBtn, 4)
    BindTheme(copyBtn, "BackgroundColor3", function()
        return copyHover and Theme.ElementHover or Theme.Element
    end)
    BindTheme(copyBtn, "TextColor3", "Text")
    copyBtn.MouseEnter:Connect(function()
        copyHover = true
        Animate(copyBtn, 0.12, { BackgroundColor3 = Theme.ElementHover })
    end)
    copyBtn.MouseLeave:Connect(function()
        copyHover = false
        Animate(copyBtn, 0.15, { BackgroundColor3 = Theme.Element })
    end)
    copyBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(ToHex(color)) end)
        Library:Notification({ Title = "Copied", Description = ToHex(color) .. " copied to clipboard.", Duration = 2 })
    end)

    local function UpdateHueVisuals()
        svGradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromHSV(hue, 1, 1))
        hueMarker.Position = UDim2.new(0.5, 0, hue, 0)
    end

    local function UpdateColorVisuals()
        svDot.Position = UDim2.new(sat, 0, 1 - val, 0)
        preview.BackgroundColor3 = color
        hexLabel.Text = ToHex(color)
        chip.BackgroundColor3 = color
    end

    local function ApplyColor(fireCallback)
        color = Color3.fromHSV(hue, sat, val)
        UpdateColorVisuals()
        if fireCallback then
            MarkConfigDirty(window)
            SafeCallback(cfg.Callback, color)
        end
    end

    MakeDraggableArea(window._connections, svBox, nil, function()
        local ok, point = pcall(function() return UserInputService:GetMouseLocation() end)
        if not ok or not point then return end
        local relX = clamp(point.X - svBox.AbsolutePosition.X, 0, svBox.AbsoluteSize.X)
        local relY = clamp(point.Y - svBox.AbsolutePosition.Y, 0, svBox.AbsoluteSize.Y)
        sat = (svBox.AbsoluteSize.X > 0) and relX / svBox.AbsoluteSize.X or 0
        val = 1 - ((svBox.AbsoluteSize.Y > 0) and relY / svBox.AbsoluteSize.Y or 0)
        ApplyColor(true)
    end, nil)

    MakeDraggableArea(window._connections, hueBar, nil, function()
        local ok, point = pcall(function() return UserInputService:GetMouseLocation() end)
        if not ok or not point then return end
        local relY = clamp(point.Y - hueBar.AbsolutePosition.Y, 0, hueBar.AbsoluteSize.Y)
        hue = (hueBar.AbsoluteSize.Y > 0) and relY / hueBar.AbsoluteSize.Y or 0
        UpdateHueVisuals()
        ApplyColor(true)
    end, nil)

    local function SetPopoverOpen(state)
        if state == popoverOpen then return end
        popoverOpen = state
        if state then
            -- close other popovers first
            for i = #Library._popovers, 1, -1 do
                local entry = Library._popovers[i]
                if entry.Frame ~= popover then
                    table.remove(Library._popovers, i)
                    entry.Close()
                end
            end
            popover.Visible = true
            local ap = chip.AbsolutePosition
            local vp = GetViewport()
            local x = clamp(ap.X + 38 - 226, 8, math.max(8, vp.X - 234))
            local y = clamp(ap.Y + 26, 8, math.max(8, vp.Y - 276))
            popover.Position = UDim2.fromOffset(_floor(x), _floor(y))
            popoverScale.Scale = 0.85
            Animate(popoverScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
            if popoverIsGroup then
                popover.GroupTransparency = 1
                Animate(popover, 0.2, { GroupTransparency = 0 })
            end
            table.insert(Library._popovers, {
                Frame = popover,
                Chip = chip,
                Window = window,
                Close = function() SetPopoverOpen(false) end,
            })
        else
            for i = #Library._popovers, 1, -1 do
                if Library._popovers[i].Frame == popover then
                    table.remove(Library._popovers, i)
                end
            end
            Animate(popoverScale, 0.18, { Scale = 0.85 })
            if popoverIsGroup then
                Animate(popover, 0.18, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, function()
                    if not popoverOpen then popover.Visible = false end
                end)
            else
                task.delay(0.2, function()
                    if not popoverOpen then popover.Visible = false end
                end)
            end
        end
    end

    chip.MouseButton1Click:Connect(function()
        SetPopoverOpen(not popoverOpen)
    end)

    UpdateHueVisuals()
    UpdateColorVisuals()

    element.Get = function() return color end
    element.Set = function(value)
        local ok, h, s, v = pcall(Color3.toHSV, value or color)
        if ok and h then hue, sat, val = h, s, v end
        UpdateHueVisuals()
        ApplyColor(false)
        MarkConfigDirty(window)
        SafeCallback(cfg.Callback, color)
    end
    element.Open = function() SetPopoverOpen(true) end
    element.Close = function() SetPopoverOpen(false) end

    RegisterFlag(ctx, cfg.Flag, element)
    return element
end

--------------------------------------------------------------------------------
-- Element registry & shared API for Tabs / Sections
--------------------------------------------------------------------------------

local ElementFactories = {
    Button      = AddButton,
    Toggle      = AddToggle,
    Slider      = AddSlider,
    Dropdown    = AddDropdown,
    Textbox     = AddTextbox,
    Keybind     = AddKeybind,
    ColorPicker = AddColorPicker,
    Label       = AddLabel,
    Paragraph   = AddParagraph,
    Divider     = AddDivider,
}

local function AddElement(ctx, kind, cfg)
    local factory = ElementFactories[kind]
    if not factory then
        error("OzionUI: unknown element type '" .. tostring(kind) .. "'")
    end
    return factory(ctx, cfg or {})
end

local function AttachElementAPI(holder, ctx)
    function holder:AddButton(cfg)      return AddElement(ctx, "Button", cfg) end
    function holder:AddToggle(cfg)      return AddElement(ctx, "Toggle", cfg) end
    function holder:AddSlider(cfg)      return AddElement(ctx, "Slider", cfg) end
    function holder:AddDropdown(cfg)    return AddElement(ctx, "Dropdown", cfg) end
    function holder:AddTextbox(cfg)     return AddElement(ctx, "Textbox", cfg) end
    function holder:AddKeybind(cfg)     return AddElement(ctx, "Keybind", cfg) end
    function holder:AddColorPicker(cfg) return AddElement(ctx, "ColorPicker", cfg) end
    function holder:AddLabel(cfg)       return AddElement(ctx, "Label", cfg) end
    function holder:AddParagraph(cfg)   return AddElement(ctx, "Paragraph", cfg) end
    function holder:AddDivider(cfg)     return AddElement(ctx, "Divider", cfg) end
    -- aliases (Obsidian naming)
    holder.AddTextBox = holder.AddTextbox
    holder.AddBind = holder.AddKeybind
    holder.AddColor = holder.AddColorPicker
    return holder
end

--------------------------------------------------------------------------------
-- Windows
--------------------------------------------------------------------------------

local guiCounter = 0

function Library:CreateWindow(cfg)
    cfg = cfg or {}
    guiCounter = guiCounter + 1

    local window = {
        _connections = {},
        _keybindRegistrations = {},
        _tabs = {},
        _visible = false,
        _minimized = false,
        _shined = false,
    }

    ------------------------------------------------------------------
    -- sizing / options
    ------------------------------------------------------------------
    local requested = cfg.Size or UDim2.fromOffset(590, 460)
    local width = clamp(requested.X.Offset, 500, 820)
    local height = clamp(requested.Y.Offset, 360, 620)
    local tabWidth = clamp(cfg.TabWidth or 150, 110, 220)
    window._size = UDim2.fromOffset(width, height)
    window._toggleKey = cfg.Key or cfg.ToggleKey or Enum.KeyCode.RightControl
    if type(window._toggleKey) == "string" then
        local ok, resolved = pcall(function() return Enum.KeyCode[window._toggleKey] end)
        window._toggleKey = ok and resolved or Enum.KeyCode.RightControl
    end
    window._configFolder = cfg.ConfigFolder or "OzionUI"
    window._configName = cfg.ConfigName or "default"
    window._saveConfig = cfg.SaveConfig == true

    ------------------------------------------------------------------
    -- root gui
    ------------------------------------------------------------------
    local screenGui = Create("ScreenGui", {
        Name = "OzionUI_" .. guiCounter .. "_" .. _floor(os.clock() * 1000),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 1000,
    })
    ProtectGui(screenGui)
    screenGui.Parent = GetRootParent()
    window.Gui = screenGui

    ------------------------------------------------------------------
    -- main frame
    ------------------------------------------------------------------
    local main, mainIsGroup = NewGroup({
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = window._size,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = screenGui,
    })
    BindTheme(main, "BackgroundColor3", "Background")
    NewCorner(main, 10)
    NewStroke(main, "Stroke", 1, 0.3)
    local mainScale = Create("UIScale", { Scale = 1, Parent = main })

    ------------------------------------------------------------------
    -- topbar
    ------------------------------------------------------------------
    local topbar = Create("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = main,
    })
    local topDivider = Create("Frame", {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = topbar,
    })
    BindTheme(topDivider, "BackgroundColor3", "Stroke")

    local iconX = 14
    if cfg.Icon then
        local icon = Create("TextLabel", {
            Position = UDim2.new(0, 14, 0, 8),
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            Text = tostring(cfg.Icon),
            TextSize = 16,
            Font = FONT_TITLE,
            Parent = topbar,
        })
        BindTheme(icon, "TextColor3", "Accent")
        iconX = 38
    end

    local titleLabel = Create("TextLabel", {
        Name = "Title",
        Position = UDim2.new(0, iconX, 0, 7),
        Size = UDim2.new(1, -iconX - 120, 0, 18),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or "OzionUI"),
        TextSize = 15,
        Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = topbar,
    })
    BindTheme(titleLabel, "TextColor3", "Text")
    Create("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(172, 172, 200)),
        Rotation = 90,
        Parent = titleLabel,
    })

    local subtitleLabel = Create("TextLabel", {
        Name = "Subtitle",
        Position = UDim2.new(0, iconX, 0, 26),
        Size = UDim2.new(1, -iconX - 120, 0, 12),
        BackgroundTransparency = 1,
        Text = tostring(cfg.SubTitle or ("v" .. VERSION)),
        TextSize = 11,
        Font = FONT_SMALL,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topbar,
    })
    BindTheme(subtitleLabel, "TextColor3", "SubText")

    local function TopBarButton(xOffset, glyph)
        local hovering = false
        local button = Create("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, xOffset, 0, 9),
            Size = UDim2.fromOffset(28, 28),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = glyph,
            TextSize = 14,
            Font = FONT_BODY,
            ZIndex = 3,
            Parent = topbar,
        })
        NewCorner(button, 6)
        BindTheme(button, "BackgroundColor3", function()
            return hovering and Theme.ElementHover or Theme.Element
        end)
        BindTheme(button, "TextColor3", function()
            return hovering and Theme.Text or Theme.SubText
        end)
        button.MouseEnter:Connect(function()
            hovering = true
            Animate(button, 0.12, { BackgroundTransparency = 0.4 })
        end)
        button.MouseLeave:Connect(function()
            hovering = false
            Animate(button, 0.15, { BackgroundTransparency = 1 })
        end)
        return button
    end

    local minBtn = TopBarButton(-10, "–")
    local closeBtn = TopBarButton(-44, "✕")

    -- shine sweep across the topbar on first open
    local shine = Create("Frame", {
        Name = "Shine",
        Position = UDim2.new(0, -140, 0, 0),
        Size = UDim2.fromOffset(90, 46),
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        Rotation = 12,
        Visible = false,
        ZIndex = 4,
        Parent = topbar,
    })
    BindTheme(shine, "BackgroundColor3", "Text")
    local function PlayShine()
        shine.Visible = true
        shine.Position = UDim2.new(0, -140, 0, 0)
        Animate(shine, 0.7, { Position = UDim2.new(1, 40, 0, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0.1, function()
            shine.Visible = false
        end)
    end

    ------------------------------------------------------------------
    -- body / sidebar / content
    ------------------------------------------------------------------
    local body, bodyIsGroup = NewGroup({
        Name = "Body",
        Position = UDim2.new(0, 0, 0, 46),
        Size = UDim2.new(1, 0, 1, -46),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = main,
    })

    local sidebar = Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, tabWidth, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = body,
    })
    local sideDivider = Create("Frame", {
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = sidebar,
    })
    BindTheme(sideDivider, "BackgroundColor3", "Stroke")

    local tabScroll = Create("ScrollingFrame", {
        Name = "TabButtons",
        Position = UDim2.new(0, 0, 0, 8),
        Size = UDim2.new(1, 0, 1, -16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageTransparency = 0.5,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        ZIndex = 3,
        Parent = sidebar,
    })
    BindTheme(tabScroll, "ScrollBarImageColor3", "Accent")
    NewPadding(tabScroll, 8, 4, 8, 4)
    Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabScroll })

    local content, contentIsGroup = NewGroup({
        Name = "Content",
        Position = UDim2.new(0, tabWidth, 0, 0),
        Size = UDim2.new(1, -tabWidth, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = body,
    })

    ------------------------------------------------------------------
    -- dragging (smooth follow: the frame lerps toward the cursor)
    ------------------------------------------------------------------
    do
        local dragging = false
        local dragStart, startPos
        Track(window._connections, topbar.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
            end
        end)
        Track(window._connections, UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        Track(window._connections, UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                local vp = GetViewport()
                local halfW = main.AbsoluteSize.X / 2
                local halfH = main.AbsoluteSize.Y / 2
                local x = clamp(startPos.X.Offset + delta.X, 70 - halfW, vp.X - 70 + halfW)
                local y = clamp(startPos.Y.Offset + delta.Y, 23 - halfH, vp.Y - 23 + halfH)
                window._targetPos = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y)
                window._lerping = true
            end
        end)
        Track(window._connections, RunService.RenderStepped, function(dt)
            if window._lerping and window._targetPos then
                main.Position = main.Position:Lerp(window._targetPos, math.min((dt or 1 / 60) * 18, 1))
                local current, target = main.Position, window._targetPos
                if not dragging
                    and current.X.Scale == target.X.Scale and current.Y.Scale == target.Y.Scale
                    and _floor(current.X.Offset) == _floor(target.X.Offset)
                    and _floor(current.Y.Offset) == _floor(target.Y.Offset) then
                    main.Position = target
                    window._lerping = false
                end
            end
        end)
    end

    ------------------------------------------------------------------
    -- window methods
    ------------------------------------------------------------------
    function window:Show()
        if window._visible then return end
        window._visible = true
        if window._minimized then
            window._minimized = false
            minBtn.Text = "–"
            body.Visible = true
            main.Size = window._size
        end
        ClosePopoversForWindow(window)
        main.Visible = true
        mainScale.Scale = 0.85
        Animate(mainScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
        if mainIsGroup then
            main.GroupTransparency = 1
            Animate(main, 0.3, { GroupTransparency = 0 })
        end
        if not window._shined then
            window._shined = true
            PlayShine()
        end
    end

    function window:Hide()
        if not window._visible then return end
        window._visible = false
        ClosePopoversForWindow(window)
        Animate(mainScale, 0.25, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        if mainIsGroup then
            Animate(main, 0.25, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, function()
                if not window._visible then main.Visible = false end
            end)
        else
            task.delay(0.25, function()
                if not window._visible then main.Visible = false end
            end)
        end
    end

    function window:Toggle()
        if window._visible then window:Hide() else window:Show() end
    end

    function window:Minimize()
        if window._minimized or not window._visible then return end
        window._minimized = true
        minBtn.Text = "▢"
        if bodyIsGroup then
            Animate(body, 0.16, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, function()
                if window._minimized then body.Visible = false end
            end)
        else
            body.Visible = false
        end
        Animate(main, 0.3, { Size = UDim2.fromOffset(210, 46) }, Enum.EasingStyle.Quint)
    end

    function window:Restore()
        if not window._minimized then return end
        window._minimized = false
        minBtn.Text = "–"
        body.Visible = true
        if bodyIsGroup then
            body.GroupTransparency = 1
            Animate(body, 0.25, { GroupTransparency = 0 })
        end
        Animate(main, 0.35, { Size = window._size }, Enum.EasingStyle.Back)
    end

    function window:ToggleMinimize()
        if window._minimized then window:Restore() else window:Minimize() end
    end

    function window:SetTitle(text)
        titleLabel.Text = tostring(text)
    end

    function window:SetSubtitle(text)
        subtitleLabel.Text = tostring(text)
    end

    function window:Destroy()
        for _, connection in ipairs(window._connections) do
            pcall(function() connection:Disconnect() end)
        end
        window._connections = {}
        ClosePopoversForWindow(window)
        for i = #Library._keybinds, 1, -1 do
            if Library._keybinds[i].Window == window then
                table.remove(Library._keybinds, i)
            end
        end
        for i = #Library.Windows, 1, -1 do
            if Library.Windows[i] == window then
                table.remove(Library.Windows, i)
            end
        end
        pcall(function() screenGui:Destroy() end)
    end

    ------------------------------------------------------------------
    -- tabs
    ------------------------------------------------------------------
    function window:SelectTab(tab, instant)
        if window._currentTab == tab then return end
        local previous = window._currentTab
        window._currentTab = tab

        local function Apply()
            if previous then
                previous.Frame.Visible = false
                previous._selected = false
                previous._glow.Visible = false
                previous._glow.Position = UDim2.new(0, 0, 0, 0)
                previous._Refresh()
            end
            tab.Frame.Visible = true
            tab._selected = true
            tab._glow.Visible = true
            tab._Refresh()
            if not instant and previous then
                -- the glow glides from the previously selected tab
                tab._glow.Position = UDim2.new(0, 0, 0, (previous._order - tab._order) * 40)
                Animate(tab._glow, 0.32, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
            end
        end

        if instant or not previous or not contentIsGroup then
            Apply()
            if not instant then
                content.Position = UDim2.new(0, 0, 0, 10)
                Animate(content, 0.22, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
            end
        else
            Animate(content, 0.12, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, function()
                Apply()
                content.Position = UDim2.new(0, 0, 0, 10)
                Animate(content, 0.22, { GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
            end)
        end
    end

    function window:AddTab(tabCfg)
        tabCfg = tabCfg or {}
        local title = tabCfg.Title or "Tab"
        local order = #window._tabs + 1
        local tab = { Title = title, _order = order, _selected = false, _window = window }

        local button = Create("TextButton", {
            Name = "TabButton_" .. title,
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            ClipsDescendants = true,
            LayoutOrder = order,
            ZIndex = 3,
            Parent = tabScroll,
        })
        NewCorner(button, 6)
        BindTheme(button, "BackgroundColor3", "RowHover")

        -- sliding highlight (animates between tabs)
        local glow = Create("Frame", {
            Name = "Glow",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 0.88,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 1,
            Parent = button,
        })
        NewCorner(glow, 6)
        BindTheme(glow, "BackgroundColor3", "Accent")
        NewStroke(glow, "Accent", 1, 0.55)
        tab._glow = glow

        local labelX = 10
        if tabCfg.Icon then
            local isImage = type(tabCfg.Icon) == "number"
                or (type(tabCfg.Icon) == "string" and string.sub(tabCfg.Icon, 1, 13) == "rbxassetid://")
            if isImage then
                local image = Create("ImageLabel", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 8, 0.5, 0),
                    Size = UDim2.fromOffset(18, 18),
                    BackgroundTransparency = 1,
                    Image = (type(tabCfg.Icon) == "number") and ("rbxassetid://" .. tostring(tabCfg.Icon)) or tabCfg.Icon,
                    ZIndex = 2,
                    Parent = button,
                })
                BindTheme(image, "ImageColor3", function()
                    return tab._selected and Theme.Accent or Theme.SubText
                end)
            else
                local iconLabel = Create("TextLabel", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 8, 0.5, 0),
                    Size = UDim2.fromOffset(20, 18),
                    BackgroundTransparency = 1,
                    Text = tostring(tabCfg.Icon),
                    TextSize = 14,
                    Font = FONT_BODY,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 2,
                    Parent = button,
                })
                BindTheme(iconLabel, "TextColor3", function()
                    return tab._selected and Theme.Accent or Theme.SubText
                end)
            end
            labelX = 32
        end

        local label = Create("TextLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, labelX, 0.5, 0),
            Size = UDim2.new(1, -labelX - 6, 0, 16),
            BackgroundTransparency = 1,
            Text = title,
            TextSize = 13,
            Font = FONT_TITLE,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2,
            Parent = button,
        })
        BindTheme(label, "TextColor3", function()
            return tab._selected and Theme.Text or Theme.SubText
        end)
        tab._Refresh = function()
            label.TextColor3 = tab._selected and Theme.Text or Theme.SubText
        end

        button.MouseEnter:Connect(function()
            Animate(button, 0.12, { BackgroundTransparency = 0.93 })
        end)
        button.MouseLeave:Connect(function()
            Animate(button, 0.12, { BackgroundTransparency = 1 })
        end)
        button.MouseButton1Click:Connect(function()
            window:SelectTab(tab)
        end)

        local frame = Create("ScrollingFrame", {
            Name = "Tab_" .. title,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageTransparency = 0.4,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
            Visible = false,
            ZIndex = 2,
            Parent = content,
        })
        BindTheme(frame, "ScrollBarImageColor3", "Accent")
        NewPadding(frame, 12, 12, 12, 24)
        Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

        tab.Frame = frame
        tab.Button = button
        tab._ctx = NewCtx(frame, window)
        AttachElementAPI(tab, tab._ctx)

        function tab:AddSection(sectionCfg)
            sectionCfg = sectionCfg or {}
            local section = { _window = window }
            local card = Create("Frame", {
                Name = "Section_" .. tostring(sectionCfg.Title or ""),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                LayoutOrder = NextOrder(tab._ctx),
                Parent = frame,
            })
            BindTheme(card, "BackgroundColor3", "Section")
            NewCorner(card, 8)
            NewStroke(card, "SectionStroke", 1, 0.5)
            NewPadding(card, 10, 10, 10, 10)
            Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

            local header = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = 0,
                Parent = card,
            })
            local accentBar = Create("Frame", {
                Position = UDim2.new(0, 0, 0, 2),
                Size = UDim2.fromOffset(3, 14),
                BorderSizePixel = 0,
                Parent = header,
            })
            NewCorner(accentBar, 2)
            BindTheme(accentBar, "BackgroundColor3", "Accent")
            local headerLabel = Create("TextLabel", {
                Position = UDim2.new(0, 9, 0, 0),
                Size = UDim2.new(1, -9, 0, 18),
                BackgroundTransparency = 1,
                Text = tostring(sectionCfg.Title or "Section"),
                TextSize = 13,
                Font = FONT_TITLE,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = header,
            })
            BindTheme(headerLabel, "TextColor3", "Text")

            local sectionCtx = NewCtx(card, window)
            sectionCtx.Order = 0 -- header owns LayoutOrder 0
            AttachElementAPI(section, sectionCtx)

            section.Card = card
            function section:SetTitle(text)
                headerLabel.Text = tostring(text)
            end
            return section
        end

        table.insert(window._tabs, tab)
        if #window._tabs == 1 then
            window:SelectTab(tab, true)
        end
        return tab
    end

    ------------------------------------------------------------------
    -- finish setup
    ------------------------------------------------------------------
    table.insert(Library.Windows, window)

    if type(cfg.Theme) == "string" then
        local preset = Library.Themes[cfg.Theme]
        if preset then ApplyTheme(preset) end
    elseif type(cfg.Theme) == "table" then
        ApplyTheme(cfg.Theme)
    end

    main.Visible = false
    if cfg.ShowSplash == false then
        window:Show()
    else
        ShowSplash(screenGui, cfg.Title or "OZION UI", function()
            window:Show()
        end)
    end

    return window
end

--------------------------------------------------------------------------------
-- Public theming API
--------------------------------------------------------------------------------

function Library:SetTheme(theme)
    if type(theme) == "string" then
        local preset = Library.Themes[theme]
        if not preset then
            error("OzionUI: unknown theme preset '" .. tostring(theme) .. "'")
        end
        ApplyTheme(preset)
    elseif type(theme) == "table" then
        ApplyTheme(theme)
    end
end

function Library:SetAccent(color)
    ApplyTheme({ Accent = color })
end

function Library:SetRainbow(enabled)
    Library._rainbow = enabled == true
end

function Library:Toggle()
    local window = Library.Windows[#Library.Windows]
    if window then window:Toggle() end
end

--------------------------------------------------------------------------------
-- Global cleanup
--------------------------------------------------------------------------------

function Library:Destroy()
    Library._alive = false
    for _, connection in ipairs(Library._connections) do
        pcall(function() connection:Disconnect() end)
    end
    Library._connections = {}
    for i = #Library.Windows, 1, -1 do
        Library.Windows[i]:Destroy()
    end
    Library:DestroyWatermark()
    if NotifGui then
        pcall(function() NotifGui:Destroy() end)
        NotifGui = nil
        NotifHolder = nil
    end
    Library.Flags = {}
    Library._popovers = {}
    Library._keybinds = {}
    Library._listeningKeybind = nil
end

--------------------------------------------------------------------------------
-- Global input handling (installed once)
--------------------------------------------------------------------------------

local function InstallGlobalInput()
    Track(Library._connections, UserInputService.InputBegan, function(input, gameProcessed)
        if not Library._alive then return end

        -- a keybind chip is listening: capture whatever key comes next
        if Library._listeningKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
            local element = Library._listeningKeybind
            if input.KeyCode == Enum.KeyCode.Escape then
                element._cancelListening()
            elseif input.KeyCode == Enum.KeyCode.Backspace then
                element._capture(Enum.KeyCode.None)
            else
                element._capture(input.KeyCode)
            end
            return
        end

        -- click-away closes open popovers (works even for clicks our UI sank)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            for i = #Library._popovers, 1, -1 do
                local entry = Library._popovers[i]
                if entry.Frame.Parent == nil then
                    table.remove(Library._popovers, i)
                elseif not IsPointInFrame(entry.Frame) and (not entry.Chip or not IsPointInFrame(entry.Chip)) then
                    table.remove(Library._popovers, i)
                    entry.Close()
                end
            end
        end

        if gameProcessed or Library._typing then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        -- window show/hide keys
        for _, window in ipairs(Library.Windows) do
            if window._toggleKey and input.KeyCode == window._toggleKey then
                window:Toggle()
            end
        end

        -- keybind elements
        for _, registration in ipairs(Library._keybinds) do
            local key = registration.GetKey()
            if key and key ~= Enum.KeyCode.None and key == input.KeyCode then
                local mode = registration.GetMode()
                if mode == "Toggle" then
                    registration.ToggleState = not registration.ToggleState
                    registration.Fire(registration.ToggleState)
                elseif mode == "Hold" then
                    registration.Fire(true)
                else
                    registration.Fire()
                end
            end
        end
    end)

    Track(Library._connections, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            for _, registration in ipairs(Library._keybinds) do
                if registration.GetMode() == "Hold" then
                    local key = registration.GetKey()
                    if key and key ~= Enum.KeyCode.None and key == input.KeyCode then
                        registration.Fire(false)
                    end
                end
            end
        end
    end)
end

-- single frame loop: FPS counter + rainbow accent
local function InstallFrameLoop()
    Track(Library._connections, RunService.RenderStepped, function(dt)
        if not Library._alive then return end
        dt = math.max(dt or 1 / 60, 1 / 144)
        Library._fpsAverage = Library._fpsAverage * 0.92 + (1 / dt) * 0.08
        Library._fps = _floor(Library._fpsAverage + 0.5)
        if Library._rainbow then
            Library._rainbowAccum = Library._rainbowAccum + dt
            if Library._rainbowAccum >= 1 / 30 then
                Library._rainbowHue = (Library._rainbowHue + Library._rainbowAccum * 0.25) % 1
                Library._rainbowAccum = 0
                SetAccent(Color3.fromHSV(Library._rainbowHue, 0.7, 1))
            end
        end
    end)
end

InstallGlobalInput()
InstallFrameLoop()

return Library
