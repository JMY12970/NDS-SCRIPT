--[[
     ██████╗ ███████╗██╗ ██████╗ ███╗   ██╗██╗   ██╗██╗
    ██╔═══██╗╚══███╔╝██║██╔═══██╗████╗  ██║██║   ██║██║
    ██║   ██║  ███╔╝ ██║██║   ██║██╔██╗ ██║██║   ██║██║
    ██║   ██║ ███╔╝  ██║██║   ██║██║╚██╗██║██║   ██║██║
    ╚██████╔╝███████╗██║╚██████╔╝██║ ╚████║╚██████╔╝██║
     ╚═════╝ ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝

    OzionUI  --  v1.0.0
    A heavily animated, executor-ready UI library for Roblox.

    Drop-in familiar: the public API mirrors the Obsidian / Linoria style,
    so scripts written for those libraries only need their loadstring swapped.

    Usage:
        local Library = loadstring(game:HttpGet("<raw url>/Library.lua"))()

    Docs: see README.md + docs/ in the repository.
    License: MIT
]]

--//////////////////////////////////////////////////////////////////////////
--// Environment                                                          //
--//////////////////////////////////////////////////////////////////////////

local CloneRef = clonereference or cloneref or function(Object)
	return Object
end

local function GetService(Name)
	local Ok, Service = pcall(function()
		return game:GetService(Name)
	end)
	if not Ok or not Service then
		return nil
	end
	local Ok2, Cloned = pcall(CloneRef, Service)
	return Ok2 and Cloned or Service
end

local Players = GetService("Players")
local UserInputService = GetService("UserInputService")
local TweenService = GetService("TweenService")
local RunService = GetService("RunService")
local HttpService = GetService("HttpService")
local TextService = GetService("TextService")
local Lighting = GetService("Lighting")
local CoreGui = GetService("CoreGui")
local GuiService = GetService("GuiService")

local LocalPlayer = Players and Players.LocalPlayer

-- Executor feature detection. Everything below degrades gracefully so the
-- library still runs inside Roblox Studio / a normal LocalScript.
local Env = {
	GetHui = (type(gethui) == "function") and gethui or nil,
	Protect = (type(syn) == "table" and type(syn.protect_gui) == "function") and syn.protect_gui
		or (type(protectgui) == "function") and protectgui
		or nil,
	SetClipboard = setclipboard or toclipboard or (type(Clipboard) == "table" and Clipboard.set) or nil,
	WriteFile = writefile,
	ReadFile = readfile,
	IsFile = isfile,
	IsFolder = isfolder,
	MakeFolder = makefolder,
	ListFiles = listfiles,
	DelFile = delfile,
	Request = (syn and syn.request) or (http and http.request) or http_request or request or nil,
}

--//////////////////////////////////////////////////////////////////////////
--// Library root                                                         //
--//////////////////////////////////////////////////////////////////////////

local Library = {
	Name = "OzionUI",
	Version = "1.0.0",

	-- state
	Toggled = false,
	Unloaded = false,
	IsMobile = false,
	CantDragForced = false,
	Window = nil,
	ActiveTab = nil,

	-- behaviour flags (public, change them whenever you like)
	Animations = true, -- master switch for every tween in the library
	AnimationSpeed = 1, -- multiplier: 0.5 = twice as fast, 2 = twice as slow
	ShowCustomCursor = true,
	ShowToggleFrameInKeybinds = true,
	NotifyOnError = true,
	ForceCheckbox = false,
	NotifySide = "Right", -- "Left" | "Right"
	CornerRadius = 6,
	DPIScale = 1,
	UseBlur = true,
	RippleEnabled = true,

	-- keybind used to open / close the menu
	ToggleKeybind = nil, -- set to a KeyPicker object to sync with one
	MenuKeybind = Enum.KeyCode.RightControl,

	-- internals
	Registry = {},
	HudRegistry = {},
	Connections = {},
	Threads = {},
	Instances = {},
	Tabs = {},
	DependencyBoxes = {},
	KeybindToggles = {},
	Notifications = {},
	UnloadCallbacks = {},
	OpenedFrames = {},

	-- element stores (also exposed through getgenv)
	Toggles = {},
	Options = {},

	-- fonts available to ThemeManager
	Fonts = {
		Gotham = Enum.Font.Gotham,
		GothamMedium = Enum.Font.GothamMedium,
		GothamBold = Enum.Font.GothamBold,
		SourceSans = Enum.Font.SourceSans,
		SourceSansBold = Enum.Font.SourceSansBold,
		Code = Enum.Font.Code,
		Arcade = Enum.Font.Arcade,
		Fantasy = Enum.Font.Fantasy,
		Highway = Enum.Font.Highway,
		SciFi = Enum.Font.SciFi,
	},

	-- the active colour scheme
	Scheme = {
		BackgroundColor = Color3.fromRGB(12, 12, 16),
		MainColor = Color3.fromRGB(20, 20, 27),
		AccentColor = Color3.fromRGB(125, 90, 255),
		OutlineColor = Color3.fromRGB(40, 40, 52),
		FontColor = Color3.fromRGB(240, 240, 250),
		Font = Enum.Font.GothamMedium,

		-- helpers used internally, still theme-able
		Red = Color3.fromRGB(255, 70, 90),
		Green = Color3.fromRGB(80, 230, 150),
		Dark = Color3.fromRGB(8, 8, 11),
		White = Color3.fromRGB(255, 255, 255),
		Black = Color3.fromRGB(0, 0, 0),
	},
}

Library.Toggles = Library.Toggles
Library.Options = Library.Options

local Toggles = Library.Toggles
local Options = Library.Options

if type(getgenv) == "function" then
	local G = getgenv()
	G.Toggles = Toggles
	G.Options = Options
	G.OzionUI = Library
end

--//////////////////////////////////////////////////////////////////////////
--// Small utilities                                                      //
--//////////////////////////////////////////////////////////////////////////

local Unpack = table.unpack or unpack

local function Clamp(Value, Min, Max)
	if Value < Min then
		return Min
	elseif Value > Max then
		return Max
	end
	return Value
end

local function Round(Value, Decimals)
	local Mult = 10 ^ (Decimals or 0)
	return math.floor(Value * Mult + 0.5) / Mult
end

local function Lerp(A, B, Alpha)
	return A + (B - A) * Alpha
end

local function TableFind(Tbl, Value)
	for Index, Item in pairs(Tbl) do
		if Item == Value then
			return Index
		end
	end
	return nil
end

local function DeepCopy(Tbl)
	local Out = {}
	for Key, Value in pairs(Tbl) do
		if type(Value) == "table" then
			Out[Key] = DeepCopy(Value)
		else
			Out[Key] = Value
		end
	end
	return Out
end

function Library:Clamp(Value, Min, Max)
	return Clamp(Value, Min, Max)
end

function Library:Round(Value, Decimals)
	return Round(Value, Decimals)
end

-- Returns a slightly darker / lighter variant of a colour. Used everywhere to
-- build gradients out of a single accent colour.
function Library:GetShade(Color, Amount)
	local H, S, V = Color:ToHSV()
	return Color3.fromHSV(H, Clamp(S, 0, 1), Clamp(V + (Amount or -0.15), 0, 1))
end

function Library:GetDarkerColor(Color)
	return Library:GetShade(Color, -0.18)
end

function Library:GetLighterColor(Color)
	return Library:GetShade(Color, 0.18)
end

function Library:ColorToHex(Color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(Color.R * 255 + 0.5),
		math.floor(Color.G * 255 + 0.5),
		math.floor(Color.B * 255 + 0.5)
	)
end

function Library:HexToColor(Hex)
	Hex = tostring(Hex):gsub("#", "")
	if #Hex == 3 then
		Hex = Hex:sub(1, 1):rep(2) .. Hex:sub(2, 2):rep(2) .. Hex:sub(3, 3):rep(2)
	end
	if #Hex ~= 6 then
		return nil
	end
	local R = tonumber(Hex:sub(1, 2), 16)
	local G = tonumber(Hex:sub(3, 4), 16)
	local B = tonumber(Hex:sub(5, 6), 16)
	if not (R and G and B) then
		return nil
	end
	return Color3.fromRGB(R, G, B)
end

-- Every callback the user gives us is wrapped so a broken script can never
-- take the menu down with it.
function Library:SafeCallback(Func, ...)
	if type(Func) ~= "function" then
		return
	end

	local Args = table.pack and table.pack(...) or { ... }
	local Count = Args.n or select("#", ...)
	local Success, Result = pcall(function()
		return Func(Unpack(Args, 1, Count))
	end)

	if Success then
		return Result
	end

	local Message = Result
	if type(Message) ~= "string" then
		Message = tostring(Message)
	end
	local _, Position = Message:find(":%d+: ")
	if Position then
		Message = Message:sub(Position + 1)
	end

	warn("[OzionUI] callback error: " .. Message)
	if Library.NotifyOnError and not Library.Unloaded then
		Library:Notify({
			Title = "Callback error",
			Description = Message,
			Time = 6,
			Type = "Error",
		})
	end
end

function Library:Spawn(Func, ...)
	local Args = table.pack and table.pack(...) or { ... }
	local Count = Args.n or select("#", ...)
	local Runner = function()
		Library:SafeCallback(Func, Unpack(Args, 1, Count))
	end
	if task and task.spawn then
		return task.spawn(Runner)
	end
	return coroutine.wrap(Runner)()
end

function Library:Delay(Time, Func)
	if task and task.delay then
		return task.delay(Time, function()
			Library:SafeCallback(Func)
		end)
	end
	return Library:Spawn(function()
		wait(Time)
		Func()
	end)
end

--//////////////////////////////////////////////////////////////////////////
--// Connection + instance bookkeeping (so :Unload leaves nothing behind)  //
--//////////////////////////////////////////////////////////////////////////

function Library:Connect(Signal, Callback)
	if not Signal then
		return nil
	end
	local Connection = Signal:Connect(function(...)
		if Library.Unloaded then
			return
		end
		return Callback(...)
	end)
	table.insert(Library.Connections, Connection)
	return Connection
end

function Library:Track(Instance)
	table.insert(Library.Instances, Instance)
	return Instance
end

--//////////////////////////////////////////////////////////////////////////
--// Instance factory                                                     //
--//////////////////////////////////////////////////////////////////////////

local function New(ClassName, Properties, Children)
	local Object = Instance.new(ClassName)
	Properties = Properties or {}

	local Parent = Properties.Parent
	Properties.Parent = nil

	for Property, Value in pairs(Properties) do
		Object[Property] = Value
	end

	if Children then
		for _, Child in pairs(Children) do
			Child.Parent = Object
		end
	end

	if Parent then
		Object.Parent = Parent
	end

	Library:Track(Object)
	return Object
end

Library.New = function(_, ...)
	return New(...)
end

-- Rounded corners helper
local function Corner(Parent, Radius)
	return New("UICorner", {
		CornerRadius = UDim.new(0, Radius or Library.CornerRadius),
		Parent = Parent,
	})
end

-- Outline helper
local function Stroke(Parent, Color, Thickness, Transparency)
	return New("UIStroke", {
		Color = Color or Library.Scheme.OutlineColor,
		Thickness = Thickness or 1,
		Transparency = Transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = Parent,
	})
end

local function Padding(Parent, Top, Bottom, Left, Right)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, Top or 0),
		PaddingBottom = UDim.new(0, Bottom or Top or 0),
		PaddingLeft = UDim.new(0, Left or Top or 0),
		PaddingRight = UDim.new(0, Right or Left or Top or 0),
		Parent = Parent,
	})
end

local function ListLayout(Parent, PaddingPx, Direction, Alignment)
	return New("UIListLayout", {
		Padding = UDim.new(0, PaddingPx or 6),
		FillDirection = Direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Alignment or Enum.HorizontalAlignment.Left,
		Parent = Parent,
	})
end

--//////////////////////////////////////////////////////////////////////////
--// Animation engine                                                     //
--//////////////////////////////////////////////////////////////////////////

local Easing = {
	Smooth = { Enum.EasingStyle.Quint, Enum.EasingDirection.Out },
	Snappy = { Enum.EasingStyle.Back, Enum.EasingDirection.Out },
	Bounce = { Enum.EasingStyle.Bounce, Enum.EasingDirection.Out },
	Linear = { Enum.EasingStyle.Linear, Enum.EasingDirection.InOut },
	Soft = { Enum.EasingStyle.Sine, Enum.EasingDirection.Out },
	Elastic = { Enum.EasingStyle.Elastic, Enum.EasingDirection.Out },
}
Library.Easing = Easing

--[[
    Library:Tween(Object, Properties, Duration, Preset, Repeat, Reverses)

    Preset is either a key of Library.Easing ("Smooth", "Snappy", "Bounce",
    "Linear", "Soft", "Elastic") or a table {EasingStyle, EasingDirection}.
    Honours Library.Animations / Library.AnimationSpeed.
]]
function Library:Tween(Object, Properties, Duration, Preset, Repeat, Reverses)
	if not Object then
		return nil
	end

	if not Library.Animations then
		for Property, Value in pairs(Properties) do
			pcall(function()
				Object[Property] = Value
			end)
		end
		return nil
	end

	local Style = Easing.Smooth
	if type(Preset) == "string" then
		Style = Easing[Preset] or Easing.Smooth
	elseif type(Preset) == "table" then
		Style = Preset
	end

	local Info = TweenInfo.new(
		(Duration or 0.18) * (Library.AnimationSpeed or 1),
		Style[1],
		Style[2],
		Repeat or 0,
		Reverses or false
	)

	local Animation = TweenService:Create(Object, Info, Properties)
	Animation:Play()
	return Animation
end

local Tween = function(...)
	return Library:Tween(...)
end

-- Material-style ripple that expands from the click position.
function Library:Ripple(Button, X, Y, Color)
	if not Library.RippleEnabled or not Library.Animations or Library.Unloaded then
		return
	end

	local Ok = pcall(function()
		local Size = Button.AbsoluteSize
		local Position = Button.AbsolutePosition
		local Radius = math.max(Size.X, Size.Y) * 1.6

		local OffsetX = (X or (Position.X + Size.X / 2)) - Position.X
		local OffsetY = (Y or (Position.Y + Size.Y / 2)) - Position.Y

		local Circle = New("Frame", {
			Name = "Ripple",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color or Library.Scheme.AccentColor,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(OffsetX, OffsetY),
			Size = UDim2.fromOffset(0, 0),
			ZIndex = 20,
			Parent = Button,
		})
		New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Circle })

		Library:Tween(Circle, { Size = UDim2.fromOffset(Radius, Radius), BackgroundTransparency = 1 }, 0.5, "Smooth")
		Library:Delay(0.55 * (Library.AnimationSpeed or 1), function()
			if Circle and Circle.Parent then
				Circle:Destroy()
			end
		end)
	end)
	return Ok
end

-- A one shot glow pulse, used when toggles are switched on.
function Library:Pulse(Object, Color)
	if not Library.Animations then
		return
	end
	pcall(function()
		local Glow = New("UIStroke", {
			Color = Color or Library.Scheme.AccentColor,
			Thickness = 0,
			Transparency = 0.1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = Object,
		})
		Library:Tween(Glow, { Thickness = 4, Transparency = 1 }, 0.45, "Soft")
		Library:Delay(0.5 * (Library.AnimationSpeed or 1), function()
			if Glow and Glow.Parent then
				Glow:Destroy()
			end
		end)
	end)
end

-- Infinite rotating gradient, used for the window outline + watermark.
function Library:AnimateGradient(Gradient, Seconds)
	if not Gradient then
		return
	end
	local Animation = Library:Tween(Gradient, { Rotation = 360 }, Seconds or 6, "Linear", -1, false)
	return Animation
end

--//////////////////////////////////////////////////////////////////////////
--// Theme registry                                                       //
--//////////////////////////////////////////////////////////////////////////

--[[
    Library:AddToRegistry(Instance, { BackgroundColor3 = "MainColor" })

    Values may be a scheme key (string) or a function that receives the scheme
    and returns the value, which is how gradients / derived shades stay live.
]]
function Library:AddToRegistry(Object, Properties, IsHud)
	local Entry = { Object = Object, Properties = Properties }
	table.insert(Library.Registry, Entry)
	if IsHud then
		table.insert(Library.HudRegistry, Entry)
	end
	return Entry
end

function Library:RemoveFromRegistry(Object)
	for Index = #Library.Registry, 1, -1 do
		if Library.Registry[Index].Object == Object then
			table.remove(Library.Registry, Index)
		end
	end
end

local function ResolveSchemeValue(Value)
	if type(Value) == "string" then
		return Library.Scheme[Value]
	elseif type(Value) == "function" then
		return Value(Library.Scheme)
	end
	return Value
end

function Library:UpdateColorsUsingRegistry()
	for _, Entry in pairs(Library.Registry) do
		for Property, SchemeKey in pairs(Entry.Properties) do
			pcall(function()
				Entry.Object[Property] = ResolveSchemeValue(SchemeKey)
			end)
		end
	end
end

function Library:SetAccent(Color)
	Library.Scheme.AccentColor = Color
	Library:UpdateColorsUsingRegistry()
end

function Library:SetFont(Font)
	if type(Font) == "string" then
		Font = Library.Fonts[Font] or Enum.Font[Font]
	end
	if not Font then
		return
	end
	Library.Scheme.Font = Font
	Library:UpdateColorsUsingRegistry()
end

function Library:SetDPIScale(Scale)
	Library.DPIScale = Clamp((tonumber(Scale) or 100) / 100, 0.5, 2)
	for _, ScaleObject in pairs(Library.ScaleObjects or {}) do
		pcall(function()
			ScaleObject.Scale = Library.DPIScale
		end)
	end
end

Library.ScaleObjects = {}

--//////////////////////////////////////////////////////////////////////////
--// ScreenGui creation + executor protection                             //
--//////////////////////////////////////////////////////////////////////////

