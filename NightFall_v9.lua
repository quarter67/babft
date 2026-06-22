--[[
	GAG 2 NightFall v9
	Fixed: GUI now builds unconditionally before any game-module loading.
	All networking is fully deferred to background threads.
]]

--========================== SERVICES ==========================--
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local LP                = Players.LocalPlayer

--========================== KILL OLD ==========================--
if _G.__NF and _G.__NF.Destroy then pcall(_G.__NF.Destroy) end
local SELF = {}; _G.__NF = SELF
local ALIVE = true
SELF.Destroy = function() ALIVE = false end

--========================== HELPERS ==========================--
local function getParentGui()
	local ok, g
	ok, g = pcall(function() return gethui() end);           if ok and g then return g end
	ok, g = pcall(function() return game:GetService("CoreGui") end); if ok and g then return g end
	return LP:WaitForChild("PlayerGui", 10)
end

local function tw(inst, props, dur)
	TweenService:Create(inst, TweenInfo.new(dur or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

local function mkCorner(p, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 10); c.Parent = p; return c
end
local function mkStroke(p, col, th)
	local s = Instance.new("UIStroke"); s.Color = col or Color3.fromRGB(44,46,58)
	s.Thickness = th or 1; s.Transparency = 0.45; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end
local function mkPad(p, t, r, b, l)
	local u = Instance.new("UIPadding")
	u.PaddingTop    = UDim.new(0, t)
	u.PaddingBottom = UDim.new(0, b or t)
	u.PaddingLeft   = UDim.new(0, l or r or t)
	u.PaddingRight  = UDim.new(0, r or t)
	u.Parent = p
end

--========================== COLOURS ==========================--
local C = {
	bg         = Color3.fromRGB(13,14,18),
	sidebar    = Color3.fromRGB(16,17,23),
	surface    = Color3.fromRGB(22,24,31),
	surfaceHov = Color3.fromRGB(28,30,40),
	elevated   = Color3.fromRGB(34,36,46),
	border     = Color3.fromRGB(44,46,58),
	accent     = Color3.fromRGB(99,102,241),
	accentHov  = Color3.fromRGB(129,140,248),
	success    = Color3.fromRGB(52,211,153),
	danger     = Color3.fromRGB(239,68,68),
	txt        = Color3.fromRGB(236,237,242),
	sub        = Color3.fromRGB(128,132,150),
	off        = Color3.fromRGB(55,58,72),
	Common     = Color3.fromRGB(180,180,180),
	Uncommon   = Color3.fromRGB(80,210,100),
	Rare       = Color3.fromRGB(80,160,240),
	Epic       = Color3.fromRGB(180,90,255),
	Legendary  = Color3.fromRGB(255,175,40),
	Mythic     = Color3.fromRGB(255,80,130),
	Super      = Color3.fromRGB(120,230,255),
}

--========================== PERSISTENT SETTINGS ==========================--
if not _G.NFSettings then _G.NFSettings = {} end
local S = _G.NFSettings
local function sg(k,d) if S[k]==nil then S[k]=d end; return S[k] end
local function ss(k,v) S[k]=v end

--========================== STATE ==========================--
local F = {}
local FKEYS = {"harvest","prioHarvest","plant","sell","steal","prioSteal","antiSteal","eventSeeds","buySeeds","buyGears","buyPets","autoScan"}
local FDEFAULT = {}
for _,k in ipairs(FKEYS) do FDEFAULT[k]=false; F[k]=sg(k,false) end

local SHOP = { maxSeeds=sg("maxSeeds",200), moneyFloor=sg("moneyFloor",0) }
local PLANT = {
	spacing       = sg("plantSpacing", 2.5),
	zone          = nil,
	zoneSize      = Vector3.new(sg("zoneX",20), 0.1, sg("zoneZ",20)),
	zoneAngle     = sg("zoneAngle",0),
	stopUnder     = sg("plantStopUnder",0),
	stopMoneyOver = sg("plantStopMoneyOver",0),
}

local seedSel       = sg("seedSel",       {})
local plantSeedSel  = sg("plantSeedSel",  {})
local gearSel       = sg("gearSel",       {})

--========================== ITEM DATA ==========================--
local SEEDS = {
	{name="Carrot",          rarity="Common"},
	{name="Strawberry",      rarity="Common"},
	{name="Blueberry",       rarity="Common"},
	{name="Tulip",           rarity="Uncommon"},
	{name="Tomato",          rarity="Uncommon"},
	{name="Apple",           rarity="Uncommon"},
	{name="Bamboo",          rarity="Rare"},
	{name="Corn",            rarity="Rare"},
	{name="Cactus",          rarity="Rare"},
	{name="Pineapple",       rarity="Rare"},
	{name="Mushroom",        rarity="Epic"},
	{name="Green Bean",      rarity="Epic"},
	{name="Banana",          rarity="Epic"},
	{name="Grape",           rarity="Epic"},
	{name="Coconut",         rarity="Epic"},
	{name="Mango",           rarity="Epic"},
	{name="Dragon Fruit",    rarity="Legendary"},
	{name="Acorn",           rarity="Legendary"},
	{name="Cherry",          rarity="Legendary"},
	{name="Sunflower",       rarity="Legendary"},
	{name="Venus Fly Trap",  rarity="Mythic"},
	{name="Pomegranate",     rarity="Mythic"},
	{name="Poison Apple",    rarity="Mythic"},
	{name="Moon Bloom",      rarity="Super"},
	{name="Venom Spitter",   rarity="Mythic"},
	{name="Dragon's Breath", rarity="Super"},
}
local GEARS = {
	{name="Common Watering Can",   rarity="Common"},
	{name="Common Sprinkler",      rarity="Common"},
	{name="Sign",                  rarity="Common"},
	{name="Lantern",               rarity="Common"},
	{name="Uncommon Sprinkler",    rarity="Uncommon"},
	{name="Trowel",                rarity="Rare"},
	{name="Rare Sprinkler",        rarity="Rare"},
	{name="Jump Mushroom",         rarity="Rare"},
	{name="Speed Mushroom",        rarity="Rare"},
	{name="Shrink Mushroom",       rarity="Epic"},
	{name="Supersize Mushroom",    rarity="Epic"},
	{name="Gnome",                 rarity="Epic"},
	{name="Flashbang",             rarity="Epic"},
	{name="Basic Pot",             rarity="Epic"},
	{name="Legendary Sprinkler",   rarity="Legendary"},
	{name="Invisibility Mushroom", rarity="Legendary"},
	{name="Teleporter",            rarity="Legendary"},
	{name="Wheelbarrow",           rarity="Legendary"},
	{name="Player Magnet",         rarity="Mythic"},
	{name="Super Watering Can",    rarity="Super"},
	{name="Super Sprinkler",       rarity="Super"},
}
for _,sd in ipairs(SEEDS) do
	if seedSel[sd.name]==nil      then seedSel[sd.name]=true end
	if plantSeedSel[sd.name]==nil then plantSeedSel[sd.name]=true end
end
for _,gd in ipairs(GEARS) do if gearSel[gd.name]==nil then gearSel[gd.name]=true end end
ss("seedSel",seedSel); ss("plantSeedSel",plantSeedSel); ss("gearSel",gearSel)

--========================== NETWORKING (deferred) ==========================--
local Net, StealFlags, FruitValueCalc
task.spawn(function()
	for i=1,60 do
		local ok,err = pcall(function()
			Net            = require(ReplicatedStorage.SharedModules.Networking)
			StealFlags     = require(ReplicatedStorage.SharedModules.Flags.StealFlags)
			FruitValueCalc = require(ReplicatedStorage.SharedModules.FruitValueCalc)
		end)
		if ok then print("[NightFall] Networking ready (attempt "..i..")"); return end
		task.wait(1)
	end
	warn("[NightFall] Networking unavailable after 60s")
end)

--========================== UTILITY ==========================--
local function getPlayerMoney()
	local v = LP:GetAttribute("Cash") or LP:GetAttribute("Coins") or LP:GetAttribute("Money") or LP:GetAttribute("Gold")
	if type(v)=="number" then return v end
	local ls = LP:FindFirstChild("leaderstats")
	if ls then for _,c in ipairs(ls:GetChildren()) do if c:IsA("NumberValue") or c:IsA("IntValue") then return c.Value end end end
	return math.huge
end
local function valueOf(m)
	if not FruitValueCalc then return 0 end
	local name = m:GetAttribute("CorePartName") or m:GetAttribute("SeedName")
	if not name then return 0 end
	local ok,v = pcall(FruitValueCalc, name, m:GetAttribute("SizeMulti") or 1, m:GetAttribute("Mutation"), LP, m:GetAttribute("DecayAlpha"))
	return (ok and type(v)=="number") and v or 0
end
local function formatVal(n)
	if n>=1e9 then return string.format("%.1fB",n/1e9) elseif n>=1e6 then return string.format("%.1fM",n/1e6) elseif n>=1e3 then return string.format("%.1fK",n/1e3) else return tostring(math.floor(n)) end
end
local function totalSeedsInBag()
	local n=0
	local function scan(c) if c then for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("SeedTool")~=nil then n=n+(t:GetAttribute("Count") or 1) end end end end
	scan(LP:FindFirstChildOfClass("Backpack")); scan(LP.Character); return n
end
local function countSeed(name)
	local n=0
	local function scan(c) if c then for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("SeedTool")==name then n=n+(t:GetAttribute("Count") or 1) end end end end
	scan(LP:FindFirstChildOfClass("Backpack")); scan(LP.Character); return n
end
local function stockFolder(shop)
	local sv=ReplicatedStorage:FindFirstChild("StockValues"); local sh=sv and sv:FindFirstChild(shop); return sh and sh:FindFirstChild("Items")
end
local function getHRP() local c=LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local busy=false
local function acquire() local t0=os.clock(); while busy and ALIVE and os.clock()-t0<30 do task.wait() end; busy=true end
local function release() busy=false end
local function isNight() local n=ReplicatedStorage:FindFirstChild("Night"); return n~=nil and n.Value==true end

--========================== FEATURE LOOPS ==========================--

-- HARVEST
local hDebounce={}
task.spawn(function()
	while ALIVE do
		if F.harvest and Net then
			local myId=LP.UserId
			local tagged=CollectionService:GetTagged("HarvestPrompt")
			local list={}
			for _,p in ipairs(tagged) do
				if p:IsA("ProximityPrompt") and p.Parent and p:IsDescendantOf(workspace) then
					local m=p.Parent:FindFirstAncestorWhichIsA("Model")
					if m and tonumber(m:GetAttribute("UserId"))==myId and m:GetAttribute("PlantId") then
						list[#list+1]={m=m,v=F.prioHarvest and valueOf(m) or 0}
					end
				end
			end
			if F.prioHarvest then table.sort(list,function(a,b) return a.v>b.v end) end
			for _,e in ipairs(list) do
				if not F.harvest then break end
				local m=e.m; local pid=m:GetAttribute("PlantId"); local fid=m:GetAttribute("FruitId")
				local key=tostring(pid).."|"..tostring(fid); local now=os.clock()
				if not hDebounce[key] or now-hDebounce[key]>0.15 then
					hDebounce[key]=now; pcall(function() Net.Garden.CollectFruit:Fire(pid, fid or "") end)
				end
			end
			if #tagged==0 then table.clear(hDebounce) end
		end
		RunService.Heartbeat:Wait()
	end
end)

-- SELL
task.spawn(function()
	while ALIVE do
		if F.sell and Net then
			local ok,preview=pcall(function() return Net.NPCS.PreviewSellAll:InvokeServer() end)
			if ok and preview and (preview.FruitCount or 0)>0 then pcall(function() Net.NPCS.SellAll:Fire() end) end
		end
		task.wait(0.3)
	end
end)

-- PLANT
local function groundPointUnder(pos)
	local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances=CollectionService:GetTagged("PlantArea")
	local r=workspace:Raycast(pos+Vector3.new(0,12,0),Vector3.new(0,-60,0),params)
	return r and r.Position
end
local function generateSlots()
	local gap=PLANT.spacing; local slots={}
	if PLANT.zone then
		local cf=PLANT.zone; local szX=PLANT.zoneSize.X; local szZ=PLANT.zoneSize.Z
		local nx=math.max(1,math.floor(szX/gap)); local nz=math.max(1,math.floor(szZ/gap))
		for iz=0,nz-1 do
			local cols={}; for ix=0,nx-1 do cols[#cols+1]=ix end
			if iz%2==1 then local r2={}; for i=#cols,1,-1 do r2[#r2+1]=cols[i] end; cols=r2 end
			for _,ix in ipairs(cols) do
				local lx=(-szX/2)+gap*0.5+ix*gap; local lz=(-szZ/2)+gap*0.5+iz*gap
				local wp=cf:PointToWorldSpace(Vector3.new(lx,0,lz)); local gp=groundPointUnder(wp)
				if gp then slots[#slots+1]=gp end
			end
		end
		return slots
	end
	local plotId=LP:GetAttribute("PlotId"); local plot=plotId and workspace:FindFirstChild("Gardens") and workspace.Gardens:FindFirstChild("Plot"..tostring(plotId))
	if not plot then return slots end
	local CELL=2; local MIN2=gap*gap*0.9; local bkts={}
	local function bk(cx,cz) return cx..","..cz end
	local function addPt(p) local cx,cz=math.floor(p.X/CELL),math.floor(p.Z/CELL); local k=bk(cx,cz); if not bkts[k] then bkts[k]={} end; table.insert(bkts[k],p) end
	local function tooClose(p) local cx,cz=math.floor(p.X/CELL),math.floor(p.Z/CELL); for dx=-1,1 do for dz=-1,1 do local b=bkts[bk(cx+dx,cz+dz)]; if b then for _,q in ipairs(b) do local ax,az=p.X-q.X,p.Z-q.Z; if ax*ax+az*az<MIN2 then return true end end end end end; return false end
	local pf=plot:FindFirstChild("Plants"); if pf then for _,pl in ipairs(pf:GetChildren()) do local ok2,cf2=pcall(function() return pl:GetPivot() end); local p2=ok2 and cf2.Position or (pl:IsA("BasePart") and pl.Position); if p2 then addPt(p2) end end end
	for _,pa in ipairs(CollectionService:GetTagged("PlantArea")) do
		if pa:IsA("BasePart") and pa.Size.Y<1 and pa:IsDescendantOf(plot) then
			local sx,sz=pa.Size.X,pa.Size.Z; local lx=-sx/2+gap/2
			while lx<sx/2 do local lz=-sz/2+gap/2; while lz<sz/2 do local world=(pa.CFrame*CFrame.new(lx,pa.Size.Y/2+0.05,lz)).Position; if not tooClose(world) then addPt(world); slots[#slots+1]=world end; lz=lz+gap end; lx=lx+gap end
		end
	end
	return slots
end
task.spawn(function()
	while ALIVE do
		if F.plant and Net then
			pcall(function()
				if PLANT.stopUnder>0 and totalSeedsInBag()<PLANT.stopUnder then return end
				if PLANT.stopMoneyOver>0 and getPlayerMoney()>PLANT.stopMoneyOver then return end
				local tools={}
				local function scan(c) if c then for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("SeedTool")~=nil and plantSeedSel[t:GetAttribute("SeedTool")] then tools[#tools+1]=t end end end end
				scan(LP:FindFirstChildOfClass("Backpack")); scan(LP.Character)
				if #tools==0 then return end
				local slots=generateSlots(); if #slots==0 then return end
				local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); local si=1
				for _,tool in ipairs(tools) do
					if not F.plant or si>#slots then break end
					local sn=tool:GetAttribute("SeedTool"); local count=tool:GetAttribute("Count") or 1
					if hum then pcall(function() hum:EquipTool(tool) end) end
					for _=1,count do
						if not F.plant or si>#slots or not tool.Parent then break end
						if PLANT.stopUnder>0 and totalSeedsInBag()<PLANT.stopUnder then return end
						if PLANT.stopMoneyOver>0 and getPlayerMoney()>PLANT.stopMoneyOver then return end
						pcall(function() Net.Plant.PlantSeed:Fire(slots[si], sn, tool) end); si=si+1; task.wait(0.07)
					end
				end
			end)
		end
		task.wait(0.6)
	end
end)

-- BUY SEEDS
task.spawn(function()
	while ALIVE do
		if F.buySeeds and Net and getPlayerMoney()>=SHOP.moneyFloor then
			pcall(function()
				local f=stockFolder("SeedShop"); if not f then return end
				for _,v in ipairs(f:GetChildren()) do
					if not F.buySeeds then break end
					if v:IsA("ValueBase") and v.Value>0 and seedSel[v.Name] then
						local need=math.max(0,(SHOP.maxSeeds>0 and SHOP.maxSeeds or math.huge)-countSeed(v.Name))
						for _=1,math.min(v.Value,need,50) do
							if not F.buySeeds or getPlayerMoney()<SHOP.moneyFloor then break end
							pcall(function() Net.SeedShop.PurchaseSeed:Fire(v.Name) end); task.wait(0.06)
						end
					end
				end
			end)
		end
		task.wait(1.5)
	end
end)

-- BUY GEARS
task.spawn(function()
	while ALIVE do
		if F.buyGears and Net then
			pcall(function()
				local f=stockFolder("GearShop"); if not f then return end
				for _,v in ipairs(f:GetChildren()) do
					if v:IsA("ValueBase") and v.Value>0 and gearSel[v.Name] then
						for _=1,math.min(v.Value,50) do pcall(function() Net.GearShop.PurchaseGear:Fire(v.Name) end); task.wait(0.06) end
					end
				end
			end)
		end
		task.wait(1.5)
	end
end)

-- BUY PET
local RRANK={Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6,Mythical=6,Godly=7,Divine=8,Secret=9,Prismatic=10}
task.spawn(function()
	while ALIVE do
		if F.buyPets and Net then
			pcall(function()
				local map=workspace:FindFirstChild("Map"); local rf=map and map:FindFirstChild("WildPetRef"); if not rf then return end
				local best,br; for _,ref in ipairs(rf:GetChildren()) do if ref:IsA("BasePart") and (ref:GetAttribute("OwnerUserId") or 0)==0 then local r=ref:GetAttribute("Rarity"); local rank=(r and RRANK[r]) or 0; if not best or rank>br then best,br=ref,rank end end end
				local hrp=getHRP(); if not best or not hrp then return end
				acquire(); local saved=hrp.CFrame; local t0=os.clock()
				while F.buyPets and best.Parent and (best:GetAttribute("OwnerUserId") or 0)==0 and os.clock()-t0<60 do
					local h2=getHRP(); if h2 then h2.CFrame=CFrame.new(best.Position+Vector3.new(0,3,2)) end
					pcall(function() Net.Pets.WildPetTame:Fire(best) end); task.wait(0.1)
				end
				local hb=getHRP(); if hb then hb.CFrame=saved end; release()
			end)
		end
		task.wait(0.5)
	end
end)

-- EVENT SEEDS
task.spawn(function()
	while ALIVE do
		if F.eventSeeds and Net then
			pcall(function()
				local map=workspace:FindFirstChild("Map"); local locs=map and map:FindFirstChild("SeedPackSpawnServerLocations"); if not locs or #locs:GetChildren()==0 then return end
				local hrp=getHRP(); if not hrp then return end
				acquire(); local saved=hrp.CFrame
				for _,m in ipairs(locs:GetChildren()) do
					if not F.eventSeeds then break end
					local cf=m:IsA("BasePart") and m.CFrame or (m:IsA("Model") and pcall(function() return m:GetPivot() end) and m:GetPivot())
					if cf then hrp.CFrame=cf+Vector3.new(0,3,0); task.wait(0.25) end
				end
				local h2=getHRP(); if h2 then h2.CFrame=saved end; release()
			end)
		end
		task.wait(1)
	end
end)

-- STEAL
task.spawn(function()
	while ALIVE do
		if F.steal and Net and StealFlags and isNight() then
			pcall(function()
				local hrp=getHRP(); if not hrp then return end
				acquire(); local saved=hrp.CFrame; local list={}
				for _,prompt in ipairs(CollectionService:GetTagged("StealPrompt")) do
					if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt:IsDescendantOf(workspace) then
						local m=prompt.Parent:FindFirstAncestorWhichIsA("Model"); if not m then continue end
						local uid=tonumber(m:GetAttribute("UserId")); local pid=m:GetAttribute("PlantId"); local seed=m:GetAttribute("SeedName") or m:GetAttribute("CorePartName")
						if uid and uid~=LP.UserId and pid and StealFlags.IsPlantStealable(seed) then list[#list+1]={m=m,pr=prompt,uid=uid,pid=pid,fid=m:GetAttribute("FruitId"),seed=seed,v=F.prioSteal and valueOf(m) or 0} end
					end
				end
				if F.prioSteal then table.sort(list,function(a,b) return a.v>b.v end) end
				for _,e in ipairs(list) do
					if not (F.steal and isNight()) then break end
					if e.m and e.m.Parent then
						local hold=e.pr.HoldDuration; if (hold==nil or hold==0) then hold=StealFlags.GetStealHoldDuration(e.seed) end
						local h2=getHRP(); if h2 then h2.CFrame=e.m:GetPivot()*CFrame.new(0,3,0) end
						pcall(function() Net.Steal.BeginSteal:Fire(e.uid,e.pid,e.fid or "") end)
						if hold and hold>0 then task.wait(hold+0.15) end
						pcall(function() Net.Steal.CompleteSteal:Fire() end); task.wait(0.1)
					end
				end
				local hb=getHRP(); if hb then hb.CFrame=saved end; release()
			end)
		end
		task.wait(F.steal and 0.5 or 1)
	end
end)

-- ANTI-STEAL
local function findShovel() local function sc(c) if c then for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("Shovel")~=nil then return t end end end end; return sc(LP.Character) or sc(LP:FindFirstChildOfClass("Backpack")) end
local function findIntruders() local pid=LP:GetAttribute("PlotId"); if not pid then return {} end; local gzd=ReplicatedStorage:FindFirstChild("GardenZoneData"); if not gzd then return {} end; local out={}; for _,p in ipairs(Players:GetPlayers()) do if p~=LP then local v=gzd:FindFirstChild(p.Name); local ch=p.Character; if v and v.Value==pid and ch and ch:FindFirstChild("HumanoidRootPart") then out[#out+1]=p end end end; return out end
task.spawn(function()
	while ALIVE do
		if F.antiSteal and Net and isNight() then
			pcall(function()
				local intruders=findIntruders(); local shovel=findShovel(); local hrp=getHRP()
				if #intruders==0 or not shovel or not hrp then return end
				acquire(); local saved=hrp.CFrame
				local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
				if hum then pcall(function() hum:EquipTool(shovel) end) end
				for _,p in ipairs(intruders) do
					if not (F.antiSteal and isNight()) then break end
					local ch=p.Character; local tHRP=ch and ch:FindFirstChild("HumanoidRootPart"); if not tHRP then continue end
					local tp=tHRP.Position; local h2=getHRP()
					if h2 then h2.CFrame=CFrame.new(tp+Vector3.new(0,0,1),tp) end
					task.wait(0.05); pcall(function() Net.Shovel.SwingShovel:Fire() end); pcall(function() Net.Shovel.HitPlayer:Fire(p.UserId) end); task.wait(0.66)
				end
				local hb=getHRP(); if hb then hb.CFrame=saved end; release()
			end)
		end
		task.wait(F.antiSteal and 0.15 or 1)
	end
end)

-- SCANNER
local scanTarget=nil; local scanHL={}
local function clearHL() for _,h in ipairs(scanHL) do pcall(function() if h.box and h.box.Parent then h.box:Destroy() end; if h.bb and h.bb.Parent then h.bb:Destroy() end end) end; table.clear(scanHL) end
local function doScan()
	clearHL(); if not scanTarget then return 0 end
	local uid=scanTarget.UserId; local cands={}
	local function walk(f) for _,o in ipairs(f:GetChildren()) do if o:IsA("Model") then local u=tonumber(o:GetAttribute("UserId")); if u==uid and o:GetAttribute("PlantId") then cands[#cands+1]={m=o,v=valueOf(o)} end; walk(o) elseif o:IsA("Folder") then walk(o) end end end
	walk(workspace)
	if #cands==0 then return 0 end
	table.sort(cands,function(a,b) return a.v>b.v end)
	for i=1,math.min(5,#cands) do
		local e=cands[i]; local m=e.m
		local box=Instance.new("SelectionBox"); box.Adornee=m; box.Color3=Color3.fromRGB(255,220,0); box.LineThickness=0.07; box.SurfaceTransparency=0.55; box.SurfaceColor3=Color3.fromRGB(255,240,80); box.Parent=workspace
		local bb=Instance.new("BillboardGui"); bb.Adornee=m; bb.Size=UDim2.fromOffset(130,42); bb.StudsOffset=Vector3.new(0,5,0); bb.AlwaysOnTop=true; bb.Parent=workspace
		local bg=Instance.new("Frame"); bg.Size=UDim2.fromScale(1,1); bg.BackgroundColor3=Color3.fromRGB(12,11,18); bg.BackgroundTransparency=0.18; bg.BorderSizePixel=0; bg.Parent=bb; local cr=Instance.new("UICorner"); cr.CornerRadius=UDim.new(0,7); cr.Parent=bg
		local vt=Instance.new("TextLabel"); vt.Size=UDim2.new(1,0,0.55,0); vt.BackgroundTransparency=1; vt.Text="💰 "..formatVal(e.v); vt.TextColor3=Color3.fromRGB(255,220,50); vt.Font=Enum.Font.GothamBold; vt.TextSize=15; vt.Parent=bg
		local rt=Instance.new("TextLabel"); rt.Size=UDim2.new(1,0,0.45,0); rt.Position=UDim2.fromScale(0,0.55); rt.BackgroundTransparency=1; rt.Text="#"..i; rt.TextColor3=Color3.fromRGB(170,170,200); rt.Font=Enum.Font.GothamMedium; rt.TextSize=10; rt.Parent=bg
		scanHL[#scanHL+1]={box=box,bb=bb}
	end
	return #cands
end
task.spawn(function() while ALIVE do if F.autoScan and scanTarget then doScan() end; task.wait(3) end end)

-- PLANT ZONE
-- ======= PLANT ZONE — CUSTOM HANDLES (PC + MOBILE) =======
--[[
	Uses plain Neon Parts as handle orbs. Drag is detected through
	UserInputService so it works identically with touch and mouse.
	
	Move  (blue)   : drag the +X / -X / +Z / -Z orbs to slide the zone
	Scale (orange) : drag the same faces to grow/shrink that dimension
	Rotate (purple): drag left/right anywhere on the zone body to spin it
	
	The approach:
	  1. Each orb's position is updated every frame while it exists.
	  2. On touch/click-begin we raycast from screen to find which orb
	     (or the zone body for Rotate) was hit.
	  3. On move we project the cursor onto the appropriate world plane
	     and compute the delta from drag-start.
]]

local cam = workspace.CurrentCamera

-- Project a screen position onto a horizontal plane at worldY
local function screenRayToPlaneY(screenPos, worldY)
	local unitRay = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local dY = unitRay.Direction.Y
	if math.abs(dY) < 1e-4 then return nil end
	local t = (worldY - unitRay.Origin.Y) / dY
	if t < 0 then return nil end
	return unitRay.Origin + unitRay.Direction * t
end

-- Raycast from screen against a specific part
local function screenHitsPart(screenPos, part)
	local unitRay = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {part}
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
	return result ~= nil
end

local zoneGhost   = nil   -- the purple zone Part
local zoneHandles = {}    -- {part, axis, dir}  — the orb Parts
local zoneActive  = false
local zoneMode    = "Move"

-- Drag state
local dragInfo = nil  -- set when a drag begins

local function updateHandlePositions()
	if not zoneGhost then return end
	local cf  = zoneGhost.CFrame
	local szX = zoneGhost.Size.X / 2 + 1.8
	local szZ = zoneGhost.Size.Z / 2 + 1.8
	for _, h in ipairs(zoneHandles) do
		if h.part and h.part.Parent then
			local offset
			if     h.axis == "x" and h.dir ==  1 then offset = cf.RightVector  * szX
			elseif h.axis == "x" and h.dir == -1 then offset = -cf.RightVector * szX
			elseif h.axis == "z" and h.dir ==  1 then offset = cf.LookVector   * szZ
			elseif h.axis == "z" and h.dir == -1 then offset = -cf.LookVector  * szZ
			end
			if offset then
				h.part.CFrame = CFrame.new(zoneGhost.Position + offset)
			end
		end
	end
end

local function destroyHandles()
	for _, h in ipairs(zoneHandles) do
		if h.part and h.part.Parent then h.part:Destroy() end
		if h.shaft and h.shaft.Parent then h.shaft:Destroy() end
	end
	table.clear(zoneHandles)
end

local function buildHandles()
	destroyHandles()
	if not zoneGhost then return end

	local modeColors = {
		Move   = Color3.fromRGB(80,  160, 255),
		Scale  = Color3.fromRGB(255, 140,  40),
		Rotate = Color3.fromRGB(200,  80, 255),
	}
	local col = modeColors[zoneMode]

	-- For Move and Scale: 4 axis orbs.  For Rotate: 2 rotation-hint orbs.
	local axes
	if zoneMode == "Rotate" then
		axes = {
			{axis="x", dir= 1},
			{axis="x", dir=-1},
		}
	else
		axes = {
			{axis="x", dir= 1},
			{axis="x", dir=-1},
			{axis="z", dir= 1},
			{axis="z", dir=-1},
		}
	end

	local cf  = zoneGhost.CFrame
	local szX = zoneGhost.Size.X / 2 + 1.8
	local szZ = zoneGhost.Size.Z / 2 + 1.8

	for _, ax in ipairs(axes) do
		-- Orb
		local orb = Instance.new("Part")
		orb.Shape    = Enum.PartType.Ball
		orb.Size     = Vector3.new(1.4, 1.4, 1.4)
		orb.Material = Enum.Material.Neon
		orb.Color    = col
		orb.Anchored    = true
		orb.CanCollide  = false
		orb.CastShadow  = false
		orb.Parent = workspace

		-- Label billboard
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(28, 18)
		bb.StudsOffset = Vector3.new(0, 1.2, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = orb
		bb.Parent = workspace
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.fromScale(1,1)
		lbl.TextColor3 = Color3.new(1,1,1)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 12
		lbl.Text = zoneMode == "Move" and "✥"
			or (zoneMode == "Scale" and (ax.axis=="x" and "↔" or "↕"))
			or "↻"
		lbl.Parent = bb

		table.insert(zoneHandles, {part=orb, axis=ax.axis, dir=ax.dir, bb=bb})
	end

	updateHandlePositions()
end

-- Every frame: keep handle orbs glued to zone edges
RunService.RenderStepped:Connect(function()
	if zoneActive and zoneGhost then updateHandlePositions() end

	if not dragInfo then return end
	local ip = dragInfo.latestInput
	if not ip then return end

	if dragInfo.type == "handle" then
		local h = dragInfo.handle
		local planeY = dragInfo.planeY
		local worldNow = screenRayToPlaneY(ip, planeY)
		if not worldNow then return end
		local delta = worldNow - dragInfo.worldStart

		if zoneMode == "Move" then
			if h.axis == "x" then
				local right = dragInfo.startCF.RightVector
				local proj  = delta:Dot(right)
				zoneGhost.CFrame = CFrame.new(dragInfo.startCF.Position + right * proj)
					* CFrame.Angles(0, math.rad(PLANT.zoneAngle), 0)
			elseif h.axis == "z" then
				local look = dragInfo.startCF.LookVector
				local proj  = delta:Dot(look)
				zoneGhost.CFrame = CFrame.new(dragInfo.startCF.Position + look * proj)
					* CFrame.Angles(0, math.rad(PLANT.zoneAngle), 0)
			end
			PLANT.zone = zoneGhost.CFrame

		elseif zoneMode == "Scale" then
			if h.axis == "x" then
				local right = dragInfo.startCF.RightVector
				local proj  = delta:Dot(right) * h.dir
				local nX = math.max(2, dragInfo.startSz.X + proj * 2)
				PLANT.zoneSize = Vector3.new(nX, 0.1, PLANT.zoneSize.Z)
				zoneGhost.Size = Vector3.new(nX, 0.22, PLANT.zoneSize.Z)
			elseif h.axis == "z" then
				local look = dragInfo.startCF.LookVector
				local proj  = delta:Dot(look) * h.dir
				local nZ = math.max(2, dragInfo.startSz.Z + proj * 2)
				PLANT.zoneSize = Vector3.new(PLANT.zoneSize.X, 0.1, nZ)
				zoneGhost.Size = Vector3.new(PLANT.zoneSize.X, 0.22, nZ)
			end
			PLANT.zone = zoneGhost.CFrame
			ss("zoneX", PLANT.zoneSize.X); ss("zoneZ", PLANT.zoneSize.Z)
		end

	elseif dragInfo.type == "rotate" then
		-- Use screen-X delta to rotate
		local screenDX = ip.X - dragInfo.screenStart.X
		local newAngle = (dragInfo.startAngle + screenDX * 0.55) % 360
		PLANT.zoneAngle = newAngle
		zoneGhost.CFrame = CFrame.new(zoneGhost.Position)
			* CFrame.Angles(0, math.rad(newAngle), 0)
		PLANT.zone = zoneGhost.CFrame
		ss("zoneAngle", newAngle)
	end
end)

-- Input began: find what was hit and start a drag
local function onInputBegan(input)
	if not zoneActive or not zoneGhost then return end
	local isMouse  = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTouch  = input.UserInputType == Enum.UserInputType.Touch
	if not isMouse and not isTouch then return end

	local screenPos = Vector2.new(input.Position.X, input.Position.Y)
	local planeY    = zoneGhost.Position.Y

	-- Check each handle orb
	for _, h in ipairs(zoneHandles) do
		if h.part and h.part.Parent and screenHitsPart(screenPos, h.part) then
			local worldStart = screenRayToPlaneY(screenPos, planeY)
			if worldStart then
				dragInfo = {
					type        = "handle",
					handle      = h,
					planeY      = planeY,
					worldStart  = worldStart,
					startCF     = zoneGhost.CFrame,
					startSz     = zoneGhost.Size,
					latestInput = screenPos,
				}
			end
			return
		end
	end

	-- Check zone body (for rotate, or free-move the whole zone in Move mode)
	if screenHitsPart(screenPos, zoneGhost) then
		if zoneMode == "Rotate" then
			dragInfo = {
				type        = "rotate",
				screenStart = screenPos,
				startAngle  = PLANT.zoneAngle,
				latestInput = screenPos,
			}
		elseif zoneMode == "Move" then
			-- drag the whole body on the horizontal plane
			local worldStart = screenRayToPlaneY(screenPos, planeY)
			if worldStart then
				dragInfo = {
					type        = "handle",
					handle      = {axis="free", dir=1},
					planeY      = planeY,
					worldStart  = worldStart,
					startCF     = zoneGhost.CFrame,
					startSz     = zoneGhost.Size,
					latestInput = screenPos,
					freeMove    = true,
				}
			end
		end
	end
end

local function onInputChanged(input)
	if not dragInfo then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch then
		dragInfo.latestInput = Vector2.new(input.Position.X, input.Position.Y)
	end
end

local function onInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		if dragInfo and dragInfo.freeMove then
			-- commit free-move
			if zoneGhost then
				local planeY = dragInfo.planeY
				local worldNow = screenRayToPlaneY(dragInfo.latestInput, planeY)
				if worldNow then
					local delta = worldNow - dragInfo.worldStart
					zoneGhost.CFrame = CFrame.new(dragInfo.startCF.Position + delta)
						* CFrame.Angles(0, math.rad(PLANT.zoneAngle), 0)
					PLANT.zone = zoneGhost.CFrame
				end
			end
		end
		dragInfo = nil
	end
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	onInputBegan(input)
end)
UserInputService.InputChanged:Connect(onInputChanged)
UserInputService.InputEnded:Connect(onInputEnded)

local function destroyZone()
	destroyHandles()
	dragInfo = nil
	if zoneGhost and zoneGhost.Parent then zoneGhost:Destroy() end
	zoneGhost = nil; zoneActive = false
end

local function attachHandles()
	buildHandles()
end

local function createZone()
	destroyZone()
	local p = Instance.new("Part"); p.Name = "GAG2_PlantZone"
	p.Size = Vector3.new(PLANT.zoneSize.X, 0.22, PLANT.zoneSize.Z)
	p.Anchored = true; p.CanCollide = false; p.CastShadow = false
	p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(130,80,220); p.Transparency = 0.55
	local hrp = getHRP()
	if hrp then
		local gp = groundPointUnder(hrp.Position) or (hrp.Position - Vector3.new(0,3,0))
		p.CFrame = CFrame.new(gp + Vector3.new(0,0.15,0)) * CFrame.Angles(0, math.rad(PLANT.zoneAngle), 0)
	end
	p.Parent = workspace; zoneGhost = p; zoneActive = true
	PLANT.zone = p.CFrame
	buildHandles()
end

SELF.Destroy = function()
	ALIVE=false; destroyZone(); clearHL()
	local old=getParentGui():FindFirstChild("GAG2NightFall"); if old then old:Destroy() end
end

--========================== GUI ==========================--
local parent=getParentGui()
local old=parent:FindFirstChild("GAG2NightFall"); if old then old:Destroy() end

local SG=Instance.new("ScreenGui")
SG.Name="GAG2NightFall"; SG.ResetOnSpawn=false; SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; SG.IgnoreGuiInset=true; SG.Parent=parent

-- NF cube
local CSIZE=44
local cubeF=Instance.new("Frame"); cubeF.Size=UDim2.new(0,CSIZE,0,CSIZE); cubeF.Position=UDim2.new(0.5,-CSIZE/2,0,14); cubeF.BackgroundTransparency=1; cubeF.Parent=SG
local cubeB=Instance.new("TextButton"); cubeB.Size=UDim2.new(1,0,1,0); cubeB.BackgroundColor3=C.surface; cubeB.Text=""; cubeB.AutoButtonColor=false; cubeB.Parent=cubeF
local cubeC=mkCorner(cubeB,10); mkStroke(cubeB,C.accent,1.5)
local cubeI=Instance.new("TextLabel"); cubeI.Size=UDim2.new(1,0,1,0); cubeI.BackgroundTransparency=1; cubeI.Text="NF"; cubeI.TextColor3=C.accentHov; cubeI.TextSize=17; cubeI.Font=Enum.Font.GothamBold; cubeI.Parent=cubeB

-- Main window
local GW,GH=640,600
local main=Instance.new("Frame"); main.Name="MainWin"; main.Size=UDim2.fromOffset(GW,GH); main.Position=UDim2.new(0.5,-GW/2,0.5,-GH/2); main.BackgroundColor3=C.bg; main.BorderSizePixel=0; main.Active=true; main.Parent=SG
mkCorner(main,20); mkStroke(main,C.border,1)

-- Header
local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,52); hdr.BackgroundColor3=C.sidebar; hdr.BorderSizePixel=0; hdr.Parent=main; mkCorner(hdr,20)
local hf=Instance.new("Frame"); hf.Size=UDim2.new(1,0,0,20); hf.Position=UDim2.new(0,0,1,-20); hf.BackgroundColor3=C.sidebar; hf.BorderSizePixel=0; hf.Parent=hdr
local ha=Instance.new("Frame"); ha.Size=UDim2.new(1,0,0,3); ha.Position=UDim2.new(0,0,1,-3); ha.BackgroundColor3=C.accent; ha.BorderSizePixel=0; ha.Parent=hdr
local titleL=Instance.new("TextLabel"); titleL.Size=UDim2.new(1,-90,0,24); titleL.Position=UDim2.new(0,16,0,7); titleL.BackgroundTransparency=1; titleL.Text="NightFall"; titleL.TextColor3=C.txt; titleL.TextSize=20; titleL.Font=Enum.Font.GothamBold; titleL.TextXAlignment=Enum.TextXAlignment.Left; titleL.Parent=hdr
local subL=Instance.new("TextLabel"); subL.Size=UDim2.new(1,-90,0,14); subL.Position=UDim2.new(0,16,0,31); subL.BackgroundTransparency=1; subL.Text="Grow a Garden 2  •  v9  •  INSERT to toggle"; subL.TextColor3=C.sub; subL.TextSize=11; subL.Font=Enum.Font.GothamMedium; subL.TextXAlignment=Enum.TextXAlignment.Left; subL.Parent=hdr
local closeB=Instance.new("TextButton"); closeB.Size=UDim2.fromOffset(28,28); closeB.Position=UDim2.new(1,-38,0.5,-14); closeB.BackgroundColor3=C.elevated; closeB.Text="–"; closeB.TextColor3=C.sub; closeB.TextSize=16; closeB.Font=Enum.Font.GothamBold; closeB.AutoButtonColor=false; closeB.Parent=hdr; mkCorner(closeB,6)

local hubVis=true
local function setVis(v) hubVis=v; main.Visible=v end
closeB.MouseButton1Click:Connect(function() setVis(false) end)

-- Header drag
do
	local dr,ds,sp
	hdr.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dr=true; ds=i.Position; sp=main.Position end end)
	UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dr=false end end)
	UserInputService.InputChanged:Connect(function(i) if not dr then return end; if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then local d=i.Position-ds; main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
end
-- Cube click+drag
do
	local cd,cm=false,false; local cds,csp,msp
	cubeB.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then cd=true; cm=false; cds=i.Position; csp=cubeF.Position; msp=main.Position end end)
	UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then if cd and not cm then setVis(not hubVis) end; cd=false end end)
	UserInputService.InputChanged:Connect(function(i) if not cd then return end; if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then local d=i.Position-cds; if d.Magnitude>8 then cm=true end; if cm then cubeF.Position=UDim2.new(csp.X.Scale,csp.X.Offset+d.X,csp.Y.Scale,csp.Y.Offset+d.Y); main.Position=UDim2.new(msp.X.Scale,msp.X.Offset+d.X,msp.Y.Scale,msp.Y.Offset+d.Y) end end end)
end
UserInputService.InputBegan:Connect(function(i,gpe) if gpe then return end; if i.KeyCode==Enum.KeyCode.Insert then setVis(not hubVis) end end)

-- Sidebar + Content
local SW=130
local sidebar=Instance.new("Frame"); sidebar.Size=UDim2.new(0,SW,1,-68); sidebar.Position=UDim2.new(0,10,0,58); sidebar.BackgroundColor3=C.sidebar; sidebar.BorderSizePixel=0; sidebar.Parent=main; mkCorner(sidebar,20)
local navList=Instance.new("Frame"); navList.Size=UDim2.new(1,-12,1,-12); navList.Position=UDim2.new(0,6,0,6); navList.BackgroundTransparency=1; navList.Parent=sidebar
local navLL=Instance.new("UIListLayout"); navLL.Padding=UDim.new(0,5); navLL.Parent=navList
local content=Instance.new("Frame"); content.Size=UDim2.new(1,-(SW+20),1,-68); content.Position=UDim2.new(0,SW+10,0,58); content.BackgroundColor3=C.surface; content.ClipsDescendants=true; content.BorderSizePixel=0; content.Parent=main; mkCorner(content,20)

-- Tab system
local pages,tabBtns={},{}
local function mkTab(name,icon)
	local page=Instance.new("ScrollingFrame"); page.Size=UDim2.new(1,-12,1,-12); page.Position=UDim2.new(0,6,0,6); page.BackgroundTransparency=1; page.BorderSizePixel=0; page.ScrollBarThickness=4; page.ScrollBarImageColor3=C.border; page.AutomaticCanvasSize=Enum.AutomaticSize.Y; page.Visible=false; page.Parent=content
	local ll=Instance.new("UIListLayout"); ll.Padding=UDim.new(0,7); ll.Parent=page
	local p2=Instance.new("UIPadding"); p2.PaddingTop=UDim.new(0,4); p2.PaddingBottom=UDim.new(0,8); p2.Parent=page
	pages[name]=page
	local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,0,36); btn.BackgroundColor3=C.sidebar; btn.Text=""; btn.AutoButtonColor=false; btn.Parent=navList; mkCorner(btn,10)
	local ti=Instance.new("TextLabel"); ti.Size=UDim2.new(0,20,1,0); ti.Position=UDim2.new(0,8,0,0); ti.BackgroundTransparency=1; ti.Text=icon; ti.TextColor3=C.sub; ti.TextSize=13; ti.Font=Enum.Font.GothamBold; ti.Parent=btn
	local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(1,-30,1,0); tl.Position=UDim2.new(0,28,0,0); tl.BackgroundTransparency=1; tl.Text=name; tl.TextColor3=C.sub; tl.TextSize=#name>7 and 11 or 13; tl.Font=Enum.Font.GothamSemibold; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Parent=btn
	tabBtns[name]=btn
	btn.MouseButton1Click:Connect(function()
		for n,pg in pairs(pages) do pg.Visible=(n==name) end
		for n,b in pairs(tabBtns) do b.BackgroundColor3=(n==name) and Color3.fromRGB(28,30,48) or C.sidebar; for _,ch in ipairs(b:GetChildren()) do if ch:IsA("TextLabel") then ch.TextColor3=(n==name) and C.accent or C.sub end end end
	end)
	return page
end
local function switchTab(name)
	for n,pg in pairs(pages) do pg.Visible=(n==name) end
	for n,b in pairs(tabBtns) do b.BackgroundColor3=(n==name) and Color3.fromRGB(28,30,48) or C.sidebar; for _,ch in ipairs(b:GetChildren()) do if ch:IsA("TextLabel") then ch.TextColor3=(n==name) and C.accent or C.sub end end end
end

-- Widget helpers
local LO=0
local function ord() LO=LO+1; return LO end
local function secLbl(parent,txt)
	local w=Instance.new("Frame"); w.Size=UDim2.new(1,0,0,22); w.LayoutOrder=ord(); w.BackgroundTransparency=1; w.Parent=parent
	local line=Instance.new("Frame"); line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,0.5,0); line.BackgroundColor3=C.border; line.BorderSizePixel=0; line.Parent=w
	local lbl=Instance.new("TextLabel"); lbl.BackgroundColor3=C.surface; lbl.Size=UDim2.new(0,0,1,0); lbl.AutomaticSize=Enum.AutomaticSize.X; lbl.Text="  "..string.upper(txt).."  "; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=10; lbl.TextColor3=C.accent; lbl.ZIndex=3; lbl.Parent=w; mkPad(lbl,0)
end
local function tog(parent,label,key,onChange)
	local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,44); row.LayoutOrder=ord(); row.BackgroundColor3=C.surface; row.BorderSizePixel=0; row.Parent=parent; mkCorner(row,10); mkStroke(row,C.border,1)
	local lbl=Instance.new("TextLabel"); lbl.BackgroundTransparency=1; lbl.Position=UDim2.fromOffset(12,0); lbl.Size=UDim2.new(1,-66,1,0); lbl.Text=label; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=13; lbl.TextColor3=C.txt; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
	local pill=Instance.new("TextButton"); pill.AnchorPoint=Vector2.new(1,0.5); pill.Position=UDim2.new(1,-10,0.5,0); pill.Size=UDim2.fromOffset(46,24); pill.BackgroundColor3=C.off; pill.Text=""; pill.AutoButtonColor=false; pill.Parent=row; mkCorner(pill,12)
	local knob=Instance.new("Frame"); knob.Size=UDim2.fromOffset(18,18); knob.Position=UDim2.fromOffset(3,3); knob.BackgroundColor3=C.txt; knob.BorderSizePixel=0; knob.Parent=pill; mkCorner(knob,9)
	local function render() local on=F[key]; tw(pill,{BackgroundColor3=on and C.accent or C.off}); tw(knob,{Position=on and UDim2.fromOffset(25,3) or UDim2.fromOffset(3,3)}); lbl.TextColor3=on and C.txt or C.sub end
	pill.MouseButton1Click:Connect(function() F[key]=not F[key]; ss(key,F[key]); render(); if onChange then onChange(F[key]) end end)
	render()
end
local function btn(parent,label,btnTxt,cb)
	local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,44); row.LayoutOrder=ord(); row.BackgroundColor3=C.surface; row.BorderSizePixel=0; row.Parent=parent; mkCorner(row,10); mkStroke(row,C.border,1)
	local lbl=Instance.new("TextLabel"); lbl.BackgroundTransparency=1; lbl.Position=UDim2.fromOffset(12,0); lbl.Size=UDim2.new(1,-108,1,0); lbl.Text=label; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=13; lbl.TextColor3=C.txt; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
	local b=Instance.new("TextButton"); b.AnchorPoint=Vector2.new(1,0.5); b.Position=UDim2.new(1,-8,0.5,0); b.Size=UDim2.fromOffset(92,28); b.BackgroundColor3=C.accent; b.Text=btnTxt; b.Font=Enum.Font.GothamBold; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.AutoButtonColor=false; b.Parent=row; mkCorner(b,6)
	b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=C.accentHov}) end); b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=C.accent}) end)
	b.MouseButton1Click:Connect(function() cb(b) end); return b
