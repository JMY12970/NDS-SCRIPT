-- OzionUI
-- A polished, dependency-free Roblox UI library.
-- Designed for LocalScripts and standard Roblox Studio projects.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local OzionUI = {
	Version = "1.0.0",
	Themes = {},
	Windows = {},
}

OzionUI.Themes.Obsidian = {
	Background = Color3.fromRGB(12, 13, 18),
	Surface = Color3.fromRGB(18, 19, 27),
	SurfaceAlt = Color3.fromRGB(24, 25, 35),
	SurfaceHover = Color3.fromRGB(31, 32, 44),
	Stroke = Color3.fromRGB(44, 46, 61),
	Text = Color3.fromRGB(241, 242, 248),
	Subtext = Color3.fromRGB(145, 148, 166),
	Accent = Color3.fromRGB(132, 91, 255),
	AccentAlt = Color3.fromRGB(64, 190, 255),
	Success = Color3.fromRGB(75, 219, 143),
	Warning = Color3.fromRGB(255, 190, 79),
	Danger = Color3.fromRGB(255, 91, 118),
}

OzionUI.Themes.Midnight = {
	Background = Color3.fromRGB(7, 14, 24),
	Surface = Color3.fromRGB(12, 23, 38),
	SurfaceAlt = Color3.fromRGB(17, 31, 49),
	SurfaceHover = Color3.fromRGB(23, 41, 63),
	Stroke = Color3.fromRGB(38, 62, 87),
	Text = Color3.fromRGB(236, 247, 255),
	Subtext = Color3.fromRGB(133, 158, 180),
	Accent = Color3.fromRGB(45, 151, 255),
	AccentAlt = Color3.fromRGB(45, 226, 196),
	Success = Color3.fromRGB(55, 214, 150),
	Warning = Color3.fromRGB(255, 187, 73),
	Danger = Color3.fromRGB(255, 90, 108),
}

OzionUI.Themes.Rose = {
	Background = Color3.fromRGB(19, 12, 18),
	Surface = Color3.fromRGB(29, 17, 27),
	SurfaceAlt = Color3.fromRGB(39, 23, 36),
	SurfaceHover = Color3.fromRGB(50, 29, 46),
	Stroke = Color3.fromRGB(70, 43, 64),
	Text = Color3.fromRGB(255, 239, 249),
	Subtext = Color3.fromRGB(183, 143, 169),
	Accent = Color3.fromRGB(255, 91, 174),
	AccentAlt = Color3.fromRGB(172, 103, 255),
	Success = Color3.fromRGB(80, 217, 149),
	Warning = Color3.fromRGB(255, 189, 77),
	Danger = Color3.fromRGB(255, 84, 103),
}

local DEFAULT_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local FAST_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING_TWEEN = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function create(className, properties, children)
	local instance = Instance.new(className)
	for key, value in pairs(properties or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if properties and properties.Parent then
		instance.Parent = properties.Parent
	end
	return instance
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function padding(parent, top, right, bottom, left)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or top or 0),
		PaddingBottom = UDim.new(0, bottom or top or 0),
		PaddingLeft = UDim.new(0, left or right or top or 0),
		Parent = parent,
	})
end

