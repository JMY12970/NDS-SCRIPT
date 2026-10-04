--[[
    OzionUI test suite -- runs against the Roblox mock in mock_roblox.lua.
    Driven by tests/run.js (node tests/run.js).
]]

local Mock = LOAD_CHUNK("tests/mock_roblox.lua")()
Mock.Install(_G)
Mock.InstallExecutorAPI(_G)

--------------------------------------------------------------- test harness --

local Passed, Failed = 0, 0
local Failures = {}

local function check(condition, message)
	if condition then
		Passed = Passed + 1
	else
		Failed = Failed + 1
		table.insert(Failures, message)
		print("    x " .. message)
	end
	return condition
end

local function section(name)
	print("\n== " .. name)
end

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		Passed = Passed + 1
		print("  ok  " .. name)
	else
		Failed = Failed + 1
		table.insert(Failures, name .. ": " .. tostring(err))
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

local function click(object)
	object.MouseButton1Down:Fire()
	object.MouseButton1Up:Fire()
	object.MouseButton1Click:Fire()
end

local function hover(object)
	object.MouseEnter:Fire()
end

local function unhover(object)
	object.MouseLeave:Fire()
end

local function keyInput(keyName)
	return {
		UserInputType = Enum.UserInputType.Keyboard,
		KeyCode = Enum.KeyCode[keyName],
		Position = Vector3.new(0, 0, 0),
	}
end

local function mouseInput(button, x, y)
	return {
		UserInputType = Enum.UserInputType[button or "MouseButton1"],
		KeyCode = Enum.KeyCode.Unknown,
		Position = Vector3.new(x or 0, y or 0, 0),
	}
end

local function setMouse(x, y)
	rawget(Mock.Services.UserInputService, "__props").MousePosition = Vector2.new(x, y)
end

--------------------------------------------------------------------- load --

print("OzionUI test suite")
section("loading")

local Library
test("Library.lua loads and returns a table", function()
	Library = LOAD_CHUNK("Library.lua")()
	assert(type(Library) == "table", "expected a table")
	assert(Library.Name == "OzionUI", "wrong library name")
	assert(type(Library.Version) == "string", "missing version")
end)

test("globals are exported through getgenv", function()
	local genv = getgenv()
	assert(genv.Toggles == Library.Toggles, "Toggles not exported")
	assert(genv.Options == Library.Options, "Options not exported")
end)

local Toggles = Library.Toggles
local Options = Library.Options

----------------------------------------------------------------- window --

section("window")

local Window, Tabs = nil, {}

test("CreateWindow builds a window", function()
	Window = Library:CreateWindow({
		Title = "OzionUI Demo",
		Footer = "test build",
		Icon = "rocket",
		NotifySide = "Right",
		ShowCustomCursor = true,
		Size = UDim2.fromOffset(660, 520),
		Resizable = true,
		AutoShow = true,
	})
	assert(Window, "no window returned")
	assert(Library.ScreenGui, "no ScreenGui created")
	assert(Library.MainFrame, "no main frame")
end)

