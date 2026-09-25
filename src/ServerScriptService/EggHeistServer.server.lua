--[[
	EGG HEIST — Server
	=====================================================================
	"Steal an Egg" uslubidagi to'liq o'yin server logikasi.

	Bu skript butun o'yinni KOD orqali quradi:
	  - Xarita (baseplate, o'yinchi bazalari, tuxum maydoni, shop belgisi)
	  - Tuxum spawn tizimi (nodir darajalar bilan)
	  - O'g'irlash mexanikasi (ProximityPrompt orqali)
	  - Baza / hatch (tuxum ochish) / pet daromadi
	  - PvP: boshqa bazadan pet o'g'irlash
	  - leaderstats (Cash, Rebirths) + upgrade tizimi
	  - DataStore orqali saqlash

	Hech qanday pullik asset ishlatilmaydi — hammasi tekin.
=====================================================================]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

--=====================================================================
-- KONFIGURATSIYA
--=====================================================================

-- Tuxum darajalari: nom, rang, qiymat (pul/sek), tushish ehtimoli (weight)
local RARITIES = {
	{ name = "Common",    color = Color3.fromRGB(190, 190, 190), value = 1,  weight = 50 },
	{ name = "Uncommon",  color = Color3.fromRGB(90, 210, 100), value = 3,  weight = 25 },
	{ name = "Rare",      color = Color3.fromRGB(70, 130, 245), value = 8,  weight = 14 },
	{ name = "Epic",      color = Color3.fromRGB(175, 80, 235), value = 22, weight = 8  },
	{ name = "Legendary", color = Color3.fromRGB(245, 195, 50), value = 65, weight = 3  },
}

-- Upgrade narxlari: base * (mult ^ level)
local UPGRADES = {
	Speed    = { base = 100, mult = 1.6, max = 25 },
	Capacity = { base = 150, mult = 1.8, max = 15 },
	Hatch    = { base = 120, mult = 1.7, max = 8  },
}

local BASE_WALKSPEED   = 16
local PET_PROTECT_TIME = 45     -- pet qo'yilgandan keyin himoya (sekund)
local EGG_SPAWN_DELAY  = 3      -- tuxum maydonini yangilash oralig'i
local AUTOSAVE_DELAY   = 120    -- avtomatik saqlash oralig'i
local NUM_PLOTS        = 8      -- bazalar soni
local STANDS_PER_PLOT  = 6      -- har bazada pet joylari

-- Yordamchi jadval: qiymat -> rang (pet rangi uchun)
local VALUE_COLOR = {}
for _, r in ipairs(RARITIES) do
	VALUE_COLOR[r.value] = r.color
end

local TOTAL_WEIGHT = 0
for _, r in ipairs(RARITIES) do
	TOTAL_WEIGHT += r.weight
end

--=====================================================================
-- DATASTORE (Studio'da API o'chiq bo'lsa xatosiz o'tadi)
--=====================================================================

local store
pcall(function()
	store = DataStoreService:GetDataStore("EggHeist_v1")
end)

--=====================================================================
-- REMOTE EVENTS
--=====================================================================

local remotes = Instance.new("Folder")
remotes.Name = "EggHeistRemotes"
remotes.Parent = ReplicatedStorage

local buyEvent = Instance.new("RemoteEvent")
buyEvent.Name = "Buy"
buyEvent.Parent = remotes

local rebirthEvent = Instance.new("RemoteEvent")
rebirthEvent.Name = "Rebirth"
rebirthEvent.Parent = remotes

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes

local function notify(player, text)
	notifyEvent:FireClient(player, text)
end

--=====================================================================
-- GLOBAL HOLAT
--=====================================================================

local plots = {}       -- plots[i] = {model, floor, hatch, stands={}, owner=Player|nil}
local carrying = {}    -- carrying[userId] = { {kind, value, color, model}, ... }
local eggPads = {}     -- markazdagi tuxum joylari

local eggsFolder = Instance.new("Folder")
eggsFolder.Name = "WildEggs"
eggsFolder.Parent = Workspace

--=====================================================================
-- NARX / DARAJA YORDAMCHILARI
--=====================================================================

local function upgradeCost(name, level)
	local cfg = UPGRADES[name]
	return math.floor(cfg.base * (cfg.mult ^ level))
end

local function rebirthCost(rebirths)
	return 1000 * (rebirths + 1) * (rebirths + 1)
end

local function pickRarity()
	local roll = math.random() * TOTAL_WEIGHT
	local acc = 0
	for _, r in ipairs(RARITIES) do
		acc += r.weight
		if roll <= acc then
			return r
		end
	end
	return RARITIES[1]
end

--=====================================================================
-- XARITA QURISH
--=====================================================================

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function makeSign(parent, text, cframe, color)
	local board = makePart({
		Size = Vector3.new(12, 4, 1),
		CFrame = cframe,
		Color = color or Color3.fromRGB(35, 35, 45),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 130)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	return board
end

local function buildBaseplate()
	local base = makePart({
		Name = "Baseplate",
		Size = Vector3.new(520, 2, 520),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(55, 90, 60),
		Material = Enum.Material.Grass,
		Parent = Workspace,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(0, 0.5, 60)
	spawn.Color = Color3.fromRGB(240, 240, 240)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = Workspace

	return base
end

-- Bitta baza (plot) quradi
local function buildPlot(index, centerCF)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(44, 1, 44),
		CFrame = centerCF,
		Color = Color3.fromRGB(60, 60, 72),
		Material = Enum.Material.Concrete,
		Parent = model,
	})

	-- Hatch pad (tuxum topshirish joyi)
	local hatch = makePart({
		Name = "HatchPad",
		Size = Vector3.new(12, 1, 12),
		CFrame = centerCF * CFrame.new(0, 1, -15),
		Color = Color3.fromRGB(80, 200, 120),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	local hatchPrompt = Instance.new("ProximityPrompt")
	hatchPrompt.ActionText = "Topshirish"
	hatchPrompt.ObjectText = "Hatch Pad"
	hatchPrompt.HoldDuration = 0.2
	hatchPrompt.MaxActivationDistance = 12
	hatchPrompt.RequiresLineOfSight = false
	hatchPrompt.Parent = hatch

	-- Pet joylari (stands)
	local stands = {}
	local startX = -15
	local startZ = 4
	for s = 1, STANDS_PER_PLOT do
		local col = (s - 1) % 3
		local row = math.floor((s - 1) / 3)
		local st = makePart({
			Name = "Stand" .. s,
			Size = Vector3.new(6, 2, 6),
			CFrame = centerCF * CFrame.new(startX + col * 15, 1, startZ + row * 14),
			Color = Color3.fromRGB(45, 45, 55),
			Material = Enum.Material.Metal,
			Parent = model,
		})
		st:SetAttribute("Occupied", false)
		st:SetAttribute("HasPet", false)
		st:SetAttribute("Value", 0)
		st:SetAttribute("ProtectedUntil", 0)
		stands[s] = st
	end

	-- Egasi belgisi
	local sign = makeSign(model, "BO'SH BAZA", centerCF * CFrame.new(0, 4, 22), Color3.fromRGB(40, 40, 55))
	sign.Name = "OwnerSign"

	model.Parent = Workspace
	return { model = model, floor = floor, hatch = hatch, hatchPrompt = hatchPrompt, stands = stands, sign = sign, owner = nil }
end

local function buildEggArea()
	-- Markazda tuxum tug'iladigan pad'lar (halqa shaklida)
	local count = 10
	local radius = 34
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * radius, 0.5, math.sin(angle) * radius)
		local pad = makePart({
			Name = "EggPad" .. i,
			Size = Vector3.new(8, 1, 8),
			Position = pos,
			Color = Color3.fromRGB(120, 100, 70),
			Material = Enum.Material.Slate,
			Parent = Workspace,
		})
		pad:SetAttribute("HasEgg", false)
		table.insert(eggPads, pad)
	end
	makeSign(Workspace, "🥚 TUXUM MAYDONI 🥚", CFrame.new(0, 6, 0), Color3.fromRGB(120, 70, 40))
end

local function buildMap()
	buildBaseplate()
	buildEggArea()

	-- Bazalarni ikki qatorga joylashtiramiz
	local perRow = math.ceil(NUM_PLOTS / 2)
	local spacing = 60
	for i = 1, NUM_PLOTS do
		local row = (i <= perRow) and 1 or 2
		local col = (i <= perRow) and i or (i - perRow)
		local x = (col - (perRow + 1) / 2) * spacing
		local z = (row == 1) and -120 or 120
		local rot = (row == 1) and 0 or math.pi
		local cf = CFrame.new(x, 0.5, z) * CFrame.Angles(0, rot, 0)
		plots[i] = buildPlot(i, cf)
	end
end

--=====================================================================
-- O'YINCHI HOLATI
--=====================================================================

local function plotOfPlayer(player)
	for _, plot in ipairs(plots) do
		if plot.owner == player then
			return plot
		end
	end
	return nil
end

local function assignPlot(player)
	for _, plot in ipairs(plots) do
		if plot.owner == nil then
			plot.owner = player
			local sign = plot.sign:FindFirstChildOfClass("SurfaceGui")
			if sign then
				sign:FindFirstChildOfClass("TextLabel").Text = player.Name
			end
			return plot
		end
	end
	return nil
end

local function freePlot(player)
	local plot = plotOfPlayer(player)
	if not plot then return end
	plot.owner = nil
	local sign = plot.sign:FindFirstChildOfClass("SurfaceGui")
	if sign then
		sign:FindFirstChildOfClass("TextLabel").Text = "BO'SH BAZA"
	end
	-- Stand'larni tozalaymiz
	for _, st in ipairs(plot.stands) do
		for _, child in ipairs(st:GetChildren()) do
			if child:IsA("Part") or child:IsA("Model") then
				child:Destroy()
			end
		end
		st:SetAttribute("Occupied", false)
		st:SetAttribute("HasPet", false)
		st:SetAttribute("Value", 0)
	end
end

local function getCapacity(player)
	return 2 + (player:GetAttribute("CapacityLevel") or 0)
end

local function updateWalkSpeed(player)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local speedLevel = player:GetAttribute("SpeedLevel") or 0
	local carried = carrying[player.UserId] and #carrying[player.UserId] or 0
	hum.WalkSpeed = math.max(8, BASE_WALKSPEED + speedLevel * 2 - carried * 0.6)
end

--=====================================================================
-- OLIB YURISH (CARRY)
--=====================================================================

local function attachCarried(char, index, color)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.8, 2.2, 1.8)
	p.Color = color
	p.Material = Enum.Material.Neon
	p.CanCollide = false
	p.Massless = true
	p.CFrame = hrp.CFrame * CFrame.new(0, 3 + index * 1.9, 0)
	p.Parent = char
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function addCarried(player, kind, value, color)
	local char = player.Character
	if not char then return false end
	local list = carrying[player.UserId]
	if not list then return false end
	if #list >= getCapacity(player) then
		notify(player, "🎒 Sumka to'la! Bazangga borib topshir.")
		return false
	end
	local model = attachCarried(char, #list, color)
	table.insert(list, { kind = kind, value = value, color = color, model = model })
	updateWalkSpeed(player)
	return true
end

--=====================================================================
-- TUXUM SPAWN + O'G'IRLASH
--=====================================================================

local function onStealEgg(player, egg, pad)
	if not egg.Parent then return end
	local value = egg:GetAttribute("Value")
	local color = egg.Color
	if addCarried(player, "egg", value, color) then
		egg:Destroy()
		pad:SetAttribute("HasEgg", false)
	end
end

local function spawnEggAt(pad)
	if pad:GetAttribute("HasEgg") then return end
	local rarity = pickRarity()
	local egg = makePart({
		Name = "WildEgg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.2, 4, 3.2),
		Position = pad.Position + Vector3.new(0, 3, 0),
		Color = rarity.color,
		Material = Enum.Material.Neon,
		Parent = eggsFolder,
	})
	egg.Anchored = true
	egg:SetAttribute("Value", rarity.value)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "O'g'irlash"
	prompt.ObjectText = rarity.name .. " tuxum"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = egg
	prompt.Triggered:Connect(function(plr)
		onStealEgg(plr, egg, pad)
	end)

	pad:SetAttribute("HasEgg", true)
end

--=====================================================================
-- PET JOYLASH / HATCH / DAROMAD
--=====================================================================

local function findFreeStand(plot)
	for i, st in ipairs(plot.stands) do
		if not st:GetAttribute("Occupied") then
			return i, st
		end
	end
	return nil
end

local function onStealPet(thief, plot, standIndex)
	local st = plot.stands[standIndex]
	if not st:GetAttribute("HasPet") then return end
	if plot.owner == thief then return end -- o'zinikini o'g'irlab bo'lmaydi
	if os.time() < st:GetAttribute("ProtectedUntil") then return end

	local value = st:GetAttribute("Value")
	local color = VALUE_COLOR[value] or Color3.fromRGB(200, 200, 200)
	if addCarried(thief, "pet", value, color) then
		-- Stand'ni bo'shatamiz
		for _, child in ipairs(st:GetChildren()) do
			if child:IsA("Part") then child:Destroy() end
		end
		st:SetAttribute("Occupied", false)
		st:SetAttribute("HasPet", false)
		st:SetAttribute("Value", 0)
		if plot.owner then
			notify(plot.owner, "😱 Kimdir pet'ingni o'g'irladi!")
		end
	end
end

local function placePet(plot, standIndex, value)
	local st = plot.stands[standIndex]
	local color = VALUE_COLOR[value] or Color3.fromRGB(200, 200, 200)

	local pet = makePart({
		Name = "Pet",
		Size = Vector3.new(3.5, 3.5, 3.5),
		Shape = Enum.PartType.Ball,
		CFrame = st.CFrame * CFrame.new(0, 3, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = st,
	})
	pet.Anchored = true

	-- Boshidagi qiymat yozuvi
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(80, 30)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = pet
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "$" .. value .. "/s"
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Parent = bb

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pet o'g'irlash"
	prompt.ObjectText = "$" .. value .. "/s"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = pet
	prompt.Triggered:Connect(function(thief)
		onStealPet(thief, plot, standIndex)
	end)

	st:SetAttribute("Occupied", true)
	st:SetAttribute("HasPet", true)
	st:SetAttribute("Value", value)
	st:SetAttribute("ProtectedUntil", os.time() + PET_PROTECT_TIME)
end

local function startHatch(plot, standIndex, value, hatchTime)
	local st = plot.stands[standIndex]
	st:SetAttribute("Occupied", true)
	st:SetAttribute("HasPet", false)

	-- Ochilayotgan tuxum ko'rinishi
	local egg = makePart({
		Name = "Hatching",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3.6, 3),
		CFrame = st.CFrame * CFrame.new(0, 3, 0),
		Color = VALUE_COLOR[value] or Color3.fromRGB(200, 200, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		Parent = st,
	})
	egg.Anchored = true

	task.delay(hatchTime, function()
		if egg and egg.Parent then egg:Destroy() end
		-- Baza egasi almashmagan bo'lsa joylaymiz
		if st.Parent then
			placePet(plot, standIndex, value)
		end
	end)
end

local function getHatchTime(player)
	local hatchLevel = player:GetAttribute("HatchLevel") or 0
	return math.max(2, 10 - hatchLevel)
end

local function onDeposit(player)
	local plot = plotOfPlayer(player)
	if not plot then
		notify(player, "Sizda baza yo'q.")
		return
	end
	local list = carrying[player.UserId]
	if not list or #list == 0 then
		notify(player, "🎒 Sumkang bo'sh.")
		return
	end

	local hatchTime = getHatchTime(player)
	local placed = 0
	-- Ro'yxat oxiridan boramiz (chunki o'chirib boramiz)
	for i = #list, 1, -1 do
		local entry = list[i]
		local standIndex = findFreeStand(plot)
		if not standIndex then
			notify(player, "🏠 Bazang to'la! (" .. STANDS_PER_PLOT .. " joy)")
			break
		end
		-- Stand'ni darhol band qilamiz
		plot.stands[standIndex]:SetAttribute("Occupied", true)
		if entry.model then entry.model:Destroy() end
		if entry.kind == "pet" then
			placePet(plot, standIndex, entry.value)
		else
			startHatch(plot, standIndex, entry.value, hatchTime)
		end
		table.remove(list, i)
		placed += 1
	end

	if placed > 0 then
		notify(player, "✅ " .. placed .. " ta topshirildi!")
	end
	updateWalkSpeed(player)
end

--=====================================================================
-- LEADERSTATS + SAQLASH
--=====================================================================

local function setupPlayer(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 0
	cash.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = leaderstats

	player:SetAttribute("SpeedLevel", 0)
	player:SetAttribute("CapacityLevel", 0)
	player:SetAttribute("HatchLevel", 0)
end

local function loadData(player)
	if not store then return end
	local key = "player_" .. player.UserId
	local ok, data = pcall(function()
		return store:GetAsync(key)
	end)
	if ok and type(data) == "table" then
		player.leaderstats.Cash.Value = data.Cash or 0
		player.leaderstats.Rebirths.Value = data.Rebirths or 0
		player:SetAttribute("SpeedLevel", data.Speed or 0)
		player:SetAttribute("CapacityLevel", data.Capacity or 0)
		player:SetAttribute("HatchLevel", data.Hatch or 0)
		-- Pet'larni qayta joylash
		local plot = plotOfPlayer(player)
		if plot and type(data.Pets) == "table" then
			for _, value in ipairs(data.Pets) do
				local standIndex = findFreeStand(plot)
				if standIndex then
					placePet(plot, standIndex, value)
				end
			end
		end
	end
end

local function saveData(player)
	if not store then return end
	local plot = plotOfPlayer(player)
	local pets = {}
	if plot then
		for _, st in ipairs(plot.stands) do
			if st:GetAttribute("HasPet") then
				table.insert(pets, st:GetAttribute("Value"))
			end
		end
	end
	local data = {
		Cash = player.leaderstats.Cash.Value,
		Rebirths = player.leaderstats.Rebirths.Value,
		Speed = player:GetAttribute("SpeedLevel") or 0,
		Capacity = player:GetAttribute("CapacityLevel") or 0,
		Hatch = player:GetAttribute("HatchLevel") or 0,
		Pets = pets,
	}
	pcall(function()
		store:SetAsync("player_" .. player.UserId, data)
	end)
end

--=====================================================================
-- SHOP (RemoteEvent orqali)
--=====================================================================

buyEvent.OnServerEvent:Connect(function(player, upgradeName)
	local cfg = UPGRADES[upgradeName]
	if not cfg then return end
	local attr = upgradeName .. "Level"
	local level = player:GetAttribute(attr) or 0
	if level >= cfg.max then
		notify(player, "⭐ Maksimal daraja!")
		return
	end
	local cost = upgradeCost(upgradeName, level)
	local cash = player.leaderstats.Cash
	if cash.Value < cost then
		notify(player, "💸 Pul yetmaydi! ($" .. cost .. " kerak)")
		return
	end
	cash.Value -= cost
	player:SetAttribute(attr, level + 1)
	if upgradeName == "Speed" then
		updateWalkSpeed(player)
	end
	notify(player, "⬆️ " .. upgradeName .. " Lvl " .. (level + 1) .. "!")
end)

rebirthEvent.OnServerEvent:Connect(function(player)
	local rebirths = player.leaderstats.Rebirths
	local cash = player.leaderstats.Cash
	local cost = rebirthCost(rebirths.Value)
	if cash.Value < cost then
		notify(player, "🔄 Rebirth uchun $" .. cost .. " kerak!")
		return
	end
	cash.Value = 0
	rebirths.Value += 1
	-- Bazani tozalaymiz
	local plot = plotOfPlayer(player)
	if plot then
		for _, st in ipairs(plot.stands) do
			for _, child in ipairs(st:GetChildren()) do
				if child:IsA("Part") then child:Destroy() end
			end
			st:SetAttribute("Occupied", false)
			st:SetAttribute("HasPet", false)
			st:SetAttribute("Value", 0)
		end
	end
	notify(player, "🌟 REBIRTH! Endi daromading x" .. (1 + rebirths.Value * 0.5))
end)

--=====================================================================
-- ASOSIY SIKLLAR
--=====================================================================

-- Daromad + himoya prompt'larini yangilash (har sekund)
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for _, plot in ipairs(plots) do
			if plot.owner then
				local player = plot.owner
				local income = 0
				for _, st in ipairs(plot.stands) do
					if st:GetAttribute("HasPet") then
						income += st:GetAttribute("Value")
						-- Himoya tugagan bo'lsa o'g'irlash prompt'ini yoqamiz
						local pet = st:FindFirstChild("Pet")
						if pet then
							local prompt = pet:FindFirstChildOfClass("ProximityPrompt")
							if prompt then
								prompt.Enabled = now >= st:GetAttribute("ProtectedUntil")
							end
						end
					end
				end
				if income > 0 then
					local rebirths = player.leaderstats.Rebirths.Value
					local mult = 1 + rebirths * 0.5
					local ls = player:FindFirstChild("leaderstats")
					if ls then
						ls.Cash.Value += math.floor(income * mult)
					end
				end
			end
		end
	end
end)

-- Tuxum spawn sikli
task.spawn(function()
	while true do
		for _, pad in ipairs(eggPads) do
			if not pad:GetAttribute("HasEgg") and math.random() < 0.6 then
				spawnEggAt(pad)
			end
		end
		task.wait(EGG_SPAWN_DELAY)
	end
end)

-- Avtomatik saqlash
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_DELAY)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)

--=====================================================================
-- O'YINCHI ULANISH / CHIQISH
--=====================================================================

local function onCharacterAdded(player)
	task.wait(0.2)
	updateWalkSpeed(player)
end

Players.PlayerAdded:Connect(function(player)
	carrying[player.UserId] = {}
	setupPlayer(player)
	assignPlot(player)
	loadData(player)

	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	if player.Character then
		onCharacterAdded(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	freePlot(player)
	carrying[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

--=====================================================================
-- ISHGA TUSHIRISH
--=====================================================================

buildMap()

-- Har bazaning hatch prompt'ini bog'laymiz
for _, plot in ipairs(plots) do
	plot.hatchPrompt.Triggered:Connect(function(player)
		if plot.owner == player then
			onDeposit(player)
		else
			notify(player, "Bu sizning bazangiz emas!")
		end
	end)
end

print("[Egg Heist] Server tayyor! Xarita qurildi.")
