--[[
    OzionUI :: ThemeManager
    Swaps the five scheme colours (plus font / scale / animation settings) and
    remembers the user's pick between sessions.

        local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
        ThemeManager:SetLibrary(Library)
        ThemeManager:SetFolder("MyHub")
        ThemeManager:ApplyToTab(Tabs["UI Settings"])

    Files land in:  <Folder>/themes/<name>.json
]]

local HttpService = game:GetService("HttpService")

local ThemeManager = {
	Folder = "OzionUI",
	Library = nil,
	BuiltInThemes = {},
	CustomThemes = {},
}

local FS = {
	isfolder = isfolder,
	makefolder = makefolder,
	isfile = isfile,
	readfile = readfile,
	writefile = writefile,
	delfile = delfile,
	listfiles = listfiles,
}

local function SafeCall(Function, ...)
	if type(Function) ~= "function" then
		return false
	end
	local Results = { pcall(Function, ...) }
	local Ok = table.remove(Results, 1)
	return Ok, Results[1]
end

---------------------------------------------------------------- the themes --

-- hex strings keep the file format identical to Obsidian / Linoria themes
ThemeManager.BuiltInThemes = {
	Ozion = {
		BackgroundColor = "0C0C10",
		MainColor = "14141B",
		AccentColor = "7D5AFF",
		OutlineColor = "282834",
		FontColor = "F0F0FA",
	},
	Midnight = {
		BackgroundColor = "0B0E14",
		MainColor = "131722",
		AccentColor = "3D7EFF",
		OutlineColor = "232A3A",
		FontColor = "E6ECFF",
	},
	Fatality = {
		BackgroundColor = "1E1842",
		MainColor = "191335",
		AccentColor = "C50754",
		OutlineColor = "322A5E",
		FontColor = "FFFFFF",
	},
	Jester = {
		BackgroundColor = "1B1B1B",
		MainColor = "242424",
		AccentColor = "DB4D4D",
		OutlineColor = "3B3B3B",
		FontColor = "FFFFFF",
	},
	Mint = {
		BackgroundColor = "0F1A17",
		MainColor = "16241F",
		AccentColor = "3CE0A3",
		OutlineColor = "24382F",
		FontColor = "E8FFF6",
	},
	["Tokyo Night"] = {
		BackgroundColor = "1A1B26",
		MainColor = "24283B",
		AccentColor = "7AA2F7",
		OutlineColor = "343A52",
		FontColor = "C0CAF5",
	},
	Vaporwave = {
		BackgroundColor = "16102A",
		MainColor = "1F1740",
		AccentColor = "FF5FD2",
		OutlineColor = "342A5E",
		FontColor = "F2E9FF",
	},
	Ember = {
		BackgroundColor = "120D0B",
		MainColor = "1C1513",
		AccentColor = "FF6B35",
		OutlineColor = "33251F",
		FontColor = "FFEFE6",
	},
	Quartz = {
		BackgroundColor = "17171C",
		MainColor = "212128",
		AccentColor = "A8A8C0",
		OutlineColor = "32323C",
		FontColor = "F2F2F7",
	},
	Monochrome = {
		BackgroundColor = "0A0A0A",
		MainColor = "151515",
		AccentColor = "FFFFFF",
		OutlineColor = "2A2A2A",
		FontColor = "F5F5F5",
	},
	Ubuntu = {
		BackgroundColor = "1D1715",
		MainColor = "2A211E",
		AccentColor = "E95420",
		OutlineColor = "3E312C",
		FontColor = "FFF3EC",
	},
	Bloom = {
		BackgroundColor = "140F16",
		MainColor = "1D1620",
		AccentColor = "FF4FA3",
		OutlineColor = "32263A",
		FontColor = "FFEAF4",
	},
}

local SchemeKeys = { "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor" }

----------------------------------------------------------------- plumbing --

function ThemeManager:SetLibrary(Library)
	self.Library = Library
	return self
end

function ThemeManager:SetFolder(Folder)
	self.Folder = Folder
	self:BuildFolderTree()
	return self
end

function ThemeManager:GetThemesPath()
	return self.Folder .. "/themes"
end

function ThemeManager:BuildFolderTree()
	if not FS.makefolder then
		return self
	end
	for _, Path in pairs({ self.Folder, self:GetThemesPath() }) do
		local Ok, Exists = SafeCall(FS.isfolder, Path)
		if not Ok or not Exists then
			SafeCall(FS.makefolder, Path)
		end
	end
	return self
end

function ThemeManager:IsSupported()
	return type(FS.writefile) == "function" and type(FS.readfile) == "function"
end

------------------------------------------------------------------- themes --