end
local function sld(parent,label,mn,mx,init,step,cb)
	step=step or 1
	local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,62); row.LayoutOrder=ord(); row.BackgroundColor3=C.surface; row.BorderSizePixel=0; row.Parent=parent; mkCorner(row,10); mkStroke(row,C.border,1)
	local lbl=Instance.new("TextLabel"); lbl.BackgroundTransparency=1; lbl.Position=UDim2.fromOffset(12,8); lbl.Size=UDim2.new(1,-80,0,18); lbl.Text=label; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=12; lbl.TextColor3=C.txt; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
	local vl=Instance.new("TextLabel"); vl.BackgroundTransparency=1; vl.AnchorPoint=Vector2.new(1,0); vl.Position=UDim2.new(1,-12,0,8); vl.Size=UDim2.fromOffset(60,18); vl.Text=tostring(init); vl.Font=Enum.Font.GothamBold; vl.TextSize=13; vl.TextColor3=C.accent; vl.TextXAlignment=Enum.TextXAlignment.Right; vl.Parent=row
	local track=Instance.new("Frame"); track.Position=UDim2.new(0,12,0,38); track.Size=UDim2.new(1,-24,0,6); track.BackgroundColor3=C.elevated; track.BorderSizePixel=0; track.Parent=row; mkCorner(track,3)
	local fill=Instance.new("Frame"); fill.Size=UDim2.new((init-mn)/(mx-mn),0,1,0); fill.BackgroundColor3=C.accent; fill.BorderSizePixel=0; fill.Parent=track; mkCorner(fill,3)
	local knob=Instance.new("TextButton"); knob.Size=UDim2.fromOffset(16,16); knob.AnchorPoint=Vector2.new(0.5,0.5); knob.Position=UDim2.new((init-mn)/(mx-mn),0,0.5,0); knob.BackgroundColor3=C.txt; knob.Text=""; knob.AutoButtonColor=false; knob.ZIndex=3; knob.Parent=track; mkCorner(knob,8)
	local sliding=false
	local function setV(v) v=math.clamp(math.floor(v/step+0.5)*step,mn,mx); local pct=(v-mn)/(mx-mn); fill.Size=UDim2.new(pct,0,1,0); knob.Position=UDim2.new(pct,0,0.5,0); vl.Text=tostring(v); cb(v) end
	local function fromI(i) local ap=track.AbsolutePosition; local as=track.AbsoluteSize; setV(mn+(mx-mn)*math.clamp((i.Position.X-ap.X)/as.X,0,1)) end
	knob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=true end end)
	track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=true; fromI(i) end end)
	UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=false end end)
	UserInputService.InputChanged:Connect(function(i) if not sliding then return end; if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then fromI(i) end end)
