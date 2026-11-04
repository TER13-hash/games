--!strict
-- Enchanted Realm: Inkbound — Settings panel (SFX / Music volume).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Settings = {}
Settings.__index = Settings

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("SyncGui") :: ScreenGui

local sfxVol = 1
local musicVol = 0.5

local panel = Instance.new("Frame")
panel.Name = "SettingsPanel"
panel.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Size = UDim2.new(0, 420, 0, 300)
panel.Position = UDim2.new(0.5, -210, 0.5, -150)
panel.ZIndex = 120
panel.Visible = false
panel.Parent = gui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 16)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 40)
title.Font = Enum.Font.Bangers
title.Text = "SETTINGS"
title.TextColor3 = Color3.fromRGB(255, 220, 150)
title.TextScaled = true
title.ZIndex = 121
title.Parent = panel

local function sliderRow(labelText: string, y: number, onChanged: (value: number) -> (), initial: number): { Frame, Frame, TextLabel }
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -40, 0, 40)
	row.Position = UDim2.new(0, 20, 0, y)
	row.ZIndex = 121
	row.Parent = panel

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(0, 100, 1, 0)
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = labelText
	lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
	lbl.TextScaled = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 122
	lbl.Parent = row

	local track = Instance.new("Frame")
	track.BackgroundColor3 = Color3.fromRGB(40, 34, 48)
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, -120, 0, 8)
	track.Position = UDim2.new(0, 110, 0.5, -4)
	track.ZIndex = 122
	track.Parent = row
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 4)
	tc.Parent = track

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(140, 225, 255)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(initial, 0, 1, 0)
	fill.ZIndex = 123
	fill.Parent = track
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 4)
	fc.Parent = fill

	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = Color3.fromRGB(255, 240, 210)
	knob.BorderSizePixel = 0
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(initial, -8, 0.5, -8)
	knob.ZIndex = 124
	knob.Parent = track
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(0, 8)
	kc.Parent = knob

	local valueLbl = Instance.new("TextLabel")
	valueLbl.BackgroundTransparency = 1
	valueLbl.Size = UDim2.new(0, 30, 1, 0)
	valueLbl.Position = UDim2.new(1, -30, 0, 0)
	valueLbl.Font = Enum.Font.GothamBold
	valueLbl.Text = tostring(math.floor(initial * 100)) .. "%"
	valueLbl.TextColor3 = Color3.fromRGB(255, 240, 210)
	valueLbl.TextScaled = true
	valueLbl.ZIndex = 122
	valueLbl.Parent = row

	local dragging = false
	local function update(px: number)
		local rel = math.clamp((px - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		knob.Position = UDim2.new(rel, -8, 0.5, -8)
		valueLbl.Text = tostring(math.floor(rel * 100)) .. "%"
		onChanged(rel)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return row, fill, valueLbl
end

sliderRow("SFX Volume", 70, function(v)
	sfxVol = v
	-- apply to all playing sounds via SoundService or per-instance
	for _, s in ipairs(game:GetService("Workspace"):GetDescendants()) do
		if s:IsA("Sound") then
			-- only adjust non-looping UI sfx that we spawned? We can't easily tag them.
			-- We'll store volume and apply on play in Effects.
		end
	end
end, sfxVol)
sliderRow("Music Volume", 130, function(v)
	musicVol = v
end, musicVol)

-- fullscreen / graphics quality placeholder
local qualityLbl = Instance.new("TextLabel")
qualityLbl.BackgroundTransparency = 1
qualityLbl.Size = UDim2.new(0, 200, 0, 30)
qualityLbl.Position = UDim2.new(0, 20, 0, 190)
qualityLbl.Font = Enum.Font.GothamBold
qualityLbl.Text = "Graphics: Fast"
qualityLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
qualityLbl.TextScaled = true
qualityLbl.ZIndex = 122
qualityLbl.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
closeBtn.BorderSizePixel = 0
closeBtn.Size = UDim2.new(0, 100, 0, 36)
closeBtn.Position = UDim2.new(0.5, -50, 1, -50)
closeBtn.Font = Enum.Font.Bangers
closeBtn.Text = "Back"
closeBtn.TextColor3 = Color3.fromRGB(255, 240, 210)
closeBtn.TextScaled = true
closeBtn.ZIndex = 122
closeBtn.Parent = panel
local cbc = Instance.new("UICorner")
cbc.CornerRadius = UDim.new(0, 10)
cbc.Parent = closeBtn

local isOpen = false
local onClose: (() -> ())? = nil

function Settings.open()
	isOpen = true
	panel.Visible = true
	panel.BackgroundTransparency = 0.5
	TweenService:Create(panel, TweenInfo.new(0.25), { BackgroundTransparency = 0.15 }):Play()
end

function Settings.close()
	isOpen = false
	TweenService:Create(panel, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	task.delay(0.2, function()
		panel.Visible = false
	end)
	if onClose then
		onClose()
	end
end

closeBtn.Activated:Connect(function()
	Settings.close()
end)

function Settings.onClose(callback: () -> ())
	onClose = callback
end

function Settings.getSFX(): number
	return sfxVol
end

function Settings.getMusic(): number
	return musicVol
end

function Settings.isOpenState(): boolean
	return isOpen
end

return Settings
