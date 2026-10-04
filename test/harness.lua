--[[
    OzionUI test harness
    --------------------
    A pure-Lua mock of the Roblox client API (instances, Enum, UDim2, Color3,
    TweenService, UserInputService, HttpService, executor filesystem, task
    scheduler, ...) that lets OzionUI.lua be executed *headlessly*.

    It validates:
      * every property the library touches actually exists on that class
      * every property gets the right datatype (UDim2, Color3, EnumItem, ...)
      * element callbacks fire, flags register, configs save/load
      * input simulation: clicks, key presses, dragging, keybind capture
      * window lifecycle: tabs, minimize, hide/show key, splash, destroy

    Run:  python3 test/run_tests.py     (or any Lua 5.1+ interpreter)
    Set _G.NO_CANVAS_GROUP = true before loading to test the Frame fallback
    (simulates very old executors without CanvasGroup support).
]]

--///////////////////////////////////////////////////////////////////////////////
-- tiny test framework
--///////////////////////////////////////////////////////////////////////////////

local TestPassed, TestFailed = 0, 0
local AsyncErrors = 0

local function check(condition, label)
    if condition then
        TestPassed = TestPassed + 1
    else
        TestFailed = TestFailed + 1
        print("    CHECK FAILED: " .. tostring(label))
    end
end

