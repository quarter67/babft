--[[
	Grow a Garden 2 — Auto Hub  
	Features: Auto Harvest (fast) | Auto Buy Seeds | Auto Buy Gears |
	          Auto Sell | Auto Steal (Night) | Auto Collect Event Seeds
	Toggle UI: INSERT key
	Reverse-engineered from the live game's Networking (Packet) API.
]]

--========================== SERVICES ==========================--
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local CollectionService  = game:GetService("CollectionService")
local TweenService       = game:GetService("TweenService")

local LP = Players.LocalPlayer

--========================== KILL OLD INSTANCE ==========================--
if _G.__GAG2HUB and _G.__GAG2HUB.Destroy then
	pcall(_G.__GAG2HUB.Destroy)
end
local SELF = {}
_G.__GAG2HUB = SELF
local ALIVE = true
SELF.Destroy = function()
	ALIVE = false
end

--========================== NETWORKING ==========================--
local Net, StealFlags, FruitValueCalc
do
	local ok, err = pcall(function()
		Net            = require(ReplicatedStorage.SharedModules.Networking)
		StealFlags     = require(ReplicatedStorage.SharedModules.Flags.StealFlags)
		FruitValueCalc = require(ReplicatedStorage.SharedModules.FruitValueCalc)
	end)
	if not ok then
		warn("[GAG2 Hub] Failed to load game API: " .. tostring(err))
		return
	end
end

local function valueOf(m)
	local name = m:GetAttribute("CorePartName") or m:GetAttribute("SeedName")
	if not name then return 0 end
	local ok, v = pcall(FruitValueCalc, name, m:GetAttribute("SizeMulti") or 1,
		m:GetAttribute("Mutation"), LP, m:GetAttribute("DecayAlpha"))
	return (ok and type(v) == "number") and v or 0
end

--========================== STATE ==========================--
local F = {
	harvest        = false,
	prioHarvest    = false,
	plant          = false,
	plantStack     = false,
	plantPoint     = nil,
	sell           = false,
	steal          = false,
	prioSteal      = false,
	antiSteal      = false,
	eventSeeds     = false,
	buySeeds       = false,
	buyGears       = false,
	buyPets        = false,
}
local seedSelected = {}
local gearSelected = {}

local busy = false
local function acquire()
	local t0 = os.clock()
	while busy and ALIVE and os.clock() - t0 < 30 do task.wait() end
	busy = true
end
local function release() busy = false end

local function getHRP()
	local c = LP.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c
end

local function safeInvoke(packet, ...)
	local args = table.pack(...)
	local ok, res = pcall(function()
		return packet:Fire(table.unpack(args, 1, args.n))
	end)
	if ok then return res end
	return nil
end

--========================== STOCK / ITEM LISTS ==========================--
local function stockFolder(shop)
	local sv = ReplicatedStorage:FindFirstChild("StockValues")
	local sh = sv and sv:FindFirstChild(shop)
	return sh and sh:FindFirstChild("Items")
end

local function listItems(shop)
	local out, f = {}, stockFolder(shop)
	if f then
		for _, v in ipairs(f:GetChildren()) do
			if v:IsA("ValueBase") then table.insert(out, v.Name) end
		end
		table.sort(out)
	end
	return out
end

