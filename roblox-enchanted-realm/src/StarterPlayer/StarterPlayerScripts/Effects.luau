--!strict
-- Enchanted Realm: Inkbound — client VFX, sound, camera shake.
-- All effects are local-only; they never affect simulation.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundIDs = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundIDs"))

local Effects = {}
Effects.__index = Effects

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local shakeRig = Instance.new("Part")
shakeRig.Name = "CameraShakeRig"
shakeRig.Anchored = true
shakeRig.CanCollide = false
shakeRig.Transparency = 1
shakeRig.Size = Vector3.new(1, 1, 1)
shakeRig.CFrame = camera.CFrame
shakeRig.Parent = workspace

local shakeIntensity = 0
local shakeDecay = 0.92

-- —————— sound ——————

function Effects.playSfx(key: string, position: Vector3?, volume: number?)
	local id = SoundIDs.find("sfx", key)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.8
	sound.Parent = workspace
	if position then
		sound.Position = position
	end
	sound:Play()
	Debris:AddItem(sound, sound.TimeLength + 0.5)
	return sound
end

function Effects.playMusic(key: string, loop: boolean?, volume: number?, fadeIn: number?)
	local id = SoundIDs.find("music", key)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = loop ~= false
	sound.Volume = volume or 0.45
	sound.Parent = workspace
	sound:Play()
	return sound
end

-- —————— camera shake ——————

function Effects.shakeCamera(intensity: number, duration: number?)
	shakeIntensity = math.max(shakeIntensity, intensity)
	if duration then
		task.delay(duration, function()
			shakeIntensity = math.max(0, shakeIntensity - intensity * 0.5)
		end)
	end
end

RunService.Heartbeat:Connect(function(dt)
	if shakeIntensity > 0.005 then
		local offset = Vector3.new(
			(math.random() - 0.5) * shakeIntensity,
			(math.random() - 0.5) * shakeIntensity,
			0
		)
		local base = CFrame.new(camera.CFrame.Position)
		camera.CFrame = base * CFrame.new(offset)
		shakeIntensity *= shakeDecay
	else
		shakeIntensity = 0
	end
end)

-- —————— particles ——————

local function burst(position: Vector3, color: Color3, amount: number, size: number?)
	local p = Instance.new("Part")
	p.Name = "VFXBurst"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Position = position
	p.Parent = workspace
	local a = Instance.new("Attachment")
	a.Parent = p
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://243660364"
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.35, 0.8)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.7), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = a
	emitter:Emit(amount)
	Debris:AddItem(p, 1.4)
end

-- —————— public vfx ——————

function Effects.swing(origin: Vector3, dir: Vector3, hit: boolean)
	local look = if dir and dir.Magnitude > 0.01 then Vector3.new(dir.X, 0, dir.Z).Unit else Vector3.new(1, 0, 0)
	local slash = Instance.new("Part")
	slash.Name = "SlashFX"
	slash.Anchored = true
	slash.CanCollide = false
	slash.CanQuery = false
	slash.Material = Enum.Material.Neon
	slash.Color = hit and Color3.fromRGB(255, 230, 140) or Color3.fromRGB(140, 160, 200)
	slash.Size = Vector3.new(0.8, 3.6, 4.5)
	local center = origin + Vector3.new(0, 1.3, 0) + look * 2
	slash.CFrame = CFrame.lookAt(center, center + look) * CFrame.Angles(0, 0, math.rad(-35))
	slash.Parent = workspace
	TweenService:Create(slash, TweenInfo.new(0.1), { Transparency = 1, Size = Vector3.new(1.4, 6, 9) }):Play()
	Debris:AddItem(slash, 0.14)
	if hit then
		burst(origin + look * 2.2 + Vector3.new(0, 1.3, 0), Color3.fromRGB(255, 200, 120), 16, 0.9)
	end
end