end
local function numIn(parent,label,init,cb)
	local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,44); row.LayoutOrder=ord(); row.BackgroundColor3=C.surface; row.BorderSizePixel=0; row.Parent=parent; mkCorner(row,10); mkStroke(row,C.border,1)
	local lbl=Instance.new("TextLabel"); lbl.BackgroundTransparency=1; lbl.Position=UDim2.fromOffset(12,0); lbl.Size=UDim2.new(1,-100,1,0); lbl.Text=label; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=12; lbl.TextColor3=C.txt; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
	local box=Instance.new("TextBox"); box.AnchorPoint=Vector2.new(1,0.5); box.Position=UDim2.new(1,-8,0.5,0); box.Size=UDim2.fromOffset(86,26); box.BackgroundColor3=C.elevated; box.Text=tostring(init); box.TextColor3=C.accent; box.Font=Enum.Font.GothamBold; box.TextSize=13; box.ClearTextOnFocus=false; box.Parent=row; mkCorner(box,6); mkStroke(box,C.border,1)
	box.FocusLost:Connect(function() local n=tonumber(box.Text:gsub("[^%d%.]+","")); if n then cb(n); box.Text=tostring(n) else box.Text=tostring(init) end end)
end
local function chklist(parent,data,store,header,onSave)
	local box=Instance.new("Frame"); box.Size=UDim2.new(1,0,0,185); box.LayoutOrder=ord(); box.BackgroundColor3=C.sidebar; box.BorderSizePixel=0; box.Parent=parent; mkCorner(box,10); mkStroke(box,C.border,1)
	local h=Instance.new("Frame"); h.Size=UDim2.new(1,0,0,30); h.BackgroundColor3=C.surface; h.BorderSizePixel=0; h.Parent=box; mkCorner(h,10)
	local hf2=Instance.new("Frame"); hf2.Size=UDim2.new(1,0,0,8); hf2.Position=UDim2.new(0,0,1,-8); hf2.BackgroundColor3=C.surface; hf2.BorderSizePixel=0; hf2.Parent=h
	local hl=Instance.new("TextLabel"); hl.BackgroundTransparency=1; hl.Position=UDim2.fromOffset(10,0); hl.Size=UDim2.new(1,-110,1,0); hl.Text=header or "Select"; hl.Font=Enum.Font.GothamMedium; hl.TextSize=12; hl.TextColor3=C.sub; hl.TextXAlignment=Enum.TextXAlignment.Left; hl.Parent=h
	local function mB(txt,xOff,col) local b=Instance.new("TextButton"); b.AnchorPoint=Vector2.new(1,0.5); b.Position=UDim2.new(1,xOff,0.5,0); b.Size=UDim2.fromOffset(44,20); b.BackgroundColor3=col or C.elevated; b.Text=txt; b.Font=Enum.Font.GothamBold; b.TextSize=11; b.TextColor3=(col and Color3.new(1,1,1)) or C.txt; b.ZIndex=4; b.Parent=h; mkCorner(b,6); mkStroke(b,col or C.border,1); return b end
	local sc=Instance.new("ScrollingFrame"); sc.Position=UDim2.fromOffset(0,30); sc.Size=UDim2.new(1,0,1,-30); sc.BackgroundTransparency=1; sc.BorderSizePixel=0; sc.ScrollBarThickness=3; sc.ScrollBarImageColor3=C.accent; sc.CanvasSize=UDim2.new(); sc.Parent=box
	local ll=Instance.new("UIListLayout"); ll.Padding=UDim.new(0,2); ll.Parent=sc
	ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sc.CanvasSize=UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+8) end)
	mkPad(sc,4,5,4,5)
	local paints={}
	for _,sd in ipairs(data) do
		local name=sd.name; local rc=C[sd.rarity] or C.Common
		local row=Instance.new("TextButton"); row.Size=UDim2.new(1,-10,0,30); row.BackgroundColor3=C.surface; row.AutoButtonColor=false; row.Text=""; row.ZIndex=4; row.Parent=sc; mkCorner(row,6)
		local bar=Instance.new("Frame"); bar.Size=UDim2.fromOffset(3,20); bar.Position=UDim2.fromOffset(6,5); bar.BackgroundColor3=rc; bar.BorderSizePixel=0; bar.ZIndex=5; bar.Parent=row; mkCorner(bar,2)
		local nm=Instance.new("TextLabel"); nm.BackgroundTransparency=1; nm.Position=UDim2.fromOffset(14,0); nm.Size=UDim2.new(1,-90,1,0); nm.Text=name; nm.Font=Enum.Font.GothamMedium; nm.TextSize=12; nm.TextColor3=C.txt; nm.TextXAlignment=Enum.TextXAlignment.Left; nm.ZIndex=5; nm.Parent=row
		local tag=Instance.new("TextLabel"); tag.AnchorPoint=Vector2.new(1,0.5); tag.Position=UDim2.new(1,-30,0.5,0); tag.Size=UDim2.fromOffset(56,15); tag.BackgroundColor3=rc; tag.BackgroundTransparency=0.72; tag.Text=sd.rarity; tag.Font=Enum.Font.GothamBold; tag.TextSize=9; tag.TextColor3=rc; tag.ZIndex=5; tag.Parent=row; mkCorner(tag,4)
		local cb2=Instance.new("Frame"); cb2.AnchorPoint=Vector2.new(1,0.5); cb2.Position=UDim2.new(1,-8,0.5,0); cb2.Size=UDim2.fromOffset(16,16); cb2.BackgroundColor3=store[name] and C.success or C.off; cb2.BorderSizePixel=0; cb2.ZIndex=5; cb2.Parent=row; mkCorner(cb2,4)
		local chk=Instance.new("TextLabel"); chk.BackgroundTransparency=1; chk.Size=UDim2.fromScale(1,1); chk.Text="✓"; chk.Font=Enum.Font.GothamBold; chk.TextSize=11; chk.TextColor3=Color3.new(1,1,1); chk.Visible=store[name]; chk.ZIndex=6; chk.Parent=cb2
		local function paint() local on=store[name]; tw(cb2,{BackgroundColor3=on and C.success or C.off}); chk.Visible=on; row.BackgroundColor3=on and C.surfaceHov or C.surface; if onSave then onSave() end end
		paints[name]=paint; row.MouseButton1Click:Connect(function() store[name]=not store[name]; paint() end)
	end
	mB("All",-6,C.accent).MouseButton1Click:Connect(function() for _,sd in ipairs(data) do store[sd.name]=true; if paints[sd.name] then paints[sd.name]() end end; if onSave then onSave() end end)
	mB("None",-54).MouseButton1Click:Connect(function() for _,sd in ipairs(data) do store[sd.name]=false; if paints[sd.name] then paints[sd.name]() end end; if onSave then onSave() end end)