-- Wiki-ordered seed list (Common → Super) with rarity + image URLs
local SEED_DATA = {
	{ name = "Carrot",        rarity = "Common",    img = "https://static.wikia.nocookie.net/growagarden27847/images/5/59/CarrotProduce.png/revision/latest/scale-to-width-down/40?cb=20260612184438" },
	{ name = "Strawberry",    rarity = "Common",    img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/4/4e/Strawberry.png/40px-Strawberry.png" },
	{ name = "Blueberry",     rarity = "Common",    img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/1/1e/Blueberry.png/40px-Blueberry.png" },
	{ name = "Tulip",         rarity = "Uncommon",  img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/5/5e/Tulip.png/40px-Tulip.png" },
	{ name = "Tomato",        rarity = "Uncommon",  img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/2/2d/Tomato.png/40px-Tomato.png" },
	{ name = "Apple",         rarity = "Uncommon",  img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/8/80/Apple.png/40px-Apple.png" },
	{ name = "Bamboo",        rarity = "Rare",      img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/0/06/Bamboo.png/40px-Bamboo.png" },
	{ name = "Corn",          rarity = "Rare",      img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/e/e5/Corn.png/40px-Corn.png" },
	{ name = "Cactus",        rarity = "Rare",      img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/9/9b/Cactus.png/40px-Cactus.png" },
	{ name = "Pineapple",     rarity = "Rare",      img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/f/f1/Pineapple.png/40px-Pineapple.png" },
	{ name = "Mushroom",      rarity = "Epic",      img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/b/b1/Mushroom.png/40px-Mushroom.png" },
	{ name = "Green Bean",    rarity = "Epic",      img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/4/46/GreenBean.png/40px-GreenBean.png" },
	{ name = "Banana",        rarity = "Epic",      img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/b/b2/Banana.png/40px-Banana.png" },
	{ name = "Grape",         rarity = "Epic",      img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/4/47/Grape.png/40px-Grape.png" },
	{ name = "Coconut",       rarity = "Epic",      img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/f/f3/Coconut.png/40px-Coconut.png" },
	{ name = "Mango",         rarity = "Epic",      img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/8/8b/Mango.png/40px-Mango.png" },
	{ name = "Dragon Fruit",  rarity = "Legendary", img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/9/9e/DragonFruit.png/40px-DragonFruit.png" },
	{ name = "Acorn",         rarity = "Legendary", img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/3/3d/Acorn.png/40px-Acorn.png" },
	{ name = "Cherry",        rarity = "Legendary", img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/4/4b/Cherry.png/40px-Cherry.png" },
	{ name = "Sunflower",     rarity = "Legendary", img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/f/f7/Sunflower.png/40px-Sunflower.png" },
	{ name = "Venus Fly Trap",rarity = "Mythic",    img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/5/56/VenusFlyTrap.png/40px-VenusFlyTrap.png" },
	{ name = "Pomegranate",   rarity = "Mythic",    img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/3/36/Pomegranate.png/40px-Pomegranate.png" },
	{ name = "Poison Apple",  rarity = "Mythic",    img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/a/a1/PoisonApple.png/40px-PoisonApple.png" },
	{ name = "Moon Bloom",    rarity = "Super",     img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/6/60/MoonBloom.png/40px-MoonBloom.png" },
	{ name = "Dragon's Breath",rarity = "Super",   img = "https://static.wikia.nocookie.net/growagarden27847/images/thumb/5/5c/DragonsBreath.png/40px-DragonsBreath.png" },
}

local seedNames = {}
for _, sd in ipairs(SEED_DATA) do
	seedNames[#seedNames + 1] = sd.name
	seedSelected[sd.name] = true
end

local gearNames = listItems("GearShop")
for _, n in ipairs(gearNames) do gearSelected[n] = true end

--========================== FEATURE LOOPS ==========================--

local harvestDebounce = {}
task.spawn(function()
	while ALIVE do
		if F.harvest then
			local myId = LP.UserId
			local tagged = CollectionService:GetTagged("HarvestPrompt")
			local list = {}
			for _, p in ipairs(tagged) do
				if p:IsA("ProximityPrompt") and p.Parent and p:IsDescendantOf(workspace) then
					local m = p.Parent:FindFirstAncestorWhichIsA("Model")
					if m and tonumber(m:GetAttribute("UserId")) == myId and m:GetAttribute("PlantId") then
						list[#list + 1] = { m = m, v = F.prioHarvest and valueOf(m) or 0 }
					end
				end
			end
			if F.prioHarvest then
				table.sort(list, function(a, b) return a.v > b.v end)
			end
			for _, e in ipairs(list) do
				if not F.harvest then break end
				local m = e.m
				local pid = m:GetAttribute("PlantId")
				local fid = m:GetAttribute("FruitId")
				local key = tostring(pid) .. "|" .. tostring(fid)
				local now = os.clock()
				if not harvestDebounce[key] or now - harvestDebounce[key] > 0.15 then
					harvestDebounce[key] = now
					pcall(function() Net.Garden.CollectFruit:Fire(pid, fid or "") end)
				end
			end
			if #tagged == 0 then table.clear(harvestDebounce) end
		end
		RunService.Heartbeat:Wait()
	end
end)

task.spawn(function()
	while ALIVE do
		if F.sell then
			local preview = safeInvoke(Net.NPCS.PreviewSellAll)
			if preview and (preview.FruitCount or 0) > 0 then
				safeInvoke(Net.NPCS.SellAll)
			end
		end
		task.wait(0.2)
	end
end)

local function groundPointUnder(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged("PlantArea")
	local r = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -60, 0), params)
	return r and r.Position
end
local function currentStackPoint()
	if F.plantPoint then return F.plantPoint end
	local hrp = getHRP()
	if not hrp then return nil end
	return groundPointUnder(hrp.Position) or (hrp.Position - Vector3.new(0, 2.5, 0))
end

local function autoPlantOnce()
	local plotId = LP:GetAttribute("PlotId")
	local plot = plotId and workspace:FindFirstChild("Gardens") and workspace.Gardens:FindFirstChild("Plot" .. tostring(plotId))
	if not plot then return end
	local seedTools = {}
	local function scan(c) if c then for _, t in ipairs(c:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("SeedTool") ~= nil then table.insert(seedTools, t) end
	end end end
	scan(LP:FindFirstChildOfClass("Backpack"))
	scan(LP.Character)
	if #seedTools == 0 then return end
	if F.plantStack then
		local pt = currentStackPoint()
		if not pt then return end
		local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		for _, tool in ipairs(seedTools) do
			if not (F.plant and F.plantStack) then break end
			local seedName = tool:GetAttribute("SeedTool")
			local count = tool:GetAttribute("Count") or 1
			if hum then pcall(function() hum:EquipTool(tool) end) end
			for _ = 1, count do
				if not (F.plant and F.plantStack) or not tool.Parent then break end
				pcall(function() Net.Plant.PlantSeed:Fire(pt, seedName, tool) end)
				task.wait(0.07)
			end
		end
		return
	end
	local CELL, MIN2 = 2, 1.3 * 1.3
	local buckets = {}
	local function bk(cx, cz) return cx .. "," .. cz end
	local function addPt(p)
		local cx, cz = math.floor(p.X / CELL), math.floor(p.Z / CELL)
		local key = bk(cx, cz); local b = buckets[key]
		if not b then b = {}; buckets[key] = b end
		table.insert(b, p)
	end
	local function tooClose(p)
		local cx, cz = math.floor(p.X / CELL), math.floor(p.Z / CELL)
		for dx = -1, 1 do for dz = -1, 1 do
			local b = buckets[bk(cx + dx, cz + dz)]
			if b then for _, q in ipairs(b) do
				local ax, az = p.X - q.X, p.Z - q.Z
				if ax * ax + az * az < MIN2 then return true end
			end end
		end end
		return false
	end
	local plantsFolder = plot:FindFirstChild("Plants")
	if plantsFolder then for _, pl in ipairs(plantsFolder:GetChildren()) do
		local ok, cf = pcall(function() return pl:GetPivot() end)
		local p = ok and cf.Position or (pl:IsA("BasePart") and pl.Position)
		if p then addPt(p) end
	end end
	local GAP = 2.5
	local slots = {}
	for _, pa in ipairs(CollectionService:GetTagged("PlantArea")) do
		if pa:IsA("BasePart") and pa.Size.Y < 1 and pa:IsDescendantOf(plot) then
			local sx, sz = pa.Size.X, pa.Size.Z
			local lx = -sx / 2 + GAP / 2
			while lx < sx / 2 do
				local lz = -sz / 2 + GAP / 2
				while lz < sz / 2 do
					local world = (pa.CFrame * CFrame.new(lx, pa.Size.Y / 2 + 0.05, lz)).Position
					if not tooClose(world) then
						addPt(world)
						table.insert(slots, world)
					end
					lz = lz + GAP
				end
				lx = lx + GAP
			end
		end
	end
	if #slots == 0 then return end
	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	local si = 1
	for _, tool in ipairs(seedTools) do
		if not F.plant or si > #slots then break end
		local seedName = tool:GetAttribute("SeedTool")
		local count = tool:GetAttribute("Count") or 1
		if hum then pcall(function() hum:EquipTool(tool) end) end
		for _ = 1, count do
			if not F.plant or si > #slots then break end
			if not tool.Parent then break end
			local pos = slots[si]; si = si + 1
			pcall(function() Net.Plant.PlantSeed:Fire(pos, seedName, tool) end)
			task.wait(0.07)
		end
	end
end
task.spawn(function()
	while ALIVE do
		if F.plant then pcall(autoPlantOnce) end
		task.wait(0.6)
	end
end)

task.spawn(function()
	while ALIVE do
		if F.buySeeds then
			local f = stockFolder("SeedShop")
			if f then
				for _, v in ipairs(f:GetChildren()) do
					if v:IsA("ValueBase") and v.Value > 0 and seedSelected[v.Name] then
						local n = math.min(v.Value, 50)
						for _ = 1, n do
							pcall(function() Net.SeedShop.PurchaseSeed:Fire(v.Name) end)
							task.wait(0.06)
						end
					end
				end
			end
		end
		task.wait(1.5)
	end
end)

task.spawn(function()
	while ALIVE do
		if F.buyGears then
			local f = stockFolder("GearShop")
			if f then
				for _, v in ipairs(f:GetChildren()) do
					if v:IsA("ValueBase") and v.Value > 0 and gearSelected[v.Name] then
						local n = math.min(v.Value, 50)
						for _ = 1, n do
							pcall(function() Net.GearShop.PurchaseGear:Fire(v.Name) end)
							task.wait(0.06)
						end
					end
				end
			end
		end
		task.wait(1.5)
	end
end)

local RARITY_RANK = {
	Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5,
	Mythic = 6, Mythical = 6, Godly = 7, Divine = 8, Secret = 9, Prismatic = 10,
}
local function pickBestWildPet(refFolder)
	local best, bestRank
	for _, ref in ipairs(refFolder:GetChildren()) do
		if ref:IsA("BasePart") and (ref:GetAttribute("OwnerUserId") or 0) == 0 then
			local r = ref:GetAttribute("Rarity")
			local rank = (r and RARITY_RANK[r]) or 0
			local price = ref:GetAttribute("Price") or 0
			if not best or rank > bestRank
				or (rank == bestRank and price > (best:GetAttribute("Price") or 0)) then
				best, bestRank = ref, rank
			end
		end
	end
	return best
end
task.spawn(function()
	while ALIVE do
		if F.buyPets then
			local map = workspace:FindFirstChild("Map")
			local refFolder = map and map:FindFirstChild("WildPetRef")
			local best = refFolder and pickBestWildPet(refFolder)
			local hrp = getHRP()
			if best and hrp then
				acquire()
				local saved = hrp.CFrame
				local t0 = os.clock()
				while F.buyPets and best.Parent
					and (best:GetAttribute("OwnerUserId") or 0) == 0
					and os.clock() - t0 < 60 do
					local h2 = getHRP()
					if h2 then h2.CFrame = CFrame.new(best.Position + Vector3.new(0, 3, 2)) end
					pcall(function() Net.Pets.WildPetTame:Fire(best) end)
					task.wait(0.1)
				end
				local hb = getHRP()
				if hb then hb.CFrame = saved end
				release()
			end
		end
		task.wait(0.5)
	end
end)

task.spawn(function()
	while ALIVE do
		if F.eventSeeds then
			local map = workspace:FindFirstChild("Map")
			local locs = map and map:FindFirstChild("SeedPackSpawnServerLocations")
			if locs and #locs:GetChildren() > 0 then
				local hrp = getHRP()
				if hrp then
					acquire()
					local saved = hrp.CFrame
					for _, marker in ipairs(locs:GetChildren()) do
						if not F.eventSeeds then break end
						local cf = marker:IsA("BasePart") and marker.CFrame
							or (marker:IsA("Model") and select(1, pcall(function() return marker:GetPivot() end)) and marker:GetPivot())
						if cf then
							hrp.CFrame = cf + Vector3.new(0, 3, 0)
							task.wait(0.25)
						end
					end
					local h2 = getHRP()
					if h2 then h2.CFrame = saved end
					release()
				end
			end
		end
		task.wait(1)
	end
end)

local function isNight()
	local n = ReplicatedStorage:FindFirstChild("Night")
	return n ~= nil and n.Value == true
end

task.spawn(function()
	while ALIVE do
		if F.steal and isNight() then
			local hrp = getHRP()
			if hrp then
				acquire()
				local saved = hrp.CFrame
				local list = {}
				for _, prompt in ipairs(CollectionService:GetTagged("StealPrompt")) do
					if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt:IsDescendantOf(workspace) then
						local m = prompt.Parent:FindFirstAncestorWhichIsA("Model")
						if m then
							local uid = tonumber(m:GetAttribute("UserId"))
							local pid = m:GetAttribute("PlantId")
							local seed = m:GetAttribute("SeedName") or m:GetAttribute("CorePartName")
							if uid and uid ~= LP.UserId and pid and StealFlags.IsPlantStealable(seed) then
								list[#list + 1] = {
									m = m, pr = prompt, uid = uid, pid = pid,
									fid = m:GetAttribute("FruitId"), seed = seed,
									v = F.prioSteal and valueOf(m) or 0,
								}
							end
						end
					end
				end
				if F.prioSteal then
					table.sort(list, function(a, b) return a.v > b.v end)
				end
				for _, e in ipairs(list) do
					if not (F.steal and isNight()) then break end
					if e.m and e.m.Parent then
						local hold = e.pr.HoldDuration
						if hold == nil or hold == 0 then hold = StealFlags.GetStealHoldDuration(e.seed) end
						local h2 = getHRP()
						if h2 then h2.CFrame = e.m:GetPivot() * CFrame.new(0, 3, 0) end
						pcall(function() Net.Steal.BeginSteal:Fire(e.uid, e.pid, e.fid or "") end)
						if hold and hold > 0 then task.wait(hold + 0.15) end
						pcall(function() Net.Steal.CompleteSteal:Fire() end)
						task.wait(0.1)
					end
				end
				local hb = getHRP()
				if hb then hb.CFrame = saved end
				release()
			end
		end
		task.wait(F.steal and 0.5 or 1)
	end
end)

local function findShovel()
	local function scan(c) if c then for _, t in ipairs(c:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("Shovel") ~= nil then return t end
	end end end
	return scan(LP.Character) or scan(LP:FindFirstChildOfClass("Backpack"))
end
local function findIntruders()
	local pid = LP:GetAttribute("PlotId")
	local out = {}
	if not pid then return out end
	local gzd = ReplicatedStorage:FindFirstChild("GardenZoneData")
	if not gzd then return out end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local v = gzd:FindFirstChild(p.Name)
			local ch = p.Character
			if v and v.Value == pid and ch and ch:FindFirstChild("HumanoidRootPart") then
				out[#out + 1] = p
			end
		end
	end
	return out
end
task.spawn(function()
	while ALIVE do
		if F.antiSteal and isNight() then
			local intruders = findIntruders()
			local shovel = findShovel()
			local hrp = getHRP()
			if #intruders > 0 and shovel and hrp then
				acquire()
				local saved = hrp.CFrame
				local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
				if hum then pcall(function() hum:EquipTool(shovel) end) end
				for _, p in ipairs(intruders) do
					if not (F.antiSteal and isNight()) then break end
					local ch = p.Character
					local tHRP = ch and ch:FindFirstChild("HumanoidRootPart")
					if tHRP then
						local tp = tHRP.Position
						local h2 = getHRP()
						if h2 then h2.CFrame = CFrame.new(tp + Vector3.new(0, 0, 5), tp) end
						pcall(function() Net.Shovel.SwingShovel:Fire() end)
						pcall(function() Net.Shovel.HitPlayer:Fire(p.UserId) end)
						task.wait(0.66)
					end
				end
				local hb = getHRP()
				if hb then hb.CFrame = saved end
				release()
			end
		end
		task.wait(F.antiSteal and 0.2 or 1)
	end
end)


--========================================================================--
--                        GUI  (NightFall Style v3)                        --
--  Toggle cube: drag to reposition, click to open/close.                  --
--  Header accent bar + close button — matches buildaboat NightFall hub.   --
--========================================================================--

-- ── PALETTE ──────────────────────────────────────────────────────────────
local C = {
	bg         = Color3.fromRGB(13, 14, 18),
	sidebar    = Color3.fromRGB(16, 17, 23),
	surface    = Color3.fromRGB(22, 24, 31),
	surfaceHov = Color3.fromRGB(28, 30, 40),
	elevated   = Color3.fromRGB(34, 36, 46),
	border     = Color3.fromRGB(44, 46, 58),
	accent     = Color3.fromRGB(99, 102, 241),
	accentLight= Color3.fromRGB(129, 140, 248),
	success    = Color3.fromRGB(52, 211, 153),
	txt        = Color3.fromRGB(236, 237, 242),
	sub        = Color3.fromRGB(128, 132, 150),
	toggleOff  = Color3.fromRGB(55, 58, 72),
	toggleOn   = Color3.fromRGB(99, 102, 241),
	-- rarity colours
	Common     = Color3.fromRGB(180, 180, 180),
	Uncommon   = Color3.fromRGB(80, 210, 100),
	Rare       = Color3.fromRGB(80, 160, 240),
	Epic       = Color3.fromRGB(180, 90, 255),
	Legendary  = Color3.fromRGB(255, 175, 40),
	Mythic     = Color3.fromRGB(255, 80, 130),
	Super      = Color3.fromRGB(120, 230, 255),
}
-- keep amber alias for seed checklist rarity tags
C.amber     = C.accent
C.card      = C.surface
C.cardHov   = C.surfaceHov
C.panel     = C.sidebar
C.stroke    = C.border
C.green     = C.success

local RADIUS = { sm = 6, md = 10, lg = 14, xl = 20 }
local SIDEBAR_WIDTH = 132

local function corner(p, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or RADIUS.md); c.Parent = p; return c
end
local function stroke(p, col, th, tr)
	local s = Instance.new("UIStroke"); s.Color = col or C.border; s.Thickness = th or 1
	s.Transparency = tr or 0.45; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end
local function pad(p, t, r, b, l)
	local u = Instance.new("UIPadding")
	u.PaddingTop    = UDim.new(0, t)
	u.PaddingBottom = UDim.new(0, b or t)
	u.PaddingLeft   = UDim.new(0, l or r or t)
	u.PaddingRight  = UDim.new(0, r or t)
	u.Parent = p; return u
end

local function tween(inst, props, dur)
	TweenService:Create(inst, TweenInfo.new(dur or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

local function getParentGui()
	local g
	local ok = pcall(function() g = gethui and gethui() end)
	if ok and g then return g end
	ok = pcall(function() g = game:GetService("CoreGui") end)
	if ok and g then return g end
	return LP:WaitForChild("PlayerGui")
end

local old = getParentGui():FindFirstChild("GAG2Hub")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GAG2Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = getParentGui()

SELF.Destroy = function()
	ALIVE = false
	if ScreenGui then ScreenGui:Destroy() end
end

-- ── TOGGLE CUBE ───────────────────────────────────────────────────────────
local CUBE_SIZE = 44
local ToggleCubeCorner  -- forward ref so applyToggleCubeSize can update it

local ToggleGui = Instance.new("Frame")
ToggleGui.Name = "ToggleGui"
ToggleGui.Size = UDim2.new(0, CUBE_SIZE, 0, CUBE_SIZE)
ToggleGui.Position = UDim2.new(0.5, -math.floor(CUBE_SIZE / 2), 0, 14)
ToggleGui.BackgroundTransparency = 1
ToggleGui.Parent = ScreenGui

local ToggleCube = Instance.new("TextButton")
ToggleCube.Size = UDim2.new(1, 0, 1, 0)
ToggleCube.BackgroundColor3 = C.surface
ToggleCube.Text = ""
ToggleCube.AutoButtonColor = false
ToggleCube.Parent = ToggleGui
ToggleCubeCorner = corner(ToggleCube, math.clamp(math.floor(CUBE_SIZE * 0.22), 4, 14))
stroke(ToggleCube, C.accent, 1.5, 0.2)

local ToggleIcon = Instance.new("TextLabel")
ToggleIcon.Size = UDim2.new(1, 0, 1, 0)
ToggleIcon.BackgroundTransparency = 1
ToggleIcon.Text = "G2"
ToggleIcon.TextColor3 = C.accentLight
ToggleIcon.TextSize = math.clamp(math.floor(CUBE_SIZE * 0.44), 10, 28)
ToggleIcon.Font = Enum.Font.GothamBold
ToggleIcon.Parent = ToggleCube

-- ── MAIN FRAME ────────────────────────────────────────────────────────────
local main = Instance.new("Frame")
main.Name = "MainFrame"
main.Size = UDim2.new(0, 600, 0, 560)
main.Position = UDim2.new(0.5, -300, 0.5, -280)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Active = true
main.Visible = true
main.Parent = ScreenGui
corner(main, RADIUS.xl)
stroke(main, C.border, 1, 0.45)

-- ── HEADER ────────────────────────────────────────────────────────────────
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = C.sidebar
Header.BorderSizePixel = 0
Header.Parent = main
corner(Header, RADIUS.xl)

-- accent line under header
local HeaderAccent = Instance.new("Frame")
HeaderAccent.Size = UDim2.new(1, 0, 0, 3)
HeaderAccent.Position = UDim2.new(0, 0, 1, -3)
HeaderAccent.BackgroundColor3 = C.accent
HeaderAccent.BorderSizePixel = 0
HeaderAccent.Parent = Header

-- fill bottom rounded corners of header background
local HeaderFill = Instance.new("Frame")
HeaderFill.Size = UDim2.new(1, 0, 0, RADIUS.xl)
HeaderFill.Position = UDim2.new(0, 0, 1, -RADIUS.xl)
HeaderFill.BackgroundColor3 = C.sidebar
HeaderFill.BorderSizePixel = 0
HeaderFill.ZIndex = Header.ZIndex
HeaderFill.Parent = Header

local HubTitle = Instance.new("TextLabel")
HubTitle.Size = UDim2.new(1, -80, 0, 22)
HubTitle.Position = UDim2.new(0, 16, 0, 8)
HubTitle.BackgroundTransparency = 1
HubTitle.Text = "Grow a Garden 2"
HubTitle.TextColor3 = C.txt
HubTitle.TextSize = 18
HubTitle.Font = Enum.Font.GothamBold
HubTitle.TextXAlignment = Enum.TextXAlignment.Left
HubTitle.Parent = Header

local HubSub = Instance.new("TextLabel")
HubSub.Size = UDim2.new(1, -80, 0, 14)
HubSub.Position = UDim2.new(0, 16, 0, 30)
HubSub.BackgroundTransparency = 1
HubSub.Text = "Auto Hub  •  v4.0"
HubSub.TextColor3 = C.sub
HubSub.TextSize = 11
HubSub.Font = Enum.Font.GothamMedium
HubSub.TextXAlignment = Enum.TextXAlignment.Left
HubSub.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -38, 0.5, -14)
CloseBtn.BackgroundColor3 = C.elevated
CloseBtn.Text = "–"
CloseBtn.TextColor3 = C.sub
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header
corner(CloseBtn, RADIUS.sm)

-- ── VISIBILITY CONTROL ────────────────────────────────────────────────────
local hubVisible = true
local function setHubVisible(v)
	hubVisible = v
	main.Visible = v
end

CloseBtn.MouseButton1Click:Connect(function()
	setHubVisible(false)
end)

-- ── DRAG: FULL WINDOW (any part of main) ─────────────────────────────────
do
	local dragging, dragStart, frameStart
	main.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = i.Position; frameStart = main.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			local d = i.Position - dragStart
			main.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + d.X,
				frameStart.Y.Scale, frameStart.Y.Offset + d.Y)
		end
	end)
end

-- ── DRAG: TOGGLE CUBE — also moves main window together ──────────────────
do
	local toggleDragging, toggleMoved = false, false
	local toggleDragStart, toggleStartPos, mainStartPos
	local THRESHOLD = 8
	ToggleCube.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			toggleDragging = true; toggleMoved = false
			toggleDragStart = i.Position
			toggleStartPos  = ToggleGui.Position
			mainStartPos    = main.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			if toggleDragging and not toggleMoved then
				setHubVisible(not hubVisible)
			end
			toggleDragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if not toggleDragging then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			local d = i.Position - toggleDragStart
			if d.Magnitude > THRESHOLD then toggleMoved = true end
			if toggleMoved then
				ToggleGui.Position = UDim2.new(
					toggleStartPos.X.Scale, toggleStartPos.X.Offset + d.X,
					toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + d.Y)
				-- move main window by the same delta
				main.Position = UDim2.new(
					mainStartPos.X.Scale, mainStartPos.X.Offset + d.X,
					mainStartPos.Y.Scale, mainStartPos.Y.Offset + d.Y)
			end
		end
	end)
end

-- ── SIDEBAR ───────────────────────────────────────────────────────────────
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -68)
Sidebar.Position = UDim2.new(0, 10, 0, 58)
Sidebar.BackgroundColor3 = C.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = main
corner(Sidebar, RADIUS.xl)

local NavList = Instance.new("Frame")
NavList.Size = UDim2.new(1, -12, 1, -12)
NavList.Position = UDim2.new(0, 6, 0, 6)
NavList.BackgroundTransparency = 1
NavList.Parent = Sidebar
local NavLayout = Instance.new("UIListLayout")
NavLayout.Padding = UDim.new(0, 6)
NavLayout.Parent = NavList

-- ── CONTENT AREA ──────────────────────────────────────────────────────────
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -(SIDEBAR_WIDTH + 20), 1, -68)
contentArea.Position = UDim2.new(0, SIDEBAR_WIDTH + 10, 0, 58)
contentArea.BackgroundColor3 = C.surface
contentArea.ClipsDescendants = false
contentArea.BorderSizePixel = 0
contentArea.Parent = main
corner(contentArea, RADIUS.xl)

-- ── TAB SYSTEM ────────────────────────────────────────────────────────────
local pages, tabBtns = {}, {}

local function createTab(name, icon)
	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.new(1, -12, 1, -12)
	page.Position = UDim2.new(0, 6, 0, 6)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.ScrollBarImageColor3 = C.border
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = contentArea

	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 8)
	l.Parent = page
	local p2 = Instance.new("UIPadding")
	p2.PaddingTop = UDim.new(0, 4); p2.PaddingBottom = UDim.new(0, 8)
	p2.Parent = page

	pages[name] = page

	local tabBtn = Instance.new("TextButton")
	tabBtn.Size = UDim2.new(1, 0, 0, 36)
	tabBtn.BackgroundColor3 = C.sidebar
	tabBtn.Text = ""
	tabBtn.AutoButtonColor = false
	tabBtn.Parent = NavList
	corner(tabBtn, RADIUS.md)

	local tabIconLbl = Instance.new("TextLabel")
	tabIconLbl.Size = UDim2.new(0, 18, 1, 0)
	tabIconLbl.Position = UDim2.new(0, 10, 0, 0)
	tabIconLbl.BackgroundTransparency = 1
	tabIconLbl.Text = icon
	tabIconLbl.TextColor3 = C.sub
	tabIconLbl.TextSize = 12
	tabIconLbl.Font = Enum.Font.GothamBold
	tabIconLbl.Parent = tabBtn

	local tabLbl = Instance.new("TextLabel")
	tabLbl.Size = UDim2.new(1, -34, 1, 0)
	tabLbl.Position = UDim2.new(0, 28, 0, 0)
	tabLbl.BackgroundTransparency = 1
	tabLbl.Text = name
	tabLbl.TextColor3 = C.sub
	tabLbl.TextSize = #name > 8 and 11 or 13
	tabLbl.Font = Enum.Font.GothamSemibold
	tabLbl.TextXAlignment = Enum.TextXAlignment.Left
	tabLbl.Parent = tabBtn

	tabBtns[name] = tabBtn
	return page
end

local function switchTab(name)
	for n, pg in pairs(pages) do
		pg.Visible = (n == name)
		local b = tabBtns[n]
		if b then
			b.BackgroundColor3 = (n == name) and Color3.fromRGB(28, 30, 48) or C.sidebar
			for _, ch in ipairs(b:GetChildren()) do
				if ch:IsA("TextLabel") then
					ch.TextColor3 = (n == name) and C.accent or C.sub
				end
			end
		end
	end
end

-- ── WIDGET HELPERS ────────────────────────────────────────────────────────
local LO = 0
local function ord() LO = LO + 1; return LO end

local function sectionLabel(parent, txt)
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 24)
	wrap.LayoutOrder = ord()
	wrap.BackgroundTransparency = 1
	wrap.Parent = parent

	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, 0.5, 0)
	line.BackgroundColor3 = C.border
	line.BorderSizePixel = 0
	line.Parent = wrap

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundColor3 = C.surface
	lbl.Size = UDim2.new(0, 0, 1, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.X
	lbl.Text = "  " .. string.upper(txt) .. "  "
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 10
	lbl.TextColor3 = C.accent
	lbl.ZIndex = 3
	lbl.Parent = wrap
	pad(lbl, 0)
	return wrap
end

-- Toggle row (pill switch)
local function toggleRow(parent, label, key, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 46)
	row.LayoutOrder = ord()
	row.BackgroundColor3 = C.surface
	row.BorderSizePixel = 0
	row.Parent = parent
	corner(row, RADIUS.md)
	stroke(row, C.border, 1, 0.65)

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(14, 0)
	lbl.Size = UDim2.new(1, -68, 1, 0)
	lbl.Text = label
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 13
	lbl.TextColor3 = C.txt
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local pill = Instance.new("TextButton")
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Position = UDim2.new(1, -12, 0.5, 0)
	pill.Size = UDim2.fromOffset(46, 24)
	pill.BackgroundColor3 = C.toggleOff
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.Parent = row
	corner(pill, 12)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(18, 18)
	knob.Position = UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = C.txt
	knob.BorderSizePixel = 0
	knob.Parent = pill
	corner(knob, 9)

	local function render()
		local on = F[key]
		tween(pill, {BackgroundColor3 = on and C.toggleOn or C.toggleOff})
		tween(knob, {Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)})
		lbl.TextColor3 = on and C.txt or C.sub
	end
	pill.MouseButton1Click:Connect(function()
		F[key] = not F[key]; render()
		if onChange then onChange(F[key]) end
	end)
	render()
	return row
end

-- Button row
local function buttonRow(parent, label, btnText, cb)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 46)
	row.LayoutOrder = ord()
	row.BackgroundColor3 = C.surface
	row.BorderSizePixel = 0
	row.Parent = parent
	corner(row, RADIUS.md)
	stroke(row, C.border, 1, 0.65)

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(14, 0)
	lbl.Size = UDim2.new(1, -112, 1, 0)
	lbl.Text = label
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 13
	lbl.TextColor3 = C.txt
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -10, 0.5, 0)
	btn.Size = UDim2.fromOffset(94, 28)
	btn.BackgroundColor3 = C.accent
	btn.Text = btnText
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.AutoButtonColor = false
	btn.Parent = row
	corner(btn, RADIUS.sm)

	btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = C.accentLight}) end)
	btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = C.accent}) end)
	btn.MouseButton1Click:Connect(function() cb(btn) end)
	return row, btn
end

-- ── SEED CHECKLIST ────────────────────────────────────────────────────────
local function seedChecklist(parent, dataList, store)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, 200)
	box.LayoutOrder = ord()
	box.BackgroundColor3 = C.sidebar
	box.BorderSizePixel = 0
	box.Parent = parent
	corner(box, RADIUS.md)
	stroke(box, C.border, 1, 0.65)

	local hdr = Instance.new("Frame")
	hdr.Size = UDim2.new(1, 0, 0, 32)
	hdr.BackgroundColor3 = C.surface
	hdr.BorderSizePixel = 0
	hdr.Parent = box
	corner(hdr, RADIUS.md)
	local hdrFix = Instance.new("Frame")
	hdrFix.Size = UDim2.new(1, 0, 0, 8); hdrFix.Position = UDim2.new(0, 0, 1, -8)
	hdrFix.BackgroundColor3 = C.surface; hdrFix.BorderSizePixel = 0; hdrFix.Parent = hdr

	local hdrLbl = Instance.new("TextLabel")
	hdrLbl.BackgroundTransparency = 1; hdrLbl.Position = UDim2.fromOffset(10, 0)
	hdrLbl.Size = UDim2.new(1, -110, 1, 0); hdrLbl.Text = "Select seeds to buy"
	hdrLbl.Font = Enum.Font.GothamMedium; hdrLbl.TextSize = 12; hdrLbl.TextColor3 = C.sub
	hdrLbl.TextXAlignment = Enum.TextXAlignment.Left; hdrLbl.Parent = hdr

	local function miniBtn(txt, xOff, col)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 0.5); b.Position = UDim2.new(1, xOff, 0.5, 0)
		b.Size = UDim2.fromOffset(44, 20); b.BackgroundColor3 = col or C.elevated; b.Text = txt
		b.Font = Enum.Font.GothamBold; b.TextSize = 11
		b.TextColor3 = C.txt; b.ZIndex = 4; b.Parent = hdr
		corner(b, RADIUS.sm); stroke(b, col or C.border, 1, 0.55); return b
	end

	local sc = Instance.new("ScrollingFrame")
	sc.Position = UDim2.fromOffset(0, 32); sc.Size = UDim2.new(1, 0, 1, -32)
	sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0
	sc.ScrollBarThickness = 3; sc.ScrollBarImageColor3 = C.accent
	sc.CanvasSize = UDim2.new(); sc.Parent = box
	local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 2); ll.Parent = sc
	ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		sc.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 8)
	end)
	pad(sc, 4, 5, 4, 5)

	local paints = {}
	for _, sd in ipairs(dataList) do
		local name   = sd.name
		local rarity = sd.rarity or "Common"
		local imgUrl = sd.img
		local rarCol = C[rarity] or C.Common

		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -10, 0, 34)
		row.BackgroundColor3 = C.surface; row.AutoButtonColor = false; row.Text = ""
		row.ZIndex = 4; row.Parent = sc; corner(row, RADIUS.sm)

		local accent2 = Instance.new("Frame")
		accent2.Size = UDim2.fromOffset(3, 24); accent2.Position = UDim2.fromOffset(6, 5)
		accent2.BackgroundColor3 = rarCol; accent2.BorderSizePixel = 0; accent2.ZIndex = 5; accent2.Parent = row
		corner(accent2, 2)

		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromOffset(24, 24); img.Position = UDim2.fromOffset(14, 5)
		img.BackgroundTransparency = 1; img.Image = imgUrl; img.ZIndex = 5; img.Parent = row

		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1; nameLbl.Position = UDim2.fromOffset(44, 0)
		nameLbl.Size = UDim2.new(1, -100, 1, 0); nameLbl.Text = name
		nameLbl.Font = Enum.Font.GothamMedium; nameLbl.TextSize = 12; nameLbl.TextColor3 = C.txt
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 5; nameLbl.Parent = row

		local rarTag = Instance.new("TextLabel")
		rarTag.AnchorPoint = Vector2.new(1, 0.5); rarTag.Position = UDim2.new(1, -36, 0.5, 0)
		rarTag.Size = UDim2.fromOffset(60, 16)
		rarTag.BackgroundColor3 = rarCol; rarTag.BackgroundTransparency = 0.7
		rarTag.Text = rarity; rarTag.Font = Enum.Font.GothamBold; rarTag.TextSize = 9
		rarTag.TextColor3 = rarCol; rarTag.ZIndex = 5; rarTag.Parent = row; corner(rarTag, 4)

		local cb = Instance.new("Frame")
		cb.AnchorPoint = Vector2.new(1, 0.5); cb.Position = UDim2.new(1, -8, 0.5, 0)
		cb.Size = UDim2.fromOffset(18, 18)
		cb.BackgroundColor3 = store[name] and C.success or C.toggleOff
		cb.BorderSizePixel = 0; cb.ZIndex = 5; cb.Parent = row; corner(cb, 4)

		local chk = Instance.new("TextLabel"); chk.BackgroundTransparency = 1
		chk.Size = UDim2.fromScale(1, 1); chk.Text = "✓"; chk.Font = Enum.Font.GothamBold
		chk.TextSize = 12; chk.TextColor3 = Color3.fromRGB(255, 255, 255)
		chk.Visible = store[name]; chk.ZIndex = 6; chk.Parent = cb

		local function paint()
			local on = store[name]
			tween(cb, {BackgroundColor3 = on and C.success or C.toggleOff})
			chk.Visible = on
			row.BackgroundColor3 = on and C.surfaceHov or C.surface
		end
		paints[name] = paint
		row.MouseButton1Click:Connect(function() store[name] = not store[name]; paint() end)
	end

	miniBtn("All", -6, C.accent).MouseButton1Click:Connect(function()
		for _, sd in ipairs(dataList) do store[sd.name] = true; if paints[sd.name] then paints[sd.name]() end end
	end)
	miniBtn("None", -54).MouseButton1Click:Connect(function()
		for _, sd in ipairs(dataList) do store[sd.name] = false; if paints[sd.name] then paints[sd.name]() end end
	end)
	return box
end

-- ── GEAR CHECKLIST ────────────────────────────────────────────────────────
local function gearChecklist(parent, names, store)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, 160)
	box.LayoutOrder = ord()
	box.BackgroundColor3 = C.sidebar
	box.BorderSizePixel = 0
	box.Parent = parent
	corner(box, RADIUS.md)
	stroke(box, C.border, 1, 0.65)

	local hdr = Instance.new("Frame")
	hdr.Size = UDim2.new(1, 0, 0, 30)
	hdr.BackgroundColor3 = C.surface; hdr.BorderSizePixel = 0; hdr.Parent = box
	corner(hdr, RADIUS.md)
	local hdrFix = Instance.new("Frame")
	hdrFix.Size = UDim2.new(1, 0, 0, 8); hdrFix.Position = UDim2.new(0, 0, 1, -8)
	hdrFix.BackgroundColor3 = C.surface; hdrFix.BorderSizePixel = 0; hdrFix.Parent = hdr

	local hdrLbl = Instance.new("TextLabel")
	hdrLbl.BackgroundTransparency = 1; hdrLbl.Position = UDim2.fromOffset(10, 0)
	hdrLbl.Size = UDim2.new(1, -110, 1, 0); hdrLbl.Text = "Select gears to buy"
	hdrLbl.Font = Enum.Font.GothamMedium; hdrLbl.TextSize = 12; hdrLbl.TextColor3 = C.sub
	hdrLbl.TextXAlignment = Enum.TextXAlignment.Left; hdrLbl.Parent = hdr

	local function miniBtn(txt, xOff, col)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 0.5); b.Position = UDim2.new(1, xOff, 0.5, 0)
		b.Size = UDim2.fromOffset(44, 20); b.BackgroundColor3 = col or C.elevated; b.Text = txt
		b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.TextColor3 = C.txt; b.ZIndex = 4; b.Parent = hdr
		corner(b, RADIUS.sm); stroke(b, col or C.border, 1, 0.55); return b
	end

	local sc = Instance.new("ScrollingFrame")
	sc.Position = UDim2.fromOffset(0, 30); sc.Size = UDim2.new(1, 0, 1, -30)
	sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0
	sc.ScrollBarThickness = 3; sc.ScrollBarImageColor3 = C.accent
	sc.CanvasSize = UDim2.new(); sc.Parent = box
	local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 2); ll.Parent = sc
	ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		sc.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 8)
	end)
	pad(sc, 4, 5, 4, 5)

	local paints = {}
	for _, name in ipairs(names) do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -10, 0, 30)
		row.BackgroundColor3 = C.surface; row.AutoButtonColor = false; row.Text = ""
		row.ZIndex = 4; row.Parent = sc; corner(row, RADIUS.sm)

		local nm = Instance.new("TextLabel"); nm.BackgroundTransparency = 1
		nm.Position = UDim2.fromOffset(10, 0); nm.Size = UDim2.new(1, -36, 1, 0); nm.Text = name
		nm.Font = Enum.Font.GothamMedium; nm.TextSize = 12; nm.TextColor3 = C.txt
		nm.TextXAlignment = Enum.TextXAlignment.Left; nm.ZIndex = 5; nm.Parent = row

		local cb = Instance.new("Frame")
		cb.AnchorPoint = Vector2.new(1, 0.5); cb.Position = UDim2.new(1, -8, 0.5, 0)
		cb.Size = UDim2.fromOffset(18, 18)
		cb.BackgroundColor3 = store[name] and C.success or C.toggleOff
		cb.BorderSizePixel = 0; cb.ZIndex = 5; cb.Parent = row; corner(cb, 4)
		local chk = Instance.new("TextLabel"); chk.BackgroundTransparency = 1
		chk.Size = UDim2.fromScale(1, 1); chk.Text = "✓"; chk.Font = Enum.Font.GothamBold
		chk.TextSize = 12; chk.TextColor3 = Color3.fromRGB(255, 255, 255)
		chk.Visible = store[name]; chk.ZIndex = 6; chk.Parent = cb

		local function paint()
			local on = store[name]
			tween(cb, {BackgroundColor3 = on and C.success or C.toggleOff})
			chk.Visible = on; row.BackgroundColor3 = on and C.surfaceHov or C.surface
		end
		paints[name] = paint
		row.MouseButton1Click:Connect(function() store[name] = not store[name]; paint() end)
	end

	miniBtn("All", -6, C.accent).MouseButton1Click:Connect(function()
		for _, n in ipairs(names) do store[n] = true; if paints[n] then paints[n]() end end
	end)
	miniBtn("None", -54).MouseButton1Click:Connect(function()
		for _, n in ipairs(names) do store[n] = false; if paints[n] then paints[n]() end end
	end)
	return box
