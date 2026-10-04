--[[
    A small Roblox API mock.

    It is deliberately not a full engine -- it implements just enough of the
    DataModel, datatypes and signals for OzionUI to be loaded and driven
    headlessly, so that "does it actually run" can be answered by CI instead
    of by pasting the script into an executor and hoping.
]]

local Mock = {}
Mock.Scheduled = {}
Mock.Clock = 0
Mock.Instances = 0
Mock.Warnings = {}

--------------------------------------------------------------------- utils --

local function class(name)
	local T = {}
	T.__index = T
	T.__className = name
	return T
end

--------------------------------------------------------------------- Signal --

local Signal = class("Signal")

function Signal.new(name)
	return setmetatable({ Name = name, Handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local conn = { Connected = true, Handler = fn, Signal = self }
	function conn:Disconnect()
		self.Connected = false
		for i, c in ipairs(self.Signal.Handlers) do
			if c == self then
				table.remove(self.Signal.Handlers, i)
				break
			end
		end
	end
	conn.disconnect = conn.Disconnect
	table.insert(self.Handlers, conn)
	return conn
end

Signal.connect = Signal.Connect

function Signal:Fire(...)
	local snapshot = {}
	for i, c in ipairs(self.Handlers) do
		snapshot[i] = c
	end
	for _, c in ipairs(snapshot) do
		if c.Connected then
			local ok, err = pcall(c.Handler, ...)
			if not ok then
				error(("signal %s handler error: %s"):format(tostring(self.Name), tostring(err)), 0)
			end
		end
	end
end

function Signal:Wait()
	return nil
end

Mock.Signal = Signal

------------------------------------------------------------------ datatypes --

local Vector2 = class("Vector2")
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0, Magnitude = math.sqrt((x or 0) ^ 2 + (y or 0) ^ 2) }, Vector2)
end
Vector2.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
Vector2.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
Vector2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
Vector2.__tostring = function(v)
	return ("Vector2(%s, %s)"):format(v.X, v.Y)
end

local Vector3 = class("Vector3")
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

local UDim = class("UDim")
function UDim.new(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDim)
end
UDim.__add = function(a, b)
	return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset)
end
UDim.__sub = function(a, b)
	return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset)
end

local UDim2 = class("UDim2")
function UDim2.new(xs, xo, ys, yo)
	if type(xs) == "table" then -- UDim2.new(UDim, UDim)
		return setmetatable({ X = xs, Y = xo }, UDim2)
	end
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UDim2)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x or 0, 0, y or 0)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x or 0, 0, y or 0, 0)
end
UDim2.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UDim2.__sub = function(a, b)
	return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
UDim2.__tostring = function(u)
	return ("UDim2(%s, %s, %s, %s)"):format(u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset)
end

local Color3 = class("Color3")
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	h, s, v = h or 0, s or 0, v or 0
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local m = i % 6
	if m == 0 then
		return Color3.new(v, t, p)
	elseif m == 1 then
		return Color3.new(q, v, p)
	elseif m == 2 then
		return Color3.new(p, v, t)
	elseif m == 3 then
		return Color3.new(p, q, v)
	elseif m == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end
Color3.fromHex = function(hex)
	hex = hex:gsub("#", "")
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end
function Color3:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, v = 0, 0, max
	local d = max - min
	s = max == 0 and 0 or d / max
	if d ~= 0 then
		if max == r then
			h = (g - b) / d % 6
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end
	return h, s, v
end
Color3.toHSV = Color3.ToHSV
function Color3:ToHex()
	return ("%02X%02X%02X"):format(self.R * 255, self.G * 255, self.B * 255)
end
Color3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3.__tostring = function(c)
	return ("Color3(%.3f, %.3f, %.3f)"):format(c.R, c.G, c.B)
end

local Rect = class("Rect")
function Rect.new(a, b, c, d)
	return setmetatable({ Min = Vector2.new(a, b), Max = Vector2.new(c, d) }, Rect)
end

local NumberSequenceKeypoint = class("NumberSequenceKeypoint")
function NumberSequenceKeypoint.new(t, v)
	return setmetatable({ Time = t, Value = v }, NumberSequenceKeypoint)
end

local NumberSequence = class("NumberSequence")
function NumberSequence.new(a, b)
	if type(a) == "table" and getmetatable(a) ~= NumberSequenceKeypoint then
		return setmetatable({ Keypoints = a }, NumberSequence)
	end
	return setmetatable({
		Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) },
	}, NumberSequence)
