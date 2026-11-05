--!strict
-- Enchanted Realm: Inkbound — client master script (mobile-friendly).
-- Builds its own HUD, supports keyboard/gamepad AND touch controls.
-- Integrates: Title Screen, Pause Menu, Settings, cooldown UI, zone notifications.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- SyncGui must exist BEFORE requiring the UI modules: TitleScreen/PauseMenu/Settings
-- WaitForChild("SyncGui") at module scope, and would deadlock this script forever.
local SyncGuiEarly = Instance.new("ScreenGui")
SyncGuiEarly.Name = "SyncGui"
SyncGuiEarly.ResetOnSpawn = false
SyncGuiEarly.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SyncGuiEarly.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local TitleScreen = require(script.Parent:WaitForChild("TitleScreen"))
local PauseMenu = require(script.Parent:WaitForChild("PauseMenu"))
local Settings = require(script.Parent:WaitForChild("Settings"))

-- device detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isConsole = GuiService:IsTenFootInterface()
local deviceLabel = if isConsole then "Console" elseif isMobile then "Mobile" else "Desktop"

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

-- remotes
local remotes = ReplicatedStorage:WaitForChild("InkboundRemotes")
local RE = {
	swing = remotes:WaitForChild("AttackSwing"),
	cast = remotes:WaitForChild("CastAbility"),
	interact = remotes:WaitForChild("Interact"),
	respawn = remotes:WaitForChild("RespawnRequest"),
	win = remotes:WaitForChild("GameWon"),
	sync = remotes:WaitForChild("StateSync"),
	buy = remotes:WaitForChild("BuyItem", 5),
	awaken = remotes:WaitForChild("Awaken"),
	syncTime = remotes:WaitForChild("SyncTime"),
}

-- simulation state
local character: Model? = nil
local hrp: BasePart? = nil
local hum: Humanoid? = nil
local grounded = false
local canDoubleJump = true
local coyoteUntil = 0
local attackAnimating = false
local castLockUntil = 0

-- ui state
local paused = false
local titleOpen = true
local zoneNotifyConn: RBXScriptConnection? = nil

-- HUD refs (built below)
local gui: ScreenGui
local frame: Frame
local hpBar, inkBar, xpBar: Frame
local hpFill, inkFill, xpFill: Frame
local levelLabel, objectiveLabel: TextLabel
local bossBar, bossFill, bossNameLabel: Frame, Frame, TextLabel
local abilityBar: Frame
local abilityBtns: { [string]: TextButton } = {}
local cooldownOverlays: { [string]: Frame } = {}

local ABILITY_ORDER = { "lightning", "fire", "ice", "wind", "powerRock", "lightningCore", "shockwave" }
local hotkeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven }

-- —————— helpers ——————

local function playSfx(key: string, position: Vector3?, volume: number?)
	Effects.playSfx(key, position, (volume or 0.8) * Settings.getSFX())
end

local function setFill(fill: Frame, ratio: number)
	fill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
end

local function drawHUD(payload: any)
	setFill(hpFill, payload.hp / payload.maxHp)
	setFill(inkFill, payload.ink / payload.maxInk)
	setFill(xpFill, payload.xp / payload.xpNext)
	inkFill.BackgroundColor3 = if payload.ink >= payload.maxInk then Color3.fromRGB(255, 215, 120) else Color3.fromRGB(140, 225, 255)
	levelLabel.Text = "LV " .. payload.level
	for id, btn in pairs(abilityBtns) do
		local known = (payload.abilities :: any)[id] == true
		btn.TextColor3 = if known then Color3.fromRGB(255, 240, 210) else Color3.fromRGB(110, 110, 120)
	end
	gui:SetAttribute("LastPayload", payload)
end

local function showZoneNotify(zoneName: string)
	local banner = Instance.new("TextLabel")
	banner.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
	banner.BackgroundTransparency = 0.15
	banner.BorderSizePixel = 0
	banner.Size = UDim2.new(0, 420, 0, 56)
	banner.Position = UDim2.new(0.5, -210, 0.18, -28)
	banner.Font = Enum.Font.Bangers
	banner.Text = zoneName
	banner.TextColor3 = Color3.fromRGB(255, 220, 150)
	banner.TextScaled = true
	banner.ZIndex = 45
	banner.Parent = gui
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 14)
	bc.Parent = banner
	TweenService:Create(banner, TweenInfo.new(0.3), { BackgroundTransparency = 0.05 }):Play()
	Debris:AddItem(banner, 3)
end

-- —————— HUD construction ——————

-- SyncGui was already created above (the UI modules required it early)
gui = SyncGuiEarly

frame = Instance.new("Frame")
frame.Name = "Frame"
frame.BackgroundTransparency = 1
frame.Size = UDim2.new(1, 0, 1, 0)
frame.Parent = gui

-- top bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
topBar.Size = UDim2.new(0, 340, 0, 44)
topBar.Position = UDim2.new(0.5, -170, 0, 10)
topBar.Parent = frame
local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 10)
topCorner.Parent = topBar

levelLabel = Instance.new("TextLabel")
levelLabel.Name = "Level"
levelLabel.BackgroundTransparency = 1
levelLabel.Size = UDim2.new(0, 100, 1, 0)
levelLabel.Position = UDim2.new(0, 12, 0, 0)
levelLabel.Font = Enum.Font.Bangers
levelLabel.Text = "LV 1"
levelLabel.TextColor3 = Color3.fromRGB(255, 215, 110)
levelLabel.TextScaled = true
levelLabel.TextXAlignment = Enum.TextXAlignment.Left
levelLabel.Parent = topBar

local deviceBadge = Instance.new("TextLabel")
deviceBadge.Name = "DeviceBadge"
deviceBadge.BackgroundColor3 = Color3.fromRGB(40, 34, 48)
deviceBadge.BackgroundTransparency = 0.3
deviceBadge.BorderSizePixel = 0
deviceBadge.Size = UDim2.new(0, 86, 0, 20)
deviceBadge.Position = UDim2.new(1, -96, 0, 12)
deviceBadge.Font = Enum.Font.GothamBold
deviceBadge.Text = deviceLabel .. " · " .. (isMobile and "Touch" or isConsole and "Gamepad" or "Keyboard")
deviceBadge.TextColor3 = Color3.fromRGB(170, 170, 190)
deviceBadge.TextScaled = true
deviceBadge.Parent = topBar
local dbCorner = Instance.new("UICorner")
dbCorner.CornerRadius = UDim.new(0, 8)
dbCorner.Parent = deviceBadge

objectiveLabel = Instance.new("TextLabel")
objectiveLabel.Name = "Objective"
objectiveLabel.BackgroundTransparency = 1
objectiveLabel.Size = UDim2.new(0, 200, 1, 0)
objectiveLabel.Position = UDim2.new(0, 120, 0, 0)
objectiveLabel.Font = Enum.Font.Bangers
objectiveLabel.Text = "Explore the forest and find a way through"
objectiveLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
objectiveLabel.TextScaled = true
objectiveLabel.TextWrapped = true
objectiveLabel.TextXAlignment = Enum.TextXAlignment.Left
objectiveLabel.Parent = topBar