end

-- ── FARM TAB ──────────────────────────────────────────────────────────────
local farm = createTab("Farm", "🌾")
sectionLabel(farm, "Harvest")
toggleRow(farm, "Auto Harvest  (instant)", "harvest")
toggleRow(farm, "Harvest highest value first", "prioHarvest")
sectionLabel(farm, "Planting")
toggleRow(farm, "Auto Plant Seeds", "plant")
toggleRow(farm, "Stack all on one spot", "plantStack")
buttonRow(farm, "Stack spot  (stand here)", "Set Spot", function(b)
	local hrp = getHRP()
	if hrp then
		F.plantPoint = groundPointUnder(hrp.Position) or (hrp.Position - Vector3.new(0, 2.5, 0))
		b.Text = "Set ✓"
		task.delay(1.5, function() if b and b.Parent then b.Text = "Set Spot" end end)
	end
end)
sectionLabel(farm, "Economy")
toggleRow(farm, "Auto Sell Inventory", "sell")
sectionLabel(farm, "Night & Events")
toggleRow(farm, "Auto Steal  (night only)", "steal")
toggleRow(farm, "Steal highest value first", "prioSteal")
toggleRow(farm, "Anti-Steal  (hit intruders)", "antiSteal")
toggleRow(farm, "Auto Collect Event Seeds", "eventSeeds")

