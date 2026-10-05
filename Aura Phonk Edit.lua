--[[
	DevUI  -  a small UI library in ONE LocalScript
	Place in: StarterPlayer > StarterPlayerScripts

	Part 1 is the library (UI:CreateWindow ...).
	Part 2 at the bottom is a demo that uses it. Delete the demo section and
	add `return UI` at the end if you want to turn Part 1 into a ModuleScript.

	API
	  local Window = UI:CreateWindow({ Title, Subtitle, Accent, ToggleKey, Size })
	  local Tab    = Window:AddTab("Name")
	  Tab:AddSection("Title")
	  Tab:AddLabel("text")                              -> { SetText }
	  Tab:AddButton({ Text, Callback })
	  Tab:AddToggle({ Text, Default, Callback })        -> { Set, Get }
	  Tab:AddSlider({ Text, Min, Max, Default, Step, Suffix, Callback }) -> { Set, Get }
	  Tab:AddDropdown({ Text, Options, Default, Callback }) -> { Set, Get, SetOptions }
	  Tab:AddTextbox({ Text, Placeholder, Default, Callback })
	  Tab:AddKeybind({ Text, Default, Callback })       -> { Set, Get }
	  Window:AddSettingsTab()      accent color, toggle key, unload button
	  Window:Notify({ Title, Text, Duration })
	  Window:SetAccent(Color3)  Window:Toggle(bool?)  Window:Destroy()
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

--====================================================================
-- PART 1: LIBRARY
--====================================================================
local UI = {}

local THEME = {
	bg = Color3.fromRGB(22, 22, 28),
	panel = Color3.fromRGB(32, 32, 42),
	item = Color3.fromRGB(44, 44, 58),
	text = Color3.fromRGB(235, 235, 245),
	sub = Color3.fromRGB(150, 150, 170),
	off = Color3.fromRGB(70, 70, 88),
}

local FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OPEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function new(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(inst, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, inst)
end

local orderCounters = setmetatable({}, { __mode = "k" })
local function nextOrder(parent)
	local n = (orderCounters[parent] or 0) + 1
	orderCounters[parent] = n
	return n
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab

----------------------------------------------------------------------
-- Window internals
----------------------------------------------------------------------
function Window:_connect(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(self._connections, conn)
	return conn
end

-- Registers a function that gets called now and whenever the accent changes.
function Window:_onAccent(fn)
	table.insert(self._accentFns, fn)
	fn(self.Accent)
end

function Window:_restyleTabs()
	for _, tab in ipairs(self.Tabs) do
		tab.Button.BackgroundColor3 = (tab == self.ActiveTab) and self.Accent or THEME.panel
	end
end

function Window:SetAccent(color)
	self.Accent = color
	for _, fn in ipairs(self._accentFns) do
		fn(color)
	end
end

function Window:Toggle(open)
	if open == nil then
		open = not self.Open
	end
	self.Open = open
	if self._tweenA then self._tweenA:Cancel() end
	if self._tweenB then self._tweenB:Cancel() end
	local info = open and OPEN or CLOSE
	if open then
		self.Main.Visible = true
	end
	self._tweenA = TweenService:Create(self.Main, info, { GroupTransparency = open and 0 or 1 })
	self._tweenB = TweenService:Create(self._scale, info, { Scale = open and 1 or 0.9 })
	self._tweenA:Play()
	self._tweenB:Play()
	if not open then
		task.delay(CLOSE.Time, function()
			if not self.Open and self.Main.Parent then
				self.Main.Visible = false
			end
		end)
	end
end

function Window:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	table.clear(self._connections)
	self.Gui:Destroy()
end

function Window:Notify(opts)
	opts = opts or {}
	local toast = new("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.panel,
		GroupTransparency = 1,
		LayoutOrder = nextOrder(self.NotifyHolder),
	}, self.NotifyHolder)
	corner(toast, 8)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
	}, toast)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, toast)
	local title = new("TextLabel", {
		LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = self.Accent, Text = opts.Title or "Notice",
	}, toast)
	self:_onAccent(function(c)
		if title.Parent then title.TextColor3 = c end
	end)
	new("TextLabel", {
		LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = THEME.text, Text = opts.Text or "",
	}, toast)

	TweenService:Create(toast, FAST, { GroupTransparency = 0 }):Play()
	task.delay(opts.Duration or 4, function()
		if not toast.Parent then return end
		local out = TweenService:Create(toast, FAST, { GroupTransparency = 1 })
		out:Play()
		out.Completed:Wait()
		toast:Destroy()
	end)
