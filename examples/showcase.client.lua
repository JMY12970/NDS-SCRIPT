-- Put OzionUI in ReplicatedStorage, then place this LocalScript in StarterPlayerScripts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OzionUI = require(ReplicatedStorage:WaitForChild("OzionUI"))

local Window = OzionUI:CreateWindow({
	Title = "OzionUI",
	Subtitle = "SHOWCASE · 1.0",
	Size = Vector2.new(780, 520),
	Theme = "Obsidian",
	ToggleKey = Enum.KeyCode.RightShift,
	Resizable = true,
})

local Home = Window:AddTab({
	Title = "Dashboard",
	Icon = "◆",
	Description = "A quick tour of OzionUI",
})

local Welcome = Home:AddSection({
	Title = "Welcome",
	Description = "A dependency-free animated interface for Roblox",
})

Welcome:AddParagraph({
	Title = "OzionUI is ready",
	Content = "Use the tabs, drag or resize the window, and press RightShift to hide it. Every control below is wired to a working callback.",
})

Welcome:AddButton({
	Title = "Send a notification",
	Description = "Animated, timed, and stackable",
	Callback = function()
		Window:Notify({
			Title = "Looking good",
			Content = "Your OzionUI window is working.",
			Type = "Success",
			Duration = 3.5,
		})
	end,
})

local Interface = Home:AddSection("Interface")
Interface:AddDropdown({
	Title = "Theme",
	Values = { "Obsidian", "Midnight", "Rose" },
	Default = "Obsidian",
	Callback = function(theme)
		Window:SetTheme(theme)
	end,
})

Interface:AddSlider({
	Title = "Walk speed demo",
	Description = "Demonstrates a stepped numeric value",
	Min = 8,
	Max = 32,
	Default = 16,
	Increment = 1,
	Suffix = " spd",
	Flag = "walk_speed_demo",
	Callback = function(value)
		print("Demo speed:", value)
	end,
})

local Controls = Window:AddTab({
	Title = "Controls",
	Icon = "✦",
	Description = "All interactive components",
})

local General = Controls:AddSection({
	Title = "General",
	Description = "Buttons, toggles, text inputs, and menus",
})

General:AddToggle({
	Title = "Animated toggle",
	Description = "Smooth color and spring motion",
	Default = true,
	Flag = "animated_toggle",
	Callback = function(value)
		print("Toggle:", value)
	end,
})

General:AddInput({
	Title = "Display name",
	Placeholder = "Type a name...",
	Default = "Ozion user",
	Flag = "display_name",
	Callback = function(value)
		print("Name:", value)
	end,
})

General:AddDropdown({
	Title = "Movement style",
	Values = { "Smooth", "Snappy", "Elastic" },
	Default = "Smooth",
	Flag = "movement_style",
	Callback = function(value)
		print("Style:", value)
	end,
})

local Personalize = Controls:AddSection("Personalize")
Personalize:AddColorPicker({
	Title = "Accent preview",
	Description = "HSV picker with live updates",
	Default = Color3.fromRGB(132, 91, 255),
	Flag = "accent_preview",
	Callback = function(color)
		print("Accent:", color)
	end,
})

Personalize:AddKeybind({
	Title = "Action key",
	Description = "Click the key chip, then press a key",
	Default = Enum.KeyCode.F,
	Flag = "action_key",
	ChangedCallback = function(key)
		print("New key:", key.Name)
	end,
	Callback = function(key)
		Window:Notify({
			Title = "Key pressed",
			Content = key.Name .. " activated the demo action.",
			Type = "Info",
			Duration = 2.5,
		})
	end,
})

local Settings = Window:AddTab({
	Title = "Settings",
	Icon = "⚙",
	Description = "Configuration and library utilities",
})

local Config = Settings:AddSection("Configuration")
local lastConfig

Config:AddButton({
	Title = "Export config",
	Description = "Serializes every flagged control to JSON",
	Callback = function()
		lastConfig = Window:ExportConfig()
		print(lastConfig)
		Window:Notify({ Title = "Config exported", Content = "JSON was printed to the output.", Type = "Success" })
	end,
})

Config:AddButton({
	Title = "Import last config",
	Description = "Restores the most recently exported values",
	Callback = function()
		if lastConfig then
			Window:ImportConfig(lastConfig)
			Window:Notify({ Title = "Config restored", Content = "Saved values were applied.", Type = "Success" })
		else
			Window:Notify({ Title = "Nothing saved", Content = "Export a config first.", Type = "Warning" })
		end
	end,
})

Window:Notify({
	Title = "OzionUI loaded",
	Content = "Press RightShift at any time to toggle the window.",
	Type = "Success",
	Duration = 5,
})
