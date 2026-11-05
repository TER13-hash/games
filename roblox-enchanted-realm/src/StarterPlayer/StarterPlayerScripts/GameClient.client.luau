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
}

-- simulation state
local character: Model? = nil
local hrp: BasePart? = nil
local hum: Humanoid? = nil
local facing = 1
local grounded = false
local canDoubleJump = true
local coyoteUntil = 0
local attackAnimating = false
local castLockUntil = 0
local moveDir = 0 -- set by keyboard AND touch D-pad

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

local ABILITY_ORDER = { "lightning", "fire", "ice", "wind", "powerRock", "lightningCore" }
local hotkeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }

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
local function makeStatRow(name: string, labelText: string, barColor: Color3, order: number): { Frame, Frame, TextLabel }
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
abilityBar.Size = UDim2.new(0, abilityBtnSize * 6 + 30, 0, abilityBtnSize + 10)
abilityBar.Position = UDim2.new(0.5, -(abilityBtnSize * 6 + 30) / 2, 0, if isMobile then 176 else 156)
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
bfCorner.Parent = bossFill

-- forward declarations for mobile buttons
local function requestJump_forward() requestJump() end
local function swingAttack_forward() swingAttack() end
local function doInteract_forward() doInteract() end

-- mobile touch controls
if isMobile then
	local padSize = 64
	local dpad = Instance.new("Frame")
	dpad.Name = "DPad"
	dpad.BackgroundTransparency = 1
	dpad.Size = UDim2.new(0, padSize * 2 + 16, 0, padSize + 16)
	dpad.Position = UDim2.new(0, 22, 1, -(padSize + 44))
	dpad.Parent = frame

	local function dpadBtn(name: string, xScale: number, text: string): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		b.BackgroundTransparency = 0.82
		b.BorderSizePixel = 0
		b.Size = UDim2.new(0, padSize, 0, padSize)
		b.Position = UDim2.new(xScale, 0, 0.5, -padSize / 2)
		b.Font = Enum.Font.Bangers
		b.Text = text
		b.TextColor3 = Color3.fromRGB(255, 245, 220)
		b.TextScaled = true
		b.Parent = frame -- parent to frame so it's above dpad visually? no, parent to dpad
		b.Parent = dpad
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 18)
		c.Parent = b
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(255, 255, 255)
		s.Transparency = 0.5
		s.Thickness = 2
		s.Parent = b
		return b
	end

	local btnLeft = dpadBtn("LeftBtn", 0, "◀")
	local btnRight = dpadBtn("RightBtn", 1, "▶") :: TextButton
	btnRight.Position = UDim2.new(1, -padSize, 0.5, -padSize / 2)

	local function press(side: number)
		moveDir = side
		facing = side
	end
	btnLeft.MouseButton1Down:Connect(function() press(-1) end)
	btnLeft.MouseButton1Up:Connect(function() if moveDir == -1 then moveDir = 0 end end)
	btnRight.MouseButton1Down:Connect(function() press(1) end)
	btnRight.MouseButton1Up:Connect(function() if moveDir == 1 then moveDir = 0 end end)

	local actions = Instance.new("Frame")
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
	RE.cast:FireServer(abilityId, aim.X, aim.Y)
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
		if not titleOpen then
			togglePause()
		end
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
	local dir = facing
	RE.swing:FireServer(dir)
	local origin = hrp.Position + Vector3.new(dir * 2, 1.4, 0)
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
	hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, jumpPower, 0)
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
	hrp.CFrame = CFrame.new(30, 4, 0)

	-- side-scroll Z lock
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not char.Parent then
			conn:Disconnect()
			return
		end
		local pos = hrp.Position
		if math.abs(pos.Z) > 0.5 then
			hrp.CFrame = CFrame.new(pos.X, pos.Y, 0)
		end
		local vel = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y, 0)
		if pos.Y < Config.WORLD.killY then
			RE.respawn:FireServer()
		end
	end)

	-- movement + flip + camera
	RunService.Heartbeat:Connect(function(dt)
		if not hrp or paused or titleOpen then
			return
		end
		local move = moveDir
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move += 1
		end
		if move ~= 0 then
			facing = move
		end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				local sx = math.abs(d.Size.X)
				if d.Size.X * facing < 0 then
					d.Size = Vector3.new(sx * facing, d.Size.Y, d.Size.Z)
				end
			end
		end
		local speed = Config.PLAYER.baseSpeed
		local payload = gui:GetAttribute("LastPayload") :: any?
		if payload and payload.abilities and payload.abilities.wind then
			speed += Config.PLAYER.windSpeedBonus
		end
		local targetVel = Vector3.new(move * speed, hrp.AssemblyLinearVelocity.Y, 0)
		hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(targetVel, 1 - math.exp(-16 * dt))

		-- ground / coyote / wind glide
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
		if payload and payload.abilities and payload.abilities.wind and not grounded then
			local vel = hrp.AssemblyLinearVelocity
			if vel.Y < 0 then
				hrp.AssemblyLinearVelocity = vel * Vector3.new(1, Config.PLAYER.windGlideFactor, 1)
			end
		end
		-- camera follow
		local targetCam = CFrame.new(hrp.Position.X, hrp.Position.Y, Config.WORLD.camDepth)
		camera.CFrame = camera.CFrame:Lerp(targetCam, 1 - math.exp(-9 * dt))
		local cx = math.clamp(hrp.Position.X, Config.WORLD.minX + 6, Config.WORLD.maxX - 6)
		if math.abs(camera.CFrame.Position.X - cx) > 2 then
			camera.CFrame = CFrame.new(cx, camera.CFrame.Position.Y, Config.WORLD.camDepth)
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