end

local ColorSequenceKeypoint = class("ColorSequenceKeypoint")
function ColorSequenceKeypoint.new(t, v)
	assert(type(t) == "number", "ColorSequenceKeypoint time must be a number")
	assert(getmetatable(v) == Color3, "ColorSequenceKeypoint value must be a Color3")
	return setmetatable({ Time = t, Value = v }, ColorSequenceKeypoint)
end

local ColorSequence = class("ColorSequence")
function ColorSequence.new(a, b)
	if type(a) == "table" and getmetatable(a) ~= Color3 then
		return setmetatable({ Keypoints = a }, ColorSequence)
	end
	return setmetatable({
		Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) },
	}, ColorSequence)
end

local TweenInfo = class("TweenInfo")
function TweenInfo.new(time, style, dir, rep, reverses, delay)
	return setmetatable({
		Time = time or 1,
		EasingStyle = style,
		EasingDirection = dir,
		RepeatCount = rep or 0,
		Reverses = reverses or false,
		DelayTime = delay or 0,
	}, TweenInfo)
end

----------------------------------------------------------------------- Enum --

local EnumItem = class("EnumItem")
EnumItem.__tostring = function(e)
	return ("Enum.%s.%s"):format(e.EnumType, e.Name)
end

local EnumType = {}
EnumType.__index = function(self, key)
	local items = rawget(self, "__items")
	if not items[key] then
		items[key] = setmetatable({ Name = key, Value = self.__count, EnumType = self.__name }, EnumItem)
		self.__count = self.__count + 1
	end
	return items[key]
end

local Enum = setmetatable({}, {
	__index = function(self, key)
		local t = setmetatable({ __items = {}, __name = key, __count = 0 }, EnumType)
		rawset(self, key, t)
		return t
	end,
})

------------------------------------------------------------------- Instance --

local EVENTS = {
	InputBegan = true,
	InputEnded = true,
	InputChanged = true,
	MouseButton1Click = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseButton2Click = true,
	MouseButton2Down = true,
	MouseEnter = true,
	MouseLeave = true,
	MouseMoved = true,
	Focused = true,
	FocusLost = true,
	Destroying = true,
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
	AncestryChanged = true,
	Ended = true,
	Activated = true,
	TouchTap = true,
	RenderStepped = true,
	Heartbeat = true,
	Stepped = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	TextBoxFocused = true,
	TextBoxFocusReleased = true,
	WindowFocused = true,
	WindowFocusReleased = true,
}

local CLASS_DEFAULTS = {
	AbsoluteSize = function()
		return Vector2.new(200, 30)
	end,
	AbsolutePosition = function()
		return Vector2.new(0, 0)
	end,
	AbsoluteContentSize = function()
		return Vector2.new(200, 30)
	end,
}

local CLASS_TREE = {
	Frame = { "GuiObject", "GuiBase2d", "Instance" },
	CanvasGroup = { "GuiObject", "GuiBase2d", "Instance" },
	ScrollingFrame = { "GuiObject", "GuiBase2d", "Instance" },
	TextLabel = { "GuiObject", "GuiBase2d", "Instance" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d", "Instance" },
	TextBox = { "GuiObject", "GuiBase2d", "Instance" },
	ImageLabel = { "GuiObject", "GuiBase2d", "Instance" },
	ImageButton = { "GuiButton", "GuiObject", "GuiBase2d", "Instance" },
	ScreenGui = { "LayerCollector", "GuiBase2d", "Instance" },
	UICorner = { "UIComponent", "Instance" },
	UIStroke = { "UIComponent", "Instance" },
	UIGradient = { "UIComponent", "Instance" },
	UIPadding = { "UIComponent", "Instance" },
	UIListLayout = { "UILayout", "UIComponent", "Instance" },
	UIScale = { "UIComponent", "Instance" },
	UISizeConstraint = { "UIComponent", "Instance" },
	BlurEffect = { "PostEffect", "Instance" },
	Sound = { "Instance" },
	Folder = { "Instance" },
}

local VALID_CLASSES = {}
for name in pairs(CLASS_TREE) do
	VALID_CLASSES[name] = true
end

local Instance = {}
local InstanceMT = {}

local function newInstance(className)
	if not VALID_CLASSES[className] then
		error("Unable to create an Instance of type \"" .. tostring(className) .. "\"", 0)
	end
	Mock.Instances = Mock.Instances + 1

	local self = setmetatable({}, InstanceMT)
	rawset(self, "__props", {
		Name = className,
		ClassName = className,
		Parent = nil,
		Visible = true,
		Active = false,
		ZIndex = 1,
		Text = "",
		Rotation = 0,
		BackgroundTransparency = 0,
		TextTransparency = 0,
		ImageTransparency = 0,
		Scale = 1,
		Thickness = 1,
		Transparency = 0,
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 0),
	})
	rawset(self, "__events", {})
	rawset(self, "__propSignals", {})
	rawset(self, "__children", {})
	rawset(self, "__attributes", {})
	rawset(self, "__destroyed", false)
	return self