-- stat rows
local function makeStatRow(name: string, labelText: string, barColor: Color3, order: number): (Frame, Frame, Frame, TextLabel)
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(0, 220, 0, 22)
	row.Position = UDim2.new(0.5, -110, 0, 60 + (order - 1) * 28)
	row.Parent = frame
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(0, 56, 1, 0)
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = labelText
	lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
	lbl.TextScaled = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, -68, 1, 0)
	bar.Position = UDim2.new(0, 68, 0, 0)
	bar.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = barColor
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.Parent = bar
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 6)
	fc.Parent = fill
	return row, bar, fill, lbl
end

hpBar, _, hpFill, _ = makeStatRow("HpBar", "HP", Color3.fromRGB(255, 90, 110), 1)
inkBar, _, inkFill, _ = makeStatRow("InkBar", "INK", Color3.fromRGB(140, 225, 255), 2)
xpBar, _, xpFill, _ = makeStatRow("XpBar", "XP", Color3.fromRGB(255, 215, 110), 3)

-- ability bar
local abilityBtnSize = if isMobile then 56 else 48
abilityBar = Instance.new("Frame")
abilityBar.Name = "AbilityBar"
abilityBar.BackgroundTransparency = 1
abilityBar.Size = UDim2.new(0, abilityBtnSize * 7 + 36, 0, abilityBtnSize + 10)
abilityBar.Position = UDim2.new(0.5, -(abilityBtnSize * 7 + 36) / 2, 0, if isMobile then 176 else 156)
abilityBar.Parent = frame

-- ability tooltip
local tooltip = Instance.new("TextLabel")
tooltip.Name = "AbilityTooltip"
tooltip.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
tooltip.BackgroundTransparency = 0.15
tooltip.BorderSizePixel = 0
tooltip.Size = UDim2.new(0, 260, 0, 44)
tooltip.Position = UDim2.new(0.5, -130, 0.3, -22)
tooltip.Font = Enum.Font.Gotham
tooltip.Text = ""
tooltip.TextColor3 = Color3.fromRGB(255, 240, 210)
tooltip.TextScaled = true
tooltip.TextWrapped = true
tooltip.Visible = false
tooltip.ZIndex = 60
tooltip.Parent = gui
local ttc = Instance.new("UICorner")
ttc.CornerRadius = UDim.new(0, 10)
ttc.Parent = tooltip
local ts = Instance.new("UIStroke")
ts.Color = Color3.fromRGB(80, 70, 90)
ts.Thickness = 2
ts.Parent = tooltip

for i, id in ipairs(ABILITY_ORDER) do
	local btn = Instance.new("TextButton")
	btn.Name = id .. "Btn"
	btn.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	btn.BorderSizePixel = 0
	btn.Size = UDim2.new(0, abilityBtnSize, 0, abilityBtnSize)
	btn.Position = UDim2.new(0, (i - 1) * (abilityBtnSize + 6), 0, 0)
	btn.Font = Enum.Font.Bangers
	btn.Text = id
	btn.TextColor3 = Color3.fromRGB(140, 140, 150)
	btn.TextScaled = true
	btn.Parent = abilityBar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = btn
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(70, 60, 80)
	s.Thickness = 2
	s.Parent = btn
	-- cooldown overlay
	local cd = Instance.new("Frame")
	cd.Name = "Cooldown"
	cd.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cd.BackgroundTransparency = 0.45
	cd.BorderSizePixel = 0
	cd.Size = UDim2.new(1, 0, 1, 0)
	cd.Visible = false
	cd.ZIndex = 5
	cd.Parent = btn
	local cdc = Instance.new("UICorner")
	cdc.CornerRadius = UDim.new(0, 12)
	cdc.Parent = cd
	btn.MouseEnter:Connect(function()
		local ab = Config.ABILITIES[id]
		if ab and not titleOpen then
			tooltip.Text = ab.name .. " — " .. ab.desc
			tooltip.Position = UDim2.new(0, btn.AbsolutePosition.X + btn.AbsoluteSize.X + 10, 0, btn.AbsolutePosition.Y - 10)
			tooltip.Visible = true
		end
	end)
	btn.MouseLeave:Connect(function()
		tooltip.Visible = false
	end)
	abilityBtns[id] = btn
	cooldownOverlays[id] = cd
end