-- ── SHOP TAB ──────────────────────────────────────────────────────────────
local shop = createTab("Shop", "🛒")
sectionLabel(shop, "Seeds")
toggleRow(shop, "Auto Buy Seeds", "buySeeds")
seedChecklist(shop, SEED_DATA, seedSelected)
sectionLabel(shop, "Gears")
toggleRow(shop, "Auto Buy Gears", "buyGears")
gearChecklist(shop, gearNames, gearSelected)
sectionLabel(shop, "Pets")
toggleRow(shop, "Auto Buy Best Wild Pet", "buyPets")

-- ── INFO TAB ──────────────────────────────────────────────────────────────
local info = createTab("Info", "📋")
sectionLabel(info, "Status")

local statCard = Instance.new("Frame")
statCard.Size = UDim2.new(1, 0, 0, 130)
statCard.LayoutOrder = ord()
statCard.BackgroundColor3 = C.surface
statCard.BorderSizePixel = 0
statCard.Parent = info
corner(statCard, RADIUS.md)
stroke(statCard, C.border, 1, 0.65)
pad(statCard, 12)

local statText = Instance.new("TextLabel")
statText.BackgroundTransparency = 1
statText.Size = UDim2.fromScale(1, 1)
statText.Font = Enum.Font.Gotham
statText.TextSize = 12
statText.TextColor3 = C.sub
statText.TextXAlignment = Enum.TextXAlignment.Left
statText.TextYAlignment = Enum.TextYAlignment.Top
statText.Text = ""
statText.Parent = statCard

