--[[
    GARDEN ALL-IN-ONE  -  one file, server + client
    ------------------------------------------------------------------
    This single script detects where it is running:

      SERVER  (put it in ServerScriptService as a *Script*)
          Creates ReplicatedStorage.GardenRemotes (Request + StateChanged)
          and runs the whole garden: coins, seeds, plots, growth, selling,
          DataStore saving. The server validates, clamps and rate-limits
          every request; the client can only ask.

      CLIENT  (run the same file from your executor, or as a LocalScript)
          Opens an Obsidian panel with: seed shop, planting, harvesting,
          selling, crop pickers (single + multi-select), pick modes, auto
          buy / plant / harvest / sell, live status, and an admin tab that
          only appears if the SERVER says you are an admin.

    Admins: the place owner, anyone in Studio, and UserIds in ADMIN_IDS.
    Menu key: RightShift (or the small "=" button on mobile).
]]

local RunService = game:GetService("RunService")

local function runServer()
	local Players           = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local DataStoreService  = game:GetService("DataStoreService")

	------------------------------------------------------------------
	-- Config (edit freely)
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
	local START_COINS    = 250
	local DEFAULT_PLOTS  = 12
	local MAX_PLOTS      = 60
	local MAX_BUY_ORDER  = 1000 -- seeds per single order line
	local MAX_ORDERS     = 8    -- order lines per Buy call
	local DATASTORE_NAME = "GardenData_v1"
	local AUTOSAVE_SECS  = 60

	-- Extra admins (UserIds). The place owner and anyone in Studio are admins.
	local ADMIN_IDS = {
		-- [123456789] = true,
	}

	local CROP_BY = {}
	for _, c in ipairs(CROPS) do CROP_BY[c.name] = c end

	local function isAdmin(player)
		if ADMIN_IDS[player.UserId] then return true end
		if RunService:IsStudio() then return true end
		return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
	end

	------------------------------------------------------------------
	-- Remotes
	------------------------------------------------------------------
	local folder = ReplicatedStorage:FindFirstChild("GardenRemotes")
	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "GardenRemotes"
	folder.Parent = ReplicatedStorage

	local Request = Instance.new("RemoteFunction")
	Request.Name = "Request"
	Request.Parent = folder

	local StateChanged = Instance.new("RemoteEvent")
	StateChanged.Name = "StateChanged"
	StateChanged.Parent = folder

	------------------------------------------------------------------
	-- Validation helpers
	------------------------------------------------------------------
	local function isInt(n, min, max)
		return type(n) == "number" and n == n and n == math.floor(n) and n >= min and n <= max
	end

	local function cleanCropList(v, maxLen)
		if type(v) ~= "table" then return nil end
		local out, seen = {}, {}
		for i = 1, math.min(#v, maxLen) do
			local name = v[i]
			if type(name) == "string" and CROP_BY[name] and not seen[name] then
				seen[name] = true
				out[#out + 1] = name
			end
		end
		return out
	end

	-- token bucket: burst 20, refill 10 / second
	local buckets = {}
	local function allow(player)
		local now = os.clock()
		local b = buckets[player] or { t = now, n = 20 }
		b.n = math.min(20, b.n + (now - b.t) * 10)
		b.t = now
		buckets[player] = b
		if b.n < 1 then return false end
		b.n -= 1
		return true
	end

	------------------------------------------------------------------
	-- Profiles + persistence
	------------------------------------------------------------------
	local store = DataStoreService:GetDataStore(DATASTORE_NAME)
	local profiles = {}

	local function newProfile(data)
		data = type(data) == "table" and data or {}
		local p = {
			coins = math.max(0, math.floor(tonumber(data.coins) or START_COINS)),
			seeds = {}, produce = {}, plots = {},
			plotCount = math.clamp(math.floor(tonumber(data.plotCount) or DEFAULT_PLOTS), 1, MAX_PLOTS),
			noSave = false,
			stats = { bought = 0, planted = 0, harvested = 0, sold = 0, earned = 0 },
		}
		for _, c in ipairs(CROPS) do
			p.seeds[c.name]   = math.max(0, math.floor(tonumber(data.seeds and data.seeds[c.name]) or 0))
			p.produce[c.name] = math.max(0, math.floor(tonumber(data.produce and data.produce[c.name]) or 0))
		end
		for i = 1, p.plotCount do
			local pl = data.plots and data.plots[i]
			if type(pl) == "table" and CROP_BY[pl.crop] and type(pl.at) == "number" then
				p.plots[i] = { crop = pl.crop, at = pl.at }
			else
				p.plots[i] = false
			end
		end
		return p
	end

	local function serialize(p)
		local plots = {}
		for i = 1, p.plotCount do
			local pl = p.plots[i]
			plots[i] = pl and { crop = pl.crop, at = pl.at } or false
		end
		return { coins = p.coins, seeds = p.seeds, produce = p.produce, plots = plots, plotCount = p.plotCount }
	end

	local function loadProfile(player)
		local key = "u_" .. player.UserId
		local data, ok = nil, false
		for attempt = 1, 3 do
			local success, res = pcall(store.GetAsync, store, key)
			if success then data, ok = res, true break end
			task.wait(attempt)
		end
		local prof = newProfile(data)
		if not ok then
			prof.noSave = true -- never overwrite real data after a failed load
			warn(("[Garden] Could not load data for %s - this session will not be saved"):format(player.Name))
		end
		if player.Parent then profiles[player] = prof end
	end

	local function saveProfile(player)
		local prof = profiles[player]
		if not prof or prof.noSave then return end
		local ok, err = pcall(store.SetAsync, store, "u_" .. player.UserId, serialize(prof))
		if not ok then warn("[Garden] Save failed for", player.Name, err) end
	end

	------------------------------------------------------------------
	-- Snapshot / push
	------------------------------------------------------------------
	local function snapshot(player, prof)
		local plots = {}
		for i = 1, prof.plotCount do
			local pl = prof.plots[i]
			plots[i] = pl and { crop = pl.crop, at = pl.at } or false
		end
		return {
			coins = prof.coins, seeds = prof.seeds, produce = prof.produce, plots = plots,
			now = os.time(), admin = isAdmin(player), stats = prof.stats,
		}
	end

	local function push(player, prof)
		StateChanged:FireClient(player, snapshot(player, prof))
	end

	------------------------------------------------------------------
	-- Action handlers. Each returns (ok, info)
	------------------------------------------------------------------
	local Handlers = {}

	function Handlers.Buy(player, prof, args)
		local orders = args.orders
		if type(orders) ~= "table" then return false, "bad orders" end
		local bought = 0
		for i = 1, math.min(#orders, MAX_ORDERS) do
			local o = orders[i]
			if type(o) == "table" and type(o.crop) == "string" and CROP_BY[o.crop] and isInt(o.amount, 1, MAX_BUY_ORDER) then
				local c = CROP_BY[o.crop]
				local n = math.min(o.amount, math.floor(prof.coins / c.cost))
				if n > 0 then
					prof.coins -= n * c.cost
					prof.seeds[c.name] += n
					prof.stats.bought += n
					bought += n
				end
			end
		end
		if bought == 0 then return false, "nothing bought" end
		return true, { bought = bought }
	end

	function Handlers.Plant(player, prof, args)
		local crops = cleanCropList(args.crops, 8)
		if not crops or #crops == 0 then return false, "no crops" end
		local rotate = args.rotate == true
		local ptr, planted = 0, 0

		local function pick()
			for k = 0, #crops - 1 do
				local idx = ((ptr + k) % #crops) + 1
				local name = crops[idx]
				if prof.seeds[name] > 0 then
					if rotate then ptr = idx end
					return name
				end
			end
			return nil
		end
		local function plantAt(i)
			if prof.plots[i] then return end
			local name = pick()
			if not name then return end
			prof.seeds[name] -= 1
			prof.plots[i] = { crop = name, at = os.time() }
			prof.stats.planted += 1
			planted += 1
		end

		if args.plot ~= nil then
			if not isInt(args.plot, 1, prof.plotCount) then return false, "bad plot" end
			plantAt(args.plot)
		else
			for i = 1, prof.plotCount do plantAt(i) end
		end
		if planted == 0 then return false, "nothing planted" end
		return true, { planted = planted }
	end

	function Handlers.Harvest(player, prof, args)
		local now, harvested = os.time(), 0
		local function harvestAt(i)
			local pl = prof.plots[i]
			if pl and now - pl.at >= CROP_BY[pl.crop].grow then
				prof.produce[pl.crop] += 1
				prof.plots[i] = false
				prof.stats.harvested += 1
				harvested += 1
			end
		end
		if args.plot ~= nil then
			if not isInt(args.plot, 1, prof.plotCount) then return false, "bad plot" end
			harvestAt(args.plot)
		else
			for i = 1, prof.plotCount do harvestAt(i) end
		end
		if harvested == 0 then return false, "nothing ready" end
		return true, { harvested = harvested }
	end

	function Handlers.Sell(player, prof, args)
		local crops = args.crops ~= nil and cleanCropList(args.crops, 8) or nil
		if crops == nil then
			crops = {}
			for _, c in ipairs(CROPS) do crops[#crops + 1] = c.name end
		end
		local keep = args.keep ~= nil and args.keep or 0
		local minStock = args.min ~= nil and args.min or 1
		if not isInt(keep, 0, 100000) or not isInt(minStock, 1, 100000) then return false, "bad numbers" end

		local total = 0
		for _, name in ipairs(crops) do total += prof.produce[name] end
		if total < minStock then return false, "below minimum" end

		local gained, sold = 0, 0
		for _, name in ipairs(crops) do
			local n = prof.produce[name] - keep
			if n > 0 then
				prof.produce[name] -= n
				gained += n * CROP_BY[name].sell
				sold += n
			end
		end
		if sold == 0 then return false, "nothing to sell" end
		prof.coins += gained
		prof.stats.sold += sold
		prof.stats.earned += gained
		return true, { sold = sold, gained = gained }
	end

	function Handlers.Admin(player, prof, args)
		if not isAdmin(player) then
			warn(("[Garden] %s attempted an admin command"):format(player.Name))
			return false, "not allowed"
		end
		local cmd = args.cmd
		if cmd == "AddCoins" then
			if not isInt(args.amount, 1, 1e9) then return false, "bad amount" end
			prof.coins += args.amount
		elseif cmd == "AddSeeds" then
			if not isInt(args.amount, 1, 100000) then return false, "bad amount" end
			if args.crop == "ALL" then
				for _, c in ipairs(CROPS) do prof.seeds[c.name] += args.amount end
			elseif type(args.crop) == "string" and CROP_BY[args.crop] then
				prof.seeds[args.crop] += args.amount
			else
				return false, "bad crop"
			end
		elseif cmd == "FinishGrowth" then
			for i = 1, prof.plotCount do
				local pl = prof.plots[i]
				if pl then pl.at = os.time() - CROP_BY[pl.crop].grow end
			end
		elseif cmd == "ClearPlots" then
			for i = 1, prof.plotCount do prof.plots[i] = false end
		elseif cmd == "SetPlots" then
			if not isInt(args.count, 1, MAX_PLOTS) then return false, "bad count" end
			for i = prof.plotCount + 1, args.count do prof.plots[i] = false end
			for i = prof.plotCount, args.count + 1, -1 do prof.plots[i] = nil end
			prof.plotCount = args.count
		elseif cmd == "ResetData" then
			local fresh = newProfile(nil)
			fresh.noSave = prof.noSave
			profiles[player] = fresh
		else
			return false, "unknown command"
		end
		return true, {}
	end

	------------------------------------------------------------------
	-- Request dispatcher
	------------------------------------------------------------------
	Request.OnServerInvoke = function(player, action, args)
		if type(action) ~= "string" then return { ok = false, err = "bad action" } end
		if args ~= nil and type(args) ~= "table" then return { ok = false, err = "bad args" } end
		args = args or {}

		if not allow(player) then return { ok = false, err = "rate limited" } end

		if action == "GetConfig" then
			return { ok = true, crops = CROPS, maxPlots = MAX_PLOTS }
		end

		local prof = profiles[player]
		if not prof then return { ok = false, err = "loading" } end

		if action == "GetState" then
			return { ok = true, state = snapshot(player, prof) }
		end

		local handler = Handlers[action]
		if not handler then return { ok = false, err = "unknown action" } end

		local ok, info = handler(player, prof, args)
		prof = profiles[player] or prof -- ResetData swaps the profile
		if ok then push(player, prof) end
		return { ok = ok, info = ok and info or nil, err = (not ok) and info or nil, state = snapshot(player, prof) }
	end

	------------------------------------------------------------------
	-- Player lifecycle
	------------------------------------------------------------------
	Players.PlayerAdded:Connect(function(player)
		loadProfile(player)
		if profiles[player] then push(player, profiles[player]) end
	end)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadProfile, player) end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player)
		profiles[player] = nil
		buckets[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECS)
			for player in pairs(profiles) do task.spawn(saveProfile, player) end
		end
	end)

	game:BindToClose(function()
		for player in pairs(profiles) do task.spawn(saveProfile, player) end
		if not RunService:IsStudio() then task.wait(3) end
	end)
end

local function runClient()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CoreGui = game:GetService("CoreGui")
	local LP = Players.LocalPlayer

	local Remotes = ReplicatedStorage:WaitForChild("GardenRemotes", 20)
	if not Remotes then
		warn("[Garden] GardenRemotes not found. Run this file as a Script in ServerScriptService first.")
		return
	end
	local Request = Remotes:WaitForChild("Request")
	local StateChanged = Remotes:WaitForChild("StateChanged")

	local conns, alive = {}, true
	local state, stateAt = nil, 0
	local function setState(s) state = s; stateAt = os.clock() end
	conns[#conns + 1] = StateChanged.OnClientEvent:Connect(setState)

	local function call(action, args)
		local ok, res = pcall(function() return Request:InvokeServer(action, args) end)
		if not ok or type(res) ~= "table" then return { ok = false, err = tostring(res) } end
		if res.state then setState(res.state) end
		return res
	end

	local cfg = call("GetConfig")
	if not cfg.ok then warn("[Garden] Could not read config: " .. tostring(cfg.err)) return end
	local CROPS, CROP, cropNames = cfg.crops, {}, {}
	for _, c in ipairs(CROPS) do CROP[c.name] = c; cropNames[#cropNames + 1] = c.name end
	local maxPlots = cfg.maxPlots or 60

	for _ = 1, 30 do
		if state then break end
		call("GetState")
		if state then break end
		task.wait(0.5)
	end
	if not state then warn("[Garden] Your garden data never loaded.") return end

	----------------------------------------------------------------
	-- Obsidian
	----------------------------------------------------------------
	local REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
	local Library      = loadstring(game:HttpGet(REPO .. "Library.lua"))()
	local ThemeManager = loadstring(game:HttpGet(REPO .. "addons/ThemeManager.lua"))()
	local SaveManager  = loadstring(game:HttpGet(REPO .. "addons/SaveManager.lua"))()

	local Window = Library:CreateWindow({
		Title = "Garden Panel", Footer = "server-validated", ToggleKeybind = Enum.KeyCode.RightShift,
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

	----------------------------------------------------------------
	-- Logic helpers
	----------------------------------------------------------------
	local A = {
		mode = "Round robin", interval = 1, keepSeeds = 5, maxSpend = 1000, sellKeep = 0, sellMin = 1,
		buy = false, plant = false, harvest = false, sell = false,
		buyList = { "Carrot" }, plantList = { "Carrot" }, sellList = { "Carrot" }, rr = 0,
		buyOne = "Carrot", buyAmt = 1, plantOne = "Carrot", plotNo = 1, stockTarget = 20, stockList = { "Carrot" },
	}

	local function act(action, args, quiet)
		local res = call(action, args)
		if not res.ok and not quiet then notify(action, tostring(res.err)) end
		return res
	end

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

	local function serverNow() return state.now + (os.clock() - stateAt) end
	local function plotPct(pl) return math.clamp((serverNow() - pl.at) / CROP[pl.crop].grow, 0, 1) end

	local function hasReady()
		for _, pl in ipairs(state.plots) do if pl and plotPct(pl) >= 1 then return true end end
		return false
	end
	local function hasEmpty()
		for _, pl in ipairs(state.plots) do if not pl then return true end end
		return false
	end
	local function hasSeeds(list)
		for _, n in ipairs(list) do if (state.seeds[n] or 0) > 0 then return true end end
		return false
	end
	local function hasSellable(list, keep, minStock)
		local total, over = 0, false
		for _, n in ipairs(list) do
			local have = state.produce[n] or 0
			total += have
			if have > keep then over = true end
		end
		return over and total >= minStock
	end

	local function buildOrders(list, target, budget)
		local orders, left = {}, budget
		for _, name in ipairs(ordered(list)) do
			if #orders >= 8 then break end
			local need = target - (state.seeds[name] or 0)
			if need > 0 then
				local n = math.min(need, math.floor(left / CROP[name].cost), 1000)
				if n > 0 then
					orders[#orders + 1] = { crop = name, amount = n }
					left -= n * CROP[name].cost
				end
			end
		end
		return orders
	end

	local function preselect(dd) pcall(function() dd:SetValue({ Carrot = true }) end) end
	local MODES = { "Round robin", "Cheapest first", "Most expensive first", "Best profit / min" }

	----------------------------------------------------------------
	-- SHOP
	----------------------------------------------------------------
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
		B(gb, "Buy Selected Seed", function() act("Buy", { orders = { { crop = A.buyOne, amount = A.buyAmt } } }) end)
		B(gb, "Buy Max Affordable", function()
			local n = math.min(1000, math.floor(state.coins / CROP[A.buyOne].cost))
			if n < 1 then return notify("Shop", "Not enough coins") end
			act("Buy", { orders = { { crop = A.buyOne, amount = n } } })
		end)
		showInfo("Carrot")

		local gb2 = Tabs.Shop:AddRightGroupbox("Stock Up", "package")
		local dd = D(gb2, "Stock-Up Crops", cropNames, nil, function(v) A.stockList = listFrom(v); A.buyList = A.stockList end, true)
		preselect(dd)
		Sl(gb2, "Stock Up To", 1, 500, 20, function(v) A.stockTarget = v end)
		B(gb2, "Stock Up Now", function()
			local orders = buildOrders(A.stockList, A.stockTarget, state.coins)
			if #orders == 0 then return notify("Shop", "Nothing to buy (stocked or no coins)") end
			act("Buy", { orders = orders })
		end)
	end

	----------------------------------------------------------------
	-- GARDEN
	----------------------------------------------------------------
	do
		local gb = Tabs.Garden:AddLeftGroupbox("Plant", "sprout")
		D(gb, "Crop To Plant", cropNames, 1, function(v) A.plantOne = v end)
		B(gb, "Plant In All Empty Plots", function() act("Plant", { crops = { A.plantOne } }) end)
		Sl(gb, "Plot Number", 1, maxPlots, 1, function(v) A.plotNo = v end)
		B(gb, "Plant In Plot #", function() act("Plant", { crops = { A.plantOne }, plot = A.plotNo }) end)
		local dd = D(gb, "Plant Crops (multi)", cropNames, nil, function(v) A.plantList = listFrom(v) end, true)
		preselect(dd)
		D(gb, "Pick Mode (buy & plant)", MODES, 1, function(v) A.mode = v end)
		B(gb, "Plant Multi-Select", function()
			if #A.plantList == 0 then return notify("Garden", "Pick at least one crop") end
			act("Plant", { crops = ordered(A.plantList), rotate = A.mode == "Round robin" })
		end)

		local gb2 = Tabs.Garden:AddRightGroupbox("Harvest", "wheat")
		B(gb2, "Harvest All Ready", function() act("Harvest", {}) end)
		B(gb2, "Harvest Plot #", function() act("Harvest", { plot = A.plotNo }) end)
	end

	----------------------------------------------------------------
	-- SELL
	----------------------------------------------------------------
	do
		local gb = Tabs.Sell:AddLeftGroupbox("Sell Produce", "coins")
		local dd = D(gb, "Crops To Sell", cropNames, nil, function(v) A.sellList = listFrom(v) end, true)
		preselect(dd)
		Sl(gb, "Keep Per Crop", 0, 100, 0, function(v) A.sellKeep = v end)
		Sl(gb, "Min Produce Before Selling", 1, 200, 1, function(v) A.sellMin = v end)
		B(gb, "Sell Selected", function()
			if #A.sellList == 0 then return notify("Sell", "Pick at least one crop") end
			local r = act("Sell", { crops = A.sellList, keep = A.sellKeep, min = A.sellMin })
			if r.ok then notify("Sold", ("%d items for %d coins"):format(r.info.sold, r.info.gained)) end
		end)
		B(gb, "Sell Everything", function()
			local r = act("Sell", {})
			if r.ok then notify("Sold", ("%d items for %d coins"):format(r.info.sold, r.info.gained)) end
		end)
	end

	----------------------------------------------------------------
	-- AUTO
	----------------------------------------------------------------
	local autoToggles = {}
	do
		local gb = Tabs.Auto:AddLeftGroupbox("Automation", "bot")
		autoToggles[#autoToggles + 1] = T(gb, "Auto Buy (uses Stock-Up Crops)", false, function(v) A.buy = v end)
		autoToggles[#autoToggles + 1] = T(gb, "Auto Plant (uses Plant Crops)", false, function(v) A.plant = v end)
		autoToggles[#autoToggles + 1] = T(gb, "Auto Harvest", false, function(v) A.harvest = v end)
		autoToggles[#autoToggles + 1] = T(gb, "Auto Sell (uses Crops To Sell)", false, function(v) A.sell = v end)
		B(gb, "Stop All Automation", function()
			for _, t in ipairs(autoToggles) do pcall(function() t:SetValue(false) end) end
		end)

		local gb2 = Tabs.Auto:AddRightGroupbox("Auto Settings", "sliders-horizontal")
		Sl(gb2, "Cycle Interval (s)", 0.3, 10, 1, function(v) A.interval = v end, 1)
		Sl(gb2, "Auto-Buy Stock Level", 1, 500, 5, function(v) A.keepSeeds = v end)
		Sl(gb2, "Max Spend Per Cycle", 10, 50000, 1000, function(v) A.maxSpend = v end)
		D(gb2, "Pick Mode", MODES, 1, function(v) A.mode = v end)
	end

	task.spawn(function()
		while alive and not Library.Unloaded do
			task.wait(A.interval)
			if A.buy or A.plant or A.harvest or A.sell then
				pcall(function()
					if A.harvest and hasReady() then act("Harvest", {}, true) end
					if A.sell and #A.sellList > 0 and hasSellable(A.sellList, A.sellKeep, A.sellMin) then
						act("Sell", { crops = A.sellList, keep = A.sellKeep, min = A.sellMin }, true)
					end
					if A.buy and #A.buyList > 0 then
						local orders = buildOrders(A.buyList, A.keepSeeds, math.min(state.coins, A.maxSpend))
						if #orders > 0 then act("Buy", { orders = orders }, true) end
					end
					if A.plant and #A.plantList > 0 and hasEmpty() and hasSeeds(A.plantList) then
						act("Plant", { crops = ordered(A.plantList), rotate = A.mode == "Round robin" }, true)
					end
				end)
			end
		end
	end)

	----------------------------------------------------------------
	-- STATUS
	----------------------------------------------------------------
	local statsLbl, invLbl, plotsLbl
	do
		local gb = Tabs.Status:AddLeftGroupbox("Garden", "leaf")
		statsLbl = L(gb, "...")
		invLbl   = L(gb, "...")
		plotsLbl = L(gb, "...")
	end
	task.spawn(function()
		while alive and not Library.Unloaded do
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

	----------------------------------------------------------------
	-- ADMIN (only built when the server says you're an admin)
	----------------------------------------------------------------
	if Tabs.Admin then
		local gb = Tabs.Admin:AddLeftGroupbox("Test Tools (server-checked)", "wrench")
		local coinsAmt, seedsAmt, seedCrop, plotsN, confirm = 1000, 10, "ALL", 12, false
		I(gb, "Coins Amount", "1000", function(v) coinsAmt = tonumber(v) or 0 end)
		B(gb, "Add Coins", function() act("Admin", { cmd = "AddCoins", amount = math.floor(coinsAmt) }) end)
		local values = { "ALL" }
		for _, n in ipairs(cropNames) do values[#values + 1] = n end
		D(gb, "Seed Crop", values, 1, function(v) seedCrop = v end)
		I(gb, "Seed Amount", "10", function(v) seedsAmt = tonumber(v) or 0 end)
		B(gb, "Add Seeds", function() act("Admin", { cmd = "AddSeeds", crop = seedCrop, amount = math.floor(seedsAmt) }) end)
		B(gb, "Finish Growth Now", function() act("Admin", { cmd = "FinishGrowth" }) end)
		B(gb, "Clear All Plots", function() act("Admin", { cmd = "ClearPlots" }) end)
		Sl(gb, "Plot Count", 1, maxPlots, 12, function(v) plotsN = v end)
		B(gb, "Apply Plot Count", function() act("Admin", { cmd = "SetPlots", count = plotsN }) end)
		T(gb, "Confirm Reset", false, function(v) confirm = v end)
		B(gb, "Reset My Garden Data", function()
			if confirm then act("Admin", { cmd = "ResetData" }) else notify("Admin", "Tick Confirm Reset first") end
		end)
	end

	----------------------------------------------------------------
	-- UI settings + mobile button
	----------------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "GardenPanelButton"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
	do
		local ok = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
		if not ok or not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(34, 34); btn.Position = UDim2.new(0, 8, 0.5, -17)
		btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25); btn.BackgroundTransparency = 0.2
		btn.TextColor3 = Color3.new(1, 1, 1); btn.Text = "="; btn.TextSize = 20; btn.Font = Enum.Font.GothamBold
		btn.Parent = gui
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
		btn.MouseButton1Click:Connect(function() pcall(function() Library:Toggle() end) end)
	end

	do
		local gb = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")
		B(gb, "Unload Panel", function() Library:Unload() end)
		gb:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
		Library.ToggleKeybind = Library.Options.MenuKeybind
	end
	ThemeManager:SetLibrary(Library)
	SaveManager:SetLibrary(Library)
	SaveManager:IgnoreThemeSettings()
	SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
	pcall(function()
		ThemeManager:SetFolder("GardenPanel")
		SaveManager:SetFolder("GardenPanel/configs")
		SaveManager:BuildConfigSection(Tabs.Settings)
		ThemeManager:ApplyToTab(Tabs.Settings)
		SaveManager:LoadAutoloadConfig()
	end)

	Library:OnUnload(function()
		alive = false
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		gui:Destroy()
	end)
	notify("Garden Panel", count .. " controls ready | menu: RightShift")
end

if RunService:IsServer() then
	runServer()
else
	runClient()
end