-- —————— clock (follows the player's local time) ——————
local clockLabel = Instance.new("TextLabel")
clockLabel.Name = "Clock"
clockLabel.BackgroundTransparency = 1
clockLabel.Size = UDim2.new(0, 130, 0, 24)
clockLabel.Position = UDim2.new(1, -10, 0, 10)
clockLabel.Font = Enum.Font.Bangers
clockLabel.Text = ""
clockLabel.TextColor3 = Color3.fromRGB(235, 225, 205)
clockLabel.TextScaled = true
clockLabel.TextXAlignment = Enum.TextXAlignment.Right
clockLabel.TextStrokeTransparency = 0.55
clockLabel.ZIndex = 6
clockLabel.Parent = frame

task.spawn(function()
	while true do
		local t = os.date("*t")
		local hour = t.hour
		local ampm = hour >= 12 and "PM" or "AM"
		local h12 = hour % 12
		if h12 == 0 then
			h12 = 12
		end
		clockLabel.Text = string.format("%d:%02d %s", h12, t.min, ampm)
		task.wait(1)
	end
end)

-- boss health bar
bossBar = Instance.new("Frame")
bossBar.Name = "BossBar"
bossBar.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
bossBar.BackgroundTransparency = 0.2
bossBar.BorderSizePixel = 0
bossBar.Size = UDim2.new(0, 300, 0, 30)
bossBar.Position = UDim2.new(0.5, -150, 0, 100)
bossBar.Visible = false
bossBar.Parent = frame
local bCorner = Instance.new("UICorner")
bCorner.CornerRadius = UDim.new(0, 8)
bCorner.Parent = bossBar
bossNameLabel = Instance.new("TextLabel")
bossNameLabel.Name = "Name"
bossNameLabel.BackgroundTransparency = 1
bossNameLabel.Size = UDim2.new(1, 0, 0, 18)
bossNameLabel.Font = Enum.Font.Bangers
bossNameLabel.Text = ""
bossNameLabel.TextColor3 = Color3.fromRGB(255, 240, 210)
bossNameLabel.TextScaled = true
bossNameLabel.Parent = bossBar
local bossBarInner = Instance.new("Frame")
bossBarInner.Name = "FillBar"
bossBarInner.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
bossBarInner.BorderSizePixel = 0
bossBarInner.Size = UDim2.new(1, -12, 0, 10)
bossBarInner.Position = UDim2.new(0, 6, 0, 18)
bossBarInner.Parent = bossBar
bossFill = Instance.new("Frame")
bossFill.Name = "Fill"
bossFill.BackgroundColor3 = Color3.fromRGB(255, 80, 100)
bossFill.BorderSizePixel = 0
bossFill.Size = UDim2.new(1, 0, 1, 0)
bossFill.Parent = bossBarInner
local bfCorner = Instance.new("UICorner")
bfCorner.CornerRadius = UDim.new(0, 4)
-- —————— awaken + skills ——————

local function makeHudButton(name: string, text: string, pos: UDim2, callback: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	b.BackgroundTransparency = 0.15
	b.BorderSizePixel = 0
	b.Size = UDim2.new(0, 92, 0, 34)
	b.Position = pos
	b.Font = Enum.Font.Bangers
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 240, 210)
	b.TextScaled = true
	b.ZIndex = 6
	b.Parent = frame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(70, 60, 80)
	s.Thickness = 2
	s.Parent = b
	b.Activated:Connect(callback)
	return b
end

local awakenBtn = makeHudButton("AwakenBtn", "AWAKEN", UDim2.new(1, -222, 0, 44), function()
	RE.awaken:FireServer()
end)

-- skills & shop panel
local skillsOpen = false
local skillsPanel = Instance.new("Frame")
skillsPanel.Name = "SkillsPanel"
skillsPanel.BackgroundColor3 = Color3.fromRGB(8, 6, 12)
skillsPanel.BackgroundTransparency = 0.35
skillsPanel.BorderSizePixel = 0
skillsPanel.Size = UDim2.new(1, 0, 1, 0)
skillsPanel.ZIndex = 32
skillsPanel.Visible = false
skillsPanel.Parent = gui
local panelBox = Instance.new("Frame")
panelBox.Name = "PanelBox"
panelBox.BackgroundColor3 = Color3.fromRGB(16, 13, 22)
panelBox.BorderSizePixel = 0
panelBox.Size = UDim2.new(0, 620, 0, 460)
panelBox.Position = UDim2.new(0.5, -310, 0.5, -230)
panelBox.ZIndex = 33
panelBox.Parent = skillsPanel
local pbc = Instance.new("UICorner")
pbc.CornerRadius = UDim.new(0, 16)
pbc.Parent = panelBox
local pbStroke = Instance.new("UIStroke")
pbStroke.Color = Color3.fromRGB(80, 68, 96)
pbStroke.Thickness = 2
pbStroke.Parent = panelBox
local pTitle = Instance.new("TextLabel")
pTitle.Name = "Title"
pTitle.BackgroundTransparency = 1
pTitle.Size = UDim2.new(1, 0, 0, 42)
pTitle.Position = UDim2.new(0, 0, 0, 8)
pTitle.Font = Enum.Font.Bangers
pTitle.Text = "SKILLS & SHOP"
pTitle.TextColor3 = Color3.fromRGB(255, 235, 160)
pTitle.TextScaled = true
pTitle.ZIndex = 34
pTitle.Parent = panelBox
local pSub = Instance.new("TextLabel")
pSub.Name = "Sub"
pSub.BackgroundTransparency = 1
pSub.Size = UDim2.new(1, 0, 0, 15)
pSub.Position = UDim2.new(0, 0, 0, 46)
pSub.Font = Enum.Font.Gotham
pSub.Text = "XP is spent for good. Haste is your enemy."
pSub.TextColor3 = Color3.fromRGB(150, 145, 165)
pSub.TextScaled = true
pSub.ZIndex = 34
pSub.Parent = panelBox
local pClose = Instance.new("TextButton")
pClose.Name = "CloseSkills"
pClose.BackgroundColor3 = Color3.fromRGB(40, 32, 46)
pClose.BorderSizePixel = 0
pClose.Size = UDim2.new(0, 32, 0, 32)
pClose.Position = UDim2.new(1, -42, 0, 8)
pClose.Font = Enum.Font.Bangers
pClose.Text = "X"
pClose.TextColor3 = Color3.fromRGB(255, 240, 210)
pClose.TextScaled = true
pClose.ZIndex = 35
pClose.Parent = panelBox
local pcc = Instance.new("UICorner")
pcc.CornerRadius = UDim.new(0, 8)
pcc.Parent = pClose
local rowsHolder = Instance.new("Frame")
rowsHolder.Name = "Rows"
rowsHolder.BackgroundTransparency = 1
rowsHolder.Size = UDim2.new(1, -20, 1, -78)
rowsHolder.Position = UDim2.new(0, 10, 0, 66)
rowsHolder.ZIndex = 34
rowsHolder.Parent = panelBox

local refreshSkillsPanel: () -> ()
local function clearRows()
	for _, c in ipairs(rowsHolder:GetChildren()) do
		c:Destroy()
	end
end
local BOSS_HINTS = {
	lightning = "Sealed — defeat the Mechanical Guardian",
	powerRock = "Sealed — defeat the Machine Warrior",
	fire = "Sealed — defeat the Fire Guardian",
	ice = "Sealed — defeat the Ice Guardian",
	wind = "Sealed — defeat the Storm Guardian",
	lightningCore = "Sealed — defeat Nukos",
}
local rowIndex = 0
local function addRow(icon: string, iconColor: Color3, name: string, desc: string, status: string, statusColor: Color3, buyId: string?)
	rowIndex += 1
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Color3.fromRGB(24, 20, 30)
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 27)
	row.Position = UDim2.new(0, 0, 0, (rowIndex - 1) * 31)
	row.ZIndex = 34
	row.Parent = rowsHolder
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row
	local iconLbl = Instance.new("TextLabel")
	iconLbl.BackgroundTransparency = 1
	iconLbl.Size = UDim2.new(0, 28, 1, 0)
	iconLbl.Position = UDim2.new(0, 4, 0, 0)
	iconLbl.Font = Enum.Font.Bangers
	iconLbl.Text = icon
	iconLbl.TextColor3 = iconColor
	iconLbl.TextScaled = true
	iconLbl.ZIndex = 35
	iconLbl.Parent = row
	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size = UDim2.new(0.46, 0, 0, 14)
	nameLbl.Position = UDim2.new(0, 36, 0, 1)
	nameLbl.Font = Enum.Font.Bangers
	nameLbl.Text = name
	nameLbl.TextColor3 = Color3.fromRGB(255, 240, 210)
	nameLbl.TextScaled = true
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.ZIndex = 35
	nameLbl.Parent = row
	local descLbl = Instance.new("TextLabel")
	descLbl.BackgroundTransparency = 1
	descLbl.Size = UDim2.new(0.46, 0, 0, 12)
	descLbl.Position = UDim2.new(0, 36, 0, 15)
	descLbl.Font = Enum.Font.Gotham
	descLbl.Text = desc
	descLbl.TextColor3 = Color3.fromRGB(150, 145, 165)
	descLbl.TextScaled = true
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.ZIndex = 35
	descLbl.Parent = row
	if buyId then
		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(0, 128, 0, 20)
		buyBtn.Position = UDim2.new(1, -136, 0, 3)
		buyBtn.BackgroundColor3 = Color3.fromRGB(63, 96, 74)
		buyBtn.BorderSizePixel = 0
		buyBtn.Font = Enum.Font.Bangers
		buyBtn.Text = "BUY — " .. status
		buyBtn.TextColor3 = Color3.fromRGB(255, 240, 210)
		buyBtn.TextScaled = true
		buyBtn.ZIndex = 36
		buyBtn.Parent = row
		local bbc = Instance.new("UICorner")
		bbc.CornerRadius = UDim.new(0, 7)
		bbc.Parent = buyBtn
		buyBtn.Activated:Connect(function()
			RE.buy:FireServer(buyId)
			buyBtn.Text = "…"
			task.delay(0.4, function()
				(refreshSkillsPanel :: () -> ())()
			end)
		end)
	else
		local tag = Instance.new("TextLabel")
		tag.BackgroundTransparency = 1
		tag.Size = UDim2.new(0, 128, 1, 0)
		tag.Position = UDim2.new(1, -132, 0, 0)
		tag.Font = Enum.Font.Bangers
		tag.Text = status
		tag.TextColor3 = statusColor
		tag.TextScaled = true
		tag.TextXAlignment = Enum.TextXAlignment.Right
		tag.ZIndex = 35
		tag.Parent = row
	end
