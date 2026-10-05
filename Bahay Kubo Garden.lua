--[[
    GARDEN PANEL - Standalone Client Version
    ------------------------------------------------------------------
    Modified for Delta Executor and standalone execution.
    Runs locally without needing server-side setup in ReplicatedStorage.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

------------------------------------------------------------------
-- Local Game Configuration & State Mock
------------------------------------------------------------------
local CROPS = {
	{ name = "Carrot",     cost = 10,  grow = 20,  sell = 18   },
	{ name = "Radish",     cost = 15,  grow = 25,  sell = 28   },
	{ name = "Tomato",     cost = 40,  grow = 45,  sell = 80   },
	{ name = "Strawberry", cost = 60,  grow = 60,  sell = 130  },
	{ name = "Corn",       cost = 90,  grow = 75,  sell = 200  },
	{ name = "Pumpkin",    cost = 200, grow = 120, sell = 480  },
	{ name = "Watermelon", cost = 350, grow = 150, sell = 900  },
	{ name = "Mango",      cost = 800, grow = 240, sell = 2300 },
}

local CROP, cropNames = {}, {}
for _, c in ipairs(CROPS) do 
	CROP[c.name] = c 
	cropNames[#cropNames + 1] = c.name 
end
local maxPlots = 60

local state = {
	coins = 250,
	seeds = { Carrot = 5 },
	produce = {},
	plots = {},
	plotCount = 12,
	now = os.time(),
	admin = true, -- Defaulted to true for local standalone testing
	stats = { bought = 0, planted = 0, harvested = 0, sold = 0, earned = 0 }
}

for _, c in ipairs(CROPS) do
	state.seeds[c.name] = state.seeds[c.name] or 0
	state.produce[c.name] = 0
end
for i = 1, state.plotCount do
	state.plots[i] = false
end

local stateAt = os.clock()
local function serverNow() return os.time() + (os.clock() - stateAt) end
local function plotPct(pl) return math.clamp((serverNow() - pl.at) / CROP[pl.crop].grow, 0, 1) end

------------------------------------------------------------------
-- Obsidian UI Loader
------------------------------------------------------------------
local REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(REPO .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(REPO .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(REPO .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
	Title = "Garden Panel", Footer = "Standalone Client", ToggleKeybind = Enum.KeyCode.RightShift,
	Center = true, AutoShow = true, NotifySide = "Right",
})

local Tabs = {
	Shop   = Window:AddTab("Shop", "shopping-basket"),
	Garden = Window:AddTab("Garden", "sprout"),
	Sell   = Window:AddTab("Sell", "coins"),
	Auto   = Window:AddTab("Auto", "bot"),
	Status = Window:AddTab("Status", "chart-no-axes-column"),
}
if state.admin then Tabs.Admin = Window:AddTab("Admin", "shield") end
Tabs.Settings = Window:AddTab("UI Settings", "settings")

local count = 0
local function nextId(t) count += 1; return ("g%03d_%s"):format(count, (t:gsub("%W", ""))) end
local function T(gb, text, def, cb) return gb:AddToggle(nextId(text), { Text = text, Default = def or false, Callback = cb }) end
local function Sl(gb, text, min, max, def, cb, round)
	return gb:AddSlider(nextId(text), { Text = text, Default = math.clamp(def, min, max), Min = min, Max = max, Rounding = round or 0, Callback = cb })
end
local function B(gb, text, fn) count += 1; return gb:AddButton({ Text = text, Func = fn }) end
local function D(gb, text, values, def, cb, multi)
	return gb:AddDropdown(nextId(text), { Text = text, Values = values, Default = def, Multi = multi or false, Callback = cb })
end
local function I(gb, text, def, cb) return gb:AddInput(nextId(text), { Text = text, Default = def or "", Finished = true, Callback = cb }) end
local function L(gb, text) count += 1; return gb:AddLabel(text, true) end
local function notify(t, d) pcall(function() Library:Notify({ Title = t, Description = d, Time = 3 }) end) end

------------------------------------------------------------------
-- Action Processing (Local Simulation)
------------------------------------------------------------------
local A = {
	mode = "Round robin", interval = 1, keepSeeds = 5, maxSpend = 1000, sellKeep = 0, sellMin = 1,
	buy = false, plant = false, harvest = false, sell = false,
	buyList = { "Carrot" }, plantList = { "Carrot" }, sellList = { "Carrot" }, rr = 0,
	buyOne = "Carrot", buyAmt = 1, plantOne = "Carrot", plotNo = 1, stockTarget = 20, stockList = { "Carrot" },
}

local function profitMin(n) local c = CROP[n]; return (c.sell - c.cost) / (c.grow / 60) end

local function listFrom(v)
	local out = {}
	if type(v) == "table" then
		for k, val in pairs(v) do
			if type(k) == "string" and val == true and CROP[k] then out[#out + 1] = k
			elseif type(val) == "string" and CROP[val] then out[#out + 1] = val end
		end
	elseif type(v) == "string" and CROP[v] then
		out[1] = v
	end
	table.sort(out, function(a, b) return CROP[a].cost < CROP[b].cost end)
	return out
end

local function ordered(list)
	local l = table.clone(list)
	if A.mode == "Cheapest first" then
		table.sort(l, function(a, b) return CROP[a].cost < CROP[b].cost end)
	elseif A.mode == "Most expensive first" then
		table.sort(l, function(a, b) return CROP[a].cost > CROP[b].cost end)
	elseif A.mode == "Best profit / min" then
		table.sort(l, function(a, b) return profitMin(a) > profitMin(b) end)
	elseif #l > 1 then
		A.rr += 1
		local k, out = (A.rr - 1) % #l, {}
		for i = 1, #l do out[i] = l[(i - 1 + k) % #l + 1] end
		l = out
	end
	return l
end

local function preselect(dd) pcall(function() dd:SetValue({ Carrot = true }) end) end
local MODES = { "Round robin", "Cheapest first", "Most expensive first", "Best profit / min" }

------------------------------------------------------------------
-- SHOP TAB
------------------------------------------------------------------
local infoLbl
local function showInfo(n)
	local c = CROP[n]
	if c and infoLbl then
		infoLbl:SetText(("%s: seed %d | grows %ds | sells %d | %.0f profit/min"):format(n, c.cost, c.grow, c.sell, profitMin(n)))
	end
end
do
	local gb = Tabs.Shop:AddLeftGroupbox("Buy Seeds", "shopping-basket")
	infoLbl = L(gb, "Pick a seed")
	D(gb, "Seed To Buy", cropNames, 1, function(v) A.buyOne = v; showInfo(v) end)
	Sl(gb, "Buy Amount", 1, 1000, 1, function(v) A.buyAmt = v end)
	B(gb, "Buy Selected Seed", function()
		local c = CROP[A.buyOne]
		local total = c.cost * A.buyAmt
		if state.coins >= total then
			state.coins -= total
			state.seeds[A.buyOne] += A.buyAmt
			state.stats.bought += A.buyAmt
			notify("Shop", ("Bought %d %s"):format(A.buyAmt, A.buyOne))
		else
			notify("Shop", "Not enough coins")
		end
	end)
	showInfo("Carrot")

	local gb2 = Tabs.Shop:AddRightGroupbox("Stock Up", "package")
	local dd = D(gb2, "Stock-Up Crops", cropNames, nil, function(v) A.stockList = listFrom(v); A.buyList = A.stockList end, true)
	preselect(dd)
	Sl(gb2, "Stock Up To", 1, 500, 20, function(v) A.stockTarget = v end)
end

------------------------------------------------------------------
-- GARDEN TAB
------------------------------------------------------------------
do
	local gb = Tabs.Garden:AddLeftGroupbox("Plant", "sprout")
	D(gb, "Crop To Plant", cropNames, 1, function(v) A.plantOne = v end)
	B(gb, "Plant In All Empty Plots", function()
		local planted = 0
		for i = 1, state.plotCount do
			if not state.plots[i] and state.seeds[A.plantOne] > 0 then
				state.seeds[A.plantOne] -= 1
				state.plots[i] = { crop = A.plantOne, at = os.time() }
				planted += 1
			end
		end
		notify("Garden", ("Planted %d crops"):format(planted))
	end)

	local gb2 = Tabs.Garden:AddRightGroupbox("Harvest", "wheat")
	B(gb2, "Harvest All Ready", function()
		local harvested = 0
		for i = 1, state.plotCount do
			local pl = state.plots[i]
			if pl and plotPct(pl) >= 1 then
				state.produce[pl.crop] = (state.produce[pl.crop] or 0) + 1
				state.plots[i] = false
				harvested += 1
			end
		end
		notify("Garden", ("Harvested %d crops"):format(harvested))
	end)
end

------------------------------------------------------------------
-- SELL TAB
------------------------------------------------------------------
do
	local gb = Tabs.Sell:AddLeftGroupbox("Sell Produce", "coins")
	B(gb, "Sell Everything", function()
		local totalEarned, totalSold = 0, 0
		for name, count in pairs(state.produce) do
			if count > 0 then
				local gain = count * CROP[name].sell
				totalEarned += gain
				totalSold += count
				state.produce[name] = 0
			end
		end
		state.coins += totalEarned
		state.stats.sold += totalSold
		state.stats.earned += totalEarned
		notify("Sell", ("Sold %d items for %d coins"):format(totalSold, totalEarned))
	end)
end

------------------------------------------------------------------
-- STATUS TAB
------------------------------------------------------------------
local statsLbl, invLbl, plotsLbl
do
	local gb = Tabs.Status:AddLeftGroupbox("Garden", "leaf")
	statsLbl = L(gb, "...")
	invLbl   = L(gb, "...")
	plotsLbl = L(gb, "...")
end

task.spawn(function()
	while true do
		pcall(function()
			local s = state.stats
			statsLbl:SetText(("Coins: %d\nEarned: %d\nBought %d | Planted %d | Harvested %d | Sold %d")
				:format(state.coins, s.earned, s.bought, s.planted, s.harvested, s.sold))
			local seeds, prod = {}, {}
			for _, n in ipairs(cropNames) do
				if (state.seeds[n] or 0) > 0 then seeds[#seeds + 1] = n .. " x" .. state.seeds[n] end
				if (state.produce[n] or 0) > 0 then prod[#prod + 1] = n .. " x" .. state.produce[n] end
			end
			invLbl:SetText("Seeds: " .. (#seeds > 0 and table.concat(seeds, ", ") or "none")
				.. "\nProduce: " .. (#prod > 0 and table.concat(prod, ", ") or "none"))
			local rows, line = {}, {}
			for i, pl in ipairs(state.plots) do
				line[#line + 1] = pl and ("[%s %d%%]"):format(pl.crop, math.floor(plotPct(pl) * 100)) or "[empty]"
				if #line == 3 or i == #state.plots then rows[#rows + 1] = table.concat(line, " "); line = {} end
			end
			plotsLbl:SetText("Plots:\n" .. table.concat(rows, "\n"))
		end)
		task.wait(0.4)
	end
end)

------------------------------------------------------------------
-- UI Mobile Button Setup
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "GardenPanelButton"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local ok = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
if not ok or not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(34, 34)
btn.Position = UDim2.new(0, 8, 0.5, -17)
btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
btn.BackgroundTransparency = 0.2
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Text = "="
btn.TextSize = 20
btn.Font = Enum.Font.GothamBold
btn.Parent = gui
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
btn.MouseButton1Click:Connect(function() pcall(function() Library:Toggle() end) end)

notify("Garden Panel", "Loaded successfully in standalone mode!")