local function list(parent, gap, horizontal)
	return create("UIListLayout", {
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function tween(instance, info, properties)
	if not instance or not instance.Parent then
		return nil
	end
	local animation = TweenService:Create(instance, info or DEFAULT_TWEEN, properties)
	animation:Play()
	return animation
end

local function safeCall(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	local ok, message = pcall(callback, ...)
	if not ok then
		warn("[OzionUI] Callback error: " .. tostring(message))
	end
end

local function merge(base, supplied)
	local result = {}
	for key, value in pairs(base or {}) do
		result[key] = value
	end
	for key, value in pairs(supplied or {}) do
		result[key] = value
	end
	return result
end

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function round(value, increment)
	increment = increment or 1
	return math.floor((value / increment) + 0.5) * increment
end

local function slug(value)
	return string.lower(tostring(value or "control")):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
end

local function keyName(keyCode)
	local name = keyCode.Name
	local replacements = {
		LeftControl = "L-Ctrl",
		RightControl = "R-Ctrl",
		LeftShift = "L-Shift",
		RightShift = "R-Shift",
		LeftAlt = "L-Alt",
		RightAlt = "R-Alt",
		Backquote = "`",
		Return = "Enter",
	}
	return replacements[name] or name
end

local function colorToHex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function hexToColor(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) ~= "string" then
		return nil
	end
	local hex = value:gsub("#", "")
	if #hex ~= 6 then
		return nil
	end
	local number = tonumber(hex, 16)
	if not number then
		return nil
	end
	return Color3.fromRGB(math.floor(number / 65536) % 256, math.floor(number / 256) % 256, number % 256)
end

local function makeMaid()
	local maid = { tasks = {} }
	function maid:Give(task)
		table.insert(self.tasks, task)
		return task
	end
	function maid:Clean()
		for index = #self.tasks, 1, -1 do
			local task = self.tasks[index]
			if typeof(task) == "RBXScriptConnection" then
				task:Disconnect()
			elseif typeof(task) == "Instance" then
				task:Destroy()
			elseif type(task) == "function" then
				pcall(task)
			elseif type(task) == "table" and task.Destroy then
				pcall(function()
					task:Destroy()
				end)
			end
			table.remove(self.tasks, index)
		end
	end
	return maid
end

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

function OzionUI:RegisterTheme(name, colors)
	assert(type(name) == "string", "Theme name must be a string")
	assert(type(colors) == "table", "Theme colors must be a table")
	self.Themes[name] = merge(self.Themes.Obsidian, colors)
	return self
end

function Window:_theme(instance, property, token)
	if not instance then
		return
	end
	instance[property] = self.Theme[token]
	table.insert(self._themeBindings, {
		Instance = instance,
		Property = property,
		Token = token,
	})
end

function Window:_stroke(parent, token, transparency, thickness)
	local stroke = create("UIStroke", {
		Color = self.Theme[token or "Stroke"],
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	self:_theme(stroke, "Color", token or "Stroke")
	return stroke
end

function Window:_registerControl(options, control)
	control.Flag = options.Flag or slug(options.Title)
	if self._controlsByFlag[control.Flag] then
		local suffix = 2
		local original = control.Flag
		while self._controlsByFlag[control.Flag] do
			control.Flag = original .. "_" .. suffix
			suffix = suffix + 1
		end
	end
	self._controlsByFlag[control.Flag] = control
	self.Flags[control.Flag] = control:GetValue()
	return control
end

function Window:SetTheme(theme)
	local colors = theme
	if type(theme) == "string" then
		colors = OzionUI.Themes[theme]
	end
	assert(type(colors) == "table", "Unknown OzionUI theme")
	self.Theme = merge(OzionUI.Themes.Obsidian, colors)
	for index = #self._themeBindings, 1, -1 do
		local binding = self._themeBindings[index]
		if binding.Instance and binding.Instance.Parent then
			tween(binding.Instance, DEFAULT_TWEEN, {
				[binding.Property] = self.Theme[binding.Token],
			})
		else
			table.remove(self._themeBindings, index)
		end
	end
	for _, tab in ipairs(self.Tabs) do
		local selected = tab == self.SelectedTab
		tween(tab.TextLabel, FAST_TWEEN, { TextColor3 = selected and self.Theme.Text or self.Theme.Subtext })
		tween(tab.IconLabel, FAST_TWEEN, { TextColor3 = selected and self.Theme.Accent or self.Theme.Subtext })
	end
	for _, control in pairs(self._controlsByFlag) do
		if control.RefreshTheme then
			control:RefreshTheme()
		end
	end
	return self
end

function Window:GetFlag(flag)
	return self.Flags[flag]
end

function Window:SetFlag(flag, value)
	local control = self._controlsByFlag[flag]
	if control then
		control:SetValue(value)
	end
	return self
end

function Window:ExportConfig()
	local data = {}
	for flag, control in pairs(self._controlsByFlag) do
		local value = control:GetValue()
		if typeof(value) == "Color3" then
			value = colorToHex(value)
		elseif typeof(value) == "EnumItem" then
			value = value.Name
		end
		data[flag] = value
	end
	return HttpService:JSONEncode(data)
end

function Window:ImportConfig(config)
	local data = config
	if type(config) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, config)
		if not ok then
			warn("[OzionUI] Could not decode config")
			return self
		end
		data = decoded
	end
	if type(data) ~= "table" then
		return self
	end
	for flag, value in pairs(data) do
		local control = self._controlsByFlag[flag]
		if control then
			control:SetValue(value, true)
		end
	end
	return self
end

function Window:_setVisible(visible)
	if self.Destroyed or self.Visible == visible then
		return
	end
	self.Visible = visible
	if visible then
		self.Screen.Enabled = true
		self.Main.Visible = true
		self.Main.Size = UDim2.fromOffset(self._size.X * 0.94, (self.Minimized and 62 or self._size.Y) * 0.94)
		self.Main.GroupTransparency = 1
		self.Shadow.Size = UDim2.fromOffset(self._size.X + 56, (self.Minimized and 62 or self._size.Y) + 56)
		self.Shadow.ImageTransparency = 1
		self.Dim.BackgroundTransparency = 1
		tween(self.Main, SPRING_TWEEN, {
			Size = UDim2.fromOffset(self._size.X, self.Minimized and 62 or self._size.Y),
			GroupTransparency = 0,
		})
		tween(self.Shadow, DEFAULT_TWEEN, { ImageTransparency = 0.25 })
		tween(self.Dim, DEFAULT_TWEEN, { BackgroundTransparency = 0.78 })
	else
		tween(self.Shadow, FAST_TWEEN, { ImageTransparency = 1 })
		tween(self.Dim, FAST_TWEEN, { BackgroundTransparency = 1 })
		local animation = tween(self.Main, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(self._size.X * 0.96, (self.Minimized and 62 or self._size.Y) * 0.96),
			GroupTransparency = 1,
		})
		if animation then
			animation.Completed:Once(function()
				if not self.Visible and not self.Destroyed then
					self.Screen.Enabled = false
				end
			end)
		end
	end
end

function Window:Toggle()
	self:_setVisible(not self.Visible)
	return self
end

function Window:SetMinimized(minimized)
	if self.Destroyed or self.Minimized == minimized then
		return self
	end
	self.Minimized = minimized
	if minimized then
		tween(self.Main, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(self._size.X, 62),
		})
		tween(self.Shadow, DEFAULT_TWEEN, { Size = UDim2.fromOffset(self._size.X + 56, 118) })
		tween(self.MinimizeIcon, FAST_TWEEN, { Rotation = 180 })
		task.delay(0.18, function()
			if self.Minimized and not self.Destroyed then
				self.Body.Visible = false
			end
		end)
	else
		self.Body.Visible = true
		tween(self.Main, SPRING_TWEEN, { Size = UDim2.fromOffset(self._size.X, self._size.Y) })
		tween(self.Shadow, DEFAULT_TWEEN, { Size = UDim2.fromOffset(self._size.X + 56, self._size.Y + 56) })
		tween(self.MinimizeIcon, FAST_TWEEN, { Rotation = 0 })
	end
	return self
end

function Window:Notify(options)
	options = merge({
		Title = "Notification",
		Content = "Something happened.",
		Duration = 4,
		Type = "Info",
	}, options)

	local palette = {
		Info = self.Theme.Accent,
		Success = self.Theme.Success,
		Warning = self.Theme.Warning,
		Error = self.Theme.Danger,
	}
	local accent = palette[options.Type] or self.Theme.Accent
	local toast = create("CanvasGroup", {
		Name = "Toast",
		Size = UDim2.fromOffset(320, 82),
		BackgroundColor3 = self.Theme.Surface,
		BackgroundTransparency = 0.04,
		GroupTransparency = 1,
		Position = UDim2.fromOffset(34, 0),
		Parent = self.ToastHolder,
	})
	corner(toast, 12)
	self:_stroke(toast, "Stroke", 0.25)

	create("Frame", {
		Size = UDim2.fromOffset(4, 50),
		Position = UDim2.fromOffset(10, 16),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = toast,
	})
	corner(toast:FindFirstChildOfClass("Frame"), 4)

	create("TextLabel", {
		Size = UDim2.new(1, -58, 0, 22),
		Position = UDim2.fromOffset(27, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamSemibold,
		Text = tostring(options.Title),
		TextColor3 = self.Theme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toast,
	})
	create("TextLabel", {
		Size = UDim2.new(1, -58, 0, 34),
		Position = UDim2.fromOffset(27, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = tostring(options.Content),
		TextColor3 = self.Theme.Subtext,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = toast,
	})
	local close = create("TextButton", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -35, 0, 7),
		BackgroundTransparency = 1,
		Text = "×",
		Font = Enum.Font.GothamMedium,
		TextColor3 = self.Theme.Subtext,
		TextSize = 20,
		Parent = toast,
	})
	local progress = create("Frame", {
		Size = UDim2.new(1, -20, 0, 2),
		Position = UDim2.new(0, 10, 1, -5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = toast,
	})
	corner(progress, 2)

	local closed = false
	local function dismiss()
		if closed or not toast.Parent then
			return
		end
		closed = true
		local out = tween(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(40, 0),
			GroupTransparency = 1,
		})
		if out then
			out.Completed:Once(function()
				toast:Destroy()
			end)
		end
	end
	close.Activated:Connect(dismiss)
	tween(toast, SPRING_TWEEN, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 })
	tween(progress, TweenInfo.new(options.Duration, Enum.EasingStyle.Linear), { Size = UDim2.fromOffset(0, 2) })
	task.delay(options.Duration, dismiss)
	return toast
end

function Window:AddTab(options)
	if type(options) == "string" then
		options = { Title = options }
	end
	options = merge({ Title = "Tab", Icon = "◆", Description = "" }, options)

	local tab = setmetatable({
		Window = self,
		Title = options.Title,
		Description = options.Description,
		Sections = {},
	}, Tab)

	local nav = create("TextButton", {
		Name = tostring(options.Title),
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = #self.Tabs + 1,
		Parent = self.NavHolder,
	})
	corner(nav, 9)
	local icon = create("TextLabel", {
		Size = UDim2.fromOffset(34, 42),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		Text = tostring(options.Icon),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = self.Theme.Subtext,
		Parent = nav,
	})
	local label = create("TextLabel", {
		Size = UDim2.new(1, -48, 1, 0),
		Position = UDim2.fromOffset(43, 0),
		BackgroundTransparency = 1,
		Text = tostring(options.Title),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = self.Theme.Subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = nav,
	})
	local marker = create("Frame", {
		Size = UDim2.fromOffset(3, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = self.Theme.Accent,
		BorderSizePixel = 0,
		Parent = nav,
	})
	corner(marker, 3)
	self:_theme(nav, "BackgroundColor3", "Accent")
	self:_theme(marker, "BackgroundColor3", "Accent")
	self:_theme(icon, "TextColor3", "Subtext")
	self:_theme(label, "TextColor3", "Subtext")

	local page = create("CanvasGroup", {
		Name = tostring(options.Title),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		GroupTransparency = 1,
		Position = UDim2.fromOffset(18, 0),
		Parent = self.Pages,
	})
	local scroller = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = self.Theme.Accent,
		ScrollBarImageTransparency = 0.25,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = page,
	})
	padding(scroller, 4, 6, 18, 2)
	list(scroller, 12)
	self:_theme(scroller, "ScrollBarImageColor3", "Accent")

	tab.Button = nav
	tab.IconLabel = icon
	tab.TextLabel = label
	tab.Marker = marker
	tab.Page = page
	tab.Scroller = scroller
	table.insert(self.Tabs, tab)

	self._maid:Give(nav.Activated:Connect(function()
		self:SelectTab(tab)
	end))
	self._maid:Give(nav.MouseEnter:Connect(function()
		if self.SelectedTab ~= tab then
			tween(nav, FAST_TWEEN, { BackgroundTransparency = 0.9 })
		end
	end))
	self._maid:Give(nav.MouseLeave:Connect(function()
		if self.SelectedTab ~= tab then
			tween(nav, FAST_TWEEN, { BackgroundTransparency = 1 })
		end
	end))

	if not self.SelectedTab then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	if type(tab) == "string" then
		for _, candidate in ipairs(self.Tabs) do
			if candidate.Title == tab then
				tab = candidate
				break
			end
		end
	end
	if type(tab) ~= "table" or self.SelectedTab == tab then
		return self
	end

	local previous = self.SelectedTab
	self.SelectedTab = tab
	self.PageTitle.Text = tab.Title
	self.PageDescription.Text = tab.Description ~= "" and tab.Description
		or "Manage " .. string.lower(tab.Title) .. " settings"

	if previous then
		tween(previous.Button, FAST_TWEEN, { BackgroundTransparency = 1 })
		tween(previous.TextLabel, FAST_TWEEN, { TextColor3 = self.Theme.Subtext })
		tween(previous.IconLabel, FAST_TWEEN, { TextColor3 = self.Theme.Subtext })
		tween(previous.Marker, FAST_TWEEN, { Size = UDim2.fromOffset(3, 0) })
		local oldPage = previous.Page
		local out = tween(oldPage, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(-12, 0),
			GroupTransparency = 1,
		})
		if out then
			out.Completed:Once(function()
				if self.SelectedTab ~= previous then
					oldPage.Visible = false
				end
			end)
		end
	end

	tab.Page.Visible = true
	tab.Page.Position = UDim2.fromOffset(18, 0)
	tab.Page.GroupTransparency = 1
	tween(tab.Page, TweenInfo.new(0.27, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, 0),
		GroupTransparency = 0,
	})
	tween(tab.Button, FAST_TWEEN, { BackgroundTransparency = 0.86 })
	tween(tab.TextLabel, FAST_TWEEN, { TextColor3 = self.Theme.Text })
	tween(tab.IconLabel, FAST_TWEEN, { TextColor3 = self.Theme.Accent })
	tween(tab.Marker, SPRING_TWEEN, { Size = UDim2.fromOffset(3, 22) })
	return self