local function RandomString(Length)
	local Characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local Output = ""
	for _ = 1, Length or 12 do
		local Index = math.random(1, #Characters)
		Output = Output .. Characters:sub(Index, Index)
	end
	return Output
end

local function ParentGui(Gui)
	-- 1. gethui() -- hidden container, safest in most executors
	if Env.GetHui then
		local Ok = pcall(function()
			Gui.Parent = Env.GetHui()
		end)
		if Ok and Gui.Parent then
			return "gethui"
		end
	end

	-- 2. syn.protect_gui / protectgui + CoreGui
	if Env.Protect then
		pcall(Env.Protect, Gui)
	end

	if CoreGui then
		local Ok = pcall(function()
			Gui.Parent = CoreGui
		end)
		if Ok and Gui.Parent then
			return "coregui"
		end
	end

	-- 3. PlayerGui (Studio / normal LocalScript)
	if LocalPlayer then
		local Ok = pcall(function()
			Gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		end)
		if Ok and Gui.Parent then
			return "playergui"
		end
	end

	return "none"
end

function Library:GetScreenGui()
	if Library.ScreenGui and Library.ScreenGui.Parent then
		return Library.ScreenGui
	end

	local Gui = Instance.new("ScreenGui")
	Gui.Name = RandomString(math.random(10, 16))
	Gui.ResetOnSpawn = false
	Gui.IgnoreGuiInset = true
	Gui.DisplayOrder = 2147483646
	pcall(function()
		Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end)
	pcall(function()
		Gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)

	Library.GuiParentMethod = ParentGui(Gui)
	Library.ScreenGui = Gui
	Library:Track(Gui)

	-- layer used by dropdown popups / colour pickers so they always draw above
	Library.PopupLayer = New("Frame", {
		Name = "Popups",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 500,
		Parent = Gui,
	})

	return Gui
end

--//////////////////////////////////////////////////////////////////////////
--// Blur                                                                 //
--//////////////////////////////////////////////////////////////////////////

function Library:SetBlur(Enabled, Size)
	if not Library.UseBlur or not Lighting then
		return
	end

	if not Library.BlurEffect or not Library.BlurEffect.Parent then
		local Ok = pcall(function()
			Library.BlurEffect = New("BlurEffect", {
				Name = RandomString(8),
				Size = 0,
				Enabled = true,
				Parent = Lighting,
			})
		end)
		if not Ok then
			return
		end
	end

	Library:Tween(Library.BlurEffect, { Size = Enabled and (Size or 14) or 0 }, 0.35, "Smooth")
end

--//////////////////////////////////////////////////////////////////////////
--// Dragging                                                             //
--//////////////////////////////////////////////////////////////////////////

function Library:MakeDraggable(Frame, Handle, OnDragEnd)
	Handle = Handle or Frame

	local Dragging = false
	local DragStart, StartPosition

	Library:Connect(Handle.InputBegan, function(Input)
		if Library.CantDragForced then
			return
		end
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			Dragging = true
			DragStart = Input.Position
			StartPosition = Frame.Position
			Library:Tween(Frame, { Rotation = 0 }, 0.1, "Soft")
		end
	end)

	Library:Connect(Handle.InputEnded, function(Input)
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			if Dragging then
				Dragging = false
				if OnDragEnd then
					Library:SafeCallback(OnDragEnd, Frame.Position)
				end
			end
		end
	end)

	Library:Connect(UserInputService.InputChanged, function(Input)
		if not Dragging then
			return
		end
		if
			Input.UserInputType ~= Enum.UserInputType.MouseMovement
			and Input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local Delta = Input.Position - DragStart
		Frame.Position = UDim2.new(
			StartPosition.X.Scale,
			StartPosition.X.Offset + Delta.X,
			StartPosition.Y.Scale,
			StartPosition.Y.Offset + Delta.Y
		)
	end)
end

--//////////////////////////////////////////////////////////////////////////
--// Custom cursor                                                        //
--//////////////////////////////////////////////////////////////////////////

function Library:CreateCursor()
	if Library.Cursor then
		return Library.Cursor
	end

	local Gui = Library:GetScreenGui()

	local Cursor = New("ImageLabel", {
		Name = "Cursor",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png",
		ImageColor3 = Library.Scheme.AccentColor,
		Size = UDim2.fromOffset(20, 20),
		Visible = false,
		ZIndex = 10000,
		Parent = Gui,
	})
	Library:AddToRegistry(Cursor, { ImageColor3 = "AccentColor" })

	local Trail = New("Frame", {
		Name = "CursorGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Library.Scheme.AccentColor,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.2, 0.2),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 9999,
		Visible = false,
		Parent = Gui,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Trail })
	Library:AddToRegistry(Trail, { BackgroundColor3 = "AccentColor" })

	Library.Cursor = Cursor
	Library.CursorTrail = Trail

	Library:Connect(RunService.RenderStepped, function()
		if Library.Unloaded then
			return
		end

		local Show = Library.Toggled and Library.ShowCustomCursor and not Library.IsMobile
		Cursor.Visible = Show
		Trail.Visible = Show

		if not Show then
			return
		end

		local Location = Library:GetMouse()
		Cursor.Position = UDim2.fromOffset(Location.X, Location.Y)

		-- trail eases toward the cursor for a soft comet effect
		local Current = Trail.Position
		Trail.Position = UDim2.fromOffset(
			Lerp(Current.X.Offset, Location.X, 0.25),
			Lerp(Current.Y.Offset, Location.Y, 0.25)
		)
	end)

	return Cursor
end

--//////////////////////////////////////////////////////////////////////////
--// Notifications                                                        //
--//////////////////////////////////////////////////////////////////////////

local NotifyColors = {
	Normal = function()
		return Library.Scheme.AccentColor
	end,
	Success = function()
		return Library.Scheme.Green
	end,
	Error = function()
		return Library.Scheme.Red
	end,
	Warning = function()
		return Color3.fromRGB(255, 190, 70)
	end,
}

function Library:SetNotifySide(Side)
	if Side ~= "Left" and Side ~= "Right" then
		Side = "Right"
	end
	Library.NotifySide = Side
	if Library.NotificationArea then
		Library.NotificationArea.AnchorPoint = Vector2.new(Side == "Right" and 1 or 0, 0)
		Library.NotificationArea.Position = UDim2.new(Side == "Right" and 1 or 0, Side == "Right" and -16 or 16, 0, 16)
		Library.NotificationArea.ListLayout.HorizontalAlignment = Side == "Right" and Enum.HorizontalAlignment.Right
			or Enum.HorizontalAlignment.Left
	end
end

function Library:CreateNotificationArea()
	if Library.NotificationArea then
		return Library.NotificationArea
	end

	local Gui = Library:GetScreenGui()

	local Area = New("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 900,
		Parent = Gui,
	})

	local Layout = ListLayout(Area, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right)
	Area.ListLayout = Layout

	local Scale = New("UIScale", { Scale = Library.DPIScale, Parent = Area })
	table.insert(Library.ScaleObjects, Scale)

	Library.NotificationArea = Area
	Library:SetNotifySide(Library.NotifySide)
	return Area
end

--[[
    Library:Notify("Hello")                       -- 5 second default
    Library:Notify("Hello", 3)
    Library:Notify({ Title = "Saved", Description = "config.json", Time = 4,
                     Type = "Success", SoundId = "rbxassetid://4590662766" })
]]
function Library:Notify(Options, Duration, SoundId)
	if Library.Unloaded then
		return
	end

	local Config = Options
	if type(Options) ~= "table" then
		Config = { Description = tostring(Options), Time = Duration, SoundId = SoundId }
	end

	local Title = Config.Title
	local Description = Config.Description or Config.Text or ""
	local Time = Config.Time or Config.Duration or 5
	local Kind = Config.Type or "Normal"
	local AccentFor = NotifyColors[Kind] or NotifyColors.Normal

	local Area = Library:CreateNotificationArea()
	local FromRight = Library.NotifySide == "Right"

	local Holder = New("Frame", {
		Name = "Notification",
		BackgroundColor3 = Library.Scheme.MainColor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		ZIndex = 901,
		Parent = Area,
	})
	Corner(Holder, Library.CornerRadius)
	Library:AddToRegistry(Holder, { BackgroundColor3 = "MainColor" }, true)

	local Outline = Stroke(Holder, Library.Scheme.OutlineColor, 1, 0.2)
	Library:AddToRegistry(Outline, { Color = "OutlineColor" }, true)

	local AccentBar = New("Frame", {
		Name = "Accent",
		BackgroundColor3 = AccentFor(),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, 0),
		ZIndex = 903,
		Parent = Holder,
	})
	Corner(AccentBar, 2)

	local Body = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 903,
		Parent = Holder,
	})
	Padding(Body, 10, 12, 0, 0)
	ListLayout(Body, 3)

	if Title and Title ~= "" then
		local TitleLabel = New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = tostring(Title),
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 904,
			Parent = Body,
		})
		Library:AddToRegistry(TitleLabel, { TextColor3 = "FontColor" }, true)
		Library:Tween(TitleLabel, { TextTransparency = 0 }, 0.3, "Smooth")
	end

	local DescriptionLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Font = Library.Scheme.Font,
		Text = tostring(Description),
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 13,
		TextTransparency = 1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 904,
		Parent = Body,
	})
	Library:AddToRegistry(DescriptionLabel, { TextColor3 = "FontColor", Font = "Font" }, true)

	local Progress = New("Frame", {
		Name = "Progress",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = AccentFor(),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 905,
		Parent = Holder,
	})

	-- entrance
	Holder.Position = UDim2.fromOffset(FromRight and 340 or -340, 0)
	Library:Tween(Holder, { BackgroundTransparency = 0.05, Position = UDim2.fromOffset(0, 0) }, 0.45, "Snappy")
	Library:Tween(DescriptionLabel, { TextTransparency = 0 }, 0.35, "Smooth")

	if Config.SoundId then
		pcall(function()
			local Sound = Instance.new("Sound")
			Sound.SoundId = tostring(Config.SoundId)
			Sound.Volume = Config.Volume or 1
			Sound.Parent = Library.ScreenGui
			Sound:Play()
			Sound.Ended:Connect(function()
				Sound:Destroy()
			end)
		end)
	end

	local Notification = {}
	Notification.Holder = Holder
	Notification.Destroyed = false

	function Notification:Destroy()
		if Notification.Destroyed then
			return
		end
		Notification.Destroyed = true
		Library:Tween(Holder, {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(FromRight and 340 or -340, 0),
		}, 0.35, "Smooth")
		Library:Tween(DescriptionLabel, { TextTransparency = 1 }, 0.2, "Smooth")
		Library:Delay(0.4 * (Library.AnimationSpeed or 1), function()
			if Holder and Holder.Parent then
				Holder:Destroy()
			end
		end)
		local Index = TableFind(Library.Notifications, Notification)
		if Index then
			table.remove(Library.Notifications, Index)
		end
	end

	function Notification:ChangeTitle(NewTitle)
		if Body:FindFirstChildOfClass("TextLabel") then
			Body:FindFirstChildOfClass("TextLabel").Text = tostring(NewTitle)
		end
	end

	function Notification:ChangeDescription(NewText)
		DescriptionLabel.Text = tostring(NewText)
	end

	table.insert(Library.Notifications, Notification)

	if Time and Time > 0 then
		Library:Tween(Progress, { Size = UDim2.new(0, 0, 0, 2) }, Time, "Linear")
		Library:Delay(Time, function()
			Notification:Destroy()
		end)
	else
		Progress.Visible = false
	end

	return Notification
end

--//////////////////////////////////////////////////////////////////////////
--// Watermark                                                            //
--//////////////////////////////////////////////////////////////////////////

function Library:CreateWatermark()
	if Library.Watermark then
		return Library.Watermark
	end

	local Gui = Library:GetScreenGui()

	local Watermark = New("Frame", {
		Name = "Watermark",
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(200, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		ZIndex = 800,
		Parent = Gui,
	})
	Corner(Watermark, Library.CornerRadius)
	Library:AddToRegistry(Watermark, { BackgroundColor3 = "MainColor" }, true)

	local WatermarkStroke = Stroke(Watermark, Library.Scheme.AccentColor, 1, 0.25)
	Library:AddToRegistry(WatermarkStroke, { Color = "AccentColor" }, true)

	local Scale = New("UIScale", { Scale = Library.DPIScale, Parent = Watermark })
	table.insert(Library.ScaleObjects, Scale)

	local AccentLine = New("Frame", {
		BackgroundColor3 = Library.Scheme.AccentColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 802,
		Parent = Watermark,
	})
	Corner(AccentLine, 2)
	local LineGradient = New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Library.Scheme.AccentColor),
			ColorSequenceKeypoint.new(0.5, Library:GetLighterColor(Library.Scheme.AccentColor)),
			ColorSequenceKeypoint.new(1, Library.Scheme.AccentColor),
		}),
		Parent = AccentLine,
	})
	Library:AddToRegistry(LineGradient, {
		Color = function(Scheme)
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, Scheme.AccentColor),
				ColorSequenceKeypoint.new(0.5, Library:GetLighterColor(Scheme.AccentColor)),
				ColorSequenceKeypoint.new(1, Scheme.AccentColor),
			})
		end,
	}, true)
	Library:AnimateGradient(LineGradient, 4)

	local Label = New("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "OzionUI",
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 13,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 803,
		Parent = Watermark,
	})
	Padding(Label, 0, 0, 12, 12)
	Library:AddToRegistry(Label, { TextColor3 = "FontColor" }, true)

	Library:MakeDraggable(Watermark, Watermark)

	Library.Watermark = Watermark
	Library.WatermarkLabel = Label
	return Watermark
end

function Library:SetWatermark(Text)
	local Watermark = Library:CreateWatermark()
	Library.WatermarkLabel.Text = tostring(Text)
	Watermark.Size = UDim2.fromOffset(0, 28) -- AutomaticSize.X grows it to fit
	return Watermark
end

function Library:SetWatermarkVisibility(Visible)
	local Watermark = Library:CreateWatermark()
	if Visible then
		Watermark.Visible = true
		Watermark.BackgroundTransparency = 1
		Library:Tween(Watermark, { BackgroundTransparency = 0 }, 0.3, "Smooth")
	else
		Watermark.Visible = false
	end
end

--//////////////////////////////////////////////////////////////////////////
--// Tooltips                                                             //
--//////////////////////////////////////////////////////////////////////////

function Library:CreateTooltipHolder()
	if Library.TooltipHolder then
		return Library.TooltipHolder
	end

	local Gui = Library:GetScreenGui()

	local Holder = New("Frame", {
		Name = "Tooltip",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		ZIndex = 5000,
		Parent = Gui,
	})
	Corner(Holder, 4)
	Padding(Holder, 5, 5, 8, 8)
	Library:AddToRegistry(Holder, { BackgroundColor3 = "BackgroundColor" })
	local TooltipStroke = Stroke(Holder, Library.Scheme.AccentColor, 1, 0.4)
	Library:AddToRegistry(TooltipStroke, { Color = "AccentColor" })

	local Label = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Font = Library.Scheme.Font,
		Text = "",
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 12,
		ZIndex = 5001,
		Parent = Holder,
	})
	Library:AddToRegistry(Label, { TextColor3 = "FontColor", Font = "Font" })

	Library.TooltipHolder = Holder
	Library.TooltipLabel = Label

	Library:Connect(RunService.RenderStepped, function()
		if not Holder.Visible then
			return
		end
		local Location = Library:GetMouse()
		Holder.Position = UDim2.fromOffset(Location.X + 16, Location.Y + 14)
	end)

	return Holder
end

function Library:AddTooltip(Text, DisabledText, Object)
	if (not Text or Text == "") and (not DisabledText or DisabledText == "") then
		return
	end

	local Holder = Library:CreateTooltipHolder()
	local Hovered = false

	Library:Connect(Object.MouseEnter, function()
		if Library.IsMobile then
			return
		end
		Hovered = true
		local Disabled = Object:GetAttribute("Disabled")
		local Display = (Disabled and DisabledText) or Text
		if not Display or Display == "" then
			return
		end
		Library.TooltipLabel.Text = tostring(Display)
		Holder.Visible = true
		Holder.BackgroundTransparency = 1
		Library.TooltipLabel.TextTransparency = 1
		Library:Tween(Holder, { BackgroundTransparency = 0 }, 0.18, "Smooth")
		Library:Tween(Library.TooltipLabel, { TextTransparency = 0 }, 0.18, "Smooth")
	end)

	Library:Connect(Object.MouseLeave, function()
		Hovered = false
		Holder.Visible = false
	end)

	Library:Connect(Object.Destroying, function()
		if Hovered then
			Holder.Visible = false
		end
	end)
end

--//////////////////////////////////////////////////////////////////////////
--// Input helpers                                                        //
--//////////////////////////////////////////////////////////////////////////

-- Mouse position in ScreenGui space (our ScreenGui ignores the topbar inset,
-- GetMouseLocation does not, so the inset has to be added back).
function Library:GetMouse()
	local Location = UserInputService:GetMouseLocation()
	local InsetX, InsetY = 0, 0
	pcall(function()
		local Inset = GuiService:GetGuiInset()
		InsetX, InsetY = Inset.X, Inset.Y
	end)
	return Vector2.new(Location.X + InsetX, Location.Y + InsetY)
end

local MouseButtonNames = {
	[Enum.UserInputType.MouseButton1] = "MB1",
	[Enum.UserInputType.MouseButton2] = "MB2",
	[Enum.UserInputType.MouseButton3] = "MB3",
}

local function InputToKeyName(Input)
	if MouseButtonNames[Input.UserInputType] then
		return MouseButtonNames[Input.UserInputType]
	end
	if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode ~= Enum.KeyCode.Unknown then
		return Input.KeyCode.Name
	end
	return nil
end

local function KeyNameMatches(Input, KeyName)
	if not KeyName then
		return false
	end
	return InputToKeyName(Input) == KeyName
end

local function IsTyping()
	local Ok, Focused = pcall(function()
		return UserInputService:GetFocusedTextBox()
	end)
	return Ok and Focused ~= nil
end

-- Click / drag helper used by sliders and the colour picker.
local function BindDrag(Frame, OnUpdate)
	local Dragging = false

	local function Update()
		local Mouse = Library:GetMouse()
		local Position = Frame.AbsolutePosition
		local Size = Frame.AbsoluteSize
		local X = Clamp((Mouse.X - Position.X) / math.max(Size.X, 1), 0, 1)
		local Y = Clamp((Mouse.Y - Position.Y) / math.max(Size.Y, 1), 0, 1)
		OnUpdate(X, Y, Dragging)
	end

	Library:Connect(Frame.InputBegan, function(Input)
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			Dragging = true
			Update()
		end
	end)

	Library:Connect(UserInputService.InputEnded, function(Input)
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			Dragging = false
		end
	end)

	Library:Connect(RunService.RenderStepped, function()
		if Dragging and not Library.Unloaded then
			Update()
		end
	end)

	return function()
		return Dragging
	end
end

--//////////////////////////////////////////////////////////////////////////
--// Icons                                                                //
--//////////////////////////////////////////////////////////////////////////