end

local InstanceMethods = {}

function InstanceMethods:IsA(className)
	local props = rawget(self, "__props")
	if props.ClassName == className then
		return true
	end
	for _, parent in ipairs(CLASS_TREE[props.ClassName] or {}) do
		if parent == className then
			return true
		end
	end
	return false
end

function InstanceMethods:GetChildren()
	local out = {}
	for i, c in ipairs(rawget(self, "__children")) do
		out[i] = c
	end
	return out
end

InstanceMethods.GetDescendants = function(self)
	local out = {}
	for _, c in ipairs(rawget(self, "__children")) do
		table.insert(out, c)
		for _, d in ipairs(c:GetDescendants()) do
			table.insert(out, d)
		end
	end
	return out
end

function InstanceMethods:FindFirstChild(name)
	for _, c in ipairs(rawget(self, "__children")) do
		if rawget(c, "__props").Name == name then
			return c
		end
	end
	return nil
end

function InstanceMethods:FindFirstChildOfClass(className)
	for _, c in ipairs(rawget(self, "__children")) do
		if rawget(c, "__props").ClassName == className then
			return c
		end
	end
	return nil
end

InstanceMethods.FindFirstChildWhichIsA = InstanceMethods.FindFirstChildOfClass
InstanceMethods.WaitForChild = InstanceMethods.FindFirstChild

function InstanceMethods:ClearAllChildren()
	for _, c in ipairs(self:GetChildren()) do
		c:Destroy()
	end
end

function InstanceMethods:Destroy()
	if rawget(self, "__destroyed") then
		return
	end
	rawset(self, "__destroyed", true)
	local events = rawget(self, "__events")
	if events.Destroying then
		events.Destroying:Fire()
	end
	for _, c in ipairs(self:GetChildren()) do
		c:Destroy()
	end
	local props = rawget(self, "__props")
	if props.Parent then
		local siblings = rawget(props.Parent, "__children")
		for i, c in ipairs(siblings) do
			if c == self then
				table.remove(siblings, i)
				break
			end
		end
	end
	props.Parent = nil
end

InstanceMethods.Remove = InstanceMethods.Destroy

function InstanceMethods:GetPropertyChangedSignal(prop)
	local signals = rawget(self, "__propSignals")
	if not signals[prop] then
		signals[prop] = Signal.new(prop .. "Changed")
	end
	return signals[prop]
end

function InstanceMethods:GetAttribute(name)
	return rawget(self, "__attributes")[name]
end

function InstanceMethods:SetAttribute(name, value)
	rawget(self, "__attributes")[name] = value
end

function InstanceMethods:GetFullName()
	return rawget(self, "__props").Name
end

InstanceMT.__index = function(self, key)
	local method = InstanceMethods[key]
	if method then
		return method
	end

	local events = rawget(self, "__events")
	if events[key] then
		return events[key]
	end
	if EVENTS[key] then
		events[key] = Signal.new(key)
		return events[key]
	end

	local props = rawget(self, "__props")
	if props[key] ~= nil then
		return props[key]
	end

	local default = CLASS_DEFAULTS[key]
	if default then
		props[key] = default()
		return props[key]
	end

	-- children are reachable by name, like the real engine
	local child = InstanceMethods.FindFirstChild(self, key)
	if child then
		return child
	end

	return nil
end

InstanceMT.__newindex = function(self, key, value)
	local props = rawget(self, "__props")

	if key == "Parent" then
		local old = props.Parent
		if old then
			local siblings = rawget(old, "__children")
			for i, c in ipairs(siblings) do
				if c == self then
					table.remove(siblings, i)
					break
				end
			end
		end
		props.Parent = value
		if value then
			if type(value) ~= "table" or not rawget(value, "__children") then
				error("Parent must be an Instance, got " .. tostring(value), 0)
			end
			table.insert(rawget(value, "__children"), self)
			local ev = rawget(value, "__events")
			if ev.ChildAdded then
				ev.ChildAdded:Fire(self)
			end
		end
		return
	end

	props[key] = value

	local signals = rawget(self, "__propSignals")
	if signals[key] then
		signals[key]:Fire()
	end
	local events = rawget(self, "__events")
	if events.Changed then
		events.Changed:Fire(key)
	end