end

refreshSkillsPanel = function()
	clearRows()
	rowIndex = 0
	local payload = gui:GetAttribute("LastPayload") :: any?
	local xp = payload and payload.xp or 0
	local roles = payload and payload.roles or {}
	local jobs = payload and payload.jobs or {}
	local pages = payload and payload.pages or {}
	local maxHp = payload and payload.maxHp or Config.PLAYER.baseHealth
	local maxInk = payload and payload.maxInk or Config.INK.max
	local level = payload and payload.level or 1
	local baseHp = Config.PLAYER.baseHealth + Config.PLAYER.levelHealthBonus * (level - 1)
	local hearts = math.max(0, math.floor((maxHp - baseHp) / Config.PLAYER.heartBonus))
	local satchels = math.max(0, math.floor((maxInk - Config.INK.max) / 25))
	local pageCount = 0
	for _ in pairs(pages) do
		pageCount += 1
	end

	addRow("»", Color3.fromRGB(200, 190, 230), "Ink Memories", "Hidden lore pages in the world (" .. pageCount .. "/8 found)", pageCount .. " / 8", Color3.fromRGB(255, 215, 120), nil)
	for key, def in pairs(Config.STYLES) do
		local rank = roles[key] or 0
		local status = if rank >= 3 then "MAXED" else "150 XP"
		local color = if rank >= 3 then Color3.fromRGB(150, 220, 150) else Color3.fromRGB(255, 215, 110)
		addRow(def.icon, def.color, def.name .. " — Rank " .. rank .. "/3", def.desc, status, color, rank < 3 and ("style_" .. key) or nil)
	end
	for key, def in pairs(Config.JOBS) do
		local rank = jobs[key] or 0
		local status = if rank >= 3 then "MAXED" else "150 XP"
		local color = if rank >= 3 then Color3.fromRGB(150, 220, 150) else Color3.fromRGB(255, 215, 110)
		addRow(def.icon, def.color, def.name .. " — Rank " .. rank .. "/3", def.desc, status, color, rank < 3 and ("job_" .. key) or nil)
	end
	local tomeOwned = (payload and payload.abilities or {}).shockwave == true
	addRow("◎", Color3.fromRGB(150, 215, 255), "Tome of Shockwave", "AoE damage around you — press [7]", tomeOwned and "OWNED" or "200 XP", tomeOwned and Color3.fromRGB(150, 220, 150) or Color3.fromRGB(255, 215, 110), not tomeOwned and "shockwave" or nil)
	addRow("◆", Color3.fromRGB(140, 225, 255), "Ink Satchel — " .. satchels .. "/3", "+25 max ink, permanent", satchels >= 3 and "MAXED" or "150 XP", satchels >= 3 and Color3.fromRGB(150, 220, 150) or Color3.fromRGB(255, 215, 110), satchels < 3 and "satchel" or nil)
	addRow("♥", Color3.fromRGB(255, 130, 150), "Heart Container — " .. hearts .. "/3", "+20 max HP, permanent", hearts >= 3 and "MAXED" or "150 XP", hearts >= 3 and Color3.fromRGB(150, 220, 150) or Color3.fromRGB(255, 215, 110), hearts < 3 and "heart" or nil)
	addRow("✦", Color3.fromRGB(255, 215, 110), "Ink Potion", "Refill your ink meter to full", "10 XP", Color3.fromRGB(255, 215, 110), "potion")
end

local skillsBtn = makeHudButton("SkillsBtn", "SKILLS", UDim2.new(1, -114, 0, 44), function()
	skillsOpen = not skillsOpen
	skillsPanel.Visible = skillsOpen
	if skillsOpen then
		refreshSkillsPanel()
	end
end)

pClose.Activated:Connect(function()
	skillsOpen = false
	skillsPanel.Visible = false
end)

bfCorner.Parent = bossFill

-- forward declarations for mobile buttons
local function requestJump_forward() requestJump() end
local function swingAttack_forward() swingAttack() end
local function doInteract_forward() doInteract() end

-- mobile touch controls
if isMobile then
	local padSize = 64
	-- (custom D-pad removed — full 3D uses Roblox's built-in touch controls)	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundTransparency = 1
	actions.Size = UDim2.new(0, padSize * 2 + 32, 0, padSize + 16)
	actions.Position = UDim2.new(1, -(padSize * 2 + 42), 1, -(padSize + 44))
	actions.Parent = frame

	local actBtnSize = padSize

	local function actBtn(name: string, xScale: number, text: string, onActivated: () -> ()): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		b.BackgroundTransparency = 0.8
		b.BorderSizePixel = 0
		b.Size = UDim2.new(0, actBtnSize, 0, actBtnSize)
		b.Position = UDim2.new(xScale, 0, 0.5, -actBtnSize / 2)
		b.Font = Enum.Font.Bangers
		b.Text = text
		b.TextColor3 = Color3.fromRGB(255, 245, 220)
		b.TextScaled = true
		b.Parent = actions
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 18)
		c.Parent = b
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(255, 255, 255)
		s.Transparency = 0.4
		s.Thickness = 2
		s.Parent = b
		b.Activated:Connect(onActivated)
		return b
	end

	actBtn("JumpBtn", 0, "⬆", requestJump_forward)
	local swingBtn = actBtn("AttackBtn", 1, "⚔", swingAttack_forward) :: TextButton
	swingBtn.Position = UDim2.new(1, -actBtnSize, 0.5, -actBtnSize / 2)

	local interactBtn = actBtn("InteractBtn", 0.5, "E", doInteract_forward) :: TextButton
	interactBtn.Position = UDim2.new(0.5, -actBtnSize / 2, 0.22, -actBtnSize / 2)
end

-- —————— tactical map (flat atlas view) ——————

local MAP_ZONES = {
	{ key = "forest",      name = "ENCHANTED FOREST", minX = 0,    maxX = 400,  color = Color3.fromRGB(66, 116, 66)  },
	{ key = "ruins",       name = "MECHANICAL RUINS", minX = 416,  maxX = 760,  color = Color3.fromRGB(110, 96, 66)  },
	{ key = "burning",     name = "BURNING FOREST",   minX = 776,  maxX = 1010, color = Color3.fromRGB(132, 72, 48)  },
	{ key = "frozen",      name = "FROZEN RUINS",     minX = 1026, maxX = 1285, color = Color3.fromRGB(88, 120, 152) },
	{ key = "cave",        name = "SECRET CAVE",      minX = 1301, maxX = 1490, color = Color3.fromRGB(88, 66, 116)  },
	{ key = "sky",         name = "SKY RUINS",        minX = 1490, maxX = 2015, color = Color3.fromRGB(96, 118, 142) },
	{ key = "underground", name = "UNDERGROUND",      minX = 2015, maxX = 2680, color = Color3.fromRGB(48, 40, 52)   },
}
local MAP_BOSSES = {
	{ kind = "mechanical", x = 345,  label = "KIDLAT"   },
	{ kind = "machine",    x = 712,  label = "PIYEDRO"  },
	{ kind = "fire",       x = 955,  label = "PEYRO"    },
	{ kind = "ice",        x = 1250, label = "DAN"      },
	{ kind = "storm",      x = 1962, label = "MAAM JYR" },
	{ kind = "squid",      x = 2545, label = "NUKOS"    },
}
local WORLD_SPAN = 2680
local mapOpen = false
local youMarker: TextLabel