--[[
    Icons can be:
      * a number            -> rbxassetid://<number>
      * "rbxassetid://123"  -> used as-is
      * a name below        -> drawn as a unicode glyph (no network needed)
      * anything else       -> first letter, uppercased

    Add your own with:  Library.Icons["skull"] = "rbxassetid://123456"
]]
Library.Icons = {
	home = "⌂",
	house = "⌂",
	settings = "⚙",
	gear = "⚙",
	user = "●",
	users = "●",
	player = "●",
	shield = "⛨",
	sword = "⚔",
	crosshair = "⌖",
	target = "⌖",
	eye = "◉",
	visuals = "◉",
	zap = "⚡",
	bolt = "⚡",
	flame = "♨",
	star = "★",
	heart = "♥",
	info = "ℹ",
	key = "⚿",
	lock = "🔒",
	palette = "◐",
	paint = "◐",
	save = "💾",
	folder = "📁",
	list = "≡",
	menu = "≡",
	map = "▦",
	globe = "🌐",
	clock = "🕑",
	bell = "🔔",
	search = "🔍",
	trash = "🗑",
	check = "✓",
	cross = "✕",
	plus = "+",
	minus = "−",
	arrow = "➤",
	chevron = "›",
	code = "<",
	terminal = "▸",
	bug = "☠",
	skull = "☠",
	car = "🚗",
	rocket = "🚀",
	wrench = "🔧",
	misc = "❖",
	box = "▣",
	grid = "▦",
	fish = "🐟",
	coin = "◎",
	money = "◎",
	farm = "🌾",
	bag = "🎒",
	gamepad = "🎮",
	music = "♫",
	moon = "☽",
	sun = "☀",
	cloud = "☁",
	droplet = "💧",
	snowflake = "❄",
	anchor = "⚓",
	flag = "⚑",
	bookmark = "🔖",
	book = "📖",
	camera = "📷",
	monitor = "🖵",
	cpu = "▩",
	database = "◬",
	link = "🔗",
	refresh = "↻",
	power = "⏻",
	play = "▶",
	pause = "⏸",
	stop = "■",
}

--[[
    Returns Image, Glyph. Exactly one of them is non nil.
]]
function Library:GetIcon(Icon)
	if Icon == nil or Icon == "" then
		return nil, nil
	end

	if type(Icon) == "number" then
		return "rbxassetid://" .. tostring(Icon), nil
	end

	if type(Icon) == "string" then
		if Icon:match("^rbxassetid://") or Icon:match("^rbxasset://") or Icon:match("^http") then
			return Icon, nil
		end
		local Mapped = Library.Icons[Icon:lower()]
		if Mapped then
			if Mapped:match("^rbxassetid://") or Mapped:match("^rbxasset://") then
				return Mapped, nil
			end
			return nil, Mapped
		end
		return nil, Icon:sub(1, 1):upper()
	end

	return nil, nil
end

--//////////////////////////////////////////////////////////////////////////
--// Keybind list                                                         //
--//////////////////////////////////////////////////////////////////////////

function Library:CreateKeybindList()
	if Library.KeybindFrame then
		return Library.KeybindFrame
	end

	local Gui = Library:GetScreenGui()

	local Frame = New("Frame", {
		Name = "Keybinds",
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.fromOffset(190, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 800,
		Parent = Gui,
	})
	Corner(Frame, Library.CornerRadius)
	Library:AddToRegistry(Frame, { BackgroundColor3 = "MainColor" }, true)
	local FrameStroke = Stroke(Frame, Library.Scheme.OutlineColor, 1, 0.2)
	Library:AddToRegistry(FrameStroke, { Color = "OutlineColor" }, true)

	local Scale = New("UIScale", { Scale = Library.DPIScale, Parent = Frame })
	table.insert(Library.ScaleObjects, Scale)

	local Title = New("TextLabel", {
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Keybinds",
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 802,
		Parent = Frame,
	})
	Corner(Title, Library.CornerRadius)
	Library:AddToRegistry(Title, { BackgroundColor3 = "BackgroundColor", TextColor3 = "FontColor" }, true)

	local Content = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 802,
		Parent = Frame,
	})
	Padding(Content, 6, 8, 10, 10)
	ListLayout(Content, 4)

	Library:MakeDraggable(Frame, Title)

	Library.KeybindFrame = Frame
	Library.KeybindContainer = Content
	return Frame
end

function Library:SetKeybindVisibility(Visible)
	local Frame = Library:CreateKeybindList()
	Frame.Visible = Visible and true or false
	if Visible then
		Frame.BackgroundTransparency = 1
		Library:Tween(Frame, { BackgroundTransparency = 0 }, 0.3, "Smooth")
	end
end

--//////////////////////////////////////////////////////////////////////////
--// Shared element behaviour                                             //
--//////////////////////////////////////////////////////////////////////////

local BaseElement = {}
BaseElement.__index = BaseElement

function BaseElement:SetVisible(Visible)
	self.Visible = Visible and true or false
	if self.Holder then
		self.Holder.Visible = self.Visible
	end
	return self
end

function BaseElement:SetDisabled(Disabled)
	self.Disabled = Disabled and true or false
	if self.Holder then
		self.Holder:SetAttribute("Disabled", self.Disabled)
	end
	if self.OnDisabledChanged then
		self:OnDisabledChanged(self.Disabled)
	end
	if self.TextLabel then
		Library:Tween(self.TextLabel, { TextTransparency = self.Disabled and 0.6 or 0 }, 0.15, "Smooth")
	end
	return self
end

function BaseElement:OnChanged(Callback)
	table.insert(self.Changed, Callback)
	if self.Value ~= nil then
		Library:SafeCallback(Callback, self.Value)
	end
	return self
end

function BaseElement:Fire(...)
	for _, Callback in pairs(self.Changed) do
		Library:SafeCallback(Callback, ...)
	end
	Library:SafeCallback(self.Callback, ...)
end

function BaseElement:Destroy()
	if self.Holder then
		self.Holder:Destroy()
	end
	if self.Index then
		Toggles[self.Index] = nil
		Options[self.Index] = nil
	end
end

local function NewElement(Element)
	Element.Changed = Element.Changed or {}
	return setmetatable(Element, BaseElement)
end

-- The standard element row: label on the left, pickers pinned to the right.
local function CreateRow(Container, Height, Order)
	local Row = New("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Height or 22),
		LayoutOrder = Order or 0,
		Parent = Container,
	})

	local Pickers = New("Frame", {
		Name = "Pickers",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 4,
		Parent = Row,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, 5),
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = Pickers,
	})

	return Row, Pickers
end

--//////////////////////////////////////////////////////////////////////////
--// Colour picker                                                        //
--//////////////////////////////////////////////////////////////////////////

function BaseElement:AddColorPicker(Index, Info)
	Info = Info or {}

	local Parent = self.Pickers or self.Holder
	local Default = Info.Default or Color3.new(1, 1, 1)

	local ColorPicker = NewElement({
		Index = Index,
		Type = "ColorPicker",
		Title = Info.Title or Info.Text or "Color",
		Value = Default,
		Transparency = Info.Transparency,
		Callback = Info.Callback,
		Changed = {},
		Open = false,
	})

	local Hue, Saturation, Value = Default:ToHSV()
	local Alpha = Info.Transparency or 0

	local Button = New("TextButton", {
		Name = "ColorPicker",
		AutoButtonColor = false,
		BackgroundColor3 = Default,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(32, 16),
		Text = "",
		ZIndex = 5,
		Parent = Parent,
	})
	Corner(Button, 4)
	local ButtonStroke = Stroke(Button, Library.Scheme.OutlineColor, 1, 0)
	Library:AddToRegistry(ButtonStroke, { Color = "OutlineColor" })

	ColorPicker.Holder = Button
	ColorPicker.Display = Button

	---------------------------------------------------------------- popup --
	local Popup = New("Frame", {
		Name = "ColorPickerPopup",
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(200, 0),
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 600,
		Parent = Library.PopupLayer,
	})
	Corner(Popup, Library.CornerRadius)
	Library:AddToRegistry(Popup, { BackgroundColor3 = "MainColor" })
	local PopupStroke = Stroke(Popup, Library.Scheme.AccentColor, 1, 0.3)
	Library:AddToRegistry(PopupStroke, { Color = "AccentColor" })

	local PopupBody = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 601,
		Parent = Popup,
	})
	Padding(PopupBody, 10, 10, 10, 10)
	ListLayout(PopupBody, 8)

	local TitleLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = ColorPicker.Title,
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 602,
		Parent = PopupBody,
	})
	Library:AddToRegistry(TitleLabel, { TextColor3 = "FontColor" })

	local PickRow = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 140),
		ZIndex = 602,
		Parent = PopupBody,
	})

	local SatVal = New("Frame", {
		Name = "SatVal",
		BackgroundColor3 = Color3.fromHSV(Hue, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -26, 1, 0),
		ZIndex = 603,
		Parent = PickRow,
	})
	Corner(SatVal, 4)
	New("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = New("Frame", {
			Name = "WhiteOverlay",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 604,
			Parent = SatVal,
		}),
	})
	local BlackOverlay = New("Frame", {
		Name = "BlackOverlay",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 605,
		Parent = SatVal,
	})
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = BlackOverlay,
	})

	local Cursor = New("Frame", {
		Name = "Cursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(Saturation, 1 - Value),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 607,
		Parent = SatVal,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Cursor })
	Stroke(Cursor, Color3.new(0, 0, 0), 2, 0.4)

	local HueBar = New("Frame", {
		Name = "Hue",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 18, 1, 0),
		ZIndex = 603,
		Parent = PickRow,
	})
	Corner(HueBar, 4)
	New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = HueBar,
	})

	local HueCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, Hue),
		Size = UDim2.new(1, 4, 0, 4),
		ZIndex = 606,
		Parent = HueBar,
	})
	Corner(HueCursor, 2)

	local AlphaBar, AlphaCursor
	if Info.Transparency ~= nil then
		AlphaBar = New("Frame", {
			Name = "Alpha",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 14),
			ZIndex = 602,
			Parent = PopupBody,
		})
		Corner(AlphaBar, 4)
		local AlphaGradient = New("UIGradient", {
			Color = ColorSequence.new(Color3.new(0, 0, 0), Default),
			Parent = AlphaBar,
		})
		ColorPicker.AlphaGradient = AlphaGradient

		AlphaCursor = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(1 - Alpha, 0.5),
			Size = UDim2.new(0, 4, 1, 4),
			ZIndex = 603,
			Parent = AlphaBar,
		})
		Corner(AlphaCursor, 2)
	end

	local HexRow = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 602,
		Parent = PopupBody,
	})

	local HexBox = New("TextBox", {
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Code,
		PlaceholderText = "#FFFFFF",
		Text = Library:ColorToHex(Default),
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 12,
		Size = UDim2.new(1, -60, 1, 0),
		ZIndex = 603,
		Parent = HexRow,
	})
	Corner(HexBox, 4)
	Library:AddToRegistry(HexBox, { BackgroundColor3 = "BackgroundColor", TextColor3 = "FontColor" })

	local CopyButton = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.AccentColor,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(54, 24),
		Text = "Copy",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 12,
		ZIndex = 603,
		Parent = HexRow,
	})
	Corner(CopyButton, 4)
	Library:AddToRegistry(CopyButton, { BackgroundColor3 = "AccentColor" })

	------------------------------------------------------------- updating --
	local function Apply(FireCallbacks)
		local Color = Color3.fromHSV(Hue, Saturation, Value)
		ColorPicker.Value = Color
		ColorPicker.Transparency = Info.Transparency and Alpha or nil

		Button.BackgroundColor3 = Color
		SatVal.BackgroundColor3 = Color3.fromHSV(Hue, 1, 1)
		Cursor.Position = UDim2.fromScale(Saturation, 1 - Value)
		HueCursor.Position = UDim2.fromScale(0.5, Hue)
		HexBox.Text = Library:ColorToHex(Color)

		if AlphaBar then
			ColorPicker.AlphaGradient.Color = ColorSequence.new(Color3.new(0, 0, 0), Color)
			AlphaCursor.Position = UDim2.fromScale(1 - Alpha, 0.5)
		end

		if FireCallbacks ~= false then
			ColorPicker:Fire(Color, Info.Transparency and Alpha or nil)
		end
	end

	BindDrag(SatVal, function(X, Y)
		Saturation = X
		Value = 1 - Y
		Apply()
	end)

	BindDrag(HueBar, function(_, Y)
		Hue = Clamp(Y, 0, 0.9999)
		Apply()
	end)

	if AlphaBar then
		BindDrag(AlphaBar, function(X)
			Alpha = 1 - X
			Apply()
		end)
	end

	Library:Connect(HexBox.FocusLost, function()
		local Parsed = Library:HexToColor(HexBox.Text)
		if Parsed then
			Hue, Saturation, Value = Parsed:ToHSV()
			Apply()
		else
			HexBox.Text = Library:ColorToHex(ColorPicker.Value)
		end
	end)

	Library:Connect(CopyButton.MouseButton1Click, function()
		if Env.SetClipboard then
			pcall(Env.SetClipboard, Library:ColorToHex(ColorPicker.Value))
			Library:Notify({ Title = "Copied", Description = Library:ColorToHex(ColorPicker.Value), Time = 2 })
		else
			Library:Notify({ Title = "Unsupported", Description = "No clipboard function found.", Time = 3 })
		end
	end)

	---------------------------------------------------------------- open --
	function ColorPicker:Toggle(State)
		if State == nil then
			State = not ColorPicker.Open
		end
		ColorPicker.Open = State

		if State then
			for _, Other in pairs(Library.OpenedFrames) do
				if Other ~= ColorPicker and Other.Toggle then
					Other:Toggle(false)
				end
			end
			if not TableFind(Library.OpenedFrames, ColorPicker) then
				table.insert(Library.OpenedFrames, ColorPicker)
			end

			local AbsolutePosition = Button.AbsolutePosition
			local AbsoluteSize = Button.AbsoluteSize
			Popup.Position = UDim2.fromOffset(AbsolutePosition.X - 168, AbsolutePosition.Y + AbsoluteSize.Y + 6)
			Popup.Visible = true
			Popup.Size = UDim2.fromOffset(200, 0)
			Library:Tween(Popup, { Size = UDim2.fromOffset(200, Info.Transparency ~= nil and 236 or 214) }, 0.3, "Snappy")
		else
			local Index2 = TableFind(Library.OpenedFrames, ColorPicker)
			if Index2 then
				table.remove(Library.OpenedFrames, Index2)
			end
			Library:Tween(Popup, { Size = UDim2.fromOffset(200, 0) }, 0.22, "Smooth")
			Library:Delay(0.25 * (Library.AnimationSpeed or 1), function()
				if not ColorPicker.Open then
					Popup.Visible = false
				end
			end)
		end
	end

	Library:Connect(Button.MouseButton1Click, function()
		ColorPicker:Toggle()
	end)

	Library:Connect(Button.MouseEnter, function()
		Library:Tween(ButtonStroke, { Color = Library.Scheme.AccentColor }, 0.15, "Smooth")
	end)
	Library:Connect(Button.MouseLeave, function()
		Library:Tween(ButtonStroke, { Color = Library.Scheme.OutlineColor }, 0.15, "Smooth")
	end)

	function ColorPicker:SetValue(NewValue, NewAlpha)
		-- accept Color3, {r, g, b} (0-255, as stored in configs) or a hex string
		if type(NewValue) == "string" then
			NewValue = Library:HexToColor(NewValue) or ColorPicker.Value
		elseif typeof(NewValue) ~= "Color3" and type(NewValue) == "table" then
			if NewValue[1] ~= nil then
				NewValue = Color3.fromRGB(NewValue[1] or 0, NewValue[2] or 0, NewValue[3] or 0)
			else
				NewValue = ColorPicker.Value
			end
		end
		if typeof(NewValue) == "Color3" then
			Hue, Saturation, Value = NewValue:ToHSV()
		end
		if NewAlpha ~= nil then
			Alpha = Clamp(NewAlpha, 0, 1)
		end
		Apply()
		return ColorPicker
	end

	function ColorPicker:SetValueRGB(Color, NewAlpha)
		return ColorPicker:SetValue(Color, NewAlpha)
	end

	function ColorPicker:GetValue()
		return ColorPicker.Value
	end

	Apply(false)

	ColorPicker.Popup = Popup

	if Index ~= nil then
		Options[Index] = ColorPicker
	end
	if Info.Callback then
		Library:SafeCallback(Info.Callback, ColorPicker.Value, ColorPicker.Transparency)
	end

	if self.Row then
		self.ColorPicker = ColorPicker
	end
	return ColorPicker
end

--//////////////////////////////////////////////////////////////////////////
--// Key picker                                                           //
--//////////////////////////////////////////////////////////////////////////

local KeyModes = { "Always", "Toggle", "Hold" }