end

function Tab:AddSection(options)
	if type(options) == "string" then
		options = { Title = options }
	end
	options = merge({ Title = "Section", Description = "" }, options)
	local section = setmetatable({
		Tab = self,
		Window = self.Window,
		Title = options.Title,
		Controls = {},
	}, Section)

	local panel = create("Frame", {
		Name = tostring(options.Title),
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.Window.Theme.Surface,
		BackgroundTransparency = 0.08,
		LayoutOrder = #self.Sections + 1,
		Parent = self.Scroller,
	})
	corner(panel, 12)
	self.Window:_stroke(panel, "Stroke", 0.32)
	self.Window:_theme(panel, "BackgroundColor3", "Surface")

	local header = create("Frame", {
		Size = UDim2.new(1, 0, 0, options.Description ~= "" and 62 or 48),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = panel,
	})
	local sectionTitle = create("TextLabel", {
		Size = UDim2.new(1, -28, 0, 22),
		Position = UDim2.fromOffset(14, options.Description ~= "" and 10 or 13),
		BackgroundTransparency = 1,
		Text = tostring(options.Title),
		TextColor3 = self.Window.Theme.Text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	self.Window:_theme(sectionTitle, "TextColor3", "Text")
	if options.Description ~= "" then
		local sectionDescription = create("TextLabel", {
			Size = UDim2.new(1, -28, 0, 18),
			Position = UDim2.fromOffset(14, 32),
			BackgroundTransparency = 1,
			Text = tostring(options.Description),
			TextColor3 = self.Window.Theme.Subtext,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = header,
		})
		self.Window:_theme(sectionDescription, "TextColor3", "Subtext")
	end
	local divider = create("Frame", {
		Size = UDim2.new(1, -28, 0, 1),
		Position = UDim2.new(0, 14, 1, -1),
		BackgroundColor3 = self.Window.Theme.Stroke,
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Parent = header,
	})
	self.Window:_theme(divider, "BackgroundColor3", "Stroke")

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = panel,
	})
	padding(holder, 7, 8, 8, 8)
	list(holder, 5)
	list(panel, 0)

	section.Panel = panel
	section.Holder = holder
	table.insert(self.Sections, section)
	return section
end