task.spawn(function()
	while ALIVE do
		local night = isNight()
		local active = {}
		if F.harvest    then table.insert(active, "🌾 Harvest") end
		if F.plant      then table.insert(active, "🌱 Plant") end
		if F.sell       then table.insert(active, "💰 Sell") end
		if F.steal      then table.insert(active, "🌙 Steal") end
		if F.eventSeeds then table.insert(active, "✨ Events") end
		if F.buySeeds   then table.insert(active, "🛒 Seeds") end
		if F.buyGears   then table.insert(active, "⚙️ Gears") end
		if F.buyPets    then table.insert(active, "🐾 Pets") end
		statText.Text = string.format(
			"Player:   %s\nNight:    %s\nActive:   %s",
			LP.Name,
			night and "✅ YES  (steal active)" or "❌ No",
			#active > 0 and table.concat(active, "  ") or "—  (nothing enabled)"
		)
		task.wait(0.5)
	end
end)

sectionLabel(info, "About")
local aboutCard = Instance.new("Frame")
aboutCard.Size = UDim2.new(1, 0, 0, 60)
aboutCard.LayoutOrder = ord()
aboutCard.BackgroundColor3 = C.surface
aboutCard.BorderSizePixel = 0
aboutCard.Parent = info
corner(aboutCard, RADIUS.md)
stroke(aboutCard, C.border, 1, 0.65)
pad(aboutCard, 10)
local aboutText = Instance.new("TextLabel")
aboutText.BackgroundTransparency = 1
aboutText.Size = UDim2.fromScale(1, 1)
aboutText.Font = Enum.Font.Gotham
aboutText.TextSize = 11
aboutText.TextColor3 = C.sub
aboutText.TextXAlignment = Enum.TextXAlignment.Left
aboutText.TextYAlignment = Enum.TextYAlignment.Top
aboutText.TextWrapped = true
aboutText.Text = "GAG2 Auto Hub v3.0  •  NightFall Style\nClick the G2 cube to show/hide. Drag it to reposition.\nDrag the header bar to move the main window."
aboutText.Parent = aboutCard