test("the ScreenGui is protected / parented", function()
	assert(Library.GuiParentMethod == "gethui", "expected gethui parenting, got " .. tostring(Library.GuiParentMethod))
	assert(Library.ScreenGui.Parent ~= nil, "ScreenGui is not parented")
	assert(Library.ScreenGui.ResetOnSpawn == false, "ResetOnSpawn should be false")
	assert(#Library.ScreenGui.Name >= 10, "ScreenGui name should be randomised")
end)

test("tabs can be created with icons", function()
	Tabs.Main = Window:AddTab("Main", "home")
	Tabs.Visuals = Window:AddTab("Visuals", "eye")
	Tabs.Settings = Window:AddTab("UI Settings", "settings")
	assert(#Window.Tabs == 3, "expected 3 tabs")
	assert(Window.ActiveTab == Tabs.Main, "first tab should auto-select")
end)

test("switching tabs works", function()
	click(Tabs.Visuals.Button)
	assert(Window.ActiveTab == Tabs.Visuals, "tab did not switch")
	assert(Tabs.Visuals.Page.Visible, "page not visible")
	assert(Tabs.Main.Page.Visible == false, "old page still visible")
	click(Tabs.Main.Button)
	assert(Window.ActiveTab == Tabs.Main, "tab did not switch back")
end)

test("warning box", function()
	Tabs.Main:UpdateWarningBox({ Title = "Heads up", Text = "Testing", Visible = true })
	Tabs.Main:UpdateWarningBox({ Visible = false })
end)

---------------------------------------------------------------- groupboxes --

section("containers")

local Left, Right, Tabbox, TabboxA
test("groupboxes", function()
	Left = Tabs.Main:AddLeftGroupbox("Combat", "sword")
	Right = Tabs.Main:AddRightGroupbox("Visuals")
	assert(Left and Right, "groupbox creation failed")
	Left:Resize()
	Left:SetTitle("Combat")
end)

test("tabboxes", function()
	Tabbox = Tabs.Visuals:AddLeftTabbox()
	TabboxA = Tabbox:AddTab("Players")
	local TabboxB = Tabbox:AddTab("World")
	assert(#Tabbox.Tabs == 2, "expected 2 tabbox tabs")
	click(TabboxB.Button)
	assert(TabboxB.Container.Visible, "tabbox tab did not show")
	click(TabboxA.Button)
	assert(TabboxA.Container.Visible, "tabbox tab did not show")
end)

------------------------------------------------------------------ elements --

section("elements")

test("label", function()
	local Label = Left:AddLabel("Hello world")
	Label:SetText("Updated")
	assert(Label.TextLabel.Text == "Updated", "label text not updated")
	Left:AddLabel({ Text = "A long wrapped label", DoesWrap = true })
end)

test("divider", function()
	Left:AddDivider()
	Left:AddDivider("Section")
end)

local ButtonRan = 0
test("button", function()
	local Button = Left:AddButton({
		Text = "Run",
		Tooltip = "Runs the thing",
		Func = function()
			ButtonRan = ButtonRan + 1
		end,
	})
	Button:AddButton({
		Text = "Sub",
		Func = function()
			ButtonRan = ButtonRan + 10
		end,
	})

	local children = {}
	for _, child in ipairs(Button.Holder:GetChildren()) do
		if child.ClassName == "TextButton" then
			table.insert(children, child)
		end
	end
	assert(#children == 2, "expected 2 buttons in the row, got " .. #children)

	setMouse(40, 40)
	click(children[1])
	click(children[2])
	assert(ButtonRan == 11, "button callbacks did not both run (" .. ButtonRan .. ")")

	Button:SetText("Renamed")
	Button:SetDisabled(true)
	click(children[1])
	assert(ButtonRan == 11, "disabled button still fired")
	Button:SetDisabled(false)
end)

test("double click button", function()
	local Count = 0
	local Button = Left:AddButton({
		Text = "Dangerous",
		DoubleClick = true,
		Func = function()
			Count = Count + 1
		end,
	})
	local Target = Button.TextLabel
	click(Target)
	assert(Count == 0, "double-click button fired on the first click")
	assert(Target.Text == "Are you sure?", "confirmation text missing")
	click(Target)
	assert(Count == 1, "double-click button never fired")
end)

local ToggleValue = nil
test("toggle", function()
	local Toggle = Left:AddToggle("MyToggle", {
		Text = "Enable feature",
		Default = false,
		Tooltip = "toggles the feature",
		Callback = function(Value)
			ToggleValue = Value
		end,
	})
	assert(Toggles.MyToggle == Toggle, "toggle not registered in Toggles")

	local Control = Toggle.Holder:FindFirstChild("Control")
	assert(Control, "toggle control missing")
	click(Control)
	assert(Toggle.Value == true, "toggle did not switch on")
	assert(ToggleValue == true, "toggle callback never ran")

	click(Control)
	assert(Toggle.Value == false, "toggle did not switch off")

	Toggle:SetValue(true)
	assert(Toggle.Value == true, "SetValue failed")

	local Observed = nil
	Toggle:OnChanged(function(Value)
		Observed = Value
	end)
	assert(Observed == true, "OnChanged should fire immediately with the current value")
	Toggle:SetValue(false)
	assert(Observed == false, "OnChanged did not fire")

	Toggle:SetText("Renamed toggle")
	Toggle:SetDisabled(true)
	click(Control)
	assert(Toggle.Value == false, "disabled toggle changed")
	Toggle:SetDisabled(false)

	-- clicking the row label also toggles
	local ClickArea = Toggle.Holder:FindFirstChild("ClickArea")
	assert(ClickArea, "click area missing")
	click(ClickArea)
	assert(Toggle.Value == true, "row click did not toggle")
	Toggle:SetValue(false)
end)

test("checkbox", function()
	local Checkbox = Left:AddCheckbox("MyCheckbox", { Text = "Checkbox", Default = true })
	assert(Checkbox.Value == true, "default not applied")
	assert(Toggles.MyCheckbox == Checkbox, "checkbox not registered")
	click(Checkbox.Holder:FindFirstChild("Control"))
	assert(Checkbox.Value == false, "checkbox did not toggle")
end)

test("slider", function()
	local Seen = nil
	local Slider = Left:AddSlider("MySlider", {
		Text = "Speed",
		Default = 25,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = " studs",
		Callback = function(Value)
			Seen = Value
		end,
	})
	assert(Options.MySlider == Slider, "slider not registered")
	assert(Slider.Value == 25, "default not applied")
	assert(Seen == 25, "callback not fired with the default")

	Slider:SetValue(70)
	assert(Slider.Value == 70, "SetValue failed")
	assert(Seen == 70, "callback not fired")

	Slider:SetValue(99999)
	assert(Slider.Value == 100, "value not clamped to Max")
	Slider:SetValue(-5)
	assert(Slider.Value == 0, "value not clamped to Min")

	Slider:SetMax(200)
	Slider:SetValue(150)
	assert(Slider.Value == 150, "SetMax did not raise the ceiling")

	-- drag the bar: mouse at 50% of a 200px wide bar
	local Bar = Slider.Holder:FindFirstChild("Bar")
	setMouse(100, 15)
	Bar.InputBegan:Fire(mouseInput("MouseButton1", 100, 15))
	assert(Slider.Value == 100, "drag did not land on 50% (" .. tostring(Slider.Value) .. ")")
	Mock.Services.UserInputService.InputEnded:Fire(mouseInput("MouseButton1"))

	Left:AddSlider("CompactSlider", { Text = "Compact", Default = 1, Min = 0, Max = 10, Compact = true })
end)

test("slider rounding", function()
	local Slider = Left:AddSlider("Rounded", { Text = "Rounded", Default = 0.5, Min = 0, Max = 1, Rounding = 2 })
	Slider:SetValue(0.123456)
	assert(Slider.Value == 0.12, "rounding failed: " .. tostring(Slider.Value))
end)

test("dropdown (single)", function()
	local Seen = nil
	local Dropdown = Right:AddDropdown("MyDropdown", {
		Text = "Target part",
		Values = { "Head", "Torso", "Random" },
		Default = 1,
		Tooltip = "where to aim",
		Callback = function(Value)
			Seen = Value
		end,
	})
	assert(Options.MyDropdown == Dropdown, "dropdown not registered")
	assert(Dropdown.Value == "Head", "default index not resolved")

	local Display = Dropdown.Holder:FindFirstChild("Display")
	click(Display)
	assert(Dropdown.Open == true, "dropdown did not open")

	click(Dropdown.Buttons[2].Button)
	assert(Dropdown.Value == "Torso", "selection failed")
	assert(Seen == "Torso", "callback not fired")
	assert(Dropdown.Open == false, "single-select dropdown should close after picking")

	Dropdown:SetValue("Random")
	assert(Dropdown.Value == "Random", "SetValue failed")
	Dropdown:SetValues({ "A", "B" })
	assert(#Dropdown.Buttons == 2, "SetValues did not rebuild the list")
	Dropdown:SetValue("A")
	assert(Dropdown.Value == "A", "SetValue after SetValues failed")
	Dropdown:AddValue("C")
	assert(#Dropdown.Values == 3, "AddValue failed")
	Dropdown:RemoveValue("C")
	assert(#Dropdown.Values == 2, "RemoveValue failed")
end)

test("dropdown (multi)", function()
	local Dropdown = Right:AddDropdown("MultiDropdown", {
		Text = "ESP options",
		Values = { "Boxes", "Names", "Health" },
		Default = { "Boxes", "Names" },
		Multi = true,
		Searchable = true,
	})
	assert(Dropdown.Value.Boxes == true and Dropdown.Value.Names == true, "multi defaults not applied")
	assert(Dropdown.Value.Health == nil, "unexpected default")

	local Active = Dropdown:GetActiveValues()
	assert(#Active == 2, "expected 2 active values")

	click(Dropdown.Holder:FindFirstChild("Display"))
	click(Dropdown.Buttons[3].Button)
	assert(Dropdown.Value.Health == true, "multi select failed")
	assert(Dropdown.Open == true, "multi dropdown should stay open")
	click(Dropdown.Buttons[3].Button)
	assert(Dropdown.Value.Health == nil, "multi deselect failed")

	Dropdown:Toggle(false)
end)

test("dropdown (player list)", function()
	local Dropdown = Right:AddDropdown("PlayerPicker", { Text = "Player", SpecialType = "Player" })
	assert(#Dropdown.Values >= 1, "player list was not populated")
end)

test("input", function()
	local Seen = nil
	local Input = Right:AddInput("MyInput", {
		Text = "Username",
		Default = "builderman",
		Placeholder = "name...",
		Callback = function(Value)
			Seen = Value
		end,
	})
	assert(Options.MyInput == Input, "input not registered")
	assert(Input.Value == "builderman", "default not applied")

	Input.TextBox.Text = "shedletsky"
	assert(Input.Value == "shedletsky", "live text sync failed")
	assert(Seen == "shedletsky", "callback not fired")

	Input:SetValue("telamon")
	assert(Input.TextBox.Text == "telamon", "SetValue did not update the box")

	local Numeric = Right:AddInput("NumericInput", { Text = "Amount", Numeric = true, Default = "10" })
	Numeric.TextBox.Text = "abc42"
	assert(Numeric.Value == "42", "numeric filtering failed: " .. tostring(Numeric.Value))

	local Finished = Right:AddInput("FinishedInput", { Text = "Press enter", Finished = true })
	Finished.TextBox.Text = "hello"
	Finished.TextBox.FocusLost:Fire(false)
	assert(Finished.Value == "", "Finished input committed without enter")
	Finished.TextBox.Text = "hello"
	Finished.TextBox.FocusLost:Fire(true)
	assert(Finished.Value == "hello", "Finished input did not commit on enter")
end)

test("colour picker", function()
	local Seen = nil
	local Label = Right:AddLabel("ESP colour")
	local Picker = Label:AddColorPicker("ESPColor", {
		Default = Color3.fromRGB(255, 0, 0),
		Title = "ESP colour",
		Callback = function(Value)
			Seen = Value
		end,
	})
	assert(Options.ESPColor == Picker, "colour picker not registered")
	assert(Picker.Value.R == 1 and Picker.Value.G == 0, "default colour wrong")

	click(Picker.Holder)
	assert(Picker.Open == true, "picker did not open")

	Picker:SetValue(Color3.fromRGB(0, 255, 0))
	assert(math.abs(Picker.Value.G - 1) < 0.01, "SetValue failed")
	assert(Seen ~= nil, "callback not fired")

	assert(Library:ColorToHex(Color3.fromRGB(18, 52, 86)) == "#123456", "hex conversion wrong")
	local Parsed = Library:HexToColor("#00FF00")
	assert(Parsed.G == 1, "hex parsing wrong")

	Picker:Toggle(false)

	local Alpha = Right:AddLabel("Fill"):AddColorPicker("FillColor", {
		Default = Color3.new(0, 0, 1),
		Transparency = 0.5,
	})
	assert(Alpha.Transparency ~= nil, "transparency not tracked")
end)

test("key picker", function()
	local Fired = 0
	local Toggle = Right:AddToggle("AimbotToggle", { Text = "Aimbot" })
	local Picker = Toggle:AddKeyPicker("AimbotKey", {
		Default = "E",
		Mode = "Toggle",
		Text = "Aimbot",
		SyncToggleState = true,
		Callback = function()
			Fired = Fired + 1
		end,
	})
	assert(Options.AimbotKey == Picker, "key picker not registered")
	assert(Picker.Value == "E", "default key wrong")

	-- press E -> toggle mode flips state and syncs the parent toggle
	Mock.Services.UserInputService.InputBegan:Fire(keyInput("E"), false)
	assert(Picker:GetState() == true, "keybind did not activate")
	assert(Toggle.Value == true, "SyncToggleState did not update the toggle")
	assert(Fired >= 1, "keybind callback never ran")

	Mock.Services.UserInputService.InputBegan:Fire(keyInput("E"), false)
	assert(Picker:GetState() == false, "keybind did not deactivate")

	-- rebinding
	click(Picker.Holder)
	assert(Picker.Binding == true, "did not enter binding mode")
	Mock.Services.UserInputService.InputBegan:Fire(keyInput("R"), false)
	assert(Picker.Value == "R", "rebinding failed")
	assert(Picker.Binding == false, "still in binding mode")

	-- hold mode
	Picker:SetValue({ "R", "Hold" })
	assert(Picker.Mode == "Hold", "mode not applied")
	Mock.Services.UserInputService.InputBegan:Fire(keyInput("R"), false)
	assert(Picker:GetState() == true, "hold did not activate")
	Mock.Services.UserInputService.InputEnded:Fire(keyInput("R"))
	assert(Picker:GetState() == false, "hold did not release")

	-- always mode
	Picker:SetValue({ "R", "Always" })
	assert(Picker:GetState() == true, "always mode should always be true")
	Picker:SetValue({ "R", "Toggle" })

	local Clicked = 0
	Picker:OnClick(function()
		Clicked = Clicked + 1
	end)
	Picker:DoClick()
	assert(Clicked == 1, "OnClick not fired")
end)

test("pickers attached straight to a groupbox", function()
	local Picker = Left:AddColorPicker("StandalonePicker", { Default = Color3.new(1, 1, 0), Title = "Standalone" })
	assert(Options.StandalonePicker == Picker, "standalone colour picker not registered")
	local Key = Left:AddKeyPicker("StandaloneKey", { Default = "K", Text = "Standalone" })
	assert(Options.StandaloneKey == Key, "standalone key picker not registered")
	assert(Key:GetState() == false, "unexpected initial state")
end)

test("dependency boxes", function()
	local Parent = Left:AddToggle("DependencyParent", { Text = "Parent" })
	local Box = Left:AddDependencyBox()
	Box:AddToggle("DependencyChild", { Text = "Child" })
	Box:SetupDependencies({ { Parent, true } })

	assert(Box.Holder.Visible == false, "box should start hidden")
	Parent:SetValue(true)
	assert(Box.Holder.Visible == true, "box should be visible")
	Parent:SetValue(false)
	assert(Box.Holder.Visible == false, "box should be hidden again")
end)

test("image element", function()
	local Image = Right:AddImage({ Image = 123456, Height = 80 })
	Image:SetImage("rbxassetid://999")
	assert(Image.Picture.Image == "rbxassetid://999", "image not applied")
end)

test("element visibility", function()
	local Toggle = Left:AddToggle("HiddenToggle", { Text = "Hidden", Visible = false })
	assert(Toggle.Holder.Visible == false, "element should be hidden")
	Toggle:SetVisible(true)
	assert(Toggle.Holder.Visible == true, "element should be visible")
end)

------------------------------------------------------------------- hud bits --

section("hud")

test("notifications", function()
	local Note = Library:Notify("plain string notification", 2)
	assert(Note, "no notification returned")
	Library:Notify({ Title = "Title", Description = "Body", Time = 1, Type = "Success" })
	Library:Notify({ Title = "Error", Description = "Oh no", Time = 1, Type = "Error" })
	assert(#Library.Notifications >= 1, "notifications not tracked")
	Note:ChangeTitle("changed")
	Note:ChangeDescription("changed too")
	Note:Destroy()
end)

test("watermark", function()
	Library:SetWatermark("OzionUI | 60 fps | 12 ms")
	Library:SetWatermarkVisibility(true)
	assert(Library.Watermark.Visible == true, "watermark should be visible")
	Library:SetWatermarkVisibility(false)
	assert(Library.Watermark.Visible == false, "watermark should be hidden")
end)

test("keybind list", function()
	Library:SetKeybindVisibility(true)
	assert(Library.KeybindFrame.Visible == true, "keybind list should be visible")
	Library:SetKeybindVisibility(false)
end)

test("notify side", function()
	Library:SetNotifySide("Left")
	assert(Library.NotifySide == "Left", "notify side not applied")
	Library:SetNotifySide("Right")
end)

test("draggable extras", function()
	local Button = Library:AddDraggableButton("Panic", function() end)
	Button:SetText("Panic!")
	Button:SetVisible(false)
	local Menu = Library:AddDraggableMenu("Quick menu")
	Menu:AddToggle("QuickToggle", { Text = "Quick" })
	Menu:AddButton({ Text = "Quick button", Func = function() end })
end)

------------------------------------------------------------------- theming --

section("theming")

test("accent colour updates the registry", function()
	local Before = #Library.Registry
	assert(Before > 50, "registry looks empty (" .. Before .. ")")
	Library:SetAccent(Color3.fromRGB(0, 200, 255))
	assert(Library.Scheme.AccentColor.B == 1, "accent not applied")
	Library:UpdateColorsUsingRegistry()
end)

test("font swapping", function()
	Library:SetFont(Enum.Font.Code)
	assert(Library.Scheme.Font == Enum.Font.Code, "font not applied")
	Library:SetFont("Gotham")
	assert(Library.Scheme.Font == Enum.Font.Gotham, "font by name failed")
end)

test("dpi scale", function()
	Library:SetDPIScale(125)
	assert(math.abs(Library.DPIScale - 1.25) < 0.001, "dpi scale not applied")
	assert(math.abs(Library.MainScale.Scale - 1.25) < 0.001, "scale object not updated")
	Library:SetDPIScale(100)
end)

test("colour helpers", function()
	local Dark = Library:GetDarkerColor(Color3.new(0.5, 0.5, 0.5))
	assert(Dark.R < 0.5, "GetDarkerColor did not darken")
	local Light = Library:GetLighterColor(Color3.new(0.5, 0.5, 0.5))
	assert(Light.R > 0.5, "GetLighterColor did not lighten")
end)

---------------------------------------------------------------- behaviour --

section("behaviour")

test("menu visibility toggling", function()
	Mock.Flush()
	assert(Library.Toggled == true, "AutoShow should have opened the menu")
	Library:Toggle(false)
	Mock.Flush()
	assert(Library.Toggled == false, "menu did not close")
	assert(Library.MainFrame.Visible == false, "frame should be hidden")
	Library:Toggle(true)
	assert(Library.Toggled == true, "menu did not open")
end)

test("menu keybind", function()
	Library.MenuKeybind = Enum.KeyCode.RightControl
	Mock.Services.UserInputService.InputBegan:Fire(keyInput("RightControl"), false)
	Mock.Flush()
	assert(Library.Toggled == false, "keybind did not close the menu")
	Mock.Services.UserInputService.InputBegan:Fire(keyInput("RightControl"), false)
	assert(Library.Toggled == true, "keybind did not open the menu")
end)

test("keybind is ignored while typing", function()
	rawget(Mock.Services.UserInputService, "__props").FocusedTextBox = Instance.new("TextBox")
	Mock.Services.UserInputService.InputBegan:Fire(keyInput("RightControl"), false)
	assert(Library.Toggled == true, "keybind fired while a text box was focused")
	rawget(Mock.Services.UserInputService, "__props").FocusedTextBox = nil
end)

test("search filters elements", function()
	local Search = Library.Window.Sidebar:FindFirstChild("Search")
	assert(Search, "search box missing")
	Search.Text = "zzzzz-no-match"
	Search.Text = ""
end)

test("SafeCallback contains errors", function()
	local Count = #Mock.Warnings
	Library:SafeCallback(function()
		error("intentional test error")
	end)
	assert(#Mock.Warnings > Count, "error was not warned about")
end)

test("hover animations do not error", function()
	local Toggle = Toggles.MyToggle
	local Control = Toggle.Holder:FindFirstChild("Control")
	hover(Control)
	unhover(Control)
	hover(Toggle.Holder:FindFirstChild("ClickArea"))
	unhover(Toggle.Holder:FindFirstChild("ClickArea"))
	hover(Library.Window.Tabs[2].Button)
	unhover(Library.Window.Tabs[2].Button)
end)

test("window dragging", function()
	local TitleBar = Library.Window.TitleBar
	TitleBar.InputBegan:Fire(mouseInput("MouseButton1", 100, 20))
	Mock.Services.UserInputService.InputChanged:Fire(mouseInput("MouseMovement", 140, 60))
	assert(Library.MainFrame.Position.X.Offset ~= 0, "window did not move")
	TitleBar.InputEnded:Fire(mouseInput("MouseButton1", 140, 60))
end)

test("window resizing", function()
	local Grip = Library.MainFrame:FindFirstChild("Resize")
	assert(Grip, "resize grip missing")
	Grip.InputBegan:Fire(mouseInput("MouseButton1", 600, 500))
	Mock.Services.UserInputService.InputChanged:Fire(mouseInput("MouseMovement", 700, 600))
	assert(Library.MainFrame.Size.X.Offset == 760, "resize failed: " .. tostring(Library.MainFrame.Size.X.Offset))
	Mock.Services.UserInputService.InputEnded:Fire(mouseInput("MouseButton1"))
end)

test("render loop ticks without errors", function()
	for _ = 1, 3 do
		Mock.Services.RunService.RenderStepped:Fire(0.016)
	end
end)

test("tooltips", function()
	local Toggle = Toggles.MyToggle
	hover(Toggle.Holder)
	assert(Library.TooltipHolder.Visible == true, "tooltip did not show")
	Mock.Services.RunService.RenderStepped:Fire(0.016)
	unhover(Toggle.Holder)
	assert(Library.TooltipHolder.Visible == false, "tooltip did not hide")
end)

test("clicking outside closes popups", function()
	local Dropdown = Options.MyDropdown
	click(Dropdown.Holder:FindFirstChild("Display"))
	assert(Dropdown.Open == true, "dropdown did not open")
	setMouse(5000, 5000)
	Mock.Services.UserInputService.InputBegan:Fire(mouseInput("MouseButton1", 5000, 5000), false)
	assert(Dropdown.Open == false, "dropdown did not close when clicking away")
end)

------------------------------------------------------------------- addons --

if FILES["addons/SaveManager.lua"] then
	section("SaveManager")

	local SaveManager
	test("loads", function()
		SaveManager = LOAD_CHUNK("addons/SaveManager.lua")()
		SaveManager:SetLibrary(Library)
		SaveManager:SetFolder("OzionUITests")
		SaveManager:IgnoreThemeSettings()
		SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
	end)

	test("builds its config section", function()
		SaveManager:BuildConfigSection(Tabs.Settings)
		assert(Options.SaveManager_ConfigName, "config name input missing")
		assert(Options.SaveManager_ConfigList, "config list dropdown missing")
	end)

	test("saves, changes, then restores values", function()
		Toggles.MyToggle:SetValue(true)
		Options.MySlider:SetValue(42)
		Options.MyInput:SetValue("saved-name")
		Options.ESPColor:SetValue(Color3.fromRGB(10, 20, 30))
		Options.AimbotKey:SetValue({ "Q", "Hold" })

		local ok, err = SaveManager:Save("unit-test")
		assert(ok, "save failed: " .. tostring(err))
		assert(isfile("OzionUITests/settings/unit-test.json"), "config file was not written")

		Toggles.MyToggle:SetValue(false)
		Options.MySlider:SetValue(1)
		Options.MyInput:SetValue("changed")
		Options.AimbotKey:SetValue({ "Z", "Toggle" })

		local ok2, err2 = SaveManager:Load("unit-test")
		assert(ok2, "load failed: " .. tostring(err2))

		assert(Toggles.MyToggle.Value == true, "toggle not restored")
		assert(Options.MySlider.Value == 42, "slider not restored")
		assert(Options.MyInput.Value == "saved-name", "input not restored")
		assert(Options.AimbotKey.Value == "Q", "keybind not restored")
		assert(Options.AimbotKey.Mode == "Hold", "keybind mode not restored")
		assert(math.abs(Options.ESPColor.Value.G * 255 - 20) < 1.5, "colour not restored")
	end)

	test("lists and deletes configs", function()
		local list = SaveManager:RefreshConfigList()
		local found = false
		for _, name in pairs(list) do
			if name == "unit-test" then
				found = true
			end
		end
		assert(found, "saved config not listed")

		assert(SaveManager:Delete("unit-test"), "delete failed")
		assert(not isfile("OzionUITests/settings/unit-test.json"), "config file still exists")
	end)

	test("autoload", function()
		SaveManager:Save("auto")
		SaveManager:SetAutoLoadConfig("auto")
		assert(isfile("OzionUITests/settings/autoload.txt"), "autoload marker missing")
		SaveManager:LoadAutoloadConfig()
	end)
end

if FILES["addons/ThemeManager.lua"] then
	section("ThemeManager")

	local ThemeManager
	test("loads", function()
		ThemeManager = LOAD_CHUNK("addons/ThemeManager.lua")()
		ThemeManager:SetLibrary(Library)
		ThemeManager:SetFolder("OzionUITests")
	end)

	test("applies built in themes", function()
		for Name in pairs(ThemeManager.BuiltInThemes) do
			ThemeManager:ApplyTheme(Name)
		end
		ThemeManager:ApplyTheme("Ozion")
	end)

	test("builds its theme section", function()
		ThemeManager:ApplyToTab(Tabs.Settings)
		assert(Options.ThemeManager_ThemeList, "theme dropdown missing")
		assert(Options.BackgroundColor, "background colour picker missing")
	end)

	test("saves and loads a custom theme", function()
		Options.AccentColor:SetValue(Color3.fromRGB(255, 120, 0))
		ThemeManager:SaveCustomTheme("my-theme")
		ThemeManager:ApplyTheme("Fatality")
		ThemeManager:ApplyTheme("my-theme")
		assert(math.abs(Library.Scheme.AccentColor.R - 1) < 0.02, "custom theme not restored")
		ThemeManager:Delete("my-theme")
	end)

	test("default theme persistence", function()
		ThemeManager:SaveDefault("Jester")
		assert(isfile("OzionUITests/themes/default.txt"), "default theme marker missing")
		ThemeManager:LoadDefault()
	end)
end

--------------------------------------------------------------------- unload --

section("unload")

test("unload tears everything down", function()
	local Ran = false
	Library:OnUnload(function()
		Ran = true
	end)

	local GuiCount = #Mock.Services.CoreGui:GetChildren()
	assert(GuiCount > 0, "no gui parented to CoreGui")

	Library:Unload()
	assert(Ran, "unload callback did not run")
	assert(Library.Unloaded == true, "Unloaded flag not set")
	assert(#Mock.Services.CoreGui:GetChildren() == 0, "ScreenGui was not destroyed")
	assert(#Library.Connections == 0, "connections were not disconnected")
	assert(Mock.Services.UserInputService.MouseIconEnabled == true, "mouse icon was not restored")
	assert(next(Library.Toggles) == nil, "Toggles not cleared")
end)

test("events after unload are harmless", function()
	Mock.Services.UserInputService.InputBegan:Fire(keyInput("RightControl"), false)
	Mock.Services.RunService.RenderStepped:Fire(0.016)
end)

--------------------------------------------------------- the example script --

if FILES["Example.lua"] then
	section("Example.lua")

	test("runs verbatim with HttpGet + loadstring stubbed", function()
		-- pretend the raw github urls resolve to the files in this repo
		rawget(Mock.Services.CoreGui, "__children")[1] = nil
		function Mock.Services.CoreGui:GetChildren()
			local out = {}
			for i, c in ipairs(rawget(self, "__children")) do
				out[i] = c
			end
			return out
		end

		_G.loadstring = function(source, name)
			local fn, err = load(source, name or "@httpget")
			if not fn then
				error("loadstring failed: " .. tostring(err), 0)
			end
			return fn
		end

		local gameProps = rawget(_G.game, "__props")
		gameProps.PlaceId = 1818
		_G.game.HttpGet = function(_, url)
			for _, candidate in ipairs({ url:match("([^/]+/[^/]+%.lua)$"), url:match("([^/]+%.lua)$") }) do
				if FILES[candidate] then
					return FILES[candidate]
				end
			end
			error("HttpGet: nothing mocked for " .. tostring(url), 0)
		end
		_G.game.HttpGetAsync = _G.game.HttpGet

		local ExampleLibrary = LOAD_CHUNK("Example.lua")()
		Mock.Flush()

		assert(ExampleLibrary, "example returned nothing")
		assert(ExampleLibrary.Window, "example did not create a window")
		assert(#ExampleLibrary.Window.Tabs == 4, "expected 4 tabs")
		assert(ExampleLibrary.Toggles.AutoFarm, "AutoFarm toggle missing")
		assert(ExampleLibrary.Options.EspColor, "EspColor picker missing")
		assert(ExampleLibrary.Options.TargetPlayer, "player dropdown missing")
		assert(ExampleLibrary.ToggleKeybind == ExampleLibrary.Options.MenuKeybind, "menu keybind not wired up")
		assert(ExampleLibrary.Watermark.Visible == true, "watermark should be on")

		-- drive a couple of things to be sure the wiring is live
		ExampleLibrary.Toggles.CustomSpeed:SetValue(true)
		ExampleLibrary.Options.FarmRadius:SetValue(120)
		assert(ExampleLibrary.Options.WalkSpeed, "dependency box element missing")

		ExampleLibrary:Unload()
	end)
end

--------------------------------------------------------------------- report --

Mock.Flush()

print("")
print(("-"):rep(52))
print(("passed: %d    failed: %d    instances: %d    tweens: %d"):format(Passed, Failed, Mock.Instances, Mock.TweensCreated))
print(("-"):rep(52))

if Failed > 0 then
	for _, failure in ipairs(Failures) do
		print("  * " .. failure)
	end
	error(("%d test(s) failed"):format(Failed), 0)
end

print("all good")
return true