function Effects.cast(abilityId: string, origin: Vector3, dir: Vector3)
	local color = {
		lightning = Color3.fromRGB(140, 225, 255),
		fire = Color3.fromRGB(255, 130, 40),
		ice = Color3.fromRGB(160, 230, 255),
		wind = Color3.fromRGB(180, 255, 210),
		powerRock = Color3.fromRGB(170, 150, 120),
		lightningCore = Color3.fromRGB(255, 255, 220),
		shockwave = Color3.fromRGB(150, 215, 255),
	}[abilityId] or Color3.fromRGB(255, 255, 255)
	burst(origin + dir * 2 + Vector3.new(0, 1, 0), color, 22, 1.1)
	-- trail forward
	local trail = Instance.new("Part")
	trail.Name = "CastTrail"
	trail.Anchored = true
	trail.CanCollide = false
	trail.CanQuery = false
	trail.Material = Enum.Material.Neon
	trail.Color = color
	trail.Transparency = 0.3
	trail.Size = Vector3.new(0.7, 0.7, 8)
	trail.CFrame = CFrame.new(origin + dir * 4, origin + dir * 12)
	trail.Parent = workspace
	TweenService:Create(trail, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	Debris:AddItem(trail, 0.2)
end

function Effects.breakBarrier(position: Vector3, btype: string)
	local color = {
		electric = Color3.fromRGB(140, 225, 255),
		stone = Color3.fromRGB(170, 150, 120),
		frozen = Color3.fromRGB(160, 230, 255),
		waterfall = Color3.fromRGB(130, 210, 250),
		vine = Color3.fromRGB(90, 190, 70),
		wood = Color3.fromRGB(150, 110, 70),
		rock = Color3.fromRGB(170, 150, 120),
		machineSeal = Color3.fromRGB(200, 140, 255),
	}[btype] or Color3.fromRGB(255, 255, 255)
	burst(position, color, 34, 1.2)
	Effects.shakeCamera(0.12, 0.2)
end

function Effects.lanternLit(position: Vector3)
	burst(position + Vector3.new(0, 2.2, 0), Color3.fromRGB(255, 200, 110), 20, 0.8)
	Effects.shakeCamera(0.06, 0.15)
end

function Effects.hurtFlash()
	local flash = Instance.new("Frame")
	flash.Name = "HurtFlash"
	flash.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	flash.BackgroundTransparency = 0.55
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BorderSizePixel = 0
	flash.ZIndex = 10
	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("SyncGui")
	if gui then
		flash.Parent = gui
		TweenService:Create(flash, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
		Debris:AddItem(flash, 0.2)
	end
end

function Effects.bossBurst(position: Vector3, color: Color3?)
	burst(position, color or Color3.fromRGB(255, 255, 255), 45, 1.4)
	Effects.shakeCamera(0.25, 0.5)
end

function Effects.deniedHint(position: Vector3, text: string?)
	-- local floating "cannot break yet" hint
	local bill = Instance.new("BillboardGui")
	bill.Name = "DeniedHint"
	bill.Size = UDim2.new(0, 260, 0, 42)
	bill.StudsOffset = Vector3.new(0, 3.4, 0)
	bill.MaxDistance = 40
	bill.AlwaysOnTop = false
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Font = Enum.Font.Bangers
	lbl.Text = text or "Locked"
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 110, 110)
	lbl.TextStrokeTransparency = 0.4
	lbl.TextStrokeColor3 = Color3.fromRGB(10, 10, 12)
	lbl.Parent = bill
	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, 4, 0)
	attach.Parent = workspace.Terrain
	bill.Adornee = attach
	bill.Parent = workspace.Terrain
	TweenService:Create(bill, TweenInfo.new(0.2), { StudsOffset = Vector3.new(0, 4.6, 0) }):Play()
	Debris:AddItem(bill, 2.2)
	Debris:AddItem(attach, 2.2)
end

function Effects.root(position: Vector3)
	burst(position, Color3.fromRGB(100, 200, 90), 18, 1)
end

function Effects.blindPlayer()
	local overlay = Instance.new("Frame")
	overlay.Name = "InkOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
	overlay.BackgroundTransparency = 0.5
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 9
	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("SyncGui")
	if gui then
		overlay.Parent = gui
		TweenService:Create(overlay, TweenInfo.new(1.6), { BackgroundTransparency = 1 }):Play()
		Debris:AddItem(overlay, 1.8)
	end
end

function Effects.burn(position: Vector3)
	burst(position, Color3.fromRGB(255, 120, 30), 10, 0.7)
end

function Effects.teleportFlash(position: Vector3)
	burst(position, Color3.fromRGB(170, 100, 255), 26, 1.1)
	Effects.shakeCamera(0.1, 0.2)
end

return Effects