end

-- FARM
local farmP=mkTab("Farm","🌾")
secLbl(farmP,"Harvest"); tog(farmP,"Auto Harvest  (instant)","harvest"); tog(farmP,"Harvest highest value first","prioHarvest")
secLbl(farmP,"Economy"); tog(farmP,"Auto Sell Inventory","sell")
secLbl(farmP,"Night & Events"); tog(farmP,"Auto Steal  (night only)","steal"); tog(farmP,"Steal highest value first","prioSteal"); tog(farmP,"Anti-Steal  (hit intruders)","antiSteal"); tog(farmP,"Auto Collect Event Seeds","eventSeeds")

-- PLANT
local plantP=mkTab("Plant","🌱")
secLbl(plantP,"Plant Zone")
local instrF=Instance.new("Frame"); instrF.Size=UDim2.new(1,0,0,68); instrF.LayoutOrder=ord(); instrF.BackgroundColor3=Color3.fromRGB(22,18,44); instrF.BorderSizePixel=0; instrF.Parent=plantP; mkCorner(instrF,10); mkStroke(instrF,C.accent,1); mkPad(instrF,10,12)
local instrT=Instance.new("TextLabel"); instrT.BackgroundTransparency=1; instrT.Size=UDim2.fromScale(1,1); instrT.Text="1. Show plant zone — purple area appears at your feet.\n2. Pick Move / Scale / Rotate and drag the coloured handles.\n3. Save Zone then enable Auto Plant."; instrT.Font=Enum.Font.Gotham; instrT.TextSize=11; instrT.TextColor3=C.sub; instrT.TextWrapped=true; instrT.TextXAlignment=Enum.TextXAlignment.Left; instrT.TextYAlignment=Enum.TextYAlignment.Top; instrT.Parent=instrF