function ThemeManager:GetCustomThemeList()
	local List = {}
	if not FS.listfiles then
		return List
	end

	local Ok, Files = SafeCall(FS.listfiles, self:GetThemesPath())
	if not Ok or type(Files) ~= "table" then
		return List
	end

	for _, Path in pairs(Files) do
		if type(Path) == "string" and Path:sub(-5) == ".json" then
			local Name = Path:match("([^/\\]+)%.json$")
			if Name then
				table.insert(List, Name)
			end
		end
	end

	table.sort(List)
	return List
end

function ThemeManager:GetTheme(Name)
	if self.BuiltInThemes[Name] then
		return self.BuiltInThemes[Name], "builtin"
	end

	local Path = self:GetThemesPath() .. "/" .. tostring(Name) .. ".json"
	if FS.isfile and FS.isfile(Path) then
		local Ok, Contents = SafeCall(FS.readfile, Path)
		if Ok then
			local Decoded
			local Success = pcall(function()
				Decoded = HttpService:JSONDecode(Contents)
			end)
			if Success and type(Decoded) == "table" then
				return Decoded, "custom"
			end
		end
	end

	return nil
end

function ThemeManager:ApplyTheme(Name)
	assert(self.Library, "ThemeManager:SetLibrary(Library) must be called first")

	local Theme = self:GetTheme(Name)
	if not Theme then
		return false, "unknown theme '" .. tostring(Name) .. "'"
	end

	local Library = self.Library

	for _, Key in pairs(SchemeKeys) do
		local Value = Theme[Key]
		if Value then
			local Color = type(Value) == "string" and Library:HexToColor(Value) or Value
			if Color then
				Library.Scheme[Key] = Color
			end
		end
	end

	if Theme.Font then
		Library:SetFont(Theme.Font)
	end

	Library:UpdateColorsUsingRegistry()
	self:UpdatePickers()
	self.CurrentTheme = Name
	return true
end

function ThemeManager:UpdatePickers()
	local Library = self.Library
	if not Library then
		return
	end
	for _, Key in pairs(SchemeKeys) do
		local Picker = Library.Options[Key]
		if Picker and Picker.SetValue then
			pcall(function()
				Picker:SetValue(Library.Scheme[Key], nil, true)
			end)
		end
	end
end

function ThemeManager:GetCurrentThemeTable()
	local Library = self.Library
	local Theme = {}
	for _, Key in pairs(SchemeKeys) do
		Theme[Key] = Library:ColorToHex(Library.Scheme[Key]):gsub("#", "")
	end
	return Theme
end

function ThemeManager:SaveCustomTheme(Name)
	if not Name or Name:gsub(" ", "") == "" then
		return false, "no theme name given"
	end
	if not self:IsSupported() then
		return false, "your executor does not support file writing"
	end

	self:BuildFolderTree()

	local Encoded
	local Ok = pcall(function()
		Encoded = HttpService:JSONEncode(self:GetCurrentThemeTable())
	end)
	if not Ok then
		return false, "failed to encode the theme"
	end

	SafeCall(FS.writefile, self:GetThemesPath() .. "/" .. Name .. ".json", Encoded)
	return true
end

function ThemeManager:Delete(Name)
	local Path = self:GetThemesPath() .. "/" .. tostring(Name) .. ".json"
	if not FS.isfile or not FS.isfile(Path) then
		return false, "that theme does not exist"
	end
	SafeCall(FS.delfile, Path)
	return true
end

------------------------------------------------------------------ default --

function ThemeManager:GetDefaultPath()
	return self:GetThemesPath() .. "/default.txt"
end

function ThemeManager:SaveDefault(Name)
	self:BuildFolderTree()
	SafeCall(FS.writefile, self:GetDefaultPath(), tostring(Name))
	return self
end

function ThemeManager:LoadDefault()
	local Path = self:GetDefaultPath()
	local Name = "Ozion"

	if FS.isfile and FS.isfile(Path) then
		local Ok, Contents = SafeCall(FS.readfile, Path)
		if Ok and Contents and Contents ~= "" then
			Name = Contents
		end
	end

	if not self:GetTheme(Name) then
		Name = "Ozion"
	end

	return self:ApplyTheme(Name)
end

------------------------------------------------------------------- the UI --