function BaseElement:AddKeyPicker(Index, Info)
	Info = Info or {}

	local ParentElement = self
	local Parent = self.Pickers or self.Holder

	local KeyPicker = NewElement({
		Index = Index,
		Type = "KeyPicker",
		Text = Info.Text or (self.Text or "Keybind"),
		Value = Info.Default or "None",
		Mode = Info.Mode or "Toggle",
		SyncToggleState = Info.SyncToggleState or false,
		NoUI = Info.NoUI or false,
		Callback = Info.Callback,
		Clicked = {},
		Changed = {},
		Active = false,
		Binding = false,
	})

	local Button = New("TextButton", {
		Name = "KeyPicker",
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromOffset(34, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "[ " .. tostring(KeyPicker.Value) .. " ]",
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 11,
		ZIndex = 5,
		Parent = Parent,
	})
	Corner(Button, 4)
	Padding(Button, 0, 0, 6, 6)
	Library:AddToRegistry(Button, { BackgroundColor3 = "BackgroundColor", TextColor3 = "FontColor" })
	local KeyStroke = Stroke(Button, Library.Scheme.OutlineColor, 1, 0)
	Library:AddToRegistry(KeyStroke, { Color = "OutlineColor" })

	KeyPicker.Holder = Button

	------------------------------------------------------------ mode menu --
	local ModeMenu = New("Frame", {
		Name = "KeyModes",
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(96, 0),
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 600,
		Parent = Library.PopupLayer,
	})
	Corner(ModeMenu, 4)
	Library:AddToRegistry(ModeMenu, { BackgroundColor3 = "MainColor" })
	local ModeStroke = Stroke(ModeMenu, Library.Scheme.AccentColor, 1, 0.3)
	Library:AddToRegistry(ModeStroke, { Color = "AccentColor" })
	ListLayout(ModeMenu, 0)

	local ModeButtons = {}
	for ModeIndex, Mode in pairs(KeyModes) do
		local ModeButton = New("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Library.Scheme.MainColor,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Library.Scheme.Font,
			LayoutOrder = ModeIndex,
			Size = UDim2.new(1, 0, 0, 24),
			Text = Mode,
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 12,
			ZIndex = 602,
			Parent = ModeMenu,
		})
		Library:AddToRegistry(ModeButton, { TextColor3 = "FontColor", Font = "Font" })
		ModeButtons[Mode] = ModeButton
	end

	local function CloseModeMenu()
		Library:Tween(ModeMenu, { Size = UDim2.fromOffset(96, 0) }, 0.18, "Smooth")
		Library:Delay(0.2 * (Library.AnimationSpeed or 1), function()
			ModeMenu.Visible = false
		end)
	end

	--------------------------------------------------------- keybind list --
	local ListEntry, ListLabel, ListState
	if not KeyPicker.NoUI then
		Library:CreateKeybindList()
		ListEntry = New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			Visible = false,
			ZIndex = 803,
			Parent = Library.KeybindContainer,
		})
		ListLabel = New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Library.Scheme.Font,
			Text = KeyPicker.Text,
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -40, 1, 0),
			ZIndex = 804,
			Parent = ListEntry,
		})
		Library:AddToRegistry(ListLabel, { TextColor3 = "FontColor", Font = "Font" }, true)

		ListState = New("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromScale(1, 0),
			Text = "[ " .. tostring(KeyPicker.Value) .. " ]",
			TextColor3 = Library.Scheme.AccentColor,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(60, 16),
			ZIndex = 804,
			Parent = ListEntry,
		})
		Library:AddToRegistry(ListState, { TextColor3 = "AccentColor" }, true)
	end

	local function UpdateDisplay()
		Button.Text = "[ " .. tostring(KeyPicker.Value) .. " ]"
		if ListEntry then
			ListLabel.Text = KeyPicker.Text
			ListState.Text = "[ " .. tostring(KeyPicker.Value) .. " ]"
			ListEntry.Visible = KeyPicker.Value ~= "None" and KeyPicker.Mode ~= "Always"
		end
		for Mode, ModeButton in pairs(ModeButtons) do
			local Selected = Mode == KeyPicker.Mode
			ModeButton.BackgroundTransparency = Selected and 0 or 1
			ModeButton.BackgroundColor3 = Library.Scheme.AccentColor
		end
	end

	function KeyPicker:GetState()
		if KeyPicker.Mode == "Always" then
			return true
		end
		return KeyPicker.Active
	end

	function KeyPicker:SetActive(State)
		if KeyPicker.Active == State then
			return
		end
		KeyPicker.Active = State
		if ListState then
			Library:Tween(ListState, {
				TextColor3 = State and Library.Scheme.Green or Library.Scheme.AccentColor,
			}, 0.15, "Smooth")
		end
		KeyPicker:Fire(KeyPicker:GetState())
		if
			KeyPicker.SyncToggleState
			and ParentElement
			and ParentElement.Type == "Toggle"
			and ParentElement.SetValue
		then
			ParentElement:SetValue(KeyPicker:GetState())
		end
	end

	function KeyPicker:DoClick()
		for _, Callback in pairs(KeyPicker.Clicked) do
			Library:SafeCallback(Callback)
		end
	end

	function KeyPicker:OnClick(Callback)
		table.insert(KeyPicker.Clicked, Callback)
		return KeyPicker
	end

	function KeyPicker:SetValue(Data)
		local Key, Mode = Data, KeyPicker.Mode
		if type(Data) == "table" then
			Key = Data[1] or Data.Key or "None"
			Mode = Data[2] or Data.Mode or KeyPicker.Mode
		end
		KeyPicker.Value = tostring(Key)
		KeyPicker.Mode = Mode
		UpdateDisplay()
		return KeyPicker
	end

	function KeyPicker:SetText(NewText)
		KeyPicker.Text = tostring(NewText)
		UpdateDisplay()
		return KeyPicker
	end

	-- binding
	Library:Connect(Button.MouseButton1Click, function()
		if KeyPicker.Binding then
			return
		end
		KeyPicker.Binding = true
		Button.Text = "[ ... ]"
		Library:Tween(KeyStroke, { Color = Library.Scheme.AccentColor }, 0.15, "Smooth")
	end)

	Library:Connect(Button.MouseButton2Click, function()
		if ModeMenu.Visible then
			CloseModeMenu()
			return
		end
		local AbsolutePosition = Button.AbsolutePosition
		local AbsoluteSize = Button.AbsoluteSize
		ModeMenu.Position = UDim2.fromOffset(AbsolutePosition.X, AbsolutePosition.Y + AbsoluteSize.Y + 4)
		ModeMenu.Visible = true
		ModeMenu.Size = UDim2.fromOffset(96, 0)
		Library:Tween(ModeMenu, { Size = UDim2.fromOffset(96, 72) }, 0.25, "Snappy")
	end)

	for Mode, ModeButton in pairs(ModeButtons) do
		Library:Connect(ModeButton.MouseButton1Click, function()
			KeyPicker.Mode = Mode
			KeyPicker.Active = false
			UpdateDisplay()
			CloseModeMenu()
			KeyPicker:Fire(KeyPicker:GetState())
		end)
		Library:Connect(ModeButton.MouseEnter, function()
			if KeyPicker.Mode ~= Mode then
				Library:Tween(ModeButton, { BackgroundTransparency = 0.8 }, 0.12, "Smooth")
			end
		end)
		Library:Connect(ModeButton.MouseLeave, function()
			if KeyPicker.Mode ~= Mode then
				Library:Tween(ModeButton, { BackgroundTransparency = 1 }, 0.12, "Smooth")
			end
		end)
	end

	Library:Connect(UserInputService.InputBegan, function(Input, Processed)
		if KeyPicker.Binding then
			local KeyName = InputToKeyName(Input)
			if Input.KeyCode == Enum.KeyCode.Escape then
				KeyName = "None"
			end
			if KeyName then
				KeyPicker.Binding = false
				KeyPicker.Value = KeyName
				UpdateDisplay()
				Library:Tween(KeyStroke, { Color = Library.Scheme.OutlineColor }, 0.15, "Smooth")
				Library:Pulse(Button)
				KeyPicker:Fire(KeyPicker:GetState())
			end
			return
		end

		if Processed and Input.UserInputType == Enum.UserInputType.Keyboard then
			return
		end
		if IsTyping() then
			return
		end
		if not KeyNameMatches(Input, KeyPicker.Value) then
			return
		end

		if KeyPicker.Mode == "Toggle" then
			KeyPicker:SetActive(not KeyPicker.Active)
		elseif KeyPicker.Mode == "Hold" then
			KeyPicker:SetActive(true)
		end
		KeyPicker:DoClick()
	end)

	Library:Connect(UserInputService.InputEnded, function(Input)
		if KeyPicker.Mode == "Hold" and KeyNameMatches(Input, KeyPicker.Value) then
			KeyPicker:SetActive(false)
		end
	end)

	UpdateDisplay()

	if Index ~= nil then
		Options[Index] = KeyPicker
	end

	if ParentElement.Type == "Toggle" then
		KeyPicker.ParentToggle = ParentElement
	end

	return KeyPicker
end

--//////////////////////////////////////////////////////////////////////////
--// Elements                                                             //
--//////////////////////////////////////////////////////////////////////////

local ElementFuncs = {}
ElementFuncs.__index = ElementFuncs

-- Registers an element so the tab search bar can filter it.
function ElementFuncs:Register(Element, SearchText)
	Element.SearchText = string.lower(tostring(SearchText or ""))
	table.insert(self.Elements, Element)
	if self.Groupbox and self.Groupbox ~= self then
		table.insert(self.Groupbox.Elements, Element)
	end
	return Element
end

--------------------------------------------------------------- Label -----

function ElementFuncs:AddLabel(Info, DoesWrap)
	if type(Info) ~= "table" then
		Info = { Text = tostring(Info), DoesWrap = DoesWrap }
	end

	local Wraps = Info.DoesWrap or Info.Wrap or false

	local Row, Pickers = CreateRow(self.Container, Wraps and 0 or 20)
	if Wraps then
		Row.AutomaticSize = Enum.AutomaticSize.Y
	end

	local TextLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Font = Library.Scheme.Font,
		Text = tostring(Info.Text or ""),
		TextColor3 = Info.Risky and Library.Scheme.Red or Library.Scheme.FontColor,
		TextSize = 13,
		TextWrapped = Wraps,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = Wraps and UDim2.new(1, -8, 0, 0) or UDim2.new(1, -8, 1, 0),
		AutomaticSize = Wraps and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		ZIndex = 3,
		Parent = Row,
	})
	Library:AddToRegistry(TextLabel, {
		TextColor3 = Info.Risky and "Red" or "FontColor",
		Font = "Font",
	})

	local Label = NewElement({
		Type = "Label",
		Holder = Row,
		Pickers = Pickers,
		TextLabel = TextLabel,
		Text = Info.Text,
		Row = Row,
	})

	function Label:SetText(NewText)
		TextLabel.Text = tostring(NewText)
		Label.Text = NewText
		Label.SearchText = string.lower(tostring(NewText))
		return Label
	end

	if Info.Tooltip then
		Library:AddTooltip(Info.Tooltip, Info.DisabledTooltip, Row)
	end
	if Info.Visible == false then
		Label:SetVisible(false)
	end

	-- entrance animation
	TextLabel.TextTransparency = 1
	Library:Tween(TextLabel, { TextTransparency = 0 }, 0.25, "Smooth")

	return self:Register(Label, Info.Text)
end

------------------------------------------------------------- Divider -----

function ElementFuncs:AddDivider(Text)
	local Row = New("Frame", {
		Name = "Divider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Text and 18 or 8),
		Parent = self.Container,
	})

	local Line = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Library.Scheme.OutlineColor,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 3,
		Parent = Row,
	})
	Library:AddToRegistry(Line, { BackgroundColor3 = "OutlineColor" })

	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = Line,
	})

	if Text then
		local Label = New("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Library.Scheme.MainColor,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 14),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = tostring(Text),
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 11,
			ZIndex = 4,
			Parent = Row,
		})
		Padding(Label, 0, 0, 6, 6)
		Library:AddToRegistry(Label, { BackgroundColor3 = "MainColor", TextColor3 = "FontColor" })
	end

	local Divider = NewElement({ Type = "Divider", Holder = Row })
	return self:Register(Divider, Text)
end

-------------------------------------------------------------- Button -----

function ElementFuncs:AddButton(Info, Func)
	if type(Info) ~= "table" then
		Info = { Text = tostring(Info), Func = Func }
	end

	local Row = New("Frame", {
		Name = "ButtonRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = self.Container,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, 6),
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = Row,
	})

	local Buttons = {}

	local function Rebalance()
		local Count = #Buttons
		for _, Entry in pairs(Buttons) do
			Entry.Button.Size = UDim2.new(1 / Count, -6 + 6 / Count, 1, 0)
		end
	end

	local function MakeButton(ButtonInfo)
		local Button = New("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Library.Scheme.BackgroundColor,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Font = Enum.Font.GothamBold,
			LayoutOrder = #Buttons + 1,
			Size = UDim2.new(1, 0, 1, 0),
			Text = tostring(ButtonInfo.Text or "Button"),
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 13,
			ZIndex = 3,
			Parent = Row,
		})
		Corner(Button, Library.CornerRadius - 1)
		Library:AddToRegistry(Button, { BackgroundColor3 = "BackgroundColor", TextColor3 = "FontColor" })

		local ButtonStroke = Stroke(Button, Library.Scheme.OutlineColor, 1, 0)
		Library:AddToRegistry(ButtonStroke, { Color = "OutlineColor" })

		local Highlight = New("Frame", {
			BackgroundColor3 = Library.Scheme.AccentColor,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = Button,
		})
		Corner(Highlight, Library.CornerRadius - 1)
		Library:AddToRegistry(Highlight, { BackgroundColor3 = "AccentColor" })

		local Entry = {
			Button = Button,
			Stroke = ButtonStroke,
			Highlight = Highlight,
			Info = ButtonInfo,
			Clicks = 0,
		}

		Library:Connect(Button.MouseEnter, function()
			if Button:GetAttribute("Disabled") then
				return
			end
			Library:Tween(Highlight, { BackgroundTransparency = 0.85 }, 0.15, "Smooth")
			Library:Tween(ButtonStroke, { Color = Library.Scheme.AccentColor }, 0.15, "Smooth")
		end)

		Library:Connect(Button.MouseLeave, function()
			Library:Tween(Highlight, { BackgroundTransparency = 1 }, 0.2, "Smooth")
			Library:Tween(ButtonStroke, { Color = Library.Scheme.OutlineColor }, 0.2, "Smooth")
			if ButtonInfo.DoubleClick then
				Entry.Clicks = 0
				Button.Text = tostring(ButtonInfo.Text or "Button")
			end
		end)

		Library:Connect(Button.MouseButton1Down, function()
			if Button:GetAttribute("Disabled") then
				return
			end
			local Mouse = Library:GetMouse()
			Library:Ripple(Button, Mouse.X, Mouse.Y)
			Library:Tween(Button, { Size = Button.Size - UDim2.fromOffset(0, 3) }, 0.1, "Soft")
		end)

		Library:Connect(Button.MouseButton1Up, function()
			Library:Tween(Button, { Size = Button.Size + UDim2.fromOffset(0, 3) }, 0.18, "Snappy")
		end)

		Library:Connect(Button.MouseButton1Click, function()
			if Button:GetAttribute("Disabled") then
				return
			end
			if ButtonInfo.DoubleClick then
				Entry.Clicks = Entry.Clicks + 1
				if Entry.Clicks < 2 then
					Button.Text = "Are you sure?"
					return
				end
				Entry.Clicks = 0
				Button.Text = tostring(ButtonInfo.Text or "Button")
			end
			Library:SafeCallback(ButtonInfo.Func or ButtonInfo.Callback)
		end)

		if ButtonInfo.Tooltip then
			Library:AddTooltip(ButtonInfo.Tooltip, ButtonInfo.DisabledTooltip, Button)
		end

		table.insert(Buttons, Entry)
		Rebalance()
		return Entry
	end

	local MainEntry = MakeButton(Info)

	local ButtonElement = NewElement({
		Type = "Button",
		Holder = Row,
		TextLabel = MainEntry.Button,
		Text = Info.Text,
	})

	function ButtonElement:AddButton(SubInfo, SubFunc)
		if type(SubInfo) ~= "table" then
			SubInfo = { Text = tostring(SubInfo), Func = SubFunc }
		end
		local Entry = MakeButton(SubInfo)
		local Sub = NewElement({ Type = "Button", Holder = Row, TextLabel = Entry.Button, Text = SubInfo.Text })
		function Sub:SetText(NewText)
			Entry.Info.Text = NewText
			Entry.Button.Text = tostring(NewText)
			return Sub
		end
		function Sub:SetDisabled(Disabled)
			Entry.Button:SetAttribute("Disabled", Disabled and true or false)
			Library:Tween(Entry.Button, { TextTransparency = Disabled and 0.6 or 0 }, 0.15, "Smooth")
			return Sub
		end
		return Sub
	end

	function ButtonElement:SetText(NewText)
		MainEntry.Info.Text = NewText
		MainEntry.Button.Text = tostring(NewText)
		ButtonElement.SearchText = string.lower(tostring(NewText))
		return ButtonElement
	end

	function ButtonElement:SetDisabled(Disabled)
		MainEntry.Button:SetAttribute("Disabled", Disabled and true or false)
		Library:Tween(MainEntry.Button, { TextTransparency = Disabled and 0.6 or 0 }, 0.15, "Smooth")
		return ButtonElement
	end

	if Info.Disabled then
		ButtonElement:SetDisabled(true)
	end
	if Info.Visible == false then
		ButtonElement:SetVisible(false)
	end

	return self:Register(ButtonElement, Info.Text)
end

-------------------------------------------------------------- Toggle -----