end

InstanceMT.__tostring = function(self)
	return rawget(self, "__props").Name
end

Instance.new = function(className, parent)
	local inst = newInstance(className)
	if parent then
		inst.Parent = parent
	end
	return inst
end

Mock.newInstance = newInstance

------------------------------------------------------------------- services --

local function makeService(className, name)
	local service = newInstance(className == nil and "Folder" or "Folder")
	rawget(service, "__props").Name = name
	rawget(service, "__props").ClassName = name
	return service
end

local Services = {}

local CoreGui = makeService(nil, "CoreGui")
local Lighting = makeService(nil, "Lighting")
local Workspace = makeService(nil, "Workspace")

local UserInputService = makeService(nil, "UserInputService")
UserInputService.TouchEnabled = false
UserInputService.KeyboardEnabled = true
UserInputService.MouseIconEnabled = true
rawget(UserInputService, "__props").MousePosition = Vector2.new(100, 100)
function UserInputService:GetMouseLocation()
	return rawget(self, "__props").MousePosition
end
function UserInputService:GetFocusedTextBox()
	return rawget(self, "__props").FocusedTextBox
end

local RunService = makeService(nil, "RunService")
function RunService:IsStudio()
	return false
end
function RunService:IsClient()
	return true
end

local TweenService = makeService(nil, "TweenService")
Mock.TweensCreated = 0
function TweenService:Create(object, info, goal)
	Mock.TweensCreated = Mock.TweensCreated + 1
	if type(object) ~= "table" or not rawget(object, "__props") then
		error("TweenService:Create expects an Instance, got " .. tostring(object), 0)
	end
	if getmetatable(info) ~= TweenInfo then
		error("TweenService:Create expects a TweenInfo", 0)
	end
	local tween = {
		Instance = object,
		TweenInfo = info,
		Completed = Signal.new("Completed"),
		PlaybackState = Enum.PlaybackState.Begin,
	}
	function tween:Play()
		-- apply the goal immediately; we only care that properties are valid
		for prop, value in pairs(goal) do
			object[prop] = value
		end
		self.PlaybackState = Enum.PlaybackState.Completed
		self.Completed:Fire(Enum.PlaybackState.Completed)
	end
	function tween:Cancel() end
	function tween:Pause() end
	function tween:Destroy() end
	return tween
end

local HttpService = makeService(nil, "HttpService")

local function jsonEncode(value, indent)
	local t = type(value)
	if value == nil then
		return "null"
	elseif t == "boolean" then
		return tostring(value)
	elseif t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "null"
		end
		if math.floor(value) == value and math.abs(value) < 1e15 then
			return string.format("%d", value)
		end
		return string.format("%.14g", value)
	elseif t == "string" then
		local out = value:gsub('[%c"\\]', function(c)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
			return map[c] or string.format("\\u%04x", c:byte())
		end)
		return '"' .. out .. '"'
	elseif t == "table" then
		local isArray, count = true, 0
		for k in pairs(value) do
			count = count + 1
			if type(k) ~= "number" then
				isArray = false
			end
		end
		if isArray and count == #value then
			local parts = {}
			for _, v in ipairs(value) do
				table.insert(parts, jsonEncode(v))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		local keys = {}
		for k in pairs(value) do
			table.insert(keys, tostring(k))
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local v = value[k] == nil and value[tonumber(k)] or value[k]
			table.insert(parts, jsonEncode(tostring(k)) .. ":" .. jsonEncode(v))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