local mapPanel = Instance.new("Frame")
mapPanel.Name = "TacticalMap"
mapPanel.BackgroundColor3 = Color3.fromRGB(8, 6, 12)
mapPanel.BackgroundTransparency = 0.25
mapPanel.BorderSizePixel = 0
mapPanel.Size = UDim2.new(1, 0, 1, 0)
mapPanel.ZIndex = 32
mapPanel.Visible = false
mapPanel.Parent = gui
local mapBox = Instance.new("Frame")
mapBox.Name = "PanelBox"
mapBox.BackgroundColor3 = Color3.fromRGB(11, 18, 26)
mapBox.Size = UDim2.new(0, 900, 0, 470)
mapBox.Position = UDim2.new(0.5, -450, 0.5, -235)
mapBox.BorderSizePixel = 0
mapBox.ZIndex = 33
mapBox.Parent = mapPanel
local mbc = Instance.new("UICorner")
mbc.CornerRadius = UDim.new(0, 16)
mbc.Parent = mapBox
local mbStroke = Instance.new("UIStroke")
mbStroke.Color = Color3.fromRGB(90, 110, 140)
mbStroke.Thickness = 2
mbStroke.Parent = mapBox

local mapTitle = Instance.new("TextLabel")
mapTitle.Name = "Title"
mapTitle.BackgroundTransparency = 1
mapTitle.Size = UDim2.new(0.8, 0, 0, 40)
mapTitle.Position = UDim2.new(0, 20, 0, 8)
mapTitle.Font = Enum.Font.Bangers
mapTitle.Text = "TACTICAL MAP — INKBOUND REALM"
mapTitle.TextColor3 = Color3.fromRGB(190, 255, 190)
mapTitle.TextScaled = true
mapTitle.TextXAlignment = Enum.TextXAlignment.Left
mapTitle.ZIndex = 34
mapTitle.Parent = mapBox

-- ocean canvas
local ocean = Instance.new("Frame")
ocean.Name = "Ocean"
ocean.Size = UDim2.new(1, -40, 1, -120)
ocean.Position = UDim2.new(0, 20, 0, 62)
ocean.BorderSizePixel = 0
ocean.BackgroundColor3 = Color3.fromRGB(24, 46, 66)
ocean.ZIndex = 34
ocean.Parent = mapBox
local oc = Instance.new("UICorner")
oc.CornerRadius = UDim.new(0, 14)
oc.Parent = ocean
local ocGradient = Instance.new("UIGradient")
ocGradient.Color = ColorSequence.new(Color3.fromRGB(14, 26, 42), Color3.fromRGB(44, 78, 104))
ocGradient.Rotation = 90
ocGradient.Parent = ocean
local ocStroke = Instance.new("UIStroke")
ocStroke.Color = Color3.fromRGB(72, 108, 140)
ocStroke.Thickness = 3
ocStroke.Parent = ocean

-- grid lines (parallels + meridians) + atlas labels
for i = 1, 5 do
	local line = Instance.new("Frame")
	line.Name = "Meridian_" .. i
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BackgroundTransparency = 0.9
	line.BorderSizePixel = 0
	line.Size = UDim2.new(0, 1, 1, 0)
	line.Position = UDim2.new(i / 6, 0, 0, 0)
	line.ZIndex = 35
	line.Parent = ocean
end
for i = 1, 3 do
	local line = Instance.new("Frame")
	line.Name = "Parallel_" .. i
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BackgroundTransparency = 0.9
	line.BorderSizePixel = 0
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, i / 4, 0)
	line.ZIndex = 35
	line.Parent = ocean
end
local letters = { "A", "B", "C", "D", "E", "F" }
for i, l in ipairs(letters) do
	local lbl = Instance.new("TextLabel")
	lbl.Name = "GridCol_" .. l
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1 / 6, 0, 0, 16)
	lbl.Position = UDim2.new((i - 1) / 6, 0, -0.055, 0)
	lbl.Font = Enum.Font.Bangers
	lbl.Text = l
	lbl.TextColor3 = Color3.fromRGB(150, 185, 220)
	lbl.TextTransparency = 0.25
	lbl.TextScaled = true
	lbl.ZIndex = 35
	lbl.Parent = ocean
end
for r = 1, 4 do
	local lbl = Instance.new("TextLabel")
	lbl.Name = "GridRow_" .. r
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(0.045, 0, 0.2, 0)
	lbl.Position = UDim2.new(0.006, 0, (r - 1) / 4 + 0.02, 0)
	lbl.Font = Enum.Font.Bangers
	lbl.Text = tostring(r)
	lbl.TextColor3 = Color3.fromRGB(150, 185, 220)
	lbl.TextTransparency = 0.25
	lbl.TextScaled = true
	lbl.ZIndex = 35
	lbl.Parent = ocean
end

-- continent blobs per zone (organic clusters, atlas look)
local bossMarks: { [string]: TextLabel } = {}
for _, zone in ipairs(MAP_ZONES) do
	local zx = zone.minX / WORLD_SPAN
	local zw = (zone.maxX - zone.minX) / WORLD_SPAN
	local function blob(sx: number, sy: number, px: number, py: number, grow: number)
		local b = Instance.new("Frame")
		b.BackgroundColor3 = zone.color
		b.BorderSizePixel = 0
		b.Size = UDim2.new(zw * sx, 0, sy, 0)
		b.Position = UDim2.new(zx + zw * px, 0, py, 0)
		b.ZIndex = 36
		b.Parent = ocean
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 26)
		c.Parent = b
		return b
	end
	blob(0.6, 0.34, 0.02, 0.18, 0)   -- upper-left mass
	blob(1.0, 0.34, 0.0, 0.32, 0)    -- main body
	blob(0.66, 0.28, 0.3, 0.52, 0)   -- lower-right mass

	local name = Instance.new("TextLabel")
	name.Name = "Name_" .. zone.key
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(zw, 0, 0.12, 0)
	name.Position = UDim2.new(zx, 0, 0.33, 0)
	name.Font = Enum.Font.Bangers
	name.Text = zone.name
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextTransparency = 0.12
	name.TextStrokeTransparency = 0.65
	name.TextScaled = true
	name.ZIndex = 37
	name.Parent = ocean
end