local function BuildToggle(self, Idx, Info, ForceCheckbox)
	Info = Info or {}

	local UseCheckbox = ForceCheckbox or Library.ForceCheckbox or Info.Checkbox
	local Row, Pickers = CreateRow(self.Container, 22)

	local Toggle = NewElement({
		Index = Idx,
		Type = "Toggle",
		Holder = Row,
		Pickers = Pickers,
		Row = Row,
		Value = Info.Default or false,
		Text = Info.Text or "Toggle",
		Callback = Info.Callback,
		Risky = Info.Risky,
		Disabled = Info.Disabled or false,
	})

	------------------------------------------------------------ visuals --
	local Control = New("TextButton", {
		Name = "Control",
		AnchorPoint = Vector2.new(0, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UseCheckbox and UDim2.fromOffset(18, 18) or UDim2.fromOffset(34, 18),
		Text = "",
		ZIndex = 3,
		Parent = Row,
	})
	Corner(Control, UseCheckbox and 4 or 9)
	Library:AddToRegistry(Control, { BackgroundColor3 = "BackgroundColor" })

	local ControlStroke = Stroke(Control, Library.Scheme.OutlineColor, 1, 0)
	Library:AddToRegistry(ControlStroke, { Color = "OutlineColor" })

	local Fill = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = Library.Scheme.AccentColor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = Control,
	})
	Corner(Fill, UseCheckbox and 4 or 9)
	Library:AddToRegistry(Fill, { BackgroundColor3 = "AccentColor" })
	New("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)),
		Rotation = 45,
		Parent = Fill,
	})

	local Knob, Check
	if UseCheckbox then
		Check = New("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0, 0),
			Text = "✓",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 6,
			Parent = Control,
		})
	else
		Knob = New("Frame", {
			Name = "Knob",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(235, 235, 245),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(12, 12),
			ZIndex = 6,
			Parent = Control,
		})
		New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Knob })
	end

	local TextLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Font = Library.Scheme.Font,
		Position = UDim2.fromOffset(UseCheckbox and 26 or 42, 0),
		Size = UDim2.new(1, UseCheckbox and -26 or -42, 1, 0),
		Text = tostring(Toggle.Text),
		TextColor3 = Info.Risky and Library.Scheme.Red or Library.Scheme.FontColor,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = Row,
	})
	Library:AddToRegistry(TextLabel, {
		TextColor3 = Info.Risky and "Red" or "FontColor",
		Font = "Font",
	})
	Toggle.TextLabel = TextLabel

	------------------------------------------------------------- logic --
	local function Render(Animate)
		local On = Toggle.Value
		local Duration = Animate == false and 0 or nil

		if Duration == 0 then
			Fill.BackgroundTransparency = On and 0 or 1
			if Knob then
				Knob.Position = UDim2.new(0, On and 19 or 3, 0.5, 0)
			end
			if Check then
				Check.Size = On and UDim2.fromScale(0.8, 0.8) or UDim2.fromScale(0, 0)
			end
			return
		end

		Library:Tween(Fill, { BackgroundTransparency = On and 0 or 1 }, 0.2, "Smooth")
		Library:Tween(ControlStroke, {
			Color = On and Library.Scheme.AccentColor or Library.Scheme.OutlineColor,
		}, 0.2, "Smooth")

		if Knob then
			Library:Tween(Knob, { Position = UDim2.new(0, On and 19 or 3, 0.5, 0) }, 0.3, "Snappy")
			Library:Tween(Knob, { Size = UDim2.fromOffset(On and 13 or 12, On and 13 or 12) }, 0.2, "Snappy")
		end
		if Check then
			Library:Tween(Check, {
				Size = On and UDim2.fromScale(0.8, 0.8) or UDim2.fromScale(0, 0),
			}, 0.28, "Snappy")
		end
		if On then
			Library:Pulse(Control)
		end
	end

	function Toggle:SetValue(Value, Silent)
		Value = Value and true or false
		if Toggle.Disabled then
			return Toggle
		end
		Toggle.Value = Value
		Render(true)
		if Silent ~= true then
			Toggle:Fire(Value)
		end
		Library:UpdateDependencyBoxes()
		return Toggle
	end

	function Toggle:SetText(NewText)
		Toggle.Text = NewText
		TextLabel.Text = tostring(NewText)
		Toggle.SearchText = string.lower(tostring(NewText))
		return Toggle
	end

	function Toggle:OnDisabledChanged(Disabled)
		Library:Tween(Control, { BackgroundTransparency = Disabled and 0.5 or 0 }, 0.15, "Smooth")
	end

	Library:Connect(Control.MouseButton1Click, function()
		if Toggle.Disabled then
			return
		end
		local Mouse = Library:GetMouse()
		Library:Ripple(Control, Mouse.X, Mouse.Y, Color3.new(1, 1, 1))
		Toggle:SetValue(not Toggle.Value)
	end)

	-- an invisible button behind everything so clicking the label works too
	local ClickArea = New("TextButton", {
		Name = "ClickArea",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 2,
		Parent = Row,
	})
	Library:Connect(ClickArea.MouseButton1Click, function()
		if Toggle.Disabled then
			return
		end
		Toggle:SetValue(not Toggle.Value)
	end)
	Library:Connect(ClickArea.MouseEnter, function()
		Library:Tween(TextLabel, { TextTransparency = 0.25 }, 0.12, "Smooth")
	end)
	Library:Connect(ClickArea.MouseLeave, function()
		Library:Tween(TextLabel, { TextTransparency = Toggle.Disabled and 0.6 or 0 }, 0.12, "Smooth")
	end)

	Library:Connect(Control.MouseEnter, function()
		if not Toggle.Value then
			Library:Tween(ControlStroke, { Color = Library.Scheme.AccentColor }, 0.15, "Smooth")
		end
	end)
	Library:Connect(Control.MouseLeave, function()
		if not Toggle.Value then
			Library:Tween(ControlStroke, { Color = Library.Scheme.OutlineColor }, 0.15, "Smooth")
		end
	end)

	if Info.Tooltip then
		Library:AddTooltip(Info.Tooltip, Info.DisabledTooltip, Row)
	end

	Render(false)
	if Idx ~= nil then
		Toggles[Idx] = Toggle
	end
	if Info.Disabled then
		Toggle:SetDisabled(true)
	end
	if Info.Visible == false then
		Toggle:SetVisible(false)
	end
	if Info.Default and Info.Callback then
		Library:SafeCallback(Info.Callback, true)
	end

	return self:Register(Toggle, Info.Text)
end

function ElementFuncs:AddToggle(Idx, Info)
	return BuildToggle(self, Idx, Info, false)
end

function ElementFuncs:AddCheckbox(Idx, Info)
	return BuildToggle(self, Idx, Info, true)
end

-------------------------------------------------------------- Slider -----

function ElementFuncs:AddSlider(Idx, Info)
	Info = Info or {}

	local Minimum = Info.Min or 0
	local Maximum = Info.Max or 100
	local Rounding = Info.Rounding or 0
	local Suffix = Info.Suffix or ""
	local Compact = Info.Compact or false

	local Row = New("Frame", {
		Name = "Slider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Compact and 26 or 36),
		Parent = self.Container,
	})

	local Pickers = New("Frame", {
		Name = "Pickers",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 5,
		Parent = Row,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, 5),
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = Pickers,
	})

	local Slider = NewElement({
		Index = Idx,
		Type = "Slider",
		Holder = Row,
		Pickers = Pickers,
		Row = Row,
		Value = Info.Default or Minimum,
		Min = Minimum,
		Max = Maximum,
		Rounding = Rounding,
		Suffix = Suffix,
		Text = Info.Text or "Slider",
		Callback = Info.Callback,
	})

	local TextLabel
	if not Compact then
		TextLabel = New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Library.Scheme.Font,
			Size = UDim2.new(1, -70, 0, 16),
			Text = tostring(Slider.Text),
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Parent = Row,
		})
		Library:AddToRegistry(TextLabel, { TextColor3 = "FontColor", Font = "Font" })
		Slider.TextLabel = TextLabel
	end

	local ValueLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(70, 16),
		Text = "0",
		TextColor3 = Library.Scheme.AccentColor,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = not Compact,
		ZIndex = 3,
		Parent = Row,
	})
	Library:AddToRegistry(ValueLabel, { TextColor3 = "AccentColor" })

	local Bar = New("TextButton", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, Compact and 0 or -4),
		Size = UDim2.new(1, 0, 0, Compact and 18 or 8),
		Text = "",
		ZIndex = 3,
		Parent = Row,
	})
	Corner(Bar, Compact and 5 or 4)
	Library:AddToRegistry(Bar, { BackgroundColor3 = "BackgroundColor" })
	local BarStroke = Stroke(Bar, Library.Scheme.OutlineColor, 1, 0)
	Library:AddToRegistry(BarStroke, { Color = "OutlineColor" })

	local FillBar = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = Library.Scheme.AccentColor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = Bar,
	})
	Corner(FillBar, Compact and 5 or 4)
	Library:AddToRegistry(FillBar, { BackgroundColor3 = "AccentColor" })

	local FillGradient = New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.Scheme.AccentColor)),
			ColorSequenceKeypoint.new(1, Library:GetLighterColor(Library.Scheme.AccentColor)),
		}),
		Parent = FillBar,
	})
	Library:AddToRegistry(FillGradient, {
		Color = function(Scheme)
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Scheme.AccentColor)),
				ColorSequenceKeypoint.new(1, Library:GetLighterColor(Scheme.AccentColor)),
			})
		end,
	})

	local CompactLabel
	if Compact then
		CompactLabel = New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Library.Scheme.Font,
			Size = UDim2.fromScale(1, 1),
			Text = tostring(Slider.Text),
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 12,
			ZIndex = 6,
			Parent = Bar,
		})
		Library:AddToRegistry(CompactLabel, { TextColor3 = "FontColor", Font = "Font" })
		Slider.TextLabel = CompactLabel
	end

	local Knob = New("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(245, 245, 255),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(Compact and 0 or 12, Compact and 0 or 12),
		Visible = not Compact,
		ZIndex = 7,
		Parent = Bar,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Knob })

	local function Format(Value)
		local Text = tostring(Round(Value, Rounding))
		if Rounding > 0 then
			Text = string.format("%." .. tostring(Rounding) .. "f", Value)
		end
		return Text
	end

	local function Render(Instant)
		local Alpha = 0
		if Maximum ~= Minimum then
			Alpha = Clamp((Slider.Value - Minimum) / (Maximum - Minimum), 0, 1)
		end

		local Text = Format(Slider.Value) .. Suffix
		if not Info.HideMax and not Compact then
			Text = Text .. " / " .. Format(Maximum) .. Suffix
		end
		ValueLabel.Text = Text
		if CompactLabel then
			CompactLabel.Text = tostring(Slider.Text) .. ": " .. Format(Slider.Value) .. Suffix
		end

		if Instant then
			FillBar.Size = UDim2.fromScale(Alpha, 1)
			Knob.Position = UDim2.fromScale(Alpha, 0.5)
		else
			Library:Tween(FillBar, { Size = UDim2.fromScale(Alpha, 1) }, 0.12, "Soft")
			Library:Tween(Knob, { Position = UDim2.fromScale(Alpha, 0.5) }, 0.12, "Soft")
		end
	end

	function Slider:SetValue(Value, Silent)
		Value = tonumber(Value) or Minimum
		Value = Round(Clamp(Value, Minimum, Maximum), Rounding)
		Slider.Value = Value
		Render(false)
		if Silent ~= true then
			Slider:Fire(Value)
		end
		return Slider
	end

	function Slider:SetMin(NewMin)
		Minimum = NewMin
		Slider.Min = NewMin
		Slider:SetValue(Slider.Value)
		return Slider
	end

	function Slider:SetMax(NewMax)
		Maximum = NewMax
		Slider.Max = NewMax
		Slider:SetValue(Slider.Value)
		return Slider
	end

	function Slider:SetText(NewText)
		Slider.Text = NewText
		if TextLabel then
			TextLabel.Text = tostring(NewText)
		end
		Render(true)
		return Slider
	end

	BindDrag(Bar, function(X)
		if Slider.Disabled then
			return
		end
		local Value = Minimum + (Maximum - Minimum) * X
		Value = Round(Clamp(Value, Minimum, Maximum), Rounding)
		if Value ~= Slider.Value then
			Slider.Value = Value
			Render(true)
			Slider:Fire(Value)
		end
	end)

	Library:Connect(Bar.MouseEnter, function()
		Library:Tween(BarStroke, { Color = Library.Scheme.AccentColor }, 0.15, "Smooth")
		if not Compact then
			Library:Tween(Knob, { Size = UDim2.fromOffset(15, 15) }, 0.15, "Snappy")
		end
	end)
	Library:Connect(Bar.MouseLeave, function()
		Library:Tween(BarStroke, { Color = Library.Scheme.OutlineColor }, 0.15, "Smooth")
		if not Compact then
			Library:Tween(Knob, { Size = UDim2.fromOffset(12, 12) }, 0.15, "Smooth")
		end
	end)

	if Info.Tooltip then
		Library:AddTooltip(Info.Tooltip, Info.DisabledTooltip, Row)
	end

	Slider.Value = Round(Clamp(Slider.Value, Minimum, Maximum), Rounding)
	Render(true)

	if Idx ~= nil then
		Options[Idx] = Slider
	end
	if Info.Visible == false then
		Slider:SetVisible(false)
	end
	if Info.Callback then
		Library:SafeCallback(Info.Callback, Slider.Value)
	end

	return self:Register(Slider, Info.Text)
end

------------------------------------------------------------ Dropdown -----

function ElementFuncs:AddDropdown(Idx, Info)
	Info = Info or {}

	local Multi = Info.Multi or false
	local MaxVisible = Info.MaxVisibleDropdownItems or 8
	local HasLabel = Info.Text ~= nil and Info.Text ~= ""

	local Row = New("Frame", {
		Name = "Dropdown",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HasLabel and 46 or 28),
		Parent = self.Container,
	})

	local Dropdown = NewElement({
		Index = Idx,
		Type = "Dropdown",
		Holder = Row,
		Row = Row,
		Values = Info.Values or {},
		Value = Multi and {} or nil,
		Multi = Multi,
		Text = Info.Text,
		AllowNull = Info.AllowNull or false,
		SpecialType = Info.SpecialType,
		Callback = Info.Callback,
		Open = false,
		Buttons = {},
	})

	if HasLabel then
		local TextLabel = New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Library.Scheme.Font,
			Size = UDim2.new(1, 0, 0, 16),
			Text = tostring(Info.Text),
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Parent = Row,
		})
		Library:AddToRegistry(TextLabel, { TextColor3 = "FontColor", Font = "Font" })
		Dropdown.TextLabel = TextLabel
	end

	local Button = New("TextButton", {
		Name = "Display",
		AnchorPoint = Vector2.new(0, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Font = Library.Scheme.Font,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 13,
		ZIndex = 3,
		Parent = Row,
	})
	Corner(Button, Library.CornerRadius - 1)
	Library:AddToRegistry(Button, { BackgroundColor3 = "BackgroundColor" })
	local ButtonStroke = Stroke(Button, Library.Scheme.OutlineColor, 1, 0)
	Library:AddToRegistry(ButtonStroke, { Color = "OutlineColor" })

	local DisplayLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Font = Library.Scheme.Font,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Text = "---",
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = Button,
	})
	Library:AddToRegistry(DisplayLabel, { TextColor3 = "FontColor", Font = "Font" })

	local Chevron = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(1, -10, 0.5, 0),
		Rotation = 90,
		Size = UDim2.fromOffset(12, 12),
		Text = "›",
		TextColor3 = Library.Scheme.AccentColor,
		TextSize = 16,
		ZIndex = 4,
		Parent = Button,
	})
	Library:AddToRegistry(Chevron, { TextColor3 = "AccentColor" })

	---------------------------------------------------------------- popup --
	local Popup = New("Frame", {
		Name = "DropdownPopup",
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(180, 0),
		Visible = false,
		ZIndex = 600,
		Parent = Library.PopupLayer,
	})
	Corner(Popup, Library.CornerRadius - 1)
	Library:AddToRegistry(Popup, { BackgroundColor3 = "MainColor" })
	local PopupStroke = Stroke(Popup, Library.Scheme.AccentColor, 1, 0.25)
	Library:AddToRegistry(PopupStroke, { Color = "AccentColor" })

	local SearchBox
	if Info.Searchable then
		SearchBox = New("TextBox", {
			BackgroundColor3 = Library.Scheme.BackgroundColor,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = Library.Scheme.Font,
			PlaceholderText = "Search...",
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 22),
			Text = "",
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 12,
			ZIndex = 602,
			Parent = Popup,
		})
		Corner(SearchBox, 4)
		Padding(SearchBox, 0, 0, 8, 8)
		Library:AddToRegistry(SearchBox, { BackgroundColor3 = "BackgroundColor", TextColor3 = "FontColor" })
	end

	local ItemHolder = New("ScrollingFrame", {
		Name = "Items",
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		Position = UDim2.fromOffset(0, SearchBox and 32 or 4),
		ScrollBarImageColor3 = Library.Scheme.AccentColor,
		ScrollBarThickness = 3,
		Size = UDim2.new(1, 0, 1, SearchBox and -36 or -8),
		ZIndex = 602,
		Parent = Popup,
	})
	Library:AddToRegistry(ItemHolder, { ScrollBarImageColor3 = "AccentColor" })
	Padding(ItemHolder, 0, 0, 5, 5)
	ListLayout(ItemHolder, 2)

	------------------------------------------------------------- helpers --
	local function GetActiveValues()
		if Multi then
			local Active = {}
			for Value, State in pairs(Dropdown.Value or {}) do
				if State then
					table.insert(Active, tostring(Value))
				end
			end
			table.sort(Active)
			return Active
		end
		return Dropdown.Value and { Dropdown.Value } or {}
	end

	function Dropdown:GetActiveValues()
		return GetActiveValues()
	end

	function Dropdown:Display()
		local Active = GetActiveValues()
		local Text = "---"
		if #Active > 0 then
			Text = table.concat(Active, ", ")
		end
		DisplayLabel.Text = Text
		return Text
	end

	local function RenderButtons()
		for _, Entry in pairs(Dropdown.Buttons) do
			local Selected
			if Multi then
				Selected = Dropdown.Value and Dropdown.Value[Entry.Value] == true
			else
				Selected = Dropdown.Value == Entry.Value
			end
			Library:Tween(Entry.Button, {
				BackgroundTransparency = Selected and 0 or 1,
			}, 0.15, "Smooth")
			Library:Tween(Entry.Label, {
				TextColor3 = Selected and Color3.new(1, 1, 1) or Library.Scheme.FontColor,
			}, 0.15, "Smooth")
		end
		Dropdown:Display()
	end

	local function BuildButtons()
		for _, Entry in pairs(Dropdown.Buttons) do
			Entry.Button:Destroy()
		end
		Dropdown.Buttons = {}

		for Index, Value in ipairs(Dropdown.Values) do
			local Text = tostring(Value)

			local ItemButton = New("TextButton", {
				AutoButtonColor = false,
				BackgroundColor3 = Library.Scheme.AccentColor,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				LayoutOrder = Index,
				Size = UDim2.new(1, 0, 0, 24),
				Text = "",
				ZIndex = 603,
				Parent = ItemHolder,
			})
			Corner(ItemButton, 4)
			Library:AddToRegistry(ItemButton, { BackgroundColor3 = "AccentColor" })

			local ItemLabel = New("TextLabel", {
				BackgroundTransparency = 1,
				Font = Library.Scheme.Font,
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -16, 1, 0),
				Text = Text,
				TextColor3 = Library.Scheme.FontColor,
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 604,
				Parent = ItemButton,
			})
			Library:AddToRegistry(ItemLabel, { Font = "Font" })

			local Entry = { Button = ItemButton, Label = ItemLabel, Value = Value, Text = Text }

			Library:Connect(ItemButton.MouseEnter, function()
				local Selected = Multi and (Dropdown.Value or {})[Value] or Dropdown.Value == Value
				if not Selected then
					Library:Tween(ItemButton, { BackgroundTransparency = 0.82 }, 0.12, "Smooth")
				end
			end)
			Library:Connect(ItemButton.MouseLeave, function()
				local Selected = Multi and (Dropdown.Value or {})[Value] or Dropdown.Value == Value
				if not Selected then
					Library:Tween(ItemButton, { BackgroundTransparency = 1 }, 0.12, "Smooth")
				end
			end)

			Library:Connect(ItemButton.MouseButton1Click, function()
				local Mouse = Library:GetMouse()
				Library:Ripple(ItemButton, Mouse.X, Mouse.Y, Color3.new(1, 1, 1))

				if Multi then
					Dropdown.Value = Dropdown.Value or {}
					Dropdown.Value[Value] = not Dropdown.Value[Value] or nil
					RenderButtons()
					Dropdown:Fire(Dropdown.Value)
				else
					if Dropdown.Value == Value and Dropdown.AllowNull then
						Dropdown.Value = nil
					else
						Dropdown.Value = Value
					end
					RenderButtons()
					Dropdown:Fire(Dropdown.Value)
					Dropdown:Toggle(false)
				end
				Library:UpdateDependencyBoxes()
			end)

			table.insert(Dropdown.Buttons, Entry)
		end

		RenderButtons()
	end

	local function PopupHeight()
		local Visible = 0
		for _, Entry in pairs(Dropdown.Buttons) do
			if Entry.Button.Visible then
				Visible = Visible + 1
			end
		end
		Visible = math.max(math.min(Visible, MaxVisible), 1)
		return Visible * 26 + 8 + (SearchBox and 32 or 0)
	end

	function Dropdown:Toggle(State)
		if State == nil then
			State = not Dropdown.Open
		end
		Dropdown.Open = State

		if State then
			for _, Other in pairs(Library.OpenedFrames) do
				if Other ~= Dropdown and Other.Toggle then
					Other:Toggle(false)
				end
			end
			if not TableFind(Library.OpenedFrames, Dropdown) then
				table.insert(Library.OpenedFrames, Dropdown)
			end

			local AbsolutePosition = Button.AbsolutePosition
			local AbsoluteSize = Button.AbsoluteSize
			Popup.Position = UDim2.fromOffset(AbsolutePosition.X, AbsolutePosition.Y + AbsoluteSize.Y + 4)
			Popup.Size = UDim2.fromOffset(AbsoluteSize.X, 0)
			Popup.Visible = true

			Library:Tween(Popup, { Size = UDim2.fromOffset(AbsoluteSize.X, PopupHeight()) }, 0.28, "Snappy")
			Library:Tween(Chevron, { Rotation = 270 }, 0.28, "Snappy")

			-- staggered item entrance
			for Index, Entry in ipairs(Dropdown.Buttons) do
				Entry.Label.TextTransparency = 1
				Library:Delay(math.min(Index, 10) * 0.02, function()
					Library:Tween(Entry.Label, { TextTransparency = 0 }, 0.2, "Smooth")
				end)
			end
		else
			local Index2 = TableFind(Library.OpenedFrames, Dropdown)
			if Index2 then
				table.remove(Library.OpenedFrames, Index2)
			end
			Library:Tween(Popup, { Size = UDim2.fromOffset(Popup.AbsoluteSize.X, 0) }, 0.22, "Smooth")
			Library:Tween(Chevron, { Rotation = 90 }, 0.22, "Smooth")
			Library:Delay(0.25 * (Library.AnimationSpeed or 1), function()
				if not Dropdown.Open then
					Popup.Visible = false
				end
			end)
		end
	end

	function Dropdown:SetValues(NewValues)
		if NewValues then
			Dropdown.Values = NewValues
		end
		BuildButtons()
		if Dropdown.Open then
			Library:Tween(Popup, { Size = UDim2.fromOffset(Popup.AbsoluteSize.X, PopupHeight()) }, 0.2, "Smooth")
		end
		return Dropdown
	end

	function Dropdown:SetValue(Value, Silent)
		if Multi then
			local NewValue = {}
			if type(Value) == "table" then
				for Key, State in pairs(Value) do
					if type(Key) == "number" then
						NewValue[State] = true
					elseif State then
						NewValue[Key] = true
					end
				end
			end
			Dropdown.Value = NewValue
		else
			if type(Value) == "number" and Dropdown.Values[Value] ~= nil then
				Value = Dropdown.Values[Value]
			end
			if Value ~= nil and not TableFind(Dropdown.Values, Value) then
				Value = Dropdown.AllowNull and nil or Dropdown.Value
			end
			Dropdown.Value = Value
		end

		RenderButtons()
		if Silent ~= true then
			Dropdown:Fire(Dropdown.Value)
		end
		Library:UpdateDependencyBoxes()
		return Dropdown
	end

	function Dropdown:SetText(NewText)
		Dropdown.Text = NewText
		if Dropdown.TextLabel then
			Dropdown.TextLabel.Text = tostring(NewText)
		end
		return Dropdown
	end

	function Dropdown:AddValue(Value)
		if not TableFind(Dropdown.Values, Value) then
			table.insert(Dropdown.Values, Value)
			Dropdown:SetValues()
		end
		return Dropdown
	end

	function Dropdown:RemoveValue(Value)
		local Index2 = TableFind(Dropdown.Values, Value)
		if Index2 then
			table.remove(Dropdown.Values, Index2)
			Dropdown:SetValues()
		end
		return Dropdown
	end

	Library:Connect(Button.MouseButton1Click, function()
		if Dropdown.Disabled then
			return
		end
		Dropdown:Toggle()
	end)

	Library:Connect(Button.MouseEnter, function()
		Library:Tween(ButtonStroke, { Color = Library.Scheme.AccentColor }, 0.15, "Smooth")
	end)
	Library:Connect(Button.MouseLeave, function()
		if not Dropdown.Open then
			Library:Tween(ButtonStroke, { Color = Library.Scheme.OutlineColor }, 0.15, "Smooth")
		end
	end)

	if SearchBox then
		Library:Connect(SearchBox:GetPropertyChangedSignal("Text"), function()
			local Query = string.lower(SearchBox.Text)
			for _, Entry in pairs(Dropdown.Buttons) do
				Entry.Button.Visible = Query == "" or string.find(string.lower(Entry.Text), Query, 1, true) ~= nil
			end
			Library:Tween(Popup, { Size = UDim2.fromOffset(Popup.AbsoluteSize.X, PopupHeight()) }, 0.15, "Smooth")
		end)
	end

	------------------------------------------------------- special types --
	if Info.SpecialType == "Player" or Info.SpecialType == "Team" then
		local function Refresh()
			local Values = {}
			if Info.SpecialType == "Player" then
				for _, Player in pairs(Players:GetPlayers()) do
					if Player ~= LocalPlayer or Info.IncludeSelf then
						table.insert(Values, Player.Name)
					end
				end
			else
				local TeamService = GetService("Teams")
				if TeamService then
					for _, Team in pairs(TeamService:GetTeams()) do
						table.insert(Values, Team.Name)
					end
				end
			end
			table.sort(Values)
			Dropdown:SetValues(Values)
		end

		Dropdown.Refresh = Refresh
		pcall(Refresh)

		if Info.SpecialType == "Player" then
			Library:Connect(Players.PlayerAdded, Refresh)
			Library:Connect(Players.PlayerRemoving, function()
				Library:Delay(0.1, Refresh)
			end)
		end
	end

	BuildButtons()

	-- defaults
	if Info.Default ~= nil then
		Dropdown:SetValue(Info.Default, true)
	end
	Dropdown:Display()

	if Info.Tooltip then
		Library:AddTooltip(Info.Tooltip, Info.DisabledTooltip, Row)
	end
	if Idx ~= nil then
		Options[Idx] = Dropdown
	end
	if Info.Visible == false then
		Dropdown:SetVisible(false)
	end
	if Info.Callback then
		Library:SafeCallback(Info.Callback, Dropdown.Value)
	end

	Dropdown.Popup = Popup
	return self:Register(Dropdown, Info.Text)
