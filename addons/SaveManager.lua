--[[
    OzionUI :: SaveManager
    Persists every registered element to a JSON file so users can keep their
    settings between sessions.

        local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
        SaveManager:SetLibrary(Library)
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
        SaveManager:SetFolder("MyHub/MyGame")
        SaveManager:BuildConfigSection(Tabs["UI Settings"])
        SaveManager:LoadAutoloadConfig()

    Files land in:  <Folder>/settings/<name>.json
]]

local HttpService = game:GetService("HttpService")

local SaveManager = {
	Folder = "OzionUI",
	SubFolder = "",
	Library = nil,
	Ignore = {},
	Options = nil,
	Toggles = nil,
}

------------------------------------------------------------------ file IO --

local FS = {
	isfolder = isfolder,
	makefolder = makefolder,
	isfile = isfile,
	readfile = readfile,
	writefile = writefile,
	delfile = delfile,
	listfiles = listfiles,
}

function SaveManager:IsSupported()
	return type(FS.writefile) == "function" and type(FS.readfile) == "function" and type(FS.isfile) == "function"
end

local function SafeCall(Function, ...)
	if type(Function) ~= "function" then
		return false, "unsupported executor function"
	end
	local Results = { pcall(Function, ...) }
	local Ok = table.remove(Results, 1)
	return Ok, Results[1]
end

----------------------------------------------------------------- parsers --

SaveManager.Parser = {
	Toggle = {
		Save = function(Index, Object)
			return { type = "Toggle", idx = Index, value = Object.Value }
		end,
		Load = function(Index, Data, Self)
			local Toggle = Self.Toggles[Index]
			if Toggle then
				Toggle:SetValue(Data.value)
			end
		end,
	},
	Slider = {
		Save = function(Index, Object)
			return { type = "Slider", idx = Index, value = tostring(Object.Value) }
		end,
		Load = function(Index, Data, Self)
			local Slider = Self.Options[Index]
			if Slider then
				Slider:SetValue(tonumber(Data.value) or 0)
			end
		end,
	},
	Dropdown = {
		Save = function(Index, Object)
			return { type = "Dropdown", idx = Index, value = Object.Value, multi = Object.Multi }
		end,
		Load = function(Index, Data, Self)
			local Dropdown = Self.Options[Index]
			if Dropdown then
				Dropdown:SetValue(Data.value)
			end
		end,
	},
	ColorPicker = {
		Save = function(Index, Object, Self)
			return {
				type = "ColorPicker",
				idx = Index,
				value = Self.Library:ColorToHex(Object.Value),
				transparency = Object.Transparency,
			}
		end,
		Load = function(Index, Data, Self)
			local Picker = Self.Options[Index]
			if Picker then
				Picker:SetValue(Data.value, Data.transparency)
			end
		end,
	},
	KeyPicker = {
		Save = function(Index, Object)
			return { type = "KeyPicker", idx = Index, value = { Object.Value, Object.Mode } }
		end,
		Load = function(Index, Data, Self)
			local Picker = Self.Options[Index]
			if Picker then
				Picker:SetValue(Data.value)
			end
		end,
	},
	Input = {
		Save = function(Index, Object)
			return { type = "Input", idx = Index, text = Object.Value }
		end,
		Load = function(Index, Data, Self)
			local Input = Self.Options[Index]
			if Input and type(Data.text) == "string" then
				Input:SetValue(Data.text)
			end
		end,
	},
}

------------------------------------------------------------------- config --

function SaveManager:SetLibrary(Library)
	self.Library = Library
	self.Options = Library.Options
	self.Toggles = Library.Toggles
	return self
end

function SaveManager:SetFolder(Folder)
	self.Folder = Folder
	self:BuildFolderTree()
	return self
end

function SaveManager:SetSubFolder(SubFolder)
	self.SubFolder = SubFolder
	self:BuildFolderTree()
	return self
end

function SaveManager:SetIgnoreIndexes(List)
	for _, Index in pairs(List or {}) do
		self.Ignore[Index] = true
	end
	return self
end

function SaveManager:IgnoreThemeSettings()
	self:SetIgnoreIndexes({
		"BackgroundColor",
		"MainColor",
		"AccentColor",
		"OutlineColor",
		"FontColor",
		"ThemeManager_ThemeList",
		"ThemeManager_CustomThemeList",
		"ThemeManager_CustomThemeName",
		"ThemeManager_Font",
		"ThemeManager_DPIScale",
	})
	return self
end

function SaveManager:GetPaths()
	local Base = self.Folder
	local Settings = Base .. "/settings"
	if self.SubFolder and self.SubFolder ~= "" then
		Settings = Base .. "/settings/" .. self.SubFolder
	end
	return Base, Settings
end

function SaveManager:BuildFolderTree()
	if not FS.makefolder then
		return
	end
	local Base, Settings = self:GetPaths()
	local Paths = { Base, Base .. "/settings", Base .. "/themes", Settings }
	for _, Path in pairs(Paths) do
		if not SafeCall(FS.isfolder, Path) or not FS.isfolder(Path) then
			SafeCall(FS.makefolder, Path)
		end
	end
	return self