end

function Window:AddTab(name)
	local tab = setmetatable({ Window = self, Name = name }, Tab)

	tab.Button = new("TextButton", {
		LayoutOrder = #self.Tabs + 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.panel,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.text, Text = name,
	}, self.TabBar)
	corner(tab.Button, 6)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, tab.Button)

	tab.Page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), Visible = false,
	}, self.Content)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tab.Page)
	new("UIPadding", { PaddingRight = UDim.new(0, 8) }, tab.Page)

	table.insert(self.Tabs, tab)
	tab.Button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)
	if not self.ActiveTab then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	self.ActiveTab = tab
	for _, t in ipairs(self.Tabs) do
		t.Page.Visible = (t == tab)
	end
	self:_restyleTabs()
end

----------------------------------------------------------------------
-- Tab controls
----------------------------------------------------------------------
local function makeRow(page, height)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = THEME.item,
		LayoutOrder = nextOrder(page),
	}, page)
	corner(row)
	return row
end

function Tab:AddSection(text)
	local win = self.Window
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = nextOrder(self.Page),
	}, self.Page)
	new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -4),
		Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.sub, Text = string.upper(text),
	}, holder)
	local line = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0,
	}, holder)
	win:_onAccent(function(c) line.BackgroundColor3 = c end)
end

function Tab:AddLabel(text)
	local label = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.text, Text = text, LayoutOrder = nextOrder(self.Page),
	}, self.Page)
	return { SetText = function(t) label.Text = t end }
end

function Tab:AddButton(o)
	local button = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = THEME.item, AutoButtonColor = false,
		Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = THEME.text, Text = o.Text or "Button",
		LayoutOrder = nextOrder(self.Page),
	}, self.Page)
	corner(button)
	button.MouseButton1Click:Connect(function()
		button.BackgroundColor3 = self.Window.Accent
		TweenService:Create(button, FAST, { BackgroundColor3 = THEME.item }):Play()
		if o.Callback then
			task.spawn(o.Callback)
		end
	end)
end

function Tab:AddToggle(o)
	local win = self.Window
	local row = makeRow(self.Page, 34)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -64, 1, 0),
		Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.text, Text = o.Text or "Toggle",
	}, row)
	local pill = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(40, 20), BackgroundColor3 = THEME.off,
	}, row)
	corner(pill, 10)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(16, 16), BackgroundColor3 = THEME.text,
	}, pill)
	corner(knob, 8)

	local state = o.Default == true
	local function render()
		TweenService:Create(pill, FAST, { BackgroundColor3 = state and win.Accent or THEME.off }):Play()
		TweenService:Create(knob, FAST, {
			Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
		}):Play()
	end
	win:_onAccent(render)

	local hit = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "" }, row)
	hit.MouseButton1Click:Connect(function()
		state = not state
		render()
		if o.Callback then task.spawn(o.Callback, state) end
	end)

	return {
		Get = function() return state end,
		Set = function(value, silent)
			state = value == true
			render()
			if not silent and o.Callback then task.spawn(o.Callback, state) end
		end,
	}
end