end

--------------------------------------------------------------- Input -----

function ElementFuncs:AddInput(Idx, Info)
	Info = Info or {}

	local HasLabel = Info.Text ~= nil and Info.Text ~= ""

	local Row = New("Frame", {
		Name = "Input",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HasLabel and 46 or 28),
		Parent = self.Container,
	})

	local Input = NewElement({
		Index = Idx,
		Type = "Input",
		Holder = Row,
		Row = Row,
		Value = tostring(Info.Default or ""),
		Text = Info.Text,
		Numeric = Info.Numeric or false,
		Finished = Info.Finished or false,
		Callback = Info.Callback,
	})

	if HasLabel then
		local TextLabel = New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Library.Scheme.Font,
			Size = UDim2.new(1, 0, 0, 16),
			Text = tostring(Info.Text),
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Parent = Row,
		})
		Library:AddToRegistry(TextLabel, { TextColor3 = "FontColor", Font = "Font" })
		Input.TextLabel = TextLabel
	end

	local Box = New("TextBox", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		ClearTextOnFocus = Info.ClearTextOnFocus or false,
		ClipsDescendants = true,
		Font = Library.Scheme.Font,
		PlaceholderColor3 = Library:GetShade(Library.Scheme.FontColor, -0.35),
		PlaceholderText = tostring(Info.Placeholder or ""),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 26),
		Text = Input.Value,
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = Row,
	})
	Corner(Box, Library.CornerRadius - 1)
	Padding(Box, 0, 0, 10, 10)
	Library:AddToRegistry(Box, { BackgroundColor3 = "BackgroundColor", TextColor3 = "FontColor", Font = "Font" })
	local BoxStroke = Stroke(Box, Library.Scheme.OutlineColor, 1, 0)
	Library:AddToRegistry(BoxStroke, { Color = "OutlineColor" })
	Input.TextBox = Box

	local Underline = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Library.Scheme.AccentColor,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0, 0, 0, 2),
		ZIndex = 5,
		Parent = Box,
	})
	Library:AddToRegistry(Underline, { BackgroundColor3 = "AccentColor" })

	local function Sanitize(Text)
		if Info.MaxLength and #Text > Info.MaxLength then
			Text = Text:sub(1, Info.MaxLength)
		end
		if Input.Numeric then
			Text = Text:gsub("[^%d%.%-]", "")
		end
		return Text
	end

	function Input:SetValue(Value, Silent)
		Value = Sanitize(tostring(Value))
		Input.Value = Value
		Box.Text = Value
		if Silent ~= true then
			Input:Fire(Value)
		end
		Library:UpdateDependencyBoxes()
		return Input
	end

	function Input:SetText(NewText)
		Input.Text = NewText
		if Input.TextLabel then
			Input.TextLabel.Text = tostring(NewText)
		end
		return Input
	end

	function Input:GetNumber()
		return tonumber(Input.Value) or 0
	end

	Library:Connect(Box.Focused, function()
		Library:Tween(Underline, { Size = UDim2.new(1, 0, 0, 2) }, 0.25, "Snappy")
		Library:Tween(BoxStroke, { Color = Library.Scheme.AccentColor }, 0.2, "Smooth")
	end)

	Library:Connect(Box.FocusLost, function(Enter)
		Library:Tween(Underline, { Size = UDim2.new(0, 0, 0, 2) }, 0.2, "Smooth")
		Library:Tween(BoxStroke, { Color = Library.Scheme.OutlineColor }, 0.2, "Smooth")
		if Input.Finished and not Enter then
			Box.Text = Input.Value
			return
		end
		Input:SetValue(Box.Text)
	end)

	if not Info.Finished then
		Library:Connect(Box:GetPropertyChangedSignal("Text"), function()
			local Clean = Sanitize(Box.Text)
			if Clean ~= Box.Text then
				Box.Text = Clean
				return
			end
			if Clean ~= Input.Value then
				Input.Value = Clean
				Input:Fire(Clean)
				Library:UpdateDependencyBoxes()
			end
		end)
	end

	if Info.Tooltip then
		Library:AddTooltip(Info.Tooltip, Info.DisabledTooltip, Row)
	end
	if Idx ~= nil then
		Options[Idx] = Input
	end
	if Info.Visible == false then
		Input:SetVisible(false)
	end
	if Info.Callback then
		Library:SafeCallback(Info.Callback, Input.Value)
	end

	return self:Register(Input, Info.Text)
end

--------------------------------------------------------------- Image -----

function ElementFuncs:AddImage(Idx, Info)
	if type(Idx) == "table" then
		Info = Idx
		Idx = nil
	end
	Info = Info or {}

	local Height = Info.Height or 120

	local Row = New("Frame", {
		Name = "Image",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Height),
		Parent = self.Container,
	})

	local ImageAsset = Library:GetIcon(Info.Image or Info.Icon)

	local Picture = New("ImageLabel", {
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BackgroundTransparency = Info.Transparent and 1 or 0,
		BorderSizePixel = 0,
		Image = ImageAsset or "",
		ImageTransparency = 1,
		ScaleType = Info.ScaleType or Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = Row,
	})
	Corner(Picture, Library.CornerRadius - 1)
	Library:Tween(Picture, { ImageTransparency = Info.Transparency or 0 }, 0.4, "Smooth")

	local ImageElement = NewElement({
		Index = Idx,
		Type = "Image",
		Holder = Row,
		Value = Info.Image,
		Picture = Picture,
	})

	function ImageElement:SetImage(NewImage)
		ImageElement.Value = NewImage
		Picture.Image = Library:GetIcon(NewImage) or ""
		return ImageElement
	end

	if Idx ~= nil then
		Options[Idx] = ImageElement
	end
	return self:Register(ImageElement, Info.Text)
end

------------------------------------------------------- Dependency box ----

function ElementFuncs:AddDependencyBox()
	local Holder = New("Frame", {
		Name = "DependencyBox",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Visible = false,
		Parent = self.Container,
	})
	ListLayout(Holder, 6)

	local Box = setmetatable({
		Type = "DependencyBox",
		Container = Holder,
		Holder = Holder,
		Elements = {},
		Dependencies = {},
	}, ElementFuncs)
	Box.Groupbox = self.Groupbox or self

	function Box:SetupDependencies(Dependencies)
		Box.Dependencies = Dependencies or {}
		Library:UpdateDependencyBoxes()
		return Box
	end

	function Box:Update()
		local Visible = true
		for _, Dependency in pairs(Box.Dependencies) do
			local Element, Expected = Dependency[1], Dependency[2]
			if not Element then
				Visible = false
				break
			end
			if Element.Value ~= Expected then
				Visible = false
				break
			end
		end
		Holder.Visible = Visible
		return Visible
	end

	table.insert(Library.DependencyBoxes, Box)
	return Box
end

function Library:UpdateDependencyBoxes()
	for _, Box in pairs(Library.DependencyBoxes) do
		pcall(function()
			Box:Update()
		end)
	end
end

--[[
    Obsidian attaches colour / key pickers to an element, but plenty of scripts
    call them straight on a groupbox. Make a label on the fly so both work.
]]
function ElementFuncs:AddColorPicker(Index, Info)
	Info = Info or {}
	local Label = self:AddLabel(Info.Text or Info.Title or "Color")
	return Label:AddColorPicker(Index, Info)
end

function ElementFuncs:AddKeyPicker(Index, Info)
	Info = Info or {}
	local Label = self:AddLabel(Info.Text or "Keybind")
	return Label:AddKeyPicker(Index, Info)
end

--//////////////////////////////////////////////////////////////////////////
--// Groupboxes + tabboxes                                                //
--//////////////////////////////////////////////////////////////////////////

local function CreateGroupboxFrame(Parent, Title, Icon, Order)
	local Holder = New("Frame", {
		Name = "Groupbox",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		LayoutOrder = Order or 0,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = Parent,
	})
	Corner(Holder, Library.CornerRadius)
	Library:AddToRegistry(Holder, { BackgroundColor3 = "MainColor" })
	local HolderStroke = Stroke(Holder, Library.Scheme.OutlineColor, 1, 0)
	Library:AddToRegistry(HolderStroke, { Color = "OutlineColor" })

	local TitleBar = New("Frame", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 3,
		Parent = Holder,
	})

	local Image, Glyph = Library:GetIcon(Icon)
	local TextOffset = 12

	if Image then
		New("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = Image,
			ImageColor3 = Library.Scheme.AccentColor,
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			ZIndex = 4,
			Parent = TitleBar,
		})
		TextOffset = 32
	elseif Glyph then
		New("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			Text = Glyph,
			TextColor3 = Library.Scheme.AccentColor,
			TextSize = 14,
			ZIndex = 4,
			Parent = TitleBar,
		})
		TextOffset = 32
	end

	local TitleLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(0, TextOffset, 0.5, 0),
		Size = UDim2.new(1, -TextOffset - 12, 1, 0),
		Text = tostring(Title or ""),
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = TitleBar,
	})
	Library:AddToRegistry(TitleLabel, { TextColor3 = "FontColor" })

	local Accent = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Library.Scheme.AccentColor,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 4,
		Parent = TitleBar,
	})
	Library:AddToRegistry(Accent, { BackgroundColor3 = "AccentColor" })
	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = Accent,
	})

	local Container = New("Frame", {
		Name = "Content",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 3,
		Parent = Holder,
	})
	Padding(Container, 10, 12, 12, 12)
	ListLayout(Container, 7)

	return Holder, Container, TitleLabel
end

local function NewGroupbox(Parent, Title, Icon, Order)
	local Holder, Container, TitleLabel = CreateGroupboxFrame(Parent, Title, Icon, Order)

	local Groupbox = setmetatable({
		Type = "Groupbox",
		Holder = Holder,
		Container = Container,
		TitleLabel = TitleLabel,
		Elements = {},
	}, ElementFuncs)
	Groupbox.Groupbox = Groupbox

	function Groupbox:Resize()
		return Groupbox -- automatic sizing does this for us, kept for compatibility
	end

	function Groupbox:SetTitle(NewTitle)
		TitleLabel.Text = tostring(NewTitle)
		return Groupbox
	end

	function Groupbox:SetVisible(Visible)
		Holder.Visible = Visible and true or false
		return Groupbox
	end

	function Groupbox:Destroy()
		Holder:Destroy()
	end

	-- entrance animation
	Holder.BackgroundTransparency = 1
	Library:Tween(Holder, { BackgroundTransparency = 0 }, 0.35, "Smooth")

	return Groupbox
end