local function jsonDecode(str)
	local pos = 1

	local function skip()
		while pos <= #str and str:sub(pos, pos):match("%s") do
			pos = pos + 1
		end
	end

	local parseValue

	local function parseString()
		pos = pos + 1
		local out = {}
		while pos <= #str do
			local c = str:sub(pos, pos)
			if c == '"' then
				pos = pos + 1
				return table.concat(out)
			elseif c == "\\" then
				local n = str:sub(pos + 1, pos + 1)
				local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if map[n] then
					table.insert(out, map[n])
					pos = pos + 2
				elseif n == "u" then
					table.insert(out, utf8.char(tonumber(str:sub(pos + 2, pos + 5), 16)))
					pos = pos + 6
				else
					pos = pos + 2
				end
			else
				table.insert(out, c)
				pos = pos + 1
			end
		end
		error("unterminated string in JSON", 0)
	end

	parseValue = function()
		skip()
		local c = str:sub(pos, pos)
		if c == "{" then
			pos = pos + 1
			local obj = {}
			skip()
			if str:sub(pos, pos) == "}" then
				pos = pos + 1
				return obj
			end
			while true do
				skip()
				local key = parseString()
				skip()
				pos = pos + 1 -- :
				obj[key] = parseValue()
				skip()
				local ch = str:sub(pos, pos)
				pos = pos + 1
				if ch == "}" then
					return obj
				end
			end
		elseif c == "[" then
			pos = pos + 1
			local arr = {}
			skip()
			if str:sub(pos, pos) == "]" then
				pos = pos + 1
				return arr
			end
			while true do
				table.insert(arr, parseValue())
				skip()
				local ch = str:sub(pos, pos)
				pos = pos + 1
				if ch == "]" then
					return arr
				end
			end
		elseif c == '"' then
			return parseString()
		elseif str:sub(pos, pos + 3) == "true" then
			pos = pos + 4
			return true
		elseif str:sub(pos, pos + 4) == "false" then
			pos = pos + 5
			return false
		elseif str:sub(pos, pos + 3) == "null" then
			pos = pos + 4
			return nil
		else
			local num = str:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
			if not num then
				error("unexpected character in JSON at " .. pos .. ": " .. c, 0)
			end
			pos = pos + #num
			return tonumber(num)
		end
	end

	local ok = parseValue()
	return ok
end

function HttpService:JSONEncode(value)
	return jsonEncode(value)
end
function HttpService:JSONDecode(value)
	return jsonDecode(value)
end
function HttpService:GenerateGUID()
	return "{MOCK-GUID}"
end

local GuiService = makeService(nil, "GuiService")
function GuiService:GetGuiInset()
	return Vector2.new(0, 36), Vector2.new(0, 0)
end

local TextService = makeService(nil, "TextService")
function TextService:GetTextSize()
	return Vector2.new(50, 14)
end

local Teams = makeService(nil, "Teams")
function Teams:GetTeams()
	return {}
end

local Players = makeService(nil, "Players")
local LocalPlayer = newInstance("Folder")
LocalPlayer.Name = "TestPlayer"
local OtherPlayer = newInstance("Folder")
OtherPlayer.Name = "SomeoneElse"
rawget(Players, "__props").LocalPlayer = LocalPlayer
function Players:GetPlayers()
	return { LocalPlayer, OtherPlayer }
end
local PlayerGui = newInstance("Folder")
PlayerGui.Name = "PlayerGui"
rawget(PlayerGui, "__props").ClassName = "PlayerGui"
PlayerGui.Parent = LocalPlayer

Services.CoreGui = CoreGui
Services.Lighting = Lighting
Services.Workspace = Workspace
Services.UserInputService = UserInputService
Services.RunService = RunService
Services.TweenService = TweenService
Services.HttpService = HttpService
Services.GuiService = GuiService
Services.TextService = TextService
Services.Players = Players
Services.Teams = Teams

Mock.Services = Services
Mock.LocalPlayer = LocalPlayer

---------------------------------------------------------------------- game --

local game = newInstance("Folder")
rawget(game, "__props").Name = "game"
function game:GetService(name)
	local service = Services[name]
	if not service then
		error("GetService: unknown service " .. tostring(name), 0)
	end
	return service
end
game.FindService = game.GetService
rawget(game, "__props").PlaceId = 1234567
rawget(game, "__props").GameId = 7654321
rawget(game, "__props").JobId = "mock-job-id"

----------------------------------------------------------------------- task --