local zoneBtnRef=btn(plantP,"Plant zone","Show Zone",function(b)
	if zoneActive then destroyZone(); b.Text="Show Zone"; b.BackgroundColor3=C.accent
	else createZone(); b.Text="Hide Zone"; b.BackgroundColor3=C.danger end
end)

secLbl(plantP,"Mode")
do
	local mRow=Instance.new("Frame"); mRow.Size=UDim2.new(1,0,0,36); mRow.LayoutOrder=ord(); mRow.BackgroundColor3=C.surface; mRow.BorderSizePixel=0; mRow.Parent=plantP; mkCorner(mRow,10)
	local modes={"Move","Scale","Rotate"}; local mCols={Move=Color3.fromRGB(80,160,255),Scale=Color3.fromRGB(255,140,40),Rotate=Color3.fromRGB(200,80,255)}; local mBtns={}
	for i,m in ipairs(modes) do
		local b=Instance.new("TextButton"); b.Size=UDim2.new(1/3,i<3 and -2 or 0,1,-6); b.Position=UDim2.new((i-1)/3,i>1 and 2 or 0,0,3); b.BackgroundColor3=(m==zoneMode) and mCols[m] or C.elevated; b.Text=m; b.Font=Enum.Font.GothamBold; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.AutoButtonColor=false; b.Parent=mRow; mkCorner(b,6); mBtns[m]=b
		b.MouseButton1Click:Connect(function() zoneMode=m; for _,mb in pairs(mBtns) do tw(mb,{BackgroundColor3=C.elevated}) end; tw(b,{BackgroundColor3=mCols[m]}); if zoneActive then attachHandles() end end)
	end