local function NewTabbox(Parent, Order)
	local Holder = New("Frame", {
		Name = "Tabbox",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		LayoutOrder = Order or 0,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = Parent,
	})
	Corner(Holder, Library.CornerRadius)
	Library:AddToRegistry(Holder, { BackgroundColor3 = "MainColor" })
	local HolderStroke = Stroke(Holder, Library.Scheme.OutlineColor, 1, 0)
	Library:AddToRegistry(HolderStroke, { Color = "OutlineColor" })

	local TabRow = New("Frame", {
		Name = "Tabs",
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 3,
		Parent = Holder,
	})
	Corner(TabRow, Library.CornerRadius)
	Library:AddToRegistry(TabRow, { BackgroundColor3 = "BackgroundColor" })
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = TabRow,
	})

	local Indicator = New("Frame", {
		Name = "Indicator",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Library.Scheme.AccentColor,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(0, 0),
		ZIndex = 5,
		Parent = TabRow,
	})
	Corner(Indicator, 2)
	Library:AddToRegistry(Indicator, { BackgroundColor3 = "AccentColor" })

	local Tabbox = { Type = "Tabbox", Holder = Holder, Tabs = {}, Current = nil }

	local function Rebalance()
		local Count = #Tabbox.Tabs
		for _, Tab in pairs(Tabbox.Tabs) do
			Tab.Button.Size = UDim2.new(1 / Count, 0, 1, 0)
		end
		if Tabbox.Current then
			Tabbox.Current:Show(true)
		end
	end

	function Tabbox:AddTab(Name)
		local Button = New("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Font = Library.Scheme.Font,
			LayoutOrder = #Tabbox.Tabs + 1,
			Size = UDim2.new(1, 0, 1, 0),
			Text = tostring(Name),
			TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.3),
			TextSize = 12,
			ZIndex = 4,
			Parent = TabRow,
		})
		Library:AddToRegistry(Button, { Font = "Font" })

		local Container = New("Frame", {
			Name = "Content",
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 0),
			Visible = false,
			ZIndex = 3,
			Parent = Holder,
		})
		Padding(Container, 10, 12, 12, 12)
		ListLayout(Container, 7)

		local Tab = setmetatable({
			Type = "Groupbox",
			Name = Name,
			Button = Button,
			Container = Container,
			Holder = Container,
			Elements = {},
		}, ElementFuncs)
		Tab.Groupbox = Tab

		function Tab:Resize()
			return Tab
		end

		function Tab:Show(Silent)
			for _, Other in pairs(Tabbox.Tabs) do
				if Other ~= Tab then
					Other.Container.Visible = false
					Library:Tween(Other.Button, {
						TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.3),
					}, 0.2, "Smooth")
				end
			end

			Tabbox.Current = Tab
			Container.Visible = true
			Library:Tween(Button, { TextColor3 = Library.Scheme.FontColor }, 0.2, "Smooth")

			local Index = TableFind(Tabbox.Tabs, Tab) or 1
			local Count = math.max(#Tabbox.Tabs, 1)
			local Goal = {
				Position = UDim2.fromScale((Index - 1) / Count, 1),
				Size = UDim2.new(1 / Count, 0, 0, 2),
			}
			if Silent then
				Indicator.Position = Goal.Position
				Indicator.Size = Goal.Size
			else
				Library:Tween(Indicator, Goal, 0.3, "Snappy")
			end
			return Tab
		end

		Library:Connect(Button.MouseButton1Click, function()
			local Mouse = Library:GetMouse()
			Library:Ripple(Button, Mouse.X, Mouse.Y)
			Tab:Show()
		end)

		Library:Connect(Button.MouseEnter, function()
			if Tabbox.Current ~= Tab then
				Library:Tween(Button, { TextColor3 = Library.Scheme.FontColor }, 0.15, "Smooth")
			end
		end)
		Library:Connect(Button.MouseLeave, function()
			if Tabbox.Current ~= Tab then
				Library:Tween(Button, {
					TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.3),
				}, 0.15, "Smooth")
			end
		end)

		table.insert(Tabbox.Tabs, Tab)
		Rebalance()
		if #Tabbox.Tabs == 1 then
			Tab:Show(true)
		end
		return Tab
	end

	return Tabbox
end

--//////////////////////////////////////////////////////////////////////////
--// Window                                                               //
--//////////////////////////////////////////////////////////////////////////