function Section:_row(options, height)
	local rightInset = options.RightInset or 150
	local row = create("Frame", {
		Name = tostring(options.Title or "Control"),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = self.Window.Theme.SurfaceAlt,
		BackgroundTransparency = 1,
		LayoutOrder = #self.Controls + 1,
		Parent = self.Holder,
	})
	corner(row, 9)
	self.Window:_theme(row, "BackgroundColor3", "SurfaceAlt")
	local title = create("TextLabel", {
		Size = UDim2.new(1, -rightInset, 0, options.Description and options.Description ~= "" and 20 or height),
		Position = UDim2.fromOffset(12, options.Description and options.Description ~= "" and 9 or 0),
		BackgroundTransparency = 1,
		Text = tostring(options.Title or "Control"),
		TextColor3 = self.Window.Theme.Text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	self.Window:_theme(title, "TextColor3", "Text")
	if options.Description and options.Description ~= "" then
		local description = create("TextLabel", {
			Size = UDim2.new(1, -rightInset, 0, 18),
			Position = UDim2.fromOffset(12, 30),
			BackgroundTransparency = 1,
			Text = tostring(options.Description),
			TextColor3 = self.Window.Theme.Subtext,
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		self.Window:_theme(description, "TextColor3", "Subtext")
	end
	self.Window._maid:Give(row.MouseEnter:Connect(function()
		tween(row, FAST_TWEEN, { BackgroundTransparency = 0.58 })
	end))
	self.Window._maid:Give(row.MouseLeave:Connect(function()
		tween(row, FAST_TWEEN, { BackgroundTransparency = 1 })
	end))
	table.insert(self.Controls, row)
	return row, title
end

function Section:AddButton(options)
	if type(options) == "string" then
		options = { Title = options }
	end
	options = merge({ Title = "Button", Description = "", Callback = nil }, options)
	local row = self:_row(options, options.Description ~= "" and 58 or 48)
	row.ClipsDescendants = true
	local arrow = create("TextLabel", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -43, 0.5, -17),
		BackgroundColor3 = self.Window.Theme.SurfaceHover,
		BackgroundTransparency = 0.25,
		Text = "›",
		TextColor3 = self.Window.Theme.Subtext,
		TextSize = 22,
		Font = Enum.Font.GothamMedium,
		Parent = row,
	})
	corner(arrow, 8)
	self.Window:_theme(arrow, "BackgroundColor3", "SurfaceHover")
	self.Window:_theme(arrow, "TextColor3", "Subtext")
	local hitbox = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	})

	local control = { Value = false }
	function control:GetValue()
		return self.Value
	end
	function control:SetValue() end
	function control:Fire()
		safeCall(options.Callback)
	end

	self.Window._maid:Give(hitbox.Activated:Connect(function(input)
		tween(
			arrow,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad),
			{ Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -41, 0.5, -15) }
		)
		task.delay(0.1, function()
			if arrow.Parent then
				tween(arrow, SPRING_TWEEN, { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -43, 0.5, -17) })
			end
		end)
		local location = UserInputService:GetMouseLocation()
		local ripple = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(location.X - row.AbsolutePosition.X, location.Y - row.AbsolutePosition.Y),
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = self.Window.Theme.Accent,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			ZIndex = row.ZIndex + 2,
			Parent = row,
		})
		corner(ripple, 999)
		local animation = tween(ripple, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(
				math.max(row.AbsoluteSize.X, row.AbsoluteSize.Y) * 2,
				math.max(row.AbsoluteSize.X, row.AbsoluteSize.Y) * 2
			),
			BackgroundTransparency = 1,
		})
		if animation then
			animation.Completed:Once(function()
				ripple:Destroy()
			end)
		end
		control:Fire()
	end))
	return control
end

function Section:AddToggle(options)
	local window = self.Window
	if type(options) == "string" then
		options = { Title = options }
	end
	options = merge({ Title = "Toggle", Description = "", Default = false, Callback = nil }, options)
	local row = self:_row(options, options.Description ~= "" and 60 or 50)
	local track = create("Frame", {
		Size = UDim2.fromOffset(44, 24),
		Position = UDim2.new(1, -56, 0.5, -12),
		BackgroundColor3 = self.Window.Theme.SurfaceHover,
		Parent = row,
	})
	corner(track, 12)
	local knob = create("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = self.Window.Theme.Subtext,
		Parent = track,
	})
	corner(knob, 9)
	self.Window:_theme(track, "BackgroundColor3", "SurfaceHover")
	local hitbox =
		create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = row })
	local control = { Value = not options.Default }
	function control:GetValue()
		return self.Value
	end
	function control:RefreshTheme()
		tween(
			track,
			DEFAULT_TWEEN,
			{ BackgroundColor3 = self.Value and window.Theme.Accent or window.Theme.SurfaceHover }
		)
		tween(knob, DEFAULT_TWEEN, { BackgroundColor3 = self.Value and Color3.new(1, 1, 1) or window.Theme.Subtext })
	end
	function control:SetValue(value, silent)
		value = not not value
		if self.Value == value then
			return
		end
		self.Value = value
		if value then
			tween(track, DEFAULT_TWEEN, { BackgroundColor3 = window.Theme.Accent })
			tween(knob, SPRING_TWEEN, { Position = UDim2.fromOffset(23, 3), BackgroundColor3 = Color3.new(1, 1, 1) })
		else
			tween(track, DEFAULT_TWEEN, { BackgroundColor3 = window.Theme.SurfaceHover })
			tween(knob, SPRING_TWEEN, { Position = UDim2.fromOffset(3, 3), BackgroundColor3 = window.Theme.Subtext })
		end
		window.Flags[self.Flag] = value
		if not silent then
			safeCall(options.Callback, value)
		end
	end
	control = self.Window:_registerControl(options, control)
	control:SetValue(options.Default, true)
	self.Window._maid:Give(hitbox.Activated:Connect(function()
		control:SetValue(not control.Value)
	end))
	return control
end

function Section:AddSlider(options)
	local window = self.Window
	if type(options) == "string" then
		options = { Title = options }
	end
	options = merge({
		Title = "Slider",
		Description = "",
		Min = 0,
		Max = 100,
		Default = 50,
		Increment = 1,
		Suffix = "",
		Callback = nil,
	}, options)
	assert(options.Max > options.Min, "Slider Max must be greater than Min")
	assert(options.Increment > 0, "Slider Increment must be greater than zero")
	local row = self:_row(options, options.Description ~= "" and 78 or 68)
	local valueLabel = create("TextLabel", {
		Size = UDim2.fromOffset(72, 28),
		Position = UDim2.new(1, -84, 0, 8),
		BackgroundColor3 = self.Window.Theme.SurfaceHover,
		BackgroundTransparency = 0.2,
		TextColor3 = self.Window.Theme.Text,
		TextSize = 12,
		Font = Enum.Font.GothamSemibold,
		Parent = row,
	})
	corner(valueLabel, 7)
	self.Window:_theme(valueLabel, "BackgroundColor3", "SurfaceHover")
	self.Window:_theme(valueLabel, "TextColor3", "Text")
	local track = create("Frame", {
		Size = UDim2.new(1, -24, 0, 5),
		Position = UDim2.new(0, 12, 1, -16),
		BackgroundColor3 = self.Window.Theme.SurfaceHover,
		BorderSizePixel = 0,
		Parent = row,
	})
	corner(track, 4)
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = self.Window.Theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(fill, 4)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	})
	corner(knob, 7)
	self.Window:_stroke(knob, "Accent", 0, 2)
	self.Window:_theme(track, "BackgroundColor3", "SurfaceHover")
	self.Window:_theme(fill, "BackgroundColor3", "Accent")
	local hitbox = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0.5, -12),
		BackgroundTransparency = 1,
		Text = "",
		Parent = track,
	})
	local dragging = false
	local control = { Value = nil }
	function control:GetValue()
		return self.Value
	end
	function control:SetValue(value, silent)
		value = clamp(round(tonumber(value) or options.Min, options.Increment), options.Min, options.Max)
		if self.Value == value then
			return
		end
		self.Value = value
		local alpha = (value - options.Min) / (options.Max - options.Min)
		valueLabel.Text = tostring(value) .. tostring(options.Suffix)
		tween(fill, FAST_TWEEN, { Size = UDim2.fromScale(alpha, 1) })
		tween(knob, FAST_TWEEN, { Position = UDim2.fromScale(alpha, 0.5) })
		window.Flags[self.Flag] = value
		if not silent then
			safeCall(options.Callback, value)
		end
	end
	local function update(input)
		local alpha = clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		control:SetValue(options.Min + (options.Max - options.Min) * alpha)
	end
	control = self.Window:_registerControl(options, control)
	control:SetValue(options.Default, true)
	self.Window._maid:Give(hitbox.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			tween(knob, FAST_TWEEN, { Size = UDim2.fromOffset(18, 18) })
			update(input)
		end
	end))
	self.Window._maid:Give(UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			update(input)
		end
	end))
	self.Window._maid:Give(UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
			tween(knob, SPRING_TWEEN, { Size = UDim2.fromOffset(14, 14) })
		end
	end))
	return control