local function step(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("  [ok] " .. name)
    else
        TestFailed = TestFailed + 1
        print("  [ERROR] " .. name .. " -> " .. tostring(err))
    end
end

--///////////////////////////////////////////////////////////////////////////////
-- virtual clock + task scheduler
--///////////////////////////////////////////////////////////////////////////////

local Clock = 0
local DelayedCalls = {}  -- { {due, fn} }
local WaitingCos = {}    -- { {co, due} }
local PendingTweens = {} -- { {tween, inst, info, props, dueStart, dueEnd} }

task = {}

function task.spawn(fn, ...)
    local co = coroutine.create(fn)
    local ok, err = coroutine.resume(co, ...)
    if not ok then
        AsyncErrors = AsyncErrors + 1
        print("    [task.spawn error] " .. tostring(err))
    end
end

function task.delay(duration, fn)
    table.insert(DelayedCalls, { due = Clock + (duration or 0), fn = fn })
end

function task.defer(fn)
    table.insert(DelayedCalls, { due = Clock, fn = fn })
end

function task.wait(duration)
    local co = coroutine.running()
    if not co then
        AsyncErrors = AsyncErrors + 1
        error("task.wait called outside of a coroutine")
    end
    table.insert(WaitingCos, { co = co, due = Clock + (duration or 0.03) })
    coroutine.yield()
    return duration or 0.03
end

local function Pump(seconds)
    local endTime = Clock + seconds
    while Clock < endTime do
        Clock = Clock + 0.05
        -- delayed calls
        local due = {}
        for i = #DelayedCalls, 1, -1 do
            if DelayedCalls[i].due <= Clock then
                table.insert(due, 1, DelayedCalls[i])
                table.remove(DelayedCalls, i)
            end
        end
        for _, call in ipairs(due) do
            local ok, err = pcall(call.fn)
            if not ok then
                AsyncErrors = AsyncErrors + 1
                print("    [delayed error] " .. tostring(err))
            end
        end
        -- sleeping coroutines
        local waking = {}
        for i = #WaitingCos, 1, -1 do
            if WaitingCos[i].due <= Clock then
                table.insert(waking, 1, WaitingCos[i])
                table.remove(WaitingCos, i)
            end
        end
        for _, entry in ipairs(waking) do
            local ok, err = coroutine.resume(entry.co)
            if not ok then
                AsyncErrors = AsyncErrors + 1
                print("    [coroutine error] " .. tostring(err))
            end
        end
        -- tweens
        for i = #PendingTweens, 1, -1 do
            local entry = PendingTweens[i]
            if entry.info.RepeatCount ~= -1 and Clock >= entry.dueEnd then
                table.remove(PendingTweens, i)
                local ok = pcall(function()
                    for prop, value in pairs(entry.props) do
                        entry.inst[prop] = value
                    end
                end)
                entry.tween.PlaybackState = Enum.PlaybackState.Completed
                if ok then
                    entry.tween.Completed:Fire(Enum.PlaybackState.Completed)
                else
                    entry.tween.Completed:Fire(Enum.PlaybackState.Cancelled)
                end
            end
        end
    end
end

--///////////////////////////////////////////////////////////////////////////////
-- value types (UDim, UDim2, Vector2/3, Color3, ColorSequence, TweenInfo)
--///////////////////////////////////////////////////////////////////////////////

local UDim = {}
function UDim.new(scale, offset)
    return { __type = "UDim", ClassName = "UDim", Scale = scale or 0, Offset = offset or 0 }
end

local UDim2MT = {}
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
    return setmetatable({ __type = "UDim2", ClassName = "UDim2", X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UDim2MT)
end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
function UDim2MT.__index(udim2, key)
    if key == "Lerp" then
        return function(self, other, alpha)
            return UDim2.new(
                self.X.Scale + (other.X.Scale - self.X.Scale) * alpha,
                self.X.Offset + (other.X.Offset - self.X.Offset) * alpha,
                self.Y.Scale + (other.Y.Scale - self.Y.Scale) * alpha,
                self.Y.Offset + (other.Y.Offset - self.Y.Offset) * alpha
            )
        end
    end
    error("UDim2: unknown member '" .. tostring(key) .. "'")
end

local Vector2MT = {}
local Vector2 = {}
function Vector2.new(x, y)
    return setmetatable({ __type = "Vector2", ClassName = "Vector2", X = x or 0, Y = y or 0 }, Vector2MT)
end
Vector2MT.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
Vector2MT.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end

local Vector3MT = {}
local Vector3 = {}
function Vector3.new(x, y, z)
    return setmetatable({ __type = "Vector3", ClassName = "Vector3", X = x or 0, Y = y or 0, Z = z or 0 }, Vector3MT)
end
Vector3MT.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3MT.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end

local Color3MT = {}
local Color3 = {}
local function clamp01(v) if v < 0 then return 0 elseif v > 1 then return 1 end return v end
function Color3.new(r, g, b)
    return setmetatable({ __type = "Color3", ClassName = "Color3", R = clamp01(r or 0), G = clamp01(g or 0), B = clamp01(b or 0) }, Color3MT)
end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHSV(h, s, v)
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    if i == 0 then return Color3.new(v, t, p)
    elseif i == 1 then return Color3.new(q, v, p)
    elseif i == 2 then return Color3.new(p, v, t)
    elseif i == 3 then return Color3.new(p, q, v)
    elseif i == 4 then return Color3.new(t, p, v)
    else return Color3.new(v, p, q) end
end
function Color3.toHSV(c)
    local max = math.max(c.R, c.G, c.B)
    local min = math.min(c.R, c.G, c.B)
    local delta = max - min
    local h = 0
    if delta > 0 then
        if max == c.R then h = ((c.G - c.B) / delta) % 6
        elseif max == c.G then h = (c.B - c.R) / delta + 2
        else h = (c.R - c.G) / delta + 4 end
        h = h / 6
    end
    local s = (max == 0) and 0 or delta / max
    return h, s, max
end
Color3MT.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end

local ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(time, color)
    return { __type = "ColorSequenceKeypoint", ClassName = "ColorSequenceKeypoint", Time = time, Value = color }
end

local ColorSequence = {}
function ColorSequence.new(a, b)
    if type(a) == "table" and a[1] then
        return { __type = "ColorSequence", ClassName = "ColorSequence", Keypoints = a }
    end
    return { __type = "ColorSequence", ClassName = "ColorSequence", Keypoints = {
        ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a)
    } }
end

local TweenInfo = {}
function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
    return {
        __type = "TweenInfo", ClassName = "TweenInfo",
        Time = time or 1,
        EasingStyle = style,
        EasingDirection = direction,
        RepeatCount = repeatCount or 0,
        Reverses = reverses or false,
        DelayTime = delayTime or 0,
    }
end

--///////////////////////////////////////////////////////////////////////////////
-- Enum
--///////////////////////////////////////////////////////////////////////////////

local EnumItemCache = {}
local EnumTypeCache = {}
local EnumItemMT = {
    __tostring = function(item) return "Enum." .. item.EnumType .. "." .. item.Name end,
}
Enum = setmetatable({}, {
    __index = function(_, enumType)
        local cached = EnumTypeCache[enumType]
        if not cached then
            cached = setmetatable({}, {
                __index = function(_, name)
                    local key = enumType .. "." .. name
                    local item = EnumItemCache[key]
                    if not item then
                        item = setmetatable({
                            __type = "EnumItem", ClassName = "EnumItem",
                            EnumType = enumType, Name = name, Value = 0,
                        }, EnumItemMT)
                        EnumItemCache[key] = item
                    end
                    return item
                end,
            })
            EnumTypeCache[enumType] = cached
        end
        return cached
    end,
})

--///////////////////////////////////////////////////////////////////////////////
-- signals
--///////////////////////////////////////////////////////////////////////////////

local function Signal()
    local signal = { _connections = {} }
    local mt
    mt = {
        __index = function(_, key)
            if key == "Connect" then
                return function(_, fn)
                    local connection = {
                        _fn = fn,
                        _connected = true,
                        _signal = signal,
                    }
                    function connection:Disconnect()
                        self._connected = false
                        for i, conn in ipairs(signal._connections) do
                            if conn == self then
                                table.remove(signal._connections, i)
                                break
                            end
                        end
                    end
                    table.insert(signal._connections, connection)
                    return connection
                end
            elseif key == "Fire" then
                return function(_, ...)
                    local snapshot = {}
                    for i, conn in ipairs(signal._connections) do snapshot[i] = conn end
                    for _, conn in ipairs(snapshot) do
                        if conn._connected then
                            conn._fn(...)
                        end
                    end
                end
            end
            error("Signal: unknown method '" .. tostring(key) .. "'")
        end,
    }
    return setmetatable(signal, mt)
end

--///////////////////////////////////////////////////////////////////////////////
-- instances
--///////////////////////////////////////////////////////////////////////////////

local function merge(...)
    local out = {}
    for _, source in ipairs({ ... }) do
        for key, value in pairs(source) do out[key] = value end
    end
    return out
end

local GuiProps = {
    Position = "UDim2", Size = "UDim2", AnchorPoint = "Vector2",
    BackgroundColor3 = "Color3", BackgroundTransparency = "number",
    BorderSizePixel = "number", BorderColor3 = "Color3",
    ClipsDescendants = "boolean", Active = "boolean", Rotation = "number",
    ZIndex = "number", Visible = "boolean", AutomaticSize = "EnumItem",
    LayoutOrder = "number",
}
local TextProps = {
    Text = "string", TextSize = "number", Font = "EnumItem",
    TextColor3 = "Color3", TextTransparency = "number",
    TextXAlignment = "EnumItem", TextYAlignment = "EnumItem",
    TextWrapped = "boolean", TextTruncate = "EnumItem",
    RichText = "boolean", TextScaled = "boolean",
}
local GuiEvents = {
    InputBegan = true, InputChanged = true, InputEnded = true,
    MouseEnter = true, MouseLeave = true, MouseMoved = true,
    MouseButton1Down = true, MouseButton1Up = true, MouseButton1Click = true,
    MouseButton2Down = true, MouseButton2Up = true, MouseButton2Click = true,
}

local ClassProps = {
    Frame         = merge(GuiProps),
    CanvasGroup   = merge(GuiProps, { GroupTransparency = "number", GroupColor3 = "Color3" }),
    ScrollingFrame = merge(GuiProps, {
        CanvasSize = "UDim2", AutomaticCanvasSize = "EnumItem",
        ScrollBarThickness = "number", ScrollBarImageColor3 = "Color3",
        ScrollBarImageTransparency = "number", ScrollingDirection = "EnumItem",
        ElasticBehavior = "EnumItem", CanvasPosition = "Vector2",
        ScrollingEnabled = "boolean", ScrollBarImage = "string",
    }),
    TextLabel     = merge(GuiProps, TextProps),
    TextButton    = merge(GuiProps, TextProps, { AutoButtonColor = "boolean", Modal = "boolean" }),
    TextBox       = merge(GuiProps, TextProps, {
        PlaceholderText = "string", PlaceholderColor3 = "Color3",
        ClearTextOnFocus = "boolean", TextEditable = "boolean", MultiLine = "boolean",
    }),
    ImageLabel    = merge(GuiProps, { Image = "string", ImageColor3 = "Color3", ImageTransparency = "number", ScaleType = "EnumItem" }),
    ScreenGui     = { ResetOnSpawn = "boolean", IgnoreGuiInset = "boolean", ZIndexBehavior = "EnumItem", DisplayOrder = "number", Enabled = "boolean" },
    UICorner      = { CornerRadius = "UDim" },
    UIStroke      = { Color = "Color3", Thickness = "number", Transparency = "number", ApplyStrokeMode = "EnumItem" },
    UIGradient    = { Color = "ColorSequence", Rotation = "number", Offset = "Vector2", Enabled = "boolean" },
    UIPadding     = { PaddingTop = "UDim", PaddingBottom = "UDim", PaddingLeft = "UDim", PaddingRight = "UDim" },
    UIListLayout  = { Padding = "UDim", SortOrder = "EnumItem", FillDirection = "EnumItem", HorizontalAlignment = "EnumItem", VerticalAlignment = "EnumItem" },
    UIScale       = { Scale = "number" },
    CoreGui       = {},
}

local ClassEvents = {
    Frame = GuiEvents, CanvasGroup = GuiEvents, ScrollingFrame = GuiEvents,
    TextLabel = GuiEvents, TextButton = GuiEvents, ImageLabel = GuiEvents,
    TextBox = merge(GuiEvents, { Focused = true, FocusLost = true }),
    ScreenGui = {}, CoreGui = {}, UICorner = {}, UIStroke = {},
    UIGradient = {}, UIPadding = {}, UIListLayout = {}, UIScale = {},
}

local GuiClasses = {
    Frame = true, CanvasGroup = true, ScrollingFrame = true, TextLabel = true,
    TextButton = true, TextBox = true, ImageLabel = true,
}

local function typeMatches(expected, value)
    if expected == "string" then return type(value) == "string"
    elseif expected == "number" then return type(value) == "number"
    elseif expected == "boolean" then return type(value) == "boolean"
    elseif expected == "Instance" then
        return value == nil or (type(value) == "table" and value._mockInstance == true)
    else
        return type(value) == "table" and value.ClassName == expected
    end
end

local InstanceMT
local InstanceMethods = {}

function InstanceMethods:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    local parent = self._props.Parent
    if parent then
        for i, child in ipairs(parent._children) do
            if child == self then
                table.remove(parent._children, i)
                break
            end
        end
    end
    self._props.Parent = nil
    local children = {}
    for i, child in ipairs(self._children) do children[i] = child end
    for _, child in ipairs(children) do child:Destroy() end
end

function InstanceMethods:FindFirstChild(name, recursive)
    for _, child in ipairs(self._children) do
        if child._props.Name == name then return child end
    end
    if recursive then
        for _, child in ipairs(self._children) do
            local found = child:FindFirstChild(name, true)
            if found then return found end
        end
    end
    return nil
end

function InstanceMethods:WaitForChild(name)
    return self:FindFirstChild(name, true)
end

function InstanceMethods:GetChildren()
    local copy = {}
    for i, child in ipairs(self._children) do copy[i] = child end
    return copy
end

function InstanceMethods:GetDescendants()
    local out = {}
    local function walk(inst)
        for _, child in ipairs(inst._children) do
            table.insert(out, child)
            walk(child)
        end
    end
    walk(self)
    return out
end

function InstanceMethods:IsA(className)
    return self._class == className
end

InstanceMT = {
    __index = function(self, key)
        if key == "ClassName" then return self._class end
        if key == "_mockInstance" then return true end
        if key == "Parent" then return self._props.Parent end
        if GuiClasses[self._class] then
            if key == "AbsolutePosition" then return Vector2.new(0, 0) end
            if key == "AbsoluteSize" then return Vector2.new(300, 200) end
            if key == "AbsoluteContentSize" then return Vector2.new(0, 600) end
        end
        if self._class == "ScrollingFrame" and key == "AbsoluteContentSize" then
            return Vector2.new(300, 600)
        end
        local prop = self._props[key]
        if prop ~= nil or rawget(self._props, key) then return prop end
        if key == "Changed" then
            return rawget(self._signals, key) or (function()
                local s = Signal(); rawset(self._signals, key, s); return s
            end)()
        end
        local events = ClassEvents[self._class]
        if events and events[key] then
            local s = rawget(self._signals, key)
            if not s then
                s = Signal()
                rawset(self._signals, key, s)
            end
            return s
        end
        if InstanceMethods[key] then return InstanceMethods[key] end
        error("mock: unknown property read '" .. tostring(key) .. "' on " .. self._class .. " '" .. tostring(self._props.Name) .. "'")
    end,
    __newindex = function(self, key, value)
        if self._destroyed then
            error("mock: attempt to set '" .. tostring(key) .. "' on destroyed " .. self._class)
        end
        if key == "Parent" then
            if not typeMatches("Instance", value) then
                error("mock: bad Parent type for " .. self._class)
            end
            local old = self._props.Parent
            if old then
                for i, child in ipairs(old._children) do
                    if child == self then table.remove(old._children, i) break end
                end
            end
            self._props.Parent = value
            if value then table.insert(value._children, self) end
            return
        end
        if key == "Name" then
            if type(value) ~= "string" then error("mock: Name must be a string") end
            self._props.Name = value
            return
        end
        local expected = ClassProps[self._class] and ClassProps[self._class][key]
        if not expected then
            error("mock: unknown property WRITE '" .. tostring(key) .. "' on " .. self._class .. " '" .. tostring(self._props.Name) .. "'")
        end
        if not typeMatches(expected, value) then
            error("mock: type mismatch on " .. self._class .. "." .. key ..
                " (expected " .. expected .. ", got " .. tostring(type(value) == "table" and value.ClassName or type(value)) .. ")")
        end
        rawset(self._props, key, value)
        local changed = rawget(self._signals, "Changed")
        if changed then changed:Fire(key) end
    end,
}

local function NewMockInstance(className)
    if className == "CanvasGroup" and _G.NO_CANVAS_GROUP then
        error("mock: CanvasGroup disabled for this test run")
    end
    if not ClassProps[className] then
        error("mock: unknown class " .. tostring(className))
    end
    return setmetatable({
        _class = className,
        _props = { Name = className },
        _children = {},
        _signals = {},
        _destroyed = false,
    }, InstanceMT)
end

Instance = { new = NewMockInstance }

-- input objects (not Instances, but need a Changed signal)
local function NewInput(props)
    local input = {}
    for key, value in pairs(props) do input[key] = value end
    setmetatable(input, {
        __index = function(t, key)
            if key == "Changed" then
                local s = rawget(t, "_changedSignal") or Signal()
                rawset(t, "_changedSignal", s)
                return s
            end
            error("mock: unknown InputObject read '" .. tostring(key) .. "'")
        end,
    })
    return input
end

--///////////////////////////////////////////////////////////////////////////////
-- services
--///////////////////////////////////////////////////////////////////////////////

local CoreGui = NewMockInstance("CoreGui")
CoreGui._props.Name = "CoreGui"

local CurrentMouse = Vector2.new(400, 300)

local UIS = {
    InputBegan = Signal(),
    InputChanged = Signal(),
    InputEnded = Signal(),
    GetMouseLocation = function() return CurrentMouse end,
    MouseEnabled = true,
    TouchEnabled = false,
}

local RunServiceMock = {
    RenderStepped = Signal(),
    Heartbeat = Signal(),
    Stepped = Signal(),
}

-- TweenService -------------------------------------------------------------

local TweenServiceMock = {}

local function validateTweenProps(inst, props)
    for prop in pairs(props) do
        local expected = ClassProps[inst._class] and ClassProps[inst._class][prop]
        if not expected then
            error("mock TweenService: cannot tween unknown property '" ..
                tostring(prop) .. "' on " .. inst._class)
        end
    end
end

function TweenServiceMock:Create(inst, info, props)
    if type(inst) ~= "table" or inst._mockInstance ~= true then
        error("mock TweenService: Create target is not an Instance")
    end
    validateTweenProps(inst, props)
    local tween = {
        PlaybackState = Enum.PlaybackState.Delayed,
        Completed = Signal(),
    }
    function tween:Play()
        self.PlaybackState = Enum.PlaybackState.Playing
        table.insert(PendingTweens, {
            tween = tween,
            inst = inst,
            info = info,
            props = props,
            dueStart = Clock + (info.DelayTime or 0),
            dueEnd = Clock + (info.DelayTime or 0) + info.Time,
        })
    end
    function tween:Cancel()
        for i, entry in ipairs(PendingTweens) do
            if entry.tween == tween then
                table.remove(PendingTweens, i)
                break
            end
        end
        if self.PlaybackState ~= Enum.PlaybackState.Completed then
            self.PlaybackState = Enum.PlaybackState.Cancelled
            self.Completed:Fire(Enum.PlaybackState.Cancelled)
        end
    end
    function tween:Pause() end
    return tween
end

-- HttpService (real JSON, enough for the config system) ---------------------

local HttpServiceMock = {}

local function jsonEscape(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, '"', '\\"')
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    return s
end

local function jsonEncode(value)
    local kind = type(value)
    if value == nil then return "null"
    elseif kind == "boolean" then return tostring(value)
    elseif kind == "number" then
        if value ~= value then error("json: NaN") end
        if math.floor(value) == value and math.abs(value) < 1e15 then
            return string.format("%d", value)
        end
        return string.format("%.14g", value)
    elseif kind == "string" then
        return '"' .. jsonEscape(value) .. '"'
    elseif kind == "table" then
        local n = #value
        if n > 0 then
            local parts = {}
            for i = 1, n do parts[i] = jsonEncode(value[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for k, v in pairs(value) do
            if type(k) ~= "string" then error("json: non-string key") end
            parts[#parts + 1] = '"' .. jsonEscape(k) .. '":' .. jsonEncode(v)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("json: cannot encode " .. kind)
end

local function jsonDecode(str)
    local pos = 1
    local function skip()
        while pos <= #str do
            local c = string.sub(str, pos, pos)
            if c == " " or c == "\n" or c == "\t" or c == "\r" then
                pos = pos + 1
            else
                break
            end
        end
    end
    local decodeValue
    local function decodeAt()
        skip()
        local c = string.sub(str, pos, pos)
        if c == "{" then
            pos = pos + 1
            local obj = {}
            skip()
            if string.sub(str, pos, pos) == "}" then pos = pos + 1 return obj end
            while true do
                skip()
                pos = pos + 1 -- opening quote
                local keyEnd = pos
                local key = ""
                while true do
                    local ch = string.sub(str, keyEnd, keyEnd)
                    if ch == '"' then break end
                    key = key .. ch
                    keyEnd = keyEnd + 1
                end
                pos = keyEnd + 1
                skip()
                pos = pos + 1 -- colon
                obj[key] = decodeValue()
                skip()
                local sep = string.sub(str, pos, pos)
                pos = pos + 1
                if sep == "}" then return obj end
            end
        elseif c == "[" then
            pos = pos + 1
            local arr = {}
            skip()
            if string.sub(str, pos, pos) == "]" then pos = pos + 1 return arr end
            while true do
                arr[#arr + 1] = decodeValue()
                skip()
                local sep = string.sub(str, pos, pos)
                pos = pos + 1
                if sep == "]" then return arr end
            end
        elseif c == '"' then
            pos = pos + 1
            local out = ""
            while true do
                local ch = string.sub(str, pos, pos)
                if ch == '"' then pos = pos + 1 break end
                if ch == "\\" then
                    local nxt = string.sub(str, pos + 1, pos + 1)
                    if nxt == "n" then out = out .. "\n"
                    elseif nxt == "t" then out = out .. "\t"
                    elseif nxt == "r" then out = out .. "\r"
                    else out = out .. nxt end
                    pos = pos + 2
                else
                    out = out .. ch
                    pos = pos + 1
                end
            end
            return out
        elseif string.sub(str, pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif string.sub(str, pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif string.sub(str, pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        else
            local numEnd = pos
            while numEnd <= #str do
                local ch = string.sub(str, numEnd, numEnd)
                if ch:match("[%-%+%d%.eE]") then numEnd = numEnd + 1 else break end
            end
            local num = tonumber(string.sub(str, pos, numEnd - 1))
            pos = numEnd
            return assert(num, "json: bad number at " .. pos)
        end
    end
    decodeValue = decodeAt
    local value = decodeValue()
    return value
end

function HttpServiceMock:JSONEncode(value) return jsonEncode(value) end
function HttpServiceMock:JSONDecode(str) return jsonDecode(str) end

-- services table ------------------------------------------------------------

local Services = {
    TweenService = TweenServiceMock,
    UserInputService = UIS,
    RunService = RunServiceMock,
    HttpService = HttpServiceMock,
    CoreGui = CoreGui,
    Workspace = { CurrentCamera = { ViewportSize = Vector2.new(1920, 1080) } },
    Players = { LocalPlayer = { Name = "MockPlayer", UserId = 12345 } },
}

game = {
    GetService = function(_, name)
        local service = Services[name]
        if not service then
            error("mock game:GetService: unknown service " .. tostring(name))
        end
        return service
    end,
}

-- export value types as GLOBALS so the library chunk (loaded with loadfile,
-- which uses the global environment) can see the mocks
for name, value in pairs({
    UDim = UDim,
    UDim2 = UDim2,
    Vector2 = Vector2,
    Vector3 = Vector3,
    Color3 = Color3,
    ColorSequence = ColorSequence,
    ColorSequenceKeypoint = ColorSequenceKeypoint,
    TweenInfo = TweenInfo,
    Instance = Instance,
    Enum = Enum,
}) do
    _G[name] = value
end

--///////////////////////////////////////////////////////////////////////////////
-- executor globals
--///////////////////////////////////////////////////////////////////////////////

local FSROOT = "/tmp/ozionui_tests"
os.execute("rm -rf " .. FSROOT .. " && mkdir -p " .. FSROOT)

function writefile(path, content)
    local file = assert(io.open(FSROOT .. "/" .. path, "w"))
    file:write(content)
    file:close()
end

function readfile(path)
    local file = io.open(FSROOT .. "/" .. path, "r")
    if not file then error("readfile: " .. path .. " does not exist", 2) end
    local content = file:read("*a")
    file:close()
    return content
end

function isfile(path)
    local file = io.open(FSROOT .. "/" .. path, "r")
    if file then file:close() return true end
    return false
end

function isfolder(path)
    local ok = os.execute("test -d '" .. FSROOT .. "/" .. path .. "'")
    return ok == true or ok == 0
end

function makefolder(path)
    os.execute("mkdir -p '" .. FSROOT .. "/" .. path .. "'")
end

function listfolder(path)
    -- io.popen is unavailable in some Lua builds; go through a temp file
    local listing = FSROOT .. "/.listing_tmp"
    os.execute("ls -1 '" .. FSROOT .. "/" .. path .. "' > '" .. listing .. "' 2>/dev/null")
    local file = io.open(listing, "r")
    if not file then return {} end
    local out = {}
    for line in file:lines() do out[#out + 1] = line end
    file:close()
    os.execute("rm -f '" .. listing .. "'")
    return out
end

local Clipboard = ""
function setclipboard(text) Clipboard = tostring(text) end
function getclipboard() return Clipboard end

function getgenv()
    return _G
end

warn = function(...) print("[warn]", ...) end

typeof = function(value)
    if type(value) == "table" and value.__type then return value.__type end
    return type(value)
end

math.clamp = math.clamp or function(v, mn, mx)
    if v < mn then return mn elseif v > mx then return mx end
    return v
end

--///////////////////////////////////////////////////////////////////////////////
-- input helpers
--///////////////////////////////////////////////////////////////////////////////

local function setMouse(x, y) CurrentMouse = Vector2.new(x, y) end

local function mouseDown(x, y)
    setMouse(x, y)
    UIS.InputBegan:Fire(NewInput {
        UserInputType = Enum.UserInputType.MouseButton1,
        Position = Vector3.new(x, y, 0),
    }, false)
end

local function mouseUp(x, y)
    setMouse(x, y)
    UIS.InputEnded:Fire(NewInput {
        UserInputType = Enum.UserInputType.MouseButton1,
        Position = Vector3.new(x, y, 0),
    })
end

local function mouseMove(x, y)
    setMouse(x, y)
    UIS.InputChanged:Fire(NewInput {
        UserInputType = Enum.UserInputType.MouseMovement,
        Position = Vector3.new(x, y, 0),
    })
end

local function pressKey(keyCode)
    UIS.InputBegan:Fire(NewInput {
        UserInputType = Enum.UserInputType.Keyboard,
        KeyCode = keyCode,
        Position = Vector3.new(0, 0, 0),
    }, false)
end

local function releaseKey(keyCode)
    UIS.InputEnded:Fire(NewInput {
        UserInputType = Enum.UserInputType.Keyboard,
        KeyCode = keyCode,
    })
end

local function renderFrame(dt)
    RunServiceMock.RenderStepped:Fire(dt or 1 / 60)
end

local function findByClass(root, className)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant.ClassName == className then return descendant end
    end
    return nil
end

local function findAllByClass(root, className)
    local out = {}
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant.ClassName == className then out[#out + 1] = descendant end
    end
    return out
end

local function findAllByName(root, name)
    local out = {}
    for _, child in ipairs(root:GetChildren()) do
        if child._props.Name == name then out[#out + 1] = child end
    end
    return out
end

--///////////////////////////////////////////////////////////////////////////////
-- LOAD THE LIBRARY
--///////////////////////////////////////////////////////////////////////////////

print("==============================================")
print(" OzionUI headless test harness")
print(" CanvasGroup fallback mode: " .. tostring(_G.NO_CANVAS_GROUP == true))
print("==============================================")

local libPath = _G.__LIB_PATH or "OzionUI.lua"
local libChunk = assert(loadfile(libPath), "cannot load " .. libPath)
local Library = libChunk()

--///////////////////////////////////////////////////////////////////////////////
-- TESTS
--///////////////////////////////////////////////////////////////////////////////

local W1, T1, T2, T3, S1, S2

local callbackLog = {}

step("library loads", function()
    check(type(Library) == "table", "library is a table")
    check(Library.Version == "1.0.0", "version")
    check(type(Library.Themes) == "table", "themes present")
end)

step("window creation", function()
    W1 = Library:CreateWindow({
        Title = "Test Window",
        SubTitle = "harness",
        Icon = "✦",
        Size = UDim2.fromOffset(600, 450),
        TabWidth = 140,
        ShowSplash = false,
        SaveConfig = true,
        ConfigFolder = "OzionTest",
        ConfigName = "default",
        Key = Enum.KeyCode.RightControl,
    })
    check(#Library.Windows == 1, "one window registered")
    check(W1.Gui ~= nil and W1.Gui.Parent == CoreGui, "gui parented to CoreGui")
    local main = W1.Gui:FindFirstChild("Main")
    check(main ~= nil, "main frame exists")
    check(main.Position.X.Offset == 0 and main.Position.Y.Offset == 0, "centered")
    check(main.Size.X.Offset == 600 and main.Size.Y.Offset == 450, "clamped size")
    check(W1._visible == true, "visible (no splash)")
    local title = main:FindFirstChild("Topbar"):FindFirstChild("Title")
    check(title ~= nil and title.Text == "Test Window", "title text")
    check(main.Visible == true, "main visible")
end)

step("tabs", function()
    T1 = W1:AddTab({ Title = "Main", Icon = "🏠" })
    T2 = W1:AddTab({ Title = "Player", Icon = "rbxassetid://1234567" })
    T3 = W1:AddTab({ Title = "Settings" })
    check(T1.Frame.Visible == true, "first tab auto-selected")
    check(T1._glow.Visible == true, "first tab glow visible")
    check(T2.Frame.Visible == false, "second tab hidden")
    check(T2._glow.Visible == false, "second tab glow hidden")
    check(T1.Button ~= nil and T2.Button ~= nil, "buttons stored")
    local imageIcon = T2.Button:FindFirstChild("ImageLabel")
    check(imageIcon ~= nil and imageIcon.Image == "rbxassetid://1234567", "image icon works")
end)

step("sections", function()
    S1 = T1:AddSection({ Title = "Actions" })
    S2 = T1:AddSection({ Title = "More" })
    check(S1.Card ~= nil, "section card exists")
    check(S1.Card.Parent == T1.Frame, "section in tab frame")
    local headerText = false
    for _, child in ipairs(S1.Card:GetChildren()) do
        if child.ClassName == "Frame" then
            local label = findByClass(child, "TextLabel")
            if label and label.Text == "Actions" then headerText = true end
        end
    end
    check(headerText, "section header text")
end)

-- element handles + callback tracking
local btnClicks = 0
local lastToggle, lastSlider, lastDD, lastMultiDD, lastTextbox, lastColor
local kbAlways, kbToggleArgs, kbHoldArgs = 0, {}, {}

local btn, tog, slider, dd, ddm, tb, kb, cp, lbl

step("elements create", function()
    btn = S1:AddButton({
        Title = "Do Thing",
        Description = "it does the thing",
        Callback = function() btnClicks = btnClicks + 1 end,
    })
    tog = S1:AddToggle({
        Title = "Godmode",
        Default = true,
        Flag = "godmode",
        Callback = function(v) lastToggle = v end,
    })
    slider = S1:AddSlider({
        Title = "WalkSpeed",
        Min = 16, Max = 200, Default = 75, Decimals = 0, Suffix = " st",
        Flag = "walkspeed",
        Callback = function(v) lastSlider = v end,
    })
    dd = S1:AddDropdown({
        Title = "Weapon",
        Values = { "Pistol", "Rifle", "Sniper" },
        Default = "Rifle",
        Flag = "weapon",
        Callback = function(v) lastDD = v end,
    })
    ddm = S1:AddDropdown({
        Title = "Friends",
        Options = { "A", "B", "C" },
        Multi = true,
        Flag = "friends",
        Callback = function(v) lastMultiDD = v end,
    })
    tb = S1:AddTextbox({
        Title = "Nickname",
        Placeholder = "enter name",
        Flag = "nickname",
        Callback = function(v) lastTextbox = v end,
    })
    kb = S1:AddKeybind({
        Title = "Panic",
        Default = Enum.KeyCode.F,
        Flag = "panic",
        Callback = function(...) table.insert(callbackLog, { ... }) end,
    })
    cp = S1:AddColorPicker({
        Title = "ESP Color",
        Default = Color3.fromRGB(255, 0, 0),
        Flag = "espcolor",
        Callback = function(v) lastColor = v end,
    })
    lbl = S1:AddLabel("hello")
    S1:AddParagraph("some long paragraph text here")
    S1:AddDivider()
    check(btn ~= nil and tog ~= nil and slider ~= nil, "simple elements")
    check(dd ~= nil and ddm ~= nil and tb ~= nil, "compound elements")
    check(kb ~= nil and cp ~= nil and lbl ~= nil, "picker elements")
    check(Library.Flags["godmode"] == tog, "toggle flag registered")
    check(Library.Flags["walkspeed"] == slider, "slider flag registered")
    check(Library.Flags["weapon"] == dd, "dropdown flag registered")
end)

step("button click + ripple", function()
    local row = findAllByName(S1.Card, "Button")[1]
    check(row ~= nil, "button row found")
    row.MouseButton1Click:Fire()
    check(btnClicks == 1, "callback fired")
    Pump(0.6) -- ripple should expand & destroy
    check(btnClicks == 1, "no double fire")
end)

step("toggle set", function()
    check(tog.Get() == true, "default on")
    tog.Set(false)
    check(lastToggle == false, "callback false")
    tog.Set(true)
    check(lastToggle == true, "callback true")
    -- track color for theme test
    local row = findAllByName(S1.Card, "Toggle")[1]
    local track = findByClass(row, "Frame")
    check(track ~= nil, "track found")
    callbackLog.track = track
end)

step("slider set + drag", function()
    slider.Set(120.6)
    check(slider.Get() == 121, "value rounds to decimals")
    check(lastSlider == 121, "slider callback")
    -- simulate dragging the bar (mouse at x=150 of a 300px bar -> 50%)
    local row = findAllByName(S1.Card, "Slider")[1]
    local bar = findByClass(row, "Frame") -- bar is the only direct Frame child
    check(bar ~= nil, "bar found")
    setMouse(150, 40)
    bar.InputBegan:Fire(NewInput {
        UserInputType = Enum.UserInputType.MouseButton1,
        Position = Vector3.new(150, 40, 0),
    })
    mouseMove(150, 40)
    check(slider.Get() == 108, "drag sets midpoint value (16 + 184*0.5), got " .. tostring(slider.Get()))
    UIS.InputEnded:Fire(NewInput {
        UserInputType = Enum.UserInputType.MouseButton1,
        Position = Vector3.new(150, 40, 0),
    })
    Pump(0.4)
end)

step("dropdown single select", function()
    dd.Set("Sniper")
    check(lastDD == "Sniper", "set callback")
    check(dd.Get() == "Sniper", "get reflects set")
    local container = findAllByName(S1.Card, "Dropdown")[1]
    local header = findByClass(container, "TextButton")
    header.MouseButton1Click:Fire()
    Pump(0.5)
    check(container.Size.Y.Offset > 30, "opened (height " .. container.Size.Y.Offset .. ")")
    -- click the "Pistol" item
    local list = findByClass(container, "ScrollingFrame")
    local clicked = false
    for _, item in ipairs(findAllByClass(list, "TextButton")) do
        local label = findByClass(item, "TextLabel")
        if label and label.Text == "Pistol" then
            item.MouseButton1Click:Fire()
            clicked = true
            break
        end
    end
    check(clicked, "item clicked")
    check(dd.Get() == "Pistol", "selection updated")
    Pump(0.5)
    check(container.Size.Y.Offset == 30, "auto-closed")
    -- invalid value ignored
    dd.Set("Grenade")
    check(dd.Get() == "Pistol", "invalid option ignored")
end)

step("dropdown multi select", function()
    ddm.Set({ "A", "C" })
    local value = ddm.Get()
    check(type(value) == "table" and #value == 2, "multi get returns table")
    check(value[1] == "A" and value[2] == "C", "multi values in option order")
    check(type(lastMultiDD) == "table" and lastMultiDD[2] == "C", "multi callback")
end)

step("textbox focus/commit", function()
    tb.Set("hello")
    check(lastTextbox == "hello", "set fires callback")
    local row = findAllByName(S1.Card, "Textbox")[1]
    local box = findByClass(row, "TextBox")
    check(box ~= nil, "box found")
    box.Focused:Fire()
    check(Library._typing == true, "typing flag set")
    box.Text = "typed!" -- direct write (mock fires Changed but no Live callback)
    box.FocusLost:Fire(true)
    check(Library._typing == false, "typing flag cleared")
    check(lastTextbox == "typed!", "focus lost commits")
    check(tb.Get() == "typed!", "get reflects text")
end)

step("keybind: dispatch, capture, modes", function()
    -- default F, Always mode
    pressKey(Enum.KeyCode.F)
    check(#callbackLog >= 1, "always mode fired")
    local row = findAllByName(S1.Card, "Keybind")[1]
    local chip = findByClass(row, "TextButton")
    check(chip ~= nil and chip.Text == "F", "chip shows key")
    -- capture a new key
    chip.MouseButton1Click:Fire()
    check(Library._listeningKeybind == kb, "listening mode on")
    pressKey(Enum.KeyCode.G)
    check(kb.Get() == Enum.KeyCode.G, "captured G")
    check(chip.Text == "G", "chip updated")
    check(Library._listeningKeybind == nil, "listening mode off")
    -- escape cancels without change
    chip.MouseButton1Click:Fire()
    pressKey(Enum.KeyCode.Escape)
    check(kb.Get() == Enum.KeyCode.G, "escape keeps old key")
    check(Library._listeningKeybind == nil, "listening cancelled")
    -- cycle mode to Toggle
    chip.MouseButton2Click:Fire()
    local modeLabel = nil
    for _, tl in ipairs(findAllByClass(row, "TextLabel")) do
        if string.find(tl.Text, "Mode: Toggle", 1, true) then modeLabel = tl end
    end
    check(modeLabel ~= nil, "mode cycled to Toggle")
    local args = {}
    local n = #callbackLog
    pressKey(Enum.KeyCode.G)
    pressKey(Enum.KeyCode.G)
    -- last two callback invocations should be true then false
    check(callbackLog[n + 1] ~= nil and callbackLog[n + 1][1] == true, "toggle on arg")
    check(callbackLog[n + 2] ~= nil and callbackLog[n + 2][1] == false, "toggle off arg")
    -- cycle to Hold
    chip.MouseButton2Click:Fire()
    n = #callbackLog
    pressKey(Enum.KeyCode.G)
    releaseKey(Enum.KeyCode.G)
    check(callbackLog[n + 1] ~= nil and callbackLog[n + 1][1] == true, "hold down arg")
    check(callbackLog[n + 2] ~= nil and callbackLog[n + 2][1] == false, "hold up arg")
    -- clear via backspace
    chip.MouseButton1Click:Fire()
    pressKey(Enum.KeyCode.Backspace)
    check(kb.Get() == Enum.KeyCode.None, "cleared to None")
    check(chip.Text == "None", "chip shows None")
end)

step("color picker popover", function()
    cp.Set(Color3.fromRGB(0, 255, 0))
    check(lastColor ~= nil and lastColor.G == 1, "set callback")
    local row = findAllByName(S1.Card, "ColorPicker")[1]
    local chip = findByClass(row, "TextButton")
    chip.MouseButton1Click:Fire()
    Pump(0.4)
    local popover = W1.Gui:FindFirstChild("ColorPopover")
    check(popover ~= nil and popover.Visible == true, "popover opened")
    -- drag inside the SV box: mouse (150, 50) on a 300x200 box -> sat=0.5, val=0.75
    local svBox = popover:FindFirstChild("SVBox")
    check(svBox ~= nil, "sv box found")
    svBox.InputBegan:Fire(NewInput {
        UserInputType = Enum.UserInputType.MouseButton1,
        Position = Vector3.new(150, 50, 0),
    })
    mouseMove(150, 50)
    check(lastColor ~= nil, "drag fired callback")
    local h, s, v = Color3.toHSV(lastColor)
    check(math.abs(s - 0.5) < 0.02, "saturation from drag (" .. s .. ")")
    check(math.abs(v - 0.75) < 0.02, "value from drag (" .. v .. ")")
    mouseUp(150, 50)
    -- hex label
    local hex = nil
    for _, tl in ipairs(findAllByClass(popover, "TextLabel")) do
        if string.sub(tl.Text, 1, 1) == "#" then hex = tl.Text end
    end
    check(hex ~= nil and #hex == 7, "hex label shown: " .. tostring(hex))
    -- click-away closes the popover
    mouseDown(1600, 900)
    Pump(0.4)
    check(popover.Visible == false, "popover closed by outside click")
    -- copy button
    chip.MouseButton1Click:Fire()
    Pump(0.3)
    popover = W1.Gui:FindFirstChild("ColorPopover")
    local copy = nil
    for _, tb2 in ipairs(findAllByClass(popover, "TextButton")) do
        if tb2.Text == "Copy" then copy = tb2 end
    end
    check(copy ~= nil, "copy button exists")
    if copy then
        copy.MouseButton1Click:Fire()
        check(getclipboard() ~= "" and string.sub(getclipboard(), 1, 1) == "#", "clipboard got hex")
    end
end)

step("label/paragraph/divider", function()
    local labelRow = findAllByName(S1.Card, "Label")[1]
    local label = findByClass(labelRow, "TextLabel")
    check(label.Text == "hello", "label text")
    lbl.Set("changed")
    check(label.Text == "changed", "label Set")
    check(findAllByName(S1.Card, "Paragraph")[1] ~= nil, "paragraph row")
    check(findAllByName(S1.Card, "Divider")[1] ~= nil, "divider row")
end)

step("tab-level elements", function()
    local tabLabel = T1:AddLabel("tab level label")
    check(tabLabel ~= nil, "created on tab")
    local found = false
    for _, child in ipairs(T1.Frame:GetChildren()) do
        if child._props.Name == "Label" then found = true end
    end
    check(found, "attached to tab frame")
end)

step("tab switching", function()
    W1:SelectTab(T2)
    Pump(0.4)
    check(T2.Frame.Visible == true and T1.Frame.Visible == false, "selectTab switches")
    check(T2._glow.Visible == true and T1._glow.Visible == false, "glows switch")
    T3.Button.MouseButton1Click:Fire()
    Pump(0.4)
    check(T3.Frame.Visible == true, "button click switches tab")
    W1:SelectTab(T1)
    Pump(0.4)
end)

step("minimize / restore", function()
    local main = W1.Gui:FindFirstChild("Main")
    local body = main:FindFirstChild("Body")
    W1:Minimize()
    Pump(0.6)
    check(main.Size.X.Offset == 210 and main.Size.Y.Offset == 46, "shrunk to pill")
    check(body.Visible == false, "body hidden")
    W1:Restore()
    Pump(0.6)
    check(main.Size.X.Offset == 600 and main.Size.Y.Offset == 450, "restored size")
    check(body.Visible == true, "body visible")
end)

step("toggle key hides / shows", function()
    local main = W1.Gui:FindFirstChild("Main")
    pressKey(Enum.KeyCode.RightControl)
    Pump(0.4)
    check(W1._visible == false, "hidden")
    check(main.Visible == false, "main invisible")
    pressKey(Enum.KeyCode.RightControl)
    Pump(0.4)
    check(W1._visible == true and main.Visible == true, "shown again")
end)

step("window dragging (smooth follow)", function()
    local main = W1.Gui:FindFirstChild("Main")
    local topbar = main:FindFirstChild("Topbar")
    check(topbar ~= nil, "topbar found")
    topbar.InputBegan:Fire(NewInput {
        UserInputType = Enum.UserInputType.MouseButton1,
        Position = Vector3.new(400, 200, 0),
    })
    mouseMove(520, 260)
    for _ = 1, 25 do renderFrame(1 / 60) end
    check(main.Position.X.Offset > 100, "x followed (got " .. main.Position.X.Offset .. ")")
    check(main.Position.Y.Offset > 50, "y followed (got " .. main.Position.Y.Offset .. ")")
    mouseUp(520, 260)
    renderFrame(1 / 60)
end)

step("notifications", function()
    local n = Library:Notification({ Title = "Hi", Description = "desc", Duration = 2 })
    check(n.Frame ~= nil and n.Frame.Parent ~= nil, "attached")
    Pump(0.6)
    check(n.Frame.Parent ~= nil, "still visible before duration")
    Pump(3)
    check(n.Frame.Parent == nil, "auto-destroyed after duration")
    local n2 = Library:Notification({ Title = "Manual", Duration = 10, Type = "Success" })
    Pump(0.3)
    n2.Close()
    Pump(1.2)
    check(n2.Frame.Parent == nil, "manual close works")
    -- all four types render
    Library:Notification({ Title = "a", Type = "Error", Duration = 1 })
    Library:Notification({ Title = "b", Type = "Warning", Duration = 1 })
    Library:Notification({ Title = "c", Type = "Info", Duration = 1 })
    Pump(3)
    check(true, "all types rendered")
end)

step("watermark", function()
    Library:CreateWatermark("Ozion")
    Pump(1)
    renderFrame(1 / 60)
    renderFrame(1 / 60)
    Pump(0.6)
    local wmGui = CoreGui:FindFirstChild("OzionUI_Watermark")
    check(wmGui ~= nil, "watermark gui exists")
    local label = findByClass(wmGui, "TextLabel")
    check(label ~= nil and string.find(label.Text, "FPS", 1, true) ~= nil, "fps shown")
    check(string.find(label.Text, "Ozion", 1, true) ~= nil, "prefix shown")
    check(string.find(label.Text, ":", 1, true) ~= nil, "clock shown")
    Library:DestroyWatermark()
    check(CoreGui:FindFirstChild("OzionUI_Watermark") == nil, "destroyed")
end)

step("theming", function()
    local main = W1.Gui:FindFirstChild("Main")
    Library:SetTheme("Ocean")
    check(main.BackgroundColor3 == Color3.fromRGB(16, 21, 32), "background rethemed")
    local track = callbackLog.track
    check(track.BackgroundColor3 == Library.Themes.Ocean.Accent, "accent binding updated (toggle is ON)")
    Library:SetAccent(Color3.fromRGB(1, 2, 3))
    check(track.BackgroundColor3 == Color3.fromRGB(1, 2, 3), "SetAccent live")
    -- rainbow cycles the accent
    local before = track.BackgroundColor3
    Library:SetRainbow(true)
    for _ = 1, 120 do renderFrame(1 / 60) end
    check(track.BackgroundColor3 ~= before, "rainbow moved accent")
    Library:SetRainbow(false)
    -- unknown theme should error
    local ok = pcall(function() Library:SetTheme("NopeTheme") end)
    check(ok == false, "unknown theme errors")
    Library:SetTheme("Midnight")
    check(track.BackgroundColor3 == Library.Themes.Midnight.Accent, "back to midnight")
end)

step("config save / load / list", function()
    check(Library:SaveConfig("profile1", W1) == true, "save ok")
    check(isfile("OzionTest/profile1.json"), "file on disk")
    -- snapshot of current state: toggle=true, slider=108 (dragged),
    -- dropdown=Pistol (clicked), friends={A,C}, nickname=typed!, panic=None
    -- mutate everything
    tog.Set(false)
    slider.Set(50)
    dd.Set("Rifle")
    ddm.Set({ "B" })
    tb.Set("changed")
    -- restore
    check(Library:LoadConfig("profile1", W1) == true, "load ok")
    check(tog.Get() == true, "toggle restored")
    check(slider.Get() == 108, "slider restored")
    check(dd.Get() == "Pistol", "dropdown restored")
    local friends = ddm.Get()
    check(type(friends) == "table" and #friends == 2 and friends[2] == "C", "multi dropdown restored")
    check(tb.Get() == "typed!", "textbox restored")
    check(kb.Get() == Enum.KeyCode.None, "keybind restored")
    local restored = cp.Get()
    check(typeof(restored) == "Color3" and restored.G > 0.7, "color restored (G=" .. tostring(restored and restored.G) .. ")")
    local configs = Library:GetConfigs(W1)
    local hasProfile = false
    for _, name in ipairs(configs) do
        if name == "profile1" then hasProfile = true end
    end
    check(#configs >= 1 and hasProfile, "configs listed")
    -- autosave debounce fires after changes
    slider.Set(77)
    Pump(2.5)
    check(isfile("OzionTest/default.json"), "autosave wrote default config")
    slider.Set(10)
    check(Library:LoadConfig("default", W1) == true, "load autosave")
    check(slider.Get() == 77, "autosave round trip")
end)

step("splash window", function()
    local W2 = Library:CreateWindow({ Title = "Splashy", ShowSplash = true })
    local splash = W2.Gui:FindFirstChild("Splash")
    check(splash ~= nil, "splash overlay created")
    check(W2._visible == false, "window hidden during splash")
    Pump(2.2)
    check(W2.Gui:FindFirstChild("Splash") == nil, "splash removed")
    check(W2._visible == true, "window shown after splash")
    check(W2.Gui:FindFirstChild("Main").Visible == true, "main visible")
    W2:Destroy()
    check(#Library.Windows == 1, "destroyed second window")
end)

step("destroy cleans up", function()
    local guiName = W1.Gui._props.Name
    W1:Destroy()
    check(#Library.Windows == 0, "windows list empty")
    check(CoreGui:FindFirstChild(guiName) == nil, "gui destroyed")
    Library:Destroy()
    -- no errors after destroy
    pressKey(Enum.KeyCode.F)
    pressKey(Enum.KeyCode.RightControl)
    renderFrame(1 / 60)
    Pump(1)
    check(Library._listeningKeybind == nil, "listening cleared")
    check(true, "no crash post-destroy")
end)

--///////////////////////////////////////////////////////////////////////////////
-- summary
--///////////////////////////////////////////////////////////////////////////////

print("==============================================")
print(" checks passed : " .. TestPassed)
print(" checks failed : " .. TestFailed)
print(" async errors  : " .. AsyncErrors)
if TestFailed == 0 and AsyncErrors == 0 then
    print(" RESULT: ALL TESTS PASSED")
    print("==============================================")
else
    print(" RESULT: FAILURES DETECTED")
    print("==============================================")
end
