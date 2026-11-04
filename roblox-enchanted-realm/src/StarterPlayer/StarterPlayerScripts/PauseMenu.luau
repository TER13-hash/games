--!strict
-- Enchanted Realm: Inkbound — Pause Menu.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PauseMenu = {}
PauseMenu.__index = PauseMenu

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("SyncGui") :: ScreenGui

local panel = Instance.new("Frame")
panel.Name = "PauseMenu"
panel.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Size = UDim2.new(0, 340, 0, 340)
panel.Position = UDim2.new(0.5, -170, 0.5, -170)
panel.ZIndex = 130
panel.Visible = false
panel.Parent = gui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 18)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 50)
title.Font = Enum.Font.Bangers
title.Text = "PAUSED"
title.TextColor3 = Color3.fromRGB(255, 220, 150)
title.TextScaled = true
title.ZIndex = 131
title.Parent = panel

local buttons = Instance.new("Frame")
buttons.BackgroundTransparency = 1
buttons.Size = UDim2.new(1, -40, 1, -100)
buttons.Position = UDim2.new(0, 20, 0, 60)
buttons.ZIndex = 131
buttons.Parent = panel

local function pauseBtn(name: string, text: string, order: number, onActivated: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	b.BackgroundTransparency = 0.15
	b.BorderSizePixel = 0
	b.Size = UDim2.new(1, 0, 0, 52)
	b.Position = UDim2.new(0, 0, 0, (order - 1) * 64)
	b.Font = Enum.Font.Bangers
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 240, 210)
	b.TextScaled = true
	b.ZIndex = 132
	b.Parent = buttons
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(80, 70, 90)
	s.Thickness = 2
	s.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.2), { BackgroundTransparency = 0.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.2), { BackgroundTransparency = 0.15 }):Play()
	end)
	b.Activated:Connect(onActivated)
	return b
end

local isOpen = false
local onResume: (() -> ())? = nil
local onSettings: (() -> ())? = nil
local onRestart: (() -> ())? = nil
local onQuitToMenu: (() -> ())? = nil

pauseBtn("ResumeBtn", "Resume", 1, function()
	if onResume then
		onResume()
	end
end)
pauseBtn("SettingsBtn", "Settings", 2, function()
	if onSettings then
		onSettings()
	end
end)
pauseBtn("RestartBtn", "Restart at Checkpoint", 3, function()
	if onRestart then
		onRestart()
	end
end)
pauseBtn("MenuBtn", "Quit to Title", 4, function()
	if onQuitToMenu then
		onQuitToMenu()
	end
end)

function PauseMenu.open()
	isOpen = true
	panel.Visible = true
	panel.BackgroundTransparency = 0.4
	TweenService:Create(panel, TweenInfo.new(0.25), { BackgroundTransparency = 0.25 }):Play()
end

function PauseMenu.close()
	isOpen = false
	TweenService:Create(panel, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	task.delay(0.2, function()
		panel.Visible = false
	end)
end

function PauseMenu.onResume(callback: () -> ())
	onResume = callback
end

function PauseMenu.onSettings(callback: () -> ())
	onSettings = callback
end

function PauseMenu.onRestart(callback: () -> ())
	onRestart = callback
end

function PauseMenu.onQuitToMenu(callback: () -> ())
	onQuitToMenu = callback
end

function PauseMenu.isOpenState(): boolean
	return isOpen
end

return PauseMenu