-- ── SETTINGS TAB ─────────────────────────────────────────────────────────
local settings = createTab("Settings", "⚙")

-- Slider helper: returns the current value (number)
local function makeSlider(parent, label, minVal, maxVal, initVal, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 64)
	row.LayoutOrder = ord()
	row.BackgroundColor3 = C.surface
	row.BorderSizePixel = 0
	row.Parent = parent
	corner(row, RADIUS.md)
	stroke(row, C.border, 1, 0.65)

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(14, 10)
	lbl.Size = UDim2.new(1, -80, 0, 18)
	lbl.Text = label
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 13
	lbl.TextColor3 = C.txt
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local valLbl = Instance.new("TextLabel")
	valLbl.BackgroundTransparency = 1
	valLbl.AnchorPoint = Vector2.new(1, 0)
	valLbl.Position = UDim2.new(1, -14, 0, 10)
	valLbl.Size = UDim2.fromOffset(52, 18)
	valLbl.Text = tostring(initVal)
	valLbl.Font = Enum.Font.GothamBold
	valLbl.TextSize = 13
	valLbl.TextColor3 = C.accent
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.Parent = row

	-- track background
	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 14, 0, 40)
	track.Size = UDim2.new(1, -28, 0, 6)
	track.BackgroundColor3 = C.elevated
	track.BorderSizePixel = 0
	track.Parent = row
	corner(track, 3)

	-- filled portion
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((initVal - minVal) / (maxVal - minVal), 0, 1, 0)
	fill.BackgroundColor3 = C.accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 3)

	-- knob
	local knob = Instance.new("TextButton")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new((initVal - minVal) / (maxVal - minVal), 0, 0.5, 0)
	knob.BackgroundColor3 = C.txt
	knob.Text = ""
	knob.AutoButtonColor = false
	knob.ZIndex = 3
	knob.Parent = track
	corner(knob, 8)

	local currentVal = initVal
	local sliding = false

	local function setVal(v)
		v = math.clamp(math.floor(v + 0.5), minVal, maxVal)
		currentVal = v
		local pct = (v - minVal) / (maxVal - minVal)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		knob.Position = UDim2.new(pct, 0, 0.5, 0)
		valLbl.Text = tostring(v)
		onChange(v)
	end

	local function updateFromInput(input)
		local trackAbsPos = track.AbsolutePosition
		local trackAbsSize = track.AbsoluteSize
		local relX = math.clamp((input.Position.X - trackAbsPos.X) / trackAbsSize.X, 0, 1)
		local v = minVal + relX * (maxVal - minVal)
		setVal(v)
	end

	knob.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			sliding = true
		end
	end)
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			updateFromInput(i)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if not sliding then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			updateFromInput(i)
		end
	end)

	return row, setVal