end

function Section:AddDropdown(options)
	local window = self.Window
	if type(options) == "string" then
		options = { Title = options }
	end
	options = merge({ Title = "Dropdown", Description = "", Values = {}, Default = nil, Callback = nil }, options)
	options.RightInset = options.RightInset or 160
	local baseHeight = options.Description ~= "" and 60 or 50
	local row = self:_row(options, baseHeight)
	row.ClipsDescendants = true
	local selector = create("TextButton", {
		Size = UDim2.fromOffset(132, 32),
		Position = UDim2.new(1, -144, 0, math.floor((baseHeight - 32) / 2)),
		BackgroundColor3 = self.Window.Theme.SurfaceHover,
		BackgroundTransparency = 0.15,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	})
	corner(selector, 8)
	local selectedLabel = create("TextLabel", {
		Size = UDim2.new(1, -32, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = "Select...",
		TextColor3 = self.Window.Theme.Subtext,
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = selector,
	})
	local chevron = create("TextLabel", {
		Size = UDim2.fromOffset(28, 32),
		Position = UDim2.new(1, -28, 0, 0),
		BackgroundTransparency = 1,
		Text = "⌄",
		TextColor3 = self.Window.Theme.Subtext,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		Parent = selector,
	})
	local optionHolder = create("Frame", {
		Size = UDim2.new(1, -24, 0, 0),
		Position = UDim2.fromOffset(12, baseHeight),
		BackgroundTransparency = 1,
		Parent = row,
	})
	list(optionHolder, 4)
	self.Window:_theme(selector, "BackgroundColor3", "SurfaceHover")
	self.Window:_theme(selectedLabel, "TextColor3", "Subtext")
	self.Window:_theme(chevron, "TextColor3", "Subtext")

	local control = { Value = nil, Open = false, Values = options.Values }
	function control:GetValue()
		return self.Value
	end
	function control:RefreshTheme()
		tween(
			selectedLabel,
			FAST_TWEEN,
			{ TextColor3 = self.Value ~= nil and window.Theme.Text or window.Theme.Subtext }
		)
	end
	function control:SetValue(value, silent)
		local valid = false
		for _, item in ipairs(self.Values) do
			if item == value or tostring(item) == tostring(value) then
				value = item
				valid = true
				break
			end
		end
		if not valid or self.Value == value then
			return
		end
		self.Value = value
		selectedLabel.Text = tostring(value)
		tween(selectedLabel, FAST_TWEEN, { TextColor3 = window.Theme.Text })
		window.Flags[self.Flag] = value
		if not silent then
			safeCall(options.Callback, value)
		end
		if self.Open then
			self:SetOpen(false)
		end
	end
	function control:SetOpen(open)
		self.Open = open
		local optionHeight = #self.Values * 34 + math.max(0, #self.Values - 1) * 4
		tween(row, DEFAULT_TWEEN, { Size = UDim2.new(1, 0, 0, open and baseHeight + optionHeight + 8 or baseHeight) })
		tween(chevron, DEFAULT_TWEEN, { Rotation = open and 180 or 0 })
	end
	function control:Refresh(values, selected)
		self.Values = values or {}
		for _, child in ipairs(optionHolder:GetChildren()) do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for index, value in ipairs(self.Values) do
			local optionButton = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = window.Theme.SurfaceHover,
				BackgroundTransparency = 0.55,
				Text = "  " .. tostring(value),
				TextColor3 = window.Theme.Subtext,
				TextSize = 11,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				LayoutOrder = index,
				Parent = optionHolder,
			})
			corner(optionButton, 7)
			window._maid:Give(optionButton.MouseEnter:Connect(function()
				tween(optionButton, FAST_TWEEN, { BackgroundTransparency = 0.2, TextColor3 = window.Theme.Text })
			end))
			window._maid:Give(optionButton.MouseLeave:Connect(function()
				tween(optionButton, FAST_TWEEN, { BackgroundTransparency = 0.55, TextColor3 = window.Theme.Subtext })
			end))
			window._maid:Give(optionButton.Activated:Connect(function()
				self:SetValue(value)
			end))
		end
		if self.Open then
			self:SetOpen(true)
		end
		if selected ~= nil then
			self:SetValue(selected, true)
		end
	end
	control = self.Window:_registerControl(options, control)
	local initialValue = options.Default
	if initialValue == nil then
		initialValue = options.Values[1]
	end
	control:Refresh(options.Values, initialValue)
	self.Window._maid:Give(selector.Activated:Connect(function()
		control:SetOpen(not control.Open)
	end))
	return control
end

function Section:AddInput(options)
	local window = self.Window
	if type(options) == "string" then
		options = { Title = options }
	end
	options = merge({
		Title = "Input",
		Description = "",
		Default = "",
		Placeholder = "Type here...",
		Numeric = false,
		Finished = true,
		Callback = nil,
	}, options)
	options.RightInset = options.RightInset or 180
	local row = self:_row(options, options.Description ~= "" and 64 or 54)
	local box = create("TextBox", {
		Size = UDim2.fromOffset(150, 34),
		Position = UDim2.new(1, -162, 0.5, -17),
		BackgroundColor3 = self.Window.Theme.SurfaceHover,
		BackgroundTransparency = 0.15,
		Text = tostring(options.Default),
		PlaceholderText = tostring(options.Placeholder),
		TextColor3 = self.Window.Theme.Text,
		PlaceholderColor3 = self.Window.Theme.Subtext,
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	padding(box, 0, 10, 0, 10)
	corner(box, 8)
	local boxStroke = self.Window:_stroke(box, "Stroke", 0.55)
	self.Window:_theme(box, "BackgroundColor3", "SurfaceHover")
	self.Window:_theme(box, "TextColor3", "Text")
	self.Window:_theme(box, "PlaceholderColor3", "Subtext")
	local control = { Value = tostring(options.Default) }
	function control:GetValue()
		return self.Value
	end
	function control:RefreshTheme()
		tween(boxStroke, FAST_TWEEN, {
			Color = box:IsFocused() and window.Theme.Accent or window.Theme.Stroke,
			Transparency = box:IsFocused() and 0 or 0.55,
		})
	end
	function control:SetValue(value, silent)
		value = tostring(value or "")
		if options.Numeric then
			value = value:gsub("[^%d%.%-]", "")
		end
		if self.Value == value and box.Text == value then
			return
		end
		self.Value = value
		box.Text = value
		window.Flags[self.Flag] = value
		if not silent then
			safeCall(options.Callback, value)
		end
	end
	control = self.Window:_registerControl(options, control)
	self.Window._maid:Give(box.Focused:Connect(function()
		tween(boxStroke, FAST_TWEEN, { Color = window.Theme.Accent, Transparency = 0 })
	end))
	self.Window._maid:Give(box.FocusLost:Connect(function(enterPressed)
		tween(boxStroke, FAST_TWEEN, { Color = window.Theme.Stroke, Transparency = 0.55 })
		control:SetValue(box.Text)
		if options.Finished and not enterPressed then
			return
		end
	end))
	if not options.Finished then
		self.Window._maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
			control:SetValue(box.Text)
		end))
	end
	return control