-- boss markers (x by boss, greyed when felled)
local bossRowY = 0.52
for _, boss in ipairs(MAP_BOSSES) do
	local holder = Instance.new("Frame")
	holder.Name = "Boss_" .. boss.kind
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(0.05, 0, 0.22, 0)
	holder.Position = UDim2.new(boss.x / WORLD_SPAN - 0.025, 0, bossRowY - 0.07, 0)
	holder.ZIndex = 38
	holder.Parent = ocean
	local mark = Instance.new("TextLabel")
	mark.Name = "Mark"
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.new(1, 0, 0.6, 0)
	mark.Position = UDim2.new(0, 0, 0, 0)
	mark.Font = Enum.Font.Bangers
	mark.Text = "×"
	mark.TextScaled = true
	mark.TextColor3 = Color3.fromRGB(255, 90, 90)
	mark.ZIndex = 38
	mark.Parent = holder
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.4, 0)
	label.Position = UDim2.new(0, 0, 0.55, 0)
	label.Font = Enum.Font.Bangers
	label.Text = "BOSS"
	label.TextColor3 = Color3.fromRGB(255, 110, 110)
	label.TextScaled = true
	label.ZIndex = 38
	label.Parent = holder
	bossMarks[boss.kind] = mark
end

-- "YOU" marker
youMarker = Instance.new("TextLabel")
youMarker.Name = "YouMarker"
youMarker.BackgroundTransparency = 1
youMarker.Size = UDim2.new(0.05, 0, 0.16, 0)
youMarker.Position = UDim2.new(30 / WORLD_SPAN - 0.025, 0, 0.55, 0)
youMarker.Font = Enum.Font.Bangers
youMarker.Text = "▲"
youMarker.TextScaled = true
youMarker.TextColor3 = Color3.fromRGB(255, 235, 110)
youMarker.TextStrokeTransparency = 0.3
youMarker.ZIndex = 39
youMarker.Parent = ocean
local youLabel = Instance.new("TextLabel")
youLabel.Name = "YouLabel"
youLabel.BackgroundTransparency = 1
youLabel.Size = UDim2.new(0.07, 0, 0.1, 0)
youLabel.Position = UDim2.new(30 / WORLD_SPAN - 0.035, 0, 0.75, 0)
youLabel.Font = Enum.Font.Bangers
youLabel.Text = "YOU"
youLabel.TextColor3 = Color3.fromRGB(255, 235, 110)
youLabel.TextTransparency = 0.15
youLabel.TextScaled = true
youLabel.ZIndex = 39
youLabel.Parent = ocean

-- compass
local compass = Instance.new("Frame")
compass.Name = "Compass"
compass.Size = UDim2.new(0.075, 0, 0.24, 0)
compass.Position = UDim2.new(0.905, 0, 0.05, 0)
compass.BackgroundColor3 = Color3.fromRGB(10, 24, 38)
compass.BackgroundTransparency = 0.15
compass.BorderSizePixel = 0
compass.ZIndex = 38
compass.Parent = ocean
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(1, 0)
cc.Parent = compass
local cs = Instance.new("UIStroke")
cs.Color = Color3.fromRGB(150, 190, 230)
cs.Thickness = 1.5
cs.Parent = compass
local compassN = Instance.new("TextLabel")
compassN.Name = "North"
compassN.BackgroundTransparency = 1
compassN.Size = UDim2.new(1, 0, 0.55, 0)
compassN.Position = UDim2.new(0, 0, 0.06, 0)
compassN.Font = Enum.Font.Bangers
compassN.Text = "N"
compassN.TextColor3 = Color3.fromRGB(190, 255, 190)
compassN.TextScaled = true
compassN.ZIndex = 39
compassN.Parent = compass

-- footer: legend + world-progress bar
local legend = Instance.new("TextLabel")
legend.Name = "Legend"
legend.BackgroundTransparency = 1
legend.Size = UDim2.new(0.46, 0, 0, 14)
legend.Position = UDim2.new(0, 6, 1, -18)
legend.Font = Enum.Font.Gotham
legend.Text = "▲ YOU    × GUARDIAN    ✦ MEMORY"
legend.TextColor3 = Color3.fromRGB(150, 190, 220)
legend.TextScaled = true
legend.TextXAlignment = Enum.TextXAlignment.Left
legend.ZIndex = 38
legend.Parent = mapBox

local progressCaption = Instance.new("TextLabel")
progressCaption.Name = "ProgressCaption"
progressCaption.BackgroundTransparency = 1
progressCaption.Size = UDim2.new(0.46, 0, 0, 12)
progressCaption.Position = UDim2.new(0.5, 0, 1, -18)
progressCaption.Font = Enum.Font.Gotham
progressCaption.Text = "GUARDIANS FELLED 0/6"
progressCaption.TextColor3 = Color3.fromRGB(150, 190, 220)
progressCaption.TextScaled = true
progressCaption.TextXAlignment = Enum.TextXAlignment.Right
progressCaption.ZIndex = 38
progressCaption.Parent = mapBox

local progressBack = Instance.new("Frame")
progressBack.Name = "Progress"
progressBack.Size = UDim2.new(0.5, 0, 0, 8)
progressBack.Position = UDim2.new(0.5, 0, 1, -30)
progressBack.BackgroundColor3 = Color3.fromRGB(30, 40, 56)
progressBack.BorderSizePixel = 0
progressBack.ZIndex = 38
progressBack.Parent = mapBox
local pbc2 = Instance.new("UICorner")
pbc2.CornerRadius = UDim.new(0, 4)
pbc2.Parent = progressBack
local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(255, 215, 120)
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 39
progressFill.Parent = progressBack
local pfc = Instance.new("UICorner")
pfc.CornerRadius = UDim.new(0, 4)
pfc.Parent = progressFill

local mapClose = Instance.new("TextButton")
mapClose.Name = "CloseMap"
mapClose.BackgroundColor3 = Color3.fromRGB(55, 32, 32)
mapClose.BorderSizePixel = 0
mapClose.Size = UDim2.new(0, 34, 0, 34)
mapClose.Position = UDim2.new(1, -42, 0, 8)
mapClose.Font = Enum.Font.Bangers
mapClose.Text = "X"
mapClose.TextColor3 = Color3.fromRGB(255, 200, 200)
mapClose.TextScaled = true
mapClose.ZIndex = 40
mapClose.Parent = mapBox
local mcc = Instance.new("UICorner")
mcc.CornerRadius = UDim.new(0, 8)
mcc.Parent = mapClose

local function refreshMap()
	local payload = gui:GetAttribute("LastPayload") :: any?
	local defeated = (payload and payload.bossesDefeated) or {}
	local pages = payload and payload.pages or {}
	for _, boss in ipairs(MAP_BOSSES) do
		local mark = bossMarks[boss.kind]
		if mark then
			mark.TextColor3 = if defeated[boss.kind] then Color3.fromRGB(120, 210, 130) else Color3.fromRGB(255, 90, 90)
		end
	end
	local felled = 0
	for _, boss in ipairs(MAP_BOSSES) do
		if defeated[boss.kind] then
			felled += 1
		end
	end
	progressFill.Size = UDim2.new(felled / 6, 0, 1, 0)
	progressCaption.Text = "GUARDIANS FELLED " .. felled .. "/6"
	local found = 0
	for _ in pairs(pages) do
		found += 1
	end
	legend.Text = "▲ YOU    × GUARDIAN    ✦ MEMORY " .. found .. "/8"