end

--------------------------------------------------------------- save / load --

function SaveManager:GetConfigPath(Name)
	local _, Settings = self:GetPaths()
	return Settings .. "/" .. tostring(Name) .. ".json"
end

function SaveManager:Save(Name)
	if not Name or Name == "" then
		return false, "no config name given"
	end
	if not self:IsSupported() then
		return false, "your executor does not support file writing"
	end

	self:BuildFolderTree()

	local Data = { version = 1, objects = {} }

	for Index, Toggle in pairs(self.Toggles) do
		if not self.Ignore[Index] then
			table.insert(Data.objects, self.Parser.Toggle.Save(Index, Toggle, self))
		end
	end

	for Index, Option in pairs(self.Options) do
		local Parser = self.Parser[Option.Type]
		if Parser and not self.Ignore[Index] then
			table.insert(Data.objects, Parser.Save(Index, Option, self))
		end
	end

	local Ok, Encoded = pcall(function()
		return HttpService:JSONEncode(Data)
	end)
	if not Ok then
		return false, "failed to encode the config"
	end

	local Written = SafeCall(FS.writefile, self:GetConfigPath(Name), Encoded)
	if not Written then
		return false, "failed to write the config file"
	end

	return true
end

function SaveManager:Load(Name)
	if not Name or Name == "" then
		return false, "no config name given"
	end

	local Path = self:GetConfigPath(Name)
	if not FS.isfile or not FS.isfile(Path) then
		return false, "that config does not exist"
	end

	local Ok, Contents = SafeCall(FS.readfile, Path)
	if not Ok then
		return false, "failed to read the config file"
	end

	local Decoded
	local Success = pcall(function()
		Decoded = HttpService:JSONDecode(Contents)
	end)
	if not Success or type(Decoded) ~= "table" then
		return false, "that config is corrupted"
	end

	for _, Object in pairs(Decoded.objects or {}) do
		local Parser = self.Parser[Object.type]
		if Parser and not self.Ignore[Object.idx] then
			pcall(function()
				Parser.Load(Object.idx, Object, self)
			end)
		end
	end

	return true
end

function SaveManager:Delete(Name)
	local Path = self:GetConfigPath(Name)
	if not FS.isfile or not FS.isfile(Path) then
		return false, "that config does not exist"
	end
	local Ok = SafeCall(FS.delfile, Path)
	return Ok, Ok and nil or "failed to delete the config"
end

function SaveManager:RefreshConfigList()
	local List = {}
	if not FS.listfiles then
		return List
	end

	local _, Settings = self:GetPaths()
	local Ok, Files = SafeCall(FS.listfiles, Settings)
	if not Ok or type(Files) ~= "table" then
		return List
	end

	for _, Path in pairs(Files) do
		if type(Path) == "string" and Path:sub(-5) == ".json" then
			local Name = Path:match("([^/\\]+)%.json$")
			if Name and Name ~= "autoload" then
				table.insert(List, Name)
			end
		end
	end

	table.sort(List)
	return List
end

---------------------------------------------------------------- autoload --

function SaveManager:GetAutoloadPath()
	local _, Settings = self:GetPaths()
	return Settings .. "/autoload.txt"
end

function SaveManager:SetAutoLoadConfig(Name)
	self:BuildFolderTree()
	SafeCall(FS.writefile, self:GetAutoloadPath(), tostring(Name))
	return self
end

function SaveManager:GetAutoloadConfig()
	local Path = self:GetAutoloadPath()
	if FS.isfile and FS.isfile(Path) then
		local Ok, Name = SafeCall(FS.readfile, Path)
		if Ok and Name and Name ~= "" then
			return Name
		end
	end
	return nil
end

function SaveManager:DeleteAutoLoadConfig()
	local Path = self:GetAutoloadPath()
	if FS.isfile and FS.isfile(Path) then
		SafeCall(FS.delfile, Path)
	end
	return self
end

function SaveManager:LoadAutoloadConfig()
	local Name = self:GetAutoloadConfig()
	if not Name then
		return false
	end

	local Ok, Error = self:Load(Name)
	if not Ok then
		if self.Library then
			self.Library:Notify({
				Title = "Autoload failed",
				Description = tostring(Error),
				Time = 5,
				Type = "Error",
			})
		end
		return false
	end

	if self.Library then
		self.Library:Notify({
			Title = "Config loaded",
			Description = "Automatically loaded '" .. Name .. "'.",
			Time = 4,
			Type = "Success",
		})
	end
	return true
end

------------------------------------------------------------------ the UI --