end

function Section:AddKeybind(options)
	local window = self.Window
	if type(options) == "string" then
		options = { Title = options }
	end
	options = merge(
		{ Title = "Keybind", Description = "", Default = Enum.KeyCode.Unknown, Callback = nil, ChangedCallback = nil },
		options
	)
	if type(options.Default) == "string" then
		options.Default = Enum.KeyCode[options.Default] or Enum.KeyCode.Unknown
	end
	local row = self:_row(options, options.Description ~= "" and 60 or 50)
	local bindButton = create("TextButton", {
		Size = UDim2.fromOffset(94, 32),
		Position = UDim2.new(1, -106, 0.5, -16),
		BackgroundColor3 = self.Window.Theme.SurfaceHover,
		BackgroundTransparency = 0.15,
		Text = "None",
		TextColor3 = self.Window.Theme.Subtext,
		TextSize = 11,
		Font = Enum.Font.GothamSemibold,
		AutoButtonColor = false,
		Parent = row,
	})
	corner(bindButton, 8)
	self.Window:_theme(bindButton, "BackgroundColor3", "SurfaceHover")
	local control = { Value = Enum.KeyCode.Unknown, Listening = false }
	function control:GetValue()
		return self.Value
	end
	function control:RefreshTheme()
		tween(bindButton, FAST_TWEEN, { TextColor3 = self.Listening and window.Theme.Accent or window.Theme.Subtext })
	end
	function control:SetValue(value, silent)
		if type(value) == "string" then
			value = Enum.KeyCode[value] or Enum.KeyCode.Unknown
		end
		if typeof(value) ~= "EnumItem" or value.EnumType ~= Enum.KeyCode then
			return
		end
		self.Value = value
		bindButton.Text = value == Enum.KeyCode.Unknown and "None" or keyName(value)
		window.Flags[self.Flag] = value
		if not silent then
			safeCall(options.ChangedCallback, value)
		end
	end
	control = self.Window:_registerControl(options, control)
	control:SetValue(options.Default, true)
	self.Window._maid:Give(bindButton.Activated:Connect(function()
		control.Listening = true
		bindButton.Text = "Press a key..."
		tween(bindButton, FAST_TWEEN, { TextColor3 = window.Theme.Accent })
	end))
	self.Window._maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if control.Listening and input.UserInputType == Enum.UserInputType.Keyboard then
			control.Listening = false
			local key = input.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or input.KeyCode
			control:SetValue(key)
			tween(bindButton, FAST_TWEEN, { TextColor3 = window.Theme.Subtext })
			return
		end
		if
			not processed
			and not control.Listening
			and input.KeyCode == control.Value
			and control.Value ~= Enum.KeyCode.Unknown
		then
			safeCall(options.Callback, control.Value)
		end
	end))
	return control
end

function Section:AddColorPicker(options)
	local window = self.Window
	if type(options) == "string" then
		options = { Title = options }
	end
	options =
		merge({ Title = "Color", Description = "", Default = Color3.fromRGB(132, 91, 255), Callback = nil }, options)
	local parsedDefault = hexToColor(options.Default) or Color3.fromRGB(132, 91, 255)
	local baseHeight = options.Description ~= "" and 60 or 50
	local row = self:_row(options, baseHeight)
	row.ClipsDescendants = true
	local preview = create("TextButton", {
		Size = UDim2.fromOffset(76, 32),
		Position = UDim2.new(1, -88, 0, math.floor((baseHeight - 32) / 2)),
		BackgroundColor3 = parsedDefault,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	})
	corner(preview, 8)
	local previewStroke = self.Window:_stroke(preview, "Stroke", 0.15)
	local picker = create("Frame", {
		Size = UDim2.new(1, -24, 0, 130),
		Position = UDim2.fromOffset(12, baseHeight),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local saturation = create("TextButton", {
		Size = UDim2.new(1, -52, 0, 112),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Color3.fromHSV(0, 1, 1),
		Text = "",
		AutoButtonColor = false,
		Parent = picker,
	})
	corner(saturation, 8)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(0, 1, 1)),
		Parent = saturation,
	})
	local darkness = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		Parent = saturation,
	})
	corner(darkness, 8)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
		Rotation = 90,
		Parent = darkness,
	})
	local satCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = saturation,
	})
	corner(satCursor, 6)
	create("UIStroke", { Color = Color3.fromRGB(15, 15, 20), Thickness = 2, Parent = satCursor })
	local hue = create("TextButton", {
		Size = UDim2.fromOffset(28, 112),
		Position = UDim2.new(1, -28, 0, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = false,
		Parent = picker,
	})
	corner(hue, 8)
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
			ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
			ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
			ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		}),
		Rotation = 90,
		Parent = hue,
	})
	local hueCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 6, 0, 4),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = hue,
	})
	corner(hueCursor, 2)
	create("UIStroke", { Color = Color3.fromRGB(15, 15, 20), Thickness = 1, Parent = hueCursor })

	local h, s, v = parsedDefault:ToHSV()
	local draggingSat, draggingHue = false, false
	local control = { Value = parsedDefault, Open = false }
	function control:GetValue()
		return self.Value
	end
	function control:RefreshTheme()
		tween(previewStroke, FAST_TWEEN, { Color = self.Open and window.Theme.Accent or window.Theme.Stroke })
	end
	function control:SetValue(value, silent)
		value = hexToColor(value)
		if not value then
			return
		end
		self.Value = value
		h, s, v = value:ToHSV()
		preview.BackgroundColor3 = value
		saturation.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		satCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(0.5, h)
		window.Flags[self.Flag] = value
		if not silent then
			safeCall(options.Callback, value)
		end
	end
	function control:SetOpen(open)
		self.Open = open
		tween(row, DEFAULT_TWEEN, { Size = UDim2.new(1, 0, 0, open and baseHeight + 130 or baseHeight) })
		tween(previewStroke, FAST_TWEEN, { Color = open and window.Theme.Accent or window.Theme.Stroke })
	end
	local function updateSat(input)
		s = clamp((input.Position.X - saturation.AbsolutePosition.X) / saturation.AbsoluteSize.X, 0, 1)
		v = 1 - clamp((input.Position.Y - saturation.AbsolutePosition.Y) / saturation.AbsoluteSize.Y, 0, 1)
		control:SetValue(Color3.fromHSV(h, s, v))
	end
	local function updateHue(input)
		h = clamp((input.Position.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1)
		control:SetValue(Color3.fromHSV(h, s, v))
	end
	control = self.Window:_registerControl(options, control)
	control:SetValue(parsedDefault, true)
	self.Window._maid:Give(preview.Activated:Connect(function()
		control:SetOpen(not control.Open)
	end))
	self.Window._maid:Give(saturation.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			draggingSat = true
			updateSat(input)
		end
	end))
	self.Window._maid:Give(hue.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			draggingHue = true
			updateHue(input)
		end
	end))
	self.Window._maid:Give(UserInputService.InputChanged:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if draggingSat then
				updateSat(input)
			elseif draggingHue then
				updateHue(input)
			end
		end
	end))
	self.Window._maid:Give(UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			draggingSat = false
			draggingHue = false
		end
	end))
	return control