end

sectionLabel(settings, "Toggle Button")

local GUI_W, GUI_H = 600, 560  -- current GUI size

-- Cube size slider (24–100)
makeSlider(settings, "Button Size", 24, 100, CUBE_SIZE, function(v)
	ToggleGui.Size = UDim2.new(0, v, 0, v)
	if ToggleCubeCorner then
		ToggleCubeCorner.CornerRadius = UDim.new(0, math.clamp(math.floor(v * 0.22), 4, 14))
	end
	ToggleIcon.TextSize = math.clamp(math.floor(v * 0.44), 10, 28)
end)

sectionLabel(settings, "Window Size")

-- GUI Width slider (400–900)
makeSlider(settings, "Width", 400, 900, GUI_W, function(v)
	GUI_W = v
	main.Size = UDim2.fromOffset(GUI_W, GUI_H)
end)

-- GUI Height slider (360–700)
makeSlider(settings, "Height", 360, 700, GUI_H, function(v)
	GUI_H = v
	main.Size = UDim2.fromOffset(GUI_W, GUI_H)
end)

-- Reset button
local resetRow = Instance.new("Frame")
resetRow.Size = UDim2.new(1, 0, 0, 46)
resetRow.LayoutOrder = ord()
resetRow.BackgroundColor3 = C.surface
resetRow.BorderSizePixel = 0
resetRow.Parent = settings
corner(resetRow, RADIUS.md)
stroke(resetRow, C.border, 1, 0.65)