function Tab:AddSlider(o)
	local win = self.Window
	local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
	local suffix = o.Suffix or ""
	local row = makeRow(self.Page, 52)
	local label = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 0, 20),
		Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.text,
	}, row)
	local track = new("Frame", {
		Position = UDim2.new(0, 10, 0, 34), Size = UDim2.new(1, -20, 0, 8), BackgroundColor3 = THEME.off,
	}, row)
	corner(track, 4)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1) }, track)
	corner(fill, 4)
	win:_onAccent(function(c) fill.BackgroundColor3 = c end)

	local value = math.clamp(o.Default or min, min, max)
	local function render()
		fill.Size = UDim2.fromScale(math.clamp((value - min) / (max - min), 0, 1), 1)
		label.Text = string.format("%s: %s%s", o.Text or "Slider", tostring(value), suffix)
	end
	render()

	local function setFromX(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = min + (max - min) * alpha
		v = math.floor(v / step + 0.5) * step
		value = math.clamp(math.floor(v * 1000 + 0.5) / 1000, min, max)
		render()
		if o.Callback then task.spawn(o.Callback, value) end
	end

	local dragging = false
	track.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	win:_connect(UserInputService.InputChanged, function(input)
		if dragging and isMove(input) then setFromX(input.Position.X) end
	end)
	win:_connect(UserInputService.InputEnded, function(input)
		if isPress(input) then dragging = false end
	end)

	return {
		Get = function() return value end,
		Set = function(v, silent)
			value = math.clamp(v, min, max)
			render()
			if not silent and o.Callback then task.spawn(o.Callback, value) end
		end,
	}
end

function Tab:AddDropdown(o)
	local win = self.Window
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.item, LayoutOrder = nextOrder(self.Page),
	}, self.Page)
	corner(holder)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, holder)

	local header = new("TextButton", {
		LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "",
	}, holder)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0.5, -10, 1, 0),
		Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.text, Text = o.Text or "Dropdown",
	}, header)
	local valueLabel = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -10, 1, 0),
		Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = THEME.sub, Text = "-",
	}, header)

	local list = new("Frame", {
		LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Visible = false,
	}, holder)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
	}, list)

	local selected = nil
	local optionButtons = {}

	local function refreshHighlight()
		for name, btn in pairs(optionButtons) do
			btn.TextColor3 = (name == selected) and win.Accent or THEME.text
		end
		valueLabel.Text = selected ~= nil and tostring(selected) or "-"
	end
	win:_onAccent(refreshHighlight)

	local function choose(name, silent)
		selected = name
		refreshHighlight()
		if not silent and o.Callback then task.spawn(o.Callback, name) end
	end

	local function setOptions(options)
		for _, btn in pairs(optionButtons) do btn:Destroy() end
		table.clear(optionButtons)
		for index, name in ipairs(options) do
			local btn = new("TextButton", {
				LayoutOrder = index, Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = THEME.panel,
				AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 13,
				TextColor3 = THEME.text, Text = tostring(name),
			}, list)
			corner(btn, 6)
			btn.MouseButton1Click:Connect(function()
				choose(name)
				list.Visible = false
			end)
			optionButtons[name] = btn
		end
		if selected ~= nil and not optionButtons[selected] then
			selected = nil
		end
		refreshHighlight()
	end

	header.MouseButton1Click:Connect(function()
		list.Visible = not list.Visible
	end)

	setOptions(o.Options or {})
	if o.Default ~= nil then choose(o.Default, true) end

	return {
		Get = function() return selected end,
		Set = function(name, silent) choose(name, silent) end,
		SetOptions = setOptions,
	}
end

function Tab:AddTextbox(o)
	local row = makeRow(self.Page, 34)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0.4, -10, 1, 0),
		Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.text, Text = o.Text or "Textbox",
	}, row)
	local box = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.new(0.6, -12, 0, 24), BackgroundColor3 = THEME.panel,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = THEME.text,
		PlaceholderText = o.Placeholder or "", PlaceholderColor3 = THEME.sub,
		Text = o.Default or "", ClearTextOnFocus = false,
	}, row)
	corner(box, 6)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed and o.Callback then task.spawn(o.Callback, box.Text) end
	end)
	return {
		Get = function() return box.Text end,
		Set = function(t) box.Text = t end,
	}
end