end

function Section:AddParagraph(options)
	if type(options) == "string" then
		options = { Title = "Note", Content = options }
	end
	options = merge({ Title = "Note", Content = "", Accent = true }, options)
	local paragraph = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.Window.Theme.SurfaceAlt,
		BackgroundTransparency = 0.38,
		LayoutOrder = #self.Controls + 1,
		Parent = self.Holder,
	})
	corner(paragraph, 9)
	padding(paragraph, 11, 13, 11, 17)
	local contentHolder = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = paragraph,
	})
	list(contentHolder, 5)
	local paragraphTitle = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = tostring(options.Title),
		TextColor3 = self.Window.Theme.Text,
		TextSize = 12,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = contentHolder,
	})
	local paragraphContent = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = tostring(options.Content),
		TextColor3 = self.Window.Theme.Subtext,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = contentHolder,
	})
	self.Window:_theme(paragraphTitle, "TextColor3", "Text")
	self.Window:_theme(paragraphContent, "TextColor3", "Subtext")
	self.Window:_theme(paragraph, "BackgroundColor3", "SurfaceAlt")
	if options.Accent then
		local bar = create("Frame", {
			Size = UDim2.new(0, 3, 1, -14),
			Position = UDim2.fromOffset(-9, 7),
			BackgroundColor3 = self.Window.Theme.Accent,
			BorderSizePixel = 0,
			Parent = paragraph,
		})
		corner(bar, 3)
		self.Window:_theme(bar, "BackgroundColor3", "Accent")
	end
	table.insert(self.Controls, paragraph)
	return paragraph
end

function Window:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self._maid:Clean()
	if self.Screen then
		self.Screen:Destroy()
	end
	for index, window in ipairs(OzionUI.Windows) do
		if window == self then
			table.remove(OzionUI.Windows, index)
			break
		end
	end
end