end

secLbl(plantP,"Seed Selection"); chklist(plantP,SEEDS,plantSeedSel,"Seeds to plant",function() ss("plantSeedSel",plantSeedSel) end)
secLbl(plantP,"Stop Conditions")
numIn(plantP,"Stop when total seeds < (0=off)", PLANT.stopUnder, function(v) PLANT.stopUnder=v; ss("plantStopUnder",v) end)
numIn(plantP,"Stop when money > (0=off)", PLANT.stopMoneyOver, function(v) PLANT.stopMoneyOver=v; ss("plantStopMoneyOver",v) end)
secLbl(plantP,"Controls")
btn(plantP,"Save zone (lock position)","Save Zone",function(b)
	if zoneGhost then PLANT.zone=zoneGhost.CFrame; b.Text="Saved ✓"; task.delay(1.3,function() if b and b.Parent then b.Text="Save Zone" end end) end
end)
tog(plantP,"Auto Plant Seeds","plant")

-- SHOP
local shopP=mkTab("Shop","🛒")
secLbl(shopP,"Seed Buying"); tog(shopP,"Auto Buy Seeds","buySeeds")
secLbl(shopP,"Buy Limits")
numIn(shopP,"Max seeds per type (0=unlimited)", SHOP.maxSeeds, function(v) SHOP.maxSeeds=math.max(0,v); ss("maxSeeds",SHOP.maxSeeds) end)
numIn(shopP,"Stop buying if money below", SHOP.moneyFloor, function(v) SHOP.moneyFloor=math.max(0,v); ss("moneyFloor",SHOP.moneyFloor) end)
secLbl(shopP,"Seed Selection"); chklist(shopP,SEEDS,seedSel,"Seeds to auto-buy",function() ss("seedSel",seedSel) end)
secLbl(shopP,"Gear Buying"); tog(shopP,"Auto Buy Gears","buyGears")
chklist(shopP,GEARS,gearSel,"Gears to auto-buy",function() ss("gearSel",gearSel) end)
secLbl(shopP,"Pets"); tog(shopP,"Auto Buy Best Wild Pet","buyPets")