function Tab:AddKeybind(o)
	local win = self.Window
	local row = makeRow(self.Page, 34)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -90, 1, 0),
		Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.text, Text = o.Text or "Keybind",
	}, row)
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(72, 24), BackgroundColor3 = THEME.panel, AutoButtonColor = false,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.text,
	}, row)
	corner(btn, 6)

	local key = o.Default
	local listening = false
	local function render()
		btn.Text = listening and "..." or (key and key.Name or "None")
	end
	render()

	btn.MouseButton1Click:Connect(function()
		listening = true
		render()
	end)

	win:_connect(UserInputService.InputBegan, function(input, processed)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				key = (input.KeyCode ~= Enum.KeyCode.Escape) and input.KeyCode or nil
				listening = false
				render()
				if o.Changed then task.spawn(o.Changed, key) end
			end
			return
		end
		if not processed and key and input.KeyCode == key and o.Callback then
			task.spawn(o.Callback)
		end
	end)

	return {
		Get = function() return key end,
		Set = function(k) key = k render() end,
	}
end

----------------------------------------------------------------------
-- Settings tab (accent, toggle key, unload)
----------------------------------------------------------------------
function Window:AddSettingsTab()
	local tab = self:AddTab("Settings")
	local presets = {
		Purple = Color3.fromRGB(120, 100, 255),
		Blue = Color3.fromRGB(70, 140, 255),
		Green = Color3.fromRGB(70, 200, 120),
		Red = Color3.fromRGB(235, 80, 90),
		Orange = Color3.fromRGB(245, 150, 60),
	}
	tab:AddSection("Appearance")
	tab:AddDropdown({
		Text = "Accent color",
		Options = { "Purple", "Blue", "Green", "Red", "Orange" },
		Default = "Purple",
		Callback = function(name)
			self:SetAccent(presets[name])
		end,
	})
	tab:AddSection("Controls")
	tab:AddKeybind({
		Text = "Toggle key",
		Default = self.ToggleKey,
		Changed = function(key)
			self.ToggleKey = key
		end,
	})
	tab:AddButton({ Text = "Unload UI", Callback = function() self:Destroy() end })
	return tab
end

----------------------------------------------------------------------
-- UI:CreateWindow
----------------------------------------------------------------------
function UI:CreateWindow(opts)
	opts = opts or {}
	local self = setmetatable({}, Window)
	self.Accent = opts.Accent or Color3.fromRGB(120, 100, 255)
	self.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightControl
	self.Tabs = {}
	self.Open = false
	self._connections = {}
	self._accentFns = {}

	self.Gui = new("ScreenGui", {
		Name = opts.Name or "DevUI", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
	}, player:WaitForChild("PlayerGui"))

	self.Main = new("CanvasGroup", {
		Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = opts.Size or UDim2.fromScale(0.42, 0.62), BackgroundColor3 = THEME.bg,
		GroupTransparency = 1, Visible = false,
	}, self.Gui)
	corner(self.Main, 12)
	new("UISizeConstraint", { MinSize = Vector2.new(320, 300), MaxSize = Vector2.new(560, 540) }, self.Main)
	self._scale = new("UIScale", { Scale = 0.9 }, self.Main)

	-- Title bar (drag handle)
	local titleBar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1,
	}, self.Main)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -60, 1, 0),
		Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.text,
		Text = (opts.Title or "DevUI") .. (opts.Subtitle and ("  |  " .. opts.Subtitle) or ""),
	}, titleBar)
	local closeBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(24, 24), BackgroundColor3 = THEME.panel, AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.text, Text = "X",
	}, titleBar)
	corner(closeBtn, 6)
	closeBtn.MouseButton1Click:Connect(function() self:Toggle(false) end)

	local dragging, dragStart, startPos = false, nil, nil
	titleBar.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging, dragStart, startPos = true, input.Position, self.Main.Position
		end
	end)
	self:_connect(UserInputService.InputChanged, function(input)
		if dragging and isMove(input) then
			local delta = input.Position - dragStart
			self.Main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
	self:_connect(UserInputService.InputEnded, function(input)
		if isPress(input) then dragging = false end
	end)

	-- Tabs + content
	self.TabBar = new("ScrollingFrame", {
		Position = UDim2.new(0, 10, 0, 40), Size = UDim2.new(1, -20, 0, 30), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
	}, self.Main)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.TabBar)

	self.Content = new("Frame", {
		Position = UDim2.new(0, 10, 0, 76), Size = UDim2.new(1, -20, 1, -86), BackgroundTransparency = 1,
	}, self.Main)

	-- Notifications (top right)
	self.NotifyHolder = new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(260, 400), BackgroundTransparency = 1,
	}, self.Gui)
	new("UIListLayout", {
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}, self.NotifyHolder)

	-- Floating button (handy on mobile)
	local fab = new("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(44, 44),
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.text, Text = "UI",
	}, self.Gui)
	corner(fab, 22)
	fab.MouseButton1Click:Connect(function() self:Toggle() end)

	self:_onAccent(function(c)
		fab.BackgroundColor3 = c
		self:_restyleTabs()
	end)

	self:_connect(UserInputService.InputBegan, function(input, processed)
		if not processed and self.ToggleKey and input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end)

	task.defer(function() self:Toggle(true) end)
	return self