function Library:CreateWindow(Config)
	Config = Config or {}

	if Library.Window then
		warn("[OzionUI] a window already exists -- returning the existing one")
		return Library.Window
	end

	Library.CornerRadius = Config.CornerRadius or Library.CornerRadius
	Library.ShowCustomCursor = Config.ShowCustomCursor ~= false
	Library.NotifySide = Config.NotifySide or Library.NotifySide
	if Config.Animations ~= nil then
		Library.Animations = Config.Animations
	end
	if Config.AnimationSpeed then
		Library.AnimationSpeed = Config.AnimationSpeed
	end

	Library.IsMobile = false
	pcall(function()
		Library.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end)

	local Gui = Library:GetScreenGui()
	local WindowSize = Config.Size or UDim2.fromOffset(640, 520)
	local MinSize = Config.MinSize or Vector2.new(460, 340)

	local ViewportSize = Vector2.new(1280, 720)
	pcall(function()
		local Absolute = Gui.AbsoluteSize
		if Absolute and Absolute.X > 0 then
			ViewportSize = Absolute
		end
	end)

	local StartPosition = Config.Position
	if not StartPosition then
		local Width = WindowSize.X.Offset
		local Height = WindowSize.Y.Offset
		StartPosition = UDim2.fromOffset(
			math.floor((ViewportSize.X - Width) / 2),
			math.floor((ViewportSize.Y - Height) / 2)
		)
	end

	------------------------------------------------------------ main frame --
	local Main = New("Frame", {
		Name = "Main",
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Position = StartPosition,
		Size = WindowSize,
		Visible = false,
		ZIndex = 10,
		Parent = Gui,
	})
	Corner(Main, Library.CornerRadius + 2)
	Library:AddToRegistry(Main, { BackgroundColor3 = "BackgroundColor" })

	local MainScale = New("UIScale", { Scale = Library.DPIScale, Parent = Main })
	table.insert(Library.ScaleObjects, MainScale)
	Library.MainScale = MainScale

	-- animated outline
	local OutlineStroke = Stroke(Main, Library.Scheme.AccentColor, 1.4, 0.15)
	local OutlineGradient = New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Library.Scheme.AccentColor),
			ColorSequenceKeypoint.new(0.5, Library:GetLighterColor(Library.Scheme.AccentColor)),
			ColorSequenceKeypoint.new(1, Library.Scheme.AccentColor),
		}),
		Parent = OutlineStroke,
	})
	Library:AddToRegistry(OutlineStroke, { Color = "AccentColor" })
	Library:AddToRegistry(OutlineGradient, {
		Color = function(Scheme)
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, Scheme.AccentColor),
				ColorSequenceKeypoint.new(0.5, Library:GetLighterColor(Scheme.AccentColor)),
				ColorSequenceKeypoint.new(1, Scheme.AccentColor),
			})
		end,
	})
	Library:AnimateGradient(OutlineGradient, 8)

	-- drop shadow
	New("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		Position = UDim2.fromScale(0.5, 0.5),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.new(1, 60, 1, 60),
		SliceCenter = Rect.new(49, 49, 450, 450),
		ZIndex = 9,
		Parent = Main,
	})

	--------------------------------------------------------------- titlebar --
	local TitleBar = New("Frame", {
		Name = "TitleBar",
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 12,
		Parent = Main,
	})
	Corner(TitleBar, Library.CornerRadius + 2)
	Library:AddToRegistry(TitleBar, { BackgroundColor3 = "MainColor" })

	New("Frame", {
		Name = "Cover",
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.5),
		ZIndex = 12,
		Parent = TitleBar,
	})

	local TitleOffset = 14
	local WindowImage, WindowGlyph = Library:GetIcon(Config.Icon)
	if WindowImage then
		New("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = WindowImage,
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			ZIndex = 14,
			Parent = TitleBar,
		})
		TitleOffset = 42
	elseif WindowGlyph then
		local GlyphLabel = New("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			Text = WindowGlyph,
			TextColor3 = Library.Scheme.AccentColor,
			TextSize = 18,
			ZIndex = 14,
			Parent = TitleBar,
		})
		Library:AddToRegistry(GlyphLabel, { TextColor3 = "AccentColor" })
		TitleOffset = 42
	end

	local TitleLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(0, TitleOffset, 0.5, 0),
		Size = UDim2.new(1, -TitleOffset - 90, 1, 0),
		Text = tostring(Config.Title or "OzionUI"),
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 14,
		Parent = TitleBar,
	})
	Library:AddToRegistry(TitleLabel, { TextColor3 = "FontColor" })

	local TitleGradient = New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Library.Scheme.FontColor),
			ColorSequenceKeypoint.new(0.5, Library.Scheme.AccentColor),
			ColorSequenceKeypoint.new(1, Library.Scheme.FontColor),
		}),
		Parent = TitleLabel,
	})
	Library:AddToRegistry(TitleGradient, {
		Color = function(Scheme)
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, Scheme.FontColor),
				ColorSequenceKeypoint.new(0.5, Scheme.AccentColor),
				ColorSequenceKeypoint.new(1, Scheme.FontColor),
			})
		end,
	})
	Library:AnimateGradient(TitleGradient, 10)

	local function TitleButton(Text, Offset, Color, OnClick)
		local Button = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			AutoButtonColor = false,
			BackgroundColor3 = Library.Scheme.BackgroundColor,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -Offset, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			Text = Text,
			TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.2),
			TextSize = 15,
			ZIndex = 14,
			Parent = TitleBar,
		})
		Corner(Button, 6)

		Library:Connect(Button.MouseEnter, function()
			Library:Tween(Button, { BackgroundTransparency = 0, TextColor3 = Color }, 0.15, "Smooth")
			Library:Tween(Button, { Rotation = 90 }, 0.25, "Snappy")
		end)
		Library:Connect(Button.MouseLeave, function()
			Library:Tween(Button, {
				BackgroundTransparency = 1,
				TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.2),
			}, 0.2, "Smooth")
			Library:Tween(Button, { Rotation = 0 }, 0.25, "Smooth")
		end)
		Library:Connect(Button.MouseButton1Click, OnClick)
		return Button
	end

	TitleButton("✕", 12, Library.Scheme.Red, function()
		Library:Unload()
	end)
	TitleButton("−", 42, Library.Scheme.AccentColor, function()
		Library:Toggle(false)
	end)


	----------------------------------------------------------------- body --
	local SidebarWidth = Config.SidebarWidth or 152
	local FooterHeight = (Config.Footer and Config.Footer ~= "") and 24 or 0

	local Sidebar = New("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(0, SidebarWidth, 1, -40 - FooterHeight),
		ZIndex = 11,
		Parent = Main,
	})
	Library:AddToRegistry(Sidebar, { BackgroundColor3 = "MainColor" })

	local SidebarEdge = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Library.Scheme.OutlineColor,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		ZIndex = 12,
		Parent = Sidebar,
	})
	Library:AddToRegistry(SidebarEdge, { BackgroundColor3 = "OutlineColor" })

	local SearchBox = New("TextBox", {
		Name = "Search",
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Library.Scheme.Font,
		PlaceholderColor3 = Library:GetShade(Library.Scheme.FontColor, -0.4),
		PlaceholderText = "Search...",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 26),
		Text = "",
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 12,
		ZIndex = 13,
		Parent = Sidebar,
	})
	Corner(SearchBox, Library.CornerRadius - 1)
	Padding(SearchBox, 0, 0, 10, 10)
	Library:AddToRegistry(SearchBox, { BackgroundColor3 = "BackgroundColor", TextColor3 = "FontColor", Font = "Font" })
	local SearchStroke = Stroke(SearchBox, Library.Scheme.OutlineColor, 1, 0)
	Library:AddToRegistry(SearchStroke, { Color = "OutlineColor" })

	local TabList = New("ScrollingFrame", {
		Name = "Tabs",
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		Position = UDim2.fromOffset(0, 46),
		ScrollBarImageColor3 = Library.Scheme.AccentColor,
		ScrollBarThickness = 2,
		Size = UDim2.new(1, 0, 1, -46),
		ZIndex = 12,
		Parent = Sidebar,
	})
	Library:AddToRegistry(TabList, { ScrollBarImageColor3 = "AccentColor" })
	Padding(TabList, 8, 8, 8, 8)
	ListLayout(TabList, Config.TabPadding or 4)

	local TabIndicator = New("Frame", {
		Name = "Indicator",
		BackgroundColor3 = Library.Scheme.AccentColor,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 34),
		Visible = false,
		ZIndex = 12,
		Parent = TabList,
	})
	Corner(TabIndicator, Library.CornerRadius - 1)
	Library:AddToRegistry(TabIndicator, { BackgroundColor3 = "AccentColor" })

	local IndicatorBar = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Library.Scheme.AccentColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 3, 0.6, 0),
		ZIndex = 13,
		Parent = TabIndicator,
	})
	Corner(IndicatorBar, 2)
	Library:AddToRegistry(IndicatorBar, { BackgroundColor3 = "AccentColor" })

	local Content = New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(SidebarWidth, 40),
		Size = UDim2.new(1, -SidebarWidth, 1, -40 - FooterHeight),
		ZIndex = 11,
		Parent = Main,
	})

	local Footer
	if FooterHeight > 0 then
		Footer = New("TextLabel", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Library.Scheme.MainColor,
			BorderSizePixel = 0,
			Font = Library.Scheme.Font,
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, FooterHeight),
			Text = "  " .. tostring(Config.Footer),
			TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.3),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
			Parent = Main,
		})
		Corner(Footer, Library.CornerRadius + 2)
		Library:AddToRegistry(Footer, { BackgroundColor3 = "MainColor", Font = "Font" })

		local Version = New("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Font = Library.Scheme.Font,
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(120, FooterHeight),
			Text = "OzionUI v" .. Library.Version,
			TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.45),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 12,
			Parent = Footer,
		})
		Library:AddToRegistry(Version, { Font = "Font" })
	end

	------------------------------------------------------------- resizing --
	local ResizeGrip
	if Config.Resizable ~= false then
		ResizeGrip = New("TextButton", {
			Name = "Resize",
			AnchorPoint = Vector2.new(1, 1),
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(18, 18),
			Text = "◢",
			TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.45),
			TextSize = 12,
			ZIndex = 30,
			Parent = Main,
		})

		local Resizing = false
		local ResizeStart, StartSize

		Library:Connect(ResizeGrip.InputBegan, function(Input)
			if
				Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				Resizing = true
				ResizeStart = Input.Position
				StartSize = Main.Size
				Library:Tween(ResizeGrip, { TextColor3 = Library.Scheme.AccentColor }, 0.15, "Smooth")
			end
		end)

		Library:Connect(UserInputService.InputEnded, function(Input)
			if
				Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				if Resizing then
					Resizing = false
					Library:Tween(ResizeGrip, {
						TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.45),
					}, 0.15, "Smooth")
				end
			end
		end)

		Library:Connect(UserInputService.InputChanged, function(Input)
			if not Resizing then
				return
			end
			if
				Input.UserInputType ~= Enum.UserInputType.MouseMovement
				and Input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local Delta = Input.Position - ResizeStart
			Main.Size = UDim2.fromOffset(
				math.max(StartSize.X.Offset + Delta.X, MinSize.X),
				math.max(StartSize.Y.Offset + Delta.Y, MinSize.Y)
			)
		end)
	end

	Library:MakeDraggable(Main, TitleBar)

	--------------------------------------------------------- window object --
	local Window = {
		Holder = Main,
		Main = Main,
		TitleBar = TitleBar,
		Sidebar = Sidebar,
		Content = Content,
		TabList = TabList,
		Tabs = {},
		TabCount = 0,
		ActiveTab = nil,
		Locked = false,
	}
	Library.Window = Window

	local TabHeight = 34
	local TabPadding = Config.TabPadding or 4

	local function MoveIndicator(Index, Instant)
		TabIndicator.Visible = true
		local Goal = UDim2.fromOffset(8, 8 + (Index - 1) * (TabHeight + TabPadding))
		if Instant then
			TabIndicator.Position = Goal
		else
			Library:Tween(TabIndicator, { Position = Goal }, 0.35, "Snappy")
		end
	end

	function Window:AddTab(Name, Icon)
		Window.TabCount = Window.TabCount + 1
		local TabIndex = Window.TabCount

		---------------------------------------------------------- button --
		local Button = New("TextButton", {
			Name = "Tab_" .. tostring(Name),
			AutoButtonColor = false,
			BackgroundColor3 = Library.Scheme.AccentColor,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = TabIndex,
			Size = UDim2.new(1, 0, 0, TabHeight),
			Text = "",
			ZIndex = 14,
			Parent = TabList,
		})
		Corner(Button, Library.CornerRadius - 1)
		Library:AddToRegistry(Button, { BackgroundColor3 = "AccentColor" })

		local TextStart = 12
		local Image, Glyph = Library:GetIcon(Icon)
		local IconObject
		if Image then
			IconObject = New("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Image = Image,
				ImageColor3 = Library:GetShade(Library.Scheme.FontColor, -0.3),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				ZIndex = 15,
				Parent = Button,
			})
			TextStart = 36
		elseif Glyph then
			IconObject = New("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				Text = Glyph,
				TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.3),
				TextSize = 15,
				ZIndex = 15,
				Parent = Button,
			})
			TextStart = 36
		end

		local Label = New("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Font = Library.Scheme.Font,
			Position = UDim2.new(0, TextStart, 0.5, 0),
			Size = UDim2.new(1, -TextStart - 8, 1, 0),
			Text = tostring(Name),
			TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.3),
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15,
			Parent = Button,
		})
		Library:AddToRegistry(Label, { Font = "Font" })

		------------------------------------------------------------ page --
		local Page
		local Ok = pcall(function()
			Page = New("CanvasGroup", {
				Name = "Page_" .. tostring(Name),
				BackgroundTransparency = 1,
				GroupTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Visible = false,
				ZIndex = 12,
				Parent = Content,
			})
		end)
		if not Ok or not Page then
			Page = New("Frame", {
				Name = "Page_" .. tostring(Name),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Visible = false,
				ZIndex = 12,
				Parent = Content,
			})
		end
		local SupportsFade = Ok

		local WarningBox = New("Frame", {
			Name = "Warning",
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Library.Scheme.MainColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.new(1, -24, 0, 0),
			Visible = false,
			ZIndex = 14,
			Parent = Page,
		})
		Corner(WarningBox, Library.CornerRadius)
		Library:AddToRegistry(WarningBox, { BackgroundColor3 = "MainColor" })
		local WarningStroke = Stroke(WarningBox, Library.Scheme.Red, 1, 0.2)
		Library:AddToRegistry(WarningStroke, { Color = "Red" })
		Padding(WarningBox, 8, 8, 10, 10)
		ListLayout(WarningBox, 2)

		local WarningTitle = New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Size = UDim2.new(1, 0, 0, 15),
			Text = "Warning",
			TextColor3 = Library.Scheme.Red,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15,
			Parent = WarningBox,
		})
		Library:AddToRegistry(WarningTitle, { TextColor3 = "Red" })

		local WarningText = New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Library.Scheme.Font,
			Size = UDim2.new(1, 0, 0, 0),
			Text = "",
			TextColor3 = Library.Scheme.FontColor,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15,
			Parent = WarningBox,
		})
		Library:AddToRegistry(WarningText, { TextColor3 = "FontColor", Font = "Font" })

		local Columns = New("Frame", {
			Name = "Columns",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 12,
			Parent = Page,
		})

		local function MakeColumn(Side)
			local Column = New("ScrollingFrame", {
				Name = Side,
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromScale(0, 0),
				Position = Side == "Left" and UDim2.fromScale(0, 0) or UDim2.new(0.5, 3, 0, 0),
				ScrollBarImageColor3 = Library.Scheme.AccentColor,
				ScrollBarImageTransparency = 0.4,
				ScrollBarThickness = 3,
				Size = UDim2.new(0.5, -3, 1, 0),
				ZIndex = 12,
				Parent = Columns,
			})
			Library:AddToRegistry(Column, { ScrollBarImageColor3 = "AccentColor" })
			Padding(Column, 12, 12, 12, 8)
			ListLayout(Column, 10)
			return Column
		end

		local Left = MakeColumn("Left")
		local Right = MakeColumn("Right")

		local Tab = {
			Name = Name,
			Index = TabIndex,
			Button = Button,
			Page = Page,
			Left = Left,
			Right = Right,
			Groupboxes = {},
			Window = Window,
		}

		function Tab:Show(Instant)
			if Window.Locked and not Tab.IsKeyTab then
				return Tab
			end

			for _, Other in pairs(Window.Tabs) do
				if Other ~= Tab then
					Other.Page.Visible = false
					Library:Tween(Other.Button, { BackgroundTransparency = 1 }, 0.2, "Smooth")
					Library:Tween(Other.Label, {
						TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.3),
					}, 0.2, "Smooth")
					if Other.IconObject then
						local Property = Other.IconObject:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
						Library:Tween(Other.IconObject, {
							[Property] = Library:GetShade(Library.Scheme.FontColor, -0.3),
						}, 0.2, "Smooth")
					end
				end
			end

			Window.ActiveTab = Tab
			Library.ActiveTab = Tab
			Page.Visible = true

			Library:Tween(Label, { TextColor3 = Library.Scheme.FontColor }, 0.25, "Smooth")
			if IconObject then
				local Property = IconObject:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
				Library:Tween(IconObject, { [Property] = Library.Scheme.AccentColor }, 0.25, "Smooth")
			end
			MoveIndicator(TabIndex, Instant)

			if SupportsFade then
				Page.GroupTransparency = Instant and 0 or 1
				if not Instant then
					Library:Tween(Page, { GroupTransparency = 0 }, 0.3, "Smooth")
				end
			end

			Columns.Position = UDim2.fromOffset(Instant and 0 or 18, Columns.Position.Y.Offset)
			if not Instant then
				Library:Tween(
					Columns,
					{ Position = UDim2.fromOffset(0, Columns.Position.Y.Offset) },
					0.35,
					"Snappy"
				)
			end
			return Tab
		end

		Tab.Label = Label
		Tab.IconObject = IconObject

		function Tab:UpdateWarningBox(Info)
			Info = Info or {}
			if Info.Title then
				WarningTitle.Text = tostring(Info.Title)
			end
			if Info.Text then
				WarningText.Text = tostring(Info.Text)
			end
			local Visible = Info.Visible
			if Visible == nil then
				Visible = true
			end
			WarningBox.Visible = Visible and true or false

			local Offset = 0
			if WarningBox.Visible then
				Offset = math.max(WarningBox.AbsoluteSize.Y, 48) + 18
			end
			Library:Tween(Columns, {
				Position = UDim2.fromOffset(0, Offset),
				Size = UDim2.new(1, 0, 1, -Offset),
			}, 0.3, "Smooth")
			return Tab
		end

		local function AddGroupbox(Side, Title, Icon)
			local Groupbox = NewGroupbox(Side == "Left" and Left or Right, Title, Icon, #Tab.Groupboxes + 1)
			table.insert(Tab.Groupboxes, Groupbox)
			return Groupbox
		end

		function Tab:AddLeftGroupbox(Title, Icon)
			return AddGroupbox("Left", Title, Icon)
		end

		function Tab:AddRightGroupbox(Title, Icon)
			return AddGroupbox("Right", Title, Icon)
		end

		function Tab:AddLeftTabbox()
			local Tabbox = NewTabbox(Left, #Tab.Groupboxes + 1)
			table.insert(Tab.Groupboxes, Tabbox)
			return Tabbox
		end

		function Tab:AddRightTabbox()
			local Tabbox = NewTabbox(Right, #Tab.Groupboxes + 1)
			table.insert(Tab.Groupboxes, Tabbox)
			return Tabbox
		end

		function Tab:SetVisible(Visible)
			Button.Visible = Visible and true or false
			return Tab
		end

		Library:Connect(Button.MouseButton1Click, function()
			local Mouse = Library:GetMouse()
			Library:Ripple(Button, Mouse.X, Mouse.Y)
			Tab:Show()
		end)

		Library:Connect(Button.MouseEnter, function()
			if Window.ActiveTab ~= Tab then
				Library:Tween(Button, { BackgroundTransparency = 0.92 }, 0.15, "Smooth")
				Library:Tween(Label, { TextColor3 = Library.Scheme.FontColor }, 0.15, "Smooth")
			end
		end)
		Library:Connect(Button.MouseLeave, function()
			if Window.ActiveTab ~= Tab then
				Library:Tween(Button, { BackgroundTransparency = 1 }, 0.2, "Smooth")
				Library:Tween(Label, {
					TextColor3 = Library:GetShade(Library.Scheme.FontColor, -0.3),
				}, 0.2, "Smooth")
			end
		end)

		table.insert(Window.Tabs, Tab)
		Library.Tabs[Name] = Tab

		if #Window.Tabs == 1 then
			Tab:Show(true)
		end

		return Tab
	end

	function Window:AddKeyTab(Name)
		local Tab = Window:AddTab(Name or "Key System", "key")
		Tab.IsKeyTab = true
		Window.Locked = true

		for _, Other in pairs(Window.Tabs) do
			if Other ~= Tab then
				Other.Button.Visible = false
			end
		end
		Tab:Show(true)

		function Tab:Unlock()
			Window.Locked = false
			Tab.Button.Visible = false
			for _, Other in pairs(Window.Tabs) do
				if Other ~= Tab then
					Other.Button.Visible = true
				end
			end
			local First = Window.Tabs[1] ~= Tab and Window.Tabs[1] or Window.Tabs[2]
			if First then
				First:Show()
			end
			return Tab
		end

		Window.Unlock = function()
			return Tab:Unlock()
		end

		return Tab
	end

	---------------------------------------------------------------- search --
	Library:Connect(SearchBox:GetPropertyChangedSignal("Text"), function()
		local Query = string.lower(SearchBox.Text)
		local Tab = Window.ActiveTab
		if not Tab then
			return
		end

		for _, Groupbox in pairs(Tab.Groupboxes) do
			local Containers = Groupbox.Tabs or { Groupbox }
			local AnyVisible = false

			for _, Box in pairs(Containers) do
				for _, Element in pairs(Box.Elements or {}) do
					if Element.Holder then
						local Match = Query == ""
							or (Element.SearchText and string.find(Element.SearchText, Query, 1, true) ~= nil)
						Element.Holder.Visible = Match and (Element.Visible ~= false)
						if Match then
							AnyVisible = true
						end
					end
				end
			end

			if Groupbox.Holder then
				Groupbox.Holder.Visible = Query == "" or AnyVisible
			end
		end
	end)

	Library:Connect(SearchBox.Focused, function()
		Library:Tween(SearchStroke, { Color = Library.Scheme.AccentColor }, 0.2, "Smooth")
	end)
	Library:Connect(SearchBox.FocusLost, function()
		Library:Tween(SearchStroke, { Color = Library.Scheme.OutlineColor }, 0.2, "Smooth")
	end)

	----------------------------------------------------------------- misc --
	function Window:SetTitle(NewTitle)
		TitleLabel.Text = tostring(NewTitle)
		return Window
	end

	function Window:SetFooter(NewFooter)
		if Footer then
			Footer.Text = "  " .. tostring(NewFooter)
		end
		return Window
	end

	function Window:SetSize(NewSize)
		Library:Tween(Main, { Size = NewSize }, 0.3, "Snappy")
		return Window
	end

	function Window:Toggle(State)
		return Library:Toggle(State)
	end

	function Window:Destroy()
		Library:Unload()
	end

	Window.Hide = function()
		return Library:Toggle(false)
	end
	Window.Show = function()
		return Library:Toggle(true)
	end

	----------------------------------------------------------- mobile bits --
	if Library.IsMobile or Config.ForceMobileButton then
		local MobileButton = New("TextButton", {
			Name = "MobileToggle",
			AutoButtonColor = false,
			BackgroundColor3 = Library.Scheme.AccentColor,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(18, 120),
			Size = UDim2.fromOffset(46, 46),
			Text = "☰",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 20,
			ZIndex = 950,
			Parent = Gui,
		})
		New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = MobileButton })
		Library:AddToRegistry(MobileButton, { BackgroundColor3 = "AccentColor" })
		Library:MakeDraggable(MobileButton, MobileButton)

		local Moved = false
		Library:Connect(MobileButton.MouseButton1Click, function()
			if not Moved then
				Library:Toggle()
			end
		end)

		Library.MobileButton = MobileButton
	end

	Library:CreateCursor()
	Library:CreateNotificationArea()

	----------------------------------------------------------- show / hide --
	Library.MainFrame = Main
	Library.MenuFadeTime = Config.MenuFadeTime or 0.25

	if Config.ToggleKeybind then
		Library.MenuKeybind = Config.ToggleKeybind
	end

	if Config.AutoShow ~= false then
		Library:Delay(0.05, function()
			Library:Toggle(true)
		end)
	end

	return Window
end

--//////////////////////////////////////////////////////////////////////////
--// Show / hide                                                          //
--//////////////////////////////////////////////////////////////////////////

local function SetMouseIcon(Enabled)
	pcall(function()
		UserInputService.MouseIconEnabled = Enabled
	end)
end

function Library:Toggle(State)
	local Main = Library.MainFrame
	if not Main then
		return
	end

	if State == nil then
		State = not Library.Toggled
	end
	State = State and true or false
	if State == Library.Toggled then
		return State
	end

	Library.Toggled = State
	local Duration = Library.MenuFadeTime or 0.25
	local Scale = Library.MainScale

	-- close any floating popups when hiding
	if not State then
		for Index = #Library.OpenedFrames, 1, -1 do
			local Frame = Library.OpenedFrames[Index]
			if Frame.Toggle then
				Frame:Toggle(false)
			end
		end
	end

	if State then
		Main.Visible = true
		if Scale then
			Scale.Scale = Library.DPIScale * 0.9
			Library:Tween(Scale, { Scale = Library.DPIScale }, Duration + 0.15, "Snappy")
		end
		Main.BackgroundTransparency = 1
		Library:Tween(Main, { BackgroundTransparency = 0 }, Duration, "Smooth")
		Library:SetBlur(true)
		if Library.ShowCustomCursor and not Library.IsMobile then
			SetMouseIcon(false)
		end
	else
		if Scale then
			Library:Tween(Scale, { Scale = Library.DPIScale * 0.92 }, Duration, "Smooth")
		end
		Library:Tween(Main, { BackgroundTransparency = 1 }, Duration, "Smooth")
		Library:SetBlur(false)
		SetMouseIcon(true)
		Library:Delay(Duration * (Library.AnimationSpeed or 1), function()
			if not Library.Toggled then
				Main.Visible = false
				if Scale then
					Scale.Scale = Library.DPIScale
				end
			end
		end)
	end

	return State
end

function Library:SetVisible(State)
	return Library:Toggle(State)
end

--//////////////////////////////////////////////////////////////////////////
--// Global input                                                         //
--//////////////////////////////////////////////////////////////////////////

local function PointInside(Object, Point)
	if not Object or not Object.Parent then
		return false
	end
	local Position = Object.AbsolutePosition
	local Size = Object.AbsoluteSize
	return Point.X >= Position.X
		and Point.X <= Position.X + Size.X
		and Point.Y >= Position.Y
		and Point.Y <= Position.Y + Size.Y
end

Library:Connect(UserInputService.InputBegan, function(Input, Processed)
	-- click outside an open dropdown / colour picker closes it
	if
		Input.UserInputType == Enum.UserInputType.MouseButton1
		or Input.UserInputType == Enum.UserInputType.Touch
	then
		local Mouse = Library:GetMouse()
		for Index = #Library.OpenedFrames, 1, -1 do
			local Frame = Library.OpenedFrames[Index]
			local Inside = PointInside(Frame.Popup, Mouse) or PointInside(Frame.Holder, Mouse)
			if not Inside and Frame.Toggle then
				Frame:Toggle(false)
			end
		end
	end

	if Input.KeyCode == Enum.KeyCode.Escape then
		for Index = #Library.OpenedFrames, 1, -1 do
			local Frame = Library.OpenedFrames[Index]
			if Frame.Toggle then
				Frame:Toggle(false)
			end
		end
	end

	if Processed or IsTyping() then
		return
	end

	-- menu keybind
	local Bind = Library.ToggleKeybind
	if type(Bind) == "table" and Bind.Value then
		if KeyNameMatches(Input, Bind.Value) then
			Library:Toggle()
		end
		return
	end

	local Menu = Library.MenuKeybind
	if Menu == nil then
		return
	end
	if type(Menu) == "string" then
		if InputToKeyName(Input) == Menu then
			Library:Toggle()
		end
	elseif Input.KeyCode == Menu then
		Library:Toggle()
	end
end)

--//////////////////////////////////////////////////////////////////////////
--// Extra helpers (Obsidian compatible)                                  //
--//////////////////////////////////////////////////////////////////////////

function Library:AddDraggableButton(Text, Callback)
	local Gui = Library:GetScreenGui()

	local Button = New("TextButton", {
		Name = "DraggableButton",
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(30, 220),
		Size = UDim2.fromOffset(120, 34),
		Text = tostring(Text or "Button"),
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 13,
		ZIndex = 940,
		Parent = Gui,
	})
	Corner(Button, Library.CornerRadius)
	Library:AddToRegistry(Button, { BackgroundColor3 = "MainColor", TextColor3 = "FontColor" }, true)
	local ButtonStroke = Stroke(Button, Library.Scheme.AccentColor, 1, 0.2)
	Library:AddToRegistry(ButtonStroke, { Color = "AccentColor" }, true)

	Library:MakeDraggable(Button, Button)
	Library:Connect(Button.MouseButton1Click, function()
		local Mouse = Library:GetMouse()
		Library:Ripple(Button, Mouse.X, Mouse.Y)
		Library:SafeCallback(Callback)
	end)

	return {
		Button = Button,
		SetText = function(_, NewText)
			Button.Text = tostring(NewText)
		end,
		SetVisible = function(_, Visible)
			Button.Visible = Visible and true or false
		end,
		Destroy = function()
			Button:Destroy()
		end,
	}
end

function Library:AddDraggableMenu(Name)
	local Gui = Library:GetScreenGui()

	local Holder = New("Frame", {
		Name = "DraggableMenu",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Library.Scheme.MainColor,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(30, 280),
		Size = UDim2.fromOffset(220, 0),
		ZIndex = 930,
		Parent = Gui,
	})
	Corner(Holder, Library.CornerRadius)
	Library:AddToRegistry(Holder, { BackgroundColor3 = "MainColor" }, true)
	local HolderStroke = Stroke(Holder, Library.Scheme.OutlineColor, 1, 0.1)
	Library:AddToRegistry(HolderStroke, { Color = "OutlineColor" }, true)

	local TitleBar = New("TextLabel", {
		BackgroundColor3 = Library.Scheme.BackgroundColor,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, 28),
		Text = tostring(Name or "Menu"),
		TextColor3 = Library.Scheme.FontColor,
		TextSize = 13,
		ZIndex = 932,
		Parent = Holder,
	})
	Corner(TitleBar, Library.CornerRadius)
	Library:AddToRegistry(TitleBar, { BackgroundColor3 = "BackgroundColor", TextColor3 = "FontColor" }, true)

	local Container = New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 932,
		Parent = Holder,
	})
	Padding(Container, 10, 12, 12, 12)
	ListLayout(Container, 7)

	Library:MakeDraggable(Holder, TitleBar)

	local Menu = setmetatable({
		Type = "Groupbox",
		Holder = Holder,
		Container = Container,
		Elements = {},
	}, ElementFuncs)
	Menu.Groupbox = Menu
	function Menu:Resize()
		return Menu
	end
	return Menu
end

--//////////////////////////////////////////////////////////////////////////
--// Unloading                                                            //
--//////////////////////////////////////////////////////////////////////////

function Library:OnUnload(Callback)
	table.insert(Library.UnloadCallbacks, Callback)
	return Callback
end

function Library:Unload()
	if Library.Unloaded then
		return
	end

	for _, Callback in pairs(Library.UnloadCallbacks) do
		pcall(Callback)
	end

	Library.Unloaded = true
	Library.Toggled = false

	for _, Connection in pairs(Library.Connections) do
		pcall(function()
			Connection:Disconnect()
		end)
	end
	Library.Connections = {}

	SetMouseIcon(true)

	if Library.BlurEffect then
		pcall(function()
			Library.BlurEffect:Destroy()
		end)
		Library.BlurEffect = nil
	end

	if Library.ScreenGui then
		pcall(function()
			Library.ScreenGui:Destroy()
		end)
	end

	Library.ScreenGui = nil
	Library.Window = nil
	Library.MainFrame = nil
	Library.Watermark = nil
	Library.KeybindFrame = nil
	Library.NotificationArea = nil
	Library.TooltipHolder = nil
	Library.Cursor = nil
	Library.MainScale = nil
	Library.PopupLayer = nil
	Library.Registry = {}
	Library.HudRegistry = {}
	Library.OpenedFrames = {}
	Library.DependencyBoxes = {}
	Library.Notifications = {}
	Library.Tabs = {}
	Library.ScaleObjects = {}

	for Key in pairs(Toggles) do
		Toggles[Key] = nil
	end
	for Key in pairs(Options) do
		Options[Key] = nil
	end

	if type(getgenv) == "function" then
		pcall(function()
			getgenv().OzionUI = nil
		end)
	end
end

Library.Destroy = Library.Unload

--//////////////////////////////////////////////////////////////////////////

return Library
