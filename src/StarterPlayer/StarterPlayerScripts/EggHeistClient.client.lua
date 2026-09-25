--[[
	EGG HEIST — Client
	=====================================================================
	Bu skript o'yin interfeysini (GUI) KOD orqali quradi:
	  - Yuqorida: Cash va Rebirths ko'rsatkichi
	  - Pastda: Shop paneli (Speed, Bag, Hatch upgrade + Rebirth)
	  - Bildirishnomalar (toast)
	  - Qisqa qo'llanma

	Hech qanday tashqi asset kerak emas.
=====================================================================]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Server konfiguratsiyasining nusxasi (faqat narxni ko'rsatish uchun)
local UPGRADES = {
	Speed    = { base = 100, mult = 1.6, max = 25, label = "🏃 Tezlik", attr = "SpeedLevel" },
	Capacity = { base = 150, mult = 1.8, max = 15, label = "🎒 Sumka",  attr = "CapacityLevel" },
	Hatch    = { base = 120, mult = 1.7, max = 8,  label = "🥚 Hatch",  attr = "HatchLevel" },
}

local function upgradeCost(name, level)
	local cfg = UPGRADES[name]
	return math.floor(cfg.base * (cfg.mult ^ level))
end

local function rebirthCost(rebirths)
	return 1000 * (rebirths + 1) * (rebirths + 1)
end

--=====================================================================
-- REMOTE'LARNI KUTAMIZ
--=====================================================================

local remotes = ReplicatedStorage:WaitForChild("EggHeistRemotes")
local buyEvent = remotes:WaitForChild("Buy")
local rebirthEvent = remotes:WaitForChild("Rebirth")
local notifyEvent = remotes:WaitForChild("Notify")

local leaderstats = player:WaitForChild("leaderstats")
local cash = leaderstats:WaitForChild("Cash")
local rebirths = leaderstats:WaitForChild("Rebirths")

--=====================================================================
-- GUI QURISH
--=====================================================================

local gui = Instance.new("ScreenGui")
gui.Name = "EggHeistGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(0, 0, 0)
	s.Thickness = thickness or 2
	s.Parent = parent
	return s
end

--------------------------------------------------------------------
-- Yuqori panel: Cash + Rebirths
--------------------------------------------------------------------
local topFrame = Instance.new("Frame")
topFrame.Size = UDim2.fromOffset(230, 78)
topFrame.Position = UDim2.new(0, 16, 0, 16)
topFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
topFrame.BackgroundTransparency = 0.1
topFrame.Parent = gui
corner(topFrame, 12)
stroke(topFrame, Color3.fromRGB(80, 200, 120), 2)

local cashLabel = Instance.new("TextLabel")
cashLabel.Size = UDim2.new(1, -16, 0, 34)
cashLabel.Position = UDim2.fromOffset(8, 6)
cashLabel.BackgroundTransparency = 1
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextScaled = true
cashLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
cashLabel.Text = "💰 $0"
cashLabel.Parent = topFrame

local rebirthLabel = Instance.new("TextLabel")
rebirthLabel.Size = UDim2.new(1, -16, 0, 28)
rebirthLabel.Position = UDim2.fromOffset(8, 42)
rebirthLabel.BackgroundTransparency = 1
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthLabel.Font = Enum.Font.GothamMedium
rebirthLabel.TextScaled = true
rebirthLabel.TextColor3 = Color3.fromRGB(180, 130, 255)
rebirthLabel.Text = "🌟 Rebirth: 0  (x1.0)"
rebirthLabel.Parent = topFrame

--------------------------------------------------------------------
-- Qo'llanma paneli (o'ng yuqori)
--------------------------------------------------------------------
local helpFrame = Instance.new("Frame")
helpFrame.Size = UDim2.fromOffset(250, 118)
helpFrame.Position = UDim2.new(1, -266, 0, 16)
helpFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
helpFrame.BackgroundTransparency = 0.2
helpFrame.Parent = gui
corner(helpFrame, 12)
stroke(helpFrame, Color3.fromRGB(70, 130, 245), 2)

local helpText = Instance.new("TextLabel")
helpText.Size = UDim2.new(1, -16, 1, -12)
helpText.Position = UDim2.fromOffset(8, 6)
helpText.BackgroundTransparency = 1
helpText.TextXAlignment = Enum.TextXAlignment.Left
helpText.TextYAlignment = Enum.TextYAlignment.Top
helpText.Font = Enum.Font.Gotham
helpText.TextSize = 14
helpText.TextColor3 = Color3.fromRGB(230, 230, 240)
helpText.TextWrapped = true
helpText.Text = "📖 QANDAY O'YNASH:\n1) Tuxum maydonidan tuxum o'g'irla (E)\n2) Bazangga olib borib Topshir\n3) Pet pul ishlaydi 💰\n4) Shop'dan kuchay va rebirth qil!"
helpText.Parent = helpFrame

--------------------------------------------------------------------
-- Shop paneli (past)
--------------------------------------------------------------------
local shop = Instance.new("Frame")
shop.Size = UDim2.fromOffset(560, 96)
shop.AnchorPoint = Vector2.new(0.5, 1)
shop.Position = UDim2.new(0.5, 0, 1, -16)
shop.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
shop.BackgroundTransparency = 0.1
shop.Parent = gui
corner(shop, 14)
stroke(shop, Color3.fromRGB(255, 220, 90), 2)

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 10)
layout.Parent = shop