end

--====================================================================
-- PART 2: DEMO  (delete everything below when you use the library)
--====================================================================
local Win = UI:CreateWindow({ Title = "DevUI", Subtitle = "demo" })

-- Component showcase
local Showcase = Win:AddTab("Components")
Showcase:AddSection("Buttons and toggles")
Showcase:AddButton({
	Text = "Show notification",
	Callback = function()
		Win:Notify({ Title = "Hello", Text = "Notifications stack and fade out on their own." })
	end,
})
Showcase:AddToggle({
	Text = "Example toggle",
	Default = true,
	Callback = function(on) print("[DevUI] toggle:", on) end,
})
Showcase:AddSection("Inputs")
Showcase:AddSlider({
	Text = "Example slider", Min = 0, Max = 100, Default = 40, Step = 5, Suffix = "%",
	Callback = function(v) print("[DevUI] slider:", v) end,
})
Showcase:AddDropdown({
	Text = "Example dropdown", Options = { "Alpha", "Beta", "Gamma" }, Default = "Alpha",
	Callback = function(v) print("[DevUI] dropdown:", v) end,
})
Showcase:AddTextbox({
	Text = "Example textbox", Placeholder = "type, press Enter",
	Callback = function(t) print("[DevUI] textbox:", t) end,
})
Showcase:AddKeybind({
	Text = "Example keybind", Default = Enum.KeyCode.F,
	Callback = function() Win:Notify({ Title = "Keybind", Text = "You pressed the bound key." }) end,
})

-- Dev tools: only exist in Studio playtests so they never ship to a live game
if RunService:IsStudio() then
	local Dev = Win:AddTab("Dev")
	local function getHumanoid()
		local character = player.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	Dev:AddSection("Character")
	Dev:AddSlider({
		Text = "Walk speed", Min = 8, Max = 100, Default = 16, Step = 1,
		Callback = function(v)
			local humanoid = getHumanoid()
			if humanoid then humanoid.WalkSpeed = v end
		end,
	})
	Dev:AddSlider({
		Text = "Jump power", Min = 20, Max = 200, Default = 50, Step = 5,
		Callback = function(v)
			local humanoid = getHumanoid()
			if humanoid then
				humanoid.UseJumpPower = true
				humanoid.JumpPower = v
			end
		end,
	})

	Dev:AddSection("Saved places")
	local places = {}
	local placeNames = {}
	local placeDropdown
	placeDropdown = Dev:AddDropdown({
		Text = "Place", Options = placeNames,
		Callback = function() end,
	})
	Dev:AddButton({
		Text = "Save current position",
		Callback = function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then return end
			local name = "Place " .. (#placeNames + 1)
			places[name] = root.CFrame
			table.insert(placeNames, name)
			placeDropdown.SetOptions(placeNames)
			placeDropdown.Set(name, true)
			Win:Notify({ Title = "Saved", Text = name .. " saved." })
		end,
	})
	Dev:AddButton({
		Text = "Go to selected place",
		Callback = function()
			local character = player.Character
			local target = places[placeDropdown.Get() or ""]
			if character and target then
				character:PivotTo(target)
			end
		end,
	})
end

Win:AddSettingsTab()
Win:Notify({ Title = "DevUI loaded", Text = "Press RightControl or the UI button to toggle." })