function OzionUI:CreateWindow(options)
	options = merge({
		Title = "OzionUI",
		Subtitle = "UI LIBRARY",
		Size = Vector2.new(760, 500),
		MinSize = Vector2.new(620, 400),
		Theme = "Obsidian",
		ToggleKey = Enum.KeyCode.RightShift,
		Resizable = true,
		Parent = nil,
	}, options)

	local size = options.Size
	if typeof(size) == "UDim2" then
		size = Vector2.new(size.X.Offset, size.Y.Offset)
	end
	if typeof(size) ~= "Vector2" then
		size = Vector2.new(760, 500)
	end
	local parent = options.Parent
	if not parent then
		local player = Players.LocalPlayer
		assert(player, "OzionUI must be created from a LocalScript, or receive a Parent")
		parent = player:WaitForChild("PlayerGui")
	end
	local theme = type(options.Theme) == "table" and merge(self.Themes.Obsidian, options.Theme)
		or merge(self.Themes.Obsidian, self.Themes[options.Theme] or self.Themes.Obsidian)
	local window = setmetatable({
		Theme = theme,
		Tabs = {},
		Flags = {},
		Visible = true,
		Minimized = false,
		Destroyed = false,
		SelectedTab = nil,
		_size = size,
		_minSize = options.MinSize,
		_themeBindings = {},
		_controlsByFlag = {},
		_maid = makeMaid(),
	}, Window)

	local screen = create("ScreenGui", {
		Name = "OzionUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 50,
		Parent = parent,
	})
	window.Screen = screen
	window._maid:Give(screen)

	local dim = create("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = screen,
	})
	window.Dim = dim

	local shadow = create("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, size.X + 56, 0, size.Y + 56),
		BackgroundTransparency = 1,
		Image = "rbxassetid://1316045217",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(10, 10, 118, 118),
		Parent = screen,
	})
	window.Shadow = shadow

	local main = create("CanvasGroup", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X * 0.92, size.Y * 0.92),
		BackgroundColor3 = theme.Background,
		GroupTransparency = 1,
		ClipsDescendants = true,
		Parent = screen,
	})
	corner(main, 14)
	window:_stroke(main, "Stroke", 0.08)
	window:_theme(main, "BackgroundColor3", "Background")
	window.Main = main

	local ambient = create("Frame", {
		Size = UDim2.fromOffset(280, 280),
		Position = UDim2.new(1, -150, 0, -170),
		BackgroundColor3 = theme.Accent,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Parent = main,
	})
	corner(ambient, 999)
	window:_theme(ambient, "BackgroundColor3", "Accent")
	local ambientGradient = create("UIGradient", {
		Color = ColorSequence.new(theme.Accent, theme.AccentAlt),
		Rotation = 0,
		Parent = ambient,
	})
	window._maid:Give(
		tween(
			ambientGradient,
			TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = 360 }
		)
	)

	local topbar = create("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		Parent = main,
	})
	window.Topbar = topbar
	local logo = create("Frame", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(16, 14),
		BackgroundColor3 = theme.Accent,
		Parent = topbar,
	})
	corner(logo, 10)
	window:_theme(logo, "BackgroundColor3", "Accent")
	local logoGradient =
		create("UIGradient", { Color = ColorSequence.new(theme.Accent, theme.AccentAlt), Rotation = 45, Parent = logo })
	window._maid:Give(
		tween(
			logoGradient,
			TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = 225 }
		)
	)
	create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = string.upper(tostring(options.Title)):sub(1, 1),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 17,
		Font = Enum.Font.GothamBold,
		Parent = logo,
	})
	local brand = create("TextLabel", {
		Size = UDim2.fromOffset(180, 22),
		Position = UDim2.fromOffset(61, 11),
		BackgroundTransparency = 1,
		Text = tostring(options.Title),
		TextColor3 = theme.Text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topbar,
	})
	window:_theme(brand, "TextColor3", "Text")
	local subtitle = create("TextLabel", {
		Size = UDim2.fromOffset(180, 18),
		Position = UDim2.fromOffset(61, 31),
		BackgroundTransparency = 1,
		Text = tostring(options.Subtitle),
		TextColor3 = theme.Subtext,
		TextSize = 9,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topbar,
	})
	window:_theme(subtitle, "TextColor3", "Subtext")

	local function topButton(text, position)
		local button = create("TextButton", {
			Size = UDim2.fromOffset(34, 34),
			Position = position,
			BackgroundColor3 = theme.SurfaceAlt,
			BackgroundTransparency = 0.38,
			Text = text,
			TextColor3 = theme.Subtext,
			TextSize = 16,
			Font = Enum.Font.GothamMedium,
			AutoButtonColor = false,
			Parent = topbar,
		})
		corner(button, 9)
		window:_theme(button, "BackgroundColor3", "SurfaceAlt")
		window:_theme(button, "TextColor3", "Subtext")
		window._maid:Give(button.MouseEnter:Connect(function()
			tween(button, FAST_TWEEN, { BackgroundTransparency = 0, TextColor3 = window.Theme.Text })
		end))
		window._maid:Give(button.MouseLeave:Connect(function()
			tween(button, FAST_TWEEN, { BackgroundTransparency = 0.38, TextColor3 = window.Theme.Subtext })
		end))
		return button
	end
	local minimize = topButton("−", UDim2.new(1, -84, 0, 14))
	local close = topButton("×", UDim2.new(1, -44, 0, 14))
	window.MinimizeIcon = minimize
	window._maid:Give(minimize.Activated:Connect(function()
		window:SetMinimized(not window.Minimized)
	end))
	window._maid:Give(close.Activated:Connect(function()
		local animation = tween(
			main,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Size = UDim2.fromOffset(size.X * 0.75, size.Y * 0.75), GroupTransparency = 1 }
		)
		if animation then
			animation.Completed:Once(function()
				window:Destroy()
			end)
		else
			window:Destroy()
		end
	end))

	local body = create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -62),
		Position = UDim2.fromOffset(0, 62),
		BackgroundTransparency = 1,
		Parent = main,
	})
	window.Body = body
	local sidebar = create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 205, 1, 0),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = body,
	})
	window:_theme(sidebar, "BackgroundColor3", "Surface")
	local edge = create("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BackgroundColor3 = theme.Stroke,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	window:_theme(edge, "BackgroundColor3", "Stroke")

	local search = create("TextBox", {
		Size = UDim2.new(1, -24, 0, 36),
		Position = UDim2.fromOffset(12, 10),
		BackgroundColor3 = theme.SurfaceAlt,
		BackgroundTransparency = 0.12,
		Text = "",
		PlaceholderText = "Search tabs...",
		TextColor3 = theme.Text,
		PlaceholderColor3 = theme.Subtext,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sidebar,
	})
	padding(search, 0, 11, 0, 31)
	corner(search, 9)
	window:_stroke(search, "Stroke", 0.5)
	window:_theme(search, "BackgroundColor3", "SurfaceAlt")
	window:_theme(search, "TextColor3", "Text")
	window:_theme(search, "PlaceholderColor3", "Subtext")
	local searchIcon = create("TextLabel", {
		Size = UDim2.fromOffset(28, 36),
		Position = UDim2.fromOffset(16, 10),
		BackgroundTransparency = 1,
		Text = "⌕",
		TextColor3 = theme.Subtext,
		TextSize = 17,
		Font = Enum.Font.GothamMedium,
		Parent = sidebar,
	})
	window:_theme(searchIcon, "TextColor3", "Subtext")

	local navHolder = create("ScrollingFrame", {
		Name = "Navigation",
		Size = UDim2.new(1, -20, 1, -66),
		Position = UDim2.fromOffset(10, 56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = sidebar,
	})
	list(navHolder, 5)
	window.NavHolder = navHolder
	window._maid:Give(search:GetPropertyChangedSignal("Text"):Connect(function()
		local query = string.lower(search.Text)
		for _, tab in ipairs(window.Tabs) do
			tab.Button.Visible = query == "" or string.find(string.lower(tab.Title), query, 1, true) ~= nil
		end
	end))

	local content = create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -205, 1, 0),
		Position = UDim2.fromOffset(205, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local pageTitle = create("TextLabel", {
		Size = UDim2.new(1, -42, 0, 24),
		Position = UDim2.fromOffset(20, 12),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = theme.Text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	window:_theme(pageTitle, "TextColor3", "Text")
	local pageDescription = create("TextLabel", {
		Size = UDim2.new(1, -42, 0, 18),
		Position = UDim2.fromOffset(20, 36),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = theme.Subtext,
		TextSize = 10,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	window:_theme(pageDescription, "TextColor3", "Subtext")
	local pages = create("Frame", {
		Name = "Pages",
		Size = UDim2.new(1, -36, 1, -68),
		Position = UDim2.fromOffset(18, 60),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = content,
	})
	window.PageTitle = pageTitle
	window.PageDescription = pageDescription
	window.Pages = pages

	local resizeHandle = create("TextButton", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(1, -22, 1, -22),
		BackgroundTransparency = 1,
		Text = "◢",
		TextColor3 = theme.Subtext,
		TextTransparency = options.Resizable and 0.25 or 1,
		TextSize = 13,
		AutoButtonColor = false,
		Visible = options.Resizable,
		Parent = main,
	})
	window:_theme(resizeHandle, "TextColor3", "Subtext")
	local dragging, dragStart, startPosition = false, nil, nil
	window._maid:Give(topbar.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPosition = main.Position
		end
	end))
	window._maid:Give(UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
			shadow.Position = main.Position
		end
	end))
	window._maid:Give(UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end))

	if options.Resizable then
		local resizing, resizeStart, originalSize = false, nil, nil
		window._maid:Give(resizeHandle.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				resizing = true
				resizeStart = input.Position
				originalSize = window._size
			end
		end))
		window._maid:Give(UserInputService.InputChanged:Connect(function(input)
			if
				resizing
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				local delta = input.Position - resizeStart
				local newSize = Vector2.new(
					math.max(window._minSize.X, originalSize.X + delta.X),
					math.max(window._minSize.Y, originalSize.Y + delta.Y)
				)
				window._size = newSize
				main.Size = UDim2.fromOffset(newSize.X, window.Minimized and 62 or newSize.Y)
				shadow.Size = UDim2.fromOffset(newSize.X + 56, (window.Minimized and 62 or newSize.Y) + 56)
			end
		end))
		window._maid:Give(UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				resizing = false
			end
		end))
	end

	local toastHolder = create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.fromOffset(320, 600),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	local toastList = list(toastHolder, 9)
	toastList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	window.ToastHolder = toastHolder

	if options.ToggleKey and options.ToggleKey ~= Enum.KeyCode.Unknown then
		window._maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == options.ToggleKey then
				window:Toggle()
			end
		end))
	end

	table.insert(self.Windows, window)
	tween(main, SPRING_TWEEN, { Size = UDim2.fromOffset(size.X, size.Y), GroupTransparency = 0 })
	tween(shadow, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { ImageTransparency = 0.25 })
	tween(dim, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.78 })
	return window
end

function OzionUI:Notify(options)
	local window = self.Windows[#self.Windows]
	if window then
		return window:Notify(options)
	end
	warn("[OzionUI] Create a window before sending a notification")
end

return OzionUI