local buttons = {}

local function makeButton(order, key)
	local cfg = UPGRADES[key]
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(128, 76)
	btn.LayoutOrder = order
	btn.BackgroundColor3 = Color3.fromRGB(45, 90, 65)
	btn.AutoButtonColor = true
	btn.Text = ""
	btn.Parent = shop
	corner(btn, 10)
	stroke(btn, Color3.fromRGB(0, 0, 0), 1.5)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -8, 0, 26)
	title.Position = UDim2.fromOffset(4, 4)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = cfg.label
	title.Parent = btn

	local info = Instance.new("TextLabel")
	info.Name = "Info"
	info.Size = UDim2.new(1, -8, 0, 42)
	info.Position = UDim2.fromOffset(4, 30)
	info.BackgroundTransparency = 1
	info.Font = Enum.Font.GothamMedium
	info.TextScaled = true
	info.TextColor3 = Color3.fromRGB(230, 255, 230)
	info.Text = "Lvl 0\n$0"
	info.Parent = btn

	btn.Activated:Connect(function()
		buyEvent:FireServer(key)
	end)

	buttons[key] = { button = btn, info = info }
end

makeButton(1, "Speed")
makeButton(2, "Capacity")
makeButton(3, "Hatch")

-- Rebirth tugmasi
local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Size = UDim2.fromOffset(128, 76)
rebirthBtn.LayoutOrder = 4
rebirthBtn.BackgroundColor3 = Color3.fromRGB(95, 55, 140)
rebirthBtn.Text = ""
rebirthBtn.Parent = shop
corner(rebirthBtn, 10)
stroke(rebirthBtn, Color3.fromRGB(0, 0, 0), 1.5)

local rbTitle = Instance.new("TextLabel")
rbTitle.Size = UDim2.new(1, -8, 0, 26)
rbTitle.Position = UDim2.fromOffset(4, 4)
rbTitle.BackgroundTransparency = 1
rbTitle.Font = Enum.Font.GothamBold
rbTitle.TextScaled = true
rbTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
rbTitle.Text = "🌟 Rebirth"
rbTitle.Parent = rebirthBtn

local rbInfo = Instance.new("TextLabel")
rbInfo.Size = UDim2.new(1, -8, 0, 42)
rbInfo.Position = UDim2.fromOffset(4, 30)
rbInfo.BackgroundTransparency = 1
rbInfo.Font = Enum.Font.GothamMedium
rbInfo.TextScaled = true
rbInfo.TextColor3 = Color3.fromRGB(240, 220, 255)
rbInfo.Text = "$1000"
rbInfo.Parent = rebirthBtn

rebirthBtn.Activated:Connect(function()
	rebirthEvent:FireServer()
end)

--=====================================================================
-- BILDIRISHNOMA (TOAST)
--=====================================================================

local toast = Instance.new("TextLabel")
toast.Size = UDim2.fromOffset(420, 44)
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 120)
toast.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
toast.BackgroundTransparency = 0.15
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.Text = ""
toast.Visible = false
toast.Parent = gui
corner(toast, 10)
stroke(toast, Color3.fromRGB(255, 220, 90), 2)

local toastToken = 0
notifyEvent.OnClientEvent:Connect(function(text)
	toastToken += 1
	local myToken = toastToken
	toast.Text = text
	toast.Visible = true
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.15
	task.delay(2.2, function()
		if myToken ~= toastToken then return end
		local t1 = TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		t1:Play()
		t1.Completed:Wait()
		if myToken == toastToken then
			toast.Visible = false
		end
	end)
end)

--=====================================================================
-- KO'RSATKICHLARNI YANGILASH
--=====================================================================

local function refresh()
	cashLabel.Text = "💰 $" .. cash.Value
	local mult = 1 + rebirths.Value * 0.5
	rebirthLabel.Text = "🌟 Rebirth: " .. rebirths.Value .. "  (x" .. string.format("%.1f", mult) .. ")"

	for key, data in pairs(buttons) do
		local cfg = UPGRADES[key]
		local level = player:GetAttribute(cfg.attr) or 0
		if level >= cfg.max then
			data.info.Text = "Lvl " .. level .. "\nMAX ⭐"
			data.button.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		else
			local cost = upgradeCost(key, level)
			data.info.Text = "Lvl " .. level .. "\n$" .. cost
			local afford = cash.Value >= cost
			data.button.BackgroundColor3 = afford and Color3.fromRGB(45, 120, 75) or Color3.fromRGB(70, 55, 55)
		end
	end

	local rbCost = rebirthCost(rebirths.Value)
	rbInfo.Text = "$" .. rbCost
	rebirthBtn.BackgroundColor3 = (cash.Value >= rbCost) and Color3.fromRGB(120, 70, 180) or Color3.fromRGB(70, 55, 90)
end

cash.Changed:Connect(refresh)
rebirths.Changed:Connect(refresh)
player:GetAttributeChangedSignal("SpeedLevel"):Connect(refresh)
player:GetAttributeChangedSignal("CapacityLevel"):Connect(refresh)
player:GetAttributeChangedSignal("HatchLevel"):Connect(refresh)

refresh()

print("[Egg Heist] Client GUI tayyor!")
