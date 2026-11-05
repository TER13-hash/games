--!strict
-- Firefly companion: a small glowing firefly that orbits the player and gives off soft light.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local FIREFLY_COLOR = Color3.fromRGB(190, 255, 140)
local ORBIT_RADIUS = 3.5
local ORBIT_HEIGHT = 2.2

local function attachFirefly(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	local firefly = Instance.new("Part")
	firefly.Name = "Firefly"
	firefly.Size = Vector3.new(0.25, 0.25, 0.25)
	firefly.Shape = Enum.PartType.Ball
	firefly.Color = FIREFLY_COLOR
	firefly.Material = Enum.Material.Neon
	firefly.CanCollide = false
	firefly.CanQuery = false
	firefly.CanTouch = false
	firefly.CastShadow = false
	firefly.Anchored = true
	firefly.Transparency = 0.2

	local light = Instance.new("PointLight")
	light.Name = "FireflyLight"
	light.Color = FIREFLY_COLOR
	light.Brightness = 1.2
	light.Range = 12
	light.Shadows = false
	light.Parent = firefly

	-- gentle flicker
	local rng = Random.new()
	task.spawn(function()
		while firefly.Parent do
			light.Brightness = 0.9 + rng:NextNumber() * 0.6
			task.wait(rng:NextNumber(0.15, 0.45))
		end
	end)

	-- spark trail
	local spark = Instance.new("ParticleEmitter")
	spark.Texture = "rbxassetid://243660364"
	spark.Color = ColorSequence.new(FIREFLY_COLOR)
	spark.Rate = 4
	spark.Lifetime = NumberRange.new(0.4, 0.8)
	spark.Speed = NumberRange.new(0.2, 0.6)
	spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	spark.LightEmission = 1
	spark.Parent = firefly

	firefly.Parent = workspace

	-- orbit around the character
	local angle = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not character.Parent or not hrp.Parent then
			conn:Disconnect()
			firefly:Destroy()
			return
			end
			angle += dt * 1.6 -- gentle orbit speed
			-- bob up and down slightly for a living feel
			local bob = math.sin(angle * 2.3) * 0.4
			local offset = Vector3.new(
				math.cos(angle) * ORBIT_RADIUS,
				ORBIT_HEIGHT + bob,
				math.sin(angle) * ORBIT_RADIUS * 0.6
			)
			firefly.CFrame = CFrame.new(hrp.Position + offset)
	end)
end

local function onCharacterAdded(character: Model)
	-- wait a moment so the character settles at spawn
	task.wait(0.5)
	attachFirefly(character)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end