end

local lastMapHeartbeat = 0
local function toggleMap(force: boolean?)
	mapOpen = if force ~= nil then force else not mapOpen
	mapPanel.Visible = mapOpen
	if mapOpen then
		refreshMap()
	end
end

mapClose.Activated:Connect(function()
	toggleMap(false)
end)

RunService.Heartbeat:Connect(function()
	if not mapOpen then
		return
	end
	if tick() - lastMapHeartbeat < 0.4 then
		return
	end
	lastMapHeartbeat = tick()
	local fraction = math.clamp(((hrp and hrp.Position.X) or 30) / WORLD_SPAN, 0, 1)
	youMarker.Position = UDim2.new(fraction - 0.025, 0, 0.55, 0)
	youLabel.Position = UDim2.new(fraction - 0.035, 0, 0.72, 0)
end)

local mapBtn = makeHudButton("MapBtn", "MAP", UDim2.new(1, -330, 0, 44), function()
	toggleMap()
end)

-- —————— input ——————

local function castAbility(abilityId: string)
	if tick() < castLockUntil or paused or titleOpen then
		return
	end
	local cd = cooldownOverlays[abilityId]
	if cd and cd.Visible then
		return -- on cooldown
	end
	castLockUntil = tick() + 0.45
	local aim = mouse.Hit
	RE.cast:FireServer(abilityId, aim.Position)
	-- local cooldown visual
	if cd then
		cd.Visible = true
		TweenService:Create(cd, TweenInfo.new(0.6), { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 1, 0) }):Play()
		task.delay(0.6, function()
			cd.Visible = false
			cd.Size = UDim2.new(1, 0, 1, 0)
			cd.Position = UDim2.new(0, 0, 0, 0)
		end)
	end
end

for i, id in ipairs(ABILITY_ORDER) do
	local btn = abilityBtns[id]
	btn.Activated:Connect(function()
		castAbility(id)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	-- pause toggle
	if input.KeyCode == Enum.KeyCode.Escape then
		if mapOpen then
			toggleMap(false)
			return
		end
		if not titleOpen then
			togglePause()
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		toggleMap()
		return
	end
	for i, kc in ipairs(hotkeys) do
		if input.KeyCode == kc then
			castAbility(ABILITY_ORDER[i])
		end
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if not paused and not titleOpen then
			swingAttack()
		end
	end
	if input.KeyCode == Enum.KeyCode.E then
		if not paused and not titleOpen then
			doInteract()
		end
	end
	if input.KeyCode == Enum.KeyCode.Q then
		if not paused and not titleOpen then
			RE.awaken:FireServer()
		end
	end
	if input.KeyCode == Enum.KeyCode.Space then
		if not paused and not titleOpen then
			requestJump()
		end
	end
end)

-- —————— actions ——————

function swingAttack()
	if attackAnimating or not hrp or paused or titleOpen then
		return
	end
	attackAnimating = true
	local look = camera.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(1, 0, 0)
	end
	dir = dir.Unit
	RE.swing:FireServer(dir)
	local origin = hrp.Position + dir * 2 + Vector3.new(0, 1.4, 0)
	Effects.swing(origin, dir, false)
	Effects.shakeCamera(0.07, 0.1)
	playSfx("SwordSlash", origin, 0.7)
	task.delay(0.34, function()
		attackAnimating = false
	end)
end

function requestJump()
	if not hrp or paused or titleOpen then
		return
	end
	local now = tick()
	local able = grounded or now < coyoteUntil or canDoubleJump
	if not able then
		return
	end
	local jumpPower = Config.PLAYER.jumpPower
	local payload = gui:GetAttribute("LastPayload") :: any?
	if payload and payload.abilities and payload.abilities.wind and not grounded and now >= coyoteUntil then
		jumpPower = Config.PLAYER.doubleJumpPower
		canDoubleJump = false
		playSfx("DoubleJump", hrp.Position, 0.7)
	else
		playSfx("Jump", hrp.Position, 0.7)
	end
	hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, jumpPower, hrp.AssemblyLinearVelocity.Z)
	grounded = false
end

function doInteract()
	if not hrp or paused or titleOpen then
		return
	end
	local worldFolder = workspace:FindFirstChild("EnchantedRealm")
	if not worldFolder then
		return
	end
	local bestName: string? = nil
	local bestDist = math.huge
	local lanterns = worldFolder:FindFirstChild("Lanterns")
	if lanterns then
		for _, l in ipairs(lanterns:GetChildren()) do
			if l:IsA("Model") then
				local pp = l.PrimaryPart :: BasePart?
				if pp then
					local d = (hrp.Position - pp.Position).Magnitude
					if d < 11 and d < bestDist then
						bestDist = d
						bestName = l.Name
					end
				end
			end
		end
	end
	if bestName then
		RE.interact:FireServer(bestName)
		return
	end
	local portals = worldFolder:FindFirstChild("Portals")
	if portals then
		for _, p in ipairs(portals:GetChildren()) do
			if p:IsA("BasePart") and (hrp.Position - p.Position).Magnitude < 9 then
				RE.interact:FireServer(p.Name)
				Effects.teleportFlash(p.Position)
				playSfx("PortalHum", p.Position, 0.8)
				return
			end
		end
	end
	local finale = worldFolder:FindFirstChild("FinalePortal") :: BasePart?
	if finale and (hrp.Position - finale.Position).Magnitude < 10 then
		RE.interact:FireServer("FinalePortal")
	end
end

-- —————— pause / settings ——————

function togglePause()
	if titleOpen then
		return
	end
	if paused then
		PauseMenu.close()
		paused = false
	else
		PauseMenu.open()
		paused = true
	end
end

-- —————— character setup ——————

local function setupCharacter(char: Model)
	character = char
	hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
	hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.WalkSpeed = Config.PLAYER.baseSpeed
	hum.JumpPower = Config.PLAYER.jumpPower
	hum.AutoRotate = true
	-- we drive jumping ourselves (double jump / wind bonus) — disable the default
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	hrp.CFrame = CFrame.lookAt(Vector3.new(30, 4, 0), Vector3.new(200, 4, 0))

	-- full 3D: default Roblox third-person camera (mouse orbit / wheel zoom)
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = hum
	camera.CameraMaxZoomDistance = 18
	camera.CameraMinZoomDistance = 4

	-- kill-Y check only — the Z axis is free in 3D
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not char.Parent then
			conn:Disconnect()
			return
		end
		if hrp.Position.Y < Config.WORLD.killY then
			RE.respawn:FireServer()
		end
	end)

	-- grounded detection, coyote time, wind glide
	-- (locomotion itself is handled by the default controller — WASD / touch stick)
	RunService.Heartbeat:Connect(function(_dt)
		if not hrp or paused or titleOpen then
			return
		end
		local origin = hrp.Position + Vector3.new(0, 1, 0)
		local result = workspace:Raycast(origin, Vector3.new(0, -hrp.Size.Y / 2 - 0.4, 0))
		if result then
			if not grounded then
				grounded = true
				canDoubleJump = true
				playSfx("Land", hrp.Position, 0.5)
				local a = Instance.new("Attachment")
				a.Parent = hrp
				local p = Instance.new("ParticleEmitter")
				p.Texture = "rbxassetid://243660364"
				p.Color = ColorSequence.new(result.Instance.Color)
				p.Rate = 0
				p.Lifetime = NumberRange.new(0.25, 0.5)
				p.Speed = NumberRange.new(3, 7)
				p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
				p.Parent = a
				p:Emit(14)
				Debris:AddItem(a, 1)
			end
			coyoteUntil = tick() + 0.12
		else
			grounded = false
		end
		local payload = gui:GetAttribute("LastPayload") :: any?
		if payload and payload.abilities and payload.abilities.wind and not grounded then
			local vel = hrp.AssemblyLinearVelocity
			if vel.Y < 0 then
				hrp.AssemblyLinearVelocity = vel * Vector3.new(1, Config.PLAYER.windGlideFactor, 1)
			end
		end
	end)

	-- time of day: the realm keeps the player's clock
	local nowT = os.date("*t")
	RE.syncTime:FireServer(nowT.hour + nowT.min / 60)
	task.spawn(function()
		while true do
			task.wait(60)
			if not char.Parent then
				return
			end
			local tt = os.date("*t")
			RE.syncTime:FireServer(tt.hour + tt.min / 60)
		end
	end)