local task = {}
function task.spawn(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error("task.spawn error: " .. tostring(err), 0)
	end
	return co
end
function task.defer(fn, ...)
	table.insert(Mock.Scheduled, { time = Mock.Clock, fn = fn, args = { ... } })
end
function task.delay(seconds, fn, ...)
	table.insert(Mock.Scheduled, { time = Mock.Clock + (seconds or 0), fn = fn, args = { ... } })
end
function task.wait(seconds)
	Mock.Clock = Mock.Clock + (seconds or 0)
	return seconds or 0
end
task.cancel = function() end

function Mock.Flush(limit)
	local iterations = 0
	while #Mock.Scheduled > 0 do
		iterations = iterations + 1
		if iterations > (limit or 5000) then
			error("scheduler did not drain -- infinite task.delay loop?", 0)
		end
		table.sort(Mock.Scheduled, function(a, b)
			return a.time < b.time
		end)
		local job = table.remove(Mock.Scheduled, 1)
		Mock.Clock = math.max(Mock.Clock, job.time)
		local ok, err = pcall(job.fn, table.unpack(job.args))
		if not ok then
			error("scheduled job error: " .. tostring(err), 0)
		end
	end
end

------------------------------------------------------------------ installer --

function Mock.Install(env)
	env = env or _G

	env.game = game
	env.workspace = Workspace
	env.Instance = Instance
	env.Enum = Enum
	env.Vector2 = Vector2
	env.Vector3 = Vector3
	env.UDim = UDim
	env.UDim2 = UDim2
	env.Color3 = Color3
	env.Rect = Rect
	env.NumberSequence = NumberSequence
	env.NumberSequenceKeypoint = NumberSequenceKeypoint
	env.ColorSequence = ColorSequence
	env.ColorSequenceKeypoint = ColorSequenceKeypoint
	env.TweenInfo = TweenInfo
	env.task = task
	env.wait = task.wait
	env.unpack = table.unpack
	env.tick = function()
		return Mock.Clock
	end

	env.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring(select(i, ...))
		end
		table.insert(Mock.Warnings, table.concat(parts, " "))
	end

	env.typeof = function(value)
		local mt = getmetatable(value)
		if mt == Color3 then
			return "Color3"
		elseif mt == Vector2 then
			return "Vector2"
		elseif mt == Vector3 then
			return "Vector3"
		elseif mt == UDim2 then
			return "UDim2"
		elseif mt == UDim then
			return "UDim"
		elseif mt == EnumItem then
			return "EnumItem"
		elseif mt == TweenInfo then
			return "TweenInfo"
		elseif mt == InstanceMT then
			return "Instance"
		elseif type(value) == "table" and rawget(value, "__props") then
			return "Instance"
		end
		return type(value)
	end

	-- Luau standard library extras that plain Lua lacks
	math.clamp = math.clamp or function(v, min, max)
		return math.max(min, math.min(max, v))
	end
	math.round = math.round or function(v)
		return math.floor(v + 0.5)
	end
	table.find = table.find or function(t, v)
		for i, item in ipairs(t) do
			if item == v then
				return i
			end
		end
		return nil
	end
	table.create = table.create or function(n, v)
		local out = {}
		for i = 1, n do
			out[i] = v
		end
		return out
	end
	table.clear = table.clear or function(t)
		for k in pairs(t) do
			t[k] = nil
		end
	end
	string.split = string.split or function(s, sep)
		local out = {}
		for part in tostring(s):gmatch("([^" .. (sep or ",") .. "]+)") do
			table.insert(out, part)
		end
		return out
	end

	return env
end

--------------------------------------------------- executor API simulation --

Mock.FileSystem = {}

function Mock.InstallExecutorAPI(env)
	env = env or _G
	local fs = Mock.FileSystem

	env.identifyexecutor = function()
		return "MockExecutor", "1.0.0"
	end
	env.getgenv = function()
		Mock.Genv = Mock.Genv or {}
		return Mock.Genv
	end
	env.gethui = function()
		return CoreGui
	end
	env.cloneref = function(o)
		return o
	end
	env.setclipboard = function(text)
		Mock.Clipboard = text
	end
	env.protectgui = function() end

	env.isfolder = function(path)
		return fs["folder:" .. path] == true
	end
	env.makefolder = function(path)
		fs["folder:" .. path] = true
	end
	env.isfile = function(path)
		return fs[path] ~= nil
	end
	env.readfile = function(path)
		if fs[path] == nil then
			error("file does not exist: " .. path, 0)
		end
		return fs[path]
	end
	env.writefile = function(path, contents)
		fs[path] = contents
	end
	env.appendfile = function(path, contents)
		fs[path] = (fs[path] or "") .. contents
	end
	env.delfile = function(path)
		fs[path] = nil
	end
	env.listfiles = function(folder)
		local out = {}
		for path in pairs(fs) do
			if not path:match("^folder:") and path:sub(1, #folder) == folder then
				table.insert(out, path)
			end
		end
		table.sort(out)
		return out
	end

	return env
end

return Mock