-- SCANNER
local scanP=mkTab("Scanner","🔍")
secLbl(scanP,"Select Player")
local plBox=Instance.new("Frame"); plBox.Size=UDim2.new(1,0,0,155); plBox.LayoutOrder=ord(); plBox.BackgroundColor3=C.sidebar; plBox.BorderSizePixel=0; plBox.Parent=scanP; mkCorner(plBox,10); mkStroke(plBox,C.border,1)
local plH=Instance.new("Frame"); plH.Size=UDim2.new(1,0,0,28); plH.BackgroundColor3=C.surface; plH.BorderSizePixel=0; plH.Parent=plBox; mkCorner(plH,10)
local plHF=Instance.new("Frame"); plHF.Size=UDim2.new(1,0,0,8); plHF.Position=UDim2.new(0,0,1,-8); plHF.BackgroundColor3=C.surface; plHF.BorderSizePixel=0; plHF.Parent=plH
local plHL2=Instance.new("TextLabel"); plHL2.BackgroundTransparency=1; plHL2.Position=UDim2.fromOffset(10,0); plHL2.Size=UDim2.new(1,0,1,0); plHL2.Text="Click a player to target their plot"; plHL2.Font=Enum.Font.GothamMedium; plHL2.TextSize=11; plHL2.TextColor3=C.sub; plHL2.TextXAlignment=Enum.TextXAlignment.Left; plHL2.Parent=plH
local plSc=Instance.new("ScrollingFrame"); plSc.Position=UDim2.fromOffset(0,28); plSc.Size=UDim2.new(1,0,1,-28); plSc.BackgroundTransparency=1; plSc.BorderSizePixel=0; plSc.ScrollBarThickness=3; plSc.ScrollBarImageColor3=C.accent; plSc.CanvasSize=UDim2.new(); plSc.Parent=plBox
local plLL2=Instance.new("UIListLayout"); plLL2.Padding=UDim.new(0,2); plLL2.Parent=plSc
plLL2:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() plSc.CanvasSize=UDim2.new(0,0,0,plLL2.AbsoluteContentSize.Y+6) end)
mkPad(plSc,4,5,4,5)
local tgtLbl; local plRows={}
local function refreshPlayers()
	for _,v in ipairs(plSc:GetChildren()) do if v:IsA("TextButton") or v:IsA("TextLabel") then v:Destroy() end end; table.clear(plRows)
	local others={}; for _,p in ipairs(Players:GetPlayers()) do if p~=LP then others[#others+1]=p end end
	if #others==0 then local n=Instance.new("TextLabel"); n.Size=UDim2.new(1,-10,0,28); n.BackgroundTransparency=1; n.Text="No other players"; n.Font=Enum.Font.GothamMedium; n.TextSize=11; n.TextColor3=C.sub; n.TextXAlignment=Enum.TextXAlignment.Center; n.Parent=plSc end
	for _,p in ipairs(others) do
		local row=Instance.new("TextButton"); row.Size=UDim2.new(1,-10,0,30); row.BackgroundColor3=C.surface; row.AutoButtonColor=false; row.Text=""; row.ZIndex=4; row.Parent=plSc; mkCorner(row,6)
		local nm=Instance.new("TextLabel"); nm.BackgroundTransparency=1; nm.Position=UDim2.fromOffset(10,0); nm.Size=UDim2.new(1,-30,1,0); nm.Text="👤 "..p.Name; nm.Font=Enum.Font.GothamMedium; nm.TextSize=12; nm.TextColor3=C.txt; nm.TextXAlignment=Enum.TextXAlignment.Left; nm.ZIndex=5; nm.Parent=row
		local dot=Instance.new("Frame"); dot.AnchorPoint=Vector2.new(1,0.5); dot.Position=UDim2.new(1,-6,0.5,0); dot.Size=UDim2.fromOffset(8,8); dot.BackgroundColor3=C.border; dot.BorderSizePixel=0; dot.ZIndex=5; dot.Parent=row; mkCorner(dot,4)
		plRows[p.UserId]={row=row,dot=dot}
		row.MouseButton1Click:Connect(function()
			for _,r in pairs(plRows) do tw(r.dot,{BackgroundColor3=C.border}); r.row.BackgroundColor3=C.surface end
			scanTarget=p; tw(dot,{BackgroundColor3=C.accent}); row.BackgroundColor3=C.surfaceHov
			if tgtLbl then tgtLbl.Text="Target: "..p.Name end
		end)
	end
end
refreshPlayers(); Players.PlayerAdded:Connect(function() task.wait(0.1); refreshPlayers() end); Players.PlayerRemoving:Connect(function() task.wait(0.1); refreshPlayers() end)
local stCard=Instance.new("Frame"); stCard.Size=UDim2.new(1,0,0,50); stCard.LayoutOrder=ord(); stCard.BackgroundColor3=C.surface; stCard.BorderSizePixel=0; stCard.Parent=scanP; mkCorner(stCard,10); mkStroke(stCard,C.border,1); mkPad(stCard,8,12)
tgtLbl=Instance.new("TextLabel"); tgtLbl.BackgroundTransparency=1; tgtLbl.Size=UDim2.fromScale(1,0.5); tgtLbl.Text="Target: (none)"; tgtLbl.Font=Enum.Font.GothamMedium; tgtLbl.TextSize=12; tgtLbl.TextColor3=C.sub; tgtLbl.TextXAlignment=Enum.TextXAlignment.Left; tgtLbl.Parent=stCard
local resLbl=Instance.new("TextLabel"); resLbl.BackgroundTransparency=1; resLbl.Size=UDim2.fromScale(1,0.5); resLbl.Position=UDim2.fromScale(0,0.5); resLbl.Text="—"; resLbl.Font=Enum.Font.GothamBold; resLbl.TextSize=12; resLbl.TextColor3=C.accent; resLbl.TextXAlignment=Enum.TextXAlignment.Left; resLbl.Parent=stCard
secLbl(scanP,"Actions")
btn(scanP,"Scan plot & highlight fruits","Scan Now",function()
	if not scanTarget then resLbl.Text="⚠ Pick a player first!"; return end
	resLbl.Text="Scanning…"; task.wait(); local n=doScan(); resLbl.Text=n==0 and "No fruits found." or "✅ Top "..math.min(5,n).." of "..n
end)
btn(scanP,"Clear highlights","Clear",function() clearHL(); resLbl.Text="Cleared." end)
btn(scanP,"Refresh list","Refresh",function() refreshPlayers() end)
secLbl(scanP,"Live Mode"); tog(scanP,"Auto scan every 3s","autoScan")

-- SETTINGS
local settP=mkTab("Settings","⚙")
secLbl(settP,"Plant Spacing"); sld(settP,"Seed spacing (studs)",1,8,PLANT.spacing,0.5,function(v) PLANT.spacing=v; ss("plantSpacing",v) end)
secLbl(settP,"UI")
sld(settP,"Window width",400,900,GW,10,function(v) GW=v; main.Size=UDim2.fromOffset(GW,GH) end)
sld(settP,"Window height",360,700,GH,10,function(v) GH=v; main.Size=UDim2.fromOffset(GW,GH) end)
btn(settP,"Reset window size","Reset",function() GW,GH=640,600; main.Size=UDim2.fromOffset(GW,GH) end)
secLbl(settP,"Auto Execute")
local aeCard=Instance.new("Frame"); aeCard.Size=UDim2.new(1,0,0,58); aeCard.LayoutOrder=ord(); aeCard.BackgroundColor3=C.surface; aeCard.BorderSizePixel=0; aeCard.Parent=settP; mkCorner(aeCard,10); mkStroke(aeCard,C.border,1); mkPad(aeCard,10,12)
local aeT=Instance.new("TextLabel"); aeT.BackgroundTransparency=1; aeT.Size=UDim2.fromScale(1,1); aeT.Text="Settings are saved in _G.NFSettings — they persist when you re-execute in the same session. The Copy button puts a loadstring() in your clipboard for your executor auto-exec."; aeT.Font=Enum.Font.Gotham; aeT.TextSize=11; aeT.TextColor3=C.sub; aeT.TextWrapped=true; aeT.TextXAlignment=Enum.TextXAlignment.Left; aeT.TextYAlignment=Enum.TextYAlignment.Top; aeT.Parent=aeCard
local SCRIPT_URL="https://raw.githubusercontent.com/YOUR_REPO/main/GAG2_NightFall.lua"
btn(settP,"Copy auto-exec loader","Copy",function(b)
	local loader='loadstring(game:HttpGet("'..SCRIPT_URL..'",true))()'
	pcall(function() if setclipboard then setclipboard(loader) elseif toclipboard then toclipboard(loader) end end)
	print("[NightFall] Auto-exec:\n"..loader)
	b.Text="Copied ✓"; task.delay(2,function() if b and b.Parent then b.Text="Copy" end end)
end)

-- Init + open animation
switchTab("Farm")
main.Size=UDim2.fromOffset(0,0); main.BackgroundTransparency=1
TweenService:Create(main,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(GW,GH),BackgroundTransparency=0}):Play()
print("[GAG 2 NightFall v9] Loaded — click the NF cube or press INSERT")