end

-- —————— remote event handlers ——————

RE.sync.OnClientEvent:Connect(drawHUD)

remotes:WaitForChild("ZoneEnter").OnClientEvent:Connect(function(zoneId: string, zoneName: string)
	showZoneNotify(zoneName)
end)

remotes:WaitForChild("PlaySound").OnClientEvent:Connect(function(key: string, position: Vector3, volume: number?)
	playSfx(key, position, volume)
end)

remotes:WaitForChild("VFX").OnClientEvent:Connect(function(kind: string, ...)
	local args = { ... }
	if kind == "swing" then
		Effects.swing(args[1], args[2], args[3])
	elseif kind == "cast" then
		Effects.cast(args[1], args[2], args[3])
	elseif kind == "breakBarrier" then
		Effects.breakBarrier(args[1], args[2])
	elseif kind == "lanternLit" then
		Effects.lanternLit(args[1])
	elseif kind == "hurtFlash" then
		Effects.hurtFlash()
	elseif kind == "bossBurst" then
		Effects.bossBurst(args[1], args[2])
	elseif kind == "deniedHint" then
		Effects.deniedHint(args[1], args[2])
	elseif kind == "root" then
		Effects.root(args[1])
	elseif kind == "blindPlayer" then
		Effects.blindPlayer()
	elseif kind == "burn" then
		Effects.burn(args[1])
	elseif kind == "teleportFlash" then
		Effects.teleportFlash(args[1])
	end
end)

remotes:WaitForChild("BossHealth").OnClientEvent:Connect(function(_kind: string, name: string, hp: number, maxHp: number)
	bossBar.Visible = true
	bossNameLabel.Text = name
	setFill(bossFill, hp / maxHp)
end)

remotes:WaitForChild("ObjectiveText"):WaitForChild("Changed") -- ensure exists
local objectiveValue = remotes:WaitForChild("ObjectiveText") :: StringValue
objectiveValue.Changed:Connect(function(text)
	if not titleOpen then
		objectiveLabel.Text = text
	end
end)
objectiveLabel.Text = objectiveValue.Value

RE.win.OnClientEvent:Connect(function()
	local overlay = Instance.new("Frame")
	overlay.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
	overlay.BackgroundTransparency = 0.15
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 50
	overlay.Parent = gui
	local msg = Instance.new("TextLabel")
	msg.BackgroundTransparency = 1
	msg.Size = UDim2.new(1, 0, 0, 80)
	msg.Position = UDim2.new(0, 0, 0.4, -40)
	msg.Font = Enum.Font.Bangers
	msg.Text = "Journey Complete — You Returned Home"
	msg.TextColor3 = Color3.fromRGB(255, 235, 160)
	msg.TextScaled = true
	msg.Parent = overlay
	playSfx("Victory", hrp and hrp.Position or Vector3.zero, 1)
end)

remotes:WaitForChild("Dialogue").OnClientEvent:Connect(function(id: string, text: string)
	local toast = Instance.new("TextLabel")
	toast.Name = "DialogueToast"
	toast.BackgroundColor3 = Color3.fromRGB(25, 20, 28)
	toast.BackgroundTransparency = 0.2
	toast.BorderSizePixel = 0
	toast.Size = UDim2.new(0, 340, 0, 44)
	toast.Position = UDim2.new(0.5, -170, 0.82, 0)
	toast.Font = Enum.Font.Bangers
	toast.Text = text
	toast.TextColor3 = Color3.fromRGB(255, 240, 210)
	toast.TextScaled = true
	toast.ZIndex = 40
	toast.Parent = gui
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 12)
	tc.Parent = toast
	Debris:AddItem(toast, 6)
	playSfx("UiClick", Vector3.zero, 0.5)
end)

remotes:WaitForChild("Narrator").OnClientEvent:Connect(function(text: string, duration: number)
	local banner = Instance.new("TextLabel")
	banner.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	banner.BackgroundTransparency = 0.15
	banner.BorderSizePixel = 0
	banner.Size = UDim2.new(0, 520, 0, 70)
	banner.Position = UDim2.new(0.5, -260, 0.28, -35)
	banner.Font = Enum.Font.Bangers
	banner.Text = text
	banner.TextColor3 = Color3.fromRGB(255, 255, 255)
	banner.TextScaled = true
	banner.ZIndex = 45
	banner.Parent = gui
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 14)
	bc.Parent = banner
	TweenService:Create(banner, TweenInfo.new(0.3), { BackgroundTransparency = 0.05 }):Play()
	Debris:AddItem(banner, duration or 4)
	playSfx("AbilityUnlock", Vector3.zero, 0.6)
end)

-- —————— title screen integration ——————

TitleScreen.onStart(function()
	titleOpen = false
	TitleScreen.close()
	-- spawn character (already loaded by server, but nudge position)
	if player.Character then
		local h = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if h then
			h.CFrame = CFrame.new(30, 4, 0)
		end
	end
end)

TitleScreen.onSettings(function()
	Settings.open()
end)

Settings.onClose(function()
	-- nothing needed
end)

-- pause menu wiring
PauseMenu.onResume(function()
	paused = false
	PauseMenu.close()
end)
PauseMenu.onSettings(function()
	Settings.open()
	PauseMenu.close()
end)
PauseMenu.onRestart(function()
	RE.respawn:FireServer()
	PauseMenu.close()
	paused = false
end)
PauseMenu.onQuitToMenu(function()
	-- reload title
	titleOpen = true
	-- rebuild menu
	-- (simplest: respawn character and show title again)
	TitleScreen.close() -- already closed; just re-show a light version
	paused = false
end)

Settings.onClose(function()
	-- if we came from pause, reopen pause
	if paused then
		PauseMenu.open()
	end
end)

-- character setup
player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end
player:LoadCharacter()

print("[Inkbound] client ready (mobile=" .. tostring(isMobile) .. ")")