function ThemeManager:ApplyToGroupbox(Groupbox)
	assert(self.Library, "ThemeManager:SetLibrary(Library) must be called first")

	local Library = self.Library
	local Options = Library.Options

	local ThemeNames = {}
	for Name in pairs(self.BuiltInThemes) do
		table.insert(ThemeNames, Name)
	end
	table.sort(ThemeNames)

	Groupbox:AddDropdown("ThemeManager_ThemeList", {
		Text = "Theme",
		Values = ThemeNames,
		Default = self.CurrentTheme or "Ozion",
		Searchable = true,
		Callback = function(Value)
			if Value then
				self:ApplyTheme(Value)
			end
		end,
	})

	local FontNames = {}
	for Name in pairs(Library.Fonts) do
		table.insert(FontNames, Name)
	end
	table.sort(FontNames)

	Groupbox:AddDropdown("ThemeManager_Font", {
		Text = "Font",
		Values = FontNames,
		Default = "GothamMedium",
		Callback = function(Value)
			Library:SetFont(Value)
		end,
	})

	Groupbox:AddSlider("ThemeManager_DPIScale", {
		Text = "UI scale",
		Default = 100,
		Min = 75,
		Max = 150,
		Rounding = 0,
		Suffix = "%",
		HideMax = true,
		Callback = function(Value)
			Library:SetDPIScale(Value)
		end,
	})

	Groupbox:AddToggle("ThemeManager_Animations", {
		Text = "Animations",
		Default = Library.Animations,
		Tooltip = "Turn every tween off if you want the absolute cheapest menu.",
		Callback = function(Value)
			Library.Animations = Value
		end,
	})

	Groupbox:AddToggle("ThemeManager_CustomCursor", {
		Text = "Custom cursor",
		Default = Library.ShowCustomCursor,
		Callback = function(Value)
			Library.ShowCustomCursor = Value
		end,
	})

	Groupbox:AddDivider()

	local Labels = {
		BackgroundColor = "Background",
		MainColor = "Panels",
		AccentColor = "Accent",
		OutlineColor = "Outlines",
		FontColor = "Text",
	}

	for _, Key in pairs(SchemeKeys) do
		Groupbox:AddLabel(Labels[Key]):AddColorPicker(Key, {
			Default = Library.Scheme[Key],
			Title = Labels[Key],
			Callback = function(Value)
				Library.Scheme[Key] = Value
				Library:UpdateColorsUsingRegistry()
			end,
		})
	end

	Groupbox:AddDivider()

	Groupbox:AddInput("ThemeManager_CustomThemeName", {
		Text = "Custom theme name",
		Placeholder = "my-theme",
	})

	Groupbox:AddDropdown("ThemeManager_CustomThemeList", {
		Text = "Saved themes",
		Values = self:GetCustomThemeList(),
		AllowNull = true,
	})

	local function RefreshCustom()
		Options.ThemeManager_CustomThemeList:SetValues(self:GetCustomThemeList())
	end

	Groupbox:AddButton({
		Text = "Save theme",
		Func = function()
			local Name = Options.ThemeManager_CustomThemeName.Value
			local Ok, Error = self:SaveCustomTheme(Name)
			if not Ok then
				return Library:Notify({ Title = "Theme", Description = tostring(Error), Time = 4, Type = "Error" })
			end
			RefreshCustom()
			Library:Notify({ Title = "Theme saved", Description = "Created '" .. Name .. "'.", Time = 4, Type = "Success" })
		end,
	}):AddButton({
		Text = "Load theme",
		Func = function()
			local Name = Options.ThemeManager_CustomThemeList.Value
			if not Name then
				return Library:Notify({ Title = "Theme", Description = "Pick a saved theme first.", Time = 4, Type = "Warning" })
			end
			self:ApplyTheme(Name)
			Library:Notify({ Title = "Theme applied", Description = Name, Time = 3, Type = "Success" })
		end,
	})

	Groupbox:AddButton({
		Text = "Delete theme",
		DoubleClick = true,
		Func = function()
			local Name = Options.ThemeManager_CustomThemeList.Value
			if not Name then
				return
			end
			self:Delete(Name)
			RefreshCustom()
			Library:Notify({ Title = "Theme deleted", Description = Name, Time = 3 })
		end,
	}):AddButton({
		Text = "Set as default",
		Func = function()
			local Name = Options.ThemeManager_ThemeList.Value or Options.ThemeManager_CustomThemeList.Value
			if not Name then
				return
			end
			self:SaveDefault(Name)
			Library:Notify({ Title = "Default theme", Description = "'" .. Name .. "' will load on launch.", Time = 4, Type = "Success" })
		end,
	})

	self.ThemeGroupbox = Groupbox
	return Groupbox
end

function ThemeManager:ApplyToTab(Tab, Side)
	local Groupbox = (Side == "Left") and Tab:AddLeftGroupbox("Appearance", "palette")
		or Tab:AddRightGroupbox("Appearance", "palette")
	return self:ApplyToGroupbox(Groupbox)
end

-- Obsidian / Linoria aliases
ThemeManager.BuildThemeSection = ThemeManager.ApplyToTab
ThemeManager.SetDefault = ThemeManager.SaveDefault

return ThemeManager