function SaveManager:BuildConfigSection(Tab, Side)
	assert(self.Library, "SaveManager:SetLibrary(Library) must be called first")

	local Library = self.Library
	local Groupbox = (Side == "Right") and Tab:AddRightGroupbox("Configuration", "save")
		or Tab:AddLeftGroupbox("Configuration", "save")

	self:SetIgnoreIndexes({
		"SaveManager_ConfigName",
		"SaveManager_ConfigList",
		"SaveManager_AutoloadLabel",
	})

	Groupbox:AddInput("SaveManager_ConfigName", {
		Text = "Config name",
		Placeholder = "my-config",
		Tooltip = "The name used when creating a new config.",
	})

	Groupbox:AddDropdown("SaveManager_ConfigList", {
		Text = "Saved configs",
		Values = self:RefreshConfigList(),
		AllowNull = true,
		Searchable = true,
		Tooltip = "Pick a config to load, overwrite, delete or autoload.",
	})

	local AutoloadLabel = Groupbox:AddLabel("Autoload: none", true)

	local function Refresh()
		local Options = Library.Options
		Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
	end

	local function Selected()
		return Library.Options.SaveManager_ConfigList.Value
	end

	Groupbox:AddDivider()

	Groupbox:AddButton({
		Text = "Create config",
		Tooltip = "Saves the current settings under the name above.",
		Func = function()
			local Name = Library.Options.SaveManager_ConfigName.Value
			if not Name or Name:gsub(" ", "") == "" then
				return Library:Notify({
					Title = "Missing name",
					Description = "Type a config name first.",
					Time = 4,
					Type = "Warning",
				})
			end

			local Ok, Error = self:Save(Name)
			if not Ok then
				return Library:Notify({ Title = "Save failed", Description = tostring(Error), Time = 5, Type = "Error" })
			end

			Library:Notify({ Title = "Config saved", Description = "Created '" .. Name .. "'.", Time = 4, Type = "Success" })
			Refresh()
		end,
	}):AddButton({
		Text = "Overwrite",
		Tooltip = "Saves the current settings over the selected config.",
		Func = function()
			local Name = Selected()
			if not Name then
				return Library:Notify({ Title = "Nothing selected", Description = "Pick a config first.", Time = 4, Type = "Warning" })
			end
			local Ok, Error = self:Save(Name)
			if not Ok then
				return Library:Notify({ Title = "Save failed", Description = tostring(Error), Time = 5, Type = "Error" })
			end
			Library:Notify({ Title = "Config saved", Description = "Overwrote '" .. Name .. "'.", Time = 4, Type = "Success" })
		end,
	})

	Groupbox:AddButton({
		Text = "Load config",
		Func = function()
			local Name = Selected()
			if not Name then
				return Library:Notify({ Title = "Nothing selected", Description = "Pick a config first.", Time = 4, Type = "Warning" })
			end
			local Ok, Error = self:Load(Name)
			if not Ok then
				return Library:Notify({ Title = "Load failed", Description = tostring(Error), Time = 5, Type = "Error" })
			end
			Library:Notify({ Title = "Config loaded", Description = "Loaded '" .. Name .. "'.", Time = 4, Type = "Success" })
		end,
	}):AddButton({
		Text = "Delete config",
		DoubleClick = true,
		Func = function()
			local Name = Selected()
			if not Name then
				return Library:Notify({ Title = "Nothing selected", Description = "Pick a config first.", Time = 4, Type = "Warning" })
			end
			local Ok, Error = self:Delete(Name)
			if not Ok then
				return Library:Notify({ Title = "Delete failed", Description = tostring(Error), Time = 5, Type = "Error" })
			end
			Library:Notify({ Title = "Config deleted", Description = "Removed '" .. Name .. "'.", Time = 4, Type = "Success" })
			Refresh()
		end,
	})

	Groupbox:AddButton({
		Text = "Refresh list",
		Func = function()
			Refresh()
			Library:Notify({ Title = "Configs", Description = "List refreshed.", Time = 3 })
		end,
	}):AddButton({
		Text = "Set as autoload",
		Func = function()
			local Name = Selected()
			if not Name then
				return Library:Notify({ Title = "Nothing selected", Description = "Pick a config first.", Time = 4, Type = "Warning" })
			end
			self:SetAutoLoadConfig(Name)
			AutoloadLabel:SetText("Autoload: " .. Name)
			Library:Notify({ Title = "Autoload set", Description = "'" .. Name .. "' will load on launch.", Time = 4, Type = "Success" })
		end,
	})

	Groupbox:AddButton({
		Text = "Clear autoload",
		Func = function()
			self:DeleteAutoLoadConfig()
			AutoloadLabel:SetText("Autoload: none")
			Library:Notify({ Title = "Autoload cleared", Time = 3 })
		end,
	})

	local Current = self:GetAutoloadConfig()
	if Current then
		AutoloadLabel:SetText("Autoload: " .. Current)
	end

	self.ConfigGroupbox = Groupbox
	return Groupbox
end

-- Obsidian / Linoria alias
SaveManager.BuildConfigTab = SaveManager.BuildConfigSection

return SaveManager
