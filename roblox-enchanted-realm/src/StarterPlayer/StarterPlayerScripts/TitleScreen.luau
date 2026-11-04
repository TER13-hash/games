--!strict
-- Enchanted Realm: Inkbound — Title Screen / Main Menu.
-- Shows at game start. Handles Start, Settings, Credits.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local TitleScreen = {}
TitleScreen.__index = TitleScreen

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("SyncGui") :: ScreenGui

-- build the menu overlay
local menu = Instance.new("Frame")
menu.Name = "TitleMenu"
menu.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
menu.BackgroundTransparency = 0.05
menu.BorderSizePixel = 0
menu.Size = UDim2.new(1, 0, 1, 0)
menu.ZIndex = 100
menu.Visible = true
menu.Parent = gui

-- vignette corners for hand-drawn feel
local cornerUL = Instance.new("Frame")
cornerUL.BackgroundColor3 = Color3.fromRGB(20, 16, 24)
cornerUL.BorderSizePixel = 0
cornerUL.Size = UDim2.new(0, 120, 0, 120)
cornerUL.Position = UDim2.new(0, 0, 0, 0)
cornerUL.ZIndex = 101
cornerUL.Parent = menu
local cornerUR = cornerUL:Clone()
cornerUR.Position = UDim2.new(1, -120, 0, 0)
cornerUR.Parent = menu
local cornerLL = cornerUL:Clone()
cornerLL.Position = UDim2.new(0, 0, 1, -120)
cornerLL.Parent = menu
local cornerLR = cornerUL:Clone()
cornerLR.Position = UDim2.new(1, -120, 1, -120)
cornerLR.Parent = menu

-- title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(0, 700, 0, 120)
title.Position = UDim2.new(0.5, -350, 0.22, -60)
title.Font = Enum.Font.Bangers
title.Text = "ENCHANTED REALM"
title.TextColor3 = Color3.fromRGB(255, 220, 150)
title.TextScaled = true
title.ZIndex = 102
title.Parent = menu
local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 0)
tc.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.BackgroundTransparency = 1
subtitle.Size = UDim2.new(0, 700, 0, 40)
subtitle.Position = UDim2.new(0.5, -350, 0.22, 55)
subtitle.Font = Enum.Font.GothamBold
subtitle.Text = ": Inkbound"
subtitle.TextColor3 = Color3.fromRGB(140, 225, 255)
subtitle.TextScaled = true
subtitle.ZIndex = 102
subtitle.Parent = menu

local tagline = Instance.new("TextLabel")
tagline.Name = "Tagline"
tagline.BackgroundTransparency = 1
tagline.Size = UDim2.new(0, 600, 0, 30)
tagline.Position = UDim2.new(0.5, -300, 0.34, 0)
tagline.Font = Enum.Font.Gotham
tagline.Text = "The world is a sketch. Fight for the page."
tagline.TextColor3 = Color3.fromRGB(200, 200, 210)
tagline.TextScaled = true
tagline.ZIndex = 102
tagline.Parent = menu

-- menu buttons
local buttons = Instance.new("Frame")
buttons.Name = "Buttons"
buttons.BackgroundTransparency = 1
buttons.Size = UDim2.new(0, 260, 0, 260)
buttons.Position = UDim2.new(0.5, -130, 0.52, 0)
buttons.ZIndex = 102
buttons.Parent = menu

local function menuBtn(name: string, text: string, order: number, onActivated: () -> ()): TextButton
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
	b.ZIndex = 103
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

-- credits text
local credits = Instance.new("TextLabel")
credits.Name = "Credits"
credits.BackgroundTransparency = 1
credits.Size = UDim2.new(0, 500, 0, 30)
credits.Position = UDim2.new(0.5, -250, 1, -40)
credits.Font = Enum.Font.Gotham
credits.Text = "Group 5 · Enchanted Realm GDD · Roblox Edition"
credits.TextColor3 = Color3.fromRGB(120, 120, 130)
credits.TextScaled = true
credits.ZIndex = 102
credits.Parent = menu

local isOpen = true
local onStart: (() -> ())? = nil
local onSettings: (() -> ())? = nil

menuBtn("StartBtn", "Start Journey", 1, function()
	if onStart then
		onStart()
	end
end)
menuBtn("SettingsBtn", "Settings", 2, function()
	if onSettings then
		onSettings()
	end
end)
menuBtn("CreditsBtn", "Credits", 3, function()
	TitleScreen.showCredits()
end)
menuBtn("QuitBtn", "Quit", 4, function()
	game:Shutdown()
end)

function TitleScreen.showCredits()
	local overlay = Instance.new("Frame")
	overlay.Name = "CreditsOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
	overlay.BackgroundTransparency = 0.1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.ZIndex = 110
	overlay.Parent = menu

	local lines = {
		"ENCHANTED REALM: INKBOUND",
		"",
		"Based on the Game Design Document by Group 5:",
		"Dyanne Francine Dagsil",
		"Dann Miguel Cabang",
		"Aaron Ross Guldo",
		"Lyka Mata",
		"Clarke Jedrex Tadeja",
		"Jasmine Dylan Santos",
		"",
		"Inspired by Hollow Knight,",
		"Ori and the Will of the Wisps,",
		"and Blasphemous.",
		"",
		"Hand-drawn 'Inkbound' art style.",
		"",
		"Press E to interact · 1-6 for abilities",
		"Space to jump · Click to attack",
		"",
		"Good luck, Warrior.",
	}
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(0, 400, 0, #lines * 24)
	list.Position = UDim2.new(0.5, -200, 0.5, -#lines * 12)
	list.ZIndex = 111
	list.Parent = overlay
	for i, line in ipairs(lines) do
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 0, 22)
		lbl.Position = UDim2.new(0, 0, 0, (i - 1) * 24)
		lbl.Font = Enum.Font.Gotham
		lbl.Text = line
		lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
		lbl.TextScaled = true
		lbl.ZIndex = 112
		lbl.Parent = list
	end
	local close = Instance.new("TextButton")
	close.Name = "CloseCredits"
	close.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	close.BorderSizePixel = 0
	close.Size = UDim2.new(0, 120, 0, 36)
	close.Position = UDim2.new(0.5, -60, 1, -80)
	close.Font = Enum.Font.Bangers
	close.Text = "Back"
	close.TextColor3 = Color3.fromRGB(255, 240, 210)
	close.TextScaled = true
	close.ZIndex = 112
	close.Parent = overlay
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = close
	close.Activated:Connect(function()
		overlay:Destroy()
	end)
end

function TitleScreen.close()
	isOpen = false
	TweenService:Create(menu, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	-- fade children
	for _, d in ipairs(menu:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		elseif d:IsA("Frame") and d ~= menu then
			TweenService:Create(d, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			for _, c in ipairs(d:GetDescendants()) do
				if c:IsA("UIStroke") then
					TweenService:Create(c, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				end
			end
		end
	end
	Debris:AddItem(menu, 0.45)
end

function TitleScreen.onStart(callback: () -> ())
	onStart = callback
end

function TitleScreen.onSettings(callback: () -> ())
	onSettings = callback
end

function TitleScreen.isOpenState(): boolean
	return isOpen
end

return TitleScreen