local resetLbl = Instance.new("TextLabel")
resetLbl.BackgroundTransparency = 1
resetLbl.Position = UDim2.fromOffset(14, 0)
resetLbl.Size = UDim2.new(1, -112, 1, 0)
resetLbl.Text = "Reset all sizes to default"
resetLbl.Font = Enum.Font.GothamMedium
resetLbl.TextSize = 13
resetLbl.TextColor3 = C.txt
resetLbl.TextXAlignment = Enum.TextXAlignment.Left
resetLbl.Parent = resetRow

local resetBtn = Instance.new("TextButton")
resetBtn.AnchorPoint = Vector2.new(1, 0.5)
resetBtn.Position = UDim2.new(1, -10, 0.5, 0)
resetBtn.Size = UDim2.fromOffset(80, 28)
resetBtn.BackgroundColor3 = C.elevated
resetBtn.Text = "Reset"
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 12
resetBtn.TextColor3 = C.sub
resetBtn.AutoButtonColor = false
resetBtn.Parent = resetRow
corner(resetBtn, RADIUS.sm)
stroke(resetBtn, C.border, 1, 0.55)

resetBtn.MouseButton1Click:Connect(function()
	-- Reset GUI size
	GUI_W, GUI_H = 600, 560
	main.Size = UDim2.fromOffset(GUI_W, GUI_H)
	-- Reset cube size
	local def = 44
	ToggleGui.Size = UDim2.new(0, def, 0, def)
	if ToggleCubeCorner then
		ToggleCubeCorner.CornerRadius = UDim.new(0, math.clamp(math.floor(def * 0.22), 4, 14))
	end
	ToggleIcon.TextSize = math.clamp(math.floor(def * 0.44), 10, 28)
end)

-- ── SELECT INITIAL TAB ────────────────────────────────────────────────────
for name, btn in pairs(tabBtns) do
	btn.MouseButton1Click:Connect(function() switchTab(name) end)
end
switchTab("Farm")

-- ── OPEN ANIMATION ────────────────────────────────────────────────────────
main.Size = UDim2.fromOffset(0, 0)
main.BackgroundTransparency = 1
TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
	Size = UDim2.fromOffset(600, 560),
	BackgroundTransparency = 0,
}):Play()

print("[GAG2 Hub v4] Loaded — Click the G2 cube to toggle.")
